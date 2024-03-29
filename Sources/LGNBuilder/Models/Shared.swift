import LGNLog

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
        Logger.current.debug("Decoding shared")

        guard let rawInput = input as? Dict else {
            self.init(dateFormat: nil)
            return
        }

        self.init(dateFormat: rawInput[Key.dateFormat] as? String)

        for (entityName, rawEntity) in (rawInput[Key.entities] as? Dict ?? Dict()) {
            Logger.current.debug("Decoding shared entity '\(entityName)'")
            self.entities.append(try Entity(name: entityName, from: rawEntity, shared: self))
        }
    }

    func getEntity(byName name: String) -> Entity? {
        if let systemEntity = EntityType.System(rawValue: name)?.entity {
            return systemEntity
        }

        return self.entities.first(where: { $0.name == name })
    }
}
