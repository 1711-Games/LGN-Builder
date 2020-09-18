import Foundation

extension Template.Swift {
    static func service(from service: Service, shared: Shared) -> String {
        """
        /**
         * This file has been autogenerated by LGNC assembler on \(Date()) (\(Date().timeIntervalSince1970)).
         * All changes will be lost on next assembly.
         */

        import Foundation
        import LGNCore
        import LGNP
        import LGNC
        import LGNS
        import Entita
        import NIO

        public extension Services {
            enum \(service.name): Service {
                \(blocks([
                    "public enum Contracts {}",
                    Template.Swift.transports(from: service.transports),
                    Template.Swift.info(from: service.info),
                    Template.Swift.guaranteeStatuses(from: service.contracts),
                    Template.Swift.contractMap(from: service.contracts),
                    Template.Swift.callbackSetters(from: service.contracts),
                    Template.Swift.contractClientExecutors(from: service.contracts),
                    Template.Swift.contractsFieldsValidators(from: service.contracts, shared: shared),
                    Template.Swift.cumulativeKeyDictionary(from: service.contracts),
                ]).removingDoubleNewlines())
            }
        }

        public extension Services.\(service.name).Contracts {
            \(blocks(
                [
                    Template.Swift.sharedTypealiases(shared: shared),
                    Template.Swift.contracts(from: service.contracts, service: service, shared: shared),
                ],
                indent: 1
            ))
        }
        """
    }

    static func transports(from transports: [(Transport, Int)]) -> String {
        """
        public static let transports: [LGNCore.Transport: Int] = [
            \(transports.count == 0
                ? ":".indented(1)
                : transports
                    .map { transport, port in ".\(transport): \(port)," }
                    .joined(separator: "\n")
                    .indented(1)
            )
        ]
        """
    }

    static func info(from info: [(String, String)]) -> String {
        var result = "public static let info: [String: String] = "

        if info.isEmpty {
            result += "[:]"
        } else {
            result += """
            [
                \(info
                    .map { k, v in "\"\(k)\": \"\(v)\"," }
                    .joined(separator: "\n")
                    .indented(1)
                )
            ]
            """
        }

        return result
    }

    static func guaranteeStatuses(from contracts: Contracts) -> String {
        """
        public static var guaranteeStatuses: [String: Bool] = [
            \(
                contracts.isEmpty
                    ? ":"
                    : contracts
                        //.sorted
                        .map { name, _ in "Contracts.\(name).URI: Contracts.\(name).isGuaranteed," }
                        .joined(separator: "\n")
                        .indented(1)
            )
        ]
        """
    }

    static func contractMap(from contracts: Contracts) -> String {
        """
        public static let contractMap: [String: AnyContract.Type] = [
            \(
                contracts.isEmpty
                    ? ":"
                    : contracts
                        //.sorted
                        .map { name, _ in "Contracts.\(name).URI: Contracts.\(name).self," }
                        .joined(separator: "\n")
                        .indented(1)
            )
        ]
        """
    }

    static func callbackSetters(from contracts: Contracts) -> String {
        contracts
            //.sorted
            .compactMap { name, contract in
                if !contract.generateServiceWiseGuarantee {
                    return nil
                }
                return """
                public static func guarantee\(name)Contract(_ guaranteeClosure: @escaping Contracts.\(name).FutureClosureWithMeta) {
                    Contracts.\(name).guarantee(guaranteeClosure)
                }

                public static func guarantee\(name)Contract(_ guaranteeClosure: @escaping Contracts.\(name).FutureClosure) {
                    Contracts.\(name).guarantee(guaranteeClosure)
                }

                public static func guarantee\(name)Contract(_ guaranteeClosure: @escaping Contracts.\(name).NonFutureClosureWithMeta) {
                    Contracts.\(name).guarantee(guaranteeClosure)
                }

                public static func guarantee\(name)Contract(_ guaranteeClosure: @escaping Contracts.\(name).NonFutureClosure) {
                    Contracts.\(name).guarantee(guaranteeClosure)
                }
                """
            }
            .joined(separator: "\n\n")
    }

    static func contractClientExecutors(from contracts: Contracts) -> String {
        contracts
            //.sorted
            .compactMap { name, contract in
                if !contract.generateServiceWiseExecutors {
                    return nil
                }
                return """
                public static func execute\(name)Contract(
                    at address: LGNCore.Address,
                    with request: Contracts.\(name).Request,
                    using client: LGNCClient
                ) -> EventLoopFuture<Contracts.\(name).Response> {
                    return Contracts.\(name).execute(at: address, with: request, using: client)
                }
                """
            }
            .joined(separator: "\n\n")
    }

    static func contractsFieldsValidators(from contracts: Contracts, shared: Shared) -> String {
        contracts
            .compactMap { contractName, contract in
                if !contract.generateServiceWiseValidators {
                    return nil
                }
                var result = [String]()
                for (entityName, entityType) in ["Request": contract.request, "Response": contract.response] {
                    let entity: Entity

                    switch entityType {
                    case let .entity(_entity): entity = _entity
                    case let .shared(_entity): entity = _entity
                    }

                    for (name, (type, errors)) in entity.validationCallbacks {
                        let prefix = "Contracts." + contractName + "." + entityName + "."
                        result.append(
                            """
                            public static func validateContract\(contractName)Field\(name.firstUppercased)(
                                _ callback: @escaping \(self.callbackValidatorType(fieldName: name, type: type, errors: errors, prefix: prefix)).Callback
                            ) {
                                \(prefix)validate\(name.firstUppercased)(callback)
                            }
                            """
                        )
                    }
                }
                return result.count > 0
                    ? result.joined(separator: "\n\n")
                    : nil
            }
            .joined(separator: "\n\n")
    }

    static func sharedTypealiases(shared: Shared) -> String {
        shared.entities
            //.sorted(by: { $0.name < $1.name })
            .map { entity in "typealias \(entity.name) = Services.Shared.\(entity.name)" }
            .joined(separator: "\n")
    }

    static func cumulativeKeyDictionary(from contracts: Contracts) -> String {
        """
        public static let keyDictionary: [String: Entita.Dict] = [
            \(contracts
                //.sorted
                .map { _, contract in
                    """
                    "\(contract.name)": [
                        "Request": Contracts.\(contract.name).Request.keyDictionary,
                        "Response": Contracts.\(contract.name).Response.keyDictionary,
                    ],
                    """
                }
                .joined(separator: "\n")
                .indented(1)
            )
        ]
        """
    }
}
