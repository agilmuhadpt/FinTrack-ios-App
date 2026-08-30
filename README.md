# Handoff: FinTrack — Personal Finance Tracker (iOS)

## Overview
FinTrack is an iOS personal-finance app for a user in Saudi Arabia who tracks two income streams (personal job stipend + "Studio" business), bank accounts (Northbank, CityPay), person-to-person loans, savings milestones, and a 50/30/20 budget — with an AI money coach ("Leo") available in a chat tab. Currency defaults to SAR, user-selectable.

## About the Design Files
The files in this bundle are **design references created in HTML** — an interactive prototype showing intended look and behavior, not production code to copy directly. The task is to **recreate this design in the target codebase's environment** (SwiftUI recommended for iOS; React Native acceptable) using its established patterns. If no codebase exists yet, SwiftUI is the natural choice — the design deliberately follows Apple HIG conventions.

## Fidelity
**High-fidelity.** Colors, typography, spacing, radii, animation curves and copy are final. Recreate pixel-perfectly.

## Screens / Views

### 1. Home (tab 1)
- Header: 44×44 app icon (radius 11, gradient #0A84FF→#5E5CE6, 💳 glyph), uppercase date label (13px/600, secondary color), "Overview" title (34px/800, letter-spacing −0.02em). Right: three 38px circular buttons — Start fresh (↺), light/dark toggle (sun/moon), Settings (gear).
- Segmented control "Personal | Studio": container = chip background, radius 12, 3px padding. Active pill is implemented as a duplicated label layer clipped with `clip-path: inset(0 50% 0 0 round 10px)` animated 250ms cubic-bezier(0.77,0,0.175,1) — recreate with a sliding indicator (matchedGeometryEffect in SwiftUI).
- Balance card: white card (radius 20, shadow 0 1px 3px rgba(10,20,40,0.06)), label 13px/600 secondary, amount 38px/800 tabular numerals, letter-spacing −0.022em. Below: account chips (pill, 12px/600, chip bg, nowrap) — tap opens Account detail.
- Budget card: 10px tri-color bar (#0A84FF Needs, #FF9F0A Wants, #30D158 Savings, 2px gaps, pill ends). Percentages are **computed from actual bucket spending**, not static. Business mode relabels to Ops/Growth/Profit (static 48/22/30).
- Milestones: cards with name (16px/600, single line, ellipsis), pct (13px/700 secondary), progress string, 6px progress bar. Tap opens Milestone detail. Cards stagger in (fade + 8px rise, 300ms, 50ms cascade).

### 2. Activity (tab 2)
- "Activity" title (34px/800). Day-grouped list (uppercase 13px/600 group labels). Row: 36px icon tile (radius 12, tinted bg + colored 2-letter glyph), title 15px/600, sub 13px secondary, amount 15px/700 tabular (green #30D158 for income).
- **Swipe-to-delete**: rows track the finger 1:1 horizontally (rubber-band to the right, max ~40px); release past −80px or a leftward flick (velocity > 0.11 px/ms) deletes with a 200ms slide-out; otherwise springs back (250ms, cubic-bezier(0.23,1,0.32,1)).
- Empty state card when no transactions.

### 3. + New Entry (center tab button, 52px blue circle, lifted −18px)
Bottom sheet (radius 24 top, max-height 78%, slides up 350ms cubic-bezier(0.32,0.72,0,1), dim scrim). Grabber handle supports **drag-to-dismiss** (1:1 downward, 0.15× resistance upward; dismiss past 140px or downward flick).
Fields: kind segmented (Expense/Income/Loan/Milestone), large centered amount input (26px/700), description, bucket picker (expense only), loan/milestone picker lists (2px blue selected border), account chips. Save applies live: adjusts account balance, bucket spend, loan outstanding, milestone saved, and prepends a transaction to Today.

### 4. Loans (tab 4)
Two summary cards (Owed to you / You owe, 22px/800, green/red). Loan cards: name, amount (green #30D158 incoming / red #FF453A outgoing), sub-line. Tap opens Loan detail.

### 5. Loan detail
Back chevron header. Outstanding card (34px/800, direction-colored). Repayment roadmap: (a) 6-bar declining chart (bar heights = remaining balance %), (b) month-by-month list (month, payment, remaining), payment = outstanding/6 rounded up. Coach note below (collection plan for incoming, avalanche note for outgoing).

### 6. Milestone detail
Progress card (pct 34px/800, progress string, 10px bar). "Add money" input + button: increments saved, deducts from first account, counts as Savings spend, logs a transaction.

### 7. Account detail
Balance card + transactions filtered to that account.

### 8. Coach (tab 5) — AI chat
Header: 42px gradient avatar with coach emoji, name 17px/700, "Your money coach" 13px green. Chat bubbles: coach = card bg, radius 20/20/20/6; user = #0A84FF white, radius 20/20/6/20; 15px, line-height 1.45. Quick-reply pills (Can I afford it? / Collection script / Milestone check). Input bar: pill text field + 44px circular send button.
**Backend**: send a system prompt containing coach name, tone (playful/serious), and a JSON financial snapshot (accounts, incomes, loans w/ direction, milestones, bucket spend, recent transactions); instruct plain text < 90 words. Recommended free local models via Ollama: **Qwen 2.5 7B** (primary — best small-model arithmetic), **Llama 3.2 3B** (low-end fallback), Gemma 2 9B (best conversational tone). "Thinking…" bubble while awaiting reply.

### 9. Settings (gear icon)
Grouped sections: Appearance (iOS switch, 51×31), Currency chips (SAR/AED/KWD/USD/EUR/INR), Coach (name field, 5 emoji options 😊🦁🤖🐨⭐, Playful/Serious segmented), Reminders (two time pickers, defaults 08:00/20:00), Notifications (list of the two scheduled reminders), Manage accounts (list with delete + add row), Export data button.

### 10. Onboarding wizard ("Start fresh")
Entry: ↺ button → destructive confirmation alert ("Start fresh?" Cancel / red Start Fresh) → 9 steps: Welcome, Currency, Accounts, Income, Loans, Milestones, Coach, Reminders, Summary. Progress bar top, Skip on steps 1–7 (every step skippable), Back/Cancel. Fields start blank. Finish **replaces all data**. Item rows added with × delete.

### 11. Push notification banner
Drops from top 3s after launch (translucent blur card, radius 20, app icon, "FinTrack / now", title with coach name+emoji, body). Tap → opens New Entry sheet. Auto-dismisses ~9s. Real app: twice-daily local notifications at the reminder times.

## Interactions & Behavior
- Tab switching is **instant** (no animation — high-frequency action).
- All pressables scale on press: 0.9–0.985 depending on size, 160ms cubic-bezier(0.23,1,0.32,1).
- Standard curves: ease-out cubic-bezier(0.23,1,0.32,1) for enter/press; ease-in-out cubic-bezier(0.77,0,0.175,1) for on-screen morphs (bars, clip pill, ≤250ms); drawer curve cubic-bezier(0.32,0.72,0,1) for sheet/banner.
- Theme change cross-fades backgrounds 300ms. Respect prefers-reduced-motion (drop movement, keep fades).
- Gestures: 1:1 tracking, velocity-aware release (project momentum; dismiss on flick), rubber-band at boundaries.

## State Management
Single app state: `{ currency, accounts[{name,bal}], incomes[{name,amt,type:Personal|Business}], loans[{name,amt,dir:in|out,sub}], msPersonal[{name,saved,target,color}], msBusiness[], bucketSpend{Needs,Wants,Savings}, coach{name,emoji,tone}, reminders{am,pm}, days[{label,items[tx]}] }` plus UI state (tab, personal/business mode, dark, overlays). Persist the data object (prototype uses localStorage key `fintrack-v1`; real app: local database / UserDefaults). Derived values: personal balance = Σ account balances; business balance = Σ business incomes; budget % = bucket spend / total spend; loan totals by direction.

## Design Tokens
Light: bg #F2F2F7, card #FFFFFF, text #1C1C1E, secondary #8E8E93, chip #F2F2F7, separator rgba(60,60,67,0.12), tab bar rgba(255,255,255,0.72) + blur(24px) saturate(180%).
Dark: bg #000000, card #1C1C1E, text #FFFFFF, secondary #98989E, chip #2C2C2E, separator rgba(84,84,88,0.5), tab bar rgba(22,22,24,0.75).
Accents: blue #0A84FF (primary/interactive), green #30D158 (positive/savings), orange #FF9F0A (wants), red #FF453A (negative/destructive), gradient #0A84FF→#5E5CE6 (brand).
Type: system font (SF Pro). Titles 34px/800 ls−0.02em; section 20px/700 ls−0.015em; balance 38px/800 ls−0.022em; body 15–16px/600; labels 12–13px/600; tabular numerals for all amounts. Radii: cards 20, inputs/rows 14–16, pills 999, sheet top 24, app icon 11. Spacing: 20px screen gutters, 10px card gaps.

## Assets
No image assets. Icons are Lucide-style 2px-stroke SVGs (home, activity zigzag, lock, chat, gear, sun/moon, restore, chevron, plus, send). Emoji: 💳 app icon, coach avatar options.

## Files
- `FinTrack.dc.html` — the full interactive prototype (template + logic; open in a browser)
- `ios-frame.jsx` — iPhone device frame used for presentation only (not part of the app)
- `support.js` — prototype runtime (presentation only)
