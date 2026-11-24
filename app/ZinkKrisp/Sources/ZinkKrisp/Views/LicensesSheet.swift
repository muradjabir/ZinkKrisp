import SwiftUI

struct LicensesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let licensesText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("About ZinkKrisp & Third-Party Licenses")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }

            ScrollView {
                Text(licensesText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
        .frame(width: 620, height: 460)
    }
}
