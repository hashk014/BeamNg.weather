# BeamNg.weather 0.5.2 alpha 1

Fix missing window droplets and untextured rectangles after the 0.5.1 glass scan fix, and correct the native cabin guard encoding.

- Give render meshes distinct names from their materials. The actual 0.5.1 game log reported a Material/ProceduralMesh namespace collision followed by repeated missing-material errors. It also confirmed successful detection of 7 glass meshes and 878 triangles.
- Check that both surface materials exist and are Material objects before creating visual meshes or activating cabin protection. A missing material now produces a diagnostic instead of untextured fallback geometry.
- Encode the cabin guard using positive fade values (`fadeDist > fadeDistEnd`). The previous negative value conflicts with the precipitation field's PositiveFloat validator. Update the original vertex shader to decode the guard and register a new shader version.
- Strengthen the synthetic engine boundary: load the actual surface material definitions, enforce shared object/material names, require valid mesh materials and apply positive-float validation. The prior tests omitted these behaviors and missed both defects.

**Install:** fully close BeamNG before replacing the old mod ZIP. Keep only `beamng_weather_hashk014.zip` in the active user folder's `mods` directory; remove older `(1)`/`(2)` copies. Restart the game to clear the previous material namespace conflict. Load a closed-roof car and let rain run outside the Escape menu before checking the windshield, side glass and cabin.

**Validation:** 44 local Python/LuaJIT tests, both Node UI checks, archive verification and SM5/SM6 vertex/pixel shader compilation pass. CI runs 43 portable tests and skips one installed-game integration. The old renderer reproduces the namespace collision with the strengthened test boundary. These checks do not confirm the corrected appearance or cabin exclusion in a running game; an in-game retest is still needed.

Existing limits remain: conservative cabin envelope, experimental glass/pose rendering and damage handling, no wiper clearing, puddles or friction changes.
