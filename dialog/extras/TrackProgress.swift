//
//  TrackProgress.swift
//  file watch test
//
//  Created by Bart Reardon on 13/1/2022.
//
// concept and execution apropriated from depNotify

import Foundation

enum StatusState {
    case start
    case done
}

class DialogUpdatableContent : ObservableObject {
    
    // set up some defaults
    
    var path: String
    @Published var titleText: String
    @Published var messageText: String
    @Published var statusText: String
    @Published var progressValue: Double
    @Published var progressTotal: Double
    @Published var button1Value: String
    @Published var button1Disabled: Bool
    @Published var button2Value: String
    @Published var infoButtonValue: String
    @Published var iconImage: String
    //@Published var image: String
    @Published var imagePresent: Bool
    @Published var imageCaptionPresent: Bool
    @Published var listItemArray: [String]
    @Published var listItemStatus: [String]
    @Published var listItemUpdateRow: Int
    @Published var listItemPresent: Bool
    
    var status: StatusState
    
    let task = Process()
    let fm = FileManager()
    var fwDownloadsStarted = false
    var filesets = Set<String>()
    
    // init
    
    init() {
        
        if cloptions.statusLogFile.present {
            path = cloptions.statusLogFile.value
        } else {
            path = "/var/tmp/dialog.log"
        }
        
        // initialise all our observed variables
        // for the most part we pull from whatever was passed in save for some tracking variables
        
        titleText = cloptions.titleOption.value
        messageText = cloptions.messageOption.value
        statusText = ""
        progressValue = 0
        progressTotal = 0
        button1Value = cloptions.button1TextOption.value
        button1Disabled = cloptions.button1Disabled.present
        button2Value = cloptions.button2TextOption.value
        infoButtonValue = cloptions.infoButtonOption.value
        listItemUpdateRow = 0
        
        iconImage = cloptions.iconOption.value
        
        //image = cloptions.mainImage.value
        appvars.imageArray = CLOptionMultiOptions(optionName: cloptions.mainImage.long)
        appvars.imageCaptionArray = CLOptionMultiOptions(optionName: cloptions.mainImageCaption.long)
        imagePresent = cloptions.mainImage.present
        imageCaptionPresent = cloptions.mainImageCaption.present
                
        listItemArray = appvars.listItemArray
        listItemStatus = appvars.listItemStatus
        listItemPresent = cloptions.listItem.present

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
        
        if !fm.fileExists(atPath: path) {
            // need to make the file
            fm.createFile(atPath: path, contents: nil, attributes: nil)
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
            NSLog("Task terminated!")
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
            // Title
            case "\(cloptions.titleOption.long):" :
                titleText = line.replacingOccurrences(of: "\(cloptions.titleOption.long): ", with: "")
            
            // Message
            case "\(cloptions.messageOption.long):" :
                messageText = line.replacingOccurrences(of: "\(cloptions.messageOption.long): ", with: "").replacingOccurrences(of: "\\n", with: "\n")
                imagePresent = false
                imageCaptionPresent = false
                //listItemPresent = false
                
            //Progress Bar
            case "\(cloptions.progressBar.long):" :
                let incrementValue = line.replacingOccurrences(of: "\(cloptions.progressBar.long): ", with: "")
                switch incrementValue {
                case "increment" :
                    if progressTotal == 0 {
                        progressTotal = 100
                    }
                    progressValue = progressValue + 1
                case "reset" :
                    progressValue = 0
                case "complete" :
                    progressValue = Double(cloptions.progressBar.value) ?? 1000
                //case "indeterminate" :
                //    progressTotal = 0
                //    progressValue = 0
                //case "determinate" :
                //    progressValue = 0
                default :
                    if progressTotal == 0 {
                        progressTotal = 100
                    }
                    progressValue = Double(incrementValue) ?? 0
                }
                
            //Progress Bar Label
            case "\(cloptions.progressBar.long)text:" :
                statusText = line.replacingOccurrences(of: "\(cloptions.progressBar.long)text: ", with: "")
                
            //Progress Bar Label (typo version with capital T)
            case "\(cloptions.progressBar.long)Text:" :
                statusText = line.replacingOccurrences(of: "\(cloptions.progressBar.long)Text: ", with: "")
            
            // Button 1 label
            case "\(cloptions.button1TextOption.long):" :
                button1Value = line.replacingOccurrences(of: "\(cloptions.button1TextOption.long): ", with: "")
                
            // Button 1 status
            case "button1:" :
                let buttonCMD = line.replacingOccurrences(of: "button1: ", with: "")
                switch buttonCMD {
                case "disable" :
                    button1Disabled = true
                case "enable" :
                    button1Disabled = false
                default :
                    button1Disabled = button1Disabled
                }

            // Button 2 label
            case "\(cloptions.button2TextOption.long):" :
                button2Value = line.replacingOccurrences(of: "\(cloptions.button2TextOption.long): ", with: "")
            
            // Info Button label
            case "\(cloptions.infoButtonOption.long):" :
                infoButtonValue = line.replacingOccurrences(of: "\(cloptions.infoButtonOption.long): ", with: "")
                
            // icon image
            case "\(cloptions.iconOption.long):" :
                iconImage = line.replacingOccurrences(of: "\(cloptions.iconOption.long): ", with: "")
                
            // image
            case "\(cloptions.mainImage.long):" :
                appvars.imageArray = [line.replacingOccurrences(of: "\(cloptions.mainImage.long): ", with: "")]
                imagePresent = true
                
            // image Caption
            case "\(cloptions.mainImageCaption.long):" :
                appvars.imageCaptionArray = [line.replacingOccurrences(of: "\(cloptions.mainImageCaption.long): ", with: "")]
                imageCaptionPresent = true
                
            // list items
            case "list:" :
                if line.replacingOccurrences(of: "list: ", with: "") == "clear" {
                    // clean everything out and remove the listview from display
                    listItemArray = Array(repeating: "", count: 64)
                    listItemStatus = appvars.listItemStatus
                    listItemPresent = false
                } else {
                    var listItems = line.replacingOccurrences(of: "list: ", with: "").components(separatedBy: ",")
                    listItems = listItems.map { $0.trimmingCharacters(in: .whitespaces) } // trim out any whitespace from the values if there were spaces before after the comma
                    listItemArray = listItems
                    listItemStatus = appvars.listItemStatus
                    listItemPresent = true
                }
                
            // list item status
            case "\(cloptions.listItem.long):" :
                let listItem = line.replacingOccurrences(of: "\(cloptions.listItem.long): ", with: "")
                
                let ItemValue = listItem.components(separatedBy: ": ").first!
                let ItemStatus = listItem.components(separatedBy: ": ").last!
                                
                listItemStatus[listItemArray.firstIndex {$0 == ItemValue} ?? 63] = ItemStatus
                listItemUpdateRow = listItemArray.firstIndex {$0 == ItemValue} ?? 63
                
                // update the listutem array named listItemValue with listItemStatus
                
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
                NSLog("Unable to delete command file")
            }
        }
    }
}
