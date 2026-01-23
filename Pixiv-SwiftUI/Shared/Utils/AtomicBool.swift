import Foundation

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
final class AtomicBool: @unchecked Sendable {
    private final class Box: @unchecked Sendable {
        nonisolated(unsafe) var value: Bool
        init(_ value: Bool) { self.value = value }
    }
    private let box: Box
    private let lock = NSLock()

    init(_ value: Bool = false) {
        box = Box(value)
    }

    @discardableResult
    nonisolated func compareAndSwap(expected: Bool, desired: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if box.value == expected {
            box.value = desired
            return true
        }
        return false
    }

    nonisolated var isTrue: Bool {
        lock.lock()
        defer { lock.unlock() }
        return box.value
    }
}
