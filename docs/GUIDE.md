# Guide d'Astral Heist

## 1. Construire et ouvrir la place

```bash
rojo build default.project.json -o build/AstralHeist.rbxl   # place complète, prête à ouvrir dans Studio
rojo serve                                                    # synchronisation en direct avec le plugin Rojo
```

Rojo place :

| Instance Roblox | Source |
| --- | --- |
| `ReplicatedStorage.Shared` | `src/ReplicatedStorage/Shared` (configs, logique, visuels, réseau) |
| `ReplicatedStorage.Assets.HeroModels` | vide : c'est ici que vont les modèles importés (préservés par Rojo) |
| `ServerScriptService.Server` | `src/ServerScriptService/Server` |
| `ServerStorage.NaturePack` | `assets/nature/NaturePack.rbxm` |
| `StarterPlayerScripts.Client` | `src/StarterPlayer/StarterPlayerScripts/Client` |
| `ReplicatedFirst` | écran de chargement |

Réglages appliqués par le projet : `StreamingEnabled` (rayon 900 / minimum 220), éclairage `Future`,
réapparition en 5 s, interface conservée à la réapparition.

**Sauvegarde en Studio** : Paramètres du jeu > Sécurité > *Enable Studio Access to API Services*. Sans cela, le jeu
fonctionne avec un profil en mémoire (message d'avertissement dans la sortie). Le DataStore s'appelle
`AstralHeist_Players_v1` et utilise un verrou de session.

## 2. Importer les modèles des héros

Les 30 héros sont dans `assets/heroes/<Héros>/`. Les 12 premiers (Forêt et Désert) ont été convertis depuis les FBX
fournis ; les 18 autres (Ville Néon, Glacier, Volcan) ont été modélisés de façon procédurale à partir des fiches de la
bible. Tous ont le même format :

- `<Héros>.glb` : un maillage par partie animable, matériau PBR (couleur, normal, métal/rugosité) intégré ;
- `<Héros>_color.png`, `<Héros>_normal.png` : textures séparées (SurfaceAppearance manuelle si besoin) ;
- `<Héros>.json` : manifeste (hauteur, pivots des articulations, pièces lumineuses), compilé dans `Visuals/HeroRigs.luau`.

Pour chaque héros :

1. **Fichier > Importer en 3D** (3D Importer), sélectionner le `.glb`.
2. Importer avec les options par défaut (ne pas fusionner les maillages).
3. Renommer le modèle avec l'identifiant exact du héros.
4. Le glisser dans `ReplicatedStorage > Assets > HeroModels`.
5. Enregistrer la place.

Ordre conseillé : les 6 héros de la Forêt (tutoriel), puis le Désert, puis les autres îles. Un héros non importé
utilise sa figurine procédurale : on peut tester le jeu à tout moment.

Vérifications :

- le modèle doit contenir des MeshParts nommées `Body`, `Head`, `ArmL`, `ArmR`… et éventuellement `*_Glow` ;
- l'échelle d'import n'a pas d'importance (le jeu redimensionne selon la taille du héros) ;
- si un héros apparaît « en T » ou tourne autour d'un mauvais point, vérifier que les noms des MeshParts n'ont pas été
  modifiés (ils doivent correspondre aux groupes de `HeroRigs.luau`).

Identifiants : Leafin, Bramble, Cylla, Lumora, Thornix, Verdantis, Pyrion, Solmir, Zahir, Solara, Rajin, Helius,
Glitchi, Volta, Kairo, Synthia, Mekhar, Axiom, Floconi, Grizzlace, Kiriha, Aurelis, Hivernor, Kryovane, Tizzo,
Magmok, Embra, Cendrael, Vulkhar, Magnarok.

## 3. Le monde

Le monde est généré à chaque démarrage du serveur (terrain des îles, hub, ponts, monuments, décor du pack Nature) ;
l'écran de chargement attend la fin de la construction. Pour le voir en mode édition :

```lua
require(game.ServerScriptService.Server.World.WorldBuilder).Build()
```

Les réglages (densité de décor par île, taille des bases, graine) sont dans `Config/World.luau`. Les positions,
couleurs, éclairages et sous-zones des îles sont dans `Config/Islands.luau`. Le pack Nature est teinté par île
(`World.NatureTintMode = "Theme"`) ; mettez `"Keep"` si votre pack embarque ses propres couleurs.

## 4. Monétisation, codes et audio

- **Gamepasses et produits** : remplacer les `id = 0` de `Config/Shop.luau` par vos identifiants (Créateur >
  Monétisation). Avec `id = 0`, l'achat est simulé en Studio (`TestPurchasesInStudio = true`) et désactivé en ligne.
- **Codes** : `Config/Codes.luau` (`ASTRAL`, `HEIST`, `LEAFIN`, `TEMPETE` par défaut, date d'expiration facultative).
- **Audio** : `Config/Audio.luau`. Les effets utilisent des sons intégrés à Roblox ; collez vos `rbxassetid://` pour
  les musiques de zone, de tempête, de duel et de boss.

## 5. Équilibrage

| Fichier | Contenu |
| --- | --- |
| `Config/Rarities.luau` | production, puissance, niveau max, transport, temps au sol par rareté |
| `Config/Islands.luau` | multiplicateurs, rang requis et coût des portes |
| `Config/Economy.luau` | améliorations, coûts de niveau, hors ligne, XP, protection des nouveaux |
| `Config/Steal.luau` | temps de référence du duel, paliers, protections anti-frustration |
| `Config/Storms.luau` | fréquence et durée des tempêtes, mutations, ciel |
| `Config/Banners.luau` | taux affichés, pitié, coûts |
| `Config/Heroes.luau`, `Skills.luau`, `Enemies.luau` | héros, compétences, mobs, gardiens, boss |
| `Config/Quests.luau` | chaîne guidée, quotidiennes, hebdomadaires, calendrier, paliers d'index |

## 6. Tester en Studio

- Menu **Paramètres > Tests (Studio)** : *Ressources* (énergie, gemmes, éclats, XP) et *Tempête* (lance une tempête).
- En Studio, une tempête survient toutes les 2,5 à 4 minutes (20 à 30 minutes en ligne).
- Lancer un test à 2 joueurs (*Test > Serveur local*) pour les vols, la défense, l'interception et les échanges.
- Tests unitaires : `python3 tools/tests/run_tests.py` (CLI `luau`).

## 7. Performances (mobile)

- Paramètre **Qualité graphique** : nombre de modèles de héros affichés en même temps (70 / 45 / 24) et rayon d'affichage.
- Les modèles sont créés à la demande autour de la caméra, les animations ne tournent que dans un rayon de 140 studs.
- Chaque héros fait environ 18 000 triangles (moins de 20 000 par maillage, limite Roblox).

## 8. Architecture

**Serveur** (`Main.server.luau`) : charge les services dans l'ordre (`Init` puis `Start`) via `Registry`. Le serveur
fait autorité sur tout (dégâts, captures, vols, économie). Les entités (mobs, héros sauvages, boss, défenseurs) sont
des ancres invisibles portant des attributs ; le client les représente.

**Contrat client / serveur** :

- Remotes (`Shared/Net.luau`) : `DataSync`, `Notify`, `Announce`, `Telegraph`, `HitFx`, `SkillFx`, `PlayerFx`,
  `CarryState`, `DuelState`, `StealAlert`, `SummonResult`, `Cinematic`, `BossState`, `StormRecap`, `LevelUp`, `TradeState`
  vers le client ; `Attack`, `Skill`, `Dodge`, `Interact`, `Teleport`, `ReturnBase` et la fonction `Action` vers le serveur.
- Attributs du joueur : devises, rang, `Power`, `Production`, `Collector`, `Island`, `LeaderHero`, `Assists`, `Carrying`,
  `CD1..3`, `Charge`, `Heat`, `Gate_*`, `Pass_*`…
- Attributs de `Workspace` : `StormState`, `StormType`, `StormEndsAt`, `NextStormAt`, `StormBoostBy`, `StormGreat`,
  `DayClock`, `WorldReady`, et pour les événements d'îles `IslEvt_<île>`, `IslEvtEnd_<île>`, `IslEvtZone_Neon`.
- `ReplicatedStorage.MapMarkers` : boss, héros annoncés et porteurs publiés chaque seconde par le serveur (mini-carte et
  carte fonctionnent même hors du rayon de streaming).
- Étiquettes : `Entity`, `Interactable`, `Pedestal`, `CampPedestal`, `VaultPedestal`, `GuardianSpot`, `StatueSpot`, et les
  étiquettes d'animation du décor (`Spin`, `FloatRock`, `NightLight`, `JumpPad`, `GateBarrier`…).
- Les horodatages publiés au client utilisent `Workspace:GetServerTimeNow()`.

**Client** (`Main.client.luau`) : contrôleurs `Data`, `Sound`, `HUD`, `Menus`, `Combat`, `FX`, `HeroDisplay`, `Enemies`,
`Interact`, `Environment`, `Cosmetics`, `Overlays`, `Cinematics`. Les menus sont des pages indépendantes
(`UI/Menus/*.luau`).

## 9. Pipeline 3D

- `tools/hero_pipeline/heropipe.py` : conversion des FBX générés (nettoyage des coques internes, segmentation en parties
  animables, peinture projetée depuis les planches de personnage, décimation, dépliage UV, cuisson PBR, yeux anime).
  Entrées via `ASTRAL_FBX_DIR` et `ASTRAL_SHEETS_DIR`, lancement : `python3 tools/hero_pipeline/run_heroes.py <sortie> <cache>`.
- `tools/hero_pipeline/sdfhero.py` + `sdf_neon.py`, `sdf_glacier.py`, `sdf_volcano.py` : modeleur procédural par champs de
  distance signée (formes lissées, motifs, yeux, AO et normales cuits depuis le champ analytique).
  `python3 tools/hero_pipeline/run_sdf_heroes.py [Nom…]`.
- `tools/hero_pipeline/make_rigs.py` : régénère `Visuals/HeroRigs.luau` depuis les manifestes.
- `tools/hero_pipeline/rbxm_strip.py` : retire du pack Nature les propriétés `Tags` que Rojo ne sait pas lire.

## 10. Avant de publier

- [ ] Accès aux services d'API activé, place publiée une première fois.
- [ ] Identifiants de gamepasses et produits renseignés.
- [ ] 30 héros importés dans `Assets/HeroModels`.
- [ ] Musiques choisies dans `Config/Audio.luau`.
- [ ] Questionnaire d'expérience (classement d'âge) et taux d'invocation affichés (déjà visibles dans le menu Invocation).
- [ ] Test à plusieurs joueurs sur un serveur Roblox privé.
