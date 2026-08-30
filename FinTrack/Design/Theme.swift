//
//  Theme.swift
//  FinTrack — Design system: color tokens.
//
//  Values are transcribed 1:1 from the design handoff ("Design Tokens") and from
//  renderVals() in the HTML prototype. Do not round or "improve" any number.
//

import SwiftUI

// MARK: - Color(hex:)

extension Color {

    /// Total hex initialiser. Accepts "#RRGGBB", "RRGGBB", "#RGB", "RGB".
    /// Anything else resolves to `.clear` — it never traps.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard !s.isEmpty, s.allSatisfy({ $0.isHexDigit }), let raw = UInt64(s, radix: 16) else {
            self = .clear
            return
        }
        let r: Double, g: Double, b: Double
        switch s.count {
        case 3:
            let r4 = Double((raw & 0xF00) >> 8)
            let g4 = Double((raw & 0x0F0) >> 4)
            let b4 = Double(raw & 0x00F)
            r = (r4 * 17) / 255; g = (g4 * 17) / 255; b = (b4 * 17) / 255
        case 6:
            r = Double((raw & 0xFF0000) >> 16) / 255
            g = Double((raw & 0x00FF00) >> 8) / 255
            b = Double(raw & 0x0000FF) / 255
        default:
            self = .clear
            return
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// CSS `rgba(r, g, b, a)` with 0–255 channels.
    static func ftRGBA(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
}

// MARK: - Accents (theme independent)

enum FTColor {
    /// Primary / interactive.
    static let blue = Color(hex: "#0A84FF")
    /// Positive / savings.
    static let green = Color(hex: "#30D158")
    /// Wants.
    static let orange = Color(hex: "#FF9F0A")
    /// Negative / destructive.
    static let red = Color(hex: "#FF453A")
    /// Second stop of the brand gradient.
    static let indigo = Color(hex: "#5E5CE6")

    /// CSS `linear-gradient(135deg, #0A84FF, #5E5CE6)`.
    static let brandGradient = LinearGradient(
        colors: [blue, indigo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// iOS switch track when off (#E9E9EA). On-state uses `green`.
    static let switchTrackOff = Color(hex: "#E9E9EA")
}

// MARK: - Theme

/// The full set of surface tokens for one appearance.
///
/// IMPORTANT: FinTrack owns its own light/dark switch. Theme selection is driven by a
/// `Bool` the app stores — never by `@Environment(\.colorScheme)`. Use
/// `Theme.resolve(dark:)` at the root and inject with `.theme(_:)`.
struct Theme: Equatable {

    /// True when this is the dark appearance. Informational only.
    let isDark: Bool

    /// Screen background.
    let bg: Color
    /// Card / grouped-row surface.
    let card: Color
    /// Primary label.
    let text: Color
    /// Secondary label.
    let sub: Color
    /// Chip / segmented-container fill.
    let chip: Color
    /// Hairline separator.
    let sep: Color
    /// Translucent tab-bar material fill.
    let tabBar: Color
    /// Card shadow color (see `ftCardShadow`).
    let shadow: Color

    /// Active pill of the two-up segmented control.
    let pillBg: Color
    /// Label on the active pill.
    let pillText: Color

    /// Unselected item of the four-up (filled) segmented control.
    let segUnselectedBg: Color
    /// Label of an unselected filled segment.
    let segUnselectedText: Color

    static let light = Theme(
        isDark: false,
        bg: Color(hex: "#F2F2F7"),
        card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#1C1C1E"),
        sub: Color(hex: "#8E8E93"),
        chip: Color(hex: "#F2F2F7"),
        sep: .ftRGBA(60, 60, 67, 0.12),
        tabBar: .ftRGBA(255, 255, 255, 0.72),
        shadow: .ftRGBA(10, 20, 40, 0.06),
        pillBg: Color(hex: "#FFFFFF"),
        pillText: Color(hex: "#1C1C1E"),
        segUnselectedBg: Color(hex: "#FFFFFF"),
        segUnselectedText: Color(hex: "#8E8E93")
    )

    static let dark = Theme(
        isDark: true,
        bg: Color(hex: "#000000"),
        card: Color(hex: "#1C1C1E"),
        text: Color(hex: "#FFFFFF"),
        sub: Color(hex: "#98989E"),
        chip: Color(hex: "#2C2C2E"),
        sep: .ftRGBA(84, 84, 88, 0.5),
        tabBar: .ftRGBA(22, 22, 24, 0.75),
        shadow: .ftRGBA(0, 0, 0, 0.4),
        pillBg: Color(hex: "#636366"),
        pillText: Color(hex: "#FFFFFF"),
        segUnselectedBg: Color(hex: "#2C2C2E"),
        segUnselectedText: Color(hex: "#98989E")
    )

    /// Pick an appearance from the app-owned dark flag.
    static func resolve(dark: Bool) -> Theme { dark ? .dark : .light }
}

// MARK: - Environment

private struct FTThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .light
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[FTThemeKey.self] }
        set { self[FTThemeKey.self] = newValue }
    }
}

extension View {
    /// Inject a theme into the environment.
    func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
    }

    /// Inject the theme selected by the app-owned dark flag.
    func theme(dark: Bool) -> some View {
        environment(\.theme, .resolve(dark: dark))
    }

    /// CSS `box-shadow: 0 1px 3px <theme.shadow>`. SwiftUI's shadow radius is a
    /// Gaussian sigma, roughly half the CSS blur radius, so 3px blur -> 1.5.
    func ftCardShadow(_ theme: Theme) -> some View {
        shadow(color: theme.shadow, radius: 1.5, x: 0, y: 1)
    }
}
