//
//  Notifications.swift
//  dialog
//
//  Created by Bart Reardon on 27/9/2022.
//

import Foundation
import UserNotifications
import AppKit
import SwiftUI

func sendNotification(title: String = "", message: String = "", image: String = "") {
    
    let center = UNUserNotificationCenter.current()
    
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if error != nil {
            print("Notifications are not available: \(error?.localizedDescription as Any)")
        }
    }
    
    center.getNotificationSettings { settings in
        guard (settings.authorizationStatus == .authorized) ||
                (settings.authorizationStatus == .provisional) else { return }
                
        if settings.authorizationStatus == .authorized {
            
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            //content.subtitle = "test subtitle"
            
            if image != "" {
                var importedImage : NSImage = NSImage(systemSymbolName: "applelogo", accessibilityDescription: "Apple logo")!

                if image.hasSuffix(".app") || image.hasSuffix("prefPane") {
                    importedImage = getAppIcon(appPath: image)
                } else {
                    importedImage = getImageFromPath(fileImagePath: image)
                }
                                
                // need to save a temp version of the image for the notification to be able to load it
                savePNG(image: importedImage, path: "/var/tmp/sdnotification.png")
                do {
                    let fileURL = URL(fileURLWithPath: "/var/tmp/sdnotification.png")
                    let attachment = try UNNotificationAttachment(identifier: "attachment", url: fileURL)
                    content.attachments = [attachment]
                } catch let error {
                    print(error.localizedDescription)
                }
                
            }
            
            // Create the request
            let uuidString = UUID().uuidString
            let request = UNNotificationRequest(identifier: uuidString,
                        content: content, trigger: nil)

            // Schedule the request with the system.
            center.add(request) { (error) in
               if error != nil {
                   print(error?.localizedDescription as Any)
               }
            }
        }
    }
}
