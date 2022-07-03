//
//  jamfHelper_syntax.swift
//  dialog
//
//  Created by Bart Reardon on 29/8/21.
//

import Foundation
import SwiftUI

struct JHOptions {
    static let windowType         = CLArgument(long: "windowType",       short: "windowType")       // -windowType [hud | utility | fs]
    static let windowPosition     = CLArgument(long: "windowPosition",   short: "windowPosition")   // -windowPosition [ul | ll | ur | lr]
    static let title              = CLArgument(long: "title",            short: "title")            // -title "string"
    static let heading            = CLArgument(long: "heading",          short: "heading")          // -heading "string"
    static let description        = CLArgument(long: "description",      short: "description")      // -description "string"
    static let icon               = CLArgument(long: "icon",             short: "icon")             // -icon path
    static let button1            = CLArgument(long: "button1",          short: "button1")          // -button1 "string"
    static let button2            = CLArgument(long: "button2",          short: "button2")          // -button2 "string"
    static let defaultButton      = CLArgument(long: "defaultButton",    short: "defaultButton")    // -defaultButton [1 | 2]
    static let cancelButton       = CLArgument(long: "cancelButton",     short: "cancelButton")     // -cancelButton [1 | 2]
    static let showDelayOptions   = CLArgument(long: "showDelayOptions", short: "showDelayOptions") // -showDelayOptions "int, int, int,..."
    static let alignDescription   = CLArgument(long: "alignDescription", short: "alignDescription") // -alignDescription [right | left | center | justified | natural]
    static let alignHeading       = CLArgument(long: "alignHeading",     short: "alignHeading")     // -alignHeading [right | left | center | justified | natural]
    static let alignCountdown     = CLArgument(long: "alignCountdown",   short: "alignCountdown")   // -alignCountdown [right | left | center | justified | natural]
    static let timeout            = CLArgument(long: "timeout",          short: "timeout")          // -timeout int
    static let countdown          = CLArgument(long: "countdown",        short: "countdown")        // -countdown
    static let iconSize           = CLArgument(long: "iconSize",         short: "iconSize")         // -iconSize pixels
    static let lockHUD            = CLArgument(long: "lockHUD",          short: "lockHUD")          // -lockHUD
    static let fullScreenIcon     = CLArgument(long: "fullScreenIcon",   short: "fullScreenIcon")   // -fullScreenIcon
    
    public func return_jh_value() {
        
    }
    
}

public func convertFromJamfHelperSyntax() {
    // read the jamfhelper syntax from the command line and populate the appropriate dialog values
    //appArguments.smallWindow.present = true
    
    //fullscreen
    if CLOptionPresent(OptionName: JHOptions.windowType) && CLOptionText(OptionName: JHOptions.windowType) == "fs" {
        appArguments.fullScreenWindow.present = true
    }
    
    // title
    appArguments.titleOption.present = CLOptionPresent(OptionName: JHOptions.title)
    appArguments.titleOption.value = CLOptionText(OptionName: JHOptions.title)
    
    // message
    appArguments.messageOption.present = CLOptionPresent(OptionName: JHOptions.description)
    if !appArguments.fullScreenWindow.present {
        appArguments.messageOption.value = "#### \(CLOptionText(OptionName: JHOptions.heading))\n\n\(CLOptionText(OptionName: JHOptions.description))"
    } else {
        appArguments.messageOption.value = "\(CLOptionText(OptionName: JHOptions.heading))\n\n\(CLOptionText(OptionName: JHOptions.description))"
    }
    
    // message alignment
    appArguments.messageAlignment.present = CLOptionPresent(OptionName: JHOptions.alignDescription)
    appArguments.messageAlignment.value = CLOptionText(OptionName: JHOptions.alignDescription)
    if appArguments.messageAlignment.present {
        switch appArguments.messageAlignment.value {
        case "left":
            appvars.messageAlignment = .leading
        case "centre", "center":
            appvars.messageAlignment = .center
        case "right":
            appvars.messageAlignment = .trailing
        default:
            appvars.messageAlignment = .leading
        }
    }
    
    //icon
    appArguments.iconOption.present         = CLOptionPresent(OptionName: JHOptions.icon)
    appArguments.iconOption.value = CLOptionText(OptionName: JHOptions.icon)
    if !appArguments.iconOption.present {
        appvars.iconIsHidden = true
    }
    
    //icon size
    appArguments.iconSize.present = CLOptionPresent(OptionName: JHOptions.iconSize)
    appArguments.iconSize.value = CLOptionText(OptionName: JHOptions.iconSize, DefaultValue: "\(appvars.iconWidth)")

    
    //button 1
    appArguments.button1TextOption.present = CLOptionPresent(OptionName: JHOptions.button1)
    appArguments.button1TextOption.value = CLOptionText(OptionName: JHOptions.button1)
    if !appArguments.button1TextOption.present {
        appArguments.button1TextOption.value = "OK"
    }
    
    //button 2
    appArguments.button2TextOption.present = CLOptionPresent(OptionName: JHOptions.button2)
    appArguments.button2TextOption.value = CLOptionText(OptionName: JHOptions.button2)
    
    //countdown or timer
    appArguments.timerBar.present = CLOptionPresent(OptionName: JHOptions.timeout)
    appArguments.timerBar.value = CLOptionText(OptionName: JHOptions.timeout)
    
    // window location on screen
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
