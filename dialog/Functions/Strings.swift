//
//  Strings.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation

enum ViewType: String {
    case textfile
    case webcontent
    case listitem
    case checkbox
    case textfield
    case radiobutton
    case dropdown
}

func getVersionString() -> String {
    // return the cf bundle version
    var appVersion: String = appvars.cliversion
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion = "\(version).\(build)"
        } else {
            appVersion = version
        }
    }
    return appVersion
}

func reorderViewArray(orderList: String, viewOrderArray: [String]) -> [String]? {
    let orderItems = orderList.components(separatedBy: ",")
    var tempViewArray = viewOrderArray
    var reorderedArray: [String] = []

    for item in orderItems {
        if let index = tempViewArray.firstIndex(of: item) {
            reorderedArray.append(tempViewArray.remove(at: index))
        }
    }

    // Append any remaining items that were not specified in the orderList
    reorderedArray.append(contentsOf: tempViewArray)

    return reorderedArray
}

func processTextString(_ textToProcess: String, tags: [String: String]) -> String {
    // replace html with markdown
    var processedTextString = textToProcess
    // replace embedded variables in text.
    for (label, value) in tags {
        processedTextString = processedTextString.replacingOccurrences(of: "{\(label)}", with: value)
    }
    return processedTextString
        .replacingOccurrences(of: "<br>", with: "  \n")
        .replacingOccurrences(of: "<hr>", with: "****")
}
