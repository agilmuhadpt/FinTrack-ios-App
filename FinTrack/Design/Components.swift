//
//  Components.swift
//  FinTrack — Design system: reusable primitives.
//
//  Every value here is transcribed from the prototype's inline CSS. These components take
//  plain Swift values only (String, Double, Color, Bool, closures) — no app model types —
//  so the design layer stays independent of Core.
//

import SwiftUI

// MARK: - Spacing

enum FTSpacing {
    /// Screen gutters.
    static let gutter: CGFloat = 20
    /// Vertical gap between stacked cards.
    static let cardGap: CGFloat = 10
}

// MARK: - 1. Card

/// White (or #1C1C1E) surface: radius 20, `0 1px 3px` shadow. Content supplies its own padding.
struct FTCard<Content: View>: View {
    @Environment(\.theme) private var theme

    var cornerRadius: CGFloat = 20
    private let content: Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        content
            .clipShape(shape)
            .background(shape.fill(theme.card))
            .ftCardShadow(theme)
    }
}

// MARK: - 2. Pressable

/// Scale-on-press feedback, 160ms ease-out-quint. Pass the scale for the control's size:
/// 0.9 for the 38pt circular header buttons, ~0.96 for chips and rows, 0.985 for large cards.
struct FTPressableStyle: ButtonStyle {
    var scale: CGFloat

    init(scale: CGFloat = 0.96) {
        self.scale = scale
    }

    func makeBody(configuration: Configuration) -> some View {
        FTPressableBody(configuration: configuration, scale: scale)
    }

    private struct FTPressableBody: View {
        let configuration: ButtonStyleConfiguration
        let scale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                // Reduced motion drops the movement and keeps a fade.
                .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
                .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
                .animation(FTMotion.resolved(FTMotion.press(), reduceMotion: reduceMotion),
                           value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == FTPressableStyle {
    static func ftPressable(scale: CGFloat = 0.96) -> FTPressableStyle {
        FTPressableStyle(scale: scale)
    }
}

// MARK: - 3. Segmented control

/// Two-to-four-up segmented control.
///
/// `.pill` is the Personal | Studio control: chip container, radius 12, 3pt padding,
/// sliding `pillBg` indicator at radius 10 (matchedGeometryEffect, 250ms ease-in-out-quart).
/// `.filled` is the entry sheet's Expense | Income | Loan | Milestone control: 6pt gaps,
/// radius 10, blue fill + white text when selected, `segUnselected*` otherwise.
struct FTSegmentedControl: View {

    enum Style {
        case pill
        case filled
    }

    /// The prototype draws the filled control at three different sizes depending on where
    /// it appears; hardcoding one set made the settings and wizard controls too small.
    struct FilledMetrics: Equatable {
        var font: CGFloat = 13
        var vPadding: CGFloat = 9
        var radius: CGFloat = 10
        var gap: CGFloat = 6

        /// Entry sheet kind + bucket rows — dc.html:564, 574.
        static let entry = FilledMetrics()
        /// Settings coach tone — dc.html:352.
        static let settings = FilledMetrics(font: 14, vPadding: 10, radius: 10, gap: 8)
        /// Wizard income type / loan direction / tone — dc.html:462, 480, 516.
        static let wizard = FilledMetrics(font: 14, vPadding: 11, radius: 12, gap: 8)
    }

    let labels: [String]
    @Binding var selection: Int
    var style: Style
    var metrics: FilledMetrics

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pillNamespace

    init(labels: [String],
         selection: Binding<Int>,
         style: Style = .pill,
         metrics: FilledMetrics = .entry) {
        self.labels = labels
        self._selection = selection
        self.style = style
        self.metrics = metrics
    }

    var body: some View {
        switch style {
        case .pill: pillBody
        case .filled: filledBody
        }
    }

    private var pillBody: some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Button { selection = index } label: {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selection == index ? theme.pillText : theme.sub)
                        .contentShape(Rectangle())
                }
                .buttonStyle(FTPressableStyle(scale: 0.97))
                // Outside the button label, so the sliding pill never gets scaled with it.
                .background {
                    if selection == index {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.pillBg)
                            .matchedGeometryEffect(id: "ftSegmentedPill", in: pillNamespace)
                    }
                }
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.chip))
        .animation(FTMotion.resolved(FTMotion.morph(0.25), reduceMotion: reduceMotion),
                   value: selection)
    }

    private var filledBody: some View {
        HStack(spacing: metrics.gap) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.system(size: metrics.font, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, metrics.vPadding)
                    .foregroundStyle(selection == index ? Color.white : theme.segUnselectedText)
                    .background {
                        RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
                            .fill(selection == index ? FTColor.blue : theme.segUnselectedBg)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selection = index }
            }
        }
        .animation(FTMotion.resolved(FTMotion.press(0.2), reduceMotion: reduceMotion),
                   value: selection)
    }
}

// MARK: - 4. Progress bar

/// Pill-ended progress bar. 6pt on milestone cards, 10pt on detail screens and the budget bar.
struct FTProgressBar: View {
    let progress: Double
    var height: CGFloat = 6
    var color: Color = FTColor.blue
    var track: Color?

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(progress: Double, height: CGFloat = 6, color: Color = FTColor.blue, track: Color? = nil) {
        self.progress = progress
        self.height = height
        self.color = color
        self.track = track
    }

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track ?? theme.chip)
                Capsule().fill(color).frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: height)
        .animation(FTMotion.resolved(FTMotion.morph(), reduceMotion: reduceMotion), value: clamped)
    }
}

// MARK: - 5. Tri-color bar

/// The budget bar: 10pt tall, three pill segments with 2pt gaps, widths proportional to the
/// three values. Colors default to Needs blue / Wants orange / Savings green.
struct FTTriColorBar: View {
    let values: [Int]
    let colors: [Color]
    var height: CGFloat
    var spacing: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ first: Int, _ second: Int, _ third: Int,
         colors: [Color] = [FTColor.blue, FTColor.orange, FTColor.green],
         height: CGFloat = 10,
         spacing: CGFloat = 2) {
        self.values = [first, second, third]
        self.colors = colors
        self.height = height
        self.spacing = spacing
    }

    private var total: Int { max(values.reduce(0, +), 0) }

    private func color(_ i: Int) -> Color {
        i < colors.count ? colors[i] : .clear
    }

    var body: some View {
        GeometryReader { geo in
            let available = max(0, geo.size.width - spacing * CGFloat(values.count - 1))
            // CSS: `display:flex;height:10px;border-radius:999px;overflow:hidden;gap:2px`
            // with plain square children — the pill ends come from the CLIPPED
            // container, not from the segments, so inner edges stay square.
            HStack(spacing: spacing) {
                ForEach(values.indices, id: \.self) { i in
                    Rectangle()
                        .fill(color(i))
                        .frame(width: total > 0
                               ? available * CGFloat(max(values[i], 0)) / CGFloat(total)
                               : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(Capsule())
        }
        .frame(height: height)
        .animation(FTMotion.resolved(FTMotion.morph(), reduceMotion: reduceMotion), value: values)
    }
}

// MARK: - 6. Chip

/// Account pill: 12pt / 600, chip background, never wraps.
struct FTChip: View {
    let text: String
    @Environment(\.theme) private var theme

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .ftLabel12Style()
            .foregroundStyle(theme.text)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(theme.chip))
            .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - 7. Icon tile

/// 36x36 transaction tile: radius 12, tinted background, 2-letter colored glyph at 13pt / 700.
struct FTIconTile: View {
    let glyph: String
    let color: Color
    var tint: Color
    var size: CGFloat

    /// `tint` is required: the prototype uses four fixed opaque swatches
    /// (#FDEBEA expense, #E9F6EC income, #E8F1FE loan, #FFF3E0 milestone) and
    /// an alpha-derived fallback would not match any of them.
    init(glyph: String, color: Color, tint: Color, size: CGFloat = 36) {
        self.glyph = glyph
        self.color = color
        self.tint = tint
        self.size = size
    }

    var body: some View {
        Text(glyph)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint))
    }
}

// MARK: - 8. Switch

/// The iOS switch: 51x31 track, 27pt knob inset 2pt, #30D158 on / #E9E9EA off.
struct FTSwitch: View {
    @Binding var isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isOn: Binding<Bool>) { self._isOn = isOn }

    var body: some View {
        Capsule()
            .fill(isOn ? FTColor.green : FTColor.switchTrackOff)
            .frame(width: 51, height: 31)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.25), radius: 2.5, x: 0, y: 1)
                    .offset(x: isOn ? 22 : 2)
            }
            .contentShape(Capsule())
            .onTapGesture { isOn.toggle() }
            .animation(FTMotion.resolved(FTMotion.press(0.2), reduceMotion: reduceMotion), value: isOn)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - 9. Section header

/// 20pt / 700 section title with -0.30 tracking and an optional blue trailing label.
struct FTSectionHeader: View {
    let title: String
    var trailing: String?
    var trailingColor: Color

    @Environment(\.theme) private var theme

    init(_ title: String, trailing: String? = nil, trailingColor: Color = FTColor.blue) {
        self.title = title
        self.trailing = trailing
        self.trailingColor = trailingColor
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .ftSectionStyle()
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(trailingColor)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - 10. Screen header

/// Back chevron + title + subtitle, shared by the loan / milestone / account detail screens.
struct FTScreenHeader: View {
    let title: String
    var subtitle: String?
    var backLabel: String
    let onBack: () -> Void

    @Environment(\.theme) private var theme

    init(title: String, subtitle: String? = nil, backLabel: String = "Back", onBack: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.backLabel = backLabel
        self.onBack = onBack
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button(action: onBack) {
                    HStack(spacing: 2) {
                        FTIcon(.chevronLeft, size: 20, color: FTColor.blue, lineWidth: 2.5)
                        Text(backLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FTColor.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(FTPressableStyle(scale: 0.95))
                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .ftDetailTitleStyle()
                    .foregroundStyle(theme.text)
                    .padding(.top, 4)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(theme.sub)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, FTSpacing.gutter)
        }
    }
}

// MARK: - Preview gallery

private struct FTGallery: View {
    @State private var dark = false
    @State private var mode = 0
    @State private var kind = 0
    @State private var night = false

    private var theme: Theme { .resolve(dark: dark) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Design system").ftTitleStyle().foregroundStyle(theme.text)
                    Spacer()
                    Button {
                        withAnimation(FTMotion.themeCrossfade) { dark.toggle() }
                    } label: {
                        FTIcon(dark ? .sun : .moon, size: 19, color: theme.text)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(theme.card))
                            .ftCardShadow(theme)
                    }
                    .buttonStyle(FTPressableStyle(scale: 0.9))
                }

                FTSegmentedControl(labels: ["Personal", "Studio"], selection: $mode)
                FTSegmentedControl(labels: ["Expense", "Income", "Loan", "Milestone"],
                                   selection: $kind, style: .filled)

                FTCard {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Total balance").ftLabel13Style().foregroundStyle(theme.sub)
                        Text("12,480.50").ftBalanceStyle().foregroundStyle(theme.text)
                            .padding(.top, 4)
                        HStack(spacing: 8) {
                            FTChip("Northbank · 9,180.50")
                            FTChip("CityPay · 3,300")
                        }
                        .padding(.top, 14)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                FTSectionHeader("August budget", trailing: "50 / 30 / 20")
                FTCard {
                    VStack(spacing: 14) {
                        FTTriColorBar(48, 22, 30)
                        FTProgressBar(progress: 0.62, height: 10, color: FTColor.green)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }

                FTSectionHeader("Milestones")
                ForEach(0..<2, id: \.self) { i in
                    FTCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(i == 0 ? "Emergency fund" : "New laptop")
                                    .ftBody16Style().foregroundStyle(theme.text)
                                Spacer()
                                Text(i == 0 ? "64%" : "22%")
                                    .font(.system(size: 13, weight: .bold)).ftTabular()
                                    .foregroundStyle(theme.sub)
                            }
                            FTProgressBar(progress: i == 0 ? 0.64 : 0.22,
                                          color: i == 0 ? FTColor.green : FTColor.orange)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .ftEntrance(delay: Double(i) * 0.05, reduceMotion: false)
                }

                FTCard {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            FTIconTile(glyph: "GR", color: Color(hex: "#248A3D"), tint: Color(hex: "#E9F6EC"))
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Groceries").ftBodyStyle().foregroundStyle(theme.text)
                                Text("Northbank · Needs").font(.system(size: 13)).foregroundStyle(theme.sub)
                            }
                            Spacer()
                            Text("−92.40").ftAmountStyle().foregroundStyle(theme.text)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        Rectangle().fill(theme.sep).frame(height: 0.5)
                        HStack {
                            Text("Night mode").ftBodyStyle().foregroundStyle(theme.text)
                            Spacer()
                            FTSwitch(isOn: $night)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                FTSectionHeader("Icons")
                FTCard {
                    HStack(spacing: 14) {
                        ForEach(FTIcon.Kind.allCases, id: \.self) { k in
                            FTIcon(k, size: 22, color: theme.text)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                }

                FTScreenHeader(title: "Adam", subtitle: "Owes you · due next month") {}
                    .padding(.horizontal, -FTSpacing.gutter)
            }
            .padding(FTSpacing.gutter)
        }
        .background(theme.bg)
        .theme(theme)
    }
}

#Preview("Component gallery") {
    FTGallery()
}
