import Foundation

extension Template.Swift {
    static func entities(_ entities: [Entity], shared: Shared) -> String {
        entities
            //.sorted(by: { $0.name < $1.name })
            .map { Template.Swift.entity(from: $0, shared: shared) }
            .joined(separator: "\n\n")
    }

    static func entity(from entity: Entity, shared: Shared, isPublic: Bool = false) -> String {
        """
        \(isPublic ? "public " : "")final class \(entity.name): ContractEntity {
            \(blocks([
                Template.Swift.entityKeyDictionary(from: entity),
                Template.Swift.hasCookiedFields(from: entity),
                Template.Swift.validationCallbackVars(from: entity),
                Template.Swift.enums(from: entity),
                Template.Swift.classFields(from: entity),
                Template.Swift.initializerCallbacksVars(from: entity),
                Template.Swift.mainInit(from: entity),
                Template.Swift.initWithValidation(from: entity, shared: shared),
                Template.Swift.initFromDictionary(from: entity),
                Template.Swift.getDictionary(from: entity),
                Template.Swift.validationCallbacksSetters(from: entity),
                Template.Swift.initializerCallbacksSetters(from: entity),
            ], indent: 1).removingDoubleNewlines())
        }
        """
    }

    static func initializerCallbacksSetters(from entity: Entity) -> String {
        entity
            .fields
            .filter { $0.alwaysInitiated }
            .map { field in
                """
                public static func initialize\(field.name)(_ callback: @escaping \(Template.Swift.callbackInitializerType(field: field, entityName: entity.name)) {
                    self.initializer\(field.name.firstUppercased)Closure = callback
                }
                """
            }
            .joined(separator: "\n\n")
    }

    static func validationCallbacksSetters(from entity: Entity) -> String {
        entity
            .validationCallbacks
            .map { (name: String, tuple) in
                let (type, errors) = tuple
                let callbackType = Template.Swift.validationCallbackType(fieldName: name, type: type, errors: errors)

                var result = """
                public static func validate\(name.firstUppercased)(
                    _ callback: @escaping \(callbackType).Callback
                ) {
                    self.validator\(name.firstUppercased)Closure = callback
                }
                """

                if errors.count == 0 {
                    result += """


                    public static func validate\(name.firstUppercased)(
                        _ callback: @escaping \(callbackType).CallbackWithSingleError
                    ) {
                        self.validate\(name.firstUppercased) { (value) async -> [ErrorTuple]? in
                            guard let error = await callback(value) else {
                                return nil
                            }
                            return [error]
                        }
                    }
                    """
                }

                return result
            }
            .joined(separator: "\n\n")
    }

    static func getDictionary(from entity: Entity) -> String {
        """
        public func getDictionary() throws -> Entita.Dict {
            [
                \(Template.Swift.getDictionaryList(from: entity).indented(2))
            ]
        }
        """
    }

    static func getDictionaryList(from entity: Entity) -> String {
        let result: String

        if entity.fields.count == 0 {
            result = ":"
        } else {
            result = entity
                .fields
                .map { field in
                    "self.getDictionaryKey(\"\(field.name)\"): try self.encode(self.\(field.name)),"
                }
                .joined(separator: "\n")
        }

        return result
    }

    static func initFromDictionary(from entity: Entity) -> String {
        """
        public convenience init(from dictionary: Entita.Dict) throws {
            self.init(
                \(Template.Swift.initFieldsFromDictionary(from: entity).indented(2))
            )
        }
        """
    }

    static func initFieldsFromDictionary(from entity: Entity) -> String {
        entity
            .fields
            .filter { $0.alwaysInitiated == false }
            //.sorted(by: { $0.name < $1.name })
            .map { field in
                "\(field.name): try \(entity.name).extract(param: \"\(field.name)\", from: dictionary\(field.isNullable ? ", isOptional: true" : ""))"
            }
            .joined(separator: ",\n")
    }

    static func initWithValidation(from entity: Entity, shared: Shared) -> String {
        """
        public static func initWithValidation(from dictionary: Entita.Dict) async throws -> Self {
            \(Template.Swift.ensureNecessaryItems(from: entity).indented(1))

            \(entity
                .fields
                .map { field in
                    let declaration = "let \(field.internalName): \(Template.Swift.prepareType(field: field))?\(field.isNullable ? "?" : "")"
                    let result: String

                    if field.type.isCookie {
                        result = """
                        \(declaration) = try await self.extractCookie(param: \"\(field.name)\", from: dictionary)
                        """
                    } else {
                        let assign = "try? (self.extract(param: \"\(field.name)\", from: dictionary\(field.isNullable ? ", isOptional: true" : "")) as \(Template.Swift.prepareType(field: field))\(field.isNullable ? "?" : ""))"
                        result = "\(declaration) = \(assign)"
                    }

                    return result
                }
                .joined(separator: "\n")
                .indented(1)
            )

            let validatorClosures: [String: ValidationClosure] = [
                \(entity.fields.count == 0
                    ? ":"
                    : entity
                        .fields
                        .map { field in
                            """
                            "\(field.name)": \(Template.Swift.validationClosuressChain(from: field, entity: entity, shared: shared)),
                            """
                        }
                        .joined(separator: "\n")
                        .removedSingleNewlines
                        .indented(2)
                )
            ]

            let validationErrors = await self.reduce(closures: validatorClosures)
            guard validationErrors.isEmpty else {
                throw LGNC.E.DecodeError(validationErrors)
            }

            return self.init(
                \(Template.Swift.initEntityFromVars(from: entity, forceUnwrap: true).indented(2))
            )
        }
        """
    }

    static func ensureNecessaryItems(from entity: Entity) -> String {
        """
        try self.ensureNecessaryItems(
            in: dictionary,
            necessaryItems: [
                \(entity
                    .fields
                    .map {
                        """
                        "\($0.name)",
                        """
                    }
                    .joined(separator: "\n")
                    .indented(2)
                )
            ]
        )
        """
    }

    static func validationClosuressChain(from field: Field, entity: Entity, shared: Shared) -> String {
        var isOptionalThrow: String = ""
        if field.isNullable {
            isOptionalThrow =
            """

            if \(Field.internalPrefix) == nil {
                throw Validation.Error.SkipMissingOptionalValueValidators()
            }
            """.indented(1)
        }
        return """
        {
            guard let \(field.isNullable ? Field.internalPrefix : "_") = \(field.internalName) else {
                throw Validation.Error.MissingValue(\(field.missingMessage.map { "message: \"\($0)\"" } ?? ""))
            }\(isOptionalThrow)
            \(field
                .validators
                .map { anyValidator in
                    """
                    \(Template.Swift.validator(from: anyValidator, field: field, entity: entity, shared: shared))
                    """
                }
                .joined(separator: "\n")
            )
        }
        """
    }

    static func validator(from anyValidator: AnyValidator, field: Field, entity: Entity, shared: Shared) -> String {
        let internalName = field.isNullable ? "unwrapped_\(field.internalName)" : field.internalName
        let validate = "validate(\(internalName)!)"

        func message(validator: AnyValidator, comma: Bool = true) -> String {
            validator.message.map { "\(comma ? ", " : "")message: \"\($0)\"" } ?? ""
        }

        var result: String = "try await Validation."

        switch anyValidator {
        case let validator as Validator.Regex:
            result +=
                """
                Regexp(pattern: "\(validator.expression)"\(message(validator: validator))).\(validate)
                """
        case let validator as Validator.In:
            let allowedValues = validator.allowedValues.map { "\"\($0)\"" }.joined(separator: ", ")
            result +=
                """
                In(allowedValues: [\(allowedValues)]\(message(validator: validator))).\(validate)
                """
        case let validator as Validator.NotEmpty:
            result +=
                """
                NotEmpty(\(message(validator: validator, comma: false))).\(validate)
                """
        case let validator as Validator.UUID:
            result +=
                """
                UUID(\(message(validator: validator, comma: false))).\(validate)
                """
        case let validator as Validator.Length:
            let name: String
            switch validator {
            case let concreteValidator as Validator.MinLength: name = concreteValidator.name
            case let concreteValidator as Validator.MaxLength: name = concreteValidator.name
            default: fatalError("Unknown length validator \(validator)")
            }
            result +=
                """
                Length.\(name)(length: \(validator.length)\(message(validator: validator))).\(validate)
                """
        case let validator as Validator.IdenticalWith:
            result +=
                """
                Identical(right: \(validator.fieldInternal)!\(message(validator: validator))).\(validate)
                """
        case let validator as Validator.Date:
            let format = validator.format ?? shared.dateFormat
            result +=
                """
                Date(\(format.map { "format: \"\($0)\"" } ?? "")\(message(validator: validator, comma: format != nil))).\(validate)
                """
        case let validator as Validator.Callback:
            result =
                """
                if let validator = self.validator\(field.name.firstUppercased)Closure {
                    try await \(Template.Swift.callbackValidatorType(fieldName: field.name, type: field.type, errors: validator.errors))(callback: validator).validate(\(internalName)!)
                }
                """.indented(1, includingFirst: true)
        case let validator as Validator.Cumulative:
            result +=
                """
                cumulative([
                    \(validator
                        .validators
                        .map {
                            """
                            {
                                \(Template.Swift
                                    .validator(from: $0, field: field, entity: entity, shared: shared)
                                    .indented(1)
                                )
                            },
                            """
                        }
                        .joined(separator: "\n")
                        .indented(1)
                    )
                ])
                """.indented(1)
        default: fatalError("Unknown validator \(anyValidator)")
        }

        if field.isNullable {
            result =
                """
                if let \(internalName) = \(field.internalName) {
                    \(result.indented(1))
                }
                """.indented(1)
        }

        return result
    }

    static func initEntityFromVars(from entity: Entity, prefix: String = "", forceUnwrap: Bool = false) -> String {
        entity
            .fields
            .filter { $0.alwaysInitiated == false }
            //.sorted(by: { $0.name < $1.name })
            .map { field in
                "\(field.name): \(prefix)\(field.internalName)\(forceUnwrap ? "!" : "")"
            }
            .joined(separator: ",\n")
    }

    static func mainInit(from entity: Entity) -> String {
        """
        public init(\(Template.Swift.mainInitArguments(from: entity))) {
            \(Template.Swift.mainInitAssign(from: entity).indented(1))
        }
        """
    }

    static func mainInitArguments(from entity: Entity, addFutures: Bool = false) -> String {
        let resultParts: [String] = entity
            .fields
            .filter { $0.alwaysInitiated == false }
            //.sorted(by: { $0.name < $1.name })
            .map { field in
                let fieldName = field.name
                let argumentName = addFutures && field.canBeFuture ? " \(fieldName)Future" : ""
                let type = Template.Swift.prepareType(field: field, addFuture: addFutures)
                let isOptional = field.isNullable ? "?" : ""
                let defaultAssign = field.defaultEmpty ? " = \(field.isNullable ? "nil" : Template.Swift.prepareType(field: field, addFuture: addFutures) + "()")" : ""
                return "\(fieldName)\(argumentName): \(type)\(isOptional)\(defaultAssign)"
            }

        let result: String

        if resultParts.joined(separator: ", ").count > 80 {
            result = "\n" + resultParts.joined(separator: ",\n").indented(1, includingFirst: true) + "\n"
        } else {
            result = resultParts.joined(separator: ", ")
        }

        return result
    }

    static func mainInitAssign(from entity: Entity) -> String {
        entity
            .fields
            .filter { $0.alwaysInitiated == false }
            .map { "self.\($0.name) = \($0.name)" }
            .joined(separator: "\n")
    }

    static func enums(from entity: Entity) -> String {
        func getShortName(from error: Validator.Callback.Error) -> String {
            var safe = CharacterSet.alphanumerics
            safe.insert(" ")
            let unsafe = safe.inverted

            var result = error.shortName ?? error
                .message
                .components(separatedBy: unsafe)
                .joined(separator: "")
                .capitalized
                .replacingOccurrences(of: " ", with: "")

            if result.first!.isNumber {
                result = "_\(result)"
            }

            return result
        }

        return entity
            .fields
            .filter { field -> Bool in
                field.validators.contains(where: { ($0 as? Validator.Callback)?.errors.count ?? 0 > 0 })
            }
            .map { (field) -> (field: Field, enums: [(String, Validator.Callback.Error)]) in
                return (
                    field: field,
                    enums: (field.validators.first(where: { $0 is Validator.Callback }) as! Validator.Callback)
                        .errors
                        .map { error in
                            (
                                getShortName(from: error),
                                error
                            )
                        }
                )
            }
            .map(Template.Swift.enum)
            .joined(separator: "\n\n")
    }

    static func `enum`(field: Field, enums: [(String, Validator.Callback.Error)]) -> String {
        """
        public enum CallbackValidator\(field.name.firstUppercased)AllowedValues: String, CallbackWithAllowedValuesRepresentable, ValidatorErrorRepresentable {
            public typealias InputValue = \(field.type.asString)

            \(enums
                .map { name, error in "case \(name) = \"\(error.message)\"" }
                .joined(separator: "\n")
                .indented(1)
            )

            public func getErrorTuple() -> ErrorTuple {
                switch self {
                    \(enums
                        .map { name, error in "case .\(name): return (code: \(error.code), message: self.rawValue)" }
                        .joined(separator: "\n")
                        .indented(3)
                    )
                }
            }
        }
        """
    }

    static func entityKeyDictionary(from entity: Entity) -> String {
        """
        public static let keyDictionary: [String: String] = [\(
            entity.keyDictionary.isEmpty
                ? ":"
                : "\n" + entity.keyDictionary.map { "\"\($0)\": \"\($1)\"" }.joined(separator: ",\n").indented(1) + "\n"
        )]
        """
    }

    static func hasCookiedFields(from entity: Entity) -> String {
        guard !entity.fields.filter(\.type.isCookie).isEmpty else {
            return ""
        }

        return """
        public static let hasCookieFields: Bool = true
        """
    }

    static func classFields(from entity: Entity) -> String {
        entity
            .fields
            .map { field in
                let visibility = "public"
                let declaration = field.alwaysInitiated || field.isMutable ? "var" : "let"
                let name = field.name
                let type = Template.Swift.prepareType(field: field)
                let optional = field.isNullable ? "?" : ""

                return "\(visibility) \(declaration) \(name): \(type)\(optional)"
            }
            .joined(separator: "\n")
    }

    static func validationCallbackVars(from entity: Entity) -> String {
        entity
            .validationCallbacks
            .map { (name: String, tuple) in
                let (type, errors) = tuple
                let callbackType = Template.Swift.validationCallbackType(fieldName: name, type: type, errors: errors)
                return "private static var validator\(name.firstUppercased)Closure: \(callbackType).Callback? = nil"
            }
            .joined(separator: "\n")
    }

    static func validationCallbackType(
        fieldName: String,
        type: FieldType,
        errors: [Validator.Callback.Error],
        prefix: String = ""
    ) -> String {
        var result = "Validation.Callback"

        if errors.count > 0 {
            result += "WithAllowedValues<\(prefix)CallbackValidator\(fieldName.firstUppercased)AllowedValues>"
        } else {
            result += "<\(type.asString)>"
        }

        return result
    }

    static func initializerCallbacksVars(from entity: Entity) -> String {
        entity
            .initializerCallbacks
            .map { field in
                "private static var initializer\(field.name.firstUppercased)Closure: (\(Template.Swift.callbackInitializerType(field: field, entityName: entity.name)))? = nil"
            }
            .joined(separator: "\n")
    }

    static func callbackInitializerType(field: Field, entityName: String) -> String {
        "(\(entityName)) throws -> \(field.type.asString.replacingOccurrences(of: "!", with: ""))"
    }
}
