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

func checkNotificationAuthorisation(notificationPresent: Bool) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
        if let error = error {
            if notificationPresent {
                writeLog(error.localizedDescription, logLevel: .error)
            }
            return
        }
    }
}

func checkForDialogNotificationMode(_ arguments: CommandLineArguments) -> Bool {
    // check if we are sending a notification
    if arguments.notification.present {
        writeLog("Sending a notification")

        var notificationIcon = ""
        if appArguments.iconOption.present {
            notificationIcon = appArguments.iconOption.value
        }

        var acceptActionLabel: String = ""
        var declineActionLabel: String = ""
        if arguments.button1TextOption.present {
            acceptActionLabel = arguments.button1TextOption.value
        }
        if arguments.button2TextOption.present {
            declineActionLabel = arguments.button2TextOption.value
        }
        sendNotification(title: arguments.titleOption.value,
                         subtitle: arguments.subTitleOption.value,
                         message: arguments.messageOption.value,
                         image: notificationIcon,
                         acceptString: acceptActionLabel,
                         acceptAction: arguments.button1ActionOption.value,
                         declineString: declineActionLabel,
                         declineAction: arguments.button2ActionOption.value,
                         notificationSoundEnabled: arguments.notificationGoPing.present)
        usleep(100000)
    }
    return arguments.notification.present
}

func sendNotification(title: String = "",
                      subtitle: String = "",
                      message: String = "",
                      image: String = "",
                      acceptString: String = "Open",
                      acceptAction: String = "",
                      declineString: String = "Close",
                      declineAction: String = "",
                      notificationSoundEnabled: Bool = false) {
    let notification = UNUserNotificationCenter.current()
    let tempImagePath: String = "/var/tmp/sdnotification.png"
    // Define the custom actions.
    let acceptActionLabel = UNNotificationAction(identifier: "ACCEPT_ACTION_LABEL",
        title: acceptString,
        options: [])
    let declineActionLabel = UNNotificationAction(identifier: "DECLINE_ACTION_LABEL",
        title: declineString,
        options: [])
    var actions: [UNNotificationAction] = []

    if !acceptString.isEmpty {
        actions.append(acceptActionLabel)
    }
    if !declineString.isEmpty {
        actions.append(declineActionLabel)
    }

    if !image.isEmpty {
        // default image just in case
        var importedImage: NSImage = NSImage(systemSymbolName: "applelogo", accessibilityDescription: "Apple logo")!

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
    }

    // Define the notification type
    let sdCategory =
          UNNotificationCategory(identifier: "SD_NOTIFICATION",
          actions: actions,
          intentIdentifiers: [],
          hiddenPreviewsBodyPlaceholder: "",
                                 options: .customDismissAction)

    notification.setNotificationCategories([sdCategory])

    notification.getNotificationSettings { settings in
        guard (settings.authorizationStatus == .authorized) ||
                  (settings.authorizationStatus == .provisional) else { return }

        switch settings.authorizationStatus {
            case .authorized:
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.subtitle = subtitle
                content.userInfo = ["ACCEPT_ACTION": acceptAction,
                                "DECLINE_ACTION": declineAction ]
                content.categoryIdentifier = "SD_NOTIFICATION"
                if notificationSoundEnabled {
                    content.sound = UNNotificationSound.default
                }
                content.attachments = []
                // Add any Attachments
                if !image.isEmpty {
                    do {
                        let fileURL = URL(fileURLWithPath: tempImagePath)
                        let attachment = try UNNotificationAttachment(identifier: "AttachedContent", url: fileURL, options: .none)
                        content.attachments = [attachment]
                    } catch let error {
                        writeLog(error.localizedDescription, logLevel: .error)
                    }
                }

                // Create the request
                //let uuidString = UUID().uuidString
                let request = UNNotificationRequest(identifier: UUID().uuidString,
                            content: content, trigger: nil)

                // Schedule the request with the system.
                notification.add(request) { (error) in
                   if error != nil {
                       print(error?.localizedDescription ?? "Notification error")
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

func processNotification(response: UNNotificationResponse) {
    // Get action items from the notification

    let userInfo = response.notification.request.content.userInfo
    let acceptAction = userInfo["ACCEPT_ACTION"] as! String
    let declineAction = userInfo["DECLINE_ACTION"] as! String

    writeLog("acceptAction: \(acceptAction)")
    writeLog("declineAction: \(acceptAction)")

    switch response.actionIdentifier {
    case "ACCEPT_ACTION_LABEL", UNNotificationDefaultActionIdentifier:
        writeLog("user accepted", logLevel: .debug)
        notificationAction(acceptAction)

    case "DECLINE_ACTION_LABEL":
        writeLog("user declined", logLevel: .debug)
        notificationAction(declineAction)

    case UNNotificationDismissActionIdentifier:
        writeLog("notification was dismissed. doing nothing", logLevel: .debug)

    default:
       break
    }

}

func notificationAction(_ action: String) {
    writeLog("processing notification action \(action)")
    if action.contains("://") {
        openSpecifiedURL(urlToOpen: action)
    } else {
        _ = shell(action)
    }
}
