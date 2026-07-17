//
//  Images.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI
import UniformTypeIdentifiers

/// Synchronous data fetch bounded by a timeout so a slow or unreachable host can't
/// stall the calling thread indefinitely. Returns nil on error or timeout.
func fetchDataWithTimeout(from url: URL, timeout: TimeInterval) -> Data? {
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    var result: Data?
    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, _, _ in
        result = data
        semaphore.signal()
    }.resume()
    if semaphore.wait(timeout: .now() + timeout + 1) == .timedOut {
        writeLog("Timed out fetching \(url.absoluteString)", logLevel: .error)
        return nil
    }
    return result
}

func getImageFromPath(fileImagePath: String, imgWidth: CGFloat? = .infinity, imgHeight: CGFloat? = .infinity, returnErrorImage: Bool? = false, errorImageName: String? = "questionmark.square.dashed") -> NSImage {
    // accept image as local file path or as URL and return NSImage
    // can pass in width and height as optional values otherwsie return the image as is.

    // origional implementation lifted from Nudge and modified
    // https://github.com/macadmins/nudge/blob/main/Nudge/Utilities/Utils.swift#L46

    writeLog("Getting image from path \(fileImagePath)")

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

    // Fetch the image data. Remote URLs use a bounded fetch so a slow or unreachable
    // host can't stall the run loop; local files are read directly. On failure, return
    // the error image or exit, exactly as before.
    if fileImagePath.hasPrefix("http") {
        writeLog("Getting image from http")
        guard let httpURL = URL(string: fileImagePath),
              let data = fetchDataWithTimeout(from: httpURL, timeout: 10) else {
            writeLog("Could not load image from \(fileImagePath)", logLevel: .error)
            if returnErrorImage! {
                return errorImage
            }
            quitDialog(exitCode: appDefaults.exit201.code, exitMessage: "\(appDefaults.exit201.message) \(fileImagePath)", observedObject: DialogUpdatableContent())
            return errorImage
        }
        imageData = data as NSData
    } else {
        do {
            imageData = try NSData(contentsOf: URL(fileURLWithPath: fileImagePath))
        } catch {
            if returnErrorImage! {
                writeLog("An error occurred - returning error image")
                return errorImage
            }
            writeLog("An error occurred - exiting")
            quitDialog(exitCode: appDefaults.exit201.code, exitMessage: "\(appDefaults.exit201.message) \(fileImagePath)", observedObject: DialogUpdatableContent())
            return errorImage
        }
    }

    // Decode the image data once (the original decoded it twice).
    guard let image = NSImage(data: imageData as Data) else {
        return errorImage
    }

    if let rep = image.bestRepresentation(for: NSRect(x: 0, y: 0, width: imgWidth!, height: imgHeight!), context: nil, hints: nil) {
        image.size = rep.size
        image.addRepresentation(rep)
    }
    writeLog("Returning image")
    return image
}

func getImageFromBase64(base64String: String) -> NSImage {
    let fallback = NSImage(systemSymbolName: "applelogo", accessibilityDescription: nil) ?? NSImage()
    guard let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
          let image = NSImage(data: imageData) else {
        writeLog("Could not decode base64 image data; using fallback image", logLevel: .error)
        return fallback
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
    guard let tiff = image.tiffRepresentation,
          let pngData = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
        writeLog("Could not convert image to PNG for \(path)", logLevel: .error)
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
    } catch {
        writeLog("Failed to write PNG to \(path): \(error.localizedDescription)", logLevel: .error)
    }
}

func generateQRCode(from string: String, withSize: CGFloat? = 300) -> NSImage {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    let size = NSSize(width: withSize!, height: withSize!)
    filter.message = Data(string.utf8)

    if let outputImage = filter.outputImage {
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return NSImage(cgImage: cgImage, size: size)
        }
    }

    return NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "") ?? NSImage()
}

func setAppIcon(named name: String) {
    let iconImage = getImageFromPath(fileImagePath: name)
    NSWorkspace.shared.setIcon(iconImage, forFile: Bundle.main.bundlePath)

    // Also update the icons of the embedded notifier helper apps
    let helpersURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        .appending(path: "Contents/Helpers", directoryHint: .isDirectory)
    let notifierApps = (try? FileManager.default.contentsOfDirectory(atPath: helpersURL.path)) ?? []
    for appName in notifierApps where appName.hasSuffix(".app") {
        let appPath = helpersURL.appending(path: appName).path
        NSWorkspace.shared.setIcon(iconImage, forFile: appPath)
    }
}
