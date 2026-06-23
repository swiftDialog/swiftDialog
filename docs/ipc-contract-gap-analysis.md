# swiftDialog ↔ ignitecli IPC Contract — Gap Analysis

**Status:** Draft for review
**Date:** 2026-06-17
**Scope:** Runtime IPC between `swiftDialog` (Inspect Mode, presets 1–6) and `ignitecli`
that launches and drives it.
**Repos:**
- swiftDialog — `/Users/henry/Projects/GitHub/swiftDialog`
- ignitecli — `/Users/henry/Projects/GitHub/ignitecli-swift-private`

This document pins the IPC contract as it exists today, then enumerates the gaps
where the two sides agree only by coincidence or where a guarantee is assumed but
not enforced. Every claim is anchored to a `file:line` so it can be re-verified.

---

## 1. Transport overview

Three transports are in play. The contract is the union of all three; a robust
implementation must not assume any single one is reliable.

| Transport | Direction | Channel / Path | Payload | Reliability |
|---|---|---|---|---|
| Distributed notification (command) | ignitecli → dialog | `com.swiftdialog.command` **and** `com.ignitecli.command` | `userInfo` dict, stringified | Best-effort, no ordering, **lost if posted before observer registers** |
| Distributed notification (event) | dialog → ignitecli | `com.swiftdialog.event` | `userInfo` dict incl. `event`, `pid` | Best-effort |
| Distributed notification (ack) | dialog → ignitecli | `com.swiftdialog.ack` | `userInfo` dict incl. `command`, `stepId`, `status`, `pid` | Best-effort, **rarely consumed** |
| Trigger / command file | ignitecli → dialog | `--status-log-file` / per-PID `.command` | newline-delimited, colon-separated | Durable, byte-offset tracked |
| Readiness file | dialog → ignitecli | `<trigger>.ready` or config `readinessFile` | JSON | Durable, presence-polled |
| Event file | dialog → ignitecli | config `eventFile` or derived `.events` | JSONL | Durable, tail-polled |
| Result file | dialog → ignitecli | config `resultFile` / per-PID `.result.json` | JSON | Durable |
| Published sessions dir | dialog → *(nobody)* | `--published-sessions-dir` (default `/private/tmp/swiftdialog/sessions/<pid>.json`) | JSON | Durable, **not consumed** — see Gap 1 |
| ignitecli IPC state | ignitecli → ignitecli | `/private/tmp/.ignitecli-ipc-<pid>.json` | JSON | Durable |

**Source anchors**
- Channels: `dialog/Views/Inspect/Core Framework/DistributedNotifications.swift:36`;
  ignitecli `Sources/Dialog/ActionDispatcher.swift:9`.
- Both-channel posting: ignitecli `Sources/Commands/IpcCommand.swift:414`.
- Command file routing: `dialog/Views/Inspect/Core Framework/CommandRouter.swift:76`.
- Published sessions dir: `dialog/Command Line/CommandLineArguments.swift:167`,
  `dialog/Views/Inspect/Core Framework/PresetCommonHelpers.swift:1134`.
- ignitecli state: `Sources/Dialog/IpcState.swift:11`.

---

## 2. Event vocabulary (the wire contract)

swiftDialog emits these event types (`DistributedNotifications.swift:36`, locked rawValues):

| EventType | rawValue | Emitted when | Key fields |
|---|---|---|---|
| `ready` | `ready` | UI ready for commands | `triggerFile`, `preset?`, `itemCount?`, `items?`, `ackChannel` |
| `exit` | `exit` | About to terminate | `triggerFile`, `exitCode?`, `completedCount?`, `failedCount?`, `resultFile?` |
| `deferred` | `defer` | User deferred | `duration`, `seconds`, `exitCode`, `resultFile` |
| `button` | `button` | Button click | `stepId`, `button`, `action` |
| `step` | `step` | Step transition | `stepId`, `action` (e.g. `completed`, `all_complete`) |
| `selection` | `selection` | Picker/grid commit | `key`, `values` |

Preset 6 confirmed to emit `step`, `button`, `selection`
(`Preset6.swift:1251`, `:1116`, `:1638`).

Accepted commands (ignitecli → dialog), routed in `CommandRouter.swift:76–163`:
`success`, `failure`, `warning`, `complete`, `navigate`/`goto`, `next`/`prev`/`back`,
`reset`, `progress`, `update_guidance`, `update_message`, `batch_update`,
`display_data`, `recheck`, `set`, `item`, `listitem`, `select`.
Shorthand `userInfo` keys expand to these (`DistributedNotifications.swift:177`).

---

## 3. Gaps

Ranked by severity. Each gap states the **observed reality**, the **risk**, and a
**proposed contract clause** (normative language for a future shared spec).

### Gap 1 — Published sessions dir is write-only; ignitecli never reads it · **HIGH**

**Observed.** swiftDialog writes a per-PID discovery file to
`/private/tmp/swiftdialog/sessions/<pid>.json`
(`PresetCommonHelpers.swift:1134`, CLI `CommandLineArguments.swift:167`). A grep of
all of ignitecli `Sources/` finds **no reader** for that directory. ignitecli
discovers sessions solely via its own `/private/tmp/.ignitecli-ipc-<pid>.json`
(`IpcState.swift:11`), which it wrote at launch.

Two parallel registries describe the same fact (which dialog is alive on which
trigger file) and never reconcile:

| Registry | swiftDialog writes | ignitecli reads |
|---|---|---|
| `…/swiftdialog/sessions/<pid>.json` | ✅ | ❌ |
| `…/.ignitecli-ipc-<pid>.json` | ❌ | ✅ |

**Risk.** ignitecli can only ever attach to a dialog it personally launched. If
ignitecli loses its own state file (crash, restart, separate invocation), the
running dialog is unrecoverable even though swiftDialog is advertising it. The
recently shipped discovery feature delivers zero value to its only in-tree consumer.

**Proposed clause.**
> swiftDialog SHALL publish a discovery record per live session. ignitecli SHALL
> treat the published sessions dir as the authoritative discovery source and SHALL
> be able to adopt a session found there (read `triggerFile`, `resultFile`,
> `readinessFile`, `ackChannel`, `pid`) without having launched it. ignitecli's
> private state file MAY remain as a launch-time cache but MUST NOT be the sole
> source of truth.

**Open decision (owner: ignitecli).** Is the sessions dir intended for ignitecli
recovery, or for *external* tooling (monitoring/MDM)? That choice determines whether
ignitecli grows a "discover & adopt" path or this stays deliberately out-of-band.

### Gap 2 — Event-file path derived by two different rules · **MEDIUM**

**Observed.** swiftDialog resolves the event path as
`config.eventFile ?? readinessFile(.ready → .events)`
(`Preset5.swift:4834`, identical in `Preset1.swift:460`, `Preset2.swift:533`,
and Preset 6). ignitecli templates **always set `eventFile` explicitly**
(`Sources/Resources/templates/*/config.json` → `/tmp/__WORKFLOW_NAME__.events`).
They converge only because the config always sets the key.

**Risk.** A config that sets a custom `readinessFile` and omits `eventFile` makes
swiftDialog derive a path ignitecli's `wait-step` is not watching. `wait-step`
(`IpcCommand.swift` WaitStep, 2 s poll) then hangs to its timeout with no
diagnostic naming the path mismatch.

**Proposed clause.**
> The event-file path SHALL be derived by exactly one rule, shared by both sides.
> If both ends derive (rather than requiring an explicit `eventFile`), the
> derivation algorithm SHALL be specified here verbatim and covered by a test on
> each side. A `wait-step` timeout SHALL include the resolved event-file path in
> its error.

### Gap 3 — Waiters that matter don't check process liveness · **MEDIUM**

**Observed.** `wait-exit` checks `kill(pid, 0)` (`IpcState.swift:58`) and notices a
dead dialog. `wait-ready` and `wait-step` wait on a notification or file mutation;
`wait-step` only catches a dead PID if its early check happens to fire, otherwise it
burns the full timeout (`IpcCommand.swift` WaitStep, `:376`).

**Risk.** A dialog that crashes mid-step turns a fast, clear failure into a 2–600 s
generic timeout with no cause.

**Proposed clause.**
> Every waiter (`wait-ready`, `wait-step`, `wait-exit`) SHALL poll `kill(pid,0)` on
> the same tick as its file/notification check and SHALL fail fast with
> `dialog PID <n> exited before <condition>` rather than a generic timeout.

### Gap 4 — Ack channel exists on both ends but is not used as a barrier · **MEDIUM**

**Observed.** swiftDialog posts to `com.swiftdialog.ack` after every routed command
(`CommandRouter.swift:351`). ignitecli has `waitAck()`
(`Sources/Dialog/DialogOrchestrator.swift:151`) but most workflows never call it;
the default delivery mode is fire-and-forget over a best-effort transport.

**Risk.** A dropped `navigate` notification that gates a subsequent pre-loaded batch
desyncs the whole flow silently. Idempotent UI paints tolerate loss; ordering-
critical commands do not.

**Proposed clause.**
> Commands whose effect gates later commands (`navigate`, `goto`, `reset`,
> `batch_update` that precedes a navigate) SHALL be sent with ack-wait enabled.
> ignitecli SHALL retry or surface an error if no ack for such a command arrives
> within the ack timeout. Fire-and-forget remains permitted for idempotent paints
> (`progress`, `update_message`, `display_data`).

### Gap 5 — Trigger-file replay hazard fixed twice, owned by neither · **LOW–MEDIUM**

**Observed.** ignitecli deletes IPC files pre-launch
(`DialogLauncher.swift:199`) to stop swiftDialog replaying stale `success:` lines
(the preset-5 flash-through). swiftDialog independently records the initial byte
offset to skip pre-existing content (`CommandRouter.swift:79`). Two independent
fixes guard one hazard.

**Risk.** If either regresses — swiftDialog reads from offset 0 again, or ignitecli
skips cleanup in a new path — the bug silently returns.

**Proposed clause.**
> swiftDialog SHALL ignore any trigger-file content present before it posts `ready`.
> This guarantee SHALL be owned and tested on the swiftDialog side; ignitecli's
> pre-launch cleanup is defense-in-depth, not the primary guarantee.

### Gap 6 — No authentication on any transport (accepted, but unstated) · **LOW**

**Observed.** No sender validation on distributed notifications (the API exposes
none); the command/trigger file is world-writable; the sessions dir is
world-readable and enumerable. Any local process can drive or spoof the dialog and
can enumerate live PIDs + trigger paths. The new sessions dir *broadens* this
disclosure surface.

**Risk.** Acceptable under a same-user local trust model; dangerous if that
assumption is ever violated (shared host, lower-privilege co-tenant).

**Proposed clause.**
> The IPC trust boundary is "same-user, same-host, local." All transports assume a
> cooperating local sender. This is a deliberate, documented assumption; no
> transport provides authentication or integrity. Any deployment outside that
> boundary is out of scope and unsupported.

---

## 4. Severity summary & sequencing

| # | Gap | Severity | Fix locus |
|---|---|---|---|
| 1 | Sessions dir write-only | HIGH | ignitecli (reader) |
| 2 | Two event-path rules | MEDIUM | both (shared rule) |
| 3 | Waiters skip liveness | MEDIUM | ignitecli |
| 4 | Ack not used as barrier | MEDIUM | ignitecli (policy) |
| 5 | Replay fixed twice | LOW–MED | swiftDialog (own the guarantee) |
| 6 | No auth, unstated | LOW | doc only |

**Recommended order.** Pin this contract first (Gaps 5–6 are doc-only and close
immediately). Then land **Gap 1 + Gap 2 together** — make ignitecli consume the
published sessions dir as the authoritative discovery source and collapse the
event-path derivation to one rule. That converts the recent swiftDialog IPC commits
into something ignitecli actually uses. Gaps 3–4 are independent ignitecli
robustness fixes that can follow.

---

## 5. Verification log

Claims in this document were checked against source on 2026-06-17:

- Sessions dir not read by ignitecli — grep of `Sources/` for
  `swiftdialog/sessions` / `publishedSessions`: no consumer.
- Preset 6 emits step/button/selection — `Preset6.swift:1116,1152,1251,1638`.
- Event-path dual derivation — `Preset1.swift:460`, `Preset2.swift:533`,
  `Preset5.swift:4834`; ignitecli explicit `eventFile` in
  `Sources/Resources/templates/*/config.json`.
- Ack posted but optional — `CommandRouter.swift:351`,
  ignitecli `DialogOrchestrator.swift:151`.
- Liveness only in `wait-exit` — `IpcState.swift:58`.
- Pre-launch cleanup vs. byte-offset skip — `DialogLauncher.swift:199`,
  `CommandRouter.swift:79`.
