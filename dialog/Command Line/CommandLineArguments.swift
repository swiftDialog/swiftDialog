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
    var helpShort: String = ""
    var helpLong: String = ""
    var helpUsage: String = "<text>"
    var present: Bool = false
    var isbool: Bool = false

    public mutating func evaluate(json: JSON = "{}", defaultValue: Any = "") {
        self.present = json[self.long].exists() || CLOptionPresent(optionName: self)
        if !self.isbool && json[self.long].bool ?? false {
            self.present = false
        }

        if self.present {
            if let numberValue = json[self.long].number {
                self.value = numberValue.stringValue
            } else {
                self.value = json[self.long].string ?? CLOptionText(optionName: self)
            }
        }
        if self.value.isEmpty {
            if let floatValue = defaultValue as? CGFloat {
                self.value = floatValue.stringValue
            } else if let stringValue = defaultValue as? String {
                self.value = stringValue
            } else {
                self.value = defaultValue as? String ?? ""
            }
        }
    }
}


struct CommandLineArguments {
    // command line options that take string parameters
    var titleOption              = CommandlineArgument(long: "title", short: "t")
    var subTitleOption           = CommandlineArgument(long: "subtitle")
    var messageOption            = CommandlineArgument(long: "message", short: "m")
    var dialogStyle              = CommandlineArgument(long: "style")
    var messageAlignment         = CommandlineArgument(long: "messagealignment")
    var helpAlignment            = CommandlineArgument(long: "helpalignment")
    var messageAlignmentOld      = CommandlineArgument(long: "alignment")
    var messageVerticalAlignment = CommandlineArgument(long: "messageposition")
    var helpMessage              = CommandlineArgument(long: "helpmessage")
    var iconOption               = CommandlineArgument(long: "icon", short: "i")
    var iconSize                 = CommandlineArgument(long: "iconsize")
    var iconAlpha                = CommandlineArgument(long: "iconalpha")
    var iconAccessabilityLabel   = CommandlineArgument(long: "iconalttext")
    var overlayIconOption        = CommandlineArgument(long: "overlayicon", short: "y")
    var bannerImage              = CommandlineArgument(long: "bannerimage", short: "n")
    var bannerTitle              = CommandlineArgument(long: "bannertitle")
    var bannerText               = CommandlineArgument(long: "bannertext")
    var bannerHeight             = CommandlineArgument(long: "bannerheight")
    var button1TextOption        = CommandlineArgument(long: "button1text")
    var button1ActionOption      = CommandlineArgument(long: "button1action")
    var button1ShellActionOption = CommandlineArgument(long: "button1shellaction",short: "")
    var button2TextOption        = CommandlineArgument(long: "button2text")
    var button2ActionOption      = CommandlineArgument(long: "button2action")
    var buttonInfoTextOption     = CommandlineArgument(long: "infobuttontext")
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
    var timerBar                 = CommandlineArgument(long: "timer")
    var progressBar              = CommandlineArgument(long: "progress")
    var progressText             = CommandlineArgument(long: "progresstext")
    var mainImage                = CommandlineArgument(long: "image", short: "g")
    var mainImageCaption         = CommandlineArgument(long: "imagecaption")
    var windowWidth              = CommandlineArgument(long: "width")
    var windowHeight             = CommandlineArgument(long: "height")
    var watermarkImage           = CommandlineArgument(long: "background", short: "bg")
    var watermarkAlpha           = CommandlineArgument(long: "bgalpha", short: "ba")
    var watermarkPosition        = CommandlineArgument(long: "bgposition", short: "bp")
    var watermarkFill            = CommandlineArgument(long: "bgfill", short: "bf")
    var watermarkScale           = CommandlineArgument(long: "bgscale", short: "bs")
    var position                 = CommandlineArgument(long: "position")
    var positionOffset           = CommandlineArgument(long: "positionoffset")
    var video                    = CommandlineArgument(long: "video")
    var videoCaption             = CommandlineArgument(long: "videocaption")
    var debug                    = CommandlineArgument(long: "debug")
    var jsonFile                 = CommandlineArgument(long: "jsonfile")
    var jsonString               = CommandlineArgument(long: "jsonstring")
    var statusLogFile            = CommandlineArgument(long: "commandfile")
    var listItem                 = CommandlineArgument(long: "listitem")
    var listStyle                = CommandlineArgument(long: "liststyle")
    var infoText                 = CommandlineArgument(long: "infotext")
    var infoBox                  = CommandlineArgument(long: "infobox")
    var quitKey                  = CommandlineArgument(long: "quitkey")
    var webcontent               = CommandlineArgument(long: "webcontent")
    var authkey                  = CommandlineArgument(long: "key", short: "k")
    var hash                     = CommandlineArgument(long: "checksum")
    var logFileToTail            = CommandlineArgument(long: "displaylog")

    // command line options that take no additional parameters
    var button1Disabled          = CommandlineArgument(long: "button1disabled", isbool: true)
    var button2Disabled          = CommandlineArgument(long: "button2disabled", isbool: true)
    var button2Option            = CommandlineArgument(long: "button2", short: "2", isbool: true)
    var infoButtonOption         = CommandlineArgument(long: "infobutton", short: "3", isbool: true)
    var getVersion               = CommandlineArgument(long: "version", short: "v")
    var hideIcon                 = CommandlineArgument(long: "hideicon", short: "h")
    var centreIcon               = CommandlineArgument(long: "centreicon", isbool: true)
    var centreIconSE             = CommandlineArgument(long: "centericon", isbool: true) // the other way of spelling
    var helpOption               = CommandlineArgument(long: "help")
    var demoOption               = CommandlineArgument(long: "demo")
    var buyCoffee                = CommandlineArgument(long: "coffee", short: "☕️")
    var licence                  = CommandlineArgument(long: "licence", short: "l")
    var warningIcon              = CommandlineArgument(long: "warningicon") // Deprecated
    var infoIcon                 = CommandlineArgument(long: "infoicon") // Deprecated
    var cautionIcon              = CommandlineArgument(long: "cautionicon") // Deprecated
    var hideTimerBar             = CommandlineArgument(long: "hidetimerbar")
    var autoPlay                 = CommandlineArgument(long: "autoplay")
    var blurScreen               = CommandlineArgument(long: "blurscreen", isbool: true)
    var notification             = CommandlineArgument(long: "notification", isbool: true)

    var constructionKit          = CommandlineArgument(long: "builder", isbool: true)
    var movableWindow            = CommandlineArgument(long: "moveable", short: "o", isbool: true)
    var forceOnTop               = CommandlineArgument(long: "ontop", short: "p", isbool: true)
    var smallWindow              = CommandlineArgument(long: "small", short: "s", isbool: true)
    var bigWindow                = CommandlineArgument(long: "big", short: "b", isbool: true)
    var fullScreenWindow         = CommandlineArgument(long: "fullscreen", short: "f", isbool: true)
    var quitOnInfo               = CommandlineArgument(long: "quitoninfo", isbool: true)
    var listFonts                = CommandlineArgument(long: "listfonts")
    var jsonOutPut               = CommandlineArgument(long: "json", short: "j", isbool: true)
    var ignoreDND                = CommandlineArgument(long: "ignorednd", short: "d", isbool: true)
    var jamfHelperMode           = CommandlineArgument(long: "jh", short: "jh", isbool: true)
    var miniMode                 = CommandlineArgument(long: "mini", isbool: true)
    var eulaMode                 = CommandlineArgument(long: "eula", isbool: true)
    var windowButtonsEnabled     = CommandlineArgument(long: "windowbuttons")
    var windowResizable          = CommandlineArgument(long: "resizable", isbool: true)
    var hideDefaultKeyboardAction = CommandlineArgument(long: "hidedefaultkeyboardaction", isbool: true)
}
