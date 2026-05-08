# claude-mux - Multiplexer di Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Italiano** · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Sessioni persistenti di Claude Code per tutti i tuoi progetti, accessibili ovunque tramite l'app mobile di Claude. ***Gestito da Claude!***

## Perche

Remote Control promette Claude Code da qualsiasi luogo, ma senza gestione delle sessioni e un'interfaccia di seconda classe anche da Claude Desktop:

- Le sessioni terminano quando chiudi il terminale e il contesto della conversazione non riprende automaticamente
- Non c'e una base operativa: nulla e in esecuzione quando prendi il telefono, a meno che tu non abbia lasciato qualcosa aperto
- Se una sessione non e in esecuzione, Remote Control e inutile: non puoi raggiungere un progetto ne avviarne uno
- Anche in una sessione RC attiva, i comandi slash non funzionano: nessun cambio di modello, compattazione o modifica della modalita di permessi
- Avviare un nuovo progetto richiede di creare manualmente una directory, inizializzare git, scrivere un CLAUDE.md, impostare una modalita di permessi e scegliere un modello: niente di tutto cio e possibile da RC
- Gestire piu progetti significa piu avvii manuali del terminale senza panoramica di cosa e in esecuzione o in che stato si trovi

claude-mux risolve tutto questo. Avvolge Claude Code in tmux cosi le sessioni persistono, inietta un system prompt cosi Claude puo gestire le proprie sessioni e instrada i comandi slash attraverso tmux cosi funzionano su Remote Control. Una volta avviata una sessione, gestisci tutto parlando con Claude: dal terminale o dall'app mobile.

## Avvio rapido

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Poi avvia una sessione:

```bash
cd ~/percorso/del/tuo/progetto
claude-mux
```

Oppure:

```bash
claude-mux ~/percorso/del/tuo/progetto
```

Tutto qui. Sei in una sessione Claude persistente, consapevole del proprio contesto, con Remote Control abilitato. Da qui, tutto e conversazionale.

## Parlare con Claude

Questo e il modo in cui si usa claude-mux quotidianamente. Ogni sessione riceve comandi iniettati cosi Claude puo gestire le sessioni, cambiare modello, inviare comandi slash e creare nuovi progetti, tutto dall'interno della conversazione. Non serve ricordare i flag CLI.

```
Tu: "status"
Claude: riporta nome sessione, modello, modalita permessi, utilizzo contesto ed elenca tutte le sessioni

Tu: "elenco sessioni attive"
Claude: mostra tutte le sessioni in esecuzione con il loro stato

Tu: "avvia una sessione per il mio progetto api-server"
Claude: avvia una sessione in ~/Claude/work/api-server

Tu: "crea un nuovo progetto chiamato mobile-app usando il template web"
Claude: crea la directory del progetto, inizializza git, applica il template, avvia una sessione

Tu: "passa questa sessione a Haiku"
Claude: invia /model haiku a se stesso tramite tmux

Tu: "compatta la sessione api-server"
Claude: invia /compact alla sessione api-server

Tu: "riavvia la sessione web-dashboard"
Claude: arresta e rilancia la sessione, preservando il contesto della conversazione

Tu: "passa la sessione api-server in plan mode"
Claude: riavvia la sessione con la modalita di permessi plan

Tu: "passa questa sessione in yolo mode"
Claude: passa a bypassPermissions tramite Shift+Tab, senza bisogno di riavvio

Tu: "in che modalita e questa sessione"
Claude: riporta la modalita di permessi corrente (default, acceptEdits, plan, bypassPermissions)

Tu: "passa questa sessione a Opus"
Claude: invia /model opus a se stesso tramite tmux

Tu: "pulisci questa sessione"
Claude: invia /clear a se stesso, resettando la conversazione

Tu: "nascondi questo progetto"
Claude: scrive .claudemux-ignore cosi il progetto e escluso dai listati -L

Tu: "proteggi questa sessione"
Claude: scrive .claudemux-protected e imposta il marcatore tmux; lo shutdown ora richiede --force

Tu: "questa sessione e protetta"
Claude: controlla .claudemux-protected nella cartella del progetto e risponde

Tu: "elimina il progetto old-prototype"
Claude: conferma in chat, poi sposta la cartella del progetto nel cestino di sistema

Tu: "rinomina questo progetto in my-new-name"
Claude: arresta la sessione, rinomina la cartella, migra la cronologia delle conversazioni, riavvia

Tu: "salva questo come template con nome web"
Claude: copia CLAUDE.md in ~/.claude-mux/templates/web.md

Tu: "tip"
Claude: stampa un consiglio, lo stesso per tutto il giorno oppure casuale se TIP_MODE=random e impostato

Tu: "enable tips" / "disable tips"
Claude: registra o rimuove l'hook tip-of-the-day su tutti i progetti

Tu: "aggiorna claude-mux"
Claude: avvisa che tutte le sessioni verranno riavviate, chiede conferma, poi aggiorna e riavvia

Tu: "arresta tutte le sessioni"
Claude: esce in modo controllato da tutte le sessioni gestite

Tu: "help"
Claude: stampa l'elenco completo dei comandi conversazionali
```

Questi comandi funzionano in qualsiasi lingua. Se scrivi l'equivalente in spagnolo, giapponese, ebraico o qualsiasi altra lingua, Claude ne deduce l'intento ed esegue il comando corrispondente.

Digita `help` dentro qualsiasi sessione per vedere l'elenco completo dei comandi.

### Sessione home

La sessione home e una sessione di uso generale che vive nella directory di base (`~/Claude` per impostazione predefinita). Si avvia automaticamente al login quando `LAUNCHAGENT_MODE=home`, fornendo una sessione Claude sempre pronta accessibile dal telefono. Usala per gestire tutte le altre sessioni senza dover avviare prima quelle specifiche del progetto.

La sessione home e **protetta** per impostazione predefinita: `--shutdown home` rifiuta di arrestarla senza `--force`. La protezione e attivata dal marcatore `.claudemux-protected` in `$BASE_DIR`, creato da `claude-mux --install`. Le sessioni protette mostrano `protected` nella colonna di stato; la sessione chiamante e contrassegnata con `>` nella colonna del nome.

## Cosa fa

Dietro le quinte, claude-mux gestisce:

- **Sessioni tmux persistenti** con Remote Control abilitato, cosi ogni sessione e accessibile dall'app mobile di Claude
- **Ripresa delle conversazioni**: riprende l'ultima conversazione (`claude -c`) al riavvio, preservando il contesto
- **Iniezione del system prompt**: ogni sessione riceve comandi per l'autogestione, l'instradamento dei comandi slash e la consapevolezza degli account SSH
- **Template CLAUDE.md**: mantieni file di template (es. `web.md`, `python.md`) in `~/.claude-mux/templates/` e applicali ai nuovi progetti
- **Supporto multi-CLI-coder**: crea `AGENTS.md` e `GEMINI.md` come symlink a `CLAUDE.md` cosi Codex CLI, Gemini CLI e altri strumenti condividono le stesse istruzioni
- **Permessi auto-approvati**: aggiunge claude-mux alla allow list di ogni progetto cosi Claude puo eseguire i comandi di sessione senza richiedere conferma
- **Migrazione dei processi orfani**: se Claude e gia in esecuzione fuori da tmux, lo migra in una sessione gestita
- **Qualita della vita in tmux**: supporto del mouse, scrollback da 50k, clipboard, 256 colori, tasti estesi, monitoraggio dell'attivita, titoli delle tab

> **Nota:** questo e diverso da `claude --worktree --tmux`, che crea una sessione tmux per un worktree git isolato. claude-mux gestisce sessioni persistenti per le directory effettive dei tuoi progetti, con Remote Control e iniezione del system prompt.

## Requisiti

- macOS (Apple Silicon o Intel)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## Installazione

### curl (consigliato)

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Scarica il binario, lo installa in `~/bin`, lo aggiunge al `PATH` e avvia la configurazione interattiva. Funziona su macOS e Linux (Linux: il passaggio LaunchAgent viene saltato).

Per aggiornare:

```bash
claude-mux --update     # funziona dall'interno di qualsiasi sessione o dal terminale
```

### Homebrew (alternativa macOS)

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Per aggiornare:

```bash
brew upgrade claude-mux
```

### Manuale

```bash
./install.sh
```

`install.sh` copia il binario in `~/bin` e lo aggiunge al `PATH`. Dopo, esegui:

```bash
claude-mux --install
```

La configurazione interattiva chiede dove risiedono i tuoi progetti Claude, se avviare una sessione home al login e quale modello usare. Crea `~/.claude-mux/config` e installa il LaunchAgent.

Usa `--non-interactive` per saltare i prompt e accettare i valori predefiniti.

Opzioni:

```bash
claude-mux --install --non-interactive                     # salta i prompt, usa i predefiniti
claude-mux --install --base-dir ~/work/claude              # usa una directory di base diversa
claude-mux --install --launchagent-mode none               # disabilita il comportamento del LaunchAgent
claude-mux --install --home-model haiku                    # usa Haiku per la sessione home
claude-mux --install --no-launchagent                      # salta completamente l'installazione del LaunchAgent
```

Il LaunchAgent esegue `claude-mux --autolaunch` al login con un ritardo di avvio di 45 secondi per permettere ai servizi di sistema di inizializzarsi.

## Stati delle sessioni

| Stato | Significato |
|-------|-------------|
| `running` | la sessione tmux esiste e Claude e in esecuzione |
| `protected` | come `running`, ma la sessione e protetta: `--shutdown` richiede `--force` per fermarla |
| `stopped` | la sessione tmux esiste ma Claude e uscito |
| `idle` | esiste un progetto `.claude/` sotto `BASE_DIR` ma nessuna sessione tmux di claude-mux e in esecuzione (mostrato solo con `-L`) |

Un prefisso `>` sul nome della sessione (es. `> home`) indica la sessione che ha eseguito il comando di lista.

Eseguire `claude-mux` in una directory che ha gia una sessione in esecuzione si collega ad essa. Piu terminali possono collegarsi alla stessa sessione (comportamento standard di tmux).

## Marcatori di progetto

Lo stato per progetto e memorizzato in file marcatori nella radice del progetto, non in una configurazione centrale. I marcatori usano il prefisso `.claudemux-` e vengono aggiunti automaticamente al `.gitignore` quando creati in un progetto tracciato da git.

| Marcatore | Significato | CLI |
|-----------|-------------|-----|
| `.claudemux-protected` | La sessione e protetta all'avvio: `--shutdown` richiede `--force` | `--protect` / `--unprotect` |
| `.claudemux-ignore` | Il progetto e nascosto dai listati di `claude-mux -L` | `--hide` / `--show` |

```bash
claude-mux --hide                    # nascondere il progetto della sessione corrente dai listati -L
claude-mux --hide my-project         # nascondere il progetto di una sessione specifica
claude-mux --show my-project         # mostrare nuovamente un progetto
claude-mux --protect                 # proteggere questa sessione da arresti accidentali
claude-mux --unprotect               # rimuovere la protezione
claude-mux -L --hidden               # elencare solo i progetti nascosti
claude-mux --delete my-project       # spostare la cartella del progetto nel cestino di sistema (macOS)
```

I marcatori seguono la cartella del progetto durante rinominazioni e spostamenti. Un unico pattern `.gitignore` (`.claudemux-*`) copre tutti i marcatori attuali e futuri.

## Configurazione

`~/.claude-mux/config` viene creato da `claude-mux --install` (o alla prima esecuzione di qualsiasi comando se non esiste alcuna config). Modificalo per sovrascrivere qualunque valore predefinito: lo script non deve mai essere modificato direttamente.

| Variabile | Predefinito | Descrizione |
|-----------|-------------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Directory radice da scansionare per i progetti Claude (directory contenenti `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Directory per il file `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Imposta `permissions.defaultMode` di Claude in ogni progetto. Valori validi: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Imposta a `""` per disabilitare. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Quando `true`, le sessioni Claude possono inviare comandi slash ad altre sessioni: utile per l'orchestrazione multi-agente |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Directory contenente i file di template CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | Template predefinito applicato ai nuovi progetti (`-n`). Imposta a `""` per disabilitare. |
| `SLEEP_BETWEEN` | `5` | Secondi tra i lanci di sessione quando si usa `-a`. Aumenta se la registrazione RC fallisce. |
| `HOME_SESSION_MODEL` | `""` | Modello per la sessione home. Valori validi: `sonnet`, `haiku`, `opus`. Vuoto eredita il predefinito di Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Elenco di file separati da spazi da creare come symlink a `CLAUDE.md` per altri strumenti AI CLI. Imposta a `""` per disabilitare. |
| `LAUNCHAGENT_MODE` | `home` | Comportamento del LaunchAgent al login: `none` (non fare nulla) o `home` (avvia la sessione home protetta). Il valore legacy `LAUNCHAGENT_ENABLED=true` viene trattato come `home`. |

**Opzioni della sessione tmux** (tutte configurabili, tutte abilitate per impostazione predefinita):

| Variabile | Predefinito | Descrizione |
|-----------|-------------|-------------|
| `TMUX_MOUSE` | `true` | Supporto del mouse: scroll, selezione, ridimensionamento dei pannelli |
| `TMUX_HISTORY_LIMIT` | `50000` | Dimensione del buffer di scrollback in righe (il predefinito di tmux e 2000) |
| `TMUX_CLIPBOARD` | `true` | Integrazione con la clipboard di sistema tramite OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Tipo di terminale per il rendering corretto dei colori |
| `TMUX_EXTENDED_KEYS` | `true` | Sequenze di tasti estese, incluso Shift+Enter (richiede tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | Ritardo del tasto escape in millisecondi (il predefinito di tmux e 500) |
| `TMUX_TITLE_FORMAT` | `#S` | Formato del titolo del terminale/tab (`#S` = nome sessione, `""` per disabilitare) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Notifica quando si verifica attivita in altre sessioni |

## Struttura delle directory

I progetti vengono individuati dalla presenza di una directory `.claude/`, a qualsiasi profondita:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ ha .claude/ - gestito
│   │   └── .claude/
│   ├── project-b/          # ✓ ha .claude/ - gestito
│   │   └── .claude/
│   └── -archived/          # ✗ escluso (inizia con -)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ ha .claude/ - gestito
│   │   └── .claude/
│   ├── .hidden/            # ✗ escluso (directory nascosta)
│   │   └── .claude/
│   └── project-d/          # ✗ nessun .claude/ - non e un progetto Claude
├── deep/nested/project-e/  # ✓ ha .claude/ - trovato a qualsiasi profondita
│   └── .claude/
└── ignored-project/        # ✗ escluso (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

I nomi delle sessioni derivano dai nomi delle directory: gli spazi diventano trattini, i caratteri non alfanumerici (eccetto i trattini) vengono sostituiti, e i trattini iniziali/finali vengono rimossi. Le directory il cui nome sanitizzato risulta vuoto vengono saltate con un avviso nel log.

## Session System Prompt

Ogni sessione Claude viene avviata con `--append-system-prompt` contenente il contesto sul proprio ambiente:

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

La sessione home riceve contesto aggiuntivo: una descrizione del suo ruolo, piu trigger di autogestione per leggere/modificare config e template. Quando `ALLOW_CROSS_SESSION_CONTROL=true`, il comando di invio puo indirizzare qualsiasi sessione, non solo se stessa. Il percorso e il path assoluto dello script al momento del lancio, cosi le sessioni non dipendono da `PATH`.

## Riferimento CLI

Raramente serve usarli direttamente: Claude li esegue per te dall'interno delle sessioni. Sono disponibili per scripting, automazione o quando non sei dentro una sessione.

```bash
# Avvio e collegamento
claude-mux                       # avvia Claude nella directory corrente e si collega
claude-mux ~/progetti/mia-app    # avvia Claude in una directory e si collega
claude-mux -d ~/progetti/mia-app # come sopra (forma esplicita)
claude-mux -t my-app             # collegati a una sessione tmux esistente

# Creazione di nuovi progetti
claude-mux -n ~/progetti/app     # crea un nuovo progetto Claude e si collega
claude-mux -n ~/nuovo/percorso/app -p  # come sopra, creando la directory e i parent
claude-mux -n ~/app --template web        # nuovo progetto con un template CLAUDE.md specifico
claude-mux -n ~/app --no-multi-coder      # nuovo progetto senza symlink AGENTS.md/GEMINI.md

# Gestione delle sessioni
claude-mux -l                    # elenca le sessioni per stato (active, running, stopped)
claude-mux -L                    # elenca tutti i progetti (active + idle)
claude-mux -L --hidden           # elenca solo i progetti nascosti
claude-mux -s my-app '/model sonnet'      # invia un comando slash a una sessione
claude-mux --shutdown my-app              # arresta una sessione specifica
claude-mux --shutdown                     # arresta tutte le sessioni gestite
claude-mux --shutdown home --force        # arresta la sessione home protetta
claude-mux --restart my-app              # riavvia una sessione specifica
claude-mux --restart                     # riavvia tutte le sessioni in esecuzione
claude-mux --permission-mode plan my-app  # riavvia la sessione in plan mode
claude-mux -a                    # avvia tutte le sessioni gestite sotto BASE_DIR

# Marcatori di progetto (tutti i comandi usano nomi di sessione, non percorsi)
claude-mux --hide                # nascondere il progetto della sessione corrente dai listati -L
claude-mux --hide my-project     # nascondere un progetto specifico per nome di sessione
claude-mux --show my-project     # mostrare nuovamente un progetto
claude-mux --protect             # proteggere questa sessione da arresti accidentali
claude-mux --unprotect           # rimuovere la protezione
claude-mux --delete my-project           # spostare la cartella del progetto nel cestino di sistema (macOS)
claude-mux --delete my-project --yes     # come sopra, senza prompt di conferma
claude-mux --rename my-project new-name  # rinominare la directory del progetto
claude-mux --move my-project ~/Claude/work  # spostare il progetto in un nuovo parent

# Altro
claude-mux --list-templates      # mostra i template CLAUDE.md disponibili
claude-mux --guide               # mostra i comandi conversazionali per l'uso dentro le sessioni
claude-mux --commands            # mostra il riferimento CLI completo
claude-mux --config-help         # mostra tutte le opzioni di configurazione con valori predefiniti e descrizioni
claude-mux --install             # configurazione interattiva: config + LaunchAgent
claude-mux --update              # aggiorna all'ultima versione
claude-mux --dry-run             # anteprima delle azioni senza eseguirle
claude-mux --version             # stampa la versione
claude-mux --help                # mostra tutte le opzioni

# Osserva il log
tail -f ~/Library/Logs/claude-mux.log
```

Quando viene eseguito dal terminale, l'output e duplicato su stdout in tempo reale. Quando viene eseguito tramite LaunchAgent, l'output va solo nel file di log.

## Risoluzione dei problemi

### Le sessioni mostrano "Not logged in · Run /login"

Questo accade al primo avvio se il keychain di macOS e bloccato (comune quando lo script viene eseguito prima che il keychain venga sbloccato dopo il login). Soluzione:

```bash
# Sblocca il keychain in un terminale normale
security unlock-keychain

# Poi completa l'autenticazione in una qualsiasi sessione in esecuzione
claude-mux -t <any-session>
# Esegui /login e completa il flusso nel browser
```

Dopo aver completato l'autenticazione una volta, termina e rilancia tutte le sessioni: prenderanno le credenziali memorizzate automaticamente.

### Le sessioni non appaiono in Claude Code Remote

Le sessioni devono essere autenticate (non devono mostrare "Not logged in"). Dopo un avvio pulito e autenticato, dovrebbero apparire nella lista RC entro pochi secondi.

### Input multi-riga in tmux

Il comando `/terminal-setup` non puo essere eseguito dentro tmux. claude-mux abilita `extended-keys` di tmux per impostazione predefinita (`TMUX_EXTENDED_KEYS=true`), che supporta Shift+Enter nella maggior parte dei terminali moderni. Se Shift+Enter non funziona, usa `\` + Return per inserire ritorni a capo nel prompt.

### "Session ready!" all'avvio della sessione

Quando una sessione viene avviata o riavviata, claude-mux invia automaticamente un messaggio `Ready?` dopo che Claude ha terminato il caricamento. L'iniezione dice a Claude di rispondere con "Session ready!" e nient'altro. Questo conferma che la sessione e attiva e l'iniezione funziona.

### Comandi slash su Remote Control

I comandi slash (es. `/model`, `/clear`) [non sono supportati nativamente](https://github.com/anthropics/claude-code/issues/30674) nelle sessioni RC. claude-mux aggira il problema: ogni sessione riceve `claude-mux -s` iniettato cosi Claude puo inviare comandi slash a se stesso tramite tmux.

## Log

- `~/Library/Logs/claude-mux.log` - tutte le azioni dello script con timestamp UTC (configurabile tramite `LOG_DIR`)

Per debug a basso livello del LaunchAgent, usa Console.app o `log show`.

## Altro

- [FAQ](FAQ.it.md) - domande frequenti su claude-mux
- [Problemi noti](ISSUES.it.md) - bug aperti, funzionalita pianificate e problemi risolti
- [Changelog](../CHANGELOG.md) - cosa e cambiato per ogni release
