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
        progressTotal = 0
        button1Value = cloptions.button1TextOption.value
        button1Disabled = false
        button2Value = cloptions.button2TextOption.value
        infoButtonValue = cloptions.infoButtonOption.value
        
        iconImage = cloptions.iconOption.value
        
        //image = cloptions.mainImage.value
        appvars.imageArray = CLOptionMultiOptions(optionName: cloptions.mainImage.long)
        appvars.imageCaptionArray = CLOptionMultiOptions(optionName: cloptions.mainImageCaption.long)
        imagePresent = cloptions.mainImage.present
        imageCaptionPresent = cloptions.mainImageCaption.present
        
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
    
    func end() {
        task.terminate()
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
                imagePresent = false
                imageCaptionPresent = false
                
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
