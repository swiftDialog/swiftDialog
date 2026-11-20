//
//  CardArm.swift
//  dialog
//
//  Which card arm renders a step, and the top-band conflict map built on it; pure, so the
//  window sizing can ask without a view.
//

import SwiftUI

/// Which card arm renders a step. Payload beats stepType: a step carrying
/// `wallpaperCategories` is a wallpaper chooser whatever it calls itself.
enum CardArm: Equatable {
    case prose, media, processing, outro
    case chooserOptions, chooserWallpaper, chooserBrands, chooserDock
    case substepsWizard
    case export
    case carousel, bento

    static func of(_ step: InspectConfig.IntroStep) -> CardArm {
        // Payload beats stepType, in the legacy renderer's presence order (wallpaper, options, dock).
        if step.wallpaperCategories?.isEmpty == false { return .chooserWallpaper }
        if step.optionCards?.isEmpty == false { return .chooserOptions }
        if (step.dockFlavors?.isEmpty == false) || (step.dockItems?.isEmpty == false) {
            return .chooserDock
        }
        switch step.resolvedStepType {
        case "options":     return .chooserOptions
        case "wallpaper":   return .chooserWallpaper
        case "brandPicker": return .chooserBrands
        case "dock":        return .chooserDock
        case "substeps":    return .substepsWizard
        case "export":      return .export
        case "carousel":    return .carousel
        case "bento":       return .bento
        case "media":       return .media
        case "processing":  return .processing
        case "outro":       return .outro
        case "standard":
            // Phase decides, as in the legacy renderer: an outro-phase standard step is the closer
            // and must draw the completion badge, receipt and failure listing.
            return step.resolvedPhase == "outro" ? .outro : .prose
        default:            return .prose      // intro + guide + assistant
        }
    }
}

/// The first step whose arm cannot carry the band: full-bleed pickers and arms that own
/// their own top geometry block; prose, outro, processing, options and dock carry it.
func topBandBlockingStep(in steps: [InspectConfig.IntroStep], claim: Bool) -> InspectConfig.IntroStep? {
    _ = claim   // kept in the signature; tests pin both flavours
    return steps.first { s in
        switch CardArm.of(s) {
        case .prose, .outro, .processing, .chooserOptions, .chooserDock:
            return false
        default:
            return true
        }
    }
}
