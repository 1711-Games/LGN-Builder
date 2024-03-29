import Foundation

public extension Builder {
    struct Swift: AnyBuilder {
        public let inputDirectory: URL
        public let outputDirectory: URL
        public let services: [String]
        public let dryRun: Bool
        public let emitRawSchema: Bool
        public let emitProcessedSchema: Bool

        public init(
            inputDirectory: URL,
            outputDirectory: URL,
            services: [String],
            dryRun: Bool,
            emitRawSchema: Bool,
            emitProcessedSchema: Bool
        ) throws {
            self.inputDirectory = inputDirectory
            self.outputDirectory = outputDirectory
            self.services = services
            self.dryRun = dryRun
            self.emitRawSchema = emitRawSchema
            self.emitProcessedSchema = emitProcessedSchema
        }
    }
}

extension Builder.Swift {
    func generateCore(from schema: Schema) throws -> String {
        Template.Swift.core(from: schema)
    }

    func generate(service: Service, shared: Shared) throws -> String {
        Template.Swift.service(from: service, shared: shared)
    }
}
