//
//  CLOptions.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation

// returns array of multiple option values
func CLOptionMultiOptions(optionName: String) -> Array<String> {
    // return an array that contains all the values passed in for a repeatable option
    var optionsArray: Array = [String]()
    let CLArguments = CommandLine.arguments
    for (argIndex, argument) in CLArguments.enumerated() {
        if argument == "--\(optionName)" {
            // The value is the next token. Treat it as empty if the option is the
            // last argument or the next token is itself an option (starts with "-"),
            // matching CLOptionText — otherwise we'd read past the end of the array
            // or swallow the following flag.
            var value = ""
            let valueIndex = argIndex + 1
            if valueIndex < CLArguments.count && !CLArguments[valueIndex].starts(with: "-") {
                value = CLArguments[valueIndex]
            }
            switch optionName {
            case "image":
                // Accept as comma separated values
                optionsArray += value.components(separatedBy: ",")
            default:
                optionsArray.append(value)
            }
        }
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

