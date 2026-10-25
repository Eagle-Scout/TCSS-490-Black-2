import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            AllowedSitesTab().tabItem { Label("Allowed sites", systemImage: "checkmark.shield") }
            ScriptsTab().tabItem { Label("Scripts & rules", systemImage: "doc.text") }
            BlockingTab().tabItem { Label("Blocking", systemImage: "shield") }
            ClaudeCodeTab().tabItem { Label("Claude Code", systemImage: "terminal") }
        }
        .frame(width: 640, height: 520)
    }
}

// MARK: Allowed sites

private struct AllowedSitesTab: View {
    @EnvironmentObject var browser: BrowserModel
    @State private var newDomain = ""
    @State private var error: String?
    @State private var pending: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AdFree only opens these sites (and their subdomains). Any other link is sent to YouTube.")
                .foregroundStyle(.secondary)
            List {
                ForEach(browser.allowedDomains, id: \.self) { domain in
                    HStack {
                        Text(domain)
                        if let rules = browser.siteRules[domain] {
                            Text("\(rules.hide.count + rules.block.count) rules").font(.caption).foregroundStyle(.secondary)
                            Button("Clear rules") { browser.siteRules[domain] = nil; browser.reloadBlocking() }
                                .buttonStyle(.link).font(.caption)
                        }
                        Spacer()
                        if domain == BrowserModel.lockedDomain {
                            Text("always allowed").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Button(role: .destructive) { browser.removeDomain(domain) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            }
            HStack {
                TextField("Add a site, e.g. kick.com", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(attemptAdd)
                Button("Add…", action: attemptAdd).disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let error { Text(error).font(.callout).foregroundStyle(.red) }
            Text("Google sign-in pages are allowed automatically so you can stay signed in.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .confirmationDialog("Allow \(pending ?? "")?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible) {
            Button("Allow \(pending ?? "")") {
                if let domain = pending { error = browser.addDomain(domain); if error == nil { newDomain = "" } }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            Text("Anything on this site, including scams or fake sign-in pages, will be able to load in AdFree. Only add sites you trust.")
        }
    }

    private func attemptAdd() {
        error = nil
        guard let domain = BrowserModel.normalizeDomain(newDomain) else {
            error = "That doesn't look like a website address."
            return
        }
        pending = domain
    }
}

// MARK: Scripts and rules

private struct ScriptsTab: View {
    @EnvironmentObject var browser: BrowserModel
    @State private var file = BrowserModel.editableFiles[1]
    @State private var text = ""
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("File", selection: $file) {
                    ForEach(BrowserModel.editableFiles, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 200)
                Text(browser.hasCustom(file) ? "Custom copy in use" : "Built-in version")
                    .font(.callout)
                    .foregroundStyle(browser.hasCustom(file) ? .orange : .secondary)
                Spacer()
                Button("Show in Finder") { browser.revealInFinder(file) }
            }
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .border(.quaternary)
            HStack {
                Button("Save and apply") {
                    browser.saveCustom(file, text) { problem in
                        isError = problem != nil
                        message = problem ?? "Saved. Blocking files reloaded."
                    }
                }
                .keyboardShortcut("s")
                Button("Revert to built-in") {
                    browser.revertCustom(file) {
                        text = browser.currentSource(file)
                        isError = false
                        message = "Reverted to the built-in version."
                    }
                }
                .disabled(!browser.hasCustom(file))
                if let message { Text(message).font(.callout).foregroundStyle(isError ? .red : .green).lineLimit(2) }
            }
            Text("A saved copy replaces the built-in file, so later app updates to that file won't apply until you revert it. Edits are checked for syntax errors before saving.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .onAppear { text = browser.currentSource(file) }
        .onChange(of: file) { _ in text = browser.currentSource(file); message = nil }
    }
}

// MARK: Blocking layers

private struct BlockingTab: View {
    @EnvironmentObject var browser: BrowserModel

    var body: some View {
        Form {
            Toggle("Block ads (master switch)", isOn: $browser.blockingEnabled)
            Section("Layers") {
                Toggle("Network rules and hidden ad slots", isOn: $browser.rulesEnabled)
                Toggle("YouTube script", isOn: $browser.youtubeScriptEnabled)
                Toggle("YouTube video player (uses yt-dlp)", isOn: $browser.nativePlayerEnabled)
                Toggle("Twitch script", isOn: $browser.twitchScriptEnabled)
            }
            Text("Turn layers off one at a time to find which one is breaking a page. Each change reloads the page.")
                .font(.caption).foregroundStyle(.secondary)
            Section("Stats") {
                LabeledContent("Ads skipped or blocked", value: "\(browser.adsBlocked)")
                Button("Reset counter") { browser.adsBlocked = 0 }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Claude Code connection

private struct ClaudeCodeTab: View {
    @EnvironmentObject var bridge: BridgeService
    @State private var state: ConnectionState = .notConnected
    @State private var message: String?
    @State private var copied: String?

    var body: some View {
        Form {
            Section("Connection") {
                statusLine
                Button("Refresh status") { refresh() }.buttonStyle(.link)
                Text("This checks the user-wide Claude Code setting. A .mcp.json inside a project is separate.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(ClaudeConnection.options(for: state)) { option in
                Section(option.title) {
                    Text(option.command)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    HStack {
                        if option.primary {
                            Button("Open Terminal here") { openTerminal(option.command) }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Button("Open Terminal here") { openTerminal(option.command) }
                        }
                        Button(copied == option.id ? "Copied" : "Copy command") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(option.command, forType: .string)
                            copied = option.id
                        }
                    }
                    Text(option.note + " Terminal opens in the project folder (the nearest one above AdFree.app with a .mcp.json), or next to AdFree.app if none is found. macOS may ask once for permission to control Terminal.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let message {
                Section { Text(message).font(.callout).foregroundStyle(.secondary) }
            }
            Section("Activity") {
                if let last = bridge.lastRequest {
                    LabeledContent("Last request", value: "\(bridge.lastTool), \(last.formatted(date: .omitted, time: .standard))")
                } else {
                    Text("No requests yet this session.").foregroundStyle(.secondary)
                }
                Text("Messages pass through the folder ~/.adfree/bridge. Claude Code asks your permission before each tool call, and every change is undoable (Scripts & rules → Revert, Allowed sites → Clear rules).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { refresh() }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch state {
        case .connected:
            Label("Connected to this copy of AdFree.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .notConnected:
            Label("Not connected yet.", systemImage: "circle.dashed").foregroundStyle(.secondary)
        case .stale(let points):
            Label("Connected to a different copy of AdFree (\(points)). Reset it to point here.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .unreadable:
            Label("Claude Code's settings file couldn't be read. Reset the connection to fix it.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func refresh() {
        state = ClaudeConnection.status()
        copied = nil
    }

    private func openTerminal(_ command: String) {
        if let problem = ClaudeConnection.openTerminal(running: command) {
            message = problem
        } else {
            message = "Terminal opened with the command. When it finishes, press Refresh status."
        }
    }
}
