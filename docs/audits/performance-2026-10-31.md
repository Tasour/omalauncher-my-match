# Audit performance — 2026-10-31

## Hotspots mesurés

| Priorité | Constat | Correction |
|---|---|---|
| P0 | `prematch.owl` relisait `espn-history.json` (1,14 Mo / 3 027 matchs) via `cat` sans intervalle, donc ~1 440 fois/jour. | source lue toutes les **6 h**, pool limité au championnat du match. |
| P0 | horloge principale toutes les **15 s** ; `allRaw` et `cal` dépendaient d'elle. | horloge principale à **1 min** ; cutoffs et calendrier sur l'horloge **horaire**. |
| P1 | `prematch` recalculait des rangs moyens inutilisés et un `groupBy` global supplémentaire. | calculs supprimés, un seul pool dédupliqué. |
| P1 | écran principal chargeait des tables par défaut. | laissé à `showTables`, pas de rendu forcé. |
| P2 | mois `.jsonl` vides refetchés. | à traiter dans une prochaine passe (marqueur vide). |
| P2 | `liveM` relancé toutes les minutes hors match. | à traiter avec une source conditionnelle. |

## Gains

- historique avant-match : **360× moins d'exécutions** (60 s → 6 h) ;
- horloge principale : **4× moins de ticks** (15 s → 60 s) ;
- `allRaw`/calendrier : recalcul **horaire** au lieu de toutes les 15 s ;
- app : moins de listes à regrouper et de nœuds de rang.

## Critères

- 0 à 4 lectures d'historique par jour.
- <= 1 tick principal par minute hors direct.
- aucune régression des 5 avant/5 après, des tendances et des prochains matchs.
- `owl-check` OK, suite complète verte.
