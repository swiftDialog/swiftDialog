//
//  GuidanceContentView.swift
//  dialog
//
//  The shared guidance block router used by every preset; per-block views live in Guidance Blocks/.
//  Generic over the context protocols, so nesting containers do not need `InspectState`.
//

import SwiftUI

// MARK: - Guidance Content View

/// Renders a step's guidance blocks; shared across all presets.
struct GuidanceContentView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let contentBlocks: [InspectConfig.GuidanceContent]
    let scaleFactor: CGFloat
    let iconBasePath: String?  // Optional base path for resolving relative image paths
    @ObservedObject var inspectState: Context
    let itemId: String
    let onOverlayTap: (() -> Void)?  // Optional callback when a block with opensOverlay=true is tapped
    /// Called with a bundle id when a `bundle-list` row's detail is opened; step navigation stays with the host.
    let onOpenSoftwareDetail: ((String) -> Void)?
    let accentColor: Color?              // Optional branded accent for icons, highlights and controls
    @Environment(\.palette) private var palette
    let contentAlignment: HorizontalAlignment  // Text block alignment (.leading default)
    /// The gap between stacked blocks. nil spaces by the `GuidanceBlockSpacing` ladder (see `stack(_:)`);
    /// a value is one flat, unscaled gap, for hosts that own their vertical rhythm (`plain-branded`).
    let blockSpacing: CGFloat?
    /// Horizontal placement of `image` blocks; `.center` except for `plain-branded`. Separate from
    /// `contentAlignment`, which applies to text only.
    let mediaAlignment: HorizontalAlignment
    /// The host's interaction-log dialect for form blocks, and any commit side effect. Default: 4-part item lines.
    let formWire: FormWire
    /// Per-line watch results for a "checklist" block, index-aligned with its `checklist` array.
    /// nil reads as no line satisfied; only lines that author `paths` consult it.
    let checklistLineSatisfied: [Bool]?
    @Environment(\.complianceAggregator) private var complianceAggregator

    init(contentBlocks: [InspectConfig.GuidanceContent], scaleFactor: CGFloat, iconBasePath: String? = nil, inspectState: Context, itemId: String, onOverlayTap: (() -> Void)? = nil, onOpenSoftwareDetail: ((String) -> Void)? = nil, accentColor: Color? = nil, contentAlignment: HorizontalAlignment = .leading, blockSpacing: CGFloat? = nil, mediaAlignment: HorizontalAlignment = .center, formWire: FormWire = FormWire(), checklistLineSatisfied: [Bool]? = nil) {
        self.contentBlocks = contentBlocks
        self.scaleFactor = scaleFactor
        self.iconBasePath = iconBasePath
        self.inspectState = inspectState
        self.itemId = itemId
        self.onOverlayTap = onOverlayTap
        self.onOpenSoftwareDetail = onOpenSoftwareDetail
        self.accentColor = accentColor
        self.contentAlignment = contentAlignment
        self.blockSpacing = blockSpacing
        self.mediaAlignment = mediaAlignment
        self.formWire = formWire
        self.checklistLineSatisfied = checklistLineSatisfied
    }

    /// The blocks to render, in authored order, minus `visible: false`. `canonicalizeStep` has already
    /// folded consecutive `comparison-table` blocks into one table.
    private var visibleBlocks: [InspectConfig.GuidanceContent] {
        let values = inspectState.userValues
        return cadenceResolved(contentBlocks.filter { $0.visible != false && ($0.showWhen?.matches(values) ?? true) }
            .map(InspectConfig.GuidanceContent.normalized))
    }

    /// Resolves measured cadence tokens (`{cadenceCount}` etc.). A conditional cast, since not every
    /// context owns a cadence.
    private func cadenceResolved(_ blocks: [InspectConfig.GuidanceContent]) -> [InspectConfig.GuidanceContent] {
        guard blocks.contains(where: CadenceTokens.mentioned(in:)),
              let cadence = inspectState as? CadenceContext else { return blocks }
        let key = inspectState.config?.localization?.selectionKey ?? "preferredLanguage"
        let language = inspectState.userValues[key].flatMap { $0.isEmpty ? nil : $0 }
        return blocks.map { CadenceTokens.resolve($0, monitor: cadence.cadenceMonitor, languageCode: language) }
    }

    var body: some View {
        arrangedBody
            .onAppear {
                inspectState.initializeGuidanceFormState(for: self.itemId)
                GuidanceSelectionKeys.logFallbacks(in: visibleBlocks)
                GuidanceAdvisories.warnOnceAboutSynonyms(in: contentBlocks, itemId: itemId)
            }
    }

    /// Media either takes the whole band or sits in the stack, never a shrunken thumbnail; `MediaArrangement` decides.
    @ViewBuilder
    private var arrangedBody: some View {
        let blocks = visibleBlocks
        switch MediaArrangement.resolve(blocks) {
        case .stacked:
            stack(blocks)

        case .fill(let index):
            // The picture takes the whole band; `Preset6View.footerBar` draws its caption.
            wrappedContentBlockView(for: blocks[index])
                .environment(\.mediaBandRole, .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .split(let mediaIndex):
            // Two equal flexible columns: "roughly half" at any content width.
            HStack(alignment: .top, spacing: 24 * scaleFactor) {
                wrappedContentBlockView(for: blocks[mediaIndex])
                    .environment(\.mediaBandRole, .split)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                stack(blocks.enumerated().filter { $0.offset != mediaIndex }.map(\.element))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// The block run, spaced by `GuidanceBlockSpacing`. Spacing is asymmetric around headings, so the stack
    /// runs at 0 and each block carries its own leading gap. An explicit `blockSpacing` wins.
    @ViewBuilder
    private func stack(_ blocks: [InspectConfig.GuidanceContent]) -> some View {
        if let blockSpacing {
            VStack(alignment: contentAlignment, spacing: blockSpacing) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    wrappedContentBlockView(for: block)
                }
            }
        } else {
            let gaps = GuidanceBlockSpacing.gaps(for: blocks)
            VStack(alignment: contentAlignment, spacing: 0) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    wrappedContentBlockView(for: block)
                        .padding(.top, index == 0 ? 0 : gaps[index - 1] * scaleFactor)
                }
            }
        }
    }

    /// The specimen frame sits outside the overlay wrap, so a framed block keeps its overlay and the
    /// frame encloses the chevron. `block.specimenNote` arrives already localized; the name never localizes.
    @ViewBuilder
    private func wrappedContentBlockView(for block: InspectConfig.GuidanceContent) -> some View {
        if block.wantsSpecimenFrame {
            SpecimenFrame(name: block.specimen ?? "",
                          note: block.specimenNote,
                          scaleFactor: scaleFactor) {
                overlayWrappedContentBlockView(for: block)
            }
        } else {
            overlayWrappedContentBlockView(for: block)
        }
    }

    /// Wraps a block with an overlay tap gesture when `opensOverlay` is true.
    @ViewBuilder
    private func overlayWrappedContentBlockView(for block: InspectConfig.GuidanceContent) -> some View {
        if block.opensOverlay == true, let onTap = onOverlayTap {
            contentBlockView(for: block)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.trailing, 8 * scaleFactor)
                }
                .help("Click for more details")
        } else {
            contentBlockView(for: block)
        }
    }

    /// Routes a block to its per-block view. Every arm is one small expression (type-check budget).
    @ViewBuilder
    private func contentBlockView(for block: InspectConfig.GuidanceContent) -> some View {
        let textColor = getTextColor(for: block)

        // Catalog rows are handled before the switch so it stays dispatch-only (see `DetailRowsBlock`).
        if block.type == "detail-rows" {
            if let rows = block.installItems, !rows.isEmpty {
                DetailRowsBlock(
                    rows: rows,
                    scaleFactor: scaleFactor,
                    iconBasePath: iconBasePath,
                    accentColor: accentColor ?? palette.accent,
                    itemId: itemId,
                    inspectState: inspectState
                )
            } else {
                GuidanceDebugHint(message: "detail-rows requires non-empty 'installItems' array", scaleFactor: scaleFactor)
            }
        } else {
        switch block.type {
        // `paragraph` is accepted as a synonym; `GuidanceAdvisories` points authors to `text`.
        case "text", "paragraph":
            GuidanceTextBlock(
                content: resolveTemplates(block.content ?? ""),
                isBold: block.bold ?? false,
                textColor: textColor,
                contentAlignment: contentAlignment,
                scaleFactor: scaleFactor
            )

        case "highlight":
            GuidanceHighlightBlock(content: block.content ?? "", scaleFactor: scaleFactor)

        case "arrow":
            GuidanceArrowBlock(content: block.content ?? "", textColor: textColor, accentColor: accentColor, scaleFactor: scaleFactor)

        case "warning":
            GuidanceCalloutBlock(content: block.content ?? "", style: .warning, scaleFactor: scaleFactor,
                                 rawStyle: block.style, title: block.title, iconOverride: block.icon)

        case "info":
            // Chip by default for info; any other `style` or a `title` draws the panel.
            // `GuidanceCalloutBlock.resolveForm` decides, from the raw `style` string.
            GuidanceCalloutBlock(content: block.content ?? "", style: .info, scaleFactor: scaleFactor,
                                 rawStyle: block.style, title: block.title, iconOverride: block.icon)

        case "success":
            GuidanceCalloutBlock(content: block.content ?? "", style: .success, scaleFactor: scaleFactor,
                                 rawStyle: block.style, title: block.title, iconOverride: block.icon)

        case "prose":
            GuidanceProseBlock(content: resolveTemplates(block.content ?? ""),
                               placeholder: block.placeholder,
                               streaming: GuidanceProseBlock.streaming(from: block.state),
                               scaleFactor: scaleFactor)

        case "explainer":
            GuidanceExplainerBlock(
                content: resolveTemplates(block.content ?? ""),
                style: block.style,
                icon: block.icon,
                accentColor: accentColor,
                scaleFactor: scaleFactor,
                label: block.label.map { resolveTemplates($0) }
            )

        case "bullets":
            GuidanceBulletsBlock(
                items: block.items,
                numbered: block.numbered == true,
                icon: block.icon,
                accentColor: accentColor,
                scaleFactor: scaleFactor,
                style: block.style
            )

        case "stat-row":
            if let stats = block.stats, !stats.isEmpty {
                GuidanceStatRowBlock(stats: stats, scaleFactor: scaleFactor, style: block.style)
            } else {
                GuidanceDebugHint(message: "stat-row requires non-empty 'stats' array", scaleFactor: scaleFactor)
            }

        case "checklist":
            if let lines = block.checklist, !lines.isEmpty {
                let satisfied = checklistLineSatisfied ?? Array(repeating: false, count: lines.count)
                let states = ChecklistState.resolve(lines: lines, satisfied: satisfied)
                GuidanceChecklistBlock(lines: lines, states: states, accentColor: accentColor, scaleFactor: scaleFactor)
            } else {
                GuidanceDebugHint(message: "checklist requires non-empty 'checklist' array", scaleFactor: scaleFactor)
            }

        case "label-value":
            GuidanceLabelValueBlock(
                block: block,
                resolvedContent: resolveTemplates(block.content ?? ""),
                scaleFactor: scaleFactor
            )

        case "image":
            GuidanceImageBlock(block: block, iconBasePath: iconBasePath, accentColor: accentColor,
                               scaleFactor: scaleFactor, contentAlignment: mediaAlignment)

        case "video":
            GuidanceVideoBlock(block: block, scaleFactor: scaleFactor)

        case "webcontent":
            GuidanceWebContentBlock(block: block, accentColor: accentColor, scaleFactor: scaleFactor)

        case "portal-webview":
            GuidancePortalWebViewBlock(
                block: block,
                // A block-level `portalConfig` overrides the global one.
                portalConfig: block.portalConfig ?? inspectState.config?.portalConfig,
                accentColor: accentColor,
                scaleFactor: scaleFactor
            )

        case "form-section":
            GuidanceFormSectionBlock(block: block, scaleFactor: scaleFactor)

        case "checkbox":
            GuidanceCheckboxBlock(block: block, itemId: itemId, inspectState: inspectState, accentColor: accentColor, scaleFactor: scaleFactor, wire: formWire)

        case "dropdown":
            GuidanceDropdownBlock(block: block, itemId: itemId, inspectState: inspectState, accentColor: accentColor, scaleFactor: scaleFactor, wire: formWire, iconBasePath: iconBasePath)

        case "radio":
            GuidanceRadioBlock(block: block, itemId: itemId, inspectState: inspectState, accentColor: accentColor, scaleFactor: scaleFactor, wire: formWire)

        case "toggle":
            GuidanceToggleBlock(block: block, itemId: itemId, inspectState: inspectState, accentColor: accentColor, scaleFactor: scaleFactor, wire: formWire)

        case "slider":
            GuidanceSliderBlock(block: block, itemId: itemId, inspectState: inspectState, accentColor: accentColor, scaleFactor: scaleFactor, wire: formWire)

        case "textfield":
            GuidanceTextFieldBlock(block: block, itemId: itemId, inspectState: inspectState, scaleFactor: scaleFactor, wire: formWire)

        case "drop-zone":
            GuidanceDropZoneBlock(block: block, itemId: itemId, inspectState: inspectState, scaleFactor: scaleFactor)

        case "color-picker":
            GuidanceColorPickerBlock(block: block, itemId: itemId, inspectState: inspectState, scaleFactor: scaleFactor)

        case "advisory":
            GuidanceAdvisoryBlock(block: block, accentColor: accentColor, scaleFactor: scaleFactor, iconBasePath: iconBasePath)

        case "segmented":
            GuidanceSegmentedBlock(block: block, itemId: itemId, inspectState: inspectState, accentColor: accentColor, scaleFactor: scaleFactor, wire: formWire)

        case "stepper":
            GuidanceStepperBlock(block: block, itemId: itemId, inspectState: inspectState, accentColor: accentColor, scaleFactor: scaleFactor)

        case "search":
            GuidanceSearchBlock(block: block, itemId: itemId, inspectState: inspectState, accentColor: accentColor, scaleFactor: scaleFactor)

        case "multi-select":
            GuidanceMultiSelectBlock(block: block, itemId: itemId, inspectState: inspectState, accentColor: accentColor, scaleFactor: scaleFactor)

        // Identity header card, live signature preview, status rows with action pills.
        case "identity":
            GuidanceIdentityBlock(block: block, scaleFactor: scaleFactor,
                                  accentColor: accentColor, iconBasePath: iconBasePath)
        case "signature-preview":
            GuidanceSignaturePreviewBlock(block: block, itemId: itemId,
                                          inspectState: inspectState,
                                          scaleFactor: scaleFactor, iconBasePath: iconBasePath)
        case "action-rows":
            GuidanceActionRowsBlock(block: block, itemId: itemId, inspectState: inspectState,
                                    accentColor: accentColor, scaleFactor: scaleFactor,
                                    iconBasePath: iconBasePath)

        // The check-row list and the 2-up tile grid, one storage model.
        case "select-list", "select-grid":
            GuidanceSelectBlock(block: block, itemId: itemId, inspectState: inspectState,
                                accentColor: accentColor, scaleFactor: scaleFactor,
                                iconBasePath: iconBasePath)

        case "button":
            GuidanceActionButtonBlock(block: block, itemId: itemId, inspectState: inspectState, accentColor: accentColor, scaleFactor: scaleFactor)

        case "status-badge":
            // `content` is accepted as the label when `label` is absent.
            if let label = block.label ?? block.content, let state = block.state {
                let autoColor = block.autoColor ?? true
                let customColor: Color? = {
                    if let colorHex = block.color {
                        return Color(hex: colorHex)
                    }
                    return nil
                }()

                StatusBadgeView(
                    label: label,
                    state: state,
                    actual: block.actual,
                    icon: block.icon,
                    autoColor: autoColor,
                    customColor: customColor,
                    scaleFactor: scaleFactor,
                    iconBasePath: iconBasePath
                )
                .id("status-badge-\(label)-\(state)-\(block.actual ?? "")")
            } else {
                GuidanceDebugHint(message: "status-badge requires 'label' and 'state' properties", scaleFactor: scaleFactor)
            }

        case "comparison-table":
            // `checks` draws one table with its headers once.
            if let checks = block.checks, !checks.isEmpty {
                ComparisonChecksTable(
                    label: block.label,
                    requiredLabel: block.expectedLabel,
                    foundLabel: block.actualLabel,
                    checks: checks,
                    accentColor: accentColor ?? palette.accent,
                    scaleFactor: scaleFactor
                )
            // Scalar `expected`/`actual` are folded into `checks[]` by `canonicalizeStep`, so only the plural arrives.
            } else {
                GuidanceDebugHint(message: "comparison-table requires 'checks' (or 'expected'/'actual', which fold into it)", scaleFactor: scaleFactor)
            }

        case "phase-tracker":
            if let currentPhase = block.currentPhase,
               let phases = block.phases, !phases.isEmpty {
                PhaseTrackerView(
                    currentPhase: currentPhase,
                    phases: Array(phases),
                    style: block.style ?? "stepper",
                    scaleFactor: scaleFactor,
                    caption: block.label,
                    progress: block.progress
                )
                .id("phase-tracker-\(currentPhase)")
            } else {
                GuidanceDebugHint(message: "phase-tracker requires 'currentPhase' and 'phases' properties", scaleFactor: scaleFactor)
            }

        case "progress-bar":
            GuidanceProgressBarBlock(block: block, scaleFactor: scaleFactor, accentColor: accentColor)

        case "image-carousel":
            if let images = block.images, !images.isEmpty {
                ImageCarouselView(
                    images: images,
                    iconBasePath: iconBasePath,
                    scaleFactor: scaleFactor,
                    imageWidth: CGFloat(block.imageWidth ?? 400),
                    imageHeight: CGFloat(block.imageHeight ?? 300),
                    imageShape: block.imageShape ?? "rectangle",
                    // "fill" is the view's default, kept for carousels that author no `imageFit`.
                    imageFit: block.imageFit ?? "fill",
                    showDots: block.showDots ?? true,
                    showArrows: block.showArrows ?? true,
                    captions: block.captions,
                    autoAdvance: block.autoAdvance ?? false,
                    autoAdvanceDelay: block.autoAdvanceDelay ?? 3.0,
                    transitionStyle: block.transitionStyle ?? "slide",
                    currentIndex: block.currentIndex ?? 0
                )
                .id("carousel-\(images.joined(separator: ","))-\(block.currentIndex ?? 0)")
            } else {
                GuidanceDebugHint(message: "image-carousel requires 'images' array with at least one image path", scaleFactor: scaleFactor)
            }

        case "feature-table":
            if let columns = block.columns, !columns.isEmpty,
               let rows = block.rows, !rows.isEmpty {
                FeatureTableView(
                    columns: columns,
                    rows: rows,
                    style: block.style,
                    scaleFactor: scaleFactor,
                    label: block.label
                )
            } else {
                GuidanceDebugHint(message: "feature-table requires non-empty 'columns' and 'rows' arrays", scaleFactor: scaleFactor)
            }

        case "option-picker":
            // Guided-setup default-app / appearance chooser.
            if let cards = block.optionCards, !cards.isEmpty {
                OptionPickerView(
                    cards: cards,
                    selectionKey: GuidanceSelectionKeys.resolvedKey(for: block) ?? "option",
                    multiSelect: block.optionMultiSelect ?? false,
                    layout: OptionPickerLayout(block.optionLayout),
                    confirmButtonText: block.optionConfirmButton,
                    preferenceKey: block.optionPreferenceKey,
                    scaleFactor: scaleFactor,
                    // The colour this payload was handed, not the config key the pill draws from.
                    tint: accentColor,
                    inspectState: inspectState,
                    itemId: itemId
                )
            } else {
                GuidanceDebugHint(message: "option-picker requires non-empty 'optionCards' array", scaleFactor: scaleFactor)
            }

        case "media-carousel":
            // Mixed-media carousel (`IntroMediaCarousel`): images, GIFs, video and YouTube/Vimeo embeds.
            // `image-carousel` remains the images-only block.
            if let mediaItems = block.mediaItems, !mediaItems.isEmpty {
                IntroMediaCarousel(
                    items: mediaItems,
                    height: CGFloat(block.mediaHeight ?? 400) * scaleFactor,
                    autoplay: block.mediaAutoplay ?? true,
                    showArrows: block.mediaShowArrows ?? true,
                    showDots: block.mediaShowDots ?? true,
                    accentColor: accentColor ?? palette.accent,
                    fit: MediaFit(block.mediaFit)
                )
            } else {
                GuidanceDebugHint(message: "media-carousel requires non-empty 'mediaItems' array", scaleFactor: scaleFactor)
            }

        case "grid-picker":
            // Renders the grid (`IntroGridPicker`, honouring `gridColumns`); see `GuidanceGridPickerBlock`.
            if let gridItems = block.gridItems, !gridItems.isEmpty {
                GuidanceGridPickerBlock(
                    items: gridItems,
                    columns: block.gridColumns ?? 3,
                    selectionMode: block.gridSelectionMode ?? "single",
                    selectionKey: GuidanceSelectionKeys.resolvedKey(for: block) ?? "grid",
                    accentColor: accentColor ?? palette.accent,
                    inspectState: inspectState
                )
            } else {
                GuidanceDebugHint(message: "grid-picker requires non-empty 'gridItems' array", scaleFactor: scaleFactor)
            }

        case "slot-picker":
            // A continuous slot-before-deadline strip. The view validates the deadline; invalid configs render nothing.
            SlotPickerView(
                block: block,
                inspectState: inspectState,
                accentColor: accentColor,
                scaleFactor: scaleFactor
            )

        case "dock-picker":
            // Guided-setup dock chooser / builder.
            if (block.dockFlavors?.isEmpty == false) || (block.dockItems?.isEmpty == false) {
                DockPickerView(
                    mode: block.dockMode ?? "flavors",
                    flavors: block.dockFlavors ?? [],
                    items: block.dockItems ?? [],
                    selectionKey: GuidanceSelectionKeys.resolvedKey(for: block) ?? "dock",
                    confirmButtonText: block.dockConfirmButton,
                    showUnavailable: block.dockShowUnavailable ?? false,
                    // Pass everything the block model carries, so `dockDecline` actually renders.
                    decline: block.dockDecline,
                    applyMode: block.dockApplyMode ?? "additive",
                    scaleFactor: scaleFactor,
                    // The colour this payload was handed.
                    tint: accentColor,
                    layout: block.dockLayout,
                    inspectState: inspectState,
                    itemId: itemId
                )
            } else {
                GuidanceDebugHint(message: "dock-picker requires non-empty 'dockFlavors' or 'dockItems'", scaleFactor: scaleFactor)
            }

        case "install-list":
            if let installItems = block.installItems, !installItems.isEmpty {
                GuidanceInstallListBlock(
                    installItems: installItems,
                    completedItems: inspectState.completedItems,
                    downloadingItems: inspectState.downloadingItems,
                    iconBasePath: iconBasePath,
                    scaleFactor: scaleFactor,
                    // `cards` or `manifest`; absent draws `.rows`.
                    layout: InstallListLayout(block.installLayout),
                    accentColor: accentColor ?? palette.accent
                )
            } else {
                GuidanceDebugHint(message: "install-list requires non-empty 'installItems' array", scaleFactor: scaleFactor)
            }

        default:
            Text(block.content ?? "")
                .font(.system(size: 13 * scaleFactor))
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        }
    }

    // MARK: - Helpers

    private func resolveTemplates(_ content: String) -> String {
        GuidanceTemplateResolver.resolve(content, formInputs: inspectState.guidanceFormInputs)
    }

    private func getTextColor(for block: InspectConfig.GuidanceContent) -> Color {
        if let colorHex = block.color {
            return Color(hex: colorHex)
        }
        return .primary
    }

    /// Resolves a `compliance-card`: the category (`content` or `categoryName`) takes live counts from
    /// `plistSources` when it matches, else the authored values. Kept out of the ViewBuilder.
    private func complianceCardData(for block: InspectConfig.GuidanceContent)
        -> (name: String, passed: Int, total: Int, details: String?)? {
        guard let name = block.categoryName ?? block.content, !name.isEmpty else { return nil }

        if let live = complianceAggregator?.category(named: name) {
            // maxItems 500, so a real baseline is never silently truncated.
            let details = complianceAggregator?.checkDetails(for: name, maxItems: 500)
            return (name, live.passed, live.total, details ?? block.checkDetails)
        }

        guard let passed = block.passed, let total = block.total else { return nil }
        return (name, passed, total, block.checkDetails)
    }

    /// Same shape for `compliance-header`: authored counts, or the aggregator's totals when
    /// `plistSources` is configured and the config named none.
    private func complianceHeaderData(for block: InspectConfig.GuidanceContent)
        -> (passed: Int, total: Int)? {
        if let passed = block.passed, let total = block.total {
            return (passed, total)
        }
        if let aggregator = complianceAggregator, !aggregator.categories.isEmpty {
            return (aggregator.totalPassed, aggregator.totalChecks)
        }
        return nil
    }
}

// MARK: - Debug Hint

/// Red italic config-error hint, debug mode only, so each switch arm stays one expression.
struct GuidanceDebugHint: View {
    let message: String
    let scaleFactor: CGFloat

    var body: some View {
        if appvars.debugMode {
            Text(message)
                .font(.system(size: 11 * scaleFactor))
                .foregroundStyle(.red)
                .italic()
        }
    }
}

// MARK: - Authoring advisories

/// Advisories for blocks that render correctly but not canonically. Never gates a render.
enum GuidanceAdvisories {

    /// Once per item id per session, since Back can revisit a step.
    private static let warnedItemIds = LockedValue(Set<String>())

    static func warnOnceAboutSynonyms(in blocks: [InspectConfig.GuidanceContent], itemId: String) {
        guard !warnedItemIds.value.contains(itemId) else { return }
        let paragraphs = blocks.filter { $0.type == "paragraph" }.count
        let aliasedText = blocks.filter { $0.content == nil && $0.text?.isEmpty == false }.count
        guard paragraphs > 0 || aliasedText > 0 else { return }
        warnedItemIds.withLock { _ = $0.insert(itemId) }
        if paragraphs > 0 {
            writeLog("guidance: \(paragraphs) block(s) on '\(itemId)' use type \"paragraph\" — it "
                     + "renders as \"text\", which is the spelling the schema documents.",
                     logLevel: .info)
        }
        if aliasedText > 0 {
            writeLog("guidance: \(aliasedText) block(s) on '\(itemId)' author \"text\" — it is read "
                     + "as \"content\", which is the spelling the schema documents.",
                     logLevel: .info)
        }
    }

    /// Test seam: resets the once-per-session record.
    static func resetForTesting() { warnedItemIds.value = [] }
}
