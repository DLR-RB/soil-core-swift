import Testing
@testable import Soil

@Suite("Sorting")
struct SortingTests {

    @Test("Insert into sorted array")
    func insertIntoSorted() throws {
        var start = [1, 2, 4, 5]
        start.insertIntoSorted(3)
        #expect(start == [1, 2, 3, 4, 5])
    }
}