# BeamNg.weather 0.5.3 alpha 1

Address droplets appearing over the rear seat instead of the windows, cabin rain, and rectangular nearby particles while driving.

- Convert GPU mesh export coordinates from glTF Y-up to BeamNG Z-up before transforming to the vehicle frame: `(x, y, z)` becomes `(x, -z, y)`. The same corrected geometry now supplies glass particle positions and the cabin exclusion envelope. The installed native glTF exporter consumes the GPU vertices directly and exports vehicle directions in the corresponding Y-up convention.
- Add explicit grayscale `opacityMap` textures for the PBR glass and near-rain materials. Their RGB channels now contain the droplet silhouette, matching the color texture's alpha. A base-color alpha channel alone was not a complete PBR opacity setup.
- Preserve material-name separation and the positive native guard encoding from 0.5.2. Log the converted cabin bounds for further diagnosis.
- Extend the synthetic GPU boundary to return glTF coordinates. Check glass-plane attachment and cabin bounds for translated, turned and rolled vehicles. The previous decoder fails this new regression. Check every opacity pixel against the source alpha and verify both materials reference the maps.

**Install:** fully close BeamNG, replace the previous mod ZIP with this one, keep only one installed copy, and restart. Load a closed-roof vehicle. Let rain run outside Escape, then check the windshield, side windows, rear-seat area and nearby airborne rain while driving and after leaving the vehicle.

**Validation:** 46 local Python/LuaJIT tests and both Node UI checks pass; all eight texture outputs regenerate deterministically and the ZIP matches the source. CI runs 45 portable tests and skips the installed-game integration. The user's 0.5.2 log confirms successful glass detection without the earlier missing-material errors, and their visual report identifies the remaining placement/transparency symptoms. The corrected 0.5.3 appearance and cabin exclusion still need an in-game retest; synthetic geometry tests are not GPU rendering evidence.

Reference for opacity: [BeamNG materials v1.5](https://documentation.beamng.com/modding/materials/materials_1.5/).

The cabin envelope and glass renderer remain experimental. No wiper clearing, road wetness, puddles or friction changes are added.
