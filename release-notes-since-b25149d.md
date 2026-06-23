# swiftDialog — Changes Since `b25149d`

*Reference commit: `b25149d` — rename regular dialog "cards" feature to "workflow"*

This document covers everything merged on `release/3.1.0` after the cards→workflow rename.

## New Features

### Regular dialog

- **Branched workflows** — Workflow pages can route to different cards based on user input, with no callback script required. New per-card properties:
  - `branch` — pick the next card from a dropdown selection (`map`) or a checkbox state (`ifTrue` / `ifFalse`), with an optional `default` fallback.
  - `nextpage` — static override that jumps to a specific card `id` after Next.
  - `finalpage` — terminates the workflow at this card; Button 1 becomes "Finish" regardless of remaining cards.

  The Previous button is history-aware and unwinds whichever path the user actually took. See `dialog/CARDS_FEATURE_DOCUMENTATION.md` for examples. (commit `655de51`)

- **aria2 partial-file support** — `cacheExtensions` is now a configurable array that marks an item as "downloading" while a partial file with one of these extensions exists in `cachePaths`. Default is `['download','pkg','dmg']`; add `'aria2'` for aria2c, which writes `<name>.aria2` partials. Leading dot optional. (#617, commit `4627c5a`)

### Inspect mode

- **Gated cadence engine** — DEPNotify-style `POLICY_ARRAY` replacement. Messages only advance when a real monitored attribute is satisfied (`app` / `file` / `plist` / `defaults` / `json` / `managedpref`), with optional IPC drive (`cadence:satisfy`, `cadence:advance`, `cadence:goto`) and per-entry timeout / minimum-dwell controls. New `stepType: "cadence"` and matching schema definitions `CadenceEntry` / `CadenceAttribute`. (commit `8481b43`)

- **`cadenceStyle: "carousel"`** — DEPNotify-style horizontal icon-card row (done/active/pending) for cadence steps. (commit `ef29b48`)

- **`managedpref` attribute type** — Cadence and gating conditions can read `/Library/Managed Preferences/<domain>.plist` directly. MDM-agnostic; works with any management vendor. Supports device and user scope. (commit `8481b43`)

- **`ManagedValueRef` for per-tenant branding** — Lets brand colour and claims pull from different MDM payload domains via a `{domain, key, darkKey}` reference. Brand colour can now come from one profile while claim text comes from another. (commit `8481b43`)

- **Forced appearance** — New `appearance` config key (`"dark"` / `"light"` / `"auto"`) forces the inspect window appearance regardless of the OS setting, in both directions. (#669, commit `8481b43`)

- **Preset 3 redesign** — Hero block, bottom footer, slim brand progress line, rebalanced spacing. (commit `ef29b48`)

- **Persistent footer brand logo** — Stays across step transitions, supports dark-mode variant, honours `maxHeight`. (commit `ef29b48`)

- **Per-item descriptions** — List items across Presets 1, 2, 3, 5, and 6 now support a description string rendered beneath the item title. (#663, commit `ef29b48`)

- **Unified brand-tinted info badge** — Brand colour falls back to `highlightColor` when not set. (commit `ef29b48`)

### Inspect IPC

- **Per-PID session discovery** — New `--published-sessions-dir` publishes a `<pid>.json` file per running Dialog so external drivers (install scripts, ignitecli, MDM helpers) can discover an active session. (commit `de7d02b`)

- **Enriched session JSON** — Published session JSON now includes `resultFile`, `readinessFile`, and `eventFile` paths so consumers don't need to guess. (commit `de7d02b`)

## Bug Fixes

- **Pseudo notifications no longer steal focus** when delivered. (#674, commit `6571420`)

- **Preset 2 header subtitle now sourced from `message`**. (#670, commit `9116c6d`)

- **Preset 2 card window auto-follows installs**. (#565, commit `9116c6d`)

- **Preset 2 custom status + progress text now respected**. (#571, commit `9116c6d`)

- **Distributed notifications**: ignore trigger-file content written before the session is ready (test added). (commit `de7d02b`)

## Schema & Cleanup

- **inspect-config schema (`inspect-config.schema.json`)** reconciled against `InspectConfig.swift` (commit `e17dcfa`):
  - Added: `CadenceAttribute`, `CadenceEntry`, `ManagedValueRef` definitions; `cadence` keys on `StepBase`; new `cadence` step-type branch and enum value; `appearance` enum.
  - Removed: duplicate camelCase button keys (`button1Disabled`, `button1Text`, `button2Text`, `button2Visible`), legacy `FeatureItem` / `features`, `guidanceContent.multiline`.
  - Tightened: `cacheExtensions` now typed as `array<string>` with description.

- **Scheme cleanup** — Removed a stale absolute `--jsonfile` launch arg from the Dialog App Bundle scheme. (commit `de7d02b`)

## Documentation

- `docs/cadence-mdm-deployment.md` — MDM deployment guide for the new cadence engine.
- `docs/ipc-contract-gap-analysis.md` — IPC contract review and identified gaps.

## Build

- Build number bump (commit `93bf073`).
- `main` merged into `release/3.1.0` (commit `ecdbf6c`).

## Stats

```
31 files changed, 2450 insertions(+), 327 deletions(-)
```

Largest deltas:
- `dialogTests/dialogTests.swift` — +503 lines (cadence engine test coverage)
- `Preset5.swift` — +332 lines
- `IntroStepMonitorService.swift` — +307 lines (new file)
- `CardState.swift` — +255 / restructured (branched workflow routing)
- `Preset3.swift` — +223 / -120 (redesign)
- `inspect-config.schema.json` — +193 / -28

Full diff: `changes-since-b25149d.diff`
