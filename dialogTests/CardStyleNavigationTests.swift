//
//  CardStyleNavigationTests.swift
//  dialogTests
//
//  Covers the navigation card style (`"cardstyle": "navigation"`): style detection, sidebar
//  sections and labels, stripping of window-level keys, required-field pre-scan, page selection
//  and variable substitution across pages.
//

import Testing
import SwiftyJSON
@testable import Dialog

struct CardStyleNavigationTests {

    private func load(_ json: JSON) -> CardState {
        let state = CardState()
        _ = state.loadCards(from: json)
        return state
    }

    private var navigationJSON: JSON {
        JSON([
            "cardstyle": "navigation",
            "title": "Global Title",
            "cards": [
                ["cardId": "a", "section": "One", "title": "Alpha", "icon": "SF=star", "width": 1200, "nextpage": 2],
                ["cardId": "b", "section": "One", "sidebartitle": "Short", "title": "Bravo Long Title",
                 "textfield": [["title": "Name", "required": true]]],
                ["cardId": "c", "section": "Two", "icon": "none"],
                ["cardId": "d", "selectitems": [["title": "Pick", "values": ["x"], "required": true]]]
            ]
        ])
    }

    @Test func wizardIsDefaultStyle() {
        let state = load(JSON(["cards": [["title": "One"], ["title": "Two"]]]))
        #expect(state.isWizardMode)
        #expect(!state.isNavigationStyle)
        #expect(state.pageIssues.isEmpty)
    }

    @Test func unknownStyleFallsBackToWizard() {
        let state = load(JSON(["cardstyle": "carousel", "cards": [["title": "One"]]]))
        #expect(state.style == .wizard)
    }

    @Test func navigationStyleDetected() {
        let state = load(navigationJSON)
        #expect(state.isNavigationStyle)
        #expect(!state.isWizardMode)
    }

    @Test func sectionsGroupConsecutiveCards() {
        let sections = load(navigationJSON).sections
        #expect(sections.map(\.title) == ["One", "Two", nil])
        #expect(sections.map(\.cardIndices) == [[0, 1], [2], [3]])
    }

    @Test func sidebarLabelsUseCardValuesNotInheritedOnes() {
        let cards = load(navigationJSON).cards
        #expect(cards[0].sidebarTitle == "Alpha")
        #expect(cards[1].sidebarTitle == "Short")
        // No title of its own - the global "Global Title" must not be repeated on the row
        #expect(cards[2].sidebarTitle == nil)
        #expect(cards[0].sidebarIcon == "SF=star")
        #expect(cards[2].sidebarIcon == nil)
        #expect(cards[3].sidebarIcon == nil)
    }

    @Test func windowAndRoutingKeysAreStrippedFromCards() {
        let state = load(navigationJSON)
        let first = state.cards[0].configuration
        #expect(!first["width"].exists())
        #expect(!first["nextpage"].exists())
        // Cards fall back to the navigation default window size
        #expect(state.getMergedConfiguration(for: state.cards[0])["width"].intValue == 900)
    }

    @Test func infoboxIsUnavailableInNavigationStyle() {
        let state = load(JSON([
            "cardstyle": "navigation",
            "infobox": "global info",
            "cards": [["title": "One", "infobox": "card info", "infoboxwidth": 200]]
        ]))
        let merged = state.getMergedConfiguration(for: state.cards[0])
        #expect(!merged["infobox"].exists())
        #expect(!merged["infoboxwidth"].exists())
    }

    @Test func wizardKeepsPerCardKeys() {
        let state = load(JSON(["cards": [["title": "One", "width": 1200, "nextpage": 1], ["title": "Two"]]]))
        #expect(state.cards[0].configuration["width"].intValue == 1200)
        #expect(state.cards[0].nextPageOverride == 1)
    }

    @Test func pagesWithRequiredFieldsStartIncomplete() {
        let state = load(navigationJSON)
        #expect(Set(state.pageIssues.keys) == [1, 3])
    }

    @Test func issuesHiddenUntilPageVisited() {
        let state = load(navigationJSON)
        // Pre-scanned issue exists (blocks Done) but is not shown yet
        #expect(state.pageIssues[1] != nil)
        #expect(state.visibleIssue(for: 1) == nil)

        state.visitedPages.insert(1)
        #expect(state.visibleIssue(for: 1) != nil)
        // Visited but complete pages show nothing
        state.visitedPages.insert(0)
        #expect(state.visibleIssue(for: 0) == nil)
    }

    @Test func sectionIdsDoNotCollideWithCardIndexTags() {
        // Section ids are used as implicit List tags; they must not be Ints matching card indices
        let ids = load(navigationJSON).sections.map(\.id)
        #expect(ids == ["section-0", "section-1", "section-2"])
    }

    @Test func selectChangesPageWithoutHistory() {
        let state = load(navigationJSON)
        #expect(state.select(index: 2))
        #expect(state.currentCardIndex == 2)
        #expect(!state.select(index: 2))   // already selected
        #expect(!state.select(index: 9))   // out of range
        #expect(!state.hasPreviousCard)    // the sidebar replaces Back
    }

    @Test func selectIsIgnoredInWizardStyle() {
        let state = load(JSON(["cards": [["title": "One"], ["title": "Two"]]]))
        #expect(!state.select(index: 1))
        #expect(state.currentCardIndex == 0)
    }

    @Test func variablesComeFromAnyOtherVisitedPage() {
        let state = load(navigationJSON)
        _ = state.select(index: 3)
        state.storeCurrentCardInput(["later": "value-from-page-4"])
        _ = state.select(index: 1)
        state.storeCurrentCardInput(["own": "current-page"])

        let variables = state.getInputAsVariables()
        #expect(variables["later"] == "value-from-page-4")
        // The current page's own input is not substituted into itself
        #expect(variables["own"] == nil)
    }

    @Test func resetRestoresWizardStyle() {
        let state = load(navigationJSON)
        state.reset()
        #expect(state.style == .wizard)
        #expect(state.pageIssues.isEmpty)
        #expect(state.visitedPages.isEmpty)
    }
}
