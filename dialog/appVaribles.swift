//
//  appVaribles.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation

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
    
    static var iconVisible = true
    static var displayMoreInfo = true // testing
    //static var textAllignment = "centre" //testing
    //static var textAllignment = "top" //testing
    static var textAllignment = "left" //testing
}

struct AppConstants {
    static let titleOption = String("--title")
    static let titleOptionBrief = String("-t")
    
    static let messageOption = String("--message")
    static let messageOptionBrief = String("-m")
    
    static let iconOption = String("--icon")
    static let iconOptionBrief = String("-i")
    
    static let button1TextOption = String("--button1text")
    static let button1ActionOption = String("--button1action")
    static let button2TextOption = String("--button2text")
    static let button2ActionOption = String("--button2action")
    
    static let buttonInfoTextOption = String("--infobuttontext")
    static let buttonInfoActionOption = String("--infobuttonaction")
    
    static let messageTextAllignment = String("--textallignment")
    
}
