# Session Handoff — FinTrack iOS

_Session: 2026-08-30 · Save target: repo (`docs/`) · Internal artifact — not client-facing_

## Next-session focus

Most likely one of three, in descending order of likelihood:

1. **Rebuild and reinstall after the provisioning profile expires** — the free Apple team's
   profile expires **2026-09-06**, after which the app will not launch on the device.
2. **Confirm the money coach works on the phone** — the user was checking this when the session
   ended; see Open threads.
3. New feature work on the app itself.

## Current state

- **Position:** Complete and shipped. The app is built, reviewed, tested, committed, and a
  **Release** build is installed and running on the user's physical iPhone (iPhone 16 Pro, iOS 26.6).
  Working tree clean at `bb487ba`.
- **Done this session:**
  - Full SwiftUI port of the HTML prototype — 35 Swift files, ~8.2k lines, all screens.
  - Hand-written `project.pbxproj` (no XcodeGen/Tuist on this machine) using a
    file-system-synchronized root group, so new `.swift` files need no project edit.
  - `FinTrackUITests` target + shared scheme; **13/13 UI tests pass** (`./test.sh`).
  - Signing split into `Config/Local.xcconfig` (gitignored) vs `Config/Shared.xcconfig`.
  - History rewritten once to purge a private LAN address; old objects pruned.
  - `BUILD.md` documents build, test, device install, launch arguments, and deviations.
- **In-flight:** Nothing. All work is committed.
- **Not started:** No remote is configured — nothing has ever been pushed. Release-build
  performance has not been profiled; the app has never run on any device but this one.

## Next actions

1. **If the app will not launch on the phone**, the profile has expired (2026-09-06). Rebuild and
   reinstall — this regenerates the profile for another 7 days:
   ```bash
   xcodebuild -project FinTrack.xcodeproj -scheme FinTrack -sdk iphoneos \
     -destination 'generic/platform=iOS' -derivedDataPath .build/ReleaseBuild \
     -configuration Release -allowProvisioningUpdates build
   xcrun devicectl device install app --device <device-id> \
     .build/ReleaseBuild/Build/Products/Release-iphoneos/FinTrack.app
   ```
   Requires `Config/Local.xcconfig` to exist locally with a `DEVELOPMENT_TEAM`.
2. **If the coach answers with "(Preview mode — no model connected here…)"**, it is falling back.
   Check, in order: Ollama is running and exposed to the network (not loopback-only); the Mac's
   current LAN address is set under **iOS Settings → FinTrack → Coach server** (it is DHCP-assigned
   and changes); iOS local-network permission is granted to FinTrack.
3. **Before any code change**, run `./build.sh` then `./test.sh` to confirm a green baseline —
   the gesture tests are the only thing guarding two subtle bugs described in `BUILD.md`.

## Open threads / decisions

- **User was verifying the coach on the phone** when the session ended and had not reported back.
  The Release build carries no `-FT*` launch arguments, so it **cannot be driven remotely** — a
  fresh agent must ask the user what they saw, or reinstall a Debug build to test programmatically.
- **No git remote.** Pushing was never requested; ask before adding one.
- Apostrophes deliberately match the prototype's ASCII `'` rather than typographic. Reversible in
  one pass if the user prefers proper typography.

## Blockers

- **Live simulator panel unavailable** — Xcode is installed but not `xcode-select`'d, so
  `mcp__Claude_Code_iOS_Simulator__control` refuses to attach. The fix is a `sudo xcode-select -s
  /Applications/Xcode.app/Contents/Developer`, which only the user can run. Work around with
  `xcrun simctl` (no touch input) — see auto-memory.

## References (durable homes — do not restate, just point)

- **Auto-memory:** `ios-sim-toolchain`, `fintrack-debug-launch-args` (both written this session).
- **engagement-state.json:** N/A — this is a code project, not an ENG engagement.
- **Commits** (branch `main`, no remote):
  - `fa588a6` — the app
  - `a4ec97a` — signing split out of the repo, coach host made configurable
  - `bb487ba` — coach host persistence, device workflow docs
- **Other:**
  - `BUILD.md` — build/test/device install, launch arguments, deviations, and the two bugs the
    test suite caught.
  - `README.md` + `FinTrack.dc.html` — the original design handoff and prototype. Code comments
    cite line numbers in the prototype; do not delete it.
  - `Config/Local.xcconfig.example` — how to restore device signing on a fresh clone.

## Suggested skills (to resume)

- `superpowers:systematic-debugging` — if the coach or a gesture misbehaves; both have subtle
  failure modes already documented in `BUILD.md`.
- `superpowers:test-driven-development` — for any new feature; the UI test target already exists
  and is the only guard on gesture behaviour.
- `frontend-design` — only for genuinely new UI. Existing screens are pinned to the prototype and
  should be changed against `FinTrack.dc.html`, not redesigned.

---
<!--
Verifier contract (do not remove): scripts/check_handoff.py requires these headings —
Next-session focus · Current state · Next actions · References · Suggested skills —
with >=1 list/numbered item under Next actions, and no secret/credential patterns anywhere.
-->
