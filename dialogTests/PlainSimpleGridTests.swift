//
//  PlainSimpleGridTests.swift
//  dialogTests
//
//  The plain-simple grid as arithmetic: the relationships between its figures, so one figure edited
//  alone breaks a test. Header and card share one left edge only because their rails agree.
//

import XCTest
import SwiftUI
@testable import Dialog

final class PlainSimpleGridTests: XCTestCase {

    // MARK: - Shell

    /// 800 − 2 × 120 = 560: the column the card, confirm card and gate line share.
    func testTheMediaColumnCloses() {
        XCTAssertEqual(PlainSimpleM.mediaColumn, 800 - 2 * PlainSimpleM.mediaRail,
                       "the media column must be the window minus both rails, or the card, confirm card and gate line stop sharing it")
        XCTAssertEqual(PlainSimpleM.mirror, 800 - PlainSimpleM.mediaRail)
    }

    /// One left edge for the header and the card: the hero and subtitle sit on the card's edge.
    func testTheHeaderSitsOnTheCardsEdge() {
        XCTAssertEqual(PlainSimpleM.textRail, PlainSimpleM.mediaRail,
                       "the header sits at textRail, the card at mediaRail: one edge, or the screen has two")
    }

    /// Header text is inset on the left only and runs to the mirror, not the card's inner width.
    func testTheTextColumnRunsToTheMirror() {
        XCTAssertEqual(PlainSimpleM.textColumn, PlainSimpleM.mirror - PlainSimpleM.textRail)
        XCTAssertEqual(PlainSimpleM.textColumn, 560)
        XCTAssertNotEqual(PlainSimpleM.textColumn,
                          PlainSimpleM.mediaColumn - 2 * PlainSimpleM.cardInset,
                          "504 is the card's inner width, not the header's column")
    }

    /// The title is optically centred on the hero (107.4 against 108).
    func testTheTitlePairsOpticallyWithTheHero() {
        let heroCentre = PlainSimpleM.heroTop + PlainSimpleM.heroSize / 2
        let titleCentre = PlainSimpleM.titleTop + 28.8 / 2 // 24/700 measures 28.8 tall
        XCTAssertEqual(heroCentre, 100, accuracy: 0.01)
        XCTAssertEqual(titleCentre, heroCentre, accuracy: 1.0,
                       "the pairing is measured, not eyeballed — within a point")
    }

    /// The title starts where the hero ends plus the authored gap.
    func testTheTitleRailClearsTheHero() {
        XCTAssertEqual(PlainSimpleM.titleRail, PlainSimpleM.textRail + PlainSimpleM.heroSize + 16)
    }

    /// The footer is the kit's band on the window's bottom edge: band top + band = the window.
    func testTheFooterConcludesTheWindow() {
        XCTAssertEqual(PlainSimpleM.footerHeight, FooterBandM.band, "one footer height")
        XCTAssertEqual(PlainSimpleM.footerBandTop + PlainSimpleM.footerHeight, PlainSimpleM.designHeight,
                       "the band lands exactly on the window's edge")
        XCTAssertEqual(PlainSimpleM.footerBandTop, 516, "600 − 84")
    }

    /// The footer rule is drawn over the band's top edge, so the band keeps the kit's full height.
    func testTheFooterRuleCostsTheBandNothing() {
        XCTAssertEqual(PlainSimpleM.footerHeight, FooterBandM.band)
        XCTAssertEqual(FooterBandM.air(), 28)
        let shell = PlainSimpleShell(buttonTitle: "Continue", onPrimaryAction: {}, accent: .blue) { EmptyView() }
        XCTAssertTrue(shell.showsFooterRule, "the rule is on unless a caller switches it off")
    }

    /// The tail slack follows from the pinned box.
    func testTheTailGapIsWhatIsLeftBelowTheCardCeiling() {
        XCTAssertEqual(PlainSimpleM.contentBoxTop + PlainSimpleM.cardMaxHeight + PlainSimpleM.tailGap,
                       PlainSimpleM.footerBandTop,
                       "202 + 268 + 46 = 516; if the ceiling moves, the tail moves, never the band")
        XCTAssertEqual(PlainSimpleM.tailGap, 46)
        XCTAssertEqual(PlainSimpleM.cardMaxHeight, 4 * PlainSimpleM.cardRowHeight + PlainSimpleM.queuedLineHeight,
                       "the ceiling is whole rows plus the queued line, never a number that slices a row")
    }

    /// The hero-less screen (E) opens 2 higher; the only y the screens do not share.
    func testOnlyTheHeroLessScreenOpensHigher() {
        XCTAssertEqual(PlainSimpleM.contentBoxTop - PlainSimpleM.contentBoxTopNoHero, 2)
    }

    // MARK: - The row

    /// 120 + 28 + 32 + 20 = 200.
    func testARowNameLandsOnTwoHundred() {
        XCTAssertEqual(PlainSimpleM.mediaRail + PlainSimpleM.cardInset + PlainSimpleM.rowIconSize
                       + PlainSimpleM.rowGutter, 200)
    }

    /// The active row is taller than a quiet one, not only coloured.
    func testTheActiveRowIsTallerThanAQuietOne() {
        XCTAssertGreaterThan(PlainSimpleM.activeRowHeight, PlainSimpleM.cardRowHeight)
        XCTAssertEqual(PlainSimpleM.activeRowHeight + 2 * PlainSimpleM.activeRowMargin, 70,
                       "J's 70 of pitch for the raised row: 64 plus a 3 margin either side")
    }

    /// The ceiling is whole rows plus the queued line, so the card never slices a row.
    func testTheCeilingIsWholeRowsPlusTheQueuedLine() {
        let scrollBudget = PlainSimpleM.cardMaxHeight - PlainSimpleM.queuedLineHeight
        let wholeRows = (scrollBudget / PlainSimpleM.cardRowHeight).rounded(.down)
        XCTAssertEqual(scrollBudget, wholeRows * PlainSimpleM.cardRowHeight,
                       "derived from rows, the budget divides — no half row to slice")
        XCTAssertEqual(wholeRows, 4, "four whole rows plus the queued line is what the 600 window holds")
    }
}

/// `PlainStepPosition`: each phase reports its own step, so a two-step flow's last screen never reads "Step 1 of 2".
final class PlainStepPositionTests: XCTestCase {

    func testTheSummaryIsAlwaysLast() {
        let p = PlainStepPosition.position(phase: .summary, hasIntro: false, hasSummary: true)
        XCTAssertEqual(p?.current, 2)
        XCTAssertEqual(p?.total, 2, "main + summary is a two-step flow, and the summary is step 2")
    }

    /// The summary screen describes itself, not the main phase.
    func testTheSummaryDoesNotReportTheMainPhasesStep() {
        let main = PlainStepPosition.position(phase: .main, hasIntro: false, hasSummary: true)
        let summary = PlainStepPosition.position(phase: .summary, hasIntro: false, hasSummary: true)
        XCTAssertEqual(main?.current, 1)
        XCTAssertNotEqual(summary?.current, main?.current,
                          "the eyebrow on the summary screen must describe the summary screen")
    }

    func testAllThreePhasesInAFullFlow() {
        XCTAssertEqual(PlainStepPosition.position(phase: .intro, hasIntro: true, hasSummary: true)?.current, 1)
        XCTAssertEqual(PlainStepPosition.position(phase: .main, hasIntro: true, hasSummary: true)?.current, 2)
        XCTAssertEqual(PlainStepPosition.position(phase: .summary, hasIntro: true, hasSummary: true)?.current, 3)
        XCTAssertEqual(PlainStepPosition.position(phase: .main, hasIntro: true, hasSummary: true)?.total, 3)
    }

    /// A single-step flow shows no indicator.
    func testASingleStepFlowHasNoIndicator() {
        XCTAssertNil(PlainStepPosition.position(phase: .main, hasIntro: false, hasSummary: false))
    }

    /// With an intro and no summary, the main phase is last.
    func testMainIsLastWhenThereIsNoSummary() {
        let p = PlainStepPosition.position(phase: .main, hasIntro: true, hasSummary: false)
        XCTAssertEqual(p?.current, 2)
        XCTAssertEqual(p?.total, 2)
    }
}

/// The media step and the walkthrough page share one silhouette: a 16:9 box and a pinned pager.
final class PlainSimpleMediaGridTests: XCTestCase {

    /// The movie is exactly 400 × 225, so strip and pager fit above the band at 516.
    func testTheMediaBoxIsExactlySixteenByNine() {
        XCTAssertEqual(PlainSimpleM.movieColumn / PlainSimpleM.movieBoxHeight, 16.0 / 9.0,
                       accuracy: 0.0001, "400 x 225 is 16:9 exactly")
        XCTAssertEqual(PlainSimpleM.movieColumn, 800 - 2 * PlainSimpleM.centredMovieRail,
                       "the 560 box stepped in two 40 units each side — the construction's own re-cut rule")
        XCTAssertEqual(PlainSimpleM.mediaBoxHeight, PlainSimpleM.movieBoxHeight)
    }

    /// E opens at 200 and H at 202; both movies are 225 tall.
    func testEAndHShareTheFrameAndDifferOnlyByTheHero() {
        let eBottom = PlainSimpleM.contentBoxTopNoHero + PlainSimpleM.mediaBoxHeight
        let hBottom = PlainSimpleM.contentBoxTop + PlainSimpleM.mediaBoxHeight
        XCTAssertEqual(eBottom, 425)
        XCTAssertEqual(hBottom, 427)
        XCTAssertEqual(hBottom - eBottom, 2, "the only y the two screens do not share")
    }

    /// Media step at 600: media ends 425, strip 453 → 509, band at 516 (28 above the strip, 7 below).
    func testTheInstallStripSitsBetweenTheMovieAndTheFooter() {
        let mediaBottom = PlainSimpleM.contentBoxTopNoHero + PlainSimpleM.mediaBoxHeight
        let stripBottom = PlainSimpleM.installStripTop + PlainSimpleM.installStripHeight
        XCTAssertEqual(PlainSimpleM.installStripTop - mediaBottom, 28, accuracy: 0.001)
        XCTAssertEqual(stripBottom, 509)
        XCTAssertGreaterThanOrEqual(PlainSimpleM.footerBandTop, stripBottom, "the strip must not enter the band")
        XCTAssertEqual(PlainSimpleM.footerBandTop - stripBottom, 7, accuracy: 0.001,
                       "7 clear to the band — the strip is the tightest thing on the screen")
    }

    /// The pager is pinned at 455, 28 below the movie's 427; it does not rise for a shorter movie.
    func testThePagerIsPinnedBelowTheFrame() {
        XCTAssertEqual(PlainSimpleM.pagerTop - (PlainSimpleM.contentBoxTop + PlainSimpleM.mediaBoxHeight),
                       28, accuracy: 0.001)
    }

    /// Pager arrows are absolute positions, so two dots and four dots put them in the same place.
    func testThePagerArrowsDoNotDependOnPageCount() {
        XCTAssertEqual(PlainSimpleM.pagerArrowLeadingX, 318)
        XCTAssertEqual(PlainSimpleM.pagerArrowTrailingX, 448)
        // The dot region is symmetric about the window axis, so dots grow inward without moving an arrow.
        let regionStart = PlainSimpleM.pagerArrowLeadingX + PlainSimpleM.pagerArrowSize
        let regionEnd = PlainSimpleM.pagerArrowTrailingX
        XCTAssertEqual((regionStart + regionEnd) / 2, PlainSimpleM.windowAxis,
                       "the dots centre on 400, so their count cannot move the arrows")
    }

    /// The gate line sits under the pager: 498 + 15 = 513, clear of the band at 516.
    func testTheGateLineSitsUnderThePagerAndAboveTheFooter() {
        XCTAssertGreaterThan(PlainSimpleM.gateLineTop, PlainSimpleM.pagerTop + PlainSimpleM.pagerArrowSize)
        XCTAssertLessThan(PlainSimpleM.gateLineTop + 15, PlainSimpleM.footerBandTop,
                          "the line itself, not just its top, stays out of the band")
    }

    /// The tour is a step: Install → Tour → All set is three.
    func testTheTourAddsAStep() {
        let p = PlainStepPosition.position(phase: .tour, hasIntro: false, hasTour: true, hasSummary: true)
        XCTAssertEqual(p?.current, 2)
        XCTAssertEqual(p?.total, 3, "Install, Tour, All set")
        XCTAssertEqual(PlainStepPosition.position(phase: .summary, hasIntro: false, hasTour: true, hasSummary: true)?.current, 3)
    }

    /// Without a tour the totals are unchanged.
    func testNoTourLeavesTheCountAlone() {
        XCTAssertEqual(PlainStepPosition.position(phase: .main, hasIntro: false, hasTour: false, hasSummary: true)?.total, 2)
    }
}

/// The centred media step and walkthrough page swap with the leading pair without the window moving:
/// same box top, pager and footer; only rail and text alignment differ.
final class PlainSimpleCentredVariantTests: XCTestCase {

    /// Both variants draw the one 400 × 225 movie: leading on the media rail, centred on the axis.
    func testBothVariantsDrawTheOneMovie() {
        XCTAssertEqual(PlainSimpleM.centredMovieRail - PlainSimpleM.mediaRail, 80, "two 40 units")
        XCTAssertEqual(PlainSimpleM.mediaRail(centred: false), PlainSimpleM.mediaRail)
        XCTAssertEqual(PlainSimpleM.mediaRail(centred: true), PlainSimpleM.centredMovieRail)
        for centred in [false, true] {
            XCTAssertEqual(PlainSimpleM.mediaColumn(centred: centred), PlainSimpleM.movieColumn)
            XCTAssertEqual(PlainSimpleM.mediaBoxHeight(centred: centred), PlainSimpleM.movieBoxHeight)
        }
    }

    /// Centred is the default; only "leading" (any case) opts out.
    func testCentredIsTheDefaultAndLeadingOptsOut() {
        XCTAssertTrue(PlainSimpleM.isCentred(authored: nil))
        XCTAssertTrue(PlainSimpleM.isCentred(authored: "center"))
        XCTAssertFalse(PlainSimpleM.isCentred(authored: "leading"))
        XCTAssertFalse(PlainSimpleM.isCentred(authored: "Leading"))
    }

    /// Centred media is centred on the window axis.
    func testTheCentredMediaIsCentredOnTheAxis() {
        let centre = PlainSimpleM.centredMovieRail + PlainSimpleM.movieColumn / 2
        XCTAssertEqual(centre, PlainSimpleM.windowAxis, "200 + 200 = 400")
    }

    /// The box top is identical in both variants.
    func testTheBoxTopIsIdenticalInBothVariants() {
        XCTAssertEqual(PlainSimpleM.contentBoxTopNoHero, 200, "one top for every no-hero screen")
        XCTAssertEqual(PlainSimpleM.contentBoxTop, 202, "one top for every hero screen")
    }

    /// The strip follows the movie by 28, landing on 453 in both variants.
    func testTheInstallStripFollowsTheMovie() {
        XCTAssertEqual(PlainSimpleM.installStripTop(centred: false), 453)
        XCTAssertEqual(PlainSimpleM.installStripTop(centred: true), 453)
        for centred in [false, true] {
            let gap = PlainSimpleM.installStripTop(centred: centred)
                - (PlainSimpleM.contentBoxTopNoHero + PlainSimpleM.mediaBoxHeight(centred: centred))
            XCTAssertEqual(gap, PlainSimpleM.installStripGap, accuracy: 0.001)
        }
    }

    /// The strip shares the movie's column rather than filling the window.
    func testTheStripNeverOutgrowsItsMovie() {
        for centred in [false, true] {
            XCTAssertEqual(PlainSimpleM.installStripWidth(centred: centred),
                           PlainSimpleM.mediaColumn(centred: centred))
        }
    }

    /// The pager is identical across variants.
    func testThePagerIsIdenticalAcrossTheVariant() {
        XCTAssertEqual(PlainSimpleM.pagerArrowLeadingX, 318)
        XCTAssertEqual(PlainSimpleM.pagerArrowTrailingX, 448)
        XCTAssertEqual(PlainSimpleM.pagerTop, 455)
    }
}

/// Guidance-block spacing: gaps come from an 8-unit scale, and the larger gap sits below a block.
final class GuidanceBlockSpacingTests: XCTestCase {

    private let scale: Set<CGFloat> = [GuidanceBlockSpacing.tight, GuidanceBlockSpacing.base,
                                       GuidanceBlockSpacing.section, GuidanceBlockSpacing.wide]

    /// Every gap is on the 8-unit scale.
    func testEveryGapComesFromTheScale() {
        let roles: [GuidanceBlockRole] = [.label, .prose, .data, .list, .state, .media]
        for a in roles {
            for b in roles {
                let gap = GuidanceBlockSpacing.gap(below: a, above: b)
                XCTAssertTrue(scale.contains(gap), "gap \(a) → \(b) = \(gap) is off the scale")
                XCTAssertEqual(gap.truncatingRemainder(dividingBy: 8), 0, "every value is a multiple of 8")
            }
        }
    }

    /// The gap around a heading is asymmetric: wide above, tight to what it labels.
    func testTheGapAroundAHeadingIsAsymmetric() {
        let above = GuidanceBlockSpacing.gap(below: .list, above: .label)   // section → heading
        let below = GuidanceBlockSpacing.gap(below: .label, above: .data)   // heading → its content
        XCTAssertGreaterThan(above, below,
                             "a label must bind DOWN to what it labels and separate UP from the section before")
        XCTAssertEqual(above, GuidanceBlockSpacing.section)
        XCTAssertEqual(below, GuidanceBlockSpacing.tight)
    }

    /// A heading is never closer to what precedes it than to what follows.
    func testAHeadingIsNeverCloserToWhatPrecedesIt() {
        for content: GuidanceBlockRole in [.prose, .data, .list, .state, .media] {
            let above = GuidanceBlockSpacing.gap(below: content, above: .label)
            let below = GuidanceBlockSpacing.gap(below: .label, above: content)
            XCTAssertGreaterThan(above, below, "label between two \(content) blocks reads as a caption")
        }
    }

    /// The state block takes the widest interior gap, set apart from the argument above.
    func testTheStateBlockSitsApartFromTheArgumentAboveIt() {
        XCTAssertEqual(GuidanceBlockSpacing.gap(below: .list, above: .state), GuidanceBlockSpacing.wide)
        XCTAssertGreaterThan(GuidanceBlockSpacing.gap(below: .list, above: .state),
                             GuidanceBlockSpacing.gap(below: .list, above: .list))
    }

    /// Two of a kind run on; a change of register separates.
    func testAChangeOfRegisterSeparatesMoreThanARunOfOneKind() {
        XCTAssertEqual(GuidanceBlockSpacing.gap(below: .prose, above: .prose), GuidanceBlockSpacing.base)
        XCTAssertEqual(GuidanceBlockSpacing.gap(below: .prose, above: .data), GuidanceBlockSpacing.section)
    }

    /// Block types map to roles, so a new type inherits a considered gap.
    func testBlockTypesMapToTheirRole() {
        XCTAssertEqual(GuidanceBlockRole(blockType: "comparison-table"), .data)
        XCTAssertEqual(GuidanceBlockRole(blockType: "phase-tracker"), .state)
        XCTAssertEqual(GuidanceBlockRole(blockType: "bullets"), .list)
        XCTAssertEqual(GuidanceBlockRole(blockType: "warning"), .prose)
        XCTAssertEqual(GuidanceBlockRole(blockType: "compliance-header"), .label)
        XCTAssertEqual(GuidanceBlockRole(blockType: "video"), .media)
        XCTAssertEqual(GuidanceBlockRole(blockType: "some-future-type"), .prose,
                       "an unknown type gets prose spacing rather than crashing or defaulting to 0")
    }
}

extension GuidanceBlockRole: @retroactive Equatable {}
