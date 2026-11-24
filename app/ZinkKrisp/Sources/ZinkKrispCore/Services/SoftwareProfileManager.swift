import Foundation

public final class SoftwareProfileManager {
    public static let shared = SoftwareProfileManager()

    public let configsURL: URL
    private var userProfiles: [SoftwareProfile] = []

    public static let builtInProfiles: [SoftwareProfile] = [
        SoftwareProfile(
            id: "solidworks-2024",
            displayName: "SOLIDWORKS 2024",
            exeNames: ["sldworks.exe"],
            requiredPrerequisites: [
                .dotnet48,
                .mscoreeShim,
                .vcredist2022x64,
                .vcredist2022x86
            ],
            dllOverrides: [
                "opengl32": "n,b",
                "mscoree": "n",
                "concrt140": "n,b",
                "msvcp140": "n,b",
                "msvcp140_1": "n,b",
                "msvcp140_2": "n,b",
                "msvcp140_atomic_wait": "n,b",
                "msvcp140_codecvt_ids": "n,b",
                "vcamp140": "n,b",
                "vccorlib140": "n,b",
                "vcruntime140": "n,b",
                "vcruntime140_1": "n,b",
                "vcruntime140_threads": "n,b",
                "mfc140u": "n,b",
                "mfcm140u": "n,b",
                "vcomp140": "n,b",
                "mshtml": "d"
            ],
            environment: [
                "WINEMSYNC": "1",
                "FEX_TSOENABLED": "0",
                "FEX_VECTORTSOENABLED": "0",
                "FEX_MEMCPYSETTSOENABLED": "0",
                "FEX_HALFBARRIERTSOENABLED": "0",
                "FEX_MULTIBLOCK": "1",
                "FEX_MAXINST": "5000",
                "mesa_glthread": "true",
                "MESA_LOADER_DRIVER_OVERRIDE": "zink",
                "MESA_GL_VERSION_OVERRIDE": "4.6COMPAT",
                "MESA_GLSL_VERSION_OVERRIDE": "460",
                "MESA_KK_EXPERIMENTAL": "custom_border",
                "MKL_ENABLE_INSTRUCTIONS": "SSE4_2",
                "MKL_DEBUG_CPU_TYPE": "5",
                "KK_CLAMP_VIEW_MISMATCH": "1",
                "KK_SYNC_BACKING_SCALE": "0"
            ],
            windowsVersion: "win10",
            autoStartServices: [
                ServiceLaunchSpec(
                    name: "SolidWorks FlexNet Server",
                    windowsExePath: "C:\\SolidWorks_Flexnet_Server\\lmgrd.exe",
                    licenseDirRelativeToDriveC: "SolidWorks_Flexnet_Server",
                    tcpPort: 25734
                )
            ],
            offlineSandbox: true,
            registryEntries: [
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\General", valueName: "Use Software OGL", valueType: "REG_DWORD", valueData: "00000000"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\General", valueName: "Software OGL Alarm", valueType: "REG_DWORD", valueData: "00000000"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance", valueName: "Software OpenGL", valueType: "REG_DWORD", valueData: "00000000"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance", valueName: "Use Performance Pipeline 2020", valueType: "REG_DWORD", valueData: "00000001"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance", valueName: "Use GPU Silhouette Edges", valueType: "REG_DWORD", valueData: "00000000"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance", valueName: "OpenGL MultiSample", valueType: "REG_DWORD", valueData: "00000003"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance", valueName: "OGL Display Shaders", valueType: "REG_DWORD", valueData: "00000001"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance\\Graphics\\Hardware\\Mesa", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "04000000"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance\\Graphics\\Hardware\\Mesa\\zink", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "04000000"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance\\Graphics\\Hardware\\Mesa\\zink Vulkan 1.4({{APPLE_GPU}} (MESA_KOSMICKRISP))", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "04000000"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance\\Graphics\\Hardware\\Gl2Shaders\\NV40\\zink", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "00032408"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance\\Graphics\\Hardware\\Gl2Shaders\\NV40\\zink Vulkan 1.4({{APPLE_GPU}} (MESA_KOSMICKRISP))", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "00032408"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance\\Graphics\\Hardware\\Gl2Shaders\\Other\\zink", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "00032408"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\SOLIDWORKS 2024\\Performance\\Graphics\\Hardware\\Gl2Shaders\\Other\\zink Vulkan 1.4({{APPLE_GPU}} (MESA_KOSMICKRISP))", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "00032408"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\AllowList\\Mesa", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "04000000"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\AllowList\\Mesa\\zink", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "04000000"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\AllowList\\Mesa\\zink Vulkan 1.4({{APPLE_GPU}} (MESA_KOSMICKRISP))", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "04000000"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\AllowList\\Gl2Shaders\\Other\\zink", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "00032408"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\AllowList\\Gl2Shaders\\Other\\zink Vulkan 1.4({{APPLE_GPU}} (MESA_KOSMICKRISP))", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "00032408"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\AllowList\\Gl2Shaders\\NV40\\zink", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "00032408"),
                RegistryEntrySpec(keyPath: "HKEY_CURRENT_USER\\Software\\SolidWorks\\AllowList\\Gl2Shaders\\NV40\\zink Vulkan 1.4({{APPLE_GPU}} (MESA_KOSMICKRISP))", valueName: "Workarounds", valueType: "REG_DWORD", valueData: "00032408")
            ],
            notes: "Requires native .NET Framework 4.8 (via mscoree shim), VC++ 2015-2022 runtimes, and FlexNet license server on port 25734.",
            isBuiltIn: true
        ),
        SoftwareProfile(
            id: "solidworks-setup",
            displayName: "SOLIDWORKS Installation Manager",
            exeNames: ["sldim.exe", "setup.exe"],
            requiredPrerequisites: [
                .webview2,
                .dotnet48,
                .mscoreeShim,
                .vcredist2022x64,
                .vcredist2022x86
            ],
            dllOverrides: [
                "opengl32": "n,b",
                "mscoree": "n",
                "concrt140": "n,b",
                "msvcp140": "n,b",
                "msvcp140_1": "n,b",
                "msvcp140_2": "n,b",
                "msvcp140_atomic_wait": "n,b",
                "msvcp140_codecvt_ids": "n,b",
                "vcamp140": "n,b",
                "vccorlib140": "n,b",
                "vcruntime140": "n,b",
                "vcruntime140_1": "n,b",
                "vcruntime140_threads": "n,b",
                "mfc140u": "n,b",
                "mfcm140u": "n,b",
                "vcomp140": "n,b"
            ],
            environment: [
                "WINEMSYNC": "1",
                "FEX_MULTIBLOCK": "1",
                "FEX_MAXINST": "5000"
            ],
            windowsVersion: "win10",
            autoStartServices: [],
            offlineSandbox: false,
            notes: "Requires Edge WebView2 Runtime for installer UI, plus .NET 4.8 (mscoree shim) and VC++ 2015-2022 runtimes for MSI custom actions (e.g. Toolbox database initialization).",
            isBuiltIn: true
        )
    ]

    private init() {
        let fm = FileManager.default
        let baseSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ZinkKrisp", isDirectory: true)
        self.configsURL = baseSupport.appendingPathComponent("Configs", isDirectory: true)
        try? fm.createDirectory(at: configsURL, withIntermediateDirectories: true)
        seedDefaultConfigsIfNeeded()
        reloadUserProfiles()
    }

    private func seedDefaultConfigsIfNeeded() {
        let fm = FileManager.default
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for profile in Self.builtInProfiles {
            let fileURL = configsURL.appendingPathComponent("\(profile.id).json")
            if !fm.fileExists(atPath: fileURL.path) {
                var diskCopy = profile
                diskCopy.isBuiltIn = false
                if let data = try? encoder.encode(diskCopy) {
                    try? data.write(to: fileURL, options: .atomic)
                }
            }
        }
    }

    public func reloadUserProfiles() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: configsURL, includingPropertiesForKeys: nil) else {
            userProfiles = []
            return
        }
        let decoder = JSONDecoder()
        var loaded: [SoftwareProfile] = []
        for url in files where url.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: url),
               let profile = try? decoder.decode(SoftwareProfile.self, from: data) {
                loaded.append(profile)
            }
        }
        userProfiles = loaded
    }

    public func allProfiles() -> [SoftwareProfile] {
        var byID: [String: SoftwareProfile] = [:]
        for p in Self.builtInProfiles {
            byID[p.id] = p
        }
        for p in userProfiles {
            byID[p.id] = p
        }
        return byID.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public func profile(for app: InstalledApp) -> SoftwareProfile? {
        let all = allProfiles()
        if let explicitID = app.profileID,
           let match = all.first(where: { $0.id == explicitID }) {
            return match
        }
        let exeName = URL(fileURLWithPath: app.exeRelativePath).lastPathComponent.lowercased()
        return all.first { profile in
            profile.exeNames.contains { $0.lowercased() == exeName }
        }
    }

    public func saveProfile(_ profile: SoftwareProfile) throws {
        var toSave = profile
        toSave.isBuiltIn = false
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let sanitizedID = profile.id
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9._-]+", with: "-", options: .regularExpression)
        let fileURL = configsURL.appendingPathComponent("\(sanitizedID).json")
        let data = try encoder.encode(toSave)
        try data.write(to: fileURL, options: .atomic)
        reloadUserProfiles()
    }

    public func buildProfile(from app: InstalledApp, requiredPrerequisites: [PrerequisiteID] = []) -> SoftwareProfile {
        let exeName = URL(fileURLWithPath: app.exeRelativePath).lastPathComponent.lowercased()
        let baseID = app.name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        var overrides = app.customDllOverrides ?? ["opengl32": "n,b"]
        if requiredPrerequisites.contains(.mscoreeShim) {
            overrides["mscoree"] = "n"
        }
        var env = app.customEnvironment ?? [
            "WINEMSYNC": "1",
            "FEX_MULTIBLOCK": "1",
            "FEX_MAXINST": "5000",
            "mesa_glthread": "true"
        ]
        if app.cadWireframeFastPath {
            env["KK_SPOOF_SMOOTH_LINES"] = "1"
        }
        return SoftwareProfile(
            id: baseID.isEmpty ? UUID().uuidString.lowercased() : baseID,
            displayName: app.name,
            exeNames: [exeName],
            requiredPrerequisites: requiredPrerequisites,
            dllOverrides: overrides,
            environment: env,
            windowsVersion: "win10",
            autoStartServices: [],
            offlineSandbox: false,
            notes: "Saved user configuration for \(app.name)",
            isBuiltIn: false
        )
    }
}
