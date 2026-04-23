

extension Optional where Wrapped == Int {

    func largerEqual(_ other: Int) -> Bool {
        guard let self else {
            return true // `nil` represents infinity, so it's bigger
        }
        return self >= other
    }
}