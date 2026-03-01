import XCTest
@testable import Skill_MT

@MainActor
final class AppStateMoveTests: XCTestCase {

    private func makeState() -> AppState {
        let suiteName = "AppStateMoveTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let settings = AppSettings(defaults: defaults)
        return AppState(settings: settings)
    }

    private func makeSkill(location: SkillLocation, path: String, isLegacyCommand: Bool = false) -> Skill {
        Skill(
            name: "demo",
            frontmatter: .default,
            markdownContent: "# body",
            location: location,
            directoryURL: URL(fileURLWithPath: path),
            isLegacyCommand: isLegacyCommand
        )
    }

    func testAvailableMoveTargets_personalAndProjectClaude() {
        let state = makeState()
        state.monitoredProjectURLs = [
            URL(fileURLWithPath: "/tmp/proj-a"),
            URL(fileURLWithPath: "/tmp/proj-b")
        ]

        let personalSkill = makeSkill(location: .personal, path: "/tmp/global/demo")
        let personalTargets = state.availableMoveTargets(for: personalSkill)
        XCTAssertEqual(personalTargets.count, 2)
        XCTAssertTrue(personalTargets.contains(.project(path: "/tmp/proj-a")))
        XCTAssertTrue(personalTargets.contains(.project(path: "/tmp/proj-b")))

        let projectSkill = makeSkill(location: .project(path: "/tmp/proj-a"), path: "/tmp/proj-a/.claude/skills/demo")
        let projectTargets = state.availableMoveTargets(for: projectSkill)
        XCTAssertTrue(projectTargets.contains(.personal))
        XCTAssertTrue(projectTargets.contains(.project(path: "/tmp/proj-b")))
        XCTAssertFalse(projectTargets.contains(.project(path: "/tmp/proj-a")))
    }

    func testAvailableMoveTargets_personalAndProjectCodex() {
        let state = makeState()
        state.monitoredProjectURLs = [
            URL(fileURLWithPath: "/tmp/codex-a"),
            URL(fileURLWithPath: "/tmp/codex-b")
        ]

        let personalSkill = makeSkill(location: .codexPersonal, path: "/tmp/codex-global/demo")
        let personalTargets = state.availableMoveTargets(for: personalSkill)
        XCTAssertEqual(personalTargets.count, 2)
        XCTAssertTrue(personalTargets.contains(.codexProject(path: "/tmp/codex-a")))
        XCTAssertTrue(personalTargets.contains(.codexProject(path: "/tmp/codex-b")))

        let projectSkill = makeSkill(location: .codexProject(path: "/tmp/codex-a"), path: "/tmp/codex-a/.agents/skills/demo")
        let projectTargets = state.availableMoveTargets(for: projectSkill)
        XCTAssertTrue(projectTargets.contains(.codexPersonal))
        XCTAssertTrue(projectTargets.contains(.codexProject(path: "/tmp/codex-b")))
        XCTAssertFalse(projectTargets.contains(.codexProject(path: "/tmp/codex-a")))
    }

    func testAvailableMoveTargets_readOnlyAndLegacyReturnEmpty() {
        let state = makeState()
        state.monitoredProjectURLs = [URL(fileURLWithPath: "/tmp/proj-a")]

        let systemSkill = makeSkill(location: .codexSystem(path: "/tmp/.codex/skills/.system/demo"), path: "/tmp/.codex/skills/.system/demo")
        let pluginSkill = makeSkill(location: .plugin(id: "p", name: "plugin", skillsURL: "/tmp/plugin"), path: "/tmp/plugin/demo")
        let legacyCommand = makeSkill(location: .legacyCommand(path: "/tmp/.claude/commands"), path: "/tmp/.claude/commands/demo.md", isLegacyCommand: true)

        XCTAssertTrue(state.availableMoveTargets(for: systemSkill).isEmpty)
        XCTAssertTrue(state.availableMoveTargets(for: pluginSkill).isEmpty)
        XCTAssertTrue(state.availableMoveTargets(for: legacyCommand).isEmpty)
    }

    func testAvailableMoveTargets_noProjectsForGlobal_returnsEmpty() {
        let state = makeState()
        state.monitoredProjectURLs = []
        let personalSkill = makeSkill(location: .personal, path: "/tmp/global/demo")
        XCTAssertTrue(state.availableMoveTargets(for: personalSkill).isEmpty)
    }
}
