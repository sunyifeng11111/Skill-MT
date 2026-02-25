# Skill-MT

**Skill-MT** is a macOS GUI tool for managing Claude Code Skills.

If you use Claude Code, the Skills feature lets you save common AI instructions as files and invoke them anytime. But managing those files has always required manual folder operations. Skill-MT provides a clean GUI so you can manage all your skills without touching the command line.

![macOS](https://img.shields.io/badge/macOS-26.0+-000000?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-FA7343?logo=swift)
![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-only-000000?logo=apple)

[中文](README.md)

## Download

[**Download Latest Release →**](https://github.com/sunyifeng11111/Skill-MT/releases/latest)

## Features

- **Create / Edit / Delete** skills with frontmatter and Markdown content editing
- **Enable / Disable** skills (via file renaming — no data is lost)
- **Import** skill folders or ZIP archives, **export** to share with others
- Manage **personal skills**, **project skills**, **legacy commands**, and **plugin skills**
- Real-time **search** by skill name and description
- Supports **Chinese / English** UI

## Installation

1. [Download Skill-MT.dmg](https://github.com/sunyifeng11111/Skill-MT/releases/latest)
2. Open the DMG and drag Skill-MT into your Applications folder
3. On first launch, macOS may warn "cannot verify developer" — **right-click the app → Open → Open**

## Build from Source

Requires Xcode 16+ and macOS 26+.

```bash
git clone https://github.com/sunyifeng11111/Skill-MT.git
cd Skill-MT/Skill-MT
open Skill-MT.xcodeproj
```

Press `⌘R` in Xcode to run.

## What are Skills?

Skills are Markdown files with YAML frontmatter stored under `~/.claude/skills/`, used as reusable instructions for the Claude Code CLI. See the [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code/skills) for details.

## License

MIT
