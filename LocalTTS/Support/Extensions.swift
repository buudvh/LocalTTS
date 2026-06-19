import Foundation

extension Data {
    var utf8String: String {
        String(decoding: self, as: UTF8.self)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
