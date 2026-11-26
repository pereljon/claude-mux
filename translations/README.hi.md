# claude-mux - Claude Code Multiplexer

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · **हिन्दी**

आपके सभी प्रोजेक्ट्स के लिए परसिस्टेंट Claude Code सेशन - Claude मोबाइल ऐप के माध्यम से कहीं से भी एक्सेस करने योग्य। ***Claude द्वारा प्रबंधित!***

## इंस्टॉल

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

फिर एक सेशन शुरू करें:

```bash
claude-mux ~/path/to/your/project
```

इंस्टॉलर पूछता है कि क्या आप लॉगिन पर होम सेशन चाहते हैं। अगर आप स्वीकार करते हैं, तो हर बार लॉगिन करने पर एक सुरक्षित Claude सेशन स्वचालित रूप से लॉन्च होता है - हमेशा आपके फोन या किसी Remote Control क्लाइंट से पहुँचने योग्य, भले ही आप कभी टर्मिनल न खोलें।

बस इतना ही! आप एक परसिस्टेंट, सेशन-अवेयर Claude सेशन में हैं जिसमें Remote Control सक्षम है। **यहाँ से, सब कुछ बातचीत से होता है।**

[Homebrew, मैन्युअल इंस्टॉल, और अन्य विकल्प](../docs/INSTALL.md)

## क्यों

Remote Control का वादा है कि Claude Code को कहीं से भी इस्तेमाल किया जा सके - लेकिन session management के बिना, यह Claude Desktop से भी एक second-class इंटरफ़ेस है:

- **सेशन खत्म हो जाते हैं** जब आप टर्मिनल बंद करते हैं - और क्रैश या रीबूट के बाद वापस नहीं आते
- **Conversation context** अपने आप resume नहीं होता
- **कोई home base नहीं** - जब आप फोन उठाते हैं तो कुछ नहीं चल रहा होता जब तक आपने कुछ खुला न छोड़ा हो
- **Remote Control को चल रहे सेशन की ज़रूरत है** - आप RC से नया सेशन शुरू नहीं कर सकते
- **Slash commands RC सेशन में काम नहीं करते** - न model switching, न compacting, न permission mode बदलना
- **नए प्रोजेक्ट शुरू करना** - manually डायरेक्टरी बनाना, git initialize करना, instructions फ़ाइल (AGENTS.md या CLAUDE.md) लिखना, और model चुनना होता है
- **कोई प्रोजेक्ट management नहीं** - idle प्रोजेक्ट देखने, या rename, move, delete करने का कोई तरीका नहीं बिना history तोड़े

**claude-mux session management की कमी को पूरा करता है।** यह Claude Code को tmux में wrap करता है ताकि सेशन बने रहें, क्रैश और रीबूट के बाद उन्हें अपने आप बहाल करता है (जब तक auto-login चालू है), एक system prompt inject करता है ताकि Claude अपने सेशन खुद मैनेज कर सके, और slash commands को tmux के माध्यम से route करता है ताकि वे Remote Control पर भी काम करें। एक बार सेशन चलने के बाद, आप Claude से बात करके सब कुछ मैनेज करते हैं - टर्मिनल में या मोबाइल ऐप से।

## claude-mux सेशन में आप क्या कर सकते हैं

- **क्रैश और रीबूट से बच निकलता है** - दोबारा लॉगिन करने पर सेशन अपने आप बहाल होते हैं और आखिरी बातचीत जारी रखते हैं। साफ़ `/exit` या shutdown सेशन को बंद रखता है; बार-बार क्रैश होने वाला सेशन हमेशा restart होने के बजाय रोककर चिह्नित कर दिया जाता है।
- **किसी भी सेशन से किसी भी सेशन को मैनेज करें** - natural language से प्रोजेक्ट शुरू, बंद, restart, list, और compact करें
- **कहीं से भी सब कुछ एक्सेस करें** - हर सेशन में Remote Control सक्षम है, तो Claude मोबाइल ऐप, डेस्कटॉप ऐप, या कोई भी remote client पूरा इंटरफ़ेस है
- **मॉडल और permission modes बदलें** - "switch to Haiku" या "switch to plan mode" कहें और Claude संभाल लेता है, Remote Control पर भी
- **नए प्रोजेक्ट बनाएँ** - "create a new project called my-app" डायरेक्टरी, git, template से AGENTS.md सेट करता है और सेशन लॉन्च करता है। Templates से आप प्रोजेक्ट्स में instructions दोबारा उपयोग कर सकते हैं।
- **Remote Control पर slash commands भेजें** - Claude `/model`, `/compact`, `/clear`, और अन्य slash commands को चल रहे सेशन में route करता है, एक [ज्ञात सीमा](https://github.com/anthropics/claude-code/issues/30674) का समाधान करते हुए। `/compact` के बाद RC एक `PreCompact` hook के ज़रिए अपने आप दोबारा जुड़ता है।
- **Claude Code upgrade की पहचान** - जब `claude` binary बदलती है (`brew upgrade` या npm update के बाद), चल रहे सेशन नई binary लोड करने के लिए restart का नोटिस दिखाते हैं; यह नोटिस restart होने तक prompts में बना रहता है, इसलिए छूटा हुआ turn इसे खो नहीं सकता
- **Conversation history सुरक्षित रखें** - rename, move, और restart सभी conversation history स्वचालित रूप से संरक्षित करते हैं
- **प्रोजेक्ट व्यवस्थित करें** - किसी भी सेशन के अंदर से प्रोजेक्ट छिपाएँ, rename करें, move करें, delete करें, और protect करें
- **GitHub multi-account support** - `~/.ssh/config` में SSH aliases पहचानता है और उन्हें सेशन में inject करता है ताकि Claude हर प्रोजेक्ट के लिए सही account उपयोग करे
- **AGENTS.md प्रोजेक्ट-instructions फ़ाइल के रूप में** - `AGENTS.md` एकमात्र असली फ़ाइल है, जिसे Claude Code और Codex CLI पढ़ते हैं। मौजूदा tree को `CLAUDE.md` से बदलने के लिए "migrate to AGENTS.md" कहें (पहले रिपोर्ट, कुछ भी commit नहीं होता)। Claude Code 2.1.277 या बाद का चाहिए; पुराने versions `CLAUDE.md` रखते हैं। Gemini CLI इसे तभी पढ़ता है जब `~/.gemini/settings.json` में `"context": {"fileName": ["AGENTS.md"]}` हो।
- **किसी भी भाषा में काम करता है** - conversational commands intent से समझे जाते हैं, keywords से नहीं

## Claude से बात करना

यही है claude-mux का रोज़ाना उपयोग। हर सेशन में commands inject किए जाते हैं ताकि Claude सेशन मैनेज कर सके, मॉडल बदल सके, slash commands भेज सके, और नए प्रोजेक्ट बना सके - सब बातचीत के अंदर से। CLI flags याद रखने की ज़रूरत नहीं।

```
कहें: "status"
सेशन नाम, मॉडल, permission mode, context usage, और सभी सेशन की सूची रिपोर्ट करता है

कहें: "list active sessions"
उनके status के साथ सभी चल रहे सेशन दिखाता है

कहें: "list idle sessions"
सिर्फ़ idle प्रोजेक्ट दिखाता है

कहें: "list stopped sessions"
सिर्फ़ बंद सेशन दिखाता है

कहें: "start a session for my api-server project"
नाम से सेशन शुरू करता है; पहले से चल रहा हो तो कुछ नहीं करता

कहें: "create a new project called mobile-app using the web template"
प्रोजेक्ट डायरेक्टरी बनाता है, git initialize करता है, template लागू करता है, सेशन लॉन्च करता है

कहें: "switch this session to Haiku"
family को नवीनतम concrete ID में बदलता है और खुद को /model claude-haiku-4-5 भेजता है

कहें: "compact the api-server session"
api-server सेशन को /compact भेजता है

कहें: "restart the web-dashboard session"
सेशन बंद करके पुनः लॉन्च करता है, conversation context बनाए रखते हुए

कहें: "restart this session fresh"
पुष्टि माँगता है, फिर नई बातचीत के साथ restart करता है - कोई resume नहीं, कोई पिछला context नहीं

कहें: "kill the api-server session"
पुष्टि माँगता है, फिर बातचीत साफ़ करके सेशन रोकता है; अगली शुरुआत नई बातचीत होती है, resume नहीं

कहें: "end this session"
पहले अधूरा काम और अगला कदम सहेजता है, पुष्टि माँगता है (और पूछता है कि कुछ बिना सहेजा तो नहीं), फिर नए सिरे से restart करता है

कहें: "switch the api-server session to plan mode"
plan permission mode के साथ सेशन पुनः शुरू करता है

कहें: "switch this session to yolo mode"
Shift+Tab के माध्यम से bypassPermissions mode में स्विच करता है - restart की ज़रूरत नहीं

कहें: "what mode is this session"
वर्तमान permission mode (default, acceptEdits, plan, bypassPermissions) रिपोर्ट करता है

कहें: "switch this session to Opus"
family को नवीनतम concrete ID में बदलता है और खुद को /model claude-opus-4-8 भेजता है

कहें: "clear this session"
पुष्टि माँगता है, फिर खुद को /clear भेजता है, बातचीत रीसेट करते हुए

कहें: "hide this project"
.claudemux-ignore लिखता है ताकि प्रोजेक्ट -L लिस्टिंग से बाहर हो जाए

कहें: "protect this session"
.claudemux-protected लिखता है और tmux मार्कर सेट करता है - shutdown अब --force माँगता है

कहें: "is this session protected"
प्रोजेक्ट फ़ोल्डर में .claudemux-protected चेक करता है और बताता है

कहें: "delete the old-prototype project"
चैट में पुष्टि करता है, फिर प्रोजेक्ट फ़ोल्डर सिस्टम ट्रैश में भेजता है

कहें: "rename this project to my-new-name"
सेशन रोकता है, फ़ोल्डर का नाम बदलता है, conversation history migrate करता है, पुनः शुरू करता है

कहें: "save this as a template named web"
AGENTS.md (या CLAUDE.md) को ~/.claude-mux/templates/web.md में कॉपी करता है

कहें: "check agents migration" / "migrate to AGENTS.md"
(सिर्फ़ पढ़कर) बताता है कि कौन सी CLAUDE.md फ़ाइलें AGENTS.md में जा सकती हैं; पुष्टि मिलने पर पूरे tree में उनका नाम बदलता है और base directory के अंतर्गत चल रहे सेशन restart करता है

कहें: "tip"
एक tip प्रिंट करता है - पूरे दिन वही tip, या TIP_MODE=random सेट होने पर random

कहें: "enable tips" / "disable tips"
सभी प्रोजेक्ट्स में डेली टिप चालू या बंद करता है

कहें: "update claude-mux"
चेतावनी देता है कि सभी सेशन restart होंगे, पुष्टि माँगता है, फिर update और restart करता है

कहें: "stop all sessions"
सभी managed सेशन gracefully बंद करता है

कहें: "help"
conversational commands की पूरी सूची प्रिंट करता है
```

**ये commands किसी भी भाषा में काम करते हैं।** अगर आप हिन्दी, जापानी, हिब्रू, या किसी अन्य भाषा में समकक्ष टाइप करते हैं, तो Claude intent समझकर matching command चलाता है।

**किसी भी सेशन में `help` टाइप करें पूरी command list देखने के लिए।**

## और जानें

- [CLI संदर्भ](../docs/CLI.md) - scripting और automation के लिए पूरा command reference
- [गाइड](../docs/GUIDE.md) - कॉन्फ़िगरेशन, सेशन विवरण, आंतरिक संरचना, और समस्या निवारण
- [इंस्टॉल विकल्प](../docs/INSTALL.md) - Homebrew, मैन्युअल इंस्टॉल, LaunchAgent सेटअप
- [FAQ](../docs/FAQ.md) - claude-mux के बारे में आम सवाल
- [ज्ञात समस्याएँ](../docs/ISSUES.md) - open bugs, नियोजित features, और हल की गई समस्याएँ
- [Changelog](../CHANGELOG.md) - हर release में क्या बदला
