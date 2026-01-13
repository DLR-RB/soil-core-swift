import Soil


extension Timestamp {

    func isVeryClose(to other: Timestamp) -> Bool {
        distance(to: other) < 0.001
    }
}
