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
    /// Widest title (on one line), used to share space between titles and sliders
    var title: CGFloat = 0
    /// Length of every slider in the group. Flexible: set from the width of the group by `fitting`.
    var slider: CGFloat = NumberColumnWidths.idealSlider

    static let idealSlider: CGFloat = 220
    static let minSlider: CGFloat = 90
    static let maxSlider: CGFloat = 280

    /// Give every slider the same length for a group `boxWidth` wide: as much as is left after the
    /// titles and fixed columns, held between `minSlider` and `maxSlider`, so it shrinks with the
    /// window before titles are squeezed and grows up to a limit.
    func fitting(boxWidth: CGFloat) -> NumberColumnWidths {
        guard boxWidth > 0 else { return self }
        var widths = self
        let fixed = [minLabel, maxLabel, value].filter { $0 > 0 }
        let spacing = CGFloat(fixed.count) * 8                       // between the pieces and the slider
        let titleShare = min(title, boxWidth * 0.4)
        let available = boxWidth - titleShare - fixed.reduce(0, +) - spacing - 16
        widths.slider = min(max(available, NumberColumnWidths.minSlider), NumberColumnWidths.maxSlider)
        return widths
    }

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
            widths.title = max(widths.title, width(input.title, plain))
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

/// Measures the width it is given and sets the shared column widths for the sliders and steppers
/// inside, so the sliders resize with the window but stay the same length as each other.
struct NumberColumnsModifier: ViewModifier {
    let inputs: [NumberInput]
    let fontSize: CGFloat
    @State private var boxWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .environment(\.numberColumns, NumberColumnWidths.measuring(inputs, fontSize: fontSize).fitting(boxWidth: boxWidth))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boxWidth = $0 }
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
            if embedded {
                // The group measured the widths for all of its number rows
                rows(visible, inputs: inputs, columns: inheritedColumns)
            } else {
                rows(visible, inputs: inputs, columns: nil)
                    .modifier(NumberColumnsModifier(inputs: visible.map { inputs[$0] },
                                                    fontSize: observedData.appProperties.labelFontSize))
                    .font(.system(size: observedData.appProperties.labelFontSize))
                    .inputBox(embedded: false)
            }
        }
    }
}

extension NumberInputView {
    /// `columns` nil means "use the environment" (set by `NumberColumnsModifier` for standalone views)
    @ViewBuilder
    fileprivate func rows(_ visible: [Int], inputs: [NumberInput], columns: NumberColumnWidths?) -> some View {
        VStack {
            ForEach(visible, id: \.self) { index in
                Group {
                    NumberRow(observedData: observedData, input: inputs[index], explicitColumns: columns)
                    if !embedded && index != visible.last {
                        Divider().opacity(0.5)
                    }
                }
                .controlDependencies(observedData, enabledIf: inputs[index].enabledIf, visibleIf: inputs[index].visibleIf)
            }
        }
    }
}

private struct NumberRow: View {

    @ObservedObject var observedData: DialogUpdatableContent
    let input: NumberInput
    let explicitColumns: NumberColumnWidths?
    @Environment(\.numberColumns) private var environmentColumns

    private var columns: NumberColumnWidths { explicitColumns ?? environmentColumns }

    private var value: Binding<Double> {
        Binding(get: { input.value },
                set: { observedData.setNumberValue(id: input.id, $0) })
    }

    /// Sliders snap to the step themselves: the native `step` would draw a tick mark for each one
    private var sliderValue: Binding<Double> {
        Binding(get: { input.value },
                set: { observedData.setNumberValue(id: input.id, $0, snapToStep: true) })
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(input.title)
                DetailText(input.detail)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
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
            Slider(value: sliderValue, in: input.minValue...input.maxValue)
                .frame(width: columns.slider)
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
