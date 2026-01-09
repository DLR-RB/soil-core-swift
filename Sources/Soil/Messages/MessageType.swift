import Foundation

public enum MessageType: Int {
    case value = 0
    case request = 1
    case history = 2
}

extension MessageType: Codable {

}
