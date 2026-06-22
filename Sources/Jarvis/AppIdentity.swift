import Foundation

enum AppIdentity {
    static let displayName = "Jarvis"
    static let executableName = "Jarvis"
    static let bundleIdentifier = "dev.infinitestack.jarvis"
    static let keychainService = bundleIdentifier

    // Keep the existing repository until the GitHub remote is explicitly renamed.
    static let releaseRepository = "roughcoder/jarvis-swift-toolbar"

    static let releaseAssetName = "Jarvis-macos.zip"
    static let legacyReleaseAssetName = "JarvisMenuBar-macos.zip"
}
