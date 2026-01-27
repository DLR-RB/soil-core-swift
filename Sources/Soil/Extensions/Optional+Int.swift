
extension Optional where Wrapped: Comparable {

    /**
     Compare two optional values.

     `nil` is considered an infinite value.
     - Returns: `true`, if `lhs` is smaller than `rhs`
     */
    static func < (lhs: Wrapped?, rhs: Wrapped?) -> Bool {
        guard let lhs else {
            return false // `nil` represents infinity, so lhs can't be smaller than rhs
        }
        guard let rhs else {
            return true // rhs is infinite, so lhs must be smaller
        }
        // Compare finite values
        return lhs < rhs
    }

    /**
     Compare two optional values.

     `nil` is considered an infinite value.
     - Returns: `true`, if `lhs` is bigger than or equalt to `rhs`
     */
    static func >= (lhs: Wrapped?, rhs: Wrapped?) -> Bool {
        guard let lhs else {
            return true // `nil` represents infinity, so lhs can't be smaller than rhs
        }
        guard let rhs else {
            return false // rhs is infinite, so lhs must be smaller
        }
        // Compare finite values
        return lhs >= rhs
    }

    /**
     Compare two optional values.

     `nil` is considered an infinite value.
     - Returns: `true`, if `lhs` is larger than `rhs`
     */
    static func > (lhs: Wrapped?, rhs: Wrapped?) -> Bool {
        guard let rhs else {
            return false // `nil` represents infinity, so rhs can't be smaller than lhs
        }
        guard let lhs else {
            return true // lhs is infinite, so rhs must be smaller
        }
        // Compare finite values
        return lhs > rhs
    }
}
