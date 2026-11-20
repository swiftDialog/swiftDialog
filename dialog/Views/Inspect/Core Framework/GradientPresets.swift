//
//  GradientPresets.swift
//  dialog
//
//  Bundled two-stop gradients (`gradients.json`) referenced by id, e.g. `"phaseBackgroundPalette": ["preset:g09"]`.
//  `expandReferences(in:)` expands them to hex before decoding; `…Dark` keys take `darkColors`.
//

import Foundation

enum GradientPresets {

    struct Preset: Decodable, Equatable {
        let id: String
        let colors: [String]
        let darkColors: [String]
    }

    static let prefix = "preset:"

    /// Palette keys that take a preset's `colors`, at any depth of the config.
    static let lightKeys: Set<String> = ["phaseBackgroundPalette", "gradientColors", "gradientPalette",
                                         "showcaseGradientColors"]
    /// Palette keys that take its `darkColors`.
    static let darkKeys: Set<String> = ["phaseBackgroundPaletteDark"]

    private struct File: Decodable { let gradients: [Preset] }

    /// The bundled set; empty when the resource is missing, which turns every reference into an
    /// unknown one for lint to name rather than a crash.
    static let all: [Preset] = {
        guard let url = Bundle.main.url(forResource: "gradients", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.gradients
    }()

    static var ids: [String] { all.map(\.id) }

    /// The stops a `preset:gNN` reference names, or nil when it is not a reference to a known one.
    static func stops(_ ref: String, dark: Bool) -> [String]? {
        guard ref.hasPrefix(prefix) else { return nil }
        let id = String(ref.dropFirst(prefix.count))
        guard let preset = all.first(where: { $0.id == id }) else { return nil }
        return dark ? preset.darkColors : preset.colors
    }

    /// A palette with each reference replaced by its stops; hex entries and unknown references
    /// pass through (lint names the latter).
    static func expand(_ palette: [String], dark: Bool) -> [String] {
        palette.flatMap { stops($0, dark: dark) ?? [$0] }
    }

    /// The whole config with every reference expanded, by key name, at any depth — so a step's
    /// `showcase.gradientColors` and a bento cell's `gradientPalette` resolve like the root keys.
    static func expandReferences(in json: Any) -> Any {
        if let dict = json as? [String: Any] {
            var out: [String: Any] = [:]
            for (key, value) in dict {
                if let palette = value as? [String], lightKeys.contains(key) || darkKeys.contains(key) {
                    out[key] = expand(palette, dark: darkKeys.contains(key))
                } else {
                    out[key] = expandReferences(in: value)
                }
            }
            return out
        }
        if let array = json as? [Any] { return array.map(expandReferences(in:)) }
        return json
    }

    /// Every `preset:` value that names no preset, with where it sits — what lint reports.
    static func unknownReferences(in json: Any, path: String = "") -> [(path: String, value: String)] {
        if let dict = json as? [String: Any] {
            return dict.keys.sorted().flatMap { key -> [(path: String, value: String)] in
                let here = path.isEmpty ? key : "\(path).\(key)"
                if let palette = dict[key] as? [String], lightKeys.contains(key) || darkKeys.contains(key) {
                    return palette.filter { $0.hasPrefix(prefix) && stops($0, dark: false) == nil }
                        .map { (here, $0) }
                }
                return unknownReferences(in: dict[key] as Any, path: here)
            }
        }
        if let array = json as? [Any] {
            return array.enumerated().flatMap { index, value in
                unknownReferences(in: value, path: "\(path)[\(index)]")
            }
        }
        return []
    }
}
