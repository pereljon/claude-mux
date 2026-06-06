# claude-mux - مُضاعِف جلسات Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · **العربية** · [हिन्दी](README.hi.md)

جلسات Claude Code دائمة لجميع مشاريعك - يمكن الوصول إليها من أي مكان عبر تطبيق Claude للهاتف المحمول. ***يديره Claude!***

## التثبيت

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

ثم ابدأ جلسة:

```bash
claude-mux ~/path/to/your/project
```

المثبِّت يسأل إن كنت تريد جلسة رئيسية عند تسجيل الدخول. إذا وافقت، تُطلق جلسة Claude محمية تلقائيا في كل مرة تسجِّل فيها الدخول - يمكن الوصول إليها دائما من هاتفك أو أي عميل Remote Control، حتى لو لم تفتح طرفية.

هذا كل شيء! أنت في جلسة Claude دائمة واعية بذاتها مع تفعيل Remote Control. **من هنا، كل شيء تحاوري.**

[Homebrew والتثبيت اليدوي وخيارات أخرى](../docs/INSTALL.md)

## لماذا

يَعِد Remote Control باستخدام Claude Code من أي مكان - لكن بدون إدارة الجلسات، فهو واجهة من الدرجة الثانية حتى من Claude Desktop:

- **تموت الجلسات** عند إغلاق الطرفية
- **سياق المحادثة** لا يُستأنف تلقائيا
- **لا قاعدة دائمة** - لا شيء يعمل عند التقاط هاتفك ما لم تترك شيئا مفتوحا
- **Remote Control يتطلب جلسة قيد التشغيل** - لا يمكنك بدء واحدة من RC
- **الأوامر المائلة لا تعمل في جلسات RC** - لا تبديل نموذج ولا ضغط ولا تغيير وضع أذونات
- **بدء مشاريع جديدة** يتطلب إنشاء مجلد يدويا وتهيئة git وكتابة CLAUDE.md واختيار نموذج
- **لا إدارة مشاريع** - لا طريقة لرؤية المشاريع الخاملة أو إعادة تسمية المشاريع ونقلها وحذفها دون كسر السجل

**claude-mux يسد ثغرة إدارة الجلسات.** يُغلِّف Claude Code في tmux لتستمر الجلسات، ويحقن موجِّه نظام حتى يتمكن Claude من إدارة جلساته بنفسه، ويُوجِّه الأوامر المائلة عبر tmux لتعمل فوق Remote Control. بمجرد تشغيل جلسة، تُدير كل شيء بالتحدث مع Claude - في الطرفية أو تطبيق الهاتف.

## ما يمكنك فعله في جلسة claude-mux

- **إدارة أي جلسة من أي جلسة** - بدء الجلسات وإيقافها وإعادة تشغيلها وسردها وضغطها باستخدام اللغة الطبيعية
- **الوصول إلى كل شيء من أي مكان** - كل جلسة مُفعَّل فيها Remote Control، فتطبيق Claude للهاتف أو سطح المكتب أو أي عميل بعيد هو واجهة كاملة
- **تبديل النماذج وأوضاع الأذونات** - قل "switch to Haiku" أو "switch to plan mode" وClaude يتولى الأمر، حتى عبر Remote Control
- **إنشاء مشاريع جديدة** - "create a new project called my-app" يُنشئ المجلد وgit وCLAUDE.md ويُطلق جلسة. قوالب CLAUDE.md تتيح إعادة استخدام التعليمات عبر المشاريع.
- **إبقاء الجلسات حية عبر إعادة التشغيل** - جلسة رئيسية اختيارية تُطلق عند تسجيل الدخول وتبقى تعمل؛ كل الجلسات تستأنف آخر محادثة تلقائيا
- **إرسال أوامر مائلة عبر Remote Control** - Claude يُوجِّه `/model` و`/compact` و`/clear` وأوامر مائلة أخرى إلى الجلسة قيد التشغيل، متجاوزا [قيدا معروفا](https://github.com/anthropics/claude-code/issues/30674)
- **حفظ سجل المحادثات** - إعادة التسمية والنقل وإعادة التشغيل تحفظ سجل المحادثات تلقائيا
- **تنظيم المشاريع** - إخفاء المشاريع وإعادة تسميتها ونقلها وحذفها وحمايتها من داخل أي جلسة
- **دعم حسابات GitHub المتعددة** - يكتشف أسماء SSH المستعارة في `~/.ssh/config` ويحقنها في الجلسات حتى يستخدم Claude الحساب الصحيح لكل مشروع
- **دعم أدوات CLI المتعددة** - يُنشئ `AGENTS.md` و`GEMINI.md` كروابط رمزية تلقائيا حتى تشترك Codex CLI وGemini CLI وغيرها في التعليمات
- **يعمل بأي لغة** - الأوامر التحاورية تُستنتج من المعنى لا من الكلمات المفتاحية

## التحدث مع Claude

هكذا تستخدم claude-mux يوميا. كل جلسة مُحقونة بأوامر حتى يتمكن Claude من إدارة الجلسات وتبديل النماذج وإرسال الأوامر المائلة وإنشاء مشاريع جديدة - كل ذلك من داخل المحادثة. لا تحتاج إلى تذكر خيارات سطر الأوامر.

```
أنت: "status"
Claude: يُبلِّغ عن اسم الجلسة والنموذج ووضع الأذونات واستخدام السياق ويعرض جميع الجلسات

أنت: "list active sessions"
Claude: يعرض جميع الجلسات قيد التشغيل وحالاتها

أنت: "start a session for my api-server project"
Claude: يُطلق جلسة في ~/Claude/work/api-server

أنت: "create a new project called mobile-app using the web template"
Claude: يُنشئ مجلد المشروع ويُهيِّئ git ويُطبِّق القالب ويُطلق جلسة

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
Claude: يكتب .claudemux-protected ويضبط إشارة tmux - الإيقاف يتطلب الآن --force

أنت: "is this session protected"
Claude: يتحقق من وجود .claudemux-protected في مجلد المشروع ويُبلِّغ

أنت: "delete the old-prototype project"
Claude: يُؤكد في المحادثة ثم ينقل مجلد المشروع إلى سلة المحذوفات

أنت: "rename this project to my-new-name"
Claude: يُوقف الجلسة ويُعيد تسمية المجلد ويُرحِّل سجل المحادثات ويُعيد التشغيل

أنت: "save this as a template named web"
Claude: ينسخ CLAUDE.md إلى ~/.claude-mux/templates/web.md

أنت: "tip"
Claude: يطبع نصيحة - نفس النصيحة طوال اليوم أو عشوائية إذا ضُبط TIP_MODE=random

أنت: "enable tips" / "disable tips"
Claude: يُفعّل أو يُعطّل نصيحة اليوم عبر جميع المشاريع

أنت: "update claude-mux"
Claude: يُحذِّر بأن جميع الجلسات ستُعاد تشغيلها ويطلب التأكيد ثم يُحدِّث ويُعيد التشغيل

أنت: "stop all sessions"
Claude: يخرج بسلاسة من جميع الجلسات المُدارة

أنت: "help"
Claude: يطبع قائمة الأوامر التحاورية كاملة
```

**تعمل هذه الأوامر بأي لغة.** إذا كتبت ما يعادلها بالإسبانية أو اليابانية أو العبرية أو أي لغة أخرى، يستنتج Claude القصد ويُنفِّذ الأمر المقابل.

**اكتب `help` داخل أي جلسة لرؤية قائمة الأوامر الكاملة.**

## المزيد

- [مرجع CLI](../docs/CLI.md) - مرجع أوامر كامل للبرمجة النصية والأتمتة
- [الدليل](../docs/guide.md) - الإعدادات وتفاصيل الجلسات والبنية الداخلية واستكشاف الأخطاء
- [خيارات التثبيت](../docs/INSTALL.md) - Homebrew والتثبيت اليدوي وإعداد LaunchAgent
- [الأسئلة الشائعة](../docs/FAQ.md) - أسئلة شائعة حول claude-mux
- [المشكلات المعروفة](../docs/ISSUES.md) - أخطاء مفتوحة وميزات مخططة ومشكلات محلولة
- [سجل التغييرات](../CHANGELOG.md) - ما تغير في كل إصدار
