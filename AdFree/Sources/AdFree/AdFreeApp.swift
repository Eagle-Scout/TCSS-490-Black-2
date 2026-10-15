import SwiftUI

/// Quit when the window closes, so the app never lingers in the Dock with no window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct AdFreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var browser = BrowserModel()

    var body: some Scene {
        WindowGroup("AdFree") {
            ContentView()
                .environmentObject(browser)
                .frame(minWidth: 900, minHeight: 600)
        }
        Settings {
            SettingsView().environmentObject(browser)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Reload") { browser.webView.reload() }.keyboardShortcut("r")
                Button("Toggle Ad Blocking") { browser.blockingEnabled.toggle() }.keyboardShortcut("b")
            }
        }
    }
}
