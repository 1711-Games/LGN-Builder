import Yams
import LGNLog

let defaultTransports: [(String, Any)] = [(Transport.HTTP.rawValue, 8080)]

struct Service {
    let name: String
    let info: [(String, String)]
    let transports: [(Transport, Int)]
    let contracts: Contracts
    let WebSocketURI: String?
}

extension Service: Model {
    enum Key: String {
        case info = "Info"
        case transports = "Transports"
        case contracts = "Contracts"
    }

    @available(*, deprecated, message: "Use init(name:from:shared:) instead")
    init(from input: Any) throws {
        throw E.InvalidSchema("Use init(name:from:shared:) instead")
    }

    init(name: String, from input: Any, shared: Shared) throws {
        self.name = name

        let errorPrefix = "Could not decode service '\(name)'"

        guard var rawInput = input as? Dict else {
            throw E.InvalidSchema("\(errorPrefix): input is not dictionary (input: \(input))")
        }

        var info: [(String, String)] = []
        if let rawInfo = rawInput[Key.info] as? Dict {
            info = rawInfo.compactMap { key, rawValue in
                guard let value = rawValue as? String else {
                    return nil
                }
                return (key, value)
            }
        }
        self.info = info

        if rawInput[Key.transports] == nil {
            Logger.current.notice("Assuming default transports (\(defaultTransports)) for service '\(name)'")
            rawInput[Key.transports] = defaultTransports
        }
        guard let rawTransports = rawInput[Key.transports] as? Dict else {
            throw E.InvalidSchema("\(errorPrefix): input doesn't have '\(Key.transports.rawValue)' key")
        }
        let transports: [(Transport, Int)] = try rawTransports.map { rawKey, rawValue in
            guard let key = Transport(rawValue: rawKey) else {
                throw E.InvalidSchema("\(errorPrefix): unknown transport '\(rawKey)'")
            }
            guard let value = rawValue as? Int else {
                throw E.InvalidSchema("\(errorPrefix): transport '\(key.rawValue)' port is not an integer (\(rawValue))")
            }
            return (key, value)
        }
        self.transports = transports

        guard let rawContracts = rawInput[Key.contracts] as? Dict else {
            throw E.InvalidSchema("\(errorPrefix): service doesn't have contracts")
        }
        self.contracts = try rawContracts.map { contractName, rawContract in
            (
                contractName.safe,
                try Contract(
                    name: contractName.safe,
                    from: rawContract,
                    allowedTransports: transports.map { $0.0 },
                    shared: shared
                )
            )
        }

        self.WebSocketURI = rawInput["WebSocketURI"] as? String

        let webSocketContracts = self.contracts.map(\.1).filter { $0.transports.contains(.WebSocket) }
        if self.WebSocketURI == nil && webSocketContracts.count > 0 {
            throw E.InvalidSchema(
                """
                Service '\(self.name)' has WebSocket contracts (\(webSocketContracts.map(\.name))), \
                but 'webSocketURI' field is empty
                """
            )
        }
    }
}
