# Validation: 0.6.1 experimental release

Date: October 22, 2026. Target: BeamNG.drive 0.40.x; installed reference: 0.40.1.0.

## 0.6.1 native enum assignment and failure isolation

The user's screenshot and 0.6.0 log report `luaBinding.lua:165: bad argument #6 (number expected, got string)`. The log shows successful detection of 8 glass meshes and 314 triangles, followed by repeated renderer failure and rescans. Line 165 is the installed native static-field setter. The new CustomMaterial directly assigned the enum `translucentBlendOp="LerpAlpha"`; the installed core materials use `setField("translucentBlendOp", 0, "LerpAlpha")` to parse that symbolic value instead. 0.6.1 follows that native pattern. The earlier mock accepted any type and missed this boundary.

The boundary now rejects direct symbolic enum writes but allows setField parsing. Before the fix, 16 of the 21 vehicle tests fail under this stricter boundary. They pass after correction. Two new failure-injection tests verify that refraction setup failures keep detected panes, visible bead geometry and the protected airborne backend, without repeated rescans or material-creation attempts. They also verify cleanup of failed material objects, recovery after changing strength, and zero native emitters during fallback. Fatal renderer errors now include a traceback in the diagnostic/log.

These checks reproduce the incompatible assignment and failure path synthetically. The new release has not been run in-game; visual refraction and cabin exclusion still require the user's retest. GPU failures which do not raise Lua errors cannot be detected by this fallback.

## 0.6.0 refraction, density and airborne renderer

The user reports that 0.5.3 window droplets generally work, but are too sparse and lack visible distortion; airborne rain still enters the cabin. Its log records 11 glass meshes and 1,008 triangles with converted Z-up cabin bounds. This supports successful scanning and the user's placement report, not proof that cabin masking worked.

The new original shader uses the installed custom-material draw interface, as demonstrated by native vehicle highlight/ghost shaders, and the `$backbuff` binding used by native water. It implements a projected curved-bead displacement with transparent corners and a small rim/highlight. FXC SM5 and DXC SM6 compile both stages using the installed headers; SM6.6 bindless permutations also compile. For FXC, DXC first resolves the game's virtual-root include paths without altering the installed files. Engine sources and compiled outputs are not distributed.

Synthetic tests verify CustomMaterial/back-buffer/state registration, changing the strength constant, the explicit zero-strength PBR fallback and material identity through resets. New population checks exercise zero amount, accumulation above the previous cap, and quality reduction. Full airborne quad vertices remain outside the synthetic cabin/footwell for stationary and +/-60 m/s velocity cases. Main-controller checks require all three native emitters to contain zero drops during mesh protection and restore counts on disable or camera departure. This removes dependence on the native precipitation fade-mask binding for this mod's cabin protection.

The higher density and back-buffer lookup are unprofiled in-game. Native shader compilation/binding, actual refraction appearance, conservative exclusion on real cars and performance still need gameplay validation. Protection uses a finite airborne volume, so distant rain can be reduced while active. Map-owned rain is unchanged. These are deliberate limitations of this experimental release, not validated parity with the previous native renderer.

## 0.5.3 coordinate and transparency correction

The 0.5.2 game log reports 6 detected glass meshes and 274 triangles, with imported glass textures and no repeat of the mod's previous namespace/missing-material errors. The user reports visible beads at the rear seat instead of on the glass, with rectangular nearby rain when driving and normal rain outside the vehicle.

The installed `util/export.lua` passes GPU vertex buffers directly to glTF POSITION accessors and converts vehicle directions and prop translations to `(x, z, -y)`. The mod previously interpreted those buffers as BeamNG Z-up. 0.5.3 applies the inverse `(x, -z, y)` before the vehicle-local transform, for both droplets and cabin bounds. The fixture now models that export convention, and a regression verifies known glass planes and the cabin envelope in three vehicle orientations. The previous decoder fails the new check. This is source-derived coordinate evidence; corrected in-game placement still needs validation.

Both PBR particle materials now use explicit grayscale opacity maps, as described in [BeamNG materials v1.5](https://documentation.beamng.com/modding/materials/materials_1.5/). The generated RGB mask equals the original color texture's alpha pixel-for-pixel and has an opaque alpha channel of its own. Tests check references, transparent borders, nonzero silhouettes and deterministic encoding. Original color/normal assets are unchanged.

## 0.5.2 runtime evidence and correction

The 0.5.1 game log confirms 7 glass meshes and 878 triangles, followed by a namespace-parent collision between Material and ProceduralMesh named `beamngWeather_hashk014_glassDrops`, then repeated missing-material errors. 0.5.2 gives both procedural meshes explicit `Mesh` suffixes and verifies Material objects before creating geometry. The prior test loader ignored the surface materials, so its uniqueness assertion could not detect the collision. It now loads the actual JSON definitions and checks material resolution during every synthetic mesh upload. The old renderer reproduces the collision under this boundary.

The Torque3D reference `Precipitation` source declares `fadeDist` and `fadeDistEnd` using `CommonValidators::PositiveFloat`. The old negative guard encoding was incompatible with that constraint. The new encoding uses `fadeDist = fadeDistEnd + guardRadius`; the original shader decodes the positive difference. Tests now emulate this validation and cover guard restoration across volume changes and cabin protection toggling. This source-based diagnosis is consistent with the reported cabin rain; actual 0.5.2 native field binding and rendered exclusion still await gameplay validation.

New regressions check material/mesh identity across resets, missing-material fallback, and positive guard values. Both shader stages compile with FXC SM5 and DXC SM6. No new in-game rendering claim is made.

## Earlier scan failure and correction

A user screenshot from 0.5.0 shows `Glass scan failed: ... Too many glass triangles`, with zero detected panes and droplets. This proves the scan abort, but does not identify which mesh/range caused the overflow. The old scanner reproduces the same error in two new synthetic cases: repeated primitive ranges and legitimate high-detail glass. Both pass after the correction.

0.5.1 filters primitives with `vehicle:getMaterialNames()[materialId + 1]`, using the mapping in the installed game's `util/export.lua`, and removes repeated ranges/indexed triangles. It samples glass above 30,000 candidates across all panes rather than aborting. Additional regressions check material filtering, duplicate triangles and missing material-table fallback. Sampling can shorten sliding and is reported in the GUI. Scan counts/failures are logged. No installed vehicle assets are distributed.

## Evidence and completed checks

- **51 local Python/LuaJIT 2.1 (Lua 5.1) tests.** CI runs 50 portable tests and
  skips the installed-game pause-actions integration. Both Node UI checks pass.
- Existing lifecycle, presets, cloud restoration, persistence/migration, budget,
  failure recovery, pause registration, texture and deterministic archive checks.
- Twenty-two synthetic tests exercise the actual vehicle-effect modules using the
  native GPU-mesh and ProceduralMesh API shapes: five exterior glass surfaces;
  interior/lamp exclusion; GPU-buffer freeing; forward/reverse impact and sliding;
  exclusion of near drops from the cabin; static shelter; pause; toggles; reset;
  asynchronous mesh timeout; corrupt-data fallback; camera distance; pose tracking;
  world-space near particles; PNG alpha fading and normal variation.
- Native F11 `rain_coverage` objects were inspected read-only in the installed Jungle Rock Island, Small Island and East Coast level archives; West Coast has `WCA_rain`. They are `Precipitation` volumes, not a separate vehicle-occlusion API. The mod inherits volume dimensions/fade for its owned ambient layer and falls back elsewhere. A regression test checks profile use, fallback and preservation of the source object.
- Main-controller integration verifies exclusive airborne backends, the airborne
  budget, and cleanup through mission end and serialization with vehicle effects.
- GPU mesh calls were checked against the installed game's `util/export.lua`:
  `GPUMesh.bng_getGPUMesh`, `dataIsReady`, `verticesGet`, `indicesGet`,
  `flexmeshes`, `primitivesGet` and `free`. These are read-only snapshots.
- ProceduralMesh format/collision disabling checked in the installed game's
  `editor/toolUtilities/meshPart.lua`; pose and quaternion APIs checked in core
  scripts. Vertex/normal/UV face indices are verified by the synthetic boundary.
- Native guard constants reuse the renderer's fade fields. Both revised HLSL
  stages compile with Windows SDK FXC (SM5) and DXC (SM6). This is offline
  compilation, not proof of runtime shader bindings or rendering.
- Original four BC3 DDS, two glass PNG and two opacity PNG textures regenerate identically.
  Independent image decoding checks alpha, atlas variants, mipmaps and normals.
- Vue settings page rendered in a browser using the installed game's Vue build,
  with simulated state. New glass/cabin controls checked through the visible UI.
- ZIP entries use safe relative paths, match source exactly and are reproducible.

## Native behavior still awaiting gameplay validation

The game has not been controlled for this update. Tests do **not** establish
that the new refraction material and replacement airborne renderer work correctly
in the actual game. The user confirms that 0.5.3 bead placement generally works.
Confirm the new effects on stock cars before treating cabin exclusion/refraction
as verified. Actual FPS, DirectX/Vulkan differences and damage are unmeasured.

Cabin protection is a conservative glass-derived envelope, active near the player
vehicle with a 12 m camera guard. It can remove some air outside the actual cabin.
Turn it off for open-top vehicles. The implementation does not model each opening
or update flexbody deformation continuously. Damage/opening windows may require
reset, and unconventional mesh names or combined body meshes may not be supported.
Window water uses screen-space refraction, with a normal-mapped fallback at zero
strength. It is not an optical ray tracer. Wipers are not implemented.
New arrivals stop under static shelter, while existing beads
run off. Collision sampling and exposure are approximate and map-dependent.

If scanning/render-mesh creation fails, the effect reports a diagnostic and leaves
native airborne rain unmasked. This fallback cannot guarantee a dry cabin.
The UI's **Raining** status confirms requested objects/counts, not rendered output.
Close Escape to run the simulation. Use the detailed test checklist in the README.

![Vehicle controls with simulated state, outside BeamNG](images/vehicle-settings-preview.png)

No road wetness, puddles, grip/friction changes, ground splashes or rain audio are
implemented. No original vehicle assets or game scripts are overwritten.
