//
//  LogFileView.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/10/2023.
//

import SwiftUI

struct TextFileView: View {

    @State private var textAreaContent = ""
    @State private var fileMonitor: DispatchSourceFileSystemObject?
    var textContentPath: String

    init(logFilePath: String) {
        self.textContentPath = logFilePath
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
                        startStreamingLogFile()
                    }
                }
                .onChange(of: textAreaContent, perform: { _ in
                    Task {
                        proxy.scrollTo("logContent", anchor: .bottom)
                    }
                })
            }
        }
    }

    private func startStreamingLogFile() {
        let fileDescriptor = open(textContentPath, O_EVTONLY)
        fileMonitor = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: .global())

        fileMonitor?.setEventHandler { [self] in
            self.readLogFile()
        }

        fileMonitor?.resume()
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
                    if lineData.isEmpty {
                        return nil
                    } else {
                        return String(data: lineData, encoding: .utf8)
                    }
                }

                if let character = String(data: data, encoding: .utf8) {
                    if character == "\n" {
                        return String(data: lineData, encoding: .utf8)
                    } else {
                        lineData.append(data)
                    }
                }
            }
        }
}

