import Foundation

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
final class AtomicBool: @unchecked Sendable {
    private let valuePtr: UnsafeMutablePointer<Bool>
    private let lock = NSLock()

    init(_ value: Bool = false) {
        valuePtr = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        valuePtr.pointee = value
    }

    deinit {
        valuePtr.deallocate()
    }

    nonisolated func compareAndSwap(expected: Bool, desired: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if valuePtr.pointee == expected {
            valuePtr.pointee = desired
            return true
        }
        return false
    }

    nonisolated var isTrue: Bool {
        lock.lock()
        defer { lock.unlock() }
        return valuePtr.pointee
    }
}
