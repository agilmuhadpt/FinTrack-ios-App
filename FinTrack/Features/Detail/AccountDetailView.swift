//
//  AccountDetailView.swift
//  FinTrack — Account detail (full-screen overlay, z-index 40).
//
//  Ported from the prototype: markup FinTrack.dc.html lines 228-240 + 285-306,
//  logic lines 1059-1068. CSS px map 1:1 to points. The 58px top padding in the
//  prototype is the mock frame's status bar and is left to the real safe area.
//

import SwiftUI

struct AccountDetailView: View {

    let index: Int

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `animation:fadeIn 200ms ease` on the overlay container.
    @State private var appeared = false

    /// Index-safe lookup, mirroring the prototype's `if (a)` guard.
    private var account: Account? {
        store.data.accounts.indices.contains(index) ? store.data.accounts[index] : nil
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            if let a = account {
                VStack(spacing: 0) {
                    AcctDetailBackRow { ui.closeDetail() }
                    scrollBody(a)
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
    private func scrollBody(_ a: Account) -> some View {
        let txs = store.transactions(forAccount: a.name)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // h1 — margin:4px 0 2px; 28/800, letter-spacing -0.02em.
                Text(a.name)
                    .ftDetailTitleStyle()
                    .foregroundStyle(theme.text)
                    .padding(.top, 4)

                Text("Account")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.sub)
                    .padding(.top, 2)

                balanceCard(a)
                    .padding(.top, 16)

                // h2 — margin:22px 0 10px.
                Text("Transactions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.text)
                    .padding(.top, 22)
                    .padding(.bottom, 10)

                if txs.isEmpty {
                    emptyCard
                } else {
                    transactionsCard(txs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.horizontal, FTSpacing.gutter)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Balance card

    private func balanceCard(_ a: Account) -> some View {
        FTCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Balance")
                    .ftLabel13Style()
                    .foregroundStyle(theme.sub)

                // 34/800, letter-spacing -0.02em (= -0.68 at 34pt), tabular.
                Text(store.fmt(a.bal))
                    .ftTextStyle(.system(size: 34, weight: .heavy).monospacedDigit(), tracking: -0.68)
                    .ftTabular()
                    .foregroundStyle(theme.text)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    // MARK: - Transactions

    /// One card, `padding:13px 16px` rows, 0.5pt hairlines between rows only.
    /// These rows are deliberately NOT swipe-deletable — only the Activity tab deletes.
    private func transactionsCard(_ txs: [Transaction]) -> some View {
        FTCard {
            VStack(spacing: 0) {
                ForEach(Array(txs.enumerated()), id: \.element.id) { pair in
                    if pair.offset > 0 {
                        Rectangle()
                            .fill(theme.sep)
                            .frame(height: 0.5)
                    }
                    row(pair.element)
                }
            }
        }
    }

    private func row(_ tx: Transaction) -> some View {
        HStack(spacing: 12) {
            FTIconTile(glyph: tx.glyph,
                       color: Color(hex: tx.colorHex),
                       tint: Color(hex: tx.tintHex),
                       size: 36)

            VStack(alignment: .leading, spacing: 0) {
                Text(tx.title)
                    .ftBodyStyle()
                    .foregroundStyle(theme.text)
                Text(tx.sub)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // `it.pos ? '#30D158' : (dark ? '#FFFFFF' : '#1C1C1E')` — i.e. the primary label.
            Text(tx.amount)
                .ftAmountStyle()
                .foregroundStyle(tx.pos ? FTColor.green : theme.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
    }

    /// `padding:28px 20px; text-align:center; 14px/500 secondary`.
    private var emptyCard: some View {
        FTCard {
            Text("No transactions on this account yet.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.sub)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - Shared chrome (duplicated per file on purpose: the Detail folder is edited in parallel)

/// The detail-overlay Back row: `padding:10px 12px 8px`, a 20pt chevron at stroke-width 2.5
/// plus "Back" in #0A84FF 16/600, 6pt/8pt around the hit area, 0.95 press scale.
private struct AcctDetailBackRow: View {

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
