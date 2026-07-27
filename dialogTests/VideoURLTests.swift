//
//  VideoURLTests.swift
//  dialogTests
//
//  Unit tests for getVideoStreamingURLFromID (backlog M5, Tier 1).
//

import XCTest
@testable import Dialog

final class VideoURLTests: XCTestCase {

    // MARK: - YouTube

    func testYouTubeIDBuildsNoCookieEmbed() {
        let url = getVideoStreamingURLFromID(videoid: "youtubeid=dQw4w9WgXcQ")
        XCTAssertEqual(url,
            "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?enablejsapi=1&playsinline=1&rel=0")
    }

    func testYouTubeIDAutoplayAddsMutedAutoplay() {
        let url = getVideoStreamingURLFromID(videoid: "youtubeid=dQw4w9WgXcQ", autoplay: true)
        XCTAssertEqual(url,
            "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?enablejsapi=1&playsinline=1&rel=0&autoplay=1&mute=1")
    }

    // MARK: - Vimeo

    func testVimeoIDNoAutoplayUsesQuestionMarkSeparator() {
        let url = getVideoStreamingURLFromID(videoid: "vimeoid=123456")
        XCTAssertEqual(url, "https://player.vimeo.com/video/123456?autoplay=0&controls=1")
    }

    func testVimeoIDAutoplayHidesControls() {
        let url = getVideoStreamingURLFromID(videoid: "vimeoid=123456", autoplay: true)
        XCTAssertEqual(url, "https://player.vimeo.com/video/123456?autoplay=1&controls=0")
    }

    func testVimeoIDWithExistingQueryUsesAmpersandSeparator() {
        let url = getVideoStreamingURLFromID(videoid: "vimeoid=123456?h=abc")
        XCTAssertEqual(url, "https://player.vimeo.com/video/123456?h=abc&autoplay=0&controls=1")
    }

    // MARK: - Passthrough

    func testPlainURLReturnedUnchanged() {
        let plain = "https://example.com/movie.mp4"
        XCTAssertEqual(getVideoStreamingURLFromID(videoid: plain), plain)
    }

    // Note: the id prefix is matched case-insensitively (the switch lowercases it)
    // but stripped case-sensitively (replacingOccurrences of the lowercase literal),
    // so only the documented lowercase form "youtubeid="/"vimeoid=" is supported in
    // practice. Not asserting the mixed-case quirk here to avoid pinning buggy output.
}
