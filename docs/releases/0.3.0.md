# BeamNg.weather 0.3.0 alpha 1

Configure rain directly from **Esc > Mods > BeamNg.weather** in BeamNG.drive 0.40.
No HUD app is required to access the settings page.

- Dedicated Vue settings page registered in the native pause menu's Mods category.
- All five rain presets, eight visual controls and three custom preset slots.
- Particle budget, collisions, wind and lighting options on the same page.
- Automatic settings saving and synchronization with the optional HUD panel.
- The menu entry is removed when the mod unloads, without removing other mods' entries.
- English interface; existing settings and custom presets remain compatible.

**Install:** replace `beamng_weather_hashk014.zip` in your active user folder's
`mods` directory, without extracting it. Restart the game and load a Freeroam
map, then press **Esc**, select **Mods** and choose **BeamNg.weather**.
If it is the only mod entry, its settings page opens when you select Mods.

Rain behaviour is unchanged. No windshield effects, puddles, friction changes,
wet materials, surface splashes or rain audio are included.

**Validation:** 20 local Python/LuaJIT tests, including integration with the
installed game's actual pause actions module. CI runs 19 portable tests and
skips that installed-game test. Both UI controllers pass Node checks, and the
Vue page was previewed with the game's Vue build and simulated game state.
**Opening the page through the actual in-game pause menu still needs testing.**

GitHub's automatic **Source code** ZIP is not the installable mod package.
