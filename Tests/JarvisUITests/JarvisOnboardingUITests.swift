import XCTest

final class JarvisOnboardingUITests: XCTestCase {
    private var app: XCUIApplication?
    private var temporaryDirectory: URL?

    override func tearDownWithError() throws {
        app?.terminate()
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        app = nil
        temporaryDirectory = nil
    }

    @MainActor
    func testFirstRunSetupCanApplyAndMarkComplete() throws {
        let harness = try makeHarness(serviceInstallResult: "success")
        let app = harness.app
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["setup.wizard"].waitForExistence(timeout: 5))
        completeRequiredSetupFields(in: app)
        runUITestCommand("apply", in: app)

        waitForUITestState("validated", in: app)
        XCTAssertEqual(app.textFields["setup.test.completed"].value as? String, "true")
    }

    @MainActor
    func testServiceInstallFailureKeepsSetupIncomplete() throws {
        let harness = try makeHarness(serviceInstallResult: "failure")
        let app = harness.app
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["setup.wizard"].waitForExistence(timeout: 5))
        completeRequiredSetupFields(in: app)
        runUITestCommand("apply", in: app)

        waitForUITestState("error", in: app)
        let error = app.textFields["setup.test.error"]
        let errorValue = error.value as? String ?? ""
        XCTAssertTrue(errorValue.contains("Service installation failed"), "Unexpected setup error: \(errorValue)")
        XCTAssertEqual(app.textFields["setup.test.completed"].value as? String, "false")
    }

    @MainActor
    private func completeRequiredSetupFields(in app: XCUIApplication) {
        replaceText(app.textFields["setup.admin.name"], with: "Neil Barton")
        replaceText(app.textFields["setup.admin.email"], with: "neil@example.com")
        replaceText(app.textFields["setup.admin.phone"], with: "+447921815819")
        runUITestCommand("next", in: app)

        replaceText(app.textFields["setup.machine.device"], with: "office-mac")
        replaceText(app.textFields["setup.machine.room"], with: "Office")
        runUITestCommand("next", in: app)

        runUITestCommand("brain", in: app)
    }

    @MainActor
    private func replaceText(_ element: XCUIElement, with text: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        element.click()
        element.typeKey("a", modifierFlags: [.command])
        element.typeText(text)
    }

    @MainActor
    private func runUITestCommand(_ command: String, in app: XCUIApplication) {
        replaceText(app.textFields["setup.test.command"], with: command)
    }

    @MainActor
    private func waitForUITestState(_ state: String, in app: XCUIApplication, timeout: TimeInterval = 8) {
        let element = app.textFields["setup.test.state"]
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        let predicate = NSPredicate(format: "value == %@", state)
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: timeout)
        let currentValue = element.value as? String ?? ""
        let currentError = app.textFields["setup.test.error"].value as? String ?? ""
        XCTAssertEqual(currentValue, state, "Current setup state: \(currentValue), error: \(currentError)")
    }

    @MainActor
    private func makeHarness(serviceInstallResult: String) throws -> Harness {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("JarvisUITests-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectory = temp
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

        let fakeRuntime = try makeFakeRuntime(temp: temp)
        let defaultsSuite = "JarvisUITests-\(UUID().uuidString)"
        UserDefaults(suiteName: defaultsSuite)?.removePersistentDomain(forName: defaultsSuite)

        let app = XCUIApplication()
        app.launchEnvironment = [
            "JARVIS_APP_DEFAULTS_SUITE": defaultsSuite,
            "JARVIS_APP_JARVIS_PATH": fakeRuntime.path,
            "JARVIS_APP_JARVIS_REPO_PATH": "",
            "JARVIS_APP_UV_PATH": "/usr/bin/false",
            "JARVIS_APP_LOGS_PATH": temp.appendingPathComponent("logs").path,
            "JARVIS_APP_UI_TEST_MODE": "1",
            "JARVIS_APP_UI_TEST_SERVICE_INSTALL": serviceInstallResult
        ]
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "--jarvis-ui-test-mode"]
        self.app = app
        return Harness(app: app, defaultsSuite: defaultsSuite)
    }

    private func makeFakeRuntime(temp: URL) throws -> URL {
        let script = temp.appendingPathComponent("jarvis-fake")
        let payloadPath = temp.appendingPathComponent("setup-apply.json").path
        let content = """
        #!/usr/bin/env bash
        set -euo pipefail
        command="${1:-}"
        subcommand="${2:-}"

        if [[ "$command" == "setup" && "$subcommand" == "read" ]]; then
          cat <<'JSON'
        {"admin":{"name":"","email":"","phone":"","whatsapp_admin":""},"machine":{"device_id":"office-mac","room":"Office","personal":true},"roles":[],"providers":{"has_openai_api_key":false,"has_openrouter_api_key":false,"has_anthropic_api_key":false,"has_gemini_api_key":false,"has_tts_api_key":false,"has_tools_websearch_api_key":false,"has_worker_peekaboo_openai_api_key":false,"has_worker_peekaboo_openrouter_api_key":false},"brain":{"host":"0.0.0.0","port":"8700"},"intercom":{"brain_host":"","brain_port":"8700","token":"","paired":false},"worker":{"repo_root":"","agent":"codex","shell_secrets":"","peekaboo_ai_providers":"","peekaboo_openai_base_url":"","peekaboo_agent_model":"gpt-5.5"},"whatsapp":{"enabled":false,"admin":"","dm_policy":"pairing","account":"","device_id":"whatsapp"}}
        JSON
        elif [[ "$command" == "setup" && "$subcommand" == "apply" ]]; then
          cat > "\(payloadPath)"
          echo '{"env_file":"~/.jarvis/.env","user_file":"~/.jarvis/jarvis-workspace/users/neil-barton.md","roles":["brain"],"changed_keys":["BRAIN_HOST","BRAIN_PORT"]}'
        elif [[ "$command" == "setup" && "$subcommand" == "validate" ]]; then
          echo '{"ok":true,"missing":[],"warnings":[]}'
        elif [[ "$command" == "fleet-status" ]]; then
          cat <<'JSON'
        {"version":"uitest","device_id":"office-mac","platform":"Darwin","services":{"brain":{"loaded":true}},"brain":{"reachable":true,"paired":true},"git":{"available":false},"docker":{"configured":false},"pairing":{"identity":"neil-barton","scope":"personal","capabilities":1},"worker":{"running_jobs":0}}
        JSON
        else
          echo "unexpected fake jarvis command: $*" >&2
          exit 2
        fi
        """
        try content.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return script
    }
}

private struct Harness {
    let app: XCUIApplication
    let defaultsSuite: String
}
