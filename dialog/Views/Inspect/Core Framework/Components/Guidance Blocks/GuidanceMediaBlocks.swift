//
//  GuidanceMediaBlocks.swift
//  dialog
//
//  Media guidance blocks: image, video (with the aspect-fit player), webcontent, portal-webview.
//

import SwiftUI
import AVKit

// MARK: - Shared caption

/// The caption line under image / web / portal media, left-aligned on the media's edge.
struct GuidanceMediaCaption: View {
    let caption: String
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        Text(caption)
            .font(.system(size: 12 * scaleFactor))
            .foregroundStyle(palette.textMuted)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4 * scaleFactor)
    }
}

// MARK: - Image (type: "image")

struct GuidanceImageBlock: View {
    let block: InspectConfig.GuidanceContent
    let iconBasePath: String?
    let accentColor: Color?
    let scaleFactor: CGFloat
    /// Where the picture sits across the block's width. A caption stretches the block to the full
    /// column, so a captioned image centres unless the host asks for `.leading`.
    var contentAlignment: HorizontalAlignment = .center
    /// `.inline` by default, so a media block outside an arrangement renders at natural size.
    @Environment(\.mediaBandRole) private var mediaBandRole

    @Environment(\.palette) private var palette

    var body: some View {
        if let contentPath = block.content, !contentPath.isEmpty {
            VStack(alignment: contentAlignment, spacing: 4 * scaleFactor) {
                if let symbolName = IconRef.symbol(contentPath) {
                    Image(systemName: symbolName)
                        .font(.system(size: (CGFloat(block.imageHeight ?? 200) * scaleFactor) * 0.5))
                        .foregroundStyle(accentColor ?? .secondary)
                        .frame(height: CGFloat(block.imageHeight ?? 200) * scaleFactor)

                    if let caption = block.caption {
                        GuidanceMediaCaption(caption: caption, scaleFactor: scaleFactor)
                    }
                } else if contentPath.lowercased() == "computer" {
                    // This Mac's hardware icon, as `--icon computer`.
                    Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
                        .resizable()
                        .scaledToFit()
                        .modifier(MediaNaturalSize(
                            height: block.imageHeight.map { CGFloat($0) * scaleFactor },
                            maxWidth: CGFloat(block.imageWidth ?? 128) * scaleFactor))
                        .padding(.vertical, 4 * scaleFactor)

                    if let caption = block.caption {
                        GuidanceMediaCaption(caption: caption, scaleFactor: scaleFactor)
                    }
                } else if contentPath.lowercased().hasSuffix(".gif") {
                    // AsyncImageView plays animated GIFs.
                    let imageWidth = CGFloat(block.imageWidth ?? 400) * scaleFactor
                    AsyncImageView(
                        iconPath: contentPath,
                        basePath: nil,
                        maxWidth: imageWidth,
                        maxHeight: block.imageHeight.map { CGFloat($0) * scaleFactor } ?? imageWidth * 0.75,
                        imageFit: .fit,
                        fallback: { EmptyView() }
                    )
                    .padding(.vertical, 4 * scaleFactor)
                } else if let image = loadInstructionalImage(path: contentPath) {
                    let imageWidth = CGFloat(block.imageWidth ?? 400) * scaleFactor
                    let shape = block.imageShape ?? "rectangle"
                    let showBorder = block.imageBorder ?? (block.imageHeight == nil)

                    // An authored `imageHeight` marks a logo: sized by height, no border.
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        // Inside a band the picture fills what it was given, not its natural size.
                        .modifier(MediaNaturalSize(
                            height: mediaBandRole == .inline
                                ? block.imageHeight.map { CGFloat($0) * scaleFactor } : nil,
                            maxWidth: mediaBandRole == .inline ? imageWidth : .infinity))
                        .frame(maxWidth: mediaBandRole == .inline ? nil : .infinity,
                               maxHeight: mediaBandRole == .inline ? nil : .infinity)
                        .clipShape(getImageClipShape(for: shape))
                        .overlay(
                            showBorder ? getImageClipShape(for: shape)
                                .stroke(palette.textMuted.opacity(0.2), lineWidth: 1) : nil
                        )
                        .padding(.vertical, 4 * scaleFactor)

                    // In `fill` the action bar draws the caption.
                    if let caption = block.caption, mediaBandRole != .fill {
                        GuidanceMediaCaption(caption: caption, scaleFactor: scaleFactor)
                    }
                } else {
                    // Logged regardless of debugMode; only the visible hint is gated.
                    let _ = Self.adviseImageFailure(path: contentPath)
                    if appvars.debugMode {
                        HStack(spacing: 8 * scaleFactor) {
                            Image(systemName: "photo")
                                .font(.system(size: 13 * scaleFactor))
                                .foregroundStyle(palette.textMuted)
                            Text("Image not drawn: \(contentPath) — \(ImageBlockAdvice.reason(for: contentPath))")
                                .font(.system(size: 11 * scaleFactor))
                                .foregroundStyle(palette.textMuted)
                                .italic()
                        }
                        .padding(10 * scaleFactor)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(palette.textMuted.opacity(0.1))
                        )
                    }
                }
            }
        }
    }

    /// Paths already advised about, so a revisited step does not repeat the advice.
    private static var advisedImagePaths = Set<String>()

    /// Logs why nothing was drawn, once per path, at `.error` so it survives without `--verbose`.
    private static func adviseImageFailure(path: String) {
        guard !advisedImagePaths.contains(path) else { return }
        advisedImagePaths.insert(path)
        let advice = "image block: nothing drawn for '\(path)' — \(ImageBlockAdvice.reason(for: path))"
        writeLog(advice, logLevel: .error)
    }

    /// Resolves the path through `ImageResolver`, then falls back to the absolute path.
    private func loadInstructionalImage(path: String) -> NSImage? {
        writeLog("GuidanceImageBlock: Loading image from path='\(path)' with iconBasePath='\(iconBasePath ?? "nil")'", logLevel: .info)

        let resolver = ImageResolver.shared

        if let resolvedPath = resolver.resolveImagePath(path, basePath: iconBasePath, fallbackIcon: nil) {
            writeLog("GuidanceImageBlock: ImageResolver returned resolvedPath='\(resolvedPath)'", logLevel: .info)

            // A resolved value without a leading slash is an SF Symbol or URL, not loadable here.
            if resolvedPath.hasPrefix("/") && FileManager.default.fileExists(atPath: resolvedPath) {
                writeLog("GuidanceImageBlock: Loading image from resolved file path: \(resolvedPath)", logLevel: .info)
                return InspectImageCache.shared.image(atPath: resolvedPath)
            } else if !resolvedPath.hasPrefix("/") {
                writeLog("GuidanceImageBlock: Resolved path is not a file path (SF Symbol or URL?): \(resolvedPath)", logLevel: .info)
            } else {
                writeLog("GuidanceImageBlock: Resolved file path does not exist: \(resolvedPath)", logLevel: .info)
            }
        } else {
            writeLog("GuidanceImageBlock: ImageResolver returned nil for path: \(path)", logLevel: .info)
        }

        if path.hasPrefix("/") {
            if FileManager.default.fileExists(atPath: path) {
                writeLog("GuidanceImageBlock: Loading image from original absolute path: \(path)", logLevel: .info)
                return InspectImageCache.shared.image(atPath: path)
            } else {
                writeLog("GuidanceImageBlock: Original absolute path does not exist: \(path)", logLevel: .info)
            }
        }

        writeLog("GuidanceImageBlock: Failed to load image from path: \(path)", logLevel: .info)
        return nil
    }

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
}

// MARK: - Video (type: "video")

/// Video player sized to the video's natural aspect ratio; `videoHeight` caps the height.
struct GuidanceVideoBlock: View {
    let block: InspectConfig.GuidanceContent
    let scaleFactor: CGFloat

    var body: some View {
        if let videoPath = block.content, !videoPath.isEmpty {
            VStack(spacing: 4 * scaleFactor) {
                let autoPlay = block.autoplay ?? false
                let maxHeight = CGFloat(block.videoHeight ?? 400) * scaleFactor

                AspectFitVideoView(
                    videoPath: videoPath,
                    autoPlay: autoPlay,
                    caption: block.caption ?? "",
                    maxHeight: maxHeight,
                    loop: block.videoLoop ?? false
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.vertical, 4 * scaleFactor)
            }
        }
    }
}

// MARK: - Web content (type: "webcontent")

/// Embedded web content through `EmbeddedWebFrame`, which shows the host, a browser escape and a
/// loading skeleton.
struct GuidanceWebContentBlock: View {
    let block: InspectConfig.GuidanceContent
    var accentColor: Color?
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette
    @Environment(\.inspectBodyBand) private var band

    /// The authored `webHeight` (400 if none), capped to what the body band can show under the
    /// 34pt address strip and this block's padding. Unauthored, it fills the band.
    private var webHeight: CGFloat {
        guard band.height > 0 else { return CGFloat(block.webHeight ?? 400) * scaleFactor }
        let fit = band.height - (34 + 8) * scaleFactor
        return max(0, min(block.webHeight.map { CGFloat($0) * scaleFactor } ?? fit, fit))
    }

    var body: some View {
        if let webURL = block.content, !webURL.isEmpty, let url = URL(string: webURL) {
            VStack(spacing: 4 * scaleFactor) {
                EmbeddedWebFrame(
                    url: url,
                    height: webHeight,
                    accent: accentColor ?? palette.accent,
                    scaleFactor: scaleFactor
                )
                .id("webcontent-\(url.absoluteString)")
                .padding(.vertical, 4 * scaleFactor)

                if let caption = block.caption {
                    GuidanceMediaCaption(caption: caption, scaleFactor: scaleFactor)
                }
            }
        }
    }
}

// MARK: - Portal webview (type: "portal-webview")

/// Embedded self-service portal. URL: the block's `portalURL`, else the global portal config,
/// else `content`.
struct GuidancePortalWebViewBlock: View {
    let block: InspectConfig.GuidanceContent
    let portalConfig: InspectConfig.PortalConfig?
    var accentColor: Color?
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        let baseURL = block.portalURL ?? portalConfig?.portalURL ?? block.content ?? ""
        let pathString = block.portalPath ?? portalConfig?.selfServicePath ?? ""
        let fullURLString = pathString.isEmpty ? baseURL : baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + pathString

        if !fullURLString.isEmpty, let url = URL(string: fullURLString) {
            let portalHeight = CGFloat(block.portalHeight ?? 400) * scaleFactor

            VStack(spacing: 4 * scaleFactor) {
                EmbeddedWebFrame(
                    url: url,
                    openExternalLinksInBrowser: portalConfig?.openExternalLinksInBrowser ?? true,
                    height: portalHeight,
                    accent: accentColor ?? palette.accent,
                    scaleFactor: scaleFactor
                )
                .id("portal-\(url.absoluteString)")
                .padding(.vertical, 4 * scaleFactor)

                if let caption = block.caption {
                    GuidanceMediaCaption(caption: caption, scaleFactor: scaleFactor)
                }
            }
        }
    }
}

// MARK: - Aspect-Fit Video Player

/// AVPlayerView with a clear background, so no black letterbox bars appear.
private struct InspectPlayerView: NSViewRepresentable {
    let player: AVPlayer
    var controlsStyle: AVPlayerViewControlsStyle = .inline

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = controlsStyle
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
        nsView.controlsStyle = controlsStyle
    }
}

/// Self-sizing video player: the frame follows the video's natural aspect ratio, `maxHeight`
/// caps the height.
struct AspectFitVideoView: View {
    let videoPath: String
    let autoPlay: Bool
    let caption: String
    let maxHeight: CGFloat
    var loop: Bool = false

    // AVQueuePlayer serves both one-shot playback and AVPlayerLooper looping.
    @State private var player = AVQueuePlayer()
    @State private var looper: AVPlayerLooper?
    @State private var aspectRatio: CGFloat

    /// Natural aspect per path, so a revisited video reserves its true aspect on the first frame
    /// instead of reflowing from the 16:9 seed mid-transition.
    @MainActor private static var naturalAspectCache: [String: CGFloat] = [:]

    init(videoPath: String, autoPlay: Bool, caption: String, maxHeight: CGFloat, loop: Bool = false) {
        self.videoPath = videoPath
        self.autoPlay = autoPlay
        self.caption = caption
        self.maxHeight = maxHeight
        self.loop = loop
        _aspectRatio = State(initialValue: Self.naturalAspectCache[videoPath] ?? 16.0 / 9.0)
    }

    private var videoURL: URL {
        if videoPath.hasPrefix("http") {
            return URL(string: videoPath)!
        }
        return URL(fileURLWithPath: videoPath)
    }

    @Environment(\.palette) private var palette

    var body: some View {
        VStack {
            // A looping ambient video hides the controls.
            InspectPlayerView(player: player, controlsStyle: loop ? .none : .inline)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(maxHeight: maxHeight)

            if !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 20))
                    .foregroundStyle(palette.text)
                    .italic()
            }
        }
        .onAppear {
            let item = AVPlayerItem(url: videoURL)
            if loop {
                // Retained in @State so it keeps looping.
                looper = AVPlayerLooper(player: player, templateItem: item)
                if autoPlay { player.playImmediately(atRate: 1) }
            } else {
                player.replaceCurrentItem(with: item)
                if autoPlay { player.play() }
            }
            loadNaturalSize()
        }
    }

    private func loadNaturalSize() {
        let asset = AVURLAsset(url: videoURL)
        Task {
            guard let track = try? await asset.loadTracks(withMediaType: .video).first,
                  let size = try? await track.load(.naturalSize),
                  size.height > 0 else { return }
            await MainActor.run {
                let ratio = size.width / size.height
                Self.naturalAspectCache[videoPath] = ratio
                // Not animated: it would ride the step crossfade and read as a reflow.
                var noAnimation = Transaction()
                noAnimation.disablesAnimations = true
                withTransaction(noAnimation) {
                    aspectRatio = ratio
                }
            }
        }
    }
}


/// Size by height when the config authored one (a mark), else cap the width (a screenshot).
private struct MediaNaturalSize: ViewModifier {
    let height: CGFloat?
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if let height {
            content.frame(height: height)
        } else {
            content.frame(maxWidth: maxWidth)
        }
    }
}

// MARK: - Why an image block drew nothing

/// What to tell an author whose `image` block drew nothing. Names the real cause: a remote URL is
/// not a missing file, the block does not fetch.
enum ImageBlockAdvice {

    static func reason(for path: String) -> String {
        let lower = path.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            if lower.hasSuffix(".gif") {
                return "remote URL — a remote .gif DOES load (it takes the animated path), so check "
                     + "the address rather than the format"
            }
            return "remote URL — the `image` block loads local files only; a .gif is the one format "
                 + "that loads remotely. Download the picture and reference it by path, or use a "
                 + "`webcontent` block if it must stay remote"
        }
        if path.hasPrefix("/") {
            return "No file at that absolute path"
        }
        return "No file at that path relative to `iconBasePath` — check the base path, or use an "
             + "absolute path"
    }
}
