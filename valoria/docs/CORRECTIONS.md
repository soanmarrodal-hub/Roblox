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

## 3. Progression — fait

| Point du document | Existant | Changement |
| --- | --- | --- |
| Intégrer la forge actuelle dans un onglet de la boutique | Améliorations au menu de la Forge, ouvert seulement près de la Forge du village | Onglet « Forge » dans la boutique (accessible partout) avec toutes les améliorations |
| Remplacer la forge physique au spawn par un reroll de spec/stats (comme ACS) | Forge = améliorations | La station devient la **Forge des talents** (même bâtiment, cristal des talents au-dessus de l'enclume, Bran le forgeron) : reroll des talents des héros |
| Reroll via jetons lâchés par les mobs (10 %, améliorable) | — | **Jeton de talent** : 10 % par ennemi de monde vaincu, + amélioration « Flair du chasseur » (+0,5 %/niveau) et bonus de butin des enchantements Glaneur |
| Talents / stats des héros | Statistiques fixes par héros | Puissance (dégâts), Vivacité (vitesse d'attaque), Précision (critique), notées F à SSS ; tout héros commence à C (neutre, l'équilibrage actuel ne bouge pas) ; un talent verrouillé garde sa note (+1 jeton par verrou, au moins un talent tiré) |
| Enchantements comme le quirk tree d'ACS, quirks repris et adaptés | 14 « bénédictions » | 37 **enchantements** repris des quirks d'ACS avec leurs taux : familles Strong/Rich/Accurate/Mage/Lucky/Genius/Fast/Collector → Vigueur/Avarice/Précision/Arcane/Fortune/Sagesse/Célérité/Glaneur (I, II, III) ; uniques Thief/Sniper/Leprechaun/Giant/Assassin/Archmage → Larron/Tireur d'élite/Farfadet/Colosse/Assassin/Archimage ; Teleport → Pas de l'ombre ; légendaires Titan/Crimson Demon/Celestial/Boxer/Blessed/Black Hole/Atomic → Titan/Démon écarlate/Céleste/Pugiliste/Béni des dieux/Néant/Astral. Les bénédictions déjà obtenues sont converties |
| Animation de roulement pour les rerolls | Résultat affiché directement | Les noms (enchantements) ou les notes (talents) défilent puis ralentissent avant de s'arrêter sur le résultat |
| Deuxième emplacement débloquable à 6 étoiles | 5 étoiles au maximum, un emplacement | 6 étoiles possibles ; second emplacement d'enchantement à 6 étoiles |
| Aura selon la rareté de l'enchantement | — | Étincelles autour du héros à la couleur de la rareté de son meilleur enchantement, plus denses et lumineuses avec la rareté (visibles par tous) ; Colosse, Farfadet et Titan changent aussi la taille du héros, Pas de l'ombre le fait se téléporter vers sa cible |
| Clic infligeant des dégâts proportionnels à l'équipe, améliorable, autoclick 500 diamants / 50 Robux | — | Clic sur l'écran (ou sur la cible) et bouton « Frapper » : 3 % des dégâts par seconde de l'équipe par clic, + amélioration « Frappe du chevalier » ; **clic automatique** (passe à 50 R$ ou 500 gemmes), activable dans le HUD |
| Déblocage progressif : monde 1 fusion d'étoiles, monde 2 enchantement, monde 3 reroll des stats | Tout disponible dès le départ | `Config/Unlocks` ; les menus verrouillés affichent la condition, le serveur refuse les actions |

Points à noter :

- « Diamants » = la monnaie premium du jeu, appelée **gemmes**.
- Le **monde 3 n'existe pas encore** : en attendant, les talents se débloquent en battant Vyrmax (boss du
  monde 2). Réglage provisoire dans `Config/Unlocks.luau`, à retirer quand le monde 3 sera ajouté.
- La quête du Val « La bénédiction » (impossible avant le monde 2) devient « Le poing du chevalier » (100 clics) ;
  la quête d'enchantement passe dans la chaîne des Falaises ; la quête du jour « Tire 2 bénédictions » devient
  « Frappe 300 fois tes cibles ».
- Les multiplicateurs des quirks d'ACS sont adaptés à l'équilibrage du jeu (ex. Fast III : ×2 de vitesse dans ACS,
  +25 % ici) ; les taux de tirage sont ceux d'ACS.

### Valeurs par défaut à valider

| Réglage | Valeur | Fichier |
| --- | --- | --- |
| Notes des talents et leurs effets | F ×0,85 … C ×1 … SSS ×1,5 (dégâts) ; poids F 12, E 16, D 20, C 20, B 15, A 10, S 5, SS 1,6, SSS 0,4 | `Config/Talents.luau` |
| Coût d'un reroll de talents | 1 jeton + 1 par talent verrouillé | `Talents.RerollCost`, `Talents.LockCost` |
| Amélioration « Flair du chasseur » | +0,5 % par niveau, 20 niveaux | `Config/Upgrades.luau` |
| Dégâts d'un clic | 3 % des dégâts/s de l'équipe, +1 %/niveau de « Frappe du chevalier » (25 niveaux) | `Upgrades.Click`, `Upgrades.List.Frappe` |
| Clic automatique | 4 clics/s ; 8 clics/s au maximum | `Upgrades.Click` |
| Effets des enchantements | voir la liste | `Config/Traits.luau` |
| Étoiles maximum | 6 | `Logic/Progression.luau` (`MaxStars`) |
| Déblocage provisoire des talents | Vyrmax vaincu (tant que le monde 3 manque) | `Config/Unlocks.luau` |

### Vérifications

- `config.spec` : taux des enchantements (≈ 100 %, ceux d'ACS), anciennes clés reprises, second emplacement à 6
  étoiles, notes de talents croissantes et C neutre, 10 % de jeton, déblocages monde 1/2/3, clic automatique
  500 gemmes / 50 R$.
- `logic.spec` : deux emplacements, enchantements d'attaque spéciale, talents, verrous, butin et jetons, clic,
  conversion des anciennes bénédictions, 6 étoiles.
- `world_smoke` : enchantement refusé au monde 1 (rune non dépensée), accepté au monde 2, second emplacement
  refusé avant 6 étoiles, aura dans l'attribut d'équipe, talents verrouillés puis débloqués, verrou (coût et
  note conservée), jetons lâchés par les ennemis, clic (dégâts, limite par seconde), achat du clic automatique en
  gemmes et frappe automatique.
- `ui_smoke` : menus Forge (boutique), Enchantements, Forge des talents et Évolution, verrouillés puis débloqués,
  chaque bouton cliqué.

## 4. Invocation et boutique — fait

| Point du document | Existant | Changement |
| --- | --- | --- |
| Petite interface au-dessus de l'autel à l'approche (œufs de Pet Simulator) au lieu d'un menu plein écran | Entrer dans le cercle de l'autel ouvrait le menu d'invocation plein écran | Panneau au-dessus de chaque autel, visible à l'approche : vitrine avec les taux, coût, boutons ×1 / ×10 / AUTO et raccourcis **E / R / T** ; le bouton ⚙ ouvre les options (garanties, vente automatique). L'invocation automatique s'arrête en s'éloignant. La révélation des parchemins reste en plein écran, comme l'éclosion des œufs |
| Autel de saison au spawn | — | **Autel de saison** sur la place du village (à la place du coffre du jour) : jetons de fusion et potions le plus souvent ; accessoires Légendaire / Mythique, héros Mythiques (Chevalier Vert, Ignir) et Secrets (Sire Citrouille, Chevalier-Tempête) à faible taux ; **500 gemmes** ou **50 Robux** (produit « Tirage de saison ») le tirage |
| Jetons de fusion | — | Nouvel objet : remplace une copie manquante lors d'une fusion d'étoiles (évolution) |
| Amélioration du design des autels | 3 dalles carrées, socle, orbe, 4 piliers | Estrade ronde à trois gradins cerclés d'or, marches, cercle de runes, socle à huit pans et cristal qui tourne dans son anneau, quatre obélisques à runes flottantes et braseros, bannières, éclats de cristal (autels des mondes, d'évolution et de saison) |
| Héros jamais obtenus grisés dans le menu de l'autel | Taux en gris seulement | Carte et portrait en gris pour tout héros jamais obtenu (panneau et options de l'autel, autel de saison) |
| Coffre du jour = bouton de menu, plus sur la carte | Coffre posé sur la place, menu à l'approche | Bouton « COFFRE » dans la colonne de menus (pastille quand il est prêt) ; coffre et station retirés de la carte |

### Valeurs par défaut à valider

| Réglage | Valeur | Fichier |
| --- | --- | --- |
| Contenu et taux de l'autel de saison | jeton de fusion ×1 43,5 %, ×3 10 %, potions 44 %, accessoire Légendaire 1,5 %, Mythique 0,4 %, héros Mythique 0,25 % chacun, Secret 0,05 % chacun | `Config/Seasons.luau` |
| Saison en cours | « Saison des Moissons » | `Seasons.Current` |
| Accessoire de saison avec la réserve pleine | remplacé par 5 jetons de fusion | `SummonService.SeasonRoll` |
| Distance d'apparition du panneau d'autel | cercle de l'autel + 18 studs | `Controllers/Altars.luau` (`RANGE`) |

Le produit Robux « Tirage de saison » doit être créé dans le Creator Hub puis son identifiant renseigné dans
`Config/Shop.luau` (comme les autres produits).

### Vérifications

- `config.spec` : contenu de la saison (objets et héros existants, héros très rares à faible taux, jetons de fusion,
  poids = 100 %), 500 gemmes / 50 Robux, coffre du jour retiré de la carte, panneaux des autels.
- `world_smoke` : tirage de saison refusé loin de l'autel, accepté près de l'autel (500 gemmes), tirages Robux
  (révélation envoyée au client), fusion d'étoiles avec un jeton de fusion, refus sans copie ni jeton.
- `ui_smoke` : panneau de l'autel du Val qui apparaît à l'approche (vitrine complète), invocation à la touche E,
  panneau de l'autel de saison au village (et celui du Val masqué), bouton gemmes, révélation d'un tirage Robux
  (accessoire + héros).
- Vues : `docs/images/vues/28_autel_de_saison.jpg`, `29_autel_du_val.jpg`.

## 5. Interface et social — à venir
