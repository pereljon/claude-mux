# ज्ञात समस्याएँ

[English](../ISSUES.md) · [Español](ISSUES.es.md) · [Français](ISSUES.fr.md) · [Deutsch](ISSUES.de.md) · [Português](ISSUES.pt-BR.md) · [日本語](ISSUES.ja.md) · [한국어](ISSUES.ko.md) · [Italiano](ISSUES.it.md) · [Русский](ISSUES.ru.md) · [中文](ISSUES.zh-CN.md) · [עברית](ISSUES.he.md) · [العربية](ISSUES.ar.md) · **हिन्दी**

## खुली समस्याएँ

### Phantom message replay अनपेक्षित क्रियाएँ करता है
**गंभीरता:** High
**स्थिति:** Open - claude-mux की तरफ से पूरी तरह ठीक नहीं हो सकता
**विवरण:** एक user ने "stop all sessions" भेजा जो 10 messages पहले handle हो चुका था। बाद में, जब claude-mux -s ने tmux send-keys के माध्यम से `/model haiku` भेजा, Claude को एक system message "stop all sessions/model haiku" मिला और उसने सेशन बंद करने की कोशिश की - एक ऐसा action जो user ने कभी request नहीं किया।
**संभावित कारण:**
- Claude Code का interruption handling पुराने context को नई slash command input के साथ concatenate कर सकता है
- पुरानी command वाला conversation history Claude को confuse कर सकता है जब कोई system event होता है
**संभावित समाधान:** injection rule जोड़ें: "बातचीत में पहले handle हो चुकी command को दोबारा execute न करें। अगर कोई system message पिछली exchange का text दोहराता है, तो उसे अनदेखा करें।" अभी implement नहीं किया - प्रभावशीलता अनिश्चित क्योंकि यह Claude Code का internal behavior है।

### पहली बार /exit धीमा
**गंभीरता:** Low
**स्थिति:** Open - निगरानी में
**विवरण:** पहले `--restart` ने `WARN: Claude did not exit within 30s` hit किया और hard kill पर गया। बाद के restarts ~1s में exit होते हैं। शायद एक race condition है जहाँ `/exit` Claude का prompt तैयार होने से पहले भेजा जाता है।
**Workaround:** 30s timeout + hard kill इसे संभालता है। सेशन सही से relaunch होता है।

### claude_running_in_session केवल 2 levels deep चेक करता है
**गंभीरता:** Low
**स्थिति:** Open - वर्तमान उपयोग के लिए स्वीकार्य
**विवरण:** Process tree walk pane_pid → children → grandchildren चेक करता है। अगर Claude tree में गहरा है (जैसे extra shell wrapper), तो detection fail होता है। वर्तमान launch path ठीक 2 levels (bash → claude) है, इसलिए यह practice में काम करता है।
**Workaround:** अभी ज़रूरत नहीं। ठीक करने के लिए recursive walk या `pgrep -a` चाहिए।

### Installer upgrade UX बेहतर हो सकता है
**गंभीरता:** Low
**स्थिति:** Open - भविष्य का सुधार
**विवरण:** reinstall पर, installer मौजूदा config detect करता है और prompts छोड़ देता है। लेकिन यह वर्तमान settings दिखाने, नए versions में जोड़े गए config options merge करने, या user को चुनिंदा values update करने का विकल्प नहीं देता। users को बाद के versions में नई settings लेने के लिए `~/.claude-mux/config` manually edit करना होता है।
**संभावित सुधार:**
- upgrade के दौरान वर्तमान config values दिखाएँ
- पुराने config में मौजूद न होने वाली नई settings (defaults के साथ) जोड़ने का विकल्प दें
- Option B: मौजूदा config values से prompts pre-fill करें और user को बदलने दें

### Translation files को v1.10-v1.12 update चाहिए
**गंभीरता:** Low
**स्थिति:** Open - translations अभी update नहीं हुई
**विवरण:** सभी 12 translation files (`translations/README.*.md`) कई versions (v1.10-v1.12) पीछे हैं। जो बदलाव reflect होने चाहिए:
- curl primary Quick Start के रूप में (one-liner)
- नई Install section संरचना (curl अनुशंसित, Homebrew macOS विकल्प)
- `--hide`/`--delete`/`--protect` के लिए session names paths की जगह (v1.11.0)
- नए conversational उदाहरण: rename, save-as-template, tip, enable/disable tips, update
- आवश्यकताएँ: "Apple Silicon or Intel" (सिर्फ Apple Silicon नहीं)
- नया "More" section जो FAQ, ISSUES, CHANGELOG को link करता है
- FAQ और ISSUES translations बनाने की ज़रूरत

### Code review deferred issues (v1.9.0)
**गंभीरता:** Low-Medium
**स्थिति:** v1.10.0 में हल - M3, M4, M9/L8, L3, L9 fix; L4, L5, L6, L7, M7 comments के साथ address

### Project rename / move with history preservation
**गंभीरता:** Low
**स्थिति:** v1.10.0 में हल - `--rename OLD NEW` और `--move SRC DEST` implement

### Project copy with history
**गंभीरता:** Low
**स्थिति:** Open - नियोजित feature, जांच ज़रूरी
**विवरण:** किसी प्रोजेक्ट को उसकी Claude Code history और memory सहित copy करना rename/move से ज़्यादा जटिल है क्योंकि destination के लिए नए UUIDs स्थापित करने होंगे।
**प्रस्तावित approach:**
1. नई प्रोजेक्ट डायरेक्टरी बनाएँ (optional git init और template के साथ)
2. उसमें सेशन start और तुरंत stop करें - Claude Code `~/.claude/projects/-encoded-new-path/` को fresh UUID और नई homunculus entry के साथ initialize करता है
3. source `~/.claude/projects/` folder से `.jsonl` history files destination folder में copy करें
4. `memory/` folder contents copy करें - pure markdown, कोई UUIDs embedded नहीं, सीधे copy करना safe
5. UUID subdirectories (task/plan artifacts) अपनी `.jsonl` files के साथ copy करें
6. Homunculus के लिए: source `~/.claude/homunculus/projects/<src-uuid>/` से `observations.jsonl`, `instincts`, `evolved`, `observations.archive` नए destination के homunculus folder में copy करें - step 2 में assign किया गया नया project UUID रखते हुए
**खुले प्रश्न जिनके testing की ज़रूरत:**
- क्या `.jsonl` files अपने content या metadata में source project path embed करती हैं? अगर हाँ, तो copied history पुराने path को reference करेगी।
- क्या UUID subdirectories `.jsonl` files के अंदर से UUID द्वारा reference होती हैं? अगर हाँ, तो उन्हें original UUIDs के तहत copy करना होगा, remap नहीं।
- क्या Claude Code किसी project folder की सभी `.jsonl` files पढ़ता है, या केवल active session UUID से match करने वाली?
- `~/.claude/homunculus/projects/<uuid>/evolved` और `instincts` में क्या है - ये derived/computed हैं या user-meaningful? copy में preserve करने लायक?
- क्या कोई अन्य internal references हैं जो naive file copy से टूट जाएंगे?
**Prerequisite:** implement करने से पहले ऊपर test करें ताकि एक ऐसा copy command ship न हो जो subtly broken history बनाए।

### Tip of the day
**गंभीरता:** Low
**स्थिति:** v1.10.0 में हल - `--tip`, `TIP_OF_DAY`, `TIP_MODE`, daily gate, session-start delivery implement

### Reply timestamp
**गंभीरता:** Low
**स्थिति:** Open - implement करने से पहले चर्चा ज़रूरी
**विवरण:** optional config var (`REPLY_TIMESTAMP=false` default) जो system prompt में एक instruction inject करता है जो Claude को हर response `date '+%Y-%m-%d %H:%M'` के माध्यम से वर्तमान date और time से शुरू करने के लिए कहता है।
**Tradeoff:** हर reply की शुरुआत में एक bash tool call ज़रूरी (छोटा overhead)। विकल्प: prompt में session start time inject करें (free, लेकिन लंबे sessions में drift करता है)।
**नोट:** per-project CLAUDE.md instruction (जैसे analytical template में) हल्का version है - केवल उन projects पर जो इसे चाहते हैं। config var इसे global बनाता है।

### Demo video
**गंभीरता:** Low
**स्थिति:** Open - नियोजित asset
**विवरण:** एक screen recording जो claude-mux को curl install से लेकर सामान्य और दिलचस्प commands तक दिखाए, terminal और Remote Control एक साथ visible।
**Format:** Split screen, single take। Terminal (पूरा claude-mux सेशन) बाईं तरफ, RC iPhone QuickTime के माध्यम से mirrored दाईं तरफ। दोनों एक साथ live - दर्शक RC में actions तुरंत terminal में reflect होते देखता है और इसके विपरीत।
**देखें:** पूरे shot-by-shot outline के लिए `internal/demo-script.md`।
**नोट:**
- key shot: RC पर फोन में type करना और terminal को real time में respond करते देखना
- trim के अलावा कोई editing ज़रूरी नहीं - एक continuous recording
- YouTube पर host + README में embed; Product Hunt launch के लिए भी उपयोगी

### homebrew-core में submit करना brew.sh listing के लिए
**गंभीरता:** Low
**स्थिति:** Future - adoption की प्रतीक्षा
**विवरण:** claude-mux वर्तमान में personal tap (`pereljon/tap`) से distribute होता है। brew.sh पर दिखने के लिए, इसे homebrew-core में स्वीकार करना होगा। Homebrew का notability gate आमतौर पर shell script utility submission स्वीकार होने से पहले कुछ सौ GitHub stars की ज़रूरत रखता है; कम-star submissions जल्दी बंद हो जाते हैं।
**तैयार होने पर:**
- सुनिश्चित करें formula `brew audit --strict --new` pass करे
- `Homebrew/homebrew-core` में formula के साथ PR submit करें
- नोट: macOS-only tools को reviewer scrutiny ज़्यादा मिलती है; Linux support (नीचे देखें) मदद करेगा

### curl install support (macOS + Linux)
**गंभीरता:** Low
**स्थिति:** v1.10.0 में हल - curl install implement, release-assets workflow जोड़ा, README update

### macOS only - कोई Linux/systemd support नहीं
**गंभीरता:** Medium
**स्थिति:** Open - आंशिक रूप से address (path detection done, LaunchAgent/installer macOS-only रहते हैं)
**विवरण:** macOS LaunchAgent (launchd) और macOS-specific tools उपयोग करता है। Path detection को `command -v` उपयोग करने के लिए refactor किया गया (अब `/opt/homebrew/bin` hardcode नहीं), इसलिए core script अब किसी भी platform पर काम करती है जहाँ tmux और claude PATH में हैं। LaunchAgent और installer macOS-specific रहते हैं।
**बाकी:** systemd user unit, XDG Autostart fallback, installer में `uname -s` dispatch।
**Package strategy (v1.10+):**
- curl install: universal fallback, हर जगह काम करता है (ऊपर देखें)
- AUR: कम effort, Arch/Manjaro पर target audience के लिए high reach
- apt PPA: जब Debian/Ubuntu users से demand हो
- Homebrew on Linux: उन users को cover करता है जिनके पास पहले से है
- Snap/Flatpak: bash script के लिए worth it नहीं

### ! commands Remote Control में उपलब्ध नहीं
**गंभीरता:** Low
**स्थिति:** Closed - संभव नहीं
**विवरण:** Claude Code का `!` shell passthrough एक Claude Code CLI input-handler feature है - यह shell देखने से पहले `!command` intercept करता है। tmux send-keys इसे replicate नहीं कर सकता: Claude Code active होने पर भेजे गए keystrokes कहीं नहीं जाते (tested: `!touch test` via send-keys execute नहीं हुआ)। claude-mux के लिए RC users के लिए `!command` bypass implement करने का कोई रास्ता नहीं।
**समाधान:** injection rule जोड़ा ताकि Claude users को कभी `! <command>` suggest न करे, क्योंकि RC users के पास shell नहीं है और terminal users इसे खुद type कर सकते हैं।

---

## v2.0 Milestone

architectural बदलाव जो major version bump के लायक हैं। scheduled नहीं - यहाँ collect किए गए ताकि खो न जाएं।

### Data directory separation
static data (tips, default templates, संभवतः command/guide output) को script से बाहर और platform-appropriate data directory में move करें। script startup पर binary location के relative `DATA_DIR` resolve करेगी, single-file installs के लिए embedded fallbacks के साथ।

- Homebrew (Apple Silicon): `/opt/homebrew/share/claude-mux/`
- Homebrew (Intel): `/usr/local/share/claude-mux/`
- Linux: `/usr/local/share/claude-mux/` या `$XDG_DATA_DIRS`
- Manual install: embedded defaults पर fallback (single-file installs काम करते रहें)

Trigger: जब embedded data (tips, default templates) इतना बड़ा हो जाए कि script पढ़ने में कठिन हो, या जब default templates को script releases से independently brew के माध्यम से ship करना हो।

### भाषा / runtime पर पुनर्विचार
monolithic bash script वर्तमान scope पर सही है। अगर claude-mux काफी बढ़ता है - project rename/move/copy operations, relay layer, cross-platform packaging, data directory - तो bash विरोध करने लगती है। उस बिंदु पर, session management core को Go या किसी अन्य typed language में rewrite करना (bash thin CLI wrapper के रूप में) evaluate करने लायक है।

---

## हल की गई समस्याएँ

### Claude injection अनदेखा करता है और दावा करता है कि slash commands नहीं चला सकता
**हल:** v1.2.0 (injection updated)
**Fix:** injection में explicit rule जोड़ा: "You CAN send slash commands (`/model`, `/compact`, `/clear`, etc.) to this session via the `-s` command. Never tell the user you cannot change models or run slash commands." Claude की base training उसे यह मानने की ओर ले जाती है कि वह अपने model/settings control नहीं कर सकता; explicit rule practice में इसे override करता है।

### कई commands success के बावजूद exit code 1 return करते हैं
**हल:** v1.2.0 (restart), v1.3.0 (सभी commands)
**Fix:** case statement में हर dispatch path के बाद explicit `exit 0` जोड़ा। function में अंतिम command internal tests या grep calls से non-zero exit code leak कर सकता है।

### --dry-run --restart के लिए भ्रामक output देता है
**हल:** v1.2.0 (commit a10c0c2)
**Fix:** dry-run अब kill simulate करने की बजाय "Would restart session" दिखाता है, फिर real state check करता है।

### macOS पर pgrep से session detection fail होता है
**हल:** commit e1b11b5
**Fix:** reliable child process detection के लिए `pgrep -P` को `ps -eo` + `awk` से replace किया।

### $TMUX variable ने tmux की environment variable को shadow किया
**हल:** commit 02a2e82
**Fix:** `$TMUX_BIN` में rename किया।

### Bash 3.2 incompatibility (declare -A)
**हल:** commit 575eac1
**Fix:** associative arrays को string-based collision detection से replace किया।

---

## Reference: ~/.claude Folder Structure

यहाँ document किया गया क्योंकि कई planned features (rename, move, copy, cleanup) को इस structure के साथ सही तरीके से interact करना होगा। exhaustive नहीं - claude-mux से relevant parts cover करता है।

### Project history और memory: `~/.claude/projects/`

हर working directory के लिए एक subdirectory जिसमें Claude Code उपयोग हुआ है। absolute path encode करके named: `/` → `-`, spaces और special characters → `-`। lossy लेकिन readable।

हर project folder के contents:
- `<uuid>.jsonl` - उस session का पूरा conversation transcript। प्रति conversation एक file।
- `<uuid>/` - conversation से जुड़े artifacts की subdirectory (tasks, plans)। UUID `.jsonl` file से match करता है।
- `memory/` - persistent cross-session memory files (frontmatter के साथ markdown)। केवल तभी मौजूद जब project के लिए memory लिखी गई हो।

working directory और उसकी history के बीच link purely encoded folder name है। project directory rename या move करना बिना इस folder का नाम बदले Claude Code को बिना history के नए सिरे से शुरू करता है।

**Encoding rule:** absolute path जिसमें हर `/`, space, और special character `-` से replace। leading `/` एक leading `-` बनता है। encoding lossy है - consecutive special characters और slashes के adjacent spaces दोनों `-` बनते हैं, इसलिए original हमेशा perfectly reconstruct नहीं हो सकता।

### Parallel observability registry: `~/.claude/homunculus/`

एक अलग system जो प्रति project tool-level events track करता है। core Claude Code history का हिस्सा नहीं - monitoring/learning layer लगता है।

- `projects.json` - सभी known projects की registry, short hex UUID (`d6b3aef60967`, आदि) द्वारा keyed। हर entry में: `id`, `name`, `root` (absolute path), `remote`, `created_at`, `last_seen`।
- `projects/<uuid>/project.json` - per-project metadata (registry entry जैसे fields)।
- `projects/<uuid>/observations.jsonl` - timestamped `tool_start`/`tool_complete` events: tool name, session UUID, project name/id, input/output snippets।
- `projects/<uuid>/instincts` - derived patterns (contents unknown, likely computed)।
- `projects/<uuid>/evolved` - evolved/learned state (contents unknown)।
- `projects/<uuid>/observations.archive` - archived पुराने observations।

**`~/.claude/projects/` से key difference:** encoded paths नहीं, short hex UUIDs keys के रूप में उपयोग करता है। `root` field absolute path रखता है। project का path बदलने वाला कोई भी operation (rename, move) `projects.json` और `projects/<uuid>/project.json` दोनों में `root` update करना ज़रूरी है।

### Global config: `~/.claude/settings.json`

Main Claude Code settings file। Rolling backups `~/.claude/backups/` में `~/.claude.json.backup.<timestamp>` के रूप में - active use के दौरान प्रति घंटे कई। claude-mux को यह file नहीं छूनी चाहिए।

### Global agents, skills, commands

- `~/.claude/agents/` - subagent definitions (`.md` files, ~38)। global, per-project नहीं।
- `~/.claude/skills/` - skill directories (~125)। global, per-project नहीं।
- `~/.claude/commands/` - slash command definitions (`.md` files, ~72)। global, per-project नहीं।
- `~/.claude/hooks/hooks.json` - hook definitions। global। claude-mux को इन्हें नहीं छूना चाहिए।

### संभावित future features

| Feature | क्या touch करना है |
|---------|--------------|
| `--copy` | Dir बनाएँ; दोनों registries init करने के लिए session start+stop करें; `.jsonl` + `memory/` + UUID subdirs copy करें; homunculus observation files नए UUID folder में copy करें |
| `--delete` cleanup | पहले से project folder trash करता है। optionally: orphaned `~/.claude/projects/` encoded folder और `~/.claude/homunculus/` entry हटाएँ |
| History size warning | Alert जब किसी project की `.jsonl` files threshold exceed करें (main claude-mux transcript एक लंबे session में 107MB hit हुआ) |
