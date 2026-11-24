import SwiftUI
import ZinkKrispCore

struct SnapshotsSheet: View {
    @ObservedObject var engine: EngineManager
    let containerID: String

    @State private var snapshots: [ContainerSnapshot] = []
    @State private var newName: String = ""
    @State private var stopBeforeSnapshot: Bool = true
    @State private var confirmRestoreSnapshot: ContainerSnapshot? = nil
    @State private var localMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Restore Points — \(containerID)")
                        .font(.title3.weight(.semibold))
                    Text("Instant APFS Copy-on-Write checkpoints. Restore repeatedly to any saved state in under a second.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                let isUp = engine.runningContainerIDs.contains(containerID)
                HStack(spacing: 5) {
                    Circle()
                        .fill(isUp ? Color.green : Color.secondary.opacity(0.45))
                        .frame(width: 7, height: 7)
                    Text(isUp ? "Running" : "Stopped")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.6), in: Capsule())
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Restore point name (e.g. After prerequisites)", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let label = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = label.isEmpty ? "Restore Point \(snapshots.count + 1)" : label
                        Task {
                            localMessage = nil
                            let ok = await engine.createSnapshot(
                                for: containerID,
                                name: finalName,
                                stopFirst: stopBeforeSnapshot
                            )
                            if ok {
                                newName = ""
                                localMessage = "Created restore point '\(finalName)'."
                            }
                            reload()
                        }
                    } label: {
                        Label("Create Restore Point", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(engine.isSnapshotBusy)
                }

                Toggle("Stop container before snapshotting (recommended for clean Wine registry)", isOn: $stopBeforeSnapshot)
                    .font(.caption)
                    .toggleStyle(.checkbox)
            }

            if engine.isSnapshotBusy {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(engine.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let msg = localMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if snapshots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No restore points yet for \(containerID).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Create one right after installing prerequisites or services so you can roll back instantly while testing.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(snapshots) { snap in
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(snap.name)
                                        .font(.callout.weight(.medium))
                                    Text(snap.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Restore") {
                                    confirmRestoreSnapshot = snap
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(engine.isSnapshotBusy)

                                Button(role: .destructive) {
                                    engine.deleteSnapshot(snap)
                                    localMessage = "Deleted restore point '\(snap.name)'."
                                    reload()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .disabled(engine.isSnapshotBusy)
                                .help("Delete Restore Point")
                            }
                            .padding(10)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxHeight: 230)
            }

            HStack {
                Spacer()
                Button("Done") {
                    engine.managingSnapshotsContainerID = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(engine.isSnapshotBusy)
            }
        }
        .padding(20)
        .frame(width: 540)
        .onAppear {
            reload()
        }
        .alert(item: $confirmRestoreSnapshot) { snap in
            Alert(
                title: Text("Restore '\(containerID)' to '\(snap.name)'?"),
                message: Text("Running processes in '\(containerID)' will be stopped and all container files & registry will be reverted to this restore point. The restore point itself will be kept for future reuse."),
                primaryButton: .destructive(Text("Restore Now")) {
                    Task {
                        localMessage = nil
                        let ok = await engine.restoreSnapshot(snap)
                        if ok {
                            localMessage = "Restored '\(containerID)' to '\(snap.name)'."
                        }
                        reload()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func reload() {
        snapshots = engine.snapshots(for: containerID)
    }
}
