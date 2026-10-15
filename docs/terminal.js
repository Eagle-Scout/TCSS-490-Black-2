/* =========================================================
   TCSS 490 — Project Portfolio
   terminal.js  (interactive terminal; loads after script.js)

   A simulated shell that navigates the site. The "filesystem"
   is generated from PROJECTS in script.js, so it never goes
   out of date. No real shell access — everything is in-browser.

   Placement modes (user-controlled, remembered per session):
     open    inline on the home page, floating mini panel elsewhere
     closed  hidden; a small ">_ Terminal" button brings it back
   ========================================================= */
(function () {
  "use strict";

  /* ── Storage (sessionStorage can throw in private windows) ─ */
  const store = {
    get(k)    { try { return sessionStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { sessionStorage.setItem(k, v); } catch (e) { /* ignore */ } }
  };
  const K = { mode: "tty.mode", cwd: "tty.cwd", hist: "tty.hist", booted: "tty.booted" };

  const reduced = matchMedia("(prefers-reduced-motion: reduce)");
  const mobile  = matchMedia("(max-width: 760px), (hover: none) and (pointer: coarse)");
  const sleep   = ms => new Promise(r => { wake = r; setTimeout(r, ms); });
  let wake = null;

  /* ── Virtual filesystem (built from PROJECTS) ─────────────── */
  const slug = s => s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
  const dir  = (route, children = {}) => ({ type: "dir", route, children });
  const file = text => ({ type: "file", text });

  function artifactDir(p) {
    const route = `#artifact-${pad(p.artifact)}`;
    if (p.tbd) {
      return dir(route, {
        "status.txt": file((isPlaceholder(p.desc) ? "" : p.desc + "\n") + "// in progress — details coming soon")
      });
    }
    const files = {
      "overview.txt":   file(p.overview || p.desc),
      "reflection.txt": file(isPlaceholder(p.reflection) ? "// reflection to be added" : p.reflection),
      "stack.txt":      file(p.tags.length ? p.tags.join(", ") : "// to be documented")
    };
    const links = [];
    if (p.link) links.push("Live artifact: " + p.link);
    (p.resources || []).forEach(r => links.push(r.label + ": " + r.url));
    if (links.length) files["links.txt"] = file(links.join("\n"));
    return dir(route, files);
  }

  const artifactNames = {};   // artifact number -> directory name
  const artifactKids  = {};
  PROJECTS.forEach(p => {
    const name = `artifact_${p.artifact}_${slug(p.name)}`;
    artifactNames[p.artifact] = name;
    artifactKids[name] = artifactDir(p);
  });

  const lede = document.querySelector(".lede");
  const root = dir("#home", {
    about:     dir("#about"),
    artifacts: dir("#artifacts", artifactKids),
    "README.md": file(lede ? lede.textContent.trim() : "TCSS 490 Project Portfolio")
  });

  // route -> path parts, so page navigation can move the terminal's cwd
  const ROUTES = {};
  (function walk(node, parts) {
    if (node.type !== "dir") return;
    ROUTES[node.route] = parts;
    Object.keys(node.children).forEach(k => walk(node.children[k], parts.concat(k)));
  })(root, []);

  function nodeAt(parts) {
    let node = root;
    for (const s of parts) {
      if (node.type !== "dir" || !node.children[s]) return null;
      node = node.children[s];
    }
    return node;
  }

  let cwd = [];

  // Folder aliases: "artifact_1", "artifact1", "adblock", "project portfolio" all work
  const norm = t => t.toLowerCase().replace(/[^a-z0-9]/g, "");
  function findArtifact(seg) {
    const k = norm(seg);
    if (!k) return null;
    const names = Object.keys(artifactKids);
    const num   = n => (/_(\d+)_/.exec(n) || [])[1];
    const label = n => norm(n.replace(/^artifact_\d+_/, ""));
    const words = n => n.replace(/^artifact_\d+_/, "").split("_").filter(w => w.length >= 4);
    const exact = names.filter(n => [norm(n), "artifact" + num(n), label(n), ...words(n)].includes(k));
    if (exact.length === 1) return exact[0];
    if (exact.length) return null;
    const pre = names.filter(n => k.length >= 3 && label(n).startsWith(k));
    return pre.length === 1 ? pre[0] : null;
  }

  function resolve(input, base = cwd) {
    const abs   = input.startsWith("~") || input.startsWith("/");
    const parts = abs ? [] : base.slice();
    input.replace(/^~/, "").split("/").forEach(s => {
      if (!s || s === ".") return;
      if (s === "..") { parts.pop(); return; }
      // Short names only work from inside ~/artifacts, like any sibling folder
      if (parts.length === 1 && parts[0] === "artifacts" && !nodeAt(parts).children[s]) {
        const hit = findArtifact(s);
        if (hit) { parts.push(hit); return; }
      }
      parts.push(s);
    });
    const node = nodeAt(parts);
    return node ? { parts, node } : null;
  }

  const pathStr = parts => parts.length ? "~/" + parts.join("/") : "~";
  // Like a real shell, the prompt shows only the current folder, not the whole path
  const folderName = () => {
    if (!cwd.length) return "~";
    const last = cwd[cwd.length - 1];
    return (/^artifact_\d+/.exec(last) || [last])[0];
  };
  const promptStr = () => `guest@tcss490:${folderName()}$ `;

  /* ── DOM ──────────────────────────────────────────────────── */
  const slot = document.getElementById("term-slot");

  const tty = document.createElement("section");
  tty.className = "term tty";
  tty.setAttribute("aria-label", "Interactive terminal");
  tty.hidden = true;
  tty.innerHTML = `
    <div class="term-bar">
      <i></i><i></i><i></i>
      <button type="button" class="tty-btn tty-cmdbtn" id="tty-cmdbtn" aria-haspopup="menu" aria-expanded="false" aria-controls="tty-menu">Commands ▾</button>
      <span>guest@tcss490</span>
      <button type="button" class="tty-btn" data-act="close" aria-label="Close terminal">✕</button>
    </div>
    <div class="tty-menu" id="tty-menu" role="menu" aria-label="Commands" hidden></div>
    <div class="term-body" id="tty-body">
      <div id="tty-out" role="log"></div>
      <form class="tty-row" id="tty-form" autocomplete="off">
        <label class="tp" id="tty-prompt" for="tty-in"></label>
        <input id="tty-in" type="text" autocomplete="off" autocapitalize="off" autocorrect="off" spellcheck="false" aria-label="Terminal input">
        <span class="cursor tty-fakecur" aria-hidden="true"></span>
      </form>
    </div>`;

  const toggle = document.createElement("button");
  toggle.type = "button";
  toggle.className = "tty-toggle";
  toggle.hidden = true;
  toggle.textContent = ">_ Terminal";
  toggle.setAttribute("aria-label", "Open terminal (shortcut: backtick)");
  document.body.appendChild(toggle);

  const q      = sel => tty.querySelector(sel);
  const out    = q("#tty-out");
  const body   = q("#tty-body");
  const input  = q("#tty-in");
  const prompt = q("#tty-prompt");
  const menuEl = q("#tty-menu");
  const cmdBtn = q("#tty-cmdbtn");

  /* ── Output helpers ───────────────────────────────────────── */
  function print(html, cls) {
    const d = document.createElement("div");
    d.className = "tl" + (cls ? " " + cls : "");
    d.innerHTML = html || "&nbsp;";
    out.appendChild(d);
    body.scrollTop = body.scrollHeight;
  }
  const printText = (t, cls) => print(esc(t), cls);
  const echo = text => print(`<span class="tp">${esc(promptStr())}</span>${esc(text)}`);

  /* ── Commands ─────────────────────────────────────────────── */
  const dirName  = (n, node) => node.type === "dir" ? `<span class="td">${esc(n)}/</span>` : esc(n);

  const COMMANDS = {
    help() {
      // [usage, description, shown on phones?] — phones only see what the Commands menu can run
      const rows = [
        ["ls [path]",    "list files and folders",                              true],
        ["cd [path]",    "change folder — this also changes the page",          true],
        ["",             "  in ~/artifacts: cd artifact_2, cd adblock",         false],
        ["pwd",          "show the current folder",                             false],
        ["cat <file>",   "print a file",                                        false],
        ["tree",         "show everything below here",                          true],
        ["open [path]",  "open an artifact's live link",                        false],
        ["echo <text>",  "print text back",                                     false],
        ["history",      "show previous commands",                              false],
        ["clear",        "clear the screen",                                    true],
        ["help",         "show this list",                                      true],
        ["exit",         "close the terminal",                                  false]
      ];
      rows.filter(r => !mobile.matches || r[2])
          .forEach(([c, d]) => print(`<span class="tok">${esc(c.padEnd(14))}</span>${esc(d)}`));
      print("");
      printText(mobile.matches
        ? "Tap Commands above to navigate and run commands."
        : "Tab completes names, ↑/↓ recalls history, and the Commands menu above types for you.", "tdim");
    },

    ls(args) {
      const r = resolve(args[0] || ".");
      if (!r) return printText(`ls: ${args[0]}: No such file or directory`, "terr");
      if (r.node.type === "file") return printText(args[0]);
      const names = Object.keys(r.node.children);
      if (!names.length) return;
      print(names.map(n => dirName(n, r.node.children[n])).join("   "));
    },

    cd(args) {
      const arg = args.join(" ") || "~";
      const r = resolve(arg);
      if (!r) return printText(`cd: ${arg}: No such file or directory`, "terr");
      if (r.node.type !== "dir") return printText(`cd: ${arg}: Not a directory`, "terr");
      go(r.parts);
    },

    pwd() { printText(pathStr(cwd)); },

    cat(args) {
      if (!args.length) return printText("cat: missing file name", "terr");
      args.forEach(a => {
        const r = resolve(a);
        if (!r)                     return printText(`cat: ${a}: No such file or directory`, "terr");
        if (r.node.type === "dir")  return printText(`cat: ${a}: Is a directory`, "terr");
        printText(r.node.text);
      });
    },

    tree() {
      const start = nodeAt(cwd);
      print(`<span class="td">${esc(pathStr(cwd))}</span>`);
      (function walk(node, prefix) {
        const names = Object.keys(node.children);
        names.forEach((n, i) => {
          const last = i === names.length - 1;
          const child = node.children[n];
          print(esc(prefix + (last ? "└── " : "├── ")) + dirName(n, child));
          if (child.type === "dir") walk(child, prefix + (last ? "    " : "│   "));
        });
      })(start, "");
    },

    open(args) {
      const r = args[0] ? resolve(args[0]) : { node: nodeAt(cwd) };
      if (!r) return printText(`open: ${args[0]}: No such file or directory`, "terr");
      const m = /^#artifact-(\d+)$/.exec(r.node.route || "");
      const p = m && PROJECTS.find(x => x.artifact === parseInt(m[1], 10));
      if (!p || !p.link) return printText("open: nothing to open here — try inside an artifact folder", "terr");
      printText("Opening " + p.link, "tdim");
      window.open(p.link, "_blank", "noopener");
    },

    echo(args, text) {
      if (mobile.matches) return printText("echo: needs a keyboard — available on desktop", "terr");
      // Use the raw text so spacing is kept; strip one pair of matching quotes like a shell would
      const rest = text.replace(/^echo\s*/, "");
      printText(rest.replace(/^(["'])(.*)\1$/, "$2"));
    },

    history() {
      hist.forEach((h, i) => printText(String(i + 1).padStart(3) + "  " + h));
    },

    clear() { out.innerHTML = ""; },

    exit() { setMode("closed"); }
  };

  /* ── History ──────────────────────────────────────────────── */
  let hist = [];
  try { hist = JSON.parse(store.get(K.hist)) || []; } catch (e) { hist = []; }
  let hpos = hist.length;

  function run(raw) {
    const text = raw.trim();
    echo(raw);
    if (!text) return;
    if (hist[hist.length - 1] !== text) hist.push(text);
    hist = hist.slice(-50);
    hpos = hist.length;
    store.set(K.hist, JSON.stringify(hist));

    const [cmd, ...args] = text.split(/\s+/);
    const fn = Object.prototype.hasOwnProperty.call(COMMANDS, cmd) ? COMMANDS[cmd] : null;
    if (!fn) return printText(`${cmd}: command not found — try 'help'`, "terr");
    fn(args, text);
  }

  /* ── Navigation (terminal <-> page) ───────────────────────── */
  const onHome = () => !location.hash || location.hash === "#home";

  const routeOf = hash => {
    const m = /^#artifact-(\d+)$/.exec(hash);
    if (m) return "#artifact-" + pad(parseInt(m[1], 10));
    return hash === "" ? "#home" : hash;
  };

  function go(parts) {
    cwd = parts;
    store.set(K.cwd, JSON.stringify(cwd));
    refreshPrompt();
    const route = nodeAt(parts).route;
    if (routeOf(location.hash) !== route) location.hash = route;   // fires hashchange -> navigate()
    else place();
  }

  // Pages that start with the terminal minimized (it stays reachable from the >_ Terminal button)
  const QUIET_ROUTES = ["#adfree-manual"];
  let lastRoute = null;

  // Page changed by menu, card, or back button: follow it
  function syncFromHash() {
    if (QUIET_ROUTES.includes(location.hash) && lastRoute !== location.hash && mode === "open") {
      mode = "closed";
      store.set(K.mode, "closed");
    }
    lastRoute = location.hash;
    const parts = ROUTES[routeOf(location.hash)];
    if (parts) {
      cwd = parts;
      store.set(K.cwd, JSON.stringify(cwd));
      refreshPrompt();
    }
    place();
  }

  /* ── Commands dropdown ────────────────────────────────────── */
  function cdTo(parts) {
    if (parts[0] === "artifacts" && parts.length === 2) {
      const short = parts[1].match(/^artifact_\d+/)[0];
      if (cwd.length === 1 && cwd[0] === "artifacts") return "cd " + short;
      if (cwd.length === 2 && cwd[0] === "artifacts") return "cd ../" + short;
      return "cd ~/artifacts/" + short;
    }
    return parts.length ? "cd ~/" + parts.join("/") : "cd ~";
  }

  function buildMenu() {
    const nav = [[cdTo([]), "go to Home"], [cdTo(["about"]), "go to About"], [cdTo(["artifacts"]), "go to All Artifacts"]];
    PROJECTS.forEach(p =>
      nav.push([cdTo(["artifacts", artifactNames[p.artifact]]), `go to Artifact ${p.artifact} — ${p.name}`]));
    const shell = [["ls", "list files here"], ["tree", "show the folder tree"], ["help", "show help"], ["clear", "clear the screen"]];
    const item = ([cmd, label]) =>
      `<button type="button" class="tty-mi" role="menuitem" data-cmd="${esc(cmd)}" title="${esc(cmd)}">${esc(label)}</button>`;
    menuEl.innerHTML =
      '<div class="tty-mh">Navigate</div>' + nav.map(item).join("") +
      '<div class="tty-mh">Shell</div>'    + shell.map(item).join("");
  }

  function menuOpen(open) {
    menuEl.hidden = !open;
    cmdBtn.setAttribute("aria-expanded", String(open));
    if (open) menuEl.querySelector(".tty-mi").focus();
  }

  cmdBtn.addEventListener("click", () => menuOpen(menuEl.hidden));

  menuEl.addEventListener("click", e => {
    const mi = e.target.closest(".tty-mi");
    if (!mi) return;
    menuOpen(false);
    typeAndRun(mi.dataset.cmd);
  });

  menuEl.addEventListener("keydown", e => {
    if (e.key !== "ArrowDown" && e.key !== "ArrowUp") return;
    e.preventDefault();
    const items = [...menuEl.querySelectorAll(".tty-mi")];
    const i = items.indexOf(document.activeElement);
    items[(i + (e.key === "ArrowDown" ? 1 : -1) + items.length) % items.length].focus();
  });

  document.addEventListener("pointerdown", e => {
    if (!menuEl.hidden && !e.target.closest("#tty-menu, #tty-cmdbtn")) menuOpen(false);
  });

  let typing = false;
  async function typeAndRun(cmd) {
    if (typing || !cmd) return;
    typing = true;
    if (!mobile.matches) input.focus({ preventScroll: true });
    if (!reduced.matches && !mobile.matches) {
      input.value = "";
      for (const ch of cmd) { input.value += ch; await sleep(22); }
      await sleep(160);
    }
    input.value = "";
    run(cmd);
    typing = false;
  }

  function refreshPrompt() {
    prompt.textContent = promptStr();
    buildMenu();
  }

  /* ── Tab completion ───────────────────────────────────────── */
  const commonPrefix = list => list.reduce((a, b) => {
    let i = 0; while (i < a.length && a[i] === b[i]) i++; return a.slice(0, i);
  });

  function complete() {
    const [, head, word] = /^(.*?)(\S*)$/.exec(input.value);
    let names, base = "", frag = word, isDir = () => false;

    if (!head.trim()) {
      names = Object.keys(COMMANDS).filter(k => k.startsWith(word));
    } else {
      const i = word.lastIndexOf("/");
      base = word.slice(0, i + 1);
      frag = word.slice(i + 1);
      const d = base ? resolve(base) : { node: nodeAt(cwd) };
      if (!d || d.node.type !== "dir") return;
      names = Object.keys(d.node.children).filter(k => k.startsWith(frag));
      isDir = n => d.node.children[n].type === "dir";
    }
    if (!names.length) return;

    if (names.length === 1) {
      input.value = head + base + names[0] + (isDir(names[0]) ? "/" : " ");
      return;
    }
    const pre = commonPrefix(names);
    if (pre.length > frag.length) { input.value = head + base + pre; return; }
    echo(input.value);
    print(names.map(n => dirName(n, { type: isDir(n) ? "dir" : "file" })).join("   "));
  }

  /* ── Input events ─────────────────────────────────────────── */
  q("#tty-form").addEventListener("submit", e => {
    e.preventDefault();
    if (typing) return;
    const v = input.value;
    input.value = "";
    run(v);
  });

  input.addEventListener("keydown", e => {
    if (e.key === "Tab") { e.preventDefault(); complete(); }
    else if (e.key === "ArrowUp")   { e.preventDefault(); if (hpos > 0) input.value = hist[--hpos]; }
    else if (e.key === "ArrowDown") { e.preventDefault(); hpos = Math.min(hpos + 1, hist.length); input.value = hist[hpos] || ""; }
    else if (e.key === "l" && e.ctrlKey) { e.preventDefault(); COMMANDS.clear(); }
  });

  body.addEventListener("click", () => {
    if (!String(getSelection()) && !input.disabled) input.focus({ preventScroll: true });
  });

  tty.addEventListener("keydown", e => {
    if (e.key !== "Escape") return;
    if (!menuEl.hidden) { menuOpen(false); cmdBtn.focus(); }
    else setMode("closed");
  });

  tty.addEventListener("click", e => {
    const act = e.target.closest("[data-act]");
    if (!act) return;
    if (act.dataset.act === "close") setMode("closed");
  });

  toggle.addEventListener("click", () => openTerminal());

  // Backtick toggles the terminal when you're not typing somewhere else
  document.addEventListener("keydown", e => {
    if (e.key !== "`" || e.ctrlKey || e.metaKey || e.altKey || mobile.matches) return;
    if (e.target.closest("input, textarea, select, [contenteditable]")) return;
    e.preventDefault();
    if (mode === "closed") openTerminal(); else setMode("closed");
  });

  /* ── Placement ────────────────────────────────────────────── */
  let mode = store.get(K.mode) || (onHome() ? "open" : "closed");
  if (!["open", "closed"].includes(mode)) mode = "open";   // also upgrades old "docked" values

  function setMode(m) {
    mode = m;
    store.set(K.mode, m);
    place();
    if (m === "closed" && !mobile.matches && !toggle.hidden) toggle.focus({ preventScroll: true });
  }

  function openTerminal() {
    setMode("open");
    if (tty.classList.contains("tty-inline")) tty.scrollIntoView({ block: "nearest", behavior: "smooth" });
    if (!input.disabled) input.focus({ preventScroll: true });
  }

  function place() {
    const home = onHome();
    const m    = mobile.matches;
    const where =
      mode === "closed"  ? "none" :
      home               ? "inline" : "float";

    const hadFocus = tty.contains(document.activeElement);
    tty.hidden = where === "none";
    tty.classList.toggle("tty-inline", where === "inline");
    tty.classList.toggle("tty-float",  where === "float");
    tty.classList.toggle("tty-ro",     m);

    const parent = where === "inline" ? slot : document.body;
    if (where !== "none" && tty.parentNode !== parent) {
      parent.appendChild(tty);
      body.scrollTop = body.scrollHeight;   // moving the node resets its scroll
      if (hadFocus) input.focus({ preventScroll: true });
    }

    if (where === "none") menuOpen(false);
    toggle.hidden  = where !== "none";

    if (where !== "none") startBoot();
  }

  /* ── Boot sequence ────────────────────────────────────────── */
  const BOOT = [
    ["tcss490 bootloader v4.90", 380],
    ["",                         120],
    [`<span class="tok">[  OK  ]</span> Checking filesystem ........ ${PROJECTS.length} artifacts found`, 330],
    ['<span class="tok">[  OK  ]</span> Mounting ~/artifacts',          260],
    ['<span class="tok">[  OK  ]</span> Mounting ~/about',              260],
    ['<span class="tok">[  OK  ]</span> Starting portfolio services',   420],
    ["",                                                                 140],
    ["Welcome to <b>TCSS 490</b> — Project Portfolio.",                  300]
  ];
  const WELCOME_BACK = [["tcss490 — session restored.", 0]];

  let booting = false, bootStarted = false, skip = false;

  function skipBoot() { if (booting) { skip = true; if (wake) wake(); } }
  tty.addEventListener("pointerdown", skipBoot);
  document.addEventListener("keydown", skipBoot);

  async function startBoot() {
    if (bootStarted) return;
    bootStarted = true;
    booting = true;
    input.disabled = true;
    cmdBtn.disabled = true;
    tty.classList.add("tty-booting");

    const lines = store.get(K.booted) ? WELCOME_BACK : BOOT;
    for (const [html, delay] of lines) {
      print(html);
      if (!skip && !reduced.matches && delay) await sleep(delay);
    }
    store.set(K.booted, "1");

    if (mobile.matches) {
      print("Tap <b>Commands</b> above to run commands — no keyboard needed.", "tdim");
    } else {
      print("Type <span class=\"tok\">help</span> to see commands, or pick one from the <b>Commands</b> menu above.", "tdim");
    }
    print("");

    booting = false;
    tty.classList.remove("tty-booting");
    input.disabled  = mobile.matches;   // phones use the Commands menu, so no soft keyboard
    cmdBtn.disabled = false;
  }

  mobile.addEventListener("change", () => {
    if (!booting) input.disabled = mobile.matches;
    place();
  });

  /* ── Init ─────────────────────────────────────────────────── */
  try {
    const saved = JSON.parse(store.get(K.cwd));
    if (Array.isArray(saved) && nodeAt(saved)) cwd = saved;
  } catch (e) { /* default to ~ */ }

  refreshPrompt();
  window.addEventListener("hashchange", syncFromHash);
  syncFromHash();
})();
