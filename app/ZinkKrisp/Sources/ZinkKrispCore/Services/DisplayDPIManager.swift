import AppKit
import Foundation

public enum DisplayScalingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto
    case retina2x
    case multiMonitorSeamless
    case standard1x

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .auto:
            return "Auto (Match Connected Displays)"
        case .retina2x:
            return "Retina 2x High-DPI (192 DPI)"
        case .multiMonitorSeamless:
            return "Seamless Multi-Monitor (Point-Scaled)"
        case .standard1x:
            return "Standard 1x (96 DPI)"
        }
    }
}

public enum DisplayTopology: String, Sendable {
    case pureRetina
    case pureStandard1x
    case mixedDPI

    public var summary: String {
        switch self {
        case .pureRetina:
            return "Pure Retina (2.0x)"
        case .pureStandard1x:
            return "Standard 1x (Non-Retina)"
        case .mixedDPI:
            return "Mixed DPI (2.0x + 1.0x)"
        }
    }
}

public struct ResolvedDPIConfig: Equatable, Sendable {
    public let retinaMode: String        // "y" or "n"
    public let logPixels: UInt32         // 192 or 96
    public let appCompatLayer: String?   // e.g. "~ HIGHDPIAWARE"
    public let syncBackingScale: Bool
}

@MainActor
public final class DisplayDPIManager {
    public static let shared = DisplayDPIManager()

    private var screenObserver: NSObjectProtocol?
    private var appliedConfigs: [String: ResolvedDPIConfig] = [:]

    private init() {}

    public func currentTopology() -> DisplayTopology {
        let scales = NSScreen.screens.map { $0.backingScaleFactor }
        guard !scales.isEmpty else { return .pureRetina }
        let hasRetina = scales.contains { $0 >= 2.0 }
        let hasStandard = scales.contains { $0 < 2.0 }
        if hasRetina && hasStandard {
            return .mixedDPI
        }
        return hasRetina ? .pureRetina : .pureStandard1x
    }

    public func resolveSettings(
        for mode: DisplayScalingMode,
        topology: DisplayTopology? = nil
    ) -> ResolvedDPIConfig {
        let activeTopology = topology ?? currentTopology()
        switch mode {
        case .retina2x:
            return ResolvedDPIConfig(retinaMode: "y", logPixels: 192, appCompatLayer: nil, syncBackingScale: true)
        case .standard1x:
            return ResolvedDPIConfig(retinaMode: "n", logPixels: 96, appCompatLayer: nil, syncBackingScale: true)
        case .multiMonitorSeamless:
            return ResolvedDPIConfig(retinaMode: "n", logPixels: 96, appCompatLayer: "~ HIGHDPIAWARE", syncBackingScale: true)
        case .auto:
            switch activeTopology {
            case .pureRetina:
                return ResolvedDPIConfig(retinaMode: "y", logPixels: 192, appCompatLayer: nil, syncBackingScale: true)
            case .pureStandard1x:
                return ResolvedDPIConfig(retinaMode: "n", logPixels: 96, appCompatLayer: nil, syncBackingScale: true)
            case .mixedDPI:
                return ResolvedDPIConfig(retinaMode: "n", logPixels: 96, appCompatLayer: "~ HIGHDPIAWARE", syncBackingScale: true)
            }
        }
    }

    public func startObservingScreenChanges(onChange: @escaping @MainActor () -> Void) {
        if let existing = screenObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onChange()
            }
        }
    }

    public func applyDPISettings(
        for mode: DisplayScalingMode,
        exeWindowsPath: String?,
        wineBin: URL,
        environment: [String: String]
    ) async {
        let resolved = resolveSettings(for: mode)
        let cacheKey = "\(environment["WINEPREFIX"] ?? "")|\((exeWindowsPath ?? "").lowercased())"
        if appliedConfigs[cacheKey] == resolved {
            return
        }
        let dpiStr = String(resolved.logPixels)

        _ = await runReg(wineBin: wineBin, env: environment, args: [
            "reg", "add", #"HKCU\Software\Wine\Mac Driver"#, "/v", "RetinaMode", "/t", "REG_SZ", "/d", resolved.retinaMode, "/f"
        ])
        _ = await runReg(wineBin: wineBin, env: environment, args: [
            "reg", "add", #"HKCU\Control Panel\Desktop"#, "/v", "LogPixels", "/t", "REG_DWORD", "/d", dpiStr, "/f"
        ])
        _ = await runReg(wineBin: wineBin, env: environment, args: [
            "reg", "add", #"HKCU\Software\Wine\Fonts"#, "/v", "LogPixels", "/t", "REG_DWORD", "/d", dpiStr, "/f"
        ])

        if let exePath = exeWindowsPath, !exePath.isEmpty {
            if let layer = resolved.appCompatLayer {
                _ = await runReg(wineBin: wineBin, env: environment, args: [
                    "reg", "add", #"HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"#,
                    "/v", exePath, "/t", "REG_SZ", "/d", layer, "/f"
                ])
            } else {
                _ = await runReg(wineBin: wineBin, env: environment, args: [
                    "reg", "delete", #"HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"#,
                    "/v", exePath, "/f"
                ])
            }
        }
        appliedConfigs[cacheKey] = resolved
    }

    private func runReg(wineBin: URL, env: [String: String], args: [String]) async -> Int32 {
        await withCheckedContinuation { continuation in
            let proc = Process()
            proc.executableURL = wineBin
            proc.arguments = args
            proc.environment = env
            proc.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
            do {
                try proc.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }
    }
}
