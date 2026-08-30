//  Formatters.swift
//  FinTrack — number formatting, ported from the prototype's
//  `Math.round(n).toLocaleString('en-US')`.

import Foundation

/// JavaScript's `Math.round` rounds half **up** (toward +∞), not half away from zero:
/// `Math.round(2.5) === 3` but `Math.round(-2.5) === -2`. Swift's `.rounded()` /
/// `.toNearestOrAwayFromZero` would give −3, so the port uses `floor(n + 0.5)`, which is
/// exactly the ECMAScript definition and agrees with `.toNearestOrAwayFromZero` for n ≥ 0.
func jsRound(_ n: Double) -> Double {
    guard n.isFinite else { return 0 }
    return (n + 0.5).rounded(.down)
}

/// One cached formatter so grouped output never varies with the device locale.
/// `en_US_POSIX` + an explicit "," separator reproduces `toLocaleString('en-US')`.
private let groupedNumberFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.numberStyle = .decimal
    f.usesGroupingSeparator = true
    f.groupingSeparator = ","
    f.groupingSize = 3
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 0
    f.negativePrefix = "-"
    return f
}()

/// `Math.round(n).toLocaleString('en-US')` — rounded to a whole number, comma-grouped,
/// no currency. e.g. `fmtN(8450)` → "8,450".
func fmtN(_ n: Double) -> String {
    var rounded = jsRound(n)
    if rounded == 0 { rounded = 0 } // collapse -0 so it never renders as "-0"
    return groupedNumberFormatter.string(from: NSNumber(value: rounded)) ?? "0"
}

/// Currency + space + `fmtN`. e.g. `fmt(8450, "SAR")` → "SAR 8,450".
func fmt(_ n: Double, _ currency: String) -> String {
    currency + " " + fmtN(n)
}

extension Double {
    /// `8450.4.fmtN` → "8,450"
    var fmtN: String { FinTrackFormatting.number(self) }

    /// `8450.4.fmt("SAR")` → "SAR 8,450"
    func fmt(_ currency: String) -> String { FinTrackFormatting.amount(self, currency) }
}

/// Namespaced spellings of the two free functions, for call sites that would otherwise be
/// ambiguous with a local `fmt`/`fmtN`.
enum FinTrackFormatting {
    static func number(_ n: Double) -> String { fmtN(n) }
    static func amount(_ n: Double, _ currency: String) -> String { fmt(n, currency) }

    /// The single parser for every amount the user types. Returns nil for anything that is
    /// not a usable positive-or-zero number, so callers can reject rather than guess.
    ///
    /// Naively swapping "," for "." reads en_US "1,500" as 1.5 — a 1000x understatement in
    /// a finance app. The grouping separator is compared against the locale's DECIMAL
    /// separator (not against a literal "."), which is what makes de_DE "1.500" parse as
    /// 1500 rather than 1.5.
    static func amount(from text: String) -> Double? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        let decimal = Locale.current.decimalSeparator ?? "."
        if let grouping = Locale.current.groupingSeparator, grouping != decimal {
            t = t.replacingOccurrences(of: grouping, with: "")
        }
        // fr_FR and friends group with a (narrow) non-breaking space.
        t = t.replacingOccurrences(of: "\u{00A0}", with: "")
             .replacingOccurrences(of: "\u{202F}", with: "")
             .replacingOccurrences(of: " ", with: "")
        if decimal != "." { t = t.replacingOccurrences(of: decimal, with: ".") }

        guard let v = Double(t), v.isFinite else { return nil }
        return v
    }

    private static let shortMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.setLocalizedDateFormatFromTemplate("LLL yyyy")
        return f
    }()

    private static let longMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return f
    }()

    /// "Jun 2027" — the compact form used on the Home milestone card.
    static func monthYear(_ date: Date) -> String { shortMonthYear.string(from: date) }

    /// "June 2027" — the milestone detail screen has room for the full name.
    static func longMonthYear(_ date: Date) -> String { longMonthYear.string(from: date) }
}
