//
//  jamfHelper_syntax.swift
//  dialog
//
//  Created by Bart Reardon on 29/8/21.
//

import Foundation
import SwiftUI

struct JHOptions {
    static let windowType         = CommandlineArgument(long: "windowType",       short: "windowType")       // -windowType [hud | utility | fs]
    static let windowPosition     = CommandlineArgument(long: "windowPosition",   short: "windowPosition")   // -windowPosition [ul | ll | ur | lr]
    static let title              = CommandlineArgument(long: "title",            short: "title")            // -title "string"
    static let heading            = CommandlineArgument(long: "heading",          short: "heading")          // -heading "string"
    static let description        = CommandlineArgument(long: "description",      short: "description")      // -description "string"
    static let icon               = CommandlineArgument(long: "icon",             short: "icon")             // -icon path
    static let button1            = CommandlineArgument(long: "button1",          short: "button1")          // -button1 "string"
    static let button2            = CommandlineArgument(long: "button2",          short: "button2")          // -button2 "string"
    static let defaultButton      = CommandlineArgument(long: "defaultButton",    short: "defaultButton")    // -defaultButton [1 | 2]
    static let cancelButton       = CommandlineArgument(long: "cancelButton",     short: "cancelButton")     // -cancelButton [1 | 2]
    static let showDelayOptions   = CommandlineArgument(long: "showDelayOptions", short: "showDelayOptions") // -showDelayOptions "int, int, int,..."
    static let alignDescription   = CommandlineArgument(long: "alignDescription", short: "alignDescription") // -alignDescription [right | left | center | justified | natural]
    static let alignHeading       = CommandlineArgument(long: "alignHeading",     short: "alignHeading")     // -alignHeading [right | left | center | justified | natural]
    static let alignCountdown     = CommandlineArgument(long: "alignCountdown",   short: "alignCountdown")   // -alignCountdown [right | left | center | justified | natural]
    static let timeout            = CommandlineArgument(long: "timeout",          short: "timeout")          // -timeout int
    static let countdown          = CommandlineArgument(long: "countdown",        short: "countdown")        // -countdown
    static let iconSize           = CommandlineArgument(long: "iconSize",         short: "iconSize")         // -iconSize pixels
    static let lockHUD            = CommandlineArgument(long: "lockHUD",          short: "lockHUD")          // -lockHUD
    static let fullScreenIcon     = CommandlineArgument(long: "fullScreenIcon",   short: "fullScreenIcon")   // -fullScreenIcon
    
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
