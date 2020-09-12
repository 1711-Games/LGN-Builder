import Foundation
import Yams

typealias Dict = [String: Any] // [(Any, Any)]

enum E: Error {
    case InvalidSchema(String)
}

protocol AnyBuilder {
    typealias Schema = (shared: Shared, services: [String: Service])

    var compiledSchemaFilename: String { get }
    var templateDirectory: URL { get }
    var inputDirectory: URL { get }
    var outputDirectory: URL { get }
    var services: [String] { get }
    var dryRun: Bool { get }
    var emitSchema: Bool { get }

    init(
        templateDirectory: URL,
        inputDirectory: URL,
        outputDirectory: URL,
        services: [String],
        dryRun: Bool,
        emitSchema: Bool
    ) throws
    func build() throws
    func generateCore(from schema: Schema) throws -> String
    func generate(service: Service, shared: Shared) throws -> String
}

fileprivate extension URL {
    func path(_ prefix: URL) -> String {
        self.path.replacingOccurrences(of: prefix.path + "/", with: "")
    }
}

fileprivate class Leaf {
    private var storage: [Substring: Leaf] = [:]

    func has(_ string: Substring) -> Bool {
        self.get(string) != nil
    }

    func get(_ string: Substring) -> Leaf? {
        self.storage[string]
    }

    func createEmpty(_ string: Substring) {
        self.storage[string] = Leaf()
    }
}

extension AnyBuilder {
    var compiledSchemaFilename: String {
        "result.yml"
    }

    func build() throws {
        // let profiler = Profiler.begin()

        let inputFiles: [URL] = try self
            .getFilesUnder(directory: self.inputDirectory, ext: "yml")
            .filter { $0.lastPathComponent != self.compiledSchemaFilename }
            .sorted(by: { $0.path.lowercased() < $1.path.lowercased() })

        let yaml = try self.buildCompleteSchema(
            from: []
                + inputFiles.filter({ $0.path(self.inputDirectory).starts(with: "Shared/") })
                + inputFiles.filter({ !$0.path(self.inputDirectory).starts(with: "Shared/") })
        )

        let schema = try self.parse(yaml: yaml)

        try self.generateCode(from: schema)

        // print(profiler.end())

        // TODO: validate custom fields and other Shared references 
    }

    fileprivate func buildCompleteSchema(from URLs: [URL], filename: String? = nil) throws -> Any? {
        //let filename = filename ?? self.compiledSchemaFilename
        let root = "__root__"
        let indent = "  "
        let EOL = "\n"

        let tree = Leaf()
        var result = ""

        for file in URLs {
            let shortFilename = file.path(self.inputDirectory)
            var level: Int = 0
            var leaf = tree
            let parts = shortFilename.replacingOccurrences(of: ".yml", with: "").split(separator: "/")
            for (i, part) in parts.enumerated() {
                if part != root && !leaf.has(part) {
                    leaf.createEmpty(part)
                    result += .init(repeating: indent, count: level) + part + ":\(EOL)"
                }
                if i + 1 == parts.count {
                    let _indent: String = .init(repeating: indent, count: part != root ? level + 1 : level)
                    let contents = try String(contentsOf: file, encoding: .utf8)
                    result += "\(_indent)# BEGIN \(shortFilename)\(EOL)"
                    result += contents
                        .split(separator: Character(EOL))
                        .map { _indent + $0 }
                        .joined(separator: EOL) + EOL
                    result += "\(_indent)# END \(shortFilename)\(EOL)"
                } else {
                    leaf = leaf.get(part)!
                    level += 1
                }
            }
        }

        if self.emitSchema {
            print(result)
            exit(0)
        }

        return try Yams.load(yaml: result, .default, .dictionaryAsPairs)
    }

    fileprivate func getFilesUnder(directory: URL, ext: String) throws -> [URL] {
        let manager = FileManager.default
        var result = [URL]()

        for url in try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey]) {
            if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                try result.append(contentsOf: self.getFilesUnder(directory: url, ext: ext))
            } else if url.pathExtension == ext {
                result.append(url)
            }
        }

        return result
    }

    fileprivate func parse(yaml: Any?) throws -> Schema {
        guard let root = yaml as? Dict else {
            throw E.InvalidSchema("Schema does not contain root")
        }

        guard let rawServices = root["Services"] as? Dict else {
            throw E.InvalidSchema("Schema does not contain services")
        }

        var servicesNames: Set<String> = []
        for (serviceName, _) in rawServices {
            guard !servicesNames.contains(serviceName) else {
                throw E.InvalidSchema("Service '\(serviceName)' is defined more than once (must be unique)")
            }
            servicesNames.insert(serviceName)
        }

        let shared: Dict = root["Shared"] as? Dict ?? [:]

        return (
            shared: try .init(from: shared),
            services: try .init(
                uniqueKeysWithValues: rawServices.map { serviceName, rawService in
                    (serviceName, try Service(name: serviceName, from: rawService, shared: shared))
                }
            )
        )
    }

    fileprivate func generateCode(from schema: Schema) throws {
        let generatedCore = try self.generateCore(from: schema)
        let fileCore = URL(fileURLWithPath: "Core.swift", relativeTo: self.outputDirectory)
        if !self.dryRun {
            try generatedCore.write(
                to: fileCore,
                atomically: true,
                encoding: .utf8
            )
        }
        print("Successfully written core to \(fileCore.absoluteString)")

        for serviceName in self.services.isEmpty ? Array(schema.services.keys).sorted() : self.services {
            guard let service = schema.services[serviceName] else {
                throw E.InvalidSchema(
                    "Requested service '\(serviceName)' not present in schema (\(schema.services.keys)"
                )
            }
            let generatedService = try self.generate(service: service, shared: schema.shared)
            let fileService = URL(fileURLWithPath: "Service\(serviceName).swift", relativeTo: self.outputDirectory)
            if !self.dryRun {
                try generatedService.write(
                    to: fileService,
                    atomically: true,
                    encoding: .utf8
                )
            }
            print("Successfully written service '\(serviceName)' to \(fileService.absoluteString)")
        }
    }
}
