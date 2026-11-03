//
//  GroupedInputsView.swift
//  dialog
//
//  Renders inputs placed by an extended `vieworder`: individual inputs of any type in any
//  order, collected into optional titled groups. Each row reuses the existing input view,
//  restricted to one item and drawn without its own box, so the rows behave exactly as they do
//  in the original per-type layout.
//

import SwiftUI

/// Grey subtext under an input's title. Draws nothing when the text is empty, so inputs
/// without `detail` lay out exactly as they always have.
struct DetailText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension View {
    /// The rounded box the per-type input views draw around their rows. Rows placed in a group
    /// are `embedded` and skip it, because the group draws one box around all of its rows.
    @ViewBuilder
    func inputBox(embedded: Bool) -> some View {
        if embedded {
            self
        } else {
            self.padding(10)
                .background(Color.background.opacity(0.5))
                .cornerRadius(8)
        }
    }
}

/// Applies `enabledif` / `visibleif`: hides the control while `visibleIf` is false and disables it
/// while `enabledIf` is false. Without conditions the content is passed through untouched.
struct ControlDependencyModifier: ViewModifier {
    @ObservedObject var observedData: DialogUpdatableContent
    let enabledIf: String
    let visibleIf: String

    func body(content: Content) -> some View {
        if enabledIf.isEmpty && visibleIf.isEmpty {
            content
        } else {
            let values = observedData.currentControlValues()
            if ControlCondition.evaluate(visibleIf, values: values) {
                content.disabled(!ControlCondition.evaluate(enabledIf, values: values))
            }
        }
    }
}

extension View {
    func controlDependencies(_ observedData: DialogUpdatableContent, enabledIf: String, visibleIf: String) -> some View {
        modifier(ControlDependencyModifier(observedData: observedData, enabledIf: enabledIf, visibleIf: visibleIf))
    }
}

struct GroupedInputsView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    let groups: [ResolvedViewLayoutGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(groups) { group in
                let rows = visibleRows(in: group)
                if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if let title = group.title {
                        Text(title)
                            .font(.headline)
                            .padding(.leading, 4)
                    }
                    if let description = group.description {
                        DetailText(description)
                            .padding(.leading, 4)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { position, row in
                            if position > 0 {
                                Divider().opacity(0.5)
                            }
                            rowView(row)
                                .padding(.vertical, 6)
                        }
                    }
                    .modifier(NumberColumnsModifier(inputs: numberInputs(in: group),
                                                    fontSize: observedData.appProperties.labelFontSize))
                    .font(.system(size: observedData.appProperties.labelFontSize))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.background.opacity(0.5))
                    .cornerRadius(8)
                    if let footer = group.footer {
                        DetailText(footer)
                            .padding(.leading, 4)
                    }
                }
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, appDefaults.contentPadding)
    }

    /// `visibleif` of a placed row ("" when it has none)
    private func visibleIf(for row: ViewLayoutRow) -> String {
        let state = observedData.observedUserInputState
        switch row {
        case .textField(let index):
            return observedData.textFieldArray.indices.contains(index) ? observedData.textFieldArray[index].visibleIf : ""
        case .checkbox(let index):
            return state.checkBoxes.indices.contains(index) ? state.checkBoxes[index].visibleIf : ""
        case .radio(let index), .dropdown(let index):
            return state.dropdownItems.indices.contains(index) ? state.dropdownItems[index].visibleIf : ""
        case .slider(let index), .stepper(let index):
            return state.numberInputs.indices.contains(index) ? state.numberInputs[index].visibleIf : ""
        case .button(let index):
            return state.buttonRows.indices.contains(index) ? state.buttonRows[index].visibleIf : ""
        case .block:
            return ""
        }
    }

    /// The rows of a group that are currently shown, so hidden rows leave no gap or extra divider
    /// (and a group with nothing to show disappears with its title and footer)
    private func visibleRows(in group: ResolvedViewLayoutGroup) -> [ViewLayoutRow] {
        let conditions = group.rows.map { visibleIf(for: $0) }
        guard conditions.contains(where: { !$0.isEmpty }) else { return group.rows }
        let values = observedData.currentControlValues()
        return zip(group.rows, conditions).filter { ControlCondition.evaluate($0.1, values: values) }.map { $0.0 }
    }

    /// The sliders and steppers in a group, whose column widths are shared so they line up
    private func numberInputs(in group: ResolvedViewLayoutGroup) -> [NumberInput] {
        let numbers = observedData.observedUserInputState.numberInputs
        return group.rows.compactMap { row in
            switch row {
            case .slider(let index), .stepper(let index):
                return numbers.indices.contains(index) ? numbers[index] : nil
            default:
                return nil
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: ViewLayoutRow) -> some View {
        switch row {
        case .textField(let index):
            TextEntryView(observedDialogContent: observedData, indices: [index], embedded: true)
                .id("\(observedData.currentCardIndex)-text-\(index)")
        case .checkbox(let index):
            RenderToggles(observedDialogContent: observedData, indices: [index], embedded: true)
                .id("\(observedData.currentCardIndex)-check-\(index)")
        case .radio(let index):
            RadioView(observedDialogContent: observedData, indices: [index], embedded: true)
                .id("\(observedData.currentCardIndex)-radio-\(index)")
        case .dropdown(let index):
            DropdownView(observedDialogContent: observedData, indices: [index], embedded: true)
                .id("\(observedData.currentCardIndex)-select-\(index)")
        case .button(let index):
            ButtonRowView(observedDialogContent: observedData, indices: [index], embedded: true)
                .id("\(observedData.currentCardIndex)-button-\(index)")
        case .slider(let index), .stepper(let index):
            NumberInputView(observedDialogContent: observedData, indices: [index], embedded: true)
                .id("\(observedData.currentCardIndex)-number-\(index)")
        case .block(let type):
            switch type {
            case .textfile:
                TextFileView(logFilePath: observedData.args.logFileToTail.value,
                             loadHistory: observedData.args.logFileHistory.present,
                             historyLineLimit: Int(observedData.args.logFileHistory.value) ?? appvars.logFileHistory)
                    .frame(height: cardState.isNavigationStyle ? 250 : nil)
            case .webcontent:
                WebContentView(observedDialogContent: observedData, url: observedData.args.webcontent.value)
                    .frame(height: cardState.isNavigationStyle ? 250 : nil)
            case .listitem:
                ListView(observedDialogContent: observedData)
                    .id(observedData.currentCardIndex)
                    .frame(height: cardState.isNavigationStyle ? 250 : nil)
            default:
                EmptyView()
            }
        }
    }
}
