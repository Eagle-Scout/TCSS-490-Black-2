# Dailymotion ad-blocking session log

Date: 2026-10-24
Site: dailymotion.com (added to AdFree's allowed list by the user)
Goal: remove preroll ads, banners, promotions.

## Timeline

1. **Initial state.** `list_sites` showed dailymotion.com with no site rules. Blocking layers were on (rules, youtube-script, yt-dlp-player; twitch-script off).
2. **Homepage snapshot** (`open_site` + `get_page_snapshot`). The only candidate element was the sticky header, which is navigation and was left alone. Third-party hosts seen:
   - Ad-related: `dmads.dailymotion.com`, `cdn.hubvisor.io`, `boot.pbstck.com`
   - Consent manager (left alone): `cdn.privacy-mgmt.com`, `launchpad.privacymanager.io`, `launchpad-wrapper.privacymanager.io`, `ats-wrapper.privacymanager.io`
   - Site/CDN (left alone): `s1/s2/static1.dmcdn.net`, `static.neon-ssr.dailymotion.com`, `geo.dailymotion.com`, `api.dailymotion.com`, `graphql.api.dailymotion.com`
   - Rules set: block `dmads.dailymotion.com`, `cdn.hubvisor.io`, `boot.pbstck.com`. No hidden selectors.
3. **Video page snapshots** (user had a preroll playing; videos `x9gyvko`, then `xa1ojkm`). Both snapshots showed the same hosts as before and no new ad domains. Candidates were the player wrapper, the player iframe (`geo.dailymotion.com`), the header, and a hidden `#continuous-player`. None were hidden.
   - Finding: the preroll runs inside the player iframe, whose network requests the snapshot cannot see. Unlike YouTube, new ad domains have to come from the user, as they appear.
4. **User report: `rtb-us-east.linkedin.com`** ("or something like that") served the ad.
   - Rule added: `.*rtb[^./]*\.linkedin\.com` (any `rtb*` LinkedIn subdomain, not all of linkedin.com).
   - Caveat given: if that request was already blocked, the ad could still come from another bidder.
5. **User report: `ad.doubleclick.net`**, and a request to add common ad providers. Rules were set for:
   - Google: `doubleclick.net`, `googlesyndication.com`, `googleadservices.com`, `imasdk.googleapis.com`, `adservice.google.com`
   - Verification: `moatads.com`, `adsafeprotected.com`
   - Exchanges / ad servers: `amazon-adsystem.com`, `adnxs.com`, `pubmatic.com`, `rubiconproject.com`, `openx.net`, `criteo.com`, `criteo.net`, `casalemedia.com`, `smartadserver.com`, `adform.net`, `3lift.com`, `sharethrough.com`, `indexww.com`, `bidswitch.net`, `adsrvr.org`
   - Video: `teads.tv`, `spotxchange.com`, `springserve.com`
   - Native: `taboola.com`, `outbrain.com`
   - Deliberately not blocked: shared domains such as `googleapis.com` and `google.com`, which could break the player or page.
   - First attempt failed: WebKit rejected the regex `criteo\.(com|net)`. url-filter does not support `(a|b)` alternation. Fixed by using two separate patterns.
6. **Outcome.** User reported that the ad blocking seems to be working.

## Final saved rules (31 block patterns, 0 hidden selectors)

```
.*dmads\.dailymotion\.com
.*cdn\.hubvisor\.io
.*boot\.pbstck\.com
.*rtb[^./]*\.linkedin\.com
.*doubleclick\.net
.*googlesyndication\.com
.*googleadservices\.com
.*imasdk\.googleapis\.com
.*adservice\.google\.com
.*moatads\.com
.*adsafeprotected\.com
.*amazon-adsystem\.com
.*adnxs\.com
.*pubmatic\.com
.*rubiconproject\.com
.*openx\.net
.*criteo\.com
.*criteo\.net
.*casalemedia\.com
.*smartadserver\.com
.*taboola\.com
.*outbrain\.com
.*teads\.tv
.*spotxchange\.com
.*springserve\.com
.*adform\.net
.*3lift\.com
.*sharethrough\.com
.*indexww\.com
.*bidswitch\.net
.*adsrvr\.org
```

## Notes

- `set_site_rules` replaces the whole rule set for a site, so each call must include all earlier patterns.
- To undo everything: `clear_site_rules` for dailymotion.com.
- Workflow going forward: when a preroll or banner still appears, the user reports the blocked or loading host and it gets added to the list.
