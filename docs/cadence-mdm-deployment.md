# Gated cadence in an MDM deployment

The gated-cadence step turns a deployment screen into an **attribute-driven** sequence: each message
is shown until a **real condition** is met, then it advances. The conditions are read from real
system state, so the screen never claims "done" before it is.

This is **MDM-agnostic.** The signals it reads — installed apps, package receipts, and
**mobileconfig managed preferences under `/Library/Managed Preferences/`** — are produced the same
way by **Fleet, Jamf, Intune, Mosyle, Kandji, Munki, Installomator**, and friends. The examples
below use **Fleet** as the worked case, but nothing is Fleet-specific.

## How it fits a rollout

The MDM does the work (installs software, pushes profiles); swiftDialog **observes** it:

| Deployment task | Cadence attribute | What it reads |
|---|---|---|
| App installed | `app` (`bundleId`) | `NSWorkspace.urlForApplication(withBundleIdentifier:)` |
| Pkg installed | `file` | receipt at `/var/db/receipts/<pkgid>.bom` |
| **Profile / mobileconfig landed** | **`managedpref`** (`domain`+`key`) | `/Library/Managed Preferences/<domain>.plist` (device) or `…/<user>/<domain>.plist` |
| Script-driven config | `file` | a marker file the script touches |
| Non-observable check | `source:"ipc"` | an MDM script calls `cadence:satisfy:<id>` (osquery, Installomator log, MDM API) |

**Hybrid drive:** most entries poll natively (no orchestrator, works offline / at the login window);
a few `source:"ipc"` entries are advanced by an MDM script for things that can't be observed
directly. The IPC verb is `cadence:satisfy:<id>` (also `advance` / `goto`).

`timeout` on an entry force-advances if a task never completes, so a failed policy can't hang the UI.

## Two phases

Because the login-window/Setup-Assistant phase has **no user session** (no user apps, only
device-level managed prefs), use two configs, selected per session by the launcher.

### Phase A — login window / Setup Assistant (device-level only)
```json
{
  "preset": "5", "stepType-note": "device phase",
  "introSteps": [{
    "id": "deploy", "stepType": "cadence", "title": "Setting up your Mac",
    "cadenceInterval": 1.0, "cadenceMinDwell": 0.6, "autoAdvance": true,
    "cadence": [
      { "id": "mdm",      "message": "Confirming management…", "sfSymbol": "checkmark.shield.fill",
        "attribute": { "type": "managedpref", "domain": "com.apple.mdm", "key": "AccessRights", "evaluation": "exists", "scope": "device" }, "timeout": 600 },
      { "id": "filevault","message": "Enabling disk encryption…", "sfSymbol": "lock.fill",
        "attribute": { "type": "managedpref", "domain": "com.apple.MCX.FileVault2", "key": "Enable", "evaluation": "equals", "expectedValue": "On", "scope": "device" }, "timeout": 900 },
      { "id": "rosetta",  "message": "Installing base packages…", "sfSymbol": "shippingbox.fill",
        "attribute": { "type": "file", "path": "/var/db/receipts/com.company.baseline.bom" }, "timeout": 900 }
    ]
  }]
}
```

### Phase B — post-login desktop (full signals)
```json
{
  "preset": "5",
  "introSteps": [{
    "id": "deploy", "stepType": "cadence", "title": "Installing your apps",
    "cadenceInterval": 0.5, "cadenceMinDwell": 0.6, "autoAdvance": true,
    "cadence": [
      { "id": "edge",    "message": "Installing Microsoft Edge…", "sfSymbol": "globe",
        "attribute": { "type": "app", "bundleId": "com.microsoft.edgemac" }, "timeout": 600 },
      { "id": "office",  "message": "Installing Office…", "sfSymbol": "doc.fill",
        "attribute": { "type": "app", "bundleId": "com.microsoft.Word" }, "timeout": 1200 },
      { "id": "vpn",     "message": "Applying VPN profile…", "sfSymbol": "network",
        "attribute": { "type": "managedpref", "domain": "com.company.vpn", "key": "Enabled", "evaluation": "boolean", "expectedValue": "true", "scope": "device" }, "timeout": 600 },
      { "id": "compliance","message": "Running compliance check…", "sfSymbol": "checkmark.seal.fill",
        "attribute": { "source": "ipc" }, "timeout": 600 }
    ]
  }]
}
```
The `compliance` entry is `source:"ipc"`: an MDM script runs the check (osquery / vendor API) and then
`… ipc send "cadence:satisfy:compliance"`.

## Shipping it (Fleet example — same shape for any MDM)
1. **Package** swiftDialog + the launcher + both cadence JSONs.
2. **Profile (mobileconfig)** configuring the launcher: which config per session, login-window flags.
   (The launcher reads its own managed prefs the same way — under `/Library/Managed Preferences/`.)
3. **LaunchAgents** (device + login-window) to start swiftDialog in the right session.
4. **GitOps / policies**: the profiles and software the cadence gates on, plus the small script that
   emits `cadence:satisfy` for any `source:"ipc"` entries.

Generate the mobileconfig + GitOps artifacts with the `contour` / `fleet-gitops` tooling, which
validates the profile against Apple's schema.

## Notes
- `managedpref` reads the file directly, so it advances the instant the profile lands (no
  CFPreferences cache lag). `evaluation:"exists"` = "profile is present"; `equals`/`boolean` = "a
  specific value is enforced".
- At the login-window phase only **device** scope exists; user-scope managed prefs and `app` checks
  belong in Phase B.
- Returning to a completed cadence (Back) **fast-replays** at `cadenceMinDwell` and stops — it does
  not re-gate or hang.
