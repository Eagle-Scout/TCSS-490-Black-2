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
    desc: "A portfolio site cataloging five TCSS 490 artifacts over Autumn 2026, with a dedicated page about the author.",
    reflection: "The biggest challenge was understanding what it was I wanted to do after every prompt and iteration. What I would do differently is probably start off the chat by showing Claude the course page for the artifact and going from there, rather than trying to build a portfolio to match. Interestingly enough, the portfolio differs from my expectation, where instead of multiple .html files, there's only one, while the CSS and JS dictate what shows on the one page at any time.",
    link: "https://eagle-scout.github.io/TCSS-490-Black-2/",
    overview: "Built as Artifact 1. A static single-page application using hash-based client-side routing — no build step required. Includes a home page, an About page, a filterable artifact grid, and per-artifact detail pages, all within one HTML file.",
    resources: []
  },
  {
    artifact: 2,
    name: "Ad Blocker",
    type: "solo",
    team: 1,
    tags: [],          // add tech stack once known, e.g. ["Safari Extension", "JavaScript"]
    featured: false,
    tbd: true,
    desc: "An ad blocker for Safari so that I can avoid YouTube or Twitch ads, even when they update their settings.",
    reflection: "",
    link: "",
    overview: "",
    resources: []
  },
  {
    artifact: 3,
    name: "AutoClick",
    type: "solo",
    team: 1,
    tags: [],          // add tech stack once known
    featured: false,
    tbd: true,
    desc: "A highly customizable auto clicker — the one I use isn't compatible on my machine anymore, so I'm building my own.",
    reflection: "",
    link: "",
    overview: "",
    resources: []
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
  } else if (/^#artifact-\d+$/.test(hash)) {
    const n = parseInt(hash.replace("#artifact-", ""), 10);
    renderDetail(n);
    pid = "page-detail";
  }

  pages.forEach(p => p.classList.toggle("active", p.id === pid));

  document.querySelectorAll("[data-nav]").forEach(a =>
    a.classList.toggle(
      "active",
      "#" + a.dataset.nav === hash || (hash === "#home" && a.dataset.nav === "home")
    )
  );

  window.scrollTo({ top: 0, behavior: "instant" });

  const m    = /^#artifact-(\d+)$/.exec(hash);
  const proj = m ? PROJECTS.find(x => x.artifact === parseInt(m[1])) : null;
  document.title =
    proj                  ? `Artifact ${pad(proj.artifact)} — TCSS 490` :
    hash === "#about"     ? "About — TCSS 490"                          :
    hash === "#artifacts" ? "Artifacts — TCSS 490"                      :
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

// Terminal animation
const term  = $("term");
const steps = [
  ['<span class="tp">$</span> ',     "cd tcss490-portfolio && ./build.sh"],
  ['\n<span class="tdim">›</span> ', "Compiling sources..."],
  ['\n<span class="tdim">›</span> ', "Running tests..."],
  ['\n<span class="tok">✓</span> ',  "Build complete.  5 artifacts tracked."]
];

if (matchMedia("(prefers-reduced-motion: reduce)").matches) {
  term.innerHTML = steps.map(([p, t]) => p + esc(t)).join("");
} else {
  let html = "", si = 0, ci = 0;
  (function tick() {
    if (si >= steps.length) {
      term.innerHTML = html + '<span class="cursor"></span>';
      return;
    }
    const [pre, txt] = steps[si];
    if (ci === 0) html += pre;
    ci++;
    term.innerHTML = html + esc(txt.slice(0, ci)) + '<span class="cursor"></span>';
    if (ci >= txt.length) {
      html += esc(txt);
      si++;
      ci = 0;
      setTimeout(tick, 480);
    } else {
      setTimeout(tick, si === 0 ? 36 : 14);
    }
  })();
}

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
      <div class="dblock">
        <h4>Tech Stack</h4>
        ${p.tags.length
          ? `<div class="tags">${p.tags.map(t => `<span>${esc(t)}</span>`).join("")}</div>`
          : '<p class="ph">// to be documented</p>'}
      </div>
      <div class="dblock">
        <h4>Resources</h4>
        ${p.resources && p.resources.length
          ? p.resources.map(r => `<a href="${esc(r.url)}">${esc(r.label)}</a>`).join("<br>")
          : '<p class="ph">// GitHub, docs, and other links go here</p>'}
      </div>
    </div>`;
}

/* ── Init ─────────────────────────────────────────────────── */
navigate(location.hash || "#home");
