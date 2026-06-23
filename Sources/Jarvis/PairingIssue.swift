import Foundation

enum PairingIssueParser {
    enum ParseError: LocalizedError {
        case invalidJSON(String)
        case missingFields(String)

        var errorDescription: String? {
            switch self {
            case .invalidJSON(let output):
                return "Could not parse pairing output.\n\(output)"
            case .missingFields(let output):
                return "Pairing output was missing token or brain device entry.\n\(output)"
            }
        }
    }

    static func parse(data: Data) throws -> PairingIssue {
        let root = try JSONValue.dictionary(from: data)
        guard let token = root.string("token"),
              let entry = root.string("brain_devices_entry"),
              !token.isEmpty,
              !entry.isEmpty else {
            throw ParseError.missingFields(String(data: data, encoding: .utf8) ?? "")
        }

        return PairingIssue(
            token: token,
            brainDevicesEntry: entry,
            brainConfigPath: root.string("brain_config_path"),
            brainDevicesCount: root.int("brain_devices_count"),
            macConfigCommand: root.string("mac_config_command"),
            piInstallerCommand: root.string("pi_installer_command")
        )
    }
}

struct PairingIssue: Equatable {
    let token: String
    let brainDevicesEntry: String
    let brainConfigPath: String?
    let brainDevicesCount: Int?
    let macConfigCommand: String?
    let piInstallerCommand: String?
}
