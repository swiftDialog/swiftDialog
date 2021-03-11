//
//  appVaribles.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation

var iconVisible: Bool = true

var helpText = """
    Dialog version \(getVersionString()) ©2021 Bart Reardon
    --title             Set the Dialog title - Over 40 characters gets truncated
    
    --message           Set the dialog message
    
    --icon              Set the icon to display
                        pass in path to png or jpg
                        if not specified, default icon will be used
    
    --hideicon          hides the icon from view
                        Doing so increases the space available for message text

    --button1text       Set the label for Button1
                        Default is "OK"
                        Bound to <Enter> key
                        Return code when actioned is 0

    --button1action     Set the action to take.
                        Accepts URL
                        Default action if not specified is no action

    --button2text       Set the label for Button1
                        Default is "Cancel"
                        Bound to <ESC> key
                        Return code when actioned is 2

    --button2action     -- Not Implemented at this time --

    --infobuttontext    Set the label for Information Button
                        If not specified, Info button will not be displayed
                        Return code when actioned is 3

    --infobuttonaction  Set the action to take.
                        Accepts URL
                        Default action if not specified is no action

    --version           Prints the app version
    --help              Prints this text

    --buycoffee         Optionally buy the author a coffee if you would like to
    --showlicense       Display the Software License Agreement for Dialog
    """

struct AppVariables {
    static var windowWidth = CGFloat(750)
    static var windowHeight = CGFloat(350)
 
    static var imageWidth = CGFloat(150)
    static var imageHeight = CGFloat(200)
    
    
    // message defaults
    static var titleDefault = String("Important Message Title")
    static var messageDefault = String("Important Message Content\n\nPlease read")
    
    // button defaults
    static var button1Default = String("    OK    ")
    static var button2Default = String("Cancel")
    static var buttonInfoDefault = String("More Information")
    static var buttonInfoActionDefault = String("")
    
    //static var iconVisible = true
    //static var displayMoreInfo = true // testing
    //static var textAllignment = "centre" //testing
    //static var textAllignment = "top" //testing
    //static var textAllignment = "left" //testing
}

struct AppConstants {
    static let titleOption = String("--title")
    //static let titleOptionBrief = String("-t")
    
    static let messageOption = String("--message")
    //static let messageOptionBrief = String("-m")
    
    static let iconOption = String("--icon")
    //static let iconOptionBrief = String("-i")
    
    static let button1TextOption = String("--button1text")
    static let button1ActionOption = String("--button1action")
    static let button2TextOption = String("--button2text")
    static let button2ActionOption = String("--button2action")
    
    static let buttonInfoTextOption = String("--infobuttontext")
    static let buttonInfoActionOption = String("--infobuttonaction")
    
    //static let messageTextAllignment = String("--textallignment")
    
    // command line options that take no additional parameters
    static let getVersion = String("--version")
    static let hideIcon = String("--hideicon")
    static let helpOption = String("--help")
    static let demoOption = String("--demo")
    static let buyCoffee = String("--buycoffee")
    static let showLicense = String("--showlicense")
}
