struct Field {
    let name: String
    let type: FieldType
    let validators: [AnyValidator]
    let canBeFuture: Bool
    var isMutable: Bool
    let isNullable: Bool
    let alwaysInitiated: Bool
    let defaultEmpty: Bool
    let defaultNull: Bool
    let missingMessage: String?

    init(
        name: String,
        type: FieldType,
        validators: [AnyValidator],
        canBeFuture: Bool,
        isMutable: Bool,
        isNullable: Bool,
        alwaysInitiated: Bool,
        defaultEmpty: Bool,
        defaultNull: Bool,
        missingMessage: String?
    ) {
        self.name = name
        self.type = type
        self.validators = validators
        self.canBeFuture = canBeFuture
        self.isMutable = isMutable
        self.isNullable = isNullable
        self.alwaysInitiated = alwaysInitiated
        self.defaultEmpty = defaultEmpty
        self.defaultNull = defaultNull
        self.missingMessage = missingMessage
    }

    mutating func setMutable(_ isMutable: Bool) -> Self {
        self.isMutable = isMutable

        return self
    }
}

extension Field: Model {
    enum Key: String {
        case type = "Type"
        case validators = "Validators"
        case canBeFuture = "CanBeFuture"
        case isNotEmpty = "NotEmpty"
        case isMutable = "IsMutable"
        case isNullable = "IsNullable"
        case alwaysInitiated = "AlwaysInitiated"
        case allowedValues = "AllowedValues"
        case defaultEmpty = "DefaultEmpty"
        case defaultNull = "DefaultNull"
        case missingMessage = "MissingMessage"
    }

    @available(*, deprecated, renamed: "init(name:from:)")
    init(from input: Any) throws {
        throw E.InvalidSchema("Use init(name:from:shared:) instead")
    }

    init(name: String, from input: Any, shared: Shared) throws {
        let errorPrefix = "Could not decode field '\(name)'"

        if let type = input as? String {
            self = Self.init(
                name: name,
                type: try .init(from: type, shared: shared),
                validators: [],
                canBeFuture: false,
                isMutable: false,
                isNullable: false,
                alwaysInitiated: false,
                defaultEmpty: false,
                defaultNull: false,
                missingMessage: nil
            )
            return
        }

        guard var rawInput = input as? Dict else {
            throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
        }
        guard let rawType = rawInput[Key.type] as? String else {
            throw E.InvalidSchema("\(errorPrefix): missing key '\(Key.type.rawValue)' (input: \(input))")
        }
        let type = try FieldType(from: rawType, shared: shared)
        // Only `String`s can have `NotEmpty` validator
        if !type.isString && (rawInput[Key.isNotEmpty] as? Bool) == true {
            rawInput["NotEmpty"] = false
        }
        var validators: [AnyValidator]
        if let rawValidators = rawInput[Key.validators] as? Dict {
            validators = try rawValidators.map { name, params in try Validator.initFrom(name: name, params: params) }
        } else if let rawValidators = rawInput[Key.validators] as? [String] {
            validators = try rawValidators.map { try Validator.initFrom(name: $0) }
        } else {
            validators = []
        }

        var isNullable: Bool = rawInput[Key.isNullable] as? Bool ?? false
        var defaultEmpty: Bool = rawInput[Key.defaultEmpty] as? Bool ?? false
        let defaultNull: Bool = rawInput[Key.defaultNull] as? Bool ?? false
        if defaultNull {
            isNullable = true
            defaultEmpty = true
        }

        if
            let notEmpty = rawInput[Key.isNotEmpty] as? Bool,
            notEmpty == true,
            isNullable == false,
            !validators.contains(where: { $0 is Validator.NotEmpty })
        {
            validators.append(Validator.NotEmpty(message: rawInput[Key.missingMessage] as? String))
        }

        if let allowedValues = rawInput[Key.allowedValues] as? [String] {
            validators.append(Validator.In(allowedValues: allowedValues))
        }

        self = Self.init(
            name: name,
            type: type,
            validators: validators,
            canBeFuture: rawInput[Key.canBeFuture] as? Bool ?? false,
            isMutable: rawInput[Key.isMutable] as? Bool ?? false,
            isNullable: isNullable,
            alwaysInitiated: rawInput[Key.alwaysInitiated] as? Bool ?? false,
            defaultEmpty: defaultEmpty,
            defaultNull: defaultNull,
            missingMessage: rawInput[Key.missingMessage] as? String
        )
    }
}
