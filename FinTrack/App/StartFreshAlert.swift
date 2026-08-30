import SwiftUI

/// The destructive "Start fresh?" confirmation (FinTrack.dc.html L620-633).
///
/// Hand-drawn rather than a system `.alert` because the prototype specifies exact
/// metrics — 270pt wide, radius 16, 0.5px hairline dividers, and a red confirm.
struct StartFreshAlert: View {

    @Environment(\.theme) private var theme
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Start fresh?")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(theme.text)
                    .padding(.top, 20)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)

                Text("This replaces all current accounts, loans and milestones with your new setup.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.sub)
                    .lineSpacing(ftLineSpacing(size: 13, lineHeight: 1.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                Rectangle().fill(theme.sep).frame(height: 0.5)

                HStack(spacing: 0) {
                    alertButton("Cancel", weight: .semibold, color: FTColor.blue) {
                        ui.cancelReset()
                    }
                    Rectangle().fill(theme.sep).frame(width: 0.5)
                    alertButton("Start Fresh", weight: .bold, color: FTColor.red) {
                        ui.confirmReset()
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 270)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.card))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            // animation: alertIn 200ms — opacity + scale from 0.95
            .scaleEffect(appeared || reduceMotion ? 1 : 0.95)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(FTMotion.resolved(FTMotion.press(0.2), reduceMotion: reduceMotion)) {
                    appeared = true
                }
            }
        }
    }

    private func alertButton(_ title: String,
                             weight: Font.Weight,
                             color: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: weight))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
        }
        .buttonStyle(FTAlertButtonStyle(pressedBackground: theme.chip))
    }
}

/// Alert rows highlight their whole cell on press (`style-active="background:var(--chip)"`)
/// rather than scaling like the rest of the app's pressables.
private struct FTAlertButtonStyle: ButtonStyle {
    let pressedBackground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? pressedBackground : .clear)
    }
}
