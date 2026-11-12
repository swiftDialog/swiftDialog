//
//  PortalChromeTests.swift
//  dialogTests
//
//  The web-view chrome: viewport geometry derived from the window, the host-first address readout
//  (a security affordance), and the failure truth table that never strands the user.
//

import XCTest
import SwiftUI
@testable import Dialog

final class PortalChromeTests: XCTestCase {

    // MARK: - Geometry by construction

    func testViewportIsWhateverTheFooterLeaves() {
        // One webview, no title bar, an 84 footer: 600 − 84 = 516.
        XCTAssertEqual(PortalGeometry.viewportHeight(windowHeight: 600, layout: .bar), 516)
        XCTAssertEqual(PortalGeometry.footerHeight, SetupAssistantM.footerHeight,
                       "the portal footer is the setup-assistant's row, read from it, not copied")
    }

    func testBarLayoutViewportFollowsTheWindowRatherThanAConstant() {
        // A 700-tall window gets 616, which a hardcoded 516 would not.
        XCTAssertEqual(PortalGeometry.viewportHeight(windowHeight: 700, layout: .bar), 616)
    }

    func testViewportNeverGoesNegativeInAnAbsurdlyShortWindow() {
        XCTAssertEqual(PortalGeometry.viewportHeight(windowHeight: 40, layout: .bar), 0)
    }

    func testBarViewportAtTheDefaultSizeClearsTheMobileBreakpoint() {
        // 800pt of width stays above the ~700 where sites switch to mobile layouts.
        XCTAssertGreaterThan(CGFloat(800), PortalGeometry.mobileBreakpoint)
    }

    // MARK: - Layout parsing

    func testUnknownAndAbsentLayoutsDegradeToTheMoreNavigableVariant() {
        // A typo, an absent word and a case variant all land on `.bar`, never on something chromeless.
        XCTAssertEqual(PortalLayout(nil), .bar)
        XCTAssertEqual(PortalLayout(""), .bar)
        XCTAssertEqual(PortalLayout("bogus"), .bar)
        XCTAssertEqual(PortalLayout("Bar"), .bar)
    }

    func testARetiredLayoutNameDegradesToTheMostNavigableScreen() {
        // Retired `fullbleed` resolves to `.bar` like any unknown value.
        XCTAssertEqual(PortalLayout("fullbleed"), .bar)
    }

    func testFooterLayoutParses() {
        XCTAssertEqual(PortalLayout("footer"), .footer)
    }

    func testEveryRemainingLayoutDrawsTheBrandedFooter() {
        // Both layout words draw the branded footer, so `drawsCornerLogo` asks `isPortalStep` alone.
        XCTAssertEqual(PortalLayout.allCases.count, 2)
        XCTAssertEqual(Set(PortalLayout.allCases.map(\.rawValue)), ["bar", "footer"])
    }

    func testEveryLayoutPaysOnlyForTheFooter() {
        // `footer` and `bar` reserve the same band.
        XCTAssertEqual(PortalGeometry.viewportHeight(windowHeight: 600, layout: .footer), 516)
        XCTAssertEqual(PortalGeometry.viewportHeight(windowHeight: 600, layout: .footer),
                       PortalGeometry.viewportHeight(windowHeight: 600, layout: .bar))
    }

    func testEveryLayoutIsCoveredByTheGeometry() {
        // Every layout word leaves the page a viewport.
        for layout in PortalLayout.allCases {
            XCTAssertGreaterThan(PortalGeometry.viewportHeight(windowHeight: 600, layout: layout), 0,
                                 "\(layout) has no viewport")
        }
    }

    // MARK: - Address readout

    func testBarFormShowsTheFullAddress() throws {
        let url = try XCTUnwrap(URL(string: "https://github.com/macadmins"))
        XCTAssertEqual(PortalURLDisplay.full(url), "https://github.com/macadmins")
    }

    func testOverlayFormDropsTheSchemeButKeepsHostAndPath() throws {
        let url = try XCTUnwrap(URL(string: "https://github.com/macadmins"))
        XCTAssertEqual(PortalURLDisplay.compact(url), "github.com/macadmins")
    }

    func testTrailingSlashIsTrimmedSoTheReadoutIsStable() throws {
        let url = try XCTUnwrap(URL(string: "https://github.com/"))
        XCTAssertEqual(PortalURLDisplay.compact(url), "github.com")
    }

    func testHostLeadsBothFormsSoTruncationCanOnlyEatTheTail() throws {
        // The chip truncates with .tail, which is safe only because the host leads the string.
        let url = try XCTUnwrap(URL(string: "https://portal.example.com/a/very/long/path/that/keeps/going/and/going"))
        XCTAssertTrue(PortalURLDisplay.compact(url).hasPrefix("portal.example.com"))
        XCTAssertTrue(PortalURLDisplay.full(url).hasPrefix("https://portal.example.com"))
    }

    func testHostAloneIsWhatTheFailureHeadlineUses() throws {
        let url = try XCTUnwrap(URL(string: "https://github.com/macadmins"))
        XCTAssertEqual(PortalURLDisplay.host(url), "github.com")
    }

    func testOnlyHTTPSEarnsTheClosedPadlock() throws {
        let secure = try XCTUnwrap(URL(string: "https://github.com"))
        let plain = try XCTUnwrap(URL(string: "http://intranet.local"))

        XCTAssertTrue(PortalURLDisplay.isSecure(secure))
        XCTAssertFalse(PortalURLDisplay.isSecure(plain))
        XCTAssertEqual(PortalURLDisplay.schemeSymbol(secure), "lock.fill")
        XCTAssertNotEqual(PortalURLDisplay.schemeSymbol(plain), "lock.fill")
    }

    // MARK: - The address is unconditional

    func testThereIsNoWayToSuppressTheAddress() {
        // `portalFooterLead` has no parameter that could suppress the address.
        XCTAssertEqual(portalFooterLead(hasURL: true, hasFooterText: true), .address)
        XCTAssertEqual(portalFooterLead(hasURL: true, hasFooterText: false), .address)
    }

    func testEveryLayoutSpellingStillDecodes() {
        for raw in ["bar", "footer"] {
            XCTAssertEqual(PortalLayout(raw).rawValue, raw)
        }
    }

    // MARK: - Footer leading slot

    func testTheFooterLeadsWithTheAddressWheneverThereIsOne() {
        XCTAssertEqual(portalFooterLead(hasURL: true, hasFooterText: true), .address)
    }

    func testBeforeTheFirstNavigationTheSlotFallsBackRatherThanShowingAnEmptyChip() {
        // No URL yet is a timing fact, not an author choice.
        XCTAssertEqual(portalFooterLead(hasURL: false, hasFooterText: true), .brandText)
        XCTAssertEqual(portalFooterLead(hasURL: false, hasFooterText: false), .nothing)
    }

    func testHidingTheAddressCanNeverHideTheWayOut() {
        // Whether the footer repeats the escape depends on layout alone; `footerRepeatsEscape` takes no flag.
        XCTAssertTrue(PortalLayout.bar.footerRepeatsEscape)
        XCTAssertTrue(PortalLayout.footer.footerRepeatsEscape)
    }

    // MARK: - Diagnostic line

    func testKnownURLErrorCodesGetTheirSymbolicName() {
        XCTAssertEqual(PortalLoadFailure.symbolicName(forURLErrorCode: NSURLErrorCannotConnectToHost),
                       "NSURLErrorCannotConnectToHost")
        XCTAssertEqual(PortalLoadFailure.symbolicName(forURLErrorCode: NSURLErrorCannotFindHost),
                       "NSURLErrorCannotFindHost")
        XCTAssertEqual(PortalLoadFailure.symbolicName(forURLErrorCode: NSURLErrorNotConnectedToInternet),
                       "NSURLErrorNotConnectedToInternet")
    }

    func testUnmappedCodesSaySoRatherThanGuessing() {
        XCTAssertEqual(PortalLoadFailure.symbolicName(forURLErrorCode: -9999), "URLError -9999")
    }

    func testDiagnosticMatchesTheLineTheDesignPrints() {
        let failure = PortalLoadFailure(
            message: "Your network blocks it, or it is down.",
            symbolicCode: "NSURLErrorCannotConnectToHost",
            code: -1004,
            host: "github.com"
        )
        XCTAssertEqual(failure.diagnostic, "NSURLErrorCannotConnectToHost · -1004")
    }

    func testFailureWithNoUnderlyingCodeOmitsTheDiagnosticRatherThanInventingOne() {
        // The page loaded but its content reads as an error: no code to show.
        let failure = PortalLoadFailure(message: "The page reported an error.", host: "example.com")
        XCTAssertNil(failure.diagnostic)
    }

    func testHTTPStatusIsQuotableToo() {
        let failure = PortalLoadFailure(message: "Page not found",
                                        symbolicCode: "HTTP", code: 404, host: "example.com")
        XCTAssertEqual(failure.diagnostic, "HTTP · 404")
    }

    func testLoadStateCarriesTheFailureThrough() {
        let state = PortalLoadState.error(PortalLoadFailure(message: "boom", code: -1004))
        XCTAssertTrue(state.isError)
        XCTAssertEqual(state.failure?.code, -1004)
        XCTAssertNil(PortalLoadState.loaded.failure)
    }

    func testMessageOnlyFailuresStillConstructCleanly() {
        // The convenience overload for call sites with nothing else to report.
        let state = PortalLoadState.error("Session expired")
        XCTAssertEqual(state.failure?.message, "Session expired")
        XCTAssertNil(state.failure?.diagnostic)
    }

    // MARK: - Failure affordances

    func testHealthyStepOffersDoneAndWhateverSkipWasAuthored() {
        XCTAssertEqual(portalFailureAffordances(hasSkip: false, isFailed: false),
                       PortalFailureAffordances(doneEnabled: true, skipEnabled: false))
        XCTAssertEqual(portalFailureAffordances(hasSkip: true, isFailed: false),
                       PortalFailureAffordances(doneEnabled: true, skipEnabled: true))
    }

    func testFailedStepWithASkipGreysDoneAndKeepsSkipLive() {
        // Done greys out only because Skip can carry the user forward.
        XCTAssertEqual(portalFailureAffordances(hasSkip: true, isFailed: true),
                       PortalFailureAffordances(doneEnabled: false, skipEnabled: true))
    }

    func testFailedStepWithNoSkipKeepsDoneLiveSoNobodyIsStranded() {
        // Without Skip, Done stays live: a page that is down must never strand someone.
        let affordances = portalFailureAffordances(hasSkip: false, isFailed: true)
        XCTAssertTrue(affordances.doneEnabled,
                      "Done must stay enabled when there is no Skip — otherwise a failed page traps the user")
        XCTAssertFalse(affordances.skipEnabled)
    }

    func testAFailureNeverDisablesAnExistingSkip() {
        // A failure is never the reason Skip is unavailable.
        for isFailed in [true, false] {
            XCTAssertTrue(portalFailureAffordances(hasSkip: true, isFailed: isFailed).skipEnabled)
        }
    }

    func testThereIsAlwaysAtLeastOneWayForward() {
        // There is always a way forward.
        for hasSkip in [true, false] {
            for isFailed in [true, false] {
                let a = portalFailureAffordances(hasSkip: hasSkip, isFailed: isFailed)
                XCTAssertTrue(a.doneEnabled || a.skipEnabled,
                              "hasSkip=\(hasSkip) isFailed=\(isFailed) left no exit")
            }
        }
    }

    // MARK: - Browser escape

    func testEscapeIsLabelledForTheBrowserWeActuallyOpen() {
        // NSWorkspace opens the default browser, which may not be Safari.
        XCTAssertEqual(PortalBrowserEscape.label, "Open in Browser")
        XCTAssertFalse(PortalBrowserEscape.label.contains("Safari"))
    }

    // MARK: - Per-block portal configuration

    /// A `portal-webview` block carries its own `portalConfig`; `openExternalLinksInBrowser` exists
    /// only there, with no flat block key.
    func testBlockCarriesItsOwnPortalConfigForTheBehaviourFlags() throws {
        let json = """
        {
          "type": "portal-webview",
          "portalHeight": 220,
          "portalConfig": {
            "portalURL": "https://selfservice.example",
            "openExternalLinksInBrowser": false,
            "selfServicePath": "/browse"
          }
        }
        """
        let block = try JSONDecoder().decode(InspectConfig.GuidanceContent.self,
                                             from: Data(json.utf8))
        let portal = try XCTUnwrap(block.portalConfig,
                                   "the block must carry its own portal config")
        // `selfServicePath` is a key a real config authors.
        XCTAssertEqual(portal.openExternalLinksInBrowser, false)
        XCTAssertEqual(portal.selfServicePath, "/browse")
        XCTAssertEqual(portal.portalURL, "https://selfservice.example")
    }

    /// A block without its own config falls back to the global one.
    func testABlockWithoutItsOwnConfigStillFallsBackToTheGlobalOne() throws {
        let json = #"{"type": "portal-webview", "portalURL": "https://a.example"}"#
        let block = try JSONDecoder().decode(InspectConfig.GuidanceContent.self,
                                             from: Data(json.utf8))
        XCTAssertNil(block.portalConfig,
                     "no authored portalConfig must stay nil so `block ?? config` picks the global")
        // The flat key is untouched and still outranks the object at the call site.
        XCTAssertEqual(block.portalURL, "https://a.example")
    }

    // MARK: - Card portal contract

    private func cardModel(layout: String?, skip: String? = nil,
                           back: String? = nil) -> CardPortalModel {
        CardPortalModel(title: "T", layout: PortalLayout(layout),
                        displayURL: URL(string: "https://example.com/x"),
                        isLoading: false, footerText: nil,
                        footerBackground: nil, footerTextColor: nil, logoPath: nil,
                        accent: .blue,
                        doneText: "Done", backText: back, skipText: skip, doneEnabled: true)
    }

    /// Every layout word (authored, absent, retired) reaches the one webview, whose footer carries the escape.
    func testEveryLayoutWordReachesTheOneWebview() {
        for word in [nil, "bar", "footer", "fullbleed", "bogus"] {
            XCTAssertTrue(cardModel(layout: word).footerRepeatsEscape,
                          "\(word ?? "nil") must reach the footer's escape")
        }
    }

    /// A skip label authored on the step reaches the action bar as a label.
    func testAnAuthoredSkipTravelsToTheActionBar() {
        XCTAssertEqual(cardModel(layout: "footer", skip: "Skip this step").skipText,
                       "Skip this step")
        XCTAssertNil(cardModel(layout: "footer").skipText)
    }
}
