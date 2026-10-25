import SwiftUI

/// File mailbox between AdFree and the MCP server that Claude Code runs (AdFree/mcp/server.js).
///
/// The server drops `requests/<id>.json`; this class answers with `responses/<id>.json`.
/// A file mailbox needs no network listener, so the app keeps its sandbox: the only extra
/// access is read/write to the one folder `~/.adfree` (see AdFree.entitlements).
@MainActor
final class BridgeService: ObservableObject {
    @Published var lastTool = ""
    @Published var lastRequest: Date?

    private let browser: BrowserModel
    private var timer: Timer?
    private var inFlight = Set<String>()
    private var ticks = 0

    /// The real home folder: inside the sandbox NSHomeDirectory() points at the app container.
    nonisolated static var realHome: URL {
        URL(fileURLWithPath: getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory())
    }
    nonisolated static var folder: URL { realHome.appendingPathComponent(".adfree/bridge", isDirectory: true) }
    private var requests: URL { Self.folder.appendingPathComponent("requests", isDirectory: true) }
    private var responses: URL { Self.folder.appendingPathComponent("responses", isDirectory: true) }

    /// Path of the bundled MCP server, for the "connect Claude Code" command.
    nonisolated static var serverPath: String {
        Bundle.main.resourceURL?.appendingPathComponent("mcp/server.js").path ?? "mcp/server.js"
    }

    init(browser: BrowserModel) { self.browser = browser }

    func start() {
        let fm = FileManager.default
        for dir in [requests, responses] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            // Anything left over from an earlier run is stale.
            for file in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] { try? fm.removeItem(at: file) }
        }
        writeStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Heartbeat: lets the server tell "AdFree is not running" from "AdFree is busy".
    private func writeStatus() {
        let status: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier,
                                     "updated": Date().timeIntervalSince1970,
                                     "app": Bundle.main.bundlePath]
        guard let data = try? JSONSerialization.data(withJSONObject: status) else { return }
        try? data.write(to: Self.folder.appendingPathComponent("status.json"), options: .atomic)
    }

    private func tick() {
        ticks += 1
        if ticks % 5 == 0 { writeStatus() }
        let files = (try? FileManager.default.contentsOfDirectory(at: requests, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where file.pathExtension == "json" {
            let id = file.deletingPathExtension().lastPathComponent
            guard id.range(of: "^[A-Za-z0-9_-]{1,64}$", options: .regularExpression) != nil, !inFlight.contains(id) else { continue }
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            if Date().timeIntervalSince(modified) > 120 { try? FileManager.default.removeItem(at: file); continue }
            inFlight.insert(id)
            Task { await handle(id: id, file: file) }
        }
    }

    // MARK: Requests

    private func handle(id: String, file: URL) async {
        defer { inFlight.remove(id); try? FileManager.default.removeItem(at: file) }
        guard let data = try? Data(contentsOf: file),
              let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tool = request["tool"] as? String else {
            return respond(id, ok: false, text: "Malformed request.")
        }
        lastTool = tool
        lastRequest = Date()
        let (ok, text) = await run(tool, request["args"] as? [String: Any] ?? [:])
        respond(id, ok: ok, text: text)
    }

    private func respond(_ id: String, ok: Bool, text: String) {
        let body: [String: Any] = ok ? ["ok": true, "result": text] : ["ok": false, "error": text]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        let tmp = responses.appendingPathComponent("\(id).tmp")
        let final = responses.appendingPathComponent("\(id).json")
        do { try data.write(to: tmp); _ = try FileManager.default.replaceItemAt(final, withItemAt: tmp) }
        catch { try? data.write(to: final) }
    }

    /// Every tool re-checks its input here, even though the server already did.
    private func run(_ tool: String, _ args: [String: Any]) async -> (Bool, String) {
        func file() -> String? {
            guard let name = args["file"] as? String, BrowserModel.editableFiles.contains(name) else { return nil }
            return name
        }
        switch tool {
        case "get_report":
            return (true, await browser.report())

        case "get_page_snapshot":
            return (true, await browser.pageSnapshot())

        case "list_sites":
            let sites = browser.allowedDomains.map { domain -> String in
                guard let set = browser.siteRules[domain] else { return "\(domain): no site rules" }
                return "\(domain): \(set.hide.count) hidden selectors, \(set.block.count) blocked patterns"
            }
            let layers = "layers: rules=\(browser.rulesEnabled) youtube-script=\(browser.youtubeScriptEnabled) " +
                "yt-dlp-player=\(browser.nativePlayerEnabled) twitch-script=\(browser.twitchScriptEnabled) blocking=\(browser.blockingEnabled)"
            return (true, (sites + [layers]).joined(separator: "\n"))

        case "read_file":
            guard let name = file() else { return (false, "Unknown file.") }
            return (true, browser.currentSource(name))

        case "open_site":
            guard let raw = args["domain"] as? String, let domain = BrowserModel.normalizeDomain(raw) else { return (false, "Not a valid domain.") }
            let result = await browser.openAndWait(domain)
            return (browser.allowedDomains.contains(domain), result)

        case "set_site_rules":
            guard let raw = args["domain"] as? String, let domain = BrowserModel.normalizeDomain(raw) else { return (false, "Not a valid domain.") }
            let hide = args["hide_selectors"] as? [String] ?? []
            let block = args["block_url_patterns"] as? [String] ?? []
            if let problem = await browser.setSiteRules(domain: domain, hide: hide, block: block) { return (false, problem) }
            browser.notify("Claude Code updated the block rules for \(domain). Undo: Settings → Allowed sites → Clear rules.")
            return (true, "Saved \(hide.count) hidden selectors and \(block.count) blocked patterns for \(domain). The page was reloaded.")

        case "clear_site_rules":
            guard let raw = args["domain"] as? String, let domain = BrowserModel.normalizeDomain(raw) else { return (false, "Not a valid domain.") }
            if let problem = await browser.setSiteRules(domain: domain, hide: [], block: []) { return (false, problem) }
            browser.notify("Claude Code cleared the block rules for \(domain).")
            return (true, "Cleared the rules for \(domain).")

        case "write_file":
            guard let name = file(), let content = args["content"] as? String, !content.isEmpty, content.count <= 200_000 else {
                return (false, "Needs a known 'file' and non-empty 'content' of at most 200,000 characters.")
            }
            if let problem = browser.validate(name, content) { return (false, problem) }
            if name == "ContentRules.json", let problem = await browser.checkRulesFile(content) { return (false, problem) }
            let problem: String? = await withCheckedContinuation { continuation in
                browser.saveCustom(name, content) { continuation.resume(returning: $0) }
            }
            if let problem { return (false, problem) }
            browser.notify("Claude Code edited \(name). Undo: Settings → Scripts & rules → Revert.")
            return (true, "Saved \(name) as a custom copy and reloaded the page.")

        case "revert_file":
            guard let name = file() else { return (false, "Unknown file.") }
            await withCheckedContinuation { continuation in browser.revertCustom(name) { continuation.resume() } }
            browser.notify("Claude Code reverted \(name) to the built-in version.")
            return (true, "Reverted \(name) to the built-in version.")

        case "set_layer":
            guard let layer = args["layer"] as? String, let on = args["enabled"] as? Bool else { return (false, "Needs 'layer' and 'enabled'.") }
            switch layer {
            case "rules": browser.rulesEnabled = on
            case "youtube_script": browser.youtubeScriptEnabled = on
            case "twitch_script": browser.twitchScriptEnabled = on
            case "yt_dlp_player": browser.nativePlayerEnabled = on
            default: return (false, "Unknown layer. Use rules, youtube_script, twitch_script or yt_dlp_player.")
            }
            return (true, "Set \(layer) to \(on). The page was reloaded.")

        default:
            return (false, "Unknown tool \(tool).")
        }
    }
}
