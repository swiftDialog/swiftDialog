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

struct Utils {

    public func createImageData(fileImagePath: String) -> NSImage {
        let urlPath = NSURL(fileURLWithPath: fileImagePath)
        var imageData = NSData()
        
        do {
            imageData = try NSData(contentsOf: urlPath as URL)
        } catch {
            let errorImageConfig = NSImage.SymbolConfiguration(pointSize: 200, weight: .regular)
            return NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil)!.withSymbolConfiguration(errorImageConfig)!
        }

        let image : NSImage = NSImage(data: imageData as Data)!
        if let rep = NSImage(data: imageData as Data)!
            .bestRepresentation(for: NSRect(x: 0, y: 0, width: AppVariables.imageWidth, height: AppVariables.imageHeight), context: nil, hints: nil) {
            image.size = rep.size
            image.addRepresentation(rep)
        }
        
        return image
    }
    
    // merge getImageFromHTTPURL and createImageData, they are practically the same
    public func getImageFromHTTPURL(fileURLString: String) -> NSImage {
        let fileURL = URL(string: fileURLString)
        var imageData = NSData()

        do {
            imageData = try NSData(contentsOf: fileURL! as URL)
        } catch {
            let errorImageConfig = NSImage.SymbolConfiguration(pointSize: 200, weight: .regular)
            return NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil)!.withSymbolConfiguration(errorImageConfig)!
        }
        
        let image : NSImage = NSImage(data: imageData as Data)!
        if let rep = NSImage(data: imageData as Data)!
            .bestRepresentation(for: NSRect(x: 0, y: 0, width: AppVariables.imageWidth, height: AppVariables.imageHeight), context: nil, hints: nil) {
            image.size = rep.size
            image.addRepresentation(rep)
        }
        
        return image
    }
}

func openSpecifiedURL(urlToOpen: String) {
    if let url = URL(string: urlToOpen) {
        NSWorkspace.shared.open(url)
    }
}

func printVersionString() -> Void {
       print(getVersionString())
}

func getVersionString() -> String {
    var appVersion: String = "0.0"
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        appVersion = version
    }
    return appVersion
}

func getAppIcon(appPath : String, withSize : CGFloat) -> NSImage {
    let image = NSImage()
    
    if let rep = NSWorkspace.shared.icon(forFile: appPath)
        .bestRepresentation(for: NSRect(x: 0, y: 0, width: withSize, height: withSize), context: nil, hints: nil) {
        image.size = rep.size
        image.addRepresentation(rep)
    }
    return image
}
