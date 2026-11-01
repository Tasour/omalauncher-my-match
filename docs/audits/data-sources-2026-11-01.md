# Audit sources de données football — 2026-11-01

Objectif : ajouter des données gratuites sans dégrader la fiabilité de
l’avant-match. Trois étapes : **isoler** chaque source, **synchroniser** avec
ESPN, puis **étudier les features** possibles.

## 1. Football-Data.co.uk

### Ce que la source donne

- CSV libres, sans clé : `https://www.football-data.co.uk/mmz4281/<saison>/<division>.csv`
  (ex. `2627/E0.csv` pour la Premier League 2026/27).
- 22 divisions européennes, résultats depuis 1993/94, cotes et stats depuis
  2000/01.
- Le fichier courant contient déjà : `HxG`, `AxG`, tirs, tirs cadrés, corners,
  fautes, cartons, arbitre, cotes ouverture/fermeture, total buts et handicap.
  Vérifié sur `2627/E0.csv` : les colonnes `HxG` et `AxG` sont présentes.
- Mise à jour environ deux fois par semaine (dimanche et mercredi), pas en direct.

### Limites à isoler

- Pas d’identifiants : uniquement des noms (`Man United`, `Nott'm Forest`,
  `Ath Madrid`, `Sp Gijon`…). Les noms changent parfois entre divisions/saisons.
- Pas de live, pas de compos, pas de blessures, pas de coup d’envoi fiable pour
  tous les pays. Les heures sont locales, sans fuseau explicite.
- Les coupes ne sont pas couvertes de façon fiable : ne pas l’utiliser pour les
  arbres de coupe.
- Les cotes Pinnacle sont signalées comme peu fiables depuis juillet 2025 ;
  ne pas les utiliser pour un consensus.
- Le xG de Football-Data est **son** modèle : ne jamais l’additionner ou le
  comparer comme s’il venait d’Understat/StatsBomb.

### Isolation

```
~/.cache/fd/
  2627/E0.csv
  2627/E0.csv.meta       # source_url, fetched_at, sha256, season, division, rows
  2627/F1.csv …
```

- Écrire le brut, ne jamais l’éditer.
- Un fichier `.meta` avec URL, date, SHA-256, lignes, saison.
- Télécharger au plus 2 fois/jour ; comparer le SHA avant de recalculer.
- Ne lire ces fichiers que par un adaptateur `fd_*`, pas directement dans l’UI.

### Synchronisation avec ESPN

- Clé de match : `(league, canonical_home, canonical_away, date)` avec une
  tolérance de **±1 jour** et jamais deux matchs dans la même fenêtre.
- Les noms passent par une table canonique (voir § 3).
- ESPN reste la source du **live, des fixtures et des compos**.
- Football-Data ne remplit que les matchs **terminés** et les champs
  `xG`, tirs, cartons, arbitre, cotes historiques.
- Aucun match futur de Football-Data ne doit écraser une fixture ESPN.
- Les cotes Football-Data ne sont pas fusionnées avec les cotes ESPN : deux
  blocs distincts, avec provenance et horodatage.

## 2. ClubElo

### Ce que la source donne

- API CSV publique : `http://api.clubelo.com/YYYY-MM-DD` (classement Elo d’un
  jour), `http://api.clubelo.com/<club>` (historique d’un club).
- Champs : `Rank, Club, Country, Level, Elo, From, To`.
- Historique depuis 1939 (fiable surtout après 1960), couverture clubs européens.
- Utilisable pour force, probabilité et forme ajustée à l’adversaire.

### Limites observées

- L’endpoint `Fixtures` est annoncé **désactivé** (`Fixtures API deactivated`).
- Lors de l’audit, `2026-11-01`, `Arsenal` et `Fixtures` n’ont renvoyé aucune
  donnée exploitable (Cloudflare/disponibilité). L’intégration doit donc être
  **non bloquante**, avec cache et fallback.
- Pas de clé ni de quota documentés ; rester très conservateur (1 lecture/jour).
- Noms de clubs spécifiques (`Man City`, `FC Bayern`, etc.), sans identifiant
  ESPN.
- Pas de matchs, pas de compos, pas de cotes : uniquement des ratings.

### Isolation

```
~/.cache/clubelo/
  2026-11-01.csv
  2026-11-01.csv.meta   # url, fetched_at, sha256, rows
  clubs/Arsenal.csv
```

- Snapshot quotidien du classement, historique par club seulement si demandé.
- Un cache as-of daté : une note Elo n’est valide que pour la date du snapshot.
- Si l’API échoue, garder le dernier snapshot et afficher son âge.

### Synchronisation

- Associer `ClubElo.Club` à l’équipe canonique via la table manuelle.
- Pour un match à venir : utiliser le rating **strictement avant** le coup
  d’envoi (date J-1 ou dernier snapshot ≤ J-1). Interdiction d’utiliser un
  rating publié après le match.
- Elo ne remplace pas le classement ESPN : il fournit une force indépendante.
- Afficher la provenance et la date du rating.

## 3. Table canonique des équipes

Fichier proposé : `~/.cache/football/canonical-teams.json`.

```json
{
  "espn:167": {
    "espn_id": "167",
    "espn_abbr": "LYON",
    "name": "Olympique Lyonnais",
    "country": "FRA",
    "aliases": ["Lyon", "Olympique Lyonnais", "OL"],
    "football_data": ["Lyon"],
    "clubelo": ["Lyon"]
  }
}
```

Règles :

1. La clé primaire est l’identifiant ESPN quand il existe.
2. Les alias sont normalisés : accents retirés, apostrophes et espaces
   uniformisés, suffixes (`FC`, `AC`, `CF`) conservés dans une liste d’alias.
3. Aucun rapprochement automatique dangereux (`Paris` ≠ `Paris FC`).
4. Les cas ambigus restent non mappés et sont signalés ; on préfère une valeur
   manquante à une valeur fausse.
5. Les clubs sans identifiant ESPN reçoivent un identifiant `canonical:<slug>`
   et ne sont pas utilisés dans les comparaisons avec les données ESPN.

## 4. Modèle normalisé et provenance

Deux couches seulement :

- **brut** : `~/.cache/fd`, `~/.cache/clubelo` (immuable, daté).
- **normalisé** : `~/.cache/football/normalized/`
  - `teams.json`
  - `matches.jsonl` : `id`, `league`, `season`, `home_id`, `away_id`,
    `kickoff_utc`, `status`, `sources: {espn, fd}`
  - `team_metrics.json` : `team_id`, `as_of`, `source`, `xg_for`, `xg_against`,
    `elo`, …

Chaque champ dérivé porte :

```json
{"value": 1.75, "source": "fd", "as_of": "2026-11-01", "sample": 8}
```

Règles :

- Une valeur sans `source`, `as_of` et `sample` n’est pas affichable.
- Un match ne peut pas avoir deux sources pour le **même champ** sans arbitrage
  explicite.
- Le xG FD et le xG Understat/StatsBomb ne se mélangent jamais.
- Les cotes ouverture/fermeture gardent leur bookmaker et leur horodatage.

## 5. Règles de synchronisation

| Donnée | Source maître | Secours | Règle |
|---|---|---|---|
| Live, score, minute | ESPN | — | jamais FD |
| Fixtures, horaires | ESPN | — | FD ne écrit pas le futur |
| Résultats terminés | ESPN | FD | FD seulement si ESPN absent |
| xG, tirs, cartons | FD | — | matchs terminés uniquement |
| Arbitre | FD | ESPN | FD en historique |
| Classement | ESPN | — | ClubElo ne remplace pas |
| Force Elo | ClubElo | aucun | rating avant match |
| Cotes live | ESPN | — | pas de mélange |
| Cotes historiques | FD | — | pour backtests uniquement |
| Compos, blessures | API-Football (futur) | ESPN | jamais FD |
| Météo, voyage | Open-Meteo, OSM | — | sans impact sur le score |

Contrôles avant publication :

1. Même compétition et même saison.
2. Écart de date ≤ 1 jour.
3. Exactement une équipe canonique par côté.
4. Scores FD cohérents avec le résultat ESPN quand les deux existent.
5. Pas de valeur après le coup d’envoi dans un champ pré-match.
6. Couverture des alias : un club non mappé est exclu, pas deviné.

## 6. Features possibles

### xG / qualité de chances (Football-Data)

- xG et xGA sur 5/10 matchs, à domicile/extérieur.
- xPts : points attendus à partir des xG (simulation ou formule Poisson).
- Écart finition : buts réels − xG ; sur/sous-performance.
- Qualité des tirs : tirs cadrés, précision, volume.
- Probabilités : plus/moins 2,5, BTTS, clean sheet, à partir d’un modèle
  Poisson ajusté aux xG.
- Forme ajustée à l’adversaire : pondérer chaque match par l’Elo de l’adversaire.
- Backtest : comparer xPts au classement réel et aux cotes FD.

### Elo (ClubElo)

- Probabilité 1/N/2 à partir de l’écart Elo (modèle logistique calibré).
- Points attendus sur les 5 prochains matchs.
- Indice d’upset : écart Elo + forme + domicile.
- Force ajustée : performance récente pondérée par l’Elo adverse.
- Simulation de fin de saison (Monte Carlo) pour titre/C1/rélegation.
- Affichage « force » indépendant du classement ESPN.

### Arbitre et discipline (FD)

- Cartons par match, fautes par carton, penaltys.
- Profil arbitre : moyenne cartons, tendance derby.
- Feature « match haché » : fautes + cartons + arbitre.

### Cotes (FD historique)

- Ouverture → fermeture, no-vig, mouvement.
- CLV (closing line value) pour backtests.
- Modèle vs marché : écart xPts/probabilité Elo vs cotes.
- Toujours indicatif, sans conseil de pari.

### Voyage / contexte (Open-Meteo, OSM/Wikidata)

- Distance et temps de trajet, fuseau du stade.
- Météo au coup d’envoi (pluie, vent, température).
- Repos et enchaînement des matchs.

### Effectif (API-Football, phase ultérieure)

- Compos confirmées, blessés, suspendus.
- Impact d’une absence sur xG/xGA.
- Risque de suspension (cartons).

## 7. Priorisation

| Feature | Valeur | Effort | Risque data |
|---|---:|---:|---|
| xG/xGA 5 matchs | haute | moyen | faible (FD) |
| xPts / écart finition | haute | moyen | moyen |
| Elo / probabilité | haute | moyen | moyen (mapping) |
| Force ajustée | haute | moyen | moyen |
| Arbitre/cartons | moyenne | faible | faible |
| Cotes historiques/CLV | moyenne | moyen | moyen |
| Météo/travel | moyenne | faible | faible |
| Compos/blessures | très haute | élevé | élevé (quota) |

## 8. Roadmap proposée

1. **Sprint A — isolement FD** : téléchargement, cache brut, mapping top 5,
   parse xG/tirs/cartons/arbitre, tests de non-régression.
2. **Sprint B — Elo** : snapshot quotidien, mapping clubs, rating as-of,
   probabilités et force ajustée.
3. **Sprint C — affichage** : xG/xGA, xPts, finition, probabilités, avec
   provenance et échantillon.
4. **Sprint D — validation** : backtests sur 3 saisons FD, calibration Elo,
   contrôle des jointures et des doublons.
5. **Sprint E — extensions** : météo, voyage, puis API-Football pour les compos
   si le quota et la licence sont acceptés.

## 9. Critères d’acceptation

- 0 match joint sur un nom ambigu ; les non-mappés sont signalés.
- 100 % des champs dérivés ont source, date et échantillon.
- 0 valeur post-match utilisée dans un affichage pré-match.
- 0 mélange de modèles xG ou de cotes de sources différentes.
- Couverture top 5 ≥ 95 % pour les équipes suivies.
- FD : 2 téléchargements/jour maximum ; ClubElo : 1/jour maximum.
- Si ClubElo échoue, l’app reste utilisable avec le dernier snapshot ou sans Elo.

## 10. Sources

- Football-Data : https://www.football-data.co.uk/data.php et notes.txt
- ClubElo : http://clubelo.com/API et http://api.clubelo.com/
- API-Football : https://www.api-football.com/pricing
- StatsBomb Open Data : https://github.com/statsbomb/open-data
- Understat : https://understat.com/
- TheSportsDB : https://www.thesportsdb.com/free_sports_api
- Open-Meteo : https://open-meteo.com/
- The Odds API : https://the-odds-api.com/
