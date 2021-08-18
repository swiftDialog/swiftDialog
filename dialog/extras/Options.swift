//
//  Options.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation


// Returns the option text for a given command line option

func CLOptionTextField () -> Array<String> {
    // return an array that contains of all the --textfield options that are passed in
    var textOptionsArray: Array = [String]()
    var argIndex = 0
    for argument in CommandLine.arguments {
        
        if argument == "--\(CLOptions.textField.long)" {
            textOptionsArray.append(CommandLine.arguments[argIndex+1])
        }
        argIndex+=1
    }
    
    return textOptionsArray
}

func CLOptionText(OptionName: (long: String, short: String), DefaultValue: String? = "") -> String {
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
            && valueIndex < CommandLine.arguments.endIndex
        {
            //if CommandLine.arguments[commandIndex] != "--\(CLOptions.timerBar.long)" {
                CLOptionTextValue = CommandLine.arguments[valueIndex]
                if (CLOptionTextValue.starts(with: "-")) {
                    //print("Argument \(CommandLine.arguments[commandIndex]) was not passed a value.")
                    CLOptionTextValue = DefaultValue ?? ""
                } else {
                    CLOptionTextValue = CLOptionTextValue.replacingOccurrences(of:"\\n", with:"\n")
                }
            //}
        }
    } else {
        CLOptionTextValue = DefaultValue ?? ""
    }
    //print("\(OptionName) - \(CLOptionTextValue)")
    return CLOptionTextValue
}

// returns true if the specified oprion is present.

func CLOptionPresent(OptionName: (long: String, short: String)) -> Bool {
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

