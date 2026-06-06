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

- **Les sessions meurent** quand vous fermez le terminal
- **Le contexte de conversation** ne reprend pas automatiquement
- **Pas de base** - rien ne tourne quand vous prenez votre téléphone sauf si vous avez laissé quelque chose ouvert
- **Remote Control nécessite une session active** - vous ne pouvez pas en démarrer une depuis RC
- **Les commandes slash ne marchent pas dans les sessions RC** - pas de changement de modèle, de compactage ou de changement de mode de permissions
- **Démarrer de nouveaux projets** - nécessite de créer un répertoire manuellement, d'initialiser git, d'écrire un CLAUDE.md et de choisir un modèle
- **Pas de gestion de projets** - aucun moyen de voir les projets inactifs, ni de renommer, déplacer ou supprimer des projets sans casser l'historique

**claude-mux comble le manque de gestion de sessions.** Il enveloppe Claude Code dans tmux pour que les sessions persistent, injecte un prompt système pour que Claude gère ses propres sessions, et route les commandes slash via tmux pour qu'elles fonctionnent sur Remote Control. Une fois qu'une session tourne, vous gérez tout en parlant à Claude - dans le terminal ou l'app mobile.

## Ce que vous pouvez faire dans une session claude-mux

- **Gérer n'importe quelle session depuis n'importe quelle session** - démarrer, arrêter, redémarrer, lister et compacter des projets en langage naturel
- **Accéder à tout de partout** - chaque session a Remote Control activé, donc l'app mobile Claude, l'app desktop ou tout client distant est une interface complète
- **Changer de modèle et de mode de permissions** - dites "passe à Haiku" ou "passe en mode plan" et Claude s'en charge, même sur Remote Control
- **Créer de nouveaux projets** - "crée un nouveau projet appelé my-app" configure le répertoire, git, CLAUDE.md et lance une session. Les templates CLAUDE.md permettent de réutiliser les instructions entre projets
- **Garder les sessions vivantes entre redémarrages** - une session home optionnelle se lance à la connexion et reste active ; toutes les sessions reprennent leur dernière conversation automatiquement
- **Envoyer des commandes slash via Remote Control** - Claude route `/model`, `/compact`, `/clear` et d'autres commandes slash vers la session active, contournant une [limitation connue](https://github.com/anthropics/claude-code/issues/30674)
- **Préserver l'historique de conversation** - renommer, déplacer et redémarrer des projets préservent l'historique de conversation automatiquement
- **Organiser les projets** - masquer, renommer, déplacer, supprimer et protéger des projets depuis n'importe quelle session
- **Support multi-compte GitHub** - détecte les alias SSH dans `~/.ssh/config` et les injecte dans les sessions pour que Claude utilise le bon compte par projet
- **Support multi-CLI-coder** - crée automatiquement des symlinks `AGENTS.md` et `GEMINI.md` pour que Codex CLI, Gemini CLI et autres partagent les instructions
- **Fonctionne dans toutes les langues** - les commandes conversationnelles sont inférées par intention, pas par mots-clés

## Parler à Claude

Voici comment vous utilisez claude-mux au quotidien. Chaque session est injectée avec des commandes pour que Claude puisse gérer les sessions, changer de modèle, envoyer des commandes slash et créer de nouveaux projets - tout depuis la conversation. Pas besoin de retenir les flags CLI.

```
Vous : "statut"
Claude : rapporte le nom de session, le modèle, le mode de permissions, l'utilisation du contexte et liste toutes les sessions

Vous : "lister les sessions actives"
Claude : affiche toutes les sessions actives avec leur statut

Vous : "lance une session pour mon projet api-server"
Claude : lance une session dans ~/Claude/work/api-server

Vous : "crée un nouveau projet appelé mobile-app avec le template web"
Claude : crée le répertoire du projet, initialise git, applique le template, lance une session

Vous : "passe cette session à Haiku"
Claude : envoie /model haiku à lui-même via tmux

Vous : "compacte la session api-server"
Claude : envoie /compact à la session api-server

Vous : "redémarre la session web-dashboard"
Claude : arrête et relance la session, en préservant le contexte de conversation

Vous : "passe la session api-server en mode plan"
Claude : redémarre la session avec le mode de permissions plan

Vous : "passe cette session en mode yolo"
Claude : passe en mode bypassPermissions via Shift+Tab - pas de redémarrage nécessaire

Vous : "quel mode pour cette session"
Claude : rapporte le mode de permissions actuel (default, acceptEdits, plan, bypassPermissions)

Vous : "passe cette session à Opus"
Claude : envoie /model opus à lui-même via tmux

Vous : "efface cette session"
Claude : envoie /clear à lui-même, réinitialisant la conversation

Vous : "masque ce projet"
Claude : écrit .claudemux-ignore pour que le projet soit exclu des listings -L

Vous : "protège cette session"
Claude : écrit .claudemux-protected et définit le marqueur tmux - l'arrêt nécessite maintenant --force

Vous : "cette session est protégée ?"
Claude : vérifie .claudemux-protected dans le dossier du projet et rapporte

Vous : "supprime le projet old-prototype"
Claude : confirme dans le chat, puis déplace le dossier du projet vers la corbeille système

Vous : "renomme ce projet en my-new-name"
Claude : arrête la session, renomme le dossier, migre l'historique de conversation, redémarre

Vous : "sauvegarde ça comme template nommé web"
Claude : copie CLAUDE.md vers ~/.claude-mux/templates/web.md

Vous : "conseil"
Claude : affiche un conseil - le même conseil toute la journée, ou aléatoire si TIP_MODE=random est configuré

Vous : "activer les conseils" / "désactiver les conseils"
Claude : active ou désactive le conseil du jour sur tous les projets

Vous : "mettre à jour claude-mux"
Claude : prévient que toutes les sessions vont redémarrer, demande confirmation, puis met à jour et redémarre

Vous : "arrêter toutes les sessions"
Claude : ferme proprement toutes les sessions gérées

Vous : "aide"
Claude : affiche la liste complète des commandes conversationnelles
```

**Ces commandes fonctionnent dans toutes les langues.** Si vous tapez l'équivalent en anglais, japonais, hébreu ou toute autre langue, Claude infère l'intention et exécute la commande correspondante.

**Tapez `help` dans n'importe quelle session pour voir la liste complète des commandes.**

## Plus

- [Référence CLI](../docs/CLI.md) - référence complète des commandes pour le scripting et l'automatisation
- [Guide](../docs/guide.md) - configuration, détails de session, fonctionnement interne et dépannage
- [Options d'installation](../docs/INSTALL.md) - Homebrew, installation manuelle, configuration du LaunchAgent
- [FAQ](../docs/FAQ.md) - questions fréquentes sur claude-mux
- [Problèmes connus](../docs/ISSUES.md) - bugs ouverts, fonctionnalités prévues et problèmes résolus
- [Journal des modifications](../CHANGELOG.md) - ce qui a changé par version
