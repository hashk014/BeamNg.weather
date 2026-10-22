# BeamNg.weather 0.6.1 alpha 1

Fix the Lua error that removed window droplets and disabled cabin protection in 0.6.0.

- Set the CustomMaterial blend mode through `setField("translucentBlendOp", 0, "LerpAlpha")`, matching the installed game's material setup. Direct assignment passed a string to a native enum setter expecting a number.
- If Lua refraction-material setup fails, keep normal-mapped beads and cabin protection active. Display a specific warning, clean up failed material objects and retry when the refraction strength changes. Avoid repeated rescans and setup attempts every frame.
- Include a traceback for other fatal vehicle-renderer errors, making further runtime failures easier to locate.
- Preserve the denser accumulation, adjustable refraction and exclusive airborne renderer introduced in 0.6.0. No new physics changes.

**Install:** fully close BeamNG, replace the previous ZIP, keep one installed copy, and restart. Use a closed-roof vehicle. In Vehicle windows, check that detected meshes and surface droplets stay above zero. Close Escape and check the windshield, seats and footwell. If the new refraction shader renders incorrectly, set Refraction strength to 0; this keeps the normal-mapped beads and cabin protection.

**Validation:** 51 local Python/LuaJIT tests and both Node UI checks pass. A stricter native-enum boundary reproduces the old assignment failure. New tests inject refraction setup errors and verify that beads and cabin protection survive, native emitters remain at zero, and changing strength can recover. The ZIP is reproducible and matches the source. CI runs 50 portable tests, skipping the installed-game integration.

**Runtime limit:** the user's log confirms successful glass detection followed by the native binding error in 0.6.0. This patch fixes that incompatible call, but the new in-game appearance and cabin exclusion still need a retest. GPU failures that do not raise a Lua error are not automatically detected.
