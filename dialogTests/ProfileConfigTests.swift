//
//  ProfileConfigTests.swift
//  dialogTests
//

import XCTest
@testable import Dialog

// MARK: - Look from a configuration profile
// Brand keys and setupExperience laid under the explicit config; inline base64 images become cached files.

final class ProfileConfigTests: XCTestCase {

    private var savedBase = ""
    private var savedCache = URL(fileURLWithPath: "/")
    private var scratch = URL(fileURLWithPath: "/")

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        savedBase = Config.managedPreferencesBase
        savedCache = Config.inlineImageCache
        Config.managedPreferencesBase = scratch.path
        Config.inlineImageCache = scratch.appendingPathComponent("images")
    }

    override func tearDown() {
        Config.managedPreferencesBase = savedBase
        Config.inlineImageCache = savedCache
    }

    private func png() -> Data {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus(); NSColor.red.setFill(); NSRect(x: 0, y: 0, width: 4, height: 4).fill(); image.unlockFocus()
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        return rep.representation(using: .png, properties: [:])!
    }

    /// The explicit config wins a top-level key whole; the profile fills the rest.
    func testTheFileIsLaidOverTheProfile() {
        let merged = Config.layered(profile: ["preset": "5", "title": "Profile", "logMonitor": ["preset": "munki"]],
                                    over: ["title": "File", "logMonitor": ["preset": "fleet"]])
        XCTAssertEqual(merged["preset"] as? String, "5")
        XCTAssertEqual(merged["title"] as? String, "File")
        XCTAssertEqual((merged["logMonitor"] as? [String: Any])?["preset"] as? String, "fleet")
    }

    /// Only a brand or setupExperience change is a new look; other rewrites of the domain file are not.
    func testOnlyALookChangeIsANewLook() throws {
        let file = scratch.appendingPathComponent("\(Config.managedConfigDomain).plist")
        func write(_ dict: [String: Any]) throws {
            try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: file)
        }
        XCTAssertNil(Config.profileLook())
        try write(["highlightColor": "#ff0000", "setupExperience": ["preset": "5"], "other": 1])
        let first = Config.profileLook()
        try write(["other": 2, "setupExperience": ["preset": "5"], "highlightColor": "#ff0000"])
        XCTAssertEqual(Config.profileLook(), first, "rewritten, same look")
        try write(["highlightColor": "#ff0000", "setupExperience": ["preset": "6"]])
        XCTAssertNotEqual(Config.profileLook(), first, "a new preset is a new look")
    }

    /// Profiles carry <data> and <date>; JSON has neither.
    func testPlistTypesBecomeJSONValues() {
        let out = Config.jsonCompatible(["logo": Data([1, 2, 3]), "when": Date(timeIntervalSince1970: 0),
                                         "nested": [["n": 1]]]) as? [String: Any]
        XCTAssertEqual(out?["logo"] as? String, "base64=AQID")
        XCTAssertEqual(out?["when"] as? String, "1970-01-01T00:00:00Z")
        XCTAssertNotNil(JSONSerialization.isValidJSONObject(out as Any) ? out : nil)
    }

    /// Both spellings become one cached file per image; what is not an image stays text.
    func testInlineImagesBecomeCachedFiles() throws {
        let b64 = png().base64EncodedString()
        let classic = try XCTUnwrap(Config.inlineImagePath("base64=" + b64))
        let dataURL = try XCTUnwrap(Config.inlineImagePath("data:image/png;base64," + b64))
        XCTAssertEqual(classic, dataURL, "same image, same file")
        XCTAssertNotNil(NSImage(contentsOfFile: classic))
        XCTAssertNil(Config.inlineImagePath("base64=" + Data("not an image".utf8).base64EncodedString()))
        XCTAssertNil(Config.inlineImagePath("SF=star.fill"))
    }

    /// The launch check that quits a config with no inspect content judges the effective config,
    /// profile included.
    func testGateAJudgesTheEffectiveConfig() throws {
        let run = Data(#"{"logMonitor": {"preset": "fleet", "path": "/opt/orbit/setup_experience_progress.json"}, "triggerFile": "/tmp/c"}"#.utf8)
        guard case .valid(let neutral) = validateInspectSchema(Config.effectiveData(run)) else {
            return XCTFail("no profile yet: the neutral look, not an exit")
        }
        XCTAssertEqual(neutral.preset, "5")
        XCTAssertEqual(neutral.introSteps?.first?.items?.count, 0, "rows come from Fleet")

        let profile: [String: Any] = ["setupExperience": ["preset": "1", "title": "From the profile",
                                                        "items": [["id": "a", "displayName": "A", "guiIndex": 0, "paths": []]]]]
        try PropertyListSerialization.data(fromPropertyList: profile, format: .binary, options: 0)
            .write(to: scratch.appendingPathComponent("\(Config.managedConfigDomain).plist"))
        guard case .valid(let fromProfile) = validateInspectSchema(Config.effectiveData(run)) else {
            return XCTFail("with the profile: its look")
        }
        XCTAssertEqual(fromProfile.preset, "1")

        try FileManager.default.removeItem(at: scratch.appendingPathComponent("\(Config.managedConfigDomain).plist"))
        guard case .notInspect = validateInspectSchema(Config.effectiveData(Data("{}".utf8))) else {
            return XCTFail("a bare {} that is not an orbit run still is not an inspect config")
        }
    }

    /// A config with its own look is never mixed with the profile.
    func testAConfigWithItsOwnLookIgnoresTheProfile() throws {
        let profile: [String: Any] = ["setupExperience": ["preset": "5", "introSteps": [["id": "s", "stepType": "installation", "items": [Any]()]]]]
        try PropertyListSerialization.data(fromPropertyList: profile, format: .binary, options: 0)
            .write(to: scratch.appendingPathComponent("\(Config.managedConfigDomain).plist"))
        let own = Data(#"{"preset": "1", "logMonitor": {"preset": "fleet", "path": "/tmp/x"}, "items": [{"id": "a", "displayName": "A", "guiIndex": 0, "paths": []}]}"#.utf8)
        guard case .success(let result) = Config().loadConfiguration(fromData: own) else { return XCTFail("its own look loads") }
        XCTAssertEqual(result.config.preset, "1")
        XCTAssertNil(result.config.introSteps)
        guard case .notInspect = validateInspectSchema(Config.effectiveData(Data(#"{"title": "Hi", "message": "a standard dialog"}"#.utf8))) else {
            return XCTFail("a standard dialog stays one")
        }
    }

    /// A profile layer whose values do not decode is left out and named; the dialog still runs.
    func testABadProfileLayerIsLeftOutNotTheDialog() throws {
        let run: [String: Any] = ["logMonitor": ["preset": "fleet", "path": "/tmp/x"]]
        func write(_ domain: [String: Any]) throws {
            try PropertyListSerialization.data(fromPropertyList: domain, format: .binary, options: 0)
                .write(to: scratch.appendingPathComponent("\(Config.managedConfigDomain).plist"))
        }
        let goodFlow: [String: Any] = ["preset": "5", "title": "Setup",
                                       "introSteps": [["id": "install", "stepType": "installation", "items": [Any]()]]]
        try write(["highlightColor": ["not": "a colour"], "setupExperience": goodFlow])
        var out = Config.effectiveObject(run)
        XCTAssertEqual(out.object["title"] as? String, "Setup", "the flow stays")
        XCTAssertNil(out.object["highlightColor"], "the bad brand goes")
        XCTAssertTrue(out.source.contains("left out, does not decode: the brand"), out.source)
        guard case .valid = validateInspectSchema(Config.effectiveData(try JSONSerialization.data(withJSONObject: run))) else {
            return XCTFail("Gate A passes on what is left")
        }
        try write(["highlightColor": "#FF0000", "setupExperience": ["preset": "5", "introSteps": "not steps"]])
        out = Config.effectiveObject(run)
        XCTAssertEqual(out.object["highlightColor"] as? String, "#FF0000", "the brand stays")
        XCTAssertEqual(out.object["title"] as? String, "Setting up your Mac", "the neutral look in the flow's place")
        XCTAssertTrue(out.source.contains("left out, does not decode: the profile's setupExperience"), out.source)
    }

    /// Each dialog watches the brand and its own flow: a first-login window sees firstLogin change,
    /// a self-contained dialog does not see setupExperience change.
    func testEachDialogWatchesItsOwnFlow() throws {
        func write(_ domain: [String: Any]) throws {
            try PropertyListSerialization.data(fromPropertyList: domain, format: .binary, options: 0)
                .write(to: scratch.appendingPathComponent("\(Config.managedConfigDomain).plist"))
        }
        XCTAssertEqual(Config.flowKey(of: ["profileLook": "firstLogin"]), "firstLogin")
        XCTAssertEqual(Config.flowKey(of: ["logMonitor": ["preset": "fleet"]]), "setupExperience")
        XCTAssertNil(Config.flowKey(of: ["preset": "5", "logMonitor": ["preset": "fleet"]]), "a look of its own")
        try write(["highlightColor": "#111111", "setupExperience": ["title": "A"], "firstLogin": ["title": "A"]])
        let first = Config.profileLook(flow: "firstLogin"), own = Config.profileLook(flow: nil)
        try write(["highlightColor": "#111111", "setupExperience": ["title": "B"], "firstLogin": ["title": "B"]])
        XCTAssertNotEqual(Config.profileLook(flow: "firstLogin"), first, "firstLogin changed")
        XCTAssertEqual(Config.profileLook(flow: nil), own, "only flows changed: not this dialog's look")
        try write(["highlightColor": "#222222", "setupExperience": ["title": "B"], "firstLogin": ["title": "B"]])
        XCTAssertNotEqual(Config.profileLook(flow: nil), own, "the brand is every dialog's")
    }

    /// A live reload keeps the session: enabled Continue, added rows, and adopted state survive.
    @MainActor func testAReloadKeepsTheSession() throws {
        let state = InspectState()
        state.buttonConfiguration.button1Disabled = false
        state.addedItemIDs = ["app-zoom"]
        let next = try JSONDecoder().decode(InspectConfig.self, from: Data(#"""
        {"preset": "3", "button1Disabled": true,
         "items": [{"id": "a", "displayName": "A", "guiIndex": 0, "paths": []}],
         "plistSources": [{"path": "/tmp/x.plist", "displayName": "X", "type": "custom"}]}
        """#.utf8))
        state.applyReloaded(next)
        XCTAssertFalse(state.buttonConfiguration.button1Disabled, "Continue stays enabled")
        XCTAssertTrue(state.addedItemIDs.isEmpty)
        XCTAssertEqual(state.items.map(\.id), ["a"])
        XCTAssertEqual(state.plistSources?.count, 1, "plist sources, set once at launch, adopted again")
    }

    /// The watch parses and reloads off main and hands only the finished config to main.
    func testTheProfileWatchReloadsOffTheMainThread() throws {
        let file = scratch.appendingPathComponent("\(Config.managedConfigDomain).plist")
        func write(_ title: String, at date: Date) throws {
            try PropertyListSerialization.data(fromPropertyList: ["setupExperience": ["preset": "5", "title": title]],
                                               format: .binary, options: 0).write(to: file)
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
        }
        try write("A", at: Date(timeIntervalSinceNow: -60))
        final class Box: @unchecked Sendable { var uptime: TimeInterval = 0; var loadedOnMain: Bool?; var applied: String? }
        let box = Box()
        let applied = expectation(description: "the reloaded look reaches the main thread")
        let run = Data(#"{"logMonitor": {"preset": "fleet", "path": "/tmp/none"}}"#.utf8)
        let watch = ProfileLookWatch(from: Config.profileLook(flow: "setupExperience"), flow: "setupExperience",
                                     uptime: { box.uptime },
                                     load: { box.loadedOnMain = Thread.isMainThread; return Config().loadConfiguration(fromData: run) },
                                     apply: { config in XCTAssertTrue(Thread.isMainThread); box.applied = config.title; applied.fulfill() })
        let queue = DispatchQueue(label: "test.watch") // as the watch's own timer runs it, on a worker thread
        func tick() { let done = DispatchSemaphore(value: 0); queue.async { watch.tick(); done.signal() }; done.wait() }
        try write("B", at: Date())
        tick()
        XCTAssertNil(box.loadedOnMain, "a new look, first read: holding")
        box.uptime = 3
        tick()
        // Generous: the hop to the main thread waits behind whatever else the test host is doing.
        wait(for: [applied], timeout: 10)
        XCTAssertEqual(box.loadedOnMain, false, "the reload ran off the main thread")
        XCTAssertEqual(box.applied, "B")
    }

    /// A look switches only once a change holds, so a transient removal or partial write does not reload mid-run.
    func testALookChangeCountsOnceItHolds() {
        let a = Data("a".utf8), b = Data("b".utf8), t0: TimeInterval = 1000
        var look = SettledLook(a)
        XCTAssertNil(look.observe(nil, at: t0), "removed for a moment")
        XCTAssertNil(look.observe(a, at: t0 + 2), "back: no change at all")
        XCTAssertFalse(look.isSettling)
        XCTAssertNil(look.observe(b, at: t0 + 4), "a new look, first read")
        XCTAssertNil(look.observe(nil, at: t0 + 5), "half-written in between: starts over")
        XCTAssertNil(look.observe(b, at: t0 + 6))
        XCTAssertEqual(look.observe(b, at: t0 + 8), .some(b), "held for 2 s: switch")
        XCTAssertEqual(look.current, b)
        XCTAssertNil(look.observe(nil, at: t0 + 10))
        XCTAssertNil(look.observe(nil, at: t0 + 16), "removed, not for 10 s yet")
        XCTAssertEqual(look.observe(nil, at: t0 + 20), .some(nil), "removed for good: neutral")
    }

    /// `{"profileLook": "firstLogin"}` runs that flow, not the setup experience beside it.
    func testProfileLookNamesTheFlow() throws {
        let domain: [String: Any] = ["setupExperience": ["preset": "5", "title": "Setup"],
                                     "firstLogin": ["preset": "6", "title": "Welcome"]]
        try PropertyListSerialization.data(fromPropertyList: domain, format: .binary, options: 0)
            .write(to: scratch.appendingPathComponent("\(Config.managedConfigDomain).plist"))
        let first = Config.effectiveObject(["profileLook": "firstLogin"]).object
        XCTAssertEqual(first["preset"] as? String, "6")
        XCTAssertEqual(first["title"] as? String, "Welcome")
        let setup = Config.effectiveObject(["logMonitor": ["preset": "fleet"]]).object
        XCTAssertEqual(setup["title"] as? String, "Setup")
    }

    /// The shipped profile sources lint clean, and the flow's Dock steps follow the team it asks for.
    @MainActor func testTheFleetProfileSourcesLintClean() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialogTests/Fixtures/inspect/fleet-setup")
        for name in ["fleet-setup-p5-lean.json", "fleet-first-login.json", "fleet-everyday-installs.json"] {
            let data = try Data(contentsOf: dir.appendingPathComponent(name))
            let errors = InspectLint.lint(data: data).filter { $0.severity == .error }
            XCTAssertEqual(errors.map(\.path), [], name)
        }
        let flow = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("fleet-first-login.json"))) as? [String: Any])
        let steps = try XCTUnwrap(flow["introSteps"] as? [[String: Any]])
        XCTAssertEqual(steps.first?["environmentKey"] as? String, "team")
        XCTAssertEqual(steps.compactMap { ($0["showWhen"] as? [String: Any])?["key"] as? String }, ["team", "team", "team"])
    }

    /// The brand styles every inspect dialog, only through brand keys; the dialog's own value wins and
    /// structural keys at the domain's top level are never taken.
    func testTheBrandStylesEveryDialogWithoutShapingIt() throws {
        let domain: [String: Any] = ["highlightColor": "#E20074", "icon": png(), "preset": "5", "items": [Any](),
                                     "buttonShape": "capsule"]
        try PropertyListSerialization.data(fromPropertyList: domain, format: .binary, options: 0)
            .write(to: scratch.appendingPathComponent("\(Config.managedConfigDomain).plist"))
        let own = Data(#"{"preset": "1", "buttonShape": "square", "items": [{"id": "a", "displayName": "A", "guiIndex": 0, "paths": []}]}"#.utf8)
        guard case .success(let result) = Config().loadConfiguration(fromData: own) else { return XCTFail("loads") }
        XCTAssertEqual(result.config.preset, "1", "structure is never the brand's")
        XCTAssertEqual(result.config.items.map(\.id), ["a"])
        XCTAssertEqual(result.config.highlightColor, "#E20074", "the brand's colour")
        XCTAssertEqual(result.config.buttonShape, "square", "the dialog's own value wins")
        XCTAssertTrue(result.config.icon?.hasPrefix(Config.inlineImageCache.path) == true, "the brand's <data> logo, cached")
        XCTAssertEqual(Config.effectiveObject(["title": "x"]).source, "the brand (buttonShape, highlightColor, icon) → the config")
    }

    /// End to end: a profile with the look (and a <data> logo) under a minimal file.
    func testAProfileSuppliesTheConfigUnderAMinimalFile() throws {
        let profile: [String: Any] = ["setupExperience": [
            "preset": "1", "title": "From the profile", "icon": png(),
            "items": [["id": "a", "displayName": "A", "guiIndex": 0, "paths": []]]
        ]]
        try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
            .write(to: scratch.appendingPathComponent("\(Config.managedConfigDomain).plist"))
        let file = #"{"title": "From the file", "triggerFile": "/tmp/orbit-command", "logMonitor": {"preset": "fleet", "path": "/tmp/none.json"}}"#
        guard case .success(let result) = Config().loadConfiguration(fromData: Data(file.utf8)) else {
            return XCTFail("a profile plus a minimal file is a whole config")
        }
        XCTAssertEqual(result.config.preset, "1")
        XCTAssertEqual(result.config.title, "From the file")
        XCTAssertEqual(result.config.items.map(\.id), ["a"])
        let icon = try XCTUnwrap(result.config.icon)
        XCTAssertTrue(icon.hasPrefix(Config.inlineImageCache.path), "the <data> logo is a cached file: \(icon)")
        XCTAssertNotNil(NSImage(contentsOfFile: icon))
    }
}
