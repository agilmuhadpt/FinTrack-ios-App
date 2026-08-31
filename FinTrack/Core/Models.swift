//  Models.swift
//  FinTrack — Core data model.
//
//  Ported 1:1 from the prototype logic class in FinTrack.dc.html (lines 651-1181).
//  Copy strings are FINAL: the separator in subtitles is U+00B7 "·" and the minus sign in
//  amounts is U+2212 "−" (never an ASCII hyphen). Every Codable decodes tolerantly — a
//  missing or unrecognised key falls back to a default instead of throwing, so an older
//  saved file can never wipe the user's data.

import Foundation

// MARK: - Enums

enum IncomeType: String, Codable, CaseIterable {
    case personal = "Personal"
    case business = "Business"
}

enum LoanDirection: String, Codable {
    case inbound = "in"
    case outbound = "out"
}

enum Bucket: String, Codable, CaseIterable, Identifiable {
    case needs = "Needs"
    case wants = "Wants"
    case savings = "Savings"

    var id: String { rawValue }
}

enum CoachTone: String, Codable, CaseIterable {
    case playful = "Playful"
    case serious = "Serious"
}

enum AppMode {
    case personal
    case business
}

// MARK: - Value types

struct Account: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var bal: Double

    fileprivate enum CodingKeys: String, CodingKey { case id, name, bal }
}

struct Income: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var amt: Double
    var type: IncomeType

    fileprivate enum CodingKeys: String, CodingKey { case id, name, amt, type }
}

struct Loan: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var amt: Double
    var dir: LoanDirection
    var sub: String

    fileprivate enum CodingKeys: String, CodingKey { case id, name, amt, dir, sub }
}

/// What a milestone's optional target date implies right now.
///
/// Deliberately has no "on track" case. Judging pace would need a contribution
/// history, and `Transaction` carries no timestamp — only a day-group label — so any
/// such verdict would be invented. These four cases are all that the data supports.
enum MilestonePace: Equatable {
    /// No target date set. The milestone behaves exactly as it did before.
    case noDate
    /// Already funded; a deadline no longer means anything.
    case complete
    /// The date has passed with money still owing.
    case overdue(days: Int)
    /// What it takes to finish on time, and how many calendar months are left.
    case due(perMonth: Double, months: Int)
}

struct Milestone: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var saved: Double
    var target: Double
    var colorHex: String
    /// Optional. Goals like "Travel fund" are legitimately open-ended, so a date is never
    /// required and nothing about the milestone changes until one is set.
    var targetDate: Date?

    /// `m.target ? Math.min(100, Math.round(m.saved / m.target * 100)) : 0`
    var pct: Int {
        guard target > 0 else { return 0 }
        let raw = (saved / target * 100).rounded()
        // Clamp in Double space: Int(Double) traps on NaN/inf and on anything
        // outside Int.min...Int.max, which JS's Math.min could never do.
        guard raw.isFinite else { return raw > 0 ? 100 : 0 }
        return Int(max(0, min(100, raw)))
    }

    /// Money still to find. Floors at zero so an over-funded goal never reads negative.
    var remaining: Double { max(0, target - saved) }

    var isComplete: Bool { target > 0 && saved >= target }

    /// Calendar months until the target, rounded UP: a partial month is still a month in
    /// which a contribution can be made, and rounding down would overstate the monthly
    /// figure. Always at least 1 for a future date.
    func monthsRemaining(from now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let targetDate else { return nil }
        guard targetDate > now else { return 0 }
        let parts = calendar.dateComponents([.month, .day], from: now, to: targetDate)
        var months = parts.month ?? 0
        if (parts.day ?? 0) > 0 { months += 1 }
        return max(1, months)
    }

    /// The one number worth deriving from a target date: what finishing on time costs
    /// per month. The savings mirror of the loan roadmap's required payment.
    func pace(from now: Date = Date(), calendar: Calendar = .current) -> MilestonePace {
        guard let targetDate else { return .noDate }
        if isComplete { return .complete }
        guard targetDate > now else {
            let days = calendar.dateComponents([.day], from: targetDate, to: now).day ?? 0
            return .overdue(days: max(0, days))
        }
        guard let months = monthsRemaining(from: now, calendar: calendar), months > 0 else {
            return .overdue(days: 0)
        }
        return .due(perMonth: remaining / Double(months), months: months)
    }

    fileprivate enum CodingKeys: String, CodingKey { case id, name, saved, target, colorHex, targetDate }
    /// The prototype wrote this field as `color`; still accepted when reading.
    fileprivate enum LegacyCodingKeys: String, CodingKey { case color }
}

struct Transaction: Identifiable, Codable, Hashable {
    var id = UUID()
    var glyph: String
    var tintHex: String
    var colorHex: String
    var title: String
    var sub: String
    var amount: String
    var pos: Bool
    var acct: String

    fileprivate enum CodingKeys: String, CodingKey {
        case id, glyph, tintHex, colorHex, title, sub, amount, pos, acct
    }
}

struct DayGroup: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var items: [Transaction]

    fileprivate enum CodingKeys: String, CodingKey { case id, label, items }
}

/// Where a business expense goes. The Studio counterpart to `Bucket`, kept as a
/// separate type rather than folded into it: the two sets are never interchangeable, and
/// a single enum would let a "Needs" expense land in the business bar.
enum BusinessBucket: String, Codable, CaseIterable, Identifiable {
    case ops = "Ops"
    case growth = "Growth"
    case profit = "Profit"

    var id: String { rawValue }
}

/// Business spend by bucket. Before this existed the business bar was a hardcoded
/// 48/22/30 carried over from the prototype, because the app recorded no business
/// expenses at all and there was nothing to compute from.
struct BusinessBucketSpend: Codable, Hashable {
    var ops: Double = 0
    var growth: Double = 0
    var profit: Double = 0

    var total: Double { ops + growth + profit }

    subscript(b: BusinessBucket) -> Double {
        get {
            switch b {
            case .ops: return ops
            case .growth: return growth
            case .profit: return profit
            }
        }
        set {
            switch b {
            case .ops: ops = newValue
            case .growth: growth = newValue
            case .profit: profit = newValue
            }
        }
    }
}

struct BucketSpend: Codable, Hashable {
    var needs: Double
    var wants: Double
    var savings: Double

    var total: Double { needs + wants + savings }

    subscript(b: Bucket) -> Double {
        get {
            switch b {
            case .needs: return needs
            case .wants: return wants
            case .savings: return savings
            }
        }
        set {
            switch b {
            case .needs: needs = newValue
            case .wants: wants = newValue
            case .savings: savings = newValue
            }
        }
    }

    fileprivate enum CodingKeys: String, CodingKey { case needs, wants, savings }
    /// The prototype keyed this object by the bucket display names.
    fileprivate enum LegacyCodingKeys: String, CodingKey {
        case needs = "Needs"
        case wants = "Wants"
        case savings = "Savings"
    }
}

struct Coach: Codable, Hashable {
    var name: String
    var emoji: String
    var tone: CoachTone

    /// 😊 🦁 🤖 🐨 ⭐ — the five options offered in Settings and in the wizard.
    static let emojiOptions = ["\u{1F60A}", "\u{1F981}", "\u{1F916}", "\u{1F428}", "\u{2B50}"]

    fileprivate enum CodingKeys: String, CodingKey { case name, emoji, tone }
}

/// Reminder times, stored as 24h "HH:mm" strings exactly as the prototype does.
struct Reminders: Codable, Hashable {
    var am: String
    var pm: String

    fileprivate enum CodingKeys: String, CodingKey { case am, pm }
}

// MARK: - AppData

struct AppData: Codable, Hashable {
    var currency: String
    var accounts: [Account]
    var incomes: [Income]
    var loans: [Loan]
    var msPersonal: [Milestone]
    var msBusiness: [Milestone]
    var bucketSpend: BucketSpend
    /// Business-mode spend. Absent from every ledger written before business expenses
    /// were recorded, and decodes to all-zero there.
    var businessBucketSpend = BusinessBucketSpend()
    var coach: Coach
    var reminders: Reminders
    var days: [DayGroup]

    static let currencyOptions = ["SAR", "AED", "KWD", "USD", "EUR", "INR"]

    /// Colours assigned to wizard milestones, cycled by index — `['#30D158', '#0A84FF', '#FF9F0A'][i % 3]`.
    static let milestonePalette = ["#30D158", "#0A84FF", "#FF9F0A"]

    fileprivate enum CodingKeys: String, CodingKey {
        case currency, accounts, incomes, loans, msPersonal, msBusiness
        case bucketSpend, businessBucketSpend, coach, reminders, days
    }

    /// Exact seed data from `demoData()` in the prototype.
    static func demo() -> AppData {
        AppData(
            currency: "SAR",
            accounts: [
                Account(name: "Northbank", bal: 8450),
                Account(name: "CityPay", bal: 1900),
            ],
            incomes: [
                Income(name: "Salary", amt: 4000, type: .personal),
                Income(name: "Studio", amt: 5500, type: .business),
                Income(name: "Pending invoices", amt: 1200, type: .business),
            ],
            loans: [
                Loan(name: "Credit card", amt: 9000, dir: .outbound, sub: "You owe \u{00B7} avalanche priority 1"),
                Loan(name: "Equipment loan", amt: 6000, dir: .outbound, sub: "You owe \u{00B7} priority 2"),
                Loan(name: "Adam", amt: 3000, dir: .inbound, sub: "Owed to you \u{00B7} 250 collected"),
                Loan(name: "Basil", amt: 1500, dir: .inbound, sub: "Owed to you"),
                Loan(name: "Cara", amt: 1200, dir: .inbound, sub: "Owed to you"),
                Loan(name: "Dana", amt: 800, dir: .inbound, sub: "Owed to you"),
            ],
            msPersonal: [
                Milestone(name: "Emergency fund", saved: 3300, target: 6000, colorHex: "#30D158"),
                Milestone(name: "Travel fund", saved: 1000, target: 5000, colorHex: "#0A84FF"),
                Milestone(name: "Loan collection", saved: 2600, target: 6500, colorHex: "#FF9F0A"),
            ],
            msBusiness: [
                Milestone(name: "Q3 revenue target", saved: 9000, target: 15000, colorHex: "#30D158"),
                Milestone(name: "Runway reserve", saved: 2000, target: 8000, colorHex: "#0A84FF"),
                Milestone(name: "Invoice collection", saved: 550, target: 1200, colorHex: "#FF9F0A"),
            ],
            bucketSpend: BucketSpend(needs: 2000, wants: 1100, savings: 900),
            // Not a ratio that reproduces the prototype's old hardcoded 48/22/30 — that
            // made a screenshot unable to tell computed from fake. 51/19/30 of 5,000.
            businessBucketSpend: BusinessBucketSpend(ops: 2550, growth: 950, profit: 1500),
            coach: Coach(name: "Leo", emoji: "\u{1F60A}", tone: .playful),
            reminders: Reminders(am: "08:00", pm: "20:00"),
            days: [
                DayGroup(label: "Today", items: [
                    Transaction(glyph: "GR", tintHex: "#E9F6EC", colorHex: "#248A3D", title: "Groceries",
                                sub: "Northbank \u{00B7} Needs", amount: "\u{2212}92.40", pos: false, acct: "Northbank"),
                    Transaction(glyph: "ST", tintHex: "#E8F1FE", colorHex: "#0A84FF", title: "Studio payout",
                                sub: "Business income", amount: "+1,450", pos: true, acct: "Northbank"),
                ]),
                DayGroup(label: "Yesterday", items: [
                    Transaction(glyph: "CF", tintHex: "#FFF3E0", colorHex: "#C87B1B", title: "Coffee",
                                sub: "CityPay \u{00B7} Wants", amount: "\u{2212}12.50", pos: false, acct: "CityPay"),
                    Transaction(glyph: "AD", tintHex: "#E9F6EC", colorHex: "#248A3D", title: "Adam repayment",
                                sub: "Loan collection", amount: "+250", pos: true, acct: "Northbank"),
                    Transaction(glyph: "FU", tintHex: "#FDEBEA", colorHex: "#D2322A", title: "Fuel",
                                sub: "Northbank \u{00B7} Needs", amount: "\u{2212}74.00", pos: false, acct: "Northbank"),
                ]),
            ]
        )
    }

    /// A fully blank ledger — what `finishWizard()` produces when every step is skipped.
    static func empty(currency: String) -> AppData {
        AppData(
            currency: currency,
            accounts: [], incomes: [], loans: [],
            msPersonal: [], msBusiness: [],
            bucketSpend: BucketSpend(needs: 0, wants: 0, savings: 0),
            businessBucketSpend: BusinessBucketSpend(),
            coach: Coach(name: "Leo", emoji: "\u{1F60A}", tone: .playful),
            reminders: Reminders(am: "08:00", pm: "20:00"),
            days: []
        )
    }

    /// Port of `finishWizard()`. Loan subs are rewritten from their direction, milestones
    /// start at `saved: 0` and take their colour from `milestonePalette[i % 3]`; business
    /// milestones, bucket spend and activity all start empty.
    static func fromWizard(currency: String,
                           accounts: [Account],
                           incomes: [Income],
                           loans: [Loan],
                           milestones: [Milestone],
                           coachName: String,
                           coachEmoji: String,
                           tone: CoachTone,
                           am: String,
                           pm: String) -> AppData {
        var out = AppData.empty(currency: currency)
        out.accounts = accounts
        out.incomes = incomes
        out.loans = loans.map { loan in
            var copy = loan
            copy.sub = loan.dir == .inbound ? "Owed to you" : "You owe"
            return copy
        }
        out.msPersonal = milestones.enumerated().map { index, milestone in
            Milestone(name: milestone.name, saved: 0, target: milestone.target,
                      colorHex: milestonePalette[index % milestonePalette.count])
        }
        let trimmedName = coachName.trimmingCharacters(in: .whitespacesAndNewlines)
        out.coach = Coach(name: trimmedName.isEmpty ? "Leo" : trimmedName,
                          emoji: coachEmoji,
                          tone: tone)
        out.reminders = Reminders(am: am.isEmpty ? "08:00" : am,
                                  pm: pm.isEmpty ? "20:00" : pm)
        return out
    }
}

// MARK: - Tolerant decoding
//
// Every `init(from:)` lives in an extension so the memberwise initializer survives, and
// every field is read with `decodeIfPresent` so a truncated, partial or older file
// degrades to defaults instead of throwing. Raw-value enums are read as plain strings
// first, so an unrecognised value falls back rather than failing the whole document.

/// Set on a `JSONDecoder` to supply the field-by-field fallback for `AppData`, which is how
/// the prototype's `{ ...this.demoData(), ...p.data }` merge is reproduced.
extension CodingUserInfoKey {
    static let appDataFallback = CodingUserInfoKey(rawValue: "fintrack.appDataFallback")!
}

private func decodeValue<K: CodingKey, T: Decodable>(_ container: KeyedDecodingContainer<K>,
                                                     _ key: K,
                                                     _ fallback: T) -> T {
    (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
}

private func decodeEnum<K: CodingKey, T: RawRepresentable>(_ container: KeyedDecodingContainer<K>,
                                                           _ key: K,
                                                           _ fallback: T) -> T where T.RawValue == String {
    guard let raw = try? container.decodeIfPresent(String.self, forKey: key),
          let value = T(rawValue: raw) else { return fallback }
    return value
}

extension Account {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: decodeValue(c, .id, UUID()),
                  name: decodeValue(c, .name, ""),
                  bal: decodeValue(c, .bal, 0))
    }
}

extension Income {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: decodeValue(c, .id, UUID()),
                  name: decodeValue(c, .name, ""),
                  amt: decodeValue(c, .amt, 0),
                  type: decodeEnum(c, .type, IncomeType.personal))
    }
}

extension Loan {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: decodeValue(c, .id, UUID()),
                  name: decodeValue(c, .name, ""),
                  amt: decodeValue(c, .amt, 0),
                  dir: decodeEnum(c, .dir, LoanDirection.inbound),
                  sub: decodeValue(c, .sub, ""))
    }
}

extension Milestone {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var hex = decodeValue(c, .colorHex, "")
        if hex.isEmpty, let legacy = try? decoder.container(keyedBy: LegacyCodingKeys.self) {
            hex = decodeValue(legacy, .color, "")
        }
        self.init(id: decodeValue(c, .id, UUID()),
                  name: decodeValue(c, .name, ""),
                  saved: decodeValue(c, .saved, 0),
                  target: decodeValue(c, .target, 0),
                  colorHex: hex.isEmpty ? "#30D158" : hex,
                  // Absent in every ledger written before target dates existed, and
                  // absent for any goal the user leaves open-ended. Both decode to nil.
                  targetDate: try? c.decodeIfPresent(Date.self, forKey: .targetDate))
    }
}

extension Transaction {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: decodeValue(c, .id, UUID()),
                  glyph: decodeValue(c, .glyph, "TX"),
                  tintHex: decodeValue(c, .tintHex, "#F2F2F7"),
                  colorHex: decodeValue(c, .colorHex, "#8E8E93"),
                  title: decodeValue(c, .title, ""),
                  sub: decodeValue(c, .sub, ""),
                  amount: decodeValue(c, .amount, ""),
                  pos: decodeValue(c, .pos, false),
                  acct: decodeValue(c, .acct, ""))
    }
}

extension DayGroup {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: decodeValue(c, .id, UUID()),
                  label: decodeValue(c, .label, ""),
                  items: decodeValue(c, .items, [Transaction]()))
    }
}

extension BucketSpend {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try? decoder.container(keyedBy: LegacyCodingKeys.self)
        func read(_ key: CodingKeys, _ legacyKey: LegacyCodingKeys) -> Double {
            if let v = try? c.decodeIfPresent(Double.self, forKey: key) { return v }
            if let legacy, let v = try? legacy.decodeIfPresent(Double.self, forKey: legacyKey) { return v }
            return 0
        }
        self.init(needs: read(.needs, .needs),
                  wants: read(.wants, .wants),
                  savings: read(.savings, .savings))
    }
}

extension Coach {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: decodeValue(c, .name, "Leo"),
                  emoji: decodeValue(c, .emoji, "\u{1F60A}"),
                  tone: decodeEnum(c, .tone, CoachTone.playful))
    }
}

extension Reminders {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(am: decodeValue(c, .am, "08:00"),
                  pm: decodeValue(c, .pm, "20:00"))
    }
}

extension AppData {
    /// Reproduces `{ ...this.demoData(), ...p.data }`: any field the saved file omits keeps
    /// the fallback's value (the demo ledger unless the decoder's userInfo says otherwise).
    init(from decoder: Decoder) throws {
        let base = (decoder.userInfo[.appDataFallback] as? AppData) ?? .demo()
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = base
            return
        }
        self.init(currency: decodeValue(c, .currency, base.currency),
                  accounts: decodeValue(c, .accounts, base.accounts),
                  incomes: decodeValue(c, .incomes, base.incomes),
                  loans: decodeValue(c, .loans, base.loans),
                  msPersonal: decodeValue(c, .msPersonal, base.msPersonal),
                  msBusiness: decodeValue(c, .msBusiness, base.msBusiness),
                  bucketSpend: decodeValue(c, .bucketSpend, base.bucketSpend),
                  businessBucketSpend: decodeValue(c, .businessBucketSpend, base.businessBucketSpend),
                  coach: decodeValue(c, .coach, base.coach),
                  reminders: decodeValue(c, .reminders, base.reminders),
                  days: decodeValue(c, .days, base.days))
    }
}
