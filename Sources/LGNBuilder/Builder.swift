public enum Builder {
    public enum E: Error {
        case LanguageNotFound
    }

    public enum Language: String, CaseIterable {
        case Swift
        //case JavaScript
        //case Go
    }

    static func create(from language: Language) -> AnyBuilder.Type {
        let result: AnyBuilder.Type

        switch language {
        case .Swift:
            result = Builder.Swift.self
        }

        return result
    }
}
