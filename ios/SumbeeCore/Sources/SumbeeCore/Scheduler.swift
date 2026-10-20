/// Time, as the session sees it: a millisecond clock and delayed actions. Injected so tests can move
/// time by hand, the way the Kotlin tests use a test dispatcher (IMPLEMENTATION.md §3.4).
@MainActor
public protocol Scheduler: AnyObject {
    /// Milliseconds on a clock that only moves forward. Its zero means nothing.
    var now: Int64 { get }

    /// Runs `action` on the main actor after `ms` milliseconds, unless cancelled first.
    func after(_ ms: Int64, _ action: @escaping @MainActor () -> Void) -> Scheduled
}

/// A pending action from a `Scheduler`.
@MainActor
public final class Scheduled {
    private var onCancel: (() -> Void)?

    public init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel?()
        onCancel = nil
    }
}

/// The real clock: uptime and `Task.sleep`.
@MainActor
public final class TaskScheduler: Scheduler {
    private let clock = ContinuousClock()
    private let start: ContinuousClock.Instant

    public init() {
        start = clock.now
    }

    public var now: Int64 {
        let d = clock.now - start
        return d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000
    }

    public func after(_ ms: Int64, _ action: @escaping @MainActor () -> Void) -> Scheduled {
        let task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(ms))
            if !Task.isCancelled { action() }
        }
        return Scheduled { task.cancel() }
    }
}
