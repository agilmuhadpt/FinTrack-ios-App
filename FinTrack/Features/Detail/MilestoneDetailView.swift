//
//  MilestoneDetailView.swift
//  FinTrack — Milestone detail (full-screen overlay, z-index 40).
//
//  Ported from the prototype: markup FinTrack.dc.html lines 228-283, logic lines 1040-1057.
//  Every number below is the CSS px value read 1:1 as a SwiftUI point. The 58px top padding
//  the prototype hardcodes is the mock device frame's status bar — on real iOS the safe area
//  supplies it, so only the element's own padding is reproduced here.
//

import SwiftUI

struct MilestoneDetailView: View {

    let index: Int

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The "Add money" field. Local and ephemeral — the prototype keeps it in a DOM ref.
    @State private var amountText = ""
    @FocusState private var amountFocused: Bool

    /// `animation:fadeIn 200ms ease` on the overlay container.
    @State private var appeared = false

    /// Index-safe lookup. `DetailHostView` already range-checks, but the overlay can outlive
    /// a mutation by one render pass, and the prototype's `if (m)` guard is equally tolerant.
    private var milestone: Milestone? {
        store.data.msPersonal.indices.contains(index) ? store.data.msPersonal[index] : nil
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            if let m = milestone {
                VStack(spacing: 0) {
                    MsDetailBackRow { ui.closeDetail() }
                    scrollBody(m)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            guard !appeared else { return }
            // CSS `ease` = cubic-bezier(0.25, 0.1, 0.25, 1).
            withAnimation(FTMotion.resolved(.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2),
                                            reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
    }

    // MARK: - Body

    /// `padding:4px 20px 40px` on the scrolling container.
    private func scrollBody(_ m: Milestone) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // h1 — margin:4px 0 2px; 28/800, letter-spacing -0.02em.
                Text(m.name)
                    .ftDetailTitleStyle()
                    .foregroundStyle(theme.text)
                    .padding(.top, 4)

                // Sub-line — 14px, secondary, regular weight.
                Text("Milestone")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.sub)
                    .padding(.top, 2)

                progressCard(m)
                    .padding(.top, 16)

                // h2 — margin:22px 0 10px.
                Text("Add money")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.text)
                    .padding(.top, 22)
                    .padding(.bottom, 10)

                addMoneyRow()

                Text("Deposits come from your first account and count toward Savings.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.horizontal, FTSpacing.gutter)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Progress card

    private func progressCard(_ m: Milestone) -> some View {
        FTCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    // 34/800, letter-spacing -0.02em (= -0.68 at 34pt), tabular.
                    Text("\(m.pct)%")
                        .ftTextStyle(.system(size: 34, weight: .heavy).monospacedDigit(), tracking: -0.68)
                        .ftTabular()
                        .foregroundStyle(theme.text)

                    Spacer(minLength: 8)

                    Text(store.fmt(m.saved) + " of " + store.fmtN(m.target))
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .ftTabular()
                        .foregroundStyle(theme.sub)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                // height:10px; track var(--chip); fill the milestone colour; width 250ms morph.
                FTProgressBar(progress: Double(m.pct) / 100,
                              height: 10,
                              color: Color(hex: m.colorHex))
                    .padding(.top, 12)
            }
            .padding(20)
        }
    }

    // MARK: - Add money

    private func addMoneyRow() -> some View {
        HStack(spacing: 10) {
            TextField("", text: $amountText,
                      prompt: Text("Amount").foregroundStyle(theme.sub))
                .font(.system(size: 16))
                .foregroundStyle(theme.text)
                .tint(FTColor.blue)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .textFieldStyle(.plain)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.card))
                .ftCardShadow(theme)

            Button {
                submitAmount()
            } label: {
                Text("Add")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(FTColor.blue))
            }
            .buttonStyle(FTPressableStyle(scale: 0.96))
        }
    }

    /// `if (!amt || amt <= 0) return;` — anything unparseable or non-positive is a no-op,
    /// and the field is only cleared once the deposit has been booked.
    private func submitAmount() {
        guard let amount = MsDetailParse.amount(amountText), amount > 0 else { return }
        store.addToMilestone(index: index, amount: amount)
        amountText = ""
        amountFocused = false
    }
}

// MARK: - Shared chrome (duplicated per file on purpose: the Detail folder is edited in parallel)

/// The detail-overlay Back row: `padding:10px 12px 8px`, a 20pt chevron at stroke-width 2.5
/// plus "Back" in #0A84FF 16/600, 6pt/8pt around the hit area, 0.95 press scale.
private struct MsDetailBackRow: View {

    let action: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: action) {
                HStack(spacing: 2) {
                    FTIcon(.chevronLeft, size: 20, color: FTColor.blue, lineWidth: 2.5)
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FTColor.blue)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(FTPressableStyle(scale: 0.95))

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

private enum MsDetailParse {
    /// `parseFloat(el.value)`, via the shared locale-aware parser so a grouped amount is
    /// never misread as a fraction.
    static func amount(_ raw: String) -> Double? {
        FinTrackFormatting.amount(from: raw)
    }
}
