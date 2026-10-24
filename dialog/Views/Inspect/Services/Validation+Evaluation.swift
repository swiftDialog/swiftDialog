//
//  Validation+Evaluation.swift
//  dialog
//
//  Validation extension: the evaluation operators and the canonical value-to-string helpers.
//

import Foundation

// MARK: - Canonical Value Stringification

/// The one place a plist, JSON or UserDefaults scalar becomes a display string; nil for containers,
/// NSNull and unknown types. Booleans are told from numbers by `CFGetTypeID`, since bridging lets a
/// `CFBoolean` pass `as? Int` and a 0/1 number pass `as? Bool`. Nonisolated so monitors can call it.
func canonicalScalarString(_ value: Any) -> String? {
    if CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID() {
        return (value as? Bool) == true ? "true" : "false"
    }
    if let stringValue = value as? String {
        return stringValue
    }
    if let dateValue = value as? Date {
        return DateDisplayService.shared.format(dateValue)
    }
    if let intValue = value as? Int {
        return String(intValue)
    }
    if let doubleValue = value as? Double {
        return String(doubleValue)
    }
    return nil
}

/// `value` through a monitor's `valueMap`, also trying the boolean alias ("true"/"1", "false"/"0") so
/// configs that map a boolean key by its numeric form keep working. nil when nothing matches.
func mapMonitorValue(_ value: String, through valueMap: [String: String]?) -> String? {
    guard let valueMap else { return nil }
    if let mapped = valueMap[value] {
        return mapped
    }
    guard let alias = booleanAliasForValueMap(value) else { return nil }
    return valueMap[alias]
}

private func booleanAliasForValueMap(_ value: String) -> String? {
    switch value {
    case "true": return "1"
    case "1": return "true"
    case "false": return "0"
    case "0": return "false"
    default: return nil
    }
}

extension Validation {
    // MARK: - Evaluation

    /// Evaluates a dotted key path ("Sets.0.URL") in a plist file; nil when the file cannot be read.
    func checkSimplePlistKey(at path: String, key: String, expectedValue: String?, evaluation: String? = nil, basePath: String? = nil) -> Bool? {
        let resolvedPath = resolvePlistPath(path, basePath: basePath)
        let expandedPath = (resolvedPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath),
              let data = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist

        for keyPart in keyParts {
            guard !keyPart.isEmpty else { continue }

            if let dict = current as? [String: Any] {
                guard let nextValue = dict[keyPart] else {
                    writeLog("ValidationService: Key part '\(keyPart)' not found in path '\(key)'", logLevel: .info)
                    return false
                }
                current = nextValue
            } else if let array = current as? [Any], let index = Int(keyPart) {
                guard index >= 0 && index < array.count else {
                    writeLog("ValidationService: Array index '\(index)' out of bounds for key '\(key)'", logLevel: .info)
                    return false
                }
                current = array[index]
            } else {
                writeLog("ValidationService: Key part '\(keyPart)' not found in path '\(key)'", logLevel: .info)
                return false
            }

            if current is NSNull {
                writeLog("ValidationService: Key '\(key)' is NSNull", logLevel: .info)
                return false
            }
        }

        // The default operator derives from what the author supplied, the same as on the poller paths.
        let evaluationType = EvaluationOperator
            .resolve(evaluation: evaluation, expectedValue: expectedValue)?.rawValue
            ?? (evaluation ?? "")
        
        return performSmartEvaluation(
            value: current,
            evaluationType: evaluationType,
            expectedValue: expectedValue,
            key: key
        )
    }
    
    /// Applies an `EvaluationOperator` to a value; an unknown operator name is not satisfied.
    /// Internal so the monitors share these operators.
    func performSmartEvaluation(value: Any, evaluationType: String, expectedValue: String?, key: String) -> Bool {
        if value is NSNull {
            writeLog("ValidationService: Key '\(key)', Value is NSNull, Result: false", logLevel: .info)
            return false
        }

        guard let op = EvaluationOperator(authored: evaluationType) else {
            writeLog("Validation: Key '\(key)', unknown evaluation '\(evaluationType)' — "
                     + "treating as not satisfied", logLevel: .error)
            return false
        }

        switch op {
        case .exists:
            let result = !(value is NSNull)
            writeLog("ValidationService: Key '\(key)', Evaluation 'exists', Result: \(result)", logLevel: .info)
            return result
            
        case .boolean:
            guard let expectedValue = expectedValue else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'boolean' requires expectedValue", logLevel: .error)
                return false
            }
            
            let expectedBool = parseSmartBoolean(expectedValue)
            let actualBool = parseSmartBoolean(value)
            let result = actualBool == expectedBool
            writeLog("ValidationService: Key '\(key)', Expected bool '\(expectedBool)', Actual bool '\(actualBool)', Result: \(result)", logLevel: .info)
            return result
            
        case .contains:
            // Membership for an array, substring for a string; shared with the other engines.
            guard let expectedValue = expectedValue else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'contains' requires expectedValue", logLevel: .error)
                return false
            }

            let result = EvaluationOperator.containsMatch(value: value, expected: expectedValue)
            let shape = value is [Any] ? "membership" : "substring"
            writeLog("ValidationService: Key '\(key)', contains '\(expectedValue)' (\(shape)), Result: \(result)", logLevel: .info)
            return result


        case .range:
            // expectedValue is "min-max".
            guard let expectedValue = expectedValue, expectedValue.contains("-") else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'range' requires format 'min-max'", logLevel: .error)
                return false
            }

            let rangeParts = expectedValue.components(separatedBy: "-")
            guard rangeParts.count == 2,
                  let minValue = Double(rangeParts[0]),
                  let maxValue = Double(rangeParts[1]) else {
                writeLog("ValidationService: Key '\(key)', Invalid range format '\(expectedValue)'", logLevel: .error)
                return false
            }

            let actualNumber: Double?
            if let intVal = value as? Int {
                actualNumber = Double(intVal)
            } else if let doubleVal = value as? Double {
                actualNumber = doubleVal
            } else if let floatVal = value as? Float {
                actualNumber = Double(floatVal)
            } else if let nsNumber = value as? NSNumber {
                actualNumber = nsNumber.doubleValue
            } else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'range' requires numeric value, got: \(type(of: value))", logLevel: .error)
                return false
            }

            guard let number = actualNumber else {
                return false
            }

            let result = number >= minValue && number <= maxValue
            writeLog("ValidationService: Key '\(key)', Value \(number) in range \(minValue)-\(maxValue), Result: \(result)", logLevel: .info)
            return result

        case .withinSeconds:
            // expectedValue is a number of seconds; the value may be a Date, a Unix timestamp or a date string.
            guard let expectedValue = expectedValue, let maxSeconds = Double(expectedValue) else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'withinSeconds' requires numeric expectedValue (seconds)", logLevel: .error)
                return false
            }

            let now = Date()
            var parsedDate: Date?

            if let dateValue = value as? Date {
                parsedDate = dateValue
            }

            if parsedDate == nil, let timestamp = value as? Double {
                parsedDate = Date(timeIntervalSince1970: timestamp)
            }
            if parsedDate == nil, let timestamp = value as? Int {
                parsedDate = Date(timeIntervalSince1970: Double(timestamp))
            }
            if parsedDate == nil, let nsNumber = value as? NSNumber {
                parsedDate = Date(timeIntervalSince1970: nsNumber.doubleValue)
            }

            if parsedDate == nil, let stringValue = value as? String {
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                parsedDate = iso8601Formatter.date(from: stringValue)

                if parsedDate == nil {
                    iso8601Formatter.formatOptions = [.withInternetDateTime]
                    parsedDate = iso8601Formatter.date(from: stringValue)
                }

                if parsedDate == nil {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")

                    let formats = [
                        "yyyy-MM-dd'T'HH:mm:ssZ",
                        "yyyy-MM-dd HH:mm:ss Z",
                        "yyyy-MM-dd HH:mm:ss",
                        "MMM d, yyyy 'at' h:mm:ss a",
                        "MMM d, yyyy, h:mm:ss a"
                    ]

                    for format in formats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: stringValue) {
                            parsedDate = date
                            break
                        }
                    }
                }

                if parsedDate == nil, let timestamp = Double(stringValue) {
                    parsedDate = Date(timeIntervalSince1970: timestamp)
                }
            }

            guard let date = parsedDate else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'withinSeconds' could not parse date from '\(value)'", logLevel: .error)
                return false
            }

            let secondsAgo = now.timeIntervalSince(date)
            let isWithin = secondsAgo >= 0 && secondsAgo <= maxSeconds
            writeLog("ValidationService: Key '\(key)', withinSeconds check - date=\(date), secondsAgo=\(secondsAgo), maxSeconds=\(maxSeconds), pass=\(isWithin)", logLevel: .debug)
            return isWithin

        case .changed:
            // Needs a baseline across two reads; this engine reads once.
            writeLog("Validation: Key '\(key)', evaluation 'changed' is only "
                     + "supported by the installation-detection poller", logLevel: .error)
            return false

        case .equals:
            guard let expectedValue = expectedValue else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'equals' requires expectedValue", logLevel: .error)
                return false
            }

            // Exact string equality on the canonical form the display path shows (integer 1 is "1",
            // a boolean is "true"); `boolean` is the operator for 1/yes/true equivalence.
            let actualValue = formatValueForDisplay(value)
            let result = actualValue == expectedValue

            writeLog("ValidationService: Key '\(key)', Expected '\(expectedValue)', Actual '\(actualValue)', Result: \(result)", logLevel: .info)
            return result
        }
    }
    
    // MARK: - Helpers

    /// true for `true`, "true"/"yes"/"1" (any case), 1 and 1.0.
    func parseSmartBoolean(_ value: Any) -> Bool {
        if let boolValue = value as? Bool {
            return boolValue
        } else if let stringValue = value as? String {
            let lower = stringValue.lowercased()
            return lower == "true" || lower == "yes" || lower == "1"
        } else if let intValue = value as? Int {
            return intValue == 1
        } else if let doubleValue = value as? Double {
            return doubleValue == 1.0
        }
        return false
    }
    
    /// Display string for any plist value: scalars via `canonicalScalarString`, containers as counts.
    func formatValueForDisplay(_ value: Any) -> String {
        if value is NSNull {
            return "null"
        }

        if let scalar = canonicalScalarString(value) {
            return scalar
        }

        if let arrayValue = value as? [Any] {
            return "[\(arrayValue.count) items]"
        } else if let dictValue = value as? [String: Any] {
            return "{\(dictValue.keys.count) keys}"
        } else if let floatValue = value as? Float {
            return String(floatValue)
        } else if let nsNumber = value as? NSNumber {
            return nsNumber.stringValue
        }

        return String(describing: value)
    }

    /// Whether the value at a dotted key path exists and, when `expectedValues` is given, is one of them.
    /// A "*" component accepts anything below it.
    func checkNestedKey(_ keyPath: String, in dict: [String: Any], expectedValues: [String]?) -> Bool {
        let components = keyPath.split(separator: ".")
        var current: Any = dict

        for component in components {
            let componentStr = String(component)

            if component == "*" {
                return true
            }

            guard let currentDict = current as? [String: Any] else {
                return false
            }

            guard let nextValue = currentDict[componentStr] else {
                return false
            }

            current = nextValue
        }

        if let expectedValues = expectedValues {
            if let stringValue = current as? String {
                return expectedValues.contains(stringValue)
            } else if let intValue = current as? Int {
                return expectedValues.contains(String(intValue))
            } else if let boolValue = current as? Bool {
                return expectedValues.contains(String(boolValue))
            } else {
                return expectedValues.contains(String(describing: current))
            }
        }
        
        return true
    }
}
