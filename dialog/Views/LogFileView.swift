//
//  LogFileView.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/10/2023.
//

import SwiftUI

struct LogFileView: View {

    @State private var logContent: [String] = [""]
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
                    List {
                        ForEach(0..<logContent.count, id: \.self) { index in
                            HStack {
                                Text(logContent[index])
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
                    .onChange(of: logContent, perform: { _ in
                        Task {
                            proxy.scrollTo(logContent.count-1, anchor: .bottom)
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
            fileHandle.seekToEndOfFile()

            while true {
                if let line = fileHandle.readLine() {
                    DispatchQueue.main.async {
                        logContent.append(line)
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

