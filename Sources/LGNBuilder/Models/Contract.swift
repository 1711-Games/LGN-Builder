typealias Contracts = [(String, Contract)]

struct Contract {
    let name: String
    let URI: String?
    let contentTypes: [ContentType]?
    var transports: [Transport]
    let generateServiceWiseExecutors: Bool
    let generateServiceWiseGuarantee: Bool
    let generateServiceWiseValidators: Bool
    let request: EntityType
    let response: EntityType
    let isPublic: Bool
    let isGETSafe: Bool

    init(
        name: String,
        URI: String?,
        contentTypes: [ContentType]?,
        transports: [Transport],
        generateServiceWiseExecutors: Bool,
        generateServiceWiseGuarantee: Bool,
        generateServiceWiseValidators: Bool,
        request: EntityType,
        response: EntityType,
        isPublic: Bool,
        isGETSafe: Bool
    ) {
        self.name = name
        self.URI = URI
        self.contentTypes = contentTypes
        self.transports = transports
        self.generateServiceWiseExecutors = generateServiceWiseExecutors
        self.generateServiceWiseGuarantee = generateServiceWiseGuarantee
        self.generateServiceWiseValidators = generateServiceWiseValidators
        self.request = request
        self.response = response
        self.isPublic = isPublic
        self.isGETSafe = isGETSafe
    }

    mutating func excludeTransports(_ allowedTransports: [Transport: Int]) -> Self {
        return self
    }
}

extension Contract: Model {
    enum Key: String {
        case transports = "Transports"
        case URI = "URI"
        case contentTypes = "ContentTypes"
        case generateServiceWiseExecutors = "GenerateServiceWiseExecutors"
        case generateServiceWiseGuarantee = "GenerateServiceWiseGuarantee"
        case generateServiceWiseValidators = "GenerateServiceWiseValidators"
        case request = "Request"
        case response = "Response"
        case isPublic = "IsPublic"
        case isGETSafe = "IsGETSafe"
    }

    @available(*, deprecated, message: "Use init(name:from:allowedTransports:)")
    init(from input: Any) throws {
        throw E.InvalidSchema("Use init(name:from:allowedTransports:)")
    }

    init(name: String, from input: Any, allowedTransports: [Transport], shared: Shared) throws {
        let errorPrefix = "Could not decode contract '\(name)'"

        guard var rawInput = input as? Dict else {
            throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
        }

        let contentTypes: [ContentType]?
        if let rawContentTypes = rawInput[Key.contentTypes] as? [String] {
            contentTypes = try rawContentTypes.map {
                guard let contentType = ContentType(rawValue: $0) else {
                    throw E.InvalidSchema("\(errorPrefix): could not decode content type from '\($0)'")
                }
                return contentType
            }
        } else {
            contentTypes = nil
        }

        if rawInput[Key.transports] == nil {
            print("Assuming default transports (\(defaultTransports)) for contract '\(name)'")
            rawInput[Key.transports] = []
        }

        guard let rawTransports = rawInput[Key.transports] as? [Any] else {
            throw E.InvalidSchema("\(errorPrefix): input does not contain '\(Key.transports.rawValue)' key or invalid")
        }
        let transports: [Transport] = try rawTransports.compactMap { rawTransport in
            guard let rawValue = rawTransport as? String, let transport = Transport(rawValue: rawValue) else {
                throw E.InvalidSchema("\(errorPrefix): unknown transport '\(rawTransport)'")
            }
            if !allowedTransports.contains(transport) {
                print("Ignoring transport '\(transport)' as it's not in allowed transports list (\(allowedTransports))")
                return nil
            }
            return transport
        }

        if rawInput[Key.request] == nil {
            rawInput[Key.request] = EntityType.System.Empty.rawValue
        }
        if rawInput[Key.response] == nil {
            rawInput[Key.response] = EntityType.System.Empty.rawValue
        }

        let request: EntityType
        guard rawInput[Key.request] != nil else {
            throw E.InvalidSchema(
                "\(errorPrefix): missing or invalid key '\(Key.request.rawValue)' '(input: \(rawInput)')"
            )
        }
        if let rawRequest = rawInput[Key.request] as? String {
            guard let sharedRequestEntity = shared.getEntity(byName: rawRequest) else {
                throw E.InvalidSchema(
                    "\(errorPrefix): could not find request entity '\(rawRequest)' in shared '(input: \(rawInput)')"
                )
            }
            request = .shared(sharedRequestEntity)
        } else {
            request = try .init(Entity(
                name: "Request",
                from: rawInput[Key.request] as Any,
                shared: shared
            ))
        }

        let response: EntityType
        guard rawInput[Key.response] != nil else {
            throw E.InvalidSchema(
                "\(errorPrefix): missing or invalid key '\(Key.response.rawValue)' '(input: \(rawInput)')"
            )
        }
        if let rawResponse = rawInput[Key.response] as? String {
            guard let sharedResponseEntity = shared.getEntity(byName: rawResponse) else {
                throw E.InvalidSchema(
                    "\(errorPrefix): could not find response entity '\(rawResponse)' in shared '(input: \(rawInput)')"
                )
            }
            response = .shared(sharedResponseEntity)
        } else {
            response = try .init(Entity(
                name: "Response",
                from: rawInput[Key.response] as Any,
                shared: shared
            ))
        }

        let isGETSafe = rawInput[Key.isGETSafe] as? Bool ?? false
        if transports.contains(.LGNS) {
            [request, response].forEach { entityType in
//                let entity: Entity
//
//                switch entityType {
//                case let .entity(_entity), let .shared(_entity): entity = _entity
//                }
//
//                let cookieFields = entity.fields.filter(\.type.isCookie)
//                if !cookieFields.isEmpty {
//                    print(
//                        """
//                        Warning: entity '\(entity.name)' in LGNS contract '\(self.name)' \
//                        has field\(cookieFields.count > 1 ? "s": "") \
//                        \(cookieFields.map { "'\($0.name)'" }.joined(separator: ", ")) of type 'Cookie', \
//                        which isn't recommended because cookies is a HTTP concept. Still, your contract \
//                        isn't invalid, but you should consider reorganising your contract/entity.
//                        """
//                    )
//                }
            }
        }

        if isGETSafe {
            if !transports.contains(.HTTP) {
                throw E.InvalidSchema(
                    """
                    \(errorPrefix): IsGETSafe is set to 'true', but contract doesn't have HTTP transport
                    """
                )
            }

            let nonGETSafeFields = request.wrapped.fields.filter { !$0.type.isGETSafe }
            if nonGETSafeFields.count > 0 {
                throw E.InvalidSchema(
                    """
                    \(errorPrefix): IsGETSafe is set to 'true', but contract has non-GET-safe fields: \
                    \(nonGETSafeFields
                        .map { "'\($0.name)' (of type '\($0.type.asString)')" }
                        .joined(separator: ", ")
                    )
                    """
                )
            }
        }

        self.init(
            name: name,
            URI: rawInput[Key.URI] as? String,
            contentTypes: contentTypes,
            transports: transports,
            generateServiceWiseExecutors: rawInput[Key.generateServiceWiseExecutors] as? Bool ?? false,
            generateServiceWiseGuarantee: rawInput[Key.generateServiceWiseGuarantee] as? Bool ?? false,
            generateServiceWiseValidators: rawInput[Key.generateServiceWiseValidators] as? Bool ?? false,
            request: request,
            response: response,
            isPublic: rawInput[Key.isPublic] as? Bool ?? false,
            isGETSafe: isGETSafe
        )
    }
}
