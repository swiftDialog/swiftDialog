//
//  MediaLayoutTests.swift
//  dialogTests
//
//  How media occupies the payload band: `inline` (default) in the stack, `fill` the whole band with
//  the caption on the action bar, or `split` beside a text column. Authored via `mediaLayout`, not inferred.
//

import XCTest
import AVFoundation
@testable import Dialog

final class MediaLayoutTests: XCTestCase {

    private func block(_ json: String) throws -> InspectConfig.GuidanceContent {
        try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
    }

    // MARK: - Decode

    func testTheKeyDecodes() throws {
        let b = try block(#"{"type":"image","mediaLayout":"fill"}"#)
        XCTAssertEqual(b.mediaLayout, "fill")
    }

    func testAnAbsentKeyDecodesAsNil() throws {
        XCTAssertNil(try block(#"{"type":"image"}"#).mediaLayout)
    }

    // MARK: - Resolution

    func testAnUnauthoredLayoutIsInline() {
        XCTAssertEqual(MediaLayout.resolve(nil), .inline)
    }

    func testEachAuthoredValueResolves() {
        XCTAssertEqual(MediaLayout.resolve("fill"), .fill)
        XCTAssertEqual(MediaLayout.resolve("split"), .split)
        XCTAssertEqual(MediaLayout.resolve("inline"), .inline)
    }

    /// An unknown value falls back to `inline`.
    func testAnUnknownValueFallsBackToInline() {
        XCTAssertEqual(MediaLayout.resolve("bogus"), .inline)
        XCTAssertEqual(MediaLayout.resolve(""), .inline)
    }

    func testResolutionIsCaseInsensitive() {
        XCTAssertEqual(MediaLayout.resolve("Fill"), .fill)
        XCTAssertEqual(MediaLayout.resolve("SPLIT"), .split)
    }

    // MARK: - What each arrangement means

    /// Only `fill` and `split` take the band.
    func testOnlyFillAndSplitTakeTheBand() {
        XCTAssertTrue(MediaLayout.fill.takesTheBand)
        XCTAssertTrue(MediaLayout.split.takesTheBand)
        XCTAssertFalse(MediaLayout.inline.takesTheBand)
    }

    /// Only `fill` moves the caption to the action bar.
    func testOnlyFillMovesTheCaptionToTheBar() {
        XCTAssertTrue(MediaLayout.fill.captionBelongsOnTheBar)
        XCTAssertFalse(MediaLayout.split.captionBelongsOnTheBar)
        XCTAssertFalse(MediaLayout.inline.captionBelongsOnTheBar)
    }

    // MARK: - Arranging a step's blocks

    private func blocks(_ jsons: [String]) throws -> [InspectConfig.GuidanceContent] {
        try jsons.map { try block($0) }
    }

    func testWithNoMediaLayoutTheStepStaysStacked() throws {
        let bs = try blocks([#"{"type":"text"}"#, #"{"type":"image"}"#])
        XCTAssertEqual(MediaArrangement.resolve(bs), .stacked)
    }

    func testALoneFillBlockTakesTheWholeBand() throws {
        let bs = try blocks([#"{"type":"image","mediaLayout":"fill"}"#])
        XCTAssertEqual(MediaArrangement.resolve(bs), .fill(index: 0))
    }

    /// `fill` beside other blocks degrades to `split`, so no authored content is dropped.
    func testFillAlongsideOtherContentDegradesToSplitRatherThanDroppingIt() throws {
        let bs = try blocks([#"{"type":"image","mediaLayout":"fill"}"#, #"{"type":"text"}"#])
        XCTAssertEqual(MediaArrangement.resolve(bs), .split(mediaIndex: 0))
    }

    func testSplitPutsTheMediaBesideEverythingElse() throws {
        let bs = try blocks([#"{"type":"text"}"#, #"{"type":"image","mediaLayout":"split"}"#])
        XCTAssertEqual(MediaArrangement.resolve(bs), .split(mediaIndex: 1))
    }

    /// A lone `split` block fills, rather than a half-width box beside nothing.
    func testALoneSplitBlockFillsInstead() throws {
        let bs = try blocks([#"{"type":"video","mediaLayout":"split"}"#])
        XCTAssertEqual(MediaArrangement.resolve(bs), .fill(index: 0))
    }

    /// When two blocks claim the band, the first wins and the second stays in the stack.
    func testTheFirstClaimantWinsWhenTwoAskForTheBand() throws {
        let bs = try blocks([#"{"type":"image","mediaLayout":"fill"}"#,
                             #"{"type":"video","mediaLayout":"fill"}"#])
        XCTAssertEqual(MediaArrangement.resolve(bs), .split(mediaIndex: 0))
    }

    func testAnEmptyStepIsStacked() {
        XCTAssertEqual(MediaArrangement.resolve([]), .stacked)
    }

    // MARK: - Schema

    func testTheSchemaDeclaresMediaLayoutAsAClosedEnum() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let defs = try XCTUnwrap((schema as? [String: Any])?["definitions"] as? [String: Any])
        let gc = try XCTUnwrap(defs["GuidanceContent"] as? [String: Any])
        let props = try XCTUnwrap(gc["properties"] as? [String: Any])
        let media = try XCTUnwrap(props["mediaLayout"] as? [String: Any],
                                  "mediaLayout is missing from the schema — the key would be unauthorable")
        XCTAssertEqual(media["type"] as? String, "string")
        XCTAssertEqual((media["enum"] as? [String])?.sorted(), ["fill", "inline", "split"])
    }

    // MARK: - Media URL resolution

    /// `IntroMediaURL.resolve` checks for a local file before `URL(string:)`, which would turn a POSIX
    /// path into a schemeless URL AVPlayer cannot play.
    func testALocalFilePathResolvesToAFileURLRatherThanASchemelessOne() throws {
        // A real file, so the test depends on no asset on the machine.
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("intro-media-\(UUID().uuidString).mp4")
        try Data("not a real movie, but a real file".utf8).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let resolved = try XCTUnwrap(IntroMediaURL.resolve(tmp.path))
        XCTAssertTrue(resolved.isFileURL, "a path that exists on disk must become a FILE url")
        XCTAssertEqual(resolved.scheme, "file",
                       "a schemeless URL is exactly what made AVPlayer report unsupported content")
        XCTAssertEqual(resolved.path, tmp.path)
    }

    func testRemoteURLsAreStillResolvedAsThemselves() throws {
        let remote = try XCTUnwrap(IntroMediaURL.resolve("https://example.com/clip.mp4"))
        XCTAssertEqual(remote.scheme, "https")
        XCTAssertFalse(remote.isFileURL)

        let embed = try XCTUnwrap(IntroMediaURL.resolve("https://youtu.be/abc123"))
        XCTAssertEqual(embed.host, "youtu.be")
    }

    /// A missing local path resolves to nil ("Media not found"), not a schemeless URL.
    func testAPathThatDoesNotExistResolvesToNilRatherThanASchemelessURL() {
        let missing = "/definitely/not/here/\(UUID().uuidString)/clip.mp4"
        XCTAssertNil(IntroMediaURL.resolve(missing),
                     "a non-existent local path must not become a schemeless URL handed to AVPlayer")
    }
}

// MARK: - mediaFit

/// `mediaFit` on `IntroStep` (folded from `media.fit`): absent is `.fit`, what the image views draw
/// without it; `fill` opts in to cropping.
extension MediaLayoutTests {

    func testAbsentMediaFitIsFitNotFill() {
        XCTAssertEqual(MediaFit(nil), .fit, "absence must keep the behaviour that already shipped")
        XCTAssertEqual(MediaFit(nil).contentMode, .fit)
    }

    func testFillIsTheOnlyWordThatCrops() {
        XCTAssertEqual(MediaFit("fill"), .fill)
        XCTAssertEqual(MediaFit("FILL"), .fill, "authored case must not decide the rendering")
        XCTAssertEqual(MediaFit("fill").contentMode, .fill)
    }

    /// An unrecognised value falls back to `.fit`.
    func testUnrecognisedMediaFitFallsBackToFit() {
        XCTAssertEqual(MediaFit("cover"), .fit)
        XCTAssertEqual(MediaFit(""), .fit)
        XCTAssertEqual(MediaFit("fit"), .fit)
    }

    /// The NSImageView arm scales the same way as the SwiftUI arm.
    func testTheAnimatedArmScalesTheSameWay() {
        XCTAssertEqual(MediaFit("fill").imageScaling, .scaleAxesIndependently)
        XCTAssertEqual(MediaFit(nil).imageScaling, .scaleProportionallyUpOrDown)
    }
}

// MARK: - image-carousel: imageFit and arrows

/// `imageFit` travels from the block through `GuidanceContentView` and `ImageCarouselView` to
/// `AsyncImageView`. Arrows (32pt glyph + 16pt inset each) drop when the frame is too narrow.
extension MediaLayoutTests {

    // MARK: imageFit

    func testTheCarouselFitKeyDecodes() throws {
        let b = try block(#"{"type":"image-carousel","imageFit":"fit"}"#)
        XCTAssertEqual(b.imageFit, "fit")
    }

    func testAnAbsentCarouselFitDecodesAsNil() throws {
        XCTAssertNil(try block(#"{"type":"image-carousel"}"#).imageFit)
    }

    /// `imageFit` is a known block key.
    func testTheCarouselFitKeyIsAKnownBlockKey() {
        XCTAssertTrue(InspectConfig.knownBlockKeys.contains("imageFit"))
    }

    /// The schema declares the carousel's `imageFit`, defaulting to `fill`.
    func testTheSchemaDeclaresTheCarouselFitKey() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let defs = try XCTUnwrap((schema as? [String: Any])?["definitions"] as? [String: Any])
        let gc = try XCTUnwrap(defs["GuidanceContent"] as? [String: Any])
        let props = try XCTUnwrap(gc["properties"] as? [String: Any])
        let fit = try XCTUnwrap(props["imageFit"] as? [String: Any],
                                "imageFit is missing from the schema — the key would be unauthorable")
        XCTAssertEqual((fit["enum"] as? [String])?.sorted(), ["fill", "fit"])
        XCTAssertEqual(fit["default"] as? String, "fill")
    }

    /// The carousel arm passes `block.imageFit ?? "fill"`; the whole expression, default included.
    func testTheCarouselArmPassesTheAuthoredFit() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Core Framework/Components/GuidanceContentView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains(#"imageFit: block.imageFit ?? "fill""#),
                      "the image-carousel arm must hand the authored fit to the view, defaulting to what shipped")
    }

    /// `ImageCarouselView` hands the fit to the image.
    func testTheCarouselHandsTheFitToTheImage() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Core Framework/Components/MediaComponents.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("imageFit: imageContentMode"),
                      "ImageCarouselView must pass its resolved content mode to AsyncImageView")
    }

    // MARK: Arrow geometry

    /// One arrow is 32pt of glyph plus a 16pt inset.
    func testTheArrowFootprintIsTheTwoNumbersTheButtonsAreDrawnWith() {
        XCTAssertEqual(ImageCarouselView.arrowFootprint, 48)
    }

    /// A clear middle at least as wide as the chrome flanking it: 2 × (2 × 48) = 192.
    func testAFrameNarrowerThanTwiceItsNavigationDropsTheArrows() {
        XCTAssertFalse(ImageCarouselView.arrowsFit(inWidth: 180), "the frame that exposed this")
        XCTAssertFalse(ImageCarouselView.arrowsFit(inWidth: 191))
        XCTAssertTrue(ImageCarouselView.arrowsFit(inWidth: 192), "exactly the derived threshold")
        XCTAssertTrue(ImageCarouselView.arrowsFit(inWidth: 400), "the default frame is unaffected")
    }

    /// The 400pt default frame keeps its arrows.
    func testTheDefaultFrameKeepsItsArrows() {
        XCTAssertTrue(ImageCarouselView.arrowsFit(inWidth: 400))
    }

    private func carousel(width: CGFloat, showArrows: Bool = true, showDots: Bool = true,
                          images: [String] = ["a.png", "b.png"]) -> ImageCarouselView {
        ImageCarouselView(images: images, iconBasePath: nil, scaleFactor: 1.0,
                          imageWidth: width, imageHeight: 100,
                          showDots: showDots, showArrows: showArrows)
    }

    /// A frame too narrow for arrows drops them even with `showArrows: true`.
    func testGeometryOverrulesAnExplicitShowArrows() {
        XCTAssertFalse(carousel(width: 180, showArrows: true).arrowsVisible)
        XCTAssertTrue(carousel(width: 400, showArrows: true).arrowsVisible)
    }

    /// The guard only removes arrows; it never adds them.
    func testTheGuardNeverAddsArrows() {
        XCTAssertFalse(carousel(width: 400, showArrows: false).arrowsVisible)
        XCTAssertFalse(carousel(width: 400, images: ["only.png"]).arrowsVisible)
    }

    /// Suppressed arrows bring the dots back, even against `showDots: false`.
    func testTheDotsStandInWhenTheArrowsAreSuppressed() {
        XCTAssertTrue(carousel(width: 180, showDots: false).dotsVisible)
        XCTAssertFalse(carousel(width: 400, showDots: false).dotsVisible,
                       "a wide frame still honours showDots: false — it has arrows")
        XCTAssertFalse(carousel(width: 180, showDots: false, images: ["only.png"]).dotsVisible,
                       "one image is not a carousel")
    }
}

/// A looping native video must not outlive its view: the end-of-item observer holds the player weakly.
final class NativeVideoLifetimeTests: XCTestCase {

    func testTheLoopObserverDoesNotKeepThePlayerAlive() {
        weak var released: AVPlayer?
        var observer: NSObjectProtocol?
        autoreleasepool {
            let player = AVPlayer(url: URL(fileURLWithPath: "/nonexistent/clip.mp4"))
            released = player
            observer = IntroNativeVideoPlayer.loopObserver(for: player, autoplay: true)
        }
        // AVFoundation lets go of a player on the main queue shortly after its last owner.
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertNil(released, "the observer kept the player, and its buffers, alive")
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}

/// Views that draw a file inside `body` decode it once per file version, never above `maxPixel`.
final class InspectImageCacheTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("image-cache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func writePNG(width: Int, height: Int, named name: String) throws -> String {
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let path = dir.appendingPathComponent(name).path
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        return path
    }

    func testARedrawGetsTheSameDecodedImage() throws {
        let path = try writePNG(width: 64, height: 64, named: "icon.png")
        let first = try XCTUnwrap(InspectImageCache.shared.image(atPath: path))
        XCTAssertTrue(first === InspectImageCache.shared.image(atPath: path), "a second draw decoded again")
    }

    func testALargeImageIsCappedInPixelsButKeepsItsPointSize() throws {
        let path = try writePNG(width: 4000, height: 1000, named: "wide.png")
        let image = try XCTUnwrap(InspectImageCache.shared.image(atPath: path))
        let widest = image.cgImage(forProposedRect: nil, context: nil, hints: nil)?.width ?? .max
        XCTAssertLessThanOrEqual(widest, InspectImageCache.maxPixel)
        XCTAssertEqual(image.size.width, NSImage(contentsOfFile: path)?.size.width ?? -1, accuracy: 0.5)
        XCTAssertEqual(image.size.height, NSImage(contentsOfFile: path)?.size.height ?? -1, accuracy: 0.5)
    }

    func testAChangedFileIsDecodedAgain() throws {
        let path = try writePNG(width: 32, height: 32, named: "logo.png")
        let before = try XCTUnwrap(InspectImageCache.shared.image(atPath: path))
        _ = try writePNG(width: 48, height: 48, named: "logo.png")
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: path)
        let after = try XCTUnwrap(InspectImageCache.shared.image(atPath: path))
        XCTAssertFalse(before === after)
        XCTAssertEqual(after.size.width, 48, accuracy: 0.5)
    }

    func testAMissingFileOrADirectoryGivesNoImage() {
        XCTAssertNil(InspectImageCache.shared.image(atPath: dir.appendingPathComponent("absent.png").path))
        XCTAssertNil(InspectImageCache.shared.image(atPath: dir.path))
    }

    func testADerivedImageIsMadeOncePerFileVersion() throws {
        let path = try writePNG(width: 16, height: 16, named: "hero.png")
        var made = 0
        for _ in 0..<5 {
            _ = InspectImageCache.shared.derivedImage("test-trim", fromPath: path) { made += 1; return NSImage(size: NSSize(width: 1, height: 1)) }
        }
        XCTAssertEqual(made, 1)
    }
}

/// The wallpaper picker's thumbnails are dropped from memory when it goes away.
@MainActor
final class ThumbnailReleaseTests: XCTestCase {

    func testReleasingDropsEveryThumbnailFromMemory() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("thumbs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 800, pixelsHigh: 600,
                                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let path = dir.appendingPathComponent("wall.png").path
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))

        await ThumbnailService.shared.loadThumbnail(for: path)
        XCTAssertNotNil(ThumbnailService.shared.thumbnails[path])
        ThumbnailService.shared.releaseThumbnails()
        XCTAssertTrue(ThumbnailService.shared.thumbnails.isEmpty)
    }
}
