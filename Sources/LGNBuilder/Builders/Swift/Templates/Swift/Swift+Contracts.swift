extension Template.Swift {
    static func contracts(from contracts: Contracts, service: Service, shared: Shared) -> String {
        contracts
            //.sorted
            .map { Template.Swift.contract(from: $1, service: service, shared: shared) }
            .joined(separator: "\n\n")
    }

    static func contract(from contract: Contract, service: Service, shared: Shared) -> String {
        let className: String

        if contract.isResponseStructured {
            className = "Structured"
        } else if contract.isResponseHTML {
            className = "HTML"
        } else if contract.isResponseFile {
            className = "File"
        } else {
            className = "Impossible"
        }

        return """
        enum \(contract.name): \(className)Contract {
            \(blocks([
                "public typealias ParentService = Services.\(service.name)",
                Template.Swift.entityTypealiases(from: contract),
                "public static let URI = \"\(contract.URI ?? contract.name)\"",
                "public static let transports: [LGNCore.Transport] = [\(contract.transports.map { "." + $0.rawValue }.joined(separator: ", "))]",
                contract.isResponseStructured == false ? "public static let isResponseStructured: Bool = false" : "",
                "public static var _guaranteeBody: Optional<CanonicalGuaranteeBody> = nil",
                "public static let contentTypes: [LGNCore.ContentType] = \(Template.Swift.contentTypes(from: contract.contentTypes).indented(1))",
                contract.isGETSafe ? "public static let isGETSafe = true" : "",
                "",
                Template.Swift.contractEntities(from: contract, shared: shared),
            ], indent: 1, separator: "\n").removingDoubleNewlines())
        }
        """
    }

    static func contentTypes(from maybeContentTypes: [ContentType]?) -> String {
        let result: String

        if let contentTypes = maybeContentTypes {
            result = "[ \(contentTypes.map { "." + $0.rawValue }.joined(separator: ", ")) ]"
        } else {
            result = "LGNCore.ContentType.allowedHTTPTypes"
        }

        return result
    }

    static func entityTypealias(from entityType: EntityType, name: String) -> String {
        guard entityType.isShared else {
            return ""
        }

        return "public typealias \(name) = \(entityType.wrapped.preparedName)"
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
            .compactMap { $0.isShared ? nil : $0.wrapped }
            .map { Template.Swift.entity(from: $0, shared: shared, isPublic: true) }
            .joined(separator: "\n\n")

        if result.count > 0 {
            result = "\n\(result)"
        }

        return result
    }
}
