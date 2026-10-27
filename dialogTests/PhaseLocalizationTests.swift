//
//  PhaseLocalizationTests.swift
//  dialogTests
//
//  Phase-screen sidecar localization: the localized key → config string → default chain
//  (localizedPhaseValue), and localization running before token resolution so sidecar strings
//  carry the same {userName} / {itemCount} / {managed:…} grammar as config strings.
//

import XCTest
@testable import Dialog

@MainActor
final class PhaseLocalizationTests: XCTestCase {

    var tempDir: URL!
    var service: LocalizationService!
    /// The same shape the presets pass into PhaseContainer.
    var localize: ((String) -> String?)!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("phase-loc-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        // Redirects the managed-preferences read so {managed:…} tokens resolve hermetically.
        CadenceMonitorService.managedPreferencesBase = tempDir.path

        let sidecar: [String: Any] = [
            "introScreen.title": "Willkommen, {userName}",
            "introScreen.buttonText": "Los geht's",
            "introScreen.steps.0": "Erster Schritt",
            "summaryScreen.title": "Fertig — {itemCount} Apps",
            "summaryScreen.footnote": "Verwaltet von {managed:test.absent.domain:Owner|deiner IT}",
            "uiLabels.skippedStatus": "Übersprungen"
        ]
        let data = try JSONSerialization.data(withJSONObject: sidecar)
        try data.write(to: tempDir.appendingPathComponent("de.json"))

        service = LocalizationService()
        let config = InspectConfig.LocalizationConfig(
            languages: ["de": "de.json"],
            selectionKey: nil,
            defaultLanguage: "de"
        )
        service.loadLanguages(from: config, iconBasePath: tempDir.path, configPath: nil)
        localize = { [service] key in service?.string(forLanguage: "de", key: key) }
    }

    override func tearDown() {
        CadenceMonitorService.managedPreferencesBase = "/Library/Managed Preferences"
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Sidecar fixture loading

    /// A relative sidecar resolves next to the config file when `iconBasePath` is unset; an empty base
    /// used to turn `de.json` into `/de.json`.
    func testRelativeSidecarResolvesAgainstTheConfigDirectory() {
        let loc = LocalizationService()
        loc.loadLanguages(from: .init(languages: ["de": "de.json"], selectionKey: nil, defaultLanguage: nil),
                          iconBasePath: nil, configPath: tempDir.appendingPathComponent("flow.json").path)
        XCTAssertTrue(loc.hasLanguage("de"))
        XCTAssertEqual(LocalizationService.sidecarBase(iconBasePath: "/icons", configPath: "/c/flow.json"), "/icons")
        XCTAssertEqual(LocalizationService.sidecarBase(iconBasePath: "", configPath: "/c/flow.json"), "/c")
    }

    /// A fixed `defaultLanguage` code finds a key spelled as a display name, as "auto" already did.
    func testFixedDefaultLanguageCodeMapsToADisplayNameKey() {
        let loc = LocalizationService()
        let config = InspectConfig.LocalizationConfig(languages: ["Deutsch": "de.json"], selectionKey: nil,
                                                      defaultLanguage: "de")
        loc.loadLanguages(from: config, iconBasePath: tempDir.path, configPath: nil)
        XCTAssertEqual(loc.resolveDefaultLanguage(from: config), "Deutsch")
    }

    func testSidecarFixtureLoads() {
        XCTAssertTrue(service.hasLanguage("de"))
        XCTAssertEqual(service.string(forLanguage: "de", key: "introScreen.buttonText"), "Los geht's")
        XCTAssertNil(service.string(forLanguage: "de", key: "introScreen.subtitle"))
    }

    // MARK: - Precedence chain (localizedPhaseValue)

    func testLocalizedKeyWinsOverConfigAndDefault() {
        let value = localizedPhaseValue("introScreen.buttonText", localize: localize,
                                        config: "Start setup", default: "Get Started")
        XCTAssertEqual(value, "Los geht's")
    }

    func testConfigStringFallsBackWhenKeyMissing() {
        let value = localizedPhaseValue("introScreen.subtitle", localize: localize,
                                        config: "A few apps install now", default: nil)
        XCTAssertEqual(value, "A few apps install now")
    }

    func testBuiltInDefaultFallsBackWhenKeyAndConfigMissing() {
        let value = localizedPhaseValue("summaryScreen.buttonText", localize: localize,
                                        config: nil, default: "Close")
        XCTAssertEqual(value, "Close")
    }

    func testNilLocalizerReducesToConfigChain() {
        XCTAssertEqual(localizedPhaseValue("introScreen.buttonText", localize: nil,
                                           config: "Start setup", default: "Get Started"),
                       "Start setup")
        XCTAssertEqual(localizedPhaseValue("introScreen.buttonText", localize: nil,
                                           config: nil, default: "Get Started"),
                       "Get Started")
        XCTAssertNil(localizedPhaseValue("introScreen.footnote", localize: nil,
                                         config: nil))
    }

    // MARK: - Pipeline order: localization before token resolution

    func testUserNameTokenResolvesInLocalizedString() {
        let text = resolveLocalizedPhaseText(key: "introScreen.title",
                                             config: "Welcome, {userName}",
                                             localize: localize,
                                             userName: "Maya", itemCount: 3)
        XCTAssertEqual(text, "Willkommen, Maya")
    }

    func testItemCountTokenResolvesInLocalizedString() {
        let text = resolveLocalizedPhaseText(key: "summaryScreen.title",
                                             config: "Done — {itemCount} apps",
                                             localize: localize,
                                             userName: nil, itemCount: 7)
        XCTAssertEqual(text, "Fertig — 7 Apps")
    }

    func testManagedTokenFallbackResolvesInLocalizedString() {
        // No plist exists under the redirected base, so the |fallback branch is used.
        let text = resolveLocalizedPhaseText(key: "summaryScreen.footnote",
                                             config: "Managed by {managed:test.absent.domain:Owner|your IT}",
                                             localize: localize,
                                             userName: nil, itemCount: 0)
        XCTAssertEqual(text, "Verwaltet von deiner IT")
    }

    func testTokensStillResolveOnConfigFallback() {
        let text = resolveLocalizedPhaseText(key: "introScreen.subtitle",
                                             config: "Hi {userName}, {itemCount} apps install now",
                                             localize: localize,
                                             userName: "Maya", itemCount: 2)
        XCTAssertEqual(text, "Hi Maya, 2 apps install now")
    }

    func testAbsentEverywhereReturnsNil() {
        XCTAssertNil(resolveLocalizedPhaseText(key: "introScreen.footnote",
                                               config: nil,
                                               localize: localize,
                                               userName: nil, itemCount: 0))
    }

    // MARK: - Indexed array keys

    func testIndexedStepKeyResolvesPerIndex() {
        XCTAssertEqual(localizedPhaseValue("introScreen.steps.0", localize: localize,
                                           config: "First step"),
                       "Erster Schritt")
        XCTAssertEqual(localizedPhaseValue("introScreen.steps.1", localize: localize,
                                           config: "Second step"),
                       "Second step")
    }

    // MARK: - Shared uiLabels namespace

    func testUILabelsKeyResolves() {
        XCTAssertEqual(localizedPhaseValue("uiLabels.skippedStatus", localize: localize,
                                           config: nil, default: "Skipped"),
                       "Übersprungen")
    }

    // MARK: - uiString

    func testUIStringFallsBackWhenLanguageMissing() {
        let svc = LocalizationService()
        XCTAssertEqual(svc.uiString("ui.helpTitle", language: nil, fallback: "Help"), "Help")
        XCTAssertEqual(svc.uiString("ui.helpTitle", language: "de", fallback: "Help"), "Help")
    }

    // MARK: - Content blocks

    /// `localizedBlock` swaps only the keys the pack has for that block index.
    func testALocalizedBlockTakesOnlyTheKeysThePackHas() throws {
        let sidecar: [String: Any] = [
            "welcome.content.0.content": "Hallo",
            "welcome.content.0.items": ["eins", "zwei"],
            "welcome.content.0.checklist.1": "Zweiter Punkt"
        ]
        try JSONSerialization.data(withJSONObject: sidecar).write(to: tempDir.appendingPathComponent("blocks.json"))
        let loc = LocalizationService()
        loc.loadLanguages(from: .init(languages: ["de": "blocks.json"], selectionKey: nil, defaultLanguage: "de"),
                          iconBasePath: tempDir.path, configPath: nil)

        let block = try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data("""
            {"type": "bullets", "content": "Hello", "caption": "Kept", "items": ["one", "two"],
             "checklist": [{"text": "First"}, {"text": "Second"}]}
            """.utf8))
        let out = loc.localizedBlock(block, language: "de", prefix: "welcome.content.0")

        XCTAssertEqual(out.content, "Hallo")
        XCTAssertEqual(out.items, ["eins", "zwei"])
        XCTAssertEqual(out.caption, "Kept", "a key the pack lacks keeps the block's own value")
        XCTAssertEqual(out.checklist?.map(\.text), ["First", "Zweiter Punkt"])
        XCTAssertEqual(loc.localizedBlock(block, language: "de", prefix: "other.content.0").content, "Hello",
                       "another block's keys never leak in")
    }
}
