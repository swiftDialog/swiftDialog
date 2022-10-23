//
//  TrackProgress.swift
//  file watch test
//
//  Created by Bart Reardon on 13/1/2022.
//
// concept and execution apropriated from depNotify

import Foundation
import SwiftUI
import SFSMonitor


enum StatusState {
    case start
    case done
}

class CommandFileReader: SFSMonitorDelegate {
    
    let monitorDispatchQueue =  DispatchQueue(label: "monitorDispatchQueue", qos: .utility)
    @ObservedObject var observedData : DialogUpdatableContent
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }
    
    func receivedNotification(_ notification: SFSMonitorNotification, url: URL, queue: SFSMonitor) {
        monitorDispatchQueue.async(flags: .barrier) { // Multithread protection
            //print(shell("tail -n1 \(url.path)"))
            let command = shell("tail -n1 \(url.path)")
            if command != self.observedData.previousCommand {
                self.observedData.processCommands(commands: shell("/usr/bin/tail -n1 \(url.path)"))
                self.observedData.previousCommand = command
            }
        }
    }
    
}

class DialogUpdatableContent : ObservableObject {
    
    // set up some defaults
    
    var path: String
    var previousCommand : String = ""
    
    @Published var mainWindow : NSWindow?
    
    // bring in all the collected appArguments
    // TODO: reduce double handling of data.
    @Published var args : CommandLineArguments
    @Published var appProperties : AppVariables = appvars
    
    @Published var titleFontColour: Color
    @Published var titleFontSize: CGFloat
    
    @Published var messageText: String
    @Published var statusText: String
    @Published var progressValue: Double
    @Published var progressTotal: Double
    @Published var iconSize: CGFloat
    
    @Published var imageArray : [MainImage]
    //@Published var imagePresent: Bool
    //@Published var imageCaptionPresent: Bool
    
    @Published var listItemsArray : [ListItems]
    @Published var listItemUpdateRow: Int

    @Published var requiredFieldsPresent : Bool
    
    @Published var windowWidth: CGFloat
    @Published var windowHeight: CGFloat
    
    @Published var showSheet: Bool
    @Published var sheetErrorMessage: String
    
    var status: StatusState
    
    let commandFilePermissions: [FileAttributeKey: Any] = [FileAttributeKey.posixPermissions: 0o666]
        
    // init
    
    init() {
        
        self.args = appArguments
        self.appProperties = appvars
        
        if appArguments.statusLogFile.present {
            path = appArguments.statusLogFile.value
        } else {
            path = "/var/tmp/dialog.log"
        }
                
        
        // initialise all our observed variables
        // for the most part we pull from whatever was passed in save for some tracking variables
        
        //button1Disabled = appArguments.button1Disabled.present
        if appArguments.timerBar.present && !appArguments.hideTimerBar.present {
            //self._button1disabled = State(initialValue: true)
            appArguments.button1Disabled.present = true
        }
                
        titleFontColour = appvars.titleFontColour
        titleFontSize = appvars.titleFontSize
        
        messageText = appArguments.messageOption.value
        statusText = appArguments.progressText.value
        progressValue = 0
        progressTotal = 0
        listItemUpdateRow = 0
        
        iconSize = string2float(string: appArguments.iconSize.value)
        
        imageArray = appvars.imageArray
        //imagePresent = appArguments.mainImage.present
        //imageCaptionPresent = appArguments.mainImageCaption.present
        
        listItemsArray = appvars.listItems

        requiredFieldsPresent = false
        
        windowWidth = appvars.windowWidth
        windowHeight = appvars.windowHeight
        
        showSheet = false
        sheetErrorMessage = ""

        // start the background process to monotor the command file
        status = .start
        
        // delete if it already exists
        self.killCommandFile()

        // create a fresh command file
        self.createCommandFile(commandFilePath: path)
        
        // start the background process to monotor the command file
        let commandFileDelegate = CommandFileReader(observedDialogContent: self)
        let commandQueue = SFSMonitor(delegate: commandFileDelegate)
        commandQueue?.setMaxMonitored(number: 200)
        _ = commandQueue?.addURL(URL(fileURLWithPath: path))
        
    }
    
    func createCommandFile(commandFilePath: String) {
        let fm = FileManager()
        
        // check to make sure the file exists
        if fm.fileExists(atPath: commandFilePath) {
            logger(logMessage: "Existing file at \(commandFilePath). Cleaning")
            let text = ""
            do {
                try text.write(toFile: path, atomically: false, encoding: String.Encoding.utf8)
            } catch {
                logger(logMessage: "Existing file at \(commandFilePath) but couldn't clean. ")
                logger(logMessage: "Error info: \(error)")
            }
        } else {
            logger(logMessage: "Creating file at \(commandFilePath)")
            fm.createFile(atPath: path, contents: nil, attributes: commandFilePermissions)
        }
    }
            
    func processCommands(commands: String) {
        
        let allCommands = commands.components(separatedBy: "\n")
        
        for line in allCommands {
            
            let command = line.components(separatedBy: " ").first!.lowercased()
                        
            switch command {
            /*
            case "width:" :
                windowWidth = NumberFormatter().number(from: line.replacingOccurrences(of: "width: ", with: "")) as! CGFloat
                placeWindow(mainWindow!, size: CGSize(width: windowWidth, height: windowHeight+28))
                
            case "height:" :
                windowHeight = NumberFormatter().number(from: line.replacingOccurrences(of: "height: ", with: "")) as! CGFloat
                placeWindow(mainWindow!, size: CGSize(width: windowWidth, height: windowHeight+28))
            */
            // Title
            case "\(args.titleOption.long):" :
                args.titleOption.value = line.replacingOccurrences(of: "\(args.titleOption.long): ", with: "")
            
            // Message
            case "\(args.messageOption.long):" :
                args.messageOption.value = line.replacingOccurrences(of: "\(args.messageOption.long): ", with: "").replacingOccurrences(of: "\\n", with: "\n")
                //imagePresent = false
                //imageCaptionPresent = false
                //listItemPresent = false
                
            // Message Position
            case "alignment:" :
                args.messageAlignment.value = line.replacingOccurrences(of: "alignment: ", with: "")
                
            //Progress Bar
            case "\(args.progressBar.long):" :
                let incrementValue = line.replacingOccurrences(of: "\(args.progressBar.long): ", with: "")
                switch incrementValue {
                case "increment" :
                    if progressTotal == 0 {
                        progressTotal = Double(args.progressBar.value) ?? 100
                    }
                    progressValue = progressValue + 1
                case "reset" :
                    progressValue = 0
                case "complete" :
                    progressValue = Double(args.progressBar.value) ?? 1000
                case "indeterminate" :
                //    progressTotal = 0
                    progressValue = Double(-1)
                case "remove" :
                    args.progressBar.present = false
                case "create" :
                    args.progressBar.present = true
                //case "determinate" :
                //    progressValue = 0
                default :
                    if progressTotal == 0 {
                        progressTotal = Double(args.progressBar.value) ?? 100
                    }
                    progressValue = Double(incrementValue) ?? 0
                }
                
            //Progress Bar Label
            case "\(args.progressBar.long)text:" :
                statusText = line.replacingOccurrences(of: "\(args.progressBar.long)text: ", with: "")
                
            //Progress Bar Label (typo version with capital T)
            case "\(args.progressBar.long)Text:" :
                statusText = line.replacingOccurrences(of: "\(args.progressBar.long)Text: ", with: "")
            
            // Button 1 label
            case "\(args.button1TextOption.long):" :
                args.button1TextOption.value = line.replacingOccurrences(of: "\(args.button1TextOption.long): ", with: "")
                
            // Button 1 status
            case "button1:" :
                let buttonCMD = line.replacingOccurrences(of: "button1: ", with: "")
                switch buttonCMD {
                case "disable" :
                    args.button1Disabled.present = true
                case "enable" :
                    args.button1Disabled.present = false
                default :
                    args.button1Disabled.present = false
                }

            // Button 2 label
            case "\(args.button2TextOption.long):" :
                args.button2TextOption.value = line.replacingOccurrences(of: "\(args.button2TextOption.long): ", with: "")
            
            // Info Button label
            case "\(args.infoButtonOption.long):" :
                args.infoButtonOption.value = line.replacingOccurrences(of: "\(args.infoButtonOption.long): ", with: "")
                
            // icon image
            case "\(args.iconOption.long):" :
                //iconPresent = true
                let iconState = line.replacingOccurrences(of: "\(args.iconOption.long): ", with: "")
                
                if iconState.components(separatedBy: ": ").first == "size" {
                    //print(iconState)
                    //if let readIconSize = iconState.replacingOccurrences(of: "size: ", with: "") {
                    if iconState.replacingOccurrences(of: "size:", with: "").trimmingCharacters(in: .whitespaces) != "" {
                        iconSize = string2float(string: iconState.replacingOccurrences(of: "size: ", with: ""))
                    } else {
                        iconSize = appvars.iconWidth
                    }
                } else {
                    switch iconState {
                    case "centre", "center" :
                        args.centreIcon.present = true
                    case "left", "default" :
                        args.centreIcon.present = false
                    case "none" :
                        args.iconOption.present = false
                        args.iconOption.value = iconState
                    default:
                        //centreIconPresent = false
                        args.iconOption.present = true
                        args.iconOption.value = iconState
                    }
                }
                //print("centre icon is \(centreIconPresent)")
                //iconImage = line.replacingOccurrences(of: "\(args.iconOption.long): ", with: "")
                
            // overlay icon
            case "\(args.overlayIconOption.long):":
                args.overlayIconOption.value = line.replacingOccurrences(of: "\(args.overlayIconOption.long): ", with: "")
                args.overlayIconOption.present = true
                if args.overlayIconOption.value == "none" {
                    args.overlayIconOption.present = false
                }
                
            // image
            case "\(args.mainImage.long):" :
                //appvars.imageArray = [line.replacingOccurrences(of: "\(args.mainImage.long): ", with: "")]
                appvars.imageArray.append(MainImage(path: line.replacingOccurrences(of: "\(args.mainImage.long): ", with: "")))
                //imagePresent = true
                
            // image Caption
            case "\(args.mainImageCaption.long):" :
                appvars.imageCaptionArray = [line.replacingOccurrences(of: "\(args.mainImageCaption.long): ", with: "")]
                //imageCaptionPresent = true
                
            // list items
            case "list:" :
                switch line.replacingOccurrences(of: "list: ", with: "") {
                case "clear":
                    // clean everything out and remove the listview from display
                    args.listItem.present = false
                    listItemsArray = [ListItems]()
                case "show":
                    // show the list
                    args.listItem.present = true
                case "hide":
                    // hide the list but don't delete the contents
                    args.listItem.present = false
                default:
                    var listItems = line.replacingOccurrences(of: "list: ", with: "").components(separatedBy: ",")
                    listItems = listItems.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma

                    listItemsArray = [ListItems]()
                    for itemTitle in listItems {
                        listItemsArray.append(ListItems(title: itemTitle))
                    }
                    args.listItem.present = true
                }
                
            // list item status
            case "\(args.listItem.long):" :
                var title             : String = ""
                var icon              : String = ""
                var statusText        : String = ""
                var statusIcon        : String = ""
                let statusTypeArray = ["wait","success","fail","error","pending","progress"]
                var listProgressValue : CGFloat = 0
                var deleteRow         : Bool = false
                var addRow            : Bool = false
                
                var iconIsSet         : Bool = false
                var statusIsSet       : Bool = false
                var statusTextIsSet   : Bool = false
                var progressIsSet     : Bool = false

                let listCommand = line.replacingOccurrences(of: "\(args.listItem.long): ", with: "")
                
                // Check for the origional way of doign things
                let listItemStateArray = listCommand.components(separatedBy: ": ")
                if listItemStateArray.count > 0 {
                    title = listItemStateArray.first!
                    statusIcon = listItemStateArray.last!
                    // if using the new method, these will not be set as the title value won't match the ItemValue
                    if let row = listItemsArray.firstIndex(where: {$0.title == title}) {
                        if statusTypeArray.contains(statusIcon) {
                            listItemsArray[row].statusIcon = statusIcon
                            listItemsArray[row].statusText = ""
                        } else {
                            listItemsArray[row].statusIcon = ""
                            listItemsArray[row].statusText = statusIcon
                        }
                        listItemUpdateRow = row
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
                                if let i = Int(action[1].trimmingCharacters(in: .whitespaces)) {
                                    if i >= 0 && i < listItemsArray.count {
                                        title = listItemsArray[i].title
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
                    if let row = listItemsArray.firstIndex(where: {$0.title == title}) {
                        if deleteRow {
                            listItemsArray.remove(at: row)
                            logger(logMessage: "deleted row at index \(row)")
                        } else {
                            if iconIsSet { listItemsArray[row].icon = icon }
                            if statusIsSet { listItemsArray[row].statusIcon = statusIcon }
                            if statusTextIsSet { listItemsArray[row].statusText = statusText }
                            if progressIsSet  {listItemsArray[row].progress = listProgressValue }
                            listItemUpdateRow = row
                        }
                    }
                    
                    // add to the list items array
                    if addRow {
                        listItemsArray.append(ListItems(title: title, icon: icon, statusText: statusText, statusIcon: statusIcon, progress: listProgressValue))
                        logger(logMessage: "row added with \(title) \(icon) \(statusText) \(statusIcon)")
                    }
                    
                }
                
            // quit
            case "quit:" :
                quitDialog(exitCode: appvars.exit5.code)

            default:

                break
            }
        }
    }
    
    func killCommandFile() {
        // delete the command file
        
        let fs = FileManager.init()
        
        if fs.isDeletableFile(atPath: path) {
            do {
                try fs.removeItem(atPath: path)
                //NSLog("Deleted Dialog command file")
            } catch {
                logger(logMessage: "Unable to delete command file")
            }
        }
    }
}
