# General log

Work that isn't tied to one artifact (portfolio site, README, tooling, setup).

## Removed placeholder text from README

- **Change:** Deleted the line `PLACEHOLDER TEXT (TO BE REMOVED)` and its blank line from the top of `README.md`.
- **Reason:** The user asked for it. The line was a leftover marker, not content.
- **Not changed:** The empty `## Artifact 4 - BetterFood` and `## Artifact 5 - ...` headings. They may also be placeholders; left for the user to decide.
- **Not committed:** Left uncommitted. Git is disabled for this project, so the diff could not be checked.
- **Mistake:** The decision was not logged when it was made. It was logged here after the user updated CLAUDE.md to add this log.

## Artifact 4 check-in text added to the portfolio

- **Change:** In `docs/script.js`, the Artifact 4 entry is renamed from "BetterFood" to "GitHub Pull Request (in progress)". The user's check-in paragraph is pasted word for word into `desc`.
- **Reason:** The group is leaning toward a GitHub PR and is still choosing a repository. The BetterFood name and description no longer matched. The user approved the rename.
- **Deviation from the approved plan:** The plan said `tbd: false` with the text in `overview`. On reading the render code, `tbd: false` would show a green "Complete" chip and change the home stat to 4/5 complete, which is wrong for a check-in. I kept `tbd: true` and put the text in `desc`. That shows it on the card and on the detail page with "// in progress", and in the terminal's `status.txt`. I should have read the render code before writing the plan.
- **Kept as written:** The user's sentence has a small grammar slip ("and am spending time"). Pasted unchanged because the user asked for copy and paste.
- **Not changed:** `team` stays 0 (unknown), `tags`, `link` and `resources` stay empty, and the README's `## Artifact 4 - BetterFood` heading is untouched.
- **No LOG4.md:** Not created. The user has not approved a new artifact log.

## "In progress" status for portfolio artifacts

- **Change:** Replaced the `tbd` true/false flag in `PROJECTS` with `status: "complete" | "progress" | "tbd"`. Edited `docs/script.js` (data, card, stats, detail page), `docs/styles.css` (amber chip and card label), and `docs/terminal.js` (only `"tbd"` gets the `status.txt` stub).
- **Reason:** The user did not want a two-state flag. The check-in for Artifact 4 is neither finished nor an empty placeholder, and the earlier workaround (`tbd: true` with the text in `desc`) gave a dim, unclickable card. The user approved the plan and the amber colour, which already existed as `--amber`.
- **Behaviour:** `progress` cards are clickable and show "group · in progress" in amber. The detail page shows an amber "In progress" chip, the reflection placeholder, and the overview (falling back to `desc`). The terminal shows the full file set. The "N/5 complete" stat counts only `complete`, so it stays 3/5.
- **Artifact 4:** Now `status: "progress"`, named "GitHub Pull Request" (the "(in progress)" suffix was dropped since the chip says it). The user's paragraph is still in `desc`, unchanged.
- **Checked:** `node --check` passes on `script.js` and `terminal.js`, and no `tbd` flag uses remain. Not checked: the rendered page, which is left to the user's checklist.

## Fixed grammar in the Artifact 4 text

- **Change:** In the Artifact 4 `desc` in `docs/script.js`, "and am spending" is now "and are spending".
- **Reason:** The user asked for it. I had pasted the original unchanged and asked whether to fix it; the user fixed the wording here.
- **Mistake:** I called the paragraph "word for word" in the earlier entries. That was true when written, but those entries now describe the text before this fix.
