//
//  ExternalFactStatusTests.swift
//  dialogTests
//
//  `ExternalFactStatus`: `StatusBadgeView`'s words for facts about the machine (enrolled, compliant,
//  present), kept apart from `StepStatus`. One classifier drives both hue and glyph, so they agree.
//

import XCTest
import SwiftUI
@testable import Dialog

final class ExternalFactStatusTests: XCTestCase {

    // Defined in BlockSemanticsTests.swift: distinct hues per slot.
    private let palette = ResolvedPalette.fixture

    // MARK: - Word by word
    // One assertion per word; a table shared with the production type would drift along with it.

    func testTheSuccessWords() {
        for word in ["enabled", "active", "pass", "success", "valid", "enrolled",
                     "connected", "on", "true", "yes", "installed", "present", "compliant",
                     "detected", "ok"] {
            XCTAssertEqual(ExternalFactStatus.classify(word), .success, "\(word)")
        }
    }

    func testTheFailureWords() {
        for word in ["fail", "failure", "invalid", "unenrolled", "disconnected",
                     "not found", "missing", "error", "non-compliant", "not detected"] {
            XCTAssertEqual(ExternalFactStatus.classify(word), .fail, "\(word)")
        }
    }

    func testTheInFlightWords() {
        for word in ["downloading", "processing", "running"] {
            XCTAssertEqual(ExternalFactStatus.classify(word), .progress, "\(word)")
        }
    }

    func testThePendingWords() {
        for word in ["pending", "in-progress", "waiting", "checking"] {
            XCTAssertEqual(ExternalFactStatus.classify(word), .pending, "\(word)")
        }
    }

    func testTheUnknownWords() {
        for word in ["unknown", "partial"] {
            XCTAssertEqual(ExternalFactStatus.classify(word), .unknown, "\(word)")
        }
    }

    func testWarningAndInfoAreExactMatchesOnly() {
        XCTAssertEqual(ExternalFactStatus.classify("warning"), .warning)
        XCTAssertEqual(ExternalFactStatus.classify("info"), .info)
        // Both arms are `==`, so "warnings" falls through to neutral.
        XCTAssertEqual(ExternalFactStatus.classify("warnings"), .neutral)
        XCTAssertEqual(ExternalFactStatus.classify("information"), .neutral)
    }

    func testAnUnrecognisedWordIsNeutral() {
        XCTAssertEqual(ExternalFactStatus.classify("bogus"), .neutral)
        XCTAssertEqual(ExternalFactStatus.classify(""), .neutral)
    }

    func testClassificationIsCaseInsensitive() {
        XCTAssertEqual(ExternalFactStatus.classify("COMPLIANT"), .success)
        XCTAssertEqual(ExternalFactStatus.classify("Not Found"), .fail)
    }

    // MARK: - Legitimate states draw neutral, not failure

    func testLegitimateOffStatesAreNeutralAndNotFailures() {
        for word in ["disabled", "inactive", "off", "false", "no"] {
            XCTAssertEqual(ExternalFactStatus.classify(word), .neutral,
                           "\(word) is a legitimate state, not a failure")
        }
    }

    /// `"no"` is not a failure word: failure matches on `contains`, so it would capture `"unknown"`.
    func testUnknownIsNotSweptIntoFailureByASubstringMatch() {
        XCTAssertEqual(ExternalFactStatus.classify("unknown"), .unknown)
        XCTAssertNotEqual(ExternalFactStatus.classify("unknown"), .fail)
    }

    // MARK: - Matching rules

    /// Non-failure words match on prefix, so `"on"` makes `"online"` and `"enabled (managed)"` succeed.
    func testNonFailureWordsMatchOnPrefix() {
        XCTAssertEqual(ExternalFactStatus.classify("online"), .success)
        XCTAssertEqual(ExternalFactStatus.classify("enabled (managed)"), .success)
        XCTAssertEqual(ExternalFactStatus.classify("downloading 4 of 9"), .progress)
    }

    /// Failure words match anywhere, so `"disk error"` is a failure.
    func testFailureWordsMatchAnywhereInTheString() {
        XCTAssertEqual(ExternalFactStatus.classify("disk error"), .fail)
        XCTAssertEqual(ExternalFactStatus.classify("profile not found"), .fail)
    }

    /// `detected` (success prefix) and `not detected` (failure substring) stay opposite verdicts.
    func testDetectedAndNotDetectedAreOppositeVerdicts() {
        XCTAssertEqual(ExternalFactStatus.classify("detected"), .success)
        XCTAssertEqual(ExternalFactStatus.classify("Detected on 2 volumes"), .success)
        XCTAssertEqual(ExternalFactStatus.classify("not detected"), .fail)
        XCTAssertEqual(ExternalFactStatus.classify("Not Detected"), .fail)
    }

    /// Verdict projection: success → true, fail → false, everything else nil (neutral words included).
    func testTheVerdictProjection() {
        for word in ["pass", "passed", "success", "enabled", "detected", "ok", "compliant", "enabled (managed)"] {
            XCTAssertEqual(ExternalFactStatus.classify(word).verdict, true, word)
            XCTAssertEqual(InspectConfig.verdictIsPass(word), true, word)
        }
        for word in ["fail", "failed", "error", "invalid", "not detected", "non-compliant", "disk error"] {
            XCTAssertEqual(ExternalFactStatus.classify(word).verdict, false, word)
            XCTAssertEqual(InspectConfig.verdictIsPass(word), false, word)
        }
        for word in ["disabled", "no", "false", "pending", "downloading", "unknown", "warning", "info", "banana", ""] {
            XCTAssertNil(ExternalFactStatus.classify(word).verdict, word)
            XCTAssertNil(InspectConfig.verdictIsPass(word), word)
        }
        XCTAssertEqual(InspectConfig.verdictIsPass("  PASS \n"), true, "the fold trims and case-folds")
    }

    /// Success is checked before failure, so `"connected, missing profile"` reads as success.
    func testSuccessIsCheckedBeforeFailure() {
        XCTAssertEqual(ExternalFactStatus.classify("connected, missing profile"), .success)
    }

    // MARK: - Glyph and hue

    func testEachCategoryKeepsItsSymbol() {
        XCTAssertEqual(ExternalFactStatus.success.symbol, "checkmark.circle.fill")
        XCTAssertEqual(ExternalFactStatus.progress.symbol, "arrow.down.circle.fill")
        XCTAssertEqual(ExternalFactStatus.warning.symbol, "exclamationmark.triangle.fill")
        XCTAssertEqual(ExternalFactStatus.info.symbol, "info.circle.fill")
        XCTAssertEqual(ExternalFactStatus.fail.symbol, "xmark.circle.fill")
        XCTAssertEqual(ExternalFactStatus.pending.symbol, "clock.fill")
        XCTAssertEqual(ExternalFactStatus.unknown.symbol, "questionmark.circle.fill")
        XCTAssertEqual(ExternalFactStatus.neutral.symbol, "circle.fill")
    }

    func testEachCategoryKeepsItsHue() {
        XCTAssertEqual(ExternalFactStatus.success.color(palette: palette), palette.success)
        XCTAssertEqual(ExternalFactStatus.progress.color(palette: palette), palette.info)
        XCTAssertEqual(ExternalFactStatus.warning.color(palette: palette), palette.warning)
        XCTAssertEqual(ExternalFactStatus.fail.color(palette: palette), palette.error)
        // `pending` and `unknown` share palette.warning.
        XCTAssertEqual(ExternalFactStatus.pending.color(palette: palette), palette.warning)
        XCTAssertEqual(ExternalFactStatus.unknown.color(palette: palette), palette.warning)
        // `info` carries no severity, so it paints the neutral default.
        XCTAssertEqual(ExternalFactStatus.info.color(palette: palette), Color.secondary)
        XCTAssertEqual(ExternalFactStatus.neutral.color(palette: palette), Color.secondary)
    }

    /// Hue and glyph agree about failure for every word.
    func testHueAndGlyphNeverDisagreeAboutFailure() {
        let vocabulary = [
            "enabled", "active", "pass", "success", "valid", "enrolled", "connected", "on",
            "true", "yes", "installed", "present", "compliant",
            "fail", "failure", "invalid", "unenrolled", "disconnected", "not found",
            "missing", "error", "non-compliant",
            "downloading", "processing", "running",
            "pending", "in-progress", "waiting", "checking",
            "unknown", "partial", "warning", "info",
            "disabled", "inactive", "off", "false", "no", "bogus"
        ]
        for word in vocabulary {
            let category = ExternalFactStatus.classify(word)
            let readsAsFailureByHue = category.color(palette: palette) == palette.error
            let readsAsFailureByGlyph = category.symbol == "xmark.circle.fill"
            XCTAssertEqual(readsAsFailureByHue, readsAsFailureByGlyph,
                           "\(word): hue says failure=\(readsAsFailureByHue) but glyph says "
                           + "failure=\(readsAsFailureByGlyph) — the two axes have drifted")
        }
    }
}
