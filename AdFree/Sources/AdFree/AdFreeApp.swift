import SwiftUI

/// Quit when the window closes, so the app never lingers in the Dock with no window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct AdFreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var browser: BrowserModel
    @StateObject private var bridge: BridgeService

    init() {
        let browser = BrowserModel()
        let bridge = BridgeService(browser: browser)
        _browser = StateObject(wrappedValue: browser)
        _bridge = StateObject(wrappedValue: bridge)
        bridge.start() // opens the mailbox that Claude Code's MCP server talks to
    }

    var body: some Scene {
        WindowGroup("AdFree") {
            ContentView()
                .environmentObject(browser)
                .frame(minWidth: 900, minHeight: 600)
        }
        Settings {
            SettingsView().environmentObject(browser).environmentObject(bridge)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Reload") { browser.webView.reload() }.keyboardShortcut("r")
                Button("Toggle Ad Blocking") { browser.blockingEnabled.toggle() }.keyboardShortcut("b")
            }
        }
    }
}
