//
//  InspectView.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//
//  Service-based implementation of InspectView
//  Uses InspectState with clean separation of concerns
//

import SwiftUI

struct InspectView: View {
    @StateObject private var inspectState = InspectState()
    @State private var showingAboutPopover = false

    var body: some View {
        Group {
            switch inspectState.loadingState {
            case .loading:
                CoordinatedLoadingView()
                    .onAppear {
                        if appvars.debugMode {
                            print("DEBUG: InspectViewServiceBased: Loading state - using new coordinator")
                        }
                    }

            case .failed(let errorMessage):
                CoordinatedConfigErrorView(
                    errorMessage: errorMessage,
                    onRetry: {
                        inspectState.retryConfiguration()
                    },
                    onQuit: {
                        quitDialog(exitCode: appDefaults.exit202.code, exitMessage: "Configuration error")
                    }
                )
                .onAppear {
                    print("ERROR: InspectViewServiceBased: Failed state - \(errorMessage)")
                }

            case .loaded:
                presetView(for: inspectState.uiConfiguration.preset)
                    .onAppear {
                        if appvars.debugMode {
                            print("DEBUG: InspectViewServiceBased: Loading preset '\(inspectState.uiConfiguration.preset)' with new coordinator")
                        }
                    }
            }
        }
        .onAppear {
            if appvars.debugMode {
                print("DEBUG: InspectViewServiceBased: Starting with service-based architecture")
            }
            writeLog("InspectViewServiceBased: Initializing with InspectState", logLevel: .info)
            inspectState.initialize()
        }
    }

    // MARK: - Helper Methods

    /// Factory method for preset creation
    @ViewBuilder
    private func presetView(for presetName: String) -> some View {
        let preset = presetName.lowercased()
        // Size mode is now handled by InspectSizes
        let basePreset = preset

        switch basePreset {
        case "preset1", "1", "deployment":
            Preset1View(inspectState: inspectState)
        case "preset2", "2", "cards":
            Preset2View(inspectState: inspectState)
        case "preset3", "3", "compact":
            Preset3Wrapper(coordinator: inspectState)
        case "preset4", "4", "toast", "compact-installer":
            Preset4Wrapper(coordinator: inspectState)
        case "preset5", "5", "portal", "self-service", "webview-portal":
            Preset5Wrapper(coordinator: inspectState)
        case "preset6", "6", "guidance", "modern-sidebar":
            Preset6Wrapper(coordinator: inspectState)
        default:
            Preset1View(inspectState: inspectState)
                .onAppear {
                    print("WARNING: InspectViewServiceBased: Unknown preset '\(presetName)', using default")
                }
        }
    }
}

// MARK: - Loading View

private struct CoordinatedLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading configuration...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Error View

private struct CoordinatedConfigErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    let onQuit: () -> Void

    @State private var copied = false

    /// Format error details for clipboard
    private var formattedErrorForCopy: String {
        let error = parsedError
        var lines: [String] = []

        lines.append("Configuration Error")
        lines.append("=" .padding(toLength: 40, withPad: "=", startingAt: 0))
        lines.append("")
        lines.append("Error: \(error.errorType)")

        if let details = error.details {
            lines.append("Location: \(details)")
        }

        if let filePath = error.filePath {
            if let lineNum = error.lineNumber {
                lines.append("File: \(filePath):\(lineNum)")
            } else {
                lines.append("File: \(filePath)")
            }
        }

        if let snippet = error.jsonSnippet {
            lines.append("")
            lines.append("Code snippet:")
            let codeLines = snippet
                .components(separatedBy: "\n")
                .filter { $0.contains(":") && $0.trimmingCharacters(in: .whitespaces).first?.isNumber == true }
            lines.append(contentsOf: codeLines)
        }

        if let hint = error.hint {
            lines.append("")
            lines.append("Hint: \(hint)")
        }

        return lines.joined(separator: "\n")
    }

    /// Copy error details to clipboard
    private func copyErrorToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedErrorForCopy, forType: .string)
        copied = true

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    /// Parse error message into structured components for better display
    // swiftlint:disable:next large_tuple
    private var parsedError: (filePath: String?, errorType: String, details: String?, lineNumber: Int?, jsonSnippet: String?, hint: String?) {
        // Extract file path from message like "Invalid JSON in configuration file /path/file.json: ..."
        var filePath: String?
        var errorType = errorMessage
        var details: String?
        var lineNumber: Int?
        var jsonSnippet: String?
        var hint: String?

        // Check for "Invalid JSON in configuration file" pattern
        if let fileRange = errorMessage.range(of: "Invalid JSON in configuration file ") {
            let afterFile = errorMessage[fileRange.upperBound...]
            if let colonIndex = afterFile.firstIndex(of: ":") {
                filePath = String(afterFile[..<colonIndex])
                let remainder = String(afterFile[afterFile.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                // Check for hint marker (with emoji from Config.swift)
                if let hintRange = remainder.range(of: "\n\n💡 Hint: ") {
                    hint = String(remainder[hintRange.upperBound...])
                    let beforeHint = String(remainder[..<hintRange.lowerBound])

                    // Check for JSON snippet marker in the part before hint
                    if let snippetRange = beforeHint.range(of: "\n\n📍") {
                        errorType = String(beforeHint[..<snippetRange.lowerBound])
                        jsonSnippet = String(beforeHint[snippetRange.lowerBound...])
                            .replacingOccurrences(of: "\n\n📍 ", with: "")
                    } else {
                        errorType = beforeHint
                    }
                } else if let snippetRange = remainder.range(of: "\n\n📍") {
                    // No hint, just snippet
                    errorType = String(remainder[..<snippetRange.lowerBound])
                    jsonSnippet = String(remainder[snippetRange.lowerBound...])
                        .replacingOccurrences(of: "\n\n📍 ", with: "")
                } else {
                    errorType = remainder
                }
            }
        }

        // Extract line number from error type (e.g., "(line 5)")
        if let lineRange = errorType.range(of: "\\(line \\d+\\)", options: .regularExpression) {
            let lineStr = errorType[lineRange]
            // Extract number from "(line X)"
            if let numRange = lineStr.range(of: "\\d+", options: .regularExpression) {
                lineNumber = Int(lineStr[numRange])
            }
            // Remove the line number part from error type
            errorType = errorType.replacingCharacters(in: lineRange, with: "").trimmingCharacters(in: .whitespaces)
        }

        // Extract details from error type (e.g., "at 'items.Index 0'")
        if let atRange = errorType.range(of: " at '") {
            details = String(errorType[atRange.upperBound...]).replacingOccurrences(of: "'", with: "")
            errorType = String(errorType[..<atRange.lowerBound])
        }

        return (filePath, errorType, details, lineNumber, jsonSnippet, hint)
    }

    var body: some View {
        let error = parsedError

        VStack(spacing: 16) {
            // Header
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Configuration Error")
                .font(.title2)
                .fontWeight(.semibold)

            // Structured error info
            VStack(alignment: .leading, spacing: 12) {
                // Error type (main message)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error.errorType)
                        .font(.body)
                        .fontWeight(.medium)
                }

                // Location/path details
                if let details = error.details {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Location:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(details)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }

                // File path with line number
                if let filePath = error.filePath {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("File:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let lineNum = error.lineNumber {
                                Text("\(filePath):\(lineNum)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(filePath)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // JSON snippet (if available)
                if let snippet = error.jsonSnippet {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(.orange)
                            Text(snippet.hasPrefix("Error location") ? "Error location:" : "Around error:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Extract just the code lines from snippet
                        let codeLines = snippet
                            .components(separatedBy: "\n")
                            .filter { $0.contains(":") && $0.trimmingCharacters(in: .whitespaces).first?.isNumber == true }
                            .joined(separator: "\n")

                        if !codeLines.isEmpty {
                            ScrollView {
                                Text(codeLines)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            }
                            .frame(maxHeight: 120)
                            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                            .clipShape(.rect(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }

                // Hint for fixing the error
                if let hint = error.hint {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text(hint)
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 6))
                }
            }
            .padding()
            .frame(maxWidth: 500)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(.rect(cornerRadius: 10))

            // Buttons
            HStack(spacing: 12) {
                Button {
                    copyErrorToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                }
                .buttonStyle(.bordered)

                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.bordered)

                Button("Quit") {
                    onQuit()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Wrapper for Preset3 to use InspectState

private struct Preset3Wrapper: View {
    @ObservedObject var coordinator: InspectState
    @StateObject private var inspectState = InspectState()

    var body: some View {
        Preset3View(inspectState: inspectState)
            .onAppear {
                // Sync initial state from coordinator
                inspectState.items = coordinator.items
                inspectState.config = coordinator.config
                inspectState.uiConfiguration = coordinator.uiConfiguration
                inspectState.backgroundConfiguration = coordinator.backgroundConfiguration
                inspectState.buttonConfiguration = coordinator.buttonConfiguration
                inspectState.completedItems = coordinator.completedItems
                inspectState.downloadingItems = coordinator.downloadingItems
            }
            .onReceive(coordinator.$completedItems) { items in
                inspectState.completedItems = items
            }
            .onReceive(coordinator.$downloadingItems) { items in
                inspectState.downloadingItems = items
            }
    }
}

// MARK: - Wrapper for Preset5 (Unified Portal)

private struct Preset5Wrapper: View {
    @ObservedObject var coordinator: InspectState

    var body: some View {
        Preset5View(inspectState: coordinator)
    }
}
