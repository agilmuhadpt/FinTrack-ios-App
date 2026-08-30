//
//  OnboardingWizardView.swift
//  FinTrack — the nine-step onboarding wizard ("Start fresh").
//
//  Full-screen cover shown while `ui.showWizard`. It owns its draft locally and writes
//  nothing to the store until the user finishes: `Cancel` on step 0 discards everything.
//
//  Markup: FinTrack.dc.html lines 409-551. Logic: `wizardVals()` / `finishWizard()`,
//  lines 1105-1180 and 838-851.
//
//  Safe area: the prototype's `padding-top:58px` is the mock frame's status bar and the
//  footer's `padding-bottom:34px` is its home indicator — on real iOS both come from the
//  safe area, so only the elements' own paddings (10pt top on the control row, 20pt
//  gutters) are applied here.
//

import SwiftUI

struct OnboardingWizardView: View {

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft = WizardDraft()

    /// The id the scroll view jumps back to whenever the step changes.
    private let topAnchor = "wizardTop"

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                controlRow
                stepBody
                footer
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Control row

    /// `padding:10px 20px 0;display:flex;align-items:center;gap:14px`
    private var controlRow: some View {
        HStack(spacing: 14) {
            Button(action: back) {
                Text(draft.backLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FTColor.blue)
                    .padding(.vertical, 6)
            }
            .buttonStyle(FTPressableStyle(scale: 0.95))

            // `flex:1;height:4px;border-radius:999px;background:var(--chip)` with a blue
            // fill that eases over 250ms — FTProgressBar already carries that curve.
            FTProgressBar(progress: draft.progress, height: 4, color: FTColor.blue)
                .accessibilityLabel("Step \(draft.step + 1) of \(WizardDraft.lastStep + 1)")

            if draft.isSkippable {
                Button(action: next) {
                    Text("Skip")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.sub)
                        .padding(.vertical, 6)
                }
                .buttonStyle(FTPressableStyle(scale: 0.95))
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, FTSpacing.gutter)
    }

    // MARK: - Step body

    /// `flex:1;overflow-y:auto;padding:20px 20px 20px`
    private var stepBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchor)

                    // `margin:8px 0 4px;font-size:28px;font-weight:800;letter-spacing:-0.02em`
                    Text(draft.title)
                        .ftDetailTitleStyle()
                        .foregroundStyle(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .accessibilityAddTraits(.isHeader)

                    // `font-size:15px;color:var(--sub);line-height:1.45` — 21.75pt of line
                    // box against SF Pro Text 15pt's own ~17.9pt.
                    Text(draft.subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(theme.sub)
                        .lineSpacing(ftLineSpacing(size: 15, lineHeight: 1.45))
                        .fixedSize(horizontal: false, vertical: true)

                    step
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FTSpacing.gutter)
                // A step change is a full content swap, exactly like the prototype's
                // `sc-if` remount: the transient fields inside each step reset with it.
                .id(draft.step)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: draft.step) {
                proxy.scrollTo(topAnchor, anchor: .top)
            }
        }
    }

    @ViewBuilder
    private var step: some View {
        switch draft.step {
        case 0:
            WizardWelcomeStep()
        case 1:
            WizardCurrencyStep(currency: $draft.currency)
        case 2:
            WizardAccountsStep(accounts: $draft.accounts, currency: draft.currency)
        case 3:
            WizardIncomeStep(incomes: $draft.incomes,
                             type: $draft.incType,
                             currency: draft.currency)
        case 4:
            WizardLoansStep(loans: $draft.loans,
                            direction: $draft.loanDir,
                            currency: draft.currency)
        case 5:
            WizardMilestonesStep(milestones: $draft.milestones, currency: draft.currency)
        case 6:
            WizardCoachStep(name: $draft.coachName,
                            emoji: $draft.coachEmoji,
                            tone: $draft.tone)
        case 7:
            WizardRemindersStep(am: $draft.am, pm: $draft.pm)
        default:
            WizardSummaryStep(rows: draft.summaryRows)
        }
    }

    // MARK: - Footer

    /// `padding:0 20px 34px` — the 34pt is the home indicator, which the safe area supplies.
    private var footer: some View {
        Button(action: next) {
            Text(draft.ctaLabel)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(FTColor.blue)
                )
                // box-shadow: 0 4px 14px rgba(10,132,255,0.35) — CSS blur 14 -> sigma 7.
                .shadow(color: .ftRGBA(10, 132, 255, 0.35), radius: 7, x: 0, y: 4)
        }
        .buttonStyle(FTPressableStyle(scale: 0.98))
        .padding(.horizontal, FTSpacing.gutter)
    }

    // MARK: - Navigation

    /// `wizBack` — step 0 cancels the whole wizard and discards the draft.
    private func back() {
        guard draft.step > 0 else {
            dismiss()
            return
        }
        draft.step -= 1
    }

    /// `wizNext` — also the Skip control, which is the same handler in the prototype.
    private func next() {
        guard draft.step < WizardDraft.lastStep else {
            finish()
            return
        }
        draft.step += 1
    }

    /// `finishWizard()` — the draft becomes the whole ledger, then the wizard closes.
    /// A draft nobody touched yields `AppData.empty(currency:)`: valid, and empty everywhere.
    private func finish() {
        let newData = draft.makeAppData()
        store.replaceAll(newData)
        // Step 7 had the user set reminder times, so this is a legitimate moment to ask —
        // the same contract SettingsView.syncReminders() follows. Without this the pending
        // requests keep the pre-reset times and the old coach name forever.
        let reminders = newData.reminders
        let coach = newData.coach
        Task { await NotificationScheduler.enableAndSchedule(reminders: reminders, coach: coach) }
        dismiss()
    }

    private func dismiss() {
        // RootView fades the wizard out (`animation:fadeIn 200ms ease`).
        withAnimation(FTMotion.resolved(.easeInOut(duration: 0.2), reduceMotion: reduceMotion)) {
            ui.closeWizard()
        }
    }
}

// MARK: - Preview

#Preview("Onboarding wizard") {
    OnboardingWizardView()
        .environment(AppStore())
        .environment(UIState())
        .theme(dark: false)
}
