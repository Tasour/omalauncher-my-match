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
- Audit multi-agents initial : [`docs/audit-my-match.html`](docs/audit-my-match.html) — rapports détaillés dans [`docs/audit/`](docs/audit/).
- Audit multi-expert 360° v5.9.8 (28/10/2026) : [`docs/audit-multi-expert-my-matches-2026-10-28.html`](docs/audit-multi-expert-my-matches-2026-10-28.html) — 17 expertises, 66 constats, cycle en V, RTM, registre des features et de validation.
- Mesures brutes : [`measurements/`](measurements/).
- Widget original et version optimisée : [`widget/my-match.owl`](widget/my-match.owl) (v5.7) et [`widget/my-match.optimized.owl`](widget/my-match.optimized.owl) (v5.10.0 en cours).

## Audits datés et traçabilité

| Date | Version | Rapport | Portée | Validation |
|---|---|---|---|---|
| 2026-10-25 | v5.7 / v5.8 | [`docs/audit-my-match.html`](docs/audit-my-match.html) | Audit initial data/OWL/sécurité/fonctionnel + mesures | `owl-check`, scripts, fixtures, mesures device v5.7/v5.8 |
| 2026-10-28 | v5.9.8 | [`docs/audit-multi-expert-my-matches-2026-10-28.html`](docs/audit-multi-expert-my-matches-2026-10-28.html) | Audit 360° : 17 expertises, 66 constats, cycle en V, RTM, F01–F32 | `owl-check`, 5 scripts `bash -n`, fixtures ; device v5.9.8 non exécuté |

La matrice **« Features & versions »** du rapport du 28/10 est la référence datée pour distinguer ce qui est *implémenté*, *testé* et *validé*. Elle contient aussi les cases volontairement non exécutées.

Le suivi d'implémentation du lot **v5.10.0** est dans [`docs/improvements-2026-10-28.md`](docs/improvements-2026-10-28.md) : une amélioration = un commit poussé + un test de continuité. `showTables` est persisté ; `showSettings` reste volontairement limité à la session pour ne pas rouvrir les réglages à chaque redémarrage.

## Structure

```
docs/        audit initial, cycle en V, audit du widget, modèle CI
widget/      my-match.owl original + version optimisée
measurements/ avant/après (CPU, fps, réseau, batterie)
scripts/     protocole de mesure reproductible + scripts/ci.sh
tests/       fixtures ESPN, faux curl, garde-fous statiques
```

## Statut

- [x] Repo public créé
- [x] Audit initial ajouté au dépôt
- [x] Document cycle en V
- [x] Récupération du source `my-match` (v5.7, 1 955 lignes)
- [x] Audit multi-agents (data, OWL/UI, sécurité, fonctionnalités)
- [x] Réécriture iso-fonctionnelle (v5.8, `owl check` OK)
- [x] Correctif v5.9.2 : bannière mise à jour (fusion `extra`/`games`/`seasonAll`, états `pre` périmés ignorés, formes du bandeau)
- [x] v5.9.8 : cotes affichées instantanément depuis un cache `current.json` lu par une source `file` (plus de clignotement au refresh) ; cache par match mis à jour en arrière-plan, date/heure corrigées ; 5 formes pour les deux équipes, ordre ancien → récent
- [x] Audit multi-expert 360° v5.9.8 (28/10/2026) : 17 expertises, 66 constats, 0 P0, 14 P1 ouverts, cycle en V et registre de validation
- [x] Lot v5.10.0 (I01–I10) : durcissement curl, IP LAN retirée, i18n, `showTables` persisté, tuile bornée, périmètre `standings` réduit, timeouts alignés, `status` + santé visible, spinner conditionnel, harnais CI portable
- [x] Revue experte v5.10.0 (UI/UX, OWL, sécurité/SRE) et correctifs associés
- [x] I11 : couverture rivaux/historique dérivée des équipes suivies (plus de liste blanche de ligues)
- [ ] Mesures device v5.10.0 + test de décharge

## Sécurité

Aucun secret, token ou donnée personnelle ne doit être publié. Le widget et les rapports sont vérifiés avant publication ; les versions complètes non assainies restent en local.

Les scripts de mesure ne contiennent plus d'adresse LAN : ils lisent `OMA_BASE` ou, à défaut, `~/.config/omalauncher/measure-base` (une ligne, ex. `http://<IP-DU-PC>:1764`), puis retombent sur `http://127.0.0.1:1764`. L'hôte est validé (`http(s)://` + caractères sûrs) avant usage.

## Tests et CI

- `make test` (ou `./tests/run.sh`) : `bash -n` des scripts extraits du widget, fixtures ESPN hors ligne, garde-fous statiques des améliorations.
- `scripts/ci.sh` : point d'entrée portable (compilation Python + `tests/run.sh`), utilisable par n'importe quel runner.
- `.github/workflows/ci.yml` est fourni comme modèle dans [`docs/ci-workflow.yml`](docs/ci-workflow.yml) : le copier après avoir accordé le scope `workflow` au token (`gh auth refresh -s workflow`). Sans ce scope, GitHub refuse tout push qui crée un workflow.

## Licence

À définir selon la licence du widget original. Le code d'Omalauncher est sous MIT.
