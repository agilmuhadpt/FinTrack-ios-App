//
//  LoansView.swift
//  FinTrack — Loans (tab 4).
//
//  Transcribed from the prototype, FinTrack.dc.html lines 142-172 (markup) and 923/955-956
//  (logic). CSS px map 1:1 to points. The prototype's `padding:58px 20px 120px` is the mock
//  frame's status-bar inset plus the gutters: on device the top safe area supplies the 58,
//  so only the 20pt gutters and the 120pt bottom inset (clearing the floating tab bar) are
//  reproduced here.
//
//  Amounts are `fmtN` — bare numbers, no currency prefix — exactly as the prototype renders
//  both the summary cards and the loan rows.
//

import SwiftUI

struct LoansView: View {

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `font-size:22px;font-weight:800;font-variant-numeric:tabular-nums`, ls -0.02em → -0.44pt.
    /// Local to this screen: the shared type scale has no 22pt step.
    private static let summaryAmount = Font.system(size: 22, weight: .heavy).monospacedDigit()

    /// `font-size:16px;font-weight:700;font-variant-numeric:tabular-nums` — the loan row amount.
    private static let rowAmount = Font.system(size: 16, weight: .bold).monospacedDigit()

    /// `font-size:13px` with the body's inherited weight (400).
    private static let rowSub = Font.system(size: 13, weight: .regular)

    /// `font-size:14px;font-weight:500` — the empty state.
    private static let emptyText = Font.system(size: 14, weight: .medium)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // <h1 style="margin:16px 0 4px;font-size:34px;font-weight:800;letter-spacing:-0.02em">
                // The 4px bottom margin collapses into the summary row's 12px top margin.
                Text("Loans")
                    .ftTitleStyle()
                    .foregroundStyle(theme.text)
                    .padding(.top, 16)

                // <div style="display:flex;gap:10px;margin-top:12px">
                summaryRow
                    .padding(.top, 12)

                // <div style="display:flex;flex-direction:column;gap:10px;margin-top:16px">
                loanList
                    .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FTSpacing.gutter)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Summary

    private var summaryRow: some View {
        HStack(spacing: FTSpacing.cardGap) {
            summaryCard(caption: "Owed to you",
                        amount: store.fmtN(store.owedToYou),
                        color: FTColor.green)
            summaryCard(caption: "You owe",
                        amount: store.fmtN(store.youOwe),
                        color: FTColor.red)
        }
    }

    /// `flex:1` card, radius 20, `padding:16px`.
    private func summaryCard(caption: String, amount: String, color: Color) -> some View {
        FTCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(caption)
                    .ftLabel12Style()
                    .foregroundStyle(theme.sub)
                    .lineLimit(1)

                Text(amount)
                    .ftTextStyle(Self.summaryAmount, tracking: -0.44)
                    .foregroundStyle(color)
                    // The two cards are locked to equal widths, so a long total shrinks
                    // rather than truncating or pushing its neighbour narrower.
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Loan list

    @ViewBuilder
    private var loanList: some View {
        VStack(spacing: FTSpacing.cardGap) {
            if store.data.loans.isEmpty {
                emptyState
            } else {
                ForEach(Array(store.data.loans.enumerated()), id: \.element.id) { index, loan in
                    loanCard(loan, index: index)
                }
            }
        }
    }

    /// `padding:16px 20px`, tapping opens the shared detail overlay (`view: { t: 'loan', i }`).
    private func loanCard(_ loan: Loan, index: Int) -> some View {
        Button {
            ui.openDetail(.loan(index))
        } label: {
            FTCard {
                VStack(alignment: .leading, spacing: 0) {
                    // display:flex;justify-content:space-between;align-items:baseline
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(loan.name)
                            .ftBody16Style()
                            .foregroundStyle(theme.text)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        Text(store.fmtN(loan.amt))
                            .font(Self.rowAmount)
                            .foregroundStyle(loan.dir == .inbound ? FTColor.green : FTColor.red)
                            .lineLimit(1)
                    }

                    Text(loan.sub)
                        .font(Self.rowSub)
                        .foregroundStyle(theme.sub)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(FTPressableStyle(scale: 0.985))
        // animation:cardIn 300ms cubic-bezier(0.23,1,0.32,1); animation-delay: i * 40ms
        .ftEntrance(delay: Double(index) * 0.04, reduceMotion: reduceMotion)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// `padding:32px 20px;text-align:center;color:var(--sub);font-size:14px;font-weight:500`
    private var emptyState: some View {
        FTCard {
            Text("No loans tracked yet.")
                .font(Self.emptyText)
                .foregroundStyle(theme.sub)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
        }
    }
}
