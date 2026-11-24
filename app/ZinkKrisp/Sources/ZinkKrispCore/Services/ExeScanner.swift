import Foundation

public struct ExeSnapshot {
    public let timestamp: Date
    public let exeModDates: [String: Date] // lowercased relativePath -> modificationDate
}

public final class ExeScanner {
    public static let shared = ExeScanner()
    private init() {}

    private let excludedPathSubstrings: [String] = [
        "/windows/",
        "/common files/installshield/",
        "/package cache/",
        "/$recycle.bin/",
        "/winsxs/"
    ]

    private let excludedNameSubstrings: [String] = [
        "uninstall", "vc_redist", "vcredist", "dxsetup",
        "crash", "update", "helper", "daemon",
        "fnplicensing", "activation", "cefsharp"
    ]

    private let excludedPrefixes: [String] = [
        "unins", "ndp", "wine"
    ]

    private let excludedExactNames: Set<String> = [
        "setup.exe", "lmgrd.exe", "sw_d.exe", "qtwebengineprocess.exe",
        "cmd.exe", "conhost.exe", "explorer.exe", "iexplore.exe",
        "notepad.exe", "regedit.exe", "services.exe", "svchost.exe",
        "wscript.exe", "msiexec.exe"
    ]

    public func takeSnapshot(in driveCURL: URL) -> ExeSnapshot {
        var map: [String: Date] = [:]
        for root in scanRoots(in: driveCURL) {
            for url in enumerateExes(under: root) {
                let rel = relativePath(of: url, from: driveCURL).lowercased()
                let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                map[rel] = attrs?.contentModificationDate ?? Date.distantPast
            }
        }
        return ExeSnapshot(timestamp: Date(), exeModDates: map)
    }

    public func scanForNewExes(
        in driveCURL: URL,
        since snapshot: ExeSnapshot,
        existingLibrary: [InstalledApp]
    ) -> [DiscoveredExe] {
        var newOrModified: [URL] = []
        for root in scanRoots(in: driveCURL) {
            for url in enumerateExes(under: root) {
                let rel = relativePath(of: url, from: driveCURL)
                let key = rel.lowercased()
                let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                if let prev = snapshot.exeModDates[key] {
                    if modDate > prev {
                        newOrModified.append(url)
                    }
                } else {
                    newOrModified.append(url)
                }
            }
        }

        let filteredNew = buildDiscoveredList(from: newOrModified, driveCURL: driveCURL, existingLibrary: existingLibrary, preselectNew: true)
        if !filteredNew.isEmpty {
            return filteredNew
        }
        return scanAllApps(in: driveCURL, existingLibrary: existingLibrary)
    }

    public func scanAllApps(
        in driveCURL: URL,
        existingLibrary: [InstalledApp]
    ) -> [DiscoveredExe] {
        var allURLs: [URL] = []
        for root in scanRoots(in: driveCURL) {
            allURLs.append(contentsOf: enumerateExes(under: root))
        }
        return buildDiscoveredList(from: allURLs, driveCURL: driveCURL, existingLibrary: existingLibrary, preselectNew: false)
    }

    public func isNoiseExecutable(url: URL, relativePath: String) -> Bool {
        let lowerRel = "/" + relativePath.replacingOccurrences(of: "\\", with: "/").lowercased()
        for sub in excludedPathSubstrings where lowerRel.contains(sub) {
            return true
        }

        let fileName = url.lastPathComponent.lowercased()
        if excludedExactNames.contains(fileName) {
            return true
        }
        for prefix in excludedPrefixes where fileName.hasPrefix(prefix) {
            return true
        }
        for sub in excludedNameSubstrings where fileName.contains(sub) {
            return true
        }
        if fileName.contains("setup") {
            return true
        }

        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        if fileSize < 40 * 1024 {
            return true
        }
        return false
    }

    private func buildDiscoveredList(
        from urls: [URL],
        driveCURL: URL,
        existingLibrary: [InstalledApp],
        preselectNew: Bool
    ) -> [DiscoveredExe] {
        let knownSet = Set(existingLibrary.map { $0.exeRelativePath.lowercased() })
        var seen = Set<String>()
        var results: [DiscoveredExe] = []

        for url in urls {
            let rel = relativePath(of: url, from: driveCURL)
            let key = rel.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)

            if isNoiseExecutable(url: url, relativePath: rel) {
                continue
            }

            let meta = PEIconExtractor.extractMetadata(from: url)
            let displayName = chooseDisplayName(meta: meta, url: url)
            let inLib = knownSet.contains(key)
            results.append(DiscoveredExe(
                url: url,
                relativePath: rel,
                productName: displayName,
                fileDescription: meta.fileDescription,
                icon: meta.icon,
                architecture: meta.architecture,
                alreadyInLibrary: inLib,
                isSelected: preselectNew && !inLib
            ))
        }

        return results.sorted { a, b in
            if a.alreadyInLibrary != b.alreadyInLibrary {
                return !a.alreadyInLibrary
            }
            return a.productName.localizedCaseInsensitiveCompare(b.productName) == .orderedAscending
        }
    }

    private func chooseDisplayName(meta: PEMetadata, url: URL) -> String {
        if let desc = meta.fileDescription, !desc.isEmpty {
            return desc
        }
        if let prod = meta.productName, !prod.isEmpty {
            return prod
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private func scanRoots(in driveCURL: URL) -> [URL] {
        var roots: [URL] = [
            driveCURL.appendingPathComponent("Program Files"),
            driveCURL.appendingPathComponent("Program Files (x86)"),
            driveCURL.appendingPathComponent("ProgramData")
        ]
        let usersDir = driveCURL.appendingPathComponent("users")
        if let userDirs = try? FileManager.default.contentsOfDirectory(
            at: usersDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for userDir in userDirs {
                roots.append(userDir.appendingPathComponent("AppData/Local/Programs"))
            }
        }
        return roots.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func enumerateExes(under root: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var exes: [URL] = []
        for case let fileURL as URL in enumerator {
            let lowerPath = fileURL.path.lowercased()
            if lowerPath.contains("/package cache/") || lowerPath.contains("/common files/installshield/") {
                enumerator.skipDescendants()
                continue
            }
            if fileURL.pathExtension.lowercased() == "exe" {
                exes.append(fileURL)
            }
        }
        return exes
    }

    private func relativePath(of url: URL, from driveCURL: URL) -> String {
        let base = driveCURL.standardizedFileURL.path
        let full = url.standardizedFileURL.path
        if full.hasPrefix(base + "/") {
            return String(full.dropFirst(base.count + 1))
        }
        return url.lastPathComponent
    }
}
