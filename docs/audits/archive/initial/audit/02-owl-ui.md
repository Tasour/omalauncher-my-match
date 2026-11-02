# Audit OWL et rendu — `my-match`

- Fichier audité : `/home/tasour/Work/omalauncher-my-match/widget/my-match.owl` (1955 lignes).
- Références de comportement : `app/src/main/assets/widgets/docs/*.md` et le runtime Compose `app/src/main/kotlin/dev/omalauncher/widgets/`.
- Date : 2026-10-25.
- Portée : coût de rendu, expressions OWL, UI, accessibilité/i18n, patchs. Les mesures réseau/API sont dans `01-data.md` ; elles ne sont rappelées ici que lorsqu'elles dominent le coût total.
- Légende : **[P]** prouvé par le code OWL ou le runtime cité ; **[E]** estimation à confirmer par `owl-check`, preview et `scripts/measure.sh` (gfxinfo/CPU).
- Comptage statique : 122 `Text`, 27 `Row`, 17 `Column`, 14 `Box`, 3 `Canvas`, 3 `Image`, 44 `for`, 95 `if`, 2 `Flow`, 0 `Grid`, 0 `lazy`, 0 `visible` dans la partie UI (composants comptés une fois, pas leur expansion). Les `for` multiplient ces nœuds à l'exécution.

## 0. Synthèse

1. **[P] Le widget n'a aucune animation continue 60 fps** : aucun `animate`, aucun `time`, aucun `Shader`, aucun `Sparkline`. Le seul mouvement est le spinner Canvas, piloté à 1 s (L.1032, L.1733-1747). Les redraws sont donc événementiels, pas par frame.
2. **[P] `now=clock every 1s` n'invalide que 9 expressions `let`** : 6 directement (`fresh`, `notDone`, `kickSoon`, `h12Text`, `liveAge`, `heroDown`) et 3 par transitivité (`soon12`, `liveSuffix`, `liveWarn`). Aucune grande liste n'est recalculée chaque seconde : `all`, `base`, `tables`, `histMap` ne dépendent pas de `now`.
3. **[P] Sur ces 9, seules 3 sont lues par l'UI** : `heroDown` (L.1501), `liveWarn` (L.1605/1618/1656/1835/1874) et `liveSuffix` (L.1698). Les 6 autres ne sont lues qu'au déclenchement de `at`/`on` (L.1039, L.1040, L.1046, L.1047). Le coût par seconde est donc faible, mais pas nul : `fmtDuration` affiche les secondes sous 1 h, donc les textes changent réellement chaque seconde.
4. **[P] Le coût dominant n'est pas le rendu** : `01-data.md` mesure ~143 Mo/h et 448 requêtes/h pour `games` seul. Même une réduction de 1 s à 15 s de l'horloge ne changera pas l'ordre de grandeur. Le gain est surtout des réveils/frames évités, pas des fps.
5. **[P] Les vrais problèmes de rendu sont les listes non lazy** : 44 `for`, aucun `lazy`, tableaux entiers rendus à l'ouverture de l'écran (`showTables=true`, L.1031 ; boucles L.1829/1868/1907), et `upShow` non borné dans la tuile (L.1076/1597). C'est là que le jank et les limites de nœuds/draws se jouent.
6. **[P] Bugs UI/i18n concrets** : logos du bandeau lus dans `~/.cache/espn-logos/banner/` jamais alimenté (L.1450) ; `slow every 15m` utilisé comme « maintenant » pour le compte à rebours et l'âge du refresh (L.1375, L.1698) ; `on games first` ne réarme les rappels qu'une fois (L.1037-1042) ; plusieurs largeurs fixes trop petites (L.1367, L.1399/1403, L.1408).

## 1. Coût de rendu

### 1.1 Modèle de rendu OWL (preuves)

- Chaque propriété est une expression live ; un `let` global est un `derivedStateOf(structuralEqualityPolicy())` (`WidgetInstance.kt:242`), et une propriété de nœud est observée via `derivedStateOf` (`Props.kt:58-68`). Le runtime documente « a value that comes back unchanged invalidates nothing » (`WidgetInstance.kt:170-175`) : une valeur identique ne recompose pas.
- Un `for` est clé par `key(...)` (`Render.kt:347-357`) ; les lignes stables ne sont pas reconstruites quand la liste se réordonne. **Mais** un `for` sans `key` stable, ou une clé dupliquée, perd cet avantage.
- `visible:false` sort avant la composition (`Render.kt:538`) ; `if` ne compose que la branche active (`Render.kt:343`). Les deux sont équivalents pour le coût, mais `if` ne conserve pas l'état de scroll.
- `lazy:true` n'agit que sur un `for` **directement** enfant du `Column`/`Grid` (`Render.kt:475-520`). Un `for` dans un `if` n'est pas lazy.
- Limites : 500 nœuds pour une tuile, 1000 pour un écran (`Compiler.kt:17,20`), 2000 ops Canvas/frame (`Canvas.kt:74`), 32 images bitmap (`WidgetImages.kt:241`), listes plafonnées à 1000 (`Builtins.kt:77`). Le compteur de nœuds compile le corps d'un `for` une fois ; le runtime le multiplie.

### 1.2 Sources, triggers et horloges

| Déclaration | Ligne | Fréquence | Ce qu'elle coûte réellement |
|---|---:|---|---|
| `source now=clock every 1s` | 996 | 1 Hz | 1 réveil/s ; invalide 9 `let` (voir 1.3), 3 lus par l'UI. Pas de shell. |
| `source slow=clock every 15m` | 997 | 4/h | 4 réveils/h ; recalcule `myTablesAll` (L.1119), `tbTopAll` (L.1138) et sert de faux « now » (L.1375, L.1698). |
| `source spr=file(...)` | 998 | événementiel | Aucun polling ; relit le JSON quand le fichier change. Le PNG du sprite est chargé par `Canvas`/`Image` et mis en cache. |
| `source liveM ... every 1m` | 724 | 1/min | Rafraîchit `liveList` (L.1099) et donc les `LiveGame` live ; ne touche pas `all`. |
| `source games ... every 15m` | 237 | 4/h | Met à jour `all`, `base`, les tableaux, etc. C'est le gros burst de recalcul, pas la seconde. |
| `every 1s{elapsed=...}` | 1032 | 1 Hz | 1 réveil/s même au repos. Quand `spinning=false`, écrit `elapsed+0` : écriture d'une valeur égale, donc aucune recomposition, mais le coroutine wake reste. |
| `on games` | 1033 | à chaque `games` | Écrit `lastDur/lastOk/lastAt/spinning/spinUntil` ; burst léger. |
| `at spinUntil` | 1034 | une fois | Fin du spinner, même hors écran. |
| `on showTeams`, `when team...` | 1035-1036 | événementiel | Négligeable. |
| `on games first` | 1037-1042 | une seule fois | Arme `h12Id/h12At/kickId/kickAt` ; ne se réarme pas (voir §4.5). |
| `at h12At`, `at kickAt` | 1043-1058 | une fois par valeur | Réveils absolus, pas de polling. |
| `at spinUntil` | 1034 | une fois | Fin/échec du refresh. |

Preuve du runtime : les horloges tickent sur la seconde (`WidgetInstance.kt:757`), `every` attend au moins 1000 ms (`:823`), `at` attend par pas de 30 s (`:836`). Les sources ne tournent que page live ; `at` tourne même hors écran (docs/declarations.md).

### 1.3 Les 9 `let` qui dépendent de `now`

| `let` | Ligne | Dépendance | Lecteur réel | Coût par tick |
|---|---:|---|---|---|
| `fresh` (locale au trigger) | 1046 | directe | `at h12At` L.1047 | seulement quand `at` tire |
| `notDone` | 1078 | directe | `soon12` L.1079 | 1 filtre de `allMine` + `nextDone.any`, seulement au premier `games` |
| `soon12` | 1079 | via `notDone` | `on games first` L.1039 | un `sortBy` de la liste filtrée, une fois |
| `kickSoon` | 1080 | directe | `on games first` L.1040 | un filtre + tri de `allMine`, une fois |
| `h12Text` | 1091 | directe | `at h12At` L.1047 | formatage + concaténation, seulement au trigger |
| `liveAge` | 1101 | directe | `liveSuffix`, `liveWarn` | soustraction, 1/s |
| `liveSuffix` | 1102 | via `liveAge` | statut écran L.1698 | `fmtDuration` + concaténation, 1/s |
| `liveWarn` | 1103 | via `liveAge` | labels L.1605/1618/1656/1835/1874 | `fmtDuration` + concaténation, 1/s si `liveAge>900` |
| `heroDown` | 1116 | directe | bandeau L.1501 | `fmtDuration` + concaténation, 1/s |

**Conséquence prouvée** : `all` (L.1064), `base` (L.1071), `allMine` (L.1077), `tables` (L.1069), `histMap` (L.1151), `rivalsAll` (L.1129), `topAll` (L.1133), `euroMatches` (L.1142) ne dépendent pas de `now`. Le tick de 1 s ne refiltre pas ces listes. C'est le point le plus important : l'horloge n'est pas le coût lourd.

**Conséquence moins visible** : `fmtDuration` renvoie des secondes sous 1 h (`Builtins.kt:667-683`), donc `liveSuffix` change chaque seconde au lieu de chaque minute, et `heroDown` aussi pour un match à moins d'une heure. Cela produit de vraies recompositions de `Text`, pas seulement des invalidations.

### 1.4 Recompositions/redraws par seconde

Hypothèse : page live (tuile visible ou écran ouvert). Écran éteint, les sources et les triggers `every` s'arrêtent ; seuls les `at` armés peuvent encore tirer. Tuile MINE avec bandeau et match à moins d'une heure, écran non ouvert ; puis écran ouvert avec `liveM` chargé.

| Contexte | Réveils/min | Invalidations `now`/min | `Text` recomposés/min | Canvas/s |
|---|---:|---:|---:|---:|
| Tuile MINE, aucun match proche | 120 | 540 (9×60) | 0 | 0 |
| Tuile MINE, match < 1 h | 120 | 540 | ~60 (`heroDown`, secondes) | 0 |
| Écran ouvert, `liveM` chargé | 120 | 540 | ~60-120 (`liveSuffix` + `heroDown`) | 0 |
| Écran ouvert, RIV/TOP5/EUROPE (`liveWarn`, >15 min) | 120 | 540 | ~60-120 (statut + `liveWarn`) | 0 |
| Spinner actif | 120 | 540 | +60 | 1 (Canvas 52 dp) |

- **[P]** Aucun Canvas de crest/logo n'est redessiné par le tick : leur `Canvas` ne lit pas `now` ; seules les propriétés `spr/logo/px` les invalident.
- **[P]** Le sprite est **une seule image** partagée par tous les `Crest` (L.1193-1198) : pas de téléchargement ni de redraw par logo au tick.
- **[E]** Les 120 réveils/min se réduisent à ~64/min avec `now` à 15 s (4 + 60 du trigger), ~62/min à 30 s. Les invalidations passent de 540/min à 36/min (15 s) ou 18/min (30 s), soit -93 %/-97 %.
- **[E]** Si l'on arrondit les durées à la minute (`fmtDuration` sans secondes), les `Text` repassent de ~60-120/min à ~1/min même sans toucher au trigger. C'est le gain le plus sûr, sans changer la fréquence de l'horloge.
- **[E]** Si le trigger `every 1s` est supprimé et que le spinner accepte 15 s, les réveils tombent à ~4/min (-97 %). Cela change la vitesse du spinner : à ne faire que si cette régression visuelle est acceptée (voir §6).

### 1.5 Gains de 1 s → 15 s / 30 s

| Scénario | Réveils/min | Invalidations/min | Frames de texte/min | Remarque |
|---|---:|---:|---:|---|
| Actuel | 120 | 540 | 60-120 | secondes visibles, spinner 1 s |
| `now` 15 s, trigger conservé | 64 | 36 | 4-12 | **-47 % réveils, -93 % invalidations** ; spinner inchangé ; secondes sautent par 15 |
| `now` 30 s, trigger conservé | 62 | 18 | 2-6 | -48 % réveils, -97 % invalidations ; « ça commence » peut retarder de 30 s |
| `now` 15 s + durées arrondies à la minute | 64 | 36 | ~1-4 | meilleur compromis visuel ; plus de secondes qui défilent |
| `now` 15 s + trigger supprimé | 4 | 36 | ~1-4 | **-97 % réveils**, mais spinner à 15 s : régression fonctionnelle visible |

**Estimation CPU/fps** : le rendu au repos est déjà événementiel ; on ne récupère pas de fps, on évite des frames isolées et des réveils. Le coût dominant reste les sources shell/curl/jq (`01-data.md` : ~143 Mo/h). Le gain CPU du rendu est probablement <1 % d'un cœur au repos ; le gain batterie/veille vient des 60→4 ticks/min. **[E]**, à prouver par `gfxinfo` et delta `/proc/<pid>/stat` avec `scripts/measure.sh`.

## 2. Expressions coûteuses

### 2.1 Constats

| Expression | Ligne | Coût | Récurrence | Preuve |
|---|---:|---|---|---|
| `all=flatten([...]).sortBy` | 1064 | 2 filtres avec `gIds.any`/`sIds.any` + tri | à chaque `games`/`seasonAll`/`extra` | [P] |
| `base=all.filter(...)` et `allMine=all.filter(...)` | 1071, 1077 | deux scans complets avec le **même** prédicat imbriqué `myTeams.any` | à chaque `all`/`myTeams`/`team` | [P] |
| `myTablesAll=tables.filter(...)` | 1119 | scan de `tables` × `myTeams` | à chaque `slow`/`standings`/`myTeams` | [P] |
| `tbTopAll=tables.filter(...)` | 1138 | scan de `tables` | à chaque `slow`/`standings` | [P] |
| `eurBase=all.filter(...).sortBy` | 1067 | tri d'une liste déjà triée (`all` l'est) | à chaque `all` | [P] |
| `rivalsAll`, `topAll`, `euroMatches` `.sortBy(...).reverse()` | 1129, 1133, 1142 | tri + reverse d'une liste déjà triée descendant (`extra` sort `sort_by(.at)|reverse`, L.629) | à chaque `extra`/onglet | [P] source, [E] contrat |
| `nextNew=nextAll.filter(... !extraAll.any ...)` | 1125 | O(n×m) | à chaque `nextup`/`extra` | [P] |
| `myLeagues=unique(flatten(scopeOf.map(...)))` | 1128 | `flatten` + `unique` sur ≤5 équipes, puis filtre | à chaque `myTeams`/`selTeam` | [P] |
| `flatten([liveF,nextF])`, `rivalsTile`, `topTile`, `euroList` | 1076, 1132, 1136, 1144 | concaténation + `take`/tri de petites listes | à chaque source/onglet | [P] |
| `all.find(g=>g.id==h12Id)` et `kickMatch` | 1082-1083 | `find` linéaire sur `all` | à chaque `all`/id de rappel | [P] |
| `histLg`, `jr`, `jrPast`, `jMatches`, `euroHist`, `euroJMatches`, `euroUpMatches`, `euroResMatches`, `topUpMatches`, `topResMatches` | 1151-1175 | 8-10 filtres/tris sur les mêmes listes, plusieurs `get(histMap,...)` identiques | à chaque `histfull`/`curLg`/`selJ` | [P] |
| `euroH=...get(histMap,...).find(...)` | 1346 | `find` linéaire **par ligne de match** | à chaque rendu d'un match européen | [P] |
| `eurPos=indexOf(eurIds,g.id)+1` | 1344 | `indexOf` linéaire par ligne (mais seulement lu pour `uefa.europa` par court-circuit) | par ligne europa | [P] |
| `FormStrip`: `all.filter(...).sortBy.take(5).reverse` | 1416 | scan de `all` par équipe (jusqu'à 5) | à chaque `all` | [P] |
| `BannerForm`: `formsData.filter` + `all.filter` | 1429-1431 | deux scans, deux fois (deux bandeaux/écran) | à chaque rendu du bandeau | [P] |
| `notDone` + `kickSoon` | 1078, 1080 | deux filtres + deux tris de `allMine` | **une fois** (`on games first`) | [P] |
| `SetupBlock.res` | 1271 | filtre de `teamsDb` sur 3 champs par frappe | à chaque frappe | [P] |
| `count(...)` répétés | 1596, 1608, 1634, etc. | linéaire sur de petites listes | à chaque recomposition | [P] |

**Taille réelle [E]** : les scripts filtrent déjà les événements sur `WANT` (L.48, L.279, L.886, L.708), donc `all`/`base`/`rivalsAll` tournent probablement sur quelques centaines de matchs, pas 10 000. `tables` est plus gros : ~26 compétitions × groupes × 18-20 équipes, soit plusieurs centaines de lignes ; c'est le rendu des tableaux, pas les filtres, qui coûte.

### 2.2 Mémoïsations/regroupements sans changer le comportement

1. **`base` = `allMine` quand `team=="ALL"`.** Le prédicat de L.1071 (branche `team=="ALL"`) est exactement celui de L.1077. Remplacer les deux scans par :
   - `let allMine = all.filter(<prédicat actuel L.1077>)`
   - `let base = team=="ALL" ? allMine : allMine.filter(<branche spécifique actuelle L.1071>)`
   Gain : un scan complet en moins à chaque changement de données. **[P] équivalent**, à tester sur un match où `selTeam` est null.

2. **Historique groupé par journée.** Construire une fois :
   - `let jrAll = histLg.filter(g=>(g.round??0)>0)`
   - `let jrByRound = groupBy(jrAll, g=>g.round)`
   - `let jMatches = curJ==null ? [] : get(jrByRound, curJ, []).sortBy(g=>g.at)`
   - `let topUpMatches = topUpJ==null ? [] : get(jrByRound, topUpJ, []).sortBy(g=>g.at)`
   Même principe pour `euroHist`/`euroJMatches`/`euroUpMatches`/`euroResMatches`. Gain : 8-10 scans deviennent des `get` O(1) + tri du petit groupe. **[P] équivalent** si les clés de round sont numériques ; tester `round=null`.

3. **Index `historique par id` pour `GameRow`.** Construire une fois par `histfull` :
   - `let histFlat = flatten(values(histMap))`
   - `let histRoundById = histFlat.reduce((m,g)=>set(m,g.id,g.round??0),{})`
   - Dans `GameRow` : `let euroR=get(histRoundById,g.id,0)`
   Gain : `find` linéaire par ligne → `get` O(1). **[P] équivalent** si `id` non nul ; ignorer les ids nuls.

4. **Index d'appartenance pour `all`.** `gIds`/`sIds`/`extraAll` sont utilisés par `any` O(n). Construire des maps `id -> true` avec `reduce((m,g)=>set(m,g.id,true),{})` puis `get(map,id,false)`. Gain O(n×m) → O(n+m) à chaque `all`. **[P] équivalent** avec garde sur `id != null`.

5. **Ne pas retrier ce qui l'est déjà.** `all` est trié par `at` (L.1064) ; `extra` sort déjà descendant (L.629). Soit documenter ce contrat et retirer les `.sortBy(...).reverse()` de `rivalsAll`/`topAll`/`euroMatches`/`eurBase`, soit faire un seul `let extraDesc=extraAll` et le réutiliser. **[E]** : dépend du contrat de la source ; garder un tri de sécurité si la source peut changer.

6. **`myTablesAll` avec un index `kind:abbr`.** Construire `let myKeys=reduce(myTeams,(m,t)=>set(m,(t.kind??"c")+":"+t.abbr,true),{})` puis tester `get(myKeys,(kind)+":"+tm.ours,false)` au lieu de `myTeams.any`. Gain modeste (5 équipes max) mais supprime un `any` imbriqué dans un filtre de plusieurs centaines de lignes. **[P] équivalent**.

7. **`FormStrip`/`BannerForm`.** Elles refont `all.filter(...).sortBy` par équipe/bandeau. Pour 5 équipes, le coût reste faible ; si l'on veut le supprimer, pré-calculer `let formByTeam = groupBy(all.filter(g=>g.state=="post"), g=>...)` ne suffit pas (un match a deux équipes). Une map `team -> 5 derniers` construite en un passage est possible mais plus complexe ; **[E]** gain limité, à faire seulement si le profilage le montre.

8. **Supprimer les alias morts** : `let baseF=base` (L.1072), `let gmShown=gm` (L.1931), `let shown1=baseF` (L.1947), `let jFuture` (L.1160, jamais lu), `S.liveWord` (L.1000, jamais lu). Aucun gain CPU, mais moins de dérivations et de code à comprendre.

## 3. UI et rendu

### 3.1 Structure

- Tuile : L.1529-1691. Écran : L.1692-1954. Les deux lisent les mêmes `let`/`state`/sources.
- La tuile a un en-tête fixe (onglets, cartes d'équipes, bandeau) puis une `Column{weight:1; scroll:true}` pour les matchs (L.1585-1600, L.1602-1613, L.1615-1651, L.1653-1690). L'écran a une seule `Column{scroll:true}` (L.1694-1695) : pas de `lazy`, donc tout est composé.
- Aucun `Grid`, aucun `lazy`, aucun `visible` : tout le gating passe par `if`. C'est correct pour supprimer les nœuds, mais pas pour virtualiser une longue liste.

### 3.2 Listes longues et `for` non lazy

| Liste | Ligne | Problème | Preuve |
|---|---:|---|---|
| `upShow` (live + tous les `pre`) | 1076, 1597 | **non borné** dans la tuile ; peut dépasser la hauteur et multiplier les `GameRow` | [P] |
| `pastTake` | 1105, 1593 | borné à 5, OK | [P] |
| `gmShown=gm` par équipe | 1929-1937 | rend tous les matchs de l'équipe, sans lazy | [P] |
| `baseF` onglet équipe | 1947-1948 | rend tous les matchs de la sélection | [P] |
| `rivalsAll.take(...)` | 1820 | borné 15/30, mais non lazy | [P] |
| `topAll.take(30)` | 1859 | borné 30, non lazy | [P] |
| `euroMatches.take(30)` | 1898 | borné 30, non lazy | [P] |
| `myTablesAll`/`topTables` | 1829, 1868, 1907 | tableaux entiers, non lazy | [P] |
| `knockLg` par round | 1917-1922 | 5 rounds, petit | [P] |

**Estimation [E]** : un `GameRow` fait ~25 nœuds (Row, 2 Crest, 5-9 Text, Box/FormChip…). 30 lignes ≈ 750 nœuds, déjà au-delà des 500 d'une tuile (limite compilée, pas runtime) et proche des 2000 draws Canvas. Sur la tuile, `upShow` peut facilement dépasser 20 lignes. Sur l'écran, les tableaux ajoutent ~1000 `Text` (20 équipes × 9-10 colonnes × plusieurs groupes). C'est le poste de composition le plus lourd, surtout à l'ouverture.

**Correctifs sans retirer de fonctionnalité** :
- Rendre les listes de l'écran `lazy:true` en restructurant l'écran en en-tête fixe + contenu scrollable avec des `for` **directement** enfants du `Column` lazy. C'est le seul vrai correctif de virtualisation ; effort moyen à élevé.
- À défaut, borner la tuile (ex. 12 lignes) et laisser l'écran tout afficher. C'est une compression de tuile, pas une suppression : l'écran garde le reste. **[E]**.
- Pour les tableaux, `showTables` est déjà un toggle (L.1031, L.1827, L.1866, L.1905) ; le rendre `persist` et/ou `false` par défaut évite de composer ~1000 `Text` à chaque ouverture. Cela change l'état initial visible ; à proposer comme option, pas comme obligation.

### 3.3 Tableaux, bracket, onglets

- `TableBlock` (L.1229-1266) : `TableRow` = 9-10 `Text` + `Box` (L.1210-1228). Un groupe de 20 équipes ≈ 200 `Text`. `topTables` peut contenir 5 ligues (L.1139, L.1868) → ~1000 `Text`. `myTables` peut contenir plusieurs groupes (L.1137, L.1829).
- `TableBlock` est correctement gaté par `if showTables` (L.1828/1867/1906), et par `if count(...)` avant. Le problème est le volume, pas l'absence de gating.
- Bracket : 5 rounds, `for g in sm` (L.1917-1922), petit. Le `let sm=knockLg.filter` est recalculé par round mais sur une petite liste ; acceptable.
- Onglets : `modeTabs`/`topTabs`/`euroTabs` sont des listes constantes (L.1120-1122, L.1140). Les `for` ont des clés stables (`m.id`, `lg.id`). Bien.
- `TableBlock` clé `u.tag+" "+u.group` (L.1829/1868/1907) : stable tant que le tag/group ne changent pas ; OK. `TableRow` clé `tm.abbr` (L.1253) : si un groupe contient deux fois la même abréviation, collision ; improbable mais possible dans des données imparfaites. Clé conseillée : `tm.abbr+":"+(tm.rank??0)`.

### 3.4 Clés instables

- `for t in myTeams key t.abbr` (L.1558, L.1715, L.1928) : `myTeams` vient de `teamsDb`, dont la clé réelle est `key` (`abbr:kind`, L.494). Deux sélections club/sélection peuvent partager `abbr` ; la clé `t.abbr` peut alors entrer en collision. Utiliser `key (t.key??t.abbr)`.
- `for tm in u.teams key tm.abbr` (L.1253) : voir ci-dessus.
- Les autres `for` utilisent `g.id`, `m.id`, `r.key`, `d.key`, `st` : stables [P].

### 3.5 `if`/`visible` manquants

- `FormStrip` (L.1415-1427) est rendu même quand `ms` est vide : la carte d'équipe réserve un vide de `5*px+8` (63-83 dp). Ajouter `visible:count(ms)>0` ou un placeholder. **[P]**.
- `BannerForm` (L.1428-1442) est rendu même sans forme : colonne vide de `px` (11 dp) à côté du logo. `visible:count(ms)>0` si l'on veut supprimer le vide ; sinon placeholder.
- `MatchBanner` a un `if heroMatch!=null` (L.1489), donc pas de bandeau vide. Bien.
- `showTables`, `exp`, `wide`, `oddsOn`, `count(draft)`, `count(res)`, `count(sm)` sont déjà gatés.
- `games.ok==false` n'est **pas** gaté : voir §4.5.
- `upShow` n'est pas gaté par la taille de la tuile ; voir §3.7.
- `visible` n'est utilisé nulle part. Pour les cas ci-dessus, `if` suffit ; `visible` serait utile si l'on voulait conserver l'état de scroll d'un bloc (ce n'est pas le cas ici).

### 3.6 Images, sprite, logos

- **Bon** : `Crest` utilise une planche sprite unique via `Canvas` (L.1183-1206), avec `si=get(spr.idx,...,-1)` et `clip(...) { image(sprPath,...) }`. Le JSON `spr` est lu par `file` (L.998) ; le PNG n'est pas téléchargé par le widget. Pas de redraw au tick.
- **Fallback** : si `sprOk` est faux, chaque crest crée un `Image{src:"~/.cache/espn-logos/soccer/${logo}"}` (L.1200-1201). Au premier chargement, ou si le sprite n'existe pas, on peut avoir 30-50 `Image` en même temps ; la limite est 32 bitmaps (`WidgetImages.kt:241`) et les suivantes ne sont pas dessinées. **[E]** selon le nombre de crests visibles. Correctif : afficher un placeholder tant que `spr==null`, ou ne créer l'`Image` que si `spr==null` (pas si le sprite existe mais n'a pas ce logo).
- **Bug prouvé** : `BannerLogo` lit `~/.cache/espn-logos/banner/${logo}` (L.1450). Aucun script du widget n'écrit dans `banner/` ; tous écrivent dans `soccer/` (L.84, L.342, L.511, L.640, L.775, L.847, L.969). Les deux logos du bandeau sont donc toujours absents. Correctif : pointer `soccer/`, ou réutiliser `Crest` (sprite) avec `px` plus grand. Ne pas supprimer `BannerLogo` : le bandeau doit garder ses logos.
- **Accessibilité** : aucun `Image` n'a `label` (L.1191, L.1201, L.1450), alors que `Image.label` existe en owl 11 (docs/nodes.md). Les cartes d'équipes (L.1558-1575, L.1715-1731) n'affichent que le crest + la forme, sans nom : un lecteur d'écran ne peut pas identifier l'équipe. Ajouter `label` au `Image` et un `Text` de nom (ou un label de `Crest`).
- **Cache** : `Image`/`Canvas image` réutilisent l'image décodée ; pas de nouvelle requête par tick. Le dossier `soccer/` est partagé ; le sprite évite 50 fichiers séparés. Bon.

### 3.7 Débordements de texte et tailles dynamiques

| Élément | Ligne | Problème | Preuve |
|---|---:|---|---|
| Score live `width:18` | 1399, 1403 | à `fz=17` (XL), deux chiffres en mono ≈ 21 dp > 18 : troncature | [P] arithmétique `cpc=fz*8/13` L.1358 |
| Score final | 1387, 1389 | largeur dynamique `len(...)*cpc`, correct | [P] |
| Tag `width:22` | 1367 | `CONF` (4 caractères à 10 sp) ≈ 24 dp > 22 | [E] |
| `rdt2 width:30` | 1408 | `Quarts`, `Demies`, `Finales` dépassent 30 dp | [P] longueur |
| `dtw=len(dstr)*5.2+1` | 1361, 1388 | 5,2 dp/caractère est sous-estimé pour du mono 11 sp ; dates FR tronquées | [E] |
| `heroDown` maxLines:1 | 1116, 1501 | « coup d'envoi dans 2h 5m » / « dans 5m 12s » peut dépasser `midW` (169 dp) | [E] |
| `rivLabel+liveWarn` maxLines:1 | 1605, 1618, 1656 | 5 noms + « concurrents » + « màj il y a … » sur une ligne | [P] composition de chaîne |
| `S.welcome` style title | 1274 | `title` force `maxLines=1` par défaut (`Render.kt:1202`) ; « Bienvenue — choisis tes équipes » sur une ligne | [P] runtime |
| `BannerOdd` valeur | 1465 | `fixed(v,2)` à `fz=17` dans une Box de largeur 1/3 de `midW` | [E] |
| `TableRow` colonnes | 1216-1226 | sommes fixes ; correct en `wide`, à vérifier en 3 colonnes | [E] |
| `mwid`/`slot`/`cpc` | 1357-1359 | constantes approchées, pas mesurées | [E] |

**Tailles adaptatives** :
- `wide=max(max(screenWidth??0,tileWidth??0),240)>=280` (L.1106) : sur une tuile 3×3 (~170 dp), `wide` est faux, mais le bandeau garde des logos 56 dp et `midW≈169` (L.1480, L.1494, L.1519), soit ~281 dp de contenu : débordement. **[E]**.
- `MatchBanner(w=72,h=96)` reçoit `w/h` (L.1469, appels L.1584/L.1791) mais **ne les utilise jamais** : `midW` et `px:56` sont fixes. C'est probablement l'adaptation prévue, inachevée. Correctif : utiliser `w/h` pour `BannerLogo` et `midW`, et masquer les cotes (`oddsOn`) quand `!wide`.
- `minSize:3x3` (L.3) est trop petit pour l'en-tête : cartes d'équipes (5 × `FormStrip` 63 dp + gaps), bandeau ~281 dp, onglets. **[E]** : soit passer `minSize:4x4`, soit un mode compact qui masque le bandeau/la forme sur les petites tuiles. Ne pas supprimer les fonctionnalités : elles restent dans l'écran.
- `fz` (L.1107) et `uiSize` sont cohérents ; tester S/M/L/XL avec FR (mois plus longs) et des scores à deux chiffres.

### 3.8 Animations continues

- **[P]** Aucun `animate`, aucun `time`, aucun `Shader`, aucun `Sparkline` : `rg` ne trouve aucune occurrence. Le spinner est un `Canvas` qui dessine un caractère Braille selon `elapsed%10` (L.1733-1747), redessiné à 1 s par `every 1s` (L.1032). Ce n'est pas une animation 60 fps.
- Le `Canvas` du spinner est petit (52×52, L.1734) et ne redessine que si `elapsed`/`spinning` change. Le coût est faible ; c'est le réveil qui compte.
- Les `Crest` sont des `Canvas` avec image ; ils ne redessinent que si `spr`, `logo`, `px` changent (L.1189-1198). Pas de redraw par tick.
- Les `Image` ne redessinent que si `src`/taillechangent ; le cache évite les décodages répétés. **[P]**.

## 4. Accessibilité et i18n

### 4.1 Libellés et langues

| Constat | Ligne | Détail | Correctif |
|---|---:|---|---|
| `lang="en"` par défaut | 999 | Un utilisateur FR doit ouvrir les réglages et changer la langue | Initialiser depuis la locale du téléphone si un builtin existe ; sinon documenter |
| Dictionnaire `S` | 1000 | clés FR/EN, bon socle | Ajouter les clés manquantes ci-dessous |
| `S.team:"equipe"` | 1000 | accent manquant | `"équipe"` |
| `liveSuffix` contient `" · live "` en dur | 1102 | reste anglais en FR, alors que `S.liveWord` existe | `" · "+S.liveWord+" "` |
| `liveWarn` | 1103 | « màj il y a … » / « updated … » ; le préfixe est localisé, mais `fmtDuration` ajoute les secondes | Utiliser une durée arrondie à la minute, ou `fmtAgo` |
| `euroLabel` | 1141 | « Ligue des Champions » / « Europa League » / « Conference League » en dur | Mettre dans `S` |
| `topLabel` | 1177 | « ENG · ESP · GER · ITA · FRA » en dur | Mettre dans `S` |
| `S.playedHdr` | 1000 | « J » en FR est ambigu (journée/joués) ; « MP » en EN | « J. » ou « Joués » |
| `S.liveWord` | 1000 | clé jamais utilisée | L’utiliser dans `liveSuffix` ou la retirer |
| `detail`/`tag` ESPN | 1332, 1367, 1401 | « FT », « HT », « 45' » restent en anglais | Mapper les états connus (`post`→Terminé, `in`→MT) si l’on veut du 100 % FR ; sinon documenter |
| `meta.description` | 4 | anglais, mais c’est la fiche store | OK |

### 4.2 Dates, heures, fuseaux

- **[P]** Les heures de match sont stockées en epoch UTC (`date[0:16]+":00Z" | fromdateiso8601`, L.48/279/886), puis affichées avec `fmtTime(..., null, lang)` (L.1091, L.1114, L.1360, L.1374, L.1378, L.1698) : fuseau du téléphone et langue demandée. C’est correct, DST compris.
- **[P]** `at h12At`/`at kickAt` utilisent des epochs absolus (L.1039, L.1041) ; pas de calcul local dans le widget.
- **[P] Bug** : `slow` (15 min) est utilisé comme « maintenant » dans `fmtDuration(max(g.at-slow,0))` (L.1375) et dans l’âge du refresh (L.1698). Le compte à rebours des lignes peut donc être faux jusqu’à 15 min, et le statut « il y a … » peut afficher 0 s pendant 15 min puis sauter. Utiliser `now` (ou un `min=clock every 1m`) pour l’affichage, et garder `slow` uniquement pour l’expiration des tableaux (L.1119/1138).
- **[E]** `fmtDuration` n’est pas localisé (unités `d/h/m/s`), mais reste lisible en FR. Si l’on veut « 5 min », il faudra une fonction dédiée ; ne pas l’inventer dans ce patch.

### 4.3 Contrastes et thème

- **[P]** Le widget utilise `soft=mix(muted,foreground,0.5)` (L.1117) et `pop=mix(accent,foreground,0.4)` (L.1118), donc suit le thème pour le texte courant. Bien.
- **[P]** Couleurs de statut en dur : `#22c55e` (vert), `#ef4444` (rouge), `#3b82f6` (bleu), `#f59e0b` (orange) (L.1208, L.1215, L.1325-1326, L.1399-1403, L.1483-1485, L.1699, L.1737-1745). Elles ne suivent pas le thème.
- **[E]** Sur un fond clair, `#22c55e` a un contraste d’environ 2,4:1 et `#ef4444` ~3,8:1 ; pour du texte de 11 sp, c’est sous le seuil WCAG AA (4,5:1). Sur un thème sombre, c’est souvent acceptable. Remplacer par les noms de thème `green`/`red`/`blue`/`orange` (qui existent, docs/expressions.md) ou ajouter un fond/`bold`. Vérifier les thèmes clairs dans la preview.
- **[P]** La zone de classement est signalée par une barre de couleur (L.1215) + une légende textuelle (L.1254-1265) ; la couleur n’est pas le seul canal. La forme d’équipe (V/N/D) est aussi textuelle (`FormChip` Canvas texte, L.1322-1328) ; OK.
- **[P]** Les logos/crests n’ont pas de `label` ; voir §3.6.

### 4.4 Cibles tactiles et lecteur d’écran

- **[P]** Onglets de tuile en `Text` avec `onTap` (L.1534) : hauteur ≈ 11 sp, sans padding vertical, donc cible tactile bien inférieure à 48 dp. Même chose pour les flèches `Text` de l’écran (L.1629/1631, L.1667/1669). Les `Button` de l’écran (L.1808/1810, L.1847/1849, L.1886/1888) sont meilleurs mais leur hauteur par défaut reste à vérifier.
- **[P]** Cartes d’équipes : `Box` avec `padding:3` + crest 26 + form strip (L.1558-1575) ; la cible est correcte, mais il n’y a pas de nom lisible par un lecteur d’écran.
- **[P]** `Canvas` du spinner (L.1733-1747) n’a pas de label ; l’écran a un texte de statut (L.1697-1701), mais la tuile n’a aucun texte « actualisation ». Ajouter un `Text` de statut à côté du spinner, ou utiliser `Image` avec `label` pour l’icône.
- **[P]** `Image.label` est disponible (owl 11) et non utilisé ; l’ajouter est sans impact visuel.
- **[P]** Sur la tuile, les nœuds ne font pas de ripple (docs/nodes.md) : les onglets `Text` (L.1534) ne donnent un retour qu’après le tap (couleur/gras). Sur l’écran, les `Button` ont le ripple. Ajouter un état pressé ou utiliser `Button` sur la tuile si l’on veut un retour immédiat.
- **[P]** `Popup`/`Input`/`Button` n’ont pas de problème de focus ici ; `Input` de recherche (L.1276) n’a pas de `focus:true`, ce qui est normal hors écran ouvert ; l’utilisateur doit taper le champ.

### 4.5 États vides et erreurs

- **[P]** `games` a `status` (L.237), donc `games.ok` et `games.err` existent, mais l’UI ne les lit pas. `if games==null` (L.1588) et `total==0` (L.1590) confondent « pas encore chargé », « aucun match » et « échec réseau ». Un échec avec `out=[]` affiche « aucun match pour cette équipe » au lieu d’une erreur.
- **[P]** `lastOk`/`lastAt` ne sont mis à jour que si `spinning` est vrai (L.1033) : après un refresh automatique réussi, `lastOk` reste l’ancien, et après un échec automatique, le statut peut rester « ✓ ». `lastDur` n’est mis à jour qu’en manuel. Le statut écran (L.1698) n’est donc pas fiable.
- **[P]** `seasonAll`, `standings`, `teamsDb`, `extra`, `liveM`, `knock`, `nextup`, `histfull` n’ont pas `status` : en cas d’échec, ils restent `null`, et l’UI affiche « chargement… » indéfiniment (`standings==null` L.1822, `knock==null` L.1912, `teamsDb==null` L.1288). Il n’y a pas d’état « hors ligne ».
- **[P]** `gamesScript` fait `exit 1` quand `games.json` est vide (L.82) : une sélection sans match dans la fenêtre ±90 j est traitée comme un échec, pas comme une liste vide légitime.
- **[P]** `formsScript` lit `/root/.cache/espn-extra.json` (L.529) alors que `extra` écrit `~/.cache/espn-extra.json` (L.631) : si `$HOME` n’est pas `/root`, les formes du bandeau sont toujours vides. Le fallback `all` (L.1430-1431) masque partiellement le problème.
- **[P]** `on games first` (L.1037-1042) ne s’exécute qu’une fois. Si l’utilisateur choisit ses équipes après le premier `games` (cas normal : `myTeams=[]` au démarrage, `games` renvoie `[]`), les rappels H-12 et coup d’envoi ne sont **jamais** armés. C’est un bug fonctionnel (voir §6).

## 5. Patchs concrets

Les patchs ci-dessous préservent les fonctionnalités, sauf mention explicite. Les numéros sont ceux du fichier actuel.

### P1 — Horloges : 1 s → 15 s, `slow` réservé aux tableaux

**Avant (L.996-997)**
```owl
source now=clock every 1s
source slow=clock every 15m
```

**Après**
```owl
source now=clock every 15s
source slow=clock every 1h
```

- `now` ne sert qu’aux compteurs/âges (`heroDown`, `liveAge`, `notDone`…). À 15 s, les affichages à la minute restent corrects ; les secondes sautent par 15 s.
- `slow` ne sert plus qu’à l’expiration des tableaux (L.1119/1138) ; 1 h suffit. L’âge du refresh doit passer à `now` (P3).
- **Risque** : `h12At=max(soon12.at-12h,now)` (L.1039) peut être décalé de 15 s ; négligeable. « ça commence maintenant » (L.1116) peut être en retard de 15 s. Si l’on tient aux secondes, garder `now` à 1 s et appliquer seulement P2/P3/P4.

### P2 — Trigger du spinner : ne plus écrire au repos

**Avant (L.1032)**
```owl
every 1s{elapsed=elapsed+(spinning?1:0)}
```

**Après**
```owl
every 1s{if spinning{elapsed=elapsed+1}}
```

- Aucun changement visible : `elapsed` n’augmente que pendant le spinner. On évite l’écriture d’une valeur égale 99 % du temps. **[P] sans régression**.
- Le réveil de 1 s reste là : OWL ne permet pas de désactiver un trigger `every` selon un état. Pour le supprimer, il faut accepter un spinner à 15 s (P1 sans ce trigger), ce qui est une régression visuelle. Ne pas le retirer sans accord.
- Il n’y a **aucune animation continue 60 fps** à supprimer dans ce widget ; ne pas remplacer le spinner par `animate rotation`, qui créerait 60 frames/s et coûterait plus cher que le tick de 1 s.

### P3 — Statut de refresh : `slow` → `now`, et `lastOk` sur les mises à jour automatiques

**Avant (L.1698, extrait)**
```owl
... agoP+fmtDuration(max(slow-(lastAt??slow),0))+agoS ...
```

**Après**
```owl
... agoP+fmtDuration(max(now-(lastAt??now),0))+agoS ...
```

**Avant (L.1033)**
```owl
on games{lastDur=spinning?elapsed:lastDur;lastOk=spinning?(games.ok??false):lastOk;lastAt=(games.ok??false)?now:lastAt;spinning=false;spinUntil=0}
```

**Après**
```owl
on games{
  lastDur=spinning?elapsed:lastDur
  lastOk=(games.ok??false)
  lastAt=(games.ok??false)?now:lastAt
  spinning=false
  spinUntil=0
}
```

- Corrige l’âge du refresh (plus de 0 s pendant 15 min) et le statut après un refresh automatique.
- Avec `lastOk=true` et `lastDur=-1` (état initial L.1017), le statut L.1698 afficherait `✓ -1s` : utiliser `max(lastDur??0,0)` dans le texte, ou initialiser `lastDur=0`.
- `lastOk` reflète désormais le dernier `games` (succès ou échec), même hors spinner. Si l’on préfère masquer un échec automatique, garder l’ancien `lastOk` ; dans ce cas, P12 doit afficher `games.ok` pour ne pas mentir.

### P4 — Compte à rebours des lignes : ne plus utiliser `slow`

**Avant (L.1375)**
```owl
Text{text:"("+S.inPrep+fmtDuration(max(g.at-slow,0))+")";...}
```

**Après (option exacte, secondes)**
```owl
Text{text:"("+S.inPrep+fmtDuration(max(g.at-now,0))+")";...}
```

**Après (option minute, compatible P1)**
```owl
Text{text:"("+S.inPrep+replace(fmtDuration(max(60,floor((g.at-now)/60)*60))," 0s","")+")";...}
```

- Corrige un compte à rebours faux jusqu’à 15 min. L’option minute évite une recomposition par seconde de chaque ligne et rend P1 invisible.
- Même traitement possible pour `heroDown` (L.1116) et `liveSuffix` (L.1102) si l’on veut supprimer les secondes : `replace(fmtDuration(max(60,floor((...)/60)*60))," 0s","")`.
- **Risque** : l’option minute retire l’affichage des secondes (fonctionnalité visible). À valider.

### P5 — Supprimer le double scan `base`/`allMine`

**Avant (L.1071 et L.1077)** : deux `all.filter(...)` avec le même prédicat imbriqué.

**Après**
```owl
let allMine=all.filter(g=>count(myTeams)>0&&(count(g.tids??[])>0?(...):(...)))
let base=team=="ALL"?allMine:allMine.filter(g=>((count(g.tids??[])>0&&selTeam!=null&&(selTeam.tid??"")!=""?(g.tids??[]).any(s=>s==selTeam.tid):(g.squads??[]).any(s=>s==team))&&(selTeam==null||(...)==(selTeam.kind??"c"))))
```

- Garder exactement la branche spécifique actuelle de L.1071. **Gain** : un scan complet en moins à chaque `games`/`seasonAll`/`extra`.
- **Preuve d’équivalence** : la branche `team=="ALL"` de L.1071 est identique à L.1077. Tester un match avec `selTeam=null` et un match de coupe.

### P6 — Historique : `groupBy` et index par id

**Avant (L.1151-1175, extrait)**
```owl
let histLg=...
let jr=histLg.filter(g=>(g.round??0)>0).sortBy(g=>g.round)
let jrPast=histLg.filter(g=>(g.round??0)>0&&g.state!='pre').sortBy(g=>g.round)
let jMatches=curJ==null?[]:histLg.filter(g=>g.round==curJ).sortBy(g=>g.at)
let topUpMatches=topUpJ==null?[]:histLg.filter(g=>g.round==topUpJ).sortBy(g=>g.at)
```

**Après**
```owl
let jrAll=histLg.filter(g=>(g.round??0)>0)
let jrByRound=groupBy(jrAll,g=>g.round)
let jr=jrAll.sortBy(g=>g.round)
let jrPast=jr.filter(g=>g.state!='pre')
let jMatches=curJ==null?[]:get(jrByRound,curJ,[]).sortBy(g=>g.at)
let topUpMatches=topUpJ==null?[]:get(jrByRound,topUpJ,[]).sortBy(g=>g.at)
```

- Même principe pour `euroHist`/`euroJMatches`/`euroUpMatches`/`euroResMatches`.
- **Gain** : 8-10 scans → 1 scan + `get` O(1) + tri du groupe. **[P] équivalent** (groupBy préserve l’ordre ; tester `round=null`).

**Index par id pour `GameRow` (L.1346)**
```owl
let histFlat=flatten(values(histMap))
let histRoundById=histFlat.reduce((m,g)=>set(m,g.id,g.round??0),{})
...
let euroR=get(histRoundById,g.id,0)
```
- **Gain** : `find` linéaire par ligne → `get`. **[P] équivalent** si `g.id` non nul.

### P7 — Listes : lazy ou bornage de la tuile

**Constat** : aucun `lazy` (L.1587/1604/1617/1655/1695). Le seul vrai correctif est de restructurer l’écran :

```owl
Column{
  // en-tête fixe : statut, onglets, réglages
  Column{
    weight:1
    lazy:true
    // un seul for direct, ou des for directs séparés par des éléments
    for g in upShow key g.id{LiveGame{g:g;compact:true}}
  }
}
```

- Rend les lignes seulement à l’écran ; conserve les fonctionnalités (tout est accessible en scrollant).
- **Effort** : moyen ; il faut sortir les `for` des `if` ou accepter un `Column` lazy par section.
- À défaut, borner la tuile à 12 lignes (`upShow.take(12)`) et laisser l’écran tout afficher : ce n’est pas une suppression, mais une compression de tuile. **[E]**.
- Pour les tableaux : rendre `showTables` `persist` et/ou `false` par défaut (L.1031, L.1827, L.1866, L.1905) évite ~1000 `Text` à l’ouverture. Option UX à valider, pas une obligation.

**Gating léger, sans lazy** :
```owl
Row{visible:count(ms)>0;...}        // L.1417, FormStrip
Column{visible:count(ms)>0;...}     // L.1432, BannerForm
```
- `visible:false` sort avant la composition (`Render.kt:538`) : la carte d’équipe ne réserve plus un vide quand aucune forme n’est connue. Le libellé/crest reste.

### P8 — Logos du bandeau et `MatchBanner` adaptatif

**Bug (L.1450)**
```owl
- Image{src:"~/.cache/espn-logos/banner/${logo}";...}
+ Image{src:"~/.cache/espn-logos/soccer/${logo}";...}
```
Ou remplacer `BannerLogo` par `Crest{logo:logo;px:w}` (sprite) pour profiter de la planche unique.

**Adaptation (L.1469-1524)**
```owl
component MatchBanner(w=72,h=96){
  let bw=wide?56:min(min(w,h),40)
  let midW=wide?fz*14:max(fz*7,w+16)
  ...
  BannerLogo{logo:heroHLogo;px:bw}
  ...
  if oddsOn&&wide{ ... }   // cotes sur les tuiles larges/écran seulement
}
```
- `w/h` sont déjà passés (L.1584 : `wide?88:48` ; L.1791 : `96`) mais ignorés. Les utiliser supprime le débordement à 3×3. **Risque** : les cotes disparaissent sur une tuile étroite ; elles restent dans l’écran (où `wide=true`). Fonctionnalité préservée sur l’écran.

### P9 — Clés stables

**Avant (L.1558, L.1715, L.1928)**
```owl
for t in myTeams key t.abbr{...}
```
**Après**
```owl
for t in myTeams key (t.key??t.abbr){...}
```
- `myTeams` vient de `teamsDb` avec `key` (`abbr:kind`, L.494) ; `t.key` est la vraie identité. Évite une collision club/sélection.
- **Avant (L.1253)** : `for tm in u.teams key tm.abbr` → `key tm.abbr+":"+(tm.rank??0)`.
- **Risque** : si un ancien `myTeams` persisté n’a pas `key`, le fallback garde `abbr` ; pas de régression.

### P10 — Largeurs de texte

**Avant (L.1399/1403)**
```owl
Text{text:hm.score??"?";...;width:18;...}
```
**Après**
```owl
Text{text:hm.score??"?";...;width:max(18,len((hm.score??"?")+"")*cpc);...}
```
Idem `aw.score`. Même formule que la branche finale (L.1387/1389).

**Autres**
```owl
- Text{text:g.tag;fontSize:10;...}                 // L.1367, width:22
+ Text{text:g.tag;fontSize:10;...;width:28;...}
- Text{text:rdt2;fontSize:10;...;width:30;...}     // L.1408
+ Text{text:rdt2;fontSize:10;...;width:42;...}
- let dtw=len(dstr??"")*5.2+1                      // L.1361
+ let dtw=len(dstr??"")*6.5+1
```
- `heroDown` (L.1501) : `maxLines:2` ou texte plus court ; `rivLabel+liveWarn` (L.1605/1618/1656) : `maxLines:2` sur l'écran, ou libellé court.
- **Risque** : les largeurs modifient l’alignement du tableau ; vérifier la preview 6×4 et 3×3.

### P11 — Accessibilité

```owl
component Crest(logo=null,art=null,px=16,label=""){
  ...
  Image{src:art;size:px;fit:contain;label:label}
  ...
  Image{src:"~/.cache/espn-logos/soccer/${logo}";size:px;fit:contain;label:label}
}
```
- Passer `label:t.name` aux `Crest` des cartes d’équipes (L.1571/1728) et `label:heroMatch.home.name`/`away.name` aux `BannerLogo`. Attention : le `Canvas` du sprite (branche L.1193-1198) n’a pas de `label` ; pour les cartes d’équipes, ajouter aussi un `Text{text:t.short}` (ou un libellé équivalent) pour que le nom soit lisible.
- Spinner : ajouter un `Text` « actualisation… » à côté du `Canvas` (ou dans la tuile), car un `Canvas` n’a pas de label.
- Onglets `Text` (L.1534) : ajouter `padding:[0,4]` (ou passer en `Button` sur l’écran, déjà le cas L.1705) pour une cible tactile plus haute. Flèches (L.1629/1631) : idem.
- **Sans impact visuel** sauf le padding ; valider la hauteur de l’en-tête.

### P12 — Erreurs et états vides

**Avant (L.1588-1591)**
```owl
if games==null{Text{text:S.loading;...}}
else if total==0{Text{text:S.noMatchTeam;...}}
else{...}
```

**Après**
```owl
if games==null{Text{text:S.loading;...}}
else if games.ok==false{Text{text:S.fail+(games.err??"");...}}
else if total==0{Text{text:S.noMatchTeam;...}}
else{...}
```
- `games.err` peut être long : le tronquer (`take`/`maxLines:2`) ; ne jamais afficher de secret (il n’y en a pas ici).
- Même logique dans l’écran (L.1698) : `lastOk==false` → `S.fail` + `games.err` si disponible.
- `gamesScript` L.82 : pour une liste vide légitime, sortir `0` avec `[]` plutôt que `1` ; garder `1` seulement si aucune requête n’a réussi. Cela distingue « aucun match » de « échec ».
- **Risque** : afficher une erreur pour un échec partiel peut être plus bruyant ; limiter à `games.ok==false` et garder les données précédentes.

### P13 — i18n ciblée

```owl
- let liveSuffix=liveAge==null?"":" · live "+agoP+fmtDuration(liveAge)+agoS
+ let liveSuffix=liveAge==null?"":" · "+S.liveWord+" "+agoP+fmtDuration(liveAge)+agoS
```
- `S.liveWord` existe déjà (L.1000) ; il n’était pas utilisé.
- Remplacer `equipe` par `équipe` (L.1000), `J` par `J.` si souhaité.
- Ajouter `S.champions`, `S.europa`, `S.conference`, `S.top5Leagues` et les utiliser en L.1141/1177.
- `liveWarn` : `lang=="fr"?"màj ":"updated "` → clé `S.updated` pour cohérence.
- Les `detail` ESPN restent anglais ; si besoin, mapper `post`/`in`/`pre` vers des libellés FR. Ne pas traduire `tag`/abrégés.

### P14 — Réarmer les rappels après le choix des équipes

**Problème (L.1037-1042)** : `on games first` ne s’exécute qu’une fois. Au démarrage `myTeams=[]`, `games` renvoie `[]`, le trigger s’exécute avec `soon12=null`, puis ne se réexécute jamais quand l’utilisateur choisit ses équipes. Les rappels H-12 et coup d’envoi ne sont jamais armés.

**Avant**
```owl
on games first{
  if soon12==null{h12Id="";h12At=0}
  else{h12Id=soon12.id;h12At=max(soon12.at-12*3600,now)}
  kickId=kickSoon==null?"":kickSoon.id
  kickAt=kickSoon==null?0:kickSoon.at
}
```

**Après**
```owl
state kickDone=[]persist
on games{
  if (games.ok??false){
    if soon12!=null&&!nextDone.any(d=>d==soon12.id){
      h12Id=soon12.id
      h12At=max(soon12.at-12*3600,now)
    }
    if kickSoon!=null&&!kickDone.any(d=>d==kickSoon.id){
      kickId=kickSoon.id
      kickAt=kickSoon.at
    }
  }
}
```

- `nextDone` (H-12) et `kickDone` (coup d’envoi) empêchent les doublons ; les deux listes sont plafonnées comme `nextDone` (L.1050).
- Ajouter dans `at kickAt` (L.1054-1058) : `let d=flatten([kickDone,[kickId]]);kickDone=count(d)>30?reverse(take(reverse(d),30)):d`.
- **Risque** : un `games` qui revient vide ne doit pas effacer un rappel déjà armé ; le code ci-dessus ne le fait pas. Tester sélection après démarrage, changement d’équipe, match à H-12, coup d’envoi, redémarrage.
- **Sans ce patch**, le reste de l’audit rend parfois les rappels plus fragiles (P1 décale `now` de 15 s) ; à appliquer ensemble.

### P15 — Nettoyage sans effet rendu

- Supprimer `let jFuture` (L.1160, jamais lu), `let baseF=base` (L.1072), `let gmShown=gm` (L.1931), `let shown1=baseF` (L.1947), `S.liveWord` si P13 n’est pas appliqué.
- Utiliser `MatchBanner.w/h` (P8) ou retirer les paramètres et les arguments (L.1469/1584/1791).
- `Crest.art` n’est jamais passé ; le garder si l’on prévoit un usage, sinon le retirer.
- `requires` (L.5) : ajouter `perl` (L.106 utilise Perl + `Compress::Zlib` L.109). Sans lui, la planche sprite peut échouer et le fallback 32 images apparaît.
- `formsScript` (L.529) : `~/.cache/espn-extra.json` au lieu de `/root/...`, et `jq` dans le `PATH` au lieu de `/usr/bin/jq`.

## 6. Gain CPU/fps et risques

### 6.1 Gain attendu

| Poste | Avant | Après P1/P2/P3/P4 | Confiance |
|---|---:|---:|---|
| Réveils horloge | 60/min | 4/min (15 s) ou 2/min (30 s) | [P] fréquence |
| Réveils trigger | 60/min | 60/min (spinner conservé) | [P] |
| Total réveils | 120/min | 64/min (15 s), 62/min (30 s) | [P] fréquence |
| Invalidations des 9 `let` | 540/min | 36/min (15 s), 18/min (30 s) | [P] dépendances |
| Frames de texte (`heroDown`, `liveSuffix`) | 60-120/min | 4-12/min (secondes), ~1-4/min (minutes) | [E] |
| Canvas spinner | 1/s pendant refresh | inchangé | [P] |
| Composition des tableaux | ~1000 Text à l’ouverture | -30 à -60 % avec lazy/collapse | [E] |
| CPU rendu au repos | faible | encore plus faible | [E] |
| fps | statique, pas de 60 fps à gagner | pas de gain fps attendu | [E] |

- **Le gain de 1 s → 15 s est de -47 % de réveils et -93 % d’invalidations**, pas -93 % de CPU total. Le trigger du spinner empêche d’atteindre -97 % sans régression visuelle.
- **Le gain le plus utile est P2/P4 + durées arrondies** : il supprime les recompositions par seconde sans toucher à la fréquence de l’horloge.
- **Le gain de rendu le plus visible est P7** (lazy/collapse des tableaux) : c’est l’ouverture de l’écran et les longues listes qui peuvent janker, pas le tick de 1 s.
- **Le coût dominant reste réseau/commandes** (`01-data.md` : ~143 Mo/h, 448 req/h pour `games`) ; une optimisation OWL ne changera pas la batterie autant que la réduction des requêtes.

### 6.2 Risques de régression

| Patch | Risque | Mitigation |
|---|---|---|
| P1 `now` 15 s | Compte à rebours à la seconde qui saute, « ça commence » en retard de 15 s, `h12At` décalé de 15 s | P4 avec arrondi minute, ou garder 1 s si les secondes sont contractuelles ; tester un match à H-1 |
| P2 trigger | Aucun visuel ; le spinner reste à 1 s | Ne pas supprimer le trigger ; P1 seul ne change pas le spinner |
| P3 `lastOk` | Un échec automatique peut rester masqué | Afficher `games.ok==false` (P12) ; tester offline |
| P4 `now` au lieu de `slow` | Plus de recompositions de lignes (30/15 s) | Arrondi minute ; `lazy` si beaucoup de lignes |
| P5 `base=allMine` | Différence sur `selTeam`/`kind`/`tids` | Tester club/sélection, `team=ALL`, `team=abbr`, `selTeam=null` |
| P6 `groupBy` | Round null ou ids null | Garde `round??0`, `id!=null` ; comparer les listes avant/après |
| P7 lazy | Scroll imbriqué, position perdue, nœuds non mesurables | Restructurer en un seul scroll ; tester 3×3 et écran |
| P8 chemin banner | Si un script externe alimente `banner/`, on perd un logo spécifique | Vérifier `banner/` ; sinon utiliser `soccer/` ou `Crest` |
| P9 clé `t.key` | Ancien état persisté sans `key` | Fallback `t.key??t.abbr` |
| P10 largeurs | Décalage de colonnes / hauteur | Preview 3×3, 6×4, S/M/L/XL, FR/EN |
| P12 erreurs | Bruit visuel, message long | `maxLines:2`, `take(80)`, garder les données précédentes |
| P14 rappels | Doublons ou rappel manqué après changement d’équipe | `nextDone` + `kickDone`, plafond 30, tester redémarrage |
| P15 `perl` | Installation demandée | `requires` correct ; sinon fallback images |

### 6.3 Protocole de validation

1. `owl-check widget/my-match.owl` : 0 erreur, preview 3×3 et 6×4 ; vérifier `.errors/` vide.
2. Ouvrir l’écran, onglets MINE/RIV/TOP5/EUROPE, FR/EN, thème clair/sombre ; vérifier tableaux, bracket, bandeau, logos, états vides.
3. `scripts/measure.sh before` puis `after` : `gfxinfo` 30 s au repos, CPU delta, `netstats`, batterie écran allumé/éteint.
4. Test fonctionnel : sélection de 1 et 5 équipes, match à H-12, coup d’envoi, refresh manuel, timeout, offline, changement de langue, redimensionnement 3×3.
5. Comparer les frames : si `gfxinfo` montre déjà ~0 frame/min au repos, le gain de P1 est surtout les réveils ; si chaque tick produit une frame, le gain 1 s→15 s est direct.

## Annexe — Preuves et comptage

- Comptage statique : `rg -o '\bText\{'` etc. sur L.996-1955 ; 122 `Text` (composants une fois), 44 `for`, 95 `if`.
- Dépendances `now` : extraction des `let` et fermeture transitive ; 6 directes + 3 indirectes. `all`, `base`, `tables`, `histMap` ne contiennent pas `now`.
- Runtime : `WidgetInstance.kt:242` (lets dérivés), `:170-175` (égalité structurelle), `:757` (tick horloge), `:823` (`every` ≥1 s), `:836` (`at` par pas de 30 s) ; `Props.kt:58-68` (propriétés dérivées) ; `Render.kt:343-357` (if/for/clés), `:508` (LazyColumn), `:538` (visible), `:1202` (maxLines par défaut) ; `Compiler.kt:17,20` (limites) ; `Canvas.kt:74` (2000 ops) ; `WidgetImages.kt:241` (32 images).
- Docs : declarations.md (sources/triggers), nodes.md (lazy, Text, Image.label), expressions.md (fmtTime/fmtDuration), screens.md (screen/scroll), versions.md (owl 11).
