//
//  SettingsView.swift
//  FinTrack — the Settings overlay (prototype z-index 45).
//
//  Ported from FinTrack.dc.html: markup lines 311-408, behaviour from the
//  `view.t === 'settings'` block of renderVals() (lines 1071-1102). Every size, padding,
//  radius, colour and copy string below is transcribed from that markup — the only
//  intentional departures are listed in the handoff note at the bottom of this file.
//

import SwiftUI
import UIKit

struct SettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Local mirror of the coach name so the field is never rewritten under the caret.
    /// Committed on submit / focus loss — `store.setCoachName` supplies the "Leo" fallback.
    @State private var coachName = ""
    @FocusState private var coachFocused: Bool

    @State private var newAccountName = ""
    @State private var newAccountBalance = ""

    @State private var exported = false
    @State private var exportFile: ExportFile?

    /// `animation:fadeIn 200ms ease`
    @State private var appeared = false

    /// CSS `ease` — cubic-bezier(0.25, 0.1, 0.25, 1). A fade survives reduced motion.
    private static let fadeIn = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2)
    /// `transition:border-color 200ms ease`
    private static let borderFade = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2)

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            scrollBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The overlay paints the screen background edge to edge; its content stays
        // inside the safe area, which supplies the prototype's fake 58px status bar.
        .background(theme.bg.ignoresSafeArea())
        .opacity(appeared ? 1 : 0)
        .onAppear {
            coachName = store.data.coach.name
            withAnimation(Self.fadeIn) { appeared = true }
        }
        .sheet(item: $exportFile) { file in
            FTShareSheet(url: file.url)
        }
    }

    // MARK: - Header
    // `padding:10px 12px 8px` — Back (#0A84FF, 16/600, gap 2, padding 6px 8px),
    // the title (16/700, margin-right:16px) and a 60px trailing spacer, space-between.

    private var header: some View {
        HStack(spacing: 0) {
            Button {
                ui.closeSettings()
            } label: {
                HStack(spacing: 2) {
                    FTIcon(.chevronLeft, size: 20, color: FTColor.blue, lineWidth: 2.5)
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FTColor.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(FTPressableStyle(scale: 0.95))

            Spacer(minLength: 0)

            Text("Settings")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .padding(.trailing, 16)

            Spacer(minLength: 0)

            Color.clear.frame(width: 60, height: 0)
        }
        .padding(.top, 10)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Scrolling body
    // `flex:1;overflow-y:auto;padding:8px 20px 40px;gap:18px`

    private var scrollBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                appearanceGroup
                currencyGroup
                coachGroup
                remindersGroup
                notificationsGroup
                accountsGroup
                exportButton
            }
            .padding(.top, 8)
            .padding(.horizontal, FTSpacing.gutter)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// `font-size:13px;font-weight:600;color:var(--sub);text-transform:uppercase;
    ///  letter-spacing:0.02em;margin:0 0 8px 4px`
    private func group<Content: View>(_ title: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.26)
                .foregroundStyle(theme.sub)
                .padding(.leading, 4)
                .padding(.bottom, 8)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 0.5pt hairline, rows only.
    private var hairline: some View {
        Rectangle().fill(theme.sep).frame(height: 0.5)
    }

    // MARK: - 1. Appearance

    private var darkBinding: Binding<Bool> {
        Binding(get: { store.dark }, set: { _ in store.toggleTheme() })
    }

    private var appearanceGroup: some View {
        group("Appearance") {
            FTCard(cornerRadius: 16) {
                HStack(spacing: 12) {
                    Text("Night mode")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    FTSwitch(isOn: darkBinding)
                        .accessibilityLabel("Night mode")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 2. Currency
    // `display:flex;gap:8px;flex-wrap:wrap` of capsule buttons:
    // `border:2px solid <blue|transparent>;background:var(--card);padding:7px 16px;14px/600`

    private var currencyGroup: some View {
        group("Currency") {
            FTFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(AppData.currencyOptions, id: \.self) { code in
                    let selected = store.data.currency == code
                    Button {
                        store.setCurrency(code)
                    } label: {
                        Text(code)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(theme.card).ftCardShadow(theme))
                            .overlay(
                                Capsule().strokeBorder(selected ? FTColor.blue : .clear,
                                                       lineWidth: 2)
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(FTPressableStyle(scale: 0.95))
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .animation(FTMotion.resolved(Self.borderFade, reduceMotion: reduceMotion),
                       value: store.data.currency)
        }
    }

    // MARK: - 3. Coach
    // Card `padding:14px 16px`, column `gap:12px`.

    private var toneBinding: Binding<Int> {
        Binding(
            get: { store.data.coach.tone == .playful ? 0 : 1 },
            set: { store.setCoachTone($0 == 0 ? .playful : .serious) }
        )
    }

    private func commitCoachName() {
        store.setCoachName(coachName)
        // Reflect the "Leo" fallback back into the field.
        coachName = store.data.coach.name
        // The evening reminder body embeds the coach name, so the pending request would
        // otherwise keep announcing the old one. Refresh quietly — a rename is not consent
        // to be asked for notification permission.
        let reminders = store.data.reminders
        let coach = store.data.coach
        Task { await NotificationScheduler.refreshIfAuthorized(reminders: reminders, coach: coach) }
    }

    private var coachGroup: some View {
        group("Coach") {
            FTCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    // `background:var(--chip);border-radius:12px;padding:12px 14px;font-size:15px`
                    TextField("Coach name", text: $coachName)
                        .font(.system(size: 15))
                        .foregroundStyle(theme.text)
                        .tint(FTColor.blue)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($coachFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.chip)
                        )
                        .onSubmit { commitCoachName() }
                        .onChange(of: coachFocused) { _, focused in
                            if !focused { commitCoachName() }
                        }

                    // Five equal tiles: `flex:1;border:2px solid …;background:var(--chip);
                    // border-radius:12px;padding:8px 0;font-size:20px`, gap 8.
                    HStack(spacing: 8) {
                        ForEach(Coach.emojiOptions, id: \.self) { emoji in
                            let selected = store.data.coach.emoji == emoji
                            Button {
                                store.setCoachEmoji(emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 20))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(theme.chip)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(selected ? FTColor.blue : .clear,
                                                          lineWidth: 2)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(FTPressableStyle(scale: 0.92))
                            .accessibilityLabel("Coach emoji \(emoji)")
                            .accessibilityAddTraits(selected ? [.isSelected] : [])
                        }
                    }
                    .animation(FTMotion.resolved(Self.borderFade, reduceMotion: reduceMotion),
                               value: store.data.coach.emoji)

                    // Playful | Serious — the shared filled (blue) segmented control.
                    FTSegmentedControl(labels: ["Playful", "Serious"],
                                       selection: toneBinding,
                                       style: .filled,
                                       metrics: .settings)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - 4. Reminders
    // Card radius 16, rows `padding:12px 16px`, 0.5px separator between them.

    private var amBinding: Binding<Date> {
        Binding(
            get: { FTTimeString.date(store.data.reminders.am, fallback: "08:00") },
            set: { store.setReminderAM(FTTimeString.text($0)); syncReminders() }
        )
    }

    private var pmBinding: Binding<Date> {
        Binding(
            get: { FTTimeString.date(store.data.reminders.pm, fallback: "20:00") },
            set: { store.setReminderPM(FTTimeString.text($0)); syncReminders() }
        )
    }

    /// Changing a reminder is the user expressing intent about notifications, so this is
    /// where permission is requested — not on a cold first launch. Also re-registers the
    /// pending requests so the stored time and the scheduled notification cannot drift.
    private func syncReminders() {
        let reminders = store.data.reminders
        let coach = store.data.coach
        Task { await NotificationScheduler.enableAndSchedule(reminders: reminders, coach: coach) }
    }

    private func reminderRow(_ label: String, time: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
            Spacer(minLength: 0)
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(FTColor.blue)
                .accessibilityLabel(label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var remindersGroup: some View {
        group("Reminders") {
            FTCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    reminderRow("Morning check-in", time: amBinding)
                    hairline
                    reminderRow("Evening review", time: pmBinding)
                }
            }
        }
    }

    // MARK: - 5. Notifications
    // Read-only, rebuilt from the live reminder times and coach name.

    private struct NotificationRow: Identifiable {
        let id = UUID()
        let title: String
        let time: String
        let body: String
    }

    private var notificationRows: [NotificationRow] {
        [
            NotificationRow(title: "Morning check-in",
                            time: store.data.reminders.am,
                            body: "Log yesterday's spending before the day starts."),
            NotificationRow(title: "Evening review",
                            time: store.data.reminders.pm,
                            body: "2 minutes with " + store.data.coach.name + " to close the day."),
        ]
    }

    private var notificationsGroup: some View {
        group("Notifications") {
            FTCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    ForEach(Array(notificationRows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { hairline }
                        HStack(alignment: .top, spacing: 12) {
                            // 32x32, radius 8, linear-gradient(135deg,#0A84FF,#5E5CE6), 16px glyph
                            Text("\u{1F4B3}")
                                .font(.system(size: 16))
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(FTColor.brandGradient)
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(row.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(theme.text)
                                    Spacer(minLength: 0)
                                    Text(row.time)
                                        .font(.system(size: 12))
                                        .monospacedDigit()
                                        .foregroundStyle(theme.sub)
                                        .fixedSize()
                                }
                                Text(row.body)
                                    .font(.system(size: 13))
                                    .foregroundStyle(theme.sub)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    // MARK: - 6. Accounts
    // One `border-radius:14px;padding:12px 16px` card per account, gap 8, then the add row.

    private func addAccount() {
        let name = newAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        // `parseFloat(value) || 0`, locale-aware.
        let bal = FinTrackFormatting.amount(from: newAccountBalance) ?? 0
        store.addAccount(name: name, bal: bal)
        newAccountName = ""
        newAccountBalance = ""
    }

    private var accountsGroup: some View {
        group("Accounts") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(store.data.accounts.enumerated()), id: \.element.id) { index, account in
                    FTCard(cornerRadius: 14) {
                        HStack(spacing: 0) {
                            Text(account.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                            Spacer(minLength: 12)
                            Text(store.fmt(account.bal))
                                .font(.system(size: 15, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                                .fixedSize()
                            // `gap:12px` less the padding the 28pt tap target adds.
                            Spacer().frame(width: 3)
                            Button {
                                store.removeAccount(at: index)
                            } label: {
                                Text("\u{00D7}")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(FTColor.red)
                                    .frame(width: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(FTPressableStyle(scale: 0.9))
                            .accessibilityLabel("Delete \(account.name)")
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 7)
                        .padding(.vertical, 12)
                    }
                }

                // `flex:1.4` name / `flex:1` balance / natural-width Add, gap 8, stretched.
                FTFlexRow(weights: [1.4, 1, 0], spacing: 8) {
                    addField("Account name", text: $newAccountName)
                    addField("Balance", text: $newAccountBalance)
                        .keyboardType(.decimalPad)

                    Button(action: addAccount) {
                        Text("Add")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(FTColor.blue)
                            .padding(.horizontal, 16)
                            .frame(maxHeight: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(theme.chip)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(FTPressableStyle(scale: 0.95))
                }
            }
        }
    }

    /// `background:var(--card);border-radius:12px;padding:12px 14px;font-size:14px;box-shadow`
    private func addField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14))
            .foregroundStyle(theme.text)
            .tint(FTColor.blue)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.card)
                    .ftCardShadow(theme)
            )
    }

    // MARK: - 7. Export
    // `background:var(--card);border-radius:16px;padding:14px;font-size:15px;font-weight:700`

    private var exportButton: some View {
        Button(action: exportData) {
            Text(exported ? "Exported \u{2713}" : "Export data")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(exported ? FTColor.green : FTColor.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.card)
                        .ftCardShadow(theme)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(FTPressableStyle(scale: 0.98))
        .animation(FTMotion.resolved(Self.borderFade, reduceMotion: reduceMotion), value: exported)
    }

    /// Writes the ledger to a temporary `fintrack-export.json` and hands the FILE (never a
    /// giant string) to a share sheet, then flips the label the way the prototype does.
    private func exportData() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let payload = try? encoder.encode(store.data) else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fintrack-export.json")
        do {
            try payload.write(to: url, options: .atomic)
        } catch {
            return
        }

        exportFile = ExportFile(url: url)
        exported = true
    }
}

// MARK: - Export plumbing

/// Identifiable wrapper so the share sheet can be presented with `.sheet(item:)`.
private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// `UIActivityViewController` for one file URL.
private struct FTShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - "HH:mm" <-> Date

/// The reminder times are stored as 24-hour "HH:mm" strings. A fixed en_US_POSIX formatter
/// keeps that true on a device set to 12-hour time.
private enum FTTimeString {

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    static func date(_ value: String, fallback: String) -> Date {
        formatter.date(from: value.trimmingCharacters(in: .whitespaces))
            ?? formatter.date(from: fallback)
            ?? Date()
    }

    static func text(_ date: Date) -> String {
        formatter.string(from: date)
    }
}

// MARK: - Layouts

/// `display:flex;flex-wrap:wrap;gap:<spacing>` — left-aligned rows that wrap.
private struct FTFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } +
            lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = subviews[item].sizeThatFits(.unspecified)
                subviews[item].place(at: CGPoint(x: x, y: y),
                                     anchor: .topLeading,
                                     proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var out: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let next = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if !current.items.isEmpty, next > maxWidth {
                out.append(current)
                current = Row(items: [index], width: size.width, height: size.height)
            } else {
                current.items.append(index)
                current.width = next
                current.height = max(current.height, size.height)
            }
        }
        if !current.items.isEmpty { out.append(current) }
        return out
    }
}

/// A flexbox row: a positive weight is `flex-grow` over a zero basis, weight 0 keeps the
/// subview's natural width. Every child is stretched to the row height (`align-items:stretch`).
private struct FTFlexRow: Layout {
    var weights: [CGFloat]
    var spacing: CGFloat

    private func weight(_ index: Int) -> CGFloat {
        index < weights.count ? weights[index] : 1
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let gaps = spacing * CGFloat(subviews.count - 1)
        var fixed = [CGFloat](repeating: 0, count: subviews.count)
        var growTotal: CGFloat = 0
        for index in subviews.indices {
            if weight(index) <= 0 {
                fixed[index] = subviews[index].sizeThatFits(.unspecified).width
            } else {
                growTotal += weight(index)
            }
        }
        let free = max(0, bounds.width - gaps - fixed.reduce(0, +))
        var x = bounds.minX
        for index in subviews.indices {
            let w = weight(index) <= 0
                ? fixed[index]
                : (growTotal > 0 ? free * weight(index) / growTotal : 0)
            subviews[index].place(at: CGPoint(x: x, y: bounds.minY),
                                  anchor: .topLeading,
                                  proposal: ProposedViewSize(width: w, height: bounds.height))
            x += w + spacing
        }
    }
}
