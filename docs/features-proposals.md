# Nouvelles features — propositions

Catalogue proposé le 2026-10-30. Les lignes **Fait** sont implémentées et
poussées ; les autres attendent une décision.

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
