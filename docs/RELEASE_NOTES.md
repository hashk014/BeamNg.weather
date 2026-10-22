# BeamNg.weather 0.6.0 alpha 1

Denser window droplets with experimental scene-color refraction, plus a replacement airborne renderer for cabin protection.

- Add an original curved-bead shader that samples the native refraction back buffer. Distortion follows each bead's projected size and orientation; transparent corners are clipped. The new **Refraction strength (0 disables)** control ranges from 0 to 2. Zero selects the previous normal-mapped material.
- Raise glass caps to 1,200 / 2,400 / 4,000 / 6,000 on Low / Balanced / High / Ultra. Increase arrival rate, lifetime and base size, add initial accumulation, and extend **Window droplet amount** to 4. Existing saved size preferences remain intact.
- Disable all three mod-owned native emitters while cabin protection is active near the vehicle. A bounded airborne mesh excludes the glass-derived cabin, footwell and movement margin. Protection no longer relies on the native shader's fade-mask binding. Native precipitation returns when protection is disabled, unavailable or outside the supported camera range.
- Cover approximately 18 m times Volume around the camera, focusing most airborne drops within 6 m. Map-owned rain and other mods are not modified. Increased mesh density may cost FPS; start with Balanced or Low.
- Keep velocity-dependent window arrival/sliding, shelter checks, English UI, presets and the corrected glass coordinates from 0.5.3. No wipers, puddles, road wetness or friction changes.

**Install:** fully close BeamNG, replace the previous mod ZIP, keep one installed copy, and restart. Test a closed-roof vehicle with Downpour, Window droplet amount 2, Window droplet size 1.5 and Refraction strength 1. Close Escape and allow accumulation. Compare stationary, forward and reverse driving, then check the footwell and seats. If refraction renders incorrectly, set its strength to 0 and report the renderer and any orange diagnostic.

**Validation:** 49 local Python/LuaJIT tests and both Node UI checks pass. The original lens shader compiles offline against the installed 0.40.1.0 headers with FXC SM5 and DXC SM6, including SM6.6 bindless permutations. Texture regeneration and deterministic ZIP/source checks pass. CI runs 48 portable tests and skips the installed-game integration.

**Still experimental:** these checks do not prove native back-buffer binding, visual quality, cabin exclusion or FPS in the game. The user reports that 0.5.3 glass placement generally works, but this new renderer still needs their gameplay test. Refraction is a screen-space approximation and cannot reconstruct hidden scene surfaces. Damaged/open windows, unusual vehicle meshes and moving glass remain limited.
