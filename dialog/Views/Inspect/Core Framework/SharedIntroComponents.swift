//
//  SharedIntroComponents.swift
//  dialog
//
//  Reusable intro/outro screen components for branded setup assistant flows.
//  Used by Preset6, Preset5, and other presets that support intro screens.
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//

import SwiftUI

// MARK: - Hero Image Component

/// Configurable hero image for intro/outro screens
/// Supports SF Symbols, image files, and multiple shapes (circle, roundedSquare, square, none)
struct IntroHeroImage: View {
    let path: String
    let shape: String
    let size: Double
    let accentColor: Color
    let sfSymbolColor: Color?
    let sfSymbolWeight: Font.Weight
    let basePath: String?

    init(
        path: String,
        shape: String = "circle",
        size: Double = 200,
        accentColor: Color = .blue,
        sfSymbolColor: Color? = nil,
        sfSymbolWeight: Font.Weight = .medium,
        basePath: String? = nil
    ) {
        self.path = path
        self.shape = shape
        self.size = size
        self.accentColor = accentColor
        self.sfSymbolColor = sfSymbolColor
        self.sfSymbolWeight = sfSymbolWeight
        self.basePath = basePath
    }

    var body: some View {
        Group {
            if path.hasPrefix("SF=") {
                // SF Symbol
                let symbolName = String(path.dropFirst(3))
                sfSymbolView(symbolName: symbolName)
            } else {
                // Image file
                imageFileView(path: path)
            }
        }
        .modifier(ConditionalClipShape(shape: shape, size: size))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    @ViewBuilder
    private func sfSymbolView(symbolName: String) -> some View {
        Image(systemName: symbolName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .font(.system(size: size * 0.5, weight: sfSymbolWeight))
            .frame(width: size, height: size)
            .foregroundStyle(sfSymbolColor ?? accentColor)
    }

    @ViewBuilder
    private func imageFileView(path: String) -> some View {
        if let nsImage = loadImage(path: path) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
        } else {
            // Fallback placeholder
            Image(systemName: "photo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        }
    }

    /// Load image with path resolution support
    private func loadImage(path: String) -> NSImage? {
        // Try absolute path first
        if path.hasPrefix("/") {
            if let image = NSImage(contentsOfFile: path) {
                return image
            }
        }

        // Try relative path with basePath
        if let base = basePath {
            let fullPath = (base as NSString).appendingPathComponent(path)
            if let image = NSImage(contentsOfFile: fullPath) {
                return image
            }
        }

        // Try using ImageResolver if available
        if let resolvedPath = ImageResolver.shared.resolveImagePath(path, basePath: basePath, fallbackIcon: nil),
           resolvedPath.hasPrefix("/"),
           let image = NSImage(contentsOfFile: resolvedPath) {
            return image
        }

        // Direct attempt as fallback
        return NSImage(contentsOfFile: path)
    }

    private var clipShape: some Shape {
        switch shape {
        case "roundedSquare":
            return AnyShape(RoundedRectangle(cornerRadius: size * 0.12))
        case "square", "none":
            return AnyShape(Rectangle())
        default: // "circle"
            return AnyShape(Circle())
        }
    }
}

/// Conditional clip shape modifier for hero images
/// Only applies clipping when shape is not "none"
private struct ConditionalClipShape: ViewModifier {
    let shape: String
    let size: Double

    func body(content: Content) -> some View {
        if shape == "none" {
            content
        } else {
            content.clipShape(clipShapeFor(shape: shape, size: size))
        }
    }

    private func clipShapeFor(shape: String, size: Double) -> some Shape {
        switch shape {
        case "roundedSquare":
            return AnyShape(RoundedRectangle(cornerRadius: size * 0.12))
        case "square":
            return AnyShape(Rectangle())
        default: // "circle"
            return AnyShape(Circle())
        }
    }
}

// MARK: - Progress Dots Component

/// Step indicator dots for multi-step intro flows
struct IntroProgressDots: View {
    let currentStep: Int
    let totalSteps: Int
    let accentColor: Color
    let dotSize: CGFloat

    init(currentStep: Int, totalSteps: Int, accentColor: Color = .blue, dotSize: CGFloat = 8) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.accentColor = accentColor
        self.dotSize = dotSize
    }

    var body: some View {
        HStack(spacing: dotSize) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? accentColor : accentColor.opacity(0.3))
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }
}

// MARK: - Footer View Component

/// Footer bar with text and navigation buttons.
/// Logo is rendered as a persistent overlay at Preset5 root level — not in the footer.
struct IntroFooterView<PopoverContent: View>: View {
    let footerText: String?
    let backButtonText: String
    let continueButtonText: String
    let accentColor: Color
    let showBackButton: Bool
    let onBack: (() -> Void)?
    let onContinue: () -> Void
    let continueDisabled: Bool
    let popupButtonText: String?
    let popoverContent: (() -> PopoverContent)?
    let footerLink: String?
    let skipButtonText: String?
    let onSkip: (() -> Void)?
    let inspectConfig: InspectConfig?

    @State private var showPopover: Bool = false

    init(
        footerText: String? = nil,
        backButtonText: String = "Back",
        continueButtonText: String = "Continue",
        accentColor: Color = .blue,
        showBackButton: Bool = true,
        onBack: (() -> Void)? = nil,
        onContinue: @escaping () -> Void,
        continueDisabled: Bool = false,
        popupButtonText: String? = nil,
        footerLink: String? = nil,
        skipButtonText: String? = nil,
        onSkip: (() -> Void)? = nil,
        inspectConfig: InspectConfig? = nil,
        @ViewBuilder popoverContent: @escaping () -> PopoverContent
    ) {
        self.footerText = footerText
        self.backButtonText = backButtonText
        self.continueButtonText = continueButtonText
        self.accentColor = accentColor
        self.showBackButton = showBackButton
        self.onBack = onBack
        self.onContinue = onContinue
        self.continueDisabled = continueDisabled
        self.popupButtonText = popupButtonText
        self.popoverContent = popoverContent
        self.footerLink = footerLink
        self.skipButtonText = skipButtonText
        self.onSkip = onSkip
        self.inspectConfig = inspectConfig
    }

    var body: some View {
        VStack(spacing: 12) {
            // Centered footer link (e.g., assistant step privacy/terms link)
            if let link = footerLink {
                Button(action: {}) {
                    Text(link)
                        .font(.system(size: 13))
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                // Footer text (e.g., branding text)
                if let footerText = footerText {
                    Text(footerText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                }

                // Popup button (e.g., "Install Details...")
                if let popupText = popupButtonText, let content = popoverContent {
                    Button(popupText) {
                        showPopover.toggle()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .font(.body)
                    .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                        content()
                    }
                }

                Spacer()

                // Deferral menu (right side, next to navigation buttons)
                if isDeferralEnabled(config: inspectConfig) {
                    DeferralMenuView(
                        config: inspectConfig,
                        accentColor: accentColor,
                        style: .bordered
                    )
                }

                // Back button
                if showBackButton, let onBack = onBack {
                    Button(backButtonText, action: onBack)
                        .buttonStyle(.bordered)
                        .tint(accentColor)
                        .controlSize(.large)
                }

                // Skip button (secondary action)
                if let skipText = skipButtonText, let onSkip = onSkip {
                    Button(skipText, action: onSkip)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }

                // Continue button
                Button(continueButtonText, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .controlSize(.large)
                    .disabled(continueDisabled)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .tint(accentColor)  // Ensure all buttons inherit tint
    }
}

// Convenience init without popover (preserves existing call sites)
extension IntroFooterView where PopoverContent == EmptyView {
    init(
        footerText: String? = nil,
        backButtonText: String = "Back",
        continueButtonText: String = "Continue",
        accentColor: Color = .blue,
        showBackButton: Bool = true,
        onBack: (() -> Void)? = nil,
        onContinue: @escaping () -> Void,
        continueDisabled: Bool = false,
        footerLink: String? = nil,
        skipButtonText: String? = nil,
        onSkip: (() -> Void)? = nil,
        inspectConfig: InspectConfig? = nil
    ) {
        self.footerText = footerText
        self.backButtonText = backButtonText
        self.continueButtonText = continueButtonText
        self.accentColor = accentColor
        self.showBackButton = showBackButton
        self.onBack = onBack
        self.onContinue = onContinue
        self.continueDisabled = continueDisabled
        self.popupButtonText = nil
        self.popoverContent = nil
        self.footerLink = footerLink
        self.skipButtonText = skipButtonText
        self.onSkip = onSkip
        self.inspectConfig = inspectConfig
    }
}

extension View {
    /// Apply accent color to the view hierarchy for consistent button styling
    @ViewBuilder
    func brandedButtons(_ color: Color) -> some View {
        self.tint(color)
    }
}

// MARK: - Grid Picker Component

/// Grid picker for wallpaper/theme selection screens
struct IntroGridPicker: View {
    let items: [IntroGridItem]
    let columns: Int
    let selectionMode: String  // "single" | "multiple" | "none"
    @Binding var selectedIds: Set<String>
    let accentColor: Color

    init(
        items: [IntroGridItem],
        columns: Int = 3,
        selectionMode: String = "single",
        selectedIds: Binding<Set<String>>,
        accentColor: Color = .blue
    ) {
        self.items = items
        self.columns = columns
        self.selectionMode = selectionMode
        self._selectedIds = selectedIds
        self.accentColor = accentColor
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(items) { item in
                IntroGridCell(
                    item: item,
                    isSelected: selectedIds.contains(item.id),
                    accentColor: accentColor
                ) {
                    toggleSelection(item.id)
                }
            }
        }
        .padding()
    }

    private func toggleSelection(_ id: String) {
        switch selectionMode {
        case "single":
            selectedIds = [id]
        case "multiple":
            if selectedIds.contains(id) {
                selectedIds.remove(id)
            } else {
                selectedIds.insert(id)
            }
        default: // "none"
            break
        }
    }
}

/// Grid item model for IntroGridPicker
struct IntroGridItem: Identifiable, Codable {
    let id: String
    let imagePath: String?
    let sfSymbol: String?
    let title: String?
    let subtitle: String?
    let value: String?
}

/// Individual cell in IntroGridPicker
struct IntroGridCell: View {
    let item: IntroGridItem
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Image content
                imageContent
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Title
                if let title = item.title {
                    Text(title)
                        .font(.caption)
                        .lineLimit(1)
                }

                // Subtitle
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 3)
            )
            .overlay(
                isSelected ?
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accentColor)
                        .font(.title2)
                        .padding(8)
                    : nil,
                alignment: .topTrailing
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var imageContent: some View {
        if let imagePath = item.imagePath, let nsImage = NSImage(contentsOfFile: imagePath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let sfSymbol = item.sfSymbol {
            Image(systemName: sfSymbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(accentColor)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(accentColor.opacity(0.1))
        } else {
            Color.gray.opacity(0.2)
        }
    }
}

// MARK: - Intro Step Container

/// Full-screen container for intro/outro steps with standard layout
struct IntroStepContainer<Content: View>: View {
    let accentColor: Color
    let accentBorderHeight: CGFloat
    let showProgressDots: Bool
    let currentStep: Int
    let totalSteps: Int
    let footerConfig: IntroFooterConfig
    @ViewBuilder let content: () -> Content

    struct IntroFooterConfig {
        let footerText: String?
        let backButtonText: String
        let continueButtonText: String
        let showBackButton: Bool
        let onBack: (() -> Void)?
        let onContinue: () -> Void
        let continueDisabled: Bool
        let footerLink: String?
        let skipButtonText: String?
        let onSkip: (() -> Void)?
        let inspectConfig: InspectConfig?

        init(
            footerText: String? = nil,
            backButtonText: String = "Back",
            continueButtonText: String = "Continue",
            showBackButton: Bool = true,
            onBack: (() -> Void)? = nil,
            onContinue: @escaping () -> Void,
            continueDisabled: Bool = false,
            footerLink: String? = nil,
            skipButtonText: String? = nil,
            onSkip: (() -> Void)? = nil,
            inspectConfig: InspectConfig? = nil
        ) {
            self.footerText = footerText
            self.backButtonText = backButtonText
            self.continueButtonText = continueButtonText
            self.showBackButton = showBackButton
            self.onBack = onBack
            self.onContinue = onContinue
            self.continueDisabled = continueDisabled
            self.footerLink = footerLink
            self.skipButtonText = skipButtonText
            self.onSkip = onSkip
            self.inspectConfig = inspectConfig
        }
    }

    init(
        accentColor: Color = .blue,
        accentBorderHeight: CGFloat = 4,
        showProgressDots: Bool = false,
        currentStep: Int = 0,
        totalSteps: Int = 1,
        footerConfig: IntroFooterConfig,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.accentColor = accentColor
        self.accentBorderHeight = accentBorderHeight
        self.showProgressDots = showProgressDots
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.footerConfig = footerConfig
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Accent border at top
            Rectangle()
                .fill(accentColor)
                .frame(height: accentBorderHeight)

            // Main content area
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Progress dots
            if showProgressDots && totalSteps > 1 {
                IntroProgressDots(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    accentColor: accentColor
                )
                .padding(.bottom, 16)
            }

            // Footer (logo is a persistent overlay at Preset5 root level)
            IntroFooterView(
                footerText: footerConfig.footerText,
                backButtonText: footerConfig.backButtonText,
                continueButtonText: footerConfig.continueButtonText,
                accentColor: accentColor,
                showBackButton: footerConfig.showBackButton,
                onBack: footerConfig.onBack,
                onContinue: footerConfig.onContinue,
                continueDisabled: footerConfig.continueDisabled,
                footerLink: footerConfig.footerLink,
                skipButtonText: footerConfig.skipButtonText,
                onSkip: footerConfig.onSkip,
                inspectConfig: footerConfig.inspectConfig
            )
        }
    }
}

// MARK: - Convenience Extension

extension IntroStepContainer.IntroFooterConfig {
    /// Simple initializer for basic use cases
    init(
        continueButtonText: String = "Continue",
        onContinue: @escaping () -> Void
    ) {
        self.footerText = nil
        self.backButtonText = "Back"
        self.continueButtonText = continueButtonText
        self.showBackButton = false
        self.onBack = nil
        self.onContinue = onContinue
        self.continueDisabled = false
        self.footerLink = nil
        self.skipButtonText = nil
        self.onSkip = nil
        self.inspectConfig = nil
    }
}

// MARK: - Media Content Types

import AVKit
import WebKit

/// Detected media content type based on URL analysis
enum IntroMediaType {
    case video          // Direct video files (.mp4, .mov, .webm, .m4v)
    case animatedImage  // Animated images (.gif, .webp, .apng)
    case staticImage    // Static images (.png, .jpg, .jpeg, .heic)
    case embedVideo     // Embeddable video services (YouTube, Vimeo, etc.)
    case webContent     // Generic web content (HTML, iframes, etc.)
    case unknown        // Fallback to WebView

    /// Detect media type from URL
    static func detect(from url: URL) -> IntroMediaType {
        let pathExtension = url.pathExtension.lowercased()
        let host = url.host?.lowercased() ?? ""
        let urlString = url.absoluteString.lowercased()

        // Check file extension first (most reliable)
        switch pathExtension {
        case "mp4", "mov", "m4v", "webm", "avi", "mkv":
            return .video
        case "gif":
            return .animatedImage
        case "webp", "apng":
            // Could be animated or static - treat as animated
            return .animatedImage
        case "png", "jpg", "jpeg", "heic", "heif", "bmp", "tiff":
            return .staticImage
        case "html", "htm":
            return .webContent
        default:
            break
        }

        // Check known embed video services by host
        let embedVideoHosts = [
            "youtube.com", "youtu.be", "youtube-nocookie.com",
            "vimeo.com", "player.vimeo.com",
            "dailymotion.com", "dai.ly",
            "wistia.com", "fast.wistia.net",
            "loom.com",
            "streamable.com",
            "vidyard.com"
        ]
        if embedVideoHosts.contains(where: { host.contains($0) }) {
            return .embedVideo
        }

        // Check GIF hosting services (often serve without extension)
        let gifHosts = ["giphy.com", "media.giphy.com", "tenor.com", "gfycat.com", "imgur.com"]
        if gifHosts.contains(where: { host.contains($0) }) {
            // Giphy media URLs are direct GIFs
            if urlString.contains("/media/") || urlString.contains(".gif") {
                return .animatedImage
            }
            // Giphy page URLs need embed
            return .webContent
        }

        // Check for direct media URLs (GitHub raw, etc.)
        if urlString.contains("raw.githubusercontent.com") || urlString.contains("/raw/") {
            // Check common patterns in path
            if urlString.contains(".gif") { return .animatedImage }
            if urlString.contains(".mp4") || urlString.contains(".mov") { return .video }
            if urlString.contains(".png") || urlString.contains(".jpg") { return .staticImage }
        }

        // Default: try WebView which can handle most content
        return .unknown
    }
}

/// Universal media player for intro/outro screens
/// Automatically detects content type and uses the appropriate renderer
struct IntroMediaPlayer: View {
    let url: URL?
    let autoplay: Bool
    let height: Double
    let cornerRadius: Double

    init(url: URL?, autoplay: Bool = true, height: Double = 400, cornerRadius: Double = 12) {
        self.url = url
        self.autoplay = autoplay
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let url = url {
                let mediaType = IntroMediaType.detect(from: url)

                switch mediaType {
                case .video:
                    // Native AVPlayer for direct video files
                    IntroNativeVideoPlayer(url: url, autoplay: autoplay)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                case .animatedImage:
                    // NSImageView with animation support
                    IntroAnimatedImageView(url: url, maxWidth: 800, maxHeight: height)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                case .staticImage:
                    // Static image display
                    IntroRemoteImageView(url: url)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                case .embedVideo:
                    // WebView with embed URL conversion
                    IntroEmbedVideoPlayer(url: url, autoplay: autoplay)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                case .webContent, .unknown:
                    // Generic WebView fallback
                    IntroWebContentView(url: url)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            } else {
                // Placeholder for missing media
                mediaPlaceholder
            }
        }
    }

    private var mediaPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Media unavailable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Legacy video player alias for backwards compatibility
typealias IntroVideoPlayer = IntroMediaPlayer

/// Native AVPlayer for local and direct video files
struct IntroNativeVideoPlayer: NSViewRepresentable {
    let url: URL
    let autoplay: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = true

        let player = AVPlayer(url: url)
        playerView.player = player

        if autoplay {
            player.play()
        }

        // Loop video when it ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            if autoplay {
                player.play()
            }
        }

        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Player already configured
    }
}

/// Embedded web player for video services
/// Uses HTML iframe wrapper for maximum compatibility with all video platforms
struct IntroEmbedVideoPlayer: NSViewRepresentable {
    let url: URL
    let autoplay: Bool

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Enable JavaScript
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        // Enable media playback
        config.mediaTypesRequiringUserActionForPlayback = autoplay ? [] : [.all]
        config.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false

        // Common user agent for better compatibility
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // Generate embed URL and load via HTML wrapper for best compatibility
        if let embedURL = getEmbedURL(from: url) {
            let html = createEmbedHTML(embedURL: embedURL, autoplay: autoplay)
            writeLog("IntroEmbedVideoPlayer: Loading via HTML wrapper: \(embedURL)", logLevel: .debug)
            webView.loadHTMLString(html, baseURL: embedURL)
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Already loaded
    }

    /// Generic HTML wrapper for iframe embeds - works with any video platform
    private func createEmbedHTML(embedURL: URL, autoplay: Bool) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; overflow: hidden; background: #000; }
                .video-container { position: relative; width: 100%; height: 100%; }
                iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; }
            </style>
        </head>
        <body>
            <div class="video-container">
                <iframe src="\(embedURL.absoluteString)"
                        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                        allowfullscreen>
                </iframe>
            </div>
        </body>
        </html>
        """
    }

    /// Convert video service URLs to their embed equivalents
    private func getEmbedURL(from url: URL) -> URL? {
        let urlString = url.absoluteString
        let host = url.host?.lowercased() ?? ""

        // YouTube patterns - use youtube-nocookie.com for better embed compatibility
        if host.contains("youtube.com") || host.contains("youtube-nocookie.com") {
            // youtube.com/watch?v=ID -> youtube-nocookie.com/embed/ID
            if urlString.contains("/watch") {
                if let videoID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "v" })?.value {
                    // Use youtube-nocookie for privacy/embed compatibility
                    // Add enablejsapi and playsinline for proper WKWebView support
                    var params = "enablejsapi=1&playsinline=1&rel=0"
                    if autoplay {
                        params += "&autoplay=1&mute=1"
                    }
                    return URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?\(params)")
                }
            }
            // Already an embed URL - ensure proper params
            if urlString.contains("/embed/") {
                var params = "enablejsapi=1&playsinline=1&rel=0"
                if autoplay {
                    params += "&autoplay=1&mute=1"
                }
                // Extract video ID and rebuild with proper domain
                if let videoID = url.pathComponents.last, !videoID.isEmpty {
                    return URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?\(params)")
                }
                return addAutoplayParam(to: url, param: params)
            }
        }

        // YouTube short URLs: youtu.be/ID
        if host.contains("youtu.be") {
            let videoID = url.lastPathComponent
            var params = "enablejsapi=1&playsinline=1&rel=0"
            if autoplay {
                params += "&autoplay=1&mute=1"
            }
            return URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?\(params)")
        }

        // Vimeo patterns
        if host.contains("vimeo.com") {
            if !host.contains("player.vimeo.com") {
                // vimeo.com/ID -> player.vimeo.com/video/ID
                let videoID = url.lastPathComponent
                let autoplayParam = autoplay ? "?autoplay=1&muted=1" : ""
                return URL(string: "https://player.vimeo.com/video/\(videoID)\(autoplayParam)")
            }
            return autoplay ? addAutoplayParam(to: url, param: "autoplay=1&muted=1") : url
        }

        // Dailymotion
        if host.contains("dailymotion.com") || host.contains("dai.ly") {
            if let videoID = url.pathComponents.last {
                let autoplayParam = autoplay ? "?autoplay=1&mute=1" : ""
                return URL(string: "https://www.dailymotion.com/embed/video/\(videoID)\(autoplayParam)")
            }
        }

        // Loom
        if host.contains("loom.com") {
            // loom.com/share/ID -> loom.com/embed/ID
            if urlString.contains("/share/") {
                let embedURL = urlString.replacingOccurrences(of: "/share/", with: "/embed/")
                return URL(string: embedURL)
            }
        }

        // Wistia
        if host.contains("wistia.com") || host.contains("fast.wistia.net") {
            // Wistia URLs often need their embed player
            if let videoID = url.pathComponents.last, !videoID.isEmpty {
                return URL(string: "https://fast.wistia.net/embed/iframe/\(videoID)")
            }
        }

        // Streamable
        if host.contains("streamable.com") {
            let videoID = url.lastPathComponent
            return URL(string: "https://streamable.com/e/\(videoID)")
        }

        // Already an embed URL or unknown - return as-is
        return url
    }

    private func addAutoplayParam(to url: URL, param: String) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let existingQuery = components?.query
        if let existing = existingQuery, !existing.isEmpty {
            components?.query = existing + "&" + param
        } else {
            components?.query = param
        }
        return components?.url ?? url
    }
}

/// Remote static image view (async loading)
struct IntroRemoteImageView: View {
    let url: URL

    @State private var loadedImage: NSImage?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Failed to load image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.1))
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    self.error = error
                    return
                }
                if let data = data, let image = NSImage(data: data) {
                    self.loadedImage = image
                }
            }
        }.resume()
    }
}

/// Generic web content view for HTML, iframes, or any web URL
struct IntroWebContentView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Already loaded
    }
}

// MARK: - Animated GIF View

/// View for displaying animated GIFs
struct IntroAnimatedImageView: NSViewRepresentable {
    let url: URL?
    let maxWidth: Double
    let maxHeight: Double

    init(url: URL?, maxWidth: Double = 500, maxHeight: Double = 400) {
        self.url = url
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true  // Enable GIF animation

        if let url = url {
            // Load image asynchronously
            DispatchQueue.global(qos: .userInitiated).async {
                if let image = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        imageView.image = image
                    }
                }
            }
        }

        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if let url = url, nsView.image == nil {
            DispatchQueue.global(qos: .userInitiated).async {
                if let image = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        nsView.image = image
                    }
                }
            }
        }
    }
}

// MARK: - Media Carousel Component

/// Interactive media carousel with arrow key navigation
/// Supports images, GIFs, YouTube, Vimeo, and other video sources
struct IntroMediaCarousel: View {
    let items: [InspectConfig.MediaItemConfig]
    let height: Double
    let autoplay: Bool
    let showArrows: Bool
    let showDots: Bool
    let accentColor: Color

    @State private var currentIndex: Int = 0
    @FocusState private var isFocused: Bool

    init(
        items: [InspectConfig.MediaItemConfig],
        height: Double = 400,
        autoplay: Bool = true,
        showArrows: Bool = true,
        showDots: Bool = true,
        accentColor: Color = .blue
    ) {
        self.items = items
        self.height = height
        self.autoplay = autoplay
        self.showArrows = showArrows
        self.showDots = showDots
        self.accentColor = accentColor
    }

    var body: some View {
        VStack(spacing: 16) {
            // Title (if present)
            if let title = items[safe: currentIndex]?.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            // Main carousel container
            ZStack {
                // Media content
                if let item = items[safe: currentIndex], let urlString = item.url {
                    mediaContent(for: urlString)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .id("media-\(currentIndex)-\(urlString)")
                }

                // Navigation arrows overlay
                if showArrows && items.count > 1 {
                    navigationArrows
                }
            }
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )

            // Caption (if present)
            if let caption = items[safe: currentIndex]?.caption, !caption.isEmpty {
                Text(caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Dot indicators
            if showDots && items.count > 1 {
                dotIndicators
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.leftArrow) {
            previousItem()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            nextItem()
            return .handled
        }
        .onAppear {
            isFocused = true
        }
    }

    // MARK: - Media Content

    @ViewBuilder
    private func mediaContent(for urlString: String) -> some View {
        if let url = URL(string: urlString) {
            IntroMediaPlayer(
                url: url,
                autoplay: autoplay,
                height: height,
                cornerRadius: 12
            )
        } else if FileManager.default.fileExists(atPath: urlString) {
            // Local file path
            IntroMediaPlayer(
                url: URL(fileURLWithPath: urlString),
                autoplay: autoplay,
                height: height,
                cornerRadius: 12
            )
        } else {
            // Fallback placeholder
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Media not found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Navigation Arrows

    private var navigationArrows: some View {
        HStack {
            // Previous button
            Button(action: previousItem) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
            .buttonStyle(.plain)
            .disabled(currentIndex == 0)
            .opacity(currentIndex == 0 ? 0.3 : 1.0)
            .padding(.leading, 16)

            Spacer()

            // Next button
            Button(action: nextItem) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
            .buttonStyle(.plain)
            .disabled(currentIndex == items.count - 1)
            .opacity(currentIndex == items.count - 1 ? 0.3 : 1.0)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Dot Indicators

    private var dotIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<items.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? accentColor : accentColor.opacity(0.3))
                    .frame(width: index == currentIndex ? 10 : 8, height: index == currentIndex ? 10 : 8)
                    .scaleEffect(index == currentIndex ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                    .onTapGesture {
                        navigateToIndex(index)
                    }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Navigation

    private func previousItem() {
        guard currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex -= 1
        }
    }

    private func nextItem() {
        guard currentIndex < items.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex += 1
        }
    }

    private func navigateToIndex(_ index: Int) {
        guard index >= 0 && index < items.count else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex = index
        }
    }
}

// MARK: - Brand Picker Components

/// Grid of brand cards for multi-brand onboarding selection
struct BrandPickerGrid: View {
    let brands: [InspectConfig.BrandConfig]
    let columns: Int
    @Binding var selectedBrandId: String?
    let accentColor: Color

    init(
        brands: [InspectConfig.BrandConfig],
        columns: Int = 2,
        selectedBrandId: Binding<String?>,
        accentColor: Color = .blue
    ) {
        self.brands = brands
        self.columns = columns
        self._selectedBrandId = selectedBrandId
        self.accentColor = accentColor
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(brands) { brand in
                BrandCard(
                    brand: brand,
                    isSelected: selectedBrandId == brand.id,
                    accentColor: accentColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedBrandId = brand.id
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

/// Individual brand card showing logo, name, and accent stripe
struct BrandCard: View {
    let brand: InspectConfig.BrandConfig
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    private var brandColor: Color {
        if let hex = brand.highlightColor {
            return Color(hex: hex)
        }
        return accentColor
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Accent stripe at top
                Rectangle()
                    .fill(brandColor)
                    .frame(height: 6)

                VStack(spacing: 12) {
                    Spacer(minLength: 8)

                    // Logo or SF Symbol
                    brandImage
                        .frame(width: 64, height: 64)

                    // Display name
                    Text(brand.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Subtitle
                    if let subtitle = brand.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 12)
            }
            .frame(minHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? brandColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 3 : 1)
            )
            .overlay(
                isSelected ?
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(brandColor)
                        .font(.title2)
                        .padding(8)
                    : nil,
                alignment: .topTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var brandImage: some View {
        if let logoPath = brand.logoPath, let nsImage = NSImage(contentsOfFile: logoPath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let sfSymbol = brand.sfSymbol {
            Image(systemName: sfSymbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(brandColor)
        } else {
            Image(systemName: "building.2.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(brandColor)
        }
    }
}

// MARK: - Assistant Step Components (Apple Setup Assistant Style)

/// Card cell for Assistant step grid — Apple-style blue selection border, no checkmark badge
struct AssistantGridCell: View {
    let item: IntroGridItem
    let isSelected: Bool
    let basePath: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Image content
                imageContent
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Title
                if let title = item.title {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.5),
                        lineWidth: isSelected ? 3 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var imageContent: some View {
        if let imagePath = item.imagePath {
            AsyncImageView(
                iconPath: imagePath,
                basePath: basePath,
                maxWidth: 200,
                maxHeight: 120,
                fallback: { Color.gray.opacity(0.1) }
            )
        } else if let sfSymbol = item.sfSymbol {
            Image(systemName: sfSymbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color.accentColor)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.accentColor.opacity(0.05))
        } else {
            Color.gray.opacity(0.1)
        }
    }
}

/// Grid picker for Assistant steps — reuses selection logic, uses AssistantGridCell
struct AssistantGridPicker: View {
    let items: [IntroGridItem]
    let columns: Int
    let selectionMode: String
    @Binding var selectedIds: Set<String>
    let basePath: String?

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(items) { item in
                AssistantGridCell(
                    item: item,
                    isSelected: selectedIds.contains(item.id),
                    basePath: basePath,
                    onTap: { toggleSelection(item.id) }
                )
            }
        }
    }

    private func toggleSelection(_ id: String) {
        switch selectionMode {
        case "single":
            selectedIds = [id]
        case "multiple":
            if selectedIds.contains(id) {
                selectedIds.remove(id)
            } else {
                selectedIds.insert(id)
            }
        default:
            break
        }
    }
}

// Note: Wallpaper picker for Preset5 reuses WallpaperPickerView from PresetCommonHelpers.swift
