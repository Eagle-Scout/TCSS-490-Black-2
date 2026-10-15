import SwiftUI

/// Home page: one card per allowed site. Add or remove sites in Settings → Allowed sites.
struct HomeView: View {
    @EnvironmentObject var browser: BrowserModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your sites").font(.largeTitle.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 14) {
                    ForEach(browser.homeSites, id: \.self) { domain in
                        Button { browser.open(domain: domain) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: icon(for: domain)).font(.title2)
                                Text(BrowserModel.displayName(for: domain)).font(.headline).lineLimit(2)
                                Text(domain).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                            .padding(12)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(spacing: 4) {
                    Text("This list is your allowed sites.")
                    SettingsLink { Text("Add or remove sites in Settings") }.buttonStyle(.link)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func icon(for domain: String) -> String {
        if domain.contains("twitch") { return "play.tv" }
        if domain.contains("youtu") { return "play.rectangle" }
        return "globe"
    }
}
