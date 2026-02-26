## Skill-MT v1.2.3

本次更新聚焦于应用内更新安装阶段的“占用中”问题收敛。

## Added
- 更新安装流程新增强制退出兜底逻辑，降低应用残留进程导致安装失败的概率。

## Improved
- 优化应用内更新时序：先尝试正常退出，再在必要时自动执行强制退出。
- 继续保留“已打开安装包”的明确状态提示，安装路径更可预期。

## Fixed
- 修复部分环境下更新时仍提示“项目正在使用中，无法完成操作”的问题。

## Download
- `Skill-MT-arm64-v1.2.3.dmg` (Apple Silicon)

## SHA256
- `Skill-MT-arm64-v1.2.3.dmg`: `13e282d15ebf4edbee184a38d6ada0df5426c5fbea2eff57ab6acfc087b03e5d`
