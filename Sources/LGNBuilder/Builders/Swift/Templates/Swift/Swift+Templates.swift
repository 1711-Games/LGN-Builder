import Foundation

enum Template {
    enum Swift {}
}

internal let TAB: String = "    "

internal extension String {
    func indented(_ times: Int, includingFirst: Bool = false) -> Self {
        self
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map {
                if !includingFirst && $0 == 0 || $1.trimmingCharacters(in: .whitespaces) == "" {
                    return .init($1)
                }
                return String(repeating: TAB, count: times) + $1
            }
            .joined(separator: "\n")
    }

    func removingDoubleNewlines(leavingOneNewLine: Bool = true) -> Self {
        let lines = self.split(separator: "\n", omittingEmptySubsequences: false)
        var result = [Substring]()

        var previousNewline: Bool = false
        for line in lines {
            guard line.trimmingCharacters(in: .whitespaces).count == 0 else {
                previousNewline = false
                result.append(line)
                continue
            }

            if previousNewline {
                continue
            } else {
                previousNewline = true
                if leavingOneNewLine {
                    result.append("")
                }
            }
        }

        return result.joined(separator: "\n")
    }
}

internal extension Entity {
    var validationCallbacks: [(String, (type: FieldType, errors: [Validator.Callback.Error]))] {
        self
            .fields
            .filter { field -> Bool in
                field.validators.contains(where: { $0 is Validator.Callback })
            }
            .map { field in
                (
                    field.name,
                    (
                        type: field.type,
                        errors: field.validators.reduce(
                            into: [Validator.Callback.Error](),
                            { result, anyValidator in
                                guard let validator = anyValidator as? Validator.Callback else {
                                    return
                                }
                                result.append(contentsOf: validator.errors)
                            }
                        )
                    )
                )
            }
    }

    var initializerCallbacks: [Field] {
        fields.filter { $0.alwaysInitiated }
    }
}

extension Template.Swift {
    static func core(from schema: AnyBuilder.Schema) -> String {
        """
        import LGNCore
        import Entita
        import LGNS
        import LGNC
        import LGNP
        import NIO

        public enum Services {
            public enum Shared {}

            \(Template.Swift.servicesList(from: schema.services).indented(1))
        }

        public extension Services.Shared {
            \(Template.Swift
                .entities(schema.shared.entities, shared: schema.shared)
                .indented(1)
            )
        }
        """
    }

    static func servicesList(from services: [String: Service]) -> String {
        """
        public static let list: [String: Service.Type] = [
            \(services
                //.sorted(by: { $0.key < $1.key })
                .map { name, _ in "\"\(name)\": \(name).self," }
                .joined(separator: "\n")
                .indented(1)
            )
        ]
        """
    }

    static func prepareType(field: Field, addFuture: Bool = false) -> String {
        var result = field
            .type
            .asString
            .replacingOccurrences(of: "Map[", with: "[")
            .replacingOccurrences(of: "List[", with: "[")

        if addFuture && field.canBeFuture {
            result = "EventLoopFuture<\(result)>"
        }

        return result
    }

    static func callbackValidatorEnumName(fieldName: String) -> String {
        "CallbackValidator\(fieldName.capitalized)AllowedValues"
    }

    static func callbackValidatorType(
        fieldName: String,
        type: FieldType,
        errors: [Validator.Callback.Error],
        prefix: String = ""
    ) -> String {
        errors.count > 0
            ? "Validation.CallbackWithAllowedValues<\(prefix)\(self.callbackValidatorEnumName(fieldName: fieldName))>"
            : "Validation.Callback<\(type.asString)>"
    }

    static func blocks(_ blocks: [String], indent: Int = 2, separator: String = "\n\n") -> String {
        blocks
            .joined(separator: separator)
            .indented(indent)
    }
}
