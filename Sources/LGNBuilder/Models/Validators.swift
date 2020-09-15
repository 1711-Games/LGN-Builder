import Foundation

protocol AnyValidator: Model {
    var name: String { get }
    var message: String? { get }
}

extension AnyValidator {
    var name: String {
        "\(Self.self)Validator"
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
    static func initFrom(name: String, params: Any) throws -> AnyValidator {
        let result: AnyValidator.Type

        switch name {
        case "Regex":         result = Regex.self
        case "In":            result = In.self
        case "NotEmpty":      result = NotEmpty.self
        case "UUID":          result = UUID.self
        case "MinLength":     result = MinLength.self
        case "MaxLength":     result = MaxLength.self
        case "IdenticalWith": result = IdenticalWith.self
        case "Date":          result = Date.self
        case "Callback":      result = Callback.self
        default: throw E.InvalidSchema("Unknown validator '\(name)'")
        }

        return try result.init(from: params)
    }

    static func initFrom(name: String) throws -> AnyValidator {
        switch name {
        case "NotEmpty", "UUID", "Date": return try Self.initFrom(name: name, params: Dict())
        default: throw E.InvalidSchema("Validator '\(name)' cannot be initiated by only name")
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

    class Length: AnyValidator {
        enum Key: String {
            case length = "Length"
        }

        let message: String?
        let length: Int

//        static func initFrom(kind: String, length: Int) throws -> AnyValidator {
//            let result: Length.Type
//
//            switch kind {
//            case "MinLength": result = MinLength.self
//            case "MaxLength": result = MaxLength.self
//            default: throw E.InvalidSchema("Invalid Length validator '\(kind)'")
//            }
//
//            return result.init(message: nil, length: length)
//        }
//
//        required init(message: String?, length: Int) {
//            self.message = message
//            self.length = length
//        }

        required init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            guard let rawInput = input as? Dict else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
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

        init(from input: Any) throws {
            let errorPrefix = "Could not decode validator \(Self.self)"

            guard let rawInput = input as? Dict else {
                throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
            }

            self.message = try Self.getMessage(from: rawInput)

            guard let field = rawInput[Key.field] as? String else {
                throw E.InvalidSchema("\(errorPrefix): missing or invalid key \(Key.field.rawValue)")
            }

            self.field = field
        }
    }

    struct Date: AnyValidator {
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

            guard let rawErrors = rawInput[Key.errors] as? [Any] else {
                throw E.InvalidSchema("\(errorPrefix): missing or invalid key '\(Key.errors.rawValue)'")
            }

            self.errors = try rawErrors.map { try Error(from: $0) }
        }
    }
}
