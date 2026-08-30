//
//  WizardDraft.swift
//  FinTrack — Onboarding wizard: the local draft the nine steps write into.
//
//  Ported from `blankDraft()`, `wizardVals()` and `finishWizard()` in the prototype
//  (FinTrack.dc.html, lines 835-851 and 1105-1180). Nothing here touches AppStore: the
//  wizard is a scratchpad, and only `makeAppData()` turns it into the AppData that
//  replaces the ledger. Every field starts blank, so finishing with nothing entered
//  produces a valid empty app.
//

import Foundation

// MARK: - Time

/// The wizard stores reminder times as 24h "HH:mm" strings, exactly like the prototype's
/// `<input type="time">`. `en_US_POSIX` keeps the pattern literal regardless of device locale.
enum WizardTime {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    /// `Date` -> "HH:mm".
    static func string(_ date: Date) -> String { formatter.string(from: date) }

    /// Today at `hour:minute` — the anchor a `DatePicker(.hourAndMinute)` edits.
    /// Falls back to "now" only if the calendar cannot represent the time (DST edge).
    static func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - Summary row

/// One line of the "All set" list. A named type rather than a tuple: Swift has no key
/// paths into tuple elements, so `ForEach(_:id:)` could not address one.
struct WizardSummaryRow: Identifiable, Hashable {
    let label: String
    let value: String

    var id: String { label }
}

// MARK: - Draft

/// `blankDraft()` — `{ step: 0, currency: 'SAR', accounts: [], incomes: [],
/// incType: 'Personal', loans: [], loanDir: 'in', milestones: [], coachEmoji: '😊',
/// tone: 'Playful' }`, plus the coach name and the two reminder times the prototype keeps
/// in DOM refs until a step change commits them.
struct WizardDraft {

    /// The index of the summary step; `step` is always `0...lastStep`.
    static let lastStep = 8

    var step: Int = 0

    var currency: String = "SAR"
    var accounts: [Account] = []

    var incomes: [Income] = []
    /// Which type the next `+ Add income` will use.
    var incType: IncomeType = .personal

    var loans: [Loan] = []
    /// Which direction the next `+ Add loan` will use.
    var loanDir: LoanDirection = .inbound

    var milestones: [Milestone] = []

    var coachName: String = ""
    var coachEmoji: String = "\u{1F60A}"
    var tone: CoachTone = .playful

    var am: Date = WizardTime.date(hour: 8, minute: 0)
    var pm: Date = WizardTime.date(hour: 20, minute: 0)

    // MARK: Copy — FINAL, character for character

    static let titles = [
        "Welcome to FinTrack",
        "Currency",
        "Bank accounts",
        "Income sources",
        "Loans",
        "Milestones",
        "Your coach",
        "Reminders",
        "All set",
    ]

    static let subtitles = [
        "Your money, one place.",
        "Pick the currency for all amounts.",
        "Add the accounts you want to track.",
        "What money comes in each month?",
        "Money you've lent or borrowed.",
        "Goals to work toward.",
        "Name your coach and pick a vibe.",
        "When should your coach check in?",
        "Here's what you've set up. You can change anything later.",
    ]

    // MARK: Derived chrome

    var title: String { WizardDraft.titles[safe: step] ?? "" }
    var subtitle: String { WizardDraft.subtitles[safe: step] ?? "" }

    /// `Math.max(4, Math.round(s / 8 * 100)) + '%'`, expressed as a 0…1 fraction.
    var progress: Double {
        max(4, jsRound(Double(step) / 8 * 100)) / 100
    }

    /// `wizBackLabel: s === 0 ? 'Cancel' : 'Back'`
    var backLabel: String { step == 0 ? "Cancel" : "Back" }

    /// `wizSkippable: s > 0 && s < 8` — no Skip on the welcome or the summary.
    var isSkippable: Bool { step > 0 && step < WizardDraft.lastStep }

    /// `wizCta: s === 0 ? 'Get started' : (s === 8 ? 'Start using FinTrack' : 'Continue')`
    var ctaLabel: String {
        if step == 0 { return "Get started" }
        if step == WizardDraft.lastStep { return "Start using FinTrack" }
        return "Continue"
    }

    // MARK: Derived content

    /// `fmtItem = (n) => w.currency + ' ' + Math.round(n).toLocaleString('en-US')` — the
    /// draft currency, not the store's, because the ledger has not been replaced yet.
    func amountLabel(_ n: Double) -> String {
        FinTrackFormatting.amount(n, currency)
    }

    /// `w.coachNameSaved || 'Leo'`
    var resolvedCoachName: String {
        let trimmed = coachName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Leo" : trimmed
    }

    /// `summaryRows` — the currency, four plain counts, and "<name> <emoji>".
    var summaryRows: [WizardSummaryRow] {
        [
            WizardSummaryRow(label: "Currency", value: currency),
            WizardSummaryRow(label: "Accounts", value: String(accounts.count)),
            WizardSummaryRow(label: "Income sources", value: String(incomes.count)),
            WizardSummaryRow(label: "Loans", value: String(loans.count)),
            WizardSummaryRow(label: "Milestones", value: String(milestones.count)),
            WizardSummaryRow(label: "Coach", value: resolvedCoachName + " " + coachEmoji),
        ]
    }

    // MARK: Finish

    /// `finishWizard()` — `AppData.fromWizard` already ports the loan-sub rewrite, the
    /// `saved: 0` milestone reset with the palette colour by index, and the empty business
    /// milestones / bucket spend / activity.
    func makeAppData() -> AppData {
        AppData.fromWizard(currency: currency,
                           accounts: accounts,
                           incomes: incomes,
                           loans: loans,
                           milestones: milestones,
                           coachName: coachName,
                           coachEmoji: coachEmoji,
                           tone: tone,
                           am: WizardTime.string(am),
                           pm: WizardTime.string(pm))
    }

    // MARK: Parsing

    /// `readNum` — `parseFloat(value)` with `NaN -> 0`. A `.decimalPad` in a comma-decimal
    /// locale hands back "1,5", so the locale's separators are normalised before parsing.
    static func number(_ text: String) -> Double {
        FinTrackFormatting.amount(from: text) ?? 0
    }

    /// `readStr` — trimmed, or "" when the field is empty.
    static func string(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Bounds-safe lookup

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
