import SwiftUI

struct InstallerProgressSheet: View {
    let installerName: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Installing \(installerName)")
                .font(.headline)
            Text("Complete the Windows setup wizard in the installer window.\nZinkKrisp will automatically scan for newly installed apps when it finishes.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 420)
    }
}
