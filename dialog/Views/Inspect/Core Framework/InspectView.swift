//
//  InspectView.swift
//  dialog
//
//  Root view of inspect mode: routes to a preset on `InspectState`, with the loading and error
//  screens.
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
                            writeLog("InspectViewServiceBased: Loading state - using new coordinator", logLevel: .debug)
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
                    writeLog("InspectViewServiceBased: Failed state - \(errorMessage)", logLevel: .error)
                }

            case .loaded:
                presetView(for: inspectState.uiConfiguration.preset)
                    // Injected above the preset switch so `buttonShape` reaches every preset.
                    .environment(\.inspectButtonShape,
                                 InspectButtonShape(inspectState.config?.buttonShape))
                    .environment(\.inspectGlow, InspectGlow(inspectState.config?.glow))
                    .onAppear {
                        if appvars.debugMode {
                            writeLog("InspectViewServiceBased: Loading preset '\(inspectState.uiConfiguration.preset)' with new coordinator", logLevel: .debug)
                        }
                    }
                    // Provenance chip for the `--debug` CLI flag (`appvars.debugMode`, not a config
                    // key), seated here so it shows on every preset.
                    .overlay(alignment: .bottomLeading) {
                        if appvars.debugMode {
                            DebugConfigChip(path: inspectState.configPath)
                        }
                    }
            }
        }
        .onAppear {
            if appvars.debugMode {
                writeLog("InspectViewServiceBased: Starting with service-based architecture", logLevel: .debug)
            }
            writeLog("InspectViewServiceBased: Initializing with InspectState", logLevel: .info)
            inspectState.initialize()
            // `--blurscreen` covers only the dialog's display in inspect mode.
            InspectBlurScope.confineToDialogScreen()
        }
    }

    // MARK: - Helper Methods

    /// The preset view for a name; every spelling lives in `InspectPresetName`.
    @ViewBuilder
    private func presetView(for presetName: String) -> some View {
        switch InspectPresetName.number(presetName) {
        case 1:
            Preset1View(inspectState: inspectState)
        case 2:
            Preset2View(inspectState: inspectState)
        case 3:
            Preset3View(inspectState: inspectState)
        case 4:
            Preset4Wrapper(coordinator: inspectState)
        case 5, 7:
            // Guided Setup (7) runs on the Preset 5 step engine.
            Preset5Wrapper(coordinator: inspectState)
        case 6:
            Preset6Wrapper(coordinator: inspectState)
        default:
            Preset1View(inspectState: inspectState)
                .onAppear {
                    writeLog("InspectViewServiceBased: Unknown preset '\(presetName)', using default", logLevel: .info)
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
    @Environment(\.palette) private var palette

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

    // swiftlint:disable:next large_tuple
    /// Parse the error message into file path, type, details, line number, JSON snippet and hint.
    private var parsedError: (filePath: String?, errorType: String, details: String?, lineNumber: Int?, jsonSnippet: String?, hint: String?) {
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

                // The hint and snippet markers are the ones Config.swift writes.
                if let hintRange = remainder.range(of: "\n\n💡 Hint: ") {
                    hint = String(remainder[hintRange.upperBound...])
                    let beforeHint = String(remainder[..<hintRange.lowerBound])

                    if let snippetRange = beforeHint.range(of: "\n\n📍") {
                        errorType = String(beforeHint[..<snippetRange.lowerBound])
                        jsonSnippet = String(beforeHint[snippetRange.lowerBound...])
                            .replacingOccurrences(of: "\n\n📍 ", with: "")
                    } else {
                        errorType = beforeHint
                    }
                } else if let snippetRange = remainder.range(of: "\n\n📍") {
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
            if let numRange = lineStr.range(of: "\\d+", options: .regularExpression) {
                lineNumber = Int(lineStr[numRange])
            }
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
                .foregroundStyle(palette.warning)

            Text("Configuration Error")
                .font(.title2)
                .fontWeight(.semibold)

            // Structured error info
            VStack(alignment: .leading, spacing: 12) {
                // Error type (main message)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.error)
                    Text(error.errorType)
                        .font(.body)
                        .fontWeight(.medium)
                }

                // Location/path details
                if let details = error.details {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(palette.info)
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
                                .foregroundStyle(palette.warning)
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
                                    .stroke(palette.warning.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }

                // Hint for fixing the error
                if let hint = error.hint {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(palette.warning)
                        Text(hint)
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.warning.opacity(0.1))
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

// MARK: - Wrapper for Preset5 (Unified Portal)

private struct Preset5Wrapper: View {
    @ObservedObject var coordinator: InspectState

    var body: some View {
        Preset5View(inspectState: coordinator)
    }
}

/// `--debug`'s provenance chip: the running config's file name, directory, copy and reveal
/// buttons. Outside the palette system because it never renders for an end user.
private struct DebugConfigChip: View {
    let path: String?
    @State private var copied = false

    var body: some View {
        if let path, !path.isEmpty {
            HStack(spacing: 8) {
                Text((path as NSString).lastPathComponent)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text((path as NSString).deletingLastPathComponent)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: 220, alignment: .trailing)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 14, height: 14)   // constant box — the icon swap never reflows the chip
                }
                .buttonStyle(.plain)
                .help("Copy config path")
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 9)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(10)
        }
    }
}
