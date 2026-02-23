//
//  GuidanceContentView.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 17/01/2026
//
//  Extracted from PresetCommonHelpers.swift
//  Renders rich guidance content for Migration Assistant-style workflows
//

import SwiftUI
import AVKit
import WebViewKit

// MARK: - Guidance Content View (Shared content renderer)

/// Renders rich guidance content for Migration Assistant-style workflows
/// Shared across all presets for consistent rich content display
struct GuidanceContentView: View {
    let contentBlocks: [InspectConfig.GuidanceContent]
    let scaleFactor: CGFloat
    let iconBasePath: String?  // Optional base path for resolving relative image paths
    @ObservedObject var inspectState: InspectState
    let itemId: String
    let onOverlayTap: (() -> Void)?  // Optional callback when a block with opensOverlay=true is tapped
    let accentColor: Color?              // Optional branded accent (arrow icons, highlight, explainer, button tint, radio selection)
    let contentAlignment: HorizontalAlignment  // Text block alignment (.leading default, .center for Preset5 intro)
    @Environment(\.palette) private var palette

    // Initialize with required parameters for interactive form support
    init(contentBlocks: [InspectConfig.GuidanceContent], scaleFactor: CGFloat, iconBasePath: String? = nil, inspectState: InspectState, itemId: String, onOverlayTap: (() -> Void)? = nil, accentColor: Color? = nil, contentAlignment: HorizontalAlignment = .leading) {
        self.contentBlocks = contentBlocks
        self.scaleFactor = scaleFactor
        self.iconBasePath = iconBasePath
        self.inspectState = inspectState
        self.itemId = itemId
        self.onOverlayTap = onOverlayTap
        self.accentColor = accentColor
        self.contentAlignment = contentAlignment

        // Initialize form state for this item asynchronously to avoid publishing during view updates
        DispatchQueue.main.async {
            inspectState.initializeGuidanceFormState(for: itemId)
        }
    }

    /// Group comparison-table blocks by category for collapsible rendering
    /// Filters out blocks where visible == false
    private var groupedBlocks: [(category: String?, items: [InspectConfig.GuidanceContent])] {
        var groups: [(String?, [InspectConfig.GuidanceContent])] = []
        var currentCategory: String?
        var currentItems: [InspectConfig.GuidanceContent] = []

        // Filter out hidden blocks (visible == false)
        let visibleBlocks = contentBlocks.filter { $0.visible != false }

        for block in visibleBlocks {
            if block.type == "comparison-table" && block.category != nil {
                // Comparison table with category
                if block.category != currentCategory {
                    // Save previous group if exists
                    if !currentItems.isEmpty {
                        groups.append((currentCategory, currentItems))
                        currentItems = []
                    }
                    currentCategory = block.category
                }
                currentItems.append(block)
            } else {
                // Non-categorized block or different type
                // Save previous group if exists
                if !currentItems.isEmpty {
                    groups.append((currentCategory, currentItems))
                    currentItems = []
                    currentCategory = nil
                }
                // Add as single-item group
                groups.append((nil, [block]))
            }
        }

        // Save last group
        if !currentItems.isEmpty {
            groups.append((currentCategory, currentItems))
        }

        return groups
    }

    private func attributedMarkdown(_ markdown: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
        } catch {
            // Fallback to plain text if markdown parsing fails
            return AttributedString(markdown)
        }
    }

    var body: some View {
        VStack(alignment: contentAlignment, spacing: 8 * scaleFactor) {
            ForEach(Array(groupedBlocks.enumerated()), id: \.offset) { groupIndex, group in
                if let category = group.category, !group.items.isEmpty, group.items.allSatisfy({ $0.type == "comparison-table" }) {
                    // Render as collapsible category group
                    ComparisonGroupView(
                        category: category,
                        comparisons: group.items,
                        scaleFactor: scaleFactor
                    )
                    .id("comparison-group-\(category)-\(groupIndex)")
                } else {
                    // Render individual blocks normally
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, block in
                        wrappedContentBlockView(for: block)
                    }
                }
            }
        }
    }

    /// Wraps content block with overlay tap gesture if opensOverlay is true
    @ViewBuilder
    private func wrappedContentBlockView(for block: InspectConfig.GuidanceContent) -> some View {
        if block.opensOverlay == true, let onTap = onOverlayTap {
            // Make the content clickable to open overlay
            contentBlockView(for: block)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
                .overlay(alignment: .trailing) {
                    // Add subtle indicator that this is clickable
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.trailing, 8 * scaleFactor)
                }
                .help("Click for more details")
        } else {
            contentBlockView(for: block)
        }
    }

    @ViewBuilder
    private func contentBlockView(for block: InspectConfig.GuidanceContent) -> some View {
        let isBold = block.bold ?? false
        let textColor = getTextColor(for: block)

        switch block.type {
        case "text":
            let resolvedContent = resolveTemplateVariables(block.content ?? "", inspectState: inspectState)
            Text(attributedMarkdown(resolvedContent))
                .font(.system(size: 13 * scaleFactor, weight: isBold ? .semibold : .regular))
                .foregroundStyle(textColor)
                .multilineTextAlignment(contentAlignment == .center ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: contentAlignment, vertical: .center))

        case "highlight":
            let resolvedAccent: Color = accentColor ?? {
                if let customColor = inspectState.config?.secondaryColor {
                    return Color(hex: customColor)
                }
                // Use system accent color if default gray is still set
                let defaultColor = inspectState.uiConfiguration.secondaryColor
                return defaultColor == "#A0A0A0" ? Color.accentColor : Color(hex: defaultColor)
            }()

            Text(block.content ?? "")
                .font(.system(size: 14 * scaleFactor, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .modifier(HighlightChipStyle(accentColor: resolvedAccent, scaleFactor: scaleFactor))

        case "arrow":
            HStack(spacing: 6 * scaleFactor) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(accentColor ?? .primary)
                    .font(.system(size: 14 * scaleFactor))
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(textColor)
            }

        case "warning":
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(palette.warning)
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.warningBackground)
            )

        case "info":
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(palette.info)
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.infoBackground)
            )

        case "success":
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(palette.success)
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.successBackground)
            )

        case "explainer":
            // Explainer with inline markdown support and optional styled box
            // Supports: "plain" (no box), "info" (blue), "warning" (orange), "success" (green)
            let resolvedContent = resolveTemplateVariables(block.content ?? "", inspectState: inspectState)
            let explainerStyle = block.style ?? "plain"

            // Determine icon and colors based on style
            let (icon, iconColor, backgroundColor): (String?, Color, Color) = {
                switch explainerStyle {
                case "info":
                    return ("info.circle.fill", palette.info, palette.infoBackground)
                case "warning":
                    return ("exclamationmark.triangle.fill", palette.warning, palette.warningBackground)
                case "success":
                    return ("checkmark.circle.fill", palette.success, palette.successBackground)
                default: // "plain"
                    if let accent = accentColor {
                        return (block.icon, accent, accent.opacity(0.06))
                    }
                    return (nil, .primary, .clear)
                }
            }()

            Group {
                if let iconName = icon {
                    // Box style with icon
                    HStack(alignment: .top, spacing: 8 * scaleFactor) {
                        Image(systemName: iconName)
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(iconColor)

                        // Native SwiftUI markdown support
                        Text(attributedMarkdown(resolvedContent))
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(backgroundColor)
                    )
                } else {
                    // Plain style without box
                    Text(attributedMarkdown(resolvedContent))
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case "bullets":
            if let items = block.items {
                VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if !item.isEmpty {
                            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                                if block.numbered == true {
                                    // Numbered mode: 1.circle.fill, 2.circle.fill, etc. (up to 50)
                                    Image(systemName: "\(index + 1).circle.fill")
                                        .font(.system(size: 15 * scaleFactor))
                                        .foregroundStyle(accentColor ?? .blue)
                                } else if let sfIcon = block.icon {
                                    Image(systemName: sfIcon)
                                        .font(.system(size: 13 * scaleFactor))
                                        .foregroundStyle(accentColor ?? .secondary)
                                } else {
                                    Text("•")
                                        .font(.system(size: 13 * scaleFactor))
                                        .foregroundStyle(.secondary)
                                }
                                Text(item)
                                    .font(.system(size: 13 * scaleFactor, weight: (block.numbered == true || block.icon != nil) ? .medium : .regular))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

        case "label-value":
            // Format label-value pairs with visual distinction
            // Expects content in format "Label: Value" or uses separate label/value fields
            // Supports style variants: "default", "success" (green labels), "table" (no bullet, green labels)
            let resolvedContent = resolveTemplateVariables(block.content ?? "", inspectState: inspectState)
            let style = block.style ?? "default"  // default, success, table

            // Parse label and value
            let (label, value): (String, String) = {
                // Option 1: Use separate label/value fields if provided
                if let blockLabel = block.label, let blockValue = block.value {
                    return (blockLabel, blockValue)
                }

                // Option 2: Parse from content string (split on first colon)
                if let colonIndex = resolvedContent.firstIndex(of: ":") {
                    let labelPart = String(resolvedContent[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let valuePart = String(resolvedContent[resolvedContent.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    return (labelPart, valuePart)
                }

                // Fallback: treat entire content as value
                return ("", resolvedContent)
            }()

            // Determine styling based on style parameter
            let (labelColor, valueFontSize, showBullet): (Color, CGFloat, Bool) = {
                switch style {
                case "success":
                    return (palette.success, 15, true)  // Green labels, larger values, with bullet
                case "table":
                    return (palette.success, 15, false)  // Green labels, larger values, no bullet
                default:
                    return (.secondary, 13, true)  // Default: grey labels, normal size, with bullet
                }
            }()

            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                // Bullet point (optional based on style)
                if showBullet {
                    Text("•")
                        .font(.system(size: 13 * scaleFactor, weight: .bold))
                        .foregroundStyle(.primary)
                }

                // Label part (styled based on variant)
                if !label.isEmpty {
                    Text(label + ":")
                        .font(.system(size: 13 * scaleFactor, weight: .regular))
                        .foregroundStyle(labelColor)
                }

                // Value part (bold, larger if table/success style)
                Text(value)
                    .font(.system(size: valueFontSize * scaleFactor, weight: .bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, showBullet ? 0 : 6 * scaleFactor)  // Add slight indent if no bullet

        case "image":
            // Only render if content path is provided and not empty
            if let contentPath = block.content, !contentPath.isEmpty {
                VStack(spacing: 4 * scaleFactor) {
                    if contentPath.hasPrefix("sf=") || contentPath.hasPrefix("SF=") {
                        // SF Symbol rendering
                        let symbolName = String(contentPath.dropFirst(3))
                        Image(systemName: symbolName)
                            .font(.system(size: (CGFloat(block.imageHeight ?? 200) * scaleFactor) * 0.5))
                            .foregroundStyle(accentColor ?? .secondary)
                            .frame(height: CGFloat(block.imageHeight ?? 200) * scaleFactor)

                        if let caption = block.caption {
                            Text(caption)
                                .font(.system(size: 11 * scaleFactor))
                                .foregroundStyle(.secondary)
                                .italic()
                                .multilineTextAlignment(.center)
                                .padding(.top, 2 * scaleFactor)
                        }
                    } else if contentPath.lowercased().hasSuffix(".gif") {
                        // Animated GIF — use AsyncImageView which handles GIF playback
                        let imageWidth = CGFloat(block.imageWidth ?? 400) * scaleFactor
                        AsyncImageView(
                            iconPath: contentPath,
                            basePath: nil,
                            maxWidth: imageWidth,
                            maxHeight: imageWidth * 0.75,
                            imageFit: .fit,
                            fallback: { EmptyView() }
                        )
                        .padding(.vertical, 4 * scaleFactor)
                    } else if let image = loadInstructionalImage(path: contentPath) {
                        let imageWidth = CGFloat(block.imageWidth ?? 400) * scaleFactor
                        let shape = block.imageShape ?? "rectangle"
                        let showBorder = block.imageBorder ?? true

                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: imageWidth)
                            .clipShape(getImageClipShape(for: shape))
                            .overlay(
                                showBorder ? getImageClipShape(for: shape)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1) : nil
                            )
                            .shadow(color: showBorder ? Color.black.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 2)
                            .padding(.vertical, 4 * scaleFactor)

                        if let caption = block.caption {
                            Text(caption)
                                .font(.system(size: 11 * scaleFactor))
                                .foregroundStyle(.secondary)
                                .italic()
                                .multilineTextAlignment(.center)
                                .padding(.top, 2 * scaleFactor)
                        }
                    } else {
                        // Fallback if image not found - only show in debug mode
                        if appvars.debugMode {
                            HStack(spacing: 8 * scaleFactor) {
                                Image(systemName: "photo")
                                    .font(.system(size: 13 * scaleFactor))
                                    .foregroundStyle(.secondary)
                                Text("Image not found: \(contentPath)")
                                    .font(.system(size: 11 * scaleFactor))
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                            .padding(10 * scaleFactor)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                        }
                    }
                }
            }

        case "video":
            // Video player - reuses main dialog's VideoView
            if let videoPath = block.content, !videoPath.isEmpty {
                VStack(spacing: 4 * scaleFactor) {
                    let videoHeight = CGFloat(block.videoHeight ?? 300) * scaleFactor
                    let autoPlay = block.autoplay ?? false

                    VideoView(
                        videourl: videoPath,
                        autoplay: autoPlay,
                        caption: block.caption ?? ""
                    )
                    .frame(height: videoHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .padding(.vertical, 4 * scaleFactor)
                }
            }

        case "webcontent":
            // Embedded web content - simplified version for overlay use
            if let webURL = block.content, !webURL.isEmpty, let url = URL(string: webURL) {
                VStack(spacing: 4 * scaleFactor) {
                    let webHeight = CGFloat(block.webHeight ?? 400) * scaleFactor

                    WebView(url: url) { _ in }
                        .frame(height: webHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.vertical, 4 * scaleFactor)

                    if let caption = block.caption {
                        Text(caption)
                            .font(.system(size: 11 * scaleFactor))
                            .foregroundStyle(.secondary)
                            .italic()
                            .multilineTextAlignment(.center)
                            .padding(.top, 2 * scaleFactor)
                    }
                }
            }

        case "portal-webview":
            // Embedded self-service portal with authentication support (bearer tokens, custom headers)
            // Use portalURL from block, fallback to global portalConfig, or use content field
            let baseURL = block.portalURL ?? inspectState.config?.portalConfig?.portalURL ?? block.content ?? ""
            let pathString = block.portalPath ?? inspectState.config?.portalConfig?.selfServicePath ?? ""
            let fullURLString = pathString.isEmpty ? baseURL : baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + pathString

            if !fullURLString.isEmpty, let url = URL(string: fullURLString) {
                let portalHeight = CGFloat(block.portalHeight ?? 400) * scaleFactor
                let userAgent = block.portalUserAgent ?? inspectState.config?.portalConfig?.userAgent

                // Build custom headers using helper
                let customHeaders = buildPortalHeaders(
                    brandingKey: block.portalBrandingKey ?? inspectState.config?.portalConfig?.brandingKey,
                    brandingHeaderName: block.portalBrandingHeader ?? inspectState.config?.portalConfig?.brandingHeaderName,
                    blockHeaders: block.portalCustomHeaders
                )

                VStack(spacing: 4 * scaleFactor) {
                    // Use full PortalWebView with authentication support
                    EmbeddedPortalWebView(
                        url: url,
                        customHeaders: customHeaders,
                        userAgent: userAgent,
                        ephemeralSession: inspectState.config?.portalConfig?.ephemeralSession ?? false,
                        errorDetectionPhrases: inspectState.config?.portalConfig?.errorDetectionPhrases ?? [],
                        errorDetectionThreshold: inspectState.config?.portalConfig?.errorDetectionThreshold ?? 2,
                        openExternalLinksInBrowser: inspectState.config?.portalConfig?.openExternalLinksInBrowser ?? true,
                        height: portalHeight
                    )
                    .id("portal-\(url.absoluteString)")  // Force recreation on URL change
                    .padding(.vertical, 4 * scaleFactor)

                    if let caption = block.caption {
                        Text(caption)
                            .font(.system(size: 11 * scaleFactor))
                            .foregroundStyle(.secondary)
                            .italic()
                            .multilineTextAlignment(.center)
                            .padding(.top, 2 * scaleFactor)
                    }
                }
            }

        case "checkbox":
            VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                HStack {
                    if let fieldId = block.id {
                        Toggle(isOn: Binding(
                            get: {
                                // Check state first, then fall back to default value from config
                                if let checked = inspectState.guidanceFormInputs[itemId]?.checkboxes[fieldId] {
                                    return checked
                                }
                                // Parse default from block.value ("true", "yes", "1" → true)
                                if let value = block.value?.lowercased() {
                                    return value == "true" || value == "yes" || value == "1"
                                }
                                return false
                            },
                            set: { newValue in
                                // Ensure state exists before setting (fixes race condition with async init)
                                if inspectState.guidanceFormInputs[itemId] == nil {
                                    inspectState.initializeGuidanceFormState(for: itemId)
                                }
                                inspectState.guidanceFormInputs[itemId]?.checkboxes[fieldId] = newValue
                                writeLog("GuidanceContentView: Checkbox '\(fieldId)' set to \(newValue)", logLevel: .info)
                            }
                        )) {
                            Text(block.content ?? "")
                                .font(.system(size: 13 * scaleFactor))
                                .foregroundStyle(.primary)
                        }
                        .toggleStyle(.checkbox)
                    } else {
                        // Fallback for checkbox without id (display-only)
                        Toggle(isOn: .constant(false)) {
                            Text(block.content ?? "")
                                .font(.system(size: 13 * scaleFactor))
                                .foregroundStyle(.primary)
                        }
                        .toggleStyle(.checkbox)
                        .disabled(true)
                    }
                }

                if block.required == true {
                    Text("* Required")
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(palette.warning)
                        .italic()
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "dropdown":
            VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                HStack {
                    Text(block.content ?? "")
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(.primary)

                    Spacer()

                    if let options = block.options, !options.isEmpty, let fieldId = block.id {
                        Picker("", selection: Binding(
                            get: {
                                inspectState.guidanceFormInputs[itemId]?.dropdowns[fieldId] ?? block.value ?? options.first ?? ""
                            },
                            set: { newValue in
                                // Ensure state exists before setting (fixes race condition with async init)
                                if inspectState.guidanceFormInputs[itemId] == nil {
                                    inspectState.initializeGuidanceFormState(for: itemId)
                                }
                                inspectState.guidanceFormInputs[itemId]?.dropdowns[fieldId] = newValue
                                writeLog("GuidanceContentView: Dropdown '\(fieldId)' set to '\(newValue)'", logLevel: .info)
                            }
                        )) {
                            ForEach(options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200 * scaleFactor)
                    } else if let options = block.options, !options.isEmpty {
                        // Fallback for dropdown without id (display-only)
                        Menu {
                            ForEach(options, id: \.self) { option in
                                Button(option) { }
                            }
                        } label: {
                            HStack {
                                Text(block.value ?? "Select...")
                                    .font(.system(size: 12 * scaleFactor))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10 * scaleFactor))
                            }
                            .padding(.horizontal, 12 * scaleFactor)
                            .padding(.vertical, 6 * scaleFactor)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                        }
                        .frame(maxWidth: 200 * scaleFactor)
                        .disabled(true)
                    }
                }

                if block.required == true {
                    Text("* Required")
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(palette.warning)
                        .italic()
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "radio":
            VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                if let content = block.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 13 * scaleFactor, weight: .medium))
                        .foregroundStyle(.primary)
                }

                if let options = block.options, !options.isEmpty, let fieldId = block.id {
                    let selectedValue = Binding(
                        get: {
                            inspectState.guidanceFormInputs[itemId]?.radios[fieldId] ?? block.value ?? ""
                        },
                        set: { newValue in
                            // Ensure state exists before setting (fixes race condition with async init)
                            if inspectState.guidanceFormInputs[itemId] == nil {
                                inspectState.initializeGuidanceFormState(for: itemId)
                            }
                            inspectState.guidanceFormInputs[itemId]?.radios[fieldId] = newValue
                            writeLog("GuidanceContentView: Radio '\(fieldId)' set to '\(newValue)'", logLevel: .info)
                        }
                    )

                    VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                        ForEach(options, id: \.self) { option in
                            HStack {
                                Image(systemName: option == selectedValue.wrappedValue ? "circle.inset.filled" : "circle")
                                    .font(.system(size: 14 * scaleFactor))
                                    .foregroundStyle(option == selectedValue.wrappedValue ? (accentColor ?? .blue) : .secondary)

                                Text(option)
                                    .font(.system(size: 13 * scaleFactor))
                                    .foregroundStyle(.primary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedValue.wrappedValue = option
                            }
                        }
                    }
                    .padding(.leading, 4 * scaleFactor)
                } else if let options = block.options, !options.isEmpty {
                    // Fallback for radio without id (display-only)
                    VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                        ForEach(options, id: \.self) { option in
                            HStack {
                                Image(systemName: option == block.value ? "circle.inset.filled" : "circle")
                                    .font(.system(size: 14 * scaleFactor))
                                    .foregroundStyle(option == block.value ? (accentColor ?? .blue) : .secondary)

                                Text(option)
                                    .font(.system(size: 13 * scaleFactor))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding(.leading, 4 * scaleFactor)
                }

                if block.required == true {
                    Text("* Required")
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(palette.warning)
                        .italic()
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "toggle":
            HStack {
                if let content = block.content {
                    Text(content)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(.primary)
                }

                if let helpText = block.helpText, !helpText.isEmpty {
                    InfoPopoverButton(helpText: helpText, scaleFactor: scaleFactor)
                }

                Spacer()

                if let fieldId = block.id {
                    let isOn = Binding(
                        get: {
                            inspectState.guidanceFormInputs[itemId]?.toggles[fieldId] ?? (block.value == "true")
                        },
                        set: { newValue in
                            if inspectState.guidanceFormInputs[itemId] == nil {
                                inspectState.initializeGuidanceFormState(for: itemId)
                            }
                            inspectState.guidanceFormInputs[itemId]?.toggles[fieldId] = newValue
                            writeLog("GuidanceContentView: Toggle '\(fieldId)' set to \(newValue)", logLevel: .info)

                            // Write to interaction log for script monitoring
                            inspectState.writeToInteractionLog("toggle:\(itemId):\(fieldId):\(newValue)")
                        }
                    )

                    Toggle("", isOn: isOn)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "slider":
            VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                HStack {
                    if let label = block.label {
                        Text(label)
                            .font(.system(size: 13 * scaleFactor, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                    if let helpText = block.helpText, !helpText.isEmpty {
                        InfoPopoverButton(helpText: helpText, scaleFactor: scaleFactor)
                    }

                    Spacer()

                    if let fieldId = block.id {
                        let currentValue = inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] ??
                                          Double(block.value ?? "0") ?? 0.0

                        // Show label from discreteSteps if available, otherwise show numeric value
                        if let steps = block.discreteSteps,
                           let matchingStep = steps.first(where: { $0.value == currentValue }) {
                            Text(matchingStep.label)
                                .font(.system(size: 13 * scaleFactor, weight: .medium))
                                .foregroundStyle(.secondary)
                        } else {
                            HStack(spacing: 4 * scaleFactor) {
                                Text("\(Int(currentValue))")
                                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                                    .foregroundStyle(.secondary)

                                if let unit = block.unit {
                                    Text(unit)
                                        .font(.system(size: 12 * scaleFactor))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let fieldId = block.id {
                    // Check if discrete steps are defined
                    if let steps = block.discreteSteps, steps.count >= 2 {
                        // Discrete steps mode - slider moves between step indices
                        let stepCount = steps.count
                        let sortedSteps = steps.sorted { $0.value < $1.value }

                        let discreteBinding = Binding(
                            get: {
                                let value = inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] ??
                                           Double(block.value ?? "\(sortedSteps[0].value)") ?? sortedSteps[0].value
                                return Double(sortedSteps.firstIndex { $0.value == value } ?? 0)
                            },
                            set: { newIndex in
                                let clampedIndex = Int(max(0, min(newIndex, Double(stepCount - 1))))
                                let newValue = sortedSteps[clampedIndex].value

                                if inspectState.guidanceFormInputs[itemId] == nil {
                                    inspectState.initializeGuidanceFormState(for: itemId)
                                }
                                inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] = newValue
                                writeLog("GuidanceContentView: Slider '\(fieldId)' set to \(newValue) (\(sortedSteps[clampedIndex].label))", logLevel: .info)

                                // Write to interaction log for script monitoring
                                inspectState.writeToInteractionLog("slider:\(itemId):\(fieldId):\(newValue)")
                            }
                        )

                        Slider(value: discreteBinding, in: 0...Double(stepCount - 1), step: 1)
                    } else {
                        // Standard continuous slider mode
                        let minValue = block.min ?? 0.0
                        let maxValue = block.max ?? 100.0
                        let stepValue = block.step ?? 1.0

                        let sliderBinding = Binding(
                            get: {
                                inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] ??
                                Double(block.value ?? "\(minValue)") ?? minValue
                            },
                            set: { newValue in
                                if inspectState.guidanceFormInputs[itemId] == nil {
                                    inspectState.initializeGuidanceFormState(for: itemId)
                                }
                                inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] = newValue
                                writeLog("GuidanceContentView: Slider '\(fieldId)' set to \(newValue)", logLevel: .info)

                                // Write to interaction log for script monitoring
                                inspectState.writeToInteractionLog("slider:\(itemId):\(fieldId):\(newValue)")
                            }
                        )

                        Slider(value: sliderBinding, in: minValue...maxValue, step: stepValue)
                    }
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "textfield":
            VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                HStack {
                    if let content = block.content, !content.isEmpty {
                        Text(content)
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(.primary)
                    }

                    if let helpText = block.helpText, !helpText.isEmpty {
                        InfoPopoverButton(helpText: helpText, scaleFactor: scaleFactor)
                    }

                    Spacer()

                    if let fieldId = block.id {
                        let textBinding = Binding(
                            get: {
                                // 1. Check user input first
                                if let userValue = inspectState.guidanceFormInputs[itemId]?.textfields[fieldId] {
                                    return userValue
                                }
                                // 2. Resolve inherit source
                                if let inheritSpec = block.inherit {
                                    if let inherited = inspectState.resolveInheritValue(inheritSpec, basePath: inspectState.uiConfiguration.iconBasePath) {
                                        return inherited
                                    }
                                }
                                // 3. Fall back to default value
                                return block.value ?? ""
                            },
                            set: { newValue in
                                if inspectState.guidanceFormInputs[itemId] == nil {
                                    inspectState.initializeGuidanceFormState(for: itemId)
                                }
                                inspectState.guidanceFormInputs[itemId]?.textfields[fieldId] = newValue
                                writeLog("GuidanceContentView: Textfield '\(fieldId)' updated", logLevel: .info)
                                inspectState.writeToInteractionLog("textfield:\(itemId):\(fieldId):\(newValue)")
                            }
                        )

                        Group {
                            if block.secure == true {
                                SecureField(block.placeholder ?? "", text: textBinding)
                            } else {
                                TextField(block.placeholder ?? "", text: textBinding)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200 * scaleFactor)
                    }
                }

                if block.required == true {
                    Text("* Required")
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundStyle(palette.warning)
                        .italic()
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "button":
            if let buttonLabel = block.content {
                applyButtonStyle(
                    Button(action: {
                        handleButtonAction(block: block, itemId: itemId, inspectState: inspectState)
                    }) {
                        if let icon = block.icon {
                            Label(buttonLabel, systemImage: icon)
                        } else {
                            Text(buttonLabel)
                        }
                    }
                    .controlSize(.regular),
                    styleString: block.buttonStyle
                )
                .tint(accentColor)
            }

        case "status-badge":
            if let label = block.label, let state = block.state {
                let autoColor = block.autoColor ?? true
                let customColor: Color? = {
                    if let colorHex = block.color {
                        return Color(hex: colorHex)
                    }
                    return nil
                }()

                StatusBadgeView(
                    label: label,
                    state: state,
                    icon: block.icon,
                    autoColor: autoColor,
                    customColor: customColor,
                    scaleFactor: scaleFactor
                )
                .id("status-badge-\(label)-\(state)")
            } else if appvars.debugMode {
                Text("status-badge requires 'label' and 'state' properties")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.red)
                    .italic()
            }

        case "comparison-table":
            // swiftlint:disable:next redundant_nil_coalescing
            if let label = block.label ?? block.content.map({ $0.isEmpty ? nil : $0 }) ?? nil,  // Flatten Optional<String?> to String?
               let expected = block.expected,
               let actual = block.actual {
                let autoColor = block.autoColor ?? true
                let customColor: Color? = {
                    if let colorHex = block.color {
                        return Color(hex: colorHex)
                    }
                    return nil
                }()

                ComparisonTableView(
                    label: label,
                    expected: expected,
                    actual: actual,
                    expectedLabel: block.expectedLabel ?? "Expected",
                    actualLabel: block.actualLabel ?? "Actual",
                    expectedIcon: block.expectedIcon,
                    actualIcon: block.actualIcon,
                    comparisonStyle: block.comparisonStyle,
                    highlightCells: block.highlightCells ?? false,
                    autoColor: autoColor,
                    customColor: customColor,
                    expectedColor: block.expectedColor.flatMap { Color(hex: $0) },
                    actualColor: block.actualColor.flatMap { Color(hex: $0) },
                    scaleFactor: scaleFactor,
                    stateOverride: block.state
                )
                .id("comparison-\(label)-\(actual)-\(block.state ?? "")-\(block.comparisonStyle ?? "stacked")")
            } else if appvars.debugMode {
                Text("comparison-table requires 'expected' and 'actual' properties")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.red)
                    .italic()
            }

        case "phase-tracker":
            if let currentPhase = block.currentPhase,
               let phases = block.phases, !phases.isEmpty {
                let style = block.style ?? "stepper"

                PhaseTrackerView(
                    currentPhase: currentPhase,
                    phases: phases,
                    style: style,
                    scaleFactor: scaleFactor
                )
                .id("phase-tracker-\(currentPhase)")
            } else if appvars.debugMode {
                Text("phase-tracker requires 'currentPhase' and 'phases' properties")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.red)
                    .italic()
            }

        case "progress-bar":
            let progressStyle = block.style ?? "indeterminate"
            let progressValue = block.progress ?? 0.0
            let progressLabel = block.label ?? block.content
            // Auto-detect determinate mode: if progress value is set (non-zero), use determinate style
            let isDeterminate = progressStyle == "determinate" || (block.progress != nil && progressValue > 0)

            VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                if let label = progressLabel, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 12 * scaleFactor, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if isDeterminate {
                    // Determinate progress with value
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)
                        .scaleEffect(y: 1.5 * scaleFactor, anchor: .center)
                        .frame(height: 12 * scaleFactor)
                } else {
                    // Indeterminate animated progress (brownian/spinner)
                    IndeterminateProgressView()
                        .frame(height: 8 * scaleFactor)
                }
            }

        case "image-carousel":
            if let images = block.images, !images.isEmpty {
                ImageCarouselView(
                    images: images,
                    iconBasePath: iconBasePath,
                    scaleFactor: scaleFactor,
                    imageWidth: CGFloat(block.imageWidth ?? 400),
                    imageHeight: CGFloat(block.imageHeight ?? 300),
                    imageShape: block.imageShape ?? "rectangle",
                    showDots: block.showDots ?? true,
                    showArrows: block.showArrows ?? true,
                    captions: block.captions,
                    autoAdvance: block.autoAdvance ?? false,
                    autoAdvanceDelay: block.autoAdvanceDelay ?? 3.0,
                    transitionStyle: block.transitionStyle ?? "slide",
                    currentIndex: block.currentIndex ?? 0
                )
                .id("carousel-\(images.joined(separator: ","))-\(block.currentIndex ?? 0)")
            } else if appvars.debugMode {
                Text("image-carousel requires 'images' array with at least one image path")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.red)
                    .italic()
            }

        case "compliance-card":
            if let categoryName = block.categoryName,
               let passed = block.passed,
               let total = block.total {
                ComplianceCardView(
                    categoryName: categoryName,
                    passed: passed,
                    total: total,
                    icon: block.cardIcon,
                    checkDetails: block.checkDetails,
                    scaleFactor: scaleFactor,
                    colorThresholds: inspectState.colorThresholds
                )
            } else if appvars.debugMode {
                Text("compliance-card requires 'categoryName', 'passed', and 'total' fields")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.red)
                    .italic()
            }

        case "compliance-header":
            if let passed = block.passed,
               let total = block.total {
                let failed = total - passed
                ComplianceDashboardHeader(
                    title: block.label ?? "Compliance Dashboard",
                    subtitle: block.content,
                    icon: block.icon,
                    passed: passed,
                    failed: failed,
                    scaleFactor: scaleFactor,
                    colorThresholds: inspectState.colorThresholds
                )
            } else if appvars.debugMode {
                Text("compliance-header requires 'passed' and 'total' fields")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.red)
                    .italic()
            }

        case "feature-table":
            if let columns = block.columns, !columns.isEmpty,
               let rows = block.rows, !rows.isEmpty {
                FeatureTableView(
                    columns: columns,
                    rows: rows,
                    style: block.style,
                    scaleFactor: scaleFactor
                )
            } else if appvars.debugMode {
                Text("feature-table requires non-empty 'columns' and 'rows' arrays")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.red)
                    .italic()
            }

        case "wallpaper-picker":
            if let categories = block.wallpaperCategories, !categories.isEmpty {
                let layoutMode: WallpaperPickerView.WallpaperLayout = {
                    switch block.wallpaperLayout?.lowercased() {
                    case "grid": return .grid
                    case "row": return .row
                    default: return .categories
                    }
                }()
                WallpaperPickerView(
                    categories: categories,
                    columns: block.wallpaperColumns ?? 3,
                    imageFit: block.wallpaperImageFit ?? "fill",
                    thumbnailHeight: block.wallpaperThumbnailHeight ?? 100,
                    selectionKey: block.wallpaperSelectionKey ?? "wallpaper",
                    showPath: block.wallpaperShowPath ?? false,
                    confirmButtonText: block.wallpaperConfirmButton,
                    multiSelectCount: block.wallpaperMultiSelect ?? 0,
                    scaleFactor: scaleFactor,
                    layout: layoutMode,
                    inspectState: inspectState,
                    itemId: itemId
                )
            } else if appvars.debugMode {
                Text("wallpaper-picker requires non-empty 'wallpaperCategories' array")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.red)
                    .italic()
            }

        case "install-list":
            // Traditional installation progress list with app icons and status indicators
            // Dynamically resolves status from inspectState when installItem.itemId links to items[]
            if let installItems = block.installItems, !installItems.isEmpty {
                VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                    ForEach(installItems.indices, id: \.self) { index in
                        let item = installItems[index]
                        let resolvedStatus: String = {
                            if let linkedId = item.itemId {
                                if inspectState.completedItems.contains(linkedId) {
                                    return "success"
                                } else if inspectState.downloadingItems.contains(linkedId) {
                                    return "progress"
                                }
                            }
                            return item.status ?? "pending"
                        }()
                        InstallListRowView(
                            title: item.title,
                            subtitle: item.subtitle,
                            icon: item.icon,
                            status: resolvedStatus,
                            progress: item.progress ?? 0,
                            scaleFactor: scaleFactor,
                            iconBasePath: iconBasePath
                        )
                    }
                }
            } else if appvars.debugMode {
                Text("install-list requires non-empty 'installItems' array")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.red)
                    .italic()
            }

        case "bento-grid":
            // Bento grid layout with variable cell sizes (1x1, 2x1, 1x2, 2x2)
            if let cells = block.bentoCells, !cells.isEmpty {
                let columns = block.bentoColumns ?? 4
                let rowHeight = block.bentoRowHeight ?? 140
                let gap = block.bentoGap ?? 12

                let accentColor: Color = {
                    if let hex = inspectState.config?.highlightColor {
                        return Color(hex: hex)
                    }
                    return .accentColor
                }()

                BentoGridView(
                    cells: cells,
                    columns: columns,
                    rowHeight: CGFloat(rowHeight),
                    gap: CGFloat(gap),
                    scaleFactor: scaleFactor,
                    accentColor: accentColor,
                    iconBasePath: iconBasePath,
                    tintColor: block.bentoTintColor.flatMap { Color(hex: $0) },
                    inspectState: inspectState
                )
            } else if appvars.debugMode {
                Text("bento-grid requires non-empty 'bentoCells' array")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.red)
                    .italic()
            }

        default:
            Text(block.content ?? "")
                .font(.system(size: 13 * scaleFactor))
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Image Loading Helper

    /// Load instructional image from absolute or relative path using ImageResolver
    private func loadInstructionalImage(path: String) -> NSImage? {
        writeLog("GuidanceContentView: Loading image from path='\(path)' with iconBasePath='\(iconBasePath ?? "nil")'", logLevel: .info)

        // Use ImageResolver for consistent path resolution across the app
        let resolver = ImageResolver.shared

        // Resolve the path using basePath (if provided) or standard search locations
        if let resolvedPath = resolver.resolveImagePath(path, basePath: iconBasePath, fallbackIcon: nil) {
            writeLog("GuidanceContentView: ImageResolver returned resolvedPath='\(resolvedPath)'", logLevel: .info)

            // Only try to load as a file if it looks like a file path (starts with /)
            // This excludes SF Symbols and other special formats that ImageResolver might return
            if resolvedPath.hasPrefix("/") && FileManager.default.fileExists(atPath: resolvedPath) {
                writeLog("GuidanceContentView: Loading image from resolved file path: \(resolvedPath)", logLevel: .info)
                return NSImage(contentsOfFile: resolvedPath)
            } else if !resolvedPath.hasPrefix("/") {
                // Not a file path - ImageResolver returned it as-is (like SF Symbol or URL)
                // These aren't supported for instructional images which must be actual image files
                writeLog("GuidanceContentView: Resolved path is not a file path (SF Symbol or URL?): \(resolvedPath)", logLevel: .info)
            } else {
                writeLog("GuidanceContentView: Resolved file path does not exist: \(resolvedPath)", logLevel: .info)
            }
        } else {
            writeLog("GuidanceContentView: ImageResolver returned nil for path: \(path)", logLevel: .info)
        }

        // If ImageResolver doesn't find it, try absolute path as last resort
        if path.hasPrefix("/") {
            if FileManager.default.fileExists(atPath: path) {
                writeLog("GuidanceContentView: Loading image from original absolute path: \(path)", logLevel: .info)
                return NSImage(contentsOfFile: path)
            } else {
                writeLog("GuidanceContentView: Original absolute path does not exist: \(path)", logLevel: .info)
            }
        }

        writeLog("GuidanceContentView: Failed to load image from path: \(path)", logLevel: .info)
        return nil
    }

    /// Get the appropriate clip shape for image display
    private func getImageClipShape(for shape: String) -> AnyShape {
        switch shape.lowercased() {
        case "square":
            return AnyShape(RoundedRectangle(cornerRadius: 8))
        case "circle":
            return AnyShape(Circle())
        default: // "rectangle"
            return AnyShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func getTextColor(for block: InspectConfig.GuidanceContent) -> Color {
        if let colorHex = block.color {
            return Color(hex: colorHex)
        }
        return .primary
    }

    // MARK: - Template Variable Resolution

    /// Resolve template variables in content string (e.g., {{fieldId}} or {{stepId.fieldId}})
    /// Looks up values from inspectState.guidanceFormInputs and replaces placeholders with actual values
    private func resolveTemplateVariables(_ content: String, inspectState: InspectState) -> String {
        var resolved = content

        // Find all {{variable}} patterns
        let pattern = "\\{\\{([^}]+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return content
        }

        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))

        // Process matches in reverse order to preserve string indices
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: content),
                  let variableRange = Range(match.range(at: 1), in: content) else {
                continue
            }

            let variable = String(content[variableRange])
            let value = resolveVariable(variable, from: inspectState)

            resolved.replaceSubrange(matchRange, with: value)
        }

        return resolved
    }

    /// Resolve a single variable (fieldId or stepId.fieldId) to its actual value
    /// Also supports system variables like serialNumber, computerModel, userName, etc.
    private func resolveVariable(_ variable: String, from inspectState: InspectState) -> String {
        let trimmed = variable.trimmingCharacters(in: .whitespaces)

        // Check for system variables first
        if let systemValue = resolveSystemVariable(trimmed) {
            return systemValue
        }

        // Check if it's a stepId.fieldId pattern
        if trimmed.contains(".") {
            let components = trimmed.split(separator: ".", maxSplits: 1).map(String.init)
            guard components.count == 2 else {
                return "(invalid variable format)"
            }

            let stepId = components[0]
            let fieldId = components[1]

            // Look up value in specific step
            if let formState = inspectState.guidanceFormInputs[stepId] {
                // Check dropdowns first (most common)
                if let value = formState.dropdowns[fieldId], !value.isEmpty {
                    return value
                }
                // Then radios
                if let value = formState.radios[fieldId], !value.isEmpty {
                    return value
                }
                // Then checkboxes (return Yes/No)
                if let checked = formState.checkboxes[fieldId] {
                    return checked ? "Yes" : "No"
                }
            }

            return "(not set)"
        } else {
            // Simple fieldId - search all steps
            let fieldId = trimmed

            // Search through all form states
            for (_, formState) in inspectState.guidanceFormInputs {
                // Check dropdowns
                if let value = formState.dropdowns[fieldId], !value.isEmpty {
                    return value
                }
                // Check radios
                if let value = formState.radios[fieldId], !value.isEmpty {
                    return value
                }
                // Check checkboxes
                if let checked = formState.checkboxes[fieldId] {
                    return checked ? "Yes" : "No"
                }
            }

            return "(not set)"
        }
    }

    /// Resolve system template variables like serialNumber, computerModel, userName, etc.
    /// Returns nil if the variable name is not a recognized system variable.
    private func resolveSystemVariable(_ variable: String) -> String? {
        let systemInfo = getEnvironmentVars()

        switch variable {
        case "serialNumber":
            return systemInfo["serialnumber"] ?? "Unknown"
        case "computerModel":
            return systemInfo["computermodel"] ?? "Unknown"
        case "computerName":
            return systemInfo["computername"] ?? "Unknown"
        case "userName":
            return systemInfo["username"] ?? "Unknown"
        case "userFullName":
            return systemInfo["userfullname"] ?? "Unknown"
        case "osVersion":
            let v = ProcessInfo.processInfo.operatingSystemVersion
            return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        case "osName":
            return systemInfo["osname"] ?? "macOS"
        default:
            return nil  // Not a system variable
        }
    }
}


// MARK: - Guidance Helper Functions

/// Get default button text for step type
func getDefaultButtonText(for stepType: String?) -> String {
    guard let stepType = stepType else { return "Continue" }

    switch stepType {
    case "confirmation":
        return "Confirm"
    case "processing":
        return "Start"
    case "completion":
        return "Continue"
    default:
        return "Continue"
    }
}

/// Check if step has guidance content
func hasGuidanceContent(_ item: InspectConfig.ItemConfig) -> Bool {
    return item.guidanceContent?.isEmpty == false
}

// MARK: - Install List Row View

/// Individual row in an install list showing app icon, title, and status indicator
struct InstallListRowView: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let status: String
    let progress: Double
    let scaleFactor: CGFloat
    let iconBasePath: String?
    @Environment(\.palette) private var palette

    private var statusColor: Color {
        switch status {
        case "success": return palette.success
        case "fail": return palette.error
        case "wait", "pending": return .gray
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12 * scaleFactor) {
            // App icon
            iconView
                .frame(width: 40 * scaleFactor, height: 40 * scaleFactor)

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(title)
                    .font(.system(size: 14 * scaleFactor, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status indicator
            statusView
        }
        .padding(.vertical, 6 * scaleFactor)
        .padding(.horizontal, 12 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(Color.gray.opacity(0.08))
        )
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconPath = icon {
            if iconPath.hasPrefix("/") || iconPath.contains(".") {
                // File path - load image
                if let nsImage = loadIcon(path: iconPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8 * scaleFactor))
                } else {
                    defaultIcon
                }
            } else {
                // SF Symbol
                Image(systemName: iconPath)
                    .font(.system(size: 24 * scaleFactor))
                    .foregroundStyle(.secondary)
            }
        } else {
            defaultIcon
        }
    }

    private var defaultIcon: some View {
        RoundedRectangle(cornerRadius: 8 * scaleFactor)
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Image(systemName: "app.fill")
                    .font(.system(size: 20 * scaleFactor))
                    .foregroundStyle(.secondary)
            )
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case "success":
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22 * scaleFactor))
                .foregroundStyle(palette.success)

        case "fail":
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22 * scaleFactor))
                .foregroundStyle(palette.error)

        case "wait":
            ProgressView()
                .scaleEffect(0.8 * scaleFactor)

        case "progress":
            ProgressView(value: progress, total: 100)
                .progressViewStyle(CircularProgressViewStyle(size: 22 * scaleFactor))
                .frame(width: 22 * scaleFactor, height: 22 * scaleFactor)

        case "pending":
            Image(systemName: "circle")
                .font(.system(size: 20 * scaleFactor))
                .foregroundStyle(.gray.opacity(0.5))

        default:
            Image(systemName: "circle")
                .font(.system(size: 20 * scaleFactor))
                .foregroundStyle(.gray.opacity(0.5))
        }
    }

    private func loadIcon(path: String) -> NSImage? {
        // Resolve path using base path if available
        let fullPath: String
        if path.hasPrefix("/") {
            fullPath = path
        } else if let basePath = iconBasePath {
            fullPath = (basePath as NSString).appendingPathComponent(path)
        } else {
            fullPath = path
        }
        return NSImage(contentsOfFile: fullPath)
    }
}
