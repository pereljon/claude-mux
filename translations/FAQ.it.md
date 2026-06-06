# FAQ

[English](../docs/FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · **Italiano** · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## Cos'e claude-mux?

Uno script shell che avvolge Claude Code in tmux per sessioni persistenti. Le sessioni sopravvivono alla chiusura del terminale, riprendono il contesto della conversazione al riavvio e sono accessibili dall'app mobile di Claude tramite Remote Control. Gestisci tutto parlando con Claude all'interno di una sessione.

## Funziona su Linux?

Non ancora. Solo macOS (Apple Silicon e Intel). Il supporto Linux e previsto per la v2.0. L'installer viene eseguito su Linux ma salta la configurazione del LaunchAgent e stampa una nota. Il binario in se funziona, ma non c'e ancora un servizio systemd o un meccanismo di avvio automatico equivalente.

## Cos'e la sessione home?

La sessione home e una sessione Claude di uso generale che vive nella directory di base (`~/Claude` per impostazione predefinita). Quando `LAUNCHAGENT_MODE=home` (il valore predefinito), si avvia automaticamente al login e resta in esecuzione tutto il giorno. E **protetta** per impostazione predefinita, quindi `--shutdown home` rifiuta di arrestarla senza `--force`.

Usa la sessione home come punto di accesso sempre disponibile dall'app mobile di Claude. Da li puoi elencare i progetti, avviare altre sessioni, gestire la configurazione e svolgere lavori generici che non appartengono a un progetto specifico.

## Cos'e Remote Control?

Remote Control (RC) e una funzionalita di Claude Code che permette di connettersi a una sessione Claude in esecuzione dall'app mobile di Claude o da Claude Desktop. claude-mux avvia ogni sessione con `--remote-control` abilitato, quindi tutte le sessioni appaiono automaticamente nella lista RC. Una volta connesso, parli con Claude come faresti dal terminale. claude-mux aggira anche i limiti di RC, come i comandi slash che non funzionano nativamente, instradandoli attraverso tmux.

## Cosa sono le modalita di permessi?

Claude Code ha quattro modalita di permessi che controllano quanta autonomia ha Claude:

| Modalita | Comportamento |
|----------|---------------|
| `default` | Claude chiede prima di eseguire comandi o modificare file |
| `acceptEdits` | Claude applica automaticamente le modifiche ai file ma chiede prima dei comandi shell |
| `plan` | Claude puo solo leggere e pianificare, nessuna scrittura o comando |
| `bypassPermissions` | Claude esegue tutto senza chiedere (richiede conferma al primo avvio) |

Imposta il valore predefinito per tutti i progetti tramite `DEFAULT_PERMISSION_MODE` nella config. Cambia una sessione in esecuzione dicendo "passa questa sessione in plan mode" (o qualsiasi nome di modalita). "yolo" e un alias per `bypassPermissions`.

Il passaggio a `bypassPermissions` da un'altra modalita usa la navigazione Shift+Tab e non richiede riavvio. Il passaggio da `bypassPermissions` a un'altra modalita richiede un riavvio, che claude-mux gestisce automaticamente.

## Come resetto una sessione?

Tre opzioni, a seconda di cosa vuoi:

- **Clear** ("pulisci questa sessione"): invia `/clear` alla sessione. Cancella la cronologia della conversazione e riparte da zero. La sessione resta in esecuzione.
- **Compact** ("compatta questa sessione"): invia `/compact` alla sessione. Riassume la conversazione in un contesto piu breve, liberando la finestra di contesto. La cronologia viene conservata in forma compressa.
- **Restart** ("riavvia questa sessione"): arresta Claude e lo rilancia con `claude -c`, che riprende l'ultima conversazione. Usalo quando serve un processo pulito (es. dopo aver cambiato modalita di permessi o quando Claude e bloccato).

## Cosa sono i template?

I template sono file CLAUDE.md riutilizzabili salvati in `~/.claude-mux/templates/`. Quando crei un nuovo progetto con `-n`, il template predefinito (o uno specificato con `--template NAME`) viene copiato nel progetto come CLAUDE.md.

Crea un template: "salva questo come template con nome web" (copia il CLAUDE.md del progetto corrente in `~/.claude-mux/templates/web.md`).

Usa un template: `claude-mux -n ~/progetti/mia-app --template web` oppure dall'interno di una sessione: "crea un nuovo progetto chiamato my-app usando il template web".

Elenca i template: "list templates" oppure `claude-mux --list-templates`.

## Come funziona il tip-of-the-day?

Un hook `UserPromptSubmit` di Claude Code nel file `.claude/settings.local.json` di ogni progetto chiama `claude-mux --on-prompt` a ogni prompt. Il primo prompt del giorno inietta un consiglio nella conversazione; i prompt successivi di quel giorno non iniettano nulla. Lo stato e per sessione, salvato in `~/.claude-mux/tip-state/<session_id>.json`, quindi ogni sessione attiva mostra il consiglio una volta al giorno. Poiche l'hook inietta nel contesto (non un hook Stop, il cui output finisce solo nel transcript), il consiglio e visibile nella conversazione e in Remote Control.

I consigli sono abilitati per impostazione predefinita (`TIP_OF_DAY=true`). Attiva o disattiva con "enable tips" o "disable tips" dentro qualsiasi sessione. `TIP_MODE=daily` mostra lo stesso consiglio tutto il giorno; `TIP_MODE=random` sceglie un consiglio casuale.

Il comando `--tip` funziona sempre indipendentemente dal gate giornaliero (e indipendentemente da `TIP_OF_DAY`), quindi puoi dire "tip" in qualsiasi momento.

## Posso usarlo con piu account GitHub?

Si. claude-mux rileva le voci `Host github.com-*` in `~/.ssh/config` e le inietta nel system prompt di ogni sessione. Claude sa quali alias SSH sono disponibili e puo usare quello corretto quando configura i remote git.

Esempio di configurazione `~/.ssh/config`:

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

Claude sapra di usare `git@github.com-work:org/repo.git` per i repo di lavoro e `git@github.com-personal:user/repo.git` per quelli personali.

## Dove viene salvato lo stato?

| Posizione | Cosa contiene |
|-----------|---------------|
| `~/.claude-mux/config` | Configurazione utente (sourced come bash) |
| `~/.claude-mux/templates/` | File di template CLAUDE.md |
| `~/.claude-mux/tip-state/<session_id>.json` | Data del consiglio per sessione + limite degli avvisi di aggiornamento |
| `~/.claude-mux/.update-check` | Risultato della verifica di versione in cache |
| `~/.claude-mux/.update-checking` | Lock durante la verifica di aggiornamento in background |
| `~/Library/Logs/claude-mux.log` | File di log (configurabile tramite `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | Plist del LaunchAgent (generato da `--install`) |
| `.claudemux-protected` (per progetto) | Contrassegna una sessione come protetta dallo shutdown |
| `.claudemux-ignore` (per progetto) | Nasconde un progetto dai listati |

I file marcatori (`.claudemux-*`) risiedono nella directory radice di ogni progetto e seguono la cartella durante rinominazioni, spostamenti e sincronizzazioni. Vengono aggiunti automaticamente al `.gitignore`.

La cronologia delle conversazioni e gestita da Claude Code stesso, salvata in `~/.claude/projects/`.

## Cosa succede con l'aggiornamento automatico se faccio un fork di claude-mux?

La verifica degli aggiornamenti e il comando `--update` hanno hardcoded `pereljon/claude-mux` come repo GitHub. Se fai un fork, le verifiche confronteranno comunque con la release upstream, e `--update` sovrascrivera il binario del tuo fork con quello upstream. Imposta `UPDATE_CHECK=false` in `~/.claude-mux/config` per disabilitare, oppure cambia l'URL del repo nelle funzioni `check_for_update()` e `do_update()` nello script.

## Come installo tramite Homebrew?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Aggiorna con `brew upgrade claude-mux`. Nota: se hai installato tramite Homebrew, `--update` delega automaticamente a `brew upgrade`.

## In cosa e diverso da `claude --worktree --tmux`?

`claude --worktree --tmux` crea una sessione tmux per un worktree git isolato, progettato per attivita di codifica parallele. claude-mux gestisce sessioni persistenti per le directory effettive dei tuoi progetti, con Remote Control abilitato, iniezione del system prompt per l'autogestione, ripresa delle conversazioni e gestione del ciclo di vita delle sessioni. Risolvono problemi diversi.

## In cosa e diverso da Claude Cowork Dispatch?

Dispatch avvia attivita dall'app desktop di Claude, ma richiede che l'app sia in esecuzione e non e legato a un progetto specifico. claude-mux gestisce sessioni persistenti, legate ai progetti, che sopravvivono ai riavvii e sono accessibili da ovunque tramite Remote Control - senza bisogno dell'app desktop.

## Perche le sessioni mostrano "Not logged in"?

Questo accade al primo avvio se il keychain di macOS e bloccato, cosa comune quando il LaunchAgent si avvia prima che tu sblocchi il keychain dopo il login. Risolvilo eseguendo `security unlock-keychain` in un terminale normale, poi collegati a qualsiasi sessione (`claude-mux -t <nome>`) ed esegui `/login` per completare il flusso di autenticazione nel browser. Dopo, riavvia tutte le sessioni e prenderanno le credenziali memorizzate.

## Piu terminali possono collegarsi alla stessa sessione?

Si. Questo e il comportamento standard di tmux. Eseguire `claude-mux` in una directory che ha gia una sessione in esecuzione si collega ad essa. Piu terminali vedono lo stesso contenuto della sessione in tempo reale.

## Come fermo definitivamente la sessione home?

Il LaunchAgent ha `KeepAlive: true`, quindi terminare la sessione home provoca un respawn entro circa 60 secondi. Per fermarla definitivamente, disabilita il LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## Cosa significa il messaggio "Session ready!"?

Quando una sessione viene avviata o riavviata, claude-mux invia un prompt `Ready?` dopo che Claude ha terminato il caricamento. L'iniezione dice a Claude di rispondere con "Session ready!" e nient'altro. Questo conferma che la sessione e attiva e l'iniezione del system prompt funziona. Puoi ignorarlo.

## Come nascondo un progetto dai listati?

Di' "nascondi questo progetto" dentro qualsiasi sessione, oppure esegui `claude-mux --hide my-project`. Questo crea un file marcatore `.claudemux-ignore`. Il progetto non apparira nell'output di `claude-mux -L`. Per vedere i progetti nascosti: `claude-mux -L --hidden`. Per mostrarlo di nuovo: "mostra questo progetto" oppure `claude-mux --show my-project`.

## Come disinstallo claude-mux?

```bash
claude-mux --uninstall
```

Questo rimuove gli hook per i consigli e le regole di permessi da tutti i progetti, scarica il LaunchAgent e opzionalmente rimuove `~/.claude-mux/`. Riporta il percorso del binario cosi puoi eliminarlo manualmente (oppure `brew uninstall claude-mux` se installato tramite Homebrew).

## I comandi slash funzionano su Remote Control?

Non nativamente. Claude Code non supporta i comandi slash (`/model`, `/clear`, ecc.) nelle sessioni RC. claude-mux aggira il problema iniettando ogni sessione con `claude-mux -s` cosi Claude puo inviare comandi slash a se stesso tramite tmux. Basta dire "passa a Haiku" o "compatta questa sessione" e Claude lo gestisce.

## Non riesco a selezionare testo in una sessione

Tieni premuto **Option** (macOS) o **Shift** (terminali Linux/Windows) mentre fai clic e trascini. Questo bypassa la cattura del mouse di tmux e copia la selezione negli appunti di sistema. Non servono modifiche alla configurazione.

## Quali lingue sono supportate per i comandi conversazionali?

Tutte. Le frasi trigger ("help", "status", "list sessions", ecc.) funzionano in qualsiasi lingua. Claude deduce l'intento dal linguaggio naturale dell'utente ed esegue il comando corrispondente. Il README e tradotto anche in 12 lingue.
