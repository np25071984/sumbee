import Foundation
import Testing
@testable import SumbeeCore

/// Time that only moves when a test says so.
@MainActor
final class TestScheduler: Scheduler {
    private struct Pending {
        let at: Int64
        let order: Int
        let action: @MainActor () -> Void
    }

    private(set) var now: Int64 = 0
    private var pending: [Int: Pending] = [:]
    private var nextId = 0

    func after(_ ms: Int64, _ action: @escaping @MainActor () -> Void) -> Scheduled {
        let id = nextId
        nextId += 1
        pending[id] = Pending(at: now + ms, order: id, action: action)
        return Scheduled { [weak self] in self?.pending[id] = nil }
    }

    /// Runs everything due up to `now + ms`, in time order, moving the clock as it goes.
    func advance(by ms: Int64) {
        let end = now + ms
        while let (id, next) = pending.filter({ $0.value.at <= end })
            .min(by: { ($0.value.at, $0.value.order) < ($1.value.at, $1.value.order) }) {
            pending[id] = nil
            now = next.at
            next.action()
        }
        now = end
    }
}

@MainActor
final class FakeStore: SettingsStore {
    var saved: SessionConfig

    init(_ initial: SessionConfig = SessionConfig()) {
        saved = initial
    }

    func load() -> SessionConfig { saved }

    func save(_ config: SessionConfig) { saved = config }
}

@MainActor
struct SessionModelTests {

    private let time = TestScheduler()

    private func model(
        _ store: FakeStore = FakeStore(SessionConfig(name: "Jenny", maxNumber: 20, cardCount: 25)),
        restoring snapshot: SessionSnapshot? = nil
    ) -> SessionModel {
        var seed: UInt64 = 41
        return SessionModel(settings: store, scheduler: time, restoring: snapshot, newSeed: { seed += 1; return seed })
    }

    private func type(_ m: SessionModel, _ n: Int) {
        for ch in String(n) { m.digit(ch.wholeNumberValue!) }
    }

    /// A wrong answer that still fits the keypad's digit limit.
    private func wrong(_ answer: Int) -> Int { answer == 0 ? 1 : answer - 1 }

    private func answerAllCorrectly(_ m: SessionModel) {
        while let s = m.cards {
            type(m, s.card.answer)
            m.submit()
            time.advance(by: SessionModel.correctMs + 1)
        }
    }

    @Test func setupShowsTheRememberedSettings() {
        #expect(model().setup?.name == "Jenny")
    }

    @Test func startSavesSettingsAndDealsTheDeck() {
        let store = FakeStore()
        let m = model(store)
        m.setName("Sam")
        m.toggleOp(.times)
        m.setCardCount(50)
        m.start()
        let s = m.cards!
        #expect(s.total == 50)
        #expect(s.index == 0)
        #expect(s.name == "Sam")
        #expect(store.saved == SessionConfig(name: "Sam", ops: [.plus, .times], cardCount: 50))
    }

    @Test func theLastOperationCannotBeTurnedOff() {
        let m = model()
        m.toggleOp(.plus)
        #expect(m.setup?.ops == [.plus])
    }

    @Test func correctAnswerMovesOn() {
        let m = model()
        m.start()
        type(m, m.cards!.card.answer)
        m.submit()
        #expect(m.cards?.feedback == .correct)
        time.advance(by: SessionModel.correctMs + 1)
        #expect(m.cards?.index == 1)
        #expect(m.cards?.correct == 1)
        #expect(m.cards?.input == "")
    }

    @Test func wrongThenRightCountsAsCorrect() {
        let m = model()
        m.start()
        let answer = m.cards!.card.answer
        type(m, wrong(answer))
        m.submit()
        #expect(m.cards?.feedback == .nudge)
        #expect(m.cards?.index == 0)
        m.delete(); m.delete(); m.delete()
        type(m, answer)
        m.submit()
        time.advance(by: SessionModel.correctMs + 1)
        #expect(m.cards?.index == 1)
        #expect(m.cards?.correct == 1)
    }

    @Test func wrongTwiceRevealsAndCountsWrong() {
        let m = model()
        m.start()
        let answer = m.cards!.card.answer
        type(m, wrong(answer))
        m.submit()
        m.submit() // unchanged answer, second attempt is final
        #expect(m.cards?.feedback == .reveal)
        m.digit(5) // ignored while the answer shows
        #expect(m.cards?.input == String(wrong(answer)))
        time.advance(by: SessionModel.revealMs + 1)
        #expect(m.cards?.index == 1)
        #expect(m.cards?.correct == 0)
    }

    @Test func inputStopsAtTheDigitLimit() {
        let m = model()
        m.start() // + up to 20: answers have at most 2 digits
        m.digit(1); m.digit(2); m.digit(3)
        #expect(m.cards?.input == "12")
        m.delete(); m.delete()
        m.digit(0); m.digit(7)
        #expect(m.cards?.input == "7")
    }

    @Test func emptyAnswerCannotBeSubmitted() {
        let m = model()
        m.start()
        m.submit()
        #expect(m.cards?.feedback == Feedback.none)
    }

    @Test func fullSessionEndsOnResults() {
        let m = model()
        m.start()
        answerAllCorrectly(m)
        #expect(m.state == .results(ResultsState(name: "Jenny", correct: 25, total: 25, elapsedMs: m.results!.elapsedMs)))
    }

    @Test func playAgainDealsANewDeckStraightAway() {
        let m = model()
        m.start()
        let first = m.cards!.deck
        answerAllCorrectly(m)
        time.advance(by: 30_000)
        m.playAgain()
        let s = m.cards!
        #expect(s.index == 0)
        #expect(s.correct == 0)
        #expect(s.name == "Jenny")
        #expect(s.total == 25)
        #expect(s.deck != first, "a different deck")
        #expect(m.seconds == 0, "the clock starts over")
    }

    @Test func playAgainOnlyWorksFromResults() {
        let m = model()
        m.playAgain()
        #expect(m.setup != nil)
    }

    @Test func oneTapShowsTheHintAndKeepsTheSession() {
        let m = model()
        m.start()
        m.digit(1)
        #expect(m.back())
        #expect(m.cards?.exitArmed == true)
        #expect(m.cards?.input == "1")
        time.advance(by: SessionModel.exitWindowMs + 1)
        #expect(m.cards?.exitArmed == false)
    }

    @Test func twoQuickTapsLeave() {
        let m = model()
        m.start()
        m.back()
        time.advance(by: 1000)
        m.back()
        #expect(m.setup != nil)
    }

    @Test func twoSlowTapsDoNotLeave() {
        let m = model()
        m.start()
        m.back()
        time.advance(by: 3000)
        m.back()
        #expect(m.cards?.exitArmed == true)
    }

    @Test func resultsGoStraightToSetup() {
        let m = model()
        m.start()
        answerAllCorrectly(m)
        #expect(m.back())
        #expect(m.setup != nil)
    }

    @Test func nothingToLeaveOnSetup() {
        #expect(!model().back())
    }

    @Test func clockPausesWhileHidden() {
        let m = model()
        m.start()
        time.advance(by: 5_000)
        m.onHidden()
        time.advance(by: 60_000)
        m.onVisible()
        time.advance(by: 5_000)
        #expect(m.seconds == 10)
    }

    @Test func clockStopsOnTheLastCard() {
        let m = model()
        m.start()
        time.advance(by: 4_500)
        answerAllCorrectly(m)
        let elapsed = m.results!.elapsedMs
        time.advance(by: 60_000)
        #expect(m.results?.elapsedMs == elapsed)
        #expect(elapsed == 4_500 + 24 * (SessionModel.correctMs + 1))
    }

    @Test func aSessionSurvivesTheAppBeingKilled() {
        let m = model()
        m.start()
        for _ in 0..<3 {
            type(m, m.cards!.card.answer)
            m.submit()
            time.advance(by: SessionModel.correctMs + 1)
        }
        let before = m.cards!
        type(m, wrong(before.card.answer))
        m.submit() // nudged
        m.onHidden()

        // A fresh launch gets back only what was saved, round-tripped as the app stores it.
        let saved = try! JSONDecoder().decode(SessionSnapshot.self, from: JSONEncoder().encode(m.snapshot!))
        let after = model(FakeStore(), restoring: saved).cards!
        #expect(after.index == before.index)
        #expect(after.card == before.card)
        #expect(after.deck == before.deck)
        #expect(after.correct == 3)
        #expect(after.attempt == 2)
        #expect(after.feedback == .nudge)
        #expect(after.input == String(wrong(before.card.answer)))
    }

    @Test func aDecidedCardIsSavedAsTheNextOne() {
        let m = model()
        m.start()
        type(m, m.cards!.card.answer)
        m.submit() // correct, not yet moved on
        let after = model(FakeStore(), restoring: m.snapshot).cards!
        #expect(after.index == 1)
        #expect(after.correct == 1)
        #expect(after.feedback == Feedback.none)
    }

    @Test func aSnapshotThatDoesNotAddUpOpensSetup() {
        var bad = SessionSnapshot(mode: .cards, config: SessionConfig(), seed: 1, index: 999)
        #expect(model(restoring: bad).setup != nil)
        bad = SessionSnapshot(mode: .results, config: SessionConfig(), correct: 5, total: 0)
        #expect(model(restoring: bad).setup != nil)
    }
}

extension SessionModel {
    var setup: SessionConfig? { if case .setup(let c) = state { c } else { nil } }
    var cards: CardsState? { if case .cards(let s) = state { s } else { nil } }
    var results: ResultsState? { if case .results(let r) = state { r } else { nil } }
}

@MainActor
struct SettingsStoreTests {

    @Test func settingsRoundTripAndSanitizeBadValues() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
        let store = UserDefaultsSettingsStore(defaults: defaults)
        #expect(store.load() == SessionConfig())

        let config = SessionConfig(name: "Zoë", maxNumber: 45, ops: [.minus, .divide], cardCount: 75)
        store.save(config)
        #expect(UserDefaultsSettingsStore(defaults: defaults).load() == config)

        defaults.set(7, forKey: "count")
        defaults.set(["NOPE"], forKey: "ops")
        #expect(store.load() == SessionConfig(name: "Zoë", maxNumber: 45, ops: [.plus], cardCount: 25))
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
    }
}
