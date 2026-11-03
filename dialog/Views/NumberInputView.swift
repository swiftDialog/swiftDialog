//
//  NumberInputView.swift
//  dialog
//
//  Sliders and steppers (--slider / --stepper): one numeric model, two controls.
//

import SwiftUI

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
            .font(.system(size: observedData.appProperties.labelFontSize))
            .inputBox(embedded: embedded)
        }
    }
}

private struct NumberRow: View {

    @ObservedObject var observedData: DialogUpdatableContent
    let input: NumberInput

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
            if !input.minLabel.isEmpty {
                Text(input.minLabel).font(.caption).foregroundStyle(.secondary)
            }
            Slider(value: value, in: input.minValue...input.maxValue, step: input.step)
                .frame(minWidth: 120, idealWidth: 220, maxWidth: 260)
                .accessibilityLabel(input.title)
            if !input.maxLabel.isEmpty {
                Text(input.maxLabel).font(.caption).foregroundStyle(.secondary)
            }
            if input.showValue {
                Text(input.displayValue + input.unit)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, alignment: .trailing)
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
            if !input.unit.isEmpty {
                Text(input.unit).foregroundStyle(.secondary)
            }
        }
    }
}
