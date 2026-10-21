# BeamNg.weather

Mod de **pluie atmosphérique pour BeamNG.drive 0.40.x**.
La version **0.2.0** ajoute trois volumes de précipitations, des textures
originales à 16 variantes par couche, cinq ambiances et trois presets personnels.
La pluie démarre automatiquement après le chargement de la carte.

**Préversion à tester en jeu.** Les points d'intégration ont été inspectés dans
une installation locale **0.40.1.0**. Les nouveaux atlas sont contrôlés hors moteur.
Les tests automatisés valident la logique et le ZIP, pas le rendu dans le moteur.
Le test en jeu est volontairement laissé à l'utilisateur.

## Télécharger et installer

1. Télécharger **[beamng_weather_hashk014.zip](https://github.com/hashk014/BeamNg.weather/releases/download/v0.2.0-alpha.1/beamng_weather_hashk014.zip)** depuis les [releases](https://github.com/hashk014/BeamNg.weather/releases).
2. Dans le launcher BeamNG : **Manage User Folder / Gérer le dossier utilisateur**, puis ouvrir le dossier actif.
3. Copier le ZIP **sans le décompresser** dans le sous-dossier `mods`.
   Créer ce sous-dossier s'il n'existe pas. Ne rien placer dans le dossier Steam du jeu.
4. Relancer le jeu, vérifier que le mod est actif dans le gestionnaire de mods,
   puis charger une carte en **Freeroam**. Attendre quelques secondes : la pluie
   doit commencer automatiquement.

Le ZIP contient directement `art/`, `lua/`, `scripts/` et `ui/`. Le ZIP « Source code »
généré automatiquement par GitHub est destiné aux développeurs.
Garder le nom `beamng_weather_hashk014.zip` lors des mises à jour.

## Régler la pluie

Dans le menu **UI Apps / Applications UI**, ouvrir l'éditeur de disposition,
choisir **Ajouter une app**, puis chercher **BeamNg.weather**. Le panneau est
facultatif : il n'est pas nécessaire pour faire tomber la pluie.
Pour une mise à jour depuis 0.1, remplacer l'ancien ZIP du même nom, puis
agrandir l'ancien panneau ou le retirer et l'ajouter à nouveau. Les options
avancées et les presets personnels sont accessibles en faisant défiler le panneau.

![Aperçu du panneau réel avec un état de jeu simulé, hors de BeamNG](docs/images/gui-preview.png)

### Ambiances et presets personnels

| Preset | Aspect recherché |
| --- | --- |
| Bruine | Petites gouttes, chute plus lente, faible densité |
| Pluie douce | Gouttes discrètes, rythme régulier |
| Averse | Gouttes plus marquées, densité variable |
| Déluge | Densité élevée, grosses gouttes et chute rapide |
| Grain | Variations de densité et turbulence plus prononcées |

Un clic applique l'ambiance et active la pluie. Le budget de particules et les
collisions restent au choix du joueur. Modifier l'aspect à la main passe le
preset à un état personnalisé. Les trois emplacements **Perso** permettent
de sauver, remplacer, charger et effacer ses réglages. Ils sont conservés entre
les sessions. Chaque emplacement garde l'aspect de la pluie et ses options
de vent/lumière ; le budget, les collisions et la durée de transition sont
des préférences globales.

### Réglages disponibles

- **Activer / Arrêter la pluie** : ajoute ou retire uniquement les effets du mod.
- **Intensité** : de 0 à 100 %. Zéro retire les effets immédiatement.
- **Taille des gouttes** : de 0,5 à 2 fois la taille du profil de base.
- **Vitesse de chute** : de 0,4 à 1,8 fois la vitesse de base, avec une plage
  différente pour chaque couche. Ce multiplicateur n'est pas une mesure en m/s.
- **Budget de particules** : éco 2 400, équilibré 6 000, élevé 12 000, ultra 20 000.
  Le compteur indique la somme réellement demandée aux trois objets.
- **Turbulence**, **variations de densité**, **visibilité des gouttes** et
  **étendue de la pluie** sont accessibles dans les réglages avancés.
- **Transition entre intensités** : de 0 à 5 secondes pour une approche progressive
  de la nouvelle densité. L'arrêt reste immédiat.
- **Suivre le vent existant** : les particules suivent le vent déjà présent.
  Ce mod ne modifie pas le vent de la carte ou les forces sur les véhicules.
- **Adapter à la lumière du ciel** : active l'éclairage natif des précipitations.
  Il ne s'agit pas d'une simulation optique des gouttes sous tous les phares.
- **Collisions avec le décor** : demande les collisions natives des précipitations.
  Les désactiver peut améliorer les performances, mais la pluie peut traverser les abris.

Les réglages sont sauvegardés dans `settings/beamngWeather_hashk014.json`
dans le dossier utilisateur actif. Ils sont conservés entre les sessions.
Si la pluie a été arrêtée, la réactiver dans le panneau lors du prochain test.

Commandes de secours dans la console, contexte **GE Lua** :

```lua
extensions.beamngWeather_hashk014.setEnabled(true)
extensions.beamngWeather_hashk014.setIntensity(1)
extensions.beamngWeather_hashk014.setEnabled(false)
dump(extensions.beamngWeather_hashk014.getState())
```

Si l'extension n'est pas chargée, vérifier d'abord que le mod est actif.
Un rechargement Lua avec **Ctrl+L** peut être nécessaire après une activation à chaud.

## Périmètre de cette version

- Trois objets natifs `Precipitation` utilisent des textures originales :
  gouttes fines proches, corps de l'averse et volume plus large en arrière-plan.
- Chaque atlas possède 16 variantes de longueur, largeur et transparence,
  avec des extrémités atténuées et une chaîne complète de mipmaps DDS.
- La taille, la vitesse et la sensibilité au vent diffèrent entre les couches.
  Des variations lentes et continues évitent une densité totalement figée.
- Le moteur suit la caméra et oriente les gouttes selon leur mouvement et
  celui de la caméra, y compris en caméra libre.
- Le mod lie les shaders de précipitation déjà fournis par le jeu pour
  l'éclairage et l'atténuation à distance, sans redistribuer ces shaders.
- Aucun fichier de carte, effet météo existant ou matériau n'est remplacé.
- Les objets sont temporaires (`canSave = false`) et supprimés à l'arrêt,
  au changement de carte et au déchargement de l'extension.
- Aucun effet de pare-brise, aucune flaque et aucune modification de friction
  ou d'adhérence. Aucun matériau humide, aucune éclaboussure de surface ni son.
- Le comportement des précipitations dans l'habitacle et sous les abris dépend
  du moteur et des collisions de la carte. Les collisions ne garantissent pas
  une protection réaliste du pare-brise.
- Les autres mods météo peuvent ajouter leurs propres effets en parallèle.
  Pour un premier test reproductible, activer uniquement ce mod.

## Test en jeu à effectuer

1. Charger Gridmap v2, puis West Coast USA, avec ce mod seul.
2. Vérifier la pluie depuis la caméra extérieure, puis en caméra libre.
3. Tester les cinq ambiances, arrêt/reprise, intensité zéro et les quatre budgets.
4. Faire varier les huit sliders, puis sauvegarder/charger un preset Perso.
   Redémarrer le jeu et vérifier que ce preset est toujours présent.
5. Vérifier les abris avec et sans collisions, puis la caméra intérieure.
6. Changer de carte, faire un reset véhicule et recharger Lua avec Ctrl+L.
7. Désactiver le mod, puis redémarrer le jeu pour vérifier sa suppression complète.
8. Relever les FPS et toute erreur contenant `beamngWeather_hashk014` dans
   `beamng.log`, à la racine du dossier utilisateur actif.

Pour signaler un problème : version exacte du jeu, carte, autres mods actifs,
capture/vidéo et extrait du journal autour de l'erreur. Le panneau qui indique
« Pluie en cours » signifie que les objets ont été créés, pas qu'un humain a
vérifié leur rendu.

## Sources et construction

```text
mod/lua/ge/extensions/           Contrôleur GE Lua
mod/scripts/                    Chargement automatique
mod/ui/modules/apps/            Panneau AngularJS du jeu
mod/art/                        Textures DDS et datablocks originaux
tests/                          Tests LuaJIT et pont UI avec moteur simulé
tools/build.py                  Construction déterministe du ZIP
tools/textures.py               Générateur procédural des textures
```

Python 3.12 pour les outils, Node.js pour la vérification JavaScript.
Aucune dépendance Python/Node n'est nécessaire pour jouer.

```sh
python -m pip install -r requirements-dev.txt
python tools/textures.py --check
python -m unittest discover -s tests -v
node --check mod/ui/modules/apps/BeamngWeatherHashk014/app.js
node tests/test_ui.js
python tools/build.py
```

Le mod installable et son SHA-256 sont produits dans `dist/`. Le workflow
GitHub Actions exécute les mêmes contrôles et conserve le ZIP comme artefact.
Voir [docs/VALIDATION.md](docs/VALIDATION.md) pour la portée des vérifications.

## Références et licence

Projet original sous [licence MIT](LICENSE), y compris les textures générées
par `tools/textures.py`. Aucune texture du jeu n'est redistribuée.
Ce projet n'est pas affilié à BeamNG GmbH.

Références : [documentation des datablocks](https://documentation.beamng.com/modding/levels/level_formats/datablocks/),
[objets de l'éditeur](https://documentation.beamng.com/world_editor/tools/create_object/).
Les structures et API ont également été inspectées en lecture seule dans les
scripts et archives de l'installation locale 0.40.1.0, notamment
`core/modmanager.lua`, `core/camera.lua`, `core/environment.lua`,
`editor/createObjectTool.lua`, l'app `Winds` et les précipitations de Jungle Rock Island.
Les concepts de mouvement et d'orientation ont aussi été étudiés dans
[le moteur Torque3D](https://github.com/TorqueGameEngines/Torque3D/blob/development/Engine/source/T3D/fx/precipitation.cpp).
