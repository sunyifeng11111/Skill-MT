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

        let claudeHome = tempRoot.appendingPathComponent("claude-home")
        let codexHome = tempRoot.appendingPathComponent("codex-home")
        try? FileManager.default.createDirectory(at: claudeHome, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        settings.saveClaudeHome(claudeHome.path)
        settings.saveCodexHome(codexHome.path)
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

    func testMoveSkill_personalToProject_movesDirectoryAndDeletesSource() throws {
        let projectRoot = tempRoot.appendingPathComponent("project-a")
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let service = SkillCRUDService(fileManager: .default, settings: settings)

        let sourceDir = try service.createSkill(
            name: "move-me",
            frontmatter: SkillFrontmatter(description: "demo"),
            markdownContent: "# Body",
            location: .personal
        )
        let skill = try FileSystemService(fileManager: .default, settings: settings)
            .readSkill(at: sourceDir, location: .personal)

        let targetDir = try service.moveSkill(skill, to: .project(path: projectRoot.path))

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("SKILL.md").path))
    }

    func testMoveSkill_projectToPersonal_movesDirectoryAndDeletesSource() throws {
        let projectRoot = tempRoot.appendingPathComponent("project-b")
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let service = SkillCRUDService(fileManager: .default, settings: settings)

        let sourceDir = try service.createSkill(
            name: "from-project",
            frontmatter: SkillFrontmatter(description: "demo"),
            markdownContent: "# Body",
            location: .project(path: projectRoot.path)
        )
        let skill = try FileSystemService(fileManager: .default, settings: settings)
            .readSkill(at: sourceDir, location: .project(path: projectRoot.path))

        let targetDir = try service.moveSkill(skill, to: .personal)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetDir.path))
    }

    func testMoveSkill_codexPersonalToCodexProject_movesDirectory() throws {
        let projectRoot = tempRoot.appendingPathComponent("codex-project-a")
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let service = SkillCRUDService(fileManager: .default, settings: settings)

        let sourceDir = try service.createSkill(
            name: "codex-move",
            frontmatter: SkillFrontmatter(description: "demo"),
            markdownContent: "# Body",
            location: .codexPersonal
        )
        let skill = try FileSystemService(fileManager: .default, settings: settings)
            .readSkill(at: sourceDir, location: .codexPersonal)

        let targetDir = try service.moveSkill(skill, to: .codexProject(path: projectRoot.path))

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetDir.path))
    }

    func testMoveSkill_nameConflict_throwsDirectoryAlreadyExists() throws {
        let projectRoot = tempRoot.appendingPathComponent("project-conflict")
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let service = SkillCRUDService(fileManager: .default, settings: settings)

        let sourceDir = try service.createSkill(
            name: "same-name",
            frontmatter: SkillFrontmatter(description: "source"),
            markdownContent: "# Source",
            location: .personal
        )
        _ = try service.createSkill(
            name: "same-name",
            frontmatter: SkillFrontmatter(description: "target"),
            markdownContent: "# Target",
            location: .project(path: projectRoot.path)
        )
        let skill = try FileSystemService(fileManager: .default, settings: settings)
            .readSkill(at: sourceDir, location: .personal)

        XCTAssertThrowsError(try service.moveSkill(skill, to: .project(path: projectRoot.path))) { error in
            guard case SkillCRUDError.directoryAlreadyExists = error else {
                XCTFail("Expected directoryAlreadyExists, got: \(error)")
                return
            }
        }
    }

    func testMoveSkill_preservesDisabledStateFile() throws {
        let projectRoot = tempRoot.appendingPathComponent("project-disabled")
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let service = SkillCRUDService(fileManager: .default, settings: settings)

        let sourceDir = try service.createSkill(
            name: "disabled-skill",
            frontmatter: SkillFrontmatter(description: "demo"),
            markdownContent: "# Body",
            location: .personal
        )
        let sourceSkill = try FileSystemService(fileManager: .default, settings: settings)
            .readSkill(at: sourceDir, location: .personal)
        try service.setSkillEnabled(sourceSkill, enabled: false)

        let disabledSkill = try FileSystemService(fileManager: .default, settings: settings)
            .readSkill(at: sourceDir, location: .personal)
        let targetDir = try service.moveSkill(disabledSkill, to: .project(path: projectRoot.path))

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: targetDir.appendingPathComponent("SKILL.md.disabled").path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: targetDir.appendingPathComponent("SKILL.md").path
        ))
    }

    func testMoveSkill_preservesSupportingFiles() throws {
        let projectRoot = tempRoot.appendingPathComponent("project-supporting")
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let service = SkillCRUDService(fileManager: .default, settings: settings)

        let sourceDir = try service.createSkill(
            name: "with-files",
            frontmatter: SkillFrontmatter(description: "demo"),
            markdownContent: "# Body",
            location: .personal
        )
        let scriptsDir = sourceDir.appendingPathComponent("scripts")
        try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        let helperFile = scriptsDir.appendingPathComponent("helper.sh")
        try "echo hi".write(to: helperFile, atomically: true, encoding: .utf8)

        let skill = try FileSystemService(fileManager: .default, settings: settings)
            .readSkill(at: sourceDir, location: .personal)
        let targetDir = try service.moveSkill(skill, to: .project(path: projectRoot.path))

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: targetDir.appendingPathComponent("scripts/helper.sh").path
        ))
    }
}
