//
//  Preset5+CardChooser.swift
//  dialog
//
//  The chooser arms: option / wallpaper / brand / dock pickers inside the card shell.
//

import SwiftUI

extension Preset5View {
    /// The chooser arm: card chrome around the shared picker components. Uses CardStepShell
    /// directly because the pickers are stateful, not block lists.
    @ViewBuilder
    func cardChooserStepView(step: InspectConfig.IntroStep, stepIndex: Int, arm: CardArm) -> some View {
        let brands = resolvedAvailableBrands
        if arm == .chooserBrands && brands.count <= 1 {
            // Nothing to pick: run the side effects and advance without mounting a grid.
            Color.clear
                .onAppear {
                    if let only = brands.first {
                        selectedBrandId = only.id
                        saveBrandSelection()
                    }
                    goToNextStep()
                }
        } else {
            CardStepShell(
                eyebrow: config?.title,
                eyebrowIcon: config?.icon,
                stepLabel: cardStepLabel(stepIndex),
                hero: cardHero(step),
                title: localized("title", forStep: step, fallback: step.title) ?? "",
                subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
                accent: branding.primaryColor,
                // Continue stays disabled until a brand is chosen; the choice is saved on Continue.
                footer: cardFooter(for: step, index: stepIndex,
                                   continueDisabled: arm == .chooserBrands && selectedBrandId == nil,
                                   autoClose: cardAutoClose(step)) {
                    if arm == .chooserBrands { saveBrandSelection() }
                    openCardContinueActionURL(step.continueAction)
                    goToNextStep()
                }
            ) {
                // An options picker with a confirm button scrolls itself and pins the button to
                // its own viewport; wrapping it again would push the button below the fold.
                let pickerOwnsScrolling = (arm == .chooserOptions && step.optionConfirmButton != nil)
                Group {
                    if pickerOwnsScrolling {
                        chooserPayloadStack(step: step, arm: arm)
                    } else {
                        // The fade shows there is more, since macOS hides the scrollbar at rest.
                        ScrollWithHint { chooserPayloadStack(step: step, arm: arm) }
                    }
                }
            }
            .sourceTag()
        }
    }

    nonisolated static let brandAllowListNoteOne =
        "1 other brand exists but is not in your managed allow-list, so it is hidden rather than greyed out."
    nonisolated static let brandAllowListNoteMany =
        "{n} other brands exist but are not in your managed allow-list, so they are hidden rather than greyed out."

    /// The allow-list note for hidden brands: a whole singular or plural sentence, so every
    /// language pack can agree verb and pronoun with the count. `{n}` is replaced by the count.
    nonisolated static func brandAllowListNote(hidden: Int,
                                               one: String = brandAllowListNoteOne,
                                               many: String = brandAllowListNoteMany) -> String {
        (hidden == 1 ? one : many).replacingOccurrences(of: "{n}", with: "\(hidden)")
    }

    /// The chooser arm's body, shared by the scrolled and self-scrolling containers.
    @ViewBuilder
    private func chooserPayloadStack(step: InspectConfig.IntroStep, arm: CardArm) -> some View {
                    VStack(alignment: .leading, spacing: 16) {
                        cardChooserPayload(step: step, arm: arm)
                        if arm == .chooserBrands, let hidden = hiddenBrandCount, hidden > 0 {
                            Text(Self.brandAllowListNote(
                                hidden: hidden,
                                one: localizedUI("brandAllowListNoteOne", fallback: Self.brandAllowListNoteOne),
                                many: localizedUI("brandAllowListNote", fallback: Self.brandAllowListNoteMany)))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        selectionStepContent(step: step)
                    }
    }

    @ViewBuilder
    private func cardChooserPayload(step: InspectConfig.IntroStep, arm: CardArm) -> some View {
        switch arm {
        case .chooserOptions:
            OptionPickerView(
                cards: localizedOptionCards(for: step),
                selectionKey: step.optionKey ?? step.id,
                multiSelect: step.optionMultiSelect ?? false,
                layout: OptionPickerLayout(step.optionLayout),
                confirmButtonText: step.optionConfirmButton,
                preferenceKey: step.optionPreferenceKey,
                scaleFactor: 1.0,
                centered: false,
                inspectState: inspectState,
                itemId: step.id
            )
        case .chooserWallpaper:
            // `wallpaper.layout` is folded into this flat key by canonicalizeStep. The default is
            // `categories`, the same as the block arm's.
            let layoutMode: WallpaperLayout = {
                switch step.wallpaperLayout?.lowercased() {
                case "row": return .row
                case "grid": return .grid
                default: return .categories
                }
            }()
            WallpaperPickerView(
                categories: step.wallpaperCategories ?? [],
                columns: 4,
                imageFit: "fill",
                // 88 and 0 are the block arm's defaults; one default per key.
                thumbnailHeight: step.wallpaperThumbnailHeight ?? 88,
                selectionKey: step.wallpaperSelectionKey ?? step.id,
                showPath: step.wallpaperShowPath ?? false,
                confirmButtonText: step.wallpaperConfirmButton,
                multiSelectCount: step.wallpaperMultiSelect ?? 0,
                scaleFactor: 1.0,
                centered: false,
                layout: layoutMode,
                inspectState: inspectState,
                itemId: step.id
            )
        case .chooserBrands:
            // The same row builders as the provisioning arm, so both hosts read brands alike.
            ProvisioningRowStack(
                rows: ProvisioningRowBuilder.brandRows(brands: resolvedAvailableBrands,
                                                       selectedId: selectedBrandId,
                                                       scheme: colorScheme),
                width: nil,
                accent: branding.primaryColor,
                onSelect: { selectedBrandId = $0 }
            )
        case .chooserDock:
            DockPickerView(
                mode: step.dockMode ?? "flavors",
                flavors: step.dockFlavors ?? [],
                items: step.dockItems ?? [],
                selectionKey: step.dockSelectionKey ?? step.id,
                confirmButtonText: step.dockConfirmButton,
                showUnavailable: step.dockShowUnavailable ?? false,
                decline: step.dockDecline,
                applyMode: step.dockApplyMode ?? "additive",
                scaleFactor: 1.0,
                centered: false,
                layout: step.dockLayout,
                inspectState: inspectState,
                itemId: step.id
            )
        default:
            EmptyView()
        }
    }
}
