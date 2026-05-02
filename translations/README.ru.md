# claude-mux - Мультиплексор Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · **Русский** · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Постоянные сессии Claude Code для всех ваших проектов, доступные откуда угодно через мобильное приложение Claude.

## Зачем это нужно

Remote Control обещает Claude Code отовсюду — но без управления сессиями это интерфейс второго сорта даже из Claude Desktop:

- Сессии завершаются при закрытии терминала, и контекст разговора не возобновляется автоматически
- Нет постоянной точки доступа — когда вы берёте телефон, ничего не запущено, если только вы не оставили что-то открытым
- Если сессия не запущена, Remote Control бесполезен — нельзя ни открыть проект, ни запустить новый
- Даже в активной RC-сессии слэш-команды не работают — нет смены модели, сжатия контекста или изменения режима разрешений
- Создание нового проекта требует вручную создать директорию, инициализировать git, написать CLAUDE.md, установить режим разрешений и выбрать модель — всё это невозможно сделать через RC
- Управление несколькими проектами означает несколько ручных запусков терминала без общего обзора того, что работает и в каком состоянии

claude-mux решает всё это. Он оборачивает Claude Code в tmux, чтобы сессии не прерывались, внедряет системный промпт, благодаря которому Claude может управлять собственными сессиями, и маршрутизирует слэш-команды через tmux — они работают через Remote Control. Как только сессия запущена, вы управляете всем, просто разговаривая с Claude — в терминале или через мобильное приложение.

## Быстрый старт

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

```bash
cd ~/path/to/your/project
claude-mux
```

Или:

```bash
claude-mux ~/path/to/your/project
```

Всё. Вы находитесь в постоянной сессии Claude с поддержкой контекста и включённым Remote Control. Дальше всё делается через разговор.

## Разговор с Claude

Именно так используется claude-mux в повседневной работе. В каждую сессию внедряются команды, позволяющие Claude управлять сессиями, переключать модели, отправлять слэш-команды и создавать новые проекты — всё это прямо из разговора. Запоминать CLI-флаги не нужно.

```
Вы: "status"
Claude: сообщает имя сессии, модель, режим разрешений, использование контекста и список всех сессий

Вы: "list active sessions"
Claude: показывает все запущенные сессии с их статусом

Вы: "start a session for my api-server project"
Claude: запускает сессию в ~/Claude/work/api-server

Вы: "create a new project called mobile-app using the web template"
Claude: создаёт каталог проекта, инициализирует git, применяет шаблон, запускает сессию

Вы: "switch this session to Haiku"
Claude: отправляет /model haiku самому себе через tmux

Вы: "compact the api-server session"
Claude: отправляет /compact в сессию api-server

Вы: "restart the web-dashboard session"
Claude: завершает и перезапускает сессию, сохраняя контекст разговора

Вы: "switch the api-server session to plan mode"
Claude: перезапускает сессию в режиме разрешений plan


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


Вы: "stop all sessions"
Claude: корректно завершает все управляемые сессии

Вы: "help"
Claude: выводит полный список диалоговых команд
```

Эти команды работают на любом языке. Если вы напишете то же самое по-испански, по-японски, на иврите или любом другом языке, Claude поймёт намерение и выполнит соответствующую команду.

Введите `help` внутри любой сессии, чтобы увидеть полный список команд.

### Home-сессия

Home-сессия — универсальная сессия, расположенная в вашем базовом каталоге (`~/Claude` по умолчанию). Она запускается автоматически при входе в систему, если `LAUNCHAGENT_MODE=home`, предоставляя одну всегда готовую сессию Claude, доступную с телефона. Используйте её для управления всеми остальными сессиями, не запуская проектные сессии заранее.

Home-сессия **защищена** по умолчанию — `--shutdown home` отказывается её останавливать без `--force`. Защита управляется маркером `.claudemux-protected` в `$BASE_DIR`, который создаётся командой `claude-mux --install`. Защищённые сессии отображают `protected` в столбце статуса; вызывающая сессия помечается `>` в столбце имени.

## Что он делает

Под капотом claude-mux обеспечивает:

- **Постоянные сессии tmux** с включённым Remote Control, так что каждая сессия доступна из мобильного приложения Claude
- **Возобновление разговоров** — при перезапуске возобновляется последний разговор (`claude -c`), контекст сохраняется
- **Внедрение системного промпта** — каждая сессия получает команды для самоуправления, маршрутизации слэш-команд и осведомлённости о SSH-аккаунтах
- **Шаблоны CLAUDE.md** — храните файлы-шаблоны (например, `web.md`, `python.md`) в `~/.claude-mux/templates/` и применяйте их к новым проектам
- **Поддержка нескольких AI CLI** — создаёт `AGENTS.md` и `GEMINI.md` как символические ссылки на `CLAUDE.md`, чтобы Codex CLI, Gemini CLI и другие инструменты использовали одни и те же инструкции
- **Автоматическое одобрение разрешений** — добавляет claude-mux в список разрешений каждого проекта, чтобы Claude мог выполнять команды сессий без запроса
- **Миграция «бесхозных» процессов** — если Claude уже работает вне tmux, переносит его в управляемую сессию
- **Удобство tmux** — поддержка мыши, буфер прокрутки 50k, буфер обмена, 256-цветный режим, расширенные клавиши, мониторинг активности, заголовки вкладок

> **Примечание:** Это не то же самое, что `claude --worktree --tmux`, который создаёт сессию tmux для изолированного git worktree. claude-mux управляет постоянными сессиями для ваших настоящих каталогов проектов, с Remote Control и внедрением системного промпта.

## Требования

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Claude Code](https://claude.ai/code) — `brew install claude`

## Установка

### Homebrew (рекомендуется)

```bash
brew tap pereljon/tap
brew install claude-mux
```

После установки запустите команду настройки:

```bash
claude-mux --install
```

Для обновления:

```bash
brew upgrade claude-mux       # или: claude-mux --update  (работает из любой сессии)
```

### Вручную

```bash
./install.sh
```

`install.sh` копирует бинарный файл в `~/bin` и добавляет его в `PATH`. Затем запустите:

```bash
claude-mux --install
```

Интерактивная настройка спросит, где находятся ваши проекты Claude, нужно ли запускать home-сессию при входе и какую модель использовать. Она создаст `~/.claude-mux/config` и установит LaunchAgent.

Используйте `--non-interactive`, чтобы пропустить вопросы и принять значения по умолчанию.

Параметры:

```bash
claude-mux --install --non-interactive                     # пропустить вопросы, использовать значения по умолчанию
claude-mux --install --base-dir ~/work/claude              # использовать другой базовый каталог
claude-mux --install --launchagent-mode none               # отключить поведение LaunchAgent
claude-mux --install --home-model haiku                    # использовать Haiku для home-сессии
claude-mux --install --no-launchagent                      # полностью пропустить установку LaunchAgent
```

LaunchAgent выполняет `claude-mux --autolaunch` при входе в систему с задержкой 45 секунд, чтобы системные службы успели инициализироваться.

## Статусы сессий

| Статус | Значение |
|--------|----------|
| `running` | сессия tmux существует и Claude работает |
| `protected` | то же что `running`, но сессия защищена — для остановки через `--shutdown` требуется `--force` |
| `stopped` | сессия tmux существует, но Claude завершился |
| `idle` | проект `.claude/` существует под `BASE_DIR`, но сессия tmux под управлением claude-mux не запущена (показывается только с `-L`) |

Префикс `>` у имени сессии (например, `> home`) указывает на сессию, из которой была запущена команда списка.

Запуск `claude-mux` в каталоге, где уже есть запущенная сессия, подключает к ней. К одной сессии могут подключаться несколько терминалов (стандартное поведение tmux).

## Маркеры проекта

Состояние конкретного проекта хранится в файлах-маркерах в корне проекта, а не в центральной конфигурации. Маркеры используют префикс `.claudemux-` и автоматически добавляются в `.gitignore` при создании в проекте под управлением git.

| Маркер | Значение | CLI |
|--------|----------|-----|
| `.claudemux-protected` | Сессия защищается при запуске — для `--shutdown` требуется `--force` | `--protect` / `--unprotect` |
| `.claudemux-ignore` | Проект скрывается из списков `claude-mux -L` | `--hide` / `--show` |

```bash
claude-mux --hide                    # скрыть текущий проект из списков -L
claude-mux --show                    # показать текущий проект снова
claude-mux --protect                 # защитить эту сессию от случайного завершения
claude-mux --unprotect               # снять защиту
claude-mux -L --hidden               # показать только скрытые проекты
claude-mux --delete ~/projects/old   # переместить папку проекта в корзину системы (macOS)
```

Маркеры следуют за папкой проекта при переименованиях и перемещениях. Единственный шаблон `.gitignore` (`.claudemux-*`) охватывает все текущие и будущие маркеры.

## Конфигурация

`~/.claude-mux/config` создаётся командой `claude-mux --install` (или при первом запуске любой команды, если конфиг отсутствует). Отредактируйте файл, чтобы переопределить значения по умолчанию — сам скрипт менять не нужно.

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `BASE_DIR` | `$HOME/Claude` | Корневой каталог для поиска проектов Claude (каталоги, содержащие `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Каталог для файла `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Устанавливает `permissions.defaultMode` в каждом проекте. Допустимые: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Установите `""`, чтобы отключить. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | При значении `true` сессии Claude могут отправлять слэш-команды в другие сессии — полезно для оркестрации нескольких агентов |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Каталог с файлами шаблонов CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | Шаблон по умолчанию, применяемый к новым проектам (`-n`). Установите `""`, чтобы отключить. |
| `SLEEP_BETWEEN` | `5` | Секунд между запусками сессий при использовании `-a`. Увеличьте, если регистрация RC даёт сбой. |
| `HOME_SESSION_MODEL` | `""` | Модель для home-сессии. Допустимые: `sonnet`, `haiku`, `opus`. Пустое значение наследует значение по умолчанию Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Список файлов через пробел, создаваемых как символические ссылки на `CLAUDE.md` для других AI CLI. Установите `""`, чтобы отключить. |
| `LAUNCHAGENT_MODE` | `home` | Поведение LaunchAgent при входе: `none` (ничего не делать) или `home` (запустить защищённую home-сессию). Устаревшее `LAUNCHAGENT_ENABLED=true` трактуется как `home`. |

**Параметры сессии tmux** (все настраиваемые, все включены по умолчанию):

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `TMUX_MOUSE` | `true` | Поддержка мыши: прокрутка, выделение, изменение размера панелей |
| `TMUX_HISTORY_LIMIT` | `50000` | Размер буфера прокрутки в строках (по умолчанию в tmux — 2000) |
| `TMUX_CLIPBOARD` | `true` | Интеграция системного буфера обмена через OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Тип терминала для корректной передачи цветов |
| `TMUX_EXTENDED_KEYS` | `true` | Расширенные последовательности клавиш, включая Shift+Enter (требуется tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | Задержка клавиши escape в миллисекундах (по умолчанию в tmux — 500) |
| `TMUX_TITLE_FORMAT` | `#S` | Формат заголовка терминала/вкладки (`#S` — имя сессии, `""` — отключить) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Уведомлять об активности в других сессиях |

## Структура каталогов

Проекты определяются по наличию каталога `.claude/` на любом уровне вложенности:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ есть .claude/ - управляется
│   │   └── .claude/
│   ├── project-b/          # ✓ есть .claude/ - управляется
│   │   └── .claude/
│   └── -archived/          # ✗ исключено (начинается с -)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ есть .claude/ - управляется
│   │   └── .claude/
│   ├── .hidden/            # ✗ исключено (скрытый каталог)
│   │   └── .claude/
│   └── project-d/          # ✗ нет .claude/ - не проект Claude
├── deep/nested/project-e/  # ✓ есть .claude/ - найдено на любой глубине
│   └── .claude/
└── ignored-project/        # ✗ исключено (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

Имена сессий формируются из имён каталогов: пробелы превращаются в дефисы, неалфавитно-цифровые символы (кроме дефисов) заменяются, ведущие и завершающие дефисы удаляются. Каталоги, имя которых после нормализации становится пустым, пропускаются с предупреждением в логе.

## Системный промпт сессии

Каждая сессия Claude запускается с `--append-system-prompt`, содержащим контекст её окружения:

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

(Строка об обновлении включается только при наличии доступного обновления.)

При `ALLOW_CROSS_SESSION_CONTROL=true` команда отправки меняется так, чтобы можно было адресовать любую сессию, а не только саму себя. Путь — это абсолютный путь к скрипту в момент запуска, поэтому сессии не зависят от `PATH`.

## Справочник CLI

Напрямую эти команды нужны редко — Claude выполняет их за вас внутри сессий. Они доступны для скриптов, автоматизации или когда вы работаете вне сессии.

```bash
# Запуск и подключение
claude-mux                       # запустить Claude в текущем каталоге и подключиться
claude-mux ~/projects/my-app     # запустить Claude в каталоге и подключиться
claude-mux -d ~/projects/my-app  # то же самое (явная форма)
claude-mux -t my-app             # подключиться к существующей сессии tmux

# Создание новых проектов
claude-mux -n ~/projects/app     # создать новый проект Claude и подключиться
claude-mux -n ~/new/path/app -p  # то же самое, создавая каталог и его родителей
claude-mux -n ~/app --template web        # новый проект с конкретным шаблоном CLAUDE.md
claude-mux -n ~/app --no-multi-coder      # новый проект без символических ссылок AGENTS.md/GEMINI.md

# Управление сессиями
claude-mux -l                    # список сессий по статусу (active, running, stopped)
claude-mux -L                    # список всех проектов (active + idle)
claude-mux -L --hidden           # показать только скрытые проекты
claude-mux -s my-app '/model sonnet'      # отправить слэш-команду в сессию
claude-mux --shutdown my-app              # остановить конкретную сессию
claude-mux --shutdown                     # остановить все управляемые сессии
claude-mux --shutdown home --force        # остановить защищённую home-сессию
claude-mux --restart my-app              # перезапустить конкретную сессию
claude-mux --restart                     # перезапустить все запущенные сессии
claude-mux --permission-mode plan my-app  # перезапустить сессию в plan-режиме
claude-mux -a                    # запустить все управляемые сессии в BASE_DIR

# Маркеры проекта
claude-mux --hide                    # скрыть текущий проект из списков -L
claude-mux --hide ~/projects/old     # скрыть конкретный проект
claude-mux --show                    # показать текущий проект снова
claude-mux --protect                 # защитить эту сессию от случайного завершения
claude-mux --unprotect               # снять защиту
claude-mux --delete ~/projects/old           # переместить папку проекта в корзину системы (macOS)
claude-mux --delete ~/projects/old --yes     # то же, без запроса подтверждения

# Прочее
claude-mux --commands            # показать полный справочник CLI
claude-mux --config-help         # показать все параметры конфигурации с их значениями по умолчанию и описаниями
claude-mux --list-templates      # показать доступные шаблоны CLAUDE.md
claude-mux --guide               # показать диалоговые команды для использования внутри сессий
claude-mux --install             # интерактивная настройка: config + LaunchAgent
claude-mux --update              # обновить до последней версии
claude-mux --dry-run             # показать действия без выполнения
claude-mux --version             # вывести версию
claude-mux --help                # показать все параметры

# Следить за логом
tail -f ~/Library/Logs/claude-mux.log
```

При запуске из терминала вывод дублируется на stdout в реальном времени. При запуске через LaunchAgent вывод идёт только в файл лога.

## Решение проблем

### Сессии показывают «Not logged in · Run /login»

Это происходит при первом запуске, если связка ключей macOS заблокирована (часто бывает, когда скрипт стартует до разблокировки связки ключей после входа в систему). Решение:

```bash
# Разблокировать связку ключей в обычном терминале
security unlock-keychain

# Затем завершить аутентификацию в любой запущенной сессии
claude-mux -t <any-session>
# Запустить /login и пройти процесс аутентификации в браузере
```

После однократного завершения аутентификации остановите и перезапустите все сессии — они автоматически подхватят сохранённые учётные данные.

### Сессии не появляются в Claude Code Remote

Сессии должны быть аутентифицированы (не показывать «Not logged in»). После чистого аутентифицированного запуска они должны появиться в списке RC в течение нескольких секунд.

### Многострочный ввод в tmux

Команда `/terminal-setup` не работает внутри tmux. claude-mux включает в tmux `extended-keys` по умолчанию (`TMUX_EXTENDED_KEYS=true`), что обеспечивает поддержку Shift+Enter в большинстве современных терминалов. Если Shift+Enter не работает, используйте `\` + Return для ввода переноса строки в запросе.

### «Ready.» при старте сессии

Когда сессия запускается или перезапускается, claude-mux автоматически отправляет сообщение `ready` после завершения загрузки Claude. Внедрённый промпт указывает Claude ответить «Ready.» и ничем больше. Это подтверждает, что сессия жива и внедрение работает.

### Слэш-команды через Remote Control

Слэш-команды (например, `/model`, `/clear`) [не поддерживаются штатно](https://github.com/anthropics/claude-code/issues/30674) в RC-сессиях. claude-mux обходит это: в каждую сессию внедряется `claude-mux -s`, чтобы Claude мог отправлять слэш-команды самому себе через tmux.

## Логи

- `~/Library/Logs/claude-mux.log` — все действия скрипта с метками времени UTC (настраивается через `LOG_DIR`)

Для низкоуровневой отладки LaunchAgent используйте Console.app или `log show`.
