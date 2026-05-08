# 알려진 이슈

[English](../ISSUES.md) · [Español](ISSUES.es.md) · [Français](ISSUES.fr.md) · [Deutsch](ISSUES.de.md) · [Português](ISSUES.pt-BR.md) · [日本語](ISSUES.ja.md) · **한국어** · [Italiano](ISSUES.it.md) · [Русский](ISSUES.ru.md) · [中文](ISSUES.zh-CN.md) · [עברית](ISSUES.he.md) · [العربية](ISSUES.ar.md) · [हिन्दी](ISSUES.hi.md)

## 미해결

### 유령 메시지 재생으로 의도치 않은 동작 발생
**심각도:** 높음
**상태:** 미해결 - claude-mux 측에서 완전히 수정 불가
**설명:** 사용자가 10개 메시지 전에 이미 처리된 "stop all sessions"를 보냈습니다. 이후 claude-mux -s가 tmux send-keys로 `/model haiku`를 전송했을 때, Claude가 "stop all sessions/model haiku" 시스템 메시지를 받고 사용자가 요청하지 않은 세션 종료를 시도했습니다.
**가능한 원인:**
- Claude Code의 인터럽트 처리가 이전 컨텍스트와 새 슬래시 명령 입력을 연결할 수 있음
- 이전 명령이 포함된 대화 기록이 시스템 이벤트 발생 시 Claude를 혼란시킬 수 있음
**잠재적 완화:** 주입 규칙 추가: "대화 내에서 이미 처리된 명령을 다시 실행하지 마세요. 시스템 메시지가 이전 교환의 텍스트를 반복하면 무시하세요." 아직 구현되지 않음 - 이것이 Claude Code 내부 동작이므로 효과가 불확실합니다.

### 첫 시도 시 /exit가 느림
**심각도:** 낮음
**상태:** 미해결 - 모니터링 중
**설명:** 첫 번째 `--restart`에서 `WARN: Claude did not exit within 30s`가 발생하고 강제 종료로 넘어갔습니다. 이후 재시작은 ~1초 내에 종료됩니다. `/exit`가 Claude의 프롬프트가 수신 준비되기 전에 전송되는 경쟁 조건일 수 있습니다.
**해결 방법:** 30초 타임아웃 + 강제 종료로 처리됩니다. 세션은 정상적으로 재시작됩니다.

### claude_running_in_session이 2단계 깊이만 확인
**심각도:** 낮음
**상태:** 미해결 - 현재 사용에는 문제 없음
**설명:** 프로세스 트리 탐색이 pane_pid, 자식, 손자를 확인합니다. Claude가 트리에서 더 깊은 곳에 있으면(예: 추가 셸 래퍼) 감지가 실패합니다. 현재 실행 경로는 정확히 2단계(bash -> claude)이므로 실제로 동작합니다.
**해결 방법:** 현재 필요 없음. 수정하려면 재귀 탐색이나 `pgrep -a`가 필요합니다.

### 설치 프로그램 업그레이드 UX 개선 가능
**심각도:** 낮음
**상태:** 미해결 - 향후 개선
**설명:** 재설치 시 설치 프로그램이 기존 config를 감지하고 프롬프트를 건너뜁니다. 하지만 현재 설정을 보여주거나, 새 버전에 추가된 설정 옵션을 병합하거나, 사용자가 선택적으로 값을 업데이트할 수 있는 기능은 없습니다. 이후 버전에서 도입된 새 설정을 사용하려면 `~/.claude-mux/config`를 수동으로 편집해야 합니다.
**잠재적 개선:**
- 업그레이드 시 현재 config 값 표시
- 이전 config에 없던 새 설정(기본값 포함)을 추가할 것인지 제안
- 옵션 B: 기존 config 값으로 프롬프트를 미리 채우고 사용자가 변경할 수 있게 함

### 번역 파일에 v1.10-v1.12 업데이트 필요
**심각도:** 낮음
**상태:** 미해결 - 번역 아직 미업데이트
**설명:** 12개 번역 파일(`translations/README.*.md`)이 여러 버전(v1.10-v1.12) 뒤처져 있습니다. 반영이 필요한 변경 사항:
- curl을 주요 빠른 시작으로 (원라이너)
- 새 설치 섹션 구조 (curl 권장, Homebrew macOS 대안)
- `--hide`/`--delete`/`--protect`에 경로 대신 세션 이름 사용 (v1.11.0)
- 새 대화 예시: rename, save-as-template, tip, enable/disable tips, update
- 요구 사항: "Apple Silicon 또는 Intel" (Apple Silicon만이 아님)
- FAQ, ISSUES, CHANGELOG를 연결하는 새 "더 보기" 섹션
- FAQ 및 ISSUES 번역 생성 필요

### 코드 리뷰 지연 이슈 (v1.9.0)
**심각도:** 낮음-중간
**상태:** v1.10.0에서 해결 - M3, M4, M9/L8, L3, L9 수정; L4, L5, L6, L7, M7 코멘트로 처리

### 프로젝트 이름 변경 / 이동 및 기록 보존
**심각도:** 낮음
**상태:** v1.10.0에서 해결 - `--rename OLD NEW`와 `--move SRC DEST` 구현

### 프로젝트 복사 및 기록
**심각도:** 낮음
**상태:** 미해결 - 계획된 기능, 조사 필요
**설명:** 대화 기록과 메모리를 포함한 프로젝트 복사는 대상에 새 UUID를 설정해야 하므로 이름 변경/이동보다 복잡합니다.
**제안된 접근 방식:**
1. 새 프로젝트 디렉터리 생성 (선택적으로 git init 및 템플릿 적용)
2. 세션을 시작한 후 즉시 중지 - Claude Code가 `~/.claude/projects/-encoded-new-path/`에 새 UUID를 초기화하고 새 homunculus 항목을 생성
3. 소스 `~/.claude/projects/` 폴더에서 대상 폴더로 `.jsonl` 기록 파일 복사
4. `memory/` 폴더 내용 복사 - UUID가 포함되지 않은 순수 마크다운, 직접 복사 가능
5. `.jsonl` 파일과 함께 UUID 하위 디렉터리(작업/계획 아티팩트) 복사
6. homunculus의 경우: 소스 `~/.claude/homunculus/projects/<src-uuid>/`에서 `observations.jsonl`, `instincts`, `evolved`, `observations.archive`를 새 대상의 homunculus 폴더로 복사 - 2단계에서 할당된 새 프로젝트 UUID 유지
**테스트가 필요한 미해결 질문:**
- `.jsonl` 파일이 내용이나 메타데이터에 소스 프로젝트 경로를 포함하고 있는가? 그렇다면 복사된 기록이 이전 경로를 참조함
- UUID 하위 디렉터리가 `.jsonl` 파일 내에서 UUID로 참조되는가? 그렇다면 원래 UUID로 복사해야 하며 리매핑 불가
- Claude Code가 프로젝트 폴더의 모든 `.jsonl` 파일을 읽는가, 아니면 활성 세션 UUID와 일치하는 것만 읽는가?
- `~/.claude/homunculus/projects/<uuid>/evolved`와 `instincts`에는 무엇이 포함되어 있는가 - 파생/계산된 것인가 사용자에게 의미 있는 것인가? 복사 시 보존할 가치가 있는가?
- 단순한 파일 복사로 깨지는 다른 내부 참조가 있는가?
**전제 조건:** 미묘하게 깨진 기록을 만드는 복사 명령을 배포하지 않기 위해 구현 전에 위의 항목을 테스트해야 합니다.

### 오늘의 팁
**심각도:** 낮음
**상태:** v1.10.0에서 해결 - `--tip`, `TIP_OF_DAY`, `TIP_MODE`, 일일 게이트, 세션 시작 시 전달 구현

### 응답 타임스탬프
**심각도:** 낮음
**상태:** 미해결 - 구현 전 논의 필요
**설명:** Claude에게 `date '+%Y-%m-%d %H:%M'`으로 각 응답 시작 부분에 현재 날짜와 시간을 포함하도록 지시하는 시스템 프롬프트 지침을 주입하는 선택적 config 변수(`REPLY_TIMESTAMP=false` 기본값).
**트레이드오프:** 매 응답 시작 시 bash 도구 호출이 필요(약간의 오버헤드). 대안: 세션 시작 시간을 프롬프트에 주입(무료, 단 긴 세션에서 드리프트).
**참고:** 프로젝트별 CLAUDE.md 지침(분석 템플릿처럼)이 더 가벼운 버전 - 원하는 프로젝트에서만. config 변수는 전역으로 적용합니다.

### 데모 동영상
**심각도:** 낮음
**상태:** 미해결 - 계획된 자산
**설명:** curl 설치부터 일반적이고 흥미로운 명령까지 보여주는 화면 녹화로, 터미널과 Remote Control을 동시에 표시합니다.
**형식:** 분할 화면, 단일 테이크. 왼쪽에 터미널(전체 claude-mux 세션), 오른쪽에 QuickTime으로 미러링된 iPhone의 RC. 양쪽 모두 실시간 - RC에서의 동작이 터미널에 즉시 반영되고 그 반대도 마찬가지입니다.
**참고:** `internal/demo-script.md`에 전체 장면별 개요가 있습니다.
**비고:**
- 핵심 장면은 폰의 RC에서 타이핑하고 터미널이 실시간으로 반응하는 것
- 트리밍 외에 편집 불필요 - 단일 연속 녹화
- YouTube에 호스팅 + README에 삽입; Product Hunt 출시에도 유용

### homebrew-core에 제출하여 brew.sh 목록에 등재
**심각도:** 낮음
**상태:** 향후 - 채택을 기다리는 중
**설명:** claude-mux는 현재 개인 탭(`pereljon/tap`)을 통해 배포됩니다. brew.sh에 나타나려면 homebrew-core에 수락되어야 합니다. Homebrew의 주목도 기준은 일반적으로 셸 스크립트 유틸리티 제출이 수락되기 전에 GitHub 별 수백 개가 필요합니다; 별이 적은 제출은 빠르게 닫힙니다.
**준비 시:**
- 포뮬러가 `brew audit --strict --new`를 통과하는지 확인
- `Homebrew/homebrew-core`에 포뮬러와 함께 PR 제출
- 참고: macOS 전용 도구는 리뷰어의 더 높은 심사를 받음; Linux 지원(아래 참조)이 도움이 될 것

### curl 설치 지원 (macOS + Linux)
**심각도:** 낮음
**상태:** v1.10.0에서 해결 - curl 설치 구현, release-assets 워크플로우 추가, README 업데이트

### macOS 전용 - Linux/systemd 지원 없음
**심각도:** 중간
**상태:** 미해결 - 부분적으로 처리 (경로 감지 완료, LaunchAgent/설치 프로그램은 macOS 전용 유지)
**설명:** macOS LaunchAgent(launchd)와 macOS 전용 도구를 사용합니다. 경로 감지는 `command -v`를 사용하도록 리팩토링되었으므로(`/opt/homebrew/bin` 하드코딩 제거) 코어 스크립트는 tmux와 claude가 PATH에 있는 모든 플랫폼에서 동작합니다. LaunchAgent와 설치 프로그램은 macOS 전용으로 유지됩니다.
**남은 작업:** systemd 사용자 유닛, XDG Autostart 폴백, 설치 프로그램의 `uname -s` 디스패치.
**패키지 전략 (v1.10+):**
- curl 설치: 어디서나 동작하는 범용 폴백 (위 참조)
- AUR: 적은 노력, Arch/Manjaro 대상 사용자에게 높은 도달율
- apt PPA: Debian/Ubuntu 사용자의 수요가 있을 때
- Linux의 Homebrew: 이미 사용 중인 사용자 대상
- Snap/Flatpak: bash 스크립트에는 가치 없음

### ! 명령이 Remote Control에서 사용 불가
**심각도:** 낮음
**상태:** 종결 - 실현 불가
**설명:** Claude Code의 `!` 셸 패스스루는 Claude Code CLI 입력 핸들러 기능으로, 셸이 보기 전에 `!command`를 가로챕니다. tmux send-keys는 이를 복제할 수 없습니다: Claude Code가 활성화된 동안 전송된 키 입력은 아무 곳으로도 가지 않습니다(테스트: send-keys를 통한 `!touch test`가 실행되지 않음). RC 사용자를 위해 claude-mux가 `!command` 우회를 구현할 수 있는 방법은 없습니다.
**해결:** Claude에게 사용자에게 `! <command>`를 제안하지 않도록 주입 규칙 추가. RC 사용자에게는 셸이 없고 터미널 사용자는 직접 타이핑할 수 있으므로.

---

## v2.0 마일스톤

메이저 버전 범프를 정당화할 만큼 중요한 아키텍처 변경. 일정은 없으며, 분실되지 않도록 여기에 수집해 둡니다.

### 데이터 디렉터리 분리
정적 데이터(팁, 기본 템플릿, 가능하면 명령/가이드 출력)를 스크립트에서 플랫폼에 적합한 데이터 디렉터리로 이동합니다. 스크립트는 시작 시 바이너리 위치를 기준으로 `DATA_DIR`을 해석하며, 단일 파일 설치를 위한 내장 폴백을 포함합니다.

- Homebrew (Apple Silicon): `/opt/homebrew/share/claude-mux/`
- Homebrew (Intel): `/usr/local/share/claude-mux/`
- Linux: `/usr/local/share/claude-mux/` 또는 `$XDG_DATA_DIRS`
- 수동 설치: 내장 기본값으로 폴백 (단일 파일 설치 계속 동작)

트리거: 내장 데이터(팁, 기본 템플릿)가 스크립트를 읽기 어렵게 만들 정도로 커지거나, 기본 템플릿이 스크립트 릴리스와 독립적으로 brew를 통해 배포되어야 할 때.

### 언어 / 런타임 재검토
모놀리식 bash 스크립트는 현재 규모에서는 올바른 선택입니다. claude-mux가 크게 성장한다면 -- 프로젝트 이름 변경/이동/복사 작업, 릴레이 레이어, 크로스 플랫폼 패키징, 데이터 디렉터리 -- bash가 버티기 어려워집니다. 그 시점에서 세션 관리 코어를 Go나 다른 타입 언어로 재작성하고(bash는 얇은 CLI 래퍼로) 평가할 가치가 있습니다.

---

## 해결됨

### Claude가 주입을 무시하고 슬래시 명령을 실행할 수 없다고 주장
**해결 버전:** v1.2.0 (주입 업데이트)
**수정:** 주입에 명시적 규칙 추가: "You CAN send slash commands (`/model`, `/compact`, `/clear`, etc.) to this session via the `-s` command. Never tell the user you cannot change models or run slash commands." Claude의 기본 학습은 자신의 모델/설정을 제어할 수 없다고 믿는 경향이 있으며, 명시적 규칙이 실제로 이를 재정의합니다.

### 여러 명령이 성공에도 불구하고 종료 코드 1을 반환
**해결 버전:** v1.2.0 (restart), v1.3.0 (전체 명령)
**수정:** case 문의 모든 디스패치 경로 끝에 명시적 `exit 0`을 추가했습니다. 함수의 마지막 명령이 내부 테스트나 grep 호출에서 비제로 종료 코드를 누출할 수 있었습니다.

### --dry-run이 --restart에 대해 오해의 소지가 있는 출력 표시
**해결 버전:** v1.2.0 (커밋 a10c0c2)
**수정:** Dry-run이 이제 종료를 시뮬레이션한 후 실제 상태를 확인하는 대신 "Would restart session"을 표시합니다.

### macOS에서 pgrep으로 세션 감지 실패
**해결 버전:** 커밋 e1b11b5
**수정:** `pgrep -P`를 `ps -eo` + `awk`로 교체하여 안정적인 자식 프로세스 감지를 구현했습니다.

### $TMUX 변수가 tmux의 환경 변수를 가림
**해결 버전:** 커밋 02a2e82
**수정:** `$TMUX_BIN`으로 이름을 변경했습니다.

### Bash 3.2 비호환성 (declare -A)
**해결 버전:** 커밋 575eac1
**수정:** 연관 배열을 문자열 기반 충돌 감지로 교체했습니다.

---

## 참조: ~/.claude 폴더 구조

여러 계획된 기능(이름 변경, 이동, 복사, 정리)이 이 구조와 올바르게 상호작용해야 하므로 여기에 문서화합니다. 전체가 아닌 claude-mux와 관련된 부분만 다룹니다.

### 프로젝트 기록과 메모리: `~/.claude/projects/`

Claude Code가 사용된 각 작업 디렉터리당 하나의 하위 디렉터리. 절대 경로를 인코딩하여 이름을 지정: `/` -> `-`, 공백 및 특수 문자 -> `-`. 손실 있지만 읽기 가능.

각 프로젝트 폴더의 내용:
- `<uuid>.jsonl` -- 해당 세션의 전체 대화 트랜스크립트. 대화당 하나의 파일.
- `<uuid>/` -- 대화와 관련된 아티팩트(작업, 계획)의 하위 디렉터리. UUID가 `.jsonl` 파일과 일치.
- `memory/` -- 영구 크로스 세션 메모리 파일(프론트매터가 있는 마크다운). 프로젝트에 메모리가 기록된 경우에만 존재.

작업 디렉터리와 기록 사이의 연결은 순전히 인코딩된 폴더 이름입니다. 이 폴더 이름을 변경하지 않고 프로젝트 디렉터리를 이름 변경하거나 이동하면 Claude Code가 기록 없이 새로 시작합니다.

**인코딩 규칙:** 모든 `/`, 공백, 특수 문자가 `-`로 대체된 절대 경로. 선행 `/`는 선행 `-`가 됩니다. 인코딩은 손실 있음 -- 연속된 특수 문자와 슬래시에 인접한 공백 모두 `-`가 되므로 원본을 항상 완벽하게 복원할 수 없습니다.

### 병렬 관찰 레지스트리: `~/.claude/homunculus/`

프로젝트별 도구 수준 이벤트를 추적하는 별도의 시스템. 핵심 Claude Code 기록의 일부가 아님 -- 모니터링/학습 레이어로 보입니다.

- `projects.json` -- 짧은 16진수 UUID(`d6b3aef60967` 등)로 키가 지정된 알려진 모든 프로젝트의 레지스트리. 각 항목: `id`, `name`, `root` (절대 경로), `remote`, `created_at`, `last_seen`.
- `projects/<uuid>/project.json` -- 프로젝트별 메타데이터(레지스트리 항목과 동일한 필드).
- `projects/<uuid>/observations.jsonl` -- 타임스탬프가 있는 `tool_start`/`tool_complete` 이벤트: 도구 이름, 세션 UUID, 프로젝트 이름/ID, 입력/출력 스니펫.
- `projects/<uuid>/instincts` -- 파생된 패턴(내용 불명, 계산된 것으로 추정).
- `projects/<uuid>/evolved` -- 진화/학습된 상태(내용 불명).
- `projects/<uuid>/observations.archive` -- 아카이브된 이전 관찰.

**`~/.claude/projects/`와의 핵심 차이:** 인코딩된 경로가 아닌 짧은 16진수 UUID를 키로 사용합니다. `root` 필드에 절대 경로가 있습니다. 프로젝트 경로를 변경하는 작업(이름 변경, 이동)은 `projects.json`과 `projects/<uuid>/project.json` 모두에서 `root`를 업데이트해야 합니다.

### 전역 설정: `~/.claude/settings.json`

주요 Claude Code 설정 파일. 롤링 백업이 `~/.claude/backups/`에 `~/.claude.json.backup.<timestamp>`로 기록됩니다 -- 활발한 사용 중 시간당 여러 개. claude-mux는 이 파일을 건드리지 않아야 합니다.

### 전역 에이전트, 스킬, 명령

- `~/.claude/agents/` -- 서브에이전트 정의(`.md` 파일, ~38개). 전역, 프로젝트별이 아님.
- `~/.claude/skills/` -- 스킬 디렉터리(~125개). 전역, 프로젝트별이 아님.
- `~/.claude/commands/` -- 슬래시 명령 정의(`.md` 파일, ~72개). 전역, 프로젝트별이 아님.
- `~/.claude/hooks/hooks.json` -- 훅 정의. 전역. claude-mux는 이것을 건드리지 않아야 합니다.

### 잠재적 향후 기능

| 기능 | 처리해야 할 사항 |
|------|-----------------|
| `--copy` | 디렉터리 생성; 세션 시작+중지로 양쪽 레지스트리 초기화; `.jsonl` + `memory/` + UUID 하위 디렉터리 복사; homunculus 관찰 파일을 새 UUID 폴더에 복사 |
| `--delete` 정리 | 이미 프로젝트 폴더를 휴지통으로 이동. 선택적으로: 고아가 된 `~/.claude/projects/` 인코딩 폴더와 `~/.claude/homunculus/` 항목 제거 |
| 기록 크기 경고 | 프로젝트의 `.jsonl` 파일이 임계값을 초과할 때 경고 (주요 claude-mux 트랜스크립트가 단일 긴 세션에서 107MB에 도달) |
