import Observation

public enum Feedback: Sendable {
    case none, correct, nudge, reveal
}

/// One screen, three states (SPEC.md FR-6.1; IMPLEMENTATION.md §3.1).
public enum UiState: Equatable, Sendable {
    case setup(SessionConfig)
    case cards(CardsState)
    case results(ResultsState)
}

public struct CardsState: Equatable, Sendable {
    public var deck: [Card]
    public var index: Int
    public var input: String
    public var attempt: Int
    public var feedback: Feedback
    public var correct: Int
    public var name: String
    public var maxDigits: Int
    /// FR-3.6: ✕ was tapped once in the last 2 s; the next tap leaves.
    public var exitArmed = false

    public var card: Card { deck[index] }
    public var total: Int { deck.count }

    /// The card is decided and the next one is on its way: input is ignored (§3.3).
    public var busy: Bool { feedback == .correct || feedback == .reveal }
}

public struct ResultsState: Equatable, Sendable {
    public var name: String
    public var correct: Int
    public var total: Int
    public var elapsedMs: Int64
}

/// What a session needs to come back after iOS ends the app in the background (IMPLEMENTATION.md §3.5):
/// the deck itself never, only its seed. A card already decided is saved as the card after it, so a
/// restore never replays a decision.
public struct SessionSnapshot: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Sendable { case cards, results }

    public var mode: Mode
    public var config: SessionConfig
    public var seed: UInt64 = 0
    public var index = 0
    public var input = ""
    public var attempt = 1
    public var correct = 0
    public var total = 0
    public var elapsedMs: Int64 = 0
}

/// The whole session: Setup, the cards, the clock and Results. A port of the Android
/// `SessionViewModel`, with ✕ standing in for the system Back button iOS doesn't have.
@MainActor
@Observable
public final class SessionModel {
    public static let correctMs: Int64 = 300
    public static let revealMs: Int64 = 1500
    public static let exitWindowMs: Int64 = 2000

    public private(set) var state: UiState

    /// The running clock in whole seconds, apart from `state` so a tick redraws only the timer (§3.4).
    public private(set) var seconds = 0

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let scheduler: Scheduler
    @ObservationIgnored private let newSeed: () -> UInt64

    @ObservationIgnored private var config: SessionConfig
    @ObservationIgnored private var seed: UInt64 = 0

    @ObservationIgnored private var accumulatedMs: Int64 = 0
    @ObservationIgnored private var runningSince: Int64?
    @ObservationIgnored private var visible = true
    @ObservationIgnored private var timing = false

    @ObservationIgnored private var tick: Scheduled?
    @ObservationIgnored private var advancing: Scheduled?
    @ObservationIgnored private var exitReset: Scheduled?

    public init(
        settings: SettingsStore,
        scheduler: Scheduler,
        restoring snapshot: SessionSnapshot? = nil,
        newSeed: @escaping () -> UInt64 = { UInt64.random(in: .min ... .max) }
    ) {
        self.settings = settings
        self.scheduler = scheduler
        self.newSeed = newSeed
        // FR-1.6: Setup opens on the remembered values.
        config = settings.load()
        state = .setup(config)
        if let snapshot { restore(snapshot) }
    }

    // MARK: Setup (FR-1)

    public func setName(_ raw: String) { editSetup { $0.name = SessionConfig.filterName(raw) } }

    public func setMaxNumber(_ value: Int) { editSetup { $0.maxNumber = value } }

    public func setCardCount(_ value: Int) { editSetup { $0.cardCount = value } }

    /// FR-1.3: deselecting the last selected operation is refused.
    public func toggleOp(_ op: MathOperation) {
        editSetup {
            if !$0.ops.contains(op) {
                $0.ops.insert(op)
            } else if $0.ops.count > 1 {
                $0.ops.remove(op)
            }
        }
    }

    private func editSetup(_ change: (inout SessionConfig) -> Void) {
        guard case .setup(var c) = state else { return }
        change(&c)
        state = .setup(c)
    }

    /// FR-1.5: save the settings, build the deck, show the first card.
    public func start() {
        guard case .setup(let c) = state else { return }
        config = c.sanitized()
        settings.save(config)
        deal()
    }

    /// A fresh deck with the current settings: Start, and Play again (FR-5.1).
    private func deal() {
        advancing?.cancel()
        exitReset?.cancel()
        seed = newSeed()
        accumulatedMs = 0
        runningSince = nil
        seconds = 0
        timing = true
        resumeClock()
        state = .cards(CardsState(
            deck: Self.deck(config, seed), index: 0, input: "", attempt: 1, feedback: .none,
            correct: 0, name: config.name, maxDigits: config.maxDigits
        ))
    }

    private static func deck(_ config: SessionConfig, _ seed: UInt64) -> [Card] {
        var random = SeededRandom(seed: seed)
        return DeckGenerator.generate(config, using: &random).cards
    }

    // MARK: Cards (FR-3)

    public func digit(_ d: Int) {
        guard var s = cards, !s.busy, s.input.count < s.maxDigits else { return }
        s.input = s.input == "0" ? "\(d)" : s.input + "\(d)"
        state = .cards(s)
    }

    public func delete() {
        guard var s = cards, !s.busy, !s.input.isEmpty else { return }
        s.input.removeLast()
        state = .cards(s)
    }

    /// FR-3.3 and FR-3.4: right → next; wrong once → nudge; wrong twice → show the answer, next.
    public func submit() {
        guard var s = cards, !s.busy, let typed = Int(s.input) else { return }
        if typed == s.card.answer {
            s.feedback = .correct
            s.correct += 1
            decide(s, Self.correctMs)
        } else if s.attempt == 1 {
            s.attempt = 2
            s.feedback = .nudge
            state = .cards(s)
        } else {
            s.feedback = .reveal
            decide(s, Self.revealMs)
        }
    }

    private func decide(_ s: CardsState, _ delayMs: Int64) {
        if s.index == s.total - 1 { stopClock() } // FR-3.5: the clock stops on the last final attempt
        state = .cards(s)
        advancing = scheduler.after(delayMs) { [weak self] in self?.advance() }
    }

    private func advance() {
        guard var s = cards else { return }
        if s.index == s.total - 1 {
            state = .results(ResultsState(name: s.name, correct: s.correct, total: s.total, elapsedMs: accumulatedMs))
        } else {
            s.index += 1
            s.input = ""
            s.attempt = 1
            s.feedback = .none
            state = .cards(s)
        }
    }

    // MARK: Leaving and Play again (FR-3.6, FR-5)

    /// ✕ on Cards and "Change settings" on Results. On Cards the first tap only arms the exit for 2 s.
    /// Returns false on Setup, where there is nothing to go back to.
    @discardableResult
    public func back() -> Bool {
        switch state {
        case .setup:
            return false
        case .results:
            toSetup()
        case .cards(var s):
            if s.exitArmed {
                toSetup()
            } else {
                s.exitArmed = true
                state = .cards(s)
                exitReset?.cancel()
                exitReset = scheduler.after(Self.exitWindowMs) { [weak self] in
                    guard let self, var s = self.cards else { return }
                    s.exitArmed = false
                    self.state = .cards(s)
                }
            }
        }
        return true
    }

    /// FR-5.1: straight into a new session with the same settings, no stop at Setup.
    public func playAgain() {
        if case .results = state { deal() }
    }

    private func toSetup() {
        advancing?.cancel()
        exitReset?.cancel()
        stopClock()
        accumulatedMs = 0
        seconds = 0
        state = .setup(config)
    }

    // MARK: The clock (FR-3.5; IMPLEMENTATION.md §3.4)

    public func onVisible() {
        visible = true
        resumeClock()
    }

    public func onHidden() {
        visible = false
        pauseClock()
    }

    private func elapsedNow() -> Int64 {
        accumulatedMs + (runningSince.map { scheduler.now - $0 } ?? 0)
    }

    private func resumeClock() {
        guard timing, visible, runningSince == nil else { return }
        runningSince = scheduler.now
        tick?.cancel()
        onTick()
    }

    private func onTick() {
        let elapsed = elapsedNow()
        seconds = Int(elapsed / 1000)
        tick = scheduler.after(1000 - elapsed % 1000) { [weak self] in self?.onTick() }
    }

    private func pauseClock() {
        if let since = runningSince { accumulatedMs += scheduler.now - since }
        runningSince = nil
        tick?.cancel()
        seconds = Int(accumulatedMs / 1000)
    }

    private func stopClock() {
        pauseClock()
        timing = false
    }

    // MARK: State restoration (IMPLEMENTATION.md §3.5)

    private var cards: CardsState? {
        if case .cards(let s) = state { s } else { nil }
    }

    /// What to save now; nil on Setup, which comes back from the settings alone.
    public var snapshot: SessionSnapshot? {
        switch state {
        case .setup:
            return nil
        case .results(let r):
            return SessionSnapshot(mode: .results, config: config, correct: r.correct, total: r.total, elapsedMs: r.elapsedMs)
        case .cards(let s):
            if s.busy && s.index == s.total - 1 {
                return SessionSnapshot(mode: .results, config: config, correct: s.correct, total: s.total, elapsedMs: accumulatedMs)
            }
            return SessionSnapshot(
                mode: .cards, config: config, seed: seed,
                index: s.busy ? s.index + 1 : s.index,
                input: s.busy ? "" : s.input,
                attempt: s.busy ? 1 : s.attempt,
                correct: s.correct, total: s.total, elapsedMs: elapsedNow()
            )
        }
    }

    /// Rebuilds a saved session; stays on Setup when the snapshot doesn't add up.
    private func restore(_ snapshot: SessionSnapshot) {
        let c = snapshot.config.sanitized()
        switch snapshot.mode {
        case .results:
            guard snapshot.total > 0, (0...snapshot.total).contains(snapshot.correct) else { return }
            config = c
            accumulatedMs = snapshot.elapsedMs
            seconds = Int(accumulatedMs / 1000)
            state = .results(ResultsState(name: c.name, correct: snapshot.correct, total: snapshot.total, elapsedMs: accumulatedMs))
        case .cards:
            let deck = Self.deck(c, snapshot.seed)
            guard deck.indices.contains(snapshot.index), (1...2).contains(snapshot.attempt),
                  snapshot.input.count <= c.maxDigits, snapshot.input.allSatisfy(\.isNumber) else { return }
            config = c
            seed = snapshot.seed
            accumulatedMs = snapshot.elapsedMs
            seconds = Int(accumulatedMs / 1000)
            state = .cards(CardsState(
                deck: deck, index: snapshot.index, input: snapshot.input, attempt: snapshot.attempt,
                feedback: snapshot.attempt == 2 ? .nudge : .none,
                correct: snapshot.correct, name: c.name, maxDigits: c.maxDigits
            ))
            timing = true
            resumeClock()
        }
    }
}
