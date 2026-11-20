//
//  GuidanceMarkdownTests.swift
//  dialogTests
//
//  Block-level Markdown in a `text` block: `GuidanceMarkdown.split` cuts headings, lists, quotes and
//  fences out before the inline renderer runs, and leaves every existing corpus block byte-identical.
//

import XCTest
@testable import Dialog

final class GuidanceMarkdownTests: XCTestCase {

    // MARK: - Corpus no-op

    /// Walks the configs under `roots`.
    private func corpusTextContents(roots: [URL]) -> [(file: String, content: String)] {

        var out: [(String, String)] = []
        for root in roots {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "json" {
                guard let data = try? Data(contentsOf: url),
                      let any = try? JSONSerialization.jsonObject(with: data) else { continue }
                collect(any, file: url.lastPathComponent, into: &out)
            }
        }
        return out
    }

    private func collect(_ node: Any, file: String, into out: inout [(String, String)]) {
        if let dict = node as? [String: Any] {
            if dict["type"] as? String == "text", let content = dict["content"] as? String {
                out.append((file, content))
            }
            for value in dict.values { collect(value, file: file, into: &out) }
        } else if let list = node as? [Any] {
            for value in list { collect(value, file: file, into: &out) }
        }
    }

    /// No in-repo config uses block syntax, so every text block passes through byte-identical.
    func testEveryCorpusTextBlockIsAnUntouchedParagraph() {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let contents = corpusTextContents(roots: [repo.appendingPathComponent("dialogTests/Fixtures/inspect")])
        XCTAssertGreaterThan(contents.count, 10, "the corpus walk found suspiciously little")

        for (file, content) in contents {
            let blocks = GuidanceMarkdown.split(content)
            XCTAssertEqual(blocks, [.paragraph(content)],
                           "\(file): content without block syntax must pass through byte-identical")
        }
    }

    /// `/Users/Shared/Demos` is optional and outside the repo; every block in it splits to something.
    func testMachineLocalDemoCorpusSplitsWithoutLoss() {
        let shared = URL(fileURLWithPath: "/Users/Shared/Demos")
        guard FileManager.default.fileExists(atPath: shared.path) else { return }
        for (file, content) in corpusTextContents(roots: [shared]) where !content.isEmpty {
            XCTAssertFalse(GuidanceMarkdown.split(content).isEmpty, "\(file): a non-empty block split to nothing")
        }
    }

    // MARK: - Block forms

    func testAHeadingTakesItsLevel() {
        XCTAssertEqual(GuidanceMarkdown.split("## Disk encryption"),
                       [.heading(level: 2, "Disk encryption")])
        XCTAssertEqual(GuidanceMarkdown.split("# Top"), [.heading(level: 1, "Top")])
    }

    func testAnUnorderedListBecomesOneListBlock() {
        XCTAssertEqual(GuidanceMarkdown.split("- one\n- two\n- three"),
                       [.list(["one", "two", "three"])])
    }

    func testTheOtherUnorderedMarkersAreAccepted() {
        XCTAssertEqual(GuidanceMarkdown.split("* one\n+ two"), [.list(["one", "two"])])
    }

    func testAnOrderedListBecomesOneOrderedBlock() {
        XCTAssertEqual(GuidanceMarkdown.split("1. first\n2. second"),
                       [.orderedList(["first", "second"])])
    }

    func testABlockquoteBecomesOneQuote() {
        XCTAssertEqual(GuidanceMarkdown.split("> mind the gap"), [.quote("mind the gap")])
    }

    func testAFencedBlockBecomesCode() {
        XCTAssertEqual(GuidanceMarkdown.split("```\nsudo profiles renew\n```"),
                       [.code("sudo profiles renew")])
    }

    // MARK: - Composition

    func testProseAroundAListSplitsIntoThree() {
        XCTAssertEqual(
            GuidanceMarkdown.split("Before you start:\n- back up\n- plug in\nThen continue."),
            [.paragraph("Before you start:"),
             .list(["back up", "plug in"]),
             .paragraph("Then continue.")])
    }

    func testABlankLineSeparatesParagraphs() {
        XCTAssertEqual(GuidanceMarkdown.split("One.\n\nTwo."),
                       [.paragraph("One."), .paragraph("Two.")])
    }

    /// Hard-wrapped prose with no blank line stays one paragraph, joined as authored.
    func testHardWrappedProseStaysOneParagraph() {
        XCTAssertEqual(GuidanceMarkdown.split("a line\nand its continuation"),
                       [.paragraph("a line\nand its continuation")])
    }

    /// Inline Markdown inside a list item is left for `guidanceAttributedMarkdown`.
    func testInlineMarkdownSurvivesInsideAListItem() {
        XCTAssertEqual(GuidanceMarkdown.split("- click **Migrate Now**"),
                       [.list(["click **Migrate Now**"])])
    }

    // MARK: - Look-alikes

    /// A hyphen that starts a sentence is not a list. The marker needs its space.
    func testAHyphenWithoutASpaceIsProse() {
        XCTAssertEqual(GuidanceMarkdown.split("-40% battery remaining"),
                       [.paragraph("-40% battery remaining")])
    }

    func testAHashWithoutASpaceIsProse() {
        XCTAssertEqual(GuidanceMarkdown.split("#1 priority"), [.paragraph("#1 priority")])
    }

    func testAnEmptyStringIsNoBlocksAtAll() {
        XCTAssertEqual(GuidanceMarkdown.split(""), [])
    }
}
