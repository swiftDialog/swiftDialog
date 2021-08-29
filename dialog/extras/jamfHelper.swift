//
//  jamfHelper_syntax.swift
//  dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 29/8/21.
//

import Foundation
import SwiftUI

struct JHOptions {
    static let windowType         = (long: String("windowType"),       short: String("windowType"),         value : String(""), present : Bool(false)) // -windowType [hud | utility | fs]
    static let windowPosition     = (long: String("windowPosition"),   short: String("windowPosition"),     value : String(""), present : Bool(false)) // -windowPosition [ul | ll | ur | lr]
    static let title              = (long: String("title"),            short: String("title"),              value : String(""), present : Bool(false)) // -title "string"
    static let heading            = (long: String("heading"),          short: String("heading"),            value : String(""), present : Bool(false)) // -heading "string"
    static let description        = (long: String("description"),      short: String("description"),        value : String(""), present : Bool(false)) // -description "string"
    static let icon               = (long: String("icon"),             short: String("icon"),               value : String(""), present : Bool(false)) // -icon path
    static let button1            = (long: String("button1"),          short: String("button1"),            value : String(""), present : Bool(false)) // -button1 "string"
    static let button2            = (long: String("button2"),          short: String("button2"),            value : String(""), present : Bool(false)) // -button2 "string"
    static let defaultButton      = (long: String("defaultButton"),    short: String("defaultButton"),      value : String(""), present : Bool(false)) // -defaultButton [1 | 2]
    static let cancelButton       = (long: String("cancelButton"),     short: String("cancelButton"),       value : String(""), present : Bool(false)) // -cancelButton [1 | 2]
    static let showDelayOptions   = (long: String("showDelayOptions"), short: String("showDelayOptions"),   value : String(""), present : Bool(false)) // -showDelayOptions "int, int, int,..."
    static let alignDescription   = (long: String("alignDescription"), short: String("alignDescription"),   value : String(""), present : Bool(false)) // -alignDescription [right | left | center | justified | natural]
    static let alignHeading       = (long: String("alignHeading"),     short: String("alignHeading"),       value : String(""), present : Bool(false)) // -alignHeading [right | left | center | justified | natural]
    static let alignCountdown     = (long: String("alignCountdown"),   short: String("alignCountdown"),     value : String(""), present : Bool(false)) // -alignCountdown [right | left | center | justified | natural]
    static let timeout            = (long: String("timeout"),          short: String("timeout"),            value : String(""), present : Bool(false)) // -timeout int
    static let countdown          = (long: String("countdown"),        short: String("countdown"),          value : String(""), present : Bool(false)) // -countdown
    static let iconSize           = (long: String("iconSize"),         short: String("iconSize"),           value : String(""), present : Bool(false)) // -iconSize pixels
    static let lockHUD            = (long: String("lockHUD"),          short: String("lockHUD"),            value : String(""), present : Bool(false)) // -lockHUD
    static let fullScreenIcon     = (long: String("fullScreenIcon"),   short: String("fullScreenIcon"),     value : String(""), present : Bool(false)) // -fullScreenIcon
    
    public func return_jh_value() {
        
    }
    
}

public func convertFromJamfHelperSyntax() {
    // read the jamfhelper syntax from the command line and populate the appropriate dialog values
    cloptions.smallWindow.present = true
    
    //fullscreen
    if CLOptionPresent(OptionName: JHOptions.windowType) && CLOptionText(OptionName: JHOptions.windowType) == "fs" {
        cloptions.fullScreenWindow.present = true
    }
    
    // title
    cloptions.titleOption.present = CLOptionPresent(OptionName: JHOptions.title)
    cloptions.titleOption.value = CLOptionText(OptionName: JHOptions.title)
    
    // message
    cloptions.messageOption.present = CLOptionPresent(OptionName: JHOptions.description)
    if !cloptions.fullScreenWindow.present {
        cloptions.messageOption.value = "### \(CLOptionText(OptionName: JHOptions.heading))\n\n\(CLOptionText(OptionName: JHOptions.description))"
    } else {
        cloptions.messageOption.value = "\(CLOptionText(OptionName: JHOptions.heading))\n\n\(CLOptionText(OptionName: JHOptions.description))"
    }
    
    //icon
    cloptions.iconOption.present         = CLOptionPresent(OptionName: JHOptions.icon)
    cloptions.iconOption.value = CLOptionText(OptionName: JHOptions.icon)
    
    //button 1
    cloptions.button1TextOption.present = CLOptionPresent(OptionName: JHOptions.button1)
    cloptions.button1TextOption.value = CLOptionText(OptionName: JHOptions.button1)
    
    //button 2
    cloptions.button2TextOption.present = CLOptionPresent(OptionName: JHOptions.button2)
    cloptions.button2TextOption.value = CLOptionText(OptionName: JHOptions.button2)
    
    //countdown or timer
    cloptions.timerBar.present = CLOptionPresent(OptionName: JHOptions.timeout)
    cloptions.timerBar.value = CLOptionText(OptionName: JHOptions.timeout)
    
    if CLOptionPresent(OptionName: JHOptions.windowPosition) {
        switch CLOptionText(OptionName: JHOptions.windowPosition) {
        case "ul":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.top
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.left
        case "ur":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.top
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.right
        case "ll":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.bottom
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.left
        case "lr":
            appvars.windowPositionVertical = NSWindow.Position.Vertical.bottom
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.right
        default:
            appvars.windowPositionVertical = NSWindow.Position.Vertical.center
            appvars.windowPositionHorozontal = NSWindow.Position.Horizontal.center
        }
    }
    
    if cloptions.debug.present {
        print(cloptions)
    }
}

/*
 
 -windowType [hud | utility | fs]
     hud: creates an Apple "Heads Up Display" style window
     utility: creates an Apple "Utility" style window
     fs: creates a full screen window the restricts all user input
         WARNING: Remote access must be used to unlock machines in this mode

 -windowPosition [ul | ll | ur | lr]
     Positions window in the upper right, upper left, lower right or lower left of the user's screen
     If no input is given, the window defaults to the center of the screen

 -title "string"
     Sets the window's title to the specified string

 -heading "string"
     Sets the heading of the window to the specified string

 -description "string"
     Sets the main contents of the window to the specified string

 -icon path
     Sets the windows image filed to the image located at the specified path

 -button1 "string"
     Creates a button with the specified label

 -button2 "string"
     Creates a second button with the specified label

 -defaultButton [1 | 2]
     Sets the default button of the window to the specified button. The Default Button will respond to "return"

 -cancelButton [1 | 2]
     Sets the cancel button of the window to the specified button. The Cancel Button will respond to "escape"

 -showDelayOptions "int, int, int,..."
     Enables the "Delay Options Mode". The window will display a dropdown with the values passed through the string

 -alignDescription [right | left | center | justified | natural]
     Aligns the description to the specified alignment

 -alignHeading [right | left | center | justified | natural]
     Aligns the heading to the specified alignment

 -alignCountdown [right | left | center | justified | natural]
     Aligns the countdown to the specified alignment

 -timeout int
     Causes the window to timeout after the specified amount of seconds
     Note: The timeout will cause the default button, button 1 or button 2 to be selected (in that order)

 -countdown
     Displays a string notifying the user when the window will time out

 -iconSize pixels
     Changes the image frame to the specified pixel size

 -lockHUD
     Removes the ability to exit the HUD by selecting the close button

 -fullScreenIcon
     Scales the "icon" to the full size of the window
     Note: Only available in full screen mode


 Return Values: The JAMF Helper will print the following return values to stdout...
     0 - Button 1 was clicked
     1 - The Jamf Helper was unable to launch
     2 - Button 2 was clicked
     XX1 - Button 1 was clicked with a value of XX seconds selected in the drop-down
     XX2 - Button 2 was clicked with a value of XX seconds selected in the drop-down
     239 - The exit button was clicked
     243 - The window timed-out with no buttons on the screen
     250 - Bad "-windowType"
     255 - No "-windowType"


 */
