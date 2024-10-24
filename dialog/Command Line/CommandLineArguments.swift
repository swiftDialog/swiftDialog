//
//  CommandLineArguments.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import SwiftyJSON

struct CommandlineArgument {
    var long: String
    var short: String = ""
    var value: String = ""
    var defaultValue: Any = ""
    var helpShort: String = ""
    var helpLong: String = ""
    var helpUsage: String = "<text>"
    var present: Bool = false
    var isbool: Bool = false
}

struct CommandLineArguments {
    // command line options that take string parameters
    var titleOption              = CommandlineArgument(long: "title", short: "t", defaultValue: appDefaults.titleDefault)
    var subTitleOption           = CommandlineArgument(long: "subtitle")
    var messageOption            = CommandlineArgument(long: "message", short: "m", defaultValue: appDefaults.messageDefault)
    var dialogStyle              = CommandlineArgument(long: "style")
    var messageAlignment         = CommandlineArgument(long: "messagealignment", defaultValue: appDefaults.messageAlignmentTextRepresentation)
    var helpAlignment            = CommandlineArgument(long: "helpalignment", defaultValue: appDefaults.messageAlignmentTextRepresentation)
    var messageAlignmentOld      = CommandlineArgument(long: "alignment", defaultValue: appDefaults.messageAlignmentTextRepresentation)
    var messageVerticalAlignment = CommandlineArgument(long: "messageposition")
    var helpMessage              = CommandlineArgument(long: "helpmessage")
    var iconOption               = CommandlineArgument(long: "icon", short: "i", defaultValue: "default")
    var iconSize                 = CommandlineArgument(long: "iconsize", defaultValue: appvars.iconWidth)
    var iconAlpha                = CommandlineArgument(long: "iconalpha", defaultValue: "1.0")
    var iconAccessabilityLabel   = CommandlineArgument(long: "iconalttext", defaultValue: "Dialog Icon")
    var overlayIconOption        = CommandlineArgument(long: "overlayicon", short: "y")
    var bannerImage              = CommandlineArgument(long: "bannerimage", short: "n")
    var bannerTitle              = CommandlineArgument(long: "bannertitle", defaultValue: appDefaults.titleDefault)
    var bannerText               = CommandlineArgument(long: "bannertext", defaultValue: appDefaults.titleDefault)
    var bannerHeight             = CommandlineArgument(long: "bannerheight")
    var button1TextOption        = CommandlineArgument(long: "button1text", defaultValue: appDefaults.button1Default)
    var button1ActionOption      = CommandlineArgument(long: "button1action")
    var button1ShellActionOption = CommandlineArgument(long: "button1shellaction",short: "")
    var button2TextOption        = CommandlineArgument(long: "button2text", defaultValue: appDefaults.button2Default)
    var button2ActionOption      = CommandlineArgument(long: "button2action")
    var buttonInfoTextOption     = CommandlineArgument(long: "infobuttontext", defaultValue: appDefaults.buttonInfoDefault)
    var buttonInfoActionOption   = CommandlineArgument(long: "infobuttonaction")
    var buttonStyle              = CommandlineArgument(long: "buttonstyle")
    var dropdownTitle            = CommandlineArgument(long: "selecttitle")
    var dropdownValues           = CommandlineArgument(long: "selectvalues")
    var dropdownDefault          = CommandlineArgument(long: "selectdefault")
    var dropdownStyle            = CommandlineArgument(long: "selectstyle")
    var titleFont                = CommandlineArgument(long: "titlefont")
    var messageFont              = CommandlineArgument(long: "messagefont")
    var textField                = CommandlineArgument(long: "textfield")
    var textFieldLiveValidation  = CommandlineArgument(long: "textfieldlivevalidation", isbool: true)
    var checkbox                 = CommandlineArgument(long: "checkbox")
    var checkboxStyle            = CommandlineArgument(long: "checkboxstyle")
    var timerBar                 = CommandlineArgument(long: "timer", defaultValue: appDefaults.timerDefaultSeconds.stringValue)
    var progressBar              = CommandlineArgument(long: "progress")
    var progressText             = CommandlineArgument(long: "progresstext", defaultValue: " ")
    var mainImage                = CommandlineArgument(long: "image", short: "g")
    var mainImageCaption         = CommandlineArgument(long: "imagecaption")
    var windowWidth              = CommandlineArgument(long: "width", defaultValue: appvars.windowWidth)
    var windowHeight             = CommandlineArgument(long: "height", defaultValue: appvars.windowHeight)
    var watermarkImage           = CommandlineArgument(long: "background", short: "bg")
    var watermarkAlpha           = CommandlineArgument(long: "bgalpha", short: "ba")
    var watermarkPosition        = CommandlineArgument(long: "bgposition", short: "bp")
    var watermarkFill            = CommandlineArgument(long: "bgfill", short: "bf")
    var watermarkScale           = CommandlineArgument(long: "bgscale", short: "bs")
    var position                 = CommandlineArgument(long: "position")
    var positionOffset           = CommandlineArgument(long: "positionoffset", defaultValue: "\(appvars.windowPositionOffset)")
    var video                    = CommandlineArgument(long: "video")
    var videoCaption             = CommandlineArgument(long: "videocaption")
    var debug                    = CommandlineArgument(long: "debug")
    var jsonFile                 = CommandlineArgument(long: "jsonfile")
    var jsonString               = CommandlineArgument(long: "jsonstring")
    var statusLogFile            = CommandlineArgument(long: "commandfile")
    var listItem                 = CommandlineArgument(long: "listitem")
    var listStyle                = CommandlineArgument(long: "liststyle")
    var infoText                 = CommandlineArgument(long: "infotext", defaultValue: "swiftDialog \(getVersionString())")
    var infoBox                  = CommandlineArgument(long: "infobox")
    var quitKey                  = CommandlineArgument(long: "quitkey", defaultValue: appvars.quitKeyCharacter)
    var webcontent               = CommandlineArgument(long: "webcontent")
    var authkey                  = CommandlineArgument(long: "key", short: "k")
    var hash                     = CommandlineArgument(long: "checksum")
    var logFileToTail            = CommandlineArgument(long: "displaylog")
    var preferredViewOrder       = CommandlineArgument(long: "vieworder")
    var preferredAppearance      = CommandlineArgument(long: "appearance")

    // command line options that take no additional parameters
    var button1Disabled          = CommandlineArgument(long: "button1disabled", isbool: true)
    var button2Disabled          = CommandlineArgument(long: "button2disabled", isbool: true)
    var button2Option            = CommandlineArgument(long: "button2", short: "2", isbool: true)
    var infoButtonOption         = CommandlineArgument(long: "infobutton", short: "3", isbool: true)
    var getVersion               = CommandlineArgument(long: "version", short: "v", isbool: true)
    var hideIcon                 = CommandlineArgument(long: "hideicon", short: "h", isbool: true)
    var centreIcon               = CommandlineArgument(long: "centreicon", isbool: true)
    var centreIconSE             = CommandlineArgument(long: "centericon", isbool: true) // the other way of spelling
    var helpOption               = CommandlineArgument(long: "help", isbool: true)
    var demoOption               = CommandlineArgument(long: "demo", isbool: true)
    var buyCoffee                = CommandlineArgument(long: "coffee", short: "☕️", isbool: true)
    var licence                  = CommandlineArgument(long: "licence", short: "l", isbool: true)
    var warningIcon              = CommandlineArgument(long: "warningicon", isbool: true) // Deprecated
    var infoIcon                 = CommandlineArgument(long: "infoicon", isbool: true) // Deprecated
    var cautionIcon              = CommandlineArgument(long: "cautionicon", isbool: true) // Deprecated
    var hideTimerBar             = CommandlineArgument(long: "hidetimerbar", isbool: true)
    var hideTimer                = CommandlineArgument(long: "hidetimer", isbool: true)
    var autoPlay                 = CommandlineArgument(long: "autoplay", isbool: true)
    var blurScreen               = CommandlineArgument(long: "blurscreen", isbool: true)
    var notification             = CommandlineArgument(long: "notification", isbool: true)
    var verboseLogging           = CommandlineArgument(long: "verbose", short: "vvv", isbool: true)

    var constructionKit          = CommandlineArgument(long: "builder", isbool: true)
    var movableWindow            = CommandlineArgument(long: "moveable", short: "o", isbool: true)
    var forceOnTop               = CommandlineArgument(long: "ontop", short: "p", isbool: true)
    var smallWindow              = CommandlineArgument(long: "small", short: "s", isbool: true)
    var bigWindow                = CommandlineArgument(long: "big", short: "b", isbool: true)
    var fullScreenWindow         = CommandlineArgument(long: "fullscreen", short: "f", isbool: true)
    var quitOnInfo               = CommandlineArgument(long: "quitoninfo", isbool: true)
    var listFonts                = CommandlineArgument(long: "listfonts", isbool: true)
    var jsonOutPut               = CommandlineArgument(long: "json", short: "j", isbool: true)
    var ignoreDND                = CommandlineArgument(long: "ignorednd", short: "d", isbool: true)
    var jamfHelperMode           = CommandlineArgument(long: "jh", short: "jh", isbool: true)
    var miniMode                 = CommandlineArgument(long: "mini", isbool: true)
    var eulaMode                 = CommandlineArgument(long: "eula", isbool: true)
    var presentationMode         = CommandlineArgument(long: "presentation", isbool: true)
    var windowButtonsEnabled     = CommandlineArgument(long: "windowbuttons", isbool: true)
    var windowResizable          = CommandlineArgument(long: "resizable", isbool: true)
    var showOnAllScreens         = CommandlineArgument(long: "showonallscreens", isbool: true)
    var notificationGoPing       = CommandlineArgument(long: "enablenotificationsounds", isbool: true)
    var loginWindow              = CommandlineArgument(long: "loginwindow", isbool: true)
    var hideDefaultKeyboardAction = CommandlineArgument(long: "hidedefaultkeyboardaction", isbool: true)
    var alwaysReturnUserInput      = CommandlineArgument(long: "alwaysreturninput", isbool: true)
}

extension CommandlineArgument {
    public mutating func evaluate(json: JSON = "{}") {
        // This function self updates the parameters of the argument based on
        // what is passed in from json or from the command line
        // It tries to process json first, and then process command line

        // Simple test - if the value exists then we are present
        let isJson = json[self.long].exists() || json[self.short].exists()
        let isComandLine = CLOptionPresent(optionName: self)

        self.present = isJson || isComandLine

        // we need to check if the value is set in json but set to false
        // case we need to set the "present" state to false
        if isJson {
            if !self.isbool && json[self.long].bool ?? false {
                self.present = false
                return
            } else if let boolValue = json[self.long].bool {
                self.present = boolValue
                return
            }
        }

        // json numbers can be input as an int or string. we need to check for both
        // command line arguments always some in as strings
        if self.present {
            if let numberValue = json[self.long].number {
                self.value = numberValue.stringValue
            } else {
                self.value = json[self.long].string ?? CLOptionText(optionName: self)
            }
        }

        // nothing was collected so set the default value as a string
        if self.value.isEmpty {
            if let floatValue = self.defaultValue as? CGFloat {
                self.value = floatValue.stringValue
            } else if let stringValue = self.defaultValue as? String {
                self.value = stringValue
            } else {
                self.value = self.defaultValue as? String ?? ""
            }
        } else {
            // we have a value - perform string processing on it
            self.value = processTextString(self.value, tags: appvars.systemInfo)
        }
    }
}


extension CommandLineArguments {
    public mutating func updateAllItems(with jsonData: JSON = "{}") {
        let mirror = Mirror(reflecting: self)

        for child in mirror.children {
            if var argument = child.value as? CommandlineArgument {
                argument.evaluate(json: jsonData)

                // Update the property with the modified ItemProperty
                if let label = child.label {
                    switch label {
                    case "titleOption": self.titleOption = argument
                    case "subTitleOption": self.subTitleOption = argument
                    case "messageOption": self.messageOption = argument
                    case "dialogStyle": self.dialogStyle = argument
                    case "messageAlignment": self.messageAlignment = argument
                    case "helpAlignment": self.helpAlignment = argument
                    case "messageAlignmentOld": self.messageAlignmentOld = argument
                    case "messageVerticalAlignment": self.messageVerticalAlignment = argument
                    case "helpMessage": self.helpMessage = argument
                    case "iconOption": self.iconOption = argument
                    case "iconSize": self.iconSize = argument
                    case "iconAlpha": self.iconAlpha = argument
                    case "iconAccessabilityLabel": self.iconAccessabilityLabel = argument
                    case "overlayIconOption": self.overlayIconOption = argument
                    case "bannerImage": self.bannerImage = argument
                    case "bannerTitle": self.bannerTitle = argument
                    case "bannerText": self.bannerText = argument
                    case "bannerHeight": self.bannerHeight = argument
                    case "button1TextOption": self.button1TextOption = argument
                    case "button1ActionOption": self.button1ActionOption = argument
                    case "button1ShellActionOption": self.button1ShellActionOption = argument
                    case "button2TextOption": self.button2TextOption = argument
                    case "button2ActionOption": self.button2ActionOption = argument
                    case "buttonInfoTextOption": self.buttonInfoTextOption = argument
                    case "buttonInfoActionOption": self.buttonInfoActionOption = argument
                    case "buttonStyle": self.buttonStyle = argument
                    case "dropdownTitle": self.dropdownTitle = argument
                    case "dropdownValues": self.dropdownValues = argument
                    case "dropdownDefault": self.dropdownDefault = argument
                    case "dropdownStyle": self.dropdownStyle = argument
                    case "titleFont": self.titleFont = argument
                    case "messageFont": self.messageFont = argument
                    case "textField": self.textField = argument
                    case "textFieldLiveValidation": self.textFieldLiveValidation = argument
                    case "checkbox": self.checkbox = argument
                    case "checkboxStyle": self.checkboxStyle = argument
                    case "timerBar": self.timerBar = argument
                    case "progressBar": self.progressBar = argument
                    case "progressText": self.progressText = argument
                    case "mainImage": self.mainImage = argument
                    case "mainImageCaption": self.mainImageCaption = argument
                    case "windowWidth": self.windowWidth = argument
                    case "windowHeight": self.windowHeight = argument
                    case "watermarkImage": self.watermarkImage = argument
                    case "watermarkAlpha": self.watermarkAlpha = argument
                    case "watermarkPosition": self.watermarkPosition = argument
                    case "watermarkFill": self.watermarkFill = argument
                    case "watermarkScale": self.watermarkScale = argument
                    case "position": self.position = argument
                    case "positionOffset": self.positionOffset = argument
                    case "video": self.video = argument
                    case "videoCaption": self.videoCaption = argument
                    case "debug": self.debug = argument
                    case "jsonFile": self.jsonFile = argument
                    case "jsonString": self.jsonString = argument
                    case "statusLogFile": self.statusLogFile = argument
                    case "listItem": self.listItem = argument
                    case "listStyle": self.listStyle = argument
                    case "infoText": self.infoText = argument
                    case "infoBox": self.infoBox = argument
                    case "quitKey": self.quitKey = argument
                    case "webcontent": self.webcontent = argument
                    case "authkey": self.authkey = argument
                    case "hash": self.hash = argument
                    case "logFileToTail": self.logFileToTail = argument
                    case "preferredViewOrder": self.preferredViewOrder = argument
                    case "preferredAppearance": self.preferredAppearance = argument
                    case "button1Disabled": self.button1Disabled = argument
                    case "button2Disabled": self.button2Disabled = argument
                    case "button2Option": self.button2Option = argument
                    case "infoButtonOption": self.infoButtonOption = argument
                    case "getVersion": self.getVersion = argument
                    case "hideIcon": self.hideIcon = argument
                    case "centreIcon": self.centreIcon = argument
                    case "centreIconSE": self.centreIconSE = argument
                    case "helpOption": self.helpOption = argument
                    case "demoOption": self.demoOption = argument
                    case "buyCoffee": self.buyCoffee = argument
                    case "licence": self.licence = argument
                    case "warningIcon": self.warningIcon = argument
                    case "infoIcon": self.infoIcon = argument
                    case "cautionIcon": self.cautionIcon = argument
                    case "hideTimerBar": self.hideTimerBar = argument
                    case "hideTimer": self.hideTimer = argument
                    case "autoPlay": self.autoPlay = argument
                    case "blurScreen": self.blurScreen = argument
                    case "notification": self.notification = argument
                    case "verboseLogging": self.verboseLogging = argument
                    case "constructionKit": self.constructionKit = argument
                    case "movableWindow": self.movableWindow = argument
                    case "forceOnTop": self.forceOnTop = argument
                    case "smallWindow": self.smallWindow = argument
                    case "bigWindow": self.bigWindow = argument
                    case "fullScreenWindow": self.fullScreenWindow = argument
                    case "quitOnInfo": self.quitOnInfo = argument
                    case "listFonts": self.listFonts = argument
                    case "jsonOutPut": self.jsonOutPut = argument
                    case "ignoreDND": self.ignoreDND = argument
                    case "jamfHelperMode": self.jamfHelperMode = argument
                    case "miniMode": self.miniMode = argument
                    case "eulaMode": self.eulaMode = argument
                    case "presentationMode": self.presentationMode = argument
                    case "windowButtonsEnabled": self.windowButtonsEnabled = argument
                    case "windowResizable": self.windowResizable = argument
                    case "showOnAllScreens": self.showOnAllScreens = argument
                    case "notificationGoPing": self.notificationGoPing = argument
                    case "loginWindow": self.loginWindow = argument
                    case "hideDefaultKeyboardAction": self.hideDefaultKeyboardAction = argument
                    case "alwaysReturnUserInput": self.alwaysReturnUserInput = argument
                    default: break
                    }
                }
            }
        }
    }
}
