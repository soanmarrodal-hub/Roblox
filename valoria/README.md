# Valoria Champions

Jeu Roblox d'aventure chevaleresque et fantastique dans l'esprit d'**Anime Champion Simulator** : tu invoques des
héros (chevaliers, bêtes, mages, démons, dragons…), ils te suivent et combattent pour toi, tu les fais progresser et
tu pars à l'assaut de mondes de plus en plus difficiles, de la **Tour des Épreuves** et de **raids** à accessoires.
L'interface reprend l'esprit de **Pet Simulator 99** (gros boutons dodus, cercles lumineux devant les marchands,
cartes colorées par rareté) avec une touche pixel : icônes et portraits en pixel art, police « arcade », damiers.
Les héros et les monstres sont en **voxels « petit pixel »**, animés de façon procédurale.

Tout le jeu est en français.

![Les héros](docs/images/heroes.png)

## Démarrage rapide

1. Installer [Rojo 7.6](https://rojo.space/) (CLI + plugin Studio), ou utiliser directement la place fournie.
2. Construire la place depuis ce dossier :
   ```bash
   rojo build default.project.json -o build/ValoriaChampions.rbxl
   ```
   puis l'ouvrir dans Roblox Studio (une place déjà construite est fournie : `build/ValoriaChampions.rbxl`).
   Pour travailler en direct : `rojo serve` + plugin Rojo.
3. Dans Studio, **Paramètres du jeu > Sécurité** :
   - **Activer l'accès de Studio aux services d'API** (sauvegardes DataStore ; sans cela, la progression reste en
     mémoire pendant la session de test) ;
   - autoriser les **API d'images modifiables (EditableImage)** si l'option est proposée : les icônes et portraits
     pixel art sont dessinés à l'exécution. Sans elles, le jeu fonctionne avec des étiquettes de repli.
4. **Jouer**. Le serveur génère le village, les deux mondes et les arènes au démarrage (quelques secondes ; un écran
   de chargement patiente), puis « cuit » les modèles voxel en unions en tâche de fond.

## Le contenu

### Bourg-Lanterne, le village de départ

![Plan du village](docs/images/plan_village.png)

Place pavée et fontaine, couronnes de maisons à colombages, jardins, étals, charrettes, ruisseau et pont. Chaque
service est un **cercle lumineux** : y entrer ouvre le menu (comme les marchands de Pet Simulator 99).

| Lieu | Rôle |
| --- | --- |
| **Cercle des Runes** (nord) | Téléporteur : village, mondes et points de passage, déblocage des mondes |
| **Quartier de la Forge** (est) | Forge des talents (reroll des statistiques des héros), Enchanteresse (enchantements), Autel d'évolution (étoiles), Bijoutier (accessoires) |
| **Salle des raids** (ouest) | Portails de la Crypte et du Temple, quartier-maître (boutique des raids) |
| **Tour des Épreuves** (sud) | Ascension par étages, gardien des jetons (boutique), classements |
| **Place** | Tableau des quêtes du jour, coffre du jour, marché (gemmes), bibliothèque (index des héros) |

### Les mondes (téléporteur)

Le relief est généré (collines, falaises en terrasses, montagnes de bordure, rivière à méandres, côte découpée) ;
les zones d'ennemis sont des plateaux de plus en plus hauts et de plus en plus difficiles, reliés par des chemins.

| Monde 1 — **Val d'Automne** | Monde 2 — **Falaises des Wyvernes** |
| --- | --- |
| ![Val d'Automne](docs/images/plan_val_automne.png) | ![Falaises des Wyvernes](docs/images/plan_falaises.png) |
| Camp du Val (palissade, tours de guet), Prés de la Ferme, Champs de Citrouilles et moulin, Bois Roux, Gorge du Torrent (pont de cordes), Ruines du Guet, Plateau des Ogres, **Arène des Moissons** (boss : le Roi-Citrouille), château sur la montagne | Brisecôte et son phare, Crique des Épaves, Corniche des Harpies, Port Englouti, Aiguilles Marines reliées par des crêtes, Grotte de Corail, Bastion Noyé, **Nid de la Tempête** (boss : Vyrmax). Débloqué au rang 12, Roi-Citrouille vaincu, contre 750 000 or |

![Les camps d'arrivée](docs/images/plan_camps.png)

Chaque camp a son **autel d'invocation** (bannière du monde), un **donneur de quêtes** (Sire Aldric, Maëlle) et une
pierre de retour.

### Direction artistique et kit de sol

Voxel 3D stylisé, lisible comme un jeu Roblox : herbe sur terre comme des blocs, chemins pavés de pierre
beige, falaises en couches de roche, feuilles d'automne, petites fleurs. Une palette commune
(`src/ReplicatedStorage/Shared/Config/Palette.luau`) fixe les couleurs du terrain, du kit et des détails au sol.

- **Kit de sol modulaire** ([`kit/`](kit/README.md)) : dalles de 8 × 8 studs, chemins pavés à raccords
  automatiques (droit, virage, T, croix, extrémité), bordures, blocs de terrain de 4 et 8 studs, falaise de 16
  studs en strates, pente, escalier, rochers, décor séparé. Livré pour Roblox Studio (`.rbxmx` avec
  assembleur), en OBJ (un matériau, un atlas de textures) et avec sa documentation. Le camp du Val d'Automne
  est construit avec ces modules.
- **Terrain** : herbe verte et nappes d'herbe sèche dans le Val, chemins pavés beiges aux bords irréguliers
  (pierres surélevées, mousse et herbe dans les joints posées côté client), falaises en couches de roche
  d'épaisseurs inégales dans tous les lieux (ocre et beige dans le Val, ardoise et basalte sur les Falaises).

| | |
| --- | --- |
| ![Zone de démonstration du kit](kit/apercus/zone_demo_ensemble.jpg) | ![Planche des modules](kit/apercus/planche_modules.jpg) |

### Sol, détails et bâtiments

- **Matériaux haute résolution** : la place active les matériaux 2022 de Roblox (`MaterialService.Use2022Materials`)
  et l'herbe animée du terrain (`Terrain.Decoration`, `GrassLength`), réglés dans `default.project.json` (ces
  propriétés ne sont pas modifiables par script).
- **Terrain** : mélange de matériaux à petite échelle (bords de chemins irréguliers, taches de terre nue ou d'herbe
  sèche, affleurements rocheux sur les pentes, rives de boue ou de sable).
- **Place du village** : anneaux de dalles autour de la fontaine (joints visibles), rayons de pierre sombre vers les
  rues, bordures le long de la place, des rues et des quartiers.
- **Détails au sol** (client, `Controllers/GroundDetail`) : touffes d'herbe, herbes hautes, fleurs aux couleurs de
  chaque monde, cailloux, plaques de gravier, feuilles mortes, champignons, roseaux, coquillages, brindilles. Ils sont
  choisis selon le matériau du terrain sous chaque point, par tranches de 32 × 32 studs autour du joueur, sans
  collision ni ombre, jamais sous un bâtiment. Portée (56 à 128 studs) et densité suivent la qualité graphique choisie
  par le joueur.
- **Bâtiments** : maisons à colombages avec encorbellement et abouts de solives, fenêtres à croisées (vitres allumées
  ou sombres, volets, jardinières fleuries), croix de Saint-André, moellons du soubassement, porte cloutée et auvent,
  rives de toit, lucarne, oculus, cheminée, pots de fleurs, tas de bois, tonneau de pluie, lierre ; toits en tuiles,
  ardoise, chaume ou bardeaux et murs enduits. Tours à socle évasé, cordons et meurtrières ; forge (soufflet, auge,
  meule, râtelier d'épées) ; fontaine à margelle et gargouilles ; puits, étals, moulin, tentes et phare enrichis.

![Les bâtiments](docs/images/batiments.jpg)

### Héros et invocation

23 héros (12 dans le Val, 11 sur les Falaises), de Commun à Mythique, dont deux héros **Secrets** obtenus en
butin rare sur les boss. Chaque héros a sa classe, son élément, son style d'attaque (taille, arc, bâton, souffle,
charge…) et une **attaque spéciale** à recharge (volée, zone, saignement…), avec une **animation et des effets
propres à chaque héros** ; sa recharge et ses dégâts s'améliorent sur la fiche du héros (contre de l'or).

- Au-dessus de chaque héros : son **nom, son niveau et ses étoiles**.
- **Zone d'action** : cercle autour du joueur, petite au départ et améliorable (« Zone d'action ») ; les héros
  n'engagent que les ennemis qui s'y trouvent. Réglage **multi-cible** : chaque héros frappe un ennemi différent.
- Sur la fiche d'un héros possédé : **prendre son apparence** (le personnage du joueur devient ce héros).
- Invocation ×1 / ×10 (au moins un Rare), **garanties** Légendaire (120) et Mythique (700), chance améliorable.
- **Vente automatique** (recyclage à l'autel) des raretés choisies, Légendaires compris, **index** de collection
  avec récompense par monde.
- Révélation animée : parchemins qui tremblent selon la rareté, retournement, rayons pour les Légendaires et plus.

![Portraits](docs/images/portraits.png)

![Les 23 attaques spéciales (animation de chaque héros, de la préparation au coup)](docs/images/attaques_speciales.jpg)

### Progression

Déblocage progressif : **monde 1** fusion d'étoiles, **monde 2** enchantements, **monde 3** talents (`Config/Unlocks`).

- **Niveaux** (expérience gagnée en combattant) et **étoiles** (fusion de copies du même héros + or), jusqu'à
  6 étoiles, niveau maximum par étoile.
- **Améliorations** dans l'onglet **Forge** de la boutique : dégâts, or, vitesse d'attaque, critique, chance,
  expérience, dégâts aux boss, zone d'action, dégâts au clic, chance de jeton de talent, héros équipés en plus,
  places de héros, vitesse de marche.
- **Enchantements** (adaptés des *quirks* d'Anime Champions Simulator) contre des Runes du destin : 37
  enchantements (familles Vigueur, Avarice, Précision, Arcane, Fortune, Sagesse, Célérité, Glaneur en I/II/III,
  uniques comme Colosse ou Assassin, légendaires comme Titan ou Astral), tirage animé, **second emplacement à
  6 étoiles**, **aura** sur le héros selon la rareté de son meilleur enchantement.
- **Talents** (statistiques à la manière d'ACS) : Puissance, Vivacité et Précision notées de F à SSS, retirées à
  la **Forge des talents** avec des **Jetons de talent** (10 % de chance par ennemi vaincu, améliorable), talents
  verrouillables (un jeton de plus par verrou).
- **Clic** : chaque clic (sur l'écran ou le bouton « Frapper ») inflige à la cible une part des dégâts de
  l'équipe ; **clic automatique** à 500 gemmes ou 50 Robux.
- **Accessoires** de raid : 6 types (heaume, amulette, anneaux, perle, cape), 4 raretés, statistiques secondaires,
  **polissage** avec les jetons du raid, recyclage.
- **Rang du joueur** (titres d'Écuyer à Roi), gemmes à chaque rang.

### Combat

Comme dans Anime Champion Simulator : ton équipe te suit en formation ; touche un ennemi (ou laisse l'**attaque
automatique**) et tes héros courent vers lui, se placent selon leur portée et frappent au rythme de leur cadence.
Le serveur calcule les coups (10 fois par seconde) ; le client anime chaque attaque pour que l'impact tombe au bon
moment (projectiles pour l'arc, le bâton et le souffle). Chiffres de dégâts en pixels, critiques, capacités
spéciales, butin qui jaillit et vole vers le joueur. Les **boss** télégraphient des cercles d'attaque qui
**étourdissent** les héros s'ils restent dedans, puis entrent en rage. L'apparition et la défaite d'un boss de
monde ne sont annoncées qu'aux joueurs de ce monde, et sa barre de vie (ou le compte à rebours de sa
réapparition) ne s'affiche qu'à proximité (`Worlds.BossBarDistance`).

### Tour des Épreuves

Une salle par joueur sur une île flottante : nettoie l'étage avant la fin du chrono, un **gardien** tous les 10
étages, reprise tous les 10 étages, jetons à chaque étage et gemmes / runes / potions aux paliers. Records et
classement mondial sur le panneau du village.

### Raids (accessoires)

| Raid | Monde | Boss | Accessoires |
| --- | --- | --- | --- |
| **Crypte du Roi Déchu** | Val d'Automne | Morvald, le Roi Déchu | Heaume du Roi Déchu, Amulette spectrale, Anneau d'os |
| **Temple Englouti** | Falaises | Le Kraken ancestral | Anneau de corail, Perle abyssale, Cape du Léviathan |

1 à 4 joueurs (salon avec compte à rebours), 3 difficultés (Normal, Héroïque, Cauchemar) qui changent les PV et
la rareté des accessoires. Chaque raid est un **donjon de 5 salles** : 4 salles de vague puis la salle du boss,
reliées par 4 **salles de parcours** (plates-formes au-dessus d'un fossé : une chute ramène au début du parcours).
Une vague vaincue ouvre la porte de sa salle, la vague suivante commence quand un joueur entre dans la salle
suivante, et un joueur resté en arrière est ramené auprès du groupe. Temps imparti : 10 minutes (doublé). Plan et
réglages : `Raids.Layout` et `Raids.Plan` (`Config/Raids.luau`). Boutique des raids : coffres d'accessoires
(aléatoire ou au choix) et runes.

### Récompenses et boutique

Quêtes en chaîne par monde, 3 quêtes du jour, coffre de connexion (7 jours), cadeaux de temps de jeu, codes
(`VALORIA`, `CHEVALIER`, `DRAGON`, `LANTERNE`), potions (force, or, chance, savoir), marché en gemmes, produits et
passes Robux (Or ×2, Chance royale, Escouade royale, Invocation éclair, Grandes écuries, VIP).

## Galerie

Vues en perspective rendues hors de Roblox à partir des pièces et du terrain réellement construits par le serveur
(banc d'essai), avec les héros et les monstres voxel en situation. Les matériaux y sont imités par des textures
procédurales, et les détails au sol viennent du même module que dans le jeu. L'herbe animée propre à Roblox n'y est
pas dessinée.

### Le village

| | |
| --- | --- |
| ![Bourg-Lanterne vu du ciel](docs/images/vues/01_village_panorama.jpg)<br>Bourg-Lanterne vu du ciel | ![La place et sa fontaine](docs/images/vues/02_village_place.jpg)<br>La place et sa fontaine |
| ![Le Cercle des Runes (téléporteur)](docs/images/vues/03_cercle_des_runes.jpg)<br>Le Cercle des Runes (téléporteur) | ![Le Quartier de la Forge](docs/images/vues/04_quartier_forge.jpg)<br>Le Quartier de la Forge |
| ![La Salle des raids](docs/images/vues/05_salle_des_raids.jpg)<br>La Salle des raids | ![La Tour des Épreuves](docs/images/vues/06_tour_des_epreuves.jpg)<br>La Tour des Épreuves |

### Val d'Automne

| | |
| --- | --- |
| ![Le Camp du Val](docs/images/vues/07_val_camp.jpg)<br>Le Camp du Val | ![Le Val d'Automne](docs/images/vues/08_val_panorama.jpg)<br>Le Val d'Automne |
| ![Les Champs de Citrouilles](docs/images/vues/09_champs_citrouilles.jpg)<br>Les Champs de Citrouilles | ![Les Prés de la Ferme](docs/images/vues/10_pres_ferme.jpg)<br>Les Prés de la Ferme |
| ![Les Ruines du Guet](docs/images/vues/11_ruines_du_guet.jpg)<br>Les Ruines du Guet | ![Le Plateau des Ogres](docs/images/vues/12_plateau_des_ogres.jpg)<br>Le Plateau des Ogres |
| ![Arène des Moissons : le Roi-Citrouille](docs/images/vues/13_arene_des_moissons.jpg)<br>Arène des Moissons : le Roi-Citrouille |  |

### Falaises des Wyvernes

| | |
| --- | --- |
| ![Brisecôte et son phare](docs/images/vues/14_brisecote.jpg)<br>Brisecôte et son phare | ![Les Falaises des Wyvernes](docs/images/vues/15_falaises_panorama.jpg)<br>Les Falaises des Wyvernes |
| ![La Crique des Épaves](docs/images/vues/16_crique_des_epaves.jpg)<br>La Crique des Épaves | ![Le Port Englouti](docs/images/vues/17_port_englouti.jpg)<br>Le Port Englouti |
| ![Les Aiguilles Marines](docs/images/vues/18_aiguilles_marines.jpg)<br>Les Aiguilles Marines | ![La Grotte de Corail](docs/images/vues/19_grotte_de_corail.jpg)<br>La Grotte de Corail |
| ![Le Bastion Noyé](docs/images/vues/20_bastion_noye.jpg)<br>Le Bastion Noyé | ![Nid de la Tempête : Vyrmax](docs/images/vues/21_nid_de_la_tempete.jpg)<br>Nid de la Tempête : Vyrmax |

### Tour et raids

| | |
| --- | --- |
| ![Une salle de la Tour des Épreuves](docs/images/vues/22_salle_des_epreuves.jpg)<br>Une salle de la Tour des Épreuves | ![Raid : la Crypte du Roi Déchu](docs/images/vues/23_crypte_du_roi_dechu.jpg)<br>Raid : la Crypte du Roi Déchu |
| ![Raid : le Temple Englouti](docs/images/vues/24_temple_englouti.jpg)<br>Raid : le Temple Englouti | ![Donjon de la Crypte (vue en coupe)](docs/images/vues/25_donjon_crypte.jpg)<br>Donjon de la Crypte : 4 salles de vague, 4 parcours, la salle du boss (vue en coupe) |
| ![Donjon du Temple](docs/images/vues/26_donjon_temple.jpg)<br>Donjon du Temple Englouti | ![Une salle de parcours](docs/images/vues/27_salle_de_parcours.jpg)<br>Une salle de parcours (coupe à hauteur d'homme) |

## À configurer avant publication

- **Passes et produits** : renseigner les identifiants Roblox dans `src/ReplicatedStorage/Shared/Config/Shop.luau`
  (champ `id`, 0 = non configuré : le bouton affiche un message).
- **Musiques** : identifiants par zone dans `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/Sound.luau`
  (vides par défaut) ; les effets sonores utilisent des sons intégrés au client et peuvent être remplacés au même
  endroit.
- **Équilibrage** : tout est dans `src/ReplicatedStorage/Shared/Config/` (héros, ennemis, mondes, bannières,
  améliorations, bénédictions, accessoires, tour, raids, quêtes, récompenses, boutique, stations).

## Organisation du code

```
src/
  ReplicatedStorage/Shared/
    Config/        données du jeu (équilibrage, mondes, stations…)
    Logic/         formules pures : statistiques, progression, gacha, butin, quêtes, modèle du profil, détails au sol
    Voxel/         assembleur des modèles voxel + modèles générés (Models/) et portraits pixel
    Anim/          animation procédurale (démarches, attaques à poses clés, chaînes souples, clignements)
    Util/          signaux, aléatoire déterministe, formats (nombres, temps, texte UTF-8)
  ServerScriptService/Server/
    Main.server    démarrage des services
    Services/      données, joueurs, héros, invocations, combat, ennemis, boss, tour, raids, quêtes,
                   récompenses, boutique, téléportations, classements, cuisson des modèles, monde
    World/         relief, terrain, kit de sol, bâtiments, décors, village, mondes, arènes
  StarterPlayer/StarterPlayerScripts/Client/
    Main.client    démarrage du client
    UI/            thème, composants, pixel art, HUD, gestionnaire de menus
    Menus/         héros, invocation, forge, bijoutier, voyage, tour et raids, quêtes, récompenses, boutique…
    Controllers/   héros, ennemis, effets, stations, ambiance, décor animé, PNJ, sons, détails au sol
  ReplicatedFirst/ écran de chargement
tools/
  voxel/           modélisation voxel (Python) : héros, ennemis, décors, portraits, aperçus, plans, vues 3D
  ui/icons.py      icônes pixel art 16×16 de l'interface
  preview/         aperçus Lune (animations, reliefs, export du terrain, des détails au sol, vitrine des bâtiments)
  tests/           tests unitaires et bancs d'essai
  kit/             kit de sol : export .rbxmx et OBJ, aperçus, assembleur pour Studio
kit/               livrables du kit de sol (.rbxmx, OBJ, aperçus, documentation)
```

Le serveur fait autorité : les ennemis n'existent que sous forme de données côté serveur et sont dessinés par les
clients ; les actions du client passent par une seule fonction distante (`Action`) avec validation et limitation
de débit ; les profils sont sauvegardés avec verrou de session et les achats sont idempotents.

## Vérifications

```bash
TOOLS=/chemin/vers/outils ROBLOX_TYPES=/chemin/globalTypes.d.luau ./tools/check.sh
```

1. **Tests unitaires** (Lune) des formules partagées et des données de configuration.
2. **Banc d'essai de l'interface et des contrôleurs** (`tools/tests/ui_smoke.luau`) : HUD, 22 menus et
   contrôleurs construits avec de vraies instances Roblox (propriétés validées), chaque bouton cliqué, scénario
   de combat simulé (ennemis, coups, morts, butin, télégraphes), détails au sol posés autour du joueur.
3. **Banc d'essai du serveur** (`tools/tests/world_smoke.luau`) : le vrai serveur démarre, construit le village,
   les deux mondes et les arènes, puis un joueur simulé se connecte, invoque, s'équipe, s'améliore, combat, bat le
   boss, gravit la Tour, traverse les 5 salles d'un raid (chute dans un parcours comprise) et le gagne, polit un
   accessoire, fait évoluer un héros et se déconnecte.
4. **Kit de sol** : export du `.rbxmx`, relu et vérifié (emprises, collisions), assembleur du fichier exécuté.
5. **Analyse de types** stricte (luau-lsp) et **construction** de la place (Rojo).

Les plans vus de dessus et les vues de la galerie sont produits à partir des pièces réellement construites par le
banc d'essai du serveur (`WORLD_DUMP=parts.json`), puis `tools/voxel/site_render.py` (plans) et
`tools/voxel/game_views.py` (vues 3D : petit moteur de rendu logiciel avec ombres portées et textures procédurales des
matériaux, `tools/voxel/scene_render.py` ; terrain exporté par `tools/preview/terrain_dump.luau`, détails au sol par
`tools/preview/detail_dump.luau`). La planche des bâtiments : `tools/preview/buildings_dump.luau` puis
`tools/voxel/building_views.py`.

## Régénérer les ressources

```bash
python3 tools/voxel/build.py         # modèles voxel, portraits, planches docs/images/*.png
python3 tools/ui/icons.py            # icônes de l'interface + docs/images/icons.png
lune run tools/kit/export_kit.luau kit && python3 tools/kit/export_obj.py kit && python3 tools/kit/kit_views.py kit
                                     # kit de sol : .rbxmx, OBJ, aperçus (voir kit/README.md)
```

![Ennemis](docs/images/enemies.png)
![Décors](docs/images/props.png)
![Icônes](docs/images/icons.png)
