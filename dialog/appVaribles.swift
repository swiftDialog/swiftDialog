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

var helpText = """
    Dialog version \(getVersionString()) ©2021 Bart Reardon

    OPTIONS:
        -\(CLOptions.titleOption.short), --\(CLOptions.titleOption.long) <text>
                    Set the Dialog title
                    Text over 40 characters gets truncated
                    Default Title is "\(appvars.titleDefault)"
        
        -\(CLOptions.messageOption.short), --\(CLOptions.messageOption.long) <text>
                    Set the dialog message
                    Message length is up to approximately 80 words
        
        -\(CLOptions.iconOption.short), --\(CLOptions.iconOption.long) <file> | <url>
                    Set the icon to display
                    Acceptable Values:
                    file path to png or jpg           -  "/file/path/image.[png|jpg]"
                    file path to Application          -  "/Applications/Chess.app"
                    URL of file resource              -  "https://someurl/file.[png|jpg]"
                    builtin                           -  info | caution | warning

                    if not specified, default icon will be used
                    Images from either file or URL are displayed as roundrect if no transparancy

        -\(CLOptions.fullScreenWindow.short), --\(CLOptions.fullScreenWindow.long)
                    Uses full screen view.
                    In this view, only banner, title, icon and message are visible.

        -\(CLOptions.overlayIconOption.short), --\(CLOptions.overlayIconOption.long) <file> | <url>
                    Set an image to display as an overlay to --icon
                    image is displayed at 1/2 resolution to the main image and positioned to the bottom right
                    Acceptable Values:
                    file path to png or jpg           -  "/file/path/image.[png|jpg]"
                    file path to Application          -  "/Applications/Chess.app"
                    URL of file resource              -  "https://someurl/file.[png|jpg]"
                    builtin                           -  info | caution | warning
        
        -\(CLOptions.hideIcon.short), --\(CLOptions.hideIcon.long)
                    Hides the icon from view
                    Doing so increases the space available for message text to approximately 100 words

        -\(CLOptions.bannerImage.short), --\(CLOptions.bannerImage.long) <file> | <url>
                    Shows a banner image at the top of the dialog
                    Banners images fill the entire top width of the window and are resized to fill, positioned from
                    the top left corner of the image.
                    Specifying this option will imply --\(CLOptions.hideIcon.long)
                    Recommended Banner Image size is 850x150.

        --\(CLOptions.button1TextOption.long) <text>
                    Set the label for Button1
                    Default label is "\(appvars.button1Default)"
                    Bound to <Enter> key

        --\(CLOptions.button1ActionOption.long) <url>
                    Set the action to take.
                    Accepts URL
                    Default action if not specified is no action
                    Return code when actioned is 0
    
        --\(CLOptions.button1ShellActionOption.long) <command>
                    << EXPERIMENTAL >>
                    Runs the specified shell command using zsh
                    Command input and output is not sanitised or checked.
                    If your command fails, Dialog still exits 0

        -\(CLOptions.button2Option.short), --\(CLOptions.button2Option.long)
                    Displays button2 with default label of "\(appvars.button2Default)"
            OR

        --\(CLOptions.button2TextOption.long) <text>
                    Set the label for Button1
                    Bound to <ESC> key

        --\(CLOptions.button2ActionOption.long) <url>
                    Return code when actioned is 2
                    -- Setting Custon Actions For Button 2 Is Not Implemented at this time --

        -\(CLOptions.infoButtonOption.short), --\(CLOptions.infoButtonOption.long)
                    Displays info button with default label of "\(appvars.buttonInfoDefault)"
            
            OR

        --\(CLOptions.buttonInfoTextOption.long) <text>
                    Set the label for Information Button
                    If not specified, Info button will not be displayed
                    Return code when actioned is 3

        --\(CLOptions.buttonInfoActionOption.long)  <url>
                    Set the action to take.
                    Accepts URL
                    Default action if not specified is no action
    
        --\(CLOptions.dropdownTitle.long) <text>
                    Title for dropdown selection
    
        --\(CLOptions.dropdownValues.long) <text><csv>
                    List of values to be displayed in the dropdown, specivied in CSV format
                    e.g. "Option 1,Option 2,Option 3"
    
        --\(CLOptions.dropdownDefault.long) <text>
                    Default option to be selected (must match one of the items in the list)
    
                    If specified, the selected option will be sent to stdout in two forms:
                      SelectedOption - Outputs the text of the option seelcted
                      SelectedIndex  - Outputs the index of the option selected, starting at 0
    
                      example output b:
                        SelectedOption: Option 1
                        SelectedIndex: 0
    
                    Output of select items is only shown if Dialog's exit code is 0


        -\(CLOptions.lockWindow.short), --\(CLOptions.lockWindow.long)
                    Let window me moved around the screen. Default is not moveable

        -\(CLOptions.forceOnTop.short), --\(CLOptions.forceOnTop.long)
                    Make the window appear above all other windows even when not active

        -\(CLOptions.bigWindow.short), --\(CLOptions.bigWindow.long)
                    Makes the dialog 25% bigger than normal. More room for message text

        -\(CLOptions.smallWindow.short), --\(CLOptions.smallWindow.long)
                    Makes the dialog 25% smaller. Less room for message text.
    
        -\(CLOptions.jsonOutPut.short), --\(CLOptions.jsonOutPut.long)
                    Outputs any results in json format for easier processing
                    (currently limited to dropdown item selections)

        -\(CLOptions.getVersion.short), --\(CLOptions.getVersion.long)
                    Prints the app version

        -\(CLOptions.showLicense.short), --\(CLOptions.showLicense.long)
                    Display the Software License Agreement for Dialog

        --\(CLOptions.helpOption.long)
                    Prints this text
    """

struct AppVariables {

    var cliversion                      = String("1.3.2")
    
    // message default strings
    var titleDefault                    = String("An Important Message")
    var messageDefault                  = String("\nThis is important message content\n\nPlease read")
    
    // button default strings
    // work out how to define a default width button that does what you tell it to. in the meantime, diry hack with spaces
    var button1Default                  = String("    OK    ")
    var button2Default                  = String("Cancel")
    var buttonInfoDefault               = String("More Information")
    var buttonInfoActionDefault         = String("")
    
    var windowIsMoveable                = Bool(false)
    var windowOnTop                     = Bool(false)
    var iconIsHidden                    = Bool(false)
    
    // Window Sizes
    var windowWidth                     = CGFloat(820)      // set default dialog width
    var windowHeight                    = CGFloat(380)      // set default dialog height
 
    var imageWidth                      = CGFloat(170)      // set default image area width
    var imageHeight                     = CGFloat(260)      // set default image area height
    var titleHeight                     = CGFloat(50)
    var bannerHeight                    = CGFloat(-10)
    var bannerOffset                    = CGFloat(0)
    
    var smallWindow                     = Bool(false)
    var bigWindow                       = Bool(false)
    var scaleFactor                     = CGFloat(1)

    var horozontalLineScale             = CGFloat(0.9)
    var dialogContentScale              = CGFloat(0.65)
    var titleFontSize                   = CGFloat(30)
    var overlayIconScale                = CGFloat(0.5)
    var overlayOffsetX                  = CGFloat(40)
    var overlayOffsetY                  = CGFloat(50)
    var overlayShadow                   = CGFloat(3)
    
    var debugBorderColour               = Color.clear
    
    var selectedOption                  = ""
    var selectedIndex                   = 0
    
    var jsonOut                         = Bool(false)
    
    // exit codes and error messages
    var exit201                         = (code: Int32(201), message: String("ERROR: Image resource cannot be found :"))
    var exit202                         = (code: Int32(202), message: String("ERROR: File not found :"))
    var exit203                         = (code: Int32(203), message: String(""))
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
}


struct CLOptions {
    // command line options that take string parameters
    static let titleOption              = (long: String("title"),             short: String("t"))  // -t
    static let messageOption            = (long: String("message"),           short: String("m"))  // -m
    static let iconOption               = (long: String("icon"),              short: String("i"))  // -i
    static let overlayIconOption        = (long: String("overlayicon"),       short: String("y"))  // -y
    static let bannerImage              = (long: String("bannerimage"),       short: String("n"))  // -n
    static let button1TextOption        = (long: String("button1text"),       short: String(""))
    static let button1ActionOption      = (long: String("button1action"),     short: String(""))
    static let button1ShellActionOption = (long: String("button1shellaction"),short: String(""))
    static let button2TextOption        = (long: String("button2text"),       short: String(""))
    static let button2ActionOption      = (long: String("button2action"),     short: String(""))
    static let buttonInfoTextOption     = (long: String("infobuttontext"),    short: String(""))
    static let buttonInfoActionOption   = (long: String("infobuttonaction"),  short: String(""))
    static let dropdownTitle            = (long: String("selecttitle"),       short: String(""))
    static let dropdownValues           = (long: String("selectvalues"),      short: String(""))
    static let dropdownDefault          = (long: String("selectdefault"),     short: String(""))

   
    // command line options that take no additional parameters
    static let button2Option            = (long: String("button2"),           short: String("2")) // -2
    static let infoButtonOption         = (long: String("infobutton"),        short: String("3")) // -3
    static let getVersion               = (long: String("version"),           short: String("v")) // -v
    static let hideIcon                 = (long: String("hideicon"),          short: String("h")) // -h
    static let helpOption               = (long: String("help"),              short: String(""))
    static let demoOption               = (long: String("demo"),              short: String(""))
    static let buyCoffee                = (long: String("coffee"),            short: String("☕️"))
    static let showLicense              = (long: String("showlicense"),       short: String("l")) // -l
    static let warningIcon              = (long: String("warningicon"),       short: String("")) // Deprecated
    static let infoIcon                 = (long: String("infoicon"),          short: String("")) // Deprecated
    static let cautionIcon              = (long: String("cautionicon"),       short: String("")) // Deprecated
    
    static let lockWindow               = (long: String("moveable"),          short: String("o")) // -o
    static let forceOnTop               = (long: String("ontop"),             short: String("p")) // -p
    static let smallWindow              = (long: String("small"),             short: String("s")) // -s
    static let bigWindow                = (long: String("big"),               short: String("b")) // -b
    static let fullScreenWindow         = (long: String("fullscreen"),        short: String("f")) // -f
    
    static let jsonOutPut               = (long: String("json"),              short: String("j")) // -j
    // civhmtsb
}
