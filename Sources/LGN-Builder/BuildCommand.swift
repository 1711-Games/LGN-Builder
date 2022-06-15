import Foundation
import ArgumentParser
import LGNLog

struct Build: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "LGN-Builder",
        abstract: "Builds LGN contracts from provided schema directory for target language."
    )

    @Option(
        name: [
            .long,
            .customLong("lang"),
            .customShort("l")
        ],
        help: "Target language (available: \(Builder.Language.allCases.map(\.rawValue).joined(separator: ", ")))"
    )
    var language: Builder.Language

    @Option(name: .shortAndLong, help: "Directory with contracts schema")
    var input: String

    @Option(name: .shortAndLong, help: "Output folder for compiled code")
    var output: String

    @Option(name: .customLong("go-package-prefix"), help: "Package name prefix for Go lang")
    var goLangPackagePrefix: String?

    @Argument(help: "Compile only given services")
    var services: [String] = []

    @Flag(
        name: .long,
        help: "Does everything except writing generated code to actual files, useful for validating schemas"
    )
    var dryRun = false

    @Flag(name: .long, help: "Prints assembled raw schema (no codegen will be done)")
    var emitRawSchema = false

    @Flag(name: .long, help: "Prints assembled processed schema with all substitutions (no codegen will be done)")
    var emitProcessedSchema = false

    @Flag(name: .long, help: "Makes LGNC router case-sensitive (so that `Profile/Info` wouldn't route to `profile/info`)")
    var caseSensitiveUris = false

    func run() throws {
        if self.dryRun {
            Logger.current.notice("THIS IS A DRY RUN, NO FILES WILL BE WRITTEN")
        }

        let manager = FileManager.default

        guard manager.isReadableFile(atPath: self.input) else {
            throw ValidationError(
                "Invalid input directory '\(self.input)' (doesn't exist or is not readable)"
            )
        }
        let inputDirectoryURL = URL(fileURLWithPath: self.input, isDirectory: true)
        guard try inputDirectoryURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw ValidationError(
                "Invalid input directory '\(self.input)' (isn't a directory)"
            )
        }

        guard manager.isWritableFile(atPath: self.output) else {
            throw ValidationError(
                "Invalid output directory '\(self.output)' (doesn't exist or is not writable)"
            )
        }
        let outputDirectoryURL = URL(fileURLWithPath: self.output, isDirectory: true)
        guard try outputDirectoryURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw ValidationError(
                "Invalid output directory '\(self.output)' (isn't a directory)"
            )
        }

        Glob.caseSensitiveURIs = self.caseSensitiveUris

        try Builder
            .create(from: self.language)
            .init(
                inputDirectory: inputDirectoryURL,
                outputDirectory: outputDirectoryURL,
                services: self.services,
                dryRun: self.dryRun,
                emitRawSchema: self.emitRawSchema,
                emitProcessedSchema: self.emitProcessedSchema
            )
            .build()
    }
}

extension Builder.Language: ExpressibleByArgument {}
