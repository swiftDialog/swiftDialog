//
//  Preset5+CadenceRuntime.swift
//  dialog
//
//  Cadence step runtime: monitor start, brand colour, localized messages, completion copy,
//  auto-advance and the confirm-on-incomplete exit. Kept out of layout files so removing a layout
//  cannot remove the runtime; the provisioning shell draws the screen.
//

import SwiftUI

/// The running/complete copy swap and auto-advance rule, shared by every cadence screen.
enum CadenceCopy {

    /// Success, unless entries failed; then a warning with the count, so `processingResult_<step>`
    /// and the result file are accurate.
    static func completionResult(message: String?, failed: Int, total: Int) -> InspectCompletionResult {
        guard failed > 0 else { return .success(message: message) }
        return .warning(message: "\(failed) of \(total) did not finish")
    }

    /// The shared rule: completed copy once complete, else running copy.
    static func resolvedCopy(isComplete: Bool, running: String?, completed: String?) -> String? {
        guard isComplete, let completed, !completed.isEmpty else { return running }
        return completed
    }

    static func resolvedTitle(isComplete: Bool, title: String, completedTitle: String?) -> String {
        resolvedCopy(isComplete: isComplete, running: title, completed: completedTitle) ?? title
    }

    /// The claim narrates the active entry, so once the run completes it is replaced by the completed
    /// message or left blank. Subtitles use `resolvedSubtitle` instead.
    static func resolvedClaim(isComplete: Bool, runningClaim: String, completedMessage: String?) -> String {
        if isComplete {
            guard let completedMessage, !completedMessage.isEmpty else { return " " }
            return completedMessage
        }
        return runningClaim
    }

    /// A subtitle is standing copy, so without a `completedMessage` it stays as authored after the run.
    static func resolvedSubtitle(isComplete: Bool, subtitle: String?, completedMessage: String?) -> String? {
        resolvedCopy(isComplete: isComplete, running: subtitle, completed: completedMessage)
    }

    /// Whether a finished run advances itself: yes unless the step sets `autoAdvance: false`.
    static func shouldAutoAdvance(autoAdvance: Bool?) -> Bool {
        autoAdvance != false
    }

    /// Hold before advancing when the step authors completion copy, so it can be read; otherwise 0.8 s.
    static let completionHold: Double = 2.0
    static let defaultHold: Double = 0.8
}

/// What the primary button does while a run is in progress.
enum CadenceContinueVisibility {
    case live, hidden, disabled

    /// A finished run always shows a live Continue; the authored value applies only while running.
    static func resolve(_ raw: String?, running: Bool) -> CadenceContinueVisibility {
        guard running else { return .live }
        switch raw?.lowercased() {
        case "hidden": return .hidden
        case "disabled": return .disabled
        default: return .live
        }
    }
}

extension Preset5View {

    /// Dark-aware brand colour from a managed preference (`brandColorRef`); nil when unset,
    /// and callers fall back to `branding.primaryColor`.
    func cadenceBrandColor(step: InspectConfig.IntroStep) -> Color? {
        step.brandColorRef.flatMap {
            CadenceMonitorService.resolveColor(from: $0, dark: colorScheme == .dark)
        }.map { Color(hex: $0) }
    }

    /// Starts, or fast-replays, the cadence for this step. `isReplay` must be read before `start()`,
    /// which resets `isComplete`; a Back return replays without auto-advancing.
    func startCadenceStep(step: InspectConfig.IntroStep) {
        let isReplay = cadenceMonitor.isComplete
        cadenceMonitor.start(step: step, replay: isReplay, entries: derivedCadenceEntries(for: step),
                             include: { cadenceEntryIsShown($0, in: step) },
                             adjust: { cadenceEntryArtwork($0, in: step) }) { [self] triggerStepId, triggerResult in
            let completionResult: CompletionResult
            switch triggerResult {
            case .success(let message):
                completionResult = CadenceCopy.completionResult(message: message,
                                                                failed: cadenceMonitor.failedIndices.count,
                                                                total: cadenceMonitor.entries.count)
            case .failure(let message): completionResult = .failure(message: message)
            }
            recordCadenceOutcome(stepId: step.id)
            handleCompletionTrigger(stepId: triggerStepId, result: completionResult)
            guard !isReplay,
                  CadenceCopy.shouldAutoAdvance(autoAdvance: step.autoAdvance),
                  step.requireManualConfirm != true else { return }
            let authorsCompletionCopy = (step.completedTitle?.isEmpty == false)
                || (step.completedMessage?.isEmpty == false)
            scheduleAutoAdvance(after: authorsCompletionCopy ? CadenceCopy.completionHold
                                                            : CadenceCopy.defaultHold,
                                from: step.id)
        }
    }

    /// Message for the active entry: live `cadence:message:<index>:<text>` override, then sidecar key
    /// `{stepId}.cadence.{entryId}.message` (entry ids are stable across reorders), then the authored message.
    func localizedCadenceMessage(step: InspectConfig.IntroStep) -> String? {
        if let override = cadenceMonitor.messageOverride[cadenceMonitor.currentIndex] { return override }
        guard let entry = cadenceMonitor.currentEntry ?? cadenceDisplayEntries(for: step).first else { return nil }
        return localized("cadence.\(entry.id).message", forStep: step, fallback: entry.message)
    }

    /// Entries to show before `start()` runs, resolved as `start()` will (a loadable `cadenceRef` wins
    /// over the inline array) so the first frame does not swap.
    func cadenceDisplayEntries(for step: InspectConfig.IntroStep) -> [InspectConfig.CadenceEntry] {
        cadenceMonitor.entries.isEmpty
            ? (CadenceMonitorService.resolveEntriesForDisplay(step: step, entries: derivedCadenceEntries(for: step),
                                                              include: { cadenceEntryIsShown($0, in: step) },
                                                              adjust: { cadenceEntryArtwork($0, in: step) }) ?? [])
            : cadenceMonitor.entries
    }

    /// An entry's artwork. With `cadenceSelectionKey` the entry borrows the icon of the option card
    /// with the same id; the entry's own `imagePath` wins.
    func cadenceEntryArtwork(_ entry: InspectConfig.CadenceEntry, in step: InspectConfig.IntroStep) -> InspectConfig.CadenceEntry {
        guard entry.imagePath?.isEmpty != false, let key = step.cadenceSelectionKey,
              let icon = multiOptionCards(forKey: key)?
                  .first(where: { ($0.value ?? $0.cardId) == entry.id })?.iconPath,
              !icon.isEmpty else { return entry }
        return entry.withImagePath(icon)
    }

    /// A progress step without entries that follows a multi-select chooser (`cadenceSelectionKey` or the
    /// only chooser) runs the chooser's plan (`OptionPlan.cadenceEntries`). nil otherwise.
    func derivedCadenceEntries(for step: InspectConfig.IntroStep) -> [InspectConfig.CadenceEntry]? {
        guard (step.cadenceEntries ?? []).isEmpty, step.cadenceRef == nil,
              let key = OptionPlan.followedKey(explicit: step.cadenceSelectionKey, in: allSteps),
              let cards = multiOptionCards(forKey: key) else { return nil }
        let run = (inspectState.userValues[OptionPlan.runKey(key)] ?? "")
            .split(separator: ",").map(String.init)
        return OptionPlan.cadenceEntries(cards: cards, run: run,
                                         minDwell: step.cadenceMinDwell, timeout: step.cadenceTimeout)
    }

    func cadenceEntryIsShown(_ entry: InspectConfig.CadenceEntry, in step: InspectConfig.IntroStep) -> Bool {
        if let key = step.cadenceSelectionKey {
            let run = Set((inspectState.userValues[OptionPlan.runKey(key)] ?? "").split(separator: ",").map(String.init))
            guard run.contains(entry.id) else { return false }
        }
        return entry.showWhen?.matches(inspectState.userValues) ?? true
    }

    /// Measured duration of a finished run, for the recap's summary strip.
    func formattedCadenceDuration() -> String? {
        CadenceTokens.duration(cadenceMonitor, languageCode: selectedLanguageCode)
    }

    /// Substitutes `{cadence.*}` tokens in a guidance block so later copy can describe the run.
    func resolvedCadenceTokens(_ block: InspectConfig.GuidanceContent) -> InspectConfig.GuidanceContent {
        CadenceTokens.resolve(block, monitor: cadenceMonitor, languageCode: selectedLanguageCode)
    }

    @ViewBuilder
    /// Confirmation raised by `continueOrConfirm` when the user leaves an unfinished run.
    func confirmIncompleteSheet(step: InspectConfig.IntroStep,
                                remaining: Int, total: Int) -> some View {
        let message = (localized("ui.notFinishedMessage", forStep: step,
                                 fallback: "{remaining} of {total} are still installing. You can keep waiting or continue anyway.")
                       ?? "")
            .replacingOccurrences(of: "{remaining}", with: "\(remaining)")
            .replacingOccurrences(of: "{total}", with: "\(total)")
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(palette.warning)
                Text(localized("ui.notFinishedTitle", forStep: step,
                               fallback: "Not finished yet") ?? "Not finished yet")
                    .font(.system(size: 18, weight: .semibold))
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            Divider()

            VStack(spacing: 12) {
                Button {
                    confirmIncompleteStepId = nil
                } label: {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(palette.success)
                        Text(localized("ui.keepWaiting", forStep: step,
                                       fallback: "Keep Waiting") ?? "Keep Waiting")
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(palette.successBackground)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localized("ui.keepWaiting", forStep: step,
                                              fallback: "Keep Waiting") ?? "Keep Waiting")

                Button {
                    confirmIncompleteStepId = nil
                    writeLog("Preset5: user continued past unfinished step '\(step.id)' (\(remaining) of \(total) pending)", logLevel: .info)
                    goToNextStep()
                } label: {
                    HStack {
                        Image(systemName: "forward.fill")
                            .foregroundStyle(palette.warning)
                        Text(localized("ui.continueAnyway", forStep: step,
                                       fallback: ChromeCopy.continueAnyway) ?? ChromeCopy.continueAnyway)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(palette.warningBackground)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localized("ui.continueAnyway", forStep: step,
                                              fallback: ChromeCopy.continueAnyway) ?? ChromeCopy.continueAnyway)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 380)
    }

    /// Records `<step>.done` / `<step>.failed` (comma-joined, run order), which later steps read.
    /// Written when the run completes and again when the user leaves early.
    func recordCadenceOutcome(stepId: String) {
        let outcome = cadenceMonitor.outcome
        StepOutcome.record(into: &inspectState.userValues, scope: stepId,
                           done: outcome.done, failed: outcome.failed)
    }

    /// Continue on an unfinished run asks first, unless the step opts out.
    func continueOrConfirm(step: InspectConfig.IntroStep, remaining: Int) {
        if remaining > 0 && step.confirmIncomplete != false {
            confirmIncompleteStepId = step.id
        } else {
            goToNextStep()
        }
    }
}

extension Preset5View {

    @ViewBuilder
    func cadenceRecapView() -> some View {
        if let model = cadenceRecapModel() { CadenceRecapView(model: model) }
    }

    /// Built from measured facts only: entry count, the monitor's timed-out set, wall-clock duration.
    func cadenceRecapModel() -> CardRecapModel? {
        guard cadenceMonitor.isComplete,
              let cadenceStep = allSteps.first(where: { $0.stepType == "cadence" }) else { return nil }
        let entries = cadenceDisplayEntries(for: cadenceStep)
        guard !entries.isEmpty else { return nil }
        let timedOut = cadenceMonitor.timedOutIndices
        let clean = timedOut.isEmpty
        let total = entries.count
        let proven = CardRecapModel.satisfiedCount(total: total, timedOut: timedOut)
        let passed = clean
            ? localizedUI("ui.cadenceRecapPassed", fallback: "All {total} checks passed")
                .replacingOccurrences(of: "{total}", with: "\(total)")
            : (localized("ui.stillFinishing", forStep: cadenceStep,
                         fallback: "· {n} still finishing") ?? "")
                .replacingOccurrences(of: "{n}", with: "\(timedOut.count)")
                .replacingOccurrences(of: "· ", with: "\(proven) of \(total) checks passed · ")
        return CardRecapModel(
            tiles: entries.map { entry in
                CadenceRecapTile(
                    id: entry.id,
                    label: localized("cadence.\(entry.id).label", forStep: cadenceStep,
                                     fallback: entry.label) ?? entry.id,
                    subtitle: localized("cadence.\(entry.id).subtitle", forStep: cadenceStep,
                                        fallback: entry.subtitle),
                    imagePath: entry.imagePath,
                    sfSymbol: entry.sfSymbol)
            },
            // Uses the monitor's real timed-out set so unproven entries get no proven mark.
            satisfiedCount: proven,
            position: total,
            timedOut: timedOut,
            accent: cadenceBrandColor(step: cadenceStep) ?? branding.primaryColor,
            basePath: effectiveIconBasePath,
            summary: CardRecapModel.segments(
                passed: passed,
                duration: formattedCadenceDuration(),
                closing: localizedUI("ui.cadenceRecapNothingElse", fallback: "nothing else to do"),
                clean: clean),
            clean: clean)
    }
}
