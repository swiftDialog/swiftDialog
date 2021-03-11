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
        let imageData:NSData = NSData(contentsOf: urlPath as URL)!
        return NSImage(data: imageData as Data)!
    }
    
}

func openSpecifiedURL(urlToOpen: String) {
    if let url = URL(string: urlToOpen) {
        NSWorkspace.shared.open(url)
    }
}

func printVersionString() -> Void {
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
       print(version)
   }
}
