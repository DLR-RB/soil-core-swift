

extension Optional where Wrapped == Int {

    /**
     Check if the optional integer is not smaller than a value, considering `nil` as an infinite value.
     - Parameter other: The value to compare to.
     - Returns: `true`, if self is `nil`, or not smaller than the given value.
     */
    func largerEqual(_ other: Int) -> Bool {
        guard let self else {
            return true // `nil` represents infinity, so it's bigger
        }
        return self >= other
    }
}