//
//  ImageResolverCacheTests.swift
//  dialogTests
//

import XCTest
@testable import Dialog

/// A relative image path resolves against its base path; the cache keys on the base path too.
final class ImageResolverCacheTests: XCTestCase {
    func testTheSameRelativeNameUnderTwoBasePathsResolvesToTwoFiles() throws {
        let fm = FileManager.default
        let root = NSTemporaryDirectory() + "image-resolver-\(UUID().uuidString)"
        let a = root + "/a", b = root + "/b"
        try fm.createDirectory(atPath: a, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: b, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: root) }
        fm.createFile(atPath: a + "/logo-probe.png", contents: Data([0]))
        fm.createFile(atPath: b + "/logo-probe.png", contents: Data([0]))

        let resolver = ImageResolver.shared
        resolver.clearCache()
        defer { resolver.clearCache() }
        XCTAssertEqual(resolver.resolveImagePath("logo-probe.png", basePath: a), a + "/logo-probe.png")
        XCTAssertEqual(resolver.resolveImagePath("logo-probe.png", basePath: b), b + "/logo-probe.png",
                       "the second base path must not get the first one's cached answer")
    }
}
