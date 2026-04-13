import Soil


extension Timestamp {

    func isVeryClose(to other: Timestamp) -> Bool {
        distance(to: other) < 0.001
    }
}

extension Sample {

    func isVeryClose(to other: Timestamp) -> Bool {
        (timestamp ?? .current()).isVeryClose(to: other)
    }
}