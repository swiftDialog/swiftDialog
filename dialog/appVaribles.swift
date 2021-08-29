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

var helpText = """
    Dialog version \(getVersionString()) ©2021 Bart Reardon

    OPTIONS:
        -\(cloptions.titleOption.short), --\(cloptions.titleOption.long) <text>
                    Set the Dialog title
                    Text over 40 characters gets truncated
                    Default Title is "\(appvars.titleDefault)"
        
        -\(cloptions.messageOption.short), --\(cloptions.messageOption.long) <text>
                    Set the dialog message
                    Messages can be plain text or can include Markdown
                    Markdown follows the CommonMark Spec https://spec.commonmark.org/current/
                    The message can be of any length. If it is larger than the viewable area
                    The message contents will be presented in  scrolable area.
    
        -\(cloptions.mainImage.short), --\(cloptions.mainImage.long)  <file> | <url>
                    Display an image instead of a message.
                    Images will be resized to fit the available display area
    
                    --\(cloptions.mainImageCaption.long) <text>
                        Text that will appear underneath the displayed image.
        
        -\(cloptions.iconOption.short), --\(cloptions.iconOption.long) <file> | <url>
                    Set the icon to display
                    Acceptable Values:
                    file path to png or jpg           -  "/file/path/image.[png|jpg]"
                    file path to Application          -  "/Applications/Chess.app"
                    URL of file resource              -  "https://someurl/file.[png|jpg]"
                    SF Symbol                         -  "SF=sf.symbol.name"
                    builtin                           -  info | caution | warning

                    if not specified, default icon will be used
                    Images from either file or URL are displayed as roundrect if no transparancy
        
        -\(cloptions.overlayIconOption.short), --\(cloptions.overlayIconOption.long) <file> | <url>
                    Set an image to display as an overlay to --icon
                    image is displayed at 1/2 resolution to the main image and positioned to the bottom right
                    Acceptable Values:
                    file path to png or jpg           -  "/file/path/image.[png|jpg]"
                    file path to Application          -  "/Applications/Chess.app"
                    URL of file resource              -  "https://someurl/file.[png|jpg]"
                    SF Symbol                         -  "SF=sf.symbol.name"
                    builtin                           -  info | caution | warning
    
                When Specifying SF Symbols for icon or overlay icon, additional parameters for colour and weight are available:
                additionl parameters are seperated by comma

                    "SF=sf.symbol.name,colour=<text><hex>,weight=<text>"
    
                    SF Symbols - visit https://developer.apple.com/sf-symbols/ for details on over 3,100 symbols

                    color,colour=<text><hex>          - specified in hex format, e.g. #00A4C7
                    bgcolor,bgcolour=<text><hex>
                                                      Also accepts any of the standard Apple colours
                                                      black, blue, gray, green, orange, pink, purple, red, white, yellow
                                                      default if option is invalid is system primary colour
    
                                                      bgcolour, bgcolor will set the background colour of the icon overlay
                                                        when SF Symbols are used
    
                                                      - Special colour "auto".
                                                      When used with a multicolor SF Symbol, the symbols
                                                        default colour scheem will be used
                                                      ** If used with a monochrome SF Symbol **
                                                      ** it will default to black and will not respect dark mode **

                    weight=<text>                     - accepts any of the following values:
                                                       thin (default), light, regular, medium, heavy, bold
        
        -\(cloptions.fullScreenWindow.short), --\(cloptions.fullScreenWindow.long)
                    Uses full screen view.
                    In this view, only banner, title, icon and message are visible.

        -\(cloptions.hideIcon.short), --\(cloptions.hideIcon.long)
                    Hides the icon from view
                    Doing so increases the space available for message text to approximately 100 words

        -\(cloptions.bannerImage.short), --\(cloptions.bannerImage.long) <file> | <url>
                    Shows a banner image at the top of the dialog
                    Banners images fill the entire top width of the window and are resized to fill, positioned from
                    the top left corner of the image.
                    Specifying this option will imply --\(cloptions.hideIcon.long)
                    Recommended Banner Image size is 850x150.

        --\(cloptions.button1TextOption.long) <text>
                    Set the label for Button1
                    Default label is "\(appvars.button1Default)"
                    Bound to <Enter> key

        --\(cloptions.button1ActionOption.long) <url>
                    Set the action to take.
                    Accepts URL
                    Default action if not specified is no action
                    Return code when actioned is 0
    
        --\(cloptions.button1ShellActionOption.long) <command>
                    << EXPERIMENTAL >>
                    Runs the specified shell command using zsh
                    Command input and output is not sanitised or checked.
                    If your command fails, Dialog still exits 0

        -\(cloptions.button2Option.short), --\(cloptions.button2Option.long)
                    Displays button2 with default label of "\(appvars.button2Default)"
            OR

        --\(cloptions.button2TextOption.long) <text>
                    Set the label for Button1
                    Bound to <ESC> key

        --\(cloptions.button2ActionOption.long) <url>
                    Return code when actioned is 2
                    -- Setting Custon Actions For Button 2 Is Not Implemented at this time --

        -\(cloptions.infoButtonOption.short), --\(cloptions.infoButtonOption.long)
                    Displays info button with default label of "\(appvars.buttonInfoDefault)"
            
            OR

        --\(cloptions.buttonInfoTextOption.long) <text>
                    Set the label for Information Button
                    If not specified, Info button will not be displayed
                    Return code when actioned is 3

        --\(cloptions.buttonInfoActionOption.long)  <url>
                    Set the action to take.
                    Accepts URL
                    Default action if not specified is no action
    
        --\(cloptions.dropdownTitle.long) <text>
                    Title for dropdown selection
    
        --\(cloptions.dropdownValues.long) <text><csv>
                    List of values to be displayed in the dropdown, specivied in CSV format
                    e.g. "Option 1,Option 2,Option 3"
    
        --\(cloptions.dropdownDefault.long) <text>
                    Default option to be selected (must match one of the items in the list)
    
                    If specified, the selected option will be sent to stdout in two forms:
                      SelectedOption - Outputs the text of the option seelcted
                      SelectedIndex  - Outputs the index of the option selected, starting at 0
    
                      example output b:
                        SelectedOption: Option 1
                        SelectedIndex: 0
    
                    Output of select items is only shown if Dialog's exit code is 0
    
        --\(cloptions.textField.long) <text>
                    Present a textfield with the specified label
                    When Dialog exits the contents of the textfield will be presented as <text> : <user_input>
                    in plain or as json using [-\(cloptions.jsonOutPut.short), --\(cloptions.jsonOutPut.long)] option
                    Multiple textfields can be specified (up to 8).
    
    
        --\(cloptions.titleFont.long) <text>
                    Lets you modify the title text of the dialog.
    
                    Can accept up to three parameters, in a comma seperated list, to modify font properties. 
                    
                        color,colour=<text><hex>  - specified in hex format, e.g. #00A4C7
                                                    Also accepts any of the standard Apple colours
                                                    black, blue, gray, green, orange, pink, purple, red, white, yellow
                                                    default if option is invalid is system primary colour
    
                        size=<float>              - accepts any float value.

                        weight=<text>             - accepts any of the following values:
                            thin
                            light
                            regular
                            medium
                            heavy
                            bold (default)
    
                    Example: \"colour=#00A4C7,weight=light,size=60\"
    
        --\(cloptions.windowWidth.long) <number>
                    Sets the width of the dialog window to the specified width in points
    
        --\(cloptions.windowHeight.long) <number>
                    Sets the height of the dialog window to the specified height in points
    
        --\(cloptions.timerBar.long) (<seconds>)
                    Replaces default button with a timer countdown after which dialog will close with exit code 4
                    Default timer value is 10 seconds
                    Optional value <seconds> can be specified to the desired value
    
                    If used in conjuction with --\(cloptions.button1TextOption.long) the default button
                    will be displayed but will be disabled for the first 3 seconds of the timer, after which it
                    becomes active and can be used to dismiss dialog with the standard button 1 exit code of 0
    
        -\(cloptions.lockWindow.short), --\(cloptions.lockWindow.long)
                    Let window me moved around the screen. Default is not moveable

        -\(cloptions.forceOnTop.short), --\(cloptions.forceOnTop.long)
                    Make the window appear above all other windows even when not active

        -\(cloptions.bigWindow.short), --\(cloptions.bigWindow.long)
                    Makes the dialog 25% bigger than normal. More room for message text

        -\(cloptions.smallWindow.short), --\(cloptions.smallWindow.long)
                    Makes the dialog 25% smaller. Less room for message text.
    
        -\(cloptions.jsonOutPut.short), --\(cloptions.jsonOutPut.long)
                    Outputs any results in json format for easier processing
                    (for dropdown item selections and textfield responses)

        -\(cloptions.ignoreDND.short), --\(cloptions.ignoreDND.long)
                    Will ignore user Do Not Disturb setting
                        (only works in macOS 11)
    
        -\(cloptions.getVersion.short), --\(cloptions.getVersion.long)
                    Prints the app version

        -\(cloptions.showLicense.short), --\(cloptions.showLicense.long)
                    Display the Software License Agreement for Dialog

        --\(cloptions.helpOption.long)
                    Prints this text
    """

struct AppVariables {

    var cliversion                      = String("1.6.1")
    
    // message default strings
    var titleDefault                    = String("An Important Message")
    var messageDefault                  = String("\nThis is important message content\n\nPlease read")
    
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
    
    var windowPositionVertical          = NSWindow.Position.Vertical.center
    var windowPositionHorozontal        = NSWindow.Position.Horizontal.center
 
    var imageWidth                      = CGFloat(170)      // set default image area width
    var imageHeight                     = CGFloat(260)      // set default image area height
    var titleHeight                     = CGFloat(50)
    var bannerHeight                    = CGFloat(-10)
    var bannerOffset                    = CGFloat(0)
    
    var smallWindow                     = Bool(false)
    var bigWindow                       = Bool(false)
    var scaleFactor                     = CGFloat(1)
    
    var timerDefaultSeconds             = CGFloat(10)

    var horozontalLineScale             = CGFloat(0.9)
    var dialogContentScale              = CGFloat(0.65)
    var titleFontSize                   = CGFloat(30)
    var titleFontColour                 = Color.primary
    var titleFontWeight                 = Font.Weight.bold
    //var titleFontFont                   = Font.TextStyle
    var overlayIconScale                = CGFloat(0.40)
    var overlayOffsetX                  = CGFloat(40)
    var overlayOffsetY                  = CGFloat(50)
    var overlayShadow                   = CGFloat(3)
    
    var selectedOption                  = ""
    var selectedIndex                   = 0

    var jsonOut                         = Bool(false)
    
    var willDisturb                     = Bool(false)
    
    var textOptionsArray                = [String]()
    var textFieldText                   = Array(repeating: "", count: 8)
    //var textOptionsText                 = [String]()
    
    var annimationSmoothing             = Double(20)
    
    // exit codes and error messages
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
    
    // reserved for future experimentation
    //static var iconVisible = true
    //static var displayMoreInfo = true // testing
    //static var textAllignment = "centre" //testing
    //static var textAllignment = "top" //testing
    //static var textAllignment = "left" //testing
    
    // debug flag
    var debugMode                       = Bool(false)
    var debugBorderColour               = Color.clear
}

struct CLOptions {
    // command line options that take string parameters
    var titleOption              = (long: String("title"),             short: String("t"),   value : String(""), present : Bool(false))  // -t
    var messageOption            = (long: String("message"),           short: String("m"),   value : String(""), present : Bool(false))  // -m
    var iconOption               = (long: String("icon"),              short: String("i"),   value : String(""), present : Bool(false))  // -i
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
    var textField                = (long: String("textfield"),         short: String(""),    value : String(""), present : Bool(false))
    var timerBar                 = (long: String("timer"),             short: String(""),    value : String(""), present : Bool(false))
    var mainImage                = (long: String("image"),             short: String("g"),   value : String(""), present : Bool(false))
    var mainImageCaption         = (long: String("imagecaption"),      short: String(""),    value : String(""), present : Bool(false))
    var windowWidth              = (long: String("width"),             short: String(""),    value : String(""), present : Bool(false))
    var windowHeight             = (long: String("height"),            short: String(""),    value : String(""), present : Bool(false))
    var debug                    = (long: String("debug"),             short: String(""),    value : String(""), present : Bool(false))

   
    // command line options that take no additional parameters
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
    
    var lockWindow               = (long: String("moveable"),          short: String("o"),   value : String(""), present : Bool(false)) // -o
    var forceOnTop               = (long: String("ontop"),             short: String("p"),   value : String(""), present : Bool(false)) // -p
    var smallWindow              = (long: String("small"),             short: String("s"),   value : String(""), present : Bool(false)) // -s
    var bigWindow                = (long: String("big"),               short: String("b"),   value : String(""), present : Bool(false)) // -b
    var fullScreenWindow         = (long: String("fullscreen"),        short: String("f"),   value : String(""), present : Bool(false)) // -f
    
    var jsonOutPut               = (long: String("json"),              short: String("j"),   value : String(""), present : Bool(false)) // -j
    var ignoreDND                = (long: String("ignorednd"),         short: String("d"),   value : String(""), present : Bool(false)) // -j
    // civhmtsb
    
    var jamfHelperMode           = (long: String("jh"),                short: String("jh"),  value : String(""), present : Bool(false))
}
