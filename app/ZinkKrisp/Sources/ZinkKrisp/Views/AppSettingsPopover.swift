import AppKit
import SwiftUI
import ZinkKrispCore

struct AppSettingsPopover: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var engine: EngineManager
    @State var app: InstalledApp

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(app.name)
                .font(.headline)
            Text("Container: \(app.containerID)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Display & Multi-Monitor Scaling")
                    .font(.caption.weight(.medium))
                Picker("Display Scaling", selection: $app.displayScalingMode) {
                    ForEach(DisplayScalingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .onChange(of: app.displayScalingMode) { _, newValue in
                    app.retina2xMode = (newValue == .retina2x || (newValue == .auto && engine.displayTopology == .pureRetina))
                    engine.updateApp(app, recreateShortcut: false)
                    Task { await engine.updateDisplayScaling(for: app, mode: newValue) }
                }
                Text("Detected: \(engine.displayTopology.summary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Toggle("CAD Wireframe Fast-Path", isOn: $app.cadWireframeFastPath)
                .onChange(of: app.cadWireframeFastPath) { _, _ in
                    engine.updateApp(app, recreateShortcut: true)
                }

            Toggle("Metal 4 Performance HUD", isOn: $app.showMetalHUD)
                .onChange(of: app.showMetalHUD) { _, _ in
                    engine.updateApp(app, recreateShortcut: true)
                }

            Divider()

            Button("Check Requirements & Download Runtimes...") {
                let target = app
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    engine.openRequirementsCheck(for: target)
                }
            }

            Button("Save Software Config Preset") {
                let reqs = SoftwareProfileManager.shared.profile(for: app)?.requiredPrerequisites ?? []
                engine.saveSoftwareProfile(for: app, requiredPrerequisites: reqs)
                dismiss()
            }

            Button("Re-create Mac .app Shortcut") {
                engine.updateApp(app, recreateShortcut: true)
            }

            if let bundlePath = app.macAppBundlePath,
               FileManager.default.fileExists(atPath: bundlePath) {
                Button("Reveal .app in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: bundlePath)])
                }
            }

            Divider()

            Button("Remove App from Library", role: .destructive) {
                engine.removeAppFromLibrary(app)
                dismiss()
            }

            Divider()

            Button("Read Architecture & Technical Blog (muradjabir.com)") {
                if let url = URL(string: "https://muradjabir.com/blog/post-rosetta-opengl-apple-silicon") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 300)
    }
}
