import Foundation

public struct ContainerStartupProcess: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var windowsExePath: String
    public var arguments: [String]
    public var workingDirectoryRelativeToDriveC: String?
    public var tcpPort: Int?
    public var processMatchName: String
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        windowsExePath: String,
        arguments: [String] = [],
        workingDirectoryRelativeToDriveC: String? = nil,
        tcpPort: Int? = nil,
        processMatchName: String? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.windowsExePath = windowsExePath
        self.arguments = arguments
        self.workingDirectoryRelativeToDriveC = workingDirectoryRelativeToDriveC
        self.tcpPort = tcpPort
        if let match = processMatchName, !match.isEmpty {
            self.processMatchName = match
        } else {
            let normalized = windowsExePath.replacingOccurrences(of: "\\", with: "/")
            self.processMatchName = URL(fileURLWithPath: normalized).lastPathComponent
        }
        self.enabled = enabled
    }

    public func unixExeURL(in driveCURL: URL) -> URL {
        var rel = windowsExePath.replacingOccurrences(of: "\\", with: "/")
        if rel.lowercased().hasPrefix("c:/") {
            rel = String(rel.dropFirst(3))
        }
        while rel.hasPrefix("/") {
            rel.removeFirst()
        }
        return driveCURL.appendingPathComponent(rel)
    }
}

public enum LaunchStepState: Equatable {
    case pending
    case inProgress
    case succeeded
    case alreadyRunning
    case skipped
    case failed
}

public struct LaunchStatusStep: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var detail: String
    public var state: LaunchStepState

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        state: LaunchStepState = .pending
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

public struct LaunchStatusSession: Identifiable, Equatable {
    public let id: UUID
    public let containerID: String
    public let executableName: String
    public var steps: [LaunchStatusStep]
    public var isFinished: Bool
    public var hasError: Bool

    public init(
        id: UUID = UUID(),
        containerID: String,
        executableName: String,
        steps: [LaunchStatusStep] = [],
        isFinished: Bool = false,
        hasError: Bool = false
    ) {
        self.id = id
        self.containerID = containerID
        self.executableName = executableName
        self.steps = steps
        self.isFinished = isFinished
        self.hasError = hasError
    }
}

public struct ContainerForcePrompt: Identifiable, Equatable {
    public enum ActionKind: Equatable {
        case stop
        case delete
    }

    public let id: UUID
    public let containerID: String
    public let action: ActionKind
    public let label: String
    public let runningProcesses: [String]

    public init(
        id: UUID = UUID(),
        containerID: String,
        action: ActionKind,
        label: String,
        runningProcesses: [String]
    ) {
        self.id = id
        self.containerID = containerID
        self.action = action
        self.label = label
        self.runningProcesses = runningProcesses
    }
}
