import Foundation

struct Profiler {
    internal var start: TimeInterval = Date().timeIntervalSince1970

    /// Begins and returns a profiler
    public static func begin() -> Profiler {
        return Profiler()
    }

    /// Stops an active profiler and returns result time in seconds
    public func end() -> Float {
        var end = Date().timeIntervalSince1970
        end -= start
        return Float(end)
    }
}

internal extension Dictionary where Key == String {
    subscript<K: RawRepresentable>(key: K) -> Value? where K.RawValue == String {
        get {
            self[key.rawValue]
        }
        set(newValue) {
            self[key.rawValue] = newValue
        }
    }
}

internal extension Array where Element == (String, Any) {
    subscript(key: String) -> Any? {
        get {
            self
                .first(where: { k, _ in k == key })?
                .1
        }
        set(newValue) {
            let newValue = (key, newValue as Any)
            if let index = self.firstIndex(where: { k, _ in k == key }) {
                self[index] = newValue
            } else {
                self.append(newValue)
            }
        }
    }

    subscript<K: RawRepresentable>(key: K) -> Any? where K.RawValue == String {
        get {
            self[key.rawValue]
        }
        set(newValue) {
            self[key.rawValue] = newValue
        }
    }
}

internal extension Dictionary where Key == String, Value == Contract {
    var sorted: [Dictionary<String, Contract>.Element] {
        self.sorted(by: { $0.key < $1.key })
    }
}

internal extension StringProtocol {
    @usableFromInline
    var firstUppercased: String { prefix(1).uppercased() + dropFirst() }
}

internal extension Bool {
    var text: String {
        self ? "true" : "false"
    }
}
