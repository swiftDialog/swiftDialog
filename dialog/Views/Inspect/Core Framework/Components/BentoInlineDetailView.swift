//
//  BentoInlineDetailView.swift
//  dialog
//
//  The detail sheet a bento cell expands into: a two-column measure (text beside a media slot), a media
//  column only for explicit `detailMedia`, and the "2 of 6 · Category" subject line.
//  The shared sheet chrome lives in `DetailSheetShell`.

import ImageIO
import SwiftUI

/// Reads an image's pixel dimensions without decoding it, so the media slot matches the picture.
/// Remote URLs return nil and the slot keeps its 16:10 default.
enum MediaAspectProbe {
    static func aspect(of path: String, basePath: String?) -> CGFloat? {
        guard !path.hasPrefix("http://"), !path.hasPrefix("https://") else { return nil }
        let fullPath: String
        if path.hasPrefix("/") {
            fullPath = path
        } else if let basePath {
            fullPath = (basePath as NSString).appendingPathComponent(path)
        } else {
            fullPath = path
        }
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: fullPath) as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = props[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0
        else { return nil }
        return width / height
    }
}

struct BentoInlineDetailView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let cellConfig: InspectConfig.GuidanceContent.BentoCellConfig
    let overlay: InspectConfig.DetailOverlayConfig
    let gridSize: CGSize
    let accentColor: Color
    let iconBasePath: String?
    /// Position among siblings for the "1 of 6" subject; nil omits the counter.
    var subjectIndex: Int?
    var subjectTotal: Int?
    @ObservedObject var inspectState: Context
    let onClose: () -> Void
    @Environment(\.inspectLocalization) private var l10n

    @Environment(\.colorScheme) private var colorScheme

    /// The text measure, and the narrowest it may go when the window cannot fit both columns.
    private static var textMeasure: CGFloat { 448 }
    private static var textFloor: CGFloat { 380 }
    /// The media slot keeps its width while text yields down to `textFloor`; only then does media shrink.
    private static var mediaMeasure: CGFloat { 340 }
    private static var mediaFloor: CGFloat { 240 }
    /// A slot taller than this would push the sheet past the text it sits beside.
    private static var maxMediaHeight: CGFloat { 320 }
    /// Must match the shell's padding and gutter, or the sheet and its content disagree about their edges.
    private static var gutter: CGFloat { DetailSheetMetrics.gutter }
    private static var pad: CGFloat { DetailSheetMetrics.pad }

    /// Width ÷ height of the still image once read from disk; sizing the slot to it avoids letterboxing.
    @State private var mediaAspect: CGFloat?

    private var headerTitle: String {
        overlay.title ?? cellConfig.title ?? l10n("ui.bentoDetailTitle", "Details")
    }

    private var headerSubtitle: String? {
        overlay.subtitle ?? cellConfig.subtitle
    }

    /// Explicit media only; the cell's background image is decoration and never gets a column.
    private var resolvedMediaPath: String? {
        overlay.detailMedia
    }

    private var showMediaPanel: Bool { resolvedMediaPath != nil }

    /// "1 of 6 · Patch intelligence": position, then the cell's category label.
    private var subjectLine: String? {
        var parts: [String] = []
        if let index = subjectIndex, let total = subjectTotal, total > 0 {
            parts.append("\(index + 1) of \(total)")
        }
        if let label = cellConfig.label, !label.isEmpty {
            parts.append(label.prefix(1).uppercased() + label.dropFirst().lowercased())
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        DetailSheetShell(
            backLabel: overlay.closeButtonText ?? l10n("ui.bentoDetailBack", "All projects"),
            subject: subjectLine,
            accentColor: accentColor,
            width: sheetWidth,
            maxHeight: gridSize.height,
            background: overlay.backgroundColor.map { Color(hex: $0) },
            onClose: onClose
        ) {
            HStack(alignment: .top, spacing: DetailSheetMetrics.gutter) {
                textColumn
                    .frame(width: textWidth, alignment: .topLeading)

                if showMediaPanel {
                    mediaColumn
                        .frame(width: mediaWidth, alignment: .top)
                }
            }
        }
    }

    /// The grid's measured area (window minus preset padding); a sheet is never wider than this.
    private var availableContentWidth: CGFloat {
        max(280, gridSize.width - Self.pad * 2)
    }

    /// How much narrower the two columns must be than their ideals to fit the window.
    private var contentShortfall: CGFloat {
        guard showMediaPanel else { return 0 }
        return max(0, (Self.textMeasure + Self.gutter + Self.mediaMeasure) - availableContentWidth)
    }

    private var textWidth: CGFloat {
        guard showMediaPanel else { return min(Self.textMeasure, availableContentWidth) }
        let textGive = Self.textMeasure - Self.textFloor
        let mediaGive = Self.mediaMeasure - Self.mediaFloor
        // Text yields first, then media; past both floors the text absorbs the rest so the sheet never overhangs.
        let beyondBothFloors = max(0, contentShortfall - textGive - mediaGive)
        return max(300, Self.textMeasure - min(contentShortfall, textGive) - beyondBothFloors)
    }

    private var mediaWidth: CGFloat {
        guard showMediaPanel else { return 0 }
        let textGive = Self.textMeasure - Self.textFloor
        let mediaShare = max(0, contentShortfall - textGive)
        return max(Self.mediaFloor, Self.mediaMeasure - mediaShare)
    }

    /// The media slot: the image's own aspect when known, 16:10 otherwise (video, remote URL).
    /// Height is capped and width follows, so the frame always matches the image.
    private var mediaSlot: CGSize {
        let aspect = min(max(mediaAspect ?? 1.6, 0.6), 2.4)
        let width = min(mediaWidth, Self.maxMediaHeight * aspect)
        return CGSize(width: width, height: width / aspect)
    }

    private var sheetWidth: CGFloat {
        let content = textWidth + (showMediaPanel ? Self.gutter + mediaWidth : 0)
        return min(content + Self.pad * 2, gridSize.width)
    }

    // MARK: - Text column

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headerTitle)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = headerSubtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }

            if let content = overlay.content, !content.isEmpty {
                GuidanceContentView(
                    contentBlocks: content,
                    scaleFactor: 1.0,
                    iconBasePath: iconBasePath,
                    inspectState: inspectState,
                    itemId: "bento-inline-\(cellConfig.id)",
                    onOverlayTap: nil,
                    accentColor: inspectState.config?.highlightColor.map { Color(hex: $0) } ?? accentColor
                )
                .padding(.top, 18)
            } else {
                // A title-only overlay says so instead of showing an empty panel.
                Text(l10n("ui.bentoDetailEmpty", "No additional details available."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 18)
            }
        }
    }

    // MARK: - Media column (only for real media)

    @ViewBuilder
    private var mediaColumn: some View {
        if let mediaPath = resolvedMediaPath {
            let url: URL = mediaPath.hasPrefix("http")
                ? (URL(string: mediaPath) ?? URL(fileURLWithPath: mediaPath))
                : URL(fileURLWithPath: mediaPath)
            let mediaType = IntroMediaType.detect(from: url)
            // Fit by default; the cell's `imageFit` describes its background, and filling would crop the screenshot.
            // Only an explicit `detailMediaFit` forces fill.
            let useFit = (overlay.detailMediaFit ?? "fit").lowercased() == "fit"
            let slot = mediaSlot

            Group {
                switch mediaType {
                case .animatedImage:
                    IntroAnimatedImageView(url: url,
                                           maxWidth: slot.width,
                                           maxHeight: slot.height)
                case .video:
                    IntroNativeVideoPlayer(url: url, autoplay: true)
                default:
                    AsyncImageView(
                        iconPath: mediaPath,
                        basePath: iconBasePath,
                        maxWidth: slot.width,
                        maxHeight: slot.height,
                        imageFit: useFit ? .fit : .fill,
                        fallback: { Color.secondary.opacity(0.1) }
                    )
                }
            }
            // Still images and GIFs are measured; video keeps 16:10 (its player fills the frame anyway).
            .task(id: mediaPath) {
                guard mediaType != .video else { return }
                let base = iconBasePath
                mediaAspect = await Task.detached {
                    MediaAspectProbe.aspect(of: mediaPath, basePath: base)
                }.value
            }
            .frame(width: slot.width, height: slot.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.top, 6)
        }
    }
}
