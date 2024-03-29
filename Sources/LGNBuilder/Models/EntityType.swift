struct EntityType {
    enum System: String {
        case Empty
        case Cookie
        case File
        case HTML

        var entity: Entity {
            let result: Entity

            switch self {
            case .Empty: result = Entity.empty
            case .Cookie: result = Entity.cookie
            case .File: result = Entity.file
            case .HTML: result = Entity.html
            }

            return result
        }
    }

    var wrapped: Entity
    var isShared: Bool = false

    var isSystem: Bool {
        self.isShared && self.wrapped.isSystem
    }

    var isFile: Bool {
        self.isSystem && self.wrapped.name == System.File.rawValue
    }

    var isHTML: Bool {
        self.isSystem && self.wrapped.name == System.HTML.rawValue
    }

    static func shared(_ entity: Entity) -> Self {
        Self(entity, isShared: true)
    }

    init(_ wrapped: Entity, isShared: Bool = false) {
        self.wrapped = wrapped
        self.isShared = isShared
    }
}
