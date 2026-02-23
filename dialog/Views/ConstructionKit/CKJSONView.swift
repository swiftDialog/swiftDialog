//
//  JSONView.swift
//  dialog
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 22/10/2025.
//

import SwiftUI
import SwiftyJSON

struct JSONView: View {
    @ObservedObject var observedDialogContent: DialogUpdatableContent

    @State private var jsonText: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    private func exportJSON(debug: Bool = false) -> String {
        var json = JSON()
        var jsonDEBUG = JSON()

        // copy modifyable objects into args
        observedDialogContent.args.iconSize.value = "\(observedDialogContent.iconSize)"
        observedDialogContent.args.windowWidth.value = "\(observedDialogContent.appProperties.windowWidth)"
        observedDialogContent.args.windowHeight.value = "\(observedDialogContent.appProperties.windowHeight)"

        let mirroredAppArguments = Mirror(reflecting: observedDialogContent.args)
        for (_, attr) in mirroredAppArguments.children.enumerated() {
            if let propertyValue = attr.value as? CommandlineArgument {
                if ["builder", "debug", "pid"].contains(propertyValue.long) { continue } 
                if propertyValue.present { //}&& propertyValue.value != "" {
                    if propertyValue.value != "" {
                        json[propertyValue.long].string = propertyValue.value
                    } else if propertyValue.isbool {
                        json[propertyValue.long].string = "\(propertyValue.present)"
                    }
                }
                jsonDEBUG[propertyValue.long].string = propertyValue.value
                jsonDEBUG["\(propertyValue.long)-present"].bool = propertyValue.present
            }
        }

        if observedDialogContent.listItemsArray.count > 0 {
            json[appArguments.listItem.long].arrayObject = Array(repeating: 0, count: observedDialogContent.listItemsArray.count)
            for index in 0..<observedDialogContent.listItemsArray.count {
                if observedDialogContent.listItemsArray[index].title.isEmpty {
                    observedDialogContent.listItemsArray[index].title = "Item \(index)"
                }
                // print(observedDialogContent.listItemsArray[i].dictionary)
                json[appArguments.listItem.long][index].dictionaryObject = observedDialogContent.listItemsArray[index].dictionary
            }
        }
        
        if observedDialogContent.textFieldArray.count > 0 {
            json[appArguments.textField.long].arrayObject = Array(repeating: 0, count: observedDialogContent.textFieldArray.count)
            for index in 0..<observedDialogContent.textFieldArray.count {
                json[appArguments.textField.long][index].dictionaryObject = observedDialogContent.textFieldArray[index].dictionary
            }
        }

        if observedDialogContent.imageArray.count > 0 {
            json[appArguments.mainImage.long].arrayObject = Array(repeating: 0, count: observedDialogContent.imageArray.count)
            for index in 0..<observedDialogContent.imageArray.count {
                json[appArguments.mainImage.long][index].dictionaryObject = observedDialogContent.imageArray[index].dictionary
            }
        }
        
        if observedDialogContent.observedUserInputState.checkBoxes.count > 0 {
            json[appArguments.checkbox.long].arrayObject = Array(repeating: 0, count: observedDialogContent.observedUserInputState.checkBoxes.count)
            for index in 0..<observedDialogContent.observedUserInputState.checkBoxes.count {
                json[appArguments.checkbox.long][index].dictionaryObject = observedDialogContent.observedUserInputState.checkBoxes[index].dictionary
            }
            json[appArguments.checkboxStyle.long].stringValue = observedDialogContent.appProperties.checkboxControlStyle
        }
        

        // message font stuff
        if observedDialogContent.appProperties.messageFontColour != .primary {
            json[appArguments.messageFont.long].dictionaryObject = ["colour": observedDialogContent.appProperties.messageFontColour.hexValue]
        }

        if observedDialogContent.appProperties.titleFontColour != .primary {
            json[appArguments.titleFont.long].dictionaryObject = ["colour": observedDialogContent.appProperties.titleFontColour.hexValue]
        }

        if observedDialogContent.appProperties.buttonSize != .regular {
            json[appArguments.buttonSize.long].string = observedDialogContent.args.buttonSize.value
        }

        // convert the JSON to a raw String
        jsonFormattedOutout = json.rawString() ?? "json is nil"

        if debug {
            jsonFormattedOutout = jsonDEBUG.rawString() ?? ""
        }
        return jsonFormattedOutout
    }

    init (observedDialogContent: DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
    }

    func saveToFile(_ content: String) {
            let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
            savePanel.canCreateDirectories = true
            savePanel.nameFieldStringValue = "file.json"
            savePanel.message = "Choose a location to save the file"
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        try content.write(to: url, atomically: true, encoding: .utf8)
                        alertMessage = "File saved successfully!"
                        showAlert = true
                    } catch {
                        alertMessage = "Failed to save file: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
        }
    
    var body: some View {
        ScrollView {
            HStack {
                Button("Regenerate") {
                    jsonText = exportJSON()
                }
                Button("Copy to clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([NSString(string: exportJSON())])
                }
                Button("Save File") {
                    saveToFile(exportJSON())
                }
                Spacer()
            }
            .padding(.top, 10)
            .padding(.leading, 10)
            Divider()
            HStack {
                Text(jsonText)
                Spacer()
            }
            .padding(.top, 10)
            .padding(.leading, 10)
            .alert("Save Status", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            
            Spacer()
            
        }
        .onAppear {
            jsonText = exportJSON()
        }
    }
}
