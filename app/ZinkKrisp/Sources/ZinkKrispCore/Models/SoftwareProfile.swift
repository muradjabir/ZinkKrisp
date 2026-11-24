import Foundation

public enum PrerequisiteID: String, Codable, CaseIterable, Identifiable, Hashable {
    case dotnet48 = "dotnet48"
    case mscoreeShim = "mscoree_shim"
    case vcredist2022x64 = "vcredist_2022_x64"
    case vcredist2022x86 = "vcredist_2022_x86"
    case webview2 = "webview2"

    public var id: String { rawValue }
}

public struct PrerequisiteDescriptor: Identifiable, Hashable {
    public let id: PrerequisiteID
    public let name: String
    public let vendor: String
    public let description: String
    public let officialDownloadURL: URL?
    public let installerFilename: String?
    public let silentArgs: [String]
    public let requiresWin7DuringInstall: Bool

    public init(
        id: PrerequisiteID,
        name: String,
        vendor: String,
        description: String,
        officialDownloadURL: URL?,
        installerFilename: String?,
        silentArgs: [String] = [],
        requiresWin7DuringInstall: Bool = false
    ) {
        self.id = id
        self.name = name
        self.vendor = vendor
        self.description = description
        self.officialDownloadURL = officialDownloadURL
        self.installerFilename = installerFilename
        self.silentArgs = silentArgs
        self.requiresWin7DuringInstall = requiresWin7DuringInstall
    }
}

public struct PrerequisiteStatus: Identifiable, Hashable {
    public var id: PrerequisiteID { descriptor.id }
    public let descriptor: PrerequisiteDescriptor
    public let isSatisfied: Bool
    public let details: String

    public init(descriptor: PrerequisiteDescriptor, isSatisfied: Bool, details: String) {
        self.descriptor = descriptor
        self.isSatisfied = isSatisfied
        self.details = details
    }
}

public struct ServiceLaunchSpec: Codable, Hashable, Identifiable {
    public var id: String { name }
    public var name: String
    public var windowsExePath: String
    public var licenseDirRelativeToDriveC: String?
    public var tcpPort: Int

    public init(
        name: String,
        windowsExePath: String,
        licenseDirRelativeToDriveC: String? = nil,
        tcpPort: Int
    ) {
        self.name = name
        self.windowsExePath = windowsExePath
        self.licenseDirRelativeToDriveC = licenseDirRelativeToDriveC
        self.tcpPort = tcpPort
    }
}

public struct RegistryEntrySpec: Codable, Hashable {
    public var keyPath: String
    public var valueName: String
    public var valueType: String // "REG_DWORD" or "REG_SZ"
    public var valueData: String

    public init(keyPath: String, valueName: String, valueType: String, valueData: String) {
        self.keyPath = keyPath
        self.valueName = valueName
        self.valueType = valueType
        self.valueData = valueData
    }
}

public struct SoftwareProfile: Codable, Identifiable, Hashable {
    public var id: String
    public var displayName: String
    public var exeNames: [String]
    public var requiredPrerequisites: [PrerequisiteID]
    public var dllOverrides: [String: String]
    public var environment: [String: String]
    public var windowsVersion: String?
    public var autoStartServices: [ServiceLaunchSpec]
    public var offlineSandbox: Bool
    public var registryEntries: [RegistryEntrySpec]?
    public var notes: String?
    public var isBuiltIn: Bool

    public init(
        id: String,
        displayName: String,
        exeNames: [String],
        requiredPrerequisites: [PrerequisiteID] = [],
        dllOverrides: [String: String] = [:],
        environment: [String: String] = [:],
        windowsVersion: String? = nil,
        autoStartServices: [ServiceLaunchSpec] = [],
        offlineSandbox: Bool = false,
        registryEntries: [RegistryEntrySpec]? = nil,
        notes: String? = nil,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.exeNames = exeNames
        self.requiredPrerequisites = requiredPrerequisites
        self.dllOverrides = dllOverrides
        self.environment = environment
        self.windowsVersion = windowsVersion
        self.autoStartServices = autoStartServices
        self.offlineSandbox = offlineSandbox
        self.registryEntries = registryEntries
        self.notes = notes
        self.isBuiltIn = isBuiltIn
    }
}
