// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZinkKrisp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ZinkKrispCore", targets: ["ZinkKrispCore"]),
        .executable(name: "ZinkKrisp", targets: ["ZinkKrisp"]),
        .executable(name: "ZinkKrispSmokeTest", targets: ["ZinkKrispSmokeTest"])
    ],
    targets: [
        .target(
            name: "ZinkKrispCore",
            path: "Sources/ZinkKrispCore"
        ),
        .executableTarget(
            name: "ZinkKrisp",
            dependencies: ["ZinkKrispCore"],
            path: "Sources/ZinkKrisp"
        ),
        .executableTarget(
            name: "ZinkKrispSmokeTest",
            dependencies: ["ZinkKrispCore"],
            path: "Sources/ZinkKrispSmokeTest"
        )
    ]
)
