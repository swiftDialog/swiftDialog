# Preset 1/2/3 install-status indicator — header spinner + static row dots

**Date:** 2026-07-04
**Branch:** inspect-cadence-ui-maintenance
**Status:** Approved design, pending implementation plan

## Problem

When several install items run at once, the inspect item lists render one spinning
`ProgressView()` **per active row**. `inspectState.downloadingItems` is a `Set<String>`
that holds every concurrent download, so a `ForEach` over active items produces N
competing spinners — visual noise that conveys no more than a single spinner would.

This is distinct from the already-fixed cadence-carousel case (a *redundant* pair
describing one step). Here the spinners multiply with concurrency.

Affected surfaces:
- `Preset1.swift` — `statusIndicatorWithValidation(for:)`, downloading branch (~`:562`)
- `Preset2.swift` — inlined badge in `Preset2ItemCardView`, `isDownloading` branch (~`:871`)
- `Preset3.swift` — `statusIndicatorWithValidation(for:textColor:)`, downloading branch (~`:625`)

Already handled elsewhere (out of scope here): Preset5 cadence carousel (done),
DetailOverlay "Currently Installing" (done, reference implementation).

## Goal

Apply the **header-spinner + static-row-dots** pattern: motion lives in exactly one
place (the list's existing progress-header region); each row reports its own state with
a **static** indicator drawn in that preset's native visual language.

## Approach — shared decision, per-preset rendering (Approach A)

The three presets today each re-derive row status from `Set` membership
(`failedItems` / `completedItems` / `downloadingItems`) plus a `hasValidationWarning(for:)`
that is **copy-pasted verbatim** in all three. The *decision* is identical; only the
*presentation* differs. So we share the decision and keep the pixels native.

Rejected alternatives:
- **B. Minimal in-place** (swap spinner → static, add header spinner, no dedup) — leaves
  3× duplicated `hasValidationWarning`/status logic.
- **C. Full unification** onto `MonitoringItemStatus` + one identical indicator view —
  overkill; would touch sorting and status-text helpers and risk visual/behavior
  regressions across three layouts.

### Shared piece (dedup) — `PresetCommonHelpers.swift`

```swift
enum InstallRowStatus {
    case pending
    case active                 // in downloadingItems
    case completed
    case completedWithWarning   // completed + validation warning (orange)
    case failed
}

func resolveInstallStatus(item: InspectConfig.ItemConfig, inspectState: InspectState) -> InstallRowStatus
```

- `resolveInstallStatus` encodes the existing 5-way branch order:
  **failed → completed(+warning) → active(downloading) → pending**.
- Move the triplicated `hasValidationWarning(for:)` here as the single source of truth;
  `resolveInstallStatus` calls it for the completed case. Preset copies are deleted and
  replaced with calls to the shared helper.
- No change to sorting (`getItemStatusType`, `getSortedItemsByStatus`) or status-*text*
  helpers in this pass, except deleting the duplicated `hasValidationWarning`.

### Per-preset rendering (each keeps its own dialect)

| Preset | Layout | Row indicator becomes | Active emphasis |
|--------|--------|-----------------------|-----------------|
| 1 | full-width list rows | filled-circle dots: pending = gray ring, **active = static filled accent circle** (was spinner), completed = green check circle, warning = orange, failed = red ✕ | faint tint on active row |
| 2 | card carousel (4 up) | corner badge on icon: **active = static filled accent badge** (was spinner), completed/warning/failed = colored badge. **Pending = no badge** (unchanged from today) | accent tint + ring on active card |
| 3 | 2-col grid, symbol+text | keeps SF Symbol + inline status text; **active = static accent `circle.fill`** beside "Installing…" (was spinner). pending `clock.fill`, completed `checkmark.circle.fill`, warning `exclamationmark.circle.fill`, failed `xmark.circle.fill` | faint tint on active cell |

Each preset's indicator becomes a small `switch resolveInstallStatus(...)` rendering in
its own style. No shared view component is introduced (the presentations diverge enough
that a parameterized view would be more indirection than value); the shared seam is the
enum + resolver.

### Header spinner (the single motion owner) — one per preset

A single small `ProgressView()` docks into each preset's **existing** progress-header
region, shown only while active (any `downloadingItems` and not complete) and replaced by
a completion checkmark when the list finishes:

- Preset1 → beside sidebar progress bar (`:163-169`)
- Preset2 → beside determinate `ProgressView(value:total:)` block (`:363-377`)
- Preset3 → into existing progress header `HStack` (`:220-237`), which already shows a
  checkmark/label/count

## Decisions (confirmed with user)

1. **Motion owner = header spinner** in all three (not "reuse the bar only").
2. **Active emphasis = static dot + subtle row/card/cell tint.**
3. **Preset2 pending cards stay badge-free** — avoids ring clutter across the carousel;
   minimal visual delta from today.
4. **Header spinner kept even beside the determinate bars** — it is one spinner per list
   regardless of concurrency, which is the win over per-row spinners.

## Out of scope

- Preset4/6 and other surfaces from the audit (per-item multiplication there is either
  serial or already acceptable; can be a follow-up).
- Refactoring status-text/color helpers or sorting logic beyond deleting duplicated
  `hasValidationWarning`.
- Changing the underlying `Set`-based state model or adopting `MonitoringItemStatus`.

## Testing / verification

- `xcodebuild -project dialog.xcodeproj -scheme "Dialog App Bundle" -configuration Debug
  build CODE_SIGNING_ALLOWED=NO` must succeed.
- Visual check in the running app: trigger concurrent installs and confirm (a) only one
  spinner per list, in the header; (b) each row shows the correct static state; (c) active
  row/card/cell tint appears; (d) on completion the header spinner becomes a checkmark.
- Confirm failed and validation-warning items render their distinct colors in each preset.

## Risk / rollback

Low. Changes are view-layer only, per-preset, and additive to a shared helper file. Each
preset can be reverted independently. No data-model or IPC changes.
