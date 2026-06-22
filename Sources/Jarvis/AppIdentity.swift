import Foundation

enum AppIdentity {
    static let displayName = "Jarvis"
    static let executableName = "Jarvis"
    static let menuBarSymbolName = "brain.head.profile"
    static let macOSBundleIdentifier = "dev.infinitestack.jarvis.mac"
    static let iOSBundleIdentifier = "dev.infinitestack.jarvis.ios"
    static let bundleIdentifier = macOSBundleIdentifier
    static let keychainService = macOSBundleIdentifier

    static let releaseRepository = "roughcoder/jarvis-apple"
    static let legacyReleaseRepository = "roughcoder/jarvis-swift-toolbar"

    static let releaseAssetName = "Jarvis-macos.zip"
    static let legacyReleaseAssetName = "JarvisMenuBar-macos.zip"

    static let homebrewTap = "roughcoder/infinite-stack"
    static let homebrewTapRepository = "roughcoder/homebrew-infinite-stack"
    static let homebrewCaskToken = "jarvis-app"
}
