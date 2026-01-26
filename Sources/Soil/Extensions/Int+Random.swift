
extension Int {

    /**
     Create a random integer in the full available range.
     */
    public static func random() -> Int {
        .random(in: Int.min...Int.max)
    }
}