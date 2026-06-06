# claude-mux - Multiplexer di Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Italiano** · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Sessioni persistenti di Claude Code per tutti i tuoi progetti - accessibili ovunque tramite l'app mobile di Claude. ***Gestito da Claude!***

## Installazione

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Poi avvia una sessione:

```bash
claude-mux ~/percorso/del/tuo/progetto
```

L'installer chiede se vuoi una sessione home al login. Se accetti, una sessione Claude protetta si avvia automaticamente ogni volta che accedi al sistema - sempre raggiungibile dal telefono o da qualsiasi client Remote Control, anche se non apri mai il terminale.

Tutto qui. Sei in una sessione Claude persistente, consapevole del contesto, con Remote Control abilitato. **Da qui, tutto e conversazionale.**

[Homebrew, installazione manuale e altre opzioni](../docs/INSTALL.md)

## Perche

Remote Control promette Claude Code da qualsiasi luogo - ma senza gestione delle sessioni, e un'interfaccia di seconda classe anche da Claude Desktop:

- **Le sessioni terminano** quando chiudi il terminale
- **Il contesto della conversazione** non riprende automaticamente
- **Nessuna base operativa** - nulla e in esecuzione quando prendi il telefono, a meno che tu non abbia lasciato qualcosa aperto
- **Remote Control richiede una sessione attiva** - non puoi avviarne una da RC
- **I comandi slash non funzionano nelle sessioni RC** - nessun cambio modello, compattazione o modifica della modalita di permessi
- **Avviare nuovi progetti** - richiede creare manualmente una directory, inizializzare git, scrivere un CLAUDE.md e scegliere un modello
- **Nessuna gestione dei progetti** - nessun modo per vedere i progetti inattivi, o rinominare, spostare ed eliminare progetti senza perdere la cronologia

**claude-mux colma la lacuna nella gestione delle sessioni.** Avvolge Claude Code in tmux cosi le sessioni persistono, inietta un system prompt cosi Claude puo gestire le proprie sessioni e instrada i comandi slash attraverso tmux cosi funzionano su Remote Control. Una volta avviata una sessione, gestisci tutto parlando con Claude - dal terminale o dall'app mobile.

## Cosa puoi fare in una sessione claude-mux

- **Gestire qualsiasi sessione da qualsiasi sessione** - avviare, arrestare, riavviare, elencare e compattare i progetti usando il linguaggio naturale
- **Accedere a tutto da ovunque** - ogni sessione ha Remote Control abilitato, quindi l'app mobile di Claude, l'app desktop o qualsiasi client remoto e un'interfaccia completa
- **Cambiare modelli e modalita di permessi** - di' "switch to Haiku" o "switch to plan mode" e Claude lo gestisce, anche tramite Remote Control
- **Creare nuovi progetti** - "create a new project called my-app" configura la directory, git, CLAUDE.md e avvia una sessione. I template CLAUDE.md permettono di riutilizzare le istruzioni tra i progetti.
- **Mantenere le sessioni attive tra i riavvii** - una sessione home opzionale si avvia al login e resta attiva; tutte le sessioni riprendono automaticamente l'ultima conversazione
- **Inviare comandi slash tramite Remote Control** - Claude instrada `/model`, `/compact`, `/clear` e altri comandi slash alla sessione attiva, aggirando una [limitazione nota](https://github.com/anthropics/claude-code/issues/30674)
- **Preservare la cronologia delle conversazioni** - rinominare, spostare e riavviare i progetti preserva automaticamente la cronologia
- **Organizzare i progetti** - nascondere, rinominare, spostare, eliminare e proteggere i progetti dall'interno di qualsiasi sessione
- **Supporto multi-account GitHub** - rileva gli alias SSH in `~/.ssh/config` e li inietta nelle sessioni cosi Claude usa l'account giusto per ogni progetto
- **Supporto multi-CLI-coder** - crea automaticamente i symlink `AGENTS.md` e `GEMINI.md` cosi Codex CLI, Gemini CLI e altri condividono le istruzioni
- **Funziona in qualsiasi lingua** - i comandi conversazionali sono dedotti dall'intento, non dalle parole chiave

## Parlare con Claude

Cosi si usa claude-mux quotidianamente. Ogni sessione riceve comandi iniettati cosi Claude puo gestire sessioni, cambiare modello, inviare comandi slash e creare nuovi progetti - tutto dall'interno della conversazione. Non serve ricordare i flag CLI.

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
Claude: stampa un consiglio - lo stesso tutto il giorno, o casuale se TIP_MODE=random e impostato

Tu: "attiva i consigli" / "disattiva i consigli"
Claude: attiva o disattiva il consiglio del giorno su tutti i progetti

Tu: "aggiorna claude-mux"
Claude: avvisa che tutte le sessioni verranno riavviate, chiede conferma, poi aggiorna e riavvia

Tu: "arresta tutte le sessioni"
Claude: esce in modo controllato da tutte le sessioni gestite

Tu: "help"
Claude: stampa l'elenco completo dei comandi conversazionali
```

**Questi comandi funzionano in qualsiasi lingua.** Se scrivi l'equivalente in spagnolo, giapponese, ebraico o qualsiasi altra lingua, Claude ne deduce l'intento ed esegue il comando corrispondente.

**Digita `help` dentro qualsiasi sessione per vedere l'elenco completo dei comandi.**

## Altro

- [Riferimento CLI](../docs/CLI.md) - riferimento completo dei comandi per scripting e automazione
- [Guida](../docs/guide.md) - configurazione, dettagli sulle sessioni, meccanismi interni e risoluzione problemi
- [Opzioni di installazione](../docs/INSTALL.md) - Homebrew, installazione manuale, configurazione LaunchAgent
- [FAQ](../docs/FAQ.md) - domande frequenti su claude-mux
- [Problemi noti](../docs/ISSUES.md) - bug aperti, funzionalita pianificate e problemi risolti
- [Changelog](../CHANGELOG.md) - cosa e cambiato per ogni release
