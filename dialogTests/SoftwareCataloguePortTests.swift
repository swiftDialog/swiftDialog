//
//  SoftwareCataloguePortTests.swift
//  dialogTests
//
//  The software catalogue's row and bundle rules, the action defaults, the block payloads and the
//  fold, proved as pure functions across all five states.

import XCTest
@testable import Dialog

final class SoftwareCataloguePortTests: XCTestCase {

    func testPendingOffersInstallAsARequest() {
        let a = SoftwareRowRule.action(for: .pending, openURL: nil, appBundleId: "com.acme.App", firstPath: nil)
        XCTAssertEqual(a.label, "Install")
        XCTAssertEqual(a.action, "request")
        XCTAssertEqual(a.requestId, "install-item")
    }

    func testActiveOffersCancel() {
        let a = SoftwareRowRule.action(for: .active, openURL: nil, appBundleId: "com.acme.App", firstPath: nil)
        XCTAssertEqual(a.label, "Cancel")
        XCTAssertEqual(a.requestId, "cancel-item")
    }

    func testFailedOffersRetry() {
        let a = SoftwareRowRule.action(for: .failed, openURL: nil, appBundleId: "com.acme.App", firstPath: nil)
        XCTAssertEqual(a.label, "Retry")
        XCTAssertEqual(a.requestId, "retry-item")
    }

    /// The app said where "Open" should land.
    func testCompletedPrefersTheAuthoredOpenURL() {
        let a = SoftwareRowRule.action(for: .completed, openURL: "acme://home", appBundleId: "com.acme.App", firstPath: nil)
        XCTAssertEqual(a.label, "Open")
        XCTAssertEqual(a.action, "url")
        XCTAssertEqual(a.url, "acme://home")
    }

    /// Without an open URL, "Open" launches the app (`app`), not a custom scheme the app may refuse.
    func testCompletedWithoutAnOpenURLLaunchesTheAppItself() {
        let a = SoftwareRowRule.action(for: .completed, openURL: nil, appBundleId: "com.acme.App", firstPath: "/Applications/Acme.app")
        XCTAssertEqual(a.action, "app")
        XCTAssertEqual(a.url, "com.acme.App")
    }

    func testCompletedFallsBackToTheFirstPathWhenThereIsNoBundleId() {
        let a = SoftwareRowRule.action(for: .completed, openURL: nil, appBundleId: nil, firstPath: "/Applications/Acme.app")
        XCTAssertEqual(a.action, "app")
        XCTAssertEqual(a.url, "/Applications/Acme.app")
    }

    /// With no identity to launch, the row offers no action.
    func testCompletedWithNoIdentityAtAllOffersNoButton() {
        let a = SoftwareRowRule.action(for: .completed, openURL: nil, appBundleId: nil, firstPath: nil)
        XCTAssertNil(a.label)
    }

    /// A skipped item offers no action; "Install" would undo a recorded decision.
    func testSkippedOffersNoActionAtAll() {
        let a = SoftwareRowRule.action(for: .skipped, openURL: "acme://home", appBundleId: "com.acme.App", firstPath: "/Applications/Acme.app")
        XCTAssertNil(a.label)
        XCTAssertNil(a.action)
    }

    // MARK: - Bundle tally

    func testBundleWithEverythingInstalledOffersDetails() {
        XCTAssertEqual(BundleTally(statuses: [.completed, .completed]).defaultActionLabel, "Details")
    }

    func testPartiallyInstalledBundleOffersComplete() {
        XCTAssertEqual(BundleTally(statuses: [.completed, .pending]).defaultActionLabel, "Complete")
    }

    func testEmptyBundleOffersInstall() {
        XCTAssertEqual(BundleTally(statuses: [.pending, .pending]).defaultActionLabel, "Install")
    }

    /// A failure outranks the rest and states its count.
    func testAnyFailureOutranksTheRestAndCountsItself() {
        XCTAssertEqual(BundleTally(statuses: [.completed, .failed, .failed]).defaultActionLabel, "Retry 2")
    }

    func testAnInstallInFlightOutranksACompletedMajority() {
        XCTAssertEqual(BundleTally(statuses: [.completed, .completed, .active]).defaultActionLabel, "Installing…")
    }

    // MARK: - Action verb default

    /// An authored bundle action with no `action` key defaults to `request` (fires the install, not the detail screen).
    func testBundleActionWithNoAuthoredVerbDefaultsToRequest() {
        let action = InspectConfig.SoftwareBundle.BundleAction(
            label: "Install {missing} missing", action: nil, url: nil, requestId: "install-bundle")
        XCTAssertEqual(SoftwareBundleActionRule.resolvedVerb(for: action), "request")
    }

    func testBundleActionKeepsAnExplicitVerb() {
        let action = InspectConfig.SoftwareBundle.BundleAction(
            label: "Open", action: "url", url: "https://example.com", requestId: nil)
        XCTAssertEqual(SoftwareBundleActionRule.resolvedVerb(for: action), "url")
    }

    /// No authored `BundleAction` resolves to nil, which routes to the detail screen when one exists.
    func testNoAuthoredBundleActionResolvesToNilVerb() {
        XCTAssertNil(SoftwareBundleActionRule.resolvedVerb(for: nil))
    }

    // MARK: - Block payloads

    /// `bundle-list`: what the row draws, plus the counted tally and the arm's detail decision.
    func testBundleListPayloadDecodes() throws {
        let json = #"""
        {"type":"bundle-list","bundleRows":[
          {"id":"essentials","title":"Essentials","summary":"Figma, Slack","size":"6.8 GB",
           "icons":[{"icon":"figma","appBundleId":"com.figma.Desktop","paths":["/Applications/Figma.app"],"status":"completed"}],
           "installedCount":1,"totalCount":2,"hasDetail":true,
           "actionLabel":"Complete","action":"request","actionURL":null,"requestId":"install-item"}
        ]}
        """#
        let block = try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
        let row = try XCTUnwrap(block.bundleRows?.first)
        XCTAssertEqual(row.bundleId, "essentials")
        XCTAssertEqual(row.title, "Essentials")
        XCTAssertEqual(row.summary, "Figma, Slack")
        XCTAssertEqual(row.size, "6.8 GB")
        XCTAssertEqual(row.icons?.first?.icon, "figma")
        XCTAssertEqual(row.icons?.first?.status, "completed")
        XCTAssertEqual(row.installedCount, 1)
        XCTAssertEqual(row.totalCount, 2)
        XCTAssertTrue(row.hasDetail)
    }

    /// `bundle-detail`: one app, including the version detail that only exists once installed.
    func testBundleDetailPayloadDecodes() throws {
        let json = #"""
        {"type":"bundle-detail","detailRows":[
          {"itemId":"figma","displayName":"Figma","icon":"figma","appBundleId":"com.figma.Desktop",
           "paths":["/Applications/Figma.app"],"status":"completed","detail":"124.6.2 (build 3)",
           "actionLabel":"Open","action":"app","actionURL":"com.figma.Desktop","requestId":null}
        ]}
        """#
        let block = try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
        let row = try XCTUnwrap(block.detailRows?.first)
        XCTAssertEqual(row.itemId, "figma")
        XCTAssertEqual(row.displayName, "Figma")
        XCTAssertEqual(row.detail, "124.6.2 (build 3)")
        XCTAssertEqual(row.status, "completed")
    }

    /// A row's resolved action survives the round trip.
    func testResolvedActionFieldsSurviveTheRoundTrip() throws {
        let json = #"""
        {"type":"bundle-list","bundleRows":[
          {"id":"data","title":"Data","summary":null,"size":null,"icons":[],
           "installedCount":0,"totalCount":2,"hasDetail":false,
           "actionLabel":"Install","action":"request","actionURL":null,"requestId":"install-item"}
        ]}
        """#
        let block = try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
        let row = try XCTUnwrap(block.bundleRows?.first)
        XCTAssertEqual(row.actionLabel, "Install")
        XCTAssertEqual(row.action, "request")
        XCTAssertNil(row.actionURL)
        XCTAssertEqual(row.requestId, "install-item")
    }

    /// `installedCount`/`totalCount` are optional; the counts are only a fallback when `icons` is empty.
    func testBundleListPayloadDecodesWithoutCounts() throws {
        let json = #"""
        {"type":"bundle-list","bundleRows":[
          {"id":"essentials","title":"Essentials","hasDetail":false,
           "icons":[{"icon":"figma","status":"completed"}]}
        ]}
        """#
        let block = try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
        let row = try XCTUnwrap(block.bundleRows?.first)
        XCTAssertNil(row.installedCount)
        XCTAssertNil(row.totalCount)
        XCTAssertEqual(row.icons?.first?.icon, "figma")
    }

    // MARK: - Fold
    // `foldCatalogue` appends the block for a step's layout; the member resolver and detail lookup are injected.

    private func makeItem(_ id: String) throws -> InspectConfig.ListItem {
        let json = #"{"id":"\#(id)","displayName":"\#(id.capitalized)","paths":[]}"#
        return try JSONDecoder().decode(InspectConfig.ListItem.self, from: Data(json.utf8))
    }

    private func makeBundle(id: String, itemIds: [String],
                            action: [String: Any]? = nil,
                            command: String? = nil, commandNote: String? = nil)
    throws -> InspectConfig.SoftwareBundle {
        var payload: [String: Any] = ["id": id, "title": id.capitalized, "itemIds": itemIds]
        if let action { payload["action"] = action }
        if let command { payload["command"] = command }
        if let commandNote { payload["commandNote"] = commandNote }
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(InspectConfig.SoftwareBundle.self, from: data)
    }

    /// Every member `.pending` unless named in `installed`.
    private func resolver(installed: Set<String> = []) -> (InspectConfig.ListItem) -> SoftwareMember {
        { item in
            let status: StepStatus = installed.contains(item.id) ? .completed : .pending
            var member = SoftwareMember(id: item.id, name: item.displayName, icon: nil,
                                        bundleId: nil, paths: item.paths, status: status,
                                        detail: nil)
            let action = SoftwareRowRule.action(for: status, openURL: nil,
                                                appBundleId: nil, firstPath: nil)
            member.actionLabel = action.label
            member.action = action.action
            member.requestId = action.requestId
            return member
        }
    }

    /// Members follow the bundle's `itemIds` order, not the items array.
    func testMembersFollowTheBundlesOwnOrderNotTheItemsArray() throws {
        let members = CardStepBlocks.catalogueMembers(
            bundleId: "design", itemIds: ["sketch", "figma"],
            items: [try makeItem("figma"), try makeItem("sketch")],
            resolve: resolver(), log: { _ in })
        XCTAssertEqual(members.map(\.id), ["sketch", "figma"])
    }

    /// An id with no matching item is dropped and logged, never a blank tile.
    func testAnIdWithNoMatchingItemIsDroppedAndLogged() throws {
        var logged: [String] = []
        let members = CardStepBlocks.catalogueMembers(
            bundleId: "design", itemIds: ["figma", "ghost", "sketch"],
            items: [try makeItem("figma"), try makeItem("sketch")],
            resolve: resolver(), log: { logged.append($0) })
        XCTAssertEqual(members.map(\.id), ["figma", "sketch"])
        XCTAssertEqual(logged.count, 1)
        XCTAssertTrue(logged[0].contains("'ghost'"), logged[0])
    }

    private func bundleRows(bundles: [InspectConfig.SoftwareBundle],
                            items: [InspectConfig.ListItem],
                            installed: Set<String> = [],
                            hasDetail: @escaping (String) -> Bool = { _ in false })
    -> [InspectConfig.GuidanceContent.BundleRowPayload] {
        let folded = CardStepBlocks.foldCatalogue(
            content: [], layout: "bundles", sources: .init(bundles: bundles, items: items),
            member: resolver(installed: installed), hasDetail: hasDetail)
        return folded.first?.bundleRows ?? []
    }

    /// A complete bundle with no action and no detail step offers no button.
    func testACompleteBundleWithNoDetailAndNoActionOffersNoButton() throws {
        let rows = bundleRows(bundles: [try makeBundle(id: "engineering", itemIds: ["xcode", "zed"])],
                              items: [try makeItem("xcode"), try makeItem("zed")],
                              installed: ["xcode", "zed"])
        XCTAssertNil(rows.first?.actionLabel)
        // `bundleId` survives the fold's round trip; "Details" navigates with it.
        XCTAssertEqual(rows.first?.bundleId, "engineering")
    }

    /// A complete bundle with a detail step offers Details.
    func testACompleteBundleWithADetailStepOffersDetails() throws {
        let rows = bundleRows(bundles: [try makeBundle(id: "essentials", itemIds: ["safari"])],
                              items: [try makeItem("safari")], installed: ["safari"],
                              hasDetail: { _ in true })
        XCTAssertEqual(rows.first?.actionLabel, "Details")
        XCTAssertTrue(rows.first?.hasDetail == true)
    }

    /// A partly installed bundle with nothing authored offers "Complete".
    func testAPartlyInstalledBundleOffersComplete() throws {
        let rows = bundleRows(bundles: [try makeBundle(id: "design", itemIds: ["figma", "sketch"])],
                              items: [try makeItem("figma"), try makeItem("sketch")],
                              installed: ["figma"])
        XCTAssertEqual(rows.first?.actionLabel, "Complete")
    }

    /// An authored label is filled from the live tally ("Install {missing} missing").
    func testAnAuthoredLabelIsResolvedFromTheTally() throws {
        let rows = bundleRows(
            bundles: [try makeBundle(id: "data", itemIds: ["dbt", "tableau"],
                                 action: ["label": "Install {missing} missing",
                                          "requestId": "install-data"])],
            items: [try makeItem("dbt"), try makeItem("tableau")], installed: ["dbt"])
        XCTAssertEqual(rows.first?.actionLabel, "Install 1 missing")
        // No verb authored: the documented default `request`, so the row installs instead of navigating.
        XCTAssertEqual(rows.first?.action, "request")
    }

    /// Detail layout: rows in bundle order, and the command on its own keys, not `content`/`note`.
    func testTheDetailLayoutFoldsRowsAndTheCommandOnItsOwnKeys() throws {
        let bundles = [try makeBundle(id: "essentials", itemIds: ["slack", "safari"],
                                  command: "fleetctl install --bundle essentials",
                                  commandNote: "No admin password needed")]
        let folded = CardStepBlocks.foldCatalogue(
            content: [], layout: "detail",
            sources: .init(bundles: bundles,
                           detailBundle: CardStepBlocks.detailBundle(in: bundles, named: "essentials"),
                           items: [try makeItem("safari"), try makeItem("slack")]),
            member: resolver(installed: ["safari"]), hasDetail: { _ in false })
        let block = try XCTUnwrap(folded.first)
        XCTAssertEqual(block.type, "bundle-detail")
        XCTAssertEqual(block.detailRows?.map(\.itemId), ["slack", "safari"])
        XCTAssertEqual(block.bundleCommand, "fleetctl install --bundle essentials")
        XCTAssertEqual(block.bundleCommandNote, "No admin password needed")
        XCTAssertNil(block.content)
        XCTAssertNil(block.note)
        // Resolved before the block: installed offers Open, missing offers Install.
        XCTAssertEqual(block.detailRows?.first?.actionLabel, "Install")
        XCTAssertEqual(block.detailRows?.last?.status, "completed")
    }

    /// A bundle whose members are all unknown still gets its command, the remaining way forward.
    func testTheDetailLayoutKeepsTheCommandWhenEveryMemberIsUnknown() throws {
        let bundles = [try makeBundle(id: "essentials", itemIds: ["ghost"],
                                  command: "fleetctl install --bundle essentials")]
        let folded = CardStepBlocks.foldCatalogue(
            content: [], layout: "detail",
            sources: .init(bundles: bundles,
                           detailBundle: CardStepBlocks.detailBundle(in: bundles, named: "essentials"),
                           items: [try makeItem("safari")]),
            member: resolver(), hasDetail: { _ in false })
        let block = try XCTUnwrap(folded.first)
        XCTAssertEqual(block.type, "bundle-detail")
        XCTAssertEqual(block.detailRows?.isEmpty, true)
        XCTAssertEqual(block.bundleCommand, "fleetctl install --bundle essentials")
    }

    /// The handoff layout copies the typed model into a `handoff-list` block.
    func testTheHandoffLayoutFoldsToHandoffList() throws {
        let json = #"""
        [{"id":"selfservice","title":"Self Service","detail":"Browse everything.","buttonLabel":"Open"},
         {"id":"launch-figma","title":"Figma","target":"figma://","action":"url","url":"figma://","itemId":"figma"}]
        """#
        let handoffs = try JSONDecoder().decode([InspectConfig.SoftwareHandoff].self,
                                                from: Data(json.utf8))
        let folded = CardStepBlocks.foldCatalogue(
            content: [], layout: "handoff", sources: .init(handoffs: handoffs),
            member: resolver(), hasDetail: { _ in false })
        let block = try XCTUnwrap(folded.first)
        XCTAssertEqual(block.type, "handoff-list")
        XCTAssertEqual(block.handoffs?.map(\.handoffId), ["selfservice", "launch-figma"])
        // The block tells cards from rows by `detail`.
        XCTAssertNotNil(block.handoffs?.first?.detail)
        XCTAssertEqual(block.handoffs?.last?.itemId, "figma")
    }

    /// An authored block of the same type wins, so the catalogue never renders twice.
    func testAnAuthoredBlockOfTheSameTypeWins() throws {
        let authored = try JSONDecoder().decode(
            InspectConfig.GuidanceContent.self,
            from: Data(#"{"type":"bundle-list","bundleRows":[{"id":"x","title":"X","hasDetail":false}]}"#.utf8))
        let folded = CardStepBlocks.foldCatalogue(
            content: [authored], layout: "bundles",
            sources: .init(bundles: [try makeBundle(id: "essentials", itemIds: ["safari"])],
                           items: [try makeItem("safari")]),
            member: resolver(), hasDetail: { _ in false })
        XCTAssertEqual(folded.count, 1)
        XCTAssertEqual(folded.first?.bundleRows?.first?.bundleId, "x")
    }
}
