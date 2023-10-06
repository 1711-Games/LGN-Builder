indirect enum FieldType {
    case String
    case Int
    case Float
    case Bool
    case List(FieldType)
    case Map(String, FieldType)
    case Custom(Entity)
}

extension FieldType {
    var asString: String {
        let result: String

        switch self {
        case .String: result = "String"
        case .Int: result = "Int"
        case .Bool: result = "Bool"
        case .Float: result = "Float"
        case let .List(list): result = "List[\(list.asString)]"
        case let .Map(key, value): result = "Map[\(key):\(value.asString)]"
        case let .Custom(entity): result = entity.preparedName
        }

        return result
    }

    var isString: Bool {
        if case .String = self {
            return true
        }
        return false
    }

    var isCookie: Bool {
        if case let .Custom(type) = self {
            return type.name == EntityType.System.Cookie.rawValue
        }
        return false
    }

    var isFile: Bool {
        if case let .Custom(type) = self {
            return type.name == EntityType.System.File.rawValue
        }
        return false
    }

    var isGETSafe: Bool {
        let result: Bool

        switch self {
        case .String, .Int, .Float, .Bool: result = true
        case .List: result = false // value.isGETSafe
        case .Map: result = false
        default: result = self.isCookie
        }

        return result
    }

    var canBeDictionaryKey: Bool {
        let result: Bool

        switch self {
        case .String: result = true
        case .Int: result = true
        default: result = false
        }

        return result
    }

    init(from string: String, shared: Shared) throws {
        let result: Self

        let listPrefix = "List["
        let mapPrefix = "Map["

        switch string {
        case "String": result = .String
        case "Int": result = .Int
        case "Bool": result = .Bool
        case "Float": result = .Float
        case let str where str.starts(with: listPrefix):
            result = try .List(
                Self.init(from: Swift.String(string.dropFirst(listPrefix.count).dropLast(1)), shared: shared)
            )
        case let str where str.starts(with: mapPrefix):
            let cleanString = string.dropFirst(mapPrefix.count).dropLast(1)
            let components = cleanString.split(separator: ":")
            guard components.count == 2 else {
                throw E.InvalidSchema("Map type definition must contain colon (input: '\(string)')")
            }
            result = try .Map(Swift.String(components[0]), Self.init(from: Swift.String(components[1]), shared: shared))
        default:
            guard let sharedEntity = shared.getEntity(byName: string) else {
                throw E.InvalidSchema(
                    "Could not decode custom field type '\(string)': entity '\(string)' not found in shared "
                    + "(hint: entity might not have yet been decoded because of file ordering, try reordering YAML definitions)"
                )
            }
            result = .Custom(sharedEntity)
        }

        self = result
    }
}

extension FieldType: Equatable {
    static func == (lhs: FieldType, rhs: FieldType) -> Bool {
        lhs.asString == rhs.asString
    }
}
