//
//  Options.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation


// Returns the option text for a given command line option

func CLOptionText(OptionName: String, DefaultValue: String) -> String {
    // Determine if argument is present.
    var CLOptionTextValue = ""
    if let commandIndex = CommandLine.arguments.firstIndex(of: OptionName) {
        // Get next index and ensure it's not out of bounds.
        let valueIndex = CommandLine.arguments.index(after: commandIndex)
        if valueIndex >= CommandLine.arguments.startIndex
            && valueIndex < CommandLine.arguments.endIndex
        {
            CLOptionTextValue = CommandLine.arguments[valueIndex]
            CLOptionTextValue = CLOptionTextValue.replacingOccurrences(of:"\\n", with:"\n")
        }
    } else {
        CLOptionTextValue = DefaultValue
    }
    //print("\(OptionName) - \(CLOptionTextValue)")
    return CLOptionTextValue
}

