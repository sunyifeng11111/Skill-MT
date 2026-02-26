# Skill-MT

<img src="docs/logo.png" width="128" />

**Skill-MT** 是一个用于管理 Claude Code / Codex Skills 的 macOS 图形界面工具。

如果你在用 Claude Code，Skills 功能可以把常用的 AI 指令保存成文件随时调用。但管理这些文件一直要靠手动操作文件夹。Skill-MT 提供了一个简洁的 GUI，让你不用碰命令行就能管理所有技能。

![macOS](https://img.shields.io/badge/macOS-26.0+-000000?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-FA7343?logo=swift)
![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-only-000000?logo=apple)

**中文** | [English](README_EN.md)

## 下载

[**下载最新版本 →**](https://github.com/sunyifeng11111/Skill-MT/releases/latest)
当前稳定版：`v1.2.5`（2026-02-27）

## 功能

- **创建 / 编辑 / 删除**技能，支持编辑 frontmatter 和 Markdown 内容
- **启用 / 禁用**技能（通过重命名文件实现，不删除数据）
- **导入**技能文件夹或 ZIP 压缩包，**导出**分享给他人
- 管理 Claude 的**个人技能**、**项目技能**、**旧版命令**和**插件技能**
- 管理 Codex 的**个人技能**与**系统技能**（系统技能只读）
- 实时**搜索**技能名称和描述
- 支持**中文 / 英文**界面

## 安装

1. [下载 Skill-MT-arm64.dmg](https://github.com/sunyifeng11111/Skill-MT/releases/latest)
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

Skills 是带有 YAML frontmatter 的 Markdown 指令文件：
- Claude: `~/.claude/skills/`
- Codex: `~/.codex/skills/`（系统技能位于 `~/.codex/skills/.system/`）

## 截图

**主页面**
![主页面](docs/主页面.png)

**新建技能**
![新建技能](docs/新建技能.png)

**编辑技能**
![编辑技能](docs/编辑技能.png)

**全局技能**
![全局技能](docs/全局技能.png)

**插件技能**
![插件技能](docs/插件技能.png)

## License

MIT
