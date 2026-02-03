---
description: 'Affiche le sprint status en mode Kanban visuel'
---

Exécute le script `sprint-board.sh` à la racine du projet pour afficher un board Kanban du sprint.

**Prérequis:**
- Fichier `_bmad/_memory/config.yaml` avec `output_folder` défini
- Fichier `sprint-status.yaml` dans `{output_folder}/implementation-artifacts/`

**Variables d'environnement:**
- `NO_COLOR=1` : Désactive les couleurs ANSI
- `SPRINT_BOARD_ASCII=1` : Utilise des caractères ASCII au lieu d'Unicode

**Erreurs possibles:**
- "Config not found" : Fichier `_bmad/_memory/config.yaml` introuvable
- "sprint-status.yaml not found" : Fichier de statut absent du dossier implementation-artifacts
- "output_folder not defined" : Variable `output_folder` manquante dans le config
