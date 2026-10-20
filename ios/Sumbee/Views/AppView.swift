import SumbeeCore
import SwiftUI

/// One screen, three states (SPEC.md FR-6.1). On an iPad-sized window the content stays phone-width,
/// centred (FR-6.3).
struct AppView: View {
    let model: SessionModel

    var body: some View {
        Group {
            switch model.state {
            case .setup(let config): SetupView(config: config, model: model)
            case .cards(let s): CardView(state: s, model: model)
            case .results(let r): ResultsView(state: r, model: model)
            }
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
    }
}
