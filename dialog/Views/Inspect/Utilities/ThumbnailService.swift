//
//  ThumbnailService.swift
//  dialog
//
//  Downsampled thumbnails for the wallpaper picker, decoded via CGImageSource so the full image
//  is never loaded, and cached on disk and in memory while the picker is on screen.
//

import AppKit

@MainActor
class ThumbnailService: ObservableObject {
    static let shared = ThumbnailService()

    @Published var thumbnails: [String: NSImage] = [:]
    private var preloadTask: Task<Void, Never>?

    private let cacheDir = "/var/tmp/dialog-thumbnails"
    private let maxPixelSize: Int = 384
    private let jpegQuality: CGFloat = 0.85

    private init() {
        try? FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Sync Lookup

    /// Cached thumbnail (memory, then disk); nil if not yet generated.
    func thumbnail(for path: String) -> NSImage? {
        if let cached = thumbnails[path] {
            return cached
        }
        let diskPath = diskCachePath(for: path)
        guard FileManager.default.fileExists(atPath: diskPath),
              !isStale(source: path, cache: diskPath),
              let image = NSImage(contentsOfFile: diskPath) else {
            return nil
        }
        thumbnails[path] = image
        return image
    }

    // MARK: - Async Generation

    /// Generates one thumbnail unless it is already cached.
    func loadThumbnail(for path: String) async {
        if thumbnails[path] != nil { return }

        let diskPath = diskCachePath(for: path)

        if FileManager.default.fileExists(atPath: diskPath),
           !isStale(source: path, cache: diskPath),
           let diskImage = NSImage(contentsOfFile: diskPath) {
            thumbnails[path] = diskImage
            return
        }

        let thumb = await Task.detached(priority: .userInitiated) { [maxPixelSize, jpegQuality] in
            guard let image = Self.downsample(path: path, maxPixelSize: maxPixelSize) else { return nil as NSImage? }
            Self.saveToDisk(image: image, at: diskPath, quality: jpegQuality)
            return image
        }.value

        if let thumb, !Task.isCancelled {
            thumbnails[path] = thumb
        }
    }

    /// Drops the in-memory thumbnails when the picker goes away; the disk cache makes a return quick.
    func releaseThumbnails() {
        preloadTask?.cancel()
        preloadTask = nil
        thumbnails.removeAll()
    }

    /// Preloads thumbnails for all paths, in order. A new preload replaces one still running.
    func preloadThumbnails(for paths: [String]) {
        preloadTask?.cancel()
        preloadTask = Task {
            for path in paths {
                if Task.isCancelled { return }
                if thumbnails[path] != nil { continue }
                await loadThumbnail(for: path)
            }
        }
    }

    // MARK: - Core Downsample

    private nonisolated static func downsample(path: String, maxPixelSize: Int) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - Disk Cache

    private nonisolated func diskCachePath(for sourcePath: String) -> String {
        let hash = sourcePath.utf8.reduce(into: UInt64(5381)) { hash, byte in
            hash = hash &* 33 &+ UInt64(byte)
        }
        return "\(cacheDir)/\(hash).jpg"
    }

    private nonisolated static func saveToDisk(image: NSImage, at path: String, quality: CGFloat) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            return
        }
        try? jpegData.write(to: URL(fileURLWithPath: path))
    }

    private nonisolated func isStale(source sourcePath: String, cache cachePath: String) -> Bool {
        let fm = FileManager.default
        guard let sourceAttrs = try? fm.attributesOfItem(atPath: sourcePath),
              let cacheAttrs = try? fm.attributesOfItem(atPath: cachePath),
              let sourceDate = sourceAttrs[.modificationDate] as? Date,
              let cacheDate = cacheAttrs[.modificationDate] as? Date else {
            return true
        }
        return sourceDate > cacheDate
    }
}
