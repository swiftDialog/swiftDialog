//
//  ButtonRowView.swift
//  dialog
//
//  Page buttons (--button / "button"): a row of one or more buttons that act immediately
//  (open a URL, run a script, show a sheet), plus colour wells and read-only info values.
//  Selectable rows behave like a radio choice (colour swatches, appearance thumbnails).
//

import SwiftUI
import Textual

struct ButtonRowView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    /// Only draw these rows (nil = all). Used when `vieworder` places inputs individually.
    var indices: [Int]?
    /// Drawn inside a group, which supplies the surrounding box and dividers
    var embedded: Bool = false

    init(observedDialogContent: DialogUpdatableContent, indices: [Int]? = nil, embedded: Bool = false) {
        self.observedData = observedDialogContent
        self.indices = indices
        self.embedded = embedded
    }

    var body: some View {
        let rows = observedData.observedUserInputState.buttonRows
        if !rows.isEmpty {
            let visible = (indices ?? Array(rows.indices)).filter { rows.indices.contains($0) }
            VStack {
                ForEach(visible, id: \.self) { rowIndex in
                    Group {
                        rowView(rows[rowIndex])
                        if !embedded && rowIndex != visible.last {
                            Divider().opacity(0.5)
                        }
                    }
                    .controlDependencies(observedData, enabledIf: rows[rowIndex].enabledIf, visibleIf: rows[rowIndex].visibleIf)
                }
            }
            .font(.system(size: observedData.appProperties.labelFontSize))
            .inputBox(embedded: embedded)
        }
    }

    @ViewBuilder
    private func rowView(_ row: ButtonRow) -> some View {
        let hasTitle = !row.title.isEmpty || !row.detail.isEmpty
        HStack(alignment: .center) {
            if hasTitle {
                VStack(alignment: .leading, spacing: 2) {
                    if !row.title.isEmpty { Text(row.title) }
                    DetailText(row.detail)
                }
                Spacer()
            } else if row.alignment != "leading" {
                Spacer()
            }
            HStack(alignment: .top, spacing: row.style == "plain" ? 14 : 8) {
                ForEach(row.items) { item in
                    ButtonItemView(observedData: observedData, row: row, item: item)
                        .controlDependencies(observedData, enabledIf: item.enabledIf, visibleIf: "")
                }
            }
            if !hasTitle && row.alignment != "trailing" {
                Spacer()
            }
        }
    }
}

struct ButtonItemView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    let row: ButtonRow
    let item: ButtonItem

    @State private var hovering = false

    private var isSelected: Bool {
        row.selectable && !item.value.isEmpty && row.selectedValue == item.value
    }

    private var hasGraphic: Bool { !item.symbol.isEmpty || !item.image.isEmpty }

    /// This row draws labels under its buttons (swatches / thumbnails) rather than inside them
    private var usesCaptions: Bool {
        item.display != "symbol" && !item.label.isEmpty &&
        (row.labelPosition == "below" || row.labelPosition == "selected")
    }

    /// The caption is visible: always for "below", only for the selected or hovered item for "selected"
    private var captionBelow: Bool {
        usesCaptions && (row.labelPosition == "below" || isSelected || hovering)
    }

    /// Text shown inside the button
    private var showsInlineLabel: Bool {
        guard !item.label.isEmpty, row.labelPosition == "inline" else { return false }
        if item.display == "symbol" && hasGraphic { return false }
        return true
    }

    private var showsGraphic: Bool {
        hasGraphic && item.display != "label"
    }

    private var graphicSize: CGFloat {
        if row.size > 0 { return row.size }
        return row.style == "plain" ? 28 : 14
    }

    var body: some View {
        control
            // Room for the caption is always reserved, and the caption is drawn as an overlay, so showing
            // or hiding it (or making it bold) never changes the size of an item or moves its neighbours.
            .padding(.bottom, usesCaptions ? 18 : 0)
            .overlay(alignment: .bottom) {
                if captionBelow {
                    Text(item.label)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .allowsHitTesting(false)
                }
            }
            .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var control: some View {
        switch item.type {
        case "info":
            Text(item.value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case "colour":
            ColorPicker(item.label, selection: colourBinding, supportsOpacity: item.opacity)
                .labelsHidden()
                .disabled(item.disabled)
                .help(item.label)
        default:
            actionButton
        }
    }

    // MARK: Colour

    private var colourBinding: Binding<Color> {
        Binding(
            get: { Color(argument: item.value.isEmpty ? "#000000" : item.value) },
            set: { newColour in
                let hex = newColour.hexString
                observedData.updateButton(id: item.id) { $0.value = hex }
            })
    }

    // MARK: Action button

    private var actionButton: some View {
        let symbolOnly = showsGraphic && !showsInlineLabel
        return Button {
            observedData.clickButton(rowID: row.id, itemID: item.id)
        } label: {
            content
                // While the spinner is up the label is dimmed right back so it doesn't compete with it
                .opacity(item.showSpinner ? 0.2 : (item.isRunning ? 0.5 : 1))
                .overlay { if item.showSpinner { spinnerBadge } }
        }
        .modifier(ButtonRowStyle(plain: row.style == "plain", circular: symbolOnly))
        .overlay { selectionRing }
        .disabled(item.disabled)
        .help(item.label)
        .accessibilityLabel(item.label.isEmpty ? item.name : item.label)
    }

    /// The spinner on a backing layer, so it reads clearly over the dimmed label. A material adapts to
    /// light and dark appearance by itself.
    private var spinnerBadge: some View {
        ProgressView()
            .controlSize(.small)
            .padding(5)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 6) {
            if showsGraphic { graphic }
            if showsInlineLabel { Text(item.label) }
        }
    }

    @ViewBuilder
    private var graphic: some View {
        if !item.image.isEmpty {
            IconView(image: item.image, sfPaddingEnabled: false)
                .frame(width: graphicSize * (row.style == "plain" ? 2 : 1),
                       height: graphicSize * (row.style == "plain" ? 1.4 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            let spec = ButtonSymbolSpec(item.symbol)
            let size = spec.size ?? graphicSize
            let base = Image(systemName: spec.name).font(.system(size: size))
            if spec.palette.count >= 2 {
                base.symbolRenderingMode(.palette)
                    .foregroundStyle(spec.palette[0], spec.palette[1], spec.palette.count > 2 ? spec.palette[2] : spec.palette[1])
            } else if let colour = spec.colour {
                base.symbolRenderingMode(spec.mode ?? .monochrome).foregroundStyle(colour)
            } else {
                base.symbolRenderingMode(spec.mode ?? .monochrome)
            }
        }
    }

    @ViewBuilder
    private var selectionRing: some View {
        if isSelected {
            if item.image.isEmpty && row.style == "plain" {
                Circle().stroke(Color.accentColor, lineWidth: 2.5).padding(-2).allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: item.image.isEmpty ? 8 : 10)
                    .stroke(Color.accentColor, lineWidth: 2.5)
                    .padding(-2)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Bordered (standard push button, round when it only has a symbol) or plain (no surround)
private struct ButtonRowStyle: ViewModifier {
    let plain: Bool
    let circular: Bool

    func body(content: Content) -> some View {
        if plain {
            content.buttonStyle(.plain)
        } else if circular {
            content.buttonStyle(.bordered).buttonBorderShape(.circle)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

/// Sheet showing markdown text from a button's `sheet` action: like the help sheet, but for any message.
struct MessageSheetView: View {
    let content: MessageSheetContent
    let onClose: () -> Void

    var settings: AppDefaults = .init()

    var body: some View {
        VStack {
            HStack {
                StructuredText(content.text, parser: ColoredMarkdownParser())
                    .textual.structuredTextStyle(.gitHub)
                    .padding(32)
                    .focusable(false)
                if !content.image.isEmpty {
                    Divider()
                        .padding(settings.sidePadding)
                        .frame(width: 2)
                    IconView(image: content.image)
                        .frame(height: 160)
                        .padding(.leading, settings.sidePadding)
                        .padding(.trailing, settings.sidePadding)
                }
            }
            Spacer()
            Button(content.buttonText.isEmpty ? "OK".localized : content.buttonText) {
                onClose()
            }
            .padding(settings.sidePadding)
            .keyboardShortcut(.defaultAction)
        }
        .frame(minWidth: 400)
        .fixedSize()
    }
}
