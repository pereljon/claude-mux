# claude-mux - Multiplexer di Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Italiano** · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

> Nota: questa traduzione potrebbe essere in ritardo rispetto al README inglese. Consulta [README.md](../README.md) per la versione canonica.

Sessioni persistenti di Claude Code per tutti i tuoi progetti, accessibili da qualsiasi luogo tramite l'app mobile di Claude.

## Perché

Lavorare con Claude Code su più progetti ha delle frizioni:

- Le sessioni muoiono quando si chiude il terminale
- Le sessioni Remote Control non possono eseguire comandi slash come `/model` o `/compact`
- Non è facile avviare una sessione per un progetto non ancora in esecuzione
- Cambiare modello, modalità di permessi o compattare il contesto dal telefono non è possibile

claude-mux risolve tutto questo. Avvolge Claude Code in tmux in modo che le sessioni persistano, inietta un system prompt in modo che Claude possa gestire le proprie sessioni, e instrada i comandi slash attraverso tmux in modo che funzionino su Remote Control. Una volta avviata una sessione, si gestisce tutto parlando con Claude, dal terminale o dall'app mobile.

## Avvio rapido

```bash
./install.sh
```

```bash
claude-mux ~/percorso/al/tuo/progetto
```

Tutto qui. Ti trovi in una sessione Claude persistente, consapevole del proprio contesto, con Remote Control abilitato. Da qui, tutto è conversazionale.

## Parlare con Claude

Questo è il modo in cui si usa claude-mux quotidianamente. Ogni sessione riceve comandi iniettati in modo che Claude possa gestire le sessioni, cambiare modello, inviare comandi slash e creare nuovi progetti, tutto dall'interno della conversazione. Non è necessario ricordare i flag CLI.

```
Tu: "status"
Claude: riporta nome sessione, modello, modalità permessi, utilizzo contesto ed elenca tutte le sessioni

Tu: "elenco sessioni attive"
Claude: mostra tutte le sessioni in esecuzione con il loro stato

Tu: "avvia una sessione per il mio progetto api-server"
Claude: avvia una sessione in ~/Claude/work/api-server

Tu: "crea un nuovo progetto chiamato mobile-app usando il template web"
Claude: crea la directory del progetto, inizializza git, applica il template, avvia una sessione

Tu: "passa questa sessione a Haiku"
Claude: invia /model haiku a sé stesso tramite tmux

Tu: "compatta la sessione api-server"
Claude: invia /compact alla sessione api-server

Tu: "riavvia la sessione web-dashboard"
Claude: arresta e rilancia la sessione, preservando il contesto della conversazione

Tu: "passa la sessione api-server in plan mode"
Claude: riavvia la sessione con la modalità di permessi plan

Tu: "arresta tutte le sessioni"
Claude: esce in modo controllato da tutte le sessioni gestite

Tu: "help"
Claude: stampa l'elenco completo dei comandi conversazionali
```

Questi comandi funzionano in qualsiasi lingua. Se scrivi l'equivalente in spagnolo, giapponese, ebraico o qualsiasi altra lingua, Claude ne deduce l'intento ed esegue il comando corrispondente.

Digita `help` dentro qualsiasi sessione per vedere l'elenco completo dei comandi.

### Sessione home

La sessione home è una sessione di uso generale che vive nella directory di base (`~/Claude` per impostazione predefinita). Si avvia automaticamente al login quando `LAUNCHAGENT_MODE=home`, fornendo una sessione Claude sempre pronta accessibile dal telefono. Usala per gestire tutte le altre sessioni senza dover avviare prima quelle specifiche del progetto.

La sessione home è sempre **protetta**: `--shutdown home` rifiuta di arrestarla senza `--force`. Le sessioni protette sono contrassegnate con `*` nell'output di stato (es. `active*`).

## Cosa fa

Dietro le quinte, claude-mux gestisce:

- **Sessioni tmux persistenti** con Remote Control abilitato, in modo che ogni sessione sia accessibile dall'app mobile di Claude
- **Ripresa delle conversazioni** - riprende l'ultima conversazione (`claude -c`) al riavvio, preservando il contesto
- **Iniezione del system prompt** - ogni sessione riceve comandi per l'autogestione, l'instradamento dei comandi slash e la consapevolezza degli account SSH
- **Template CLAUDE.md** - mantieni file di template (es. `web.md`, `python.md`) in `~/.claude-mux/templates/` e applicali ai nuovi progetti
- **Supporto multi-CLI-coder** - crea `AGENTS.md` e `GEMINI.md` come symlink a `CLAUDE.md` in modo che Codex CLI, Gemini CLI e altri strumenti condividano le stesse istruzioni
- **Permessi auto-approvati** - aggiunge claude-mux alla allow list di ogni progetto in modo che Claude possa eseguire i comandi di sessione senza richiedere conferma
- **Migrazione dei processi orfani** - se Claude è già in esecuzione fuori da tmux, lo migra in una sessione gestita
- **Qualita della vita in tmux** - supporto del mouse, scrollback da 50k, clipboard, 256 colori, tasti estesi, monitoraggio dell'attività, titoli delle tab

> **Nota:** questo è diverso da `claude --worktree --tmux`, che crea una sessione tmux per un worktree git isolato. claude-mux gestisce sessioni persistenti per le directory effettive dei tuoi progetti, con Remote Control e iniezione del system prompt.

## Requisiti

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## Installazione

```bash
./install.sh
```

L'installer interattivo chiede dove risiedono i tuoi progetti Claude, se avviare una sessione home al login e quale modello usare. Installa `claude-mux` in `~/bin`, crea `~/.claude-mux/config` e configura il LaunchAgent.

Usa `--non-interactive` per saltare i prompt e accettare i valori predefiniti.

Opzioni:

```bash
./install.sh --non-interactive                     # salta i prompt, usa i predefiniti
./install.sh --base-dir ~/work/claude              # usa una directory di base diversa
./install.sh --launchagent-mode none               # disabilita il comportamento del LaunchAgent
./install.sh --home-model haiku                    # usa Haiku per la sessione home
./install.sh --no-launchagent                      # salta completamente l'installazione del LaunchAgent
```

Il LaunchAgent esegue `claude-mux --autolaunch` al login con un ritardo di avvio di 45 secondi per permettere ai servizi di sistema di inizializzarsi.

## Stati delle sessioni

| Stato | Significato |
|-------|-------------|
| `active` | la sessione tmux esiste, Claude è in esecuzione, e un client tmux locale è collegato |
| `running` | la sessione tmux esiste e Claude è in esecuzione (nessun client locale collegato) |
| `stopped` | la sessione tmux esiste ma Claude è uscito |
| `idle` | esiste un progetto `.claude/` sotto `BASE_DIR` ma nessuna sessione tmux di claude-mux in esecuzione (mostrato solo con `-L`) |

Un `*` finale su qualsiasi stato indica che la sessione è protetta e richiede `--force` per essere arrestata (es. `active*`, `running*`). La sessione home è sempre protetta.

Eseguire `claude-mux` in una directory che ha già una sessione in esecuzione si collega ad essa. Più terminali possono collegarsi alla stessa sessione (comportamento standard di tmux).

## Configurazione

Alla prima esecuzione, `~/.claude-mux/config` viene creato automaticamente con tutte le impostazioni commentate. Modificalo per sovrascrivere qualunque valore predefinito: lo script non deve mai essere modificato direttamente.

| Variabile | Predefinito | Descrizione |
|-----------|-------------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Directory radice da scansionare per i progetti Claude (directory contenenti `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Directory per il file `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Imposta `permissions.defaultMode` di Claude in ogni progetto. Valori validi: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Imposta a `""` per disabilitare. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Quando `true`, le sessioni Claude possono inviare comandi slash ad altre sessioni: utile per l'orchestrazione multi-agente |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Directory contenente i file di template CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | Template predefinito applicato ai nuovi progetti (`-n`). Imposta a `""` per disabilitare. |
| `SLEEP_BETWEEN` | `5` | Secondi tra i lanci di sessioni quando si usa `-a`. Aumenta se la registrazione RC fallisce. |
| `HOME_SESSION_MODEL` | `""` | Modello per la sessione home. Valori validi: `sonnet`, `haiku`, `opus`. Vuoto eredita il predefinito di Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Elenco di file separati da spazi da creare come symlink a `CLAUDE.md` per altri strumenti AI CLI. Imposta a `""` per disabilitare. |
| `LAUNCHAGENT_MODE` | `home` | Comportamento del LaunchAgent al login: `none` (non fare nulla) o `home` (avvia la sessione home protetta). Il valore legacy `LAUNCHAGENT_ENABLED=true` viene trattato come `home`. |

**Opzioni della sessione tmux** (tutte configurabili, tutte abilitate per impostazione predefinita):

| Variabile | Predefinito | Descrizione |
|-----------|-------------|-------------|
| `TMUX_MOUSE` | `true` | Supporto del mouse: scroll, selezione, ridimensionamento dei pannelli |
| `TMUX_HISTORY_LIMIT` | `50000` | Dimensione del buffer di scrollback in righe (il predefinito di tmux è 2000) |
| `TMUX_CLIPBOARD` | `true` | Integrazione con la clipboard di sistema tramite OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Tipo di terminale per il rendering corretto dei colori |
| `TMUX_EXTENDED_KEYS` | `true` | Sequenze di tasti estese, incluso Shift+Enter (richiede tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | Ritardo del tasto escape in millisecondi (il predefinito di tmux è 500) |
| `TMUX_TITLE_FORMAT` | `#S` | Formato del titolo del terminale/tab (`#S` = nome sessione, `""` per disabilitare) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Notifica quando si verifica attività in altre sessioni |

## Struttura delle directory

I progetti vengono individuati dalla presenza di una directory `.claude/`, a qualsiasi profondità:

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
│   └── project-d/          # ✗ nessun .claude/ - non è un progetto Claude
├── deep/nested/project-e/  # ✓ ha .claude/ - trovato a qualsiasi profondità
│   └── .claude/
└── ignored-project/        # ✗ escluso (.ignore-claudemux)
    ├── .claude/
    └── .ignore-claudemux
```

I nomi delle sessioni sono derivati dai nomi delle directory: gli spazi diventano trattini, i caratteri non alfanumerici (eccetto i trattini) vengono sostituiti, e i trattini iniziali/finali vengono rimossi. Le directory il cui nome, una volta sanitizzato, risulta vuoto vengono saltate con un avviso nel log.

## Session System Prompt

Ogni sessione Claude viene avviata con `--append-system-prompt` contenente il contesto sul proprio ambiente:

```
You are running inside tmux session '<session-name>'.
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
- When user says: ready — respond with "Ready." on one line. Nothing else.
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
  -a                          Start ALL sessions (use with caution)

GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

Quando `ALLOW_CROSS_SESSION_CONTROL=true`, il comando di invio cambia per permettere di indirizzare qualsiasi sessione, non solo sé stessa. Il percorso è il path assoluto dello script al momento del lancio, in modo che le sessioni non dipendano da `PATH`.

## Riferimento CLI

Raramente è necessario usarli direttamente: Claude li esegue per te dall'interno delle sessioni. Sono disponibili per scripting, automazione o quando non si è dentro una sessione.

```bash
# Avvio e collegamento
claude-mux                       # avvia Claude nella directory corrente e si collega
claude-mux ~/progetti/mia-app    # avvia Claude in una directory e si collega
claude-mux -d ~/progetti/mia-app # come sopra (forma esplicita)
claude-mux -t my-app             # collegati a una sessione tmux esistente

# Creazione di nuovi progetti
claude-mux -n ~/progetti/app     # crea un nuovo progetto Claude e si collega
claude-mux -n ~/nuovo/path/app -p  # come sopra, creando la directory e i parent
claude-mux -n ~/app --template web        # nuovo progetto con un template CLAUDE.md specifico
claude-mux -n ~/app --no-multi-coder      # nuovo progetto senza symlink AGENTS.md/GEMINI.md

# Gestione delle sessioni
claude-mux -l                    # elenca le sessioni per stato (active, running, stopped)
claude-mux -L                    # elenca tutti i progetti (active + idle)
claude-mux -s my-app '/model sonnet'      # invia un comando slash a una sessione
claude-mux --shutdown my-app              # arresta una sessione specifica
claude-mux --shutdown                     # arresta tutte le sessioni gestite
claude-mux --shutdown home --force        # arresta la sessione home protetta
claude-mux --restart my-app              # riavvia una sessione specifica
claude-mux --restart                     # riavvia tutte le sessioni in esecuzione
claude-mux --permission-mode plan my-app  # riavvia la sessione in plan mode
claude-mux -a                    # avvia tutte le sessioni gestite sotto BASE_DIR

# Altro
claude-mux --list-templates      # mostra i template CLAUDE.md disponibili
claude-mux --guide               # mostra i comandi conversazionali per l'uso dentro le sessioni
claude-mux --dry-run             # anteprima delle azioni senza eseguirle
claude-mux --version             # stampa la versione
claude-mux --help                # mostra tutte le opzioni

# Osserva il log
tail -f ~/Library/Logs/claude-mux.log
```

Quando viene eseguito dal terminale, l'output è duplicato su stdout in tempo reale. Quando viene eseguito tramite LaunchAgent, l'output va solo nel file di log.

## Risoluzione dei problemi

### Le sessioni mostrano "Not logged in · Run /login"

Questo accade al primo avvio se il keychain di macOS è bloccato (comune quando lo script viene eseguito prima che il keychain venga sbloccato dopo il login). Soluzione:

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

Il comando `/terminal-setup` non può essere eseguito dentro tmux. claude-mux abilita `extended-keys` di tmux per impostazione predefinita (`TMUX_EXTENDED_KEYS=true`), che supporta Shift+Enter nella maggior parte dei terminali moderni. Se Shift+Enter non funziona, usa `\` + Return per inserire ritorni a capo nel prompt.

### "Ready." all'avvio della sessione

Quando una sessione viene avviata o riavviata, claude-mux invia automaticamente un messaggio `ready` dopo che Claude ha terminato il caricamento. L'iniezione dice a Claude di rispondere con "Ready." e nient'altro. Questo conferma che la sessione è attiva e l'iniezione funziona.

### Comandi slash su Remote Control

I comandi slash (es. `/model`, `/clear`) [non sono supportati nativamente](https://github.com/anthropics/claude-code/issues/30674) nelle sessioni RC. claude-mux aggira il problema: ogni sessione riceve `claude-mux -s` iniettato in modo che Claude possa inviare comandi slash a sé stesso tramite tmux.

## Log

- `~/Library/Logs/claude-mux.log` - tutte le azioni dello script con timestamp UTC (configurabile tramite `LOG_DIR`)

Per debug a basso livello del LaunchAgent, usa Console.app o `log show`.
