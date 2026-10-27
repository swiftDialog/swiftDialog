//
//  CadenceBentoBoard.swift
//  dialog
//
//  The cadence run as a bento board, selected by `cadenceStyle: "bento"`: the machine in the left
//  seat, four step seats on the right, and a completed step flips to its receipt.
//

import SwiftUI
import AppKit
import IOKit

// MARK: - The machine

/// What the "This Mac" tile says, read from the machine. The marketing name from the IORegistry,
/// else the hardware model identifier. Resolved once per process.
struct MachineIdentity: Sendable, Equatable {
    let name: String
    let chip: String?
    let memory: String?
    let osVersion: String

    static let current = MachineIdentity()

    init() {
        name = MachineIdentity.productName() ?? deviceHardwareModel
        chip = MachineIdentity.sysctlString("machdep.cpu.brand_string")
        memory = MachineIdentity.memoryDescription()
        let v = ProcessInfo.processInfo.operatingSystemVersion
        osVersion = "macOS \(v.majorVersion).\(v.minorVersion)"
    }

    /// Chip · memory · OS; unanswered pieces drop out.
    var specLine: String {
        [chip, memory, osVersion].compactMap { $0 }.joined(separator: " · ")
    }

    /// Chip · memory, for seats with no room for the OS version.
    var shortSpecLine: String {
        [chip, memory].compactMap { $0 }.joined(separator: " · ")
    }

    /// The marketing name from `IODeviceTree:/product`; `IOPlatformExpertDevice` has only the
    /// identifier. The property is a NUL-terminated C string in a data value.
    private static func productName() -> String? {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        guard let property = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString,
                                                             kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Data else { return nil }
        guard let raw = String(bytes: property, encoding: .utf8) else { return nil }
        let text = raw.trimmingCharacters(
            in: CharacterSet(charactersIn: "\0").union(.whitespacesAndNewlines))
        return text.isEmpty ? nil : text
    }

    private static func sysctlString(_ key: String) -> String? {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &value, &size, nil, 0) == 0 else { return nil }
        let text = String(cString: value).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    private static func memoryDescription() -> String? {
        let bytes = ProcessInfo.processInfo.physicalMemory
        guard bytes > 0 else { return nil }
        return "\(bytes / 1_073_741_824) GB"
    }
}

/// This Mac's own artwork via `NSImage.computerName`, at the size the seat gives it. Takes no
/// frame of its own, so it stays left-aligned with the name beneath it.
struct MachineImage: View {
    var body: some View {
        Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

// MARK: - The board's numbers

/// The board's geometry.
enum CadenceBentoM {
    static let tileRadius: CGFloat = 14
    /// Air between seats, both axes.
    static let gap: CGFloat = 14
    /// The machine seat's share of the board's width; the step seats take the rest.
    static let machineWidthFraction: CGFloat = 0.3
    /// Air around the machine picture inside its seat.
    static let machineImageInset: CGFloat = 6
    /// The flip curve; not a spring.
    static let flip: Animation = .timingCurve(0.4, 0.05, 0.2, 1, duration: 0.72)
    /// The turn's vanishing point; 1 is a flat turn.
    static let flipPerspective: CGFloat = 0.42
    /// Step seats per board. A longer run promotes through them, starting one entry behind the
    /// cursor so a tile that just flipped stays readable beside the running one.
    static let seats: Int = 4
}

// MARK: - A tile

/// Two faces on one card, swapped at the halfway point of a Y rotation. `Animatable` so the face
/// choice is made per interpolated frame; the back is pre-rotated 180° to read correctly once
/// turned. The deprecated `perspective:` signature is the only one that carries a vanishing
/// point on macOS.
struct CadenceFlipFaces<Front: View, Back: View>: View, @MainActor Animatable {
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            front.opacity(angle < 90 ? 1 : 0)
            back.opacity(angle < 90 ? 0 : 1)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0),
                          perspective: CadenceBentoM.flipPerspective)
    }
}

/// One step's seat: identity on the front, receipt on the back. Only `done` flips.
struct CadenceFlipTile: View {
    let entry: InspectConfig.CadenceEntry
    let state: CadenceBentoBoard.TileState
    let accent: Color

    @Environment(\.palette) private var palette

    private var isFlipped: Bool { state == .done }

    var body: some View {
        CadenceFlipFaces(angle: isFlipped ? 180 : 0,
                         front: face(front: true),
                         back: face(front: false))
            .animation(CadenceBentoM.flip, value: isFlipped)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.label ?? entry.id), \(stateWord)")
    }

    private var stateWord: String {
        switch state {
        case .queued: return "Queued"
        case .active: return "Checking"
        case .done: return "Complete"
        case .failed: return "Didn't finish"
        }
    }

    @ViewBuilder
    private func face(front: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if front {
                CadenceEntryGlyph(entry: entry, accent: state == .active ? accent : palette.textMuted)
                Spacer(minLength: 8)
                Text(entry.label ?? entry.id)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(state == .active ? accent : palette.text)
                    .lineLimit(1)
                Text(stateWord)
                    .font(.system(size: 12))
                    .foregroundStyle(state == .active ? accent : palette.textMuted)
                    .lineLimit(1)
            } else {
                // The receipt: the entry's subtitle, else its running message.
                Image(systemName: state == .failed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(state == .failed ? palette.warning : palette.success)
                Spacer(minLength: 8)
                Text(entry.label ?? entry.id)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Text(entry.subtitle ?? entry.message)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: CadenceBentoM.tileRadius, style: .continuous)
                .fill(state == .active ? accent.opacity(0.06) : palette.text.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CadenceBentoM.tileRadius, style: .continuous)
                .strokeBorder(state == .active ? accent : palette.text.opacity(0.08),
                              lineWidth: state == .active ? 1.5 : 1)
        )
    }
}

/// The entry's mark at tile size: authored image, authored symbol, or the initial.
struct CadenceEntryGlyph: View {
    let entry: InspectConfig.CadenceEntry
    let accent: Color

    var body: some View {
        if let path = entry.imagePath, !path.isEmpty, ProvisioningRowIcon.handles(path) {
            ProvisioningRowIcon(path: path, symbol: entry.sfSymbol ?? "circle", on: true,
                                accent: accent, size: 26)
        } else if let path = entry.imagePath, !path.isEmpty {
            BrandMark(path: path, box: BrandMarkBox(height: 26, maxWidth: 26))
        } else if let symbol = entry.sfSymbol, !symbol.isEmpty {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent)
        } else {
            Text(String((entry.label ?? entry.id).prefix(1)).uppercased())
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
        }
    }
}

// MARK: - The board

/// The bento: the machine on the left, the run's steps in the seats on the right.
struct CadenceBentoBoard: View {
    enum TileState: Equatable { case queued, active, done, failed }

    let run: CadenceProgress
    let haltedIndex: Int?
    let accent: Color
    /// The board's frame; the shell owns the payload's bounds.
    let size: CGSize

    @Environment(\.palette) private var palette

    /// Passed entries are done unless failed or halted, the cursor's entry is active, the rest wait.
    func state(at index: Int) -> TileState {
        if let haltedIndex {
            if index == haltedIndex { return .failed }
            if index < haltedIndex { return run.failed.contains(index) ? .failed : .done }
            return .queued
        }
        if index < run.position { return run.failed.contains(index) ? .failed : .done }
        if index == run.position && !run.isComplete { return .active }
        return run.isComplete ? .done : .queued
    }

    /// A window of the run that promotes through the seats, via `CadenceM.visibleWindow` with a
    /// viewport the width of four cards and their gaps. Never every entry at once.
    var seatedEntries: [(offset: Int, element: InspectConfig.CadenceEntry)] {
        let seatViewport = CGFloat(CadenceBentoM.seats) * (CadenceM.cardWidth + CadenceM.cardGap)
            - CadenceM.cardGap
        let window = CadenceM.visibleWindow(count: run.entries.count,
                                            active: run.position,
                                            viewport: seatViewport)
        return window.compactMap { index in
            run.entries.indices.contains(index) ? (index, run.entries[index]) : nil
        }
    }

    /// "2 of 12 complete": the whole run, where the seats show only a window.
    var countLine: String {
        "\(run.satisfied) of \(run.total) complete"
    }

    /// The running step's name, for layouts that put it in a band.
    var runningName: String? {
        guard let current = run.current else { return nil }
        return current.label ?? current.id
    }

    var body: some View {
        board
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        // The seats slide when the window promotes; the flip is the tile's own.
        .animation(CadenceBentoM.flip, value: run.position)
    }

    /// The machine column and a 2 × 2 of step seats.
    private var board: some View {
        HStack(alignment: .top, spacing: CadenceBentoM.gap) {
            machineTile
                .frame(width: size.width * CadenceBentoM.machineWidthFraction)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: CadenceBentoM.gap),
                                GridItem(.flexible(), spacing: CadenceBentoM.gap)],
                      spacing: CadenceBentoM.gap) {
                ForEach(seatedEntries, id: \.element.id) { seat in
                    tile(seat)
                        .frame(height: (size.height - CadenceBentoM.gap) / 2)
                }
            }
            // Without this the grid sizes to its content and leaves dead space on the right.
            .frame(maxWidth: .infinity)
        }
    }

    private func tile(_ seat: (offset: Int, element: InspectConfig.CadenceEntry)) -> some View {
        CadenceFlipTile(entry: seat.element, state: state(at: seat.offset), accent: accent)
    }

    /// "This Mac": the machine's picture, name and spec line, none of it authored.
    private var machineTile: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("This Mac")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(palette.textMuted)
            MachineImage()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, CadenceBentoM.machineImageInset)
            Text(MachineIdentity.current.name)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(palette.text)
                .lineLimit(1)
            Text(MachineIdentity.current.specLine)
                .font(.system(size: 11.5))
                .foregroundStyle(palette.textMuted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: CadenceBentoM.tileRadius, style: .continuous)
                .fill(palette.text.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CadenceBentoM.tileRadius, style: .continuous)
                .strokeBorder(palette.text.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This Mac, \(MachineIdentity.current.name)")
        .sourceTag()
    }
}
