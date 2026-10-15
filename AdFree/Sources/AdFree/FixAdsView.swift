import SwiftUI
import AppKit

/// Step-by-step help for when an ad gets through.
struct FixAdsView: View {
    @EnvironmentObject var browser: BrowserModel
    @Environment(\.dismiss) private var dismiss
    @State private var report = ""
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Ad got through?").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("YouTube and Twitch change their code often, so blocking breaks now and then. Try these in order. Stop when the ad is gone.")
                        .foregroundStyle(.secondary)

                    step(1, "Reload the page", "Fixes most one-off misses.") {
                        Button("Reload page") { browser.webView.reload(); status = "Reloaded." }
                    }
                    step(2, "Make sure blocking is on and reload the blocking files",
                         "Re-reads the rules and scripts from disk and reloads the page.") {
                        Toggle("Block ads", isOn: $browser.blockingEnabled)
                        Button("Reload blocking files") {
                            browser.reloadBlocking { status = "Blocking files reloaded." }
                        }
                    }
                    step(3, "Clear the page cache", "Removes cached scripts and pages. You stay signed in.") {
                        Button("Clear cache") { browser.clearCache { status = "Cache cleared." } }
                    }
                    step(4, "Collect a report",
                         "Shows what the app sees on the current page. Copy it and paste it to Claude with a note like “ads are getting through on YouTube, please update the scripts.”") {
                        HStack {
                            Button("Run diagnosis") { browser.diagnose { report = $0 } }
                            Button("Copy report") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(report, forType: .string)
                                status = "Report copied."
                            }.disabled(report.isEmpty)
                        }
                        if !report.isEmpty {
                            Text(report)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    step(5, "Edit the scripts",
                         "The rules and scripts can be edited inside the app. Open Settings → Scripts & rules, make a change, and press Save and apply. You can also open the folder in Finder from there.") {
                        SettingsLink { Text("Open Settings") }
                    }

                    Text("Note: this version doesn't use yt-dlp or streamlink. Updating them won't help until the optional “Play natively” fallback is added.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !status.isEmpty { Text(status).font(.callout).foregroundStyle(.green) }
                }
                .padding()
            }
        }
        .frame(width: 560, height: 620)
    }

    private func step<Content: View>(_ n: Int, _ title: String, _ detail: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(n). \(title)").font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary)
            content()
        }
    }
}
