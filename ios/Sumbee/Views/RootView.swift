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
            let settings = FileSettingsStore()
            var newSeed = { UInt64.random(in: .min ... .max) }
            let args = CommandLine.arguments
            if args.contains("-uiTesting") {
                settings.reset()
                saved = nil
                // `-seed N` deals the same decks every run, so store screenshots show chosen cards.
                if let i = args.firstIndex(of: "-seed"), i + 1 < args.count, var seed = UInt64(args[i + 1]) {
                    newSeed = { defer { seed += 1 }; return seed }
                }
            }
            let snapshot = saved.flatMap { try? JSONDecoder().decode(SessionSnapshot.self, from: $0) }
            model = SessionModel(settings: settings, scheduler: TaskScheduler(), restoring: snapshot, newSeed: newSeed)
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
