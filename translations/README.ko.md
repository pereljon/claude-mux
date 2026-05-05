# claude-mux - Claude Code 멀티플렉서

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · **한국어** · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

모든 프로젝트를 위한 영구 Claude Code 세션 - Claude 모바일 앱을 통해 어디서나 접근 가능합니다. ***Claude가 관리!***

## 왜 사용하나요

Remote Control은 어디서든 Claude Code를 사용할 수 있다고 약속합니다 — 하지만 세션 관리 없이는 Claude Desktop에서도 이류 인터페이스입니다:

- 터미널을 닫으면 세션이 종료되고 대화 컨텍스트가 자동으로 재개되지 않음
- 상시 실행되는 홈 베이스가 없음 — 무언가를 열어둔 것이 없으면 폰을 들었을 때 아무것도 실행 중이지 않음
- 세션이 실행 중이지 않으면 Remote Control은 무용지물 — 프로젝트에 접근하거나 새로 시작할 수 없음
- 실행 중인 RC 세션에서도 슬래시 명령이 작동하지 않음 — 모델 전환, 압축, 권한 모드 변경 불가
- 새 프로젝트를 시작하려면 디렉토리 수동 생성, git 초기화, CLAUDE.md 작성, 권한 모드 설정, 모델 선택이 필요 — RC에서는 이 중 어느 것도 할 수 없음
- 여러 프로젝트 관리는 여러 터미널을 수동으로 실행하는 것을 의미하며 무엇이 실행 중인지, 어떤 상태인지 전체 파악이 불가능

claude-mux는 이 모든 문제를 해결합니다. Claude Code를 tmux로 감싸 세션이 유지되도록 하고, Claude가 자신의 세션을 관리할 수 있도록 시스템 프롬프트를 주입하며, 슬래시 명령을 tmux를 통해 라우팅해 Remote Control에서도 동작하게 합니다. 세션이 실행 중이면 터미널이든 모바일 앱이든 Claude와 대화로 모든 것을 처리합니다.

## 빠른 시작

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

```bash
cd ~/path/to/your/project
claude-mux
```

또는:

```bash
claude-mux ~/path/to/your/project
```

이게 전부입니다. Remote Control이 활성화된 영구적이고 세션 인식이 가능한 Claude 세션에 진입한 상태입니다. 이제부터 모든 것은 대화로 처리합니다.

## Claude와 대화하기

이것이 claude-mux의 일상적인 사용 방식입니다. 모든 세션에는 Claude가 세션을 관리하고, 모델을 전환하고, 슬래시 명령을 보내고, 새 프로젝트를 만들 수 있는 명령이 주입됩니다 - 모두 대화 안에서 이루어집니다. CLI 플래그를 외울 필요가 없습니다.

```
사용자: "status"
Claude: 세션 이름, 모델, 권한 모드, 컨텍스트 사용량을 보고하고 모든 세션 목록을 표시합니다

사용자: "list active sessions"
Claude: 실행 중인 모든 세션과 상태를 표시합니다

사용자: "start a session for my api-server project"
Claude: ~/Claude/work/api-server에서 세션을 시작합니다

사용자: "create a new project called mobile-app using the web template"
Claude: 프로젝트 디렉터리를 생성하고, git을 초기화하고, 템플릿을 적용하고, 세션을 시작합니다

사용자: "switch this session to Haiku"
Claude: tmux를 통해 자기 자신에게 /model haiku를 전송합니다

사용자: "compact the api-server session"
Claude: api-server 세션에 /compact를 전송합니다

사용자: "restart the web-dashboard session"
Claude: 세션을 종료하고 재시작하며 대화 컨텍스트를 보존합니다

사용자: "switch the api-server session to plan mode"
Claude: plan 권한 모드로 세션을 재시작합니다


You: "switch this session to yolo mode"
Claude: switches to bypassPermissions mode via Shift+Tab — no restart needed

You: "what mode is this session"
Claude: reports the current permission mode (default, acceptEdits, plan, bypassPermissions)

You: "switch this session to Opus"
Claude: sends /model opus to itself via tmux

You: "clear this session"
Claude: sends /clear to itself, resetting the conversation

You: "hide this project"
Claude: writes .claudemux-ignore so the project is excluded from -L listings

You: "protect this session"
Claude: writes .claudemux-protected and sets the tmux marker — shutdown now requires --force

You: "is this session protected"
Claude: checks for .claudemux-protected in the project folder and reports

You: "delete the old-prototype project"
Claude: confirms in chat, then moves the project folder to system trash

You: "update claude-mux"
Claude: warns that all sessions will restart, asks for confirmation, then updates and restarts


사용자: "stop all sessions"
Claude: 관리 중인 모든 세션을 정상 종료합니다

사용자: "help"
Claude: 전체 대화형 명령 목록을 출력합니다
```

이 명령들은 어떤 언어로든 동작합니다. 스페인어, 일본어, 히브리어 또는 다른 언어로 동등한 표현을 입력하면 Claude가 의도를 파악해 해당 명령을 실행합니다.

세션 안에서 `help`를 입력하면 전체 명령 목록을 볼 수 있습니다.

### 홈 세션

홈 세션은 베이스 디렉터리(`~/Claude` 기본값)에 있는 범용 세션입니다. `LAUNCHAGENT_MODE=home`이면 로그인 시 자동으로 시작되어 휴대폰에서 항상 준비된 Claude 세션을 제공합니다. 프로젝트별 세션을 먼저 시작하지 않아도 다른 모든 세션을 관리할 수 있습니다.

홈 세션은 기본적으로 **보호** 상태입니다 - `--shutdown home`은 `--force` 없이는 중지를 거부합니다. 보호는 `$BASE_DIR`의 `.claudemux-protected` 마커 파일로 관리되며, `claude-mux --install`이 생성합니다. 보호된 세션은 상태 열에 `protected`로 표시됩니다. 현재 세션은 이름 열에서 `>`로 표시됩니다.

## 동작 방식

내부적으로 claude-mux는 다음을 처리합니다:

- **Remote Control이 활성화된 영구 tmux 세션** — 모든 세션을 Claude 모바일 앱에서 접근 가능하게 합니다
- **대화 재개** — 재시작 시 마지막 대화를 재개(`claude -c`)하여 컨텍스트를 보존합니다
- **시스템 프롬프트 주입** — 각 세션에 자체 관리, 슬래시 명령 라우팅, SSH 계정 인식을 위한 명령을 주입합니다
- **CLAUDE.md 템플릿** — `~/.claude-mux/templates/`에 템플릿 파일(예: `web.md`, `python.md`)을 관리하고 새 프로젝트에 적용합니다
- **Multi-CLI-coder 지원** — Codex CLI, Gemini CLI 및 다른 도구들이 같은 지침을 공유할 수 있도록 `AGENTS.md`와 `GEMINI.md`를 `CLAUDE.md`의 심볼릭 링크로 생성합니다
- **자동 승인 권한** — claude-mux를 각 프로젝트의 허용 목록에 추가하여 Claude가 권한 요청 없이 세션 명령을 실행할 수 있게 합니다
- **떠도는 프로세스 마이그레이션** — Claude가 tmux 외부에서 이미 실행 중이면 관리 대상 세션으로 마이그레이션합니다
- **Tmux 사용성 개선** — 마우스 지원, 50k 스크롤백, 클립보드, 256-color, 확장 키, 활동 모니터링, 탭 제목

> **참고:** 이는 격리된 git worktree에 대해 tmux 세션을 만드는 `claude --worktree --tmux`와는 다릅니다. claude-mux는 실제 프로젝트 디렉터리에 대해 영구 세션을 관리하며, Remote Control과 시스템 프롬프트 주입을 함께 제공합니다.

## 요구 사항

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## 설치

### Homebrew (권장)

```bash
brew tap pereljon/tap
brew install claude-mux
```

설치 후, 설정 명령을 실행하여 config를 만들고 LaunchAgent를 선택적으로 설치하세요(로그인 시 홈 세션):

```bash
claude-mux --install
```

업데이트하려면:

```bash
brew upgrade claude-mux       # 또는: claude-mux --update  (모든 세션 내에서 실행 가능)
```

### 수동

```bash
./install.sh
```

`install.sh`는 바이너리를 `~/bin`에 복사하고 `PATH`에 추가합니다. 그 다음, 실행하세요:

```bash
claude-mux --install
```

대화형 설정은 Claude 프로젝트가 어디에 있는지, 로그인 시 홈 세션을 시작할지, 어떤 모델을 사용할지 묻습니다. `~/.claude-mux/config`를 생성하고 LaunchAgent를 설치합니다.

프롬프트를 건너뛰고 기본값을 사용하려면 `--non-interactive`를 사용하세요.

옵션:

```bash
claude-mux --install --non-interactive                     # 프롬프트 건너뛰기, 기본값 사용
claude-mux --install --base-dir ~/work/claude              # 다른 베이스 디렉터리 사용
claude-mux --install --launchagent-mode none               # LaunchAgent 동작 비활성화
claude-mux --install --home-model haiku                    # 홈 세션에 Haiku 사용
claude-mux --install --no-launchagent                      # LaunchAgent 설치 전부 건너뛰기
```

LaunchAgent는 시스템 서비스 초기화를 위해 45초의 시작 지연을 두고 로그인 시 `claude-mux --autolaunch`를 실행합니다.

## 세션 상태

| 상태 | 의미 |
|--------|---------|
| `running` | tmux 세션이 존재하고 Claude가 실행 중임 |
| `protected` | `running`과 동일하지만 세션이 보호됨 — `--shutdown`으로 중지하려면 `--force`가 필요 |
| `stopped` | tmux 세션은 존재하지만 Claude가 종료됨 |
| `idle` | `BASE_DIR` 아래에 `.claude/` 프로젝트가 존재하지만 claude-mux tmux 세션이 실행되지 않음 (`-L`에서만 표시) |

세션 이름의 `>` 접두사(예: `> home`)는 list 명령을 실행한 세션을 나타냅니다.

이미 실행 중인 세션이 있는 디렉터리에서 `claude-mux`를 실행하면 해당 세션에 연결됩니다. 여러 터미널이 같은 세션에 연결할 수 있습니다(표준 tmux 동작).

## 프로젝트 마커

프로젝트별 상태는 중앙 설정이 아니라 프로젝트 루트의 마커 파일에 저장됩니다. 마커는 `.claudemux-` 접두사를 사용하며, git으로 추적되는 프로젝트에서 생성 시 자동으로 `.gitignore`에 추가됩니다.

| 마커 | 의미 | CLI |
|------|------|-----|
| `.claudemux-protected` | 시작 시 세션 보호 — `--shutdown`에 `--force` 필요 | `--protect` / `--unprotect` |
| `.claudemux-ignore` | `claude-mux -L` 목록에서 프로젝트 숨김 | `--hide` / `--show` |

```bash
claude-mux --hide                    # 현재 프로젝트를 -L 목록에서 숨기기
claude-mux --show                    # 현재 프로젝트 숨김 해제
claude-mux --protect                 # 이 세션을 실수로 종료되지 않도록 보호
claude-mux --unprotect               # 보호 해제
claude-mux -L --hidden               # 숨겨진 프로젝트만 목록 표시
claude-mux --delete ~/projects/old   # 프로젝트 폴더를 시스템 휴지통으로 이동 (macOS)
```

마커는 프로젝트 폴더를 이름 변경하거나 이동해도 따라갑니다. 단일 `.gitignore` 패턴(`.claudemux-*`)으로 현재 및 향후 모든 마커를 처리할 수 있습니다.

## 구성

`~/.claude-mux/config`는 `claude-mux --install`로 생성됩니다 (또는 config가 없는 경우 명령어 첫 실행 시). 기본값을 재정의하려면 이 파일을 편집하세요 - 스크립트 자체는 절대 수정할 필요가 없습니다.

| 변수 | 기본값 | 설명 |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Claude 프로젝트(`.claude/`를 포함한 디렉터리)를 검색할 루트 디렉터리 |
| `LOG_DIR` | `$HOME/Library/Logs` | `claude-mux.log` 파일을 위한 디렉터리 |
| `DEFAULT_PERMISSION_MODE` | `auto` | 각 프로젝트에서 Claude의 `permissions.defaultMode`를 설정합니다. 유효 값: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. 비활성화하려면 `""`로 설정. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | `true`일 때 Claude 세션이 다른 세션에 슬래시 명령을 보낼 수 있음 - 멀티 에이전트 오케스트레이션에 유용 |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | CLAUDE.md 템플릿 파일을 포함하는 디렉터리 |
| `DEFAULT_TEMPLATE` | `default.md` | 새 프로젝트(`-n`)에 적용되는 기본 템플릿. 비활성화하려면 `""`로 설정. |
| `SLEEP_BETWEEN` | `5` | `-a` 사용 시 세션 시작 사이의 초 단위 대기. RC 등록이 실패하면 늘리세요. |
| `HOME_SESSION_MODEL` | `""` | 홈 세션의 모델. 유효 값: `sonnet`, `haiku`, `opus`. 비어 있으면 Claude 기본값을 따릅니다. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | 다른 AI CLI 도구를 위해 `CLAUDE.md`의 심볼릭 링크로 생성할 파일의 공백 구분 목록. 비활성화하려면 `""`로 설정. |
| `LAUNCHAGENT_MODE` | `home` | 로그인 시 LaunchAgent 동작: `none`(아무것도 하지 않음) 또는 `home`(보호된 홈 세션 시작). 레거시 `LAUNCHAGENT_ENABLED=true`는 `home`으로 처리됩니다. |

**Tmux 세션 옵션** (모두 구성 가능, 모두 기본 활성화):

| 변수 | 기본값 | 설명 |
|----------|---------|-------------|
| `TMUX_MOUSE` | `true` | 마우스 지원 - 스크롤, 선택, 페인 크기 조정 |
| `TMUX_HISTORY_LIMIT` | `50000` | 스크롤백 버퍼 크기(라인 수, tmux 기본값은 2000) |
| `TMUX_CLIPBOARD` | `true` | OSC 52를 통한 시스템 클립보드 통합 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | 색상 렌더링을 위한 터미널 유형 |
| `TMUX_EXTENDED_KEYS` | `true` | Shift+Enter를 포함한 확장 키 시퀀스(tmux 3.2+ 필요) |
| `TMUX_ESCAPE_TIME` | `10` | Escape 키 지연(밀리초, tmux 기본값은 500) |
| `TMUX_TITLE_FORMAT` | `#S` | 터미널/탭 제목 형식 (`#S` = 세션 이름, 비활성화는 `""`) |
| `TMUX_MONITOR_ACTIVITY` | `true` | 다른 세션에 활동이 발생하면 알림 |

## 디렉터리 구조

프로젝트는 어떤 깊이에서든 `.claude/` 디렉터리의 존재로 검색됩니다:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ .claude/ 있음 - 관리됨
│   │   └── .claude/
│   ├── project-b/          # ✓ .claude/ 있음 - 관리됨
│   │   └── .claude/
│   └── -archived/          # ✗ 제외 (- 로 시작)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ .claude/ 있음 - 관리됨
│   │   └── .claude/
│   ├── .hidden/            # ✗ 제외 (숨김 디렉터리)
│   │   └── .claude/
│   └── project-d/          # ✗ .claude/ 없음 - Claude 프로젝트 아님
├── deep/nested/project-e/  # ✓ .claude/ 있음 - 어떤 깊이에서든 발견됨
│   └── .claude/
└── ignored-project/        # ✗ 제외 (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

세션 이름은 디렉터리 이름에서 파생됩니다: 공백은 하이픈이 되고, 영숫자가 아닌 문자(하이픈 제외)는 치환되며, 앞뒤 하이픈은 제거됩니다. 이름이 정제 후 비게 되는 디렉터리는 로그 경고와 함께 건너뜁니다.

## 세션 시스템 프롬프트

각 Claude 세션은 환경에 대한 컨텍스트를 담은 `--append-system-prompt`로 시작됩니다:

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
- When user says: ready — respond with "Session ready!" on one line. Nothing else.
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

(업데이트 라인은 업데이트가 가능한 경우에만 포함됩니다.)

`ALLOW_CROSS_SESSION_CONTROL=true`이면 send 명령이 자기 자신뿐 아니라 임의의 세션을 대상으로 지정할 수 있도록 변경됩니다. 경로는 시작 시점의 스크립트 절대 경로이므로 세션은 `PATH`에 의존하지 않습니다.

## CLI 참조

직접 사용할 일은 드뭅니다 - 세션 안에서 Claude가 대신 실행해 줍니다. 스크립트, 자동화, 또는 세션 밖에 있을 때 사용할 수 있습니다.

```bash
# 시작 및 연결
claude-mux                       # 현재 디렉터리에서 Claude 시작 후 연결
claude-mux ~/projects/my-app     # 디렉터리에서 Claude 시작 후 연결
claude-mux -d ~/projects/my-app  # 위와 동일 (명시적 형태)
claude-mux -t my-app             # 기존 tmux 세션에 연결

# 새 프로젝트 생성
claude-mux -n ~/projects/app     # 새 Claude 프로젝트 생성 후 연결
claude-mux -n ~/new/path/app -p  # 위와 동일하되 디렉터리 및 상위 경로 생성
claude-mux -n ~/app --template web        # 특정 CLAUDE.md 템플릿으로 새 프로젝트
claude-mux -n ~/app --no-multi-coder      # AGENTS.md/GEMINI.md 심볼릭 링크 없이 새 프로젝트

# 세션 관리
claude-mux -l                    # 상태별 세션 목록 (active, running, stopped)
claude-mux -L                    # 모든 프로젝트 목록 (active + idle)
claude-mux -L --hidden           # 숨겨진 프로젝트만 목록 표시
claude-mux -s my-app '/model sonnet'      # 세션에 슬래시 명령 전송
claude-mux --shutdown my-app              # 특정 세션 종료
claude-mux --shutdown                     # 관리 중인 모든 세션 종료
claude-mux --shutdown home --force        # 보호된 홈 세션 종료
claude-mux --restart my-app              # 특정 세션 재시작
claude-mux --restart                     # 실행 중인 모든 세션 재시작
claude-mux --permission-mode plan my-app  # plan 모드로 세션 재시작
claude-mux -a                    # BASE_DIR 아래 모든 관리 세션 시작

# 프로젝트 마커
claude-mux --hide                    # 현재 프로젝트를 -L 목록에서 숨기기
claude-mux --hide ~/projects/old     # 특정 프로젝트 숨기기
claude-mux --show                    # 현재 프로젝트 숨김 해제
claude-mux --protect                 # 이 세션을 실수로 종료되지 않도록 보호
claude-mux --unprotect               # 보호 해제
claude-mux --delete ~/projects/old           # 프로젝트 폴더를 시스템 휴지통으로 이동 (macOS)
claude-mux --delete ~/projects/old --yes     # 동일, 확인 프롬프트 건너뛰기

# 기타
claude-mux --commands            # 전체 CLI 참조 표시
claude-mux --config-help         # 기본값 및 설명과 함께 모든 설정 옵션 표시
claude-mux --list-templates      # 사용 가능한 CLAUDE.md 템플릿 표시
claude-mux --guide               # 세션 내에서 사용 가능한 대화형 명령 표시
claude-mux --install             # 대화형 설정: config + LaunchAgent
claude-mux --update              # 최신 버전으로 업데이트
claude-mux --dry-run             # 실행하지 않고 동작 미리 보기
claude-mux --version             # 버전 출력
claude-mux --help                # 모든 옵션 표시

# 로그 보기
tail -f ~/Library/Logs/claude-mux.log
```

터미널에서 실행하면 출력이 stdout에 실시간으로 미러링됩니다. LaunchAgent를 통해 실행하면 출력은 로그 파일로만 전송됩니다.

## 문제 해결

### 세션이 "Not logged in · Run /login"을 표시함

macOS 키체인이 잠겨 있을 때(로그인 후 키체인이 잠금 해제되기 전에 스크립트가 실행될 때 흔함) 첫 실행에서 발생합니다. 해결 방법:

```bash
# 일반 터미널에서 키체인 잠금 해제
security unlock-keychain

# 그런 다음 실행 중인 세션 하나에서 인증 완료
claude-mux -t <any-session>
# /login 실행 후 브라우저 흐름 완료
```

한 번 인증을 완료한 후 모든 세션을 종료하고 다시 실행하면 저장된 자격 증명을 자동으로 가져옵니다.

### 세션이 Claude Code Remote에 표시되지 않음

세션은 인증되어 있어야 합니다("Not logged in"이 표시되지 않은 상태). 깨끗하게 인증된 실행 후 몇 초 안에 RC 목록에 나타나야 합니다.

### tmux에서 여러 줄 입력

`/terminal-setup` 명령은 tmux 내에서 실행할 수 없습니다. claude-mux는 기본적으로 tmux `extended-keys`(`TMUX_EXTENDED_KEYS=true`)를 활성화하며, 이는 대부분의 최신 터미널에서 Shift+Enter를 지원합니다. Shift+Enter가 동작하지 않으면 프롬프트에서 `\` + Return으로 줄바꿈을 입력하세요.

### 세션 시작 시 "Ready."

세션이 시작되거나 재시작될 때 Claude가 로딩을 완료한 후 claude-mux가 자동으로 `ready` 메시지를 전송합니다. 주입 내용은 Claude에게 "Ready."만 응답하도록 지시합니다. 이를 통해 세션이 살아있고 주입이 동작 중임을 확인합니다.

### Remote Control을 통한 슬래시 명령

슬래시 명령(예: `/model`, `/clear`)은 RC 세션에서 [기본으로 지원되지 않습니다](https://github.com/anthropics/claude-code/issues/30674). claude-mux는 이를 우회합니다 - 각 세션에는 `claude-mux -s`가 주입되어 있어 Claude가 tmux를 통해 자기 자신에게 슬래시 명령을 보낼 수 있습니다.

## 로그

- `~/Library/Logs/claude-mux.log` - UTC 타임스탬프가 포함된 모든 스크립트 동작(`LOG_DIR`로 구성 가능)

저수준 LaunchAgent 디버깅에는 Console.app 또는 `log show`를 사용하세요.
