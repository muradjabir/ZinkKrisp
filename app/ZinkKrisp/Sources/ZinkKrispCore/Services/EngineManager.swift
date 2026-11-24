import AppKit
import Darwin
import Foundation

@MainActor
public final class EngineManager: ObservableObject {
    public static let shared = EngineManager()

    @Published public var isReady: Bool = false
    @Published public var isBusy: Bool = false
    @Published public var statusMessage: String = "Checking runtime..."
    @Published public var errorMessage: String?

    @Published public var wineAppURL: URL?
    @Published public var needsWineRuntimeSetup: Bool = false
    @Published public var isDownloadingWine: Bool = false
    @Published public var wineDownloadStatus: String = ""
    @Published public var wineDownloadProgress: Double?
    @Published public var wineDownloadMBText: String = ""

    @Published public var libraryApps: [InstalledApp] = []
    @Published public var containerIDs: [String] = []
    @Published public var discoveredExes: [DiscoveredExe] = []
    @Published public var showExeSelectionSheet: Bool = false
    @Published public var installerRunningName: String?
    @Published public var activeContainerID: String?
    @Published public var activeContainerName: String?
    @Published public var pendingNewAppInstallerURL: URL?
    @Published public var browsingContainerID: String?
    @Published public var displayTopology: DisplayTopology = .pureRetina

    @Published public var pendingRequirementsApp: InstalledApp?
    @Published public var pendingRequirementsStatuses: [PrerequisiteStatus] = []
    @Published public var isInstallingPrereqs: Bool = false
    @Published public var prereqProgressMessage: String = ""
    @Published public var prereqProgressValue: Double? = nil
    @Published public var prereqErrorMessage: String? = nil

    @Published public var runningContainerIDs: Set<String> = []
    @Published public var activeLaunchSession: LaunchStatusSession? = nil
    @Published public var managingStartupContainerID: String? = nil
    @Published public var managingSnapshotsContainerID: String? = nil
    @Published public var isSnapshotBusy: Bool = false
    @Published public var pendingForcePrompt: ContainerForcePrompt? = nil
    private var containerStatusTimer: Timer?
    private var webViewWatchdogTasks: [String: Task<Void, Never>] = [:]

    public let appSupportURL: URL
    public let templatePrefixURL: URL
    public let containersURL: URL
    public let snapshotsURL: URL
    public let runtimeURL: URL
    public let icdJSONURL: URL
    public let libraryJSONURL: URL

    private init() {
        var rl = rlimit()
        if getrlimit(RLIMIT_NOFILE, &rl) == 0 {
            let target: rlim_t = 65536
            rl.rlim_cur = max(rl.rlim_cur, min(target, rl.rlim_max))
            setrlimit(RLIMIT_NOFILE, &rl)
        }
        let fm = FileManager.default
        let baseSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ZinkKrisp", isDirectory: true)
        self.appSupportURL = baseSupport
        self.templatePrefixURL = baseSupport.appendingPathComponent("TemplatePrefix", isDirectory: true)
        self.containersURL = baseSupport.appendingPathComponent("Containers", isDirectory: true)
        self.snapshotsURL = baseSupport.appendingPathComponent("Snapshots", isDirectory: true)
        self.runtimeURL = baseSupport.appendingPathComponent("Runtime", isDirectory: true)
        self.icdJSONURL = runtimeURL.appendingPathComponent("kosmickrisp_icd.json")
        self.libraryJSONURL = baseSupport.appendingPathComponent("library.json")

        loadLibrary()
        refreshContainers()
        refreshRunningContainers()
        containerStatusTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshRunningContainers()
            }
        }
        displayTopology = DisplayDPIManager.shared.currentTopology()
        DisplayDPIManager.shared.startObservingScreenChanges { [weak self] in
            guard let self else { return }
            self.displayTopology = DisplayDPIManager.shared.currentTopology()
            Task {
                await self.syncAutoDisplaySettings()
            }
        }
    }

    public func syncAutoDisplaySettings() async {
        guard let wineApp = wineAppURL, let wineBin = resolveWineBinary(in: wineApp) else { return }
        for app in libraryApps where app.displayScalingMode == .auto {
            let env = buildEnvironment(for: app, prefixURL: app.containerURL(in: containersURL))
            await DisplayDPIManager.shared.applyDPISettings(
                for: .auto,
                exeWindowsPath: app.windowsExePath,
                wineBin: wineBin,
                environment: env
            )
        }
    }

    public func refreshContainers() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: containersURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            containerIDs = []
            return
        }
        containerIDs = items
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { $0.lastPathComponent }
            .sorted()
        refreshRunningContainers()
    }

    private func wineserverPID(for containerID: String) -> pid_t? {
        let prefixPath = containerURL(for: containerID).standardizedFileURL.path
        var st = stat()
        guard stat(prefixPath, &st) == 0 else { return nil }
        let uid = getuid()
        let devHex = String(UInt64(UInt32(bitPattern: st.st_dev)), radix: 16)
        let inoHex = String(UInt64(st.st_ino), radix: 16)
        let lockPath = "/tmp/.wine-\(uid)/server-\(devHex)-\(inoHex)/lock"
        let fd = open(lockPath, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var fl = flock()
        fl.l_type = Int16(F_WRLCK)
        fl.l_whence = Int16(SEEK_SET)
        fl.l_start = 0
        fl.l_len = 0
        if fcntl(fd, F_GETLK, &fl) == 0, fl.l_type != Int16(F_UNLCK), fl.l_pid > 0 {
            return fl.l_pid
        }
        return nil
    }

    public func isContainerRunning(_ containerID: String) -> Bool {
        wineserverPID(for: containerID) != nil
    }

    public func runningProcessDescriptions(in containerID: String) -> [String] {
        var results: [String] = []
        if let wsPID = wineserverPID(for: containerID) {
            results.append("wineserver (PID \(wsPID))")
        }
        let prefixPath = containerURL(for: containerID).standardizedFileURL.path
        let registeredNames = startupProcesses(for: containerID).map { $0.processMatchName.lowercased() }
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-e", "-o", "pid=,args="]
        let pipe = Pipe()
        ps.standardOutput = pipe
        ps.standardError = Pipe()
        if (try? ps.run()) != nil {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            ps.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            for raw in output.split(separator: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                let lower = line.lowercased()
                let matchesStartup = isContainerRunning(containerID) && registeredNames.contains { !$0.isEmpty && lower.contains($0) }
                if line.contains(prefixPath) || matchesStartup {
                    results.append(String(line.prefix(90)))
                }
            }
        }
        return Array(Set(results)).sorted()
    }

    public func refreshRunningContainers() {
        var active = Set<String>()
        let allIDs = Set(containerIDs).union(libraryApps.map(\.containerID))
        for cid in allIDs {
            if isContainerRunning(cid) {
                active.insert(cid)
            }
        }
        if active != runningContainerIDs {
            runningContainerIDs = active
        }
    }

    public func stopContainer(containerID: String, force: Bool = false) async {
        let targetPrefix = containerURL(for: containerID)
        let env = buildEnvironment(for: nil, prefixURL: targetPrefix)
        let wineApp = wineAppURL
        let wineserver = wineApp.flatMap { resolveWineserverBinary(in: $0) }

        if !force {
            if let wineserver {
                _ = try? await runProcess(executable: wineserver, arguments: ["-k"], environment: env)
            }
            for _ in 0..<8 {
                if !isContainerRunning(containerID) { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            refreshRunningContainers()
            if isContainerRunning(containerID) {
                let procs = runningProcessDescriptions(in: containerID)
                errorMessage = "Container '\(containerID)' still has running processes. Force close to terminate them."
                pendingForcePrompt = ContainerForcePrompt(
                    containerID: containerID,
                    action: .stop,
                    label: containerID,
                    runningProcesses: procs
                )
                return
            }
            errorMessage = nil
            statusMessage = "Stopped container \(containerID)"
            return
        }

        // Force stop: wineserver -k9 + SIGKILL on wineserver PID and any process connected to its server socket
        if let wineserver {
            _ = try? await runProcess(executable: wineserver, arguments: ["-k9"], environment: env)
        }
        let prefixPath = targetPrefix.standardizedFileURL.path
        var st = stat()
        if stat(prefixPath, &st) == 0 {
            let uid = getuid()
            let devHex = String(UInt64(UInt32(bitPattern: st.st_dev)), radix: 16)
            let inoHex = String(UInt64(st.st_ino), radix: 16)
            let serverDir = "/tmp/.wine-\(uid)/server-\(devHex)-\(inoHex)"
            let sockPath = "\(serverDir)/socket"
            let lsof = Process()
            lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            lsof.arguments = ["-t", sockPath]
            let lsofPipe = Pipe()
            lsof.standardOutput = lsofPipe
            lsof.standardError = Pipe()
            if (try? lsof.run()) != nil {
                let data = lsofPipe.fileHandleForReading.readDataToEndOfFile()
                lsof.waitUntilExit()
                let pidStr = String(data: data, encoding: .utf8) ?? ""
                for token in pidStr.split(whereSeparator: { $0.isWhitespace }) {
                    if let pid = pid_t(token), pid > 1, pid != getpid() {
                        kill(pid, SIGKILL)
                    }
                }
            }
        }
        if let wsPID = wineserverPID(for: containerID) {
            kill(wsPID, SIGKILL)
        }
        stopWebViewBridgeProcesses()
        webViewWatchdogTasks[containerID]?.cancel()
        webViewWatchdogTasks.removeValue(forKey: containerID)
        for _ in 0..<10 {
            if !isContainerRunning(containerID) { break }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        refreshRunningContainers()
        pendingForcePrompt = nil
        if isContainerRunning(containerID) {
            errorMessage = "Container '\(containerID)' could not be stopped completely."
        } else {
            errorMessage = nil
            statusMessage = "Force stopped container \(containerID)"
        }
    }

    private func appleGPUBrandString() -> String {
        var size: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 1 else { return "Apple Silicon" }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        let str = String(cString: buf).trimmingCharacters(in: .whitespacesAndNewlines)
        return str.isEmpty ? "Apple Silicon" : str
    }

    private func applyProfileRegistryEntries(
        _ entries: [RegistryEntrySpec],
        containerID: String,
        wineBin: URL,
        env: [String: String]
    ) async {
        let gpu = appleGPUBrandString()
        var byKey: [String: [RegistryEntrySpec]] = [:]
        var keyOrder: [String] = []
        for entry in entries {
            let expandedKey = entry.keyPath.replacingOccurrences(of: "{{APPLE_GPU}}", with: gpu)
            if byKey[expandedKey] == nil {
                keyOrder.append(expandedKey)
            }
            byKey[expandedKey, default: []].append(entry)
        }

        var regText = "Windows Registry Editor Version 5.00\r\n\r\n"
        for key in keyOrder {
            regText += "[\(key)]\r\n"
            for entry in byKey[key] ?? [] {
                let namePart = entry.valueName.isEmpty || entry.valueName == "@"
                    ? "@"
                    : "\"\(entry.valueName.replacingOccurrences(of: "\"", with: "\\\""))\""
                let expandedData = entry.valueData.replacingOccurrences(of: "{{APPLE_GPU}}", with: gpu)
                if entry.valueType.uppercased() == "REG_DWORD" {
                    regText += "\(namePart)=dword:\(expandedData)\r\n"
                } else {
                    let escaped = expandedData
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                    regText += "\(namePart)=\"\(escaped)\"\r\n"
                }
            }
            regText += "\r\n"
        }

        let tmpReg = FileManager.default.temporaryDirectory
            .appendingPathComponent("zk_profile_reg_\(UUID().uuidString).reg")
        guard (try? regText.write(to: tmpReg, atomically: true, encoding: .utf8)) != nil else { return }
        defer { try? FileManager.default.removeItem(at: tmpReg) }

        let launch = wineLaunchCommand(wineBin: wineBin, arguments: ["regedit", "/S", tmpReg.path], containerID: containerID)
        _ = try? await runProcess(executable: launch.executable, arguments: launch.arguments, environment: env)
    }

    private func clearPendingRebootFlags(containerID: String, prefixURL: URL, wineBin: URL, env: [String: String]) async {
        let regArgsList: [[String]] = [
            ["reg", "delete", "HKLM\\System\\CurrentControlSet\\Control\\Session Manager", "/v", "PendingFileRenameOperations", "/f"],
            ["reg", "delete", "HKLM\\System\\ControlSet001\\Control\\Session Manager", "/v", "PendingFileRenameOperations", "/f"],
            ["reg", "delete", "HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\RebootPending", "/f"],
            ["reg", "delete", "HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired", "/f"]
        ]
        for args in regArgsList {
            let launch = wineLaunchCommand(wineBin: wineBin, arguments: args, containerID: containerID)
            _ = try? await runProcess(executable: launch.executable, arguments: launch.arguments, environment: env)
        }
    }

    // MARK: - APFS Copy-on-Write Container Restore Points

    private func snapshotsDir(for containerID: String) -> URL {
        snapshotsURL.appendingPathComponent(containerID, isDirectory: true)
    }

    private func snapshotsIndexURL(for containerID: String) -> URL {
        snapshotsDir(for: containerID).appendingPathComponent("snapshots.json")
    }

    public func snapshots(for containerID: String) -> [ContainerSnapshot] {
        let url = snapshotsIndexURL(for: containerID)
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([ContainerSnapshot].self, from: data) else {
            return []
        }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    private func saveSnapshots(_ list: [ContainerSnapshot], for containerID: String) {
        let dir = snapshotsDir(for: containerID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(list) {
            try? data.write(to: snapshotsIndexURL(for: containerID), options: .atomic)
        }
    }

    private func cloneDirectoryAPFS(from source: URL, to destination: URL) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) {
            let chflagsProc = Process()
            chflagsProc.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
            chflagsProc.arguments = ["-R", "nouchg", destination.path]
            try? chflagsProc.run()
            chflagsProc.waitUntilExit()
            try? fm.removeItem(at: destination)
        }
        // Try APFS Copy-on-Write clone first (instant, 0 extra disk space)
        let cowExit = try await runProcess(
            executable: URL(fileURLWithPath: "/bin/cp"),
            arguments: ["-c", "-R", "-p", source.path, destination.path],
            environment: [:]
        )
        if cowExit != 0 {
            try? fm.removeItem(at: destination)
            let fallbackExit = try await runProcess(
                executable: URL(fileURLWithPath: "/bin/cp"),
                arguments: ["-R", "-p", source.path, destination.path],
                environment: [:]
            )
            if fallbackExit != 0 {
                throw NSError(domain: "ZinkKrisp", code: Int(fallbackExit), userInfo: [
                    NSLocalizedDescriptionKey: "Failed to clone container directory (cp exited with \(fallbackExit))."
                ])
            }
        }
    }

    @discardableResult
    public func createSnapshot(for containerID: String, name: String, stopFirst: Bool = true) async -> Bool {
        let targetPrefix = containerURL(for: containerID)
        guard FileManager.default.fileExists(atPath: targetPrefix.path) else {
            errorMessage = "Container '\(containerID)' does not exist."
            return false
        }

        isSnapshotBusy = true
        errorMessage = nil
        defer { isSnapshotBusy = false }

        if stopFirst && isContainerRunning(containerID) {
            statusMessage = "Stopping \(containerID) before creating restore point..."
            await stopContainer(containerID: containerID, force: true)
        }

        statusMessage = "Creating APFS restore point '\(name)'..."
        let snapID = UUID()
        let dirName = "snap_\(Int(Date().timeIntervalSince1970))_\(snapID.uuidString.prefix(8))"
        let destURL = snapshotsDir(for: containerID).appendingPathComponent(dirName, isDirectory: true)

        do {
            try await cloneDirectoryAPFS(from: targetPrefix, to: destURL)
            var list = snapshots(for: containerID)
            let snap = ContainerSnapshot(
                id: snapID,
                containerID: containerID,
                name: name,
                createdAt: Date(),
                directoryName: dirName
            )
            list.insert(snap, at: 0)
            saveSnapshots(list, for: containerID)
            statusMessage = "Created restore point '\(name)' for \(containerID)"
            return true
        } catch {
            errorMessage = "Restore point failed: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    public func restoreSnapshot(_ snapshot: ContainerSnapshot) async -> Bool {
        let sourceURL = snapshotsDir(for: snapshot.containerID)
            .appendingPathComponent(snapshot.directoryName, isDirectory: true)
        let targetPrefix = containerURL(for: snapshot.containerID)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            errorMessage = "Restore point files missing for '\(snapshot.name)'."
            return false
        }

        isSnapshotBusy = true
        errorMessage = nil
        defer { isSnapshotBusy = false }

        if isContainerRunning(snapshot.containerID) {
            statusMessage = "Stopping \(snapshot.containerID) before restoring..."
            await stopContainer(containerID: snapshot.containerID, force: true)
        }

        statusMessage = "Restoring \(snapshot.containerID) to '\(snapshot.name)'..."
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: targetPrefix.path) {
                let chflagsProc = Process()
                chflagsProc.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
                chflagsProc.arguments = ["-R", "nouchg", targetPrefix.path]
                try? chflagsProc.run()
                chflagsProc.waitUntilExit()
                try? fm.removeItem(at: targetPrefix)
                if fm.fileExists(atPath: targetPrefix.path) {
                    _ = try? await runProcess(
                        executable: URL(fileURLWithPath: "/bin/rm"),
                        arguments: ["-rf", targetPrefix.path],
                        environment: [:]
                    )
                }
            }
            try await cloneDirectoryAPFS(from: sourceURL, to: targetPrefix)
            refreshContainers()
            statusMessage = "Restored \(snapshot.containerID) to '\(snapshot.name)'"
            return true
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            refreshContainers()
            return false
        }
    }

    public func deleteSnapshot(_ snapshot: ContainerSnapshot) {
        let snapDir = snapshotsDir(for: snapshot.containerID)
            .appendingPathComponent(snapshot.directoryName, isDirectory: true)
        let fm = FileManager.default
        if fm.fileExists(atPath: snapDir.path) {
            let chflagsProc = Process()
            chflagsProc.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
            chflagsProc.arguments = ["-R", "nouchg", snapDir.path]
            try? chflagsProc.run()
            chflagsProc.waitUntilExit()
            try? fm.removeItem(at: snapDir)
        }
        var list = snapshots(for: snapshot.containerID)
        list.removeAll { $0.id == snapshot.id }
        saveSnapshots(list, for: snapshot.containerID)
    }

    // MARK: - Container Startup Process Registry (VM-style Services)

    private func startupProcessesURL(for containerID: String) -> URL {
        containerURL(for: containerID).appendingPathComponent(".zinkkrisp_startup_processes.json")
    }

    public func startupProcesses(for containerID: String) -> [ContainerStartupProcess] {
        let url = startupProcessesURL(for: containerID)
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([ContainerStartupProcess].self, from: data) else {
            return []
        }
        return list
    }

    public func saveStartupProcesses(_ list: [ContainerStartupProcess], for containerID: String) {
        let url = startupProcessesURL(for: containerID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(list) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public func registerStartupProcess(_ proc: ContainerStartupProcess, for containerID: String) {
        var list = startupProcesses(for: containerID)
        if let idx = list.firstIndex(where: { $0.windowsExePath.lowercased() == proc.windowsExePath.lowercased() }) {
            list[idx] = proc
        } else {
            list.append(proc)
        }
        saveStartupProcesses(list, for: containerID)
    }

    public func removeStartupProcess(id: UUID, for containerID: String) {
        var list = startupProcesses(for: containerID)
        list.removeAll { $0.id == id }
        saveStartupProcesses(list, for: containerID)
    }

    public func toggleStartupProcess(id: UUID, for containerID: String) {
        var list = startupProcesses(for: containerID)
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx].enabled.toggle()
            saveStartupProcesses(list, for: containerID)
        }
    }

    public func autoDiscoverStartupProcesses(for containerID: String) {
        let driveC = driveCURL(for: containerID)
        let existing = startupProcesses(for: containerID)

        for profile in SoftwareProfileManager.shared.allProfiles() {
            for svc in profile.autoStartServices {
                let normalizedRel = svc.windowsExePath
                    .replacingOccurrences(of: "\\", with: "/")
                    .replacingOccurrences(of: "C:/", with: "", options: [.caseInsensitive, .anchored])
                let exeURL = driveC.appendingPathComponent(normalizedRel)
                guard FileManager.default.fileExists(atPath: exeURL.path) else { continue }

                let alreadyRegistered = existing.contains {
                    $0.windowsExePath.lowercased() == svc.windowsExePath.lowercased()
                }
                guard !alreadyRegistered else { continue }

                var args: [String] = []
                var relWorkDir: String? = nil
                if let licRel = svc.licenseDirRelativeToDriveC, !licRel.isEmpty {
                    relWorkDir = licRel
                    let licDir = driveC.appendingPathComponent(licRel, isDirectory: true)
                    if let files = try? FileManager.default.contentsOfDirectory(at: licDir, includingPropertiesForKeys: nil),
                       let licFile = files.first(where: { $0.pathExtension.lowercased() == "lic" }) {
                        let winDir = "C:\\" + licRel.replacingOccurrences(of: "/", with: "\\")
                        let licName = licFile.lastPathComponent
                        let logName = licFile.deletingPathExtension().lastPathComponent + ".log"
                        args = ["-c", "\(winDir)\\\(licName)", "-l", "\(winDir)\\\(logName)", "-z2"]
                    }
                }

                let proc = ContainerStartupProcess(
                    name: svc.name,
                    windowsExePath: svc.windowsExePath,
                    arguments: args,
                    workingDirectoryRelativeToDriveC: relWorkDir,
                    tcpPort: svc.tcpPort,
                    processMatchName: exeURL.lastPathComponent,
                    enabled: true
                )
                registerStartupProcess(proc, for: containerID)
            }
        }
    }

    private func isTCPPortListening(_ port: Int) -> Bool {
        let checkProc = Process()
        checkProc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        checkProc.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN"]
        checkProc.standardOutput = Pipe()
        checkProc.standardError = Pipe()
        do {
            try checkProc.run()
            checkProc.waitUntilExit()
            return checkProc.terminationStatus == 0
        } catch {
            return false
        }
    }

    public func isStartupProcessRunning(_ proc: ContainerStartupProcess, in containerID: String) -> Bool {
        if let port = proc.tcpPort, isTCPPortListening(port) {
            return true
        }
        guard isContainerRunning(containerID) else { return false }
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-e", "-o", "args="]
        let pipe = Pipe()
        ps.standardOutput = pipe
        ps.standardError = Pipe()
        do {
            try ps.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            ps.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            let needle = proc.processMatchName.lowercased()
            for line in output.split(separator: "\n") {
                if line.lowercased().contains(needle) {
                    return true
                }
            }
        } catch {
            return false
        }
        return false
    }

    private func updateLaunchStep(sessionID: UUID, stepID: UUID, state: LaunchStepState, detail: String? = nil) {
        guard var session = activeLaunchSession, session.id == sessionID else { return }
        if let idx = session.steps.firstIndex(where: { $0.id == stepID }) {
            session.steps[idx].state = state
            if let detail {
                session.steps[idx].detail = detail
            }
            activeLaunchSession = session
        }
    }

    private func scheduleAutoDismissLaunchSession(sessionID: UUID, delayNanoseconds: UInt64 = 800_000_000) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard let self,
                  let current = self.activeLaunchSession,
                  current.id == sessionID,
                  current.isFinished,
                  !current.hasError else { return }
            self.activeLaunchSession = nil
        }
    }

    private func bootContainerStartupProcesses(
        containerID: String,
        wineBin: URL,
        sessionID: UUID,
        serviceStepMap: [UUID: UUID]
    ) async {
        let targetPrefix = containerURL(for: containerID)
        let driveC = driveCURL(for: containerID)
        let enabledProcs = startupProcesses(for: containerID).filter(\.enabled)

        for proc in enabledProcs {
            guard let stepID = serviceStepMap[proc.id] else { continue }
            updateLaunchStep(sessionID: sessionID, stepID: stepID, state: .inProgress, detail: "Checking if already running...")

            if isStartupProcessRunning(proc, in: containerID) {
                let portNote = proc.tcpPort.map { " (listening on TCP :\($0))" } ?? ""
                updateLaunchStep(
                    sessionID: sessionID,
                    stepID: stepID,
                    state: .alreadyRunning,
                    detail: "Reusing active background process\(portNote) — no duplicate started."
                )
                continue
            }

            let exeURL = proc.unixExeURL(in: driveC)
            guard FileManager.default.fileExists(atPath: exeURL.path) else {
                updateLaunchStep(
                    sessionID: sessionID,
                    stepID: stepID,
                    state: .skipped,
                    detail: "Executable not found at \(proc.windowsExePath)"
                )
                continue
            }

            updateLaunchStep(sessionID: sessionID, stepID: stepID, state: .inProgress, detail: "Starting \(proc.processMatchName)...")
            let launch = wineLaunchCommand(
                wineBin: wineBin,
                arguments: [proc.windowsExePath] + proc.arguments,
                containerID: containerID
            )
            let startProc = Process()
            startProc.executableURL = launch.executable
            startProc.arguments = launch.arguments
            var env = ProcessInfo.processInfo.environment
            env["WINEPREFIX"] = targetPrefix.path
            env["WINEDEBUG"] = "-all"
            startProc.environment = env
            if let relWork = proc.workingDirectoryRelativeToDriveC, !relWork.isEmpty {
                let workURL = driveC.appendingPathComponent(relWork, isDirectory: true)
                if FileManager.default.fileExists(atPath: workURL.path) {
                    startProc.currentDirectoryURL = workURL
                }
            }
            startProc.standardOutput = Pipe()
            startProc.standardError = Pipe()

            do {
                try startProc.run()
                if let port = proc.tcpPort {
                    var ready = false
                    for _ in 0..<40 {
                        if isTCPPortListening(port) {
                            ready = true
                            break
                        }
                        try? await Task.sleep(nanoseconds: 250_000_000)
                    }
                    if ready {
                        updateLaunchStep(sessionID: sessionID, stepID: stepID, state: .succeeded, detail: "Started and listening on TCP :\(port)")
                    } else {
                        updateLaunchStep(sessionID: sessionID, stepID: stepID, state: .failed, detail: "Started, but TCP :\(port) did not open within 10s")
                    }
                } else {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    updateLaunchStep(sessionID: sessionID, stepID: stepID, state: .succeeded, detail: "Started in background")
                }
            } catch {
                updateLaunchStep(sessionID: sessionID, stepID: stepID, state: .failed, detail: error.localizedDescription)
            }
        }
        refreshRunningContainers()
    }

    public func containerURL(for containerID: String) -> URL {
        containersURL.appendingPathComponent(containerID, isDirectory: true)
    }

    public func driveCURL(for containerID: String) -> URL {
        containerURL(for: containerID).appendingPathComponent("drive_c", isDirectory: true)
    }

    public func bootstrap() async {
        detectWineApp()
        if wineAppURL == nil {
            needsWineRuntimeSetup = true
            statusMessage = "MetalSharp-Wine runtime required"
            return
        }
        needsWineRuntimeSetup = false
        await ensureEngineReady()
    }

    private static let savedWinePathKey = "ZinkKrisp.wineAppPath"

    private func normalizeWineAppURL(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        if let range = standardized.path.range(of: ".app/Contents/lib/wine/") {
            let outerPath = String(standardized.path[..<range.lowerBound]) + ".app"
            let outerURL = URL(fileURLWithPath: outerPath)
            if FileManager.default.fileExists(atPath: outerURL.path) {
                return outerURL
            }
        }
        return standardized
    }

    public func saveWineAppURL(_ url: URL) {
        let normalized = normalizeWineAppURL(url)
        wineAppURL = normalized
        UserDefaults.standard.set(normalized.path, forKey: Self.savedWinePathKey)
    }

    public func detectWineApp() {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let envWine = ProcessInfo.processInfo.environment["ZINKKRISP_WINE_APP"], !envWine.isEmpty {
            candidates.append(normalizeWineAppURL(URL(fileURLWithPath: envWine)))
        }
        if let savedPath = UserDefaults.standard.string(forKey: Self.savedWinePathKey), !savedPath.isEmpty {
            candidates.append(normalizeWineAppURL(URL(fileURLWithPath: savedPath)))
        }
        candidates.append(URL(fileURLWithPath: "/Applications/MetalSharp-Wine.app"))
        candidates.append(fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/MetalSharp-Wine.app"))
        candidates.append(runtimeURL.appendingPathComponent("MetalSharp-Wine.app"))
        if let wsURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.metalsharp.wine") {
            candidates.append(normalizeWineAppURL(wsURL))
        }

        for candidate in candidates {
            if resolveWineBinary(in: candidate) != nil {
                saveWineAppURL(candidate)
                return
            }
        }
        wineAppURL = nil
    }

    public func resolveWineBinary(in appURL: URL) -> URL? {
        let base = normalizeWineAppURL(appURL)
        let fm = FileManager.default
        let candidates = [
            base.appendingPathComponent("Contents/MacOS/wine"),
            base.appendingPathComponent("Contents/Resources/wine/bin/wine64"),
            base.appendingPathComponent("Contents/Resources/wine/bin/wine")
        ]
        for bin in candidates where fm.isExecutableFile(atPath: bin.path) {
            return bin
        }
        return nil
    }

    public func resolveWineserverBinary(in appURL: URL) -> URL? {
        let base = normalizeWineAppURL(appURL)
        let fm = FileManager.default
        let candidates = [
            base.appendingPathComponent("Contents/MacOS/wineserver"),
            base.appendingPathComponent("Contents/bin/wineserver"),
            base.appendingPathComponent("Contents/Resources/wine/bin/wineserver")
        ]
        for bin in candidates where fm.isExecutableFile(atPath: bin.path) {
            return bin
        }
        return nil
    }

    public func payloadURL() -> URL? {
        let fm = FileManager.default
        if let resURL = Bundle.main.resourceURL {
            let bundled = resURL.appendingPathComponent("Payload", isDirectory: true)
            if fm.fileExists(atPath: bundled.path) {
                return bundled
            }
        }
        let cwdPayload = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("Payload", isDirectory: true)
        if fm.fileExists(atPath: cwdPayload.path) {
            return cwdPayload
        }
        return nil
    }

    public func thirdPartyLicensesText() -> String {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let resURL = Bundle.main.resourceURL {
            candidates.append(resURL.appendingPathComponent("THIRD_PARTY_LICENSES.txt"))
            candidates.append(resURL.appendingPathComponent("Payload/THIRD_PARTY_LICENSES.txt"))
        }
        candidates.append(URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("Payload/THIRD_PARTY_LICENSES.txt"))
        for url in candidates {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return "Mesa 3D (MIT), zlib (zlib License), llvm-mingw (Apache-2.0 with LLVM Exception / ZPL 2.1). External runtime: MetalSharp-Wine (AGPL-3.0) / Wine (LGPL-2.1+) / FEX-Emu (MIT)."
    }

    public func ensureEngineReady() async {
        guard let wineApp = wineAppURL, let wineBin = resolveWineBinary(in: wineApp) else {
            needsWineRuntimeSetup = true
            isReady = false
            return
        }

        isBusy = true
        errorMessage = nil
        statusMessage = "Preparing OpenGL 4.6 -> Metal 4 runtime..."

        do {
            let fm = FileManager.default
            try fm.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            try fm.createDirectory(at: containersURL, withIntermediateDirectories: true)
            try fm.createDirectory(at: runtimeURL, withIntermediateDirectories: true)

            guard let payload = payloadURL() else {
                throw NSError(domain: "ZinkKrisp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing Payload directory inside ZinkKrisp bundle."])
            }

            // 1. Copy macOS arm64 KosmicKrisp + bundled dylibs and generate dynamic ICD JSON
            let macSrcDir = payload.appendingPathComponent("macos-arm64", isDirectory: true)
            let dylibs = try fm.contentsOfDirectory(at: macSrcDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "dylib" }
            for dylib in dylibs {
                let dest = runtimeURL.appendingPathComponent(dylib.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: dylib, to: dest)
            }

            let kkDest = runtimeURL.appendingPathComponent("libvulkan_kosmickrisp.dylib")
            let icdDict: [String: Any] = [
                "file_format_version": "1.0.0",
                "ICD": [
                    "api_version": "1.4.303",
                    "library_path": kkDest.path
                ]
            ]
            let icdData = try JSONSerialization.data(withJSONObject: icdDict, options: [.prettyPrinted, .sortedKeys])
            try icdData.write(to: icdJSONURL)

            // 2. Initialize Golden TemplatePrefix if needed
            let templateDriveC = templatePrefixURL.appendingPathComponent("drive_c", isDirectory: true)
            let sys32URL = templateDriveC.appendingPathComponent("windows/system32", isDirectory: true)
            let isFirstInit = !fm.fileExists(atPath: sys32URL.path)
            if isFirstInit {
                statusMessage = "Initializing Golden TemplatePrefix (first run)..."
                try fm.createDirectory(at: templatePrefixURL, withIntermediateDirectories: true)
                _ = try await runProcess(
                    executable: wineBin,
                    arguments: ["wineboot", "-u"],
                    environment: buildEnvironment(for: nil, prefixURL: templatePrefixURL)
                )
            }

            // 3. Inject COFF-ARM64EC Zink DLLs into TemplatePrefix
            let winSrcDir = payload.appendingPathComponent("win64-arm64ec", isDirectory: true)
            for dllName in ["opengl32.dll", "libgallium_wgl.dll", "libz-1.dll"] {
                let src = winSrcDir.appendingPathComponent(dllName)
                let dst = sys32URL.appendingPathComponent(dllName)
                if fm.fileExists(atPath: src.path) {
                    if fm.fileExists(atPath: dst.path) {
                        try fm.removeItem(at: dst)
                    }
                    try fm.copyItem(at: src, to: dst)
                }
            }

            // 3b. Inject WebView2 Bridge & Stub Prerequisite into TemplatePrefix
            let bridgeSrcDir = payload.appendingPathComponent("webview_bridge", isDirectory: true)
            if fm.fileExists(atPath: bridgeSrcDir.path) {
                // Keep Wine's original aarch64/i386 version.dll intact; restore version_real.dll if left behind
                let realVer = sys32URL.appendingPathComponent("version_real.dll")
                let wineVer = sys32URL.appendingPathComponent("version.dll")
                if fm.fileExists(atPath: realVer.path) {
                    if fm.fileExists(atPath: wineVer.path) { try? fm.removeItem(at: wineVer) }
                    try? fm.moveItem(at: realVer, to: wineVer)
                }
                let v64Src = bridgeSrcDir.appendingPathComponent("version64.dll")
                if fm.fileExists(atPath: v64Src.path) {
                    let guard64Dst = sys32URL.appendingPathComponent("zk_deadlock_guard64.dll")
                    if fm.fileExists(atPath: guard64Dst.path) { try? fm.removeItem(at: guard64Dst) }
                    try? fm.copyItem(at: v64Src, to: guard64Dst)
                }

                let wow64URL = templateDriveC.appendingPathComponent("windows/syswow64", isDirectory: true)
                try? fm.createDirectory(at: wow64URL, withIntermediateDirectories: true)
                let realVer32 = wow64URL.appendingPathComponent("version_real.dll")
                let wineVer32 = wow64URL.appendingPathComponent("version.dll")
                if fm.fileExists(atPath: realVer32.path) {
                    if fm.fileExists(atPath: wineVer32.path) { try? fm.removeItem(at: wineVer32) }
                    try? fm.moveItem(at: realVer32, to: wineVer32)
                }

                // zk_bridge32.dll -> syswow64/zk_bridge.dll
                let zk32Src = bridgeSrcDir.appendingPathComponent("zk_bridge32.dll")
                let zk32Dst = wow64URL.appendingPathComponent("zk_bridge.dll")
                if fm.fileExists(atPath: zk32Src.path) {
                    if fm.fileExists(atPath: zk32Dst.path) { try? fm.removeItem(at: zk32Dst) }
                    try? fm.copyItem(at: zk32Src, to: zk32Dst)
                }

                // Deploy 0-exit stub MicrosoftEdgeWebView2RuntimeInstallerX64.exe to sldim directory
                let sldimDir = templateDriveC.appendingPathComponent("sldim", isDirectory: true)
                try? fm.createDirectory(at: sldimDir, withIntermediateDirectories: true)
                let stubSrc = bridgeSrcDir.appendingPathComponent("MicrosoftEdgeWebView2RuntimeInstallerX64.exe")
                let stubDst = sldimDir.appendingPathComponent("MicrosoftEdgeWebView2RuntimeInstallerX64.exe")
                if fm.fileExists(atPath: stubSrc.path) {
                    if fm.fileExists(atPath: stubDst.path) { try? fm.removeItem(at: stubDst) }
                    try? fm.copyItem(at: stubSrc, to: stubDst)
                }

                // auto_resize_daemon.exe -> windows/auto_resize_daemon.exe
                let daemonSrc = bridgeSrcDir.appendingPathComponent("auto_resize_daemon.exe")
                let daemonDst = templateDriveC.appendingPathComponent("windows/auto_resize_daemon.exe")
                if fm.fileExists(atPath: daemonSrc.path) {
                    if fm.fileExists(atPath: daemonDst.path) { try? fm.removeItem(at: daemonDst) }
                    try? fm.copyItem(at: daemonSrc, to: daemonDst)
                }
            }

            // 4. Apply workstation defaults registry on first init of TemplatePrefix
            let regMarker = templatePrefixURL.appendingPathComponent(".registry_initialized")
            if !fm.fileExists(atPath: regMarker.path) {
                let regURL = payload.appendingPathComponent("registry/workstation_defaults.reg")
                if fm.fileExists(atPath: regURL.path) {
                    statusMessage = "Applying Retina & CAD OpenGL registry defaults..."
                    _ = try await runProcess(
                        executable: wineBin,
                        arguments: ["regedit", "/S", regURL.path],
                        environment: buildEnvironment(for: nil, prefixURL: templatePrefixURL)
                    )
                    if let wineserver = resolveWineserverBinary(in: wineApp) {
                        _ = try? await runProcess(
                            executable: wineserver,
                            arguments: ["-w"],
                            environment: buildEnvironment(for: nil, prefixURL: templatePrefixURL)
                        )
                    }
                    try Data().write(to: regMarker)
                }
            }

            isReady = true
            statusMessage = "OpenGL 4.6 -> Metal 4 Ready (Native ARM64)"
        } catch {
            isReady = false
            errorMessage = error.localizedDescription
            statusMessage = "Runtime setup failed"
        }

        isBusy = false
    }

    public func buildEnvironment(for app: InstalledApp?, prefixURL: URL, profileOverride: SoftwareProfile? = nil) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefixURL.path
        env["WINEDEBUG"] = "-all"
        env["WINEDLLOVERRIDES"] = "opengl32=n,b"
        env["VK_DRIVER_FILES"] = icdJSONURL.path
        env["VK_ICD_FILENAMES"] = icdJSONURL.path
        env["WINEMSYNC"] = "1"
        env["FEX_TSOENABLED"] = "0"
        env["FEX_VECTORTSOENABLED"] = "0"
        env["FEX_MEMCPYSETTSOENABLED"] = "0"
        env["FEX_HALFBARRIERTSOENABLED"] = "0"
        env["FEX_MULTIBLOCK"] = "1"
        env["FEX_MAXINST"] = "5000"
        env["mesa_glthread"] = "true"
        env["MESA_LOADER_DRIVER_OVERRIDE"] = "zink"
        env["MESA_GL_VERSION_OVERRIDE"] = "4.6COMPAT"
        env["MESA_GLSL_VERSION_OVERRIDE"] = "460"
        env["MESA_KK_EXPERIMENTAL"] = "custom_border"
        env["KK_SPOOF_SMOOTH_LINES"] = (app?.cadWireframeFastPath ?? true) ? "1" : "0"
        env["KK_CLAMP_VIEW_MISMATCH"] = "1"
        env["KK_SYNC_BACKING_SCALE"] = "0"
        env["MTL_HUD_ENABLED"] = (app?.showMetalHUD ?? false) ? "1" : "0"
        env["WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS"] = "--remote-debugging-port=9222 --remote-allow-origins=* --no-sandbox --in-process-gpu --disable-direct-composition --disable-features=RemoveRedirectionBitmap,DirectComposition,CalculateNativeWinOcclusion --edge-webview-disable-mojo-ipcz --disk-cache-size=1 --media-cache-size=1 --disable-gpu-shader-disk-cache --disable-application-cache --disable-background-networking --disable-component-update --disable-domain-reliability --disable-sync"

        var dllOverrides: [String: String] = ["opengl32": "n,b"]
        let resolvedProfile = profileOverride ?? app.flatMap { SoftwareProfileManager.shared.profile(for: $0) }
        if let profile = resolvedProfile {
            for (k, v) in profile.environment {
                env[k] = v
            }
            for (k, v) in profile.dllOverrides {
                dllOverrides[k] = v
            }
        }
        if let customEnv = app?.customEnvironment {
            for (k, v) in customEnv {
                env[k] = v
            }
        }
        if let customOverrides = app?.customDllOverrides {
            for (k, v) in customOverrides {
                dllOverrides[k] = v
            }
        }
        env["WINEDLLOVERRIDES"] = dllOverrides.keys.sorted().map { "\($0)=\(dllOverrides[$0]!)" }.joined(separator: ";")
        return env
    }

    public func sanitizeContainerName(_ appName: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = appName
            .components(separatedBy: invalid)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Container" : String(cleaned.prefix(40))
    }

    public func containerExists(named appName: String) -> Bool {
        let candidate = sanitizeContainerName(appName).lowercased()
        return containerIDs.contains { $0.lowercased() == candidate }
    }

    public func makeContainerID(for appName: String) -> String {
        let base = sanitizeContainerName(appName)
        if !containerExists(named: base) {
            return base
        }
        var index = 2
        while containerExists(named: "\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }

    public func cloneTemplatePrefix(to destinationURL: URL) async throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        try fm.createDirectory(at: containersURL, withIntermediateDirectories: true)

        let cpURL = URL(fileURLWithPath: "/bin/cp")
        let cowStatus = try await runProcess(
            executable: cpURL,
            arguments: ["-cR", templatePrefixURL.path, destinationURL.path],
            environment: [:]
        )
        if cowStatus != 0 {
            if fm.fileExists(atPath: destinationURL.path) {
                try? fm.removeItem(at: destinationURL)
            }
            let fallbackStatus = try await runProcess(
                executable: cpURL,
                arguments: ["-R", templatePrefixURL.path, destinationURL.path],
                environment: [:]
            )
            if fallbackStatus != 0 {
                throw NSError(
                    domain: "ZinkKrisp",
                    code: Int(fallbackStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to clone TemplatePrefix to \(destinationURL.lastPathComponent)."]
                )
            }
        }
    }

    public static let offlineMarkerName = ".zinkkrisp_offline"
    public static let offlineSandboxProfile = "(version 1) (allow default) (deny network-outbound (remote ip \"*:*\")) (deny network-inbound (local ip \"*:*\")) (allow network-outbound (remote ip \"localhost:*\")) (allow network-inbound (local ip \"localhost:*\"))"

    public func isInternetEnabled(for containerID: String) -> Bool {
        let marker = containerURL(for: containerID).appendingPathComponent(Self.offlineMarkerName)
        return !FileManager.default.fileExists(atPath: marker.path)
    }

    public func setInternetEnabled(_ enabled: Bool, for containerID: String) async {
        let targetPrefix = containerURL(for: containerID)
        let marker = targetPrefix.appendingPathComponent(Self.offlineMarkerName)
        let fm = FileManager.default

        if enabled {
            if fm.fileExists(atPath: marker.path) {
                try? fm.removeItem(at: marker)
            }
        } else {
            try? Data().write(to: marker)
        }

        if isContainerRunning(containerID) {
            await stopContainer(containerID: containerID, force: true)
        }

        objectWillChange.send()
        statusMessage = enabled
            ? "Internet enabled for container \(containerID)"
            : "Internet disabled (offline sandbox) for container \(containerID)"
    }

    private func wineLaunchCommand(wineBin: URL, arguments: [String], containerID: String) -> (executable: URL, arguments: [String]) {
        if isInternetEnabled(for: containerID) {
            return (wineBin, arguments)
        }
        return (
            URL(fileURLWithPath: "/usr/bin/sandbox-exec"),
            ["-p", Self.offlineSandboxProfile, wineBin.path] + arguments
        )
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func confirmRegImport(url: URL, containerName: String) -> Bool {
        let rawData = try? Data(contentsOf: url)
        let decoded: String = rawData.flatMap {
            String(data: $0, encoding: .utf8)
                ?? String(data: $0, encoding: .utf16LittleEndian)
                ?? String(data: $0, encoding: .ascii)
        } ?? ""
        let previewLines = decoded
            .components(separatedBy: .newlines)
            .prefix(12)
            .joined(separator: "\n")
        let truncatedPreview = previewLines.count > 600
            ? String(previewLines.prefix(600)) + "\n..."
            : previewLines

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Import Registry File into \"\(containerName)\"?"
        alert.informativeText = "File: \(url.lastPathComponent)"
            + (truncatedPreview.isEmpty ? "" : "\n\nPreview:\n\(truncatedPreview)")
        alert.addButton(withTitle: "Import Registry")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func launchBatchInTerminal(url: URL, containerID: String, wineBin: URL, env: [String: String]) {
        let launch = wineLaunchCommand(wineBin: wineBin, arguments: ["cmd", "/c", url.path], containerID: containerID)
        let keysToExport = [
            "WINEPREFIX", "WINEDEBUG", "WINEDLLOVERRIDES",
            "VK_DRIVER_FILES", "VK_ICD_FILENAMES", "WINEMSYNC",
            "FEX_TSOENABLED", "FEX_VECTORTSOENABLED", "FEX_MEMCPYSETTSOENABLED",
            "FEX_HALFBARRIERTSOENABLED", "FEX_MULTIBLOCK", "FEX_MAXINST",
            "mesa_glthread", "KK_SPOOF_SMOOTH_LINES", "KK_CLAMP_VIEW_MISMATCH",
            "MTL_HUD_ENABLED"
        ]
        var exportLines: [String] = []
        for key in keysToExport {
            if let val = env[key] {
                exportLines.append("export \(key)=\(shellQuote(val))")
            }
        }
        let quotedCmd = ([launch.executable.path] + launch.arguments).map { shellQuote($0) }.joined(separator: " ")
        let workDir = url.deletingLastPathComponent().path
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zinkkrisp_bat_\(UUID().uuidString).command")

        let script = """
        #!/usr/bin/env bash
        \(exportLines.joined(separator: "\n"))
        rm -f \(shellQuote(scriptURL.path))
        MY_TTY="$(tty 2>/dev/null || true)"
        cd \(shellQuote(workDir)) || exit 1
        echo "=== ZinkKrisp: Running \(url.lastPathComponent) in container \(containerID) ==="
        # Feed newline/EOF to cmd.exe so batch 'pause' commands do not hang in Wine's conhost --unix
        printf '\\r\\n' | \(quotedCmd)
        EXIT_CODE=${PIPESTATUS[1]}
        echo ""
        echo "=== Finished with exit code $EXIT_CODE ==="
        if [[ -n "$MY_TTY" ]]; then
            (sleep 0.6; /usr/bin/osascript -e 'tell application "Terminal" to close (every window whose (tty of tabs) contains "'"$MY_TTY"'")' >/dev/null 2>&1) &
        fi
        exit $EXIT_CODE
        """

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            let openProc = Process()
            openProc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            openProc.arguments = ["-a", "Terminal", scriptURL.path]
            try openProc.run()
        } catch {
            errorMessage = "Failed to open Terminal for \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    public func containerID(containing url: URL) -> String? {
        let base = containersURL.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        let target = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard let range = target.range(of: base, options: [.caseInsensitive, .anchored]) else { return nil }
        let remainder = String(target[range.upperBound...])
        guard let firstSlash = remainder.firstIndex(of: "/") else { return nil }
        let cid = String(remainder[..<firstSlash])
        guard !cid.isEmpty else { return nil }
        return containerIDs.first(where: { $0.lowercased() == cid.lowercased() }) ?? cid
    }

    public func handleOpenedFile(_ url: URL) async {
        let ext = url.pathExtension.lowercased()
        guard ["exe", "msi", "bat", "cmd", "reg", "zip"].contains(ext) else { return }

        if wineAppURL == nil {
            detectWineApp()
        }
        guard let wineApp = wineAppURL, resolveWineBinary(in: wineApp) != nil else {
            needsWineRuntimeSetup = true
            pendingNewAppInstallerURL = url
            return
        }
        if !isReady {
            await ensureEngineReady()
        }
        guard isReady else { return }

        if let cid = containerID(containing: url) {
            await runFileInContainer(containerID: cid, containerName: cid, url: url)
        } else {
            pendingNewAppInstallerURL = url
        }
    }

    public func createNewAppAndRunInstaller(appName: String, installerURL: URL?, allowInternet: Bool = true) async {
        guard wineAppURL != nil else {
            needsWineRuntimeSetup = true
            return
        }
        if !isReady {
            await ensureEngineReady()
        }
        guard isReady else { return }

        let cleanName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = installerURL?.deletingPathExtension().lastPathComponent ?? "Container"
        let containerLabel = cleanName.isEmpty ? fallbackName : cleanName
        let newContainerID = makeContainerID(for: containerLabel)
        let newContainerURL = containerURL(for: newContainerID)

        isBusy = true
        errorMessage = nil
        statusMessage = "Cloning isolated APFS container for \(containerLabel)..."

        do {
            try await cloneTemplatePrefix(to: newContainerURL)
            if !allowInternet {
                let marker = newContainerURL.appendingPathComponent(Self.offlineMarkerName)
                try? Data().write(to: marker)
            }
            refreshContainers()
        } catch {
            errorMessage = error.localizedDescription
            isBusy = false
            return
        }

        if let installerURL {
            await runFileInContainer(containerID: newContainerID, containerName: containerLabel, url: installerURL)
        } else {
            isBusy = false
            statusMessage = "Created isolated container \(newContainerID)"
        }
    }

    public func runFileInContainer(containerID: String, containerName: String, url: URL) async {
        guard let wineApp = wineAppURL, let wineBin = resolveWineBinary(in: wineApp) else {
            needsWineRuntimeSetup = true
            return
        }
        if !isReady {
            await ensureEngineReady()
        }
        guard isReady else { return }

        let ext = url.pathExtension.lowercased()
        if ext == "reg" {
            guard confirmRegImport(url: url, containerName: containerName) else {
                statusMessage = "Cancelled registry import: \(url.lastPathComponent)"
                return
            }
        }

        let targetPrefix = containerURL(for: containerID)
        let targetDriveC = driveCURL(for: containerID)
        let matchedProfile = (ext == "exe")
            ? SoftwareProfileManager.shared.allProfiles().first { profile in
                profile.exeNames.contains { $0.lowercased() == url.lastPathComponent.lowercased() }
            }
            : nil
        if let matchedProfile, ext == "exe" {
            let statuses = PrerequisiteManager.shared.checkRequirements(for: matchedProfile, in: targetPrefix)
            if statuses.contains(where: { !$0.isSatisfied }) {
                let relPath: String
                let basePath = targetDriveC.standardizedFileURL.path + "/"
                let fullPath = url.standardizedFileURL.path
                if fullPath.hasPrefix(basePath) {
                    relPath = String(fullPath.dropFirst(basePath.count))
                } else {
                    relPath = fullPath
                }
                let tempApp = InstalledApp(
                    containerID: containerID,
                    name: matchedProfile.displayName,
                    exeRelativePath: relPath,
                    profileID: matchedProfile.id
                )
                pendingRequirementsStatuses = statuses
                prereqErrorMessage = nil
                pendingRequirementsApp = tempApp
                statusMessage = "Missing required runtime components for \(matchedProfile.displayName)."
                return
            }
        }
        let env = buildEnvironment(for: nil, prefixURL: targetPrefix, profileOverride: matchedProfile)

        if ext == "bat" || ext == "cmd" {
            launchBatchInTerminal(url: url, containerID: containerID, wineBin: wineBin, env: env)
            statusMessage = "Opened \(url.lastPathComponent) in Terminal (\(containerName))"
            return
        }

        isBusy = true
        errorMessage = nil
        installerRunningName = "\(containerName): \(url.lastPathComponent)"
        statusMessage = "Running \(url.lastPathComponent) in container \(containerID)..."

        let snapshot = ExeScanner.shared.takeSnapshot(in: targetDriveC)

        do {
            var exitCode: Int32 = 0
            if ext == "zip" {
                let progFiles = targetDriveC.appendingPathComponent("Program Files", isDirectory: true)
                let appFolder = progFiles.appendingPathComponent(containerName, isDirectory: true)
                try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
                statusMessage = "Extracting \(url.lastPathComponent) to Program Files/\(containerName)..."
                exitCode = try await runProcess(
                    executable: URL(fileURLWithPath: "/usr/bin/ditto"),
                    arguments: ["-x", "-k", url.path, appFolder.path],
                    environment: [:]
                )
            } else {
                let args: [String]
                switch ext {
                case "msi":
                    args = ["msiexec", "/i", url.path]
                case "reg":
                    args = ["regedit", "/S", url.path]
                default:
                    args = [url.path]
                }

                let launch = wineLaunchCommand(wineBin: wineBin, arguments: args, containerID: containerID)
                var launchSessionID: UUID?
                var execStepID: UUID?
                if ext == "exe" || ext == "msi" {
                    autoDiscoverStartupProcesses(for: containerID)
                    let enabledStartup = startupProcesses(for: containerID).filter(\.enabled)
                    let wasUp = isContainerRunning(containerID)
                    let containerStep = LaunchStatusStep(
                        title: "Container \(containerID)",
                        detail: wasUp ? "Container is already running" : "Booting container runtime",
                        state: wasUp ? .alreadyRunning : .succeeded
                    )
                    var steps: [LaunchStatusStep] = [containerStep]
                    var serviceStepMap: [UUID: UUID] = [:]
                    if enabledStartup.isEmpty {
                        steps.append(LaunchStatusStep(
                            title: "Background Startup Processes",
                            detail: "None registered for this container",
                            state: .skipped
                        ))
                    } else {
                        for proc in enabledStartup {
                            let s = LaunchStatusStep(title: "Startup: \(proc.name)", detail: "Queued", state: .pending)
                            steps.append(s)
                            serviceStepMap[proc.id] = s.id
                        }
                    }
                    let execStep = LaunchStatusStep(
                        title: "Launch \(url.lastPathComponent)",
                        detail: "Waiting for startup processes...",
                        state: .pending
                    )
                    steps.append(execStep)
                    let session = LaunchStatusSession(
                        containerID: containerID,
                        executableName: url.lastPathComponent,
                        steps: steps
                    )
                    activeLaunchSession = session
                    launchSessionID = session.id
                    execStepID = execStep.id

                    await bootContainerStartupProcesses(
                        containerID: containerID,
                        wineBin: wineBin,
                        sessionID: session.id,
                        serviceStepMap: serviceStepMap
                    )
                    await clearPendingRebootFlags(containerID: containerID, prefixURL: targetPrefix, wineBin: wineBin, env: env)
                    updateLaunchStep(
                        sessionID: session.id,
                        stepID: execStep.id,
                        state: .inProgress,
                        detail: "Running \(url.lastPathComponent)..."
                    )
                }

                startWebViewBridgeWatchdog(containerID: containerID, prefixURL: targetPrefix, wineBin: wineBin)
                let rebootSweeper = Task { [weak self] in
                    guard let self else { return }
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        if Task.isCancelled { break }
                        await self.clearPendingRebootFlags(containerID: containerID, prefixURL: targetPrefix, wineBin: wineBin, env: env)
                    }
                }
                defer { rebootSweeper.cancel() }
                exitCode = try await runProcess(
                    executable: launch.executable,
                    arguments: launch.arguments,
                    environment: env,
                    workingDirectory: url.deletingLastPathComponent()
                )
                rebootSweeper.cancel()
                if let sid = launchSessionID, let eid = execStepID {
                    updateLaunchStep(
                        sessionID: sid,
                        stepID: eid,
                        state: exitCode == 0 ? .succeeded : .failed,
                        detail: "Exited with code \(exitCode)"
                    )
                    if var s = activeLaunchSession, s.id == sid {
                        s.isFinished = true
                        s.hasError = (exitCode != 0)
                        activeLaunchSession = s
                    }
                    if exitCode == 0 {
                        scheduleAutoDismissLaunchSession(sessionID: sid)
                    }
                }
                let hasPersistentServices = !startupProcesses(for: containerID).filter(\.enabled).isEmpty
                if hasPersistentServices {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                } else if let wineserver = resolveWineserverBinary(in: wineApp) {
                    _ = try? await runProcess(executable: wineserver, arguments: ["-w"], environment: env)
                }
                refreshRunningContainers()
            }

            if ext == "reg" {
                if exitCode == 0 {
                    statusMessage = "Imported registry file into \(containerName)"
                } else {
                    errorMessage = "Registry import exited with code \(exitCode)"
                }
            } else {
                let containerApps = libraryApps.filter { $0.containerID == containerID }
                let found = ExeScanner.shared.scanForNewExes(in: targetDriveC, since: snapshot, existingLibrary: containerApps)
                activeContainerID = containerID
                activeContainerName = containerName
                discoveredExes = found
                showExeSelectionSheet = true
                statusMessage = "OpenGL 4.6 -> Metal 4 Ready (Native ARM64)"
            }
        } catch {
            errorMessage = "Installer failed: \(error.localizedDescription)"
        }

        installerRunningName = nil
        isBusy = false
    }

    public func scanContainer(containerID: String, containerName: String) {
        let targetDriveC = driveCURL(for: containerID)
        let containerApps = libraryApps.filter { $0.containerID == containerID }
        activeContainerID = containerID
        activeContainerName = containerName
        discoveredExes = ExeScanner.shared.scanAllApps(in: targetDriveC, existingLibrary: containerApps)
        showExeSelectionSheet = true
    }

    public func addSelectedExes(_ selected: [DiscoveredExe], createMacApps: Bool) {
        guard let wineApp = wineAppURL, let wineBin = resolveWineBinary(in: wineApp) else { return }
        let targetContainerID = activeContainerID ?? makeContainerID(for: "app")
        let targetPrefix = containerURL(for: targetContainerID)

        for item in selected where item.isSelected {
            var app = InstalledApp(
                containerID: targetContainerID,
                name: item.productName,
                exeRelativePath: item.relativePath,
                architecture: item.architecture
            )
            if createMacApps {
                if let bundleURL = try? MacAppGenerator.createMacApp(
                    for: app,
                    icon: item.icon,
                    prefixURL: targetPrefix,
                    icdJSONURL: icdJSONURL,
                    wineBinaryURL: wineBin
                ) {
                    app.macAppBundlePath = bundleURL.path
                }
            }
            if let idx = libraryApps.firstIndex(where: {
                $0.containerID == targetContainerID && $0.exeRelativePath.lowercased() == app.exeRelativePath.lowercased()
            }) {
                libraryApps[idx] = app
            } else {
                libraryApps.append(app)
            }
        }
        saveLibrary()
    }

    private func isBridgeProcessRunning(pattern: String) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-f", pattern]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func stopWebViewBridgeProcesses() {
        for pattern in ["zk_webview_bridge.py", "zk_webview_overlay.exe"] {
            let killProc = Process()
            killProc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            killProc.arguments = ["-9", "-f", pattern]
            try? killProc.run()
            killProc.waitUntilExit()
        }
    }

    private func startWebViewBridgeWatchdog(containerID: String, prefixURL: URL, wineBin: URL) {
        let payloadDir = Bundle.main.resourceURL?.appendingPathComponent("Payload/webview_bridge", isDirectory: true)
            ?? appSupportURL.appendingPathComponent("Runtime/webview_bridge", isDirectory: true)
        let daemonScript = payloadDir.appendingPathComponent("zk_webview_bridge.py")
        let overlayExe = payloadDir.appendingPathComponent("zk_webview_overlay.exe")

        guard FileManager.default.fileExists(atPath: daemonScript.path) &&
              FileManager.default.fileExists(atPath: overlayExe.path) else {
            return
        }

        webViewWatchdogTasks[containerID]?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            let startTime = Date()
            var attached = false
            var lastRebootSweep = Date.distantPast
            let sweepEnv = self.buildEnvironment(for: nil, prefixURL: prefixURL)
            let cdpURL = URL(string: "http://127.0.0.1:9222/json")!
            var req = URLRequest(url: cdpURL)
            req.timeoutInterval = 1.0

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }

                let elapsed = Date().timeIntervalSince(startTime)
                let containerUp = self.isContainerRunning(containerID)
                if elapsed > 30 && !containerUp && !self.isBusy {
                    if attached {
                        self.stopWebViewBridgeProcesses()
                    }
                    break
                }

                // Sweep PendingFileRenameOperations every 3s for the first 3 minutes so chained
                // installers (like setup.exe -> EdgeWebView2 -> sldIM.exe) never hit a reboot prompt
                if elapsed < 180 && Date().timeIntervalSince(lastRebootSweep) >= 3.0 {
                    lastRebootSweep = Date()
                    await self.clearPendingRebootFlags(containerID: containerID, prefixURL: prefixURL, wineBin: wineBin, env: sweepEnv)
                }

                let cdpAlive: Bool
                if let (data, resp) = try? await URLSession.shared.data(for: req),
                   let http = resp as? HTTPURLResponse,
                   http.statusCode == 200,
                   !data.isEmpty {
                    cdpAlive = true
                } else {
                    cdpAlive = false
                }

                if cdpAlive {
                    let daemonAlive = self.isBridgeProcessRunning(pattern: "zk_webview_bridge.py")
                    let overlayAlive = self.isBridgeProcessRunning(pattern: "zk_webview_overlay.exe")
                    if !attached || !daemonAlive || !overlayAlive {
                        self.stopWebViewBridgeProcesses()

                        let daemonProc = Process()
                        daemonProc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                        daemonProc.arguments = [daemonScript.path]
                        try? daemonProc.run()

                        try? await Task.sleep(nanoseconds: 800_000_000)

                        let overlayProc = Process()
                        overlayProc.executableURL = wineBin
                        overlayProc.arguments = [overlayExe.path]
                        var env = ProcessInfo.processInfo.environment
                        env["WINEPREFIX"] = prefixURL.path
                        env["WINEDEBUG"] = "-all"
                        env["WINEDLLOVERRIDES"] = "opengl32=n,b"
                        overlayProc.environment = env
                        try? overlayProc.run()

                        attached = true
                    }
                } else if attached {
                    self.stopWebViewBridgeProcesses()
                    attached = false
                }
            }
        }
        webViewWatchdogTasks[containerID] = task
    }

    public func checkRequirements(for app: InstalledApp) -> [PrerequisiteStatus] {
        let targetPrefix = app.containerURL(in: containersURL)
        guard let profile = SoftwareProfileManager.shared.profile(for: app) else {
            return []
        }
        return PrerequisiteManager.shared.checkRequirements(for: profile, in: targetPrefix)
    }

    public func openRequirementsCheck(for app: InstalledApp) {
        let targetPrefix = app.containerURL(in: containersURL)
        if let profile = SoftwareProfileManager.shared.profile(for: app) {
            pendingRequirementsStatuses = PrerequisiteManager.shared.checkRequirements(for: profile, in: targetPrefix)
        } else {
            // Show all standard optional runtimes for apps without a preset config
            pendingRequirementsStatuses = PrerequisiteID.allCases.map {
                PrerequisiteManager.shared.check($0, in: targetPrefix)
            }
        }
        prereqErrorMessage = nil
        pendingRequirementsApp = app
    }

    public func installPrerequisite(_ id: PrerequisiteID, for app: InstalledApp) {
        if wineAppURL == nil { detectWineApp() }
        guard let wineApp = wineAppURL, let wineBin = resolveWineBinary(in: wineApp) else {
            needsWineRuntimeSetup = true
            return
        }
        let targetPrefix = app.containerURL(in: containersURL)
        isInstallingPrereqs = true
        prereqErrorMessage = nil
        prereqProgressMessage = "Preparing..."
        prereqProgressValue = 0.05

        Task {
            do {
                try await PrerequisiteManager.shared.install(id, into: targetPrefix, wineBin: wineBin) { [weak self] msg, prog in
                    self?.prereqProgressMessage = msg
                    self?.prereqProgressValue = prog
                }
                refreshRequirementsStatuses(for: app)
            } catch {
                prereqErrorMessage = error.localizedDescription
            }
            isInstallingPrereqs = false
        }
    }

    public func installAllMissingPrerequisites(for app: InstalledApp) {
        if wineAppURL == nil { detectWineApp() }
        guard let wineApp = wineAppURL, let wineBin = resolveWineBinary(in: wineApp) else {
            needsWineRuntimeSetup = true
            return
        }
        let targetPrefix = app.containerURL(in: containersURL)
        let missing = pendingRequirementsStatuses.filter { !$0.isSatisfied }.map { $0.id }
        guard !missing.isEmpty else { return }

        isInstallingPrereqs = true
        prereqErrorMessage = nil

        Task {
            for id in missing {
                do {
                    try await PrerequisiteManager.shared.install(id, into: targetPrefix, wineBin: wineBin) { [weak self] msg, prog in
                        self?.prereqProgressMessage = msg
                        self?.prereqProgressValue = prog
                    }
                    refreshRequirementsStatuses(for: app)
                } catch {
                    prereqErrorMessage = error.localizedDescription
                    break
                }
            }
            isInstallingPrereqs = false
        }
    }

    private func refreshRequirementsStatuses(for app: InstalledApp) {
        let targetPrefix = app.containerURL(in: containersURL)
        if let profile = SoftwareProfileManager.shared.profile(for: app) {
            pendingRequirementsStatuses = PrerequisiteManager.shared.checkRequirements(for: profile, in: targetPrefix)
        } else {
            pendingRequirementsStatuses = PrerequisiteID.allCases.map {
                PrerequisiteManager.shared.check($0, in: targetPrefix)
            }
        }
    }

    public func saveSoftwareProfile(for app: InstalledApp, requiredPrerequisites: [PrerequisiteID]) {
        let profile = SoftwareProfileManager.shared.buildProfile(from: app, requiredPrerequisites: requiredPrerequisites)
        do {
            try SoftwareProfileManager.shared.saveProfile(profile)
            if let idx = libraryApps.firstIndex(where: { $0.id == app.id }) {
                libraryApps[idx].profileID = profile.id
                saveLibrary()
            }
            statusMessage = "Saved config '\(profile.displayName)'"
        } catch {
            errorMessage = "Failed to save config: \(error.localizedDescription)"
        }
    }

    public func launchApp(_ app: InstalledApp, skipRequirementsCheck: Bool = false) {
        if wineAppURL == nil {
            detectWineApp()
        }
        guard let wineApp = wineAppURL, let wineBin = resolveWineBinary(in: wineApp) else {
            needsWineRuntimeSetup = true
            return
        }

        let targetPrefix = app.containerURL(in: containersURL)
        let exeURL = app.unixExeURL(inContainerRoot: containersURL)
        guard FileManager.default.fileExists(atPath: exeURL.path) else {
            errorMessage = "Executable not found at \(exeURL.path)"
            return
        }

        if !skipRequirementsCheck {
            let statuses = checkRequirements(for: app)
            if statuses.contains(where: { !$0.isSatisfied }) {
                pendingRequirementsStatuses = statuses
                prereqErrorMessage = nil
                pendingRequirementsApp = app
                statusMessage = "Missing required runtime components for \(app.name)."
                return
            }
        }

        let env = buildEnvironment(for: app, prefixURL: targetPrefix)
        let targetArg = app.exeRelativePath.hasPrefix("/") ? exeURL.path : app.windowsExePath
        let launch = wineLaunchCommand(wineBin: wineBin, arguments: [targetArg], containerID: app.containerID)
        errorMessage = nil
        statusMessage = "Launching \(app.name)..."

        autoDiscoverStartupProcesses(for: app.containerID)
        let enabledStartup = startupProcesses(for: app.containerID).filter(\.enabled)
        let wasUp = isContainerRunning(app.containerID)

        let containerStep = LaunchStatusStep(
            title: "Container \(app.containerID)",
            detail: wasUp ? "Container is already running" : "Booting container runtime",
            state: wasUp ? .alreadyRunning : .succeeded
        )
        var steps: [LaunchStatusStep] = [containerStep]
        var serviceStepMap: [UUID: UUID] = [:]
        if enabledStartup.isEmpty {
            steps.append(LaunchStatusStep(
                title: "Background Startup Processes",
                detail: "None registered for this container",
                state: .skipped
            ))
        } else {
            for proc in enabledStartup {
                let s = LaunchStatusStep(title: "Startup: \(proc.name)", detail: "Queued", state: .pending)
                steps.append(s)
                serviceStepMap[proc.id] = s.id
            }
        }
        let profileName = SoftwareProfileManager.shared.profile(for: app)?.displayName ?? "Default Zink + KosmicKrisp"
        let graphicsStep = LaunchStatusStep(
            title: "Apply Profile & Graphics Bridge",
            detail: "\(profileName) (Zink + KosmicKrisp + FEX)",
            state: .pending
        )
        let execStep = LaunchStatusStep(
            title: "Launch \(app.name)",
            detail: exeURL.lastPathComponent,
            state: .pending
        )
        steps.append(graphicsStep)
        steps.append(execStep)

        let session = LaunchStatusSession(
            containerID: app.containerID,
            executableName: app.name,
            steps: steps
        )
        activeLaunchSession = session
        startWebViewBridgeWatchdog(containerID: app.containerID, prefixURL: targetPrefix, wineBin: wineBin)

        Task {
            await bootContainerStartupProcesses(
                containerID: app.containerID,
                wineBin: wineBin,
                sessionID: session.id,
                serviceStepMap: serviceStepMap
            )

            updateLaunchStep(sessionID: session.id, stepID: graphicsStep.id, state: .inProgress)
            if let profile = SoftwareProfileManager.shared.profile(for: app),
               let entries = profile.registryEntries, !entries.isEmpty {
                await applyProfileRegistryEntries(entries, containerID: app.containerID, wineBin: wineBin, env: env)
            }
            await DisplayDPIManager.shared.applyDPISettings(
                for: app.displayScalingMode,
                exeWindowsPath: app.windowsExePath,
                wineBin: wineBin,
                environment: env
            )
            updateLaunchStep(
                sessionID: session.id,
                stepID: graphicsStep.id,
                state: .succeeded,
                detail: "\(profileName) • Zink + KosmicKrisp active"
            )

            updateLaunchStep(sessionID: session.id, stepID: execStep.id, state: .inProgress, detail: "Starting \(exeURL.lastPathComponent)...")
            let proc = Process()
            proc.executableURL = launch.executable
            proc.arguments = launch.arguments
            proc.environment = env
            if FileManager.default.fileExists(atPath: exeURL.deletingLastPathComponent().path) {
                proc.currentDirectoryURL = exeURL.deletingLastPathComponent()
            }
            do {
                try proc.run()
                try? await Task.sleep(nanoseconds: 500_000_000)
                refreshRunningContainers()
                updateLaunchStep(
                    sessionID: session.id,
                    stepID: execStep.id,
                    state: .succeeded,
                    detail: "\(exeURL.lastPathComponent) started (PID \(proc.processIdentifier))"
                )
                if var s = activeLaunchSession, s.id == session.id {
                    s.isFinished = true
                    activeLaunchSession = s
                }
                scheduleAutoDismissLaunchSession(sessionID: session.id)
                statusMessage = "Launched \(app.name) (\(app.containerID))"
            } catch {
                updateLaunchStep(
                    sessionID: session.id,
                    stepID: execStep.id,
                    state: .failed,
                    detail: error.localizedDescription
                )
                if var s = activeLaunchSession, s.id == session.id {
                    s.isFinished = true
                    s.hasError = true
                    activeLaunchSession = s
                }
                errorMessage = "Failed to launch \(app.name): \(error.localizedDescription)"
            }
        }

        if let idx = libraryApps.firstIndex(where: { $0.id == app.id }) {
            libraryApps[idx].lastLaunchedAt = Date()
            saveLibrary()
        }
    }

    public func updateApp(_ app: InstalledApp, recreateShortcut: Bool = true) {
        guard let idx = libraryApps.firstIndex(where: { $0.id == app.id }) else { return }
        var updated = app
        let targetPrefix = updated.containerURL(in: containersURL)
        if recreateShortcut,
           let wineApp = wineAppURL,
           let wineBin = resolveWineBinary(in: wineApp) {
            let meta = PEIconExtractor.extractMetadata(from: updated.unixExeURL(inContainerRoot: containersURL))
            if let bundleURL = try? MacAppGenerator.createMacApp(
                for: updated,
                icon: meta.icon,
                prefixURL: targetPrefix,
                icdJSONURL: icdJSONURL,
                wineBinaryURL: wineBin
            ) {
                updated.macAppBundlePath = bundleURL.path
            }
        }
        libraryApps[idx] = updated
        saveLibrary()
    }

    public func updateDisplayScaling(for app: InstalledApp, mode: DisplayScalingMode) async {
        guard let wineApp = wineAppURL, let wineBin = resolveWineBinary(in: wineApp) else { return }
        let env = buildEnvironment(for: app, prefixURL: app.containerURL(in: containersURL))
        await DisplayDPIManager.shared.applyDPISettings(
            for: mode,
            exeWindowsPath: app.windowsExePath,
            wineBin: wineBin,
            environment: env
        )
    }

    public func toggleRetinaMode(for app: InstalledApp, enabled: Bool) async {
        await updateDisplayScaling(for: app, mode: enabled ? .retina2x : .standard1x)
    }

    public func removeAppFromLibrary(_ app: InstalledApp) {
        let fm = FileManager.default
        if let bundlePath = app.macAppBundlePath, fm.fileExists(atPath: bundlePath) {
            try? fm.removeItem(atPath: bundlePath)
        }
        libraryApps.removeAll { $0.id == app.id }
        saveLibrary()
        statusMessage = "Removed \(app.name) from library (container '\(app.containerID)' kept)"
    }

    public func uninstallAndDeleteContainer(for app: InstalledApp) async {
        await deleteContainer(containerID: app.containerID, label: app.name)
    }

    public func deleteContainer(containerID: String, label: String? = nil, force: Bool = false) async {
        let targetPrefix = containerURL(for: containerID)
        let fm = FileManager.default

        if isContainerRunning(containerID) {
            if !force {
                await stopContainer(containerID: containerID, force: false)
                if isContainerRunning(containerID) {
                    let procs = runningProcessDescriptions(in: containerID)
                    errorMessage = "Cannot delete '\(label ?? containerID)' while processes are running. Force close to delete."
                    pendingForcePrompt = ContainerForcePrompt(
                        containerID: containerID,
                        action: .delete,
                        label: label ?? containerID,
                        runningProcesses: procs
                    )
                    return
                }
            } else {
                await stopContainer(containerID: containerID, force: true)
            }
        }

        let affectedApps = libraryApps.filter { $0.containerID == containerID }
        for item in affectedApps {
            if let bundlePath = item.macAppBundlePath, fm.fileExists(atPath: bundlePath) {
                try? fm.removeItem(atPath: bundlePath)
            }
        }

        if fm.fileExists(atPath: targetPrefix.path) {
            let chflagsProc = Process()
            chflagsProc.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
            chflagsProc.arguments = ["-R", "nouchg", targetPrefix.path]
            try? chflagsProc.run()
            chflagsProc.waitUntilExit()

            do {
                try fm.removeItem(at: targetPrefix)
            } catch {
                let rmProc = Process()
                rmProc.executableURL = URL(fileURLWithPath: "/bin/rm")
                rmProc.arguments = ["-rf", targetPrefix.path]
                try? rmProc.run()
                rmProc.waitUntilExit()
            }
        }

        if fm.fileExists(atPath: targetPrefix.path) {
            errorMessage = "Failed to delete container '\(label ?? containerID)' — some files are still locked or in use."
            refreshContainers()
            return
        }

        libraryApps.removeAll { $0.containerID == containerID }
        saveLibrary()
        pendingForcePrompt = nil
        errorMessage = nil
        refreshContainers()
        statusMessage = "Deleted container \(label ?? containerID)"
    }

    public func iconForApp(_ app: InstalledApp) -> NSImage {
        PEIconExtractor.extractMetadata(from: app.unixExeURL(inContainerRoot: containersURL)).icon
    }

    public func downloadAndInstallMetalSharpWine() async {
        isDownloadingWine = true
        wineDownloadProgress = nil
        wineDownloadStatus = "Querying latest MetalSharp-Wine release..."
        errorMessage = nil

        do {
            let apiURL = URL(string: "https://api.github.com/repos/metalsharp/MetalSharp-Wine/releases/latest")!
            var req = URLRequest(url: apiURL)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let assets = json["assets"] as? [[String: Any]] else {
                throw NSError(domain: "ZinkKrisp", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not parse MetalSharp-Wine release metadata."])
            }

            let preferred =
                assets.first(where: {
                    let n = ($0["name"] as? String ?? "").lowercased()
                    return n.contains("arm64") && !n.contains("x86_64") && (n.hasSuffix(".dmg") || n.hasSuffix(".zip"))
                })
                ?? assets.first(where: {
                    let n = ($0["name"] as? String ?? "").lowercased()
                    return !n.contains("x86_64") && (n.hasSuffix(".dmg") || n.hasSuffix(".zip"))
                })
                ?? assets.first(where: {
                    let n = ($0["name"] as? String ?? "").lowercased()
                    return !n.contains("x86_64") && (n.hasSuffix(".tar.gz") || n.hasSuffix(".tar.xz"))
                })
            guard let asset = preferred,
                  let dlStr = asset["browser_download_url"] as? String,
                  let dlURL = URL(string: dlStr),
                  let assetName = asset["name"] as? String else {
                throw NSError(domain: "ZinkKrisp", code: 3, userInfo: [NSLocalizedDescriptionKey: "No macOS archive asset found in latest MetalSharp-Wine release."])
            }

            let expectedAssetSize = (asset["size"] as? NSNumber)?.int64Value ?? -1
            let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("zinkkrisp_wine_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
            let archiveURL = workDir.appendingPathComponent(assetName)

            wineDownloadStatus = "Downloading \(assetName)..."
            wineDownloadProgress = 0
            if expectedAssetSize > 0 {
                let mbTotal = String(format: "%.1f", Double(expectedAssetSize) / 1_048_576)
                wineDownloadMBText = "0.0 MB / \(mbTotal) MB"
            } else {
                wineDownloadMBText = "0.0 MB"
            }
            try await downloadFileWithProgress(from: dlURL, to: archiveURL) { [weak self] written, expected in
                let total = expected > 0 ? expected : expectedAssetSize
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let mbWritten = String(format: "%.1f", Double(written) / 1_048_576)
                    if total > 0 {
                        let fraction = min(max(Double(written) / Double(total), 0), 1)
                        self.wineDownloadProgress = fraction
                        let mbTotal = String(format: "%.1f", Double(total) / 1_048_576)
                        self.wineDownloadMBText = "\(mbWritten) MB / \(mbTotal) MB"
                        self.wineDownloadStatus = "Downloading \(assetName)..."
                    } else {
                        self.wineDownloadProgress = nil
                        self.wineDownloadMBText = "\(mbWritten) MB"
                        self.wineDownloadStatus = "Downloading \(assetName)..."
                    }
                }
            }

            wineDownloadProgress = nil
            wineDownloadMBText = ""
            wineDownloadStatus = "Installing MetalSharp-Wine.app..."
            let destApplications = URL(fileURLWithPath: "/Applications")
            let fallbackApplications = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            let installRoot = FileManager.default.isWritableFile(atPath: destApplications.path) ? destApplications : fallbackApplications
            try FileManager.default.createDirectory(at: installRoot, withIntermediateDirectories: true)

            if assetName.lowercased().hasSuffix(".dmg") {
                let mountPoint = workDir.appendingPathComponent("mnt")
                try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
                _ = try await runProcess(executable: URL(fileURLWithPath: "/usr/bin/hdiutil"), arguments: ["attach", archiveURL.path, "-nobrowse", "-quiet", "-mountpoint", mountPoint.path], environment: [:])
                defer {
                    let detach = Process()
                    detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    detach.arguments = ["detach", mountPoint.path, "-quiet"]
                    try? detach.run()
                    detach.waitUntilExit()
                }
                if let appBundle = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil).first(where: { $0.pathExtension == "app" }) {
                    let destApp = installRoot.appendingPathComponent("MetalSharp-Wine.app")
                    if FileManager.default.fileExists(atPath: destApp.path) {
                        try FileManager.default.removeItem(at: destApp)
                    }
                    try FileManager.default.copyItem(at: appBundle, to: destApp)
                }
            } else {
                let extractDir = workDir.appendingPathComponent("extracted")
                try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
                if assetName.lowercased().hasSuffix(".zip") {
                    _ = try await runProcess(executable: URL(fileURLWithPath: "/usr/bin/ditto"), arguments: ["-x", "-k", archiveURL.path, extractDir.path], environment: [:])
                } else {
                    _ = try await runProcess(executable: URL(fileURLWithPath: "/usr/bin/tar"), arguments: ["-xf", archiveURL.path, "-C", extractDir.path], environment: [:])
                }
                if let appBundle = findAppBundle(in: extractDir) {
                    let destApp = installRoot.appendingPathComponent("MetalSharp-Wine.app")
                    if FileManager.default.fileExists(atPath: destApp.path) {
                        try FileManager.default.removeItem(at: destApp)
                    }
                    try FileManager.default.copyItem(at: appBundle, to: destApp)
                }
            }

            try? FileManager.default.removeItem(at: workDir)
            detectWineApp()
            if wineAppURL != nil {
                needsWineRuntimeSetup = false
                await ensureEngineReady()
            } else {
                throw NSError(domain: "ZinkKrisp", code: 4, userInfo: [NSLocalizedDescriptionKey: "MetalSharp-Wine.app was not found inside the downloaded archive."])
            }
        } catch {
            errorMessage = error.localizedDescription
            wineDownloadStatus = "Download failed"
        }

        isDownloadingWine = false
        wineDownloadProgress = nil
    }

    private func downloadFileWithProgress(
        from url: URL,
        to destinationURL: URL,
        onProgress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        let delegate = WineDownloadDelegate(destinationURL: destinationURL, onProgress: onProgress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        try await delegate.start(with: session, url: url)
    }

    private func findAppBundle(in root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in enumerator where url.pathExtension == "app" {
            return url
        }
        return nil
    }

    private func loadLibrary() {
        guard let data = try? Data(contentsOf: libraryJSONURL),
              let decoded = try? JSONDecoder().decode([InstalledApp].self, from: data) else {
            return
        }
        libraryApps = decoded
    }

    private func saveLibrary() {
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(libraryApps) {
            try? data.write(to: libraryJSONURL)
        }
    }

    private func runProcess(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL? = nil
    ) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let proc = Process()
            proc.executableURL = executable
            proc.arguments = arguments
            proc.environment = environment
            if let workingDirectory {
                proc.currentDirectoryURL = workingDirectory
            }
            proc.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
            do {
                try proc.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class WineDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let onProgress: @Sendable (Int64, Int64) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private let lock = NSLock()

    init(destinationURL: URL, onProgress: @escaping @Sendable (Int64, Int64) -> Void) {
        self.destinationURL = destinationURL
        self.onProgress = onProgress
    }

    func start(with session: URLSession, url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            resumeOnce(with: .success(()))
        } catch {
            resumeOnce(with: .failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            resumeOnce(with: .failure(error))
        }
    }

    private func resumeOnce(with result: Result<Void, Error>) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(with: result)
    }
}
