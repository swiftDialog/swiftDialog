//
//  Validation+CachedChecks.swift
//  dialog
//
//  Validation extension: plist checks, through the cache (async) and by direct read (sync).
//

import Foundation

extension Validation {
    // MARK: - Cached Checks

    func validateSimplePlistItemCachedAsync(_ item: InspectConfig.ItemConfig, basePath: String? = nil) async -> ValidationResult {
        guard let plistKey = item.plistKey else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .plistValidation, details: nil)
        }

        for path in item.paths {
            let resolvedPath = resolvePlistPath(path, basePath: basePath)
            if let plist = await loadPlistCachedAsync(at: path, basePath: basePath) {
                let result = validatePlistValue(plist: plist, key: plistKey,
                                               expectedValue: item.expectedValue,
                                               evaluation: item.evaluation)
                if result {
                    let actualValue = extractPlistValue(from: plist, key: plistKey)
                    return ValidationResult(
                        itemId: item.id,
                        isValid: true,
                        validationType: .plistValidation,
                        details: ValidationDetails(
                            path: resolvedPath,
                            key: plistKey,
                            expectedValue: item.expectedValue,
                            actualValue: formatValueForDisplay(actualValue),
                            evaluationType: item.evaluation
                        )
                    )
                }
            }
        }

        return ValidationResult(
            itemId: item.id,
            isValid: false,
            validationType: .plistValidation,
            details: nil
        )
    }

    func validateComplexPlistItemCachedAsync(_ item: InspectConfig.ItemConfig, source: InspectConfig.PlistSourceConfig) async -> ValidationResult {
        guard let plist = await loadPlistCachedAsync(at: source.path) else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
        }

        if let criticalKeys = source.criticalKeys {
            for key in criticalKeys where !checkNestedKey(key, in: plist, expectedValues: source.successValues) {
                return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
            }
        }

        return ValidationResult(itemId: item.id, isValid: true, validationType: .complexPlistValidation, details: nil)
    }

    /// Walks a dotted key path (array indices as numbers, at most 20 levels) and evaluates the value.
    func validatePlistValue(plist: [String: Any], key: String, expectedValue: String?, evaluation: String?) -> Bool {
        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist

        guard keyParts.count <= 20 else {
            writeLog("ValidationService: Key '\(key)' has too many nested levels (\(keyParts.count))", logLevel: .error)
            return false
        }

        for (index, keyPart) in keyParts.enumerated() {
            guard !keyPart.isEmpty else { continue }

            guard keyPart.count < 1000 else {
                writeLog("ValidationService: Key part '\(keyPart)' is too long", logLevel: .error)
                return false
            }
            
            if let dict = current as? [String: Any] {
                guard let next = dict[keyPart] else { 
                    writeLog("ValidationService: Dictionary key '\(keyPart)' not found at level \(index) in '\(key)'", logLevel: .debug)
                    return false 
                }
                current = next
            } else if let array = current as? [Any], let index = Int(keyPart) {
                guard index >= 0 && index < array.count else {
                    writeLog("ValidationService: Array index \(index) out of bounds (size: \(array.count)) for key '\(key)'", logLevel: .debug)
                    return false
                }
                current = array[index]
            } else {
                writeLog("ValidationService: Invalid navigation - expected dict or array, got \(type(of: current)) for key part '\(keyPart)' in '\(key)'", logLevel: .debug)
                return false
            }

            if current is NSNull {
                writeLog("ValidationService: Encountered NSNull at key part '\(keyPart)' in '\(key)'", logLevel: .debug)
                return false
            }
        }

        return performSmartEvaluation(
            value: current,
            evaluationType: EvaluationOperator
                .resolve(evaluation: evaluation, expectedValue: expectedValue)?.rawValue
                ?? (evaluation ?? ""),
            expectedValue: expectedValue,
            key: key
        )
    }

    /// The value at a dotted key path, or `NSNull` when the path does not resolve.
    func extractPlistValue(from plist: [String: Any], key: String) -> Any {
        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist

        guard keyParts.count <= 20 else {
            writeLog("ValidationService: Key '\(key)' has too many nested levels (\(keyParts.count))", logLevel: .error)
            return NSNull()
        }

        for keyPart in keyParts {
            guard !keyPart.isEmpty else { continue }

            guard keyPart.count < 1000 else {
                writeLog("ValidationService: Key part '\(keyPart)' is too long", logLevel: .error)
                return NSNull()
            }

            if let dict = current as? [String: Any] {
                current = dict[keyPart] ?? NSNull()
            } else if let array = current as? [Any], let index = Int(keyPart) {
                guard index >= 0 && index < array.count else {
                    return NSNull()
                }
                current = array[index]
            } else {
                return NSNull()
            }
        }

        return current
    }

    func validateSimplePlistItem(_ item: InspectConfig.ItemConfig, basePath: String? = nil) -> ValidationResult {
        guard let plistKey = item.plistKey else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .plistValidation, details: nil)
        }

        for path in item.paths {
            let resolvedPath = resolvePlistPath(path, basePath: basePath)
            if let result = checkSimplePlistKey(at: path, key: plistKey, expectedValue: item.expectedValue, evaluation: item.evaluation, basePath: basePath) {
                let actualValue = getPlistValue(at: path, key: plistKey, basePath: basePath)
                let details = ValidationDetails(
                    path: resolvedPath,
                    key: plistKey,
                    expectedValue: item.expectedValue,
                    actualValue: actualValue,
                    evaluationType: item.evaluation
                )

                return ValidationResult(
                    itemId: item.id,
                    isValid: result,
                    validationType: .plistValidation,
                    details: details
                )
            }
        }

        // No path's plist could be read.
        let firstPath = item.paths.first ?? ""
        let resolvedFirstPath = resolvePlistPath(firstPath, basePath: basePath)
        return ValidationResult(
            itemId: item.id,
            isValid: false,
            validationType: .plistValidation,
            details: ValidationDetails(
                path: resolvedFirstPath,
                key: plistKey,
                expectedValue: item.expectedValue,
                actualValue: nil,
                evaluationType: item.evaluation
            )
        )
    }
    
    func validateComplexPlistItem(_ item: InspectConfig.ItemConfig, source: InspectConfig.PlistSourceConfig) -> ValidationResult {
        let expandedPath = (source.path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath),
              let data = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
        }

        if let criticalKeys = source.criticalKeys {
            for key in criticalKeys where !checkNestedKey(key, in: plist, expectedValues: source.successValues) {
                return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
            }
        }
        
        return ValidationResult(itemId: item.id, isValid: true, validationType: .complexPlistValidation, details: nil)
    }
    
}
