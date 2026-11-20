//
//  StepPayloadNestingTests.swift
//  dialogTests
//
//  Grouped (`wallpaper: { categories: [...] }`) and flat (`wallpaperCategories: [...]`) payload
//  spellings, and the other aliases, decode to indistinguishable canonical steps.
//

import XCTest
@testable import Dialog

final class StepPayloadNestingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        InspectConfig.unknownKeyWarnings = []
    }

    override func tearDown() {
        InspectConfig.unknownKeyWarnings = []
        super.tearDown()
    }

    // MARK: - Helpers

    private func step(_ stepJSON: String,
                      file: StaticString = #filePath, line: UInt = #line) throws -> InspectConfig.IntroStep {
        let json = #"{"preset": "preset5", "introSteps": [\#(stepJSON)]}"#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        return try XCTUnwrap(config.introSteps?.first, file: file, line: line)
    }

    /// Canonical JSON of a decoded step, as the step_add dedup path compares it.
    private func canonical(_ s: InspectConfig.IntroStep) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try XCTUnwrap(String(bytes: enc.encode(s), encoding: .utf8))
    }

    /// Two spellings, one decoded step. No normalization before comparing: canonicalization consumes
    /// the grouped container itself.
    private func assertEquivalent(flat: String, grouped: String,
                                  file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try canonical(try step(flat)), try canonical(try step(grouped)),
                       "flat and grouped spellings must decode to the same step",
                       file: file, line: line)
    }

    // MARK: - Root steps[] for every preset

    /// A preset-5 config authoring root `steps[]` renders its steps. Asserted through
    /// `stepsWithBookends`, the list Preset 5 actually renders.
    func testRootStepsRendersForPreset5NotOnlyPreset6() throws {
        let json = #"""
        {"preset": "5", "steps": [
          {"id": "one", "stepType": "intro", "title": "First"},
          {"id": "two", "stepType": "intro", "title": "Second"}
        ]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let rendered = try XCTUnwrap(config.stepsWithBookends,
                                    "a P5 config authoring root steps[] must have a renderable list")
        XCTAssertEqual(rendered.count, 2,
                       "Preset5 renders stepsWithBookends; root steps[] must reach it")
        XCTAssertEqual(rendered.map(\.id), ["one", "two"])
    }

    /// Preset 6 still reads `config.steps` unchanged.
    func testRootStepsStillFeedsPreset6() throws {
        let json = #"""
        {"preset": "6", "steps": [
          {"id": "a", "title": "A"},
          {"id": "b", "title": "B"}
        ]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.steps?.map(\.id), ["a", "b"],
                       "preset 6's own list must be unchanged")
    }

    // MARK: - comparison-table: singular spelling folds onto checks[]

    /// Single-datum comparison blocks fold at decode into one `checks[]` table.
    func testComparisonTableSingularFoldsOntoChecks() throws {
        let singular = #"""
        {"id": "enc", "content": [
          {"type": "comparison-table", "label": "FileVault 2", "expected": "Enabled", "actual": "Enabled",
           "state": "success", "comparisonStyle": "columns", "expectedLabel": "Required",
           "actualLabel": "Current", "category": "Encryption Checks"},
          {"type": "comparison-table", "label": "Recovery Key", "expected": "Escrowed", "actual": "Escrowed",
           "state": "success", "comparisonStyle": "columns", "expectedLabel": "Required",
           "actualLabel": "Current", "category": "Encryption Checks"}
        ]}
        """#
        let plural = #"""
        {"id": "enc", "content": [
          {"type": "comparison-table", "label": "Encryption Checks", "expectedLabel": "Required",
           "actualLabel": "Current", "checks": [
             {"check": "FileVault 2", "required": "Enabled", "found": "Enabled", "pass": true},
             {"check": "Recovery Key", "required": "Escrowed", "found": "Escrowed", "pass": true}
           ]}
        ]}
        """#
        // Authored via `content`; the `guidanceContent` alias path is covered by the `state` test below.
        try assertEquivalent(flat: singular, grouped: plural)
    }

    /// `pass` comes from `state`, not `required == found` ("8 GB minimum" vs "36 GB" still passes).
    func testComparisonTablePassComesFromStateNotStringEquality() throws {
        let s = try step(#"""
        {"id": "hw", "guidanceContent": [
          {"type": "comparison-table", "label": "Memory", "expected": "8 GB minimum", "actual": "36 GB",
           "state": "success", "expectedLabel": "Required", "actualLabel": "Current",
           "category": "Hardware Requirements"}
        ]}
        """#)
        let block = try XCTUnwrap(s.content?.first)
        let check = try XCTUnwrap(block.checks?.first)
        XCTAssertEqual(check.pass, true,
                       "'state: success' with unequal strings must still be a pass")
        XCTAssertEqual(check.check, "Memory")
        XCTAssertEqual(check.required, "8 GB minimum")
        XCTAssertEqual(check.found, "36 GB")
    }

    /// A run merges only within one category; two categories stay two tables.
    func testComparisonTableRunsDoNotCrossCategories() throws {
        let s = try step(#"""
        {"id": "two", "guidanceContent": [
          {"type": "comparison-table", "label": "FileVault", "expected": "On", "actual": "On",
           "state": "success", "category": "Encryption Checks"},
          {"type": "comparison-table", "label": "Stealth mode", "expected": "On", "actual": "Off",
           "state": "fail", "category": "Firewall Checks"}
        ]}
        """#)
        let blocks = try XCTUnwrap(s.content)
        XCTAssertEqual(blocks.count, 2, "two categories must stay two tables")
        XCTAssertEqual(blocks[0].label, "Encryption Checks")
        XCTAssertEqual(blocks[1].label, "Firewall Checks")
        XCTAssertEqual(blocks[0].checks?.count, 1)
        XCTAssertEqual(blocks[1].checks?.first?.pass, false, "'fail' is not a pass")
    }

    /// The canonical `checks[]` spelling passes through, and a second pass changes nothing.
    func testComparisonTableChecksSpellingIsIdempotent() throws {
        let plural = #"""
        {"id": "p", "guidanceContent": [
          {"type": "comparison-table", "label": "Checks", "checks": [
            {"check": "FileVault", "required": "On", "found": "On", "pass": true}
          ]}
        ]}
        """#
        let once = try step(plural)
        var advisories: [String] = []
        let twice = InspectConfig.canonicalizeStep(once, advisories: &advisories)
        XCTAssertEqual(try canonical(once), try canonical(twice),
                       "canonicalization must be idempotent for the canonical spelling")
        XCTAssertEqual(once.content?.count, 1)
        XCTAssertEqual(once.content?.first?.checks?.count, 1)
    }

    // MARK: - Equivalence per family

    func testWallpaperPayloadEquivalence() throws {
        try assertEquivalent(
            flat: """
            {"id": "wp", "wallpaperLayout": "grid", "wallpaperThumbnailHeight": 140,
             "wallpaperSelectionKey": "wall", "wallpaperShowPath": true, "wallpaperMultiSelect": 2,
             "wallpaperCategories": [{"title": "Brand", "images": [{"path": "/a.png"}]}]}
            """,
            grouped: """
            {"id": "wp", "wallpaper": {"layout": "grid", "thumbnailHeight": 140,
             "selectionKey": "wall", "showPath": true, "multiSelect": 2,
             "categories": [{"title": "Brand", "images": [{"path": "/a.png"}]}]}}
            """)
    }

    func testOptionPayloadEquivalence() throws {
        try assertEquivalent(
            flat: """
            {"id": "opt", "optionKey": "browser", "optionLayout": "grid", "optionMultiSelect": true,
             "optionConfirmButton": "Choose",
             "optionCards": [{"id": "safari", "label": "Safari"}]}
            """,
            grouped: """
            {"id": "opt", "option": {"key": "browser", "layout": "grid", "multiSelect": true,
             "confirmButton": "Choose", "cards": [{"id": "safari", "label": "Safari"}]}}
            """)
    }

    /// Dock fixtures use `layout: "narrow"`, the schema's only `dockLayout` value.
    func testDockPayloadEquivalence() throws {
        try assertEquivalent(
            flat: """
            {"id": "dk", "dockMode": "flavors", "dockLayout": "narrow", "dockApplyMode": "replace",
             "dockShowUnavailable": false, "dockSelectionKey": "dock",
             "dockFlavors": [{"id": "dev", "name": "Developer", "items": []}]}
            """,
            grouped: """
            {"id": "dk", "dock": {"mode": "flavors", "layout": "narrow", "applyMode": "replace",
             "showUnavailable": false, "selectionKey": "dock",
             "flavors": [{"id": "dev", "name": "Developer", "items": []}]}}
            """)
    }

    func testMediaPayloadEquivalence() throws {
        try assertEquivalent(
            flat: """
            {"id": "md", "mediaHeight": 380, "mediaAutoplay": false, "mediaShowDots": true,
             "mediaFit": "fit", "mediaSide": "left",
             "mediaItems": [{"type": "image", "path": "/a.png"}]}
            """,
            grouped: """
            {"id": "md", "media": {"height": 380, "autoplay": false, "showDots": true,
             "fit": "fit", "side": "left", "items": [{"type": "image", "path": "/a.png"}]}}
            """)
    }

    func testBentoPayloadEquivalence() throws {
        try assertEquivalent(
            flat: """
            {"id": "bn", "bentoColumns": 3, "bentoGap": 12, "bentoLayout": "grid",
             "bentoRowHeight": 120, "bentoTintColor": "#61BB46"}
            """,
            grouped: """
            {"id": "bn", "bento": {"columns": 3, "gap": 12, "layout": "grid",
             "rowHeight": 120, "tintColor": "#61BB46"}}
            """)
    }

    func testGuidePayloadEquivalence() throws {
        try assertEquivalent(
            flat: """
            {"id": "gd", "guideKeyPoints": "Read this", "guideCategoryIcon": "book",
             "guideStepBadge": "1", "guideImageRatio": 1.5, "guideBulletPoints": ["a", "b"]}
            """,
            grouped: """
            {"id": "gd", "guide": {"keyPoints": "Read this", "categoryIcon": "book",
             "stepBadge": "1", "imageRatio": 1.5, "bulletPoints": ["a", "b"]}}
            """)
    }

    func testShowcasePayloadEquivalence() throws {
        try assertEquivalent(
            flat: ##"{"id": "sc", "showcaseImageHeight": 260, "showcaseTextColor": "#FFFFFF", "showcaseGradientColors": ["#000", "#111"]}"##,
            grouped: ##"{"id": "sc", "showcase": {"imageHeight": 260, "textColor": "#FFFFFF", "gradientColors": ["#000", "#111"]}}"##)
    }

    func testAssistantPayloadEquivalence() throws {
        try assertEquivalent(
            flat: #"{"id": "as", "assistantImageHeight": 220, "agentLabel": "Setup Assistant"}"#,
            grouped: #"{"id": "as", "assistant": {"imageHeight": 220, "agentLabel": "Setup Assistant"}}"#)
    }

    func testSoftwarePayloadEquivalence() throws {
        try assertEquivalent(
            flat: """
            {"id": "sw", "softwareNote": "Managed by IT", "agentLabel": "agent: fleetctl",
             "bundles": [{"id": "core", "title": "Core", "itemIds": ["slack"]}]}
            """,
            grouped: """
            {"id": "sw", "software": {"note": "Managed by IT", "agentLabel": "agent: fleetctl",
             "bundles": [{"id": "core", "title": "Core", "itemIds": ["slack"]}]}}
            """)
    }

    // MARK: - agentLabel

    /// `agentLabel` folds from the software family.
    func testAgentLabelFoldsFromTheSoftwareFamily() throws {
        let s = try step(#"{"id": "sw", "software": {"agentLabel": "agent: fleetctl"}}"#)
        XCTAssertEqual(s.agentLabel, "agent: fleetctl",
                       "agentLabel is software vocabulary and must fold from `software`")
        XCTAssertNil(s.software, "the grouped container is still consumed")
    }

    /// The legacy `assistant.agentLabel` spelling still folds.
    func testLegacyAssistantAgentLabelStillFolds() throws {
        let s = try step(#"{"id": "sw", "assistant": {"agentLabel": "agent: fleetctl"}}"#)
        XCTAssertEqual(s.agentLabel, "agent: fleetctl",
                       "the legacy assistant spelling is still honoured")
    }

    /// With both spellings authored, `software` wins with its own advisory.
    func testSoftwareAgentLabelWinsOverTheLegacyAssistantSpelling() throws {
        let s = try step("""
        {"id": "sw", "assistant": {"agentLabel": "legacy"}, "software": {"agentLabel": "canonical"}}
        """)
        XCTAssertEqual(s.agentLabel, "canonical", "the software family is canonical and wins")
    }

    /// The losing value is advised, never dropped silently.
    func testTheTwoAgentLabelSpellingsCollidingIsAdvised() throws {
        let raw = try JSONDecoder().decode(
            InspectConfig.IntroStep.self,
            from: Data(#"{"id": "sw", "assistant": {"agentLabel": "legacy"}, "software": {"agentLabel": "canonical"}}"#.utf8))
        var advisories: [String] = []
        _ = InspectConfig.canonicalizeStep(raw, advisories: &advisories)
        XCTAssertTrue(advisories.contains { $0.contains("agentLabel") && $0.contains("assistant") },
                      "dropping the legacy value must be advised, not silent: \(advisories)")
    }

    /// `portal` is a rename of `portalConfig`.
    func testPortalIsARenameOfPortalConfig() throws {
        try assertEquivalent(
            flat: #"{"id": "pt", "portalConfig": {"portalURL": "https://example.com"}}"#,
            grouped: #"{"id": "pt", "portal": {"portalURL": "https://example.com"}}"#)
    }

    // MARK: - Cadence: one key, two shapes

    /// A bare array still means the entries.
    func testCadenceBareArrayStillDecodesAsEntries() throws {
        let s = try step("""
        {"id": "cd", "cadence": [
          {"id": "a", "message": "One", "attribute": {"type": "app", "bundleId": "com.apple.finder"}}
        ]}
        """)
        XCTAssertEqual(s.cadenceEntries?.count, 1)
        XCTAssertEqual(s.cadenceEntries?.first?.id, "a")
    }

    func testCadenceGroupedShapeCarriesEntriesAndSiblings() throws {
        let s = try step("""
        {"id": "cd", "cadence": {"style": "manifest", "interval": 2.5, "minDwell": 0.9, "entries": [
          {"id": "a", "message": "One", "attribute": {"type": "app", "bundleId": "com.apple.finder"}}
        ]}}
        """)
        XCTAssertEqual(s.cadenceEntries?.count, 1)
        XCTAssertEqual(s.cadenceStyle, "manifest", "cadence.style folds onto cadenceStyle")
        XCTAssertEqual(s.cadenceInterval, 2.5)
        XCTAssertEqual(s.cadenceMinDwell, 0.9)
    }

    func testCadenceShapesAreEquivalentForTheEntries() throws {
        let bare = try step(#"{"id": "cd", "cadenceStyle": "manifest", "cadence": [{"id": "a", "message": "One", "attribute": {"type": "app", "bundleId": "x"}}]}"#)
        let grouped = try step(#"{"id": "cd", "cadence": {"style": "manifest", "entries": [{"id": "a", "message": "One", "attribute": {"type": "app", "bundleId": "x"}}]}}"#)
        XCTAssertEqual(bare.cadenceEntries?.map(\.id), grouped.cadenceEntries?.map(\.id))
        XCTAssertEqual(bare.cadenceStyle, grouped.cadenceStyle)
    }

    // MARK: - Precedence and advisories

    /// Grouped wins over flat, with an advisory.
    func testGroupedWinsOverFlatWithAnAdvisory() throws {
        let s = try step(#"{"id": "wp", "wallpaperLayout": "row", "wallpaper": {"layout": "grid"}}"#)
        XCTAssertEqual(s.wallpaperLayout, "grid", "the grouped value wins")
        XCTAssertTrue(InspectConfig.unknownKeyWarnings.isEmpty,
                      "the conflict is a canonicalization advisory, not an unknown key")
    }

    /// The fold runs before the renderer presence chain, so a grouped-only step selects the same renderer.
    func testGroupedPayloadStillDrivesTheRendererPresenceChain() throws {
        let grouped = try step(#"{"id": "wp", "wallpaper": {"categories": [{"title": "B", "images": [{"path": "/a.png"}]}]}}"#)
        XCTAssertEqual(grouped.stepType, "wallpaper",
                       "a grouped-only wallpaper step must still resolve its renderer")

        let dock = try step(#"{"id": "dk", "dock": {"flavors": [{"id": "d", "name": "D", "items": []}]}}"#)
        XCTAssertEqual(dock.stepType, "dock")

        let option = try step(#"{"id": "op", "option": {"cards": [{"id": "a", "label": "A"}]}}"#)
        XCTAssertEqual(option.stepType, "options")
    }

    /// Grouped containers are known keys, not unknown-key warnings. There is no `guide` container;
    /// `guideText` is flat and folds into `content`.
    func testGroupedContainersAreNotReportedUnknown() throws {
        _ = try step(#"{"id": "s", "wallpaper": {}, "dock": {}, "media": {}, "bento": {}, "showcase": {}, "assistant": {}, "software": {}, "option": {}, "portal": {}}"#)
        XCTAssertTrue(InspectConfig.unknownKeyWarnings.isEmpty,
                      "grouped payload containers are known step keys: \(InspectConfig.unknownKeyWarnings)")
    }

    /// Canonicalization consumes the grouped container.
    func testCanonicalizationConsumesTheGroupedContainer() throws {
        let s = try step(#"{"id": "wp", "wallpaper": {"layout": "grid"}}"#)
        XCTAssertNil(s.wallpaper, "the grouped container is consumed by the fold")
        XCTAssertEqual(s.wallpaperLayout, "grid", "its value survives on the flat key")
    }

    /// Canonicalizing an already-canonical step changes nothing and emits no advisories.
    func testFoldIsIdempotent() throws {
        let once = try step(#"{"id": "wp", "wallpaperLayout": "row", "wallpaper": {"layout": "grid"}}"#)
        var advisories: [String] = []
        let twice = InspectConfig.canonicalizeStep(once, advisories: &advisories)
        XCTAssertEqual(try canonical(once), try canonical(twice))
        XCTAssertTrue(advisories.isEmpty,
                      "a canonical step re-emits no rewrite advisories: \(advisories)")
    }

    // MARK: - What nesting does not touch

    /// `substeps` and `items` are the step's own content and stay top-level.
    func testSingleCollectionPayloadsStayTopLevel() throws {
        let s = try step("""
        {"id": "s", "substeps": [{"id": "a", "title": "A"}],
         "items": [{"id": "r1", "displayName": "Row"}]}
        """)
        XCTAssertEqual(s.substeps?.count, 1, "substeps stays a top-level collection")
        XCTAssertEqual(s.items?.count, 1, "items stays core — it is the row list, not a payload")
    }

    // MARK: - Button label folds onto content

    /// A button spelled with `label` renders its caption: `GuidanceActionButtonBlock` reads `content`.
    func testButtonLabelFoldsOntoContent() throws {
        let s = try step(#"""
        {"id": "actions", "content": [
          {"type": "button", "label": "Open Self Service", "buttonStyle": "prominent", "url": "https://example.com"}
        ]}
        """#)
        XCTAssertEqual(s.content?.first?.content, "Open Self Service",
                       "a button's `label` must reach the property the renderer reads")
    }

    /// An authored `content` wins over `label`.
    func testButtonContentBeatsLabelWhenBothAuthored() throws {
        let s = try step(#"""
        {"id": "actions", "content": [
          {"type": "button", "content": "Canonical", "label": "Alias", "url": "https://example.com"}
        ]}
        """#)
        XCTAssertEqual(s.content?.first?.content, "Canonical")
    }

    /// Only buttons fold `label`; on a `comparison-table` it names the check.
    func testLabelIsNotFoldedOnNonButtonBlocks() throws {
        let s = try step(#"""
        {"id": "enc", "content": [
          {"type": "comparison-table", "label": "FileVault 2", "expected": "Enabled",
           "actual": "Enabled", "state": "success"}
        ]}
        """#)
        XCTAssertNil(s.content?.first?.content,
                     "a comparison-table's `label` is its check name, not its body text")
    }

    /// The fold sits after the `guidanceContent` alias, so both container spellings reach it.
    func testButtonLabelFoldsThroughTheGuidanceContentAlias() throws {
        let s = try step(#"""
        {"id": "actions", "guidanceContent": [
          {"type": "button", "label": "View documentation", "buttonStyle": "bordered"}
        ]}
        """#)
        XCTAssertEqual(s.content?.first?.content, "View documentation")
    }

    // MARK: - Button action inferred from payload

    /// A button with only `url` infers `action: url`; `handleButtonAction` needs an action.
    func testButtonWithUrlAndNoActionInfersUrl() throws {
        let s = try step(#"""
        {"id": "actions", "content": [
          {"type": "button", "label": "Open Self Service", "url": "https://example.com"}
        ]}
        """#)
        XCTAssertEqual(s.content?.first?.action, "url")
    }

    /// Each payload names exactly one action.
    func testShellAndRequestPayloadsInferTheirOwnActions() throws {
        let shell = try step(#"""
        {"id": "a", "content": [{"type": "button", "label": "Run", "shell": "/bin/echo hi"}]}
        """#)
        XCTAssertEqual(shell.content?.first?.action, "shell")

        let request = try step(#"""
        {"id": "b", "content": [{"type": "button", "label": "Install", "requestId": "profiles-install"}]}
        """#)
        XCTAssertEqual(request.content?.first?.action, "request")
    }

    /// An authored action is never overwritten, even if its payload disagrees.
    func testAuthoredActionWins() throws {
        let s = try step(#"""
        {"id": "a", "content": [
          {"type": "button", "label": "Custom", "action": "custom", "url": "https://example.com"}
        ]}
        """#)
        XCTAssertEqual(s.content?.first?.action, "custom")
    }

    /// A button with no payload keeps its nil action, so the handler reports it.
    func testPayloadlessButtonIsLeftAlone() throws {
        let s = try step(#"""
        {"id": "a", "content": [{"type": "button", "label": "Nothing"}]}
        """#)
        XCTAssertNil(s.content?.first?.action)
    }

    // MARK: - Dock vocabulary at block level

    /// `dockDecline` decodes on a block, so a block-level dock picker can offer the decline card.
    func testBlockLevelDockDeclineDecodes() throws {
        let s = try step("""
        {"id": "s", "content": [
          {"type": "dock-picker", "dockFlavors": [{"id": "f", "name": "F", "items": []}],
           "dockDecline": {"label": "Keep my Dock as it is", "subtitle": "Nothing added."}}]}
        """)
        let block = try XCTUnwrap(s.content?.first)
        XCTAssertEqual(block.dockDecline?.label, "Keep my Dock as it is")
        XCTAssertEqual(block.dockDecline?.subtitle, "Nothing added.")
    }

    /// The block's grouped dock container folds onto flat keys and is consumed, as at step level.
    func testBlockLevelDockPayloadFoldsIntoFlatKeys() throws {
        let s = try step("""
        {"id": "s", "content": [
          {"type": "dock-picker", "dock": {"mode": "flavors", "applyMode": "replace",
           "layout": "narrow", "selectionKey": "dock", "preferenceKey": "DockChoice",
           "confirmButton": "Apply", "showUnavailable": false,
           "items": [{"label": "Finder", "path": "/System/Library/CoreServices/Finder.app"}],
           "flavors": [{"id": "f", "name": "F", "items": []}],
           "decline": {"label": "Keep mine"}}}]}
        """)
        let block = try XCTUnwrap(s.content?.first)
        XCTAssertEqual(block.dockMode, "flavors")
        XCTAssertEqual(block.dockApplyMode, "replace")
        XCTAssertEqual(block.dockLayout, "narrow")
        XCTAssertEqual(block.dockSelectionKey, "dock")
        XCTAssertEqual(block.dockPreferenceKey, "DockChoice")
        XCTAssertEqual(block.dockConfirmButton, "Apply")
        XCTAssertEqual(block.dockShowUnavailable, false)
        XCTAssertEqual(block.dockItems?.first?.label, "Finder")
        XCTAssertEqual(block.dockFlavors?.first?.name, "F")
        XCTAssertEqual(block.dockDecline?.label, "Keep mine")
        XCTAssertNil(block.dock, "the container must be nil'd after folding, like the step level")
    }

    /// Both spellings on a block: grouped wins, with an advisory.
    func testBlockLevelDockGroupedWinsWithAnAdvisory() throws {
        let s = try step("""
        {"id": "s", "content": [
          {"type": "dock-picker", "dockMode": "build", "dock": {"mode": "flavors"}}]}
        """)
        XCTAssertEqual(s.content?.first?.dockMode, "flavors", "the grouped value wins")
        XCTAssertTrue(InspectConfig.unknownKeyWarnings.isEmpty,
                      "the conflict is a canonicalization advisory, not an unknown key: "
                      + "\(InspectConfig.unknownKeyWarnings)")
    }

    /// The fold also runs for `items[].guidanceContent[]` through `ItemConfig`.
    func testBlockLevelDockPayloadFoldsThroughTheItemDecoder() throws {
        let json = #"""
        {"preset": "6", "items": [{"id": "i", "displayName": "I", "guidanceContent": [
          {"type": "dock-picker", "dock": {"mode": "flavors",
           "flavors": [{"id": "f", "name": "F", "items": []}],
           "decline": {"label": "Keep mine", "value": "declined"}}}]}]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let block = try XCTUnwrap(config.items.first?.guidanceContent?.first)
        XCTAssertEqual(block.dockMode, "flavors")
        XCTAssertEqual(block.dockDecline?.label, "Keep mine")
        XCTAssertEqual(block.dockDecline?.value, "declined")
        XCTAssertNil(block.dock)
    }

    // MARK: - summaryScreen

    /// `PresetSummaryScreen` carries the dock payload's members, decline included.
    func testSummaryScreenDeclineDecodesFlat() throws {
        let json = #"""
        {"preset": "2", "summaryScreen": {"title": "Done", "layout": "dock",
          "dockFlavors": [{"id": "f", "name": "F", "items": []}],
          "dockDecline": {"label": "Keep my Dock as it is"}}}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let outro = try XCTUnwrap(config.summaryScreen)
        XCTAssertEqual(outro.dockDecline?.label, "Keep my Dock as it is")
        XCTAssertEqual(outro.dockFlavors?.first?.name, "F")
    }

    /// The outro's grouped container folds at its decode site (a root key, not per step).
    func testSummaryScreenDockPayloadFoldsIntoFlatKeys() throws {
        let json = #"""
        {"preset": "2", "summaryScreen": {"title": "Done", "layout": "dock",
          "dock": {"mode": "flavors", "applyMode": "replace", "layout": "narrow",
           "selectionKey": "outroDock", "preferenceKey": "DockChoice", "confirmButton": "Apply",
           "showUnavailable": true,
           "items": [{"label": "Finder", "path": "/System/Library/CoreServices/Finder.app"}],
           "flavors": [{"id": "f", "name": "F", "items": []}],
           "decline": {"label": "Keep mine"}}}}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let outro = try XCTUnwrap(config.summaryScreen)
        XCTAssertEqual(outro.dockMode, "flavors")
        XCTAssertEqual(outro.dockApplyMode, "replace")
        XCTAssertEqual(outro.dockLayout, "narrow")
        XCTAssertEqual(outro.dockSelectionKey, "outroDock")
        XCTAssertEqual(outro.dockPreferenceKey, "DockChoice")
        XCTAssertEqual(outro.dockConfirmButton, "Apply")
        XCTAssertEqual(outro.dockShowUnavailable, true)
        XCTAssertEqual(outro.dockItems?.first?.label, "Finder")
        XCTAssertEqual(outro.dockFlavors?.first?.name, "F")
        XCTAssertEqual(outro.dockDecline?.label, "Keep mine")
        XCTAssertNil(outro.dock, "the container is consumed at the outro too")
    }

    /// An authored flat key is not dropped silently when the container also carries it.
    func testSummaryScreenGroupedDockWinsOverFlat() throws {
        let json = #"""
        {"preset": "2", "summaryScreen": {"layout": "dock", "dockMode": "build",
          "dock": {"mode": "flavors"}}}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.summaryScreen?.dockMode, "flavors", "the grouped value wins")
    }

    // MARK: - Option and wallpaper at block level

    /// Every picker block can take a preference key distinct from its selection key. Authored through
    /// root `steps[]` + `guidanceContent[]` (the longest path), asserted on `step.content` since the alias is nil after decode.
    func testBlockLevelWallpaperPreferenceKeyDecodes() throws {
        let json = """
        {"preset":"6","title":"t","steps":[{"id":"s","displayName":"S","guidanceContent":[
          {"type":"wallpaper-picker","wallpaperCategories":[],"wallpaperPreferenceKey":"com.example.wp"}]}]}
        """
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let block = try XCTUnwrap(config.steps?.first?.content?.first)
        XCTAssertEqual(block.wallpaperPreferenceKey, "com.example.wp")
    }

    /// Both grouped containers fold onto the flat keys and are consumed; every member is asserted.
    /// `OptionPayload` spells its selection key `key`, the others `selectionKey`.
    func testBlockLevelOptionAndWallpaperPayloadsFold() throws {
        let json = """
        {"preset":"6","title":"t","steps":[{"id":"s","displayName":"S","guidanceContent":[
          {"type":"option-picker","option":{"key":"k","layout":"grid","multiSelect":true,
            "confirmButton":"Choose","preferenceKey":"OptionChoice",
            "cards":[{"id":"c","label":"C"}]}},
          {"type":"wallpaper-picker","wallpaper":{"selectionKey":"w","preferenceKey":"p",
            "showPath":true,"confirmButton":"Set","layout":"grid","multiSelect":2,
            "thumbnailHeight":140,
            "categories":[{"title":"4K","images":[{"path":"/a.png"}]}]}}]}]}
        """
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let step = try XCTUnwrap(config.steps?.first)
        let blocks = try XCTUnwrap(step.content)
        // A fold that copied instead of consuming would leave the alias populated.
        XCTAssertNil(step.guidanceContent,
                     "`guidanceContent` is alias INTAKE and canonicalizeStep CONSUMES it: the "
                     + "blocks live on `content` and exactly one spelling survives")
        XCTAssertEqual(blocks[0].optionKey, "k")
        XCTAssertEqual(blocks[0].optionLayout, "grid")
        XCTAssertEqual(blocks[0].optionMultiSelect, true)
        XCTAssertEqual(blocks[0].optionConfirmButton, "Choose")
        XCTAssertEqual(blocks[0].optionPreferenceKey, "OptionChoice")
        XCTAssertEqual(blocks[0].optionCards?.first?.label, "C")
        XCTAssertNil(blocks[0].option, "the container must be nil'd after folding")
        XCTAssertEqual(blocks[1].wallpaperSelectionKey, "w")
        XCTAssertEqual(blocks[1].wallpaperPreferenceKey, "p")
        XCTAssertEqual(blocks[1].wallpaperShowPath, true)
        XCTAssertEqual(blocks[1].wallpaperConfirmButton, "Set")
        XCTAssertEqual(blocks[1].wallpaperLayout, "grid")
        XCTAssertEqual(blocks[1].wallpaperMultiSelect, 2)
        XCTAssertEqual(blocks[1].wallpaperThumbnailHeight, 140)
        XCTAssertEqual(blocks[1].wallpaperCategories?.first?.title, "4K")
        XCTAssertNil(blocks[1].wallpaper, "the container must be nil'd after folding")
    }

    /// Both spellings: grouped wins with an advisory, and the container is a known block key.
    func testBlockLevelOptionAndWallpaperGroupedWinsWithAnAdvisory() throws {
        let s = try step("""
        {"id": "s", "content": [
          {"type": "option-picker", "optionLayout": "rows", "option": {"layout": "grid"}},
          {"type": "wallpaper-picker", "wallpaperSelectionKey": "flat",
           "wallpaper": {"selectionKey": "grouped"}}]}
        """)
        XCTAssertEqual(s.content?[0].optionLayout, "grid", "the grouped value wins")
        XCTAssertEqual(s.content?[1].wallpaperSelectionKey, "grouped", "the grouped value wins")
        XCTAssertTrue(InspectConfig.unknownKeyWarnings.isEmpty,
                      "the conflict is a canonicalization advisory, not an unknown key: "
                      + "\(InspectConfig.unknownKeyWarnings)")
    }

    /// The option and wallpaper folds also run through `ItemConfig`.
    func testBlockLevelOptionAndWallpaperFoldThroughTheItemDecoder() throws {
        let json = #"""
        {"preset": "6", "items": [{"id": "i", "displayName": "I", "guidanceContent": [
          {"type": "option-picker", "option": {"key": "k", "multiSelect": true}},
          {"type": "wallpaper-picker", "wallpaper": {"preferenceKey": "p", "multiSelect": 2}}]}]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let blocks = try XCTUnwrap(config.items.first?.guidanceContent)
        XCTAssertEqual(blocks[0].optionKey, "k")
        XCTAssertEqual(blocks[0].optionMultiSelect, true)
        XCTAssertNil(blocks[0].option)
        XCTAssertEqual(blocks[1].wallpaperPreferenceKey, "p")
        XCTAssertEqual(blocks[1].wallpaperMultiSelect, 2)
        XCTAssertNil(blocks[1].wallpaper)
    }

    // MARK: - Picker steps default to bands

    /// Picker steps default to the bands stance; an authored key still wins.
    func testPickerStepsDefaultToBands() {
        for stepType in ["options", "dock", "brandPicker"] {
            let stance = ContentStanceResolver.presetDefault(forStepType: stepType,
                                                             preset: .topLeading)
            XCTAssertEqual(stance.anchor, .bands,
                           "\(stepType) should default to the design's bands")
        }
    }

    /// The bands default leaves horizontal alignment alone.
    func testBandsDefaultLeavesAlignmentAlone() {
        XCTAssertEqual(ContentStanceResolver.presetDefault(forStepType: "dock",
                                                           preset: .topLeading).align,
                       ContentStance.topLeading.align)
    }

    /// Substeps, which has no hero, centres its group instead of banding.
    func testSubstepsCentresRatherThanBanding() {
        let stance = ContentStanceResolver.presetDefault(forStepType: "substeps", preset: .topLeading)
        XCTAssertEqual(stance.anchor, .center)
        XCTAssertEqual(stance.align, ContentStance.centered.align,
                       "a vertically centred screen with a flush-left text edge reads as a mistake")
    }

    /// `assistant` centres, so its `symmetricCenter: true` takes effect.
    func testAssistantCentresRatherThanPinningToTheTop() {
        let stance = ContentStanceResolver.presetDefault(forStepType: "assistant", preset: .topLeading)
        XCTAssertEqual(stance.anchor, .center,
                       "assistant already asks for symmetricCenter; the anchor must agree with it")
    }

    /// Other step types keep the preset's stance (`assistant` is covered above).
    func testNonPickerStepsKeepThePresetDefault() {
        for stepType in ["standard", "guide", "media"] {
            XCTAssertEqual(ContentStanceResolver.presetDefault(forStepType: stepType,
                                                               preset: .topLeading).anchor,
                           StepAnchor.top,
                           "\(stepType) must not silently acquire bands")
        }
    }

    /// An authored `contentAnchor` beats the bands default.
    func testAuthoredAnchorStillBeatsTheBandsDefault() {
        let resolved = ContentStanceResolver.resolve(
            stepAnchor: "top", stepAlign: nil,
            configAnchor: nil, configAlign: nil,
            preset: ContentStanceResolver.presetDefault(forStepType: "dock", preset: .topLeading))
        XCTAssertEqual(resolved.anchor, .top)
    }

    // MARK: - The fold consumes its aliases

    /// After canonicalization `guidanceTitle`, `guidanceContent`, `icon` and `itemOverlay` are cleared,
    /// so one spelling of each fact survives.
    func testAliasSpellingsAreClearedAfterFolding() throws {
        let json = #"""
        {"preset":"6","title":"t","steps":[{"id":"s1","stepType":"intro",
          "guidanceTitle":"Hello","guidanceContent":[{"type":"text","content":"hi"}]}]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let step = try XCTUnwrap(config.steps?.first)
        XCTAssertEqual(step.title, "Hello")
        XCTAssertEqual(step.content?.first?.type, "text")
        XCTAssertNil(step.guidanceTitle, "alias survived the fold")
        XCTAssertNil(step.guidanceContent, "alias survived the fold")
    }

    /// The alias is cleared even when the canonical field won.
    func testTheAliasIsClearedEvenWhenTheCanonicalFieldWon() throws {
        let json = #"""
        {"preset":"6","title":"t","steps":[{"id":"s1","stepType":"intro",
          "title":"Canonical","guidanceTitle":"Alias",
          "content":[{"type":"text","content":"canonical"}],
          "guidanceContent":[{"type":"text","content":"alias"}]}]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let step = try XCTUnwrap(config.steps?.first)
        XCTAssertEqual(step.title, "Canonical", "the canonical spelling wins")
        XCTAssertEqual(step.content?.first?.content, "canonical")
        XCTAssertNil(step.guidanceTitle, "the losing alias must not survive")
        XCTAssertNil(step.guidanceContent, "the losing alias must not survive")
    }

    // MARK: - Secure-field exclusion

    /// A step authored with `content:` has a nil `guidanceContent`, so `secureFieldIds` must read `$1.content`.
    func testSecureFieldAuthoredCanonicallyIsInvisibleOnTheAlias() throws {
        let json = #"""
        {"preset":"6","title":"t","steps":[{"id":"s1","stepType":"intro",
          "content":[{"type":"textfield","id":"pw","secure":true}]}]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let step = try XCTUnwrap(config.steps?.first)
        XCTAssertEqual(step.content?.first?.secure, true, "the canonical spelling carries the field")
        XCTAssertNil(step.guidanceContent,
                     "alias is nil for canonical authoring — any reader of the alias sees NO secure fields")
    }

    /// Preset 6's exclusion set is built from `$1.content`, as in Preset 5.
    func testPreset6SecureFieldExclusionReadsCanonicalContent() throws {
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts/Preset6+Commands.swift"),
            encoding: .utf8)
        XCTAssertTrue(source.contains("formUnion(secureFieldIds(in: $1.content))"),
                      "Preset 6's secure-field exclusion no longer reads the canonical content field")
        XCTAssertFalse(source.contains("secureFieldIds(in: $1.guidanceContent)"),
                       "the stale-alias read is back")
    }
}

// MARK: - Identifiable stability

/// A computed `Identifiable.id` returns the same value on every access, never a fresh `UUID()`.
final class IdentifiableStabilityTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    /// An item without identifying fields keeps a stable id.
    func testGridItemWithoutAnIdKeepsTheSameIdAcrossAccesses() throws {
        let item = try decode(InspectConfig.GridItemConfig.self, #"{"title": "Engineering"}"#)
        XCTAssertEqual(item.id, item.id, "id must not change between reads")
        XCTAssertFalse(item.id.isEmpty)
        // Falls through to `title`.
        XCTAssertEqual(item.id, "Engineering")
    }

    /// A completely empty item still has a stable id.
    func testTotallyEmptyGridItemIsStableNotRandom() throws {
        let item = try decode(InspectConfig.GridItemConfig.self, "{}")
        XCTAssertEqual(item.id, item.id)
        XCTAssertEqual(item.id, "grid-item")
    }

    /// Authored identity wins, in its authored precedence.
    func testAuthoredIdentityStillWins() throws {
        let explicit = try decode(InspectConfig.GridItemConfig.self,
                                  #"{"id": "eng", "value": "e", "title": "Engineering"}"#)
        XCTAssertEqual(explicit.id, "eng")
        let byValue = try decode(InspectConfig.GridItemConfig.self, #"{"value": "e", "title": "Engineering"}"#)
        XCTAssertEqual(byValue.id, "e")
    }

    func testMediaItemAndSubStepIdsAreStableToo() throws {
        let media = try decode(InspectConfig.MediaItemConfig.self, #"{"caption": "A still"}"#)
        XCTAssertEqual(media.id, media.id)
        XCTAssertEqual(media.id, "A still")

        let sub = try decode(InspectConfig.SubStep.self, #"{"text": "Do the thing"}"#)
        XCTAssertEqual(sub.id, sub.id)
        XCTAssertEqual(sub.id, "Do the thing")
    }
}
