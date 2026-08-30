//
//  ActivityRow.swift
//  FinTrack — Activity: one transaction row, with swipe-to-delete.
//
//  Ported from the prototype (FinTrack.dc.html):
//    · markup  line 128-135  — the row div inside the day card
//    · gesture line 770-799  — rowDragStart / deleteTx
//
//  The physics are the prototype's, not UIKit's:
//    left  drag → the row tracks the finger 1:1
//    right drag → rubber-band, eff = dx * 40 / (40 + dx), asymptotic at +40pt
//    release    → delete when dx < -80, or dx < -24 with velocity < -0.11 pt/ms
//                 (velocity is sampled between successive moves, in points per MILLISECOND —
//                  it is NOT SwiftUI's points-per-second `value.velocity`)
//    delete     → 200ms ease-out slide to -110% + fade, and only THEN the store mutation
//    otherwise  → spring back over 250ms cubic-bezier(0.23, 1, 0.32, 1)
//

import SwiftUI

struct ActivityRow: View {

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tx: Transaction

    /// The prototype puts `border-bottom` on every row; the card's `overflow:hidden`
    /// clips the last one, so the last row must not draw a hairline.
    let showsSeparator: Bool

    /// Keyed by transaction id, never by index: indices shift the moment a sibling row
    /// is deleted, so the position is looked up in the store at gesture-end time.
    let onDelete: (UUID) -> Void

    // MARK: Gesture state

    /// Which way this touch turned out to go. `.vertical` hands the pan back to the ScrollView.
    private enum DragPhase { case idle, undecided, horizontal, vertical }

    /// How far the finger must travel before the axis is decided.
    private static let axisLock: CGFloat = 8

    @State private var phase: DragPhase = .idle
    @State private var pressed = false
    @State private var deleting = false

    /// Raw finger delta (the prototype's `dx`) — the release thresholds read this,
    /// not the rubber-banded offset.
    @State private var rawDX: CGFloat = 0
    /// Rendered translation (the prototype's `eff`).
    @State private var offset: CGFloat = 0
    /// True only while the finger is down. SwiftUI skips `onEnded` on a system-cancelled
    /// gesture; the prototype binds its release handler to `pointercancel` as well as
    /// `pointerup`, so without this a cancelled swipe leaves the row displaced.
    @GestureState private var touching = false
    @State private var opacity: Double = 1

    /// Velocity sampler — points per millisecond, over the last movement sample.
    @State private var lastX: CGFloat = 0
    @State private var lastTime: Date = .distantPast
    @State private var velocity: CGFloat = 0

    /// Measured row width; the delete slide travels -110% of it.
    @State private var width: CGFloat = 0

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                FTIconTile(glyph: tx.glyph,
                           color: Color(hex: tx.colorHex),
                           tint: Color(hex: tx.tintHex))

                VStack(alignment: .leading, spacing: 0) {
                    Text(tx.title)
                        .ftBodyStyle()
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(tx.sub)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.sub)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                // flex:1; min-width:0
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(tx.amount)
                    .font(.ftAmount)
                    .foregroundStyle(tx.pos ? FTColor.green : theme.text)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)

            if showsSeparator {
                Rectangle()
                    .fill(theme.sep)
                    .frame(height: 0.5)
            }
        }
        .frame(maxWidth: .infinity)
        // Collapse the row into ONE accessibility element before naming it. Without
        // .combine, `.accessibilityIdentifier` propagates to every child, each child
        // reports the same identifier, and the container ends up with it concatenated
        // once per child — so a test query matches a 19pt glyph instead of the row.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ft.row.\(tx.title)")
        // style-active="background:var(--chip)" — no transition on the row in the prototype.
        .background(pressed ? theme.chip : theme.card)
        .background(widthReader)
        .contentShape(Rectangle())
        .offset(x: offset)
        .opacity(opacity)
        // Simultaneous, so a vertical pan still reaches the ScrollView underneath.
        .simultaneousGesture(drag)
        .onChange(of: touching) { _, active in
            guard !active, !deleting else { return }
            phase = .idle
            pressed = false
            guard offset != 0 else { return }
            withAnimation(FTMotion.resolved(FTMotion.springBack(), reduceMotion: reduceMotion)) {
                offset = 0
                rawDX = 0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("Delete")) { onDelete(tx.id) }
    }

    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .task(id: proxy.size.width) { width = proxy.size.width }
        }
    }

    // MARK: Gesture

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                guard !deleting else { return }

                // pointerdown: seed the velocity sampler, light the active background.
                if phase == .idle {
                    phase = .undecided
                    pressed = true
                    rawDX = 0
                    velocity = 0
                    lastX = value.location.x
                    lastTime = value.time
                    if value.translation == .zero { return }
                }

                // The ScrollView owns this touch.
                if phase == .vertical { return }

                if phase == .undecided {
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard max(abs(dx), abs(dy)) >= Self.axisLock else {
                        // Keep sampling so the flick velocity is warm the instant we lock.
                        sample(value)
                        return
                    }
                    guard abs(dx) > abs(dy) else {
                        phase = .vertical
                        pressed = false
                        return
                    }
                    phase = .horizontal
                }

                sample(value)

                let dx = value.translation.width
                rawDX = dx
                // eff = dx < 0 ? dx : (dx * 40) / (40 + dx)
                offset = dx < 0 ? dx : (dx * 40) / (40 + dx)
            }
            .onEnded { _ in
                let wasHorizontal = (phase == .horizontal)
                phase = .idle
                pressed = false
                guard wasHorizontal, !deleting else { return }

                if rawDX < -80 || (rawDX < -24 && velocity < -0.11) {
                    remove()
                } else {
                    withAnimation(FTMotion.resolved(FTMotion.springBack(),
                                                    reduceMotion: reduceMotion)) {
                        offset = 0
                    }
                }
            }
    }

    /// `vel = (x - lastX) / max(1, now - lastT)` — points per millisecond.
    private func sample(_ value: DragGesture.Value) {
        let dtMS = CGFloat(max(1, value.time.timeIntervalSince(lastTime) * 1000))
        velocity = (value.location.x - lastX) / dtMS
        lastX = value.location.x
        lastTime = value.time
    }

    /// 200ms slide-out to -110% + fade, then the store mutation — in that order, so the
    /// row never disappears from under the animation.
    private func remove() {
        deleting = true
        let id = tx.id

        if reduceMotion {
            // Reduced motion keeps the fade and drops the slide.
            withAnimation(FTMotion.reducedFade) {
                opacity = 0
            } completion: {
                onDelete(id)
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                offset = -(width > 0 ? width : 420) * 1.1
                opacity = 0
            } completion: {
                onDelete(id)
            }
        }
    }
}
