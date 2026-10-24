//
//  Validation+API.swift
//  dialog
//
//  Validation extension: the batch entry points (async, completion, streaming) and `withTimeout`.
//

import Foundation

extension Validation {
    // MARK: - Public API

    /// Validates all items, at most 12 at a time, 10 s each; publishes `validationProgress` as they finish.
    func validateItemsBatch(_ items: [InspectConfig.ItemConfig],
                           plistSources: [InspectConfig.PlistSourceConfig]? = nil,
                           basePath: String? = nil) async -> [String: Bool] {

        isValidating = true
        validationProgress = 0.0

        defer {
            isValidating = false
            validationProgress = 1.0
        }

        await withTimeout(seconds: 30.0) { [weak self] in
            await self?.preCachePlistsAsync(from: items, and: plistSources)
        }

        let totalItems = items.count
        var results = [String: Bool]()

        await withTaskGroup(of: (String, Bool).self, returning: Void.self) { group in
            let maxConcurrency = min(12, items.count)
            var currentIndex = 0

            for _ in 0..<min(maxConcurrency, items.count) where currentIndex < items.count {
                let item = items[currentIndex]
                currentIndex += 1
                
                group.addTask(priority: .userInitiated) { [weak self] in
                    guard let self = self else { return (item.id, false) }

                    let result = await withTimeout(seconds: 10.0) { [weak self] in
                        guard let self = self else { return ValidationResult(itemId: item.id, isValid: false, validationType: .fileExistence, details: nil) }
                        let request = ValidationRequest(item: item, plistSources: plistSources, basePath: basePath)
                        return await self.validateItemCachedAsync(request)
                    }
                    return (item.id, result?.isValid ?? false)
                }
            }
            
            while let (itemId, isValid) = await group.next() {
                results[itemId] = isValid

                let progress = Double(results.count) / Double(totalItems)
                await MainActor.run {
                    self.validationProgress = progress
                }

                if currentIndex < items.count {
                    let nextItem = items[currentIndex]
                    currentIndex += 1

                    group.addTask(priority: .userInitiated) { [weak self] in
                        guard let self = self else { return (nextItem.id, false) }

                        let result = await withTimeout(seconds: 10.0) { [weak self] in
                            guard let self = self else { return ValidationResult(itemId: nextItem.id, isValid: false, validationType: .fileExistence, details: nil) }
                            let request = ValidationRequest(item: nextItem, plistSources: plistSources, basePath: basePath)
                            return await self.validateItemCachedAsync(request)
                        }
                        
                        return (nextItem.id, result?.isValid ?? false)
                    }
                }
            }
        }
        
        return results
    }
    
    // MARK: - Timeout

    /// Runs `operation` against a timer in a task group; nil when the timer wins. `T` must be
    /// `Sendable` because the result crosses back to the caller's actor.
    func withTimeout<T: Sendable>(seconds: TimeInterval,
                                  operation: @escaping @Sendable () async -> T?) async -> T? {
        return await withTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }

            group.addTask {
                do {
                    try await Task.sleep(for: .seconds(seconds))
                    return nil
                } catch {
                    return nil
                }
            }

            // swiftlint:disable:next redundant_nil_coalescing
            let result = await group.next() ?? nil  // Flatten T?? to T?
            group.cancelAll()
            return result
        }
    }

    /// Completion-based wrapper around the async batch.
    func validateItemsBatch(_ items: [InspectConfig.ItemConfig],
                           plistSources: [InspectConfig.PlistSourceConfig]? = nil,
                           basePath: String? = nil,
                           completion: @escaping ([String: Bool]) -> Void) {

        Task { @MainActor in
            let results = await validateItemsBatch(items, plistSources: plistSources, basePath: basePath)
            completion(results)
        }
    }

    /// Batch validation that reports each item through `onItemValidated` as it finishes;
    /// `onPreCacheProgress` reports the plist pre-cache phase.
    func validateItemsBatchStreaming(_ items: [InspectConfig.ItemConfig],
                                    plistSources: [InspectConfig.PlistSourceConfig]? = nil,
                                    basePath: String? = nil,
                                    // Called from `MainActor.run`; its caller writes main-actor state.
                                    onPreCacheProgress: (@MainActor @Sendable (Int, Int) -> Void)? = nil,
                                    onItemValidated: @escaping (String, Bool) -> Void,
                                    completion: @escaping ([String: Bool]) -> Void) {

        Task { @MainActor in
            isValidating = true
            validationProgress = 0.0

            defer {
                isValidating = false
                validationProgress = 1.0
            }

            await withTimeout(seconds: 30.0) {
                await self.preCachePlistsAsyncWithProgress(from: items, and: plistSources, onProgress: onPreCacheProgress)
            }

            let totalItems = items.count
            var results = [String: Bool]()

            await withTaskGroup(of: (String, Bool).self, returning: Void.self) { group in
                let maxConcurrency = min(12, items.count)
                var currentIndex = 0

                for _ in 0..<min(maxConcurrency, items.count) where currentIndex < items.count {
                    let item = items[currentIndex]
                    currentIndex += 1

                    group.addTask(priority: .userInitiated) {
                        let result = await self.withTimeout(seconds: 10.0) {
                            let request = ValidationRequest(item: item, plistSources: plistSources, basePath: basePath)
                            return await self.validateItemCachedAsync(request)
                        }
                        return (item.id, result?.isValid ?? false)
                    }
                }

                while let (itemId, isValid) = await group.next() {
                    results[itemId] = isValid

                    await MainActor.run {
                        onItemValidated(itemId, isValid)
                        self.validationProgress = Double(results.count) / Double(totalItems)
                    }

                    if currentIndex < items.count {
                        let nextItem = items[currentIndex]
                        currentIndex += 1

                        group.addTask(priority: .userInitiated) {
                            let result = await self.withTimeout(seconds: 10.0) {
                                let request = ValidationRequest(item: nextItem, plistSources: plistSources, basePath: basePath)
                                return await self.validateItemCachedAsync(request)
                            }
                            return (nextItem.id, result?.isValid ?? false)
                        }
                    }
                }
            }

            completion(results)
        }
    }

    /// One item through the plist cache: `plistKey` check, else a matching plist source, else file existence.
    func validateItemCachedAsync(_ request: ValidationRequest) async -> ValidationResult {
        let item = request.item

        if item.plistKey != nil {
            return await validateSimplePlistItemCachedAsync(item, basePath: request.basePath)
        }

        if let plistSources = request.plistSources {
            for source in plistSources where item.paths.contains(source.path) {
                return await validateComplexPlistItemCachedAsync(item, source: source)
            }
        }

        return validateFileExistence(item, basePath: request.basePath)
    }

    /// Synchronous `validateItemCachedAsync`, reading plists directly.
    func validateItem(_ request: ValidationRequest) -> ValidationResult {
        let item = request.item

        if item.plistKey != nil {
            return validateSimplePlistItem(item, basePath: request.basePath)
        }

        if let plistSources = request.plistSources {
            for source in plistSources where item.paths.contains(source.path) {
                return validateComplexPlistItem(item, source: source)
            }
        }

        return validateFileExistence(item, basePath: request.basePath)
    }
}
