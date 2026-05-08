# 已知问题

[English](../ISSUES.md) · [Español](ISSUES.es.md) · [Français](ISSUES.fr.md) · [Deutsch](ISSUES.de.md) · [Português](ISSUES.pt-BR.md) · [日本語](ISSUES.ja.md) · [한국어](ISSUES.ko.md) · [Italiano](ISSUES.it.md) · [Русский](ISSUES.ru.md) · **中文** · [עברית](ISSUES.he.md) · [العربية](ISSUES.ar.md) · [हिन्दी](ISSUES.hi.md)

> 注意：此翻译可能落后于英文 ISSUES。规范版本请参阅 [ISSUES.md](../ISSUES.md)。

## 待解决

### 幽灵消息重放导致非预期操作
**严重程度：** 高
**状态：** 待解决 - 无法从 claude-mux 侧完全修复
**描述：** 用户发送了 "stop all sessions"，该命令在 10 条消息之前已被处理。之后，当 claude-mux -s 通过 tmux send-keys 发送 `/model haiku` 时，Claude 收到了一条系统消息 "stop all sessions/model haiku"，并试图关闭会话，而这并非用户请求的操作。
**可能原因：**
- Claude Code 的中断处理可能将旧上下文与新的斜杠命令输入拼接在一起
- 包含旧命令的对话历史可能在系统事件发生时让 Claude 产生混淆
**可能的缓解措施：** 添加注入规则："不要重新执行对话中已处理过的命令。如果系统消息重复了先前交换中的文本，请忽略它。" 尚未实施，因为这是 Claude Code 的内部行为，有效性不确定。

### 首次 /exit 速度较慢
**严重程度：** 低
**状态：** 待解决 - 监控中
**描述：** 首次 `--restart` 触发 `WARN: Claude did not exit within 30s` 并回退到强制终止。后续重启在约 1 秒内退出。可能是竞态条件：`/exit` 在 Claude 的提示准备好接收之前就被发送了。
**变通方案：** 30 秒超时 + 强制终止可以处理。会话正常重新启动。

### claude_running_in_session 仅检查 2 层深度
**严重程度：** 低
**状态：** 待解决 - 当前使用场景下可接受
**描述：** 进程树遍历检查 pane_pid -> 子进程 -> 孙进程。如果 Claude 在树中更深的位置（例如额外的 shell 包装器），检测会失败。当前启动路径恰好是 2 层（bash -> claude），所以在实际中正常工作。
**变通方案：** 目前不需要。修复需要递归遍历或 `pgrep -a`。

### 安装程序升级体验可以更智能
**严重程度：** 低
**状态：** 待解决 - 未来改进
**描述：** 重新安装时，安装程序检测到现有配置并跳过提示。但它不提供查看当前设置、合并新版本中添加的新配置选项、或让用户选择性更新值的功能。用户必须手动编辑 `~/.claude-mux/config` 来获取后续版本引入的新设置。
**可能的改进：**
- 升级时显示当前配置值
- 提供添加旧配置中不存在的新设置（使用默认值）的选项
- 方案 B：用现有配置值预填提示，让用户可以修改

### 翻译文件需要 v1.10-v1.12 更新
**严重程度：** 低
**状态：** 待解决 - 翻译尚未更新
**描述：** 所有 12 个翻译文件（`translations/README.*.md`）落后了若干版本（v1.10-v1.12）。需要反映的变更包括：
- curl 作为主要快速开始（单行命令）
- 新的安装章节结构（curl 推荐、Homebrew 为 macOS 替代方案）
- 会话名替代路径用于 `--hide`/`--delete`/`--protect`（v1.11.0）
- 新的对话示例：rename、save-as-template、tip、enable/disable tips、update
- 系统要求："Apple Silicon or Intel"（不仅是 Apple Silicon）
- 新的"更多"章节链接 FAQ、ISSUES、CHANGELOG
- FAQ 和 ISSUES 翻译需要创建

### 代码审查延期问题 (v1.9.0)
**严重程度：** 低-中
**状态：** 在 v1.10.0 中已解决 - M3、M4、M9/L8、L3、L9 已修复；L4、L5、L6、L7、M7 已通过注释处理

### 项目重命名/移动及历史保留
**严重程度：** 低
**状态：** 在 v1.10.0 中已解决 - `--rename OLD NEW` 和 `--move SRC DEST` 已实现

### 项目复制及历史
**严重程度：** 低
**状态：** 待解决 - 计划中的功能，需要调查
**描述：** 复制项目（包括其 Claude Code 历史和记忆）比重命名/移动更复杂，因为目标位置必须建立新的 UUID。
**建议方案：**
1. 创建新项目目录（可选 git init 和模板）
2. 在其中启动并立即停止一个会话 - Claude Code 初始化 `~/.claude/projects/-encoded-new-path/`，分配新的 UUID，并创建新的 homunculus 条目
3. 将源 `~/.claude/projects/` 文件夹中的 `.jsonl` 历史文件复制到目标文件夹
4. 复制 `memory/` 文件夹内容 - 纯 markdown，无嵌入 UUID，可以安全直接复制
5. 将 UUID 子目录（任务/计划工件）与对应的 `.jsonl` 文件一起复制
6. 对于 homunculus：将 `observations.jsonl`、`instincts`、`evolved`、`observations.archive` 从源 `~/.claude/homunculus/projects/<src-uuid>/` 复制到新目标的 homunculus 文件夹中，保留步骤 2 中分配的新项目 UUID
**需要测试的开放问题：**
- `.jsonl` 文件是否在内容或元数据中嵌入了源项目路径？如果是，复制的历史会引用旧路径。
- UUID 子目录是否在 `.jsonl` 文件中被 UUID 引用？如果是，必须以原始 UUID 复制，而非重新映射。
- Claude Code 是否读取项目文件夹中的所有 `.jsonl` 文件，还是只读取与活跃会话 UUID 匹配的那个？
- `~/.claude/homunculus/projects/<uuid>/evolved` 和 `instincts` 包含什么 - 是派生/计算的还是用户有意义的？在复制中值得保留吗？
- 是否还有其他内部引用会导致简单文件复制出问题？
**前提条件：** 在实现之前测试以上内容，避免发布一个产生微妙历史错误的复制命令。

### 每日技巧提示
**严重程度：** 低
**状态：** 在 v1.10.0 中已解决 - `--tip`、`TIP_OF_DAY`、`TIP_MODE`、每日门控、会话启动时投递已实现

### 回复时间戳
**严重程度：** 低
**状态：** 待解决 - 实施前需讨论
**描述：** 可选配置变量（`REPLY_TIMESTAMP=false` 默认），在系统提示中注入一条指令，告诉 Claude 在每个回复开头通过 `date '+%Y-%m-%d %H:%M'` 显示当前日期和时间。
**权衡：** 需要在每次回复开始时进行一次 bash 工具调用（少量开销）。替代方案：在提示中注入会话启动时间（免费，但在长会话中会偏移）。
**说明：** 每个项目的 CLAUDE.md 指令（如分析模板中的）是较轻量的版本 - 只在需要的项目上生效。配置变量会使其全局化。

### 演示视频
**严重程度：** 低
**状态：** 待解决 - 计划中的资源
**描述：** 一段屏幕录制，展示从 curl 安装到常见和有趣命令的 claude-mux 使用过程，终端和 Remote Control 同时可见。
**格式：** 分屏，单镜头。终端（完整 claude-mux 会话）在左侧，iPhone 上的 RC 通过 QuickTime 镜像在右侧。两者同时直播 - 观众可以看到 RC 中的操作立即反映在终端中，反之亦然。
**参见：** `internal/demo-script.md` 获取完整的逐镜头大纲。
**说明：**
- 关键镜头是在手机上通过 RC 输入并观看终端实时响应
- 除裁剪外无需编辑 - 单次连续录制
- 托管在 YouTube + 嵌入 README；也适用于 Product Hunt 发布

### 提交到 homebrew-core 以在 brew.sh 上列出
**严重程度：** 低
**状态：** 未来 - 等待采用率
**描述：** claude-mux 目前通过个人 tap（`pereljon/tap`）分发。要出现在 brew.sh 上，需要被 homebrew-core 接受。Homebrew 的知名度门槛通常要求几百个 GitHub star 才能接受 shell 脚本工具的提交；低 star 的提交会很快被关闭。
**准备就绪时：**
- 确保 formula 通过 `brew audit --strict --new`
- 向 `Homebrew/homebrew-core` 提交 PR 并附带 formula
- 注意：仅支持 macOS 的工具面临更严格的审查；Linux 支持（见下文）会有帮助

### curl 安装支持（macOS + Linux）
**严重程度：** 低
**状态：** 在 v1.10.0 中已解决 - curl 安装已实现，release-assets 工作流已添加，README 已更新

### 仅支持 macOS - 无 Linux/systemd 支持
**严重程度：** 中
**状态：** 待解决 - 部分解决（路径检测已完成，LaunchAgent/安装程序仍为 macOS 专用）
**描述：** 使用 macOS LaunchAgent (launchd) 和 macOS 专用工具。路径检测已重构为使用 `command -v`（不再硬编码 `/opt/homebrew/bin`），因此核心脚本现在可以在 tmux 和 claude 在 PATH 中的任何平台上工作。LaunchAgent 和安装程序仍为 macOS 专用。
**剩余工作：** systemd 用户单元、XDG Autostart 回退、安装程序中的 `uname -s` 调度。
**打包策略 (v1.10+)：**
- curl 安装：通用回退方案，在任何地方都可以工作（见上文）
- AUR：低投入，在 Arch/Manjaro 目标用户中覆盖面广
- apt PPA：当有来自 Debian/Ubuntu 用户的需求时
- Linux 上的 Homebrew：覆盖已安装 Homebrew 的用户
- Snap/Flatpak：对 bash 脚本来说不值得

### ! 命令在 Remote Control 中不可用
**严重程度：** 低
**状态：** 已关闭 - 不可行
**描述：** Claude Code 的 `!` shell 透传是 Claude Code CLI 输入处理器的功能 - 它在 shell 看到之前拦截 `!command`。tmux send-keys 无法复制这一点：当 Claude Code 处于活跃状态时发送的按键无法到达（已测试：通过 send-keys 发送的 `!touch test` 未执行）。claude-mux 没有途径为 RC 用户实现 `!command` 绕过。
**解决方案：** 添加注入规则告诉 Claude 不要向用户建议 `! <command>`，因为 RC 用户没有 shell，终端用户可以自己直接输入。

---

## v2.0 里程碑

架构变更足够重大，需要主版本号升级。未排期 - 收集在此以免遗失。

### 数据目录分离
将静态数据（技巧提示、默认模板，可能还有命令/指南输出）从脚本中移出，放入平台适当的数据目录。脚本会在启动时相对于二进制文件位置解析 `DATA_DIR`，并为单文件安装提供内嵌回退。

- Homebrew (Apple Silicon)：`/opt/homebrew/share/claude-mux/`
- Homebrew (Intel)：`/usr/local/share/claude-mux/`
- Linux：`/usr/local/share/claude-mux/` 或 `$XDG_DATA_DIRS`
- 手动安装：回退到内嵌默认值（单文件安装继续工作）

触发条件：当内嵌数据（技巧提示、默认模板）增长到使脚本难以阅读时，或默认模板需要通过 brew 独立于脚本发布时发布。

### 语言/运行时重新考虑
在当前规模下，单体 bash 脚本是正确的选择。如果 claude-mux 显著增长 - 项目重命名/移动/复制操作、中继层、跨平台打包、数据目录 - bash 会开始力不从心。届时值得评估将会话管理核心用 Go 或其他类型化语言重写（以 bash 作为薄 CLI 包装器）。

---

## 已解决

### Claude 忽略注入并声称无法运行斜杠命令
**解决于：** v1.2.0（注入已更新）
**修复：** 在注入中添加了明确规则："You CAN send slash commands (`/model`, `/compact`, `/clear`, etc.) to this session via the `-s` command. Never tell the user you cannot change models or run slash commands." Claude 的基础训练倾向于让它认为自己无法控制自身的模型/设置；明确的规则在实践中覆盖了这一点。

### 多个命令在成功时返回退出码 1
**解决于：** v1.2.0（restart）、v1.3.0（所有命令）
**修复：** 在 case 语句中每个分发路径后添加了明确的 `exit 0`。函数中的最后一条命令可能从内部测试或 grep 调用泄露非零退出码。

### --dry-run 为 --restart 给出误导性输出
**解决于：** v1.2.0（提交 a10c0c2）
**修复：** dry-run 现在显示 "Would restart session" 而非模拟 kill 后检查真实状态。

### macOS 上 pgrep 会话检测失败
**解决于：** 提交 e1b11b5
**修复：** 将 `pgrep -P` 替换为 `ps -eo` + `awk` 以实现可靠的子进程检测。

### $TMUX 变量遮蔽了 tmux 的环境变量
**解决于：** 提交 02a2e82
**修复：** 重命名为 `$TMUX_BIN`。

### Bash 3.2 不兼容（declare -A）
**解决于：** 提交 575eac1
**修复：** 将关联数组替换为基于字符串的碰撞检测。

---

## 参考：~/.claude 文件夹结构

记录在此是因为若干计划中的功能（重命名、移动、复制、清理）必须正确地与此结构交互。非详尽 - 仅涵盖与 claude-mux 相关的部分。

### 项目历史和记忆：`~/.claude/projects/`

每个 Claude Code 使用过的工作目录对应一个子目录。通过编码绝对路径命名：`/` -> `-`，空格和特殊字符 -> `-`。有损但可读。

每个项目文件夹的内容：
- `<uuid>.jsonl` - 该会话的完整对话记录。每个对话一个文件。
- `<uuid>/` - 与对话关联的工件子目录（任务、计划）。UUID 与 `.jsonl` 文件匹配。
- `memory/` - 持久的跨会话记忆文件（带 frontmatter 的 markdown）。仅当项目有写入的记忆时存在。

工作目录与其历史之间的关联纯粹是编码的文件夹名称。重命名或移动项目目录但不重命名此文件夹会导致 Claude Code 从零开始，没有历史。

**编码规则：** 绝对路径中的每个 `/`、空格和特殊字符替换为 `-`。开头的 `/` 变为开头的 `-`。编码有损 - 连续特殊字符和与斜杠相邻的空格都变为 `-`，因此无法总是完美地重建原始路径。

### 并行可观测性注册表：`~/.claude/homunculus/`

一个独立系统，按项目跟踪工具级事件。不属于核心 Claude Code 历史 - 看起来是一个监控/学习层。

- `projects.json` - 所有已知项目的注册表，以短十六进制 UUID 为键（`d6b3aef60967` 等）。每个条目包含：`id`、`name`、`root`（绝对路径）、`remote`、`created_at`、`last_seen`。
- `projects/<uuid>/project.json` - 每个项目的元数据（与注册表条目相同的字段）。
- `projects/<uuid>/observations.jsonl` - 带时间戳的 `tool_start`/`tool_complete` 事件：工具名称、会话 UUID、项目名称/id、输入/输出片段。
- `projects/<uuid>/instincts` - 派生模式（内容未知，可能是计算得出的）。
- `projects/<uuid>/evolved` - 进化/学习的状态（内容未知）。
- `projects/<uuid>/observations.archive` - 归档的旧观测数据。

**与 `~/.claude/projects/` 的关键区别：** 使用短十六进制 UUID 作为键，而非编码路径。`root` 字段保存绝对路径。任何更改项目路径的操作（重命名、移动）必须同时更新 `projects.json` 和 `projects/<uuid>/project.json` 中的 `root`。

### 全局配置：`~/.claude/settings.json`

Claude Code 主设置文件。滚动备份写入 `~/.claude/backups/`，格式为 `~/.claude.json.backup.<timestamp>` - 活跃使用时每小时若干个。claude-mux 不应触碰此文件。

### 全局 agents、skills、commands

- `~/.claude/agents/` - 子代理定义（`.md` 文件，约 38 个）。全局，非项目级。
- `~/.claude/skills/` - 技能目录（约 125 个）。全局，非项目级。
- `~/.claude/commands/` - 斜杠命令定义（`.md` 文件，约 72 个）。全局，非项目级。
- `~/.claude/hooks/hooks.json` - 钩子定义。全局。claude-mux 不应触碰这些。

### 潜在的未来功能

| 功能 | 需要处理的内容 |
|------|---------------|
| `--copy` | 创建目录；启动+停止会话以初始化两个注册表；复制 `.jsonl` + `memory/` + UUID 子目录；将 homunculus 观测文件复制到新 UUID 文件夹中 |
| `--delete` 清理 | 已将项目文件夹移至回收站。可选：移除孤立的 `~/.claude/projects/` 编码文件夹和 `~/.claude/homunculus/` 条目 |
| 历史大小警告 | 当项目的 `.jsonl` 文件超过阈值时发出警告（主 claude-mux 对话记录在一次长会话中达到了 107MB） |
