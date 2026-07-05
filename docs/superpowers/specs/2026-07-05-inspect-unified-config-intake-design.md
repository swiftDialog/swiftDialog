# Inspect Mode: Unified Config Intake + Strict Schema Validation

**Date:** 2026-07-05
**Status:** Design — approved for spec review
**Area:** `dialog/Command Line/ProcessCLOptions.swift`, `dialog/Views/Inspect/Services/Config.swift`, `dialog/Views/Inspect/Core Framework/InspectState.swift`

## Goal

Make launching inspect mode simple and predictable: accept the inspect config JSON from **any** supported source, validate it against the inspect schema up front, and fail with a precise error when it doesn't conform — instead of the current mix of a bespoke flag, three resolution paths, a hard rejection of `--jsonfile`/`--jsonstring`, and silent "blank window" failures.

One mental model for the user: *"Hand inspect mode JSON any way you like. It validates, or it tells you exactly why not."*

## Current behavior (the problem)

Config reaches inspect mode as a **file path**, resolved in `ProcessCLOptions.getJSON()` / the inspect-mode block:

1. `DIALOG_INSPECT_CONFIG` env var (a path)
2. Standard location `/var/tmp/dialog-inspect-config.json`
3. `--inspect-config <path>` CLI arg

The chosen path is stored in `appvars.inspectConfigPath`; `InspectState.loadConfiguration` then **re-reads the file** via `configurationService.loadConfiguration(fromFile:)`. The file is read up to 3× (once in `getJSON`, once for window-sizing via `MinimalInspectConfig`, once in `InspectState`).

Pain points:

- **Hard rejection.** `getJSON()` (≈ lines 50–65) explicitly errors if `--inspect-mode` is combined with `--jsonfile`/`--jsonstring`, because the schemas differ.
- **Docs contradict code.** `HelpText.swift:1493–1494` documents `dialog --inspect-mode --jsonfile config.json` and `--jsonstring '{…}'` as valid — but the code rejects exactly that.
- **Known hang.** A logged note warns `--inspect-config` "may cause hang with certain SwiftUI versions"; the env-var and standard-location paths exist as workarounds, and `ignitecli ipc launch` is the blessed path.
- **Silent failure mode.** A wrong-schema JSON produces a blank window rather than an error.

## Proposed design

### 1. Single intake resolution

When `--inspect-mode` is present, resolve the config from the **first** available source in this priority (explicit flags beat ambient sources):

1. `--jsonstring '{…}'` (inline)
2. `--jsonfile <path>`
3. `--inspect-config <path>` — retained as a **deprecated alias** of `--jsonfile` (logs a deprecation note)
4. `DIALOG_INSPECT_CONFIG` env var (path) — IPC transport, unchanged
5. `/var/tmp/dialog-inspect-config.json` standard location — IPC transport, unchanged

Resolution yields `(data: Data, origin: String)` where `origin` is a human label used in logs and error messages (e.g. `--jsonfile /path`, `DIALOG_INSPECT_CONFIG`, `standard location`). If `--inspect-mode` is set but no source resolves, exit non-zero with guidance listing the accepted sources.

The `--jsonfile`/`--jsonstring` rejection guard is **removed**. The standard (non-inspect) `--jsonfile`/`--jsonstring` path is untouched when `--inspect-mode` is absent.

### 2. Strict schema validation

A standalone, reusable function:

```
enum InspectSchemaValidation {
    case valid(InspectConfig)
    case notInspect(missingMarkers: Bool)   // no inspect marker keys present
    case malformed(reason: String)          // markers present but decode failed
}
func validateInspectSchema(_ data: Data) -> InspectSchemaValidation
```

Strict rule — two gates, both required:

- **Gate A (intent marker):** the raw JSON object must contain at least one of `inspectMode`, `preset`, `introSteps`, `items` as a present key (checked on the raw object, not on decoded optionals — decoding is too lenient and would let a standard `{"title":…}` "pass" with everything `nil`).
- **Gate B (decodes):** the data decodes into `InspectConfig` via the existing decoder (including the current scalar-coercion pre-pass, `InspectConfigCoercion.coerceScalars`).

Outcomes:

- Gate A fails → `notInspect`. Error: *"No inspect content found (expected `preset`, `introSteps`, or `items`). If you meant a standard dialog, drop `--inspect-mode`."*
- Gate A passes, Gate B fails → `malformed`. Error: *"Inspect config is malformed: `<decoder error>`"* (include the failing key path where the decoder provides it).
- Both pass → `valid(config)`, proceed.

All failures exit non-zero **before** any window is shown.

### 3. Load-from-data (eliminate re-reads and enable inline)

Add `loadConfiguration(fromData:)` to the configuration service (`Config.swift`), funnelling the existing file loader through it (`fromFile:` reads the file then calls `fromData:`). Store the resolved `Data` on `appvars` (e.g. `inspectConfigData`) alongside `inspectConfigPath` (kept for logging/back-compat).

- `InspectState.loadConfiguration` uses `fromData:` when `inspectConfigData` is set, else falls back to `fromFile:` (back-compat).
- Window-sizing (`MinimalInspectConfig`) decodes the already-resolved `Data`, not a fresh file read.
- Net: one read (or zero for `--jsonstring`), one decode surface. No temp file required for the inline string.

## Components & responsibilities

| Unit | Responsibility | Depends on |
|------|----------------|------------|
| `resolveInspectConfigSource()` (ProcessCLOptions) | Pick the highest-priority source, return `(Data, origin)` or a fatal "no source" error | CLI args, env, FileManager |
| `validateInspectSchema(_:)` (new, standalone) | Strict two-gate validation, return typed result | `InspectConfig`, `InspectConfigCoercion`, JSONSerialization for marker check |
| `Config.loadConfiguration(fromData:)` | Decode `Data` → `InspectConfig` result (existing logic, new entry point) | existing decode/coercion |
| `InspectState.loadConfiguration` | Consume resolved data/path, drive UI state | `Config`, `appvars` |
| Sizing read (ProcessCLOptions) | Decode resolved `Data` for preset/window dims | resolved `Data` |

Each is independently testable: the resolver with fabricated args/env, the validator with fixture JSON, the loader with `Data`.

## Data flow

```
--inspect-mode set
  → resolveInspectConfigSource() → (Data, origin)
  → validateInspectSchema(Data)
      notInspect / malformed → stderr error + exit(non-zero)
      valid(config) →
          appvars.inspectConfigData = Data (+ inspectConfigPath if file-based)
          sizing decode from Data
          InspectView → InspectState.loadConfiguration(fromData:) → render
```

## Error handling

- All validation errors write a single, actionable message to stderr and exit non-zero — never a blank window.
- Messages name the `origin` so the user knows *which* input was used (important when env/standard-location are also present).
- `--inspect-config` continues to work but logs: *"`--inspect-config` is deprecated; use `--jsonfile`."*

## Backward compatibility

- `DIALOG_INSPECT_CONFIG` and `/var/tmp/dialog-inspect-config.json` keep working unchanged (ignitecli IPC path is unaffected).
- `--inspect-config` keeps working as a `--jsonfile` alias.
- Standard (non-inspect) `--jsonfile`/`--jsonstring` behavior is unchanged.
- Existing configs need no changes.

## Testing

- **Validator unit tests:** standard-Dialog JSON → `notInspect`; inspect JSON with only `items` → `valid`; inspect JSON with a type error → `malformed`; empty `{}` → `notInspect`; quoted-scalar config (coercion) → `valid`.
- **Resolver unit tests:** priority ordering (jsonstring > jsonfile > inspect-config > env > standard location); "no source" fatal.
- **Integration (manual, real window):** `dialog --inspect-mode --jsonfile p1.json`, `--jsonstring '{…}'`, env var, and standard location each launch and render; a standard-Dialog JSON under `--inspect-mode` errors cleanly; confirm no `--inspect-config` hang via the `--jsonfile` route.

## Out of scope (explicitly)

- **Auto-detecting inspect vs standard without `--inspect-mode`.** Rerouting the app's entire entry path based on JSON shape is a larger, riskier change. `--inspect-mode` stays required; Gate A gives most of the ergonomic win safely.
- Changing the inspect config schema itself.
- Changing standard-Dialog `--jsonfile`/`--jsonstring` behavior.
