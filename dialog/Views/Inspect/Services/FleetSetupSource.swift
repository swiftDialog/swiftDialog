import Foundation

enum FleetSetup {

    static func slug(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }.filter(\.isASCII)
    }
}
