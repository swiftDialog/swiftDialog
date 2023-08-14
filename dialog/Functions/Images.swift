//
//  Images.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import AppKit

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
