---
editor_options: 
  markdown: 
    wrap: 72
---

# Artifact 1 — Project Portfolio

## Devlog

------------------------------------------------------------------------

### What I set out to build

A portfolio site for TCSS 490 that holds all five artifacts as cards,
looks good, and can be submitted as a live link. No specific design in
mind going in — I described the vibe (dark, techy) and let Claude
propose the structure.

In a second Claude Code session I connected Claude to the GitHub repo
and added a **working terminal** to the site. The home page had a
decorative terminal that just played a scripted typing animation. I
wanted one where I could type `ls` and `cd` to move between pages, with
a smaller version available on every other page.

------------------------------------------------------------------------

### What I asked for and what changed

#### Part 1: Building the site

**Initial build** Asked for a dark, techy project card grid. Claude
asked a few clarifying questions about style and sections before
building. Got a working single-page site with a card grid, terminal
animation, stats bar, and filter buttons.

**Rebranding** The first version had "Every line written by AI" as the
hero heading and a "100% AI-written code" stat. I redirected this — the
site should look like a standard portfolio, not a showcase of AI
authorship. Changed the headline to "TCSS 490 / Project Portfolio" and
reframed the stats around artifact count and course info.

**Expanding the site** Asked for a home page, a hamburger menu, and
individual pages per artifact. This led to a discussion about how to
structure it. Decided on a single-file SPA with hash-based routing
rather than separate HTML files — one `index.html`, three views (Home,
Artifacts, detail), JavaScript handles which one is visible.

**Spec check** Pulled up the course spec mid-build. Found gaps: no About
page, no reflection field per artifact, no link field per artifact, no
log file. Added all of these in one pass.

**Personal content** Filled in name, major, bio, and artifact ideas
directly in the JS file. Ran into two issues pushing to GitHub:
`index.html` had been opened in Mac TextEdit, which re-saved it as an
old HTML 4.01 format and broke the whole page. Also had `tags: [TBD]` in
the data, which JavaScript read as an undefined variable and crashed the
script before anything rendered. Both fixed.

**Nav not updating** After changing artifact names in the JS, the
hamburger menu still showed old names. The nav items were hardcoded in
`index.html` — two places to maintain. Fixed by generating the nav from
the `PROJECTS` array at runtime, so the JS is the single source of
truth.

**GitHub Pages** Files were in a `/files` folder; Pages was set to serve
from `/docs`. Site returned 404. Renamed the folder to match.

#### Part 2: Claude Code session (interactive terminal)

**Connecting the repo** Asked how to connect Claude to a GitHub repo.
Claude cloned the public repo to `~/Documents/GitHub`, moved the session
into that folder, and walked through how the site is built. I later
asked how the single HTML, JS and CSS setup switches pages, and got an
explanation of hash routing: one `index.html` with four page sections,
JavaScript showing one at a time based on the URL hash, and all content
generated from the `PROJECTS` array.

**Checking the devlog** Asked Claude to recheck the repo after I added
`LOG.md`. It confirmed the file is served by GitHub Pages as raw
Markdown at its own URL, and that nothing on the site links to it. Along
the way Claude wrongly reported a stray `---` at the end of the file.
That came from its own `echo` separators in the command, not from my
file. Claude caught the mistake when I asked for the line to be removed.

**Editing safely** After the TextEdit problem in part 1, I switched to
VSCodium. Claude suggested: preview locally with
`python3 -m http.server 8000 --directory docs`, commit in small steps,
and use a branch so `main` and the live site stay untouched until I'm
ready.

**Linking the devlog** Added `LOG.md` to Artifact 1's Resources list.
First I kept the change local because I wasn't sure whether to link to
GitHub or to an in-portfolio page. Later I decided on the GitHub page,
and asked for it to open in a new tab. That is done in the shared
resource template, so all resource links open in a new tab.

**Designing the terminal** Claude judged it feasible, since everything
runs in the browser and the router is already one function. I chose a
few things: - A fake filesystem generated from `PROJECTS`, so it never
goes stale. - Open as a large terminal on Home, closed with a toggle
button on other pages, and a mini panel when opened. - Desktop first. On
phones the input line is hidden (no soft keyboard) and the Commands menu
does the typing. - A Commands
dropdown that types the command into the terminal for you. - A
boot-sequence intro that replaces the old typing animation, with the
"type help" hint as part of the boot.

**First build and my first review round** Claude built `terminal.js`
plus the CSS and a small HTML change, and tested it in the preview
browser. My feedback: - The prompt should stay at the bottom when the
output scrolls. - The Commands dropdown should be at the top, and styled
for the portfolio rather than my device's default menu. - The page
bounced when I scrolled hard past the top or bottom, so the header or
footer slid away and showed the background.

Claude moved the menu to a custom Commands button in the title bar, and
turned off elastic overscroll on the page.

**Second round** - Docking wasn't what I imagined, so I had it removed
and kept the mini panel plus the closed toggle button. - Folders should
accept project names or artifact numbers. Claude added aliases so
`cd artifact_2`, `artifact2`, `adblock`, `blocker` and
`project portfolio` all work.

**Third round** - The terminal itself had elastic overscroll and a gap
between the output and the prompt. The gap turned out to come from stray
whitespace in the markup, because the old terminal style preserved line
breaks. Claude fixed that and made the prompt follow the output, then
stick to the bottom once it scrolls. Overscroll is now off inside the
terminal too. - The prompt showed the full path. It now shows only the
current folder, like `~$` or `artifact_1$`. - I found a bug: I could
`cd artifact_1` from About but not go from artifact 1 to About. The
aliases had been working from anywhere. They now only work from inside
`~/artifacts`, like sibling folders.

**Mobile and the Commands menu**
I wanted phones to be able to use the terminal without a keyboard. Claude turned the Commands menu on for phones, hid the input line so the soft keyboard never opens, and let the terminal float on other pages as it does on desktop. After a `clear` the phone terminal looked empty, so I had a blinking prompt put back in as a stand-in for the input.

**New commands and a device-aware `help`**
Asked for an `echo` command. Claude added it as desktop only, since it needs a keyboard, and it isn't in the Commands menu. That led to `help` changing by device: desktop lists every command, and phones list only what the menu can run (`ls`, `cd`, `tree`, `clear`, `help`), so `cat`, `open` and the like don't show up.

**Home URL** The bare site link had no hash, but navigating to Home
added `#home`. Fixed so a bare URL gets `#home` automatically, without
adding a back-button entry.

**Updating the entry and README**
A lot had changed since the Artifact 1 entry was written, so I had its description and overview rewritten to describe the site as it is now, including the terminal. The README's empty Artifact 1 section now has a summary and a section on how the terminal works.

**Publishing** Asked how to push the branch. Claude explained `git add`,
`git commit` and `git push -u origin interactive-terminal`. The branch
is on GitHub. The live site updates only after it's merged into `main`.

------------------------------------------------------------------------

### What I decided

-   Single-file SPA over separate HTML pages per artifact — easier to
    deploy, no duplication of the header and nav across files
-   Cards navigate to a full detail page rather than expanding inline —
    gives each artifact more room as they get filled in
-   `script.js` as the only file that needs editing day-to-day for
    content — names, descriptions, reflections, and links all live
    there; `index.html` and `styles.css` stay untouched once personal
    info is set
-   A **simulated** terminal in the browser, with no real shell access.
    It's safe, and it needs no backend.
-   Generate the terminal's filesystem from `PROJECTS`, so it updates
    automatically when I add artifacts.
-   Keep the real folder names descriptive (`artifact_2_ad_blocker`) and
    let short names resolve as aliases.
-   A shell-like prompt that shows only the current folder. `pwd` still
    prints the full path.
-   Aliases only work from inside `~/artifacts`. Absolute-path jumps
    like `cd ~/about` are intentionally allowed from anywhere, as in a
    real shell.
-   `echo` is desktop only, and `help` lists commands by device, so phones
    don't see commands they can't run.
-   On phones, the Commands menu is the way to use the terminal. The
    input line is hidden and a blinking prompt stands in for it, so the
    soft keyboard never pops up. Desktop keeps the typed input.
-   The devlog link points to the GitHub page and opens in a new tab.
-   Always show `#home` in the URL, instead of never showing it, because
    it was a one-line change and every Home link already used that form.
-   Work on a branch so the live site stays untouched until I decide to
    merge.

------------------------------------------------------------------------

### What I abandoned

-   "Every line written by AI" framing — cut early, doesn't serve the
    portfolio's purpose
-   Inline card expansion with a "Show the prompt" toggle — replaced
    with full detail pages
-   `tags: [TBD]` as a placeholder — not valid JavaScript; switched to
    empty arrays `[]` until real tags are known
-   Separate `.html` files per artifact — abandoned in favor of a
    single-file SPA
-   **Docking the terminal** to the bottom of every page. I wanted a
    different layout, so the dock button and its code were removed.
-   A **native dropdown** at the bottom of the terminal, replaced by a
    styled Commands button at the top.
-   Showing the **full command text** next to each menu item. It got cut
    off, so the menu shows labels only.
-   The **typing-animation** terminal on the home page.
-   Short folder names that work **from anywhere**. They allowed jumps
    like About to Artifact 1 that a real shell wouldn't allow.
-   A **full path** in the prompt.
-   The **local-only** devlog link, which I replaced with the GitHub
    link.
-   Hiding `#home` from the URL, since it meant rewriting more links.

------------------------------------------------------------------------

### Things still open

-   Merging `interactive-terminal` into `main` so the terminal goes
    live.
