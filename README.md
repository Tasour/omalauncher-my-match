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
- Widget original et version optimisée : [`widget/my-match.owl`](widget/my-match.owl) (v5.7) et [`widget/my-match.optimized.owl`](widget/my-match.optimized.owl) (v5.16.2).

## Audits datés et traçabilité

| Date | Version | Rapport | Portée | Validation |
|---|---|---|---|---|
| 2026-10-25 | v5.7 / v5.8 | [`docs/audit-my-match.html`](docs/audit-my-match.html) | Audit initial data/OWL/sécurité/fonctionnel + mesures | `owl-check`, scripts, fixtures, mesures device v5.7/v5.8 |
| 2026-10-28 | v5.9.8 | [`docs/audit-multi-expert-my-matches-2026-10-28.html`](docs/audit-multi-expert-my-matches-2026-10-28.html) | Audit 360° : 17 expertises, 66 constats, cycle en V, RTM, F01–F32 | `owl-check`, 5 scripts `bash -n`, fixtures ; device v5.9.8 non exécuté |

La matrice **« Features & versions »** du rapport du 28/10 est la référence datée pour distinguer ce qui est *implémenté*, *testé* et *validé*. Elle contient aussi les cases volontairement non exécutées.

Le suivi d'implémentation du lot **v5.10.0** est dans [`docs/improvements-2026-10-28.md`](docs/improvements-2026-10-28.md) : une amélioration = un commit poussé + un test de continuité. `showTables` est persisté ; `showSettings` reste volontairement limité à la session pour ne pas rouvrir les réglages à chaque redémarrage.

## Structure

```
docs/        audits, cycle en V, notice de données, modèle CI, propositions de features
widget/      my-match.owl original + version optimisée
measurements/ avant/après (CPU, fps, réseau, batterie)
scripts/     mesure, CI, extraction des scripts du widget
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
- [x] I12 : métadonnées de cache (schéma/version/TTL/expiration) et validation à la lecture
- [x] I13 : téléchargements d'écussons atomiques et verrouillés (temp privé + lock par fichier)
- [x] I14 : backoff/Retry-After, jitter par source et fixtures 429/5xx/offline/tronqué
- [x] I15 : `liveM` conditionnel hors fenêtre de match (plus de shell/jq chaque minute)
- [x] I16–I17 : rounds ESPN préférés ; reports/annulations explicites (agrégats aller/retour restant)
- [x] I19, I21–I24 : classements à la demande, zones/live textuels, plancher typo, largeurs dynamiques, minimum 5×4
- [x] I20 (partiel) : libellés d'écussons ; contrôles Canvas à convertir
- [x] I25–I29 : base dérivée d'allMine, clés stables, tests sources/pannes/concurrence
- [x] I31 (partiel) : langue initiale depuis Android ; réglages secondaires persistés
- [x] I32 : LICENSE MIT + notice de données/attribution ESPN
- [x] I33 (partiel) : preuves hors appareil + protocole ; décharge device non exécutée
- [x] Réglages « à propos / données » : attribution ESPN, diagnostic copiable, effacement des caches en deux temps
- [x] I30 : extracteur `scripts/dump-widget-scripts.sh` (revue/shellcheck, mono-fichier conservé)
- [ ] I18 : listes lazy (refactor d'écran + validation device)
- [x] N01 : Goal Flash — notification à chaque but de mes équipes
- [x] N04 : mode anti-spoiler (scores et pastilles V/N/D masqués)
- [x] N07 : forme H2H des 5 dernières confrontations dans la carte du prochain match
- [x] 20 features F01–F20 : rappels intelligents, digests, matchday/compact, aujourd'hui, cotes/forme, partage, accent équipe, daltonien, révélation, préchargement, dédup, AET/PEN, calendrier, dernier H2H
- [x] Fiche match : stade/arbitre, stats, temps forts, compositions, actus ESPN
- [x] Refonte ergonomique v5.14.0 : réglages en vue dédiée et sections, en-tête compact, libellés courts, lien Fiche dans la carte
- [ ] N02–N24 : voir [`docs/features-proposals.md`](docs/features-proposals.md)
- [ ] Mesures device v5.10.0 + test de décharge

## Sécurité

Aucun secret, token ou donnée personnelle ne doit être publié. Le widget et les rapports sont vérifiés avant publication ; les versions complètes non assainies restent en local.

Les écussons de **bannière** sont mis en cache en **160×160** dans `~/.cache/espn-logos/banner/` (les listes gardent le cache 48 px) ; les anciens fichiers trop petits sont remplacés automatiquement.

Les scripts de mesure ne contiennent plus d'adresse LAN : ils lisent `OMA_BASE` ou, à défaut, `~/.config/omalauncher/measure-base` (une ligne, ex. `http://<IP-DU-PC>:1764`), puis retombent sur `http://127.0.0.1:1764`. L'hôte est validé (`http(s)://` + caractères sûrs) avant usage.

## Données & attribution

Les scores, classements, calendriers, cotes et écussons viennent de l'API publique **ESPN** (`site.api.espn.com`, `a.espncdn.com`). Le widget n'est ni affilié, ni sponsorisé, ni approuvé par ESPN : les données, logos et marques restent la propriété d'ESPN et de leurs ayants droit. Aucune donnée personnelle n'est envoyée ; seuls des caches publics sont conservés sous `~/.cache/espn-*`.

Détail des données stockées, absence d'affiliation, effacement (`rm -rf ~/.cache/espn-*`, réglages) et précautions d'usage : [`docs/data-notice.md`](docs/data-notice.md).

## Tests et CI

- `make test` (ou `./tests/run.sh`) : `bash -n` des scripts extraits du widget, fixtures ESPN hors ligne, garde-fous statiques des améliorations.
- `scripts/ci.sh` : point d'entrée portable (compilation Python + `tests/run.sh`), utilisable par n'importe quel runner.
- `.github/workflows/ci.yml` est fourni comme modèle dans [`docs/ci-workflow.yml`](docs/ci-workflow.yml) : le copier après avoir accordé le scope `workflow` au token (`gh auth refresh -s workflow`). Sans ce scope, GitHub refuse tout push qui crée un workflow.

## Licence

Le code du widget est sous licence **MIT** — voir [`LICENSE`](LICENSE) (copyright © 2026 Tasour). La licence MIT couvre uniquement le code du widget, **pas** les données, logos ni marques ESPN, détaillés dans [`docs/data-notice.md`](docs/data-notice.md). Le code d'Omalauncher est lui aussi sous MIT.
