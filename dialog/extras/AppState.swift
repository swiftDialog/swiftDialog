//
//  appVaribles.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation
import SwiftUI

var iconVisible: Bool = true

// Probably a way to work all this out as a nice dictionary. For now, long form.

// declare our app var in case we want to update values - e.g. future use, multiple dialog sizes
var appvars = AppVariables()
var appArguments = CommandLineArguments()
var userInputState = UserInputState()

let displayAsInt: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 0
    formatter.numberStyle = .decimal
    return formatter
}()

let displayAsDouble: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 1
    formatter.numberStyle = .decimal
    return formatter
}()

struct UserInputState {
    // These items can get quite large so we declare them here and not as part of the main ObservableObject
    // Doing so saves on performance as the states only need to be updated to the value entered in, not re-evaluated on every keystroke
    var dropdownItems = [DropDownItems]()
    var listItems = [ListItems]()
    var textFields = [TextFieldState]()
}

struct TextFieldState {
    var editor: Bool       = false
    var fileSelect: Bool   = false
    var fileType: String   = ""
    var passwordFill: Bool = false
    var prompt: String     = ""
    var regex: String      = ""
    var regexError: String = ""
    var required: Bool     = false
    var secure: Bool       = false
    var title: String
    var value: String      = ""
    var requiredTextfieldHighlight: Color = .clear
    var dictionary: [String: Any] {
            return ["title": title,
                    "required": required,
                    "secure": secure,
                    "prompt": prompt,
                    "regex": regex,
                    "regexerror": regexError,
                    "value": value
            ]
        }
    var nsDictionary: NSDictionary {
            return dictionary as NSDictionary
        }
}

struct DropDownItems {
    var title: String
    var values: [String]
    var defaultValue: String
    var selectedValue: String = ""
    var required: Bool   = false
    var style: String = "list"
    var requiredfieldHighlight: Color = .clear
}

struct CheckBoxes {
    var label: String
    var icon: String = ""
    var checked: Bool = false
    var disabled: Bool = false
}

struct ListItems: Codable {
    var title: String
    var icon: String = ""
    var statusText: String = ""
    var statusIcon: String = ""
    var progress: CGFloat = 0
    var dictionary: [String: Any] {
            return ["title": title,
                    "statustext": statusText,
                    "status": statusIcon,
                    "progress": progress]
        }
    var nsDictionary: NSDictionary {
            return dictionary as NSDictionary
        }
}

struct MainImage {
    var title: String = ""
    var path: String
    var caption: String = ""
    var dictionary: [String: Any] {
        return ["imagename": "\(path)",
                    "caption": caption]
        }
    var nsDictionary: NSDictionary {
            return dictionary as NSDictionary
        }
}

struct CommandlineArgument {
    var long: String
    var short: String = ""
    var value: String = ""
    var helpShort: String = ""
    var helpLong: String = ""
    var helpUsage: String = "<text>"
    var present: Bool = false
    var isbool: Bool = false
}


struct AppVariables {

    var cliversion                      = "2.3.0"

    // message default strings
    let titleDefault                    = String("default-title".localized)
    let messageDefault                  = String("default-message".localized)
    var messageAlignment: TextAlignment = .leading
    let messageAlignmentTextRepresentation = String("left")
    let allignmentStates: [String: TextAlignment] = ["left": .leading,
                                                      "right": .trailing,
                                                      "centre": .center,
                                                      "center": .center]
    var messagePosition: Alignment = .leading
    let positionStates: [String: Alignment] = ["left": .leading,
                                                      "right": .trailing,
                                                      "centre": .center,
                                                      "center": .center]

    // button default strings
    // work out how to define a default width button that does what you tell it to. in the meantime, diry hack with spaces
    let button1Default                  = String("button-ok".localized)
    let button2Default                  = String("button-cancel".localized)
    let buttonInfoDefault               = String("button-more-info".localized)
    let buttonInfoActionDefault         = String("")
    let button1DefaultAction            = KeyboardShortcut.defaultAction

    var helpButtonHoverText             = String("help-hover".localized)

    var windowIsMoveable                = Bool(false)
    var windowOnTop                     = Bool(false)
    var iconIsHidden                    = Bool(false)
    var iconIsCentred                   = Bool(false)

    // Window Sizes
    var windowWidth                     = CGFloat(820)      // set default dialog width
    var windowHeight                    = CGFloat(380)      // set default dialog height

    // Content padding
    let sidePadding                     = CGFloat(15)
    let topPadding                      = CGFloat(10)
    let bottomPadding                   = CGFloat(15)
    let contentPadding                  = CGFloat(8)

    // Screen Size
    var screenWidth                     = CGFloat(0)
    var screenHeight                    = CGFloat(0)

    var videoWindowWidth                = CGFloat(900)
    var videoWindowHeight               = CGFloat(600)

    var windowPositionVertical          = NSWindow.Position.Vertical.center
    var windowPositionHorozontal        = NSWindow.Position.Horizontal.center

    var iconWidth                      = CGFloat(150)      // set default image area width
    var iconHeight                     = CGFloat(260)      // set default image area height
    var titleHeight                     = CGFloat(50)
    var bannerHeight                    = CGFloat(-10)

    var smallWindow                     = Bool(false)
    var bigWindow                       = Bool(false)
    var scaleFactor                     = CGFloat(1)

    let timerDefaultSeconds             = CGFloat(10)

    let autoPlayDefaultSeconds          = CGFloat(10)

    var horozontalLineScale             = CGFloat(0.9)
    var dialogContentScale              = CGFloat(0.65)
    var titleFontSize                   = CGFloat(30)
    var titleFontColour                 = Color.primary
    var titleFontWeight                 = Font.Weight.bold
    var titleFontName                   = ""
    var titleFontShadow                 = Bool(false)
    var messageFontSize                 = CGFloat(20)
    var messageFontColour               = Color.primary
    var messageFontWeight               = Font.Weight.regular
    var messageFontName                 = ""
    var labelFontSize                   = CGFloat(16)

    var userInputRequired               = false

    var overlayIconScale                = CGFloat(0.40)
    var overlayOffsetX                  = CGFloat(40)
    var overlayOffsetY                  = CGFloat(50)
    var overlayShadow                   = CGFloat(3)

    var showHelpMessage                 = Bool(false)

    var willDisturb                     = Bool(false)

    var checkboxArray                   = [CheckBoxes]()
    var checkboxControlSize             = ControlSize.mini
    var checkboxControlStyle            = ""

    var imageArray                      = [MainImage]()
    var imageCaptionArray               = [String]()

    let defaultStatusLogFile            = String("/var/tmp/dialog.log")

    var quitKeyCharacter                = String("q")

    let argRegex                        = String("(,? ?[a-zA-Z1-9]+=|(,\\s?editor)|(,\\s?fileselect))|(,\\s?passwordfill)|(,\\s?required)|(,\\s?secure)")

    // exit codes and error messages
    let exit0                           = (code: Int32(0),   message: String("")) // normal exit
    let exitNow                         = (code: Int32(255), message: String("")) // forced exit
    let exit1                           = (code: Int32(1),   message: String("")) // pressed
    let exit2                           = (code: Int32(2),   message: String("")) // pressed button 2
    let exit3                           = (code: Int32(3),   message: String("")) // pressed button 3 (info button)
    let exit4                           = (code: Int32(4),   message: String(""))
    let exit5                           = (code: Int32(5),   message: String("")) // quit via command file
    let exit10                          = (code: Int32(10),  message: String("")) // quit via command + quitKey
    let exit20                          = (code: Int32(20),  message: String("Timeout Exceeded"))
    let exit201                         = (code: Int32(201), message: String("ERROR: Image resource cannot be found :"))
    let exit202                         = (code: Int32(202), message: String("ERROR: File not found :"))
    let exit203                         = (code: Int32(203), message: String("ERROR: Invalid Colour Value Specified. Use format #000000 :"))
    let exit204                         = (code: Int32(204), message: String(""))
    let exit205                         = (code: Int32(205), message: String(""))
    let exit206                         = (code: Int32(206), message: String(""))
    let exit207                         = (code: Int32(207), message: String(""))
    let exit208                         = (code: Int32(208), message: String(""))
    let exit209                         = (code: Int32(209), message: String(""))
    let exit210                         = (code: Int32(210), message: String(""))

    // debug flag
    var debugMode                       = Bool(false)
    var debugBorderColour               = Color.clear
}

struct CommandLineArguments {
    // command line options that take string parameters
    var titleOption              = CommandlineArgument(long: "title", short: "t")
    var subTitleOption           = CommandlineArgument(long: "subtitle")
    var messageOption            = CommandlineArgument(long: "message", short: "m")
    var dialogStyle              = CommandlineArgument(long: "style")
    var messageAlignment         = CommandlineArgument(long: "messagealignment")
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
    var miniMode                 = CommandlineArgument(long: "mini")
}
