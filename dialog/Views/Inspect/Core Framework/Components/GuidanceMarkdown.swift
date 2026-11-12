//
//  GuidanceMarkdown.swift
//  Dialog
//
//  Block-level Markdown in a `text` block, split so each piece renders through the view that
//  already owns its look.
//

import Foundation

/// One block-level piece of a `text` block. Inline markdown (bold, links, code spans) stays in
/// the strings for `guidanceAttributedMarkdown` to render.
enum MarkdownBlock: Equatable {
    case paragraph(String)
    case heading(level: Int, String)
    case list([String])
    case orderedList([String])
    case quote(String)
    case code(String)
}

/// Splits authored `text` content into block-level pieces so a Markdown list renders as a
/// `GuidanceBulletsBlock`. Content with no block syntax comes back as one paragraph, unchanged:
/// it is never reflowed, re-joined or trimmed.
enum GuidanceMarkdown {

    private static let unorderedMarkers: Set<Character> = ["-", "*", "+"]

    static func split(_ content: String) -> [MarkdownBlock] {
        // No newline means no block structure; hand the string back untouched.
        guard content.contains("\n") else {
            return content.isEmpty ? [] : [singleLine(content)]
        }

        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var list: [String] = []
        var ordered: [String] = []
        var quote: [String] = []
        var code: [String] = []
        var inCode = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph.removeAll()
        }
        func flushList() {
            guard !list.isEmpty else { return }
            blocks.append(.list(list)); list.removeAll()
        }
        func flushOrdered() {
            guard !ordered.isEmpty else { return }
            blocks.append(.orderedList(ordered)); ordered.removeAll()
        }
        func flushQuote() {
            guard !quote.isEmpty else { return }
            blocks.append(.quote(quote.joined(separator: "\n"))); quote.removeAll()
        }
        /// Closes every open run except the one being extended, so reading order survives.
        func flushAll(except keep: Int = 0) {
            if keep != 1 { flushParagraph() }
            if keep != 2 { flushList() }
            if keep != 3 { flushOrdered() }
            if keep != 4 { flushQuote() }
        }

        for rawLine in content.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(code.joined(separator: "\n")))
                    code.removeAll()
                    inCode = false
                } else {
                    flushAll()
                    inCode = true
                }
                continue
            }
            if inCode { code.append(rawLine); continue }

            if line.isEmpty { flushAll(); continue }

            if let heading = heading(from: line) {
                flushAll(); blocks.append(heading); continue
            }
            if let item = unorderedItem(from: line) {
                flushAll(except: 2); list.append(item); continue
            }
            if let item = orderedItem(from: line) {
                flushAll(except: 3); ordered.append(item); continue
            }
            if let text = quoteLine(from: line) {
                flushAll(except: 4); quote.append(text); continue
            }

            flushAll(except: 1)
            paragraph.append(rawLine)
        }

        // An unterminated fence still emits its text.
        if inCode, !code.isEmpty { blocks.append(.code(code.joined(separator: "\n"))) }
        flushAll()
        return blocks
    }

    // MARK: - Line classification
    //
    // Every marker requires its trailing space, so "-40% battery" and "#1 priority" stay prose.

    private static func singleLine(_ line: String) -> MarkdownBlock {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let heading = heading(from: trimmed) { return heading }
        if let item = unorderedItem(from: trimmed) { return .list([item]) }
        if let item = orderedItem(from: trimmed) { return .orderedList([item]) }
        if let text = quoteLine(from: trimmed) { return .quote(text) }
        return .paragraph(line)
    }

    private static func heading(from line: String) -> MarkdownBlock? {
        let hashes = line.prefix(while: { $0 == "#" })
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.first == " " else { return nil }
        return .heading(level: hashes.count,
                        String(rest.dropFirst()).trimmingCharacters(in: .whitespaces))
    }

    private static func unorderedItem(from line: String) -> String? {
        guard let first = line.first, unorderedMarkers.contains(first),
              line.dropFirst().first == " " else { return nil }
        return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    private static func orderedItem(from line: String) -> String? {
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard let sep = rest.first, sep == "." || sep == ")",
              rest.dropFirst().first == " " else { return nil }
        return String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    private static func quoteLine(from line: String) -> String? {
        guard line.hasPrefix(">") else { return nil }
        let rest = line.dropFirst()
        guard rest.first == " " else { return nil }
        return String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
}
