# BeamNg.weather 0.4.0 alpha 1

Fix the pause menu connection and configure native clouds alongside rain.

- Fix preset and setting requests in **Esc > Mods > BeamNg.weather**. The page now calls the game's generic Lua bridge instead of accessing an unregistered function signature. Every request returns the applied state or a diagnostic.
- Classic gray interface with orange controls in both the pause page and optional HUD.
- Native clouds: **Follow rain intensity** (default), **Manual cloud cover**, or **Keep map settings**. Automatic coverage ranges from 60% to 100% with rain intensity. Manual mode allows 0% to 100%.
- Preserve cloud settings in custom profiles. Restore the previous sky when rain stops, the map ends, or the extension unloads. Unsupported or locked cloud layers show a separate warning.
- Replace incompatible uncompressed DDS atlases with original DXT5/BC3 atlases, retaining all mipmaps and 16 variants per layer.
- Replace deprecated precipitation shaders, which produced DirectX compilation errors in the previous version, with original standalone HLSL shaders.

**Install:** close BeamNG, replace `beamng_weather_hashk014.zip` in the active user folder's `mods` directory, then restart. Do not extract it or keep a second old copy. Open **Esc > Mods > BeamNg.weather** after loading a Freeroam map. Existing settings and custom presets are retained.

**Validation:** 24 local Python/LuaJIT checks, both UI controller checks, independent BC3 decoding, and offline HLSL compilation. Local checks use the actual installed pause actions module and generic Vue Lua bridge, with a mocked engine boundary. CI skips the installed-game integration and runs 23 portable Python tests. The GUI was checked in a browser with simulated state. Actual game rendering, GPU bindings and native cloud appearance still require in-game testing.

No windshield effects, puddles, friction changes, wet materials, surface splashes or rain audio are included. GitHub's automatic **Source code** ZIP is not the installable mod package.
