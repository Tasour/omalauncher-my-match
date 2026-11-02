# Audit sécurité & robustesse — `my-match.owl`

- Source : `/home/tasour/Work/omalauncher-my-match/widget/my-match.owl` (1955 lignes, 102 370 octets)
- Audit initial : `docs/audit-omalauncher-2026-10-25.html` (texte extrait dans `/tmp/opencode/audit-my-match/audit-source.txt`)
- Référentiel `sh()` : `app/src/main/assets/widgets/docs/declarations.md:55-70` et `owl/src/test/.../LangTest.kt:1439-1454` (dépôt amont dans `/tmp/opencode/upstream-src`)
- Méthode : analyse statique du widget, extraction des scripts, reproduction locale du quoting shell, lecture du runtime `GuestShell` amont. Aucun test sur téléphone dans cet audit.
- Périmètre : injection, données ESPN, caches, processus, réseau, partage. Aucune fonctionnalité n'est retirée par les correctifs proposés.

## Résumé exécutif

| ID | Sévérité | Constat | Lignes |
|---|---|---|---|
| S-01 | **P0** | Injection shell réelle : `favStr`, `favTid`, `favNoTid` sont concaténés **bruts** entre apostrophes, sans `sh()`. Un `abbr`/`tid` contenant `'` casse le script ou exécute du code dans le shell invité. | 6-8, 10-12, 239-241, 385-387, 658-660 |
| S-02 | **P0** | Pas de `trap`; timeouts surdimensionnés par rapport au travail réel; sorties précoces et SIGTERM laissent `mktemp -d` et des `curl`/`jq` en arrière-plan. C'est la chaîne exacte de l'orphelin à 100 % mesuré dans l'audit initial (§P0-1). | 9, 50-62, 80-82, 235, 238, 761, 833, 936, etc. |
| S-03 | **P1** | Caches : écritures directes ou `mv` inter-systèmes non atomiques, noms `.tmp` fixes, pas de validation de schéma, concurrence entre 7 sources sur les mêmes logos/sprite. | 83, 306-308, 333, 440-443, 502, 595, 631, 770, 842, 925, 984 |
| S-04 | **P1** | JSON ESPN non validé : `fromdateiso8601`, `.children[]`, `.stats[]`, `ascii_downcase` peuvent faire échouer tout le filtre; `curl | jq > fichier` laisse des `.jsonl` partiels. | 48, 279, 428, 557, 709, 740, 815, 886 |
| S-05 | **P1** | Logos/téléchargements non atomiques; un fichier partiel non nul n'est jamais retéléchargé. Sprite : JSON non échappé, `cols=0` non gardé. | 94, 352, 519, 646, 781, 853, 975, 215-226, 1179, 1196 |
| S-06 | **P1** | Faux « frais » et perte de cache hors ligne : `games` republie le cache en `ok`, `knock`/`nextup` sortent avant la fusion du cache. | 73-78, 597-600, 761, 833 |
| S-07 | **P1** | Réseau : pas de limite de taille, pas de `--proto`/`--max-redirs`, retries sans jitter, concurrence globale non bornée. | tous les `curl`, 48/277/367/425/557/709/739/814/886 |
| S-08 | **P1** | Partage : le widget ne passerait pas la revue du store (commandes « built from widget values »), `requires` omet `perl`, chemin `/root` codé en dur, lien de 28 704 caractères. | 5, 237/361/453/531/724, 529 |
| S-09 | **P2** | Champs non bornés (`name`, `detail`, `stage`, `group`), cache non versionné, variables `WANT` mortes, double redirection, cas spécial `LYON`, scripts de partage. | 48/428/557/709, 305, 557/740/815, 820, 529, `scripts/*` |

**Verdict** : le widget n'est pas publiable en l'état. S-01 doit être corrigé avant toute exécution avec des données ESPN non fiables; S-02 avant de le remettre sur un écran d'accueil. Les autres points sont nécessaires pour un partage public fiable.

### Rappel de l'audit initial (extrait)

- **P0-1** : un script foot/ESPN orphelin (PID 14568, PPID 1) a tourné 45 min à 100,4 % d'un cœur, écran éteint inclus; `Proot.killAll()` ne tue pas un `bash` déjà reparenté.
- **P1-6** : le widget est jugé trop lourd pour un launcher (156 requêtes, téléchargements de logos, `jq` dans proot); la doc recommande `http(...)` + `file(...)` et un rafraîchissement plus lent.
- Ces constats ne sont pas corrigés par la version 5.7 auditée : au premier run, `games` fait 140 requêtes et `seasonAll` 364, avec des timeouts inférieurs au pire cas (§4.1). La sécurité et la robustesse doivent donc traiter aussi le volume, pas seulement le quoting.

---

## 1. Injection shell

### 1.1 Ce que fait réellement le code

Contrairement à l'hypothèse « valeurs injectées via `sh()` », les valeurs favorites ne passent **pas** par `sh()` :

```owl
6: let favStr=join(myTeams.map(t=>t.abbr??"").filter(a=>a!=""),",")
7: let favTid=join(myTeams.map(t=>t.tid??"").filter(a=>a!=""),",")
8: let favNoTid=join(myTeams.map(t=>(t.tid??"")==""?(t.abbr??""):"").filter(a=>a!=""),",")
...
10:     WANT='"""+favStr+"""'
11:     WANTID='"""+favTid+"""'
12:     WANTNOTID='"""+favNoTid+"""'
```

La valeur est donc placée **telle quelle** entre deux apostrophes littérales. `sh()` n'est utilisé que pour emballer le script entier :

```owl
237: source games=cmd("bash -c ${sh(gamesScript)}")every 15m json timeout 240s status
361: source seasonAll=cmd("bash -c ${sh(seasonScript)}")every 12h json timeout 300s
453: source standings=cmd("bash -c ${sh(standingsScript)}")every 6h json timeout 90s
531: source formsData=cmd("bash -c ${sh(formsScript)}")every 15m json timeout 60s
724: source liveM=cmd("bash -c ${sh(liveScript)}")every 1m json timeout 90s
```

Ces cinq appels sont corrects pour la couche extérieure (`sh()` hors guillemets, un seul argument). Mais ils transportent le texte déjà piégé de `WANT`, que le `bash` intérieur réinterprète. Le correctif doit donc porter sur les lignes 10-12, 239-241, 385-387 et 658-660, pas sur les lignes 237/361/453/531/724.

### 1.2 Inventaire des interpolations

| Emplacement | Valeur | Forme | Verdict |
|---|---|---|---|
| 6-8 | `favStr`, `favTid`, `favNoTid` | construites depuis `myTeams` (état persistant + ESPN) | donnée non fiable, non échappée |
| 10-12, 239-241, 385-387, 658-660 | mêmes valeurs | `WANT='<valeur brute>'` | **injectable** (apostrophe) |
| 237, 361, 453, 531, 724 | script entier | `sh(script)` hors guillemets | correct pour le shell extérieur; ne protège pas l'intérieur |
| 1008-1010, 1036, 1315 | `team`, `myTeams`, `draft` | état OWL, pas de shell | pas d'injection directe; source de `fav*` |
| 999, 1001-1006, 1785-1786 | `lang` | uniquement UI (`S`, `JP`, etc.) | pas d'injection shell |
| 48, 279, 428, 557, 709, 740, 815, 886 | `lg`, `d`, `tag` | `"$lg"`, `"$d"`, `--arg` | sûrs si `lg` vient des listes fixes; `lg` de cache à valider |
| 94, 352, 519, 646, 781, 853, 975 | `f` (logo) | chemin + URL, regex en amont | limité par la regex; à durcir côté cache/UI |
| 104, 305, 323 | `sig`, `WANT` | `sha256sum`, `printf '%s'` | sûr si l'assignation `WANT` est corrigée |
| 348-357, 972-980 | `nn`, `k`, `n` | nombres calculés | sûr |
| 367-381 | `lg`, `id` | constantes d'appel (`fra.1 167`, etc.) | sûr |
| 425-427 | `e` (endDate ESPN) | `date -d "$e"` | pas d'exécution; entrée non bornée (voir §2) |
| 529 | `/root/.cache/espn-extra.json` | chemin fixe | pas une injection; dépend de `HOME` (voir §6) |
| 106-228 | heredoc `PERLEOF` | contenu statique, args `$dir`/`$out` | pas d'interpolation; problème JSON distinct (§3.4) |

### 1.3 Preuve de l'injection

Le quoting de `sh()` est correct quand il est utilisé seul : `sh("O'Neil")` produit `'O'\''Neil'` (test amont `LangTest.kt:1441-1443`). Ici il n'est pas utilisé.

```bash
# Valeur favorite : PSG
WANT='PSG'                       # ok

# Valeur favorite : O'Neil
WANT='O'Neil'                    # bash: EOF prématurée -> script mort

# Valeur favorite : '; touch /tmp/PWN; #
WANT=''; touch /tmp/PWN; #'      # exécute touch

# Valeur favorite : x'$(touch /tmp/PWN)'
WANT='x'$(touch /tmp/PWN)''      # exécute la substitution
```

Précision importante : `$(...)` ou des backticks **seuls**, à l'intérieur des apostrophes, restent littéraux. C'est l'apostrophe qui ferme la quote et permet l'exécution. Autrement dit, tout `abbr`/`tid` contenant `'` est dangereux; `$()` seul ne l'est pas, mais devient dangereux combiné à `'`.

### 1.4 Chaîne d'exploitation

1. ESPN (ou un cache corrompu) renvoie `team.abbreviation = "'; curl … #"` ou `team.id = "'; … #"`.
2. `teamsDb` écrit ce champ sans validation : ligne 494 (`abbr: $t.abbreviation`, `tid: ($t.id | tostring)`).
3. L'utilisateur sélectionne l'équipe (ligne 1305), `myTeams=draft` (ligne 1315), l'état est persisté (ligne 1009).
4. Au prochain `games`, `seasonAll`, `standings` ou `liveM`, `favStr`/`favTid`/`favNoTid` est concaténé dans `WANT` et exécuté dans le `bash` invité.

Impact : exécution de commandes en tant qu'utilisateur Linux invité (pas root Android), lecture/écriture des caches et des répertoires montés, accès réseau. Un widget tiers peut aussi embarquer un `state myTeams` piégé; il peut déjà lancer des commandes, mais cela montre que la donnée d'état n'est pas une frontière de confiance. L'état `myTeams` peut également être écrit par `owl-send` ou par une valeur persistée corrompue : la validation doit donc être faite au moment de construire `favStr`/`favTid`/`favNoTid`, pas seulement dans l'UI de sélection.

### 1.5 Correctif P0 (avant/après)

Avant, aux quatre endroits :

```owl
WANT='"""+favStr+"""'
WANTID='"""+favTid+"""'
WANTNOTID='"""+favNoTid+"""'
```

Après, aux quatre endroits (10-12, 239-241, 385-387, 658-660), sans apostrophes ajoutées autour de `sh()` :

```owl
WANT="""+sh(favStr)+"""
WANTID="""+sh(favTid)+"""
WANTNOTID="""+sh(favNoTid)+"""
```

Le shell généré devient `WANT='PSG'`, `WANT='O'\''Neil'`, `WANT=''\''; …'` : la valeur reste un seul mot et ne peut plus sortir de la quote.

Défense en profondeur, sans retirer d'équipe réelle, aux lignes 6-8 :

```owl
let favStr=join(myTeams.map(t=>(t.abbr??"")).filter(a=>a!=""&&!contains(a,",")&&!contains(a,"\n")&&!contains(a,"\r")).take(5),",")
let favTid=join(myTeams.map(t=>(t.tid??"")).filter(a=>a!=""&&!contains(a,",")&&!contains(a,"\n")&&!contains(a,"\r")).take(5),",")
let favNoTid=join(myTeams.map(t=>(t.tid??"")==""?(t.abbr??""):"").filter(a=>a!=""&&!contains(a,",")&&!contains(a,"\n")&&!contains(a,"\r")).take(5),",")
```

- `take(5)` borne un état persistant corrompu, même si l'UI limite déjà à 5.
- Virgule/retour ligne sont retirés uniquement pour le format CSV de `WANT`; les apostrophes restent autorisées et sont gérées par `sh()`.
- Ne pas « corriger » en remplaçant `sh()` par un `replace("'","")` : cela casserait les noms réels et ne protégerait pas les autres métacaractères.

À la source, ligne 494, normaliser/caper les champs sans modifier les équipes valides :

```jq
abbr: (($t.abbreviation // "") | tostring | gsub("[,\r\n\t]"; "") | .[0:16]),
tid:  (($t.id // "")          | tostring | gsub("[^0-9]"; "")   | .[0:16]),
```

`WANT` reste ensuite passé à `jq --arg` (48, 279, 428, 661-671) : ce n'est pas une zone d'injection, seulement une valeur.

---

## 2. Données ESPN non fiables

### 2.1 Parsing

Les filtres supposent des types et des champs parfaits :

- `fromdateiso8601` sur `.date[0:16] + ":00Z"` (48, 279, 557, 709, 740, 815, 886) : une date absente, courte, avec fuseau ou invalide fait échouer tout le filtre. Comme le flux est redirigé vers un `.jsonl`, `jq` peut avoir déjà écrit une partie des événements : fichier partiel conservé.
- `$c.status.type.state`, `$c.status.type.shortDetail` (48, etc.) : `$c` peut être `null` si `.competitions[0]` manque.
- `.children[]` et `.standings.entries[]` (428) : pas de `// []`; un `children` absent fait échouer toute la ligue.
- `reduce .stats[]` (428) : `stats` peut ne pas être un tableau.
- `ascii_downcase` sur `.note.description` (428) : si ce n'est pas une chaîne, erreur.
- `date -d "$e"` (427) : `$e` vient de `.season.endDate`; c'est quoté (pas d'exécution), mais la chaîne n'est pas bornée. `date` peut échouer ou interpréter des formats inattendus.
- `--argjson ends "$e"` (428) : doit être un nombre; le fallback `9999999999` est prévu, mais pas si `date` renvoie autre chose.

Conséquence : un seul événement malformé peut faire perdre un mois entier, ou produire un cache partiel qui sera ensuite fusionné. Le `status` de la source peut rester `ok` alors que des données manquent.

### 2.2 Champs affichés

| Champ | Source | Risque |
|---|---|---|
| `abbr` | `.team.abbreviation` | injection (S-01), longueur, caractères de contrôle, doublons de clé OWL |
| `name`, `short` | `shortDisplayName`/`displayName` | longueur non bornée, contrôle, RTL/bidi, sauts de ligne; rendu texte seulement |
| `logo` | `.team.logo` | regex `^(soccer|countries)/500/[a-z0-9]+[.]png$` (48) ou `[a-z0-9.]+` (494), puis `gsub("/"; "-")`; pas de traversée par `/`, mais la valeur lue depuis un cache modifié est réutilisée telle quelle dans un chemin (1201, 1450) |
| `detail` | `status.type.shortDetail` | affiché en largeur fixe, `maxLines:1` (1401), mais chaîne non bornée |
| `tag`, `stage`, `group` | constantes/ESPN | longueur, contrôle, affichage; `get(knockLabels, st, st)` (1920) |
| `odds` | `.odds[].moneyline…` | `dec` (48) convertit par `try tonumber`; valeurs énormes/négatives, `Infinity`, arrondis; affichage seulement |
| `score`, `winner` | ESPN | types incohérents; `winner` est utilisé comme booléen dans les ternaires (1356, 1370, etc.) |
| `id` | ESPN | concaténé (`$lg + ":" + .id`); `null` possible; `unique_by(.id)` peut fusionner plusieurs `null` |

Pas de HTML/XSS : le widget utilise `Text`, pas de WebView ni de HTML. Les noms restent du texte. En revanche, un nom très long, avec caractères de contrôle ou directions bidi, peut casser la mise en page ou tromper la lecture (faux score, faux nom). Les notifications (`notify`, 1047/1056) reprennent ces textes.

### 2.3 Correctif P1 — parsing tolérant

Avant (48, répété à 279/557/709/740/815/886) :

```jq
.events[]? | .competitions[0] as $c
| {id: ..., at: (.date[0:16] + ":00Z" | fromdateiso8601), ...}
```

Après (principe) :

```jq
.events[]?
| try (
    .competitions[0]? as $c
    | (try (.date[0:19] | fromdateiso8601) catch null) as $at
    | select($at != null and .id != null)
    | select(($c.status.type.state // "") | IN("pre","in","post"))
    | {
        id: ($lg + ":" + (.id | tostring)),
        at: $at,
        state: ($c.status.type.state // ""),
        detail: (($c.status.type.shortDetail // "") | tostring | .[0:80]),
        squads: ([$c.competitors[]? | .team.abbreviation | strings | .[0:16]]),
        ...
      }
  ) catch empty
```

Et pour les classements (428) :

```jq
(.children // [])[]
| { name: ((.name // "") | tostring | .[0:60]),
    teams: ([((.standings.entries) // [])[]
             | select((.stats | type) == "array")
             | ...]) }
```

`note.description` doit être testé `type == "string"` avant `ascii_downcase`/`test`.

Borner les tableaux (par ligue/mois) et les chaînes est aussi une protection mémoire : `[0:500]` par réponse, `detail[0:80]`, `name[0:60]`, `stage[0:32]`.

### 2.4 Risques de taille et de coût

- Pas de limite de taille de réponse dans le widget; `jq` construit des tableaux en mémoire. Un JSON de plusieurs Mo, ou un `gzip` très compressé, peut saturer le shell invité.
- `curl --compressed` décompresse avant `jq`; une bombe de décompression est possible.
- `liveM` relit et `slurp` quatre caches (dont `espn-season.json`) toutes les minutes (661-671). Un cache volumineux augmente le CPU et la mémoire en continu.
- `formsData` relit tout `espn-extra.json` toutes les 15 min (529).
- Les caches ne sont jamais bornés en nombre d'éléments; les logos sont seulement purgés après 30 jours (88, 346).

---

## 3. Caches

### 3.1 Inventaire

| Fichier | Écriture | Lecture | Atomicité actuelle |
|---|---|---|---|
| `~/.cache/espn-games.json` | 69-83 | 671, 1151 (UI) | `cache.tmp` puis `mv` même dossier (83), nom fixe |
| `~/.cache/espn-season.json` | 303-341 | 671 | init directe (306, 308); `mv` depuis `$tmp` (333) → inter-systèmes possible |
| `~/.cache/espn-standings.json` | 439-449 | 1069 (UI) | init directe (440); `cache.tmp` (443) |
| `~/.cache/espn-teams.json` | 500-508 | 1270 (UI) | `cache.tmp` (502) |
| `~/.cache/espn-extra-base.json` | 569-595 | 671 | init directe (572); `mv` depuis `$tmp` (595) |
| `~/.cache/espn-extra.json` | 597-598, 631-633 | 529, 671, 1123 | `.tmp` fixe même dossier (631) |
| `~/.cache/espn-knock.json` | 766-774 | 1146 (UI) | init directe (767); `cache.tmp` (770) |
| `~/.cache/espn-nextup.json` | 838-846 | 671, 1124 | init directe (839); `cache.tmp` (842) |
| `~/.cache/espn-hist-base.json` | 902-925 | 927, 935, etc. | init directe (904); `mv` depuis `$tmp` (925) |
| `~/.cache/espn-history.json` | 927, 984 | 986, 1151 (UI) | `.tmp` fixe même dossier (984) |
| `~/.cache/espn-logos/soccer/*.png` | 84-99, 342-357, 511-524, 640-651, 775-786, 847-858, 969-980 | 1201, 1450 | **non atomique** (`curl -o` direct), 6 écrivains concurrents |
| `~/.cache/espn-logos/empty.png` | 86-87, 344-345, 513-514 | 1201? (fallback) | **non atomique** (`[ -s ]` puis `>`), 3 écrivains |
| `~/.cache/espn-logos/sprite.png` / `.json` | 106-232 | 998, 1178 | build dans `$tmp` puis `mv` (230), mais lecture concurrente des logos |
| `~/.cache/espn-logos/.sprite.sig` | 231 | 105 | écriture directe |

`~` et `/root` : `formsData` lit `/root/.cache/espn-extra.json` (529) alors que `extra` écrit `~/.cache/espn-extra.json` (631). Dans le proot actuel `HOME=/root`, mais ce n'est pas garanti; le chemin absolu est aussi un « chemin personnel » pour la revue du store.

### 3.2 Corruption et absorption des erreurs

- `[ -s "$cache" ]` ne vérifie que « non vide », pas « JSON valide ».
- `jq -e '.lms and .items'` (306, 572, 904) accepte un `.items` chaîne/objet; le merge échoue ensuite.
- `jq -e '.sig == $sig'` (307) ne vérifie pas le type des éléments.
- `games` (73-78) : si le frais est vide mais que le cache existe, il republie le cache et sort en succès. Le widget affiche alors `lastAt=now` via `on games` (1033) : données potentiellement vieilles présentées comme fraîches.
- `extra` (597-600) et `history` (985-988) resservent un ancien fichier sans vérifier sa fraîcheur.
- `knock` (761) et `nextup` (833) sortent avant la fusion si aucune réponse n'est valide : hors ligne, le cache existant n'est **pas** servi.
- `liveM` (661-671) fait un `jq -s` sur quatre fichiers : un seul JSON corrompu annule toute la sortie live (`2>/dev/null` masque l'erreur).
- `formsData` (529) échoue si `espn-extra.json` est absent/corrompu; pas de fallback.

### 3.3 Écriture atomique

`mv "$tmp/cache.json" "$cache"` (333, 595, 925) est atomique seulement si `$tmp` et `~/.cache` sont sur le même système de fichiers. Dans le proot, `/tmp` et le stockage Android monté peuvent être des montages différents; `mv` fait alors copie + unlink, et un lecteur peut voir un fichier partiel. Les écritures `> "$cache.tmp"` avec un nom fixe (83, 308, 443, 502, 631, 770, 842, 984) sont dans le bon dossier mais deux exécutions concurrentes (refresh manuel + source périodique) se marchent dessus.

Correctif type, pour chaque cache :

```bash
# avant
jq -c '.cache' "$tmp/merged.json" > "$tmp/cache.json" && mv "$tmp/cache.json" "$cache"

# après
out=$(mktemp "${cache}.XXXXXX") || exit 1
jq -c '.cache' "$tmp/merged.json" > "$out" || { rm -f -- "$out"; exit 1; }
mv -f -- "$out" "$cache"
```

Et validation avant lecture :

```bash
jq -e 'type=="array"' "$cache" >/dev/null 2>&1 || cache_ok=0
jq -e 'type=="object" and (.lms|type)=="array" and (.items|type)=="array"' "$cache" >/dev/null 2>&1 || cache_ok=0
```

Verrou optionnel (`flock` disponible sur Arch) autour de la publication seulement, pas autour des requêtes réseau :

```bash
exec 9>"$HOME/.cache/espn.lock"
flock -w 20 9 || exit 1
# ... mv atomique ...
```

### 3.4 Logos et sprite

- `curl -o "$d/$f"` écrit directement le fichier final (94, 352, 519, 646, 781, 853, 975). Un arrêt au milieu laisse un PNG partiel non nul; `[ ! -s "$d/$f" ]` (93, 351, 518, 645, 780, 852, 974) ne le retélécharge jamais. Le sprite `parse_png` rejette le fichier invalide (125-181), mais l'UI `Image` peut afficher un écran cassé.
- Plusieurs sources téléchargent les mêmes logos dans le même dossier sans verrou; une source peut `rm -f` le fichier qu'une autre vient d'écrire (94, 352, etc.).
- `empty.png` : `[ -s "$e" ] || printf ... > "$e"` (87, 345, 514) : deux écrivains peuvent tronquer le fichier de l'autre. Ce fichier n'est jamais lu : code mort. De même, `BannerLogo` pointe vers `~/.cache/espn-logos/banner/${logo}` (1450), mais aucun script ne crée ni ne remplit `banner/` : les bannières sont toujours vides, avec un `Image` sur un chemin absent.
- Sprite (215-226) : les noms de fichiers sont insérés dans le JSON sans échappement :
  ```perl
  print $oj '"' . $names[$i] . '":' . $i;
  ```
  Un fichier nommé `a".png` dans le dossier rend `sprite.json` invalide. Le widget lit ce fichier avec `source spr=file(...)` (998) et `sprOk` (1179) ne vérifie pas `cols>0`; `si%spr.cols` (1196) peut diviser par zéro si le JSON est corrompu.
- `sha256sum` du sprite (104) est basé sur des noms/taille/mtime; pas de contenu. Un fichier remplacé avec même taille/mtime ne déclenche pas la reconstruction.

Correctifs :

```bash
# logo atomique
part=$(mktemp "$d/.${f}.XXXXXX") || continue
if curl --connect-timeout 3 --max-time 8 --max-filesize 262144 -fsS \
     -o "$part" "https://a.espncdn.com/combiner/i?img=/i/teamlogos/$p&w=48&h=48" \
   && [ "$(head -c 4 "$part" | od -An -tx1 | tr -d ' \n')" = "89504e47" ]; then
  mv -f -- "$part" "$d/$f"
else
  rm -f -- "$part"
fi
```

```perl
sub jstr {
  my $s = shift;
  $s =~ s/([\\"])/\\$1/g;
  $s =~ s/([\x00-\x1f])/sprintf("\\u%04x", ord($1))/ge;
  return '"' . $s . '"';
}
...
print $oj jstr($names[$i]) . ':' . $i;
```

Et dans `sprOk` (1179) : `&& (spr.cols??0)>0` (et éventuellement `(spr.idx??{})`).

### 3.5 Permissions et taille

- Aucun `umask`; les fichiers sont créés selon l'umask du shell invité. Les caches contiennent les équipes suivies (préférence personnelle), pas de token. Un autre processus/widget du même utilisateur invité peut les lire : `chmod` ne protège pas contre le même UID, mais limite les lectures par d'autres UID et les sauvegardes naïves.
- Recommandation : `umask 077` en tête de chaque script, `mkdir -p` puis `chmod 700 ~/.cache/espn-logos`, `chmod 600` sur les caches après écriture. Ne pas mettre de secret dans ces fichiers.
- Pas de plafond global : `games` peut accumuler les matchs de 5 mois × 28 ligues; `season` 13 mois × 28; `history` 12 × 9; `extra` 120 jours × 11. Ajouter un plafond par ligue et un plafond total, et purger les équipes retirées de `myTeams`.
- `espn-logos/soccer` n'est purgé que par âge (30 jours) et par le motif `[0-9]*.png` (89, 347); les logos d'équipes supprimées restent. Le sprite grossit avec tous les PNG du dossier; plafonner le nombre de tuiles (ex. 256) et la taille finale.

---

## 4. Processus, timeouts, orphelins

### 4.1 Budget réel vs timeout

| Source | Lignes | Requêtes au premier run | Concurrence | Timeout | Pire cas avec `-m 15` |
|---|---|---|---|---|---|
| `games` | 237 | 28 ligues × 5 mois = 140 | 5 (52-54) | 240 s | 28 lots × 15 s = 420 s |
| `seasonAll` | 361 | 28 × 13 = 364 | 10 (289) | 300 s | 37 lots × 10 s = 370 s |
| `standings` | 453 | 26 | 5 (431-434) | 90 s | 6 lots × 15 s = 90 s |
| `teamsDb` | 527 | 27 | 6 (496) | 150 s | 5 lots × 15 s = 75 s |
| `extra` | 654 | 11 ligues × (5 ou 2) = 40 | 5 (563) | 150 s | 8 lots × 10 s = 80 s |
| `liveM` | 724 | lignes de `LGD` (variable) | 3 (715) | 90 s | variable, peut dépasser |
| `knock` | 789 | 3 × 4 = 12 | 10 (747) | 120 s | 2 lots × 10 s = 20 s |
| `nextup` | 861 | 11 × 4 = 44 | 5 (822) | 150 s | 9 lots × 10 s = 90 s |
| `histfull` | 995 | 9 × 13 = 117 | 10 (892) | 150 s | 12 lots × 15 s = 180 s |
| `scheds` | 383 | 7 | séquentiel | 60 s | 7 × 10 s = 70 s |

Les pires cas `games` et `seasonAll` dépassent le timeout. C'est exactement le mécanisme de l'orphelin mesuré dans l'audit initial : `bash`/`proot` tué, enfants `curl`/`jq` reparentés, script à 100 % d'un cœur pendant 45 min (audit §P0-1).

### 4.2 Fuites de `mktemp`

Les scripts créent `tmp=$(mktemp -d)` (9, 238, 363, 384, 455, 533, 656, 726, 791, 863). Plusieurs sorties ne le suppriment pas :

- `games` : 80, 82 (`exit 1` sans `rm`).
- `scheds` : 380.
- `extra` : 606.
- `knock` : 761.
- `nextup` : 833.
- `histfull` : 936.
- Tous les scripts si `timeout`/SIGTERM/SIGKILL arrive avant la fin (aucun `trap`).

Un `mktemp -d` qui échoue (disque plein, `/tmp` absent) laisse `tmp=""`; les chemins deviennent `"/..."` et le nettoyage `rm -rf "$tmp"` est au mieux inutile. Il faut tester le retour de `mktemp`.

### 4.3 Jobs, `wait`, `kill`

- `wait` sans argument (62, 99, 318, 357, 435, 498, 524, 581, 627, 651, 720, 758, 786, 832, 858, 912, 968, 980) attend tous les jobs du shell. Si un `curl`/`jq` se bloque au-delà de son `-m`, le `wait` bloque jusqu'au timeout extérieur.
- Les `&` (52, 94, 287, 352, 431, 494, 519, 561, 620, 646, 713, 745, 781, 820, 853, 890, 975) laissent des enfants si le shell est tué.
- Aucun `kill` dans le widget. C'est bien : un `pkill -f espn`, `kill 0`, `kill -- -$$` ou `killall bash` tuerait le `GuestShell` persistant ou d'autres widgets. Le nettoyage doit rester limité aux jobs du script.
- Fuite de descripteurs : pas de `exec`/redirection permanente dans le widget; les FDs des jobs se ferment au `wait`. Le `GuestShell` amont garde son fichier `$__err` par shell persistant (hors périmètre widget), et les fichiers de cache ne sont pas tenus ouverts. Aucun descripteur fuyant identifié dans le widget lui-même.

### 4.4 `trap` sûr (ne tue pas le `GuestShell`)

À insérer au début de chaque script, avant `tmp=$(mktemp -d)` :

```bash
tmp=
cleanup() {
  rc=$1
  trap - EXIT INT TERM HUP
  # Uniquement les jobs de CE bash, jamais le groupe de processus du GuestShell.
  for p in $(jobs -p 2>/dev/null); do kill "$p" 2>/dev/null || true; done
  wait 2>/dev/null || true
  [ -n "${tmp:-}" ] && [ -d "$tmp" ] && rm -rf -- "$tmp"
  exit "$rc"
}
trap 'cleanup $?' EXIT
trap 'cleanup 143' INT TERM HUP

tmp=$(mktemp -d) || exit 1
```

Pourquoi c'est sûr :

- `jobs -p` ne liste que les jobs lancés par ce `bash -c`; le `GuestShell` est le parent, pas un job.
- On ne fait **pas** `kill 0`, `kill -- -$$`, `pkill -f`, `killall`, ni `kill` sur un PID lu dans un fichier.
- `rm -rf -- "$tmp"` est protégé par `[ -n ] && [ -d ]`; jamais de `rm -rf "$tmp"/*` avec `tmp` vide.
- Sur SIGKILL du timeout, le `trap` ne tourne pas : c'est pourquoi il faut aussi réduire le budget (§4.5) et, côté amont, `timeout -k 5` avec `GuestShell`. Le `kill` des jobs directs ne tue pas forcément les petits-enfants d'un sous-shell; c'est `curl -m 8`/`--max-time` qui borne leur durée. Ne jamais utiliser `kill -- -$$` pour compenser : cela peut atteindre le `GuestShell`.

Ne pas remplacer les `rm -rf "$tmp"` existants par un `trap` qui tue tout : les deux peuvent coexister (le `rm` final est idempotent).

### 4.5 Réduire le risque sans retirer de fonctionnalité

- Passer `curl -m 15` à `--connect-timeout 4 --max-time 8` et augmenter la concurrence de 5 à 8 pour `games` : 18 lots × 8 s = 144 s < 240 s.
- `seasonAll` : 31 lots × 8 s = 248 s < 300 s, ou timeout 360 s. Le cache mensuel fait que seul le premier run est complet.
- `histfull` : `-m 8` -> 12 lots × 8 s = 96 s < 150 s.
- `standings` : `-m 8` -> 6 lots × 8 s = 48 s < 90 s.
- `scheds` : `-m 8` -> 7 lots × 8 s = 56 s < 60 s (ou timeout 90 s).
- Supprimer la couche `bash -c` quand c'est possible : `cmd(gamesScript)` au lieu de `cmd("bash -c ${sh(gamesScript)}")` (237, 361, 453, 531, 724). `cmd` prend une expression; à valider avec `owl-check`. Le timeout vise alors directement le script, au lieu d'un `bash` qui attend un `bash`.
- Côté amont `GuestShell` : `timeout -k 5 N bash -c …` pour éviter qu'un enfant refuse de mourir.

---

## 5. Réseau

### 5.1 Constats

- Toutes les URL sont en **HTTPS** (`site.api.espn.com`, `a.espncdn.com`); aucun `http://`, aucun `-k`, pas de vérification TLS désactivée. C'est un point positif.
- `curl` n'utilise pas `-L` : les redirections ne sont pas suivies. Une réponse 3xx n'est pas une erreur `-f`; le corps peut être du HTML, puis `jq` échoue.
- Pas de `--proto '=https'` : une redirection future ou une URL modifiée pourrait descendre en clair. Les URL sont fixes, mais l'option est peu coûteuse.
- Pas de `--max-redirs 0` explicite.
- Pas de `--max-filesize` ni de contrôle de taille après téléchargement. `--compressed` décompresse avant `jq`; une réponse énorme ou une bombe gzip peut saturer la mémoire.
- `-m 15`/`-m 10`: pas de `--connect-timeout` séparé; un DNS lent consomme tout le budget.
- `--retry 0/1/2 --retry-delay 1/2`: pas de jitter, pas de `--retry-max-time`; 429/503 peuvent provoquer des rafales synchronisées entre sources.
- Concurrence globale : 5 (games), 10 (season), 5 (standings), 6 (teams), 5 (extra), 3 (live), 10 (knock), 5 (nextup), 10 (hist). Un `refresh()` manuel (1735) peut lancer plusieurs de ces scripts en même temps, en plus des sources périodiques.
- 404/429 : `-f` les transforme en échec; certains scripts retombent sur le cache, d'autres non (§3.2).
- SSRF : pas de host dynamique; `$lg` vient de listes fixes ou du cache, `$d` d'une date, `$p` d'un logo filtré. Risque faible, à condition de valider `lg` du cache avant de l'utiliser (671, 717-719).

### 5.2 Correctif type

```bash
# avant (ex. 48)
curl --retry 1 --retry-delay 1 -fsm 15 --compressed "https://…/$lg/scoreboard?dates=$d" 2>/dev/null | jq -c …

# après
raw="$tmp/raw-$lg-$d.json"
curl --proto '=https' --tlsv1.2 --max-redirs 0 \
     --connect-timeout 4 --max-time 8 \
     --retry 2 --retry-delay 2 --retry-max-time 24 \
     --max-filesize 2097152 --compressed -fsS \
     "https://site.api.espn.com/apis/site/v2/sports/soccer/$lg/scoreboard?dates=$d" \
     -o "$raw" || return 1
[ "$(wc -c <"$raw")" -le 2097152 ] || return 1
jq -e 'type=="object"' "$raw" >/dev/null || return 1
jq -c '…' "$raw" > "$tmp/$lg-$d.jsonl" || { rm -f -- "$tmp/$lg-$d.jsonl"; return 1; }
```

Pour les logos, plafonner à 256 Ko (`--max-filesize 262144`) et vérifier la signature PNG avant `mv`.

Gestion 429 :

- Respecter `Retry-After` (curl le fait avec `--retry` sur 429/503) avec un plafond (ex. 30 s).
- Backoff exponentiel + jitter (`sleep $((2 ** attempt + RANDOM % 3))`), pas de retry sur 400/404.
- Un 429 ne doit pas écraser un cache valide; il doit marquer la source `ok=false` ou servir le cache avec un âge visible.

---

## 6. Partage public

### 6.1 Ce qui est déjà propre

- Aucun token, mot de passe, clé API ou URL personnelle dans le fichier.
- Toutes les URL sont fixes et HTTPS.
- `meta` contient description, version `5.7`, licence MIT, catégorie sport, `owl:11`.
- `myTeams`, `team`, `view`, `lang`, etc. sont des états persistés **hors** du fichier `.owl`; un lien de partage n'embarque pas les équipes choisies.
- Les caches ne sont pas dans le fichier; ils ne sont pas partagés par `encode-share-link.py`.

### 6.2 À assainir avant publication

1. **S-01** : remplacer les `WANT='…'` par `sh()`. Sans cela, la revue du store considérera les commandes comme « built from widget values » (erreur, pas seulement avertissement; `Review.kt` / `UNQUOTED`) et le widget restera refusé.
2. **`requires`** (5) : ajouter les paquets réellement utilisés : `perl` (106), `coreutils` (`base64` 87, `sha256sum` 104, `date`, `mktemp`, `sort`, `cut`, `wc`), `findutils` (`find` 88, 346), `bash` (scripts). Sans `perl`, le sprite échoue; le fallback images fonctionne, mais la fonctionnalité « affichage groupé » est perdue.
3. **Chemin `/root`** (529) : remplacer par `~/.cache/espn-extra.json` ou, mieux, lire le fichier via une source `file()` et filtrer en OWL. Un chemin absolu `/root` est à la fois fragile et signalé comme chemin personnel.
4. **Cas `LYON`** (48, 279, 428, 557, 709, 740, 815, 886) : cas spécial codé en dur pour une équipe. Ce n'est pas un secret, mais c'est une préférence personnelle/exception non générique. Le remplacer par `displayName`/`shortDisplayName` (ou une table générique) pour un widget neutre. Si le rendu « Olympique Lyonnais » est voulu, le documenter comme choix éditorial, pas comme donnée.
5. **Taille du lien** : le fichier fait 102 370 octets; le lien généré fait 28 704 caractères. La doc de partage annonce ~2,9 Ko utiles et un QR code; ce widget est ~10× trop gros pour un QR/message. Pour un partage public, passer par le store ou héberger le fichier; sinon le lien sera tronqué. Ne pas « résoudre » en supprimant des fonctionnalités; réduire les scripts (mutualiser `tagof`, sortir les données) ou héberger.
6. **Données de mesure** : `scripts/measure.sh` collecte `getprop` (peut contenir un numéro de série), `dumpsys package`, `dumpsys batterystats`, `ps`, `netstats`. Ne pas publier `measurements/` brut sans vérifier/expurger. Le README l'exige déjà, mais `.gitignore` ne l'applique pas aux dossiers `measurements/`.
7. **Captures d'écran** : les onglets « Mes matchs », les noms d'équipes et les notifications révèlent les clubs suivis. Vider `myTeams`/captures avant publication.
8. **Caches** : ne pas joindre `~/.cache/espn-*.json`, `espn-logos/`, `sprite.json`; ils contiennent les équipes suivies et l'historique. Le lien `.owl` ne les inclut pas, mais un partage de dépôt/sauvegarde peut le faire.
9. **Scripts de partage** :
   - `scripts/decode-share-link.py` décompresse sans limite : un lien malveillant de quelques Ko peut produire des centaines de Mo (bombe DEFLATE). Ajouter une limite (`decompressobj().decompress(data, 1_000_000)`, vérifier `unconsumed_tail`/`eof`) et refuser > 1 Mo.
   - `scripts/open-share-link.sh` passe `$1` à `adb shell … -d "$LINK"`; `adb shell` reconstruit une commande shell côté appareil. Un lien contenant `;`, `$()` ou des espaces peut injecter. Valider `^https://simonschubert\.github\.io/omarchy-widgets/w#owl[0-9]+\.[A-Za-z0-9_-]+$` avant l'appel, et refuser le reste.

### 6.3 Ce qui ne doit pas être « assaini » par suppression

Conserver : les 28 compétitions, les onglets, les classements, les journées, les arbres, les cotes, les logos, les notifications, le cache anti-trous, le rafraîchissement manuel. Les correctifs ci-dessus sont des ajouts de quoting, validation, limites et fallbacks.

---

## 7. Correctifs classés

### P0 — à faire avant exécution avec des données non fiables

| # | Correctif | Lignes | Effort |
|---|---|---|---|
| P0-1 | Passer `WANT`/`WANTID`/`WANTNOTID` par `sh()` hors guillemets; filtrer virgule/retour ligne; `take(5)`. | 6-8, 10-12, 239-241, 385-387, 658-660 | faible |
| P0-2 | `trap` de nettoyage sûr + `mktemp` vérifié dans les 10 scripts; ne jamais tuer le `GuestShell`. | 9, 238, 363, 384, 455, 533, 656, 726, 791, 863 | faible |
| P0-3 | Réduire le budget réseau (`-m 8`, concurrence adaptée) pour que `games`/`seasonAll`/`histfull` restent sous leur timeout; sinon l'orphelin revient. | 48-62, 277-318, 886-912 | moyen |

### P1 — avant partage public / fiabilité

| # | Correctif | Lignes |
|---|---|---|
| P1-1 | Télécharger chaque réponse dans un fichier temporaire, vérifier taille/type, puis `jq`; supprimer le `.jsonl` en cas d'échec (fini les JSON tronqués). | 48, 279, 557, 709, 740, 815, 886 |
| P1-2 | Caches : `mktemp` dans le dossier cible + `mv` atomique; valider le schéma avant lecture; fallback cache explicite. | 83, 306-308, 333, 440-443, 502, 595, 631, 770, 842, 925, 984 |
| P1-3 | Logos atomiques (`.part`/`mktemp` + `mv`), vérification PNG, limite de taille; sprite JSON échappé et `cols>0`. | 94, 352, 519, 646, 781, 853, 975, 215-226, 1179, 1196 |
| P1-4 | `curl --proto '=https' --max-redirs 0 --connect-timeout 4 --max-time 8 --max-filesize 2M --retry-max-time`; gérer 429/Retry-After. | tous les `curl` |
| P1-5 | Servir le cache quand toutes les requêtes échouent (`knock` 761, `nextup` 833) et ne pas republier un cache comme « frais » (`games` 73-78); stocker/afficher `fetchedAt`. | 73-78, 597, 761, 833 |
| P1-6 | `requires` + `perl`, remplacer `/root` par `~`/`file()`, supprimer les commandes « built from widget values » (déjà P0-1). | 5, 529 |
| P1-7 | Borner les champs ESPN (`name`, `detail`, `stage`, `group`) et les tableaux; `try` autour de chaque événement. | 48, 279, 428, 557, 709, 740, 815, 886 |

### P2 — durcissement

| # | Correctif | Lignes |
|---|---|---|
| P2-1 | `umask 077`; `chmod 700` dossiers, `600` caches; ne rien mettre de secret dedans. | 70, 84, 303, 500, 569, 766, 838, 902 |
| P2-2 | Versionner les caches (`sig = "v2|season|WANTID|WANT"`) et purger les entrées des équipes retirées. | 305, 585, 765, 837 |
| P2-3 | Supprimer les `WANT` morts de `extra`/`knock`/`nextup` (`--arg want "$WANT"` sans `WANT`) et le double `>` de `nextup` 820. | 557, 740, 815, 820 |
| P2-4 | Remplacer `LYON` codé en dur par un affichage générique. | 48, 279, 428, 557, 709, 740, 815, 886 |
| P2-5 | `sprOk` doit exiger `cols>0` et `idx` objet; chemins `logo` validés aussi au rendu. | 1179, 1196, 1201, 1450 |
| P2-6 | Scripts de partage : limite de décompression, validation du lien ADB, taille/QR. | `scripts/decode-share-link.py`, `scripts/open-share-link.sh` |
| P2-7 | `LC_ALL=C` pour `sort`/`sha256sum`; `mktemp` vérifié; `while IFS= read -r` au lieu de `for f in $(jq …)` pour les logos. | 88, 91, 104, 349, 516, 643, 778, 850, 972 |
| P2-8 | Supprimer `empty.png` (jamais lu) et soit créer/remplir `banner/`, soit faire fallback `BannerLogo` vers `soccer/` ou `Crest`. | 86-87, 344-345, 513-514, 1450 |

---

## 8. Tests de robustesse

Les tests peuvent être faits hors téléphone en extrayant les scripts et en remplaçant `curl`/`jq` par des stubs dans `PATH`, avec `HOME` pointant vers un dossier jetable. Toujours vérifier qu'aucun fichier marqueur n'est créé et que les caches restent valides (`jq -e .`).

| # | Scénario | Injection / fixture | Attendu |
|---|---|---|---|
| T1 | Injection `abbr` | `PSG`, `O'Neil`, `'; touch /tmp/PWN; #`, `x'$(touch …)'`, nouvelle ligne, virgule | Aucun `/tmp/PWN`; `WANT` contient la valeur littérale; pas d'EOF; le widget continue. `O'Neil` doit matcher l'équipe si ESPN la renvoie. |
| T2 | API vide | `{"events":[]}`, `{"children":[]}`, `{"teams":[]}` | JSON `[]` valide, pas de crash, pas d'écrasement d'un cache valide; l'UI affiche « aucun match ». |
| T3 | 429 | En-tête `Retry-After: 5`, corps vide | Backoff, pas de rafale, cache précédent conservé; source `ok=false` ou cache avec âge visible. |
| T4 | Hors ligne | `curl` exit 6 | `games`/`season`/`standings`/`teams`/`extra` servent le cache; `knock`/`nextup` aussi (après P1-5); aucun cache écrasé par `[]`. |
| T5 | JSON tronqué | Premiers 50 % d'une réponse valide | `jq` échoue, fichier `.jsonl` supprimé, cache précédent intact, source en échec propre (pas de `.jsonl` partiel fusionné). |
| T6 | Cache corrompu | `{`, `[]` à la place d'un objet `.lms/.items`, `cols:0`, `idx` chaîne | Validation échoue, cache reconstruit ou ignoré; pas de division par zéro; sprite ignoré et fallback images. |
| T7 | Équipe supprimée | 404 sur `teams/$id/schedule`, standings sans l'équipe | Pas de crash; l'équipe reste sélectionnée mais sans match; l'utilisateur peut la retirer; pas de match d'une autre équipe. |
| T8 | Changement de saison | Date simulée 31/07 puis 01/08; `nor.1`/`swe.1` | `S`/`E` basculent, `keep` purge l'ancienne saison, `hist`/`knock` ne mélangent pas les saisons; cache `sig` change. |
| T9 | Champs énormes | `name` 1 Mo, `detail` 1 Mo, `children` 10 000, caractères de contrôle/bidi | Réponse rejetée ou champs tronqués; mémoire bornée; UI lisible; notification bornée. |
| T10 | Concurrence | Lancer `games` deux fois + `liveM` + `refresh()` pendant les écritures | Tous les caches restent `jq -e .`; aucun sprite partiel; aucun logo partiel; pas d'orphelin `curl`/`jq`. |
| T11 | Timeout / TERM | Envoyer TERM au `bash -c` pendant `games` | `trap` supprime `tmp`; jobs directs terminés; `GuestShell` toujours vivant (`echo ok` via une autre source). Les petits-enfants de sous-shells sont bornés par `curl -m`; SIGKILL : documenter la limite et vérifier les orphelins. |
| T12 | Permissions | `stat -c '%a %n' ~/.cache/espn-* ~/.cache/espn-logos` | 600/700 après P2-1. |
| T13 | Lien de partage | Lien DEFLATE 1 Ko -> 100 Mo; lien ADB `…; id` | Décodeur refuse > 1 Mo; `open-share-link.sh` refuse le lien non conforme; aucune commande locale. |

Commandes de vérification utiles :

```bash
for f in ~/.cache/espn-*.json; do jq -e . "$f" >/dev/null || echo "corrompu: $f"; done
find /tmp -maxdepth 1 -name 'tmp.*' -type d -mmin +60 -print
ps -eo pid,ppid,etime,pcpu,comm,args | grep -E 'espn|curl|jq|bash -c' | grep -v grep
for f in ~/.cache/espn-*.json; do stat -c '%a %n' "$f"; done
```

Critères de sortie : aucun marqueur d'injection, aucun cache invalide, aucun orphelin après TERM, aucun `.jsonl` partiel fusionné, aucun crash UI avec les fixtures T2/T6/T9, et le `GuestShell` répond après T11.

---

## Annexe — preuves et limites

- `sh()` : `'a b'`, `'it'\''s; rm -rf ~'`, `''` (test amont `LangTest.kt:1439-1444`). La doc impose `sh(value)` **hors** guillemets (`declarations.md:55-70`). Le widget ne le fait pas pour `favStr`/`favTid`/`favNoTid`.
- PoC d'injection : reproduit localement avec `bash -c "WANT='<valeur>'"`; `'; touch /tmp/PWN; #` crée le fichier, `O'Neil` provoque `EOF prématurée`. Le correctif `WANT=<sh(valeur)>` ne crée plus de fichier et restitue `O'Neil`.
- Audit initial : orphelin PID 14568, 100,4 % d'un cœur, 45 min de CPU pour 46 min de vie, PPID 1 (audit §P0-1); widget jugé trop lourd (156 requêtes, §P1-6). La version auditée ici fait 140 requêtes `games` + 364 `seasonAll` au premier run, ce qui aggrave le budget.
- Limites : pas de test sur appareil, pas de `owl-check` exécuté, pas de mesure de mémoire réelle; les pires cas réseau sont théoriques (DNS/TLS inclus dans `-m`, mais débit variable). Les références de lignes sont celles du fichier fourni au 25/10/2026.
