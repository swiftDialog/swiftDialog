//
//  CardMediaViewer.swift
//  dialog
//
//  The media viewer step: artwork on a light stage, title and caption below, a pill pager as the
//  only control. The exit button appears on the last frame only. Video shares the frame so paging
//  between an image and a clip never moves the controls.
//

import SwiftUI

struct CardMediaViewerItem {
    let path: String
    let title: String?
    let caption: String?
    var isClip: Bool {
        ["gif", "mp4", "mov", "m4v"].contains((path as NSString).pathExtension.lowercased())
    }
}

struct CardMediaViewerView: View {
    @Environment(\.palette) private var palette
    let stepTitle: String
    let items: [CardMediaViewerItem]
    let index: Int
    let accent: Color
    let onPrev: (() -> Void)?              // nil on the first frame
    let onNext: (() -> Void)?              // nil on the last frame
    let exitText: String                   // the one button, last frame only
    let onExit: () -> Void
    /// `mediaStage`: nil/"light" the light stage; "surface" a translucent wash; "#RRGGBB" a colour.
    var stageStyle: String?

    /// Light in both appearances: artwork and screenshots are authored against white.
    private static let stage = Color(red: 0.957, green: 0.961, blue: 0.969)

    private var stageGround: AnyShapeStyle {
        switch stageStyle?.lowercased() {
        case nil, "light":
            return AnyShapeStyle(Self.stage)
        case "surface":
            return AnyShapeStyle(palette.text.opacity(0.035))
        case let hex? where hex.hasPrefix("#"):
            return AnyShapeStyle(Color(hex: hex))
        default:
            return AnyShapeStyle(Self.stage)
        }
    }

    private var current: CardMediaViewerItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(stepTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text.opacity(0.55))
                Spacer()
                if let itemTitle = current?.title {
                    Text(itemTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.text.opacity(0.45))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // The media takes the stage's measured room; a fixed height would clip a short window.
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(stageGround)
                    if let item = current {
                        Group {
                            if item.isClip, !item.path.lowercased().hasSuffix(".gif"),
                               FileManager.default.fileExists(atPath: item.path) {
                                AspectFitVideoView(videoPath: item.path, autoPlay: true,
                                                   caption: "",
                                                   maxHeight: max(60, geo.size.height - 60),
                                                   loop: false)
                            } else {
                                AsyncImageView(
                                    iconPath: item.path,
                                    basePath: nil,
                                    maxWidth: max(60, geo.size.width - 60),
                                    maxHeight: max(60, geo.size.height - 60),
                                    imageFit: .fit,
                                    fallback: { CardStripePlaceholder().frame(height: 120) }
                                )
                            }
                        }
                        .id("media-viewer-\(index)")   // fresh player per frame
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 3) {
                if let title = current?.title {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.text.opacity(0.9))
                }
                if let caption = current?.caption {
                    Text(caption)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.text.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 14)

            HStack(spacing: 14) {
                pagerArrow("chevron.left", action: onPrev)
                HStack(spacing: 11) {
                    ForEach(items.indices, id: \.self) { i in
                        Circle()
                            .fill(i == index ? accent : palette.text.opacity(0.25))
                            .frame(width: 7, height: 7)
                    }
                    Text("\(index + 1) of \(items.count)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.text.opacity(0.5))
                }
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(Capsule().fill(palette.text.opacity(0.07)))
                pagerArrow("chevron.right", action: onNext)
            }
            .padding(.top, 14)
            .padding(.bottom, 20)
            // Full width first so the exit button anchors to the window edge, not the pager.
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                if onNext == nil {
                    Button(exitText, action: onExit)
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .padding(.trailing, 20)
                }
            }
        }
        // Same ground as every card step so paging never jumps colour.
        .background(CardChromeGround())
    }

    @ViewBuilder private func pagerArrow(_ symbol: String, action: (() -> Void)?) -> some View {
        Button(action: { action?() }) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.text.opacity(action == nil ? 0.2 : 0.7))
                .frame(width: 44, height: 44)
                .background(Circle().fill(palette.text.opacity(action == nil ? 0.04 : 0.08)))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
