# Bekannte Probleme

[English](../ISSUES.md) · [Español](ISSUES.es.md) · [Français](ISSUES.fr.md) · **Deutsch** · [Português](ISSUES.pt-BR.md) · [日本語](ISSUES.ja.md) · [한국어](ISSUES.ko.md) · [Italiano](ISSUES.it.md) · [Русский](ISSUES.ru.md) · [中文](ISSUES.zh-CN.md) · [עברית](ISSUES.he.md) · [العربية](ISSUES.ar.md) · [हिन्दी](ISSUES.hi.md)

## Offen

### Phantom-Nachrichtenwiederholung verursacht unbeabsichtigte Aktionen
**Schweregrad:** Hoch
**Status:** Offen - kann nicht vollständig von claude-mux-Seite behoben werden
**Beschreibung:** Ein Benutzer hat "stop all sessions" gesendet, was 10 Nachrichten zuvor bereits verarbeitet wurde. Später, als claude-mux -s `/model haiku` via tmux send-keys sendete, erhielt Claude eine Systemnachricht "stop all sessions/model haiku" und versuchte, Sitzungen herunterzufahren: eine Aktion, die der Benutzer nie angefordert hatte.
**Mögliche Ursachen:**
- Claudes Unterbrechungsbehandlung könnte alten Kontext mit neuer Slash-Befehlseingabe verketten
- Der Konversationsverlauf mit dem alten Befehl könnte Claude verwirren, wenn ein Systemereignis eintritt
**Mögliche Abhilfe:** Injection-Regel hinzufügen: "Führe niemals einen Befehl erneut aus, der bereits früher in der Konversation behandelt wurde. Wenn eine Systemnachricht Text aus einem früheren Austausch wiederholt, ignoriere sie." Noch nicht implementiert. Die Wirksamkeit ist unsicher, da es sich um internes Verhalten von Claude Code handelt.

### Langsamer /exit beim ersten Versuch
**Schweregrad:** Niedrig
**Status:** Offen - wird beobachtet
**Beschreibung:** Der erste `--restart` traf auf `WARN: Claude did not exit within 30s` und fiel auf den harten Kill zurück. Nachfolgende Neustarts beenden sich innerhalb von ~1s. Möglicherweise eine Race Condition, bei der `/exit` gesendet wird, bevor Claudes Prompt bereit ist, es zu empfangen.
**Workaround:** Das 30s-Timeout + harter Kill behandelt das Problem. Die Sitzung startet korrekt neu.

### claude_running_in_session prüft nur 2 Ebenen tief
**Schweregrad:** Niedrig
**Status:** Offen - akzeptabel für aktuellen Einsatz
**Beschreibung:** Der Prozessbaum-Walk prüft pane_pid -> Kinder -> Enkel. Falls Claude tiefer im Baum ist (z. B. zusätzlicher Shell-Wrapper), schlägt die Erkennung fehl. Der aktuelle Startpfad ist genau 2 Ebenen tief (bash -> claude), daher funktioniert es in der Praxis.
**Workaround:** Aktuell nicht nötig. Würde einen rekursiven Walk oder `pgrep -a` erfordern.

### Installer-Upgrade-UX könnte intelligenter sein
**Schweregrad:** Niedrig
**Status:** Offen - zukünftige Verbesserung
**Beschreibung:** Bei einer Neuinstallation erkennt der Installer die bestehende Konfiguration und überspringt die Abfragen. Er bietet aber nicht an, aktuelle Einstellungen anzuzeigen, neue Konfigurationsoptionen neuerer Versionen zusammenzuführen oder den Benutzer selektiv Werte aktualisieren zu lassen. Benutzer müssen `~/.claude-mux/config` manuell bearbeiten, um neue Einstellungen späterer Versionen zu übernehmen.
**Mögliche Verbesserungen:**
- Aktuelle Konfigurationswerte beim Upgrade anzeigen
- Anbieten, neue Einstellungen (mit Standardwerten) hinzuzufügen, die in der alten Konfiguration nicht existierten
- Option B: Abfragen mit bestehenden Konfigurationswerten vorausfüllen und den Benutzer Änderungen vornehmen lassen

### Übersetzungsdateien benötigen v1.10-v1.12-Update
**Schweregrad:** Niedrig
**Status:** Offen - Übersetzungen noch nicht aktualisiert
**Beschreibung:** Alle 12 Übersetzungsdateien (`translations/README.*.md`) liegen um mehrere Versionen zurück (v1.10-v1.12). Änderungen, die berücksichtigt werden müssen:
- curl als primärer Schnellstart (Einzeiler)
- Neue Installationsabschnitt-Struktur (curl empfohlen, Homebrew macOS-Alternative)
- Sitzungsnamen statt Pfade für `--hide`/`--delete`/`--protect` (v1.11.0)
- Neue konversationelle Beispiele: rename, save-as-template, tip, enable/disable tips, update
- Anforderungen: "Apple Silicon oder Intel" (nicht nur Apple Silicon)
- Neuer "Mehr"-Abschnitt mit Links zu FAQ, ISSUES, CHANGELOG
- FAQ- und ISSUES-Übersetzungen müssen erstellt werden

### Code-Review aufgeschobene Probleme (v1.9.0)
**Schweregrad:** Niedrig-Mittel
**Status:** Behoben in v1.10.0 - M3, M4, M9/L8, L3, L9 behoben; L4, L5, L6, L7, M7 mit Kommentaren adressiert

### Projekt umbenennen / verschieben mit Verlaufserhaltung
**Schweregrad:** Niedrig
**Status:** Behoben in v1.10.0 - `--rename OLD NEW` und `--move SRC DEST` implementiert

### Projekt kopieren mit Verlauf
**Schweregrad:** Niedrig
**Status:** Offen - geplantes Feature, erfordert Untersuchung
**Beschreibung:** Das Kopieren eines Projekts einschließlich seiner Claude Code-History und Memory ist komplexer als Umbenennen/Verschieben, da für das Ziel neue UUIDs erstellt werden müssen.
**Geplanter Ansatz:**
1. Neues Projektverzeichnis erstellen (mit optionalem git init und Vorlage)
2. Eine Sitzung darin starten und sofort stoppen: Claude Code initialisiert `~/.claude/projects/-encoded-new-path/` mit einer neuen UUID und erstellt einen neuen Homunculus-Eintrag
3. `.jsonl`-Verlaufsdateien aus dem Quell-`~/.claude/projects/`-Ordner in den Zielordner kopieren
4. Inhalt des `memory/`-Ordners kopieren: reines Markdown, keine eingebetteten UUIDs, sicher zu kopieren
5. UUID-Unterverzeichnisse (Task-/Plan-Artefakte) zusammen mit ihren `.jsonl`-Dateien kopieren
6. Für Homunculus: `observations.jsonl`, `instincts`, `evolved`, `observations.archive` aus dem Quell-`~/.claude/homunculus/projects/<src-uuid>/` in den Homunculus-Ordner des neuen Ziels kopieren, dabei die in Schritt 2 zugewiesene neue Projekt-UUID beibehalten
**Offene Fragen, die getestet werden müssen:**
- Betten `.jsonl`-Dateien den Quellprojektpfad in ihrem Inhalt oder ihren Metadaten ein? Falls ja, würde kopierter Verlauf den alten Pfad referenzieren.
- Werden UUID-Unterverzeichnisse über die UUID aus `.jsonl`-Dateien referenziert? Falls ja, müssen sie unter ihren Original-UUIDs kopiert werden, nicht umgemappt.
- Liest Claude Code alle `.jsonl`-Dateien in einem Projektordner oder nur die, die der aktiven Sitzungs-UUID entspricht?
- Was enthalten `~/.claude/homunculus/projects/<uuid>/evolved` und `instincts`: sind sie abgeleitet/berechnet oder benutzerbedeutsam? Lohnt es sich, sie bei einer Kopie zu erhalten?
- Gibt es andere interne Referenzen, die bei einer naiven Dateikopie kaputt gehen würden?
**Voraussetzung:** Das oben Genannte vor der Implementierung testen, um keinen Kopierbefehl auszuliefern, der subtil fehlerhaften Verlauf erzeugt.

### Tipp des Tages
**Schweregrad:** Niedrig
**Status:** Behoben in v1.10.0 - `--tip`, `TIP_OF_DAY`, `TIP_MODE`, tägliche Sperre, Anzeige beim Sitzungsstart implementiert

### Antwort-Zeitstempel
**Schweregrad:** Niedrig
**Status:** Offen - vor Implementierung diskutieren
**Beschreibung:** Optionale Konfigurationsvariable (`REPLY_TIMESTAMP=false` Standard), die eine Anweisung in den System-Prompt injiziert, damit Claude jede Antwort mit dem aktuellen Datum und der Uhrzeit via `date '+%Y-%m-%d %H:%M'` beginnt.
**Abwägung:** Erfordert einen Bash-Tool-Aufruf am Anfang jeder Antwort (kleiner Overhead). Alternative: Sitzungsstartzeit in den Prompt injizieren (kostenlos, driftet aber in langen Sitzungen).
**Hinweis:** Eine projektspezifische CLAUDE.md-Anweisung (wie in der analytischen Vorlage) ist die leichtere Variante: nur für Projekte, die es wollen. Die Konfigurationsvariable macht es global.

### Demo-Video
**Schweregrad:** Niedrig
**Status:** Offen - geplantes Asset
**Beschreibung:** Eine Bildschirmaufnahme, die claude-mux vom curl-Install bis zu häufigen und interessanten Befehlen zeigt, mit Terminal und Remote Control gleichzeitig sichtbar.
**Format:** Geteilter Bildschirm, eine Aufnahme. Terminal (vollständige claude-mux-Sitzung) links, RC auf dem iPhone gespiegelt via QuickTime rechts. Beide gleichzeitig live: der Zuschauer sieht Aktionen in RC sofort im Terminal reflektiert und umgekehrt.
**Siehe:** `internal/demo-script.md` für die vollständige Szene-für-Szene-Übersicht.
**Hinweise:**
- Die entscheidende Aufnahme ist das Tippen in RC auf dem Telefon, während das Terminal in Echtzeit reagiert
- Kein Schnitt nötig außer Trim: eine einzige durchgehende Aufnahme
- Auf YouTube hosten + im README einbetten; auch nützlich für den Product Hunt-Launch

### Einreichung bei homebrew-core für brew.sh-Listung
**Schweregrad:** Niedrig
**Status:** Zukunft - wartet auf Verbreitung
**Beschreibung:** claude-mux wird aktuell über einen persönlichen Tap (`pereljon/tap`) verteilt. Um auf brew.sh zu erscheinen, muss es in homebrew-core aufgenommen werden. Die Bekanntheitsanforderung von Homebrew erfordert typischerweise einige hundert GitHub-Stars, bevor eine Einreichung eines Shell-Skript-Tools akzeptiert wird; Einreichungen mit wenigen Stars werden schnell geschlossen.
**Wenn bereit:**
- Sicherstellen, dass die Formel `brew audit --strict --new` besteht
- PR an `Homebrew/homebrew-core` mit der Formel einreichen
- Hinweis: macOS-only-Tools erfahren strengere Reviewer-Prüfung; Linux-Unterstützung (siehe unten) würde helfen

### curl-Install-Unterstützung (macOS + Linux)
**Schweregrad:** Niedrig
**Status:** Behoben in v1.10.0 - curl-Install implementiert, Release-Assets-Workflow hinzugefügt, README aktualisiert

### Nur macOS - keine Linux/systemd-Unterstützung
**Schweregrad:** Mittel
**Status:** Offen - teilweise adressiert (Pfaderkennung erledigt, LaunchAgent/Installer bleiben macOS-spezifisch)
**Beschreibung:** Verwendet macOS LaunchAgent (launchd) und macOS-spezifische Werkzeuge. Die Pfaderkennung wurde auf `command -v` umgestellt (hardcodet nicht mehr `/opt/homebrew/bin`), sodass das Kern-Skript jetzt auf jeder Plattform funktioniert, wo tmux und claude im PATH sind. LaunchAgent und Installer bleiben macOS-spezifisch.
**Verbleibend:** systemd User Unit, XDG Autostart-Fallback, `uname -s`-Dispatch im Installer.
**Paketstrategie (v1.10+):**
- curl-Install: universeller Fallback, funktioniert überall (siehe oben)
- AUR: geringer Aufwand, hohe Reichweite für die Zielgruppe auf Arch/Manjaro
- apt PPA: bei Nachfrage von Debian/Ubuntu-Benutzern
- Homebrew auf Linux: deckt Benutzer ab, die es bereits haben
- Snap/Flatpak: lohnt sich nicht für ein Bash-Skript

### !-Befehle nicht in Remote Control verfügbar
**Schweregrad:** Niedrig
**Status:** Geschlossen - nicht umsetzbar
**Beschreibung:** Claudes `!`-Shell-Durchleitung ist ein Feature des Claude Code CLI-Input-Handlers: es fängt `!command` ab, bevor die Shell es sieht. tmux send-keys kann dies nicht replizieren: Tastatureingaben, die gesendet werden, während Claude Code aktiv ist, kommen nirgendwo an (getestet: `!touch test` via send-keys wurde nicht ausgeführt). Es gibt keinen Weg für claude-mux, die `!command`-Umgehung für RC-Benutzer zu implementieren.
**Lösung:** Injection-Regel hinzufügen, die Claude anweist, Benutzern nie `! <command>` vorzuschlagen, da RC-Benutzer keine Shell haben und Terminal-Benutzer es einfach selbst eingeben können.

---

## v2.0-Meilenstein

Architekturänderungen, die bedeutend genug für einen Major-Versionsbump sind. Kein Zeitplan festgelegt: hier gesammelt, damit sie nicht verloren gehen.

### Trennung des Datenverzeichnisses
Statische Daten (Tipps, Standardvorlagen, möglicherweise Befehls-/Guide-Ausgabe) aus dem Skript in ein plattformgerechtes Datenverzeichnis verschieben. Das Skript würde `DATA_DIR` beim Start relativ zum Binär-Speicherort auflösen, mit eingebetteten Fallbacks für Einzeldatei-Installationen.

- Homebrew (Apple Silicon): `/opt/homebrew/share/claude-mux/`
- Homebrew (Intel): `/usr/local/share/claude-mux/`
- Linux: `/usr/local/share/claude-mux/` oder `$XDG_DATA_DIRS`
- Manuelle Installation: Fallback auf eingebettete Standardwerte (Einzeldatei-Installationen funktionieren weiterhin)

Auslöser: wenn die eingebetteten Daten (Tipps, Standardvorlagen) groß genug werden, um das Skript schwer lesbar zu machen, oder wenn Standardvorlagen unabhängig von Skript-Releases via Brew ausgeliefert werden müssen.

### Sprach-/Runtime-Überlegung
Das monolithische Bash-Skript ist beim aktuellen Umfang die richtige Wahl. Falls claude-mux deutlich wächst: Projekt-Umbenennung/-Verschiebung/-Kopie, ein Relay-Layer, plattformübergreifendes Packaging, ein Datenverzeichnis: dann wehrt sich Bash. An diesem Punkt lohnt es sich, den Session-Management-Kern in Go oder einer anderen typisierten Sprache (mit Bash als dünnem CLI-Wrapper) neu zu schreiben.

---

## Behoben

### Claude ignoriert die Injection und behauptet, keine Slash-Befehle ausführen zu können
**Behoben in:** v1.2.0 (Injection aktualisiert)
**Fix:** Explizite Regel zur Injection hinzugefügt: "You CAN send slash commands (`/model`, `/compact`, `/clear`, etc.) to this session via the `-s` command. Never tell the user you cannot change models or run slash commands." Claudes Basistraining neigt dazu, ihm glauben zu machen, er könne sein eigenes Modell/Einstellungen nicht steuern; die explizite Regel überschreibt das in der Praxis.

### Mehrere Befehle geben Exit-Code 1 trotz Erfolg zurück
**Behoben in:** v1.2.0 (restart), v1.3.0 (alle Befehle)
**Fix:** Explizites `exit 0` nach jedem Dispatch-Pfad in der Case-Anweisung hinzugefügt. Der letzte Befehl in einer Funktion kann einen Nicht-Null-Exit-Code von internen Tests oder grep-Aufrufen durchlassen.

### --dry-run gibt irreführende Ausgabe für --restart
**Behoben in:** v1.2.0 (Commit a10c0c2)
**Fix:** Dry-Run zeigt jetzt "Would restart session" statt den Kill zu simulieren und dann den realen Zustand zu prüfen.

### Sitzungserkennung schlägt mit pgrep auf macOS fehl
**Behoben in:** Commit e1b11b5
**Fix:** `pgrep -P` durch `ps -eo` + `awk` für zuverlässige Kindprozess-Erkennung ersetzt.

### $TMUX-Variable hat die Umgebungsvariable von tmux überdeckt
**Behoben in:** Commit 02a2e82
**Fix:** In `$TMUX_BIN` umbenannt.

### Bash 3.2-Inkompatibilität (declare -A)
**Behoben in:** Commit 575eac1
**Fix:** Assoziative Arrays durch string-basierte Kollisionserkennung ersetzt.

---

## Referenz: ~/.claude Ordnerstruktur

Hier dokumentiert, weil mehrere geplante Features (Umbenennen, Verschieben, Kopieren, Bereinigung) korrekt mit dieser Struktur interagieren müssen. Nicht vollständig: deckt die für claude-mux relevanten Teile ab.

### Projektverlauf und Memory: `~/.claude/projects/`

Ein Unterverzeichnis pro Arbeitsverzeichnis, in dem Claude Code verwendet wurde. Benannt durch Kodierung des absoluten Pfads: `/` wird zu `-`, Leerzeichen und Sonderzeichen werden zu `-`. Verlustbehaftet, aber lesbar.

Inhalt jedes Projektordners:
- `<uuid>.jsonl` - vollständiges Konversationstranskript für diese Sitzung. Eine Datei pro Konversation.
- `<uuid>/` - Unterverzeichnis mit Artefakten einer Konversation (Tasks, Pläne). UUID entspricht der `.jsonl`-Datei.
- `memory/` - persistente sitzungsübergreifende Memory-Dateien (Markdown mit Frontmatter). Nur vorhanden, wenn Memory für das Projekt geschrieben wurde.

Die Verbindung zwischen einem Arbeitsverzeichnis und seinem Verlauf ist rein der kodierte Ordnername. Das Umbenennen oder Verschieben des Projektverzeichnisses ohne Umbenennung dieses Ordners führt dazu, dass Claude Code ohne Verlauf neu startet.

**Kodierungsregel:** absoluter Pfad, wobei jeder `/`, jedes Leerzeichen und Sonderzeichen durch `-` ersetzt wird. Führendes `/` wird zu einem führenden `-`. Die Kodierung ist verlustbehaftet: aufeinanderfolgende Sonderzeichen und Leerzeichen neben Schrägstrichen werden beide zu `-`, daher kann das Original nicht immer perfekt rekonstruiert werden.

### Paralleles Observability-Register: `~/.claude/homunculus/`

Ein separates System, das Tool-Level-Ereignisse pro Projekt verfolgt. Nicht Teil der Kern-Claude-Code-History: scheint eine Monitoring-/Lernschicht zu sein.

- `projects.json` - Register aller bekannten Projekte, indiziert durch kurze Hex-UUID (`d6b3aef60967` usw.). Jeder Eintrag hat: `id`, `name`, `root` (absoluter Pfad), `remote`, `created_at`, `last_seen`.
- `projects/<uuid>/project.json` - projektspezifische Metadaten (gleiche Felder wie der Registereintrag).
- `projects/<uuid>/observations.jsonl` - zeitgestempelte `tool_start`/`tool_complete`-Ereignisse: Tool-Name, Sitzungs-UUID, Projektname/-ID, Input-/Output-Auszüge.
- `projects/<uuid>/instincts` - abgeleitete Muster (Inhalt unbekannt, wahrscheinlich berechnet).
- `projects/<uuid>/evolved` - weiterentwickelter/gelernter Zustand (Inhalt unbekannt).
- `projects/<uuid>/observations.archive` - archivierte ältere Beobachtungen.

**Hauptunterschied zu `~/.claude/projects/`:** Verwendet kurze Hex-UUIDs als Schlüssel, keine kodierten Pfade. Das `root`-Feld enthält den absoluten Pfad. Jede Operation, die den Pfad eines Projekts ändert (Umbenennen, Verschieben), muss `root` sowohl in `projects.json` als auch in `projects/<uuid>/project.json` aktualisieren.

### Globale Konfiguration: `~/.claude/settings.json`

Haupt-Claude-Code-Einstellungsdatei. Rollende Backups werden als `~/.claude.json.backup.<timestamp>` unter `~/.claude/backups/` geschrieben: mehrere pro Stunde bei aktiver Nutzung. claude-mux sollte diese Datei nicht anfassen.

### Globale Agents, Skills, Commands

- `~/.claude/agents/` - Subagent-Definitionen (`.md`-Dateien, ~38). Global, nicht projektspezifisch.
- `~/.claude/skills/` - Skill-Verzeichnisse (~125). Global, nicht projektspezifisch.
- `~/.claude/commands/` - Slash-Befehl-Definitionen (`.md`-Dateien, ~72). Global, nicht projektspezifisch.
- `~/.claude/hooks/hooks.json` - Hook-Definitionen. Global. claude-mux sollte diese nicht anfassen.

### Mögliche zukünftige Features

| Feature | Was angepasst werden muss |
|---------|--------------------------|
| `--copy` | Verzeichnis erstellen; Sitzung starten+stoppen, um beide Register zu initialisieren; `.jsonl` + `memory/` + UUID-Unterverzeichnisse kopieren; Homunculus-Beobachtungsdateien in neuen UUID-Ordner kopieren |
| `--delete` Bereinigung | Verschiebt bereits den Projektordner in den Papierkorb. Optional: verwaisten `~/.claude/projects/`-kodierten Ordner und `~/.claude/homunculus/`-Eintrag entfernen |
| Verlaufsgrößenwarnung | Warnung, wenn die `.jsonl`-Dateien eines Projekts einen Schwellenwert überschreiten (das Haupt-claude-mux-Transkript erreichte 107 MB in einer einzelnen langen Sitzung) |
