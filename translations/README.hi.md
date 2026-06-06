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

- **सेशन खत्म हो जाते हैं** जब आप टर्मिनल बंद करते हैं
- **Conversation context** अपने आप resume नहीं होता
- **कोई home base नहीं** - जब आप फोन उठाते हैं तो कुछ नहीं चल रहा होता जब तक आपने कुछ खुला न छोड़ा हो
- **Remote Control को चल रहे सेशन की ज़रूरत है** - आप RC से नया सेशन शुरू नहीं कर सकते
- **Slash commands RC सेशन में काम नहीं करते** - न model switching, न compacting, न permission mode बदलना
- **नए प्रोजेक्ट शुरू करना** - manually डायरेक्टरी बनाना, git initialize करना, CLAUDE.md लिखना, और model चुनना होता है
- **कोई प्रोजेक्ट management नहीं** - idle प्रोजेक्ट देखने, या rename, move, delete करने का कोई तरीका नहीं बिना history तोड़े

**claude-mux session management की कमी को पूरा करता है।** यह Claude Code को tmux में wrap करता है ताकि सेशन बने रहें, एक system prompt inject करता है ताकि Claude अपने सेशन खुद मैनेज कर सके, और slash commands को tmux के माध्यम से route करता है ताकि वे Remote Control पर भी काम करें। एक बार सेशन चलने के बाद, आप Claude से बात करके सब कुछ मैनेज करते हैं - टर्मिनल में या मोबाइल ऐप से।

## claude-mux सेशन में आप क्या कर सकते हैं

- **किसी भी सेशन से किसी भी सेशन को मैनेज करें** - natural language से प्रोजेक्ट शुरू, बंद, restart, list, और compact करें
- **कहीं से भी सब कुछ एक्सेस करें** - हर सेशन में Remote Control सक्षम है, तो Claude मोबाइल ऐप, डेस्कटॉप ऐप, या कोई भी remote client पूरा इंटरफ़ेस है
- **मॉडल और permission modes बदलें** - "switch to Haiku" या "switch to plan mode" कहें और Claude संभाल लेता है, Remote Control पर भी
- **नए प्रोजेक्ट बनाएँ** - "create a new project called my-app" डायरेक्टरी, git, CLAUDE.md सेट करता है और सेशन लॉन्च करता है। CLAUDE.md templates से आप प्रोजेक्ट्स में instructions दोबारा उपयोग कर सकते हैं।
- **रीबूट के बाद भी सेशन चालू रखें** - एक वैकल्पिक होम सेशन लॉगिन पर लॉन्च होता है और चलता रहता है; सभी सेशन अपनी आखिरी बातचीत स्वचालित रूप से resume करते हैं
- **Remote Control पर slash commands भेजें** - Claude `/model`, `/compact`, `/clear`, और अन्य slash commands को चल रहे सेशन में route करता है, एक [ज्ञात सीमा](https://github.com/anthropics/claude-code/issues/30674) का समाधान करते हुए
- **Conversation history सुरक्षित रखें** - rename, move, और restart सभी conversation history स्वचालित रूप से संरक्षित करते हैं
- **प्रोजेक्ट व्यवस्थित करें** - किसी भी सेशन के अंदर से प्रोजेक्ट छिपाएँ, rename करें, move करें, delete करें, और protect करें
- **GitHub multi-account support** - `~/.ssh/config` में SSH aliases पहचानता है और उन्हें सेशन में inject करता है ताकि Claude हर प्रोजेक्ट के लिए सही account उपयोग करे
- **Multi-CLI-coder support** - `AGENTS.md` और `GEMINI.md` symlinks स्वचालित रूप से बनाता है ताकि Codex CLI, Gemini CLI, और अन्य tools instructions शेयर करें
- **किसी भी भाषा में काम करता है** - conversational commands intent से समझे जाते हैं, keywords से नहीं

## Claude से बात करना

यही है claude-mux का रोज़ाना उपयोग। हर सेशन में commands inject किए जाते हैं ताकि Claude सेशन मैनेज कर सके, मॉडल बदल सके, slash commands भेज सके, और नए प्रोजेक्ट बना सके - सब बातचीत के अंदर से। CLI flags याद रखने की ज़रूरत नहीं।

```
आप: "status"
Claude: सेशन नाम, मॉडल, permission mode, context usage, और सभी सेशन की सूची रिपोर्ट करता है

आप: "list active sessions"
Claude: उनके status के साथ सभी चल रहे सेशन दिखाता है

आप: "start a session for my api-server project"
Claude: ~/Claude/work/api-server में एक सेशन लॉन्च करता है

आप: "create a new project called mobile-app using the web template"
Claude: प्रोजेक्ट डायरेक्टरी बनाता है, git initialize करता है, template लागू करता है, सेशन लॉन्च करता है

आप: "switch this session to Haiku"
Claude: tmux के माध्यम से खुद को /model haiku भेजता है

आप: "compact the api-server session"
Claude: api-server सेशन को /compact भेजता है

आप: "restart the web-dashboard session"
Claude: सेशन बंद करके पुनः लॉन्च करता है, conversation context बनाए रखते हुए

आप: "switch the api-server session to plan mode"
Claude: plan permission mode के साथ सेशन पुनः शुरू करता है

आप: "switch this session to yolo mode"
Claude: Shift+Tab के माध्यम से bypassPermissions mode में स्विच करता है - restart की ज़रूरत नहीं

आप: "what mode is this session"
Claude: वर्तमान permission mode (default, acceptEdits, plan, bypassPermissions) रिपोर्ट करता है

आप: "switch this session to Opus"
Claude: tmux के माध्यम से खुद को /model opus भेजता है

आप: "clear this session"
Claude: खुद को /clear भेजता है, बातचीत रीसेट करते हुए

आप: "hide this project"
Claude: .claudemux-ignore लिखता है ताकि प्रोजेक्ट -L लिस्टिंग से बाहर हो जाए

आप: "protect this session"
Claude: .claudemux-protected लिखता है और tmux मार्कर सेट करता है - shutdown अब --force माँगता है

आप: "is this session protected"
Claude: प्रोजेक्ट फ़ोल्डर में .claudemux-protected चेक करता है और बताता है

आप: "delete the old-prototype project"
Claude: चैट में पुष्टि करता है, फिर प्रोजेक्ट फ़ोल्डर सिस्टम ट्रैश में भेजता है

आप: "rename this project to my-new-name"
Claude: सेशन रोकता है, फ़ोल्डर का नाम बदलता है, conversation history migrate करता है, पुनः शुरू करता है

आप: "save this as a template named web"
Claude: CLAUDE.md को ~/.claude-mux/templates/web.md में कॉपी करता है

आप: "tip"
Claude: एक tip प्रिंट करता है - पूरे दिन वही tip, या TIP_MODE=random सेट होने पर random

आप: "enable tips" / "disable tips"
Claude: सभी प्रोजेक्ट्स में डेली टिप चालू या बंद करता है

आप: "update claude-mux"
Claude: चेतावनी देता है कि सभी सेशन restart होंगे, पुष्टि माँगता है, फिर update और restart करता है

आप: "stop all sessions"
Claude: सभी managed सेशन gracefully बंद करता है

आप: "help"
Claude: conversational commands की पूरी सूची प्रिंट करता है
```

**ये commands किसी भी भाषा में काम करते हैं।** अगर आप हिन्दी, जापानी, हिब्रू, या किसी अन्य भाषा में समकक्ष टाइप करते हैं, तो Claude intent समझकर matching command चलाता है।

**किसी भी सेशन में `help` टाइप करें पूरी command list देखने के लिए।**

## और जानें

- [CLI संदर्भ](../docs/CLI.md) - scripting और automation के लिए पूरा command reference
- [गाइड](../docs/guide.md) - कॉन्फ़िगरेशन, सेशन विवरण, आंतरिक संरचना, और समस्या निवारण
- [इंस्टॉल विकल्प](../docs/INSTALL.md) - Homebrew, मैन्युअल इंस्टॉल, LaunchAgent सेटअप
- [FAQ](../docs/FAQ.md) - claude-mux के बारे में आम सवाल
- [ज्ञात समस्याएँ](../docs/ISSUES.md) - open bugs, नियोजित features, और हल की गई समस्याएँ
- [Changelog](../CHANGELOG.md) - हर release में क्या बदला
