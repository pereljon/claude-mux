# claude-mux - Multiplexer di Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Italiano** · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

> Nota: Questa traduzione potrebbe essere in ritardo rispetto al README in inglese. Consulta [README.md](../README.md) per la versione canonica.

Sessioni persistenti di Claude Code per tutti i tuoi progetti, accessibili da qualsiasi luogo tramite l'app mobile di Claude.

Uno script di shell che avvia Claude Code dentro tmux con Remote Control abilitato, ripresa delle conversazioni e auto-gestione delle sessioni: elenca le sessioni, invia comandi slash, avvia nuovi progetti, arresta o riavvia. Esegui `claude-mux` in qualsiasi directory per ottenere una sessione persistente accessibile dal telefono.

## Avvio rapido

```bash
./install.sh
```

```bash
claude-mux ~/percorso/al/tuo/progetto
```

Oppure entra con `cd` nella directory del progetto ed esegui:

```bash
claude-mux
```

Tutto qui: ti trovi in una sessione Claude persistente, consapevole del proprio contesto, con Remote Control abilitato.

claude-mux è un singolo script bash senza dipendenze oltre a tmux e Claude Code.

## Cosa fa

1. **Sessioni tmux persistenti con Remote Control** - avvia Claude Code dentro tmux con `--remote-control` abilitato, in modo che ogni sessione sia accessibile dall'app mobile di Claude
2. **Ripresa della conversazione** - se Claude era già in esecuzione nella directory, riprende l'ultima conversazione (`claude -c`) dentro una nuova sessione tmux con Remote Control, preservando il tuo contesto
3. **Gestione delle sessioni** - elenca le sessioni attive (`-l`) o tutti i progetti, comprese le sessioni inattive non ancora avviate (`-L`), arresta (`--shutdown`), riavvia (`--restart`), cambia modalità di permessi (`--permission-mode`), collegati (`-t`), invia comandi slash alle sessioni (`-s`)
4. **Auto-gestione di Claude** - ogni sessione riceve un system prompt iniettato così che Claude possa eseguire tutti i comandi sopra direttamente dai prompt della conversazione (terminale o app mobile):
   - a. Elencare le sessioni in esecuzione e tutti i progetti
   - b. Avviare nuove sessioni, creare nuovi progetti
   - c. Inviare comandi slash a sé stesso o ad altre sessioni (workaround per i [comandi slash che non funzionano nativamente su RC](https://github.com/anthropics/claude-code/issues/30674))
   - d. Arrestare, riavviare o cambiare modalità di permessi delle sessioni
5. **Sessione home** - una sessione leggera, sempre attiva, nella tua directory di base che parte al login (configurabile tramite `LAUNCHAGENT_MODE`). Mantiene Remote Control sempre disponibile dall'app mobile di Claude e può gestire tutte le altre sessioni. Protetta da arresti accidentali.
6. **Creazione di nuovi progetti** - `claude-mux -n DIRECTORY` crea un progetto pronto per il codice con git, `.gitignore` e modalità di permessi configurata (`-p` crea la directory se non esiste). Qualsiasi sessione attiva può creare nuovi progetti: chiedi a Claude di impostare un repo su uno qualsiasi dei tuoi account GitHub e inizia a programmare, da qualsiasi luogo
7. **Template CLAUDE.md** - mantieni una libreria di file di istruzioni CLAUDE.md in `~/.claude-mux/templates/` (es. `web.md`, `python.md`, `default.md`) e applicali automaticamente ai nuovi progetti. Usa `--template NAME` per scegliere un template specifico oppure lascia che venga applicato quello predefinito
8. **Consapevolezza degli account SSH** - inietta gli alias degli host SSH di GitHub da `~/.ssh/config` così Claude sa quali account sono disponibili per le operazioni git
9. **Permessi auto-approvati** - claude-mux si aggiunge alla allow list di `.claude/settings.local.json` di ogni progetto in modo che Claude possa eseguire i comandi claude-mux senza richiedere il permesso
10. **Migrazione dei processi orfani** - se Claude è già in esecuzione nella directory di destinazione fuori da tmux, lo termina e lo rilancia dentro una sessione tmux gestita (la conversazione riprende tramite `claude -c`)
11. **Comodità di tmux** - le sessioni sono configurate con supporto del mouse, buffer di scrollback da 50k, integrazione con la clipboard, 256 colori, ritardo di escape ridotto, tasti estesi (Shift+Enter), monitoraggio dell'attività e titoli delle tab del terminale, tutto configurabile in `~/.claude-mux/config`

> **Nota:** Questo è diverso da `claude --worktree --tmux`, che crea una sessione tmux per un worktree git isolato. claude-mux gestisce sessioni persistenti per le directory effettive dei tuoi progetti, con Remote Control e iniezione del system prompt.

### Sessione home

Una singola sessione di uso generale che vive in `$BASE_DIR`. Avviata automaticamente al login quando `LAUNCHAGENT_MODE=home`, oppure manualmente eseguendo `claude-mux` da `$BASE_DIR`. Ti dà una sessione Claude sempre pronta accessibile dal telefono senza dover avviare sessioni per ogni progetto.

La sessione home è sempre **protetta**: `--shutdown home` rifiuta di arrestarla senza `--force`, indipendentemente da come è stata avviata. Le sessioni protette sono contrassegnate con `*` nell'output di `-l`/`-L` (es. `active*`).

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

## Uso

```bash
claude-mux                       # avvia Claude nella directory corrente e si collega
claude-mux ~/projects/my-app     # avvia Claude in una directory e si collega
claude-mux -d ~/projects/my-app  # come sopra (forma esplicita)
claude-mux -a                    # avvia tutte le sessioni gestite sotto BASE_DIR
claude-mux -n ~/projects/app     # crea un nuovo progetto Claude e si collega
claude-mux -n ~/new/path/app -p  # come sopra, creando la directory e i parent
claude-mux -n ~/app --template web  # nuovo progetto con un template CLAUDE.md specifico
claude-mux --list-templates      # mostra i template CLAUDE.md disponibili
claude-mux -t my-app             # collegati a una sessione tmux esistente
claude-mux -s my-app '/model sonnet' # invia un comando slash a una sessione
claude-mux -l                    # elenca le sessioni per stato (active, running, stopped)
claude-mux -L                    # elenca tutti i progetti (active + idle)
claude-mux --shutdown            # esce in modo controllato da tutte le sessioni Claude gestite
claude-mux --shutdown my-app     # arresta una sessione specifica
claude-mux --shutdown a b c      # arresta più sessioni
claude-mux --shutdown home --force  # arresta la sessione home protetta
claude-mux --restart             # riavvia le sessioni che erano in esecuzione
claude-mux --restart my-app      # riavvia una sessione specifica
claude-mux --restart a b c       # riavvia più sessioni
claude-mux --permission-mode plan my-app    # riavvia la sessione in plan mode
claude-mux --permission-mode dangerously-skip-permissions my-app  # modalità yolo
claude-mux --dry-run             # anteprima delle azioni senza eseguirle
claude-mux --version             # stampa la versione
claude-mux --help                # mostra tutte le opzioni
claude-mux --guide               # mostra i comandi conversazionali per l'uso dentro le sessioni

# Osserva il log
tail -f ~/Library/Logs/claude-mux.log
```

Quando viene eseguito da terminale, l'output è duplicato su stdout in tempo reale. Quando viene eseguito tramite LaunchAgent, l'output va solo nel file di log.

## Stati delle sessioni

| Stato | Significato |
|--------|---------|
| `active` | la sessione tmux esiste, Claude è in esecuzione, e un client tmux locale è collegato |
| `running` | la sessione tmux esiste e Claude è in esecuzione (nessun client locale collegato) |
| `stopped` | la sessione tmux esiste ma Claude è uscito |
| `idle` | esiste un progetto `.claude/` sotto `BASE_DIR` ma nessuna sessione tmux di claude-mux in esecuzione (mostrato solo con `-L`) |

Un `*` finale su qualsiasi stato indica che la sessione è protetta e richiede `--force` per essere arrestata (es. `active*`, `running*`). La sessione home è sempre protetta.

Eseguire `claude-mux` in una directory che ha già una sessione in esecuzione si collega ad essa. Più terminali possono collegarsi alla stessa sessione (comportamento standard di tmux).

## Esempi di prompt per Claude

Poiché ogni sessione riceve i comandi claude-mux iniettati, puoi gestire le sessioni direttamente dai prompt della conversazione, dal terminale o tramite l'app mobile:

```
Tu: "Quali sessioni sono in esecuzione?"
Claude: esegue `claude-mux -l` e mostra i risultati

Tu: "Mostrami tutti i progetti"
Claude: esegue `claude-mux -L` e mostra i risultati

Tu: "Avvia una sessione per il mio progetto di lavoro api-server"
Claude: esegue `claude-mux -d ~/Claude/work/api-server --no-attach`

Tu: "Crea un nuovo progetto personale chiamato mobile-app"
Claude: esegue `claude-mux -n ~/Claude/personal/mobile-app -p --no-attach`

Tu: "Quali template ho?"
Claude: esegue `claude-mux --list-templates` e mostra i risultati

Tu: "Crea un nuovo progetto di lavoro chiamato api-server usando il template web"
Claude: esegue `claude-mux -n ~/Claude/work/api-server -p --template web --no-attach`

Tu: "Passa tutte le sessioni a Sonnet"
Claude: esegue `claude-mux -s SESSION '/model sonnet'` per ogni sessione in esecuzione

Tu: "Arresta la sessione data-pipeline"
Claude: esegue `claude-mux --shutdown data-pipeline`

Tu: "Riavvia la sessione web-dashboard bloccata"
Claude: esegue `claude-mux --restart web-dashboard`

Tu: "Passa la sessione api-server in plan mode"
Claude: esegue `claude-mux --permission-mode plan api-server`

Tu: "Metti la sessione data-pipeline in modalità yolo"
Claude: esegue `claude-mux --permission-mode dangerously-skip-permissions data-pipeline`

Tu: "Avvia la sessione data-pipeline in background"
Claude: esegue `claude-mux -d ~/Claude/work/data-pipeline --no-attach`

Tu: "Avvia tutti i miei progetti"
Claude: esegue `claude-mux -a` (dopo conferma: questo avvia ogni progetto gestito)
```

## Configurazione

Alla prima esecuzione, `~/.claude-mux/config` viene creato automaticamente con tutte le impostazioni commentate. Modificalo per sovrascrivere qualunque valore predefinito: lo script non deve mai essere modificato direttamente.

| Variabile | Predefinito | Descrizione |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Directory radice da scansionare per i progetti Claude (directory contenenti `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Directory per il file `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Imposta `permissions.defaultMode` di Claude in ogni progetto. Valori validi: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Imposta a `""` per disabilitare. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Quando `true`, le sessioni Claude possono inviare comandi slash ad altre sessioni: utile per orchestrazione multi-agente |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Directory contenente i file di template CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | Template predefinito applicato ai nuovi progetti (`-n`). Imposta a `""` per disabilitare. |
| `SLEEP_BETWEEN` | `5` | Secondi tra i lanci di sessioni quando si usa `-a`. Aumenta se la registrazione RC fallisce. |
| `HOME_SESSION_MODEL` | `""` | Modello per la sessione home. Valori validi: `sonnet`, `haiku`, `opus`. Vuoto eredita il predefinito di Claude. |
| `LAUNCHAGENT_MODE` | `home` | Comportamento del LaunchAgent al login: `none` (non fare nulla) o `home` (avvia la sessione home protetta). `LAUNCHAGENT_ENABLED=true` legacy viene trattato come `home`. |

**Opzioni della sessione tmux** (tutte configurabili, tutte abilitate per impostazione predefinita):

| Variabile | Predefinito | Descrizione |
|----------|---------|-------------|
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

Quando `ALLOW_CROSS_SESSION_CONTROL=true`, il comando di invio cambia per permettere di indirizzare qualsiasi sessione, non solo sé stessa. Il path è il percorso assoluto allo script al momento del lancio, in modo che le sessioni non dipendano da `PATH`.

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

Il comando `/terminal-setup` non può essere eseguito dentro tmux. claude-mux abilita `extended-keys` di tmux per impostazione predefinita (`TMUX_EXTENDED_KEYS=true`), che supporta Shift+Enter nella maggior parte dei terminali moderni. Se Shift+Enter non funziona, usa `\` + Return per inserire ritorni a capo nel tuo prompt.

### Comandi slash su Remote Control

I comandi slash (es. `/model`, `/clear`) [non sono supportati nativamente](https://github.com/anthropics/claude-code/issues/30674) nelle sessioni RC. claude-mux aggira il problema: ogni sessione riceve `claude-mux -s` iniettato così che Claude possa inviare comandi slash a sé stesso tramite tmux.

## Log

- `~/Library/Logs/claude-mux.log` - tutte le azioni dello script con timestamp UTC (configurabile tramite `LOG_DIR`)

Per debug a basso livello del LaunchAgent, usa Console.app o `log show`.
