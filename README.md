# BeamNg.weather

Un premier mod de **pluie visuelle pour BeamNG.drive 0.40.x**.
La pluie démarre automatiquement une fois la carte chargée. Un petit panneau
permet de l'arrêter et de régler son intensité, sa densité et les collisions
avec le décor.

**Préversion à tester en jeu.** Les API, les datablocks et les textures ont été
vérifiés dans une installation locale **0.40.1.0**. Les tests automatisés
valident la logique et le ZIP, pas le rendu dans le moteur. Le test en jeu est
volontairement laissé à l'utilisateur.

## Télécharger et installer

1. Télécharger **[beamng_weather_hashk014.zip](https://github.com/hashk014/BeamNg.weather/releases/download/v0.1.0-alpha.1/beamng_weather_hashk014.zip)** depuis les [releases](https://github.com/hashk014/BeamNg.weather/releases).
2. Dans le launcher BeamNG : **Manage User Folder / Gérer le dossier utilisateur**, puis ouvrir le dossier actif.
3. Copier le ZIP **sans le décompresser** dans le sous-dossier `mods`.
   Créer ce sous-dossier s'il n'existe pas. Ne rien placer dans le dossier Steam du jeu.
4. Relancer le jeu, vérifier que le mod est actif dans le gestionnaire de mods,
   puis charger une carte en **Freeroam**. Attendre quelques secondes : la pluie
   doit commencer automatiquement.

Le ZIP contient directement `lua/`, `scripts/` et `ui/`. Le ZIP « Source code »
généré automatiquement par GitHub est destiné aux développeurs.
Garder le nom `beamng_weather_hashk014.zip` lors des mises à jour.

## Régler la pluie

Dans le menu **UI Apps / Applications UI**, ouvrir l'éditeur de disposition,
choisir **Ajouter une app**, puis chercher **BeamNg.weather**. Le panneau est
facultatif : il n'est pas nécessaire pour faire tomber la pluie.

- **Activer / Arrêter la pluie** : ajoute ou retire uniquement les effets du mod.
- **Intensité** : de 0 à 100 %. Zéro retire les effets.
- **Qualité** : légère (1 200 particules maximum), équilibrée (2 800), dense (5 000).
  La valeur par défaut est 65 % en qualité équilibrée.
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

- Deux objets natifs `Precipitation`, proches de la caméra, utilisent les
  datablocks `rain_drop` et `rain_medium` fournis par le jeu.
- Les effets suivent la caméra, y compris en caméra libre.
- Aucun fichier de carte, effet météo existant ou matériau n'est remplacé.
- Les objets sont temporaires (`canSave = false`) et supprimés à l'arrêt,
  au changement de carte et au déchargement de l'extension.
- La version ne simule pas les routes mouillées, l'aquaplanage, les flaques,
  les gouttes sur les vitres, les essuie-glaces ou le son de pluie.
- Le comportement des précipitations dans l'habitacle et sous les abris dépend
  du moteur et des collisions de la carte. Les collisions ne garantissent pas
  une protection réaliste du pare-brise.
- Les autres mods météo peuvent ajouter leurs propres effets en parallèle.
  Pour un premier test reproductible, activer uniquement ce mod.

## Test en jeu à effectuer

1. Charger Gridmap v2, puis West Coast USA, avec ce mod seul.
2. Vérifier la pluie depuis la caméra extérieure, puis en caméra libre.
3. Tester arrêt, reprise, intensité zéro, intensité maximum et les trois qualités.
4. Vérifier les abris avec et sans collisions, puis la caméra intérieure.
5. Changer de carte, faire un reset véhicule et recharger Lua avec Ctrl+L.
6. Désactiver le mod, puis redémarrer le jeu pour vérifier sa suppression complète.
7. Relever les FPS et toute erreur contenant `beamngWeather_hashk014` dans
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
tests/                          Tests LuaJIT et pont UI avec moteur simulé
tools/build.py                  Construction déterministe du ZIP
```

Python 3.12 pour les outils, Node.js pour la vérification JavaScript.
Aucune dépendance Python/Node n'est nécessaire pour jouer.

```sh
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
node --check mod/ui/modules/apps/BeamngWeatherHashk014/app.js
node tests/test_ui.js
python tools/build.py
```

Le mod installable et son SHA-256 sont produits dans `dist/`. Le workflow
GitHub Actions exécute les mêmes contrôles et conserve le ZIP comme artefact.
Voir [docs/VALIDATION.md](docs/VALIDATION.md) pour la portée des vérifications.

## Références et licence

Projet original sous [licence MIT](LICENSE). Les assets BeamNG sont uniquement
référencés à l'exécution et restent la propriété de leurs auteurs.
Ce projet n'est pas affilié à BeamNG GmbH.

Références : [documentation des datablocks](https://documentation.beamng.com/modding/levels/level_formats/datablocks/),
[objets de l'éditeur](https://documentation.beamng.com/world_editor/tools/create_object/).
Les structures et API ont également été inspectées en lecture seule dans les
scripts et archives de l'installation locale 0.40.1.0, notamment
`core/modmanager.lua`, `core/camera.lua`, `core/environment.lua`,
`editor/createObjectTool.lua`, l'app `Winds` et les précipitations de Jungle Rock Island.

