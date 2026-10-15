// Generates a short illustration of what AdFree does, as an H.264 video. It draws a mock window
// with placeholder content (no real sites, no screen recording) frame by frame.
// Usage: swift tools/make-demo.swift <output.mp4>
import AppKit
import AVFoundation
import CoreVideo

let W = 1280, H = 720, FPS = 20
let DURATION = 39.5

// MARK: Colors

func rgb(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}
let bg = rgb(0x0a0e17), winBg = rgb(0x1e1f24), bar = rgb(0x2a2c33), card = rgb(0x30323a), thumb = rgb(0x3b3e48)
let muted = rgb(0x8c9ab3), cyan = rgb(0x5cd6ff), amber = rgb(0xffb454), blue = rgb(0x2f7cf6)

// MARK: Drawing helpers (top-left origin)

func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, fill: NSColor? = nil, stroke: NSColor? = nil, lw: CGFloat = 1) {
    let p = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
    if let fill { fill.setFill(); p.fill() }
    if let stroke { stroke.setStroke(); p.lineWidth = lw; p.stroke() }
}
func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont { .systemFont(ofSize: size, weight: weight) }
func textSize(_ s: String, _ size: CGFloat = 13, _ weight: NSFont.Weight = .regular) -> NSSize {
    s.size(withAttributes: [.font: font(size, weight)])
}
/// Draws text; `center` treats x as the horizontal center, `mid` treats y as the vertical center.
func text(_ s: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat = 13, weight: NSFont.Weight = .regular,
          color: NSColor = .white, center: Bool = false, mid: Bool = true) {
    let a: [NSAttributedString.Key: Any] = [.font: font(size, weight), .foregroundColor: color]
    let sz = s.size(withAttributes: a)
    s.draw(at: NSPoint(x: center ? x - sz.width / 2 : x, y: mid ? y - sz.height / 2 : y), withAttributes: a)
}
func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: NSColor) {
    c.setFill(); NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
}
func poly(_ pts: [(CGFloat, CGFloat)], _ c: NSColor) {
    let p = NSBezierPath(); p.move(to: NSPoint(x: pts[0].0, y: pts[0].1))
    for q in pts.dropFirst() { p.line(to: NSPoint(x: q.0, y: q.1)) }
    p.close(); c.setFill(); p.fill()
}
func smooth(_ t: Double) -> Double { let c = min(max(t, 0), 1); return c * c * (3 - 2 * c) }
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

// MARK: Layout

let wx: CGFloat = 80, wy: CGFloat = 24, ww: CGFloat = 1120, wh: CGFloat = 600
let contentTop = wy + 72
let tbMid = wy + 50
let housePt = CGPoint(x: wx + 30, y: tbMid), gearPt = CGPoint(x: wx + ww - 28, y: tbMid)
let fixPt = CGPoint(x: wx + ww - 112, y: tbMid), togglePt = CGPoint(x: wx + ww - 225, y: tbMid)
func cardCenter(_ i: Int) -> CGPoint { CGPoint(x: wx + 32 + 115 + CGFloat(i) * 246, y: contentTop + 90 + 55) }
let videoRect = CGRect(x: wx + 32, y: contentTop + 24, width: 720, height: 405)
let linkX = wx + 32 + textSize("More info: ", 14).width
let linkW = textSize("desiredsite.com", 14).width
let linkPt = CGPoint(x: linkX + linkW / 2, y: videoRect.maxY + 60)
let settingsRect = CGRect(x: wx + 230, y: wy + 90, width: 660, height: 420)
let fieldPt = CGPoint(x: settingsRect.minX + 180, y: settingsRect.maxY - 54)
let addBtnPt = CGPoint(x: settingsRect.maxX - 62, y: settingsRect.maxY - 54)
let closePt = CGPoint(x: settingsRect.minX + 16, y: settingsRect.minY + 14)
let dialogRect = CGRect(x: settingsRect.midX - 200, y: settingsRect.midY - 90, width: 400, height: 180)
let allowPt = CGPoint(x: dialogRect.midX + 20, y: dialogRect.maxY - 46)

// MARK: Timeline

struct Key { let t: Double; let x: CGFloat; let y: CGFloat }
let path: [Key] = [
    Key(t: 0, x: 640, y: 420), Key(t: 3.2, x: 640, y: 420), Key(t: 4.8, x: cardCenter(0).x, y: cardCenter(0).y),
    Key(t: 7.0, x: cardCenter(0).x, y: cardCenter(0).y), Key(t: 8.2, x: linkPt.x, y: linkPt.y),
    Key(t: 9.6, x: linkPt.x, y: linkPt.y), Key(t: 13.4, x: gearPt.x, y: gearPt.y),
    Key(t: 14.0, x: gearPt.x, y: gearPt.y), Key(t: 15.0, x: fieldPt.x, y: fieldPt.y),
    Key(t: 17.0, x: fieldPt.x, y: fieldPt.y), Key(t: 17.6, x: addBtnPt.x, y: addBtnPt.y),
    Key(t: 18.0, x: addBtnPt.x, y: addBtnPt.y), Key(t: 19.0, x: allowPt.x, y: allowPt.y),
    Key(t: 19.5, x: allowPt.x, y: allowPt.y), Key(t: 20.7, x: closePt.x, y: closePt.y),
    Key(t: 21.0, x: closePt.x, y: closePt.y), Key(t: 21.9, x: housePt.x, y: housePt.y),
    Key(t: 22.3, x: housePt.x, y: housePt.y), Key(t: 24.3, x: cardCenter(2).x, y: cardCenter(2).y),
    Key(t: 27.5, x: cardCenter(2).x, y: cardCenter(2).y), Key(t: 28.6, x: togglePt.x, y: togglePt.y),
    Key(t: 29.6, x: togglePt.x, y: togglePt.y), Key(t: 31.5, x: fixPt.x, y: fixPt.y),
    Key(t: 39.5, x: fixPt.x, y: fixPt.y),
]
let clicks: [Double] = [5.0, 8.5, 13.9, 17.8, 19.2, 20.9, 22.2, 25.0, 29.0, 31.9]
let captions: [(Double, Double, String)] = [
    (0, 5.0, "Home: one card for every site you've allowed"),
    (5.0, 8.4, "Browse normally, signed in as you"),
    (8.4, 13.5, "A link to a site that isn't allowed is blocked and sent to YouTube"),
    (13.5, 21.0, "Settings → Allowed sites: add it, then confirm"),
    (21.0, 25.0, "The home page updates automatically"),
    (25.0, 27.5, "Now the same link opens"),
    (27.5, 29.0, "Block ads off: an ad plays"),
    (29.0, 31.8, "Block ads on: no ad, and the counter goes up"),
    (31.8, 39.5, "Ad slipped through? \"Ads showing?\" walks you through the fix"),
]

func cursor(at t: Double) -> CGPoint {
    var a = path[0], b = path[0]
    for i in 0..<path.count - 1 where t >= path[i].t && t <= path[i + 1].t { a = path[i]; b = path[i + 1] }
    if t > path.last!.t { a = path.last!; b = a }
    let k = b.t > a.t ? smooth((t - a.t) / (b.t - a.t)) : 1
    return CGPoint(x: lerp(Double(a.x), Double(b.x), k), y: lerp(Double(a.y), Double(b.y), k))
}

// MARK: Scene pieces

func drawToolbar(host: String, count: Int, blockOn: Bool, countFlash: Bool) {
    rr(wx, wy + 28, ww, 44, 0, fill: bar)
    for (i, g) in ["⌂", "‹", "›", "↻"].enumerated() {
        rr(wx + 14 + CGFloat(i) * 36, tbMid - 13, 30, 26, 6, fill: rgb(0x3a3d46))
        text(g, wx + 29 + CGFloat(i) * 36, tbMid, size: 15, center: true)
    }
    text("●  " + host, wx + 170, tbMid, size: 13, color: muted)
    text("⊘ \(count)", wx + ww - 335, tbMid, size: 14, weight: .semibold, color: countFlash ? amber : .white, center: true)
    rr(togglePt.x - 50, tbMid - 14, 100, 28, 7, fill: blockOn ? blue : rgb(0x3a3d46))
    text("Block ads", togglePt.x, tbMid, size: 12.5, weight: .medium, center: true)
    rr(fixPt.x - 62, tbMid - 14, 124, 28, 7, fill: rgb(0x3a3d46))
    text("Ads showing?", fixPt.x, tbMid, size: 12.5, weight: .medium, center: true)
    rr(gearPt.x - 15, tbMid - 13, 30, 26, 6, fill: rgb(0x3a3d46))
    text("⚙", gearPt.x, tbMid, size: 15, center: true)
}

func drawHome(sites: [(String, String)], highlight: Int?, t: Double) {
    rr(wx, contentTop, ww, wy + wh - contentTop, 0, fill: winBg)
    text("Your sites", wx + 32, contentTop + 42, size: 30, weight: .bold)
    for (i, s) in sites.enumerated() {
        let x = wx + 32 + CGFloat(i) * 246, y = contentTop + 90
        rr(x, y, 230, 110, 10, fill: card)
        if i == highlight {
            let pulse = 0.55 + 0.45 * sin(t * 7)
            rr(x - 2, y - 2, 234, 114, 12, stroke: cyan.withAlphaComponent(CGFloat(pulse)), lw: 3)
        }
        text(s.0 == "youtube.com" ? "▶" : (s.0 == "twitch.tv" ? "◉" : "◍"), x + 14, y + 26, size: 22)
        text(s.1, x + 14, y + 62, size: 16, weight: .semibold)
        text(s.0, x + 14, y + 86, size: 12, color: muted)
    }
    text("This list is your allowed sites.   Add or remove sites in Settings", wx + 32, contentTop + 232, size: 12, color: muted)
}

func drawThumbGrid() {
    rr(wx, contentTop, ww, wy + wh - contentTop, 0, fill: winBg)
    for r in 0..<2 { for c in 0..<4 {
        let x = wx + 32 + CGFloat(c) * 265, y = contentTop + 30 + CGFloat(r) * 250
        rr(x, y, 245, 138, 8, fill: thumb)
        rr(x, y + 150, 200, 10, 5, fill: rgb(0x555966)); rr(x, y + 168, 140, 9, 4, fill: rgb(0x40434d))
    } }
}

func drawWatchPage(adVisible: Bool, blockOn: Bool, t: Double, link: Bool) {
    rr(wx, contentTop, ww, wy + wh - contentTop, 0, fill: winBg)
    rr(videoRect.minX, videoRect.minY, videoRect.width, videoRect.height, 10, fill: rgb(0x14161b))
    if adVisible {
        rr(videoRect.minX, videoRect.minY, videoRect.width, videoRect.height, 10, fill: rgb(0x2b2620))
        rr(videoRect.minX + 16, videoRect.maxY - 54, 92, 26, 5, fill: amber)
        text("Ad · 0:05", videoRect.minX + 62, videoRect.maxY - 41, size: 12.5, weight: .bold, color: .black, center: true)
        rr(videoRect.maxX - 110, videoRect.maxY - 58, 94, 32, 6, fill: rgb(0x000000, 0.65))
        text("Skip ›", videoRect.maxX - 63, videoRect.maxY - 42, size: 13, weight: .semibold, center: true)
        rr(videoRect.minX + 16, videoRect.maxY - 14, videoRect.width - 32, 4, 2, fill: amber)
        text("Sponsored placeholder", videoRect.midX, videoRect.midY, size: 20, color: rgb(0xffffff, 0.4), center: true)
    } else {
        poly([(videoRect.midX - 22, videoRect.midY - 30), (videoRect.midX - 22, videoRect.midY + 30), (videoRect.midX + 34, videoRect.midY)], rgb(0xffffff, 0.35))
        let p = CGFloat(min(max((t - 29.7) / 8, 0), 1))
        rr(videoRect.minX + 16, videoRect.maxY - 14, videoRect.width - 32, 4, 2, fill: rgb(0x555966))
        rr(videoRect.minX + 16, videoRect.maxY - 14, (videoRect.width - 32) * (0.12 + 0.3 * p), 4, 2, fill: rgb(0xff3b30))
    }
    text("Video title placeholder", videoRect.minX, videoRect.maxY + 28, size: 18, weight: .semibold)
    text("More info: ", videoRect.minX, videoRect.maxY + 60, size: 14, color: muted)
    text("desiredsite.com", linkX, videoRect.maxY + 60, size: 14, color: link ? cyan : muted)
    for i in 0..<4 {
        let y = contentTop + 24 + CGFloat(i) * 120
        rr(wx + 780, y, 180, 100, 8, fill: thumb)
        rr(wx + 972, y + 6, 110, 9, 4, fill: rgb(0x555966)); rr(wx + 972, y + 24, 80, 8, 4, fill: rgb(0x40434d))
    }
}

func drawPlaceholderSite() {
    rr(wx, contentTop, ww, wy + wh - contentTop, 0, fill: rgb(0xf4f5f7))
    text("desiredsite.com", wx + 60, contentTop + 70, size: 34, weight: .bold, color: rgb(0x20232a))
    text("Placeholder page: this site is allowed now.", wx + 60, contentTop + 118, size: 16, color: rgb(0x5b6270))
    for i in 0..<3 { rr(wx + 60 + CGFloat(i) * 300, contentTop + 170, 280, 150, 10, fill: rgb(0xdde1e8)) }
}

func drawSettings(typed: String, list: [String], showDialog: Bool, t: Double) {
    let r = settingsRect
    rr(r.minX, r.minY, r.width, r.height, 12, fill: rgb(0x26272d)); rr(r.minX, r.minY, r.width, r.height, 12, stroke: rgb(0x44464f))
    circle(r.minX + 16, r.minY + 14, 6, rgb(0xff5f57)); circle(r.minX + 36, r.minY + 14, 6, rgb(0x5a5c63)); circle(r.minX + 56, r.minY + 14, 6, rgb(0x5a5c63))
    text("Settings", r.midX, r.minY + 14, size: 13, weight: .semibold, center: true)
    for (i, tab) in ["Allowed sites", "Scripts & rules", "Blocking"].enumerated() {
        let x = r.minX + 120 + CGFloat(i) * 150
        if i == 0 { rr(x - 6, r.minY + 34, 140, 26, 6, fill: rgb(0x3a3d46)) }
        text(tab, x + 64, r.minY + 47, size: 12.5, weight: i == 0 ? .semibold : .regular, color: i == 0 ? .white : muted, center: true)
    }
    text("AdFree only opens these sites. Any other link is sent to YouTube.", r.minX + 24, r.minY + 84, size: 12.5, color: muted)
    for (i, d) in list.enumerated() {
        let y = r.minY + 108 + CGFloat(i) * 32
        rr(r.minX + 24, y, r.width - 48, 28, 6, fill: i % 2 == 0 ? rgb(0x2d2f36) : rgb(0x292b31))
        text(d, r.minX + 36, y + 14, size: 13)
        text(d == "youtube.com" ? "always allowed" : "–", r.maxX - (d == "youtube.com" ? 84 : 44), y + 14, size: 11.5, color: muted, center: true)
    }
    rr(r.minX + 24, fieldPt.y - 15, 310, 30, 6, fill: rgb(0x1a1b20), stroke: rgb(0x44464f))
    let caret = Int(t * 2) % 2 == 0 && !showDialog ? "|" : ""
    text(typed.isEmpty ? "Add a site, e.g. kick.com" : typed + caret, r.minX + 36, fieldPt.y, size: 13, color: typed.isEmpty ? muted : .white)
    rr(addBtnPt.x - 42, addBtnPt.y - 15, 84, 30, 7, fill: blue)
    text("Add…", addBtnPt.x, addBtnPt.y, size: 13, weight: .semibold, center: true)
    if showDialog {
        rr(r.minX, r.minY, r.width, r.height, 12, fill: rgb(0x000000, 0.35))
        let d = dialogRect
        rr(d.minX, d.minY, d.width, d.height, 12, fill: rgb(0x34363e), stroke: rgb(0x555966))
        text("Allow desiredsite.com?", d.midX, d.minY + 30, size: 15, weight: .bold, center: true)
        text("Anything on this site, including scams, will be able to", d.midX, d.minY + 62, size: 11.5, color: muted, center: true)
        text("load in AdFree. Only add sites you trust.", d.midX, d.minY + 80, size: 11.5, color: muted, center: true)
        rr(d.minX + 24, d.maxY - 62, 150, 32, 7, fill: rgb(0x4a4d57)); text("Cancel", d.minX + 99, d.maxY - 46, size: 13, center: true)
        rr(d.maxX - 194, d.maxY - 62, 170, 32, 7, fill: blue); text("Allow desiredsite.com", d.maxX - 109, d.maxY - 46, size: 12.5, weight: .semibold, center: true)
    }
}

func drawFixPanel() {
    let r = CGRect(x: wx + 280, y: wy + 70, width: 560, height: 500)
    rr(wx, contentTop, ww, wy + wh - contentTop, 0, fill: rgb(0x000000, 0.45))
    rr(r.minX, r.minY, r.width, r.height, 12, fill: rgb(0x26272d), stroke: rgb(0x44464f))
    text("Ad got through?", r.minX + 24, r.minY + 34, size: 20, weight: .bold)
    let steps = [("1. Reload the page", "Fixes most one-off misses."), ("2. Reload the blocking files", "Re-reads the rules and scripts."),
                 ("3. Clear the page cache", "You stay signed in."), ("4. Run a diagnosis", "Copy the report to share it."),
                 ("5. Edit the scripts", "Settings → Scripts & rules.")]
    for (i, s) in steps.enumerated() {
        let y = r.minY + 80 + CGFloat(i) * 76
        rr(r.minX + 24, y, r.width - 48, 62, 8, fill: rgb(0x2f3138))
        text(s.0, r.minX + 40, y + 22, size: 14, weight: .semibold)
        text(s.1, r.minX + 40, y + 43, size: 12, color: muted)
    }
}

func drawCursor(_ p: CGPoint, t: Double) {
    for c in clicks where t >= c && t < c + 0.35 {
        let k = CGFloat((t - c) / 0.35)
        NSBezierPath(ovalIn: NSRect(x: p.x - 8 - 18 * k, y: p.y - 8 - 18 * k, width: 16 + 36 * k, height: 16 + 36 * k)).apply { $0.lineWidth = 2; NSColor.white.withAlphaComponent(1 - k).setStroke(); $0.stroke() }
    }
    let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 17), (4.5, 13), (8, 20), (10.5, 19), (7, 12), (12.5, 12)]
    let path = NSBezierPath(); path.move(to: NSPoint(x: p.x + pts[0].0, y: p.y + pts[0].1))
    for q in pts.dropFirst() { path.line(to: NSPoint(x: p.x + q.0, y: p.y + q.1)) }
    path.close(); NSColor.white.setFill(); path.fill(); NSColor.black.setStroke(); path.lineWidth = 1.2; path.stroke()
}
extension NSBezierPath { func apply(_ f: (NSBezierPath) -> Void) { f(self) } }

// MARK: Frame

func render(_ t: Double) {
    // Background and window chrome.
    bg.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
    rr(wx, wy, ww, wh, 12, fill: winBg, stroke: rgb(0x3a3d46))
    rr(wx, wy, ww, 28, 12, fill: rgb(0x2f3138)); rr(wx, wy + 14, ww, 14, 0, fill: rgb(0x2f3138))
    circle(wx + 18, wy + 14, 6, rgb(0xff5f57)); circle(wx + 38, wy + 14, 6, rgb(0xfebc2e)); circle(wx + 58, wy + 14, 6, rgb(0x28c840))
    text("AdFree", wx + ww / 2, wy + 14, size: 12.5, weight: .semibold, color: muted, center: true)

    let added = t >= 19.2
    let sites2 = [("youtube.com", "YouTube"), ("twitch.tv", "Twitch")]
    let sites3 = sites2 + [("desiredsite.com", "desiredsite.com")]
    let blockOn = !(t >= 27.5 && t < 29.0) // off only while the ad plays, on after the toggle click
    var host = "Home", count = t >= 29.4 ? 1 : 0
    var settings = false, fix = false

    switch t {
    case ..<5.0: drawHome(sites: sites2, highlight: nil, t: t)
    case ..<8.5: host = "www.youtube.com"; drawWatchPage(adVisible: false, blockOn: true, t: t, link: t > 7.8)
    case ..<21.9: host = "www.youtube.com"; drawThumbGrid(); settings = t >= 14.0 && t < 20.9
    case ..<25.0: drawHome(sites: sites3, highlight: t < 24.0 ? 2 : nil, t: t)
    case ..<27.5: host = "desiredsite.com"; drawPlaceholderSite()
    default:
        host = "www.youtube.com"
        count = t >= 29.4 ? 1 : 0
        drawWatchPage(adVisible: t < 29.0, blockOn: blockOn, t: t, link: false)
        fix = t >= 31.9
    }
    if t >= 5.0 && t < 5.4 { host = "Home" }
    drawToolbar(host: host, count: count, blockOn: blockOn, countFlash: t >= 29.4 && t < 30.2)
    if t >= 8.6 && t < 13.0 {
        rr(wx, wy + 72, ww, 30, 0, fill: amber.withAlphaComponent(0.28))
        text("Blocked a link to desiredsite.com. Only your allowed sites open here.", wx + ww / 2, wy + 87, size: 13, center: true)
    }
    if settings {
        var typed = ""
        let full = "desiredsite.com"
        if t >= 15.2 { typed = String(full.prefix(min(full.count, Int((t - 15.2) / 0.1) + 1))) }
        if t >= 19.2 { typed = "" }
        drawSettings(typed: typed, list: added ? ["youtube.com", "youtu.be", "twitch.tv", "desiredsite.com"] : ["youtube.com", "youtu.be", "twitch.tv"],
                     showDialog: t >= 17.8 && t < 19.2, t: t)
    }
    if fix { drawFixPanel() }

    // Caption bar, disclaimer, fades at hard cuts.
    for c in captions where t >= c.0 && t < c.1 {
        rr(wx, 640, ww, 48, 10, fill: rgb(0x111826), stroke: rgb(0x222d42))
        text(c.2, wx + ww / 2, 664, size: 17, weight: .medium, color: .white, center: true)
    }
    text("Illustration with placeholder sites. Not a screen recording.", wx + ww / 2, 703, size: 11, color: muted, center: true)
    drawCursor(cursor(at: t), t: t)
    for cut in [5.0, 8.5, 21.9, 25.0, 27.5, 31.9] where t >= cut && t < cut + 0.25 {
        bg.withAlphaComponent(CGFloat(1 - (t - cut) / 0.25) * 0.55).setFill(); NSRect(x: wx, y: wy, width: ww, height: wh).fill()
    }
}

// MARK: Encode

guard CommandLine.arguments.count == 2 else { print("usage: make-demo.swift <output.mp4>"); exit(1) }
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.removeItem(at: outURL)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_400_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let frames = Int(DURATION * Double(FPS))
for i in 0..<frames {
    while !input.isReadyForMoreMediaData { usleep(2000) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    let pb = buffer!
    CVPixelBufferLockBaseAddress(pb, [])
    let cg = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: W, height: H, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    cg.translateBy(x: 0, y: CGFloat(H)); cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    render(Double(i) / Double(FPS))
    NSGraphicsContext.restoreGraphicsState()
    CVPixelBufferUnlockBaseAddress(pb, [])
    adaptor.append(pb, withPresentationTime: CMTime(value: Int64(i), timescale: Int32(FPS)))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print(writer.status == .completed ? "wrote \(outURL.path)" : "failed: \(String(describing: writer.error))")
