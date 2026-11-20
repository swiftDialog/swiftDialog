//
//  SlotPickerCopy.swift
//  dialog
//
//  The slot picker's words, shared by the block and the card footers: the block's
//  `continueFormat`, `continueAtNow` and `secondaryAtLater` keys label footer buttons the block
//  does not own, so their resolution lives here.
//

import Foundation

/// The one place the picker formats a Date for people ("Tonight, Wed 21:00"), so the block's
/// readout and the button's `{time}` read identically. `now` is the caller's fixed reference,
/// never the live clock, so a label does not re-word itself as time passes.
enum SlotPickerReadout {

    static func timeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("Hm")
        return formatter.string(from: date)
    }

    static func weekdayAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    /// Today, Tonight (from 18:00) or Tomorrow, every word through `l10n`; nil beyond that.
    static func relativeDayPrefix(for date: Date, now: Date,
                                  l10n: (String, String) -> String) -> String? {
        let cal = Calendar.current
        let dayDiff = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                          to: cal.startOfDay(for: date)).day ?? 0
        switch dayDiff {
        case 0:
            return cal.component(.hour, from: date) >= 18
                ? l10n("slotPicker.tonight", "Tonight")
                : l10n("slotPicker.today", "Today")
        case 1:
            return l10n("slotPicker.tomorrow", "Tomorrow")
        default:
            return nil
        }
    }

    static func readout(_ date: Date, now: Date, l10n: (String, String) -> String) -> String {
        let weekday = weekdayAbbrev(date)
        let time = timeOnly(date)
        guard let prefix = relativeDayPrefix(for: date, now: now, l10n: l10n) else { return "\(weekday) \(time)" }
        return "\(prefix), \(weekday) \(time)"
    }
}

/// Footer copy for the chosen slot; nil text keeps the step's own button text.
struct SlotPickerFooterCopy: Equatable {
    let selectionKey: String
    /// The chosen slot is not in the future.
    let isNow: Bool
    let continueText: String?
    let secondaryText: String?
}

enum SlotPickerCopy {

    /// Footer copy for the step's first `slot-picker` block. Nil when the step has no picker or
    /// the block has not yet recorded its opening slot (one render after appear).
    static func resolve(step: InspectConfig.IntroStep, userValues: [String: String], now: Date,
                        l10n: (String, String) -> String) -> SlotPickerFooterCopy? {
        let blocks = step.content ?? step.guidanceContent ?? []
        guard let block = blocks.first(where: { $0.type == "slot-picker" }) else { return nil }
        let key = SelectionEmission.resolveKey(block.id, fallback: "slot").key
        guard let raw = userValues[key], let chosen = SlotPicker.isoDate(raw) else { return nil }
        return resolve(block: block, chosen: chosen, now: now, selectionKey: key, l10n: l10n)
    }

    /// The pure half. "Now" is any slot not in the future: the opening slot is floored to the
    /// granularity grid, so it can sit minutes behind the clock.
    static func resolve(block: InspectConfig.GuidanceContent, chosen: Date, now: Date,
                        selectionKey: String, l10n: (String, String) -> String) -> SlotPickerFooterCopy {
        // `!(a > b)`, not `a <= b`: Foundation's Date <= and >= are new in the macOS 27.2 SDK and missing
        // from some 27.2 builds, where a call jumps to address 0. <, > and == exist everywhere.
        let isNow = !(chosen > now)
        let continueText: String?
        if isNow {
            continueText = block.continueAtNow
        } else if let format = block.continueFormat {
            continueText = SlotPicker.primaryLabel(chosen: chosen, now: now, format: format,
                                                   atNow: block.continueAtNow ?? format,
                                                   timeText: SlotPickerReadout.readout(chosen, now: now, l10n: l10n))
        } else {
            continueText = nil
        }
        return SlotPickerFooterCopy(selectionKey: selectionKey, isNow: isNow,
                                    continueText: continueText,
                                    secondaryText: isNow ? nil : block.secondaryAtLater)
    }
}
