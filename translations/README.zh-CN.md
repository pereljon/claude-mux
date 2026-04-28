# claude-mux - Claude Code 多路复用器

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · **中文** · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

> 注意：此翻译可能落后于英文 README。规范版本请参阅 [README.md](../README.md)。

为你所有项目提供持久的 Claude Code 会话 - 通过 Claude 移动应用从任何地方访问。

## 为什么

Remote Control 承诺让你从任何地方使用 Claude Code——但没有会话管理，即使在 Claude Desktop 中也是二流体验：

- 关闭终端后会话就消失，对话上下文不会自动恢复
- 没有常驻的主会话——除非你留了什么开着，否则拿起手机时什么都没在运行
- 没有运行中的会话，Remote Control 就毫无用处——既无法进入项目，也无法新建一个
- 即使在运行中的 RC 会话里，斜杠命令也不起作用——无法切换模型、压缩上下文或更改权限模式
- 新建项目需要手动创建目录、初始化 git、编写 CLAUDE.md、设置权限模式并选择模型——这些在 RC 中都无法完成
- 管理多个项目意味着多次手动启动终端，却无法全局了解哪些项目在运行、处于什么状态

claude-mux 解决了所有这些问题。它将 Claude Code 包裹在 tmux 中使会话持久，注入一段系统提示让 Claude 能管理自己的会话，并通过 tmux 路由斜杠命令使其在 Remote Control 下也能正常工作。会话一旦运行，你就可以通过对话管理一切——在终端或移动应用中都行。

## 快速开始

```bash
brew tap pereljon/tap
brew install claude-mux
```

```bash
cd ~/path/to/your/project
claude-mux
```

或者：

```bash
claude-mux ~/path/to/your/project
```

就这些。你已进入一个启用了 Remote Control 的、持久的、会话感知的 Claude 会话。从这里开始，一切都是对话式的。

## 与 Claude 对话

这是日常使用 claude-mux 的方式。每个会话都注入了命令，让 Claude 可以管理会话、切换模型、发送斜杠命令、创建新项目——全部在对话内完成。你不需要记住 CLI 标志。

```
你："status"
Claude：报告会话名称、模型、权限模式、上下文用量，并列出所有会话

你："list active sessions"
Claude：显示所有运行中的会话及其状态

你："start a session for my api-server project"
Claude：在 ~/Claude/work/api-server 中启动会话

你："create a new project called mobile-app using the web template"
Claude：创建项目目录，初始化 git，应用模板，启动会话

你："switch this session to Haiku"
Claude：通过 tmux 向自己发送 /model haiku

你："compact the api-server session"
Claude：向 api-server 会话发送 /compact

你："restart the web-dashboard session"
Claude：关闭并重新启动会话，保留对话上下文

你："switch the api-server session to plan mode"
Claude：以 plan 权限模式重启会话

你："stop all sessions"
Claude：优雅地退出所有受管会话

你："help"
Claude：打印完整的对话式命令列表
```

这些命令在任何语言下都有效。如果你用西班牙语、日语、希伯来语或任何其他语言输入等效表达，Claude 会推断意图并执行匹配的命令。

在任意会话中输入 `help` 可查看完整命令列表。

### 主会话

主会话是一个通用会话，位于你的根目录（默认为 `~/Claude`）。当 `LAUNCHAGENT_MODE=home` 时在登录时自动启动，让你拥有一个始终就绪、可从手机访问的 Claude 会话。无需先启动项目专属会话，就能用它管理所有其他会话。

主会话始终是**受保护的** — `--shutdown home` 会拒绝在没有 `--force` 的情况下停止它。

## 它做什么

在底层，claude-mux 处理以下事项：

- **启用 Remote Control 的持久 tmux 会话** — 每个会话都可以通过 Claude 移动应用访问
- **对话恢复** — 重新启动时恢复上一次对话（`claude -c`），保留上下文
- **系统提示注入** — 每个会话都注入了用于自管理、斜杠命令路由和 SSH 账户感知的命令
- **CLAUDE.md 模板** — 在 `~/.claude-mux/templates/` 中维护模板文件（如 `web.md`、`python.md`），并自动应用到新项目
- **多 CLI 工具支持** — 将 `AGENTS.md` 和 `GEMINI.md` 创建为指向 `CLAUDE.md` 的符号链接，使 Codex CLI、Gemini CLI 及其他工具共享同一套指令
- **自动批准权限** — 将 claude-mux 添加到每个项目的允许列表，让 Claude 无需提示即可运行会话命令
- **野生进程迁移** — 如果 Claude 已在 tmux 之外运行，将其迁移到受管会话中
- **Tmux 体验改进** — 鼠标支持、50k 滚动缓冲区、剪贴板集成、256 色、扩展按键、活动监视、标签标题

> **注意：** 这与 `claude --worktree --tmux` 不同，后者为隔离的 git worktree 创建一个 tmux 会话。claude-mux 管理的是面向你实际项目目录的持久会话，并附带 Remote Control 和系统提示注入。

## 系统要求

- macOS（Apple Silicon）
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## 安装

### Homebrew（推荐）

```bash
brew tap pereljon/tap
brew install claude-mux
```

安装后，运行配置命令：

```bash
claude-mux --install
```

更新：

```bash
brew upgrade claude-mux       # 或：claude-mux --update  （可在任意会话内运行）
```

### 手动

```bash
./install.sh
```

`install.sh` 将二进制文件复制到 `~/bin` 并添加到 `PATH`。然后运行：

```bash
claude-mux --install
```

交互式配置会询问你的 Claude 项目所在位置、登录时是否启动主会话、以及使用哪个模型。它会创建 `~/.claude-mux/config` 并安装 LaunchAgent。

使用 `--non-interactive` 跳过提示并接受默认值。

选项：

```bash
claude-mux --install --non-interactive                     # 跳过提示，使用默认值
claude-mux --install --base-dir ~/work/claude              # 使用不同的根目录
claude-mux --install --launchagent-mode none               # 禁用 LaunchAgent 行为
claude-mux --install --home-model haiku                    # 主会话使用 Haiku
claude-mux --install --no-launchagent                      # 完全跳过 LaunchAgent 安装
```

LaunchAgent 在登录时运行 `claude-mux --autolaunch`，并有 45 秒的启动延迟，以便系统服务初始化。

## 会话状态

| 状态 | 含义 |
|--------|---------|
| `running` | tmux 会话存在且 Claude 正在运行 |
| `protected` | 与 `running` 相同，但会话受保护——`--shutdown` 需要 `--force` 才能停止。主会话始终受保护。 |
| `stopped` | tmux 会话存在但 Claude 已退出 |
| `idle` | `BASE_DIR` 下存在 `.claude/` 项目，但没有运行中的 claude-mux tmux 会话（仅在 `-L` 中显示） |

会话名称前的 `>` 前缀（例如 `> home`）标记执行了列表命令的会话。

在已有运行会话的目录中运行 `claude-mux` 会附加到该会话。多个终端可以附加到同一个会话（标准 tmux 行为）。

## 配置

`~/.claude-mux/config` 由 `claude-mux --install` 创建（或在没有 config 的情况下首次运行任意命令时创建）。编辑该文件即可覆盖任何默认值——无需直接修改脚本。

| 变量 | 默认值 | 说明 |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | 用于扫描 Claude 项目（包含 `.claude/` 的目录）的根目录 |
| `LOG_DIR` | `$HOME/Library/Logs` | `claude-mux.log` 文件所在目录 |
| `DEFAULT_PERMISSION_MODE` | `auto` | 在每个项目中设置 Claude 的 `permissions.defaultMode`。有效值：`default`、`acceptEdits`、`plan`、`auto`、`dontAsk`、`bypassPermissions`。设为 `""` 可禁用。 |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | 为 `true` 时，Claude 会话可向其他会话发送斜杠命令——适合多 agent 编排 |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | 存放 CLAUDE.md 模板文件的目录 |
| `DEFAULT_TEMPLATE` | `default.md` | 应用于新项目（`-n`）的默认模板。设为 `""` 可禁用。 |
| `SLEEP_BETWEEN` | `5` | 使用 `-a` 时各会话启动之间的秒数。如 RC 注册失败可调大。 |
| `HOME_SESSION_MODEL` | `""` | 主会话使用的模型。有效值：`sonnet`、`haiku`、`opus`。留空则继承 Claude 默认值。 |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | 以空格分隔的文件列表，这些文件将作为指向 `CLAUDE.md` 的符号链接创建，供其他 AI CLI 工具使用。设为 `""` 可禁用。 |
| `LAUNCHAGENT_MODE` | `home` | 登录时的 LaunchAgent 行为：`none`（什么也不做）或 `home`（启动受保护的主会话）。旧的 `LAUNCHAGENT_ENABLED=true` 等同于 `home`。 |

**Tmux 会话选项**（全部可配置，全部默认启用）：

| 变量 | 默认值 | 说明 |
|----------|---------|-------------|
| `TMUX_MOUSE` | `true` | 鼠标支持——滚动、选择、调整窗格大小 |
| `TMUX_HISTORY_LIMIT` | `50000` | 滚动缓冲区行数（tmux 默认是 2000） |
| `TMUX_CLIPBOARD` | `true` | 通过 OSC 52 集成系统剪贴板 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | 终端类型，确保正确的颜色渲染 |
| `TMUX_EXTENDED_KEYS` | `true` | 扩展按键序列，包括 Shift+Enter（需要 tmux 3.2+） |
| `TMUX_ESCAPE_TIME` | `10` | Escape 键延迟（毫秒，tmux 默认是 500） |
| `TMUX_TITLE_FORMAT` | `#S` | 终端/标签标题格式（`#S` = 会话名，`""` 可禁用） |
| `TMUX_MONITOR_ACTIVITY` | `true` | 当其他会话有活动时通知 |

## 目录结构

通过是否存在 `.claude/` 目录来发现项目，深度不限：

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ 含 .claude/ - 被管理
│   │   └── .claude/
│   ├── project-b/          # ✓ 含 .claude/ - 被管理
│   │   └── .claude/
│   └── -archived/          # ✗ 排除（以 - 开头）
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ 含 .claude/ - 被管理
│   │   └── .claude/
│   ├── .hidden/            # ✗ 排除（隐藏目录）
│   │   └── .claude/
│   └── project-d/          # ✗ 无 .claude/ - 不是 Claude 项目
├── deep/nested/project-e/  # ✓ 含 .claude/ - 任意深度都能找到
│   └── .claude/
└── ignored-project/        # ✗ 排除（.ignore-claudemux）
    ├── .claude/
    └── .ignore-claudemux
```

会话名由目录名派生：空格变为连字符，非字母数字字符（连字符除外）会被替换，首尾多余的连字符会被去除。如果目录名清洗后为空，会被跳过并记录一条警告。

## 会话系统提示

每个 Claude 会话以 `--append-system-prompt` 启动，包含其环境的相关上下文：

```
You are running inside tmux session '<session-name>'.
claude-mux version: <version>
[Update available: <new-version> (found <date>). Tell the user and suggest they say "update claude-mux" to update.]
claude-mux path: /path/to/claude-mux

Rules:
- You CAN send slash commands (/model, /compact, /clear, etc.) to this session
  via the -s command. Never tell the user you cannot change models or run slash
  commands.
- Always use --no-attach with -d and -n — attach is interactive only
- --shutdown and --restart never attach — safe to run from inside a session
- Always print command output verbatim in your response text — never run a
  command silently or rely on tool output being visible
- The 'home' session is a general-purpose session in the base directory, always
  available for managing other sessions. It is protected (* in status):
  --shutdown requires --force, but --restart bypasses protection (it relaunches,
  not permanently kills).
- When asked to shut down sessions, run the command directly — protected sessions
  are skipped automatically, do not ask for confirmation
- When user says: ready — respond with "Ready." on one line. Nothing else.
  Sent automatically when a session starts or restarts.
- When user says: help — print the conversational commands list verbatim
- When user says: status — report session name, current model, current permission
  mode, context usage estimate, then run claude-mux -l and include the results
- When user says: list active sessions — run claude-mux -l
- When user says: list all sessions — run claude-mux -L
- When user says: start session SESSION — run claude-mux -d SESSION --no-attach
- When user says: stop this session / stop session NAME — run claude-mux --shutdown
- When user says: stop all sessions — run claude-mux --shutdown
- When user says: restart this session / restart session NAME — run claude-mux --restart
- When user says: restart all sessions — run claude-mux --restart
- When user says: start new session in FOLDER — run claude-mux -n FOLDER --no-attach
- When user says: switch this session to MODE mode / switch session NAME to MODE mode
- When user says: switch this session to MODEL model / switch session NAME to MODEL model
- When user says: compact/clear this session / compact/clear session NAME
- When user says: list templates — run claude-mux --list-templates
- When user says: update claude-mux — warns about restart, gets confirmation, then runs --update and --restart

Commands:
  -s '<session-name>' '/command'  Send slash command to yourself
  -l                          List active sessions
  -L                          List all projects
  -d DIR --no-attach          Launch session in directory
  -n DIR --no-attach          New project
  -n DIR -p --no-attach       New project (create parents)
  --template NAME             CLAUDE.md template (with -n)
  --list-templates            Show available templates
  --shutdown SESSION...       Shut down sessions (omit SESSION to shut down all)
  --shutdown SESSION --force  Shut down protected session
  --restart SESSION...        Restart sessions (omit SESSION to restart all running)
  --permission-mode MODE SESSION  Restart session with a different permission mode
                              Modes: default, acceptEdits, plan, auto, bypassPermissions, dontAsk, dangerously-skip-permissions
                              ("yolo" is an alias for dangerously-skip-permissions)
  --update                    Update claude-mux to the latest version
  -a                          Start ALL sessions (use with caution)

GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

（更新行仅在有可用更新时出现。）

当 `ALLOW_CROSS_SESSION_CONTROL=true` 时，send 命令会变为允许定向到任意会话，而不仅仅是自身。该 path 是启动时脚本的绝对路径，因此会话不依赖 `PATH`。

## CLI 参考

你很少需要直接使用这些——Claude 会在会话内为你运行它们。这些命令适用于脚本、自动化，或在会话外使用时。

```bash
# 启动并附加
claude-mux                       # 在当前目录启动 Claude 并附加
claude-mux ~/projects/my-app     # 在指定目录启动 Claude 并附加
claude-mux -d ~/projects/my-app  # 同上（显式形式）
claude-mux -t my-app             # 附加到已存在的 tmux 会话

# 创建新项目
claude-mux -n ~/projects/app     # 创建新 Claude 项目并附加
claude-mux -n ~/new/path/app -p  # 同上，并创建目录及其父目录
claude-mux -n ~/app --template web        # 使用指定 CLAUDE.md 模板创建新项目
claude-mux -n ~/app --no-multi-coder      # 创建新项目但不创建 AGENTS.md/GEMINI.md 符号链接

# 会话管理
claude-mux -l                    # 按状态列出会话（active、running、stopped）
claude-mux -L                    # 列出所有项目（活动 + 空闲）
claude-mux -s my-app '/model sonnet'      # 向会话发送斜杠命令
claude-mux --shutdown my-app              # 关闭指定会话
claude-mux --shutdown                     # 关闭所有受管会话
claude-mux --shutdown home --force        # 关闭受保护的主会话
claude-mux --restart my-app              # 重启指定会话
claude-mux --restart                     # 重启所有运行中的会话
claude-mux --permission-mode plan my-app  # 以 plan 模式重启会话
claude-mux -a                    # 启动 BASE_DIR 下所有受管会话

# 其他
claude-mux --list-templates      # 显示可用的 CLAUDE.md 模板
claude-mux --guide               # 显示供会话内使用的对话式命令
claude-mux --install             # 交互式配置：config + LaunchAgent
claude-mux --update              # 更新到最新版本
claude-mux --dry-run             # 预览动作但不执行
claude-mux --version             # 打印版本号
claude-mux --help                # 显示所有选项

# 跟踪日志
tail -f ~/Library/Logs/claude-mux.log
```

从终端运行时，输出会实时镜像到 stdout。通过 LaunchAgent 运行时，输出仅写入日志文件。

## 故障排查

### 会话显示 "Not logged in · Run /login"

这通常发生在首次启动时，macOS keychain 还处于锁定状态（脚本在登录后 keychain 解锁之前运行时常见）。修复方式：

```bash
# 在普通终端解锁 keychain
security unlock-keychain

# 然后在任意一个运行中的会话里完成认证
claude-mux -t <any-session>
# 运行 /login 并完成浏览器流程
```

完成一次认证后，关闭并重新启动所有会话——它们会自动获取已存储的凭据。

### 会话未出现在 Claude Code Remote 中

会话必须已认证（不显示 "Not logged in"）。在干净的已认证启动后，几秒内它们就应当出现在 RC 列表里。

### tmux 中的多行输入

`/terminal-setup` 命令无法在 tmux 内运行。claude-mux 默认启用了 tmux 的 `extended-keys`（`TMUX_EXTENDED_KEYS=true`），它在大多数现代终端中支持 Shift+Enter。如果 Shift+Enter 不起作用，可在提示中使用 `\` + Return 输入换行。

### 会话启动时显示 "Ready."

会话启动或重启时，claude-mux 会在 Claude 加载完成后自动发送 `ready` 消息。注入内容告知 Claude 用 "Ready." 单独回复，别无其他。这确认了会话处于活跃状态且注入正在工作。

### 通过 Remote Control 使用斜杠命令

斜杠命令（如 `/model`、`/clear`）在 RC 会话中[并未原生支持](https://github.com/anthropics/claude-code/issues/30674)。claude-mux 对此做了变通——每个会话都注入了 `claude-mux -s`，让 Claude 通过 tmux 向自己发送斜杠命令。

## 日志

- `~/Library/Logs/claude-mux.log` — 所有脚本动作，附带 UTC 时间戳（可通过 `LOG_DIR` 配置）

如需进行底层 LaunchAgent 调试，请使用 Console.app 或 `log show`。
