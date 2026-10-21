# Validation: 0.4.0 experimental release

Date: October 21, 2026. Target: BeamNG.drive 0.40.x; installed reference: 0.40.1.0.

## Confirmed problems in the previous release

The installed Vue bridge exposes a static signature registry. The previous page
accessed a mod namespace that was absent from that registry, causing requests to
fail before reaching Lua. Its earlier mock incorrectly supplied that namespace.
The new page uses `run()` from `@/bridge/libs/Lua.js` and a restricted `uiRequest`
endpoint that returns an acknowledgement plus the applied state.

Read-only inspection of the user's existing game log also found DDS header
rejections and failures compiling the deprecated precipitation shader macros.
The package now uses BC3 DDS and original standalone HLSL. These repairs were
validated offline; a new in-game log has not yet been generated for this release.

## Completed checks

- 24 local Python/LuaJIT 2.1 (Lua 5.1) tests cover lifecycle, presets, persistence,
  migration, budgets, pause registration, request acknowledgements and errors,
  cloud modes, multiple cloud layers, restoration, external edits, locked modes,
  missing layers, map changes, DDS decoding and reproducible packaging.
- One test executes the installed `ui/pause/actions.lua` with a mocked engine.
  CI skips this installed-game check and runs 23 portable tests.
- Node checks cover both UI controllers. The pause test supplies **no mod entry**
  in the static signature registry. When the installed game is available, it runs
  the actual generic `bridge/libs/Lua.js` implementation against a mock engine API.
  Portable CI validates the generic endpoint contract with a mock.
- The actual Vue component renders using the game's Vue browser build in a local
  preview. Preset selection and automatic/manual cloud controls were checked
  through the visible interface with simulated game state.
- The cloud controller uses the installed game's exported `getCloudCoverByID`,
  `setCloudCoverByID` and `canChange` APIs. It changes coverage only on existing
  native `CloudLayer` objects. C++ execution remains untested.
- All four procedural BC3 DDS files regenerate identically. Pillow independently
  decodes the compressed atlases; checks cover alpha, 16 variants and full mipmaps.
- Original vertex/pixel shaders compile offline with the Windows SDK DirectX
  Shader Compiler. This establishes HLSL validity, not engine resource bindings
  or final rendered output.
- ZIP paths are safe, installable contents match source exactly, and repeated
  builds produce the same archive and SHA-256 checksum.

![Classic pause page with simulated game state, outside BeamNG](images/pause-settings-preview.png)

## Still requires in-game testing

The game has not been controlled for this update. Confirm preset changes through
Esc > Mods, native cloud appearance and restoration, rain texture loading,
shader bindings under the active renderer, collisions, map switching and FPS.
The **Raining** status means effect objects were created; it does not prove their
rendered output. Test Gridmap v2 and West Coast USA, then inspect `beamng.log`.

No windshield effects, puddles, friction, grip, wet materials or surface splashes
are implemented. See the README for installation and the gameplay checklist.
