//
//  LogFileView.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/10/2023.
//

import SwiftUI

struct LogFileView: View {

    @State private var logContent: String = ""
    @State private var fileMonitor: DispatchSourceFileSystemObject?
    @State private var fileHandle: FileHandle?
    @State private var dataAvailable: NSObjectProtocol?
    @State private var dataReady: NSObjectProtocol?

    var logFilePath: String

    var body: some View {
        if !logFilePath.isEmpty {
            ScrollViewReader { proxy in
                VStack {
                    HStack {
                        Text("\(logFilePath):")
                        Spacer()
                    }
                    ScrollView {
                        Text(logContent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("logContent")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cornerRadius(3.0)
                    .background(Color("editorBackgroundColour"))
                    .onAppear {
                        DispatchQueue.main.async {
                            startStreamingLogFile()
                        }
                    }
                    .onChange(of: logContent, perform: { _ in
                        //DispatchQueue.main.async {
                            proxy.scrollTo("logContent", anchor: .bottom)
                        //}
                    })
                }
            }
        }
    }

    private func startStreamingLogFile() {
        let fileDescriptor = open(logFilePath, O_EVTONLY)
        fileMonitor = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: .global())

        fileMonitor?.setEventHandler { [self] in
            try? self.readLogFile()
        }

        fileMonitor?.resume()
    }

    private func readLogFile() throws {
        //do {
            try self.fileHandle = FileHandle(forReadingFrom: URL(fileURLWithPath: logFilePath))

            fileHandle?.waitForDataInBackgroundAndNotify()
            //let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: logFilePath))
            //fileHandle.seekToEndOfFile()

            dataAvailable = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: self.fileHandle, queue: nil) { _ in
                if let data = self.fileHandle?.availableData,
                   data.count > 0 {
                    //if let line = fileHandle.readLine() {
                        //DispatchQueue.main.async {
                            logContent += String(data: data, encoding: .utf8) ?? ""
                        //}
                    //}
                }
            }
            dataReady = NotificationCenter.default.addObserver(forName: Process.didTerminateNotification,
                                                               object: self.fileHandle, queue: nil) { _ -> Void in
                NSLog("Task terminated!")
                NotificationCenter.default.removeObserver(self.dataReady as Any)
            }
        //} catch {
        ///    print("Error opening or reading log file: \(error.localizedDescription)")
        //}
    }

}

extension FileHandle {
    func readLine() -> String? {
        let data = self.readData(ofLength: 1)
        if data.isEmpty {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
