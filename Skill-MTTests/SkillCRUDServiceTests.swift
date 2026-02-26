import XCTest
@testable import Skill_MT

final class SkillCRUDServiceTests: XCTestCase {

    private var tempRoot: URL!
    private var settings: AppSettings!
    private var defaultsSuite: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillCRUDServiceTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let suiteName = "SkillCRUDServiceTests.\(UUID().uuidString)"
        defaultsSuiteName = suiteName
        defaultsSuite = UserDefaults(suiteName: suiteName) ?? .standard
        settings = AppSettings(defaults: defaultsSuite)
    }

    override func tearDown() {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        if let name = defaultsSuiteName {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        settings = nil
        defaultsSuite = nil
        defaultsSuiteName = nil
        tempRoot = nil
        super.tearDown()
    }

    func testCreateSkill_projectLocation_writesUnderProjectSkillsDirectory() throws {
        let globalClaudeHome = tempRoot.appendingPathComponent("global-claude-home")
        let projectRoot = tempRoot.appendingPathComponent("my-project")
        try FileManager.default.createDirectory(at: globalClaudeHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        settings.saveClaudeHome(globalClaudeHome.path)

        let service = SkillCRUDService(fileManager: .default, settings: settings)
        let createdDir = try service.createSkill(
            name: "project-skill",
            frontmatter: SkillFrontmatter(description: "Project scoped"),
            markdownContent: "# Body",
            location: .project(path: projectRoot.path)
        )

        XCTAssertEqual(
            createdDir.path,
            projectRoot
                .appendingPathComponent(".claude")
                .appendingPathComponent("skills")
                .appendingPathComponent("project-skill")
                .path
        )
        XCTAssertFalse(createdDir.path.hasPrefix(globalClaudeHome.path))
    }

    func testCreateSkill_description_roundTripsFromWrittenSkillFile() throws {
        let globalClaudeHome = tempRoot.appendingPathComponent("global-claude-home")
        try FileManager.default.createDirectory(at: globalClaudeHome, withIntermediateDirectories: true)
        settings.saveClaudeHome(globalClaudeHome.path)

        let service = SkillCRUDService(fileManager: .default, settings: settings)
        let createdDir = try service.createSkill(
            name: "desc-skill",
            frontmatter: SkillFrontmatter(description: "A test description"),
            markdownContent: "",
            location: .personal
        )

        let fileURL = createdDir.appendingPathComponent("SKILL.md")
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        let (frontmatter, _) = try SkillParser.parse(content: raw)
        XCTAssertEqual(frontmatter.description, "A test description")
    }

    func testCreateSkill_codexProjectLocation_writesUnderAgentsSkillsDirectory() throws {
        let projectRoot = tempRoot.appendingPathComponent("codex-project")
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)

        let service = SkillCRUDService(fileManager: .default, settings: settings)
        let createdDir = try service.createSkill(
            name: "codex-project-skill",
            frontmatter: SkillFrontmatter(description: "Codex project scoped"),
            markdownContent: "# Body",
            location: .codexProject(path: projectRoot.path)
        )

        XCTAssertEqual(
            createdDir.path,
            projectRoot
                .appendingPathComponent(".agents")
                .appendingPathComponent("skills")
                .appendingPathComponent("codex-project-skill")
                .path
        )
    }
}
