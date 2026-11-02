# Trajectoire xG — réflexion, lecture et design

## Décision

Le graphique compare, pour une équipe, deux séries lissées sur **5 matchs** et
affichées sur les **20 derniers matchs** :

- **trait plein** : différence de buts réelle, `G − encaissés` ;
- **trait pointillé** : différence attendue, `xG − xG encaissés` (`xGD`).

Le second trait n'est pas `G − xGA`. Ce mélange entre attaque réelle et défense
attendue n'est pas une différence de référence : les deux courbes partageraient
`G` et leur écart ne mesurerait plus que la différence entre buts encaissés et
xGA. La comparaison qui rend le croisement interprétable est **buts réels contre
buts attendus**, des deux côtés du terrain.

## Ce que dit la recherche

- Les rolling xG sont utilisés pour suivre la tendance récente plutôt que la
  moyenne de saison, qui mélange trop de régimes de jeu
  (SoccerAnalytics, *Build a Rolling xG Form Chart*).
- StatsBomb présente le xGD comme un des meilleurs indicateurs publics de
  performance future et montre des exemples où les courbes attaque/défense se
  croisent avant les changements de discours ou de manager
  (*Trend-ing Topics*, 2017).
- StatsBomb rappelle aussi que le xGD est plus stable que le goal difference
  sur petits échantillons, mais que les écarts entre buts et xG peuvent être
  de la finition, du gardien, de la chance ou un mélange des trois
  (*Arsenal Aren't This Good*, 2018).
- Soccermatics recommande de ne pas surinterpréter 1–2 matchs, de lire 3–6
  matchs comme un signal, et 7–16 matchs comme une fenêtre sérieuse. Une
  fenêtre de 5 est volontairement réactive ; elle doit être confirmée.
- FootyMetrics insiste sur la régression vers la moyenne : un écart buts/xG
  sur quelques matchs est souvent du bruit, mais une partie peut être réelle.
- FinalSkore et xGstat proposent la même lecture : comparer le réel à
  l'attendu, puis regarder si les deux lectures se confirment.

## Définitions

| Élément | Calcul | Sens |
|---|---|---|
| Réel | `(buts marqués − buts encaissés)` moyen sur 5 | Résultat effectif |
| Attendu | `(xG − xGA)` moyen sur 5 | Qualité des occasions créées et concédées |
| Écart | `réel − attendu` | Finition + gardien + variance |
| Tendance | variation du xGD sur les 5 derniers points | Accélération ou retournement |

## Lecture en quatre temps

1. **Position par rapport à zéro.** Au-dessus : l'équipe domine ses matchs.
   En dessous : elle est dominée. Le pointillé est le plus important pour le
   fond de jeu ; le plein est le plus important pour les points.
2. **Pente.** Une pente qui monte signifie que la performance récente s'améliore
   par rapport aux matchs plus anciens. Une pente qui descend alerte.
3. **Écart réel/attendu.** Réel au-dessus : finition ou gardien en avance,
   souvent non soutenable. Réel en dessous : résultats en retard sur le jeu.
4. **Croisement.** Un croisement localise un changement de régime. Il ne prouve
   pas une crise : il faut regarder le niveau absolu et la durée.

## Matrice de lecture

| Réel | Attendu | Lecture |
|---|---|---|
| > 0 | > 0 | Solide : résultats et fond de jeu se confirment |
| < 0 | > 0 | Sous-performance : les résultats sont en retard sur le jeu |
| > 0 | < 0 | Résultats trompeurs : le réel masque un fond de jeu fragile |
| < 0 | < 0 | Alerte : les deux courbes sont négatives |
| réel décroche sous attendu | < 0 | Alerte renforcée : la défense ou la finition lâche |

**Réponse à la question « les lignes se croisent, donc crise ? »** : non, pas
automatiquement. Un croisement est un **changement de régime**. La crise devient
un scénario crédible quand le xGD est durablement sous zéro **et** que le réel
décroche sous l'attendu. L'app affiche « Alerte crise » seulement dans ce cas ;
le texte précise toujours qu'il s'agit d'un signal, pas d'un verdict.

## Choix visuels

- **20 points** : assez de contexte pour voir un retournement, pas seulement les
  5 derniers matchs.
- **Fenêtre 5** : réactive, lisible, et cohérente avec les autres blocs de l'app.
- **Axe symétrique autour de zéro** : les deux lignes sont comparables et le
  passage au-dessus/en dessous de zéro se lit immédiatement.
- **Plein contre pointillé** : distinction lisible sans ajouter de couleur
  concurrente.
- **Ruban vert/rouge entre les courbes** : le vert signale le réel au-dessus de
  l'attendu, le rouge l'inverse ; le croisement devient un point de bascule.
- **Marqueurs de croisement** : date et direction, sans prétendre prédire.
- **Cartes de synthèse** : réel, attendu, écart, tendance pour chaque équipe,
  avec un badge de signal.
- **Pas d'animation** : le graphique doit rester lisible et ne pas consommer de
  batterie pour un effet décoratif.

## Données et limites

- Understat fournit 20 matchs avec xG pour les cinq grands championnats ; c'est
  la source utilisée dès qu'elle est disponible.
- Football-Data reste le fallback (Ligue 2, ou équipe absente d'Understat) et ne
  fournit alors que les matchs avec xG de la saison en cours.
- Les fenêtres glissantes se chevauchent : les points ne sont pas indépendants.
- Le xG dépend du modèle : ne pas additionner Understat et Football-Data comme
  s'il s'agissait du même chiffre.
- Le calendrier, les cartons, les pénos et l'adversaire ne sont pas neutralisés.
- Un signal de 5 matchs est un signal court ; il doit être confirmé.

## Sources

- SoccerAnalytics, *Build a Rolling xG Form Chart in Python* :
  https://socceranalytics.net/articles/build-a-rolling-xg-form-chart.html
- StatsBomb, *Trend-ing Topics* :
  https://blogarchive.statsbomb.com/articles/soccer/trend-ing-topics-how-basic-data-vis-can-show-incredibly-important-football-info/
- StatsBomb, *Arsenal Aren't This Good. Nor Are Dortmund.* :
  https://blogarchive.statsbomb.com/articles/soccer/arsenal-arent-this-good-nor-are-dortmund-heres-why/
- Soccermatics, *History and application of xG* :
  https://soccermatics.readthedocs.io/en/latest/lesson2/MoreonxG.html
- FootyMetrics, *Goals vs xG: overperformance and regression* :
  https://www.footymetrics.com/learn/goals-vs-xg-overperformance
- FinalSkore, *xG for, xG against, and regression* :
  https://www.finalskore.com/en/education/football-reading-the-game/xg-for-and-against
- xGstat, *Goal Difference versus Expected* :
  https://www.xgstat.com/learn/goal-difference-versus-expected
