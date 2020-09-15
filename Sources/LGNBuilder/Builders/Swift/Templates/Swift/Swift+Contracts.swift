extension Template.Swift {
    static func contracts(from contracts: [String: Contract], service: Service, shared: Shared) -> String {
        contracts
            //.sorted
            .map { Template.Swift.contract(from: $1, service: service, shared: shared) }
            .joined(separator: "\n\n")
    }

    static func contract(from contract: Contract, service: Service, shared: Shared) -> String {
        """
        enum \(contract.name): Contract {
            \(blocks([
                "public typealias ParentService = Services.\(service.name)",
                Template.Swift.entityTypealiases(from: contract),
                "public static let URI = \"\(contract.URI ?? contract.name)\"",
                "public static let transports: [LGNCore.Transport] = [\(contract.transports.map { "." + $0.rawValue }.joined(separator: ", "))]",
                "public static var guaranteeClosure: Optional<Closure> = nil",
                "public static let contentTypes: [LGNCore.ContentType] = \(Template.Swift.contentTypes(from: contract.contentTypes).indented(1))",
                "",
                "static let visibility: ContractVisibility = \(contract.isPublic ? ".Public" : ".Private")",
                Template.Swift.contractEntities(from: contract, shared: shared),
            ], indent: 1, separator: "\n"))
        }
        """
    }

    static func contentTypes(from maybeContentTypes: [ContentType]?) -> String {
        let result: String

        if let contentTypes = maybeContentTypes {
            result = "[ \(contentTypes.map { "." + $0.rawValue }.joined(separator: ", ")) ]"
        } else {
            result = "LGNCore.ContentType.allCases"
        }

        return result
    }

    static func entityTypealias(from entityType: EntityType, name: String) -> String {
        guard case .shared(let entity) = entityType else {
            return ""
        }

        return "public typealias \(name) = \(entityType.isSharedEmpty ? "LGNC.Entity" : "Services.Shared").\(entity.name)"
    }

    static func entityTypealiases(from contract: Contract) -> String {
        var result = [
            Template.Swift.entityTypealias(from: contract.request, name: "Request"),
            Template.Swift.entityTypealias(from: contract.response, name: "Response"),
        ]
            .filter { $0.count > 0 }
            .joined(separator: "\n")

        if result.count > 0 {
            result = "\n\(result)\n"
        }

        return result
    }

    static func contractEntities(from contract: Contract, shared: Shared) -> String {
        var result = [contract.request, contract.response]
            .compactMap {
                guard case .entity(let entity) = $0 else {
                    return nil
                }
                return entity
            }
            .map { Template.Swift.entity(from: $0, shared: shared, isPublic: true) }
            .joined(separator: "\n\n")

        if result.count > 0 {
            result = "\n\(result)"
        }

        return result
    }
}
