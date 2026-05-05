# claude-mux - מולטיפלקסר ל-Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · **עברית** · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

סשנים מתמשכים של Claude Code לכל הפרויקטים שלך - נגישים מכל מקום דרך אפליקציית Claude לנייד. ***מנוהל על ידי Claude!***

## למה

Remote Control מבטיח Claude Code מכל מקום — אבל ללא ניהול סשנים, זו ממשק סוג ב' אפילו מ-Claude Desktop:

- סשנים מתים כשסוגרים את הטרמינל, וההקשר של השיחה לא מתחדש אוטומטית
- אין בסיס קבוע — כשמרימים את הטלפון, שום דבר לא רץ אלא אם השארת משהו פתוח
- אם סשן לא רץ, Remote Control חסר תועלת — לא ניתן להגיע לפרויקט ולא להתחיל אחד
- אפילו בסשן RC פעיל, פקודות slash לא עובדות — אין החלפת מודל, דחיסה, או שינוי מצב הרשאות
- התחלת פרויקט חדש דורשת יצירה ידנית של תיקייה, אתחול git, כתיבת CLAUDE.md, הגדרת מצב הרשאות ובחירת מודל — שום דבר מזה לא ניתן לעשות מ-RC
- ניהול פרויקטים מרובים אומר הפעלות ידניות מרובות של טרמינל ללא תמונה כוללת של מה רץ ובאיזה מצב

claude-mux פותר את כל אלה. הוא עוטף את Claude Code ב-tmux כך שסשנים נשמרים, מזריק system prompt כדי ש-Claude יוכל לנהל את הסשנים שלו עצמו, ומנתב פקודות slash דרך tmux כך שהן עובדות דרך Remote Control. ברגע שסשן רץ, מנהלים הכול על ידי שיחה עם Claude — בטרמינל או באפליקציית הנייד.

## התחלה מהירה

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

```bash
cd ~/path/to/your/project
claude-mux
```

או:

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


אתה: "stop all sessions"
Claude: יוצא בעדינות מכל הסשנים המנוהלים

אתה: "help"
Claude: מדפיס את רשימת הפקודות השיחותיות המלאה
```

הפקודות האלה עובדות בכל שפה. אם מקלידים את המקבילה בספרדית, יפנית, עברית, או כל שפה אחרת — Claude מסיק את הכוונה ומריץ את הפקודה המתאימה.

הקלד `help` בתוך כל סשן לצפייה ברשימת הפקודות המלאה.

### סשן הבית

סשן הבית הוא סשן לשימוש כללי שגר בספריית הבסיס (`~/Claude` כברירת מחדל). הוא מופעל אוטומטית בכניסה למערכת כאשר `LAUNCHAGENT_MODE=home`, ונותן לך סשן Claude אחד תמיד-מוכן הנגיש מהטלפון. השתמש בו לניהול כל הסשנים האחרים שלך מבלי להפעיל קודם סשנים ספציפיים לפרויקטים.

סשן הבית הוא **מוגן** כברירת מחדל — `--shutdown home` מסרב לעצור אותו ללא `--force`. ההגנה מנוהלת על ידי קובץ הסמן `.claudemux-protected` ב-`$BASE_DIR`, שנוצר על ידי `claude-mux --install`. סשנים מוגנים מוצגים עם `protected` בעמודת הסטטוס; הסשן הנוכחי מסומן ב-`>` בעמודת השם.

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

### Homebrew (מומלץ)

```bash
brew tap pereljon/tap
brew install claude-mux
```

לאחר ההתקנה, הפעל את פקודת ההגדרה כדי ליצור את ה-config ולהתקין אופציונלית את ה-LaunchAgent (סשן בית בעת כניסה למערכת):

```bash
claude-mux --install
```

לעדכון:

```bash
brew upgrade claude-mux       # או: claude-mux --update  (עובד מתוך כל סשן)
```

### ידני

```bash
./install.sh
```

`install.sh` מעתיק את הקובץ הבינארי ל-`~/bin` ומוסיף אותו ל-`PATH`. לאחר מכן, הפעל:

```bash
claude-mux --install
```

ההגדרה האינטראקטיבית שואלת היכן ממוקמים פרויקטי Claude שלך, האם להפעיל סשן בית בכניסה למערכת, ובאיזה מודל להשתמש. היא יוצרת את `~/.claude-mux/config` ומתקינה את ה-LaunchAgent.

השתמש ב-`--non-interactive` כדי לדלג על הנחיות ולקבל ברירות מחדל.

אפשרויות:

```bash
claude-mux --install --non-interactive                     # דלג על הנחיות, השתמש בברירות מחדל
claude-mux --install --base-dir ~/work/claude              # השתמש בספריית בסיס אחרת
claude-mux --install --launchagent-mode none               # השבת התנהגות LaunchAgent
claude-mux --install --home-model haiku                    # השתמש ב-Haiku לסשן הבית
claude-mux --install --no-launchagent                      # דלג על התקנת LaunchAgent לחלוטין
```

ה-LaunchAgent מריץ את `claude-mux --autolaunch` בכניסה למערכת עם השהיית הפעלה של 45 שניות כדי לאפשר לשירותי המערכת להתאתחל.

## סטטוסי סשן

| סטטוס | משמעות |
|--------|---------|
| `running` | סשן tmux קיים ו-Claude רץ |
| `protected` | כמו `running`, אך הסשן מוגן — `--shutdown` דורש `--force` כדי לעצור אותו |
| `stopped` | סשן tmux קיים אך Claude יצא |
| `idle` | פרויקט `.claude/` קיים תחת `BASE_DIR` אך אין לו סשן tmux של claude-mux רץ (מוצג רק עם `-L`) |

קידומת `>` על שם הסשן (למשל `> home`) מסמנת את הסשן שהריץ את פקודת הרשימה.

הרצת `claude-mux` בספרייה שכבר יש לה סשן רץ מחברת אליו. ניתן לחבר טרמינלים מרובים לאותו סשן (התנהגות tmux סטנדרטית).

## סמני פרויקט

מצב לכל פרויקט מאוחסן בקובצי סמן בשורש הפרויקט, לא בהגדרות מרכזיות. סמנים משתמשים בקידומת `.claudemux-` ומתווספים אוטומטית ל-`.gitignore` כאשר נוצרים בפרויקט עם מעקב git.

| סמן | משמעות | CLI |
|-----|---------|-----|
| `.claudemux-protected` | הסשן מוגן בעת הפעלה — `--shutdown` דורש `--force` | `--protect` / `--unprotect` |
| `.claudemux-ignore` | הפרויקט מוסתר מרשימות `claude-mux -L` | `--hide` / `--show` |

```bash
claude-mux --hide                    # הסתר את הפרויקט הנוכחי מרשימות -L
claude-mux --show                    # בטל הסתרה של הפרויקט הנוכחי
claude-mux --protect                 # הגן על הסשן הזה מכיבוי בטעות
claude-mux --unprotect               # הסר הגנה
claude-mux -L --hidden               # הצג רק פרויקטים מוסתרים
claude-mux --delete ~/projects/old   # העבר את תיקיית הפרויקט לאשפה של המערכת (macOS)
```

סמנים עוברים עם תיקיית הפרויקט בעת שינוי שם והעברה. תבנית `.gitignore` אחת (`.claudemux-*`) מכסה את כל הסמנים הנוכחיים והעתידיים.

## הגדרות

`~/.claude-mux/config` נוצר על ידי `claude-mux --install` (או בהרצה ראשונה של כל פקודה אם אין config קיים). ערוך אותו כדי לעקוף ברירות מחדל — הסקריפט עצמו אף פעם לא צריך להיות שונה ישירות.

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
└── ignored-project/        # ✗ מוחרג (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

שמות סשן נגזרים משמות ספריות: רווחים הופכים למקפים, תווים שאינם אלפא-נומריים (חוץ ממקפים) מוחלפים, ומקפים מובילים/נגררים מוסרים. ספריות ששמן עובר ניקוי לריק מדולגות עם אזהרת log.

## System Prompt של סשן

כל סשן Claude מופעל עם `--append-system-prompt` המכיל הקשר אודות הסביבה שלו:

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

(שורת העדכון אופציונלית — מופיעה רק כשיש עדכון ממתין.)

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
claude-mux -L --hidden           # הצג רק פרויקטים מוסתרים
claude-mux -s my-app '/model sonnet'      # שלח פקודת slash לסשן
claude-mux --shutdown my-app              # כבה סשן ספציפי
claude-mux --shutdown                     # כבה את כל הסשנים המנוהלים
claude-mux --shutdown home --force        # כבה את סשן הבית המוגן
claude-mux --restart my-app              # הפעל מחדש סשן ספציפי
claude-mux --restart                     # הפעל מחדש את כל הסשנים הרצים
claude-mux --permission-mode plan my-app  # הפעל מחדש סשן עם מצב plan
claude-mux -a                    # הפעל את כל הסשנים המנוהלים תחת BASE_DIR

# סמני פרויקט
claude-mux --hide                    # הסתר את הפרויקט הנוכחי מרשימות -L
claude-mux --hide ~/projects/old     # הסתר פרויקט ספציפי
claude-mux --show                    # בטל הסתרה של הפרויקט הנוכחי
claude-mux --protect                 # הגן על הסשן הזה מכיבוי בטעות
claude-mux --unprotect               # הסר הגנה
claude-mux --delete ~/projects/old           # העבר את תיקיית הפרויקט לאשפה של המערכת (macOS)
claude-mux --delete ~/projects/old --yes     # אותו דבר, ללא בקשת אישור

# אחר
claude-mux --commands            # הצג עיון CLI מלא
claude-mux --config-help         # הצג את כל אפשרויות ה-config עם ברירות מחדל ותיאורים
claude-mux --list-templates      # הצג תבניות CLAUDE.md זמינות
claude-mux --guide               # הצג פקודות שיחה לשימוש בתוך סשנים
claude-mux --install          # הגדרה אינטראקטיבית: config + LaunchAgent
claude-mux --update           # עדכן לגרסה האחרונה
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
