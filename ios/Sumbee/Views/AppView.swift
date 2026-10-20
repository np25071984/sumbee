import SumbeeCore
import SwiftUI

/// One screen, three states (SPEC.md FR-6.1).
struct AppView: View {
    let model: SessionModel

    var body: some View {
        switch model.state {
        case .setup(let config):
            VStack(spacing: 20) {
                Text("Sumbee").font(Fonts.baloo(40))
                Text("Numbers up to \(config.maxNumber), \(config.cardCount) cards").font(Fonts.nunito(18))
                Button("Start") { model.start() }.font(Fonts.nunito(24))
            }
        case .cards(let s):
            VStack(spacing: 20) {
                Text("\(s.index + 1) / \(s.total)   \(model.seconds) s").font(Fonts.nunito(18))
                Text(s.card.text).font(Fonts.baloo(64))
                Text(s.input.isEmpty ? "?" : s.input).font(Fonts.baloo(48))
                Button("Show answer") {
                    for ch in String(s.card.answer) { model.digit(ch.wholeNumberValue!) }
                    model.submit()
                }
                Button(s.exitArmed ? "Tap again to stop" : "✕") { model.back() }
            }
        case .results(let r):
            VStack(spacing: 20) {
                Text("\(r.correct) / \(r.total)").font(Fonts.baloo(64))
                Button("Play again") { model.playAgain() }
                Button("Change settings") { model.back() }
            }
        }
    }
}
