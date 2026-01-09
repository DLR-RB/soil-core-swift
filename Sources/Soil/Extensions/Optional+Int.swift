
extension Optional where Wrapped: Comparable {

    /**
     Check if an optional is either `nil` or greater/equal than the given value.

     This function is useful in conditional tests with optionals:

     ```
     let value: Int?
     if value.isNilOrNotSmaller(than: 42) {

     }
     ```
     - Parameter threshold: The value to compare to
     - Returns: `true`, if the value is either `nil` or greater/equal to `value`.
     */
    func isNilOrNotSmaller(than threshold: Wrapped) -> Bool {
        guard let self else {
            return true
        }
        return self >= threshold
    }

    /**
     Check if an optional is either `nil` or less/equal to the given value.

     This function is useful in conditional tests with optionals:

     ```
     let value: Int?
     if value.isNilOrNotGreater(than: 42) {

     }
     ```
     - Parameter threshold: The value to compare to
     - Returns: `true`, if the value is either `nil` or not greater than `value`.
     */
    func isNilOrNotGreater(than threshold: Wrapped) -> Bool {
        guard let self else {
            return true
        }
        return self <= threshold
    }
}
