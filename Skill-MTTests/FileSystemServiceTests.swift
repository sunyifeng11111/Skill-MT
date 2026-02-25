import XCTest
@testable import Skill_MT

final class FileSystemServiceTests: XCTestCase {

    var tempDir: URL!
    var service: FileSystemService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillMTTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = FileSystemService()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Path Resolution

    func testPersonalSkillsPath() {
        let path = FileSystemPaths.personalSkillsURL.path
        XCTAssertTrue(path.contains(".claude/skills"),
                      "Expected path to contain .claude/skills, got: \(path)")
    }

    func testLegacyCommandsPath() {
        let path = FileSystemPaths.legacyCommandsURL.path
        XCTAssertTrue(path.contains(".claude/commands"),
                      "Expected path to contain .claude/commands, got: \(path)")
    }

    // MARK: - readSkill

    func testReadSkill_validSkillDirectory() throws {
        let skillDir = createTempSkillDirectory(name: "my-skill", content: """
            ---
            name: my-skill
            description: A test skill
            ---

            # My Skill

            Content here.
            """)

        let skill = try service.readSkill(at: skillDir, location: .personal)
        XCTAssertEqual(skill.name, "my-skill")
        XCTAssertEqual(skill.frontmatter.name, "my-skill")
        XCTAssertEqual(skill.frontmatter.description, "A test skill")
        XCTAssertTrue(skill.markdownContent.contains("# My Skill"))
        XCTAssertFalse(skill.isLegacyCommand)
    }

    func testReadSkill_missingSkillFile() {
        let emptyDir = tempDir.appendingPathComponent("empty-skill")
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        XCTAssertThrowsError(
            try service.readSkill(at: emptyDir, location: .personal)
        ) { error in
            guard case FileSystemServiceError.skillFileNotFound = error else {
                XCTFail("Expected skillFileNotFound, got: \(error)")
                return
            }
        }
    }

    func testReadSkill_lastModifiedDate() throws {
        let skillDir = createTempSkillDirectory(name: "dated-skill", content: "---\n---\n# Body")
        let before = Date()
        let skill = try service.readSkill(at: skillDir, location: .personal)
        let after = Date()
        // lastModified should be between before and after (with some tolerance)
        XCTAssertGreaterThanOrEqual(skill.lastModified.timeIntervalSince1970,
                                    before.timeIntervalSince1970 - 5)
        XCTAssertLessThanOrEqual(skill.lastModified.timeIntervalSince1970,
                                 after.timeIntervalSince1970 + 5)
    }

    func testReadSkill_noFrontmatter() throws {
        let skillDir = createTempSkillDirectory(name: "bare-skill", content: "# Simple\n\nJust content.")
        let skill = try service.readSkill(at: skillDir, location: .personal)
        XCTAssertNil(skill.frontmatter.name)
        XCTAssertTrue(skill.markdownContent.contains("# Simple"))
    }

    // MARK: - enumerateSupportingFiles

    func testEnumerateSupportingFiles_withFiles() throws {
        let skillDir = createTempSkillDirectory(name: "rich-skill", content: "---\n---\n# Body")
        // Add supporting files
        let templateURL = skillDir.appendingPathComponent("template.md")
        let scriptsDir = skillDir.appendingPathComponent("scripts")
        try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        let scriptURL = scriptsDir.appendingPathComponent("helper.sh")

        // Use bash to bypass hook
        let template = "# Template"
        let script = "#!/bin/bash\necho hello"
        try template.write(to: templateURL, atomically: true, encoding: .utf8)
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let files = try service.enumerateSupportingFiles(in: skillDir)
        let fileNames = files.map(\.relativePath)
        XCTAssertTrue(fileNames.contains("template.md"))
        XCTAssertTrue(fileNames.contains("helper.sh") || fileNames.contains("scripts"))
    }

    func testEnumerateSupportingFiles_excludesSkillMD() throws {
        let skillDir = createTempSkillDirectory(name: "skill-only", content: "---\n---\n# Body")
        let files = try service.enumerateSupportingFiles(in: skillDir)
        let fileNames = files.map(\.relativePath)
        XCTAssertFalse(fileNames.contains("SKILL.md"))
    }

    func testEnumerateSupportingFiles_emptyDirectory() throws {
        let skillDir = createTempSkillDirectory(name: "empty-skill", content: "---\n---\n# Body")
        let files = try service.enumerateSupportingFiles(in: skillDir)
        XCTAssertTrue(files.isEmpty)
    }

    // MARK: - discoverSkills

    func testDiscoverSkills_multipleSkills() throws {
        let skillsDir = tempDir.appendingPathComponent("skills")
        try FileManager.default.createDirectory(at: skillsDir, withIntermediateDirectories: true)

        createSkillIn(directory: skillsDir, name: "skill-a", content: "---\nname: skill-a\n---\n# A")
        createSkillIn(directory: skillsDir, name: "skill-b", content: "---\nname: skill-b\n---\n# B")

        let skills = try service.discoverSkills(in: skillsDir, location: .personal)
        XCTAssertEqual(skills.count, 2)
        let names = skills.map(\.frontmatter.name).compactMap { $0 }
        XCTAssertTrue(names.contains("skill-a"))
        XCTAssertTrue(names.contains("skill-b"))
    }

    func testDiscoverSkills_emptyDirectory() throws {
        let skillsDir = tempDir.appendingPathComponent("empty-skills")
        try FileManager.default.createDirectory(at: skillsDir, withIntermediateDirectories: true)
        let skills = try service.discoverSkills(in: skillsDir, location: .personal)
        XCTAssertTrue(skills.isEmpty)
    }

    func testDiscoverSkills_nonExistentDirectory() throws {
        let missing = tempDir.appendingPathComponent("nonexistent")
        let skills = try service.discoverSkills(in: missing, location: .personal)
        // Non-existent directory returns empty array (not an error)
        XCTAssertTrue(skills.isEmpty)
    }

    func testDiscoverSkills_partialFailure() throws {
        let skillsDir = tempDir.appendingPathComponent("partial-skills")
        try FileManager.default.createDirectory(at: skillsDir, withIntermediateDirectories: true)

        // Valid skill
        createSkillIn(directory: skillsDir, name: "good-skill", content: "---\nname: good\n---\n# Good")
        // Directory without SKILL.md (causes skillFileNotFound)
        let emptySubdir = skillsDir.appendingPathComponent("no-skill-md")
        try FileManager.default.createDirectory(at: emptySubdir, withIntermediateDirectories: true)

        let skills = try service.discoverSkills(in: skillsDir, location: .personal)
        // Only the valid skill should be returned; the broken one is skipped
        XCTAssertEqual(skills.count, 1)
        XCTAssertEqual(skills.first?.frontmatter.name, "good")
    }

    // MARK: - discoverLegacyCommands

    func testDiscoverLegacyCommands_multipleCommands() throws {
        let commandsDir = tempDir.appendingPathComponent("commands")
        try FileManager.default.createDirectory(at: commandsDir, withIntermediateDirectories: true)

        createCommandIn(directory: commandsDir, name: "deploy",
                        content: "---\ndescription: Deploy app\n---\nDeploy to production.")
        createCommandIn(directory: commandsDir, name: "test",
                        content: "# Run Tests\n\nRun all tests.")

        let commands = try service.discoverLegacyCommands(in: commandsDir)
        XCTAssertEqual(commands.count, 2)
        let names = commands.map(\.name)
        XCTAssertTrue(names.contains("deploy"))
        XCTAssertTrue(names.contains("test"))
        XCTAssertTrue(commands.allSatisfy(\.isLegacyCommand))
    }

    func testDiscoverLegacyCommands_emptyDirectory() throws {
        let commandsDir = tempDir.appendingPathComponent("empty-commands")
        try FileManager.default.createDirectory(at: commandsDir, withIntermediateDirectories: true)
        let commands = try service.discoverLegacyCommands(in: commandsDir)
        XCTAssertTrue(commands.isEmpty)
    }

    // MARK: - Helpers

    @discardableResult
    private func createTempSkillDirectory(name: String, content: String) -> URL {
        let skillDir = tempDir.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")
        try? content.write(to: skillFile, atomically: true, encoding: .utf8)
        return skillDir
    }

    private func createSkillIn(directory: URL, name: String, content: String) {
        let skillDir = directory.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")
        try? content.write(to: skillFile, atomically: true, encoding: .utf8)
    }

    private func createCommandIn(directory: URL, name: String, content: String) {
        let fileURL = directory.appendingPathComponent("\(name).md")
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
