# FAQ

[English](../FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · **Deutsch** · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## Was ist claude-mux?

Ein Shell-Skript, das Claude Code in tmux für persistente Sitzungen kapselt. Sitzungen überleben das Schließen des Terminals, nehmen den Konversationskontext beim Neustart wieder auf und sind über die Claude-Mobile-App via Remote Control erreichbar. Du verwaltest alles, indem du innerhalb einer Sitzung mit Claude sprichst.

## Funktioniert es auf Linux?

Noch nicht. Nur macOS (Apple Silicon und Intel). Linux-Unterstützung ist für v2.0 geplant. Der Installer läuft auf Linux, überspringt aber das LaunchAgent-Setup und gibt einen Hinweis aus. Die Binärdatei selbst funktioniert, es gibt aber noch keinen systemd-Dienst oder vergleichbaren Autostart-Mechanismus.

## Was ist die Home-Sitzung?

Die Home-Sitzung ist eine Allzweck-Claude-Sitzung, die in deinem Basisverzeichnis lebt (`~/Claude` standardmäßig). Wenn `LAUNCHAGENT_MODE=home` (der Standard), startet sie beim Login automatisch und läuft den ganzen Tag. Sie ist standardmäßig **geschützt**: `--shutdown home` weigert sich, sie ohne `--force` zu beenden.

Verwende die Home-Sitzung als deinen immer verfügbaren Einstiegspunkt von der Claude-Mobile-App. Von dort aus kannst du Projekte auflisten, andere Sitzungen starten, die Konfiguration verwalten und allgemeine Arbeit erledigen, die nicht zu einem bestimmten Projekt gehört.

## Was ist Remote Control?

Remote Control (RC) ist ein Feature von Claude Code, mit dem du dich von der Claude-Mobile-App oder Claude Desktop aus mit einer laufenden Claude-Sitzung verbinden kannst. claude-mux startet jede Sitzung mit aktiviertem `--remote-control`, sodass alle Sitzungen automatisch in der RC-Liste erscheinen. Einmal verbunden, sprichst du mit Claude genauso wie im Terminal. claude-mux umgeht auch RC-Einschränkungen wie nicht funktionierende Slash-Befehle, indem sie über tmux geroutet werden.

## Was sind Berechtigungsmodi?

Claude Code hat vier Berechtigungsmodi, die steuern, wie viel Autonomie Claude hat:

| Modus | Verhalten |
|-------|-----------|
| `default` | Claude fragt vor dem Ausführen von Befehlen oder Bearbeiten von Dateien |
| `acceptEdits` | Claude wendet Dateiänderungen automatisch an, fragt aber vor Shell-Befehlen |
| `plan` | Claude kann nur lesen und planen, keine Schreibvorgänge oder Befehle |
| `bypassPermissions` | Claude führt alles ohne Rückfrage aus (erfordert Bestätigung beim ersten Start) |

Setze den Standard für alle Projekte über `DEFAULT_PERMISSION_MODE` in der Konfiguration. Wechsle in einer laufenden Sitzung durch die Eingabe von z. B. "switch this session to plan mode" (oder einem anderen Modusnamen). "yolo" ist ein Alias für `bypassPermissions`.

Der Wechsel zu `bypassPermissions` aus einem anderen Modus verwendet Shift+Tab-Navigation und erfordert keinen Neustart. Der Wechsel von `bypassPermissions` zu einem anderen Modus erfordert einen Neustart, den claude-mux automatisch durchführt.

## Wie setze ich eine Sitzung zurück?

Drei Optionen, je nachdem was du brauchst:

- **Leeren** ("clear this session"): sendet `/clear` an die Sitzung. Löscht den Konversationsverlauf und startet frisch. Die Sitzung läuft weiter.
- **Komprimieren** ("compact this session"): sendet `/compact` an die Sitzung. Fasst die Konversation in einen kürzeren Kontext zusammen und gibt das Kontextfenster frei. Der Verlauf bleibt in komprimierter Form erhalten.
- **Neustarten** ("restart this session"): fährt Claude herunter und startet ihn mit `claude -c` neu, was die letzte Konversation wieder aufnimmt. Verwende dies, wenn du einen sauberen Prozess brauchst (z. B. nach dem Wechsel des Berechtigungsmodus oder wenn Claude hängt).

## Was sind Vorlagen?

Vorlagen sind wiederverwendbare CLAUDE.md-Dateien, die in `~/.claude-mux/templates/` gespeichert werden. Wenn du ein neues Projekt mit `-n` erstellst, wird die Standardvorlage (oder eine, die du mit `--template NAME` angibst) als CLAUDE.md ins Projekt kopiert.

Vorlage erstellen: "save this as a template named web" (kopiert die CLAUDE.md des aktuellen Projekts nach `~/.claude-mux/templates/web.md`).

Vorlage verwenden: `claude-mux -n ~/projekte/my-app --template web` oder aus einer Sitzung heraus: "create a new project called my-app using the web template".

Vorlagen auflisten: "list templates" oder `claude-mux --list-templates`.

## Wie funktioniert der Tipp des Tages?

Ein Claude Code Stop-Hook in der `.claude/settings.local.json` jedes Projekts ruft `claude-mux --tipotd` nach jedem Gesprächszug auf. Der Befehl prüft, ob heute bereits ein Tipp angezeigt wurde (über `~/.claude-mux/.tip-date`). Falls ja, beendet er sich in etwa 6ms. Falls nein, gibt er einen Tipp aus und speichert das heutige Datum.

Tipps sind standardmäßig aktiviert (`TIP_OF_DAY=true`). Umschalten mit "enable tips" oder "disable tips" in einer beliebigen Sitzung. `TIP_MODE=daily` zeigt den ganzen Tag denselben Tipp; `TIP_MODE=random` wählt einen zufälligen Tipp pro Aufruf (mit dem Stop-Hook bedeutet das einen zufälligen Tipp pro Tag aufgrund der täglichen Sperre).

Der `--tip`-Befehl funktioniert immer unabhängig von der täglichen Sperre, sodass du jederzeit "tip" sagen kannst.

## Kann ich das mit mehreren GitHub-Accounts verwenden?

Ja. claude-mux erkennt `Host github.com-*`-Einträge in `~/.ssh/config` und injiziert sie in den System-Prompt jeder Sitzung. Claude weiß, welche SSH-Aliase verfügbar sind, und kann den richtigen beim Einrichten von Git-Remotes verwenden.

Beispiel für `~/.ssh/config`:

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

Claude verwendet dann `git@github.com-work:org/repo.git` für Arbeits-Repos und `git@github.com-personal:user/repo.git` für persönliche.

## Wo wird der Status gespeichert?

| Ort | Was dort liegt |
|-----|----------------|
| `~/.claude-mux/config` | Benutzerkonfiguration (wird als Bash eingelesen) |
| `~/.claude-mux/templates/` | CLAUDE.md-Vorlagedateien |
| `~/.claude-mux/.tip-date` | Datum des zuletzt angezeigten Tipps |
| `~/.claude-mux/.update-check` | Gecachtes Ergebnis der Versionsprüfung |
| `~/Library/Logs/claude-mux.log` | Logdatei (über `LOG_DIR` konfigurierbar) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | LaunchAgent-Plist (erzeugt von `--install`) |
| `.claudemux-protected` (pro Projekt) | Markiert eine Sitzung als geschützt vor dem Herunterfahren |
| `.claudemux-ignore` (pro Projekt) | Blendet ein Projekt aus Auflistungen aus |

Markierungsdateien (`.claudemux-*`) liegen im Stammverzeichnis jedes Projekts und folgen dem Ordner bei Umbenennung, Verschiebung und Synchronisierung. Sie werden automatisch zur `.gitignore` hinzugefügt.

Der Konversationsverlauf wird von Claude Code selbst verwaltet und unter `~/.claude/projects/` gespeichert.

## Was passiert mit dem Auto-Update, wenn ich claude-mux forke?

Die Update-Prüfung und der `--update`-Befehl verwenden fest `pereljon/claude-mux` als GitHub-Repo. Bei einem Fork vergleicht die Update-Prüfung weiterhin mit dem Upstream-Release, und `--update` überschreibt die Binärdatei deines Forks mit Upstream. Setze `UPDATE_CHECK=false` in `~/.claude-mux/config`, um das zu deaktivieren, oder ändere die Repo-URL in den Funktionen `check_for_update()` und `do_update()` im Skript.

## Wie installiere ich über Homebrew?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Aktualisiere mit `brew upgrade claude-mux`. Hinweis: Falls du über Homebrew installiert hast, delegiert `--update` automatisch an `brew upgrade`.

## Wie unterscheidet sich das von `claude --worktree --tmux`?

`claude --worktree --tmux` erstellt eine tmux-Sitzung für ein isoliertes git worktree, gedacht für parallele Codierungsaufgaben. claude-mux verwaltet persistente Sitzungen für deine tatsächlichen Projektverzeichnisse, mit aktivierter Remote Control, System-Prompt-Injection zur Selbstverwaltung, Wiederaufnahme von Konversationen und Sitzungslebenszyklusverwaltung. Sie lösen unterschiedliche Probleme.

## Warum zeigen Sitzungen "Not logged in"?

Das passiert beim ersten Start, wenn der macOS-Schlüsselbund gesperrt ist, was häufig vorkommt, wenn der LaunchAgent startet, bevor du den Schlüsselbund nach dem Login entsperrst. Behebe es, indem du `security unlock-keychain` in einem regulären Terminal ausführst, dann an eine beliebige Sitzung anhängst (`claude-mux -t <name>`) und `/login` ausführst, um den Browser-Auth-Flow abzuschließen. Danach alle Sitzungen neu starten, sie übernehmen die gespeicherten Anmeldedaten.

## Können mehrere Terminals sich an dieselbe Sitzung anhängen?

Ja. Das ist Standardverhalten von tmux. Wenn `claude-mux` in einem Verzeichnis ausgeführt wird, das bereits eine laufende Sitzung hat, wird diese angehängt. Mehrere Terminals sehen den gleichen Sitzungsinhalt in Echtzeit.

## Wie stoppe ich die Home-Sitzung dauerhaft?

Der LaunchAgent hat `KeepAlive: true`, sodass das Beenden der Home-Sitzung innerhalb von etwa 60 Sekunden einen Neustart auslöst. Um sie dauerhaft zu stoppen, deaktiviere den LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## Was bedeutet die "Session ready!"-Meldung?

Wenn eine Sitzung startet oder neu startet, sendet claude-mux nach dem Laden von Claude einen `Ready?`-Prompt. Die Injection weist Claude an, mit "Session ready!" und nichts weiter zu antworten. Das bestätigt, dass die Sitzung aktiv ist und die System-Prompt-Injection funktioniert. Du kannst die Meldung ignorieren.

## Wie blende ich ein Projekt aus Auflistungen aus?

Sage "hide this project" in einer beliebigen Sitzung oder führe `claude-mux --hide my-project` aus. Dadurch wird eine `.claudemux-ignore`-Markierungsdatei erstellt. Das Projekt erscheint nicht mehr in der `claude-mux -L`-Ausgabe. Um ausgeblendete Projekte zu sehen: `claude-mux -L --hidden`. Zum Einblenden: "show this project" oder `claude-mux --show my-project`.

## Wie deinstalliere ich claude-mux?

```bash
claude-mux --uninstall
```

Das entfernt Tipp-Hooks und Berechtigungsregeln aus allen Projekten, entlädt den LaunchAgent und entfernt optional `~/.claude-mux/`. Es zeigt den Binärpfad an, damit du ihn manuell löschen kannst (oder `brew uninstall claude-mux`, falls über Homebrew installiert).

## Funktionieren Slash-Befehle über Remote Control?

Nicht nativ. Claude Code unterstützt Slash-Befehle (`/model`, `/clear` usw.) in RC-Sitzungen nicht. claude-mux umgeht das, indem jede Sitzung mit `claude-mux -s` versehen wird, damit Claude Slash-Befehle über tmux an sich selbst senden kann. Sage einfach "switch to Haiku" oder "compact this session" und Claude erledigt den Rest.

## Ich kann keinen Text in einer Sitzung auswählen

Halte **Option** (macOS) oder **Shift** (Linux/Windows-Terminals) gedrückt, während du klickst und ziehst. Das umgeht die Mauserfassung von tmux und kopiert die Auswahl in deine Systemzwischenablage. Keine Konfigurationsänderungen nötig.

## Welche Sprachen werden für konversationelle Befehle unterstützt?

Alle. Die Auslösephrasen ("help", "status", "list sessions" usw.) funktionieren in jeder Sprache. Claude erkennt die Absicht aus der natürlichen Sprache des Benutzers und führt den passenden Befehl aus. Das README ist außerdem in 12 Sprachen übersetzt.
