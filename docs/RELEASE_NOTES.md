# BeamNg.weather 0.6.3 alpha 1

Smoother speed-dependent window droplets and more visible rain, retaining the working classic renderer and cabin protection from 0.6.2.

- Replace rapid window sliding with size-dependent adhesion, gravity and air shear. Small beads cling; larger beads move more readily. A 0.18-second response time smooths acceleration and reversals, and terminal sliding speed is capped at 0.08 m/s.
- Keep bead texture orientation stable when airflow reverses, avoiding abrupt highlight/normal-map flips. Increase glass geometry refresh from 10 to 20 Hz, keeping the existing particle caps. Pose tracking still follows the car each graphics frame.
- Increase classic window-bead opacity and rim definition. Dense wet glass is more conspicuous without raising the bead cap or enabling the experimental shader.
- Add an original three-streak near-rain atlas with stronger opacity and modest emissive fill. Each airborne quad displays three varied streaks, so visual density rises without multiplying geometry or weakening cabin exclusion. Native precipitation textures remain unchanged.

**Install:** fully close BeamNG, replace the old mod ZIP, keep one installed copy and restart. Leave Experimental refraction unchecked. Start with Low or Balanced, Downpour, Window droplet amount 2 and Window droplet size 1.5 for a heavy-rain test. Close Escape; compare stationary, forward, reverse and turning motion. Adjust amount/size to taste.

**Validation:** 56 local Python/LuaJIT tests and both UI tests pass. New checks cover adhesion, capped tangent motion, gradual direction reversal, smoothing consistency and atlas silhouettes/transparency. Texture generation and ZIP/source checks pass. CI runs 55 portable tests and skips the installed-game integration.

The synthetic 10-second workload measures 0.536 s on Low and 1.108 s on Balanced. This is more work than 0.6.2 but well below 0.6.1 in the same harness; it is not an in-game FPS measurement. The user confirms the 0.6.2 window and airborne rendering works. The new motion, visual density and performance still need their gameplay test. This is an artistic approximation of water; full optical refraction remains experimental. No wipers, puddles or friction changes.
