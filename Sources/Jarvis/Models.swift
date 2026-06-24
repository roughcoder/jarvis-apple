import Foundation
import SwiftUI

enum StatusLevel: String, CaseIterable, Equatable {
    case green
    case amber
    case red
    case unknown

    var rank: Int {
        switch self {
        case .green: 0
        case .unknown: 1
        case .amber: 2
        case .red: 3
        }
    }

    var title: String {
        switch self {
        case .green: "Healthy"
        case .amber: "Degraded"
        case .red: "Down"
        case .unknown: "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .green: .green
        case .amber: .orange
        case .red: .red
        case .unknown: .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .green: "checkmark.circle.fill"
        case .amber: "exclamationmark.triangle.fill"
        case .red: "xmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

enum JarvisRole: String, CaseIterable, Identifiable, Codable, Hashable {
    case brain
    case intercom
    case worker
    case whatsapp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brain: "Brain"
        case .intercom: "Intercom"
        case .worker: "Worker"
        case .whatsapp: "WhatsApp"
        }
    }

    var launchdLabel: String {
        "com.jarvis.\(rawValue)"
    }

    var launchAgentPath: String {
        "~/Library/LaunchAgents/\(launchdLabel).plist"
    }
}

struct RoleStatus: Identifiable, Equatable {
    let role: JarvisRole
    let level: StatusLevel
    let headline: String
    let detail: String
    let loaded: Bool?

    var id: JarvisRole { role }
}

struct DockerStatus: Equatable {
    let level: StatusLevel
    let headline: String
    let detail: String
}

struct GitStatus: Equatable {
    let level: StatusLevel
    let branch: String
    let revision: String
    let dirty: Bool?
    let detail: String
}

struct PairingSummary: Equatable {
    let identity: String
    let scope: String
    let capabilityCount: Int?
    let detail: String
}

struct WorkerSummary: Equatable {
    let runningJobs: Int?
    let recentStatuses: [String]
    let detail: String
}

struct FleetStatus: Equatable {
    let version: String
    let deviceID: String
    let platform: String
    let roles: [RoleStatus]
    let docker: DockerStatus
    let git: GitStatus
    let pairing: PairingSummary
    let worker: WorkerSummary
    let overall: StatusLevel
    let rawJSON: String
    let lastUpdated: Date

    static let placeholder = FleetStatus(
        version: "unknown",
        deviceID: "unknown",
        platform: "unknown",
        roles: JarvisRole.allCases.map {
            RoleStatus(role: $0, level: .unknown, headline: "Unknown", detail: "No status has been loaded yet.", loaded: nil)
        },
        docker: DockerStatus(level: .unknown, headline: "Unknown", detail: "No Docker status has been loaded yet."),
        git: GitStatus(level: .unknown, branch: "unknown", revision: "unknown", dirty: nil, detail: "No git status has been loaded yet."),
        pairing: PairingSummary(identity: "unknown", scope: "unknown", capabilityCount: nil, detail: "No pairing status has been loaded yet."),
        worker: WorkerSummary(runningJobs: nil, recentStatuses: [], detail: "No worker status has been loaded yet."),
        overall: .unknown,
        rawJSON: "{}",
        lastUpdated: .distantPast
    )
}

struct CommandResult: Equatable {
    let executable: String
    let arguments: [String]
    let currentDirectory: String?
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool
    let duration: TimeInterval

    var succeeded: Bool {
        exitCode == 0 && !timedOut
    }

    var commandLine: String {
        ([executable] + arguments).joined(separator: " ")
    }

    var combinedOutput: String {
        [stdout, stderr].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n")
    }
}
