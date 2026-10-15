# Artifact 2 — AdFree (ad blocker)

## Devlog

------------------------------------------------------------------------

### What I set out to build

An ad blocker for YouTube and Twitch that keeps their normal features.
I first thought about pulling the video stream out of the page and
casting it to another device, then realized I wanted to watch on the same
Mac. That led to a macOS app that opens the real sites with blocking
built in, instead of a Safari extension.

------------------------------------------------------------------------

### What I asked for and what changed

-   **Skeleton app.** A SwiftUI window around a `WKWebView`, with three
    blocking layers: network rules, a YouTube script and a Twitch script.
    Google sign-in worked straight away, so history and subscriptions
    came with it.
-   **Link restriction.** Only YouTube and Twitch open; anything else
    goes to YouTube. Later I removed the address bar and narrowed the
    Google exception to sign-in pages only.
-   **"Ads showing?" panel.** Steps to try when an ad gets through,
    including a copyable diagnosis report.
-   **YouTube skipping to the end of ads.** That was my fallback, not
    the main blocker. I improved the stripping of ad data and made the
    fallback hide and mute the ad.
-   **Twitch black screen.** With blocking on, streams showed a black
    screen and a spinner. I built a headless self-test that loads a live
    channel and checks whether video is advancing, then turned layers off
    one at a time. The network rules were fine; the Twitch script's
    worker wrapper was the problem. I fixed it by inlining the original
    worker code instead of calling `importScripts` on a blob URL.
-   **Settings.** An editable allowed-sites list, an in-app editor for
    the rules and scripts, switches for each blocking layer, and an
    ads-skipped counter.
-   **Saved sites.** A start page that shows only saved sites.
-   **Sandbox.** The app now runs in the macOS App Sandbox.
-   **Usage guide.** A page on the portfolio covering install, use and
    modification.

------------------------------------------------------------------------

### What I decided

-   Own app instead of a browser extension, so I control the whole
    environment and the link restriction.
-   Rules and scripts stay plain files so they can be fixed without
    touching Swift.
-   A custom copy of a script exists only after I save an edit in
    Settings, because a stale copy silently overrides the app's own
    fixed version.
-   Allowed-site and script editing live together in Settings, with
    a confirmation before a site is added.

------------------------------------------------------------------------

### What I abandoned

-   Casting the stream to another device.
-   An address bar; YouTube's and Twitch's own search is enough.
-   A "developer mode" for editing; the in-app editor replaced it.
-   Locking the scripts folder to my user. It adds almost nothing.

------------------------------------------------------------------------

### Things still open

-   Tracker blocking, maybe later.
-   A Safari or other browser extension version.
-   A native "play without the page" fallback using `yt-dlp` or
    `streamlink`, if page-level blocking stops working.
-   Merging `artifact-2-adblocker` into `main`.
