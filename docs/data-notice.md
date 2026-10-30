# Données & attribution

Ce document décrit la provenance des données affichées par le widget
**my-match**, ce qu'il conserve localement et comment l'effacer. Il complète
[`LICENSE`](../LICENSE) : la licence MIT couvre **uniquement le code du widget**,
pas les données ni les marques d'ESPN.

## Source des données

- Les données sportives (matchs, scores, classements, calendriers, cotes,
  équipes) proviennent de l'API publique d'**ESPN** :
  `https://site.api.espn.com/apis/site/v2/sports/soccer/…`.
- Les écussons et visuels d'équipes sont téléchargés depuis
  `https://a.espncdn.com/…` (logos servis via le combiner ESPN).

Le widget effectue uniquement des requêtes HTTP `GET` vers ces deux hôtes. Il
n'envoie **aucune donnée personnelle** : pas de compte, pas d'identifiant, pas
de jeton, pas de télémétrie, pas de statistiques d'usage. Les requêtes ne
contiennent que les paramètres nécessaires (ligue, équipe, date), identiques
pour tous les utilisateurs.

## Absence d'affiliation

Ce widget est un projet indépendant. Il n'est **ni affilié, ni sponsorisé, ni
approuvé par ESPN**, la NFL, l'UEFA, les ligues, les clubs ou les fédérations
concernées. Les noms, sigles, écussons, logos et données restent la propriété
de leurs détenteurs respectifs, en particulier **ESPN** et les ayants droit
sportifs. Ils sont affichés à titre d'information et ne sont couverts ni par la
licence MIT du code, ni par aucune licence accordée par ce dépôt.

Les données peuvent être partielles, retardées ou erronées. Les cotes affichées
sont purement informatives : elles ne constituent ni un conseil de pari ni une
incitation à jouer.

## Données conservées localement

Le widget ne stocke rien sur un serveur. Tout reste sur l'appareil, dans le
répertoire personnel de l'utilisateur.

### Réglages et sélection d'équipes

Ces valeurs sont conservées par Omalauncher avec l'état persistant du widget
(`persist`) :

- équipes suivies (1 à 5) et équipe sélectionnée ponctuellement ;
- langue (`fr`/`en`), taille d'affichage, onglet actif, ligues Top 5 / Europe ;
- sections repliées, visibilité des classements ;
- état des rappels déjà déclenchés (coup d'envoi, mi-temps) et horodatages de
  dernier rafraîchissement.

Aucune de ces valeurs n'est transmise à un tiers ; elles servent seulement à
restituer l'affichage au lancement suivant.

### Caches

Les réponses ESPN et les visuels sont mis en cache sous `~/.cache/` :

- `~/.cache/espn-games.json`, `~/.cache/espn-games.sig` et
  `~/.cache/espn-games-months/` : matchs et tranches mensuelles ;
- `~/.cache/espn-season.json`, `~/.cache/espn-standings.json` : saison et
  classements ;
- `~/.cache/espn-teams.json`, `~/.cache/espn-history.json`,
  `~/.cache/espn-extra.json`, `~/.cache/espn-knock.json`,
  `~/.cache/espn-nextup.json` : équipes, historique, calendrier, arbre et
  prochaines affiches ;
- `~/.cache/espn-live-index.json`, `~/.cache/espn-live.json` : index du direct ;
- `~/.cache/espn-odds/` : cotes mises en cache ;
- `~/.cache/espn-logos/` : écussons téléchargés, sprite et fichier vide ;
- fichiers annexes `*.json.meta`, `*.sig` : horodatage, schéma et empreinte de
  validité des caches.

Ces fichiers ne contiennent que des données publiques ESPN et des métadonnées
techniques. Ils sont réutilisés pour limiter les appels réseau et peuvent être
supprimés sans perte : le widget les reconstruira au prochain rafraîchissement.

## Effacer les données locales

- **Caches** : `rm -rf ~/.cache/espn-*`
- **Réglages et équipes suivies** : modifier ou retirer les équipes via
  « mes équipes », réinitialiser les réglages du widget, ou supprimer puis
  recréer la tuile (l'état persistant repart alors de zéro).

## Précautions d'usage

- L'API ESPN est publique mais non contractuelle : elle peut être limitée,
  modifiée ou interrompue sans préavis.
- Le widget espace ses appels (caches avec TTL, backoff et respect de
  `Retry-After`) pour rester courtois. Éviter de multiplier les instances, les
  rafraîchissements forcés ou les intervalles très courts, sous peine de
  blocage temporaire côté ESPN.
- Ne pas réutiliser les données ou les logos à des fins commerciales ou de
  manière suggérant une affiliation avec ESPN sans autorisation.
