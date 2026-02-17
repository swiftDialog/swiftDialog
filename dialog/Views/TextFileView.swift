//
//  LogFileView.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/10/2023.
//

import SwiftUI

struct TextFileView: View {

    @State private var textAreaContent = ""
    @State private var fileMonitor: DispatchSourceRead?
    var textContentPath: String
    var loadHistory: Bool
    var historyLineLimit: Int

    init(logFilePath: String, loadHistory: Bool = true, historyLineLimit: Int = 1000) {
        self.textContentPath = logFilePath
        self.loadHistory = loadHistory
        self.historyLineLimit = historyLineLimit
    }

    var body: some View {
        if !textContentPath.isEmpty {
            ScrollViewReader { proxy in
                List {
                    Text(textAreaContent)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("logContent")
                }
                .background(Color("editorBackgroundColour"))
                .cornerRadius(5.0)
                .onAppear {
                    DispatchQueue.main.async {
                        if loadHistory {
                            loadExistingContent()
                        }
                        startStreamingLogFile()
                    }
                }
                .onChange(of: textAreaContent) {
                    Task {
                        proxy.scrollTo("logContent", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func loadExistingContent() {
        do {
            let fileContent = try String(contentsOfFile: textContentPath, encoding: .utf8)
            let lines = fileContent.components(separatedBy: .newlines)
            
            if historyLineLimit > 0 && lines.count > historyLineLimit {
                let lastLines = Array(lines.suffix(historyLineLimit))
                textAreaContent = lastLines.joined(separator: "\n")
            } else {
                textAreaContent = fileContent
            }
            
            // Ensure content ends with newline if it doesn't already
            if !textAreaContent.isEmpty && !textAreaContent.hasSuffix("\n") {
                textAreaContent += "\n"
            }
            
        } catch {
            print("Error loading existing log content: \(error.localizedDescription)")
        }
    }

    private func startStreamingLogFile() {
        if FileManager.default.fileExists(atPath: textContentPath) {
            let fileDescriptor = open(textContentPath, O_EVTONLY)
            fileMonitor = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor, queue: .global())
            
            fileMonitor?.setEventHandler { [self] in
                self.readLogFile()
            }
            
            fileMonitor?.resume()
        } else {
            writeLog("Requested displaylog file does not exist at path: \"\(textContentPath)\"", logLevel: .error)
            quitDialog(exitCode: appDefaults.exit202.code, exitMessage: appDefaults.exit202.message)
        }
        
    }

    private func readLogFile() {
        do {
            let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: textContentPath))
            try fileHandle.seekToEnd()

            while true {
                if let line = fileHandle.readLine() {
                    DispatchQueue.main.async {
                        textAreaContent+="\(line)\n"
                    }
                } else {
                    usleep(10000)
                }
            }
        } catch {
            print("Error opening or reading log file: \(error.localizedDescription)")
        }
    }
}

extension FileHandle {
    func readLine() -> String? {
        var lineData = Data()
        while true {
            let data = self.readData(ofLength: 1)

            if data.isEmpty {
                if !lineData.isEmpty {
                    return String(data: lineData, encoding: .utf8)
                } else {
                    return nil
                }
            }

            lineData.append(data)
            
            // Check if we've hit a newline by looking at the accumulated data
            if data.first == 0x0A { // \n is 0x0A in ASCII/UTF-8
                // Remove the trailing newline before converting
                lineData.removeLast()
                return String(data: lineData, encoding: .utf8)
            }
        }
    }
}
