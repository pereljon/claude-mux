# 常见问题

[English](../FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · **中文** · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

> 注意：此翻译可能落后于英文 FAQ。规范版本请参阅 [FAQ.md](../FAQ.md)。

## claude-mux 是什么？

一个将 Claude Code 包裹在 tmux 中以实现持久会话的 shell 脚本。会话在关闭终端后仍然存活，重启时恢复对话上下文，并可通过 Remote Control 从 Claude 移动应用访问。你只需在会话中与 Claude 对话来管理一切。

## 支持 Linux 吗？

暂不支持。目前仅限 macOS（Apple Silicon 和 Intel）。Linux 支持计划在 v2.0 实现。安装程序可以在 Linux 上运行，但会跳过 LaunchAgent 配置并打印提示。二进制文件本身可以工作，但尚无 systemd 服务或等效的自动启动机制。

## 什么是主会话？

主会话是一个通用 Claude 会话，位于你的根目录（默认为 `~/Claude`）。当 `LAUNCHAGENT_MODE=home`（默认值）时，它在登录时自动启动并全天保持运行。它**默认受保护**，即 `--shutdown home` 在没有 `--force` 的情况下会拒绝停止它。

把主会话当作你从 Claude 移动应用接入的始终可用的入口。从这里你可以列出项目、启动其他会话、管理配置，以及处理不属于特定项目的通用工作。

## 什么是 Remote Control？

Remote Control (RC) 是 Claude Code 的一项功能，让你可以从 Claude 移动应用或 Claude Desktop 连接到运行中的 Claude 会话。claude-mux 在启动每个会话时都启用了 `--remote-control`，因此所有会话会自动出现在 RC 列表中。连接后，使用方式与在终端中完全相同。claude-mux 还绕过了 RC 的限制，比如斜杠命令在原生 RC 中不可用，通过 tmux 路由来实现。

## 什么是权限模式？

Claude Code 有四种权限模式，控制 Claude 的自主程度：

| 模式 | 行为 |
|------|------|
| `default` | Claude 在运行命令或编辑文件前会请求确认 |
| `acceptEdits` | Claude 自动应用文件编辑，但运行 shell 命令前会请求确认 |
| `plan` | Claude 只能读取和规划，不能写入或运行命令 |
| `bypassPermissions` | Claude 不经请求直接运行所有操作（首次启动时需要确认） |

通过配置中的 `DEFAULT_PERMISSION_MODE` 为所有项目设置默认值。在运行中的会话里说 "switch this session to plan mode"（或任何模式名）即可切换。"yolo" 是 `bypassPermissions` 的别名。

从其他模式切换到 `bypassPermissions` 使用 Shift+Tab 导航，不需要重启。从 `bypassPermissions` 切换到其他模式需要重启，claude-mux 会自动处理。

## 如何重置会话？

三种方式，取决于你需要什么：

- **Clear**（"clear this session"）：向会话发送 `/clear`。清除对话历史并重新开始。会话保持运行。
- **Compact**（"compact this session"）：向会话发送 `/compact`。将对话总结为更短的上下文，释放上下文窗口。历史以压缩形式保留。
- **Restart**（"restart this session"）：关闭 Claude 并使用 `claude -c` 重新启动，恢复上一次对话。当你需要干净的进程时使用（例如更改权限模式后或 Claude 卡住时）。

## 什么是模板？

模板是存储在 `~/.claude-mux/templates/` 中的可复用 CLAUDE.md 文件。使用 `-n` 创建新项目时，默认模板（或用 `--template NAME` 指定的模板）会被复制到项目中作为其 CLAUDE.md。

创建模板：在会话中说 "save this as a template named web"（将当前项目的 CLAUDE.md 复制到 `~/.claude-mux/templates/web.md`）。

使用模板：`claude-mux -n ~/projects/my-app --template web` 或在会话中说 "create a new project called my-app using the web template"。

列出模板："list templates" 或 `claude-mux --list-templates`。

## 每日技巧提示如何工作？

每个项目的 `.claude/settings.local.json` 中有一个 Claude Code Stop 钩子，它在每次对话轮次后调用 `claude-mux --tipotd`。该命令检查今天是否已显示过提示（通过 `~/.claude-mux/.tip-date`）。如果已显示，约 6ms 内退出。如果未显示，打印一条提示并记录今天的日期。

提示默认启用（`TIP_OF_DAY=true`）。在任意会话中说 "enable tips" 或 "disable tips" 来切换。`TIP_MODE=daily` 全天显示同一条提示；`TIP_MODE=random` 每次调用随机选择一条（配合 Stop 钩子，由于每日门控，实际上每天一条随机提示）。

`--tip` 命令不受每日门控限制，所以你随时可以说 "tip"。

## 可以配合多个 GitHub 账户使用吗？

可以。claude-mux 会检测 `~/.ssh/config` 中的 `Host github.com-*` 条目，并将它们注入到每个会话的系统提示中。Claude 知道哪些 SSH 别名可用，并在设置 git remote 时使用正确的别名。

`~/.ssh/config` 配置示例：

```
Host github.com-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_work

Host github.com-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_personal
```

Claude 会在工作仓库中使用 `git@github.com-work:org/repo.git`，个人仓库中使用 `git@github.com-personal:user/repo.git`。

## 状态存储在哪里？

| 位置 | 内容 |
|------|------|
| `~/.claude-mux/config` | 用户配置（作为 bash 文件加载） |
| `~/.claude-mux/templates/` | CLAUDE.md 模板文件 |
| `~/.claude-mux/.tip-date` | 上次显示提示的日期 |
| `~/.claude-mux/.update-check` | 缓存的版本检查结果 |
| `~/Library/Logs/claude-mux.log` | 日志文件（可通过 `LOG_DIR` 配置） |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | LaunchAgent plist（由 `--install` 生成） |
| `.claudemux-protected`（每个项目） | 标记会话受保护，防止关闭 |
| `.claudemux-ignore`（每个项目） | 从列表中隐藏项目 |

标记文件（`.claudemux-*`）位于每个项目的根目录中，在重命名、移动和同步时随文件夹一起移动。它们会自动添加到 `.gitignore`。

对话历史由 Claude Code 自身管理，存储在 `~/.claude/projects/` 下。

## 如果我 fork 了 claude-mux，自动更新会怎样？

更新检查和 `--update` 命令硬编码了 `pereljon/claude-mux` 作为 GitHub 仓库。如果你 fork 了它，更新检查仍会与上游版本比较，`--update` 会用上游的二进制文件覆盖你 fork 的版本。在 `~/.claude-mux/config` 中设置 `UPDATE_CHECK=false` 可禁用，或在脚本中修改 `check_for_update()` 和 `do_update()` 函数的仓库 URL。

## 如何通过 Homebrew 安装？

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

使用 `brew upgrade claude-mux` 更新。注意：如果通过 Homebrew 安装，`--update` 会自动委托给 `brew upgrade`。

## 这和 `claude --worktree --tmux` 有什么区别？

`claude --worktree --tmux` 为隔离的 git worktree 创建一个 tmux 会话，专为并行编码任务设计。claude-mux 管理的是面向你实际项目目录的持久会话，启用了 Remote Control、用于自管理的系统提示注入、对话恢复和会话生命周期管理。它们解决的是不同的问题。

## 为什么会话显示 "Not logged in"？

这发生在首次启动时，如果 macOS keychain 处于锁定状态，当 LaunchAgent 在你登录后解锁 keychain 之前启动时很常见。修复方式：在普通终端运行 `security unlock-keychain`，然后附加到任意会话（`claude-mux -t <name>`）并运行 `/login` 完成浏览器认证流程。之后重启所有会话，它们会自动获取已存储的凭据。

## 多个终端可以附加到同一个会话吗？

可以。这是标准的 tmux 行为。在已有运行会话的目录中运行 `claude-mux` 会附加到该会话。多个终端实时看到相同的会话内容。

## 如何永久停止主会话？

LaunchAgent 设置了 `KeepAlive: true`，所以关闭主会话会在约 60 秒内触发重新生成。要永久停止它，请禁用 LaunchAgent：

```bash
claude-mux --install --launchagent-mode none
```

## "Session ready!" 消息是什么意思？

会话启动或重启时，claude-mux 在 Claude 加载完成后发送 `Ready?` 提示。注入内容告知 Claude 用 "Session ready!" 回复，别无其他。这确认会话处于活跃状态且系统提示注入正在工作。你可以忽略它。

## 如何从列表中隐藏项目？

在任意会话中说 "hide this project"，或运行 `claude-mux --hide my-project`。这会创建一个 `.claudemux-ignore` 标记文件。该项目不会出现在 `claude-mux -L` 的输出中。查看隐藏项目：`claude-mux -L --hidden`。取消隐藏："show this project" 或 `claude-mux --show my-project`。

## 如何卸载 claude-mux？

```bash
claude-mux --uninstall
```

这会从所有项目中移除提示钩子和权限规则，卸载 LaunchAgent，并可选择移除 `~/.claude-mux/`。它会报告二进制文件路径，以便你手动删除（如果通过 Homebrew 安装，则使用 `brew uninstall claude-mux`）。

## 斜杠命令能在 Remote Control 上用吗？

不能直接使用。Claude Code 在 RC 会话中不原生支持斜杠命令（`/model`、`/clear` 等）。claude-mux 通过在每个会话中注入 `claude-mux -s` 来绕过这个限制，让 Claude 通过 tmux 向自己发送斜杠命令。只需说 "switch to Haiku" 或 "compact this session"，Claude 会处理。

## 无法在会话中选择文本

按住 **Option**（macOS）或 **Shift**（Linux/Windows 终端）的同时点击并拖动。这会绕过 tmux 的鼠标捕获，将选中内容复制到系统剪贴板。无需修改配置。

## 对话式命令支持哪些语言？

所有语言。触发短语（"help"、"status"、"list sessions" 等）在任何语言下都有效。Claude 从用户的自然语言中推断意图并运行匹配的命令。README 也已翻译成 12 种语言。
