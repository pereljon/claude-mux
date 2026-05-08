# FAQ

[English](../FAQ.md) · [Español](FAQ.es.md) · **Français** · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## Qu'est-ce que claude-mux ?

Un script shell qui encapsule Claude Code dans tmux pour des sessions persistantes. Les sessions survivent a la fermeture du terminal, reprennent le contexte de conversation au redemarrage, et sont accessibles depuis l'application mobile Claude via Remote Control. Vous gerez tout en parlant a Claude depuis une session.

## Est-ce que ca fonctionne sous Linux ?

Pas encore. macOS uniquement (Apple Silicon et Intel). Le support Linux est prevu pour la v2.0. L'installeur fonctionne sous Linux mais ignore la configuration du LaunchAgent et affiche une note. Le binaire lui-meme fonctionne, mais il n'y a pas encore de service systemd ni de mecanisme de demarrage automatique equivalent.

## Qu'est-ce que la session principale ?

La session principale est une session Claude generaliste qui vit dans votre repertoire de base (`~/Claude` par defaut). Quand `LAUNCHAGENT_MODE=home` (la valeur par defaut), elle se lance automatiquement a l'ouverture de session et reste active toute la journee. Elle est **protegee** par defaut, ce qui signifie que `--shutdown home` refuse de l'arreter sans `--force`.

Utilisez la session principale comme point d'entree toujours disponible depuis l'application mobile Claude. De la, vous pouvez lister les projets, demarrer d'autres sessions, gerer la config et faire du travail general qui n'appartient a aucun projet specifique.

## Qu'est-ce que Remote Control ?

Remote Control (RC) est une fonctionnalite de Claude Code qui permet de se connecter a une session Claude en cours depuis l'application mobile Claude ou Claude Desktop. claude-mux lance chaque session avec `--remote-control` active, donc toutes les sessions apparaissent automatiquement dans la liste RC. Une fois connecte, vous parlez a Claude de la meme maniere que dans un terminal. claude-mux contourne aussi les limitations de RC comme le fait que les slash commands ne fonctionnent pas nativement, en les acheminant via tmux.

## Que sont les modes de permission ?

Claude Code a quatre modes de permission qui controlent le degre d'autonomie de Claude :

| Mode | Comportement |
|------|-------------|
| `default` | Claude demande avant d'executer des commandes ou de modifier des fichiers |
| `acceptEdits` | Claude applique automatiquement les modifications de fichiers mais demande avant les commandes shell |
| `plan` | Claude peut uniquement lire et planifier, pas d'ecriture ni de commandes |
| `bypassPermissions` | Claude execute tout sans demander (necessite une confirmation au premier lancement) |

Definissez la valeur par defaut pour tous les projets via `DEFAULT_PERMISSION_MODE` dans la config. Changez le mode d'une session en cours en disant "switch this session to plan mode" (ou tout autre nom de mode). "yolo" est un alias pour `bypassPermissions`.

Passer en `bypassPermissions` depuis un autre mode utilise la navigation Shift+Tab et ne necessite pas de redemarrage. Passer de `bypassPermissions` a un autre mode necessite un redemarrage, que claude-mux gere automatiquement.

## Comment reinitialiser une session ?

Trois options, selon ce que vous voulez :

- **Clear** ("clear this session") : envoie `/clear` a la session. Efface l'historique de conversation et repart de zero. La session reste active.
- **Compact** ("compact this session") : envoie `/compact` a la session. Resume la conversation en un contexte plus court, liberant la fenetre de contexte. L'historique est preserve sous forme comprimee.
- **Restart** ("restart this session") : arrete Claude et le relance avec `claude -c`, qui reprend la derniere conversation. A utiliser quand vous avez besoin d'un processus propre (par exemple apres un changement de mode de permission ou quand Claude est bloque).

## Que sont les templates ?

Les templates sont des fichiers CLAUDE.md reutilisables stockes dans `~/.claude-mux/templates/`. Quand vous creez un nouveau projet avec `-n`, le template par defaut (ou celui que vous specifiez avec `--template NAME`) est copie dans le projet comme CLAUDE.md.

Creer un template : "save this as a template named web" (copie le CLAUDE.md du projet courant vers `~/.claude-mux/templates/web.md`).

Utiliser un template : `claude-mux -n ~/projets/my-app --template web` ou depuis une session : "create a new project called my-app using the web template".

Lister les templates : "list templates" ou `claude-mux --list-templates`.

## Comment fonctionne le tip-of-the-day ?

Un hook Stop de Claude Code dans le fichier `.claude/settings.local.json` de chaque projet appelle `claude-mux --tipotd` apres chaque tour de conversation. La commande verifie si une astuce a deja ete affichee aujourd'hui (via `~/.claude-mux/.tip-date`). Si oui, elle se termine en environ 6ms. Sinon, elle affiche une astuce et enregistre la date du jour.

Les astuces sont activees par defaut (`TIP_OF_DAY=true`). Activez ou desactivez avec "enable tips" ou "disable tips" dans n'importe quelle session. `TIP_MODE=daily` affiche la meme astuce toute la journee ; `TIP_MODE=random` choisit une astuce aleatoire par invocation (avec le hook Stop, cela signifie une astuce aleatoire par jour grace au filtre quotidien).

La commande `--tip` fonctionne toujours independamment du filtre quotidien, vous pouvez donc dire "tip" a tout moment.

## Peut-on l'utiliser avec plusieurs comptes GitHub ?

Oui. claude-mux detecte les entrees `Host github.com-*` dans `~/.ssh/config` et les injecte dans le system prompt de chaque session. Claude sait quels alias SSH sont disponibles et peut utiliser le bon lors de la configuration des remotes git.

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

Claude saura alors utiliser `git@github.com-work:org/repo.git` pour les repos professionnels et `git@github.com-personal:user/repo.git` pour les repos personnels.

## Ou est stocke l'etat ?

| Emplacement | Contenu |
|-------------|---------|
| `~/.claude-mux/config` | Configuration utilisateur (source en tant que bash) |
| `~/.claude-mux/templates/` | Fichiers templates CLAUDE.md |
| `~/.claude-mux/.tip-date` | Date de la derniere astuce affichee |
| `~/.claude-mux/.update-check` | Resultat de la verification de version en cache |
| `~/Library/Logs/claude-mux.log` | Fichier de log (configurable via `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | Plist du LaunchAgent (genere par `--install`) |
| `.claudemux-protected` (par projet) | Marque une session comme protegee contre l'arret |
| `.claudemux-ignore` (par projet) | Masque un projet des listes |

Les fichiers marqueurs (`.claudemux-*`) se trouvent a la racine de chaque projet et suivent le dossier lors de renommages, deplacements et synchronisations. Ils sont automatiquement ajoutes au `.gitignore`.

L'historique de conversation est gere par Claude Code lui-meme, stocke dans `~/.claude/projects/`.

## Que se passe-t-il avec la mise a jour automatique si je fork claude-mux ?

La verification de mise a jour et la commande `--update` codent en dur `pereljon/claude-mux` comme repo GitHub. Si vous le forkez, les verifications de mise a jour compareront toujours avec la release upstream, et `--update` ecrasera le binaire de votre fork avec celui d'upstream. Definissez `UPDATE_CHECK=false` dans `~/.claude-mux/config` pour desactiver, ou modifiez l'URL du repo dans les fonctions `check_for_update()` et `do_update()` du script.

## Comment installer via Homebrew ?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Mettez a jour avec `brew upgrade claude-mux`. Note : si vous avez installe via Homebrew, `--update` delegue automatiquement a `brew upgrade`.

## En quoi est-ce different de `claude --worktree --tmux` ?

`claude --worktree --tmux` cree une session tmux pour un git worktree isole, concu pour des taches de codage en parallele. claude-mux gere des sessions persistantes pour vos repertoires de projet reels, avec Remote Control active, injection de system prompt pour l'autogestion, reprise de conversation et gestion du cycle de vie des sessions. Ils resolvent des problemes differents.

## Pourquoi les sessions affichent "Not logged in" ?

Cela arrive au premier lancement si le keychain de macOS est verrouille, ce qui est frequent quand le LaunchAgent demarre avant que vous deverrouilliez le keychain apres l'ouverture de session. Corrigez en executant `security unlock-keychain` dans un terminal classique, puis attachez-vous a n'importe quelle session (`claude-mux -t <nom>`) et executez `/login` pour completer le flux d'authentification dans le navigateur. Apres cela, redemarrez toutes les sessions et elles recupereront les identifiants stockes.

## Plusieurs terminaux peuvent-ils s'attacher a la meme session ?

Oui. C'est le comportement standard de tmux. Lancer `claude-mux` dans un repertoire qui a deja une session en cours s'y attache. Plusieurs terminaux voient le meme contenu de session en temps reel.

## Comment arreter la session principale definitivement ?

Le LaunchAgent a `KeepAlive: true`, donc tuer la session principale declenche une relance dans les 60 secondes environ. Pour l'arreter definitivement, desactivez le LaunchAgent :

```bash
claude-mux --install --launchagent-mode none
```

## Que signifie le message "Session ready!" ?

Quand une session demarre ou redemarre, claude-mux envoie un prompt `Ready?` apres le chargement de Claude. L'injection indique a Claude de repondre "Session ready!" et rien d'autre. Cela confirme que la session est active et que l'injection de system prompt fonctionne. Vous pouvez l'ignorer.

## Comment masquer un projet des listes ?

Dites "hide this project" dans n'importe quelle session, ou executez `claude-mux --hide my-project`. Cela cree un fichier marqueur `.claudemux-ignore`. Le projet n'apparaitra plus dans la sortie de `claude-mux -L`. Pour voir les projets masques : `claude-mux -L --hidden`. Pour reafficher : "show this project" ou `claude-mux --show my-project`.

## Comment desinstaller claude-mux ?

```bash
claude-mux --uninstall
```

Cela supprime les hooks d'astuces et les regles de permission de tous les projets, decharge le LaunchAgent, et supprime optionnellement `~/.claude-mux/`. Le chemin du binaire est affiche pour que vous puissiez le supprimer manuellement (ou `brew uninstall claude-mux` si installe via Homebrew).

## Les slash commands fonctionnent-elles via Remote Control ?

Pas nativement. Claude Code ne prend pas en charge les slash commands (`/model`, `/clear`, etc.) dans les sessions RC. claude-mux contourne ce probleme en injectant dans chaque session `claude-mux -s` pour que Claude puisse s'envoyer des slash commands a lui-meme via tmux. Dites simplement "switch to Haiku" ou "compact this session" et Claude s'en charge.

## Je ne peux pas selectionner du texte dans une session

Maintenez **Option** (macOS) ou **Shift** (terminaux Linux/Windows) en cliquant et glissant. Cela contourne la capture de souris de tmux et copie la selection dans votre presse-papiers systeme. Aucun changement de configuration necessaire.

## Quelles langues sont supportees pour les commandes conversationnelles ?

Toutes. Les phrases declencheuses ("help", "status", "list sessions", etc.) fonctionnent dans n'importe quelle langue. Claude deduit l'intention a partir du langage naturel de l'utilisateur et execute la commande correspondante. Le README est aussi traduit en 12 langues.
