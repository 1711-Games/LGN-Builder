enum EntityType {
    case entity(Entity)
    case shared(Entity)
}

extension EntityType {
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

    var isSystem: Bool {
        if case .shared(let entity) = self {
            return entity.isSystem
        }
        return false
    }
}
