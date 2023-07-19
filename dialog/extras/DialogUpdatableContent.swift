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

enum StatusState {
    case start
    case done
}

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
                    print("Error: \(error.localizedDescription)")
                }
            }
        }

        dataReady = NotificationCenter.default.addObserver(forName: Process.didTerminateNotification,
                                                           object: self.fileHandle, queue: nil) { _ -> Void in
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

    private func processCommands(commands: String) {

        let allCommands = commands.components(separatedBy: "\n")

        for line in allCommands {

            let command = line.components(separatedBy: " ").first!.lowercased()

            switch command {

            case "width:":
                let tempWidth = line.replacingOccurrences(of: "width: ", with: "")
                if tempWidth.isNumeric {
                    observedData.appProperties.windowWidth = CGFloat((tempWidth as NSString).floatValue)
                    placeWindow(observedData.mainWindow!, size: CGSize(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight+28))
                }

            case "height:":
                let tempHeight = line.replacingOccurrences(of: "height: ", with: "")
                if tempHeight.isNumeric {
                    observedData.appProperties.windowHeight = CGFloat((tempHeight as NSString).floatValue)
                    placeWindow(observedData.mainWindow!, size: CGSize(width: observedData.appProperties.windowWidth, height: observedData.appProperties.windowHeight+28))
                }

            // Title
            case "\(observedData.args.titleOption.long):":
                observedData.args.titleOption.value = line.replacingOccurrences(of: "\(observedData.args.titleOption.long): ", with: "")

            // Message
            case "\(observedData.args.messageOption.long):":
                let message = line.replacingOccurrences(of: "\(observedData.args.messageOption.long): ", with: "").replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "<br>", with: "\n")
                if message.lowercased().hasSuffix(".md") {
                    observedData.args.messageOption.value = getMarkdown(mdFilePath: message)
                } else if message.hasPrefix("+ ") {
                    observedData.args.messageOption.value += message.replacingOccurrences(of: "+ ", with: "  \n")
                } else {
                    observedData.args.messageOption.value = message
                }
                observedData.args.mainImage.present = false
                observedData.args.mainImageCaption.present = false
                observedData.args.listItem.present = false

            // Message Position
            case "alignment:":
                observedData.args.messageAlignment.value = line.replacingOccurrences(of: "alignment: ", with: "")

            //Progress Bar
            case "\(observedData.args.progressBar.long):":
                let progressCommand = line.replacingOccurrences(of: "\(observedData.args.progressBar.long): ", with: "")
                switch progressCommand.split(separator: " ").first {
                case "increment":
                    let incrementValue = progressCommand.components(separatedBy: " ").last!
                    observedData.progressValue = (observedData.progressValue ?? 0) + (Double(incrementValue) ?? 1)
                case "reset", "indeterminate":
                    observedData.progressValue = nil
                case "complete":
                    observedData.progressValue = observedData.progressTotal
                case "delete", "remove", "hide":
                    observedData.args.progressBar.present = false
                case "create", "show":
                    observedData.args.progressBar.present = true
                default:
                    if progressCommand == "0" {
                        observedData.progressValue = nil
                    } else {
                        observedData.progressValue = Double(progressCommand) ?? observedData.progressValue
                    }
                }

            //Progress Bar Label
            case "\(observedData.args.progressText.long):".lowercased():
                observedData.args.progressText.value = line.replacingOccurrences(of: "\(observedData.args.progressText.long): ", with: "", options: .caseInsensitive)

            // Button 1 label
            case "\(observedData.args.button1TextOption.long):":
                observedData.args.button1TextOption.value = line.replacingOccurrences(of: "\(observedData.args.button1TextOption.long): ", with: "")

            // Button 1 status
            case "button1:":
                let buttonCMD = line.replacingOccurrences(of: "button1: ", with: "")
                switch buttonCMD {
                case "disable":
                    observedData.args.button1Disabled.present = true
                case "enable":
                    observedData.args.button1Disabled.present = false
                default:
                    observedData.args.button1Disabled.present = false
                }

            // Button 2 label
            case "\(observedData.args.button2TextOption.long):":
                observedData.args.button2TextOption.value = line.replacingOccurrences(of: "\(observedData.args.button2TextOption.long): ", with: "")

            // Button 2 status
            case "button2:":
                let buttonCMD = line.replacingOccurrences(of: "button2: ", with: "")
                switch buttonCMD {
                case "disable":
                    observedData.args.button2Disabled.present = true
                case "enable":
                    observedData.args.button2Disabled.present = false
                default:
                    observedData.args.button2Disabled.present = false
                }

            // Info Button label
            case "\(observedData.args.infoButtonOption.long):":
                observedData.args.infoButtonOption.value = line.replacingOccurrences(of: "\(observedData.args.infoButtonOption.long): ", with: "")

            // Info text
            case "\(observedData.args.infoText.long):":
                let infoText = line.replacingOccurrences(of: "\(observedData.args.infoText.long): ", with: "")
                if infoText == "disable" {
                    observedData.args.infoText.present = false
                } else {
                    observedData.args.infoText.value = infoText
                    observedData.args.infoText.present = true
                }

            // Info Box
            case "\(observedData.args.infoBox.long):":
                let infoBoxContent = line.replacingOccurrences(of: "\(observedData.args.infoBox.long): ", with: "").replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "<br>", with: "\n")
                if infoBoxContent.lowercased().hasSuffix(".md") {
                    observedData.args.infoBox.value = getMarkdown(mdFilePath: infoBoxContent)
                } else if infoBoxContent.hasPrefix("+ ") {
                    observedData.args.infoBox.value += infoBoxContent.replacingOccurrences(of: "+ ", with: "  \n")
                } else {
                    observedData.args.infoBox.value = infoBoxContent
                }
                observedData.args.infoBox.present = true

            // icon image
            case "\(observedData.args.iconOption.long):":
                //iconPresent = true
                let iconState = line.replacingOccurrences(of: "\(observedData.args.iconOption.long): ", with: "")

                if iconState.components(separatedBy: ": ").first == "size" {
                    if iconState.replacingOccurrences(of: "size:", with: "").trimmingCharacters(in: .whitespaces) != "" {
                        observedData.iconSize = string2float(string: iconState.replacingOccurrences(of: "size: ", with: ""))
                    } else {
                        observedData.iconSize = observedData.appProperties.iconWidth
                    }
                } else {
                    switch iconState {
                    case "centre", "center":
                        observedData.args.centreIcon.present = true
                    case "left", "default":
                        observedData.args.centreIcon.present = false
                    case "none":
                        observedData.args.iconOption.present = false
                        observedData.args.iconOption.value = iconState
                    default:
                        //centreIconPresent = false
                        observedData.args.iconOption.present = true
                        observedData.args.iconOption.value = iconState
                    }
                }

            // overlay icon
            case "\(observedData.args.overlayIconOption.long):":
                observedData.args.overlayIconOption.value = line.replacingOccurrences(of: "\(observedData.args.overlayIconOption.long): ", with: "")
                observedData.args.overlayIconOption.present = true
                if observedData.args.overlayIconOption.value == "none" {
                    observedData.args.overlayIconOption.present = false
                }

            // image
            case "\(observedData.args.mainImage.long):":
                let argument = line.replacingOccurrences(of: "\(observedData.args.mainImage.long): ", with: "")
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
                appvars.imageCaptionArray = [line.replacingOccurrences(of: "\(observedData.args.mainImageCaption.long): ", with: "")]
                observedData.args.mainImageCaption.present = true
                //imageCaptionPresent = true

            // list items
            case "list:":
                switch line.replacingOccurrences(of: "list: ", with: "") {
                case "clear":
                    // clean everything out and remove the listview from display
                    observedData.args.listItem.present = false
                    listItems = [ListItems]()
                case "show":
                    // show the list
                    observedData.args.listItem.present = true
                case "hide":
                    // hide the list but don't delete the contents
                    observedData.args.listItem.present = false
                default:
                    var listItemsArray = line.replacingOccurrences(of: "list: ", with: "").components(separatedBy: ",")
                    listItemsArray = listItemsArray.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma

                    listItems = [ListItems]()
                    for itemTitle in listItemsArray {
                        listItems.append(ListItems(title: itemTitle))
                    }
                    observedData.args.listItem.present = true
                }

            // list item status
            case "\(observedData.args.listItem.long):":
                var title: String = ""
                var icon: String = ""
                var statusText: String = ""
                var statusIcon: String = ""
                let statusTypeArray = ["wait","success","fail","error","pending","progress"]
                var listProgressValue: CGFloat = 0
                var deleteRow: Bool = false
                var addRow: Bool = false

                var iconIsSet: Bool = false
                var statusIsSet: Bool = false
                var statusTextIsSet: Bool = false
                var progressIsSet: Bool = false

                let listCommand = line.replacingOccurrences(of: "\(observedData.args.listItem.long): ", with: "")

                // Check for the origional way of doign things
                let listItemStateArray = listCommand.components(separatedBy: ": ")
                if listItemStateArray.count > 0 {
                    title = listItemStateArray.first!
                    statusIcon = listItemStateArray.last!
                    // if using the new method, these will not be set as the title value won't match the ItemValue
                    if let row = listItems.firstIndex(where: {$0.title == title}) {
                        if statusTypeArray.contains(statusIcon) {
                            listItems[row].statusIcon = statusIcon
                            listItems[row].statusText = ""
                        } else {
                            listItems[row].statusIcon = ""
                            listItems[row].statusText = statusIcon
                        }
                        observedData.listItemUpdateRow = row
                        break
                    }
                }

                // And now for the new way
                let commands = listCommand.components(separatedBy: ",")

                if commands.count > 0 {
                    for command in commands {
                        let action = command.components(separatedBy: ": ")
                        switch action[0].lowercased().trimmingCharacters(in: .whitespaces) {
                            case "index":
                                if let index = Int(action[1].trimmingCharacters(in: .whitespaces)) {
                                    if index >= 0 && index < listItems.count {
                                        title = listItems[index].title
                                    }
                                }
                            case "title":
                                title = action[1].trimmingCharacters(in: .whitespaces)
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
                                listProgressValue = string2float(string: action[1].trimmingCharacters(in: .whitespaces))
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
                    if let row = listItems.firstIndex(where: {$0.title == title}) {
                        if deleteRow {
                            listItems.remove(at: row)
                            writeLog("deleted row at index \(row)")
                        } else {
                            if iconIsSet { listItems[row].icon = icon }
                            if statusIsSet { listItems[row].statusIcon = statusIcon }
                            if statusTextIsSet { listItems[row].statusText = statusText }
                            if progressIsSet { listItems[row].progress = listProgressValue }
                            observedData.listItemUpdateRow = row
                        }
                        // update the view if visible
                        if observedData.args.listItem.present {
                            observedData.args.listItem.present = true
                        }
                    }

                    // add to the list items array
                    if addRow {
                        listItems.append(ListItems(title: title, icon: icon, statusText: statusText, statusIcon: statusIcon, progress: listProgressValue))
                        writeLog("row added with \(title) \(icon) \(statusText) \(statusIcon)")
                        // update the view if visible
                        if observedData.args.listItem.present {
                            if let row = listItems.firstIndex(where: {$0.title == title}) {
                                observedData.listItemUpdateRow = row
                            }
                            observedData.args.listItem.present = true
                        }
                    }

                }

            // help message
            case "\(observedData.args.helpMessage.long):":
                observedData.args.helpMessage.value = line.replacingOccurrences(of: "\(observedData.args.helpMessage.long): ", with: "").replacingOccurrences(of: "\\n", with: "\n")
                observedData.args.helpMessage.present = true

            // activate
            case "activate:":
                NSApp.activate(ignoringOtherApps: true)

            // icon alpha
            case "\(observedData.args.iconAlpha.long):":
                observedData.iconAlpha = Double(line.replacingOccurrences(of: "\(observedData.args.iconAlpha.long): ", with: "")) ?? 1.0

            // video
            case "\(observedData.args.video.long):":
                let command = line.replacingOccurrences(of: "\(observedData.args.video.long): ", with: "")
                if command == "none" {
                    observedData.args.video.present = false
                    observedData.args.video.value = ""
                } else {
                    observedData.args.autoPlay.present = true
                    observedData.args.video.value = getVideoStreamingURLFromID(videoid: command, autoplay: observedData.args.autoPlay.present)
                    observedData.args.video.present = true
                }

            // web content
            case "\(observedData.args.webcontent.long):":
                let command = line.replacingOccurrences(of: "\(observedData.args.webcontent.long): ", with: "")
                if command == "none" {
                    observedData.args.webcontent.present = false
                    observedData.args.webcontent.value = ""
                } else {
                    if command.hasPrefix("http") {
                        observedData.args.webcontent.value = command
                        observedData.args.webcontent.present = true
                    }
                }

            // quit
            case "quit:":
                quitDialog(exitCode: appvars.exit5.code)

            default:
                break
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

    @Published var blurredScreen = [BlurWindowController]()

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

        iconSize = string2float(string: appArguments.iconSize.value)
        iconAlpha = Double(appArguments.iconAlpha.value) ?? 1.0

        imageArray = appvars.imageArray

        listItemsArray = listItems

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
                print("Error: \(error.localizedDescription)")
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
                                        writeLog("Existing file at \(commandFilePath) but couldn't clean. ")
                                        writeLog("Error info: \(error)")
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
                                        writeLog("Unable to delete command file")
            }
        }
    }
}
