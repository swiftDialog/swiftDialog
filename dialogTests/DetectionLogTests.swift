//
//  DetectionLogTests.swift
//  dialogTests
//
//  The detection log and the receipt census.
//

import XCTest
import SwiftUI
import Synchronization
@testable import Dialog

// MARK: - Which engine acted

/// Several engines feed the same item state; the detection log names which one acted, so a dead
/// engine cannot hide behind a live one. Env-gated.
final class DetectionLogTests: XCTestCase {

    /// Off unless a harness asks.
    func testTheChannelIsOffByDefault() {
        XCTAssertNil(DetectionLog.destination(in: [:]))
        XCTAssertNil(DetectionLog.destination(in: [DetectionLog.variable: ""]))
        XCTAssertEqual(DetectionLog.destination(in: [DetectionLog.variable: "/tmp/d.log"]), "/tmp/d.log")
    }

    /// One line per transition, naming the engine.
    func testTheLineNamesTheEngine() {
        let at = Date(timeIntervalSince1970: 0)
        let line = DetectionLog.line(itemId: "obsidian", from: "completed", to: "pending",
                                     by: .fsevents, at: at)
        XCTAssertTrue(line.contains("obsidian"))
        XCTAssertTrue(line.contains("completed -> pending"))
        XCTAssertTrue(line.hasSuffix("by=fsevents"))
    }

    /// Every engine has a word.
    func testEveryEngineHasAWord() {
        XCTAssertEqual(DetectionEngine.fsevents.rawValue, "fsevents")
        XCTAssertEqual(DetectionEngine.poller.rawValue, "poller")
        XCTAssertEqual(DetectionEngine.logmonitor.rawValue, "logmonitor")
        XCTAssertEqual(DetectionEngine.command.rawValue, "command")
        XCTAssertEqual(DetectionEngine.requirements.rawValue, "requirements")
    }

    /// The panel counts the requirement engine as a source.
    func testTheMeterKnowsTheRequirementsSource() {
        XCTAssertTrue(InspectDebugMeter.knownSources.contains("requirements"))
    }

    /// The trace names the evidence: a pkgId answerable against /var/db/receipts.
    func testEvidenceNamesTheReceipt() throws {
        let json = #"[{"type":"receipt","pkgId":"com.example.setup.DEMO2"},{"type":"path","paths":["/Applications/A.app","/Applications/B.app"]},{"type":"app","bundleId":"com.x.y","negate":true}]"#
        let reqs = try JSONDecoder().decode([InspectConfig.ItemConfig.Requirement].self, from: json.data(using: .utf8)!)
        XCTAssertEqual(DetectionLog.evidence(reqs[0]), "receipt com.example.setup.DEMO2")
        XCTAssertEqual(DetectionLog.evidence(reqs[1]), "path /Applications/A.app|/Applications/B.app")
        XCTAssertEqual(DetectionLog.evidence(reqs[2]), "not app com.x.y")
    }

    // MARK: - pollerWords

    // The poller's words derive from its four flags. Each case below is one real
    // `checkDirectInstallationStatus` path.

    /// Installed, never completed, never downloaded: pending -> completed.
    func testFreshInstallSaysPendingToCompleted() {
        let words = DetectionLog.pollerWords(wasCompleted: false, wasDownloading: false,
                                             isInstalled: true, isDownloading: false)
        XCTAssertEqual(words.from, "pending")
        XCTAssertEqual(words.to, "completed")
    }

    /// Installed after downloading: downloading -> completed.
    func testDownloadCompletingSaysDownloadingToCompleted() {
        let words = DetectionLog.pollerWords(wasCompleted: false, wasDownloading: true,
                                             isInstalled: true, isDownloading: false)
        XCTAssertEqual(words.from, "downloading")
        XCTAssertEqual(words.to, "completed")
    }

    /// A completed app gone and not re-caching: completed -> pending.
    func testInstalledItemRemovedSaysCompletedToPending() {
        let words = DetectionLog.pollerWords(wasCompleted: true, wasDownloading: false,
                                             isInstalled: false, isDownloading: false)
        XCTAssertEqual(words.from, "completed")
        XCTAssertEqual(words.to, "pending")
    }

    /// A completed app gone while a new copy caches: completed -> downloading.
    func testItemRemovedWhileStillDownloadingSaysCompletedToDownloading() {
        let words = DetectionLog.pollerWords(wasCompleted: true, wasDownloading: false,
                                             isInstalled: false, isDownloading: true)
        XCTAssertEqual(words.from, "completed")
        XCTAssertEqual(words.to, "downloading")
    }

    /// A cache file appears for a pending item: pending -> downloading.
    func testDownloadStartingSaysPendingToDownloading() {
        let words = DetectionLog.pollerWords(wasCompleted: false, wasDownloading: false,
                                             isInstalled: false, isDownloading: true)
        XCTAssertEqual(words.from, "pending")
        XCTAssertEqual(words.to, "downloading")
    }

    /// The cache file is gone and the item never installed: downloading -> pending.
    func testDownloadAbandonedSaysDownloadingToPending() {
        let words = DetectionLog.pollerWords(wasCompleted: false, wasDownloading: true,
                                             isInstalled: false, isDownloading: false)
        XCTAssertEqual(words.from, "downloading")
        XCTAssertEqual(words.to, "pending")
    }
}

// MARK: - Receipt census

/// Division mode is paced by a count of package receipts on disk. These pin what counts as a
/// receipt, what the baseline excludes, and the clamp.
final class ReceiptCensusTests: XCTestCase {

    private func scratch() throws -> String {
        let dir = NSTemporaryDirectory() + "receipt-census-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    /// `.plist` and `.bom` are one receipt; other files are not receipts.
    func testAReceiptIsOnePackageWhateverItsFiles() throws {
        let dir = try scratch()
        for name in ["com.a.pkg.plist", "com.a.pkg.bom", "com.b.pkg.bom", "notes.txt", ".DS_Store"] {
            FileManager.default.createFile(atPath: dir + "/" + name, contents: Data())
        }
        XCTAssertEqual(ReceiptCensus.identifiers(in: dir), ["com.a.pkg", "com.b.pkg"])
    }

    /// A missing directory is an empty census.
    func testAMissingDirectoryIsEmpty() {
        XCTAssertEqual(ReceiptCensus.identifiers(in: "/nonexistent/receipts-\(UUID().uuidString)"), [])
    }

    /// A multi-package install is one item: its component receipts land in the same second, separate installs well apart.
    func testAMultiPackageInstallIsOneItem() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        func r(_ id: String, _ offset: TimeInterval) -> ReceiptCensus.Receipt {
            ReceiptCensus.Receipt(id: id, writtenAt: t0.addingTimeInterval(offset))
        }
        let baseline: Set<String> = ["com.fleetdm.orbit.base.pkg"]
        // Two component receipts in the same second: one item.
        XCTAssertEqual(ReceiptCensus.newInstalls(now: [r("com.microsoft.teams2", 0), r("com.microsoft.MSTeamsAudioDevice", 0)],
                                                 baseline: baseline, total: 20), 1)
        // Three multi-package installs of three receipts each, 40 s apart, plus one plain one.
        var now: Set<ReceiptCensus.Receipt> = []
        for k in 0..<3 { for c in 0..<3 { now.insert(r("multi\(k).comp\(c)", Double(k) * 40 + Double(c) * 0.5)) } }
        now.insert(r("plain", 160))
        XCTAssertEqual(ReceiptCensus.newInstalls(now: now, baseline: baseline, total: 20), 4)
        // The baseline's ids never count.
        now.insert(r("com.fleetdm.orbit.base.pkg", 200))
        XCTAssertEqual(ReceiptCensus.newInstalls(now: now, baseline: baseline, total: 20), 4)
        // The clamp still holds.
        XCTAssertEqual(ReceiptCensus.newInstalls(now: now, baseline: baseline, total: 2), 2)
        // Exactly at the window is the same install; just past it is the next.
        XCTAssertEqual(ReceiptCensus.newInstalls(now: [r("a", 0), r("b", ReceiptCensus.clusterWindow)], baseline: [], total: 9), 1)
        XCTAssertEqual(ReceiptCensus.newInstalls(now: [r("a", 0), r("b", ReceiptCensus.clusterWindow + 0.01)], baseline: [], total: 9), 2)
    }

    /// `receiptCensus` is a known root key, and the engine has its word.
    func testReceiptCensusIsARootKeyWithAnEngineWord() throws {
        XCTAssertTrue(InspectConfig.knownRootKeys.contains("receiptCensus"))
        let json = Data(#"{"preset":"5","introSteps":[],"receiptCensus":true}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(InspectConfig.self, from: json).receiptCensus, true)
        XCTAssertEqual(DetectionEngine.census.rawValue, "census")
        XCTAssertTrue(InspectDebugMeter.knownSources.contains("census"))
    }
}
