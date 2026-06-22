import Foundation

enum Redactor {
    private static let sensitiveKeyFragments = [
        "api_key",
        "apikey",
        "authorization",
        "bearer",
        "password",
        "pairing_token",
        "refresh_token",
        "secret",
        "token"
    ]

    static func redactText(_ text: String) -> String {
        var redacted = text
        let replacements = [
            (
                #"(?i)\b(api[_-]?key|authorization|bearer|password|pairing[_-]?token|refresh[_-]?token|secret|token)(\s*[:=]\s*)("[^"]+"|'[^']+'|[^\s,}]+)"#,
                "$1$2<redacted>"
            ),
            (
                #"(?i)("?(?:api[_-]?key|authorization|password|pairing[_-]?token|refresh[_-]?token|secret|token)"?\s*:\s*)("[^"]*"|[^\s,}]+)"#,
                "$1\"<redacted>\""
            )
        ]

        for (pattern, template) in replacements {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(redacted.startIndex..<redacted.endIndex, in: redacted)
                redacted = regex.stringByReplacingMatches(
                    in: redacted,
                    range: range,
                    withTemplate: template
                )
            }
        }

        return redacted
    }

    static func redactedJSONObject(_ value: Any) -> Any {
        if let dictionary = value as? JSONDictionary {
            return dictionary.reduce(into: JSONDictionary()) { partial, element in
                if isSensitiveKey(element.key) {
                    partial[element.key] = "<redacted>"
                } else {
                    partial[element.key] = redactedJSONObject(element.value)
                }
            }
        }

        if let array = value as? [Any] {
            return array.map(redactedJSONObject)
        }

        return value
    }

    static func redactedJSONString(from dictionary: JSONDictionary) -> String {
        let redacted = redactedJSONObject(dictionary)
        guard JSONSerialization.isValidJSONObject(redacted),
              let data = try? JSONSerialization.data(withJSONObject: redacted, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.replacingOccurrences(of: "-", with: "_").lowercased()
        return sensitiveKeyFragments.contains { normalized.contains($0) }
    }
}
