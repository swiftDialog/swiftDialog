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
        quitDialog(exitCode: appvars.exit202.code, exitMessage: "\(appvars.exit202.message) \(jsonFilePath)")
    }

    do {
        json = try JSON(data: jsonData)
    } catch {
        quitDialog(exitCode: appvars.exit202.code, exitMessage: "JSON import failed")
    }
    return json
}

func processJSONString(jsonString: String) -> JSON {
    var json = JSON()
    let dataFromString = jsonString.replacingOccurrences(of: "\n", with: "\\n").data(using: .utf8)
    do {
        json = try JSON(data: dataFromString!)
    } catch {
        quitDialog(exitCode: appvars.exit202.code, exitMessage: "JSON import failed")
    }
    return json
}

func getJSON() -> JSON {
    var json = JSON()
    if CLOptionPresent(OptionName: appArguments.jsonFile) {
        // read json in from file
        json = processJSON(jsonFilePath: CLOptionText(OptionName: appArguments.jsonFile))
    }
    
    if CLOptionPresent(OptionName: appArguments.jsonString) {
        // read json in from text string
        json = processJSONString(jsonString: CLOptionText(OptionName: appArguments.jsonString))
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

func processCLOptions(json: JSON = getJSON()) {

    //this method goes through the arguments that are present and performs any processing required before use
    writeLog("Processing Options")
    if appArguments.messageOption.present && appArguments.messageOption.value.lowercased().hasSuffix(".md") {
        appArguments.messageOption.value = getMarkdown(mdFilePath: appArguments.messageOption.value)
    }
    
    if appArguments.dropdownValues.present {
        writeLog("\(appArguments.dropdownValues.long) present")
        // checking for the pre 1.10 way of defining a select list
        if json[appArguments.dropdownValues.long].exists() && !json["selectitems"].exists() {
            writeLog("processing select list from json")
            let selectValues = json[appArguments.dropdownValues.long].arrayValue.map {$0.stringValue}
            let selectTitle = json[appArguments.dropdownTitle.long].stringValue
            let selectDefault = json[appArguments.dropdownDefault.long].stringValue
            appvars.dropdownItems.append(DropDownItems(title: selectTitle, values: selectValues, defaultValue: selectDefault, selectedValue: selectDefault))
        }

        if json["selectitems"].exists() {
            writeLog("processing select items from json")
            for i in 0..<json["selectitems"].count {                
                appvars.dropdownItems.append(DropDownItems(
                        title: json["selectitems"][i]["title"].stringValue,
                        values: (json["selectitems"][i]["values"].arrayValue.map {$0.stringValue}).map { $0.trimmingCharacters(in: .whitespaces) },
                        defaultValue: json["selectitems"][i]["default"].stringValue,
                        selectedValue: json["selectitems"][i]["default"].stringValue,
                        required: json["selectitems"][i]["required"].boolValue,
                        style: json["selectitems"][i]["style"].stringValue
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

            for i in 0..<(dropdownValues.count) {
                let labelItems = dropdownLabels[i].components(separatedBy: ",")
                var dropdownRequired: Bool = false
                var dropdownStyle: String = "list"
                let dropdownTitle: String = labelItems[0]
                if labelItems.count > 1 {
                    if labelItems[1] == "required" {
                        dropdownRequired = true
                    }
                    if labelItems[1] == "radio" {
                        dropdownStyle = labelItems[1]
                    }
                }
                appvars.dropdownItems.append(DropDownItems(title: dropdownTitle, values: dropdownValues[i].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }, defaultValue: dropdownDefaults[i], selectedValue: dropdownDefaults[i], required: dropdownRequired, style: dropdownStyle))
            }
        }
        for i in 0..<appvars.dropdownItems.count where appvars.dropdownItems[i].required {
            appvars.userInputRequired = true
        }
        writeLog("Processed \(appvars.dropdownItems.count) select items")
    }
    
    if appArguments.textField.present {
        writeLog("\(appArguments.textField.long) present")
        if json[appArguments.textField.long].exists() {
            for i in 0..<json[appArguments.textField.long].arrayValue.count {
                if json[appArguments.textField.long][i]["title"].stringValue == "" {
                    appvars.textFields.append(TextFieldState(title: String(json[appArguments.textField.long][i].stringValue)))
                } else {
                    appvars.textFields.append(TextFieldState(
                        editor: Bool(json[appArguments.textField.long][i]["editor"].boolValue),
                        fileSelect: Bool(json[appArguments.textField.long][i]["fileselect"].boolValue),
                        fileType: String(json[appArguments.textField.long][i]["filetype"].stringValue),
                        passwordFill: Bool(json[appArguments.textField.long][i]["passwordfill"].boolValue),
                        prompt: String(json[appArguments.textField.long][i]["prompt"].stringValue),
                        regex: String(json[appArguments.textField.long][i]["regex"].stringValue),
                        regexError: String(json[appArguments.textField.long][i]["regexerror"].stringValue),
                        required: Bool(json[appArguments.textField.long][i]["required"].boolValue),
                        secure: Bool(json[appArguments.textField.long][i]["secure"].boolValue),
                        title: String(json[appArguments.textField.long][i]["title"].stringValue),
                        value: String(json[appArguments.textField.long][i]["value"].stringValue))
                    )
                }
            }
        } else {
            for textFieldOption in CLOptionMultiOptions(optionName: appArguments.textField.long) {
                let items = textFieldOption.split(usingRegex: appvars.argRegex)
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
                var fieldValue: String = ""
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
                            default: ()
                            }
                        }
                    }
                }
                appvars.textFields.append(TextFieldState(
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
                            value: fieldValue))
            }
        }
        for i in 0..<appvars.textFields.count where appvars.textFields[i].required {
            appvars.userInputRequired = true
        }
        writeLog("textOptionsArray : \(appvars.textFields)")
    }
    
    if appArguments.checkbox.present {
        writeLog("\(appArguments.checkbox.long) present")
        if json[appArguments.checkbox.long].exists() {
            for i in 0..<json[appArguments.checkbox.long].arrayValue.count {
                let cbLabel = json[appArguments.checkbox.long][i]["label"].stringValue
                let cbChecked = json[appArguments.checkbox.long][i]["checked"].boolValue
                let cbDisabled = json[appArguments.checkbox.long][i]["disabled"].boolValue
                let cbIcon = json[appArguments.checkbox.long][i]["icon"].stringValue
                
                appvars.checkboxArray.append(CheckBoxes(label: cbLabel, icon: cbIcon, checked: cbChecked, disabled: cbDisabled))
            }
        } else {
            for checkboxes in CLOptionMultiOptions(optionName: appArguments.checkbox.long) {
                let items = checkboxes.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var label: String = ""
                var icon: String = ""
                var checked: Bool = false
                var disabled: Bool = false
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
                    case "icon":
                        icon = itemValue
                    case "checked":
                        checked = true
                    case "disabled":
                        disabled = true
                    default:
                        label = itemName
                    }
                }
                appvars.checkboxArray.append(CheckBoxes(label: label, icon: icon, checked: checked, disabled: disabled))
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
                for i in 0..<json[appArguments.mainImage.long].arrayValue.count {
                    appvars.imageArray.append(MainImage(path: json[appArguments.mainImage.long][i]["imagename"].stringValue, caption: json[appArguments.mainImage.long][i]["caption"].stringValue))
                    //appvars.imageArray = json[appArguments.mainImage.long][i].stringValue
                    //appvars.imageCaptionArray = json[appArguments.mainImage.long].arrayValue.map {$0["caption"].stringValue}
                }
            }
        } else {
            let imgArray = CLOptionMultiOptions(optionName: appArguments.mainImage.long)
            for i in 0..<imgArray.count {
                appvars.imageArray.append(MainImage(path: imgArray[i]))
            }
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
        for i in 0..<appvars.imageCaptionArray.count where i < appvars.imageArray.count {
            appvars.imageArray[i].caption = appvars.imageCaptionArray[i]
        }
    }
    
    if appArguments.listItem.present {
        writeLog("\(appArguments.listItem.long) present")
        if json[appArguments.listItem.long].exists() {
            
            for i in 0..<json[appArguments.listItem.long].arrayValue.count {
                if json[appArguments.listItem.long][i]["title"].stringValue == "" {
                    appvars.listItems.append(ListItems(title: String(json[appArguments.listItem.long][i].stringValue)))
                } else {
                    appvars.listItems.append(ListItems(title: String(json[appArguments.listItem.long][i]["title"].stringValue),
                                               icon: String(json[appArguments.listItem.long][i]["icon"].stringValue),
                                               statusText: String(json[appArguments.listItem.long][i]["statustext"].stringValue),
                                               statusIcon: String(json[appArguments.listItem.long][i]["status"].stringValue))
                                )
                }
            }

        } else {
            
            for listItem in CLOptionMultiOptions(optionName: appArguments.listItem.long) {
                let items = listItem.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var title: String = ""
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
                appvars.listItems.append(ListItems(title: title, icon: icon, statusText: statusText, statusIcon: statusIcon))
            }
        }
        if appvars.listItems.isEmpty {
            appArguments.listItem.present = false
        }
    }
    
    if !json[appArguments.autoPlay.long].exists() && !appArguments.autoPlay.present {
        writeLog("\(appArguments.autoPlay.long) present")
        appArguments.autoPlay.value = "0"
                                writeLog("autoPlay.value : \(appArguments.autoPlay.value)")
    }

    // process command line options that just display info and exit before we show the main window
    if appArguments.helpOption.present || CommandLine.arguments.count == 1 {
        writeLog("\(appArguments.helpOption.long) present")
        let sdHelp = SDHelp(arguments: appArguments)
        if appArguments.helpOption.value != "" {
            writeLog("Printing help for \(appArguments.helpOption.value)")
            sdHelp.printHelpLong(for: appArguments.helpOption.value)
        } else {
            sdHelp.printHelpShort()
        }
        quitDialog(exitCode: appvars.exitNow.code)
    }
    if appArguments.getVersion.present {
        writeLog("\(appArguments.getVersion.long) called")
        printVersionString()
        quitDialog(exitCode: appvars.exitNow.code)
    }
    if appArguments.licence.present {
        writeLog("\(appArguments.licence.long) called")
        print(licenseText)
        quitDialog(exitCode: appvars.exitNow.code)
    }
    if appArguments.buyCoffee.present {
        writeLog("\(appArguments.buyCoffee.long) called :)")
        //I'm a teapot
        print("If you like this app and want to buy me a coffee https://www.buymeacoffee.com/bartreardon")
        quitDialog(exitCode: appvars.exitNow.code)
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
        quitDialog(exitCode: appvars.exit0.code)
    }
        
    if appArguments.windowWidth.present {
        writeLog("\(appArguments.windowWidth.long) present")
        //appvars.windowWidth = CGFloat() //CLOptionText(OptionName: appArguments.windowWidth)
        if appArguments.windowWidth.value.last == "%" {
            appvars.windowWidth = appvars.screenWidth * string2float(string: String(appArguments.windowWidth.value.dropLast()))/100
        } else {
            appvars.windowWidth = string2float(string: appArguments.windowWidth.value)
        }
                                writeLog("windowWidth : \(appvars.windowWidth)")
    }
    if appArguments.windowHeight.present {
        writeLog("\(appArguments.windowHeight.long) present")
        //appvars.windowHeight = CGFloat() //CLOptionText(OptionName: appArguments.windowHeight)
        if appArguments.windowHeight.value.last == "%" {
            appvars.windowHeight = appvars.screenHeight * string2float(string: String(appArguments.windowHeight.value.dropLast()))/100
        } else {
            appvars.windowHeight = string2float(string: appArguments.windowHeight.value)
        }
                                writeLog("windowHeight : \(appvars.windowHeight)")
    }
    
    if appArguments.iconSize.present {
        writeLog("\(appArguments.iconSize.long) present")
        //appvars.windowWidth = CGFloat() //CLOptionText(OptionName: appArguments.windowWidth)
        appvars.iconWidth = string2float(string: appArguments.iconSize.value)
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
                appvars.titleFontSize = string2float(string: json[appArguments.titleFont.long]["size"].stringValue, defaultValue: appvars.titleFontSize)
            }
            if json[appArguments.titleFont.long]["weight"].exists() {
                appvars.titleFontWeight = textToFontWeight(json[appArguments.titleFont.long]["weight"].stringValue)
            }
            if json[appArguments.titleFont.long]["colour"].exists() {
                appvars.titleFontColour = stringToColour(json[appArguments.titleFont.long]["colour"].stringValue)
                print("found a colour of \(json[appArguments.titleFont.long]["colour"].stringValue)")
            } else if json[appArguments.titleFont.long]["color"].exists() {
                appvars.titleFontColour = stringToColour(json[appArguments.titleFont.long]["color"].stringValue)
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
                        appvars.titleFontSize = string2float(string: item[1], defaultValue: appvars.titleFontSize)
                                                writeLog("titleFontSize : \(appvars.titleFontSize)")
                    case  "weight":
                        appvars.titleFontWeight = textToFontWeight(item[1])
                                                writeLog("titleFontWeight : \(appvars.titleFontWeight)")
                    case  "colour","color":
                        appvars.titleFontColour = stringToColour(item[1])
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
                appvars.messageFontSize = string2float(string: json[appArguments.messageFont.long]["size"].stringValue, defaultValue: appvars.messageFontSize)
            }
            if json[appArguments.messageFont.long]["weight"].exists() {
                appvars.messageFontWeight = textToFontWeight(json[appArguments.messageFont.long]["weight"].stringValue)
            }
            if json[appArguments.messageFont.long]["colour"].exists() {
                appvars.messageFontColour = stringToColour(json[appArguments.messageFont.long]["colour"].stringValue)
            } else if json[appArguments.messageFont.long]["color"].exists() {
                appvars.messageFontColour = stringToColour(json[appArguments.messageFont.long]["color"].stringValue)
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
                        appvars.messageFontSize = string2float(string: item[1], defaultValue: appvars.messageFontSize)
                                                writeLog("messageFontSize : \(appvars.messageFontSize)")
                    case "weight":
                        appvars.messageFontWeight = textToFontWeight(item[1])
                                                writeLog("messageFontWeight : \(appvars.messageFontWeight)")
                    case "colour","color":
                        appvars.messageFontColour = stringToColour(item[1])
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
        
    if appArguments.bannerImage.present && appArguments.iconOption.present {
        writeLog("banner image and icon are specified, un-hide the icon")
        appvars.iconIsHidden = false
    }

    if appArguments.centreIcon.present {
        appvars.iconIsCentred = true
        writeLog("iconIsCentred = true")
    }

    if appArguments.movableWindow.present {
        appvars.windowIsMoveable = true
        writeLog("windowIsMoveable = true")
    }
    
    if appArguments.forceOnTop.present {
        appvars.windowOnTop = true
        writeLog("windowOnTop = true")
    }
    
    if appArguments.jsonOutPut.present {
        appvars.jsonOut = true
        writeLog("jsonOut = true")
    }

    // we define this stuff here as we will use the info to draw the window.
    if appArguments.smallWindow.present {
        // scale everything down a notch
        appvars.smallWindow = true
        appvars.scaleFactor = 0.75
        if !appArguments.iconSize.present {
            appArguments.iconSize.value = "120"
        }
        writeLog("smallWindow.present")
    } else if appArguments.bigWindow.present {
        // scale everything up a notch
        appvars.bigWindow = true
        appvars.scaleFactor = 1.25
        writeLog("bigWindow.present")
    }

    //if info button is present but no button action then default to quit on info
    if !appArguments.buttonInfoActionOption.present {
        writeLog("\(appArguments.quitOnInfo.long) enabled")
        appArguments.quitOnInfo.present = true
    }
}

func processCLOptionValues() {
    
    // this method reads in arguments from either json file or from the command line and loads them into the appArguments object
    // also records whether an argument is present or not
    writeLog("Checking command line options for arguments")
    let json: JSON = getJSON()
    
    appArguments.titleOption.value             = json[appArguments.titleOption.long].string ?? CLOptionText(OptionName: appArguments.titleOption, DefaultValue: appvars.titleDefault)
    appArguments.titleOption.present           = json[appArguments.titleOption.long].exists() || CLOptionPresent(OptionName: appArguments.titleOption)
    
    appArguments.subTitleOption.value          = json[appArguments.subTitleOption.long].string ?? CLOptionText(OptionName: appArguments.subTitleOption)
    appArguments.subTitleOption.present        = json[appArguments.subTitleOption.long].exists() || CLOptionPresent(OptionName: appArguments.subTitleOption)

    appArguments.messageOption.value           = json[appArguments.messageOption.long].string ?? CLOptionText(OptionName: appArguments.messageOption, DefaultValue: appvars.messageDefault)
    appArguments.messageOption.present         = json[appArguments.messageOption.long].exists() || CLOptionPresent(OptionName: appArguments.messageOption)
    
    appArguments.messageAlignment.value        = json[appArguments.messageAlignment.long].string ?? CLOptionText(OptionName: appArguments.messageAlignment, DefaultValue: appvars.messageAlignmentTextRepresentation)
    appArguments.messageAlignment.present      = json[appArguments.messageAlignment.long].exists() || CLOptionPresent(OptionName: appArguments.messageAlignment)
    
    appArguments.messageAlignmentOld.value        = json[appArguments.messageAlignmentOld.long].string ?? CLOptionText(OptionName: appArguments.messageAlignmentOld, DefaultValue: appvars.messageAlignmentTextRepresentation)
    appArguments.messageAlignmentOld.present      = json[appArguments.messageAlignmentOld.long].exists() || CLOptionPresent(OptionName: appArguments.messageAlignmentOld)
    
    if appArguments.messageAlignmentOld.present {
        appArguments.messageAlignment.present = appArguments.messageAlignmentOld.present
        appArguments.messageAlignment.value = appArguments.messageAlignmentOld.value
    }
    
    if appArguments.messageAlignment.present {
        appvars.messageAlignment = appvars.allignmentStates[appArguments.messageAlignment.value] ?? .leading
    }
    
    appArguments.messageVerticalAlignment.value = json[appArguments.messageVerticalAlignment.long].string ?? CLOptionText(OptionName: appArguments.messageVerticalAlignment)
    appArguments.messageVerticalAlignment.present = json[appArguments.messageVerticalAlignment.long].exists() || CLOptionPresent(OptionName: appArguments.messageVerticalAlignment)

    appArguments.helpMessage.value           = json[appArguments.helpMessage.long].string ?? CLOptionText(OptionName: appArguments.helpMessage)
    appArguments.helpMessage.present         = json[appArguments.helpMessage.long].exists() || CLOptionPresent(OptionName: appArguments.helpMessage)
    
    appArguments.position.value           = json[appArguments.position.long].string ?? CLOptionText(OptionName: appArguments.position)
    appArguments.position.present         = json[appArguments.position.long].exists() || CLOptionPresent(OptionName: appArguments.position)
    
    // window location on screen
    if appArguments.position.present {
        writeLog("Window position will be set to \(appArguments.position.value)")
        switch appArguments.position.value {
        case "topleft":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.top
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.left
        case "topright":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.top
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.right
        case "bottomleft":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.bottom
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.left
        case "bottomright":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.bottom
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.right
        case "left":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.center
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.left
        case "right":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.center
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.right
        case "top":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.top
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.center
        case "bottom":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.bottom
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.center
        case "centre","center":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.deadcenter
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.center
        default:
            appvars.windowPositionVertical = NSWindow.Position.Vertical.center
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.center
        }
    }

    appArguments.iconOption.value              = json[appArguments.iconOption.long].string ?? CLOptionText(OptionName: appArguments.iconOption, DefaultValue: "default")
    appArguments.iconOption.present            = json[appArguments.iconOption.long].exists() || CLOptionPresent(OptionName: appArguments.iconOption)
    
    appArguments.iconSize.value                = json[appArguments.iconSize.long].string ?? CLOptionText(OptionName: appArguments.iconSize, DefaultValue: "\(appvars.iconWidth)")
    appArguments.iconSize.present              = json[appArguments.iconSize.long].exists() || CLOptionPresent(OptionName: appArguments.iconSize)
    
    appArguments.iconAlpha.value                = json[appArguments.iconAlpha.long].string ?? CLOptionText(OptionName: appArguments.iconAlpha, DefaultValue: "1.0")
    appArguments.iconAlpha.present              = json[appArguments.iconAlpha.long].exists() || CLOptionPresent(OptionName: appArguments.iconAlpha)
    
    appArguments.iconAccessabilityLabel.value  = json[appArguments.iconAccessabilityLabel.long].string ?? CLOptionText(OptionName: appArguments.iconAccessabilityLabel, DefaultValue: "Dialog Icon")
    appArguments.iconAccessabilityLabel.present = json[appArguments.iconAccessabilityLabel.long].exists() || CLOptionPresent(OptionName: appArguments.iconAccessabilityLabel)

    appArguments.overlayIconOption.value       = json[appArguments.overlayIconOption.long].string ?? CLOptionText(OptionName: appArguments.overlayIconOption)
    appArguments.overlayIconOption.present     = json[appArguments.overlayIconOption.long].exists() || CLOptionPresent(OptionName: appArguments.overlayIconOption)

    appArguments.bannerImage.value             = json[appArguments.bannerImage.long].string ?? CLOptionText(OptionName: appArguments.bannerImage)
    appArguments.bannerImage.present           = json[appArguments.bannerImage.long].exists() || CLOptionPresent(OptionName: appArguments.bannerImage)
    
    appArguments.bannerTitle.value             = json[appArguments.bannerTitle.long].string ?? CLOptionText(OptionName: appArguments.bannerTitle, DefaultValue: appArguments.titleOption.value)
    appArguments.bannerTitle.present           = json[appArguments.bannerTitle.long].exists() || CLOptionPresent(OptionName: appArguments.bannerTitle)
    
    appArguments.bannerText.value             = json[appArguments.bannerText.long].string ?? CLOptionText(OptionName: appArguments.bannerText, DefaultValue: appArguments.titleOption.value)
    appArguments.bannerText.present           = json[appArguments.bannerText.long].exists() || CLOptionPresent(OptionName: appArguments.bannerText)
    
    if appArguments.bannerText.present {
        appArguments.bannerTitle.value = appArguments.bannerText.value
        appArguments.bannerTitle.present = true
    }
    
    if appArguments.bannerTitle.present {
        appArguments.titleOption.value = appArguments.bannerTitle.value
    }
    
    appArguments.button1TextOption.value       = json[appArguments.button1TextOption.long].string ?? CLOptionText(OptionName: appArguments.button1TextOption, DefaultValue: appvars.button1Default)
    appArguments.button1TextOption.present     = json[appArguments.button1TextOption.long].exists() || CLOptionPresent(OptionName: appArguments.button1TextOption)

    appArguments.button1ActionOption.value     = json[appArguments.button1ActionOption.long].string ?? CLOptionText(OptionName: appArguments.button1ActionOption)
    appArguments.button1ActionOption.present   = json[appArguments.button1ActionOption.long].exists() || CLOptionPresent(OptionName: appArguments.button1ActionOption)

    appArguments.button1ShellActionOption.value = json[appArguments.button1ShellActionOption.long].string ?? CLOptionText(OptionName: appArguments.button1ShellActionOption)
    appArguments.button1ShellActionOption.present = json[appArguments.button1ShellActionOption.long].exists() || CLOptionPresent(OptionName: appArguments.button1ShellActionOption)
    
    appArguments.button1Disabled.present       = json[appArguments.button1Disabled.long].exists() || CLOptionPresent(OptionName: appArguments.button1Disabled)

    appArguments.button2TextOption.value       = json[appArguments.button2TextOption.long].string ?? CLOptionText(OptionName: appArguments.button2TextOption, DefaultValue: appvars.button2Default)
    appArguments.button2TextOption.present     = json[appArguments.button2TextOption.long].exists() || CLOptionPresent(OptionName: appArguments.button2TextOption)

    appArguments.button2ActionOption.value     = json[appArguments.button2ActionOption.long].string ?? CLOptionText(OptionName: appArguments.button2ActionOption)
    appArguments.button2ActionOption.present   = json[appArguments.button2ActionOption.long].exists() || CLOptionPresent(OptionName: appArguments.button2ActionOption)
    
    appArguments.button2Disabled.present       = json[appArguments.button2Disabled.long].exists() || CLOptionPresent(OptionName: appArguments.button2Disabled)

    appArguments.buttonInfoTextOption.value    = json[appArguments.buttonInfoTextOption.long].string ?? CLOptionText(OptionName: appArguments.buttonInfoTextOption, DefaultValue: appvars.buttonInfoDefault)
    appArguments.buttonInfoTextOption.present  = json[appArguments.buttonInfoTextOption.long].exists() || CLOptionPresent(OptionName: appArguments.buttonInfoTextOption)

    appArguments.buttonInfoActionOption.value  = json[appArguments.buttonInfoActionOption.long].string ?? CLOptionText(OptionName: appArguments.buttonInfoActionOption)
    appArguments.buttonInfoActionOption.present = json[appArguments.buttonInfoActionOption.long].exists() || CLOptionPresent(OptionName: appArguments.buttonInfoActionOption)

    appArguments.dropdownTitle.present         = json[appArguments.dropdownTitle.long].exists() || CLOptionPresent(OptionName: appArguments.dropdownTitle)

    appArguments.dropdownValues.present        = json["selectitems"].exists() || json[appArguments.dropdownValues.long].exists() || CLOptionPresent(OptionName: appArguments.dropdownValues)

    appArguments.dropdownDefault.present       = json[appArguments.dropdownDefault.long].exists() || CLOptionPresent(OptionName: appArguments.dropdownDefault)

    appArguments.titleFont.value               = json[appArguments.titleFont.long].string ?? CLOptionText(OptionName: appArguments.titleFont)
    appArguments.titleFont.present             = json[appArguments.titleFont.long].exists() || CLOptionPresent(OptionName: appArguments.titleFont)
    
    appArguments.messageFont.value             = json[appArguments.messageFont.long].string ?? CLOptionText(OptionName: appArguments.messageFont)
    appArguments.messageFont.present           = json[appArguments.messageFont.long].exists() || CLOptionPresent(OptionName: appArguments.messageFont)

    appArguments.textField.present             = json[appArguments.textField.long].exists() || CLOptionPresent(OptionName: appArguments.textField)
    
    appArguments.checkbox.present             = json[appArguments.checkbox.long].exists() || CLOptionPresent(OptionName: appArguments.checkbox)
    
    appArguments.checkboxStyle.present        = json[appArguments.checkboxStyle.long].exists() || CLOptionPresent(OptionName: appArguments.checkboxStyle)
    appArguments.checkboxStyle.value          = json[appArguments.checkboxStyle.long].string ?? CLOptionText(OptionName: appArguments.checkboxStyle)

    appArguments.timerBar.value                = json[appArguments.timerBar.long].string ?? CLOptionText(OptionName: appArguments.timerBar, DefaultValue: "\(appvars.timerDefaultSeconds)")
    appArguments.timerBar.present              = json[appArguments.timerBar.long].exists() || CLOptionPresent(OptionName: appArguments.timerBar)
    
    appArguments.progressBar.value             = json[appArguments.progressBar.long].string ?? CLOptionText(OptionName: appArguments.progressBar)
    appArguments.progressBar.present           = json[appArguments.progressBar.long].exists() || CLOptionPresent(OptionName: appArguments.progressBar)
    
    appArguments.progressText.value             = json[appArguments.progressText.long].string ?? CLOptionText(OptionName: appArguments.progressText, DefaultValue: " ")
    appArguments.progressText.present           = json[appArguments.progressText.long].exists() || CLOptionPresent(OptionName: appArguments.progressText)
    
    appArguments.mainImage.present             = json[appArguments.mainImage.long].exists() || CLOptionPresent(OptionName: appArguments.mainImage)
    
    appArguments.mainImageCaption.present      = json[appArguments.mainImageCaption.long].exists() || CLOptionPresent(OptionName: appArguments.mainImageCaption)
    
    appArguments.listItem.present              = json[appArguments.listItem.long].exists() || CLOptionPresent(OptionName: appArguments.listItem)
    
    appArguments.listStyle.value               = json[appArguments.listStyle.long].string ?? CLOptionText(OptionName: appArguments.listStyle)
    appArguments.listStyle.present             = json[appArguments.listStyle.long].exists() || CLOptionPresent(OptionName: appArguments.listStyle)

    appArguments.windowWidth.value             = json[appArguments.windowWidth.long].string ?? CLOptionText(OptionName: appArguments.windowWidth)
    appArguments.windowWidth.present           = json[appArguments.windowWidth.long].exists() || CLOptionPresent(OptionName: appArguments.windowWidth)

    appArguments.windowHeight.value            = json[appArguments.windowHeight.long].string ?? CLOptionText(OptionName: appArguments.windowHeight)
    appArguments.windowHeight.present          = json[appArguments.windowHeight.long].exists() || CLOptionPresent(OptionName: appArguments.windowHeight)
    
    appArguments.watermarkImage.value          = json[appArguments.watermarkImage.long].string ?? CLOptionText(OptionName: appArguments.watermarkImage)
    appArguments.watermarkImage.present        = json[appArguments.watermarkImage.long].exists() || CLOptionPresent(OptionName: appArguments.watermarkImage)
        
    appArguments.watermarkAlpha.value          = json[appArguments.watermarkAlpha.long].string ?? CLOptionText(OptionName: appArguments.watermarkAlpha)
    appArguments.watermarkAlpha.present        = json[appArguments.watermarkAlpha.long].exists() || CLOptionPresent(OptionName: appArguments.watermarkAlpha)
    
    appArguments.watermarkPosition.value       = json[appArguments.watermarkPosition.long].string ?? CLOptionText(OptionName: appArguments.watermarkPosition)
    appArguments.watermarkPosition.present     = json[appArguments.watermarkPosition.long].exists() || CLOptionPresent(OptionName: appArguments.watermarkPosition)
    
    appArguments.watermarkFill.value           = json[appArguments.watermarkFill.long].string ?? CLOptionText(OptionName: appArguments.watermarkFill)
    appArguments.watermarkFill.present         = json[appArguments.watermarkFill.long].exists() || CLOptionPresent(OptionName: appArguments.watermarkFill)
    
    appArguments.watermarkFill.value           = json[appArguments.watermarkScale.long].string ?? CLOptionText(OptionName: appArguments.watermarkScale)
    appArguments.watermarkFill.present         = json[appArguments.watermarkScale.long].exists() || CLOptionPresent(OptionName: appArguments.watermarkScale)
    
    appArguments.autoPlay.value                = json[appArguments.autoPlay.long].string ?? CLOptionText(OptionName: appArguments.autoPlay, DefaultValue: "\(appvars.timerDefaultSeconds)")
    appArguments.autoPlay.present              = json[appArguments.autoPlay.long].exists() || CLOptionPresent(OptionName: appArguments.autoPlay)
    
    appArguments.statusLogFile.value           = json[appArguments.statusLogFile.long].string ?? CLOptionText(OptionName: appArguments.statusLogFile)
    appArguments.statusLogFile.present         = json[appArguments.statusLogFile.long].exists() || CLOptionPresent(OptionName: appArguments.statusLogFile)
    
    appArguments.infoText.value                = json[appArguments.infoText.long].string ?? CLOptionText(OptionName: appArguments.infoText, DefaultValue: "swiftDialog \(getVersionString())")
    appArguments.infoText.present              = json[appArguments.infoText.long].exists() || CLOptionPresent(OptionName: appArguments.infoText)
        
    if (getVersionString().starts(with: "Alpha") || getVersionString().starts(with: "Beta")) && !appArguments.constructionKit.present {
        appArguments.infoText.present = true
    }
    
    appArguments.infoBox.value                = json[appArguments.infoBox.long].string ?? CLOptionText(OptionName: appArguments.infoBox)
    appArguments.infoBox.present              = json[appArguments.infoBox.long].exists() || CLOptionPresent(OptionName: appArguments.infoBox)
    
    appArguments.quitKey.value                 = json[appArguments.quitKey.long].string ?? CLOptionText(OptionName: appArguments.quitKey, DefaultValue: appvars.quitKeyCharacter)
    
    if !appArguments.statusLogFile.present {
        appArguments.statusLogFile.value = appvars.defaultStatusLogFile
    }
    
    appArguments.webcontent.value           = json[appArguments.webcontent.long].string ?? CLOptionText(OptionName: appArguments.webcontent)
    appArguments.webcontent.present         = json[appArguments.webcontent.long].exists() || CLOptionPresent(OptionName: appArguments.webcontent)
    
    appArguments.video.value                   = json[appArguments.video.long].string ?? CLOptionText(OptionName: appArguments.video)
    appArguments.video.present                 = json[appArguments.video.long].exists() || CLOptionPresent(OptionName: appArguments.video)
    if appArguments.video.present || appArguments.webcontent.present {
        // check if it's a youtube id
        switch appArguments.video.value.components(separatedBy: "=").first!.lowercased() {
        case "youtubeid":
            writeLog("Youtube ID detected")
            let youTubeID = appArguments.video.value.replacingOccurrences(of: "youtubeid=", with: "")
            let youtubeURL = "https://www.youtube.com/embed/\(youTubeID)?autoplay=\(appArguments.autoPlay.present ? 1 : 0)&controls=0&showinfo=0"
            appArguments.video.value = youtubeURL
        case "vimeoid":
            let vimeoID = appArguments.video.value.replacingOccurrences(of: "vimeoid=", with: "")
            let vimeoURL = "https://player.vimeo.com/video/\(vimeoID)\(vimeoID.contains("?") ? "&" : "?")autoplay=\(appArguments.autoPlay.present ? 1 : 0)&controls=\(appArguments.autoPlay.present ? 0 : 1)"
            appArguments.video.value = vimeoURL
        default:
            break
        }
        writeLog("video url is \(appArguments.video.value)")
        // set a larger window size. 900x600 will fit a standard 16:9 video
        writeLog("resetting default window size to 900x600")
        appvars.windowWidth = appvars.videoWindowWidth
        appvars.windowHeight = appvars.videoWindowHeight
    }
    
    appArguments.videoCaption.value            = json[appArguments.videoCaption.long].string ?? CLOptionText(OptionName: appArguments.videoCaption)
    appArguments.videoCaption.present          = json[appArguments.videoCaption.long].exists() || CLOptionPresent(OptionName: appArguments.videoCaption)

    if appArguments.watermarkImage.present {
        // return the image resolution and re-size the window to match
        let bgImage = getImageFromPath(fileImagePath: appArguments.watermarkImage.value)
        if bgImage.size.width > appvars.windowWidth && bgImage.size.height > appvars.windowHeight && !appArguments.windowHeight.present && !appArguments.watermarkFill.present {
            // keep the same width ratio but change the height
            var wWidth = appvars.windowWidth
            if appArguments.windowWidth.present {
                wWidth = string2float(string: appArguments.windowWidth.value)
            }
            let widthRatio = wWidth / bgImage.size.width  // get the ration of the image height to the current display width
            let newHeight = (bgImage.size.height * widthRatio) - 28 //28 needs to be removed to account for the phantom title bar height
            appvars.windowHeight = floor(newHeight) // floor() will strip any fractional values as a result of the above multiplication
                                                    // we need to do this as window heights can't be fractional and weird things happen
                        
            if !appArguments.watermarkFill.present {
                appArguments.watermarkFill.present = true
                appArguments.watermarkFill.value = "fill"
            }
        }
    }
    
    appArguments.helpOption.present            = CLOptionPresent(OptionName: appArguments.helpOption)
    appArguments.helpOption.value              = CLOptionText(OptionName: appArguments.helpOption)

    // anthing that is an option only with no value
    appArguments.button2Option.present         = json[appArguments.button2Option.long].boolValue || CLOptionPresent(OptionName: appArguments.button2Option)
    appArguments.infoButtonOption.present      = json[appArguments.infoButtonOption.long].boolValue || CLOptionPresent(OptionName: appArguments.infoButtonOption)
    appArguments.hideIcon.present              = json[appArguments.hideIcon.long].boolValue || CLOptionPresent(OptionName: appArguments.hideIcon)
    appArguments.centreIcon.present            = json[appArguments.centreIcon.long].boolValue || json[appArguments.centreIconSE.long].boolValue || CLOptionPresent(OptionName: appArguments.centreIcon) || CLOptionPresent(OptionName: appArguments.centreIconSE)
    appArguments.warningIcon.present           = json[appArguments.warningIcon.long].boolValue || CLOptionPresent(OptionName: appArguments.warningIcon)
    appArguments.infoIcon.present              = json[appArguments.infoIcon.long].boolValue || CLOptionPresent(OptionName: appArguments.infoIcon)
    appArguments.cautionIcon.present           = json[appArguments.cautionIcon.long].boolValue || CLOptionPresent(OptionName: appArguments.cautionIcon)
    appArguments.movableWindow.present            = json[appArguments.movableWindow.long].boolValue || CLOptionPresent(OptionName: appArguments.movableWindow)
    appArguments.forceOnTop.present            = json[appArguments.forceOnTop.long].boolValue || CLOptionPresent(OptionName: appArguments.forceOnTop)
    appArguments.smallWindow.present           = json[appArguments.smallWindow.long].boolValue || CLOptionPresent(OptionName: appArguments.smallWindow)
    appArguments.bigWindow.present             = json[appArguments.bigWindow.long].boolValue || CLOptionPresent(OptionName: appArguments.bigWindow)
    appArguments.fullScreenWindow.present      = json[appArguments.fullScreenWindow.long].boolValue || CLOptionPresent(OptionName: appArguments.fullScreenWindow)
    appArguments.jsonOutPut.present            = json[appArguments.jsonOutPut.long].boolValue || CLOptionPresent(OptionName: appArguments.jsonOutPut)
    appArguments.ignoreDND.present             = json[appArguments.ignoreDND.long].boolValue || CLOptionPresent(OptionName: appArguments.ignoreDND)
    appArguments.hideTimerBar.present          = json[appArguments.hideTimerBar.long].boolValue || CLOptionPresent(OptionName: appArguments.hideTimerBar)
    appArguments.quitOnInfo.present            = json[appArguments.quitOnInfo.long].boolValue || CLOptionPresent(OptionName: appArguments.quitOnInfo)
    appArguments.blurScreen.present            = json[appArguments.blurScreen.long].boolValue || CLOptionPresent(OptionName: appArguments.blurScreen)
    appArguments.constructionKit.present       = json[appArguments.constructionKit.long].boolValue || CLOptionPresent(OptionName: appArguments.constructionKit)
    appArguments.miniMode.present              = json[appArguments.miniMode.long].boolValue || CLOptionPresent(OptionName: appArguments.miniMode)
    appArguments.notification.present          = json[appArguments.notification.long].boolValue || CLOptionPresent(OptionName: appArguments.notification)
    
    // command line only options
    appArguments.listFonts.present             = CLOptionPresent(OptionName: appArguments.listFonts)
    appArguments.demoOption.present            = CLOptionPresent(OptionName: appArguments.demoOption)
    appArguments.buyCoffee.present             = CLOptionPresent(OptionName: appArguments.buyCoffee)
    appArguments.licence.present           = CLOptionPresent(OptionName: appArguments.licence)
    appArguments.jamfHelperMode.present        = CLOptionPresent(OptionName: appArguments.jamfHelperMode)
    appArguments.debug.present                 = CLOptionPresent(OptionName: appArguments.debug)
    appArguments.getVersion.present            = CLOptionPresent(OptionName: appArguments.getVersion)

}
