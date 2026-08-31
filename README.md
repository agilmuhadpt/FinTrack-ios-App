# FinTrack

A native SwiftUI recreation of the `FinTrack.dc.html` design prototype — a personal finance
tracker that keeps a personal and a business ("Studio") side of the same books: accounts,
income streams, person-to-person loans, savings milestones, a 50/30/20 budget, and a money
coach backed by a local LLM.

iOS 17.0+, portrait, no third-party dependencies. 32 Swift files, 28 UI tests.

## What it does

Home shows a balance, a tri-colour budget bar and milestone cards, and flips between Personal
and Studio with a sliding segmented control. Both budget bars are computed from recorded
spending — the prototype hard-coded the business one at 48/22/30, and here a Ledger row on
the entry sheet lets business expenses land in Ops, Growth or Profit so the bar means
something.

Activity is a day-grouped list with swipe-to-delete that tracks the finger 1:1 and honours
both a distance threshold and a velocity flick. The centre tab opens a drag-dismissible entry
sheet that books expenses, income, loan repayments and milestone deposits, applying each to
the account balance, bucket spend and transaction list at once.

Milestones take an optional target date. Set one and the app derives the monthly contribution
needed and flags the goal when it goes overdue; leave it unset and the card renders exactly as
the prototype specified. There is deliberately no "on track" indicator — that needs a
contribution history, and transactions carry no timestamp.

Loans open a repayment roadmap: a declining six-bar chart and a month-by-month schedule.
Settings covers appearance, currency, the coach's name and tone, twice-daily reminders,
account management and a JSON export. "Start fresh" runs a nine-step onboarding wizard that
replaces all data.

## The coach

The coach tab talks to a **local Ollama instance** — nothing leaves the machine, and there is
no API key. It sends a system prompt plus a JSON snapshot of the finances and asks for a plain
reply under 90 words. Default model is `qwen3.5:9b`; the host is configurable in Settings, and
the app falls back to canned preview text when Ollama is unreachable rather than surfacing an
error.

One honest caveat, measured rather than assumed: over five samples of an identical prompt the
model was **numerically correct 5/5** and made **no false completion claims**, but **4/5 still
volunteered "you're crushing it" / "you're on track"**, once contradicting itself in the same
sentence as an overdue goal. Its figures are trustworthy; its verdicts are not. A prompt
guardrail reduced this; a stronger model is the real lever. `BUILD.md` records the full run.

## Build

```bash
open FinTrack.xcodeproj
```

⌘R for the app, ⌘U for the tests. The simulator needs no signing and builds from a fresh
clone. From the command line:

```bash
./build.sh && ./test.sh
```

To build to a device, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and put
your own `DEVELOPMENT_TEAM` in it. That file is gitignored — a team ID identifies an Apple
Developer account — and the shared config includes it optionally, so its absence never breaks
a simulator build. On a free Apple team the provisioning profile expires after 7 days, and
rebuilding alone does not renew it; `BUILD.md` has the eviction recipe.

## Layout

| path | what's in it |
|---|---|
| `FinTrack/App/` | root view, tab bar, overlay routing, debug launch arguments |
| `FinTrack/Core/` | models, store, persistence, the shared number formatters |
| `FinTrack/Design/` | theme, typography, motion curves, icons, shared components |
| `FinTrack/Features/` | one folder per screen |
| `FinTrackUITests/` | gesture and behaviour tests |
| `Config/` | signing split — `Shared.xcconfig` tracked, `Local.xcconfig` not |

`FinTrack.dc.html` is the original interactive prototype and `DESIGN-HANDOFF.md` its written
spec. Code comments cite the prototype by line and the spec by section, so both stay in the
repo. `ios-frame.jsx` and
`support.js` belong to the prototype's presentation frame, not the app.

## Fidelity

The handoff declared the design final and asked for a pixel-perfect recreation, so colours,
type, spacing, radii, animation curves and copy come straight from it — CSS `cubic-bezier`
values map to SwiftUI `timingCurve`, and every amount goes through a `jsRound` because JS
rounds halves toward +infinity (`Math.round(-2.5) === -2`) where Swift's `.rounded()` rounds
half away from zero and would give -3.

Every departure is listed under "Known deviations" in `BUILD.md`. Four are substantive: the
milestone pace line, the entry sheet's Ledger row, tappable business milestone cards, and one
added sentence in the coach prompt. Three more are accessibility fixes the prototype had no
opinion on — overlays now hide the background from VoiceOver, filled segmented controls are
real buttons with an `.isSelected` trait, and row deletion is reachable without a gesture.
Each of those three was found by a UI test failing, not by review.

## Notes

The demo data is fictional. Nothing is uploaded anywhere: state lives in `UserDefaults` and
the coach runs on your own machine.

Built with [Claude Code](https://claude.com/claude-code).
