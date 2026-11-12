//
//  CardHeroPortTests.swift
//  dialogTests
//
//  Covers the card hero advisory, card footer rules (claim, dots, button shape), media loading
//  markers, image-block advice, and the LogMonitor pattern presets with their routing and the
//  logprobe parity guard.
//

import XCTest
@testable import Dialog

/// The hero band is a fixed box with a glyph: shape, size and padding describe the legacy circle
/// and are ignored with an advisory; weight changes only the glyph and is honoured.
final class CardHeroPortTests: XCTestCase {

    func testWeightIsPortedBecauseItDoesNotTouchTheBox() {
        XCTAssertEqual(CardHeroAdvice.weight(from: "bold"), .bold)
        XCTAssertEqual(CardHeroAdvice.weight(from: "regular"), .regular)
        XCTAssertEqual(CardHeroAdvice.weight(from: nil), .medium, "absent must stay today's render")
        XCTAssertEqual(CardHeroAdvice.weight(from: "nonsense"), .medium, "unknown fails closed")
    }

    func testTheThreeGeometryKeysAreNamedAsIgnoredRatherThanSilentlyDropped() {
        let keys = CardHeroAdvice.ignoredKeys(shape: "circle", size: 200, padding: 12)
        XCTAssertEqual(keys, ["heroImageShape", "heroImageSize", "heroImagePadding"])
    }

    func testNothingAuthoredMeansNothingToSay() {
        XCTAssertTrue(CardHeroAdvice.ignoredKeys(shape: nil, size: nil, padding: nil).isEmpty)
    }

    func testOnlyTheKeysActuallyAuthoredAreNamed() {
        XCTAssertEqual(CardHeroAdvice.ignoredKeys(shape: nil, size: 44, padding: nil),
                       ["heroImageSize"])
    }

    // MARK: - Two more retired keys

    /// heroBadge overlays the legacy circle; the band has no circle to overlay.
    func testHeroBadgeIsNamedAsIgnored() {
        XCTAssertEqual(CardHeroAdvice.ignoredKeys(shape: nil, size: nil, padding: nil,
                                                  badge: "check"),
                       ["heroBadge"])
    }

    /// Dots are on by default; only an authored false turns them off.
    func testShowProgressDotsTurnsTheCardFooterDotsOffOnlyWhenAuthoredFalse() {
        XCTAssertTrue(CardFooterDots.shown(authored: nil))
        XCTAssertTrue(CardFooterDots.shown(authored: true))
        XCTAssertFalse(CardFooterDots.shown(authored: false))
    }

    func testTheNewKeysAreSilentWhenUnauthored() {
        XCTAssertTrue(CardHeroAdvice.ignoredKeys(shape: nil, size: nil, padding: nil,
                                                 badge: nil).isEmpty)
        XCTAssertEqual(CardHeroAdvice.ignoredKeys(shape: "circle", size: nil, padding: nil),
                       ["heroImageShape"])
    }
}

/// The footer claim is opt-in: only authored text draws a line.
final class CardFooterClaimTests: XCTestCase {

    func testAnUnauthoredClaimDrawsNothing() {
        XCTAssertNil(CardFooterClaim.resolve(authored: nil))
    }

    func testAnAuthoredClaimWins() {
        XCTAssertEqual(CardFooterClaim.resolve(authored: "Managed by Globex IT"), "Managed by Globex IT")
    }

    func testAnEmptyStringIsAnOptOutNotAFallback() {
        XCTAssertNil(CardFooterClaim.resolve(authored: ""))
    }
}

/// The button shape key names one of two shapes; text-only affordances have none and are untouched.
final class InspectButtonShapeTests: XCTestCase {

    func testTheTwoFlavoursDecode() {
        XCTAssertEqual(InspectButtonShape("pill"), .pill)
        XCTAssertEqual(InspectButtonShape("rounded"), .rounded)
    }

    func testSpellingIsCaseInsensitive() {
        XCTAssertEqual(InspectButtonShape("Pill"), .pill)
        XCTAssertEqual(InspectButtonShape("ROUNDED"), .rounded)
    }

    func testAbsentMeansTodaysRenderIsLeftAlone() {
        // nil means "apply no shape modifier", not a third flavour.
        XCTAssertNil(InspectButtonShape(nil))
    }

    func testAnUnknownSpellingFailsClosedRatherThanGuessing() {
        XCTAssertNil(InspectButtonShape("squircle"))
        XCTAssertNil(InspectButtonShape(""))
    }
}

/// The footer dots are capped, not windowed; past the cap one measure takes the slot.
final class CardFooterDotCapTests: XCTestCase {

    /// StepDotIndicator owns the three dot states so no two rows disagree about the fill.
    func testADotIsPassedCurrentOrFutureByPosition() {
        XCTAssertEqual(StepDotIndicator.state(ofDot: 1, current: 3), .passed)
        XCTAssertEqual(StepDotIndicator.state(ofDot: 2, current: 3), .passed)
        XCTAssertEqual(StepDotIndicator.state(ofDot: 3, current: 3), .current)
        XCTAssertEqual(StepDotIndicator.state(ofDot: 4, current: 3), .future)
    }

    func testOnTheFirstStepNothingIsPassed() {
        XCTAssertEqual(StepDotIndicator.state(ofDot: 1, current: 1), .current)
        XCTAssertEqual(StepDotIndicator.state(ofDot: 2, current: 1), .future)
    }

    func testThePassedTintIsTheCardsFortyFivePercent() {
        XCTAssertEqual(StepDotIndicator.passedOpacity, 0.45)
    }

    func testTheCardObeysTheSameDotCapAsEverythingElse() {
        XCTAssertTrue(StepDotIndicator.drawsDots(total: 7))
        XCTAssertTrue(StepDotIndicator.drawsDots(total: 8))
        XCTAssertFalse(StepDotIndicator.drawsDots(total: 9), "past the cap the counter carries it")
        XCTAssertFalse(StepDotIndicator.drawsDots(total: 29), "capability-tour")
    }

    func testASingleStepDrawsNoDots() {
        XCTAssertFalse(StepDotIndicator.drawsDots(total: 1), "one dot states nothing")
    }

    // MARK: - Past the cap, a measure

    func testShortFlowsGetDotsAndLongOnesGetAMeasure() {
        XCTAssertEqual(StepDotIndicator.form(total: 5), .dots)
        XCTAssertEqual(StepDotIndicator.form(total: 8), .dots, "the cap itself still counts")
        XCTAssertEqual(StepDotIndicator.form(total: 9), .measure, "one past the cap switches form")
        XCTAssertEqual(StepDotIndicator.form(total: 29), .measure, "capability-tour")
    }

    /// A one-step flow draws neither dots nor a measure.
    func testAFlowTooShortToStateProgressDrawsNeither() {
        XCTAssertEqual(StepDotIndicator.form(total: 1), .none)
        XCTAssertEqual(StepDotIndicator.form(total: 0), .none)
    }

    /// drawsDots answers only the dots question; past the cap the measure draws and it is false.
    func testDrawsDotsStillAnswersOnlyTheDotsQuestion() {
        XCTAssertTrue(StepDotIndicator.drawsDots(total: 8))
        XCTAssertFalse(StepDotIndicator.drawsDots(total: 9))
    }

    /// The measure fills by position: step 1 of n is not zero.
    func testTheMeasureFillsByPositionNotByCompletion() {
        XCTAssertEqual(StepDotIndicator.measureFraction(current: 1, total: 29), 1.0 / 29.0, accuracy: 0.0001)
        XCTAssertEqual(StepDotIndicator.measureFraction(current: 29, total: 29), 1.0, accuracy: 0.0001)
        XCTAssertEqual(StepDotIndicator.measureFraction(current: 15, total: 29), 15.0 / 29.0, accuracy: 0.0001)
    }

    func testAnOutOfRangePositionClamps() {
        XCTAssertEqual(StepDotIndicator.measureFraction(current: 0, total: 10), 0.0, accuracy: 0.0001)
        XCTAssertEqual(StepDotIndicator.measureFraction(current: 99, total: 10), 1.0, accuracy: 0.0001)
        XCTAssertEqual(StepDotIndicator.measureFraction(current: 3, total: 0), 0.0, accuracy: 0.0001)
    }
}

/// The media skeleton is a declinable visual; the readiness marker is emitted either way, because
/// the quiescence poll waits on it.
final class MediaLoadingTests: XCTestCase {

    func testTheMarkerIsEmittedEvenWhenTheSkeletonIsDeclined() {
        XCTAssertTrue(MediaLoading.drawsSkeleton(showLoadingState: true))
        XCTAssertFalse(MediaLoading.drawsSkeleton(showLoadingState: false),
                       "the VISUAL is declinable")
        XCTAssertFalse(MediaLoading.marker.isEmpty,
                       "the MARKER is not — readiness is a fact, not decoration")
    }

    func testTheMarkerIsTheStringTheHarnessWaitsFor() {
        // scripts/ax-frame-diff.zsh lists this string in QUIESCE_PENDING.
        XCTAssertEqual(MediaLoading.marker, "Loading media")
    }
}

/// An image block that cannot load draws nothing on screen, so the log says why, once per path.
final class ImageBlockAdviceTests: XCTestCase {

    func testARemoteURLIsNamedAsUnsupportedRatherThanAsMissing() {
        // The block does not fetch; the file is not missing.
        let advice = ImageBlockAdvice.reason(for: "https://example.com/a.png")
        XCTAssertTrue(advice.contains("remote"), advice)
        XCTAssertFalse(advice.lowercased().contains("not found"), advice)
    }

    func testHTTPAndHTTPSAreBothRecognised() {
        XCTAssertTrue(ImageBlockAdvice.reason(for: "http://example.com/a.png").contains("remote"))
        XCTAssertTrue(ImageBlockAdvice.reason(for: "https://example.com/a.png").contains("remote"))
    }

    func testAGifIsToldItWouldHaveWorked() {
        // GIFs take the AsyncImageView path, which does fetch.
        XCTAssertTrue(ImageBlockAdvice.reason(for: "https://example.com/a.gif").contains(".gif"),
                      ImageBlockAdvice.reason(for: "https://example.com/a.gif"))
    }

    func testAnAbsolutePathIsReportedAsAMissingFile() {
        let advice = ImageBlockAdvice.reason(for: "/nope/missing.png")
        XCTAssertTrue(advice.contains("No file"), advice)
    }

    func testARelativePathNamesTheBasePathAsTheThingToCheck() {
        XCTAssertTrue(ImageBlockAdvice.reason(for: "art/missing.png").contains("iconBasePath"),
                      ImageBlockAdvice.reason(for: "art/missing.png"))
    }
}

/// AppInspector.signal tells a removal from a cleared download; both look the same without
/// wasInstalled.
final class AppRowSignalTests: XCTestCase {

    func testAFreshInstallReadsAsInstalled() {
        XCTAssertEqual(AppInspector.signal(isInstalled: true, wasInstalled: false, isCached: false),
                       .installed)
    }

    func testAnAppThatDisappearsReadsAsRemovedNotPending() {
        XCTAssertEqual(AppInspector.signal(isInstalled: false, wasInstalled: true, isCached: false),
                       .removed)
    }

    func testAClearedDownloadStillReadsAsPending() {
        XCTAssertEqual(AppInspector.signal(isInstalled: false, wasInstalled: false, isCached: false),
                       .pending)
    }

    func testADownloadInFlightReadsAsDownloading() {
        XCTAssertEqual(AppInspector.signal(isInstalled: false, wasInstalled: false, isCached: true),
                       .downloading)
    }

    func testInstalledWinsOverACachedCopyStillOnDisk() {
        // munki leaves the .dmg in the cache after installing.
        XCTAssertEqual(AppInspector.signal(isInstalled: true, wasInstalled: false, isCached: true),
                       .installed)
    }
}

/// The removal notice changes the row's text for a dwell, never its state.
final class RemovalNoticeDwellTests: XCTestCase {

    func testTheNoticeHoldsBrieflyThenSettlesBackToPending() {
        let removedAt = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(AppInspector.removalNoticeExpired(
            removedAt: removedAt, now: removedAt.addingTimeInterval(5)))
        XCTAssertTrue(AppInspector.removalNoticeExpired(
            removedAt: removedAt, now: removedAt.addingTimeInterval(120)))
    }

    func testTheNoticeNeverChangesTheROWSTATE() {
        XCTAssertEqual(AppInspector.signal(isInstalled: false, wasInstalled: true, isCached: false),
                       .removed)
        XCTAssertEqual(AppInspector.rowState(for: .removed), AppInspector.rowState(for: .pending))
    }
}

/// Glob matching for item paths (fnmatch semantics), so a versioned receipt name can be matched.
final class GlobPathMatchingTests: XCTestCase {

    func testAVersionedReceiptIsMatchedByPrefix() {
        XCTAssertTrue(PathGlob.matches(name: "Obsidian-1.12.7.pkg", pattern: "Obsidian*"))
        XCTAssertTrue(PathGlob.matches(name: "Obsidian-2.0.0.pkg",  pattern: "Obsidian*"))
    }

    func testItDoesNotMatchADifferentPackage() {
        XCTAssertFalse(PathGlob.matches(name: "Obsidian-1.12.7.pkg", pattern: "Slack*"))
    }

    func testAPlainNameStillMatchesExactlyAndOnlyExactly() {
        XCTAssertTrue(PathGlob.matches(name: "Obsidian.pkg", pattern: "Obsidian.pkg"))
        XCTAssertFalse(PathGlob.matches(name: "Obsidian-1.12.7.pkg", pattern: "Obsidian.pkg"))
    }

    func testTheDotIsLiteralNotAWildcard() {
        XCTAssertFalse(PathGlob.matches(name: "ObsidianXpkg", pattern: "Obsidian.pkg"))
    }

    func testQuestionMarkMatchesExactlyOneCharacter() {
        XCTAssertTrue(PathGlob.matches(name: "app-1.pkg", pattern: "app-?.pkg"))
        XCTAssertFalse(PathGlob.matches(name: "app-12.pkg", pattern: "app-?.pkg"))
    }

    func testSelfServicePlusSignIsLiteral() {
        XCTAssertTrue(PathGlob.matches(name: "SelfService+2.16.0.pkg",
                                               pattern: "SelfService+*"))
    }

    /// A real name containing glob characters is found by its literal path (3.1.1 behaviour), and
    /// the glob still matches versioned names in the same folder.
    func testALiteralBracketNameExistsAndGlobsStillMatch() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("Foo [Beta].app").path, contents: nil)
        FileManager.default.createFile(atPath: dir.appendingPathComponent("Obsidian-1.12.7.pkg").path, contents: nil)

        XCTAssertTrue(PathGlob.exists(atPath: dir.appendingPathComponent("Foo [Beta].app").path))
        XCTAssertTrue(PathGlob.exists(atPath: dir.appendingPathComponent("Obsidian*").path))
        XCTAssertFalse(PathGlob.exists(atPath: dir.appendingPathComponent("Foo [Gamma].app").path))
    }

    func testNeedsGlobDetectsMagicCharactersOnly() {
        XCTAssertTrue(PathGlob.needsGlob("/path/Obsidian*"))
        XCTAssertTrue(PathGlob.needsGlob("/path/app-?.pkg"))
        XCTAssertTrue(PathGlob.needsGlob("/path/[abc].pkg"))
        XCTAssertFalse(PathGlob.needsGlob("/Applications/Firefox.app"))
    }
}
