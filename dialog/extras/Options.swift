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
            //print("OptionName = \(OptionName)")
            //print("Option Name Index = \(commandIndex)")
            //print("valueIndex = \(valueIndex)")
            //print("CommandLine.arguments.startIndex = \(CommandLine.arguments.startIndex)")
            //print("CommandLine.arguments.endIndex = \(CommandLine.arguments.endIndex)")
            //print("---")
            CLOptionTextValue = CommandLine.arguments[valueIndex]
            if (CLOptionTextValue.starts(with: "--")) {
                print("\(OptionName) has no associated value")
                CLOptionTextValue = DefaultValue
            } else {
                CLOptionTextValue = CLOptionTextValue.replacingOccurrences(of:"\\n", with:"\n")
            }
        }
    } else {
        CLOptionTextValue = DefaultValue
    }
    //print("\(OptionName) - \(CLOptionTextValue)")
    return CLOptionTextValue
}

// returns true if the specified oprion is present.

func CLOptionPresent(OptionName: String) -> Bool {
    // Determine if option is present.
    var optionPresent = false
    if let commandIndex = CommandLine.arguments.firstIndex(of: OptionName) {
        if commandIndex > 0 {
            optionPresent = true
        }
    }
    return optionPresent
}

