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

var cloptions = CLOptions()

struct AppVariables {
    
    var cliversion                      = String("1.9.1")
    
    // message default strings
    var titleDefault                    = String("An Important Message")
    var messageDefault                  = String("\nThis is important message content\n\nPlease read")
    var messageAlignment : TextAlignment = .leading
    var messageAlignmentTextRepresentation = String("left")
    
    // button default strings
    // work out how to define a default width button that does what you tell it to. in the meantime, diry hack with spaces
    var button1Default                  = String("OK")
    var button2Default                  = String("Cancel")
    var buttonInfoDefault               = String("More Information")
    var buttonInfoActionDefault         = String("")
    
    var windowIsMoveable                = Bool(false)
    var windowOnTop                     = Bool(false)
    var iconIsHidden                    = Bool(false)
    
    // Window Sizes
    var windowWidth                     = CGFloat(820)      // set default dialog width
    var windowHeight                    = CGFloat(380)      // set default dialog height
    
    // Screen Size
    var screenWidth                     = CGFloat(0)
    var screenHeight                    = CGFloat(0)
    
    var videoWindowWidth                = CGFloat(900)
    var videoWindowHeight               = CGFloat(600)
    
    var windowPositionVertical          = NSWindow.Position.Vertical.center
    var windowPositionHorozontal        = NSWindow.Position.Horizontal.center
 
    var iconWidth                      = CGFloat(170)      // set default image area width
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
    var messageFontSize                 = CGFloat(20)
    var messageFontColour               = Color.primary
    var messageFontWeight               = Font.Weight.regular
    var messageFontName                 = ""
    var overlayIconScale                = CGFloat(0.40)
    var overlayOffsetX                  = CGFloat(40)
    var overlayOffsetY                  = CGFloat(50)
    var overlayShadow                   = CGFloat(3)
    
    var selectedOption                  = ""
    var selectedIndex                   = 0

    var jsonOut                         = Bool(false)
    
    var willDisturb                     = Bool(false)
    
    var textOptionsArray                = [String]()
    var textFieldText                   = Array(repeating: "", count: 64)
    
    var checkboxOptionsArray            = [String]()
    var checkboxText                    = Array(repeating: "", count: 64)
    var checkboxValue                   = Array(repeating: false, count: 64)
    var checkboxDisabled                = Array(repeating: false, count: 64)
    
    var imageArray                      = [String]()
    var imageCaptionArray               = [String]()
    
    var listItemArray                   = Array(repeating: "", count: 64)
    var listItemStatus                  = Array(repeating: "", count: 64)
    
    var annimationSmoothing             = Double(20)
    
    var defaultStatusLogFile            = String("/var/tmp/dialog.log")
    
    // exit codes and error messages
    var exit0                           = (code: Int32(0),   message: String("")) // normal exit
    var exit1                           = (code: Int32(1),   message: String("")) // pressed
    var exit2                           = (code: Int32(2),   message: String("")) // pressed button 2
    var exit3                           = (code: Int32(3),   message: String("")) // pressed button 3 (info button)
    var exit4                           = (code: Int32(4),   message: String(""))
    var exit5                           = (code: Int32(4),   message: String("")) // quit via command file
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

struct CLOptions {
    // command line options that take string parameters
    var titleOption              = (long: String("title"),             short: String("t"),   value : String(""), present : Bool(false))  // -t
    var messageOption            = (long: String("message"),           short: String("m"),   value : String(""), present : Bool(false))  // -m
    var messageAlignment         = (long: String("alignment"),         short: String(""),    value : String(""), present : Bool(false))
    var iconOption               = (long: String("icon"),              short: String("i"),   value : String(""), present : Bool(false))  // -i
    var iconSize                 = (long: String("iconsize"),          short: String(""),    value : String(""), present : Bool(false))
  //var iconHeight               = (long: String("iconheight"),        short: String(""),    value : String(""), present : Bool(false))
    var overlayIconOption        = (long: String("overlayicon"),       short: String("y"),   value : String(""), present : Bool(false))  // -y
    var bannerImage              = (long: String("bannerimage"),       short: String("n"),   value : String(""), present : Bool(false))  // -n
    var button1TextOption        = (long: String("button1text"),       short: String(""),    value : String(""), present : Bool(false))
    var button1ActionOption      = (long: String("button1action"),     short: String(""),    value : String(""), present : Bool(false))
    var button1ShellActionOption = (long: String("button1shellaction"),short: String(""),    value : String(""), present : Bool(false))
    var button2TextOption        = (long: String("button2text"),       short: String(""),    value : String(""), present : Bool(false))
    var button2ActionOption      = (long: String("button2action"),     short: String(""),    value : String(""), present : Bool(false))
    var buttonInfoTextOption     = (long: String("infobuttontext"),    short: String(""),    value : String(""), present : Bool(false))
    var buttonInfoActionOption   = (long: String("infobuttonaction"),  short: String(""),    value : String(""), present : Bool(false))
    var dropdownTitle            = (long: String("selecttitle"),       short: String(""),    value : String(""), present : Bool(false))
    var dropdownValues           = (long: String("selectvalues"),      short: String(""),    value : String(""), present : Bool(false))
    var dropdownDefault          = (long: String("selectdefault"),     short: String(""),    value : String(""), present : Bool(false))
    var titleFont                = (long: String("titlefont"),         short: String(""),    value : String(""), present : Bool(false))
    var messageFont              = (long: String("messagefont"),       short: String(""),    value : String(""), present : Bool(false))
    var textField                = (long: String("textfield"),         short: String(""),    value : String(""), present : Bool(false))
    var checkbox                 = (long: String("checkbox"),          short: String(""),    value : String(""), present : Bool(false))
    var timerBar                 = (long: String("timer"),             short: String(""),    value : String(""), present : Bool(false))
    var progressBar              = (long: String("progress"),          short: String(""),    value : String(""), present : Bool(false))
    var mainImage                = (long: String("image"),             short: String("g"),   value : String(""), present : Bool(false))
    var mainImageCaption         = (long: String("imagecaption"),      short: String(""),    value : String(""), present : Bool(false))
    var windowWidth              = (long: String("width"),             short: String(""),    value : String(""), present : Bool(false))
    var windowHeight             = (long: String("height"),            short: String(""),    value : String(""), present : Bool(false))
    var watermarkImage           = (long: String("background"),        short: String("bg"),  value : String(""), present : Bool(false)) // -bg
    var watermarkAlpha           = (long: String("bgalpha"),           short: String("ba"),  value : String(""), present : Bool(false)) // -ba
    var watermarkPosition        = (long: String("bgposition"),        short: String("bp"),  value : String(""), present : Bool(false)) // -bp
    var watermarkFill            = (long: String("bgfill"),            short: String("bf"),  value : String(""), present : Bool(false)) // -bf
    var position                 = (long: String("position"),          short: String(""),    value : String(""), present : Bool(false)) // -bf
    var video                    = (long: String("video"),             short: String(""),    value : String(""), present : Bool(false))
    var videoCaption             = (long: String("videocaption"),      short: String(""),    value : String(""), present : Bool(false))// -bf
    var debug                    = (long: String("debug"),             short: String(""),    value : String(""), present : Bool(false))
    var jsonFile                 = (long: String("jsonfile"),          short: String(""),    value : String(""), present : Bool(false))
    var jsonString               = (long: String("jsonstring"),        short: String(""),    value : String(""), present : Bool(false))
    var statusLogFile            = (long: String("commandfile"),       short: String(""),    value : String(""), present : Bool(false))
    var listItem                 = (long: String("listitem"),          short: String(""),    value : String(""), present : Bool(false))

    // command line options that take no additional parameters
    var button1Disabled          = (long: String("button1disabled"),   short: String(""),    value : String(""), present : Bool(false))
    var button2Option            = (long: String("button2"),           short: String("2"),   value : String(""), present : Bool(false)) // -2
    var infoButtonOption         = (long: String("infobutton"),        short: String("3"),   value : String(""), present : Bool(false)) // -3
    var getVersion               = (long: String("version"),           short: String("v"),   value : String(""), present : Bool(false)) // -v
    var hideIcon                 = (long: String("hideicon"),          short: String("h"),   value : String(""), present : Bool(false)) // -h
    var helpOption               = (long: String("help"),              short: String(""),    value : String(""), present : Bool(false))
    var demoOption               = (long: String("demo"),              short: String(""),    value : String(""), present : Bool(false))
    var buyCoffee                = (long: String("coffee"),            short: String("☕️"),  value : String(""), present : Bool(false))
    var showLicense              = (long: String("showlicense"),       short: String("l"),   value : String(""), present : Bool(false)) // -l
    var warningIcon              = (long: String("warningicon"),       short: String(""),    value : String(""), present : Bool(false)) // Deprecated
    var infoIcon                 = (long: String("infoicon"),          short: String(""),    value : String(""), present : Bool(false)) // Deprecated
    var cautionIcon              = (long: String("cautionicon"),       short: String(""),    value : String(""), present : Bool(false)) // Deprecated
    var hideTimerBar             = (long: String("hidetimerbar"),      short: String(""),    value : String(""), present : Bool(false))
    var autoPlay                 = (long: String("autoplay"),          short: String(""),    value : String(""), present : Bool(false))
    var blurScreen               = (long: String("blurscreen"),        short: String(""),    value : String(""), present : Bool(false))
    
    var lockWindow               = (long: String("moveable"),          short: String("o"),   value : String(""), present : Bool(false)) // -o
    var forceOnTop               = (long: String("ontop"),             short: String("p"),   value : String(""), present : Bool(false)) // -p
    var smallWindow              = (long: String("small"),             short: String("s"),   value : String(""), present : Bool(false)) // -s
    var bigWindow                = (long: String("big"),               short: String("b"),   value : String(""), present : Bool(false)) // -b
    var fullScreenWindow         = (long: String("fullscreen"),        short: String("f"),   value : String(""), present : Bool(false)) // -f
    var quitOnInfo               = (long: String("quitoninfo"),        short: String(""),    value : String(""), present : Bool(false))
    var listFonts                = (long: String("listfonts"),         short: String(""),    value : String(""), present : Bool(false))
    
    var jsonOutPut               = (long: String("json"),              short: String("j"),   value : String(""), present : Bool(false)) // -j
    var ignoreDND                = (long: String("ignorednd"),         short: String("d"),   value : String(""), present : Bool(false)) // -j
    // civhmtsb
    
    var jamfHelperMode           = (long: String("jh"),                short: String("jh"),  value : String(""), present : Bool(false))
}
