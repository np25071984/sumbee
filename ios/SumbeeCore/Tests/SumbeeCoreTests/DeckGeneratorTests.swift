import Foundation
import Testing
@testable import SumbeeCore

typealias Relaxation = DeckGenerator.Relaxation

/// SPEC.md FR-2, over the matrix IMPLEMENTATION.md §5 names.
struct DeckGeneratorTests {

    private let ranges = [5, 10, 15, 20, 50, 100]
    private let counts = SessionConfig.cardCounts
    private let opSets: [Set<MathOperation>] = (1..<16).map { mask in
        Set(MathOperation.allCases.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element))
    }

    private func deal(_ config: SessionConfig, seed: UInt64) -> DeckGenerator.Deck {
        var random = SeededRandom(seed: seed)
        return DeckGenerator.generate(config, using: &random)
    }

    @Test func everyDeckHonoursTheRulesItsRelaxationLevelPromises() {
        var decks = 0
        for n in ranges { for ops in opSets { for count in counts {
            let seeds: UInt64 = n == 100 ? 3 : 8
            for seed in 0..<seeds {
                let config = SessionConfig(maxNumber: n, ops: ops, cardCount: count)
                checkDeck(config, deal(config, seed: seed), "n=\(n) ops=\(ops.map(\.symbol).sorted()) count=\(count) seed=\(seed)")
                decks += 1
            }
        } } }
        #expect(decks > 1000)
    }

    private func checkDeck(_ config: SessionConfig, _ deck: DeckGenerator.Deck, _ what: String) {
        let cards = deck.cards
        let n = config.maxNumber
        #expect(cards.count == config.cardCount, "size \(what)")

        // FR-2.1–2.3: never relaxed.
        for c in cards {
            #expect(config.ops.contains(c.op), "op \(c) \(what)")
            switch c.op {
            case .plus, .times:
                #expect((0...n).contains(c.a) && (0...n).contains(c.b), "bounds \(c) \(what)")
            case .minus:
                #expect((0...n).contains(c.a) && (0...c.a).contains(c.b), "bounds \(c) \(what)")
            case .divide:
                #expect((1...n).contains(c.b), "divisor \(c) \(what)")
                #expect(c.a % c.b == 0, "whole \(c) \(what)")
                #expect((0...n).contains(c.answer), "quotient \(c) \(what)")
            }
            #expect(c.answer >= 0, "negative \(c) \(what)")
        }

        // FR-2.4: balance, and no run longer than 2 with two or more ops.
        let k = config.ops.count
        for op in config.ops {
            let times = cards.filter { $0.op == op }.count
            #expect(times == config.cardCount / k || times == (config.cardCount + k - 1) / k, "balance \(op)=\(times) \(what)")
        }
        if k >= 2 {
            for i in 2..<cards.count {
                #expect(!(cards[i].op == cards[i - 1].op && cards[i].op == cards[i - 2].op), "run at \(i) \(what)")
            }
        }

        // Never the same card twice in a row, at any level.
        for i in 1..<cards.count {
            #expect(cards[i - 1].canonical() != cards[i].canonical(), "back-to-back at \(i) \(what)")
        }

        if deck.relaxation < .repeats {
            #expect(Set(cards.map { $0.canonical() }).count == cards.count, "repeat \(what)")
        }
        if deck.relaxation < .noTrivialLimit {
            let budget = max(1, config.cardCount / 10)
            #expect(cards.filter(\.isTrivial).count <= budget, "trivial budget \(what)")
            for i in 1..<cards.count {
                #expect(!(cards[i].isTrivial && cards[i - 1].isTrivial), "trivial pair \(i) \(what)")
            }
        }
        let window = switch deck.relaxation {
        case .none: 3
        case .shortWindow: 1
        default: 0
        }
        for i in cards.indices {
            for j in max(0, i - window)..<i {
                #expect(!cards[i].isNear(to: cards[j]), "near \(cards[j]) → \(cards[i]) \(what)")
            }
        }
    }

    @Test func ordinaryDecksNeedNoRelaxation() {
        for seed in UInt64(0)..<50 {
            for config in [
                SessionConfig(maxNumber: 20, ops: [.plus], cardCount: 25),
                SessionConfig(maxNumber: 20, ops: [.plus, .minus], cardCount: 50),
                SessionConfig(maxNumber: 50, ops: Set(MathOperation.allCases), cardCount: 100),
            ] {
                #expect(deal(config, seed: seed).relaxation == .none, "\(config) seed=\(seed)")
            }
        }
    }

    @Test func tinyPoolsStillFillTheDeck() {
        // Only 66 distinct + cards exist up to 10 (FR-2.8's example).
        let deck = deal(SessionConfig(maxNumber: 10, ops: [.plus], cardCount: 100), seed: 7)
        #expect(deck.cards.count == 100)
        #expect(deck.relaxation >= .repeats)
    }

    @Test func smallestRangeFillsEveryDeck() {
        // N = 5 is "sums up to 10": only 21 distinct + or × cards, and most × cards are trivial.
        for op in MathOperation.allCases {
            for count in counts {
                let config = SessionConfig(maxNumber: 5, ops: [op], cardCount: count)
                #expect(deal(config, seed: 3).cards.count == count, "\(op) \(count)")
            }
        }
    }

    @Test func sameSeedSameDeck() {
        let config = SessionConfig(maxNumber: 30, ops: Set(MathOperation.allCases), cardCount: 75)
        #expect(deal(config, seed: 99) == deal(config, seed: 99))
        #expect(deal(config, seed: 99) != deal(config, seed: 100))
    }

    @Test func nearNeighboursMatchTheSpecExamples() {
        func plus(_ a: Int, _ b: Int) -> Card { Card(.plus, a, b) }
        #expect(plus(6, 4).isNear(to: plus(6, 5)))
        #expect(plus(6, 4).isNear(to: plus(7, 3)))
        #expect(plus(6, 4).isNear(to: plus(5, 7)))
        #expect(!plus(6, 4).isNear(to: plus(13, 7)))
        #expect(!plus(6, 4).isNear(to: Card(.times, 6, 5)))
        // ÷ compares divisor with divisor and quotient with quotient.
        #expect(Card(.divide, 24, 6).isNear(to: Card(.divide, 35, 7)))
        #expect(!Card(.divide, 24, 6).isNear(to: Card(.divide, 90, 9)))
    }

    @Test func trivialCardsMatchTheSpecList() {
        let trivial = [
            Card(.times, 7, 0), Card(.times, 1, 9), Card(.plus, 0, 5),
            Card(.minus, 8, 0), Card(.minus, 6, 6), Card(.divide, 9, 1),
            Card(.divide, 7, 7), Card(.divide, 0, 4),
        ]
        for c in trivial { #expect(c.isTrivial, "\(c)") }
        for c in [Card(.times, 2, 3), Card(.minus, 9, 4), Card(.divide, 12, 3)] { #expect(!c.isTrivial, "\(c)") }
    }

    @Test func largestDeckIsQuick() {
        // FR-7 budgets 50 ms on a low-end phone. A debug build here is unoptimized, so allow it more.
        let config = SessionConfig(maxNumber: 100, ops: Set(MathOperation.allCases), cardCount: 100)
        for seed in UInt64(0)..<5 { _ = deal(config, seed: seed) } // warm up
        let start = ContinuousClock.now
        for seed in UInt64(100)..<120 { _ = deal(config, seed: seed) }
        let avg = (ContinuousClock.now - start) / 20
        #if DEBUG
        let limit = Duration.milliseconds(200)
        #else
        let limit = Duration.milliseconds(20)
        #endif
        #expect(avg < limit, "average \(avg)")
    }

    @Test func configSanitizing() {
        let wild = SessionConfig(name: "  Zoë-Ann 2 O’Neil!!  ", maxNumber: 103, ops: [], cardCount: 30).sanitized()
        #expect(wild == SessionConfig(name: "Zoë-Ann  O’Neil", maxNumber: 100, ops: [.plus], cardCount: 25))
        #expect(SessionConfig(maxNumber: 2).sanitized().maxNumber == 5)
        #expect(SessionConfig(maxNumber: 37).sanitized().maxNumber == 35)
        #expect(SessionConfig.filterName(String(repeating: "a", count: 30)).count == 20)
        #expect(SessionConfig(maxNumber: 20, ops: [.plus]).maxDigits == 2)
        #expect(SessionConfig(maxNumber: 20, ops: [.plus, .times]).maxDigits == 3)
        #expect(SessionConfig(maxNumber: 100, ops: [.times]).maxDigits == 5)
    }
}
