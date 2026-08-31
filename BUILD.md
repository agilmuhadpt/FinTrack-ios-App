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
Device Management), which requires internet once.

### Renewing the 7-day profile

On a free Apple team the provisioning profile lasts 7 days, after which the app stops
launching. **Rebuilding is not enough on its own.** Xcode reuses a cached profile while it
is still valid, so a clean rebuild embeds the *same* expiry — verified: rebuilding a
profile dated 2026-09-06 produced a build still dated 2026-09-06. The cached profile has to
be evicted first:

```bash
rm ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision
xcodebuild -project FinTrack.xcodeproj -scheme FinTrack -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath .build/ReleaseBuild -allowProvisioningUpdates build
xcrun devicectl device install app --device <device-id> \
  .build/ReleaseBuild/Build/Products/Release-iphoneos/FinTrack.app
```

Confirm it actually renewed rather than assuming:

```bash
security cms -D -i .build/ReleaseBuild/Build/Products/Release-iphoneos/FinTrack.app/embedded.mobileprovision \
  | grep -A1 ExpirationDate
```

This recurs weekly and cannot be avoided on a free team; a paid Developer Program
membership extends provisioning to a year.

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
ollama pull qwen3.5:4b  # the default; see the preference list below
```

Model resolution: `qwen3.5:4b`, else `qwen3:8b`, `qwen3.5:9b`, `qwen2.5:7b`, `llama3.2:3b`,
`llama3.2:1b`, else the first model `/api/tags` reports. `gemma3:4b` is deliberately absent
— see below. The tab warms the model on appear and the
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

### What the coach is told, and what it still gets wrong

Every derived figure is sent explicitly — `remaining`, `monthsRemaining`, `requiredPerMonth`,
and a `status` of `"overdue by N days"` / `"complete"`. The rule this follows was learned
the hard way: **numbers handed to the model come back correct; numbers it has to derive
come back wrong.** Given only `targetDate: "Dec 2026"` it reported the Travel fund as
"12 months" left — a figure belonging to a different milestone.

The system prompt carries one sentence beyond the prototype's, telling it to use the
supplied values and to treat a milestone as finished only when `status` says so. That was
added after qwen3.5:9b, handed `saved 2400 / target 12000 / remaining 9600`, opened with
"You crushed the Travel fund goal!".

Measured over five samples of an identical prompt afterwards: **0/5 false completion
claims** and **5/5 numerically correct**. What remains is characterisation — 4/5 still
volunteered "you're crushing it" or "you're on track", once contradicting itself
("crushing your Loan collection goal, but it's overdue by 12 days"). Note the demo tone is
Playful and the prompt asks for "warm, playful", so enthusiasm is requested; the defect is
enthusiasm that contradicts the data. No snapshot field fixes this. Treat the coach's
figures as reliable and its verdicts as not.

**"A stronger model is the lever" was wrong**, and this section said so until it was
measured. Three runs per model against the real prompt with `think:false`, on a 16GB M5:

| model | size | seconds | invented figures | markdown | false verdict |
|---|---|---|---|---|---|
| `qwen3.5:4b` | 3.4GB | 6.6-10.6 | 0/3 | 0/3 | **0/3** |
| `qwen3:8b` | 5.2GB | 9.9-11.0 | 0/3 | **3/3** | 1/3 |
| `qwen3.5:9b` | 6.6GB | 14.9-16.0 | **2/3** | 0/3 | 1/3 |
| `gemma3:4b` | 3.3GB | 8.6-9.4 | 1/3 | 0/3 | **3/3** |

The largest model was the worst: slowest, and the only one to invent figures — it summed
the two debts into "15000 SAR total" and produced 450 and 600 from nowhere, in a prompt
that says not to calculate. Size does not help when the task is recitation. The default is
now `qwen3.5:4b`, which was clean on every axis and half the memory.

`gemma3:4b` is excluded from the preference list: 3/3 false verdicts ("fantastic
progress", "you're crushing it", "you're on track") plus completion percentages it was
told not to derive, and it prefixes replies with "Okay, Leo here!". Its warmth is a
liability here.

`qwen3:8b` was the most accurate on the pace fields but bolded every reply, which the
coach bubble would render literally as `**Travel fund**`. `stripMarkdown` removes emphasis
the prompt already asked the model not to use; it is deliberately conservative, leaving a
lone `*`, an underscore inside a word, and `2 * 3` untouched.

**With Ollama stopped the app still works** — the coach falls back to the prototype's deterministic
preview answer, computed from real data.

### An unset server on device is now explicit

`host` resolves `-FTCoachHost`, then the "Coach server" field in iOS Settings, then
`COACH_DEFAULT_HOST` baked into `Info.plist` at build time, then loopback. Loopback is
right in the simulator and useless on a phone, where `127.0.0.1` is the phone itself.

That case used to produce the offline preview — text that reads like a working coach — so a
blank field was indistinguishable from a working one. It now returns a distinct
`.unconfigured` outcome naming the fix, and `warmUp`/`resolveModel` skip the doomed
connection entirely.

This matters because **installing the app fresh clears UserDefaults**, and with it the
Settings value. A device reinstall silently un-configures the coach; that is what happened
after the Release install, and it cost a session's debugging aimed at the network and the
model instead.

To have your own device builds come back configured, set `COACH_DEFAULT_HOST` in
`Config/Local.xcconfig` (gitignored — a LAN address is personal). Two traps, both verified
by building and reading the value back out of the built `Info.plist` rather than assuming:

- **Declare the empty default BEFORE `#include? "Local.xcconfig"`** in `Shared.xcconfig`.
  The last assignment wins, so declaring it after silently overwrote the local value.
- **Write it without a scheme** — `192.168.1.50:11434`. An xcconfig treats `//` as a
  comment, so `http://host` is truncated to `http:`. `normalised()` adds the scheme.

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

## Business expenses and the Studio bar

Business spend is recorded separately from personal, in `BusinessBucketSpend`
(Ops / Growth / Profit) alongside the personal `BucketSpend` (Needs / Wants / Savings).
`BusinessBucket` is a distinct type from `Bucket` on purpose: one shared enum would make
it possible for a "Needs" expense to land in the business bar.

The New Entry sheet shows a **Ledger** row for expenses only — income, loan payments and
milestone deposits behave identically in both modes — and it defaults to whichever mode
you were last in. Choosing Studio swaps the Bucket row to Ops / Growth / Profit and
routes the amount to `businessBucketSpend`.

The Home bar in business mode is now computed from those totals. It was previously a
hardcoded 48/22/30 carried over from the prototype, which recorded no business expenses
at all and so had nothing to compute from.

The demo seed is 3,180 / 1,120 / 1,900 = **51/18/31**, chosen so it does *not* reproduce
the prototype's old hardcoded 48/22/30 — reusing that ratio made a screenshot unable to
tell "computed" from "fake" and implied the business had spent in exactly that proportion.
`BusinessBudgetTests` proves the bar is live by recording an expense and asserting every
share moves (to 32/49/19), including the two buckets left untouched — only possible if the
denominator is real. Two further tests assert the ledgers stay separate in both
directions.

Business milestones can be funded, from the entry sheet (choose Studio under Ledger)
or by tapping the card on Home. A business deposit counts toward **Profit** — the business
mirror of Savings — so funding a goal also moves the Studio bar.

`DetailRoute.milestone` carries a `business` flag because `msPersonal` and `msBusiness` are
separate arrays and an index alone is ambiguous.

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
- **The New Entry sheet gains a Ledger row for expenses**, so business spending can be
  recorded and the Studio bar can be real rather than a fixed 48/22/30.
- **Business milestone cards are tappable.** The prototype gave them `open: () => {}`
  because they could not be funded; leaving them inert would strand the screen that funds
  them.
- While any overlay is presented, the tab content and tab bar are `.accessibilityHidden`.
  Without it VoiceOver walks into the screen behind a modal sheet and can activate it.
- Filled segmented controls are real `Button`s with an `.isSelected` trait. As `Text` with
  a tap gesture they had no button semantics: VoiceOver could not tell they were tappable
  or which was active, and Switch Control could not activate them. Rendering is unchanged
  (`FTNoEffectButtonStyle`) — the prototype gives them no pressed state.

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
