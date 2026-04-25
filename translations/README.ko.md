# claude-mux - Claude Code 멀티플렉서

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · **한국어** · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

> 참고: 이 번역은 영어 README보다 뒤처질 수 있습니다. 정식 버전은 [README.md](../README.md)를 참조하세요.

모든 프로젝트를 위한 영구 Claude Code 세션 - Claude 모바일 앱을 통해 어디서나 접근 가능합니다.

Claude Code를 tmux 내부에서 실행하는 셸 스크립트로, Remote Control 활성화, 대화 재개, 세션 자체 관리(세션 목록 조회, 슬래시 명령 전송, 새 프로젝트 시작, 종료 또는 재시작) 기능을 제공합니다. 어떤 디렉터리에서든 `claude-mux`를 실행하면 휴대폰에서 접근할 수 있는 영구 세션이 생성됩니다.

## 빠른 시작

```bash
./install.sh
```

```bash
claude-mux ~/path/to/your/project
```

또는 프로젝트 디렉터리로 `cd`한 후 다음을 실행합니다:

```bash
claude-mux
```

이게 전부입니다 - Remote Control이 활성화된 영구적이고 세션 인식이 가능한 Claude 세션에 진입한 상태입니다.

claude-mux는 tmux와 Claude Code 외에 의존성이 없는 단일 bash 스크립트입니다.

## 기능

1. **Remote Control이 적용된 영구 tmux 세션** - Claude Code를 tmux 내부에서 `--remote-control`이 활성화된 상태로 실행하므로 모든 세션을 Claude 모바일 앱에서 접근할 수 있습니다
2. **대화 재개** - 해당 디렉터리에서 Claude가 이전에 실행된 적이 있다면 Remote Control이 적용된 새 tmux 세션 내에서 마지막 대화를 재개(`claude -c`)하여 컨텍스트를 보존합니다
3. **세션 관리** - 활성 세션 목록 조회(`-l`) 또는 아직 실행되지 않은 유휴 프로젝트를 포함한 모든 프로젝트 조회(`-L`), 종료(`--shutdown`), 재시작(`--restart`), 권한 모드 전환(`--permission-mode`), 연결(`-t`), 세션에 슬래시 명령 전송(`-s`)
4. **Claude 자체 관리** - 각 세션에는 시스템 프롬프트가 주입되어 있어, Claude가 위 명령들을 대화 프롬프트(터미널 또는 모바일 앱)에서 직접 실행할 수 있습니다:
   - a. 실행 중인 세션 및 모든 프로젝트 목록 조회
   - b. 새 세션 시작, 새 프로젝트 생성
   - c. 자기 자신 또는 다른 세션에 슬래시 명령 전송 ([RC에서 슬래시 명령이 기본으로 동작하지 않는 문제](https://github.com/anthropics/claude-code/issues/30674)에 대한 우회 방법)
   - d. 세션 종료, 재시작, 또는 권한 모드 전환
5. **홈 세션** - 베이스 디렉터리에서 항상 실행되는 가벼운 세션으로 로그인 시 시작됩니다(`LAUNCHAGENT_MODE`로 구성 가능). Claude 모바일 앱에서 Remote Control을 항상 사용 가능하도록 유지하며 다른 모든 세션을 관리할 수 있습니다. 실수로 종료되지 않도록 보호됩니다.
6. **새 프로젝트 생성** - `claude-mux -n DIRECTORY`는 git, `.gitignore`, 권한 모드가 설정된 코딩 준비 완료 프로젝트를 생성합니다(`-p`는 디렉터리가 없으면 생성). 실행 중인 어떤 세션이라도 새 프로젝트를 생성할 수 있습니다 - Claude에게 GitHub 계정 중 하나에 리포지토리를 설정하고 어디서든 코딩을 시작하도록 요청하세요
7. **CLAUDE.md 템플릿** - `~/.claude-mux/templates/`에 CLAUDE.md 지침 파일 라이브러리(예: `web.md`, `python.md`, `default.md`)를 유지하고 새 프로젝트에 자동 적용합니다. `--template NAME`으로 특정 템플릿을 선택하거나 기본값을 사용할 수 있습니다
8. **SSH 계정 인식** - `~/.ssh/config`의 GitHub SSH 호스트 별칭을 주입하여 Claude가 git 작업에 어떤 계정을 사용할 수 있는지 알 수 있도록 합니다
9. **자동 승인 권한** - claude-mux는 각 프로젝트의 `.claude/settings.local.json` 허용 목록에 자신을 추가하므로 Claude가 권한 요청 없이 claude-mux 명령을 실행할 수 있습니다
10. **떠도는 프로세스 마이그레이션** - 대상 디렉터리에서 Claude가 tmux 외부에서 이미 실행 중이라면 종료시키고 관리 대상 tmux 세션 내부에서 다시 시작합니다(대화는 `claude -c`로 재개됩니다)
11. **Tmux 사용성 개선** - 마우스 지원, 50k 스크롤백 버퍼, 클립보드 통합, 256-color, 단축된 escape 지연, 확장 키(Shift+Enter), 활동 모니터링, 터미널 탭 제목이 구성된 세션 - 모두 `~/.claude-mux/config`에서 구성 가능

> **참고:** 이는 격리된 git worktree에 대해 tmux 세션을 만드는 `claude --worktree --tmux`와는 다릅니다. claude-mux는 실제 프로젝트 디렉터리에 대해 영구 세션을 관리하며, Remote Control과 시스템 프롬프트 주입을 함께 제공합니다.

### 홈 세션

`$BASE_DIR`에 존재하는 단일 범용 세션입니다. `LAUNCHAGENT_MODE=home`이면 로그인 시 자동으로, 또는 `$BASE_DIR`에서 `claude-mux`를 수동 실행하여 시작합니다. 모든 프로젝트마다 세션을 띄우지 않아도 휴대폰에서 항상 사용 가능한 Claude 세션 하나를 제공합니다.

홈 세션은 항상 **보호** 상태입니다 - 어떻게 시작했든 `--shutdown home`은 `--force` 없이는 중지를 거부합니다. 보호된 세션은 `-l`/`-L` 출력에서 `*`로 표시됩니다(예: `active*`).

## 요구 사항

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## 설치

```bash
./install.sh
```

대화형 설치 프로그램은 Claude 프로젝트가 어디에 있는지, 로그인 시 홈 세션을 시작할지, 어떤 모델을 사용할지 묻습니다. `claude-mux`를 `~/bin`에 설치하고 `~/.claude-mux/config`를 생성하며 LaunchAgent를 설정합니다.

프롬프트를 건너뛰고 기본값을 사용하려면 `--non-interactive`를 사용하세요.

옵션:

```bash
./install.sh --non-interactive                     # 프롬프트 건너뛰기, 기본값 사용
./install.sh --base-dir ~/work/claude              # 다른 베이스 디렉터리 사용
./install.sh --launchagent-mode none               # LaunchAgent 동작 비활성화
./install.sh --home-model haiku                    # 홈 세션에 Haiku 사용
./install.sh --no-launchagent                      # LaunchAgent 설치 전부 건너뛰기
```

LaunchAgent는 시스템 서비스 초기화를 위해 45초의 시작 지연을 두고 로그인 시 `claude-mux --autolaunch`를 실행합니다.

## 사용법

```bash
claude-mux                       # 현재 디렉터리에서 Claude 실행 후 연결
claude-mux ~/projects/my-app     # 디렉터리에서 Claude 실행 후 연결
claude-mux -d ~/projects/my-app  # 위와 동일 (명시적 형태)
claude-mux -a                    # BASE_DIR 아래 모든 관리 세션 시작
claude-mux -n ~/projects/app     # 새 Claude 프로젝트 생성 후 연결
claude-mux -n ~/new/path/app -p  # 위와 동일하되 디렉터리 및 상위 경로 생성
claude-mux -n ~/app --template web  # 특정 CLAUDE.md 템플릿으로 새 프로젝트
claude-mux --list-templates      # 사용 가능한 CLAUDE.md 템플릿 표시
claude-mux -t my-app             # 기존 tmux 세션에 연결
claude-mux -s my-app '/model sonnet' # 세션에 슬래시 명령 전송
claude-mux -l                    # 상태별 세션 목록 (active, running, stopped)
claude-mux -L                    # 모든 프로젝트 목록 (active + idle)
claude-mux --shutdown            # 모든 관리 Claude 세션 정상 종료
claude-mux --shutdown my-app     # 특정 세션 종료
claude-mux --shutdown a b c      # 여러 세션 종료
claude-mux --shutdown home --force  # 보호된 홈 세션 종료
claude-mux --restart             # 실행 중이던 세션 재시작
claude-mux --restart my-app      # 특정 세션 재시작
claude-mux --restart a b c       # 여러 세션 재시작
claude-mux --permission-mode plan my-app    # plan 모드로 세션 재시작
claude-mux --permission-mode dangerously-skip-permissions my-app  # yolo 모드
claude-mux --dry-run             # 실행하지 않고 동작 미리 보기
claude-mux --version             # 버전 출력
claude-mux --help                # 모든 옵션 표시
claude-mux --guide               # 세션 내에서 사용 가능한 대화형 명령 표시

# 로그 보기
tail -f ~/Library/Logs/claude-mux.log
```

터미널에서 실행하면 출력이 stdout에 실시간으로 미러링됩니다. LaunchAgent를 통해 실행하면 출력은 로그 파일로만 전송됩니다.

## 세션 상태

| 상태 | 의미 |
|--------|---------|
| `active` | tmux 세션이 존재하고 Claude가 실행 중이며 로컬 tmux 클라이언트가 연결되어 있음 |
| `running` | tmux 세션이 존재하고 Claude가 실행 중임 (로컬 클라이언트 연결 없음) |
| `stopped` | tmux 세션은 존재하지만 Claude가 종료됨 |
| `idle` | `BASE_DIR` 아래에 `.claude/` 프로젝트가 존재하지만 claude-mux tmux 세션이 실행되지 않음 (`-L`에서만 표시) |

상태 뒤의 `*`는 세션이 보호되어 있어 종료에 `--force`가 필요함을 나타냅니다(예: `active*`, `running*`). 홈 세션은 항상 보호됩니다.

이미 실행 중인 세션이 있는 디렉터리에서 `claude-mux`를 실행하면 해당 세션에 연결됩니다. 여러 터미널이 같은 세션에 연결할 수 있습니다(표준 tmux 동작).

## Claude 프롬프트 예시

각 세션에 claude-mux 명령이 주입되어 있으므로 터미널이나 모바일 앱의 대화 프롬프트에서 세션을 직접 관리할 수 있습니다:

```
사용자: "어떤 세션이 실행 중이야?"
Claude: `claude-mux -l`을 실행하고 결과를 표시합니다

사용자: "모든 프로젝트를 보여줘"
Claude: `claude-mux -L`을 실행하고 결과를 표시합니다

사용자: "내 api-server 업무 프로젝트를 위한 세션을 시작해줘"
Claude: `claude-mux -d ~/Claude/work/api-server --no-attach`를 실행합니다

사용자: "mobile-app이라는 새 개인 프로젝트를 만들어줘"
Claude: `claude-mux -n ~/Claude/personal/mobile-app -p --no-attach`를 실행합니다

사용자: "어떤 템플릿이 있어?"
Claude: `claude-mux --list-templates`를 실행하고 결과를 표시합니다

사용자: "web 템플릿을 사용해서 api-server라는 새 업무 프로젝트를 만들어줘"
Claude: `claude-mux -n ~/Claude/work/api-server -p --template web --no-attach`를 실행합니다

사용자: "모든 세션을 Sonnet으로 전환해줘"
Claude: 실행 중인 각 세션에 대해 `claude-mux -s SESSION '/model sonnet'`을 실행합니다

사용자: "data-pipeline 세션을 종료해줘"
Claude: `claude-mux --shutdown data-pipeline`을 실행합니다

사용자: "멈춘 web-dashboard 세션을 재시작해줘"
Claude: `claude-mux --restart web-dashboard`를 실행합니다

사용자: "api-server 세션을 plan 모드로 전환해줘"
Claude: `claude-mux --permission-mode plan api-server`를 실행합니다

사용자: "data-pipeline 세션을 yolo로 돌려줘"
Claude: `claude-mux --permission-mode dangerously-skip-permissions data-pipeline`을 실행합니다

사용자: "data-pipeline 세션을 백그라운드로 시작해줘"
Claude: `claude-mux -d ~/Claude/work/data-pipeline --no-attach`를 실행합니다

사용자: "내 모든 프로젝트를 시작해줘"
Claude: `claude-mux -a`를 실행합니다 (확인 후 - 모든 관리 프로젝트가 시작됩니다)
```

## 구성

처음 실행할 때 모든 설정이 주석 처리된 상태로 `~/.claude-mux/config`가 자동 생성됩니다. 기본값을 재정의하려면 이 파일을 편집하세요 - 스크립트 자체는 절대 수정할 필요가 없습니다.

| 변수 | 기본값 | 설명 |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Claude 프로젝트(즉 `.claude/`를 포함한 디렉터리)를 검색할 루트 디렉터리 |
| `LOG_DIR` | `$HOME/Library/Logs` | `claude-mux.log` 파일을 위한 디렉터리 |
| `DEFAULT_PERMISSION_MODE` | `auto` | 각 프로젝트에서 Claude의 `permissions.defaultMode`를 설정. 유효 값: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. 비활성화하려면 `""`로 설정. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | `true`일 때 Claude 세션이 다른 세션에 슬래시 명령을 보낼 수 있음 - 멀티 에이전트 오케스트레이션에 유용 |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | CLAUDE.md 템플릿 파일을 포함하는 디렉터리 |
| `DEFAULT_TEMPLATE` | `default.md` | 새 프로젝트(`-n`)에 적용되는 기본 템플릿. 비활성화하려면 `""`로 설정. |
| `SLEEP_BETWEEN` | `5` | `-a` 사용 시 세션 시작 사이의 초 단위 대기. RC 등록이 실패하면 늘리세요. |
| `HOME_SESSION_MODEL` | `""` | 홈 세션의 모델. 유효 값: `sonnet`, `haiku`, `opus`. 비어 있으면 Claude 기본값을 따릅니다. |
| `LAUNCHAGENT_MODE` | `home` | 로그인 시 LaunchAgent 동작: `none`(아무 것도 하지 않음) 또는 `home`(보호된 홈 세션 시작). 레거시 `LAUNCHAGENT_ENABLED=true`는 `home`으로 처리됩니다. |

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
└── ignored-project/        # ✗ 제외 (.ignore-claudemux)
    ├── .claude/
    └── .ignore-claudemux
```

세션 이름은 디렉터리 이름에서 파생됩니다: 공백은 하이픈이 되고, 영숫자가 아닌 문자(하이픈 제외)는 치환되며, 앞뒤 하이픈은 제거됩니다. 이름이 정제 후 비게 되는 디렉터리는 로그 경고와 함께 건너뜁니다.

## 세션 시스템 프롬프트

각 Claude 세션은 환경에 대한 컨텍스트를 담은 `--append-system-prompt`로 시작됩니다:

```
You are running inside tmux session '<session-name>'.
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
  -a                          Start ALL sessions (use with caution)

GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

`ALLOW_CROSS_SESSION_CONTROL=true`이면 send 명령이 자기 자신뿐 아니라 임의의 세션을 대상으로 지정할 수 있도록 변경됩니다. 경로는 시작 시점의 스크립트 절대 경로이므로 세션은 `PATH`에 의존하지 않습니다.

## 문제 해결

### 세션이 "Not logged in · Run /login"을 표시함

이는 macOS 키체인이 잠겨 있을 때(스크립트가 로그인 후 키체인이 잠금 해제되기 전에 실행될 때 흔함) 첫 실행에서 발생합니다. 해결:

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

### Remote Control을 통한 슬래시 명령

슬래시 명령(예: `/model`, `/clear`)은 RC 세션에서 [기본으로 지원되지 않습니다](https://github.com/anthropics/claude-code/issues/30674). claude-mux는 이를 우회합니다 - 각 세션에는 `claude-mux -s`가 주입되어 있어 Claude가 tmux를 통해 자기 자신에게 슬래시 명령을 보낼 수 있습니다.

## 로그

- `~/Library/Logs/claude-mux.log` - UTC 타임스탬프가 포함된 모든 스크립트 동작(`LOG_DIR`로 구성 가능)

저수준 LaunchAgent 디버깅에는 Console.app 또는 `log show`를 사용하세요.
