//
//  Untitled.swift
//  swiftDialog
//
//  Created by Bart E Reardon on 16/10/2024.
//

import SwiftUI
import Combine

class FileWatcher: ObservableObject {
    @Published var fileContent: String = ""
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private let filePath: String
    private var fileHandle: FileHandle?
    private let initFile: Bool

    init(filePath: String, initFile: Bool = false) {
        self.filePath = filePath
        self.initFile = initFile
    }

    func startWatching() {
        // Initialize the file if needed
        if initFile {
            initializeFile()
        }

        guard fileDescriptor == -1 else { return }

        // Open the file
        fileDescriptor = open(filePath, O_EVTONLY)
        guard fileDescriptor != -1 else {
            print("Error opening file.")
            return
        }

        // Set up the dispatch source to monitor the file
        dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: DispatchQueue.global())

        // Define the event handler
        dispatchSource?.setEventHandler { [weak self] in
            self?.fileDidChange()
        }

        // Define the cancellation handler
        dispatchSource?.setCancelHandler { [weak self] in
            if let descriptor = self?.fileDescriptor {
                close(descriptor)
                self?.fileDescriptor = -1
            }
        }

        // Start monitoring
        dispatchSource?.resume()

        // Read the initial content of the file
        readFileContent()
    }

    func stopWatching() {
        dispatchSource?.cancel()
    }

    private func fileDidChange() {
        DispatchQueue.global().async { [weak self] in
            self?.readFileContent()
        }
    }

    private func readFileContent() {
        // Open file for reading if not already opened
        if fileHandle == nil {
            fileHandle = FileHandle(forReadingAtPath: filePath)
        }

        // Ensure we have a valid file handle
        guard let fileHandle = fileHandle else { return }

        // Seek to the end of the file and read the new data
        let data = fileHandle.readDataToEndOfFile()

        if let newContent = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async { [weak self] in
                self?.fileContent.append(newContent)
            }
        }
    }

    private func initializeFile() {
            let fileManager = FileManager.default

            // Check if the file exists
            if fileManager.fileExists(atPath: filePath) {
                // Truncate the file if it exists
                do {
                    try "".write(toFile: filePath, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to clear file: \(error.localizedDescription)")
                }
            } else {
                // Create an empty file if it doesn't exist
                fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
            }
        }
}
