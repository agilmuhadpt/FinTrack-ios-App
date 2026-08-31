# Session Handoff — FinTrack iOS

_Session: 2026-08-31 · Save target: repo (`docs/`) · Internal artifact — not client-facing_

## Next-session focus

In descending order of likelihood:

1. **Renew the provisioning profile** — the free Apple team's profile expires
   **2026-09-07 04:07 UTC**, after which the app will not launch on the device. Rebuilding
   alone does NOT renew it; see Next actions.
2. **Sharing the app with someone else.** Asked at the end of this session and not yet
   acted on — see Open threads for what each route actually costs.
3. **New feature work.** The app is complete against the prototype and has grown three
   features beyond it; nothing is half-finished.

## Current state

- **Position:** Complete, public, and running on hardware. A **Release** build is installed
  on the user's iPhone 16 Pro (iOS 26.6) with the coach **verified working end to end** —
  Ollama's log shows `POST /api/chat` from the phone and `qwen3.5:4b` resident. Working
  tree clean at `bc17df2`. 32 Swift files, **28/28 UI tests green** (`./test.sh`).
- **The repo is PUBLIC**: `github.com/agilmuhadpt/FinTrack-ios-App`. Seed data is fictional
  and history was rewritten before publication.
- **Done this session:**
  - **`README.md` is now a real front page**; the client's design spec moved to
    `DESIGN-HANDOFF.md` unchanged (it is still cited by code comments).
  - **Default model is `qwen3.5:4b`**, down from `qwen3.5:9b`. Measured, not guessed —
    see the table in `BUILD.md`.
  - **`stripMarkdown`** removes emphasis from replies. `qwen3:8b` bolded 3/3 and the coach
    bubble renders its string literally.
  - **An unset coach server on device is now explicit** rather than silently offline, and
    `COACH_DEFAULT_HOST` in the gitignored `Config/Local.xcconfig` bakes the address into
    device builds so a reinstall comes back configured.
  - **14.2 GB of disk reclaimed** — `qwen3.5:9b`, `gemma3:4b` and the ALLaM GGUF removed.
    All three are re-pullable; ALLaM is the only one not from Ollama's registry.
- **In-flight:** Nothing. All work is committed and pushed.
- **Not started:** Release performance is unprofiled. The app has run on no device but
  this one. The `.unconfigured` code path is device-only (`#if targetEnvironment(simulator)`)
  so no test covers it and it has never been seen rendered.

## Next actions

1. **If the app will not launch on the phone**, the profile has expired. **Rebuilding alone
   does not renew it** — Xcode reuses a cached profile while it is still valid (verified).
   Evict the cache first:
   ```bash
   rm ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision
   cd /path/to/FinTrack-ios-App   # absolute, or run from the repo root
   xcodebuild -project FinTrack.xcodeproj -scheme FinTrack -configuration Release \
     -sdk iphoneos -destination 'generic/platform=iOS' \
     -derivedDataPath .build/ReleaseBuild -allowProvisioningUpdates build
   xcrun devicectl device install app --device <device-id> \
     .build/ReleaseBuild/Build/Products/Release-iphoneos/FinTrack.app
   ```
   Then confirm the new date rather than assuming — `security cms -D -i <app>/
   embedded.mobileprovision | grep -A1 ExpirationDate`. Full recipe in `BUILD.md`.
   **Give every command an absolute path or a `cd`** — commands handed over without one
   were run from `~` this session and failed three times in a row.
2. **If the coach falls back to preview text**, diagnose in this order. Two sessions have
   now been lost to guessing:
   1. **Is the Coach server field in iOS Settings stale?** It takes precedence over the
    baked `COACH_DEFAULT_HOST`, so a wrong value there overrides a correct build.
    **Blank is correct** on a build with the default baked in.
   2. **Is Local Network permission on** for FinTrack? Safari is not gated by it, so
    "Safari can load Ollama" does NOT prove the app can.
   3. **Did the request even arrive?** `grep GIN ~/.ollama/logs/server.log | grep <phone-ip>`
    settles blocked-on-phone vs failed-at-Mac in one line. Use it early.
   4. Only then suspect Ollama, which has been correctly configured every time
    (`OLLAMA_HOST=0.0.0.0`, firewall set to allow incoming).
3. **Before any code change**, run `./build.sh` then `./test.sh` for a green baseline.

## Open threads / decisions

- **Sharing the app** — asked, not yet answered in the repo. The honest options: a
  developer friend can clone the public repo and build with their own free Apple ID
  (7-day expiry, needs a Mac and Xcode); anyone else needs TestFlight, which requires the
  paid Apple Developer Program. **Either way the coach needs an Ollama host on their own
  network**, or it will show the unconfigured message — the app is fully usable without it,
  since every screen but Coach works offline.
- **The coach characterises unreliably, and a bigger model does not fix it.** Measured over
  four models: the largest (`qwen3.5:9b`) was slowest and the only one to invent figures;
  `gemma3:4b` gave a false approving verdict 3/3 and is excluded from the preference list.
  Its figures are trustworthy; its verdicts are not. Table in `BUILD.md`.
- **Cold model load costs ~40s**; warm replies are 7-11s. `keep_alive: "30m"` holds it.
  If warm replies stay near 40s, investigate — the machine is 16GB with heavy swap.
- **Four deliberate deviations from a spec that declared the design final**, all in
  `BUILD.md`, each put to the user and approved.
- **A strict-mode pre-push hook** (`.git/hooks/pre-push`) demands an interactive `YES` and
  aborts without a TTY. Bypassing needs `--no-verify` **and the user's say-so each time**.
- Apostrophes deliberately match the prototype's ASCII `'`. Reversible in one pass.

## Blockers

- **Live simulator panel unavailable** — Xcode is installed but not `xcode-select`'d, so
  the simulator MCP refuses to attach. The fix needs the user's password. Work around with
  `xcrun simctl`, which has no touch input — see auto-memory.
- **Release builds cannot be driven remotely.** `DebugLaunch` is `#if DEBUG`, so no `-FT*`
  argument works on the installed build. Install a Debug build to exercise the app
  programmatically.
- **The Mac's LAN address moves.** It changed subnet mid-session (192.168.1.x → 192.168.0.x)
  and made a wrong diagnosis look confirmed. A DHCP reservation on the router would end it;
  note the Wi-Fi MAC is a private/randomised address, so reserve against the current one
  only while "Private Wi-Fi Address" stays Fixed.

## References (durable homes — do not restate, just point)

- **Auto-memory:** `ios-sim-toolchain`, `fintrack-debug-launch-args`, `coach-host-and-model`.
- **Remote:** `github.com/agilmuhadpt/FinTrack-ios-App` — **public**. `main` tracks
  `origin/main`.
- **Commits**, newest first:
  - `bc17df2` explicit unconfigured coach + `COACH_DEFAULT_HOST`
  - `752a01c` qwen3.5:4b default + `stripMarkdown` · `6126088` public README
  - `9b10f59` seed scrub · `6e27e1d` profile renewal · `366caf5` previous handoff
  - `7cb0a68` coach snapshot + guardrail · `93fc327` demo seed
- **Other:**
  - `BUILD.md` — build, test, device install, launch arguments, deviations, the model
    benchmark, the coach's measured limits, and the bugs the test suite caught.
  - `README.md` — public front page. `DESIGN-HANDOFF.md` + `FinTrack.dc.html` — the spec
    and prototype. Code comments cite them; do not delete either.
  - `Config/Local.xcconfig.example` — device signing and `COACH_DEFAULT_HOST`.

## Suggested skills (to resume)

- `superpowers:systematic-debugging` — for gesture or coach misbehaviour. This session lost
  time twice to a plausible-looking first theory that was never tested.
- `superpowers:test-driven-development` — for new features. The UI test target has caught
  every accessibility defect found so far.
- `frontend-design` — only for genuinely new UI. Existing screens are pinned to
  `FinTrack.dc.html`.

---
<!--
Verifier contract (do not remove): scripts/check_handoff.py requires these headings —
Next-session focus · Current state · Next actions · References · Suggested skills —
with >=1 list/numbered item under Next actions, and no secret/credential patterns anywhere.
-->
