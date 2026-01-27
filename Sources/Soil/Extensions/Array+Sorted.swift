
extension Array where Element: Comparable {

    /**
     Insert a new element into the sorted array.

     - Note: This function assumes that the array is sorted in ascending order.
     - Parameter newElement: The element to insert
     */
    mutating func insertIntoSorted(_ value: Element) {
        let index = partitioningIndex { $0 > value }
        insert(value, at: index)
    }
}

extension Array {

    /**
     Insert a new element into the sorted array.

     - Note: This function assumes that the array is sorted in ascending order.
     - Parameter newElement: The element to insert
     - Parameter areInIncreasingOrder: A predicate that returns true if its first argument should be ordered before its second argument; otherwise, false.
     */
    mutating func insertIntoSorted(_ newElement: Element, where areInIncreasingOrder: (Element, Element) -> Bool) {
        let index = partitioningIndex { areInIncreasingOrder(newElement, $0) }
        insert(newElement, at: index)
    }
}