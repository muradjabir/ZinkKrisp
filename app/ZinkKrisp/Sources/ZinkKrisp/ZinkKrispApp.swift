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
    @State private var showLicenses = false

    var body: some Scene {
        Window("ZinkKrisp", id: "main") {
            MainLibraryView()
                .environmentObject(engine)
                .frame(minWidth: 900, minHeight: 580)
                .task {
                    await engine.bootstrap()
                }
                .sheet(isPresented: $showLicenses) {
                    LicensesSheet(licensesText: engine.thirdPartyLicensesText())
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ZinkKrisp & Licenses...") {
                    showLicenses = true
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
