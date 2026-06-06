# claude-mux - Claude Code 멀티플렉서

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · **한국어** · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

모든 프로젝트를 위한 영구 Claude Code 세션 - Claude 모바일 앱을 통해 어디서나 접근 가능합니다. ***Claude가 관리!***

## 설치

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

세션을 시작합니다:

```bash
claude-mux ~/path/to/your/project
```

설치 프로그램은 로그인 시 홈 세션을 자동 시작할지 물어봅니다. 수락하면 로그인할 때마다 보호된 Claude 세션이 자동 시작되어 터미널을 열지 않아도 휴대폰이나 Remote Control 클라이언트에서 항상 접근할 수 있습니다.

이게 전부입니다. Remote Control이 활성화된 영구적이고 세션 인식이 가능한 Claude 세션에 진입했습니다. **이제부터 모든 것은 대화로 처리합니다.**

[Homebrew, 수동 설치 및 기타 옵션](../docs/INSTALL.md)

## 왜 사용하나요

Remote Control은 어디서든 Claude Code를 사용할 수 있다고 약속합니다. 하지만 세션 관리 없이는 Claude Desktop에서조차 이류 인터페이스입니다:

- 터미널을 닫으면 **세션이 종료**됨
- **대화 컨텍스트**가 자동으로 재개되지 않음
- **상시 실행되는 홈 베이스가 없음** - 무언가를 열어둔 것이 없으면 폰을 들었을 때 아무것도 실행 중이지 않음
- **Remote Control은 실행 중인 세션이 필요** - RC에서 세션을 시작할 수 없음
- **RC 세션에서 슬래시 명령이 동작하지 않음** - 모델 전환, 압축, 권한 모드 변경 불가
- **새 프로젝트 시작** - 디렉터리 수동 생성, git 초기화, CLAUDE.md 작성, 모델 선택이 필요
- **프로젝트 관리 부재** - 유휴 프로젝트 확인이나 기록을 깨지 않고 프로젝트 이름 변경, 이동, 삭제가 불가능

**claude-mux는 세션 관리의 공백을 해결합니다.** Claude Code를 tmux로 감싸 세션이 유지되도록 하고, Claude가 자체 세션을 관리할 수 있도록 시스템 프롬프트를 주입하며, 슬래시 명령을 tmux를 통해 라우팅해 Remote Control에서도 동작하게 합니다. 세션이 실행 중이면 터미널이든 모바일 앱이든 Claude와 대화로 모든 것을 관리합니다.

## claude-mux 세션에서 할 수 있는 것

- **어떤 세션에서든 다른 세션을 관리** - 자연어로 프로젝트 시작, 중지, 재시작, 목록 조회, 압축
- **어디서나 모든 것에 접근** - 모든 세션에 Remote Control이 활성화되어 있어 Claude 모바일 앱, 데스크톱 앱, 기타 원격 클라이언트가 완전한 인터페이스로 동작
- **모델과 권한 모드 전환** - "Haiku로 전환해" 또는 "plan 모드로 전환해"라고 하면 Remote Control을 통해서도 Claude가 처리
- **새 프로젝트 생성** - "my-app이라는 새 프로젝트를 만들어"라고 하면 디렉터리 설정, git 초기화, CLAUDE.md 작성, 세션 시작까지 완료. CLAUDE.md 템플릿으로 프로젝트 간 지침 재사용 가능
- **재부팅 후에도 세션 유지** - 선택적 홈 세션이 로그인 시 시작되어 계속 실행. 모든 세션이 자동으로 마지막 대화를 재개
- **Remote Control을 통한 슬래시 명령 전송** - `/model`, `/compact`, `/clear` 등의 슬래시 명령을 Claude가 실행 중인 세션으로 라우팅하여 [알려진 제한](https://github.com/anthropics/claude-code/issues/30674)을 우회
- **대화 기록 보존** - 프로젝트 이름 변경, 이동, 재시작 시 대화 기록을 자동으로 보존
- **프로젝트 정리** - 어떤 세션 안에서든 프로젝트 숨기기, 이름 변경, 이동, 삭제, 보호
- **GitHub 멀티 계정 지원** - `~/.ssh/config`의 SSH 별칭을 감지하여 세션에 주입, 프로젝트별로 올바른 계정 사용
- **멀티 CLI 도구 지원** - `AGENTS.md`와 `GEMINI.md` 심볼릭 링크를 자동 생성하여 Codex CLI, Gemini CLI 등과 지침 공유
- **어떤 언어로든 동작** - 대화형 명령은 키워드가 아닌 의도에서 추론됨

## Claude와 대화하기

이것이 claude-mux의 일상적인 사용 방식입니다. 모든 세션에는 명령이 주입되어 있어 Claude가 세션 관리, 모델 전환, 슬래시 명령 전송, 새 프로젝트 생성을 대화 안에서 처리합니다. CLI 플래그를 외울 필요가 없습니다.

```
사용자: "status"
Claude: 세션 이름, 모델, 권한 모드, 컨텍스트 사용량을 보고하고 모든 세션 목록을 표시

사용자: "활성 세션 목록"
Claude: 실행 중인 모든 세션과 상태를 표시

사용자: "api-server 프로젝트의 세션을 시작해"
Claude: ~/Claude/work/api-server에서 세션을 시작

사용자: "web 템플릿을 사용해서 mobile-app이라는 새 프로젝트를 만들어"
Claude: 프로젝트 디렉터리 생성, git 초기화, 템플릿 적용, 세션 시작

사용자: "이 세션을 Haiku로 전환해"
Claude: tmux를 통해 자기 자신에게 /model haiku를 전송

사용자: "api-server 세션을 압축해"
Claude: api-server 세션에 /compact를 전송

사용자: "web-dashboard 세션을 재시작해"
Claude: 세션을 종료하고 재시작하며 대화 컨텍스트를 보존

사용자: "api-server 세션을 plan 모드로 전환해"
Claude: plan 권한 모드로 세션을 재시작

사용자: "이 세션을 yolo 모드로 전환해"
Claude: Shift+Tab으로 bypassPermissions 모드로 전환 - 재시작 불필요

사용자: "이 세션은 무슨 모드야"
Claude: 현재 권한 모드를 보고 (default, acceptEdits, plan, bypassPermissions)

사용자: "이 세션을 Opus로 전환해"
Claude: tmux를 통해 자기 자신에게 /model opus를 전송

사용자: "이 세션을 클리어해"
Claude: 자기 자신에게 /clear를 전송하여 대화를 초기화

사용자: "이 프로젝트를 숨겨"
Claude: .claudemux-ignore를 생성하여 프로젝트를 -L 목록에서 제외

사용자: "이 세션을 보호해"
Claude: .claudemux-protected를 생성하고 tmux 마커를 설정 - 종료에 --force가 필요

사용자: "이 세션은 보호되어 있어?"
Claude: 프로젝트 폴더에서 .claudemux-protected를 확인하고 결과를 보고

사용자: "old-prototype 프로젝트를 삭제해"
Claude: 대화에서 확인 후 프로젝트 폴더를 시스템 휴지통으로 이동

사용자: "이 프로젝트 이름을 my-new-name으로 변경해"
Claude: 세션을 중지하고, 폴더 이름을 변경하고, 대화 기록을 마이그레이션한 후 재시작

사용자: "이걸 web이라는 이름의 템플릿으로 저장해"
Claude: CLAUDE.md를 ~/.claude-mux/templates/web.md로 복사

사용자: "tip"
Claude: 팁을 출력 - 하루 내내 같은 팁, TIP_MODE=random 설정 시 무작위

사용자: "팁 활성화" / "팁 비활성화"
Claude: 모든 프로젝트에서 매일 팁을 켜거나 끔

사용자: "update claude-mux"
Claude: 모든 세션이 재시작될 것을 경고하고, 확인 후 업데이트 및 재시작

사용자: "모든 세션을 중지해"
Claude: 관리 중인 모든 세션을 정상 종료

사용자: "help"
Claude: 전체 대화형 명령 목록을 출력
```

**이 명령들은 어떤 언어로든 동작합니다.** 스페인어, 일본어, 히브리어 등 어떤 언어로든 동등한 표현을 입력하면 Claude가 의도를 파악해 해당 명령을 실행합니다.

**세션 안에서 `help`를 입력하면 전체 명령 목록을 볼 수 있습니다.**

## 더 보기

- [CLI 참조](../docs/CLI.md) - 스크립팅과 자동화를 위한 전체 명령 참조
- [가이드](../docs/guide.md) - 구성, 세션 상세, 내부 구조, 문제 해결
- [설치 옵션](../docs/INSTALL.md) - Homebrew, 수동 설치, LaunchAgent 설정
- [FAQ](../docs/FAQ.md) - claude-mux에 대한 자주 묻는 질문
- [알려진 이슈](../docs/ISSUES.md) - 미해결 버그, 계획된 기능, 해결된 이슈
- [변경 로그](../CHANGELOG.md) - 릴리스별 변경 사항
