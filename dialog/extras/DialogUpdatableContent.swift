//
//  TrackProgress.swift
//  file watch test
//
//  Created by Bart Reardon on 13/1/2022.
//
// concept and execution apropriated from depNotify

import Foundation
import SwiftUI

enum StatusState {
    case start
    case done
}

class DialogUpdatableContent : ObservableObject {
    
    // set up some defaults
    
    var path: String
    
    // bring in all the collected appArguments
    // TODO: reduce double handling of data.
    @Published var args : CommandLineArguments = appArguments
    @Published var appProperties : AppVariables = appvars
    
    //@Published var titleText: String   // unused
    @Published var titleFontColour: Color
    @Published var titleFontSize: CGFloat
    
    @Published var messageText: String
    @Published var statusText: String
    @Published var progressValue: Double
    @Published var progressTotal: Double
    //@Published var button1Value: String
    //@Published var button1Disabled: Bool
    //@Published var button2Value: String
    //@Published var button2Present: Bool
    //@Published var infoButtonValue: String
    //@Published var infoButtonPresent: Bool
    //@Published var iconImage: String
    @Published var iconSize: CGFloat
    //@Published var iconPresent: Bool
    //@Published var overlayIconImage: String
    //@Published var overlayIconPresent: Bool
    //@Published var centreIconPresent: Bool
    //@Published var image: String
    
    @Published var imageArray : [MainImage]
    @Published var imagePresent: Bool
    @Published var imageCaptionPresent: Bool
    
    @Published var listItemsArray : [ListItems]
    @Published var listItemUpdateRow: Int
    @Published var listItemPresent: Bool
    
    @Published var textEntryArray : [TextFieldState]
    
    @Published var requiredTextfieldHighlight: [Color] = Array(repeating: Color.clear, count: appvars.textFields.count)
    @Published var requiredFieldsPresent : Bool
    
    @Published var windowWidth: CGFloat
    @Published var windowHeight: CGFloat
    
    @Published var showSheet: Bool
    @Published var sheetErrorMessage: String
    
    var status: StatusState
    
    let task = Process()
    let fm = FileManager()
    var fwDownloadsStarted = false
    var filesets = Set<String>()
    
    let commandFilePermissions: [FileAttributeKey: Any] = [FileAttributeKey.posixPermissions: 0o666]
    
    // init
    
    init() {
        
        if appArguments.statusLogFile.present {
            path = appArguments.statusLogFile.value
        } else {
            path = "/var/tmp/dialog.log"
        }
        
        // initialise all our observed variables
        // for the most part we pull from whatever was passed in save for some tracking variables
        
        //button1Disabled = args.button1Disabled.present
        if appArguments.timerBar.present && !appArguments.hideTimerBar.present {
            //self._button1disabled = State(initialValue: true)
            appArguments.button1Disabled.present = true
        }
                
        //titleText = appArguments.titleOption.value
        titleFontColour = appvars.titleFontColour
        titleFontSize = appvars.titleFontSize
        
        messageText = appArguments.messageOption.value
        statusText = appArguments.progressText.value
        progressValue = 0
        progressTotal = 0
        //button1Value = appArguments.button1TextOption.value
        //button2Value = appArguments.button2TextOption.value
        //button2Present = appArguments.button2Option.present
        //infoButtonValue = appArguments.infoButtonOption.value
        //infoButtonPresent = appArguments.infoButtonOption.present || appArguments.buttonInfoTextOption.present
        listItemUpdateRow = 0
        
        //requiredTextfieldHighlight = Color.clear
        
        //iconImage = appArguments.iconOption.value
        iconSize = string2float(string: appArguments.iconSize.value)
        //iconPresent = !appvars.iconIsHidden
        //centreIconPresent = appArguments.centreIcon.present
        
        imageArray = appvars.imageArray
        imagePresent = appArguments.mainImage.present
        imageCaptionPresent = appArguments.mainImageCaption.present
        
        //overlayIconImage = appArguments.overlayIconOption.value
        //overlayIconPresent = appArguments.overlayIconOption.present
        
        listItemsArray = appvars.listItems
        listItemPresent = appArguments.listItem.present
        
        textEntryArray = appvars.textFields
        requiredFieldsPresent = false
        
        windowWidth = appvars.windowWidth
        windowHeight = appvars.windowHeight
        
        showSheet = false
        sheetErrorMessage = ""

        // start the background process to monotor the command file
        status = .start
        task.launchPath = "/usr/bin/tail"
        task.arguments = ["-f", path]
        
        // delete if it already exists
        self.killCommandFile()
        self.run()
        
    }
    
    // watch for updates and post them
    
    func run() {
        
        // check to make sure the file exists
        if fm.fileExists(atPath: path) {
            logger(logMessage: "Existing file at \(path). Cleaning")
            let text = ""
            do {
                try text.write(toFile: path, atomically: false, encoding: String.Encoding.utf8)
            } catch {
                logger(logMessage: "Existing file at \(path) but couldn't clean. ")
                logger(logMessage: "Error info: \(error)")
            }
        } else {
            logger(logMessage: "Creating file at \(path)")
            fm.createFile(atPath: path, contents: nil, attributes: commandFilePermissions)
        }
        
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        let outputHandle = pipe.fileHandleForReading
        outputHandle.waitForDataInBackgroundAndNotify()
        
        var dataAvailable : NSObjectProtocol!
        dataAvailable = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable,
        object: outputHandle, queue: nil) {  notification -> Void in
            let data = pipe.fileHandleForReading.availableData
            if data.count > 0 {
                if let str = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    //print("Task sent some data: \(str)")
                    self.processCommands(commands: str as String)
                }
                outputHandle.waitForDataInBackgroundAndNotify()
            } else {
                NotificationCenter.default.removeObserver(dataAvailable as Any)
            }
        }
        
        var dataReady : NSObjectProtocol!
        dataReady = NotificationCenter.default.addObserver(forName: Process.didTerminateNotification,
        object: pipe.fileHandleForReading, queue: nil) { notification -> Void in
            logger(logMessage: "Task terminated!")
            NotificationCenter.default.removeObserver(dataReady as Any)
        }
        
        task.launch()
    }
    
    func end() {
        task.terminate()
    }
    
    func processCommands(commands: String) {
        
        let allCommands = commands.components(separatedBy: "\n")
        
        for line in allCommands {
            
            let command = line.components(separatedBy: " ").first!.lowercased()
                        
            switch command {
            /*
            case "width:" :
                windowWidth = NumberFormatter().number(from: line.replacingOccurrences(of: "width: ", with: "")) as! CGFloat
                appvars.windowWidth = NumberFormatter().number(from: line.replacingOccurrences(of: "width: ", with: "")) as! CGFloat
                
            case "height:" :
                windowHeight = NumberFormatter().number(from: line.replacingOccurrences(of: "height: ", with: "")) as! CGFloat
                appvars.windowHeight = NumberFormatter().number(from: line.replacingOccurrences(of: "height: ", with: "")) as! CGFloat
            */
            // Title
            case "\(appArguments.titleOption.long):" :
                args.titleOption.value = line.replacingOccurrences(of: "\(appArguments.titleOption.long): ", with: "")
            
            // Message
            case "\(appArguments.messageOption.long):" :
                args.messageOption.value = line.replacingOccurrences(of: "\(appArguments.messageOption.long): ", with: "").replacingOccurrences(of: "\\n", with: "\n")
                imagePresent = false
                imageCaptionPresent = false
                //listItemPresent = false
                
            //Progress Bar
            case "\(appArguments.progressBar.long):" :
                let incrementValue = line.replacingOccurrences(of: "\(appArguments.progressBar.long): ", with: "")
                switch incrementValue {
                case "increment" :
                    if progressTotal == 0 {
                        progressTotal = Double(appArguments.progressBar.value) ?? 100
                    }
                    progressValue = progressValue + 1
                case "reset" :
                    progressValue = 0
                case "complete" :
                    progressValue = Double(appArguments.progressBar.value) ?? 1000
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
                        progressTotal = Double(appArguments.progressBar.value) ?? 100
                    }
                    progressValue = Double(incrementValue) ?? 0
                }
                
            //Progress Bar Label
            case "\(appArguments.progressBar.long)text:" :
                statusText = line.replacingOccurrences(of: "\(appArguments.progressBar.long)text: ", with: "")
                
            //Progress Bar Label (typo version with capital T)
            case "\(appArguments.progressBar.long)Text:" :
                statusText = line.replacingOccurrences(of: "\(appArguments.progressBar.long)Text: ", with: "")
            
            // Button 1 label
            case "\(appArguments.button1TextOption.long):" :
                args.button1TextOption.value = line.replacingOccurrences(of: "\(appArguments.button1TextOption.long): ", with: "")
                
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
            case "\(appArguments.button2TextOption.long):" :
                args.button2TextOption.value = line.replacingOccurrences(of: "\(appArguments.button2TextOption.long): ", with: "")
            
            // Info Button label
            case "\(appArguments.infoButtonOption.long):" :
                args.infoButtonOption.value = line.replacingOccurrences(of: "\(appArguments.infoButtonOption.long): ", with: "")
                
            // icon image
            case "\(appArguments.iconOption.long):" :
                //iconPresent = true
                let iconState = line.replacingOccurrences(of: "\(appArguments.iconOption.long): ", with: "")
                
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
                //iconImage = line.replacingOccurrences(of: "\(appArguments.iconOption.long): ", with: "")
                
            // overlay icon
            case "\(appArguments.overlayIconOption.long):":
                args.overlayIconOption.value = line.replacingOccurrences(of: "\(appArguments.overlayIconOption.long): ", with: "")
                args.overlayIconOption.present = true
                if args.overlayIconOption.value == "none" {
                    args.overlayIconOption.present = false
                }
                
            // image
            case "\(appArguments.mainImage.long):" :
                //appvars.imageArray = [line.replacingOccurrences(of: "\(appArguments.mainImage.long): ", with: "")]
                appvars.imageArray.append(MainImage(path: line.replacingOccurrences(of: "\(appArguments.mainImage.long): ", with: "")))
                imagePresent = true
                
            // image Caption
            case "\(appArguments.mainImageCaption.long):" :
                appvars.imageCaptionArray = [line.replacingOccurrences(of: "\(appArguments.mainImageCaption.long): ", with: "")]
                imageCaptionPresent = true
                
            // list items
            case "list:" :
                switch line.replacingOccurrences(of: "list: ", with: "") {
                case "clear":
                    // clean everything out and remove the listview from display
                    listItemPresent = false
                    listItemsArray = [ListItems]()
                case "show":
                    // show the list
                    listItemPresent = true
                case "hide":
                    // hide the list but don't delete the contents
                    listItemPresent = false
                default:
                    var listItems = line.replacingOccurrences(of: "list: ", with: "").components(separatedBy: ",")
                    listItems = listItems.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma

                    listItemsArray = [ListItems]()
                    for itemTitle in listItems {
                        listItemsArray.append(ListItems(title: itemTitle))
                    }
                    listItemPresent = true
                }
                
            // list item status
            case "\(appArguments.listItem.long):" :
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

                let listCommand = line.replacingOccurrences(of: "\(appArguments.listItem.long): ", with: "")
                
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
                self.end()
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
