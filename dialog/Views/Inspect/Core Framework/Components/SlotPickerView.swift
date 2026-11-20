//
//  SlotPickerView.swift
//  dialog
//
//  `slot-picker`: a continuous strip up to a deadline for choosing an install time. Arithmetic
//  lives in `SlotPickerLogic.swift`; this view draws, formats for the locale, and records the
//  answer the way the option picker does, pre-selection included.
//

import SwiftUI

struct SlotPickerView<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat

    @Environment(\.inspectLocalization) private var l10n

    /// The deadline tick reads the palette's `warning` slot so a branded warning colour carries.
    @Environment(\.palette) private var palette

    /// Selection key shared with the other pickers' fallback convention.
    private var resolvedKey: (key: String, usedFallback: Bool) {
        SelectionEmission.resolveKey(block.id, fallback: "slot")
    }
    private var selectionKey: String { resolvedKey.key }

    /// A fixed reference for the screen's lifetime, not a ticking clock. `onAppear` floors it to
    /// the granularity grid before anything reads it, so clock-aligned authored instants snap to
    /// themselves.
    @State private var now = Date()
    @State private var chosen: Date = Date()
    @State private var resolvedQuickPicks: [ResolvedPick] = []
    @State private var didInit = false

    private struct ResolvedPick: Identifiable {
        let id = UUID()
        let label: String
        let at: Date
    }

    private var amber: Color { palette.warning }
    private var resolvedAccent: Color { accentColor ?? .accentColor }

    private var windowHours: Int { block.windowHours ?? 24 }
    private var granularityMinutes: Int { block.granularityMinutes ?? 15 }

    private var deadlineDate: Date? {
        guard let raw = block.deadline else { return nil }
        return SlotPicker.isoDate(raw)
    }

    /// An unparseable or past deadline means the block does not render at all.
    private var isValid: Bool {
        guard let deadlineDate else { return false }
        return !(deadlineDate < now)   // not <= / >= on Date (see SlotPickerCopy.resolve)
    }

    var body: some View {
        Group {
            if isValid, let deadlineDate {
                content(deadline: deadlineDate)
            } else {
                GuidanceDebugHint(
                    message: "slot-picker requires a parseable 'deadline' at or after now",
                    scaleFactor: scaleFactor
                )
            }
        }
        .onAppear {
            guard !didInit else { return }
            didInit = true
            if resolvedKey.usedFallback {
                writeLog(
                    "SlotPickerView: no 'id' authored — defaulting the selection key to 'slot'. " +
                    "Two id-less slot-pickers on the same step will silently share (and overwrite) " +
                    "one answer; author distinct 'id's to avoid it.",
                    logLevel: .error
                )
            }
            // Floor before the validity check and every downstream read. Unclamped on purpose:
            // `granularityMinutes: 0` means no snapping, and `snap` treats it the same way.
            now = SlotPicker.floorToGranularity(now, granularityMinutes: granularityMinutes)
            guard let deadlineDate, isValid else {
                writeLog(
                    "SlotPickerView: id='\(block.id ?? "nil")' deadline missing, unparseable, or " +
                    "before now ('\(block.deadline ?? "nil")') — block will not render",
                    logLevel: .error
                )
                return
            }
            initializeAndRecord(deadline: deadlineDate)
        }
    }

    // MARK: - Setup (onAppear only)

    /// Resolves quick-picks, dropping unparseable ones. A restored answer wins, re-snapped against
    /// the current deadline and re-emitted only if that changed it; otherwise the opening value
    /// (`defaultAt`, first quick-pick, `now`) is recorded at once, since a pre-selection is an answer.
    private func initializeAndRecord(deadline: Date) {
        var picks: [ResolvedPick] = []
        for pick in block.quickPicks ?? [] {
            guard let resolved = SlotPicker.resolve(pick.at, now: now, deadline: deadline) else {
                writeLog(
                    "SlotPickerView: quickPick '\(pick.label)' has unparseable at='\(pick.at)' — dropped",
                    logLevel: .error
                )
                continue
            }
            let snapped = SlotPicker.snap(resolved, start: now, deadline: deadline,
                                          granularityMinutes: granularityMinutes)
            picks.append(ResolvedPick(label: pick.label, at: snapped))
        }
        resolvedQuickPicks = picks

        if let existingRaw = inspectState.userValues[selectionKey], !existingRaw.isEmpty,
           let existing = SlotPicker.isoDate(existingRaw) {
            let snappedExisting = SlotPicker.snap(existing, start: now, deadline: deadline,
                                                  granularityMinutes: granularityMinutes)
            if abs(snappedExisting.timeIntervalSince(existing)) > 0.001 {
                record(snappedExisting)   // the stored value no longer fits
            } else {
                chosen = snappedExisting
            }
            return
        }

        let openingRaw: Date
        if let defaultAt = block.defaultAt,
           let resolved = SlotPicker.resolve(defaultAt, now: now, deadline: deadline) {
            openingRaw = resolved
        } else if let first = picks.first {
            openingRaw = first.at
        } else {
            openingRaw = now
        }
        let opening = SlotPicker.snap(openingRaw, start: now, deadline: deadline,
                                      granularityMinutes: granularityMinutes)
        record(opening)
    }

    /// Move the handle, then emit only if `SelectionEmission` says this is an answer: `userValues`,
    /// the `select:` log line, the selection notification. The wire value is always ISO-8601.
    private func record(_ date: Date, trigger: SelectionEmission.Trigger = .committed) {
        chosen = date
        let iso = SlotPicker.isoString(date)
        guard SelectionEmission.shouldEmit(newValue: iso,
                                           recorded: inspectState.userValues[selectionKey],
                                           trigger: trigger) else { return }
        inspectState.userValues[selectionKey] = iso
        inspectState.writeToInteractionLog("select:\(selectionKey):\(iso)")
        DialogNotifications.postSelection(key: selectionKey, values: [iso])
    }

    // MARK: - Anatomy

    @ViewBuilder
    private func content(deadline: Date) -> some View {
        VStack(alignment: .leading, spacing: 14 * scaleFactor) {
            readout
            track(deadline: deadline)
            scaleLabels(deadline: deadline)
            if let note = block.deadlineNote, !note.isEmpty {
                Text(note)
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !resolvedQuickPicks.isEmpty {
                quickPickChips
            }
            if let facts = block.facts, !facts.isEmpty {
                Divider().opacity(0.5)
                factsTable(facts)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Chosen-slot readout: label, formatted instant, exposure hours, hairline.
    private var readout: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            HStack(alignment: .firstTextBaseline, spacing: 8 * scaleFactor) {
                Text(l10n("slotPicker.chosenSlot", "CHOSEN SLOT"))
                    .font(.system(size: 11.5 * scaleFactor, design: .monospaced))
                    .kerning(11.5 * 0.07 * scaleFactor)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12 * scaleFactor)
                Text(formattedReadout(chosen))
                    .font(.system(size: 15 * scaleFactor, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("\(SlotPicker.exposureHours(from: now, to: chosen)) \(l10n("slotPicker.exposureSuffix", "h unpatched"))")
                    .font(.system(size: 11.5 * scaleFactor, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Divider().opacity(0.5)
        }
    }

    /// The track: accent fill to the handle, a deadline tick the handle cannot pass because every
    /// drag goes through `SlotPicker.snap`.
    private func track(deadline: Date) -> some View {
        let deadlineFraction = SlotPicker.position(of: deadline, start: now, windowHours: windowHours)
        let handleFraction = SlotPicker.position(of: chosen, start: now, windowHours: windowHours)

        return GeometryReader { geo in
            // Inset by the handle's radius so the end positions draw whole.
            let inset = 8 * scaleFactor
            let width = max(0, geo.size.width - 2 * inset)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: width, height: 4 * scaleFactor)

                // Past the deadline is not selectable, so it reads more muted.
                if deadlineFraction < 1 {
                    Capsule()
                        .fill(Color.primary.opacity(0.04))
                        .frame(width: max(0, width * (1 - deadlineFraction)), height: 4 * scaleFactor)
                        .offset(x: width * deadlineFraction)
                }

                Capsule()
                    .fill(resolvedAccent)
                    .frame(width: max(0, width * handleFraction), height: 4 * scaleFactor)
                    .frame(width: width, alignment: .leading)

                Rectangle()
                    .fill(amber)
                    .frame(width: 2, height: 14 * scaleFactor)
                    .offset(x: width * deadlineFraction - 1)
                    .accessibilityHidden(true)

                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(Circle().strokeBorder(resolvedAccent, lineWidth: 2))
                    .frame(width: 16 * scaleFactor, height: 16 * scaleFactor)
                    .offset(x: width * handleFraction - 8 * scaleFactor)
                    .shadow(color: .black.opacity(0.15), radius: 1.5, y: 0.5)
            }
            .frame(width: width, height: 16 * scaleFactor, alignment: .leading)
            .padding(.horizontal, inset)
            .frame(height: 16 * scaleFactor)
            .contentShape(Rectangle())
            // Dragging moves the handle; letting go answers. Only the trigger differs, and
            // `SelectionEmission.shouldEmit` decides which may emit, so a drag is one `select:` line.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let snapped = snappedInstant(atX: value.location.x - inset, width: width,
                                                        deadline: deadline) {
                            record(snapped, trigger: .dragFrame)
                        }
                    }
                    .onEnded { value in
                        if let snapped = snappedInstant(atX: value.location.x - inset, width: width,
                                                        deadline: deadline) {
                            record(snapped, trigger: .committed)
                        }
                    }
            )
        }
        .frame(height: 16 * scaleFactor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n("slotPicker.trackAccessibilityLabel", "Install slot"))
        .accessibilityValue(formattedReadout(chosen))
        .accessibilityAdjustableAction { direction in
            let step = TimeInterval(max(granularityMinutes, 1) * 60)
            let delta: TimeInterval = direction == .increment ? step : -step
            let snapped = SlotPicker.snap(chosen.addingTimeInterval(delta), start: now,
                                          deadline: deadline, granularityMinutes: granularityMinutes)
            record(snapped)
        }
    }

    /// Pointer x to the snapped instant the handle should sit on.
    private func snappedInstant(atX x: CGFloat, width: CGFloat, deadline: Date) -> Date? {
        guard width > 0 else { return nil }
        let fraction = x / width
        let rawInstant = SlotPicker.instant(atPosition: fraction, start: now, windowHours: windowHours)
        return SlotPicker.snap(rawInstant, start: now, deadline: deadline,
                               granularityMinutes: granularityMinutes)
    }

    /// Scale labels: "now", a midpoint day, and the deadline in the warning colour.
    private func scaleLabels(deadline: Date) -> some View {
        let midpoint = SlotPicker.midpoint(start: now, windowHours: windowHours)
        let nowLabel = l10n("slotPicker.now", "now")
        let deadlinePrefix = l10n("slotPicker.deadlinePrefix", "deadline")
        let deadlineAccessibilityPrefix = l10n("slotPicker.deadlineAccessibilityPrefix", "Deadline:")
        return HStack {
            Text(nowLabel)
                .accessibilityLabel("\(l10n("slotPicker.startAccessibilityPrefix", "Start:")) \(nowLabel)")
            Spacer(minLength: 8 * scaleFactor)
            Text(weekdayAbbrev(midpoint))
                .accessibilityHidden(true)
            Spacer(minLength: 8 * scaleFactor)
            Text("\(deadlinePrefix) \(weekdayAbbrev(deadline)) \(formattedTimeOnly(deadline))")
                .foregroundStyle(amber)
                .accessibilityLabel("\(deadlineAccessibilityPrefix) \(weekdayAbbrev(deadline)) \(formattedTimeOnly(deadline))")
        }
        .font(.system(size: 10.5 * scaleFactor, design: .monospaced))
        .foregroundStyle(.secondary)
    }

    /// Quick-pick chips; the one matching the current value is accent-tinted.
    private var quickPickChips: some View {
        FlowingTokens(spacing: 8 * scaleFactor) {
            ForEach(resolvedQuickPicks) { pick in
                chip(pick)
            }
        }
    }

    private func chip(_ pick: ResolvedPick) -> some View {
        let isActive = abs(pick.at.timeIntervalSince(chosen)) < 1
        return Button {
            record(pick.at)
        } label: {
            Text(pick.label)
                .font(.system(size: 12.5 * scaleFactor, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? resolvedAccent : .primary)
                .padding(.horizontal, 10 * scaleFactor)
                .padding(.vertical, 5 * scaleFactor)
                .background(
                    Capsule().fill(isActive ? resolvedAccent.opacity(0.12) : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(isActive ? resolvedAccent : Color.primary.opacity(0.15),
                                            lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// Facts table, one row per `facts` entry.
    private func factsTable(_ facts: [InspectConfig.SlotFact]) -> some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                HStack(alignment: .top, spacing: 12 * scaleFactor) {
                    Text(fact.label)
                        .font(.system(size: 12.5 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .frame(width: 110 * scaleFactor, alignment: .leading)
                    Text(fact.value)
                        .font(.system(size: 12.5 * scaleFactor))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Formatting, shared with the card footer through `SlotPickerReadout`

    private func formattedTimeOnly(_ date: Date) -> String { SlotPickerReadout.timeOnly(date) }

    private func weekdayAbbrev(_ date: Date) -> String { SlotPickerReadout.weekdayAbbrev(date) }

    /// "Tonight, Wed 21:00", relative to the fixed `now`.
    private func formattedReadout(_ date: Date) -> String {
        SlotPickerReadout.readout(date, now: now, l10n: { l10n($0, $1) })
    }
}
