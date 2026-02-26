import XCTest
@testable import Skill_MT

final class SkillParserTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) -> String {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: nil,
                                   subdirectory: nil) else {
            XCTFail("Fixture not found: \(name)")
            return ""
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    // MARK: - splitContent

    func testSplitContent_validFrontmatter() {
        let content = "---\nname: test\n---\n\n# Body"
        let (yaml, markdown) = SkillParser.splitContent(content)
        XCTAssertEqual(yaml, "name: test\n")
        XCTAssertEqual(markdown, "# Body")
    }

    func testSplitContent_noFrontmatter() {
        let content = "# Just Markdown\n\nNo delimiters."
        let (yaml, markdown) = SkillParser.splitContent(content)
        XCTAssertNil(yaml)
        XCTAssertEqual(markdown, content)
    }

    func testSplitContent_emptyFrontmatter() {
        let content = "---\n---\n\n# Body"
        let (yaml, markdown) = SkillParser.splitContent(content)
        XCTAssertNotNil(yaml)
        XCTAssertTrue(yaml!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertEqual(markdown, "# Body")
    }

    func testSplitContent_frontmatterOnly() {
        let content = "---\nname: test\n---\n"
        let (yaml, markdown) = SkillParser.splitContent(content)
        XCTAssertEqual(yaml, "name: test\n")
        XCTAssertTrue(markdown.isEmpty)
    }

    func testSplitContent_windowsLineEndings() {
        let content = "---\r\nname: test\r\n---\r\n\r\n# Body"
        let (yaml, markdown) = SkillParser.splitContent(content)
        XCTAssertEqual(yaml, "name: test\n")
        XCTAssertEqual(markdown, "# Body")
    }

    func testSplitContent_tripleHyphensInBody() {
        let content = "---\nname: test\n---\n\n# Body\n\n---\n\nMore content"
        let (yaml, markdown) = SkillParser.splitContent(content)
        XCTAssertEqual(yaml, "name: test\n")
        XCTAssertTrue(markdown.contains("---"))
        XCTAssertTrue(markdown.contains("More content"))
    }

    func testSplitContent_fixtureValidSkill() {
        let content = loadFixture("valid-skill.md")
        let (yaml, markdown) = SkillParser.splitContent(content)
        XCTAssertNotNil(yaml)
        XCTAssertTrue(yaml!.contains("name: review-code"))
        XCTAssertTrue(markdown.contains("# Code Review"))
    }

    func testSplitContent_fixtureNoFrontmatter() {
        let content = loadFixture("no-frontmatter.md")
        let (yaml, _) = SkillParser.splitContent(content)
        XCTAssertNil(yaml)
    }

    // MARK: - parseFrontmatter

    func testParseFrontmatter_nameField() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "name: my-skill\n")
        XCTAssertEqual(fm.name, "my-skill")
    }

    func testParseFrontmatter_descriptionField() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "description: Does something\n")
        XCTAssertEqual(fm.description, "Does something")
    }

    func testParseFrontmatter_descriptionNumericValueCoercesToString() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "description: 2026\n")
        XCTAssertEqual(fm.description, "2026")
    }

    func testParseFrontmatter_descriptionBooleanValueCoercesToString() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "description: true\n")
        XCTAssertEqual(fm.description, "true")
    }

    func testParseFrontmatter_argumentHint() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "argument-hint: \"[file]\"\n")
        XCTAssertEqual(fm.argumentHint, "[file]")
    }

    func testParseFrontmatter_disableModelInvocationTrue() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "disable-model-invocation: true\n")
        XCTAssertTrue(fm.disableModelInvocation)
    }

    func testParseFrontmatter_disableModelInvocationDefault() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "name: test\n")
        XCTAssertFalse(fm.disableModelInvocation)
    }

    func testParseFrontmatter_userInvocableFalse() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "user-invocable: false\n")
        XCTAssertFalse(fm.userInvocable)
    }

    func testParseFrontmatter_userInvocableDefault() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "name: test\n")
        XCTAssertTrue(fm.userInvocable)
    }

    func testParseFrontmatter_allowedTools() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "allowed-tools: \"Read, Grep\"\n")
        XCTAssertEqual(fm.allowedTools, "Read, Grep")
    }

    func testParseFrontmatter_model() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "model: claude-opus-4-6\n")
        XCTAssertEqual(fm.model, "claude-opus-4-6")
    }

    func testParseFrontmatter_context() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "context: fork\n")
        XCTAssertEqual(fm.context, "fork")
    }

    func testParseFrontmatter_agent() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "agent: Explore\n")
        XCTAssertEqual(fm.agent, "Explore")
    }

    func testParseFrontmatter_hooksRaw() throws {
        let content = loadFixture("hooks-frontmatter.md")
        let (yaml, _) = SkillParser.splitContent(content)
        let fm = try SkillParser.parseFrontmatter(yaml: yaml!)
        XCTAssertNotNil(fm.hooksRaw)
        XCTAssertTrue(fm.hooksRaw!.contains("PreToolUse"))
    }

    func testParseFrontmatter_allFields() throws {
        let content = loadFixture("full-frontmatter.md")
        let (yaml, _) = SkillParser.splitContent(content)
        let fm = try SkillParser.parseFrontmatter(yaml: yaml!)
        XCTAssertEqual(fm.name, "full-example")
        XCTAssertNotNil(fm.description)
        XCTAssertEqual(fm.argumentHint, "[arg1] [arg2]")
        XCTAssertTrue(fm.disableModelInvocation)
        XCTAssertFalse(fm.userInvocable)
        XCTAssertEqual(fm.model, "claude-opus-4-6")
        XCTAssertEqual(fm.context, "fork")
        XCTAssertEqual(fm.agent, "Explore")
    }

    func testParseFrontmatter_emptyYAML() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "")
        XCTAssertNil(fm.name)
        XCTAssertFalse(fm.disableModelInvocation)
        XCTAssertTrue(fm.userInvocable)
    }

    func testParseFrontmatter_unknownFieldsIgnored() throws {
        let fm = try SkillParser.parseFrontmatter(yaml: "name: test\nunknown-field: value\n")
        XCTAssertEqual(fm.name, "test")
    }

    func testParseFrontmatter_invalidYAML() {
        XCTAssertThrowsError(
            try SkillParser.parseFrontmatter(yaml: "name: [invalid\n")
        ) { error in
            XCTAssertTrue(error is SkillParserError)
        }
    }

    // MARK: - parse (integration)

    func testParse_validSkillFile() throws {
        let content = loadFixture("valid-skill.md")
        let (fm, markdown) = try SkillParser.parse(content: content)
        XCTAssertEqual(fm.name, "review-code")
        XCTAssertTrue(markdown.contains("# Code Review"))
        XCTAssertTrue(markdown.contains("$ARGUMENTS"))
    }

    func testParse_noFrontmatter() throws {
        let content = loadFixture("no-frontmatter.md")
        let (fm, markdown) = try SkillParser.parse(content: content)
        XCTAssertNil(fm.name)
        XCTAssertFalse(fm.disableModelInvocation)
        XCTAssertTrue(fm.userInvocable)
        XCTAssertFalse(markdown.isEmpty)
    }

    func testParse_emptyFrontmatter() throws {
        let content = loadFixture("empty-frontmatter.md")
        let (fm, markdown) = try SkillParser.parse(content: content)
        XCTAssertNil(fm.name)
        XCTAssertTrue(markdown.contains("# Empty Frontmatter"))
    }

    func testParse_legacyCommand() throws {
        let content = loadFixture("legacy-command.md")
        let (fm, markdown) = try SkillParser.parse(content: content)
        XCTAssertEqual(fm.description, "Review PR changes")
        XCTAssertFalse(markdown.isEmpty)
    }

    func testParse_withHooks() throws {
        let content = loadFixture("hooks-frontmatter.md")
        let (fm, markdown) = try SkillParser.parse(content: content)
        XCTAssertEqual(fm.name, "hooked-skill")
        XCTAssertNotNil(fm.hooksRaw)
        XCTAssertTrue(markdown.contains("# Hooked Skill"))
    }
}
