import AppKit
import Foundation

public struct DiscoveredExe: Identifiable {
    public let id: String
    public let url: URL
    public let relativePath: String
    public let productName: String
    public let fileDescription: String?
    public let icon: NSImage
    public let architecture: PEArchitecture
    public let alreadyInLibrary: Bool
    public var isSelected: Bool

    public init(
        url: URL,
        relativePath: String,
        productName: String,
        fileDescription: String?,
        icon: NSImage,
        architecture: PEArchitecture = .unknown,
        alreadyInLibrary: Bool,
        isSelected: Bool
    ) {
        self.id = relativePath.lowercased()
        self.url = url
        self.relativePath = relativePath
        self.productName = productName
        self.fileDescription = fileDescription
        self.icon = icon
        self.architecture = architecture
        self.alreadyInLibrary = alreadyInLibrary
        self.isSelected = isSelected
    }
}
