import XCTest
@testable import Skill_MT

final class SkillModelTests: XCTestCase {

    // MARK: - SkillFrontmatter

    func testSkillFrontmatter_defaultValues() {
        let fm = SkillFrontmatter.default
        XCTAssertNil(fm.name)
        XCTAssertNil(fm.description)
        XCTAssertNil(fm.argumentHint)
        XCTAssertFalse(fm.disableModelInvocation)
        XCTAssertTrue(fm.userInvocable)
        XCTAssertNil(fm.allowedTools)
        XCTAssertNil(fm.model)
        XCTAssertNil(fm.context)
        XCTAssertNil(fm.agent)
        XCTAssertNil(fm.hooksRaw)
    }

    func testSkillFrontmatter_customInit() {
        let fm = SkillFrontmatter(
            name: "test",
            description: "A test skill",
            disableModelInvocation: true,
            userInvocable: false,
            model: "sonnet"
        )
        XCTAssertEqual(fm.name, "test")
        XCTAssertEqual(fm.description, "A test skill")
        XCTAssertTrue(fm.disableModelInvocation)
        XCTAssertFalse(fm.userInvocable)
        XCTAssertEqual(fm.model, "sonnet")
    }

    func testSkillFrontmatter_hashable() {
        let fm1 = SkillFrontmatter(name: "a")
        let fm2 = SkillFrontmatter(name: "a")
        let fm3 = SkillFrontmatter(name: "b")
        XCTAssertEqual(fm1, fm2)
        XCTAssertNotEqual(fm1, fm3)
    }

    // MARK: - SkillLocation

    func testSkillLocation_personalDisplayName() {
        XCTAssertEqual(SkillLocation.personal.displayName, String(localized: "Personal"))
    }

    func testSkillLocation_projectDisplayName() {
        let loc = SkillLocation.project(path: "/Users/sun/myapp")
        XCTAssertTrue(loc.displayName.contains("myapp"))
    }

    func testSkillLocation_legacyCommandDisplayName() {
        let loc = SkillLocation.legacyCommand(path: "/Users/sun/.claude/commands")
        XCTAssertEqual(loc.displayName, String(localized: "Legacy Command"))
    }

    func testSkillLocation_hashable() {
        let a = SkillLocation.personal
        let b = SkillLocation.personal
        let c = SkillLocation.project(path: "/foo")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testSkillLocation_basePath_personal() {
        let base = SkillLocation.personal.basePath
        XCTAssertTrue(base.path.hasSuffix("/skills"))
    }

    func testSkillLocation_basePath_project() {
        let loc = SkillLocation.project(path: "/Users/sun/myapp")
        let base = loc.basePath
        XCTAssertEqual(base.path, "/Users/sun/myapp/.claude/skills")
    }

    func testSkillLocation_basePath_codexProject() {
        let loc = SkillLocation.codexProject(path: "/Users/sun/myapp")
        let base = loc.basePath
        XCTAssertEqual(base.path, "/Users/sun/myapp/.agents/skills")
    }

    func testSkillLocation_basePath_codexPersonal() {
        let base = SkillLocation.codexPersonal.basePath
        XCTAssertTrue(base.path.hasSuffix("/skills"))
    }

    func testSkillLocation_codexSystemDisplayName() {
        let loc = SkillLocation.codexSystem(path: "/Users/sun/.codex/skills/.system")
        XCTAssertEqual(loc.displayName, String(localized: "System Skill"))
    }

    func testSkillLocation_isReadOnly() {
        XCTAssertTrue(SkillLocation.codexSystem(path: "/tmp/system").isReadOnly)
        XCTAssertTrue(SkillLocation.plugin(id: "p", name: "plugin", skillsURL: "/tmp").isReadOnly)
        XCTAssertFalse(SkillLocation.codexPersonal.isReadOnly)
        XCTAssertFalse(SkillLocation.codexProject(path: "/tmp/project").isReadOnly)
        XCTAssertFalse(SkillLocation.personal.isReadOnly)
    }

    // MARK: - SkillFile

    func testSkillFile_init() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let file = SkillFile(
            relativePath: "test.md",
            fileURL: url,
            fileSize: 100,
            isDirectory: false
        )
        XCTAssertEqual(file.relativePath, "test.md")
        XCTAssertEqual(file.fileSize, 100)
        XCTAssertFalse(file.isDirectory)
        XCTAssertNotNil(file.id)
    }

    func testSkillFile_identifiable() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let file1 = SkillFile(relativePath: "f", fileURL: url, fileSize: 0, isDirectory: false)
        let file2 = SkillFile(relativePath: "f", fileURL: url, fileSize: 0, isDirectory: false)
        // Each instance gets a unique UUID
        XCTAssertNotEqual(file1.id, file2.id)
    }

    // MARK: - Skill

    func testSkill_displayNameFromFrontmatter() {
        let fm = SkillFrontmatter(name: "my-skill")
        let skill = Skill(
            name: "directory-name",
            frontmatter: fm,
            markdownContent: "",
            location: .personal,
            directoryURL: URL(fileURLWithPath: "/tmp")
        )
        XCTAssertEqual(skill.displayName, "my-skill")
    }

    func testSkill_displayNameFallback() {
        let fm = SkillFrontmatter()
        let skill = Skill(
            name: "directory-name",
            frontmatter: fm,
            markdownContent: "",
            location: .personal,
            directoryURL: URL(fileURLWithPath: "/tmp")
        )
        XCTAssertEqual(skill.displayName, "directory-name")
    }

    func testSkill_skillFileURL_standard() {
        let dir = URL(fileURLWithPath: "/tmp/my-skill")
        let skill = Skill(
            name: "my-skill",
            frontmatter: .default,
            markdownContent: "",
            location: .personal,
            directoryURL: dir
        )
        XCTAssertEqual(skill.skillFileURL.lastPathComponent, "SKILL.md")
    }

    func testSkill_skillFileURL_legacy() {
        let dir = URL(fileURLWithPath: "/tmp/.claude/commands")
        let skill = Skill(
            name: "deploy",
            frontmatter: .default,
            markdownContent: "",
            location: .legacyCommand(path: dir.path),
            directoryURL: dir,
            isLegacyCommand: true
        )
        XCTAssertEqual(skill.skillFileURL.lastPathComponent, "deploy.md")
    }

    func testSkill_identifiable() {
        let s1 = Skill(name: "a", frontmatter: .default, markdownContent: "",
                       location: .personal, directoryURL: URL(fileURLWithPath: "/tmp"))
        let s2 = Skill(name: "a", frontmatter: .default, markdownContent: "",
                       location: .personal, directoryURL: URL(fileURLWithPath: "/tmp"))
        XCTAssertNotEqual(s1.id, s2.id)
    }

    func testSkill_hashable() {
        let dir = URL(fileURLWithPath: "/tmp")
        let s1 = Skill(id: UUID(), name: "a", frontmatter: .default, markdownContent: "",
                       location: .personal, directoryURL: dir)
        var set = Set<Skill>()
        set.insert(s1)
        set.insert(s1)
        XCTAssertEqual(set.count, 1)
    }
}
