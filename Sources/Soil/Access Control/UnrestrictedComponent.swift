
/**
 A component access specification that allows all operations.
 */
public struct UnrestrictedComponent {

    public init() { }

}

extension UnrestrictedComponent: ComponentAccess {

    public func component(canRead path: Path) -> Bool {
        true
    }

    public func component(canWrite path: Path) -> Bool {
        true
    }

    public func component(canDelete path: Path) -> Bool {
        true
    }
}