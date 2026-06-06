# FAQ

[English](../docs/FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · **Deutsch** · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## Was ist claude-mux?

Ein Shell-Skript, das Claude Code in tmux fuer persistente Sitzungen einkapselt. Sitzungen ueberleben das Schliessen des Terminals, setzen den Konversationskontext bei Neustart fort und sind ueber die Claude-Mobile-App per Remote Control erreichbar. Du verwaltest alles, indem du innerhalb einer Sitzung mit Claude sprichst.

## Funktioniert es unter Linux?

Noch nicht. Nur macOS (Apple Silicon und Intel). Linux-Unterstuetzung ist fuer v2.0 geplant. Der Installer laeuft unter Linux, ueberspringt aber die LaunchAgent-Einrichtung und gibt einen Hinweis aus. Das Binary selbst funktioniert, aber es gibt noch keinen systemd-Service oder vergleichbaren Autostart-Mechanismus.

## Was ist die Home-Sitzung?

Die Home-Sitzung ist eine Allzweck-Claude-Sitzung in deinem Basisverzeichnis (`~/Claude` standardmaessig). Wenn `LAUNCHAGENT_MODE=home` (Standard), startet sie automatisch beim Login und laeuft den ganzen Tag. Sie ist standardmaessig **geschuetzt**, das heisst `--shutdown home` verweigert das Beenden ohne `--force`.

Nutze die Home-Sitzung als deinen staendig verfuegbaren Einstiegspunkt ueber die Claude-Mobile-App. Von dort kannst du Projekte auflisten, andere Sitzungen starten, Konfiguration verwalten und allgemeine Arbeiten erledigen, die zu keinem bestimmten Projekt gehoeren.

## Was ist Remote Control?

Remote Control (RC) ist eine Claude Code-Funktion, die es dir erlaubt, dich von der Claude-Mobile-App oder Claude Desktop mit einer laufenden Claude-Sitzung zu verbinden. claude-mux startet jede Sitzung mit `--remote-control`, sodass alle Sitzungen automatisch in der RC-Liste erscheinen. Sobald verbunden, sprichst du mit Claude genau wie im Terminal. claude-mux umgeht auch RC-Einschraenkungen wie nicht funktionierende Slash Commands, indem es sie ueber tmux leitet.

## Was sind Berechtigungsmodi?

Claude Code hat vier Berechtigungsmodi, die steuern, wie viel Autonomie Claude hat:

| Modus | Verhalten |
|-------|-----------|
| `default` | Claude fragt vor dem Ausfuehren von Befehlen oder dem Bearbeiten von Dateien |
| `acceptEdits` | Claude wendet Dateibearbeitungen automatisch an, fragt aber vor Shell-Befehlen |
| `plan` | Claude kann nur lesen und planen, keine Schreibvorgaenge oder Befehle |
| `bypassPermissions` | Claude fuehrt alles ohne Nachfrage aus (erfordert Bestaetigung beim ersten Start) |

Setze den Standard fuer alle Projekte ueber `DEFAULT_PERMISSION_MODE` in der Konfiguration. Wechsle eine laufende Sitzung, indem du sagst "wechsle diese Sitzung in den Plan-Modus" (oder jeden anderen Modusnamen). "yolo" ist ein Alias fuer `bypassPermissions`.

Der Wechsel zu `bypassPermissions` von einem anderen Modus verwendet Shift+Tab-Navigation und erfordert keinen Neustart. Der Wechsel von `bypassPermissions` zu einem anderen Modus erfordert einen Neustart, den claude-mux automatisch durchfuehrt.

## Wie setze ich eine Sitzung zurueck?

Drei Optionen, je nachdem was du brauchst:

- **Clear** ("loesche diese Sitzung"): sendet `/clear` an die Sitzung. Loescht den Konversationsverlauf und startet frisch. Die Sitzung laeuft weiter.
- **Compact** ("komprimiere diese Sitzung"): sendet `/compact` an die Sitzung. Fasst die Konversation in einen kuerzeren Kontext zusammen und gibt das Kontextfenster frei. Der Verlauf bleibt in komprimierter Form erhalten.
- **Restart** ("starte diese Sitzung neu"): faehrt Claude herunter und startet es mit `claude -c` neu, was die letzte Konversation fortsetzt. Nutze dies, wenn du einen sauberen Prozess brauchst (z.B. nach Aenderung der Berechtigungsmodi oder wenn Claude haengt).

## Was sind Templates?

Templates sind wiederverwendbare CLAUDE.md-Dateien in `~/.claude-mux/templates/`. Wenn du ein neues Projekt mit `-n` erstellst, wird das Standard-Template (oder eines, das du mit `--template NAME` angibst) als CLAUDE.md ins Projekt kopiert.

Template erstellen: "speichere das als Template mit dem Namen web" (kopiert das CLAUDE.md des aktuellen Projekts nach `~/.claude-mux/templates/web.md`).

Template verwenden: `claude-mux -n ~/projekte/my-app --template web` oder innerhalb einer Sitzung: "erstelle ein neues Projekt namens my-app mit dem web-Template".

Templates auflisten: "Templates auflisten" oder `claude-mux --list-templates`.

## Wie funktioniert der Tip-of-the-Day?

Ein Claude Code `UserPromptSubmit`-Hook in der `.claude/settings.local.json` jedes Projekts ruft bei jeder Eingabe `claude-mux --on-prompt` auf. Die erste Eingabe des Tages spielt einen Tipp in die Konversation ein; spaetere Eingaben an diesem Tag spielen nichts ein. Der Zustand ist pro Sitzung und wird in `~/.claude-mux/tip-state/<session_id>.json` gespeichert, sodass jede aktive Sitzung den Tipp einmal pro Tag zeigt. Da der Hook in den Kontext einspielt (kein Stop-Hook, dessen Ausgabe nur im Transkript landet), ist der Tipp in der Konversation und in Remote Control sichtbar.

Tipps sind standardmaessig aktiviert (`TIP_OF_DAY=true`). Umschalten mit "tips aktivieren" oder "tips deaktivieren" innerhalb jeder Sitzung. `TIP_MODE=daily` zeigt den ganzen Tag denselben Tipp; `TIP_MODE=random` waehlt einen zufaelligen Tipp.

Der `--tip`-Befehl funktioniert immer unabhaengig von der Tagessperre (und unabhaengig von `TIP_OF_DAY`), du kannst also jederzeit "tip" sagen.

## Kann ich das mit mehreren GitHub-Konten nutzen?

Ja. claude-mux erkennt `Host github.com-*`-Eintraege in `~/.ssh/config` und injiziert sie in den System-Prompt jeder Sitzung. Claude weiss, welche SSH-Aliase verfuegbar sind und kann den richtigen beim Einrichten von Git-Remotes verwenden.

Beispiel `~/.ssh/config`:

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

Claude verwendet dann `git@github.com-work:org/repo.git` fuer Arbeitsrepos und `git@github.com-personal:user/repo.git` fuer persoenliche.

## Wo wird der Zustand gespeichert?

| Ort | Inhalt |
|-----|--------|
| `~/.claude-mux/config` | Benutzerkonfiguration (wird als Bash gesourct) |
| `~/.claude-mux/templates/` | CLAUDE.md-Template-Dateien |
| `~/.claude-mux/tip-state/<session_id>.json` | Tipp-Datum pro Sitzung + Drossel fuer Update-Hinweise |
| `~/.claude-mux/.update-check` | Zwischengespeichertes Ergebnis der Versionspruefung |
| `~/.claude-mux/.update-checking` | Sperre waehrend der Update-Pruefung im Hintergrund |
| `~/Library/Logs/claude-mux.log` | Logdatei (konfigurierbar ueber `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | LaunchAgent-plist (generiert von `--install`) |
| `.claudemux-protected` (pro Projekt) | Markiert eine Sitzung als geschuetzt vor dem Beenden |
| `.claudemux-ignore` (pro Projekt) | Versteckt ein Projekt aus Auflistungen |

Markerdateien (`.claudemux-*`) liegen im Wurzelverzeichnis jedes Projekts und wandern mit dem Ordner bei Umbenennung, Verschiebung und Synchronisation. Sie werden automatisch zu `.gitignore` hinzugefuegt.

Der Konversationsverlauf wird von Claude Code selbst verwaltet und unter `~/.claude/projects/` gespeichert.

## Was passiert mit Auto-Update, wenn ich claude-mux forke?

Die Update-Pruefung und der `--update`-Befehl verwenden fest `pereljon/claude-mux` als GitHub-Repo. Wenn du forkst, vergleichen Update-Pruefungen weiterhin mit dem Upstream-Release, und `--update` ueberschreibt dein Fork-Binary mit dem Upstream. Setze `UPDATE_CHECK=false` in `~/.claude-mux/config` zum Deaktivieren, oder aendere die Repo-URL in den Funktionen `check_for_update()` und `do_update()` im Skript.

## Wie installiere ich ueber Homebrew?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Aktualisieren mit `brew upgrade claude-mux`. Hinweis: Wenn du ueber Homebrew installiert hast, delegiert `--update` automatisch an `brew upgrade`.

## Wie unterscheidet sich das von `claude --worktree --tmux`?

`claude --worktree --tmux` erstellt eine tmux-Sitzung fuer einen isolierten Git-Worktree, gedacht fuer parallele Programmieraufgaben. claude-mux verwaltet persistente Sitzungen fuer deine tatsaechlichen Projektverzeichnisse, mit aktiviertem Remote Control, System-Prompt-Injektion fuer Selbstverwaltung, Konversationsfortsetzung und Sitzungs-Lifecycle-Management. Sie loesen unterschiedliche Probleme.

## Wie unterscheidet sich das von Claude Cowork Dispatch?

Dispatch startet Aufgaben ueber die Claude-Desktop-App, erfordert aber, dass die App laeuft, und ist nicht an ein bestimmtes Projekt gebunden. claude-mux verwaltet persistente, projektgebundene Sitzungen, die Neustarts ueberleben und von ueberall ueber Remote Control erreichbar sind - keine Desktop-App erforderlich.

## Warum zeigen Sitzungen "Not logged in"?

Das passiert beim ersten Start, wenn der macOS-Schluesselband gesperrt ist, was haeufig vorkommt, wenn der LaunchAgent startet, bevor du den Schluesselband nach dem Login entsperrst. Loesung: `security unlock-keychain` in einem normalen Terminal ausfuehren, dann zu einer beliebigen Sitzung verbinden (`claude-mux -t <name>`) und `/login` ausfuehren, um den Browser-Auth-Flow abzuschliessen. Danach alle Sitzungen neu starten - sie uebernehmen dann die gespeicherten Anmeldedaten.

## Koennen mehrere Terminals dieselbe Sitzung nutzen?

Ja. Das ist Standard-tmux-Verhalten. `claude-mux` in einem Verzeichnis ausfuehren, das bereits eine laufende Sitzung hat, verbindet sich damit. Mehrere Terminals sehen den gleichen Sitzungsinhalt in Echtzeit.

## Wie stoppe ich die Home-Sitzung dauerhaft?

Der LaunchAgent hat `KeepAlive: true`, das Beenden der Home-Sitzung loest also innerhalb von etwa 60 Sekunden einen Neustart aus. Um sie dauerhaft zu stoppen, deaktiviere den LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## Was bedeutet die Meldung "Session ready!"?

Wenn eine Sitzung startet oder neugestartet wird, sendet claude-mux nach dem Laden von Claude einen `Ready?`-Prompt. Die Injektion weist Claude an, mit "Session ready!" und nichts anderem zu antworten. Das bestaetigt, dass die Sitzung aktiv ist und die System-Prompt-Injektion funktioniert. Du kannst es ignorieren.

## Wie verstecke ich ein Projekt aus Auflistungen?

Sage "verstecke dieses Projekt" innerhalb einer Sitzung, oder fuehre `claude-mux --hide my-project` aus. Das erstellt eine `.claudemux-ignore`-Markerdatei. Das Projekt erscheint nicht in der `claude-mux -L`-Ausgabe. Um versteckte Projekte zu sehen: `claude-mux -L --hidden`. Zum Einblenden: "zeige dieses Projekt" oder `claude-mux --show my-project`.

## Wie deinstalliere ich claude-mux?

```bash
claude-mux --uninstall
```

Das entfernt Tipp-Hooks und Berechtigungsregeln aus allen Projekten, entlaedt den LaunchAgent und entfernt optional `~/.claude-mux/`. Es zeigt den Binary-Pfad an, damit du ihn manuell loeschen kannst (oder `brew uninstall claude-mux` bei Installation ueber Homebrew).

## Funktionieren Slash Commands ueber Remote Control?

Nicht nativ. Claude Code unterstuetzt Slash Commands (`/model`, `/clear`, usw.) in RC-Sitzungen nicht. claude-mux umgeht das, indem jeder Sitzung `claude-mux -s` injiziert wird, sodass Claude Slash Commands ueber tmux an sich selbst senden kann. Sage einfach "wechsle zu Haiku" oder "komprimiere diese Sitzung" und Claude erledigt das.

## Ich kann keinen Text in einer Sitzung auswaehlen

Halte **Option** (macOS) oder **Shift** (Linux/Windows-Terminals) gedrueckt, waehrend du klickst und ziehst. Das umgeht die Mauserfassung von tmux und kopiert die Auswahl in die Zwischenablage. Keine Konfigurationsaenderungen noetig.

## Welche Sprachen werden fuer Konversationsbefehle unterstuetzt?

Alle. Die Trigger-Phrasen ("help", "status", "list sessions", usw.) funktionieren in jeder Sprache. Claude erkennt die Absicht aus der natuerlichen Sprache des Benutzers und fuehrt den passenden Befehl aus. Die README ist auch in 12 Sprachen uebersetzt.
