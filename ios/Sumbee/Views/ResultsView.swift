import SumbeeCore
import SwiftUI

/// The score (SPEC.md FR-4) and Play again (FR-5).
struct ResultsView: View {
    let state: ResultsState
    let model: SessionModel
    @Environment(\.uiScale) private var s

    var body: some View {
        VStack(spacing: 24 * s) {
            VStack(spacing: 24 * s) {
                Group {
                    if state.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Your score:")
                    } else {
                        Text("\(state.name)'s score:")
                    }
                }
                .font(Fonts.words(40 * s))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                scoreCard
                timeRow
            }
            .frame(maxHeight: .infinity)
            VStack(spacing: 12 * s) {
                Button { model.playAgain() } label: {
                    HStack(spacing: 12 * s) {
                        IconView(icon: .playAgain, size: 30)
                        Text("Play again").font(Fonts.words(36 * s)).foregroundStyle(Palette.ink).wordsTrim(36 * s)
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Palette.sun, base: Palette.sunShadow, radius: 24, depth: 6))
                .frame(height: 90 * s)
                .accessibilityIdentifier("playAgain")
                // iOS has no Back button, so the way to Setup is spelled out.
                Button { model.back() } label: {
                    Text("Change settings").font(Fonts.nunito(18 * s)).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, minHeight: 44 * s)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("changeSettings")
            }
        }
        .padding(EdgeInsets(top: 40 * s, leading: 24 * s, bottom: 12 * s, trailing: 24 * s))
    }

    private var scoreCard: some View {
        VStack(spacing: 16 * s) {
            Text("\(Text("\(state.correct)"))\(Text(" / \(state.total)").font(Fonts.baloo(132 * 0.42 * s)).foregroundStyle(Palette.muted))")
                .font(Fonts.baloo(132 * s))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(48 / 132)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(state.correct) out of \(state.total)")
                .accessibilityIdentifier("score")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.track)
                    Capsule().fill(Palette.sun)
                        .frame(width: state.total > 0 ? geo.size.width * CGFloat(state.correct) / CGFloat(state.total) : 0)
                }
            }
            .frame(height: 14 * s)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 24 * s)
        .padding(.vertical, 32 * s)
        .background(Palette.white, in: RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
    }

    private var timeRow: some View {
        HStack(alignment: .lastTextBaseline) {
            HStack(spacing: 10 * s) {
                IconView(icon: .clock, size: 24, color: Palette.muted)
                Text("Time").font(Fonts.nunito(20 * s)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Text(formatTime(Int(state.elapsedMs / 1000))).font(Fonts.baloo(44 * s)).foregroundStyle(Palette.ink).digitsOnly(44 * s)
                .accessibilityIdentifier("time")
        }
        .padding(.horizontal, 24 * s)
        .padding(.vertical, 18 * s)
        .background(Palette.white, in: RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
