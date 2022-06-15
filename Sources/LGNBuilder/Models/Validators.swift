import Foundation

protocol AnyValidator: Model {
    var name: String { get }
    var message: String? { get }

    func performSanityCheck(entity: Entity) throws
}

extension AnyValidator {
    var name: String {
        "\(Self.self)Validator"
    }

    func performSanityCheck(entity: Entity) throws {

    }

    static func getMessage(from input: Dict) throws -> String? {
        guard var message = input["Message"] as? String else {
            return nil
        }

        let regex = try NSRegularExpression(pattern: "\\{(\\w+)\\}")

        for match in regex.matches(in: message, range: NSRange(location: 0, length: message.utf16.count)) {
            let substring = (message as NSString).substring(with: match.range)
            let cleanSubstring = substring
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: "}", with: "")

            guard let value = input[cleanSubstring] as? CustomStringConvertible else {
                continue
            }

            message = message.replacingOccurrences(of: substring, with: "\(value)")
        }

        return message
    }
}

enum Validator {
    enum Name: String {
        case Regex
        case In
        case NotEmpty
        case UUID
        case MinLength
        case MaxLength
        case IdenticalWith
        case Date
        case Callback
        case Cumulative

        init(from rawName: String) throws {
            guard let value = Self(rawValue: rawName) else {
                throw E.InvalidSchema("Unknown validator '\(rawName)'")
            }

            self = value
        }
    }

    static func initFrom(name rawName: String, params: Any) throws -> AnyValidator {
        let result: AnyValidator.Type

        switch try Name(from: rawName) {
        case .Regex:         result = Regex.self
        case .In:            result = In.self
        case .NotEmpty:      result = NotEmpty.self
        case .UUID:          result = UUID.self
        case .MinLength:     result = MinLength.self
        case .MaxLength:     result = MaxLength.self
        case .IdenticalWith: result = IdenticalWith.self
        case .Date:          result = Date.self
        case .Callback:      result = Callback.self
        case .Cumulative:    result = Cumulative.self
        }

        return try result.init(from: params)
    }

    static func initFrom(name rawName: String) throws -> AnyValidator {
        switch try Name(from: rawName) {
        case .NotEmpty, .UUID, .Date, .Callback: return try Self.initFrom(name: rawName, params: Dict())
        default: throw E.InvalidSchema("Validator '\(rawName)' cannot be initiated by only name")
        }
    }

    struct Regex: AnyValidator {
        enum Key: String {
            case expression = "Expression"
        }

        let message: String?
        let expression: String

        init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            guard let rawInput = input as? Dict else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
            }

            self.message = try Self.getMessage(from: rawInput)

            guard let expression = rawInput[Key.expression] as? String else {
                throw E.InvalidSchema("\(errorPrefix): missing or invalid key \(Key.expression.rawValue)")
            }

            self.expression = expression
        }
    }

    struct In: AnyValidator {
        enum Key: String {
            case allowedValues = "AllowedValues"
        }

        let message: String?
        let allowedValues: [String]

        init(allowedValues: [String]) {
            self.message = nil
            self.allowedValues = allowedValues
        }

        init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            guard let rawInput = input as? Dict else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
            }

            self.message = try Self.getMessage(from: rawInput)

            guard let allowedValues = rawInput[Key.allowedValues] as? [String] else {
                throw E.InvalidSchema("\(errorPrefix): missing or invalid key \(Key.allowedValues.rawValue)")
            }

            self.allowedValues = allowedValues
        }
    }

    struct NotEmpty: AnyValidator {
        enum Key: String { case foo }

        let message: String?

        init(message: String?) {
            self.message = message
        }

        init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            guard let rawInput = input as? Dict else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
            }

            self.message = try Self.getMessage(from: rawInput)
        }
    }

    struct UUID: AnyValidator {
        enum Key: String { case foo }

        let message: String?

        init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            guard let rawInput = input as? Dict else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
            }

            self.message = try Self.getMessage(from: rawInput)
        }
    }

    class Length: AnyValidator, CustomStringConvertible {
        enum Key: String {
            case length = "Length"
        }

        let message: String?
        let length: Int

        var description: String {
            "\(Self.self)(message: \(String(describing: self.message)), length: \(self.length))"
        }

        required init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            var _input = input
            if let length = input as? Int {
                _input = Dict([("Length", length)])
            }

            guard let rawInput = _input as? Dict else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(_input))")
            }

            self.message = try Self.getMessage(from: rawInput.map { $0 }) // dr_hax.exe

            guard let length = rawInput[Key.length] as? Int else {
                throw E.InvalidSchema("\(errorPrefix): missing or invalid key \(Key.length.rawValue)")
            }

            self.length = length
        }
    }

    class MinLength: Length {
        var name: String = "Min"
    }

    class MaxLength: Length {
        var name: String = "Max"
    }

    struct IdenticalWith: AnyValidator {
        enum Key: String {
            case field = "Field"
        }

        let message: String?
        let field: String

        var fieldInternal: String {
            "\(Field.internalPrefix)_\(self.field)"
        }

        internal init(message: String?, field: String) {
            self.message = message
            self.field = field
        }

        init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            if let field = input as? String {
                self.init(message: nil, field: field)
            } else if let rawInput = input as? Dict {
                guard let field = rawInput[Key.field] as? String else {
                    throw E.InvalidSchema("\(errorPrefix): missing or invalid key \(Key.field.rawValue)")
                }
                self.init(message: try Self.getMessage(from: rawInput), field: field)
            } else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary or string (input: \(input))")
            }
        }

        func performSanityCheck(entity: Entity) throws {
            guard entity.fields.contains(where: { $0.name == self.field }) else {
                throw E.InvalidSchema(
                    "Entity '\(entity.name)' doesn't have a field '\(self.field)' for validator '\(self.name)'"
                )
            }
        }
    }

    struct Date: AnyValidator {
        enum Key: String { case format = "Format" }

        let message: String?
        let format: String?

        init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            guard let rawInput = input as? Dict else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
            }

            self.message = try Self.getMessage(from: rawInput)
            self.format = rawInput[Key.format] as? String
        }
    }

    struct Callback: AnyValidator {
        struct Error: Model {
            enum Key: String {
                case code = "Code"
                case message = "Message"
                case shortName = "ShortName"
            }

            let code: Int
            let message: String
            let shortName: String?

            init(from input: Any) throws {
                let errorPrefix = "Could not decode error \(Self.self)"

                guard let rawInput = input as? Dict else {
                    throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
                }

                guard let code = rawInput[Key.code] as? Int else {
                    throw E.InvalidSchema("\(errorPrefix): missing or invalid key '\(Key.code.rawValue)'")
                }

                guard let message = rawInput[Key.message] as? String else {
                    throw E.InvalidSchema("\(errorPrefix): missing or invalid key '\(Key.code.rawValue)'")
                }

                self.code = code
                self.message = message
                self.shortName = rawInput[Key.shortName] as? String
            }
        }

        enum Key: String {
            case errors = "Errors"
        }

        let message: String? = nil
        let errors: [Error]

        init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            guard let rawInput = input as? Dict else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
            }

            let rawErrors: [Any]
            if rawInput[Key.errors] == nil {
                rawErrors = []
            } else {
                guard let _rawErrors = rawInput[Key.errors] as? [Any] else {
                    throw E.InvalidSchema("\(errorPrefix): missing or invalid key '\(Key.errors.rawValue)'")
                }
                rawErrors = _rawErrors
            }

            self.errors = try rawErrors.map { try Error(from: $0) }
        }
    }

    struct Cumulative: AnyValidator {
        let message: String? = nil
        let validators: [AnyValidator]

        init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            guard let rawInput = input as? Dict else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
            }

            self.validators = try rawInput.map { name, rawValidator in
                let validator = try Validator.initFrom(name: name, params: rawValidator)
                if validator is Self {
                    throw E.InvalidSchema(
                        "\(errorPrefix): this validator cannot have nested Cumulative validator"
                    )
                }
                return validator
            }
        }
    }
}
