//
//  WizardComponents.swift
//  FinTrack — Onboarding wizard: primitives the Design layer does not carry.
//
//  The wizard's inputs, "+ Add" buttons, draft rows and grouped list card exist only here,
//  so nothing in FinTrack/Design has to change. Every value is transcribed from the inline
//  CSS in FinTrack.dc.html lines 409-551.
//

import SwiftUI
import UIKit

// MARK: - Text field

/// `border:none;background:var(--card);border-radius:14px;padding:14px 16px;font-size:16px;box-shadow:var(--shadow)`
struct WizardField: View {

    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    @Environment(\.theme) private var theme

    init(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) {
        self.placeholder = placeholder
        self._text = text
        self.keyboard = keyboard
    }

    var body: some View {
        TextField("", text: $text,
                  prompt: Text(placeholder).foregroundStyle(theme.sub))
            .font(.system(size: 16))
            .foregroundStyle(theme.text)
            .tint(FTColor.blue)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(keyboard == .default ? .words : .never)
            .submitLabel(.done)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.card))
            .ftCardShadow(theme)
            .accessibilityLabel(placeholder)
    }
}

// MARK: - Add button

/// `background:var(--chip);color:#0A84FF;border-radius:14px;padding:13px;font-size:15px;font-weight:700`
/// with the 0.97 press scale from `style-active`.
struct WizardAddButton: View {

    let title: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(FTColor.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.chip))
        }
        .buttonStyle(FTPressableStyle(scale: 0.97))
    }
}

// MARK: - Draft row

/// One added account / income / loan / milestone.
///
/// `background:var(--card);border-radius:14px;padding:12px 16px;box-shadow:var(--shadow)`
/// with `animation:cardIn 300ms cubic-bezier(0.23,1,0.32,1)` — the same fade-plus-8pt-rise
/// `FTEntrance` performs, so reduced motion keeps the fade and drops the rise.
struct WizardItemRow: View {

    let name: String
    var kind: String? = nil
    let value: String
    var valueColor: Color? = nil
    let onRemove: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text)
                if let kind {
                    Text(kind)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.sub)
                        .layoutPriority(-1)
                }
            }
            .lineLimit(1)
            .truncationMode(.tail)

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .ftTabular()
                    .foregroundStyle(valueColor ?? theme.text)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Button(action: onRemove) {
                    // U+00D7 MULTIPLICATION SIGN, never an "x".
                    Text("\u{00D7}")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FTColor.red)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(FTPressableStyle(scale: 0.9))
                .accessibilityLabel("Remove " + name)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.card))
        .ftCardShadow(theme)
        .ftEntrance(delay: 0, reduceMotion: reduceMotion)
    }
}

// MARK: - Grouped list card

/// `background:var(--card);border-radius:16px;overflow:hidden;box-shadow:var(--shadow)` —
/// the currency list and the summary list.
struct WizardGroupCard<Content: View>: View {

    @Environment(\.theme) private var theme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) { content }
            .clipShape(shape)
            .background(shape.fill(theme.card))
            .ftCardShadow(theme)
    }
}

/// `border-bottom:0.5px solid var(--sep)` — drawn after every row, the last one included,
/// exactly as the markup's per-row border renders inside the clipped card.
struct WizardRowSeparator: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Rectangle().fill(theme.sep).frame(height: 0.5)
    }
}

// MARK: - Row press style

/// `style-active="background:var(--chip)"` — the currency rows tint rather than scale.
struct WizardRowPressStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration)
    }

    private struct PressBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.theme) private var theme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .background(configuration.isPressed ? theme.chip : Color.clear)
                .animation(FTMotion.resolved(FTMotion.press(), reduceMotion: reduceMotion),
                           value: configuration.isPressed)
        }
    }
}
