import Foundation

/// The last-used Setup, remembered between runs (SPEC.md FR-1.6). Nothing else is ever stored.
@MainActor
public protocol SettingsStore: AnyObject {
    func load() -> SessionConfig
    func save(_ config: SessionConfig)
}

/// `SettingsStore` as a small JSON file, on the device only (IMPLEMENTATION.md §4.3, §8).
///
/// Not `UserDefaults`: iOS copies those to iCloud and computer backups, and the child's name must not
/// leave the device (VISION.md §6). Its folder is marked excluded from backup, the iOS counterpart
/// of Android's `allowBackup="false"`. The folder rather than the file, because an atomic write
/// replaces the file and would drop a mark set on it.
@MainActor
public final class FileSettingsStore: SettingsStore {
    private let directory: URL

    private var file: URL { directory.appendingPathComponent("settings.json") }

    public init(directory: URL = URL.applicationSupportDirectory.appendingPathComponent("Sumbee", isDirectory: true)) {
        self.directory = directory
    }

    public func load() -> SessionConfig {
        guard let data = try? Data(contentsOf: file),
              let config = try? JSONDecoder().decode(SessionConfig.self, from: data) else { return SessionConfig() }
        return config.sanitized()
    }

    public func save(_ config: SessionConfig) {
        // Remembering settings only saves taps, so a failed save just means the defaults next time.
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var dir = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        try? JSONEncoder().encode(config).write(to: file, options: .atomic)
    }

    /// Forgets everything, as a fresh install would. For UI tests.
    public func reset() {
        try? FileManager.default.removeItem(at: directory)
    }
}
