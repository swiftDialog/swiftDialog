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
    if logLevel == .error || (logLevel == .debug && appvars.debugMode) {
        // print debug and error to sterr
        print("\(oslogTypeToString(logLevel).uppercased()): \(message)", to: &standardError)
    }
}

func oslogTypeToString(_ type: OSLogType) -> String {
    switch type {
    case OSLogType.default: return "default"
    case OSLogType.info: return "info"
    case OSLogType.debug: return "debug"
    case OSLogType.error: return "error"
    case OSLogType.fault: return "fault"
    default: return "unknown"
    }
}
