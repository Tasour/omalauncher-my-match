# omalauncher-my-match

Audit de qualité, réécriture optimisée et mesures avant/après du widget **my-match** pour [Omalauncher](https://github.com/SimonSchubert/omalauncher).

## Contexte

- Appareil de référence : Xiaomi 11T Pro (`vili`), Android 14, Snapdragon 888.
- Omalauncher installé : 0.12.0 (build Play du 24/10/2026).
- Dépôt upstream analysé : `SimonSchubert/omalauncher`, branche `main` (commit `916b318` au moment de l'audit initial).
- Audit énergétique initial : [`docs/audit-omalauncher-2026-10-25.html`](docs/audit-omalauncher-2026-10-25.html).

## Objectif

1. Vérifier par la mesure si `my-match` est bien la première source des problèmes de performance et de batterie.
2. Auditer le code du widget avec plusieurs experts (code/OWL, data/API, performance, structure, sécurité, UX).
3. Réécrire le widget **à fonctionnalités identiques**, mais sans les coûts inutiles (proot/curl/jq, requêtes massives, téléchargements de logos, animations continues).
4. Prouver le gain par des mesures avant/après et un test de décharge débranché.

## Méthode

- Document **cycle en V** complet de l'app : [`docs/cycle-en-v-omalauncher.html`](docs/cycle-en-v-omalauncher.html).
- Audit multi-agents du widget : [`docs/audit-my-match.html`](docs/audit-my-match.html) (à venir).
- Mesures brutes : [`measurements/`](measurements/).
- Widget original et version optimisée : [`widget/`](widget/).

## Structure

```
docs/        audit initial, cycle en V, audit du widget
widget/      my-match.owl original + version optimisée
measurements/ avant/après (CPU, fps, réseau, batterie)
scripts/     protocole de mesure reproductible
```

## Statut

- [x] Audit initial ajouté au dépôt
- [ ] Document cycle en V
- [ ] Récupération du source `my-match`
- [ ] Audit multi-agents
- [ ] Réécriture iso-fonctionnelle
- [ ] Mesures avant/après + test de décharge

## Sécurité

Aucun secret, token ou donnée personnelle ne doit être publié. Le widget et les rapports sont vérifiés avant publication ; les versions complètes non assainies restent en local.

## Licence

À définir selon la licence du widget original. Le code d'Omalauncher est sous MIT.
