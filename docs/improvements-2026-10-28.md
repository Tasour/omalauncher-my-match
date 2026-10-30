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
| I05 | Borner `upShow` dans la tuile, garder la liste complète dans l'écran | UX-01 | test statique + preview 7×12 | **Fait** |
| I06 | Réduire le périmètre `standings` au premier lancement (Top 5 + Europe) | PROD-01, DATA-02 | test statique + extraction `bash -n` | **Fait** |
| I07 | Aligner les timeouts `scheds`/`standings`/`teamsDb` sur le pire cas | SHELL-01, DATA-03 | test de valeurs + `bash -n` | **Fait** |
| I08 | Ajouter `status` à toutes les sources et une santé visible | SRE-01, PROD-02, UX-03 | test de présence + `owl-check` | **Fait** |
| I09 | Remplacer le réveil `every 1s` par un `at` conditionnel | ENERGY-01 | test anti-`every 1s` + `owl-check` | **Fait** |
| I10 | Ajouter la CI et le harnais de tests des améliorations | QA-01, QA-02 | `scripts/ci.sh` + template Actions | **Fait** |

## Note CI (I10)

`scripts/ci.sh` est le harnais portable (compile Python, `tests/run.sh`).
Le workflow GitHub Actions prêt à l'emploi est `docs/ci-workflow.yml` : il doit
être copié vers `.github/workflows/ci.yml` par un token disposant du scope
`workflow` (`gh auth refresh -s workflow`). Le token courant ne l'a pas, et
GitHub rejette alors tout push contenant un fichier de workflow.

## Revue experte v5.10.0 (UI/UX, OWL, sécurité/SRE)

Trois revues indépendantes ont été rejouées sur le lot. Constats corrigés :

- **I09** : `spinAt=now+1` ne ré-armait pas le tick (l'horloge `now` est à 15 s).
  Corrigé en `spinAt=spinAt+1`, test aligné sur l'expression exacte.
- **I08** : une source en échec affichait « aucun match » ; branches d'erreur
  ajoutées (MINE, RIV, TOP5, EUROPE), y compris les échecs partiels (un flux
  tombe, l'autre est vide), bannière santé courte (`⚠ N · dégradé`) avec noms
  localisés, masquée pendant l'onboarding.
- **I05** : le nombre de matchs masqués dans la tuile est affiché (`+N`), test
  sur `take(8)` et sur le compteur.
- **I07** : budgets portés à `standings 300s` / `teamsDb 900s`, `bash -n` étendu
  aux neuf sources shell (`extract.py` sait lire `source X=cmd("""`).
- **I02** : validation sur la valeur entière (`grep -Ex`, CR/LF retirés), hôte
  passé en argument positionnel, `guest-ab.html` transmet `OMA_BASE`, scripts
  de mesure épinglés aux commits v5.7/v5.8/v5.9.1 (les gardes de version ne
  peuvent plus échouer sur `main`), port du serveur aligné sur 1764.
- **I10** : `tests/__pycache__` ignoré.

## Revue experte lot 2 (I11–I15)

- **I15** : fenêtre alignée sur le script live (`now-3h .. now+2min`) au lieu de
  ±2 h, index live en cache (`liveIdx`) pour démarrer même pendant le chargement
  de `games`/`extra`, purge des matchs `pre` retardés portée à 3 h.
- **I14** : jitter conservé sur les sources réseau, retiré de `liveM` pour ne pas
  retarder les scores en direct.
- **I13** : test de téléchargement réel (faux curl `MOCK_LOGO=1`), verrou/temp
  périmés purgés et absence de résidu vérifiée.

## Backlog restant

### Fiabilité et données

- **Fait — I11** Dériver le périmètre rivaux/historique de `myTeams`/`teamsDb`
  au lieu d'une liste blanche (FOOT-01, DATA-05) : `rivLgs` supprimé,
  `supportedLeagues` unique source, `extra`/`nextup`/`histfull` reçoivent
  `WANTLG` via `sh(favLg)`, tags NED/POR/TUR…, test `tests/test-league-scope.sh`
  (un club néerlandais remonte dans les trois sources ; `foo.1` est ignoré).
- **Fait — I12** Schéma/version/TTL/expiration des caches (DATA-04) : sidecar
  `.meta` `{v,at,ttl,exp}` pour games, season, standings, teams, extra, nextup,
  knock, history ; migration des anciens caches, fallback refusé si expiré,
  `fetchedAt` non rafraîchi sur un simple repli cache. Tests
  `tests/test-cache-meta.sh` (migration, repli, expiration) + assertions dans
  `test-games.sh`/`test-league-scope.sh`.
- **Fait — I13** Téléchargements d'écussons atomiques et verrouillés
  (SHELL-02, SHELL-04) : fichier temporaire privé `.$f.$$.tmp`, verrou
  `mkdir .$f.lock` par écusson, `mv` atomique après validation, purge des
  verrous/temp de plus de 15 min ; 7 blocs alignés, test statique + contrôle
  « aucun temp/lock laissé » dans `test-games.sh`.
- **Fait — I14** 429/5xx/offline : backoff exponentiel curl (`--retry-delay 0`),
  `Retry-After` respecté par curl, `--retry-connrefused`, `--retry-max-time`
  borné, jitter 0-2 s par source (`/dev/urandom`) (SRE-02) ; fixtures de panne
  `MOCK_MODE=429/500/offline/trunc` et repli cache testé (QA-03).
- **Fait — I15** `liveM` conditionnel (ENERGY-02) : `liveWin` (match en direct
  ou coup d'envoi à ±2 h) choisit `liveCmd` ; hors fenêtre la source n'exécute
  qu'un `printf` JSON minimal (plus de shell/jq/lecture de caches chaque
  minute), et le passage dans la fenêtre change la commande → run immédiat.
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
