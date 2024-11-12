//
//  CLOptions.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation

// returns array of multiple option values
func CLOptionMultiOptions (optionName: String) -> Array<String> {
    // return an array that contains of all the --textfield options that are passed in
    var optionsArray: Array = [String]()
    var argIndex = 0
    let CLArguments = CommandLine.arguments
    for argument in CLArguments {

        if argument == "--\(optionName)" {
            optionsArray.append(CLArguments[argIndex+1])
        }
        argIndex+=1
    }
    return optionsArray
}

// Returns the option text for a given command line option
func CLOptionText(optionName: CommandlineArgument, defaultValue: String? = "") -> String {
    // Determine if argument is present.
    var CLOptionTextValue = ""
    let CLArguments = CommandLine.arguments

    if let commandIndex = [CLArguments.firstIndex(of: "--\(optionName.long)"), CLArguments.firstIndex(of: "-\(optionName.short)")].compactMap({$0}).first {
        // Get next index and ensure it's not out of bounds.

        if commandIndex == CLArguments.count-1 {
            // the command being passed in is the last item so just return the default value
            CLOptionTextValue = defaultValue ?? ""
        }

        let valueIndex = CLArguments.index(after: commandIndex)
        if valueIndex >= CLArguments.startIndex
            && valueIndex < CLArguments.endIndex {
            CLOptionTextValue = CLArguments[valueIndex]
            if CLOptionTextValue.starts(with: "-") {
                CLOptionTextValue = defaultValue ?? ""
            } else {
                CLOptionTextValue = CLOptionTextValue.replacingOccurrences(of: "\\n", with: "\n")
            }
        }
    } else {
        CLOptionTextValue = defaultValue ?? ""
    }
    return CLOptionTextValue
}

// returns true if the specified oprion is present.

func CLOptionPresent(optionName: CommandlineArgument) -> Bool {
    // Determine if option is present.
    var optionPresent = false
    let CLArguments = CommandLine.arguments
    if let commandIndex = [CLArguments.firstIndex(of: "--\(optionName.long)"), CLArguments.firstIndex(of: "-\(optionName.short)")].compactMap({$0}).first {
        if commandIndex > 0 {
            optionPresent = true
        }
    }
    return optionPresent
}

private func returnTextFoCLOption(index: Int) -> String {

    return ""
}

