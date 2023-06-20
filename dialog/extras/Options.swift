//
//  Options.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation

// returns array of multiple option values
func CLOptionMultiOptions (optionName : String) -> Array<String> {
    // return an array that contains of all the --textfield options that are passed in
    var optionsArray: Array = [String]()
    var argIndex = 0
    for argument in CommandLine.arguments {
        
        if argument == "--\(optionName)" {
            optionsArray.append(CommandLine.arguments[argIndex+1])
        }
        argIndex+=1
    }
    return optionsArray
}

// Returns the option text for a given command line option
func CLOptionText(OptionName: CommandlineArgument, DefaultValue: String? = "") -> String {
    // Determine if argument is present.
    var CLOptionTextValue = ""
    
    if let commandIndex = [CommandLine.arguments.firstIndex(of: "--\(OptionName.long)"), CommandLine.arguments.firstIndex(of: "-\(OptionName.short)")].compactMap({$0}).first {
        // Get next index and ensure it's not out of bounds.
        
        if (commandIndex == CommandLine.arguments.count-1) {
            // the command being passed in is the last item so just return the default value
            CLOptionTextValue = DefaultValue ?? ""
        }
 
        let valueIndex = CommandLine.arguments.index(after: commandIndex)
        if valueIndex >= CommandLine.arguments.startIndex
            && valueIndex < CommandLine.arguments.endIndex {
            CLOptionTextValue = CommandLine.arguments[valueIndex]
            if (CLOptionTextValue.starts(with: "-")) {
                CLOptionTextValue = DefaultValue ?? ""
            } else {
                CLOptionTextValue = CLOptionTextValue.replacingOccurrences(of:"\\n", with:"\n")
            }
        }
    } else {
        CLOptionTextValue = DefaultValue ?? ""
    }
    return CLOptionTextValue
}

// returns true if the specified oprion is present.

func CLOptionPresent(OptionName: CommandlineArgument) -> Bool {
    // Determine if option is present.
    var optionPresent = false
    if let commandIndex = [CommandLine.arguments.firstIndex(of: "--\(OptionName.long)"), CommandLine.arguments.firstIndex(of: "-\(OptionName.short)")].compactMap({$0}).first {
        if commandIndex > 0 {
            optionPresent = true
        }
    }
    return optionPresent
}

private func returnTextFoCLOption(index: Int) -> String {

    return ""
}

