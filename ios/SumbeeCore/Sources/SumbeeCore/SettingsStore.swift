import Foundation

/// The last-used Setup, remembered between runs (SPEC.md FR-1.6). Nothing else is ever stored.
@MainActor
public protocol SettingsStore: AnyObject {
    func load() -> SessionConfig
    func save(_ config: SessionConfig)
}

/// `SettingsStore` on `UserDefaults`, on the device only (IMPLEMENTATION.md §4.3).
@MainActor
public final class UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SessionConfig {
        let base = SessionConfig()
        return SessionConfig(
            name: defaults.string(forKey: Keys.name) ?? base.name,
            maxNumber: defaults.object(forKey: Keys.max) as? Int ?? base.maxNumber,
            ops: (defaults.stringArray(forKey: Keys.ops)?.compactMap(MathOperation.init(rawValue:))).map(Set.init) ?? base.ops,
            cardCount: defaults.object(forKey: Keys.count) as? Int ?? base.cardCount
        ).sanitized()
    }

    public func save(_ config: SessionConfig) {
        defaults.set(config.name, forKey: Keys.name)
        defaults.set(config.maxNumber, forKey: Keys.max)
        defaults.set(config.ops.map(\.rawValue).sorted(), forKey: Keys.ops)
        defaults.set(config.cardCount, forKey: Keys.count)
    }

    private enum Keys {
        static let name = "name"
        static let max = "max"
        static let ops = "ops"
        static let count = "count"
    }
}
