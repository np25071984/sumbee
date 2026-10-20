import SumbeeCore
import SwiftUI

/// Everything on the card screen but the four key rows, with the problem at a readable 64 pt:
/// padding 36, header 50, gaps 28, keypad gaps 30, problem 64, answer 104, slot 52, their gaps 32.
private let cardChrome: CGFloat = 396

/// Answering a card (SPEC.md FR-3).
struct CardView: View {
    let state: CardsState
    let model: SessionModel

    var body: some View {
        GeometryReader { geo in
            // Keys give up height, down to FR-3.2's 64 pt, before the problem has to shrink.
            let keyHeight = min(max((geo.size.height - cardChrome) / 4, minKeyHeight), maxKeyHeight)
            VStack(spacing: 14) {
                ProgressHeader(number: state.index + 1, total: state.total, model: model)
                VStack(spacing: 16) {
                    problem
                    AnswerBox(state: state)
                    messageSlot
                }
                .frame(maxHeight: .infinity)
                Keypad(
                    onDigit: model.digit, onDelete: model.delete, onSubmit: model.submit,
                    submitEnabled: !state.input.isEmpty && !state.busy, keyHeight: keyHeight
                )
            }
            .padding(EdgeInsets(top: 20, leading: 16, bottom: 16, trailing: 16))
        }
        // The screen stays on while cards show (FR-3.7); Setup and Results still sleep as usual.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: state.feedback) { _, feedback in
            if let message = announcement(feedback) {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }

    /// The problem takes whatever height is left, so on a short screen it shrinks rather than the answer
    /// box, the message slot or the keypad.
    private var problem: some View {
        GeometryReader { geo in
            let size = min(max(geo.size.height * 1.25, 24), 96)
            Text(state.card.text)
                .font(Fonts.baloo(size))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(24 / size)
                .digitsOnly(size)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement()
        .accessibilityLabel(state.card.text)
        .accessibilityIdentifier("problem")
    }

    /// One slot for every message, so none of them costs the problem any height: the first card's
    /// greeting until it is answered (FR-3.1), the feedback, and the exit hint (FR-3.6), which wins for
    /// its 2 s; whatever it covers shows again after.
    private var messageSlot: some View {
        ZStack {
            if state.exitArmed {
                Pill(text: "Tap ✕ again to stop", background: Palette.ink, ink: Palette.white, small: true)
            } else if state.feedback == .nudge {
                Pill(text: "Are you sure? Check again.", background: Palette.nudgeBg, ink: Palette.nudgeInk, icon: .question)
            } else if state.feedback == .correct {
                Pill(text: "Correct!", background: Palette.goodBg, ink: Palette.goodInk, icon: .check)
            } else if state.feedback == .reveal {
                Pill(text: "The answer is \(state.card.answer)", background: Palette.soft, ink: Palette.ink)
            } else if state.index == 0 && state.attempt == 1 && !state.name.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Ready, \(state.name)?").font(Fonts.nunito(22)).foregroundStyle(Palette.muted)
            }
        }
        .frame(height: 52)
        .accessibilityIdentifier("message")
    }

    private func announcement(_ feedback: Feedback) -> String? {
        switch feedback {
        case .none: nil
        case .correct: String(localized: "Correct!")
        case .nudge: String(localized: "Are you sure? Check again.")
        case .reveal: String(localized: "The answer is \(state.card.answer)")
        }
    }
}

private struct ProgressHeader: View {
    let number: Int
    let total: Int
    let model: SessionModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // ✕ stands in for Android's system Back: tap once to arm, again within 2 s to leave.
                Button { model.back() } label: {
                    IconView(icon: .close, size: 18, color: Palette.muted)
                        .frame(width: 40, height: 40)
                        .background(Palette.white, in: Circle())
                        .overlay(Circle().strokeBorder(Palette.track, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop")
                .accessibilityIdentifier("exit")
                Text("\(number) / \(total)").font(Fonts.baloo(26)).foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("progress")
                Spacer()
                TimerPill(model: model)
            }
            .frame(height: 50)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.track)
                    Capsule().fill(Palette.sun).frame(width: geo.size.width * CGFloat(number - 1) / CGFloat(total))
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
        }
    }
}

/// The only reader of the clock, so a tick redraws this pill and nothing else (IMPLEMENTATION.md §3.4).
private struct TimerPill: View {
    let model: SessionModel

    var body: some View {
        HStack(spacing: 6) {
            IconView(icon: .clock, size: 18, color: Palette.muted)
            Text(formatTime(model.seconds)).font(Fonts.nunito(18)).foregroundStyle(Palette.muted).monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Palette.white, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.track, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("timer")
    }
}

private struct AnswerBox: View {
    let state: CardsState

    var body: some View {
        let (text, color): (String, Color) = switch state.feedback {
        case .reveal: ("\(state.card.answer)", Palette.ink)
        case .correct: (state.input, Palette.goodInk)
        default: state.input.isEmpty ? ("?", Palette.placeholder) : (state.input, Palette.ink)
        }
        let border = switch state.feedback {
        case .nudge: Palette.nudgeBorder
        case .correct: Palette.goodBorder
        default: Palette.line
        }
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        Text(text)
            .font(Fonts.baloo(72))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(32 / 72)
            .digitsOnly(72)
            .padding(.horizontal, 12)
            .frame(width: 220, height: 104)
            .background(Palette.white, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: 4))
            .accessibilityElement()
            .accessibilityLabel("Your answer")
            .accessibilityValue(state.input)
            .accessibilityIdentifier("answer")
    }
}

private struct Pill: View {
    let text: LocalizedStringKey
    let background: Color
    let ink: Color
    var icon: Icon?
    var small = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon { IconView(icon: icon, size: 22, color: ink) }
            Text(text).font(Fonts.nunito(small ? 17 : 20)).foregroundStyle(ink)
        }
        .padding(.horizontal, small ? 20 : 18)
        .padding(.vertical, small ? 12 : 10)
        .background(background, in: Capsule())
    }
}
