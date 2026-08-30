//
//  HomeView.swift
//  FinTrack — Home (tab 1), "Overview".
//
//  Transcribed from FinTrack.dc.html L29-116 (markup, inline CSS = exact px) and the
//  `renderVals()` block, L904-953 (chips / budget / milestones derivations).
//
//  Two deliberate departures from the prototype markup, both required by real iOS:
//    • The body's `padding:58px 20px 120px` was drawn inside a mock device frame — the 58px
//      is that frame's status bar. Here the top safe area supplies it and only the header's
//      own `padding:16px 0 4px` is applied. The 20pt gutters and the 120pt bottom inset
//      (so the last card clears the floating tab bar) are kept verbatim.
//    • The date label is hard-coded "Saturday, Aug 30" in the prototype; here it is the real
//      date, formatted with a fixed en_US_POSIX locale so it always reads the same way.
//

import SwiftUI

struct HomeView: View {

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Read in the body so Observation registers the dependency for every child below.
        let personal = store.mode == .personal
        let modeSelection = Binding<Int>(
            get: { store.mode == .personal ? 0 : 1 },
            set: { store.setMode($0 == 0 ? .personal : .business) }
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // padding:16px 0 4px
                header
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                // margin-top:14px
                FTSegmentedControl(labels: ["Personal", "Studio"],
                                   selection: modeSelection,
                                   style: .pill)
                    .padding(.top, 14)

                // margin-top:14px
                balanceCard(personal: personal)
                    .padding(.top, 14)

                // margin-top:20px — "<Month> budget" + the rule label, baseline aligned.
                FTSectionHeader(HomeDate.monthName + " budget", trailing: store.budgetRuleLabel)
                    .padding(.top, 20)

                // margin-top:10px
                budgetCard
                    .padding(.top, 10)

                // margin:24px 0 10px
                FTSectionHeader("Milestones")
                    .padding(.top, 24)
                    .padding(.bottom, 10)

                milestones(personal: personal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FTSpacing.gutter)
            .padding(.bottom, 120)
        }
    }

    // MARK: - 1. Header

    private var header: some View {
        // display:flex; align-items:flex-end; justify-content:space-between
        HStack(alignment: .bottom, spacing: 0) {
            // display:flex; align-items:center; gap:12px
            HStack(alignment: .center, spacing: 12) {
                appIcon
                VStack(alignment: .leading, spacing: 0) {
                    Text(HomeDate.headerLabel)
                        .ftUppercaseLabelStyle()
                        .foregroundStyle(theme.sub)
                        .lineLimit(1)
                    Text("Overview")
                        .ftTitleStyle()
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .padding(.top, 2)           // margin:2px 0 0
                }
            }
            Spacer(minLength: 12)
            // gap:8px
            HStack(spacing: 8) {
                circleButton(.restore, size: 18) { ui.askReset() }
                circleButton(store.dark ? .sun : .moon, size: 19) { store.toggleTheme() }
                circleButton(.gear, size: 19) { ui.openSettings() }
            }
        }
    }

    /// 44x44, radius 11, `linear-gradient(135deg,#0A84FF,#5E5CE6)`, 24px 💳,
    /// `box-shadow:0 2px 6px rgba(10,132,255,0.35)` (CSS blur 6 -> sigma 3).
    private var appIcon: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(FTColor.brandGradient)
            .frame(width: 44, height: 44)
            .overlay(Text("\u{1F4B3}").font(.system(size: 24)))
            .shadow(color: .ftRGBA(10, 132, 255, 0.35), radius: 3, x: 0, y: 2)
    }

    /// 38x38 circular card button with the standard card shadow; press scale 0.9.
    private func circleButton(_ kind: FTIcon.Kind,
                              size: CGFloat,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            FTIcon(kind, size: size, color: theme.text)
                .frame(width: 38, height: 38)
                .background(Circle().fill(theme.card))
                .ftCardShadow(theme)
                .contentShape(Circle())
        }
        .buttonStyle(FTPressableStyle(scale: 0.9))
    }

    // MARK: - 3. Balance card

    private func balanceCard(personal: Bool) -> some View {
        FTCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.balanceLabel)
                    .ftLabel13Style()
                    .foregroundStyle(theme.sub)

                Text(store.fmt(store.displayBalance))
                    .ftBalanceStyle()
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 4)               // margin-top:4px

                // display:flex;gap:8px;margin-top:14px;flex-wrap:wrap
                HomeFlowLayout(spacing: 8, lineSpacing: 8) {
                    chips(personal: personal)
                }
                .padding(.top, 14)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func chips(personal: Bool) -> some View {
        if personal {
            if store.data.accounts.isEmpty {
                FTChip("No accounts yet")
            } else {
                ForEach(Array(store.data.accounts.enumerated()), id: \.element.id) { index, account in
                    Button {
                        ui.openDetail(.account(index))
                    } label: {
                        // "<name> · <fmtN(bal)>" — the separator is U+00B7.
                        FTChip(account.name + " \u{00B7} " + store.fmtN(account.bal))
                    }
                    .buttonStyle(FTPressableStyle(scale: 0.95))
                }
            }
        } else {
            let business = store.data.incomes.filter { $0.type == .business }
            if business.isEmpty {
                FTChip("No business income yet")
            } else {
                // Business chips are display-only in the prototype (`open: () => {}`).
                ForEach(business) { income in
                    FTChip(income.name + " \u{00B7} " + store.fmtN(income.amt))
                }
            }
        }
    }

    // MARK: - 4. Budget card

    private var budgetCard: some View {
        let segments = store.budgetSegments
        return FTCard {
            VStack(alignment: .leading, spacing: 0) {
                FTTriColorBar(segments[0].pct, segments[1].pct, segments[2].pct,
                              colors: segments.map { Color(hex: $0.colorHex) },
                              height: 10,
                              spacing: 2)

                // display:flex;justify-content:space-between;margin-top:14px
                HStack(spacing: 8) {
                    budgetColumn(segments[0])
                    Spacer(minLength: 4)
                    budgetColumn(segments[1])
                    Spacer(minLength: 4)
                    budgetColumn(segments[2])
                }
                .padding(.top, 14)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)               // padding:18px 20px
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func budgetColumn(_ segment: (name: String, pct: Int, colorHex: String)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(segment.name)
                .ftLabel12Style()
                .foregroundStyle(Color(hex: segment.colorHex))
                .lineLimit(1)
            Text("\(segment.pct)%")
                .font(.system(size: 17, weight: .bold))
                .ftTabular()
                .foregroundStyle(theme.text)
                .lineLimit(1)
        }
    }

    // MARK: - 5. Milestones

    @ViewBuilder
    private func milestones(personal: Bool) -> some View {
        let list = store.milestones
        VStack(alignment: .leading, spacing: FTSpacing.cardGap) {   // gap:10px
            if list.isEmpty {
                emptyMilestones
            } else {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, milestone in
                    milestoneCard(milestone, index: index, tappable: personal)
                        // animation-delay: (i * 50) + 'ms'
                        .ftEntrance(delay: Double(index) * 0.05, reduceMotion: reduceMotion)
                }
            }
        }
    }

    @ViewBuilder
    private func milestoneCard(_ milestone: Milestone, index: Int, tappable: Bool) -> some View {
        if tappable {
            Button {
                ui.openDetail(.milestone(index))
            } label: {
                milestoneCardBody(milestone)
            }
            .buttonStyle(FTPressableStyle(scale: 0.985))
        } else {
            // Business milestones carry `open: () => {}` — no tap target at all.
            milestoneCardBody(milestone)
        }
    }

    private func milestoneCardBody(_ milestone: Milestone) -> some View {
        FTCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {   // margin-left:8px on the pct
                    Text(milestone.name)
                        .ftBody16Style()
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(milestone.pct)%")
                        .font(.system(size: 13, weight: .bold))
                        .ftTabular()
                        .foregroundStyle(theme.sub)
                        .lineLimit(1)
                        .layoutPriority(1)                            // flex-shrink:0
                }

                Text(store.fmt(milestone.saved) + " of " + store.fmtN(milestone.target))
                    .font(.system(size: 13))
                    .ftTabular()
                    .foregroundStyle(theme.sub)
                    .lineLimit(1)
                    .padding(.top, 2)                                 // margin-top:2px

                FTProgressBar(progress: Double(milestone.pct) / 100,
                              height: 6,
                              color: Color(hex: milestone.colorHex))
                    .padding(.top, 10)                                // margin-top:10px
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)                                 // padding:16px 20px
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyMilestones: some View {
        FTCard {
            // The dash is an em dash, U+2014.
            Text("No milestones yet \u{2014} add one from the + tab.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.sub)
                .multilineTextAlignment(.center)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)                             // padding:24px 20px
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Date labels

/// The prototype hard-codes "Saturday, Aug 30" and "August budget". Both are derived here,
/// against a fixed en_US_POSIX locale so the wording never shifts with the device locale.
private enum HomeDate {

    private static let header: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let month: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "LLLL"
        return f
    }()

    /// e.g. "Saturday, Aug 30" — uppercased by `.ftUppercaseLabelStyle()`.
    static var headerLabel: String { header.string(from: Date()) }

    /// e.g. "August".
    static var monthName: String { month.string(from: Date()) }
}

// MARK: - Wrapping chip row

/// `display:flex;gap:8px;flex-wrap:wrap` — chips keep their intrinsic width (they never
/// wrap their own text) and spill onto a new line when the row is full.
private struct HomeFlowLayout: Layout {

    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var out: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if current.indices.isEmpty {
                current.indices = [index]
                current.width = size.width
                current.height = size.height
                continue
            }
            let extended = current.width + spacing + size.width
            if extended > maxWidth {
                out.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = extended
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { out.append(current) }
        return out
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let laid = rows(subviews, maxWidth: maxWidth)
        let height = laid.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, laid.count - 1))
        let width = proposal.width ?? (laid.map(\.width).max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        let laid = rows(subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in laid {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      anchor: .topLeading,
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }
}
