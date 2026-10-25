# Artifact 3 log: a model inside AdFree

Extends Artifact 2 (AdFree) so that a model does part of the work. Plans first, then what changed.

## Plan 1: an AI chat inside the app (dropped)

Idea: a chat window in AdFree, using the user's own Anthropic API key, that reads the diagnostic
report and the scripts and proposes fixes when YouTube breaks the ad blocker. Per-site block lists
for sites added to the allow list. Built it: key in the Keychain, a chat window, tools to read the
report and propose edits, an Apply or Reject card for every change.

Why dropped: the assignment page says the Claude access we have covers Claude Code, not the API,
which bills each call. Options 1 to 3 run on the existing access; option 4 may cost money and needs
an instructor's OK. A feature that costs money every time it runs is the wrong shape for this
project, so the code was removed (never committed).

What it taught me: the useful part was never the chat window. It was the tools: a report, a page
snapshot, validated rules, and a safe way to apply a change.

## Plan 2: an MCP server (chosen)

Option 2 on the page: "an MCP server that gives Claude access to a tool or data source you use."
The data source is AdFree's state. Claude Code is the model, so there is no API key and no cost.

Decisions:
- **Model's job:** diagnose and write the fix. **Code's job:** validate input, restrict what can
  change, apply and log it. See `AdFree/mcp/README.md`.
- **Bridge between the sandboxed app and the server:** a file mailbox, not a network port. A
  listener on localhost can be reached by any local program or web page and needs a new
  entitlement. A mailbox needs neither.
- **Mailbox in `~/.adfree/bridge`, not inside the app's container:** first plan was the container,
  to avoid any sandbox change. I expected macOS to ask permission whenever another program reads
  an app's container, which is exactly the setup step I wanted to avoid. The cost is one narrow
  sandbox exception for one folder.
- **Node with no packages:** MCP over stdio is newline-delimited JSON-RPC, small enough to write
  directly. Nothing to `npm install`, and the server ships inside the app bundle.
- **Approval:** each change is applied immediately, because Claude Code asks for permission before
  each tool call. The app shows a banner saying what changed, and every change is undoable
  (Revert for scripts, Clear rules for sites). Weakness: if a user sets the write tools to "always
  allow", that human check is gone.

## What changed

- `AdFree/Sources/AdFree/BridgeService.swift`: the app side of the mailbox (polls requests, answers, heartbeat).
- `AdFree/mcp/server.js`: the MCP server (10 tools, validation, audit log).
- `AdFree/mcp/test.js`: 16 checks against a mock app.
- Per-site rules (`SiteRuleSet` in `BrowserModel.swift`): hidden selectors and blocked URL patterns
  per allowed site, checked by WebKit before they are saved so a bad rule cannot break existing blocking.
- Settings → Claude Code tab (`ClaudeConnection.swift`, `SettingsView.swift`):
  - **Status check:** reads Claude Code's user config `~/.claude.json` and reports one of four states: not connected, connected to this copy, connected to a different copy (for example the app moved), or settings file unreadable.
  - **Command by state:** not connected shows `claude mcp add`; a different copy or unreadable shows `claude mcp remove` then `add`, which works whether or not an old entry exists.
  - **Connected:** no add or remove. The tab leads with "Work with Claude Code on AdFree", which starts `claude` with a first message telling it to call `list_sites` and ask which site or ads to handle. Check (`claude mcp get adfree`) and reset stay below it.
  - **Open Terminal here:** opens Terminal in the folder that holds AdFree.app and runs the command. Copy command is the fallback.
  - First version showed nothing when connected, because it only displayed a command when a fix was needed. Found by using it; fixed by always offering options per state.
- `AdFree.entitlements`: read/write for `~/.adfree/` only; read-only `~/.claude.json`; Apple events to Terminal only (plus `NSAppleEventsUsageDescription`). Each is the narrowest exception that does the job. Terminal control is the largest: a compromised app could run commands there, so the buttons only run commands the tab shows.
- `AdFree/.mcp.json`: registers the server when Claude Code runs from the `AdFree` folder. I first
  put it at the repo root, which meant Claude Code started with the whole repository, including other
  artifacts, in reach. Moving the server config into `AdFree/` and starting Terminal there (the tab
  looks upward from AdFree.app for the nearest `.mcp.json`) limits Claude Code's working folder to
  AdFree and its files. Least access applied to the model's workspace, not just to the app.
- `build.sh`: bundles the server into the app.

## Verification so far

- `node AdFree/mcp/test.js`: 16 of 16 checks pass (against a mock app, not the real one).
- The app builds, is signed with the sandbox entitlement, and the helper keeps its own.
- The Claude Code tab builds and signs with the new entitlements (checked in the built app).
- Not yet verified: the real app and Claude Code talking through the mailbox end to end; the macOS Automation prompt for Terminal; that `~/.claude.json` keeps user-wide servers under `mcpServers` on every install (it did on my machine, where the status check showed the existing connection).

## Open

- Run the end-to-end check and record a demo.
- Whether to keep write tools behind a stricter approval.
- The reflection (mine to write).
