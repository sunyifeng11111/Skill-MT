# Skill-MT

**Skill-MT** 是一个用于管理 Claude Code Skills 的 macOS 图形界面工具。

如果你在用 Claude Code，Skills 功能可以把常用的 AI 指令保存成文件随时调用。但管理这些文件一直要靠手动操作文件夹。Skill-MT 提供了一个简洁的 GUI，让你不用碰命令行就能管理所有技能。

![macOS](https://img.shields.io/badge/macOS-26.0+-000000?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-FA7343?logo=swift)

## 下载

[**下载最新版本 →**](https://github.com/sunyifeng11111/Skill-MT/releases/latest)

## 功能

- **创建 / 编辑 / 删除**技能，支持编辑 frontmatter 和 Markdown 内容
- **启用 / 禁用**技能（通过重命名文件实现，不删除数据）
- **导入**技能文件夹或 ZIP 压缩包，**导出**分享给他人
- 管理**个人技能**、**项目技能**、**旧版命令**和**插件技能**
- 实时**搜索**技能名称和描述
- 支持**中文 / 英文**界面

## 安装

1. [下载 Skill-MT.dmg](https://github.com/sunyifeng11111/Skill-MT/releases/latest)
2. 打开 DMG，将 Skill-MT 拖入 Applications 文件夹
3. 首次打开时 macOS 会提示"无法验证开发者"，**右键点击 app → 打开 → 打开**即可

## 从源码构建

需要 Xcode 16+ 和 macOS 26+。

```bash
git clone https://github.com/sunyifeng11111/Skill-MT.git
cd Skill-MT/Skill-MT
open Skill-MT.xcodeproj
```

在 Xcode 中按 `⌘R` 运行。

## Skills 是什么

Skills 是存储在 `~/.claude/skills/` 下的 Markdown 文件，带有 YAML frontmatter，作为 Claude Code CLI 的可复用指令。详见 [Claude Code 官方文档](https://docs.anthropic.com/en/docs/claude-code/skills)。

## License

MIT

---

# Skill-MT (English)

**Skill-MT** is a macOS GUI for managing Claude Code Skills.

If you use Claude Code, Skills let you save reusable AI instructions as local files. But managing those files has always meant digging around in the filesystem. Skill-MT gives you a clean interface to handle everything without touching the command line.

## Download

[**Download latest release →**](https://github.com/sunyifeng11111/Skill-MT/releases/latest)

## Features

- **Create / edit / delete** skills with frontmatter and Markdown content editing
- **Enable / disable** skills (renames the file, no data loss)
- **Import** skill folders or ZIP archives, **export** to share with others
- Manage **personal skills**, **project skills**, **legacy commands**, and **plugin skills**
- Real-time **search** across skill names and descriptions
- **Chinese / English** interface

## Installation

1. [Download Skill-MT.dmg](https://github.com/sunyifeng11111/Skill-MT/releases/latest)
2. Open the DMG and drag Skill-MT into your Applications folder
3. On first launch macOS will warn "unverified developer" — **right-click the app → Open → Open** to bypass Gatekeeper

## Build from Source

Requires Xcode 16+ and macOS 26+.

```bash
git clone https://github.com/sunyifeng11111/Skill-MT.git
cd Skill-MT/Skill-MT
open Skill-MT.xcodeproj
```

Press `⌘R` in Xcode to run.

## What are Skills?

Skills are Markdown files with YAML frontmatter stored under `~/.claude/skills/`, used as reusable instructions for the Claude Code CLI. See the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code/skills) for details.
