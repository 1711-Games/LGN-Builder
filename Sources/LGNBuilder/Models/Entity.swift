enum EntityType {
    case entity(Entity)
    case shared(Entity)
}

extension EntityType {
    var isSharedEmpty: Bool {
        if case .shared(let entity) = self {
            return entity.isSystem && entity.name == Entity.emptyEntityName
        }
        return false
    }
}

struct Entity {
    let name: String
    let fields: [Field]
    let needsAwait: Bool
    let futureField: String?
    let isMutable: Bool
    let keyDictionary: [String: String]
    let isSystem: Bool = false

    init(
        name: String,
        fields: [Field],
        needsAwait: Bool,
        futureField: String?,
        isMutable: Bool,
        keyDictionary: [String : String],
        isSystem: Bool = false
    ) {
        self.name = name
        self.fields = fields
        self.needsAwait = needsAwait
        self.futureField = futureField
        self.isMutable = isMutable
        self.keyDictionary = keyDictionary
    }
}

extension Entity: Model {
    enum Key: String {
        case parentEntity = "ParentEntity"
        case excludedFields = "ExcludeFields"
        case fields = "Fields"
        case isMutable = "IsMutable"
    }

    @available(*, deprecated, message: "Use init(name:from:shared:) instead")
    init(from input: Any) throws {
        throw E.InvalidSchema("Use init(name:from:shared:) instead")
    }

    init(name: String, from input: Any, shared: Shared) throws {
        self.name = name

        let errorPrefix = "Could not decode entity"

        guard let rawInput = input as? Dict else {
            throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
        }
        guard let rawFields = rawInput[Key.fields] as? Dict else {
            throw E.InvalidSchema("\(errorPrefix): input does not contain '\(Key.fields)' key (input: \(rawInput))")
        }

        var fields = [Field]()

        if let parentEntityName = rawInput[Key.parentEntity] as? String {
            guard let parentEntity = shared.getEntity(byName: parentEntityName) else {
                throw E.InvalidSchema("\(errorPrefix): parent entity '\(parentEntityName)' not present in Shared entities"
                )
            }
            let excludedFields: [String] = rawInput[Key.excludedFields] as? [String] ?? []
            fields = parentEntity.fields.filter { !excludedFields.contains($0.name) }
        }

        for (fieldName, fieldParams) in rawFields {
            let field = try Field(name: fieldName, from: fieldParams)
            if let existingFieldIndex = fields.firstIndex(where: { $0.name == field.name }) {
                fields[existingFieldIndex] = field
            } else {
                fields.append(field)
            }
        }

        self.fields = fields
        self.needsAwait = fields.reduce(false, { $1.canBeFuture })
        self.futureField = fields.first(where: { $0.canBeFuture })?.name
        self.isMutable = rawInput[Key.isMutable] as? Bool ?? false
        self.keyDictionary = [:] // todo
    }
}

extension Entity {
    static let emptyEntityName = "Empty"

    static let empty: Self = Self(
        name: Self.emptyEntityName,
        fields: [],
        needsAwait: false,
        futureField: nil,
        isMutable: false,
        keyDictionary: [:],
        isSystem: true
    )
}
