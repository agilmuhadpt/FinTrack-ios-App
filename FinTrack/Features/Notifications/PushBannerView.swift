//
//  PushBannerView.swift
//  FinTrack — the simulated push notification banner (z-index 70).
//
//  Transcribed from FinTrack.dc.html line 636:
//    top:54px; left:10px; right:10px; background: rgba(255,255,255,0.85) / rgba(44,44,46,0.85);
//    backdrop-filter: blur(24px) saturate(180%); border-radius:20px; padding:12px 14px;
//    display:flex; gap:11px; align-items:flex-start;
//    box-shadow: 0 8px 30px rgba(0,0,0,0.25);
//    animation: bannerIn 450ms cubic-bezier(0.32,0.72,0,1)   (from { translateY(-130%) })
//    active: transform: scale(0.98)
//
//  The prototype's `top:54px` is measured inside its mock device frame, whose status bar is
//  58px tall — i.e. the banner sits flush with the top of the content area. On real iOS the
//  safe area supplies that inset, so this view only adds the small gap iOS itself leaves
//  between the status bar and a delivered banner.
//
//  RootView owns *when* the banner appears (3s after launch, auto-dismissed ~9s later) and
//  places it at z-index 70; this file owns only its appearance, its entrance and its tap.
//
//  This is also where the app's *real* notifications are bootstrapped — see
//  NotificationScheduler. Settings must call `NotificationScheduler.reschedule` itself after
//  a reminder time or the coach changes.
//

import SwiftUI

struct PushBannerView: View {

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Live offset while the banner is being flicked away. Never positive: the banner only
    /// travels upward, the way a real iOS notification does.
    @State private var dragOffset: CGFloat = 0

    /// Set while a swipe is in flight so the underlying Button's tap cannot also fire.
    @State private var swiping = false

    // MARK: - Metrics (1:1 with the markup)

    private let sideInset: CGFloat = 10
    private let topGap: CGFloat = 8
    private let corner: CGFloat = 20
    private let iconSide: CGFloat = 36
    private let iconCorner: CGFloat = 9
    private let contentGap: CGFloat = 11

    /// `translateY(-130%)`. A fixed value keeps the entrance declarative — a measured height
    /// is still zero at the moment of insertion, so the drop would not animate at all.
    /// 130% of the ~74pt card is ~96pt, which inside the prototype's mock frame starts the
    /// card over its drawn status bar. On a real device that reads as a glitch, so the travel
    /// is stretched just far enough to begin fully above the physical top of the screen.
    private let dropDistance: CGFloat = 150

    /// Swipe further than this and the banner is dismissed.
    private let dismissThreshold: CGFloat = 40

    /// `bannerBg` — rgba(255,255,255,0.85) light, rgba(44,44,46,0.85) dark.
    private var bannerTint: Color {
        theme.isDark ? .ftRGBA(44, 44, 46, 0.85) : .ftRGBA(255, 255, 255, 0.85)
    }

    /// `'Evening review with ' + data.coach.name + ' ' + data.coach.emoji`
    private var bannerTitle: String {
        "Evening review with " + store.data.coach.name + " " + store.data.coach.emoji
    }

    /// `bannerBody`
    private let bannerBody = "Take 2 minutes to log today's spending."

    // MARK: - Body

    var body: some View {
        Button {
            guard !swiping else { return }
            ui.tapBanner()
        } label: {
            card
        }
        .buttonStyle(FTPressableStyle(scale: 0.98))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("FinTrack, now. \(bannerTitle). \(bannerBody)")
        .accessibilityHint("Opens the new entry sheet")
        .offset(y: dragOffset)
        .simultaneousGesture(swipeUp)
        .padding(.horizontal, sideInset)
        .padding(.top, topGap)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(entrance)
        .task { await bootstrapRealNotifications() }
    }

    // MARK: - Card

    private var card: some View {
        HStack(alignment: .top, spacing: contentGap) {
            appIcon

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("FinTrack")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.text)
                    Spacer(minLength: 0)
                    Text("now")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.sub)
                }

                Text(bannerTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .padding(.top, 1)              // margin-top:1px

                Text(bannerBody)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.sub)
                    .lineSpacing(ftLineSpacing(size: 13, lineHeight: 1.35))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)   // flex:1; min-width:0
        }
        .padding(.vertical, 12)                                 // padding:12px 14px
        .padding(.horizontal, 14)
        .background(surface)
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        // box-shadow: 0 8px 30px rgba(0,0,0,0.25) — CSS blur 30 ≈ SwiftUI radius 15.
        .shadow(color: .ftRGBA(0, 0, 0, 0.25), radius: 15, x: 0, y: 8)
    }

    /// `backdrop-filter: blur(24px) saturate(180%)` under the 0.85 tint.
    private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(bannerTint)
        }
    }

    /// 36×36, radius 9, linear-gradient(135deg,#0A84FF,#5E5CE6), 19px 💳.
    private var appIcon: some View {
        RoundedRectangle(cornerRadius: iconCorner, style: .continuous)
            .fill(FTColor.brandGradient)
            .frame(width: iconSide, height: iconSide)
            .overlay {
                Text("\u{1F4B3}")
                    .font(.system(size: 19))
            }
    }

    // MARK: - Motion

    /// `animation: bannerIn 450ms cubic-bezier(0.32,0.72,0,1)` — drops in from above.
    /// Reduced motion keeps the fade and drops the travel. Removal is always a plain fade,
    /// which is what RootView's auto-dismiss and `tapBanner()` read as.
    private var entrance: AnyTransition {
        let insertion: AnyTransition = reduceMotion
            ? .opacity
            : .offset(y: -dropDistance).combined(with: .opacity)

        return .asymmetric(insertion: insertion, removal: .opacity)
            .animation(FTMotion.resolved(FTMotion.sheet(0.45), reduceMotion: reduceMotion))
    }

    /// Flick the banner up to dismiss it, exactly as iOS does. Downward travel is ignored.
    private var swipeUp: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                swiping = true
                dragOffset = min(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height < -dismissThreshold {
                    withAnimation(FTMotion.resolved(FTMotion.sheet(), reduceMotion: reduceMotion)) {
                        ui.showBanner = false
                    }
                    return
                }
                withAnimation(FTMotion.resolved(FTMotion.springBack(), reduceMotion: reduceMotion)) {
                    dragOffset = 0
                }
                // Let the Button's own tap resolve first, then re-arm it.
                Task {
                    try? await Task.sleep(for: .milliseconds(120))
                    swiping = false
                }
            }
    }

    // MARK: - Real notifications

    /// Refreshes the two daily reminders from current store values, without ever prompting.
    /// current store values. Denial is a no-op: `reschedule` still runs, iOS simply keeps the
    /// requests undelivered until the user allows them in Settings.
    private func bootstrapRealNotifications() async {
        guard !NotificationBootstrap.done else { return }
        NotificationBootstrap.done = true

        // Deliberately does NOT prompt. A cold permission alert on first launch has no
        // context and is the first thing the user would see. Permission is requested where
        // the user actually expresses intent — changing a reminder in Settings, or
        // finishing onboarding. Here we only keep an already-granted schedule current.
        await NotificationScheduler.refreshIfAuthorized(
            reminders: store.data.reminders,
            coach: store.data.coach
        )
    }
}

/// One-shot launch latch. The banner can be shown more than once per launch (RootView after
/// 3s, and again after a reset), but the permission prompt must only ever be asked for once.
@MainActor
private enum NotificationBootstrap {
    static var done = false
}
