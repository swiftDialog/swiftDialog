//
//  HostLine.swift
//
//  The device-identity line (computer name · OS version · account) a footer can seat.
//

import Foundation

enum HostLine {

    /// Joins the facts; an empty fact is dropped, not padded (the user name is empty in a daemon context).
    static func text(name: String, os: String, user: String,
                     separator: String = " · ") -> String {
        [name, os, user].filter { !$0.isEmpty }.joined(separator: separator)
    }

    /// The line for the machine this process runs on.
    static func current(separator: String = " · ") -> String {
        text(name: Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
             os: ProcessInfo.processInfo.operatingSystemVersionString,
             user: NSUserName(),
             separator: separator)
    }
}
