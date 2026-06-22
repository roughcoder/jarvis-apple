import Foundation

enum GitHubReleaseClientError: LocalizedError {
    case invalidRepository(String)
    case noReleaseAsset
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidRepository(let value):
            return "Invalid GitHub repository: \(value)"
        case .noReleaseAsset:
            return "The latest GitHub release does not include a .zip or .dmg asset."
        case .requestFailed(let statusCode):
            return "GitHub release check failed with HTTP \(statusCode)."
        }
    }
}

struct GitHubReleaseClient {
    func latestRelease(repository rawRepository: String) async throws -> AppRelease {
        let repository = try Self.normalizedRepository(rawRepository)
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("JarvisMenuBar/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GitHubReleaseClientError.requestFailed(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(GitHubReleasePayload.self, from: data)
        let asset = payload.assets.preferredInstallAsset

        return AppRelease(
            tagName: payload.tagName,
            name: payload.name ?? payload.tagName,
            body: payload.body ?? "",
            htmlURL: payload.htmlURL,
            assetName: asset?.name,
            assetURL: asset?.browserDownloadURL,
            publishedAt: payload.publishedAt
        )
    }

    static func normalizedRepository(_ value: String) throws -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("git@github.com:") {
            trimmed = String(trimmed.dropFirst("git@github.com:".count))
        }
        if trimmed.hasPrefix("https://github.com/") {
            trimmed = String(trimmed.dropFirst("https://github.com/".count))
        }
        if trimmed.hasSuffix(".git") {
            trimmed = String(trimmed.dropLast(4))
        }
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let parts = trimmed.split(separator: "/")
        guard parts.count == 2,
              parts.allSatisfy({ !$0.isEmpty }) else {
            throw GitHubReleaseClientError.invalidRepository(value)
        }
        return parts.joined(separator: "/")
    }
}

private struct GitHubReleasePayload: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let publishedAt: Date?
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL
    let contentType: String?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case contentType = "content_type"
    }
}

private extension Array where Element == GitHubReleaseAsset {
    var preferredInstallAsset: GitHubReleaseAsset? {
        first { $0.name == "JarvisMenuBar-macos.zip" }
            ?? first { $0.name.localizedCaseInsensitiveContains("JarvisMenuBar") && $0.name.hasSuffix(".zip") }
            ?? first { $0.name.hasSuffix(".dmg") }
            ?? first { $0.name.hasSuffix(".zip") }
    }
}
