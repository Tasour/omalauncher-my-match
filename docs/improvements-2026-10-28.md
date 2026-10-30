# Améliorations issues de l'audit du 28/10/2026

Référence : `AUD-2026-10-28-MYM-001`, widget v5.9.8, base Git `10801eb`.
Règle : une amélioration = un commit poussé, un test de continuité, aucune
fonctionnalité retirée. Le widget passe au lot **v5.11.0** (lot 1 : I01–I10 ; lot 2 : I11–I33).

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
- **Fait — I16** Les rounds ESPN (`get(rounds,g.id)`, `g.round`) priment déjà sur
  l'estimation ; garde-fou et test ajoutés (FOOT-02).
- **Partiel — I17** Reports/annulations/suspensions explicites (statut ESPN
  conservé et affiché, rétention des `pre` marqués) (FOOT-04). Les agrégats
  aller/retour (FOOT-03) ne sont pas implémentés : le flux `knock` actuel ne
  porte pas le contrat série ; à faire avec un fixture ESPN dédié.

### Rendu et accessibilité

- **Reporté — I18** Listes `lazy` : nécessite un refactor d'écran (en-tête fixe
  + `Column{lazy:true}` avec `for` direct) et une validation device ; non fait
  pour ne pas livrer un rendu non testé (RENDER-01).
- **Fait — I19** `showTables=false persist` : les classements se composent à la
  demande (RENDER-02) ; le lazy des tables reste lié à I18.
- **Partiel — I20** `label` sur les `Image` des écussons (Crest/BannerLogo) ;
  les contrôles `Canvas` (refresh, flèches) ne sont pas convertis en `Button`
  faute de validation visuelle (A11Y-01/02).
- **Fait — I21** Zones nommées dans le tableau large et « en direct » dans le
  détail live, plus seulement la couleur (A11Y-03).
- **Fait — I22** Plancher 12 en taille S, tags à 11, largeurs dynamiques ;
  la taille système Android reste hors du contrôle OWL (VIS-02/A11Y-04 partiel).
- **Fait — I23** Largeurs score/détail/tour calculées depuis `fz` (VIS-01).
- **Fait — I24** `minSize:5x4` : plus de 3×3 illisible (UX-02).

### Architecture et qualité

- **Partiel — I25** `base` dérivé d'`allMine` (un seul prédicat d'appartenance) ;
  l'index historique/formes (OWL-03, RENDER-03) reste à faire.
- **Fait — I26** Clés stables `t.key`, `abbr:rank` pour les lignes de tableau (OWL-04).
- **Fait — I27** `tests/test-sources.sh` : scheds, teamsDb, extra, knock, nextup,
  histfull + fixtures ; repli cache (QA-01).
- **Fait — I28** `tests/test-degraded.sh` : 429/500/503/offline/tronqué/trop gros (QA-03).
- **Fait — I29** `tests/test-cache-concurrency.sh` : deux rafraîchissements
  concurrents laissent JSON + méta valides, sans `.tmp` (QA-04).
- **Reporté — I30** Extraction des scripts / réduction du monolithe : plan
  documenté, refactor non fait (risque élevé sans validation device).
- **Partiel — I31** Langue initiale depuis `lang()` et réglages déjà persistés ;
  `showSettings` reste volontairement limité à la session, et l'i18n des
  libellés ESPN inconnus n'est pas exhaustif (I18N-02..04).
- **Fait — I32** `LICENSE` MIT, `docs/data-notice.md` (source ESPN, absence
  d'affiliation, données locales, effacement), README mis à jour.
- **Partiel — I33** Preuves hors appareil (owl-check, `tests/run-all.sh`, modèle
  de requêtes) et protocole complet dans `docs/measurements-v5.10.0.md` ;
  décharge/ADB non exécutées (aucun appareil attaché).

## Protocole de validation

Pour chaque ligne :

1. modifier le widget ou les scripts ;
2. exécuter `tests/run.sh` et `owl-check` ;
3. vérifier le preview 7×12 ;
4. commiter avec un message `improve(Ixx): ...` ;
5. pousser sur `main` ;
6. mettre à jour ce tableau.
