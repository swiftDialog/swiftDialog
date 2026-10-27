//
//  IntroMediaComponents.swift
//  dialog
//
//  The media stack for intro and outro steps: type detection, native and embedded video, remote
//  and animated images, web content, the carousel, and the media URL rule.
//

import SwiftUI

// MARK: - Media Content Types

import AVKit
import WebKit

/// The renderer a media URL needs, from its extension, then its host.
enum IntroMediaType {
    case video          // direct video files
    case animatedImage  // gif, webp, apng
    case staticImage
    case embedVideo     // video services, through an iframe
    case webContent
    case unknown        // falls back to a web view

    static func detect(from url: URL) -> IntroMediaType {
        let pathExtension = url.pathExtension.lowercased()
        let host = url.host?.lowercased() ?? ""
        let urlString = url.absoluteString.lowercased()

        switch pathExtension {
        case "mp4", "mov", "m4v", "webm", "avi", "mkv":
            return .video
        case "gif":
            return .animatedImage
        case "webp", "apng":
            return .animatedImage
        case "png", "jpg", "jpeg", "heic", "heif", "bmp", "tiff":
            return .staticImage
        case "html", "htm":
            return .webContent
        default:
            break
        }

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

        // GIF hosts often serve without an extension; a media URL is the file, a page needs a web view.
        let gifHosts = ["giphy.com", "media.giphy.com", "tenor.com", "gfycat.com", "imgur.com"]
        if gifHosts.contains(where: { host.contains($0) }) {
            if urlString.contains("/media/") || urlString.contains(".gif") {
                return .animatedImage
            }
            return .webContent
        }

        if urlString.contains("raw.githubusercontent.com") || urlString.contains("/raw/") {
            if urlString.contains(".gif") { return .animatedImage }
            if urlString.contains(".mp4") || urlString.contains(".mov") { return .video }
            if urlString.contains(".png") || urlString.contains(".jpg") { return .staticImage }
        }

        return .unknown
    }
}

/// How an image fills its media box: `fit` shows the whole image, `fill` crops it.
enum MediaFit {
    case fit
    case fill

    /// Absent or unrecognised is `fit`; cropping is opt-in.
    init(_ authored: String?) {
        self = authored?.lowercased() == "fill" ? .fill : .fit
    }

    var contentMode: ContentMode { self == .fill ? .fill : .fit }
    var imageScaling: NSImageScaling { self == .fill ? .scaleAxesIndependently : .scaleProportionallyUpOrDown }
}

/// One media view for any URL: detects the type and picks the renderer.
struct IntroMediaPlayer: View {
    let url: URL?
    let autoplay: Bool
    let height: Double
    let cornerRadius: Double
    /// Image arms only; a video's aspect is the player's business.
    let fit: MediaFit

    init(url: URL?, autoplay: Bool = true, height: Double = 400, cornerRadius: Double = 12,
         fit: MediaFit = .fit) {
        self.url = url
        self.autoplay = autoplay
        self.height = height
        self.cornerRadius = cornerRadius
        self.fit = fit
    }

    var body: some View {
        Group {
            if let url = url {
                let mediaType = IntroMediaType.detect(from: url)

                switch mediaType {
                case .video:
                    IntroNativeVideoPlayer(url: url, autoplay: autoplay)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                case .animatedImage:
                    IntroAnimatedImageView(url: url, maxWidth: 800, maxHeight: height, fit: fit)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                case .staticImage:
                    IntroRemoteImageView(url: url, fit: fit)
                        .frame(height: height)
                        // `fill` overflows its box, so bound it before the rounded clip.
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                case .embedVideo:
                    IntroEmbedVideoPlayer(url: url, autoplay: autoplay)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                case .webContent, .unknown:
                    IntroWebContentView(url: url)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            } else {
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

/// Older name, kept for callers.
typealias IntroVideoPlayer = IntroMediaPlayer

/// AVPlayer for local and direct video files; loops until the step ends.
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
            // Muted: the user never asked for it to play, and it loops. The inline controls can
            // unmute.
            player.isMuted = true
            player.play()
        }

        context.coordinator.endObserver = Self.loopObserver(for: player, autoplay: autoplay)

        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var endObserver: NSObjectProtocol?
    }

    /// Rewinds at the end, and plays again when autoplaying. Holds the player weakly, so the
    /// observer never keeps a removed player (and its decode buffers) alive.
    static func loopObserver(for player: AVPlayer, autoplay: Bool) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            if autoplay { player?.play() }
        }
    }

    /// A removed view stops and releases its player, so no sound plays on and no buffers are kept.
    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: Coordinator) {
        if let observer = coordinator.endObserver {
            NotificationCenter.default.removeObserver(observer)
            coordinator.endObserver = nil
        }
        nsView.player?.pause()
        nsView.player?.replaceCurrentItem(with: nil)
        nsView.player = nil
    }
}

/// A video service's player in a web view, through an iframe wrapper.
struct IntroEmbedVideoPlayer: NSViewRepresentable {
    let url: URL
    let autoplay: Bool

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        config.mediaTypesRequiringUserActionForPlayback = autoplay ? [] : [.all]
        config.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false

        // A desktop Safari user agent; some players refuse the default one.
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        if let embedURL = getEmbedURL(from: url) {
            let html = createEmbedHTML(embedURL: embedURL, autoplay: autoplay)
            writeLog("IntroEmbedVideoPlayer: Loading via HTML wrapper: \(embedURL)", logLevel: .debug)
            webView.loadHTMLString(html, baseURL: embedURL)
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
    }

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

    /// A video service URL's embed equivalent, with autoplay parameters; unknown hosts pass through.
    private func getEmbedURL(from url: URL) -> URL? {
        let urlString = url.absoluteString
        let host = url.host?.lowercased() ?? ""

        // YouTube: rebuild on youtube-nocookie.com; enablejsapi and playsinline are what WKWebView needs.
        if host.contains("youtube.com") || host.contains("youtube-nocookie.com") {
            if urlString.contains("/watch") {
                if let videoID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "v" })?.value {
                    var params = "enablejsapi=1&playsinline=1&rel=0"
                    if autoplay {
                        params += "&autoplay=1&mute=1"
                    }
                    return URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?\(params)")
                }
            }
            if urlString.contains("/embed/") {
                var params = "enablejsapi=1&playsinline=1&rel=0"
                if autoplay {
                    params += "&autoplay=1&mute=1"
                }
                if let videoID = url.pathComponents.last, !videoID.isEmpty {
                    return URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?\(params)")
                }
                return addAutoplayParam(to: url, param: params)
            }
        }

        if host.contains("youtu.be") {
            let videoID = url.lastPathComponent
            var params = "enablejsapi=1&playsinline=1&rel=0"
            if autoplay {
                params += "&autoplay=1&mute=1"
            }
            return URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?\(params)")
        }

        if host.contains("vimeo.com") {
            if !host.contains("player.vimeo.com") {
                let videoID = url.lastPathComponent
                let autoplayParam = autoplay ? "?autoplay=1&muted=1" : ""
                return URL(string: "https://player.vimeo.com/video/\(videoID)\(autoplayParam)")
            }
            return autoplay ? addAutoplayParam(to: url, param: "autoplay=1&muted=1") : url
        }

        if host.contains("dailymotion.com") || host.contains("dai.ly") {
            if let videoID = url.pathComponents.last {
                let autoplayParam = autoplay ? "?autoplay=1&mute=1" : ""
                return URL(string: "https://www.dailymotion.com/embed/video/\(videoID)\(autoplayParam)")
            }
        }

        if host.contains("loom.com") {
            if urlString.contains("/share/") {
                let embedURL = urlString.replacingOccurrences(of: "/share/", with: "/embed/")
                return URL(string: embedURL)
            }
        }

        if host.contains("wistia.com") || host.contains("fast.wistia.net") {
            if let videoID = url.pathComponents.last, !videoID.isEmpty {
                return URL(string: "https://fast.wistia.net/embed/iframe/\(videoID)")
            }
        }

        if host.contains("streamable.com") {
            let videoID = url.lastPathComponent
            return URL(string: "https://streamable.com/e/\(videoID)")
        }

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

/// A remote still image, loaded asynchronously.
struct IntroRemoteImageView: View {
    let url: URL
    var fit: MediaFit = .fit

    @State private var loadedImage: NSImage?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fit.contentMode)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
        URLSession.shared.dataTask(with: url) { data, _, error in
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

/// Any web URL in a web view.
struct IntroWebContentView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        // A local page loads through loadFileURL so its own images and styles beside it can load.
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
    }
}

// MARK: - Animated GIF View

/// An animated image in an `NSImageView`, loaded off the main thread.
struct IntroAnimatedImageView: NSViewRepresentable {
    let url: URL?
    let maxWidth: Double
    let maxHeight: Double
    let fit: MediaFit

    init(url: URL?, maxWidth: Double = 500, maxHeight: Double = 400, fit: MediaFit = .fit) {
        self.url = url
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.fit = fit
    }

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = fit.imageScaling
        imageView.imageAlignment = .alignCenter
        imageView.animates = true

        // Low priorities so SwiftUI's frame wins over the image's intrinsic size.
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)

        if let url = url {
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

/// A media carousel with arrow-key navigation, arrows and dots.
struct IntroMediaCarousel: View {
    let items: [InspectConfig.MediaItemConfig]
    let height: Double
    let autoplay: Bool
    let showArrows: Bool
    let showDots: Bool
    let accentColor: Color
    /// Authored `mediaFit`; `.fit` by default, as `MediaFit(nil)` gives.
    var fit: MediaFit = .fit

    @State private var currentIndex: Int = 0
    @FocusState private var isFocused: Bool

    init(
        items: [InspectConfig.MediaItemConfig],
        height: Double = 400,
        autoplay: Bool = true,
        showArrows: Bool = true,
        showDots: Bool = true,
        accentColor: Color = .accentColor,
        fit: MediaFit = .fit
    ) {
        self.items = items
        self.height = height
        self.autoplay = autoplay
        self.showArrows = showArrows
        self.showDots = showDots
        self.accentColor = accentColor
        self.fit = fit
    }

    var body: some View {
        VStack(spacing: 16) {
            if let title = items[safe: currentIndex]?.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            ZStack {
                if let item = items[safe: currentIndex], let urlString = item.url {
                    mediaContent(for: urlString)
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .id("media-\(currentIndex)-\(urlString)")
                }

                if showArrows && items.count > 1 {
                    navigationArrows
                }
            }
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )

            if let caption = items[safe: currentIndex]?.caption, !caption.isEmpty {
                Text(caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

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
        if let url = IntroMediaURL.resolve(urlString) {
            IntroMediaPlayer(
                url: url,
                autoplay: autoplay,
                height: height,
                cornerRadius: 12,
                fit: fit
            )
        } else {
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


// MARK: - Media URL resolution

/// Turns an authored media string into a URL the players can load. The local file is asked first
/// because `URL(string:)` happily parses a POSIX path into a schemeless URL, which AVPlayer draws
/// as broken media.
enum IntroMediaURL {
    /// Local file first, then a remote URL with a scheme, then nil. The scheme test keeps a
    /// mistyped local path from reaching the player instead of the placeholder.
    static func resolve(_ urlString: String) -> URL? {
        let expanded = (urlString as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expanded) {
            return URL(fileURLWithPath: expanded)
        }
        if let url = URL(string: urlString), url.scheme != nil {
            return url
        }
        return nil
    }
}
