# claude-mux - Claude Code 多路复用器

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · **中文** · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

为你所有项目提供持久的 Claude Code 会话 - 通过 Claude 移动应用随时随地访问。***由 Claude 管理！***

## 安装

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

然后启动一个会话：

```bash
claude-mux ~/path/to/your/project
```

安装程序会询问你是否想在登录时启动一个 home 会话。如果接受，每次登录时都会自动启动一个受保护的 Claude 会话 - 即使你从未打开终端，也能随时通过手机或任何 Remote Control 客户端访问。

就这样！你已经进入了一个持久的、感知会话的 Claude 会话，且已启用 Remote Control。**从这里开始，一切都是对话式的。**

[Homebrew、手动安装及其他选项](../docs/INSTALL.md)

## 为什么

Remote Control 承诺可以在任何地方使用 Claude Code - 但如果没有会话管理，即使从 Claude Desktop 使用，它也只是一个二等接口：

- **会话会消亡** - 关闭终端后会话就没了
- **对话上下文** 不会自动恢复
- **没有大本营** - 除非你特意留着什么不关，否则拿起手机时什么都没在运行
- **Remote Control 需要运行中的会话** - 你无法从 RC 启动一个会话
- **Slash 命令在 RC 会话中不可用** - 无法切换模型、压缩上下文或更改权限模式
- **启动新项目** - 需要手动创建目录、初始化 git、编写指令文件 (AGENTS.md 或 CLAUDE.md)、选择模型
- **没有项目管理** - 无法查看空闲项目，也无法在不破坏历史记录的情况下重命名、移动和删除项目

**claude-mux 填补了会话管理的空白。** 它将 Claude Code 包装在 tmux 中使会话持久化，在崩溃和重启后自动恢复会话 (前提是已启用自动登录)，注入系统提示词使 Claude 能够管理自己的会话，并通过 tmux 路由 slash 命令使其在 Remote Control 上也能工作。一旦会话运行起来，你只需与 Claude 对话就能管理一切 - 无论是在终端还是移动应用中。

## 在 claude-mux 会话中你能做什么

- **崩溃和重启后依然存活** - 重新登录时会话自动恢复，接续上一次对话。正常的 `/exit` 或关机会让会话保持停止；反复崩溃的会话会被停止并标记，而不是无限重启
- **从任何会话管理任何会话** - 使用自然语言启动、停止、重启、列出和压缩项目
- **随时随地访问一切** - 每个会话都启用了 Remote Control，Claude 移动应用、桌面应用或任何远程客户端都是完整的操作界面
- **切换模型和权限模式** - 说"切换到 Haiku"或"切换到 plan 模式"，Claude 会处理，即使通过 Remote Control 也可以
- **创建新项目** - "创建一个叫 my-app 的新项目"会设置目录、git、基于模板的 AGENTS.md，并启动一个会话。模板让你可以跨项目复用指令。
- **通过 Remote Control 发送 slash 命令** - Claude 将 `/model`、`/compact`、`/clear` 及其他 slash 命令路由到运行中的会话，绕过一个[已知限制](https://github.com/anthropics/claude-code/issues/30674)。RC 会通过 `PreCompact` 钩子在 `/compact` 后自动重新连接。
- **Claude Code 升级检测** - 当 `claude` 二进制文件发生变化时 (`brew upgrade` 或 npm 更新后)，运行中的会话会提示重启以加载新的二进制文件；该提示会在每次提示词中持续出现，直到你重启，因此错过一轮也不会丢失
- **保留对话历史** - 重命名、移动和重启项目都会自动保留对话历史
- **组织项目** - 从任何会话内部隐藏、重命名、移动、删除和保护项目
- **GitHub 多账号支持** - 检测 `~/.ssh/config` 中的 SSH 别名并注入到会话中，使 Claude 能为每个项目使用正确的账号
- **以 AGENTS.md 作为项目指令文件** - `AGENTS.md` 是唯一的实际文件，Claude Code 和 Codex CLI 都会读取。说"migrate to AGENTS.md"可将现有目录树从 `CLAUDE.md` 转换过来 (先出报告，不提交任何内容)。需要 Claude Code 2.1.277 或更高版本；更旧的版本继续使用 `CLAUDE.md`。仅当 `~/.gemini/settings.json` 包含 `"context": {"fileName": ["AGENTS.md"]}` 时，Gemini CLI 才会读取它。
- **支持任何语言** - 对话命令通过意图推断，而非关键词匹配

## 与 Claude 对话

这是你日常使用 claude-mux 的方式。每个会话都被注入了命令，使 Claude 能够管理会话、切换模型、发送 slash 命令和创建新项目 - 全部在对话中完成。你不需要记住 CLI 参数。

```
说: "status"
报告会话名称、模型、权限模式、上下文使用情况，并列出所有会话

说: "列出活跃会话"
显示所有运行中的会话及其状态

说: "列出空闲会话"
仅显示空闲项目

说: "列出已停止的会话"
仅显示已停止的会话

说: "为我的 api-server 项目启动一个会话"
按名称启动会话；如果已在运行则不做任何事

说: "用 web 模板创建一个叫 mobile-app 的新项目"
创建项目目录、初始化 git、应用模板、启动会话

说: "把这个会话切换到 Haiku"
将模型家族解析为最新的具体 ID，并向自己发送 /model claude-haiku-4-5

说: "压缩 api-server 会话"
向 api-server 会话发送 /compact

说: "重启 web-dashboard 会话"
关闭并重新启动会话，保留对话上下文

说: "全新重启这个会话"
请求确认，然后以新对话重启 - 不恢复，没有之前的上下文

说: "kill api-server 会话"
请求确认，然后清除对话并停止会话；下次启动是新对话，而不是恢复

说: "结束这个会话"
先保存未完成的工作和下一步，请求确认 (并询问是否有未保存的内容)，然后全新重启

说: "把 api-server 会话切换到 plan 模式"
以 plan 权限模式重启会话

说: "把这个会话切换到 yolo 模式"
通过 Shift+Tab 切换到 bypassPermissions 模式 - 无需重启

说: "这个会话是什么模式"
报告当前权限模式 (default, acceptEdits, plan, bypassPermissions)

说: "把这个会话切换到 Opus"
将模型家族解析为最新的具体 ID，并向自己发送 /model claude-opus-4-8

说: "清除这个会话"
请求确认，然后向自己发送 /clear，重置对话

说: "隐藏这个项目"
写入 .claudemux-ignore，使项目从 -L 列表中排除

说: "保护这个会话"
写入 .claudemux-protected 并设置 tmux 标记 - 关闭现在需要 --force

说: "这个会话受保护吗"
检查项目文件夹中是否存在 .claudemux-protected 并报告

说: "删除 old-prototype 项目"
在聊天中确认，然后将项目文件夹移至系统回收站

说: "把这个项目重命名为 my-new-name"
停止会话、重命名文件夹、迁移对话历史、重启

说: "把这个保存为名为 web 的模板"
将 AGENTS.md (或 CLAUDE.md) 复制到 ~/.claude-mux/templates/web.md

说: "check agents migration" / "migrate to AGENTS.md"
(只读) 报告哪些 CLAUDE.md 文件可以迁移到 AGENTS.md；确认后在整个目录树中重命名，并重启基础目录下运行中的会话

说: "tip"
显示一条提示 - 全天相同，或在设置 TIP_MODE=random 时随机

说: "启用提示" / "禁用提示"
在所有项目中开启或关闭每日提示

说: "更新 claude-mux"
警告所有会话将重启，请求确认，然后更新并重启

说: "停止所有会话"
优雅地退出所有托管会话

说: "help"
显示完整的对话命令列表
```

**这些命令支持任何语言。** 如果你用中文、日文、希伯来文或任何其他语言输入等效内容，Claude 会推断意图并运行对应的命令。

**在任何会话中输入 `help` 查看完整命令列表。**

## 更多

- [CLI 参考](../docs/CLI.md) - 用于脚本和自动化的完整命令参考
- [指南](../docs/GUIDE.md) - 配置、会话详情、内部机制和故障排除
- [安装选项](../docs/INSTALL.md) - Homebrew、手动安装、LaunchAgent 设置
- [常见问题](../docs/FAQ.md) - 关于 claude-mux 的常见问题
- [已知问题](../docs/ISSUES.md) - 已知 bug、计划功能和已解决的问题
- [变更日志](../CHANGELOG.md) - 每个版本的变更内容
