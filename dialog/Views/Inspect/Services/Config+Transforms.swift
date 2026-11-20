//
//  Config+Transforms.swift
//  dialog
//
//  Config extension: resolves $token references before decoding and extracts UI, background and
//  button configuration from a decoded `InspectConfig`.
//

import Foundation

extension Config {
    // MARK: - Brand Token Resolution (Pre-Decode)

    /// Resolves $token references throughout a JSON dictionary, recursing into arrays and objects.
    func resolveBrandTokens(in dict: [String: Any], palette: [String: Any]) -> [String: Any] {
        var result = dict

        for (key, value) in dict {
            if let stringValue = value as? String {
                let resolved = resolveTokenString(stringValue, palette: palette)
                if resolved != stringValue {
                    writeLog("BrandToken: Dict key '\(key)' resolved: '\(stringValue)' → '\(resolved)'", logLevel: .info)
                }
                result[key] = resolved
            } else if let arrayValue = value as? [Any] {
                writeLog("BrandToken: Processing array for key '\(key)' with \(arrayValue.count) elements", logLevel: .info)
                result[key] = resolveTokensInArray(arrayValue, palette: palette)
            } else if let dictValue = value as? [String: Any],
                      key != "brandPalette", key != "brandPaletteDark" {
                // Both palettes define tokens; resolving inside them would be circular.
                result[key] = resolveBrandTokens(in: dictValue, palette: palette)
            }
        }

        return result
    }

    func resolveTokensInArray(_ array: [Any], palette: [String: Any]) -> [Any] {
        return array.map { element in
            if let stringValue = element as? String {
                return resolveTokenString(stringValue, palette: palette)
            } else if let arrayValue = element as? [Any] {
                return resolveTokensInArray(arrayValue, palette: palette)
            } else if let dictValue = element as? [String: Any] {
                return resolveBrandTokens(in: dictValue, palette: palette)
            }
            return element
        }
    }

    /// Replaces each `$tokenName` in a string with its palette value; unknown tokens are left as written.
    func resolveTokenString(_ value: String, palette: [String: Any]) -> String {
        guard value.contains("$") else { return value }

        let pattern = #"\$([a-zA-Z_][a-zA-Z0-9_.]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }

        var result = value
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))

        writeLog("BrandToken: Resolving '\(value)' - found \(matches.count) token(s)", logLevel: .info)

        for match in matches.reversed() {
            guard let tokenRange = Range(match.range(at: 1), in: value),
                  let fullRange = Range(match.range, in: result) else { continue }

            let token = String(value[tokenRange])
            if let resolved = lookupPaletteToken(token, palette: palette) {
                writeLog("BrandToken: Resolved $\(token) → \(resolved)", logLevel: .info)
                result.replaceSubrange(fullRange, with: resolved)
            } else {
                writeLog("BrandToken: WARNING - Token '$\(token)' not found in palette", logLevel: .info)
            }
        }

        return result
    }

    /// Looks up a flat token or a one-level namespaced one such as "logos.main"; namespaced values
    /// may themselves contain tokens.
    func lookupPaletteToken(_ token: String, palette: [String: Any]) -> String? {
        if token.contains(".") {
            let parts = token.split(separator: ".", maxSplits: 1)
            if parts.count == 2,
               let namespace = palette[String(parts[0])] as? [String: Any],
               let value = namespace[String(parts[1])] as? String {
                return resolveTokenString(value, palette: palette)
            }
            return nil
        }

        if let value = palette[token] as? String {
            return value
        }

        return nil
    }

    // MARK: - Configuration Transformation Helpers

    func extractUIConfiguration(from config: InspectConfig) -> UIConfiguration {
        var uiConfig = UIConfiguration()

        writeLog("Config.swift: extractUIConfiguration called", logLevel: .debug)
        writeLog("Config.swift: config.banner = \(config.banner ?? "nil")", logLevel: .debug)
        writeLog("Config.swift: config.bannerHeight = \(config.bannerHeight ?? 0)", logLevel: .debug)
        writeLog("Config.swift: config.bannerTitle = \(config.bannerTitle ?? "nil")", logLevel: .debug)

        if let title = config.title {
            uiConfig.windowTitle = title
        }

        uiConfig.chrome = config.chrome

        if let message = config.message {
            uiConfig.subtitleMessage = message
            uiConfig.statusMessage = message
        }

        if let icon = config.icon {
            uiConfig.iconPath = icon
        }

        if let sideMessage = config.sideMessage {
            uiConfig.sideMessages = sideMessage
        }

        if let popupButton = config.popupButton {
            uiConfig.popupButtonText = popupButton
        }

        uiConfig.preset = config.preset

        if let highlightColor = config.highlightColor {
            uiConfig.highlightColor = highlightColor
        }

        if let secondaryColor = config.secondaryColor {
            uiConfig.secondaryColor = secondaryColor
        }

        if let banner = config.banner {
            writeLog("Config.swift: Setting uiConfig.bannerImage = \(banner)", logLevel: .debug)
            uiConfig.bannerImage = banner
        }

        if let bannerHeight = config.bannerHeight {
            writeLog("Config.swift: Setting uiConfig.bannerHeight = \(bannerHeight)", logLevel: .debug)
            uiConfig.bannerHeight = bannerHeight
        }

        if let bannerTitle = config.bannerTitle {
            writeLog("Config.swift: Setting uiConfig.bannerTitle = \(bannerTitle)", logLevel: .debug)
            uiConfig.bannerTitle = bannerTitle
        }

        writeLog("Config.swift: After extraction - uiConfig.bannerImage = \(uiConfig.bannerImage ?? "nil")", logLevel: .debug)

        if let iconsize = config.iconsize {
            uiConfig.iconSize = iconsize
        }

        if let width = config.width {
            uiConfig.width = width
        }

        if let height = config.height {
            uiConfig.height = height
        }

        if let size = config.size {
            uiConfig.size = size
        }

        // Density travels raw and is resolved per read; log its advisory once here, not on the layout path.
        uiConfig.density = config.density
        if let note = InspectDensity.resolve(authored: config.density, preset: config.preset).advisory {
            writeLog("InspectConfig: \(note)", logLevel: .info)
        }

        if let iconBasePath = config.iconBasePath {
            uiConfig.iconBasePath = iconBasePath
            ImageResolver.shared.configBasePath = iconBasePath
        }

        if let overlayicon = config.overlayicon {
            uiConfig.overlayIcon = overlayicon
        }

        if let rotatingImages = config.rotatingImages {
            uiConfig.rotatingImages = rotatingImages
        }

        if let imageRotationInterval = config.imageRotationInterval {
            uiConfig.imageRotationInterval = imageRotationInterval
        }

        if let imageShape = config.imageShape {
            uiConfig.imageFormat = imageShape
        }


        if let stepStyle = config.stepStyle {
            uiConfig.stepStyle = stepStyle
        }

        if let listIndicatorStyle = config.listIndicatorStyle {
            uiConfig.listIndicatorStyle = listIndicatorStyle
            writeLog("Config: Setting listIndicatorStyle to '\(listIndicatorStyle)' from JSON", logLevel: .debug)
        } else {
            writeLog("Config: No listIndicatorStyle in JSON, using default: '\(uiConfig.listIndicatorStyle)'", logLevel: .debug)
        }

        return uiConfig
    }
    
    func extractBackgroundConfiguration(from config: InspectConfig) -> BackgroundConfiguration {
        var bgConfig = BackgroundConfiguration()
        
        if let backgroundColor = config.backgroundColor {
            bgConfig.backgroundColor = backgroundColor
        }
        
        if let backgroundImage = config.backgroundImage {
            bgConfig.backgroundImage = backgroundImage
        }
        
        if let backgroundOpacity = config.backgroundOpacity {
            bgConfig.backgroundOpacity = backgroundOpacity
        }
        
        if let textOverlayColor = config.textOverlayColor {
            bgConfig.textOverlayColor = textOverlayColor
        }
        
        if let gradientColors = config.gradientColors {
            bgConfig.gradientColors = gradientColors
        }
        
        return bgConfig
    }
    
    func extractButtonConfiguration(from config: InspectConfig) -> ButtonConfiguration {
        var buttonConfig = ButtonConfiguration()

        if let button1Text = config.button1Text {
            buttonConfig.button1Text = button1Text
            writeLog("Config: Extracted button1Text = '\(button1Text)'", logLevel: .info)
        } else {
            writeLog("Config: button1Text is nil in config", logLevel: .info)
        }

        if let button1Disabled = config.button1Disabled {
            buttonConfig.button1Disabled = button1Disabled
        }

        buttonConfig.button1Symbol = config.button1Symbol
        buttonConfig.button2Symbol = config.button2Symbol

        if let button2Text = config.button2Text {
            buttonConfig.button2Text = button2Text
            writeLog("Config: Extracted button2Text = '\(button2Text)'", logLevel: .info)
        } else {
            writeLog("Config: button2Text is nil in config", logLevel: .info)
        }

        // button2Disabled and buttonStyle are not read: button 2 is always enabled when shown.

        if let button2Visible = config.button2Visible {
            buttonConfig.button2Visible = button2Visible
        }

        if let autoEnableButton = config.autoEnableButton {
            buttonConfig.autoEnableButton = autoEnableButton
        }
        
        return buttonConfig
    }
}
