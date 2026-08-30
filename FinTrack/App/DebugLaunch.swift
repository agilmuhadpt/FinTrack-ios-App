#if DEBUG
import Foundation

/// DEBUG-only launch-argument hook used to drive the app into a specific screen for
/// screenshot verification, e.g.
///
///     xcrun simctl launch <device> com.fintrack.app -FTTab loans -FTDark 1
///
/// Compiled out of Release entirely. Recognised arguments:
///   -FTTab      home | activity | loans | coach
///   -FTDark     1 | 0
///   -FTMode     personal | business
///   -FTOverlay  entry | settings | wizard | alert | banner |
///               loan:<i> | milestone:<i> | account:<i>
///   -FTFresh    1   — start from a blank ledger instead of the demo data
///   -FTNoBanner 1   — suppress the timed launch banner
enum DebugLaunch {

    private static var args: [String: String] = {
        var out: [String: String] = [:]
        let raw = ProcessInfo.processInfo.arguments
        var i = 0
        while i < raw.count {
            if raw[i].hasPrefix("-FT"), i + 1 < raw.count, !raw[i + 1].hasPrefix("-") {
                out[raw[i]] = raw[i + 1]
                i += 2
            } else {
                i += 1
            }
        }
        return out
    }()

    static var suppressBanner: Bool { args["-FTNoBanner"] == "1" }
    /// `-FTAsk "<text>"` — sends one real message to the coach on launch, so the whole
    /// Ollama round trip (prompt assembly, HTTP, parsing, rendering) can be verified
    /// without a tap.
    static var ask: String? { args["-FTAsk"] }
    static var startFresh: Bool { args["-FTFresh"] == "1" }
    /// `-FTDemo 1` — restore the seeded demo ledger before the UI appears. UI tests mutate
    /// persistent state (a swipe really does delete and really does write to disk), so
    /// without this each test inherits whatever the previous one left behind.
    static var resetToDemo: Bool { args["-FTDemo"] == "1" }

    static var dark: Bool? {
        guard let v = args["-FTDark"] else { return nil }
        return v == "1"
    }

    static var mode: AppMode? {
        switch args["-FTMode"] {
        case "personal": return .personal
        case "business": return .business
        default: return nil
        }
    }

    static var tab: Tab? {
        switch args["-FTTab"] {
        case "home": return .home
        case "activity": return .activity
        case "loans": return .loans
        case "coach": return .coach
        default: return nil
        }
    }

    /// Applies every recognised argument to the live state.
    @MainActor
    static func apply(store: AppStore, ui: UIState) {
        if resetToDemo { store.replaceAll(.demo()) }
        if startFresh { store.replaceAll(.empty(currency: "SAR")) }
        if let dark { store.dark = dark }
        if let mode { store.mode = mode }
        if let tab { ui.tab = tab }

        if let ask, !ask.isEmpty {
            ui.tab = .coach
            CoachService.shared.send(ask, store: store)
        }

        guard let overlay = args["-FTOverlay"] else { return }
        let parts = overlay.split(separator: ":", maxSplits: 1).map(String.init)
        let index = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        switch parts[0] {
        case "entry":     ui.showEntry = true
        case "settings":  ui.showSettings = true
        case "wizard":    ui.showWizard = true
        case "alert":     ui.showResetAlert = true
        case "banner":    ui.showBanner = true
        case "loan":      ui.detail = .loan(index)
        case "milestone": ui.detail = .milestone(index)
        case "account":   ui.detail = .account(index)
        default: break
        }
    }
}
#endif
