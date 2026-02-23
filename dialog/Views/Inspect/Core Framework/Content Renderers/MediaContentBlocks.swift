//
//  MediaContentBlocks.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Media-based content blocks: image-carousel
//

import SwiftUI

// MARK: - Image Carousel Block

/// Displays multiple images with navigation arrows and dots
/// Supports auto-advance and captions
struct ImageCarouselBlock: View {
    let block: InspectConfig.GuidanceContent
    let accentColor: Color
    let maxWidth: CGFloat

    @State private var currentIndex: Int = 0
    @State private var autoAdvanceTimer: Timer?

    private var images: [String] { block.images ?? [] }
    private var captions: [String] { block.captions ?? [] }
    private var imageHeight: CGFloat { block.imageHeight ?? 300 }
    private var showDots: Bool { block.showDots ?? true }
    private var showArrows: Bool { block.showArrows ?? true }
    private var autoAdvance: Bool { block.autoAdvance ?? false }
    private var autoAdvanceDelay: Double { block.autoAdvanceDelay ?? 3.0 }

    var body: some View {
        if !images.isEmpty {
            VStack(spacing: 12) {
                // Image container with navigation
                ZStack {
                    // Current image
                    imageView(for: images[currentIndex])
                        .frame(height: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .id(currentIndex) // Force view refresh on index change

                    // Navigation arrows
                    if showArrows && images.count > 1 {
                        HStack {
                            // Previous button
                            Button(action: previousImage) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.3), radius: 4)
                            }
                            .buttonStyle(.plain)
                            .opacity(currentIndex > 0 ? 1 : 0.3)
                            .disabled(currentIndex == 0)

                            Spacer()

                            // Next button
                            Button(action: nextImage) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.3), radius: 4)
                            }
                            .buttonStyle(.plain)
                            .opacity(currentIndex < images.count - 1 ? 1 : 0.3)
                            .disabled(currentIndex == images.count - 1)
                        }
                        .padding(.horizontal, 12)
                    }
                }

                // Caption
                if currentIndex < captions.count, !captions[currentIndex].isEmpty {
                    Text(captions[currentIndex])
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Dot indicators
                if showDots && images.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? accentColor : Color.secondary.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentIndex = index
                                    }
                                    restartAutoAdvance()
                                }
                        }
                    }
                }
            }
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .onAppear {
                // Set initial index from block if specified
                if let initialIndex = block.currentIndex, initialIndex >= 0, initialIndex < images.count {
                    currentIndex = initialIndex
                }
                startAutoAdvance()
            }
            .onDisappear {
                stopAutoAdvance()
            }
        }
    }

    // MARK: - Image View

    @ViewBuilder
    private func imageView(for path: String) -> some View {
        if path.hasPrefix("sf=") || path.hasPrefix("SF=") {
            // SF Symbol
            let symbolName = String(path.dropFirst(3))
            Image(systemName: symbolName)
                .font(.system(size: imageHeight * 0.4))
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        } else if let nsImage = NSImage(contentsOfFile: path) {
            // Local file
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: imageHeight)
                .clipped()
        } else if let url = URL(string: path), path.hasPrefix("http") {
            // Remote image
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: imageHeight)
                        .clipped()
                case .failure:
                    placeholderView
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: imageHeight)
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.1))
            .frame(maxWidth: .infinity, maxHeight: imageHeight)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Navigation

    private func previousImage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex = max(0, currentIndex - 1)
        }
        restartAutoAdvance()
    }

    private func nextImage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex = min(images.count - 1, currentIndex + 1)
        }
        restartAutoAdvance()
    }

    // MARK: - Auto Advance

    private func startAutoAdvance() {
        guard autoAdvance, images.count > 1 else { return }

        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: autoAdvanceDelay, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex = (currentIndex + 1) % images.count
            }
        }
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }

    private func restartAutoAdvance() {
        stopAutoAdvance()
        startAutoAdvance()
    }
}
