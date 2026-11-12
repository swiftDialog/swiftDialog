//
//  MediaComponents.swift
//  dialog
//
//  Async image loading, the image carousel, and the gallery sheet.
//

import SwiftUI

// MARK: - Shared Image Cache

/// Thread-safe NSCache for decoded images, keyed by "path@WxH" so each display size gets its own
/// downsampled entry.
private final class AsyncImageCache: @unchecked Sendable {
    static let shared = AsyncImageCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 30
        cache.totalCostLimit = 200_000_000  // ~200 MB
    }

    func image(forKey key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: NSImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

// MARK: - AsyncImageView

/// Asynchronous image loader (file path or URL) with a skeleton, downsampled decode and fallback.
struct AsyncImageView<Fallback: View>: View {
    let iconPath: String
    let basePath: String?
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    let imageFit: ContentMode
    let showLoadingState: Bool
    let fallback: () -> Fallback

    @State private var imageState: ImageLoadState = .loading
    @State private var loadedImage: NSImage?

    private var isGIF: Bool {
        iconPath.lowercased().hasSuffix(".gif")
    }

    /// The icon path as a URL, for GIF playback.
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

    init(iconPath: String, basePath: String?, maxWidth: CGFloat, maxHeight: CGFloat, imageFit: ContentMode = .fill, showLoadingState: Bool = true, @ViewBuilder fallback: @escaping () -> Fallback) {
        self.iconPath = iconPath
        self.basePath = basePath
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.imageFit = imageFit
        self.showLoadingState = showLoadingState
        self.fallback = fallback
    }

    var body: some View {
        Group {
            switch imageState {
            case .loading:
                if MediaLoading.drawsSkeleton(showLoadingState: showLoadingState) {
                    MediaSkeletonView()
                        .frame(width: maxWidth, height: maxHeight)
                        .clipped()
                } else {
                    // The loading marker is emitted even when the skeleton is declined.
                    Color.clear
                        .frame(width: maxWidth, height: maxHeight)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(MediaLoading.marker)
                }

            case .loaded(let nsImage):
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

    private var cacheKey: String {
        "\(iconPath)@\(Int(maxWidth))x\(Int(maxHeight))"
    }

    @MainActor
    private func loadImage() async {
        if let cached = AsyncImageCache.shared.image(forKey: cacheKey) {
            withAnimation(.easeInOut(duration: 0.3)) { imageState = .loaded(cached) }
            return
        }

        if iconPath.hasPrefix("http://") || iconPath.hasPrefix("https://") {
            guard let url = URL(string: iconPath) else {
                withAnimation(.easeInOut(duration: 0.3)) { imageState = .failed }
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let nsImage = NSImage(data: data) {
                    AsyncImageCache.shared.setImage(nsImage, forKey: cacheKey)
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

        let fullPath: String
        if iconPath.hasPrefix("/") {
            fullPath = iconPath
        } else if let basePath = basePath {
            fullPath = (basePath as NSString).appendingPathComponent(iconPath)
        } else {
            fullPath = iconPath
        }

        // Decode at display size off the main actor, not at full resolution.
        let targetW = maxWidth
        let targetH = maxHeight
        let key = cacheKey

        let result: NSImage? = await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: fullPath)
            let sourceOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOpts as CFDictionary) else {
                return nil as NSImage?
            }

            // Twice the display size, for Retina.
            let maxPixelSize = max(targetW, targetH) * 2.0
            let downsampleOpts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOpts as CFDictionary) else {
                return nil as NSImage?
            }

            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }.value

        if let image = result {
            AsyncImageCache.shared.setImage(image, forKey: key)
            withAnimation(.easeInOut(duration: 0.3)) {
                imageState = .loaded(image)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                imageState = .failed
            }
        }
    }
}

// MARK: - ImageCarouselView

/// Image carousel with arrows, dots, captions and auto-advance.
struct ImageCarouselView: View {
    @Environment(\.palette) private var palette
    let images: [String]
    let iconBasePath: String?
    let scaleFactor: CGFloat

    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let imageShape: String
    let imageFit: String  // "fill" | "fit"

    let showDots: Bool
    let showArrows: Bool
    let captions: [String]?

    let autoAdvance: Bool
    let autoAdvanceDelay: Double
    let transitionStyle: String

    @State private var currentIndex: Int
    @State private var autoAdvanceClock: Poll?
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

    // MARK: - Geometry

    /// One arrow's footprint in authored points: the 32pt glyph plus its 16pt edge inset.
    static let arrowFootprint: CGFloat = 32 + 16

    /// Whether a frame this wide can carry the arrows: the picture keeps a clear middle at least
    /// as wide as the chrome flanking it. Authored width, so the answer is scale-free.
    static func arrowsFit(inWidth width: CGFloat) -> Bool {
        width >= arrowFootprint * 4
    }

    /// `showArrows` is the author's intent; geometry wins when the frame cannot honour it.
    var arrowsVisible: Bool {
        showArrows && images.count > 1 && Self.arrowsFit(inWidth: imageWidth)
    }

    /// Dots are the fallback navigation whenever geometry suppresses the arrows.
    var dotsVisible: Bool {
        images.count > 1 && (showDots || !arrowsVisible)
    }

    /// Only the word `fit` shows the whole picture; anything else crops.
    private var imageContentMode: ContentMode {
        imageFit.lowercased() == "fit" ? .fit : .fill
    }

    var body: some View {
        VStack(spacing: 12 * scaleFactor) {
            ZStack {
                RoundedRectangle(cornerRadius: 12 * scaleFactor)
                    .fill(palette.text.opacity(0.1))

                carouselImageView()

                if arrowsVisible {
                    HStack {
                        Button(action: previousImage) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 32 * scaleFactor))
                                .foregroundStyle(.white)
                                // The shadow is the disc's only contrast against a light photo.
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                        .opacity(currentIndex == 0 ? 0.3 : 1.0)
                        .padding(.leading, 16 * scaleFactor)

                        Spacer()

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

            if dotsVisible {
                dotIndicators()
            }

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

            // `sf=name` draws a symbol; AsyncImageView knows only URLs and file paths.
            if let symbolName = IconRef.symbol(imagePath) {
                Image(systemName: symbolName)
                    .font(.system(size: imageHeight * scaleFactor * 0.4))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(getTransition())
                    .id("carousel-image-\(currentIndex)-\(imagePath)")
            } else {
            AsyncImageView(
                iconPath: imagePath,
                basePath: iconBasePath,
                maxWidth: imageWidth * scaleFactor,
                maxHeight: imageHeight * scaleFactor,
                imageFit: imageContentMode,
                fallback: {
                    ZStack {
                        palette.text.opacity(0.2)

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
        // `Poll` runs its body on the main actor, so the `@State` write needs no hop.
        let clock = Poll(every: autoAdvanceDelay)
        autoAdvanceClock = clock
        clock.start {
            if currentIndex < images.count - 1 {
                withAnimation(getAnimationType()) {
                    currentIndex += 1
                }
            } else {
                withAnimation(getAnimationType()) {
                    currentIndex = 0
                }
            }
        }
    }

    private func stopAutoAdvance() {
        autoAdvanceClock?.cancel()
        autoAdvanceClock = nil
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

extension Array {
    /// nil instead of a crash on an out-of-bounds index.
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


// MARK: - Gallery Presentation Components

/// Preloaded gallery images.
@MainActor
class GalleryImageCache: ObservableObject {
    @Published var images: [String: NSImage] = [:]
    @Published var loadingComplete: Bool = false

    func preloadImages(paths: [String]) {
        // Reads run off the main actor; the published state is written back on it.
        Task { [weak self] in
            let loaded = await Task.detached(priority: .userInitiated) {
                var images: [String: NSImage] = [:]
                for path in paths {
                    if let image = InspectImageCache.shared.image(atPath: path) { images[path] = image }
                }
                return images
            }.value
            self?.images = loaded
            self?.loadingComplete = true
        }
    }

    func image(for path: String) -> NSImage? {
        images[path]
    }
}

/// One gallery slide, from the cache.
struct GalleryImageSlide: View {
    let imagePath: String
    let caption: String?
    let imageHeight: Double
    let allowZoom: Bool
    let onImageTap: () -> Void
    let cachedImage: NSImage?
    var maxWidth: CGFloat?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if let image = cachedImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
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

/// Gallery navigation thumbnail, from the cache.
struct GalleryThumbnail: View {
    @Environment(\.palette) private var palette
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
                        .scaledToFill()
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Rectangle()
                        .fill(palette.text.opacity(0.2))
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

/// The gallery sheet: carousel or side-by-side layout, with a preloaded image cache.
struct GalleryCarouselView: View {
    @Environment(\.palette) private var palette
    /// Drawn inside a `.sheet` with no preset state, so the counters localise through the environment.
    @Environment(\.inspectLocalization) private var l10n
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

                if showStepCounter && images.count > 1 {
                    Text(StepCounterLabel.text(current: currentIndex + 1,
                                              total: images.count,
                                              localizer: l10n))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(palette.text.opacity(0.1))
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

            if !imageCache.loadingComplete {
                VStack {
                    Spacer()
                    ProgressView("Loading images...")
                        .scaleEffect(1.2)
                    Spacer()
                }
            } else if isSideBySide && hasSideContent {
                sideBySideContent
            } else {
                standardCarouselContent
            }
        }
        .frame(width: getSizeWidth(), height: getSizeHeight())
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            imageCache.preloadImages(paths: images)
        }
    }

    // MARK: - Standard Carousel Layout

    private var standardCarouselContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    if showNavigationArrows && images.count > 1 {
                        Button(action: previousImage) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(currentIndex > 0 ? Color.accentColor : palette.text.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                        .help("Previous")
                    }

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
                        .id(currentIndex)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }

                    if showNavigationArrows && images.count > 1 {
                        Button(action: nextImage) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(currentIndex < images.count - 1 ? Color.accentColor : palette.text.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex >= images.count - 1)
                        .help("Next")
                    }
                }
                .padding(.horizontal, showNavigationArrows ? 16 : 32)
                .padding(.vertical, 20)
                .animation(.easeInOut(duration: 0.25), value: currentIndex)

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
            // Image carousel, 60% of the width.
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    if showNavigationArrows && images.count > 1 {
                        Button(action: previousImage) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(currentIndex > 0 ? Color.accentColor : palette.text.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                        .help("Previous")
                    }

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

                    if showNavigationArrows && images.count > 1 {
                        Button(action: nextImage) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(currentIndex < images.count - 1 ? Color.accentColor : palette.text.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex >= images.count - 1)
                        .help("Next")
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: currentIndex)

                if showStepCounter && images.count > 1 {
                    Text(StepCounterLabel.text(current: currentIndex + 1,
                                              total: images.count,
                                              localizer: l10n))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(palette.text.opacity(0.1))
                        )
                }

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

            Divider()

            // Content blocks, 40% of the width.
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

/// One content block in the side-by-side gallery's side panel.
struct GallerySideContentBlock: View {
    let block: InspectConfig.GuidanceContent
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

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
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if !item.isEmpty {
                            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                                Text(block.numbered == true ? "\(index + 1)." : "•")
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
                    .foregroundStyle(palette.info)
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.info.opacity(0.1))
            )

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
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.warning.opacity(0.1))
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
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.success.opacity(0.1))
            )

        case "arrow":
            HStack(spacing: 6 * scaleFactor) {
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(.primary)
            }

        default:
            if let content = block.content {
                Text(content)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Media readiness

/// How a still-loading image says so. The visual skeleton can be declined with
/// `showLoadingState: false`; the accessibility marker is emitted either way.
enum MediaLoading {
    /// The accessibility label a loading image carries; capture tooling waits on this string.
    static let marker = "Loading media"

    /// Whether to draw the visible skeleton. The marker does not depend on this.
    static func drawsSkeleton(showLoadingState: Bool) -> Bool { showLoadingState }
}

/// A still image's placeholder: the shape of the picture, not a spinner, and not animated.
struct MediaSkeletonView: View {
    var scaleFactor: CGFloat = 1.0
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Rectangle().fill(palette.text.opacity(0.06))
            Image(systemName: "photo")
                .font(.system(size: 22 * scaleFactor, weight: .regular))
                .foregroundStyle(palette.text.opacity(0.22))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MediaLoading.marker)
    }
}
