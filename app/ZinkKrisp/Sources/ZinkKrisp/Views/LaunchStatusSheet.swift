import SwiftUI
import ZinkKrispCore

struct LaunchStatusSheet: View {
    @ObservedObject var engine: EngineManager
    let session: LaunchStatusSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(headerTint.opacity(0.15))
                        .frame(width: 40, height: 40)
                    if !session.isFinished {
                        ProgressView()
                            .controlSize(.small)
                    } else if session.hasError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.isFinished ? (session.hasError ? "Launch Issue: \(session.executableName)" : "Launched \(session.executableName)") : "Starting \(session.executableName)...")
                        .font(.headline)
                    HStack(spacing: 6) {
                        let isUp = engine.runningContainerIDs.contains(session.containerID)
                        Circle()
                            .fill(isUp ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text("Container \(session.containerID) • \(isUp ? "Running" : "Booting")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(session.steps) { step in
                        HStack(alignment: .top, spacing: 10) {
                            stepIcon(for: step.state)
                                .frame(width: 18, height: 18)
                                .padding(.top, 1)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(step.title)
                                        .font(.callout.weight(.medium))
                                    if step.state == .alreadyRunning {
                                        Text("Already Running")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1.5)
                                            .background(Color.teal.opacity(0.15))
                                            .foregroundStyle(.teal)
                                            .clipShape(Capsule())
                                    }
                                }
                                if !step.detail.isEmpty {
                                    Text(step.detail)
                                        .font(.caption)
                                        .foregroundStyle(step.state == .failed ? .red : .secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxHeight: 280)

            HStack {
                Text(session.isFinished ? "You can now interact with the Windows application." : "Preparing container services and graphics bridge...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(session.isFinished ? "Done" : "Hide") {
                    engine.activeLaunchSession = nil
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var headerTint: Color {
        if !session.isFinished { return .accentColor }
        return session.hasError ? .red : .green
    }

    @ViewBuilder
    private func stepIcon(for state: LaunchStepState) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .inProgress:
            ProgressView()
                .controlSize(.small)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .alreadyRunning:
            Image(systemName: "bolt.circle.fill")
                .foregroundStyle(.teal)
        case .skipped:
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
