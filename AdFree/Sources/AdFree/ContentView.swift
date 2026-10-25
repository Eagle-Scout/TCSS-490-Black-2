import SwiftUI
import WebKit

struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var browser: BrowserModel
    @State private var showFix = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if let notice = browser.notice {
                Text(notice)
                    .font(.callout)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(.yellow.opacity(0.25))
            }
            Divider()
            // The web view stays in the window so pages keep loading behind the home page.
            ZStack {
                WebViewHost(webView: browser.webView)
                if browser.showHome { HomeView() }
            }
        }
        .sheet(isPresented: $showFix) { FixAdsView().environmentObject(browser) }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { browser.goHome() } label: { Image(systemName: "house") }
                .help("Home")
            Button { browser.showHome = false; browser.webView.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!browser.canGoBack)
            Button { browser.showHome = false; browser.webView.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!browser.canGoForward)
            Button {
                if browser.loading { browser.webView.stopLoading() } else { browser.webView.reload() }
            } label: {
                Image(systemName: browser.loading ? "xmark" : "arrow.clockwise")
            }

            // Read-only: shows which site you're really on (useful during sign-in).
            Label(browser.showHome ? "Home" : browser.pageHost, systemImage: "lock.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 6)

            Label("\(browser.adsBlocked)", systemImage: "hand.raised.slash")
                .help("Ads skipped or blocked so far")
                .font(.callout.monospacedDigit())
            Toggle(isOn: $browser.blockingEnabled) {
                Label("Block ads", systemImage: browser.blockingEnabled ? "shield.fill" : "shield.slash")
            }
            .toggleStyle(.button)
            Toggle(isOn: $browser.nativePlayerEnabled) {
                Label("yt-dlp", systemImage: "play.rectangle")
            }
            .toggleStyle(.button)
            .help("Play YouTube videos in a separate player (via yt-dlp) instead of YouTube's own. Use it as a backup if YouTube blocks the ad blocker.")
            Button { showFix = true } label: {
                Label("Ads showing?", systemImage: "wrench.and.screwdriver")
            }
            SettingsLink { Image(systemName: "gearshape") }
                .help("Settings")
        }
        .padding(8)
    }
}
