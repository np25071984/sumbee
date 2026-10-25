import SumbeeCore
import SwiftUI

private let numberValues = Array(stride(from: SessionConfig.minMax, through: SessionConfig.maxMax, by: SessionConfig.maxStep))

/// Choosing a session (SPEC.md FR-1).
struct SetupView: View {
    let config: SessionConfig
    let model: SessionModel
    @FocusState private var nameFocused: Bool
    @Environment(\.uiScale) private var s

    var body: some View {
        VStack(spacing: 16 * s) {
            // FR-6.3: no scrolling on a small phone. The gaps close up from 26 to 12 pt to fit; the
            // scroll is only a fallback for large text sizes.
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        gap
                        nameField
                        gap
                        SliderBlock(
                            label: "Numbers up to", values: numberValues, value: config.maxNumber,
                            ticks: [SessionConfig.minMax, SessionConfig.maxMax], onChange: model.setMaxNumber
                        )
                        gap
                        opsBlock
                        gap
                        SliderBlock(
                            label: "How many cards?", values: SessionConfig.cardCounts, value: config.cardCount,
                            ticks: SessionConfig.cardCounts, onChange: model.setCardCount
                        )
                    }
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.immediately)
            }
            Button {
                nameFocused = false
                model.start()
            } label: {
                HStack(spacing: 12 * s) {
                    Text("Start").font(Fonts.words(36 * s)).wordsTrim(36 * s)
                    IconView(icon: .arrowRight, size: 30)
                }
                .foregroundStyle(Palette.ink)
            }
            .buttonStyle(ChunkyButtonStyle(color: Palette.sun, base: Palette.sunShadow, radius: 24, depth: 6))
            .frame(height: 80 * s)
            .accessibilityIdentifier("start")
        }
        .padding(24 * s)
        // FR-1.1: a tap outside the name field closes the keyboard.
        .contentShape(Rectangle())
        .onTapGesture { nameFocused = false }
    }

    private var gap: some View {
        Spacer(minLength: 12 * s).frame(maxHeight: 26 * s)
    }

    private var header: some View {
        HStack(spacing: 12 * s) {
            Image("Bee")
                .resizable()
                .frame(width: 48 * s, height: 48 * s)
                .clipShape(RoundedRectangle(cornerRadius: 14 * s, style: .continuous))
                .accessibilityHidden(true)
            Text("Sumbee").font(Fonts.baloo(30 * s)).foregroundStyle(Palette.ink)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            Text("What's your name?").font(Fonts.nunito(17 * s)).foregroundStyle(Palette.muted)
            TextField(
                "",
                text: Binding(get: { config.name }, set: { model.setName($0) }),
                prompt: Text("Your name").foregroundStyle(Palette.placeholder)
            )
            .font(Fonts.nunito(22 * s))
            .foregroundStyle(Palette.ink)
            .tint(Palette.ink)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($nameFocused)
            .padding(.horizontal, 18 * s)
            .frame(height: 58 * s)
            .background(Palette.white, in: RoundedRectangle(cornerRadius: 16 * s, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16 * s, style: .continuous).strokeBorder(Palette.line, lineWidth: 2 * s))
            .accessibilityLabel("What's your name?")
            .accessibilityIdentifier("name")
        }
    }

    private var opsBlock: some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            Text("Practice").font(Fonts.nunito(17 * s)).foregroundStyle(Palette.muted)
            HStack(spacing: 10 * s) {
                ForEach(MathOperation.allCases, id: \.self) { op in
                    let on = config.ops.contains(op)
                    let shape = RoundedRectangle(cornerRadius: 18 * s, style: .continuous)
                    Button { model.toggleOp(op) } label: {
                        Text(op.symbol)
                            .font(Fonts.baloo(42 * s, .bold))
                            .foregroundStyle(on ? Palette.white : Palette.muted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(on ? Palette.ink : Palette.white, in: shape)
                            .overlay(shape.strokeBorder(on ? Palette.ink : Palette.line, lineWidth: 2 * s))
                            .contentShape(shape)
                    }
                    .buttonStyle(ToggleTileStyle())
                    .frame(height: 76 * s)
                    .accessibilityLabel(op.spokenName)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("op.\(op.rawValue)")
                }
            }
        }
    }
}

extension MathOperation {
    var spokenName: LocalizedStringKey {
        switch self {
        case .plus: "Addition"
        case .minus: "Subtraction"
        case .times: "Multiplication"
        case .divide: "Division"
        }
    }
}

/// No dimming while pressed: the tile's own colour change is the feedback, as on Android.
private struct ToggleTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

/// A label, its value, a stepped slider with a big round thumb for small fingers, and tick labels.
private struct SliderBlock: View {
    let label: LocalizedStringKey
    let values: [Int]
    let value: Int
    let ticks: [Int]
    let onChange: (Int) -> Void
    @Environment(\.uiScale) private var s

    var body: some View {
        VStack(spacing: 2 * s) {
            HStack(alignment: .lastTextBaseline) {
                Text(label).font(Fonts.nunito(17 * s)).foregroundStyle(Palette.muted)
                Spacer()
                Text("\(value)").font(Fonts.baloo(36 * s)).foregroundStyle(Palette.ink).digitsOnly(36 * s)
            }
            .padding(.bottom, 6 * s)
            track
            HStack {
                ForEach(Array(ticks.enumerated()), id: \.offset) { i, tick in
                    if i > 0 { Spacer() }
                    Text("\(tick)").font(Fonts.nunito(14 * s, .bold)).foregroundStyle(Palette.muted)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            guard let i = values.firstIndex(of: value) else { return }
            switch direction {
            case .increment: if i + 1 < values.count { onChange(values[i + 1]) }
            case .decrement: if i > 0 { onChange(values[i - 1]) }
            @unknown default: break
            }
        }
    }

    private var track: some View {
        GeometryReader { geo in
            let thumb: CGFloat = 32 * s
            let span = geo.size.width - thumb
            let first = CGFloat(values.first!), last = CGFloat(values.last!)
            let x = (CGFloat(value) - first) / (last - first) * span
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track).frame(height: 12 * s)
                Capsule().fill(Palette.ink).frame(width: x + thumb / 2, height: 12 * s)
                Circle()
                    .fill(Palette.white)
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 6 * s))
                    .frame(width: thumb, height: thumb)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let f = min(max((g.location.x - thumb / 2) / span, 0), 1)
                let target = first + f * (last - first)
                let nearest = values.min { abs(CGFloat($0) - target) < abs(CGFloat($1) - target) }!
                if nearest != value { onChange(nearest) }
            })
        }
        .frame(height: 40 * s)
    }
}
