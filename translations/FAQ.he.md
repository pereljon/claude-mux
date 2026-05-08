# שאלות נפוצות

[English](../FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · **עברית** · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## מה זה claude-mux?

סקריפט shell שעוטף את Claude Code ב-tmux לסשנים מתמשכים. סשנים שורדים סגירת טרמינל, מחדשים הקשר שיחה בעת הפעלה מחדש, ונגישים מאפליקציית Claude לנייד דרך Remote Control. מנהלים הכול על ידי שיחה עם Claude בתוך סשן.

## האם זה עובד על Linux?

עדיין לא. macOS בלבד (Apple Silicon ו-Intel). תמיכה ב-Linux מתוכננת לגרסה v2.0. תוכנית ההתקנה רצה על Linux אבל מדלגת על הגדרת LaunchAgent ומדפיסה הערה. הקובץ הבינארי עצמו עובד, אבל אין עדיין שירות systemd או מנגנון הפעלה אוטומטית מקביל.

## מה זה סשן הבית?

סשן הבית הוא סשן Claude לשימוש כללי שגר בספריית הבסיס (`~/Claude` כברירת מחדל). כאשר `LAUNCHAGENT_MODE=home` (ברירת המחדל), הוא מופעל אוטומטית בכניסה למערכת ונשאר רץ כל היום. הוא **מוגן** כברירת מחדל, כלומר `--shutdown home` מסרב לעצור אותו ללא `--force`.

השתמש בסשן הבית כנקודת כניסה תמיד-זמינה מאפליקציית Claude לנייד. משם ניתן לרשום פרויקטים, להפעיל סשנים אחרים, לנהל config, ולבצע עבודה כללית שלא שייכת לפרויקט ספציפי.

## מה זה Remote Control?

Remote Control (RC) הוא תכונה של Claude Code שמאפשרת להתחבר לסשן Claude רץ מאפליקציית Claude לנייד או מ-Claude Desktop. claude-mux מפעיל כל סשן עם `--remote-control` מופעל, כך שכל הסשנים מופיעים ברשימת ה-RC אוטומטית. לאחר חיבור, מדברים עם Claude כמו בטרמינל. claude-mux גם עוקף מגבלות RC כמו פקודות slash שלא עובדות באופן מקורי, על ידי ניתוב דרך tmux.

## מה הם מצבי הרשאות?

ל-Claude Code יש ארבעה מצבי הרשאות ששולטים בכמה אוטונומיה יש ל-Claude:

| מצב | התנהגות |
|------|----------|
| `default` | Claude שואל לפני הרצת פקודות או עריכת קבצים |
| `acceptEdits` | Claude מחיל עריכות קבצים אוטומטית אבל שואל לפני פקודות shell |
| `plan` | Claude יכול רק לקרוא ולתכנן, ללא כתיבה או פקודות |
| `bypassPermissions` | Claude מריץ הכול ללא שאילתה (דורש אישור בהפעלה ראשונה) |

הגדר ברירת מחדל לכל הפרויקטים דרך `DEFAULT_PERMISSION_MODE` ב-config. החלף סשן רץ באמירת "switch this session to plan mode" (או כל שם מצב). "yolo" הוא כינוי ל-`bypassPermissions`.

מעבר ל-`bypassPermissions` ממצב אחר משתמש בניווט Shift+Tab ולא דורש הפעלה מחדש. מעבר מ-`bypassPermissions` למצב אחר דורש הפעלה מחדש, ו-claude-mux מטפל בזה אוטומטית.

## איך מאפסים סשן?

שלוש אפשרויות, תלוי במה שצריך:

- **Clear** ("clear this session"): שולח `/clear` לסשן. מוחק היסטוריית שיחות ומתחיל מחדש. הסשן ממשיך לרוץ.
- **Compact** ("compact this session"): שולח `/compact` לסשן. מסכם את השיחה להקשר קצר יותר, ומשחרר את חלון ההקשר. ההיסטוריה נשמרת בצורה מכווצת.
- **Restart** ("restart this session"): מכבה את Claude ומפעיל מחדש עם `claude -c`, שמחדש את השיחה האחרונה. השתמש בזה כשצריך תהליך נקי (למשל, אחרי שינוי מצבי הרשאות או כש-Claude תקוע).

## מה הן תבניות?

תבניות הן קבצי CLAUDE.md לשימוש חוזר המאוחסנים ב-`~/.claude-mux/templates/`. כשיוצרים פרויקט חדש עם `-n`, תבנית ברירת המחדל (או אחת שמציינים עם `--template NAME`) מועתקת לפרויקט כ-CLAUDE.md שלו.

יצירת תבנית: "save this as a template named web" (מעתיק את ה-CLAUDE.md של הפרויקט הנוכחי ל-`~/.claude-mux/templates/web.md`).

שימוש בתבנית: `claude-mux -n ~/projects/my-app --template web` או מתוך סשן: "create a new project called my-app using the web template".

רשימת תבניות: "list templates" או `claude-mux --list-templates`.

## איך עובד טיפ-היום?

Claude Code Stop hook ב-`.claude/settings.local.json` של כל פרויקט קורא ל-`claude-mux --tipotd` אחרי כל סיבוב שיחה. הפקודה בודקת אם כבר הוצג טיפ היום (דרך `~/.claude-mux/.tip-date`). אם כן, היא יוצאת תוך כ-6ms. אם לא, היא מדפיסה טיפ ורושמת את התאריך של היום.

טיפים מופעלים כברירת מחדל (`TIP_OF_DAY=true`). החלף עם "enable tips" או "disable tips" בתוך כל סשן. `TIP_MODE=daily` מציג את אותו טיפ כל היום; `TIP_MODE=random` בוחר טיפ אקראי לכל הפעלה (עם ה-Stop hook, זה אומר טיפ אקראי אחד ליום בגלל השער היומי).

הפקודה `--tip` תמיד עובדת ללא קשר לשער היומי, אז אפשר לומר "tip" בכל זמן.

## אפשר להשתמש עם מספר חשבונות GitHub?

כן. claude-mux מזהה ערכי `Host github.com-*` ב-`~/.ssh/config` ומזריק אותם ל-system prompt של כל סשן. Claude יודע אילו כינויי SSH זמינים ויכול להשתמש בנכון כשמגדיר git remotes.

דוגמת הגדרת `~/.ssh/config`:

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

Claude ידע להשתמש ב-`git@github.com-work:org/repo.git` עבור repos של עבודה ו-`git@github.com-personal:user/repo.git` עבור אישיים.

## היכן מאוחסן מצב?

| מיקום | מה גר שם |
|----------|-----------------|
| `~/.claude-mux/config` | הגדרות משתמש (נטען כ-bash) |
| `~/.claude-mux/templates/` | קבצי תבנית CLAUDE.md |
| `~/.claude-mux/.tip-date` | תאריך הטיפ האחרון שהוצג |
| `~/.claude-mux/.update-check` | תוצאת בדיקת גרסה שמורה |
| `~/Library/Logs/claude-mux.log` | קובץ log (ניתן להגדרה דרך `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | קובץ plist של LaunchAgent (נוצר על ידי `--install`) |
| `.claudemux-protected` (לכל פרויקט) | מסמן סשן כמוגן מכיבוי |
| `.claudemux-ignore` (לכל פרויקט) | מסתיר פרויקט מרשימות |

קובצי סמן (`.claudemux-*`) גרים בספריית השורש של כל פרויקט ועוברים עם התיקייה בעת שינוי שם, העברה וסנכרון. הם מתווספים אוטומטית ל-`.gitignore`.

היסטוריית שיחות מנוהלת על ידי Claude Code עצמו, מאוחסנת תחת `~/.claude/projects/`.

## מה קורה עם עדכון אוטומטי אם עשיתי fork ל-claude-mux?

בדיקת העדכון והפקודה `--update` מקודדות בקוד את `pereljon/claude-mux` כ-repo ב-GitHub. אם עשית fork, בדיקות עדכון עדיין ישוו מול ה-release של ה-upstream, ו-`--update` ידרוס את הקובץ הבינארי של ה-fork עם upstream. הגדר `UPDATE_CHECK=false` ב-`~/.claude-mux/config` כדי להשבית, או שנה את כתובת ה-repo בפונקציות `check_for_update()` ו-`do_update()` בסקריפט.

## איך מתקינים דרך Homebrew?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

עדכון עם `brew upgrade claude-mux`. הערה: אם התקנת דרך Homebrew, `--update` מאציל אוטומטית ל-`brew upgrade`.

## מה ההבדל בין זה ל-`claude --worktree --tmux`?

`claude --worktree --tmux` יוצר סשן tmux ל-git worktree מבודד, מיועד למשימות קידוד מקבילות. claude-mux מנהל סשנים מתמשכים לספריות הפרויקט הממשיות שלך, עם Remote Control מופעל, הזרקת system prompt לניהול עצמי, חידוש שיחות, וניהול מחזור חיי סשנים. הם פותרים בעיות שונות.

## למה סשנים מציגים "Not logged in"?

זה קורה בהפעלה ראשונה אם ה-keychain של macOS נעול, מה שנפוץ כשה-LaunchAgent מתחיל לפני שפותחים את ה-keychain אחרי הכניסה למערכת. תקן על ידי הרצת `security unlock-keychain` בטרמינל רגיל, ואז התחבר לכל סשן (`claude-mux -t <name>`) והרץ `/login` להשלמת תהליך האימות בדפדפן. לאחר מכן, הפעל מחדש את כל הסשנים והם יקלטו את האישור המאוחסן.

## אפשר לחבר מספר טרמינלים לאותו סשן?

כן. זו התנהגות tmux סטנדרטית. הרצת `claude-mux` בספרייה שכבר יש לה סשן רץ מחברת אליו. מספר טרמינלים רואים את אותו תוכן סשן בזמן אמת.

## איך עוצרים את סשן הבית לצמיתות?

ל-LaunchAgent יש `KeepAlive: true`, כך שהריגת סשן הבית גורמת להפעלה מחדש תוך כ-60 שניות. כדי לעצור לצמיתות, השבת את ה-LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## מה המשמעות של ההודעה "Session ready!"?

כשסשן מתחיל או מופעל מחדש, claude-mux שולח הנחיית `Ready?` אחרי ש-Claude סיים לטעון. ה-injection מורה ל-Claude להגיב ב-"Session ready!" ולא בשום דבר נוסף. זה מאשר שהסשן פעיל וה-system prompt injection עובד. אפשר להתעלם מזה.

## איך מסתירים פרויקט מרשימות?

אמור "hide this project" בתוך כל סשן, או הרץ `claude-mux --hide my-project`. זה יוצר קובץ סמן `.claudemux-ignore`. הפרויקט לא יופיע בפלט `claude-mux -L`. לצפייה בפרויקטים מוסתרים: `claude-mux -L --hidden`. לביטול הסתרה: "show this project" או `claude-mux --show my-project`.

## איך מסירים את claude-mux?

```bash
claude-mux --uninstall
```

זה מסיר tip hooks וכללי הרשאות מכל הפרויקטים, מנטרל את ה-LaunchAgent, ואופציונלית מוחק את `~/.claude-mux/`. הפקודה מדווחת על נתיב הקובץ הבינארי כך שניתן למחוק אותו ידנית (או `brew uninstall claude-mux` אם הותקן דרך Homebrew).

## האם פקודות slash עובדות דרך Remote Control?

לא באופן מקורי. Claude Code לא תומך בפקודות slash (`/model`, `/clear` וכו') בסשני RC. claude-mux עוקף זאת על ידי הזרקת `claude-mux -s` לכל סשן כך ש-Claude יכול לשלוח פקודות slash לעצמו דרך tmux. פשוט אמור "switch to Haiku" או "compact this session" ו-Claude מטפל בזה.

## לא מצליח לבחור טקסט בסשן

החזק **Option** (macOS) או **Shift** (טרמינלים של Linux/Windows) תוך כדי לחיצה וגרירה. זה עוקף את לכידת העכבר של tmux ומעתיק את הבחירה ל-clipboard המערכת. לא צריך שינויי הגדרות.

## אילו שפות נתמכות לפקודות שיחותיות?

כולן. ביטויי ההפעלה ("help", "status", "list sessions" וכו') עובדים בכל שפה. Claude מסיק את הכוונה מהשפה הטבעית של המשתמש ומריץ את הפקודה המתאימה. ה-README מתורגם גם ל-12 שפות.
