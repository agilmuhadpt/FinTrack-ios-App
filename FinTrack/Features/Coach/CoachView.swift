//
//  CoachView.swift
//  FinTrack — Coach (tab 5), the AI chat.
//
//  CSS source: FinTrack.dc.html L173-204. The 58px top padding in the markup is the mock
//  frame's status bar, so it is dropped here and the real safe area supplies it; every
//  other px maps 1:1 to points.
//

import SwiftUI
import UIKit

struct CoachView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var service = CoachService.shared
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    /// Scroll target pinned below the quick replies.
    private let bottomAnchor = "ft-coach-bottom"

    // MARK: - Derived copy

    private var coach: Coach { store.data.coach }

    /// The greeting is regenerated on every render and never stored — the prototype
    /// prepends it to `chatMsgs`, so it is not part of the history the model sees.
    private var greeting: String {
        let pct = store.bucketPct(.wants)
        if coach.tone == .serious {
            return "Hello. Wants spending is at \(pct)% of this month's total. Ask me anything about your finances."
        }
        return "Hey! Wants are at \(pct)% this month \u{2014} nice. Ask me anything about your money."
    }

    private var quickReplies: [(label: String, prompt: String)] {
        [
            (label: "Can I afford it?",
             prompt: "Can I afford a \(store.data.currency) 300 dinner out this week given my budget?"),
            (label: "Collection script",
             prompt: "Write me a short, friendly message to ask for repayment of the largest loan owed to me."),
            (label: "Milestone check",
             prompt: "How am I doing on my milestones? What should I prioritize this month?"),
        ]
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.isThinking
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            chat
            inputBar
        }
    }

    // MARK: - 1. Header

    /// `padding:58px 20px 12px; gap:12px; background:var(--tabbar); backdrop-filter:blur(20px) saturate(180%)`
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#30D158"), Color(hex: "#0A84FF")],
                        startPoint: .topLeading,        // linear-gradient(135deg, …)
                        endPoint: .bottomTrailing))
                Text(coach.emoji)
                    .font(.system(size: 24))
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(coach.name)
                    .ftTextStyle(.system(size: 17, weight: .bold), tracking: -0.17)
                    .foregroundStyle(theme.text)
                Text("Your money coach")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FTColor.green)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FTSpacing.gutter)
        .padding(.bottom, 12)
        .background(alignment: .bottom) {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)          // backdrop-filter: blur(20px) saturate(180%)
                    .overlay(theme.tabBar)
            }
            .ignoresSafeArea(edges: .top)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 2. Chat

    /// `flex:1; overflow-y:auto; padding:12px 20px 8px; gap:10px`
    private var chat: some View {
        GeometryReader { geo in
            let bubbleMax = max(80, (geo.size.width - FTSpacing.gutter * 2) * 0.8)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        bubble(text: greeting, role: .coach, maxWidth: bubbleMax)
                            .id("ft-coach-greeting")

                        ForEach(service.messages) { message in
                            bubble(text: message.text, role: message.role, maxWidth: bubbleMax)
                                .id(message.id)
                        }

                        if service.isThinking {
                            thinkingBubble
                        }

                        CoachFlowLayout(spacing: 8) {
                            ForEach(quickReplies, id: \.label) { reply in
                                quickReplyPill(reply.label, prompt: reply.prompt)
                            }
                        }
                        .padding(.top, 4)

                        Color.clear
                            .frame(height: 0)
                            .id(bottomAnchor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                    .padding(.horizontal, FTSpacing.gutter)
                    .padding(.bottom, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: service.messages.count) { scrollToBottom(proxy) }
                .onChange(of: service.isThinking) { scrollToBottom(proxy) }
                .onAppear {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                    // Load the model while the user reads the greeting, so the cold-start
                    // cost is not charged to their first message.
                    service.warmUpIfNeeded()
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(FTMotion.resolved(FTMotion.morph(), reduceMotion: reduceMotion)) {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }

    /// `max-width:80%; padding:12px 16px; font-size:15px; line-height:1.45; box-shadow:var(--shadow); white-space:pre-wrap`
    private func bubble(text: String, role: ChatMessage.Role, maxWidth: CGFloat) -> some View {
        let isUser = role == .user
        return HStack(spacing: 0) {
            if isUser { Spacer(minLength: 0) }

            Text(text)
                .font(.system(size: 15))
                .lineSpacing(Self.bubbleLineSpacing)
                .foregroundStyle(isUser ? Color.white : theme.text)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                // `max-width:80%` on a default content-box element caps the CONTENT box,
                // so the 16pt horizontal padding sits outside it.
                .frame(maxWidth: maxWidth, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background {
                    bubbleShape(isUser: isUser)
                        .fill(isUser ? FTColor.blue : theme.card)
                        .ftCardShadow(theme)
                }

            if !isUser { Spacer(minLength: 0) }
        }
    }

    /// coach `20px 20px 20px 6px` / user `20px 20px 6px 20px` — only one bottom corner tightens.
    private func bubbleShape(isUser: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(
            topLeading: 20,
            bottomLeading: isUser ? 20 : 6,
            bottomTrailing: isUser ? 6 : 20,
            topTrailing: 20))
    }

    /// `{{ coachName }} is thinking…` — 14px, sub colour, coach bubble geometry.
    private var thinkingBubble: some View {
        HStack(spacing: 0) {
            Text("\(coach.name) is thinking\u{2026}")
                .font(.system(size: 14))
                .foregroundStyle(theme.sub)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background {
                    bubbleShape(isUser: false)
                        .fill(theme.card)
                        .ftCardShadow(theme)
                }
            Spacer(minLength: 0)
        }
        .transition(.opacity)
        .accessibilityLabel("\(coach.name) is thinking")
    }

    /// `background:var(--card); color:#0A84FF; 14px/600; border-radius:999px; padding:9px 15px`
    private func quickReplyPill(_ label: String, prompt: String) -> some View {
        Button {
            send(prompt)
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FTColor.blue)
                .lineLimit(1)
                .fixedSize()
                .padding(.vertical, 9)
                .padding(.horizontal, 15)
                .background {
                    Capsule()
                        .fill(theme.card)
                        .ftCardShadow(theme)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(FTPressableStyle(scale: 0.96))
        .disabled(service.isThinking)
    }

    // MARK: - 3. Input bar

    /// `display:flex; gap:8px; padding:8px 20px 100px` — the 100pt clears the floating tab bar.
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("",
                      text: $draft,
                      prompt: Text("Message \(coach.name)\u{2026}").foregroundStyle(theme.sub))
                .font(.system(size: 15))
                .foregroundStyle(theme.text)
                .tint(FTColor.blue)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .focused($inputFocused)
                .onSubmit { send(draft) }
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background {
                    Capsule()
                        .fill(theme.card)
                        .ftCardShadow(theme)
                }
                .accessibilityLabel("Message \(coach.name)")

            Button {
                send(draft)
            } label: {
                FTIcon(.send, size: 20, color: .white, lineWidth: 2.5)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(FTColor.blue))
                    .contentShape(Circle())
            }
            .buttonStyle(FTPressableStyle(scale: 0.9))
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.top, 8)
        .padding(.horizontal, FTSpacing.gutter)
        .padding(.bottom, 100)
    }

    // MARK: - Sending

    /// `sendChat` / `chatKeyDown` — trim, ignore empties, clear the field, then ask.
    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !service.isThinking else { return }
        draft = ""
        service.send(trimmed, store: store)
    }

    /// CSS `line-height: 1.45` at 15px, expressed as SwiftUI's *extra* leading.
    private static let bubbleLineSpacing: CGFloat =
        ftLineSpacing(size: 15, lineHeight: 1.45)
}

// MARK: - Wrapping row layout

/// `display:flex; gap:8px; flex-wrap:wrap` for the quick-reply pills.
private struct CoachFlowLayout: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let limit = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > limit {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: limit.isFinite ? min(widest, limit) : widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
