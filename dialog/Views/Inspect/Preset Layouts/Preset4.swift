//
//  Preset4.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Preset4: Compact Toast Installer
//  Minimal ~550×180 window showing one item at a time.
//  Supports intro → items → summary flow, all in the same compact window.
//
//  Progress modes:
//    "shared"  — Single progress bar showing "X of Y completed" (default)
//    "perItem" — Indeterminate progress per item, auto-advances on completion
//

import SwiftUI

struct Preset4View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @StateObject private var iconCache = PresetIconCache()

    @State private var currentPhase: PresetPhase = .main
    @State private var currentItemIndex: Int = 0

    // MARK: - Derived properties

    private var primaryColor: Color {
        Color(hex: inspectState.uiConfiguration.highlightColor)
    }

    private var progressMode: String {
        inspectState.config?.progressMode ?? "shared"
    }

    private var basePath: String? {
        inspectState.uiConfiguration.iconBasePath
    }

    private var currentItem: InspectConfig.ItemConfig? {
        guard !inspectState.items.isEmpty,
              currentItemIndex >= 0,
              currentItemIndex < inspectState.items.count else { return nil }
        return inspectState.items[currentItemIndex]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)

            switch currentPhase {
            case .intro:
                compactIntroView
            case .main:
                mainPhaseView
            case .summary:
                compactSummaryView
            }
        }
        .ignoresSafeArea()
        .onAppear {
            iconCache.cacheMainIcon(for: inspectState)
            iconCache.cacheItemIcons(for: inspectState)

            if inspectState.config?.introScreen != nil {
                currentPhase = .intro
            }
        }
        .onChange(of: inspectState.completedItems) { _, _ in
            advanceToNextItem()
            checkAutoTransitionToSummary()
        }
        .onChange(of: currentPhase) { _, newPhase in
            if newPhase == .main {
                checkAutoTransitionToSummary()
            }
        }
        .onChange(of: inspectState.downloadingItems) { _, newDownloading in
            if let nextDownloadingIndex = inspectState.items.firstIndex(where: { newDownloading.contains($0.id) && !inspectState.completedItems.contains($0.id) }) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentItemIndex = nextDownloadingIndex
                }
            }
        }
    }

    // MARK: - Main Phase

    private var mainPhaseView: some View {
        HStack(spacing: 14) {
            cachedIcon(
                for: currentItem.flatMap { iconCache.getItemIconPath(for: $0, state: inspectState) } ?? "",
                fallbackSymbol: "app.fill"
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(currentItem?.displayName ?? inspectState.config?.title ?? "Installing...")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                if progressMode == "perItem" {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(primaryColor)
                } else {
                    let total = max(inspectState.items.count, 1)
                    let completed = inspectState.completedItems.count
                    ProgressView(value: Double(completed), total: Double(total))
                        .progressViewStyle(.linear)
                        .tint(primaryColor)
                        .animation(.easeInOut(duration: 0.3), value: completed)
                }

                if let item = currentItem {
                    Text(getItemStatus(for: item))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if progressMode == "shared" {
                    Text("\(inspectState.completedItems.count) of \(inspectState.items.count) completed")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Compact Intro Phase

    private var compactIntroView: some View {
        HStack(spacing: 14) {
            let heroPath = inspectState.config?.introScreen?.heroImage
                ?? inspectState.uiConfiguration.iconPath ?? ""
            toastIcon(path: heroPath, fallbackSymbol: "info.circle.fill")

            VStack(alignment: .leading, spacing: 2) {
                Text(inspectState.config?.introScreen?.title ?? inspectState.config?.title ?? "Welcome")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                if let subtitle = inspectState.config?.introScreen?.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // Defer menu — shared deferral pattern (exit code 10, result file, ignitecli env)
                if inspectState.buttonConfiguration.button2Visible || isDeferralEnabled(config: inspectState.config) {
                    DeferralMenuView(
                        config: inspectState.config,
                        accentColor: primaryColor,
                        buttonText: inspectState.buttonConfiguration.button2Text.isEmpty
                            ? nil : inspectState.buttonConfiguration.button2Text,
                        style: .compact
                    )
                }

                Button(inspectState.config?.introScreen?.buttonText ?? "Continue") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentPhase = .main
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryColor)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Compact Summary Phase

    private var compactSummaryView: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(inspectState.config?.summaryScreen?.title ?? "Installation Complete")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                if let subtitle = inspectState.config?.summaryScreen?.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    let failedCount = inspectState.failedItems.count
                    if failedCount > 0 {
                        Text("\(inspectState.completedItems.count) installed, \(failedCount) failed")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(inspectState.completedItems.count) items installed successfully")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button(inspectState.config?.summaryScreen?.buttonText ?? "Close") {
                writeLog("Preset4View: Summary closed", logLevel: .info)
                exit(0)
            }
            .buttonStyle(.borderedProminent)
            .tint(primaryColor)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Icon helpers

    /// Synchronous icon from already-cached path — no loading spinner
    @ViewBuilder
    private func cachedIcon(for path: String, fallbackSymbol: String) -> some View {
        let resolvedPath = resolvePath(path)
        if let resolvedPath, let nsImage = NSImage(contentsOfFile: resolvedPath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: 28))
                .foregroundStyle(primaryColor.opacity(0.6))
                .frame(width: 48, height: 48)
        }
    }

    /// Async icon for intro (loads once, spinner acceptable)
    @ViewBuilder
    private func toastIcon(path: String, fallbackSymbol: String) -> some View {
        if !path.isEmpty {
            AsyncImageView(
                iconPath: path,
                basePath: basePath,
                maxWidth: 48,
                maxHeight: 48,
                imageFit: .fit
            ) {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 28))
                    .foregroundStyle(primaryColor.opacity(0.6))
                    .frame(width: 48, height: 48)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: 28))
                .foregroundStyle(primaryColor.opacity(0.6))
                .frame(width: 48, height: 48)
        }
    }

    /// Resolve relative path against basePath
    private func resolvePath(_ path: String) -> String? {
        guard !path.isEmpty else { return nil }
        if path.hasPrefix("/") { return path }
        guard let base = basePath else { return path }
        return (base as NSString).appendingPathComponent(path)
    }

    // MARK: - Deferral (uses shared performDeferral() from PresetCommonHelpers)

    // MARK: - Auto-Advance Logic

    private func advanceToNextItem() {
        guard currentPhase == .main, !inspectState.items.isEmpty else { return }

        if let item = currentItem,
           !inspectState.completedItems.contains(item.id),
           !inspectState.failedItems.contains(item.id) {
            return
        }

        if let nextIdx = inspectState.items.firstIndex(where: {
            inspectState.downloadingItems.contains($0.id) && !inspectState.completedItems.contains($0.id)
        }) {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentItemIndex = nextIdx
            }
            return
        }

        if let nextIdx = inspectState.items.firstIndex(where: {
            !inspectState.completedItems.contains($0.id) &&
            !inspectState.downloadingItems.contains($0.id) &&
            !inspectState.failedItems.contains($0.id)
        }) {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentItemIndex = nextIdx
            }
            return
        }
    }

    private func checkAutoTransitionToSummary() {
        guard currentPhase == .main,
              !inspectState.items.isEmpty,
              inspectState.completedItems.count == inspectState.items.count else { return }

        if inspectState.config?.summaryScreen != nil {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPhase = .summary
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                writeLog("Preset4View: All items complete, auto-exiting", logLevel: .info)
                exit(0)
            }
        }
    }
}

// MARK: - Preset4 Wrapper

struct Preset4Wrapper: View {
    @ObservedObject var coordinator: InspectState

    var body: some View {
        Preset4View(inspectState: coordinator)
    }
}
