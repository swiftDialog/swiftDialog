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
import OSLog
import SwiftyJSON


func writeLog(_ message: String, logLevel: OSLogType = .info, log: OSLog = osLog) {
    let logMessage = "\(message)"

    os_log("%{public}@", log: log, type: logLevel, logMessage)
    if logLevel == .debug || appvars.debugMode {
        // print debug to stdout
        print("\(oslogTypeToString(logLevel).uppercased()): \(message)")
    }
}

func oslogTypeToString(_ type: OSLogType) -> String {
    switch type {
    case OSLogType.default: return "default"
    case OSLogType.info: return "info"
    case OSLogType.debug: return "debug"
    case OSLogType.error: return "error"
    case OSLogType.fault: return "fault"
    default: return "unknown"
    }
}

func string2float(string: String, defaultValue: CGFloat = 0) -> CGFloat {
    // take a umber in scring format and return a float
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .decimal

    var number: CGFloat?
    if let num = numberFormatter.number(from: string) {
        number = CGFloat(truncating: num)
    } else {
        numberFormatter.locale = Locale(identifier: "en")
        if let num = numberFormatter.number(from: string) {
            number = CGFloat(truncating: num)
        }
    }
    return number ?? defaultValue
}

func getImageFromPath(fileImagePath: String, imgWidth: CGFloat? = .infinity, imgHeight: CGFloat? = .infinity, returnErrorImage: Bool? = false, errorImageName: String? = "questionmark.square.dashed") -> NSImage {
    // accept image as local file path or as URL and return NSImage
    // can pass in width and height as optional values otherwsie return the image as is.

    // origional implementation lifted from Nudge and modified
    // https://github.com/macadmins/nudge/blob/main/Nudge/Utilities/Utils.swift#L46

    writeLog("Getting image from path \(fileImagePath)")

    // need to declare literal empty string first otherwsie the runtime whinges about an NSURL instance with an empty URL string. I know!
    var urlPath = NSURL(string: "")!
    var imageData = NSData()

    let errorImageConfig = NSImage.SymbolConfiguration(pointSize: 200, weight: .thin)
    var errorImage = NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil)!
        .withSymbolConfiguration(errorImageConfig)!

    if errorImageName == "banner" {
        errorImage = bannerErrorImage(size: NSSize(width: 800, height: 100))!
    }

    // check if it's base64 image data
    if fileImagePath.hasPrefix("base64") {
        writeLog("Creating image from base64 data")
        return getImageFromBase64(base64String: fileImagePath.replacingOccurrences(of: "base64=", with: ""))
    }

    // checking for anything starting with http - crude but it works (for now)
    if fileImagePath.hasPrefix("http") {
        writeLog("Getting image from http")
        urlPath = NSURL(string: fileImagePath)!
    } else {
        urlPath = NSURL(fileURLWithPath: fileImagePath)
    }

    // wrap everything in a try block.IF the URL or filepath is unreadable then return a default wtf image
    do {
        imageData = try NSData(contentsOf: urlPath as URL)
    } catch {
        if returnErrorImage! {
            writeLog("An error occured - returning error image")
            return errorImage
        } else {
            writeLog("An error occured - exiting")
            quitDialog(exitCode: appvars.exit201.code, exitMessage: "\(appvars.exit201.message) \(fileImagePath)", observedObject: DialogUpdatableContent())
        }
    }

    let image: NSImage = NSImage(data: imageData as Data) ?? errorImage

    if let rep = NSImage(data: imageData as Data)?
        .bestRepresentation(for: NSRect(x: 0, y: 0, width: imgWidth!, height: imgHeight!), context: nil, hints: nil) {
        image.size = rep.size
        image.addRepresentation(rep)
    }
    writeLog("Returning image")
    return image
}

func getImageFromBase64(base64String: String) -> NSImage {
    var image = NSImage(systemSymbolName: "applelogo", accessibilityDescription: nil)!
    if let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) {
        image = NSImage(data: imageData)!
    }
    return image
}

func bannerErrorImage(size: NSSize) -> NSImage? {
    // Create a yellow-to-orange gradient
        let gradient = NSGradient(starting: NSColor.red, ending: NSColor.orange)

        // Create an NSImage with the specified size and add a bitmap representation
        let image = NSImage(size: size)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)
        image.addRepresentation(rep!)

        // Create a new graphics context and set it as the current context
        let graphicsContext = NSGraphicsContext(bitmapImageRep: rep!)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        // Draw the gradient background in the image
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 30.0)

        // Draw the "questionmark.square.dashed" system symbol in the image
        if let symbolImage = NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil) {
            symbolImage.isTemplate = true // Set the template mode to draw in black
            let symbolSize = NSSize(width: size.height * 0.8, height: size.height * 0.8)
            let symbolOrigin = NSPoint(x: (size.width - symbolSize.width) / 2, y: (size.height - symbolSize.height) / 2)
            symbolImage.draw(in: NSRect(origin: symbolOrigin, size: symbolSize))
        }

        // Restore the previous graphics state and return the image
        NSGraphicsContext.restoreGraphicsState()
        return image
}

func openSpecifiedURL(urlToOpen: String) {
    // Open the selected URL (no checking is performed)
    writeLog("Opening URL \(urlToOpen)")
    if let url = URL(string: urlToOpen) {
        NSWorkspace.shared.open(url)
    }
}

func shell(_ command: String) -> String {
    writeLog("Running shell command \(command)")
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

// taken wholesale from DEPNotify because Joel and team and jsut awesome so why re-invent the wheel?
func checkRegexPattern(regexPattern: String, textToValidate: String) -> Bool {
    var returnValue = true
    writeLog("Checking regex")
    do {
        let regex = try NSRegularExpression(pattern: regexPattern)
        let nsString = textToValidate as NSString
        let results = regex.matches(in: textToValidate, range: NSRange(location: 0, length: nsString.length))

        if results.count == 0 {
            returnValue = false
        }

    } catch let error as NSError {
        writeLog("invalid regex: \(error.localizedDescription)")
        returnValue = false
    }

    return  returnValue
}

func buttonAction(action: String, exitCode: Int32, executeShell: Bool, shouldQuit: Bool = true, observedObject: DialogUpdatableContent) {
    writeLog("processing button action \(action)")
    if action != "" {
        if executeShell {
            print(shell(action))
        } else {
            openSpecifiedURL(urlToOpen: action)
        }
    }
    if shouldQuit {
        quitDialog(exitCode: exitCode, observedObject: observedObject)
    }
}

func getAppIcon(appPath: String, withSize: CGFloat? = 300) -> NSImage {
    // take application path and extracts the application icon and returns is as NSImage
    // Swift implimentation of the ObjC code used in SAP's nice "Icons" utility for extracting application icons
    // https://github.com/SAP/macOS-icon-generator/blob/master/source/Icons/MTDragDropView.m#L66
    writeLog("Getting app icon image from \(appPath)")
    let image = NSImage()
    if let rep = NSWorkspace.shared.icon(forFile: appPath)
        .bestRepresentation(for: NSRect(x: 0, y: 0, width: withSize!, height: withSize!), context: nil, hints: nil) {
        image.size = rep.size
        image.addRepresentation(rep)
    }
    return image
}

func printVersionString() {
    //what it says on the tin
    print(getVersionString())
}

func getVersionString() -> String {
    var appVersion: String = appvars.cliversion
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion = "\(version).\(build)"
        } else {
            appVersion = version
        }
    }
    return appVersion
}

func quitDialog(exitCode: Int32, exitMessage: String? = "", observedObject: DialogUpdatableContent? = nil) {
    writeLog("About to quit with exit code \(exitCode)")
    if exitMessage != "" {
        print("\(exitMessage!)")
    }

    // force quit
    if exitCode == 255 {
        exit(0)
    }

    // only print if exit code os 0
    if exitCode == 0 {

        // build json using SwiftyJSON
        var json = JSON()

        //build output array
        var outputArray: Array = [String]()
        var dontQuit = false
        var requiredString = ""

        if appArguments.textField.present {
            writeLog("Textfield present - checking requirements are met")
            // check to see if fields marked as required have content before allowing the app to exit
            // if there is an empty field, update the highlight colour

            for index in 0..<(observedObject?.appProperties.textFields.count ?? 0) {
                //check for required fields
                let textField = observedObject?.appProperties.textFields[index]
                let textfieldValue = textField?.value ?? ""
                let textfieldTitle = textField?.title ?? ""
                let textfieldRequired = textField?.required ?? false
                observedObject?.appProperties.textFields[index].requiredTextfieldHighlight = Color.clear

                if textfieldRequired && textfieldValue == "" { // && textFields[index].regex.isEmpty {
                    NSSound.beep()
                    requiredString += "• \"\(textfieldTitle)\" \("is-required".localized) \n"
                    observedObject?.appProperties.textFields[index].requiredTextfieldHighlight = Color.red
                    dontQuit = true
                    writeLog("Required text field \(textfieldTitle) has no value")

                //check for regex requirements
                } else if !(textfieldValue.isEmpty)
                            && !(textField?.regex.isEmpty ?? false)
                            && !checkRegexPattern(regexPattern: textField?.regex ?? "", textToValidate: textfieldValue) {
                    NSSound.beep()
                    observedObject?.appProperties.textFields[index].requiredTextfieldHighlight = Color.green
                    requiredString += "• "+(textField?.regexError ?? "Regex Check Failed  \n")
                    dontQuit = true
                    writeLog("Textfield \(textfieldTitle) value \(textfieldValue) does not meet regex requirements \(String(describing: textField?.regex))")
                }

                outputArray.append("\(textfieldTitle) : \(textfieldValue)")
                json[textfieldTitle].string = textfieldValue
            }
        }

        if observedObject?.args.dropdownValues.present != nil {
            writeLog("Select items present - checking require,ments are met")
            if observedObject?.appProperties.dropdownItems.count == 1 {
                let selectedValue = observedObject?.appProperties.dropdownItems[0].selectedValue
                let selectedIndex = observedObject?.appProperties.dropdownItems[0].values

                outputArray.append("\"SelectedOption\" : \"\(selectedValue ?? "")\"")
                json["SelectedOption"].string = selectedValue
                outputArray.append("\"SelectedIndex\" : \(selectedIndex?.firstIndex(of: (selectedValue)!) ?? -1)")
                json["SelectedIndex"].int = selectedIndex?.firstIndex(of: selectedValue ?? "") ?? -1
            }
            // check to see if fields marked as required have content before allowing the app to exit
            // if there is an empty field, update the highlight colour
            for index in 0..<(observedObject?.appProperties.dropdownItems.count ?? 0) {
                let dropdownItem = observedObject?.appProperties.dropdownItems[index]
                let dropdownItemValues = dropdownItem?.values ?? [""]
                let dropdownItemSelectedValue = dropdownItem?.selectedValue ?? ""
                let dropdownItemTitle = dropdownItem?.title ?? ""
                let dropdownItemRequired = dropdownItem?.required ?? false
                observedObject?.appProperties.dropdownItems[index].requiredfieldHighlight = Color.clear

                if dropdownItemRequired && dropdownItemSelectedValue == "" {
                    NSSound.beep()
                    requiredString += "• \"\(dropdownItemTitle)\" \("is-required".localized) \n"
                    observedObject?.appProperties.dropdownItems[index].requiredfieldHighlight = Color.red
                    dontQuit = true
                    writeLog("Required select item \(dropdownItemTitle) has no value")
                } else {
                    outputArray.append("\"\(dropdownItemTitle)\" : \"\(dropdownItemSelectedValue)\"")
                    outputArray.append("\"\(dropdownItemTitle)\" index : \"\(dropdownItemValues.firstIndex(of: dropdownItemSelectedValue) ?? -1)\"")
                    json[dropdownItemTitle] = ["selectedValue": dropdownItemSelectedValue, "selectedIndex": dropdownItemValues.firstIndex(of: dropdownItemSelectedValue) ?? -1]
                }
            }
        }

        if dontQuit {
            writeLog("Requirements were not met. Dialog will not quit at this time")
            observedObject?.sheetErrorMessage = requiredString
            observedObject?.showSheet = true
            return
        }

        if observedObject?.args.checkbox.present != nil {
            for index in 0..<(observedObject?.appProperties.checkboxArray.count ?? 0) {
                outputArray.append("\"\(observedObject?.appProperties.checkboxArray[index].label ?? "checkbox \(index)")\" : \"\(observedObject?.appProperties.checkboxArray[index].checked ?? false)\"")
                json[observedObject?.appProperties.checkboxArray[index].label ?? 0].boolValue = observedObject?.appProperties.checkboxArray[index].checked ?? false
            }
        }

        // print the output
        if observedObject?.args.jsonOutPut.present ?? false {
            print(json)
        } else {
            for index in 0..<outputArray.count {
                print(outputArray[index])
            }
        }
    }
    exit(exitCode)
}

func isValidColourHex(_ hexvalue: String) -> Bool {
    let hexRegEx = "^#([a-fA-F0-9]{6})$"
    let hexPred = NSPredicate(format: "SELF MATCHES %@", hexRegEx)
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

    if isValidColourHex(colourValue) {

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
        case "mint":
            if #available(macOS 12.0, *) {
                returnColor = Color.mint
            } else {
                returnColor = Color.init(red: 90, green: 196, blue: 198)
            }
        case "cyan":
            if #available(macOS 12.0, *) {
                returnColor = Color.cyan
            } else {
                returnColor = Color.init(red: 114, green: 187, blue: 235)
            }
        case "indigo":
            if #available(macOS 12.0, *) {
                returnColor = Color.indigo
            } else {
                returnColor = Color.init(red: 88, green: 86, blue: 207)
            }
        case "teal":
            if #available(macOS 12.0, *) {
                returnColor = Color.teal
            } else {
                returnColor = Color.init(red: 110, green: 171, blue: 193)
            }
        default:
            returnColor = Color.primary
        }
    }

    return returnColor

}

func colourToString(color: Color) -> String {
    let components = color.cgColor?.components
    let red: CGFloat = components?[0] ?? 0.0
    let green: CGFloat = components?[1] ?? 0.0
    let blue: CGFloat = components?[2] ?? 0.0

    let hexString = String.init(format: "#%02lX%02lX%02lX", lroundf(Float(red * 255)), lroundf(Float(green * 255)), lroundf(Float(blue * 255)))
    return hexString
 }

func plistFromData(_ data: Data) throws -> [String: Any] {
    try PropertyListSerialization.propertyList(
        from: data,
        format: nil
    ) as! [String: Any]
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

        if let userPref = dndPrefsList["userPref"] as? [String: Any] {
            return userPref["enabled"] as! Bool
        }
    } catch {
        quitDialog(exitCode: 21, exitMessage: "DND Prefs unavailable", observedObject: DialogUpdatableContent())
    }
    return false
}


func savePNG(image: NSImage, path: String) {
    // from https://gist.github.com/WilliamD47/e0a2a02b5e32018139a47f5e53ff3bb4
    let imageRep = NSBitmapImageRep(data: image.tiffRepresentation!)
    let pngData = imageRep?.representation(using: .png, properties: [:])
    do {
        try pngData!.write(to: URL(fileURLWithPath: path))
    } catch {
        print(error)
    }
}

func getVideoStreamingURLFromID(videoid: String, autoplay: Bool = false) -> String {
    var fullURL: String = videoid
    switch videoid.components(separatedBy: "=").first!.lowercased() {
    case "youtubeid":
        writeLog("Youtube ID detected")
        let youTubeID = videoid.replacingOccurrences(of: "youtubeid=", with: "")
        let youtubeURL = "https://www.youtube.com/embed/\(youTubeID)?autoplay=\(autoplay ? 1 : 0)&controls=0&showinfo=0"
        fullURL = youtubeURL
    case "vimeoid":
        let vimeoID = videoid.replacingOccurrences(of: "vimeoid=", with: "")
        let vimeoURL = "https://player.vimeo.com/video/\(vimeoID)\(vimeoID.contains("?") ? "&" : "?")autoplay=\(autoplay ? 1 : 0)&controls=\(autoplay ? 0 : 1)"
        fullURL = vimeoURL
    default:
        break
    }
    writeLog("video url is \(fullURL)")
    return fullURL
}
