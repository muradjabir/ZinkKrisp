import Foundation

public enum PrerequisiteError: LocalizedError {
    case missingDownloadURL(String)
    case downloadFailed(String)
    case installFailed(String, Int32)
    case shimNotFound

    public var errorDescription: String? {
        switch self {
        case .missingDownloadURL(let name):
            return "No official download URL is configured for \(name)."
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .installFailed(let name, let code):
            return "\(name) installer exited with code \(code)."
        case .shimNotFound:
            return "Bundled mscoree_shim64.dll was not found in app resources."
        }
    }
}

public final class PrerequisiteManager {
    public static let shared = PrerequisiteManager()

    /// Must stay under 520 bytes UTF-16LE (259 chars + NUL) because EmbeddedBrowserWebView.dll (>= v150)
    /// queries AdditionalBrowserArguments with a fixed 520-byte stack buffer and silently ignores ERROR_MORE_DATA.
    /// Combined with msedgewebview2.exe Version=win8 below, this avoids Chromium >= 140's
    /// output_device_backing.cc DCompositionCreateDevice E_NOTIMPL crash under Wine.
    public static let webView2AdditionalBrowserArguments: String = "--remote-debugging-port=9222 --remote-allow-origins=* --no-sandbox --disable-gpu --disable-gpu-compositing --disable-direct-composition"

    public let cacheDirURL: URL

    public static let descriptors: [PrerequisiteID: PrerequisiteDescriptor] = [
        .dotnet48: PrerequisiteDescriptor(
            id: .dotnet48,
            name: "Microsoft .NET Framework 4.8",
            vendor: "Microsoft Corporation",
            description: "Official Microsoft .NET Framework 4.8 Offline Installer (required for WPF and .NET 4.x apps).",
            officialDownloadURL: URL(string: "https://go.microsoft.com/fwlink/?linkid=2088631"),
            installerFilename: "ndp48-x86-x64-allos-enu.exe",
            silentArgs: ["/q", "/norestart"],
            requiresWin7DuringInstall: true
        ),
        .mscoreeShim: PrerequisiteDescriptor(
            id: .mscoreeShim,
            name: "Native .NET CLR Bridge (mscoree.dll)",
            vendor: "ZinkKrisp Runtime",
            description: "Routes .NET calls to Microsoft's native mscoreei.dll / clr.dll instead of Wine-Mono.",
            officialDownloadURL: nil,
            installerFilename: nil
        ),
        .vcredist2022x64: PrerequisiteDescriptor(
            id: .vcredist2022x64,
            name: "Visual C++ 2015–2022 Redistributable (x64)",
            vendor: "Microsoft Corporation",
            description: "Official Microsoft Visual C++ x64 runtime libraries.",
            officialDownloadURL: URL(string: "https://aka.ms/vs/17/release/vc_redist.x64.exe"),
            installerFilename: "vc_redist.x64.exe",
            silentArgs: ["/install", "/quiet", "/norestart"]
        ),
        .vcredist2022x86: PrerequisiteDescriptor(
            id: .vcredist2022x86,
            name: "Visual C++ 2015–2022 Redistributable (x86)",
            vendor: "Microsoft Corporation",
            description: "Official Microsoft Visual C++ x86 runtime libraries.",
            officialDownloadURL: URL(string: "https://aka.ms/vs/17/release/vc_redist.x86.exe"),
            installerFilename: "vc_redist.x86.exe",
            silentArgs: ["/install", "/quiet", "/norestart"]
        ),
        .webview2: PrerequisiteDescriptor(
            id: .webview2,
            name: "Microsoft Edge WebView2 Runtime",
            vendor: "Microsoft Corporation",
            description: "Official Microsoft Edge WebView2 Evergreen Runtime.",
            officialDownloadURL: URL(string: "https://go.microsoft.com/fwlink/p/?LinkId=2124703"),
            installerFilename: "MicrosoftEdgeWebview2Setup.exe",
            silentArgs: ["/silent", "/install"]
        )
    ]

    private init() {
        let fm = FileManager.default
        let baseSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ZinkKrisp", isDirectory: true)
        self.cacheDirURL = baseSupport.appendingPathComponent("Cache/Prereqs", isDirectory: true)
        try? fm.createDirectory(at: cacheDirURL, withIntermediateDirectories: true)
    }

    public func descriptor(for id: PrerequisiteID) -> PrerequisiteDescriptor {
        Self.descriptors[id]!
    }

    public func checkRequirements(for profile: SoftwareProfile, in prefixURL: URL) -> [PrerequisiteStatus] {
        profile.requiredPrerequisites.map { check($0, in: prefixURL) }
    }

    public func check(_ id: PrerequisiteID, in prefixURL: URL) -> PrerequisiteStatus {
        let desc = descriptor(for: id)
        let fm = FileManager.default
        let driveC = prefixURL.appendingPathComponent("drive_c", isDirectory: true)

        switch id {
        case .dotnet48:
            let fw64 = driveC.appendingPathComponent("windows/Microsoft.NET/Framework64/v4.0.30319", isDirectory: true)
            let clr = fw64.appendingPathComponent("clr.dll")
            let mscoreei = fw64.appendingPathComponent("mscoreei.dll")
            let ok = fm.fileExists(atPath: clr.path) && fm.fileExists(atPath: mscoreei.path)
            return PrerequisiteStatus(
                descriptor: desc,
                isSatisfied: ok,
                details: ok ? "Native clr.dll & mscoreei.dll present" : "Not installed (only Wine-Mono stub found)"
            )

        case .mscoreeShim:
            let mscoree = driveC.appendingPathComponent("windows/system32/mscoree.dll")
            guard fm.fileExists(atPath: mscoree.path),
                  let data = try? Data(contentsOf: mscoree, options: .mappedIfSafe) else {
                return PrerequisiteStatus(descriptor: desc, isSatisfied: false, details: "mscoree.dll missing")
            }
            let marker = Data("Wine builtin DLL".utf8)
            let isWineBuiltin = data.range(of: marker) != nil
            return PrerequisiteStatus(
                descriptor: desc,
                isSatisfied: !isWineBuiltin,
                details: isWineBuiltin ? "Wine builtin mscoree.dll active (routes to Wine-Mono)" : "Native mscoree.dll active"
            )

        case .vcredist2022x64:
            let sys32 = driveC.appendingPathComponent("windows/system32", isDirectory: true)
            let required = ["vcruntime140.dll", "msvcp140.dll", "concrt140.dll", "mfc140u.dll", "vcomp140.dll"]
            let ok = required.allSatisfy { isNativeX64DLL(at: sys32.appendingPathComponent($0)) }
            return PrerequisiteStatus(
                descriptor: desc,
                isSatisfied: ok,
                details: ok ? "Native x86-64 VC++ & MFC runtimes installed" : "Native x86-64 VC++ / MFC runtime missing or ARM64 stub"
            )

        case .vcredist2022x86:
            let dll = driveC.appendingPathComponent("windows/syswow64/vcruntime140.dll")
            let ok = isNonWineDLL(at: dll)
            return PrerequisiteStatus(
                descriptor: desc,
                isSatisfied: ok,
                details: ok ? "Native vcruntime140.dll (x86) installed" : "Native VC++ x86 runtime missing"
            )

        case .webview2:
            let appDir = driveC.appendingPathComponent("Program Files (x86)/Microsoft/EdgeWebView/Application", isDirectory: true)
            let hasExe = (try? fm.contentsOfDirectory(atPath: appDir.path))?.contains(where: { entry in
                fm.fileExists(atPath: appDir.appendingPathComponent("\(entry)/msedgewebview2.exe").path)
            }) ?? false
            return PrerequisiteStatus(
                descriptor: desc,
                isSatisfied: hasExe,
                details: hasExe ? "WebView2 Runtime installed" : "Edge WebView2 Runtime not installed"
            )
        }
    }

    private func isNonWineDLL(at url: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return false
        }
        return data.range(of: Data("Wine builtin DLL".utf8)) == nil
    }

    private func isNativeX64DLL(at url: URL) -> Bool {
        guard isNonWineDLL(at: url),
              let fh = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? fh.close() }
        guard let header = try? fh.read(upToCount: 4096), header.count >= 0x40 else {
            return false
        }
        let peOff = Int(header[0x3C]) | (Int(header[0x3D]) << 8) | (Int(header[0x3E]) << 16) | (Int(header[0x3F]) << 24)
        guard peOff >= 0, peOff + 6 <= header.count else { return false }
        let machine = UInt16(header[peOff + 4]) | (UInt16(header[peOff + 5]) << 8)
        return machine == 0x8664
    }

    public func install(
        _ id: PrerequisiteID,
        into prefixURL: URL,
        wineBin: URL,
        progress: @escaping @MainActor (String, Double?) -> Void
    ) async throws {
        let desc = descriptor(for: id)

        if id == .mscoreeShim {
            await progress("Deploying native mscoree.dll bridge...", 0.5)
            try deployMscoreeShim(into: prefixURL, wineBin: wineBin)
            await progress("Native mscoree.dll bridge deployed.", 1.0)
            return
        }

        guard let url = desc.officialDownloadURL, let filename = desc.installerFilename else {
            throw PrerequisiteError.missingDownloadURL(desc.name)
        }

        let cachedInstaller = cacheDirURL.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: cachedInstaller.path) {
            await progress("Downloading \(desc.name) from \(url.host ?? "official source")...", 0.15)
            let (tmpURL, response) = try await URLSession.shared.download(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw PrerequisiteError.downloadFailed("HTTP \(http.statusCode) from \(url.absoluteString)")
            }
            if FileManager.default.fileExists(atPath: cachedInstaller.path) {
                try? FileManager.default.removeItem(at: cachedInstaller)
            }
            try FileManager.default.moveItem(at: tmpURL, to: cachedInstaller)
        }

        await progress("Installing \(desc.name) into container...", 0.65)
        try await Task.detached(priority: .userInitiated) {
            try self.runInstaller(
                descriptor: desc,
                installerURL: cachedInstaller,
                prefixURL: prefixURL,
                wineBin: wineBin
            )
        }.value

        if id == .dotnet48 {
            try? deployMscoreeShim(into: prefixURL, wineBin: wineBin)
            repair64BitOleAut32(in: prefixURL, wineBin: wineBin)
        } else if id == .vcredist2022x64 {
            await progress("Deploying native x86-64 VC++ & MFC DLLs...", 0.85)
            try await Task.detached(priority: .userInitiated) {
                let deployed = try self.deployX64VCRedistDLLs(from: cachedInstaller, into: prefixURL)
                self.registerNativeDllOverrides(deployed, in: prefixURL, wineBin: wineBin)
                self.repair64BitOleAut32(in: prefixURL, wineBin: wineBin)
            }.value
        } else if id == .webview2 {
            await progress("Applying WebView2 Group Policy settings...", 0.90)
            await Task.detached(priority: .userInitiated) {
                self.ensureWebView2Policy(in: prefixURL, wineBin: wineBin)
            }.value
        }

        await progress("\(desc.name) installed.", 1.0)
    }

    private func runInstaller(
        descriptor: PrerequisiteDescriptor,
        installerURL: URL,
        prefixURL: URL,
        wineBin: URL
    ) throws {
        var baseEnv = ProcessInfo.processInfo.environment
        baseEnv["WINEPREFIX"] = prefixURL.path
        baseEnv["WINEDEBUG"] = "-all"

        if descriptor.requiresWin7DuringInstall {
            // Clear Wine-Mono fake NDP v4 key so ndp48 runs full install, and temporarily use win7 mode
            _ = runWineCommand(wineBin: wineBin, args: ["reg", "delete", "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v4", "/f"], env: baseEnv)
            _ = runWineCommand(wineBin: wineBin, args: ["reg", "delete", "HKLM\\Software\\Wow6432Node\\Microsoft\\NET Framework Setup\\NDP\\v4", "/f"], env: baseEnv)
            _ = runWineCommand(wineBin: wineBin, args: ["reg", "add", "HKCU\\Software\\Wine", "/v", "Version", "/t", "REG_SZ", "/d", "win7", "/f"], env: baseEnv)
        }

        var installEnv = baseEnv
        if descriptor.id == .dotnet48 {
            installEnv["WINEDLLOVERRIDES"] = "mscoree="
        }

        let code = runWineCommand(
            wineBin: wineBin,
            args: [installerURL.path] + descriptor.silentArgs,
            env: installEnv
        )

        if descriptor.requiresWin7DuringInstall {
            _ = runWineCommand(wineBin: wineBin, args: ["reg", "delete", "HKCU\\Software\\Wine", "/v", "Version", "/f"], env: baseEnv)
            _ = runWineCommand(wineBin: wineBin, args: ["reg", "add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "mscoree", "/t", "REG_SZ", "/d", "native,builtin", "/f"], env: baseEnv)
        }

        // 0 = success; 3010 (194 mod 256) = reboot requested; 1638 (102 mod 256) = newer/same version already installed
        let acceptedCodes: Set<Int32> = [0, 3010, 194, 1638, 102]
        if !acceptedCodes.contains(code) {
            throw PrerequisiteError.installFailed(descriptor.name, code)
        }
    }

    private func runWineCommand(wineBin: URL, args: [String], env: [String: String]) -> Int32 {
        let proc = Process()
        proc.executableURL = wineBin
        proc.arguments = args
        proc.environment = env
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus
        } catch {
            return -1
        }
    }

    private func deployMscoreeShim(into prefixURL: URL, wineBin: URL) throws {
        let fm = FileManager.default
        let candidates: [URL] = [
            Bundle.main.resourceURL?.appendingPathComponent("Payload/webview_bridge/mscoree_shim64.dll"),
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("ZinkKrisp/Runtime/webview_bridge/mscoree_shim64.dll")
        ].compactMap { $0 }

        guard let source = candidates.first(where: { fm.fileExists(atPath: $0.path) }) else {
            throw PrerequisiteError.shimNotFound
        }

        let sys32 = prefixURL.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
        let dest = sys32.appendingPathComponent("mscoree.dll")
        let bak = sys32.appendingPathComponent("mscoree.dll.wine_bak")

        if fm.fileExists(atPath: dest.path), !fm.fileExists(atPath: bak.path) {
            try? fm.copyItem(at: dest, to: bak)
        }
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: source, to: dest)

        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefixURL.path
        env["WINEDEBUG"] = "-all"
        _ = runWineCommand(wineBin: wineBin, args: ["reg", "add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "mscoree", "/t", "REG_SZ", "/d", "native,builtin", "/f"], env: env)
        _ = runWineCommand(wineBin: wineBin, args: ["reg", "add", "HKLM\\Software\\Microsoft\\.NETFramework", "/v", "OnlyUseLatestCLR", "/t", "REG_DWORD", "/d", "1", "/f"], env: env)
        repair64BitOleAut32(in: prefixURL, wineBin: wineBin)
    }

    /// On ARM64EC Wine, Microsoft's vc_redist.x64.exe installs ARM64X (0xaa64) DLLs into system32
    /// and may leave Wine's builtin msvcp140.dll in place, which crashes pure x86-64 (0x8664) apps.
    /// Extract the official pure x86-64 (*.dll_amd64) DLLs directly from the downloaded vc_redist.x64.exe
    /// using macOS's built-in libarchive (/usr/bin/tar) and deploy them into drive_c/windows/system32.
    @discardableResult
    private func deployX64VCRedistDLLs(from installerURL: URL, into prefixURL: URL) throws -> [String] {
        let fm = FileManager.default
        let data = try Data(contentsOf: installerURL, options: .mappedIfSafe)
        let magic = Data([0x4D, 0x53, 0x43, 0x46, 0x00, 0x00, 0x00, 0x00]) // "MSCF\0\0\0\0"

        var cabRanges: [Range<Int>] = []
        var searchStart = data.startIndex
        while let found = data.range(of: magic, in: searchStart..<data.endIndex) {
            let offset = found.lowerBound
            guard offset + 12 <= data.endIndex else { break }
            let size = Int(data[offset + 8])
                | (Int(data[offset + 9]) << 8)
                | (Int(data[offset + 10]) << 16)
                | (Int(data[offset + 11]) << 24)
            if size > 64, offset + size <= data.endIndex {
                cabRanges.append(offset..<(offset + size))
                searchStart = offset + size
            } else {
                searchStart = offset + 8
            }
        }

        let tmpDir = fm.temporaryDirectory.appendingPathComponent("zk_vcredist_\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        func extractCab(_ cabURL: URL, to outDir: URL) {
            try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            p.arguments = ["-xf", cabURL.path, "-C", outDir.path]
            p.standardOutput = Pipe()
            p.standardError = Pipe()
            if (try? p.run()) != nil {
                p.waitUntilExit()
            }
        }

        for (idx, range) in cabRanges.enumerated() {
            let cabURL = tmpDir.appendingPathComponent("outer_\(idx).cab")
            try data[range].write(to: cabURL)
            let outDir = tmpDir.appendingPathComponent("outer_\(idx)", isDirectory: true)
            extractCab(cabURL, to: outDir)

            if let entries = try? fm.contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil) {
                for entry in entries {
                    if let fh = try? FileHandle(forReadingFrom: entry),
                       let hdr = try? fh.read(upToCount: 4),
                       hdr == Data([0x4D, 0x53, 0x43, 0x46]) {
                        try? fh.close()
                        let innerOut = tmpDir.appendingPathComponent("inner_\(idx)_\(entry.lastPathComponent)", isDirectory: true)
                        extractCab(entry, to: innerOut)
                    }
                }
            }
        }

        let sys32 = prefixURL.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
        try fm.createDirectory(at: sys32, withIntermediateDirectories: true)

        var deployedNames: [String] = []
        if let enumerator = fm.enumerator(at: tmpDir, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                let name = fileURL.lastPathComponent
                guard name.lowercased().hasSuffix(".dll_amd64") else { continue }
                guard isNativeX64DLL(at: fileURL) else { continue }
                let dllName = String(name.dropLast("_amd64".count))
                let dest = sys32.appendingPathComponent(dllName)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(atPath: dest.path)
                }
                try fm.copyItem(at: fileURL, to: dest)
                let baseName = URL(fileURLWithPath: dllName).deletingPathExtension().lastPathComponent.lowercased()
                deployedNames.append(baseName)
            }
        }
        return Array(Set(deployedNames)).sorted()
    }

    private func registerNativeDllOverrides(_ dllBaseNames: [String], in prefixURL: URL, wineBin: URL) {
        guard !dllBaseNames.isEmpty else { return }
        var regText = "Windows Registry Editor Version 5.00\r\n\r\n[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]\r\n"
        for name in dllBaseNames {
            regText += "\"*\(name)\"=\"native,builtin\"\r\n"
        }
        let tmpReg = FileManager.default.temporaryDirectory
            .appendingPathComponent("zk_vcredist_ovr_\(UUID().uuidString).reg")
        guard (try? regText.write(to: tmpReg, atomically: true, encoding: .utf8)) != nil else { return }
        defer { try? FileManager.default.removeItem(at: tmpReg) }

        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefixURL.path
        env["WINEDEBUG"] = "-all"
        _ = runWineCommand(wineBin: wineBin, args: ["regedit", "/S", tmpReg.path], env: env)
    }

    /// .NET 4.8's installer can overwrite 64-bit OLE Automation CLSID InprocServer32 entries
    /// with C:\windows\syswow64\oleaut32.dll (32-bit), breaking 64-bit COM clients.
    private func repair64BitOleAut32(in prefixURL: URL, wineBin: URL) {
        let clsidList = [
            "{0000002F-0000-0000-C000-000000000046}",
            "{00020420-0000-0000-C000-000000000046}",
            "{00020421-0000-0000-C000-000000000046}",
            "{00020422-0000-0000-C000-000000000046}",
            "{00020423-0000-0000-C000-000000000046}",
            "{00020424-0000-0000-C000-000000000046}",
            "{00020425-0000-0000-C000-000000000046}",
            "{0BE35203-8F91-11CE-9DE3-00AA004BB851}",
            "{0BE35204-8F91-11CE-9DE3-00AA004BB851}",
            "{46763EE0-CAB2-11CE-8C20-00AA0051E5D4}",
            "{B196B286-BAB4-101A-B69C-00AA00341D07}"
        ]
        var regText = "Windows Registry Editor Version 5.00\r\n\r\n"
        for clsid in clsidList {
            regText += "[HKEY_LOCAL_MACHINE\\Software\\Classes\\CLSID\\\(clsid)\\InprocServer32]\r\n"
            regText += "@=\"C:\\\\windows\\\\system32\\\\oleaut32.dll\"\r\n\r\n"
        }
        let tmpReg = FileManager.default.temporaryDirectory
            .appendingPathComponent("zk_oleaut32_\(UUID().uuidString).reg")
        guard (try? regText.write(to: tmpReg, atomically: true, encoding: .utf8)) != nil else { return }
        defer { try? FileManager.default.removeItem(at: tmpReg) }

        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefixURL.path
        env["WINEDEBUG"] = "-all"
        _ = runWineCommand(wineBin: wineBin, args: ["regedit", "/S", tmpReg.path], env: env)
    }

    /// Edge WebView2 ignores WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS under elevated processes (such as Wine).
    /// Setting the official WebView2 Group Policy keys ensures CDP and compatibility flags apply cleanly.
    /// Setting msedgewebview2.exe Version=win8 + opengl32=builtin keeps Chromium >= 140 off DirectComposition/ARM64EC paths.
    public func ensureWebView2Policy(in prefixURL: URL, wineBin: URL) {
        let escapedArgs = Self.webView2AdditionalBrowserArguments
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let expectedEntry = "\"*\"=\"\(escapedArgs)\""
        let sysRegURL = prefixURL.appendingPathComponent("system.reg")
        let userRegURL = prefixURL.appendingPathComponent("user.reg")
        if let sysData = try? Data(contentsOf: sysRegURL, options: .mappedIfSafe),
           let userData = try? Data(contentsOf: userRegURL, options: .mappedIfSafe),
           sysData.range(of: Data("Policies\\\\Microsoft\\\\Edge\\\\WebView2\\\\AdditionalBrowserArguments".utf8)) != nil,
           sysData.range(of: Data(expectedEntry.utf8)) != nil,
           userData.range(of: Data("AppDefaults\\\\msedgewebview2.exe".utf8)) != nil,
           userData.range(of: Data("\"Version\"=\"win8\"".utf8)) != nil,
           userData.range(of: Data("\"opengl32\"=\"builtin\"".utf8)) != nil {
            return
        }
        let policyKeys = [
            "HKEY_LOCAL_MACHINE\\Software\\Policies\\Microsoft\\Edge\\WebView2\\AdditionalBrowserArguments",
            "HKEY_LOCAL_MACHINE\\Software\\WOW6432Node\\Policies\\Microsoft\\Edge\\WebView2\\AdditionalBrowserArguments",
            "HKEY_CURRENT_USER\\Software\\Policies\\Microsoft\\Edge\\WebView2\\AdditionalBrowserArguments"
        ]
        var regText = "Windows Registry Editor Version 5.00\r\n\r\n"
        for key in policyKeys {
            regText += "[\(key)]\r\n\"*\"=\"\(escapedArgs)\"\r\n\r\n"
        }
        regText += "[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\msedgewebview2.exe]\r\n\"Version\"=\"win8\"\r\n\r\n"
        regText += "[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\msedgewebview2.exe\\DllOverrides]\r\n\"winevulkan\"=\"\"\r\n\"vulkan-1\"=\"\"\r\n\"opengl32\"=\"builtin\"\r\n\r\n"

        let tmpReg = FileManager.default.temporaryDirectory
            .appendingPathComponent("zk_wv2_policy_\(UUID().uuidString).reg")
        guard (try? regText.write(to: tmpReg, atomically: true, encoding: .utf8)) != nil else { return }
        defer { try? FileManager.default.removeItem(at: tmpReg) }

        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefixURL.path
        env["WINEDEBUG"] = "-all"
        _ = runWineCommand(wineBin: wineBin, args: ["regedit", "/S", tmpReg.path], env: env)
    }
}
