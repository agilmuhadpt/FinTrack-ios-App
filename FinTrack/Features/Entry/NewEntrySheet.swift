//  NewEntrySheet.swift
//  FinTrack — the "New entry" bottom sheet.
//
//  Ported 1:1 from the prototype (FinTrack.dc.html markup lines 552-619, drag handler
//  `sheetDragStart` lines 801-830, row view-models lines 1004-1013).
//
//  Presented by RootView inside its ZStack at z-index 55, NOT by SwiftUI's `.sheet`:
//  the prototype pins exact metrics (radius 24 top corners, max-height 78%, a
//  0 -8px 40px rgba(0,0,0,0.25) shadow) and a bespoke grabber drag that `.sheet`
//  cannot reproduce.

import SwiftUI

struct NewEntrySheet: View {

    @Environment(AppStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Entry state
    //
    // Local, exactly like the prototype's `entry` slot: the picker selections live here and
    // the amount / description are plain text the view hands to `AppStore.saveEntry`.
    // RootView creates this view fresh on every open, so every field resets.

    @State private var draft = EntryDraft()
    @State private var amountText = ""
    @State private var descText = ""
    @FocusState private var focus: Field?

    private enum Field: Hashable { case amount, desc }

    // MARK: Presentation + drag state

    /// Measured height of the sheet — the "100%" of `translateY(100%)`.
    @State private var sheetHeight: CGFloat = 0
    /// Measured height of the scroll content, so the sheet hugs short content.
    @State private var contentHeight: CGFloat = 0
    /// Heights of the non-scrolling chrome (grabber + header, and the footer), so the
    /// scroll body can be capped at `maxHeight - chrome` without the sheet expanding.
    @State private var topChromeHeight: CGFloat = 0
    @State private var bottomChromeHeight: CGFloat = 0
    @State private var didMeasure = false
    @State private var presented = false
    @State private var dismissing = false
    /// Live grabber translation: 1:1 downward, 0.15x upward (`sheetDragStart`).
    @State private var dragOffset: CGFloat = 0
    /// True only while the grabber is actually held. SwiftUI does not call `onEnded` for a
    /// system-cancelled gesture, and the prototype handles that case explicitly (it binds
    /// the same handler to `pointercancel` as to `pointerup`); without this the sheet would
    /// stay parked partway down forever.
    @GestureState private var grabbing = false
    /// Velocity sampler — points per millisecond over the last movement sample, matching
    /// `sheetDragStart`'s `vel = (ev.clientY - lastY) / max(1, now - lastT)`.
    /// SwiftUI's own `value.velocity` is NOT used: the prototype samples manually in both
    /// drag handlers (as ActivityRow does), and `value.velocity` is not populated for
    /// synthesised touches, which made the flick branch untestable.
    ///
    /// Held in a reference type on purpose. Sampling writes on EVERY drag event, and this
    /// view's body is large and contains geometry readers that themselves write `@State`
    /// on layout — invalidating it per event re-entered that layout pass and starved the
    /// gesture, so the sheet stopped dismissing entirely. Mutating a class held in
    /// `@State` does not trigger a view update.
    @State private var tracker = DragVelocityTracker()

    // MARK: Curves not in the shared Motion layer (kept private per the layering rules)

    /// CSS `ease` — `animation: fadeIn 250ms ease` on the scrim.
    private static let scrimFade = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.25)
    /// The drawer curve at the drag-release durations.
    private static let dragOut = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.25)
    private static let dragBack = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.30)
    /// CSS `transition: border-color 200ms ease` on the loan / milestone / account pickers.
    private static let borderFade = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.20)

    private static let kindOrder: [EntryKind] = [.expense, .income, .loan, .milestone]
    private static let kindLabels = ["Expense", "Income", "Loan", "Milestone"]

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                scrim
                sheet(maxHeight: geo.size.height * 0.78)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        // Ignore the device insets (the sheet paints to the very bottom and supplies the
        // 34pt home-indicator padding itself) but NOT the keyboard, so the sheet lifts
        // above it and the fields stay visible.
        .ignoresSafeArea(.container)
        // Default the ledger to whichever side of the app you were just looking at.
        // RootView mounts this sheet fresh each time, so @State is new on every open.
        .onAppear { draft.isBusiness = (store.mode == .business) }
    }

    // MARK: - Scrim

    private var scrim: some View {
        Color.black.opacity(0.4)
            .opacity(presented ? 1 : 0)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { ui.closeEntry() }
            .animation(FTMotion.resolved(Self.scrimFade, reduceMotion: reduceMotion),
                       value: presented)
    }

    // MARK: - Sheet

    private func sheet(maxHeight: CGFloat) -> some View {
        // Before the first measurement, hide the sheet a full 78% below the fold so it can
        // never flash at its resting position.
        let hidden = sheetHeight > 0 ? sheetHeight : maxHeight

        let scrollCap = max(0, maxHeight - topChromeHeight - bottomChromeHeight)

        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                grabber
                header
            }
            .background { chromeReader($topChromeHeight) }

            scrollBody
                // `flex:1` up to the sheet's 78% cap, then it scrolls.
                .frame(height: min(contentHeight, scrollCap))

            footer
                .background { chromeReader($bottomChromeHeight) }
        }
        .frame(maxWidth: .infinity)
        .background(sheetShape.fill(theme.bg))
        .clipShape(sheetShape)
        // CSS `0 -8px 40px rgba(0,0,0,0.25)` — SwiftUI's radius is a sigma, ~half the blur.
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: -8)
        .background { heightReader }
        .offset(y: translation(hidden: hidden))
        .opacity(sheetOpacity)
    }

    private var sheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 24,
                               bottomLeadingRadius: 0,
                               bottomTrailingRadius: 0,
                               topTrailingRadius: 24,
                               style: .continuous)
    }

    /// Reduced motion keeps the finger-tracked drag (the prototype's media query only kills
    /// `transition` / `animation`, never the inline transform) but drops the slide in/out.
    private func translation(hidden: CGFloat) -> CGFloat {
        if reduceMotion { return dragOffset }
        if dismissing { return hidden }
        if !presented { return hidden }
        return dragOffset
    }

    private var sheetOpacity: Double {
        guard reduceMotion else { return 1 }
        return presented && !dismissing ? 1 : 0
    }

    private var heightReader: some View {
        GeometryReader { g in
            Color.clear
                .onAppear { measure(g.size.height) }
                .onChange(of: g.size.height) { _, h in sheetHeight = h }
        }
    }

    private func chromeReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { g in
            Color.clear
                .onAppear { binding.wrappedValue = g.size.height }
                .onChange(of: g.size.height) { _, h in binding.wrappedValue = h }
        }
    }

    private func measure(_ height: CGFloat) {
        sheetHeight = height
        guard !didMeasure else { return }
        didMeasure = true
        // One runloop later: the sheet must first render parked at translateY(100%),
        // otherwise there is nothing for the 350ms slide to travel from.
        DispatchQueue.main.async {
            withAnimation(FTMotion.resolved(FTMotion.sheet(0.35), reduceMotion: reduceMotion)) {
                presented = true
            }
        }
    }

    // MARK: - Grabber (drag to dismiss)

    private var grabber: some View {
        Capsule()
            .fill(theme.sub.opacity(0.4))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .accessibilityIdentifier("ft.entrySheet.grabber")
            .onChange(of: grabbing) { _, active in
                guard !active else { return }
                tracker.reset()
                guard !dismissing, dragOffset != 0 else { return }
                withAnimation(FTMotion.resolved(Self.dragBack, reduceMotion: reduceMotion)) {
                    dragOffset = 0
                }
            }
            .accessibilityLabel("Dismiss")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { ui.closeEntry() }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($grabbing) { _, state, _ in state = true }
            .onChanged { value in
                tracker.sample(value)
                let dy = value.translation.height
                dragOffset = dy > 0 ? dy : dy * 0.15
            }
            .onEnded { value in
                let dy = value.translation.height
                let velocity = tracker.velocity
                tracker.reset()
                if dy > 140 || (dy > 30 && velocity > 0.11) {
                    dismissByDrag()
                } else {
                    withAnimation(FTMotion.resolved(Self.dragBack, reduceMotion: reduceMotion)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func dismissByDrag() {
        withAnimation(FTMotion.resolved(Self.dragOut, reduceMotion: reduceMotion)) {
            dismissing = true
        } completion: {
            ui.closeEntry()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Text("New entry")
                .ftTextStyle(.system(size: 20, weight: .heavy), tracking: -0.30)
                .foregroundStyle(theme.text)

            Spacer(minLength: 12)

            Button { ui.closeEntry() } label: {
                Text("\u{00D7}")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.sub)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(theme.chip))
            }
            .buttonStyle(FTPressableStyle(scale: 0.9))
            .accessibilityLabel("Close")
        }
        .padding(.top, 10)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    // MARK: - Scrolling body

    private var scrollBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                kindSelector
                amountField
                descriptionField

                // The ledger choice applies to expenses and milestone deposits. Income
                // and loan payments behave identically in both modes.
                if draft.kind == .expense || draft.kind == .milestone { ledgerSection }
                if draft.kind == .expense { bucketRow }
                if draft.kind == .loan { loanSection }
                if draft.kind == .milestone { milestoneSection }

                accountSection
            }
            .padding(.top, 8)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background {
                GeometryReader { g in
                    Color.clear
                        .onAppear { contentHeight = g.size.height }
                        .onChange(of: g.size.height) { _, h in contentHeight = h }
                }
            }
        }
        // Height is imposed by the caller: min(content, 78% - chrome).
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: a. Kind

    private var kindSelector: some View {
        FTSegmentedControl(labels: Self.kindLabels, selection: kindBinding, style: .filled)
    }

    private var kindBinding: Binding<Int> {
        Binding(
            get: {
                switch draft.kind {
                case .expense: return 0
                case .income: return 1
                case .loan: return 2
                case .milestone: return 3
                }
            },
            set: { draft.kind = Self.kindOrder[$0] }
        )
    }

    // MARK: b. Amount

    private var amountField: some View {
        TextField("0.00", text: $amountText)
            .textFieldStyle(.plain)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 26, weight: .bold).monospacedDigit())
            .foregroundStyle(theme.text)
            .focused($focus, equals: .amount)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.card))
            .ftCardShadow(theme)
    }

    // MARK: c. Description

    private var descriptionField: some View {
        TextField(descPlaceholder, text: $descText)
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .foregroundStyle(theme.text)
            .submitLabel(.done)
            .focused($focus, equals: .desc)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.card))
            .ftCardShadow(theme)
    }

    private var descPlaceholder: String {
        switch draft.kind {
        case .expense: return "Description (e.g. Groceries)"
        case .income: return "Source (e.g. Payout)"
        default: return "Note (optional)"
        }
    }

    // MARK: d. Bucket (expense only)

    /// Which ledger the entry belongs to. Shown for expenses and milestone deposits.
    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption("Ledger")
            FTSegmentedControl(labels: ["Personal", "Studio"],
                               selection: ledgerBinding,
                               style: .filled)
        }
    }

    private var bucketRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption("Bucket")
            if draft.isBusiness {
                FTSegmentedControl(labels: BusinessBucket.allCases.map(\.rawValue),
                                   selection: businessBucketBinding,
                                   style: .filled)
            } else {
                FTSegmentedControl(labels: Bucket.allCases.map(\.rawValue),
                                   selection: bucketBinding,
                                   style: .filled)
            }
        }
    }

    private var ledgerBinding: Binding<Int> {
        Binding(
            get: { draft.isBusiness ? 1 : 0 },
            set: { draft.isBusiness = ($0 == 1) }
        )
    }

    private var bucketBinding: Binding<Int> {
        Binding(
            get: { Bucket.allCases.firstIndex(of: draft.bucket) ?? 0 },
            set: { draft.bucket = Bucket.allCases[$0] }
        )
    }

    private var businessBucketBinding: Binding<Int> {
        Binding(
            get: { BusinessBucket.allCases.firstIndex(of: draft.businessBucket) ?? 0 },
            set: { draft.businessBucket = BusinessBucket.allCases[$0] }
        )
    }

    // MARK: e. Which loan (loan only)

    private var loanSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption("Which loan")
            VStack(spacing: 6) {
                ForEach(Array(store.data.loans.enumerated()), id: \.element.id) { index, loan in
                    pickerRow(selected: draft.loan == index,
                              action: { draft.loan = index }) {
                        Text(store.fmtN(loan.amt))
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(loan.dir == .inbound ? FTColor.green : FTColor.red)
                    } leading: {
                        Text(loan.name)
                    }
                }
            }
            .animation(FTMotion.resolved(Self.borderFade, reduceMotion: reduceMotion),
                       value: draft.loan)
        }
    }

    // MARK: f. Which milestone (milestone only)

    private var milestoneSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption("Which milestone")
            VStack(spacing: 6) {
                ForEach(Array(milestoneList.enumerated()), id: \.element.id) { index, ms in
                    pickerRow(selected: draft.ms == index,
                              action: { draft.ms = index }) {
                        Text(store.fmtN(ms.saved) + " / " + store.fmtN(ms.target))
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(theme.sub)
                    } leading: {
                        Text(ms.name)
                    }
                }
            }
            .animation(FTMotion.resolved(Self.borderFade, reduceMotion: reduceMotion),
                       value: draft.ms)

            if milestoneList.isEmpty {
                Text(draft.isBusiness
                     ? "No Studio milestones yet."
                     : "No milestones yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.sub)
                    .padding(.top, 2)
            }
        }
        // Switching ledger swaps the list, so a held index could point at a different
        // goal — or past the end of a shorter list.
        .onChange(of: draft.isBusiness) { _, _ in draft.ms = 0 }
    }

    private var milestoneList: [Milestone] {
        draft.isBusiness ? store.data.msBusiness : store.data.msPersonal
    }

    /// Shared loan / milestone row. The 2pt border is always drawn — only its colour
    /// changes — so selecting a row never resizes it.
    private func pickerRow<Trailing: View, Leading: View>(
        selected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder leading: () -> Leading
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button(action: action) {
            HStack(spacing: 12) {
                leading()
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(shape.fill(theme.card))
            .overlay(shape.strokeBorder(selected ? FTColor.blue : .clear, lineWidth: 2))
            .ftCardShadow(theme)
        }
        .buttonStyle(FTPressableStyle(scale: 0.96))
    }

    // MARK: g. Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption("Account")
            FTWrapLayout(spacing: 6, lineSpacing: 6) {
                ForEach(Array(store.data.accounts.enumerated()), id: \.element.id) { index, account in
                    Button { draft.acct = index } label: {
                        Text(account.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.text)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 14)
                            .background(Capsule().fill(theme.card))
                            .overlay(Capsule().strokeBorder(draft.acct == index ? FTColor.blue : .clear,
                                                            lineWidth: 2))
                            .ftCardShadow(theme)
                    }
                    .buttonStyle(FTPressableStyle(scale: 0.96))
                }
            }
            .animation(FTMotion.resolved(Self.borderFade, reduceMotion: reduceMotion),
                       value: draft.acct)
        }
    }

    // MARK: - Caption

    /// 12pt/600 uppercase, tracking +0.24, 4pt leading indent, 6pt bottom margin.
    private func caption(_ text: String) -> some View {
        Text(text)
            .ftTextStyle(.ftLabel12, tracking: 0.24)
            .textCase(.uppercase)
            .foregroundStyle(theme.sub)
            .padding(.leading, 4)
            .padding(.bottom, 6)
    }

    // MARK: - Footer

    private var footer: some View {
        Button(action: save) {
            Text("Save entry")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(FTColor.blue))
                // CSS `0 4px 14px rgba(10,132,255,0.35)`.
                .shadow(color: FTColor.blue.opacity(0.35), radius: 7, x: 0, y: 4)
        }
        .buttonStyle(FTPressableStyle(scale: 0.98))
        .padding(.top, 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }

    /// `saveEntry()` — a blank, non-numeric or non-positive amount does nothing at all:
    /// no mutation, no dismissal.
    private func save() {
        // Locale-aware: a pasted "1,500" must be 1500, not 1.5.
        guard let amount = FinTrackFormatting.amount(from: amountText), amount > 0 else { return }
        if store.saveEntry(draft, amount: amount, description: descText) {
            ui.closeEntry()
        }
    }
}

// MARK: - Wrapping row layout

/// `display:flex; gap:6px; flex-wrap:wrap` for the account chips. Private to this file:
/// the shared Design layer has no flow layout and must not be extended from here.
private struct FTWrapLayout: Layout {

    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        let points = arrange(maxWidth: bounds.width, subviews: subviews).points
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            subview.place(at: CGPoint(x: bounds.minX + points[index].x,
                                      y: bounds.minY + points[index].y),
                          proposal: ProposedViewSize(size))
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }

        let width = maxWidth.isFinite ? min(widest, maxWidth) : widest
        return (CGSize(width: max(0, width), height: y + rowHeight), points)
    }
}

/// Vertical flick velocity in points per millisecond, sampled the way the prototype's
/// `sheetDragStart` does: `vel = (ev.clientY - lastY) / Math.max(1, now - lastT)`.
///
/// A class rather than `@State` scalars so that sampling — which happens on every drag
/// event — never invalidates the sheet's view body.
final class DragVelocityTracker {
    private var lastY: CGFloat = 0
    private var lastTime: Date = .distantPast
    private(set) var velocity: CGFloat = 0

    func reset() {
        lastTime = .distantPast
        velocity = 0
    }

    func sample(_ value: DragGesture.Value) {
        guard lastTime != .distantPast else {
            // pointerdown: seed, so the first real movement measures a sane interval.
            lastY = value.location.y
            lastTime = value.time
            velocity = 0
            return
        }
        let dtMS = CGFloat(max(1, value.time.timeIntervalSince(lastTime) * 1000))
        velocity = (value.location.y - lastY) / dtMS
        lastY = value.location.y
        lastTime = value.time
    }
}
