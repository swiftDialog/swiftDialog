//
//  FileMonitorTests.swift
//
//  FSEvents detection with `FileMonitor` constructed directly, so no `InspectState` poller can mask
//  a dead stream. All paths are under /private/tmp: /tmp is a symlink and FSEvents reports resolved paths.
//

import XCTest
@testable import Dialog

private final class MonitorSpy: FileMonitorDelegate {
    // The debounced status check can land off main, so every access takes the lock.
    private let lock = NSLock()
    private var _installed: [String] = []
    private var _removed: [String] = []
    private var _downloaded: [String] = []

    var installed: [String] { lock.lock(); defer { lock.unlock() }; return _installed }
    var removed: [String] { lock.lock(); defer { lock.unlock() }; return _removed }
    var downloaded: [String] { lock.lock(); defer { lock.unlock() }; return _downloaded }

    /// Fulfilled on any callback, so tests wait for arrival, not a duration.
    var onEvent: (() -> Void)?

    func fileMonitor(_ m: FileMonitor, didDetectInstallation itemId: String, at path: String) {
        lock.lock(); _installed.append(itemId); lock.unlock(); onEvent?()
    }
    func fileMonitor(_ m: FileMonitor, didDetectRemoval itemId: String, at path: String) {
        lock.lock(); _removed.append(itemId); lock.unlock(); onEvent?()
    }
    func fileMonitor(_ m: FileMonitor, didDetectDownload itemId: String, at path: String) {
        lock.lock(); _downloaded.append(itemId); lock.unlock(); onEvent?()
    }
    func fileMonitorDidDetectChanges(_ m: FileMonitor) {}
}

/// Callbacks arrive on `callbackQueue`, which `setUp` moves off main.
@MainActor
final class FileMonitorTests: XCTestCase {

    private var sandbox: URL!
    private var monitor: FileMonitor!
    private var spy: MonitorSpy!

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: "/private/tmp")
            .appendingPathComponent("dialog-fsevents-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        monitor = FileMonitor()
        // Off main: under full-suite load a main-queue hop would deadlock against the running suite.
        monitor.callbackQueue = DispatchQueue(label: "tests.filemonitor.callbacks")
        spy = MonitorSpy()
        monitor.delegate = spy
    }

    override func tearDownWithError() throws {
        monitor.stopMonitoring()
        try? FileManager.default.removeItem(at: sandbox)
    }

    private func item(id: String, name: String, paths: [String]) throws -> InspectConfig.ItemConfig {
        // Interpolating a [String] would escape the quotes and produce a path nothing matches.
        let quoted = paths.map { "\"\($0)\"" }.joined(separator: ", ")
        let json = """
        {"id": "\(id)", "displayName": "\(name)", "paths": [\(quoted)]}
        """
        return try JSONDecoder().decode(InspectConfig.ItemConfig.self, from: Data(json.utf8))
    }

    /// A liveness probe item in every monitored set; never asserted on.
    private let probeItemId = "__stream-probe"

    /// Starts monitoring and returns only once the stream has delivered an event for the probe item.
    /// FSEventStreamStart is not live synchronously, so mutations issued earlier would be lost.
    private func startLive(items: [InspectConfig.ItemConfig],
                           cachePaths: [String] = [],
                           cacheExtensions: [String]? = nil) throws {
        let probePath = sandbox.appendingPathComponent("stream-liveness.probe").path
        let probe = try item(id: probeItemId, name: "Stream probe", paths: [probePath])
        monitor.startMonitoring(items: items + [probe],
                                cachePaths: cachePaths, cacheExtensions: cacheExtensions)

        // Wait through XCTest: callbacks go to `callbackQueue`, not this thread's runloop.
        let live = expectation(description: "FSEvents stream live")
        let lock = NSLock()
        var fired = false
        let previousOnEvent = spy.onEvent
        spy.onEvent = { [weak spy, probeItemId] in
            lock.lock(); defer { lock.unlock() }
            if !fired, spy?.installed.contains(probeItemId) == true { fired = true; live.fulfill() }
        }
        // Re-touch the probe slower than the 0.5s debounce, which restarts on every event.
        let ticker = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        ticker.schedule(deadline: .now(), repeating: 1.2)
        ticker.setEventHandler {
            FileManager.default.createFile(atPath: probePath, contents: Data())
        }
        ticker.resume()
        defer { ticker.cancel(); spy.onEvent = previousOnEvent }
        wait(for: [live], timeout: 20)
    }

    /// Waits for arrival with a generous ceiling; never asserts on latency.
    private func waitForEvent(_ predicate: @escaping () -> Bool, _ label: String) {
        let done = expectation(description: label)
        let guardLock = NSLock()
        var fulfilled = false
        spy.onEvent = {
            guardLock.lock(); defer { guardLock.unlock() }
            if !fulfilled, predicate() { fulfilled = true; done.fulfill() }
        }
        guardLock.lock()
        if !fulfilled, predicate() { fulfilled = true; done.fulfill() }
        guardLock.unlock()
        wait(for: [done], timeout: 5.0)
    }

    /// A removal fires.
    func testARemovalFires() throws {
        let app = sandbox.appendingPathComponent("Obsidian.app").path
        let it = try item(id: "obsidian", name: "Obsidian", paths: [app])
        try startLive(items: [it])

        // Wait for the creation to be reported before deleting: FSEvents coalesces per path within one latency window.
        FileManager.default.createFile(atPath: app, contents: Data())
        waitForEvent({ [spy] in spy!.installed.contains("obsidian") }, "installed first")

        try FileManager.default.removeItem(atPath: app)
        waitForEvent({ [spy] in spy!.removed.contains("obsidian") }, "removal")
        XCTAssertTrue(spy.removed.contains("obsidian"))
    }

    func testAnInstallationFires() throws {
        let app = sandbox.appendingPathComponent("Slack.app").path
        let it = try item(id: "slack", name: "Slack", paths: [app])
        try startLive(items: [it])

        FileManager.default.createFile(atPath: app, contents: Data())
        waitForEvent({ [spy] in spy!.installed.contains("slack") }, "installation")
        XCTAssertTrue(spy.installed.contains("slack"))
    }

    /// A package in a watched cache directory, with the installed path absent, fires a download.
    func testADownloadFires() throws {
        let cache = sandbox.appendingPathComponent("Cache")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let it = try item(id: "obsidian", name: "Obsidian",
                          paths: [sandbox.appendingPathComponent("Obsidian.app").path])
        try startLive(items: [it], cachePaths: [cache.path], cacheExtensions: [".pkg"])

        FileManager.default.createFile(atPath: cache.appendingPathComponent("Obsidian.pkg").path,
                                       contents: Data())
        waitForEvent({ [spy] in !spy!.downloaded.isEmpty }, "download")
        XCTAssertFalse(spy.downloaded.isEmpty)
    }

    /// With several items watched, each event names the right item.
    func testTheRightItemIsNamed() throws {
        let a = sandbox.appendingPathComponent("Alpha.app").path
        let b = sandbox.appendingPathComponent("Beta.app").path
        let items = [try item(id: "alpha", name: "Alpha", paths: [a]),
                     try item(id: "beta", name: "Beta", paths: [b])]
        try startLive(items: items)

        FileManager.default.createFile(atPath: a, contents: Data())
        FileManager.default.createFile(atPath: b, contents: Data())
        waitForEvent({ [spy] in spy!.installed.contains("beta") }, "beta installed first")

        try FileManager.default.removeItem(atPath: b)
        waitForEvent({ [spy] in spy!.removed.contains("beta") }, "beta removed")
        XCTAssertTrue(spy.removed.contains("beta"))
        XCTAssertFalse(spy.removed.contains("alpha"), "alpha was untouched and must not be reported")
    }

    /// An item authored under /tmp still resolves when FSEvents reports /private/tmp.
    func testAnItemAuthoredUnderTmpStillResolves() throws {
        let short = "/tmp/" + sandbox.lastPathComponent + "/Resolved.app"
        let real = sandbox.appendingPathComponent("Resolved.app").path
        let it = try item(id: "resolved", name: "Resolved", paths: [short])
        try startLive(items: [it])

        FileManager.default.createFile(atPath: real, contents: Data())
        waitForEvent({ [spy] in spy!.installed.contains("resolved") }, "resolved installed first")

        try FileManager.default.removeItem(atPath: real)
        waitForEvent({ [spy] in spy!.removed.contains("resolved") }, "resolved removal")
        XCTAssertTrue(spy.removed.contains("resolved"),
                      "an item authored under /tmp must still map when the event arrives as /private/tmp")
    }
}

// MARK: - Debouncer

extension FileMonitorTests {
    /// A debounced event that has run leaves no entry behind.
    func testADebouncedEventThatRanLeavesNoEntry() {
        let debouncer = EventDebouncer()
        let ran = expectation(description: "both ran")
        ran.expectedFulfillmentCount = 2
        debouncer.debounce(key: "/a", delay: 0.01) { ran.fulfill() }
        debouncer.debounce(key: "/b", delay: 0.01) { ran.fulfill() }
        wait(for: [ran], timeout: 2)
        let drained = expectation(for: NSPredicate { _, _ in debouncer.pendingCount == 0 }, evaluatedWith: nil)
        wait(for: [drained], timeout: 2)
    }
}
