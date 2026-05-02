# claude-mux - Claude Code मल्टीप्लेक्सर

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · **हिन्दी**

आपके सभी प्रोजेक्ट्स के लिए परसिस्टेंट Claude Code सेशन - Claude मोबाइल ऐप के माध्यम से कहीं से भी एक्सेस करने योग्य।

## क्यों

Remote Control का वादा है कि Claude Code को कहीं से भी इस्तेमाल किया जा सके — लेकिन session management के बिना, यह Claude Desktop से भी एक द्वितीय श्रेणी का इंटरफ़ेस है:

- टर्मिनल बंद करने पर सेशन खत्म हो जाते हैं और conversation context अपने आप resume नहीं होता
- कोई permanent home base नहीं है — जब आप फोन उठाते हैं तो कुछ भी नहीं चल रहा होता जब तक कि आपने कुछ खुला न छोड़ा हो
- अगर कोई सेशन नहीं चल रहा तो Remote Control बेकार है — न किसी प्रोजेक्ट तक पहुंच सकते हैं, न नया शुरू कर सकते हैं
- चल रहे RC सेशन में भी slash commands काम नहीं करते — न model switching, न compaction, न permission mode बदलना
- नया प्रोजेक्ट शुरू करने के लिए manually directory बनानी होती है, git init करना होता है, CLAUDE.md लिखना होता है, permission mode सेट करना होता है और model चुनना होता है — इनमें से कुछ भी RC से नहीं हो सकता
- कई प्रोजेक्ट्स मैनेज करने का मतलब है कई manual terminal launches, और कोई overview नहीं कि क्या चल रहा है या किस state में है

claude-mux यह सब ठीक करता है। यह Claude Code को tmux में लपेटता है ताकि सेशन बने रहें, एक system prompt inject करता है ताकि Claude अपने सेशन खुद मैनेज कर सके, और slash commands को tmux के माध्यम से रूट करता है ताकि वे Remote Control पर भी काम करें। एक बार सेशन चलने के बाद, आप Claude से बात करके सब कुछ मैनेज करते हैं - टर्मिनल में या मोबाइल ऐप से।

## त्वरित शुरुआत

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

```bash
cd ~/path/to/your/project
claude-mux
```

या:

```bash
claude-mux ~/path/to/your/project
```

बस इतना ही। आप एक परसिस्टेंट, सेशन-अवेयर Claude सेशन में हैं जिसमें Remote Control सक्षम है। यहाँ से, सब कुछ बातचीत से होता है।

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


You: "switch this session to yolo mode"
Claude: switches to bypassPermissions mode via Shift+Tab — no restart needed

You: "what mode is this session"
Claude: reports the current permission mode (default, acceptEdits, plan, bypassPermissions)

You: "switch this session to Opus"
Claude: sends /model opus to itself via tmux

You: "clear this session"
Claude: sends /clear to itself, resetting the conversation

You: "hide this project"
Claude: writes .claudemux-ignore so the project is excluded from -L listings

You: "protect this session"
Claude: writes .claudemux-protected and sets the tmux marker — shutdown now requires --force

You: "is this session protected"
Claude: checks for .claudemux-protected in the project folder and reports

You: "delete the old-prototype project"
Claude: confirms in chat, then moves the project folder to system trash

You: "update claude-mux"
Claude: warns that all sessions will restart, asks for confirmation, then updates and restarts


आप: "stop all sessions"
Claude: सभी मैनेज्ड सेशन gracefully बंद करता है

आप: "help"
Claude: conversational commands की पूरी सूची प्रिंट करता है
```

ये commands किसी भी भाषा में काम करते हैं। यदि आप हिन्दी, जापानी, हिब्रू, या किसी अन्य भाषा में समकक्ष टाइप करते हैं, तो Claude intent समझकर matching command चलाता है।

किसी भी सेशन में `help` टाइप करें पूरी command list देखने के लिए।

### होम सेशन

होम सेशन एक सामान्य-उद्देश्य सेशन है जो आपकी बेस डायरेक्टरी (`~/Claude` by default) में रहता है। `LAUNCHAGENT_MODE=home` होने पर यह लॉगिन पर स्वचालित रूप से लॉन्च होता है, जो आपको एक हमेशा-तैयार Claude सेशन देता है जो आपके फोन से एक्सेस करने योग्य है। इसका उपयोग अपने सभी अन्य सेशन मैनेज करने के लिए करें बिना पहले प्रोजेक्ट-विशिष्ट सेशन लॉन्च किए।

होम सेशन डिफ़ॉल्ट रूप से **सुरक्षित** होता है - `--shutdown home` इसे `--force` के बिना रोकने से इनकार करता है। सुरक्षा `$BASE_DIR` में `.claudemux-protected` मार्कर फ़ाइल द्वारा नियंत्रित होती है, जो `claude-mux --install` द्वारा बनाई जाती है। सुरक्षित सेशन status column में `protected` दिखाते हैं; calling session को name column में `>` से चिह्नित किया जाता है।

## यह क्या करता है

claude-mux के अंदर यह सब होता है:

- **परसिस्टेंट tmux सेशन** Remote Control सक्षम के साथ, ताकि हर सेशन Claude मोबाइल ऐप से एक्सेस करने योग्य हो
- **Conversation resume** - पुनः लॉन्च करने पर अंतिम बातचीत (`claude -c`) resume करता है, context बनाए रखते हुए
- **System prompt injection** - प्रत्येक सेशन को self-management, slash command routing, और SSH account awareness के लिए commands मिलते हैं
- **CLAUDE.md templates** - `~/.claude-mux/templates/` में template files (जैसे `web.md`, `python.md`) रखें और नए प्रोजेक्ट्स पर लागू करें
- **Multi-CLI-coder support** - Codex CLI, Gemini CLI, और अन्य tools के लिए `AGENTS.md` और `GEMINI.md` को `CLAUDE.md` के symlinks के रूप में बनाता है ताकि सभी एक ही instructions शेयर करें
- **Auto-approved permissions** - claude-mux को हर प्रोजेक्ट की allow list में जोड़ता है ताकि Claude बिना prompt किए session commands चला सके
- **Stray process migration** - यदि Claude पहले से tmux के बाहर चल रहा है, तो उसे managed सेशन में migrate करता है
- **Tmux quality-of-life** - mouse support, 50k scrollback, clipboard, 256-color, extended keys, activity monitoring, tab titles

> **नोट:** यह `claude --worktree --tmux` से अलग है, जो एक isolated git worktree के लिए tmux सेशन बनाता है। claude-mux आपकी वास्तविक प्रोजेक्ट डायरेक्टरीज़ के लिए परसिस्टेंट सेशन मैनेज करता है, Remote Control और system prompt injection के साथ।

## आवश्यकताएँ

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## इंस्टॉल

### Homebrew (अनुशंसित)

```bash
brew tap pereljon/tap
brew install claude-mux
```

इंस्टॉल करने के बाद, अपना config बनाने और optionally LaunchAgent install करने के लिए setup command चलाएं (लॉगिन पर होम सेशन):

```bash
claude-mux --install
```

अपडेट करने के लिए:

```bash
brew upgrade claude-mux       # या: claude-mux --update  (किसी भी सेशन के अंदर से काम करता है)
```

### मैन्युअल

```bash
./install.sh
```

`install.sh` binary को `~/bin` में copy करता है और `PATH` में add करता है। उसके बाद, चलाएं:

```bash
claude-mux --install
```

इंटरैक्टिव setup पूछता है कि आपके Claude प्रोजेक्ट्स कहाँ रहते हैं, लॉगिन पर होम सेशन शुरू करना है या नहीं, और कौन सा मॉडल उपयोग करना है। यह `~/.claude-mux/config` बनाता है और LaunchAgent install करता है।

prompts छोड़ने और defaults स्वीकार करने के लिए `--non-interactive` का उपयोग करें।

विकल्प:

```bash
claude-mux --install --non-interactive                     # prompts छोड़ें, defaults उपयोग करें
claude-mux --install --base-dir ~/work/claude              # अलग बेस डायरेक्टरी उपयोग करें
claude-mux --install --launchagent-mode none               # LaunchAgent व्यवहार अक्षम करें
claude-mux --install --home-model haiku                    # होम सेशन के लिए Haiku उपयोग करें
claude-mux --install --no-launchagent                      # LaunchAgent installation पूरी तरह छोड़ें
```

LaunchAgent लॉगिन पर `claude-mux --autolaunch` को 45-सेकंड startup delay के साथ चलाता है ताकि system services initialize हो सकें।

## सेशन स्टेटस

| स्टेटस | अर्थ |
|--------|---------|
| `running` | tmux सेशन मौजूद है और Claude चल रहा है |
| `protected` | `running` जैसा ही, लेकिन सेशन सुरक्षित है — `--shutdown` को रोकने के लिए `--force` की आवश्यकता है |
| `stopped` | tmux सेशन मौजूद है लेकिन Claude exit हो चुका है |
| `idle` | `BASE_DIR` के तहत एक `.claude/` प्रोजेक्ट मौजूद है लेकिन कोई claude-mux tmux सेशन नहीं चल रहा (केवल `-L` के साथ दिखाया जाता है) |

सेशन नाम पर `>` prefix (जैसे `> home`) उस सेशन को चिह्नित करता है जिसने list command चलाई।

`claude-mux` को ऐसी डायरेक्टरी में चलाना जिसमें पहले से चल रहा सेशन है, उससे attach हो जाता है। एक ही सेशन से कई टर्मिनल attach हो सकते हैं (standard tmux व्यवहार)।

## प्रोजेक्ट मार्कर

प्रति-प्रोजेक्ट स्थिति केंद्रीय config में नहीं, बल्कि प्रोजेक्ट रूट पर मार्कर फ़ाइलों में संग्रहीत होती है। मार्कर `.claudemux-` prefix का उपयोग करते हैं और git-tracked प्रोजेक्ट में बनाए जाने पर स्वचालित रूप से `.gitignore` में जोड़ दिए जाते हैं।

| मार्कर | अर्थ | CLI |
|--------|------|-----|
| `.claudemux-protected` | लॉन्च पर सेशन सुरक्षित होता है — `--shutdown` को `--force` चाहिए | `--protect` / `--unprotect` |
| `.claudemux-ignore` | प्रोजेक्ट `claude-mux -L` लिस्टिंग से छिपा होता है | `--hide` / `--show` |

```bash
claude-mux --hide                    # वर्तमान प्रोजेक्ट को -L लिस्टिंग से छिपाएं
claude-mux --show                    # वर्तमान प्रोजेक्ट को फिर से दिखाएं
claude-mux --protect                 # इस सेशन को गलती से बंद होने से बचाएं
claude-mux --unprotect               # सुरक्षा हटाएं
claude-mux -L --hidden               # केवल छिपे हुए प्रोजेक्ट सूचीबद्ध करें
claude-mux --delete ~/projects/old   # प्रोजेक्ट फ़ोल्डर को सिस्टम ट्रैश में ले जाएं (macOS)
```

मार्कर प्रोजेक्ट फ़ोल्डर के साथ rename और move पर चलते हैं। एक ही `.gitignore` पैटर्न (`.claudemux-*`) सभी वर्तमान और भविष्य के मार्कर को कवर करता है।

## कॉन्फ़िगरेशन

`~/.claude-mux/config` `claude-mux --install` द्वारा बनाया जाता है (या किसी भी command के पहले run पर यदि कोई config नहीं है)। किसी भी default को override करने के लिए इसे edit करें - script को कभी सीधे modify करने की ज़रूरत नहीं है।

| वेरिएबल | डिफ़ॉल्ट | विवरण |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Claude प्रोजेक्ट्स (`.claude/` वाली डायरेक्टरीज़) के लिए scan की जाने वाली root डायरेक्टरी |
| `LOG_DIR` | `$HOME/Library/Logs` | `claude-mux.log` फ़ाइल के लिए डायरेक्टरी |
| `DEFAULT_PERMISSION_MODE` | `auto` | प्रत्येक प्रोजेक्ट में Claude का `permissions.defaultMode` सेट करें। मान्य: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`। अक्षम करने के लिए `""` सेट करें। |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | जब `true` हो, Claude सेशन अन्य सेशन को slash commands भेज सकते हैं - multi-agent orchestration के लिए उपयोगी |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | CLAUDE.md template files वाली डायरेक्टरी |
| `DEFAULT_TEMPLATE` | `default.md` | नए प्रोजेक्ट्स (`-n`) पर लागू default template। अक्षम करने के लिए `""` सेट करें। |
| `SLEEP_BETWEEN` | `5` | `-a` का उपयोग करने पर सेशन launches के बीच seconds। RC registration fail होने पर बढ़ाएँ। |
| `HOME_SESSION_MODEL` | `""` | होम सेशन के लिए मॉडल। मान्य: `sonnet`, `haiku`, `opus`। खाली होने पर Claude का default inherit करता है। |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | अन्य AI CLI tools के लिए `CLAUDE.md` के symlinks के रूप में बनाई जाने वाली files की space-separated सूची। अक्षम करने के लिए `""` सेट करें। |
| `LAUNCHAGENT_MODE` | `home` | लॉगिन पर LaunchAgent व्यवहार: `none` (कुछ नहीं करें) या `home` (सुरक्षित होम सेशन लॉन्च करें)। Legacy `LAUNCHAGENT_ENABLED=true` को `home` के रूप में माना जाता है। |

**Tmux सेशन विकल्प** (सभी configurable, सभी default रूप से सक्षम):

| वेरिएबल | डिफ़ॉल्ट | विवरण |
|----------|---------|-------------|
| `TMUX_MOUSE` | `true` | Mouse support - scroll, select, panes का आकार बदलें |
| `TMUX_HISTORY_LIMIT` | `50000` | Lines में scrollback buffer size (tmux default 2000 है) |
| `TMUX_CLIPBOARD` | `true` | OSC 52 के माध्यम से system clipboard integration |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | उचित color rendering के लिए terminal type |
| `TMUX_EXTENDED_KEYS` | `true` | Shift+Enter सहित extended key sequences (tmux 3.2+ की आवश्यकता) |
| `TMUX_ESCAPE_TIME` | `10` | Escape key delay milliseconds में (tmux default 500 है) |
| `TMUX_TITLE_FORMAT` | `#S` | Terminal/tab title format (`#S` = सेशन नाम, अक्षम करने के लिए `""`) |
| `TMUX_MONITOR_ACTIVITY` | `true` | अन्य सेशन में activity होने पर सूचित करें |

## डायरेक्टरी संरचना

प्रोजेक्ट किसी भी गहराई पर `.claude/` डायरेक्टरी की उपस्थिति से खोजे जाते हैं:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ .claude/ है - मैनेज्ड
│   │   └── .claude/
│   ├── project-b/          # ✓ .claude/ है - मैनेज्ड
│   │   └── .claude/
│   └── -archived/          # ✗ बहिष्कृत (- से शुरू)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ .claude/ है - मैनेज्ड
│   │   └── .claude/
│   ├── .hidden/            # ✗ बहिष्कृत (hidden डायरेक्टरी)
│   │   └── .claude/
│   └── project-d/          # ✗ कोई .claude/ नहीं - Claude प्रोजेक्ट नहीं
├── deep/nested/project-e/  # ✓ .claude/ है - किसी भी गहराई पर मिला
│   └── .claude/
└── ignored-project/        # ✗ बहिष्कृत (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

सेशन नाम डायरेक्टरी नामों से प्राप्त होते हैं: spaces hyphens बन जाते हैं, non-alphanumeric characters (hyphens को छोड़कर) बदल दिए जाते हैं, और शुरू/अंत के hyphens हटा दिए जाते हैं। जिन डायरेक्टरीज़ का नाम sanitize होकर खाली हो जाता है, उन्हें log warning के साथ छोड़ दिया जाता है।

## सेशन सिस्टम प्रॉम्प्ट

प्रत्येक Claude सेशन को इसके environment के बारे में context वाले `--append-system-prompt` के साथ लॉन्च किया जाता है:

```
You are running inside tmux session '<session-name>'.
claude-mux version: <version>
[Update available: <new-version> (found <date>). Tell the user and suggest they say "update claude-mux" to update.]
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
- When user says: ready — respond with "Session ready!" on one line. Nothing else.
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
- When user says: update claude-mux — warns about restart, gets confirmation, then runs --update and --restart

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
  --update                    Update claude-mux to the latest version
  -a                          Start ALL sessions (use with caution)

GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

(update line optional है — केवल तभी दिखाई देती है जब कोई update pending हो।)

जब `ALLOW_CROSS_SESSION_CONTROL=true` हो, तो send command बदल जाती है ताकि किसी भी सेशन को target किया जा सके, सिर्फ़ खुद को नहीं। path launch समय पर script का absolute path है, इसलिए सेशन `PATH` पर निर्भर नहीं करते।

## CLI संदर्भ

आपको इनकी सीधे ज़रूरत कम ही पड़ती है - Claude सेशन के अंदर से आपके लिए ये चलाता है। ये scripting, automation, या जब आप सेशन के बाहर हों, तब के लिए उपलब्ध हैं।

```bash
# लॉन्च और attach
claude-mux                       # वर्तमान डायरेक्टरी में Claude लॉन्च करें और attach करें
claude-mux ~/projects/my-app     # डायरेक्टरी में Claude लॉन्च करें और attach करें
claude-mux -d ~/projects/my-app  # ऊपर के समान (explicit form)
claude-mux -t my-app             # मौजूदा tmux सेशन से attach करें

# नए प्रोजेक्ट बनाएँ
claude-mux -n ~/projects/app     # नया Claude प्रोजेक्ट बनाएँ और attach करें
claude-mux -n ~/new/path/app -p  # वही, डायरेक्टरी और parents बनाते हुए
claude-mux -n ~/app --template web        # विशिष्ट CLAUDE.md template के साथ नया प्रोजेक्ट
claude-mux -n ~/app --no-multi-coder      # AGENTS.md/GEMINI.md symlinks के बिना नया प्रोजेक्ट

# सेशन management
claude-mux -l                    # status के अनुसार सेशन सूचीबद्ध करें (active, running, stopped)
claude-mux -L                    # सभी प्रोजेक्ट सूचीबद्ध करें (active + idle)
claude-mux -L --hidden           # केवल छिपे हुए प्रोजेक्ट सूचीबद्ध करें
claude-mux -s my-app '/model sonnet'      # सेशन को slash command भेजें
claude-mux --shutdown my-app              # विशिष्ट सेशन बंद करें
claude-mux --shutdown                     # सभी managed सेशन बंद करें
claude-mux --shutdown home --force        # सुरक्षित होम सेशन बंद करें
claude-mux --restart my-app              # विशिष्ट सेशन पुनः शुरू करें
claude-mux --restart                     # सभी चल रहे सेशन पुनः शुरू करें
claude-mux --permission-mode plan my-app  # plan mode के साथ सेशन पुनः शुरू करें
claude-mux -a                    # BASE_DIR के तहत सभी managed सेशन शुरू करें

# प्रोजेक्ट मार्कर
claude-mux --hide                    # वर्तमान प्रोजेक्ट को -L लिस्टिंग से छिपाएं
claude-mux --hide ~/projects/old     # किसी विशिष्ट प्रोजेक्ट को छिपाएं
claude-mux --show                    # वर्तमान प्रोजेक्ट को फिर से दिखाएं
claude-mux --protect                 # इस सेशन को गलती से बंद होने से बचाएं
claude-mux --unprotect               # सुरक्षा हटाएं
claude-mux --delete ~/projects/old           # प्रोजेक्ट फ़ोल्डर को सिस्टम ट्रैश में ले जाएं (macOS)
claude-mux --delete ~/projects/old --yes     # वही, confirmation prompt छोड़ें

# अन्य
claude-mux --commands            # पूरा CLI reference दिखाएँ
claude-mux --config-help         # डिफ़ॉल्ट और विवरण के साथ सभी config विकल्प दिखाएँ
claude-mux --list-templates      # उपलब्ध CLAUDE.md templates दिखाएँ
claude-mux --guide               # सेशन के अंदर उपयोग के लिए conversational commands दिखाएँ
claude-mux --install          # interactive setup: config + LaunchAgent
claude-mux --update           # latest version पर update करें
claude-mux --dry-run             # execute किए बिना actions का preview करें
claude-mux --version             # version प्रिंट करें
claude-mux --help                # सभी विकल्प दिखाएँ

# लॉग देखें
tail -f ~/Library/Logs/claude-mux.log
```

टर्मिनल से चलाने पर, output को real time में stdout पर mirror किया जाता है। LaunchAgent के माध्यम से चलाने पर, output केवल log file में जाता है।

## समस्या निवारण

### सेशन "Not logged in · Run /login" दिखाते हैं

यह पहले launch पर होता है यदि macOS keychain locked है (आम बात जब script login के बाद keychain unlock होने से पहले चलती है)। समाधान:

```bash
# सामान्य टर्मिनल में keychain unlock करें
security unlock-keychain

# फिर किसी एक चल रहे सेशन में auth पूरा करें
claude-mux -t <any-session>
# /login चलाएँ और browser flow पूरा करें
```

एक बार auth पूरा करने के बाद, सभी सेशन kill करके पुनः launch करें - वे stored credential स्वचालित रूप से उठा लेंगे।

### सेशन Claude Code Remote में नहीं दिख रहे

सेशन authenticated होने चाहिए ("Not logged in" नहीं दिखाते)। एक clean authenticated launch के बाद उन्हें कुछ seconds के भीतर RC list में दिखना चाहिए।

### tmux में multi-line input

`/terminal-setup` command tmux के अंदर नहीं चल सकती। claude-mux default रूप से tmux `extended-keys` सक्षम करता है (`TMUX_EXTENDED_KEYS=true`), जो अधिकांश modern terminals में Shift+Enter को support करता है। यदि Shift+Enter काम नहीं करता, तो अपने prompt में newlines डालने के लिए `\` + Return का उपयोग करें।

### सेशन शुरू होने पर "Ready."

जब सेशन शुरू होता है या पुनः शुरू होता है, claude-mux Claude के load होने के बाद स्वचालित रूप से एक `ready` message भेजता है। injection Claude को "Ready." और कुछ नहीं के साथ respond करने के लिए कहता है। यह confirm करता है कि सेशन alive है और injection काम कर रहा है।

### Remote Control पर slash commands

Slash commands (जैसे `/model`, `/clear`) RC सेशन में [मूल रूप से supported नहीं हैं](https://github.com/anthropics/claude-code/issues/30674)। claude-mux इस पर काम करता है - प्रत्येक सेशन को `claude-mux -s` inject किया जाता है ताकि Claude tmux के माध्यम से खुद को slash commands भेज सके।

## लॉग

- `~/Library/Logs/claude-mux.log` - UTC timestamps के साथ सभी script actions (`LOG_DIR` के माध्यम से configurable)

Low-level LaunchAgent debugging के लिए, Console.app या `log show` का उपयोग करें।
