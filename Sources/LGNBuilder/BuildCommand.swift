import Foundation
import ArgumentParser

struct Build: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "LGNBuilder",
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

    @Argument(help: "Compile only given services")
    var services: [String] = []

    @Flag(
        name: .long,
        help: "Does everything except writing generated code to actual files, useful for validating schemas"
    )
    var dryRun = false

    @Flag(name: .long, help: "Prints assembled schema (no codegen will be done)")
    var emitSchema = false

    func run() throws {
        if self.dryRun {
            print("THIS IS A DRY RUN, NO FILES WILL BE WRITTEN")
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

        try Builder
            .create(from: self.language)
            .init(
                inputDirectory: inputDirectoryURL,
                outputDirectory: outputDirectoryURL,
                services: self.services,
                dryRun: self.dryRun,
                emitSchema: self.emitSchema
            )
            .build()
    }
}

extension Builder.Language: ExpressibleByArgument {}
