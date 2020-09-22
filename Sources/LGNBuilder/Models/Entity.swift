struct Entity {
    let name: String
    let fields: [Field]
    let isMutable: Bool
    let keyDictionary: [String: String]
    let isSystem: Bool

    var needsAwait: Bool {
        self.fields.reduce(false, { $0 || $1.canBeFuture })
    }

    var futureField: Field? {
        self.fields.first(where: { $0.canBeFuture })
    }

    init(
        name: String,
        fields: [Field],
        isMutable: Bool,
        keyDictionary: [String: String],
        isSystem: Bool = false
    ) {
        self.name = name
        self.fields = fields
        self.isMutable = isMutable
        self.keyDictionary = keyDictionary
        self.isSystem = isSystem
    }
}

extension Entity: Model {
    enum Key: String {
        case parentEntity = "ParentEntity"
        case excludedFields = "ExcludeFields"
        case fields = "Fields"
        case isMutable = "IsMutable"
    }

    var preparedName: String {
        "\(self.isSystem ? "LGNC.Entity" : "Services.Shared").\(self.name)"
    }

    @available(*, deprecated, message: "Use init(name:from:shared:) instead")
    init(from input: Any) throws {
        throw E.InvalidSchema("Use init(name:from:shared:) instead")
    }

    init(name: String, from input: Any, shared: Shared) throws {
        let errorPrefix = "Could not decode entity '\(name)'"

        guard let rawInput = input as? Dict else {
            throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
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

        // Even though an entity must have at least one field, we don't do this kind of validation here because
        // entity might have parent entity + excluded fields, and thus there migth be no need to have `Fields` key.
        let rawFields = rawInput[Key.fields] as? Dict ?? Dict()
        for (fieldName, fieldParams) in rawFields {
            let field = try Field(name: fieldName, from: fieldParams, shared: shared)
            if let existingFieldIndex = fields.firstIndex(where: { $0.name == field.name }) {
                fields[existingFieldIndex] = field
            } else {
                fields.append(field)
            }
        }

        guard fields.count > 0 else {
            throw E.InvalidSchema("\(errorPrefix): there are no fields in this entity")
        }

        self = Self(
            name: name,
            fields: fields,
            isMutable: rawInput[Key.isMutable] as? Bool ?? false,
            keyDictionary: [:], // todo
            isSystem: false
        )
    }
}

extension Entity {
    static let empty: Self = Self(
        name: EntityType.System.Empty.rawValue,
        fields: [],
        isMutable: false,
        keyDictionary: [:],
        isSystem: true
    )

    static let cookie: Self = Self(
        name: EntityType.System.Cookie.rawValue,
        fields: [],
        isMutable: false,
        keyDictionary: [:],
        isSystem: true
    )
}
