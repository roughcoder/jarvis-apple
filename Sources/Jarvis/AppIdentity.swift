import Foundation

enum AppIdentity {
    static let displayName = "Jarvis"
    static let executableName = "Jarvis"
    static let bundleIdentifier = "dev.infinitestack.jarvis"
    static let keychainService = bundleIdentifier

    static let releaseRepository = "roughcoder/jarvis-apple"
    static let legacyReleaseRepository = "roughcoder/jarvis-swift-toolbar"

    static let releaseAssetName = "Jarvis-macos.zip"
    static let legacyReleaseAssetName = "JarvisMenuBar-macos.zip"
}
