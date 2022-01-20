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
    @Published var button1Value: String
    @Published var button1Disabled: Bool
    @Published var button2Value: String
    @Published var infoButtonValue: String
    @Published var iconImage: String
    
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
        
        titleText = cloptions.titleOption.value
        messageText = cloptions.messageOption.value
        statusText = ""
        progressValue = 0
        button1Value = cloptions.button1TextOption.value
        button1Disabled = false
        button2Value = cloptions.button2TextOption.value
        infoButtonValue = cloptions.infoButtonOption.value
        
        iconImage = cloptions.iconOption.value
        
        status = .start
        task.launchPath = "/usr/bin/tail"
        task.arguments = ["-f", path]
        
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
        
        //titleText = cloptions.titleOption.value
        
    }
    
    func processCommands(commands: String) {
        
        let allCommands = commands.components(separatedBy: "\n")
        
        for line in allCommands {
            //print(line)
            switch line.components(separatedBy: " ").first! {
            // Title
            case "\(cloptions.titleOption.long):" :
                titleText = line.replacingOccurrences(of: "\(cloptions.titleOption.long): ", with: "")
            
            // Message
            case "\(cloptions.messageOption.long):" :
                messageText = line.replacingOccurrences(of: "\(cloptions.messageOption.long): ", with: "").replacingOccurrences(of: "\\n", with: "\n")
            
            //Progress Bar
            case "\(cloptions.progressBar.long):" :
                progressValue = Double(line.replacingOccurrences(of: "\(cloptions.progressBar.long): ", with: "")) ?? 0
            
            //Progress Bar Label
            case "\(cloptions.progressBar.long)Text:" :
                statusText = line.replacingOccurrences(of: "\(cloptions.progressBar.long)Text: ", with: "")
                
            case "\(cloptions.button1TextOption.long):" :
                button1Value = line.replacingOccurrences(of: "\(cloptions.button1TextOption.long): ", with: "")
                
            case "button1:" :
                let buttonCMD = line.replacingOccurrences(of: "button1: ", with: "")
                if buttonCMD == "disable" {
                    button1Disabled = true
                } else if buttonCMD == "enable" {
                    button1Disabled = false
                }
                
            case "\(cloptions.button2TextOption.long):" :
                button2Value = line.replacingOccurrences(of: "\(cloptions.button2TextOption.long): ", with: "")
                
            case "\(cloptions.infoButtonOption.long):" :
                infoButtonValue = line.replacingOccurrences(of: "\(cloptions.infoButtonOption.long): ", with: "")
                
            // icon
            case "\(cloptions.iconOption.long):" :
                iconImage = line.replacingOccurrences(of: "\(cloptions.iconOption.long): ", with: "")

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
                NSLog("Deleted Dialog command file")
            } catch {
                NSLog("Unable to delete command file")
            }
        }
    }
}
