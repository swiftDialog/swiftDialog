//
//  InspectState+SampleConfig.swift
//  dialog
//
//  Writes the built-in sample config to a temp file and exits (testData mode only).
//

import SwiftUI

extension InspectState {
    func createSampleConfiguration() {
        guard configurationSource == .testData else {
            writeLog("InspectState: createSampleConfiguration called but not in test mode", logLevel: .debug)
            return
        }

        let sampleConfig = inspectDemoConfigJSON

        let configPath = NSTemporaryDirectory() + "inspect-config-sample.json"
        let divider = String(repeating: "━", count: 66)

        do {
            try sampleConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
            writeLog("InspectState: Sample configuration created at: \(configPath)", logLevel: .info)

            print("")
            print(divider)
            print("  Sample Configuration Created")
            print(divider)
            print("")
            print("  ✓ Preset: 5 (unified)")
            print("  ✓ Steps:  3 (intro → bento → deployment)")
            print("  ✓ File:   \(configPath)")
            print("")
            print("  Launch it:")
            print("  → dialog --inspect-config \"\(configPath)\" --inspect-mode")
            print("")
            print("  Or copy and customize:")
            print("  → cp \"\(configPath)\" ~/Desktop/my-config.json")
            print("")
            print(divider)
            print("")

            // Exit code 10: sample created.
            exit(10)
        } catch {
            writeLog("InspectState: Failed to create sample configuration: \(error)", logLevel: .error)
        }
    }
}
