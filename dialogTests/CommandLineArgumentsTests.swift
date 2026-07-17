//
//  CommandLineArgumentsTests.swift
//  dialogTests
//
//  Guards the single-source-of-truth keypath table that updateAllItems and
//  resetToDefaults drive off (backlog M3).
//

import XCTest
@testable import Dialog

final class CommandLineArgumentsTests: XCTestCase {

    /// The keypath table must list every CommandlineArgument property exactly once —
    /// this is what stops a newly added argument being silently forgotten.
    func testAllArgumentKeyPathsCoverEveryArgument() {
        let mirror = Mirror(reflecting: CommandLineArguments())
        let argumentCount = mirror.children.filter { $0.value is CommandlineArgument }.count
        let keyPaths = CommandLineArguments.allArgumentKeyPaths
        XCTAssertEqual(Set(keyPaths).count, keyPaths.count,
                       "allArgumentKeyPaths contains duplicate keypaths")
        XCTAssertEqual(keyPaths.count, argumentCount,
                       "allArgumentKeyPaths must list every CommandlineArgument property (add the new one)")
    }

    /// resetToDefaults must leave the session/meta-level exclusions untouched while
    /// resetting everything else.
    func testResetToDefaultsPreservesExclusionsAndResetsOthers() {
        var args = CommandLineArguments()
        for keyPath in CommandLineArguments.resetExclusions {
            args[keyPath: keyPath].value = "PRESERVE-ME"
            args[keyPath: keyPath].present = true
        }
        args.titleOption.value = "SHOULD-RESET"
        args.titleOption.present = true

        args.resetToDefaults()

        for keyPath in CommandLineArguments.resetExclusions {
            XCTAssertEqual(args[keyPath: keyPath].value, "PRESERVE-ME",
                           "Excluded argument '\(args[keyPath: keyPath].long)' must persist across resetToDefaults")
            XCTAssertTrue(args[keyPath: keyPath].present)
        }
        XCTAssertFalse(args.titleOption.present,
                       "A non-excluded argument should be reset to its default (present == false)")
    }

    /// Every exclusion must itself be a known argument keypath.
    func testResetExclusionsAreKnownArguments() {
        let all = Set(CommandLineArguments.allArgumentKeyPaths)
        for keyPath in CommandLineArguments.resetExclusions {
            XCTAssertTrue(all.contains(keyPath),
                          "resetExclusions contains a keypath that isn't in allArgumentKeyPaths")
        }
    }
}
