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

func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // Forground notifications.
    completionHandler([.banner, .sound])
}

func sendNotification(title: String = "", subtitle: String = "", message: String = "", image: String = "") {
    
    
    let tempImagePath : String = "/var/tmp/sdnotification.png"
    
    let notification = UNUserNotificationCenter.current()
    notification.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            print("Notifications are not available: \(error.localizedDescription as Any)")
            print("Check to see if Notifications for Dialog.app are enabled in notification center")
        }
    }
    
    notification.getNotificationSettings { settings in
        guard (settings.authorizationStatus == .authorized) ||
                  (settings.authorizationStatus == .provisional) else { return }
        
        switch settings.authorizationStatus {
            case .authorized:
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.subtitle = subtitle
                content.categoryIdentifier = "DIALOG_NOTIFICATION"

                if image != "" {
                    // default image just in case
                    var importedImage : NSImage = NSImage(systemSymbolName: "applelogo", accessibilityDescription: "Apple logo")!

                    if image.hasSuffix(".app") || image.hasSuffix("prefPane") {
                        importedImage = getAppIcon(appPath: image)
                    } else if image.lowercased().hasPrefix("sf=") {
                        let imageConfig = NSImage.SymbolConfiguration(pointSize: 128, weight: .thin)
                        importedImage = NSImage(systemSymbolName: String(image.dropFirst(3)), accessibilityDescription: "SF Symbol")!
                            .withSymbolConfiguration(imageConfig)!
                    } else {
                        importedImage = getImageFromPath(fileImagePath: image, returnErrorImage: true)
                    }
                    
                    // need to save a temp version of the image for the notification to be able to load it
                    savePNG(image: importedImage, path: tempImagePath)
                    do {
                        let fileURL = URL(fileURLWithPath: tempImagePath)
                        let attachment = try UNNotificationAttachment(identifier: "AttachedContent", url: fileURL)
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
                notification.add(request) { (error) in
                   if error != nil {
                       print(error?.localizedDescription as Any)
                   }
                }
            case .provisional:
                print("Notification authorisation is provisional")
            case .denied:
                print("Notification authorisation is denied")
            case .notDetermined:
                print("Notification authorisation cannot be determined")
            default:
                print("Notifications aren't authorised")
        }
    }
}
