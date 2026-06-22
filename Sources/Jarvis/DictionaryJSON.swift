import Foundation

typealias JSONDictionary = [String: Any]

extension Dictionary where Key == String, Value == Any {
    func dictionary(_ key: String) -> JSONDictionary? {
        self[key] as? JSONDictionary
    }

    func string(_ key: String) -> String? {
        if let value = self[key] as? String {
            return value
        }
        if let value = self[key] as? CustomStringConvertible {
            return value.description
        }
        return nil
    }

    func bool(_ key: String) -> Bool? {
        if let value = self[key] as? Bool {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.boolValue
        }
        if let value = self[key] as? String {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1", "running", "loaded", "ok", "healthy", "reachable", "paired":
                return true
            case "false", "no", "0", "stopped", "unloaded", "failed", "unhealthy", "unreachable", "unpaired":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    func int(_ key: String) -> Int? {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.intValue
        }
        if let value = self[key] as? String {
            return Int(value)
        }
        return nil
    }

    func array(_ key: String) -> [Any]? {
        self[key] as? [Any]
    }

    func dictionaries(_ key: String) -> [JSONDictionary]? {
        self[key] as? [JSONDictionary]
    }
}

enum JSONValue {
    static func dictionary(from data: Data) throws -> JSONDictionary {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? JSONDictionary else {
            throw FleetStatusParser.ParseError.topLevelObjectIsNotDictionary
        }
        return dictionary
    }

    static func compactString(_ value: Any?) -> String? {
        guard let value else {
            return nil
        }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        if JSONSerialization.isValidJSONObject([value]),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }
}
