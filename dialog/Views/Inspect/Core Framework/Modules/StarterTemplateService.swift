//
//  StarterTemplateService.swift
//  dialog
//
//  Starter config templates for all 6 presets.
//  Each template is a self-contained JSON config that newcomers can
//  drop onto the Desktop and run immediately.
//

import Foundation

struct StarterTemplateService {

    // MARK: - Preset Name Lookup

    private static let presetNames: [Int: String] = [
        1: "deployment",
        2: "cards",
        3: "compact",
        4: "toast",
        5: "unified",
        6: "guidance"
    ]

    // MARK: - Template Configs

    private static let templates: [Int: String] = [

        // ── Preset 1: Deployment ────────────────────────────────────────
        1: """
        {
            "preset": "1",
            "title": "App Deployment",
            "message": "Installing applications...(example)",
            "icon": "SF=arrow.down.app.fill",
            "highlightColor": "#007AFF",
            "items": [
                {
                    "id": "safari",
                    "displayName": "Safari",
                    "icon": "/Applications/Safari.app",
                    "paths": ["/Applications/Safari.app"],
                    "showBundleInfo": "all"
                },
                {
                    "id": "calculator",
                    "displayName": "Calculator",
                    "icon": "/System/Applications/Calculator.app",
                    "paths": ["/System/Applications/Calculator.app"],
                    "showBundleInfo": "all"
                },
                {
                    "id": "textedit",
                    "displayName": "TextEdit",
                    "icon": "/System/Applications/TextEdit.app",
                    "paths": ["/System/Applications/TextEdit.app"],
                    "showBundleInfo": "all"
                }
            ]
        }
        """,

        // ── Preset 2: Cards ─────────────────────────────────────────────
        2: """
        {
            "preset": "2",
            "title": "App Catalog",
            "message": "Installing applications...(example)",
            "icon": "SF=rectangle.split.3x1.fill",
            "highlightColor": "#34C759",
            "items": [
                {
                    "id": "safari",
                    "displayName": "Safari",
                    "icon": "/Applications/Safari.app",
                    "paths": ["/Applications/Safari.app"],
                    "showBundleInfo": "all"
                },
                {
                    "id": "calculator",
                    "displayName": "Calculator",
                    "icon": "/System/Applications/Calculator.app",
                    "paths": ["/System/Applications/Calculator.app"],
                    "showBundleInfo": "all"
                },
                {
                    "id": "textedit",
                    "displayName": "TextEdit",
                    "icon": "/System/Applications/TextEdit.app",
                    "paths": ["/System/Applications/TextEdit.app"],
                    "showBundleInfo": "all"
                }
            ]
        }
        """,

        // ── Preset 3: Compact ───────────────────────────────────────────
        3: """
        {
            "preset": "3",
            "title": "Quick Install",
            "message": "Installing essentials...(example)",
            "icon": "SF=list.bullet.rectangle.fill",
            "highlightColor": "#5856D6",
            "secondaryColor": "#AF52DE",
            "items": [
                {
                    "id": "safari",
                    "displayName": "Safari",
                    "icon": "/Applications/Safari.app",
                    "paths": ["/Applications/Safari.app"]
                },
                {
                    "id": "calculator",
                    "displayName": "Calculator",
                    "icon": "/System/Applications/Calculator.app",
                    "paths": ["/System/Applications/Calculator.app"]
                },
                {
                    "id": "textedit",
                    "displayName": "TextEdit",
                    "icon": "/System/Applications/TextEdit.app",
                    "paths": ["/System/Applications/TextEdit.app"]
                }
            ]
        }
        """,

        // ── Preset 4: Toast ─────────────────────────────────────────────
        4: """
        {
            "preset": "4",
            "title": "Background Install",
            "icon": "SF=bell.badge.fill",
            "highlightColor": "#FF9500",
            "introScreen": {
                "title": "Software Check",
                "subtitle": "Checking 3 applications...",
                "buttonText": "Begin"
            },
            "summaryScreen": {
                "title": "All Done",
                "subtitle": "All applications installed successfully.",
                "buttonText": "Close"
            },
            "items": [
                {
                    "id": "safari",
                    "displayName": "Safari",
                    "icon": "/Applications/Safari.app",
                    "paths": ["/Applications/Safari.app"]
                },
                {
                    "id": "calculator",
                    "displayName": "Calculator",
                    "icon": "/System/Applications/Calculator.app",
                    "paths": ["/System/Applications/Calculator.app"]
                },
                {
                    "id": "textedit",
                    "displayName": "TextEdit",
                    "icon": "/System/Applications/TextEdit.app",
                    "paths": ["/System/Applications/TextEdit.app"]
                }
            ]
        }
        """,

        // ── Preset 5: Unified Portal ────────────────────────────────────
        5: """
        {
            "preset": "5",
            "highlightColor": "#007AFF",
            "introSteps": [
                {
                    "id": "welcome",
                    "stepType": "intro",
                    "title": "Welcome",
                    "subtitle": "Your starter Preset 5 workflow (example)",
                    "heroImage": "SF=macbook.gen2",
                    "heroImageSize": 180,
                    "content": [
                        { "type": "text", "content": "This is a two-step starter. Edit config.json to add more steps, change layouts, or customise the content." },
                        { "type": "bullets", "items": ["Step types: intro, deployment, carousel, guide, showcase, bento, processing, portal, outro", "55+ content block types available", "Add branding, forms, compliance checks"] }
                    ],
                    "continueButtonText": "Next",
                    "showBackButton": false
                },
                {
                    "id": "apps",
                    "stepType": "deployment",
                    "title": "App Installation",
                    "subtitle": "Simulated deployment step",
                    "heroImage": "SF=arrow.down.app.fill",
                    "items": [
                        { "id": "safari", "displayName": "Safari", "guiIndex": 0, "icon": "/Applications/Safari.app", "paths": ["/Applications/Safari.app"] },
                        { "id": "calculator", "displayName": "Calculator", "guiIndex": 1, "icon": "/System/Applications/Calculator.app", "paths": ["/System/Applications/Calculator.app"] },
                        { "id": "textedit", "displayName": "TextEdit", "guiIndex": 2, "icon": "/System/Applications/TextEdit.app", "paths": ["/System/Applications/TextEdit.app"] }
                    ],
                    "continueButtonText": "Finish",
                    "showBackButton": true
                }
            ]
        }
        """,

        // ── Preset 6: Guidance / Modern Sidebar ─────────────────────────
        6: """
        {
            "preset": "6",
            "title": "Service Portal",
            "highlightColor": "#007AFF",
            "items": [
                {
                    "id": "overview",
                    "displayName": "Overview",
                    "icon": "SF=house.fill",
                    "guidanceTitle": "Welcome",
                    "guidanceContent": [
                        { "type": "text", "content": "Welcome to the sidebar navigation layout. Users can navigate between sections." },
                        { "type": "info", "content": "Edit config.json to add more sections, change icons, or customise the content blocks." }
                    ]
                },
                {
                    "id": "apps",
                    "displayName": "Applications",
                    "icon": "SF=app.badge.fill",
                    "guidanceTitle": "Applications",
                    "guidanceContent": [
                        { "type": "text", "content": "This section could list available applications or provide self-service options." },
                        { "type": "bullets", "items": ["Safari — Web browser", "Calculator — Quick math", "TextEdit — Text editor"] }
                    ]
                },
                {
                    "id": "help",
                    "displayName": "Help & Support",
                    "icon": "SF=questionmark.circle.fill",
                    "guidanceTitle": "Help & Support",
                    "guidanceContent": [
                        { "type": "text", "content": "Add links, contact info, or troubleshooting guides here." },
                        { "type": "button", "content": "Open Apple Support", "icon": "safari.fill", "action": "url", "url": "https://support.apple.com" }
                    ]
                }
            ]
        }
        """
    ]

    // MARK: - Run Script Template

    private static func generateRunScript() -> String {
        return """
        #!/bin/bash
        # swiftDialog Starter — Launch Script
        # Run: bash run.sh

        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

        # Clean previous state
        defaults delete com.swiftdialog.preset5 2>/dev/null || true
        rm -f /var/tmp/dialog.log /var/tmp/dialog-inspect-trigger.txt

        # Launch
        dialog --inspect-config "$SCRIPT_DIR/config.json" --inspect-mode
        """
    }

    // MARK: - Generate Starter Project

    static func generateStarter(forPreset presetId: String) {
        guard let presetNum = Int(presetId),
              let template = templates[presetNum] else {
            writeLog("StarterTemplate: No template for preset '\(presetId)'", logLevel: .error)
            return
        }

        let presetName = presetNames[presetNum] ?? "unknown"
        let dirName = "swiftdialog-preset\(presetNum)"
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .appendingPathComponent(dirName)

        do {
            // Create directory
            try FileManager.default.createDirectory(at: desktopURL, withIntermediateDirectories: true)

            // Write config.json (pretty-printed by re-serializing)
            let configURL = desktopURL.appendingPathComponent("config.json")
            if let jsonData = template.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) {
                try prettyData.write(to: configURL)
            } else {
                // Fallback: write the raw template string
                try template.write(to: configURL, atomically: true, encoding: .utf8)
            }

            // Write run.sh
            let runURL = desktopURL.appendingPathComponent("run.sh")
            try generateRunScript().write(to: runURL, atomically: true, encoding: .utf8)

            // chmod +x run.sh
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: runURL.path
            )

            // Terminal output
            let divider = String(repeating: "━", count: 66)
            let path = "~/Desktop/\(dirName)/"
            print("""

            \(divider)
              Starter Project Generated
            \(divider)

              ✓ Preset:  \(presetNum) (\(presetName))
              ✓ Path:    \(path)
              ✓ Files:   config.json, run.sh

              Launch it:
              → cd \(path) && bash run.sh

            \(divider)
            """)

            writeLog("StarterTemplate: Generated preset \(presetNum) at \(desktopURL.path)", logLevel: .info)

        } catch {
            writeLog("StarterTemplate: Failed to generate — \(error.localizedDescription)", logLevel: .error)
            print("  ✗ Failed to generate starter: \(error.localizedDescription)")
        }
    }
}
