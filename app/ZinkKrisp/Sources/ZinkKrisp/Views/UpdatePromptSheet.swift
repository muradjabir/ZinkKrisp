import AppKit
import SwiftUI
import ZinkKrispCore

struct UpdatePromptSheet: View {
    @ObservedObject var checker: UpdateChecker
    let update: AppReleaseUpdate

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Update Available: ZinkKrisp v\(update.version)")
                        .font(.headline)
                    Text("Currently installed: v\(checker.currentVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(update.title)
                    .font(.subheadline.weight(.semibold))

                ScrollView {
                    Text(update.releaseNotes)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 240)
                .padding(10)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Button("Skip This Version") {
                    checker.skipUpdate(update)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Later") {
                    checker.dismissPrompt()
                }
                .keyboardShortcut(.cancelAction)

                Button("Release Page") {
                    NSWorkspace.shared.open(update.htmlURL)
                }
                .buttonStyle(.bordered)

                Button("Download Update") {
                    NSWorkspace.shared.open(update.appZipURL ?? update.htmlURL)
                    checker.dismissPrompt()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}
