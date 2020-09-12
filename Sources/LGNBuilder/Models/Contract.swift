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
    }

    static let emptyEntity = "Empty"

    @available(*, deprecated, message: "Use init(name:from:allowedTransports:)")
    init(from input: Any) throws {
        throw E.InvalidSchema("Use init(name:from:allowedTransports:)")
    }

    init(name: String, from input: Any, allowedTransports: [Transport], shared: Dict) throws {
        self.name = name

        let errorPrefix = "Could not decode contract"

        guard var rawInput = input as? Dict else {
            throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
        }

        self.URI = rawInput[Key.URI] as? String

        if let rawContentTypes = rawInput[Key.contentTypes] as? [String] {
            self.contentTypes = try rawContentTypes.map {
                guard let contentType = ContentType(rawValue: $0) else {
                    throw E.InvalidSchema("\(errorPrefix): could not decode content type from '\($0)'")
                }
                return contentType
            }
        } else {
            self.contentTypes = nil
        }

        if rawInput[Key.transports] == nil {
            print("Assuming default transports (\(defaultTransports)) for contract")
            rawInput[Key.transports] = []
        }

        guard let rawTransports = rawInput[Key.transports] as? [Any] else {
            throw E.InvalidSchema("\(errorPrefix): input does not contain '\(Key.transports.rawValue)' key or invalid")
        }
        self.transports = try rawTransports.compactMap { rawTransport in
            guard let rawValue = rawTransport as? String, let transport = Transport(rawValue: rawValue) else {
                throw E.InvalidSchema("\(errorPrefix): unknown transport '\(rawTransport)'")
            }
            if !allowedTransports.contains(transport) {
                print("Ignoring transport '\(transport)' as it's not in allowed transports list (\(allowedTransports))")
                return nil
            }
            return transport
        }
        self.generateServiceWiseExecutors = rawInput[Key.generateServiceWiseExecutors] as? Bool ?? false
        self.generateServiceWiseGuarantee = rawInput[Key.generateServiceWiseGuarantee] as? Bool ?? false
        self.generateServiceWiseValidators = rawInput[Key.generateServiceWiseValidators] as? Bool ?? false
        self.isPublic = rawInput[Key.isPublic] as? Bool ?? false

        if rawInput[Key.request] == nil {
            rawInput[Key.request] = Self.emptyEntity
        }
        if rawInput[Key.response] == nil {
            rawInput[Key.response] = Self.emptyEntity
        }

        let request: EntityType
        guard rawInput[Key.request] != nil else {
            throw E.InvalidSchema(
                "\(errorPrefix): missing or invalid key '\(Key.request.rawValue)' '(input: \(input)')"
            )
        }
        if let rawRequest = rawInput[Key.request] as? String {
            request = .shared(rawRequest)
        } else {
            request = try .entity(Entity(
                name: "Request",
                from: rawInput[Key.request] as Any,
                shared: shared
            ))
        }
        self.request = request

        let response: EntityType
        guard rawInput[Key.response] != nil else {
            throw E.InvalidSchema(
                "\(errorPrefix): missing or invalid key '\(Key.response.rawValue)' '(input: \(input)')"
            )
        }
        if let rawResponse = rawInput[Key.response] as? String {
            response = .shared(rawResponse)
        } else {
            response = try .entity(Entity(
                name: "Response",
                from: rawInput[Key.response] as Any,
                shared: shared
            ))
        }
        self.response = response
    }
}
