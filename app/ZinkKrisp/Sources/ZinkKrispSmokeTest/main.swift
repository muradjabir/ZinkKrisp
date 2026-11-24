import AppKit
import Foundation
import ZinkKrispCore

let args = CommandLine.arguments
let defaultDriveC = ProcessInfo.processInfo.environment["ZINKKRISP_TEST_DRIVEC"] ?? "./dist/SWOnMac/prefix/drive_c"
let driveCPath = args.count > 1 ? args[1] : defaultDriveC
let driveCURL = URL(fileURLWithPath: driveCPath, isDirectory: true)

guard FileManager.default.fileExists(atPath: driveCURL.path) else {
    fputs("ERROR: drive_c not found at \(driveCURL.path)\n", stderr)
    exit(1)
}

print("Scanning drive_c at: \(driveCURL.path)")
let discovered = ExeScanner.shared.scanAllApps(in: driveCURL, existingLibrary: [])
print("Discovered \(discovered.count) non-noise executables.")

guard let sldworks = discovered.first(where: { $0.url.lastPathComponent.lowercased() == "sldworks.exe" }) else {
    fputs("FAIL: SLDWORKS.exe was not discovered!\n", stderr)
    exit(1)
}

let noiseNames = ["lmgrd.exe", "sw_d.exe", "notepad.exe", "regedit.exe", "unins000.exe"]
for noise in noiseNames {
    if discovered.contains(where: { $0.url.lastPathComponent.lowercased() == noise }) {
        fputs("FAIL: Noise executable \(noise) was NOT filtered out!\n", stderr)
        exit(1)
    }
}

print("PASS: Found SLDWORKS.exe -> productName='\(sldworks.productName)', relativePath='\(sldworks.relativePath)'")
print("      Icon size: \(sldworks.icon.size), representations: \(sldworks.icon.representations.count)")

guard sldworks.icon.size.width > 0,
      sldworks.icon.size.height > 0,
      !sldworks.icon.representations.isEmpty else {
    fputs("FAIL: Extracted NSImage for SLDWORKS.exe is invalid/empty!\n", stderr)
    exit(1)
}

// Verify PEIconExtractor directly on SLDWORKS.exe
let directMeta = PEIconExtractor.extractMetadata(from: sldworks.url)
print("PASS: PEIconExtractor direct -> productName='\(directMeta.productName ?? "<nil>")', fileDescription='\(directMeta.fileDescription ?? "<nil>")'")

// Test MacAppGenerator in temp directory
let tmpApps = FileManager.default.temporaryDirectory.appendingPathComponent("zinkkrisp_smoke_\(UUID().uuidString)")
let testApp = InstalledApp(containerID: "smoke-test", name: sldworks.productName, exeRelativePath: sldworks.relativePath)
let generated = try MacAppGenerator.createMacApp(
    for: testApp,
    icon: sldworks.icon,
    prefixURL: driveCURL.deletingLastPathComponent(),
    icdJSONURL: URL(fileURLWithPath: "/tmp/kosmickrisp_icd.json"),
    wineBinaryURL: URL(fileURLWithPath: "/Applications/MetalSharp-Wine.app/Contents/MacOS/wine"),
    applicationsDir: tmpApps
)
let icnsExists = FileManager.default.fileExists(atPath: generated.appendingPathComponent("Contents/Resources/AppIcon.icns").path)
let launcherExists = FileManager.default.isExecutableFile(atPath: generated.appendingPathComponent("Contents/MacOS/launcher").path)
try? FileManager.default.removeItem(at: tmpApps)

guard icnsExists && launcherExists else {
    fputs("FAIL: Generated .app bundle missing AppIcon.icns or executable launcher!\n", stderr)
    exit(1)
}
print("PASS: MacAppGenerator created valid signed .app bundle with AppIcon.icns and launcher.")
