# Inspect Unified Config Intake + Strict Schema Validation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let inspect mode accept its config JSON from any source (`--jsonstring`, `--jsonfile`, `--inspect-config`, `DIALOG_INSPECT_CONFIG`, standard location), validate it strictly against the inspect schema, and fail with a precise error when it doesn't conform.

**Architecture:** A pure resolver picks the highest-priority source and returns raw `Data` + an origin label. A pure strict validator (two gates: raw-key marker + successful decode) accepts or rejects that data. A new `loadConfiguration(fromData:)` funnels both file and inline-string input through one decode surface. Inspect-mode glue in `ProcessCLOptions` validates up front (before any window) and stores the resolved `Data` for `InspectState`.

**Tech Stack:** Swift 6, Foundation (`JSONSerialization`, `JSONDecoder`), XCTest (`dialogTests` target), Xcode `xcodebuild`.

## Global Constraints

- Swift 6; macOS; target minimum unchanged.
- **Xcode target membership:** do NOT create new `.swift` files unless you also add them to the correct Xcode target — a new file not in compile sources fails the build. This plan adds production code inside existing compiled files (`Config.swift`, `AppVariables.swift`, `ProcessCLOptions.swift`, `InspectState.swift`, `HelpText.swift`) and tests inside the existing `dialogTests/dialogTests.swift`.
- Build command: `xcodebuild -project dialog.xcodeproj -scheme "Dialog App Bundle" -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- Test command (signing MUST be disabled or `xcodebuild test` fails with a Developer ID error): `xcodebuild test -project dialog.xcodeproj -scheme "Dialog App Bundle" -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -only-testing:dialogTests/<Class>` (tests use `@testable import Dialog`, matching `dialogTests/PlistEvaluationTests.swift`). Note: `LogMonitorServiceTests` has 6 pre-existing unrelated failures — ignore them; only assert on the classes this plan adds.
- Git: commit after each task. No `--push`. No Claude co-author line.
- Do NOT change the standard (non-inspect) `--jsonfile`/`--jsonstring` behavior. Do NOT auto-detect inspect vs standard without `--inspect-mode` (explicitly out of scope).
- Inspect marker keys (canonical set, used verbatim): `inspectMode`, `preset`, `introSteps`, `items`.

---

### Task 1: Strict schema validator

**Files:**
- Modify: `dialog/Views/Inspect/Services/Config.swift` (add at file scope, directly after `enum InspectConfigCoercion { … }` near line 1524)
- Test: `dialogTests/dialogTests.swift` (append a new `final class InspectSchemaValidationTests: XCTestCase`)

**Interfaces:**
- Produces:
  - `enum InspectSchemaValidation { case valid(InspectConfig); case notInspect; case malformed(reason: String) }`
  - `func validateInspectSchema(_ data: Data) -> InspectSchemaValidation`
- Consumes: `InspectConfig` (Codable, `InspectConfig.swift`), `InspectConfigCoercion.coerceScalars(in:)` (existing, `Config.swift`).

**Behavior:**
- **Gate A (intent marker):** parse `data` with `JSONSerialization`. If not a `[String: Any]` object → `.malformed(reason: "top-level JSON is not an object")`. A marker is present when ANY of: `inspectMode == true`; `preset` is a non-empty `String`; `introSteps` is a non-empty array; `items` is a non-empty array. No marker → `.notInspect`.
- **Gate B (decode):** apply `InspectConfigCoercion.coerceScalars(in:)` to the object, re-serialize, `JSONDecoder().decode(InspectConfig.self, …)`. On success → `.valid(config)`. On `DecodingError` → `.malformed(reason: <human string>)`.

- [ ] **Step 1: Write the failing tests**

Append to `dialogTests/dialogTests.swift`:

```swift
final class InspectSchemaValidationTests: XCTestCase {
    private func data(_ s: String) -> Data { Data(s.utf8) }

    func testStandardDialogJSONIsNotInspect() {
        let r = validateInspectSchema(data(#"{"title":"Hi","message":"yo"}"#))
        if case .notInspect = r {} else { XCTFail("expected .notInspect, got \(r)") }
    }

    func testItemsOnlyConfigIsValid() {
        let r = validateInspectSchema(data(#"{"items":[{"id":"a","displayName":"A","guiIndex":0}]}"#))
        if case .valid = r {} else { XCTFail("expected .valid, got \(r)") }
    }

    func testEmptyObjectIsNotInspect() {
        let r = validateInspectSchema(data("{}"))
        if case .notInspect = r {} else { XCTFail("expected .notInspect, got \(r)") }
    }

    func testEmptyItemsArrayIsNotInspect() {
        // markers must be NON-empty to count as intent
        let r = validateInspectSchema(data(#"{"items":[]}"#))
        if case .notInspect = r {} else { XCTFail("expected .notInspect, got \(r)") }
    }

    func testMarkerPresentButMalformedDecode() {
        // preset present (marker) but items has wrong type -> malformed, not notInspect
        let r = validateInspectSchema(data(#"{"preset":"1","items":"not-an-array"}"#))
        if case .malformed = r {} else { XCTFail("expected .malformed, got \(r)") }
    }

    func testQuotedScalarsCoerceAndValidate() {
        // guiIndex given as quoted string must coerce and still validate
        let r = validateInspectSchema(data(#"{"preset":"1","items":[{"id":"a","displayName":"A","guiIndex":"2"}]}"#))
        if case .valid = r {} else { XCTFail("expected .valid, got \(r)") }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project dialog.xcodeproj -scheme "Dialog App Bundle" -destination 'platform=macOS' -only-testing:dialogTests/InspectSchemaValidationTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'validateInspectSchema' in scope`.

- [ ] **Step 3: Implement the validator**

Add to `Config.swift` at file scope, immediately after the closing brace of `enum InspectConfigCoercion`:

```swift
/// Result of validating raw JSON against the inspect-mode schema.
enum InspectSchemaValidation {
    case valid(InspectConfig)
    case notInspect
    case malformed(reason: String)
}

/// Strict two-gate check that `data` is an intended, well-formed inspect config.
/// Gate A: the raw object must carry an inspect *intent* marker (non-empty
/// `inspectMode`/`preset`/`introSteps`/`items`) — decoding alone is too lenient.
/// Gate B: it must decode into `InspectConfig` (after scalar coercion).
func validateInspectSchema(_ data: Data) -> InspectSchemaValidation {
    guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
        return .malformed(reason: "top-level JSON is not an object")
    }

    // Gate A — intent marker
    var hasMarker = false
    if let b = obj["inspectMode"] as? Bool, b { hasMarker = true }
    if let s = obj["preset"] as? String, !s.isEmpty { hasMarker = true }
    if let a = obj["introSteps"] as? [Any], !a.isEmpty { hasMarker = true }
    if let a = obj["items"] as? [Any], !a.isEmpty { hasMarker = true }
    guard hasMarker else { return .notInspect }

    // Gate B — decode (reuse the same scalar coercion the loaders apply)
    let coerced = (InspectConfigCoercion.coerceScalars(in: obj) as? [String: Any]) ?? obj
    guard let coercedData = try? JSONSerialization.data(withJSONObject: coerced) else {
        return .malformed(reason: "could not re-serialize coerced JSON")
    }
    do {
        let config = try JSONDecoder().decode(InspectConfig.self, from: coercedData)
        return .valid(config)
    } catch {
        return .malformed(reason: String(describing: error))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project dialog.xcodeproj -scheme "Dialog App Bundle" -destination 'platform=macOS' -only-testing:dialogTests/InspectSchemaValidationTests 2>&1 | tail -20`
Expected: PASS (6 tests). If `testItemsOnlyConfigIsValid`/`testQuotedScalarsCoerceAndValidate` fail on a required non-optional field, inspect the decode error in the message and confirm the fixture includes every non-defaulted `ItemConfig`/`InspectConfig` field; adjust the fixture (not the validator) to the minimal valid shape.

- [ ] **Step 5: Commit**

```bash
git add "dialog/Views/Inspect/Services/Config.swift" dialogTests/dialogTests.swift
git commit -m "feat(inspect): strict schema validator (validateInspectSchema)"
```

---

### Task 2: `loadConfiguration(fromData:)`

**Files:**
- Modify: `dialog/Views/Inspect/Services/Config.swift` (`class Config`, near `loadConfigurationFromFile(at:)` line 450)
- Test: `dialogTests/dialogTests.swift` (append to a `final class ConfigLoadFromDataTests: XCTestCase`)

**Interfaces:**
- Consumes: `validateInspectSchema(_:)` (Task 1), `ConfigurationResult`/`ConfigurationError` (existing, `Config.swift:23` / error type).
- Produces: `func loadConfiguration(fromData data: Data) -> Result<ConfigurationResult, ConfigurationError>` on `Config`.

**Behavior:** Runs `validateInspectSchema`. `.valid(config)` → `.success(ConfigurationResult(...))` built the same way `loadConfigurationFromFile` builds it (same warnings/source semantics). `.notInspect` / `.malformed` → `.failure(...)` with a descriptive `ConfigurationError`. Refactor `loadConfigurationFromFile(at:)` to read the file into `Data` and delegate to `loadConfiguration(fromData:)` so there is one decode surface.

- [ ] **Step 1: Write the failing test**

First inspect the existing `ConfigurationResult` initializer and `ConfigurationError` cases:

Run: `grep -n "struct ConfigurationResult\|enum ConfigurationError\|case \|init(" "dialog/Views/Inspect/Services/Config.swift" | sed -n '1,40p'`

Then append (adjust the `ConfigurationError` case name to the real one surfaced by the grep — e.g. `.invalidFormat`/`.decodingFailed`):

```swift
final class ConfigLoadFromDataTests: XCTestCase {
    func testValidInspectDataLoads() {
        let data = Data(#"{"preset":"1","items":[{"id":"a","displayName":"A","guiIndex":0}]}"#.utf8)
        let result = Config().loadConfiguration(fromData: data)
        switch result {
        case .success(let r): XCTAssertEqual(r.config.items.count, 1)
        case .failure(let e): XCTFail("expected success, got \(e)")
        }
    }

    func testStandardDataFails() {
        let data = Data(#"{"title":"Hi"}"#.utf8)
        if case .failure = Config().loadConfiguration(fromData: data) {} else {
            XCTFail("expected failure for non-inspect JSON")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project dialog.xcodeproj -scheme "Dialog App Bundle" -destination 'platform=macOS' -only-testing:dialogTests/ConfigLoadFromDataTests 2>&1 | tail -20`
Expected: FAIL — `value of type 'Config' has no member 'loadConfiguration(fromData:)'`.

- [ ] **Step 3: Implement `loadConfiguration(fromData:)` and delegate the file loader to it**

In `class Config`, add:

```swift
/// Decode + validate inspect config from in-memory JSON. Single decode surface
/// shared by the file loader and inline `--jsonstring`.
func loadConfiguration(fromData data: Data) -> Result<ConfigurationResult, ConfigurationError> {
    switch validateInspectSchema(data) {
    case .valid(let config):
        return .success(ConfigurationResult(config: config, warnings: [], source: .file("<data>")))
    case .notInspect:
        return .failure(.invalidFormat("No inspect content found (expected preset, introSteps, or items). If you meant a standard dialog, drop --inspect-mode."))
    case .malformed(let reason):
        return .failure(.invalidFormat("Inspect config is malformed: \(reason)"))
    }
}
```

Then change `loadConfigurationFromFile(at:)` to read `Data` and delegate:

```swift
// inside loadConfigurationFromFile(at path: String):
guard let data = FileManager.default.contents(atPath: path) else {
    return .failure(.fileNotFound(path))
}
return loadConfiguration(fromData: data)
```

Match `ConfigurationResult(...)`, `.file(...)`, `.invalidFormat`, and `.fileNotFound` to the exact initializer/case names from the Step-1 grep. If the file loader currently emits richer warnings, preserve that by passing them through a `warnings` parameter added to `loadConfiguration(fromData:)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project dialog.xcodeproj -scheme "Dialog App Bundle" -destination 'platform=macOS' -only-testing:dialogTests/ConfigLoadFromDataTests 2>&1 | tail -20`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add "dialog/Views/Inspect/Services/Config.swift" dialogTests/dialogTests.swift
git commit -m "feat(inspect): loadConfiguration(fromData:) single decode surface"
```

---

### Task 3: Pure config-source resolver + `appvars.inspectConfigData`

**Files:**
- Modify: `dialog/App Processing/AppVariables.swift` (near `inspectConfigPath` line 190)
- Modify: `dialog/Command Line/ProcessCLOptions.swift` (add resolver at file scope, above `getJSON()`)
- Test: `dialogTests/dialogTests.swift` (append `final class InspectSourceResolverTests: XCTestCase`)

**Interfaces:**
- Produces:
  - `struct ResolvedInspectSource { let data: Data; let origin: String; let path: String? }`
  - `func resolveInspectConfigSource(jsonString: String?, jsonFilePath: String?, inspectConfigPath: String?, envPath: String?, standardLocationPath: String?, readFile: (String) -> Data?) -> ResolvedInspectSource?`  — **pure** (all inputs injected, no globals), returns `nil` when nothing resolves.
  - `var inspectConfigData: Data?` on `appvars`.
- Consumes: nothing from other tasks.

**Behavior:** Priority: `jsonString` (inline → `Data`, origin `"--jsonstring"`, path `nil`) > `jsonFilePath` > `inspectConfigPath` > `envPath` > `standardLocationPath`. For path sources, `readFile(path)` supplies the bytes; a path that yields `nil` bytes is skipped (fall through to the next source). `origin` is a human label; `path` is set for file-based sources (for logging / `appvars.inspectConfigPath`).

- [ ] **Step 1: Write the failing tests**

```swift
final class InspectSourceResolverTests: XCTestCase {
    private let fakeRead: (String) -> Data? = { p in Data("FILE:\(p)".utf8) }

    func testJsonStringWins() {
        let r = resolveInspectConfigSource(jsonString: "{}", jsonFilePath: "/a.json",
            inspectConfigPath: nil, envPath: nil, standardLocationPath: nil, readFile: fakeRead)
        XCTAssertEqual(r?.origin, "--jsonstring")
        XCTAssertEqual(r?.data, Data("{}".utf8))
        XCTAssertNil(r?.path)
    }

    func testJsonFileBeatsEnvAndStandard() {
        let r = resolveInspectConfigSource(jsonString: nil, jsonFilePath: "/a.json",
            inspectConfigPath: nil, envPath: "/env.json", standardLocationPath: "/std.json", readFile: fakeRead)
        XCTAssertEqual(r?.path, "/a.json")
        XCTAssertEqual(r?.data, Data("FILE:/a.json".utf8))
    }

    func testEnvBeatsStandard() {
        let r = resolveInspectConfigSource(jsonString: nil, jsonFilePath: nil,
            inspectConfigPath: nil, envPath: "/env.json", standardLocationPath: "/std.json", readFile: fakeRead)
        XCTAssertEqual(r?.path, "/env.json")
    }

    func testNoSourceReturnsNil() {
        let r = resolveInspectConfigSource(jsonString: nil, jsonFilePath: nil,
            inspectConfigPath: nil, envPath: nil, standardLocationPath: nil, readFile: fakeRead)
        XCTAssertNil(r)
    }

    func testUnreadableFileFallsThrough() {
        let r = resolveInspectConfigSource(jsonString: nil, jsonFilePath: "/missing.json",
            inspectConfigPath: nil, envPath: "/env.json", standardLocationPath: nil,
            readFile: { $0 == "/env.json" ? Data("ok".utf8) : nil })
        XCTAssertEqual(r?.path, "/env.json")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project dialog.xcodeproj -scheme "Dialog App Bundle" -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -only-testing:dialogTests/InspectSourceResolverTests -only-testing:dialogTests/InspectIntakePipelineTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'resolveInspectConfigSource' in scope`.

- [ ] **Step 3: Implement the resolver and the appvars field**

In `AppVariables.swift`, after `var inspectConfigPath = String("")`:

```swift
var inspectConfigData: Data?   // resolved inspect config bytes (any source)
```

In `ProcessCLOptions.swift`, at file scope above `getJSON()`:

```swift
struct ResolvedInspectSource {
    let data: Data
    let origin: String
    let path: String?
}

/// Pure resolver: pick the highest-priority inspect config source and return its bytes.
/// Explicit flags beat ambient env/standard-location. Unreadable path sources fall through.
func resolveInspectConfigSource(
    jsonString: String?,
    jsonFilePath: String?,
    inspectConfigPath: String?,
    envPath: String?,
    standardLocationPath: String?,
    readFile: (String) -> Data?
) -> ResolvedInspectSource? {
    if let s = jsonString, !s.isEmpty {
        return ResolvedInspectSource(data: Data(s.utf8), origin: "--jsonstring", path: nil)
    }
    let fileSources: [(label: String, path: String?)] = [
        ("--jsonfile", jsonFilePath),
        ("--inspect-config", inspectConfigPath),
        ("DIALOG_INSPECT_CONFIG", envPath),
        ("standard location", standardLocationPath),
    ]
    for src in fileSources {
        guard let p = src.path, !p.isEmpty, let data = readFile(p) else { continue }
        return ResolvedInspectSource(data: data, origin: "\(src.label) \(p)", path: p)
    }
    return nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project dialog.xcodeproj -scheme "Dialog App Bundle" -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -only-testing:dialogTests/InspectSourceResolverTests 2>&1 | tail -20`
Expected: PASS (5 tests).

- [ ] **Step 5: Full-pipeline integration test (source → validate → load)**

This is the end-to-end proof that inspect config from a file source AND an inline string both resolve, validate, and load into a usable `InspectConfig` — the closest we get to "launch works" without a GUI. Append to `dialogTests/dialogTests.swift`:

```swift
final class InspectIntakePipelineTests: XCTestCase {
    private let inspectJSON = #"{"preset":"1","items":[{"id":"a","displayName":"A","guiIndex":0},{"id":"b","displayName":"B","guiIndex":1}]}"#

    func testJsonStringPipelineProducesValidConfig() {
        let src = resolveInspectConfigSource(jsonString: inspectJSON, jsonFilePath: nil,
            inspectConfigPath: nil, envPath: nil, standardLocationPath: nil, readFile: { _ in nil })
        XCTAssertNotNil(src)
        guard case .valid = validateInspectSchema(src!.data) else { return XCTFail("string source failed validation") }
        switch Config().loadConfiguration(fromData: src!.data) {
        case .success(let r): XCTAssertEqual(r.config.items.count, 2)
        case .failure(let e): XCTFail("string pipeline load failed: \(e)")
        }
    }

    func testJsonFilePipelineMatchesString() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("intake-\(UUID().uuidString).json")
        try Data(inspectJSON.utf8).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let src = resolveInspectConfigSource(jsonString: nil, jsonFilePath: tmp.path,
            inspectConfigPath: nil, envPath: nil, standardLocationPath: nil,
            readFile: { FileManager.default.contents(atPath: $0) })
        XCTAssertEqual(src?.path, tmp.path)
        switch Config().loadConfiguration(fromData: src!.data) {
        case .success(let r): XCTAssertEqual(r.config.items.count, 2)
        case .failure(let e): XCTFail("file pipeline load failed: \(e)")
        }
    }

    func testStandardJSONViaPipelineIsRejected() {
        let src = resolveInspectConfigSource(jsonString: #"{"title":"Hi"}"#, jsonFilePath: nil,
            inspectConfigPath: nil, envPath: nil, standardLocationPath: nil, readFile: { _ in nil })
        if case .failure = Config().loadConfiguration(fromData: src!.data) {} else {
            XCTFail("standard JSON should be rejected by the pipeline")
        }
    }
}
```

Run: `xcodebuild test -project dialog.xcodeproj -scheme "Dialog App Bundle" -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -only-testing:dialogTests/InspectIntakePipelineTests 2>&1 | tail -20`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add "dialog/App Processing/AppVariables.swift" "dialog/Command Line/ProcessCLOptions.swift" dialogTests/dialogTests.swift
git commit -m "feat(inspect): config-source resolver + inspectConfigData + intake pipeline tests"
```

---

### Task 4: Wire resolver + validation into the inspect-mode entry path

**Files:**
- Modify: `dialog/Command Line/ProcessCLOptions.swift` — remove the reject guard in `getJSON()` (≈ lines 47–65); replace the inspect-mode config-path block (≈ lines 167–200) to use `resolveInspectConfigSource` + `validateInspectSchema`; add `--inspect-config` deprecation log.
- (No new unit test — this is app-entry glue; covered by manual integration below.)

**Interfaces:**
- Consumes: `resolveInspectConfigSource(...)` (Task 3), `validateInspectSchema(_:)` (Task 1), `appvars.inspectConfigData`/`appvars.inspectConfigPath`, existing `MinimalInspectConfig` sizing decode.

- [ ] **Step 1: Remove the reject guard in `getJSON()`**

Delete the entire `if CLOptionPresent(optionName: appArguments.inspectMode) && (…jsonFile… || …jsonString…) { … quitDialog … }` block (≈ lines 47–65). The standard `--jsonfile`/`--jsonstring` handlers below it stay unchanged and only run when `--inspect-mode` is absent (guaranteed by the inspect-mode branch handling the config itself in Step 2 and the app not reaching standard rendering in inspect mode).

- [ ] **Step 2: Replace the inspect-mode config resolution block**

In the inspect-mode activation block, replace the Priority 1/2/3 `configPath` logic (≈ 167–200) with:

```swift
let stdLocation = "/var/tmp/dialog-inspect-config.json"
if appArguments.inspectConfig.present {
    writeLog("Inspect Mode: --inspect-config is deprecated; use --jsonfile.", logLevel: .info)
}
let resolved = resolveInspectConfigSource(
    jsonString: appArguments.jsonString.present ? CLOptionText(optionName: appArguments.jsonString) : nil,
    jsonFilePath: appArguments.jsonFile.present ? CLOptionText(optionName: appArguments.jsonFile) : nil,
    inspectConfigPath: appArguments.inspectConfig.present ? CLOptionText(optionName: appArguments.inspectConfig) : nil,
    envPath: ProcessInfo.processInfo.environment["DIALOG_INSPECT_CONFIG"],
    standardLocationPath: FileManager.default.fileExists(atPath: stdLocation) ? stdLocation : nil,
    readFile: { FileManager.default.contents(atPath: $0) }
)

guard let source = resolved else {
    let msg = """
    Error: --inspect-mode requires a config. Provide one via:
      dialog --inspect-mode --jsonfile /abs/path/config.json
      dialog --inspect-mode --jsonstring '{...}'
      DIALOG_INSPECT_CONFIG=/abs/path/config.json dialog --inspect-mode

    """
    FileHandle.standardError.write(Data(msg.utf8))
    writeLog("Inspect Mode: no config source resolved", logLevel: .error)
    quitDialog(exitCode: appDefaults.exit1.code)
    return json  // unreachable; satisfies control flow
}

switch validateInspectSchema(source.data) {
case .notInspect:
    let msg = "Error: \(source.origin) is not an inspect config (expected preset, introSteps, or items). If you meant a standard dialog, drop --inspect-mode.\n"
    FileHandle.standardError.write(Data(msg.utf8))
    writeLog("Inspect Mode: source \(source.origin) failed Gate A (notInspect)", logLevel: .error)
    quitDialog(exitCode: appDefaults.exit1.code)
case .malformed(let reason):
    let msg = "Error: inspect config from \(source.origin) is malformed: \(reason)\n"
    FileHandle.standardError.write(Data(msg.utf8))
    writeLog("Inspect Mode: source \(source.origin) malformed: \(reason)", logLevel: .error)
    quitDialog(exitCode: appDefaults.exit1.code)
case .valid(let config):
    appvars.inspectConfigData = source.data
    if let p = source.path { appvars.inspectConfigPath = p }
    writeLog("Inspect Mode: config accepted from \(source.origin)", logLevel: .info)
    // Window sizing from the already-resolved config (no extra file read).
    applyInspectWindowSizing(preset: config.preset)   // see note below
}
```

If the existing sizing code used a local `MinimalInspectConfig` decode of the file, replace that with direct use of `config.preset` (and any other dims it read) from the `.valid(config)` above. If sizing logic is substantial, keep it inline in the `.valid` case rather than introducing `applyInspectWindowSizing` — match the current structure; the point is to feed it `config`/`source.data` instead of re-reading the file.

- [ ] **Step 3: Build**

Run: `xcodebuild -project dialog.xcodeproj -scheme "Dialog App Bundle" -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual integration check (real window)**

Using the fresh Debug binary at `~/Library/Developer/Xcode/DerivedData/dialog-*/Build/Products/Debug/Dialog.app`:
- `open -na <Dialog.app> --args --inspect-mode --jsonfile /abs/p1test.json` → renders the list preset.
- `open -na <Dialog.app> --args --inspect-mode --jsonstring "$(cat /abs/p1test.json)"` → renders identically.
- `open -na <Dialog.app> --args --inspect-mode --jsonfile /abs/standard-dialog.json` (a `{"title":…}` file) → no window; exits non-zero; stderr shows the "not an inspect config" error.
- `DIALOG_INSPECT_CONFIG=/abs/p1test.json open -na <Dialog.app> --args --inspect-mode` → renders (env path still works).

(If the sandbox can't display a window, at minimum confirm the two error cases exit non-zero with the expected stderr via a direct binary run capturing stderr.)

- [ ] **Step 5: Commit**

```bash
git add "dialog/Command Line/ProcessCLOptions.swift"
git commit -m "feat(inspect): unified config intake via resolver + strict validation"
```

---

### Task 5: `InspectState` consumes resolved data

**Files:**
- Modify: `dialog/Views/Inspect/Core Framework/InspectState.swift` (`loadConfiguration`, line ~232)

**Interfaces:**
- Consumes: `appvars.inspectConfigData` (Task 3), `Config.loadConfiguration(fromData:)` (Task 2), existing `loadConfiguration(fromFile:)` (fallback).

- [ ] **Step 1: Use `fromData` when available, else fall back to `fromFile`**

Replace the loader call at ~232:

```swift
let result: Result<ConfigurationResult, ConfigurationError>
if let data = appvars.inspectConfigData {
    result = configurationService.loadConfiguration(fromData: data)
} else {
    result = configurationService.loadConfiguration(fromFile: appvars.inspectConfigPath)
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project dialog.xcodeproj -scheme "Dialog App Bundle" -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual check** — re-run the `--jsonstring` launch from Task 4 Step 4 and confirm the window renders from in-memory data (no file on disk for the inline case).

- [ ] **Step 4: Commit**

```bash
git add "dialog/Views/Inspect/Core Framework/InspectState.swift"
git commit -m "feat(inspect): InspectState loads from resolved data when present"
```

---

### Task 6: Fix help text + documentation

**Files:**
- Modify: `dialog/Command Line/HelpText.swift` (inspect-mode section, ≈ lines 1480–1505)

**Interfaces:** none (docs only).

- [ ] **Step 1: Update the inspect help copy**

- Change the examples (≈ 1493–1494) to reflect the accepted, non-conflicting usage: `--inspect-mode --jsonfile config.json` and `--inspect-mode --jsonstring '{...}'` now work.
- Remove/replace the contradictory line (≈ 1505) *"Inspect-mode configs use a different schema than --jsonfile. Do not mix them."* with: *"Inspect-mode configs use a different schema than standard Dialog configs; the JSON is validated on launch and rejected with an error if it isn't an inspect config."*
- Note that `--inspect-config` is a deprecated alias of `--jsonfile`.

- [ ] **Step 2: Build**

Run: `xcodebuild -project dialog.xcodeproj -scheme "Dialog App Bundle" -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify help renders**

Run: `<Dialog.app>/Contents/MacOS/Dialog --help 2>&1 | grep -iA3 "inspect"`
Expected: updated copy, no "do not mix" contradiction.

- [ ] **Step 4: Commit**

```bash
git add "dialog/Command Line/HelpText.swift"
git commit -m "docs(inspect): help reflects unified --jsonfile/--jsonstring intake"
```

---

## Self-Review

**Spec coverage:**
- Single intake resolution → Task 3 (resolver) + Task 4 (wiring, priority incl. deprecated `--inspect-config`, env, standard location). ✓
- Strict two-gate validation (marker + decode) → Task 1. ✓
- Load-from-data / eliminate triple read → Task 2 (file loader delegates to `fromData`) + Task 4 (sizing from resolved config) + Task 5 (InspectState). ✓
- Precise errors, no blank window → Task 4 (`.notInspect`/`.malformed` → stderr + non-zero exit before window). ✓
- Back-compat (env, standard location, `--inspect-config` alias, standard `--jsonfile` untouched) → Task 3/4. ✓
- Docs/code contradiction fix → Task 6. ✓
- Out of scope (auto-detect w/o `--inspect-mode`) → not implemented, as specified. ✓

**Placeholder scan:** No TBD/TODO. Every code step shows real code. The two "match the exact case name from the grep" notes (Task 2/4) are deliberate — `ConfigurationError`/`ConfigurationResult` case names must be read from the file; the grep step provides them before the code is written.

**Type consistency:** `validateInspectSchema(_ data: Data) -> InspectSchemaValidation` used identically in Tasks 1, 2, 4. `ResolvedInspectSource { data; origin; path }` produced in Task 3, consumed in Task 4. `loadConfiguration(fromData:)` defined in Task 2, consumed in Task 5. `appvars.inspectConfigData: Data?` defined in Task 3, consumed in Tasks 4 & 5. Marker key set identical across Task 1 and the Global Constraints.
