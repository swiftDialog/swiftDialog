//
//  LockedValue.swift
//  dialog
//

import Synchronization

/// One value behind a `Mutex`, for statics read and written from any thread. `Sendable` by
/// construction; a read-modify-write that must be atomic goes through `withLock`.
final class LockedValue<Value: Sendable>: Sendable {
    private let storage: Mutex<Value>

    init(_ value: Value) { storage = Mutex(value) }

    var value: Value {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }

    @discardableResult
    func withLock<Result: Sendable>(_ body: (inout Value) -> Result) -> Result {
        storage.withLock { body(&$0) }
    }
}
