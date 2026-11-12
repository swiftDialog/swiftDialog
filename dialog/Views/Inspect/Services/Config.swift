//
//  Config.swift
//  dialog
//
//  Configuration request/result models and the error type whose messages point at the JSON that failed.
//  The `Config` service itself is filled in by the Config+*.swift extensions.
//

import Foundation

// MARK: - Configuration Models

struct ConfigurationRequest {
    let environmentVariable: String
    let fallbackToTestData: Bool
    
    static let `default` = ConfigurationRequest(
        environmentVariable: "DIALOG_INSPECT_CONFIG",
        fallbackToTestData: true
    )
}

struct ConfigurationResult {
    let config: InspectConfig
    let source: ConfigurationSource
    let warnings: [String]
}


enum ConfigurationError: Error, LocalizedError {
    case fileNotFound(path: String)
    case invalidJSON(path: String, error: Error)
    case missingEnvironmentVariable(name: String)
    case testDataCreationFailed(error: Error)
    case invalidFormat(reason: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Configuration file not found at: \(path)"
        case .invalidJSON(let path, let error):
            let jsonString = try? String(contentsOfFile: path, encoding: .utf8)
            return "Invalid JSON in configuration file \(path): \(Self.formatJSONError(error, jsonString: jsonString))"
        case .missingEnvironmentVariable(let name):
            return "Environment variable '\(name)' not set and no fallback available"
        case .testDataCreationFailed(let error):
            return "Failed to create test configuration: \(error.localizedDescription)"
        case .invalidFormat(let reason):
            return reason
        }
    }

    /// Human-readable text for a decoding or syntax error, with line number and snippet when `jsonString` is given.
    static func formatJSONError(_ error: Error, jsonString: String? = nil) -> String {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                let location = path.isEmpty ? "root" : "'\(path)'"
                var message = "Missing required field '\(key.stringValue)' at \(location)"

                if let json = jsonString, !path.isEmpty {
                    let result = extractJSONSnippet(json: json, path: path)
                    if let lineNum = result.lineNumber {
                        message += " (line \(lineNum))"
                    }
                    if let snippet = result.snippet {
                        message += "\n\n📍 Error location:\n\(snippet)"
                    }
                }

                if let hint = fieldHint(for: key.stringValue) {
                    message += "\n\n💡 Hint: \(hint)"
                }
                return message

            case .typeMismatch(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                var message = "Type mismatch at '\(path)': expected \(type)"

                if let json = jsonString, !path.isEmpty {
                    let result = extractJSONSnippet(json: json, path: path)
                    if let lineNum = result.lineNumber {
                        message += " (line \(lineNum))"
                    }
                    if let snippet = result.snippet {
                        message += "\n\n📍 Error location:\n\(snippet)"
                    }
                }

                if let hint = typeHint(for: path, expectedType: type) {
                    message += "\n\n💡 Hint: \(hint)"
                }
                return message

            case .valueNotFound(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                var message = "Missing value at '\(path)': expected \(type)"

                if let json = jsonString, !path.isEmpty {
                    let result = extractJSONSnippet(json: json, path: path)
                    if let lineNum = result.lineNumber {
                        message += " (line \(lineNum))"
                    }
                }
                return message

            case .dataCorrupted(let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                let location = path.isEmpty ? "document" : "'\(path)'"
                return "Data corrupted at \(location): \(context.debugDescription)"

            @unknown default:
                return error.localizedDescription
            }
        }

        // JSONSerialization syntax errors: the debug description reads "... around line X, column Y".
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain || nsError.domain == "NSCocoaErrorDomain" {
            if let debugDesc = nsError.userInfo[NSDebugDescriptionErrorKey] as? String {
                var message = "JSON syntax error (line "

                if let json = jsonString,
                   let range = debugDesc.range(of: "line \\d+", options: .regularExpression),
                   let lineNum = Int(debugDesc[range].dropFirst(5)) {
                    message += "\(lineNum)): \(debugDesc)"
                    let lines = json.components(separatedBy: "\n")
                    if lineNum > 0 && lineNum <= lines.count {
                        let startLine = max(0, lineNum - 3)
                        let endLine = min(lines.count, lineNum + 2)
                        var snippet = "\n\n📍 Around line \(lineNum):\n"
                        for i in startLine..<endLine {
                            let marker = (i + 1 == lineNum) ? "→ " : "  "
                            snippet += "\(marker)\(i + 1): \(lines[i])\n"
                        }
                        message += snippet
                    }
                } else {
                    message = "JSON syntax error: \(debugDesc)"
                }
                return message
            }
        }

        return error.localizedDescription
    }

    /// Locates a coding path such as "items.Index 0.guidanceContent.Index 0.state" in the raw JSON text
    /// and returns the 1-based line number and a few surrounding lines, or (nil, nil).
    static func extractJSONSnippet(json: String, path: String) -> (lineNumber: Int?, snippet: String?) {
        let components = path.split(separator: ".")

        var arrayKey = ""
        var itemIndex = 0
        var fieldName: String?

        for component in components {
            let comp = String(component)
            if comp.hasPrefix("Index ") {
                if let idx = Int(comp.dropFirst(6)) {
                    itemIndex = idx
                }
            } else {
                if ["items", "guidanceContent", "plistSources"].contains(comp) {
                    arrayKey = comp
                    itemIndex = 0
                } else {
                    // The last non-index component is the field name.
                    fieldName = comp
                }
            }
        }

        let lines = json.components(separatedBy: "\n")
        var foundKeyLine = -1
        var braceCount = 0
        var inTargetArray = false
        var currentItemIndex = -1
        var itemStartLine = -1
        var itemEndLine = -1

        // Find the item block by counting braces inside the target array.
        for (lineIdx, line) in lines.enumerated() {
            if line.contains("\"\(arrayKey)\"") && line.contains("[") {
                inTargetArray = true
                braceCount = 0
            }

            if inTargetArray {
                for char in line {
                    if char == "{" {
                        if braceCount == 0 {
                            currentItemIndex += 1
                            if currentItemIndex == itemIndex {
                                itemStartLine = lineIdx
                            }
                        }
                        braceCount += 1
                        if currentItemIndex == itemIndex && braceCount == 1 {
                            foundKeyLine = lineIdx
                        }
                    } else if char == "}" {
                        braceCount -= 1
                        if braceCount == 0 && currentItemIndex == itemIndex {
                            itemEndLine = lineIdx
                        }
                    }
                }

                if line.contains("]") && braceCount <= 0 {
                    inTargetArray = false
                }
            }

            if foundKeyLine >= 0 && braceCount == 0 {
                break
            }
        }

        if let field = fieldName, itemStartLine >= 0 {
            let searchEnd = itemEndLine >= 0 ? itemEndLine : min(lines.count, itemStartLine + 20)
            for i in itemStartLine...searchEnd where lines[i].contains("\"\(field)\"") {
                foundKeyLine = i
                break
            }
        }

        if foundKeyLine >= 0 {
            let startLine = max(0, foundKeyLine - 2)
            let endLine = min(lines.count, foundKeyLine + 6)
            var snippet = ""
            for i in startLine..<endLine {
                let marker = (i == foundKeyLine) ? "→ " : "  "
                snippet += "\(marker)\(i + 1): \(lines[i])\n"
            }
            return (foundKeyLine + 1, snippet)
        }

        return (nil, nil)
    }

    /// Hint text for a commonly missing field, or nil.
    static func fieldHint(for fieldName: String) -> String? {
        switch fieldName {
        case "paths":
            return "Add \"paths\": [] to each item. This array lists file paths to monitor for completion."
        case "id":
            return "Add \"id\": \"unique-identifier\" to each item. This must be unique across all items."
        case "displayName":
            return "Add \"displayName\": \"Name\" to each item. This is shown in the UI."
        case "guiIndex":
            return "Add \"guiIndex\": 0 to each item. This determines the display order (0 = first)."
        case "preset":
            return "Add \"preset\": \"preset1\" at the root level. Valid: preset1-6, or named: deployment, cards, compact, toast, portal, self-service, guidance."
        case "items":
            return "Add \"items\": [] at the root level. This array contains the items to display."
        case "title":
            return "Add \"title\": \"Your Title\" at the root level."
        case "guidanceContent":
            return "Add \"guidanceContent\": [] to items that need guidance panels. Array of content blocks."
        case "type":
            return "Add \"type\": \"text\" to guidance content blocks. Types: text, badge, button, spacer, divider, etc."
        case "content":
            return "Add \"content\": \"...\" to guidance content blocks for the display text."
        case "state":
            return "Add \"state\": \"pending\" to badge blocks. States: pending, success, fail, info, etc."
        default:
            return nil
        }
    }

    /// Hint text for a type mismatch; falls back to a generic hint for the expected type.
    static func typeHint(for path: String, expectedType: Any.Type) -> String? {
        let fieldName = path.split(separator: ".").last.map(String.init) ?? ""

        switch fieldName {
        case "guiIndex":
            return "\"guiIndex\" must be a number without quotes. Use guiIndex: 0, not guiIndex: \"0\""
        case "state":
            return "\"state\" must be a string. Use state: \"pending\", not state: 0"
        case "paths":
            return "\"paths\" must be an array. Use paths: [\"/path/to/file\"], not paths: \"/path\""
        case "items":
            return "\"items\" must be an array of objects. Use items: [{...}], not items: {...}"
        case "guidanceContent":
            return "\"guidanceContent\" must be an array. Use guidanceContent: [{...}], not guidanceContent: {...}"
        default:
            let typeStr = String(describing: expectedType)
            if typeStr.contains("Int") {
                return "This field expects a number without quotes."
            } else if typeStr.contains("Bool") {
                return "This field expects true or false without quotes."
            } else if typeStr.contains("String") {
                return "This field expects a string value in quotes."
            } else if typeStr.contains("Array") {
                return "This field expects an array using square brackets []."
            }
            return nil
        }
    }
}

// MARK: - Configuration Service

class Config {
    
}


enum ConfigurationSource: Equatable {
    case file(path: String)
    case testData
    case fallback
}
