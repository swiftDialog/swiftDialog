//
//  Logs.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import OSLog

func writeLog(_ message: String, logLevel: OSLogType = .info, log: OSLog = osLog) {
    let logMessage = "\(message)"
    var standardError = StandardError()

    os_log("%{public}@", log: log, type: logLevel, logMessage)
    if logLevel == .error || appvars.debugMode || appArguments.verboseLogging.present {
        // print debug and error to sterr
        print("\(logLevel.stringValue.uppercased()): \(message)", to: &standardError)
    }
    // also write to a log file
    // writeFileLog(message: message, logLevel: logLevel)
}

func writeFileLog(message: String, logLevel: OSLogType) {
    // write to a log file for accessability of those that don't want to manage the system log
    let logFilePath = "/private/var/log/dialog.log"
    if logLevel == .debug && !appvars.debugMode {
        return
    }
    let logFileURL = URL(fileURLWithPath: logFilePath)
    if !checkFileExists(path: logFilePath) {
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        let attributes = [FileAttributeKey.posixPermissions: 0o666]
        do {
            try FileManager.default.setAttributes(attributes, ofItemAtPath: logFileURL.path)
        } catch {
            printStdErr("\(OSLogType.error.stringValue.uppercased()): Unable to create log file at \(logFilePath)")
            printStdErr(error.localizedDescription)
            return
        }
    }
    do {
        let fileHandle = try FileHandle(forWritingTo: logFileURL)
        defer { fileHandle.closeFile() }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let date = dateFormatter.string(from: Date())
        let logEntry = "\(date) \(logLevel.stringValue): \(message)\n"

        fileHandle.seekToEndOfFile()
        fileHandle.write(logEntry.data(using: .utf8)!)
    } catch {
        printStdErr("\(OSLogType.error.stringValue.uppercased()): Unable to read log file at \(logFilePath)")
        printStdErr(error.localizedDescription)
        return
    }
}

func printStdErr(_ errorMessage: String) {
    var standardError = StandardError()
    print(errorMessage, to: &standardError)
}

func checkFileExists(path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path)
}

extension OSLogType {
    var stringValue: String {
        switch self {
        case .default: return "default"
        case .info: return "info"
        case .debug: return "debug"
        case .error: return "error"
        case .fault: return "fault"
        default: return "unknown"
        }
    }
}

