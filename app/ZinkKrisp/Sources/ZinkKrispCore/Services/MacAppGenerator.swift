import AppKit
import Foundation
import ImageIO

public enum MacAppGenerator {
    public static func createMacApp(
        for app: InstalledApp,
        icon: NSImage,
        prefixURL: URL,
        icdJSONURL: URL,
        wineBinaryURL: URL,
        applicationsDir: URL? = nil
    ) throws -> URL {
        let fm = FileManager.default
        let destRoot = applicationsDir ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        try fm.createDirectory(at: destRoot, withIntermediateDirectories: true)

        let cleanName = sanitizeFilename(app.name)
        let bundleURL = destRoot.appendingPathComponent("\(cleanName).app", isDirectory: true)
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)

        if fm.fileExists(atPath: bundleURL.path) {
            try fm.removeItem(at: bundleURL)
        }
        try fm.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        // 1. Write AppIcon.icns
        let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")
        writeICNS(image: icon, to: icnsURL)

        // 2. Write Info.plist
        let bundleID = "com.zinkkrisp.app." + cleanName
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let plistDict: [String: Any] = [
            "CFBundleExecutable": "launcher",
            "CFBundleIconFile": "AppIcon",
            "CFBundleIdentifier": bundleID.isEmpty ? "com.zinkkrisp.app.custom" : bundleID,
            "CFBundleName": app.name,
            "CFBundleDisplayName": app.name,
            "CFBundlePackageType": "APPL",
            "CFBundleVersion": "1.0",
            "CFBundleShortVersionString": "1.0",
            "NSHighResolutionCapable": true
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
        try plistData.write(to: contentsURL.appendingPathComponent("Info.plist"))

        // 3. Write Contents/MacOS/launcher
        let exeURL = app.unixExeURL(in: prefixURL)
        let exeUnixPath = exeURL.path
        let targetExeArg = app.exeRelativePath.hasPrefix("/") ? exeUnixPath : app.windowsExePath
        let exeDir = exeURL.deletingLastPathComponent().path
        let safeLogName = cleanName
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
        let profile = SoftwareProfileManager.shared.profile(for: app)
        var dllOverrides: [String: String] = ["opengl32": "n,b"]
        if let profileOverrides = profile?.dllOverrides {
            for (k, v) in profileOverrides { dllOverrides[k] = v }
        }
        if let customOverrides = app.customDllOverrides {
            for (k, v) in customOverrides { dllOverrides[k] = v }
        }
        let overridesString = dllOverrides.keys.sorted().map { "\($0)=\(dllOverrides[$0]!)" }.joined(separator: ";")
        var mergedEnv: [String: String] = [:]
        if let profileEnv = profile?.environment {
            for (k, v) in profileEnv { mergedEnv[k] = v }
        }
        if let customEnv = app.customEnvironment {
            for (k, v) in customEnv { mergedEnv[k] = v }
        }
        let extraEnvExports = mergedEnv.keys.sorted()
            .map { "export \($0)=\(shellQuote(mergedEnv[$0]!))" }
            .joined(separator: "\n")

        // Generic startup service launcher block derived from profile autoStartServices
        var serviceLaunchBlocks: [String] = []
        if let services = profile?.autoStartServices {
            for svc in services {
                let relExe = svc.windowsExePath
                    .replacingOccurrences(of: "\\", with: "/")
                    .replacingOccurrences(of: "C:/", with: "", options: [.caseInsensitive, .anchored])
                let portCheck = svc.tcpPort > 0 ? "&& ! lsof -nP -iTCP:\(svc.tcpPort) -sTCP:LISTEN >/dev/null 2>&1" : ""
                let portWait = svc.tcpPort > 0
                    ? """
                    for _ in $(seq 1 40); do
                        lsof -nP -iTCP:\(svc.tcpPort) -sTCP:LISTEN >/dev/null 2>&1 && break
                        sleep 0.25
                    done
                    """
                    : "sleep 0.5"
                if let licRel = svc.licenseDirRelativeToDriveC, !licRel.isEmpty {
                    let winLicDir = "C:\\" + licRel.replacingOccurrences(of: "/", with: "\\")
                    serviceLaunchBlocks.append("""
                    SVC_DIR="$WINEPREFIX/drive_c/\(licRel)"
                    if [[ -d "$SVC_DIR" && -f "$WINEPREFIX/drive_c/\(relExe)" ]] \(portCheck); then
                        LIC_FILE=""
                        for candidate in "$SVC_DIR"/*.lic; do
                            if [[ -f "$candidate" ]]; then
                                LIC_FILE="$candidate"
                                break
                            fi
                        done
                        if [[ -n "$LIC_FILE" ]]; then
                            if [[ -f "$WINEPREFIX/.zinkkrisp_offline" ]]; then
                                WINEPREFIX="$WINEPREFIX" WINEDEBUG="-all" /usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network-outbound (remote ip "*:*")) (deny network-inbound (local ip "*:*")) (allow network-outbound (remote ip "localhost:*")) (allow network-inbound (local ip "localhost:*"))' \(shellQuote(wineBinaryURL.path)) \(shellQuote(svc.windowsExePath)) -c "\(winLicDir)\\$(basename "$LIC_FILE")" -l "\(winLicDir)\\$(basename "$LIC_FILE" .lic).log" -z2 >/dev/null 2>&1 &
                            else
                                WINEPREFIX="$WINEPREFIX" WINEDEBUG="-all" \(shellQuote(wineBinaryURL.path)) \(shellQuote(svc.windowsExePath)) -c "\(winLicDir)\\$(basename "$LIC_FILE")" -l "\(winLicDir)\\$(basename "$LIC_FILE" .lic).log" -z2 >/dev/null 2>&1 &
                            fi
                            \(portWait)
                        fi
                    fi
                    """)
                } else {
                    serviceLaunchBlocks.append("""
                    if [[ -f "$WINEPREFIX/drive_c/\(relExe)" ]] \(portCheck); then
                        if [[ -f "$WINEPREFIX/.zinkkrisp_offline" ]]; then
                            WINEPREFIX="$WINEPREFIX" WINEDEBUG="-all" /usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network-outbound (remote ip "*:*")) (deny network-inbound (local ip "*:*")) (allow network-outbound (remote ip "localhost:*")) (allow network-inbound (local ip "localhost:*"))' \(shellQuote(wineBinaryURL.path)) \(shellQuote(svc.windowsExePath)) >/dev/null 2>&1 &
                        else
                            WINEPREFIX="$WINEPREFIX" WINEDEBUG="-all" \(shellQuote(wineBinaryURL.path)) \(shellQuote(svc.windowsExePath)) >/dev/null 2>&1 &
                        fi
                        \(portWait)
                    fi
                    """)
                }
            }
        }
        let serviceStartupScript = serviceLaunchBlocks.joined(separator: "\n")
        let script = """
        #!/usr/bin/env bash
        set -euo pipefail
        ulimit -n 65536 2>/dev/null || true
        export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
        export WINEPREFIX=\(shellQuote(prefixURL.path))
        export WINEDEBUG="-all"
        export WINEDLLOVERRIDES=\(shellQuote(overridesString))
        export VK_DRIVER_FILES=\(shellQuote(icdJSONURL.path))
        export VK_ICD_FILENAMES=\(shellQuote(icdJSONURL.path))
        export WINEMSYNC="1"
        export FEX_TSOENABLED="0"
        export FEX_VECTORTSOENABLED="0"
        export FEX_MEMCPYSETTSOENABLED="0"
        export FEX_HALFBARRIERTSOENABLED="0"
        export FEX_MULTIBLOCK="1"
        export FEX_MAXINST="5000"
        export mesa_glthread="true"
        export MESA_LOADER_DRIVER_OVERRIDE="zink"
        export MESA_GL_VERSION_OVERRIDE="4.6COMPAT"
        export MESA_GLSL_VERSION_OVERRIDE="460"
        export MESA_KK_EXPERIMENTAL="custom_border"
        export KK_SPOOF_SMOOTH_LINES=\(app.cadWireframeFastPath ? "\"1\"" : "\"0\"")
        export KK_CLAMP_VIEW_MISMATCH="1"
        export KK_SYNC_BACKING_SCALE="0"
        export MTL_HUD_ENABLED=\(app.showMetalHUD ? "\"1\"" : "\"0\"")
        export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--remote-debugging-port=9222 --remote-allow-origins=* --no-sandbox --in-process-gpu --disable-direct-composition --disable-features=RemoveRedirectionBitmap,DirectComposition,CalculateNativeWinOcclusion --edge-webview-disable-mojo-ipcz --disk-cache-size=1 --media-cache-size=1 --disable-gpu-shader-disk-cache --disable-application-cache --disable-background-networking --disable-component-update --disable-domain-reliability --disable-sync"
        \(extraEnvExports)
        \(serviceStartupScript)
        if [[ -d \(shellQuote(exeDir)) ]]; then
            cd \(shellQuote(exeDir))
        fi
        LOG_FILE="${TMPDIR:-/tmp}/zinkkrisp_\(safeLogName).log"
        if [[ -f "$WINEPREFIX/.zinkkrisp_offline" ]]; then
            exec /usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network-outbound (remote ip "*:*")) (deny network-inbound (local ip "*:*")) (allow network-outbound (remote ip "localhost:*")) (allow network-inbound (local ip "localhost:*"))' \(shellQuote(wineBinaryURL.path)) \(shellQuote(targetExeArg)) "$@" >"$LOG_FILE" 2>&1
        else
            exec \(shellQuote(wineBinaryURL.path)) \(shellQuote(targetExeArg)) "$@" >"$LOG_FILE" 2>&1
        fi
        """
        let launcherURL = macOSURL.appendingPathComponent("launcher")
        try script.write(to: launcherURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcherURL.path)

        // 4. Clear quarantine attributes & ad-hoc codesign
        runTool("/usr/bin/xattr", arguments: ["-cr", bundleURL.path])
        runTool("/usr/bin/codesign", arguments: ["--force", "--deep", "--sign", "-", bundleURL.path])

        return bundleURL
    }

    private static func writeICNS(image: NSImage, to icnsURL: URL) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let dest = CGImageDestinationCreateWithURL(icnsURL as CFURL, "com.apple.icns" as CFString, 1, nil) else {
            return
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Windows App" : cleaned
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    @discardableResult
    private static func runTool(_ path: String, arguments: [String]) -> Int32 {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus
    }
}
