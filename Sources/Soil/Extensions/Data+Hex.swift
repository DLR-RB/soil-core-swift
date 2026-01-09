import Foundation

extension Data {

    /// The data as an uppercase hex string
    var hex: String {
        map { String(format: "%02X", $0) }.joined()
    }
}