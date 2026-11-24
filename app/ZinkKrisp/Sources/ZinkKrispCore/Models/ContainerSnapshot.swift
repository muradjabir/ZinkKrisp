import Foundation

public struct ContainerSnapshot: Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let containerID: String
    public var name: String
    public let createdAt: Date
    public let directoryName: String

    public init(
        id: UUID = UUID(),
        containerID: String,
        name: String,
        createdAt: Date = Date(),
        directoryName: String
    ) {
        self.id = id
        self.containerID = containerID
        self.name = name
        self.createdAt = createdAt
        self.directoryName = directoryName
    }
}
