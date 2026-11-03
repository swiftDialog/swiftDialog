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

struct GroupedInputsView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    let groups: [ResolvedViewLayoutGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(groups) { group in
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
                        ForEach(Array(group.rows.enumerated()), id: \.offset) { position, row in
                            if position > 0 {
                                Divider().opacity(0.5)
                            }
                            rowView(row)
                                .padding(.vertical, 6)
                        }
                    }
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
        .padding(.bottom, appDefaults.contentPadding)
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
