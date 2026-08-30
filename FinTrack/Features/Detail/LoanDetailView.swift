//
//  LoanDetailView.swift
//  FinTrack — Screen 5: Loan detail.
//
//  Ported from FinTrack.dc.html: the shared detail chrome (L230-239) plus the
//  `isLoanDetail` branch (L240-265), driven by the `view.t === 'loan'` case of
//  renderVals() (L1018-1036). The six-month repayment maths already lives in
//  `AppStore.loanRoadmap(amount:)`, so this file only lays it out.
//
//  The prototype's `padding-top:58px` is the mock device frame's status bar — on
//  real iOS the top safe area supplies it, so only the element's own padding is
//  transcribed here.
//

import SwiftUI

struct LoanDetailView: View {

    let index: Int

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `animation:fadeIn 200ms ease` — CSS `ease` is cubic-bezier(0.25, 0.1, 0.25, 1).
    private static let fadeIn: Animation = .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2)

    @State private var appeared = false

    private var loan: Loan { store.data.loans[index] }
    private var roadmap: [RoadmapEntry] { store.roadmap(for: loan) }

    /// `l.dir === 'in' ? '#30D158' : '#FF453A'`
    private var accent: Color { loan.dir == .inbound ? FTColor.green : FTColor.red }

    var body: some View {
        ZStack {
            theme.bg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                backRow
                scrollBody
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(FTMotion.resolved(Self.fadeIn, reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
    }

    // MARK: - Back row

    /// `padding:10px 12px 8px` around a blue 16px/600 chevron + "Back" button
    /// whose own padding is `6px 8px`, so the label lands on the 20pt gutter.
    private var backRow: some View {
        HStack(spacing: 4) {
            Button {
                ui.closeDetail()
            } label: {
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

    // MARK: - Body

    /// `flex:1; overflow-y:auto; padding:4px 20px 40px`
    private var scrollBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                outstandingCard
                    .padding(.top, 16)

                Text("Repayment roadmap")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.text)
                    .padding(.top, 22)
                    .padding(.bottom, 10)

                chartCard
                listCard
                    .padding(.top, 12)

                Text(roadmapNote)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.sub)
                    .lineSpacing(ftLineSpacing(size: 13, lineHeight: 1.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.horizontal, FTSpacing.gutter)
            .padding(.bottom, 40)
        }
    }

    /// `<h1 style="margin:4px 0 2px">` + the 14px direction line.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(loan.name)
                .ftDetailTitleStyle()
                .foregroundStyle(theme.text)
                .padding(.top, 4)
                .padding(.bottom, 2)

            Text(loan.dir == .inbound ? "They owe you" : "You owe them")
                .font(.system(size: 14))
                .foregroundStyle(theme.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Outstanding card

    private var outstandingCard: some View {
        FTCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Outstanding")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.sub)

                Text(store.fmt(loan.amt))
                    .font(.system(size: 34, weight: .heavy).monospacedDigit())
                    .tracking(-0.68)                // -0.02em
                    .foregroundStyle(accent)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    // MARK: - Chart card

    /// `padding:18px 20px` around a 90px-tall, bottom-aligned six-column chart
    /// with 8px gutters. Bars carry `border-radius:6px 6px 3px 3px`.
    private var chartCard: some View {
        let rows = roadmap
        return FTCard {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(rows) { r in
                    VStack(spacing: 5) {
                        // The label is fixed-size, so the reader takes exactly the space
                        // the bar may occupy: 90pt minus the 5pt gap and the label.
                        GeometryReader { g in
                            FTRoundedBar(topRadius: 6, bottomRadius: 3)
                                .fill(accent)
                                .frame(height: max(0, g.size.height * r.barFraction))
                                .frame(width: g.size.width,
                                       height: g.size.height,
                                       alignment: .bottom)
                        }

                        Text(r.month)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.sub)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.chartHeight)
                }
            }
            .animation(FTMotion.resolved(FTMotion.morph(), reduceMotion: reduceMotion),
                       value: loan.amt)
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
        }
    }

    private static let chartHeight: CGFloat = 90

    // MARK: - List card

    /// Six `13px 16px` rows separated by 0.5px hairlines; the card clips them.
    private var listCard: some View {
        let rows = roadmap
        return FTCard {
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { i in
                    let r = rows[i]

                    HStack(spacing: 0) {
                        Text(r.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: 12)

                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(store.fmt(r.pay))
                                .font(.system(size: 14, weight: .bold).monospacedDigit())
                                .foregroundStyle(theme.text)

                            Text(store.fmtN(r.left) + " left")
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(theme.sub)
                                .lineLimit(1)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.vertical, 13)
                    .padding(.horizontal, 16)

                    if i < rows.count - 1 {
                        Rectangle()
                            .fill(theme.sep)
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    // MARK: - Coach note

    /// `roadmapNote` — verbatim from renderVals(). `pay` is the first instalment,
    /// i.e. `Math.ceil(l.amt / 6)`.
    private var roadmapNote: String {
        let pay = store.fmt(roadmap.first?.pay ?? 0)
        if loan.dir == .inbound {
            return "Suggested collection plan: " + pay
                + " per month clears it in 6 months. Ask "
                + store.data.coach.name + " for a friendly collection script."
        }
        return "Avalanche plan: paying " + pay
            + " per month clears this in 6 months. Extra payments go furthest here"
            + " if this is your highest-priority debt."
    }
}

// MARK: - Bar shape

/// `border-radius:6px 6px 3px 3px` — the Design layer has no asymmetric-corner
/// shape, so the loan chart carries its own private one.
private struct FTRoundedBar: Shape {
    let topRadius: CGFloat
    let bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        // A radius can never exceed half the shorter side, exactly as CSS clamps it.
        let limit = min(rect.width, rect.height) / 2
        let top = max(0, min(topRadius, limit))
        let bottom = max(0, min(bottomRadius, limit))

        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + top))
        p.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + top),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottom),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
