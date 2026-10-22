# BeamNg.weather 0.6.2 alpha 1

Reduce vehicle-rain overhead, restore classic window beads by default, and strengthen cabin exclusion while turning.

- Default to the classic PBR bead material, including for old settings with Refraction strength 1. The new **Experimental refraction** checkbox is off by default. The GUI reports the selected window renderer and whether cabin protection is active.
- Address the logged DirectX 12 null sampler-table failure in the experimental shader by using the engine's scene-space render-target sampler. Compilation and reflection pass; the revised shader remains opt-in until its actual rendering is confirmed.
- Limit glass geometry uploads to 10 Hz and airborne uploads to 20 Hz. Vehicle pose tracking still runs each frame. Cache panel exposure centers instead of rebuilding them repeatedly.
- Lower glass caps to 600 / 1,000 / 1,600 / 2,200 and air caps to 600 / 900 / 1,400 / 2,000 for Low / Balanced / High / Ultra. Amount and size controls remain available.
- Use a wider rounded cabin envelope covering all orientations, the footwell, particle corners and expected movement. Hide a stale air mesh after an unpredicted movement until the next scheduled rebuild. This can remove some rain just outside the car.

**Install:** fully close BeamNG, replace the old ZIP, keep one installed copy and restart. Enable rain and leave Experimental refraction unchecked for the first test. Start with Low or Balanced. Vehicle windows should report Classic beads and Cabin protection: Active near a supported closed-roof vehicle. Close Escape to test motion, then check the windshield, seats and footwell while turning.

**Validation:** 54 local Python/LuaJIT tests and both UI tests pass. Checks cover default material selection, opt-in switching, upload limits at 120 graphics updates per second, pause, rotated cabin exclusion and stale-mesh hiding. All six offline shader stage/permutation compilations pass. ZIP/source integrity is verified. CI runs 53 portable tests and skips the installed-game integration.

The synthetic 10-second Low workload fell from 2.642 s to 0.313 s on the same machine; Balanced fell from 8.177 s to 0.855 s. These timings exclude the native renderer and are **not in-game FPS measurements**. See docs/VALIDATION.md for the procedure and limits. Actual appearance, performance and cabin exclusion still require gameplay validation. No puddles, wipers or friction changes.
