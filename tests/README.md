# Tests hors ligne

Lancer après chaque modification du widget :

```sh
make test        # suite rapide (~3 min)
# ou
./tests/run.sh

make test-all    # + sources secondaires, pannes réseau, concurrence de caches (~10 min)
# ou
./tests/run-all.sh
```

## Ce qui est vérifié

- `owl check` (si `OWL_JAR` pointe vers le vérificateur ; par défaut `/tmp/opencode/owl.jar`).
- `bash -n` sur les scripts `games` et `live` extraits du `.owl`.
- Le script `games` réel, exécuté avec un faux `curl` ESPN et des fixtures :
  - liste complète de ligues (fallback) ;
  - liste dynamique `favLg` (`fra.1`, `eng.1`) ;
  - une réponse ESPN invalide ne doit pas écrire de cache `.ok` ;
  - un cache invalide ne doit pas empêcher la récupération suivante ;
  - `SIG` change quand `WANTLG` change ;
  - `sh()` empêche l'exécution de code via une apostrophe.
- Le gate `liveM` : aucun appel réseau quand aucun match n'est live.

## Fichiers

- `extract.py` : extrait un script `"""…"""` du `.owl` et remplace les `sh(fav…)` par des variables de test.
- `bin/curl` : faux `curl` (scoreboards ESPN + logos).
- `fixtures/` : réponses ESPN minimales.
- `test-games.sh` : assertions.

Aucun appel réseau n'est fait par les tests.
