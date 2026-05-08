# claude-mux - Multiplexeur Claude Code

[English](../README.md) · [Español](README.es.md) · **Français** · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Des sessions Claude Code persistantes pour tous vos projets, accessibles depuis n'importe ou via l'application mobile Claude. ***Managed by Claude!***

## Pourquoi

Remote Control promet Claude Code depuis n'importe ou, mais sans gestion de sessions, c'est une interface de second rang, y compris depuis Claude Desktop :

- Les sessions meurent quand vous fermez le terminal, et le contexte de conversation ne reprend pas automatiquement
- Il n'y a pas de base permanente : rien ne tourne quand vous prenez votre telephone sauf si vous avez laisse quelque chose ouvert
- Si une session ne tourne pas, Remote Control est inutile : vous ne pouvez ni atteindre un projet ni en demarrer un
- Meme dans une session RC active, les slash commands ne fonctionnent pas : pas de changement de modele, de compactage, ni de changement de mode de permission
- Demarrer un nouveau projet necessite de creer manuellement un repertoire, initialiser git, ecrire un CLAUDE.md, definir un mode de permission et choisir un modele. Rien de tout cela n'est possible depuis RC
- Gerer plusieurs projets implique plusieurs lancements manuels de terminal sans vue d'ensemble de ce qui tourne ni de son etat

claude-mux resout tout cela. Il encapsule Claude Code dans tmux pour que les sessions persistent, injecte un system prompt afin que Claude puisse gerer ses propres sessions, et achemine les slash commands via tmux pour qu'elles fonctionnent en Remote Control. Une fois une session lancee, vous gerez tout en parlant a Claude, depuis le terminal ou l'application mobile.

## Demarrage rapide

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Puis lancez une session :

```bash
cd ~/chemin/vers/votre/projet
claude-mux
```

Ou :

```bash
claude-mux ~/chemin/vers/votre/projet
```

C'est tout. Vous etes dans une session Claude persistante et consciente de son contexte, avec Remote Control active. A partir de la, tout est conversationnel.

## Parler a Claude

C'est ainsi que vous utilisez claude-mux au quotidien. Chaque session recoit en injection les commandes permettant a Claude de gerer les sessions, changer de modele, envoyer des slash commands et creer de nouveaux projets, le tout depuis la conversation. Vous n'avez pas besoin de memoriser des flags CLI.

```
Vous : "status"
Claude : indique le nom de session, le modele, le mode de permission, l'utilisation du contexte, et liste toutes les sessions

Vous : "list active sessions"
Claude : affiche toutes les sessions en cours avec leur statut

Vous : "start a session for my api-server project"
Claude : lance une session dans ~/Claude/work/api-server

Vous : "create a new project called mobile-app using the web template"
Claude : cree le repertoire du projet, initialise git, applique le template, lance une session

Vous : "switch this session to Haiku"
Claude : envoie /model haiku a lui-meme via tmux

Vous : "compact the api-server session"
Claude : envoie /compact a la session api-server

Vous : "restart the web-dashboard session"
Claude : arrete et relance la session en preservant le contexte de conversation

Vous : "switch the api-server session to plan mode"
Claude : redemarre la session avec le mode de permission plan

Vous : "switch this session to yolo mode"
Claude : passe en mode bypassPermissions via Shift+Tab, sans redemarrage

Vous : "what mode is this session"
Claude : indique le mode de permission actuel (default, acceptEdits, plan, bypassPermissions)

Vous : "switch this session to Opus"
Claude : envoie /model opus a lui-meme via tmux

Vous : "clear this session"
Claude : envoie /clear a lui-meme, reinitialisant la conversation

Vous : "hide this project"
Claude : ecrit .claudemux-ignore pour exclure le projet des listes -L

Vous : "protect this session"
Claude : ecrit .claudemux-protected et definit le marqueur tmux. L'arret necessite desormais --force

Vous : "is this session protected"
Claude : verifie la presence de .claudemux-protected dans le dossier du projet et repond

Vous : "delete the old-prototype project"
Claude : confirme dans le chat, puis deplace le dossier du projet dans la corbeille systeme

Vous : "rename this project to my-new-name"
Claude : arrete la session, renomme le dossier, migre l'historique de conversation, redemarre

Vous : "save this as a template named web"
Claude : copie CLAUDE.md vers ~/.claude-mux/templates/web.md

Vous : "tip"
Claude : affiche une astuce. Meme astuce toute la journee, ou aleatoire si TIP_MODE=random est defini

Vous : "enable tips" / "disable tips"
Claude : active ou desactive le hook tip-of-the-day sur tous les projets

Vous : "update claude-mux"
Claude : previent que toutes les sessions vont redemarrer, demande confirmation, puis met a jour et redemarre

Vous : "stop all sessions"
Claude : quitte proprement toutes les sessions gerees

Vous : "help"
Claude : affiche la liste complete des commandes conversationnelles
```

Ces commandes fonctionnent dans n'importe quelle langue. Si vous tapez l'equivalent en espagnol, japonais, hebreu ou toute autre langue, Claude deduit l'intention et execute la commande correspondante.

Tapez `help` dans n'importe quelle session pour voir la liste complete des commandes.

### Session principale

La session principale est une session generaliste vivant dans votre repertoire de base (`~/Claude` par defaut). Elle se lance automatiquement a l'ouverture de session quand `LAUNCHAGENT_MODE=home`, vous donnant une session Claude toujours prete et accessible depuis votre telephone. Utilisez-la pour gerer toutes vos autres sessions sans avoir a lancer d'abord les sessions de projet specifiques.

La session principale est **protegee** par defaut : `--shutdown home` refuse de l'arreter sans `--force`. La protection est assuree par le marqueur `.claudemux-protected` dans `$BASE_DIR`, cree par `claude-mux --install`. Les sessions protegees affichent `protected` dans la colonne de statut ; la session appelante est marquee avec `>` dans la colonne de nom.

## Ce qu'il fait

En coulisses, claude-mux gere :

- **Sessions tmux persistantes** avec Remote Control active, afin que chaque session soit accessible depuis l'application mobile Claude
- **Reprise de conversation** : reprend la derniere conversation (`claude -c`) lors du relancement, en preservant le contexte
- **Injection de system prompt** : chaque session recoit des commandes pour l'autogestion, l'acheminement des slash commands et la reconnaissance des comptes SSH
- **Templates CLAUDE.md** : maintenez des fichiers templates (par exemple `web.md`, `python.md`) dans `~/.claude-mux/templates/` et appliquez-les aux nouveaux projets
- **Support multi-CLI-coder** : cree `AGENTS.md` et `GEMINI.md` comme liens symboliques vers `CLAUDE.md` pour que Codex CLI, Gemini CLI et autres outils partagent les memes instructions
- **Permissions auto-approuvees** : ajoute claude-mux a la liste d'autorisations de chaque projet pour que Claude puisse executer les commandes de session sans demander la permission
- **Migration des processus orphelins** : si Claude tourne deja en dehors de tmux, le migre dans une session geree
- **Confort tmux** : prise en charge de la souris, buffer de defilement de 50k lignes, presse-papiers, 256 couleurs, extended keys, surveillance d'activite, titres d'onglets

> **Remarque :** ceci differe de `claude --worktree --tmux`, qui cree une session tmux pour un git worktree isole. claude-mux gere des sessions persistantes pour vos repertoires de projet reels, avec Remote Control et injection de system prompt.

## Prerequis

- macOS (Apple Silicon ou Intel)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## Installation

### curl (recommande)

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Telecharge le binaire, l'installe dans `~/bin`, l'ajoute au `PATH` et lance la configuration interactive. Fonctionne sur macOS et Linux (Linux : l'etape LaunchAgent est ignoree).

Pour mettre a jour :

```bash
claude-mux --update     # fonctionne depuis n'importe quelle session ou depuis le terminal
```

### Homebrew (alternative macOS)

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Pour mettre a jour :

```bash
brew upgrade claude-mux
```

### Manuel

```bash
./install.sh
```

`install.sh` copie le binaire dans `~/bin` et l'ajoute au `PATH`. Ensuite, lancez :

```bash
claude-mux --install
```

La configuration interactive demande ou se trouvent vos projets Claude, s'il faut demarrer une session principale a l'ouverture de session, et quel modele utiliser. Elle cree `~/.claude-mux/config` et installe le LaunchAgent.

Utilisez `--non-interactive` pour ignorer les prompts et accepter les valeurs par defaut.

Options :

```bash
claude-mux --install --non-interactive                     # ignore les prompts, utilise les valeurs par defaut
claude-mux --install --base-dir ~/work/claude              # utilise un repertoire de base different
claude-mux --install --launchagent-mode none               # desactive le comportement du LaunchAgent
claude-mux --install --home-model haiku                    # utilise Haiku pour la session principale
claude-mux --install --no-launchagent                      # ignore completement l'installation du LaunchAgent
```

Le LaunchAgent execute `claude-mux --autolaunch` a l'ouverture de session avec un delai de demarrage de 45 secondes pour permettre l'initialisation des services systeme.

## Statuts de session

| Statut | Signification |
|--------|---------------|
| `running` | la session tmux existe et Claude tourne |
| `protected` | identique a `running`, mais la session est protegee : `--shutdown` necessite `--force` pour l'arreter |
| `stopped` | la session tmux existe mais Claude s'est arrete |
| `idle` | un projet `.claude/` existe sous `BASE_DIR` mais aucune session tmux claude-mux n'est en cours (visible uniquement avec `-L`) |

Un prefixe `>` sur le nom de session (p. ex. `> home`) marque la session qui a execute la commande de liste.

Lancer `claude-mux` dans un repertoire qui a deja une session en cours s'y attache. Plusieurs terminaux peuvent s'attacher a la meme session (comportement standard de tmux).

## Marqueurs de projet

L'etat par projet est stocke dans des fichiers marqueurs a la racine du projet, et non dans une configuration centrale. Les marqueurs utilisent le prefixe `.claudemux-` et sont automatiquement ajoutes au `.gitignore` lors de leur creation dans un projet suivi par git.

| Marqueur | Signification | CLI |
|----------|---------------|-----|
| `.claudemux-protected` | La session est protegee au lancement : `--shutdown` necessite `--force` | `--protect` / `--unprotect` |
| `.claudemux-ignore` | Le projet est masque des listes `claude-mux -L` | `--hide` / `--show` |

```bash
claude-mux --hide                    # masquer le projet de la session courante des listes -L
claude-mux --hide my-project         # masquer le projet d'une session specifique
claude-mux --show my-project         # afficher a nouveau un projet
claude-mux --protect                 # proteger cette session d'un arret accidentel
claude-mux --unprotect               # supprimer la protection
claude-mux -L --hidden               # lister uniquement les projets masques
claude-mux --delete my-project       # deplacer le dossier du projet dans la corbeille systeme (macOS)
```

Les marqueurs suivent le dossier du projet lors de renommages et deplacements. Un seul motif `.gitignore` (`.claudemux-*`) couvre tous les marqueurs actuels et futurs.

## Configuration

`~/.claude-mux/config` est cree par `claude-mux --install` (ou au premier lancement d'une commande si aucune config n'existe). Modifiez-le pour surcharger les valeurs par defaut : le script lui-meme n'a jamais besoin d'etre modifie directement.

| Variable | Valeur par defaut | Description |
|----------|-------------------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Repertoire racine a scanner pour trouver les projets Claude (repertoires contenant `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Repertoire pour le fichier `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Definit `permissions.defaultMode` de Claude dans chaque projet. Valeurs valides : `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Mettez `""` pour desactiver. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Quand `true`, les sessions Claude peuvent envoyer des slash commands a d'autres sessions. Utile pour l'orchestration multi-agent. |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Repertoire contenant les fichiers templates CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | Template par defaut applique aux nouveaux projets (`-n`). Mettez `""` pour desactiver. |
| `SLEEP_BETWEEN` | `5` | Secondes entre les lancements de session quand `-a` est utilise. A augmenter si l'enregistrement RC echoue. |
| `HOME_SESSION_MODEL` | `""` | Modele pour la session principale. Valeurs valides : `sonnet`, `haiku`, `opus`. Vide herite de la valeur par defaut de Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Liste de fichiers separes par des espaces a creer comme liens symboliques vers `CLAUDE.md` pour d'autres outils CLI d'IA. Mettez `""` pour desactiver. |
| `LAUNCHAGENT_MODE` | `home` | Comportement du LaunchAgent a l'ouverture de session : `none` (ne rien faire) ou `home` (lance la session principale protegee). L'ancienne valeur `LAUNCHAGENT_ENABLED=true` est traitee comme `home`. |

**Options de session tmux** (toutes configurables, toutes activees par defaut) :

| Variable | Valeur par defaut | Description |
|----------|-------------------|-------------|
| `TMUX_MOUSE` | `true` | Prise en charge de la souris : defilement, selection, redimensionnement de panneaux |
| `TMUX_HISTORY_LIMIT` | `50000` | Taille du buffer de defilement en lignes (la valeur par defaut de tmux est 2000) |
| `TMUX_CLIPBOARD` | `true` | Integration du presse-papiers systeme via OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Type de terminal pour un rendu correct des couleurs |
| `TMUX_EXTENDED_KEYS` | `true` | Sequences de touches etendues, dont Shift+Enter (necessite tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | Delai de la touche Echap en millisecondes (la valeur par defaut de tmux est 500) |
| `TMUX_TITLE_FORMAT` | `#S` | Format du titre de terminal/onglet (`#S` = nom de session, `""` pour desactiver) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Notifie quand une activite survient dans d'autres sessions |

## Structure des repertoires

Les projets sont decouverts par la presence d'un repertoire `.claude/`, a n'importe quelle profondeur :

```
~/Claude/
├── work/
│   ├── project-a/          # a .claude/ - gere
│   │   └── .claude/
│   ├── project-b/          # a .claude/ - gere
│   │   └── .claude/
│   └── -archived/          # exclu (commence par -)
│       └── .claude/
├── personal/
│   ├── project-c/          # a .claude/ - gere
│   │   └── .claude/
│   ├── .hidden/            # exclu (repertoire cache)
│   │   └── .claude/
│   └── project-d/          # pas de .claude/ - n'est pas un projet Claude
├── deep/nested/project-e/  # a .claude/ - trouve a n'importe quelle profondeur
│   └── .claude/
└── ignored-project/        # exclu (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

Les noms de session sont derives des noms de repertoire : les espaces deviennent des tirets, les caracteres non alphanumeriques (sauf les tirets) sont remplaces, et les tirets en debut/fin sont supprimes. Les repertoires dont le nom assaini est vide sont ignores avec un avertissement dans le log.

## System prompt de session

Chaque session Claude est lancee avec `--append-system-prompt` contenant le contexte de son environnement :

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

La session principale recoit un contexte supplementaire : une description de son role, ainsi que des triggers d'autogestion pour lire/modifier la config et les templates. Quand `ALLOW_CROSS_SESSION_CONTROL=true`, la commande d'envoi peut cibler n'importe quelle session, pas seulement elle-meme. Le chemin est le chemin absolu vers le script au moment du lancement, donc les sessions ne dependent pas de `PATH`.

## Reference CLI

Vous avez rarement besoin de ces commandes directement : Claude les execute pour vous depuis les sessions. Elles sont disponibles pour les scripts, l'automatisation ou quand vous n'etes pas dans une session.

```bash
# Lancer et s'attacher
claude-mux                       # lance Claude dans le repertoire courant et s'attache
claude-mux ~/projets/my-app      # lance Claude dans un repertoire et s'attache
claude-mux -d ~/projets/my-app   # identique (forme explicite)
claude-mux -t my-app             # s'attache a une session tmux existante

# Creer de nouveaux projets
claude-mux -n ~/projets/app      # cree un nouveau projet Claude et s'attache
claude-mux -n ~/nouveau/chemin/app -p  # idem, en creant le repertoire et ses parents
claude-mux -n ~/app --template web        # nouveau projet avec un template CLAUDE.md specifique
claude-mux -n ~/app --no-multi-coder      # nouveau projet sans liens symboliques AGENTS.md/GEMINI.md

# Gestion des sessions
claude-mux -l                    # liste les sessions par statut (active, running, stopped)
claude-mux -L                    # liste tous les projets (actifs + idle)
claude-mux -L --hidden           # liste uniquement les projets masques
claude-mux -s my-app '/model sonnet'      # envoie une slash command a une session
claude-mux --shutdown my-app              # arrete une session specifique
claude-mux --shutdown                     # arrete toutes les sessions gerees
claude-mux --shutdown home --force        # arrete la session principale protegee
claude-mux --restart my-app              # redemarre une session specifique
claude-mux --restart                     # redemarre toutes les sessions en cours
claude-mux --permission-mode plan my-app  # redemarre la session en mode plan
claude-mux -a                    # demarre toutes les sessions gerees sous BASE_DIR

# Marqueurs de projet (toutes les commandes utilisent des noms de session, pas des chemins)
claude-mux --hide                # masquer le projet de la session courante des listes -L
claude-mux --hide my-project     # masquer un projet specifique par nom de session
claude-mux --show my-project     # afficher a nouveau un projet
claude-mux --protect             # proteger cette session d'un arret accidentel
claude-mux --unprotect           # supprimer la protection
claude-mux --delete my-project           # deplacer le dossier du projet dans la corbeille systeme (macOS)
claude-mux --delete my-project --yes     # idem, sans invite de confirmation
claude-mux --rename my-project new-name  # renommer le repertoire du projet
claude-mux --move my-project ~/Claude/work  # deplacer le projet vers un nouveau parent

# Autre
claude-mux --list-templates      # affiche les templates CLAUDE.md disponibles
claude-mux --guide               # affiche les commandes conversationnelles a utiliser dans les sessions
claude-mux --commands            # affiche la reference CLI complete
claude-mux --config-help         # affiche toutes les options de configuration avec valeurs par defaut et descriptions
claude-mux --install             # configuration interactive : config + LaunchAgent
claude-mux --update              # met a jour vers la derniere version
claude-mux --dry-run             # previsualise les actions sans les executer
claude-mux --version             # affiche la version
claude-mux --help                # affiche toutes les options

# Suivre le journal
tail -f ~/Library/Logs/claude-mux.log
```

Lorsqu'il est execute depuis le terminal, la sortie est dupliquee vers stdout en temps reel. Lorsqu'il est execute via le LaunchAgent, la sortie va uniquement dans le fichier de log.

## Depannage

### Les sessions affichent "Not logged in - Run /login"

Cela arrive au premier lancement si le keychain de macOS est verrouille (frequent quand le script tourne avant que le keychain soit deverrouille apres l'ouverture de session). Solution :

```bash
# Deverrouiller le keychain dans un terminal classique
security unlock-keychain

# Puis terminer l'authentification dans n'importe quelle session en cours
claude-mux -t <any-session>
# Lancer /login et completer le flux dans le navigateur
```

Une fois l'authentification faite, fermez et relancez toutes les sessions : elles recupereront automatiquement les identifiants stockes.

### Sessions absentes de Claude Code Remote

Les sessions doivent etre authentifiees (ne pas afficher "Not logged in"). Apres un lancement propre et authentifie, elles devraient apparaitre dans la liste RC en quelques secondes.

### Saisie multiligne dans tmux

La commande `/terminal-setup` ne peut pas tourner dans tmux. claude-mux active les `extended-keys` de tmux par defaut (`TMUX_EXTENDED_KEYS=true`), ce qui prend en charge Shift+Enter dans la plupart des terminaux modernes. Si Shift+Enter ne fonctionne pas, utilisez `\` + Entree pour inserer des sauts de ligne dans votre prompt.

### "Session ready!" au demarrage de session

Quand une session demarre ou redemarre, claude-mux envoie automatiquement un message `Ready?` apres le chargement de Claude. L'injection indique a Claude de repondre "Session ready!" et rien d'autre. Cela confirme que la session est active et que l'injection fonctionne.

### Slash commands via Remote Control

Les slash commands (par exemple `/model`, `/clear`) [ne sont pas prises en charge nativement](https://github.com/anthropics/claude-code/issues/30674) dans les sessions RC. claude-mux contourne ce probleme : chaque session recoit l'injection de `claude-mux -s` afin que Claude puisse s'envoyer des slash commands a lui-meme via tmux.

## Logs

- `~/Library/Logs/claude-mux.log` : toutes les actions du script avec horodatage UTC (configurable via `LOG_DIR`)

Pour le debogage bas niveau du LaunchAgent, utilisez Console.app ou `log show`.

## Plus

- [FAQ](FAQ.fr.md) : questions frequentes sur claude-mux
- [Problemes connus](ISSUES.fr.md) : bugs ouverts, fonctionnalites prevues et problemes resolus
- [Changelog](../CHANGELOG.md) : ce qui a change par version
