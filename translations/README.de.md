# claude-mux - Claude Code Multiplexer

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · **Deutsch** · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Persistente Claude Code-Sitzungen fuer alle deine Projekte - von ueberall ueber die Claude-Mobile-App erreichbar. ***Von Claude verwaltet!***

## Installieren

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Dann starte eine Sitzung:

```bash
claude-mux ~/pfad/zu/deinem/projekt
```

Der Installer fragt, ob du beim Login eine Home-Sitzung starten moechtest. Wenn du zustimmst, startet eine geschuetzte Claude-Sitzung automatisch bei jeder Anmeldung - immer erreichbar ueber dein Handy oder einen anderen Remote Control Client, auch wenn du kein Terminal oeffnest.

Das war's! Du bist in einer persistenten, sitzungsbewussten Claude-Sitzung mit aktiviertem Remote Control. **Ab hier ist alles per Konversation steuerbar.**

[Homebrew, manuelle Installation und weitere Optionen](../docs/INSTALL.md)

## Warum

Remote Control verspricht Claude Code von ueberall - aber ohne Sitzungsverwaltung ist es selbst von Claude Desktop aus eine zweitklassige Oberflaeche:

- **Sitzungen sterben** beim Schliessen des Terminals
- **Konversationskontext** wird nicht automatisch fortgesetzt
- **Keine Basis** - nichts laeuft, wenn du dein Handy in die Hand nimmst, es sei denn du hast etwas offen gelassen
- **Remote Control braucht eine laufende Sitzung** - du kannst keine ueber RC starten
- **Slash Commands funktionieren nicht in RC-Sitzungen** - kein Modellwechsel, kein Komprimieren, keine Aenderungen am Berechtigungsmodus
- **Neue Projekte starten** - erfordert manuelles Erstellen eines Verzeichnisses, git-Initialisierung, CLAUDE.md schreiben und ein Modell waehlen
- **Keine Projektverwaltung** - keine Moeglichkeit, inaktive Projekte zu sehen oder Projekte umzubenennen, zu verschieben und zu loeschen, ohne den Verlauf zu verlieren

**claude-mux schliesst die Luecke in der Sitzungsverwaltung.** Es packt Claude Code in tmux, damit Sitzungen bestehen bleiben, injiziert einen System-Prompt, damit Claude seine eigenen Sitzungen verwalten kann, und leitet Slash Commands ueber tmux weiter, damit sie ueber Remote Control funktionieren. Sobald eine Sitzung laeuft, steuerst du alles per Gespraech mit Claude - im Terminal oder in der Mobile-App.

## Was du in einer claude-mux-Sitzung tun kannst

- **Jede Sitzung von jeder Sitzung aus verwalten** - Projekte per natuerlicher Sprache starten, stoppen, neustarten, auflisten und komprimieren
- **Ueberall Zugriff** - jede Sitzung hat Remote Control aktiviert, sodass die Claude-Mobile-App, Desktop-App oder jeder Remote-Client eine vollwertige Oberflaeche ist
- **Modelle und Berechtigungsmodi wechseln** - sage "wechsle zu Haiku" oder "wechsle in den Plan-Modus" und Claude erledigt das, auch ueber Remote Control
- **Neue Projekte erstellen** - "erstelle ein neues Projekt namens my-app" richtet Verzeichnis, git, CLAUDE.md ein und startet eine Sitzung. CLAUDE.md-Templates ermoeglichen das Wiederverwenden von Anweisungen ueber Projekte hinweg.
- **Sitzungen ueber Neustarts hinweg am Leben halten** - eine optionale Home-Sitzung startet beim Login und bleibt aktiv; alle Sitzungen setzen ihre letzte Konversation automatisch fort
- **Slash Commands ueber Remote Control senden** - Claude leitet `/model`, `/compact`, `/clear` und andere Slash Commands an die laufende Sitzung weiter - ein Workaround fuer eine [bekannte Einschraenkung](https://github.com/anthropics/claude-code/issues/30674)
- **Konversationsverlauf bewahren** - Umbenennen, Verschieben und Neustarten von Projekten bewahren den Konversationsverlauf automatisch
- **Projekte organisieren** - Projekte aus jeder Sitzung heraus verstecken, umbenennen, verschieben, loeschen und schuetzen
- **GitHub-Multi-Account-Unterstuetzung** - erkennt SSH-Aliase in `~/.ssh/config` und injiziert sie in Sitzungen, damit Claude den richtigen Account pro Projekt verwendet
- **Multi-CLI-Coder-Unterstuetzung** - erstellt automatisch `AGENTS.md`- und `GEMINI.md`-Symlinks, damit Codex CLI, Gemini CLI und andere die gleichen Anweisungen nutzen
- **Funktioniert in jeder Sprache** - Konversationsbefehle werden aus der Absicht abgeleitet, nicht aus Schluesselwoertern

## Mit Claude sprechen

So nutzt du claude-mux im Alltag. Jeder Sitzung werden Befehle injiziert, damit Claude Sitzungen verwalten, Modelle wechseln, Slash Commands senden und neue Projekte erstellen kann - alles innerhalb der Konversation. Du musst dir keine CLI-Flags merken.

```
Du: "status"
Claude: berichtet Sitzungsname, Modell, Berechtigungsmodus, Kontextnutzung und listet alle Sitzungen

Du: "aktive Sitzungen auflisten"
Claude: zeigt alle laufenden Sitzungen mit ihrem Status

Du: "starte eine Sitzung fuer mein api-server-Projekt"
Claude: startet eine Sitzung in ~/Claude/work/api-server

Du: "erstelle ein neues Projekt namens mobile-app mit dem web-Template"
Claude: erstellt das Projektverzeichnis, initialisiert git, wendet das Template an, startet eine Sitzung

Du: "wechsle diese Sitzung zu Haiku"
Claude: sendet /model haiku an sich selbst ueber tmux

Du: "komprimiere die api-server-Sitzung"
Claude: sendet /compact an die api-server-Sitzung

Du: "starte die web-dashboard-Sitzung neu"
Claude: faehrt die Sitzung herunter und startet sie neu, wobei der Konversationskontext erhalten bleibt

Du: "wechsle die api-server-Sitzung in den Plan-Modus"
Claude: startet die Sitzung mit dem Berechtigungsmodus plan neu

Du: "wechsle diese Sitzung in den Yolo-Modus"
Claude: wechselt ueber Shift+Tab zu bypassPermissions - kein Neustart noetig

Du: "in welchem Modus ist diese Sitzung"
Claude: berichtet den aktuellen Berechtigungsmodus (default, acceptEdits, plan, bypassPermissions)

Du: "wechsle diese Sitzung zu Opus"
Claude: sendet /model opus an sich selbst ueber tmux

Du: "loesche diese Sitzung"
Claude: sendet /clear an sich selbst und setzt die Konversation zurueck

Du: "verstecke dieses Projekt"
Claude: schreibt .claudemux-ignore, sodass das Projekt von -L-Auflistungen ausgeschlossen wird

Du: "schuetze diese Sitzung"
Claude: schreibt .claudemux-protected und setzt den tmux-Marker - --shutdown erfordert jetzt --force

Du: "ist diese Sitzung geschuetzt"
Claude: prueft, ob .claudemux-protected im Projektordner vorhanden ist, und berichtet

Du: "loesche das old-prototype-Projekt"
Claude: bestaetigt im Chat, verschiebt dann den Projektordner in den Papierkorb

Du: "benenne dieses Projekt um in my-new-name"
Claude: stoppt die Sitzung, benennt den Ordner um, migriert den Konversationsverlauf, startet neu

Du: "speichere das als Template mit dem Namen web"
Claude: kopiert CLAUDE.md nach ~/.claude-mux/templates/web.md

Du: "tip"
Claude: zeigt einen Tipp - den ganzen Tag derselbe, oder zufaellig wenn TIP_MODE=random gesetzt ist

Du: "tips aktivieren" / "tips deaktivieren"
Claude: schaltet den täglichen Tipp projektübergreifend ein oder aus

Du: "claude-mux aktualisieren"
Claude: warnt, dass alle Sitzungen neugestartet werden, bittet um Bestaetigung, aktualisiert und startet neu

Du: "alle Sitzungen stoppen"
Claude: beendet ordnungsgemaess alle verwalteten Sitzungen

Du: "help"
Claude: zeigt die vollstaendige Liste der Konversationsbefehle
```

**Diese Befehle funktionieren in jeder Sprache.** Wenn du das Aequivalent auf Deutsch, Japanisch, Hebraeisch oder in jeder anderen Sprache tippst, erkennt Claude die Absicht und fuehrt den passenden Befehl aus.

**Tippe `help` in einer beliebigen Sitzung, um die vollstaendige Befehlsliste zu sehen.**

## Mehr

- [CLI-Referenz](../docs/CLI.md) - vollstaendige Befehlsreferenz fuer Scripting und Automatisierung
- [Leitfaden](../docs/guide.md) - Konfiguration, Sitzungsdetails, Interna und Fehlerbehebung
- [Installationsoptionen](../docs/INSTALL.md) - Homebrew, manuelle Installation, LaunchAgent-Einrichtung
- [FAQ](../docs/FAQ.md) - haeufige Fragen zu claude-mux
- [Bekannte Probleme](../docs/ISSUES.md) - offene Bugs, geplante Features und geloeste Probleme
- [Changelog](../CHANGELOG.md) - Aenderungen pro Release
