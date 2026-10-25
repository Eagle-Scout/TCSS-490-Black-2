/* =========================================================
   TCSS 490 — Project Portfolio
   script.js
   ========================================================= */

/* ── Data ──────────────────────────────────────────────────────
   Edit PROJECTS to update the site. Fields:
     artifact   number   artifact number (1–5)
     name       string   project title
     type       string   "solo" | "group" | "mega"
     team       number   team size (0 = unknown)
     tags       array    tech stack labels ["HTML", "CSS", ...]
     featured   bool     true → spans full width on home / artifacts
     tbd        bool     true → renders as a dim placeholder
     desc       string   one- or two-sentence summary (shown on card)
     reflection string   a few sentences on how it went (shown on detail page)
     link       string   URL to the live artifact (empty = hidden)
     overview   string   longer description for the detail page
     resources  array    [{ label, url }] — GitHub, docs, etc.
     video      object   optional { src, caption } — embedded on the detail page
─────────────────────────────────────────────────────────────── */
const PROJECTS = [
  {
    artifact: 1,
    name: "Project Portfolio",
    type: "solo",
    team: 1,
    tags: ["HTML", "CSS", "JavaScript"],
    featured: true,
    tbd: false,
    desc: "A portfolio site cataloging five TCSS 490 artifacts over Autumn 2026, with a page about the author and a working terminal you can use to browse it.",
    reflection: "The biggest challenge was understanding what it was I wanted to do after every prompt and iteration. What I would do differently is probably start off the chat by showing Claude the course page for the artifact and going from there, rather than trying to build a portfolio to match. Interestingly enough, the portfolio differs from my expectation, where instead of multiple .html files, there's only one. The CSS and JS dictate what shows up on the page at any given time.",
    link: "https://eagle-scout.github.io/TCSS-490-Black-2/",
    overview: "Built as Artifact 1. A static single-page application using hash-based client-side routing — no build step required. Includes a home page, an About page, a filterable artifact grid, and per-artifact detail pages, all within one HTML file and generated from one PROJECTS array. It also has an interactive terminal: a simulated shell whose filesystem is built from that same array, so ls, cd and cat move around the site and every folder matches a page. On desktop you type commands (help lists them all); on phones the input is hidden and a Commands menu runs navigation commands instead, so no keyboard is needed. The devlog is linked in the resources below.",
    resources: [
      { label: "Devlog (LOG.md)", url: "https://github.com/Eagle-Scout/TCSS-490-Black-2/blob/artifact-3/logs/LOG.md" }
    ]
  },
  {
    artifact: 2,
    name: "AdFree — Ad Blocker",
    type: "solo",
    team: 1,
    tags: ["Swift", "SwiftUI", "WebKit", "JavaScript"],
    featured: false,
    tbd: false,
    desc: "A native macOS app that opens YouTube and Twitch with ad blocking built in, and only those sites, so I can avoid ads even when they change their code.",
    reflection: "My intention with the class was that Claude would do a majority of the work, while I would push things to github, do version control, and be a project manager. The difficult part with this artifact was that Claude pushed to github multiple times. I had not explicitly stated for it to not do so, however it was a nightmare trying to revert changes and commits that I did not want or approve of. Eventually figured it out, and now I have pull requests turned on.",
    link: "https://github.com/Eagle-Scout/TCSS-490-Black-2/tree/artifact-3/AdFree",
    overview: "Built as Artifact 2. A sandboxed macOS app: a SwiftUI window around a WKWebView, so it is the real YouTube and Twitch with my own Google sign-in. Blocking has three layers: network rules that block ad hosts and hide ad slots, a YouTube script that strips ad data from player responses, and a Twitch script that filters ad segments out of the video playlist. Only an editable list of allowed sites will open, with a home page that mirrors that list, an in-app editor for the blocking scripts, an ads-skipped counter, and an Ads showing? panel that walks through fixes when something breaks. The usage guide covers installing, using and modifying it.",
    video: {
      src: "media/adfree-demo.mp4",
      caption: "A 40-second illustration of AdFree: the home page, a blocked link, adding a site, blocking an ad, and the fix panel. Placeholder sites; generated, not a screen recording."
    },
    resources: [
      { label: "Usage guide", url: "#adfree-manual" },
      { label: "Devlog (LOG2.md)", url: "https://github.com/Eagle-Scout/TCSS-490-Black-2/blob/artifact-3/logs/LOG2.md" }
    ]
  },
  {
    artifact: 3,
    name: "AdFree Continued — AI Inside",
    type: "solo",
    team: 1,
    tags: ["Swift", "SwiftUI", "Node.js", "MCP", "Claude Code"],
    featured: false,
    tbd: false,
    desc: "AdFree again, with Claude Code inside the workflow: an MCP server lets it read the app's report and change block rules and scripts when a site breaks, with every change checked by code and undoable.",
    reflection: "",
    link: "https://github.com/Eagle-Scout/TCSS-490-Black-2/tree/artifact-3/AdFree",
    overview: "Built as Artifact 3, on top of AdFree. The first plan was a chat window in the app using the user's own API key, which I built and then dropped because API calls bill per use and the course access covers Claude Code, not the API. The kept version is an MCP server (plain Node, no packages) that Claude Code runs, so the model is Claude Code and there is no key and no cost. It has 10 tools: read the diagnostic report and a page snapshot, list sites, read and write the blocking scripts and rules, set per-site block rules, toggle layers, and revert. The model diagnoses and writes the fix; code validates every input, restricts what can change, applies it and logs it. The sandboxed app and the server talk through a file mailbox in ~/.adfree, not a network port, so the app needs only one narrow folder exception. Settings has a Claude Code tab that checks whether AdFree is already connected, shows the right add or reset command, and opens Terminal in the AdFree folder to run it or to start a working session. Every change shows a banner and can be undone. The log covers the plans, the trade-offs and what is still unverified.",
    resources: [
      { label: "Devlog (LOG3.md)", url: "https://github.com/Eagle-Scout/TCSS-490-Black-2/blob/artifact-3/logs/LOG3.md" },
      { label: "MCP server README", url: "https://github.com/Eagle-Scout/TCSS-490-Black-2/blob/artifact-3/AdFree/mcp/README.md" }
    ]
  },
  {
    artifact: 4,
    name: "BetterFood",
    type: "group",
    team: 0,
    tags: [],          // add tech stack once known
    featured: false,
    tbd: true,
    desc: "A phone app that identifies what it's pointed at, whether it's edible, and how unhealthy it is based on a ranking of possible ingredients from worst to healthiest.",
    reflection: "",
    link: "",
    overview: "",
    resources: []
  },
  {
    artifact: 5,
    name: "Straw in a Needle Pile",
    type: "mega",
    team: 0,
    tags: [],
    featured: false,
    tbd: true,
    desc: "A PC game to be released on Steam — or maybe it's just finding a single strand of hay in a pile of needles.",
    reflection: "",
    link: "",
    overview: "",
    resources: []
  }
];

const TL = { all: "all", solo: "solo", group: "group", mega: "mega group" };

/* ── Helpers ──────────────────────────────────────────────── */
const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const pad = n => String(n).padStart(2, "0");
const $   = id => document.getElementById(id);
const isPlaceholder = s => !s || s.startsWith("[");

/* ── Drawer ───────────────────────────────────────────────── */
const hamburger = $("hamburger");
const overlay   = $("overlay");
const drawer    = $("drawer");

const openDrawer  = () => {
  hamburger.classList.add("open");
  hamburger.setAttribute("aria-expanded", "true");
  overlay.classList.add("open");
  drawer.classList.add("open");
};
const closeDrawer = () => {
  hamburger.classList.remove("open");
  hamburger.setAttribute("aria-expanded", "false");
  overlay.classList.remove("open");
  drawer.classList.remove("open");
};

hamburger.onclick         = () => drawer.classList.contains("open") ? closeDrawer() : openDrawer();
overlay.onclick           = closeDrawer;
$("drawer-close").onclick = closeDrawer;

/* ── Router ───────────────────────────────────────────────── */
const pages = document.querySelectorAll(".page");

function navigate(raw) {
  const hash = raw || "#home";
  closeDrawer();

  let pid = "page-home";
  if (hash === "#about") {
    pid = "page-about";
    renderAboutGrid();
  } else if (hash === "#artifacts") {
    pid = "page-artifacts";
    renderArtGrid();
  } else if (hash === "#adfree-manual") {
    pid = "page-manual";
  } else if (/^#artifact-\d+$/.test(hash)) {
    const n = parseInt(hash.replace("#artifact-", ""), 10);
    renderDetail(n);
    pid = "page-detail";
  }

  pages.forEach(p => p.classList.toggle("active", p.id === pid));

  // The manual has no menu entry of its own; highlight its parent artifact instead.
  const navHash = hash === "#adfree-manual" ? "#artifact-02" : hash;
  document.querySelectorAll("[data-nav]").forEach(a =>
    a.classList.toggle(
      "active",
      "#" + a.dataset.nav === navHash || (navHash === "#home" && a.dataset.nav === "home")
    )
  );

  window.scrollTo({ top: 0, behavior: "instant" });

  const m    = /^#artifact-(\d+)$/.exec(hash);
  const proj = m ? PROJECTS.find(x => x.artifact === parseInt(m[1])) : null;
  document.title =
    proj                  ? `Artifact ${pad(proj.artifact)} — TCSS 490` :
    hash === "#about"     ? "About — TCSS 490"                          :
    hash === "#artifacts" ? "Artifacts — TCSS 490"                      :
    hash === "#adfree-manual" ? "AdFree Manual — TCSS 490"              :
                            "TCSS 490 — Project Portfolio";
}

window.addEventListener("hashchange", () => navigate(location.hash));

/* ── Card template ────────────────────────────────────────── */
function cardHTML(p, showFeat) {
  const feat = showFeat && p.featured ? " feat" : "";
  const nav  = `#artifact-${pad(p.artifact)}`;

  const ia = !p.tbd
    ? `tabindex="0" role="link"
       aria-label="View Artifact ${pad(p.artifact)}: ${esc(p.name)}"
       onclick="navigate('${nav}')"
       onkeydown="if(event.key==='Enter'||event.key===' '){event.preventDefault();navigate('${nav}')}"`
    : "";

  return `<article class="card${feat}${p.tbd ? " tbd" : ""}" data-t="${p.type}" ${ia}>
    <div class="card-meta">
      <span>Artifact ${pad(p.artifact)}</span>
      <span class="ctype">${p.tbd ? "—" : TL[p.type]}</span>
    </div>
    <h3 class="card-name">${esc(p.name)}</h3>
    <p class="card-desc${isPlaceholder(p.desc) ? " ph" : ""}">${esc(p.desc)}</p>
    ${p.tags.length
      ? `<div class="tags">${p.tags.map(t => `<span>${esc(t)}</span>`).join("")}</div>`
      : ""}
    ${!p.tbd && p.link
      ? `<a class="view-btn" href="${esc(p.link)}" target="_blank" rel="noopener"
           onclick="event.stopPropagation()">View artifact ↗</a>`
      : ""}
  </article>`;
}

/* ── Home page ────────────────────────────────────────────── */
const complete = PROJECTS.filter(p => !p.tbd).length;

$("stats").innerHTML = [
  ["5",             "artifacts"],
  [`${complete}/5`, "complete"],
  ["TCSS 490",      "course"]
].map(([n, l]) => `<div class="stat"><b>${n}</b><span>${l}</span></div>`).join("");

$("home-grid").innerHTML = PROJECTS.map(p => cardHTML(p, true)).join("");

/* ── About page ───────────────────────────────────────────── */
function renderAboutGrid() {
  $("about-grid").innerHTML = PROJECTS.map(p => cardHTML(p, false)).join("");
}

/* ── Artifacts page ───────────────────────────────────────── */
let cur    = "all";
const fbox = $("filters");

Object.keys(TL).forEach(k => {
  const b = document.createElement("button");
  b.textContent = TL[k];
  b.setAttribute("aria-pressed", k === "all");
  b.onclick = () => {
    cur = k;
    [...fbox.children].forEach(c => c.setAttribute("aria-pressed", c === b));
    renderArtGrid();
  };
  fbox.appendChild(b);
});

function renderArtGrid() {
  const list = PROJECTS.filter(p => cur === "all" || p.type === cur);
  $("artifacts-grid").innerHTML = list.length
    ? list.map(p => cardHTML(p, cur === "all")).join("")
    : '<p class="empty">// no artifacts in this category yet</p>';
}

/* ── Detail page ──────────────────────────────────────────── */
function renderDetail(num) {
  const p = PROJECTS.find(x => x.artifact === num);
  if (!p) {
    $("detail-content").innerHTML = '<p style="color:var(--muted)">Artifact not found.</p>';
    return;
  }

  if (p.tbd) {
    $("detail-content").innerHTML = `
      <span class="art-badge">Artifact ${pad(p.artifact)}</span>
      <h1 class="art-name">${esc(p.name)}</h1>
      <div class="art-chips"><span class="chip">TBD</span></div>
      <div class="tbd-well">
        ${!isPlaceholder(p.desc)
          ? `<p class="idea">${esc(p.desc)}</p><p class="coming">// in progress</p>`
          : `<p class="coming">// artifact details coming soon</p>`}
      </div>`;
    return;
  }

  $("detail-content").innerHTML = `
    <span class="art-badge">Artifact ${pad(p.artifact)}</span>
    <h1 class="art-name">${esc(p.name)}</h1>
    <div class="art-chips">
      <span class="chip done">Complete</span>
      <span class="chip">${TL[p.type]}</span>
      ${p.team > 0 ? `<span class="chip">${p.team} ${p.team === 1 ? "person" : "people"}</span>` : ""}
      ${p.tags.map(t => `<span class="chip">${esc(t)}</span>`).join("")}
      ${p.link ? `<a class="chip ext" href="${esc(p.link)}" target="_blank" rel="noopener">View Artifact ↗</a>` : ""}
    </div>
    <div class="detail-grid">
      <div class="dblock reflect" style="grid-column:1/-1">
        <h4>Reflection</h4>
        <p class="${isPlaceholder(p.reflection) ? "ph" : ""}">${esc(p.reflection || "// reflection to be added")}</p>
      </div>
      <div class="dblock" style="grid-column:1/-1">
        <h4>Overview</h4>
        <p>${esc(p.overview || p.desc)}</p>
      </div>
      ${p.video ? `
      <div class="dblock demo" style="grid-column:1/-1">
        <h4>Demo</h4>
        <video controls playsinline preload="metadata" src="${esc(p.video.src)}"></video>
        ${p.video.caption ? `<p class="caption">${esc(p.video.caption)}</p>` : ""}
      </div>` : ""}
      <div class="dblock">
        <h4>Tech Stack</h4>
        ${p.tags.length
          ? `<div class="tags">${p.tags.map(t => `<span>${esc(t)}</span>`).join("")}</div>`
          : '<p class="ph">// to be documented</p>'}
      </div>
      <div class="dblock">
        <h4>Resources</h4>
        ${p.resources && p.resources.length
          ? p.resources.map(r => `<a href="${esc(r.url)}"${/^https?:/.test(r.url) ? ' target="_blank" rel="noopener"' : ""}>${esc(r.label)}</a>`).join("<br>")
          : '<p class="ph">// GitHub, docs, and other links go here</p>'}
      </div>
    </div>`;
}

/* ── Init ─────────────────────────────────────────────────── */
// A bare URL gets "#home" so Home looks the same whether you arrive or navigate to it.
// replaceState swaps the URL in place: no hashchange event and no extra back-button entry.
if (!location.hash) history.replaceState(null, "", "#home");
navigate(location.hash);
