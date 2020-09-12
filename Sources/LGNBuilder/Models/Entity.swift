enum EntityType {
    case entity(Entity)
    case shared(String)
}

extension EntityType {
    var isSharedEmpty: Bool {
        if case .shared(let name) = self {
            return name == Contract.emptyEntity
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

    init(name: String, from input: Any, shared: Dict) throws {
        self.name = name

        let errorPrefix = "Could not decode entity"

        guard let rawInput = input as? Dict else {
            throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
        }

        var rawFields = rawInput[Key.fields] as? Dict ?? [:]

        if let rawParentEntity = rawInput[Key.parentEntity] as? String {
            guard
                let sharedEntities = shared["Entities"] as? Dict,
                let parentEntity = sharedEntities[rawParentEntity] as? Dict,
                var parentFields = parentEntity["Fields"] as? Dict
            else {
                throw E.InvalidSchema(
                    "\(errorPrefix): parent entity '\(rawParentEntity)' not present in Shared entities"
                )
            }
            for (fieldName, fieldParams) in rawFields {
                parentFields[fieldName] = fieldParams
            }
            let excludedFields: [String] = rawInput[Key.excludedFields] as? [String] ?? []
            rawFields = parentFields.filter { !excludedFields.contains($0.key) }
        }

        let isMutable = rawInput[Key.isMutable] as? Bool ?? false

        let fields: [Field] = try rawFields.map {
            try Field(name: $0, from: $1)
        }

        self.fields = fields
        self.needsAwait = fields.reduce(false, { $1.canBeFuture })
        self.futureField = fields.first(where: { $0.canBeFuture })?.name
        self.isMutable = isMutable
        self.keyDictionary = [:]
    }
}

// TODO: key dictionary
