# שאלות נפוצות

[English](../docs/FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · **עברית** · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## מה זה claude-mux?

סקריפט shell שעוטף את Claude Code ב-tmux לסשנים מתמשכים. סשנים שורדים סגירת טרמינל, ממשיכים הקשר שיחה בהפעלה מחדש, ונגישים מאפליקציית Claude לנייד דרך Remote Control. אתה מנהל הכל בשיחה עם Claude בתוך סשן.

## זה עובד על Linux?

עדיין לא. macOS בלבד (Apple Silicon ו-Intel). תמיכה ב-Linux מתוכננת ל-v2.0. תוכנית ההתקנה רצה על Linux אבל מדלגת על הגדרת LaunchAgent ומדפיסה הערה. הקובץ עצמו עובד, אבל עדיין אין שירות systemd או מנגנון הפעלה אוטומטית מקביל.

## מה זה סשן home?

סשן home הוא סשן Claude לשימוש כללי שנמצא בתיקיית הבסיס שלך (`~/Claude` כברירת מחדל). כאשר `LAUNCHAGENT_MODE=home` (ברירת המחדל), הוא מופעל אוטומטית בכניסה למערכת ונשאר פעיל כל היום. הוא **מוגן** כברירת מחדל, כלומר `--shutdown home` מסרב לעצור אותו בלי `--force`.

השתמש בסשן home כנקודת כניסה שתמיד זמינה מאפליקציית Claude לנייד. משם אפשר לרשום פרויקטים, להפעיל סשנים אחרים, לנהל תצורה ולעשות עבודה כללית שלא שייכת לפרויקט ספציפי.

## מה זה Remote Control?

Remote Control (RC) הוא פיצ'ר של Claude Code שמאפשר להתחבר לסשן Claude פעיל מאפליקציית Claude לנייד או מ-Claude Desktop. claude-mux מפעיל כל סשן עם `--remote-control` מופעל, כך שכל הסשנים מופיעים אוטומטית ברשימת RC. לאחר החיבור, מדברים עם Claude בדיוק כמו בטרמינל. claude-mux גם עוקף מגבלות RC כמו פקודות slash שלא עובדות באופן מקורי, על ידי ניתובן דרך tmux.

## מה הם מצבי הרשאות?

ל-Claude Code יש ארבעה מצבי הרשאות ששולטים בכמה אוטונומיה יש ל-Claude:

| מצב | התנהגות |
|------|---------|
| `default` | Claude שואל לפני הרצת פקודות או עריכת קבצים |
| `acceptEdits` | Claude מחיל עריכות קבצים אוטומטית אבל שואל לפני פקודות shell |
| `plan` | Claude יכול רק לקרוא ולתכנן, בלי כתיבה או פקודות |
| `bypassPermissions` | Claude מריץ הכל בלי לשאול (דורש אישור בהפעלה ראשונה) |

הגדר ברירת מחדל לכל הפרויקטים דרך `DEFAULT_PERMISSION_MODE` בתצורה. החלף סשן פעיל על ידי אמירת "עבור את הסשן הזה למצב plan" (או כל שם מצב). "yolo" הוא כינוי ל-`bypassPermissions`.

מעבר ל-`bypassPermissions` ממצב אחר משתמש בניווט Shift+Tab ולא דורש הפעלה מחדש. מעבר מ-`bypassPermissions` למצב אחר דורש הפעלה מחדש, ו-claude-mux מטפל בזה אוטומטית.

## איך מאפסים סשן?

שלוש אפשרויות, תלוי במה שאתה רוצה:

- **ניקוי** ("נקה את הסשן הזה"): שולח `/clear` לסשן. מוחק היסטוריית שיחה ומתחיל מחדש. הסשן ממשיך לרוץ.
- **דחיסה** ("דחוס את הסשן הזה"): שולח `/compact` לסשן. מסכם את השיחה להקשר קצר יותר, משחרר את חלון ההקשר. ההיסטוריה נשמרת בצורה דחוסה.
- **הפעלה מחדש** ("הפעל מחדש את הסשן הזה"): מכבה את Claude ומפעיל אותו מחדש עם `claude -c`, שממשיך את השיחה האחרונה. להשתמש כשצריך תהליך נקי (למשל אחרי שינוי מצב הרשאות או כש-Claude תקוע).

## מה הם תבניות?

תבניות הן קבצי CLAUDE.md לשימוש חוזר שמאוחסנים ב-`~/.claude-mux/templates/`. כשיוצרים פרויקט חדש עם `-n`, תבנית ברירת המחדל (או אחת שנבחרה עם `--template NAME`) מועתקת לפרויקט כ-CLAUDE.md שלו.

יצירת תבנית: "שמור את זה כתבנית בשם web" (מעתיק את CLAUDE.md של הפרויקט הנוכחי ל-`~/.claude-mux/templates/web.md`).

שימוש בתבנית: `claude-mux -n ~/projects/my-app --template web` או מתוך סשן: "צור פרויקט חדש בשם my-app עם תבנית web".

רשימת תבניות: "הצג תבניות" או `claude-mux --list-templates`.

## איך עובד הטיפ היומי?

Claude Code `UserPromptSubmit` hook ב-`.claude/settings.local.json` של כל פרויקט קורא ל-`claude-mux --on-prompt` בכל הודעה. ההודעה הראשונה של היום מזריקה טיפ אחד לשיחה; הודעות מאוחרות יותר באותו יום לא מזריקות כלום. המצב הוא לכל סשן, נשמר ב-`~/.claude-mux/tip-state/<session_id>.json`, כך שכל סשן פעיל מציג את הטיפ פעם ביום. מכיוון שה-hook מזריק להקשר (לא Stop hook שהפלט שלו רק בתמליל), הטיפ גלוי בשיחה וב-Remote Control.

טיפים מופעלים כברירת מחדל (`TIP_OF_DAY=true`). החלף עם "הפעל טיפים" או "כבה טיפים" בתוך כל סשן. `TIP_MODE=daily` מציג את אותו טיפ כל היום; `TIP_MODE=random` בוחר טיפ אקראי.

פקודת `--tip` תמיד עובדת ללא קשר לשער היומי (וללא קשר ל-`TIP_OF_DAY`), אז אפשר לומר "tip" בכל זמן.

## אפשר להשתמש עם מספר חשבונות GitHub?

כן. claude-mux מזהה רשומות `Host github.com-*` ב-`~/.ssh/config` ומזריק אותן ל-system prompt של כל סשן. Claude יודע אילו SSH aliases זמינים ויכול להשתמש בנכון כשמגדירים git remotes.

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

Claude יידע להשתמש ב-`git@github.com-work:org/repo.git` עבור מאגרי עבודה וב-`git@github.com-personal:user/repo.git` עבור אישיים.

## היכן מאוחסן המצב?

| מיקום | מה נמצא שם |
|-------|-----------|
| `~/.claude-mux/config` | תצורת משתמש (נטענת כ-bash) |
| `~/.claude-mux/templates/` | קבצי תבנית CLAUDE.md |
| `~/.claude-mux/tip-state/<session_id>.json` | תאריך טיפ לכל סשן + מצערת התראות עדכון |
| `~/.claude-mux/.update-check` | תוצאת בדיקת גרסה במטמון |
| `~/.claude-mux/.update-checking` | נעילה במהלך בדיקת עדכון ברקע |
| `~/Library/Logs/claude-mux.log` | קובץ לוג (ניתן להגדרה דרך `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | plist של LaunchAgent (נוצר על ידי `--install`) |
| `.claudemux-protected` (לכל פרויקט) | מסמן סשן כמוגן מכיבוי |
| `.claudemux-ignore` (לכל פרויקט) | מסתיר פרויקט מרשימות |

קבצי סימון (`.claudemux-*`) נמצאים בתיקיית השורש של כל פרויקט ונעים עם התיקייה בשינוי שם, העברה וסנכרון. הם מתווספים אוטומטית ל-`.gitignore`.

היסטוריית שיחות מנוהלת על ידי Claude Code עצמו, מאוחסנת תחת `~/.claude/projects/`.

## מה קורה עם עדכון אוטומטי אם עשיתי fork ל-claude-mux?

בדיקת העדכון ופקודת `--update` מקודדות `pereljon/claude-mux` כמאגר GitHub. אם עשית fork, בדיקות עדכון עדיין ישוו מול המהדורה העליונה, ו-`--update` ידרוס את הקובץ הבינארי של ה-fork שלך עם העליון. הגדר `UPDATE_CHECK=false` ב-`~/.claude-mux/config` כדי להשבית, או שנה את כתובת המאגר בפונקציות `check_for_update()` ו-`do_update()` בסקריפט.

## איך מתקינים דרך Homebrew?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

עדכון עם `brew upgrade claude-mux`. הערה: אם התקנת דרך Homebrew, `--update` מעביר אוטומטית ל-`brew upgrade`.

## מה ההבדל בין זה ל-`claude --worktree --tmux`?

`claude --worktree --tmux` יוצר סשן tmux עבור git worktree מבודד, מעוצב למשימות קידוד מקבילות. claude-mux מנהל סשנים מתמשכים לתיקיות הפרויקט בפועל שלך, עם Remote Control מופעל, הזרקת system prompt לניהול עצמי, המשך שיחה וניהול מחזור חיי סשן. הם פותרים בעיות שונות.

## מה ההבדל בין זה ל-Claude Cowork Dispatch?

Dispatch מפעיל משימות מאפליקציית Claude למחשב, אבל דורש שהאפליקציה תרוץ ולא קשור לפרויקט ספציפי. claude-mux מנהל סשנים מתמשכים וקשורים לפרויקט ששורדים אתחולים ונגישים מכל מקום דרך Remote Control - בלי צורך באפליקציית שולחן עבודה.

## למה סשנים מציגים "Not logged in"?

זה קורה בהפעלה ראשונה אם מחזיק המפתחות של macOS נעול, מה שנפוץ כאשר ה-LaunchAgent מופעל לפני שאתה פותח את מחזיק המפתחות אחרי כניסה. תיקון: הרץ `security unlock-keychain` בטרמינל רגיל, ואז התחבר לכל סשן (`claude-mux -t <name>`) והרץ `/login` להשלמת תהליך האימות בדפדפן. אחרי זה, הפעל מחדש את כל הסשנים והם יקלטו את האישור השמור.

## אפשר לחבר מספר טרמינלים לאותו סשן?

כן. זו התנהגות סטנדרטית של tmux. הרצת `claude-mux` בתיקייה שכבר יש בה סשן פעיל מתחברת אליו. מספר טרמינלים רואים את אותו תוכן סשן בזמן אמת.

## איך עוצרים את סשן home לצמיתות?

ל-LaunchAgent יש `KeepAlive: true`, כך שהריגת סשן home מפעילה הפעלה מחדש תוך כ-60 שניות. כדי לעצור לצמיתות, השבת את ה-LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## מה אומרת ההודעה "Session ready!"?

כשסשן מופעל או מופעל מחדש, claude-mux שולח הודעת `Ready?` אחרי ש-Claude מסיים להיטען. ההזרקה אומרת ל-Claude להגיב עם "Session ready!" ותו לא. זה מאשר שהסשן חי וש-system prompt injection עובד. אפשר להתעלם מזה.

## איך מסתירים פרויקט מרשימות?

אמור "הסתר את הפרויקט הזה" בתוך כל סשן, או הרץ `claude-mux --hide my-project`. זה יוצר קובץ סימון `.claudemux-ignore`. הפרויקט לא יופיע בפלט `claude-mux -L`. כדי לראות פרויקטים מוסתרים: `claude-mux -L --hidden`. כדי לבטל הסתרה: "הצג את הפרויקט הזה" או `claude-mux --show my-project`.

## איך מסירים את claude-mux?

```bash
claude-mux --uninstall
```

זה מסיר hooks של טיפים וכללי הרשאות מכל הפרויקטים, מוריד את ה-LaunchAgent, ואופציונלית מוחק `~/.claude-mux/`. הוא מדווח על נתיב הקובץ הבינארי כדי שתוכל למחוק ידנית (או `brew uninstall claude-mux` אם הותקן דרך Homebrew).

## פקודות slash עובדות דרך Remote Control?

לא באופן מקורי. Claude Code לא תומך בפקודות slash (`/model`, `/clear` וכו') בסשני RC. claude-mux עוקף את זה על ידי הזרקת `claude-mux -s` לכל סשן כדי ש-Claude יוכל לשלוח פקודות slash לעצמו דרך tmux. פשוט אמור "עבור ל-Haiku" או "דחוס את הסשן הזה" ו-Claude מטפל בזה.

## אי אפשר לבחור טקסט בסשן

החזק **Option** (macOS) או **Shift** (טרמינלים של Linux/Windows) תוך כדי לחיצה וגרירה. זה עוקף את לכידת העכבר של tmux ומעתיק את הבחירה ללוח המערכת. אין צורך בשינויי תצורה.

## אילו שפות נתמכות לפקודות שיחה?

כולן. ביטויי ההפעלה ("help", "status", "list sessions" וכו') עובדים בכל שפה. Claude מזהה את הכוונה מהשפה הטבעית של המשתמש ומריץ את הפקודה המתאימה. ה-README גם מתורגם ל-12 שפות.
