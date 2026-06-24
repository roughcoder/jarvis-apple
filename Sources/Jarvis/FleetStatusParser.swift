import Foundation

enum FleetStatusParser {
    enum ParseError: Error {
        case topLevelObjectIsNotDictionary
    }

    static func parse(data: Data, receivedAt: Date = Date()) throws -> FleetStatus {
        let root = try JSONValue.dictionary(from: data)
        let redactedRawJSON = Redactor.redactedJSONString(from: root)

        let version = firstString(in: root, keys: ["version"]) ?? "unknown"
        let deviceID = firstString(in: root, keys: ["device_id", "deviceId", "device"]) ?? "unknown"
        let platform = firstString(in: root, keys: ["platform", "host_platform"]) ?? "unknown"

        let roles = JarvisRole.allCases.map { roleStatus(for: $0, root: root) }
        let docker = dockerStatus(root: root)
        let git = gitStatus(root: root)
        let pairing = pairingSummary(root: root)
        let worker = workerSummary(root: root)

        let levels = [docker.level, git.level] + roles.map(\.level)
        let actionableLevels = levels.filter { $0 != .unknown }
        let overall = actionableLevels.max { $0.rank < $1.rank }
            ?? (levels.contains(.unknown) ? .unknown : .green)

        return FleetStatus(
            version: version,
            deviceID: deviceID,
            platform: platform,
            roles: roles,
            docker: docker,
            git: git,
            pairing: pairing,
            worker: worker,
            overall: overall,
            rawJSON: redactedRawJSON,
            lastUpdated: receivedAt
        )
    }

    private static func roleStatus(for role: JarvisRole, root: JSONDictionary) -> RoleStatus {
        let roleNode = root.dictionary(role.rawValue) ?? [:]
        let roleProbeNode = roleNode.dictionary("probe") ?? [:]
        let roleHealthNode = roleProbeNode.dictionary("health") ?? [:]
        let pairingNode = root.dictionary("pairing")
            ?? root.dictionary("intercom")?.dictionary("pairing")
            ?? root.dictionary("brain")?.dictionary("pairing")
            ?? [:]
        let servicesNode = root.dictionary("services") ?? [:]
        let serviceNode = servicesNode.dictionary(role.rawValue)
            ?? servicesNode.dictionary(role.launchdLabel)
            ?? [:]

        let loaded = firstBool(nodes: [roleNode, serviceNode], keys: [
            "loaded",
            "launchd_loaded",
            "is_loaded",
            "running",
            "service_loaded"
        ])

        let reachable = firstBool(nodes: [roleNode, roleProbeNode, roleHealthNode, serviceNode], keys: [
            "reachable",
            "health_reachable",
            "healthy",
            "ok",
            "responding"
        ])

        let paired = firstBool(nodes: [roleNode, pairingNode, serviceNode], keys: [
            "paired",
            "pairing_reachable",
            "brain_reachable",
            "intercom_pairing_reachable"
        ])

        let jobErrors = firstBool(nodes: [roleNode, roleProbeNode, roleHealthNode], keys: ["jobs_errored", "has_failed_jobs", "recent_errors"])
        let guiConfigured = firstBool(nodes: [roleNode, roleProbeNode, roleHealthNode], keys: ["gui_configured", "browser_configured"])
        let explicit = explicitStatusLevel(from: [roleNode, roleProbeNode, roleHealthNode, serviceNode])

        let level: StatusLevel
        switch role {
        case .brain:
            if loaded == false || reachable == false {
                level = .red
            } else if loaded == true && (paired == true || reachable == true || explicit == .green) {
                level = .green
            } else if loaded == true {
                level = .amber
            } else {
                level = explicit ?? .unknown
            }
        case .intercom:
            if loaded == false {
                level = .red
            } else if loaded == true && paired == true {
                level = .green
            } else if loaded == true {
                level = .amber
            } else {
                level = explicit ?? .unknown
            }
        case .worker:
            if loaded == false || reachable == false {
                level = .red
            } else if loaded == true && reachable == true && jobErrors != true && guiConfigured != false {
                level = .green
            } else if loaded == true || reachable == true {
                level = .amber
            } else {
                level = explicit ?? .unknown
            }
        case .whatsapp:
            if loaded == false {
                level = .red
            } else if loaded == true {
                level = .green
            } else {
                level = explicit ?? .unknown
            }
        }

        return RoleStatus(
            role: role,
            level: level,
            headline: headline(for: role, level: level, loaded: loaded, reachable: reachable, paired: paired),
            detail: roleDetail(roleNode: roleNode, serviceNode: serviceNode, loaded: loaded, reachable: reachable, paired: paired),
            loaded: loaded
        )
    }

    private static func dockerStatus(root: JSONDictionary) -> DockerStatus {
        guard let node = root.dictionary("docker") else {
            return DockerStatus(level: .unknown, headline: "Unknown", detail: "Docker status is missing from fleet-status.")
        }

        let explicit = explicitStatusLevel(from: [node])
        let available = firstBool(nodes: [node], keys: ["available", "docker_available", "running"])
        let configured = firstBool(nodes: [node], keys: ["configured", "compose_configured"])
        let allRunning = firstBool(nodes: [node], keys: ["all_running", "required_running", "compose_running"])
        let requiredStopped = firstBool(nodes: [node], keys: ["required_stopped", "required_services_stopped"])

        let level: StatusLevel
        if configured == false {
            level = .green
        } else if requiredStopped == true || allRunning == false {
            level = .red
        } else if allRunning == true {
            level = .green
        } else if available == false {
            level = .amber
        } else {
            level = explicit ?? .amber
        }

        let headline = firstString(in: node, keys: ["summary", "status", "state"])
            ?? (configured == false ? "Not configured" : level.title)
        let detail = firstString(in: node, keys: ["detail", "message", "reason"])
            ?? "Docker checks are \(level.title.lowercased())."
        return DockerStatus(level: level, headline: headline.capitalizedSentence, detail: detail)
    }

    private static func gitStatus(root: JSONDictionary) -> GitStatus {
        guard let node = root.dictionary("git") else {
            return GitStatus(level: .unknown, branch: "unknown", revision: "unknown", dirty: nil, detail: "Git status is missing from fleet-status.")
        }

        let available = firstBool(nodes: [node], keys: ["available"])
        if available == false {
            return GitStatus(
                level: .green,
                branch: "Homebrew",
                revision: "installed",
                dirty: false,
                detail: "Installed runtime; no source checkout."
            )
        }

        let dirty = firstBool(nodes: [node], keys: ["dirty", "has_changes", "working_tree_dirty"])
        let updateFailed = firstBool(nodes: [node], keys: ["update_failed", "pull_failed"])
        let explicit = explicitStatusLevel(from: [node])
        let level: StatusLevel
        if updateFailed == true {
            level = .red
        } else if dirty == true {
            level = .amber
        } else if dirty == false {
            level = .green
        } else {
            level = explicit ?? .unknown
        }

        let branch = firstString(in: node, keys: ["branch", "expected_branch", "current_branch"]) ?? "unknown"
        let revision = firstString(in: node, keys: ["revision", "rev", "sha", "commit", "short_sha"]) ?? "unknown"
        let detail = firstString(in: node, keys: ["detail", "message", "status"])
            ?? (dirty == true ? "Working tree has local changes." : "Git status is \(level.title.lowercased()).")

        return GitStatus(level: level, branch: branch, revision: revision, dirty: dirty, detail: detail)
    }

    private static func pairingSummary(root: JSONDictionary) -> PairingSummary {
        let node = root.dictionary("pairing")
            ?? root.dictionary("intercom")?.dictionary("pairing")
            ?? root.dictionary("brain")?.dictionary("pairing")
            ?? [:]

        let identity = firstString(in: node, keys: ["identity", "device_identity", "peer_identity"])
            ?? firstString(in: root, keys: ["identity"])
            ?? "unknown"
        let scope = firstString(in: node, keys: ["scope", "pairing_scope", "fleet_scope"]) ?? "unknown"
        let capabilityCount = firstInt(in: node, keys: ["capability_count", "capabilities_count"])
            ?? node.array("capabilities")?.count
            ?? root.dictionary("worker")?.array("capabilities")?.count
        let capabilityText = capabilityCount.map { "\($0) capabilities" } ?? "capability count unknown"
        let detail = firstString(in: node, keys: ["detail", "summary", "message"])
            ?? "\(identity), \(scope), \(capabilityText)"

        return PairingSummary(identity: identity, scope: scope, capabilityCount: capabilityCount, detail: detail)
    }

    private static func workerSummary(root: JSONDictionary) -> WorkerSummary {
        let node = root.dictionary("worker") ?? [:]
        let jobsNode = node.dictionary("jobs") ?? root.dictionary("jobs") ?? [:]
        let runningJobs = firstInt(in: node, keys: ["running_jobs", "active_jobs"])
            ?? firstInt(in: jobsNode, keys: ["running", "active"])

        var statuses = [String]()
        if let recent = jobsNode.array("recent") ?? node.array("recent_jobs") {
            statuses = recent.compactMap { item in
                if let dict = item as? JSONDictionary {
                    return firstString(in: dict, keys: ["status", "state", "result"])
                }
                return JSONValue.compactString(item)
            }
        } else if let values = jobsNode.array("statuses") ?? node.array("job_statuses") {
            statuses = values.compactMap(JSONValue.compactString)
        }

        let detail = firstString(in: jobsNode, keys: ["detail", "summary", "message"])
            ?? firstString(in: node, keys: ["jobs_detail", "summary"])
            ?? {
                let running = runningJobs.map(String.init) ?? "unknown"
                let recent = statuses.isEmpty ? "no recent statuses" : statuses.prefix(4).joined(separator: ", ")
                return "\(running) running, \(recent)"
            }()

        return WorkerSummary(runningJobs: runningJobs, recentStatuses: Array(statuses.prefix(6)), detail: detail)
    }

    private static func headline(
        for role: JarvisRole,
        level: StatusLevel,
        loaded: Bool?,
        reachable: Bool?,
        paired: Bool?
    ) -> String {
        if loaded == false {
            return "Stopped"
        }
        if reachable == false {
            return "Unreachable"
        }
        if role == .intercom && paired == false {
            return "Unpaired"
        }
        return level.title
    }

    private static func roleDetail(
        roleNode: JSONDictionary,
        serviceNode: JSONDictionary,
        loaded: Bool?,
        reachable: Bool?,
        paired: Bool?
    ) -> String {
        if let detail = firstString(in: roleNode, keys: ["detail", "summary", "message", "reason"])
            ?? firstString(in: serviceNode, keys: ["detail", "summary", "message", "reason"]) {
            return detail
        }

        var parts = [String]()
        if let loaded {
            parts.append(loaded ? "launchd loaded" : "launchd stopped")
        }
        if let reachable {
            parts.append(reachable ? "health reachable" : "health unreachable")
        }
        if let paired {
            parts.append(paired ? "paired" : "unpaired")
        }
        return parts.isEmpty ? "No detailed status was reported." : parts.joined(separator: ", ")
    }

    private static func explicitStatusLevel(from nodes: [JSONDictionary]) -> StatusLevel? {
        let status = firstString(nodes: nodes, keys: ["status", "state", "health", "level"])?.lowercased()
        guard let status else {
            return nil
        }

        if ["ok", "healthy", "green", "running", "active", "clean", "ready", "reachable", "paired"].contains(status) {
            return .green
        }
        if ["degraded", "warning", "warn", "amber", "dirty", "partial", "unpaired", "unconfigured"].contains(status) {
            return .amber
        }
        if ["error", "failed", "red", "down", "stopped", "unreachable", "unhealthy"].contains(status) {
            return .red
        }
        if ["unknown", "missing"].contains(status) {
            return .unknown
        }
        return nil
    }

    private static func firstString(in node: JSONDictionary, keys: [String]) -> String? {
        firstString(nodes: [node], keys: keys)
    }

    private static func firstString(nodes: [JSONDictionary], keys: [String]) -> String? {
        for node in nodes {
            for key in keys {
                if let value = node.string(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    private static func firstBool(nodes: [JSONDictionary], keys: [String]) -> Bool? {
        for node in nodes {
            for key in keys {
                if let value = node.bool(key) {
                    return value
                }
            }
        }
        return nil
    }

    private static func firstInt(in node: JSONDictionary, keys: [String]) -> Int? {
        for key in keys {
            if let value = node.int(key) {
                return value
            }
        }
        return nil
    }
}

private extension String {
    var capitalizedSentence: String {
        guard let first else {
            return self
        }
        return first.uppercased() + dropFirst()
    }
}
