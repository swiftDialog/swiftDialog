//
//  ProcessCLOptions.swift
//  dialog
//
//  Created by Bart Reardon on 29/8/21.
//

import Foundation
import SwiftUI
import SwiftyJSON

func processJSON(jsonFilePath: String) -> JSON {
    var json = JSON()
    // read in from file
    let jsonDataPath = NSURL(fileURLWithPath: jsonFilePath)
    var jsonData = Data()

    // wrap everything in a try block.IF the URL or filepath is unreadable then bail
    do {
        jsonData = try Data(contentsOf: jsonDataPath as URL)
    } catch {
        quitDialog(exitCode: appDefaults.exit202.code, exitMessage: "\(appDefaults.exit202.message) \(jsonFilePath)")
    }

    do {
        json = try JSON(data: jsonData)
    } catch {
        quitDialog(exitCode: appDefaults.exit202.code, exitMessage: "JSON import failed")
    }
    return json
}

func processJSONString(jsonString: String) -> JSON {
    var json = JSON()
    let dataFromString = jsonString.replacingOccurrences(of: "\n", with: "\\n").data(using: .utf8)
    do {
        json = try JSON(data: dataFromString!)
    } catch {
        quitDialog(exitCode: appDefaults.exit202.code, exitMessage: "JSON import failed")
    }
    return json
}

func getJSON() -> JSON {
    var json = JSON()
    if CLOptionPresent(optionName: appArguments.jsonFile) {
        // read json in from file
        json = processJSON(jsonFilePath: CLOptionText(optionName: appArguments.jsonFile))
    }

    if CLOptionPresent(optionName: appArguments.jsonString) {
        // read json in from text string
        json = processJSONString(jsonString: CLOptionText(optionName: appArguments.jsonString))
    }
    return json
}

func getMarkdown(mdFilePath: String) -> String {
    //let fileURL = URL(fileURLWithPath: mdFilePath)
    var urlPath = NSURL(string: "")!

    // checking for anything starting with http - crude but it works (for now)
    if mdFilePath.hasPrefix("http") {
        writeLog("Getting image from http")
        urlPath = NSURL(string: mdFilePath)!
    } else {
        urlPath = NSURL(fileURLWithPath: mdFilePath)
    }

    do {
        let fileContents = try String(contentsOf: urlPath as URL, encoding: .utf8)
        return fileContents
    } catch {
        return error.localizedDescription
    }

}

func processCLOptionValues() {

    // this method reads in arguments from either json file or from the command line and loads them into the appArguments object
    // also records whether an argument is present or not
    writeLog("Checking command line options for arguments")
    // if argument count is < 2 print help and exit
    if CommandLine.arguments.count < 2 {
        SDHelp(arguments: appArguments).printHelpShort()
        //if !appvars.quitAfterProcessingNotifications {
        //    quitDialog(exitCode: 0)
        //}
    }
    writeLog("Argument count: \(CommandLine.arguments.count)", logLevel: .debug)
    for argument in CommandLine.arguments {
        writeLog("Using argument: \(argument)", logLevel: .debug)
    }
    let json: JSON = getJSON()

    appArguments.updateAllItems(with: json)
}

func processCLOptions(json: JSON = getJSON()) {

    //this method goes through the arguments that are present and performs any processing required before use
    writeLog("Processing Options")

    if appArguments.messageAlignmentOld.present {
        appArguments.messageAlignment.present = appArguments.messageAlignmentOld.present
        appArguments.messageAlignment.value = appArguments.messageAlignmentOld.value
    }
    if appArguments.messageAlignment.present {
        appvars.messageAlignment = appDefaults.allignmentStates[appArguments.messageAlignment.value] ?? .leading
        appvars.messagePosition = appDefaults.positionStates[appArguments.messageAlignment.value] ?? .leading
    }

    // info box
    if (getVersionString().starts(with: "Alpha") || getVersionString().starts(with: "Beta")) && !appArguments.constructionKit.present {
        appArguments.infoText.present = true
    }

    // help sheet
    if appArguments.helpAlignment.present {
        appvars.helpAlignment = appDefaults.allignmentStates[appArguments.helpAlignment.value] ?? .leading
    }

    // window location on screen
    if appArguments.position.present {
        writeLog("Window position will be set to \(appArguments.position.value)")
        (appvars.windowPositionVertical,appvars.windowPositionHorozontal) = windowPosition(appArguments.position.value)
    }
    if appArguments.positionOffset.present {
        appvars.windowPositionOffset = appArguments.positionOffset.value.floatValue()
    }

    // banner image
    if appArguments.bannerText.present {
        appArguments.bannerTitle.value = appArguments.bannerText.value
        appArguments.bannerTitle.present = true
    }
    if appArguments.bannerTitle.present {
        appArguments.titleOption.value = appArguments.bannerTitle.value
    }

    //  User Input
    var selectItemsArg = CommandlineArgument(long: "selectitems")
    selectItemsArg.evaluate(json: json)
    if selectItemsArg.present { appArguments.dropdownValues = selectItemsArg }

    if !appArguments.statusLogFile.present {
        appArguments.statusLogFile.value = appDefaults.defaultStatusLogFile
    }

    // rich content
    if appArguments.video.present || appArguments.webcontent.present {
        // check if it's a youtube id
        appArguments.video.value = getVideoStreamingURLFromID(videoid: appArguments.video.value, autoplay: appArguments.autoPlay.present)
        // set a larger window size. 900x600 will fit a standard 16:9 video
        writeLog("resetting default window size to 900x600")
        appvars.windowWidth = appvars.videoWindowWidth
        appvars.windowHeight = appvars.videoWindowHeight
    }

    // anthing that is an option only with no value
    if appArguments.centreIconSE.present {
        appArguments.centreIcon.present = true
    }
    if appArguments.fullScreenWindow.present {
        appArguments.forceOnTop.present = false
    }

    // command line only options
    if appArguments.hideDefaultKeyboardAction.present {
        appvars.button1DefaultAction.modifiers = [.command, .shift]
        appvars.button2DefaultAction.modifiers = [.command, .shift]
    }

    // process command line options that just display info and exit before we show the main window
    if appArguments.helpOption.present {
        writeLog("\(appArguments.helpOption.long) present")
        let sdHelp = SDHelp(arguments: appArguments)
        if appArguments.helpOption.value != "" {
            writeLog("Printing help for \(appArguments.helpOption.value)")
            sdHelp.printHelpLong(for: appArguments.helpOption.value)
        } else {
            sdHelp.printHelpShort()
        }
        quitDialog(exitCode: appDefaults.exitNow.code)
    }
    if appArguments.getVersion.present {
        writeLog("\(appArguments.getVersion.long) called")
        printVersionString()
        quitDialog(exitCode: appDefaults.exitNow.code)
    }
    if appArguments.licence.present {
        writeLog("\(appArguments.licence.long) called")
        print(licenseText)
        quitDialog(exitCode: appDefaults.exitNow.code)
    }
    if appArguments.buyCoffee.present {
        writeLog("\(appArguments.buyCoffee.long) called :)")
        //I'm a teapot
        print("If you like this app and want to buy me a coffee https://www.buymeacoffee.com/bartreardon")
        quitDialog(exitCode: appDefaults.exitNow.code)
    }
    if appArguments.setAppIcon.present {
        setAppIcon(named: appArguments.setAppIcon.value)
        print("Setting app icon to \(appArguments.setAppIcon.value)")
        quitDialog(exitCode: appDefaults.exitNow.code)
    }

    // Check if an auth key is present and verify
    if !dialogIsAuthorised {
        writeLog("Auth key is required", logLevel: .debug)
        quitDialog(exitCode: appDefaults.exit30.code, exitMessage: appDefaults.exit30.message)
    }

    // hash a key value
    if appArguments.hash.present {
        quitDialog(exitCode: 0, exitMessage: appArguments.hash.value.sha256Hash)
    }

    if !appArguments.messageOption.present {
        appArguments.messageOption.value = appDefaults.messageDefault
    }
    if appArguments.messageOption.present && appArguments.messageOption.value.lowercased().hasSuffix(".md") {
        appArguments.messageOption.value = processTextString(getMarkdown(mdFilePath: appArguments.messageOption.value), tags: appvars.systemInfo)
    }

    if appArguments.infoBox.present && appArguments.infoBox.value.lowercased().hasSuffix(".md") {
        appArguments.infoBox.value = processTextString(getMarkdown(mdFilePath: appArguments.infoBox.value), tags: appvars.systemInfo)
    }

    if appArguments.helpMessage.present && appArguments.helpMessage.value.lowercased().hasSuffix(".md") {
        appArguments.helpMessage.value = processTextString(getMarkdown(mdFilePath: appArguments.helpMessage.value), tags: appvars.systemInfo)
    }

    // Dialog style allows for pre-set types that define how the window will look
    if appArguments.dialogStyle.present {
        switch appArguments.dialogStyle.value {
        case "alert","caution","warning":
            // set defaults for the alert style
            appArguments.buttonStyle.value = "centre"
            appArguments.centreIcon.present = true
            appArguments.messageOption.value = "### \(appArguments.titleOption.value)\n\n\(appArguments.messageOption.value)"
            appArguments.iconSize.value = "80"
            appArguments.titleOption.value = "none"
            appvars.messagePosition = .center
            appvars.messageAlignment = .center
            appvars.windowHeight = 300
            appvars.windowWidth = 300
            if ["caution", "warning"].contains(appArguments.dialogStyle.value.lowercased()) {
                appArguments.iconOption.value = appArguments.dialogStyle.value.lowercased()
            }
        case "centred", "centered":
            appArguments.iconSize.value = !appArguments.iconSize.present ? "110" : appArguments.iconSize.value
            appArguments.buttonStyle.value = "centre"
            appArguments.centreIcon.present = true
            appvars.messagePosition = .center
            appvars.messageAlignment = .center
        case "mini":
            appArguments.miniMode.present = true
        case "presentation":
            appArguments.presentationMode.present = true
        default: ()
        }
    }

    if appArguments.buttonSize.present {
        appvars.buttonSize = appDefaults.buttonSizeStates[appArguments.buttonSize.value] ?? .regular
    }

    if appArguments.dropdownValues.present {
        writeLog("\(appArguments.dropdownValues.long) present")
        // checking for the pre 1.10 way of defining a select list
        if json[appArguments.dropdownValues.long].exists() && !json["selectitems"].exists() {
            writeLog("processing select list from json")
            let selectValues = json[appArguments.dropdownValues.long].arrayValue.map {$0.stringValue}
            let selectTitle = json[appArguments.dropdownTitle.long].stringValue
            let selectDefault = json[appArguments.dropdownDefault.long].stringValue
            userInputState.dropdownItems.append(DropDownItems(title: selectTitle, values: selectValues, defaultValue: selectDefault, selectedValue: selectDefault))
        }

        if json["selectitems"].exists() {
            writeLog("processing select items from json")
            for index in 0..<json["selectitems"].count {
                userInputState.dropdownItems.append(DropDownItems(
                        title: json["selectitems"][index]["title"].stringValue,
                        name: json["selectitems"][index]["name"].stringValue,
                        values: (json["selectitems"][index]["values"].arrayValue.map {$0.stringValue}).map { $0.trimmingCharacters(in: .whitespaces) },
                        defaultValue: json["selectitems"][index]["default"].stringValue,
                        selectedValue: json["selectitems"][index]["default"].stringValue,
                        required: json["selectitems"][index]["required"].boolValue,
                        style: json["selectitems"][index]["style"].stringValue
                ))
            }

        } else {
            writeLog("processing select list from command line arguments")
            let dropdownValues = CLOptionMultiOptions(optionName: appArguments.dropdownValues.long)
            var dropdownLabels = CLOptionMultiOptions(optionName: appArguments.dropdownTitle.long)
            var dropdownDefaults = CLOptionMultiOptions(optionName: appArguments.dropdownDefault.long)

            // need to make sure the title and default value arrays are the same size
            for _ in dropdownLabels.count..<dropdownValues.count {
                dropdownLabels.append("")
            }
            for _ in dropdownDefaults.count..<dropdownValues.count {
                dropdownDefaults.append("")
            }

            for index in 0..<(dropdownValues.count) {
                let labelItems = dropdownLabels[index].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var dropdownRequired: Bool = false
                var dropdownStyle: String = "list"
                let dropdownTitle: String = labelItems[0]
                var dropdownName: String = ""
                for item in labelItems {
                    var itemKeyValuePair = item.split(separator: "=", maxSplits: 1)
                    for _ in itemKeyValuePair.count...2 {
                        itemKeyValuePair.append("")
                    }
                    let itemName = String(itemKeyValuePair[0])
                    let itemValue = String(itemKeyValuePair[1])
                    switch itemName.lowercased() {
                        case "required":
                            dropdownRequired = true
                        case "radio":
                            dropdownStyle = "radio"
                        case "name":
                            dropdownName = itemValue
                        default: ()
                        }
                }
                userInputState.dropdownItems.append(DropDownItems(title: dropdownTitle, name: dropdownName, values: dropdownValues[index].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }, defaultValue: dropdownDefaults[index], selectedValue: dropdownDefaults[index], required: dropdownRequired, style: dropdownStyle))
            }
        }
        for index in 0..<userInputState.dropdownItems.count where userInputState.dropdownItems[index].required {
            appvars.userInputRequired = true
        }
        writeLog("Processed \(userInputState.dropdownItems.count) select items")
    }

    if appArguments.textField.present {
        writeLog("\(appArguments.textField.long) present")
        if json[appArguments.textField.long].exists() {
            for index in 0..<json[appArguments.textField.long].arrayValue.count {
                if json[appArguments.textField.long][index]["title"].stringValue == "" {
                    userInputState.textFields.append(TextFieldState(title: String(json[appArguments.textField.long][index].stringValue)))
                } else {
                    userInputState.textFields.append(TextFieldState(
                        editor: Bool(json[appArguments.textField.long][index]["editor"].boolValue),
                        fileSelect: Bool(json[appArguments.textField.long][index]["fileselect"].boolValue),
                        fileType: String(json[appArguments.textField.long][index]["filetype"].stringValue),
                        passwordFill: Bool(json[appArguments.textField.long][index]["passwordfill"].boolValue),
                        prompt: String(json[appArguments.textField.long][index]["prompt"].stringValue),
                        regex: String(json[appArguments.textField.long][index]["regex"].stringValue),
                        regexError: String(json[appArguments.textField.long][index]["regexerror"].stringValue),
                        required: Bool(json[appArguments.textField.long][index]["required"].boolValue),
                        secure: Bool(json[appArguments.textField.long][index]["secure"].boolValue),
                        title: String(json[appArguments.textField.long][index]["title"].stringValue),
                        name: String(json[appArguments.textField.long][index]["name"].stringValue),
                        value: String(json[appArguments.textField.long][index]["value"].stringValue),
                        isDate: Bool(json[appArguments.textField.long][index]["isdate"].boolValue),
                        confirm: Bool(json[appArguments.textField.long][index]["confirm"].boolValue))
                    )
                }
            }
        } else {
            for textFieldOption in CLOptionMultiOptions(optionName: appArguments.textField.long) {
                let items = textFieldOption.split(usingRegex: appDefaults.argRegex)
                var fieldEditor: Bool = false
                var fieldFileSelect: Bool = false
                var fieldPasswordFill: Bool = false
                var fieldPrompt: String = ""
                var fieldRegex: String = ""
                var fieldRegexError: String = ""
                var fieldRequire: Bool = false
                var fieldSecure: Bool = false
                var fieldSelectType: String = ""
                var fieldTitle: String = ""
                var fieldName: String = ""
                var fieldValue: String = ""
                var fieldIsDate: Bool = false
                var fieldConfirm: Bool = false
                if items.count > 0 {
                    fieldTitle = items[0]
                    if items.count > 1 {
                        fieldRegexError = "\"\(fieldTitle)\" "+"no-pattern".localized
                        for index in 1...items.count-1 {
                            switch items[index].lowercased()
                                .replacingOccurrences(of: ",", with: "")
                                .replacingOccurrences(of: "=", with: "")
                                .trimmingCharacters(in: .whitespaces) {
                            case "editor":
                                fieldEditor = true
                            case "fileselect":
                                fieldFileSelect = true
                            case "filetype":
                                fieldSelectType = items[index+1]
                            case "passwordfill":
                                fieldPasswordFill = true
                            case "prompt":
                                fieldPrompt = items[index+1]
                            case "regex":
                                fieldRegex = items[index+1]
                            case "regexerror":
                                fieldRegexError = items[index+1]
                            case "required":
                                fieldRequire = true
                            case "secure":
                                fieldSecure = true
                            case "value":
                                fieldValue = items[index+1]
                            case "name":
                                fieldName = items[index+1]
                            case "isdate":
                                fieldIsDate = true
                            case "confirm":
                                fieldConfirm = true
                            default: ()
                            }
                        }
                    }
                }
                userInputState.textFields.append(TextFieldState(
                            editor: fieldEditor,
                            fileSelect: fieldFileSelect,
                            fileType: fieldSelectType,
                            passwordFill: fieldPasswordFill,
                            prompt: fieldPrompt,
                            regex: fieldRegex,
                            regexError: fieldRegexError,
                            required: fieldRequire,
                            secure: fieldSecure,
                            title: fieldTitle,
                            name: fieldName,
                            value: fieldValue,
                            isDate: fieldIsDate,
                            confirm: fieldConfirm))
            }
        }
        for index in 0..<userInputState.textFields.count where userInputState.textFields[index].required {
            appvars.userInputRequired = true
        }
        writeLog("textOptionsArray : \(userInputState.textFields)")
    }

    if appArguments.checkbox.present {
        writeLog("\(appArguments.checkbox.long) present")
        if json[appArguments.checkbox.long].exists() {
            for index in 0..<json[appArguments.checkbox.long].arrayValue.count {
                let cbLabel = json[appArguments.checkbox.long][index]["label"].stringValue
                let cbChecked = json[appArguments.checkbox.long][index]["checked"].boolValue
                let cbDisabled = json[appArguments.checkbox.long][index]["disabled"].boolValue
                let cbIcon = json[appArguments.checkbox.long][index]["icon"].stringValue
                let cbButtonEnable = json[appArguments.checkbox.long][index]["enableButton1"].boolValue
                let cbName = json[appArguments.checkbox.long][index]["name"].stringValue

                userInputState.checkBoxes.append(CheckBoxes(label: cbLabel, name: cbName, icon: cbIcon, checked: cbChecked, disabled: cbDisabled, enablesButton1: cbButtonEnable))
            }
        } else {
            for checkboxes in CLOptionMultiOptions(optionName: appArguments.checkbox.long) {
                let items = checkboxes.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var label: String = ""
                var name: String = ""
                var icon: String = ""
                var checked: Bool = false
                var disabled: Bool = false
                var enableButton1: Bool = false
                for item in items {
                    var itemKeyValuePair = item.split(separator: "=", maxSplits: 1)
                    for _ in itemKeyValuePair.count...2 {
                        itemKeyValuePair.append("")
                    }
                    let itemName = String(itemKeyValuePair[0])
                    let itemValue = String(itemKeyValuePair[1])
                    switch itemName.lowercased() {
                    case "label":
                        label = itemValue
                    case "name":
                        name = itemValue
                    case "icon":
                        icon = itemValue
                    case "checked":
                        checked = true
                    case "disabled":
                        disabled = true
                    case "enablebutton1":
                        enableButton1 = true
                    default:
                        label = itemName
                    }
                }
                userInputState.checkBoxes.append(CheckBoxes(label: label, name: name, icon: icon, checked: checked, disabled: disabled, enablesButton1: enableButton1))
                //appvars.checkboxArray.append(CheckBoxes(label: label, name: name, icon: icon, checked: checked, disabled: disabled, enablesButton1: enableButton1))
            }
        }
                                writeLog("checkboxOptionsArray : \(appvars.checkboxArray)")
    }

    if appArguments.checkboxStyle.present {
        writeLog("\(appArguments.checkboxStyle.long) present")
        var controlSize = ""
        if json[appArguments.checkboxStyle.long].exists() {
            appvars.checkboxControlStyle = json[appArguments.checkboxStyle.long]["style"].stringValue
            controlSize = json[appArguments.checkboxStyle.long]["size"].stringValue
        } else {
            appvars.checkboxControlStyle = appArguments.checkboxStyle.value.components(separatedBy: ",").first ?? "checkbox"
            controlSize = appArguments.checkboxStyle.value.components(separatedBy: ",").last ?? ""
        }
        switch controlSize {
        case "regular":
            appvars.checkboxControlSize = .regular
        case "small":
            appvars.checkboxControlSize = .small
        case "large":
            appvars.checkboxControlSize = .large
        case "mini":
            appvars.checkboxControlSize = .mini
        default:
            appvars.checkboxControlSize = .mini
        }
    }

    if appArguments.mainImage.present {
        writeLog("\(appArguments.mainImage.long) present")
        if json[appArguments.mainImage.long].exists() {
            if json[appArguments.mainImage.long].array == nil {
                // not an array so pull the single value
                appvars.imageArray.append(MainImage(path: json[appArguments.mainImage.long].stringValue))
            } else {
                for index in 0..<json[appArguments.mainImage.long].arrayValue.count {
                    appvars.imageArray.append(MainImage(path: json[appArguments.mainImage.long][index]["imagename"].stringValue, caption: json[appArguments.mainImage.long][index]["caption"].stringValue))
                    //appvars.imageArray = json[appArguments.mainImage.long][index].stringValue
                    //appvars.imageCaptionArray = json[appArguments.mainImage.long].arrayValue.map {$0["caption"].stringValue}
                }
            }
        } else {
            let imgArray = CLOptionMultiOptions(optionName: appArguments.mainImage.long)
            for index in 0..<imgArray.count {
                appvars.imageArray.append(MainImage(path: imgArray[index]))
            }
        }
        if !appArguments.messageOption.present {
            appArguments.messageOption.value = ""
        }
        writeLog("imageArray : \(appvars.imageArray)")
    }

    if json[appArguments.mainImageCaption.long].exists() || appArguments.mainImageCaption.present {
        writeLog("\(appArguments.mainImageCaption.long) present")
        if json[appArguments.mainImageCaption.long].exists() {
            appvars.imageCaptionArray.append(json[appArguments.mainImageCaption.long].stringValue)
        } else {
            appvars.imageCaptionArray = CLOptionMultiOptions(optionName: appArguments.mainImageCaption.long)
        }
                                writeLog("imageCaptionArray : \(appvars.imageCaptionArray)")
        for index in 0..<appvars.imageCaptionArray.count where index < appvars.imageArray.count {
            appvars.imageArray[index].caption = appvars.imageCaptionArray[index]
        }
    }

    if appArguments.listItem.present {
        writeLog("\(appArguments.listItem.long) present")
        if json[appArguments.listItem.long].exists() {

            for index in 0..<json[appArguments.listItem.long].arrayValue.count {
                if json[appArguments.listItem.long][index]["title"].stringValue == "" {
                    userInputState.listItems.append(ListItems(title: String(json[appArguments.listItem.long][index].stringValue)))
                } else {
                    userInputState.listItems.append(ListItems(title: String(json[appArguments.listItem.long][index]["title"].stringValue),
                                               subTitle: String(json[appArguments.listItem.long][index]["subtitle"].stringValue),
                                               icon: String(json[appArguments.listItem.long][index]["icon"].stringValue),
                                               statusText: String(json[appArguments.listItem.long][index]["statustext"].stringValue),
                                               statusIcon: String(json[appArguments.listItem.long][index]["status"].stringValue))
                                )
                }
            }

        } else {

            for listItem in CLOptionMultiOptions(optionName: appArguments.listItem.long) {
                let items = listItem.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var title: String = ""
                var subTitle: String = ""
                var icon: String = ""
                var statusText: String = ""
                var statusIcon: String = ""
                for item in items {
                    var itemKeyValuePair = item.split(separator: "=", maxSplits: 1)
                    for _ in itemKeyValuePair.count...2 {
                        itemKeyValuePair.append("")
                    }
                    let itemName = String(itemKeyValuePair[0])
                    let itemValue = String(itemKeyValuePair[1])
                    switch itemName.lowercased() {
                    case "title":
                        title = itemValue
                    case "subtitle":
                        subTitle = itemValue
                    case "icon":
                        icon = itemValue
                    case "statustext":
                        statusText = itemValue
                    case "status":
                        statusIcon = itemValue
                    default:
                        title = itemName
                    }
                }
                userInputState.listItems.append(ListItems(title: title, subTitle: subTitle, icon: icon, statusText: statusText, statusIcon: statusIcon))
            }
        }
        if userInputState.listItems.isEmpty {
            appArguments.listItem.present = false
        }
    }

    // Process view order
    if appArguments.preferredViewOrder.present {
        appvars.viewOrder = reorderViewArray(orderList: appArguments.preferredViewOrder.value, viewOrderArray: appvars.viewOrder) ?? appvars.viewOrder
    }

    if !json[appArguments.autoPlay.long].exists() && !appArguments.autoPlay.present {
        writeLog("\(appArguments.autoPlay.long) present")
        appArguments.autoPlay.value = "0"
                                writeLog("autoPlay.value : \(appArguments.autoPlay.value)")
    }

    if appArguments.ignoreDND.present {
        writeLog("\(appArguments.ignoreDND.long) set")
        appvars.willDisturb = true
    }

    if appArguments.listFonts.present {
        writeLog("\(appArguments.listFonts.long) called")
        //All font Families
        let fontfamilies = NSFontManager.shared.availableFontFamilies
        print("Available font families:")
        for familyname in fontfamilies.enumerated() {
            print("  \(familyname.element)")
        }

        // All font names
        let fonts = NSFontManager.shared.availableFonts
        print("Available font names:")
        for fontname in fonts.enumerated() {
            print("  \(fontname.element)")
        }
        quitDialog(exitCode: appDefaults.exit0.code)
    }

    if appArguments.windowWidth.present {
        writeLog("\(appArguments.windowWidth.long) present")
        if appArguments.windowWidth.value.last == "%" {
            appvars.windowWidth = appvars.screenWidth * appArguments.windowWidth.value.replacingOccurrences(of: "%", with: "").floatValue()/100
        } else {
            appvars.windowWidth = appArguments.windowWidth.value.floatValue(defaultValue: appvars.windowWidth)
        }
        writeLog("windowWidth : \(appvars.windowWidth)")
    }
    if appArguments.windowHeight.present {
        writeLog("\(appArguments.windowHeight.long) present")
        if appArguments.windowHeight.value.last == "%" {
            appvars.windowHeight = appvars.screenHeight * appArguments.windowHeight.value.replacingOccurrences(of: "%", with: "").floatValue()/100
        } else {
            appvars.windowHeight = appArguments.windowHeight.value.floatValue(defaultValue: appvars.windowHeight)
        }
        writeLog("windowHeight : \(appvars.windowHeight)")
    }

    if appArguments.iconSize.present {
        writeLog("\(appArguments.iconSize.long) present")
        //appvars.windowWidth = CGFloat() //CLOptionText(OptionName: appArguments.windowWidth)
        appvars.iconWidth = appArguments.iconSize.value.floatValue(defaultValue: appvars.iconWidth)
        writeLog("iconWidth : \(appvars.iconWidth)")
    }
    // Correct feng shui so the app accepts keyboard input
    // from https://stackoverflow.com/questions/58872398/what-is-the-minimally-viable-gui-for-command-line-swift-scripts
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    if appArguments.bannerTitle.present {
        writeLog("\(appArguments.bannerTitle.long) present")
        appvars.titleFontColour = Color.white
    }

    if appArguments.titleFont.present {
        writeLog("\(appArguments.titleFont.long) present")

        if appArguments.titleFont.value == "" {
                                    writeLog("titleFont.object : \(json[appArguments.titleFont.long].object)")

            if json[appArguments.titleFont.long]["size"].exists() {
                appvars.titleFontSize = json[appArguments.titleFont.long]["size"].number as! CGFloat
            }
            if json[appArguments.titleFont.long]["weight"].exists() {
                appvars.titleFontWeight = Font.Weight(argument: json[appArguments.titleFont.long]["weight"].stringValue)
            }
            if json[appArguments.titleFont.long]["colour"].exists() {
                appvars.titleFontColour = Color(argument: json[appArguments.titleFont.long]["colour"].stringValue)
                writeLog("found a colour of \(json[appArguments.titleFont.long]["colour"].stringValue)", logLevel: .debug)
            } else if json[appArguments.titleFont.long]["color"].exists() {
                appvars.titleFontColour = Color(argument: json[appArguments.titleFont.long]["color"].stringValue)
            }
            if json[appArguments.titleFont.long]["name"].exists() {
                appvars.titleFontName = json[appArguments.titleFont.long]["name"].stringValue
            }
        } else {
            writeLog("titleFont.value : \(appArguments.titleFont.value)")
            let fontCLValues = appArguments.titleFont.value
            var fontValues = [""]
            //split by ,
            fontValues = fontCLValues.components(separatedBy: ",")
            fontValues = fontValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
            for value in fontValues {
                // split by =
                let item = value.components(separatedBy: "=")
                switch item[0] {
                    case  "size":
                        appvars.titleFontSize = item[1].floatValue(defaultValue: appvars.titleFontSize)
                        writeLog("titleFontSize : \(appvars.titleFontSize)")
                    case  "weight":
                        appvars.titleFontWeight = Font.Weight(argument: item[1])
                        writeLog("titleFontWeight : \(appvars.titleFontWeight)")
                    case  "colour","color":
                        appvars.titleFontColour = Color(argument: item[1])
                        writeLog("titleFontColour : \(appvars.titleFontColour)")
                    case  "name":
                        appvars.titleFontName = item[1]
                        writeLog("titleFontName : \(appvars.titleFontName)")
                    case  "shadow":
                        appvars.titleFontShadow = item[1].boolValue
                        writeLog("titleFontShadow : \(appvars.titleFontShadow)")
                    default:
                        writeLog("Unknown paramater \(item[0])")
                }

            }
        }
    }


    if appArguments.messageFont.present {
        writeLog("\(appArguments.messageFont.long) present")

        if appArguments.messageFont.value == "" {
                                    writeLog("messageFont.object : \(json[appArguments.messageFont.long].object)")
            if json[appArguments.messageFont.long]["size"].exists() {
                appvars.messageFontSize = json[appArguments.messageFont.long]["size"].number as! CGFloat
            }
            if json[appArguments.messageFont.long]["weight"].exists() {
                appvars.messageFontWeight = Font.Weight(argument: json[appArguments.messageFont.long]["weight"].stringValue)
            }
            if json[appArguments.messageFont.long]["colour"].exists() {
                appvars.messageFontColour = Color(argument: json[appArguments.messageFont.long]["colour"].stringValue)
            } else if json[appArguments.messageFont.long]["color"].exists() {
                appvars.messageFontColour = Color(argument: json[appArguments.messageFont.long]["color"].stringValue)
            }
            if json[appArguments.messageFont.long]["name"].exists() {
                appvars.messageFontName = json[appArguments.messageFont.long]["name"].stringValue
            }
        } else {

                                    writeLog("messageFont.value : \(appArguments.messageFont.value)")
            let fontCLValues = appArguments.messageFont.value
            var fontValues = [""]
            //split by ,
            fontValues = fontCLValues.components(separatedBy: ",")
            fontValues = fontValues.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
            for value in fontValues {
                // split by =
                let item = value.components(separatedBy: "=")
                switch item[0] {
                    case "size":
                        appvars.messageFontSize = item[1].floatValue(defaultValue: appvars.messageFontSize)
                        writeLog("messageFontSize : \(appvars.messageFontSize)")
                    case "weight":
                        appvars.messageFontWeight = Font.Weight(argument: item[1])
                        writeLog("messageFontWeight : \(appvars.messageFontWeight)")
                    case "colour","color":
                        appvars.messageFontColour = Color(argument: item[1])
                        writeLog("messageFontColour : \(appvars.messageFontColour)")
                    case "name":
                        appvars.messageFontName = item[1]
                        writeLog("messageFontName : \(appvars.messageFontName)")
                    default:
                        writeLog("Unknown paramater \(item[0])")
                }
            }
        }
        if appvars.messageFontSize < 20 {
            appvars.labelFontSize = appvars.messageFontSize
        } else {
            appvars.labelFontSize = appvars.messageFontSize - 4
        }
    }

    if appArguments.iconOption.value != "" {
        writeLog("\(appArguments.iconOption.long) present")
        appArguments.iconOption.present = true
        if json["icons"].exists() {
            writeLog("processing multiple icons from json")
            for index in 0..<json["icons"].count {
                userInputState.iconItems.append(Icons(value: json["icons"][index]["icon"].stringValue))
            }
            // use index 0 for the default icon value
            appArguments.iconOption.value = userInputState.iconItems[0].value
        } else if json["icon"].exists() {
            userInputState.iconItems.append(Icons(value: json["icon"].stringValue))
        } else {
            for iconOption in CLOptionMultiOptions(optionName: appArguments.iconOption.long) {
                userInputState.iconItems.append(Icons(value: iconOption))
            }
        }
    }

    // hide the icon if asked to or if banner image is present
    if appArguments.hideIcon.present || appArguments.iconOption.value == "none" || appArguments.bannerImage.present {
        writeLog("\(appArguments.hideIcon.long) set")
        appArguments.iconOption.present = false
    }

    // of both banner image and icon are specified, re-enable the icon.
    if appArguments.bannerImage.present && appArguments.iconOption.value != "none" && appArguments.iconOption.value != "default" {
        writeLog("both banner image and icon are specified, re-enable the icon")
        appArguments.iconOption.present = true
    }

    if appArguments.loginWindow.present {
        appArguments.forceOnTop.present = true
    }

    if appArguments.forceOnTop.present {
        appArguments.showOnAllScreens.present = true
        writeLog("windowOnTop = true")
    }

    // we define this stuff here as we will use the info to draw the window.
    if appArguments.smallWindow.present {
        appvars.scaleFactor = 0.75
        if !appArguments.iconSize.present {
            appArguments.iconSize.value = "120"
        }
        writeLog("smallWindow.present")
    } else if appArguments.bigWindow.present {
        appvars.scaleFactor = 1.25
        writeLog("bigWindow.present")
    }

    if appArguments.windowButtonsEnabled.present {
        if appArguments.windowButtonsEnabled.value != "" {
            // Reset default state to all false
            appvars.windowCloseEnabled = false
            appvars.windowMinimiseEnabled = false
            appvars.windowMaximiseEnabled = false

            let enabledStates = appArguments.windowButtonsEnabled.value.components(separatedBy: ",")
            for state in enabledStates {
                switch state.lowercased() {
                case "min":
                    appvars.windowMinimiseEnabled = true
                case "max":
                    appvars.windowMaximiseEnabled = true
                case "close":
                    appvars.windowCloseEnabled = true
                default: ()
                }
            }
        }
    }

    if appArguments.windowResizable.present {
        appvars.windowWidth = .infinity
        appvars.windowHeight = .infinity
        appArguments.movableWindow.present = true
    }

    //if info button is present but no button action then default to quit on info
    if !appArguments.buttonInfoActionOption.present {
        writeLog("\(appArguments.quitOnInfo.long) enabled")
        appArguments.quitOnInfo.present = true
    }

    if appArguments.timerBar.present && !appArguments.hideTimerBar.present {
        appArguments.button1Disabled.present = true
    }

}

