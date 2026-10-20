import SumbeeCore
import SwiftUI

/// The score (SPEC.md FR-4) and Play again (FR-5).
struct ResultsView: View {
    let state: ResultsState
    let model: SessionModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 24) {
                Group {
                    if state.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Your score:")
                    } else {
                        Text("\(state.name)'s score:")
                    }
                }
                .font(Fonts.baloo(40))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                scoreCard
                timeRow
            }
            .frame(maxHeight: .infinity)
            VStack(spacing: 12) {
                Button { model.playAgain() } label: {
                    HStack(spacing: 12) {
                        IconView(icon: .playAgain, size: 30)
                        Text("Play again").font(Fonts.baloo(36)).foregroundStyle(Palette.ink).digitsOnly(36)
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Palette.sun, base: Palette.sunShadow, radius: 24, depth: 6))
                .frame(height: 90)
                .accessibilityIdentifier("playAgain")
                // iOS has no Back button, so the way to Setup is spelled out.
                Button { model.back() } label: {
                    Text("Change settings").font(Fonts.nunito(18)).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("changeSettings")
            }
        }
        .padding(EdgeInsets(top: 40, leading: 24, bottom: 12, trailing: 24))
    }

    private var scoreCard: some View {
        VStack(spacing: 16) {
            Text("\(Text("\(state.correct)"))\(Text(" / \(state.total)").font(Fonts.baloo(132 * 0.42)).foregroundStyle(Palette.muted))")
                .font(Fonts.baloo(132))
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
            .frame(height: 14)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(Palette.white, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var timeRow: some View {
        HStack(alignment: .lastTextBaseline) {
            HStack(spacing: 10) {
                IconView(icon: .clock, size: 24, color: Palette.muted)
                Text("Time").font(Fonts.nunito(20)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Text(formatTime(Int(state.elapsedMs / 1000))).font(Fonts.baloo(44)).foregroundStyle(Palette.ink).digitsOnly(44)
                .accessibilityIdentifier("time")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Palette.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
