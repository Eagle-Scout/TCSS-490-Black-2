# Artifact 1 — Project Portfolio
## Devlog

---

### What I set out to build

A portfolio site for TCSS 490 that holds all five artifacts as cards, looks good, and can be submitted as a live link. No specific design in mind going in — I described the vibe (dark, techy) and let Claude propose the structure.

---

### What I asked for and what changed

**Initial build**
Asked for a dark, techy project card grid. Claude asked a few clarifying questions about style and sections before building. Got a working single-page site with a card grid, terminal animation, stats bar, and filter buttons.

**Rebranding**
The first version had "Every line written by AI" as the hero heading and a "100% AI-written code" stat. I redirected this — the site should look like a standard portfolio, not a showcase of AI authorship. Changed the headline to "TCSS 490 / Project Portfolio" and reframed the stats around artifact count and course info.

**Expanding the site**
Asked for a home page, a hamburger menu, and individual pages per artifact. This led to a discussion about how to structure it. Decided on a single-file SPA with hash-based routing rather than separate HTML files — one `index.html`, three views (Home, Artifacts, detail), JavaScript handles which one is visible.

**Spec check**
Pulled up the course spec mid-build. Found gaps: no About page, no reflection field per artifact, no link field per artifact, no log file. Added all of these in one pass.

**Personal content**
Filled in name, major, bio, and artifact ideas directly in the JS file. Ran into two issues pushing to GitHub: `index.html` had been opened in Mac TextEdit, which re-saved it as an old HTML 4.01 format and broke the whole page. Also had `tags: [TBD]` in the data, which JavaScript read as an undefined variable and crashed the script before anything rendered. Both fixed.

**Nav not updating**
After changing artifact names in the JS, the hamburger menu still showed old names. The nav items were hardcoded in `index.html` — two places to maintain. Fixed by generating the nav from the `PROJECTS` array at runtime, so the JS is the single source of truth.

**GitHub Pages**
Files were in a `/files` folder; Pages was set to serve from `/docs`. Site returned 404. Renamed the folder to match.

---

### What I decided

- Single-file SPA over separate HTML pages per artifact — easier to deploy, no duplication of the header and nav across files
- Cards navigate to a full detail page rather than expanding inline — gives each artifact more room as they get filled in
- `script.js` as the only file that needs editing day-to-day — names, descriptions, reflections, and links all live there; `index.html` and `styles.css` stay untouched once personal info is set

---

### What I abandoned

- "Every line written by AI" framing — cut early, doesn't serve the portfolio's purpose
- Inline card expansion with a "Show the prompt" toggle — replaced with full detail pages
- `tags: [TBD]` as a placeholder — not valid JavaScript; switched to empty arrays `[]` until real tags are known
- Separate `.html` files per artifact — abandoned in favor of a single-file SPA
