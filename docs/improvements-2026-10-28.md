# Améliorations issues de l'audit du 28/10/2026

Référence : `AUD-2026-10-28-MYM-001`, widget v5.9.8, base Git `10801eb`.
Règle : une amélioration = un commit poussé, un test de continuité, aucune
fonctionnalité retirée. Le widget passe au lot **v5.10.0**.

## Lot 1 — 10 premières améliorations

| ID | Amélioration | Constats | Test de continuité | État |
|---|---|---|---|---|
| I01 | Durcir tous les `curl` du widget : HTTPS, zéro redirection, taille bornée, timeout de connexion | SEC-02 | `tests/test-audit-improvements.py` + `owl-check` + fixtures | **Fait** |
| I02 | Retirer l'IP LAN codée en dur des scripts de mesure | SEC-03 | scan anti-IP + tests | **Fait** |
| I03 | Corriger « equipe » → « équipe » | I18N-01 | test de chaînes + `owl-check` | **Fait** |
| I04 | Persister `showTables` | PROD-03 | test de présence `persist` + `owl-check` | **Fait** |
| I05 | Borner `upShow` dans la tuile, garder la liste complète dans l'écran | UX-01 | test statique + preview 7×12 | À faire |
| I06 | Réduire le périmètre `standings` au premier lancement (Top 5 + Europe) | PROD-01, DATA-02 | test statique + extraction `bash -n` | À faire |
| I07 | Aligner les timeouts `scheds`/`standings`/`teamsDb` sur le pire cas | SHELL-01, DATA-03 | test de valeurs + `bash -n` | À faire |
| I08 | Ajouter `status` à toutes les sources et une santé visible | SRE-01, PROD-02, UX-03 | test de présence + `owl-check` | À faire |
| I09 | Remplacer le réveil `every 1s` par un `at` conditionnel | ENERGY-01 | test anti-`every 1s` + `owl-check` | À faire |
| I10 | Ajouter la CI et le harnais de tests des améliorations | QA-01, QA-02 | workflow + exécution locale | À faire |

## Backlog restant

### Fiabilité et données

- `I11` Dériver `rivLgs` de `myTeams`/`teamsDb` au lieu d'une liste blanche (FOOT-01, DATA-05).
- `I12` Ajouter schéma/version/TTL aux caches et validation à la lecture (DATA-04).
- `I13` Rendre les téléchargements de logos atomiques et verrouillés (SHELL-02, SHELL-04).
- `I14` Gérer 429/5xx/offline avec jitter et `Retry-After` (SRE-02, QA-03).
- `I15` Rendre `liveM` conditionnel hors fenêtre de match (ENERGY-02).
- `I16` Remplacer les journées estimées par les rounds ESPN quand disponibles (FOOT-02).
- `I17` Gérer reports/annulations et agrégats aller-retour (FOOT-03, FOOT-04).

### Rendu et accessibilité

- `I18` Passer les listes d'écran en `lazy:true` (RENDER-01).
- `I19` Ouvrir les classements à la demande et les rendre lazy (RENDER-02).
- `I20` Ajouter les libellés des logos et des contrôles (A11Y-01, A11Y-02).
- `I21` Ajouter un texte aux zones et au live, pas seulement une couleur (A11Y-03).
- `I22` Relever le plancher typographique et tester les tailles système (VIS-02, A11Y-04).
- `I23` Remplacer les largeurs fixes de scores/tours (VIS-01).
- `I24` Ajouter un mode compact 3×3 ou passer le minimum à 5×4 (UX-02).

### Architecture et qualité

- `I25` Fusionner `base`/`allMine`, indexer historique et formes (OWL-02, OWL-03, RENDER-03).
- `I26` Utiliser `t.key` et des clés de table stables (OWL-04).
- `I27` Ajouter des tests pour `scheds`, `teamsDb`, `extra`, `knock`, `nextup`, `histfull` (QA-01).
- `I28` Ajouter les fixtures 429/offline/JSON tronqué/trop gros (QA-03).
- `I29` Ajouter un test de concurrence/atomicité des caches (QA-04).
- `I30` Extraire les scripts et réduire le monolithe (OWL-01, MAINT-02).
- `I31` Persister les réglages secondaires et compléter l'i18n (PROD-03, I18N-02..04).
- `I32` Ajouter LICENSE, attribution ESPN et notice de données (LEGAL-01..03, MAINT-04).
- `I33` Rejouer les mesures device sur v5.10.0 (ENERGY-03).

## Protocole de validation

Pour chaque ligne :

1. modifier le widget ou les scripts ;
2. exécuter `tests/run.sh` et `owl-check` ;
3. vérifier le preview 7×12 ;
4. commiter avec un message `improve(Ixx): ...` ;
5. pousser sur `main` ;
6. mettre à jour ce tableau.
