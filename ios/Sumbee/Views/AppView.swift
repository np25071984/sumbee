import SumbeeCore
import SwiftUI

/// One screen, three states (SPEC.md FR-6.1). On an iPad-sized window the content stays phone-width,
/// centred, and the whole layout scales up to fill the window (FR-6.3).
struct AppView: View {
    let model: SessionModel
    @State private var scale: CGFloat = 1

    var body: some View {
        Group {
            switch model.state {
            case .setup(let config): SetupView(config: config, model: model)
            case .cards(let s): CardView(state: s, model: model)
            case .results(let r): ResultsView(state: r, model: model)
            }
        }
        .environment(\.uiScale, scale)
        .frame(maxWidth: 480 * scale)
        .frame(maxWidth: .infinity)
        .background {
            // Measured without the keyboard, so the layout doesn't rescale while a name is typed.
            GeometryReader { geo in
                Color.clear.onChange(of: geo.size, initial: true) { _, size in scale = layoutScale(size) }
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}

/// 1 on every phone and on short windows; up to 1.5 on a tall iPad. The reference is a 480 × 860 pt
/// phone layout, so a window gets as much scale as both its width and its height can hold.
func layoutScale(_ size: CGSize) -> CGFloat {
    min(max(min(size.width / 480, size.height / 860), 1), 1.5)
}
