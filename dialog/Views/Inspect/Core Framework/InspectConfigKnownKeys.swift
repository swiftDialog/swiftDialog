//
//  InspectConfigKnownKeys.swift
//  dialog
//
//  Accepted JSON keys per config surface, for the decoders' unknown-key warnings. Parity tests check them
//  against the struct declarations.
//

import Foundation

extension InspectConfig {

    /// Root keys: the root CodingKeys plus accepted aliases and tolerated deprecated keys.
    static let knownRootKeys: Set<String> = [
        // `$schema` is for editors; the engine ignores it.
        "$schema", "watch",
        "accentBorderColor", "actionPipe", "appConfigSource", "appearance", "autoAdvanceDelay", "autoAdvanceOnComplete", "autoEnableButton",
        "autoEnableButtonText", "backButtonStyle", "backgroundColor", "backgroundImage", "backgroundOpacity", "banner",
        "bannerHeight", "bannerTitle", "brandPalette", "brandPaletteDark", "brandPaletteRef", "brandSelectionKey", "brands", "button1disabled",
        "button1symbol", "button1text", "button2disabled", "button2symbol", "button2text", "button2visible",
        "buttonShape", "buttonStyle", "migrationBodies", "cacheExtensions", "cachePaths", "chrome", "colorThresholds",
        "completedTitle", "complianceLabels", "contentAlign", "contentAnchor", "copyrightText", "dateStyle",
        "debugMode", "deferralConfig", "density", "detailOverlay", "enableOnTimer", "eventFile", "finalButtonText",
        "footerBackgroundColor", "footerText", "footerTextColor", "gradientColors", "gradientPalette", "gradientStyle",
        "greetingNameSource", "guidanceContent", "height", "helpButton", "hideSystemDetails", "highlightColor", "icon",
        "iconBasePath", "iconsize", "imageRotationInterval", "imageShape", "infobox",
        "instructionBanner", "introScreen", "introSteps", "items", "labels", "listIndicatorStyle",
        "steps",
        "liststyle", "localization", "logMonitor", "logMonitors", "logoConfig", "successColor", "topBand", "message", "messageStyle",
        "observeOnly", "overlayicon", "phaseBackground", "phaseBackgroundPalette", "phaseBackgroundPaletteDark", "phaseBackgroundSource",
        "pickerConfig", "pickerLabels", "plistSources", "popupButton", "portalConfig", "preferencesOutput",
        "preset", "progressBarConfig", "progressMode", "readinessFile", "receiptCensus", "receiptsBasePath", "resultFile",
        "profileLook", "resumable", "rotatingImages", "showProfilesRow", "scanInterval", "secondaryColor", "showAccentBorder",
        "glow", "itemSortOrder", "sideInterval", "sideMessage", "size", "skipPortal", "stepCounterPlacement", "stepStyle", "style",
        "summaryScreen", "supportText", "textOverlayColor", "title", "triggerFile", "uiLabels",
        "width", "windowPosition", "windowPositionOffset", "options", "button1Action", "button2Action"
    ]

    /// ItemConfig keys, same rule as the root set.
    static let knownItemKeys: Set<String> = [
        "logAliases",
        "actionButtonText", "allowNavigationDuringProcessing", "allowOverride", "autoAdvance", "autoAdvanceOnComplete", "autoResult",
        "banner", "blocking", "cardPanel", "category",
        "categoryIcon", "claim", "completedStatus", "completionMode", "continueAction", "continueButtonText", "displayName",
        "dockCandidate", "downloadingStatus", "evaluation", "expectedValue", "failureMessage", "finalButtonText",
        "footerNote", "gradientColors", "group", "guiIndex", "guidanceContent", "guidanceTitle",
        "highlightColor", "icon", "id", "info", "itemOverlay",
        "jsonMonitors", "keyPointsText", "managedPrefDomain", "managedPrefKey", "observeOnly", "openURL", "overrideButtonText",
        "paths", "pendingStatus", "phase", "plistKey", "plistMonitors", "plistRecheckInterval",
        "processingDuration", "processingMessage", "processingMode", "required", "requirements", "satisfy",
        "showBundleInfo", "size", "status", "stepType", "subtitle", "successMessage", "timeEstimate", "title",
        "useUserDefaults", "version", "waitForExternalTrigger", "waitLargeOverrideTime", "waitSmallOverrideTime",
        "waitWarningTime", "windowPosition", "windowPositionOffset"
    ]

    /// `ListItem` (step row) keys. Also accepts `title` (displayName alias) and `stepType`,
    /// whose row-kind spellings fold into `kind` at decode for compatibility.
    static let knownListItemKeys: Set<String> = [
        "logAliases",
        "category", "completedStatus", "claim", "displayName", "downloadingStatus", "evaluation", "expectedValue",
        "failureMessage", "finalButtonText", "guiIndex", "highlightColor", "icon", "id",
        "info", "itemOverlay", "jsonMonitors", "kind", "managedPrefDomain", "managedPrefKey",
        "openURL", "paths", "pendingStatus", "plistKey", "plistMonitors", "plistRecheckInterval",
        "requirements", "satisfy", "showBundleInfo", "size", "status", "stepType", "subtitle",
        "timeEstimate", "title", "useUserDefaults", "version"
    ]

    /// IntroStep stored properties; synthesized Codable, so this is the accepted key set.
    static let knownStepKeys: Set<String> = [
        "actionButtonText", "agentLabel", "allowOverride", "assistantImageHeight", "autoAdvance", "autoAdvanceOnComplete", "autoCloseAfter",
        "autoEnableButton", "autoEnableButtonText", "autoResult", "backButtonKind", "backButtonText", "backLabel", "bannerHeight",
        "bentoCells", "bentoColumns", "bentoGap", "bentoLayout", "bentoRowHeight", "bentoShowSlots",
        "bentoSidebarContent", "bentoSidebarRatio", "bentoTintColor", "brandColorRef", "bundleId", "bundles",
        "cadence", "cadenceInterval", "cadenceMinDwell", "cadenceRef", "cadenceStyle", "carouselStyle", "cardPanel", "confirmIncomplete", "continueWhileRunning", "secondaryButtonText", "secondaryAction",
        "totalTimeEstimate",
        "completedMessage", "completedTitle", "failedTitle",
        "completionMode", "condition", "content", "contentAlign", "contentAnchor", "continueAction",
        "continueButtonText", "dockApplyMode", "dockConfirmButton", "dockDecline", "dockFlavors", "dockItems",
        "dockLayout", "dockMode", "dockPreferenceKey", "dockSelectionKey", "dockShowUnavailable", "evaluation",
        "expectedValue", "failureMessage", "footerNote", "gridColumns", "gridItems",
        "gridPreferenceKey", "gridSelectionKey", "gridSelectionMode", "screens",
        "guidanceContent", "guidanceTitle", "displayName", "icon", "itemOverlay", "completedStatus", "observeOnly", "allowNavigationDuringProcessing", "group", "headerIconTile",
        // Grouped per-type payload containers; stored properties on IntroStep.
        "assistant", "bento", "dock", "export", "media", "option",
        "portal", "showcase", "software", "wallpaper",
        "guideText", "handoffs", "heroBackgroundColor", "heroBadge",
        "heroImage", "heroImagePadding", "heroImageSFSymbolColor", "heroImageSFSymbolWeight", "heroImageShape", "heroImageSize",
        "id", "installationLayout", "installationMode", "items", "layout", "stateWords", "divisionMode", "finalMessage", "holdPrimary", "gridProgress", "gridStyle", "showGridCounter", "showProgressLine", "eyebrow",
        "mediaAutoplay", "mediaFit", "mediaHeight", "mediaItems", "mediaLayout", "mediaRatio", "mediaShowArrows", "mediaStage",
        "mediaShowDots", "mediaSide", "monitorRefreshInterval", "optionCards", "optionConfirmButton", "optionKey",
        "optionLayout", "optionMultiSelect", "optionPreferenceKey", "overrideButtonText", "paths", "phase", "plistKey",
        "plistMonitors", "popupButtonText", "portalConfig", "processingDuration", "processingMessage", "processingMode",
        "progressFormat", "receipt", "requireManualConfirm", "revisitable", "selectable",
        "environmentKey", "environmentLabel", "environments", "learnMoreText", "learnMoreURL", "showWhen",
        "optionControl", "cadenceSelectionKey", "cadenceTimeout", "reviewSelectionKey", "reviewAcknowledge",
        "showBackButton", "showCadenceRecap", "showProgressDots", "showcaseGradientColors", "showcaseImageHeight",
        "showcaseTextColor", "sideMessageInterval", "sideMessages", "skipButtonText", "skipIfComplete", "softwareNote",
        "stats", "stepOverlay", "stepType", "substeps", "subtitle", "successMessage",
        "title", "waitForExternalTrigger", "waitLargeOverrideTime", "waitSmallOverrideTime", "wallpaperCategories", "wallpaperConfirmButton",
        "wallpaperLayout", "wallpaperMultiSelect", "wallpaperPreferenceKey", "wallpaperSelectionKey", "wallpaperShowPath", "wallpaperThumbnailHeight",
        "windowPosition", "windowPositionOffset"
    ]

    /// GuidanceContent stored properties; synthesized Codable, same rule. `ChecklistLine` fields
    /// belong to that nested struct, not here; `auditBlockArray` does not descend into `checklist[]`.
    static let knownBlockKeys: Set<String> = [
        "requiredOptions",
        "optionActions",
        "optionURLs",
        "action", "actual", "actualColor", "actualIcon", "actualLabel", "autoAdvance",
        "multiple", "limit", "autoAdvanceDelay", "autoColor", "autoplay", "bentoCells", "bentoColumns", "bentoGap",
        "bentoLayout", "bentoRowHeight", "bentoTintColor", "bold", "bundleCommand", "bundleCommandNote", "bundleRows", "buttonStyle", "caption", "captions",
        "cardIcon", "category", "categoryName", "checkDetails", "checklist", "checks",
        "color", "columns", "content", "continueAtNow", "continueFormat",
        "currentIndex", "currentPhase", "deadline", "deadlineNote", "defaultAt", "detailRows",
        "discreteSteps", "dock", "dockApplyMode", "dockConfirmButton", "dockDecline", "dockFlavors", "dockItems", "dockLayout",
        "dockMode", "dockPreferenceKey", "dockSelectionKey", "dockShowUnavailable", "editorHeight", "expected",
        "expectedColor", "expectedIcon", "expectedLabel", "facts", "fileType", "findings", "follow", "footnote",
        "granularityMinutes", "gridColumns", "gridItems", "gridSelectionKey", "gridSelectionMode", "handoffs", "helpText", "highlightCells", "icon", "id", "imageBorder", "imageFit", "imageHeight",
        "imageShape", "imageWidth", "images", "inherit", "initialPath", "installItems", "installLayout",
        "items", "label", "max", "maxLength", "mediaAutoplay", "mediaFit", "mediaHeight", "mediaItems", "mediaLayout", "mediaShowArrows", "mediaShowDots", "min", "note", "numbered",
        "opensOverlay", "option", "optionCards", "optionConfirmButton", "optionKey", "optionLayout", "optionMultiSelect",
        "optionDetails", "optionIcons", "optionPreferenceKey", "options", "passed", "phases", "placeholder",
        "portalConfig", "portalHeight", "portalPath", "portalURL", "progress", "quickPicks", "regex", "regexError",
        "requestId", "required", "rows", "secondaryAtLater", "sectionLabel", "secure", "shell",
        "showArrows", "showDots", "specimen", "specimenNote", "state", "stats", "step",
        "style", "targetBadge", "text", "textfieldMode", "title", "total", "transitionStyle", "type",
        "showWhen", "unit", "url", "value", "videoHeight", "videoLoop", "visible",
        "wallpaper", "wallpaperCategories", "wallpaperColumns", "wallpaperConfirmButton", "wallpaperImageFit", "wallpaperLayout", "wallpaperMultiSelect",
        "wallpaperPreferenceKey", "wallpaperSelectionKey", "wallpaperShowPath", "wallpaperThumbnailHeight", "webHeight", "windowHours"
    ]

    /// PresetIntroScreen stored properties; synthesized Codable, same rule. Nested types such as
    /// `PresetIntroScreen.ExplainerStep`, `PresetSummaryScreen.NextStep`, `DockItem` and
    /// `DeclineOption` are not audited.
    static let knownIntroScreenKeys: Set<String> = [
        "title", "subtitle", "heroImage", "heroImageShape", "heroImageSize", "content",
        "buttonText", "showBackButton", "layout", "userBadge", "userBadgePosition", "stats", "footnote",
        "linkText", "steps", "showAppIcons", "explainerSteps", "explainerStepLabel"
    ]

    /// PresetSummaryScreen stored properties; synthesized Codable, same rule.
    static let knownSummaryScreenKeys: Set<String> = [
        "title", "subtitle", "heroImage", "heroImageShape", "heroImageSize", "content",
        "bentoLayout", "bentoCells", "bentoColumns", "bentoRowHeight", "bentoGap",
        "buttonText", "autoTransition", "layout", "caption", "infoNote", "footnote",
        "linkText", "sectionTitle", "nextSteps",
        "dockFlavors", "dockApplyMode", "dockConfirmButton", "dockDecline", "dockItems",
        "dockLayout", "dockMode", "dockPreferenceKey", "dockSelectionKey",
        "dockShowUnavailable", "dock", "itemStrip"
    ]

    // MARK: - The rule

    /// The one place a key is judged unknown; every audited scope routes through here.
    /// Underscore-prefixed keys (`_comment`, `_ui.*`) are authors' comments and are tolerated.
    static func unknownKeys(in keys: Set<String>, against known: Set<String>) -> [String] {
        keys.subtracting(known).filter { !$0.hasPrefix("_") }.sorted()
    }

    // MARK: - The walks

    /// Audits `steps[]` and `introSteps[]`, and each step's blocks under both `content` and
    /// `guidanceContent`. Everything is `try?`: detection must never fail a decode.
    /// `items[]` is audited by `ItemConfig.init(from:)`.
    static func auditStepAndBlockKeys(root: KeyedDecodingContainer<RawCodingKey>) {
        for listKey in ["steps", "introSteps"] {
            guard var steps = try? root.nestedUnkeyedContainer(forKey: RawCodingKey(stringValue: listKey)) else { continue }
            var index = 0
            while !steps.isAtEnd {
                guard let step = try? steps.nestedContainer(keyedBy: RawCodingKey.self) else {
                    // Advance past a non-object element so the loop cannot stall.
                    _ = try? steps.superDecoder()
                    index += 1
                    continue
                }
                let keys = Set(step.allKeys.map(\.stringValue))
                let id = (try? step.decode(String.self, forKey: RawCodingKey(stringValue: "id"))) ?? "step[\(index)]"
                for key in unknownKeys(in: keys, against: knownStepKeys) {
                    unknownKeyWarnings.append("Unknown key '\(key)' in step '\(id)'")
                }
                auditBlockArray(in: step, arrayKey: "content", owner: "step '\(id)'")
                auditBlockArray(in: step, arrayKey: "guidanceContent", owner: "step '\(id)'")
                index += 1
            }
        }
    }

    /// Audits `introScreen` and its `content[]` blocks. Same `try?` contract as the step walk.
    static func auditIntroScreenKeys(root: KeyedDecodingContainer<RawCodingKey>) {
        guard let screen = try? root.nestedContainer(keyedBy: RawCodingKey.self,
                                                     forKey: RawCodingKey(stringValue: "introScreen"))
        else { return }
        let keys = Set(screen.allKeys.map(\.stringValue))
        for key in unknownKeys(in: keys, against: knownIntroScreenKeys) {
            unknownKeyWarnings.append("Unknown key '\(key)' in introScreen")
        }
        auditBlockArray(in: screen, arrayKey: "content", owner: "introScreen")
    }

    /// Audits `summaryScreen` and its `content[]` blocks. Same `try?` contract as the step walk.
    static func auditSummaryScreenKeys(root: KeyedDecodingContainer<RawCodingKey>) {
        guard let screen = try? root.nestedContainer(keyedBy: RawCodingKey.self,
                                                     forKey: RawCodingKey(stringValue: "summaryScreen"))
        else { return }
        let keys = Set(screen.allKeys.map(\.stringValue))
        for key in unknownKeys(in: keys, against: knownSummaryScreenKeys) {
            unknownKeyWarnings.append("Unknown key '\(key)' in summaryScreen")
        }
        auditBlockArray(in: screen, arrayKey: "content", owner: "summaryScreen")
    }

    /// Audits one array of guidance blocks against `knownBlockKeys`.
    static func auditBlockArray(in parent: KeyedDecodingContainer<RawCodingKey>, arrayKey: String, owner: String) {
        guard var blocks = try? parent.nestedUnkeyedContainer(forKey: RawCodingKey(stringValue: arrayKey)) else { return }
        var index = 0
        while !blocks.isAtEnd {
            guard let block = try? blocks.nestedContainer(keyedBy: RawCodingKey.self) else {
                _ = try? blocks.superDecoder()
                index += 1
                continue
            }
            let keys = Set(block.allKeys.map(\.stringValue))
            let type = (try? block.decode(String.self, forKey: RawCodingKey(stringValue: "type"))) ?? "?"
            for key in unknownKeys(in: keys, against: knownBlockKeys) {
                unknownKeyWarnings.append("Unknown key '\(key)' in \(owner) content[\(index)] (type '\(type)')")
            }
            index += 1
        }
    }
}
