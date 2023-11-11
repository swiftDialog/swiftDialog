//
//  String+Additions.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import CryptoKit

extension String {

    var sha256Hash: String {
        // Returns a sha256 hash of the given text
        let inputData = Data(self.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    var localized: String {
      return NSLocalizedString(self, comment: "\(self)_comment")
    }

    func localized(_ args: CVarArg...) -> String {
        return String(format: localized, arguments: args)
    }
}

extension String {
    func split(usingRegex pattern: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self))
            let splits = [startIndex]
            + matches
                .map { Range($0.range, in: self)! }
                .flatMap { [ $0.lowerBound, $0.upperBound ] }
            + [endIndex]

            return zip(splits, splits.dropFirst())
                .map { String(self[$0 ..< $1])}
        } catch {
            return [self]
        }
    }
}

extension String {
    private static let numberFormatter = NumberFormatter()
    var isNumeric: Bool {
        Self.numberFormatter.number(from: self) != nil
    }
}

extension StringProtocol {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}

extension String {
    var boolValue: Bool {
        return (self as NSString).boolValue
    }
}
