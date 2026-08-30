//
//  Motion.swift
//  FinTrack — Design system: named animation curves.
//
//  `Animation.timingCurve(x1, y1, x2, y2, duration:)` maps exactly onto CSS
//  `cubic-bezier(x1, y1, x2, y2)`, so the prototype's curves transfer without approximation.
//

import SwiftUI

enum FTMotion {

    // MARK: Named curves

    /// CSS `cubic-bezier(0.23, 1, 0.32, 1)` — press feedback and enter transitions. 160ms.
    static let easeOutQuint: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.16)

    /// CSS `cubic-bezier(0.77, 0, 0.175, 1)` — on-screen morphs (bars, segmented pill). <= 250ms.
    static let easeInOutQuart: Animation = .timingCurve(0.77, 0, 0.175, 1, duration: 0.25)

    /// CSS `cubic-bezier(0.32, 0.72, 0, 1)` — sheets and the push banner. 350ms.
    static let drawer: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.35)

    /// CSS `ease` — used for the 300ms theme cross-fade.
    static let themeCrossfade: Animation = .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.30)

    // MARK: Duration-parameterised factories

    /// Press feedback — ease-out quint, 160ms by default.
    static func press(_ d: Double = 0.16) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: d)
    }

    /// On-screen morph — ease-in-out quart, 250ms by default.
    static func morph(_ d: Double = 0.25) -> Animation {
        .timingCurve(0.77, 0, 0.175, 1, duration: d)
    }

    /// Sheet / banner presentation — drawer curve, 350ms by default.
    static func sheet(_ d: Double = 0.35) -> Animation {
        .timingCurve(0.32, 0.72, 0, 1, duration: d)
    }

    /// Card entrance — ease-out quint, 300ms by default.
    static func enter(_ d: Double = 0.30) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: d)
    }

    /// Gesture spring-back — ease-out quint, 250ms.
    static func springBack() -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: 0.25)
    }

    // MARK: Reduced motion

    /// The fade-equivalent used whenever movement is suppressed.
    static let reducedFade: Animation = .easeInOut(duration: 0.2)

    /// Returns `a` normally, or a plain 200ms fade when the user asks for reduced motion.
    /// Callers must additionally drop translation/scale themselves — this only neutralises
    /// the curve, it cannot remove the movement.
    static func resolved(_ a: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reducedFade : a
    }
}

// MARK: - Entrance stagger

/// Milestone/loan card entrance: opacity 0 -> 1 plus an 8pt rise over 300ms.
/// The caller supplies the cascade delay (milestones 50ms per index, loans 40ms). The rise is dropped under
/// reduced motion; the fade is kept.
struct FTEntrance: ViewModifier {
    let delay: Double
    let reduceMotion: Bool

    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : (reduceMotion ? 0 : 8))
            .onAppear {
                guard !shown else { return }
                withAnimation(FTMotion.resolved(FTMotion.enter(), reduceMotion: reduceMotion).delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    /// Staggered card entrance. Pass `Double(index) * 0.05` for milestone cards, `Double(index) * 0.04` for loan cards.
    func ftEntrance(delay: Double, reduceMotion: Bool) -> some View {
        modifier(FTEntrance(delay: delay, reduceMotion: reduceMotion))
    }
}
