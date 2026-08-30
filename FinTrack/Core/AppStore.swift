//  AppStore.swift
//  FinTrack — the single source of app state.
//
//  Ported from the prototype's logic class: state, `renderVals()` derived values and every
//  mutation (`saveEntry`, `addTx`, `deleteTx`, the milestone-detail handler, the settings
//  handlers and `finishWizard`). Navigation, tab, sheet and wizard state deliberately do
//  NOT live here — views own those, exactly as the prototype keeps them beside `data`.

import Foundation
import Observation

// Convenience spellings so both `EntryDraft` and `AppStore.EntryDraft` resolve.
typealias EntryKind = AppStore.EntryKind
typealias EntryDraft = AppStore.EntryDraft
typealias RoadmapEntry = AppStore.RoadmapEntry

@MainActor
@Observable
final class AppStore {

    // MARK: - Nested types

    enum EntryKind {
        case expense, income, loan, milestone
    }

    /// The New Entry sheet's picker state. Amount and description stay in the view's own
    /// text fields and are handed to `saveEntry` — the prototype reads them from refs.
    struct EntryDraft {
        var kind: EntryKind = .expense
        var bucket: Bucket = .needs
        var acct = 0
        var loan = 0
        var ms = 0

        init(kind: EntryKind = .expense, bucket: Bucket = .needs, acct: Int = 0, loan: Int = 0, ms: Int = 0) {
            self.kind = kind
            self.bucket = bucket
            self.acct = acct
            self.loan = loan
            self.ms = ms
        }
    }

    /// One month of the loan-detail repayment roadmap.
    struct RoadmapEntry: Identifiable, Hashable {
        let month: String
        let label: String
        let pay: Double
        let left: Double
        /// Bar height as a 0…1 fraction, clamped to a 4% minimum like the prototype.
        let barFraction: Double

        var id: String { month }
    }

    // MARK: - State

    var data: AppData
    var dark: Bool
    var mode: AppMode = .personal

    @ObservationIgnored private let store: Persistence
    /// Mirrors `this._lastSaved` — an identical consecutive snapshot is never rewritten.
    @ObservationIgnored private var lastSavedJSON: Data?

    init(persistence: Persistence = .shared) {
        self.store = persistence
        if let snapshot = persistence.load() {
            // `{ ...this.demoData(), ...p.data }` — the merge happens during decoding, so a
            // field the saved file omits keeps its demo value instead of being wiped.
            self.data = snapshot.data
            self.dark = snapshot.dark
        } else {
            self.data = .demo()
            self.dark = false
        }
        self.lastSavedJSON = persistence.encode(Persistence.Snapshot(data: data, dark: dark))
    }

    // MARK: - Persistence

    /// Encodes the current snapshot and writes it only when it differs from the last one
    /// written — the same de-duplication `componentDidUpdate()` performs.
    func persist() {
        guard let json = store.encode(Persistence.Snapshot(data: data, dark: dark)) else { return }
        guard json != lastSavedJSON else { return }
        lastSavedJSON = json
        store.write(json)
    }

    private func mutate(_ body: (inout AppData) -> Void) {
        body(&data)
        persist()
    }

    // MARK: - Formatting

    /// `fmt = (n) => cur + ' ' + Math.round(n).toLocaleString('en-US')`
    func fmt(_ n: Double) -> String { FinTrackFormatting.amount(n, data.currency) }

    /// `fmtN = (n) => Math.round(n).toLocaleString('en-US')`
    func fmtN(_ n: Double) -> String { FinTrackFormatting.number(n) }

    // MARK: - Derived values (renderVals)

    /// `sum(data.accounts, a => a.bal)`
    var personalBalance: Double {
        data.accounts.reduce(0) { $0 + $1.bal }
    }

    /// `sum(data.incomes.filter(i => i.type === 'Business'), i => i.amt)`
    var businessBalance: Double {
        data.incomes.filter { $0.type == .business }.reduce(0) { $0 + $1.amt }
    }

    var displayBalance: Double {
        mode == .personal ? personalBalance : businessBalance
    }

    var balanceLabel: String {
        mode == .personal ? "Total balance" : "Business balance"
    }

    /// The milestone list for the current mode — personal milestones are the editable ones.
    var milestones: [Milestone] {
        mode == .personal ? data.msPersonal : data.msBusiness
    }

    var owedToYou: Double {
        data.loans.filter { $0.dir == .inbound }.reduce(0) { $0 + $1.amt }
    }

    var youOwe: Double {
        data.loans.filter { $0.dir == .outbound }.reduce(0) { $0 + $1.amt }
    }

    /// `pctOf = (v) => bTotal ? Math.round(v / bTotal * 100) : 0`
    func bucketPct(_ b: Bucket) -> Int {
        AppStore.bucketPercent(data.bucketSpend[b], total: data.bucketSpend.total)
    }

    var budgetRuleLabel: String {
        mode == .personal ? "50 / 30 / 20" : "Ops / Growth / Profit"
    }

    /// Personal bars are computed from real spending; business bars are the static
    /// 48 / 22 / 30 split the prototype hard-codes.
    var budgetSegments: [(name: String, pct: Int, colorHex: String)] {
        if mode == .personal {
            return [
                (name: "Needs", pct: bucketPct(.needs), colorHex: "#0A84FF"),
                (name: "Wants", pct: bucketPct(.wants), colorHex: "#FF9F0A"),
                (name: "Savings", pct: bucketPct(.savings), colorHex: "#30D158"),
            ]
        }
        return [
            (name: "Ops", pct: 48, colorHex: "#0A84FF"),
            (name: "Growth", pct: 22, colorHex: "#FF9F0A"),
            (name: "Profit", pct: 30, colorHex: "#30D158"),
        ]
    }

    /// Every transaction booked against one account, in day order then row order.
    func transactions(forAccount name: String) -> [Transaction] {
        data.days.flatMap { $0.items }.filter { $0.acct == name }
    }

    // MARK: - Pure helpers (no live store needed)

    /// `pctOf = (v) => bTotal ? Math.round(v / bTotal * 100) : 0`
    nonisolated static func bucketPercent(_ value: Double, total: Double) -> Int {
        guard total != 0 else { return 0 }
        return Int(jsRound(value / total * 100))
    }

    /// `glyphOf = (s) => (s || 'TX').slice(0, 2).toUpperCase()`
    nonisolated static func glyph(from source: String) -> String {
        let base = source.isEmpty ? "TX" : source
        // JS `.slice(0, 2)` counts UTF-16 code units, so a leading non-BMP
        // character (an emoji surrogate pair) fills both slots on its own.
        // String.prefix(2) counts grapheme clusters and would append a second
        // character instead, so slice the UTF-16 view to match the prototype.
        let units = Array(base.utf16.prefix(2))
        return String(decoding: units, as: UTF16.self).uppercased()
    }

    /// `addTx(data, tx)` — prepend into an existing "Today" group, else start one.
    nonisolated static func addingTransaction(_ tx: Transaction, to days: [DayGroup]) -> [DayGroup] {
        var out = days
        if let first = out.first, first.label == "Today" {
            out[0].items.insert(tx, at: 0)
        } else {
            out.insert(DayGroup(label: "Today", items: [tx]), at: 0)
        }
        return out
    }

    /// Six-month repayment roadmap. `pay = ceil(amt / 6)`, the last instalment is whatever
    /// is left, and the bar is `max(4%, round((left + pay) / amt * 100))` — the prototype
    /// measures the bar from the balance *before* the instalment is subtracted.
    nonisolated static func loanRoadmap(amount: Double) -> [RoadmapEntry] {
        let months = ["Sep", "Oct", "Nov", "Dec", "Jan", "Feb"]
        let pay = (amount / 6).rounded(.up)
        let denominator = amount == 0 ? 1 : amount
        var left = amount
        var out: [RoadmapEntry] = []
        out.reserveCapacity(months.count)
        for (i, month) in months.enumerated() {
            let instalment = min(pay, left)
            left -= instalment
            let barPercent = max(4, Int(jsRound((left + instalment) / denominator * 100)))
            out.append(RoadmapEntry(month: month,
                                    label: month + " 2026" + (i > 3 ? "/27" : ""),
                                    pay: instalment,
                                    left: left,
                                    barFraction: Double(barPercent) / 100))
        }
        return out
    }

    func roadmap(for loan: Loan) -> [RoadmapEntry] {
        AppStore.loanRoadmap(amount: loan.amt)
    }

    // MARK: - Mutations

    func toggleTheme() {
        dark.toggle()
        persist()
    }

    func setMode(_ newMode: AppMode) {
        mode = newMode
    }

    /// Port of `saveEntry()`. Returns false and changes nothing when the entry is invalid:
    /// a non-positive amount, or a loan/milestone entry with an empty list to apply it to.
    @discardableResult
    func saveEntry(_ draft: EntryDraft, amount: Double, description: String) -> Bool {
        guard amount.isFinite, amount > 0 else { return false }

        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        var accounts = data.accounts
        // `Math.min(entry.acct, Math.max(0, accounts.length - 1))`
        let acctIdx = max(0, min(draft.acct, max(0, accounts.count - 1)))
        let acctName = accounts.isEmpty ? "\u{2014}" : accounts[acctIdx].name

        var next = data
        let tx: Transaction

        switch draft.kind {
        case .expense:
            let title = desc.isEmpty ? "Expense" : desc
            if !accounts.isEmpty { accounts[acctIdx].bal -= amount }
            next.bucketSpend[draft.bucket] += amount
            tx = Transaction(glyph: AppStore.glyph(from: title),
                             tintHex: "#FDEBEA",
                             colorHex: "#D2322A",
                             title: title,
                             sub: acctName + " \u{00B7} " + draft.bucket.rawValue,
                             amount: "\u{2212}" + fmtN(amount),
                             pos: false,
                             acct: acctName)

        case .income:
            let title = desc.isEmpty ? "Income" : desc
            if !accounts.isEmpty { accounts[acctIdx].bal += amount }
            tx = Transaction(glyph: AppStore.glyph(from: title),
                             tintHex: "#E9F6EC",
                             colorHex: "#248A3D",
                             title: title,
                             sub: acctName + " \u{00B7} Income",
                             amount: "+" + fmtN(amount),
                             pos: true,
                             acct: acctName)

        case .loan:
            guard !data.loans.isEmpty else { return false }
            var loans = data.loans
            let li = max(0, min(draft.loan, loans.count - 1))
            loans[li].amt = max(0, loans[li].amt - amount)
            next.loans = loans
            let incoming = loans[li].dir == .inbound
            if !accounts.isEmpty { accounts[acctIdx].bal += incoming ? amount : -amount }
            let title = desc.isEmpty
                ? loans[li].name + (incoming ? " repayment" : " payment")
                : desc
            tx = Transaction(glyph: AppStore.glyph(from: loans[li].name),
                             tintHex: "#E8F1FE",
                             colorHex: "#0A84FF",
                             title: title,
                             sub: "Loan \u{00B7} " + loans[li].name,
                             amount: (incoming ? "+" : "\u{2212}") + fmtN(amount),
                             pos: incoming,
                             acct: acctName)

        case .milestone:
            guard !data.msPersonal.isEmpty else { return false }
            var ms = data.msPersonal
            let mi = max(0, min(draft.ms, ms.count - 1))
            ms[mi].saved += amount
            next.msPersonal = ms
            next.bucketSpend.savings += amount
            if !accounts.isEmpty { accounts[acctIdx].bal -= amount }
            let title = desc.isEmpty ? ms[mi].name + " deposit" : desc
            tx = Transaction(glyph: AppStore.glyph(from: ms[mi].name),
                             tintHex: "#FFF3E0",
                             colorHex: "#C87B1B",
                             title: title,
                             sub: "Milestone \u{00B7} " + ms[mi].name,
                             amount: "\u{2212}" + fmtN(amount),
                             pos: false,
                             acct: acctName)
        }

        next.accounts = accounts
        next.days = AppStore.addingTransaction(tx, to: data.days)
        data = next
        persist()
        return true
    }

    /// `deleteTx(di, ii)` — remove the row, then drop the day group if it emptied out.
    func deleteTransaction(dayIndex: Int, itemIndex: Int) {
        guard data.days.indices.contains(dayIndex),
              data.days[dayIndex].items.indices.contains(itemIndex) else { return }
        mutate { d in
            d.days[dayIndex].items.remove(at: itemIndex)
            d.days.removeAll { $0.items.isEmpty }
        }
    }

    /// Port of the milestone-detail "Add money" handler: the milestone grows, the FIRST
    /// account is debited, the amount counts as Savings spend and a transaction is logged.
    /// Sets or clears a milestone's optional target date. `nil` returns the goal to
    /// open-ended, which is the default and a legitimate end state, not an error.
    func setMilestoneDate(index: Int, date: Date?) {
        guard data.msPersonal.indices.contains(index) else { return }
        mutate { $0.msPersonal[index].targetDate = date }
    }

    func addToMilestone(index: Int, amount: Double) {
        guard amount.isFinite, amount > 0, data.msPersonal.indices.contains(index) else { return }
        let name = data.msPersonal[index].name
        mutate { d in
            d.msPersonal[index].saved += amount
            if !d.accounts.isEmpty { d.accounts[0].bal -= amount }
            d.bucketSpend.savings += amount
            let tx = Transaction(glyph: AppStore.glyph(from: name),
                                 tintHex: "#FFF3E0",
                                 colorHex: "#C87B1B",
                                 title: name + " deposit",
                                 sub: "Milestone \u{00B7} " + name,
                                 amount: "\u{2212}" + FinTrackFormatting.number(amount),
                                 pos: false,
                                 acct: d.accounts.first?.name ?? "\u{2014}")
            d.days = AppStore.addingTransaction(tx, to: d.days)
        }
    }

    /// `addTx()` as a mutation.
    func addTransactionToToday(_ tx: Transaction) {
        mutate { d in d.days = AppStore.addingTransaction(tx, to: d.days) }
    }

    // MARK: - Settings mutations

    func setCurrency(_ currency: String) {
        mutate { $0.currency = currency }
    }

    /// `e.target.value.trim() || 'Leo'`
    func setCoachName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        mutate { $0.coach.name = trimmed.isEmpty ? "Leo" : trimmed }
    }

    func setCoachEmoji(_ emoji: String) {
        mutate { $0.coach.emoji = emoji }
    }

    func setCoachTone(_ tone: CoachTone) {
        mutate { $0.coach.tone = tone }
    }

    func setReminderAM(_ time: String) {
        mutate { $0.reminders.am = time }
    }

    func setReminderPM(_ time: String) {
        mutate { $0.reminders.pm = time }
    }

    func addAccount(name: String, bal: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate { $0.accounts.append(Account(name: trimmed, bal: bal)) }
    }

    func removeAccount(at index: Int) {
        guard data.accounts.indices.contains(index) else { return }
        mutate { $0.accounts.remove(at: index) }
    }

    /// `finishWizard()` — the new ledger replaces everything and the app returns to
    /// personal mode.
    func replaceAll(_ newData: AppData) {
        data = newData
        mode = .personal
        persist()
    }
}
