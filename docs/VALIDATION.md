# Validation de la préversion 0.1.0

Date : 21 octobre 2026. Cible : BeamNG.drive 0.40.x.

## Vérifications réalisées

- Inspection en lecture seule d'une installation BeamNG.drive **0.40.1.0**.
- Présence de `rain_drop`, `rain_medium` et de leurs textures dans le jeu.
- Chargement `scripts/<nom>/modScript.lua` et mode de déchargement manuel
  vérifiés dans `core/modmanager.lua`.
- Création d'objets, datablocks et caméra vérifiés dans les scripts du jeu.
- Exécution de la logique dans **LuaJIT 2.1, Lua 5.1**, avec un moteur simulé :
  démarrage automatique, budget, caméra, arrêt/reprise, réglages invalides,
  transitions carte/menu, sérialisation, suppression d'un objet, absence de
  datablock, échec de création partielle, persistance des réglages et désactivation.
- Vérification du pont UI : réception d'état, commandes, bornes numériques,
  sélection de qualité limitée aux valeurs autorisées.
- Construction reproductible et intégrité du ZIP, chemins relatifs sûrs,
  contenu identique aux sources, absence de dossier enveloppe.

## Vérifications laissées au testeur

Le jeu n'a pas été lancé ni piloté pour ce projet. Il reste à confirmer le
rendu, les performances, les collisions, le comportement en habitacle,
l'apparition du panneau dans l'éditeur UI et l'absence d'erreurs en jeu.
Les tests sur moteur simulé ne valident pas les bindings C++ ou le rendu GPU.
La liste de test détaillée se trouve dans le README.
