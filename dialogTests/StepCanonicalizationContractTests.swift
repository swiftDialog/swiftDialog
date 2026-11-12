//
//  StepCanonicalizationContractTests.swift
//  dialogTests
//
//  Schema-reading contracts: step canonicalisation and the silent-default advisory over the
//  fixture corpus.
//

import XCTest
@testable import Dialog

// MARK: - Step Canonicalization Contract

/// Canonicalization is deterministic at decode and count-preserving, so indices are stable on
/// first run and on resume.
final class StepCanonicalizationContractTests: XCTestCase {

    private func decodeStep(_ json: String) throws -> InspectConfig.IntroStep {
        try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(json.utf8))
    }

    private func canonicalize(_ json: String) throws -> InspectConfig.IntroStep {
        var advisories: [String] = []
        return InspectConfig.canonicalizeStep(try decodeStep(json), advisories: &advisories)
    }

    private func advisories(_ json: String) throws -> [String] {
        var advisories: [String] = []
        _ = InspectConfig.canonicalizeStep(try decodeStep(json), advisories: &advisories)
        return advisories
    }

    // MARK: Priority order, one fixture per arm

    func testInstallationWinsOverEverything() throws {
        let step = try canonicalize("""
        {"id":"s","installationMode":"progress","wallpaperCategories":[{"title":"c","images":[]}],
         "optionCards":[{"id":"o","label":"O"}],"dockItems":[{"label":"A","path":"/A"}]}
        """)
        XCTAssertEqual(step.stepType, "installation")
    }

    func testWallpaperWinsOverOptionsAndDock() throws {
        let step = try canonicalize("""
        {"id":"s","wallpaperCategories":[{"title":"c","images":[]}],
         "optionCards":[{"id":"o","label":"O"}],"dockItems":[{"label":"A","path":"/A"}]}
        """)
        XCTAssertEqual(step.stepType, "wallpaper")
    }

    func testOptionsWinsOverDock() throws {
        let step = try canonicalize("""
        {"id":"s","optionCards":[{"id":"o","label":"O"}],"dockItems":[{"label":"A","path":"/A"}]}
        """)
        XCTAssertEqual(step.stepType, "options")
    }

    func testDockMatchesOnEitherField() throws {
        XCTAssertEqual(try canonicalize(#"{"id":"s","dockItems":[{"label":"A","path":"/A"}]}"#).stepType, "dock")
        XCTAssertEqual(try canonicalize(#"{"id":"s","dockFlavors":[{"id":"f","name":"F","items":[]}]}"#).stepType, "dock")
    }

    func testEmptyArraysDoNotSelectARenderer() throws {
        // Empty arrays are not pickers; the step resolves to "standard".
        let step = try canonicalize(#"{"id":"s","optionCards":[],"dockItems":[],"wallpaperCategories":[]}"#)
        XCTAssertEqual(step.stepType, "standard")
    }

    func testStepWithNoPresenceFieldsKeepsItsAuthoredType() throws {
        XCTAssertEqual(try canonicalize(#"{"id":"s","stepType":"bento"}"#).stepType, "bento")
        // A step with nothing to go on is "standard", which makes `resolvedStepType` total.
        XCTAssertEqual(try canonicalize(#"{"id":"s"}"#).stepType, "standard")
    }

    // MARK: The two axes stay separate

    func testAuthoredIntroPhaseSurvivesRendererExplicitization() throws {
        // A wallpaper picker authored as stepType:"intro".
        let step = try canonicalize("""
        {"id":"wallpaper","stepType":"intro","wallpaperCategories":[{"title":"c","images":[]}]}
        """)
        XCTAssertEqual(step.stepType, "wallpaper", "renderer becomes explicit")
        XCTAssertEqual(step.phase, "intro", "and the authored phase is NOT lost")
    }

    func testAuthoredOutroPhaseSurvives() throws {
        let step = try canonicalize("""
        {"id":"done","stepType":"outro","optionCards":[{"id":"o","label":"O"}]}
        """)
        XCTAssertEqual(step.stepType, "options")
        XCTAssertEqual(step.phase, "outro")
    }

    func testExplicitPhaseIsNeverOverwritten() throws {
        let step = try canonicalize("""
        {"id":"s","phase":"outro","stepType":"intro","dockItems":[{"label":"A","path":"/A"}]}
        """)
        XCTAssertEqual(step.phase, "outro", "an authored phase wins over one inferred from stepType")
        XCTAssertEqual(step.stepType, "dock")
    }

    func testPhaseOnlyStepKeepsStepTypeAsPhaseForBackCompat() throws {
        // No presence fields: stepType stays "intro" and phase mirrors it.
        let step = try canonicalize(#"{"id":"s","stepType":"intro"}"#)
        XCTAssertEqual(step.stepType, "intro")
        XCTAssertEqual(step.phase, "intro")
    }

    func testConflictingAuthoredRendererIsLoggedNotSilent() throws {
        let lines = try advisories("""
        {"id":"s","stepType":"assistant","wallpaperCategories":[{"title":"c","images":[]}]}
        """)
        XCTAssertTrue(lines.contains { $0.contains("assistant") && $0.contains("wallpaper") },
                      "an overridden renderer must produce an advisory, got: \(lines)")
    }

    func testMatchingAuthoredRendererIsNotFlagged() throws {
        // Steps that already author options/dock get no advisory.
        XCTAssertTrue(try advisories(#"{"id":"s","stepType":"options","optionCards":[{"id":"o","label":"O"}]}"#).isEmpty)
        XCTAssertTrue(try advisories(#"{"id":"s","stepType":"dock","dockItems":[{"label":"A","path":"/A"}]}"#).isEmpty)
    }

    func testPhaseValueInStepTypeIsNotTreatedAsAConflict() throws {
        XCTAssertTrue(try advisories("""
        {"id":"s","stepType":"intro","wallpaperCategories":[{"title":"c","images":[]}]}
        """).isEmpty, "moving a phase out of stepType is not an override")
    }

    // MARK: Alias fold

    func testGuidanceTitleFoldsIntoTitle() throws {
        let step = try canonicalize(#"{"id":"s","guidanceTitle":"Hello"}"#)
        XCTAssertEqual(step.title, "Hello")
    }

    func testAliasNeverOverwritesTheCanonicalField() throws {
        let step = try canonicalize(#"{"id":"s","title":"Canonical","guidanceTitle":"Alias"}"#)
        XCTAssertEqual(step.title, "Canonical")
    }

    func testAliasFoldIsLogged() throws {
        XCTAssertTrue(try advisories(#"{"id":"s","guidanceTitle":"Hello"}"#)
            .contains { $0.contains("guidanceTitle") })
    }

    // MARK: Determinism and count preservation

    private static let corpusShapes = [
        #"{"id":"a","stepType":"intro"}"#,
        #"{"id":"b","wallpaperCategories":[{"title":"c","images":[]}],"stepType":"intro"}"#,
        #"{"id":"c","optionCards":[{"id":"o","label":"O"}],"stepType":"options"}"#,
        #"{"id":"d","dockItems":[{"label":"A","path":"/A"}],"stepType":"dock"}"#,
        #"{"id":"e","stepType":"outro"}"#,
        #"{"id":"f"}"#
    ]

    func testCanonicalizationIsIdempotent() throws {
        // Resume decodes the same bytes again; a second pass does not drift.
        for json in Self.corpusShapes {
            var a1: [String] = [], a2: [String] = []
            let once = InspectConfig.canonicalizeStep(try decodeStep(json), advisories: &a1)
            let twice = InspectConfig.canonicalizeStep(once, advisories: &a2)
            XCTAssertEqual(once.stepType, twice.stepType, "stepType drifted on re-canonicalization of \(json)")
            XCTAssertEqual(once.phase, twice.phase, "phase drifted on re-canonicalization of \(json)")
            XCTAssertEqual(once.title, twice.title)
            XCTAssertTrue(a2.isEmpty, "a canonical step must not re-emit advisories: \(a2)")
        }
    }

    func testRepeatedDecodesProduceIdenticalResults() throws {
        for json in Self.corpusShapes {
            let first = try canonicalize(json)
            let second = try canonicalize(json)
            XCTAssertEqual(first.id, second.id)
            XCTAssertEqual(first.stepType, second.stepType)
            XCTAssertEqual(first.phase, second.phase)
        }
    }

    func testCanonicalizationPreservesCountAndOrder() throws {
        let steps = try Self.corpusShapes.map { try decodeStep($0) }
        let out = InspectConfig.canonicalizeSteps(steps)
        XCTAssertEqual(out?.count, steps.count, "canonicalization must never add or remove a step")
        XCTAssertEqual(out?.map(\.id), steps.map(\.id), "canonicalization must never reorder steps")
    }

    func testCanonicalizationPreservesIdentity() throws {
        // Index-keyed resume (P5 lastStepIndex) depends on this.
        let step = try canonicalize(#"{"id":"stable-id","wallpaperCategories":[{"title":"c","images":[]}]}"#)
        XCTAssertEqual(step.id, "stable-id")
    }

    func testNilStepsStayNil() {
        XCTAssertNil(InspectConfig.canonicalizeSteps(nil))
    }

    // MARK: step_add desugars like the file path

    /// An implicit-type `step_add:` payload canonicalizes exactly like the same step in the config file.
    func testStepAddEnvelopeCanonicalizesLikeTheFileDecoder() throws {
        let payload = """
        {"step":{"id":"ipc-implicit","title":"Added over IPC",        "optionCards":[{"id":"a","label":"Alpha"},{"id":"b","label":"Beta"}]},"at":3}
        """
        let envelope: StepAddEnvelope<InspectConfig.IntroStep> = try decodeStepEnvelope(payload)
        XCTAssertNil(envelope.step.stepType, "precondition: the wire payload carries no type")

        var advisories: [String] = []
        let canonical = InspectConfig.canonicalizeStep(envelope.step, advisories: &advisories)
        XCTAssertEqual(canonical.stepType, "options", "step_add must arrive explicit")
        XCTAssertEqual(canonical.id, "ipc-implicit")
        XCTAssertEqual(envelope.at, 3)
    }

    // MARK: Bookend projection

    private func decodeConfig(_ json: String) throws -> InspectConfig {
        try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
    }

    func testSummaryScreenIsSkippedWhenTheFlowAlreadyClosesWithAnOutro() throws {
        // An outro step plus a summaryScreen gives one closing screen, not two.
        let config = try decodeConfig("""
        { "preset": "5",
          "introSteps": [ {"id":"a"}, {"id":"finish","stepType":"outro"} ],
          "summaryScreen": { "title": "All done" } }
        """)
        XCTAssertEqual(config.stepsWithBookends?.map(\.id), ["a", "finish"],
                       "an authored outro must suppress the projected one")
    }

    func testIntroScreenIsSkippedWhenTheFlowAlreadyOpensWithAnIntro() throws {
        // The same at the other end.
        let config = try decodeConfig("""
        { "preset": "5",
          "introSteps": [ {"id":"welcome","stepType":"intro"}, {"id":"b"} ],
          "introScreen": { "title": "Welcome" } }
        """)
        XCTAssertEqual(config.stepsWithBookends?.map(\.id), ["welcome", "b"])
    }

    func testSkipLooksOnlyAtTheEdgeStepNotTheWholeFlow() throws {
        // A mid-flow intro step does not make the flow open with one.
        let config = try decodeConfig("""
        { "preset": "5",
          "introSteps": [ {"id":"a","stepType":"options","optionCards":[{"id":"o","label":"O"}]},
                          {"id":"mid","stepType":"intro"} ],
          "introScreen": { "title": "Welcome" } }
        """)
        XCTAssertEqual(config.stepsWithBookends?.map(\.id), ["_intro", "a", "mid"])
    }

    func testSummaryScreenProjectsToAReservedOutroStepAtTheEnd() throws {
        let config = try decodeConfig("""
        { "preset": "5",
          "introSteps": [ {"id":"a","stepType":"intro"}, {"id":"b"} ],
          "summaryScreen": { "title": "All done", "buttonText": "Close" } }
        """)
        let steps = config.stepsWithBookends ?? []
        XCTAssertEqual(steps.map(\.id), ["a", "b", "_outro"])
        XCTAssertEqual(steps.last?.phase, "outro")
        XCTAssertEqual(steps.last?.title, "All done")
        XCTAssertEqual(steps.last?.continueButtonText, "Close",
                       "the bookend's buttonText must land on the step's button field")
    }

    func testIntroScreenProjectsToAReservedIntroStepAtIndexZero() throws {
        let config = try decodeConfig("""
        { "preset": "5",
          "introSteps": [ {"id":"a"} ],
          "introScreen": { "title": "Welcome" } }
        """)
        let steps = config.stepsWithBookends ?? []
        XCTAssertEqual(steps.map(\.id), ["_intro", "a"])
        XCTAssertEqual(steps.first?.phase, "intro")
        XCTAssertEqual(steps.first?.title, "Welcome")
    }

    func testBothBookendsBracketTheAuthoredSteps() throws {
        let config = try decodeConfig("""
        { "preset": "5",
          "introSteps": [ {"id":"a"}, {"id":"b"} ],
          "introScreen": { "title": "Hi" }, "summaryScreen": { "title": "Bye" } }
        """)
        XCTAssertEqual(config.stepsWithBookends?.map(\.id), ["_intro", "a", "b", "_outro"])
    }

    func testProjectionIsAdditiveAndLeavesTheAuthoredKeysAlone() throws {
        let config = try decodeConfig("""
        { "preset": "5",
          "introSteps": [ {"id":"a"} ],
          "introScreen": { "title": "Welcome", "heroImage": "SF=star" },
          "summaryScreen": { "title": "Done", "subtitle": "Sub" } }
        """)
        // P4 and the P1-P3 phase screens read these field by field.
        XCTAssertEqual(config.introScreen?.title, "Welcome")
        XCTAssertEqual(config.introScreen?.heroImage, "SF=star")
        XCTAssertEqual(config.summaryScreen?.title, "Done")
        XCTAssertEqual(config.summaryScreen?.subtitle, "Sub")
        // introSteps stays as authored.
        XCTAssertEqual(config.introSteps?.map(\.id), ["a"])
    }

    func testProjectionWithNoBookendKeysIsAPassThrough() throws {
        let config = try decodeConfig(#"{ "preset": "5", "introSteps": [ {"id":"a"} ] }"#)
        XCTAssertEqual(config.stepsWithBookends?.map(\.id), ["a"])
    }

    func testProjectionIsIdempotent() throws {
        let config = try decodeConfig("""
        { "preset": "5", "introSteps": [ {"id":"a"} ],
          "introScreen": { "title": "Hi" }, "summaryScreen": { "title": "Bye" } }
        """)
        let once = config.stepsWithBookends ?? []
        let twice = InspectConfig.projectBookends(into: once,
                                                  introScreen: config.introScreen,
                                                  summaryScreen: config.summaryScreen) ?? []
        XCTAssertEqual(once.map(\.id), twice.map(\.id), "re-projecting must not duplicate a bookend")
    }

    func testProjectedBookendsAreCanonicalized() throws {
        // A dock-flavor outro carries dockFlavors, so its renderer comes out explicit.
        let config = try decodeConfig("""
        { "preset": "5", "introSteps": [ {"id":"a"} ],
          "summaryScreen": { "title": "Pick a dock", "layout": "dock",
            "dockFlavors": [ {"id":"f","name":"F","items":[]} ] } }
        """)
        let outro = config.stepsWithBookends?.last
        XCTAssertEqual(outro?.stepType, "dock", "projected steps go through canonicalizeStep")
        XCTAssertEqual(outro?.phase, "outro", "and keep their bookend phase")
    }

    func testAConfigClaimingAReservedIdIsRejectedLoudly() {
        XCTAssertThrowsError(try decodeConfig("""
        { "preset": "5", "introSteps": [ {"id":"_outro","stepType":"outro"} ],
          "summaryScreen": { "title": "Bye" } }
        """), "a reserved bookend id must be rejected at decode") { error in
            XCTAssertTrue("\(error)".contains("reserved"), "error should name the problem: \(error)")
        }
    }

    func testReservedIdRejectionAppliesToIntroToo() {
        XCTAssertThrowsError(try decodeConfig("""
        { "preset": "5", "introSteps": [ {"id":"_intro"} ], "introScreen": { "title": "Hi" } }
        """))
    }

    /// Without the matching screen nothing is projected, so the id is an ordinary step id, as in
    /// 3.1.1; only the end that has a screen is reserved.
    func testReservedIdsAreOrdinaryWithoutTheirScreen() throws {
        let config = try decodeConfig("""
        { "preset": "5", "introSteps": [ {"id":"_intro"}, {"id":"_outro"} ] }
        """)
        XCTAssertEqual(config.introSteps?.map(\.id), ["_intro", "_outro"])
        XCTAssertNoThrow(try decodeConfig("""
        { "preset": "5", "introSteps": [ {"id":"_outro"} ], "introScreen": { "title": "Hi" } }
        """), "an intro screen reserves `_intro` only")
    }

    // MARK: The renderer vocabulary is closed and matches the schema

    func testEveryRendererNameIsDeclaredInTheSchemaEnum() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let defs = root["definitions"] as! [String: Any]
        let step = defs["StepBase"] as? [String: Any] ?? defs["IntroStep"] as! [String: Any]
        var declared = Set<String>()
        if let props = step["properties"] as? [String: Any],
           let st = props["stepType"] as? [String: Any],
           let values = st["enum"] as? [String] {
            declared.formUnion(values)
        }
        for renderer in InspectConfig.stepRendererPriority.map(\.renderer) {
            XCTAssertTrue(declared.contains(renderer),
                          "renderer '\(renderer)' is written by canonicalization but missing from the schema enum")
        }
    }
}

// MARK: - Silent-default advisories

/// A default that decides an outcome says so; a default that cannot matter stays quiet.
final class SilentDefaultAdvisoryTests: XCTestCase {

    private func step(_ json: [String: Any]) throws -> InspectConfig.IntroStep {
        var full: [String: Any] = ["id": "s1"]
        full.merge(json) { _, new in new }
        let data = try JSONSerialization.data(withJSONObject: full)
        return try JSONDecoder().decode(InspectConfig.IntroStep.self, from: data)
    }

    /// Throws rather than `try!`, so a fixture that stops decoding fails its own test.
    private func advisories(_ json: [String: Any]) throws -> [String] {
        InspectConfig.silentDefaultAdvisories(for: try step(json))
    }

    // MARK: Derived operator

    func testAnExpectedValueWithNoOperatorNamesTheComparisonApplied() throws {
        let lines = try advisories(["expectedValue": "1"])
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].contains("equals"),
                      "the advisory has to NAME the operator, not just say one was chosen: \(lines)")
    }

    func testAnAuthoredOperatorProducesNoAdvisory() throws {
        XCTAssertTrue(try advisories(["expectedValue": "1", "evaluation": "boolean"]).isEmpty,
                      "nothing was derived, so there is nothing to report")
    }

    func testABareKeyWithNoExpectedValueProducesNoAdvisory() throws {
        XCTAssertTrue(try advisories([:]).isEmpty,
                      "'exists' on a bare requirement is the obvious reading, not a surprise")
    }

    // MARK: Verdict and destructive defaults, when relevant

    func testAProcessingStepIsToldItsUnreportedScriptCountsAsSuccess() throws {
        let lines = try advisories(["processingDuration": 3])
        XCTAssertTrue(lines.contains { $0.contains("autoResult") && $0.contains("success") }, "\(lines)")
        XCTAssertTrue(lines.contains { $0.contains("processingMode") }, "\(lines)")
    }

    func testANonProcessingStepIsNotToldAboutProcessingDefaults() throws {
        XCTAssertTrue(try advisories(["title": "Welcome"]).isEmpty,
                      "relevance gating is what keeps this log worth reading")
    }

    func testADockStepIsToldTheDockWillBeAppendedToRatherThanReplaced() throws {
        let lines = try advisories(["dockItems": [["label": "Safari", "path": "/Applications/Safari.app"]]])
        XCTAssertTrue(lines.contains { $0.contains("dockApplyMode") && $0.contains("additive") }, "\(lines)")
    }

    func testAnAuthoredDockApplyModeSilencesTheAdvisory() throws {
        let lines = try advisories(["dockItems": [["label": "Safari", "path": "/Applications/Safari.app"]],
                                    "dockApplyMode": "replace"])
        XCTAssertFalse(lines.contains { $0.contains("dockApplyMode") }, "\(lines)")
    }

    func testAGridStepIsToldSelectionDefaultsToSingle() throws {
        let lines = try advisories(["gridItems": [["title": "A"]]])
        XCTAssertTrue(lines.contains { $0.contains("gridSelectionMode") }, "\(lines)")
    }

    /// One completion trigger earns no completionMode advisory.
    func testOneCompletionTriggerDoesNotEarnACompletionModeAdvisory() throws {
        let one: [String: Any] = ["plistMonitors": [
            ["path": "/tmp/a.plist", "key": "k", "guidanceBlockIndex": 0, "targetProperty": "state", "recheckInterval": 5,
             "completionTrigger": ["condition": "exists", "result": "success"]]
        ]]
        XCTAssertFalse(try advisories(one).contains { $0.contains("completionMode") },
                       "with one trigger, any and all agree")
    }

    func testTwoCompletionTriggersEarnTheFirstOneWinsAdvisory() throws {
        let two: [String: Any] = ["plistMonitors": [
            ["path": "/tmp/a.plist", "key": "k", "guidanceBlockIndex": 0, "targetProperty": "state", "recheckInterval": 5,
             "completionTrigger": ["condition": "exists", "result": "success"]],
            ["path": "/tmp/b.plist", "key": "k", "guidanceBlockIndex": 1, "targetProperty": "state", "recheckInterval": 5,
             "completionTrigger": ["condition": "exists", "result": "success"]]
        ]]
        let lines = try advisories(two)
        XCTAssertTrue(lines.contains { $0.contains("completionMode") && $0.contains("FIRST") }, "\(lines)")
    }

    // MARK: Corpus noise

    /// The fixture configs decode with no advisory.
    func testTheFixtureConfigsProduceNoAdvisories() throws {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialogTests/Fixtures/inspect")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertFalse(files.isEmpty, "no example configs found at \(dir.path)")

        var noisy: [String] = []
        for file in files {
            let config = try JSONDecoder().decode(InspectConfig.self, from: Data(contentsOf: file))
            for step in config.introSteps ?? [] {
                for line in InspectConfig.silentDefaultAdvisories(for: step) {
                    noisy.append("\(file.lastPathComponent): \(line)")
                }
            }
        }
        XCTAssertEqual(noisy, [], "corpus advisories should be empty")
    }
}
