struct Shared {
    let entities: [Entity]
    let dateFormat: String?
}

extension Shared: Model {
    enum Key: String {
        case entities = "Entities"
        case dateFormat = "DateFormat"
    }

    init(from input: Any) throws {
        guard let rawInput = input as? Dict else {
            self = Self(entities: [], dateFormat: nil)
            return
        }

        self.entities = try (rawInput[Key.entities] as? Dict ?? Dict()).map { entityName, rawEntity in
            try Entity(name: entityName, from: rawEntity, shared: rawInput)
        }
        self.dateFormat = rawInput[Key.dateFormat] as? String
    }
}
