//
//  GuidanceFormBlocks.swift
//  dialog
//
//  Interactive form guidance blocks: checkbox, dropdown, radio, toggle, slider, button.
//  Generic over `UserInputContext`; they touch only `guidanceFormInputs` and the interaction log.
//

import SwiftUI

// MARK: - Shared row geometry and required hint

/// Labels sit in a fixed column so every control on a step starts at the same x.
enum FormRowGeometry {
    /// Longer labels wrap inside the column rather than pushing the control right.
    static func labelColumn(scaleFactor: CGFloat) -> CGFloat { 180 * scaleFactor }
}

struct GuidanceRequiredHint: View {
    let scaleFactor: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        Text("* Required")
            .font(.system(size: 11 * scaleFactor))
            .foregroundStyle(palette.textMuted)
            .italic()
    }
}

// MARK: - Checkbox (type: "checkbox")

struct GuidanceCheckboxBlock<Context: UserInputContext & ObservableObject>: View {
    @Environment(\.brandedControls) private var brandedControls
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat
    var wire = FormWire()

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            HStack {
                if let fieldId = block.id {
                    Toggle(isOn: Binding(
                        get: {
                            if let checked = inspectState.guidanceFormInputs[itemId]?.checkboxes[fieldId] {
                                return checked
                            }
                            if let value = block.value?.lowercased() {
                                return value == "true" || value == "yes" || value == "1"
                            }
                            return false
                        },
                        set: { newValue in
                            if inspectState.guidanceFormInputs[itemId] == nil {
                                inspectState.initializeGuidanceFormState(for: itemId)
                            }
                            inspectState.guidanceFormInputs[itemId]?.checkboxes[fieldId] = newValue
                            writeLog("GuidanceContentView: Checkbox '\(fieldId)' set to \(newValue)", logLevel: .info)
                            inspectState.writeToInteractionLog(
                                wire.line(type: "checkbox", owner: itemId, field: fieldId, value: "\(newValue)"))
                            wire.onValueCommit?(fieldId, newValue)
                        }
                    )) {
                        Text(block.content ?? "")
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(palette.text)
                    }
                    // Branded primitives take `accentColor: nil` and fill from `palette.accent`:
                    // a control's on-state fill is state, not decoration, and a host may hand
                    // the block a muted decoration colour.
                    .toggleStyle(brandedControls
                                 ? AnyToggleStyle(BrandCheckboxToggleStyle(accentColor: nil,
                                                                           scaleFactor: scaleFactor))
                                 : AnyToggleStyle(.checkbox))
                    .tint(accentColor ?? palette.accent)
                } else {
                    // No id: display-only.
                    Toggle(isOn: .constant(false)) {
                        Text(block.content ?? "")
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(palette.text)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(true)
                }
            }

            if let helpText = block.helpText, !helpText.isEmpty {
                GuidanceFieldHelp(text: helpText, scaleFactor: scaleFactor)
            }

            if block.required == true {
                GuidanceRequiredHint(scaleFactor: scaleFactor)
            }
        }
        .padding(.vertical, 4 * scaleFactor)
    }
}

// MARK: - Dropdown (type: "dropdown")

struct GuidanceDropdownBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat
    var wire = FormWire()
    /// Resolves relative `optionIcons` paths.
    var iconBasePath: String?

    private var hasOptionIcons: Bool {
        block.optionIcons?.contains { !$0.isEmpty } ?? false
    }

    private func selectionBinding(fieldId: String, options: [String]) -> Binding<String> {
        Binding<String>(
            get: {
                inspectState.guidanceFormInputs[itemId]?.dropdowns[fieldId] ?? block.value ?? options.first ?? ""
            },
            set: { newValue in
                if inspectState.guidanceFormInputs[itemId] == nil {
                    inspectState.initializeGuidanceFormState(for: itemId)
                }
                inspectState.guidanceFormInputs[itemId]?.dropdowns[fieldId] = newValue
                writeLog("GuidanceContentView: Dropdown '\(fieldId)' set to '\(newValue)'", logLevel: .info)
                inspectState.writeToInteractionLog(
                    wire.line(type: "dropdown", owner: itemId, field: fieldId, value: newValue))
                wire.onValueCommit?(fieldId, newValue)
            }
        )
    }

    @Environment(\.palette) private var palette
    @Environment(\.brandedControls) private var brandedControls

    var body: some View {
        if block.style == "option-rows" {
            optionRowsBody
        } else {
            labelledControlBody
        }
    }

    /// `style: "option-rows"`: tappable rows, the selected one tinted with a checkmark. Draws no
    /// inline label; the step title names the choice.
    private var optionRowsBody: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            if let options = block.options, !options.isEmpty, let fieldId = block.id {
                let selection = selectionBinding(fieldId: fieldId, options: options)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        let isSelected = selection.wrappedValue == option
                        // `optionDetails` is parallel to `options`; a shorter array is fine.
                        let detail = (block.optionDetails?.indices.contains(index) ?? false)
                            ? block.optionDetails?[index]
                            : nil

                        // Top-aligned so the icon stays beside the title under a long detail.
                        HStack(alignment: .top, spacing: 10 * scaleFactor) {
                            // Once any option has an icon, every row reserves the slot so the
                            // titles keep one left edge.
                            if hasOptionIcons {
                                let iconName = (block.optionIcons?.indices.contains(index) ?? false)
                                    ? block.optionIcons?[index]
                                    : nil
                                if let iconName, !iconName.isEmpty {
                                    GuidanceInlineIcon(
                                        icon: iconName,
                                        size: 28 * scaleFactor,
                                        basePath: iconBasePath,
                                        tint: isSelected ? (accentColor ?? palette.accent) : nil
                                    )
                                } else {
                                    Color.clear.frame(width: 28 * scaleFactor, height: 28 * scaleFactor)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                                // Weight marks the selection for readers who cannot see the tint.
                                Text(option)
                                    .font(.system(size: 14 * scaleFactor,
                                                  weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(palette.text)

                                if let detail, !detail.isEmpty {
                                    Text(detail)
                                        .font(.system(size: 12 * scaleFactor))
                                        .foregroundStyle(palette.textMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Spacer(minLength: 8 * scaleFactor)

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13 * scaleFactor, weight: .semibold))
                                    .foregroundStyle(accentColor ?? palette.accent)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10 * scaleFactor)
                        .padding(.horizontal, 14 * scaleFactor)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected
                                      ? (accentColor ?? palette.accent).opacity(0.10)
                                      : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                selection.wrappedValue = option
                            }
                        }
                        // Hairline between unselected neighbours only.
                        .overlay(alignment: .bottom) {
                            if index < options.count - 1, !isSelected,
                               selection.wrappedValue != options[index + 1] {
                                Rectangle()
                                    .fill(palette.textMuted.opacity(0.12))
                                    .frame(height: 1)
                                    .padding(.horizontal, 14 * scaleFactor)
                            }
                        }
                    }
                }
            }

            if let helpText = block.helpText, !helpText.isEmpty {
                GuidanceFieldHelp(text: helpText, scaleFactor: scaleFactor)
            }

            if block.required == true {
                GuidanceRequiredHint(scaleFactor: scaleFactor)
            }
        }
        .padding(.vertical, 4 * scaleFactor)
    }

    private var labelledControlBody: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            HStack(alignment: .firstTextBaseline, spacing: 12 * scaleFactor) {
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: FormRowGeometry.labelColumn(scaleFactor: scaleFactor),
                           alignment: .leading)

                if let options = block.options, !options.isEmpty, let fieldId = block.id {
                    let selection = selectionBinding(fieldId: fieldId, options: options)

                    if block.style == "searchable" || block.style == "multiselect" {
                        // Multiselect stores a CSV string in the same `guidanceFormInputs` slot.
                        SearchablePicker(
                            title: block.content ?? "",
                            allItems: options,
                            selection: selection,
                            allowMultiSelect: block.style == "multiselect",
                            idealWidth: 200 * scaleFactor
                        )
                        .frame(maxWidth: 200 * scaleFactor)
                    } else if brandedControls {
                        // `accentColor: nil`: see `GuidanceCheckboxBlock`.
                        BrandPicker(options: options,
                                    selection: selection,
                                    placeholder: block.content ?? "Select…",
                                    accentColor: nil,
                                    scaleFactor: scaleFactor)
                            .frame(maxWidth: 200 * scaleFactor)
                    } else {
                        Picker("", selection: selection) {
                            ForEach(options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(accentColor ?? palette.accent)
                        .frame(maxWidth: 200 * scaleFactor)
                    }
                } else if let options = block.options, !options.isEmpty {
                    // No id: display-only.
                    Menu {
                        ForEach(options, id: \.self) { option in
                            Button(option) { }
                        }
                    } label: {
                        HStack {
                            Text(block.value ?? "Select...")
                                .font(.system(size: 12 * scaleFactor))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10 * scaleFactor))
                        }
                        .padding(.horizontal, 12 * scaleFactor)
                        .padding(.vertical, 6 * scaleFactor)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(palette.textMuted.opacity(0.1))
                        )
                    }
                    .frame(maxWidth: 200 * scaleFactor)
                    .disabled(true)
                }
            }

            if let helpText = block.helpText, !helpText.isEmpty {
                GuidanceFieldHelp(text: helpText, scaleFactor: scaleFactor)
            }

            if block.required == true {
                GuidanceRequiredHint(scaleFactor: scaleFactor)
            }
        }
        .padding(.vertical, 4 * scaleFactor)
    }
}

// MARK: - Radio (type: "radio")

struct GuidanceRadioBlock<Context: UserInputContext & ObservableObject>: View {
    @Environment(\.brandedControls) private var brandedControls
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    let accentColor: Color?
    let scaleFactor: CGFloat
    var wire = FormWire()

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            if let content = block.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(palette.text)
            }

            if let options = block.options, !options.isEmpty, let fieldId = block.id {
                let selectedValue = Binding(
                    get: {
                        inspectState.guidanceFormInputs[itemId]?.radios[fieldId] ?? block.value ?? ""
                    },
                    set: { newValue in
                        if inspectState.guidanceFormInputs[itemId] == nil {
                            inspectState.initializeGuidanceFormState(for: itemId)
                        }
                        inspectState.guidanceFormInputs[itemId]?.radios[fieldId] = newValue
                        writeLog("GuidanceContentView: Radio '\(fieldId)' set to '\(newValue)'", logLevel: .info)
                        inspectState.writeToInteractionLog(
                            wire.line(type: "radio", owner: itemId, field: fieldId, value: newValue))
                        wire.onValueCommit?(fieldId, newValue)
                    }
                )

                if brandedControls {
                    // `BrandRadioGroup` is readable as a radio group by VoiceOver; the
                    // hand-rolled arm below is not.
                    BrandRadioGroup(options: options,
                                    selection: selectedValue,
                                    accessibilityLabel: block.content ?? "",
                                    accentColor: nil,
                                    scaleFactor: scaleFactor)
                        .padding(.leading, 4 * scaleFactor)
                } else {
                    VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                        ForEach(options, id: \.self) { option in
                            HStack {
                                Image(systemName: option == selectedValue.wrappedValue ? "circle.inset.filled" : "circle")
                                    .font(.system(size: 14 * scaleFactor))
                                    .foregroundStyle(option == selectedValue.wrappedValue ? (accentColor ?? palette.accent) : palette.textMuted)

                                Text(option)
                                    .font(.system(size: 13 * scaleFactor))
                                    .foregroundStyle(palette.text)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedValue.wrappedValue = option
                            }
                        }
                    }
                    .padding(.leading, 4 * scaleFactor)
                }
            } else if let options = block.options, !options.isEmpty {
                // No id: display-only.
                VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                    ForEach(options, id: \.self) { option in
                        HStack {
                            Image(systemName: option == block.value ? "circle.inset.filled" : "circle")
                                .font(.system(size: 14 * scaleFactor))
                                .foregroundStyle(option == block.value ? (accentColor ?? palette.accent) : palette.textMuted)

                            Text(option)
                                .font(.system(size: 13 * scaleFactor))
                                .foregroundStyle(palette.text)
                        }
                    }
                }
                .padding(.leading, 4 * scaleFactor)
            }

            if let helpText = block.helpText, !helpText.isEmpty {
                GuidanceFieldHelp(text: helpText, scaleFactor: scaleFactor)
            }

            if block.required == true {
                GuidanceRequiredHint(scaleFactor: scaleFactor)
            }
        }
        .padding(.vertical, 4 * scaleFactor)
    }
}

// MARK: - Toggle (type: "toggle")

struct GuidanceToggleBlock<Context: UserInputContext & ObservableObject>: View {
    @Environment(\.brandedControls) private var brandedControls
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat
    var wire = FormWire()

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                if let content = block.content {
                    Text(content)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(palette.text)
                }

                if let helpText = block.helpText, !helpText.isEmpty {
                    GuidanceFieldHelp(text: helpText, scaleFactor: scaleFactor)
                }
            }
            // Fixed label column, not a trailing switch: a step mixes toggles with other
            // controls and they must share one column.
            .frame(width: FormRowGeometry.labelColumn(scaleFactor: scaleFactor), alignment: .leading)

            if let fieldId = block.id {
                let isOn = Binding(
                    get: {
                        inspectState.guidanceFormInputs[itemId]?.toggles[fieldId] ?? (block.value == "true")
                    },
                    set: { newValue in
                        if inspectState.guidanceFormInputs[itemId] == nil {
                            inspectState.initializeGuidanceFormState(for: itemId)
                        }
                        inspectState.guidanceFormInputs[itemId]?.toggles[fieldId] = newValue
                        writeLog("GuidanceContentView: Toggle '\(fieldId)' set to \(newValue)", logLevel: .info)

                        inspectState.writeToInteractionLog(
                            wire.line(type: "toggle", owner: itemId, field: fieldId, value: "\(newValue)"))
                        wire.onValueCommit?(fieldId, newValue)
                    }
                )

                if brandedControls {
                    // `accentColor: nil`: see `GuidanceCheckboxBlock`.
                    BrandToggle(isOn: isOn,
                                accessibilityLabel: block.content ?? "",
                                accentColor: nil,
                                scaleFactor: scaleFactor)
                } else {
                    Toggle("", isOn: isOn)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .tint(accentColor ?? palette.accent)
                }
            }
        }
        .padding(.vertical, 4 * scaleFactor)
    }
}

// MARK: - Slider (type: "slider")

struct GuidanceSliderBlock<Context: UserInputContext & ObservableObject>: View {
    @Environment(\.brandedControls) private var brandedControls
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat
    var wire = FormWire()

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            HStack {
                // Sliders are authored with either `label` or `content`.
                if let label = block.label ?? block.content, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 13 * scaleFactor, weight: .medium))
                        .foregroundStyle(palette.text)
                }

                if let helpText = block.helpText, !helpText.isEmpty {
                    GuidanceFieldHelp(text: helpText, scaleFactor: scaleFactor)
                }
            }
            .frame(width: FormRowGeometry.labelColumn(scaleFactor: scaleFactor), alignment: .leading)
            Group {

                if let fieldId = block.id {
                    let currentValue = inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] ??
                                      Double(block.value ?? "0") ?? 0.0

                    if let steps = block.discreteSteps,
                       let matchingStep = steps.first(where: { $0.value == currentValue }) {
                        Text(matchingStep.label)
                            .font(.system(size: 13 * scaleFactor, weight: .medium))
                            .foregroundStyle(palette.textMuted)
                    } else {
                        HStack(spacing: 4 * scaleFactor) {
                            Text("\(Int(currentValue))")
                                .font(.system(size: 13 * scaleFactor, weight: .medium))
                                .foregroundStyle(palette.textMuted)

                            if let unit = block.unit {
                                Text(unit)
                                    .font(.system(size: 12 * scaleFactor))
                                    .foregroundStyle(palette.textMuted)
                            }
                        }
                    }
                }
            }

            if let fieldId = block.id {
                if let steps = block.discreteSteps, steps.count >= 2 {
                    // The slider moves between step indices; the stored value is the step's value.
                    let stepCount = steps.count
                    let sortedSteps = steps.sorted { $0.value < $1.value }

                    let discreteBinding = Binding(
                        get: {
                            let value = inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] ??
                                       Double(block.value ?? "\(sortedSteps[0].value)") ?? sortedSteps[0].value
                            return Double(sortedSteps.firstIndex { $0.value == value } ?? 0)
                        },
                        set: { newIndex in
                            let clampedIndex = Int(max(0, min(newIndex, Double(stepCount - 1))))
                            let newValue = sortedSteps[clampedIndex].value

                            if inspectState.guidanceFormInputs[itemId] == nil {
                                inspectState.initializeGuidanceFormState(for: itemId)
                            }
                            inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] = newValue
                            writeLog("GuidanceContentView: Slider '\(fieldId)' set to \(newValue) (\(sortedSteps[clampedIndex].label))", logLevel: .info)

                            inspectState.writeToInteractionLog(
                                wire.line(type: "slider", owner: itemId, field: fieldId,
                                          value: wire.sliderWireValue(newValue)))
                            wire.commitSlider(fieldId, newValue)
                        }
                    )

                    if brandedControls {
                        // `.tint()` does not colour a native slider's track in dark mode.
                        // `accentColor: nil`: see `GuidanceCheckboxBlock`.
                        BrandSlider(value: discreteBinding,
                                    range: 0...Double(stepCount - 1),
                                    step: 1,
                                    accessibilityLabel: block.content ?? "",
                                    accentColor: nil,
                                    scaleFactor: scaleFactor)
                    } else {
                        Slider(value: discreteBinding, in: 0...Double(stepCount - 1), step: 1)
                            .tint(accentColor ?? palette.accent)
                    }
                } else {
                    let minValue = block.min ?? 0.0
                    let maxValue = block.max ?? 100.0
                    let stepValue = block.step ?? 1.0

                    let sliderBinding = Binding(
                        get: {
                            inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] ??
                            Double(block.value ?? "\(minValue)") ?? minValue
                        },
                        set: { newValue in
                            if inspectState.guidanceFormInputs[itemId] == nil {
                                inspectState.initializeGuidanceFormState(for: itemId)
                            }
                            inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] = newValue
                            writeLog("GuidanceContentView: Slider '\(fieldId)' set to \(newValue)", logLevel: .info)

                            inspectState.writeToInteractionLog(
                                wire.line(type: "slider", owner: itemId, field: fieldId,
                                          value: wire.sliderWireValue(newValue)))
                            wire.commitSlider(fieldId, newValue)
                        }
                    )

                    if brandedControls {
                        BrandSlider(value: sliderBinding,
                                    range: minValue...maxValue,
                                    step: stepValue,
                                    accessibilityLabel: block.content ?? "",
                                    accentColor: nil,
                                    scaleFactor: scaleFactor)
                    } else {
                        Slider(value: sliderBinding, in: minValue...maxValue, step: stepValue)
                            .tint(accentColor ?? palette.accent)
                    }
                }
            }
        }
        .padding(.vertical, 4 * scaleFactor)
    }
}

// MARK: - Button (type: "button")

struct GuidanceActionButtonBlock<Context: UserInputContext>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    let inspectState: Context
    let accentColor: Color?
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        if let buttonLabel = block.content {
            let isLink = GuidanceButtonStyle(lenient: block.buttonStyle) == .link
            // A link ignores a muted `accentColor`: colour is its only affordance.
            let tint = isLink ? palette.accent : (accentColor ?? palette.accent)
            let styled = applyButtonStyle(
                Button(action: {
                    handleButtonAction(block: block, itemId: itemId, inspectState: inspectState)
                }) {
                    if let icon = block.icon {
                        Label(buttonLabel, systemImage: icon)
                    } else {
                        Text(buttonLabel)
                    }
                }
                .controlSize(.regular),
                styleString: block.buttonStyle
            )
            .tint(tint)

            // `.link` draws in `NSColor.linkColor` and honours only `foregroundStyle`; on the
            // filled style the same modifier would paint the label in its own fill colour.
            if isLink {
                styled.foregroundStyle(tint)
            } else {
                styled
            }
        }
    }
}


// MARK: - Field help

/// The one-line explanation under the field it belongs to.
struct GuidanceFieldHelp: View {
    let text: String
    let scaleFactor: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(.system(size: 11 * scaleFactor))
            .foregroundStyle(palette.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
