# Audit data/API — `my-match.owl` v5.7

Fichier audité : `/home/tasour/Work/omalauncher-my-match/widget/my-match.owl` (1955 lignes, 102 Ko).
Tous les chiffres ci-dessous sont dérivés du code aux lignes citées. Les tailles réseau sont mesurées sur l'API réelle (voir §1.3).

> **Mesure device (25/10/2026)** — le régime stable réel de v5.7 est **82,5 curl/min (~4 950/h)**, pas 502/h ; v5.8 est **0 curl/min stable** (aucun match live) et **4 jq/min**. Le burst initial reste **222 → 221 curl**. Les 502/41 ci-dessous sont des estimations code ; la mesure appareil fait foi pour le régime stable. Voir `docs/measurements-2026-10-25.md`.
>
> **v5.9.1** corrige deux régressions de v5.8 : les affectations `WANT…` collées par le compilateur OWL (syntaxe `games`/`seasonAll`) et le cache `games` empoisonné par une réponse ESPN invalide. Tests : `make test`.

---

## 0. Chiffres clés (état actuel, caches chauds, 1 équipe, hors direct)

| Métrique | Valeur | Détail |
|---|---:|---|
| Requêtes HTTP | **502 / h** (+60 par couple ligue-jour en direct) | `games` en fournit 448 à lui seul |
| Processus lancés | **~1 254 / h** (+120 par couple ligue-jour) | 502 curl + 681 jq + 71 bash |
| Transfert | **~143 Mo / h** (+17,6 Mo/h par couple live) | soit **~3,4 Go/jour** hors direct |
| Coût dominant | `games` | 448 req/h, 132 Mo/h, 468 jq/h |
| Second coût | `liveM` | 60 bash + 120 jq/h **même sans match** |
| Troisième coût | `extra` | 34 req/h + 64 jq/h |

Après P0+P1 (périmètre dynamique, cache mensuel `games`, gating `liveM`, intervalles) :

| Métrique | Avant | Après | Gain |
|---|---:|---:|---:|
| HTTP/h hors direct | 502 | **~41** | **-92 %** |
| Processus/h hors direct | ~1 254 | **~180** | **-86 %** |
| Transfert/h hors direct | 143 Mo | **~10 Mo** | **-93 %** |
| HTTP/h jour de match (N=3) | 682 | **~221** | -68 % |
| Processus/h jour de match (N=3) | ~1 614 | **~540** | -67 % |

Le direct reste à 1 requête/minute par couple ligue-jour **uniquement quand un match est en cours ou imminent** : aucune fonctionnalité live n'est dégradée.

---

## 1. Sources : type, cadence, requêtes, cache, orphelins

### 1.1 Tableau des sources

`N` = nombre de couples distincts `(league, jour)` avec un match `in` ou `pre` à moins de 90 min (0 à ~10 ; 0–3 hors match, 3–8 un samedi).

| Source | Déclaration | Type / endpoint | Intervalle | Timeout | Requêtes HTTP / exécution (preuve) | Req/h | Mo/h | Cache | Risque orphelin |
|---|---|---|---|---:|---|---:|---:|---|---|
| `games` | L237 | `scoreboard?dates=YYYYMM` ×28 ligues ×4–5 mois | 15 min | 240 s | **112** (28 × 4 ; 140 si 5 mois) — boucle L56-61, `CLUBS` L14 + `NATS` L15 | **448** (560) | 132 | `~/.cache/espn-games.json` (L70), logos L84-99, sprite L104-233 | **Oui** : `exit 1` L80 sans `rm` ; timeout 240 s < pire cas 368 s |
| `seasonAll` | L361 | `scoreboard?dates=YYYYMM` | 12 h | 300 s | **28 chaud** (mois courant/ligue), **362 froid** (26×13 + 2×12) — L291-317, cache L303-333 | 2,3 | 0,7 | `~/.cache/espn-season.json` L303 | Non (`rm` L336/L340) mais timeout froid 407 s |
| `scheds` | L362 | `teams/{id}/schedule` ×7 appels fixes | 12 h | 60 s | **7** — L371-377 | 0,58 | 0,04 | Aucun | Oui (timeout, pas de `trap`) |
| `standings` | L453 | `v2/.../standings` ×26 ligues | 6 h | 90 s | **26** — `TABLES` L388, boucle L430-434 | 4,33 | 0,27 | `~/.cache/espn-standings.json` L439-444 | Non (`rm` L447) ; timeout 90 s < pire 96 s |
| `teamsDb` | L527 | `.../teams` ×27 ligues | 24 h | 150 s | **27** — `LEAGUES` L456, boucle L490-497 | 1,13 | 0,02 | `~/.cache/espn-teams.json` L500-508 | Non ; **écrasement partiel** possible (L500-503) |
| `formsData` | L531 | `jq` local sur `espn-extra.json` | 15 min | 60 s | **0** — L529 | 0 | 0 | Lit `/root/.cache/espn-extra.json` | Non (aucun `tmp`) |
| `extra` | L654 | `scoreboard` ×11 + `standings` ×6 | 30 min | 150 s | **17 chaud** (11 scoreboard + 6 standings), **46 froid** (40 + 6) — L565-580, `rrun` L611-627 | **34** (92 froid) | 7,2 | `espn-extra-base.json` L569, `espn-extra.json` L631 | **Oui** : `exit 1` L606 sans `rm` |
| `liveM` | L724 | `scoreboard?dates=YYYYMMDD` ×N | 1 min | 90 s | **N** (0–10) — `LGD` L661-672, boucle L717-720 | **60N** | 17,6N | Lit 4 caches L671, **aucune écriture de cache de résultat** | Non (`rm` L722) |
| `knock` | L789 | `scoreboard` ×3 ligues ×4 mois | 6 h | 120 s | **12** — L753-757 | 2 | 0,59 | `~/.cache/espn-knock.json` L766 | **Oui** : `exit 1` L761 sans `rm` |
| `nextup` | L861 | `scoreboard` ×11 ×4 mois | 6 h | 150 s | **44** — L826-831 | 7,33 | 2,16 | `~/.cache/espn-nextup.json` L838 | **Oui** : `exit 1` L833 sans `rm` |
| `histfull` | L995 | `scoreboard` ×9 ×12 mois + `standings` ×6 | 6 h | 150 s | **15 chaud** (9 + 6), **114 froid** (108 + 6) — L894-911, `rrun` L946-967 | 2,5 | 0,50 | `espn-hist-base.json` L902, `espn-history.json` L984 | **Oui** : `exit 1` L936 sans `rm` ; timeout 150 s < pire 176 s |
| `now` | L996 | `clock` | 1 s | — | 0 | 0 | 0 | — | — |
| `slow` | L997 | `clock` | 15 min | — | 0 | 0 | 0 | — | — |
| `spr` | L998 | `file(sprite.json)` | — | — | 0 | 0 | 0 | `~/.cache/espn-logos/sprite.json` | — |

### 1.2 Détail des comptages (preuves)

> Note : l'énoncé « 25 ligues × 5 mois = 125 » sous-estime le code réel. `CLUBS` compte 25 ligues (L14) **plus** `NATS` 3 (L15), soit 28 ; et `MONTHS` (L56) donne 4 mois distincts la plupart du temps, 5 seulement quand `-4 j` change de mois. Le vrai coût est **112–140 requêtes/exécution**.

- **`games`** : `CLUBS` = 25 ligues (L14), `NATS` = 3 (L15) ⇒ 28. `MONTHS` = `-4 0 30 60 90` jours (L56) ⇒ 4 mois distincts en général, 5 quand `-4 j` change de mois. 28×4 = **112** ; 28×5 = **140**.
- **`seasonAll`** : 26 ligues non-calendaires × 13 mois (`07`→`12` puis `01`→`07`, L296-297) + 2 ligues calendaires (`nor.1`, `swe.1`, L298-299) × 12 = 338 + 24 = **362 froid**. Chaud : une seule requête par ligue (mois courant), car `lms` saute les autres (L313) ⇒ **28**.
- **`standings`** : `TABLES` compte 26 entrées (L388), dont les 3 coupes UEFA et 2 compétitions nations.
- **`teamsDb`** : `LEAGUES` compte 27 entrées (L456).
- **`extra`** : `LEAGUES` = 11 (L535). `RR` = 6 ligues à 5 mois (L565-566), 5 ligues à 2 mois (L567) ⇒ 6×5 + 5×2 = **40** scoreboard à froid. Chaud : mois courant seulement ⇒ **11**. `rrun` ajoute **6** appels `standings` à **chaque** exécution (L614), même avec cache chaud.
- **`liveM`** : `LGD` (L661-672) construit les couples depuis `espn-games.json`, `espn-season.json`, `espn-extra-base.json`, `espn-nextup.json`, puis filtre `state=="in"` ou `pre` dans `[now-5400, now]` (L666) et le périmètre `myTeams` (L667). `N` = nombre de couples uniques après `sort -u` (L672). Aucune requête si `N=0`, mais **le script tourne quand même 60 fois/h**.
- **`knock`** : 3 ligues × 4 mois (`02`→`05`, L754) = 12.
- **`nextup`** : 11 ligues × 4 mois (`0 30 60 90`, L826) = 44.
- **`histfull`** : 9 ligues × 12 mois (`08`→`07`, L898-900) = 108 + 6 `standings` pour les 6 ligues à poule (L954-955), les 3 coupes UEFA étant traitées en local (L948-952).
- **`scheds`** : 7 appels explicites (L371-377).

### 1.3 Preuves API (mesures du 25/10/2026)

| Requête | Résultat |
|---|---|
| `fra.1/scoreboard?dates=202610` | 200, **379 101 o**, 33 events |
| `fra.1/scoreboard?dates=202609` | 200, 273 505 o, 27 events |
| `fra.1/scoreboard?dates=202611` | 200, 228 627 o, 30 events |
| `fra.1/scoreboard?dates=20261001-20261031` | **400** (plage refusée) |
| `fra.1/scoreboard?dates=2026` | 200, 988 579 o, **100 events** (limite par défaut) |
| `fra.1/scoreboard?dates=2026&limit=1000` | 200, **2 779 120 o, 288 events** |
| `fra.1/scoreboard?dates=2027&limit=1000` | 200, 1 263 761 o, 180 events |
| `eng.1/scoreboard?dates=2026&limit=1000` | 200, **3 819 075 o, 374 events** |
| `uefa.champions/...?dates=2026&limit=1000` | 200, 2 007 075 o, 189 events |
| `fra.1/standings` | 200, **63 160 o** |
| `fra.1/teams` | 200, **21 202 o** |
| `fra.1/teams/167/schedule` | 200, **62 525 o**, 7 events seulement |

Conséquences :
1. La plage de dates n'est pas supportée ; il faut garder le pas mensuel.
2. `dates=YYYY&limit=1000` fonctionne et retourne l'année entière : utile **uniquement pour le backfill à froid** de `seasonAll`/`histfull` (2 requêtes/ligue au lieu de 12–13), pas pour les rafraîchissements (2,8–3,8 Mo par ligue).
3. `/schedule` ne contient ni cotes ni saison complète : inutilisable pour remplacer `games`/`seasonAll`.

---

## 2. Coût réel

### 2.1 HTTP par heure

| Source | Calcul | Req/h |
|---|---|---:|
| `games` | 28 ligues × 4 mois × 4 exécutions | **448** |
| `seasonAll` | 28 × (2/24) | 2,3 |
| `scheds` | 7 × (2/24) | 0,58 |
| `standings` | 26 × (4/24) | 4,33 |
| `teamsDb` | 27 × (1/24) | 1,13 |
| `formsData` | 0 | 0 |
| `extra` | 17 × 2 | **34** |
| `liveM` | N × 60 | **60N** |
| `knock` | 12 × (4/24) | 2 |
| `nextup` | 44 × (4/24) | 7,33 |
| `histfull` | 15 × (4/24) | 2,5 |
| **Total** | | **502 + 60N** |

### 2.2 Processus par heure

| Source | curl/h | jq/h | bash/h |
|---|---:|---:|---:|
| `games` | 448 | ~468 (112 fetch + 5 merge/filtre par run) | 4 |
| `seasonAll` | 2,3 | 2,9 | 0,08 |
| `scheds` | 0,58 | 0,25 | 0,08 |
| `standings` | 4,33 | 4,8 | 0,17 |
| `teamsDb` | 1,13 | 1,25 | 0,04 |
| `formsData` | 0 | 4 | 4 |
| `extra` | 34 | 64 | 2 |
| `liveM` | 60N | **120 + 60N** | **60** |
| `knock` | 2 | 2,5 | 0,17 |
| `nextup` | 7,33 | 7,8 | 0,17 |
| `histfull` | 2,5 | 5,3 | 0,17 |
| **Total** | **502 + 60N** | **~681 + 60N** | **~71** |

**Total ≈ 1 254 + 120N processus/h**, soit ~30 000/jour, ~900 000/mois. `liveM` représente à lui seul 60 bash + 120 jq/h **au repos**, et 4 fichiers de cache parsés chaque minute (dont `espn-season.json` et `espn-extra-base.json`, les plus gros).

### 2.3 Transfert par heure

Base : mois `scoreboard` ≈ 294 Ko (moyenne des mesures 228–379 Ko), `standings` ≈ 63 Ko, `teams` ≈ 21 Ko, `schedule` ≈ 62 Ko.

| Source | Calcul | Mo/h |
|---|---|---:|
| `games` | 112 × 294 Ko × 4 | **131,7** |
| `seasonAll` | 28 × 294 Ko × 2/24 | 0,69 |
| `scheds` | 7 × 62 Ko × 2/24 | 0,04 |
| `standings` | 26 × 63 Ko × 4/24 | 0,27 |
| `teamsDb` | 27 × 21 Ko × 1/24 | 0,02 |
| `extra` | (11×294 + 6×63) Ko × 2 | 7,22 |
| `liveM` | N × 294 Ko × 60 | **17,6N** |
| `knock` | 12 × 294 Ko × 4/24 | 0,59 |
| `nextup` | 44 × 294 Ko × 4/24 | 2,16 |
| `histfull` | (9×294 + 6×63) Ko × 4/24 | 0,50 |
| **Total** | | **143,2 + 17,6N Mo/h** |

Soit **~3,44 Go/jour** hors direct, ~4,7 Go/jour avec N=3. Le poste `games` = 92 % du transfert.

### 2.3bis Taille des caches locaux (ordre de grandeur)

Les caches sont absents de la machine d'audit ; tailles estimées à partir des événements filtrés et des réponses API mesurées.

| Fichier | Contenu | Taille estimée |
|---|---|---:|
| `~/.cache/espn-games.json` | événements `myTeams` ±90 j, fusionnés | 100–400 Ko |
| `~/.cache/espn-games-months/<sig>/` (P0-2) | 4–5 mois × 5–9 ligues, filtrés | 1–5 Mo |
| `~/.cache/espn-season.json` | saison complète `myTeams` | 0,3–1,5 Mo |
| `~/.cache/espn-extra-base.json` | 30 matchs × 11 ligues | 300–600 Ko |
| `~/.cache/espn-extra.json` | idem + rounds | 300–600 Ko |
| `~/.cache/espn-history.json` | 9 ligues, saison complète | 2–4 Mo |
| `~/.cache/espn-teams.json` | ~540 équipes (27 ligues) | 120–250 Ko |
| `~/.cache/espn-knock.json` / `espn-nextup.json` | ~100–250 événements | 100–300 Ko |
| `~/.cache/espn-standings.json` | 26 ligues + groupes | 200–400 Ko |
| `~/.cache/espn-logos/soccer/*.png` | 50–500 écussons 48 px | 0,5–5 Mo |
| `~/.cache/espn-logos/sprite.png` + `.json` | planche 8 colonnes | 1–4 Mo |

`liveM` ne lit pas `espn-history.json` (L671), mais relit `espn-season.json` et `espn-extra-base.json` **chaque minute**, d'où l'intérêt de l'index compact P0-3.

### 2.4 Défauts qui gonflent le coût

1. **`games` refetch 4–5 mois à chaque passage** (L56-61) : aucun cache mensuel, alors que les mois passés sont immuables. C'est le premier poste de tout le widget.
2. **Filtrage après téléchargement** : chaque `scoreboard` mensuel complet (294 Ko, 30–60 matchs) est téléchargé puis filtré par `jq` sur 1 à 5 équipes (L48, L279). L'API n'offre pas de filtre équipe : la seule réduction possible est la liste de ligues.
3. **`liveM` parse 4 caches chaque minute** (L661-672) même quand `N=0`, et sans cache de résultat : 120 jq/h + 60 bash/h inutiles au repos.
4. **`extra` refetch le mois courant de 11 ligues toutes les 30 min** (L573-580) + 6 `standings` (L614) : chevauchement avec `games`/`seasonAll`/`nextup`/`histfull`.
5. **`n >= 30`** (L69-73) : le seuil compte des lignes d'événements, pas des requêtes réussies. Avec une liste de ligues dynamique (moins d'événements), une équipe nationale ou un mois creux peut faire échouer `games` alors que les réponses sont valides.
6. **Pas de `trap`** : les `exit 1` L80, L606, L761, L833, L936 laissent `$tmp` derrière eux ; les timeouts coupent bash au milieu d'un `wait` et laissent des `curl`/fichiers.
7. **Timeouts trop courts dans le pire cas** : `games` 240 s pour 23 vagues × 16 s ≈ 368 s ; `standings` 90 s pour 96 s ; `histfull` 150 s pour 176 s.
8. **`teamsDb` écrase le cache avec un résultat partiel** (L500-503) : si une seule ligue répond, les 26 autres disparaissent du catalogue jusqu'au lendemain.
9. **`formsData` lit `/root/.cache/...` en dur** (L529) alors que tous les autres scripts utilisent `~/.cache` : si `$HOME != /root`, les formes du bandeau sont vides. Utilise aussi `/usr/bin/jq` en dur.
10. **Caches dupliqués par source** : `espn-games`, `espn-season`, `espn-extra-base`, `espn-nextup`, `espn-hist-base`, `espn-knock` contiennent des chevauchements de matchs ; le même mois de la même ligue est retéléchargé par plusieurs sources.

---

## 3. Plan d'optimisation P0 / P1 / P2

### P0 — gains majeurs, faible risque

| # | Levier | Gain estimé | Lignes |
|---|---|---|---|
| P0-1 | `games`/`seasonAll` limités aux ligues de `myTeams` (+ CDF, UEFA, nations) | `games` 448→~80 req/h ; transfert 132→~24 Mo/h ; `seasonAll` froid 362→~65 | L10-15, L239-244 |
| P0-2 | Cache mensuel immuable pour `games` : mois courant toujours, mois passés lus, mois futurs rafraîchis 1×/24 h | `games` 112→~5 req/exécution ; 448→112 req/h seul, **80→~20 req/h** avec P0-1 | L51-61, L69-83, L234 |
| P0-3 | Gating `liveM` par index compact + cache de résultat | 120 jq/h et 60 gros parsings/h → 0 au repos ; 0 requête inutile | L655-672, L721-724, L234 |
| P0-4 | `trap` de nettoyage + `mktemp -d /tmp/espn.XXXXXX` + `rm -rf` sur tous les `exit` | Supprime les orphelins ; ne touche jamais au GuestShell | L9, L80, L238, L384, L455, L533, L606, L656, L726, L761, L791, L833, L863, L936 |
| P0-5 | Remplacer le seuil `n>=30` par « au moins une réponse non vide ou cache existant » | Évite l'échec `games` quand le périmètre est réduit | L69-81 |

### P1 — gains moyens, risque modéré

| # | Levier | Gain estimé | Lignes |
|---|---|---|---|
| P1-1 | `extra` 30 min→1 h (2 h hors saison) + liste dynamique | 34→~14 req/h ; 7,2→~2,7 Mo/h | L535, L654 |
| P1-2 | `nextup` 6 h→12 h + fenêtre 4→3 mois | 7,33→~2,0–2,75 req/h (8–11 ligues) | L792, L826, L861 |
| P1-3 | `histfull` 6 h→24 h | 2,5→~0,63 req/h | L995 |
| P1-4 | `standings` limité au périmètre affiché (Top5 + UEFA + ligues `myTeams`) | 26→~9 req/exécution ; 4,33→~1,5 req/h | L388 |
| P1-5 | `teamsDb` 24 h→168 h (7 j) | 1,13→~0,16 req/h | L527 |
| P1-6 | `knock` 6 h→12 h | 2→1 req/h | L789 |
| P1-7 | `scheds` 12 h→24 h | 0,58→0,29 req/h | L383 |
| P1-8 | `formsData` : corriger `$HOME`, ou dériver les formes de `extra.out` dans l'OWL | 4 jq/h→0 ; corrige un bug silencieux | L528-531, L1429 |
| P1-9 | Fusion `teamsDb` avec l'ancien cache (anti-écrasement partiel) | Fiabilité catalogue | L500-508 |
| P1-10 | Aligner timeouts et concurrence (`-m 10`, 8 parallèles) | Évite les kills au milieu de `wait` | L48, L54, L237, L453, L995 |

### P2 — gains plus faibles ou refactor

| # | Levier | Gain estimé | Lignes |
|---|---|---|---|
| P2-1 | Backfill annuel `dates=YYYY&limit=1000` à froid pour `seasonAll`/`histfull` | 362→56 req (une fois) ; 108→18 | L291-317, L894-911 |
| P2-2 | `curl --parallel` + un seul `jq -s` par source | curl 502→~40/h, jq ~681→~70/h | L44-61 |
| P2-3 | Cache brut mensuel partagé entre `games`/`seasonAll`/`extra`/`nextup`/`histfull` | ~20 req/h et ~5 Mo/h en moins | L303, L569, L766, L838, L902 |
| P2-4 | `now` 1 s→5 s/15 s | 3 600→240–720 ticks UI/h (0 requête) | L996 |
| P2-5 | Scan sprite 1×/h au lieu de chaque `games` | 1 `find`+`sort`+`sha256sum`/15 min en moins | L104-105 |
| P2-6 | Purger/nettoyer `espn-games.json` quand `myTeams` change (signature) | Évite 7 jours d'événements orphelins en cache | L70-75 |

**Bilan cumulé (hors direct, caches chauds, 1 équipe)** :

| Étape | Req/h | Processus/h | Transfert/h |
|---|---:|---:|---:|
| Départ | 502 | ~1 254 | 143 Mo |
| + P0-1 (ligues dynamiques) | ~134 | ~516 | ~35 Mo |
| + P0-2 (cache mensuel `games`) | ~74 | ~400 | ~17 Mo |
| + P0-3 (gating `liveM`) | ~74 | ~278 | ~17 Mo |
| + P1 (intervalles + `extra` dynamique) | **~41** | **~180** | **~10 Mo** |

Hypothèse : **1 club** ⇒ 5 ligues pour `games`/`seasonAll` (domestique + CDF + 3 UEFA) et 8 pour `extra`/`nextup`. Avec **5 clubs de 5 pays**, compter 8–9 ligues pour `games`/`seasonAll` et jusqu'à 13 pour `extra`/`nextup` : multiplier `games`/`seasonAll` par ~1,6–1,8 et `extra` par ~1,6. Les totaux restent sous ~70 req/h et ~300 processus/h, très loin des 502/1 254.

**Non recommandé** : limiter `teamsDb` aux ligues affichées. `teamsDb` est le catalogue de l'écran de choix (L1270-1307) ; le réduire supprimerait la recherche de clubs, donc une fonctionnalité. On garde les 27 ligues et on passe seulement à 7 jours.

---

## 4. Patchs exacts (avant/après)

### 4.1 P0-1 — listes de ligues dynamiques

**OWL, après L8** — ajouter la liste des ligues suivies :

```owl
let favLg=join(unique(myTeams.map(t=>(t.league??"")).filter(l=>l!="")),",")
```

**`games` L9-15 et `seasonAll` L238-244** — injecter `WANTLG` puis remplacer `CLUBS`/`NATS` :

```owl
let gamesScript="""    tmp=$(mktemp -d /tmp/espn.XXXXXX)
    WANT='"""+favStr+"""'
    WANTID='"""+favTid+"""'
    WANTNOTID='"""+favNoTid+"""'
    WANTLG='"""+favLg+"""'
```

```sh
# AVANT (L14-15 et L243-244)
CLUBS="fra.1 fra.2 fra.coupe_de_france ned.1 por.1 tur.1 bel.1 sco.1 gre.1 sui.1 aut.1 den.1 nor.1 swe.1 rou.1 cze.1 isr.1 cyp.1 uefa.europa uefa.europa.conf eng.1 esp.1 ger.1 ita.1 uefa.champions"
NATS="uefa.nations fifa.worldq.uefa fifa.friendly"

# APRÈS
LG=$(printf '%s' "$WANTLG" | tr ',' ' ')
if [ -z "$LG" ]; then
  # fallback : comportement actuel si myTeams n'a pas de league (état persisté ancien)
  CLUBS="fra.1 fra.2 fra.coupe_de_france ned.1 por.1 tur.1 bel.1 sco.1 gre.1 sui.1 aut.1 den.1 nor.1 swe.1 rou.1 cze.1 isr.1 cyp.1 uefa.europa uefa.europa.conf eng.1 esp.1 ger.1 ita.1 uefa.champions"
  NATS="uefa.nations fifa.worldq.uefa fifa.friendly"
else
  NONNAT=$(printf '%s\n' $LG | grep -Ev '^(uefa\.nations|fifa\.(worldq\.uefa|friendly))$' || true)
  if [ -n "$NONNAT" ]; then
    CLUBS=$(printf '%s\n' $NONNAT uefa.champions uefa.europa uefa.europa.conf \
      | awk 'NF && !s[$0]++' | tr '\n' ' ')
    case " $NONNAT " in *" fra.1 "*|*" fra.2 "*) CLUBS="$CLUBS fra.coupe_de_france";; esac
  else
    CLUBS=""
  fi
  NATS=""
  case " $LG " in
    *" uefa.nations "*|*" fifa.worldq.uefa "*|*" fifa.friendly "*)
      NATS=$(printf '%s\n' $LG uefa.nations fifa.worldq.uefa fifa.friendly \
        | awk 'NF && !s[$0]++' | tr '\n' ' ') ;;
  esac
fi
```

Effet : club L1 → `fra.1 fra.coupe_de_france uefa.champions uefa.europa uefa.europa.conf` (5 ligues) au lieu de 28. Nations → 3 ligues. Cinq clubs de 5 pays → ~8–10 ligues. Le fallback conserve l'ancien comportement si `league` est absent.

**`standings` L384-388** — même principe, restreint aux ligues qui ont un classement. Ajouter d'abord la ligne `WANTLG='"""+favLg+"""'` après `WANTNOTID` (L387), comme dans `games` :

```sh
# AVANT (L388)
TABLES="fra.1 fra.2 ned.1 por.1 tur.1 bel.1 sco.1 gre.1 sui.1 aut.1 den.1 nor.1 swe.1 rou.1 cze.1 isr.1 cyp.1 uefa.europa uefa.europa.conf uefa.nations fifa.worldq.uefa eng.1 esp.1 ger.1 ita.1 uefa.champions"

# APRÈS
TABLESALL="fra.1 fra.2 ned.1 por.1 tur.1 bel.1 sco.1 gre.1 sui.1 aut.1 den.1 nor.1 swe.1 rou.1 cze.1 isr.1 cyp.1 uefa.europa uefa.europa.conf uefa.nations fifa.worldq.uefa eng.1 esp.1 ger.1 ita.1 uefa.champions"
LG=$(printf '%s' "$WANTLG" | tr ',' ' ')
if [ -z "$LG" ]; then
  TABLES="$TABLESALL"
else
  TABLES=$(for l in eng.1 esp.1 ger.1 ita.1 fra.1 uefa.champions uefa.europa uefa.europa.conf $LG; do
    case " $TABLESALL " in *" $l "*) printf '%s ' "$l";; esac
  done | tr ' ' '\n' | awk 'NF && !s[$0]++' | tr '\n' ' ')
fi
```

**`extra` L535 et `nextup` L792** — union Top5 + UEFA + ligues suivies. Ajouter `WANTLG` en tête de chaque script (après `tmp=$(mktemp -d)`), car ces deux scripts ne le déclarent pas aujourd'hui :

```sh
# AVANT
LEAGUES="fra.1 fra.2 uefa.europa uefa.europa.conf uefa.nations eng.1 esp.1 ger.1 ita.1 fifa.worldq.uefa uefa.champions"

# APRÈS
BASE="eng.1 esp.1 ger.1 ita.1 fra.1 uefa.champions uefa.europa uefa.europa.conf"
LEAGUES=$(printf '%s\n' $BASE $(printf '%s' "$WANTLG" | tr ',' ' ') \
  | awk 'NF && !s[$0]++' | tr '\n' ' ')
```

Hors top5, cela ajoute au pire la ligue du club (ex. `ned.1`), ce qui **active** Rivaux dans cette ligue au lieu de le laisser vide : c'est un gain fonctionnel, pas une régression. Pour un utilisateur Top5/UEFA, on passe de 11 à 8 ligues.

Dans `extra`, filtrer aussi `rrun` (L624-626) sur `LEAGUES`, sinon les 6 `standings` de `RR` sont appelés même pour une ligue absente de `LEAGUES` :

```sh
for lg in $RR; do
  case " $LEAGUES " in *" $lg "*) rrun "$lg";; esac
done
```

Gain : 1 `standings`/exécution en moins quand `fra.2` n'est pas suivi (soit 2/h).

### 4.2 P0-2 — cache mensuel de `games`

Principe : le mois courant est toujours refetché (live/résultats), les mois passés sont immuables, les mois futurs sont rafraîchis une fois par 24 h. Un fichier `.ok` distingue « mois récupéré avec 0 match » de « jamais récupéré ».

Ajouter `set -o pipefail` en tête de `games` (bash) : sans cela, un `curl` en échec est masqué par le `jq` du pipe (L48), et un mois vide serait caché à tort comme valide.

**`games` L51-61** :

```sh
# AVANT
run() {
  fetch "$1" "$2" > "$tmp/$1-$2.jsonl" &
  n=$((n + 1))
  if [ "$n" -ge 5 ]; then wait; n=0; sleep 1; fi
}
MONTHS=$(for off in -4 0 30 60 90; do date -d "$off day" +%Y%m; done | sort -u)
for lg in $CLUBS $NATS; do
  for m in $MONTHS; do
    run "$lg" "$m"
  done
done
wait

# APRÈS
# Le cache mensuel contient des événements déjà filtrés par WANT : il DOIT être
# rangé par signature de suivi, sinon un changement de myTeams ressert les
# anciennes équipes pour les mois passés.
SIG=$(printf '%s|%s|%s' "$WANT" "$WANTID" "$WANTNOTID" | sha256sum | cut -d' ' -f1)
MC=~/.cache/espn-games-months/$SIG
mkdir -p "$MC"
CUR=$(date +%Y%m)
NOW=$(date +%s)
run() {
  ( f="$tmp/$1-$2.jsonl"
    if fetch "$1" "$2" > "$f.tmp"; then
      mv "$f.tmp" "$f"
      cp "$f" "$MC/$1-$2.jsonl.tmp" && mv "$MC/$1-$2.jsonl.tmp" "$MC/$1-$2.jsonl"
      : > "$MC/$1-$2.jsonl.ok"
    else
      rm -f "$f.tmp"
    fi ) &
  n=$((n + 1))
  if [ "$n" -ge 8 ]; then wait; n=0; sleep 1; fi
}
MONTHS=$(for off in -4 0 30 60 90; do date -d "$off day" +%Y%m; done | sort -u)
for lg in $CLUBS $NATS; do
  for m in $MONTHS; do
    f="$MC/$lg-$m.jsonl"
    if [ "$m" = "$CUR" ] || [ ! -f "$f.ok" ] \
       || { [ "$m" \> "$CUR" ] && [ $((NOW - $(stat -c %Y "$f.ok"))) -gt 86400 ]; }; then
      run "$lg" "$m"
    else
      [ -s "$f" ] && cp "$f" "$tmp/$lg-$m.jsonl"
    fi
  done
done
wait
# purge des signatures orphelines (changement d'équipes) et des vieux mois
find ~/.cache/espn-games-months -mindepth 1 -maxdepth 1 -type d -mtime +200 -exec rm -rf {} + 2>/dev/null
find "$MC" -type f -mtime +200 -delete
```

Le `SIG` est indispensable : sans lui, `games` réutiliserait un mois passé filtré sur les **anciennes** équipes après un changement de `myTeams`. `seasonAll` a déjà ce mécanisme (L305-309) ; `extra`/`nextup`/`histfull` ne filtrent pas par `WANT` (le `$wl` de L557/L815/L886 est déclaré mais inutilisé), donc leurs caches ne sont pas concernés.

**`games` L69-82** — supprimer le seuil 30 (indispensable après réduction du périmètre) :

```sh
# AVANT
n=$(cat "$tmp"/*.jsonl 2>/dev/null | wc -l)
...
if [ "$n" -ge 30 ] || [ -s "$cache" ]; then

# APRÈS
if [ -s "$cache" ] || [ "$(jq 'length // 0' "$tmp/fresh.json" 2>/dev/null || echo 0)" -gt 0 ]; then
```

(`fresh.json` est déjà créé L72.) Et sur le `else` L79-81 :

```sh
else
  rm -rf -- "$tmp"
  exit 1
fi
```

Effet immédiat : `games` passe de 112 à ~5 requêtes/exécution (mois courant des 5 ligues dynamiques), soit **448 → ~20 req/h** et **132 → ~6 Mo/h**. Sans P0-1, on passe déjà de 112 à 28 (448→112 req/h, 132→33 Mo/h).

### 4.3 P0-3 — gating `liveM`

**`games` L234** — produire un index compact (le cache `games` ne contient déjà que les matchs de `myTeams`) :

```sh
cat "$tmp/games.json" | jq -c --argjson f "$(date +%s)" 'map(. + {fetchedAt: $f})'
jq -c --argjson now "$(date +%s)" '
  [.[] | select(.state=="in" or
     (.state=="pre" and (.at//0) <= ($now+10800) and (.at//0) >= ($now-10800)))
   | {league, at, state}]
  | unique_by(.league + ":" + (((.at//0)/86400)|floor|tostring))' \
  "$tmp/games.json" > ~/.cache/espn-live-index.json.tmp \
  && mv ~/.cache/espn-live-index.json.tmp ~/.cache/espn-live-index.json
```

**`liveM` L655-672** — sortie rapide si aucun candidat :

```sh
# APRÈS `now=$(date +%s)` (L657)
IDX=~/.cache/espn-live-index.json
LAST=~/.cache/espn-live.json
if [ -s "$IDX" ] && ! jq -e --argjson now "$now" '
      any(.[]; (.state//"") == "in"
        or ((.at//0) <= ($now+120) and (.at//0) >= ($now-10800)))' \
      "$IDX" >/dev/null 2>&1; then
  if [ -s "$LAST" ]; then cat "$LAST"; else printf '{"at":%s,"items":[]}' "$now"; fi
  rm -rf -- "$tmp"
  exit 0
fi
```

**`liveM` L721-724** — écrire le cache de résultat et servir les items précédents en cas d'échec partiel :

```sh
# AVANT
jq -cs --argjson now "$now" '{at: $now, items: unique_by(.id)}' "$tmp"/*.jsonl 2>/dev/null || printf '{"at":%s,"items":[]}' "$now"
rm -rf "$tmp"

# APRÈS
jq -cs --argjson now "$now" '{at: $now, items: unique_by(.id)}' "$tmp"/*.jsonl \
  > "$tmp/live.json" 2>/dev/null || printf '{"at":%s,"items":[]}' "$now" > "$tmp/live.json"
# Si aucune requête n'a rien rapporté, resservir le dernier état s'il a < 10 min
if [ "$(jq '.items|length' "$tmp/live.json" 2>/dev/null || echo 1)" -eq 0 ] \
   && [ -s "$LAST" ] && [ $((now - $(jq '.at // 0' "$LAST"))) -lt 600 ]; then
  cp "$LAST" "$tmp/live.json"
fi
cp "$tmp/live.json" "$LAST.tmp" && mv "$LAST.tmp" "$LAST"
cat "$LAST"
rm -rf -- "$tmp"
```

Le gate est volontairement large (3 h avant, 3 h après) : un match qui commence est déjà dans l'index, et un match en cours reste couvert même si `games` n'a pas encore rafraîchi son état. Si `games` est en retard de 15 min, le direct peut démarrer avec ≤15 min de retard ; c'est le seul compromis. Le cache `LAST` évite l'écran vide si une requête échoue, sans ressusciter un match terminé au-delà de 10 min.

### 4.4 P0-4 — orphelins sans tuer le GuestShell

Après **chaque** `tmp=$(mktemp -d)` (L9, L238, L363, L384, L455, L533, L656, L726, L791, L863) :

```sh
tmp=$(mktemp -d /tmp/espn.XXXXXX)
cleanup() {
  rc=$?
  trap - EXIT INT TERM
  kill $(jobs -p) 2>/dev/null
  case "$tmp" in /tmp/espn.*) rm -rf -- "$tmp";; esac
  exit $rc
}
trap cleanup EXIT INT TERM
```

Règles :
- **Jamais** `pkill curl`, `killall curl`, `kill 0`, `kill -$$` : cela tuerait d'autres widgets ou le shell invité.
- `kill $(jobs -p)` ne cible que les enfants du script courant.
- Le préfixe `/tmp/espn.` permet un nettoyage sûr des restes de plus de 2 h au démarrage suivant, sans toucher aux `tmp.*` des autres widgets :

```sh
find /tmp -maxdepth 1 -type d -name 'espn.*' -mmin +120 -exec rm -rf {} + 2>/dev/null
```

À ne lancer qu'une fois par heure (fichier marqueur) ou une fois par run de `games`, pas dans les 10 scripts, pour ne pas ajouter 10 `find`/h.

- Sur les sorties anticipées, ajouter `rm -rf -- "$tmp"` avant `exit 1` : L80, L606, L761, L833, L936.
- `liveM` L722 et `knock` L761 : idem.

### 4.5 P1-1/2/3/5/6/7 — intervalles

| Ligne | Avant | Après | Justification |
|---|---|---|---|
| L654 | `source extra=... every 30m` | `every 1h` | résultats rivaux/Top5/Europe ; le live est déjà couvert par `liveM` |
| L861 | `source nextup=... every 6h` | `every 12h` | les affiches à venir bougent lentement ; report visible sous 12 h |
| L995 | `source histfull=... every 6h` | `every 24h` | l'historique ne change qu'après un match ; `games`/`extra` couvrent le récent |
| L527 | `source teamsDb=... every 24h` | `every 168h` (ou `7d`) | catalogues de clubs quasi statiques |
| L789 | `source knock=... every 6h` | `every 12h` | l'arbre ne bouge qu'après un tour |
| L383 | `source scheds=... every 12h` | `every 24h` | journées/ancres recalculées rarement |
| L996 | `source now=clock every 1s` | `every 5s` (ou `15s`) | 0 requête ; réduit les recompositions UI. Garder 1 s si le spinner et le compte à rebours à la seconde sont critiques |

### 4.6 P1-2 — fenêtre `nextup` 4→3 mois

**L826** :

```sh
# AVANT
MONTHS=$(for off in 0 30 60 90; do date -d "$off day" +%Y%m; done | sort -u)

# APRÈS
MONTHS=$(for off in 0 30 60; do date -d "$off day" +%Y%m; done | sort -u)
```

Avec 11 ligues dynamiques → 8 : 8×3 = 24 requêtes/exécution, 2×/jour = **48/jour = 2 req/h** (au lieu de 7,33).

### 4.7 P1-8 — `formsData`

**L528-531** :

```owl
# AVANT
let formsScript="""
    /usr/bin/jq -c '[.[] | select(.state == "post" and .home.abbr != null and .away.abbr != null) | {id, at, home: .home.abbr, away: .away.abbr, hw: .home.winner, aw: .away.winner}]' /root/.cache/espn-extra.json
  """
source formsData=cmd("bash -c ${sh(formsScript)}")every 15m json timeout 60s

# APRÈS (correctif minimal)
let formsScript="""
    jq -c '[.[] | select(.state == "post" and .home.abbr != null and .away.abbr != null) | {id, at, home: .home.abbr, away: .away.abbr, hw: .home.winner, aw: .away.winner}]' "$HOME/.cache/espn-extra.json"
  """
source formsData=cmd("bash -c ${sh(formsScript)}")every 1h json timeout 60s
```

Variante sans processus (préférable, fonctionnalité identique) : `espn-extra.json` est exactement la sortie de `extra` ; remplacer L1429 :

```owl
let ex=(formsData.out??[]).filter(g=>g.home==t.abbr||g.away==t.abbr)
```

par :

```owl
let ex=(extra.out??extra??[]).filter(g=>g.state=="post"&&g.home!=null&&g.away!=null&&(g.home.abbr==t.abbr||g.away.abbr==t.abbr))
  .map(g=>({id:g.id,at:g.at,home:g.home.abbr,away:g.away.abbr,hw:g.home.winner,aw:g.away.winner}))
```

et supprimer la source `formsData` : les formes du bandeau restent calculées, avec 0 requête et 0 jq supplémentaire. `BannerForm` garde son fallback sur `all` (L1430).

À vérifier au passage : L1429 lit `formsData.out`, alors que les sources tableau sont utilisées directement ailleurs (`standings??[]` L1069, `extra??[]` L1123). Si `formsData` est un tableau, `formsData.out` est nul et le bandeau retombe déjà sur `all` (L1430-1431) : le bug est latent, pas visible. Adapter la forme (`extra.out` ou `extra`) au type réel renvoyé par `cmd`. 


### 4.8 P1-9 — `teamsDb` sans écrasement partiel

**L500-503** :

```sh
# AVANT
cache=~/.cache/espn-teams.json
if [ "$(jq 'length // 0' "$tmp/teams.json")" -gt 0 ]; then
  cp "$tmp/teams.json" "$cache.tmp" && mv "$cache.tmp" "$cache"

# APRÈS
cache=~/.cache/espn-teams.json
if [ "$(jq 'length // 0' "$tmp/teams.json")" -gt 0 ]; then
  if [ -s "$cache" ]; then
    jq -cs '.[0] as $new | .[1] as $old
      | ($new + [$old[] | select(.key as $k | ($new | map(.key) | index($k)) == null)])' \
      "$tmp/teams.json" "$cache" > "$tmp/merged.json" \
      && mv "$tmp/merged.json" "$tmp/teams.json"
  fi
  cp "$tmp/teams.json" "$cache.tmp" && mv "$cache.tmp" "$cache"
```

Ainsi une ligue en échec ne supprime pas ses équipes du catalogue.

### 4.9 P1-10 — timeouts et concurrence

- **`games` L48** : `-fsm 15` → `-fsm 10` ; **L54** : `-ge 5` → `-ge 8`. Pire cas : 112/8 = 14 vagues × 11 s = **154 s** < 240 s.
- **`standings` L425** : `-fsm 15` → `-fsm 10` ; **L433** : `-ge 5` → `-ge 8`. Pire cas 26/8 = 4 vagues × 11 = 44 s < 90 s.
- **`histfull` L886** : `-fsm 15` → `-fsm 10` ; **L892** : `-ge 10` → `-ge 8`. Froid 114/8 = 15 vagues × 11 = 165 s < 150 s ? Non : passer le timeout L995 à `210s`, ou faire le backfill annuel P2-1 (18 requêtes).
- **`seasonAll` froid** : passer le timeout L361 à `600s` **ou** appliquer P2-1 (56 requêtes annuelles, ~7 vagues×31 s=217 s).
- **`extra`** : 46/8×11 = 63 s < 150 s, rien à changer.

### 4.10 P2-1 — backfill annuel à froid (optionnel)

Quand `seasonAll` n'a pas de cache (`lms` vide), remplacer 13 mois/ligue par 1–2 requêtes `dates=YYYY&limit=1000` (2,8–3,8 Mo), puis marquer les 12 mois comme couverts dans `lms`. Même principe pour `histfull` (2 requêtes/ligue au lieu de 12). Preuve : §1.3. Ne **pas** l'utiliser pour les rafraîchissements : 3 Mo/ligue toutes les 12 h serait pire que le mensuel.

Gain : `seasonAll` froid **362→56** requêtes ; `histfull` froid **114→18**. À réserver au premier lancement/changement d'équipes (`sig` L305-309). Contrainte : traiter les réponses en flux (`curl | jq`), concurrence ≤3, timeout 600 s, sinon pic mémoire/transfert.

### 4.11 P2-2 — `curl --parallel` (esquisse)

**L44-61** : générer un fichier de config curl avec une entrée `url`/`output` par ligue-mois, puis :

```sh
cfg="$tmp/curl.cfg"; : > "$cfg"
for lg in $CLUBS $NATS; do
  for m in $MONTHS; do
    printf 'url = "https://site.api.espn.com/apis/site/v2/sports/soccer/%s/scoreboard?dates=%s"\noutput = "%s/%s-%s.json"\n' \
      "$lg" "$m" "$tmp" "$lg" "$m" >> "$cfg"
  done
done
curl -K "$cfg" --parallel --parallel-max 8 --retry 1 --retry-delay 1 -fsm 15 --compressed || true
```

Puis un seul `jq -c` sur `"$tmp"/*.json` avec `input_filename` pour récupérer `lg`/`m`. Gain : 1 curl + 1 jq par exécution au lieu de 112+112. Risque : version de curl dans proot ; tester `curl --version` sur l'appareil (le binaire hôte est 8.23, mais proot peut embarquer plus ancien).

### 4.12 P2-3 — cache brut mensuel partagé

`games`, `seasonAll`, `extra`, `nextup`, `histfull` retéléchargent le même mois de la même ligue. Un cache brut `~/.cache/espn-raw/{lg}-{YYYYMM}.json` avec TTL 5 min pour le mois courant et immuable pour les mois passés permettrait :
- `extra` chaud : 11 scoreboard → 0 (lit `games`) ;
- `nextup`/`histfull` : 11/9 → 0 ;
- économie ~20 req/h et ~5 Mo/h après P0+P1.

Coût : 28 × ~300 Ko = 8,4 Mo pour le mois courant, et politique de purge à définir (garder 3–4 mois = ~34 Mo). À faire après P0/P1, car le gain est plus faible et le risque de cache corrompu plus élevé.

---

## 5. Fonctionnalité préservée

| Optimisation | Ce qui change | Fonctionnalité | Preuve de préservation |
|---|---|---|---|
| P0-1 ligues dynamiques `games`/`seasonAll` | moins de ligues interrogées | Mes matchs, résultats, à venir, cotes, rappels, logos, FR/EN | `base`/`allMine` filtrent déjà sur `myTeams` (L1071, L1077) ; CDF/UEFA/nations ajoutés ; fallback liste complète |
| P0-1 `standings` dynamique | 26→~9 ligues | Classements « Mes matchs », Top 5, Europe, nations | `myTablesAll`, `topTables`, `euroTables` (L1119, L1138-1139, L1145) ne lisent que Top5/UEFA/ligues suivies |
| P0-1 `extra`/`nextup` dynamiques | 11→8–11 ligues | Rivaux, Top 5, Europe, affiches à venir | `rivLgs`/`myLeagues` L1126-1128 ; Top5 L1121-1122 ; UEFA L1140 |
| P0-2 cache mensuel `games` | mois passés lus, futur 1×/24 h | Mes matchs, résultats récents, 90 j à venir, cotes, rappels | `seasonAll` couvre la saison (L1063-1064) ; `nextup` couvre l'avenir ; mois courant toujours frais |
| P0-3 gating `liveM` | requêtes seulement si match en cours/imminent | Scores live, minute, âge live, hero live | `liveList` L1099 ; `LAST` renvoie le dernier état ; fenêtre 3 h |
| P0-4 `trap` | nettoyage des enfants/tmp | Toutes | Ne touche qu'aux jobs du script et à `/tmp/espn.*` |
| P1-1 `extra` 1 h | rivaux/Europe/Top5 rafraîchis 1×/h | Rivaux, Top 5, Europe, formes | `liveM` reste à 1 min pour le direct ; `games` à 15 min pour Mes matchs |
| P1-2 `nextup` 12 h / 3 mois | affiches à venir 2×/jour | À venir, Rivaux, Top5, Europe | `nextup` ne sert qu'aux listes `pre` (L1125, L1131, L1135, L1143) |
| P1-3 `histfull` 24 h | historique 1×/jour | Historique, journées J1..Jn, Top5/Europe | `histMap` L1151 ; les résultats récents restent dans `extra`/`games` |
| P1-5 `teamsDb` 7 j | catalogue plus frais à 7 j | Écran de choix, recherche, logos, en-têtes | `teamsDb` L1270-1307 non modifié ; seule la fraîcheur change |
| P1-6 `knock` 12 h | arbre 2×/jour | Arbre C1/EUR/CONF | `knockLg` L1146-1147 ; l'arbre ne change qu'après un tour |
| P1-8 `formsData` dérivé | plus de processus dédié | Formes V/N/D du bandeau | Même source `espn-extra.json` ; fallback `all` conservé L1430 |
| Toutes | aucun élément UI supprimé | Onglets, classements, historique, bracket, cotes, rappels, logos, FR/EN, taille | Aucune ligne de rendu L1000-1955 n'est supprimée ; seules les sources changent |

---

## 6. Risques de régression et tests

### 6.1 Risques

1. **`t.league` absent ou obsolète** (état persisté d'une ancienne version) : le fallback liste complète protège, mais il faut le tester.
2. **Équipe nationale** : `league` peut valoir `uefa.nations`, `fifa.worldq.uefa` ou `fifa.friendly`. Le patch ajoute les 3 ; vérifier qu'aucune ne déclenche 3 ligues UEFA de clubs inutiles.
3. **Coupe de France** : un club L1/L2 doit voir ses matchs CDF. Le patch ajoute `fra.coupe_de_france` uniquement pour `fra.1`/`fra.2`.
4. **Mois vide** : `games` doit marquer un mois sans match comme récupéré (`.ok`) pour ne pas le refetcher toutes les 15 min. Tester juin/juillet.
5. **Passage de mois** : `CUR` est local (`date +%Y%m`), l'API est UTC. Tester le 1er du mois à 00:30 (Europe/Paris) : le mois UTC précédent peut encore contenir des matchs. Le cache mensuel + `-4 j` couvre le trou, mais vérifier.
6. **Gating `liveM`** : un match qui commence moins de 15 min après le dernier `games` peut être raté jusqu'au run suivant. Fenêtre 3 h + `state=="pre"` atténue, mais tester un coup d'envoi imminent et un match qui passe de `pre` à `in` sans rafraîchissement de `games`.
7. **`LAST` live** : si `liveM` échoue complètement, on ressert l'ancien état ; l'âge `liveAt` peut vieillir. C'est préférable à un écran vide, mais l'UI doit afficher `liveWarn` au-delà de 15 min (déjà L1103).
8. **Backfill annuel** : `dates=YYYY&limit=1000` renvoie 2 saisons dans une année civile. Le filtre `keep` L329/L921 élimine la saison précédente, mais vérifier les mois de juillet/août. Pic mémoire/transfert : traiter en flux, concurrence ≤3.
9. **`curl --parallel`** : version de curl dans proot inconnue ; `--parallel` existe depuis 7.66. Tester sur l'appareil avant de généraliser.
10. **`teamsDb` fusion** : si le cache ancien contient des clés obsolètes, elles persistent. Prévoir une purge annuelle ou un champ `season`.
11. **`now` 15 s** : le spinner (`elapsed%10`, L1739) et « actualisation Xs » deviennent saccadés. Si c'est inacceptable, garder 1 s ; le gain est uniquement CPU/UI, pas réseau.
12. **Fuseau/`strftime`** dans le backfill : `(.at|strftime("%Y%m"))` est en UTC, cohérent avec l'API.

### 6.2 Tests à faire

| Test | Attendu |
|---|---|
| 1 club L1 + 1 club L2 + 1 nation + 2 clubs étrangers (5 équipes) | `games`/`seasonAll` couvrent CDF, UEFA, nations ; aucune ligue inutile |
| `myTeams` vide / `league` vide (état ancien) | fallback liste complète, setup inchangé |
| Changement de `myTeams` | `seasonAll` `sig` (L305-309) repart ; `games` cache mensuel ne sert pas d'anciennes équipes à l'UI |
| Installation neuve, réseau lent | `games` finit < 240 s ; `seasonAll` froid < 600 s ou backfill annuel ; aucun `/tmp/espn.*` restant |
| Timeout artificiel (`-m 1`) sur une ligue | `trap` nettoie ; pas de `curl` orphelin ; pas d'impact sur les autres widgets |
| Samedi 5 matchs simultanés | `liveM` N≈3–6 ; requêtes uniquement sur les couples concernés ; `LAST` cohérent |
| Match à J-2 min | `liveM` commence à requêter dans la fenêtre ; score/minute apparaissent |
| Fin de match | `liveM` s'arrête ; `games`/`extra` prennent le relais ; `LAST` ne reste pas bloqué |
| 1er du mois à 00:30 | aucun match perdu entre mois local et UTC |
| Mois de juin/juillet (0 match) | `games` ne refetch pas les mois passés ; aucun échec `n>=30` |
| `teamsDb` avec 1 ligue en 404 | le cache conserve les 26 autres |
| `formsData` avec `HOME=/root` et `HOME≠/root` | formes identiques ; bug `/root` corrigé |
| `curl --version` dans proot | `--parallel` disponible ou fallback boucle actuelle |
| FR/EN, taille S/M/L/XL, onglets, bracket, cotes, rappels | identiques avant/après (comparaison visuelle + notifications) |

### 6.3 Ordre de déploiement conseillé

1. P0-4 (`trap`) + P0-5 (seuil) : sécurise les runs suivants.
2. P0-1 (ligues dynamiques) : réduit immédiatement 448→~80 req/h et 132→~24 Mo/h.
3. P0-2 (cache mensuel) : 80→~20 req/h et 24→~6 Mo/h.
4. P0-3 (gating live) : supprime 120 jq/h au repos.
5. P1-1/2/3/4/5 : ~41 req/h, ~10 Mo/h, ~180 processus/h.
6. P1-8/9/10 et P2 : fiabilité, backfill, parallélisation.
