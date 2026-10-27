//
//  GuidanceTextFieldBlock.swift
//  dialog
//
//  The guidance textfield block: plain/secure, plus textfieldMode "date", "file", "editor" and "confirm",
//  ported from classic TextEntryView.

import SwiftUI
import UniformTypeIdentifiers

/// textfieldMode="date" formatter: the stored value is locale-independent "yyyy-MM-dd" while the picker
/// shows the user's locale. File scope because generic types cannot hold static stored properties.
private let guidanceDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

/// NSOpenPanel for textfieldMode="file", with classic's rules: single selection, "folder" allows directories,
/// media tokens map to UTTypes, anything else is an extension. Sheet on the main window.
@MainActor
private func presentFileSelectPanel(fileType: String, initialPath: String, completion: @escaping (String) -> Void) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    if initialPath.isEmpty {
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
    } else {
        panel.directoryURL = URL(fileURLWithPath: initialPath)
    }
    if !fileType.isEmpty {
        var fileTypesArray: [UTType] = []
        for type in fileType.components(separatedBy: " ") {
            switch type {
            case "folder":
                panel.canChooseDirectories = true
            case "image":
                fileTypesArray.append(UTType.image)
            case "movie", "video":
                fileTypesArray.append(UTType.movie)
            case "audio":
                fileTypesArray.append(UTType.audio)
            default:
                fileTypesArray.append(UTType(filenameExtension: type) ?? .item)
            }
        }
        if !fileTypesArray.isEmpty {
            panel.allowedContentTypes = fileTypesArray
        }
    }
    guard let window = NSApp.mainWindow ?? NSApp.keyWindow else { return }
    panel.beginSheetModal(for: window) { response in
        if response == .OK {
            completion(panel.url?.path ?? "")
        }
    }
}

struct GuidanceTextFieldBlock<Context: UserInputContext & ObservableObject>: View {
    let block: InspectConfig.GuidanceContent
    let itemId: String
    @ObservedObject var inspectState: Context
    let scaleFactor: CGFloat
    var wire = FormWire()       // host-declared line shape + commit side effects
    @Environment(\.palette) private var palette

    /// Effective value: user input, then inherit resolution, then the block default.
    private var currentValue: String {
        guard let fieldId = block.id else { return "" }
        if let userValue = inspectState.guidanceFormInputs[itemId]?.textfields[fieldId] {
            return userValue
        }
        if let inheritSpec = block.inherit,
           let inherited = inspectState.resolveInheritValue(inheritSpec, basePath: inspectState.uiConfiguration.iconBasePath) {
            return inherited
        }
        return block.value ?? ""
    }

    /// Live regex verdict via classic's `checkRegexPattern`. Empty values never flag; required is validation's job.
    private var regexFailed: Bool {
        guard let regex = block.regex, !regex.isEmpty, !currentValue.isEmpty else { return false }
        return !checkRegexPattern(regexPattern: regex, textToValidate: currentValue)
    }

    private var confirmValue: String {
        guard let fieldId = block.id else { return "" }
        return inspectState.guidanceFormInputs[itemId]?.confirmations[fieldId] ?? ""
    }

    /// Flags any difference unless both fields are empty, like classic `validateRequiredFields`.
    private var confirmMismatch: Bool {
        guard block.textfieldMode == "confirm" else { return false }
        if currentValue.isEmpty && confirmValue.isEmpty { return false }
        return currentValue != confirmValue
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { currentValue },
            set: { newValue in
                guard let fieldId = block.id else { return }
                var value = newValue
                if let maxLength = block.maxLength, maxLength > 0, value.count > maxLength {
                    value = String(value.prefix(maxLength))
                }
                if inspectState.guidanceFormInputs[itemId] == nil {
                    inspectState.initializeGuidanceFormState(for: itemId)
                }
                inspectState.guidanceFormInputs[itemId]?.textfields[fieldId] = value
                writeLog("GuidanceContentView: Textfield '\(fieldId)' updated", logLevel: .info)
                inspectState.writeToInteractionLog(
                    wire.line(type: "textfield", owner: itemId, field: fieldId,
                              value: FormWire.loggedValue(value, secure: block.secure == true)))
                wire.onValueCommit?(fieldId, value)
            }
        )
    }

    /// Stored in the confirmations dict, which never reaches result files or the interaction log.
    private var confirmBinding: Binding<String> {
        Binding(
            get: { confirmValue },
            set: { newValue in
                guard let fieldId = block.id else { return }
                if inspectState.guidanceFormInputs[itemId] == nil {
                    inspectState.initializeGuidanceFormState(for: itemId)
                }
                inspectState.guidanceFormInputs[itemId]?.confirmations[fieldId] = newValue
                writeLog("GuidanceContentView: Textfield '\(fieldId)' confirm entry updated", logLevel: .info)
            }
        )
    }

    /// Parses the stored ISO string. An untouched field stays empty in the store, so required still gates.
    private var dateBinding: Binding<Date> {
        Binding(
            get: { guidanceDateFormatter.date(from: currentValue) ?? Date.now },
            set: { newDate in
                textBinding.wrappedValue = guidanceDateFormatter.string(from: newDate)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            if block.textfieldMode == "editor" {
                editorLayout
            } else {
                rowLayout
            }

            if regexFailed {
                Text((block.regexError?.isEmpty == false) ? block.regexError! : "Invalid format")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(palette.error)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if confirmMismatch {
                Text("Values do not match")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(palette.error)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if block.required == true {
                GuidanceRequiredHint(scaleFactor: scaleFactor)
            }
        }
        .padding(.vertical, 4 * scaleFactor)
    }

    // MARK: - Row modes (plain/secure, date, file, confirm)

    private var rowLayout: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            // Label above the field, so a wide pane does not separate the label from its input.
            labelGroup

            if block.id != nil {
                control
                    .frame(maxWidth: 320 * scaleFactor)
            }

            // Help text under the field it explains.
            if let helpText = block.helpText, !helpText.isEmpty {
                Text(helpText)
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if block.textfieldMode == "confirm", block.id != nil {
                HStack {
                    Text("Confirm \(block.content ?? "")")
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                    Spacer()
                    Group {
                        if block.secure == true {
                            SecureField(block.placeholder ?? "", text: confirmBinding)
                        } else {
                            TextField(block.placeholder ?? "", text: confirmBinding)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(confirmMismatch ? palette.error : Color.clear, lineWidth: 1.5)
                    )
                    .frame(maxWidth: 200 * scaleFactor)
                }
            }
        }
    }

    @ViewBuilder
    private var labelGroup: some View {
        // Reads `label` as well as `content`, like every other form block; first non-empty wins.
        let text = [block.label, block.content].compactMap { $0 }.first { !$0.isEmpty }
        if let text {
            HStack(spacing: 4 * scaleFactor) {
                Text(text)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(palette.text)
                if block.required == true {
                    Text("*")
                        .font(.system(size: 13 * scaleFactor, weight: .medium))
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
    }

    @ViewBuilder
    private var control: some View {
        switch block.textfieldMode?.lowercased() {
        case "date":
            DatePicker("", selection: dateBinding, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()

        case "file":
            HStack(spacing: 6 * scaleFactor) {
                plainField
                Button("Select…") {
                    presentFileSelectPanel(fileType: block.fileType ?? "",
                                           initialPath: block.initialPath ?? "") { selectedPath in
                        textBinding.wrappedValue = selectedPath
                    }
                }
            }

        default:
            plainField
        }
    }

    private var plainField: some View {
        Group {
            if block.secure == true {
                SecureField(block.placeholder ?? "", text: textBinding)
            } else {
                TextField(block.placeholder ?? "", text: textBinding)
            }
        }
        .textFieldStyle(.roundedBorder)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(regexFailed ? palette.error : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Editor mode (full-width multi-line)

    private var editorLayout: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            HStack {
                labelGroup
                Spacer()
            }

            if block.id != nil {
                TextEditor(text: textBinding)
                    .font(.system(size: 13 * scaleFactor))
                    .scrollContentBackground(.hidden)
                    .padding(6 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(palette.cardSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(regexFailed ? palette.error : palette.textMuted.opacity(0.4), lineWidth: regexFailed ? 1.5 : 1)
                    )
                    .frame(height: (block.editorHeight ?? 120) * scaleFactor)
            }
        }
    }
}
