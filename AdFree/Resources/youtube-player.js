// Replaces YouTube's own player with a plain video element fed by the app (via yt-dlp).
// The rest of the YouTube page (comments, channel, recommendations) keeps working.
(() => {
  if (!/(^|\.)youtube\.com$/.test(location.hostname)) return;
  if (window.top !== window) return;

  const note = (m) => { (window.__adfreeLog = window.__adfreeLog || []).push(Math.round(performance.now()) + ' player: ' + m); };
  const post = (msg) => { try { webkit.messageHandlers.adfree.postMessage(msg); } catch (e) {} };
  const videoId = () => (location.pathname === '/watch' ? new URLSearchParams(location.search).get('v') : null);
  const fmt = (s) => {
    s = Math.floor(s);
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
    return (h ? h + ':' + String(m).padStart(2, '0') : m) + ':' + String(r).padStart(2, '0');
  };

  const style = document.createElement('style');
  style.textContent = `
    #adfree-player { position:absolute; inset:0; z-index:2147483000; background:#000; color:#fff;
      font:14px -apple-system, system-ui, sans-serif; }
    #adfree-player video { width:100%; height:100%; background:#000; }
    #adfree-player .af-msg { position:absolute; inset:0; display:flex; align-items:center; justify-content:center;
      text-align:center; padding:24px; opacity:.85; }
    #adfree-player .af-bar { position:absolute; top:0; left:0; right:0; padding:10px 12px; display:flex; gap:10px;
      align-items:center; background:linear-gradient(#000a, #0000); opacity:0; transition:opacity .2s; pointer-events:none; }
    #adfree-player:hover .af-bar, #adfree-player.af-open .af-bar { opacity:1; pointer-events:auto; }
    #adfree-player button { background:#fff3; color:#fff; border:0; border-radius:14px; padding:5px 12px; cursor:pointer; font:inherit; }
    #adfree-player .af-title { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; opacity:.9; }
    #adfree-player .af-list { position:absolute; top:44px; left:12px; max-height:70%; width:min(420px, 80%); overflow:auto;
      background:#111e; border-radius:8px; display:none; padding:4px; }
    #adfree-player.af-open .af-list { display:block; }
    #adfree-player .af-list div { padding:7px 10px; border-radius:6px; cursor:pointer; display:flex; gap:12px; }
    #adfree-player .af-list div:hover, #adfree-player .af-list div.af-now { background:#fff3; }
    #adfree-player .af-list span { opacity:.6; min-width:48px; font-variant-numeric:tabular-nums; }
  `;
  (document.head || document.documentElement).appendChild(style);

  let wanted = null;   // video id currently on the page
  let data = null;     // stream info from the app for that id
  let failed = false;
  let wrap = null, video = null, msgEl = null, titleEl = null, listEl = null;

  const teardown = () => { if (wrap) wrap.remove(); wrap = video = msgEl = titleEl = listEl = null; };

  const build = () => {
    wrap = document.createElement('div');
    wrap.id = 'adfree-player';
    msgEl = document.createElement('div');
    msgEl.className = 'af-msg';
    msgEl.textContent = 'Preparing ad-free player… (the first load can take about 20 seconds)';
    wrap.appendChild(msgEl);
  };

  const mountStream = () => {
    if (!wrap || !data || video) return;
    video = document.createElement('video');
    video.controls = true;
    video.autoplay = true;
    video.playsInline = true;
    video.src = data.url;
    video.addEventListener('error', () => {
      note('video error ' + (video && video.error && video.error.code));
      failed = true;
      teardown();
    });
    video.addEventListener('playing', () => { if (msgEl) msgEl.style.display = 'none'; });
    wrap.insertBefore(video, wrap.firstChild);
    const t = parseInt(new URLSearchParams(location.search).get('t') || '', 10);
    if (t > 0) video.addEventListener('loadedmetadata', () => { video.currentTime = t; }, { once: true });

    // Top bar: video title and, when the video has them, a chapter list.
    const bar = document.createElement('div');
    bar.className = 'af-bar';
    titleEl = document.createElement('span');
    titleEl.className = 'af-title';
    titleEl.textContent = data.title || '';
    if (data.chapters && data.chapters.length) {
      const btn = document.createElement('button');
      btn.textContent = '☰ Chapters';
      btn.onclick = () => wrap.classList.toggle('af-open');
      bar.appendChild(btn);
      listEl = document.createElement('div');
      listEl.className = 'af-list';
      data.chapters.forEach((c) => {
        const row = document.createElement('div');
        row.innerHTML = '<span></span><b style="font-weight:400"></b>';
        row.children[0].textContent = fmt(c.t);
        row.children[1].textContent = c.title;
        row.onclick = () => { video.currentTime = c.t; video.play(); wrap.classList.remove('af-open'); };
        listEl.appendChild(row);
      });
      wrap.appendChild(listEl);
      video.addEventListener('timeupdate', () => {
        let now = 0;
        data.chapters.forEach((c, i) => { if (video.currentTime >= c.t) now = i; });
        const cur = data.chapters[now];
        titleEl.textContent = cur.title + (data.title ? ' · ' + data.title : '');
        [...listEl.children].forEach((r, i) => r.classList.toggle('af-now', i === now));
      });
    }
    bar.appendChild(titleEl);
    wrap.appendChild(bar);
    note('stream mounted');
  };

  // The app calls this with the result of the yt-dlp run.
  window.__adfreePlay = (info) => {
    if (!info || info.id !== videoId()) return;
    if (info.error) { note('resolve failed: ' + info.error); failed = true; window.__adfreePlayerError = info.error; teardown(); return; }
    data = info;
    mountStream();
  };

  // YouTube navigates without reloading, so watch the address instead of waiting for load events.
  setInterval(() => {
    const id = videoId();
    if (id !== wanted) {
      wanted = id; data = null; failed = false; window.__adfreePlayerError = null;
      teardown();
      if (id) { note('watch ' + id); post({ watch: id }); }
    }
    if (!id || failed) return;

    // Keep our player inside YouTube's player box, and keep YouTube's own player quiet.
    const host = document.querySelector('#movie_player');
    if (host) {
      if (!wrap) build();
      if (wrap.parentElement !== host) { host.appendChild(wrap); if (data) { video = null; wrap.querySelectorAll('video,.af-bar,.af-list').forEach((e) => e.remove()); mountStream(); } }
    }
    const yt = document.querySelector('video.html5-main-video');
    if (yt && yt !== video) { try { yt.muted = true; yt.pause(); } catch (e) {} }
  }, 400);
})();
