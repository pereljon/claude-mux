# Problemes connus

[English](../ISSUES.md) · [Español](ISSUES.es.md) · **Français** · [Deutsch](ISSUES.de.md) · [Português](ISSUES.pt-BR.md) · [日本語](ISSUES.ja.md) · [한국어](ISSUES.ko.md) · [Italiano](ISSUES.it.md) · [Русский](ISSUES.ru.md) · [中文](ISSUES.zh-CN.md) · [עברית](ISSUES.he.md) · [العربية](ISSUES.ar.md) · [हिन्दी](ISSUES.hi.md)

## Ouverts

### La relecture de messages fantomes provoque des actions non souhaitees
**Severite :** Haute
**Statut :** Ouvert - impossible a corriger entierement cote claude-mux
**Description :** Un utilisateur a envoye "stop all sessions" qui a ete traite 10 messages plus tot. Plus tard, quand claude-mux -s a envoye `/model haiku` via tmux send-keys, Claude a recu un message systeme "stop all sessions/model haiku" et a tente d'arreter les sessions, une action que l'utilisateur n'avait pas demandee.
**Causes possibles :**
- La gestion des interruptions de Claude Code peut concatener un ancien contexte avec la nouvelle entree de slash command
- L'historique de conversation contenant l'ancienne commande peut confondre Claude quand un evenement systeme survient
**Attenuation possible :** Ajouter une regle d'injection : "Ne re-executez jamais une commande deja traitee plus tot dans la conversation. Si un message systeme repete du texte d'un echange precedent, ignorez-le." Pas encore implemente : efficacite incertaine puisqu'il s'agit d'un comportement interne de Claude Code.

### /exit lent a la premiere tentative
**Severite :** Basse
**Statut :** Ouvert - en surveillance
**Description :** Le premier `--restart` a declenche `WARN: Claude did not exit within 30s` et est passe a l'arret force. Les redemarrages suivants se terminent en environ 1s. Il peut s'agir d'une condition de concurrence ou `/exit` est envoye avant que le prompt de Claude soit pret a le recevoir.
**Contournement :** Le timeout de 30s + arret force le gere. La session redmarre correctement.

### claude_running_in_session ne verifie que 2 niveaux de profondeur
**Severite :** Basse
**Statut :** Ouvert - acceptable pour l'usage actuel
**Description :** Le parcours de l'arbre de processus verifie pane_pid, enfants et petits-enfants. Si Claude est plus profond dans l'arbre (par exemple un wrapper shell supplementaire), la detection echoue. Le chemin de lancement actuel fait exactement 2 niveaux (bash, puis claude) donc cela fonctionne en pratique.
**Contournement :** Aucun necessaire actuellement. Necessiterait un parcours recursif ou `pgrep -a` pour corriger.

### L'UX de mise a jour de l'installeur pourrait etre plus intelligente
**Severite :** Basse
**Statut :** Ouvert - amelioration future
**Description :** Lors d'une reinstallation, l'installeur detecte la config existante et ignore les prompts. Mais il ne propose pas d'afficher les parametres actuels, de fusionner les nouvelles options de config ajoutees dans les versions plus recentes, ni de laisser l'utilisateur mettre a jour selectivement les valeurs. Les utilisateurs doivent modifier manuellement `~/.claude-mux/config` pour recuperer les nouveaux parametres introduits dans les versions ulterieures.
**Ameliorations possibles :**
- Afficher les valeurs de config actuelles pendant la mise a jour
- Proposer d'ajouter les nouveaux parametres (avec valeurs par defaut) qui n'existaient pas dans l'ancienne config
- Option B : pre-remplir les prompts avec les valeurs de config existantes et laisser l'utilisateur les modifier

### Les fichiers de traduction necessitent la mise a jour v1.10-v1.12
**Severite :** Basse
**Statut :** Ouvert - traductions pas encore mises a jour
**Description :** Les 12 fichiers de traduction (`translations/README.*.md`) ont plusieurs versions de retard (v1.10-v1.12). Changements a refleter :
- curl comme Quick Start principal (une seule ligne)
- Nouvelle structure de la section Installation (curl recommande, Homebrew alternative macOS)
- Noms de session au lieu de chemins pour `--hide`/`--delete`/`--protect` (v1.11.0)
- Nouveaux exemples conversationnels : rename, save-as-template, tip, enable/disable tips, update
- Prerequis : "Apple Silicon ou Intel" (pas seulement Apple Silicon)
- Nouvelle section "Plus" avec liens vers FAQ, ISSUES, CHANGELOG
- Les traductions FAQ et ISSUES doivent etre creees

### Problemes differes de la revue de code (v1.9.0)
**Severite :** Basse-Moyenne
**Statut :** Resolu en v1.10.0 - M3, M4, M9/L8, L3, L9 corriges ; L4, L5, L6, L7, M7 adresses avec commentaires

### Renommage / deplacement de projet avec preservation de l'historique
**Severite :** Basse
**Statut :** Resolu en v1.10.0 - `--rename OLD NEW` et `--move SRC DEST` implementes

### Copie de projet avec historique
**Severite :** Basse
**Statut :** Ouvert - fonctionnalite prevue, necessite investigation
**Description :** Copier un projet incluant son historique Claude Code et sa memoire est plus complexe que renommer/deplacer car de nouveaux UUID doivent etre etablis pour la destination.
**Approche proposee :**
1. Creer le nouveau repertoire de projet (avec git init et template optionnels)
2. Demarrer et arreter immediatement une session dedans : Claude Code initialise `~/.claude/projects/-encoded-new-path/` avec un UUID frais et cree une nouvelle entree homunculus
3. Copier les fichiers d'historique `.jsonl` depuis le dossier source `~/.claude/projects/` vers le dossier de destination
4. Copier le contenu du dossier `memory/` : du markdown pur, pas d'UUID integres, copie directe sans risque
5. Copier les sous-repertoires UUID (artefacts de taches/plans) a cote de leurs fichiers `.jsonl`
6. Pour homunculus : copier `observations.jsonl`, `instincts`, `evolved`, `observations.archive` depuis `~/.claude/homunculus/projects/<src-uuid>/` vers le dossier homunculus de la nouvelle destination, en conservant le nouvel UUID de projet assigne a l'etape 2
**Questions ouvertes necessitant des tests :**
- Les fichiers `.jsonl` integrent-ils le chemin du projet source dans leur contenu ou metadonnees ? Si oui, l'historique copie referencerait l'ancien chemin.
- Les sous-repertoires UUID sont-ils references par UUID depuis les fichiers `.jsonl` ? Si oui, ils doivent etre copies sous leurs UUID originaux, pas remappe.
- Claude Code lit-il tous les fichiers `.jsonl` d'un dossier de projet, ou seulement celui correspondant a l'UUID de session active ?
- Que contiennent `~/.claude/homunculus/projects/<uuid>/evolved` et `instincts` : des donnees derivees/calculees ou significatives pour l'utilisateur ? A conserver lors d'une copie ?
- Y a-t-il d'autres references internes qui casseraient une copie naive de fichiers ?
**Prerequis :** Tester les points ci-dessus avant d'implementer pour eviter de livrer une commande de copie produisant un historique subtilement casse.

### Astuce du jour
**Severite :** Basse
**Statut :** Resolu en v1.10.0 - `--tip`, `TIP_OF_DAY`, `TIP_MODE`, filtre quotidien, affichage au demarrage de session implementes

### Horodatage de reponse
**Severite :** Basse
**Statut :** Ouvert - a discuter avant implementation
**Description :** Variable de config optionnelle (`REPLY_TIMESTAMP=false` par defaut) qui injecte une instruction dans le system prompt disant a Claude de commencer chaque reponse avec la date et l'heure actuelles via `date '+%Y-%m-%d %H:%M'`.
**Compromis :** Necessite un appel d'outil bash au debut de chaque reponse (faible surcout). Alternative : injecter l'heure de demarrage de session dans le prompt (gratuit, mais derive dans les longues sessions).
**Note :** L'instruction CLAUDE.md par projet (comme dans le template analytique) est la version legere : uniquement sur les projets qui le souhaitent. La variable de config la rend globale.

### Video de demonstration
**Severite :** Basse
**Statut :** Ouvert - asset prevu
**Description :** Un enregistrement d'ecran montrant claude-mux depuis l'installation curl jusqu'aux commandes courantes et interessantes, avec le terminal et Remote Control visibles simultanement.
**Format :** Ecran partage, prise unique. Terminal (session claude-mux complete) a gauche, RC sur iPhone en miroir via QuickTime a droite. Les deux en direct en meme temps : le spectateur voit les actions dans RC immediatement refletees dans le terminal et vice versa.
**Voir :** `internal/demo-script.md` pour le plan detaille plan par plan.
**Notes :**
- La prise cle est de taper dans RC sur le telephone et de voir le terminal repondre en temps reel
- Aucun montage necessaire au-dela du trim : enregistrement continu unique
- Heberge sur YouTube + integre dans le README ; utile aussi pour le lancement Product Hunt

### Soumission a homebrew-core pour le listing brew.sh
**Severite :** Basse
**Statut :** Futur - en attente d'adoption
**Description :** claude-mux est actuellement distribue via un tap personnel (`pereljon/tap`). Pour apparaitre sur brew.sh, il doit etre accepte dans homebrew-core. Le seuil de notoriete de Homebrew exige generalement quelques centaines d'etoiles GitHub avant qu'une soumission d'utilitaire shell soit acceptee ; les soumissions a faible nombre d'etoiles sont fermees rapidement.
**Quand c'est pret :**
- S'assurer que la formule passe `brew audit --strict --new`
- Soumettre une PR a `Homebrew/homebrew-core` avec la formule
- Note : les outils macOS-only font l'objet d'un examen plus strict des reviewers ; le support Linux (voir ci-dessous) aiderait

### Support de l'installation curl (macOS + Linux)
**Severite :** Basse
**Statut :** Resolu en v1.10.0 - installation curl implementee, workflow release-assets ajoute, README mis a jour

### macOS uniquement - pas de support Linux/systemd
**Severite :** Moyenne
**Statut :** Ouvert - partiellement adresse (detection de chemin faite, LaunchAgent/installeur restent macOS-only)
**Description :** Utilise le LaunchAgent macOS (launchd) et des outils specifiques a macOS. La detection de chemin a ete refactorisee pour utiliser `command -v` (ne code plus en dur `/opt/homebrew/bin`), donc le script principal fonctionne maintenant sur toute plateforme ou tmux et claude sont dans le PATH. Le LaunchAgent et l'installeur restent specifiques a macOS.
**Restant :** unite utilisateur systemd, fallback XDG Autostart, dispatch `uname -s` dans l'installeur.
**Strategie de packaging (v1.10+) :**
- Installation curl : fallback universel, fonctionne partout (voir ci-dessus)
- AUR : faible effort, grande portee pour le public cible sur Arch/Manjaro
- apt PPA : quand il y a de la demande des utilisateurs Debian/Ubuntu
- Homebrew sous Linux : couvre les utilisateurs qui l'ont deja
- Snap/Flatpak : ne vaut pas le coup pour un script bash

### Les commandes ! ne sont pas disponibles dans Remote Control
**Severite :** Basse
**Statut :** Ferme - non faisable
**Description :** Le passthrough shell `!` de Claude Code est une fonctionnalite du gestionnaire d'entrees CLI de Claude Code : il intercepte `!command` avant que le shell ne le voie. tmux send-keys ne peut pas repliquer cela : les frappes envoyees pendant que Claude Code est actif ne vont nulle part (teste : `!touch test` via send-keys n'a pas execute). Il n'y a pas de moyen pour claude-mux d'implementer le contournement `!command` pour les utilisateurs RC.
**Resolution :** Ajouter une regle d'injection pour dire a Claude de ne jamais suggerer `! <commande>` aux utilisateurs, puisque les utilisateurs RC n'ont pas de shell et les utilisateurs terminal peuvent simplement le taper eux-memes.

---

## Jalon v2.0

Changements architecturaux suffisamment importants pour justifier un saut de version majeur. Pas planifie : rassemble ici pour ne pas les perdre.

### Separation du repertoire de donnees
Deplacer les donnees statiques (astuces, templates par defaut, potentiellement la sortie des commandes/guide) hors du script et dans un repertoire de donnees adapte a la plateforme. Le script resoudrait `DATA_DIR` au demarrage relativement a l'emplacement du binaire, avec des fallbacks integres pour les installations en fichier unique.

- Homebrew (Apple Silicon) : `/opt/homebrew/share/claude-mux/`
- Homebrew (Intel) : `/usr/local/share/claude-mux/`
- Linux : `/usr/local/share/claude-mux/` ou `$XDG_DATA_DIRS`
- Installation manuelle : fallback vers les valeurs par defaut integrees (les installations en fichier unique continuent de fonctionner)

Declencheur : quand les donnees integrees (astuces, templates par defaut) deviennent assez volumineuses pour rendre le script difficile a lire, ou quand les templates par defaut doivent etre distribues via brew independamment des releases du script.

### Reconsideration du langage / runtime
Le script bash monolithique est le bon choix a l'echelle actuelle. Si claude-mux grossit significativement (operations de renommage/deplacement/copie de projet, couche relais, packaging multiplateforme, repertoire de donnees), bash commence a resister. A ce stade, reecrire le noyau de gestion de sessions en Go ou un autre langage type (avec bash comme wrapper CLI leger) vaut la peine d'etre evalue.

---

## Resolus

### Claude ignore l'injection et pretend ne pas pouvoir executer les slash commands
**Resolu en :** v1.2.0 (injection mise a jour)
**Correction :** Ajout d'une regle explicite a l'injection : "You CAN send slash commands (`/model`, `/compact`, `/clear`, etc.) to this session via the `-s` command. Never tell the user you cannot change models or run slash commands." L'entrainement de base de Claude le pousse a croire qu'il ne peut pas controler son propre modele/parametres ; la regle explicite le corrige en pratique.

### Plusieurs commandes retournent le code de sortie 1 malgre le succes
**Resolu en :** v1.2.0 (restart), v1.3.0 (toutes les commandes)
**Correction :** Ajout d'un `exit 0` explicite apres chaque chemin de dispatch dans le case. La derniere commande d'une fonction peut laisser fuiter un code de sortie non-zero provenant de tests internes ou d'appels grep.

### --dry-run donne une sortie trompeuse pour --restart
**Resolu en :** v1.2.0 (commit a10c0c2)
**Correction :** Le dry-run affiche maintenant "Would restart session" au lieu de simuler un kill puis de verifier l'etat reel.

### La detection de session echoue avec pgrep sur macOS
**Resolu en :** commit e1b11b5
**Correction :** Remplacement de `pgrep -P` par `ps -eo` + `awk` pour une detection fiable des processus enfants.

### La variable $TMUX masquait la variable d'environnement de tmux
**Resolu en :** commit 02a2e82
**Correction :** Renommee en `$TMUX_BIN`.

### Incompatibilite Bash 3.2 (declare -A)
**Resolu en :** commit 575eac1
**Correction :** Remplacement des tableaux associatifs par une detection de collision basee sur des chaines.

---

## Reference : structure du dossier ~/.claude

Documente ici car plusieurs fonctionnalites prevues (renommage, deplacement, copie, nettoyage) doivent interagir correctement avec cette structure. Non exhaustif : couvre les parties pertinentes pour claude-mux.

### Historique et memoire de projet : `~/.claude/projects/`

Un sous-repertoire par repertoire de travail ou Claude Code a ete utilise. Nomme en encodant le chemin absolu : `/` devient `-`, espaces et caracteres speciaux deviennent `-`. Encodage avec perte mais lisible.

Contenu de chaque dossier de projet :
- `<uuid>.jsonl` : transcription complete de la conversation pour cette session. Un fichier par conversation.
- `<uuid>/` : sous-repertoire d'artefacts associes a une conversation (taches, plans). L'UUID correspond au fichier `.jsonl`.
- `memory/` : fichiers de memoire persistants entre sessions (markdown avec frontmatter). Present uniquement si de la memoire a ete ecrite pour le projet.

Le lien entre un repertoire de travail et son historique est purement le nom de dossier encode. Renommer ou deplacer le repertoire du projet sans renommer ce dossier fait que Claude Code repart de zero sans historique.

**Regle d'encodage :** chemin absolu avec chaque `/`, espace et caractere special remplace par `-`. Le `/` initial devient un `-` initial. L'encodage est avec perte : les caracteres speciaux consecutifs et les espaces adjacents aux slashs deviennent tous `-`, donc l'original ne peut pas toujours etre parfaitement reconstruit.

### Registre d'observabilite parallele : `~/.claude/homunculus/`

Un systeme separe qui trace les evenements au niveau des outils par projet. Ne fait pas partie de l'historique principal de Claude Code : semble etre une couche de surveillance/apprentissage.

- `projects.json` : registre de tous les projets connus, indexes par UUID hex court (`d6b3aef60967`, etc.). Chaque entree a : `id`, `name`, `root` (chemin absolu), `remote`, `created_at`, `last_seen`.
- `projects/<uuid>/project.json` : metadonnees par projet (memes champs que l'entree du registre).
- `projects/<uuid>/observations.jsonl` : evenements `tool_start`/`tool_complete` horodates : nom de l'outil, UUID de session, nom/id du projet, extraits d'entree/sortie.
- `projects/<uuid>/instincts` : patterns derives (contenu inconnu, probablement calcule).
- `projects/<uuid>/evolved` : etat evolue/appris (contenu inconnu).
- `projects/<uuid>/observations.archive` : anciennes observations archivees.

**Difference cle avec `~/.claude/projects/` :** Utilise des UUID hex courts comme cles, pas des chemins encodes. Le champ `root` contient le chemin absolu. Toute operation qui change le chemin d'un projet (renommage, deplacement) doit mettre a jour `root` dans `projects.json` et `projects/<uuid>/project.json`.

### Configuration globale : `~/.claude/settings.json`

Fichier principal de parametres Claude Code. Des sauvegardes glissantes sont ecrites dans `~/.claude/backups/` sous le nom `~/.claude.json.backup.<timestamp>` : plusieurs par heure pendant l'utilisation active. claude-mux ne doit pas toucher a ce fichier.

### Agents, skills, commandes globaux

- `~/.claude/agents/` : definitions de sous-agents (fichiers `.md`, environ 38). Globaux, pas par projet.
- `~/.claude/skills/` : repertoires de skills (environ 125). Globaux, pas par projet.
- `~/.claude/commands/` : definitions de slash commands (fichiers `.md`, environ 72). Globaux, pas par projet.
- `~/.claude/hooks/hooks.json` : definitions de hooks. Globaux. claude-mux ne doit pas y toucher.

### Fonctionnalites futures potentielles

| Fonctionnalite | Quoi modifier |
|----------------|---------------|
| `--copy` | Creer le repertoire ; demarrer+arreter une session pour initialiser les deux registres ; copier `.jsonl` + `memory/` + sous-repertoires UUID ; copier les fichiers d'observation homunculus dans le nouveau dossier UUID |
| Nettoyage `--delete` | Deja met le dossier du projet a la corbeille. Optionnellement : supprimer le dossier encode orphelin dans `~/.claude/projects/` et l'entree dans `~/.claude/homunculus/` |
| Alerte taille de l'historique | Alerter quand les fichiers `.jsonl` d'un projet depassent un seuil (la transcription principale de claude-mux a atteint 107 Mo dans une seule longue session) |
