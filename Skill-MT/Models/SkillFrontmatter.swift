import Foundation

struct SkillFrontmatter: Hashable {
    var name: String?
    var description: String?
    var argumentHint: String?
    var disableModelInvocation: Bool
    var userInvocable: Bool
    var allowedTools: String?
    var model: String?
    var context: String?
    var agent: String?
    /// Raw YAML string for the `hooks` field; not deeply parsed in Phase 1.
    var hooksRaw: String?

    init(
        name: String? = nil,
        description: String? = nil,
        argumentHint: String? = nil,
        disableModelInvocation: Bool = false,
        userInvocable: Bool = true,
        allowedTools: String? = nil,
        model: String? = nil,
        context: String? = nil,
        agent: String? = nil,
        hooksRaw: String? = nil
    ) {
        self.name = name
        self.description = description
        self.argumentHint = argumentHint
        self.disableModelInvocation = disableModelInvocation
        self.userInvocable = userInvocable
        self.allowedTools = allowedTools
        self.model = model
        self.context = context
        self.agent = agent
        self.hooksRaw = hooksRaw
    }

    static let `default` = SkillFrontmatter()
}
