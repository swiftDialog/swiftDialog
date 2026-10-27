//
//  BlockKeyReachTests.swift
//  dialogTests
//
//  Block keys reach every host that renders the block. These read the renderer source and check
//  that a block type's arm reads the key. Assert the whole expression (`caption: block.label`),
//  never a fragment that could match without the property being read.
//

import XCTest
@testable import Dialog

final class BlockKeyReachTests: XCTestCase {

    // MARK: - paragraph/text synonyms

    private func block(_ json: String) throws -> InspectConfig.GuidanceContent {
        try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
    }

    /// A synonym type with a synonym field (`paragraph` + `text`) renders its copy.
    func testParagraphWithTextRendersItsCopy() throws {
        let authored = try block("""
        { "type": "paragraph", "text": "This is a Preset 5 workflow." }
        """)
        XCTAssertNil(authored.content, "as authored, `content` is empty — this is the trap")
        let normalized = InspectConfig.GuidanceContent.normalized(authored)
        XCTAssertEqual(normalized.content, "This is a Preset 5 workflow.",
                       "normalization folds `text` into `content` so a render arm sees the copy")
    }

    /// `paragraph` shares the `text` arm.
    func testParagraphSharesTheTextArm() throws {
        let source = try inspectSource("Core Framework/Components/GuidanceContentView.swift")
        XCTAssertTrue(source.contains("case \"text\", \"paragraph\":"),
                      "paragraph is a label on the text arm, not an arm of its own")
    }

    /// Canonical `content` is never overwritten; with both spellings, `content` wins.
    func testCanonicalContentIsNeverOverwritten() throws {
        let canonical = try block("""
        { "type": "text", "content": "canonical" }
        """)
        XCTAssertEqual(InspectConfig.GuidanceContent.normalized(canonical).content, "canonical")

        let both = try block("""
        { "type": "text", "content": "canonical", "text": "alias" }
        """)
        XCTAssertEqual(InspectConfig.GuidanceContent.normalized(both).content, "canonical",
                       "content wins — the alias only fills a hole, it never replaces")
    }

    /// An empty alias is not folded, so a blank block is skipped rather than drawn empty.
    func testEmptyAliasIsNotFolded() throws {
        let blank = try block("""
        { "type": "paragraph", "text": "" }
        """)
        XCTAssertNil(InspectConfig.GuidanceContent.normalized(blank).content)
    }

    /// `text` is a known block key.
    func testTextIsARegisteredBlockKey() {
        XCTAssertTrue(InspectConfig.knownBlockKeys.contains("text"),
                      "the alias is registered, so it does not trip the unknown-key advisory")
    }

    /// The schema accepts the `paragraph` type and declares `text`.
    func testSchemaAcceptsBothSynonyms() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let defs = schema?["definitions"] as? [String: Any]
        let guidance = defs?["GuidanceContent"] as? [String: Any]
        let props = guidance?["properties"] as? [String: Any]
        let typeEnum = (props?["type"] as? [String: Any])?["enum"] as? [String]
        XCTAssertEqual(typeEnum?.contains("paragraph"), true, "schema accepts the paragraph type")
        XCTAssertNotNil(props?["text"], "schema declares the text alias")
    }

    /// Schema block types and `GuidanceContentView`'s dispatcher arms are the same set; the
    /// `default:` arm would otherwise draw an unknown type as plain text.
    func testEverySchemaBlockTypeHasARendererArm() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let defs = schema?["definitions"] as? [String: Any]
        let props = (defs?["GuidanceContent"] as? [String: Any])?["properties"] as? [String: Any]
        let declared = Set((props?["type"] as? [String: Any])?["enum"] as? [String] ?? [])
        XCTAssertFalse(declared.isEmpty, "schema type enum not found")

        // From `contentBlockView(for:)` to `default:`, plus the type routed by the `if` before the switch.
        // Only arms at the switch's own indentation count; deeper `case` lines belong to nested switches.
        let source = try inspectSource("Core Framework/Components/GuidanceContentView.swift")
        let start = try XCTUnwrap(source.range(of: "func contentBlockView(for block"))
        let end = try XCTUnwrap(source.range(of: "\n        default:", range: start.upperBound..<source.endIndex))
        let dispatcher = String(source[start.lowerBound..<end.lowerBound])
        var handled = Set<String>()
        for line in dispatcher.split(separator: "\n")
        where line.hasPrefix("        case \"") || line.hasPrefix("        if block.type == \"") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let head = trimmed.split(separator: ":", maxSplits: 1).first.map(String.init) ?? trimmed
            let quoted = head.split(separator: "\"", omittingEmptySubsequences: false)
            handled.formUnion(stride(from: 1, to: quoted.count, by: 2).map { String(quoted[$0]) })
        }

        XCTAssertEqual(declared.subtracting(handled).sorted(), [],
                       "schema block types with no renderer arm (they draw as plain text)")
        XCTAssertEqual(handled.subtracting(declared).sorted(), [],
                       "renderer arms for types the schema does not accept")
    }

    /// `InspectConfig.knownBlockKeys` and the schema's `GuidanceContent` properties are one set.
    func testSchemaDeclaresEveryDecodedBlockKey() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let defs = schema?["definitions"] as? [String: Any]
        let props = (defs?["GuidanceContent"] as? [String: Any])?["properties"] as? [String: Any]
        let declared = Set(props?.keys.map { $0 } ?? [])
        XCTAssertFalse(declared.isEmpty, "schema GuidanceContent properties not found")

        XCTAssertEqual(InspectConfig.knownBlockKeys.subtracting(declared).sorted(), [],
                       "block keys the decoder reads that the schema does not declare")
        XCTAssertEqual(declared.subtracting(InspectConfig.knownBlockKeys).sorted(), [],
                       "block keys the schema declares that the decoder does not read")
    }

    private func inspectSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect")
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Slices the `case "<caseLabel>":` arm out of a `switch block.type`, up to the next
    /// `case`/`default` at the same indentation; empty if the arm is missing. `after` anchors the
    /// search in files that switch more than once; an ambiguous label without one throws.
    enum ArmTextError: Error, CustomStringConvertible {
        case ambiguous(label: String, count: Int, path: String)

        var description: String {
            switch self {
            case let .ambiguous(label, count, path):
                return "case \"\(label)\": occurs \(count)x in \(path) — pass `after:` naming "
                     + "the enclosing declaration to say which one you mean"
            }
        }
    }

    private func armText(_ relativePath: String, caseLabel: String, after anchor: String? = nil) throws -> String {
        let source = try inspectSource(relativePath)
        let lines = source.components(separatedBy: "\n")
        let needle = "case \"\(caseLabel)\":"
        if anchor == nil {
            let occurrences = lines.filter { $0.contains(needle) }.count
            guard occurrences <= 1 else {
                throw ArmTextError.ambiguous(label: caseLabel, count: occurrences,
                                             path: relativePath)
            }
        }
        var searchFrom = lines.startIndex
        if let anchor {
            guard let anchorIndex = lines.firstIndex(where: { $0.contains(anchor) }) else {
                return ""
            }
            searchFrom = lines.index(after: anchorIndex)
        }
        guard let startIndex = lines[searchFrom...].firstIndex(where: { $0.contains(needle) }) else {
            return ""
        }
        let indent = lines[startIndex].prefix(while: { $0 == " " }).count

        var endIndex = lines.count
        for index in (startIndex + 1)..<lines.count {
            let line = lines[index]
            let lineIndent = line.prefix(while: { $0 == " " }).count
            guard lineIndent == indent else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("case \"") || trimmed.hasPrefix("default:") {
                endIndex = index
                break
            }
        }
        return lines[startIndex..<endIndex].joined(separator: "\n")
    }

    /// The `knownBlockKeys` array literal alone; `dockDecline` also appears in `knownStepKeys`.
    private func knownBlockKeysLiteral(from source: String) throws -> String {
        let lines = source.components(separatedBy: "\n")
        guard let startIndex = lines.firstIndex(where: { $0.contains("static let knownBlockKeys") }) else {
            return ""
        }
        var endIndex = lines.count
        for index in startIndex..<lines.count where lines[index].trimmingCharacters(in: .whitespaces) == "]" {
            endIndex = index
            break
        }
        return lines[startIndex...min(endIndex, lines.count - 1)].joined(separator: "\n")
    }

    // MARK: - Phase tracker label

    /// The guidance phase-tracker arm passes `caption: block.label`, as Preset 5 does.
    func testPhaseTrackerLabelReachesEveryHost() throws {
        let arm = try armText("Core Framework/Components/GuidanceContentView.swift",
                              caseLabel: "phase-tracker")
        XCTAssertFalse(arm.isEmpty, "phase-tracker arm not found — GuidanceContentView.swift may have moved")
        XCTAssertTrue(arm.contains("caption: block.label"),
                      "guidance's phase-tracker arm never passes the block's label")
    }

    // MARK: - Bullets numbered

    /// The gallery side panel reads `block.numbered`.
    func testBulletsNumberedReachesTheGallerySidePanel() throws {
        let arm = try armText("Core Framework/Components/MediaComponents.swift",
                              caseLabel: "bullets")
        XCTAssertFalse(arm.isEmpty, "bullets arm not found — MediaComponents.swift may have moved")
        XCTAssertTrue(arm.contains("block.numbered"),
                      "GallerySideContentBlock's bullets arm ignores block.numbered")
    }

    // MARK: - Text bold

    /// Card chrome's text arm reads `block.bold`.
    func testTextBoldReachesCardChrome() throws {
        let arm = try armText("Core Framework/Components/CardStepScreen.swift",
                              caseLabel: "text")
        XCTAssertFalse(arm.isEmpty, "text arm not found — CardStepScreen.swift may have moved")
        XCTAssertTrue(arm.contains("block.bold"),
                      "card chrome's text arm ignores block.bold")
    }

    // MARK: - Block-level dockDecline

    /// `dockDecline` is a known block key, not only a step key.
    func testDockDeclineExistsAtBlockLevel() throws {
        let known = try inspectSource("Core Framework/InspectConfigKnownKeys.swift")
        let blockKeys = try knownBlockKeysLiteral(from: known)
        XCTAssertFalse(blockKeys.isEmpty, "knownBlockKeys literal not found — InspectConfigKnownKeys.swift may have moved")
        XCTAssertTrue(blockKeys.contains("dockDecline"),
                      "dockDecline absent from knownBlockKeys")
    }

    // MARK: - Dock arm passes decline

    /// The block dock arm passes `decline: block.dockDecline`; decoding it is not enough.
    func testBlockDockArmPassesDecline() throws {
        let arm = try armText("Core Framework/Components/GuidanceContentView.swift",
                              caseLabel: "dock-picker",
                              after: "private func contentBlockView")
        XCTAssertFalse(arm.isEmpty, "dock-picker arm not found — GuidanceContentView.swift may have moved")
        XCTAssertTrue(arm.contains("DockPickerView("),
                      "sliced a `dock-picker` arm that does not construct the picker — wrong switch")
        XCTAssertTrue(arm.contains("decline: block.dockDecline"),
                      "the block-level dock arm still does not pass a decline card")
    }

    /// Every outro `DockPickerView(` call site passes `decline: config.dockDecline`, checked per call site.
    func testOutroDockPassesDecline() throws {
        let source = try inspectSource("Core Framework/Components/BookendScreenView.swift")
        let sites = callArgumentLists(of: "DockPickerView(", in: source)
        XCTAssertFalse(sites.isEmpty,
                       "no DockPickerView call site found in the outro — did the view move?")
        for (index, site) in sites.enumerated() {
            XCTAssertTrue(site.contains("decline: config.dockDecline"),
                          "outro DockPickerView call site \(index) does not pass a decline card")
        }
    }

    /// Every `<constructor>(` argument list, sliced to its balanced closing paren.
    private func callArgumentLists(of constructor: String, in source: String) -> [String] {
        var lists: [String] = []
        var searchStart = source.startIndex
        while let hit = source.range(of: constructor, range: searchStart..<source.endIndex) {
            var depth = 1
            var i = hit.upperBound
            while i < source.endIndex, depth > 0 {
                if source[i] == "(" { depth += 1 } else if source[i] == ")" { depth -= 1 }
                i = source.index(after: i)
            }
            lists.append(String(source[hit.upperBound..<i]))
            searchStart = i
        }
        return lists
    }

    // MARK: - armText contract

    /// An ambiguous label without an anchor throws rather than slicing the first match.
    func testArmTextRefusesAmbiguousLabelsWithoutAnAnchor() throws {
        // "dock-picker" occurs in GuidanceSelectionKeys.authoredKey and in contentBlockView.
        XCTAssertThrowsError(
            try armText("Core Framework/InspectState+FormInputs.swift",
                        caseLabel: "checkbox")
        ) { error in
            guard case let ArmTextError.ambiguous(label, count, _) = error else {
                return XCTFail("expected ArmTextError.ambiguous, got \(error)")
            }
            XCTAssertEqual(label, "checkbox")
            XCTAssertGreaterThan(count, 1, "the error must name the count that made it ambiguous")
        }
    }

    /// An anchored call still resolves, and a unique label works without one.
    func testArmTextStillResolvesAnchoredAndUniqueLabels() throws {
        let anchored = try armText("Core Framework/Components/GuidanceContentView.swift",
                                   caseLabel: "dock-picker", after: "contentBlockView")
        XCTAssertFalse(anchored.isEmpty, "the anchored dock-picker arm should still slice")
        XCTAssertTrue(anchored.contains("DockPicker"),
                      "the anchor should land on the RENDER arm, not the key mapping: \(anchored.prefix(200))")
    }

    // MARK: - Layout and content

    /// Both default phase views pass `contentBlocks: config.content ?? []` to `BookendScreenView`,
    /// checked per view.
    func testTheDefaultPhaseLayoutRendersScreenContent() throws {
        let phaseViews = try inspectSource("Core Framework/Components/PresetPhaseViews.swift")
        let needle = "contentBlocks: config.content ?? []"

        for view in ["PresetIntroScreenView", "PresetSummaryScreenView"] {
            guard let start = phaseViews.range(of: "struct \(view)") else {
                return XCTFail("\(view) is not in PresetPhaseViews.swift — did it move?")
            }
            // To the next top-level `struct ` declaration, or end of file.
            let rest = phaseViews[start.upperBound...]
            let end = rest.range(of: "\nstruct ")?.lowerBound ?? phaseViews.endIndex
            let slice = phaseViews[start.lowerBound..<end]

            let passes = slice.components(separatedBy: needle).count - 1
            XCTAssertEqual(passes, 1,
                           "\(view)'s default body must pass config.content into "
                           + "BookendScreenView exactly once — got \(passes)")
        }
    }

    /// `stepRenderableBookendLayouts` is pinned by value: a layout joins it only with a step renderer
    /// behind it, and the projection warns about the rest.
    func testBookendProjectionStatesWhichLayoutsTheStepPathHonours() throws {
        // Preset5 routes the reserved bookend ids into BookendScreenView with the root screen config.
        XCTAssertEqual(InspectConfig.stepRenderableBookendLayouts,
                       ["centered", "overview", "welcome", "explainer",
                        "dock", "receipt", "nextsteps"],
                       "the step path's renderable-layout set changed — every value needs a "
                       + "renderer behind it, wired in the same commit that grows this set.")

        let steps = try inspectSource("Core Framework/InspectConfig+Bookends.swift")
        XCTAssertTrue(steps.contains("!stepRenderableBookendLayouts.contains(layout)"),
                      "the projection no longer guards on the renderable-layout set, so a "
                      + "non-renderable layout would project silently")
        XCTAssertTrue(steps.contains("which no \\\n                path renders"),
                      "the projection's layout-loss warning is gone — losing a layout must stay "
                      + "loud, per the layout advisory")

        // Both reserved ids route into the bookend surface with their root screen config.
        let preset5 = try inspectSource("Preset Layouts/Preset5.swift")
        for needle in ["step.id == InspectConfig.reservedIntroStepId",
                       "step.id == InspectConfig.reservedOutroStepId",
                       "intro: intro,", "summary: summary,"] {
            XCTAssertTrue(preset5.contains(needle),
                          "Preset5's ceremony arm lost '\(needle)' — the grown "
                          + "stepRenderableBookendLayouts set would overclaim what the step "
                          + "path renders")
        }
    }
}
