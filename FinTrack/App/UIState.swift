import Foundation
import Observation

/// Which root tab is showing. The prototype switches tabs with no animation at all
/// ("high-frequency action" — README, Interactions & Behavior), so nothing here is animated.
enum Tab: Hashable {
    case home, activity, loans, coach
}

/// The single full-screen detail overlay, shared by the loan / milestone / account screens
/// exactly as the prototype's `view: { t, i }` is.
enum DetailRoute: Hashable {
    case loan(Int)
    case milestone(Int)
    case account(Int)
}

/// Ephemeral navigation and presentation state.
///
/// Deliberately separate from `AppStore`: nothing here is persisted, and keeping it out of
/// the store means a tab change or a sheet dismissal never triggers a disk write.
/// Mirrors the prototype's non-`data` state keys (`tab`, `view`, `sheet`, `alert`, `wiz`, `banner`).
@MainActor
@Observable
final class UIState {

    var tab: Tab = .home

    /// Non-nil while the loan / milestone / account detail overlay is up (`state.view`).
    var detail: DetailRoute?

    /// The settings overlay (`state.view.t === 'settings'`).
    var showSettings = false

    /// The "New entry" bottom sheet (`state.sheet`).
    var showEntry = false

    /// The destructive "Start fresh?" confirmation (`state.alert`).
    var showResetAlert = false

    /// The full-screen onboarding wizard (`state.wiz !== null`).
    /// The wizard owns its own draft internally; finishing it calls `AppStore.replaceAll`.
    var showWizard = false

    /// The simulated push banner (`state.banner`).
    var showBanner = false

    /// `showBanner && !wiz && !sheet` — the prototype hides the banner behind either overlay.
    var bannerVisible: Bool { showBanner && !showWizard && !showEntry }

    // MARK: - Transitions (ported from the prototype's inline setState calls)

    /// `askReset` — the ↺ button only opens the confirmation; it never resets directly.
    func askReset() { showResetAlert = true }

    /// `cancelReset`
    func cancelReset() { showResetAlert = false }

    /// `confirmReset` — dismisses the alert, drops any detail overlay, and opens a blank wizard.
    func confirmReset() {
        showResetAlert = false
        detail = nil
        showSettings = false
        showWizard = true
    }

    /// `openEntry` — opening the sheet also dismisses the banner.
    func openEntry() {
        showEntry = true
        showBanner = false
    }

    func closeEntry() { showEntry = false }

    /// `bannerTap` — tapping the notification opens the New Entry sheet.
    func tapBanner() {
        showBanner = false
        showEntry = true
    }

    func openDetail(_ route: DetailRoute) { detail = route }
    func closeDetail() { detail = nil }

    func openSettings() { showSettings = true }
    func closeSettings() { showSettings = false }

    /// Called by the wizard when it finishes or is cancelled.
    func closeWizard() {
        showWizard = false
        tab = .home
        detail = nil
        showSettings = false
    }
}
