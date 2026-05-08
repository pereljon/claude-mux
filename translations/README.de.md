# claude-mux - Claude Code Multiplexer

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · **Deutsch** · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Persistente Claude Code-Sitzungen für alle deine Projekte, von überall über die Claude-Mobile-App erreichbar. ***Von Claude verwaltet!***

## Warum

Remote Control verspricht Claude Code von überall, aber ohne Session-Management ist es eine zweitklassige Schnittstelle, selbst von Claude Desktop aus:

- Sitzungen sterben, wenn du das Terminal schließt, und der Gesprächskontext wird nicht automatisch wiederhergestellt
- Es gibt keine Heimatbasis: nichts läuft, wenn du dein Telefon nimmst, es sei denn, du hast etwas offen gelassen
- Wenn keine Sitzung läuft, ist Remote Control nutzlos: du kannst weder ein Projekt erreichen noch eines starten
- Selbst in einer laufenden RC-Sitzung funktionieren Slash-Befehle nicht: kein Modellwechsel, kein Komprimieren, keine Berechtigungsmodusänderungen
- Ein neues Projekt zu starten erfordert manuelles Erstellen eines Verzeichnisses, git-Initialisierung, Schreiben einer CLAUDE.md, Setzen eines Berechtigungsmodus und Auswahl eines Modells: nichts davon ist über RC möglich
- Mehrere Projekte zu verwalten bedeutet mehrere manuelle Terminal-Starts ohne Überblick darüber, was läuft oder in welchem Zustand es sich befindet

claude-mux behebt all das. Es kapselt Claude Code in tmux, sodass Sitzungen persistent sind, injiziert einen System-Prompt, damit Claude seine eigenen Sitzungen verwalten kann, und leitet Slash-Befehle über tmux weiter, damit sie über Remote Control funktionieren. Sobald eine Sitzung läuft, verwaltest du alles per Gespräch mit Claude: im Terminal oder in der Mobile-App.

## Schnellstart

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Dann eine Sitzung starten:

```bash
cd ~/pfad/zu/deinem/projekt
claude-mux
```

Oder:

```bash
claude-mux ~/pfad/zu/deinem/projekt
```

Das war's. Du befindest dich in einer persistenten, sitzungsbewussten Claude-Sitzung mit aktivierter Remote Control. Von hier aus ist alles konversationell.

## Mit Claude sprechen

So verwendest du claude-mux im Alltag. Jede Sitzung wird mit Befehlen injiziert, damit Claude Sitzungen verwalten, Modelle wechseln, Slash-Befehle senden und neue Projekte erstellen kann: alles aus dem Gespräch heraus. Du musst dir keine CLI-Flags merken.

```
Du: "status"
Claude: meldet Sitzungsname, Modell, Berechtigungsmodus, Kontextnutzung und listet alle Sitzungen auf

Du: "list active sessions"
Claude: zeigt alle laufenden Sitzungen mit ihrem Status

Du: "start a session for my api-server project"
Claude: startet eine Sitzung in ~/Claude/work/api-server

Du: "create a new project called mobile-app using the web template"
Claude: erstellt das Projektverzeichnis, initialisiert git, wendet die Vorlage an, startet eine Sitzung

Du: "switch this session to Haiku"
Claude: sendet /model haiku via tmux an sich selbst

Du: "compact the api-server session"
Claude: sendet /compact an die api-server-Sitzung

Du: "restart the web-dashboard session"
Claude: fährt die Sitzung herunter und startet sie neu, dabei bleibt der Konversationskontext erhalten

Du: "switch the api-server session to plan mode"
Claude: startet die Sitzung mit dem plan-Berechtigungsmodus neu

Du: "switch this session to yolo mode"
Claude: wechselt in den bypassPermissions-Modus via Shift+Tab, kein Neustart nötig

Du: "what mode is this session"
Claude: meldet den aktuellen Berechtigungsmodus (default, acceptEdits, plan, bypassPermissions)

Du: "switch this session to Opus"
Claude: sendet /model opus via tmux an sich selbst

Du: "clear this session"
Claude: sendet /clear an sich selbst und setzt die Konversation zurück

Du: "hide this project"
Claude: schreibt .claudemux-ignore, damit das Projekt aus -L-Auflistungen ausgeschlossen wird

Du: "protect this session"
Claude: schreibt .claudemux-protected und setzt den tmux-Marker, Herunterfahren erfordert jetzt --force

Du: "is this session protected"
Claude: prüft, ob .claudemux-protected im Projektordner vorhanden ist, und meldet das Ergebnis

Du: "delete the old-prototype project"
Claude: bestätigt im Chat, verschiebt dann den Projektordner in den Systempapierkörb

Du: "rename this project to my-new-name"
Claude: stoppt die Sitzung, benennt den Ordner um, migriert den Konversationsverlauf, startet neu

Du: "save this as a template named web"
Claude: kopiert CLAUDE.md nach ~/.claude-mux/templates/web.md

Du: "tip"
Claude: gibt einen Tipp aus, den ganzen Tag derselbe, oder zufällig wenn TIP_MODE=random gesetzt ist

Du: "enable tips" / "disable tips"
Claude: registriert oder entfernt den Tipp-des-Tages-Hook für alle Projekte

Du: "update claude-mux"
Claude: warnt, dass alle Sitzungen neu starten, bittet um Bestätigung, aktualisiert dann und startet neu

Du: "stop all sessions"
Claude: beendet alle verwalteten Sitzungen ordnungsgemäß

Du: "help"
Claude: gibt die vollständige Liste der konversationellen Befehle aus
```

Diese Befehle funktionieren in jeder Sprache. Wenn du das Äquivalent auf Spanisch, Japanisch, Hebräisch oder einer anderen Sprache eingibst, erkennt Claude die Absicht und führt den passenden Befehl aus.

Tippe `help` in einer beliebigen Sitzung, um die vollständige Befehlsliste zu sehen.

### Home-Sitzung

Die Home-Sitzung ist eine Allzweck-Sitzung, die in deinem Basisverzeichnis lebt (`~/Claude` standardmäßig). Sie startet beim Login automatisch, wenn `LAUNCHAGENT_MODE=home` gesetzt ist, und gibt dir eine immer bereite Claude-Sitzung, die vom Telefon aus erreichbar ist. Verwende sie, um alle anderen Sitzungen zu verwalten, ohne zuerst projektspezifische starten zu müssen.

Die Home-Sitzung ist standardmäßig **geschützt**: `--shutdown home` weigert sich, sie ohne `--force` zu beenden. Der Schutz wird durch die Markierungsdatei `.claudemux-protected` in `$BASE_DIR` aktiviert, die von `claude-mux --install` erstellt wird. Geschützte Sitzungen zeigen `protected` in der Statusspalte; die aufrufende Sitzung wird mit `>` in der Namensspalte markiert.

## Was es tut

Im Hintergrund übernimmt claude-mux:

- **Persistente tmux-Sitzungen** mit aktivierter Remote Control, damit jede Sitzung über die Claude-Mobile-App erreichbar ist
- **Konversation wiederaufnehmen**: nimmt die letzte Konversation (`claude -c`) beim Neustart wieder auf und erhält den Kontext
- **System-Prompt-Injection**: jede Sitzung erhält Befehle zur Selbstverwaltung, Slash-Befehl-Weiterleitung und SSH-Konten-Erkennung
- **CLAUDE.md-Vorlagen**: pflege Vorlagendateien (z. B. `web.md`, `python.md`) in `~/.claude-mux/templates/` und wende sie auf neue Projekte an
- **Multi-CLI-Coder-Unterstützung**: erstellt `AGENTS.md` und `GEMINI.md` als Symlinks zu `CLAUDE.md`, damit Codex CLI, Gemini CLI und andere Werkzeuge dieselben Anweisungen teilen
- **Automatisch genehmigte Berechtigungen**: fügt claude-mux zur Allow-Liste jedes Projekts hinzu, damit Claude Sitzungsbefehle ohne Rückfrage ausführen kann
- **Migration verwaister Prozesse**: läuft Claude bereits außerhalb von tmux, migriert es ihn in eine verwaltete Sitzung
- **Tmux-Komfortfunktionen**: Mausunterstützung, 50k-Scrollback, Zwischenablage, 256 Farben, erweiterte Tasten, Aktivitätsüberwachung, Tab-Titel

> **Hinweis:** Dies unterscheidet sich von `claude --worktree --tmux`, das eine tmux-Sitzung für ein isoliertes git worktree erstellt. claude-mux verwaltet persistente Sitzungen für deine tatsächlichen Projektverzeichnisse, mit Remote Control und System-Prompt-Injection.

## Anforderungen

- macOS (Apple Silicon oder Intel)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## Installation

### curl (empfohlen)

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Lädt die Binärdatei herunter, installiert sie nach `~/bin`, fügt sie zum `PATH` hinzu und startet das interaktive Setup. Funktioniert auf macOS und Linux (Linux: LaunchAgent-Schritt wird übersprungen).

Zum Aktualisieren:

```bash
claude-mux --update     # funktioniert aus jeder Sitzung heraus oder vom Terminal
```

### Homebrew (macOS-Alternative)

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Zum Aktualisieren:

```bash
brew upgrade claude-mux
```

### Manuell

```bash
./install.sh
```

`install.sh` kopiert die Binärdatei nach `~/bin` und fügt sie zum `PATH` hinzu. Danach ausführen:

```bash
claude-mux --install
```

Der interaktive Setup fragt, wo deine Claude-Projekte liegen, ob beim Login eine Home-Sitzung gestartet werden soll und welches Modell verwendet werden soll. Er erstellt `~/.claude-mux/config` und installiert den LaunchAgent.

Verwende `--non-interactive`, um Abfragen zu überspringen und Standardwerte zu übernehmen.

Optionen:

```bash
claude-mux --install --non-interactive                     # Abfragen überspringen, Standardwerte verwenden
claude-mux --install --base-dir ~/work/claude              # ein anderes Basisverzeichnis verwenden
claude-mux --install --launchagent-mode none               # LaunchAgent-Verhalten deaktivieren
claude-mux --install --home-model haiku                    # Haiku für die Home-Sitzung verwenden
claude-mux --install --no-launchagent                      # LaunchAgent-Installation komplett überspringen
```

Der LaunchAgent führt `claude-mux --autolaunch` beim Login mit einer Startverzögerung von 45 Sekunden aus, damit Systemdienste sich initialisieren können.

## Sitzungsstatus

| Status | Bedeutung |
|--------|-----------|
| `running` | tmux-Sitzung existiert und Claude läuft |
| `protected` | wie `running`, aber die Sitzung ist geschützt: `--shutdown` benötigt `--force` zum Beenden |
| `stopped` | tmux-Sitzung existiert, aber Claude wurde beendet |
| `idle` | Ein `.claude/`-Projekt existiert unter `BASE_DIR`, aber es läuft keine claude-mux-tmux-Sitzung dafür (nur mit `-L` angezeigt) |

Ein `>`-Präfix beim Sitzungsnamen (z. B. `> home`) markiert die Sitzung, die den List-Befehl ausgeführt hat.

Wenn `claude-mux` in einem Verzeichnis ausgeführt wird, das bereits eine laufende Sitzung hat, wird diese angehängt. Mehrere Terminals können sich an dieselbe Sitzung anhängen (Standardverhalten von tmux).

## Projektmarkierungen

Der projektbezogene Status wird in Markierungsdateien im Projektstammverzeichnis gespeichert, nicht in einer zentralen Konfiguration. Markierungen verwenden das Präfix `.claudemux-` und werden automatisch zur `.gitignore` hinzugefügt, wenn sie in einem git-verwalteten Projekt erstellt werden.

| Markierung | Bedeutung | CLI |
|------------|-----------|-----|
| `.claudemux-protected` | Sitzung wird beim Start geschützt: `--shutdown` erfordert `--force` | `--protect` / `--unprotect` |
| `.claudemux-ignore` | Projekt wird aus `claude-mux -L`-Auflistungen ausgeblendet | `--hide` / `--show` |

```bash
claude-mux --hide                    # aktuelles Projekt aus -L-Auflistungen ausblenden
claude-mux --hide my-project         # ein bestimmtes Projekt nach Sitzungsname ausblenden
claude-mux --show my-project         # Projekt wieder einblenden
claude-mux --protect                 # diese Sitzung vor versehentlichem Herunterfahren schützen
claude-mux --unprotect               # Schutz entfernen
claude-mux -L --hidden               # nur ausgeblendete Projekte auflisten
claude-mux --delete my-project       # Projektordner in den Systempapierkörb verschieben (macOS)
```

Markierungen folgen dem Projektordner bei Umbenennung und Verschiebung. Ein einziges `.gitignore`-Muster (`.claudemux-*`) deckt alle aktuellen und zukünftigen Markierungen ab.

## Konfiguration

`~/.claude-mux/config` wird von `claude-mux --install` erstellt (oder beim ersten Ausführen eines beliebigen Befehls, falls keine Konfiguration vorhanden ist). Bearbeite die Datei, um Standardwerte zu überschreiben: das Skript selbst muss nie geändert werden.

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `BASE_DIR` | `$HOME/Claude` | Wurzelverzeichnis, in dem nach Claude-Projekten gesucht wird (Verzeichnisse mit `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Verzeichnis für die Datei `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Setzt Claudes `permissions.defaultMode` in jedem Projekt. Gültig: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Auf `""` setzen, um zu deaktivieren. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Wenn `true`, können Claude-Sitzungen Slash-Befehle an andere Sitzungen senden, nützlich für Multi-Agent-Orchestrierung |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Verzeichnis mit CLAUDE.md-Vorlagedateien |
| `DEFAULT_TEMPLATE` | `default.md` | Standardvorlage für neue Projekte (`-n`). Auf `""` setzen, um zu deaktivieren. |
| `SLEEP_BETWEEN` | `5` | Sekunden zwischen Sitzungsstarts, wenn `-a` verwendet wird. Erhöhen, falls die RC-Registrierung fehlschlägt. |
| `HOME_SESSION_MODEL` | `""` | Modell für die Home-Sitzung. Gültig: `sonnet`, `haiku`, `opus`. Leer übernimmt Claudes Standard. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Leerzeichen-getrennte Liste von Dateien, die als Symlinks zu `CLAUDE.md` für andere AI-CLI-Werkzeuge erstellt werden. Auf `""` setzen, um zu deaktivieren. |
| `LAUNCHAGENT_MODE` | `home` | LaunchAgent-Verhalten beim Login: `none` (nichts tun) oder `home` (geschützte Home-Sitzung starten). Veraltetes `LAUNCHAGENT_ENABLED=true` wird als `home` behandelt. |

**Tmux-Sitzungsoptionen** (alle konfigurierbar, alle standardmäßig aktiviert):

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `TMUX_MOUSE` | `true` | Mausunterstützung: Scrollen, Auswählen, Größenänderung von Panes |
| `TMUX_HISTORY_LIMIT` | `50000` | Größe des Scrollback-Puffers in Zeilen (tmux-Standard ist 2000) |
| `TMUX_CLIPBOARD` | `true` | Integration der Systemzwischenablage über OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Terminaltyp für korrekte Farbdarstellung |
| `TMUX_EXTENDED_KEYS` | `true` | Erweiterte Tastensequenzen einschließlich Shift+Enter (benötigt tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | Verzögerung der Escape-Taste in Millisekunden (tmux-Standard ist 500) |
| `TMUX_TITLE_FORMAT` | `#S` | Format für Terminal-/Tab-Titel (`#S` = Sitzungsname, `""` zum Deaktivieren) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Benachrichtigt bei Aktivität in anderen Sitzungen |

## Verzeichnisstruktur

Projekte werden anhand des Vorhandenseins eines `.claude/`-Verzeichnisses erkannt, in beliebiger Tiefe:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ hat .claude/ - verwaltet
│   │   └── .claude/
│   ├── project-b/          # ✓ hat .claude/ - verwaltet
│   │   └── .claude/
│   └── -archived/          # ✗ ausgeschlossen (beginnt mit -)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ hat .claude/ - verwaltet
│   │   └── .claude/
│   ├── .hidden/            # ✗ ausgeschlossen (verstecktes Verzeichnis)
│   │   └── .claude/
│   └── project-d/          # ✗ kein .claude/ - kein Claude-Projekt
├── deep/nested/project-e/  # ✓ hat .claude/ - in beliebiger Tiefe gefunden
│   └── .claude/
└── ignored-project/        # ✗ ausgeschlossen (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

Sitzungsnamen werden aus Verzeichnisnamen abgeleitet: Leerzeichen werden zu Bindestrichen, nicht-alphanumerische Zeichen (außer Bindestrichen) werden ersetzt, und führende sowie nachgestellte Bindestriche entfernt. Verzeichnisse, deren Name nach der Bereinigung leer ist, werden mit einer Log-Warnung übersprungen.

## Session System Prompt

Each Claude session is launched with `--append-system-prompt` containing context about its environment:

```
You are running inside tmux session '<session-name>'. claude-mux path: /path/to/claude-mux
claude-mux version: <version>
[Update available: <new-version> (found <date>). Tell the user and suggest they say "update claude-mux" to update.]

Reference lookups (run on demand if you need information not covered by trigger rules):
  claude-mux --guide          → conversational commands list (used for "help")
  claude-mux --commands       → full CLI reference
  claude-mux --config-help    → config options with defaults, types, descriptions
  claude-mux --list-templates → available CLAUDE.md templates

Rules:
- Always run claude-mux using the absolute path shown above (claude-mux path:). The bare command may not be in PATH.
- You CAN send slash commands (/model, /compact, /clear, etc.) to this session via the -s command.
- Always use --no-attach with -d and -n — attach is interactive only
- --shutdown and --restart never attach — safe to run from inside a session; do NOT add --no-attach to these commands
- Always print command output verbatim in your response text — if a command fails, report the error
- When command output contains <assistant-must-display> tags, include the COMPLETE content verbatim
- The 'home' session is the always-available session in the base directory. It is protected (shows 'protected' in status): --shutdown requires --force, but --restart bypasses protection. Protection is driven by the .claudemux-protected marker.
- Disambiguate 'home': 'home session' means the claude-mux session named home; 'home folder' means ~/
- When asked to shut down sessions, run the command directly — protected sessions are skipped automatically
- Use claude-mux for ALL session management. Never use raw tmux, ls, or other shell commands for session management.
- Don't guess at claude-mux flags. If you need information not in the trigger rules, run the relevant lookup.
- When user says: ready — respond with "Session ready!" on one line. Nothing else.
- When user says: help — run claude-mux --guide and print the output verbatim
- When user says: status — report session name, model, permission mode, context estimate, then run claude-mux -l
- When user says: list active sessions — run claude-mux -l
- When user says: list all sessions — run claude-mux -L
- When user says: list hidden projects — run claude-mux -L --hidden
- When user says: start session SESSION — run claude-mux -d SESSION --no-attach
- When user says: stop this session / stop session NAME — run claude-mux --shutdown
- When user says: stop all sessions — run claude-mux --shutdown
- When user says: restart this session / restart session NAME — run claude-mux --restart
- When user says: restart all sessions — run claude-mux --restart
- When user says: start new session in FOLDER — run claude-mux -n FOLDER --no-attach
- When user says: switch this session to MODE mode / switch session NAME to MODE mode
- When user says: switch this session to MODEL model / switch session NAME to MODEL model
- When user says: compact/clear this session / compact/clear session NAME
- When user says: update claude-mux — warn sessions will restart, get confirmation, run --update then --restart
- When user says: hide this project / hide PROJECT — run claude-mux --hide
- When user says: show this project / show PROJECT / unhide PROJECT — run claude-mux --show
- When user says: protect this session / protect SESSION — run claude-mux --protect
- When user says: unprotect this session / unprotect SESSION — run claude-mux --unprotect
- When user says: is this hidden / is this protected — check for .claudemux-ignore or .claudemux-protected
- When user says: delete this project / delete PROJECT — confirm in chat first, then run claude-mux --delete SESSION --yes
- When user says: list templates — run claude-mux --list-templates
- When user says: enable tips / turn on tips — run claude-mux --enable-tips
- When user says: disable tips / turn off tips — run claude-mux --disable-tips
- These trigger phrases work in any language.

Additional capabilities (run claude-mux --commands for full syntax):
  - Attach interactively to a session (-t — user-only, never from inside a session)
  - Start all sessions at once (-a)
  - New project with a CLAUDE.md template (-n DIR --template NAME, -p for parent dirs)
  - Force-shutdown a protected session (--shutdown SESSION --force)
  - Hide/show projects (--hide / --show)
  - Protect/unprotect sessions (--protect / --unprotect)
  - Move a project to trash (--delete SESSION — macOS; honors protection unless --force)
  - Enable/disable tip-of-the-day hook (--enable-tips / --disable-tips)
  - Show all config options (--config-help)
  - Run interactive setup or reconfigure (--install)
  - Remove all hooks and permissions (--uninstall)
  - Update claude-mux (--update)

Self-targeting send: claude-mux -s '<session-name>' '/command' sends slash commands to yourself.
GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

Die Home-Sitzung erhält zusätzlichen Kontext: eine Beschreibung ihrer Rolle sowie Trigger zur Selbstverwaltung zum Lesen/Bearbeiten von Konfiguration und Vorlagen. Wenn `ALLOW_CROSS_SESSION_CONTROL=true` gesetzt ist, kann der Sendebefehl jede Sitzung als Ziel haben, nicht nur die eigene. Der Pfad ist der absolute Pfad zum Skript zum Startzeitpunkt, sodass Sitzungen nicht von `PATH` abhängen.

## CLI-Referenz

Du brauchst diese Befehle selten direkt: Claude führt sie innerhalb von Sitzungen für dich aus. Sie sind für Scripting, Automatisierung oder wenn du dich nicht in einer Sitzung befindest.

```bash
# Starten und anhängen
claude-mux                       # Claude im aktuellen Verzeichnis starten und anhängen
claude-mux ~/projekte/my-app     # Claude in einem Verzeichnis starten und anhängen
claude-mux -d ~/projekte/my-app  # gleich wie oben (explizite Form)
claude-mux -t my-app             # an eine bestehende tmux-Sitzung anhängen

# Neue Projekte erstellen
claude-mux -n ~/projekte/app     # ein neues Claude-Projekt erstellen und anhängen
claude-mux -n ~/neuer/pfad/app -p  # gleich, mit Anlegen des Verzeichnisses und der übergeordneten Verzeichnisse
claude-mux -n ~/app --template web        # neues Projekt mit einer bestimmten CLAUDE.md-Vorlage
claude-mux -n ~/app --no-multi-coder      # neues Projekt ohne AGENTS.md/GEMINI.md-Symlinks

# Sitzungsverwaltung
claude-mux -l                    # Sitzungen nach Status auflisten (active, running, stopped)
claude-mux -L                    # alle Projekte auflisten (active + idle)
claude-mux -L --hidden           # nur ausgeblendete Projekte auflisten
claude-mux -s my-app '/model sonnet'      # einen Slash-Befehl an eine Sitzung senden
claude-mux --shutdown my-app              # eine bestimmte Sitzung herunterfahren
claude-mux --shutdown                     # alle verwalteten Sitzungen herunterfahren
claude-mux --shutdown home --force        # geschützte Home-Sitzung herunterfahren
claude-mux --restart my-app              # eine bestimmte Sitzung neu starten
claude-mux --restart                     # alle laufenden Sitzungen neu starten
claude-mux --permission-mode plan my-app  # Sitzung mit plan-Modus neu starten
claude-mux -a                    # alle verwalteten Sitzungen unter BASE_DIR starten

# Projektmarkierungen (alle Befehle verwenden Sitzungsnamen, keine Pfade)
claude-mux --hide                # aktuelles Projekt aus -L-Auflistungen ausblenden
claude-mux --hide my-project     # ein bestimmtes Projekt nach Sitzungsname ausblenden
claude-mux --show my-project     # Projekt wieder einblenden
claude-mux --protect             # diese Sitzung vor versehentlichem Herunterfahren schützen
claude-mux --unprotect           # Schutz entfernen
claude-mux --delete my-project           # Projektordner in den Systempapierkörb verschieben (macOS)
claude-mux --delete my-project --yes     # gleich, ohne Bestätigungsdialog
claude-mux --rename my-project new-name  # Projektverzeichnis umbenennen
claude-mux --move my-project ~/Claude/work  # Projekt in ein neues übergeordnetes Verzeichnis verschieben

# Sonstiges
claude-mux --list-templates      # verfügbare CLAUDE.md-Vorlagen anzeigen
claude-mux --guide               # konversationelle Befehle für die Verwendung in Sitzungen anzeigen
claude-mux --commands            # vollständige CLI-Referenz anzeigen
claude-mux --config-help         # alle Konfigurationsoptionen mit Standardwerten und Beschreibungen anzeigen
claude-mux --install             # interaktiver Setup: Konfiguration + LaunchAgent
claude-mux --update              # auf die neueste Version aktualisieren
claude-mux --dry-run             # Aktionen anzeigen, ohne sie auszuführen
claude-mux --version             # Version ausgeben
claude-mux --help                # alle Optionen anzeigen

# Log beobachten
tail -f ~/Library/Logs/claude-mux.log
```

Bei Ausführung im Terminal wird die Ausgabe in Echtzeit auf stdout gespiegelt. Bei Ausführung über LaunchAgent geht die Ausgabe nur in die Logdatei.

## Fehlerbehebung

### Sitzungen zeigen "Not logged in · Run /login"

Das passiert beim ersten Start, wenn der macOS-Schlüsselbund gesperrt ist (häufig, wenn das Skript läuft, bevor der Schlüsselbund nach dem Login entsperrt wird). Lösung:

```bash
# Schlüsselbund in einem regulären Terminal entsperren
security unlock-keychain

# Dann die Authentifizierung in einer beliebigen laufenden Sitzung abschließen
claude-mux -t <any-session>
# /login ausführen und den Browser-Flow abschließen
```

Nachdem die Authentifizierung einmal abgeschlossen wurde, alle Sitzungen beenden und neu starten: sie übernehmen die gespeicherten Anmeldedaten automatisch.

### Sitzungen erscheinen nicht in Claude Code Remote

Sitzungen müssen authentifiziert sein (also nicht "Not logged in" anzeigen). Nach einem sauberen, authentifizierten Start sollten sie innerhalb weniger Sekunden in der RC-Liste erscheinen.

### Mehrzeilige Eingabe in tmux

Der Befehl `/terminal-setup` kann nicht innerhalb von tmux ausgeführt werden. claude-mux aktiviert standardmäßig tmux `extended-keys` (`TMUX_EXTENDED_KEYS=true`), was Shift+Enter in den meisten modernen Terminals unterstützt. Falls Shift+Enter nicht funktioniert, verwende `\` + Return, um Zeilenumbrüche im Prompt einzufügen.

### "Session ready!" beim Sitzungsstart

Wenn eine Sitzung startet oder neu startet, sendet claude-mux nach dem Laden von Claude automatisch eine `Ready?`-Nachricht. Die Injection weist Claude an, mit "Session ready!" und nichts weiter zu antworten. Das bestätigt, dass die Sitzung aktiv und die Injection funktionsfähig ist.

### Slash-Befehle über Remote Control

Slash-Befehle (z. B. `/model`, `/clear`) werden in RC-Sitzungen [nicht nativ unterstützt](https://github.com/anthropics/claude-code/issues/30674). claude-mux umgeht das: jede Sitzung wird mit `claude-mux -s` versehen, damit Claude Slash-Befehle über tmux an sich selbst senden kann.

## Logs

- `~/Library/Logs/claude-mux.log` -- alle Skriptaktionen mit UTC-Zeitstempeln (über `LOG_DIR` konfigurierbar)

Für tiefergehendes LaunchAgent-Debugging Console.app oder `log show` verwenden.

## Mehr

- [FAQ](FAQ.de.md) -- häufige Fragen zu claude-mux
- [Bekannte Probleme](ISSUES.de.md) -- offene Bugs, geplante Features und behobene Probleme
- [Changelog](../CHANGELOG.md) -- was sich pro Release geändert hat
