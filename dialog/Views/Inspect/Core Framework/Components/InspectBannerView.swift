//
// InspectBannerView.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Shared banner component for Inspect presets.
//  Loads an image asynchronously, falls back to a gradient,
//  and optionally overlays a title + step counter.
//

import SwiftUI

struct InspectBannerView: View {
    let bannerImage: String?
    let bannerHeight: CGFloat
    let bannerTitle: String?
    let iconBasePath: String?
    let accentColor: Color
    let scaleFactor: CGFloat

    // Optional step counter
    let stepText: String?
    let onOptionClick: (() -> Void)?

    @State private var cachedImage: NSImage?
    @State private var imageLoaded = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image or gradient fallback
            if let image = cachedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: bannerHeight * scaleFactor)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [accentColor.opacity(0.6), accentColor.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(maxWidth: .infinity, maxHeight: bannerHeight * scaleFactor)
            }

            // Title + step counter overlay
            VStack(spacing: 0) {
                VStack(spacing: 8 * scaleFactor) {
                    if let title = bannerTitle, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 24 * scaleFactor, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }

                    if let stepText = stepText {
                        HStack {
                            Spacer()
                            Text(stepText)
                                .font(.system(size: 12 * scaleFactor, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(.thinMaterial.opacity(0.6))
                                        .overlay(
                                            Capsule()
                                                .stroke(.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .onTapGesture {
                                    if NSEvent.modifierFlags.contains(.option) {
                                        onOptionClick?()
                                    }
                                }
                                .help("Option-click to reset progress")
                            Spacer()
                        }
                    }
                }
                .padding(.top, 16 * scaleFactor)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: bannerHeight * scaleFactor)
        .clipShape(
            .rect(
                topLeadingRadius: 16,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 16
            )
        )
        .onAppear {
            loadBannerImage()
        }
    }

    // MARK: - Image Loading

    private func loadBannerImage() {
        guard let path = bannerImage, !path.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            // Skip color specifications
            if path.range(of: "colo[u]?r=", options: .regularExpression) != nil {
                return
            }

            let fullPath: String
            if path.hasPrefix("/") {
                fullPath = path
            } else if let basePath = iconBasePath {
                fullPath = "\(basePath)/\(path)"
            } else {
                fullPath = path
            }

            if let image = NSImage(contentsOfFile: fullPath) {
                DispatchQueue.main.async {
                    self.cachedImage = image
                    self.imageLoaded = true
                }
            }
        }
    }
}
