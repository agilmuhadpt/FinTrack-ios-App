//
//  ActivityView.swift
//  FinTrack — Activity (tab 2).
//
//  Ported from the prototype (FinTrack.dc.html) lines 117-141.
//
//  Vertical rhythm: the markup's adjacent CSS margins collapse — the h1's 4pt bottom
//  margin against a 20pt top margin resolves to 20pt — so every block after the title
//  carries 20pt of top padding and the title itself keeps only its own 16pt.
//  The prototype's `padding:58px 20px 120px` is a fake status bar plus gutters plus a
//  tab-bar inset: on device the safe area supplies the 58, so only 20/120 survive.
//

import SwiftUI

struct ActivityView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text("Activity")
                    .ftTitleStyle()
                    .foregroundStyle(theme.text)
                    .padding(.top, 16)

                if store.data.days.isEmpty {
                    emptyState
                        .padding(.top, 20)
                } else {
                    ForEach(store.data.days) { day in
                        dayGroup(day)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FTSpacing.gutter)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        FTCard {
            Text("No transactions yet — tap + to add your first one.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.sub)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Day group

    @ViewBuilder
    private func dayGroup(_ day: DayGroup) -> some View {
        Text(day.label.uppercased())
            .ftTextStyle(.ftLabel13, tracking: 0.26)
            .foregroundStyle(theme.sub)
            .padding(.top, 20)
            .padding(.bottom, 8)

        FTCard {
            VStack(spacing: 0) {
                ForEach(Array(day.items.enumerated()), id: \.element.id) { index, tx in
                    ActivityRow(tx: tx,
                                showsSeparator: index < day.items.count - 1,
                                onDelete: delete)
                }
            }
        }
    }

    // MARK: - Delete

    /// Resolves the row's position at gesture-end time. Indices shift as soon as any row
    /// goes, so the id — never a captured index — is the key.
    private func delete(_ id: UUID) {
        for (dayIndex, day) in store.data.days.enumerated() {
            if let itemIndex = day.items.firstIndex(where: { $0.id == id }) {
                store.deleteTransaction(dayIndex: dayIndex, itemIndex: itemIndex)
                return
            }
        }
    }
}
