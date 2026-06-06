# الأسئلة الشائعة

[English](../docs/FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · **العربية** · [हिन्दी](FAQ.hi.md)

## ما هو claude-mux؟

سكربت shell يُغلِّف Claude Code في tmux لجلسات دائمة. الجلسات تصمد بعد إغلاق الطرفية، وتستأنف سياق المحادثة عند إعادة التشغيل، ويمكن الوصول إليها من تطبيق Claude للهاتف عبر Remote Control. تُدير كل شيء بالتحدث مع Claude داخل جلسة.

## هل يعمل على Linux؟

ليس بعد. macOS فقط (Apple Silicon وIntel). دعم Linux مُخطط لـ v2.0. المثبِّت يعمل على Linux لكنه يتجاوز إعداد LaunchAgent ويطبع ملاحظة. الملف التنفيذي نفسه يعمل، لكن لا يوجد بعد خدمة systemd أو آلية بدء تلقائي مكافئة.

## ما هي الجلسة الرئيسية؟

الجلسة الرئيسية هي جلسة Claude عامة الغرض تعيش في دليلك الأساسي (`~/Claude` افتراضيا). عندما يكون `LAUNCHAGENT_MODE=home` (الافتراضي)، تُطلق تلقائيا عند تسجيل الدخول وتبقى تعمل طوال اليوم. هي **محمية** افتراضيا، أي أن `--shutdown home` يرفض إيقافها دون `--force`.

استخدم الجلسة الرئيسية كنقطة دخول متاحة دائما من تطبيق Claude للهاتف. منها يمكنك سرد المشاريع وبدء جلسات أخرى وإدارة الإعدادات والقيام بعمل عام لا ينتمي لمشروع محدد.

## ما هو Remote Control؟

Remote Control (RC) هو ميزة في Claude Code تتيح الاتصال بجلسة Claude قيد التشغيل من تطبيق Claude للهاتف أو Claude Desktop. يُطلق claude-mux كل جلسة مع `--remote-control` مُفعَّلا، فتظهر جميع الجلسات في قائمة RC تلقائيا. بعد الاتصال، تتحدث مع Claude كما في الطرفية. يلتف claude-mux أيضا حول قيود RC مثل عدم عمل الأوامر المائلة أصلا، بتوجيهها عبر tmux.

## ما هي أوضاع الأذونات؟

Claude Code لديه أربعة أوضاع أذونات تتحكم في مقدار الاستقلالية التي يملكها Claude:

| الوضع | السلوك |
|-------|--------|
| `default` | Claude يسأل قبل تشغيل الأوامر أو تعديل الملفات |
| `acceptEdits` | Claude يُطبِّق تعديلات الملفات تلقائيا لكن يسأل قبل أوامر shell |
| `plan` | Claude يمكنه القراءة والتخطيط فقط، لا كتابة ولا أوامر |
| `bypassPermissions` | Claude يُنفِّذ كل شيء دون سؤال (يتطلب تأكيدا عند الإطلاق الأول) |

اضبط الافتراضي لجميع المشاريع عبر `DEFAULT_PERMISSION_MODE` في الإعدادات. بدِّل جلسة قيد التشغيل بقول "switch this session to plan mode" (أو أي اسم وضع). "yolo" هو اسم مختصر لـ `bypassPermissions`.

التحول إلى `bypassPermissions` من وضع آخر يستخدم تنقل Shift+Tab ولا يتطلب إعادة تشغيل. التحول من `bypassPermissions` إلى وضع آخر يتطلب إعادة تشغيل، يتولاها claude-mux تلقائيا.

## كيف أُعيد ضبط جلسة؟

ثلاثة خيارات حسب ما تريد:

- **Clear** ("clear this session"): يُرسل `/clear` إلى الجلسة. يمسح سجل المحادثة ويبدأ من جديد. الجلسة تبقى تعمل.
- **Compact** ("compact this session"): يُرسل `/compact` إلى الجلسة. يُلخِّص المحادثة في سياق أقصر، محررا نافذة السياق. السجل يُحفظ بشكل مضغوط.
- **Restart** ("restart this session"): يُوقف Claude ويُعيد إطلاقه بـ `claude -c` الذي يستأنف آخر محادثة. استخدم هذا عندما تحتاج عملية نظيفة (مثلا بعد تغيير أوضاع الأذونات أو عندما يتوقف Claude).

## ما هي القوالب؟

القوالب هي ملفات CLAUDE.md قابلة لإعادة الاستخدام مخزنة في `~/.claude-mux/templates/`. عند إنشاء مشروع جديد بـ `-n`، يُنسخ القالب الافتراضي (أو واحد تحدده بـ `--template NAME`) إلى المشروع كـ CLAUDE.md.

إنشاء قالب: "save this as a template named web" (ينسخ CLAUDE.md الحالي إلى `~/.claude-mux/templates/web.md`).

استخدام قالب: `claude-mux -n ~/projects/my-app --template web` أو من داخل جلسة: "create a new project called my-app using the web template".

سرد القوالب: "list templates" أو `claude-mux --list-templates`.

## كيف تعمل نصيحة اليوم؟

خطاف Claude Code من نوع `UserPromptSubmit` في `.claude/settings.local.json` لكل مشروع يستدعي `claude-mux --on-prompt` عند كل مُطالبة. أول مُطالبة في اليوم تحقن نصيحة واحدة في المحادثة؛ المطالبات اللاحقة في ذلك اليوم لا تحقن شيئا. الحالة لكل جلسة، مُخزَّنة في `~/.claude-mux/tip-state/<session_id>.json`، لذا تعرض كل جلسة نشطة النصيحة مرة واحدة يوميا. لأن الخطاف يحقن في السياق (وليس خطاف Stop الذي يكون مُخرَجه في النص فقط)، تكون النصيحة مرئية في المحادثة وفي Remote Control.

النصائح مُفعَّلة افتراضيا (`TIP_OF_DAY=true`). بدِّل بـ "enable tips" أو "disable tips" داخل أي جلسة. `TIP_MODE=daily` يعرض نفس النصيحة طوال اليوم؛ `TIP_MODE=random` يختار نصيحة عشوائية.

الأمر `--tip` يعمل دائما بغض النظر عن البوابة اليومية (وبغض النظر عن `TIP_OF_DAY`)، فيمكنك قول "tip" في أي وقت.

## هل يمكنني استخدامه مع حسابات GitHub متعددة؟

نعم. يكتشف claude-mux إدخالات `Host github.com-*` في `~/.ssh/config` ويحقنها في موجِّه النظام لكل جلسة. يعرف Claude أي أسماء SSH المستعارة متاحة ويمكنه استخدام الصحيح عند إعداد git remotes.

مثال على إعداد `~/.ssh/config`:

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

سيعرف Claude استخدام `git@github.com-work:org/repo.git` لمستودعات العمل و`git@github.com-personal:user/repo.git` للشخصية.

## أين تُخزَّن الحالة؟

| الموقع | المحتوى |
|--------|---------|
| `~/.claude-mux/config` | إعدادات المستخدم (يُقرأ كـ bash) |
| `~/.claude-mux/templates/` | ملفات قوالب CLAUDE.md |
| `~/.claude-mux/tip-state/<session_id>.json` | تاريخ نصيحة كل جلسة + خانق إشعار التحديث |
| `~/.claude-mux/.update-check` | نتيجة فحص الإصدار المحفوظة |
| `~/.claude-mux/.update-checking` | قفل أثناء فحص التحديث في الخلفية |
| `~/Library/Logs/claude-mux.log` | ملف السجل (قابل للتعديل عبر `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | ملف plist لـ LaunchAgent (يُنشئه `--install`) |
| `.claudemux-protected` (لكل مشروع) | يُعلِّم الجلسة كمحمية من الإيقاف |
| `.claudemux-ignore` (لكل مشروع) | يُخفي المشروع من القوائم |

ملفات الإشارة (`.claudemux-*`) تعيش في جذر كل مشروع وتنتقل مع المجلد عند إعادة التسمية والنقل والمزامنة. تُضاف تلقائيا إلى `.gitignore`.

سجل المحادثات يُدار من Claude Code نفسه، مُخزَّن تحت `~/.claude/projects/`.

## ماذا يحدث مع التحديث التلقائي إذا عملت fork لـ claude-mux؟

فحص التحديث والأمر `--update` يُقيِّدان `pereljon/claude-mux` كمستودع GitHub. إذا عملت fork، ستقارن فحوصات التحديث مع إصدار upstream، و`--update` سيستبدل ملفك التنفيذي بـ upstream. اضبط `UPDATE_CHECK=false` في `~/.claude-mux/config` للتعطيل، أو غيِّر عنوان المستودع في دوال `check_for_update()` و`do_update()` في السكربت.

## كيف أُثبِّت عبر Homebrew؟

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

حدِّث بـ `brew upgrade claude-mux`. ملاحظة: إذا ثبَّتت عبر Homebrew، فإن `--update` يُفوِّض تلقائيا إلى `brew upgrade`.

## ما الفرق بينه وبين `claude --worktree --tmux`؟

`claude --worktree --tmux` يُنشئ جلسة tmux لشجرة عمل git معزولة، مصمَّمة لمهام البرمجة المتوازية. claude-mux يُدير جلسات دائمة لأدلة مشاريعك الفعلية، مع تفعيل Remote Control وحقن موجِّه نظام للإدارة الذاتية واستئناف المحادثات وإدارة دورة حياة الجلسات. يحلان مشكلتين مختلفتين.

## ما الفرق بينه وبين Claude Cowork Dispatch؟

Dispatch يُطلق مهام من تطبيق Claude لسطح المكتب، لكنه يتطلب تشغيل التطبيق وليس مرتبطا بمشروع محدد. claude-mux يُدير جلسات دائمة مرتبطة بمشاريع تصمد بعد إعادة التشغيل ويمكن الوصول إليها من أي مكان عبر Remote Control - دون الحاجة لتطبيق سطح المكتب.

## لماذا تعرض الجلسات "Not logged in"؟

يحدث هذا عند الإطلاق الأول إذا كانت سلسلة مفاتيح macOS مقفلة، وهو شائع عندما يبدأ LaunchAgent قبل فتح سلسلة المفاتيح بعد تسجيل الدخول. أصلحه بتشغيل `security unlock-keychain` في طرفية عادية، ثم ألحق بأي جلسة (`claude-mux -t <name>`) وشغِّل `/login` لإكمال تدفق المصادقة بالمتصفح. بعد ذلك، أعد تشغيل جميع الجلسات وستلتقط بيانات الاعتماد المحفوظة.

## هل يمكن لعدة طرفيات الإلحاق بنفس الجلسة؟

نعم. هذا سلوك tmux القياسي. تشغيل `claude-mux` في دليل لديه جلسة قيد التشغيل يُلحقك بها. عدة طرفيات ترى نفس محتوى الجلسة في الوقت الحقيقي.

## كيف أوقف الجلسة الرئيسية نهائيا؟

LaunchAgent لديه `KeepAlive: true`، فإيقاف الجلسة الرئيسية يُفعِّل إعادة التشغيل خلال حوالي 60 ثانية. لإيقافها نهائيا، عطِّل LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## ماذا تعني رسالة "Session ready!"؟

عند بدء جلسة أو إعادة تشغيلها، يُرسل claude-mux موجِّه `Ready?` بعد انتهاء تحميل Claude. الحقن يُخبر Claude بالرد بـ "Session ready!" فقط ولا شيء آخر. هذا يؤكد أن الجلسة حية وحقن موجِّه النظام يعمل. يمكنك تجاهلها.

## كيف أخفي مشروعا من القوائم؟

قل "hide this project" داخل أي جلسة، أو شغِّل `claude-mux --hide my-project`. هذا يُنشئ ملف إشارة `.claudemux-ignore`. المشروع لن يظهر في خرج `claude-mux -L`. لرؤية المشاريع المخفية: `claude-mux -L --hidden`. لإلغاء الإخفاء: "show this project" أو `claude-mux --show my-project`.

## كيف أُزيل claude-mux؟

```bash
claude-mux --uninstall
```

يُزيل خطافات النصائح وقواعد الأذونات من جميع المشاريع، ويُفرِّغ LaunchAgent، ويحذف اختياريا `~/.claude-mux/`. يُبلِّغ عن مسار الملف التنفيذي لتتمكن من حذفه يدويا (أو `brew uninstall claude-mux` إذا ثُبِّت عبر Homebrew).

## هل تعمل الأوامر المائلة عبر Remote Control؟

ليس أصلا. Claude Code لا يدعم الأوامر المائلة (`/model` و`/clear` إلخ) في جلسات RC. يلتف claude-mux حول ذلك بحقن `claude-mux -s` في كل جلسة حتى يتمكن Claude من إرسال الأوامر المائلة إلى نفسه عبر tmux. فقط قل "switch to Haiku" أو "compact this session" وClaude يتولى الأمر.

## لا أستطيع تحديد نص في جلسة

اضغط باستمرار على **Option** (macOS) أو **Shift** (طرفيات Linux/Windows) أثناء النقر والسحب. هذا يتجاوز التقاط الفأرة في tmux وينسخ التحديد إلى حافظة النظام. لا حاجة لتغيير إعدادات.

## ما اللغات المدعومة للأوامر التحاورية؟

جميعها. عبارات التشغيل ("help" و"status" و"list sessions" إلخ) تعمل بأي لغة. يستنتج Claude المقصد من اللغة الطبيعية للمستخدم ويُنفِّذ الأمر المقابل. ملف README مترجم أيضا إلى 12 لغة.
