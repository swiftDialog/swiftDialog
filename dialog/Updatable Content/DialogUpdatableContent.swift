//
//  TrackProgress.swift
//  file watch test
//
//  Created by Bart Reardon on 13/1/2022.
//
// concept and execution apropriated from depNotify

import Foundation
import SwiftUI
import Combine
import OSLog

enum StatusState {
    case start
    case done
}

// swiftlint:disable force_try
class StandardError: TextOutputStream {
  func write(_ string: String) {
    try! FileHandle.standardError.write(contentsOf: Data(string.utf8))
  }
}
// swiftlint:enable force_try

class FileReader {
    /// Provided by Joel Rennich

    @ObservedObject var observedData: DialogUpdatableContent
    let fileURL: URL
    var fileHandle: FileHandle?
    var dataAvailable: NSObjectProtocol?
    var dataReady: NSObjectProtocol?

    init(observedData: DialogUpdatableContent, fileURL: URL) {
        self.observedData = observedData
        self.fileURL = fileURL
    }

    deinit {
        try? self.fileHandle?.close()
    }

    func monitorFile() throws {
            //print("mod date is less than now")
        //}

        /*

         if getModificationDateOf(self.fileURL) > Date.now {
         }
         */

        try self.fileHandle = FileHandle(forReadingFrom: fileURL)
        if let data = try? self.fileHandle?.readToEnd() {
            parseAndPrint(data: data)
        }
        fileHandle?.waitForDataInBackgroundAndNotify()

        dataAvailable = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: self.fileHandle, queue: nil) { _ in
            if let data = self.fileHandle?.availableData,
               data.count > 0 {
                self.parseAndPrint(data: data)
                self.fileHandle?.waitForDataInBackgroundAndNotify()
            } else {
                // something weird happened. let's re-load the file
                NotificationCenter.default.removeObserver(self.dataAvailable as Any)
                do {
                    try self.monitorFile()
                } catch {
                    writeLog("Error: \(error.localizedDescription)", logLevel: .error)
                }
            }

        }

        dataReady = NotificationCenter.default.addObserver(forName: Process.didTerminateNotification,
                                                           object: self.fileHandle, queue: nil) { _ in
                                                            NSLog("Task terminated!")
            NotificationCenter.default.removeObserver(self.dataReady as Any)
        }
    }

    private func parseAndPrint(data: Data) {
        if let str = String(data: data, encoding: .utf8) {
            for line in str.components(separatedBy: .newlines) {
                let command = line.trimmingCharacters(in: .newlines)
                if command == "" {
                    continue
                }
                processCommands(commands: command)
            }
        }
    }

    private func processWindow() {
        placeWindow(observedData.mainWindow ?? NSApp.windows[0], size: CGSize(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight+28),
            vertical: observedData.appProperties.windowPositionVertical,
            horozontal: observedData.appProperties.windowPositionHorozontal,
            offset: observedData.args.positionOffset.value.floatValue())
    }

    private func writeToLog(_ message: String, logLevel: OSLogType = .info) {
        writeLog("COMMAND: \(message)", logLevel: logLevel)
    }

    private func processListItems(_ argument: String) {
        var title: String = ""
        var subtitle: String = ""
        var icon: String = ""
        var statusText: String = ""
        var statusIcon: String = ""
        let statusTypeArray = ["wait","success","fail","error","pending","progress"]
        var listProgressValue: CGFloat = 0
        var deleteRow: Bool = false
        var addRow: Bool = false

        var subTitleIsSet: Bool = false
        var iconIsSet: Bool = false
        var statusIsSet: Bool = false
        var statusTextIsSet: Bool = false
        var progressIsSet: Bool = false

        // Check for the origional way of doign things
        let listItemStateArray = argument.components(separatedBy: ": ")
        if listItemStateArray.count > 0 {
            writeToLog("processing list items the old way")
            title = listItemStateArray.first!
            statusIcon = listItemStateArray.last!
            // if using the new method, these will not be set as the title value won't match the ItemValue
            if let row = userInputState.listItems.firstIndex(where: {$0.title == title}) {
                if statusTypeArray.contains(statusIcon) {
                    userInputState.listItems[row].statusIcon = statusIcon
                    userInputState.listItems[row].statusText = ""
                } else {
                    userInputState.listItems[row].statusIcon = ""
                    userInputState.listItems[row].statusText = statusIcon
                }
                observedData.listItemUpdateRow = row
                return
            }
        }

        // And now for the new way
        let commands = argument.components(separatedBy: ",")

        if commands.count > 0 {
            writeToLog("processing list items")
            for command in commands {
                let action = command.components(separatedBy: ": ")
                switch action[0].lowercased().trimmingCharacters(in: .whitespaces) {
                    case "index":
                        if let index = Int(action[1].trimmingCharacters(in: .whitespaces)) {
                            if index >= 0 && index < userInputState.listItems.count {
                                title = userInputState.listItems[index].title
                            }
                        }
                    case "title":
                        title = action[1].trimmingCharacters(in: .whitespaces)
                    case "subtitle":
                        subtitle = action[1].trimmingCharacters(in: .whitespaces)
                        subTitleIsSet = true
                    case "icon":
                        icon = action[1].trimmingCharacters(in: .whitespaces)
                        iconIsSet = true
                    case "statustext":
                        statusText = action[1].trimmingCharacters(in: .whitespaces)
                        statusTextIsSet = true
                    case "status":
                        statusIcon = action[1].trimmingCharacters(in: .whitespaces)
                        statusIsSet = true
                    case "progress":
                    listProgressValue = action[1].trimmingCharacters(in: .whitespaces).floatValue()
                        statusIcon = "progress"
                        progressIsSet = true
                        statusIsSet = true
                    case "delete":
                        deleteRow = true
                    case "add":
                        addRow = true
                    default:
                        break
                    }
            }

            // update the list items array
            if let row = userInputState.listItems.firstIndex(where: {$0.title == title}) {
                if deleteRow {
                    userInputState.listItems.remove(at: row)
                    writeToLog("deleted row at index \(row)")
                } else {
                    if subTitleIsSet { userInputState.listItems[row].subTitle = subtitle }
                    if iconIsSet { userInputState.listItems[row].icon = icon }
                    if statusIsSet { userInputState.listItems[row].statusIcon = statusIcon }
                    if statusTextIsSet { userInputState.listItems[row].statusText = statusText }
                    if progressIsSet { userInputState.listItems[row].progress = listProgressValue }
                    observedData.listItemUpdateRow = row
                    writeToLog("updated row at index \(row)")
                }
                // update the view if visible
                if observedData.args.listItem.present {
                    observedData.args.listItem.present = true
                    writeToLog("showing list")
                }
            }

            // add to the list items array
            if addRow {
                userInputState.listItems.append(ListItems(title: title, subTitle: subtitle, icon: icon, statusText: statusText, statusIcon: statusIcon, progress: listProgressValue))
                writeToLog("row added with \(title) \(subtitle) \(icon) \(statusText) \(statusIcon)")
                // update the view if visible
                if observedData.args.listItem.present {
                    if let row = userInputState.listItems.firstIndex(where: {$0.title == title}) {
                        observedData.listItemUpdateRow = row
                    }
                    observedData.args.listItem.present = true
                }
            }

        }
    }

    private func processCommands(commands: String) {
        //print(getModificationDateOf(self.fileURL))
        //print(Date.now)
        if getModificationDateOf(self.fileURL) < appDefaults.launchTime {
            return
        }
        let allCommands = commands.components(separatedBy: "\n")

        for line in allCommands {

            let command = line.components(separatedBy: " ").first!.lowercased()
            let argument = processTextString(line.replacingOccurrences(of: "\(command) ", with: ""), tags: appvars.systemInfo)
            writeToLog("\(command) ARG: \(argument)")

            switch command {

            case "position:":
                (observedData.appProperties.windowPositionVertical,
                 observedData.appProperties.windowPositionHorozontal) = windowPosition(argument)
                processWindow()
                NSApp.activate(ignoringOtherApps: true)

            case "width:":
                if argument.isNumeric {
                    observedData.appProperties.windowWidth = argument.floatValue()
                    processWindow()
                }

            case "height:":
                if argument.isNumeric {
                    observedData.appProperties.windowHeight = argument.floatValue()
                    processWindow()
                }

            // Title
            case "\(observedData.args.titleOption.long):":
                observedData.args.titleOption.value = argument

            // Title Font
            case "\(observedData.args.titleFont.long):":
                let fontValues = argument.components(separatedBy: .whitespaces)
                for value in fontValues {
                    // split by =
                    let item = value.components(separatedBy: "=")
                    switch item[0] {
                    case  "size":
                        observedData.appProperties.titleFontSize = item[1].floatValue(defaultValue: appvars.titleFontSize)
                    case  "weight":
                        observedData.appProperties.titleFontWeight = Font.Weight(argument: item[1])
                    case  "colour","color":
                        observedData.appProperties.titleFontColour = Color(argument: item[1])
                    case  "name":
                        observedData.appProperties.titleFontName = item[1]
                    case  "shadow":
                        observedData.appProperties.titleFontShadow = item[1].boolValue
                    default:
                        writeToLog("Unknown paramater \(item[0])")
                    }
                }

            // Message
            case "\(observedData.args.messageOption.long):":
                if argument.lowercased().hasSuffix(".md") {
                    writeToLog("message from markdown")
                    observedData.args.messageOption.value = processTextString(getMarkdown(mdFilePath: argument), tags: appvars.systemInfo)
                } else if argument.hasPrefix("+ ") {
                    writeToLog("appending to existing message")
                    observedData.args.messageOption.value += argument.replacingOccurrences(of: "+ ", with: "  \n")
                } else {
                    writeToLog("updating message")
                    observedData.args.messageOption.value = argument
                }
                observedData.args.mainImage.present = false
                observedData.args.mainImageCaption.present = false
                observedData.args.listItem.present = false

            // Message Position
            case "alignment:":
                observedData.args.messageAlignment.value = argument

            //Progress Bar
            case "\(observedData.args.progressBar.long):":

                switch argument.split(separator: " ").first {
                case "increment":
                    let incrementValue = argument.components(separatedBy: " ").last!
                    writeToLog("progress increment by \(Double(incrementValue) ?? 1)")
                    observedData.progressValue = (observedData.progressValue ?? 0) + (Double(incrementValue) ?? 1)
                case "reset", "indeterminate":
                    observedData.progressValue = nil
                case "complete":
                    observedData.progressValue = observedData.progressTotal
                case "delete", "remove", "hide", "disable":
                    observedData.args.progressBar.present = false
                case "create", "show", "enable":
                    observedData.args.progressBar.present = true
                default:
                    if argument == "0" {
                        writeToLog("progress reset")
                        observedData.progressValue = nil
                    } else {
                        writeToLog("progress value set \(argument)")
                        observedData.progressValue = Double(argument) ?? observedData.progressValue
                    }
                }

            //Progress Bar Label
            case "\(observedData.args.progressText.long):".lowercased():
                observedData.args.progressText.present = true
                observedData.args.progressText.value = argument

            // Button 1 label
            case "\(observedData.args.button1TextOption.long):":
                observedData.args.button1TextOption.value = argument

            // Button 1 status
            case "button1:":
                switch argument {
                case "disable", "hide":
                    observedData.args.button1Disabled.present = true
                case "enable", "show":
                    observedData.args.button1Disabled.present = false
                default:
                    observedData.args.button1Disabled.present = false
                }

            // Button 2 label
            case "\(observedData.args.button2TextOption.long):":
                observedData.args.button2TextOption.value = argument

            // Button 2 status
            case "button2:":
                switch argument {
                case "disable", "hide":
                    observedData.args.button2Disabled.present = true
                case "enable", "show":
                    observedData.args.button2Disabled.present = false
                default:
                    observedData.args.button2Disabled.present = false
                }
                
            // Button control size
            case "buttonsize:":
                switch argument {
                case "mini", "small", "regular", "large":
                    observedData.appProperties.buttonSize = appDefaults.buttonSizeStates[argument] ?? .regular
                default:
                    observedData.appProperties.buttonSize = .regular
                }

                
            // Info Button label
            case "\(observedData.args.infoButtonOption.long):":
                observedData.args.infoButtonOption.value = argument

            // Info text
            case "\(observedData.args.infoText.long):":
                switch argument {
                case "disable", "hide":
                    observedData.args.infoText.present = false
                case "reset", "clear":
                    observedData.args.infoText.value = ""
                default:
                    observedData.args.infoText.value = argument
                    observedData.args.infoText.present = true
                }

            // Info Box
            case "\(observedData.args.infoBox.long):":
                if argument.lowercased().hasSuffix(".md") {
                    writeToLog("info box from markdown")
                    observedData.args.infoBox.value = processTextString(getMarkdown(mdFilePath: argument), tags: appvars.systemInfo)
                } else if argument.hasPrefix("+ ") {
                    writeToLog("adding to existing info box")
                    observedData.args.infoBox.value += argument.replacingOccurrences(of: "+ ", with: "  \n")
                } else {
                    writeToLog("updating info box")
                    observedData.args.infoBox.value = argument
                }
                observedData.args.infoBox.present = true

            // icon image
            case "\(observedData.args.iconOption.long):":
                if argument.components(separatedBy: ": ").first == "size" {
                    writeToLog("updating icon size")
                    if argument.replacingOccurrences(of: "size:", with: "").trimmingCharacters(in: .whitespaces) != "" {
                        observedData.iconSize = argument.replacingOccurrences(of: "size: ", with: "").floatValue()
                    } else {
                        observedData.iconSize = observedData.appProperties.iconWidth
                    }
                } else {
                    switch argument {
                    case "centre", "center":
                        observedData.args.centreIcon.present = true
                    case "left", "default":
                        observedData.args.centreIcon.present = false
                    case "none":
                        observedData.args.iconOption.present = false
                        observedData.args.iconOption.value = argument
                    default:
                        //centreIconPresent = false
                        observedData.args.iconOption.present = true
                        observedData.args.iconOption.value = argument
                    }
                }

            // banner image
            case "\(observedData.args.bannerImage.long):":
                switch argument {
                case "none":
                    observedData.args.bannerImage.present = false
                    observedData.args.bannerTitle.present = false
                    observedData.appProperties.titleFontColour = appvars.titleFontColour
                default:
                    observedData.args.bannerImage.value = argument
                    observedData.args.bannerImage.present = true
                }


            // banner text
            case "\(observedData.args.bannerText.long):":
                switch argument {
                case "enable":
                    observedData.args.bannerTitle.present = true
                    observedData.appProperties.titleFontColour = Color.white
                case "disable":
                    observedData.args.bannerTitle.present = false
                    observedData.appProperties.titleFontColour = appvars.titleFontColour
                case "shadow":
                    observedData.appProperties.titleFontShadow = true
                default:
                    observedData.args.bannerText.value = argument
                    observedData.args.bannerTitle.present = true
                }


            // overlay icon
            case "\(observedData.args.overlayIconOption.long):":
                observedData.args.overlayIconOption.value = argument
                observedData.args.overlayIconOption.present = true
                if observedData.args.overlayIconOption.value == "none" {
                    observedData.args.overlayIconOption.present = false
                }

            // image
            case "\(observedData.args.mainImage.long):":
                switch argument.lowercased() {
                case "show":
                    observedData.args.mainImage.present = true
                case "hide":
                    observedData.args.mainImage.present = false
                case "clear":
                    observedData.imageArray.removeAll()
                default:
                    observedData.imageArray.append(MainImage(path: argument))
                    observedData.args.mainImage.present = true
                }

            // image Caption
            case "\(observedData.args.mainImageCaption.long):":
                appvars.imageCaptionArray = [argument]
                observedData.args.mainImageCaption.present = true

            // list items
            case "list:":
                switch argument {
                case "clear":
                    // clean everything out and remove the listview from display
                    observedData.args.listItem.present = false
                    userInputState.listItems = [ListItems]()
                case "show":
                    // show the list
                    observedData.args.listItem.present = true
                case "hide":
                    // hide the list but don't delete the contents
                    observedData.args.listItem.present = false
                default:
                    var listItemsArray = argument.components(separatedBy: ",")
                    writeToLog("updating list array")
                    listItemsArray = listItemsArray.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma

                    userInputState.listItems = [ListItems]()
                    for itemTitle in listItemsArray {
                        userInputState.listItems.append(ListItems(title: itemTitle))
                    }
                    observedData.args.listItem.present = true
                }

            // list item status
            case "\(observedData.args.listItem.long):":
                processListItems(argument)

            // help message
            case "\(observedData.args.helpMessage.long):":
                observedData.args.helpMessage.value = argument
                observedData.args.helpMessage.present = true

            // activate
            case "activate:":
                writeToLog("activating window")
                NSApp.activate(ignoringOtherApps: true)

            // icon alpha
            case "\(observedData.args.iconAlpha.long):":
                let alphaValue = Double(argument) ?? 1.0
                writeToLog("icon alpha - desired: \(argument), actual: \(alphaValue)")
                observedData.iconAlpha = alphaValue

            // video
            case "\(observedData.args.video.long):":
                if argument == "none" {
                    observedData.args.video.present = false
                    observedData.args.video.value = ""
                } else {
                    observedData.args.autoPlay.present = true
                    observedData.args.video.value = getVideoStreamingURLFromID(videoid: argument, autoplay: observedData.args.autoPlay.present)
                    observedData.args.video.present = true
                }

            // blur screen
            case "\(observedData.args.blurScreen.long):":
                switch argument {
                case "enable":
                    writeToLog("enabling blur screen")
                    observedData.args.blurScreen.present = true
                    blurredScreen.show()
                    NSApp.activate(ignoringOtherApps: true)
                default:
                    observedData.args.blurScreen.present = false
                    blurredScreen.hide()
                    if !observedData.args.forceOnTop.present {
                        NSApp.windows.first?.level = .normal
                    }
                    NSApp.activate(ignoringOtherApps: true)
                }

            // web content
            case "\(observedData.args.webcontent.long):":
                if argument == "none" {
                    observedData.args.webcontent.present = false
                    observedData.args.webcontent.value = ""
                } else {
                    if argument.hasPrefix("http") {
                        observedData.args.webcontent.value = argument
                        observedData.args.webcontent.present = true
                    }
                }

            // quit
            case "quit:":
                writeToLog("quitting")
                quitDialog(exitCode: appDefaults.exit5.code)

            default:
                writeToLog("unrecognised command \(line)")
            }
        }
    }
}

class DialogUpdatableContent: ObservableObject {

    // set up some defaults

    var path: String
    var previousCommand: String = ""

    @Published var mainWindow: NSWindow?

    // bring in all the collected appArguments
    // TODO: reduce double handling of data.
    @Published var args: CommandLineArguments
    @Published var appProperties: AppVariables = AppVariables()

    @Published var progressValue: Double?
    @Published var progressTotal: Double
    @Published var iconSize: CGFloat
    @Published var iconAlpha: Double

    @Published var imageArray: [MainImage]

    @Published var listItemsArray: [ListItems]
    @Published var listItemUpdateRow: Int

    @Published var requiredFieldsPresent: Bool

    @Published var showSheet: Bool
    @Published var sheetErrorMessage: String

    @Published var updateView: Bool = true
    @Published var constructionKitShown: Bool = false
    
    var status: StatusState

    let commandFilePermissions: [FileAttributeKey: Any] = [FileAttributeKey.posixPermissions: 0o666]

    init() {

        self.args = appArguments
        self.appProperties = appvars
        writeLog("Init updateable content")
        if appArguments.statusLogFile.present {
            path = appArguments.statusLogFile.value
        } else {
            path = "/var/tmp/dialog.log"
        }


        // initialise all our observed variables
        // for the most part we pull from whatever was passed in save for some tracking variables

        if appArguments.timerBar.present && !appArguments.hideTimerBar.present {
            //self._button1disabled = State(initialValue: true)
            appArguments.button1Disabled.present = true
        }

        progressTotal = Double(appArguments.progressBar.value) ?? 100
        listItemUpdateRow = 0

        iconSize = appArguments.iconSize.value.floatValue()
        iconAlpha = Double(appArguments.iconAlpha.value) ?? 1.0

        imageArray = appvars.imageArray

        listItemsArray = userInputState.listItems

        requiredFieldsPresent = false

        showSheet = false
        sheetErrorMessage = ""

        // start the background process to monotor the command file
        status = .start

        // delete if it already exists
        self.killCommandFile()

        // create a fresh command file
        self.createCommandFile(commandFilePath: path)

        // start the background process to monotor the command file
        if let url = URL(string: path) {
            let reader = FileReader(observedData: self, fileURL: url)
            do {
                try reader.monitorFile()
            } catch {
                writeLog("Error: \(error.localizedDescription)", logLevel: .error)
            }
        }

    }

    func createCommandFile(commandFilePath: String) {
        let manager = FileManager()

        // check to make sure the file exists
        if manager.fileExists(atPath: commandFilePath) {
            writeLog("Existing file at \(commandFilePath). Cleaning")
            let text = ""
            do {
                try text.write(toFile: path, atomically: false, encoding: String.Encoding.utf8)
            } catch {
                if !manager.isReadableFile(atPath: commandFilePath) {
                    writeLog(" Existing file at \(commandFilePath) is not readable\n\tCommands set to \(commandFilePath) will not be processed\n"
                             , logLevel: .error)
                    writeLog("\(error)\n", logLevel: .error)
                }
            }
        } else {
            writeLog("Creating file at \(commandFilePath)")
            manager.createFile(atPath: path, contents: nil, attributes: commandFilePermissions)
        }
    }


    func killCommandFile() {
        // delete the command file

        let manager = FileManager.init()

        if manager.isDeletableFile(atPath: path) {
            do {
                try manager.removeItem(atPath: path)
                //NSLog("Deleted Dialog command file")
            } catch {
                writeLog("Unable to delete file at path \(path)", logLevel: .debug)
                writeLog("\(error)", logLevel: .debug)
            }
        }
    }
}
