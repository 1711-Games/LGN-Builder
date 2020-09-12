import Foundation

public extension Builder {
    struct Swift: AnyBuilder {
        public let templateDirectory: URL
        public let inputDirectory: URL
        public let outputDirectory: URL
        public let services: [String]
        public let dryRun: Bool
        public let emitSchema: Bool

        public init(
            templateDirectory: URL,
            inputDirectory: URL,
            outputDirectory: URL,
            services: [String],
            dryRun: Bool,
            emitSchema: Bool
        ) throws {
            self.templateDirectory = templateDirectory
            self.inputDirectory = inputDirectory
            self.outputDirectory = outputDirectory
            self.services = services
            self.dryRun = dryRun
            self.emitSchema = emitSchema
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
