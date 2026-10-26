# Corrections et améliorations — suivi

Suivi du document « Jeu Roblox — Corrections et améliorations » (version .docx, qui remplace la version PDF).
Les sections sont traitées une par une, dans l'ordre du document, chacune testée (`tools/check.sh`) avant de
passer à la suivante. Pour chaque point : ce qui existait, ce qui change, ce qui est nouveau.

Les valeurs que le document ne précise pas sont des **valeurs par défaut à valider**, regroupées dans les
fichiers de configuration et signalées par « VALEUR(S) PAR DÉFAUT » dans le code ; elles sont listées ici.

## 1. Boss et combats — fait

| Point du document | Existant | Changement |
| --- | --- | --- |
| Notification de boss uniquement dans le monde concerné | `BossService` annonçait l'apparition et la défaite d'un boss de monde à **tout le serveur** (`AnnouncementService:Broadcast`) | Nouvelle fonction `AnnouncementService:ToZone(zone, …)` : l'apparition et la défaite ne sont envoyées qu'aux joueurs présents dans le monde du boss. Les autres annonces (tirages rares, records) restent globales |
| Barre de vie du boss visible uniquement à proximité | Le HUD affichait la barre dès qu'un boss existait **dans la zone**, et le compte à rebours de réapparition partout dans le monde | Le client cherche le boss le plus proche à moins de `Worlds.BossBarDistance` studs ; le compte à rebours ne s'affiche que près de l'arène (le serveur envoie désormais la position de l'arène dans `BossState`). Vaut aussi pour les boss de la tour et des raids |
| Raids : chaque vague dans une salle différente (5 vagues = 5 salles), petite salle de parcours entre deux salles, temps doublé | Une arène unique par raid, 4 vagues puis le boss au même endroit, 300 s | Donjon par emplacement de raid (`World/Arenas.luau`, plan dans `Raids.Plan`) : 4 salles de vague + la salle du boss (l'ancienne arène), reliées par 4 salles de parcours (plates-formes en zigzag ou poutres étroites au-dessus d'un fossé). La porte d'une salle s'ouvre quand sa vague est vaincue ; la vague suivante démarre quand un joueur entre dans la salle suivante. Chute dans le fossé → retour au début du parcours. Temps imparti : 600 s |

Correction au passage : pendant l'intro d'un raid, l'ancienne boucle considérait la vague 1 comme déjà vaincue
et lançait la vague 2 deux fois (des ennemis restaient hors du décompte). Le déroulement est désormais une suite
de phases explicites (`intro` → `wave` → `path` → … → `boss`).

### Valeurs par défaut à valider

| Réglage | Valeur | Fichier |
| --- | --- | --- |
| Distance d'affichage de la barre de vie d'un boss | 110 studs | `Config/Worlds.luau` (`BossBarDistance`) |
| Taille d'une salle de vague | 64 × 64 studs | `Config/Raids.luau` (`Layout.room`) |
| Longueur / largeur d'une salle de parcours | 56 / 22 studs | `Layout.course`, `Layout.width` |
| Profondeur du fossé, seuil de chute | 16 / 5 studs | `Layout.pit`, `Layout.fall` |
| Rattrapage d'un joueur resté en arrière pendant une vague | 20 s | `Layout.catchUp` |

Les sauts des parcours sont vérifiés par les tests (écart ≤ 6 studs, montée ≤ 3 studs, faisables avec le saut
par défaut de Roblox).

### Vérifications

- `tools/tests/config.spec.luau` : une salle par vague + le boss, un parcours entre deux salles, salles
  raccordées, sauts faisables, temps doublé.
- `tools/tests/world_smoke.luau` : le joueur simulé arrive dans la salle 1, vérifie que chaque vague apparaît
  dans sa salle, que la porte s'ouvre, tombe dans un fossé (retour au début du parcours), traverse les 5 salles
  et gagne le raid ; les annonces de boss ne sont jamais envoyées à tout le serveur.
- Vues : `docs/images/vues/25_donjon_crypte.jpg`, `26_donjon_temple.jpg`, `27_salle_de_parcours.jpg`.

## 2. Héros — fait

| Point du document | Existant | Changement |
| --- | --- | --- |
| Une attaque spéciale par héros avec cooldown | Une « capacité spéciale » par héros, déclenchée **toutes les N attaques** (`special.every`) | Recharge en secondes (`special.cooldown`) : l'attaque spéciale part dès que la recharge est finie, puis le héros finit son animation (`Heroes.SpecialLock`) avant de frapper à nouveau |
| Animation différente par héros et effets | Les spéciales réutilisaient l'animation d'attaque normale (un peu plus ample) et un anneau commun | 23 animations nouvelles, une par héros (`Anim/Poses`, clés `Sp…` : tourbillon, saut, cabrage, piqué, incantation…) et un effet propre à chaque héros (`Controllers/Specials` : pluie de flèches, colonne de lumière, éclairs, souffle, éclats de roche…). Planche : `docs/images/attaques_speciales.jpg` |
| Améliorer cooldown et dégâts de l'attaque spéciale | — | Deux améliorations par héros sur sa fiche (« Recharge » et « Dégâts »), payées en or, 10 niveaux chacune |
| Option multi-cible dans les paramètres | Tous les héros frappaient la cible choisie | Réglage « Héros en multi-cible » : chaque héros frappe un ennemi différent de la zone d'action (la cible choisie d'abord) ; le serveur envoie la cible de chaque héros, qui court vers elle |
| Zone d'action affichée par un cercle, petite au départ, améliorable | La cible pouvait être choisie jusqu'à 95 studs, l'attaque auto prenait l'ennemi le plus proche à 70 studs | Zone d'action = cercle lumineux au sol autour du personnage du joueur (hors du village, réglage « Cercle de la zone d'action ») ; seules les cibles à l'intérieur sont acceptées (clic, attaque auto, serveur). Nouvelle amélioration « Zone d'action » à la Forge |
| Nom, niveau et étoiles au-dessus de chaque héros | Rien au-dessus des héros | Étiquette au-dessus de chaque héros (les siens et ceux des autres joueurs) |
| Prendre l'apparence d'un héros possédé | — | Bouton (casque) sur la fiche du héros : le personnage prend l'apparence du héros (modèle voxel animé, vu par tous) ; second clic pour reprendre la sienne. Retirée si le dernier exemplaire est relâché |
| Recycler les Légendaires à l'autel comme Commun / Rare / Épique | Vente automatique à l'autel pour Commun, Rare, Épique | Légendaire ajouté à la vente automatique |

Interprétation à confirmer : le « cercle autour du héros » est tracé autour du **personnage du joueur** (centre de
l'équipe) plutôt qu'autour de chaque héros, pour rester lisible avec 3 à 6 héros ; un cercle par héros est
facile à mettre en place si c'était le sens voulu.

### Valeurs par défaut à valider

| Réglage | Valeur | Fichier |
| --- | --- | --- |
| Recharge de chaque attaque spéciale | 3 à 5,5 s (même rythme que l'ancienne règle « toutes les N attaques ») | `Config/Heroes.luau` (`special.cooldown`) |
| Pause après une attaque spéciale (animation) | 1,1 s | `Heroes.SpecialLock` |
| Améliorations de la spéciale | 10 niveaux : −5 % de recharge / +15 % de dégâts par niveau | `Heroes.SpecialUpgrade` |
| Coût d'une amélioration de la spéciale | coût d'une invocation du monde × facteur de rareté (2 à 48) × 1,55^niveau (×1,25 pour la recharge) | `Heroes.SpecialUpgrade`, `Heroes.SpecialCost` |
| Zone d'action de départ | 20 studs | `Config/Upgrades.luau` (`BaseActionRange`) |
| Amélioration « Zone d'action » | +4 studs par niveau, 15 niveaux, 300 or × 1,45^niveau | `Upgrades.List.Portee` |

### Vérifications

- `config.spec` : chaque héros a une recharge, une animation unique présente pour sa famille de squelette, des
  coûts d'amélioration croissants ; `logic.spec` : recharge et dégâts améliorés, zone d'action.
- `world_smoke` : cible hors de la zone d'action refusée, multi-cible (trois héros sur trois ennemis différents),
  attaques spéciales déclenchées par la recharge, améliorations, apparence (et refus d'un héros non possédé),
  vente auto des Légendaires.
- `ui_smoke` : les 23 animations et effets joués, étiquettes au-dessus des héros, cercle de la zone d'action,
  apparence affichée puis retirée, boutons de la fiche du héros cliqués.

## 3. Progression — à venir

## 4. Invocation et boutique — à venir

## 5. Interface et social — à venir
