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

- **Le sessioni terminano** quando chiudi il terminale - e non tornano dopo un crash o un riavvio
- **Il contesto della conversazione** non riprende automaticamente
- **Nessuna base operativa** - nulla e in esecuzione quando prendi il telefono, a meno che tu non abbia lasciato qualcosa aperto
- **Remote Control richiede una sessione attiva** - non puoi avviarne una da RC
- **I comandi slash non funzionano nelle sessioni RC** - nessun cambio modello, compattazione o modifica della modalita di permessi
- **Avviare nuovi progetti** - richiede creare manualmente una directory, inizializzare git, scrivere un file di istruzioni (AGENTS.md o CLAUDE.md) e scegliere un modello
- **Nessuna gestione dei progetti** - nessun modo per vedere i progetti inattivi, o rinominare, spostare ed eliminare progetti senza perdere la cronologia

**claude-mux colma la lacuna nella gestione delle sessioni.** Avvolge Claude Code in tmux cosi le sessioni persistono, le ripristina automaticamente dopo crash e riavvii (purche il login automatico sia abilitato), inietta un system prompt cosi Claude puo gestire le proprie sessioni e instrada i comandi slash attraverso tmux cosi funzionano su Remote Control. Una volta avviata una sessione, gestisci tutto parlando con Claude - dal terminale o dall'app mobile.

## Cosa puoi fare in una sessione claude-mux

- **Sopravvive a crash e riavvii** - le sessioni vengono ripristinate automaticamente quando accedi di nuovo, riprendendo l'ultima conversazione. Un `/exit` pulito o uno spegnimento mantiene la sessione ferma; una sessione che va in crash ripetuti viene fermata e segnalata, invece di essere riavviata all'infinito.
- **Gestire qualsiasi sessione da qualsiasi sessione** - avviare, arrestare, riavviare, elencare e compattare i progetti usando il linguaggio naturale
- **Accedere a tutto da ovunque** - ogni sessione ha Remote Control abilitato, quindi l'app mobile di Claude, l'app desktop o qualsiasi client remoto e un'interfaccia completa
- **Cambiare modelli e modalita di permessi** - di' "switch to Haiku" o "switch to plan mode" e Claude lo gestisce, anche tramite Remote Control
- **Creare nuovi progetti** - "create a new project called my-app" configura la directory, git, un AGENTS.md da un template e avvia una sessione. I template permettono di riutilizzare le istruzioni tra i progetti.
- **Inviare comandi slash tramite Remote Control** - Claude instrada `/model`, `/compact`, `/clear` e altri comandi slash alla sessione attiva, aggirando una [limitazione nota](https://github.com/anthropics/claude-code/issues/30674). RC si riconnette automaticamente dopo `/compact` tramite un hook `PreCompact`.
- **Rilevamento degli aggiornamenti di Claude Code** - quando il binario `claude` cambia (dopo `brew upgrade` o un aggiornamento npm), le sessioni in esecuzione mostrano un avviso per riavviare e caricare il nuovo binario; l'avviso persiste tra i prompt finche non riavvii, quindi un turno perso non lo fa sparire
- **Preservare la cronologia delle conversazioni** - rinominare, spostare e riavviare i progetti preserva automaticamente la cronologia
- **Organizzare i progetti** - nascondere, rinominare, spostare, eliminare e proteggere i progetti dall'interno di qualsiasi sessione
- **Supporto multi-account GitHub** - rileva gli alias SSH in `~/.ssh/config` e li inietta nelle sessioni cosi Claude usa l'account giusto per ogni progetto
- **AGENTS.md come file di istruzioni del progetto** - `AGENTS.md` e l'unico file reale, letto da Claude Code e da Codex CLI. Di' "migrate to AGENTS.md" per convertire un albero esistente da `CLAUDE.md` (prima un report, nulla viene committato). Richiede Claude Code 2.1.277 o successivo; le versioni precedenti mantengono `CLAUDE.md`. Gemini CLI lo legge solo se `~/.gemini/settings.json` contiene `"context": {"fileName": ["AGENTS.md"]}`.
- **Funziona in qualsiasi lingua** - i comandi conversazionali sono dedotti dall'intento, non dalle parole chiave

## Parlare con Claude

Cosi si usa claude-mux quotidianamente. Ogni sessione riceve comandi iniettati cosi Claude puo gestire sessioni, cambiare modello, inviare comandi slash e creare nuovi progetti - tutto dall'interno della conversazione. Non serve ricordare i flag CLI.

```
Di': "status"
Riporta nome sessione, modello, modalita permessi, utilizzo contesto ed elenca tutte le sessioni

Di': "elenco sessioni attive"
Mostra tutte le sessioni in esecuzione con il loro stato

Di': "elenco sessioni inattive"
Mostra solo i progetti inattivi

Di': "elenco sessioni ferme"
Mostra solo le sessioni ferme

Di': "avvia una sessione per il mio progetto api-server"
Avvia la sessione per nome; non fa nulla se e gia in esecuzione

Di': "crea un nuovo progetto chiamato mobile-app usando il template web"
Crea la directory del progetto, inizializza git, applica il template, avvia una sessione

Di': "passa questa sessione a Haiku"
Risolve la famiglia nell'ID concreto piu recente e invia /model claude-haiku-4-5 a se stesso

Di': "compatta la sessione api-server"
Invia /compact alla sessione api-server

Di': "riavvia la sessione web-dashboard"
Arresta e rilancia la sessione, preservando il contesto della conversazione

Di': "riavvia questa sessione da zero"
Chiede conferma, poi riavvia con una nuova conversazione - nessuna ripresa, nessun contesto precedente

Di': "uccidi la sessione api-server"
Chiede conferma, poi cancella la conversazione e la ferma; il prossimo avvio e una nuova conversazione, non una ripresa

Di': "chiudi questa sessione"
Salva prima il lavoro non finito e il passo successivo, chiede conferma (e se c'e qualcosa di non salvato), poi riavvia da zero

Di': "passa la sessione api-server in plan mode"
Riavvia la sessione con la modalita di permessi plan

Di': "passa questa sessione in yolo mode"
Passa alla modalita bypassPermissions tramite Shift+Tab - nessun riavvio necessario

Di': "in che modalita e questa sessione"
Riporta la modalita di permessi corrente (default, acceptEdits, plan, bypassPermissions)

Di': "passa questa sessione a Opus"
Risolve la famiglia nell'ID concreto piu recente e invia /model claude-opus-4-8 a se stesso

Di': "pulisci questa sessione"
Chiede conferma, poi invia /clear a se stesso, resettando la conversazione

Di': "nascondi questo progetto"
Scrive .claudemux-ignore cosi il progetto e escluso dai listati -L

Di': "proteggi questa sessione"
Scrive .claudemux-protected e imposta il marcatore tmux - lo shutdown ora richiede --force

Di': "questa sessione e protetta"
Controlla .claudemux-protected nella cartella del progetto e risponde

Di': "elimina il progetto old-prototype"
Conferma in chat, poi sposta la cartella del progetto nel cestino di sistema

Di': "rinomina questo progetto in my-new-name"
Arresta la sessione, rinomina la cartella, migra la cronologia delle conversazioni, riavvia

Di': "salva questo come template con nome web"
Copia AGENTS.md (o CLAUDE.md) in ~/.claude-mux/templates/web.md

Di': "controlla la migrazione ad agents" / "migra ad AGENTS.md"
Riporta (sola lettura) quali file CLAUDE.md possono passare ad AGENTS.md; dopo conferma li rinomina in tutto l'albero e riavvia le sessioni in esecuzione nella directory base

Di': "tip"
Stampa un consiglio - lo stesso tutto il giorno, o casuale se TIP_MODE=random e impostato

Di': "attiva i consigli" / "disattiva i consigli"
Attiva o disattiva il consiglio del giorno su tutti i progetti

Di': "aggiorna claude-mux"
Avvisa che tutte le sessioni verranno riavviate, chiede conferma, poi aggiorna e riavvia

Di': "arresta tutte le sessioni"
Esce in modo controllato da tutte le sessioni gestite

Di': "help"
Stampa l'elenco completo dei comandi conversazionali
```

**Questi comandi funzionano in qualsiasi lingua.** Se scrivi l'equivalente in spagnolo, giapponese, ebraico o qualsiasi altra lingua, Claude ne deduce l'intento ed esegue il comando corrispondente.

**Digita `help` dentro qualsiasi sessione per vedere l'elenco completo dei comandi.**

## Altro

- [Riferimento CLI](../docs/CLI.md) - riferimento completo dei comandi per scripting e automazione
- [Guida](../docs/GUIDE.md) - configurazione, dettagli sulle sessioni, meccanismi interni e risoluzione problemi
- [Opzioni di installazione](../docs/INSTALL.md) - Homebrew, installazione manuale, configurazione LaunchAgent
- [FAQ](../docs/FAQ.md) - domande frequenti su claude-mux
- [Problemi noti](../docs/ISSUES.md) - bug aperti, funzionalita pianificate e problemi risolti
- [Changelog](../CHANGELOG.md) - cosa e cambiato per ogni release
