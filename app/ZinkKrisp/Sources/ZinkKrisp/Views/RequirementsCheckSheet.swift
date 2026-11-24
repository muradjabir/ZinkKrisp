import SwiftUI
import ZinkKrispCore

struct RequirementsCheckSheet: View {
    @ObservedObject var engine: EngineManager
    let app: InstalledApp

    private var profile: SoftwareProfile? {
        SoftwareProfileManager.shared.profile(for: app)
    }

    private var allSatisfied: Bool {
        engine.pendingRequirementsStatuses.allSatisfy(\.isSatisfied)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Runtime Requirements: \(app.name)")
                        .font(.headline)
                    if let profile {
                        Text("Config: \(profile.displayName) (\(profile.id))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Container: \(app.containerID)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if allSatisfied {
                    Label("All Ready", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                }
            }

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(engine.pendingRequirementsStatuses) { status in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: status.isSatisfied ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(status.isSatisfied ? .green : .orange)
                                .font(.title3)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(status.descriptor.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(status.descriptor.vendor)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(4)
                                }
                                Text(status.descriptor.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(status.details)
                                    .font(.caption2)
                                    .foregroundColor(status.isSatisfied ? .green : .orange)
                            }

                            Spacer()

                            if !status.isSatisfied {
                                Button(status.descriptor.officialDownloadURL != nil ? "Download & Install" : "Install") {
                                    engine.installPrerequisite(status.id, for: app)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(engine.isInstallingPrereqs)
                            }
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
            .frame(maxHeight: 280)

            if engine.isInstallingPrereqs {
                VStack(alignment: .leading, spacing: 6) {
                    if let prog = engine.prereqProgressValue {
                        ProgressView(value: prog)
                    } else {
                        ProgressView()
                    }
                    Text(engine.prereqProgressMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let err = engine.prereqErrorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(3)
            }

            Divider()

            HStack {
                Button("Close") {
                    engine.pendingRequirementsApp = nil
                }
                .disabled(engine.isInstallingPrereqs)

                Spacer()

                if !allSatisfied {
                    Button("Install All Missing") {
                        engine.installAllMissingPrerequisites(for: app)
                    }
                    .buttonStyle(.bordered)
                    .disabled(engine.isInstallingPrereqs)

                    Button("Launch Anyway") {
                        let target = app
                        engine.pendingRequirementsApp = nil
                        engine.launchApp(target, skipRequirementsCheck: true)
                    }
                    .disabled(engine.isInstallingPrereqs)
                } else {
                    Button("Launch \(app.name)") {
                        let target = app
                        engine.pendingRequirementsApp = nil
                        engine.launchApp(target, skipRequirementsCheck: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(engine.isInstallingPrereqs)
                }
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}
