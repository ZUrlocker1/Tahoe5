# Tahoe5 — native app

A native Mac / iPad / iPhone shell around the Tahoe5 video poker web game.

`Web/` holds the game itself — `index.html`, `styles.css`, `app.js`, `assets/`.
Everything else here is roughly 200 lines of Swift whose only job is to put that
in a window and give it an icon.

## Status

**Mac: shipped**, as a signed and notarized DMG on this repo's
[releases page](https://github.com/ZUrlocker1/Tahoe5/releases/latest). Requires
macOS 14 or later, universal for Apple silicon and Intel.

**iOS: built, works, not distributed.** It runs fine on iPhone and iPad and the
layouts are tuned for both. It was submitted to the App Store and rejected under
guideline 2.3.6: Apple does not permit *individual* developers to publish apps
whose age rating declares simulated gambling. The rating is accurate — the game
has betting, a bankroll and a payout table — so there is nothing to appeal. The
only route Apple offers is enrolling as an organization, which requires forming
a real legal entity; they reject sole proprietorships and DBAs. Not worth it for
a hobby game. The web version covers iPhone and iPad instead.

That is worth knowing before you copy this project: **the Mac half of this
approach is viable and the iOS half is closed** to individuals for anything
gambling-adjacent.

> **`Web/` is a frozen fork.** It began as a copy of the web version's `app/`
> directory (what GitHub Pages serves) but that was a **one-way conversion**,
> completed. The two are deliberately not in sync and neither is being updated.
> Edit `Web/` directly; do not copy `app/` over it, which would revert the
> native-only work.
>
> Diverged so far: the About panel's "Source code here: github.com/..." line is
> replaced with "Claude wrapped it in a native Mac and iOS app using WebKit"; a
> cross-promotion link to Tahoe21 in the footer; and a substantial amount of
> responsive CSS for iPad sizes and small Mac windows that the web version never
> needed. Roughly 170 lines of `styles.css` differ, plus smaller changes in
> `app.js` and `index.html`.

## Build and run

```bash
brew install xcodegen     # once
bash setup.sh
open Tahoe5.xcodeproj
```

Pick a destination in the toolbar — My Mac, or any iPhone / iPad simulator —
and press ⌘R. One target covers all three.

If you are not me, change `DEVELOPMENT_TEAM` in `project.yml` to your own team
ID and re-run `setup.sh`, or signing will fail. The team ID left in there
(`K66MA9TR8Z`) is not a secret — it is embedded in every signed app on the
store — but it is not yours.

`Tahoe5.xcodeproj` is generated from `project.yml` and is gitignored. Re-run
`setup.sh` after editing `project.yml` or adding a file to `Sources/`. Files
added under `Web/` need no regeneration — it is a folder reference, so whatever
is in the directory gets bundled.

## Layout

| Path | |
|---|---|
| `project.yml` | XcodeGen config — the real project definition |
| `Sources/App/Tahoe5App.swift` | SwiftUI entry point, window sizing |
| `Sources/App/GameWebView.swift` | The web view, platform wrappers, link handling |
| `Sources/App/BundleSchemeHandler.swift` | Serves `Web/` over a custom URL scheme |
| `Sources/Info.plist` | Shared across both platforms |
| `Tahoe5.entitlements` | Sandbox + the WKWebView network entitlement |
| `Web/` | The game — a frozen fork of the web version's `app/` |
| `make_icons.py` | Builds the AppIcon set from the game logo |
| `setup.sh` | Runs XcodeGen to regenerate the `.xcodeproj` |
| `release-dmg.sh` | Packages a notarized `.app` into a drag-to-install DMG |

## Four things worth knowing

**One target, three devices.** `supportedDestinations: [macOS, iOS]` builds a
multiplatform app. One bundle ID across Mac and iOS means one App Store listing
and Universal Purchase, rather than two listings and two review cycles for the
same game.

**A custom URL scheme, not `file://`.** `index.html` references
`styles.css?v=1.5.0`. Those query strings bust the GitHub Pages CDN and mean
nothing locally, but over `file://` WebKit resolves the literal path and the
request can fail. `BundleSchemeHandler` drops the query, so the bundled files
keep the query strings they were authored with. It also gives the page a stable
origin —
`file://` origins are opaque, which makes `localStorage` unreliable there.
Nothing uses it yet (the balance resets on every launch), but adding
persistence later won't mean re-plumbing how the app loads.

**A sandboxed Mac app needs `com.apple.security.network.client` to use
WKWebView at all** — even with zero network requests. WebKit runs its
networking in a separate XPC process which cannot start without it. The failure
mode is nasty: the window renders plain white, with no error, no delegate
callback, and no log line. Cost several rounds of debugging; don't remove it
thinking the game doesn't need network, because that isn't what it gates. iOS
is unaffected.

**External links leave the app.** The footer's cross-promo link carries
`target="_blank"`. Those never reach `decidePolicyFor` — WebKit
asks the UI delegate for a new web view and silently drops them when there
isn't one. `WebViewCoordinator` implements both delegates and hands http(s)
URLs to the system browser.

## Cutting a Mac release

1. **Bump `CURRENT_PROJECT_VERSION`** (and `MARKETING_VERSION` if the version
   is changing) in `project.yml`, then re-run `setup.sh`.
2. In Xcode: **Product → Archive**, then **Distribute App → Direct
   Distribution**. Apple notarizes it and staples the ticket. Export the `.app`
   from the Organizer.
3. `./release-dmg.sh /path/to/Tahoe5.app` — builds a signed drag-to-install DMG
   at `~/Downloads/Tahoe5.dmg`.
4. Attach the DMG to a GitHub release. The README links point at
   `releases/latest/download/Tahoe5.dmg`, so the filename must stay stable.

The script refuses to package an ad-hoc signed Debug build, which would launch
on your Mac and nowhere else. Verify the export before shipping:

```bash
xcrun stapler validate Tahoe5.app          # -> "The validate action worked!"
spctl --assess --type exec -v Tahoe5.app   # -> "source=Notarized Developer ID"
```

What matters for Gatekeeper is that the **`.app`** is notarized and stapled — a
stapled ticket validates offline. Notarizing the DMG as well is Apple's
belt-and-braces suggestion, not a requirement.

Still worth doing at some point: **replace the app icon.** `make_icons.py`
upscales the 342px logo, so 512 and 1024 are soft. Drop real 1024px artwork in
and re-run it.

## Portrait type scaling

Portrait font sizes are `clamp()`-based, keyed to viewport height: the floor is
the size at 660px tall (Safari on a notched iPhone, and the SE), the max is
reached at 760px. Short phones and the web render exactly as before; the native
app, which has no browser chrome, gets ~18% larger text.

The top anchor is 760, not 860. Anchored at 860 an iPhone 15/16/17 (759px web
view) landed mid-range and the change was barely visible.

The footer is the exception — it scales on **width**, because that row holds the
promo link, version and copyright side by side and wraps before it runs out of
height.

## Cross-promotion

The footer link points at the developer page:
`https://apps.apple.com/us/developer/zack-urlocker/id1893448954`

It is a plain `https://` URL, so `WebViewCoordinator` hands it to the system and
it opens in the App Store app — no URL scheme registration or StoreKit needed.

The developer page was chosen because Tahoe21 had no App Store ID yet. Given the
2.3.6 rejection above it never will, so this stays pointed at the developer page
rather than a direct app link. If you fork this for a non-gambling app, a direct
`https://apps.apple.com/app/id<APP_ID>` link is the better target.

Keep the link text short. The footer row is width-constrained and wraps above
0.72rem at 393px wide; "Try Tahoe21 blackjack!" already sits near that limit.
