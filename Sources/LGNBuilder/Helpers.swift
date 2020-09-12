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

internal extension Dictionary where Key == String, Value == Contract {
    var sorted: [Dictionary<String, Contract>.Element] {
        self.sorted(by: { $0.key < $1.key })
    }
}
