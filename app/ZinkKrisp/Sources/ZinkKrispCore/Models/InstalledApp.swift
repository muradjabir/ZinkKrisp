import Foundation

public struct InstalledApp: Codable, Identifiable, Hashable {
    public var id: UUID
    public var containerID: String
    public var name: String
    public var exeRelativePath: String   // Relative to drive_c, e.g. "Program Files/SOLIDWORKS/SLDWORKS.exe"
    public var macAppBundlePath: String? // e.g. "/Users/<user>/Applications/SOLIDWORKS 2024.app"
    public var retina2xMode: Bool
    public var displayScalingMode: DisplayScalingMode
    public var cadWireframeFastPath: Bool
    public var showMetalHUD: Bool
    public var architecture: PEArchitecture
    public var lastLaunchedAt: Date?
    public var profileID: String?
    public var customDllOverrides: [String: String]?
    public var customEnvironment: [String: String]?

    public init(
        id: UUID = UUID(),
        containerID: String,
        name: String,
        exeRelativePath: String,
        macAppBundlePath: String? = nil,
        retina2xMode: Bool = true,
        displayScalingMode: DisplayScalingMode = .auto,
        cadWireframeFastPath: Bool = true,
        showMetalHUD: Bool = false,
        architecture: PEArchitecture = .unknown,
        lastLaunchedAt: Date? = nil,
        profileID: String? = nil,
        customDllOverrides: [String: String]? = nil,
        customEnvironment: [String: String]? = nil
    ) {
        self.id = id
        self.containerID = containerID
        self.name = name
        self.exeRelativePath = exeRelativePath
        self.macAppBundlePath = macAppBundlePath
        self.retina2xMode = retina2xMode
        self.displayScalingMode = displayScalingMode
        self.cadWireframeFastPath = cadWireframeFastPath
        self.showMetalHUD = showMetalHUD
        self.architecture = architecture
        self.lastLaunchedAt = lastLaunchedAt
        self.profileID = profileID
        self.customDllOverrides = customDllOverrides
        self.customEnvironment = customEnvironment
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.id = id
        self.containerID = try container.decodeIfPresent(String.self, forKey: .containerID) ?? id.uuidString
        self.name = try container.decode(String.self, forKey: .name)
        self.exeRelativePath = try container.decode(String.self, forKey: .exeRelativePath)
        self.macAppBundlePath = try container.decodeIfPresent(String.self, forKey: .macAppBundlePath)
        let retina = try container.decodeIfPresent(Bool.self, forKey: .retina2xMode) ?? true
        self.retina2xMode = retina
        self.displayScalingMode = try container.decodeIfPresent(DisplayScalingMode.self, forKey: .displayScalingMode)
            ?? (retina ? .auto : .standard1x)
        self.cadWireframeFastPath = try container.decodeIfPresent(Bool.self, forKey: .cadWireframeFastPath) ?? true
        self.showMetalHUD = try container.decodeIfPresent(Bool.self, forKey: .showMetalHUD) ?? false
        self.architecture = try container.decodeIfPresent(PEArchitecture.self, forKey: .architecture) ?? .unknown
        self.lastLaunchedAt = try container.decodeIfPresent(Date.self, forKey: .lastLaunchedAt)
        self.profileID = try container.decodeIfPresent(String.self, forKey: .profileID)
        self.customDllOverrides = try container.decodeIfPresent([String: String].self, forKey: .customDllOverrides)
        self.customEnvironment = try container.decodeIfPresent([String: String].self, forKey: .customEnvironment)
    }

    public var windowsExePath: String {
        let normalized = exeRelativePath.replacingOccurrences(of: "/", with: "\\")
        if exeRelativePath.hasPrefix("/") {
            return "Z:" + normalized
        }
        return "C:\\" + normalized
    }

    public func containerURL(in containersRoot: URL) -> URL {
        containersRoot.appendingPathComponent(containerID, isDirectory: true)
    }

    public func driveCURL(in containersRoot: URL) -> URL {
        containerURL(in: containersRoot).appendingPathComponent("drive_c", isDirectory: true)
    }

    public func unixExeURL(inContainerRoot containersRoot: URL) -> URL {
        if exeRelativePath.hasPrefix("/") {
            return URL(fileURLWithPath: exeRelativePath)
        }
        return driveCURL(in: containersRoot).appendingPathComponent(exeRelativePath)
    }

    public func unixExeURL(in prefixURL: URL) -> URL {
        if exeRelativePath.hasPrefix("/") {
            return URL(fileURLWithPath: exeRelativePath)
        }
        return prefixURL.appendingPathComponent("drive_c", isDirectory: true).appendingPathComponent(exeRelativePath)
    }
}
