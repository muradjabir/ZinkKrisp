import AppKit
import SwiftUI
import ZinkKrispCore

final class ZinkKrispAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        var rlp = rlimit()
        if getrlimit(RLIMIT_NOFILE, &rlp) == 0 {
            rlp.rlim_cur = min(rlim_t(65536), rlp.rlim_max)
            setrlimit(RLIMIT_NOFILE, &rlp)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in
            for url in urls {
                await EngineManager.shared.handleOpenedFile(url)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct ZinkKrispApp: App {
    @NSApplicationDelegateAdaptor(ZinkKrispAppDelegate.self) private var appDelegate
    @StateObject private var engine = EngineManager.shared
    @StateObject private var updateChecker = UpdateChecker.shared
    @State private var showLicenses = false

    var body: some Scene {
        Window("ZinkKrisp", id: "main") {
            MainLibraryView()
                .environmentObject(engine)
                .frame(minWidth: 900, minHeight: 580)
                .task {
                    async let boot: Void = engine.bootstrap()
                    async let updateCheck: Void = updateChecker.checkForUpdates(manual: false)
                    _ = await (boot, updateCheck)
                }
                .sheet(isPresented: $showLicenses) {
                    LicensesSheet(licensesText: engine.thirdPartyLicensesText())
                }
                .sheet(item: $updateChecker.availableUpdate) { update in
                    UpdatePromptSheet(checker: updateChecker, update: update)
                }
                .alert(
                    "ZinkKrisp Updates",
                    isPresented: Binding(
                        get: { updateChecker.statusAlertMessage != nil },
                        set: { if !$0 { updateChecker.statusAlertMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) {
                        updateChecker.statusAlertMessage = nil
                    }
                } message: {
                    Text(updateChecker.statusAlertMessage ?? "")
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ZinkKrisp & Licenses...") {
                    showLicenses = true
                }
                Button("Check for Updates...") {
                    Task {
                        await updateChecker.checkForUpdates(manual: true)
                    }
                }
            }
            CommandGroup(replacing: .help) {
                Button("Read Architecture & Technical Blog (muradjabir.com)") {
                    if let url = URL(string: "https://muradjabir.com/blog/post-rosetta-opengl-apple-silicon") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
