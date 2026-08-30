# FinTrack — building and running

SwiftUI recreation of the `FinTrack.dc.html` prototype. iOS 17.0+, portrait, no third-party
dependencies.

## Open it

```bash
open FinTrack.xcodeproj
```

Then ⌘R. The scheme is `FinTrack`, bundle id `com.agilmuhad.fintrack`.

The simulator needs no signing and works from a fresh clone. **To build to a device**, copy
`Config/Local.xcconfig.example` to `Config/Local.xcconfig` and put your own `DEVELOPMENT_TEAM` in
it. That file is gitignored — a team ID identifies an Apple Developer account and is deliberately
kept out of the repo — and `Config/Shared.xcconfig` includes it optionally, so its absence never
breaks a simulator build.

Installing over a wireless device pairing:

```bash
xcodebuild -project FinTrack.xcodeproj -scheme FinTrack -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath .build/DeviceBuild \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device <device-id> \
  .build/DeviceBuild/Build/Products/Debug-iphoneos/FinTrack.app
```

First launch needs the developer certificate trusted on the phone (Settings → General → VPN &
Device Management), which requires internet once. On a free Apple team the build expires after
7 days and must be reinstalled.

## Build from the command line

```bash
./build.sh
```

Prints only errors and the final status. It serialises behind an atomic lock because several
processes may share one derived-data path; a run can pause briefly while another finishes.

## Project layout

`FinTrack.xcodeproj` uses a **file-system-synchronized root group**, so every `.swift` file under
`FinTrack/` is compiled automatically — adding a file needs no project edit. `Info.plist` is the one
membership exception (otherwise it is also copied as a bundle resource and the build fails with a
duplicate-output error).

```
FinTrack/
  Core/       models, AppStore, persistence, formatting   — no SwiftUI
  Design/     tokens, typography, motion, icons, components — no Core dependency
  App/        UIState, RootView, TabBarView, alert, debug hooks
  Features/   one folder per screen
```

`Core` and `Design` are independent of each other; every feature depends on both. Views read
`@Environment(AppStore.self)`, `@Environment(UIState.self)` and `@Environment(\.theme)`.

## The money coach

The Coach tab talks to a **local Ollama** — nothing leaves your network and there is no API key.

The address resolves from, in order: the `-FTCoachHost` launch argument, the `coach_host` user
default, else `http://127.0.0.1:11434`. Loopback is correct in the **simulator**, which shares the
Mac's, but on a **real iPhone** loopback is the phone itself, so a device build must be pointed at
the Mac's LAN address via **iOS Settings → FinTrack → Coach server** (the app ships a
`Settings.bundle` for exactly this). Two further requirements on device:

- Ollama must listen beyond loopback. The macOS app ignores `OLLAMA_HOST`; the setting is
  "expose to the network" in its own preferences, which makes it bind `*:11434`. This exposes your
  models to everyone on the network.
- iOS gates local-network access behind a permission prompt (`NSLocalNetworkUsageDescription`).
  Until it is allowed the connection fails silently and the coach uses its offline answers.

```bash
ollama serve            # if it is not already running
ollama pull qwen3.5:9b  # the default; see the preference list below
```

Model resolution: `qwen3.5:9b`, else `qwen2.5:7b`, `qwen3.5:4b`, `llama3.2:3b`, `llama3.2:1b`,
`gemma3:1b`, else the first model `/api/tags` reports. The tab warms the model on appear and the
request sends `keep_alive: 30m`, so only the first message of a session pays the load cost.

The request also sends **`think: false`**, which matters a great deal. Qwen 3.5 is a reasoning
model, and left to itself it spends nearly all of its output budget on hidden thinking. Measured on
this machine with the coach's own prompt:

| model | thinking | time | tokens |
|---|---|---|---|
| qwen3.5:9b | on | ~4 min | ~2000 |
| qwen3.5:9b | **off** | **21 s** | 107 |
| qwen3.5:4b | on | 130 s | 1982 |
| qwen3.5:4b | **off** | **7 s** | 100 |

Answer quality is unchanged — the coach wants a short plain-text verdict, not a derivation. Ollama
accepts the flag for non-thinking models too (verified against `llama3.2:1b`), so it is sent
unconditionally. `<think>` blocks are still stripped from replies as a fallback for models that
ignore the flag.

**With Ollama stopped the app still works** — the coach falls back to the prototype's deterministic
preview answer, computed from real data.

## Notifications

Permission is requested only when the user changes a reminder time or finishes onboarding — never
as a cold prompt at launch. Two repeating daily local notifications are registered
(`fintrack.reminder.am` / `.pm`) and re-registered whenever the times or the coach name change.

## Debug launch arguments (DEBUG builds only)

Compiled out of Release. Useful for jumping straight to a screen:

```bash
xcrun simctl launch "iPhone 17 Pro" com.fintrack.app -FTTab loans -FTDark 1 -FTNoBanner 1
```

| Argument | Values |
|---|---|
| `-FTTab` | `home` `activity` `loans` `coach` |
| `-FTDark` | `1` `0` |
| `-FTMode` | `personal` `business` |
| `-FTOverlay` | `entry` `settings` `wizard` `alert` `banner` `loan:<i>` `milestone:<i>` `account:<i>` |
| `-FTFresh` | `1` — start from a blank ledger (**persists**; delete the saved file to undo) |
| `-FTNoBanner` | `1` — suppress the timed launch banner |
| `-FTDemo` | `1` — restore the seeded demo ledger before the UI appears |
| `-FTAsk` | `"<text>"` — send one real message to the coach on launch |
| `-FTCoachHost` | `"<addr>"` — set the Ollama address; **persisted** to `coach_host` |
| `-FTMilestoneDates` | `1` — give the seeded milestones dates (+12mo, +4mo, 12 days overdue) |

On a device, arguments go after a `--` separator:

```bash
xcrun devicectl device process launch --device <id> com.agilmuhad.fintrack \
  -- -FTCoachHost 192.168.1.42 -FTAsk "Can I afford dinner out?"
```

Saved state lives at `Library/Application Support/fintrack-v1.json` inside the app container
(`xcrun simctl get_app_container "iPhone 17 Pro" com.fintrack.app data`).

## Milestone target dates

Milestones carry an **optional** `targetDate`. With one set, the app derives a single
number — what finishing on time costs per month — shown on the Home card and stated in
full on the milestone detail screen, plus an overdue state. Clearing the date returns the
goal to open-ended.

There is deliberately **no "on track" indicator**. Judging pace needs a contribution
history and `Transaction` carries no timestamp, only a day-group label; deriving it from
`bucketSpend.savings` would be wrong because that bucket pools every goal. Adding
per-deposit timestamps is the prerequisite if that signal is ever wanted.

Months remaining are rounded **up** — a partial month is still a month in which a
contribution can be made, and rounding down would overstate the monthly figure.

`MilestonePaceTests` guards the fidelity promise: **an undated milestone renders exactly
as the prototype does.** That was verified once by pixel-diffing Home against a
pre-feature baseline (identical but for the status-bar clock) and is now held by tests.

## Known deviations from the prototype

- The date header and the budget month are derived from the current date rather than the
  prototype's hard-coded "Saturday, Aug 30" / "August".
- The prototype's `padding-top: 58px` is the mock device frame's status bar, not app padding; the
  real safe area supplies it instead, so it is not reproduced literally.
- Amount fields parse with the **device locale** (en_US "1,500" → 1500, de_DE "1.500" → 1500). The
  prototype relied on `<input type="number">`, which simply rejects grouped input.
- Export writes a JSON file and opens the share sheet; the prototype only flipped its label.
- Apostrophes match the prototype's ASCII `'` rather than typographic `'`. Em dashes, middle dots
  and the U+2212 minus sign in amounts are typographic, as in the source.
- **The Home milestone card gains a pace line when a target date is set** — the first
  deliberate departure from a layout the spec pinned as final, taken knowingly. Undated
  milestones are unchanged.

## Tests

The two drag gestures are the only behaviour a build cannot check and `xcrun simctl` cannot drive
(it has no touch input), so they have their own XCUITest target, `FinTrackUITests`.

```bash
./test.sh
```

or from Xcode, ⌘U on the `FinTrack` scheme.

`SwipeToDeleteTests` and `EntrySheetDragTests` assert the actual release rules from the prototype's
pointer handlers, not merely that a swipe does something:

| gesture | rule under test |
|---|---|
| row swipe | deletes past `dx < -80` |
| row swipe | springs back at -50pt (past the flick distance, short of -80, too slow to flick) |
| row swipe | ignores a 12pt drag |
| row swipe | a fast flick deletes at only -45pt (`dx < -24 && velocity < -0.11 px/ms`) |
| row swipe | a vertical pan scrolls and never deletes |
| row swipe | the delete is persisted, verified by relaunching |
| row swipe | emptying a day group removes its header |
| sheet drag | dismisses past `dy > 140` |
| sheet drag | springs back at 80pt |
| sheet drag | a fast flick dismisses at only 60pt |
| sheet drag | upward drag is resisted and never dismisses |
| sheet drag | only the grabber carries the gesture — dragging the body does nothing |
| sheet drag | tapping the scrim dismisses |

The tests drive gestures with `press(forDuration:thenDragTo:)` rather than `swipeLeft()`, because
the thresholds are the thing being tested and `swipeLeft()` gives no control over distance or
velocity. Velocity is pinned explicitly — `XCUIGestureVelocity(50)` (0.05 px/ms, under the
threshold) for the spring-back cases and `800` (0.8 px/ms, over it) for flicks — so each test
exercises exactly one branch of the release rule.

### What this suite caught

Both gestures under-reported finger travel by roughly half. Each `DragGesture` was attached to a
view that the gesture itself translates (the grabber lives inside the sheet that `dragOffset` moves;
the row hosts its own gesture and is moved by `offset`), and SwiftUI's default `.local` coordinate
space measures translation relative to that moving view. A 260pt drag registered as ~120pt, so the
sheet's `dy > 140` branch could never fire and every distance threshold was effectively doubled for
real users. Both gestures now use `coordinateSpace: .global`, which is what the prototype's
`ev.clientY` (viewport coordinates) actually means.

This was invisible to a green build and survived two code-review passes. It only appeared by driving
the real gesture and reading the frames out of the failure recording. Each test launches a fresh app with `-FTNoBanner 1` so the launch banner never overlays
the target, and the rows are addressed through `ft.row.<title>` accessibility identifiers.
