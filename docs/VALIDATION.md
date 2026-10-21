# Validation de la préversion 0.2.0

Date : 21 octobre 2026. Cible : BeamNG.drive 0.40.x.

## Vérifications réalisées

- Inspection en lecture seule d'une installation BeamNG.drive **0.40.1.0**.
- Chargement des datablocks via `loadJsonMaterialsFile`, chargement automatique
  du mod et cycle de vie vérifiés dans les scripts du jeu.
- Présence des noms de champs de rendu et de mouvement utilisés dans le binaire
  du jeu. Cette présence n'est pas une validation de leur comportement en jeu.
- Étude du code de précipitations Torque3D pour les atlas, vitesses, turbulences,
  orientation et atténuation. Le moteur BeamNG est un dérivé : un test en jeu
  reste nécessaire pour confirmer le comportement exact de cette version.
- **18 tests Python/LuaJIT 2.1, Lua 5.1** : cycle de vie, budgets, presets,
  persistance, migration depuis 0.1, transitions, pause, erreurs et reprise,
  nettoyage, absence d'effets de surface, textures et archive.
- Test Node du pont UI : réglage individuel sans écraser les autres options,
  presets, emplacements personnels, bornes et protection du slider pendant l'édition.
- Régénération déterministe des quatre textures, contrôle des en-têtes DDS,
  mipmaps complets, 16 variantes distinctes et texture de surface transparente.
- Vérification visuelle des textures originales, hors moteur.
- Liaison des shaders natifs `precipV.hlsl` et `precipP.hlsl` sous un nom propre
  au mod, suivant la création de `ShaderData` dans les scripts du jeu.
  Le shader applique lumière et atténuation ; sa compilation GPU reste à vérifier en jeu.
- Aperçu du vrai panneau et de son contrôleur avec l'**AngularJS 1.5.8 du jeu**,
  dans un navigateur local à état simulé. Clics vérifiés : preset Bruine,
  slider d'intensité, sauvegarde et chargement personnel, options avancées.
- Correction spécifique aux bornes interpolées des sliders dans AngularJS 1.5.8.
- ZIP reproductible, chemins sûrs et contenu identique aux sources.

![Panneau hors moteur, état de jeu simulé](images/gui-preview.png)

## Vérifications laissées au testeur

Le jeu n'a pas été piloté pour ce projet. Il reste à confirmer le rendu de la
pluie, le chargement des DDS et des datablocks par le moteur réel, les FPS,
les collisions et l'intégration de l'app dans la disposition UI du jeu.
Le réalisme visuel doit être apprécié en mouvement sur les cartes utilisées.

Les tests à moteur simulé ne valident pas les bindings C++, le GPU, les
phares ou la protection réelle de l'habitacle. L'éclairage est celui natif
des précipitations ; les unités de vitesse de l'interface sont relatives.
La version ne modifie ni friction ni matériaux et n'ajoute aucun effet
sur les vitres, aucune flaque ou éclaboussure de surface.

La liste détaillée de test en jeu se trouve dans le README.
