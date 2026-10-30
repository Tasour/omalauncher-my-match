# Mesures v5.14.0 — plan reproductible et état des preuves

> Lot audit v5.10.0 (I01–I10) + backlog I11–I33 ; widget publié en **v5.14.0** (F01–F20, fiche match, refonte ergonomique).

Audit **I33 / ENERGY-03**. Widget `my-match` **v5.10.0**.
Rédigé le **2026-10-30**. Références : `docs/measurements-2026-10-25.md`
(baseline device v5.7/v5.8), `measurements/README.md`,
`scripts/measure*.sh`, `scripts/guest-*.sh`, `scripts/collect-server.py`.

## 1. Résumé

| Élément | État au 2026-10-30 |
|---|---|
| Compilation OWL + previews | **Prouvé hors appareil** (voir §2.1) |
| Suite de tests hors ligne | **Prouvée hors appareil** (voir §2.2) |
| Modèle requêtes/timeouts | **Calculé depuis le code** (voir §3) |
| Mesure curl/jq sur téléphone | **Non exécutée — appareil requis** |
| CPU, fps, réseau, mémoire | **Non exécutée — appareil requis** |
| Décharge batterie 30–60 min | **Non exécutée — appareil requis** |

Sur la machine de rédaction, `adb devices` ne liste **aucun appareil**
(démon ADB démarré, liste vide). Aucun chiffre device v5.10.0 n'est donc
présenté ici : les colonnes v5.7/v5.8 sont les mesures du 2026-10-25, et
toute case v5.10.0 non mesurée porte explicitement
**« non exécuté (appareil requis) »**.

## 2. Ce qui est déjà prouvé hors appareil (exécuté le 2026-10-30)

### 2.1 `owl-check` : compilation et previews

Le fichier installé `~/.config/omalauncher/widgets/20-my-matches.owl` est
**identique octet pour octet** au widget du dépôt :

```text
sha256  98bb0410f64eff3c5a78af6d580bfbd89ba1d7de8cee251feb9fa5a997870530
        ~/.config/omalauncher/widgets/20-my-matches.owl
sha256  98bb0410f64eff3c5a78af6d580bfbd89ba1d7de8cee251feb9fa5a997870530
        widget/my-match.optimized.owl
version:"5.10.0"
```

Commande exécutée :

```sh
cd ~/.config/omalauncher/widgets
owl-check 20-my-matches.owl
```

Sortie réelle : `exit=0`.

```text
20-my-matches.owl: compiles
  preview: /root/.config/omalauncher/widgets/.preview/20-my-matches.owl.png
           (7x12 cells, 1046x1832 px, with live data)
  screen:  /root/.config/omalauncher/widgets/.preview/20-my-matches.owl.screen.png
           (1080x2186 px, opened full screen, with live data)
  runtime: warning: runs `fifa.friendly`, which isn't installed; ...
  runtime: warning: runs `fifa.worldq.uefa`, which isn't installed; ...
```

Les deux avertissements `runtime: warning:` sont des paquets de données
absents, pas des erreurs de compilation ; `owl-check` sort à 0. Ils étaient
déjà présents avant v5.10.0 et ne bloquent pas la mesure.

Reproductibilité : `owl-check` n'accepte que les fichiers `*.owl` directement
dans `~/.config/omalauncher/widgets`. Le dépôt est dans un sous-dossier ;
c'est pourquoi la vérification ci-dessus cible le fichier installé, après
avoir contrôlé que son SHA-256 est celui du widget du dépôt.

### 2.2 Suite de tests hors ligne

Commande exécutée :

```sh
cd /root/.config/omalauncher/widgets/omalauncher-my-match
PYTHONDONTWRITEBYTECODE=1 ./tests/run.sh
```

Résultat réel : **tous les tests passent**.

- `bash -n` : `gamesScript`, `seasonScript`, `standingsScript`,
  `liveScript`, `heroOddsScript`, `scheds`, `teamsDb`, `extra`, `knock`,
  `nextup`, `histfull` — **11/11 PASS**.
- Réseau simulé / caches : liste complète, écussons atomiques, liste
  dynamique, `eng.1`, réponse invalide non empoisonnante, reprise,
  429/5xx/offline/tronqué, repli cache, `SIG`, `sh()`, gate `liveM` —
  **PASS**.
- Périmètre ligues (`extra`, `nextup`, `histfull`) — **PASS**.
- Métadonnées de cache (schéma, expiration, repli, migration) — **PASS**.
- Garde-fous d'audit I01–I15 (curl durci, pas d'IP LAN, typographie,
  `showTables`, tuile bornée, timeouts, statut/santé, spinner, CI) —
  **PASS**.

Le `owl check` interne à `tests/run.sh` est **SKIP** car
`/tmp/opencode/owl.jar` n'existe pas sur cette machine. La compilation OWL
est couverte séparément par `owl-check` en §2.1.

### 2.3 Ce que ces preuves ne couvrent pas

- Aucun appel réseau réel vers ESPN.
- Aucune consommation CPU, mémoire, octets réseau ou batterie.
- Aucun comportement écran allumé/éteint, ni orphelins de processus invités.
- Aucune mesure du régime permanent au-delà de quelques secondes.

## 3. Modèle requêtes/timeouts (calculé, non mesuré)

Cette section est un **modèle statique** dérivé des `source ... every ...
timeout ...` et des `curl` du widget v5.10.0. Ce ne sont **pas** des
résultats device.

Hypothèses :

- Profil **secours** : aucune ligue déductible des équipes (`favLg` vide),
  `games` couvre **28 ligues** (25 clubs + 3 nations).
- Profil **dynamique typique** : 5 équipes suivies dans **6 ligues**
  distinctes. Le profil réel dépend de `myTeams`.
- Mois `games` : 4 mois distincts (`-4 j`, `0`, `+30`, `+60`, `+90`).
- Les caches froids sont vidés ; les caches chauds sont valides.

### 3.1 Sources, périodes et timeouts

| Source | Période | Timeout source | Requêtes / exécution (modèle) | Requêtes / 24 h à chaud |
|---|---:|---:|---:|---:|
| `games` | 15 min | 240 s | `L × 4` à froid ; `L` à chaud | `96·L + 3·L` |
| `seasonAll` | 12 h | 300 s | `L × 12` à froid ; `L` à chaud | `2·L` |
| `scheds` | 24 h | 900 s | 7 | 7 |
| `standings` | 6 h | 300 s | `8 + ligues suivies` | `4 × (8 + ligues)` |
| `teamsDb` | 168 h | 900 s | 27 | ≈ 3,9 |
| `extra` | 1 h | 360 s | ≈ 38–48 | `24 × N_e` (12–17) |
| `liveM` | 1 min | 90 s | 0 hors fenêtre ; `U` dans la fenêtre | 0 hors fenêtre |
| `knock` | 12 h | 120 s | 12 | 24 |
| `nextup` | 12 h | 360 s | `4 × N_n` (48–68) | `8 × N_n` (96–136) |
| `histfull` | 24 h | 300 s | `12 × N_h` (108–168) | `N_h` (9–14) |
| `heroOdds` | 1 h | 20 s | 0 ou 1 | 4–24 (TTL 6 h / 1 h) |

`L` = ligues de `games` ; `N_e` = ligues de `extra` (12 de base + ligues
suivies) ; `N_n` = ligues de `nextup` ; `N_h` = ligues de `histfull`.
`U` = couples uniques `(ligue, jour)` avec un match suivi en direct ou dans
les 3 h. Les sources `now` (15 s), `slow` (1 h), `liveIdx`, `oddsNow` et
`spr` sont locales et ne font aucun appel réseau.

Timeouts `curl` (I01) : `--connect-timeout 5`, `--max-redirs 0`,
`--max-filesize 2097152`, `-fsm 10–15` ; `--retry 0–2`, `--retry-max-time
20–30`, jitter 0–2 s par source réseau. `heroOdds` est le cas le plus
tendu : `retry-max-time 20 s` pour un timeout source de **20 s**, sans marge.

### 3.2 Volumes modélisés

| Source | Profil secours (L=28), 1er chargement | Profil secours, /24 h | Profil typique (L=6), 1er chargement | Profil typique, /24 h |
|---|---:|---:|---:|---:|
| `games` | 112 | 2 772 | 24 | 594 |
| `seasonAll` | 336 | 56 | 72 | 12 |
| `standings` | 8 | 32 | ≈ 11 | ≈ 44 |
| `extra` | ≈ 38 | 288 | ≈ 38 | ≈ 336 |
| `nextup` | 48 | 96 | ≈ 56 | ≈ 112 |
| `histfull` | 108 | 9 | ≈ 108 | ≈ 12 |
| `knock` | 12 | 24 | 12 | 24 |
| `scheds` | 7 | 7 | 7 | 7 |
| `teamsDb` | 27 | ≈ 3,9 | 27 | ≈ 3,9 |
| `heroOdds` | 0–1 | 4–24 | 0–1 | 4–24 |
| **Total indicatif** | — | **≈ 3 292** | — | **≈ 1 149** |

Soit environ **137 requêtes/h** en profil secours et **48 requêtes/h** en
profil typique, hors fenêtre live. À comparer au v5.7 mesuré :
**82,5 curl/min ≈ 4 950/h** en régime stable. Le modèle v5.10.0 reste donc
très inférieur, mais il doit être confirmé par la mesure : les fenêtres de
2 min du protocole v5.7/v5.8 **sous-échantillonnent** les sources à 15 min,
1 h, 6 h, 12 h et 24 h.

### 3.3 Budgets pire cas (modèle pessimiste)

Chaque lot parallèle attend le retour de tous ses `curl`. Avec des requêtes
qui expirent au maximum :

| Source | Parallélisme | Lots (froid) | Pire cas approximatif | Timeout source | Verdict |
|---|---:|---:|---:|---:|---|
| `games` secours | 8 | 14 | 14 × (20 + 1) ≈ 294 s | 240 s | **dépasse au pire** |
| `games` à chaud | 8 | 4 | 4 × 21 ≈ 84 s | 240 s | OK |
| `seasonAll` secours | 10 | 34 | 34 × 30 ≈ 1 020 s | 300 s | **dépasse au pire** |
| `histfull` secours | 10 | 11 | 11 × 30 ≈ 330 s | 300 s | **limite** |
| `standings` | 5 | 3 | 3 × 30 ≈ 90 s | 300 s | OK |
| `extra` froid | 5 | 10 | 10 × 30 ≈ 300 s | 360 s | marge faible |
| `heroOdds` | 1 | 1 | jusqu'à 20 s | 20 s | **aucune marge** |

Ces dépassements sont **théoriques** (réseau totalement bloqué ou très
lent). Ils ne sont pas observés dans les mesures v5.7/v5.8 et ne doivent pas
être présentés comme un résultat. Ils indiquent en revanche les cas à
surveiller pendant le test : premier chargement à froid, statut
`games`/`seasonAll`/`histfull`, et source `heroOdds`.

## 4. Protocole appareil à exécuter

### 4.1 Prérequis

- Téléphone de référence si possible : Xiaomi 11T Pro, Android 14,
  Omalauncher 0.12.0 (même base que les mesures v5.7/v5.8).
- Débogage USB autorisé, écran déverrouillé, `adb devices` doit afficher
  `device`.
- Relever et consigner : `getprop ro.product.model`, `getprop
  ro.build.version.release`, `getprop persist.sys.timezone`, `date`.
- Noter si le téléphone est **branché** (mesures de consommation) ou
  **débranché** (test de décharge). Ne pas mélanger les deux.
- Pour une comparaison stricte, faire les deux bras **le même jour**, même
  réseau, même position d'écran.
- Serveur LAN utilisé par les scripts invités : depuis le PC,
  `python3 scripts/collect-server.py 1764`. Sur le téléphone, on peut
  enregistrer une fois `http://<IP-DU-PC>:1764` dans
  `~/.config/omalauncher/measure-base`, ou passer `OMA_BASE` à chaque
  commande. Sans serveur, les scripts invités ne peuvent pas poster leurs
  résultats ; les mesures ADB de §4.4 restent utilisables.

### 4.2 Artefacts attendus

`scripts/measure.sh` crée `measurements/<phase>/<horodatage>/` :

```text
device.txt  battery.txt  package.txt  display.txt  power.txt
deviceidle.txt  services.txt  media.txt  meminfo.txt  netstats.txt
ps.txt  top.txt  settings_refresh.txt  settings_stay_awake.txt
settings_timeout.txt  guest_procs.txt  orphans.txt  gfxinfo.txt
proc_t0.txt  proc_t1.txt  batterystats.txt
proc_off_t0.txt  proc_off_t1.txt  power_screen_off.txt
```

`scripts/measure-remote.sh` crée `measurements/<horodatage>/` avec les
sorties de `measure-device.sh` (`static.txt`, `guest_t0.txt`, `proc_t0.txt`,
`proc_t1.txt`, `guest_t1.txt`, `gfxinfo.txt`, `ui.xml`, `DONE`).

Le collecteur `scripts/collect-server.py` écrit
`measurements/guest-<horodatage>.txt`. Ce nom est ignoré par Git
(`.gitignore` : `measurements/guest-*.txt`) ; conserver le fichier local et
noter sa taille et son SHA-256 dans le compte rendu final.

### 4.3 Phase 0 — vérifier la version installée

Dans le terminal invité d'Omalauncher (pas sur le PC) :

```sh
cd ~/.config/omalauncher/widgets
f=$(grep -l 'My Matches' *.owl | head -1)
grep -o 'version:"[^"]*"' "$f" | head -1
command -v owl-check >/dev/null && owl-check "$f"
```

Attendu : `version:"5.10.0"` et `compiles`. Pour installer/mettre à jour
(le collecteur §4.5 doit servir le dépôt) :

```sh
# terminal invité
curl -fsSL http://<IP-DU-PC>:1764/scripts/guest-update-widget.sh \
  -o /tmp/guest-update-widget.sh
nohup env OMA_BASE='http://<IP-DU-PC>:1764' \
  sh /tmp/guest-update-widget.sh >/tmp/update-widget.log 2>&1 &
sleep 20
cat /tmp/update-widget.log
```

`scripts/guest-update-widget.sh` tente GitHub `main`, puis
`$OMA_BASE/widget/my-match.optimized.owl`. Vérifier ensuite le SHA-256 si le
fichier doit être exactement celui du dépôt.

### 4.4 Phase A — mesures système ADB

Depuis la racine du dépôt sur le PC :

```sh
adb devices
adb shell 'settings get global stay_on_while_plugged_in'   # attendu 15
./scripts/measure.sh before --battery
```

`before` doit correspondre à **v5.8 installé**. Puis installer v5.10.0
(§4.3) et lancer :

```sh
./scripts/measure.sh after --screen-off --battery
```

`measure.sh` ne modifie aucun réglage : il lit, mesure 30 s de `gfxinfo`,
puis 10 s de deltas CPU, et avec `--screen-off` éteint l'écran 60 s
(`input keyevent 26`), relève les deltas CPU, puis rallume
(`keyevent 224`).

Variante si le lien USB est instable :

```sh
./scripts/measure-remote.sh
```

Elle pousse `measure-device.sh`, l'exécute en arrière-plan sur le téléphone,
attend `DONE`, puis récupère `/sdcard/omalauncher-measure`.

### 4.5 Phase B — compteurs curl/jq v5.7 vs v5.8 (baseline reproductible)

Le compteur exact est `scripts/guest-ab-wrapper.sh` : wrappers
`/usr/local/bin/curl` et `/usr/local/bin/jq`, fenêtre **90 s de démarrage +
120 s de régime stable** par version, puis POST vers `/measure`.

Sur le PC :

```sh
cd /root/.config/omalauncher/widgets/omalauncher-my-match
python3 scripts/collect-server.py 1764
```

Sur le téléphone, ouvrir `http://<IP-DU-PC>:1764/scripts/guest-ab.html`
pour la page d'aide, ou coller directement dans le terminal invité :

```sh
curl -fsSL http://<IP-DU-PC>:1764/scripts/guest-ab-wrapper.sh -o /tmp/ab-wrapper.sh
nohup env OMA_BASE='http://<IP-DU-PC>:1764' sh /tmp/ab-wrapper.sh \
  >/tmp/ab-wrapper.log 2>&1 &
```

Puis revenir à l'écran d'accueil et ne pas toucher le téléphone pendant
environ 7 min (deux fenêtres de 210 s + préparation). Le script :

- télécharge v5.7 (`$OMA_BASE/widget/my-match.owl` ou commit `f7bc076`) et
  v5.8 (commit `c918d58`) et vérifie `version:"5.7"` / `"5.8"` ;
- installe les wrappers, compte chaque appel, puis restaure v5.8 ;
- poste `/tmp/ab-wrapper.txt` vers le collecteur.

Artefacts : `measurements/guest-<horodatage>.txt` sur le PC, plus
`/tmp/phase-v57.txt`, `/tmp/phase-v58.txt`, `/tmp/curl-*.log`,
`/tmp/jq-*.log` dans le terminal invité. Récupération optionnelle :

```sh
adb shell 'cat /tmp/phase-v57.txt /tmp/phase-v58.txt' \
  > measurements/after/<horodatage>/phase-v57-v58.txt
```

`scripts/guest-ab-measure.sh` est l'autre script invité : il échantillonne
les processus toutes les 0,5 s pendant 30 s par version. Il ne compte pas
les appels curl/jq ; il sert à vérifier les processus invités et les
orphelins. La page `guest-ab.html` pointe vers ce script, pas vers le
wrapper de comptage.

### 4.6 Phase C — compteurs v5.10.0

Le wrapper A/B existant est épinglé à v5.7/v5.8. Pour v5.10.0, après
installation et vérification de version (§4.3), coller ce bloc dans le
terminal invité. Il n'écrit que dans `/tmp` et retire ses wrappers à la fin.

```sh
cat > /tmp/count-v5100.sh <<'EOS'
#!/bin/sh
set -u
cd "$HOME/.config/omalauncher/widgets" || exit 1
f=$(grep -l 'My Matches' *.owl | head -1)
grep -q 'version:"5.10.0"' "$f" || { echo "not v5.10.0: $f"; exit 1; }

cat >/usr/local/bin/curl <<'EOC'
#!/bin/sh
echo "$(date +%s) curl $*" >>/tmp/curl-v5100.log
exec /usr/bin/curl "$@"
EOC
cat >/usr/local/bin/jq <<'EOJ'
#!/bin/sh
echo "$(date +%s) jq $*" >>/tmp/jq-v5100.log
exec /usr/bin/jq "$@"
EOJ
chmod +x /usr/local/bin/curl /usr/local/bin/jq
trap 'rm -f /usr/local/bin/curl /usr/local/bin/jq' EXIT INT TERM

: >/tmp/curl-v5100.log
: >/tmp/jq-v5100.log
echo "initial v5100 $(date +%s)" >/tmp/phase-v5100.txt
sleep 90
echo "steady_start v5100 $(date +%s)" >>/tmp/phase-v5100.txt
sleep 120
echo "steady_end v5100 $(date +%s)" >>/tmp/phase-v5100.txt
cp /tmp/curl-v5100.log /tmp/curl-v5100.saved
cp /tmp/jq-v5100.log /tmp/jq-v5100.saved

a=$(awk '/steady_start/{print $3}' /tmp/phase-v5100.txt)
b=$(awk '/steady_end/{print $3}' /tmp/phase-v5100.txt)
{
  cat /tmp/phase-v5100.txt
  echo "curl_total=$(wc -l </tmp/curl-v5100.saved)"
  echo "jq_total=$(wc -l </tmp/jq-v5100.saved)"
  echo "curl_steady=$(awk -v a="$a" -v b="$b" '$1>=a && $1<=b' /tmp/curl-v5100.saved | wc -l)"
  echo "jq_steady=$(awk -v a="$a" -v b="$b" '$1>=a && $1<=b' /tmp/jq-v5100.saved | wc -l)"
  cat /tmp/curl-v5100.saved /tmp/jq-v5100.saved
} >/tmp/ab-v5100.txt

BASE="${OMA_BASE:-}"
[ -z "$BASE" ] && [ -r "$HOME/.config/omalauncher/measure-base" ] \
  && BASE=$(head -n 1 "$HOME/.config/omalauncher/measure-base" | tr -d '\r')
BASE=$(printf '%s' "$BASE" | tr -d '\r\n')
printf '%s' "$BASE" | grep -Ex '^https?://[A-Za-z0-9._:-]+$' >/dev/null || BASE=""
[ -n "$BASE" ] && curl -fsSL --connect-timeout 10 -X POST \
  --data-binary @/tmp/ab-v5100.txt --url "$BASE/measure" \
  -o /tmp/ab-v5100.out || true
echo done
EOS
nohup sh /tmp/count-v5100.sh >/tmp/count-v5100.log 2>&1 &
```

Revenir à l'accueil pendant les 210 s. Artefact : `measurements/guest-<ts>.txt`
sur le PC, ou `/tmp/ab-v5100.txt` sur le téléphone.

Pour comparer avec v5.8, le bloc doit être rejoué après avoir réinstallé
v5.8 et **vidé les caches** des deux bras (sinon le premier chargement
mesuré dépend de l'état laissé par l'autre version). Caches concernés :

```sh
rm -rf ~/.cache/espn-games-months ~/.cache/espn-games.json \
  ~/.cache/espn-games.json.meta ~/.cache/espn-games.sig \
  ~/.cache/espn-season.json ~/.cache/espn-season.json.meta \
  ~/.cache/espn-standings.json ~/.cache/espn-standings.json.meta \
  ~/.cache/espn-teams.json ~/.cache/espn-teams.json.meta \
  ~/.cache/espn-extra-base.json ~/.cache/espn-extra-base.json.meta \
  ~/.cache/espn-extra.json ~/.cache/espn-extra.json.meta \
  ~/.cache/espn-nextup.json ~/.cache/espn-nextup.json.meta \
  ~/.cache/espn-knock.json ~/.cache/espn-knock.json.meta \
  ~/.cache/espn-history.json ~/.cache/espn-history.json.meta \
  ~/.cache/espn-history-base.json ~/.cache/espn-history-base.json.meta \
  ~/.cache/espn-live.json ~/.cache/espn-live-index.json \
  ~/.cache/espn-odds ~/.cache/espn-logos
```

Vérifier les noms réellement utilisés par la version avant de supprimer :
`grep -o '~/\.cache/[A-Za-z0-9._/-]*' widget/my-match.optimized.owl | sort -u`.

### 4.7 Phase D — décharge et batterie

Pour une décharge réelle, téléphone **débranché**, écran éteint :

```sh
adb shell dumpsys batterystats --reset
adb shell settings get global stay_on_while_plugged_in
adb shell settings put global stay_on_while_plugged_in 0   # à restaurer ensuite
adb shell svc power stayon false
adb shell input keyevent 26
# attendre 30 à 60 min sans toucher au téléphone
adb shell dumpsys battery > measurements/after/<ts>/battery-discharge.txt
adb shell dumpsys batterystats --charged dev.omalauncher \
  > measurements/after/<ts>/batterystats-discharge.txt
adb shell settings put global stay_on_while_plugged_in 15  # restaurer la valeur d'origine
```

Consigner le niveau de batterie au début et à la fin (`dumpsys battery |
grep level`), la durée exacte, et si l'écran est resté éteint. Sans cette
vérification, un delta de batterie n'est pas interprétable.

## 5. Critères d'acceptation vs v5.7 / v5.8

Baseline v5.7/v5.8 : Xiaomi 11T Pro, Android 14, Omalauncher 0.12.0,
2026-10-25 22:19–22:27 Europe/Paris, wrappers curl/jq, 90 s de démarrage +
120 s de régime stable par version.

| ID | Métrique | Baseline v5.7 | Baseline v5.8 | Seuil v5.10.0 | Statut |
|---|---|---:|---:|---|---|
| AC-01 | Compilation + preview 7×12 | — | — | `owl-check` exit 0, preview et screen générés | **OK hors appareil** |
| AC-02 | Tests hors ligne | — | — | tous PASS | **OK hors appareil** |
| AC-03 | curl burst 90 s | 222 | 221 | ≤ 221, aucune source en régression > 10 % | non exécuté (appareil requis) |
| AC-04 | jq burst 90 s | 733 | 462 | ≤ 462 | non exécuté (appareil requis) |
| AC-05 | scoreboard burst | 160 | 175 | ≤ 175 | non exécuté (appareil requis) |
| AC-06 | standings burst | 28 | 12 | ≤ 12 (effet I06 attendu, à confirmer) | non exécuté (appareil requis) |
| AC-07 | teams burst | 34 | 34 | ≤ 34 | non exécuté (appareil requis) |
| AC-08 | curl régime stable sans live, 120 s | 165 (82,5/min) | 0 | `liveM` = 0 hors fenêtre ; total ≤ v5.8 sur fenêtre alignée | non exécuté (appareil requis) |
| AC-09 | jq régime stable sans live, 120 s | 323 (161,5/min) | 8 | ≤ 8 sur fenêtre alignée | non exécuté (appareil requis) |
| AC-10 | Débit résiduel sur 60 min | non mesuré | à établir | ≤ v5.8 + 10 % ; aucun `liveM` hors fenêtre | non exécuté (appareil requis) |
| AC-11 | Fenêtre live (curl/min) | non mesuré | à établir | ≤ v5.8 + 10 % ; ≤ 5 couples `(ligue, jour)`/min | non exécuté (appareil requis) |
| AC-12 | CPU écran allumé (delta 10 s) | non mesuré | à établir | ≤ v5.8 + 10 % | non exécuté (appareil requis) |
| AC-13 | CPU écran éteint (delta 60 s) | non mesuré | à établir | ≤ v5.8 + 10 % | non exécuté (appareil requis) |
| AC-14 | `gfxinfo` 30 s (jank/fps) | non mesuré | à établir | pas de régression visible vs v5.8 | non exécuté (appareil requis) |
| AC-15 | `netstats` octets | non mesuré | à établir | ≤ v5.8 + 10 % | non exécuté (appareil requis) |
| AC-16 | Décharge 30–60 min | non mesuré | à établir | ≤ v5.8 à conditions égales | non exécuté (appareil requis) |
| AC-17 | PSS / orphelins | non mesuré | à établir | PSS ≤ v5.8 + 10 % ; aucun `bash`/`curl`/`jq` orphelin | non exécuté (appareil requis) |
| AC-18 | Santé des sources | — | — | toutes `ok`, ou dégradation expliquée et bornée | non exécuté (appareil requis) |

Les seuils CPU/batterie/mémoire n'ont **pas** de baseline historique : les
mesures du 2026-10-25 ne portaient que sur curl/jq. Il faut donc mesurer
v5.8 et v5.10.0 dans la même session pour établir le delta. Ne pas réutiliser
un chiffre d'une autre session comme baseline CPU.

## 6. Tableau « non exécuté (appareil requis) »

| Mesure | Commande / source | Artefact attendu | Statut |
|---|---|---|---|
| Burst curl/jq v5.10.0 | §4.6 | `measurements/guest-*.txt` | non exécuté (appareil requis) |
| Baseline curl/jq v5.7/v5.8 rejouée | §4.5 | `measurements/guest-*.txt` | non exécuté (appareil requis) |
| Régime stable 120 s | §4.5/§4.6 | phase + logs horodatés | non exécuté (appareil requis) |
| Régime stable 60 min | §4.6, fenêtre prolongée | logs horodatés | non exécuté (appareil requis) |
| Fenêtre live | §4.6 pendant un match | logs + URL | non exécuté (appareil requis) |
| CPU écran allumé | `measure.sh` (proc_t0/t1) | `proc_t0.txt`, `proc_t1.txt` | non exécuté (appareil requis) |
| CPU écran éteint 60 s | `measure.sh --screen-off` | `proc_off_t0.txt`, `proc_off_t1.txt` | non exécuté (appareil requis) |
| Rendu / fps / jank | `measure.sh` (`gfxinfo`) | `gfxinfo.txt` | non exécuté (appareil requis) |
| Octets Wi-Fi/mobile | `measure.sh` (`netstats`) | `netstats.txt` | non exécuté (appareil requis) |
| Mémoire PSS | `measure.sh` (`meminfo`) | `meminfo.txt` | non exécuté (appareil requis) |
| Orphelins invités | `measure.sh` (`ps`, `orphans`) | `ps.txt`, `orphans.txt` | non exécuté (appareil requis) |
| Batterie / wakelocks | `measure.sh --battery` | `batterystats.txt`, `battery.txt` | non exécuté (appareil requis) |
| Décharge 30–60 min | §4.7 | `battery-discharge.txt`, `batterystats-discharge.txt` | non exécuté (appareil requis) |
| État écran / power | `measure.sh` | `power.txt`, `power_screen_off.txt` | non exécuté (appareil requis) |

## 7. Pièges de mesure à respecter

1. **Fenêtre trop courte.** 120 s ne voient pas `games` (15 min), `extra`
   (1 h), `standings` (6 h), `nextup`/`knock` (12 h) ni `histfull`/`scheds`
   (24 h). Conserver 90 s + 120 s pour la comparabilité v5.7/v5.8, puis
   ajouter une fenêtre de 60 min pour le débit résiduel.
2. **Profil de ligues.** Le burst dépend de `myTeams` et de `favLg`. Noter
   les équipes suivies et le nombre de ligues effectif avant chaque bras.
3. **Caches.** Un bras « chaud » après un bras « froid » ne mesure pas la
   même chose. Faire un passage à froid (caches vidés) et un passage à chaud,
   et les étiqueter.
4. **Live.** Un match en direct change `liveM`. Mesurer aussi une fenêtre
   sans live et une fenêtre avec live, séparément.
5. **Écran et alimentation.** Ne pas comparer un relevé branché avec un
   relevé débranché. Vérifier `stay_on_while_plugged_in` avant/après.
6. **Fuseau et heure.** Les logs sont horodatés en heure locale du téléphone.
   Consigner `persist.sys.timezone` et la date exacte.
7. **Collecteur.** `guest-*.txt` est ignoré par Git ; le compte rendu doit
   citer le nom, la taille et le SHA-256 du fichier brut local.
8. **Ne pas mélanger modèle et mesure.** Les chiffres du §3 sont calculés
   depuis le code ; seuls les chiffres issus des artefacts §4 sont des
   mesures device.

## 8. Fichiers utiles

| Fichier | Rôle |
|---|---|
| `docs/measurements-2026-10-25.md` | Baseline device v5.7/v5.8 (curl/jq) |
| `measurements/README.md` | Liste des métriques à relever |
| `scripts/measure.sh` | Mesures ADB ponctuelles, CPU, gfxinfo, batterie |
| `scripts/measure-device.sh` | Mesure embarquée autonome (sans lien USB) |
| `scripts/measure-remote.sh` | Push/exécution/récupération de la mesure embarquée |
| `scripts/guest-ab-wrapper.sh` | Comptage exact curl/jq v5.7/v5.8, 90 s + 120 s |
| `scripts/guest-ab-measure.sh` | Échantillonnage processus invités, 30 s par version |
| `scripts/guest-update-widget.sh` | Installation du widget optimisé |
| `scripts/collect-server.py` | Serveur LAN et collecte des POST `/measure` |
| `widget/my-match.optimized.owl` | Widget v5.10.0 mesuré |

## 9. Conclusion

Les preuves **hors appareil** sont acquises : v5.10.0 compile, ses previews
7×12 et plein écran sont générés, et toute la suite de tests hors ligne passe.
Le modèle statique indique un débit résiduel très inférieur à v5.7 et un
premier chargement à surveiller (sources à caches froids et `heroOdds`).
La validation **ENERGY-03** reste ouverte : elle exige le protocole §4 sur
un appareil physique, avec les artefacts §4.2 et les seuils §5. Aucun
résultat device v5.10.0 n'est revendiqué dans ce document.
