import Foundation

struct AppRelease: Equatable, Identifiable {
    let tagName: String
    let name: String
    let body: String
    let htmlURL: URL
    let assetName: String?
    let assetURL: URL?
    let publishedAt: Date?

    var id: String { tagName }
}

struct SemVer: Comparable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int
    let suffix: String?

    static func parse(_ rawValue: String) -> SemVer? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        let parts = withoutPrefix.split(separator: "-", maxSplits: 1).map(String.init)
        guard let versionCore = parts[safe: 0] else {
            return nil
        }
        let versionParts = versionCore.split(separator: ".").map(String.init)
        guard let major = Int(versionParts[safe: 0] ?? ""),
              let minor = Int(versionParts[safe: 1] ?? "0") else {
            return nil
        }
        let patch = Int(versionParts[safe: 2] ?? "0") ?? 0
        let suffix = parts[safe: 1]
        return SemVer(major: major, minor: minor, patch: patch, suffix: suffix)
    }

    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }

        switch (lhs.suffix, rhs.suffix) {
        case (.none, .some):
            return false
        case (.some, .none):
            return true
        case let (.some(left), .some(right)):
            return left < right
        case (.none, .none):
            return false
        }
    }
}

enum AppVersion {
    static var current: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "0.0.0-dev"
    }

    static func isRelease(_ candidate: String, newerThan current: String = Self.current) -> Bool {
        guard let candidateVersion = SemVer.parse(candidate),
              let currentVersion = SemVer.parse(current) else {
            return false
        }
        return candidateVersion > currentVersion
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
