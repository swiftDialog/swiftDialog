//
//  MediaComponents.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Extracted from PresetCommonHelpers.swift
//
//  Async image loading, image carousels, and gallery presentation
//

import SwiftUI

// MARK: - AsyncImageView (Shared Component)

/// Asynchronous image loader with loading states and fallback support
/// Extracted for reuse across all presets
struct AsyncImageView<Fallback: View>: View {
    let iconPath: String
    let basePath: String?
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    let imageFit: ContentMode  // .fill (crop to fill) or .fit (show entire image)
    let fallback: () -> Fallback

    @State private var imageState: ImageLoadState = .loading
    @State private var loadedImage: NSImage?

    /// Detect GIF files by extension for animated rendering
    private var isGIF: Bool {
        iconPath.lowercased().hasSuffix(".gif")
    }

    /// Resolve the icon path to a file URL for GIF playback
    private var resolvedFileURL: URL? {
        if iconPath.hasPrefix("http://") || iconPath.hasPrefix("https://") {
            return URL(string: iconPath)
        }
        let fullPath: String
        if iconPath.hasPrefix("/") {
            fullPath = iconPath
        } else if let basePath = basePath {
            fullPath = (basePath as NSString).appendingPathComponent(iconPath)
        } else {
            fullPath = iconPath
        }
        return URL(fileURLWithPath: fullPath)
    }

    enum ImageLoadState: Equatable {
        case loading
        case loaded(NSImage)
        case failed

        static func == (lhs: ImageLoadState, rhs: ImageLoadState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.failed, .failed):
                return true
            case (.loaded(let lhsImage), .loaded(let rhsImage)):
                return lhsImage == rhsImage
            default:
                return false
            }
        }
    }

    init(iconPath: String, basePath: String?, maxWidth: CGFloat, maxHeight: CGFloat, imageFit: ContentMode = .fill, @ViewBuilder fallback: @escaping () -> Fallback) {
        self.iconPath = iconPath
        self.basePath = basePath
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.imageFit = imageFit
        self.fallback = fallback
    }

    var body: some View {
        Group {
            switch imageState {
            case .loading:
                // Loading state - gradient background with spinner
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Loading...")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: maxWidth, height: maxHeight)
                .clipped()

            case .loaded(let nsImage):
                // Use AnimatedGIFViewBlocked for GIFs (WKWebView-based), static Image for everything else
                if isGIF, let gifURL = resolvedFileURL {
                    AnimatedGIFViewBlocked(url: gifURL)
                        .frame(width: maxWidth, height: maxHeight)
                        .clipped()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: imageFit)
                        .frame(width: maxWidth, height: maxHeight)
                        .clipped()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

            case .failed:
                // Failed to load, show fallback
                fallback()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: imageState)
        .onAppear {
            loadImageAsync()
        }
        .onChange(of: iconPath) { _, _ in
            imageState = .loading
            loadImageAsync()
        }
    }

    private func loadImageAsync() {
        Task {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        // URL loading — fetch remote image over HTTP(S)
        if iconPath.hasPrefix("http://") || iconPath.hasPrefix("https://") {
            guard let url = URL(string: iconPath) else {
                withAnimation(.easeInOut(duration: 0.3)) { imageState = .failed }
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let nsImage = NSImage(data: data) {
                    withAnimation(.easeInOut(duration: 0.3)) { imageState = .loaded(nsImage) }
                } else {
                    writeLog("AsyncImageView: Invalid image data from URL: \(iconPath)", logLevel: .error)
                    withAnimation(.easeInOut(duration: 0.3)) { imageState = .failed }
                }
            } catch {
                writeLog("AsyncImageView: Failed to fetch URL: \(iconPath) — \(error.localizedDescription)", logLevel: .error)
                withAnimation(.easeInOut(duration: 0.3)) { imageState = .failed }
            }
            return
        }

        // Resolve local file path
        let fullPath: String
        if iconPath.hasPrefix("/") {
            fullPath = iconPath
        } else if let basePath = basePath {
            fullPath = (basePath as NSString).appendingPathComponent(iconPath)
        } else {
            fullPath = iconPath
        }

        try? await Task.sleep(for: .milliseconds(100))

        if let nsImage = NSImage(contentsOfFile: fullPath) {
            withAnimation(.easeInOut(duration: 0.3)) {
                imageState = .loaded(nsImage)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                imageState = .failed
            }
        }
    }
}

// MARK: - ImageCarouselView (Shared Component)

/// Interactive image carousel component with navigation controls
/// Supports arrow buttons, dot indicators, captions, and auto-advance
struct ImageCarouselView: View {
    // Required properties
    let images: [String]
    let iconBasePath: String?
    let scaleFactor: CGFloat

    // Layout properties
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let imageShape: String
    let imageFit: String  // "fill" (crop to fill) or "fit" (show entire image)

    // Navigation properties
    let showDots: Bool
    let showArrows: Bool
    let captions: [String]?

    // Behavior properties
    let autoAdvance: Bool
    let autoAdvanceDelay: Double
    let transitionStyle: String

    // State
    @State private var currentIndex: Int
    @State private var autoAdvanceTimer: Timer?
    @StateObject private var iconCache = PresetIconCache()

    init(
        images: [String],
        iconBasePath: String?,
        scaleFactor: CGFloat,
        imageWidth: CGFloat = 400,
        imageHeight: CGFloat = 300,
        imageShape: String = "rectangle",
        imageFit: String = "fill",
        showDots: Bool = true,
        showArrows: Bool = true,
        captions: [String]? = nil,
        autoAdvance: Bool = false,
        autoAdvanceDelay: Double = 3.0,
        transitionStyle: String = "slide",
        currentIndex: Int = 0
    ) {
        self.images = images
        self.iconBasePath = iconBasePath
        self.scaleFactor = scaleFactor
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageShape = imageShape
        self.imageFit = imageFit
        self.showDots = showDots
        self.showArrows = showArrows
        self.captions = captions
        self.autoAdvance = autoAdvance
        self.autoAdvanceDelay = autoAdvanceDelay
        self.transitionStyle = transitionStyle
        self._currentIndex = State(initialValue: min(max(0, currentIndex), images.count - 1))
    }

    var body: some View {
        VStack(spacing: 12 * scaleFactor) {
            // Main carousel container
            ZStack {
                // Background with rounded corners
                RoundedRectangle(cornerRadius: 12 * scaleFactor)
                    .fill(Color.gray.opacity(0.1))

                // Current image
                carouselImageView()

                // Navigation arrows (overlays)
                if showArrows && images.count > 1 {
                    HStack {
                        // Previous button
                        Button(action: previousImage) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 32 * scaleFactor))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                        .opacity(currentIndex == 0 ? 0.3 : 1.0)
                        .padding(.leading, 16 * scaleFactor)

                        Spacer()

                        // Next button
                        Button(action: nextImage) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 32 * scaleFactor))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == images.count - 1)
                        .opacity(currentIndex == images.count - 1 ? 0.3 : 1.0)
                        .padding(.trailing, 16 * scaleFactor)
                    }
                }
            }
            .frame(width: imageWidth * scaleFactor, height: imageHeight * scaleFactor)
            .clipShape(applyImageShape())

            // Dot indicators
            if showDots && images.count > 1 {
                dotIndicators()
            }

            // Caption
            if let captions = captions,
               let caption = captions[safe: currentIndex],
               !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16 * scaleFactor)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if autoAdvance && images.count > 1 {
                startAutoAdvance()
            }
        }
        .onDisappear {
            stopAutoAdvance()
        }
    }

    // MARK: - Image View

    @ViewBuilder
    private func carouselImageView() -> some View {
        if images.indices.contains(currentIndex) {
            let imagePath = images[currentIndex]

            AsyncImageView(
                iconPath: imagePath,
                basePath: iconBasePath,
                maxWidth: imageWidth * scaleFactor,
                maxHeight: imageHeight * scaleFactor,
                fallback: {
                    // Fallback view for failed image load
                    ZStack {
                        Color.gray.opacity(0.2)

                        VStack(spacing: 8 * scaleFactor) {
                            Image(systemName: "photo")
                                .font(.system(size: 40 * scaleFactor))
                                .foregroundStyle(.secondary)

                            Text("Image not found")
                                .font(.system(size: 12 * scaleFactor))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            )
            .transition(getTransition())
            .id("carousel-image-\(currentIndex)-\(imagePath)")
        }
    }

    // MARK: - Dot Indicators

    private func dotIndicators() -> some View {
        HStack(spacing: 8 * scaleFactor) {
            ForEach(0..<images.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(
                        width: (index == currentIndex ? 8 : 6) * scaleFactor,
                        height: (index == currentIndex ? 8 : 6) * scaleFactor
                    )
                    .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                    .onTapGesture {
                        navigateToIndex(index)
                    }
            }
        }
        .padding(.vertical, 8 * scaleFactor)
    }

    // MARK: - Navigation

    private func previousImage() {
        guard currentIndex > 0 else { return }
        withAnimation(getAnimationType()) {
            currentIndex -= 1
        }
        resetAutoAdvanceTimer()
    }

    private func nextImage() {
        guard currentIndex < images.count - 1 else { return }
        withAnimation(getAnimationType()) {
            currentIndex += 1
        }
        resetAutoAdvanceTimer()
    }

    private func navigateToIndex(_ index: Int) {
        guard index != currentIndex && images.indices.contains(index) else { return }
        withAnimation(getAnimationType()) {
            currentIndex = index
        }
        resetAutoAdvanceTimer()
    }

    // MARK: - Auto-Advance

    private func startAutoAdvance() {
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: autoAdvanceDelay, repeats: true) { _ in
            if currentIndex < images.count - 1 {
                withAnimation(getAnimationType()) {
                    currentIndex += 1
                }
            } else {
                // Loop back to start
                withAnimation(getAnimationType()) {
                    currentIndex = 0
                }
            }
        }
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }

    private func resetAutoAdvanceTimer() {
        if autoAdvance {
            stopAutoAdvance()
            startAutoAdvance()
        }
    }

    // MARK: - Helpers

    private func getTransition() -> AnyTransition {
        switch transitionStyle.lowercased() {
        case "fade":
            return .opacity
        case "slide":
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        default:
            return .opacity
        }
    }

    private func getAnimationType() -> Animation {
        switch transitionStyle.lowercased() {
        case "slide":
            return .spring(response: 0.4, dampingFraction: 0.8)
        case "fade":
            return .easeInOut(duration: 0.3)
        default:
            return .easeInOut(duration: 0.3)
        }
    }

    private func applyImageShape() -> some Shape {
        switch imageShape.lowercased() {
        case "circle":
            return AnyShape(Circle())
        case "square":
            return AnyShape(RoundedRectangle(cornerRadius: 8 * scaleFactor))
        default: // "rectangle"
            return AnyShape(RoundedRectangle(cornerRadius: 12 * scaleFactor))
        }
    }
}

/*
// Helper for type-erased shapes
private struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) where S: Sendable {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}
 */

/// Extension to provide safe array subscripting that returns nil instead of crashing on out-of-bounds access
extension Array {
    /// Safe subscript that returns nil instead of crashing on out-of-bounds access
    /// Usage: if let item = array[safe: index] { ... }
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


// MARK: - Gallery Presentation Components

/// Individual image slide in gallery carousel
/// Cache for preloading gallery images
class GalleryImageCache: ObservableObject {
    @Published var images: [String: NSImage] = [:]
    @Published var loadingComplete: Bool = false

    func preloadImages(paths: [String]) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var loadedImages: [String: NSImage] = [:]
            for path in paths {
                if let image = NSImage(contentsOfFile: path) {
                    loadedImages[path] = image
                }
            }
            DispatchQueue.main.async {
                self?.images = loadedImages
                self?.loadingComplete = true
            }
        }
    }

    func image(for path: String) -> NSImage? {
        images[path]
    }
}

/// Individual image slide in gallery carousel - uses cached images
struct GalleryImageSlide: View {
    let imagePath: String
    let caption: String?
    let imageHeight: Double
    let allowZoom: Bool
    let onImageTap: () -> Void
    let cachedImage: NSImage?
    var maxWidth: CGFloat?  // Optional max width constraint

    var body: some View {
        VStack(spacing: 12) {
            // Main image area
            ZStack {
                if let image = cachedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: maxWidth, maxHeight: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .onTapGesture {
                            if allowZoom {
                                onImageTap()
                            }
                        }
                        .help(allowZoom ? "Click to view fullscreen" : "")
                } else {
                    // Loading or error state
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Image not available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: maxWidth ?? .infinity, maxHeight: imageHeight)
                }
            }

            // Caption (if provided)
            if let caption = caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }
}

/// Thumbnail view for gallery navigation - uses cached images
struct GalleryThumbnail: View {
    let imagePath: String
    let thumbnailSize: Double
    let isSelected: Bool
    let action: () -> Void
    let cachedImage: NSImage?

    var body: some View {
        Button(action: action) {
            ZStack {
                if let thumbnail = cachedImage {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

/// Gallery presentation view (carousel mode) with preloaded image cache
struct GalleryCarouselView: View {
    let config: InspectConfig.DetailOverlayConfig
    let onClose: () -> Void

    @State private var currentIndex: Int = 0
    @State private var showFullscreen: Bool = false
    @StateObject private var imageCache = GalleryImageCache()

    private var images: [String] {
        config.galleryImages ?? []
    }

    private var imageHeight: Double {
        config.imageHeight ?? 400
    }

    private var thumbnailSize: Double {
        config.thumbnailSize ?? 60
    }

    private var showStepCounter: Bool {
        config.showStepCounter ?? true
    }

    private var showNavigationArrows: Bool {
        config.showNavigationArrows ?? true
    }

    private var showThumbnails: Bool {
        config.showThumbnails ?? true
    }

    private var allowZoom: Bool {
        config.allowImageZoom ?? false
    }

    private var isSideBySide: Bool {
        config.galleryLayout == "sideBySide" && getSizeWidth() >= 800
    }

    private var hasSideContent: Bool {
        config.gallerySideContent != nil && !(config.gallerySideContent?.isEmpty ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.title ?? "Instructions")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let subtitle = config.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Step counter
                if showStepCounter && images.count > 1 {
                    Text("Step \(currentIndex + 1) of \(images.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                }

                Button(config.closeButtonText ?? "Close") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main content area
            if !imageCache.loadingComplete {
                // Loading state
                VStack {
                    Spacer()
                    ProgressView("Loading images...")
                        .scaleEffect(1.2)
                    Spacer()
                }
            } else if isSideBySide && hasSideContent {
                // Side-by-side layout: image on left, content on right
                sideBySideContent
            } else {
                // Standard carousel layout
                standardCarouselContent
            }
        }
        .frame(width: getSizeWidth(), height: getSizeHeight())
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // Preload all images when view appears
            imageCache.preloadImages(paths: images)
        }
    }

    // MARK: - Standard Carousel Layout

    private var standardCarouselContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Carousel with navigation
                HStack(spacing: 16) {
                    // Previous button
                    if showNavigationArrows && images.count > 1 {
                        Button(action: previousImage) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(currentIndex > 0 ? Color.accentColor : Color.gray.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                        .help("Previous")
                    }

                    // Current image - use cached image with smooth transition
                    if currentIndex < images.count {
                        GalleryImageSlide(
                            imagePath: images[currentIndex],
                            caption: config.galleryCaptions?[safe: currentIndex],
                            imageHeight: imageHeight,
                            allowZoom: allowZoom,
                            onImageTap: {
                                if allowZoom {
                                    showFullscreen = true
                                }
                            },
                            cachedImage: imageCache.image(for: images[currentIndex])
                        )
                        .id(currentIndex) // Force view identity for smooth transitions
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }

                    // Next button
                    if showNavigationArrows && images.count > 1 {
                        Button(action: nextImage) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(currentIndex < images.count - 1 ? Color.accentColor : Color.gray.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex >= images.count - 1)
                        .help("Next")
                    }
                }
                .padding(.horizontal, showNavigationArrows ? 16 : 32)
                .padding(.vertical, 20)
                .animation(.easeInOut(duration: 0.25), value: currentIndex)

                // Thumbnail strip
                if showThumbnails && images.count > 1 {
                    Divider()
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(images.indices, id: \.self) { index in
                                GalleryThumbnail(
                                    imagePath: images[index],
                                    thumbnailSize: thumbnailSize,
                                    isSelected: currentIndex == index,
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            currentIndex = index
                                        }
                                    },
                                    cachedImage: imageCache.image(for: images[index])
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
    }

    // MARK: - Side-by-Side Layout

    private var sideBySideContent: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left side: Image carousel (60% width)
            VStack(spacing: 16) {
                // Navigation arrows + image
                HStack(spacing: 12) {
                    // Previous button
                    if showNavigationArrows && images.count > 1 {
                        Button(action: previousImage) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(currentIndex > 0 ? Color.accentColor : Color.gray.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                        .help("Previous")
                    }

                    // Current image
                    if currentIndex < images.count {
                        GalleryImageSlide(
                            imagePath: images[currentIndex],
                            caption: config.galleryCaptions?[safe: currentIndex],
                            imageHeight: imageHeight * 0.85,
                            allowZoom: allowZoom,
                            onImageTap: {
                                if allowZoom {
                                    showFullscreen = true
                                }
                            },
                            cachedImage: imageCache.image(for: images[currentIndex]),
                            maxWidth: getSizeWidth() * 0.55
                        )
                        .id(currentIndex)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }

                    // Next button
                    if showNavigationArrows && images.count > 1 {
                        Button(action: nextImage) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(currentIndex < images.count - 1 ? Color.accentColor : Color.gray.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex >= images.count - 1)
                        .help("Next")
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: currentIndex)

                // Step counter below image
                if showStepCounter && images.count > 1 {
                    Text("Step \(currentIndex + 1) of \(images.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                }

                // Thumbnail strip
                if showThumbnails && images.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(images.indices, id: \.self) { index in
                                GalleryThumbnail(
                                    imagePath: images[index],
                                    thumbnailSize: thumbnailSize * 0.8,
                                    isSelected: currentIndex == index,
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            currentIndex = index
                                        }
                                    },
                                    cachedImage: imageCache.image(for: images[index])
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }

                Spacer()
            }
            .padding()
            .frame(width: getSizeWidth() * 0.6)

            // Divider
            Divider()

            // Right side: Content blocks (40% width)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let sideContent = config.gallerySideContent {
                        ForEach(Array(sideContent.enumerated()), id: \.offset) { _, block in
                            GallerySideContentBlock(block: block, scaleFactor: 1.0)
                        }
                    }
                }
                .padding()
            }
            .frame(width: getSizeWidth() * 0.4)
        }
    }

    private func previousImage() {
        if currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentIndex -= 1
            }
        }
    }

    private func nextImage() {
        if currentIndex < images.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentIndex += 1
            }
        }
    }

    private func getSizeWidth() -> CGFloat {
        switch config.size {
        case "small": return 600
        case "large": return 1000
        case "full": return 1200
        default: return 800  // medium
        }
    }

    private func getSizeHeight() -> CGFloat {
        switch config.size {
        case "small": return 500
        case "large": return 700
        case "full": return 900
        default: return 600  // medium
        }
    }
}

// MARK: - Gallery Side Content Block

/// Renders a single content block for the side panel in sideBySide gallery layout
struct GallerySideContentBlock: View {
    let block: InspectConfig.GuidanceContent
    let scaleFactor: CGFloat

    var body: some View {
        switch block.type {
        case "text":
            Text(block.content ?? "")
                .font(.system(size: 13 * scaleFactor, weight: block.bold == true ? .semibold : .regular))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

        case "highlight":
            Text(block.content ?? "")
                .font(.system(size: 14 * scaleFactor, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12 * scaleFactor)
                .padding(.vertical, 6 * scaleFactor)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: block.color ?? "#007AFF").opacity(0.15))
                )

        case "bullets":
            if let items = block.items {
                VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                    ForEach(items, id: \.self) { item in
                        if !item.isEmpty {
                            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                                Text("•")
                                    .font(.system(size: 13 * scaleFactor))
                                    .foregroundStyle(.secondary)
                                Text(item)
                                    .font(.system(size: 13 * scaleFactor))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

        case "info":
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.blue)
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )

        case "warning":
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.orange)
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )

        case "success":
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.green)
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.1))
            )

        case "arrow":
            HStack(spacing: 6 * scaleFactor) {
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(.primary)
            }

        default:
            // Fallback for unsupported types
            if let content = block.content {
                Text(content)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// NOTE: DetailOverlayView is defined in dialog/Views/Inspect/Utilities/DetailOverlayView.swift
// with proper system info styling including device icon
