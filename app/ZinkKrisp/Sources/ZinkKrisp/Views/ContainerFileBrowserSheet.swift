import AppKit
import SwiftUI
import ZinkKrispCore

struct ContainerFileBrowserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine: EngineManager
    let containerID: String

    @State private var currentURL: URL
    @State private var selectedURL: URL?
    @State private var searchText: String = ""

    private let rootURL: URL
    private let runnableExtensions: Set<String> = ["exe", "msi", "bat", "cmd", "reg", "zip"]

    init(engine: EngineManager, containerID: String) {
        self.engine = engine
        self.containerID = containerID
        let driveC = engine.driveCURL(for: containerID).standardizedFileURL
        self.rootURL = driveC
        _currentURL = State(initialValue: driveC)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 10) {
                Button {
                    navigateUp()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canNavigateUp)
                .help("Go Up")

                Text(windowsBreadcrumb)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Filter", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)

                Button {
                    NSWorkspace.shared.open(currentURL)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Reveal Current Folder in Finder")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // File list
            List(items, id: \.self, selection: $selectedURL) { url in
                let isDir = isDirectory(url)
                let isRunnable = !isDir && runnableExtensions.contains(url.pathExtension.lowercased())

                HStack(spacing: 10) {
                    Image(nsImage: icon(for: url, isDir: isDir))
                        .resizable()
                        .frame(width: 20, height: 20)

                    Text(url.lastPathComponent)
                        .foregroundStyle((isDir || isRunnable) ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer()

                    if !isDir {
                        Text(formattedSize(for: url))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    activateItem(url)
                }
                .onTapGesture(count: 1) {
                    selectedURL = url
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()

            // Bottom bar
            HStack {
                Text("Double-click a folder to open, or double-click a .exe / .msi / .bat / .reg / .zip to run.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(primaryActionTitle) {
                    if let selected = selectedURL {
                        activateItem(selected)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canActivateSelected)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 680, height: 480)
    }

    private var canNavigateUp: Bool {
        currentURL.standardizedFileURL.path != rootURL.standardizedFileURL.path
    }

    private var windowsBreadcrumb: String {
        let rootPath = rootURL.standardizedFileURL.path
        let currPath = currentURL.standardizedFileURL.path
        if currPath == rootPath {
            return "C:\\"
        }
        let rel = String(currPath.dropFirst(rootPath.count))
            .replacingOccurrences(of: "/", with: "\\")
        return "C:" + rel
    }

    private var items: [URL] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: currentURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let filtered = contents.filter { url in
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            return url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
        }

        return filtered.sorted { a, b in
            let aDir = isDirectory(a)
            let bDir = isDirectory(b)
            if aDir != bDir { return aDir }
            return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
        }
    }

    private var canActivateSelected: Bool {
        guard let url = selectedURL else { return false }
        if isDirectory(url) { return true }
        return runnableExtensions.contains(url.pathExtension.lowercased())
    }

    private var primaryActionTitle: String {
        guard let url = selectedURL else { return "Run" }
        return isDirectory(url) ? "Open" : "Run"
    }

    private func navigateUp() {
        guard canNavigateUp else { return }
        let parent = currentURL.deletingLastPathComponent().standardizedFileURL
        if parent.path.hasPrefix(rootURL.standardizedFileURL.path) {
            currentURL = parent
            selectedURL = nil
            searchText = ""
        }
    }

    private func activateItem(_ url: URL) {
        if isDirectory(url) {
            currentURL = url.standardizedFileURL
            selectedURL = nil
            searchText = ""
            return
        }
        guard runnableExtensions.contains(url.pathExtension.lowercased()) else { return }
        let cid = containerID
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            await engine.runFileInContainer(containerID: cid, containerName: cid, url: url)
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func icon(for url: URL, isDir: Bool) -> NSImage {
        if !isDir && url.pathExtension.lowercased() == "exe" {
            return PEIconExtractor.extractMetadata(from: url).icon
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func formattedSize(for url: URL) -> String {
        guard let bytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
