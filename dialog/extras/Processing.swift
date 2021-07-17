//
//  Processing.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation
import AppKit
import SystemConfiguration
import SwiftUI

class stdOutput: ObservableObject {
    @Published var selectedOption: String = ""
}

public extension Color {

    static let background = Color(NSColor.windowBackgroundColor)
    static let secondaryBackground = Color(NSColor.underPageBackgroundColor)
    static let tertiaryBackground = Color(NSColor.controlBackgroundColor)
}

func getImageFromPath(fileImagePath: String, imgWidth: CGFloat? = .infinity, imgHeight: CGFloat? = .infinity, returnErrorImage: Bool? = false) -> NSImage {
    // accept image as local file path or as URL and return NSImage
    // can pass in width and height as optional values otherwsie return the image as is.
    
    // origional implementation lifted from Nudge and modified
    // https://github.com/macadmins/nudge/blob/main/Nudge/Utilities/Utils.swift#L46
    
    // need to declare literal empty string first otherwsie the runtime whinges about an NSURL instance with an empty URL string. I know!
    var urlPath = NSURL(string: "")!
    var imageData = NSData()
    
    // checking for anything starting with http - crude but it works (for now)
    if fileImagePath.hasPrefix("http") {
        urlPath = NSURL(string: fileImagePath)!
    } else {
        urlPath = NSURL(fileURLWithPath: fileImagePath)
    }
      
    // wrap everything in a try block.IF the URL or filepath is unreadable then return a default wtf image
    do {
        imageData = try NSData(contentsOf: urlPath as URL)
    } catch {
        if returnErrorImage! {
            let errorImageConfig = NSImage.SymbolConfiguration(pointSize: 200, weight: .thin)
            let errorImage = NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil)!
                .withSymbolConfiguration(errorImageConfig)!
            return errorImage
        } else {
        
            quitDialog(exitCode: appvars.exit201.code, exitMessage: "\(appvars.exit201.message) \(fileImagePath)")
        }
    }
  
    let image : NSImage = NSImage(data: imageData as Data)!
    
    if let rep = NSImage(data: imageData as Data)!
        .bestRepresentation(for: NSRect(x: 0, y: 0, width: imgWidth!, height: imgHeight!), context: nil, hints: nil) {
        image.size = rep.size
        image.addRepresentation(rep)
    }
    return image
}

func openSpecifiedURL(urlToOpen: String) {
    // Open the selected URL (no checking is perfoemrd)
    
    if let url = URL(string: urlToOpen) {
        NSWorkspace.shared.open(url)
    }
}

func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    
    return output
}

func buttonAction(action: String, exitCode: Int32, executeShell: Bool) {
    //let action: String = CLOptionText(OptionName: CLOptions.button1ActionOption, DefaultValue: "")
    
    if (action != "") {
        if executeShell {
            print(shell(action))
        } else {
            openSpecifiedURL(urlToOpen: action)
        }
    }
    quitDialog(exitCode: exitCode)
    //exit(0)
}

func getAppIcon(appPath: String, withSize: CGFloat? = 300) -> NSImage {
    // take application path and extracts the application icon and returns is as NSImage
    // Swift implimentation of the ObjC code used in SAP's nice "Icons" utility for extracting application icons
    // https://github.com/SAP/macOS-icon-generator/blob/master/source/Icons/MTDragDropView.m#L66
    
    let image = NSImage()
    if let rep = NSWorkspace.shared.icon(forFile: appPath)
        .bestRepresentation(for: NSRect(x: 0, y: 0, width: withSize!, height: withSize!), context: nil, hints: nil) {
        image.size = rep.size
        image.addRepresentation(rep)
    }
    return image
}

func printVersionString() -> Void {
    //what it says on the tin
    print(getVersionString())
}

func getVersionString() -> String {
    var appVersion: String = appvars.cliversion
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        appVersion = version
    }
    return appVersion
}

func quitDialog(exitCode: Int32, exitMessage: String? = "") {
    if exitMessage != "" {
        //print(exitCode)
        print("\(exitMessage!)")
    }
    // only print if exit code os 0
    if exitCode == 0 && appvars.selectedOption != "" {
        
        if appvars.jsonOut {
            print("{")
            print("\"SelectedOption\" : \"\(appvars.selectedOption)\",")
            print("\"SelectedIndex\" : \(appvars.selectedIndex)")
            print("}")
        } else  {
            print("SelectedOption: \(appvars.selectedOption)")
            print("SelectedIndex: \(appvars.selectedIndex)")
        }
        //if CLOptionPresent(OptionName: CLOptions.dropdownDefault) || appvars.selectedIndex >= 0 {
        //    print("SelectedIndex: \(appvars.selectedIndex)")
        //}
    }
    exit(exitCode)
}

func isValidColourHex(_ hexvalue: String) -> Bool {
    let hexRegEx = "^#([a-fA-F0-9]{6})$"
    let hexPred = NSPredicate(format:"SELF MATCHES %@", hexRegEx)
    return hexPred.evaluate(with: hexvalue)
}

func textToFontWeight(_ weight: String) -> Font.Weight {
    switch weight {
        case "bold":
            return Font.Weight.bold
        case "heavy":
            return Font.Weight.heavy
        case "light":
            return Font.Weight.light
        case "medium":
            return Font.Weight.medium
        case "regular":
            return Font.Weight.regular
        case "thin":
            return Font.Weight.thin
        default:
            return Font.Weight.thin
    }
}

func stringToColour(_ colourValue: String) -> Color {
    
    var returnColor: Color
    
    //let colourHash = String(item[1])
    if isValidColourHex(colourValue) {
        
        // valid hex = #000000 format
    
        let colourRedValue = "\(colourValue[1])\(colourValue[2])"
        let colourRed = Double(Int(colourRedValue, radix: 16)!)/255
        
        let colourGreenValue = "\(colourValue[3])\(colourValue[4])"
        let colourGreen = Double(Int(colourGreenValue, radix: 16)!)/255
        
        let colourBlueValue = "\(colourValue[5])\(colourValue[6])"
        let colourBlue = Double(Int(colourBlueValue, radix: 16)!)/255
        
        returnColor = Color(red: colourRed, green: colourGreen, blue: colourBlue)
        
    } else {
        switch colourValue {
            case "black":
                returnColor = Color.black
            case "blue":
                returnColor = Color.blue
            case "gray":
                returnColor = Color.gray
            case "green":
                returnColor = Color.green
            case "orange":
                returnColor = Color.orange
            case "pink":
                returnColor = Color.pink
            case "purple":
                returnColor = Color.purple
            case "red":
                returnColor = Color.red
            case "white":
                returnColor = Color.white
            case "yellow":
                returnColor = Color.yellow
            default:
                returnColor = Color.primary
        }
    }
    
    return returnColor
    
}

func plistFromData(_ data: Data) throws -> [String:Any] {
    try PropertyListSerialization.propertyList(
        from: data,
        format: nil
    ) as! [String:Any]
}

func isDNDEnabled() -> Bool {
    // check for DND and return true if it is on
    // ** This function will not work under macOS 12 as at July 2021
    let consoleUser = SCDynamicStoreCopyConsoleUser(nil, nil , nil)
    let consoleUserHomeDir = FileManager.default.homeDirectory(forUser: consoleUser! as String)?.path ?? ""
    
    let ncprefsUrl = URL(
        fileURLWithPath: String("\(consoleUserHomeDir)/Library/Preferences/com.apple.ncprefs.plist")
    )
    
    do {
        let prefsList = try plistFromData(try Data(contentsOf: ncprefsUrl))
        let dndPrefsData = prefsList["dnd_prefs"] as! Data
        let dndPrefsList = try plistFromData(dndPrefsData)
        
        if let userPref = dndPrefsList["userPref"] as? [String:Any] {
            return userPref["enabled"] as! Bool
        }
    } catch {
        quitDialog(exitCode: 21, exitMessage: "DND Prefs unavailable")
    }
    return false
}
