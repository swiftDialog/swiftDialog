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
    var overrideDefaultIfNill = false
    var hidden: Bool = false
}

struct CommandLineArguments {
    // command line options that take string parameters
    var titleOption              = CommandlineArgument(long: "title", short: "t", defaultValue: appDefaults.titleDefault, overrideDefaultIfNill: true)
    var subTitleOption           = CommandlineArgument(long: "subtitle")
    var messageOption            = CommandlineArgument(long: "message", short: "m", defaultValue: appDefaults.messageDefault, overrideDefaultIfNill: true)
    var dialogStyle              = CommandlineArgument(long: "style")
    var messageAlignment         = CommandlineArgument(long: "messagealignment", defaultValue: appDefaults.messageAlignmentTextRepresentation)
    var helpAlignment            = CommandlineArgument(long: "helpalignment", defaultValue: appDefaults.messageAlignmentTextRepresentation)
    var messageAlignmentOld      = CommandlineArgument(long: "alignment", defaultValue: appDefaults.messageAlignmentTextRepresentation)
    var messageVerticalAlignment = CommandlineArgument(long: "messageposition")
    var helpMessage              = CommandlineArgument(long: "helpmessage")
    var helpImage                = CommandlineArgument(long: "helpimage")
    var helpSheetButton          = CommandlineArgument(long: "helpsheetbuttontext", defaultValue: "OK".localized)
    var iconOption               = CommandlineArgument(long: "icon", short: "i", defaultValue: "default", overrideDefaultIfNill: true)
    var iconSize                 = CommandlineArgument(long: "iconsize", defaultValue: appvars.iconWidth)
    var iconAlpha                = CommandlineArgument(long: "iconalpha", defaultValue: "1.0")
    var iconAccessabilityLabel   = CommandlineArgument(long: "iconalttext", defaultValue: "Dialog Icon")
    var overlayIconOption        = CommandlineArgument(long: "overlayicon", short: "y")
    var bannerImage              = CommandlineArgument(long: "bannerimage", short: "n")
    var bannerTitle              = CommandlineArgument(long: "bannertitle", defaultValue: appDefaults.titleDefault)
    var bannerText               = CommandlineArgument(long: "bannertext", defaultValue: appDefaults.titleDefault)
    var bannerHeight             = CommandlineArgument(long: "bannerheight")
    var button1TextOption        = CommandlineArgument(long: "button1text", defaultValue: appDefaults.button1Default, overrideDefaultIfNill: true)
    var button1ActionOption      = CommandlineArgument(long: "button1action")
    var button1ShellActionOption = CommandlineArgument(long: "button1shellaction",short: "", hidden: true)
    var button1Symbol            = CommandlineArgument(long: "button1symbol")
    var button2TextOption        = CommandlineArgument(long: "button2text", defaultValue: appDefaults.button2Default)
    var button2ActionOption      = CommandlineArgument(long: "button2action")
    var button2Symbol            = CommandlineArgument(long: "button2symbol")
    var buttonInfoTextOption     = CommandlineArgument(long: "infobuttontext", defaultValue: appDefaults.buttonInfoDefault)
    var buttonInfoActionOption   = CommandlineArgument(long: "infobuttonaction")
    var buttonInfoSymbol         = CommandlineArgument(long: "infobuttonsymbol")
    var cardsNextButtonText      = CommandlineArgument(long: "nextbuttontext", defaultValue: "Next".localized)
    var cardsPreviousButtonText  = CommandlineArgument(long: "previousbuttontext", defaultValue: "Previous".localized)
    var buttonStyle              = CommandlineArgument(long: "buttonstyle")
    var buttonSize               = CommandlineArgument(long: "buttonsize", defaultValue: "regular")
    var buttonTextSize           = CommandlineArgument(long: "buttontextsize")
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
    var timerBar                 = CommandlineArgument(long: "timer", defaultValue: appDefaults.timerDefaultSeconds)
    var progressBar              = CommandlineArgument(long: "progress")
    var progressText             = CommandlineArgument(long: "progresstext", defaultValue: " ")
    var progressTextAlignment    = CommandlineArgument(long: "progresstextalignment", defaultValue: " ")
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
    var listSelectionEnabled     = CommandlineArgument(long: "enablelistselect", isbool: true)
    var infoText                 = CommandlineArgument(long: "infotext", defaultValue: "swiftDialog \(getVersionString())")
    var infoBox                  = CommandlineArgument(long: "infobox")
    var infoBoxWidth             = CommandlineArgument(long: "infoboxwidth")
    var quitKey                  = CommandlineArgument(long: "quitkey", defaultValue: appvars.quitKeyCharacter)
    var webcontent               = CommandlineArgument(long: "webcontent")
    var authkey                  = CommandlineArgument(long: "key", short: "k")
    var hash                     = CommandlineArgument(long: "checksum")
    var logFileToTail            = CommandlineArgument(long: "displaylog")
    var logFileHistory           = CommandlineArgument(long: "loghistory", defaultValue: appvars.logFileHistory)
    var preferredViewOrder       = CommandlineArgument(long: "vieworder")
    var preferredAppearance      = CommandlineArgument(long: "appearance")
    var setAppIcon               = CommandlineArgument(long: "seticon")
    var notificationIdentifier   = CommandlineArgument(long: "identifier", short: "id")
    var callingPid               = CommandlineArgument(long: "pid", defaultValue: 0, hidden: true)
    var playSound                = CommandlineArgument(long: "sound")
    var dockIcon                 = CommandlineArgument(long: "dockicon")
    var dockBadge                = CommandlineArgument(long: "dockiconbadge")
    var onAdvance                = CommandlineArgument(long: "onadvance")
    var screenBackground         = CommandlineArgument(long: "screenbackground")

    // command line options that take no additional parameters
    var button1Disabled          = CommandlineArgument(long: "button1disabled", isbool: true)
    var button2Disabled          = CommandlineArgument(long: "button2disabled", isbool: true)
    var button2Option            = CommandlineArgument(long: "button2", short: "2", isbool: true)
    var infoButtonOption         = CommandlineArgument(long: "infobutton", short: "3", isbool: true)
    var getVersion               = CommandlineArgument(long: "version", short: "v", isbool: true)
    var hideIcon                 = CommandlineArgument(long: "hideicon", short: "h", isbool: true)
    var centreIcon               = CommandlineArgument(long: "centreicon", isbool: true)
    var centreIconSE             = CommandlineArgument(long: "centericon", isbool: true, hidden: true) // the other way of spelling
    var helpOption               = CommandlineArgument(long: "help", isbool: true)
    var demoOption               = CommandlineArgument(long: "demo", isbool: true)
    var buyCoffee                = CommandlineArgument(long: "coffee", short: "☕️", isbool: true, hidden: true)
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
    var showDockIcon             = CommandlineArgument(long: "showdockicon", isbool: true)

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
    var removeNotification        = CommandlineArgument(long: "remove", isbool: true)
    var showSoundControls         = CommandlineArgument(long: "showsoundcontrols", isbool: true)
    var hideOtherApps            = CommandlineArgument(long: "hideotherapps", isbool: true)

    // Notification style
    var notificationStyle         = CommandlineArgument(long: "style", defaultValue: "")

    // Inspect Mode Arguments
    var inspectMode               = CommandlineArgument(long: "inspect-mode", isbool: true)
    var inspectConfig             = CommandlineArgument(long: "inspect-config")

    // IPC: directory where each running Dialog publishes a <pid>.json
    // session-discovery file. Pass an empty value or "none" to disable.
    var publishedSessionsDir      = CommandlineArgument(long: "published-sessions-dir",
                                                        defaultValue: "/private/tmp/swiftdialog/sessions")
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
                var stringValue = json[self.long].string ?? CLOptionText(optionName: self)
                if stringValue == "" && self.overrideDefaultIfNill {
                    stringValue = "none"
                }
                self.value = stringValue
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

    /// Single source of truth: a key-path to every `CommandlineArgument` property,
    /// in declaration order. `updateAllItems` and `resetToDefaults` both drive off
    /// this one list so a newly added argument can't be silently forgotten by one of
    /// them (as happened historically when the two hand-maintained switch statements
    /// drifted). `CommandLineArgumentsTests` asserts this covers every argument.
    static let allArgumentKeyPaths: [WritableKeyPath<CommandLineArguments, CommandlineArgument>] = [
        \.titleOption, \.subTitleOption, \.messageOption, \.dialogStyle, \.messageAlignment,
        \.helpAlignment, \.messageAlignmentOld, \.messageVerticalAlignment, \.helpMessage, \.helpImage,
        \.helpSheetButton, \.iconOption, \.iconSize, \.iconAlpha, \.iconAccessabilityLabel,
        \.overlayIconOption, \.bannerImage, \.bannerTitle, \.bannerText, \.bannerHeight,
        \.button1TextOption, \.button1ActionOption, \.button1ShellActionOption, \.button1Symbol, \.button2TextOption,
        \.button2ActionOption, \.button2Symbol, \.buttonInfoTextOption, \.buttonInfoActionOption, \.buttonInfoSymbol,
        \.cardsNextButtonText, \.cardsPreviousButtonText, \.buttonStyle, \.buttonSize, \.buttonTextSize,
        \.dropdownTitle, \.dropdownValues, \.dropdownDefault, \.dropdownStyle, \.titleFont,
        \.messageFont, \.textField, \.textFieldLiveValidation, \.checkbox, \.checkboxStyle,
        \.timerBar, \.progressBar, \.progressText, \.progressTextAlignment, \.mainImage,
        \.mainImageCaption, \.windowWidth, \.windowHeight, \.watermarkImage, \.watermarkAlpha,
        \.watermarkPosition, \.watermarkFill, \.watermarkScale, \.position, \.positionOffset,
        \.video, \.videoCaption, \.debug, \.jsonFile, \.jsonString,
        \.statusLogFile, \.listItem, \.listStyle, \.listSelectionEnabled, \.infoText,
        \.infoBox, \.infoBoxWidth, \.quitKey, \.webcontent, \.authkey,
        \.hash, \.logFileToTail, \.logFileHistory, \.preferredViewOrder, \.preferredAppearance,
        \.setAppIcon, \.notificationIdentifier, \.callingPid, \.playSound, \.dockIcon,
        \.dockBadge, \.onAdvance, \.screenBackground, \.button1Disabled, \.button2Disabled,
        \.button2Option, \.infoButtonOption, \.getVersion, \.hideIcon, \.centreIcon,
        \.centreIconSE, \.helpOption, \.demoOption, \.buyCoffee, \.licence,
        \.warningIcon, \.infoIcon, \.cautionIcon, \.hideTimerBar, \.hideTimer,
        \.autoPlay, \.blurScreen, \.notification, \.verboseLogging, \.showDockIcon,
        \.constructionKit, \.movableWindow, \.forceOnTop, \.smallWindow, \.bigWindow,
        \.fullScreenWindow, \.quitOnInfo, \.listFonts, \.jsonOutPut, \.ignoreDND,
        \.jamfHelperMode, \.miniMode, \.eulaMode, \.presentationMode, \.windowButtonsEnabled,
        \.windowResizable, \.showOnAllScreens, \.notificationGoPing, \.loginWindow, \.hideDefaultKeyboardAction,
        \.alwaysReturnUserInput, \.removeNotification, \.showSoundControls, \.hideOtherApps, \.notificationStyle,
        \.inspectMode, \.inspectConfig, \.publishedSessionsDir,
    ]

    /// Session/meta-level arguments that must persist across a `resetToDefaults`
    /// (which runs between cards in cards mode): the JSON/command-file inputs, auth,
    /// inspect mode, and the info-and-exit flags. These are exactly the arguments the
    /// original `resetToDefaults` switch omitted, preserved here explicitly.
    static let resetExclusions: Set<WritableKeyPath<CommandLineArguments, CommandlineArgument>> = [
        \.jsonFile, \.jsonString, \.statusLogFile, \.authkey, \.hash,
        \.getVersion, \.helpOption, \.demoOption, \.buyCoffee, \.licence,
        \.verboseLogging, \.constructionKit, \.jamfHelperMode, \.setAppIcon, \.notificationIdentifier,
        \.inspectMode, \.inspectConfig, \.publishedSessionsDir, \.callingPid,
    ]

    /// Evaluate every argument against the supplied JSON and the command line.
    public mutating func updateAllItems(with jsonData: JSON = "{}") {
        for keyPath in Self.allArgumentKeyPaths {
            self[keyPath: keyPath].evaluate(json: jsonData)
        }
    }

    /// Reset arguments to their default values (used between cards), except the
    /// session/meta-level arguments in `resetExclusions`, which must persist.
    public mutating func resetToDefaults() {
        let defaults = CommandLineArguments()
        for keyPath in Self.allArgumentKeyPaths where !Self.resetExclusions.contains(keyPath) {
            self[keyPath: keyPath] = defaults[keyPath: keyPath]
        }
    }
}
