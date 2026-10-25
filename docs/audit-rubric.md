# Grille d'audit my-match (multi-agents)

Chaque constat doit contenir : ID, dimension, gravité (P0/P1/P2), preuve (ligne/fichier ou mesure), impact, correctif, effort, confiance, et si la fonctionnalité est préservée.

## Dimensions

1. **Code / OWL** : syntaxe, portée des `let`, triggers, nulls, composants, version `owl`, thème, `owl-check`, lisibilité.
2. **Data / API ESPN** : endpoints, nombre de requêtes, fenêtre de dates, pagination, cache, ETag, rate limit, fuseaux/DST, schéma, logos.
3. **Performance / batterie** : CPU, fps, réveils, réseau, mémoire, comportement hors écran, risque d'orphelin, intervalle de refresh.
4. **Structure / maintenabilité** : découpage, nommage, séparation données/logique/vue, `meta`, `requires`, testabilité, documentation.
5. **Sécurité / robustesse** : injection `sh()`, secrets, données non fiables, offline, erreurs partielles, mode dégradé, partage.
6. **UX / i18n / accessibilité** : français, contrastes, textes qui débordent, états vides/erreur, cibles tactiles, thème.
7. **Red team** : API vide, 429, hors ligne, changement d'équipe, JSON énorme, données incomplètes, match annulé, DST.

## Règle d'or

**Aucune fonctionnalité retirée.** On optimise l'implémentation, pas le périmètre. Si une optimisation change un comportement visible, elle doit être proposée comme option, pas imposée.
