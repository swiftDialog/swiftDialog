//
//  NumberInputView.swift
//  dialog
//
//  Sliders and steppers (--slider / --stepper): one numeric model, two controls.
//

import SwiftUI
import AppKit

// MARK: - Shared column widths

/// Widths of the pieces around a slider or stepper. Rows that sit together (in a group, or one
/// view) all use the widest, so sliders are the same length and stepper arrows line up.
///
/// The widths are measured up front from the text itself rather than reported back by the rows:
/// a value that arrives a layout pass late makes rows size themselves twice and jump.
struct NumberColumnWidths: Equatable {
    var minLabel: CGFloat = 0
    var maxLabel: CGFloat = 0
    var value: CGFloat = 0
    var unit: CGFloat = 0

    /// The widths needed by `inputs`, for text drawn at `fontSize` (captions are 10pt).
    static func measuring(_ inputs: [NumberInput], fontSize: CGFloat) -> NumberColumnWidths {
        func width(_ text: String, _ font: NSFont) -> CGFloat {
            text.isEmpty ? 0 : ceil((text as NSString).size(withAttributes: [.font: font]).width) + 2
        }
        let caption = NSFont.systemFont(ofSize: 10)
        let digits = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        let plain = NSFont.systemFont(ofSize: fontSize)

        var widths = NumberColumnWidths()
        for input in inputs {
            if input.kind == "stepper" {
                widths.unit = max(widths.unit, width(input.unit, plain))
            } else {
                widths.minLabel = max(widths.minLabel, width(input.minLabel, caption))
                widths.maxLabel = max(widths.maxLabel, width(input.maxLabel, caption))
                if input.showValue {
                    // the widest the readout gets while dragging: the longer end of the range
                    var low = input; low.value = input.minValue
                    var high = input; high.value = input.maxValue
                    let widest = [low.displayValue, high.displayValue].max { $0.count < $1.count } ?? ""
                    widths.value = max(widths.value, width(widest + input.unit, digits))
                }
            }
        }
        return widths
    }
}

private struct NumberColumnsKey: EnvironmentKey {
    static let defaultValue = NumberColumnWidths()
}

extension EnvironmentValues {
    var numberColumns: NumberColumnWidths {
        get { self[NumberColumnsKey.self] }
        set { self[NumberColumnsKey.self] = newValue }
    }
}

// MARK: - View

struct NumberInputView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    /// Only draw this kind ("slider" / "stepper"); nil draws whichever the listed indices are.
    var kind: String?
    /// Only draw these items (nil = all of `kind`). Used when `vieworder` places inputs individually.
    var indices: [Int]?
    /// Drawn inside a group, which supplies the surrounding box and the shared column widths
    var embedded: Bool = false

    @Environment(\.numberColumns) private var inheritedColumns

    init(observedDialogContent: DialogUpdatableContent, kind: String? = nil, indices: [Int]? = nil, embedded: Bool = false) {
        self.observedData = observedDialogContent
        self.kind = kind
        self.indices = indices
        self.embedded = embedded
    }

    var body: some View {
        let inputs = observedData.observedUserInputState.numberInputs
        let visible = (indices ?? Array(inputs.indices)).filter { index in
            inputs.indices.contains(index) && (kind == nil || inputs[index].kind == kind)
        }
        if !visible.isEmpty {
            // Embedded rows use the widths their group measured; otherwise measure the rows shown here
            let columns = embedded
                ? inheritedColumns
                : NumberColumnWidths.measuring(visible.map { inputs[$0] }, fontSize: observedData.appProperties.labelFontSize)
            VStack {
                ForEach(visible, id: \.self) { index in
                    NumberRow(observedData: observedData, input: inputs[index], columns: columns)
                    if !embedded && index != visible.last {
                        Divider().opacity(0.5)
                    }
                }
            }
            .font(.system(size: observedData.appProperties.labelFontSize))
            .inputBox(embedded: embedded)
        }
    }
}

private struct NumberRow: View {

    @ObservedObject var observedData: DialogUpdatableContent
    let input: NumberInput
    let columns: NumberColumnWidths

    private var value: Binding<Double> {
        Binding(get: { input.value },
                set: { observedData.setNumberValue(id: input.id, $0) })
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(input.title)
                DetailText(input.detail)
            }
            Spacer()
            if input.kind == "stepper" {
                stepper
            } else {
                slider
            }
        }
    }

    // MARK: Slider

    private var slider: some View {
        HStack(spacing: 8) {
            if columns.minLabel > 0 {
                Text(input.minLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: columns.minLabel, alignment: .trailing)
            }
            Slider(value: value, in: input.minValue...input.maxValue, step: input.step)
                .frame(width: 220)
                .accessibilityLabel(input.title)
            if columns.maxLabel > 0 {
                Text(input.maxLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: columns.maxLabel, alignment: .leading)
            }
            if columns.value > 0 {
                // Fixed width, so the slider keeps its length however the number changes
                Text(input.showValue ? input.displayValue + input.unit : "")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: columns.value, alignment: .trailing)
            }
        }
    }

    // MARK: Stepper

    private var stepper: some View {
        HStack(spacing: 6) {
            TextField("", value: value, format: .number.precision(.fractionLength(input.decimals)))
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .accessibilityLabel(input.title)
                .onSubmit { observedData.setNumberValue(id: input.id, input.value) }
            Stepper("", value: value, in: input.minValue...input.maxValue, step: input.step)
                .labelsHidden()
            if columns.unit > 0 {
                Text(input.unit)
                    .foregroundStyle(.secondary)
                    .frame(width: columns.unit, alignment: .leading)
            }
        }
    }
}
