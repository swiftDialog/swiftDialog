//
//  Preset5+CardSubsteps.swift
//  dialog
//
//  Substep and selection content, shared by several arms.
//

import SwiftUI

extension Preset5View {
    /// One substep's content: icon, title, text, optional media, optional action button.
    @ViewBuilder
    /// Leading-aligned on the card's own text edge; `ContentStance` does not reach this view.
    func substepContent(_ sub: InspectConfig.SubStep) -> some View {
        let layout = MediaLayout.resolve(sub.mediaLayout)
        let hasMedia = !(sub.media ?? "").isEmpty
        // A split with nothing beside the picture falls back to fill, as blocks do.
        let hasCompany = sub.title != nil || sub.text != nil || sub.sfSymbol != nil
            || !(sub.iconPath ?? "").isEmpty
        let effective: MediaLayout = (layout == .split && !hasCompany) ? .fill : layout

        Group {
            if hasMedia, effective == .split {
                // Two flexible columns, as GuidanceContentView's split. No infinite height on the
                // picture: inside this ScrollView it would terminate the app.
                HStack(alignment: .top, spacing: 24) {
                    substepMedia(sub.media ?? "", loop: sub.mediaLoop ?? false, layout: .split)
                        .frame(maxWidth: .infinity)
                    substepTextColumn(sub)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    substepTextColumn(sub)
                    if hasMedia {
                        substepMedia(sub.media ?? "", loop: sub.mediaLoop ?? false, layout: effective)
                            .frame(maxWidth: effective == .fill ? .infinity : nil,
                                   alignment: .leading)
                    }
                }
            }
        }
    }

    /// Everything on a substep that is not the picture; one column for all three arrangements.
    @ViewBuilder
    func substepTextColumn(_ sub: InspectConfig.SubStep) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let iconPath = sub.iconPath, !iconPath.isEmpty {
                Image(nsImage: NSWorkspace.shared.icon(forFile: (iconPath as NSString).expandingTildeInPath))
                    .resizable().scaledToFit().frame(width: 56, height: 56)
            } else if let sf = sub.sfSymbol {
                Image(systemName: sf).font(.system(size: 40)).foregroundStyle(branding.primaryColor)
            }

            if let title = sub.title {
                Text(title).font(.system(size: 18, weight: .semibold)).multilineTextAlignment(.leading)
            }
            if let text = sub.text {
                Text(guidanceAttributedMarkdown(text)).font(.system(size: 13)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            if let action = sub.action, action != "none",
               let label = sub.actionButtonText {
                Button(label) { runSubstepAction(sub) }
                    .buttonStyle(.borderedProminent).tint(branding.primaryColor).controlSize(.large)
                    .padding(.top, 2)
            }
        }
    }

    /// The picture, sized for its layout. `inline` keeps the 280×200 box so older substeps render
    /// unchanged; `split` and `fill` take the width they are given.
    @ViewBuilder
    func substepMedia(_ path: String, loop: Bool, layout: MediaLayout = .inline) -> some View {
        let lower = path.lowercased()
        // Finite widths only: AsyncImageView converts maxWidth to Int for its cache key, and
        // infinity traps.
        let maxH: CGFloat = layout == .inline ? 200 : (layout == .split ? 300 : 340)
        let maxW: CGFloat = layout == .inline ? 280 : (layout == .split ? 380 : 660)
        if [".mov", ".mp4", ".m4v"].contains(where: lower.hasSuffix) {
            AspectFitVideoView(videoPath: resolvedMediaPath(path), autoPlay: true, caption: "", maxHeight: maxH, loop: loop)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        } else if lower.hasSuffix(".gif") {
            AsyncImageView(iconPath: resolvedMediaPath(path), basePath: nil, maxWidth: maxW, maxHeight: maxH, imageFit: .fit, fallback: { EmptyView() })
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        } else if let img = InspectImageCache.shared.image(atPath: resolvedMediaPath(path)) {
            Image(nsImage: img).resizable().scaledToFit().frame(maxHeight: maxH)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
    }

    /// Resolves a relative media path against the icon base path.
    func resolvedMediaPath(_ path: String) -> String {
        if path.hasPrefix("/") || path.hasPrefix("http") { return path }
        let base = effectiveIconBasePath ?? ""
        return base.isEmpty ? path : (base as NSString).appendingPathComponent(path)
    }

    /// Runs a substep's action: a `request` over IPC, a URL, or an app path. Never shells out.
    func runSubstepAction(_ sub: InspectConfig.SubStep) {
        guard let action = sub.action else { return }
        switch action {
        case "url":
            if let urlStr = sub.url, let url = URL(string: urlStr) { NSWorkspace.shared.open(url) }
        case "request":
            let rid = sub.requestId ?? sub.id
            inspectState.writeToInteractionLog("request:\(rid):\(sub.id):0")
            DialogNotifications.postSelection(key: "request", values: [rid])
        default:
            if action.hasSuffix(".app"), FileManager.default.fileExists(atPath: action) {
                NSWorkspace.shared.open(URL(fileURLWithPath: action))
            }
        }
    }


    func saveBrandSelection() {
        guard let brandId = selectedBrandId else { return }
        let key = config?.brandSelectionKey ?? "selectedBrand"
        stateDefaults.set(brandId, forKey: key)
        preferencesService?.setValue(brandId, forKey: key)
        writeLog("Preset5: Saved brand selection '\(brandId)' to key '\(key)'", logLevel: .info)
    }

    /// Content blocks under a selection picker, shared by the chooser arms.
    @ViewBuilder
    func selectionStepContent(step: InspectConfig.IntroStep) -> some View {
        if let blocks = step.content, !blocks.isEmpty {
            GuidanceContentView(
                contentBlocks: blocks,
                scaleFactor: 1.0,
                iconBasePath: effectiveIconBasePath,
                inspectState: inspectState,
                itemId: step.id,
                onOverlayTap: nil,
                accentColor: branding.primaryColor,
                // Centred on the picker's own axis.
                contentAlignment: .center
            )
            .frame(maxWidth: metrics.contentMaxW)
        }
    }
}
