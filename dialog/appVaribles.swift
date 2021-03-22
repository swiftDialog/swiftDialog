//
//  appVaribles.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation

var iconVisible: Bool = true

// Probably a way to work all this out as a nice dictionary. For now, long form.

// declare our app var in case we want to update values - e.g. future use, multiple dialog sizes
var appvars = AppVariables()

var helpText = """
    Dialog version \(getVersionString()) ©2021 Bart Reardon
    --title             Set the Dialog title
                        Text over 40 characters gets truncated
                        Default Title is "\(appvars.titleDefault)"
    
    --message           Set the dialog message
                        Message length is up to approximately 80 words
    
    --icon              Set the icon to display
                        Acceptable Values:
                        file path to png or jpg           -  "/file/path/image.[png|jpg]"
                        file path to Application          -  "/Applications/Chess.app"
                        URL of file resource              -  "https://someurl/file.[png|jpg]"
                        builtin                           -  info | caution | warning

                        if not specified, default icon will be used
                        Images from either file or URL are displayed as roundrect if no transparancy

    --overlayicon       Set an image to display as an overlay to --icon
                        image is displayed at 1/2 resolution to the main image and positioned to the bottom right
                        Acceptable Values:
                        file path to png or jpg           -  "/file/path/image.[png|jpg]"
                        file path to Application          -  "/Applications/Chess.app"
                        URL of file resource              -  "https://someurl/file.[png|jpg]"
                        builtin                           -  info | caution | warning

    --infoicon          (Deprecated - use "--icon info" instead) Built in. Displays person with questionmark as the icon

    --cautionicon       (Deprecated - use "--icon caution" instead) Built in. Displays yellow triangle with exclamation point

    --warningicon       (Deprecated - use "--icon warning" instead) Built in. Displays red octagon with exclamation point
    
    --hideicon          hides the icon from view
                        Doing so increases the space available for message text to approximately 100 words

    --button1text       Set the label for Button1
                        Default label is "\(appvars.button1Default)"
                        Bound to <Enter> key

    --button1action     Set the action to take.
                        Accepts URL
                        Default action if not specified is no action
                        Return code when actioned is 0

    --button2           Displays button2 with default label of "\(appvars.button2Default)"
        OR
    --button2text       Set the label for Button1
                        Bound to <ESC> key

    --button2action     Return code when actioned is 2
                        -- Setting Custon Actions For Button 2 Is Not Implemented at this time --

    --infobutton        Displays button2 with default label of "\(appvars.buttonInfoDefault)"
        OR
    --infobuttontext    Set the label for Information Button
                        If not specified, Info button will not be displayed
                        Return code when actioned is 3

    --infobuttonaction  Set the action to take.
                        Accepts URL
                        Default action if not specified is no action

    --moveable          Let window me moved around the screen. Default is not moveable

    --ontop             Make the window appear above all other windows even when not active

    --version           Prints the app version
    --help              Prints this text

    --showlicense       Display the Software License Agreement for Dialog
    """

struct AppVariables {
    var windowWidth                     = CGFloat(820)      // set default dialog width
    var windowHeight                    = CGFloat(380)      // set default dialog height
 
    var imageWidth                      = CGFloat(170)      // set default image area width
    var imageHeight                     = CGFloat(260)      // set default image area height
    
    
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
    
    // reserved for future experimentation
    //static var iconVisible = true
    //static var displayMoreInfo = true // testing
    //static var textAllignment = "centre" //testing
    //static var textAllignment = "top" //testing
    //static var textAllignment = "left" //testing
}


struct CLOptions {
    static let titleOption              = String("--title")
    static let messageOption            = String("--message")
    static let iconOption               = String("--icon")
    static let overlayIconOption        = String("--overlayicon")
    static let button1TextOption        = String("--button1text")
    static let button1ActionOption      = String("--button1action")
    static let button2TextOption        = String("--button2text")
    static let button2ActionOption      = String("--button2action")
    static let buttonInfoTextOption     = String("--infobuttontext")
    static let buttonInfoActionOption   = String("--infobuttonaction")
   
    // command line options that take no additional parameters
    static let button2Option            = String("--button2")
    static let infoButtonOption         = String("--infobutton")
    static let getVersion               = String("--version")
    static let hideIcon                 = String("--hideicon")
    static let helpOption               = String("--help")
    static let demoOption               = String("--demo")
    static let buyCoffee                = String("--coffee")
    static let showLicense              = String("--showlicense")
    static let warningIcon              = String("--warningicon")
    static let infoIcon                 = String("--infoicon")
    static let cautionIcon              = String("--cautionicon")
    
    static let lockWindow              = String("--moveable")
    static let forceOnTop              = String("--ontop")
}
