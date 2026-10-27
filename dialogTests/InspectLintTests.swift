//
//  InspectLintTests.swift
//  dialogTests
//
//  The config lint: its findings and the script keys it knows.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// Lint: the whole-flow checks an author needs before running anything.
@MainActor
final class InspectLintTests: XCTestCase {

    private func findings(_ json: String) -> [InspectLintFinding] {
        InspectLint.lint(data: Data(json.utf8))
    }

    private let clean = #"""
    {"preset":"5","chrome":"provisioning","introSteps":[
      {"id":"pick","stepType":"options","optionMultiSelect":true,"optionKey":"tasks",
       "optionCards":[{"id":"a","label":"A","category":"One","cancels":["category:Two"]},
                      {"id":"b","label":"B","category":"Two"}]},
      {"id":"check","stepType":"review"},
      {"id":"run","stepType":"cadence"},
      {"id":"done","stepType":"outro","receipt":[{"stepId":"pick","label":"Tasks","selectionKey":"tasks"}]}]}
    """#

    /// A bullets block with no `items` draws nothing (as in 3.1.1), so lint names it.
    func testABulletsBlockWithoutItemsIsReported() {
        let all = findings(#"""
        {"preset":"5","introSteps":[{"id":"s","content":[{"type":"bullets","content":"Lost text"},
                                                        {"type":"bullets","items":["Shown"]}]}]}
        """#)
        XCTAssertEqual(all.map(\.path), ["introSteps[s].content[0]"], "\(all)")
    }

    /// A translated step flow whose sidecar lacks the button and counter keys keeps them in the
    /// config's language; lint lists the missing keys per language file.
    func testASidecarWithoutStepChromeIsReported() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lint-chrome-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(#"{"a.title":"Hallo","a.continueButtonText":"Weiter"}"#.utf8).write(to: dir.appendingPathComponent("de.json"))
        try Data(#"{"a.title":"Hello"}"#.utf8).write(to: dir.appendingPathComponent("en.json"))
        // English is the built-in chrome language, so its sidecar is not reported.
        let json = #"""
        {"preset":"5","localization":{"languages":{"de":"de.json","English":"en.json"}},
         "introSteps":[{"id":"a","title":"Hello"},{"id":"b","title":"Next"}]}
        """#
        let all = InspectLint.lint(data: Data(json.utf8), configPath: dir.appendingPathComponent("flow.json").path)
        XCTAssertEqual(all.count, 1, "\(all)")
        XCTAssertEqual(all.first?.path, "localization.languages[de]")
        XCTAssertTrue(all.first?.message.contains("b.continueButtonText, b.backButtonText, _ui.stepCounterFormat") == true,
                      all.first?.message ?? "")
    }

    func testACleanStepFlowHasNoFindings() {
        let all = findings(clean)
        XCTAssertEqual(all, [], "\(all)")
        XCTAssertEqual(InspectLint.exitCode(for: all), 0)
    }

    func testEachWholeFlowCheckFires() {
        let broken = clean
            .replacingOccurrences(of: #""cancels":["category:Two"]"#, with: #""cancels":["category:Nope","ghost"]"#)
            .replacingOccurrences(of: #""stepId":"pick""#, with: #""stepId":"gone""#)
            .replacingOccurrences(of: #""preset":"5","#, with: #""preset":"5","phaseBackgroundPalette":["preset:g99"],"#)
        let messages = findings(broken).map(\.message).joined(separator: "\n")
        XCTAssertTrue(messages.contains("'category:Nope' names no category"), messages)
        XCTAssertTrue(messages.contains("'ghost' is not an option"), messages)
        XCTAssertTrue(messages.contains("points at step 'gone'"), messages)
        XCTAssertTrue(messages.contains("'preset:g99' is not a gradient preset"), messages)
        XCTAssertEqual(InspectLint.exitCode(for: findings(broken)), 1)
    }

    func testAFollowerWithNothingToFollowIsAnError() {
        let noChooser = #"{"preset":"5","introSteps":[{"id":"check","stepType":"review"},{"id":"run","stepType":"cadence"}]}"#
        let messages = findings(noChooser).map(\.message)
        XCTAssertTrue(messages.contains { $0.contains("no multi-select chooser to follow") }, "\(messages)")
        XCTAssertTrue(messages.contains { $0.contains("no entries and no chooser") }, "\(messages)")
    }

    func testAShowWhenNobodyRecordsIsAWarning() {
        let json = clean.replacingOccurrences(of: #"{"id":"check","stepType":"review"}"#,
                                              with: #"{"id":"check","stepType":"review","showWhen":{"key":"nobody","anyOf":["x"]}}"#)
        let found = findings(json).first { $0.path == "introSteps[check].showWhen" }
        XCTAssertEqual(found?.severity, .warning)
    }
}

// Lint counts a key a sibling script records (`select:<key>:`) as recorded.
final class LintScriptKeysTests: XCTestCase {
    func testSelectLinesInAScriptAreRecordedKeys() {
        let script = #"send "select:installed:${(j:,:)INSTALLED}"; echo "select:team.pick:eng""#
        XCTAssertEqual(InspectLint.scriptKeys(inScript: script), ["installed", "team.pick"])
        XCTAssertTrue(InspectLint.scriptKeys(inScript: "cadence:satisfy:zoom").isEmpty)
    }
}

/// The legacy layer: 3.1.1 keys translated in memory, each with a note lint shows.
@MainActor
final class InspectLegacyRemapTests: XCTestCase {

    private func remap(_ json: String) throws -> InspectLegacyRemap.Result {
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        return InspectLegacyRemap.apply(object)
    }

    private func step(_ r: InspectLegacyRemap.Result, _ index: Int = 0) -> [String: Any] {
        ((r.object["introSteps"] as? [Any])?[index] as? [String: Any]) ?? [:]
    }

    func testFooterLinkBecomesFooterNoteAndTheV6KeyWins() throws {
        var r = try remap(#"{"preset":"5","introSteps":[{"id":"a","footerLink":"About Privacy…"}]}"#)
        XCTAssertEqual(step(r)["footerNote"] as? String, "About Privacy…")
        XCTAssertNil(step(r)["footerLink"], "the old key is removed, so the unknown-key audit stays quiet")
        XCTAssertTrue(r.notes.contains { $0.contains("introSteps[a]") && $0.contains("'footerLink' remapped → 'footerNote'") })

        r = try remap(#"{"preset":"5","introSteps":[{"id":"a","footerLink":"old","footerNote":"new"}]}"#)
        XCTAssertEqual(step(r)["footerNote"] as? String, "new")
        XCTAssertTrue(r.notes.contains { $0.contains("redundant") })
    }

    func testKeyPointsAndBulletsFoldIntoTheStepsBlocks() throws {
        let r = try remap(#"{"preset":"5","introSteps":[{"id":"g","stepType":"guide","content":[{"type":"text","content":"Hi"}],"guideKeyPoints":"Keep it on power.","guideBulletPoints":["One","Two"]}]}"#)
        let blocks = try XCTUnwrap(step(r)["content"] as? [[String: Any]])
        XCTAssertEqual(blocks.map { $0["type"] as? String }, ["text", "info", "bullets"], "authored blocks first, as with guideText")
        XCTAssertEqual(blocks[1]["title"] as? String, "Key Points")
        XCTAssertEqual(blocks[2]["items"] as? [String], ["One", "Two"])

        let alias = try remap(#"{"preset":"5","introSteps":[{"id":"g","guidanceContent":[{"type":"text","content":"Hi"}],"guideBulletPoints":["One"]}]}"#)
        XCTAssertEqual((step(alias)["guidanceContent"] as? [Any])?.count, 2, "appended to the alias the step uses")
        XCTAssertNil(step(alias)["content"])
    }

    func testSizeSetsTheWindowOnlyWhereItChangedTheWindow() throws {
        let large = try remap(#"{"preset":"5","size":"large","introSteps":[{"id":"a"}]}"#)
        XCTAssertEqual(large.object["width"] as? Int, 1200)
        XCTAssertEqual(large.object["height"] as? Int, 800)

        let explicit = try remap(#"{"preset":"5","size":"large","width":900,"height":700,"introSteps":[{"id":"a"}]}"#)
        XCTAssertEqual(explicit.object["width"] as? Int, 900)
        XCTAssertTrue(explicit.notes.contains { $0.contains("redundant") })

        XCTAssertTrue(try remap(#"{"preset":"2","size":"large","items":[]}"#).notes.isEmpty, "Presets 1–3 never read size")
        XCTAssertTrue(try remap(#"{"preset":"5","size":"standard","introSteps":[]}"#).notes.isEmpty, "standard matches v6")
    }

    func testPreset3BackdropBecomesThePhaseBackdrop() throws {
        let r = try remap(##"{"preset":"3","gradientColors":["#112233","#445566"],"backgroundImage":"/tmp/x.png","items":[]}"##)
        XCTAssertEqual(r.object["phaseBackground"] as? String, "gradient")
        XCTAssertEqual(r.object["phaseBackgroundPalette"] as? [String], ["#112233", "#445566"])
        XCTAssertTrue(r.notes.contains { $0.contains("'backgroundImage'") && $0.contains("no effect") })

        let p5 = try remap(##"{"preset":"5","gradientColors":["#112233","#445566"],"introSteps":[]}"##)
        XCTAssertNil(p5.object["phaseBackground"], "only Preset 3 drew gradientColors as its backdrop")
    }

    func testPreset6IntroLayoutMovesTheHeroKeysAndNamesTheDeadOnes() throws {
        let r = try remap(#"{"preset":"6","items":[{"id":"welcome","introLayoutConfig":{"heroImageSize":120,"heroImagePadding":8,"logoImage":"/x.png"}}]}"#)
        let item = try XCTUnwrap((r.object["items"] as? [Any])?.first as? [String: Any])
        XCTAssertEqual(item["heroImageSize"] as? Int, 120)
        XCTAssertEqual(item["heroImagePadding"] as? Int, 8)
        XCTAssertNil(item["introLayoutConfig"])
        XCTAssertTrue(r.notes.contains { $0.contains("logoImage never had an effect") })
    }

    func testBlockKeysWithNoEffectAreRemovedWhereverTheyAre() throws {
        let r = try remap(#"{"preset":"5","introSteps":[{"id":"p","content":[{"type":"portal-webview","portalShowHeader":true,"portalOfflineMessage":"Offline"},{"type":"button","shellTimeout":30}]}]}"#)
        let blocks = try XCTUnwrap(step(r)["content"] as? [[String: Any]])
        XCTAssertNil(blocks[0]["portalShowHeader"])
        XCTAssertNil(blocks[0]["portalOfflineMessage"])
        XCTAssertNil(blocks[1]["shellTimeout"])
        XCTAssertEqual(r.notes.filter { $0.contains("no effect") }.count, 3)
    }

    func testA3_1_1ConfigLintsWithRemapNotesAndExitsTwo() {
        let json = #"{"preset":"5","size":"large","introSteps":[{"id":"a","title":"Hi","footerLink":"About","guideStepBadge":"REQUIRED"}]}"#
        let findings = InspectLint.lint(data: Data(json.utf8))
        let messages = findings.map(\.message)
        XCTAssertTrue(messages.contains { $0.contains("'footerLink' remapped") })
        XCTAssertTrue(messages.contains { $0.contains("'guideStepBadge' remapped") })
        XCTAssertTrue(messages.contains { $0.contains("'size: large' remapped") })
        XCTAssertFalse(messages.contains { $0.contains("Unknown key 'footerLink'") }, "reported once, as a remap")
        XCTAssertEqual(messages.filter { $0.contains("'footerLink' remapped") }.count, 1, "once, though the schema check runs more than once")
        XCTAssertFalse(findings.contains { $0.severity == .error })
        XCTAssertEqual(InspectLint.exitCode(for: findings), 2, "warnings only: lint's standard exit for notes")
    }
}

/// Steps sent at runtime go through the same legacy rules; the interval line names its source.
@MainActor
final class RuntimeRemapAndScanIntervalTests: XCTestCase {
    func testAStepAddedAtRuntimeIsRemapped() throws {
        let envelope: StepAddEnvelope<InspectConfig.IntroStep> =
            try decodeStepEnvelope(#"{"step":{"id":"x","title":"T","footerLink":"About…","guideBulletPoints":["One"]},"at":0}"#)
        XCTAssertEqual(envelope.step.footerNote, "About…")
        XCTAssertEqual(envelope.step.content?.count, 1, "the bullets block")
        XCTAssertEqual(envelope.at, 0, "the envelope's own keys survive")
    }

    func testTheScanIntervalLineNamesItsSource() {
        XCTAssertEqual(InspectConstants.scanIntervalSource(nil), "(default)")
        XCTAssertEqual(InspectConstants.scanIntervalSource(30), "(scanInterval 30)")
        XCTAssertEqual(InspectConstants.scanIntervalSource(0), "(scanInterval 0 raised to the 1 s floor)")
        XCTAssertEqual(InspectConstants.scanInterval(0), 1)
    }
}
