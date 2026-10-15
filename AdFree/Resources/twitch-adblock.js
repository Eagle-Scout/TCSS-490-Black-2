// Twitch splices ads into the HLS playlist the video player downloads. The player fetches
// playlists inside Web Workers, so this core runs both on the page and inside each worker.
//
// When a playlist is an ad:
//   1. Drop the ad segments if live ones are mixed in.
//   2. Otherwise (the whole playlist is ads) ask Twitch for the same stream as another player
//      type, which usually carries no ads, and swap that playlist in.
//   3. If that fails the ad plays, and the page-side fallback below mutes it.
(() => {
  if (!/(^|\.)twitch\.tv$/.test(location.hostname)) return;
  window.__adfree = 'twitch';

  function adfreeCore(cfg) {
    const g = typeof window !== 'undefined' ? window : self;
    const realFetch = g.fetch.bind(g);
    const bus = new BroadcastChannel('adfree-bus');
    const state = { gql: null, usher: null, variants: [] }; // how the player asked for the stream
    const cache = {};                                        // player type -> { t, variants }
    let inAd = false;

    const isAd = (t) => /stitched|X-TV-TWITCH-AD/i.test(t);
    const urlOf = (i) => (typeof i === 'string' ? i : (i && i.url) || '');
    const headersToObj = (h) => {
      const o = {};
      if (!h) return o;
      if (typeof Headers !== 'undefined' && h instanceof Headers) h.forEach((v, k) => { o[k] = v; });
      else if (Array.isArray(h)) h.forEach(([k, v]) => { o[k] = v; });
      else Object.assign(o, h);
      return o;
    };
    const share = () => bus.postMessage({ t: 'state', state });
    const reportAd = () => { if (cfg.onAd) cfg.onAd(); else bus.postMessage({ t: 'ad' }); };
    const sample = (kind, text) => {
      if (cfg.onSample) cfg.onSample(kind, text); else bus.postMessage({ t: 'sample', kind, text });
    };

    bus.onmessage = (e) => {
      const m = e.data;
      if (!m || typeof m !== 'object') return;
      if (m.t === 'state' && m.state) {
        for (const k of ['gql', 'usher']) if (m.state[k]) state[k] = m.state[k];
        if (m.state.variants && m.state.variants.length) state.variants = m.state.variants;
      } else if (m.t === 'hello' && (state.gql || state.usher)) share();
      else if (m.t === 'ad' && cfg.onAd) cfg.onAd();
      else if (m.t === 'sample' && cfg.onSample) cfg.onSample(m.kind, m.text);
    };
    bus.postMessage({ t: 'hello' });

    const parseMaster = (text) => {
      const lines = text.split('\n');
      const out = [];
      for (let i = 0; i < lines.length; i++) {
        if (!lines[i].startsWith('#EXT-X-STREAM-INF')) continue;
        const res = /RESOLUTION=(\d+x\d+)/.exec(lines[i]);
        const url = (lines[i + 1] || '').trim();
        if (url && !url.startsWith('#')) out.push({ res: res ? res[1] : null, url });
      }
      return out;
    };

    // Keep only segments Twitch labels "live". Null if none are left (the whole thing is ads).
    const stripAds = (text) => {
      const lines = text.split('\n');
      const out = [];
      let kept = 0;
      for (let i = 0; i < lines.length; i++) {
        const l = lines[i];
        if (l.startsWith('#EXTINF')) {
          if (/,\s*live/i.test(l)) { out.push(l, lines[i + 1]); kept++; }
          i++;
        } else if (!/^#EXT-X-DATERANGE.*(stitched|twitch-ad)/i.test(l) && !/^#EXT-X-TWITCH-PREFETCH/.test(l)) {
          out.push(l);
        }
      }
      return kept > 0 ? out.join('\n') : null;
    };

    // Ask for a playback token as another player type, then load that stream's master playlist.
    async function masterFor(playerType) {
      const c = cache[playerType];
      if (c && Date.now() - c.t < 180000) return c.variants;
      const parsed = JSON.parse(state.gql.body);
      const ops = Array.isArray(parsed) ? parsed : [parsed];
      for (const op of ops) {
        if (/PlaybackAccessToken/.test(op.operationName || '')) {
          op.variables = Object.assign({}, op.variables, { playerType });
        }
      }
      const r = await realFetch('https://gql.twitch.tv/gql', {
        method: 'POST', headers: state.gql.headers, body: JSON.stringify(Array.isArray(parsed) ? ops : ops[0]),
      });
      const j = await r.json();
      const tok = (Array.isArray(j) ? j : [j]).map((x) => x && x.data && x.data.streamPlaybackAccessToken).find(Boolean);
      if (!tok) return null;
      const u = new URL(state.usher);
      u.searchParams.set('token', tok.value);
      u.searchParams.set('sig', tok.signature);
      const mr = await realFetch(u.href);
      if (!mr.ok) return null;
      const variants = parseMaster(await mr.text());
      if (!variants.length) return null;
      cache[playerType] = { t: Date.now(), variants };
      return variants;
    }

    async function fetchBackup(adUrl) {
      if (!state.gql || !state.usher) return null;
      const own = state.variants.find((v) => v.url === adUrl);
      for (const playerType of ['embed', 'popout', 'autoplay', 'picture-by-picture']) {
        try {
          const variants = await masterFor(playerType);
          if (!variants) continue;
          const pick = (own && variants.find((v) => v.res === own.res)) || variants[0];
          const r = await realFetch(pick.url);
          if (!r.ok) continue;
          const text = await r.text();
          if (!isAd(text)) return text;
        } catch (e) {}
      }
      return null;
    }

    const rebuild = (res, text) =>
      new Response(text, { status: res.status, statusText: res.statusText, headers: res.headers });

    g.fetch = async function (input, init) {
      const url = urlOf(input);
      // Remember how the player requests stream access, so we can repeat it as another player type.
      if (/gql\.twitch\.tv\/gql/.test(url) && init && typeof init.body === 'string' && /PlaybackAccessToken/.test(init.body)) {
        state.gql = { headers: headersToObj(init.headers), body: init.body };
        share();
      }
      const isUsher = /usher\.ttvnw\.net\/api\/.*channel\/hls\/[^/?]+\.m3u8/i.test(url);
      if (isUsher) { state.usher = url; share(); }

      const res = await realFetch(input, init);
      if (!/\.m3u8/i.test(url)) return res;

      if (isUsher) {
        res.clone().text().then((t) => { state.variants = parseMaster(t); share(); }).catch(() => {});
        return res;
      }

      const text = await res.clone().text();
      if (!cfg.force && !isAd(text)) {
        if (cfg.debug && !cfg.sampledNormal) { cfg.sampledNormal = true; sample('normal', text.slice(0, 900)); }
        inAd = false;
        return res;
      }
      if (!inAd) { inAd = true; reportAd(); sample('ad', text.slice(0, 1500)); }

      if (!cfg.force) {
        const stripped = stripAds(text);
        if (stripped) return rebuild(res, stripped);
      }
      const backup = await fetchBackup(url);
      if (cfg.debug) sample('backup', backup ? 'swapped in an ad-free playlist' : 'no ad-free playlist found');
      return rebuild(res, backup || text);
    };
  }

  const report = () => { try { webkit.messageHandlers.adfree.postMessage({ ad: 1, site: 'twitch' }); } catch (e) {} };
  const cfg = {
    force: !!window.__adfreeForce, debug: !!window.__adfreeDebug,
    onAd: report,
    onSample: (kind, text) => {
      window.__adfreeSample = kind + ': ' + text;
      if (window.__adfreeDebug) { try { webkit.messageHandlers.log.postMessage('SAMPLE ' + kind + ' :: ' + text.slice(0, 700)); } catch (e) {} }
    },
  };
  adfreeCore(cfg);

  // Read a script's source on the main thread. Blob URLs can't be importScripts()'d from our
  // wrapper worker in WebKit, so we inline the original code instead.
  const readSource = (url) => {
    try {
      const x = new XMLHttpRequest();
      x.open('GET', url, false);
      x.send();
      if ((x.status === 200 || x.status === 0) && x.responseText) return x.responseText;
    } catch (e) {}
    return null;
  };

  const RealWorker = window.Worker;
  window.Worker = class extends RealWorker {
    constructor(url, opts) {
      if (opts && opts.type === 'module') return super(url, opts);
      const abs = new URL(String(url), location.href).href;
      const original = readSource(abs);
      const body = original !== null ? original : `importScripts(${JSON.stringify(abs)});`;
      const wcfg = { force: cfg.force, debug: cfg.debug };
      const src = `(${adfreeCore.toString()})(${JSON.stringify(wcfg)});\n${body}`;
      super(URL.createObjectURL(new Blob([src], { type: 'application/javascript' })), opts);
    }
  };

  // Fallback: if an ad still plays, mute it until it ends. Counts once per ad.
  let mutedByUs = false;
  let adSeen = false;
  setInterval(() => {
    const video = document.querySelector('video');
    if (!video) return;
    const ad = document.querySelector('[data-a-target="video-ad-label"], [data-test-selector="ad-banner-default-text"]');
    if (ad) {
      if (!adSeen) { adSeen = true; report(); }
      if (!video.muted) { video.muted = true; mutedByUs = true; }
    } else {
      adSeen = false;
      if (mutedByUs) { video.muted = false; mutedByUs = false; }
    }
  }, 500);
})();
