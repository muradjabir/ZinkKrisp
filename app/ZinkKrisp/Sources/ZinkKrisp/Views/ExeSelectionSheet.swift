import SwiftUI
import ZinkKrispCore

struct ExeSelectionSheet: View {
    @Binding var candidates: [DiscoveredExe]
    let onConfirm: (Bool) -> Void
    let onCancel: () -> Void

    @State private var createMacApps = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Select Applications to Add")
                .font(.title3.weight(.semibold))
            Text("ZinkKrisp scanned your managed Windows drive and extracted icons and product names.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if candidates.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No application executables found.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                List {
                    ForEach($candidates) { $item in
                        HStack(spacing: 12) {
                            Toggle("", isOn: $item.isSelected)
                                .labelsHidden()
                            Image(nsImage: item.icon)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.productName)
                                        .font(.body.weight(.medium))
                                    if item.architecture != .unknown {
                                        Text(item.architecture.rawValue)
                                            .font(.system(size: 9, weight: .semibold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1.5)
                                            .background(item.architecture == .x64 ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                                            .foregroundStyle(item.architecture == .x64 ? Color.blue : Color.orange)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    if item.alreadyInLibrary {
                                        Text("In Library")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.secondary.opacity(0.15), in: Capsule())
                                    }
                                }
                                Text(item.relativePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .frame(minHeight: 240, maxHeight: 340)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Toggle("Create Shortcut in ~/Applications Folder", isOn: $createMacApps)

            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                Spacer()
                Button("Create Mac App(s)") {
                    onConfirm(createMacApps)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!candidates.contains(where: \.isSelected))
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}
