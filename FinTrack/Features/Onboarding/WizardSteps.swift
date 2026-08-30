//
//  WizardSteps.swift
//  FinTrack — Onboarding wizard: the nine step bodies.
//
//  Each step owns the transient text it is typing. That is deliberate: the prototype keeps
//  those values in DOM refs which unmount when the step changes, so a half-typed row is
//  discarded on Continue / Skip / Back. Values that survive a step change (currency, the
//  added lists, the coach and the reminder times) live in `WizardDraft` instead.
//
//  Every step begins 20pt below the subtitle — `margin-top:20px` — except the welcome
//  hero, which sits 56pt below it.
//

import SwiftUI

// MARK: - 0. Welcome

struct WizardWelcomeStep: View {

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            // 88x88, radius 22, linear-gradient(135deg,#0A84FF,#5E5CE6),
            // box-shadow 0 8px 24px rgba(10,132,255,0.35) — CSS blur 24 -> sigma 12.
            Text("\u{1F4B3}")
                .font(.system(size: 48))
                .frame(width: 88, height: 88)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(FTColor.brandGradient)
                )
                .shadow(color: .ftRGBA(10, 132, 255, 0.35), radius: 12, x: 0, y: 8)

            // 15px, line-height 1.5 -> 22.5pt; SF Pro Text 15pt already stacks at ~17.9pt.
            Text("Track accounts, income, loans and milestones \u{2014} with a coach in your corner. About 2 minutes to set up.")
                .font(.system(size: 15))
                .foregroundStyle(theme.sub)
                .multilineTextAlignment(.center)
                .lineSpacing(ftLineSpacing(size: 15, lineHeight: 1.45))
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
    }
}

// MARK: - 1. Currency

struct WizardCurrencyStep: View {

    @Binding var currency: String

    @Environment(\.theme) private var theme

    var body: some View {
        WizardGroupCard {
            ForEach(AppData.currencyOptions, id: \.self) { option in
                Button {
                    currency = option
                } label: {
                    HStack(spacing: 0) {
                        Text(option)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Spacer(minLength: 12)
                        // U+2713 CHECK MARK, blue when picked and transparent otherwise —
                        // the row height must not change with the selection.
                        Text("\u{2713}")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(currency == option ? FTColor.blue : Color.clear)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(WizardRowPressStyle())
                .accessibilityAddTraits(currency == option ? [.isButton, .isSelected] : .isButton)

                WizardRowSeparator()
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - 2. Bank accounts

struct WizardAccountsStep: View {

    @Binding var accounts: [Account]
    let currency: String

    @State private var name = ""
    @State private var balance = ""

    var body: some View {
        VStack(spacing: 10) {
            WizardField("Account name (e.g. Northbank)", text: $name)
            WizardField("Current balance", text: $balance, keyboard: .decimalPad)
            WizardAddButton(title: "+ Add account", action: add)

            ForEach(accounts) { account in
                WizardItemRow(name: account.name,
                              value: FinTrackFormatting.amount(account.bal, currency)) {
                    accounts.removeAll { $0.id == account.id }
                }
            }
        }
        .padding(.top, 20)
    }

    /// `addAccount` — a blank name is ignored, a blank balance reads as 0, both clear.
    private func add() {
        let trimmed = WizardDraft.string(name)
        guard !trimmed.isEmpty else { return }
        accounts.append(Account(name: trimmed, bal: WizardDraft.number(balance)))
        name = ""
        balance = ""
    }
}

// MARK: - 3. Income sources

struct WizardIncomeStep: View {

    @Binding var incomes: [Income]
    @Binding var type: IncomeType
    let currency: String

    @State private var name = ""
    @State private var amount = ""

    private var typeIndex: Binding<Int> {
        Binding(get: { type == .personal ? 0 : 1 },
                set: { type = $0 == 0 ? .personal : .business })
    }

    var body: some View {
        VStack(spacing: 10) {
            WizardField("Source (e.g. Salary)", text: $name)
            WizardField("Amount per month", text: $amount, keyboard: .decimalPad)
            FTSegmentedControl(labels: ["Personal", "Business"],
                               selection: typeIndex,
                               style: .filled, metrics: .wizard)
            WizardAddButton(title: "+ Add income", action: add)

            ForEach(incomes) { income in
                WizardItemRow(name: income.name,
                              kind: income.type.rawValue,
                              value: FinTrackFormatting.amount(income.amt, currency) + "/mo") {
                    incomes.removeAll { $0.id == income.id }
                }
            }
        }
        .padding(.top, 20)
    }

    private func add() {
        let trimmed = WizardDraft.string(name)
        guard !trimmed.isEmpty else { return }
        incomes.append(Income(name: trimmed, amt: WizardDraft.number(amount), type: type))
        name = ""
        amount = ""
    }
}

// MARK: - 4. Loans

struct WizardLoansStep: View {

    @Binding var loans: [Loan]
    @Binding var direction: LoanDirection
    let currency: String

    @State private var name = ""
    @State private var amount = ""

    private var directionIndex: Binding<Int> {
        Binding(get: { direction == .inbound ? 0 : 1 },
                set: { direction = $0 == 0 ? .inbound : .outbound })
    }

    /// `a.dir === 'in' ? 'They owe me' : 'I owe them'`
    private func label(_ dir: LoanDirection) -> String {
        dir == .inbound ? "They owe me" : "I owe them"
    }

    var body: some View {
        VStack(spacing: 10) {
            WizardField("Person or lender", text: $name)
            WizardField("Amount", text: $amount, keyboard: .decimalPad)
            FTSegmentedControl(labels: ["They owe me", "I owe them"],
                               selection: directionIndex,
                               style: .filled, metrics: .wizard)
            WizardAddButton(title: "+ Add loan", action: add)

            ForEach(loans) { loan in
                WizardItemRow(name: loan.name,
                              kind: label(loan.dir),
                              value: FinTrackFormatting.amount(loan.amt, currency),
                              valueColor: loan.dir == .inbound ? FTColor.green : FTColor.red) {
                    loans.removeAll { $0.id == loan.id }
                }
            }
        }
        .padding(.top, 20)
    }

    /// The `sub` line is rewritten to "Owed to you" / "You owe" by `AppData.fromWizard`.
    private func add() {
        let trimmed = WizardDraft.string(name)
        guard !trimmed.isEmpty else { return }
        loans.append(Loan(name: trimmed, amt: WizardDraft.number(amount), dir: direction, sub: ""))
        name = ""
        amount = ""
    }
}

// MARK: - 5. Milestones

struct WizardMilestonesStep: View {

    @Binding var milestones: [Milestone]
    let currency: String

    @State private var name = ""
    @State private var target = ""

    var body: some View {
        VStack(spacing: 10) {
            WizardField("Milestone (e.g. Emergency fund)", text: $name)
            WizardField("Target amount", text: $target, keyboard: .decimalPad)
            WizardAddButton(title: "+ Add milestone", action: add)

            ForEach(milestones) { milestone in
                WizardItemRow(name: milestone.name,
                              value: FinTrackFormatting.amount(milestone.target, currency)) {
                    milestones.removeAll { $0.id == milestone.id }
                }
            }
        }
        .padding(.top, 20)
    }

    /// `saved` starts at 0 and the colour is reassigned by index in `AppData.fromWizard`;
    /// the palette lookup here only keeps the draft self-consistent.
    private func add() {
        let trimmed = WizardDraft.string(name)
        guard !trimmed.isEmpty else { return }
        let palette = AppData.milestonePalette
        milestones.append(Milestone(name: trimmed,
                                    saved: 0,
                                    target: WizardDraft.number(target),
                                    colorHex: palette[milestones.count % palette.count]))
        name = ""
        target = ""
    }
}

// MARK: - 6. Your coach

struct WizardCoachStep: View {

    @Binding var name: String
    @Binding var emoji: String
    @Binding var tone: CoachTone

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var toneIndex: Binding<Int> {
        Binding(get: { tone == .playful ? 0 : 1 },
                set: { tone = $0 == 0 ? .playful : .serious })
    }

    var body: some View {
        VStack(spacing: 14) {
            WizardField("Coach name (e.g. Leo)", text: $name)

            HStack(spacing: 8) {
                ForEach(Coach.emojiOptions, id: \.self) { option in
                    Button {
                        emoji = option
                    } label: {
                        Text(option)
                            .font(.system(size: 24))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            // `border:2px solid` sits inside the 14pt outer radius.
                            .padding(2)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(theme.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(emoji == option ? FTColor.blue : Color.clear,
                                                  lineWidth: 2)
                            )
                            .ftCardShadow(theme)
                    }
                    .buttonStyle(FTPressableStyle(scale: 0.92))
                    .accessibilityLabel("Coach emoji " + option)
                    .accessibilityAddTraits(emoji == option ? [.isButton, .isSelected] : .isButton)
                }
            }
            // `border-color 200ms ease`
            .animation(FTMotion.resolved(.easeInOut(duration: 0.2), reduceMotion: reduceMotion),
                       value: emoji)

            FTSegmentedControl(labels: ["Playful", "Serious"],
                               selection: toneIndex,
                               style: .filled, metrics: .wizard)
        }
        .padding(.top, 20)
    }
}

// MARK: - 7. Reminders

struct WizardRemindersStep: View {

    @Binding var am: Date
    @Binding var pm: Date

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            row("Morning check-in", $am)
            row("Evening review", $pm)
        }
        .padding(.top, 20)
    }

    private func row(_ title: String, _ value: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)

            DatePicker("", selection: value, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(FTColor.blue)
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.card))
        .ftCardShadow(theme)
    }
}

// MARK: - 8. Summary

struct WizardSummaryStep: View {

    let rows: [WizardSummaryRow]

    @Environment(\.theme) private var theme

    var body: some View {
        WizardGroupCard {
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    Text(row.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 12)

                    Text(row.value)
                        .font(.system(size: 15, weight: .bold))
                        .ftTabular()
                        .foregroundStyle(theme.sub)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                WizardRowSeparator()
            }
        }
        .padding(.top, 20)
    }
}
