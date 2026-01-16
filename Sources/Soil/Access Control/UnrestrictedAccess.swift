
/**
 An access manager that allows full access for all components
 */
public struct UnrestrictedAccess<ComponentId: Hashable>: AccessManager {

    public init() { }

    public func component(_ id: ComponentId, canRead path: Path) -> Bool {
        true
    }

    public func component(_ id: ComponentId, canWrite path: Path) -> Bool {
        true
    }
}
