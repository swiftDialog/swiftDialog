//
//  CommentFileReferenceTests.swift
//  dialogTests
//
//  Every file and test a source comment names in backticks exists.
//

import XCTest
import SwiftUI
@testable import Dialog

// MARK: - Comment references

/// In a comment, a backticked file name (Name.swift) or test name (testSomething) is a live
/// reference and must exist in the repo; a name in plain prose is not checked.
final class CommentFileReferenceTests: XCTestCase {

    /// Names used in prose as examples rather than as references to this repo's sources.
    private static let notOurs: Set<String> = [
        "ContentView.swift"   // the upstream classic file
    ]

    func testEveryFileNamedInACommentExists() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let inspect = root.appendingPathComponent("dialog/Views/Inspect")

        var present = Set<String>()
        if let all = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let f as URL in all where f.pathExtension == "swift" {
                present.insert(f.lastPathComponent)
            }
        }
        XCTAssertFalse(present.isEmpty, "found no sources — the walk is broken, not the tree")

        let named = try NSRegularExpression(pattern: "`([A-Za-z0-9+_-]+\\.swift)`")
        var dangling: [String] = []

        for dir in [inspect, root.appendingPathComponent("dialogTests")] {
            guard let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
            else { return XCTFail("could not walk \(dir.path)") }

            for case let file as URL in walker where file.pathExtension == "swift" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                for (index, raw) in text.components(separatedBy: .newlines).enumerated() {
                    let line = raw.trimmingCharacters(in: .whitespaces)
                    guard line.hasPrefix("//") || line.hasPrefix("///") || line.hasPrefix("*") else { continue }
                    let range = NSRange(line.startIndex..., in: line)
                    for m in named.matches(in: line, range: range) {
                        guard let r = Range(m.range(at: 1), in: line) else { continue }
                        let name = String(line[r])
                        if present.contains(name) || Self.notOurs.contains(name) { continue }
                        dangling.append("\(file.lastPathComponent):\(index + 1) names `\(name)`")
                    }
                }
            }
        }

        XCTAssertEqual(dangling, [],
                       "comments name \(dangling.count) file(s) that do not exist. Either the "
                       + "reference is stale, or the point it was making is history — write it as "
                       + "dated history and it stops being a claim that can rot.")
    }

    /// A backticked test name in a comment must resolve to a test in this target.
    func testEveryTestNamedInACommentExists() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let tests = root.appendingPathComponent("dialogTests")
        let inspect = root.appendingPathComponent("dialog/Views/Inspect")

        let defined = try NSRegularExpression(pattern: "func (test[A-Za-z0-9_]*)\\s*\\(")
        var present = Set<String>()
        guard let testWalker = FileManager.default.enumerator(at: tests, includingPropertiesForKeys: nil)
        else { return XCTFail("could not walk \(tests.path)") }
        for case let file as URL in testWalker where file.pathExtension == "swift" {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for m in defined.matches(in: text, range: range) {
                if let r = Range(m.range(at: 1), in: text) { present.insert(String(text[r])) }
            }
        }
        XCTAssertGreaterThan(present.count, 1000, "found too few tests — the walk is broken, not the tree")

        let cited = try NSRegularExpression(pattern: "`(test[A-Z][A-Za-z0-9_]*)(?:\\(\\))?`")
        var dangling: [String] = []
        for dir in [inspect, tests] {
            guard let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
            else { return XCTFail("could not walk \(dir.path)") }
            for case let file as URL in walker where file.pathExtension == "swift" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                for (index, raw) in text.components(separatedBy: .newlines).enumerated() {
                    let line = raw.trimmingCharacters(in: .whitespaces)
                    guard line.hasPrefix("//") || line.hasPrefix("*") else { continue }
                    let range = NSRange(line.startIndex..., in: line)
                    for m in cited.matches(in: line, range: range) {
                        guard let r = Range(m.range(at: 1), in: line) else { continue }
                        let name = String(line[r])
                        if present.contains(name) { continue }
                        dangling.append("\(file.lastPathComponent):\(index + 1) promises `\(name)`")
                    }
                }
            }
        }
        XCTAssertEqual(dangling, [],
                       "comments promise \(dangling.count) test(s) that do not exist. Name the test "
                       + "that holds the fact now, or drop the promise.")
    }
}
