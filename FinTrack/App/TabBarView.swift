import SwiftUI

/// The floating bottom tab bar.
///
/// CSS (FinTrack.dc.html L206): `padding:10px 12px 26px; background:var(--tabbar);
/// backdrop-filter:blur(24px) saturate(180%); border-top:0.5px solid var(--sep);
/// justify-content:space-around`.
///
/// Tab switching is intentionally NOT animated — the handoff calls it a high-frequency
/// action, so only the press scale (0.92) animates.
struct TabBarView: View {

    @Environment(\.theme) private var theme
    @Environment(UIState.self) private var ui

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home, icon: .home, label: "Home")
            tabButton(.activity, icon: .activity, label: "Activity")
            plusButton
            tabButton(.loans, icon: .lock, label: "Loans")
            tabButton(.coach, icon: .chat, label: "Coach")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.horizontal, 12)
        .padding(.bottom, 26)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)      // backdrop-filter: blur(24px) saturate(180%)
                    .overlay(theme.tabBar)
                Rectangle()                        // border-top: 0.5px solid var(--sep)
                    .fill(theme.sep)
                    .frame(height: 0.5)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// `color: {{ homeColor }}` — blue when active, theme.sub when not.
    private func tint(_ tab: Tab) -> Color {
        ui.tab == tab ? FTColor.blue : theme.sub
    }

    private func tabButton(_ tab: Tab, icon: FTIcon.Kind, label: String) -> some View {
        Button {
            ui.tab = tab                            // no withAnimation: switching is instant
        } label: {
            VStack(spacing: 3) {
                FTIcon(icon, size: 24, color: tint(tab))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint(tab))
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(FTPressableStyle(scale: 0.92))
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
        .accessibilityAddTraits(ui.tab == tab ? [.isButton, .isSelected] : .isButton)
    }

    /// The centre action: 52px blue circle lifted 18px above the bar.
    private var plusButton: some View {
        Button {
            ui.openEntry()
        } label: {
            FTIcon(.plus, size: 26, color: .white, lineWidth: 2.5)
                .frame(width: 52, height: 52)
                .background(Circle().fill(FTColor.blue))
                .shadow(color: FTColor.blue.opacity(0.4), radius: 7, x: 0, y: 4)
        }
        .buttonStyle(FTPressableStyle(scale: 0.9))
        .offset(y: -18)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("New entry")
    }
}
