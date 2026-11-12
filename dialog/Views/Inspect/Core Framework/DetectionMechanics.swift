//
//  DetectionMechanics.swift
//
//  What each log preset's delivery mechanic cannot tell you, shown by `--inspect-lint --explain` under a
//  log monitor that uses that preset.
//

import Foundation

enum DetectionMechanic: String, CaseIterable {
    case munki, jamf, installomator, orbit

    var caveat: String {
        switch self {
        case .munki:
            return "munki's success line does not name the item, so a finished install is matched to "
                 + "the item munki was working on, not to the line's text."
        case .jamf:
            return "the jamf preset reads policy lines only; jamf may not log each install step, so "
                 + "per-item progress may not appear."
        case .installomator, .orbit:
            return "no download cache is known for it, so progress comes from its log, not from files "
                 + "on disk."
        }
    }
}
