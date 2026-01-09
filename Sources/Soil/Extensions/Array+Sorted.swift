
extension Array where Element: Comparable {

    mutating func insertIntoSorted(_ value: Element) {
        let index = partitioningIndex { $0 < value }
        insert(value, at: index)
    }
}