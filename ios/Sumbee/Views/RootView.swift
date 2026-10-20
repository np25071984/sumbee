import SumbeeCore
import SwiftUI

/// Owns the session: builds it from what the scene saved, tells it when the app comes and goes, and
/// saves it back (IMPLEMENTATION.md §3.4–3.5). `@SceneStorage` is iOS's own state restoration, so a
/// session comes back after iOS ends the app in the background, but not after the user swipes it away.
struct RootView: View {
    @SceneStorage("session") private var saved: Data?
    @State private var model: SessionModel?
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()
            if let model {
                AppView(model: model)
                    .onChange(of: model.state) { save() }
            }
        }
        .onAppear {
            guard model == nil else { return }
            // UI tests start from a fresh install's state every run.
            if CommandLine.arguments.contains("-uiTesting"), let id = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: id)
                saved = nil
            }
            let snapshot = saved.flatMap { try? JSONDecoder().decode(SessionSnapshot.self, from: $0) }
            model = SessionModel(settings: UserDefaultsSettingsStore(), scheduler: TaskScheduler(), restoring: snapshot)
        }
        .onChange(of: phase) { _, phase in
            switch phase {
            case .active: model?.onVisible()
            case .background:
                model?.onHidden()
                save()
            default: break
            }
        }
    }

    private func save() {
        saved = model?.snapshot.flatMap { try? JSONEncoder().encode($0) }
    }
}
