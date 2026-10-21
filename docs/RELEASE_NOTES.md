# BeamNg.weather 0.1.0 alpha 1

Première préversion destinée au test en jeu sur BeamNG.drive 0.40.x.

- Pluie visuelle automatique au chargement d'une carte.
- Panneau BeamNg.weather : marche/arrêt, intensité, trois qualités et collisions.
- Réglages conservés entre les sessions.
- Effets temporaires utilisant les ressources natives du jeu, sans remplacer les cartes.

Installation : déposer **beamng_weather_hashk014.zip**, sans le décompresser,
dans `mods` du dossier utilisateur actif (accessible depuis le launcher).
Relancer le jeu, activer le mod, puis charger une carte Freeroam.
Le panneau facultatif s'ajoute depuis l'éditeur UI Apps.

API et ressources inspectées dans le jeu 0.40.1.0. Logique testée en LuaJIT
avec moteur simulé, pont UI et archive contrôlés. **Rendu et compatibilité en
jeu à confirmer par le testeur.** Cette version n'ajoute pas de routes
mouillées, de changement d'adhérence, de son ou de gouttes sur les vitres.

Le ZIP « Source code » de GitHub n'est pas le mod installable.
