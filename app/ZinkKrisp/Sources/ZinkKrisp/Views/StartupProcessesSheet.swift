import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ZinkKrispCore

struct StartupProcessesSheet: View {
    @ObservedObject var engine: EngineManager
    let containerID: String

    @State private var processes: [ContainerStartupProcess] = []
    @State private var newName: String = ""
    @State private var newWindowsPath: String = ""
    @State private var newArgsText: String = ""
    @State private var newPortText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Startup Processes — \(containerID)")
                        .font(.title3.weight(.semibold))
                    Text("These background processes start automatically whenever any executable launches in this container (without duplicating running instances).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                let isUp = engine.runningContainerIDs.contains(containerID)
                HStack(spacing: 5) {
                    Circle()
                        .fill(isUp ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text(isUp ? "Container Up" : "Stopped")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.6), in: Capsule())
            }

            Divider()

            if processes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "gearshape.2")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No startup processes registered yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(processes) { proc in
                            HStack(spacing: 10) {
                                Toggle("", isOn: Binding(
                                    get: { proc.enabled },
                                    set: { _ in
                                        engine.toggleStartupProcess(id: proc.id, for: containerID)
                                        reload()
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(proc.name)
                                            .font(.callout.weight(.medium))
                                        if let port = proc.tcpPort {
                                            Text("TCP :\(port)")
                                                .font(.caption2.monospacedDigit())
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.12))
                                                .foregroundStyle(.blue)
                                                .clipShape(Capsule())
                                        }
                                        if engine.isStartupProcessRunning(proc, in: containerID) {
                                            Text("Running")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.green.opacity(0.15))
                                                .foregroundStyle(.green)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(proc.windowsExePath + (proc.arguments.isEmpty ? "" : " " + proc.arguments.joined(separator: " ")))
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    engine.removeStartupProcess(id: proc.id, for: containerID)
                                    reload()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove Startup Process")
                            }
                            .padding(10)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Register Startup Process")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    TextField("Name (e.g. Background Service)", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    TextField("TCP Port (optional)", text: $newPortText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 130)
                }

                HStack(spacing: 8) {
                    TextField("Windows path (e.g. C:\\Services\\daemon.exe)", text: $newWindowsPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse C:...") {
                        browseForExe()
                    }
                }

                TextField("Arguments (space-separated, optional)", text: $newArgsText)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Auto-Detect Services") {
                        engine.autoDiscoverStartupProcesses(for: containerID)
                        reload()
                    }
                    Spacer()
                    Button("Add Startup Process") {
                        addProcess()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newWindowsPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            HStack {
                if engine.runningContainerIDs.contains(containerID) {
                    Button("Stop Container", role: .destructive) {
                        Task {
                            await engine.stopContainer(containerID: containerID)
                            reload()
                        }
                    }
                }
                Spacer()
                Button("Done") {
                    engine.managingStartupContainerID = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560)
        .onAppear {
            engine.autoDiscoverStartupProcesses(for: containerID)
            reload()
        }
    }

    private func reload() {
        processes = engine.startupProcesses(for: containerID)
    }

    private func browseForExe() {
        let driveC = engine.driveCURL(for: containerID)
        let panel = NSOpenPanel()
        panel.title = "Select Startup Executable in \(containerID)"
        panel.directoryURL = driveC
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let exeType = UTType(filenameExtension: "exe") {
            panel.allowedContentTypes = [exeType]
        }
        if panel.runModal() == .OK, let url = panel.url {
            let base = driveC.standardizedFileURL.path + "/"
            let path = url.standardizedFileURL.path
            if path.hasPrefix(base) {
                let rel = String(path.dropFirst(base.count)).replacingOccurrences(of: "/", with: "\\")
                newWindowsPath = "C:\\" + rel
            } else {
                newWindowsPath = path
            }
            if newName.isEmpty {
                newName = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func addProcess() {
        let trimmedPath = newWindowsPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let args = newArgsText
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        let port = Int(newPortText.trimmingCharacters(in: .whitespacesAndNewlines))
        let proc = ContainerStartupProcess(
            name: name.isEmpty ? URL(fileURLWithPath: trimmedPath.replacingOccurrences(of: "\\", with: "/")).deletingPathExtension().lastPathComponent : name,
            windowsExePath: trimmedPath,
            arguments: args,
            tcpPort: port,
            enabled: true
        )
        engine.registerStartupProcess(proc, for: containerID)
        newName = ""
        newWindowsPath = ""
        newArgsText = ""
        newPortText = ""
        reload()
    }
}
