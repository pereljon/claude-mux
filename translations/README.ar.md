# claude-mux - مُجمِّع جلسات Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · **العربية** · [हिन्दी](README.hi.md)

جلسات Claude Code دائمة لجميع مشاريعك، يمكن الوصول إليها من أي مكان عبر تطبيق Claude للهاتف المحمول.

## لماذا

العمل مع Claude Code عبر مشاريع متعددة ينطوي على احتكاكات:

- تموت الجلسات عند إغلاق الطرفية
- لا تستطيع جلسات Remote Control تشغيل أوامر مائلة مثل `/model` أو `/compact`
- لا يمكنك بسهولة بدء جلسة لمشروع لا يعمل بالفعل
- تبديل النماذج أو أوضاع الأذونات أو ضغط السياق من هاتفك غير ممكن

claude-mux يعالج كل ذلك. يُغلِّف Claude Code داخل tmux لتستمر الجلسات، ويحقن موجِّه نظام حتى يتمكن Claude من إدارة جلساته بنفسه، ويُوجِّه الأوامر المائلة عبر tmux لتعمل فوق Remote Control. بمجرد تشغيل جلسة، تُدير كل شيء بالتحدث مع Claude — من الطرفية أو تطبيق الهاتف.

## البدء السريع

```bash
./install.sh
```

```bash
claude-mux ~/path/to/your/project
```

هذا كل شيء. أنت الآن داخل جلسة Claude دائمة وواعية بذاتها مع تفعيل Remote Control. من هنا، كل شيء تحاوري.

## التحدث مع Claude

هكذا تستخدم claude-mux يوميًا. كل جلسة مُحقونة بأوامر حتى يستطيع Claude إدارة الجلسات، وتبديل النماذج، وإرسال الأوامر المائلة، وإنشاء مشاريع جديدة — كل ذلك من داخل المحادثة. لا تحتاج إلى تذكر خيارات سطر الأوامر.

```
أنت: "status"
Claude: يُبلِّغ عن اسم الجلسة، والنموذج، ووضع الأذونات، واستخدام السياق، ويعرض جميع الجلسات

أنت: "list active sessions"
Claude: يعرض جميع الجلسات قيد التشغيل وحالاتها

أنت: "start a session for my api-server project"
Claude: يُطلق جلسة في ~/Claude/work/api-server

أنت: "create a new project called mobile-app using the web template"
Claude: يُنشئ دليل المشروع، ويُهيِّئ git، ويُطبِّق القالب، ويُطلق جلسة

أنت: "switch this session to Haiku"
Claude: يُرسل /model haiku إلى نفسه عبر tmux

أنت: "compact the api-server session"
Claude: يُرسل /compact إلى جلسة api-server

أنت: "restart the web-dashboard session"
Claude: يُوقف ويُعيد إطلاق الجلسة مع الحفاظ على سياق المحادثة

أنت: "switch the api-server session to plan mode"
Claude: يُعيد تشغيل الجلسة بوضع أذونات plan

أنت: "stop all sessions"
Claude: يخرج بسلاسة من جميع الجلسات المُدارة

أنت: "help"
Claude: يطبع قائمة الأوامر التحاورية كاملة
```

تعمل هذه الأوامر بأي لغة. إذا كتبت ما يعادلها بالإسبانية أو اليابانية أو العبرية أو أي لغة أخرى، يستنتج Claude القصد ويُنفِّذ الأمر المقابل.

اكتب `help` داخل أي جلسة لرؤية قائمة الأوامر الكاملة.

### الجلسة الرئيسية

الجلسة الرئيسية هي جلسة عامة الغرض تعيش في دليلك الأساسي (`~/Claude` افتراضيًا). تُطلق تلقائيًا عند تسجيل الدخول حين يكون `LAUNCHAGENT_MODE=home`، مما يمنحك جلسة Claude واحدة جاهزة دائمًا يمكن الوصول إليها من هاتفك. استخدمها لإدارة جميع جلساتك الأخرى دون الحاجة إلى إطلاق جلسات لكل مشروع أولًا.

الجلسة الرئيسية **محمية** دائمًا — `--shutdown home` يرفض إيقافها دون `--force`. الجلسات المحمية تُعلَّم بالعلامة `*` في مخرجات الحالة (مثل `active*`).

## ما الذي يفعله

خلف الكواليس، يتولى claude-mux:

- **جلسات tmux دائمة** مع تفعيل Remote Control، بحيث تكون كل جلسة متاحة من تطبيق Claude للهاتف المحمول
- **استئناف المحادثة** — يستأنف آخر محادثة (`claude -c`) عند إعادة الإطلاق، مع الحفاظ على السياق
- **حقن موجِّه النظام** — تحصل كل جلسة على أوامر للإدارة الذاتية، وتوجيه الأوامر المائلة، والوعي بحسابات SSH
- **قوالب CLAUDE.md** — احتفظ بملفات قوالب (مثل `web.md` و `python.md`) في `~/.claude-mux/templates/` وطبِّقها على المشاريع الجديدة
- **دعم أدوات CLI المتعددة** — يُنشئ `AGENTS.md` و `GEMINI.md` كروابط رمزية إلى `CLAUDE.md` حتى تشترك Codex CLI و Gemini CLI وغيرها في التعليمات ذاتها
- **أذونات معتمدة تلقائيًا** — يُضيف claude-mux نفسه إلى قائمة السماح في كل مشروع حتى يتمكن Claude من تشغيل أوامر الجلسة دون طلب إذن
- **ترحيل العمليات الشاردة** — إذا كان Claude يعمل خارج tmux، يُرحِّله إلى جلسة مُدارة
- **تحسينات tmux لجودة الاستخدام** — دعم الفأرة، ومخزن تمرير سعته 50 ألف سطر، وتكامل الحافظة، وألوان 256، ومفاتيح موسَّعة، ومراقبة النشاط، وعناوين تبويبات الطرفية

> **ملاحظة:** هذا يختلف عن `claude --worktree --tmux` الذي يُنشئ جلسة tmux لشجرة عمل git معزولة. يُدير claude-mux جلسات دائمة لأدلة مشاريعك الفعلية، مع Remote Control وحقن موجِّه النظام.

## المتطلبات

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Claude Code](https://claude.ai/code) — `brew install claude`

## التثبيت

### Homebrew (موصى به)

```bash
brew tap pereljon/tap
brew install claude-mux
```

يتم إنشاء الإعدادات (`~/.claude-mux/config`) تلقائياً عند التشغيل الأول. لإعداد LaunchAgent (جلسة رئيسية عند تسجيل الدخول)، انسخ المستودع وشغّل `install.sh`.

للتحديث:

```bash
brew upgrade claude-mux
```

### يدوي

```bash
./install.sh
```

يسأل المُثبِّت التفاعلي عن مكان مشاريع Claude، وعمّا إذا كنت تريد بدء جلسة رئيسية عند تسجيل الدخول، وأي نموذج تستخدم. ثم يُثبِّت `claude-mux` في `~/bin`، ويُنشئ `~/.claude-mux/config`، ويُعدّ LaunchAgent.

استخدم `--non-interactive` لتجاوز المطالبات وقبول القيم الافتراضية.

الخيارات:

```bash
./install.sh --non-interactive                     # تجاوز المطالبات واستخدم القيم الافتراضية
./install.sh --base-dir ~/work/claude              # استخدام دليل أساسي مختلف
./install.sh --launchagent-mode none               # تعطيل سلوك LaunchAgent
./install.sh --home-model haiku                    # استخدام Haiku للجلسة الرئيسية
./install.sh --no-launchagent                      # تخطي تثبيت LaunchAgent بالكامل
```

يُشغِّل LaunchAgent الأمر `claude-mux --autolaunch` عند تسجيل الدخول مع تأخير بدء قدره 45 ثانية للسماح لخدمات النظام بالتهيئة.

## حالات الجلسات

| الحالة | المعنى |
|--------|--------|
| `active` | جلسة tmux موجودة و Claude يعمل، وعميل tmux محلي ملحق |
| `running` | جلسة tmux موجودة و Claude يعمل (بدون عميل محلي ملحق) |
| `stopped` | جلسة tmux موجودة لكن Claude خرج |
| `idle` | يوجد مشروع `.claude/` تحت `BASE_DIR` لكن لا توجد جلسة tmux من claude-mux تعمل (يظهر فقط مع `-L`) |

علامة `*` في نهاية أي حالة تعني أن الجلسة محمية وتتطلب `--force` لإيقافها (مثل `active*` و `running*`). الجلسة الرئيسية محمية دائمًا.

تشغيل `claude-mux` في دليل لديه جلسة قيد التشغيل بالفعل يُلحقك بها. يمكن لعدة طرفيات الإلحاق بالجلسة نفسها (سلوك tmux القياسي).

## التهيئة

عند التشغيل لأول مرة، يُنشأ `~/.claude-mux/config` تلقائيًا مع تعطيل جميع الإعدادات بالتعليق. عدِّله لتجاوز أي قيم افتراضية — لا حاجة أبدًا لتعديل السكربت مباشرةً.

| المتغير | الافتراضي | الوصف |
|---------|-----------|-------|
| `BASE_DIR` | `$HOME/Claude` | الدليل الجذر للبحث عن مشاريع Claude (الأدلة التي تحتوي `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | دليل ملف `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | يضبط `permissions.defaultMode` لـ Claude في كل مشروع. القيم الصحيحة: `default`، `acceptEdits`، `plan`، `auto`، `dontAsk`، `bypassPermissions`. اضبطه على `""` للتعطيل. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | عند `true`، تستطيع جلسات Claude إرسال أوامر مائلة إلى جلسات أخرى — مفيد لتنسيق الوكلاء المتعددين |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | دليل ملفات قوالب CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | القالب الافتراضي المُطبَّق على المشاريع الجديدة (`-n`). اضبطه على `""` للتعطيل. |
| `SLEEP_BETWEEN` | `5` | عدد الثواني بين إطلاق الجلسات عند استخدام `-a`. زِدها إذا فشل تسجيل RC. |
| `HOME_SESSION_MODEL` | `""` | نموذج الجلسة الرئيسية. القيم الصحيحة: `sonnet`، `haiku`، `opus`. القيمة الفارغة ترث افتراضي Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | قائمة مفصولة بمسافات من الملفات التي تُنشأ كروابط رمزية إلى `CLAUDE.md` لأدوات AI CLI الأخرى. اضبطها على `""` للتعطيل. |
| `LAUNCHAGENT_MODE` | `home` | سلوك LaunchAgent عند تسجيل الدخول: `none` (لا شيء) أو `home` (إطلاق الجلسة الرئيسية المحمية). يُعامَل `LAUNCHAGENT_ENABLED=true` القديم كـ `home`. |

**خيارات جلسة tmux** (جميعها قابلة للضبط ومُفعَّلة افتراضيًا):

| المتغير | الافتراضي | الوصف |
|---------|-----------|-------|
| `TMUX_MOUSE` | `true` | دعم الفأرة — التمرير، التحديد، تغيير حجم الألواح |
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
└── ignored-project/        # ✗ مستثنى (.ignore-claudemux)
    ├── .claude/
    └── .ignore-claudemux
```

تُشتق أسماء الجلسات من أسماء الأدلة: تتحوَّل المسافات إلى شَرَط، وتُستبدل المحارف غير الأبجدية الرقمية (باستثناء الشَرَط)، وتُجرَّد الشَرَط في البداية والنهاية. الأدلة التي يُفضي تطهير اسمها إلى سلسلة فارغة تُتجاوز مع تحذير في السجل.

## موجِّه نظام الجلسة

تُطلق كل جلسة Claude بوسيط `--append-system-prompt` يحوي سياقًا عن بيئتها:

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

عندما يكون `ALLOW_CROSS_SESSION_CONTROL=true`، يتغير أمر الإرسال للسماح باستهداف أي جلسة، لا الجلسة نفسها فحسب. المسار هو المسار المطلق للسكربت وقت الإطلاق، فلا تعتمد الجلسات على `PATH`.

## مرجع سطر الأوامر

نادرًا ما تحتاج إلى هذه الأوامر مباشرةً — يُشغِّلها Claude من داخل الجلسات. هي متاحة للبرمجة النصية والأتمتة أو حين لا تكون داخل جلسة.

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
claude-mux -l                    # عرض الجلسات حسب الحالة (active، running، stopped)
claude-mux -L                    # عرض جميع المشاريع (نشطة + خاملة)
claude-mux -s my-app '/model sonnet'      # إرسال أمر مائل إلى جلسة
claude-mux --shutdown my-app              # إيقاف جلسة محددة
claude-mux --shutdown                     # إيقاف جميع الجلسات المُدارة
claude-mux --shutdown home --force        # إيقاف الجلسة الرئيسية المحمية
claude-mux --restart my-app              # إعادة تشغيل جلسة محددة
claude-mux --restart                     # إعادة تشغيل جميع الجلسات قيد التشغيل
claude-mux --permission-mode plan my-app  # إعادة تشغيل الجلسة بوضع plan
claude-mux -a                    # بدء جميع الجلسات المُدارة تحت BASE_DIR

# أخرى
claude-mux --list-templates      # عرض قوالب CLAUDE.md المتاحة
claude-mux --guide               # عرض الأوامر التحاورية للاستخدام داخل الجلسات
claude-mux --dry-run             # معاينة الإجراءات دون تنفيذها
claude-mux --version             # طباعة الإصدار
claude-mux --help                # عرض جميع الخيارات

# متابعة السجل
tail -f ~/Library/Logs/claude-mux.log
```

عند التشغيل من الطرفية، تُعكس المخرجات إلى stdout في الزمن الحقيقي. وعند التشغيل عبر LaunchAgent، تذهب المخرجات إلى ملف السجل فقط.

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

بعد إكمال المصادقة مرة واحدة، أوقف وأعد إطلاق جميع الجلسات — ستلتقط بيانات الاعتماد المحفوظة تلقائيًا.

### الجلسات لا تظهر في Claude Code Remote

يجب أن تكون الجلسات مُصادَقًا عليها (لا تعرض "Not logged in"). بعد إطلاق نظيف ومُصادَق عليه، يُفترض أن تظهر في قائمة RC في غضون ثوانٍ قليلة.

### الإدخال متعدد الأسطر في tmux

لا يمكن تشغيل أمر `/terminal-setup` داخل tmux. يُفعِّل claude-mux ميزة `extended-keys` في tmux افتراضيًا (`TMUX_EXTENDED_KEYS=true`)، وهي تدعم Shift+Enter في معظم الطرفيات الحديثة. إذا لم يعمل Shift+Enter، استخدم `\` + Return لإدخال أسطر جديدة في موجِّهك.

### "Ready." عند بدء الجلسة

عند بدء جلسة أو إعادة تشغيلها، يُرسل claude-mux رسالة `ready` تلقائيًا بعد انتهاء تحميل Claude. يُخبر الحقن Claude بالرد بـ "Ready." فحسب ولا شيء آخر. هذا يؤكد أن الجلسة حية وأن الحقن يعمل.

### الأوامر المائلة عبر Remote Control

الأوامر المائلة (مثل `/model` و `/clear`) [غير مدعومة بشكل أصيل](https://github.com/anthropics/claude-code/issues/30674) في جلسات RC. يلتف claude-mux حول ذلك — تُحقن كل جلسة بـ `claude-mux -s` بحيث يستطيع Claude إرسال الأوامر المائلة إلى نفسه عبر tmux.

## السجلات

- `~/Library/Logs/claude-mux.log` — جميع إجراءات السكربت بطوابع زمنية UTC (قابل للضبط عبر `LOG_DIR`)

لتصحيح أخطاء LaunchAgent منخفضة المستوى، استخدم Console.app أو `log show`.
