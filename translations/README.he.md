# claude-mux - מולטיפלקסר ל-Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · **עברית** · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

סשנים מתמשכים של Claude Code לכל הפרויקטים שלך - נגישים מכל מקום דרך אפליקציית Claude לנייד.

## למה

עבודה עם Claude Code על פני פרויקטים מרובים כרוכה בחיכוך:

- סשנים מתים כשסוגרים את הטרמינל
- סשני Remote Control לא יכולים להריץ פקודות slash כמו `/model` או `/compact`
- קשה להתחיל סשן לפרויקט שעדיין לא רץ
- החלפת מודלים, מצבי הרשאות, או דחיסת הקשר מהטלפון אינה אפשרית

claude-mux פותר את כל אלה. הוא עוטף את Claude Code ב-tmux כך שסשנים נשמרים, מזריק system prompt כדי ש-Claude יוכל לנהל את הסשנים שלו עצמו, ומנתב פקודות slash דרך tmux כך שהן עובדות דרך Remote Control. ברגע שסשן רץ, מנהלים הכול על ידי שיחה עם Claude — בטרמינל או באפליקציית הנייד.

## התחלה מהירה

```bash
./install.sh
```

```bash
claude-mux ~/path/to/your/project
```

זהו. אתה בתוך סשן Claude מתמשך ומודע-לסשן עם Remote Control מופעל. מכאן, הכול שיחותי.

## לדבר עם Claude

כך משתמשים ב-claude-mux מדי יום. כל סשן מוזרק עם פקודות כך ש-Claude יוכל לנהל סשנים, להחליף מודלים, לשלוח פקודות slash וליצור פרויקטים חדשים — הכול מתוך השיחה. אין צורך לזכור דגלי CLI.

```
אתה: "status"
Claude: מדווח על שם הסשן, מודל, מצב הרשאות, שימוש בהקשר, ומפרט את כל הסשנים

אתה: "list active sessions"
Claude: מציג את כל הסשנים הרצים עם הסטטוס שלהם

אתה: "start a session for my api-server project"
Claude: מפעיל סשן ב-~/Claude/work/api-server

אתה: "create a new project called mobile-app using the web template"
Claude: יוצר את ספריית הפרויקט, מאתחל git, מחיל את התבנית, מפעיל סשן

אתה: "switch this session to Haiku"
Claude: שולח /model haiku לעצמו דרך tmux

אתה: "compact the api-server session"
Claude: שולח /compact לסשן api-server

אתה: "restart the web-dashboard session"
Claude: מכבה ומפעיל מחדש את הסשן, תוך שמירת הקשר השיחה

אתה: "switch the api-server session to plan mode"
Claude: מפעיל מחדש את הסשן עם מצב הרשאות plan

אתה: "stop all sessions"
Claude: יוצא בעדינות מכל הסשנים המנוהלים

אתה: "help"
Claude: מדפיס את רשימת הפקודות השיחותיות המלאה
```

הפקודות האלה עובדות בכל שפה. אם מקלידים את המקבילה בספרדית, יפנית, עברית, או כל שפה אחרת — Claude מסיק את הכוונה ומריץ את הפקודה המתאימה.

הקלד `help` בתוך כל סשן לצפייה ברשימת הפקודות המלאה.

### סשן הבית

סשן הבית הוא סשן לשימוש כללי שגר בספריית הבסיס (`~/Claude` כברירת מחדל). הוא מופעל אוטומטית בכניסה למערכת כאשר `LAUNCHAGENT_MODE=home`, ונותן לך סשן Claude אחד תמיד-מוכן הנגיש מהטלפון. השתמש בו לניהול כל הסשנים האחרים שלך מבלי להפעיל קודם סשנים ספציפיים לפרויקטים.

סשן הבית הוא תמיד **מוגן** — `--shutdown home` מסרב לעצור אותו ללא `--force`. סשנים מוגנים מסומנים ב-`*` בפלט הסטטוס (למשל `active*`).

## מה זה עושה

מאחורי הקלעים, claude-mux מטפל ב:

- **סשני tmux מתמשכים** עם Remote Control מופעל, כך שכל סשן נגיש מאפליקציית Claude לנייד
- **חידוש שיחות** — מחדש את השיחה האחרונה (`claude -c`) בעת הפעלה מחדש, תוך שמירת ההקשר
- **הזרקת system prompt** — כל סשן מקבל פקודות לניהול עצמי, ניתוב פקודות slash, ומודעות לחשבון SSH
- **תבניות CLAUDE.md** — שמור קבצי תבניות (למשל `web.md`, `python.md`) ב-`~/.claude-mux/templates/` והחל אותם על פרויקטים חדשים
- **תמיכה במספר CLI-coders** — יוצר `AGENTS.md` ו-`GEMINI.md` כסימלינקים ל-`CLAUDE.md` כך ש-Codex CLI, Gemini CLI וכלים נוספים חולקים את אותן הוראות
- **הרשאות מאושרות אוטומטית** — מוסיף את claude-mux לרשימת ההיתר של כל פרויקט כך ש-Claude יכול להריץ פקודות סשן ללא בקשת אישור
- **העברת תהליכים תועים** — אם Claude כבר רץ מחוץ ל-tmux, מעביר אותו לסשן מנוהל
- **שיפורי איכות חיים של Tmux** — תמיכת עכבר, scrollback של 50k, clipboard, 256-color, מקשים מורחבים, ניטור פעילות, כותרות טאב

> **הערה:** זה שונה מ-`claude --worktree --tmux`, שיוצר סשן tmux ל-git worktree מבודד. claude-mux מנהל סשנים מתמשכים לספריות הפרויקט הממשיות שלך, עם Remote Control והזרקת system prompt.

## דרישות

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## התקנה

```bash
./install.sh
```

המתקין האינטראקטיבי שואל היכן ממוקמים פרויקטי Claude שלך, האם להפעיל סשן בית בכניסה למערכת, ובאיזה מודל להשתמש. הוא מתקין את `claude-mux` ל-`~/bin`, יוצר את `~/.claude-mux/config`, ומגדיר את ה-LaunchAgent.

השתמש ב-`--non-interactive` כדי לדלג על הנחיות ולקבל ברירות מחדל.

אפשרויות:

```bash
./install.sh --non-interactive                     # דלג על הנחיות, השתמש בברירות מחדל
./install.sh --base-dir ~/work/claude              # השתמש בספריית בסיס אחרת
./install.sh --launchagent-mode none               # השבת התנהגות LaunchAgent
./install.sh --home-model haiku                    # השתמש ב-Haiku לסשן הבית
./install.sh --no-launchagent                      # דלג על התקנת LaunchAgent לחלוטין
```

ה-LaunchAgent מריץ את `claude-mux --autolaunch` בכניסה למערכת עם השהיית הפעלה של 45 שניות כדי לאפשר לשירותי המערכת להתאתחל.

## סטטוסי סשן

| סטטוס | משמעות |
|--------|---------|
| `active` | סשן tmux קיים, Claude רץ, ו-tmux client מקומי מחובר |
| `running` | סשן tmux קיים ו-Claude רץ (ללא client מקומי מחובר) |
| `stopped` | סשן tmux קיים אך Claude יצא |
| `idle` | פרויקט `.claude/` קיים תחת `BASE_DIR` אך אין לו סשן tmux של claude-mux רץ (מוצג רק עם `-L`) |

`*` נגררת על כל סטטוס מציינת שהסשן מוגן ודורש `--force` כדי לכבותו (למשל `active*`, `running*`). סשן הבית הוא תמיד מוגן.

הרצת `claude-mux` בספרייה שכבר יש לה סשן רץ מחברת אליו. ניתן לחבר טרמינלים מרובים לאותו סשן (התנהגות tmux סטנדרטית).

## הגדרות

בהרצה ראשונה, `~/.claude-mux/config` נוצר אוטומטית עם כל ההגדרות מסומנות כהערות. ערוך אותו כדי לעקוף ברירות מחדל — הסקריפט עצמו אף פעם לא צריך להיות שונה ישירות.

| משתנה | ברירת מחדל | תיאור |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | ספריית שורש לסריקה של פרויקטי Claude (ספריות המכילות `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | ספרייה לקובץ `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | הגדרת `permissions.defaultMode` של Claude בכל פרויקט. ערכים תקפים: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. הגדר ל-`""` כדי להשבית. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | כאשר `true`, סשני Claude יכולים לשלוח פקודות slash לסשנים אחרים - שימושי לתזמור מולטי-סוכן |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | ספרייה המכילה קבצי תבנית CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | תבנית ברירת מחדל המוחלת על פרויקטים חדשים (`-n`). הגדר ל-`""` כדי להשבית. |
| `SLEEP_BETWEEN` | `5` | שניות בין הפעלות סשנים כאשר `-a` בשימוש. הגדל אם רישום RC נכשל. |
| `HOME_SESSION_MODEL` | `""` | מודל לסשן הבית. ערכים תקפים: `sonnet`, `haiku`, `opus`. ריק יורש את ברירת המחדל של Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | רשימת קבצים מופרדת ברווחים ליצירה כסימלינקים ל-`CLAUDE.md` עבור כלי AI CLI אחרים. הגדר ל-`""` כדי להשבית. |
| `LAUNCHAGENT_MODE` | `home` | התנהגות LaunchAgent בכניסה למערכת: `none` (לא לעשות כלום) או `home` (להפעיל סשן בית מוגן). `LAUNCHAGENT_ENABLED=true` ישן מטופל כ-`home`. |

**אפשרויות סשן Tmux** (כולן ניתנות להגדרה, כולן מופעלות כברירת מחדל):

| משתנה | ברירת מחדל | תיאור |
|----------|---------|-------------|
| `TMUX_MOUSE` | `true` | תמיכת עכבר - גלילה, בחירה, שינוי גודל panes |
| `TMUX_HISTORY_LIMIT` | `50000` | גודל מאגר scrollback בשורות (ברירת המחדל של tmux היא 2000) |
| `TMUX_CLIPBOARD` | `true` | אינטגרציית clipboard מערכת דרך OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | סוג טרמינל לעיבוד צבע נכון |
| `TMUX_EXTENDED_KEYS` | `true` | רצפי מקשים מורחבים כולל Shift+Enter (דורש tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | השהיית מקש escape במילישניות (ברירת המחדל של tmux היא 500) |
| `TMUX_TITLE_FORMAT` | `#S` | פורמט כותרת טרמינל/טאב (`#S` = שם סשן, `""` כדי להשבית) |
| `TMUX_MONITOR_ACTIVITY` | `true` | התראה כאשר מתרחשת פעילות בסשנים אחרים |

## מבנה הספריות

פרויקטים מתגלים על ידי נוכחות של ספריית `.claude/`, בכל עומק:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ יש .claude/ - מנוהל
│   │   └── .claude/
│   ├── project-b/          # ✓ יש .claude/ - מנוהל
│   │   └── .claude/
│   └── -archived/          # ✗ מוחרג (מתחיל ב-)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ יש .claude/ - מנוהל
│   │   └── .claude/
│   ├── .hidden/            # ✗ מוחרג (ספרייה מוסתרת)
│   │   └── .claude/
│   └── project-d/          # ✗ אין .claude/ - לא פרויקט Claude
├── deep/nested/project-e/  # ✓ יש .claude/ - נמצא בכל עומק
│   └── .claude/
└── ignored-project/        # ✗ מוחרג (.ignore-claudemux)
    ├── .claude/
    └── .ignore-claudemux
```

שמות סשן נגזרים משמות ספריות: רווחים הופכים למקפים, תווים שאינם אלפא-נומריים (חוץ ממקפים) מוחלפים, ומקפים מובילים/נגררים מוסרים. ספריות ששמן עובר ניקוי לריק מדולגות עם אזהרת log.

## System Prompt של סשן

כל סשן Claude מופעל עם `--append-system-prompt` המכיל הקשר אודות הסביבה שלו:

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

כאשר `ALLOW_CROSS_SESSION_CONTROL=true`, פקודת השליחה משתנה כדי לאפשר מיקוד לכל סשן, לא רק לעצמו. הנתיב הוא הנתיב המוחלט לסקריפט בזמן ההפעלה, כך שסשנים אינם תלויים ב-`PATH`.

## עיון ב-CLI

לרוב אין צורך בפקודות אלה ישירות — Claude מריץ אותן עבורך מתוך הסשנים. הן זמינות לסקריפטים, אוטומציה, או כשאינך בתוך סשן.

```bash
# הפעלה וחיבור
claude-mux                       # הפעל את Claude בספרייה הנוכחית והתחבר
claude-mux ~/projects/my-app     # הפעל את Claude בספרייה והתחבר
claude-mux -d ~/projects/my-app  # זהה לעיל (צורה מפורשת)
claude-mux -t my-app             # התחבר לסשן tmux קיים

# יצירת פרויקטים חדשים
claude-mux -n ~/projects/app     # צור פרויקט Claude חדש והתחבר
claude-mux -n ~/new/path/app -p  # זהה, יוצר את הספרייה ואת ספריות האב
claude-mux -n ~/app --template web        # פרויקט חדש עם תבנית CLAUDE.md ספציפית
claude-mux -n ~/app --no-multi-coder      # פרויקט חדש ללא סימלינקים של AGENTS.md/GEMINI.md

# ניהול סשנים
claude-mux -l                    # הצג סשנים לפי סטטוס (active, running, stopped)
claude-mux -L                    # הצג את כל הפרויקטים (active + idle)
claude-mux -s my-app '/model sonnet'      # שלח פקודת slash לסשן
claude-mux --shutdown my-app              # כבה סשן ספציפי
claude-mux --shutdown                     # כבה את כל הסשנים המנוהלים
claude-mux --shutdown home --force        # כבה את סשן הבית המוגן
claude-mux --restart my-app              # הפעל מחדש סשן ספציפי
claude-mux --restart                     # הפעל מחדש את כל הסשנים הרצים
claude-mux --permission-mode plan my-app  # הפעל מחדש סשן עם מצב plan
claude-mux -a                    # הפעל את כל הסשנים המנוהלים תחת BASE_DIR

# אחר
claude-mux --list-templates      # הצג תבניות CLAUDE.md זמינות
claude-mux --guide               # הצג פקודות שיחה לשימוש בתוך סשנים
claude-mux --dry-run             # הצג תצוגה מקדימה של פעולות ללא ביצוע
claude-mux --version             # הדפס גרסה
claude-mux --help                # הצג את כל האפשרויות

# צפה ב-log
tail -f ~/Library/Logs/claude-mux.log
```

כשהוא מורץ מהטרמינל, הפלט משתקף ל-stdout בזמן אמת. כשמורץ דרך LaunchAgent, הפלט מועבר רק לקובץ ה-log.

## פתרון תקלות

### סשנים מציגים "Not logged in · Run /login"

זה קורה בהפעלה ראשונה אם ה-keychain של macOS נעול (נפוץ כשהסקריפט רץ לפני שה-keychain פתוח לאחר הכניסה למערכת). תיקון:

```bash
# פתח את ה-keychain בטרמינל רגיל
security unlock-keychain

# לאחר מכן השלם אימות בסשן רץ אחד כלשהו
claude-mux -t <any-session>
# הרץ /login והשלם את תהליך הדפדפן
```

לאחר השלמת אימות פעם אחת, הרוג והפעל מחדש את כל הסשנים — הם יקלטו את האישור המאוחסן אוטומטית.

### סשנים לא מופיעים ב-Claude Code Remote

סשנים חייבים להיות מאומתים (לא מציגים "Not logged in"). לאחר הפעלה מאומתת נקייה הם אמורים להופיע ברשימת ה-RC תוך כמה שניות.

### קלט מרובה-שורות ב-tmux

הפקודה `/terminal-setup` לא יכולה לרוץ בתוך tmux. claude-mux מפעיל את tmux `extended-keys` כברירת מחדל (`TMUX_EXTENDED_KEYS=true`), שתומך ב-Shift+Enter ברוב הטרמינלים המודרניים. אם Shift+Enter לא עובד, השתמש ב-`\` + Return כדי להזין שורות חדשות בהנחיה שלך.

### "Ready." בתחילת סשן

כשסשן מתחיל או מופעל מחדש, claude-mux שולח אוטומטית הודעת `ready` לאחר שסיים לטעון Claude. ה-injection מורה ל-Claude להגיב ב-"Ready." ולא בשום דבר נוסף. זה מאשר שהסשן פעיל וה-injection עובד.

### פקודות slash דרך Remote Control

פקודות slash (למשל `/model`, `/clear`) [אינן נתמכות באופן מקורי](https://github.com/anthropics/claude-code/issues/30674) בסשני RC. claude-mux עוקף זאת — לכל סשן מוזרק `claude-mux -s` כך ש-Claude יכול לשלוח פקודות slash לעצמו דרך tmux.

## לוגים

- `~/Library/Logs/claude-mux.log` - כל פעולות הסקריפט עם חותמות זמן UTC (ניתן להגדרה דרך `LOG_DIR`)

עבור דיבוג ברמה נמוכה של LaunchAgent, השתמש ב-Console.app או `log show`.
