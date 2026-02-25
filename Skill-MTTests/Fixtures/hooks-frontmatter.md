---
name: hooked-skill
description: A skill with hooks configuration
hooks:
  PreToolUse:
    - matcher: "Write"
      hooks:
        - type: prompt
          prompt: "Validate write operation"
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: "Verify completion"
---

# Hooked Skill

This skill has lifecycle hooks.
