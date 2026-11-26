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

- **Sitzungen sterben** beim Schliessen des Terminals - und kommen nach einem Absturz oder Neustart nicht zurueck
- **Konversationskontext** wird nicht automatisch fortgesetzt
- **Keine Basis** - nichts laeuft, wenn du dein Handy in die Hand nimmst, es sei denn du hast etwas offen gelassen
- **Remote Control braucht eine laufende Sitzung** - du kannst keine ueber RC starten
- **Slash Commands funktionieren nicht in RC-Sitzungen** - kein Modellwechsel, kein Komprimieren, keine Aenderungen am Berechtigungsmodus
- **Neue Projekte starten** - erfordert manuelles Erstellen eines Verzeichnisses, git-Initialisierung, eine Anweisungsdatei (AGENTS.md oder CLAUDE.md) schreiben und ein Modell waehlen
- **Keine Projektverwaltung** - keine Moeglichkeit, inaktive Projekte zu sehen oder Projekte umzubenennen, zu verschieben und zu loeschen, ohne den Verlauf zu verlieren

**claude-mux schliesst die Luecke in der Sitzungsverwaltung.** Es packt Claude Code in tmux, damit Sitzungen bestehen bleiben, stellt sie nach Abstuerzen und Neustarts automatisch wieder her (sofern der automatische Login aktiviert ist), injiziert einen System-Prompt, damit Claude seine eigenen Sitzungen verwalten kann, und leitet Slash Commands ueber tmux weiter, damit sie ueber Remote Control funktionieren. Sobald eine Sitzung laeuft, steuerst du alles per Gespraech mit Claude - im Terminal oder in der Mobile-App.

## Was du in einer claude-mux-Sitzung tun kannst

- **Ueberlebt Abstuerze und Neustarts** - Sitzungen werden beim naechsten Login automatisch wiederhergestellt und setzen die letzte Konversation fort. Ein sauberes `/exit` oder Herunterfahren haelt eine Sitzung gestoppt; eine Sitzung im Absturz-Loop wird gestoppt und markiert, statt endlos neu gestartet zu werden.
- **Jede Sitzung von jeder Sitzung aus verwalten** - Projekte per natuerlicher Sprache starten, stoppen, neustarten, auflisten und komprimieren
- **Ueberall Zugriff** - jede Sitzung hat Remote Control aktiviert, sodass die Claude-Mobile-App, Desktop-App oder jeder Remote-Client eine vollwertige Oberflaeche ist
- **Modelle und Berechtigungsmodi wechseln** - sage "wechsle zu Haiku" oder "wechsle in den Plan-Modus" und Claude erledigt das, auch ueber Remote Control
- **Neue Projekte erstellen** - "erstelle ein neues Projekt namens my-app" richtet Verzeichnis, git, eine AGENTS.md aus einem Template ein und startet eine Sitzung. Templates ermoeglichen das Wiederverwenden von Anweisungen ueber Projekte hinweg.
- **Slash Commands ueber Remote Control senden** - Claude leitet `/model`, `/compact`, `/clear` und andere Slash Commands an die laufende Sitzung weiter - ein Workaround fuer eine [bekannte Einschraenkung](https://github.com/anthropics/claude-code/issues/30674). RC verbindet sich nach `/compact` ueber einen `PreCompact`-Hook automatisch neu.
- **Erkennung von Claude-Code-Upgrades** - aendert sich das `claude`-Binary (nach `brew upgrade` oder einem npm-Update), zeigen laufende Sitzungen einen Hinweis zum Neustart an, um das neue Binary zu laden; er bleibt ueber Prompts hinweg bestehen, bis du neu startest, sodass ein verpasster Zug ihn nicht verliert
- **Konversationsverlauf bewahren** - Umbenennen, Verschieben und Neustarten von Projekten bewahren den Konversationsverlauf automatisch
- **Projekte organisieren** - Projekte aus jeder Sitzung heraus verstecken, umbenennen, verschieben, loeschen und schuetzen
- **GitHub-Multi-Account-Unterstuetzung** - erkennt SSH-Aliase in `~/.ssh/config` und injiziert sie in Sitzungen, damit Claude den richtigen Account pro Projekt verwendet
- **AGENTS.md als Projekt-Anweisungsdatei** - `AGENTS.md` ist die einzige echte Datei und wird von Claude Code und Codex CLI gelesen. Sage "migriere zu AGENTS.md", um einen bestehenden Baum von `CLAUDE.md` umzustellen (zuerst ein Bericht, nichts wird committet). Erfordert Claude Code 2.1.277 oder neuer; aeltere Versionen behalten `CLAUDE.md`. Gemini CLI liest sie nur, wenn `~/.gemini/settings.json` `"context": {"fileName": ["AGENTS.md"]}` enthaelt.
- **Funktioniert in jeder Sprache** - Konversationsbefehle werden aus der Absicht abgeleitet, nicht aus Schluesselwoertern

## Mit Claude sprechen

So nutzt du claude-mux im Alltag. Jeder Sitzung werden Befehle injiziert, damit Claude Sitzungen verwalten, Modelle wechseln, Slash Commands senden und neue Projekte erstellen kann - alles innerhalb der Konversation. Du musst dir keine CLI-Flags merken.

```
Sage: "status"
Berichtet Sitzungsname, Modell, Berechtigungsmodus, Kontextnutzung und listet alle Sitzungen

Sage: "aktive Sitzungen auflisten"
Zeigt alle laufenden Sitzungen mit ihrem Status

Sage: "inaktive Sitzungen auflisten"
Zeigt nur inaktive Projekte

Sage: "gestoppte Sitzungen auflisten"
Zeigt nur gestoppte Sitzungen

Sage: "starte eine Sitzung fuer mein api-server-Projekt"
Startet die Sitzung per Name; passiert nichts, wenn sie schon laeuft

Sage: "erstelle ein neues Projekt namens mobile-app mit dem web-Template"
Erstellt das Projektverzeichnis, initialisiert git, wendet das Template an, startet eine Sitzung

Sage: "wechsle diese Sitzung zu Haiku"
Loest die Familie zur neuesten konkreten ID auf und sendet /model claude-haiku-4-5 an sich selbst

Sage: "komprimiere die api-server-Sitzung"
Sendet /compact an die api-server-Sitzung

Sage: "starte die web-dashboard-Sitzung neu"
Faehrt die Sitzung herunter und startet sie neu, wobei der Konversationskontext erhalten bleibt

Sage: "starte diese Sitzung frisch neu"
Bittet um Bestaetigung, startet dann mit einer neuen Konversation neu - ohne Fortsetzung, ohne frueheren Kontext

Sage: "beende die api-server-Sitzung"
Bittet um Bestaetigung, loescht dann die Konversation und stoppt die Sitzung; der naechste Start ist eine neue Konversation, keine Fortsetzung

Sage: "beende diese Sitzung"
Sichert zuerst unfertige Arbeit und den naechsten Schritt, bittet um Bestaetigung (und fragt, ob etwas ungesichert ist), startet dann frisch neu

Sage: "wechsle die api-server-Sitzung in den Plan-Modus"
Startet die Sitzung mit dem Berechtigungsmodus plan neu

Sage: "wechsle diese Sitzung in den Yolo-Modus"
Wechselt ueber Shift+Tab zu bypassPermissions - kein Neustart noetig

Sage: "in welchem Modus ist diese Sitzung"
Berichtet den aktuellen Berechtigungsmodus (default, acceptEdits, plan, bypassPermissions)

Sage: "wechsle diese Sitzung zu Opus"
Loest die Familie zur neuesten konkreten ID auf und sendet /model claude-opus-4-8 an sich selbst

Sage: "loesche diese Sitzung"
Bittet um Bestaetigung, sendet dann /clear an sich selbst und setzt die Konversation zurueck

Sage: "verstecke dieses Projekt"
Schreibt .claudemux-ignore, sodass das Projekt von -L-Auflistungen ausgeschlossen wird

Sage: "schuetze diese Sitzung"
Schreibt .claudemux-protected und setzt den tmux-Marker - --shutdown erfordert jetzt --force

Sage: "ist diese Sitzung geschuetzt"
Prueft, ob .claudemux-protected im Projektordner vorhanden ist, und berichtet

Sage: "loesche das old-prototype-Projekt"
Bestaetigt im Chat, verschiebt dann den Projektordner in den Papierkorb

Sage: "benenne dieses Projekt um in my-new-name"
Stoppt die Sitzung, benennt den Ordner um, migriert den Konversationsverlauf, startet neu

Sage: "speichere das als Template mit dem Namen web"
Kopiert AGENTS.md (oder CLAUDE.md) nach ~/.claude-mux/templates/web.md

Sage: "pruefe die Agents-Migration" / "migriere zu AGENTS.md"
Berichtet (nur lesend), welche CLAUDE.md-Dateien zu AGENTS.md wechseln koennen; nach Bestaetigung benennt es sie im ganzen Baum um und startet die laufenden Sitzungen unter dem Basisverzeichnis neu

Sage: "tip"
Zeigt einen Tipp - den ganzen Tag derselbe, oder zufaellig wenn TIP_MODE=random gesetzt ist

Sage: "tips aktivieren" / "tips deaktivieren"
Schaltet den taeglichen Tipp projektuebergreifend ein oder aus

Sage: "claude-mux aktualisieren"
Warnt, dass alle Sitzungen neugestartet werden, bittet um Bestaetigung, aktualisiert und startet neu

Sage: "alle Sitzungen stoppen"
Beendet ordnungsgemaess alle verwalteten Sitzungen

Sage: "help"
Zeigt die vollstaendige Liste der Konversationsbefehle
```

**Diese Befehle funktionieren in jeder Sprache.** Wenn du das Aequivalent auf Deutsch, Japanisch, Hebraeisch oder in jeder anderen Sprache tippst, erkennt Claude die Absicht und fuehrt den passenden Befehl aus.

**Tippe `help` in einer beliebigen Sitzung, um die vollstaendige Befehlsliste zu sehen.**

## Mehr

- [CLI-Referenz](../docs/CLI.md) - vollstaendige Befehlsreferenz fuer Scripting und Automatisierung
- [Leitfaden](../docs/GUIDE.md) - Konfiguration, Sitzungsdetails, Interna und Fehlerbehebung
- [Installationsoptionen](../docs/INSTALL.md) - Homebrew, manuelle Installation, LaunchAgent-Einrichtung
- [FAQ](../docs/FAQ.md) - haeufige Fragen zu claude-mux
- [Bekannte Probleme](../docs/ISSUES.md) - offene Bugs, geplante Features und geloeste Probleme
- [Changelog](../CHANGELOG.md) - Aenderungen pro Release
