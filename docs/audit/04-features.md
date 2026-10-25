# Cartographie fonctionnelle et plan de recette — `my-match.owl`

**Objet** : widget Omalauncher « My Matches – Football », version 5.7, 1 955 lignes.
**Fichier audité** : `/home/tasour/Work/omalauncher-my-match/widget/my-match.owl`.
**Audit initial** : `docs/audit-omalauncher-2026-10-25.html`, cité `audit L.x`.
**Règle** : aucune fonctionnalité n'est supprimée. Toute optimisation doit être iso-fonctionnelle ; un changement visible non validé est une régression.

**Conventions**
- `L.x` = ligne du fichier `.owl` ; `L.x-y` = plage.
- Les volumétries de requêtes sont des **estimations statiques** déduites des boucles et intervalles, hors retries et logos. Elles doivent être confirmées par un compteur instrumenté.
- Criticité : **Must** = sans elle le widget perd son usage ; **Should** = attente produit forte ; **Could** = confort.

---

## 0. Chiffres clés

| Indicateur | Valeur | Référence |
|---|---:|---|
| Taille du widget | 6×4, minimum 3×3 | L.1-3 |
| Sources | 14 : 11 `cmd`, 2 `clock`, 1 `file` | L.237, 361, 383, 453, 527, 531, 654, 724, 789, 861, 995, 996-998 |
| États | 25, dont 15 persistés | L.999, 1008-1031 |
| Composants UI | 14 | L.1180-1691 |
| Ligues interrogées | 28 matchs/saison ; 26 classements ; 27 catalogue ; 11 rivaux/Top 5/nextup ; 9 historique ; 3 knockout | L.14-15, 243-244, 388, 456, 535, 727, 792, 864 |
| Sélection | 1 à 5 équipes, clubs et sélections | L.1268-1321 |
| Langues | EN par défaut, FR | L.999-1000 |
| Tailles | S, M, L, XL | L.1020, 1107 |
| Caches | 10 JSON de données + logos + sprite | L.70, 303, 439, 500, 569, 631, 766, 838, 902, 984, 998 |
| Requêtes estimées, régime stable | ≈ 15 250/j, ≈ 636/h, hors live et logos | §2.4 |
| Requêtes `games` seules | 140/passage × 96 passages/j ≈ 13 440/j | L.14-15, 56, 237 |
| Orphelin constaté | 100 % d'un cœur, 45 min | audit L.131-134, 181, 212-236 |
| Rendu constaté | 111 fps au repos avec now-playing | audit L.133, 183-184, 240-255 |

---

## 1. Inventaire fonctionnel

### 1.1 Tableau F01-F16

Lecture : la colonne **Code** cite les lignes et, quand ils sont déterminants, les `let`, `state` et composants/nodes (`heroMatch`, `myTeams`, `MatchBanner`, etc.) ; la colonne **Données / dépendances** donne d'abord la source de données, puis les dépendances runtime.

| ID | Fonction | Description | Code | Données / dépendances | Criticité |
|---|---|---|---|---|---|
| F01 | Coque, titre, responsive | Widget 6×4, min 3×3 ; titre localisé ; écran scrollable ; mode `wide` ≥ 280 px ; police selon `uiSize`. | L.1-4, 1106-1107, 1692-1701 | `screenWidth`, `tileWidth`, thème runtime | Must |
| F02 | Sélection 1-5 équipes | Recherche club/sélection, brouillon, retrait, plafond 5, validation avec `refresh()` ; affichage des puces et compteur. | L.1009-1012, 1035, 1268-1321, 1305, 1315, 1554-1576, 1712-1732, 1779-1781 | `teamsDb` L.454-527 ; `myTeams` persisté ; `notify()` | Must |
| F03 | Identité et injection | `favStr`/`favTid`/`favNoTid` ; filtrage par `tid` sinon abréviation ; `kind` c/n ; cas `LYON`. | L.6-12, 44-48, 239-241, 273-279, 658-660, 1071, 1077, 1084-1098, 1128 | `teamsDb` (`abbr`,`tid`,`kind`,`league`) ; `sh()` | Must |
| F04 | Onglets principaux | Mes matchs / Rivaux / Top 5 / Europe ; `view` persisté ; `selJ` remis à -1 au changement. | L.1120, 1533-1536, 1702-1707, 1027 | i18n `S` L.1000 | Must |
| F05 | Filtres secondaires | Puces équipes ; Top 5 ENG/ESP/GER/ITA/FRA + ALL ; Europe C1/EUR/CONF. | L.1121-1122, 1140, 1554-1576, 1538-1553, 1751-1766, 1008, 1028-1029, 1036 | `myTeams`, listes de ligues | Must |
| F06 | Hero match | Prochain match ou live : équipes, logos, classement, heure/minute, compte à rebours, cotes, formes. | L.1081, 1108-1116, 1469-1527, 1470-1474, 1494, 1519, 1502-1515, 1584, 1622-1624, 1660-1662, 1790-1792 | `all` L.1062-1064, `tables` L.1069, `nextup` L.1124-1125, `formsData` L.1429 | Must |
| F07 | Cotes 1/N/2 | Dans le hero Mes matchs uniquement ; match à venir, trois cotes décimales, couleurs selon l'équipe suivie, rien si une cote manque. | L.48, 279, 1454-1467, 1475-1479, 1483-1488, 1502-1515 | `competitions[0].odds[].moneyline` ; replis close/open | Should |
| F08 | Live et fraîcheur | Superposition du live le plus frais ; score, minute, pastille verte ; âge live ; warning > 15 min ; hero live. | L.655-724, 661-671, 666, 709, 721, 1073, 1099-1103, 1411-1414, 1396-1404, 1596 | `liveM` + 4 caches L.671 ; `now` 1 s ; `liveM` 1 min | Must |
| F09 | À venir | Matchs futurs triés, date/heure locale, compte à rebours, `nextup`, hero du plus proche. | L.1074-1076, 1081, 1125, 1594-1598, 1371-1378, 1116 ; sources L.790-861, 9-237, 238-361 | `nextup` 6 h, `games` 15 min, `seasonAll` 12 h | Must |
| F10 | Résultats et forme | 5 derniers résultats, scores, vainqueur en gras, pastille V/N/D ; bandeaux de forme. | L.1075, 1105, 1593, 1355-1356, 1387-1389, 1322-1327, 1415-1442, 528-531 | `games`, `seasonAll`, `extra`, `histfull` ; `winner` | Must |
| F11 | Journées et navigation | Numérotation Jn, libellé par ligne en Mes matchs ; navigation gauche/droite en Rivaux (équipe) et Top 5/Europe ; estimation à venir, phases finales. | L.362-383, 1065-1066, 1334-1352, 1030, 1158-1159, 1626-1631, 1664-1669, 1805-1811, 1844-1850, 1883-1889 | `scheds`, standings `gamesPlayed` L.614/955, `histfull`, `extra`, `knock` ; K L.613/954 ; seuil 345 600 s L.949 | Must |
| F12 | Classements | Multi-groupes, J/V/N/D, BP:BC en large, +/-, Pts ; équipe suivie en gras ; zones et légende. | L.384-453, 388, 425-428, 1069, 1119, 1137-1139, 1145, 1210-1267, 1822-1831, 1861-1870, 1900-1909 | ESPN standings ; `ends` ; cache 6 h L.439-451 ; `teamsDb` | Must |
| F13 | Historique de saison | 9 compétitions, saison août-juillet, journées passées/futures ; utilisé par Top 5 et Europe. | L.862-995, 864, 894-900, 902-934, 937-982, 1151-1175, 1659-1683, 1844-1859, 1883-1899 | `histfull` 6 h ; caches `espn-hist-base`, `espn-history` | Should |
| F14 | Rivaux | Matchs des concurrents hors équipes suivies ; jusqu'à 12 récents (8 dans la tuile) et 10 prochaines affiches (4 dans la tuile) ; Jn si équipe active. | L.1126-1132, 1601-1613, 1793-1820, 1129-1130 | `extra` 30 min, `nextup` 6 h, `histfull` 6 h | Should |
| F15 | Top 5 | ENG/ESP/GER/ITA/FRA + ALL ; à venir, journée, résultats, classements. | L.1121-1122, 1133-1139, 1538-1545, 1652-1690, 1832-1870 | `extra`, `nextup`, `histfull`, `standings` | Should |
| F16 | Europe | C1/EUR/CONF ; listes, journée européenne, classement phase de ligue, hero. | L.1140-1145, 1161-1171, 1546-1553, 1614-1651, 1871-1909 | `extra`, `nextup`, `histfull`, `standings`, `knock` | Should |

### 1.2 Tableau F17-F32

| ID | Fonction | Description | Code | Données / dépendances | Criticité |
|---|---|---|---|---|---|
| F17 | Arbre du tournoi | Barrages, 8es, quarts, demies, finale ; message si phase de ligue en cours. | L.725-789, 753-756, 763-774, 1146-1149, 1910-1924, 1349-1352 | `knock` 6 h ; `season.slug` L.740 ; cache `espn-knock` | Should |
| F18 | Rappel 12 h | Notification unique 12 h avant le prochain match non notifié ; `nextDone` plafonné à 30. | L.1022-1026, 1037-1042, 1078-1091, 1043-1053 | `allMine`, `nextDone` persisté, `now` 1 s | Should |
| F19 | Rappel coup d'envoi | Notification au coup d'envoi si non terminé, fenêtre [-15 min, +∞[, une fois. | L.1024-1025, 1040-1041, 1054-1058, 1080-1098 | `allMine`, `games`, notifications | Should |
| F20 | Refresh manuel et statut | Bouton, spinner 245 s max, « actualisation… », ✓ durée ou ✗, âge de la dernière mise à jour. | L.1014-1019, 1032-1034, 1315, 1697-1701, 1733-1747 | `refresh()`, `games.ok`, 11 sources | Must |
| F21 | Langue FR/EN | Bascule persistée ; libellés, en-têtes, phases, légendes, dates, titres. | L.999-1007, 1782-1787, 1693, 1349-1352, 1262, 1232-1235, 1141, 1149 | `lang`, `fmtTime` | Must |
| F22 | Tailles S/M/L/XL | Police, largeurs, densité ; persistée. | L.1020, 1107, 1772-1778, 1216-1226, 1242-1251, 1357-1359 | `uiSize`, `wide` | Should |
| F23 | Édition équipes | Compteur n/5, liste, bouton « modifier mes équipes », ouverture du setup. | L.1779-1781, 1012, 1035 | `myTeams` | Should |
| F24 | Logos et sprite | Téléchargement 48×48, purge 30 j, planche 8 colonnes + JSON, découpe Canvas, fallback fichier puis placeholder. | L.84-99, 100-233, 229-232, 342-357, 509-524, 640-651, 775-786, 847-858, 969-980, 998, 1178-1179, 1183-1206, 1443-1452 | `a.espncdn.com` ; `perl`+zlib ; `sha256sum` ; `find` ; `base64` | Should |
| F25 | Badges, zones, live | Pastilles V/N/D, bandeau de forme, points de zone, pastille verte live. | L.1207-1215, 1322-1327, 1415-1442, 1355-1356, 1400 | `winner`, `zone`, `formsData` | Should |
| F26 | Persistance | Langue, équipe, équipes, sections, durée/date du dernier refresh, taille, rappels, vue, Top 5, Europe ; caches fichiers. | L.999, 1008-1009, 1013, 1017, 1019-1020, 1022-1029, 70, 303, 439, 500, 569, 631, 766, 838, 902, 984 | prefs + `~/.cache/espn-*` | Must |
| F27 | Vide/chargement/erreur | Messages équipes, matchs, résultats, saison terminée, classements, bracket, échec refresh. | L.1288-1291, 1588-1601, 1606-1612, 1619-1650, 1657-1688, 1797-1830, 1836-1870, 1875-1909, 1912-1924, 1925-1951, 1697-1701 | null, tableaux vides, `lastOk` | Must |
| F28 | Sections repliables | Vue ALL : section par équipe, compteur, repli persisté (10 max). | L.1013, 1927-1941 | `secClosed` | Could |
| F29 | Thème et adaptation | Couleurs thème, zones, cotes, statut ; noms complets et BP:BC en large. | L.1106, 1117-1118, 1208, 1215, 1483-1488, 1699, 1216-1226, 1242-1251, 1370, 1406 | tokens thème | Could |
| F30 | Dates et i18n secondaire | Dates localisées, « il y a », « dans », en-têtes, phases, légendes, titres. | L.1001-1007, 1091, 1098, 1112-1114, 1360, 1374, 1378, 1242-1251, 1232-1235, 1262, 1349-1352, 1149, 1693 | `lang`, `fmtTime`, `fmtDuration` | Should |
| F31 | Fermeture | Bouton « fermer » en bas d'écran. | L.1952 | `close()` | Should |
| F32 | Cache anti-trous | Fusion frais/cache par id, frais prioritaire, trous comblés, repli cache, échec sinon. | L.63-83, 319-341, 437-451, 500-508, 568-605, 759-774, 835-846, 901-934, 983-993 | `jq`, `mv` atomique, schémas | Must |

### 1.3 Index des lets, states et nodes clés

| Domaine | Lets / states / nodes | Lignes |
|---|---|---|
| Sélection | `favStr`, `favTid`, `favNoTid`, `myTeams`, `draft`, `query`, `showTeams`, `SetupBlock` | L.6-8, 1009-1012, 1268-1321 |
| Identité | `favAbbrs`, `selTeam`, `kind`, `base`, `allMine` | L.1059-1060, 1071, 1077, 1084-1098 |
| Navigation | `view`, `team`, `topLg`, `euroLg`, `modeTabs`, `topTabs`, `euroTabs`, `selJ` | L.1008, 1027-1030, 1120-1122, 1140 |
| Hero | `heroMatch`, `heroH`, `heroA`, `heroDown`, `oddsOn`, `MatchBanner`, `BannerOdd` | L.1081, 1108-1116, 1454-1527 |
| Matchs | `baseF`, `liveF`, `nextF`, `pastA`, `upShow`, `pastTake`, `GameRow`, `LiveGame` | L.1072-1076, 1105, 1329-1414 |
| À venir / live | `nextNew`, `liveM`, `liveList`, `liveAt`, `liveAge`, `liveWarn` | L.1099-1103, 1125 |
| Journées | `rounds`, `anchors`, `rd`, `est`, `curJ`, `jMatches`, `euroCurJ`, `topUpJ` | L.1065-1066, 1334-1352, 1158-1174 |
| Classements | `tables`, `myTablesAll`, `myTables`, `topTables`, `euroTables`, `TableBlock`, `TableRow`, `ZoneDot` | L.1069, 1119, 1137-1145, 1207-1267 |
| Historique | `histMap`, `histLg`, `maxJ`, `minJ`, `maxPlayed`, `jrPast` | L.1151-1159 |
| Rivaux / Top 5 / Europe | `rivalsAll`, `rivalsTile`, `topAll`, `topTile`, `euroMatches`, `euroList`, `topHero`, `euroHero` | L.1129-1171 |
| Bracket | `knockAll`, `knockLg`, `knockRounds`, `knockLabels` | L.1146-1149 |
| Rappels | `soon12`, `notDone`, `h12Id`, `h12At`, `kickId`, `kickAt`, `nextDone` | L.1022-1026, 1078-1080, 1043-1058 |
| Refresh | `spinning`, `spinUntil`, `elapsed`, `lastDur`, `lastOk`, `lastAt` | L.1014-1019, 1032-1034 |
| Réglages | `lang`, `uiSize`, `showSettings`, `showTables` | L.999, 1020-1021, 1031 |
| Logos / badges | `spr`, `sprOk`, `Crest`, `FormChip`, `FormStrip`, `BannerForm`, `BannerLogo` | L.998, 1178-1206, 1322-1452 |
| États globaux | `setupNeeded`, `wide`, `fz`, `soft`, `pop` | L.1061, 1106-1118 |

### 1.4 Fiches à risque particulier

- **F02/F03 — sélection et identité.** Le `teamsDb` a `key = abbr:kind` (L.494) et un dédoublonnage qui privilégie les clubs (L.499). Une réécriture qui n'émet plus `tid` bascule tout sur les abréviations : les homonymes club/sélection et les équipes sans abréviation changent de comportement. Conserver `tid`, `abbr`, `kind`, `league`, `logo`, `key`.
- **F06 — hero.** `heroH`/`heroA` font `myTeams.find(...).short` (L.1108-1109) ; le fallback `??` ne protège pas une propriété lue sur `null` si le moteur n'est pas null-safe. Vérifier le cas « équipe du hero non sélectionnée » (rival, autre club). Le bandeau complet `MatchBanner` n'est rendu qu'en Mes matchs (L.1584, 1790-1792) ; Top 5/Europe affichent un match vedette dans la tuile compacte via `LiveGame` (L.1622-1624, 1660-1662), Rivaux n'a pas de hero. Le chemin `banner/` L.1450 n'est jamais alimenté : le hero peut afficher des logos vides. `BannerForm` lit `formsData.out` L.1429 alors que la source renvoie un tableau brut L.528-531 ; le fallback L.1430-1431 masque l'écart.
- **F08 — live gating.** La requête live ne part que si un match des caches est `in` ou `pre` dans les 90 min (L.661-671). Si `at`, `state`, `tids` ou `squads` disparaissent, aucune requête live n'est émise : l'UI reste silencieusement figée. Le warning `liveWarn` > 900 s L.1103 est le seul signal.
- **F11 — journées.** Les K valent 9 pour FRA.1/FRA.2/GER.1, 18 pour C1, 10 sinon (L.613/954) ; l'Europe phase de ligue utilise des grappes à 4 jours (L.949) ; les rounds viennent de `scheds` L.362-383, de `extra` L.607-629 et de `histfull` L.937-982. Une réduction de mois casse d'abord les journées futures et l'estimation `est` L.1342.
- **F12 — classements.** Le filtre L.428 ne garde que les groupes avec une équipe suivie ou une ligue Top 5/Europe. Une liste de ligues dynamique doit mettre à jour ce filtre, sinon les nouveaux championnats sont téléchargés mais invisibles. `ends + 604800` L.1119/1138 masque les tableaux expirés.
- **F20 — statut.** `lastOk` n'est mis à jour que si `spinning` (L.1033) : un refresh automatique réussi ne change pas le statut. `lastAt` est mis à jour à chaque succès. Le spinner expire à `now + 245` L.1735, la source à 240 s L.237.
- **F24 — sprite.** La source `spr=file(...)` L.998 n'a pas de `every` : après reconstruction du sprite (L.229-232), l'index en mémoire peut rester périmé et afficher le mauvais écusson. `requires` ne déclare que `curl` et `jq` L.5 alors que le sprite dépend de `perl` et zlib (L.106-228), `base64` L.87, `sha256sum` L.104/305.

---

## 2. Socle data

### 2.1 Sources, intervalles, sorties

| Source | Lignes | Intervalle | Timeout | Sortie | Écrit / lit | Remarque |
|---|---|---:|---:|---|---|---|
| `games` | 9-237 | 15 min | 240 s | tableau de matchs | écrit `espn-games.json` ; lu par `liveM` | 28 ligues × 5 mois = 140 req/passage ; concurrency 5 + `sleep 1` L.50-55 |
| `seasonAll` | 238-361 | 12 h | 300 s | tableau de matchs | écrit `espn-season.json` | saison août-juillet L.291-300 ; `lms` ; concurrency 10 L.281-290 |
| `scheds` | 362-383 | 12 h | 60 s | `{rounds, anchors}` | aucun cache | 7 appels calendrier L.371-377 |
| `standings` | 384-453 | 6 h | 90 s | tableau de classements | écrit `espn-standings.json` | 26 ligues L.388 ; fusion ligue+groupe L.437-451 |
| `teamsDb` | 454-527 | 24 h | 150 s | tableau d'équipes | écrit `espn-teams.json` | 27 ligues L.456 ; `kind` c/n L.493 ; priorité L.499 |
| `formsData` | 528-531 | 15 min | 60 s | tableau de résultats | lit `/root/.cache/espn-extra.json` | 0 réseau ; consommé via `.out` L.1429 |
| `extra` | 532-654 | 30 min | 150 s | tableau de matchs | écrit `espn-extra-base.json` + `espn-extra.json` | 11 ligues L.535 ; rounds L.607-629 ; 5/2 mois L.565-567 |
| `liveM` | 655-724 | 1 min | 90 s | `{at, items}` | lit 4 caches L.671 | gating L.661-671 ; concurrency 3 + `sleep 0.5` L.711-716 |
| `knock` | 725-789 | 6 h | 120 s | tableau de matchs | écrit `espn-knock.json` | 3 ligues L.727 ; février-mai L.753-756 ; purge au 1er septembre L.765 |
| `nextup` | 790-861 | 6 h | 150 s | tableau de matchs | écrit `espn-nextup.json` | 11 ligues L.792 ; 8/18 par ligue L.834 ; purge -1 j L.840 |
| `histfull` | 862-995 | 6 h | 150 s | objet `{league: [matchs]}` | écrit `espn-hist-base.json`, `espn-history.json` | 9 ligues L.864 ; saison L.894-900 ; rounds L.937-982 |
| `now` | 996 | 1 s | — | epoch | état UI | horloge des rappels/compte à rebours |
| `slow` | 997 | 15 min | — | epoch | état UI | âge/refresh, expiration classements |
| `spr` | 998 | fichier | — | `{cell, cols, w, h, idx}` | `sprite.json` | pas de `every` : rechargement non garanti |

### 2.2 Caches

| Fichier | Écrit par | Lu par | Rétention / logique |
|---|---|---|---|
| `~/.cache/espn-games.json` | `games` L.83, 234 | `liveM` L.671 | fusion anti-trous ; purge `at <= now-604800`, live périmé, pre commencé L.75 |
| `~/.cache/espn-season.json` | `seasonAll` L.333-334 | `liveM` L.671 | `lms` ; mois courants/futurs ; `month >= S07` L.323-330 ; nor/swe dès janvier L.329 |
| `~/.cache/espn-extra-base.json` | `extra` L.595 | `extra` L.585-592 ; `liveM` L.671 | `lms` ; conservation 120 jours L.571-592 |
| `~/.cache/espn-extra.json` | `extra` L.631 | `formsData` L.529 ; `extra` L.597 | sortie UI rivaux/Top 5/Europe ; 30 matchs/ligue L.605 |
| `~/.cache/espn-nextup.json` | `nextup` L.842 | `liveM` L.671 | purge `at <= now-86400` L.840 |
| `~/.cache/espn-knock.json` | `knock` L.770 | `knock` L.768 | garde la saison depuis le 1er septembre L.765-768 |
| `~/.cache/espn-standings.json` | `standings` L.443 | `standings` L.441 | fusion par `league:group` ; pas d'expiration fichier |
| `~/.cache/espn-teams.json` | `teamsDb` L.502 | `teamsDb` L.503 | remplacement si non vide, sinon dernier cache |
| `~/.cache/espn-hist-base.json` | `histfull` L.925 | `histfull` L.915-922 | `lms` ; saison depuis août L.915 |
| `~/.cache/espn-history.json` | `histfull` L.984 | `histfull` L.927/985 | objet groupé par ligue ; sert aussi de repli |
| `~/.cache/espn-logos/soccer/*.png` | 6 scripts | `Crest` L.1201 | purge `-mtime +30` L.88/346 ; noms numériques supprimés L.89/347 |
| `~/.cache/espn-logos/sprite.png` + `.json` | `games` L.229-232 | `Crest` L.1178-1198 | reconstruction si signature change L.104-105 ; écriture atomique |
| `~/.cache/espn-logos/empty.png` | L.86-87 | fallback | PNG 1×1 |

### 2.3 Contrats de données

- **Match** : `{id, league, tag, at, state, detail, squads, tids?, odds?, teams?, home?, away?, stage?, round?, month?, fetchedAt?}`. `id = league:eventId` (L.48). `at` = epoch UTC calculé par `.date[0:16] + ":00Z" | fromdateiso8601` (L.48). `state` ∈ `pre|in|post`. `home`/`away` peuvent manquer dans `liveM`/`knock`/`nextup` (L.709, 740, 815) : `GameRow` fait `g.home??{}` L.1330-1331.
- **Classement** : `{league, tag, group, ends, teams:[{abbr,name,rank,played,won,drawn,lost,bp,bc,gd,pts,ours,zone,zlabel}], squads, legend:[{c,t}]}` (L.428). `ends` = epoch de fin de saison ou 9999999999 L.426-427.
- **Équipe** : `{key, name, short, abbr, display, logo, league, tag, kind, tid}` (L.494). `key` = `abbr:kind`.
- **Calendrier** : `{rounds:{id: "J1"|...|"Finales"}, anchors:{league:{jn, at}}}` (L.368-369, 381).
- **Live** : `{at, items:[match...]}` (L.721).
- **Historique** : `{league:[match...]}` avec `round` ajouté L.982.
- **Sprite** : `{cell, cols:8, w, h, idx:{fichier: index}}` (L.220-225).

### 2.4 Volumétrie estimée du code actuel

Hypothèse : 24 h, aucun échec, hors logos et retries. `games` est le poste dominant car il ne utilise pas `lms` et refait 5 mois à chaque passage.

| Source | Requêtes / passage | Passages / 24 h | Requêtes / 24 h |
|---|---:|---:|---:|
| `games` | 140 (28 ligues × 5 mois) | 96 | **13 440** |
| `seasonAll` | 364 froid ; 280 chaud en octobre | 2 | 728 / 560 |
| `scheds` | 7 | 2 | 14 |
| `standings` | 26 | 4 | 104 |
| `teamsDb` | 27 | 1 | 27 |
| `extra` | 40 froid ; 11 chaud | 48 | 1 920 froid ; 528 chaud |
| `liveM` | 1 à N ligues/jour | 1 440 | 0 à 300/h selon gating |
| `knock` | 12 | 4 | 48 |
| `nextup` | 44 | 4 | 176 |
| `histfull` | 117 froid ; 90 chaud en octobre | 4 | 468 / 360 |
| **Total chaud, hors live/logos** | | | **≈ 15 250/j, ≈ 636/h** |

Lecture : la cible d'une réécriture ne peut pas être atteinte en gardant `games` à 5 mois × 28 ligues toutes les 15 min. La préservation fonctionnelle impose de **mettre les mois en cache** et de **ne requêter que les ligues/dates utiles** (voir R02/R03/R05).

---

## 3. Risques de réécriture data et règles de préservation

| ID | Risque | Fonctions impactées | Lignes | Symptôme si mal fait | Préservation obligatoire |
|---|---|---|---|---|---|
| R01 | **Listes de ligues dynamiques** | F02, F03, F05, F08, F11-F17 | Listes dupliquées : L.14-15, 243-244, 388, 456, 535, 565, 727, 792, 864 ; tags L.16-43, 245-272, 389-420, 457-488, 536-552, 673-704, 728-734, 793-809, 865-881 ; UI L.1121-1122, 1126, 1140, 1148 | Une ligue ajoutée est téléchargée mais n'apparaît pas (rival/top/classement), ou son tag devient l'ID brut et déborde la colonne de 22 px L.1367. Une ligue retirée casse le fallback `tagof` L.41. | Source unique de catalogue ; conserver `tag` court, `kind` c/n, l'appartenance à `RR` (6 ligues), `CAL` (nor/swe), `topLeagues` (5), `rivLgs` (11), `euroTabs` (3) et le filtre standings L.428. Tests FT-11, FT-12, FT-22, FT-25, FT-27, FT-28. |
| R02 | **Réduction des mois** | F09-F17, F32 | `games` L.56 ; `season` L.291-300 ; `extra` L.566-567 ; `nextup` L.826 ; `knock` L.753-756 ; `histfull` L.894-900 | Trous dans les résultats récents, les journées futures, les affiches à venir, l'historique ou l'arbre. Le cache anti-trous masque partiellement, puis les données anciennes disparaissent à la purge. | Conserver les fenêtres : `games` -4 j/+90 j, saison complète, `extra` -120 j, `nextup` 0/+90 j, `knock` février-mai, `hist` saison. Si une fenêtre change, recalculer les `lms`, les purges L.75/329/591/840/921 et vérifier les mois charnières. |
| R03 | **Changement d'intervalle** | F08, F09, F18-F20, F27 | L.237, 361, 383, 453, 527, 531, 654, 724, 789, 861, 995, 997 | Live et rappels en retard, `liveWarn` L.1103, statut L.1698, compte à rebours L.1116. Un intervalle plus long que 15 min rend le statut « actualiser » trompeur. | Conserver au minimum `liveM` 1 min, `now` 1 s, `slow` 15 min ; `games` ≤ 15 min pour le hero/compte à rebours ; `nextup`/`hist`/`knock`/`standings` 6 h ; `season` 12 h ; `teams` 24 h. Toute baisse doit garder le refresh manuel et les rappels. |
| R04 | **Live gating** | F08, F09, F18, F19 | L.661-671, 666, 709, 721 | Plus aucune requête live, ou live permanent (coût), si les champs ou la fenêtre changent. | Conserver les 4 caches d'entrée L.671, les filtres `league`, `at`, `state`, `tids`/`squads` L.661-667, la fenêtre 5 400 s L.666, la sortie `{at,items}` L.721 et l'overlay par id L.1412. Tester avec un cache volontairement incomplet. |
| R05 | **Contrat de champs** | Toutes | L.48, 279, 428, 557, 709, 740, 815, 886 | Un champ renommé (`home`/`away`, `winner`, `odds`, `round`, `stage`, `ends`, `zone`) produit des `null` silencieux, pas une erreur. | Geler le schéma §2.3 ; valider par `jq` avant écriture ; conserver les null-tolerances de `GameRow` L.1330-1331, `MatchBanner` L.1470-1479, `TableRow` L.1216. |
| R06 | **Identité équipe** | F02, F03, F06-F19 | L.6-8, 44-48, 494-499, 1071, 1077, 1084-1098, 1128 | Mélange club/sélection, doublons, équipes sans `tid` perdues, mauvais matchs. | Conserver `tid` prioritaire, fallback abréviation, `kind` c/n, `key=abbr:kind`, priorité clubs L.499, cas `LYON` L.48. Tester un club et une sélection de même abréviation. |
| R07 | **Calcul des journées** | F11, F13, F15, F16 | L.613-629, 949-982, 954-958, 1334-1352 | Décalage d'une journée, doublons, `Finales` au mauvais tour, journées européennes fusionnées. | Conserver K=9/18/10 L.613/954, le mode `gamesPlayed` L.614/955, les grappes 345 600 s L.949, `stage` L.1349-1352 et l'ordre `knockRounds` L.1148. Tests FT-20, FT-21, FT-29. |
| R08 | **Cotes** | F06, F07 | L.48, 279, 1475-1515 | Cote américaine affichée brute, cotes partielles, cotes sur match live/post. `dec` suppose des cotes américaines : si ESPN renvoie déjà du décimal, `1.85` deviendrait `1.0185`. | Conserver `dec` **après avoir vérifié le format réel** ; conserver les trois replis close/open/moneyLine, l'objet `{h,d,a}`, la condition `pre` + trois valeurs L.1479, l'arrondi `fixed(v,2)` L.1465. Ajouter un test de contrat sur une cote connue. |
| R09 | **Cache anti-trous** | F09-F17, F27, F32 | L.63-83, 319-341, 437-451, 500-508, 568-605, 759-774, 835-846, 901-934 | Perte de mois entiers sur timeout, doublons, cache qui écrase le frais, fichier partiel. | Conserver « frais gagnant par id », fusion par `league:month`/`league:group`, écriture `mv` atomique, repli cache, et les purges. Tests NFT-09/10/14. |
| R10 | **Fuseaux et DST** | F09, F11, F18, F19, F30 | `date -d` L.56, 299, 566-567, 571, 753-754, 826, 837, 896, 904 ; `fromdateiso8601` L.48 ; `gmtime` L.668 ; `fmtTime` L.1360/1374/1378 | Match affiché à la mauvaise heure, rappel 12 h décalé d'une heure, jour de match faux au changement d'heure. | Stocker `at` en epoch UTC ; ne jamais recalculer l'heure locale dans les scripts ; conserver la fenêtre 12 h en secondes L.1039 ; tester printemps/automne et un match à 23:30 local. |
| R11 | **Changement de saison** | F11-F17, F32 | L.291-300, 749-752, 894-900, 765, 305-309, 323-330 | Ancienne saison mélangée à la nouvelle, arbre vide, cache `sig` obsolète. | Conserver la bascule août/juillet, `sig` équipes L.305-309, purge `month >= S07` L.329, `keep = S-09-01` L.765 et `hist` depuis août L.915. Test NFT-14. |
| R12 | **Rappels** | F18, F19 | L.1022-1026, 1037-1058, 1078-1091 | Notification en double, manquée, ou envoyée pour un match terminé. | Conserver `nextDone` persisté et plafonné à 30 L.1050, `h12At=max(at-12h,now)` L.1039, la condition `state=="pre" && at>now` L.1046, la fenêtre kickoff L.1056. |
| R13 | **Sprite et logos** | F06, F24, F25 | L.100-233, 998, 1178-1206, 1443-1452 | Mauvais écusson après ajout d'une équipe, sprite partiel, hero sans logo. | Conserver le nommage `soccer-500-id.png`, la cellule 48×48, 8 colonnes, la signature L.104-105, l'écriture atomique L.229-232, le fallback L.1189-1203. Recharger `spr` après reconstruction. Le dossier `banner/` L.1450 doit être alimenté ou le fallback doit rester visible. |
| R14 | **Dépendances shell** | F24, toutes les sources | L.5, 106-228, 529 | Sprite non construit si `perl`/zlib absent ; `formsData` vide si `/usr/bin/jq` absent ; scripts en échec. | Déclarer `perl`, zlib, `coreutils`, `findutils`, `jq` ; ou remplacer le sprite par une méthode sans Perl **sans** perdre le rendu groupé. Vérifier `requires` L.5. |
| R15 | **Sécurité `sh()`** | F02, F03, toutes | L.10-12, 239-241, 658-660 | Abréviation contenant `'` ou injection via catalogue dynamique. | Garder l'échappement `sh()` et ne jamais concaténer une valeur non contrôlée dans le script ; valider `abbr`/`tid` avant persistance. Test NFT-22. |
| R16 | **Formes externes** | F06, F10, F25 | L.528-531, 529, 1429-1431 | `formsData` ignoré (`.out` sur un tableau), donc bandeau hero moins riche ; chemin `/root` pouvant différer de `~`. | Décider produit : soit exposer `{out:[...]}`, soit lire le tableau directement ; dans les deux cas conserver le fallback `all` L.1430-1431 et le rendu 5 matchs. Ne pas supprimer le fallback. |
| R17 | **Rate limit / offline** | Toutes | retries L.48, 277, 367, 425, 494, 557, 709, 740, 814, 886 ; pas de backoff global | Rafale de 28 ligues, 429, échecs partiels, batterie. | Conserver les limites de concurrence (5/10), les `sleep`, les retries bornés 0-2 et le repli cache. Ajouter un backoff/jitter seulement si les fonctionnalités et délais restent identiques. |
| R18 | **Wrappers de sortie** | Toutes | `games` L.234, `season` L.358, `extra` L.652, `nextup` L.859, `hist` L.993, `knock` L.787, `standings` L.450, `teams` L.525, `scheds` L.381, `live` L.721 | `.out` absent, tableau attendu reçu objet (ou inverse), UI vide. | Conserver les formes §2.3 ; un test de schéma par source doit passer avant l'UI. |

**Règles transverses de préservation**
1. Toute liste de ligues doit être dérivée d'une seule source, mais conserver les sous-ensembles métier : `RR` (rounds), `CAL` (calendriers nor/swe), `topLeagues`, `rivLgs`, `euroTabs`, `TABLES`, `LEAGUES`.
2. Toute optimisation de requêtes doit d'abord démontrer qu'elle préserve les fenêtres de dates, les rounds, les cotes, le live et les rappels.
3. Toute modification de schéma doit être testée avec les anciens caches : le widget doit démarrer sans cache, avec un cache partiel et avec un cache d'une saison précédente.
4. Aucun test de non-régression ne peut être « vert » si une fonctionnalité F01-F32 est absente ou silencieusement vide.

---

## 4. Matrice de recette

### 4.1 Cas fonctionnels (38)

| ID | Cas | Préconditions / procédure | Résultat attendu | Réf. |
|---|---|---|---|---|
| FT-01 | Première ouverture sans équipe | Installer, vider `myTeams`, ouvrir. | `SetupBlock` visible, compteur 0/5, bouton « Choisis au moins 1 équipe ». `games` et `seasonAll` sortent avec `[]` (L.13, 242) ; les sources catalogue/classements peuvent encore charger, sans erreur UI. | L.13, 242, 1061, 1274-1318 |
| FT-02 | Recherche club | Saisir `lyon`, puis `LYON`, puis `Olympique`. | Liste filtrée sur `name`/`short`/`abbr`, ≤ 12 résultats, ajout possible, pas de crash. | L.1269-1271, 1276 |
| FT-03 | Recherche sélection | Saisir `France`, sélectionner. | L'équipe est de type `n` ; seuls les matchs nations/worldq/friendly remontent dans Mes matchs. | L.493, 1071, 1128 |
| FT-04 | Plafond 5 | Ajouter 5 équipes, tenter la 6e. | Le 6e `+` est grisé/muet, le compteur reste 5/5, message « Maximum 5 — retire une équipe pour en changer ». | L.1285-1286, 1295, 1305 |
| FT-05 | Retrait brouillon | Ajouter 3, retirer la 2e, re-ajouter. | Compteur et puces cohérents, validation possible entre 1 et 5. | L.1277-1284, 1314 |
| FT-06 | Annulation édition | Avec 2 équipes existantes, ouvrir l'édition, modifier, annuler. | Les 2 équipes d'origine sont conservées, le setup se ferme, aucun refresh. | L.1035, 1311-1313 |
| FT-07 | Validation 1 équipe | Choisir 1 club, valider. | Dashboard, puce équipe, matchs/hero, `refresh()` déclenché, sélection conservée après redémarrage. | L.1315, 1009, 1712-1732 |
| FT-08 | Validation 5 équipes | Choisir 5 équipes, valider. | 5 puces, formes, filtre équipe, maximum respecté, persistance. | L.1315, 1554-1576 |
| FT-09 | Filtre équipe | Taper une puce, puis re-taper. | Bascule `team`/`ALL`, seuls les matchs de l'équipe s'affichent, `selJ=-1`. | L.1567, 1724, 1036 |
| FT-10 | Onglets principaux | Taper MINE, RIV, TOP5, EUROPE, recharger. | Vue correcte à chaque fois, dernière vue persistée, `selJ` remis à -1. | L.1120, 1534, 1705, 1027 |
| FT-11 | Filtres Top 5 | Taper ENG, ESP, GER, ITA, FRA, puis la ligue active. | Filtrage correct, bascule vers ALL au second tap, libellé `topLabel` cohérent. | L.1121-1122, 1543, 1177 |
| FT-12 | Filtres Europe | Taper C1, EUR, CONF, recharger. | Onglet et libellé corrects, `euroLg` persisté, défaut `uefa.europa`. | L.1029, 1140-1141, 1551 |
| FT-13 | Hero prochain match | Avoir un match futur avec classement. | Deux équipes, logos, rang si disponible, heure locale, date, compte à rebours, tag. Aucun hero si aucun match. | L.1081, 1108-1116, 1469-1527, 1584 |
| FT-14 | Hero live | Un match est `in`. | Affichage « en direct maintenant », minute/détail, score, lien avec liveM. | L.1112-1116, 1411-1414 |
| FT-15 | Cotes complètes | Match `pre` avec 3 cotes. | Ligne 1/N/2, décimales à 2 chiffres, couleurs favorite/outsider, aucune cote sur live/post. | L.1475-1515 |
| FT-16 | Cotes incomplètes | Match `pre` sans draw ou sans odds. | Aucune ligne de cotes, pas de `null` affiché, reste du hero intact. | L.1479, 1502 |
| FT-17 | Live et fraîcheur | Match live, liveM plus récent que games. | Score live prioritaire, pastille verte, `liveSuffix` avec âge, warning si > 15 min. | L.1099-1103, 1396-1404 |
| FT-18 | À venir | Plusieurs matchs futurs, dont doublons nextup/extra. | Tri ascendant, dédoublonnage `nextNew`, compte à rebours, pas de doublon. | L.1074-1076, 1125, 1594-1598 |

### 4.2 Cas fonctionnels (suite)

| ID | Cas | Préconditions / procédure | Résultat attendu | Réf. |
|---|---|---|---|---|
| FT-19 | Résultats récents | Plus de 5 matchs `post`. | Exactement 5, ordre chronologique, scores, vainqueur en gras, pastille V/N/D pour l'équipe suivie. | L.1105, 1355-1356, 1387-1389 |
| FT-20 | Journée courante | Sélectionner un club, onglet Rivaux/Top 5. | Libellé `Jn`, flèches bornées, centre remet la journée courante, matchs de la journée. | L.1158-1159, 1805-1811 |
| FT-21 | Journée future | Naviguer vers Jn+1/Jn+2. | Matchs `pre` affichés, message « saison terminée » si dépassement, flèche droite grisée en butée. | L.1160, 1634-1635, 1672-1673 |
| FT-22 | Classement complet | Équipe dans un championnat, mode large. | Colonnes J/V/N/D/BP:BC/+/-/Pts, équipe en gras, zones colorées, légende traduite, BP:BC visible. | L.1210-1267, 1822-1831 |
| FT-23 | Classement mode étroit | Même test en tuile étroite. | Noms abrégés, BP:BC masqué, colonnes non chevauchées, zones visibles. | L.1106, 1216-1226, 1242-1251 |
| FT-24 | Classement expiré | Saison `ends + 7 j < now`. | Tableau masqué, « aucun classement », pas de crash. | L.1119, 1138, 1824-1825 |
| FT-25 | Rivaux | 2 clubs suivis, onglet Rivaux. | Matchs des concurrents uniquement, équipes suivies exclues, 4 prochains + 8 récents dans la tuile (jusqu'à 12 récents et 10 prochains en données), libellé `· concurrents`. | L.1129-1132, 1601-1613 |
| FT-26 | Rivaux par équipe | Sélectionner une équipe puis Rivaux. | Navigation Jn visible pour cette équipe, matchs de la journée, pas de matchs de l'équipe suivie. | L.1150, 1805-1820 |
| FT-27 | Top 5 ALL | Onglet Top 5, aucun championnat actif. | Liste des 5 championnats, libellé `ENG · ESP · GER · ITA · FRA`, `tapAll`, classements combinés. | L.1177, 1656, 1832-1870 |
| FT-28 | Europe phase de ligue | Onglet Europe, C1, phase de ligue. | Matchs à venir/résultats, `euroCurJ`, message bracket « phase de ligue en cours ». | L.1161-1170, 1914-1915 |
| FT-29 | Bracket | Après la phase de ligue, cache knock rempli. | Sections barrages/8es/quarts/demies/finale dans l'ordre, compte par tour, matchs corrects. | L.1146-1149, 1917-1924 |
| FT-30 | Rappel 12 h | Match futur > 12 h, `nextDone` vide. | Une notification 12 h avant, une seule fois, `nextDone` contient l'id, pas de doublon après rechargement. | L.1037-1053 |
| FT-31 | Rappel coup d'envoi | Match à l'heure H, non `post`. | Notification à H, une fois, fenêtre -15 min, pas de notification si `post`. | L.1054-1058 |
| FT-32 | Refresh manuel réussi | Taper ↻. | Spinner, « actualisation… Ns », puis ✓ durée, données mises à jour, spinner disparaît. | L.1733-1747, 1697-1701 |
| FT-33 | Refresh en échec | Couper le réseau puis ↻. | Spinner jusqu'à 245 s max, ✗, données en cache conservées, aucun crash. | L.1017-1019, 1034, 1698 |
| FT-34 | Langue FR/EN | Taper Français puis English. | Tous les libellés, en-têtes, phases, légendes, titres et dates changent, choix persisté. | L.999-1007, 1782-1787 |
| FT-35 | Tailles S/M/L/XL | Tester les 4 tailles en 3×3 et 6×4. | Police et colonnes adaptées, aucune collision, choix persisté. | L.1020, 1107, 1772-1778 |
| FT-36 | Logos et sprite | Vider `espn-logos`, ajouter une équipe, attendre le refresh. | Logos téléchargés, sprite reconstruit, écussons corrects, fallback placeholder si logo absent. | L.84-233, 1183-1206 |
| FT-37 | Sections repliables | Vue ALL, replier une équipe, recharger. | Section repliée avec compteur, état persisté, 10 sections max. | L.1013, 1927-1941 |
| FT-38 | Fermeture | Taper « fermer ». | Le widget/screen se ferme proprement, pas de processus invité résiduel. | L.1952 |

### 4.3 Cas non-fonctionnels (24)

| ID | Dimension | Cas / méthode | Résultat attendu | Réf. |
|---|---|---|---|---|
| NFT-01 | CPU écran allumé | 10 s de deltas `/proc/<pid>/stat`, sans widget animé. | UID launcher < 5 % d'un cœur ; part my-match < 2 % ; aucun pic > 15 %. | audit L.182-185, 407 |
| NFT-02 | CPU écran éteint | 60 s écran éteint, deltas. | UID < 2 % ; aucun `bash`/`curl`/`jq`/`perl` de données actif ; 0 orphelin. | audit L.185, 259-264 |
| NFT-03 | fps / jank | `gfxinfo reset`, 30 s au repos, dump. | 0 frame en 10 s au repos ; ≤ 60 fps en interaction ; jank < 1 %. | audit L.183-186, 406 |
| NFT-04 | Requêtes stables | Compter les appels sur 1 h, sans live. | ≤ 150 req/h (objectif 60) ; aucun mois déjà en cache refetché ; pas de doublon `games`/`season`. | §2.4, L.56, 237 |
| NFT-05 | Requêtes live | 1 h avec un match live, puis 1 h sans. | ≤ 60 req/h avec live ; 0 sans match dans la fenêtre ; jamais plus de 1/min. | L.661-671, 724 |
| NFT-06 | Coût froid 24 h | Installation neuve, 24 h. | ≤ 2 000 requêtes ; ≤ 100 Mo réseau ; aucun téléchargement de logo répété. | §2.4 |
| NFT-07 | Orphelins | Après refresh, 5 min puis 30 min. | 0 processus de données PPID 1 ; aucun processus > 300 s ; répertoires `mktemp` nettoyés. | audit L.212-236, 405 |
| NFT-08 | Concurrence | Pendant un refresh complet, `ps`. | ≤ 10 curl simultanés ; respect des `wait`/`sleep` L.50-55, 281-290, 711-716. | L.50-55, 281-290 |
| NFT-09 | Offline | Mode avion, cache présent puis absent. | Cache affiché, statut ✗, aucun crash, aucune boucle infinie ; sans cache, états vides. | L.63-83, 1698 |
| NFT-10 | 429 / 5xx | Simuler 429/500 sur une ligue. | Retries bornés (0-2), pas de rafale, fusion partielle, cache conservé. | L.48, 277, 367, 814 |
| NFT-11 | Fuseau horaire | Match 20:45 UTC, appareil Europe/Paris. | Affichage 22:45 en été, 21:45 en hiver ; jour correct ; `at` inchangé. | L.48, 1360 |
| NFT-12 | DST | Nuit de changement d'heure, rappel 12 h et coup d'envoi. | Rappels à ±2 min de l'heure réelle, pas de doublon/manqué, compte à rebours cohérent. | L.1039, 1056, 1116 |
| NFT-13 | Changement de mois | Exécution à 23:59 le dernier jour. | Les fenêtres `-4/+90` et `%Y%m` incluent le bon mois ; aucun mois manquant. | L.56, 566-567, 826 |
| NFT-14 | Changement de saison | Basculer au 1er août, cache ancien. | Ancienne saison purgée/masquée, nouvelle saison vide sans crash, `sig` recalculé. | L.291-300, 305-309, 765 |
| NFT-15 | Taille cache | `du -sh` après 24 h. | JSON ≤ 20 Mo, logos ≤ 1 500 fichiers/20 Mo, sprite ≤ 2 Mo, aucun fichier > 30 j. | L.88, 104-105 |
| NFT-16 | Cohérence sprite | Ajouter/retirer une équipe, forcer un refresh. | Index et planche cohérents, aucun écusson décalé ; fallback si absent ; rechargement après rebuild. | L.100-233, 998 |
| NFT-17 | Gros JSON | Injecter 10 000 événements. | UI réactive, listes plafonnées (12/30/18), pas d'OOM, pas de freeze > 2 s. | L.605, 834, 1130, 1134 |
| NFT-18 | Champs manquants | Supprimer `home`, `away`, `odds`, `stats`, `logo`, `stage`. | Placeholders, pas de crash, listes partielles correctes. | L.1330-1331, 1470-1479 |
| NFT-19 | Refresh concurrent | Taper ↻ deux fois vite. | Un seul cycle utile, pas de doublon de sources, spinner cohérent, timeout 245 s. | L.1735, 1033-1034 |
| NFT-20 | Mémoire | 100 refresh ou 24 h, `dumpsys meminfo`. | Delta PSS < 50 Mo, pas de croissance monotone. | audit L.188 |
| NFT-21 | Batterie | 30-60 min écran éteint, mode avion, débranché. | ≤ 2 %/h ; aucun agent/script actif ; comparer avant/après. | audit L.410 |
| NFT-22 | Sécurité | Abréviation avec `'`/`;`, URL, JSON malformé. | Aucune exécution injectée, erreur contrôlée, cache non corrompu. | L.10-12 |
| NFT-23 | i18n extrême | FR en S et XL, libellés longs. | Aucun débordement critique, troncature propre, pas de chevauchement. | L.1000, 1107 |
| NFT-24 | Parité de données | Même journée, ancien vs nouveau widget. | Mêmes matchs, mêmes scores, mêmes journées, mêmes classements, mêmes cotes ; écarts justifiés par une correction documentée. | Toutes |

---

## 5. Checklist de non-régression après import du widget optimisé

### 5.1 Données et sources

- [ ] Les 14 sources sont présentes avec les mêmes noms : `games`, `seasonAll`, `scheds`, `standings`, `teamsDb`, `formsData`, `extra`, `liveM`, `knock`, `nextup`, `histfull`, `now`, `slow`, `spr` (L.237-998).
- [ ] Les 11 sources `cmd` ont un timeout et un intervalle documentés ; aucun timeout supprimé ou allongé sans mesure.
- [ ] `games` couvre toujours -4 j/+90 j et les 28 ligues, ou une stratégie équivalente prouvée par test de parité.
- [ ] `seasonAll` couvre août-juillet, y compris les mois futurs, et conserve `lms`.
- [ ] `extra` couvre les 11 ligues, avec 5 mois pour `RR` et 2 mois sinon.
- [ ] `nextup` couvre 0/+90 j, 8 matchs par ligue et 18 pour l'Europe.
- [ ] `knock` couvre février-mai des 3 coupes et conserve la purge au 1er septembre.
- [ ] `histfull` couvre les 9 ligues et les 13 mois de la saison.
- [ ] `standings` couvre les 26 compétitions et le filtre L.428.
- [ ] `teamsDb` couvre les 27 ligues et produit `tid`, `abbr`, `kind`, `league`, `logo`, `key`.
- [ ] `scheds` produit `rounds` et `anchors` pour les 7 appels.
- [ ] `liveM` ne requête que les ligues/dates avec match `in` ou `pre` à ±90 min.
- [ ] Tous les wrappers de sortie sont identiques : tableaux pour matchs/classements/équipes, `{rounds,anchors}`, `{at,items}`, `{league:[...]}`, `{cell,cols,w,h,idx}`.
- [ ] Les caches sont écrits de façon atomique (`mv`) et les replis cache fonctionnent.
- [ ] Aucun cache n'est supprimé ou renommé sans migration.
- [ ] Les purges 7 j / 120 j / 1 j / 30 j / saison sont conservées ou justifiées.

### 5.2 Sélection et identité

- [ ] 1 à 5 équipes, clubs et sélections, avec plafond et messages (L.1268-1321).
- [ ] Recherche par nom, nom court et abréviation (L.1271).
- [ ] `tid` prioritaire, fallback abréviation, `kind` c/n (L.6-8, 1071).
- [ ] Aucun doublon club/sélection ; `key=abbr:kind` conservé (L.494).
- [ ] Équipe sans `tid` toujours suivie via `favNoTid`.
- [ ] Cas `LYON` toujours mappé sur « Olympique Lyonnais » (L.48).
- [ ] Équipe active réinitialisée à `ALL` si elle disparaît (L.1036).
- [ ] Persistance de `myTeams`, `team`, `draft` non persisté comme avant (L.1009-1010).

### 5.3 Écrans et composants

- [ ] 4 onglets principaux et 3 filtres secondaires opérationnels (L.1120-1140).
- [ ] Hero : prochain match, live, logos, rang, heure, compte à rebours, cotes, formes.
- [ ] Live : score, minute, pastille, âge et warning > 15 min.
- [ ] À venir et résultats : tri, plafond 5, V/N/D, dédoublonnage.
- [ ] Journées : Jn, flèches, bornes, `Finales`, phases, estimation.
- [ ] Classements : groupes, zones, légende, BP:BC large, équipe suivie en gras.
- [ ] Historique : 9 ligues, rounds, avenir.
- [ ] Rivaux : exclusion des équipes suivies, 4 prochains + 8 récents dans la tuile, Jn par équipe.
- [ ] Top 5 : 5 ligues + ALL, listes et classements.
- [ ] Europe : 3 coupes, phase de ligue, bracket.
- [ ] Arbre : 5 tours dans l'ordre, comptes, message phase de ligue.
- [ ] Rappels 12 h et coup d'envoi : une seule notification, `nextDone` plafonné.
- [ ] Refresh : spinner, ✓/✗, durée, âge, timeout 245 s.
- [ ] Réglages : langue, taille, équipes.
- [ ] Fermeture.
- [ ] Sections repliables et persistance.
- [ ] Mode large/étroit, S/M/L/XL, FR/EN sans débordement.

### 5.4 États et résilience

- [ ] Chargement, vide, aucun résultat, saison terminée, aucun classement, bracket vide, échec.
- [ ] Offline avec cache : données affichées + statut d'échec.
- [ ] Offline sans cache : états vides, aucun crash.
- [ ] 429/5xx : retries bornés, pas de boucle, cache conservé.
- [ ] JSON partiel : fusion, pas de perte de mois/ligue.
- [ ] Cache d'une saison précédente : démarrage sans mélange.
- [ ] Changement de mois, de saison, de fuseau, DST.

### 5.5 Performance et propreté

- [ ] CPU écran allumé < 5 % UID ; my-match < 2 %.
- [ ] CPU écran éteint < 2 % UID ; 0 source active.
- [ ] 0 frame au repos sur 10 s ; ≤ 60 fps ; jank < 1 %.
- [ ] 0 orphelin PPID 1 ; 0 processus > 300 s ; 0 `mktemp` résiduel.
- [ ] ≤ 10 curl simultanés.
- [ ] Requêtes stables ≤ 150/h (objectif 60), live ≤ 60/h.
- [ ] Coût froid ≤ 2 000 req/24 h et ≤ 100 Mo.
- [ ] Caches ≤ 20 Mo, logos ≤ 1 500/20 Mo, sprite ≤ 2 Mo.
- [ ] Aucun logo > 30 j, aucun fichier partiel.
- [ ] PSS stable (< 50 Mo de delta sur 100 refresh).

### 5.6 Sécurité et intégrité

- [ ] Aucun secret/token dans le widget ou les caches.
- [ ] `sh()` conserve l'échappement ; test avec `'`, `;`, `$()`.
- [ ] Les données ESPN ne sont jamais interprétées comme du code.
- [ ] Les URLs et chemins de cache sont inchangés ou migrés.
- [ ] Les erreurs ne loggent pas de données personnelles.

---

## 6. Critères d'acceptation mesurables

Seuils **bloquants** pour valider l'import. Les valeurs « référence » sont soit mesurées (audit), soit estimées par le code (§2.4) ; elles doivent être remplacées par une mesure avant/après.

| Domaine | Métrique | Méthode | Référence actuelle | Cible acceptée |
|---|---|---|---:|---:|
| Parité | Fonctionnalités Must présentes et passantes | FT-01 à FT-38 + checklist §5 | 16/16 Must | 100 % ; 0 P0/P1 |
| Parité | Fonctionnalités Should | FT + checklist | 14/14 Should | ≥ 13/14, écarts documentés |
| Réseau | Requêtes stables, hors live | Compteur d'appels `curl` sur 1 h (log instrumenté) | ≈ 636/h estimé | ≤ 150/h ; objectif 60/h |
| Réseau | Requêtes live | Compteur sur 1 h avec/sans match | 0 à 300/h | ≤ 60/h avec live ; 0 sans |
| Réseau | Requêtes froid 24 h | Compteur sur installation neuve | ≈ 15 000 estimé | ≤ 2 000 |
| Réseau | Volume froid 24 h | `dumpsys netstats detail` | 63,7 Mo reçus/114 Mo émis sur 2 h sous charge (audit L.189) | ≤ 100 Mo/24 h, hors agents |
| Réseau | Refresh manuel | Compteur + chrono | 140 req `games` + autres | ≤ 30 req, ≤ 120 s |
| CPU | Écran allumé, repos | Delta `/proc/<pid>/stat` 10 s | 36,9 % UID avec now-playing (audit L.182) ; 100 % orphelin | UID < 5 % ; my-match < 2 % |
| CPU | Écran éteint | Delta 60 s | ≈ 1,2 cœur (audit L.185) | UID < 2 % ; 0 source |
| CPU | Coût d'un refresh | `time` côté invité + delta PID | non mesuré | ≤ 5 s CPU, ≤ 240 s wall |
| Rendu | fps au repos | `gfxinfo reset` + 30 s | 111 fps (audit L.183) | 0 frame/10 s ; ≤ 60 fps en interaction |
| Rendu | Jank | `gfxinfo` | 0,18 % (audit L.186) | < 1 % |
| Cache | Taille totale | `du -sh ~/.cache/espn-* ~/.cache/espn-logos` | non plafonné | ≤ 20 Mo JSON + ≤ 20 Mo logos |
| Cache | Nombre de logos | `find ... -type f` puis `wc -l` | non plafonné | ≤ 1 500 fichiers |
| Cache | Sprite | `ls -l sprite.*` | non plafonné | PNG ≤ 2 Mo, JSON ≤ 300 Ko |
| Cache | Rétention | `find -mtime +30` | 30 j logos | 0 fichier > 30 j |
| Processus | Orphelins | `ps -A -o PID,PPID,NAME` + boucle PPID=1 | 1 orphelin à 100 % (audit L.212-236) | 0 |
| Processus | Durée max | `ps -o etimes` | 45 min | aucun processus de données > 300 s |
| Processus | Concurrence | `ps` pendant refresh | 5/10 selon scripts | ≤ 10 curl |
| Fraîcheur | Live | `liveM.at` vs horloge | 1 min | ≤ 120 s |
| Fraîcheur | Scores/à venir | `games`/`nextup` | 15 min/6 h | ≤ 15 min pour le hero, ≤ 6 h pour nextup |
| Fraîcheur | Classements/bracket | `standings`/`knock` | 6 h | ≤ 6 h |
| Fraîcheur | Équipes | `teamsDb` | 24 h | ≤ 24 h |
| Rappels | 12 h | Journal de notifications + horodatage | non mesuré | 12 h ± 2 min, une fois |
| Rappels | Coup d'envoi | Journal | non mesuré | H ± 1 min, une fois |
| Persistance | États | 3 redémarrages | 15 états persistés | 100 % conservés |
| Offline | Comportement | Mode avion + cache | non mesuré | 0 crash, cache ≤ 24 h, statut ✗ |
| Mémoire | PSS | `dumpsys meminfo` avant/après 100 refresh | non mesuré | delta < 50 Mo |
| Batterie | Veille | 30-60 min écran éteint, avion, débranché | non mesuré (audit en charge) | ≤ 2 %/h |
| Sécurité | Injection | Test `'`, `;`, `$()` dans `abbr` | non mesuré | 0 exécution, erreur contrôlée |
| Qualité | `owl-check` | Outil officiel | non mesuré | 0 erreur, 0 warning bloquant |

**Règle de décision** : un seul seuil bloquant non atteint = import refusé. Les seuils « objectif » (60 req/h, 5 s CPU) sont des cibles d'ingénierie ; les seuils « acceptés » sont les minima de livraison. Toute dérogation doit être écrite, mesurée et associée à un test de non-régression.

---

## 7. Annexes

### 7.1 Commandes de mesure

```bash
# CPU par processus (ticks de 10 ms)
adb shell 'for d in /proc/[0-9]*; do p=${d#/proc/}; [ -r "$d/stat" ] || continue; s=$(cat "$d/stat"); echo "$p $s"; done' > /tmp/proc_t0.txt
sleep 10
adb shell 'for d in /proc/[0-9]*; do p=${d#/proc/}; [ -r "$d/stat" ] || continue; s=$(cat "$d/stat"); echo "$p $s"; done' > /tmp/proc_t1.txt

# Rendu
adb shell dumpsys gfxinfo dev.omalauncher reset
sleep 30
adb shell dumpsys gfxinfo dev.omalauncher

# Orphelins
adb shell 'for d in /proc/[0-9]*; do p=${d#/proc/}; [ "$p" = 1 ] && continue; ppid=$(awk "{print \$4}" "$d/stat" 2>/dev/null); [ "$ppid" = 1 ] && echo "$p $(cat "$d/comm" 2>/dev/null)"; done'

# Réseau
adb shell dumpsys netstats detail

# Caches
adb shell 'du -sh ~/.cache/espn-* ~/.cache/espn-logos 2>/dev/null'
adb shell 'find ~/.cache/espn-logos -type f | wc -l'

# Batterie
adb shell dumpsys batterystats --charged dev.omalauncher
```

Le script du dépôt `scripts/measure.sh before|after [--screen-off] [--battery]` exécute déjà ces relevés (README `measurements/`).

### 7.2 Points connus à ne pas « corriger » par suppression

| Point | Lignes | Décision |
|---|---|---|
| `formsData` lit `/root/.cache/espn-extra.json` et le consommateur lit `.out` | L.529, 531, 1429 | Conserver le fallback `all` ; si correction, test de parité des 5 formes. |
| Dossier `banner/` jamais alimenté | L.1450 | Alimenter ou garder le fallback ; ne pas supprimer le hero. |
| `myLeagues` exclut `fifa.friendly` | L.1128 | Comportement existant ; évolution produit explicite, pas effet de bord. |
| `jFuture` calculé mais non utilisé | L.1160 | Peut rester ; aucun impact fonctionnel. |
| `spr` sans `every` | L.998 | Recharger après rebuild ; ne pas supprimer le sprite. |
| `requires` incomplet | L.5 | Ajouter les dépendances ou fournir un fallback sans Perl. |
| `lastOk` seulement si `spinning` | L.1033 | Conserver la sémantique de statut manuel. |
| Statut basé sur `slow` 15 min | L.997, 1698 | Conserver l'âge affiché ; ne pas promettre le prochain refresh exact. |
| `lastDur=-1`, `h12At=0` | L.1017, 1023 | Valeurs sentinelles ; ne pas les interpréter comme des données. |

### 7.3 Ordre d'exécution recommandé

1. Geler l'original (`git` ou copie) et exécuter `scripts/measure.sh before`.
2. Importer la version optimisée **sans** changer les fonctionnalités ni les libellés.
3. Vérifier les schémas de chaque source avec un cache neuf, un cache partiel et un cache d'ancienne saison.
4. Exécuter FT-01 à FT-38, puis NFT-01 à NFT-24.
5. Exécuter `scripts/measure.sh after`, comparer §6, puis seulement envisager les optimisations de fréquence.
6. Archiver les preuves dans `measurements/after/` et joindre le tableau §6 rempli.

<!-- END -->
