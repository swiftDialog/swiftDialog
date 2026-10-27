//
//  InspectState+Validation.swift
//  dialog
//
//  Primary-button gating on required items, and plist validation through `Validation`.
//

import SwiftUI

extension InspectState {
    /// The items the primary button waits for: every item, unless it sets `required: false`.
    var requiredItems: [InspectConfig.ItemConfig] { items.filter { $0.required != false } }

    /// Every required item has completed; optional items never hold the primary button. The
    /// auto-transition to the summary still waits for every item.
    var allRequiredItemsCompleted: Bool {
        !items.isEmpty && requiredItems.allSatisfy { completedItems.contains($0.id) }
    }

    /// Every required item has finished, completed or failed. This releases a held primary button, so a
    /// failed install never leaves the user stuck (as Preset 5's `continueWhileRunning`).
    var allRequiredItemsFinished: Bool {
        !items.isEmpty && requiredItems.allSatisfy { completedItems.contains($0.id) || failedItems.contains($0.id) }
    }

    /// Called whenever `completedItems` or `failedItems` changes.
    func requiredItemsChanged() {
        recordItemOutcome()
        guard allRequiredItemsFinished else { return }
        checkAndUpdateButtonState()
    }

    /// `items.done` / `items.failed` (`StepOutcome`), for every preset with items.
    func recordItemOutcome() {
        guard !items.isEmpty else { return }
        let outcome = StepOutcome.items(items.map(\.id), completed: completedItems, failed: failedItems)
        StepOutcome.record(into: &userValues, scope: StepOutcome.itemsScope,
                           done: outcome.done, failed: outcome.failed)
    }

    func checkAndUpdateButtonState() {
        let totalApps = items.count
        let completedCount = completedItems.count
        
        writeLog("InspectState: Button state check - Total: \(totalApps), Completed: \(completedCount), Required: \(requiredItems.count), AutoEnable: \(buttonConfiguration.autoEnableButton)", logLevel: .info)
        
        if allRequiredItemsFinished {
            writeLog("InspectState: All required items finished (\(completedCount)/\(totalApps) completed, \(failedItems.count) failed)", logLevel: .info)
            
            Task { @MainActor in
                let completedItemsToValidate = items.filter { completedItems.contains($0.id) }
                writeLog("InspectState: Re-validating \(completedItemsToValidate.count) completed items for button state update", logLevel: .info)
                
                for item in completedItemsToValidate {
                    if item.plistKey != nil || plistSources?.contains(where: { source in
                        item.paths.contains(source.path)
                    }) == true {
                        let isValid = validatePlistItem(item)
                        writeLog("InspectState: Re-validated completed item '\(item.id)': \(isValid)", logLevel: .info)
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + InspectConstants.debounceDelay) { [weak self] in
                guard let self = self else { return }
                if self.buttonConfiguration.autoEnableButton {
                    self.buttonConfiguration.button1Text = self.config?.autoEnableButtonText ?? "OK"
                    self.buttonConfiguration.button1Disabled = false
                    writeLog("InspectState: Auto-enabling button with text: \(self.buttonConfiguration.button1Text)", logLevel: .info)
                }
            }
        }
    }
    
    // MARK: - Unified Plist Validation

    /// Validates one plist-backed item and caches the result in `plistValidationResults`.
    @MainActor
    func validatePlistItem(_ item: InspectConfig.ItemConfig) -> Bool {
        writeLog("InspectState: validatePlistItem called for '\(item.id)' (\(item.displayName))", logLevel: .info)
        writeLog("InspectState: Item details - plistKey: '\(item.plistKey ?? "nil")', expectedValue: '\(item.expectedValue ?? "nil")', evaluation: '\(item.evaluation ?? "nil")'", logLevel: .info)
        writeLog("InspectState: Item paths: \(item.paths)", logLevel: .info)
        writeLog("InspectState: iconBasePath for relative path resolution: \(uiConfiguration.iconBasePath ?? "nil")", logLevel: .info)

        // basePath resolves relative entries in item.paths.
        let request = ValidationRequest(
            item: item,
            plistSources: plistSources,
            basePath: uiConfiguration.iconBasePath
        )

        let result = Validation.shared.validateItem(request)
        
        plistValidationResults[item.id] = result.isValid
        
        writeLog("InspectState: Validation result for '\(item.id)': isValid=\(result.isValid), type=\(result.validationType)", logLevel: .info)
        
        if let details = result.details {
            writeLog("InspectState: Validation details - Path: \(details.path), Key: \(details.key ?? "N/A"), Expected: \(details.expectedValue ?? "N/A"), Actual: \(details.actualValue ?? "N/A"), EvalType: \(details.evaluationType ?? "N/A")", logLevel: .info)
        } else {
            writeLog("InspectState: No validation details available for '\(item.id)'", logLevel: .info)
        }
        
        return result.isValid
    }
    
    // MARK: - Validation Initialization
    
    /// Validates every item, streaming each result into `plistValidationResults` as it lands.
    /// Never blocks the main thread.
    func validateAllItems() {
        writeLog("InspectState: Starting async validation of \(items.count) items", logLevel: .info)

        // Sorted by category so cards complete top to bottom.
        let sortedItems = items.sorted { item1, item2 in
            let cat1 = item1.category ?? getCategoryPrefix(item1.id)
            let cat2 = item2.category ?? getCategoryPrefix(item2.id)
            return cat1 < cat2
        }

        for item in sortedItems {
            writeLog("InspectState: Will validate item '\(item.id)' - plistKey: '\(item.plistKey ?? "nil")', expectedValue: '\(item.expectedValue ?? "nil")', evaluation: '\(item.evaluation ?? "nil")'", logLevel: .debug)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            Validation.shared.validateItemsBatchStreaming(
                sortedItems,
                plistSources: self.plistSources,
                basePath: self.uiConfiguration.iconBasePath,
                onPreCacheProgress: { [weak self] loaded, total in
                    self?.preCacheProgress = (loaded, total)
                },
                onItemValidated: { [weak self] itemId, isValid in
                    if self?.preCacheProgress != nil {
                        self?.preCacheProgress = nil
                    }
                    self?.plistValidationResults[itemId] = isValid
                },
                completion: { [weak self] results in
                    guard let self = self else { return }
                    writeLog("InspectState: Streaming validation complete. \(results.filter { $0.value }.count) valid items out of \(results.count) total", logLevel: .info)

                    self.preCacheProgress = nil
                }
            )
        }
    }

    /// The id's first "_" segment ("os_gatekeeper_enable" → "os"), the sort key when no category is set.
    private func getCategoryPrefix(_ itemId: String) -> String {
        let parts = itemId.components(separatedBy: "_")
        if let first = parts.first, !first.isEmpty {
            return first.lowercased()
        }
        return itemId
    }

}
