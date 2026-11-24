import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ZinkKrispCore

struct NewAppSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine: EngineManager

    @State private var appName: String
    @State private var selectedInstallerURL: URL?
    @State private var allowInternet: Bool = true

    init(engine: EngineManager, initialInstallerURL: URL? = nil) {
        self.engine = engine
        let defaultName = initialInstallerURL?.deletingPathExtension().lastPathComponent ?? ""
        _appName = State(initialValue: defaultName)
        _selectedInstallerURL = State(initialValue: initialInstallerURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create Isolated App Container")
                        .font(.title3.weight(.semibold))
                    Text("Each app gets its own clean Windows C: drive cloned instantaneously via APFS Copy-on-Write.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("App / Container Name")
                    .font(.subheadline.weight(.medium))
                TextField("e.g. SOLIDWORKS 2024, MeshLab, Blender", text: $appName)
                    .textFieldStyle(.roundedBorder)
                if isDuplicateName {
                    Text("A container named \"\(resolvedContainerName)\" already exists. Please choose another name.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Windows Installer or Executable (Optional)")
                    .font(.subheadline.weight(.medium))
                HStack {
                    Text(selectedInstallerURL?.path ?? "None — create an empty isolated container")
                        .font(.caption)
                        .foregroundStyle(selectedInstallerURL == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))

                    if selectedInstallerURL != nil {
                        Button("Clear") {
                            selectedInstallerURL = nil
                        }
                    }

                    Button("Browse...") {
                        pickInstaller()
                    }
                }
            }

            Toggle("Allow Internet Connectivity", isOn: $allowInternet)
                .font(.subheadline)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(selectedInstallerURL == nil ? "Create Container" : "Create & Run Installer") {
                    let name = appName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let url = selectedInstallerURL
                    let internet = allowInternet
                    dismiss()
                    Task {
                        let finalName = name.isEmpty ? (url?.deletingPathExtension().lastPathComponent ?? "Container") : name
                        await engine.createNewAppAndRunInstaller(
                            appName: finalName,
                            installerURL: url,
                            allowInternet: internet
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled((appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedInstallerURL == nil) || isDuplicateName)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 500)
    }

    private var resolvedContainerName: String {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return selectedInstallerURL?.deletingPathExtension().lastPathComponent ?? ""
    }

    private var isDuplicateName: Bool {
        let name = resolvedContainerName
        guard !name.isEmpty else { return false }
        return engine.containerExists(named: name)
    }

    private func pickInstaller() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "exe"),
            UTType(filenameExtension: "msi"),
            UTType(filenameExtension: "bat"),
            UTType(filenameExtension: "cmd"),
            UTType(filenameExtension: "reg"),
            UTType(filenameExtension: "zip")
        ].compactMap { $0 }
        panel.message = "Choose a Windows installer, portable archive, or executable (.exe, .msi, .zip, .bat, .cmd, .reg)"
        if panel.runModal() == .OK, let url = panel.url {
            selectedInstallerURL = url
            if appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appName = url.deletingPathExtension().lastPathComponent
            }
        }
    }
}
