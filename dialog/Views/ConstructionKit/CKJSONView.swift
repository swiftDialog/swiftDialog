//
//  CKJSONView.swift
//  dialog
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 22/10/2025.
//

import SwiftUI
import SwiftyJSON

// Pure export helpers. Kept free of view state so output is reproducible and testable.
enum CKExport {

    // Size-related values are stored on appProperties rather than the argument's
    // `.value`, so surface them as overrides keyed by the argument name.
    private static func argumentOverrides(_ content: DialogUpdatableContent) -> [String: String] {
        var overrides = [
            appArguments.iconSize.long: "\(Int(content.iconSize))",
            appArguments.windowWidth.long: "\(Int(content.appProperties.windowWidth))",
            appArguments.windowHeight.long: "\(Int(content.appProperties.windowHeight))"
        ]
        // When the message / infobox is sourced from a markdown file or URL, export the
        // reference rather than the loaded preview content.
        if !content.messageSource.isEmpty {
            overrides[appArguments.messageOption.long] = content.messageSource
        }
        if !content.infoBoxSource.isEmpty {
            overrides[appArguments.infoBox.long] = content.infoBoxSource
        }
        return overrides
    }

    private static let skippedArguments = ["builder", "debug", "pid"]

    /// JSON config representation of the current builder state. This is the lossless export.
    static func json(from content: DialogUpdatableContent, debug: Bool = false) -> String {
        var json = JSON()
        var jsonDEBUG = JSON()
        let overrides = argumentOverrides(content)

        for child in Mirror(reflecting: content.args).children {
            guard let arg = child.value as? CommandlineArgument else { continue }
            if skippedArguments.contains(arg.long) { continue }
            let value = overrides[arg.long] ?? arg.value
            if arg.present {
                if !value.isEmpty {
                    json[arg.long].string = value
                } else if arg.isbool {
                    json[arg.long].string = "\(arg.present)"
                }
            }
            jsonDEBUG[arg.long].string = value
            jsonDEBUG["\(arg.long)-present"].bool = arg.present
        }

        if !content.listItemsArray.isEmpty {
            json[appArguments.listItem.long].arrayObject = Array(repeating: 0, count: content.listItemsArray.count)
            for index in content.listItemsArray.indices {
                var item = content.listItemsArray[index]
                if item.title.isEmpty { item.title = "Item \(index)" }
                json[appArguments.listItem.long][index].dictionaryObject = item.dictionary
            }
        }

        if !content.textFieldArray.isEmpty {
            json[appArguments.textField.long].arrayObject = Array(repeating: 0, count: content.textFieldArray.count)
            for index in content.textFieldArray.indices {
                json[appArguments.textField.long][index].dictionaryObject = content.textFieldArray[index].dictionary
            }
        }

        if !content.imageArray.isEmpty {
            json[appArguments.mainImage.long].arrayObject = Array(repeating: 0, count: content.imageArray.count)
            for index in content.imageArray.indices {
                json[appArguments.mainImage.long][index].dictionaryObject = content.imageArray[index].dictionary
            }
        }

        if !content.observedUserInputState.checkBoxes.isEmpty {
            json[appArguments.checkbox.long].arrayObject = Array(repeating: 0, count: content.observedUserInputState.checkBoxes.count)
            for index in content.observedUserInputState.checkBoxes.indices {
                json[appArguments.checkbox.long][index].dictionaryObject = content.observedUserInputState.checkBoxes[index].dictionary
            }
            if !content.appProperties.checkboxControlStyle.isEmpty {
                json[appArguments.checkboxStyle.long].stringValue = content.appProperties.checkboxControlStyle
            }
        }

        // bannerTitle is used as a flag (overlay the title on the banner); the mirror walk
        // skips it because it has no value, so emit it explicitly when present.
        if content.args.bannerTitle.present && content.args.bannerTitle.value.isEmpty {
            json[appArguments.bannerTitle.long].string = "true"
        }

        if content.appProperties.messageFontColour != .primary {
            json[appArguments.messageFont.long].dictionaryObject = ["colour": content.appProperties.messageFontColour.hexValue]
        }
        if content.appProperties.titleFontColour != .primary {
            json[appArguments.titleFont.long].dictionaryObject = ["colour": content.appProperties.titleFontColour.hexValue]
        }
        if content.appProperties.buttonSize != .regular {
            json[appArguments.buttonSize.long].string = content.args.buttonSize.value
        }

        if debug {
            return jsonDEBUG.rawString() ?? ""
        }
        return json.rawString() ?? "json is nil"
    }

    /// A copy/paste-able `dialog` command. Scalar/bool options become flags; collections use
    /// swiftDialog's comma syntax. The JSON export remains the lossless path for values that
    /// contain commas.
    static func command(from content: DialogUpdatableContent) -> String {
        var flags: [String] = []
        let overrides = argumentOverrides(content)
        let collectionMarkers = [
            appArguments.textField.long,
            appArguments.checkbox.long,
            appArguments.listItem.long,
            appArguments.mainImage.long,
            appArguments.dropdownTitle.long
        ]

        for child in Mirror(reflecting: content.args).children {
            guard let arg = child.value as? CommandlineArgument, arg.present else { continue }
            if skippedArguments.contains(arg.long) || collectionMarkers.contains(arg.long) { continue }
            let value = overrides[arg.long] ?? arg.value
            if !value.isEmpty {
                flags.append("--\(arg.long) \(quote(value))")
            } else if arg.isbool {
                flags.append("--\(arg.long)")
            }
        }

        for field in content.textFieldArray {
            flags.append("--\(appArguments.textField.long) \(quote(encode(field)))")
        }
        for box in content.observedUserInputState.checkBoxes {
            flags.append("--\(appArguments.checkbox.long) \(quote(encode(box)))")
        }
        for (index, item) in content.listItemsArray.enumerated() {
            flags.append("--\(appArguments.listItem.long) \(quote(encode(item, index: index)))")
        }
        for image in content.imageArray {
            flags.append("--\(appArguments.mainImage.long) \(quote(image.path))")
        }

        if !content.observedUserInputState.checkBoxes.isEmpty && !content.appProperties.checkboxControlStyle.isEmpty {
            flags.append("--\(appArguments.checkboxStyle.long) \(quote(content.appProperties.checkboxControlStyle))")
        }

        if content.args.bannerTitle.present && content.args.bannerTitle.value.isEmpty {
            flags.append("--\(appArguments.bannerTitle.long)")
        }

        if content.appProperties.titleFontColour != .primary {
            flags.append("--\(appArguments.titleFont.long) \(quote("colour=\(content.appProperties.titleFontColour.hexValue)"))")
        }
        if content.appProperties.messageFontColour != .primary {
            flags.append("--\(appArguments.messageFont.long) \(quote("colour=\(content.appProperties.messageFontColour.hexValue)"))")
        }

        return (["dialog"] + flags).joined(separator: " \\\n  ")
    }

    // MARK: - Collection encoders (mirror the parsers in ProcessCLOptions)

    private static func encode(_ field: TextFieldState) -> String {
        var tokens = [field.title]
        if field.required { tokens.append("required") }
        if field.secure { tokens.append("secure") }
        if field.confirm { tokens.append("confirm") }
        if field.fileSelect { tokens.append("fileselect") }
        if !field.fileType.isEmpty { tokens.append("filetype=\(field.fileType)") }
        if !field.prompt.isEmpty { tokens.append("prompt=\(field.prompt)") }
        if !field.regex.isEmpty { tokens.append("regex=\(field.regex)") }
        if !field.regexError.isEmpty { tokens.append("regexerror=\(field.regexError)") }
        if !field.value.isEmpty { tokens.append("value=\(field.value)") }
        if !field.name.isEmpty { tokens.append("name=\(field.name)") }
        if !field.initialPath.isEmpty { tokens.append("path=\(field.initialPath)") }
        return tokens.joined(separator: ",")
    }

    private static func encode(_ box: CheckBoxes) -> String {
        var tokens = [box.label]
        if !box.name.isEmpty { tokens.append("name=\(box.name)") }
        if !box.icon.isEmpty { tokens.append("icon=\(box.icon)") }
        if box.checked { tokens.append("checked") }
        if box.disabled { tokens.append("disabled") }
        if box.enablesButton1 { tokens.append("enableButton1") }
        return tokens.joined(separator: ",")
    }

    private static func encode(_ item: ListItems, index: Int) -> String {
        var tokens = [item.title.isEmpty ? "Item \(index)" : item.title]
        if !item.subTitle.isEmpty { tokens.append("subtitle=\(item.subTitle)") }
        if !item.icon.isEmpty { tokens.append("icon=\(item.icon)") }
        if !item.statusText.isEmpty { tokens.append("statustext=\(item.statusText)") }
        if !item.statusIcon.isEmpty { tokens.append("status=\(item.statusIcon)") }
        return tokens.joined(separator: ",")
    }

    private static func quote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

enum CKOutputFormat: String, CaseIterable, Identifiable {
    case json = "JSON"
    case command = "Command Line"
    var id: String { rawValue }
}

struct CKOutputView: View {
    @ObservedObject var observedDialogContent: DialogUpdatableContent

    @State private var format: CKOutputFormat = .json
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
    }

    // Recomputed whenever observed state changes, so the preview stays live.
    private var outputText: String {
        switch format {
        case .json: return CKExport.json(from: observedDialogContent)
        case .command: return CKExport.command(from: observedDialogContent)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        alertTitle = "Copied to clipboard".localized
        alertMessage = format == .json
            ? "The JSON output was copied to the clipboard.".localized
            : "The dialog command was copied to the clipboard.".localized
        showAlert = true
    }

    private func saveToFile() {
        let savePanel = NSSavePanel()
        switch format {
        case .json:
            savePanel.allowedContentTypes = [.json]
            savePanel.nameFieldStringValue = "dialog.json"
        case .command:
            savePanel.allowedContentTypes = [.plainText]
            savePanel.nameFieldStringValue = "dialog-command.txt"
        }
        savePanel.canCreateDirectories = true
        savePanel.message = "Choose a location to save the file".localized

        let content = outputText
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    alertTitle = "Saved".localized
                    alertMessage = "File saved successfully.".localized
                    showAlert = true
                } catch {
                    alertTitle = "Save failed".localized
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $format) {
                ForEach(CKOutputFormat.allCases) { fmt in
                    Text(fmt.rawValue.localized).tag(fmt)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)
            HStack {
                Button("Copy to clipboard".localized) {
                    copyToClipboard()
                }
                Button("Save File".localized) {
                    saveToFile()
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            Divider()
            ScrollView([.vertical, .horizontal]) {
                Text(outputText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}
