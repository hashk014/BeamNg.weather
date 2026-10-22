# BeamNg.weather 0.5.1 alpha 1

Fix the glass scan stopping with `Too many glass triangles`, leaving zero detected windows and zero surface droplets in 0.5.0.

- Select each triangle range using the vehicle's actual material table. Inherited JBeam deformation options no longer cause an entire mixed-material mesh to be treated as glass when material names are available.
- Remove duplicate primitive ranges and repeated indexed triangles. Exclude window handles, switches, racing nets, lamp glass and invisible/interior glass.
- For genuine high-detail glass above 30,000 candidate triangles, distribute a bounded sample across all detected panes instead of disabling every window effect. The GUI reports when sampling is active; sliding can be shorter across omitted triangles.
- Write scan counts and failures to `beamng.log` under `beamngWeather_glass` to make further game reports diagnosable.

**Install:** close BeamNG, remove the previous mod ZIP, including copies ending in `(1)` or `(2)`, and install this ZIP as `beamng_weather_hashk014.zip`. Keep exactly one copy in the active user folder's `mods` directory. Restart, load a closed-roof vehicle, enable rain and close Escape for a few seconds. Check **Esc > Mods > BeamNg.weather > Vehicle windows** for detected panes and surface droplets.

**Validation:** 41 local Python/LuaJIT tests and both Node UI controller checks pass. Five regression tests cover material selection, duplicate ranges, duplicate triangles, a 32,002-triangle vehicle and material-name fallback. Two regressions reproduce the reported error with the old scanner and pass with the new one. CI runs 40 portable tests and skips one installed-game integration test. Archive contents and texture generation are checked. The native render and FPS still require an in-game retest; the user's screenshot confirms the old scan failure, not the corrected appearance.

The cabin envelope, glass damage/openings, transparency and droplet renderer remain experimental. No road wetness, puddles, friction or wiper clearing is added.
