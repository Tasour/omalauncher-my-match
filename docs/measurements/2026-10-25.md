# Mesures device — my-match v5.7 vs v5.8

**Date** : 2026-10-25, 22:19–22:27 (Europe/Paris)
**Téléphone** : Xiaomi 11T Pro (`2107113SG`), Android 14, Omalauncher 0.12.0
**Widget** : `shared-my-matches-football.owl` (même nom de fichier, même page)
**Protocole** : wrappers `curl` et `jq` dans le shell invité, 90 s de démarrage puis 120 s de régime stable par version, écran d'accueil visible, téléphone branché (`stay_on_while_plugged_in=15`).
**Données brutes** : `measurements/guest-20261025-222720.txt` (881 Ko, local, non versionné).

## Résultat principal

| Métrique | v5.7 | v5.8 | Écart |
|---|---:|---:|---:|
| `curl` — burst initial 90 s | **222** | **221** | -0,5 % |
| `jq` — burst initial 90 s | **733** | **462** | **-37 %** |
| `curl` — régime stable 120 s | **165** | **0** | **-100 %** |
| `jq` — régime stable 120 s | **323** | **8** | **-97,5 %** |
| `curl` / min stable | **82,5** | **0** | **-100 %** |
| `curl` / h stable (extrapolé) | **~4 950** | **0** | **-100 %** |
| `jq` / min stable | **161,5** | **4** | **-97,5 %** |

## Détail par type d'appel

### v5.7 — régime stable (120 s)

- `scoreboard` : **155** appels
- `standings` : **10** appels
- Ligues vues : `eng.1`, `esp.1`, `ger.1`, `ita.1`, `fra.1`, `fra.2`, `uefa.champions`, `uefa.europa`, `uefa.europa.conf`, `uefa.nations`, `fifa.worldq.uefa`, `fifa.friendly`.
- Le polling permanent des 28 ligues par `liveM` (toutes les minutes) domine ; le burst initial de `games`/`standings`/`teams` déborde même sur le début du régime stable.

### v5.8 — régime stable (120 s)

- `scoreboard` : **0**
- `standings` : **0**
- `curl` : **0**
- `jq` : **8** (lecture du cache d'index, sans requête réseau)
- Aucun match live pendant la fenêtre : le gate `liveM` renvoie le cache et ne fait aucun appel.

### v5.8 — burst initial (90 s)

- `scoreboard` : 175
- `standings` : 12
- `teams` : 34
- Les équipes suivies couvrent encore beaucoup de ligues : la liste dynamique reste large au premier chargement. Le burst initial est donc proche de v5.7 (221 vs 222 `curl`), mais avec **37 % de `jq` en moins**.

## Interprétation

1. **Le gain principal est le régime stable**, celui qui vide la batterie : v5.7 fait **82,5 `curl`/min** en continu (~4 950/h), v5.8 tombe à **0 `curl`/min** quand aucun match n'est live.
2. **Le burst initial reste à ~221 `curl`**, une fois par chargement du widget. Il est dominé par `games`/`standings`/`teams` et par le grand nombre de ligues des équipes suivies. C'est le prochain axe : lazy-load des onglets non visibles et cache du premier `games` entre deux chargements.
3. **L'estimation code de l'audit (502 → 41 req/h) était trop basse pour v5.7** : la mesure réelle du régime stable est ~4 950 `curl`/h. Elle était aussi trop pessimiste pour v5.8 en régime stable (0 `curl`/h sans live). La conclusion — suppression du polling permanent — est confirmée, et même renforcée.
4. **v5.8 est bien la version active à la fin de la mesure** : le script réinstalle v5.8 avant de poster, et la fenêtre « after » ne fait aucun `curl`.

## Limites

- Le shell invité n'a pas accès à `/proc/net/dev` (`Permission denied`) : les octets réseau n'ont pas pu être mesurés depuis le guest. Les compteurs `curl`/`jq` sont exacts.
- La mesure couvre 2 min de régime stable ; elle est suffisante pour le polling `liveM` (1 min) mais pas pour les sources à 6 h/12 h/24 h.
- Le burst initial dépend du nombre de ligues des équipes suivies ; il variera avec la liste `myTeams`.

## Fichiers

- `scripts/guest-ab-wrapper.sh` — script A/B embarqué (wrappers + fenêtres).
- `scripts/collect-server.py` — collecteur HTTP local (port 1764).
- `widget/ab-wrapper.owl` — widget déclencheur (à retirer après usage).
- `measurements/guest-20261025-222720.txt` — données brutes.

## Correctif v5.9.1 (25/10/2026, après la mesure)

Deux régressions de v5.8 ont été trouvées sur le téléphone par `owl-check` :

- les affectations `WANT`/`WANTID`/`WANTNOTID`/`WANTLG` étaient collées par le compilateur OWL (le retour à la ligne en tête de morceau de chaîne est supprimé), ce qui cassait `games`/`seasonAll` (`bash: syntax error near unexpected token 'then'`) ;
- le cache `games` écrivait un `.ok` même sur une réponse ESPN invalide, et `SIG` n'incluait pas `WANTLG` : le cache pouvait rester vide/empoisonné.

v5.9.1 corrige : points-virgules après chaque affectation, validation `has("events") or has("leagues")` avant d'écrire le cache, `SIG` avec `WANTLG`, refetch des fichiers de cache vides, fallback `favLg` si une équipe n'a pas de `league`.

Tests : `make test` / `./tests/run.sh` (owl, `bash -n` sur `games`/`season`/`standings`/`forms`/`live`, fixtures ESPN, cache anti-poison, `SIG`, `favLg`, `sh()`, gate `liveM`). Les chiffres de la mesure v5.8 restent valides pour le régime stable ; v5.9.1 est la version installée.
