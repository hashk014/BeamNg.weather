# Validation: 0.3.0 experimental release

Date: October 21, 2026. Target: BeamNG.drive 0.40.x.

## Completed checks

- Read-only inspection of a local BeamNG.drive **0.40.1.0** installation.
- Datablock loading through `loadJsonMaterialsFile`, automatic mod loading and
  lifecycle hooks checked against game scripts.
- Names of the rendering and movement fields used by the mod found in the
  game binary. Their presence does not establish correct in-game behaviour.
- Torque3D precipitation code inspected for atlas layout, speeds, turbulence,
  orientation and fading. BeamNG is a derivative engine; actual behaviour in
  this game version still requires in-game testing.
- **20 local Python/LuaJIT 2.1, Lua 5.1 tests:** lifecycle, budgets, built-in presets,
  persistence, migration from 0.1, transitions, pause, failures and recovery,
  cleanup, absence of surface effects, texture assets and packaging.
- New pause registration tests cover repeated registration, the `mods` tab,
  the exact Vue component path and removal of only this mod's button.
- One test executes the **actual installed `ui/pause/actions.lua` module** with
  a mocked engine boundary. It confirms native Mods-tab metadata and coexistence
  with another mod entry. CI skips this installed-game test and runs 19 portable tests.
- Node UI bridge checks: individual setting changes without overwriting other
  options, presets, custom slots, bounds and slider protection during editing.
- A second Node check covers the Vue pause controller: initial state, settings,
  presets, slots, failed requests, retries and late responses after unmount.
- The dedicated Vue page was compiled/rendered using the game's Vue 3 browser
  build in a local preview with simulated game state. Preset selection,
  intensity and custom preset save/load were checked through the displayed UI.
- The pause integration uses `ui_pause_actions.registerModButton` with the
  reserved `mods` tab and `unregisterModButton` on unload. The component lives
  under `/ui/ui-vue/mods/`, as expected by the native mod component loader.
- Reproducible generation of four textures; DDS headers, complete mip chains,
  16 distinct atlas variants and the transparent surface texture checked.
- Original textures visually inspected outside the engine.
- Native `precipV.hlsl` and `precipP.hlsl` shaders bound under a unique mod name,
  following the game's `ShaderData` creation pattern. GPU compilation and
  rendered lighting/fading still require in-game verification.
- Actual panel and controller previewed with the game's **AngularJS 1.5.8**
  in a local browser using simulated game state. Preset selection, intensity,
  custom preset save/load and advanced settings checked.
- AngularJS 1.5.8 interpolated slider bounds corrected.
- Reproducible ZIP, safe relative paths and contents identical to source files.
- Version 0.2.1 translates UI text, preset names/descriptions, documentation,
  release metadata and preview artwork to English. Preset IDs and saved-setting
  keys remain unchanged.

![Panel outside the engine, with simulated game state](images/gui-preview.png)

![Pause settings component, with simulated game state](images/pause-settings-preview.png)

## Checks left to the in-game tester

The game has not been controlled for this project. Rain rendering, DDS and
datablock loading in the actual engine, FPS, collisions and integration with
the game's UI layout still need confirmation. In particular, **Esc > Mods >
BeamNg.weather** must be checked in the actual game, including closing/reopening
the page, changing maps and reloading Lua. Visual realism must be judged
in motion on the maps being used.

Mock-engine tests do not validate C++ bindings, GPU rendering, headlights or
actual cabin protection. Lighting uses native precipitation behaviour and
the speed controls use relative units.

The mod changes neither friction nor materials and adds no windshield effects,
puddles or surface splashes. The detailed in-game checklist is in the README.
