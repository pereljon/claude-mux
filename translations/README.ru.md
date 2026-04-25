# claude-mux - Мультиплексор Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · **Русский** · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

> Примечание: Этот перевод может отставать от английского README. См. [README.md](../README.md) для канонической версии.

Постоянные сессии Claude Code для всех ваших проектов, доступные откуда угодно через мобильное приложение Claude.

Shell-скрипт, который запускает Claude Code внутри tmux с включённым Remote Control, возобновлением разговоров и самоуправлением сессиями: просмотр сессий, отправка слэш-команд, создание новых проектов, остановка и перезапуск. Запустите `claude-mux` в любом каталоге, чтобы получить постоянную сессию, доступную с телефона.

## Быстрый старт

```bash
./install.sh
```

```bash
claude-mux ~/path/to/your/project
```

Или перейдите (`cd`) в каталог проекта и выполните:

```bash
claude-mux
```

Готово: вы находитесь в постоянной сессии Claude с поддержкой контекста и включённым Remote Control.

claude-mux это один bash-скрипт без зависимостей, кроме tmux и Claude Code.

## Что он делает

1. **Постоянные сессии tmux с Remote Control** — запускает Claude Code внутри tmux с флагом `--remote-control`, так что каждая сессия доступна из мобильного приложения Claude
2. **Возобновление разговоров** — если Claude ранее работал в каталоге, возобновляет последний разговор (`claude -c`) внутри новой сессии tmux с Remote Control, сохраняя ваш контекст
3. **Управление сессиями** — список активных сессий (`-l`) или всех проектов, включая неактивные (`-L`), остановка (`--shutdown`), перезапуск (`--restart`), переключение режимов разрешений (`--permission-mode`), подключение (`-t`), отправка слэш-команд в сессии (`-s`)
4. **Самоуправление Claude** — в каждую сессию внедряется системный промпт, благодаря которому Claude может выполнять все приведённые выше команды прямо из окна разговора (в терминале или в мобильном приложении):
   - a. Список запущенных сессий и всех проектов
   - b. Запуск новых сессий, создание новых проектов
   - c. Отправка слэш-команд самому себе или в другие сессии (обходное решение для [слэш-команд, которые не работают штатно через RC](https://github.com/anthropics/claude-code/issues/30674))
   - d. Остановка, перезапуск или переключение режимов разрешений сессий
5. **Home-сессия** — лёгкая, всегда работающая сессия в вашем базовом каталоге, которая запускается при входе в систему (настраивается через `LAUNCHAGENT_MODE`). Поддерживает постоянную доступность Remote Control из мобильного приложения Claude и может управлять всеми остальными сессиями. Защищена от случайной остановки.
6. **Создание новых проектов** — `claude-mux -n DIRECTORY` создаёт готовый к работе проект с git, `.gitignore` и настроенным режимом разрешений (`-p` создаёт каталог, если его нет). Любая запущенная сессия может создавать новые проекты: попросите Claude настроить репозиторий в любом из ваших аккаунтов GitHub и начать кодить откуда угодно
7. **Шаблоны CLAUDE.md** — храните библиотеку файлов-инструкций CLAUDE.md в `~/.claude-mux/templates/` (например, `web.md`, `python.md`, `default.md`) и применяйте их автоматически к новым проектам. Используйте `--template NAME`, чтобы выбрать конкретный шаблон, или позвольте применить шаблон по умолчанию
8. **Учёт SSH-аккаунтов** — внедряет алиасы хостов GitHub SSH из `~/.ssh/config`, чтобы Claude знал, какие аккаунты доступны для git-операций
9. **Автоматическое одобрение разрешений** — claude-mux добавляет себя в список разрешений `.claude/settings.local.json` каждого проекта, чтобы Claude мог выполнять команды claude-mux без запроса разрешения
10. **Миграция «бесхозных» процессов** — если Claude уже работает в целевом каталоге вне tmux, скрипт завершает его и перезапускает внутри управляемой сессии tmux (разговор возобновляется через `claude -c`)
11. **Удобство работы с tmux** — сессии настроены с поддержкой мыши, буфером прокрутки 50k, интеграцией буфера обмена, 256-цветным режимом, уменьшенной задержкой escape, расширенными клавишами (Shift+Enter), мониторингом активности и заголовками вкладок терминала. Всё настраивается в `~/.claude-mux/config`

> **Примечание:** Это не то же самое, что `claude --worktree --tmux`, который создаёт сессию tmux для изолированного git worktree. claude-mux управляет постоянными сессиями для ваших настоящих каталогов проектов, с Remote Control и внедрением системного промпта.

### Home-сессия

Одна универсальная сессия, расположенная в `$BASE_DIR`. Запускается автоматически при входе, если `LAUNCHAGENT_MODE=home`, или вручную запуском `claude-mux` из `$BASE_DIR`. Даёт одну всегда готовую сессию Claude, доступную с телефона, без необходимости запускать сессии для каждого проекта.

Home-сессия всегда **защищена**: `--shutdown home` отказывается её останавливать без `--force`, независимо от того, как она была запущена. Защищённые сессии помечаются `*` в выводе `-l`/`-L` (например, `active*`).

## Требования

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Claude Code](https://claude.ai/code) — `brew install claude`

## Установка

```bash
./install.sh
```

Интерактивный установщик спросит, где находятся ваши проекты Claude, нужно ли запускать home-сессию при входе и какую модель использовать. Он установит `claude-mux` в `~/bin`, создаст `~/.claude-mux/config` и настроит LaunchAgent.

Используйте `--non-interactive`, чтобы пропустить вопросы и принять значения по умолчанию.

Параметры:

```bash
./install.sh --non-interactive                     # пропустить вопросы, использовать значения по умолчанию
./install.sh --base-dir ~/work/claude              # использовать другой базовый каталог
./install.sh --launchagent-mode none               # отключить поведение LaunchAgent
./install.sh --home-model haiku                    # использовать Haiku для home-сессии
./install.sh --no-launchagent                      # полностью пропустить установку LaunchAgent
```

LaunchAgent выполняет `claude-mux --autolaunch` при входе в систему с задержкой 45 секунд, чтобы системные службы успели инициализироваться.

## Использование

```bash
claude-mux                       # запустить Claude в текущем каталоге и подключиться
claude-mux ~/projects/my-app     # запустить Claude в каталоге и подключиться
claude-mux -d ~/projects/my-app  # то же самое (явная форма)
claude-mux -a                    # запустить все управляемые сессии в BASE_DIR
claude-mux -n ~/projects/app     # создать новый проект Claude и подключиться
claude-mux -n ~/new/path/app -p  # то же самое, создавая каталог и его родителей
claude-mux -n ~/app --template web  # новый проект с конкретным шаблоном CLAUDE.md
claude-mux --list-templates      # показать доступные шаблоны CLAUDE.md
claude-mux -t my-app             # подключиться к существующей сессии tmux
claude-mux -s my-app '/model sonnet' # отправить слэш-команду в сессию
claude-mux -l                    # список сессий по статусу (active, running, stopped)
claude-mux -L                    # список всех проектов (active + idle)
claude-mux --shutdown            # корректно завершить все управляемые сессии Claude
claude-mux --shutdown my-app     # остановить конкретную сессию
claude-mux --shutdown a b c      # остановить несколько сессий
claude-mux --shutdown home --force  # остановить защищённую home-сессию
claude-mux --restart             # перезапустить сессии, которые были запущены
claude-mux --restart my-app      # перезапустить конкретную сессию
claude-mux --restart a b c       # перезапустить несколько сессий
claude-mux --permission-mode plan my-app    # перезапустить сессию в plan-режиме
claude-mux --permission-mode dangerously-skip-permissions my-app  # yolo-режим
claude-mux --dry-run             # показать действия без выполнения
claude-mux --version             # показать версию
claude-mux --help                # показать все параметры
claude-mux --guide               # показать диалоговые команды для использования внутри сессий

# Следить за логом
tail -f ~/Library/Logs/claude-mux.log
```

При запуске из терминала вывод дублируется на stdout в реальном времени. При запуске через LaunchAgent вывод идёт только в файл лога.

## Статусы сессий

| Статус | Значение |
|--------|----------|
| `active` | сессия tmux существует, Claude работает, и локальный клиент tmux подключён |
| `running` | сессия tmux существует и Claude работает (локальный клиент не подключён) |
| `stopped` | сессия tmux существует, но Claude завершился |
| `idle` | проект `.claude/` существует под `BASE_DIR`, но сессия tmux под управлением claude-mux не запущена (показывается только с `-L`) |

Завершающая `*` у любого статуса означает, что сессия защищена и для её остановки требуется `--force` (например, `active*`, `running*`). Home-сессия всегда защищена.

Запуск `claude-mux` в каталоге, где уже есть запущенная сессия, подключает к ней. К одной сессии могут подключаться несколько терминалов (стандартное поведение tmux).

## Примеры запросов к Claude

Поскольку в каждую сессию внедряются команды claude-mux, вы можете управлять сессиями прямо из окна разговора — в терминале или через мобильное приложение:

```
Вы: «Какие сессии запущены?»
Claude: выполняет `claude-mux -l` и показывает результат

Вы: «Покажи все проекты»
Claude: выполняет `claude-mux -L` и показывает результат

Вы: «Запусти сессию для моего рабочего проекта api-server»
Claude: выполняет `claude-mux -d ~/Claude/work/api-server --no-attach`

Вы: «Создай новый личный проект под названием mobile-app»
Claude: выполняет `claude-mux -n ~/Claude/personal/mobile-app -p --no-attach`

Вы: «Какие у меня есть шаблоны?»
Claude: выполняет `claude-mux --list-templates` и показывает результат

Вы: «Создай новый рабочий проект под названием api-server, используя шаблон web»
Claude: выполняет `claude-mux -n ~/Claude/work/api-server -p --template web --no-attach`

Вы: «Переключи все сессии на Sonnet»
Claude: выполняет `claude-mux -s SESSION '/model sonnet'` для каждой запущенной сессии

Вы: «Останови сессию data-pipeline»
Claude: выполняет `claude-mux --shutdown data-pipeline`

Вы: «Перезапусти зависшую сессию web-dashboard»
Claude: выполняет `claude-mux --restart web-dashboard`

Вы: «Переключи сессию api-server в plan-режим»
Claude: выполняет `claude-mux --permission-mode plan api-server`

Вы: «Yolo-режим для сессии data-pipeline»
Claude: выполняет `claude-mux --permission-mode dangerously-skip-permissions data-pipeline`

Вы: «Запусти сессию data-pipeline в фоне»
Claude: выполняет `claude-mux -d ~/Claude/work/data-pipeline --no-attach`

Вы: «Запусти все мои проекты»
Claude: выполняет `claude-mux -a` (после подтверждения — это запустит все управляемые проекты)
```

## Конфигурация

При первом запуске `~/.claude-mux/config` создаётся автоматически со всеми настройками, закомментированными. Отредактируйте файл, чтобы переопределить значения по умолчанию: сам скрипт менять не нужно.

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
│   ├── project-a/          # ✓ есть .claude/ — управляется
│   │   └── .claude/
│   ├── project-b/          # ✓ есть .claude/ — управляется
│   │   └── .claude/
│   └── -archived/          # ✗ исключено (начинается с -)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ есть .claude/ — управляется
│   │   └── .claude/
│   ├── .hidden/            # ✗ исключено (скрытый каталог)
│   │   └── .claude/
│   └── project-d/          # ✗ нет .claude/ — не проект Claude
├── deep/nested/project-e/  # ✓ есть .claude/ — найдено на любой глубине
│   └── .claude/
└── ignored-project/        # ✗ исключено (.ignore-claudemux)
    ├── .claude/
    └── .ignore-claudemux
```

Имена сессий формируются из имён каталогов: пробелы превращаются в дефисы, неалфавитно-цифровые символы (кроме дефисов) заменяются, ведущие и завершающие дефисы удаляются. Каталоги, имя которых после нормализации становится пустым, пропускаются с предупреждением в логе.

## Системный промпт сессии

Каждая сессия Claude запускается с `--append-system-prompt`, содержащим контекст её окружения:

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

При `ALLOW_CROSS_SESSION_CONTROL=true` команда отправки меняется так, чтобы можно было адресовать любую сессию, а не только саму себя. Путь — это абсолютный путь к скрипту в момент запуска, поэтому сессии не зависят от `PATH`.

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

### Слэш-команды через Remote Control

Слэш-команды (например, `/model`, `/clear`) [не поддерживаются штатно](https://github.com/anthropics/claude-code/issues/30674) в RC-сессиях. claude-mux обходит это: в каждую сессию внедряется `claude-mux -s`, чтобы Claude мог отправлять слэш-команды самому себе через tmux.

## Логи

- `~/Library/Logs/claude-mux.log` — все действия скрипта с метками времени UTC (настраивается через `LOG_DIR`)

Для низкоуровневой отладки LaunchAgent используйте Console.app или `log show`.
