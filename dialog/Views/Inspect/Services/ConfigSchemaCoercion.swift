//
//  ConfigSchemaCoercion.swift
//  dialog
//
//  Pre-decode scalar coercion for inspect config JSON, and `validateInspectSchema`.
//

import Foundation

/// Coerces quoted scalars (`"2"`, `"true"`) to the type the schema declares, before `Codable` decoding.
///
/// The field sets are derived from `dialog/Views/Inspect/inspect-config.schema.json`: only names with a
/// single scalar type across the whole schema are listed, so a legitimate string is never rewritten.
/// Regenerate after editing the schema. Coercion is idempotent.
enum InspectConfigCoercion {

    /// Schema fields declared only as `integer`.
    static let integerFields: Set<String> = [
        "bannerHeight", "bentoColumns", "blockIndex", "captureGroup",
        "column", "columnSpan", "currentIndex", "currentPhase", "errorDetectionThreshold",
        "exitCode", "granularityMinutes", "gridColumns", "guiIndex", "guidanceBlockIndex",
        "height", "iconsize",
        "maxLength", "plistRecheckInterval", "processingDuration",
        "recheckInterval", "row", "rowSpan", "scanInterval", "scriptTimeout",
        "sideInterval", "sideMessageInterval",
        "total", "waitLargeOverrideTime", "waitSmallOverrideTime", "waitWarningTime",
        "wallpaperColumns", "wallpaperMultiSelect", "width", "windowHours"
    ]

    /// Schema fields declared only as `number` (floating point).
    static let numberFields: Set<String> = [
        "assistantImageHeight", "autoAdvanceDelay", "backgroundOpacity", "bentoGap",
        "bentoRowHeight", "bentoSidebarRatio", "cadenceInterval", "cadenceMinDwell",
        "cornerRadius", "delay", "dismissDelay", "editorHeight", "enableOnTimer", "excellent", "good", "guideImageRatio",
        "heroImagePadding", "heroImageSize", "iconSize", "imageHeight",
        "imageRotationInterval", "imageWidth", "introScale",
        "introVerticalOffset", "logoMaxWidth", "max", "maxHeight", "maxWidth",
        "mediaHeight", "mediaRatio", "min", "minDwell", "monitorRefreshInterval",
        "opacity", "outroScale", "outroVerticalOffset", "padding", "portalHeight",
        "progress", "scale", "showcaseImageHeight", "step", "thumbnailSize",
        "timeout", "verticalOffset", "videoHeight", "wallpaperThumbnailHeight", "webHeight"
    ]

    /// Schema fields declared only as `boolean`.
    static let booleanFields: Set<String> = [
        "addRows", "allowContinueWithoutSelection", "allowImageZoom", "allowNavigationDuringProcessing",
        "allowOverride", "autoAdvance", "autoAdvanceOnComplete", "autoColor", "autoDiscover",
        "autoDismiss", "autoEnableButton", "autoMatch", "autoTransition", "autoplay", "bold",
        "button1disabled", "button2visible", "debugMode",
        "enableStatusColors", "enabled", "ephemeralSession", "hideSystemDetails",
        "highlightCells", "imageBorder", "isCritical", "mediaAutoplay",
        "mediaShowArrows", "mediaShowDots", "mergeWithExisting", "numbered", "observeOnly",
        "openExternalLinksInBrowser", "opensOverlay", "recommended",
        "requireManualConfirm", "required", "resumable", "returnSelections", "secure",
        "selfServiceOnly", "showAccentBorder", "showAddressBar", "showArrows",
        "showBackButton",
        "showBlockingState", "showCompletionState", "showDividers", "showDots",
        "showNavigationArrows", "showOnIntro", "showOnMain", "showOnSummary", "showProgressDots", "showProgressInfo", "showStepCounter", "showSystemInfo",
        "showThumbnails", "skipIfComplete", "skipPortal", "startFromEnd", "useUserDefaults",
        "visible", "waitForExternalTrigger", "wallpaperShowPath", "wide",
        "writeOnDialogExit", "writeOnStepComplete"
    ]

    /// List fields where a bare string is read as a one-element list, with an advisory.
    static let stringListFields: Set<String> = ["sideMessage", "sideMessages"]

    /// Keys that are boolean elsewhere but a string inside the named container: `required` is display
    /// text in a `checks` row, so `"YES"` there must not become `true`.
    static let stringInContainer: [String: Set<String>] = [
        "required": ["checks"]
    ]

    /// Recursively coerces scalars in a `JSONSerialization` object graph. `container` is the key the
    /// value was reached through; array elements inherit their array's key for `stringInContainer`.
    static func coerceScalars(in value: Any, container: String? = nil) -> Any {
        if let dict = value as? [String: Any] {
            var out = [String: Any](minimumCapacity: dict.count)
            for (key, val) in dict {
                if val is [String: Any] || val is [Any] {
                    out[key] = coerceScalars(in: val, container: key)
                } else if let exempt = stringInContainer[key],
                          let container, exempt.contains(container) {
                    out[key] = val
                } else if integerFields.contains(key), let i = asInt(val) {
                    out[key] = i
                } else if numberFields.contains(key), let d = asDouble(val) {
                    out[key] = d
                } else if booleanFields.contains(key), let b = asBool(val) {
                    out[key] = b
                } else if stringListFields.contains(key), let one = val as? String {
                    out[key] = [one]
                    let message = "\(key): a single string was given where a list is expected; "
                        + "it is read as a one-item list. Write [\"…\"] to silence this."
                    writeLog("InspectConfig: \(message)", logLevel: .info)
                } else {
                    out[key] = val
                }
            }
            return out
        }
        if let arr = value as? [Any] {
            return arr.map { coerceScalars(in: $0, container: container) }
        }
        return value
    }

    // MARK: Scalar parsers

    static func asInt(_ v: Any) -> Int? {
        if let i = v as? Int { return i }
        if let s = v as? String, let i = Int(s.trimmingCharacters(in: .whitespaces)) { return i }
        if let d = v as? Double, d == d.rounded() { return Int(d) }
        return nil
    }

    static func asDouble(_ v: Any) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String, let d = Double(s.trimmingCharacters(in: .whitespaces)) { return d }
        return nil
    }

    static func asBool(_ v: Any) -> Bool? {
        if let b = v as? Bool { return b }
        if let s = v as? String {
            switch s.trimmingCharacters(in: .whitespaces).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }
}

/// Result of validating raw JSON against the inspect-mode schema.
enum InspectSchemaValidation {
    case valid(InspectConfig)
    case notInspect
    case malformed(reason: String)
}

/// Two gates: the object must carry an inspect marker (non-empty `inspectMode`, `preset`, `introSteps`
/// or `items`), then decode into `InspectConfig` after the same scalar coercion the loaders apply.
func validateInspectSchema(_ data: Data) -> InspectSchemaValidation {
    guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
        return .malformed(reason: "top-level JSON is not an object")
    }

    var hasMarker = false
    if let b = obj["inspectMode"] as? Bool, b { hasMarker = true }
    if let s = obj["preset"] as? String, !s.isEmpty { hasMarker = true }
    if let a = obj["introSteps"] as? [Any], !a.isEmpty { hasMarker = true }
    if let a = obj["items"] as? [Any], !a.isEmpty { hasMarker = true }
    guard hasMarker else { return .notInspect }

    // 3.1.1 keys first, in memory only; their notes reach the loader's warnings and lint.
    let remap = InspectLegacyRemap.apply(obj)
    InspectLegacyRemap.log(remap.notes)
    InspectConfig.unknownKeyWarnings.append(contentsOf: remap.notes)
    let coerced = (InspectConfigCoercion.coerceScalars(in: remap.object) as? [String: Any]) ?? remap.object
    guard let coercedData = try? JSONSerialization.data(withJSONObject: coerced) else {
        return .malformed(reason: "could not re-serialize coerced JSON")
    }
    do {
        let config = try JSONDecoder().decode(InspectConfig.self, from: coercedData)
        return .valid(config)
    } catch {
        let jsonString = String(data: data, encoding: .utf8)
        return .malformed(reason: ConfigurationError.formatJSONError(error, jsonString: jsonString))
    }
}
