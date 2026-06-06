# अक्सर पूछे जाने वाले प्रश्न

[English](../docs/FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · **हिन्दी**

## claude-mux क्या है?

एक shell script जो Claude Code को tmux में wrap करता है ताकि सेशन परसिस्टेंट रहें। सेशन टर्मिनल बंद करने पर भी बने रहते हैं, restart पर conversation context resume करते हैं, और Claude मोबाइल ऐप से Remote Control के माध्यम से एक्सेस करने योग्य होते हैं। सेशन के अंदर Claude से बात करके सब कुछ मैनेज करते हैं।

## क्या यह Linux पर काम करता है?

अभी नहीं। केवल macOS (Apple Silicon और Intel)। Linux support v2.0 के लिए नियोजित है। इंस्टॉलर Linux पर चलता है लेकिन LaunchAgent सेटअप छोड़ देता है और एक नोट प्रिंट करता है। binary खुद काम करता है, लेकिन अभी कोई systemd service या समकक्ष auto-start mechanism नहीं है।

## होम सेशन क्या है?

होम सेशन एक सामान्य-उद्देश्य Claude सेशन है जो आपकी बेस डायरेक्टरी (`~/Claude` by default) में रहता है। जब `LAUNCHAGENT_MODE=home` (default) हो, तो यह लॉगिन पर स्वचालित रूप से लॉन्च होता है और पूरे दिन चलता रहता है। यह डिफ़ॉल्ट रूप से **सुरक्षित** है, यानी `--shutdown home` इसे `--force` के बिना रोकने से इनकार करता है।

होम सेशन को Claude मोबाइल ऐप से हमेशा-उपलब्ध entry point के रूप में उपयोग करें। वहाँ से आप प्रोजेक्ट list कर सकते हैं, अन्य सेशन शुरू कर सकते हैं, config मैनेज कर सकते हैं, और ऐसा सामान्य काम कर सकते हैं जो किसी विशिष्ट प्रोजेक्ट से संबंधित नहीं है।

## Remote Control क्या है?

Remote Control (RC) Claude Code की एक feature है जो आपको Claude मोबाइल ऐप या Claude Desktop से चल रहे Claude सेशन से कनेक्ट करने देती है। claude-mux हर सेशन को `--remote-control` सक्षम करके लॉन्च करता है, इसलिए सभी सेशन RC list में स्वचालित रूप से दिखते हैं। कनेक्ट होने के बाद, आप Claude से वैसे ही बात करते हैं जैसे टर्मिनल में। claude-mux RC की सीमाओं जैसे slash commands का मूल रूप से काम न करना भी हल करता है, उन्हें tmux के माध्यम से route करके।

## Permission modes क्या हैं?

Claude Code के चार permission modes हैं जो Claude की स्वायत्तता को नियंत्रित करते हैं:

| Mode | व्यवहार |
|------|---------|
| `default` | Claude commands चलाने या files edit करने से पहले पूछता है |
| `acceptEdits` | Claude file edits स्वचालित रूप से लागू करता है लेकिन shell commands से पहले पूछता है |
| `plan` | Claude केवल पढ़ और plan कर सकता है, कोई writes या commands नहीं |
| `bypassPermissions` | Claude सब कुछ बिना पूछे चलाता है (पहली बार launch पर confirmation आवश्यक) |

सभी प्रोजेक्ट्स के लिए default `DEFAULT_PERMISSION_MODE` से config में सेट करें। चल रहा सेशन बदलने के लिए "switch this session to plan mode" कहें (या कोई भी mode नाम)। "yolo" `bypassPermissions` का उपनाम है।

किसी अन्य mode से `bypassPermissions` में स्विच करना Shift+Tab navigation का उपयोग करता है और restart की आवश्यकता नहीं। `bypassPermissions` से किसी अन्य mode में स्विच करने के लिए restart आवश्यक है, जो claude-mux स्वचालित रूप से संभालता है।

## सेशन कैसे रीसेट करें?

तीन विकल्प, जो आप चाहते हैं उस पर निर्भर:

- **Clear** ("clear this session"): सेशन को `/clear` भेजता है। Conversation history मिटाता है और ताज़ा शुरू करता है। सेशन चलता रहता है।
- **Compact** ("compact this session"): सेशन को `/compact` भेजता है। बातचीत को छोटे context में summarize करता है, context window खाली करता है। History संपीड़ित रूप में संरक्षित रहती है।
- **Restart** ("restart this session"): Claude को बंद करता है और `claude -c` से फिर से लॉन्च करता है, जो आखिरी बातचीत resume करता है। इसका उपयोग तब करें जब clean process चाहिए (जैसे permission modes बदलने के बाद या जब Claude अटक गया हो)।

## Templates क्या हैं?

Templates `~/.claude-mux/templates/` में stored पुनः उपयोग योग्य CLAUDE.md files हैं। जब `-n` से नया प्रोजेक्ट बनाते हैं, default template (या `--template NAME` से specify किया हुआ) प्रोजेक्ट में CLAUDE.md के रूप में copy होता है।

Template बनाएँ: "save this as a template named web" (वर्तमान प्रोजेक्ट का CLAUDE.md `~/.claude-mux/templates/web.md` में copy करता है)।

Template उपयोग करें: `claude-mux -n ~/projects/my-app --template web` या सेशन के अंदर से: "create a new project called my-app using the web template"।

Templates सूचीबद्ध करें: "list templates" या `claude-mux --list-templates`।

## Tip-of-the-day कैसे काम करता है?

प्रत्येक प्रोजेक्ट के `.claude/settings.local.json` में एक Claude Code `UserPromptSubmit` hook हर prompt पर `claude-mux --on-prompt` को call करता है। दिन का पहला prompt conversation में एक tip inject करता है; उस दिन के बाद के prompts कुछ inject नहीं करते। State हर session के लिए अलग है, `~/.claude-mux/tip-state/<session_id>.json` में संग्रहीत, इसलिए हर active session दिन में एक बार tip दिखाता है। चूँकि hook context में inject करता है (Stop hook नहीं, जिसका output केवल transcript में जाता है), tip conversation और Remote Control में दिखता है।

Tips डिफ़ॉल्ट रूप से सक्षम हैं (`TIP_OF_DAY=true`)। किसी भी सेशन में "enable tips" या "disable tips" से toggle करें। `TIP_MODE=daily` पूरे दिन वही tip दिखाता है; `TIP_MODE=random` एक random tip चुनता है।

`--tip` command हमेशा काम करती है daily gate की परवाह किए बिना (और `TIP_OF_DAY` की परवाह किए बिना), तो आप कभी भी "tip" कह सकते हैं।

## क्या इसे कई GitHub accounts के साथ उपयोग कर सकता हूँ?

हाँ। claude-mux `~/.ssh/config` में `Host github.com-*` entries पहचानता है और उन्हें हर सेशन के system prompt में inject करता है। Claude जानता है कौन से SSH aliases उपलब्ध हैं और git remotes सेट करते समय सही वाला उपयोग कर सकता है।

`~/.ssh/config` सेटअप उदाहरण:

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

Claude जानेगा कि work repos के लिए `git@github.com-work:org/repo.git` और personal repos के लिए `git@github.com-personal:user/repo.git` उपयोग करना है।

## State कहाँ stored है?

| स्थान | क्या रहता है |
|--------|-------------|
| `~/.claude-mux/config` | User configuration (bash के रूप में sourced) |
| `~/.claude-mux/templates/` | CLAUDE.md template files |
| `~/.claude-mux/tip-state/<session_id>.json` | प्रति-session tip तारीख + update सूचना throttle |
| `~/.claude-mux/.update-check` | Cached version check result |
| `~/.claude-mux/.update-checking` | background update check के दौरान lock |
| `~/Library/Logs/claude-mux.log` | Log file (`LOG_DIR` से configurable) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | LaunchAgent plist (`--install` द्वारा generated) |
| `.claudemux-protected` (प्रति प्रोजेक्ट) | सेशन को shutdown से सुरक्षित चिह्नित करता है |
| `.claudemux-ignore` (प्रति प्रोजेक्ट) | प्रोजेक्ट को listings से छुपाता है |

Marker files (`.claudemux-*`) हर प्रोजेक्ट की root डायरेक्टरी में रहती हैं और rename, move, और sync पर फ़ोल्डर के साथ चलती हैं। ये `.gitignore` में स्वचालित रूप से जुड़ जाती हैं।

Conversation history Claude Code खुद मैनेज करता है, `~/.claude/projects/` के तहत stored।

## अगर मैंने claude-mux fork किया तो auto-update का क्या होगा?

Update check और `--update` command `pereljon/claude-mux` को GitHub repo के रूप में hardcode करते हैं। अगर आपने fork किया, तो update checks अभी भी upstream release से compare करेंगे, और `--update` आपकी fork की binary को upstream से overwrite कर देगा। `UPDATE_CHECK=false` `~/.claude-mux/config` में सेट करें अक्षम करने के लिए, या script में `check_for_update()` और `do_update()` functions में repo URL बदलें।

## Homebrew से कैसे install करें?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

`brew upgrade claude-mux` से update करें। नोट: अगर Homebrew से install किया है, तो `--update` स्वचालित रूप से `brew upgrade` को delegate करता है।

## यह `claude --worktree --tmux` से कैसे अलग है?

`claude --worktree --tmux` एक isolated git worktree के लिए tmux सेशन बनाता है, parallel coding tasks के लिए designed। claude-mux आपकी वास्तविक प्रोजेक्ट directories के लिए persistent sessions मैनेज करता है, Remote Control सक्षम, self-management के लिए system prompt injection, conversation resume, और session lifecycle management के साथ। ये अलग-अलग समस्याएँ हल करते हैं।

## यह Claude Cowork Dispatch से कैसे अलग है?

Dispatch Claude desktop app से tasks लॉन्च करता है, लेकिन app को चलना ज़रूरी है और यह किसी विशिष्ट प्रोजेक्ट से बंधा नहीं है। claude-mux persistent, project-bound sessions मैनेज करता है जो reboots के बाद भी बने रहते हैं और Remote Control से कहीं से भी accessible हैं - desktop app की ज़रूरत नहीं।

## सेशन "Not logged in" क्यों दिखाते हैं?

यह पहले launch पर होता है अगर macOS keychain locked है, जो आम है जब LaunchAgent login के बाद keychain unlock करने से पहले शुरू होता है। इसे ठीक करने के लिए normal टर्मिनल में `security unlock-keychain` चलाएँ, फिर किसी सेशन से attach करें (`claude-mux -t <name>`) और browser auth flow पूरा करने के लिए `/login` चलाएँ। उसके बाद, सभी सेशन restart करें और वे stored credential उठा लेंगे।

## क्या कई terminals एक ही सेशन से attach हो सकते हैं?

हाँ। यह standard tmux व्यवहार है। ऐसी डायरेक्टरी में `claude-mux` चलाना जिसमें पहले से सेशन चल रहा है, उससे attach हो जाता है। कई terminals एक ही सेशन content real time में देखते हैं।

## होम सेशन स्थायी रूप से कैसे रोकें?

LaunchAgent में `KeepAlive: true` है, इसलिए होम सेशन kill करने पर लगभग 60 seconds में respawn होता है। स्थायी रूप से रोकने के लिए, LaunchAgent अक्षम करें:

```bash
claude-mux --install --launchagent-mode none
```

## "Session ready!" message का क्या मतलब है?

जब कोई सेशन शुरू या restart होता है, claude-mux Claude के load होने के बाद `Ready?` prompt भेजता है। Injection Claude को "Session ready!" और कुछ नहीं respond करने के लिए कहता है। यह confirm करता है कि सेशन alive है और system prompt injection काम कर रहा है। इसे ignore कर सकते हैं।

## प्रोजेक्ट को listings से कैसे छिपाएँ?

किसी भी सेशन में "hide this project" कहें, या `claude-mux --hide my-project` चलाएँ। यह `.claudemux-ignore` marker file बनाता है। प्रोजेक्ट `claude-mux -L` output में नहीं दिखेगा। छिपे प्रोजेक्ट देखने के लिए: `claude-mux -L --hidden`। unhide करने के लिए: "show this project" या `claude-mux --show my-project`।

## claude-mux कैसे uninstall करें?

```bash
claude-mux --uninstall
```

यह सभी प्रोजेक्ट्स से tip hooks और permission rules हटाता है, LaunchAgent unload करता है, और वैकल्पिक रूप से `~/.claude-mux/` remove करता है। Binary path report करता है ताकि आप इसे manually delete कर सकें (या Homebrew से install किया था तो `brew uninstall claude-mux`)।

## क्या slash commands Remote Control पर काम करते हैं?

मूल रूप से नहीं। Claude Code RC sessions में slash commands (`/model`, `/clear`, आदि) support नहीं करता। claude-mux हर सेशन में `claude-mux -s` inject करके इसका समाधान करता है ताकि Claude tmux के माध्यम से खुद को slash commands भेज सके। बस "switch to Haiku" या "compact this session" कहें और Claude संभाल लेता है।

## सेशन में text select नहीं कर पा रहा

Click और drag करते समय **Option** (macOS) या **Shift** (Linux/Windows terminals) दबाए रखें। यह tmux के mouse capture को bypass करता है और selection को system clipboard में copy करता है। किसी config change की ज़रूरत नहीं।

## Conversational commands के लिए कौन सी भाषाएँ supported हैं?

सभी। Trigger phrases ("help", "status", "list sessions", आदि) किसी भी भाषा में काम करते हैं। Claude user की natural language से intent समझता है और matching command चलाता है। README भी 12 भाषाओं में translated है।
