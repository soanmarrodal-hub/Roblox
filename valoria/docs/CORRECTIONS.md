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

## 2. Héros — à venir

## 3. Progression — à venir

## 4. Invocation et boutique — à venir

## 5. Interface et social — à venir
