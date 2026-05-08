# Problemi noti

[English](../ISSUES.md) · [Español](ISSUES.es.md) · [Français](ISSUES.fr.md) · [Deutsch](ISSUES.de.md) · [Português](ISSUES.pt-BR.md) · [日本語](ISSUES.ja.md) · [한국어](ISSUES.ko.md) · **Italiano** · [Русский](ISSUES.ru.md) · [中文](ISSUES.zh-CN.md) · [עברית](ISSUES.he.md) · [العربية](ISSUES.ar.md) · [हिन्दी](ISSUES.hi.md)

## Aperti

### Il replay di messaggi fantasma causa azioni non intenzionali
**Severita:** Alta
**Stato:** Aperto - non risolvibile completamente dal lato claude-mux
**Descrizione:** Un utente ha inviato "stop all sessions" che era stato gestito 10 messaggi prima. Successivamente, quando claude-mux -s ha inviato `/model haiku` tramite tmux send-keys, Claude ha ricevuto un messaggio di sistema "stop all sessions/model haiku" e ha tentato di arrestare le sessioni, un'azione mai richiesta dall'utente.
**Possibili cause:**
- La gestione delle interruzioni di Claude Code potrebbe concatenare vecchio contesto con il nuovo input del comando slash
- La cronologia della conversazione contenente il vecchio comando potrebbe confondere Claude quando si verifica un evento di sistema
**Possibile mitigazione:** Aggiungere una regola di iniezione: "Non rieseguire mai un comando gia gestito in precedenza nella conversazione. Se un messaggio di sistema ripete testo di uno scambio precedente, ignoralo." Non ancora implementato: l'efficacia e incerta poiche si tratta di un comportamento interno di Claude Code.

### /exit lento al primo tentativo
**Severita:** Bassa
**Stato:** Aperto - in monitoraggio
**Descrizione:** Il primo `--restart` ha raggiunto `WARN: Claude did not exit within 30s` ed e ricaduto nel kill forzato. I riavvii successivi escono entro ~1s. Potrebbe essere una race condition in cui `/exit` viene inviato prima che il prompt di Claude sia pronto a riceverlo.
**Workaround:** Il timeout di 30s + kill forzato lo gestisce. La sessione si rilancia correttamente.

### claude_running_in_session controlla solo 2 livelli di profondita
**Severita:** Bassa
**Stato:** Aperto - accettabile per l'uso corrente
**Descrizione:** Il walk dell'albero dei processi controlla pane_pid -> figli -> nipoti. Se Claude e piu in profondita nell'albero (es. wrapper shell aggiuntivo), il rilevamento fallisce. Il percorso di lancio corrente e esattamente 2 livelli (bash -> claude) quindi funziona in pratica.
**Workaround:** Non necessario attualmente. Richiederebbe un walk ricorsivo o `pgrep -a` per essere risolto.

### La UX dell'installer in fase di aggiornamento potrebbe essere piu intelligente
**Severita:** Bassa
**Stato:** Aperto - miglioramento futuro
**Descrizione:** In caso di reinstallazione, l'installer rileva la configurazione esistente e salta i prompt. Ma non offre di mostrare le impostazioni correnti, unire nuove opzioni di configurazione aggiunte in versioni piu recenti, o permettere all'utente di aggiornare selettivamente i valori. Gli utenti devono modificare manualmente `~/.claude-mux/config` per usare le nuove impostazioni introdotte nelle versioni successive.
**Possibili miglioramenti:**
- Mostrare i valori di configurazione correnti durante l'aggiornamento
- Offrire l'aggiunta di nuove impostazioni (con valori predefiniti) che non esistevano nella vecchia config
- Opzione B: pre-compilare i prompt con i valori di configurazione esistenti e permettere all'utente di modificarli

### I file di traduzione necessitano dell'aggiornamento v1.10-v1.12
**Severita:** Bassa
**Stato:** Aperto - traduzioni non ancora aggiornate
**Descrizione:** Tutti i 12 file di traduzione (`translations/README.*.md`) sono indietro di diverse versioni (v1.10-v1.12). Modifiche da riportare:
- curl come Quick Start primario (one-liner)
- Nuova struttura della sezione Install (curl consigliato, Homebrew alternativa macOS)
- Nomi di sessione invece di percorsi per `--hide`/`--delete`/`--protect` (v1.11.0)
- Nuovi esempi conversazionali: rename, save-as-template, tip, enable/disable tips, update
- Requisiti: "Apple Silicon o Intel" (non solo Apple Silicon)
- Nuova sezione "Altro" con link a FAQ, ISSUES, CHANGELOG
- Le traduzioni di FAQ e ISSUES devono essere create

### Problemi di code review differiti (v1.9.0)
**Severita:** Bassa-Media
**Stato:** Risolto nella v1.10.0 - M3, M4, M9/L8, L3, L9 corretti; L4, L5, L6, L7, M7 affrontati con commenti

### Rinomina / spostamento progetto con preservazione della cronologia
**Severita:** Bassa
**Stato:** Risolto nella v1.10.0 - `--rename OLD NEW` e `--move SRC DEST` implementati

### Copia progetto con cronologia
**Severita:** Bassa
**Stato:** Aperto - funzionalita pianificata, richiede indagine
**Descrizione:** Copiare un progetto includendo la cronologia e la memoria di Claude Code e piu complesso di rinomina/spostamento perche devono essere stabiliti nuovi UUID per la destinazione.
**Approccio proposto:**
1. Creare la nuova directory del progetto (con git init e template opzionali)
2. Avviare e arrestare immediatamente una sessione al suo interno: Claude Code inizializza `~/.claude/projects/-encoded-new-path/` con un UUID fresco e crea una nuova voce homunculus
3. Copiare i file di cronologia `.jsonl` dalla cartella `~/.claude/projects/` sorgente nella cartella di destinazione
4. Copiare il contenuto della cartella `memory/`: puro markdown, nessun UUID incorporato, sicuro da copiare direttamente
5. Copiare le sottodirectory UUID (artefatti task/plan) insieme ai loro file `.jsonl`
6. Per homunculus: copiare `observations.jsonl`, `instincts`, `evolved`, `observations.archive` da `~/.claude/homunculus/projects/<src-uuid>/` nella cartella homunculus della nuova destinazione, mantenendo il nuovo UUID del progetto assegnato nel passaggio 2
**Domande aperte che richiedono test:**
- I file `.jsonl` incorporano il percorso del progetto sorgente nel loro contenuto o metadati? In tal caso, la cronologia copiata farebbe riferimento al vecchio percorso.
- Le sottodirectory UUID sono referenziate per UUID dall'interno dei file `.jsonl`? In tal caso, devono essere copiate con i loro UUID originali, non rimappate.
- Claude Code legge tutti i file `.jsonl` in una cartella di progetto, o solo quello corrispondente all'UUID della sessione attiva?
- Cosa contengono `~/.claude/homunculus/projects/<uuid>/evolved` e `instincts`: sono derivati/calcolati o significativi per l'utente? Vale la pena preservarli in una copia?
- Ci sono altri riferimenti interni che si romperebbero con una copia naive dei file?
**Prerequisito:** Testare quanto sopra prima di implementare per evitare di rilasciare un comando di copia che produce cronologia sottilmente rotta.

### Consiglio del giorno
**Severita:** Bassa
**Stato:** Risolto nella v1.10.0 - `--tip`, `TIP_OF_DAY`, `TIP_MODE`, gate giornaliero, consegna all'avvio della sessione implementati

### Timestamp della risposta
**Severita:** Bassa
**Stato:** Aperto - da discutere prima di implementare
**Descrizione:** Variabile di configurazione opzionale (`REPLY_TIMESTAMP=false` predefinito) che inietta un'istruzione nel system prompt dicendo a Claude di iniziare ogni risposta con data e ora correnti tramite `date '+%Y-%m-%d %H:%M'`.
**Compromesso:** Richiede una chiamata al tool bash all'inizio di ogni risposta (piccolo overhead). Alternativa: iniettare l'ora di inizio sessione nel prompt (gratuito, ma si disallinea nelle sessioni lunghe).
**Nota:** L'istruzione nel CLAUDE.md per progetto (come nel template analitico) e la versione piu leggera: solo sui progetti che la vogliono. La variabile di configurazione la rende globale.

### Video demo
**Severita:** Bassa
**Stato:** Aperto - asset pianificato
**Descrizione:** Una registrazione dello schermo che mostra claude-mux dall'installazione tramite curl attraverso i comandi comuni e interessanti, con terminale e Remote Control visibili simultaneamente.
**Formato:** Schermo diviso, ripresa singola. Terminale (sessione claude-mux completa) a sinistra, RC su iPhone mirrored tramite QuickTime a destra. Entrambi live allo stesso tempo: lo spettatore vede le azioni in RC immediatamente riflesse nel terminale e viceversa.
**Vedi:** `internal/demo-script.md` per lo schema inquadratura per inquadratura completo.
**Note:**
- L'inquadratura chiave e digitare in RC sul telefono e vedere il terminale rispondere in tempo reale
- Non e necessario editing oltre al taglio: registrazione continua singola
- Hosting su YouTube + embed nel README; utile anche per il lancio su Product Hunt

### Sottomissione a homebrew-core per il listato su brew.sh
**Severita:** Bassa
**Stato:** Futuro - in attesa di adozione
**Descrizione:** claude-mux e attualmente distribuito tramite un tap personale (`pereljon/tap`). Per apparire su brew.sh, deve essere accettato in homebrew-core. Il gate di notorieta di Homebrew richiede tipicamente qualche centinaio di stelle su GitHub prima che un'utilita script shell venga accettata; le sottomissioni con poche stelle vengono chiuse rapidamente.
**Quando pronto:**
- Assicurarsi che la formula passi `brew audit --strict --new`
- Inviare una PR a `Homebrew/homebrew-core` con la formula
- Nota: gli strumenti solo macOS affrontano uno scrutinio piu attento dai revisori; il supporto Linux (vedi sotto) aiuterebbe

### Supporto curl install (macOS + Linux)
**Severita:** Bassa
**Stato:** Risolto nella v1.10.0 - installazione tramite curl implementata, workflow release-assets aggiunto, README aggiornato

### Solo macOS - nessun supporto Linux/systemd
**Severita:** Media
**Stato:** Aperto - parzialmente affrontato (rilevamento percorsi fatto, LaunchAgent/installer restano specifici macOS)
**Descrizione:** Usa il LaunchAgent di macOS (launchd) e strumenti specifici di macOS. Il rilevamento dei percorsi e stato refactorato per usare `command -v` (non codifica piu `/opt/homebrew/bin`), quindi lo script core ora funziona su qualsiasi piattaforma dove tmux e claude sono nel PATH. LaunchAgent e installer restano specifici macOS.
**Rimanente:** unit utente systemd, fallback XDG Autostart, dispatch `uname -s` nell'installer.
**Strategia di pacchettizzazione (v1.10+):**
- installazione curl: fallback universale, funziona ovunque (vedi sopra)
- AUR: basso sforzo, alta visibilita per il pubblico target su Arch/Manjaro
- apt PPA: quando c'e domanda dagli utenti Debian/Ubuntu
- Homebrew su Linux: copre gli utenti che lo hanno gia
- Snap/Flatpak: non vale la pena per uno script bash

### I comandi ! non sono disponibili in Remote Control
**Severita:** Bassa
**Stato:** Chiuso - non fattibile
**Descrizione:** Il passthrough shell `!` di Claude Code e una funzionalita dell'input handler del CLI di Claude Code: intercetta `!command` prima che la shell lo veda. tmux send-keys non puo replicarlo: le sequenze di tasti inviate mentre Claude Code e attivo non vanno da nessuna parte (testato: `!touch test` tramite send-keys non e stato eseguito). Non c'e modo per claude-mux di implementare il bypass `!command` per gli utenti RC.
**Risoluzione:** Aggiunta regola di iniezione per dire a Claude di non suggerire mai `! <command>` agli utenti, poiche gli utenti RC non hanno una shell e gli utenti del terminale possono semplicemente digitarlo da soli.

---

## Milestone v2.0

Cambiamenti architetturali abbastanza significativi da giustificare un bump di versione major. Non pianificato: raccolti qui per non perderli.

### Separazione della directory dati
Spostare i dati statici (consigli, template predefiniti, possibilmente output comandi/guida) fuori dallo script e in una directory dati appropriata per la piattaforma. Lo script risolverebbe `DATA_DIR` all'avvio relativamente alla posizione del binario, con fallback incorporati per le installazioni a file singolo.

- Homebrew (Apple Silicon): `/opt/homebrew/share/claude-mux/`
- Homebrew (Intel): `/usr/local/share/claude-mux/`
- Linux: `/usr/local/share/claude-mux/` o `$XDG_DATA_DIRS`
- Installazione manuale: fallback ai default incorporati (le installazioni a file singolo continuano a funzionare)

Trigger: quando i dati incorporati (consigli, template predefiniti) crescono abbastanza da rendere lo script difficile da leggere, o quando i template predefiniti devono essere distribuiti tramite brew indipendentemente dalle release dello script.

### Riconsiderazione del linguaggio / runtime
Lo script bash monolitico e la scelta giusta allo scope attuale. Se claude-mux cresce significativamente (operazioni di rinomina/spostamento/copia dei progetti, un layer relay, pacchettizzazione cross-platform, una directory dati), bash inizia a fare resistenza. A quel punto, riscrivere il core di gestione delle sessioni in Go o un altro linguaggio tipizzato (con bash come thin CLI wrapper) vale la pena di essere valutato.

---

## Risolti

### Claude ignora l'iniezione e dichiara di non poter eseguire comandi slash
**Risolto in:** v1.2.0 (iniezione aggiornata)
**Fix:** Aggiunta regola esplicita all'iniezione: "You CAN send slash commands (`/model`, `/compact`, `/clear`, etc.) to this session via the `-s` command. Never tell the user you cannot change models or run slash commands." L'addestramento base di Claude lo inclina a credere di non poter controllare il proprio modello/impostazioni; la regola esplicita sovrascrive questo in pratica.

### Comandi multipli restituiscono exit code 1 nonostante il successo
**Risolto in:** v1.2.0 (restart), v1.3.0 (tutti i comandi)
**Fix:** Aggiunto `exit 0` esplicito dopo ogni percorso di dispatch nel case statement. L'ultimo comando in una funzione puo far trapelare un exit code non-zero da test interni o chiamate grep.

### --dry-run fornisce output fuorviante per --restart
**Risolto in:** v1.2.0 (commit a10c0c2)
**Fix:** Il dry-run ora mostra "Would restart session" invece di simulare il kill e poi controllare lo stato reale.

### Il rilevamento delle sessioni fallisce con pgrep su macOS
**Risolto in:** commit e1b11b5
**Fix:** Sostituito `pgrep -P` con `ps -eo` + `awk` per un rilevamento affidabile dei processi figli.

### La variabile $TMUX sovrascriveva la variabile d'ambiente di tmux
**Risolto in:** commit 02a2e82
**Fix:** Rinominata in `$TMUX_BIN`.

### Incompatibilita Bash 3.2 (declare -A)
**Risolto in:** commit 575eac1
**Fix:** Sostituiti gli array associativi con rilevamento delle collisioni basato su stringhe.

---

## Riferimento: struttura della cartella ~/.claude

Documentato qui perche diverse funzionalita pianificate (rinomina, spostamento, copia, pulizia) devono interagire correttamente con questa struttura. Non esaustivo: copre le parti rilevanti per claude-mux.

### Cronologia e memoria dei progetti: `~/.claude/projects/`

Una sottodirectory per ogni directory di lavoro in cui Claude Code e stato utilizzato. Denominata codificando il percorso assoluto: `/` diventa `-`, spazi e caratteri speciali diventano `-`. Lossy ma leggibile.

Contenuto di ogni cartella di progetto:
- `<uuid>.jsonl` - trascritto completo della conversazione per quella sessione. Un file per conversazione.
- `<uuid>/` - sottodirectory di artefatti associati a una conversazione (task, piani). L'UUID corrisponde al file `.jsonl`.
- `memory/` - file di memoria persistente cross-sessione (markdown con frontmatter). Presente solo se la memoria e stata scritta per il progetto.

Il collegamento tra una directory di lavoro e la sua cronologia e puramente il nome della cartella codificato. Rinominare o spostare la directory del progetto senza rinominare questa cartella fa si che Claude Code riparta da zero senza cronologia.

**Regola di codifica:** percorso assoluto con ogni `/`, spazio e carattere speciale sostituito da `-`. Il `/` iniziale diventa un `-` iniziale. La codifica e lossy: caratteri speciali consecutivi e spazi adiacenti agli slash diventano entrambi `-`, quindi l'originale non puo sempre essere ricostruito perfettamente.

### Registro di osservabilita parallela: `~/.claude/homunculus/`

Un sistema separato che traccia gli eventi a livello di tool per progetto. Non fa parte della cronologia core di Claude Code: sembra essere un layer di monitoraggio/apprendimento.

- `projects.json` - registro di tutti i progetti conosciuti, indicizzato per UUID esadecimale breve (`d6b3aef60967`, ecc.). Ogni voce ha: `id`, `name`, `root` (percorso assoluto), `remote`, `created_at`, `last_seen`.
- `projects/<uuid>/project.json` - metadati per progetto (stessi campi della voce nel registro).
- `projects/<uuid>/observations.jsonl` - eventi `tool_start`/`tool_complete` con timestamp: nome tool, UUID sessione, nome/id progetto, frammenti input/output.
- `projects/<uuid>/instincts` - pattern derivati (contenuto sconosciuto, probabilmente calcolato).
- `projects/<uuid>/evolved` - stato evoluto/appreso (contenuto sconosciuto).
- `projects/<uuid>/observations.archive` - osservazioni piu vecchie archiviate.

**Differenza chiave da `~/.claude/projects/`:** usa UUID esadecimali brevi come chiavi, non percorsi codificati. Il campo `root` contiene il percorso assoluto. Qualsiasi operazione che cambia il percorso di un progetto (rinomina, spostamento) deve aggiornare `root` sia in `projects.json` che in `projects/<uuid>/project.json`.

### Configurazione globale: `~/.claude/settings.json`

File di impostazioni principale di Claude Code. Backup rolling scritti in `~/.claude/backups/` come `~/.claude.json.backup.<timestamp>`: diversi per ora durante l'uso attivo. claude-mux non deve toccare questo file.

### Agenti, skill, comandi globali

- `~/.claude/agents/` - definizioni di sottoacenti (file `.md`, ~38). Globali, non per progetto.
- `~/.claude/skills/` - directory delle skill (~125). Globali, non per progetto.
- `~/.claude/commands/` - definizioni dei comandi slash (file `.md`, ~72). Globali, non per progetto.
- `~/.claude/hooks/hooks.json` - definizioni degli hook. Globali. claude-mux non deve toccarli.

### Potenziali funzionalita future

| Funzionalita | Cosa toccare |
|--------------|-------------|
| `--copy` | Creare la directory; avviare+fermare una sessione per inizializzare entrambi i registri; copiare `.jsonl` + `memory/` + sottodirectory UUID; copiare i file di osservazione homunculus nella nuova cartella UUID |
| Pulizia `--delete` | Gia sposta la cartella del progetto nel cestino. Opzionalmente: rimuovere la cartella `~/.claude/projects/` codificata orfana e la voce `~/.claude/homunculus/` |
| Avviso dimensione cronologia | Avvisare quando i file `.jsonl` di un progetto superano una soglia (il trascritto principale di claude-mux ha raggiunto 107MB in una singola sessione lunga) |
