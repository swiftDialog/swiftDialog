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

let formatter: NumberFormatter = {
    let formatter = NumberFormatter()
    //formatter.usesSignificantDigits = false
    formatter.maximumFractionDigits = 0
    formatter.numberStyle = .decimal
    return formatter
}()

struct TextFieldState {
    var editor          : Bool      = false
    var fileSelect      : Bool      = false
    var fileType        : String    = ""
    var passwordFill    : Bool      = false
    var prompt          : String    = ""
    var regex           : String    = ""
    var regexError      : String    = ""
    var required        : Bool      = false
    var secure          : Bool      = false
    //var selectLabel     : String    = ""
    var title           : String
    var value           : String    = ""
    var requiredTextfieldHighlight : Color = .clear
    var dictionary: [String: Any] {
            return ["title": title,
                    "required": required,
                    "secure": secure,
                    "prompt": prompt,
                    "regex":regex,
                    "regexerror":regexError,
                    "value":value
            ]
        }
    var nsDictionary: NSDictionary {
            return dictionary as NSDictionary
        }
}

struct DropDownItems {
    var title           : String
    var values          : [String]
    var defaultValue    : String
    var selectedValue   : String = ""
}

struct CheckBoxes {
    var title           : String
    var value           : Bool = false
    var disabled        : Bool = false
}

struct ListItems: Codable {
    var title           : String
    var icon            : String = ""
    var statusText      : String = ""
    var statusIcon      : String = ""
    var progress        : CGFloat = 0
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
    var title           : String = ""
    var path            : String
    var caption         : String = ""
    var dictionary: [String: Any] {
        return ["imagename": "\(path)",
                    "caption": caption]
        }
    var nsDictionary: NSDictionary {
            return dictionary as NSDictionary
        }
}

struct CLArgument {
    var long: String
    var short: String = ""
    var value : String = ""
    var help : String = ""
    var present : Bool = false
    var isbool : Bool = false
}


struct AppVariables {
    
    var cliversion                      = "2.1.0"
    
    // message default strings
    var titleDefault                    = String("default-title".localized)
    var messageDefault                  = String("default-message".localized)
    var messageAlignment : TextAlignment = .leading
    var messageAlignmentTextRepresentation = String("left")
    var allignmentStates : [String: TextAlignment] = ["left" : .leading,
                                                      "right" : .trailing,
                                                      "centre" : .center,
                                                      "center" : .center]

    // button default strings
    // work out how to define a default width button that does what you tell it to. in the meantime, diry hack with spaces
    var button1Default                  = String("button-ok".localized)
    var button2Default                  = String("button-cancel".localized)
    var buttonInfoDefault               = String("button-more-info".localized)
    var buttonInfoActionDefault         = String("")
    var button1DefaultAction            = KeyboardShortcut.defaultAction
    
    var helpButtonHoverText             = String("help-hover".localized)

    var windowIsMoveable                = Bool(false)
    var windowOnTop                     = Bool(false)
    var iconIsHidden                    = Bool(false)
    var iconIsCentred                   = Bool(false)

    // Window Sizes
    var windowWidth                     = CGFloat(820)      // set default dialog width
    var windowHeight                    = CGFloat(380)      // set default dialog height
    
    // Content padding
    var sidePadding                     = CGFloat(15)
    var topPadding                      = CGFloat(10)
    var bottomPadding                   = CGFloat(15)

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

    var timerDefaultSeconds             = CGFloat(10)

    var autoPlayDefaultSeconds          = CGFloat(10)

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
    var overlayIconScale                = CGFloat(0.40)
    var overlayOffsetX                  = CGFloat(40)
    var overlayOffsetY                  = CGFloat(50)
    var overlayShadow                   = CGFloat(3)
    
    var showHelpMessage                 = Bool(false)

    var jsonOut                         = Bool(false)

    var willDisturb                     = Bool(false)

    var checkboxOptionsArray            = [String]()
    var checkboxText                    = Array(repeating: "", count: 64)
    var checkboxValue                   = Array(repeating: false, count: 64)
    var checkboxDisabled                = Array(repeating: false, count: 64)

    var imageArray                      = [MainImage]()
    var imageCaptionArray               = [String]()

    var listItems = [ListItems]()
    var textFields = [TextFieldState]()
    var dropdownItems = [DropDownItems]()

    var annimationSmoothing             = Double(20)

    var defaultStatusLogFile            = String("/var/tmp/dialog.log")

    var quitKeyCharacter                = String("q")

    var argRegex                        = String("(,? ?[a-zA-Z1-9]+=|(,\\s?editor)|(,\\s?fileselect))|(,\\s?passwordfill)|(,\\s?required)|(,\\s?secure)")

    // exit codes and error messages
    var exit0                           = (code: Int32(0),   message: String("")) // normal exit
    var exitNow                         = (code: Int32(255), message: String("")) // forced exit
    var exit1                           = (code: Int32(1),   message: String("")) // pressed
    var exit2                           = (code: Int32(2),   message: String("")) // pressed button 2
    var exit3                           = (code: Int32(3),   message: String("")) // pressed button 3 (info button)
    var exit4                           = (code: Int32(4),   message: String(""))
    var exit5                           = (code: Int32(5),   message: String("")) // quit via command file
    var exit10                          = (code: Int32(10),  message: String("")) // quit via command + quitKey
    var exit20                          = (code: Int32(20),  message: String("Timeout Exceeded"))
    var exit201                         = (code: Int32(201), message: String("ERROR: Image resource cannot be found :"))
    var exit202                         = (code: Int32(202), message: String("ERROR: File not found :"))
    var exit203                         = (code: Int32(203), message: String("ERROR: Invalid Colour Value Specified. Use format #000000 :"))
    var exit204                         = (code: Int32(204), message: String(""))
    var exit205                         = (code: Int32(205), message: String(""))
    var exit206                         = (code: Int32(206), message: String(""))
    var exit207                         = (code: Int32(207), message: String(""))
    var exit208                         = (code: Int32(208), message: String(""))
    var exit209                         = (code: Int32(209), message: String(""))
    var exit210                         = (code: Int32(210), message: String(""))

    // debug flag
    var debugMode                       = Bool(false)
    var debugBorderColour               = Color.clear
}

struct CommandLineArguments {
    // command line options that take string parameters
    var titleOption              = CLArgument(long: "title", short: "t")
    var subTitleOption           = CLArgument(long: "subtitle")
    var messageOption            = CLArgument(long: "message", short: "m")
    var messageAlignment         = CLArgument(long: "messagealignment")
    var messageAlignmentOld      = CLArgument(long: "alignment")
    var messageVerticalAlignment = CLArgument(long: "messageposition")
    var helpMessage              = CLArgument(long: "helpmessage")
    var iconOption               = CLArgument(long: "icon", short: "i")
    var iconSize                 = CLArgument(long: "iconsize")
    var iconAccessabilityLabel   = CLArgument(long: "iconalttext")
  //var iconHeight               = CLArgument(long: "iconheight")
    var overlayIconOption        = CLArgument(long: "overlayicon", short: "y")
    var bannerImage              = CLArgument(long: "bannerimage", short: "n")
    var bannerTitle              = CLArgument(long: "bannertitle")
    var bannerText               = CLArgument(long: "bannertext")
    var button1TextOption        = CLArgument(long: "button1text")
    var button1ActionOption      = CLArgument(long: "button1action")
    var button1ShellActionOption = CLArgument(long: "button1shellaction",short: "")
    var button2TextOption        = CLArgument(long: "button2text")
    var button2ActionOption      = CLArgument(long: "button2action")
    var buttonInfoTextOption     = CLArgument(long: "infobuttontext")
    var buttonInfoActionOption   = CLArgument(long: "infobuttonaction")
    var dropdownTitle            = CLArgument(long: "selecttitle")
    var dropdownValues           = CLArgument(long: "selectvalues")
    var dropdownDefault          = CLArgument(long: "selectdefault")
    var titleFont                = CLArgument(long: "titlefont")
    var messageFont              = CLArgument(long: "messagefont")
    var textField                = CLArgument(long: "textfield")
    var checkbox                 = CLArgument(long: "checkbox")
    var timerBar                 = CLArgument(long: "timer")
    var progressBar              = CLArgument(long: "progress")
    var progressText             = CLArgument(long: "progresstext")
    var mainImage                = CLArgument(long: "image", short: "g")
    var mainImageCaption         = CLArgument(long: "imagecaption")
    var windowWidth              = CLArgument(long: "width")
    var windowHeight             = CLArgument(long: "height")
    var watermarkImage           = CLArgument(long: "background", short: "bg")
    var watermarkAlpha           = CLArgument(long: "bgalpha", short: "ba")
    var watermarkPosition        = CLArgument(long: "bgposition", short: "bp")
    var watermarkFill            = CLArgument(long: "bgfill", short: "bf")
    var watermarkScale           = CLArgument(long: "bgscale", short: "bs")
    var position                 = CLArgument(long: "position")
    var video                    = CLArgument(long: "video")
    var videoCaption             = CLArgument(long: "videocaption")
    var debug                    = CLArgument(long: "debug")
    var jsonFile                 = CLArgument(long: "jsonfile")
    var jsonString               = CLArgument(long: "jsonstring")
    var statusLogFile            = CLArgument(long: "commandfile")
    var listItem                 = CLArgument(long: "listitem")
    var listStyle                = CLArgument(long: "liststyle")
    var infoText                 = CLArgument(long: "infotext")
    var infoBox                  = CLArgument(long: "infobox")
    var quitKey                  = CLArgument(long: "quitkey")
    var webcontent               = CLArgument(long: "webcontent")

    // command line options that take no additional parameters
    var button1Disabled          = CLArgument(long: "button1disabled", isbool: true)
    var button2Disabled          = CLArgument(long: "button2disabled", isbool: true)
    var button2Option            = CLArgument(long: "button2", short: "2", isbool: true)
    var infoButtonOption         = CLArgument(long: "infobutton", short: "3", isbool: true)
    var getVersion               = CLArgument(long: "version", short: "v")
    var hideIcon                 = CLArgument(long: "hideicon", short: "h")
    var centreIcon               = CLArgument(long: "centreicon", isbool: true)
    var centreIconSE             = CLArgument(long: "centericon", isbool: true) // the other way of spelling
    var helpOption               = CLArgument(long: "help")
    var demoOption               = CLArgument(long: "demo")
    var buyCoffee                = CLArgument(long: "coffee", short: "☕️")
    var licence              = CLArgument(long: "licence", short: "l")
    var warningIcon              = CLArgument(long: "warningicon") // Deprecated
    var infoIcon                 = CLArgument(long: "infoicon") // Deprecated
    var cautionIcon              = CLArgument(long: "cautionicon") // Deprecated
    var hideTimerBar             = CLArgument(long: "hidetimerbar")
    var autoPlay                 = CLArgument(long: "autoplay")
    var blurScreen               = CLArgument(long: "blurscreen", isbool: true)
    var notification             = CLArgument(long: "notification", isbool: true)
    
    //var lockWindow               = CLArgument(long: "moveable", short: "o")
    var constructionKit          = CLArgument(long: "builder", isbool: true)
    var movableWindow            = CLArgument(long: "moveable", short: "o", isbool: true)
    var forceOnTop               = CLArgument(long: "ontop", short: "p", isbool: true)
    var smallWindow              = CLArgument(long: "small", short: "s", isbool: true)
    var bigWindow                = CLArgument(long: "big", short: "b", isbool: true)
    var fullScreenWindow         = CLArgument(long: "fullscreen", short: "f", isbool: true)
    var quitOnInfo               = CLArgument(long: "quitoninfo", isbool: true)
    var listFonts                = CLArgument(long: "listfonts")
    var jsonOutPut               = CLArgument(long: "json", short: "j", isbool: true)
    var ignoreDND                = CLArgument(long: "ignorednd", short: "d", isbool: true)
    var jamfHelperMode           = CLArgument(long: "jh", short: "jh", isbool: true)
    var miniMode                 = CLArgument(long: "mini")
}
