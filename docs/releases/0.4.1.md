# BeamNg.weather 0.4.1 alpha 1

Stronger native cloud cover and reliable in-panel option lists.

- Correct native cloud coverage to use BeamNG 0.40's **0–3** range. The previous release stopped at 1, only one third of the native range.
- Automatic clouds now use **2.4–3** as rain intensity rises, producing a much stronger overcast setting. Downpour reaches the native maximum, 3.
- Manual 0–100% cloud control now maps to native 0–3. Percentages represent the native setting range, not measured sky occlusion. Existing saved settings and profiles are retained.
- Replace native browser popup selects with expandable lists rendered inside the pause page and optional HUD. Cloud mode and particle budget options open inline, survive periodic state updates, and close after selection. Keyboard users can Tab to options, select with Enter/Space, or close the list with Escape.
- Previous cloud values are still restored when rain stops, the map ends, or the mod unloads. Wind, sun, materials and vehicle physics remain untouched.

**Install:** close BeamNG, replace `beamng_weather_hashk014.zip` in the active user folder's `mods` directory, then restart. Do not extract it or retain a second old ZIP. Load a Freeroam map and open **Esc > Mods > BeamNg.weather**.

**Validation:** 25 local Python/LuaJIT tests, both UI controller checks, and browser checks of the actual Vue/Angular components with simulated engine state. The native 0–3 cloud range was verified in the installed game's own environment panel. CI runs 24 portable Python tests and skips one installed-game integration test. Actual in-game cloud appearance and input behavior still require a gameplay check.

No windshield effects, puddles, friction changes, wet materials, surface splashes or rain audio are included.
