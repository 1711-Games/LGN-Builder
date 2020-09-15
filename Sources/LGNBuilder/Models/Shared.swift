final class Shared {
    enum Key: String {
        case entities = "Entities"
        case dateFormat = "DateFormat"
    }

    var entities: [Entity] = []
    let dateFormat: String?

    init(dateFormat: String?) {
        self.dateFormat = dateFormat
    }

    convenience init(from input: Any) throws {
        guard let rawInput = input as? Dict else {
            self.init(dateFormat: nil)
            return
        }

        self.init(dateFormat: rawInput[Key.dateFormat] as? String)

        for (entityName, rawEntity) in (rawInput[Key.entities] as? Dict ?? Dict()) {
            self.entities.append(try Entity(name: entityName, from: rawEntity, shared: self))
        }
    }

    func getEntity(byName name: String) -> Entity? {
        name == Entity.emptyEntityName
            ? .empty
            : self.entities.first(where: { $0.name == name })
    }
}
