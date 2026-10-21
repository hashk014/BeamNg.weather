# BeamNg.weather 0.5.0 alpha 1

Experimental cabin protection and 3D droplets on detected vehicle windows.

- Detect exterior glass from the active vehicle's GPU mesh. Cover named windshields, rear and side windows, and glass roofs. Interior duplicates, lamps, mirrors, wipers and trim are excluded.
- Attach normal-mapped bead particles to glass triangles. Vehicle-relative rainfall determines which panes receive more water; gravity and tangential airflow change sliding direction and speed, including reversing and sideways movement.
- Protect the cabin with a conservative envelope derived from the detected glass. A guarded native shader and a bounded near-rain mesh keep airborne drops outside that envelope, without adding physical colliders. Protection is active near the player's vehicle, within a 12 m camera guard radius.
- Static shelter checks stop new glass droplets under roofs. Existing beads drain and fade; nearby airborne drops are clipped below the sampled roof height. Collision behavior still depends on the map's collision geometry.
- Add **Vehicle windows** controls in Esc > Mods and the optional HUD: cabin protection, glass droplets, amount and size. Store these options in custom presets.
- Use the F11 map `rain_coverage` volume (or West Coast's `WCA_rain`) as the ambient layer profile when available, with a mod fallback elsewhere. Read the map profile without modifying its objects.
- Keep the native distant rain, cloud controls and English classic interface. Reserve part of the existing airborne particle budget for near rain. Surface droplets have a separate quality-dependent cap.
- Clean up meshes and GPU snapshots on stop, vehicle reset/switch, map changes, Lua reload and unload. If glass scanning fails, show a diagnostic and retain native airborne rain.

**Install:** close BeamNG, replace `beamng_weather_hashk014.zip` in the active user folder's `mods` directory, then restart. Load a closed-roof car, enable rain and open **Esc > Mods > BeamNg.weather > Vehicle windows**. Close Escape to let the simulation run; allow a few seconds for glass scanning and accumulation.

**Limits:** this is a new experimental renderer. Named exterior glass must be detectable. Open-top cars need cabin protection disabled. The cabin envelope is conservative, not a simulation of door/window openings. Severe deformation, shattered/opening windows and unconventional vehicle meshes need validation; reset after damage. Water beads use geometry, alpha and normals rather than full optical refraction. Wiper clearing is not implemented.

**Validation:** 36 local Python/LuaJIT tests, both UI controller checks, deterministic texture generation, and offline SM5/SM6 HLSL compilation. Synthetic 3D tests cover five glass surfaces, forward/reverse flow, cabin exclusion, shelter, pause, bounds, GPU-snapshot cleanup, failure fallback, pose attachment and budgets. CI runs 35 portable tests and skips one installed-game integration test. Real game rendering, mesh orientation, transparency sorting and FPS have not been tested for this version and remain for the gameplay tester.

No puddles, road wetness, friction/grip changes, ground splashes or rain audio are included.
