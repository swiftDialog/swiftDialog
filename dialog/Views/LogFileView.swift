//
//  LogFileView.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/10/2023.
//

import SwiftUI

struct LogFileView: View {

    @State private var logContentArray: [String] = [""]
    @State private var logContent = ""
    @State private var fileMonitor: DispatchSourceFileSystemObject?
    var logFilePath: String

    var body: some View {
        if !logFilePath.isEmpty {
            ScrollViewReader { proxy in
                VStack {
                    HStack {
                        Text("\(logFilePath):")
                        Spacer()
                    }

                    /*
                    TextEditor(text: $logContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cornerRadius(3.0)
                        .background(Color("editorBackgroundColour"))
                        .onAppear {
                            DispatchQueue.main.async {
                                startStreamingLogFile()
                            }
                        }
                        .onChange(of: logContent, perform: { _ in
                            Task {
                                proxy.scrollTo(logContent, anchor: .bottom)
                            }
                        })
                     */

                    /*
                    List {
                        ForEach(0..<logContentArray.count, id: \.self) { index in
                            HStack {
                                Text(logContentArray[index])
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                                    .hideRowSeperator()
                            }

                        }
                    }
                    .cornerRadius(3.0)
                    .background(Color("editorBackgroundColour"))
                    .onAppear {
                        DispatchQueue.main.async {
                            startStreamingLogFile()
                        }
                    }
                    .onChange(of: logContentArray, perform: { _ in
                        Task {
                            proxy.scrollTo(logContentArray.count-1, anchor: .bottom)
                        }
                    })
                     */

                    List {
                        Text(logContent)
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
                    .onChange(of: logContent, perform: { _ in
                        Task {
                            proxy.scrollTo("logContent", anchor: .bottom)
                        }
                    })
                }
            }
        }
    }

    private func startStreamingLogFile() {
        let fileDescriptor = open(logFilePath, O_EVTONLY)
        fileMonitor = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: .global())

        fileMonitor?.setEventHandler { [self] in
            self.readLogFile()
        }

        fileMonitor?.resume()
    }

    private func readLogFile() {
        do {
            let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: logFilePath))
            try fileHandle.seekToEnd()

            while true {
                if let line = fileHandle.readLine() {
                    DispatchQueue.main.async {
                        //logContentArray.append(line)
                        logContent+="\(line)\n"
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

