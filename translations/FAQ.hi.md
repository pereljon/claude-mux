# FAQ

[English](../FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · **हिन्दी**

## claude-mux क्या है?

एक shell script जो Claude Code को tmux में wrap करती है ताकि सेशन persistent रहें। टर्मिनल बंद होने पर भी सेशन बने रहते हैं, restart पर conversation context resume होता है, और Claude मोबाइल ऐप से Remote Control के माध्यम से एक्सेस करने योग्य होते हैं। सेशन के अंदर Claude से बात करके सब कुछ मैनेज किया जाता है।

## क्या यह Linux पर काम करता है?

अभी नहीं। केवल macOS (Apple Silicon और Intel)। Linux support v2.0 में नियोजित है। installer Linux पर चलता है लेकिन LaunchAgent setup छोड़ देता है और एक नोट प्रिंट करता है। binary काम करती है, लेकिन अभी कोई systemd service या समकक्ष auto-start mechanism नहीं है।

## होम सेशन क्या है?

होम सेशन एक सामान्य-उद्देश्य Claude सेशन है जो आपकी बेस डायरेक्टरी (`~/Claude` by default) में रहता है। जब `LAUNCHAGENT_MODE=home` (default) हो, तो यह लॉगिन पर स्वचालित रूप से लॉन्च होता है और पूरे दिन चलता रहता है। यह डिफ़ॉल्ट रूप से **सुरक्षित** है, यानी `--shutdown home` इसे `--force` के बिना रोकने से इनकार करता है।

होम सेशन को Claude मोबाइल ऐप से अपने हमेशा-उपलब्ध entry point के रूप में उपयोग करें। यहाँ से आप प्रोजेक्ट सूचीबद्ध कर सकते हैं, अन्य सेशन शुरू कर सकते हैं, config मैनेज कर सकते हैं, और ऐसा सामान्य काम कर सकते हैं जो किसी विशिष्ट प्रोजेक्ट से संबंधित नहीं है।

## Remote Control क्या है?

Remote Control (RC) एक Claude Code feature है जो आपको Claude मोबाइल ऐप या Claude Desktop से चल रहे Claude सेशन से कनेक्ट करने देता है। claude-mux हर सेशन को `--remote-control` सक्षम करके लॉन्च करता है, इसलिए सभी सेशन RC list में अपने आप दिखते हैं। कनेक्ट होने के बाद, आप Claude से उसी तरह बात करते हैं जैसे टर्मिनल में। claude-mux RC की सीमाओं का भी समाधान करता है जैसे slash commands मूल रूप से काम न करना, उन्हें tmux के माध्यम से route करके।

## Permission modes क्या हैं?

Claude Code में चार permission modes हैं जो नियंत्रित करते हैं कि Claude को कितनी स्वायत्तता मिलती है:

| Mode | व्यवहार |
|------|----------|
| `default` | Claude commands चलाने या files edit करने से पहले पूछता है |
| `acceptEdits` | Claude file edits auto-apply करता है लेकिन shell commands से पहले पूछता है |
| `plan` | Claude केवल पढ़ और plan बना सकता है, कोई writes या commands नहीं |
| `bypassPermissions` | Claude सब कुछ बिना पूछे चलाता है (पहले launch पर confirmation ज़रूरी) |

सभी प्रोजेक्ट्स के लिए default config में `DEFAULT_PERMISSION_MODE` से सेट करें। चल रहा सेशन बदलने के लिए "switch this session to plan mode" (या कोई भी mode नाम) बोलें। "yolo" `bypassPermissions` का alias है।

किसी अन्य mode से `bypassPermissions` में स्विच करना Shift+Tab navigation का उपयोग करता है और restart की ज़रूरत नहीं। `bypassPermissions` से किसी अन्य mode में स्विच करने के लिए restart ज़रूरी है, जो claude-mux स्वचालित रूप से संभालता है।

## सेशन कैसे रीसेट करें?

तीन विकल्प, आपकी ज़रूरत के अनुसार:

- **Clear** ("clear this session"): सेशन को `/clear` भेजता है। conversation history मिटाता है और नए सिरे से शुरू करता है। सेशन चलता रहता है।
- **Compact** ("compact this session"): सेशन को `/compact` भेजता है। बातचीत को एक छोटे context में summarize करता है, context window खाली करते हुए। history compressed form में संरक्षित रहता है।
- **Restart** ("restart this session"): Claude को बंद करता है और `claude -c` से पुनः लॉन्च करता है, जो अंतिम बातचीत resume करता है। इसका उपयोग तब करें जब एक clean process चाहिए (जैसे permission modes बदलने के बाद या जब Claude stuck हो)।

## Templates क्या हैं?

Templates पुन: उपयोग योग्य CLAUDE.md files हैं जो `~/.claude-mux/templates/` में संग्रहीत होती हैं। जब आप `-n` से नया प्रोजेक्ट बनाते हैं, तो default template (या `--template NAME` से निर्दिष्ट) प्रोजेक्ट में CLAUDE.md के रूप में copy होता है।

template बनाएं: "save this as a template named web" (वर्तमान प्रोजेक्ट का CLAUDE.md `~/.claude-mux/templates/web.md` में copy होता है)।

template उपयोग करें: `claude-mux -n ~/projects/my-app --template web` या सेशन के अंदर: "create a new project called my-app using the web template"।

templates सूचीबद्ध करें: "list templates" या `claude-mux --list-templates`।

## Tip-of-the-day कैसे काम करता है?

हर प्रोजेक्ट के `.claude/settings.local.json` में एक Claude Code Stop hook हर conversation turn के बाद `claude-mux --tipotd` चलाता है। command चेक करता है कि आज tip पहले से दिखाया गया है (`~/.claude-mux/.tip-date` के माध्यम से)। अगर हाँ, तो लगभग 6ms में exit हो जाता है। अगर नहीं, तो एक tip प्रिंट करता है और आज की तारीख record करता है।

Tips डिफ़ॉल्ट रूप से सक्षम हैं (`TIP_OF_DAY=true`)। किसी भी सेशन में "enable tips" या "disable tips" बोलकर toggle करें। `TIP_MODE=daily` पूरे दिन वही tip दिखाता है; `TIP_MODE=random` हर invocation पर एक random tip चुनता है (Stop hook के साथ, daily gate के कारण यह प्रति दिन एक random tip होता है)।

`--tip` command daily gate की परवाह किए बिना हमेशा काम करती है, इसलिए आप कभी भी "tip" बोल सकते हैं।

## क्या इसे कई GitHub accounts के साथ उपयोग कर सकते हैं?

हाँ। claude-mux `~/.ssh/config` में `Host github.com-*` entries detect करता है और उन्हें हर सेशन के system prompt में inject करता है। Claude जानता है कि कौन से SSH aliases उपलब्ध हैं और git remotes सेट करते समय सही का उपयोग कर सकता है।

`~/.ssh/config` setup का उदाहरण:

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

Claude तब work repos के लिए `git@github.com-work:org/repo.git` और personal repos के लिए `git@github.com-personal:user/repo.git` उपयोग करेगा।

## State कहाँ संग्रहीत होता है?

| स्थान | क्या रहता है |
|--------|-----------------|
| `~/.claude-mux/config` | user configuration (bash के रूप में sourced) |
| `~/.claude-mux/templates/` | CLAUDE.md template files |
| `~/.claude-mux/.tip-date` | अंतिम tip दिखाने की तारीख |
| `~/.claude-mux/.update-check` | cached version check result |
| `~/Library/Logs/claude-mux.log` | log file (`LOG_DIR` से configurable) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | LaunchAgent plist (`--install` द्वारा generated) |
| `.claudemux-protected` (प्रति प्रोजेक्ट) | सेशन को shutdown से सुरक्षित चिह्नित करता है |
| `.claudemux-ignore` (प्रति प्रोजेक्ट) | प्रोजेक्ट को listings से छिपाता है |

मार्कर files (`.claudemux-*`) हर प्रोजेक्ट की root डायरेक्टरी में रहती हैं और rename, move, और sync पर फ़ोल्डर के साथ चलती हैं। ये `.gitignore` में अपने आप जोड़ी जाती हैं।

Conversation history Claude Code द्वारा प्रबंधित होती है, `~/.claude/projects/` के तहत संग्रहीत।

## अगर मैं claude-mux fork करूँ तो auto-update का क्या होगा?

update check और `--update` command GitHub repo के रूप में `pereljon/claude-mux` hardcoded करते हैं। अगर आप fork करते हैं, तो update checks अभी भी upstream release से compare करेंगे, और `--update` आपके fork की binary को upstream से overwrite करेगा। अक्षम करने के लिए `~/.claude-mux/config` में `UPDATE_CHECK=false` सेट करें, या script में `check_for_update()` और `do_update()` functions में repo URL बदलें।

## Homebrew से कैसे इंस्टॉल करें?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

`brew upgrade claude-mux` से update करें। नोट: अगर Homebrew से इंस्टॉल किया है, तो `--update` अपने आप `brew upgrade` को delegate करता है।

## यह `claude --worktree --tmux` से कैसे अलग है?

`claude --worktree --tmux` एक isolated git worktree के लिए tmux सेशन बनाता है, जो parallel coding tasks के लिए designed है। claude-mux आपकी वास्तविक प्रोजेक्ट डायरेक्टरीज़ के लिए persistent सेशन मैनेज करता है, Remote Control सक्षम, self-management के लिए system prompt injection, conversation resume, और session lifecycle management के साथ। ये अलग-अलग समस्याएँ हल करते हैं।

## सेशन "Not logged in" क्यों दिखाते हैं?

यह पहले launch पर होता है यदि macOS keychain locked है, जो आम है जब LaunchAgent आपके login के बाद keychain unlock करने से पहले शुरू होता है। इसे ठीक करने के लिए सामान्य टर्मिनल में `security unlock-keychain` चलाएं, फिर किसी सेशन से attach करें (`claude-mux -t <name>`) और browser auth flow पूरा करने के लिए `/login` चलाएं। उसके बाद, सभी सेशन restart करें और वे stored credential उठा लेंगे।

## क्या एक ही सेशन से कई terminals attach हो सकते हैं?

हाँ। यह standard tmux व्यवहार है। `claude-mux` को ऐसी डायरेक्टरी में चलाना जिसमें पहले से चल रहा सेशन है, उससे attach हो जाता है। कई terminals real time में एक ही सेशन content देखते हैं।

## होम सेशन को स्थायी रूप से कैसे रोकें?

LaunchAgent में `KeepAlive: true` है, इसलिए होम सेशन kill करने पर लगभग 60 seconds में respawn होता है। स्थायी रूप से रोकने के लिए, LaunchAgent अक्षम करें:

```bash
claude-mux --install --launchagent-mode none
```

## "Session ready!" message का क्या मतलब है?

जब कोई सेशन शुरू होता है या पुनः शुरू होता है, claude-mux Claude के load होने के बाद एक `Ready?` prompt भेजता है। injection Claude को "Session ready!" और कुछ नहीं respond करने के लिए कहता है। यह confirm करता है कि सेशन alive है और system prompt injection काम कर रहा है। आप इसे अनदेखा कर सकते हैं।

## प्रोजेक्ट को listings से कैसे छिपाएं?

किसी भी सेशन में "hide this project" बोलें, या `claude-mux --hide my-project` चलाएं। यह एक `.claudemux-ignore` मार्कर file बनाता है। प्रोजेक्ट `claude-mux -L` output में नहीं दिखेगा। छिपे हुए प्रोजेक्ट देखने के लिए: `claude-mux -L --hidden`। दिखाने के लिए: "show this project" या `claude-mux --show my-project`।

## claude-mux कैसे uninstall करें?

```bash
claude-mux --uninstall
```

यह सभी प्रोजेक्ट्स से tip hooks और permission rules हटाता है, LaunchAgent unload करता है, और वैकल्पिक रूप से `~/.claude-mux/` हटाता है। यह binary path report करता है ताकि आप इसे manually delete कर सकें (या Homebrew से इंस्टॉल किया है तो `brew uninstall claude-mux`)।

## क्या slash commands Remote Control पर काम करते हैं?

मूल रूप से नहीं। Claude Code RC सेशन में slash commands (`/model`, `/clear`, आदि) support नहीं करता। claude-mux इसका समाधान करता है हर सेशन को `claude-mux -s` inject करके ताकि Claude tmux के माध्यम से खुद को slash commands भेज सके। बस "switch to Haiku" या "compact this session" बोलें और Claude संभाल लेगा।

## सेशन में text select नहीं हो रहा

Click और drag करते समय **Option** (macOS) या **Shift** (Linux/Windows terminals) दबाए रखें। यह tmux के mouse capture को bypass करता है और selection को system clipboard में copy करता है। कोई config बदलने की ज़रूरत नहीं।

## Conversational commands के लिए कौन सी भाषाएँ supported हैं?

सभी। trigger phrases ("help", "status", "list sessions", आदि) किसी भी भाषा में काम करते हैं। Claude user की natural language से intent समझता है और matching command चलाता है। README भी 12 भाषाओं में translated है।
