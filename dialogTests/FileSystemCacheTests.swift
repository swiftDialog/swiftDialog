//
//  FileSystemCacheTests.swift
//  dialogTests
//
//  Unit tests for FileSystemCache (backlog M5, Tier 2). Uses real temp
//  directories as fixtures.
//

import XCTest
@testable import Dialog

final class FileSystemCacheTests: XCTestCase {

    private var tempDirs: [String] = []

    override func tearDownWithError() throws {
        for dir in tempDirs { try? FileManager.default.removeItem(atPath: dir) }
        tempDirs = []
    }

    /// Create a temp directory containing `files`, returning its path.
    private func makeTempDir(files: [String] = []) throws -> String {
        let dir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("fscache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for file in files {
            FileManager.default.createFile(atPath: (dir as NSString).appendingPathComponent(file),
                                           contents: Data("x".utf8))
        }
        tempDirs.append(dir)
        return dir
    }

    func testCacheThenRetrieveIsAHit() throws {
        let cache = FileSystemCache()
        let dir = try makeTempDir(files: ["a.txt", "b.txt"])

        XCTAssertEqual(Set(cache.cacheDirectoryContents(dir)), ["a.txt", "b.txt"])
        // Subsequent read is served from cache.
        XCTAssertEqual(cache.getCachedDirectoryContents(dir).map(Set.init), ["a.txt", "b.txt"])

        let stats = cache.getStatistics()
        XCTAssertEqual(stats.entries, 1)
        XCTAssertEqual(stats.accessiblePaths, 1)
        XCTAssertGreaterThan(stats.memoryUsage, 0)
    }

    func testMissBeforeCaching() throws {
        let cache = FileSystemCache()
        let dir = try makeTempDir(files: ["a.txt"])
        XCTAssertNil(cache.getCachedDirectoryContents(dir), "Nothing cached yet")
    }

    func testInaccessiblePathReturnsEmptyAndIsMarked() {
        let cache = FileSystemCache()
        let missing = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("missing-\(UUID().uuidString)")
        XCTAssertTrue(cache.cacheDirectoryContents(missing).isEmpty)
        XCTAssertNil(cache.getCachedDirectoryContents(missing), "Known-inaccessible path returns nil")
        XCTAssertEqual(cache.getStatistics().inaccessiblePaths, 1)
    }

    func testEvictionBoundsEntryCount() throws {
        let cache = FileSystemCache(maxCacheEntries: 2)
        cache.cacheDirectoryContents(try makeTempDir(files: ["1"]))
        cache.cacheDirectoryContents(try makeTempDir(files: ["2"]))
        cache.cacheDirectoryContents(try makeTempDir(files: ["3"]))  // evicts the oldest
        XCTAssertLessThanOrEqual(cache.getStatistics().entries, 2)
    }

    func testInvalidateCacheRemovesEntryAndMemory() throws {
        let cache = FileSystemCache()
        let dir = try makeTempDir(files: ["a"])
        cache.cacheDirectoryContents(dir)
        XCTAssertEqual(cache.getStatistics().entries, 1)

        cache.invalidateCache(for: dir)
        let stats = cache.getStatistics()
        XCTAssertEqual(stats.entries, 0)
        XCTAssertEqual(stats.memoryUsage, 0)
    }

    func testInvalidateAll() throws {
        let cache = FileSystemCache()
        cache.cacheDirectoryContents(try makeTempDir(files: ["a"]))
        cache.cacheDirectoryContents(try makeTempDir(files: ["b"]))
        XCTAssertEqual(cache.getStatistics().entries, 2)

        cache.invalidateAll()
        let stats = cache.getStatistics()
        XCTAssertEqual(stats.entries, 0)
        XCTAssertEqual(stats.memoryUsage, 0)
    }

    func testContainsMatchingFile() throws {
        let cache = FileSystemCache()
        let dir = try makeTempDir(files: ["report.pdf", "notes.txt"])
        XCTAssertTrue(cache.containsMatchingFile(in: dir) { $0.hasSuffix(".pdf") })
        XCTAssertFalse(cache.containsMatchingFile(in: dir) { $0.hasSuffix(".zip") })
    }
}
