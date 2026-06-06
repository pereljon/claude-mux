# FAQ

[English](../docs/FAQ.md) · [Español](FAQ.es.md) · **Français** · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## Qu'est-ce que claude-mux ?

Un script shell qui enveloppe Claude Code dans tmux pour des sessions persistantes. Les sessions survivent à la fermeture des terminaux, reprennent le contexte de conversation au redémarrage, et sont accessibles depuis l'app mobile Claude via Remote Control. Vous gérez tout en parlant à Claude à l'intérieur d'une session.

## Est-ce que ça fonctionne sur Linux ?

Pas encore. macOS uniquement (Apple Silicon et Intel). Le support Linux est prévu pour la v2.0. L'installateur s'exécute sur Linux mais ignore la configuration du LaunchAgent et affiche une note. Le binaire lui-même fonctionne, mais il n'y a pas encore de service systemd ou de mécanisme équivalent de démarrage automatique.

## Qu'est-ce que la session home ?

La session home est une session Claude polyvalente qui vit dans votre répertoire de base (`~/Claude` par défaut). Quand `LAUNCHAGENT_MODE=home` (la valeur par défaut), elle se lance automatiquement à la connexion et reste active toute la journée. Elle est **protégée** par défaut, ce qui signifie que `--shutdown home` refuse de l'arrêter sans `--force`.

Utilisez la session home comme votre point d'entrée toujours disponible depuis l'app mobile Claude. De là, vous pouvez lister les projets, démarrer d'autres sessions, gérer la configuration et faire du travail général qui n'appartient pas à un projet spécifique.

## Qu'est-ce que Remote Control ?

Remote Control (RC) est une fonctionnalité de Claude Code qui permet de se connecter à une session Claude active depuis l'app mobile Claude ou Claude Desktop. claude-mux lance chaque session avec `--remote-control` activé, donc toutes les sessions apparaissent automatiquement dans la liste RC. Une fois connecté, vous parlez à Claude de la même façon que dans un terminal. claude-mux contourne aussi les limitations de RC comme les commandes slash qui ne fonctionnent pas nativement, en les routant via tmux.

## Que sont les modes de permissions ?

Claude Code a quatre modes de permissions qui contrôlent le niveau d'autonomie de Claude :

| Mode | Comportement |
|------|-------------|
| `default` | Claude demande avant d'exécuter des commandes ou de modifier des fichiers |
| `acceptEdits` | Claude applique les modifications automatiquement mais demande avant les commandes shell |
| `plan` | Claude peut seulement lire et planifier, pas d'écritures ni de commandes |
| `bypassPermissions` | Claude exécute tout sans demander (nécessite une confirmation au premier lancement) |

Définissez la valeur par défaut pour tous les projets via `DEFAULT_PERMISSION_MODE` dans la config. Changez une session active en disant "passe cette session en mode plan" (ou tout nom de mode). "yolo" est un alias pour `bypassPermissions`.

Passer à `bypassPermissions` depuis un autre mode utilise la navigation Shift+Tab et ne nécessite pas de redémarrage. Passer de `bypassPermissions` à un autre mode nécessite un redémarrage, que claude-mux gère automatiquement.

## Comment réinitialiser une session ?

Trois options, selon ce que vous voulez :

- **Effacer** ("efface cette session") : envoie `/clear` à la session. Supprime l'historique de conversation et repart à zéro. La session reste active.
- **Compacter** ("compacte cette session") : envoie `/compact` à la session. Résume la conversation en un contexte plus court, libérant la fenêtre de contexte. L'historique est préservé sous forme compressée.
- **Redémarrer** ("redémarre cette session") : arrête Claude et le relance avec `claude -c`, qui reprend la dernière conversation. Utilisez ceci quand vous avez besoin d'un processus propre (ex. après un changement de mode de permissions ou quand Claude est bloqué).

## Que sont les templates ?

Les templates sont des fichiers CLAUDE.md réutilisables stockés dans `~/.claude-mux/templates/`. Quand vous créez un nouveau projet avec `-n`, le template par défaut (ou celui que vous spécifiez avec `--template NAME`) est copié dans le projet comme CLAUDE.md.

Créer un template : "sauvegarde ça comme template nommé web" (copie le CLAUDE.md du projet actuel vers `~/.claude-mux/templates/web.md`).

Utiliser un template : `claude-mux -n ~/projets/my-app --template web` ou depuis une session : "crée un nouveau projet appelé my-app avec le template web".

Lister les templates : "lister les templates" ou `claude-mux --list-templates`.

## Comment fonctionne le conseil du jour ?

Un hook `UserPromptSubmit` de Claude Code dans le `.claude/settings.local.json` de chaque projet appelle `claude-mux --on-prompt` à chaque invite. La première invite de la journée injecte un conseil dans la conversation ; les invites suivantes de la journée n'injectent rien. L'état est par session, stocké dans `~/.claude-mux/tip-state/<session_id>.json`, donc chaque session active affiche le conseil une fois par jour. Comme le hook injecte dans le contexte (pas un hook Stop, dont la sortie ne va que dans le transcript), le conseil est visible dans la conversation et dans Remote Control.

Les conseils sont activés par défaut (`TIP_OF_DAY=true`). Basculez avec "activer les conseils" ou "désactiver les conseils" dans n'importe quelle session. `TIP_MODE=daily` affiche le même conseil toute la journée ; `TIP_MODE=random` choisit un conseil aléatoire.

La commande `--tip` fonctionne toujours indépendamment de la porte quotidienne (et indépendamment de `TIP_OF_DAY`), donc vous pouvez dire "conseil" à tout moment.

## Puis-je utiliser ceci avec plusieurs comptes GitHub ?

Oui. claude-mux détecte les entrées `Host github.com-*` dans `~/.ssh/config` et les injecte dans le prompt système de chaque session. Claude sait quels alias SSH sont disponibles et peut utiliser le bon pour configurer les remotes git.

Exemple de configuration `~/.ssh/config` :

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

Claude saura alors utiliser `git@github.com-work:org/repo.git` pour les repos professionnels et `git@github.com-personal:user/repo.git` pour les personnels.

## Où est stocké l'état ?

| Emplacement | Contenu |
|------------|---------|
| `~/.claude-mux/config` | Configuration utilisateur (chargée comme bash) |
| `~/.claude-mux/templates/` | Fichiers de template CLAUDE.md |
| `~/.claude-mux/tip-state/<session_id>.json` | Date du conseil par session + limitation des avis de mise à jour |
| `~/.claude-mux/.update-check` | Résultat mis en cache de la vérification de version |
| `~/.claude-mux/.update-checking` | Verrou pendant la vérification de mise à jour en arrière-plan |
| `~/Library/Logs/claude-mux.log` | Fichier de log (configurable via `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | Plist du LaunchAgent (généré par `--install`) |
| `.claudemux-protected` (par projet) | Marque une session comme protégée contre l'arrêt |
| `.claudemux-ignore` (par projet) | Masque un projet des listings |

Les fichiers marqueurs (`.claudemux-*`) vivent dans le répertoire racine de chaque projet et suivent le dossier lors des renommages, déplacements et synchronisations. Ils sont automatiquement ajoutés au `.gitignore`.

L'historique de conversation est géré par Claude Code lui-même, stocké sous `~/.claude/projects/`.

## Que se passe-t-il avec la mise à jour automatique si je fork claude-mux ?

La vérification de mise à jour et la commande `--update` ont `pereljon/claude-mux` codé en dur comme repo GitHub. Si vous forkez, les vérifications de mise à jour compareront toujours avec la version upstream, et `--update` écrasera le binaire de votre fork avec celui d'upstream. Configurez `UPDATE_CHECK=false` dans `~/.claude-mux/config` pour désactiver, ou changez l'URL du repo dans les fonctions `check_for_update()` et `do_update()` du script.

## Comment installer via Homebrew ?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Mettez à jour avec `brew upgrade claude-mux`. Note : si vous avez installé via Homebrew, `--update` délègue à `brew upgrade` automatiquement.

## En quoi est-ce différent de `claude --worktree --tmux` ?

`claude --worktree --tmux` crée une session tmux pour un worktree git isolé, conçu pour des tâches de codage en parallèle. claude-mux gère des sessions persistantes pour vos vrais répertoires de projet, avec Remote Control activé, injection de prompt système pour l'autogestion, reprise de conversation et gestion du cycle de vie des sessions. Ils résolvent des problèmes différents.

## En quoi est-ce différent de Claude Cowork Dispatch ?

Dispatch lance des tâches depuis l'app desktop de Claude, mais nécessite que l'app soit ouverte et n'est pas lié à un projet spécifique. claude-mux gère des sessions persistantes liées aux projets qui survivent aux redémarrages et sont accessibles de partout via Remote Control - sans besoin de l'app desktop.

## Pourquoi les sessions affichent "Not logged in" ?

Cela arrive au premier lancement si le trousseau macOS est verrouillé, ce qui est courant quand le LaunchAgent démarre avant que vous ne déverrouilliez le trousseau après la connexion. Corrigez en exécutant `security unlock-keychain` dans un terminal normal, puis connectez-vous à n'importe quelle session (`claude-mux -t <nom>`) et exécutez `/login` pour compléter le flux d'authentification navigateur. Ensuite, redémarrez toutes les sessions et elles récupéreront les identifiants stockés.

## Plusieurs terminaux peuvent-ils se connecter à la même session ?

Oui. C'est le comportement standard de tmux. Exécuter `claude-mux` dans un répertoire qui a déjà une session active s'y connecte. Plusieurs terminaux voient le même contenu de session en temps réel.

## Comment arrêter la session home définitivement ?

Le LaunchAgent a `KeepAlive: true`, donc tuer la session home déclenche un redémarrage dans environ 60 secondes. Pour l'arrêter définitivement, désactivez le LaunchAgent :

```bash
claude-mux --install --launchagent-mode none
```

## Que signifie le message "Session ready!" ?

Quand une session démarre ou redémarre, claude-mux envoie un prompt `Ready?` après que Claude a fini de charger. L'injection dit à Claude de répondre avec "Session ready!" et rien d'autre. Cela confirme que la session est vivante et que l'injection du prompt système fonctionne. Vous pouvez l'ignorer.

## Comment masquer un projet des listings ?

Dites "masque ce projet" dans n'importe quelle session, ou exécutez `claude-mux --hide mon-projet`. Cela crée un fichier marqueur `.claudemux-ignore`. Le projet n'apparaîtra pas dans la sortie de `claude-mux -L`. Pour voir les projets masqués : `claude-mux -L --hidden`. Pour afficher : "montre ce projet" ou `claude-mux --show mon-projet`.

## Comment désinstaller claude-mux ?

```bash
claude-mux --uninstall
```

Cela supprime les hooks de conseils et les règles de permissions de tous les projets, décharge le LaunchAgent, et supprime optionnellement `~/.claude-mux/`. La commande affiche le chemin du binaire pour que vous puissiez le supprimer manuellement (ou `brew uninstall claude-mux` si installé via Homebrew).

## Les commandes slash fonctionnent-elles sur Remote Control ?

Pas nativement. Claude Code ne supporte pas les commandes slash (`/model`, `/clear`, etc.) dans les sessions RC. claude-mux contourne cela en injectant chaque session avec `claude-mux -s` pour que Claude puisse envoyer des commandes slash à lui-même via tmux. Dites simplement "passe à Haiku" ou "compacte cette session" et Claude s'en charge.

## Je ne peux pas sélectionner du texte dans une session

Maintenez **Option** (macOS) ou **Shift** (terminaux Linux/Windows) en cliquant et glissant. Cela contourne la capture de souris de tmux et copie la sélection dans le presse-papiers système. Aucun changement de configuration nécessaire.

## Quelles langues sont supportées pour les commandes conversationnelles ?

Toutes. Les phrases de déclenchement ("help", "status", "list sessions", etc.) fonctionnent dans n'importe quelle langue. Claude infère l'intention du langage naturel de l'utilisateur et exécute la commande correspondante. Le README est aussi traduit en 12 langues.
