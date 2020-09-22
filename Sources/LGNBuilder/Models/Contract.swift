typealias Contracts = [(String, Contract)]

struct Contract {
    let name: String
    let URI: String?
    let contentTypes: [ContentType]?
    var transports: [Transport]
    let generateServicewiseExecutors: Bool
    let generateServicewiseGuarantee: Bool
    let generateServicewiseValidators: Bool
    let request: EntityType
    let response: EntityType
    let isPublic: Bool
    let isGETSafe: Bool

    init(
        name: String,
        URI: String?,
        contentTypes: [ContentType]?,
        transports: [Transport],
        generateServicewiseExecutors: Bool,
        generateServicewiseGuarantee: Bool,
        generateServicewiseValidators: Bool,
        request: EntityType,
        response: EntityType,
        isPublic: Bool,
        isGETSafe: Bool
    ) {
        self.name = name
        self.URI = URI
        self.contentTypes = contentTypes
        self.transports = transports
        self.generateServicewiseExecutors = generateServicewiseExecutors
        self.generateServicewiseGuarantee = generateServicewiseGuarantee
        self.generateServicewiseValidators = generateServicewiseValidators
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
        case generateServicewiseExecutors = "GenerateServicewiseExecutors"
        case generateServicewiseGuarantee = "GenerateServicewiseGuarantee"
        case generateServicewiseValidators = "GenerateServicewiseValidators"
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
                throw E.InvalidSchema(
                    "\(errorPrefix): transport '\(transport)' is not in allowed transports list (\(allowedTransports))"
                )
            }
            return transport
        }

        if rawInput[Key.request] == nil {
            rawInput[Key.request] = EntityType.System.Empty.rawValue
        }
        if rawInput[Key.response] == nil {
            rawInput[Key.response] = EntityType.System.Empty.rawValue
        }

        let request: EntityType = try Self.initEntity(
            from: rawInput,
            as: .request,
            shared: shared,
            errorPrefix: errorPrefix
        )
        let response: EntityType = try Self.initEntity(
            from: rawInput,
            as: .response,
            shared: shared,
            errorPrefix: errorPrefix
        )

        let isGETSafe = rawInput[Key.isGETSafe] as? Bool ?? false
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
            generateServicewiseExecutors: rawInput[Key.generateServicewiseExecutors] as? Bool ?? false,
            generateServicewiseGuarantee: rawInput[Key.generateServicewiseGuarantee] as? Bool ?? false,
            generateServicewiseValidators: rawInput[Key.generateServicewiseValidators] as? Bool ?? false,
            request: request,
            response: response,
            isPublic: rawInput[Key.isPublic] as? Bool ?? false,
            isGETSafe: isGETSafe
        )
    }

    fileprivate static func initEntity(
        from input: Dict,
        as key: Key,
        shared: Shared,
        errorPrefix: String
    ) throws -> EntityType {
        let result: EntityType

        guard input[key] != nil else {
            throw E.InvalidSchema(
                "\(errorPrefix): missing or invalid key '\(key.rawValue)' '(input: \(input)')"
            )
        }
        if let rawResult = input[key] as? String {
            guard let sharedEntity = shared.getEntity(byName: rawResult) else {
                throw E.InvalidSchema(
                    "\(errorPrefix): could not find \(key.rawValue) entity '\(rawResult)' in shared '(input: \(input)')"
                )
            }
            result = .shared(sharedEntity)
        } else {
            result = try .init(Entity(
                name: key.rawValue,
                from: input[key] as Any,
                shared: shared
            ))
        }

        return result
    }
}
