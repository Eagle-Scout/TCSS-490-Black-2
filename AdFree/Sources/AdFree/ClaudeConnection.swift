import AppKit
import Foundation

/// What Claude Code's user-wide config says about AdFree's MCP server.
enum ConnectionState: Equatable {
    case notConnected
    case connected
    /// An entry exists but points at another copy of the server (for example, the app was moved).
    case stale(points: String)
    /// Claude Code's config exists but could not be parsed.
    case unreadable
}

/// Reads Claude Code's user config (~/.claude.json) and builds the commands that fix it.
///
/// The sandboxed app cannot run `claude` itself, so the check reads the config file (read-only,
/// via a one-file sandbox exception). Changes are made by a command the user runs in Terminal.
enum ClaudeConnection {
    static let serverName = "adfree"

    static var serverPath: String { BridgeService.serverPath }
    static var configURL: URL { BridgeService.realHome.appendingPathComponent(".claude.json") }

    static func status() -> ConnectionState {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return .notConnected }
        guard let data = try? Data(contentsOf: configURL),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return .unreadable }
        guard let servers = root["mcpServers"] as? [String: Any],
              let entry = servers[serverName] as? [String: Any] else { return .notConnected }
        let args = entry["args"] as? [String] ?? []
        let command = entry["command"] as? String ?? ""
        if command.hasSuffix("node") && args.contains(serverPath) { return .connected }
        return .stale(points: args.last ?? "an unknown location")
    }

    static var addCommand: String {
        "claude mcp add \(serverName) --scope user -- node \"\(serverPath)\""
    }

    /// Remove first, then add: works whether or not an old entry exists, and leaves exactly one.
    static var resetCommand: String {
        "claude mcp remove \(serverName) --scope user; \(addCommand)"
    }

    /// A command offered for a state, with a heading and a one-line explanation.
    struct Option: Identifiable {
        let title: String
        let command: String
        let note: String
        var primary = false
        var id: String { title }
    }

    /// Always at least one option, so the Terminal and Copy buttons are never missing.
    static func options(for state: ConnectionState) -> [Option] {
        let check = Option(title: "Check the connection", command: "claude mcp get \(serverName)",
                           note: "Shows what Claude Code has saved for AdFree and whether it can start the server.")
        let reset = Option(title: "Reset the connection", command: resetCommand,
                           note: "Removes the old entry, then adds one that points at this copy of AdFree.")
        let start = Option(title: "Work with Claude Code on AdFree",
                           command: "claude \"Use the adfree tools. Start with list_sites, then ask me which site I want to add or which ads I want blocked, and propose small, undoable rules.\"",
                           note: "Starts Claude Code with a first message. It asks your permission before each tool call, and every change can be undone.",
                           primary: true)
        switch state {
        case .connected:
            return [start, check, reset]
        case .notConnected:
            return [Option(title: "Connect Claude Code", command: addCommand,
                           note: "Adds AdFree's server to Claude Code for your user account.")]
        case .stale, .unreadable:
            return [reset, check]
        }
    }

    /// The project folder Claude Code should start in: the nearest folder above AdFree.app that holds a
    /// `.mcp.json` (so the project's AdFree server is found), else the folder that holds the app.
    static var terminalFolder: String {
        let appFolder = Bundle.main.bundleURL.deletingLastPathComponent()
        var dir = appFolder
        while dir.path != "/" {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent(".mcp.json").path) { return dir.path }
            dir = dir.deletingLastPathComponent()
        }
        return appFolder.path
    }

    /// Opens Terminal in `terminalFolder` and runs `command` there.
    /// Returns an error message, or nil on success.
    static func openTerminal(running command: String) -> String? {
        let folder = terminalFolder
        let shell = "cd \(shellQuote(folder)) && \(command)"
        let source = "tell application \"Terminal\"\nactivate\ndo script \(appleScriptString(shell))\nend tell"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard let error else { return nil }
        if (error[NSAppleScript.errorNumber] as? Int) == -1743 {
            return "macOS blocked AdFree from controlling Terminal. Allow it in System Settings → Privacy & Security → Automation, or copy the command and paste it yourself."
        }
        return (error[NSAppleScript.errorMessage] as? String) ?? "Couldn't open Terminal."
    }

    private static func shellQuote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptString(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
