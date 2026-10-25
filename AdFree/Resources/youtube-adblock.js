// Runs at document start in the page's own world, before YouTube's scripts.
(() => {
  if (!/(^|\.)youtube\.com$/.test(location.hostname)) return;
  window.__adfree = 'youtube';

  // 1. Strip ad data out of player responses before the player sees it.
  const AD_KEYS = ['adPlacements', 'playerAds', 'adSlots', 'adBreakHeartbeatParams'];
  // Tell the app an ad was stopped (it keeps the ads-blocked counter).
  // Debounced: YouTube may re-request the player response repeatedly, which must not inflate the count.
  let lastReport = 0;
  const report = () => {
    const now = Date.now();
    if (now - lastReport < 5000) return;
    lastReport = now;
    try { webkit.messageHandlers.adfree.postMessage({ ad: 1, site: 'youtube' }); } catch (e) {}
  };

  // Ad data is sometimes nested (e.g. inside playerResponse, or in arrays of responses).
  const strip = (o, depth = 0) => {
    if (!o || typeof o !== 'object' || depth > 3) return o;
    if (Array.isArray(o)) { for (const x of o) strip(x, depth + 1); return o; }
    // Only video ads count; feed ad slots are removed silently.
    if (o.playabilityStatus) window.__adfreeStatus = JSON.stringify(o.playabilityStatus).slice(0, 600);
    if ('adPlacements' in o || 'playerAds' in o) report();
    for (const k of AD_KEYS) if (k in o) delete o[k];
    if (o.playerResponse) strip(o.playerResponse, depth + 1);
    return o;
  };
  const parse = JSON.parse;
  JSON.parse = function () { return strip(parse.apply(this, arguments)); };
  const rjson = Response.prototype.json;
  Response.prototype.json = function () { return rjson.call(this).then(strip); };
  // Make the patched functions look native, since a wall can check for tampering.
  const nativeToString = Function.prototype.toString;
  const fake = new Map([[JSON.parse, parse], [Response.prototype.json, rjson]]);
  Function.prototype.toString = new Proxy(nativeToString, {
    apply(t, self, args) { return t.apply(fake.has(self) ? fake.get(self) : self, args); },
  });
  let initial;
  try {
    Object.defineProperty(window, 'ytInitialPlayerResponse', {
      configurable: true,
      get: () => initial,
      set: (v) => { initial = strip(v); },
    });
  } catch (e) {}

  // 2. Fallback: if an ad still shows, hide it, mute it, and skip or fast-forward it.
  const style = document.createElement('style');
  style.textContent = '.ad-showing video { visibility: hidden !important; }';
  new MutationObserver((_, obs) => {
    if (document.head) { document.head.appendChild(style); obs.disconnect(); }
  }).observe(document.documentElement, { childList: true, subtree: true });
  let saved = null;

  // 3. If YouTube's "ad blockers violate our Terms" wall appears, remove it and resume.
  //    If the player stays stuck, reload the page once (guarded so it can't loop).
  let enforcedAt = 0, recoveries = 0, wallSeen = false, lastNudge = 0, nudges = 0;
  const note = (m) => { (window.__adfreeLog = window.__adfreeLog || []).push(Math.round(performance.now()) + ' ' + m); };
  // Removing the dialog is not enough: the player stops loading when the wall fires, so restart it.
  const recover = () => {
    const p = document.querySelector('#movie_player');
    const id = new URLSearchParams(location.search).get('v');
    if (!p || !id || recoveries >= 2) return;
    recoveries++;
    note('recover#' + recoveries);
    try { p.loadVideoById(id); } catch (e) { note('loadVideoById failed'); }
  };
  const dismissWall = () => {
    const msg = document.querySelector('ytd-enforcement-message-view-model');
    if (!msg) return;
    wallSeen = true;
    if (!enforcedAt) { enforcedAt = Date.now(); note('wall seen'); }
    (msg.closest('tp-yt-paper-dialog') || msg).remove();
    document.querySelectorAll('tp-yt-iron-overlay-backdrop').forEach((e) => e.remove());
    document.body && (document.body.style.overflow = '');
    setTimeout(recover, 500);
  };
  // The wall also hides the player by setting visibility:hidden on a container.
  // Find the topmost hidden ancestor of the video (the one that is the source) and unhide it.
  const unhidePlayer = () => {
    const v = document.querySelector('video.html5-main-video');
    if (!v) return;
    const player = document.querySelector('.html5-video-player');
    if (player && player.classList.contains('ad-showing')) return;
    for (let n = v.parentElement; n && n !== document.documentElement; n = n.parentElement) {
      if (getComputedStyle(n).visibility !== 'hidden') continue;
      const up = n.parentElement;
      if (up && getComputedStyle(up).visibility === 'hidden') continue;
      n.style.setProperty('visibility', 'visible', 'important');
      note('unhid ' + n.tagName.toLowerCase() + (n.id ? '#' + n.id : '') + '.' + String(n.className).slice(0, 40));
      break;
    }
    // Once unhidden, a player stuck at "unstarted" gets a gentle nudge (at most every 3 s).
    const mp = document.querySelector('#movie_player');
    if (mp && mp.getPlayerState && mp.getPlayerState() === -1 && nudges < 3 && Date.now() - lastNudge > 3000) {
      lastNudge = Date.now(); nudges++;
      try { mp.playVideo(); note('nudged play'); } catch (e) {}
    }
  };
  const maybeReload = () => {
    if (!enforcedAt || Date.now() - enforcedAt < 4000) return;
    const v = document.querySelector('video.html5-main-video');
    const stuck = !v || v.paused || v.readyState < 3 || document.querySelector('.ytp-error');
    enforcedAt = 0;
    if (!stuck) return;
    try {
      if (sessionStorage.getItem('adfree-reload') === location.href) { note('reload skipped (already tried)'); return; }
      sessionStorage.setItem('adfree-reload', location.href);
    } catch (e) { return; }
    note('reloading');
    location.reload();
  };

  setInterval(() => {
    dismissWall();
    if (wallSeen) unhidePlayer();
    maybeReload();
    const player = document.querySelector('.html5-video-player');
    const video = document.querySelector('video.html5-main-video');
    if (!player || !video) return;
    const adShowing = player.classList.contains('ad-showing');
    if (adShowing) {
      if (!saved) { saved = { muted: video.muted, rate: video.playbackRate }; report(); }
      video.muted = true;
      video.playbackRate = 16;
      if (isFinite(video.duration) && video.duration > 0) video.currentTime = video.duration;
      document.querySelectorAll(
        '.ytp-skip-ad-button, .ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-ad-overlay-close-button'
      ).forEach((b) => b.click());
    } else if (saved) {
      video.muted = saved.muted;
      video.playbackRate = saved.rate;
      saved = null;
    }
  }, 100);
})();
