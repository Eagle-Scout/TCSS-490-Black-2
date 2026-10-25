import SwiftUI
import WebKit
import JavaScriptCore

final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    static let home = URL(string: "https://www.youtube.com")!
    /// youtube.com can't be removed: it is where blocked links are sent.
    static let lockedDomain = "youtube.com"
    static let defaultDomains = ["youtube.com", "youtu.be", "twitch.tv"]
    static let googleSignInHosts = ["accounts.google.com", "consent.google.com"]
    static let editableFiles = ["ContentRules.json", "youtube-adblock.js", "youtube-player.js", "twitch-adblock.js"]

    let webView: WKWebView
    private let controller = WKUserContentController()
    private var ruleList: WKContentRuleList?
    private var observers: [NSKeyValueObservation] = []
    private let defaults = UserDefaults.standard

    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var loading = false
    @Published var pageTitle = ""
    @Published var pageHost = ""
    @Published var notice: String?
    @Published var showHome = true

    @Published var blockingEnabled = true {
        didSet { applyBlocking(); webView.reload() }
    }
    // Individual blocking layers, saved between launches.
    @Published var rulesEnabled: Bool { didSet { layerChanged("layer.rules", rulesEnabled) } }
    @Published var youtubeScriptEnabled: Bool { didSet { layerChanged("layer.youtube", youtubeScriptEnabled) } }
    @Published var twitchScriptEnabled: Bool { didSet { layerChanged("layer.twitch", twitchScriptEnabled) } }
    /// Plays YouTube videos in a plain player fed by yt-dlp, instead of YouTube's own player.
    @Published var nativePlayerEnabled: Bool { didSet { layerChanged("layer.player", nativePlayerEnabled) } }

    @Published var allowedDomains: [String] { didSet { defaults.set(allowedDomains, forKey: "allowedDomains") } }
    /// Per-site rules (hidden elements and blocked requests). Declarative only, no scripts.
    @Published var siteRules: [String: SiteRuleSet] {
        didSet { defaults.set(try? JSONEncoder().encode(siteRules), forKey: "siteRules") }
    }
    @Published var adsBlocked: Int { didSet { defaults.set(adsBlocked, forKey: "stats.ads") } }
    /// Bumped whenever a custom file is saved or reverted, so views can refresh.
    @Published var customFilesVersion = 0

    private let resolver = StreamResolver()
    private let selfTest = ProcessInfo.processInfo.environment["ADFREE_SELFTEST"] != nil
    private var testLog: [String] = []
    private var lastTwitchStat = Date.distantPast

    private func layerChanged(_ key: String, _ value: Bool) {
        defaults.set(value, forKey: key)
        applyBlocking()
        webView.reload()
    }

    override init() {
        let defaults = UserDefaults.standard
        func saved(_ key: String) -> Bool { defaults.object(forKey: key) as? Bool ?? true }
        var rules = saved("layer.rules"), yt = saved("layer.youtube"), tw = saved("layer.twitch")
        // ADFREE_LAYERS=rules,youtube,twitch (any subset) overrides the saved layers, for testing.
        if let layers = ProcessInfo.processInfo.environment["ADFREE_LAYERS"] {
            let on = Set(layers.split(separator: ",").map(String.init))
            rules = on.contains("rules"); yt = on.contains("youtube"); tw = on.contains("twitch")
        }
        rulesEnabled = rules; youtubeScriptEnabled = yt; twitchScriptEnabled = tw
        nativePlayerEnabled = saved("layer.player")
        var domains = defaults.stringArray(forKey: "allowedDomains") ?? Self.defaultDomains
        if !domains.contains(Self.lockedDomain) { domains.insert(Self.lockedDomain, at: 0) }
        allowedDomains = domains
        adsBlocked = defaults.integer(forKey: "stats.ads")
        siteRules = (defaults.data(forKey: "siteRules").flatMap { try? JSONDecoder().decode([String: SiteRuleSet].self, from: $0) }) ?? [:]

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // persistent: logins survive restarts
        config.userContentController = controller
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isInspectable = true // Safari > Develop > this Mac > AdFree
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

        observers = [
            webView.observe(\.canGoBack) { [weak self] w, _ in self?.canGoBack = w.canGoBack },
            webView.observe(\.canGoForward) { [weak self] w, _ in self?.canGoForward = w.canGoForward },
            webView.observe(\.isLoading) { [weak self] w, _ in self?.loading = w.isLoading },
            webView.observe(\.title) { [weak self] w, _ in self?.pageTitle = w.title ?? "" },
            webView.observe(\.url) { [weak self] w, _ in self?.pageHost = w.url?.host ?? "" },
        ]
        controller.add(self, name: "adfree")
        if selfTest { installTestLogging() }
        compileRules { [weak self] in
            guard let self else { return }
            self.applyBlocking()
            if self.selfTest { self.runSelfTest() }
        }
    }

    // MARK: Messages from the page scripts

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "log" {
            if testLog.count < 60 { testLog.append("\(message.body)") }
            return
        }
        guard let body = message.body as? [String: Any] else { return }
        if let id = body["watch"] as? String { return resolveStream(id) }
        guard body["ad"] != nil else { return }
        // Twitch reports once per playlist poll, so collapse a burst into one ad.
        if (body["site"] as? String) == "twitch" {
            guard Date().timeIntervalSince(lastTwitchStat) > 20 else { return }
            lastTwitchStat = Date()
        }
        adsBlocked += 1
    }

    /// The page asked for a stream: run yt-dlp, then hand the result back to the page's player script.
    private func resolveStream(_ id: String) {
        resolver.resolve(id) { [weak self] stream, problem in
            var payload: [String: Any] = ["id": id]
            if let stream {
                payload["url"] = stream.url
                payload["title"] = stream.title
                payload["chapters"] = stream.chapters
            } else {
                payload["error"] = problem ?? "Unknown error"
            }
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else { return }
            self?.webView.evaluateJavaScript("window.__adfreePlay && window.__adfreePlay(\(json))")
        }
    }

    // MARK: Rules and scripts (built-in, with optional custom copies)

    /// Custom copies live here. A file exists only after the user saves an edit in Settings.
    static var overridesFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AdFree", isDirectory: true)
    }

    private func overrideURL(_ file: String) -> URL { Self.overridesFolder.appendingPathComponent(file) }

    func builtInSource(_ file: String) -> String {
        let parts = file.split(separator: ".").map(String.init)
        guard parts.count == 2, let url = Bundle.main.url(forResource: parts[0], withExtension: parts[1]) else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func hasCustom(_ file: String) -> Bool { FileManager.default.fileExists(atPath: overrideURL(file).path) }

    func currentSource(_ file: String) -> String {
        if !selfTest, let text = try? String(contentsOf: overrideURL(file), encoding: .utf8) { return text }
        return builtInSource(file)
    }

    /// Returns an error message if the text isn't valid for that file.
    func validate(_ file: String, _ text: String) -> String? {
        if file.hasSuffix(".json") {
            do { _ = try JSONSerialization.jsonObject(with: Data(text.utf8)); return nil }
            catch { return "Not valid JSON: \(error.localizedDescription)" }
        }
        guard let literal = try? JSONEncoder().encode(text), let source = String(data: literal, encoding: .utf8),
              let context = JSContext() else { return nil }
        _ = context.evaluateScript("new Function(\(source))") // parses without running
        if let ex = context.exception { return "JavaScript error: \(ex.toString() ?? "unknown")" }
        return nil
    }

    func saveCustom(_ file: String, _ text: String, then done: @escaping (String?) -> Void) {
        if let problem = validate(file, text) { return done(problem) }
        do {
            try FileManager.default.createDirectory(at: Self.overridesFolder, withIntermediateDirectories: true)
            try text.write(to: overrideURL(file), atomically: true, encoding: .utf8)
        } catch { return done("Couldn't save: \(error.localizedDescription)") }
        customFilesVersion += 1
        reloadBlocking { done(nil) }
    }

    func revertCustom(_ file: String, then done: @escaping () -> Void = {}) {
        try? FileManager.default.removeItem(at: overrideURL(file))
        customFilesVersion += 1
        reloadBlocking(then: done)
    }

    /// Opens the folder holding custom copies in Finder, selecting the file if it exists.
    func revealInFinder(_ file: String? = nil) {
        try? FileManager.default.createDirectory(at: Self.overridesFolder, withIntermediateDirectories: true)
        if let file, hasCustom(file) { NSWorkspace.shared.activateFileViewerSelecting([overrideURL(file)]) }
        else { NSWorkspace.shared.open(Self.overridesFolder) }
    }

    private func resource(_ name: String, _ ext: String) -> String? {
        let text = currentSource("\(name).\(ext)")
        return text.isEmpty ? nil : text
    }

    private func compileRules(then done: @escaping () -> Void) {
        guard let base = resource("ContentRules", "json") else { return done() }
        let json = SiteRuleSet.merge(base, siteRules)
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "adfree", encodedContentRuleList: json) { [weak self] list, error in
            if let error { print("Rule compile failed: \(error)") }
            self?.ruleList = list
            DispatchQueue.main.async(execute: done)
        }
    }

    private func applyBlocking() {
        controller.removeAllUserScripts()
        controller.removeAllContentRuleLists()
        if selfTest { installTestLogging() }
        guard blockingEnabled else { return }
        if rulesEnabled, let ruleList { controller.add(ruleList) }
        var scripts: [String] = []
        if youtubeScriptEnabled { scripts.append("youtube-adblock") }
        if nativePlayerEnabled { scripts.append("youtube-player") }
        if twitchScriptEnabled { scripts.append("twitch-adblock") }
        for name in scripts {
            if let src = resource(name, "js") {
                controller.addUserScript(WKUserScript(source: src, injectionTime: .atDocumentStart, forMainFrameOnly: false))
            }
        }
    }

    // MARK: Diagnostics and rule helpers (report, page snapshot, validated site rules)

    /// Checks that WebKit accepts a rule list, without installing it. Returns an error message or nil.
    func compileCheck(_ json: String) async -> String? {
        await withCheckedContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "adfree-check", encodedContentRuleList: json) { list, error in
                if let error {
                    let detail = (error as NSError).helpAnchor ?? error.localizedDescription
                    return continuation.resume(returning: "WebKit rejected these rules: \(detail)")
                }
                WKContentRuleListStore.default().removeContentRuleList(forIdentifier: "adfree-check") { _ in }
                continuation.resume(returning: nil)
            }
        }
    }

    /// Validates, then saves rules for one allowed site and recompiles. Returns an error message or nil.
    func setSiteRules(domain: String, hide: [String], block: [String]) async -> String? {
        guard allowedDomains.contains(domain) else { return "\(domain) is not on the allowed list." }
        var proposed = siteRules
        let set = SiteRuleSet(hide: hide, block: block).cleaned
        proposed[domain] = (set.hide.isEmpty && set.block.isEmpty) ? nil : set
        guard let base = resource("ContentRules", "json") else { return "The rules file is missing." }
        if let problem = await compileCheck(SiteRuleSet.merge(base, proposed)) { return problem }
        siteRules = proposed
        await withCheckedContinuation { c in reloadBlocking { c.resume() } }
        return nil
    }

    /// Checks that WebKit would accept these rules for a site, without saving them.
    func checkSiteRules(domain: String, set: SiteRuleSet) async -> String? {
        guard let base = resource("ContentRules", "json") else { return "The rules file is missing." }
        var proposed = siteRules
        proposed[domain] = set
        return await compileCheck(SiteRuleSet.merge(base, proposed))
    }

    /// Checks a replacement for ContentRules.json together with the saved site rules.
    func checkRulesFile(_ text: String) async -> String? {
        await compileCheck(SiteRuleSet.merge(text, siteRules))
    }

    func report() async -> String {
        await withCheckedContinuation { c in diagnose { c.resume(returning: $0) } }
    }

    /// Opens an allowed site and waits for it to settle, so a snapshot sees its ads.
    func openAndWait(_ domain: String) async -> String {
        guard allowedDomains.contains(domain) else { return "\(domain) is not on the allowed list." }
        open(domain: domain)
        try? await Task.sleep(nanoseconds: 800_000_000)
        var waited = 0
        while loading && waited < 40 { try? await Task.sleep(nanoseconds: 500_000_000); waited += 1 }
        try? await Task.sleep(nanoseconds: 2_500_000_000) // late-loading ad slots
        return "Loaded \(webView.url?.absoluteString ?? domain)"
    }

    /// Structure of the current page: no text, no form values, no query strings.
    func pageSnapshot() async -> String {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(Self.snapshotJS) { result, error in
                continuation.resume(returning: (result as? String) ?? "Snapshot failed: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    private static let snapshotJS = #"""
    (() => {
      const hostOf = (u) => { try { return new URL(u, location.href).host; } catch (e) { return null; } };
      const out = { page: location.origin + location.pathname, host: location.host };
      const hosts = {};
      for (const e of document.querySelectorAll('script[src],iframe[src],img[src],link[href]')) {
        const h = hostOf(e.src || e.href);
        if (h && h !== location.host) hosts[h] = (hosts[h] || 0) + 1;
      }
      out.thirdPartyHosts = Object.entries(hosts).sort((a, b) => b[1] - a[1]).slice(0, 40);
      const adish = /(^|[-_ ])(ad|ads|adv|advert|advertisement|sponsor|sponsored|promo|banner|popup|modal|overlay|paywall|consent|newsletter|sticky|taboola|outbrain|dfp|gpt|adsbygoogle)([-_ 0-9]|$)/i;
      const sel = (e) => {
        if (e.id) return e.tagName.toLowerCase() + '#' + CSS.escape(e.id);
        const cls = typeof e.className === 'string' ? e.className.trim().split(/\s+/).filter(Boolean).slice(0, 3) : [];
        return e.tagName.toLowerCase() + cls.map((c) => '.' + CSS.escape(c)).join('');
      };
      const area = innerWidth * innerHeight;
      const items = [];
      for (const e of document.querySelectorAll('body *')) {
        if (items.length >= 120) break;
        const cs = getComputedStyle(e), r = e.getBoundingClientRect();
        const cls = typeof e.className === 'string' ? e.className : '';
        const covering = (cs.position === 'fixed' || cs.position === 'sticky') && r.width * r.height > area * 0.15;
        const looksLikeAd = adish.test(e.id || '') || adish.test(cls) || (e.tagName === 'IFRAME' && hostOf(e.src) !== location.host);
        if (!covering && !looksLikeAd) continue;
        if (r.width < 2 && r.height < 2 && !covering) continue;
        items.push({ selector: sel(e), tag: e.tagName.toLowerCase(), position: cs.position, zIndex: cs.zIndex,
                     size: [Math.round(r.width), Math.round(r.height)], visible: cs.display !== 'none' && cs.visibility !== 'hidden',
                     iframeHost: e.tagName === 'IFRAME' ? hostOf(e.src) : undefined });
      }
      out.candidates = items;
      out.bodyOverflow = getComputedStyle(document.body).overflow;
      return JSON.stringify(out);
    })()
    """#

    // MARK: Fix-it actions

    /// Re-reads the rules and scripts and reloads the page.
    func reloadBlocking(then done: @escaping () -> Void = {}) {
        compileRules { [weak self] in
            self?.applyBlocking()
            self?.webView.reload()
            done()
        }
    }

    /// Clears cached pages and scripts only. Cookies and logins are kept.
    func clearCache(then done: @escaping () -> Void = {}) {
        let types: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache,
                                  WKWebsiteDataTypeOfflineWebApplicationCache, WKWebsiteDataTypeFetchCache,
                                  WKWebsiteDataTypeServiceWorkerRegistrations]
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) { [weak self] in
            self?.webView.reloadFromOrigin()
            done()
        }
    }

    /// Builds a plain-text report about the current page's ad state.
    func diagnose(_ done: @escaping (String) -> Void) {
        let js = """
        (() => {
          const h = location.hostname, r = { host: h, injected: window.__adfree || 'no' };
          if (/youtube/.test(h)) {
            const p = document.querySelector('.html5-video-player');
            r.playerFound = !!p; r.adShowing = !!(p && p.classList.contains('ad-showing'));
            r.skipButton = !!document.querySelector('.ytp-skip-ad-button,.ytp-ad-skip-button-modern');
            r.playability = window.__adfreeStatus ? String(window.__adfreeStatus).slice(0, 80) : null;
            r.enforcementElement = !!document.querySelector('ytd-enforcement-message-view-model');
            const v = document.querySelector('video.html5-main-video');
            r.video = v ? { ready: v.readyState, net: v.networkState, paused: v.paused, t: v.currentTime, w: v.videoWidth, err: v.error && v.error.code, src: !!v.currentSrc } : null;
            const mp = document.querySelector('#movie_player');
            try { r.playerState = mp && mp.getPlayerState && mp.getPlayerState(); } catch (e) {}
            if (v) {
              const cs = getComputedStyle(v), b = v.getBoundingClientRect();
              r.videoStyle = { vis: cs.visibility, disp: cs.display, op: cs.opacity, filter: cs.filter, tf: cs.transform.slice(0, 40), rect: [b.x, b.y, b.width, b.height].map(Math.round) };
              r.audio = { muted: v.muted, vol: v.volume, rate: v.playbackRate };
              r.videoCount = document.querySelectorAll('video').length;
              const hid = []; for (let n = v.parentElement; n && hid.length < 8; n = n.parentElement) { const c = getComputedStyle(n); if (c.visibility !== 'visible' || c.display === 'none' || c.opacity !== '1') hid.push(n.tagName.toLowerCase() + '.' + String(n.className).slice(0, 30) + ' ' + c.visibility + '/' + c.display + '/' + c.opacity); }
              r.hiddenAncestors = hid;
              const top = document.elementFromPoint(b.x + b.width / 2, b.y + b.height / 2);
              r.coveredBy = top ? top.tagName.toLowerCase() + '.' + String(top.className).slice(0, 60) : null;
            }
            r.playerClasses = p ? p.className.slice(-200) : null;
            r.log = window.__adfreeLog || null;
            r.nativePlayerError = window.__adfreePlayerError || null;
            r.playerError = (document.querySelector('.ytp-error') || {}).innerText || null;
            // Find the smallest element whose text mentions the wall, to learn its real selector.
            let wall = null;
            for (const e of document.querySelectorAll('body *')) {
              if (e.children.length < 4 && /ad blockers?|violate/i.test(e.textContent || '') && (e.textContent || '').length < 400) {
                const chain = []; for (let n = e; n && chain.length < 6; n = n.parentElement) chain.push(n.tagName.toLowerCase() + (n.id ? '#' + n.id : ''));
                wall = { chain: chain.join(' < '), text: e.textContent.trim().slice(0, 160) };
                break;
              }
            }
            r.wall = wall;
          } else if (/twitch/.test(h)) {
            r.videoFound = !!document.querySelector('video');
            r.adLabel = !!document.querySelector('[data-a-target="video-ad-label"],[data-test-selector="ad-banner-default-text"]');
            r.lastAdSample = window.__adfreeSample ? String(window.__adfreeSample).slice(0, 1200) : null;
          }
          return JSON.stringify(r);
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self else { return }
            let custom = Self.editableFiles.filter(self.hasCustom)
            var lines = [
                "AdFree report",
                "Page: \(self.webView.url?.absoluteString ?? "none")",
                "Blocking enabled: \(self.blockingEnabled)",
                "Layers: rules=\(self.rulesEnabled) youtube=\(self.youtubeScriptEnabled) player=\(self.nativePlayerEnabled) twitch=\(self.twitchScriptEnabled)",
                "Rules compiled: \(self.ruleList != nil)",
                "Custom files: \(custom.isEmpty ? "none" : custom.joined(separator: ", "))",
                "Ads blocked so far: \(self.adsBlocked)",
                "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            ]
            if let result { lines.append("Page state: \(result)") }
            if let error { lines.append("Page state unavailable: \(error.localizedDescription)") }
            done(lines.joined(separator: "\n"))
        }
    }

    // MARK: Allowed sites

    /// Cleans user input like "https://www.Example.com/path" into "example.com". Nil if it isn't a domain.
    static func normalizeDomain(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = text.range(of: "://") { text = String(text[range.upperBound...]) }
        text = text.split(whereSeparator: { "/?#:".contains($0) }).first.map(String.init) ?? ""
        if text.hasPrefix("www.") { text.removeFirst(4) }
        let pattern = #"^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$"#
        return text.range(of: pattern, options: .regularExpression) != nil ? text : nil
    }

    func addDomain(_ input: String) -> String? {
        guard let domain = Self.normalizeDomain(input) else { return "That doesn't look like a website address." }
        if allowedDomains.contains(domain) { return "\(domain) is already allowed." }
        allowedDomains.append(domain)
        return nil
    }

    func removeDomain(_ domain: String) {
        guard domain != Self.lockedDomain else { return }
        allowedDomains.removeAll { $0 == domain }
        if siteRules[domain] != nil { siteRules[domain] = nil; reloadBlocking() }
    }

    private func isAllowed(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if Self.googleSignInHosts.contains(host) { return true }
        if host == "www.google.com" && url.path.lowercased().hasPrefix("/accounts") { return true }
        return allowedDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    // MARK: Home page (one card per allowed site)

    /// Sites shown on the home page: exactly the allowed list. youtu.be is only a short-link
    /// alias of YouTube, so it gets no card of its own.
    var homeSites: [String] { allowedDomains.filter { $0 != "youtu.be" } }

    static func displayName(for domain: String) -> String {
        switch domain {
        case "youtube.com": return "YouTube"
        case "twitch.tv": return "Twitch"
        default: return domain
        }
    }

    func open(domain: String) {
        guard let url = URL(string: "https://\(domain)") else { return }
        showHome = false
        openedFromHome = true
        webView.load(URLRequest(url: url))
    }

    // MARK: Navigation

    func goHome() {
        webView.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.pause())")
        showHome = true
    }

    /// Lets the Claude Code bridge tell the user what it changed.
    func notify(_ text: String) { showNotice(text, seconds: 10) }

    private func showNotice(_ text: String, seconds: Double = 4) {
        notice = text
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            if self?.notice == text { self?.notice = nil }
        }
    }

    // MARK: Load failures (so a broken or mistyped site is never silent)

    /// True while a home-page card is loading, so a failure can send you back to the home page.
    private var openedFromHome = false

    private func handleLoadFailure(_ error: Error) {
        let e = error as NSError
        // Only real network errors. Cancelled loads and our own blocked links are not failures.
        guard e.domain == NSURLErrorDomain, e.code != NSURLErrorCancelled else { return }
        let host = (e.userInfo[NSURLErrorFailingURLErrorKey] as? URL)?.host ?? "that site"
        let reason: String
        switch e.code {
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            reason = "\(host) doesn't exist or can't be found. Check the address in Settings → Allowed sites."
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            reason = "No internet connection, so \(host) couldn't load."
        case NSURLErrorTimedOut:
            reason = "\(host) took too long to respond."
        case NSURLErrorCannotConnectToHost:
            reason = "\(host) refused the connection."
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorServerCertificateNotYetValid:
            reason = "\(host) has a security problem (certificate), so it was not opened."
        default:
            reason = "\(host) couldn't load: \(e.localizedDescription)"
        }
        if openedFromHome { openedFromHome = false; showHome = true }
        showNotice("Couldn't open this page. " + reason, seconds: 10)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { openedFromHome = false }

    /// Flags main pages that load but come back as an error (404, 500, ...).
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame, let http = navigationResponse.response as? HTTPURLResponse, http.statusCode >= 400 {
            let host = http.url?.host ?? "this site"
            showNotice("\(host) returned an error (\(http.statusCode)): the page may not exist.", seconds: 8)
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        guard isMainFrame, let url = navigationAction.request.url,
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              !isAllowed(url) else {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        showNotice("Blocked a link to \(url.host ?? "another site"). Only your allowed sites open here.")
        DispatchQueue.main.async { webView.load(URLRequest(url: Self.home)) }
    }

    // Open target=_blank links in the same view (they pass through decidePolicyFor).
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }

    // MARK: Self-test (headless Twitch check, used during development)

    private func installTestLogging() {
        controller.removeScriptMessageHandler(forName: "log")
        controller.add(self, name: "log")
        let js = """
        (() => {
          const send = (t, m) => { try { webkit.messageHandlers.log.postMessage(t + ': ' + m); } catch (e) {} };
          // Test runs may have no visible window; Twitch won't stream into a hidden page.
          window.__adfreeDebug = true;
          window.__adfreeForce = \(ProcessInfo.processInfo.environment["ADFREE_FORCE_BACKUP"] != nil);
          Object.defineProperty(document, 'visibilityState', { get: () => 'visible' });
          Object.defineProperty(document, 'hidden', { get: () => false });
          const ce = console.error; console.error = function () { send('console.error', [...arguments].map(String).join(' ').slice(0, 300)); return ce.apply(this, arguments); };
          window.addEventListener('error', (e) => send('error', e.message + ' @' + (e.filename || '').slice(-60)));
          window.addEventListener('unhandledrejection', (e) => send('rejection', String(e.reason).slice(0, 300)));
        })();
        """
        controller.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    }

    private func eval(_ js: String, _ done: @escaping (Any?) -> Void) {
        webView.evaluateJavaScript(js) { r, _ in done(r) }
    }

    private func load(_ s: String) { if let u = URL(string: s) { showHome = false; webView.load(URLRequest(url: u)) } }

    private func runSelfTest() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        load("https://www.twitch.tv/directory/all")
        var tries = 0
        func findStream() {
            eval("document.querySelector('a[data-a-target=\"preview-card-image-link\"]')?.href || ''") { [weak self] r in
                guard let self else { return }
                if let href = r as? String, !href.isEmpty {
                    self.testLog.append("channel: \(href)")
                    self.load(href)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 20) { self.sampleVideo(first: true) }
                } else if tries < 30 {
                    tries += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { findStream() }
                } else { self.finishSelfTest("no stream link found on the directory page") }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { findStream() }
    }

    private var firstSample: String?
    private func sampleVideo(first: Bool) {
        let js = """
        (() => { const v = document.querySelector('video');
          const gate = document.querySelector('[data-a-target="content-classification-gate-overlay-start-watching-button"]');
          if (gate) gate.click();
          if (v && v.paused) v.play().catch(() => {});
          return JSON.stringify({ vis: document.visibilityState, gate: !!gate, video: !!v, ready: v && v.readyState,
            t: v && v.currentTime, paused: v && v.paused, w: v && v.videoWidth, muted: v && v.muted,
            adfree: window.__adfree || null, url: location.href }); })()
        """
        eval(js) { [weak self] r in
            guard let self else { return }
            let text = (r as? String) ?? "no result"
            if first {
                self.firstSample = text
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { self.sampleVideo(first: false) }
            } else {
                self.testLog.insert("sample1: \(self.firstSample ?? "")", at: 0)
                self.testLog.insert("sample2: \(text)", at: 1)
                self.finishSelfTest(nil)
            }
        }
    }

    private func finishSelfTest(_ problem: String?) {
        var out = ["layers: rules=\(rulesEnabled) youtube=\(youtubeScriptEnabled) twitch=\(twitchScriptEnabled) blocking=\(blockingEnabled)",
                   "ads counted: \(adsBlocked)"]
        if let problem { out.append("problem: \(problem)") }
        out += testLog
        print(out.joined(separator: "\n"))
        fflush(stdout)
        NSApp.terminate(nil)
    }
}


/// Hidden elements and blocked requests for one site. Declarative only: no scripts.
struct SiteRuleSet: Codable, Equatable {
    var hide: [String]
    var block: [String]

    /// Drops anything that is not a plain selector or URL pattern, and caps the size.
    var cleaned: SiteRuleSet {
        func ok(_ text: String) -> Bool {
            !text.isEmpty && text.count <= 200 && text.rangeOfCharacter(from: CharacterSet(charactersIn: "{};\n\r")) == nil
        }
        return SiteRuleSet(hide: Array(hide.map { $0.trimmingCharacters(in: .whitespaces) }.filter(ok).prefix(60)),
                           block: Array(block.map { $0.trimmingCharacters(in: .whitespaces) }.filter(ok).prefix(40)))
    }

    /// Appends the per-site rules to the base content rules. Each one applies only on its own site.
    static func merge(_ baseJSON: String, _ sites: [String: SiteRuleSet]) -> String {
        guard !sites.isEmpty,
              var rules = (try? JSONSerialization.jsonObject(with: Data(baseJSON.utf8))) as? [[String: Any]] else { return baseJSON }
        for (domain, set) in sites.sorted(by: { $0.key < $1.key }) {
            let scope = ["*" + domain]
            if !set.hide.isEmpty {
                rules.append(["trigger": ["url-filter": ".*", "if-domain": scope],
                              "action": ["type": "css-display-none", "selector": set.hide.joined(separator: ", ")]])
            }
            for pattern in set.block {
                rules.append(["trigger": ["url-filter": pattern, "if-domain": scope], "action": ["type": "block"]])
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rules), let text = String(data: data, encoding: .utf8) else { return baseJSON }
        return text
    }
}
