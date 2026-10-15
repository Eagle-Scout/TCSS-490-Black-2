// Runs at document start in the page's own world, before YouTube's scripts.
(() => {
  if (!/(^|\.)youtube\.com$/.test(location.hostname)) return;
  window.__adfree = 'youtube';

  // 1. Strip ad data out of player responses before the player sees it.
  const AD_KEYS = ['adPlacements', 'playerAds', 'adSlots', 'adBreakHeartbeatParams'];
  // Tell the app an ad was stopped (it keeps the ads-blocked counter).
  const report = () => { try { webkit.messageHandlers.adfree.postMessage({ ad: 1, site: 'youtube' }); } catch (e) {} };

  // Ad data is sometimes nested (e.g. inside playerResponse, or in arrays of responses).
  const strip = (o, depth = 0) => {
    if (!o || typeof o !== 'object' || depth > 3) return o;
    if (Array.isArray(o)) { for (const x of o) strip(x, depth + 1); return o; }
    // Only video ads count; feed ad slots are removed silently.
    if ('adPlacements' in o || 'playerAds' in o) report();
    for (const k of AD_KEYS) if (k in o) delete o[k];
    if (o.playerResponse) strip(o.playerResponse, depth + 1);
    return o;
  };
  const parse = JSON.parse;
  JSON.parse = function () { return strip(parse.apply(this, arguments)); };
  const rjson = Response.prototype.json;
  Response.prototype.json = function () { return rjson.call(this).then(strip); };
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
  setInterval(() => {
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
