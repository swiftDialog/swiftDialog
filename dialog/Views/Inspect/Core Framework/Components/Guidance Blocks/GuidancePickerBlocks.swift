//
//  GuidancePickerBlocks.swift
//  dialog
//
//  Picker blocks, selections from a known set: segmented, stepper, search, multi-select, the
//  select list/grid, and the identity, action-row and signature-preview cards.
//

import SwiftUI

// MARK: - Segmented (type: "segmented")

/// Two to four short options, all visible at once; more or longer belongs in a menu.
struct GuidanceSegmentedBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat
    var wire = FormWire()       // host-declared log line shape and commit side effects

    private var selection: Binding<String> {
        Binding(
            get: { inspectState.guidanceFormInputs[itemId]?.dropdowns[block.id ?? ""] ?? block.value ?? "" },
            set: { newValue in
                guard let fieldId = block.id else { return }
                if inspectState.guidanceFormInputs[itemId] == nil {
                    inspectState.initializeGuidanceFormState(for: itemId)
                }
                inspectState.guidanceFormInputs[itemId]?.dropdowns[fieldId] = newValue
                inspectState.writeToInteractionLog(
                    wire.line(type: "segmented", owner: itemId, field: fieldId, value: newValue))
                wire.onValueCommit?(fieldId, newValue)
            }
        )
    }

    @Environment(\.palette) private var palette
    @Environment(\.brandedControls) private var brandedControls

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            if let label = block.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
            }

            // Control and help on one line when they fit, else the help drops underneath.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12 * scaleFactor) {
                    picker
                    help
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                    picker
                    help
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var picker: some View {
        if brandedControls {
            // Opt-in: the native control ignores `.tint()` in dark appearance.
            BrandSegmented(options: block.options ?? [],
                           selection: selection,
                           accessibilityLabel: block.label ?? block.content ?? "",
                           accentColor: nil,
                           scaleFactor: scaleFactor)
                // No `.fixedSize`: this control divides the offered width evenly between segments.
                .frame(maxWidth: 340 * scaleFactor, alignment: .leading)
        } else {
            Picker("", selection: selection) {
                ForEach(block.options ?? [], id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .tint(accentColor ?? palette.accent)
            .frame(maxWidth: 340 * scaleFactor, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    @ViewBuilder
    private var help: some View {
        if let helpText = block.helpText, !helpText.isEmpty {
            GuidanceFieldHelp(text: helpText, scaleFactor: scaleFactor)
        }
    }
}

// MARK: - Stepper (type: "stepper")

/// A small integer the user nudges rather than types; `min`/`max` are enforced on every step.
struct GuidanceStepperBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat

    private var lowerBound: Int { Int(block.min ?? 0) }
    private var upperBound: Int { Int(block.max ?? 99) }

    private var value: Int {
        let stored = inspectState.guidanceFormInputs[itemId]?.textfields[block.id ?? ""]
        return Int(stored ?? block.value ?? "") ?? lowerBound
    }

    private func set(_ newValue: Int) {
        guard let fieldId = block.id else { return }
        let clamped = min(max(newValue, lowerBound), upperBound)
        if inspectState.guidanceFormInputs[itemId] == nil {
            inspectState.initializeGuidanceFormState(for: itemId)
        }
        inspectState.guidanceFormInputs[itemId]?.textfields[fieldId] = "\(clamped)"
        appendToInteractionLog("stepper:\(fieldId):\(clamped)")
    }

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            if let label = block.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
            }

            HStack(spacing: 10 * scaleFactor) {
                Text("\(value)")
                    .font(.system(size: 17 * scaleFactor, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 26 * scaleFactor, alignment: .leading)

                HStack(spacing: 0) {
                    stepButton("minus") { set(value - 1) }
                        .disabled(value <= lowerBound)
                    Divider().frame(height: 18 * scaleFactor)
                    stepButton("plus") { set(value + 1) }
                        .disabled(value >= upperBound)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6 * scaleFactor, style: .continuous)
                        .stroke(palette.textMuted.opacity(0.3), lineWidth: 1)
                )

                if let unit = block.unit, !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                }
            }

            if let helpText = block.helpText, !helpText.isEmpty {
                GuidanceFieldHelp(text: helpText, scaleFactor: scaleFactor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11 * scaleFactor, weight: .semibold))
                .frame(width: 26 * scaleFactor, height: 22 * scaleFactor)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search (type: "search")

/// A search field for filtering a set too large to show at once.
struct GuidanceSearchBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    private var query: Binding<String> {
        Binding(
            get: { inspectState.guidanceFormInputs[itemId]?.textfields[block.id ?? ""] ?? "" },
            set: { newValue in
                guard let fieldId = block.id else { return }
                if inspectState.guidanceFormInputs[itemId] == nil {
                    inspectState.initializeGuidanceFormState(for: itemId)
                }
                inspectState.guidanceFormInputs[itemId]?.textfields[fieldId] = newValue
                appendToInteractionLog("search:\(fieldId):\(newValue)")
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            if let label = block.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
            }

            HStack(spacing: 7 * scaleFactor) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(palette.textMuted)

                TextField(block.placeholder ?? "Search", text: query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13 * scaleFactor))

                if !query.wrappedValue.isEmpty {
                    Button { query.wrappedValue = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12 * scaleFactor))
                            .foregroundStyle(palette.textFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9 * scaleFactor)
            .padding(.vertical, 6 * scaleFactor)
            .frame(maxWidth: 340 * scaleFactor)
            .overlay(
                RoundedRectangle(cornerRadius: 7 * scaleFactor, style: .continuous)
                    .stroke(palette.textMuted.opacity(0.3), lineWidth: 1)
            )

            if let helpText = block.helpText, !helpText.isEmpty {
                GuidanceFieldHelp(text: helpText, scaleFactor: scaleFactor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Multi-select (type: "multi-select")

/// Several answers from one set as removable tokens; the remaining options sit behind a menu.
struct GuidanceMultiSelectBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat

    private var selected: [String] {
        let raw = inspectState.guidanceFormInputs[itemId]?.textfields[block.id ?? ""] ?? block.value ?? ""
        return raw.split(separator: "\u{001F}").map(String.init).filter { !$0.isEmpty }
    }

    private var available: [String] {
        (block.options ?? []).filter { !selected.contains($0) }
    }

    private func store(_ values: [String]) {
        guard let fieldId = block.id else { return }
        if inspectState.guidanceFormInputs[itemId] == nil {
            inspectState.initializeGuidanceFormState(for: itemId)
        }
        // Unit separator, not a comma: an option may contain a comma.
        inspectState.guidanceFormInputs[itemId]?.textfields[fieldId] = values.joined(separator: "\u{001F}")
        appendToInteractionLog("multiselect:\(fieldId):\(values.joined(separator: ","))")
    }

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            if let label = block.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
            }

            FlowingTokens(spacing: 6 * scaleFactor) {
                ForEach(selected, id: \.self) { value in
                    HStack(spacing: 5 * scaleFactor) {
                        Text(value)
                            .font(.system(size: 12 * scaleFactor))
                        Button {
                            store(selected.filter { $0 != value })
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9 * scaleFactor, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.textMuted)
                    }
                    .padding(.horizontal, 9 * scaleFactor)
                    .padding(.vertical, 4 * scaleFactor)
                    .background(
                        Capsule().fill((accentColor ?? palette.accent).opacity(0.10))
                    )
                }

                if !available.isEmpty {
                    Menu {
                        ForEach(available, id: \.self) { option in
                            Button(option) { store(selected + [option]) }
                        }
                    } label: {
                        HStack(spacing: 4 * scaleFactor) {
                            Image(systemName: "plus")
                                .font(.system(size: 9 * scaleFactor, weight: .semibold))
                            Text(block.placeholder ?? "Add")
                                .font(.system(size: 12 * scaleFactor))
                        }
                        .padding(.horizontal, 9 * scaleFactor)
                        .padding(.vertical, 4 * scaleFactor)
                        .overlay(
                            Capsule().stroke(palette.textMuted.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }

            if let helpText = block.helpText, !helpText.isEmpty {
                GuidanceFieldHelp(text: helpText, scaleFactor: scaleFactor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Tokens that wrap onto the next line instead of truncating.
struct FlowingTokens: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Select list / grid (type: "select-list" | "select-grid")

/// Check-row list or 2-up tile grid of yes/no choices. Options, details and icons ride the same
/// parallel arrays as `radio`; `requiredOptions` rows render locked and always count as selected.
/// Stored like the multi-select (unit-separated labels under the block id); `value` seeds the
/// preselection as comma-separated labels.
struct GuidanceSelectBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat
    var iconBasePath: String?
    @Environment(\.palette) private var palette

    private var accent: Color { accentColor ?? palette.accent }
    private var options: [String] { block.options ?? [] }
    private var required: Set<String> { Set(block.requiredOptions ?? []) }

    private var selected: Set<String> {
        let stored = inspectState.guidanceFormInputs[itemId]?.textfields[block.id ?? ""]
        let raw: [String]
        if let stored {
            raw = stored.split(separator: "\u{001F}").map(String.init)
        } else {
            raw = (block.value ?? "").split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return Set(raw.filter { !$0.isEmpty }).union(required)
    }

    private func toggle(_ option: String) {
        guard !required.contains(option), let fieldId = block.id else { return }
        var now = selected
        if now.contains(option) { now.remove(option) } else { now.insert(option) }
        if inspectState.guidanceFormInputs[itemId] == nil {
            inspectState.initializeGuidanceFormState(for: itemId)
        }
        let ordered = options.filter { now.contains($0) }
        inspectState.guidanceFormInputs[itemId]?.textfields[fieldId]
            = ordered.joined(separator: "\u{001F}")
        appendToInteractionLog("select:\(fieldId):\(ordered.joined(separator: ","))")
    }

    private func detail(for index: Int) -> String? {
        guard let details = block.optionDetails, details.indices.contains(index) else { return nil }
        return details[index]
    }
    private func icon(for index: Int) -> String? {
        guard let icons = block.optionIcons, icons.indices.contains(index) else { return nil }
        return icons[index]
    }

    var body: some View {
        if block.type == "select-grid" {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12 * scaleFactor),
                                GridItem(.flexible())], spacing: 12 * scaleFactor) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    Button { toggle(option) } label: {
                        VStack(alignment: .leading, spacing: 10 * scaleFactor) {
                            HStack(alignment: .top) {
                                if let icon = icon(for: index) {
                                    GuidanceInlineIcon(icon: icon, size: 32 * scaleFactor,
                                                       basePath: iconBasePath, tint: accent)
                                }
                                Spacer(minLength: 0)
                                checkSquare(option)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option)
                                    .font(.system(size: 14 * scaleFactor, weight: .semibold))
                                    .foregroundStyle(palette.text.opacity(0.9))
                                if let detail = detail(for: index) {
                                    Text(detail)
                                        .font(.system(size: 12 * scaleFactor, design: .monospaced))
                                        .foregroundStyle(palette.text.opacity(0.5))
                                }
                            }
                        }
                        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.text.opacity(0.035)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option): \(selected.contains(option) ? "selected" : "not selected")")
                }
            }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    if index > 0 {
                        Rectangle().fill(palette.text.opacity(0.08))
                            .frame(height: 0.5)
                            .padding(.leading, 48)
                    }
                    Button { toggle(option) } label: {
                        HStack(spacing: 13) {
                            checkSquare(option)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option)
                                    .font(.system(size: 14 * scaleFactor, weight: .semibold))
                                    .foregroundStyle(palette.text.opacity(0.9))
                                if let detail = detail(for: index) {
                                    Text(detail)
                                        .font(.system(size: 11.5 * scaleFactor))
                                        .foregroundStyle(palette.text.opacity(0.5))
                                }
                            }
                            Spacer(minLength: 8)
                            if let icon = icon(for: index) {
                                GuidanceInlineIcon(icon: icon, size: 28 * scaleFactor,
                                                   basePath: iconBasePath, tint: accent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option): \(selected.contains(option) ? "selected" : "not selected")")
                }
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.text.opacity(0.035)))
        }
    }

    @ViewBuilder private func checkSquare(_ option: String) -> some View {
        let isOn = selected.contains(option)
        let locked = required.contains(option)
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isOn ? accent.opacity(locked ? 0.55 : 1) : Color.clear)
            if !isOn {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(palette.text.opacity(0.3), lineWidth: 1.5)
            }
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 10 * scaleFactor, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 19 * scaleFactor, height: 19 * scaleFactor)
    }
}

// MARK: - Identity card (type: "identity")

/// The "Is this you?" card: `icon` as a circular avatar, `label` the name, `note` the subline.
struct GuidanceIdentityBlock: View {
    let block: InspectConfig.GuidanceContent
    let scaleFactor: CGFloat
    var accentColor: Color?
    var iconBasePath: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 16 * scaleFactor) {
            Group {
                if let icon = block.icon {
                    GuidanceInlineIcon(icon: icon, size: 52 * scaleFactor,
                                       basePath: iconBasePath, tint: accentColor)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(palette.text.opacity(0.25))
                }
            }
            .frame(width: 52 * scaleFactor, height: 52 * scaleFactor)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(block.label ?? block.content ?? "")
                    .font(.system(size: 17 * scaleFactor, weight: .bold))
                    .foregroundStyle(palette.text)
                if let note = block.note {
                    Text(note)
                        .font(.system(size: 12.5 * scaleFactor))
                        .foregroundStyle(palette.text.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18 * scaleFactor)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.text.opacity(0.035)))
    }
}

// MARK: - Action rows (type: "action-rows")

/// Status rows with a per-row action pill, or a done tick once the row is in `value` (the
/// comma-separated done list, updatable live via `update_guidance`). Rows ride the option
/// parallel arrays; `optionActions` / `optionURLs` carry the buttons.
struct GuidanceActionRowsBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    var accentColor: Color?
    let scaleFactor: CGFloat
    var iconBasePath: String?
    @Environment(\.palette) private var palette

    private var accent: Color { accentColor ?? palette.accent }
    private var done: Set<String> {
        Set((block.value ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
    private func at(_ array: [String]?, _ i: Int) -> String? {
        guard let array, array.indices.contains(i), !array[i].isEmpty else { return nil }
        return array[i]
    }

    var body: some View {
        let options = block.options ?? []
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                if index > 0 {
                    Rectangle().fill(palette.text.opacity(0.08))
                        .frame(height: 0.5)
                        .padding(.leading, 61)
                }
                let isDone = done.contains(option)
                HStack(spacing: 13) {
                    if let icon = at(block.optionIcons, index) {
                        GuidanceInlineIcon(icon: icon, size: 32 * scaleFactor,
                                           basePath: iconBasePath, tint: accent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(option)
                            .font(.system(size: 14 * scaleFactor, weight: .semibold))
                            .foregroundStyle(palette.text.opacity(0.9))
                        if let detail = at(block.optionDetails, index) {
                            Text(detail)
                                .font(.system(size: 11.5 * scaleFactor))
                                .foregroundStyle(isDone ? palette.success
                                                        : palette.text.opacity(0.5))
                        }
                    }
                    Spacer(minLength: 8)
                    if isDone {
                        ZStack {
                            Circle().fill(palette.success)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9 * scaleFactor, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 19 * scaleFactor, height: 19 * scaleFactor)
                    } else if let actionLabel = at(block.optionActions, index) {
                        Button {
                            handleRowAction(action: "url", url: at(block.optionURLs, index),
                                            requestId: nil, label: actionLabel,
                                            itemId: itemId, inspectState: inspectState)
                        } label: {
                            Text(actionLabel)
                                .font(.system(size: 12.5 * scaleFactor, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(accent))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.text.opacity(0.035)))
    }
}

// MARK: - Signature preview (type: "signature-preview")

/// Live email-signature preview on a light panel regardless of appearance. `label`, `content`
/// and `note` resolve `{{fieldId}}` templates against the step's form inputs on every keystroke.
struct GuidanceSignaturePreviewBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    let scaleFactor: CGFloat
    var iconBasePath: String?

    private let panelFill = Color(red: 0.933, green: 0.945, blue: 0.965) // #eef1f6
    private let ink = Color(red: 0.114, green: 0.114, blue: 0.122)       // #1d1d1f

    private func resolved(_ template: String?) -> String? {
        guard let template, !template.isEmpty else { return nil }
        return GuidanceTemplateResolver.resolve(template,
                                                formInputs: inspectState.guidanceFormInputs)
    }

    var body: some View {
        HStack(spacing: 14 * scaleFactor) {
            if let icon = block.icon {
                GuidanceInlineIcon(icon: icon, size: 34 * scaleFactor,
                                   basePath: iconBasePath, tint: nil)
                Rectangle().fill(Color(red: 0.84, green: 0.86, blue: 0.89))
                    .frame(width: 1, height: 40 * scaleFactor)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let name = resolved(block.label) {
                    Text(name)
                        .font(.system(size: 14 * scaleFactor, weight: .bold))
                        .foregroundStyle(ink)
                }
                if let line = resolved(block.content) {
                    Text(line)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(Color(red: 0.33, green: 0.38, blue: 0.44))
                }
                if let mono = resolved(block.note) {
                    Text(mono)
                        .font(.system(size: 12 * scaleFactor, design: .monospaced))
                        .foregroundStyle(Color(red: 0.48, green: 0.53, blue: 0.60))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(panelFill))
        .onAppear {
            // Seeds field defaults so templates resolve before any keystroke.
            inspectState.initializeGuidanceFormState(for: itemId)
        }
    }
}
