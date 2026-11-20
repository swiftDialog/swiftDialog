//
//  PaletteAndNoticeTests.swift
//  dialogTests
//
//  The config model's palettes, advisories and notices, and the language key lookup.
//

import XCTest
import SwiftUI
import Synchronization
@testable import Dialog

/// `defaultLanguage: "auto"` against `localization.languages` keyed by display name
/// (`"Deutsch": ".../de.json"`): `languageKey(forCode:in:)` also matches the file's code and the native name.
final class LanguageKeyForCodeTests: XCTestCase {

    private let corpusShape = ["English": "/d/lang/en.json",
                               "Deutsch": "/d/lang/de.json",
                               "Français": "/d/lang/fr.json"]

    /// Keyed by display name, the file named by code.
    func testMatchesTheDisplayNameKeyByItsFileCode() {
        XCTAssertEqual(LocalizationService.languageKey(forCode: "de", in: corpusShape), "Deutsch")
        XCTAssertEqual(LocalizationService.languageKey(forCode: "fr", in: corpusShape), "Français")
        XCTAssertEqual(LocalizationService.languageKey(forCode: "en", in: corpusShape), "English")
    }

    /// A dictionary keyed by code still resolves.
    func testMatchesAnExactCodeKey() {
        XCTAssertEqual(LocalizationService.languageKey(forCode: "de",
                                                       in: ["de": "de.json", "en": "en.json"]), "de")
    }

    /// Code matching ignores case.
    func testCodeMatchingIsCaseInsensitive() {
        XCTAssertEqual(LocalizationService.languageKey(forCode: "DE", in: corpusShape), "Deutsch")
    }

    /// With no file hint, the locale's native display name matches.
    func testFallsBackToTheNativeDisplayName() {
        XCTAssertEqual(LocalizationService.languageKey(forCode: "de",
                                                       in: ["Deutsch": "", "English": ""]), "Deutsch")
    }

    /// A language the config does not carry resolves to nil.
    func testAnUncarriedLanguageResolvesToNil() {
        XCTAssertNil(LocalizationService.languageKey(forCode: "ja", in: corpusShape))
    }
}


// MARK: - notice palette token

/// `notice` lets the removal chip read `\.palette` instead of a colour literal, declared like `warning`.
final class ResolvedPaletteNoticeTests: XCTestCase {

    /// Only `notice` authored, so assertions concern its resolution alone.
    private func brandPalette(notice: String?) -> InspectConfig.BrandPalette {
        InspectConfig.BrandPalette(
            primary: nil, secondary: nil, accent: nil,
            success: nil, warning: nil, error: nil, info: nil,
            notice: notice,
            background: nil, surface: nil, surfaceLight: nil,
            textPrimary: nil, textSecondary: nil,
            logos: nil, custom: nil)
    }

    /// Unauthored, `notice` is #724913 in light and #e0b378 in dark.
    func testNoticeResolvesDifferentlyInEachAppearance() {
        let light = ResolvedPalette(from: nil, dark: nil, scheme: .light)
        let dark = ResolvedPalette(from: nil, dark: nil, scheme: .dark)
        XCTAssertNotEqual(light.notice, dark.notice)
        XCTAssertEqual(light.notice, Color(hex: "#724913"))
        XCTAssertEqual(dark.notice, Color(hex: "#e0b378"))
    }

    /// An authored `brandPalette.notice` wins in light.
    func testAnAuthoredNoticeWinsInLight() {
        let resolved = ResolvedPalette(from: brandPalette(notice: "#123456"), dark: nil, scheme: .light)
        XCTAssertEqual(resolved.notice, Color(hex: "#123456"))
    }

    /// `brandPaletteDark.notice` wins in dark over the light value and the default.
    func testAnAuthoredDarkNoticeWinsInDark() {
        let resolved = ResolvedPalette(from: brandPalette(notice: "#123456"),
                                       dark: brandPalette(notice: "#abcdef"),
                                       scheme: .dark)
        XCTAssertEqual(resolved.notice, Color(hex: "#abcdef"))
    }

    /// `noticeBackground` follows the `warningBackground` idiom at 0.16, and `noticeInk` derives from
    /// `notice`, checked for the default and an authored value.
    func testNoticeBackgroundAndInkAreDerivedNotLiteral() {
        let light = ResolvedPalette(from: nil, dark: nil, scheme: .light)
        let dark = ResolvedPalette(from: nil, dark: nil, scheme: .dark)
        XCTAssertEqual(light.noticeBackground, light.notice.opacity(0.16))
        XCTAssertEqual(dark.noticeBackground, dark.notice.opacity(0.16))
        XCTAssertNotEqual(light.noticeInk, light.notice,
                          "ink must be pushed off the wash, not equal to the base token")
        XCTAssertNotEqual(dark.noticeInk, dark.notice,
                          "ink must be pushed off the wash, not equal to the base token")

        let authored = ResolvedPalette(from: brandPalette(notice: "#123456"), dark: nil, scheme: .light)
        XCTAssertEqual(authored.noticeBackground, Color(hex: "#123456").opacity(0.16))
        XCTAssertNotEqual(authored.noticeBackground, light.noticeBackground,
                          "background must follow the AUTHORED notice, not the unauthored default")
        XCTAssertNotEqual(authored.noticeInk, light.noticeInk,
                          "ink must follow the AUTHORED notice, not the unauthored default")
    }
}

// MARK: - Palette from a mobileconfig

/// `brandPaletteRef` lets a managed profile supply palette roles; `brandColorRef` covers one colour only.
@MainActor
final class BrandPaletteRefTests: XCTestCase {

    private var base: String!

    override func setUpWithError() throws {
        base = NSTemporaryDirectory() + "managed-prefs-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)
        CadenceMonitorService.managedPreferencesBase = base
    }

    override func tearDownWithError() throws {
        CadenceMonitorService.managedPreferencesBase = "/Library/Managed Preferences"
        try? FileManager.default.removeItem(atPath: base)
    }

    private func writeProfile(_ domain: String, _ contents: [String: Any]) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: contents,
                                                      format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: "\(base!)/\(domain).plist"))
    }

    private func config(_ json: String) throws -> InspectConfig {
        try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
    }

    private let ref = #"{"domain":"com.example.branding","key":"BrandPalette","darkKey":"BrandPaletteDark"}"#

    /// A profile's roles reach the resolved palette.
    func testAProfileSuppliesTheWholePalette() throws {
        try writeProfile("com.example.branding", [
            "BrandPalette": ["primary": "#112233", "success": "#00FF00", "notice": "#FF00FF"]
        ])
        let c = try config(#"{"preset":"5","brandPaletteRef":\#(ref)}"#)
        let light = ResolvedPalette.palettes(for: c).light
        XCTAssertEqual(light?.primary, "#112233")
        XCTAssertEqual(light?.success, "#00FF00")
        XCTAssertEqual(light?.notice, "#FF00FF")
    }

    /// The dark key set is used only in dark.
    func testTheDarkKeySetIsUsedForDark() throws {
        try writeProfile("com.example.branding", [
            "BrandPalette": ["primary": "#111111"],
            "BrandPaletteDark": ["primary": "#EEEEEE"]
        ])
        let c = try config(#"{"preset":"5","brandPaletteRef":\#(ref)}"#)
        let both = ResolvedPalette.palettes(for: c)
        XCTAssertEqual(both.light?.primary, "#111111")
        XCTAssertEqual(both.dark?.primary, "#EEEEEE")
    }

    /// An absent profile falls back to the inline palette.
    func testAnAbsentProfileFallsBackToTheInlinePalette() throws {
        let c = try config(##"{"preset":"5","brandPalette":{"primary":"#ABCDEF"},"brandPaletteRef":\##(ref)}"##)
        XCTAssertEqual(ResolvedPalette.palettes(for: c).light?.primary, "#ABCDEF",
                       "no profile on disk — the inline palette is still the tenant's design")
    }

    /// A partial profile fills only the roles it names.
    func testAPartialProfileFillsOnlyTheRolesItNames() throws {
        try writeProfile("com.example.branding", ["BrandPalette": ["primary": "#000FFF"]])
        let c = try config(##"""
        {"preset":"5",
         "brandPalette":{"primary":"#ABCDEF","secondary":"#123456","success":"#654321"},
         "brandPaletteRef":\##(ref)}
        """##)
        let light = ResolvedPalette.palettes(for: c).light
        XCTAssertEqual(light?.primary, "#000FFF", "the profile wins for the role it names")
        XCTAssertEqual(light?.secondary, "#123456", "and leaves the ones it does not")
        XCTAssertEqual(light?.success, "#654321")
    }

    /// A non-string role is dropped without spoiling the rest.
    func testANonStringRoleIsDroppedRatherThanPoisoningTheMerge() throws {
        try writeProfile("com.example.branding", [
            "BrandPalette": ["primary": "#000FFF", "secondary": 42]
        ])
        let c = try config(##"{"preset":"5","brandPalette":{"secondary":"#123456"},"brandPaletteRef":\##(ref)}"##)
        let light = ResolvedPalette.palettes(for: c).light
        XCTAssertEqual(light?.primary, "#000FFF")
        XCTAssertEqual(light?.secondary, "#123456", "the numeric role is dropped, not merged")
    }
}
