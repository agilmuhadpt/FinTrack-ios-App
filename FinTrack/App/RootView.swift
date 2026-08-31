import SwiftUI

/// The single screen the app ever shows.
///
/// Mirrors the prototype's one-page structure: a tab body, the tab bar, and a stack of
/// absolutely-positioned overlays layered by z-index —
/// detail (40) < settings (45) < entry sheet (55/56) < alert (60) < banner (70).
struct RootView: View {

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: Theme { .resolve(dark: store.dark) }

    var body: some View {
        ZStack {
            // Theme change cross-fades backgrounds over 300ms (DESIGN-HANDOFF.md, Interactions).
            theme.bg
                .ignoresSafeArea()
                .animation(FTMotion.themeCrossfade, value: store.dark)

            tabBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Behind a modal, this content must leave the accessibility tree —
                // otherwise VoiceOver walks straight into the screen underneath.
                .accessibilityHidden(ui.overlayPresented)

            // The tab bar hides behind the wizard, which is full-screen.
            if !ui.showWizard {
                VStack {
                    Spacer()
                    TabBarView()
                }
                .ignoresSafeArea(edges: .bottom)
                .accessibilityHidden(ui.overlayPresented)
            }

            overlays
        }
        .theme(dark: store.dark)
        .environment(\.colorScheme, store.dark ? .dark : .light)
        .preferredColorScheme(store.dark ? .dark : .light)
        .animation(FTMotion.themeCrossfade, value: store.dark)
        .task { await scheduleLaunchBanner() }
    }

    // MARK: - Tab body

    @ViewBuilder
    private var tabBody: some View {
        // No transition: tab switching is instant by design.
        switch ui.tab {
        case .home:     HomeView()
        case .activity: ActivityView()
        case .loans:    LoansView()
        case .coach:    CoachView()
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var overlays: some View {
        // z-index 40 — loan / milestone / account detail
        if let route = ui.detail {
            DetailHostView(route: route)
                .transition(.opacity)           // animation:fadeIn 200ms ease
                .zIndex(40)
        }

        // z-index 45 — settings
        if ui.showSettings {
            SettingsView()
                .transition(.opacity)
                .zIndex(45)
        }

        // z-index 55/56 — new entry sheet + scrim
        if ui.showEntry {
            NewEntrySheet()
                .zIndex(55)
        }

        // z-index 60 — destructive confirmation
        if ui.showResetAlert {
            StartFreshAlert()
                .zIndex(60)
        }

        // z-index 70 — simulated push banner
        if ui.bannerVisible {
            PushBannerView()
                .zIndex(70)
        }

        // Full screen — onboarding wizard
        if ui.showWizard {
            OnboardingWizardView()
                .transition(.opacity)
                .zIndex(80)
        }
    }

    // MARK: - Launch banner

    /// The prototype drops the banner 3s after launch and auto-dismisses it ~9s later.
    private func scheduleLaunchBanner() async {
        #if DEBUG
        if DebugLaunch.suppressBanner { return }
        #endif
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled, !ui.showWizard, !ui.showEntry else { return }
        withAnimation(FTMotion.resolved(FTMotion.drawer, reduceMotion: reduceMotion)) {
            ui.showBanner = true
        }
        try? await Task.sleep(for: .seconds(9))
        guard !Task.isCancelled else { return }
        withAnimation(FTMotion.resolved(FTMotion.drawer, reduceMotion: reduceMotion)) {
            ui.showBanner = false
        }
    }
}

/// Routes the shared detail overlay to the right screen, matching the prototype's
/// single `view: { t, i }` slot. Out-of-range indices close the overlay instead of
/// crashing, which is what the prototype's `if (l)` / `if (m)` / `if (a)` guards do.
struct DetailHostView: View {

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui

    let route: DetailRoute

    var body: some View {
        switch route {
        case .loan(let i):
            if store.data.loans.indices.contains(i) { LoanDetailView(index: i) } else { dismissed }
        case .milestone(let i, let business):
            let list = business ? store.data.msBusiness : store.data.msPersonal
            if list.indices.contains(i) {
                MilestoneDetailView(index: i, business: business)
            } else { dismissed }
        case .account(let i):
            if store.data.accounts.indices.contains(i) { AccountDetailView(index: i) } else { dismissed }
        }
    }

    private var dismissed: some View {
        Color.clear.onAppear { ui.closeDetail() }
    }
}
