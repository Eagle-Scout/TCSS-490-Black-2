# AdFree MCP server

Lets Claude Code look at AdFree and fix its ad blocking. AdFree itself makes no AI calls and
needs no API key: the model is Claude Code, running on your existing Claude Code login.

## What the model does, and what the code checks

| | Responsible for |
|---|---|
| **Claude Code (the model)** | Reads the report, the page structure and the scripts. Decides what is wrong. Writes the fix: block rules for a site, or an edit to a script. Says whether a fresh report shows the fix worked. |
| **`server.js` (plain code)** | Speaks MCP. Allows only four named files and ten named tools. Checks every input before it goes anywhere: domain format, selector and pattern characters and lengths, file size, JSON validity, JavaScript syntax. Writes an audit log of every change. |
| **The app (plain code)** | Checks the same inputs again. Has WebKit compile the rules before saving anything. Applies the change, reloads the page, and tells the user what changed. Every change can be undone. |

If something goes wrong, the split tells you where to look: a bad idea is the model's, a
rejected input is the server's, a rule WebKit refuses is the app's.

## Connect (what a user does)

1. Install [Node.js](https://nodejs.org) and Claude Code.
2. Open AdFree → Settings → **Claude Code** and click **Copy command**, then run it once in Terminal.
   It looks like:
   ```
   claude mcp add adfree --scope user -- node "/path/to/AdFree.app/Contents/Resources/mcp/server.js"
   ```
   The server ships inside the app, so there is nothing else to download or `npm install`.
3. Keep AdFree open. In Claude Code, ask something like *"YouTube is showing the ad-blocker wall, check AdFree."*

From a clone of this repo, `AdFree/.mcp.json` registers the server for Claude Code instead
(Claude Code asks you to approve it the first time). If you move the app, run the command again.

## Tools

| Tool | Changes something? | What it does |
|---|---|---|
| `get_report` | no | Diagnostic report for the open page |
| `get_page_snapshot` | no | Page structure: third-party hosts, candidate ad elements. No page text |
| `list_sites` | no | Allowed sites, their rule counts, which layers are on |
| `read_file` | no | A rule or script file |
| `open_site` | no | Opens an allowed site and waits for it to load |
| `set_site_rules` | yes | Replaces one site's hidden selectors and blocked URL patterns |
| `clear_site_rules` | yes | Removes one site's rules |
| `write_file` | yes | Replaces a rule or script file (as a custom copy) |
| `revert_file` | yes | Goes back to the built-in file |
| `set_layer` | yes | Turns a blocking layer on or off, including the yt-dlp backup player |

## How it talks to the app

A file mailbox in `~/.adfree/bridge`: the server writes `requests/<id>.json`, the app answers with
`responses/<id>.json`, and the app refreshes `status.json` every two seconds so the server can say
"AdFree is not running". There is no network listener, so the app keeps its sandbox. The one extra
sandbox permission is read/write access to `~/.adfree/`. Every write also goes to
`~/.adfree/bridge/audit.log`.

## Safety notes

- Page content, reports and script text are untrusted data and could contain instructions aimed at
  the model. The server's instructions tell the model to ignore them; Claude Code's own permission
  prompt for each tool call is the human check. Don't set write tools to "always allow" unless you accept that.
- Site rules are declarative only (hide and block). Nothing the model writes for another site runs as JavaScript.
- Script edits are saved as custom copies; the built-in files are never modified.

## Tests

```
node AdFree/mcp/test.js
```
Starts the server against a mock app and checks the handshake, the tool list, the "app not running"
error, that bad input is rejected *before* it reaches the app, and that writes are audited without
their content. It does not test the real app or Claude Code.

## Troubleshooting

- *"AdFree is not running"*: open the app. The status file must be under eight seconds old.
- *Claude Code can't start the server*: it needs `node` on the PATH it uses. If Node is installed through nvm, put the full path to `node` in the command.
- *A change did nothing*: check Settings → Scripts & rules for a stale custom copy, and Settings → Blocking for a layer that is off.
