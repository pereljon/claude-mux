# FAQ

[English](../FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · **한국어** · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## claude-mux란 무엇인가요?

Claude Code를 tmux로 감싸 영구 세션을 제공하는 셸 스크립트입니다. 세션은 터미널을 닫아도 유지되고, 재시작 시 대화 컨텍스트를 재개하며, Remote Control을 통해 Claude 모바일 앱에서 접근할 수 있습니다. 세션 안에서 Claude와 대화하는 것으로 모든 것을 관리합니다.

## Linux에서 동작하나요?

아직 아닙니다. macOS 전용입니다(Apple Silicon 및 Intel). Linux 지원은 v2.0에서 계획되어 있습니다. 설치 스크립트는 Linux에서 실행되지만 LaunchAgent 설정을 건너뛰고 안내 메시지를 출력합니다. 바이너리 자체는 동작하지만, systemd 서비스나 이에 상응하는 자동 시작 메커니즘은 아직 없습니다.

## 홈 세션이란 무엇인가요?

홈 세션은 베이스 디렉터리(`~/Claude` 기본값)에 있는 범용 Claude 세션입니다. `LAUNCHAGENT_MODE=home`(기본값)이면 로그인 시 자동으로 시작되어 하루 종일 실행 상태를 유지합니다. 기본적으로 **보호** 상태이며, `--shutdown home`은 `--force` 없이는 중지를 거부합니다.

홈 세션은 Claude 모바일 앱에서 항상 접근 가능한 진입점으로 사용하세요. 여기서 프로젝트를 조회하고, 다른 세션을 시작하고, config를 관리하고, 특정 프로젝트에 속하지 않는 일반 작업을 수행할 수 있습니다.

## Remote Control이란 무엇인가요?

Remote Control(RC)은 Claude 모바일 앱이나 Claude Desktop에서 실행 중인 Claude 세션에 연결할 수 있는 Claude Code 기능입니다. claude-mux는 모든 세션을 `--remote-control`로 시작하므로 모든 세션이 자동으로 RC 목록에 표시됩니다. 연결되면 터미널에서와 동일하게 Claude와 대화합니다. claude-mux는 슬래시 명령이 기본으로 동작하지 않는 것과 같은 RC의 한계를 tmux를 통해 우회합니다.

## 권한 모드란 무엇인가요?

Claude Code에는 Claude의 자율성을 제어하는 네 가지 권한 모드가 있습니다:

| 모드 | 동작 |
|------|------|
| `default` | Claude가 명령 실행이나 파일 편집 전에 물어봄 |
| `acceptEdits` | Claude가 파일 편집을 자동 적용하지만 셸 명령 전에는 물어봄 |
| `plan` | Claude가 읽기와 계획만 가능, 쓰기나 명령 실행 불가 |
| `bypassPermissions` | Claude가 물어보지 않고 모든 것을 실행 (첫 실행 시 확인 필요) |

config의 `DEFAULT_PERMISSION_MODE`으로 모든 프로젝트의 기본값을 설정하세요. 실행 중인 세션을 전환하려면 "switch this session to plan mode"(또는 다른 모드 이름)라고 말하면 됩니다. "yolo"는 `bypassPermissions`의 별칭입니다.

다른 모드에서 `bypassPermissions`로 전환할 때는 Shift+Tab 탐색을 사용하며 재시작이 필요하지 않습니다. `bypassPermissions`에서 다른 모드로 전환할 때는 재시작이 필요하며, claude-mux가 자동으로 처리합니다.

## 세션을 초기화하려면 어떻게 하나요?

원하는 결과에 따라 세 가지 옵션이 있습니다:

- **Clear** ("clear this session"): 세션에 `/clear`를 전송합니다. 대화 기록을 지우고 새로 시작합니다. 세션은 계속 실행됩니다.
- **Compact** ("compact this session"): 세션에 `/compact`를 전송합니다. 대화를 짧은 컨텍스트로 요약하여 컨텍스트 윈도우를 확보합니다. 기록은 압축된 형태로 보존됩니다.
- **Restart** ("restart this session"): Claude를 종료하고 `claude -c`로 다시 시작하여 마지막 대화를 재개합니다. 권한 모드 변경 후나 Claude가 멈췄을 때처럼 깨끗한 프로세스가 필요할 때 사용하세요.

## 템플릿이란 무엇인가요?

템플릿은 `~/.claude-mux/templates/`에 저장된 재사용 가능한 CLAUDE.md 파일입니다. `-n`으로 새 프로젝트를 만들 때 기본 템플릿(또는 `--template NAME`으로 지정한 템플릿)이 프로젝트의 CLAUDE.md로 복사됩니다.

템플릿 만들기: "save this as a template named web" (현재 프로젝트의 CLAUDE.md를 `~/.claude-mux/templates/web.md`로 복사합니다).

템플릿 사용하기: `claude-mux -n ~/projects/my-app --template web` 또는 세션 안에서: "create a new project called my-app using the web template".

템플릿 목록 보기: "list templates" 또는 `claude-mux --list-templates`.

## 오늘의 팁은 어떻게 동작하나요?

각 프로젝트의 `.claude/settings.local.json`에 있는 Claude Code Stop 훅이 대화 턴마다 `claude-mux --tipotd`를 호출합니다. 이 명령은 오늘 이미 팁이 표시되었는지(`~/.claude-mux/.tip-date`를 통해) 확인합니다. 이미 표시되었으면 약 6ms 만에 종료합니다. 아직 표시되지 않았으면 팁을 출력하고 오늘 날짜를 기록합니다.

팁은 기본적으로 활성화되어 있습니다(`TIP_OF_DAY=true`). 세션 안에서 "enable tips" 또는 "disable tips"로 전환하세요. `TIP_MODE=daily`는 하루 종일 같은 팁을 보여주고, `TIP_MODE=random`은 호출 시마다 무작위 팁을 선택합니다(Stop 훅과 함께 사용하면 일일 게이트로 인해 하루에 무작위 팁 하나).

`--tip` 명령은 일일 게이트와 관계없이 항상 동작하므로 언제든 "tip"이라고 말할 수 있습니다.

## 여러 GitHub 계정과 함께 사용할 수 있나요?

네. claude-mux는 `~/.ssh/config`에서 `Host github.com-*` 항목을 감지하고 각 세션의 시스템 프롬프트에 주입합니다. Claude는 어떤 SSH 별칭이 사용 가능한지 알고 git remote를 설정할 때 올바른 것을 사용할 수 있습니다.

`~/.ssh/config` 설정 예시:

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

Claude는 업무용 저장소에 `git@github.com-work:org/repo.git`을, 개인 저장소에 `git@github.com-personal:user/repo.git`을 사용해야 한다는 것을 알게 됩니다.

## 상태는 어디에 저장되나요?

| 위치 | 내용 |
|------|------|
| `~/.claude-mux/config` | 사용자 설정 (bash로 소스됨) |
| `~/.claude-mux/templates/` | CLAUDE.md 템플릿 파일 |
| `~/.claude-mux/.tip-date` | 마지막 팁 표시 날짜 |
| `~/.claude-mux/.update-check` | 캐시된 버전 확인 결과 |
| `~/Library/Logs/claude-mux.log` | 로그 파일 (`LOG_DIR`로 설정 가능) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | LaunchAgent plist (`--install`로 생성) |
| `.claudemux-protected` (프로젝트별) | 세션을 종료 보호로 표시 |
| `.claudemux-ignore` (프로젝트별) | 프로젝트를 목록에서 숨김 |

마커 파일(`.claudemux-*`)은 각 프로젝트의 루트 디렉터리에 있으며 이름 변경, 이동, 동기화 시에도 폴더와 함께 이동합니다. `.gitignore`에 자동으로 추가됩니다.

대화 기록은 Claude Code 자체에서 관리하며 `~/.claude/projects/`에 저장됩니다.

## claude-mux를 포크한 경우 자동 업데이트는 어떻게 되나요?

업데이트 확인과 `--update` 명령은 GitHub 저장소로 `pereljon/claude-mux`를 하드코딩합니다. 포크하면 업데이트 확인은 여전히 업스트림 릴리스와 비교하며, `--update`는 포크의 바이너리를 업스트림으로 덮어씁니다. `~/.claude-mux/config`에서 `UPDATE_CHECK=false`로 설정하여 비활성화하거나, 스크립트의 `check_for_update()`와 `do_update()` 함수에서 저장소 URL을 변경하세요.

## Homebrew로 설치하려면 어떻게 하나요?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

`brew upgrade claude-mux`로 업데이트하세요. 참고: Homebrew로 설치한 경우 `--update`는 자동으로 `brew upgrade`에 위임합니다.

## `claude --worktree --tmux`와 어떻게 다른가요?

`claude --worktree --tmux`는 격리된 git worktree를 위한 tmux 세션을 만들며, 병렬 코딩 작업을 위해 설계되었습니다. claude-mux는 실제 프로젝트 디렉터리를 위한 영구 세션을 관리하며, Remote Control 활성화, 자체 관리를 위한 시스템 프롬프트 주입, 대화 재개, 세션 생명주기 관리를 함께 제공합니다. 서로 다른 문제를 해결합니다.

## 세션이 "Not logged in"을 표시하는 이유는 무엇인가요?

macOS 키체인이 잠겨 있을 때 첫 실행에서 발생합니다. 로그인 후 키체인을 잠금 해제하기 전에 LaunchAgent가 시작될 때 흔합니다. 일반 터미널에서 `security unlock-keychain`을 실행한 후, 세션에 연결(`claude-mux -t <name>`)하여 `/login`으로 브라우저 인증을 완료하세요. 그 후 모든 세션을 재시작하면 저장된 자격 증명을 가져옵니다.

## 여러 터미널이 같은 세션에 연결할 수 있나요?

네. 이것은 표준 tmux 동작입니다. 이미 실행 중인 세션이 있는 디렉터리에서 `claude-mux`를 실행하면 해당 세션에 연결됩니다. 여러 터미널이 같은 세션 내용을 실시간으로 볼 수 있습니다.

## 홈 세션을 영구적으로 중지하려면 어떻게 하나요?

LaunchAgent에 `KeepAlive: true`가 설정되어 있으므로 홈 세션을 종료하면 약 60초 내에 다시 시작됩니다. 영구적으로 중지하려면 LaunchAgent를 비활성화하세요:

```bash
claude-mux --install --launchagent-mode none
```

## "Session ready!" 메시지는 무엇을 의미하나요?

세션이 시작되거나 재시작될 때, claude-mux는 Claude가 로딩을 완료한 후 `Ready?` 프롬프트를 전송합니다. 주입 내용은 Claude에게 "Session ready!"만 응답하도록 지시합니다. 이를 통해 세션이 살아있고 시스템 프롬프트 주입이 동작 중임을 확인합니다. 무시해도 됩니다.

## 프로젝트를 목록에서 숨기려면 어떻게 하나요?

세션 안에서 "hide this project"라고 말하거나 `claude-mux --hide my-project`를 실행하세요. `.claudemux-ignore` 마커 파일이 생성됩니다. 프로젝트가 `claude-mux -L` 출력에 나타나지 않습니다. 숨겨진 프로젝트를 보려면: `claude-mux -L --hidden`. 숨김 해제: "show this project" 또는 `claude-mux --show my-project`.

## claude-mux를 제거하려면 어떻게 하나요?

```bash
claude-mux --uninstall
```

모든 프로젝트에서 팁 훅과 권한 규칙을 제거하고, LaunchAgent를 언로드하며, 선택적으로 `~/.claude-mux/`를 제거합니다. 바이너리 경로를 보고하므로 수동으로 삭제할 수 있습니다(Homebrew로 설치한 경우 `brew uninstall claude-mux`).

## Remote Control에서 슬래시 명령이 동작하나요?

기본적으로는 안 됩니다. Claude Code는 RC 세션에서 슬래시 명령(`/model`, `/clear` 등)을 지원하지 않습니다. claude-mux는 각 세션에 `claude-mux -s`를 주입하여 Claude가 tmux를 통해 자기 자신에게 슬래시 명령을 보낼 수 있도록 우회합니다. "switch to Haiku"나 "compact this session"이라고 말하면 Claude가 처리합니다.

## 세션에서 텍스트를 선택할 수 없어요

클릭하고 드래그할 때 **Option** (macOS) 또는 **Shift** (Linux/Windows 터미널)를 누르세요. 이렇게 하면 tmux의 마우스 캡처를 우회하고 선택 내용을 시스템 클립보드에 복사합니다. 설정 변경이 필요하지 않습니다.

## 대화형 명령은 어떤 언어를 지원하나요?

모든 언어를 지원합니다. 트리거 문구("help", "status", "list sessions" 등)는 어떤 언어로든 동작합니다. Claude가 사용자의 자연어에서 의도를 파악하고 해당 명령을 실행합니다. README도 12개 언어로 번역되어 있습니다.
