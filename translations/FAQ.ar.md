# الأسئلة الشائعة

[English](../FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · **العربية** · [हिन्दी](FAQ.hi.md)

## ما هو claude-mux؟

سكربت شِل يُغلِّف Claude Code في tmux لجلسات دائمة. تبقى الجلسات حية بعد إغلاق الطرفية وتستأنف سياق المحادثة عند إعادة التشغيل ويمكن الوصول إليها من تطبيق Claude للهاتف المحمول عبر Remote Control. تُدير كل شيء بالتحدث مع Claude داخل جلسة.

## هل يعمل على Linux؟

ليس بعد. macOS فقط (Apple Silicon وIntel). دعم Linux مخطط للإصدار v2.0. يعمل المُثبِّت على Linux لكنه يتجاوز إعداد LaunchAgent ويطبع ملاحظة. الملف التنفيذي نفسه يعمل لكن لا يوجد خدمة systemd أو آلية بدء تلقائي مكافئة بعد.

## ما هي الجلسة الرئيسية؟

الجلسة الرئيسية هي جلسة Claude عامة الغرض تعيش في دليلك الأساسي (`~/Claude` افتراضيا). عندما يكون `LAUNCHAGENT_MODE=home` (الافتراضي)، تُطلق تلقائيا عند تسجيل الدخول وتبقى تعمل طوال اليوم. هي **محمية** افتراضيا، أي أن `--shutdown home` يرفض إيقافها دون `--force`.

استخدم الجلسة الرئيسية كنقطة دخول دائمة التوفر من تطبيق Claude للهاتف المحمول. من هناك يمكنك عرض المشاريع وبدء جلسات أخرى وإدارة الإعدادات وإنجاز عمل عام لا ينتمي لمشروع محدد.

## ما هو Remote Control؟

Remote Control (RC) ميزة في Claude Code تتيح الاتصال بجلسة Claude قيد التشغيل من تطبيق Claude للهاتف المحمول أو Claude Desktop. يُطلق claude-mux كل جلسة مع تفعيل `--remote-control` فتظهر جميع الجلسات في قائمة RC تلقائيا. بمجرد الاتصال تتحدث مع Claude بنفس الطريقة كما في الطرفية. يلتف claude-mux أيضا حول قيود RC مثل عدم عمل الأوامر المائلة أصلا بتوجيهها عبر tmux.

## ما هي أوضاع الأذونات؟

يملك Claude Code أربعة أوضاع أذونات تتحكم في مدى استقلالية Claude:

| الوضع | السلوك |
|-------|--------|
| `default` | يسأل Claude قبل تشغيل الأوامر أو تعديل الملفات |
| `acceptEdits` | يُطبِّق Claude تعديلات الملفات تلقائيا لكن يسأل قبل أوامر الشِل |
| `plan` | يستطيع Claude القراءة والتخطيط فقط، لا كتابة ولا أوامر |
| `bypassPermissions` | يُشغِّل Claude كل شيء دون سؤال (يتطلب تأكيدا عند الإطلاق الأول) |

اضبط الافتراضي لجميع المشاريع عبر `DEFAULT_PERMISSION_MODE` في الإعدادات. بدِّل جلسة قيد التشغيل بقول "switch this session to plan mode" (أو أي اسم وضع). "yolo" اختصار لـ `bypassPermissions`.

التبديل إلى `bypassPermissions` من وضع آخر يستخدم تنقل Shift+Tab ولا يتطلب إعادة تشغيل. التبديل من `bypassPermissions` إلى وضع آخر يتطلب إعادة تشغيل يتولاها claude-mux تلقائيا.

## كيف أُعيد تعيين جلسة؟

ثلاثة خيارات حسب ما تريد:

- **مسح** ("clear this session"): يُرسل `/clear` إلى الجلسة. يمسح سجل المحادثة ويبدأ من جديد. تبقى الجلسة تعمل.
- **ضغط** ("compact this session"): يُرسل `/compact` إلى الجلسة. يُلخِّص المحادثة في سياق أقصر مما يُحرِّر نافذة السياق. يُحفظ السجل بصيغة مضغوطة.
- **إعادة تشغيل** ("restart this session"): يُوقف Claude ويُعيد إطلاقه بـ `claude -c` الذي يستأنف آخر محادثة. استخدم هذا عند الحاجة لعملية نظيفة (مثلا بعد تغيير أوضاع الأذونات أو حين يتوقف Claude عن الاستجابة).

## ما هي القوالب؟

القوالب ملفات CLAUDE.md قابلة لإعادة الاستخدام مُخزَّنة في `~/.claude-mux/templates/`. عند إنشاء مشروع جديد بـ `-n`، يُنسخ القالب الافتراضي (أو الذي تُحدِّده بـ `--template NAME`) إلى المشروع كملف CLAUDE.md.

إنشاء قالب: "save this as a template named web" (ينسخ CLAUDE.md من المشروع الحالي إلى `~/.claude-mux/templates/web.md`).

استخدام قالب: `claude-mux -n ~/projects/my-app --template web` أو من داخل جلسة: "create a new project called my-app using the web template".

عرض القوالب: "list templates" أو `claude-mux --list-templates`.

## كيف تعمل نصيحة اليوم؟

خطاف Stop في Claude Code داخل `.claude/settings.local.json` لكل مشروع يستدعي `claude-mux --tipotd` بعد كل دورة محادثة. يتحقق الأمر مما إذا عُرضت نصيحة اليوم بالفعل (عبر `~/.claude-mux/.tip-date`). إذا نعم، يخرج في حوالي 6 ملي ثانية. إذا لا، يطبع نصيحة ويُسجِّل تاريخ اليوم.

النصائح مُفعَّلة افتراضيا (`TIP_OF_DAY=true`). بدِّل بقول "enable tips" أو "disable tips" داخل أي جلسة. `TIP_MODE=daily` يعرض نفس النصيحة طوال اليوم؛ `TIP_MODE=random` يختار نصيحة عشوائية لكل استدعاء (مع خطاف Stop يعني نصيحة عشوائية واحدة في اليوم بسبب البوابة اليومية).

أمر `--tip` يعمل دائما بغض النظر عن البوابة اليومية، فيمكنك قول "tip" في أي وقت.

## هل يمكنني استخدامه مع حسابات GitHub متعددة؟

نعم. يكتشف claude-mux مُدخلات `Host github.com-*` في `~/.ssh/config` ويحقنها في موجِّه نظام كل جلسة. يعرف Claude أي أسماء SSH المستعارة متوفرة ويمكنه استخدام الصحيح عند إعداد git remotes.

مثال إعداد `~/.ssh/config`:

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

سيعرف Claude عندها استخدام `git@github.com-work:org/repo.git` لمستودعات العمل و`git@github.com-personal:user/repo.git` للمستودعات الشخصية.

## أين تُخزَّن الحالة؟

| الموقع | ما يحتويه |
|--------|-----------|
| `~/.claude-mux/config` | إعدادات المستخدم (تُحمَّل كـ bash) |
| `~/.claude-mux/templates/` | ملفات قوالب CLAUDE.md |
| `~/.claude-mux/.tip-date` | تاريخ آخر نصيحة مُعروضة |
| `~/.claude-mux/.update-check` | نتيجة فحص التحديث المُخبَّأة |
| `~/Library/Logs/claude-mux.log` | ملف السجل (قابل للضبط عبر `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | ملف LaunchAgent plist (يُولَّد بواسطة `--install`) |
| `.claudemux-protected` (لكل مشروع) | يُعلِّم الجلسة كمحمية من الإيقاف |
| `.claudemux-ignore` (لكل مشروع) | يُخفي المشروع من القوائم |

ملفات الإشارة (`.claudemux-*`) تعيش في جذر كل مشروع وتتبعه عند إعادة التسمية والنقل والمزامنة. تُضاف تلقائيا إلى `.gitignore`.

سجل المحادثات يُديره Claude Code نفسه ويُخزَّن تحت `~/.claude/projects/`.

## ماذا يحدث مع التحديث التلقائي إذا عملت fork لـ claude-mux؟

فحص التحديث وأمر `--update` يستخدمان `pereljon/claude-mux` كمستودع GitHub المُضمَّن. إذا عملت fork، ستظل فحوصات التحديث تُقارن بالإصدار الأصلي وسيستبدل `--update` ملفك التنفيذي بالأصلي. اضبط `UPDATE_CHECK=false` في `~/.claude-mux/config` لتعطيل ذلك أو غيِّر عنوان المستودع في دالتي `check_for_update()` و`do_update()` في السكربت.

## كيف أُثبِّت عبر Homebrew؟

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

حدِّث بـ `brew upgrade claude-mux`. ملاحظة: إذا ثبَّتت عبر Homebrew، يُفوِّض `--update` تلقائيا إلى `brew upgrade`.

## كيف يختلف هذا عن `claude --worktree --tmux`؟

`claude --worktree --tmux` يُنشئ جلسة tmux لشجرة عمل git معزولة مصممة لمهام البرمجة المتوازية. يُدير claude-mux جلسات دائمة لأدلة مشاريعك الفعلية مع تفعيل Remote Control وحقن موجِّه النظام للإدارة الذاتية واستئناف المحادثة وإدارة دورة حياة الجلسات. يحلان مشكلات مختلفة.

## لماذا تعرض الجلسات "Not logged in"؟

يحدث هذا عند الإطلاق الأول إذا كانت سلسلة مفاتيح macOS مقفلة، وهو شائع عند بدء LaunchAgent قبل فتح سلسلة المفاتيح بعد تسجيل الدخول. أصلحه بتشغيل `security unlock-keychain` في طرفية عادية ثم ألحق بأي جلسة (`claude-mux -t <name>`) وشغِّل `/login` لإكمال تدفق مصادقة المتصفح. بعد ذلك أعد تشغيل جميع الجلسات وستلتقط بيانات الاعتماد المحفوظة.

## هل يمكن لعدة طرفيات الإلحاق بنفس الجلسة؟

نعم. هذا سلوك tmux القياسي. تشغيل `claude-mux` في دليل لديه جلسة قيد التشغيل بالفعل يُلحقك بها. ترى عدة طرفيات محتوى الجلسة نفسه في الوقت الحقيقي.

## كيف أُوقف الجلسة الرئيسية نهائيا؟

LaunchAgent مُعدّ بـ `KeepAlive: true`، فإيقاف الجلسة الرئيسية يُحفِّز إعادة إنشائها خلال حوالي 60 ثانية. لإيقافها نهائيا، عطِّل LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## ماذا تعني رسالة "Session ready!"؟

عند بدء جلسة أو إعادة تشغيلها، يُرسل claude-mux موجِّه `Ready?` بعد انتهاء تحميل Claude. يُخبر الحقن Claude بالرد بـ "Session ready!" فحسب ولا شيء آخر. هذا يؤكد أن الجلسة حية وأن حقن موجِّه النظام يعمل. يمكنك تجاهلها.

## كيف أُخفي مشروعا من القوائم؟

قل "hide this project" داخل أي جلسة أو شغِّل `claude-mux --hide my-project`. يُنشئ هذا ملف إشارة `.claudemux-ignore`. لن يظهر المشروع في مُخرجات `claude-mux -L`. لرؤية المشاريع المخفية: `claude-mux -L --hidden`. لإظهاره مجددا: "show this project" أو `claude-mux --show my-project`.

## كيف أُزيل claude-mux؟

```bash
claude-mux --uninstall
```

يُزيل هذا خطافات النصائح وقواعد الأذونات من جميع المشاريع ويُلغي تحميل LaunchAgent ويعرض اختياريا إزالة `~/.claude-mux/`. يُبلِّغ عن مسار الملف التنفيذي لتحذفه يدويا (أو `brew uninstall claude-mux` إذا ثُبِّت عبر Homebrew).

## هل تعمل الأوامر المائلة عبر Remote Control؟

ليس أصلا. لا يدعم Claude Code الأوامر المائلة (`/model` و`/clear` وغيرها) في جلسات RC. يلتف claude-mux حول ذلك بحقن كل جلسة بـ `claude-mux -s` بحيث يستطيع Claude إرسال الأوامر المائلة إلى نفسه عبر tmux. قل فقط "switch to Haiku" أو "compact this session" وسيتولى Claude الأمر.

## لا أستطيع تحديد نص في جلسة

اضغط مع الاستمرار على **Option** (macOS) أو **Shift** (طرفيات Linux/Windows) أثناء النقر والسحب. يتجاوز هذا التقاط فأرة tmux وينسخ التحديد إلى حافظة النظام. لا حاجة لتغيير الإعدادات.

## ما اللغات المدعومة للأوامر التحاورية؟

جميعها. عبارات التحفيز ("help" و"status" و"list sessions" وغيرها) تعمل بأي لغة. يستنتج Claude القصد من اللغة الطبيعية للمستخدم ويُنفِّذ الأمر المقابل. الملف التمهيدي مُترجم أيضا إلى 12 لغة.
