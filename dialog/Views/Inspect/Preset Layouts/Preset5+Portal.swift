//
//  Preset5+Portal.swift
//  dialog
//
//  Preset 5's portal step: URL resolution (file, MDM override, config, then `selfServicePath`), labels,
//  exit behaviour, per-step state reset, and the web area. `CardPortalView` draws the chrome around it.
//

import SwiftUI

extension Preset5View {

    // Portal URL from file, MDM override, or config, in that order (per-step `effectivePortalConfig`).
    var portalURL: URL? {
        let portalCfg = effectivePortalConfig
        var baseURL: String?

        // A URL file allows device-specific URLs.
        if let urlFilePath = portalCfg?.portalURLFile {
            if let fileURL = readURLFromFile(path: urlFilePath) {
                baseURL = fileURL
                writeLog("Preset5: Loaded portal URL from file: \(urlFilePath)", logLevel: .debug)
            }
        }

        if baseURL == nil, let mdmURL = mdmOverrides?.portalURL {
            baseURL = mdmURL
            writeLog("Preset5: Using MDM override portal URL", logLevel: .debug)
        }

        if baseURL == nil {
            baseURL = portalCfg?.portalURL
        }

        guard let urlString = baseURL else { return nil }

        var fullURL = urlString
        if let path = portalCfg?.selfServicePath {
            fullURL =
                urlString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/"
                + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return URL(string: fullURL)
    }

    // Reads a URL from a file, trimming whitespace and newlines.
    func readURLFromFile(path: String) -> String? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            writeLog("Preset5: URL file not found: \(path)", logLevel: .debug)
            return nil
        }
        do {
            let content = try String(contentsOfFile: expandedPath, encoding: .utf8)
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return trimmed
        } catch {
            writeLog("Preset5: Failed to read URL file: \(error)", logLevel: .error)
            return nil
        }
    }


    // MARK: - Portal View

    /// The step's `layout`, the same field `software` uses.
    var portalLayout: PortalLayout {
        PortalLayout(currentStep?.layout)
    }

    /// The address the chrome shows: the view's current URL, else the configured one.
    var portalDisplayURL: URL? {
        portalLiveURL ?? portalURL
    }

    /// Whether the step offers a way past it other than Done.
    var portalHasSkip: Bool {
        currentStep?.skipButtonText != nil
    }

    /// What the failure screen offers, so a page that is down never strands the user.
    var portalAffordances: PortalFailureAffordances {
        portalFailureAffordances(hasSkip: portalHasSkip, isFailed: loadState.isError)
    }

    // MARK: - The card portal arm

    /// The portal step on the card layout, the single renderer for every chrome. `portalWebArea`
    /// holds the composite web-view identity and the failure screen that keeps Skip reachable.
    @ViewBuilder
    func cardPortalStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        CardPortalView(
            model: CardPortalModel(
                title: localized("title", forStep: step, fallback: step.title),
                layout: portalLayout,
                displayURL: portalDisplayURL,
                isLoading: loadState == .loading || loadState == .initializing,
                footerText: branding.footerText,
                // Only when authored; the resolved default would pin the bar to the system background.
                footerBackground: branding.effectiveFooterBackgroundColor.map { Color(hex: $0) },
                footerTextColor: branding.effectiveFooterTextColor.map { Color(hex: $0) },
                // The card footer's resolver picks the dark-art variant in dark mode.
                logoPath: cardFooterLogoPath ?? branding.logoPath,
                accent: branding.primaryColor,
                doneText: portalDoneLabel,
                // Shown at any index when configured; `handlePortalBack()` decides what it does by position.
                backText: (config?.button2Visible ?? false) ? portalBackLabel : nil,
                skipText: step.skipButtonText,
                doneEnabled: portalAffordances.doneEnabled),
            scaleFactor: scaleFactor,
            onRefresh: refetch,
            onSkip: step.skipButtonText == nil ? nil : { goToNextStep() },
            onBack: (config?.button2Visible ?? false) ? { handlePortalBack() } : nil,
            onDone: { handleButton1() },
            stage: { portalWebArea })
        // Portal state lives on Preset5View and outlives the step, and `onAppear` fires once for this body,
        // so it is also reset on step change; otherwise a step shows the previous step's error.
        .onAppear { if isPortalStep { resetPortalStateForCurrentStep() } }
        .onChange(of: currentStep?.id) { _, _ in
            if isPortalStep { resetPortalStateForCurrentStep() }
        }
        .sourceTag()
    }

    /// Resets portal state for the current step; used on entry and on step change.
    /// loadState/portalLiveURL live on Preset5View, so they outlive the step that set them.
    func resetPortalStateForCurrentStep() {
        loadState = .initializing
        showContent = false
        portalLiveURL = nil
        setupPortal()
    }

    var portalDoneLabel: String {
        branding.button1Text ?? effectivePortalConfig?.button1Text ?? ChromeCopy.done
    }

    var portalBackLabel: String {
        // The portal's button2Text overrides the global branding value before BackDoor resolves it.
        BackDoor.label(localized: nil, step: nil,
                       branding: branding.button2Text ?? effectivePortalConfig?.button2Text)
    }

    /// Mid-flow, Back goes to the previous step. At index 0 (single-step self-service) it calls
    /// `handleButton2()`, which quits with exit code 2.
    func handlePortalBack() {
        if currentStepIndex > 0 {
            goToPreviousStep()
        } else {
            handleButton2()
        }
    }

    /// Icon base path: the override, else config.
    var effectiveIconBasePath: String? {
        dynamicState.iconBasePathOverride ?? inspectState.uiConfiguration.iconBasePath
    }

    // MARK: - Content Area

    /// The page plus at most one of the skeleton or the failure screen. No horizontal inset: a narrower
    /// viewport changes how the page lays out.
    @ViewBuilder
    var portalWebArea: some View {
        if let url = portalURL {
            ZStack {
                PortalWebView(
                    url: url,
                    openExternalLinksInBrowser: effectivePortalConfig?.openExternalLinksInBrowser ?? true,
                    onLoadStateChange: { state in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            loadState = state
                            if state == .loaded {
                                showContent = true
                            }
                        }
                    },
                    onNavigationError: { error in
                        writeLog("Preset5: Navigation error - \(error)", logLevel: .error)
                    },
                    onURLChange: { portalLiveURL = $0 }
                )
                // The identity includes step and URL: the coordinator's one-shot latches (`hasReportedError`,
                // `hasCompletedInitialLoad`) must not carry over between portal steps.
                .id("portal-\(currentStep?.id ?? "")-\(url.absoluteString)-\(portalViewId)")

                // No fade on the page; the skeleton covers it at the same size until it loads.
                if loadState == .loading || loadState == .initializing {
                    PortalSkeletonView(scaleFactor: scaleFactor)
                }

                if let failure = loadState.failure {
                    PortalFailureView(
                        failure: failure,
                        url: portalDisplayURL ?? url,
                        fallbackMessage: effectivePortalConfig?.fallbackMessage,
                        supportContact: effectivePortalConfig?.supportContact,
                        onRetry: {
                            loadState = .loading
                            portalViewId = UUID()
                            retryConnection()
                        },
                        scaleFactor: scaleFactor
                    )
                }
            }
        } else {
            noURLConfigured
        }
    }

    /// Missing-URL screen: a neutral line for the user; the key to add is logged (and shown in debug mode).
    var noURLConfigured: some View {
        VStack(spacing: 8) {
            Text("This page isn't available.")
                .font(.system(size: 16, weight: .semibold))
            // The fix is for the admin: shown in debug mode only, always logged.
            if appvars.debugMode {
                Text("Add `portalConfig.portalURL` (or `portalURLFile`) to this step.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            writeLog("Preset5: portal step has no URL; add portalConfig.portalURL (or portalURLFile)",
                     logLevel: .error)
        }
    }

}
