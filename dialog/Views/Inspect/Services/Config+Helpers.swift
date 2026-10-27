//
//  Config+Helpers.swift
//  dialog
//
//  Config extension: plist auto-discovery, item defaults and the configuration warnings.
//

import Foundation

extension Config {
    // MARK: - Internal Helper Methods
    
    func getConfigPath(from environmentVariable: String) -> String? {
        guard let path = ProcessInfo.processInfo.environment[environmentVariable] else {
            return nil
        }
        return path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func applyConfigurationDefaults(to config: InspectConfig) -> InspectConfig {
        var processedConfig = config

        // `chrome` stays authored-only; its preset default lives in `InspectSizes.Construction.resolve`.

        if let plistSources = config.plistSources {
            var discoveredItems: [InspectConfig.ItemConfig] = []

            for source in plistSources where source.autoDiscover == true {
                let items = discoverItemsFromPlist(source: source, basePath: config.iconBasePath)
                discoveredItems.append(contentsOf: items)
                writeLog("ConfigurationService: Auto-discovered \(items.count) items from \(source.path)", logLevel: .info)
            }

            // Authored items win over discovered ones with the same ID.
            if !discoveredItems.isEmpty {
                let existingIds = Set(processedConfig.items.map { $0.id })
                let newItems = discoveredItems.filter { !existingIds.contains($0.id) }
                processedConfig.items.append(contentsOf: newItems)
                writeLog("ConfigurationService: Total items after auto-discovery: \(processedConfig.items.count)", logLevel: .info)
            }
        }

        processedConfig.items.sort { $0.guiIndex < $1.guiIndex }

        return processedConfig
    }

    /// Mints one item per finding in a compliance-findings plist (each top-level key holding a `finding` subkey).
    func discoverItemsFromPlist(source: InspectConfig.PlistSourceConfig, basePath: String?) -> [InspectConfig.ItemConfig] {
        var items: [InspectConfig.ItemConfig] = []

        var plistPath = source.path
        if !plistPath.hasPrefix("/") && !plistPath.hasPrefix("~") {
            if let basePath = basePath, !basePath.isEmpty {
                plistPath = (basePath as NSString).appendingPathComponent(source.path)
            }
        }
        plistPath = (plistPath as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: plistPath) else {
            writeLog("ConfigurationService: Auto-discover plist not found: \(plistPath)", logLevel: .error)
            return items
        }

        guard let plistData = FileManager.default.contents(atPath: plistPath),
              let plistDict = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            writeLog("ConfigurationService: Failed to parse plist for auto-discovery: \(plistPath)", logLevel: .error)
            return items
        }

        // Synthesis defaults, not read-side ones: findings plists mean `finding == false` is compliant,
        // and `boolean` (not `equals`) is what reads a real plist boolean. Do not route through
        // `EvaluationOperator.resolve`.
        let findingKey = source.findingKey ?? "finding"
        let expectedValue = source.expectedValue ?? "false"   // census:synthesis
        let evaluation = source.evaluation ?? "boolean"       // census:synthesis

        // Logged once per source, only when the config left a default to us.
        if source.evaluation == nil || source.expectedValue == nil {
            writeLog("ConfigurationService: \(source.path): auto-discovery defaults — "
                     + "evaluation=\(evaluation), expectedValue=\(expectedValue) "
                     + "(finding=false ⇒ compliant). Author both keys to override.",
                     logLevel: .info)
        }
        let excludeKeys = Set(source.excludeKeys ?? ["lastComplianceCheck", "profileIdentifier", "scanDate"])

        var includeRegex: NSRegularExpression?
        if let pattern = source.includePattern {
            includeRegex = try? NSRegularExpression(pattern: pattern, options: [])
        }

        var guiIndex = 0
        for (key, value) in plistDict.sorted(by: { $0.key < $1.key }) {
            if excludeKeys.contains(key) { continue }

            if let regex = includeRegex {
                let range = NSRange(key.startIndex..<key.endIndex, in: key)
                if regex.firstMatch(in: key, options: [], range: range) == nil { continue }
            }

            guard let valueDict = value as? [String: Any],
                  valueDict[findingKey] != nil else {
                continue
            }

            let category = getCategoryFromKey(key, categoryPrefix: source.categoryPrefix)
            let displayName = formatDisplayName(key, categoryPrefix: source.categoryPrefix)
            let icon = getIconForKey(key, category: category, sourceIcon: source.icon, categoryIcons: source.categoryIcons)

            var finalDisplayName = displayName
            var finalCategory = category
            if let mapping = source.keyMappings?.first(where: { $0.key == key }) {
                if let mappedName = mapping.displayName { finalDisplayName = mappedName }
                if let mappedCategory = mapping.category { finalCategory = mappedCategory }
            }

            let item = InspectConfig.ItemConfig(
                id: key,
                displayName: finalDisplayName,
                icon: icon,
                paths: [source.path],
                guiIndex: guiIndex,
                category: finalCategory,
                categoryIcon: nil,
                plistKey: "\(key).\(findingKey)",
                expectedValue: expectedValue,
                evaluation: evaluation
            )

            items.append(item)
            guiIndex += 1
        }

        return items
    }

    /// Category for a finding key: the config's prefix map first, then the built-in prefixes.
    func getCategoryFromKey(_ key: String, categoryPrefix: [String: String]?) -> String {
        if let prefixes = categoryPrefix {
            for (prefix, category) in prefixes where key.hasPrefix(prefix) {
                return category
            }
        }

        if key.hasPrefix("audit_") { return "Audit Controls" }
        if key.hasPrefix("auth_") { return "Authentication" }
        if key.hasPrefix("icloud_") { return "iCloud Security" }
        if key.hasPrefix("os_") { return "OS Security" }
        if key.hasPrefix("pwpolicy_") { return "Password Policy" }
        if key.hasPrefix("system_settings_") { return "System Settings" }
        if key.hasPrefix("sysprefs_") { return "System Preferences" }

        return "Other"
    }

    /// Display name for a finding key: prefix stripped, title-cased, common acronyms restored.
    func formatDisplayName(_ key: String, categoryPrefix: [String: String]?) -> String {
        var name = key

        let prefixes = ["audit_", "auth_", "icloud_", "os_", "pwpolicy_", "system_settings_", "sysprefs_"]
        for prefix in prefixes where name.hasPrefix(prefix) {
            name = String(name.dropFirst(prefix.count))
            break
        }

        name = name.replacingOccurrences(of: "_", with: " ")
            .capitalized
            .replacingOccurrences(of: "Ssh", with: "SSH")
            .replacingOccurrences(of: "Mdm", with: "MDM")
            .replacingOccurrences(of: "Sip", with: "SIP")
            .replacingOccurrences(of: "Airdrop", with: "AirDrop")
            .replacingOccurrences(of: "Icloud", with: "iCloud")
            .replacingOccurrences(of: "Httpd", with: "HTTP Server")
            .replacingOccurrences(of: "Nfsd", with: "NFS Server")
            .replacingOccurrences(of: "Smbd", with: "SMB Server")
            .replacingOccurrences(of: "Tftpd", with: "TFTP Server")
            .replacingOccurrences(of: "Usb", with: "USB")
            .replacingOccurrences(of: "Wifi", with: "WiFi")

        return name
    }

    /// Icon for a category: config-provided icons, then built-in ones, then the source icon.
    func getIconForKey(_ key: String, category: String, sourceIcon: String?, categoryIcons configIcons: [String: String]?) -> String {
        if let configIcons = configIcons, let icon = configIcons[category] {
            return icon
        }

        let defaultCategoryIcons: [String: String] = [
            "OS Security": "sf=shield.fill,colour1=#007AFF",
            "iCloud Security": "sf=icloud.fill,colour1=#007AFF",
            "Authentication": "sf=person.badge.key.fill,colour1=#5856D6",
            "Audit Controls": "sf=doc.text.magnifyingglass,colour1=#8E8E93",
            "Password Policy": "sf=key.fill,colour1=#FF9500",
            "System Settings": "sf=gearshape.fill,colour1=#8E8E93",
            "System Preferences": "sf=gearshape.fill,colour1=#8E8E93"
        ]

        return defaultCategoryIcons[category] ?? sourceIcon ?? "sf=shield.fill,colour1=#007AFF"
    }
    
    /// The colour slots of a brand palette with their authored values. Listed by hand: `logos` and
    /// `custom` hold non-colour strings and must not be checked.
    private func paletteColourSlots(_ p: InspectConfig.BrandPalette)
        -> [(name: String, value: String?)] {
        [("primary", p.primary), ("secondary", p.secondary), ("accent", p.accent),
         ("success", p.success), ("warning", p.warning), ("error", p.error), ("info", p.info),
         ("background", p.background), ("surface", p.surface), ("surfaceLight", p.surfaceLight),
         ("textPrimary", p.textPrimary), ("textSecondary", p.textSecondary)]
    }

    /// Whether `Color(hex:)` reads this string as intended: 3, 6 or 8 hex digits, optional `#`.
    /// That initialiser is not failable and paints anything else black, so the check lives here.
    private func isReadableHexColour(_ raw: String) -> Bool {
        let body = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        guard [3, 6, 8].contains(body.count) else { return false }
        return body.allSatisfy(\.isHexDigit)
    }

    /// Warnings for brand-palette values that would render black.
    func validateBrandPalettes(_ config: InspectConfig) -> [String] {
        var warnings: [String] = []
        for (label, palette) in [("brandPalette", config.brandPalette),
                                 ("brandPaletteDark", config.brandPaletteDark)] {
            guard let palette else { continue }
            for slot in paletteColourSlots(palette) {
                guard let raw = slot.value else { continue }
                if !isReadableHexColour(raw) {
                    warnings.append(
                        "\(label).\(slot.name): '\(raw)' is not a readable hex colour — expected "
                        + "3, 6 or 8 hex digits with an optional '#'. It will render as black, not "
                        + "as the default.")
                }
            }
        }
        return warnings
    }

    func validateConfiguration(_ config: InspectConfig) -> [String] {
        var warnings: [String] = []
        warnings.append(contentsOf: validateBrandPalettes(config))
        
        // A step flow carries its content in `introSteps` / `steps`, so no items is not "empty".
        let isStepFlow = !(config.introSteps ?? config.steps ?? []).isEmpty

        if config.items.isEmpty && config.plistSources?.isEmpty != false && !isStepFlow {
            warnings.append("Configuration has no items or plist sources")
        }
        
        if InspectPresetName.number(config.preset) == nil {
            warnings.append("Unknown preset '\(config.preset)' - will default to preset1")
        }
        
        if let iconPath = config.icon,
           !IconRef.isSymbolReference(iconPath),
           !FileManager.default.fileExists(atPath: iconPath) {
            warnings.append("Icon file not found: \(iconPath)")
        }
        
        if let backgroundImage = config.backgroundImage, !FileManager.default.fileExists(atPath: backgroundImage) {
            warnings.append("Background image not found: \(backgroundImage)")
        }
        
        if let thresholds = config.colorThresholds {
            if thresholds.excellent <= thresholds.good || thresholds.good <= thresholds.warning {
                warnings.append("Color thresholds should be in descending order (excellent > good > warning)")
            }
        }

        if !config.items.isEmpty {
            let guiIndexWarnings = validateGuiIndexSequence(config.items)
            warnings.append(contentsOf: guiIndexWarnings)
        }

        let itemWarnings = validateItems(config.items, preset: config.preset)
        warnings.append(contentsOf: itemWarnings)

        let presetWarnings = validatePresetSpecific(config)
        warnings.append(contentsOf: presetWarnings)

        for warning in warnings {
            writeLog("ConfigurationService: Warning - \(warning)", logLevel: .info)
        }
        
        return warnings
    }

    /// Item-level warnings: duplicate IDs, empty names, and preset-specific field checks.
    func validateItems(_ items: [InspectConfig.ItemConfig], preset: String) -> [String] {
        var warnings: [String] = []
        let normalizedPreset = normalizePreset(preset)

        var seenIds: Set<String> = []
        for item in items {
            if seenIds.contains(item.id) {
                warnings.append("⚠️ Duplicate item ID: '\(item.id)'")
            } else {
                seenIds.insert(item.id)
            }
        }

        let validActions = ["url", "request", "custom"]
        let validOverlaySizes = ["small", "medium", "large"]

        for item in items {
            let itemPrefix = "Item '\(item.id)'"

            if item.displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                warnings.append("⚠️ \(itemPrefix): Empty displayName")
            }

            if normalizedPreset == "5" && item.category == nil {
                warnings.append("⚠️ \(itemPrefix): Missing 'category' field (recommended for preset5 grouping)")
            }

            if normalizedPreset == "5" && item.plistKey == nil && item.paths.isEmpty {
                warnings.append("⚠️ \(itemPrefix): No 'plistKey' or 'paths' for validation (preset5 compliance check)")
            }

            // No stepType allow-list for preset 6: row kinds are `ListItem.kind` values and the role lives on `phase`.
            if normalizedPreset == "6" {
                if let overlay = item.itemOverlay, let size = overlay.size, !validOverlaySizes.contains(size.lowercased()) {
                    warnings.append("⚠️ \(itemPrefix): Invalid itemOverlay size '\(size)' - expected one of: \(validOverlaySizes.joined(separator: ", "))")
                }

                if let guidanceContent = item.guidanceContent {
                    for (index, block) in guidanceContent.enumerated() where block.type == "button" {
                        if let action = block.action {
                            if !validActions.contains(action.lowercased()) {
                                warnings.append("⚠️ \(itemPrefix): guidanceContent[\(index)] has invalid button action '\(action)' - expected one of: \(validActions.joined(separator: ", "))")
                            }
                            if action.lowercased() == "request" && (block.requestId == nil || block.requestId?.isEmpty == true) {
                                warnings.append("⚠️ \(itemPrefix): guidanceContent[\(index)] button action='request' but no requestId provided")
                            }
                            if action.lowercased() == "url" && (block.url == nil || block.url?.isEmpty == true) {
                                warnings.append("⚠️ \(itemPrefix): guidanceContent[\(index)] button action='url' but no url provided")
                            }
                        }
                    }
                }
            }
        }

        return warnings
    }

    /// The engine number a preset name selects, as a string ("5" for preset 7); unknown names validate as "1".
    func normalizePreset(_ preset: String) -> String {
        InspectPresetName.engine(preset).map(String.init) ?? "1"
    }

    /// Root-level warnings: enum-valued keys and the inputs presets 5 and 6 need.
    func validatePresetSpecific(_ config: InspectConfig) -> [String] {
        var warnings: [String] = []
        let preset = normalizePreset(config.preset)
        // A step flow has no compliance dashboard, so no plistSources to miss.
        let isStepFlow = !(config.introSteps ?? config.steps ?? []).isEmpty

        let validListIndicatorStyles = ["letters", "numbers", "roman"]
        let validStepStyles = ["plain", "colored", "cards"]
        let validImageShapes = ["rectangle", "square", "circle"]

        if let style = config.listIndicatorStyle, !validListIndicatorStyles.contains(style.lowercased()) {
            warnings.append("⚠️ Invalid listIndicatorStyle '\(style)' - expected one of: \(validListIndicatorStyles.joined(separator: ", "))")
        }

        if let style = config.stepStyle, !validStepStyles.contains(style.lowercased()) {
            warnings.append("⚠️ Invalid stepStyle '\(style)' - expected one of: \(validStepStyles.joined(separator: ", "))")
        }

        if let shape = config.imageShape, !validImageShapes.contains(shape.lowercased()) {
            warnings.append("⚠️ Invalid imageShape '\(shape)' - expected one of: \(validImageShapes.joined(separator: ", "))")
        }

        if preset == "5" && !isStepFlow {
            if config.plistSources == nil || config.plistSources?.isEmpty == true {
                warnings.append("⚠️ Preset5: Missing 'plistSources' - required for compliance dashboard data")
            } else if let sources = config.plistSources {
                for (index, source) in sources.enumerated() {
                    // URLs and glob patterns cannot be checked on disk.
                    if !source.path.hasPrefix("http") && !source.path.contains("*") {
                        let expandedPath = NSString(string: source.path).expandingTildeInPath
                        if !FileManager.default.fileExists(atPath: expandedPath) {
                            warnings.append("⚠️ Preset5: plistSources[\(index)] path not found: \(source.path)")
                        }
                    }
                }
            }
        }

        if preset == "6" {
            let itemsWithGuidance = config.items.filter { $0.guidanceContent != nil }
            if itemsWithGuidance.isEmpty && !config.items.isEmpty {
                warnings.append("⚠️ Preset6: No items have 'guidanceContent' - recommended for workflow steps")
            }

            let hasRequestButtons = config.items.contains { item in
                item.guidanceContent?.contains { $0.action?.lowercased() == "request" } ?? false
            }
            if hasRequestButtons && config.actionPipe == nil {
                warnings.append("⚠️ Preset6: Items use 'request' button actions but no 'actionPipe' configured")
            }
        }

        return warnings
    }

    /// Warnings when guiIndex values are not 0, 1, 2, ...: non-zero start, duplicates, gaps.
    func validateGuiIndexSequence(_ items: [InspectConfig.ItemConfig]) -> [String] {
        var warnings: [String] = []

        let indexedItems = items.map { (id: $0.id, index: $0.guiIndex) }
        let sortedByIndex = indexedItems.sorted { $0.index < $1.index }

        if let first = sortedByIndex.first, first.index != 0 {
            warnings.append("⚠️ guiIndex: Sequence should start at 0, but starts at \(first.index) (item: '\(first.id)')")
        }

        var seenIndices: [Int: String] = [:] // index -> first item ID that used it
        for item in sortedByIndex {
            if let existingId = seenIndices[item.index] {
                warnings.append("⚠️ guiIndex: Duplicate index \(item.index) found in items '\(existingId)' and '\(item.id)'")
            } else {
                seenIndices[item.index] = item.id
            }
        }

        let indices = sortedByIndex.map { $0.index }
        let uniqueIndices = Set(indices).sorted()

        if uniqueIndices.count > 1 {
            for i in 0..<(uniqueIndices.count - 1) {
                let current = uniqueIndices[i]
                let next = uniqueIndices[i + 1]
                if next != current + 1 {
                    let beforeItem = sortedByIndex.first { $0.index == current }?.id ?? "?"
                    let afterItem = sortedByIndex.first { $0.index == next }?.id ?? "?"
                    let missingIndices = (current + 1)..<next
                    warnings.append("⚠️ guiIndex: Gap in sequence - missing index(es) \(Array(missingIndices)) between '\(beforeItem)' (\(current)) and '\(afterItem)' (\(next))")
                }
            }
        }

        if !warnings.isEmpty {
            let actual = sortedByIndex.map { "\($0.index)" }.joined(separator: ", ")
            warnings.insert("⚠️ guiIndex: Expected sequential [0..\(items.count - 1)] but found [\(actual)]", at: 0)
        }

        return warnings
    }
}
