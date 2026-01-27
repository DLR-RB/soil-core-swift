
/**
 An object that provides an extended description
 */
protocol DebugConvertible {

    /**
     Create the lines of an extended description.
     - Parameter indent: The indentation to use for indented lines of the description
     - Returns: The lines of the description
     */
    func described(indent: String) -> [String]
}

extension DebugConvertible {

    /**
     The extended description of the object.
     - Parameter indent: The indentation to use for indented lines of the description
     - Returns: The lines of the description joined by newline characters
     */
    func extendedDescription(indent: String = "  ") -> String {
        described(indent: indent).joined(separator: "\n")
    }

    /**
     Print the extended description of the object.
     - Parameter indent: The indentation to use for indented lines of the description
     */
    func printExtendedDescription(indent: String = "  ") {
        print(extendedDescription(indent: indent))
    }
}