# Nouvelles features — propositions

Catalogue proposé le 2026-10-30. Les lignes **Fait** sont implémentées et
poussées ; les autres attendent une décision.

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
