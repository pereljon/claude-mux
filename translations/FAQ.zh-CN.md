# 常见问题

[English](../docs/FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · **中文** · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## claude-mux 是什么？

一个将 Claude Code 包装在 tmux 中以实现持久会话的 shell 脚本。会话在终端关闭后仍然存活，重启时自动恢复对话上下文，并可通过 Remote Control 从 Claude 移动应用访问。你在会话内与 Claude 对话来管理一切。

## 支持 Linux 吗？

暂不支持。目前仅限 macOS（Apple Silicon 和 Intel）。Linux 支持计划在 v2.0 实现。安装程序可在 Linux 上运行但会跳过 LaunchAgent 设置并打印提示。二进制文件本身可以工作，但还没有 systemd 服务或等效的自动启动机制。

## home 会话是什么？

home 会话是一个通用 Claude 会话，存在于你的 base 目录中（默认为 `~/Claude`）。当 `LAUNCHAGENT_MODE=home`（默认值）时，它在登录时自动启动并全天运行。默认**受保护**，意味着 `--shutdown home` 在不加 `--force` 时会拒绝停止。

把 home 会话当作你从 Claude 移动应用随时可用的入口。从这里你可以列出项目、启动其他会话、管理配置、做不属于特定项目的通用工作。

## 什么是 Remote Control？

Remote Control (RC) 是 Claude Code 的一个功能，让你可以从 Claude 移动应用或 Claude Desktop 连接到运行中的 Claude 会话。claude-mux 在启动每个会话时都启用了 `--remote-control`，所以所有会话都会自动出现在 RC 列表中。连接后，你与 Claude 的交互方式和在终端中完全一样。claude-mux 还解决了 RC 的一些限制，比如 slash 命令原生不可用 - 通过 tmux 路由它们来绕过。

## 什么是权限模式？

Claude Code 有四种权限模式，控制 Claude 拥有多少自主权：

| 模式 | 行为 |
|------|------|
| `default` | Claude 在运行命令或编辑文件前会询问 |
| `acceptEdits` | Claude 自动应用文件编辑但在 shell 命令前询问 |
| `plan` | Claude 只能读取和规划，不能写入或运行命令 |
| `bypassPermissions` | Claude 无需询问即可运行一切（首次启动时需确认） |

通过配置中的 `DEFAULT_PERMISSION_MODE` 为所有项目设置默认值。在运行中的会话里说"把这个会话切换到 plan 模式"（或任何模式名）即可切换。"yolo" 是 `bypassPermissions` 的别名。

从其他模式切换到 `bypassPermissions` 使用 Shift+Tab 导航，不需要重启。从 `bypassPermissions` 切换到其他模式需要重启，claude-mux 会自动处理。

## 如何重置会话？

三种选择，取决于你想要什么：

- **清除**（"清除这个会话"）：向会话发送 `/clear`。清除对话历史并重新开始。会话保持运行。
- **压缩**（"压缩这个会话"）：向会话发送 `/compact`。将对话总结为更短的上下文，释放上下文窗口。历史以压缩形式保留。
- **重启**（"重启这个会话"）：关闭 Claude 并使用 `claude -c` 重新启动，恢复上次对话。当你需要干净的进程时使用（例如更改权限模式后或 Claude 卡住时）。

## 什么是模板？

模板是存储在 `~/.claude-mux/templates/` 中的可复用 CLAUDE.md 文件。当你用 `-n` 创建新项目时，默认模板（或用 `--template NAME` 指定的模板）会被复制到项目中作为其 CLAUDE.md。

创建模板："把这个保存为名为 web 的模板"（将当前项目的 CLAUDE.md 复制到 `~/.claude-mux/templates/web.md`）。

使用模板：`claude-mux -n ~/projects/my-app --template web` 或在会话内："用 web 模板创建一个叫 my-app 的新项目"。

列出模板："列出模板" 或 `claude-mux --list-templates`。

## 每日提示是怎么工作的？

每个项目的 `.claude/settings.local.json` 中有一个 Claude Code `UserPromptSubmit` hook，在每次提交提示时调用 `claude-mux --on-prompt`。当天第一个提示会在对话中注入一条提示；当天之后的提示不会注入任何内容。状态按会话保存在 `~/.claude-mux/tip-state/<session_id>.json` 中，因此每个活动会话每天显示一次提示。由于该 hook 注入到上下文中（而不是输出仅进入转录的 Stop hook），提示在对话和 Remote Control 中都可见。

提示默认启用（`TIP_OF_DAY=true`）。在任何会话内用"启用提示"或"禁用提示"来切换。`TIP_MODE=daily` 全天显示同一条提示；`TIP_MODE=random` 随机选择一条提示。

`--tip` 命令始终有效，不受每日门控影响（也不受 `TIP_OF_DAY` 影响），所以你随时可以说"tip"。

## 可以用多个 GitHub 账号吗？

可以。claude-mux 检测 `~/.ssh/config` 中的 `Host github.com-*` 条目并将它们注入到每个会话的系统提示中。Claude 知道哪些 SSH 别名可用，并能在设置 git remote 时使用正确的别名。

`~/.ssh/config` 示例设置：

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

Claude 会知道对工作仓库使用 `git@github.com-work:org/repo.git`，对个人仓库使用 `git@github.com-personal:user/repo.git`。

## 状态存储在哪里？

| 位置 | 存储内容 |
|------|---------|
| `~/.claude-mux/config` | 用户配置（作为 bash 脚本加载） |
| `~/.claude-mux/templates/` | CLAUDE.md 模板文件 |
| `~/.claude-mux/tip-state/<session_id>.json` | 每会话提示日期 + 更新通知节流 |
| `~/.claude-mux/.update-check` | 缓存的版本检查结果 |
| `~/.claude-mux/.update-checking` | 后台更新检查期间的锁 |
| `~/Library/Logs/claude-mux.log` | 日志文件（可通过 `LOG_DIR` 配置） |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | LaunchAgent plist（由 `--install` 生成） |
| `.claudemux-protected`（每个项目） | 标记会话受保护，防止关闭 |
| `.claudemux-ignore`（每个项目） | 在列表中隐藏项目 |

标记文件（`.claudemux-*`）存在于每个项目的根目录，随文件夹跨重命名、移动和同步。它们会被自动添加到 `.gitignore`。

对话历史由 Claude Code 本身管理，存储在 `~/.claude/projects/` 下。

## 如果我 fork 了 claude-mux，自动更新会怎样？

更新检查和 `--update` 命令硬编码了 `pereljon/claude-mux` 作为 GitHub 仓库。如果你 fork 了它，更新检查仍会与上游版本比较，`--update` 会用上游版本覆盖你 fork 的二进制文件。在 `~/.claude-mux/config` 中设置 `UPDATE_CHECK=false` 来禁用，或者修改脚本中 `check_for_update()` 和 `do_update()` 函数中的仓库 URL。

## 如何通过 Homebrew 安装？

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

用 `brew upgrade claude-mux` 更新。注意：如果你通过 Homebrew 安装，`--update` 会自动委托给 `brew upgrade`。

## 和 `claude --worktree --tmux` 有什么区别？

`claude --worktree --tmux` 为隔离的 git worktree 创建 tmux 会话，设计用于并行编码任务。claude-mux 管理你实际项目目录的持久会话，启用 Remote Control，注入系统提示用于自我管理，恢复对话，并管理会话生命周期。它们解决不同的问题。

## 和 Claude Cowork Dispatch 有什么区别？

Dispatch 从 Claude 桌面应用启动任务，但需要应用保持运行且不绑定到特定项目。claude-mux 管理持久的、绑定项目的会话，能跨重启存活，并可通过 Remote Control 从任何地方访问 - 不需要桌面应用。

## 为什么会话显示"Not logged in"？

这发生在首次启动时如果 macOS 钥匙串被锁定，这在 LaunchAgent 在你解锁钥匙串之前启动时很常见。修复方法：在普通终端中运行 `security unlock-keychain`，然后连接到任何会话（`claude-mux -t <name>`）并运行 `/login` 完成浏览器认证流程。之后重启所有会话，它们会获取存储的凭证。

## 多个终端可以连接到同一个会话吗？

可以。这是标准的 tmux 行为。在已有运行中会话的目录中运行 `claude-mux` 会连接到它。多个终端实时看到相同的会话内容。

## 如何永久停止 home 会话？

LaunchAgent 设置了 `KeepAlive: true`，所以关闭 home 会话会在约 60 秒内触发重新启动。要永久停止，禁用 LaunchAgent：

```bash
claude-mux --install --launchagent-mode none
```

## "Session ready!" 消息是什么意思？

当会话启动或重启时，claude-mux 在 Claude 完成加载后发送一个 `Ready?` 提示。注入指令告诉 Claude 回应 "Session ready!" 且不包含其他内容。这确认了会话存活且系统提示注入正常工作。你可以忽略它。

## 如何在列表中隐藏项目？

在任何会话内说"隐藏这个项目"，或运行 `claude-mux --hide my-project`。这会创建一个 `.claudemux-ignore` 标记文件。项目不会出现在 `claude-mux -L` 输出中。查看隐藏项目：`claude-mux -L --hidden`。取消隐藏："显示这个项目" 或 `claude-mux --show my-project`。

## 如何卸载 claude-mux？

```bash
claude-mux --uninstall
```

这会从所有项目中移除提示 hook 和权限规则，卸载 LaunchAgent，并可选地删除 `~/.claude-mux/`。它会报告二进制文件路径以便你手动删除（或者如果通过 Homebrew 安装则使用 `brew uninstall claude-mux`）。

## slash 命令在 Remote Control 中可用吗？

原生不支持。Claude Code 不支持在 RC 会话中使用 slash 命令（`/model`、`/clear` 等）。claude-mux 通过为每个会话注入 `claude-mux -s` 来解决这个问题，使 Claude 能通过 tmux 向自己发送 slash 命令。只需说"切换到 Haiku"或"压缩这个会话"，Claude 会处理。

## 在会话中无法选择文本

按住 **Option**（macOS）或 **Shift**（Linux/Windows 终端）同时点击拖动。这会绕过 tmux 的鼠标捕获并将选中内容复制到系统剪贴板。不需要更改配置。

## 对话命令支持哪些语言？

所有语言。触发短语（"help"、"status"、"list sessions" 等）在任何语言中都有效。Claude 从用户的自然语言推断意图并运行匹配的命令。README 也已翻译为 12 种语言。
