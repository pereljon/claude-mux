# claude-mux - Multiplexeur Claude Code

[English](../README.md) · [Español](README.es.md) · **Français** · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

> Remarque : Cette traduction peut être en retard par rapport au README anglais. Consultez [README.md](../README.md) pour la version canonique.

Des sessions Claude Code persistantes pour tous vos projets, accessibles depuis n'importe où via l'application mobile Claude.

## Pourquoi

Remote Control promet Claude Code depuis n'importe où — mais sans gestion de sessions, c'est une interface de second rang même depuis Claude Desktop :

- Les sessions meurent quand vous fermez le terminal, et le contexte de la conversation ne reprend pas automatiquement
- Il n'y a pas de base permanente — rien ne tourne quand vous prenez votre téléphone sauf si vous avez laissé quelque chose ouvert
- Si une session ne tourne pas, Remote Control est inutile — vous ne pouvez ni atteindre un projet ni en démarrer un
- Même dans une session RC active, les slash commands ne fonctionnent pas — pas de changement de modèle, de compactage, ni de changement de mode de permission
- Démarrer un nouveau projet nécessite de créer manuellement un répertoire, initialiser git, écrire un CLAUDE.md, définir un mode de permission et choisir un modèle — rien de tout cela n'est possible depuis RC
- Gérer plusieurs projets implique plusieurs lancements manuels de terminal sans vue d'ensemble de ce qui tourne ni de son état

claude-mux résout tout cela. Il encapsule Claude Code dans tmux pour que les sessions persistent, injecte un system prompt afin que Claude puisse gérer ses propres sessions, et achemine les slash commands via tmux pour qu'elles fonctionnent en Remote Control. Une fois une session lancée, vous gérez tout en parlant à Claude -- depuis le terminal ou l'application mobile.

## Démarrage rapide

```bash
brew tap pereljon/tap
brew install claude-mux
```

```bash
cd ~/chemin/vers/votre/projet
claude-mux
```

Ou :

```bash
claude-mux ~/chemin/vers/votre/projet
```

C'est tout. Vous êtes dans une session Claude persistante et consciente de son contexte, avec Remote Control activé. À partir de là, tout est conversationnel.

## Parler à Claude

C'est ainsi que vous utilisez claude-mux au quotidien. Chaque session reçoit en injection les commandes permettant à Claude de gérer les sessions, changer de modèle, envoyer des slash commands et créer de nouveaux projets -- tout depuis la conversation. Vous n'avez pas besoin de mémoriser des flags CLI.

```
Vous : « status »
Claude : indique le nom de session, le modèle, le mode de permission, l'utilisation du contexte, et liste toutes les sessions

Vous : « list active sessions »
Claude : affiche toutes les sessions en cours avec leur statut

Vous : « start a session for my api-server project »
Claude : lance une session dans ~/Claude/work/api-server

Vous : « create a new project called mobile-app using the web template »
Claude : crée le répertoire du projet, initialise git, applique le modèle, lance une session

Vous : « switch this session to Haiku »
Claude : envoie /model haiku à lui-même via tmux

Vous : « compact the api-server session »
Claude : envoie /compact à la session api-server

Vous : « restart the web-dashboard session »
Claude : arrête et relance la session en préservant le contexte de conversation

Vous : « switch the api-server session to plan mode »
Claude : redémarre la session avec le mode de permission plan

Vous : « stop all sessions »
Claude : quitte proprement toutes les sessions gérées

Vous : « help »
Claude : affiche la liste complète des commandes conversationnelles
```

Ces commandes fonctionnent dans n'importe quelle langue. Si vous tapez l'équivalent en espagnol, japonais, hébreu ou toute autre langue, Claude déduit l'intention et exécute la commande correspondante.

Tapez `help` dans n'importe quelle session pour voir la liste complète des commandes.

### Session principale

La session principale est une session généraliste vivant dans votre répertoire de base (`~/Claude` par défaut). Elle se lance automatiquement à l'ouverture de session quand `LAUNCHAGENT_MODE=home`, vous donnant une session Claude toujours prête et accessible depuis votre téléphone. Utilisez-la pour gérer toutes vos autres sessions sans avoir à lancer d'abord les sessions de projet spécifiques.

La session principale est toujours **protégée** -- `--shutdown home` refuse de l'arrêter sans `--force`. Les sessions protégées sont marquées d'un `*` dans la sortie de statut (par exemple `active*`).

## Ce qu'il fait

En coulisses, claude-mux gère :

- **Sessions tmux persistantes** avec Remote Control activé, afin que chaque session soit accessible depuis l'application mobile Claude
- **Reprise de conversation** -- reprend la dernière conversation (`claude -c`) lors du relancement, en préservant le contexte
- **Injection de system prompt** -- chaque session reçoit des commandes pour l'autogestion, l'acheminement des slash commands et la reconnaissance des comptes SSH
- **Modèles CLAUDE.md** -- maintenez des fichiers modèles (par exemple `web.md`, `python.md`) dans `~/.claude-mux/templates/` et appliquez-les aux nouveaux projets
- **Support multi-CLI-coder** -- crée `AGENTS.md` et `GEMINI.md` comme liens symboliques vers `CLAUDE.md` pour que Codex CLI, Gemini CLI et autres outils partagent les mêmes instructions
- **Permissions auto-approuvées** -- ajoute claude-mux à la liste d'autorisations de chaque projet pour que Claude puisse exécuter les commandes de session sans demander la permission
- **Migration des processus orphelins** -- si Claude tourne déjà en dehors de tmux, le migre dans une session gérée
- **Confort tmux** -- prise en charge de la souris, buffer de défilement de 50k lignes, presse-papiers, 256 couleurs, extended keys, surveillance d'activité, titres d'onglets

> **Remarque :** ceci diffère de `claude --worktree --tmux`, qui crée une session tmux pour un git worktree isolé. claude-mux gère des sessions persistantes pour vos répertoires de projet réels, avec Remote Control et injection de system prompt.

## Prérequis

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## Installation

### Homebrew (recommandé)

```bash
brew tap pereljon/tap
brew install claude-mux
```

La configuration (`~/.claude-mux/config`) est créée automatiquement au premier lancement. Pour configurer le LaunchAgent (session principale au démarrage), clonez le dépôt et exécutez `install.sh`.

Pour mettre à jour :

```bash
brew upgrade claude-mux
```

### Manuel

```bash
./install.sh
```

L'installeur interactif demande où se trouvent vos projets Claude, s'il faut démarrer une session principale à l'ouverture de session, et quel modèle utiliser. Il installe `claude-mux` dans `~/bin`, crée `~/.claude-mux/config` et configure le LaunchAgent.

Utilisez `--non-interactive` pour ignorer les prompts et accepter les valeurs par défaut.

Options :

```bash
./install.sh --non-interactive                     # ignore les prompts, utilise les valeurs par défaut
./install.sh --base-dir ~/work/claude              # utilise un répertoire de base différent
./install.sh --launchagent-mode none               # désactive le comportement du LaunchAgent
./install.sh --home-model haiku                    # utilise Haiku pour la session principale
./install.sh --no-launchagent                      # ignore complètement l'installation du LaunchAgent
```

Le LaunchAgent exécute `claude-mux --autolaunch` à l'ouverture de session avec un délai de démarrage de 45 secondes pour permettre l'initialisation des services système.

## Statuts de session

| Statut | Signification |
|--------|---------------|
| `active` | la session tmux existe, Claude tourne, et un client tmux local est attaché |
| `running` | la session tmux existe et Claude tourne (aucun client local attaché) |
| `stopped` | la session tmux existe mais Claude s'est arrêté |
| `idle` | un projet `.claude/` existe sous `BASE_DIR` mais aucune session tmux claude-mux n'est en cours (visible uniquement avec `-L`) |

Un `*` à la fin d'un statut indique que la session est protégée et nécessite `--force` pour être arrêtée (par exemple `active*`, `running*`). La session principale est toujours protégée.

Lancer `claude-mux` dans un répertoire qui a déjà une session en cours s'y attache. Plusieurs terminaux peuvent s'attacher à la même session (comportement standard de tmux).

## Configuration

Au premier lancement, `~/.claude-mux/config` est créé automatiquement avec tous les paramètres en commentaires. Modifiez-le pour surcharger les valeurs par défaut -- le script lui-même n'a jamais besoin d'être modifié directement.

| Variable | Valeur par défaut | Description |
|----------|-------------------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Répertoire racine à scanner pour trouver les projets Claude (répertoires contenant `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Répertoire pour le fichier `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Définit `permissions.defaultMode` de Claude dans chaque projet. Valeurs valides : `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Mettez `""` pour désactiver. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Quand `true`, les sessions Claude peuvent envoyer des slash commands à d'autres sessions. Utile pour l'orchestration multi-agent. |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Répertoire contenant les fichiers modèles CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | Modèle par défaut appliqué aux nouveaux projets (`-n`). Mettez `""` pour désactiver. |
| `SLEEP_BETWEEN` | `5` | Secondes entre les lancements de session quand `-a` est utilisé. À augmenter si l'enregistrement RC échoue. |
| `HOME_SESSION_MODEL` | `""` | Modèle pour la session principale. Valeurs valides : `sonnet`, `haiku`, `opus`. Vide hérite de la valeur par défaut de Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Liste de fichiers séparés par des espaces à créer comme liens symboliques vers `CLAUDE.md` pour d'autres outils CLI d'IA. Mettez `""` pour désactiver. |
| `LAUNCHAGENT_MODE` | `home` | Comportement du LaunchAgent à l'ouverture de session : `none` (ne rien faire) ou `home` (lance la session principale protégée). L'ancienne valeur `LAUNCHAGENT_ENABLED=true` est traitée comme `home`. |

**Options de session tmux** (toutes configurables, toutes activées par défaut) :

| Variable | Valeur par défaut | Description |
|----------|-------------------|-------------|
| `TMUX_MOUSE` | `true` | Prise en charge de la souris : défilement, sélection, redimensionnement de panneaux |
| `TMUX_HISTORY_LIMIT` | `50000` | Taille du buffer de défilement en lignes (la valeur par défaut de tmux est 2000) |
| `TMUX_CLIPBOARD` | `true` | Intégration du presse-papiers système via OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Type de terminal pour un rendu correct des couleurs |
| `TMUX_EXTENDED_KEYS` | `true` | Séquences de touches étendues, dont Shift+Enter (nécessite tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | Délai de la touche Échap en millisecondes (la valeur par défaut de tmux est 500) |
| `TMUX_TITLE_FORMAT` | `#S` | Format du titre de terminal/onglet (`#S` = nom de session, `""` pour désactiver) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Notifie quand une activité survient dans d'autres sessions |

## Structure des répertoires

Les projets sont découverts par la présence d'un répertoire `.claude/`, à n'importe quelle profondeur :

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ a .claude/ - géré
│   │   └── .claude/
│   ├── project-b/          # ✓ a .claude/ - géré
│   │   └── .claude/
│   └── -archived/          # ✗ exclu (commence par -)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ a .claude/ - géré
│   │   └── .claude/
│   ├── .hidden/            # ✗ exclu (répertoire caché)
│   │   └── .claude/
│   └── project-d/          # ✗ pas de .claude/ - n'est pas un projet Claude
├── deep/nested/project-e/  # ✓ a .claude/ - trouvé à n'importe quelle profondeur
│   └── .claude/
└── ignored-project/        # ✗ exclu (.ignore-claudemux)
    ├── .claude/
    └── .ignore-claudemux
```

Les noms de session sont dérivés des noms de répertoire : les espaces deviennent des tirets, les caractères non alphanumériques (sauf les tirets) sont remplacés, et les tirets en début/fin sont supprimés. Les répertoires dont le nom assaini est vide sont ignorés avec un avertissement dans le log.

## System prompt de session

Chaque session Claude est lancée avec `--append-system-prompt` contenant le contexte de son environnement :

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

Quand `ALLOW_CROSS_SESSION_CONTROL=true`, la commande d'envoi change pour permettre de cibler n'importe quelle session, pas seulement elle-même. Le chemin est le chemin absolu vers le script au moment du lancement, donc les sessions ne dépendent pas de `PATH`.

## Référence CLI

Vous avez rarement besoin de ces commandes directement -- Claude les exécute pour vous depuis les sessions. Elles sont disponibles pour les scripts, l'automatisation ou quand vous n'êtes pas dans une session.

```bash
# Lancer et s'attacher
claude-mux                       # lance Claude dans le répertoire courant et s'attache
claude-mux ~/projets/mon-app     # lance Claude dans un répertoire et s'attache
claude-mux -d ~/projets/mon-app  # identique (forme explicite)
claude-mux -t my-app             # s'attache à une session tmux existante

# Créer de nouveaux projets
claude-mux -n ~/projets/app     # crée un nouveau projet Claude et s'attache
claude-mux -n ~/new/path/app -p  # idem, en créant le répertoire et ses parents
claude-mux -n ~/app --template web        # nouveau projet avec un modèle CLAUDE.md spécifique
claude-mux -n ~/app --no-multi-coder      # nouveau projet sans liens symboliques AGENTS.md/GEMINI.md

# Gestion des sessions
claude-mux -l                    # liste les sessions par statut (active, running, stopped)
claude-mux -L                    # liste tous les projets (actifs + inactifs)
claude-mux -s my-app '/model sonnet'      # envoie une slash command à une session
claude-mux --shutdown my-app              # arrête une session spécifique
claude-mux --shutdown                     # arrête toutes les sessions gérées
claude-mux --shutdown home --force        # arrête la session principale protégée
claude-mux --restart my-app              # redémarre une session spécifique
claude-mux --restart                     # redémarre toutes les sessions en cours
claude-mux --permission-mode plan my-app  # redémarre la session en mode plan
claude-mux -a                    # démarre toutes les sessions gérées sous BASE_DIR

# Autre
claude-mux --list-templates      # affiche les modèles CLAUDE.md disponibles
claude-mux --guide               # affiche les commandes conversationnelles à utiliser dans les sessions
claude-mux --dry-run             # prévisualise les actions sans les exécuter
claude-mux --version             # affiche la version
claude-mux --help                # affiche toutes les options

# Suivre le journal
tail -f ~/Library/Logs/claude-mux.log
```

Lorsqu'il est exécuté depuis le terminal, la sortie est dupliquée vers stdout en temps réel. Lorsqu'il est exécuté via le LaunchAgent, la sortie va uniquement dans le fichier de log.

## Dépannage

### Les sessions affichent « Not logged in · Run /login »

Cela arrive au premier lancement si le keychain de macOS est verrouillé (fréquent quand le script tourne avant que le keychain soit déverrouillé après l'ouverture de session). Solution :

```bash
# Déverrouiller le keychain dans un terminal classique
security unlock-keychain

# Puis terminer l'authentification dans n'importe quelle session en cours
claude-mux -t <any-session>
# Lancer /login et compléter le flux dans le navigateur
```

Une fois l'authentification faite, fermez et relancez toutes les sessions -- elles récupéreront automatiquement les identifiants stockés.

### Sessions absentes de Claude Code Remote

Les sessions doivent être authentifiées (ne pas afficher « Not logged in »). Après un lancement propre et authentifié, elles devraient apparaître dans la liste RC en quelques secondes.

### Saisie multiligne dans tmux

La commande `/terminal-setup` ne peut pas tourner dans tmux. claude-mux active les `extended-keys` de tmux par défaut (`TMUX_EXTENDED_KEYS=true`), ce qui prend en charge Shift+Enter dans la plupart des terminaux modernes. Si Shift+Enter ne fonctionne pas, utilisez `\` + Entrée pour insérer des sauts de ligne dans votre prompt.

### « Ready. » au démarrage de session

Quand une session démarre ou redémarre, claude-mux envoie automatiquement un message `ready` après le chargement de Claude. L'injection indique à Claude de répondre « Ready. » et rien d'autre. Cela confirme que la session est active et que l'injection fonctionne.

### Slash commands via Remote Control

Les slash commands (par exemple `/model`, `/clear`) [ne sont pas prises en charge nativement](https://github.com/anthropics/claude-code/issues/30674) dans les sessions RC. claude-mux contourne ce problème -- chaque session reçoit l'injection de `claude-mux -s` afin que Claude puisse s'envoyer des slash commands à lui-même via tmux.

## Logs

- `~/Library/Logs/claude-mux.log` -- toutes les actions du script avec horodatage UTC (configurable via `LOG_DIR`)

Pour le débogage bas niveau du LaunchAgent, utilisez Console.app ou `log show`.
