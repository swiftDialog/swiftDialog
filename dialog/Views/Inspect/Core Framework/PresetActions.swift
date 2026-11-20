//
//  PresetActions.swift
//  dialog
//
//  Behaviour shared by the presets: button and row actions, phase transitions, localization,
//  phase events.
//

import SwiftUI

// MARK: - Button Helpers

/// Runs the action of an inline button in guidance content. Every action is written to the
/// interaction log as `button:<itemId>:…`.
func handleButtonAction(block: InspectConfig.GuidanceContent, itemId: String, inspectState: some UserInputContext) {
    guard let action = block.action else {
        writeLog("Button clicked but no action defined", logLevel: .error)
        return
    }

    switch action {
    case "copy":
        let raw = block.value ?? block.content ?? ""
        let resolved = GuidanceTemplateResolver.resolve(
            raw, formInputs: inspectState.guidanceFormInputs)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resolved, forType: .string)
        writeLog("Button: copied \(resolved.count) chars to the pasteboard", logLevel: .info)
        inspectState.writeToInteractionLog("button:\(itemId):copy")

    case "url":
        if let urlString = block.url, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            writeLog("Button: Opened URL \(urlString)", logLevel: .info)
            inspectState.writeToInteractionLog("button:\(itemId):\(block.content ?? "button"):url:\(urlString)")
        } else {
            writeLog("Button: Invalid URL for action='url'", logLevel: .error)
        }

    case "app":
        // Launch an app by bundle path or bundle identifier; a custom URL scheme would be a
        // deeplink the app may reject.
        if let target = block.url {
            let url: URL? = target.hasPrefix("/")
                ? URL(fileURLWithPath: target)
                : NSWorkspace.shared.urlForApplication(withBundleIdentifier: target)
            if let url {
                // `open(_:)`, not `openApplication(at:)`: only `open` sends the reopen event that
                // makes a menu-bar app surface its window.
                NSWorkspace.shared.open(url)
                writeLog("Button: Launched app \(target)", logLevel: .info)
                inspectState.writeToInteractionLog("button:\(itemId):\(block.content ?? "button"):app:\(target)")
            } else {
                writeLog("Button: No application found for '\(target)' (action='app')", logLevel: .error)
            }
        } else {
            writeLog("Button: action='app' needs a bundle path or identifier in 'url'", logLevel: .error)
        }

    case "shell":
        // Not supported: logged and ignored.
        writeLog("Button: Shell action is not supported", logLevel: .info)
        inspectState.writeToInteractionLog("button:\(itemId):\(block.content ?? "button"):shell:NOT_SUPPORTED")

    case "minimize":
        minimizeDialogWindow()
        writeLog("Button: Minimized window for '\(block.content ?? "button")'", logLevel: .info)
        inspectState.writeToInteractionLog("button:\(itemId):\(block.content ?? "button"):minimize")

    case "custom":
        inspectState.writeToInteractionLog("button:\(itemId):\(block.content ?? "button"):custom")
        writeLog("Button: Custom action triggered for '\(block.content ?? "button")'", logLevel: .info)
        DialogNotifications.postButtonClick(
            stepId: itemId, label: block.content ?? "button", action: "custom"
        )

    case "request":
        // Script callback: `request:<requestId>:<itemId>:<badgeIndex>` to the interaction log,
        // and to `actionPipe` when configured.
        let requestId = block.requestId ?? "unknown"
        let badgeIndex = block.targetBadge?.blockIndex ?? 0
        let requestLine = "request:\(requestId):\(itemId):\(badgeIndex)"

        inspectState.writeToInteractionLog(requestLine)

        if let pipePath = inspectState.config?.actionPipe {
            writeToPipeIfExists(path: pipePath, content: requestLine)
        }

        writeLog("Button: Request '\(requestId)' sent for item '\(itemId)'", logLevel: .info)

    case "generate":
        let presetId = block.requestId ?? "5"
        StarterTemplateService.generateStarter(forPreset: presetId)
        writeLog("Button: Generated starter for preset \(presetId)", logLevel: .info)

    default:
        writeLog("Button: Unknown action '\(action)'", logLevel: .error)
    }
}

/// Runs a detail-row action (type="detail-rows"): "url", "app", "request", or a custom word
/// written to the interaction log as `row:<itemId>:<label>:<action>`.
func handleRowAction(action: String?, url: String?, requestId: String? = nil, label: String, itemId: String, inspectState: some UserInputContext) {
    guard let action = action else { return }
    switch action {
    case "url":
        if let urlString = url, let u = URL(string: urlString) {
            NSWorkspace.shared.open(u)
            inspectState.writeToInteractionLog("row:\(itemId):\(label):url:\(urlString)")
            writeLog("Detail-row: Opened URL \(urlString)", logLevel: .info)
        } else {
            writeLog("Detail-row: Invalid URL for action='url'", logLevel: .error)
        }
    case "app":
        // Same launch semantics as the block-level action:"app".
        if let target = url, !target.isEmpty {
            let appURL: URL? = target.hasPrefix("/")
                ? URL(fileURLWithPath: target)
                : NSWorkspace.shared.urlForApplication(withBundleIdentifier: target)
            if let appURL {
                NSWorkspace.shared.open(appURL)
                inspectState.writeToInteractionLog("row:\(itemId):\(label):app:\(target)")
                writeLog("Detail-row: Launched app \(target)", logLevel: .info)
            } else {
                writeLog("Detail-row: No application found for '\(target)' (action='app')", logLevel: .error)
            }
        } else {
            writeLog("Detail-row: action='app' needs a bundle path or identifier", logLevel: .error)
        }

    case "request":
        let rid = requestId ?? "unknown"
        let line = "request:\(rid):\(itemId):0"
        inspectState.writeToInteractionLog(line)
        if let pipePath = inspectState.config?.actionPipe {
            writeToPipeIfExists(path: pipePath, content: line)
        }
        writeLog("Detail-row: Request '\(rid)' sent for item '\(itemId)'", logLevel: .info)
    default:
        inspectState.writeToInteractionLog("row:\(itemId):\(label):\(action)")
        writeLog("Detail-row: '\(action)' action for '\(label)'", logLevel: .info)
    }
}

// MARK: - Phase Machinery

/// The bottom brand logo across the intro/main/summary phases, gated per phase by
/// `LogoConfig.showOnIntro/Main/Summary`. Sits on the footer button baseline.
struct PhaseLogoOverlay: View {
    let logoConfig: InspectConfig.LogoConfig?
    let basePath: String?
    let phase: PresetPhase
    let scaleFactor: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let logoConfig {
            let visible: Bool = switch phase {
            case .intro:   logoConfig.showOnIntro ?? true
            case .main:    logoConfig.showOnMain ?? true
            case .summary: logoConfig.showOnSummary ?? true
            }
            if visible {
                BrandMark(
                    path: BrandArtwork.resolve(logoConfig, isDark: colorScheme == .dark) ?? logoConfig.imagePath,
                    box: BrandMarkBox.fit(authored: logoConfig.maxHeight.map { $0 * (logoConfig.scale ?? 1.0) },
                                          default: 40 * CGFloat(logoConfig.scale ?? 1.0)),
                    basePath: basePath,
                    clearSpace: logoConfig.clearSpace,
                    opacity: logoConfig.opacity ?? 0.6
                )
                .allowsHitTesting(false)
                .padding(.bottom, InspectConstants.spacingSection * scaleFactor)
                .transaction { $0.animation = nil }
            }
        }
    }
}

/// Moves main → summary when every tracked item completes, unless `summaryScreen.autoTransition`
/// is false. The main phase stays at least 2.5 s so an already-complete list is not flashed past.
@MainActor
func phaseAutoTransitionToSummary(state: InspectState, currentPhase: Binding<PresetPhase>, mainAppearedAt: Date?) {
    guard currentPhase.wrappedValue == .main,
          let summaryConfig = state.config?.summaryScreen,
          summaryConfig.autoTransition != false,
          !state.trackedItems.isEmpty,
          state.trackedCompletedCount == state.trackedItems.count else { return }
    let minimumDisplay: TimeInterval = 2.5
    let elapsed = mainAppearedAt.map { Date().timeIntervalSince($0) } ?? minimumDisplay
    if elapsed < minimumDisplay {
        DispatchQueue.main.asyncAfter(deadline: .now() + (minimumDisplay - elapsed)) {
            if currentPhase.wrappedValue == .main,
               state.trackedCompletedCount == state.trackedItems.count {
                currentPhase.wrappedValue = .summary
            }
        }
    } else {
        currentPhase.wrappedValue = .summary
    }
}

/// Button1 action when a `summaryScreen` is configured: show the summary instead of exiting.
/// nil without one; the caller then exits as usual.
@MainActor
func summaryTransitionAction(state: InspectState, currentPhase: Binding<PresetPhase>) -> (() -> Void)? {
    guard state.config?.summaryScreen != nil else { return nil }
    return {
        withAnimation(InspectConstants.stepTransition) {
            currentPhase.wrappedValue = .summary
        }
    }
}

// MARK: - Preset Localization

/// The localization helpers the item presets share: effective language, localized string and
/// array, side message, item status.
@MainActor
struct PresetLocalization {
    let state: InspectState
    let service: LocalizationService

    var effectiveLanguage: String? {
        guard let locConfig = state.config?.localization else { return nil }
        return service.resolveDefaultLanguage(from: locConfig)
    }

    /// A localized string, or `fallback`.
    func string(_ key: String, fallback: String?) -> String? {
        guard let lang = effectiveLanguage else { return fallback }
        return service.string(forLanguage: lang, key: key) ?? fallback
    }

    /// A localized string array, or `fallback`.
    func array(_ key: String, fallback: [String]?) -> [String]? {
        guard let lang = effectiveLanguage else { return fallback }
        return service.stringArray(forLanguage: lang, key: key) ?? fallback
    }

    /// The current side message, localized.
    /// Every rotating line, localized; the seat for the current one is sized from these.
    func sideMessages() -> [String] {
        array("sideMessages", fallback: state.uiConfiguration.sideMessages) ?? state.uiConfiguration.sideMessages
    }

    func sideMessage() -> String? {
        let messages = sideMessages()
        guard !messages.isEmpty else { return nil }
        let index = min(state.uiConfiguration.currentSideMessageIndex, messages.count - 1)
        return messages[index]
    }

    /// A localized item status: item-specific key, then global key, then `baseStatus`.
    func itemStatus(for item: InspectConfig.ItemConfig, baseStatus: String) -> String {
        guard effectiveLanguage != nil else { return baseStatus }
        // A script's own text is not a status word to translate.
        if state.itemStatusText[item.id] != nil { return baseStatus }
        if state.completedItems.contains(item.id) {
            return string("\(item.id).completedStatus", fallback: nil)
                ?? string("completedStatus", fallback: nil)
                ?? baseStatus
        } else if state.downloadingItems.contains(item.id) {
            return string("\(item.id).downloadingStatus", fallback: nil)
                ?? string("downloadingStatus", fallback: nil)
                ?? baseStatus
        } else if state.failedItems.contains(item.id) {
            return string("\(item.id).failedStatus", fallback: nil)
                ?? string("failedStatus", fallback: nil)
                ?? baseStatus
        } else {
            return string("\(item.id).pendingStatus", fallback: nil)
                ?? string("pendingStatus", fallback: nil)
                ?? baseStatus
        }
    }
}

/// Appends a `phase_changed` event to the JSONL event file: `config.eventFile`, else the
/// readiness file with a `.events` extension.
func writePhaseEvent(_ phase: PresetPhase, config: InspectConfig?, presetLabel: String) {
    let eventPath: String? = config?.eventFile ?? config?.readinessFile.map {
        (($0 as NSString).deletingPathExtension) + ".events"
    }
    guard let path = eventPath else { return }

    let entry: [String: Any] = [
        "event": "phase_changed",
        "phase": "\(phase)",
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: entry),
          let line = String(data: data, encoding: .utf8) else { return }

    let expandedPath = (path as NSString).expandingTildeInPath
    let lineData = (line + "\n").data(using: .utf8)!
    if let handle = FileHandle(forWritingAtPath: expandedPath) {
        handle.seekToEndOfFile()
        handle.write(lineData)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: expandedPath, contents: lineData)
    }
    writeLog("\(presetLabel): Phase event emitted — \(phase)", logLevel: .info)
}

/// Writes `content` plus a newline to the FIFO at `path`, if one exists.
private func writeToPipeIfExists(path: String, content: String) {
    var statInfo = stat()
    guard stat(path, &statInfo) == 0,
          (statInfo.st_mode & S_IFMT) == S_IFIFO else {
        writeLog("FIFO not found or not a pipe: \(path)", logLevel: .debug)
        return
    }

    // Off the main thread: opening a FIFO blocks until a reader is waiting.
    DispatchQueue.global(qos: .userInitiated).async {
        guard let handle = FileHandle(forWritingAtPath: path) else {
            writeLog("FIFO: Could not open for writing: \(path)", logLevel: .error)
            return
        }
        defer { handle.closeFile() }

        let data = (content + "\n").data(using: .utf8)!
        handle.write(data)
        writeLog("FIFO: Wrote request to \(path)", logLevel: .debug)
    }
}


// MARK: - Observe-Only Helpers

/// Whether an item is observe-only: `item.observeOnly`, else `config.observeOnly`, else false.
func isItemObserveOnly(_ item: InspectConfig.ItemConfig?, config: InspectConfig?) -> Bool {
    item?.observeOnly ?? config?.observeOnly ?? false
}

/// The same cascade for a step.
func isItemObserveOnly(_ step: InspectConfig.IntroStep?, config: InspectConfig?) -> Bool {
    step?.observeOnly ?? config?.observeOnly ?? false
}

func isGlobalObserveOnly(config: InspectConfig?) -> Bool {
    config?.observeOnly ?? false
}


// MARK: - Button Helper Functions

/// The guidance button styles and their authored spellings. `prominent` is a synonym of
/// `borderedProminent`; an unknown or absent spelling is `.bordered`.
enum GuidanceButtonStyle: String, CaseIterable {
    case bordered
    case borderedProminent
    case plain
    case link

    static let synonyms: [GuidanceButtonStyle: Set<String>] = [
        .bordered: ["bordered"],
        .borderedProminent: ["borderedprominent", "prominent"],
        .plain: ["plain"],
        .link: ["link"]
    ]

    init(lenient raw: String?) {
        guard let key = raw?.trimmingCharacters(in: .whitespaces).lowercased(), !key.isEmpty else {
            self = .bordered
            return
        }
        for (style, spellings) in Self.synonyms where spellings.contains(key) {
            self = style
            return
        }
        self = .bordered
    }
}

/// Applies the SwiftUI button style named by `styleString`. Main actor: the `ButtonStyle` statics are.
@MainActor
@ViewBuilder
func applyButtonStyle(_ button: some View, styleString: String?) -> some View {
    switch GuidanceButtonStyle(lenient: styleString) {
    case .borderedProminent:
        button.buttonStyle(.borderedProminent)
    case .plain:
        button.buttonStyle(.plain)
    case .link:
        button.buttonStyle(.link)
    case .bordered:
        button.buttonStyle(.bordered)
    }
}


// MARK: - Help Button Action Handler

/// Runs the help button's action: "url", "custom" (writes `helpbutton:custom:<id>` to the
/// interaction log), or "overlay" (the default).
func handleHelpButtonAction(
    config: InspectConfig.HelpButtonConfig,
    showOverlay: Binding<Bool>? = nil,
    interactionLogPath: String = "/var/tmp/dialog-inspect-interactions.log"
) {
    let actionType = config.action ?? "overlay"

    switch actionType {
    case "url":
        if let urlString = config.url, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            writeLog("HelpButton: Opened URL: \(urlString)", logLevel: .info)
        } else {
            writeLog("HelpButton: Invalid or missing URL for action 'url'", logLevel: .error)
        }

    case "custom":
        let customId = config.customId ?? config.label ?? "help"
        let message = "helpbutton:custom:\(customId)"
        if let data = (message + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: interactionLogPath) {
                if let handle = FileHandle(forWritingAtPath: interactionLogPath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: interactionLogPath, contents: data, attributes: nil)
            }
        }
        writeLog("HelpButton: Custom action triggered: \(customId)", logLevel: .info)

    case "overlay", _:
        writeLog("HelpButton: opening the help overlay", logLevel: .info)
        showOverlay?.wrappedValue = true
    }
}


