struct EntityType {
    enum System: String {
        case Empty
        case Cookie

        var entity: Entity {
            let result: Entity

            switch self {
            case .Empty: result = Entity.empty
            case .Cookie: result = Entity.cookie
            }

            return result
        }
    }

    var wrapped: Entity
    var isShared: Bool = false

    var isSystem: Bool {
        self.isShared && self.wrapped.isSystem
    }

    static func shared(_ entity: Entity) -> Self {
        Self(entity, isShared: true)
    }

    init(_ wrapped: Entity, isShared: Bool = false) {
        self.wrapped = wrapped
        self.isShared = isShared
    }
}
