//
//  GuidanceColorPickerBlock.swift
//  dialog
//
//  `type: "color-picker"`: the system colour well with a swatch and hex readout. The hex is stored
//  where a text field's value would be, `guidanceFormInputs[step].textfields[id]`; `value` is the
//  starting colour.
//

import SwiftUI
import AppKit

struct GuidanceColorPickerBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    private var hex: String {
        guard let id = block.id else { return block.value ?? "#0A84FF" }
        return inspectState.guidanceFormInputs[itemId]?.textfields[id] ?? block.value ?? "#0A84FF"
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: hex) },
            set: { store(Self.hexString($0) ?? hex) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            if let label = block.content, !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(palette.text)
            }
            HStack(spacing: 16 * scaleFactor) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: hex))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.text.opacity(0.12), lineWidth: 1))
                    .frame(width: 120 * scaleFactor, height: 72 * scaleFactor)
                VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                    ColorPicker("Colour", selection: colorBinding, supportsOpacity: false)
                        .labelsHidden()
                    Text(hex.uppercased())
                        .font(.system(size: 13 * scaleFactor, design: .monospaced))
                        .foregroundStyle(palette.textMuted)
                        .textSelection(.enabled)
                }
            }
        }
        .onAppear {
            // The starting colour is an answer too when the user never touches the well.
            guard let id = block.id, inspectState.guidanceFormInputs[itemId]?.textfields[id] == nil else { return }
            store(hex)
        }
    }

    private func store(_ value: String) {
        guard let id = block.id else { return }
        if inspectState.guidanceFormInputs[itemId] == nil { inspectState.initializeGuidanceFormState(for: itemId) }
        inspectState.guidanceFormInputs[itemId]?.textfields[id] = value
        inspectState.writeToInteractionLog("color:\(id):\(value)")
    }

    /// "#RRGGBB" for a colour, in sRGB; nil when it has no sRGB form.
    static func hexString(_ color: Color) -> String? {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        let channel = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(rgb.redComponent), channel(rgb.greenComponent),
                      channel(rgb.blueComponent))
    }
}
