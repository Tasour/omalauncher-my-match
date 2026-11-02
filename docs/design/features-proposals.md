# Nouvelles features — propositions

Catalogue proposé le 2026-10-30. Les lignes **Fait** sont implémentées et
poussées ; les autres attendent une décision.

## Handoff avant-match — v5.22.9

- le bandeau écrit le match dans le fichier **et** pose l’état `handoff` de l’app déjà ouverte
- l’app préfère ce handoff au fichier, puis retombe sur le fichier au démarrage à froid
- corrige l’affichage d’un ancien match quand l’app était encore en mémoire
- app `1.0.23`

## Trajectoire xG — v5.22.8

- remplace les deux courbes xG/xGA par une trajectoire de 20 matchs, lissée sur 5
- trait plein réel `G − encaissés`, pointillé attendu `xG − xGA`, axe symétrique autour de zéro
- rubans vert/rouge entre les courbes, marqueurs de croisement et badge de signal
- lecture guidée : position, pente, écart réel/attendu, croisement, limites
- source Understat pour les 20 matchs des cinq grands championnats ; Football-Data en secours
- sélection de l’équipe dans le graphique, synthèse comparée des deux équipes
- réflexion complète et sources dans `trajectory-xg-2026-11-01.md`
- app `1.0.22`

## Graphes xG avancés — v5.22.7

> Remplacé par la trajectoire 20 matchs de la v5.22.8.

- nouvel onglet Analyse dans l’app avant-match : rolling xG/xGA/xGD/xPts sur 5 matchs
- deux courbes xG vs xGA par équipe, séries glissantes alignées sur les 10 derniers matchs
- barres xGD par match, radar de percentiles et carte attaque/défense avec les deux équipes mises en avant
- calculs JavaScript dans `scripts/fd-analysis.js`, cache `~/.cache/espn-fd-analysis.json`
- percentile dans le championnat, tendance xGD et lecture rapide des volumes de tirs
- app `1.0.21`

## xG Football-Data — v5.22.6

- source gratuite Football-Data.co.uk synchronisée toutes les 12 h pour les cinq grands championnats et la Ligue 2
- xG, xGA et xPts sur les cinq derniers matchs, écart finition vs xG, provenance affichée
- lecture par nom normalisé avec alias, jamais par abréviation ESPN (collisions MUN/MNC)
- app `1.0.20`, cache `~/.cache/espn-fd.json` et script `scripts/fd-sync.py`

## Couleurs des logos — v5.22.4

- couleurs primaire et secondaire extraites des logos, contraste garanti sur le hero et les cartes
- cache `~/.cache/espn-logos/colors.json` ; repli sur les couleurs par défaut

## Sélection depuis Mes matchs — v5.22.3

- un tap sur le bandeau ouvre l’app avant-match sur le match choisi
- sélection transmise par `~/.cache/prematch-match.json` ; clé `o:prematch.owl`

## Forme centrée — v5.22.5

- lettres V/N/D centrées dans les carrés de forme de l’app avant-match

## Classement complet — v5.22.2

- classement dans Stats avec Place / Équipe / J / G / N / P / DB / Pts / Forme
- logos via les données de classement ou le cache équipes, initiales en dernier recours
- forme sur cinq résultats, titre de compétition nettoyé

## Lisibilité avant-match — v5.21.2

- « sans encaisser », « les 2 marquent » et « plus de 2,5 buts » sur des lignes séparées
- moyenne de confrontations avec virgule décimale

## Lisibilité avant-match — v5.21.1

- stats sur deux lignes, plus de « 2 p… » ni de « 4 les 2 marq… »
- fraîcheur « à l'instant » au lieu de « now »
- décimales françaises sur total/handicap

## Arbres repliés et complets — v5.21.0

- arbre replié par défaut, bouton afficher/masquer
- les matchs du tour viennent du cache complet, plus seulement du club suivi
- si les 8es manquent, l'arbre commence aux quarts avec les bons libellés

## Arbre dans Mes matchs — v5.20.1

- même arbre Canvas 8es → finale pour la coupe suivie dans « Mes matchs »
- tours antérieurs conservés en liste
- composant Bracket réutilisable pour l'Europe et les coupes nationales

## Arbre de tournoi — v5.20.0

- à partir des 8es : colonnes 8es / quarts / demies / finale avec lignes de liaison
- tous les matchs du même niveau sont dans leur colonne
- les tours antérieurs (32es, barrages) restent en liste comme avant

## Performance écran — v5.19.2

- migration qui replie aussi les classements des installations existantes
- liste de fixtures encore plus légère (GameRow direct, 4/12 lignes)

## Performance écran — v5.19.1

- classements repliés par défaut à l'ouverture de « Mes matchs »
- un tap sur « classements : non » les affiche
- moins de nœuds et de texte à composer à l'ouverture

## Performance écran — v5.19.0

- 12 fixtures par équipe sélectionnée, 4 par équipe en mode ALL, avec « plus »
- une seule table de classement rendue par défaut
- moins de nœuds à l'ouverture de « Mes matchs »

## Performance écran — v5.18.9

- la liste de fixtures de « Mes matchs » est plafonnée à 20 lignes, 12 par équipe en mode ALL
- bouton « plus / moins » pour charger la suite
- ouverture de l'écran intérieur plus légère, tables et en-tête inchangés

## Performance — v5.18.8

- audit dans `../audits/performance-2026-10-31.md`
- historique avant-match toutes les 6 h, limité au championnat
- horloge principale à 1 min ; cutoffs et calendrier sur l'horloge horaire
- calculs de rang inutilisés supprimés

## App avant-match — v5.18.7

- légende V = gagné, N = nul, D = perdu
- bloc « 5 prochains » nommé explicitement
- sprint de finition terminé

## App avant-match — v5.18.6

- compte à rebours avant le coup d'envoi
- score et mention « en direct » / « terminé » selon l'état
- mouvement des cotes ouverture → fermeture

## App avant-match — v5.18.5

- forme et calendrier récupérés depuis l'historique complet : 5 avant et 5 après pour les deux équipes
- un seul cadre coloré par carte équipe, logos nets
- libellés explicites : points, sans encaisser, les 2 marquent, plus de 2,5 buts, pts/match, confrontations
- prochains matchs affichés pour les deux équipes

## App avant-match — v5.18.4

- bouton actualiser qui relance les sources du widget principal
- onglets inactifs plus contrastés
- cotes et totaux avec virgule décimale française
- horloge de fraîcheur ralentie à 5 min

## App avant-match — v5.18.3

- cartes équipes compactes, sans vide sous les noms
- libellé de forme exact quand moins de 5 matchs sont disponibles
- libellés de cotes sur deux lignes dans Infos

## App avant-match — v5.18.2

- logos 160 px du cache bannière au lieu des 48 px upscalés (flou)
- cartes équipes à hauteur fixe et noms sur deux lignes, sans débordement
- prochains matchs limités aux rencontres futures réelles

## App avant-match — v5.18.1

- ouverture corrigée : la clé du tiroir est `o:prematch.owl`, pas `owl:`
- app allégée : plus de cache historique complet, horloge à 1 min, calculs de rang inutilisés supprimés

## App avant-match dédiée — v5.18.0

- nouvel app `widget/prematch.owl`, ouverte par la bannière (`owl:prematch.owl`)
- layout complet avec hero VS coloré, onglets Aperçu / Stats / Infos
- tendances, forme, contexte, classement, H2H, cotes, compos, actus et voyage
- données lues dans les caches ESPN déjà produits par le widget principal

## Hiérarchie avant-match — v5.17.4

- les tendances passent avant le bloc « À retenir », conformément à l'audit UX
- le reste de la refonte (hero compact, onglets) est documenté et sera livré dans un widget dédié

## Audit avant-match — v5.17.3

- audits UX, accessibilité et data documentés dans `../audits/prematch-2026-10-31.md`
- projection trompeuse remplacée par les points réels
- leaders vides masqués ; actus filtrées sur les noms complets des deux équipes
- refonte en onglets/hero compact et corrections de barres zéro planifiées

## Avant-match — v5.17.2

- actus filtrées sur les deux équipes du match, plus de news PSG sur un Lyon–Angers
- compos affichées seulement si les onze sont publiés ; sinon message « ~1 h avant »
- compositions vides et actus hors sujet ne polluent plus la page

## Avant-match — v5.17.1

- bloc « À retenir » avec les tendances clés
- points pris sur les 5 derniers matchs à domicile/extérieur
- probabilités 1X2 visibles dès le bandeau

## Refonte avant-match — v5.17.0

- page unique de comparaison, sans onglets : chaque tendance oppose les deux équipes
- bandeau VS avec couleurs d'équipe, forme, rang et cotes
- duels chiffrés pts/buts/clean sheets/BTTS/+2,5 avec barres colorées
- forme, momentum et comparaison côte à côte, puis contexte, H2H, cotes, calendrier, effectifs, actus et voyage

## Avant-match — v5.16.2

- difficulté des 5 prochains matchs : rang moyen des adversaires
- comparaison clean sheets et BTTS entre les deux équipes

## Avant-match enrichi — v5.16.1

- marchés total buts et handicap dans l'onglet Cotes
- sparkline de momentum sur les 5 derniers points
- comparaison buts / points sur 5 matchs entre les deux équipes
- moyenne de buts H2H et libellés de journée Europa corrigés

## Page avant-match — v5.16.0

- la bannière ouvre une vraie page plein écran, plus une fiche inline
- onglets Aperçu / Cotes / Stats / H2H / Onze / Actus / Voyage
- aperçu : rang, PPG, projection, clés, forme dom/ext, 5 derniers et 5 prochains
- cotes : 1X2, sans marge, mouvement, cumul ; stats : classement, séries, leaders, blessures
- voyage : stade, arbitre, repos, travel pack, chambrage, pause et rappels
- la colonne `#rang` des fixtures est retirée

## Fixtures épurées — v5.15.3

- retrait de la colonne `#rang` de l'adversaire dans la liste des matchs de « Mes matchs »
- le rang reste disponible dans la fiche/le bandeau

## Coupes nationales — v5.15.2

- FA Cup, Carabao Cup, Copa del Rey, DFB-Pokal et Coppa Italia suivies avec la Coupe de France
- tours lus depuis `season.slug` et affichés dans « Mes matchs » pour l'équipe choisie
- libellés de tours (préliminaire → finale) et repli européen depuis les matchs de saison
Garde-fous coupes nationales.

## Arbres de coupes — v5.15.1

- Coupe de France ajoutée aux compétitions suivies, avec son arbre dans « Mes matchs »
- les tours de coupe sont lus depuis le `season.slug` ESPN de chaque match
- l'arbre européen se complète aussi depuis les matchs de saison, sans attendre la source dédiée
Garde-fous CDF/UCL bracket.

## Données, voyage, finitions — v5.15.0

- archive CSV/Markdown exportable, leaders buteurs/passeurs, blessures et suspensions dans la fiche
- travel pack copiable, bandeau hors ligne avec âge + retry, mode basse data (initiales, sections allégées)
- ligne de chambrage, import de la config équipes par JSON, retry visible par source
Garde-fous DN25/DN23/DN22/AT20/AT18/AT22/HF23/HF24/AT25.

## Personnalisation — v5.14.9

- rivaux explicites par codes séparés par des virgules, prioritaires sur les concurrents de ligue
- coupure des alertes club par club (rappels, buts, cartons, HT/FT)
- couleurs d'équipe activables/désactivables, preset couleur conservé par club
Garde-fous HF01/N15/HF25.

## Contexte match — v5.14.8

- rang de l'adversaire `#N` sur chaque ligne (accent si top 5)
- jours de repos avant le prochain match dans la fiche
- forme domicile/extérieur séparée dans la fiche
Garde-fous DN14/HF/DN08.

## Casual/setup — v5.14.7

- ligne de confiance « ESPN, sans compte, rien n'est envoyé » dans le setup
- retry explicite si le catalogue d'équipes échoue
- recherche vide avec suggestion et bouton pour l'effacer
- pause globale des alertes 24 h, respectée par rappels, buts, cartons, HT/FT
Garde-fous CU02/CU03/CU04/CU15.

## Accessibilité — v5.14.6

- **AT03** haut contraste (toggle, soft = foreground, pop = accent).
- **AT12/AT16** dates relatives « aujourd'hui / demain » dans les lignes.
- **AT07** flèches précédent/suivant nommées, spinner déjà étiqueté.
- **AT10** padding des onglets et flèches pour des cibles plus grandes.
Garde-fous AT03/AT07/AT10/AT12/AT16.

## Live alerts — v5.14.5

Goal Flash inclut désormais le **buteur et la minute**, une alerte **carton rouge**
et les notifications **mi-temps** (source live) et **fin de match** (source games,
rattrapage toutes les 15 min). Les détails viennent de `competitions[0].details`
du scoreboard, sans requête supplémentaire. Garde-fous HF02/HF03/HF04.

## Refonte ergonomique — v5.14.0

Réglages en vue dédiée, découpés en **Général / Affichage / Rappels / Partage /
Données / À propos** ; interrupteurs compacts ligne par ligne, en-tête avec
statut lisible et bouton fermer, libellés raccourcis, lien **Fiche** dans la
carte du match. Les tests `ergonomic settings` et `fiche link in hero` gardent
la structure.

## Fait — Fiche match (2026-10-30)

Panneau **« fiche match »** sous la carte du prochain match (écran, MINE) :
stade/ville/affluence/arbitre, statistiques (matchs joués ou en direct),
temps forts (buts, cartons, remplacements), compositions et actus ESPN.
Réutilise le `summary` déjà chargé pour les cotes/H2H (schéma 2, cache
invalidé une fois). Tests : `match centre` statique + assertions du fixture
`summary-h2h.json` (info/stats/events/lineups/news).

## Fait — lot F01–F20 (2026-10-30)

| ID | Feature | Test |
|---|---|---|
| F01 | Délai de rappel 1/3/6/12/24 h | `F01 reminder lead` |
| F02 | Heures calmes 22–07 | `F02 quiet hours` |
| F03 | Digest quotidien 08:00 | `F03 daily digest` |
| F04 | Digest hebdo du lundi | `F04 weekly digest` |
| F05 | Réarmer les rappels | `F05 reset reminders` |
| F06 | Matchday mode | `F06 matchday mode` |
| F07 | Mode compact | `F07 compact mode` |
| F08 | Filtre « aujourd'hui » | `F08 today filter` |
| F09 | Masquer les cotes | `F09 show odds` |
| F10 | Masquer la forme | `F10 show form` |
| F11 | Copier le match | `F11 copy match` |
| F12 | Copier mes équipes (JSON) | `F12 copy teams` |
| F13 | Couleur d'accent par équipe | `F13 team accent` |
| F14 | Mode daltonien | `F14 colour-blind` |
| F15 | Révéler un score masqué au tap | `F15 per-match reveal` |
| F16 | Préchargement à 06:00 | `F16 prewarm` |
| F17 | Fusion des doublons de match | `F17 dedupe matches` |
| F18 | Étiquette AET/PEN | `F18 AET/PEN tag` |
| F19 | Bandeau calendrier 7 jours | `F19 calendar strip` |
| F20 | Dernier résultat H2H | `F20 last H2H result` |

Les actions F01–F20 sont dans **Réglages → plus d'options**. Les rappels, digests,
anti-spoiler et notifications de but respectent les heures calmes.

## Fait

| ID | Feature | Détail | Commit |
|---|---|---|---|
| N01 | Goal Flash | Notif texte à chaque but de mes équipes (score, minute, compétition) ; compare les snapshots `liveM`, silencieux au premier, si le score baisse (VAR) ou en anti-spoiler | `50f887c` |
| N04 | Anti-spoiler | Mode persistant : scores et pastilles V/N/D masqués pour les matchs en direct/terminés | `2dc98b9` |
| N07 | Carte H2H | Forme des 5 dernières confrontations dans la carte du prochain match, depuis `summary.seasonseries` (même requête que les cotes) | à venir |

## Proposé — expérience jour de match

| ID | Feature | Effort |
|---|---|---|
| N02 | Alerte compos ~1 h avant (`summary.rosters`) | M |
| N03 | Matchday Mode : tuile recentrée sur le match du jour (compte à rebours, live, timeline) | M |
| N05 | Rappels intelligents : délai 1 h/3 h/12 h/1 j, heures calmes, pas de notif si ouvert récemment | M |
| N06 | Digest quotidien 08:00 et hebdo du lundi | S |
| N08 | Classement live (as-it-stands) | M/L |
| N09 | Panneau stats live : possession, tirs, xG, cartons | M |
| N10 | Timeline buts/cartons/remplacements | M |
| N11 | Radar blessures/suspensions | M |
| N12 | Fil d'actus ESPN de mes équipes | S/M |
| N17 | Bandeau calendrier 10 jours | S/M |

## Proposé — personnalisation

| ID | Feature | Effort |
|---|---|---|
| N13 | Joueur suivi (stats, buts, notif) | M/L |
| N14 | Coupes nationales + football féminin | M |
| N15 | Rivaux choisis explicitement | S/M |
| N16 | Page équipe (toutes compétitions, forme, buteurs) | L |
| N18 | Partage/export : carte match en texte, lien de sélection, import/export JSON | S |
| N19 | Thème/accent par équipe | S |

## Proposé — fiabilité, accessibilité, énergie

| ID | Feature | Effort |
|---|---|---|
| N20 | Budget data + « réessayer » ciblé par source | S/M |
| N21 | Langues ES/DE/IT/PT + dynamic type | M |
| N22 | Mode daltonien : zones et live écrits | S |
| N23 | Préchargement programmé (06:00) + 30 s seulement en live | S |
| N24 | Fusion anti-doublons + reports/annulations/tirs au but complets | M |

## Rappel des enablers

- **I18** listes lazy (refactor d'écran + validation device).
- **I33** mesures device (décharge batterie, ADB requis).
