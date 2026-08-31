# Session Handoff — FinTrack iOS

_Session: 2026-08-31 · Save target: repo (`docs/`) · Internal artifact — not client-facing_

## Next-session focus

In descending order of likelihood:

1. **Renew the provisioning profile** — the free Apple team's profile expires
   **2026-09-07**, after which the app will not launch on the device. Note that rebuilding
   alone does NOT renew it; see Next actions.
2. **New feature work.** The app is complete against the prototype and has grown three
   features beyond it; nothing is half-finished.
3. **Coach quality**, if the user raises it — see Open threads for the known limitation.

## Current state

- **Position:** Complete and shipped. A **Release** build is installed and running on the
  user's iPhone (iPhone 16 Pro, iOS 26.6). Working tree clean at `8e93b5b`. 38 Swift files,
  **28/28 UI tests green** (`./test.sh`).
- **Done, beyond the original port** (all committed, all tested):
  - **Milestone target dates** — optional; with one set the app derives the required
    monthly contribution and an overdue state. No "on track" indicator: that needs a
    contribution history and `Transaction` has no timestamp.
  - **Business expenses** — `BusinessBucketSpend` (Ops/Growth/Profit) recorded via a
    Ledger row on the entry sheet. The Studio bar is computed from it; it was a
    hardcoded 48/22/30 before.
  - **Studio milestones are fundable** — deposits count toward Profit, so funding a
    goal also moves the business bar. `DetailRoute.milestone` carries a `business` flag.
  - **Coach snapshot** — sends `remaining`, `monthsRemaining`, `status`, plus business
    spend. One added prompt sentence guards against invented verdicts.
- **Three accessibility defects fixed**, each surfaced by a UI test failing, none by review:
  row deletion reachable only by gesture; filled segmented controls with no button
  semantics; overlays not removing the background from the accessibility tree.
- **In-flight:** Nothing. All work is committed.
- **Not started:** Release performance is unprofiled. The app has run on no device but
  this one.

## Next actions

1. **If the app will not launch on the phone**, the profile has expired (2026-09-07).
   **Rebuilding alone does not renew it** — Xcode reuses a cached profile while it is still
   valid, so a clean rebuild embeds the same expiry (verified). Evict the cache first:
   ```bash
   rm ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision
   xcodebuild -project FinTrack.xcodeproj -scheme FinTrack -configuration Release \
     -sdk iphoneos -destination 'generic/platform=iOS' \
     -derivedDataPath .build/ReleaseBuild -allowProvisioningUpdates build
   xcrun devicectl device install app --device <device-id> \
     .build/ReleaseBuild/Build/Products/Release-iphoneos/FinTrack.app
   ```
   Then confirm the new date rather than assuming — `security cms -D -i <app>/
   embedded.mobileprovision | grep -A1 ExpirationDate`. Full recipe in `BUILD.md`.
   Needs `Config/Local.xcconfig` locally with a `DEVELOPMENT_TEAM`. **Use a USB cable** —
   the wireless pairing dropped repeatedly across the session; over USB it worked first try
   every time.
2. **If the coach falls back to its offline answer**, check in order: Ollama running and
   exposed beyond loopback; the Mac's *current* LAN address set under **iOS Settings →
   FinTrack → Coach server** (DHCP-assigned, it changes); iOS local-network permission
   granted.
3. **Before any code change**, run `./build.sh` then `./test.sh` for a green baseline. The
   UI tests are the only guard on the gesture thresholds and on the fidelity promise that
   an undated milestone renders exactly as the prototype does.

## Open threads / decisions

- **The coach characterises unreliably.** Measured over five samples of one prompt: 0/5
  false completion claims and 5/5 numerically correct, but 4/5 volunteered "you're crushing
  it" / "you're on track", once contradicting itself ("crushing your Loan collection goal,
  but it's overdue by 12 days"). Its *figures* are trustworthy; its *verdicts* are not. No
  snapshot field fixes this — a stronger model is the lever. Note the demo tone is Playful
  and the prompt asks for warmth, so some enthusiasm is requested.
- **Four deliberate deviations from a spec that declared the design final**, all in
  `BUILD.md`: the milestone pace line on the Home card, the entry sheet's Ledger row,
  business milestone cards becoming tappable, and one added sentence in the coach prompt.
  Each was put to the user and approved.
- **The repo is PUBLIC** as of 2026-08-31. The seed figures and names in `Models.swift`,
  `DESIGN-HANDOFF.md` and `FinTrack.dc.html` were replaced with fictional ones and the
  history rewritten before publication, so nothing personal survives in any commit. Anything
  added from here is visible immediately — keep real balances out of the seed.
- **A strict-mode pre-push hook** (`.git/hooks/pre-push`) demands an interactive `YES` and
  aborts without a TTY, so an agent cannot push unattended. Bypassing it needs
  `--no-verify` and the user's explicit say-so.
- Apostrophes deliberately match the prototype's ASCII `'`. Reversible in one pass.

## Blockers

- **Live simulator panel unavailable** — Xcode is installed but not `xcode-select`'d, so
  the simulator MCP refuses to attach. The fix is a `sudo xcode-select -s
  /Applications/Xcode.app/Contents/Developer`, which only the user can run. Work around
  with `xcrun simctl`, which has no touch input — see auto-memory.
- **Release builds cannot be driven remotely.** `DebugLaunch` is `#if DEBUG`, so no `-FT*`
  argument works on the installed build. To exercise the app on the phone programmatically,
  install a Debug build first.

## References (durable homes — do not restate, just point)

- **Auto-memory:** `ios-sim-toolchain`, `fintrack-debug-launch-args`.
- **engagement-state.json:** N/A — a code project, not an ENG engagement.
- **Remote:** `github.com/agilmuhadpt/FinTrack-ios-App` — **public**. `main` tracks
  `origin/main`.
- **Commits**, newest first:
  - `5adfb92` this handoff · `8e93b5b` coach snapshot + prompt guardrail · `c5b7f6a` demo seed
  - `550f7ea` business milestone funding · `a1a5243` business expenses + computed bar
  - `3e2b772` milestone target dates · `f37011a` previous handoff
  - `bb487ba` coach host persistence · `a4ec97a` signing split · `fa588a6` the app
- **Other:**
  - `BUILD.md` — build, test, device install, launch arguments, deviations, the coach's
    measured limits, and the bugs the test suite caught.
  - `README.md` — the public front page (what the app does, build, layout, fidelity).
  - `DESIGN-HANDOFF.md` + `FinTrack.dc.html` — the written spec and prototype, renamed from
    `README.md` when the repo went public. Code comments cite them; do not delete either.
  - `Config/Local.xcconfig.example` — restoring device signing on a fresh clone.

## Suggested skills (to resume)

- `superpowers:systematic-debugging` — for gesture or coach misbehaviour; both have subtle
  failure modes already written down in `BUILD.md`.
- `superpowers:test-driven-development` — for new features. The UI test target exists and
  has caught every accessibility defect found so far.
- `frontend-design` — only for genuinely new UI. Existing screens are pinned to
  `FinTrack.dc.html` and should be changed against it, not redesigned.

---
<!--
Verifier contract (do not remove): scripts/check_handoff.py requires these headings —
Next-session focus · Current state · Next actions · References · Suggested skills —
with >=1 list/numbered item under Next actions, and no secret/credential patterns anywhere.
-->
