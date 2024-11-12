//
//  AppVariables.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import SwiftUI

struct AppDefaults {
    let cliversion                      = "2.5.3"
    let launchTime                      = Date.now
    // message default strings
    let titleDefault                    = String("default-title".localized)
    let messageDefault                  = String("default-message".localized)
    let messageAlignmentTextRepresentation = String("left")
    let allignmentStates: [String: TextAlignment] = ["left": .leading,
                                                      "right": .trailing,
                                                      "centre": .center,
                                                      "center": .center]
    let positionStates: [String: Alignment] = ["left": .leading,
                                                      "right": .trailing,
                                                      "centre": .center,
                                                      "center": .center]
    let button1Default                  = String("button-ok".localized)
    let button2Default                  = String("button-cancel".localized)
    let buttonInfoDefault               = String("button-more-info".localized)
    let buttonInfoActionDefault         = String("")

    // Content padding
    let sidePadding                     = CGFloat(15)
    let topPadding                      = CGFloat(10)
    let bottomPadding                   = CGFloat(15)
    let contentPadding                  = CGFloat(8)

    let timerDefaultSeconds             = CGFloat(10)

    let autoPlayDefaultSeconds          = CGFloat(10)

    let defaultStatusLogFile            = String("/var/tmp/dialog.log")

    let argRegex                        = String("(,? ?[a-zA-Z1-9]+=|(,\\s?editor)|(,\\s?fileselect))|(,\\s?passwordfill)|(,\\s?required)|(,\\s?secure)|(,\\s?confirm)")

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
    let exit30                          = (code: Int32(30),  message: String("Key authorisation required"))
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
}

struct AppVariables {

    var messageAlignment: TextAlignment = .leading
    var helpAlignment: TextAlignment = .leading
    var messagePosition: Alignment = .leading
    var systemInfo: [String: String] = getEnvironmentVars()

    var viewOrder: [String] = [
        ViewType.textfile.rawValue,
        ViewType.webcontent.rawValue,
        ViewType.listitem.rawValue,
        ViewType.checkbox.rawValue,
        ViewType.textfield.rawValue,
        ViewType.radiobutton.rawValue,
        ViewType.dropdown.rawValue
    ]

    // button default strings
    // work out how to define a default width button that does what you tell it to. in the meantime, diry hack with spaces
    var button1DefaultAction            = KeyboardShortcut.defaultAction
    var button2DefaultAction            = KeyboardShortcut.cancelAction

    var helpButtonHoverText             = String("help-hover".localized)

    // Window Sizes
    var windowWidth                     = CGFloat(820)      // set default dialog width
    var windowHeight                    = CGFloat(380)      // set default dialog height

    var windowBackgroundColour          = Color.clear


    // Screen Size
    var screenWidth                     = CGFloat(0)
    var screenHeight                    = CGFloat(0)

    var videoWindowWidth                = CGFloat(900)
    var videoWindowHeight               = CGFloat(600)

    var windowPositionVertical          = NSWindow.Position.Vertical.center
    var windowPositionHorozontal        = NSWindow.Position.Horizontal.center
    var windowPositionOffset            = CGFloat(16)

    var windowCloseEnabled              = Bool(true)
    var windowMinimiseEnabled           = Bool(true)
    var windowMaximiseEnabled           = Bool(true)

    var iconWidth                      = CGFloat(150)      // set default image area width
    var iconHeight                     = CGFloat(260)      // set default image area height
    var titleHeight                     = CGFloat(50)
    var bannerHeight                    = CGFloat(-10)

    var scaleFactor                     = CGFloat(1)

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

    var quitAfterProcessingNotifications = true

    var quitKeyCharacter                = String("q")


    // Auth key validation
    var authorised                      = Bool(false)

    // debug flag
    var debugMode                       = Bool(false)
    var debugBorderColour               = Color.clear
}
