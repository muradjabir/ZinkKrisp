import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ZinkKrispCore

struct MainLibraryView: View {
    @EnvironmentObject private var engine: EngineManager
    @State private var isDropTargeted = false
    @State private var selectedSettingsAppID: UUID?
    @State private var showNewAppSheet = false
    @State private var droppedInstallerURL: URL?
    @State private var selectedContainerID: String?
    @State private var selectedAppID: UUID?
    @State private var expandedContainerIDs: Set<String> = []
    @State private var knownContainerIDs: Set<String> = []

    private var allContainerIDs: [String] {
        Array(Set(engine.containerIDs).union(engine.libraryApps.map(\.containerID)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = engine.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.callout)
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") { engine.errorMessage = nil }
                        .buttonStyle(.borderless)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.12))
            }

            if allContainerIDs.isEmpty {
                emptyStateView
                    .overlay {
                        if isDropTargeted {
                            dropOverlay(text: "Drop .exe, .msi, .zip, .bat, or .reg to Run")
                        }
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                        handleDrop(providers: providers, targetContainerID: nil)
                    }
            } else {
                NavigationSplitView {
                    ContainerSidebarView(
                        containerIDs: allContainerIDs,
                        selectedContainerID: $selectedContainerID,
                        selectedAppID: $selectedAppID,
                        expandedContainerIDs: $expandedContainerIDs
                    )
                    .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
                } detail: {
                    if let activeCID = selectedContainerID ?? allContainerIDs.first {
                        ContainerDetailView(
                            containerID: activeCID,
                            selectedAppID: $selectedAppID,
                            selectedSettingsAppID: $selectedSettingsAppID,
                            onDropFile: { providers in
                                handleDrop(providers: providers, targetContainerID: activeCID)
                            }
                        )
                    } else {
                        emptyStateView
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(engine.isReady ? Color.green : (engine.isBusy ? Color.orange : Color.red))
                        .frame(width: 8, height: 8)
                    Text(engine.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.6), in: Capsule())
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    droppedInstallerURL = nil
                    showNewAppSheet = true
                } label: {
                    Label("New App", systemImage: "plus.app")
                }
                .disabled(engine.isBusy || engine.needsWineRuntimeSetup)

                Button {
                    NSWorkspace.shared.open(engine.containersURL)
                } label: {
                    Label("Open Containers Folder", systemImage: "folder")
                }
                .disabled(!FileManager.default.fileExists(atPath: engine.containersURL.path))
            }
        }
        .sheet(isPresented: $showNewAppSheet) {
            NewAppSheet(engine: engine, initialInstallerURL: droppedInstallerURL)
        }
        .onAppear {
            syncHierarchySelection(with: allContainerIDs)
            if let url = engine.pendingNewAppInstallerURL {
                droppedInstallerURL = url
                showNewAppSheet = true
                engine.pendingNewAppInstallerURL = nil
            }
        }
        .onChange(of: allContainerIDs) { _, updated in
            syncHierarchySelection(with: updated)
        }
        .onChange(of: engine.pendingNewAppInstallerURL) { _, newURL in
            if let url = newURL {
                droppedInstallerURL = url
                showNewAppSheet = true
                engine.pendingNewAppInstallerURL = nil
            }
        }
        .sheet(isPresented: Binding(
            get: { engine.installerRunningName != nil && engine.activeLaunchSession == nil },
            set: { _ in }
        )) {
            InstallerProgressSheet(installerName: engine.installerRunningName ?? "Installer")
        }
        .sheet(isPresented: $engine.showExeSelectionSheet) {
            ExeSelectionSheet(
                candidates: $engine.discoveredExes,
                onConfirm: { createMacApps in
                    engine.addSelectedExes(engine.discoveredExes, createMacApps: createMacApps)
                    engine.showExeSelectionSheet = false
                },
                onCancel: {
                    engine.showExeSelectionSheet = false
                }
            )
        }
        .sheet(isPresented: $engine.needsWineRuntimeSetup) {
            WineRuntimeSetupSheet()
                .environmentObject(engine)
        }
        .sheet(isPresented: Binding(
            get: { engine.browsingContainerID != nil },
            set: { if !$0 { engine.browsingContainerID = nil } }
        )) {
            if let cid = engine.browsingContainerID {
                ContainerFileBrowserSheet(engine: engine, containerID: cid)
            }
        }
        .sheet(isPresented: Binding(
            get: { engine.pendingRequirementsApp != nil },
            set: { if !$0 && !engine.isInstallingPrereqs { engine.pendingRequirementsApp = nil } }
        )) {
            if let reqApp = engine.pendingRequirementsApp {
                RequirementsCheckSheet(engine: engine, app: reqApp)
            }
        }
        .sheet(isPresented: Binding(
            get: { engine.activeLaunchSession != nil },
            set: { if !$0 { engine.activeLaunchSession = nil } }
        )) {
            if let session = engine.activeLaunchSession {
                LaunchStatusSheet(engine: engine, session: session)
            }
        }
        .sheet(isPresented: Binding(
            get: { engine.managingStartupContainerID != nil },
            set: { if !$0 { engine.managingStartupContainerID = nil } }
        )) {
            if let cid = engine.managingStartupContainerID {
                StartupProcessesSheet(engine: engine, containerID: cid)
            }
        }
        .sheet(isPresented: Binding(
            get: { engine.managingSnapshotsContainerID != nil },
            set: { if !$0 && !engine.isSnapshotBusy { engine.managingSnapshotsContainerID = nil } }
        )) {
            if let cid = engine.managingSnapshotsContainerID {
                SnapshotsSheet(engine: engine, containerID: cid)
            }
        }
        .alert(item: $engine.pendingForcePrompt) { prompt in
            let procList = prompt.runningProcesses.isEmpty
                ? "Background Wine processes are still active."
                : prompt.runningProcesses.prefix(5).joined(separator: "\n")
            return Alert(
                title: Text(prompt.action == .delete ? "Cannot Delete Running Container" : "Container Still Running"),
                message: Text("Container '\(prompt.label)' still has active processes:\n\n\(procList)\n\nForce closing will terminate all processes in this container."),
                primaryButton: .destructive(Text(prompt.action == .delete ? "Force Close & Delete" : "Force Close Processes")) {
                    Task {
                        if prompt.action == .delete {
                            await engine.deleteContainer(containerID: prompt.containerID, label: prompt.label, force: true)
                        } else {
                            await engine.stopContainer(containerID: prompt.containerID, force: true)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func syncHierarchySelection(with containers: [String]) {
        let newlySeen = Set(containers).subtracting(knownContainerIDs)
        if !newlySeen.isEmpty {
            expandedContainerIDs.formUnion(newlySeen)
            knownContainerIDs.formUnion(newlySeen)
        }
        if selectedContainerID == nil || !containers.contains(selectedContainerID!) {
            selectedContainerID = containers.first
            selectedAppID = nil
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "cube.transparent")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Containers or Applications Yet")
                .font(.title2.weight(.semibold))
            Text("Drag & drop any Windows .exe, .msi, .bat, or .reg file here, or click \"+ New App\" above.\nEach container isolates its own Windows environment and hosts one or more applications.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
            HStack(spacing: 12) {
                Button("+ New App") {
                    droppedInstallerURL = nil
                    showNewAppSheet = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(engine.isBusy || engine.needsWineRuntimeSetup)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func handleDrop(providers: [NSItemProvider], targetContainerID: String?) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            Task { @MainActor in
                handleSelectedFile(url, targetContainerID: targetContainerID)
            }
        }
        return true
    }

    private func handleSelectedFile(_ url: URL, targetContainerID: String?) {
        let ext = url.pathExtension.lowercased()
        guard ["exe", "msi", "bat", "cmd", "reg", "zip"].contains(ext) else { return }
        if let cid = targetContainerID {
            Task {
                await engine.runFileInContainer(containerID: cid, containerName: cid, url: url)
            }
        } else {
            droppedInstallerURL = url
            showNewAppSheet = true
        }
    }
}

@ViewBuilder
private func dropOverlay(text: String) -> some View {
    RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
        .background(Color.accentColor.opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 12)))
        .padding(12)
        .overlay {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                Text(text)
                    .font(.headline)
            }
        }
}

private struct ContainerSidebarView: View {
    @EnvironmentObject private var engine: EngineManager
    let containerIDs: [String]
    @Binding var selectedContainerID: String?
    @Binding var selectedAppID: UUID?
    @Binding var expandedContainerIDs: Set<String>

    var body: some View {
        List {
            Section("Containers") {
                ForEach(containerIDs, id: \.self) { cid in
                    let appsInContainer = engine.libraryApps.filter { $0.containerID == cid }
                    let isExpanded = Binding<Bool>(
                        get: { expandedContainerIDs.contains(cid) },
                        set: { expanded in
                            if expanded {
                                expandedContainerIDs.insert(cid)
                            } else {
                                expandedContainerIDs.remove(cid)
                            }
                        }
                    )
                    let isRunning = engine.runningContainerIDs.contains(cid)
                    let isContainerSelected = (selectedContainerID == cid && selectedAppID == nil)

                    DisclosureGroup(isExpanded: isExpanded) {
                        if appsInContainer.isEmpty {
                            Text("No applications added")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 3)
                        } else {
                            ForEach(appsInContainer) { app in
                                let isAppSelected = (selectedContainerID == cid && selectedAppID == app.id)
                                HStack(spacing: 8) {
                                    Image(nsImage: engine.iconForApp(app))
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 18, height: 18)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                    Text(app.name)
                                        .font(.callout)
                                        .lineLimit(1)

                                    Spacer()

                                    Button {
                                        engine.launchApp(app)
                                    } label: {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Launch \(app.name)")
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isAppSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedContainerID = cid
                                    selectedAppID = app.id
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox.fill")
                                .foregroundStyle(isRunning ? .blue : .secondary)
                            Text(cid)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Circle()
                                .fill(isRunning ? Color.green : Color.secondary.opacity(0.45))
                                .frame(width: 6, height: 6)
                            if !engine.isInternetEnabled(for: cid) {
                                Image(systemName: "network.slash")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .help("Offline Sandbox Enabled")
                            }
                            Spacer()
                            Text("\(appsInContainer.count)")
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isContainerSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedContainerID = cid
                            selectedAppID = nil
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct ContainerDetailView: View {
    @EnvironmentObject private var engine: EngineManager
    let containerID: String
    @Binding var selectedAppID: UUID?
    @Binding var selectedSettingsAppID: UUID?
    let onDropFile: ([NSItemProvider]) -> Bool

    @State private var isDropTargeted = false

    private let gridColumns = [
        GridItem(.adaptive(minimum: 230, maximum: 300), spacing: 16)
    ]

    private var appsInContainer: [InstalledApp] {
        engine.libraryApps.filter { $0.containerID == containerID }
    }

    var body: some View {
        let isRunning = engine.runningContainerIDs.contains(containerID)
        let isInternetOn = engine.isInternetEnabled(for: containerID)
        let startupCount = engine.startupProcesses(for: containerID).count
        let snapshotCount = engine.snapshots(for: containerID).count

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(isRunning ? .blue : .secondary)
                            .frame(width: 44, height: 44)
                            .background((isRunning ? Color.blue : Color.secondary).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("CONTAINER")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Text(containerID)
                                    .font(.title2.weight(.semibold))
                                    .lineLimit(1)

                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(isRunning ? Color.green : Color.secondary.opacity(0.45))
                                        .frame(width: 7, height: 7)
                                    Text(isRunning ? "Running" : "Stopped")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(isRunning ? .green : .secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((isRunning ? Color.green : Color.secondary).opacity(0.12), in: Capsule())

                                Button {
                                    Task { await engine.setInternetEnabled(!isInternetOn, for: containerID) }
                                } label: {
                                    Label(isInternetOn ? "Internet On" : "Offline Sandbox",
                                          systemImage: isInternetOn ? "network" : "network.slash")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(isInternetOn ? Color.blue : Color.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((isInternetOn ? Color.blue : Color.orange).opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .help(isInternetOn ? "Click to Enable Offline Sandbox" : "Click to Allow Internet Connectivity")
                            }
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Label("\(startupCount) Startup", systemImage: "gearshape.2")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary.opacity(0.6), in: Capsule())

                            Label("\(snapshotCount) Snapshots", systemImage: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary.opacity(0.6), in: Capsule())
                        }
                    }

                    Divider()

                    HStack(spacing: 8) {
                        Menu("Run...") {
                            Button("Internal (Container C: Drive)...") {
                                engine.browsingContainerID = containerID
                            }
                            Button("External (Any File on Mac)...") {
                                pickAndRunContainerFile(
                                    engine: engine,
                                    containerID: containerID,
                                    containerName: containerID
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                        Button {
                            engine.scanContainer(containerID: containerID, containerName: containerID)
                        } label: {
                            Label("Scan .EXEs", systemImage: "magnifyingglass")
                        }
                        .controlSize(.regular)

                        Button {
                            engine.managingStartupContainerID = containerID
                        } label: {
                            Label("Startup Processes", systemImage: "gearshape.2")
                        }
                        .controlSize(.regular)

                        Button {
                            engine.managingSnapshotsContainerID = containerID
                        } label: {
                            Label("Restore Points", systemImage: "clock.arrow.circlepath")
                        }
                        .controlSize(.regular)

                        Button {
                            NSWorkspace.shared.open(engine.driveCURL(for: containerID))
                        } label: {
                            Label("Open C: Drive", systemImage: "folder")
                        }
                        .controlSize(.regular)

                        Spacer()

                        if isRunning {
                            Button(role: .destructive) {
                                Task { await engine.stopContainer(containerID: containerID) }
                            } label: {
                                Label("Stop", systemImage: "stop.circle.fill")
                            }
                            .controlSize(.regular)
                        }

                        Button(role: .destructive) {
                            Task { await engine.deleteContainer(containerID: containerID) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .controlSize(.regular)
                        .help("Delete Container '\(containerID)'")
                    }
                }
                .padding(16)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text(containerID)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("Applications (\(appsInContainer.count))")
                            .font(.headline)
                    }

                    if appsInContainer.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No Applications Registered in '\(containerID)'")
                                .font(.headline)
                            Text("Drop a Windows installer or executable onto this view, run a file from the C: drive, or scan for existing .EXEs.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 420)
                            HStack(spacing: 10) {
                                Button("Run Installer / File...") {
                                    pickAndRunContainerFile(
                                        engine: engine,
                                        containerID: containerID,
                                        containerName: containerID
                                    )
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Scan C: Drive for .EXEs") {
                                    engine.scanContainer(containerID: containerID, containerName: containerID)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
                        )
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(appsInContainer) { app in
                                AppCardView(
                                    app: app,
                                    icon: engine.iconForApp(app),
                                    isSelected: selectedAppID == app.id,
                                    isShowingSettings: Binding(
                                        get: { selectedSettingsAppID == app.id },
                                        set: { selectedSettingsAppID = $0 ? app.id : nil }
                                    ),
                                    onSelect: { selectedAppID = app.id },
                                    onLaunch: { engine.launchApp(app) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .overlay {
            if isDropTargeted {
                dropOverlay(text: "Drop to Run in Container '\(containerID)'")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            onDropFile(providers)
        }
    }
}

private struct AppCardView: View {
    @EnvironmentObject private var engine: EngineManager
    let app: InstalledApp
    let icon: NSImage
    let isSelected: Bool
    @Binding var isShowingSettings: Bool
    let onSelect: () -> Void
    let onLaunch: () -> Void

    var body: some View {
        let profile = SoftwareProfileManager.shared.profile(for: app)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.headline)
                            .lineLimit(1)
                        if app.architecture != .unknown {
                            Text(app.architecture.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(app.architecture == .x64 ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                                .foregroundStyle(app.architecture == .x64 ? Color.blue : Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text(URL(fileURLWithPath: app.exeRelativePath).lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let profile {
                        Text(profile.displayName)
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Button("Launch") {
                    onSelect()
                    onLaunch()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button {
                    onSelect()
                    engine.openRequirementsCheck(for: app)
                } label: {
                    Image(systemName: "checkmark.shield")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Check Requirements & Download Runtimes")

                Spacer()

                Button {
                    onSelect()
                    isShowingSettings.toggle()
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $isShowingSettings, arrowEdge: .bottom) {
                    AppSettingsPopover(app: app)
                }
            }
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.85) : Color.primary.opacity(0.1),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

private struct WineRuntimeSetupSheet: View {
    @EnvironmentObject private var engine: EngineManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Download Native ARM64 Wine Runtime")
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            Text("ZinkKrisp requires MetalSharp-Wine (external AGPL/LGPL/MIT runtime) to execute Windows x86_64 binaries natively on Apple Silicon. It is not bundled inside ZinkKrisp.app.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            if engine.isDownloadingWine {
                VStack(alignment: .leading, spacing: 6) {
                    if let progress = engine.wineDownloadProgress {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                    HStack {
                        Text(engine.wineDownloadStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if !engine.wineDownloadMBText.isEmpty {
                            Text(engine.wineDownloadMBText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let error = engine.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Locate MetalSharp-Wine.app...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowedContentTypes = [.applicationBundle]
                    if panel.runModal() == .OK, let url = panel.url {
                        if engine.resolveWineBinary(in: url) != nil {
                            engine.saveWineAppURL(url)
                            engine.errorMessage = nil
                            engine.needsWineRuntimeSetup = false
                            Task { await engine.ensureEngineReady() }
                        } else {
                            engine.errorMessage = "Selected app bundle does not contain a Wine binary."
                        }
                    }
                }
                .disabled(engine.isDownloadingWine)

                Spacer()

                Button("Download & Install MetalSharp-Wine") {
                    Task {
                        await engine.downloadAndInstallMetalSharpWine()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(engine.isDownloadingWine)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

@MainActor
private func pickAndRunContainerFile(engine: EngineManager, containerID: String, containerName: String) {
    let panel = NSOpenPanel()
    panel.title = "Run Windows File in \(containerName)"
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    let types = ["exe", "msi", "bat", "cmd", "reg", "zip"].compactMap { UTType(filenameExtension: $0) }
    if !types.isEmpty { panel.allowedContentTypes = types }

    if panel.runModal() == .OK, let url = panel.url {
        Task {
            await engine.runFileInContainer(containerID: containerID, containerName: containerName, url: url)
        }
    }
}
