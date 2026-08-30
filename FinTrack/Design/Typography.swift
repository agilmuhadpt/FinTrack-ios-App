//
//  Typography.swift
//  FinTrack — Design system: type scale.
//
//  SF Pro (the system font) throughout. CSS px map 1:1 to points; CSS `em` letter-spacing
//  is resolved against its own font size and expressed here in points:
//    34pt × -0.020em = -0.68 · 38pt × -0.022em = -0.836 · 20pt × -0.015em = -0.30
//    28pt × -0.020em = -0.56 · 13pt × +0.020em = +0.26
//  CSS weights map 800 -> .heavy, 700 -> .bold, 600 -> .semibold.
//

import SwiftUI

extension Font {

    /// Screen titles — 34pt / 800. Pair with `.ftTitleStyle()`.
    static let ftTitle = Font.system(size: 34, weight: .heavy)

    /// Detail-screen titles — 28pt / 800.
    static let ftDetailTitle = Font.system(size: 28, weight: .heavy)

    /// Balance / hero amount — 38pt / 800, tabular.
    static let ftBalance = Font.system(size: 38, weight: .heavy).monospacedDigit()

    /// Section headers — 20pt / 700.
    static let ftSection = Font.system(size: 20, weight: .bold)

    /// Body — 15pt / 600.
    static let ftBody = Font.system(size: 15, weight: .semibold)

    /// Body large — 16pt / 600.
    static let ftBody16 = Font.system(size: 16, weight: .semibold)

    /// Label — 13pt / 600.
    static let ftLabel13 = Font.system(size: 13, weight: .semibold)

    /// Label small — 12pt / 600.
    static let ftLabel12 = Font.system(size: 12, weight: .semibold)

    /// Row amount — 15pt / 700, tabular.
    static let ftAmount = Font.system(size: 15, weight: .bold).monospacedDigit()
}

// MARK: - Style modifier

/// Applies font + letter-spacing + line-height as one unit.
struct FTTextStyle: ViewModifier {
    let font: Font
    var tracking: CGFloat = 0
    var lineSpacing: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .font(font)
            .tracking(tracking)
            .lineSpacing(lineSpacing)
    }
}

/// CSS `line-height: L` on a font of `size` means a line box of `size * L`.
/// SwiftUI's `.lineSpacing` is EXTRA leading ON TOP of the font's own line height, so the
/// naive `size * (L - 1)` sets text roughly 2.3pt too loose per line. SwiftUI cannot set a
/// line box tighter than the font's natural height, hence the clamp at zero.
func ftLineSpacing(size: CGFloat, lineHeight: CGFloat) -> CGFloat {
    max(0, size * lineHeight - UIFont.systemFont(ofSize: size).lineHeight)
}

extension View {

    /// Arbitrary pairing of one of the `ft*` fonts with its tracking.
    func ftTextStyle(_ font: Font, tracking: CGFloat = 0, lineSpacing: CGFloat = 0) -> some View {
        modifier(FTTextStyle(font: font, tracking: tracking, lineSpacing: lineSpacing))
    }

    /// 34pt / 800, tracking -0.68, line-height 1.05.
    func ftTitleStyle() -> some View {
        modifier(FTTextStyle(font: .ftTitle, tracking: -0.68, lineSpacing: 0))
    }

    /// 28pt / 800, tracking -0.56, line-height 1.05.
    func ftDetailTitleStyle() -> some View {
        modifier(FTTextStyle(font: .ftDetailTitle, tracking: -0.56, lineSpacing: 0))
    }

    /// 38pt / 800, tracking -0.836, line-height 1, tabular.
    func ftBalanceStyle() -> some View {
        modifier(FTTextStyle(font: .ftBalance, tracking: -0.836, lineSpacing: 0))
    }

    /// 20pt / 700, tracking -0.30.
    func ftSectionStyle() -> some View {
        modifier(FTTextStyle(font: .ftSection, tracking: -0.30))
    }

    /// 15pt / 600.
    func ftBodyStyle() -> some View {
        modifier(FTTextStyle(font: .ftBody))
    }

    /// 16pt / 600.
    func ftBody16Style() -> some View {
        modifier(FTTextStyle(font: .ftBody16))
    }

    /// 13pt / 600.
    func ftLabel13Style() -> some View {
        modifier(FTTextStyle(font: .ftLabel13))
    }

    /// 12pt / 600.
    func ftLabel12Style() -> some View {
        modifier(FTTextStyle(font: .ftLabel12))
    }

    /// 15pt / 700 tabular — row amounts.
    func ftAmountStyle() -> some View {
        modifier(FTTextStyle(font: .ftAmount))
    }

    /// 13pt / 600 uppercase, tracking +0.26 — day-group and settings-group labels.
    func ftUppercaseLabelStyle() -> some View {
        modifier(FTTextStyle(font: .ftLabel13, tracking: 0.26))
            .textCase(.uppercase)
    }

    /// Tabular numerals. EVERY monetary amount must use this.
    func ftTabular() -> some View {
        monospacedDigit()
    }
}
