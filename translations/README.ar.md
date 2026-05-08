# claude-mux - مُضاعِف جلسات Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · **العربية** · [हिन्दी](README.hi.md)

جلسات Claude Code دائمة لجميع مشاريعك، يمكن الوصول إليها من أي مكان عبر تطبيق Claude للهاتف المحمول. ***يديره Claude!***

## لماذا

يَعِد Remote Control باستخدام Claude Code من أي مكان، لكن بدون إدارة الجلسات، فهو واجهة من الدرجة الثانية حتى من Claude Desktop:

- تموت الجلسات عند إغلاق الطرفية ولا يُستأنف سياق المحادثة تلقائيا
- لا توجد قاعدة دائمة: عند التقاط هاتفك، لا شيء يعمل ما لم تترك شيئا مفتوحا
- إذا لم تكن هناك جلسة قيد التشغيل، فـ Remote Control عديم الفائدة: لا يمكنك الوصول إلى مشروع أو بدء واحد
- حتى في جلسة RC نشطة، لا تعمل الأوامر المائلة: لا تبديل نموذج ولا ضغط ولا تغيير وضع الأذونات
- بدء مشروع جديد يتطلب إنشاء مجلد يدويا وتهيئة git وكتابة CLAUDE.md وضبط وضع الأذونات واختيار نموذج: لا شيء من هذا يمكن فعله من RC
- إدارة مشاريع متعددة تعني تشغيلات طرفية يدوية متعددة دون نظرة شاملة على ما يعمل أو حالته

claude-mux يحل كل ذلك. يُغلِّف Claude Code في tmux لتستمر الجلسات، ويحقن موجِّه نظام حتى يتمكن Claude من إدارة جلساته بنفسه، ويُوجِّه الأوامر المائلة عبر tmux لتعمل فوق Remote Control. بمجرد تشغيل جلسة، تُدير كل شيء بالتحدث مع Claude من الطرفية أو تطبيق الهاتف.

## البدء السريع

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

ثم ابدأ جلسة:

```bash
cd ~/path/to/your/project
claude-mux
```

أو:

```bash
claude-mux ~/path/to/your/project
```

هذا كل شيء. أنت الآن في جلسة Claude دائمة واعية بذاتها مع تفعيل Remote Control. من هنا، كل شيء تحاوري.

## التحدث مع Claude

هكذا تستخدم claude-mux يوميا. كل جلسة مُحقونة بأوامر حتى يستطيع Claude إدارة الجلسات وتبديل النماذج وإرسال الأوامر المائلة وإنشاء مشاريع جديدة، كل ذلك من داخل المحادثة. لا تحتاج إلى تذكر خيارات سطر الأوامر.

```
أنت: "status"
Claude: يُبلِّغ عن اسم الجلسة والنموذج ووضع الأذونات واستخدام السياق ويعرض جميع الجلسات

أنت: "list active sessions"
Claude: يعرض جميع الجلسات قيد التشغيل وحالاتها

أنت: "start a session for my api-server project"
Claude: يُطلق جلسة في ~/Claude/work/api-server

أنت: "create a new project called mobile-app using the web template"
Claude: يُنشئ دليل المشروع ويُهيِّئ git ويُطبِّق القالب ويُطلق جلسة

أنت: "switch this session to Haiku"
Claude: يُرسل /model haiku إلى نفسه عبر tmux

أنت: "compact the api-server session"
Claude: يُرسل /compact إلى جلسة api-server

أنت: "restart the web-dashboard session"
Claude: يُوقف ويُعيد إطلاق الجلسة مع الحفاظ على سياق المحادثة

أنت: "switch the api-server session to plan mode"
Claude: يُعيد تشغيل الجلسة بوضع أذونات plan

أنت: "switch this session to yolo mode"
Claude: يتحول إلى وضع bypassPermissions عبر Shift+Tab دون الحاجة لإعادة التشغيل

أنت: "what mode is this session"
Claude: يُبلِّغ عن وضع الأذونات الحالي (default أو acceptEdits أو plan أو bypassPermissions)

أنت: "switch this session to Opus"
Claude: يُرسل /model opus إلى نفسه عبر tmux

أنت: "clear this session"
Claude: يُرسل /clear إلى نفسه ويُعيد تعيين المحادثة

أنت: "hide this project"
Claude: يكتب .claudemux-ignore فيُستثنى المشروع من قوائم -L

أنت: "protect this session"
Claude: يكتب .claudemux-protected ويضبط إشارة tmux، فيتطلب الإيقاف الآن --force

أنت: "is this session protected"
Claude: يتحقق من وجود .claudemux-protected في مجلد المشروع ويُبلِّغ

أنت: "delete the old-prototype project"
Claude: يُؤكد في المحادثة ثم ينقل مجلد المشروع إلى سلة المحذوفات

أنت: "rename this project to my-new-name"
Claude: يُوقف الجلسة ويُعيد تسمية المجلد ويُرحِّل سجل المحادثات ويُعيد التشغيل

أنت: "save this as a template named web"
Claude: ينسخ CLAUDE.md إلى ~/.claude-mux/templates/web.md

أنت: "tip"
Claude: يطبع نصيحة، نفس النصيحة طوال اليوم أو عشوائية إذا ضُبط TIP_MODE=random

أنت: "enable tips" / "disable tips"
Claude: يُسجِّل أو يُزيل خطاف نصيحة اليوم عبر جميع المشاريع

أنت: "update claude-mux"
Claude: يُحذِّر بأن جميع الجلسات ستُعاد تشغيلها ويطلب التأكيد ثم يُحدِّث ويُعيد التشغيل

أنت: "stop all sessions"
Claude: يخرج بسلاسة من جميع الجلسات المُدارة

أنت: "help"
Claude: يطبع قائمة الأوامر التحاورية كاملة
```

تعمل هذه الأوامر بأي لغة. إذا كتبت ما يعادلها بالإسبانية أو اليابانية أو العبرية أو أي لغة أخرى، يستنتج Claude القصد ويُنفِّذ الأمر المقابل.

اكتب `help` داخل أي جلسة لرؤية قائمة الأوامر الكاملة.

### الجلسة الرئيسية

الجلسة الرئيسية هي جلسة عامة الغرض تعيش في دليلك الأساسي (`~/Claude` افتراضيا). تُطلق تلقائيا عند تسجيل الدخول حين يكون `LAUNCHAGENT_MODE=home`، مما يمنحك جلسة Claude واحدة جاهزة دائما يمكن الوصول إليها من هاتفك. استخدمها لإدارة جميع جلساتك الأخرى دون الحاجة إلى إطلاق جلسات لكل مشروع أولا.

الجلسة الرئيسية **محمية** افتراضيا: `--shutdown home` يرفض إيقافها دون `--force`. تُدار الحماية بواسطة ملف الإشارة `.claudemux-protected` في `$BASE_DIR`، الذي يُنشئه `claude-mux --install`. الجلسات المحمية تظهر بالحالة `protected` في عمود الحالة، وتُميَّز الجلسة الحالية بعلامة `>` في عمود الاسم.

## ما الذي يفعله

خلف الكواليس، يتولى claude-mux:

- **جلسات tmux دائمة** مع تفعيل Remote Control، بحيث تكون كل جلسة متاحة من تطبيق Claude للهاتف المحمول
- **استئناف المحادثة**: يستأنف آخر محادثة (`claude -c`) عند إعادة الإطلاق مع الحفاظ على السياق
- **حقن موجِّه النظام**: تحصل كل جلسة على أوامر للإدارة الذاتية وتوجيه الأوامر المائلة والوعي بحسابات SSH
- **قوالب CLAUDE.md**: احتفظ بملفات قوالب (مثل `web.md` و`python.md`) في `~/.claude-mux/templates/` وطبِّقها على المشاريع الجديدة
- **دعم أدوات CLI المتعددة**: يُنشئ `AGENTS.md` و`GEMINI.md` كروابط رمزية إلى `CLAUDE.md` حتى تشترك Codex CLI وGemini CLI وغيرها في التعليمات ذاتها
- **أذونات معتمدة تلقائيا**: يُضيف claude-mux نفسه إلى قائمة السماح في كل مشروع حتى يتمكن Claude من تشغيل أوامر الجلسة دون طلب إذن
- **ترحيل العمليات الشاردة**: إذا كان Claude يعمل خارج tmux، يُرحِّله إلى جلسة مُدارة
- **تحسينات tmux لجودة الاستخدام**: دعم الفأرة ومخزن تمرير سعته 50 ألف سطر وتكامل الحافظة وألوان 256 ومفاتيح موسَّعة ومراقبة النشاط وعناوين تبويبات الطرفية

> **ملاحظة:** هذا يختلف عن `claude --worktree --tmux` الذي يُنشئ جلسة tmux لشجرة عمل git معزولة. يُدير claude-mux جلسات دائمة لأدلة مشاريعك الفعلية مع Remote Control وحقن موجِّه النظام.

## المتطلبات

- macOS (Apple Silicon أو Intel)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## التثبيت

### curl (موصى به)

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

يُنزِّل الملف التنفيذي ويُثبِّته في `~/bin` ويُضيفه إلى `PATH` ويُشغِّل الإعداد التفاعلي. يعمل على macOS وLinux (على Linux: يُتجاوز إعداد LaunchAgent).

للتحديث:

```bash
claude-mux --update     # يعمل من داخل أي جلسة أو من الطرفية
```

### Homebrew (بديل macOS)

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

للتحديث:

```bash
brew upgrade claude-mux
```

### يدوي

```bash
./install.sh
```

يقوم `install.sh` بنسخ الملف التنفيذي إلى `~/bin` وإضافته إلى `PATH`. بعد ذلك شغِّل:

```bash
claude-mux --install
```

يسأل الإعداد التفاعلي عن مكان مشاريع Claude وعمّا إذا كنت تريد بدء جلسة رئيسية عند تسجيل الدخول وأي نموذج تستخدم. يُنشئ `~/.claude-mux/config` ويُثبِّت LaunchAgent.

استخدم `--non-interactive` لتجاوز المطالبات وقبول القيم الافتراضية.

الخيارات:

```bash
claude-mux --install --non-interactive                     # تجاوز المطالبات واستخدام القيم الافتراضية
claude-mux --install --base-dir ~/work/claude              # استخدام دليل أساسي مختلف
claude-mux --install --launchagent-mode none               # تعطيل سلوك LaunchAgent
claude-mux --install --home-model haiku                    # استخدام Haiku للجلسة الرئيسية
claude-mux --install --no-launchagent                      # تخطي تثبيت LaunchAgent بالكامل
```

يُشغِّل LaunchAgent الأمر `claude-mux --autolaunch` عند تسجيل الدخول مع تأخير بدء قدره 45 ثانية للسماح لخدمات النظام بالتهيئة.

## حالات الجلسات

| الحالة | المعنى |
|--------|--------|
| `running` | جلسة tmux موجودة وClaude يعمل |
| `protected` | مثل `running` لكن الجلسة محمية: `--shutdown` يتطلب `--force` لإيقافها |
| `stopped` | جلسة tmux موجودة لكن Claude خرج |
| `idle` | يوجد مشروع `.claude/` تحت `BASE_DIR` لكن لا توجد جلسة tmux من claude-mux تعمل (يظهر فقط مع `-L`) |

البادئة `>` على اسم الجلسة (مثل `> home`) تُشير إلى الجلسة التي نفّذت أمر القائمة.

تشغيل `claude-mux` في دليل لديه جلسة قيد التشغيل بالفعل يُلحقك بها. يمكن لعدة طرفيات الإلحاق بالجلسة نفسها (سلوك tmux القياسي).

## إشارات المشروع

تُخزَّن حالة كل مشروع في ملفات إشارة بجذر المشروع، لا في إعدادات مركزية. تستخدم الإشارات البادئة `.claudemux-` وتُضاف تلقائيا إلى `.gitignore` عند إنشائها في مشروع محكوم بـ git.

| الإشارة | المعنى | CLI |
|---------|--------|-----|
| `.claudemux-protected` | تُحمى الجلسة عند الإطلاق: `--shutdown` يتطلب `--force` | `--protect` / `--unprotect` |
| `.claudemux-ignore` | يُخفى المشروع من قوائم `claude-mux -L` | `--hide` / `--show` |

```bash
claude-mux --hide                    # إخفاء مشروع الجلسة الحالية من قوائم -L
claude-mux --hide my-project         # إخفاء مشروع محدد باسم الجلسة
claude-mux --show my-project         # إظهار مشروع مخفي
claude-mux --protect                 # حماية هذه الجلسة من الإيقاف العرضي
claude-mux --unprotect               # إزالة الحماية
claude-mux -L --hidden               # عرض المشاريع المخفية فقط
claude-mux --delete my-project       # نقل مجلد المشروع إلى سلة المحذوفات (macOS)
```

تتبع الإشارات مجلد المشروع عند إعادة التسمية والنقل. نمط `.gitignore` واحد (`.claudemux-*`) يغطي جميع الإشارات الحالية والمستقبلية.

## التهيئة

يُنشأ `~/.claude-mux/config` بواسطة `claude-mux --install` (أو عند أول تشغيل لأي أمر إذا لم يكن الملف موجودا). عدِّله لتجاوز أي قيم افتراضية: لا حاجة أبدا لتعديل السكربت مباشرة.

| المتغير | الافتراضي | الوصف |
|---------|-----------|-------|
| `BASE_DIR` | `$HOME/Claude` | الدليل الجذر للبحث عن مشاريع Claude (الأدلة التي تحتوي `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | دليل ملف `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | يضبط `permissions.defaultMode` لـ Claude في كل مشروع. القيم الصحيحة: `default` و`acceptEdits` و`plan` و`auto` و`dontAsk` و`bypassPermissions`. اضبطه على `""` للتعطيل. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | عند `true`، تستطيع جلسات Claude إرسال أوامر مائلة إلى جلسات أخرى. مفيد لتنسيق الوكلاء المتعددين. |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | دليل ملفات قوالب CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | القالب الافتراضي المُطبَّق على المشاريع الجديدة (`-n`). اضبطه على `""` للتعطيل. |
| `SLEEP_BETWEEN` | `5` | عدد الثواني بين إطلاق الجلسات عند استخدام `-a`. زِدها إذا فشل تسجيل RC. |
| `HOME_SESSION_MODEL` | `""` | نموذج الجلسة الرئيسية. القيم الصحيحة: `sonnet` و`haiku` و`opus`. القيمة الفارغة ترث افتراضي Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | قائمة مفصولة بمسافات من الملفات التي تُنشأ كروابط رمزية إلى `CLAUDE.md` لأدوات AI CLI الأخرى. اضبطها على `""` للتعطيل. |
| `LAUNCHAGENT_MODE` | `home` | سلوك LaunchAgent عند تسجيل الدخول: `none` (لا شيء) أو `home` (إطلاق الجلسة الرئيسية المحمية). يُعامَل `LAUNCHAGENT_ENABLED=true` القديم كـ `home`. |

**خيارات جلسة tmux** (جميعها قابلة للضبط ومُفعَّلة افتراضيا):

| المتغير | الافتراضي | الوصف |
|---------|-----------|-------|
| `TMUX_MOUSE` | `true` | دعم الفأرة: التمرير والتحديد وتغيير حجم الألواح |
| `TMUX_HISTORY_LIMIT` | `50000` | حجم مخزن التمرير بالأسطر (الافتراضي في tmux هو 2000) |
| `TMUX_CLIPBOARD` | `true` | تكامل حافظة النظام عبر OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | نوع الطرفية لعرض ألوان سليم |
| `TMUX_EXTENDED_KEYS` | `true` | تسلسلات مفاتيح موسَّعة بما فيها Shift+Enter (يتطلب tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | تأخير مفتاح escape بالملي ثانية (الافتراضي في tmux هو 500) |
| `TMUX_TITLE_FORMAT` | `#S` | صيغة عنوان الطرفية/التبويب (`#S` = اسم الجلسة، `""` للتعطيل) |
| `TMUX_MONITOR_ACTIVITY` | `true` | الإشعار عند حدوث نشاط في جلسات أخرى |

## بنية الأدلة

تُكتشف المشاريع بوجود دليل `.claude/` على أي عمق:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ يحوي .claude/ — مُدار
│   │   └── .claude/
│   ├── project-b/          # ✓ يحوي .claude/ — مُدار
│   │   └── .claude/
│   └── -archived/          # ✗ مستثنى (يبدأ بـ -)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ يحوي .claude/ — مُدار
│   │   └── .claude/
│   ├── .hidden/            # ✗ مستثنى (دليل مخفي)
│   │   └── .claude/
│   └── project-d/          # ✗ لا يوجد .claude/ — ليس مشروع Claude
├── deep/nested/project-e/  # ✓ يحوي .claude/ — يُكتشف على أي عمق
│   └── .claude/
└── ignored-project/        # ✗ مستثنى (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

تُشتق أسماء الجلسات من أسماء الأدلة: تتحول المسافات إلى شرطات، وتُستبدل المحارف غير الأبجدية الرقمية (باستثناء الشرطات)، وتُجرَّد الشرطات في البداية والنهاية. الأدلة التي يُفضي تطهير اسمها إلى سلسلة فارغة تُتجاوز مع تحذير في السجل.

## موجِّه نظام الجلسة

تُطلق كل جلسة Claude بوسيط `--append-system-prompt` يحوي سياقا عن بيئتها:

```
You are running inside tmux session '<session-name>'. claude-mux path: /path/to/claude-mux
claude-mux version: <version>
[Update available: <new-version> (found <date>). Tell the user and suggest they say "update claude-mux" to update.]

Reference lookups (run on demand if you need information not covered by trigger rules):
  claude-mux --guide          → conversational commands list (used for "help")
  claude-mux --commands       → full CLI reference
  claude-mux --config-help    → config options with defaults, types, descriptions
  claude-mux --list-templates → available CLAUDE.md templates

Rules:
- Always run claude-mux using the absolute path shown above (claude-mux path:). The bare command may not be in PATH.
- You CAN send slash commands (/model, /compact, /clear, etc.) to this session via the -s command.
- Always use --no-attach with -d and -n — attach is interactive only
- --shutdown and --restart never attach — safe to run from inside a session; do NOT add --no-attach to these commands
- Always print command output verbatim in your response text — if a command fails, report the error
- When command output contains <assistant-must-display> tags, include the COMPLETE content verbatim
- The 'home' session is the always-available session in the base directory. It is protected (shows 'protected' in status): --shutdown requires --force, but --restart bypasses protection. Protection is driven by the .claudemux-protected marker.
- Disambiguate 'home': 'home session' means the claude-mux session named home; 'home folder' means ~/
- When asked to shut down sessions, run the command directly — protected sessions are skipped automatically
- Use claude-mux for ALL session management. Never use raw tmux, ls, or other shell commands for session management.
- Don't guess at claude-mux flags. If you need information not in the trigger rules, run the relevant lookup.
- When user says: ready — respond with "Session ready!" on one line. Nothing else.
- When user says: help — run claude-mux --guide and print the output verbatim
- When user says: status — report session name, model, permission mode, context estimate, then run claude-mux -l
- When user says: list active sessions — run claude-mux -l
- When user says: list all sessions — run claude-mux -L
- When user says: list hidden projects — run claude-mux -L --hidden
- When user says: start session SESSION — run claude-mux -d SESSION --no-attach
- When user says: stop this session / stop session NAME — run claude-mux --shutdown
- When user says: stop all sessions — run claude-mux --shutdown
- When user says: restart this session / restart session NAME — run claude-mux --restart
- When user says: restart all sessions — run claude-mux --restart
- When user says: start new session in FOLDER — run claude-mux -n FOLDER --no-attach
- When user says: switch this session to MODE mode / switch session NAME to MODE mode
- When user says: switch this session to MODEL model / switch session NAME to MODEL model
- When user says: compact/clear this session / compact/clear session NAME
- When user says: update claude-mux — warn sessions will restart, get confirmation, run --update then --restart
- When user says: hide this project / hide PROJECT — run claude-mux --hide
- When user says: show this project / show PROJECT / unhide PROJECT — run claude-mux --show
- When user says: protect this session / protect SESSION — run claude-mux --protect
- When user says: unprotect this session / unprotect SESSION — run claude-mux --unprotect
- When user says: is this hidden / is this protected — check for .claudemux-ignore or .claudemux-protected
- When user says: delete this project / delete PROJECT — confirm in chat first, then run claude-mux --delete SESSION --yes
- When user says: list templates — run claude-mux --list-templates
- When user says: enable tips / turn on tips — run claude-mux --enable-tips
- When user says: disable tips / turn off tips — run claude-mux --disable-tips
- These trigger phrases work in any language.

Additional capabilities (run claude-mux --commands for full syntax):
  - Attach interactively to a session (-t — user-only, never from inside a session)
  - Start all sessions at once (-a)
  - New project with a CLAUDE.md template (-n DIR --template NAME, -p for parent dirs)
  - Force-shutdown a protected session (--shutdown SESSION --force)
  - Hide/show projects (--hide / --show)
  - Protect/unprotect sessions (--protect / --unprotect)
  - Move a project to trash (--delete SESSION — macOS; honors protection unless --force)
  - Enable/disable tip-of-the-day hook (--enable-tips / --disable-tips)
  - Show all config options (--config-help)
  - Run interactive setup or reconfigure (--install)
  - Remove all hooks and permissions (--uninstall)
  - Update claude-mux (--update)

Self-targeting send: claude-mux -s '<session-name>' '/command' sends slash commands to yourself.
GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

تحصل الجلسة الرئيسية على سياق إضافي: وصف لدورها بالإضافة إلى مُحفِّزات إدارة ذاتية لقراءة الإعدادات والقوالب وتعديلها. عندما يكون `ALLOW_CROSS_SESSION_CONTROL=true`، يتغير أمر الإرسال للسماح باستهداف أي جلسة لا الجلسة نفسها فحسب. المسار هو المسار المطلق للسكربت وقت الإطلاق فلا تعتمد الجلسات على `PATH`.

## مرجع سطر الأوامر

نادرا ما تحتاج إلى هذه الأوامر مباشرة: يُشغِّلها Claude من داخل الجلسات. هي متاحة للبرمجة النصية والأتمتة أو حين لا تكون داخل جلسة.

```bash
# الإطلاق والإلحاق
claude-mux                       # تشغيل Claude في الدليل الحالي والإلحاق
claude-mux ~/projects/my-app     # تشغيل Claude في دليل والإلحاق
claude-mux -d ~/projects/my-app  # نفس ما سبق (الصيغة الصريحة)
claude-mux -t my-app             # الإلحاق بجلسة tmux قائمة

# إنشاء مشاريع جديدة
claude-mux -n ~/projects/app     # إنشاء مشروع Claude جديد والإلحاق
claude-mux -n ~/new/path/app -p  # نفس ما سبق مع إنشاء الدليل والآباء
claude-mux -n ~/app --template web        # مشروع جديد بقالب CLAUDE.md محدد
claude-mux -n ~/app --no-multi-coder      # مشروع جديد بدون روابط AGENTS.md/GEMINI.md

# إدارة الجلسات
claude-mux -l                    # عرض الجلسات حسب الحالة (نشطة وقيد التشغيل ومتوقفة)
claude-mux -L                    # عرض جميع المشاريع (نشطة + خاملة)
claude-mux -L --hidden           # عرض المشاريع المخفية فقط
claude-mux -s my-app '/model sonnet'      # إرسال أمر مائل إلى جلسة
claude-mux --shutdown my-app              # إيقاف جلسة محددة
claude-mux --shutdown                     # إيقاف جميع الجلسات المُدارة
claude-mux --shutdown home --force        # إيقاف الجلسة الرئيسية المحمية
claude-mux --restart my-app              # إعادة تشغيل جلسة محددة
claude-mux --restart                     # إعادة تشغيل جميع الجلسات قيد التشغيل
claude-mux --permission-mode plan my-app  # إعادة تشغيل الجلسة بوضع plan
claude-mux -a                    # بدء جميع الجلسات المُدارة تحت BASE_DIR

# إشارات المشروع (جميع الأوامر تستخدم أسماء الجلسات لا المسارات)
claude-mux --hide                # إخفاء مشروع الجلسة الحالية من قوائم -L
claude-mux --hide my-project     # إخفاء مشروع محدد باسم الجلسة
claude-mux --show my-project     # إظهار مشروع مخفي
claude-mux --protect             # حماية هذه الجلسة من الإيقاف العرضي
claude-mux --unprotect           # إزالة الحماية
claude-mux --delete my-project           # نقل مجلد المشروع إلى سلة المحذوفات (macOS)
claude-mux --delete my-project --yes     # نفس الأمر بدون طلب تأكيد
claude-mux --rename my-project new-name  # إعادة تسمية دليل المشروع
claude-mux --move my-project ~/Claude/work  # نقل المشروع إلى أب جديد

# أخرى
claude-mux --list-templates      # عرض قوالب CLAUDE.md المتاحة
claude-mux --guide               # عرض الأوامر التحاورية للاستخدام داخل الجلسات
claude-mux --commands            # عرض مرجع CLI الكامل
claude-mux --config-help         # عرض جميع خيارات الإعداد مع القيم الافتراضية والأوصاف
claude-mux --install             # إعداد تفاعلي: الإعدادات + LaunchAgent
claude-mux --update              # تحديث إلى أحدث إصدار
claude-mux --dry-run             # معاينة الإجراءات دون تنفيذها
claude-mux --version             # طباعة الإصدار
claude-mux --help                # عرض جميع الخيارات

# متابعة السجل
tail -f ~/Library/Logs/claude-mux.log
```

عند التشغيل من الطرفية، تُعكس المخرجات إلى stdout في الوقت الحقيقي. وعند التشغيل عبر LaunchAgent، تذهب المخرجات إلى ملف السجل فقط.

## استكشاف الأخطاء وإصلاحها

### تعرض الجلسات "Not logged in · Run /login"

يحدث هذا عند الإطلاق الأول إذا كانت سلسلة مفاتيح macOS مقفلة (شائع عند تشغيل السكربت قبل فتح سلسلة المفاتيح بعد تسجيل الدخول). الحل:

```bash
# افتح سلسلة المفاتيح في طرفية عادية
security unlock-keychain

# ثم أكمل المصادقة في أي جلسة قيد التشغيل
claude-mux -t <any-session>
# شغِّل /login وأكمل تدفق المتصفح
```

بعد إكمال المصادقة مرة واحدة، أوقف وأعد إطلاق جميع الجلسات وستلتقط بيانات الاعتماد المحفوظة تلقائيا.

### الجلسات لا تظهر في Claude Code Remote

يجب أن تكون الجلسات مُصادَقا عليها (لا تعرض "Not logged in"). بعد إطلاق نظيف ومُصادَق عليه، يُفترض أن تظهر في قائمة RC في غضون ثوانٍ قليلة.

### الإدخال متعدد الأسطر في tmux

لا يمكن تشغيل أمر `/terminal-setup` داخل tmux. يُفعِّل claude-mux ميزة `extended-keys` في tmux افتراضيا (`TMUX_EXTENDED_KEYS=true`) وهي تدعم Shift+Enter في معظم الطرفيات الحديثة. إذا لم يعمل Shift+Enter، استخدم `\` + Return لإدخال أسطر جديدة في مُوجِّهك.

### "Session ready!" عند بدء الجلسة

عند بدء جلسة أو إعادة تشغيلها، يُرسل claude-mux رسالة `Ready?` تلقائيا بعد انتهاء تحميل Claude. يُخبر الحقن Claude بالرد بـ "Session ready!" فحسب ولا شيء آخر. هذا يؤكد أن الجلسة حية وأن الحقن يعمل.

### الأوامر المائلة عبر Remote Control

الأوامر المائلة (مثل `/model` و`/clear`) [غير مدعومة أصلا](https://github.com/anthropics/claude-code/issues/30674) في جلسات RC. يلتف claude-mux حول ذلك: تُحقن كل جلسة بـ `claude-mux -s` بحيث يستطيع Claude إرسال الأوامر المائلة إلى نفسه عبر tmux.

## السجلات

- `~/Library/Logs/claude-mux.log` — جميع إجراءات السكربت بطوابع زمنية UTC (قابل للضبط عبر `LOG_DIR`)

لتصحيح أخطاء LaunchAgent منخفضة المستوى، استخدم Console.app أو `log show`.

## المزيد

- [الأسئلة الشائعة](FAQ.ar.md) — أسئلة شائعة حول claude-mux
- [المشكلات المعروفة](ISSUES.ar.md) — أخطاء مفتوحة وميزات مخططة ومشكلات محلولة
- [سجل التغييرات](../CHANGELOG.md) — ما تغير في كل إصدار
