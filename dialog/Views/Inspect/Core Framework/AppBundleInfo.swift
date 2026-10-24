//
//  AppBundleInfo.swift
//  dialog
//
//  Identity, version and signing team of an app bundle, read when an app is dropped on a drop zone.
//

import Foundation
import Security

struct AppBundleInfo: Codable, Equatable, Sendable {
    let path: String
    let name: String
    let bundleId: String?
    let version: String?
    let build: String?
    /// The signing team (Developer ID / App Store), from the code signature; nil when unsigned.
    let teamId: String?
    let minimumSystemVersion: String?

    /// Read a bundle on disk; nil when the path is not a bundle.
    static func read(_ path: String) -> AppBundleInfo? {
        let expanded = (path as NSString).expandingTildeInPath
        guard let bundle = Bundle(path: expanded), let info = bundle.infoDictionary else { return nil }
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? ((expanded as NSString).lastPathComponent as NSString).deletingPathExtension
        return AppBundleInfo(path: expanded, name: name,
                             bundleId: bundle.bundleIdentifier,
                             version: info["CFBundleShortVersionString"] as? String,
                             build: info["CFBundleVersion"] as? String,
                             teamId: teamIdentifier(of: expanded),
                             minimumSystemVersion: info["LSMinimumSystemVersion"] as? String)
    }

    /// One line for a chip or a card: `<bundleId> · <version>`.
    var summary: String {
        [bundleId, version].compactMap { $0 }.joined(separator: " · ")
    }

    private static func teamIdentifier(of path: String) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code) == errSecSuccess,
              let code else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
