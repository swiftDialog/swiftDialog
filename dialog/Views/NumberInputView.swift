//
//  NumberInputView.swift
//  dialog
//
//  Sliders and steppers (--slider / --stepper): one numeric model, two controls.
//

import SwiftUI

// MARK: - Shared column widths

/// Widths of the pieces around a slider or stepper. Every number row reports what it needs and rows
/// that sit together use the widest, so sliders are the same length and stepper arrows line up.
struct NumberColumnWidths: Equatable {
    var minLabel: CGFloat = 0
    var maxLabel: CGFloat = 0
    var value: CGFloat = 0
    var unit: CGFloat = 0
}

private struct NumberColumnKey: PreferenceKey {
    static var defaultValue = NumberColumnWidths()
    static func reduce(value: inout NumberColumnWidths, nextValue: () -> NumberColumnWidths) {
        let next = nextValue()
        value.minLabel = max(value.minLabel, next.minLabel)
        value.maxLabel = max(value.maxLabel, next.maxLabel)
        value.value = max(value.value, next.value)
        value.unit = max(value.unit, next.unit)
    }
}

private struct NumberColumnsEnvironmentKey: EnvironmentKey {
    static let defaultValue = NumberColumnWidths()
}

extension EnvironmentValues {
    fileprivate var numberColumns: NumberColumnWidths {
        get { self[NumberColumnsEnvironmentKey.self] }
        set { self[NumberColumnsEnvironmentKey.self] = newValue }
    }
}

/// Collects the widths reported by number rows inside and hands the widest back to them.
struct AlignedNumberColumns: ViewModifier {
    @State private var widths = NumberColumnWidths()

    func body(content: Content) -> some View {
        content
            .environment(\.numberColumns, widths)
            .onPreferenceChange(NumberColumnKey.self) { widths = $0 }
    }
}

extension View {
    /// Rows of sliders / steppers inside share column widths so they line up
    func alignedNumberColumns() -> some View {
        modifier(AlignedNumberColumns())
    }
}

struct NumberInputView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    /// Only draw this kind ("slider" / "stepper"); nil draws whichever the listed indices are.
    var kind: String?
    /// Only draw these items (nil = all of `kind`). Used when `vieworder` places inputs individually.
    var indices: [Int]?
    /// Drawn inside a group, which supplies the surrounding box
    var embedded: Bool = false

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
            VStack {
                ForEach(visible, id: \.self) { index in
                    NumberRow(observedData: observedData, input: inputs[index])
                    if !embedded && index != visible.last {
                        Divider().opacity(0.5)
                    }
                }
            }
            .alignedNumberColumns()
            .font(.system(size: observedData.appProperties.labelFontSize))
            .inputBox(embedded: embedded)
        }
    }
}

private struct NumberRow: View {

    @ObservedObject var observedData: DialogUpdatableContent
    let input: NumberInput
    @Environment(\.numberColumns) private var columns

    /// The widest the value readout gets while dragging (monospaced digits, so the longest end of the range)
    private var widestValueText: String {
        var low = input; low.value = input.minValue
        var high = input; high.value = input.maxValue
        let text = [low.displayValue, high.displayValue].max { $0.count < $1.count } ?? ""
        return text + input.unit
    }

    /// Report a piece's natural width without affecting layout
    private func measure(_ text: String, font: Font? = nil, into report: @escaping (CGFloat) -> NumberColumnWidths) -> some View {
        Text(text)
            .font(font)
            .monospacedDigit()
            .fixedSize()
            .hidden()
            .background(GeometryReader { proxy in
                Color.clear.preference(key: NumberColumnKey.self, value: report(proxy.size.width))
            })
    }

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
            Text(input.minLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: columns.minLabel, alignment: .trailing)
                .background(measure(input.minLabel, font: .caption) { NumberColumnWidths(minLabel: $0) })
            Slider(value: value, in: input.minValue...input.maxValue, step: input.step)
                .frame(width: 220)
                .accessibilityLabel(input.title)
            Text(input.maxLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: columns.maxLabel, alignment: .leading)
                .background(measure(input.maxLabel, font: .caption) { NumberColumnWidths(maxLabel: $0) })
            if input.showValue {
                Text(input.displayValue + input.unit)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: columns.value, alignment: .trailing)
                    .background(measure(widestValueText) { NumberColumnWidths(value: $0) })
            } else if columns.value > 0 {
                // keep the slider aligned with rows in the same group that do show a value
                Color.clear.frame(width: columns.value, height: 1)
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
            Text(input.unit)
                .foregroundStyle(.secondary)
                .frame(minWidth: columns.unit, alignment: .leading)
                .background(measure(input.unit) { NumberColumnWidths(unit: $0) })
        }
    }
}
