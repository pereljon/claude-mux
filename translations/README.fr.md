# claude-mux - Multiplexeur Claude Code

[English](../README.md) · [Español](README.es.md) · **Français** · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Sessions persistantes de Claude Code pour tous vos projets - accessibles de partout via l'app mobile Claude. ***Géré par Claude !***

## Installer

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Puis lancez une session :

```bash
claude-mux ~/chemin/vers/votre/projet
```

L'installateur demande si vous voulez une session home au démarrage. Si vous acceptez, une session protégée de Claude se lance automatiquement à chaque connexion - toujours accessible depuis votre téléphone ou tout client Remote Control, même si vous n'ouvrez jamais de terminal.

C'est tout ! Vous êtes dans une session persistante de Claude avec détection de session et Remote Control activé. **À partir d'ici, tout est conversationnel.**

[Homebrew, installation manuelle et autres options](../docs/INSTALL.md)

## Pourquoi

Remote Control promet Claude Code de partout - mais sans gestion de sessions, c'est une interface de second ordre même depuis Claude Desktop :

- **Les sessions meurent** quand vous fermez le terminal - et ne reviennent pas après un plantage ou un redémarrage
- **Le contexte de conversation** ne reprend pas automatiquement
- **Pas de base** - rien ne tourne quand vous prenez votre téléphone sauf si vous avez laissé quelque chose ouvert
- **Remote Control nécessite une session active** - vous ne pouvez pas en démarrer une depuis RC
- **Les commandes slash ne marchent pas dans les sessions RC** - pas de changement de modèle, de compactage ou de changement de mode de permissions
- **Démarrer de nouveaux projets** - nécessite de créer un répertoire manuellement, d'initialiser git, d'écrire un fichier d'instructions (AGENTS.md ou CLAUDE.md) et de choisir un modèle
- **Pas de gestion de projets** - aucun moyen de voir les projets inactifs, ni de renommer, déplacer ou supprimer des projets sans casser l'historique

**claude-mux comble le manque de gestion de sessions.** Il enveloppe Claude Code dans tmux pour que les sessions persistent, les restaure automatiquement après les plantages et les redémarrages (tant que la connexion automatique est activée), injecte un prompt système pour que Claude gère ses propres sessions, et route les commandes slash via tmux pour qu'elles fonctionnent sur Remote Control. Une fois qu'une session tourne, vous gérez tout en parlant à Claude - dans le terminal ou l'app mobile.

## Ce que vous pouvez faire dans une session claude-mux

- **Survit aux plantages et aux redémarrages** - les sessions sont restaurées automatiquement à votre reconnexion et reprennent la dernière conversation. Un `/exit` propre ou un arrêt garde la session arrêtée ; une session qui plante en boucle est arrêtée et signalée au lieu d'être relancée indéfiniment.
- **Gérer n'importe quelle session depuis n'importe quelle session** - démarrer, arrêter, redémarrer, lister et compacter des projets en langage naturel
- **Accéder à tout de partout** - chaque session a Remote Control activé, donc l'app mobile Claude, l'app desktop ou tout client distant est une interface complète
- **Changer de modèle et de mode de permissions** - dites "passe à Haiku" ou "passe en mode plan" et Claude s'en charge, même sur Remote Control
- **Créer de nouveaux projets** - "crée un nouveau projet appelé my-app" configure le répertoire, git, un AGENTS.md issu d'un template et lance une session. Les templates permettent de réutiliser les instructions entre projets.
- **Envoyer des commandes slash via Remote Control** - Claude route `/model`, `/compact`, `/clear` et d'autres commandes slash vers la session active, contournant une [limitation connue](https://github.com/anthropics/claude-code/issues/30674). RC se reconnecte automatiquement après `/compact` via un hook `PreCompact`.
- **Détection des mises à jour de Claude Code** - quand le binaire `claude` change (après `brew upgrade` ou une mise à jour npm), les sessions en cours affichent un avis pour redémarrer et charger le nouveau binaire ; il persiste d'un prompt à l'autre jusqu'au redémarrage, donc un tour manqué ne le fait pas disparaître
- **Préserver l'historique de conversation** - renommer, déplacer et redémarrer des projets préservent l'historique de conversation automatiquement
- **Organiser les projets** - masquer, renommer, déplacer, supprimer et protéger des projets depuis n'importe quelle session
- **Support multi-compte GitHub** - détecte les alias SSH dans `~/.ssh/config` et les injecte dans les sessions pour que Claude utilise le bon compte par projet
- **AGENTS.md comme fichier d'instructions du projet** - `AGENTS.md` est l'unique vrai fichier, lu par Claude Code et Codex CLI. Dites "migre vers AGENTS.md" pour convertir une arborescence existante depuis `CLAUDE.md` (rapport d'abord, rien n'est commité). Nécessite Claude Code 2.1.277 ou plus récent ; les versions antérieures gardent `CLAUDE.md`. Gemini CLI ne le lit que si `~/.gemini/settings.json` contient `"context": {"fileName": ["AGENTS.md"]}`.
- **Fonctionne dans toutes les langues** - les commandes conversationnelles sont inférées par intention, pas par mots-clés

## Parler à Claude

Voici comment vous utilisez claude-mux au quotidien. Chaque session est injectée avec des commandes pour que Claude puisse gérer les sessions, changer de modèle, envoyer des commandes slash et créer de nouveaux projets - tout depuis la conversation. Pas besoin de retenir les flags CLI.

```
Dites : "statut"
Rapporte le nom de session, le modèle, le mode de permissions, l'utilisation du contexte et liste toutes les sessions

Dites : "lister les sessions actives"
Affiche toutes les sessions en cours avec leur statut

Dites : "lister les sessions inactives"
Affiche uniquement les projets inactifs

Dites : "lister les sessions arrêtées"
Affiche uniquement les sessions arrêtées

Dites : "lance une session pour mon projet api-server"
Démarre la session par son nom ; sans effet si elle tourne déjà

Dites : "crée un nouveau projet appelé mobile-app avec le template web"
Crée le répertoire du projet, initialise git, applique le template, lance une session

Dites : "passe cette session à Haiku"
Résout la famille vers le dernier ID concret et s'envoie /model claude-haiku-4-5

Dites : "compacte la session api-server"
Envoie /compact à la session api-server

Dites : "redémarre la session web-dashboard"
Arrête et relance la session, en préservant le contexte de conversation

Dites : "redémarre cette session à zéro"
Demande confirmation, puis redémarre avec une nouvelle conversation - sans reprise, sans contexte antérieur

Dites : "tue la session api-server"
Demande confirmation, puis efface la conversation et l'arrête ; le prochain démarrage est une nouvelle conversation, pas une reprise

Dites : "termine cette session"
Sauvegarde d'abord le travail inachevé et la prochaine étape, demande confirmation (et si quelque chose n'est pas sauvegardé), puis redémarre à zéro

Dites : "passe la session api-server en mode plan"
Redémarre la session avec le mode de permissions plan

Dites : "passe cette session en mode yolo"
Passe en mode bypassPermissions via Shift+Tab - pas de redémarrage nécessaire

Dites : "quel mode pour cette session"
Rapporte le mode de permissions actuel (default, acceptEdits, plan, bypassPermissions)

Dites : "passe cette session à Opus"
Résout la famille vers le dernier ID concret et s'envoie /model claude-opus-4-8

Dites : "efface cette session"
Demande confirmation, puis s'envoie /clear, réinitialisant la conversation

Dites : "masque ce projet"
Écrit .claudemux-ignore pour que le projet soit exclu des listings -L

Dites : "protège cette session"
Écrit .claudemux-protected et définit le marqueur tmux - l'arrêt nécessite maintenant --force

Dites : "cette session est protégée ?"
Vérifie .claudemux-protected dans le dossier du projet et rapporte

Dites : "supprime le projet old-prototype"
Confirme dans le chat, puis déplace le dossier du projet vers la corbeille système

Dites : "renomme ce projet en my-new-name"
Arrête la session, renomme le dossier, migre l'historique de conversation, redémarre

Dites : "sauvegarde ça comme template nommé web"
Copie AGENTS.md (ou CLAUDE.md) vers ~/.claude-mux/templates/web.md

Dites : "vérifie la migration agents" / "migre vers AGENTS.md"
Rapporte (lecture seule) quels fichiers CLAUDE.md peuvent passer en AGENTS.md ; après confirmation, les renomme dans toute l'arborescence et redémarre les sessions en cours sous le répertoire de base

Dites : "conseil"
Affiche un conseil - le même conseil toute la journée, ou aléatoire si TIP_MODE=random est configuré

Dites : "activer les conseils" / "désactiver les conseils"
Active ou désactive le conseil du jour sur tous les projets

Dites : "mettre à jour claude-mux"
Prévient que toutes les sessions vont redémarrer, demande confirmation, puis met à jour et redémarre

Dites : "arrêter toutes les sessions"
Ferme proprement toutes les sessions gérées

Dites : "aide"
Affiche la liste complète des commandes conversationnelles
```

**Ces commandes fonctionnent dans toutes les langues.** Si vous tapez l'équivalent en anglais, japonais, hébreu ou toute autre langue, Claude infère l'intention et exécute la commande correspondante.

**Tapez `help` dans n'importe quelle session pour voir la liste complète des commandes.**

## Plus

- [Référence CLI](../docs/CLI.md) - référence complète des commandes pour le scripting et l'automatisation
- [Guide](../docs/GUIDE.md) - configuration, détails de session, fonctionnement interne et dépannage
- [Options d'installation](../docs/INSTALL.md) - Homebrew, installation manuelle, configuration du LaunchAgent
- [FAQ](../docs/FAQ.md) - questions fréquentes sur claude-mux
- [Problèmes connus](../docs/ISSUES.md) - bugs ouverts, fonctionnalités prévues et problèmes résolus
- [Journal des modifications](../CHANGELOG.md) - ce qui a changé par version
