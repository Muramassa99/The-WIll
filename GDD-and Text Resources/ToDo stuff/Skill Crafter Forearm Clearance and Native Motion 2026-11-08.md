# Skill Crafter forearm clearance and native motion — 2026-11-08

## Scope and protected baseline

User manually accepts gripping and upper-body motion as working foundations.
Git savepoint: `313c78658fa4d691147260421822a3d3ca07bf08`, tag `Stable-body`.
Add forearm/body sliding protection and accelerate numerical movement work.
User reports Tip smooth at 20,000 px/s but Pommel stutters above 500 px/s.
Do not change acquisition/seating, anatomical limits, fixed Idle references,
wrist X/Z ownership, opposite-arm isolation, or Save/F lifecycle for this pass.

## Code findings

- Both Forearm→Hand capsules already exist in `clearance_proxy_builder.gd`.
- Active weapon/independent-arm allocation omits the legacy boolean collision
  callback. Reconnecting it would reject intersecting starts and recreate the
  editing lockouts the user explicitly rejected.
- Weapon separation in older settle paths is not current continuous sliding.
- Existing body self-collision allows 40 mm forearm/torso overlap and exempts
  forearm/forearm crossing. New forearm guidance must prevent torso penetration,
  while retaining connected-joint and opposite-forearm exceptions for this scope.
- Historical heavy Pommel traces spend most time inside repeated FK/anatomical
  evaluations. These are not fresh timings of the Stable-body profile.

## Implementation plan / ownership

1. Fresh actual-rig request fixture and timing breakdown; preserve identical
   captured inputs for reference/native comparison. No test-library mutation.
2. Existing `native/grip_contact` extension: batched FK and exact QP/linear
   algebra kernel; optional reference backend for diagnostics. Preserve arithmetic
   order, limits and result contracts. No parallel scene-tree mutation.
3. Named-bone clearance snapshot, captured once per request. Evaluate full
   forearm capsule segments against existing body capsules/boxes from candidate
   FK. Same root ancestry and world-metre convention as the movement adapter.
4. Signed constraints, fixed initial penetration allowance, outward recovery,
   and explicit tangential continuation. Do not reintroduce a must-already-be-
   legal movement gate. Clearance must not detach either acquired grip.
5. Focused parity, collision/recovery, root-transform and real-rig checks. Report
   measured gains and residual boundary stalls honestly; do not infer usability
   from native compilation or lower average time alone.

## Files expected

- `core/resolvers/combat_weapon_motion_allocator.gd`
- `runtime/player/combat_weapon_motion_rig_adapter.gd`
- new `core/resolvers/combat_motion_math_backend.gd`
- new `runtime/player/combat_forearm_clearance_snapshot.gd`
- existing native extension registration/build and new numerical kernel files
- focused verification/benchmark tools and this companion note

## Evidence / status

Forearm clearance and the measured native acceleration changes are implemented.
The accepted Stable-body mechanics remain the reference. Boundary-search stalls
remain unresolved; do not describe this as a completed smoothness fix.

- Native FK and active-set QP preserve reference arithmetic/order. Prepared
  wrist sampling is enabled after 338/338 complete-dictionary equality checks
  (`godot_runs/forearm_native_20261108/prepared_native_exact`). The optional
  native shoulder measurement also passes, but stays disabled because prepared
  GDScript was slightly faster. This is a measured choice, not a missing port.
- Reuse immutable profiles/calibration within each request. Read actual stored
  bones for certification, but avoid rebuilding unchanged metadata for every
  candidate. Shared torso readback retains the original initializer.
- Nine identical actual-rig requests pass reference/native pose comparison.
  Initial / optimized timings (ms): R Pommel 20 mm up 60.778 / 26.816;
  L 20 mm up 89.329 / 41.266; R 100 mm outward 1239.268 / 612.881;
  R 100 mm forward 1540.172 / 807.543; L outward 1586.617 / 834.207.
  These are synchronous request costs, not display FPS. Boundary cases still
  take far too long. Inputs/results are under
  `godot_runs/motion_native_performance_20261108/{script,native_final}`.
- Full-segment forearm capsule queries use existing named-bone body proxies,
  including capsule-to-capsule and capsule-to-oriented-box distances. Prepared
  native constraint queries measured 5.36 us versus 268.37 us per reference
  batch (20 shapes / 34 pairs), with 145 parity/transform/immutability checks.
- Collision numerical allowance is the current 0.05 mm position tolerance.
  A deeper existing intersection may recover but must not deepen: effective
  cap is max(0.05 mm, original depth), not original depth plus 0.05 mm.
  Twenty synthetic sliding/recovery/tolerance checks pass.
- Twenty-two focused actual-rig shared-two-hand / independent-arm checks pass
  (`godot_runs/forearm_native_20261108/integration`). Bindings in these fixtures
  are declared rigid transforms, not a new finger/grip-acquisition test.
- A rendered real Skill Crafter run reset/acquired Broken_Balde_v1 and exercised
  24 sequential Pommel edits. Contact stayed inside existing tolerances, but a
  request still took 853 ms and repeated blocked requests took 231-259 ms.
  This early run is not evidence that the jitter is solved.
- Real L forearm contact plus the clavicle boundary exposed a bad slide target:
  the legal improving partial pose still had orientation error; fixing its
  position while repairing orientation was infeasible. Dedicated contact-slide
  orientation priority now passes 25 pure and 51 actual-rig checks. Ordinary
  movement rules stay intact. See the final evidence below.
- The historical pure allocator verifier has three old strict-priority failures.
  The same failures/numbers reproduce with the Stable-body allocator extracted
  to an external temporary fixture. Do not alter current weighted body mechanics
  to satisfy those obsolete assertions. Evidence: `stable_reference.log`.

The bounded exact-input cache experiment was rejected (below). The final
rendered check is complete. Remaining work is interactive boundary-search cost,
plus user assessment of capsule shape/slide feel. No larger ROM or new grip
solver is justified by the remaining performance problem.
No Save/F lifecycle or saved-skill changes are part of this pass. No Git operations
have been authorized or performed for these additions.

Official Godot 4.7 references reviewed:
- https://docs.godotengine.org/en/4.7/tutorials/performance/cpu_optimization.html
- https://docs.godotengine.org/en/4.7/tutorials/scripting/cpp/gdextension_cpp_example.html
- https://docs.godotengine.org/en/4.7/classes/class_geometry3d.html
- https://docs.godotengine.org/en/4.7/classes/class_physicstestmotionresult3d.html

### Bounded exact-input cache experiment — rejected after measurement

An opt-in, request-local cache of exact float64 joint-coordinate evaluations was
tested with fixed continuation epochs and a 256-entry bound. Its 18 contract
checks and all six actual-body cache-on/cache-off outcome comparisons passed,
but reuse was too low to repay lookup/storage overhead: roughly 6–10% in the
hard contact cases and below 2% for ordinary requests. Measured cache-off/on
times were R approach 539/543 ms, L approach 802/840 ms, and L tangent 937/967 ms.
This was not a useful optimization. The experimental runtime cache, switches
and its dedicated verifier were removed; no evaluation cache remains enabled
or available. Existing prepared anatomy/native geometry and storage-readback
metadata reuse remain unchanged. The general body-clearance numeric comparison
helper was retained. Evidence logs/reports remain in
`godot_runs/forearm_native_20261108/cache_contract.log` and
`godot_runs/forearm_native_20261108/body_clearance_cache/`.

### Final contact and live evidence

`godot_runs/forearm_native_20261108/body_clearance_slide/report.json`:
25 pure checks in `allocation_slide.log`, 51 actual-body checks in this report.
R approach / tangent / outward: 539 / 28 / 23 ms. L approach / tangent / outward:
802 / 937 / 37 ms. Both outward requests and R tangent complete 20 mm. L tangent
moves 1.226 mm of its 20 mm demand at simultaneous chest/clavicle boundaries;
it is explicitly `SCALED`, not a full successful target match. Deepest measured
chest penetration is 0.0318 mm, within the 0.05 mm allowance. Actual stored
binding position error is at most 0.145 micrometres; untouched opposite-arm
displacement is at most 0.245 micrometres. Weapon orientation is within the
existing 0.025-degree cap (L tangent is near that cap).

`godot_runs/forearm_native_20261108/live_station_final/manifest.json`:
Rendered actual Skill Crafter, isolated real Broken_Balde_v1 Skill 3, Reset and
ordinary acquisition readiness (5.484 s), then 24 numeric Pommel edits through
the real UI API. Eighteen edits accept movement; six further inward requests
at the combined hip/clavicle boundary retain the current pose. Reversal recovers.
All 24 maintain the acquired Hand/weapon binding: max 0.313 micrometres positional
and 0.0000215 degrees angular error. Start/end images were inspected. Existing
pose-warning text can appear near limits; this pass does not certify every pose.

Ordinary numeric-edit callbacks cost about 47-62 ms, of which the allocator uses
14-24 ms. The test's `false` argument disables persistence only: timeline,
fields, preview and summary still refresh. This is NOT mouse-drag frame latency.
Actual drag uses cached chains and budgeted visuals via `_handle_preview_drag`
-> `_queue_pommel_drag_authority_target` -> `_flush_pending_preview_drag_refresh`.
The heavy shared allocator cost is real: near the boundary, accepted requests
cost 380-654 ms and complete callbacks reach 793 ms. For rejected edits the
checkpoint restores `weapon_motion_allocation_result`, so that metadata is the
last accepted result, not fresh timing for the rejected request. Use the complete
callback elapsed time there, not the repeated metadata allocation time.

### Final code owners and follow-up boundary

- `core/resolvers/combat_motion_math_backend.gd` plus native
  `combat_motion_math_kernel.*`: FK and QP, enabled by default.
- `combat_shoulder_motion_resolver.gd` / `combat_wrist_motion_resolver.gd` plus
  `combat_motion_anatomy_kernel.*`: checked prepared contexts; native wrist on,
  native shoulder off after timing comparison. Exact native/reference checks
  use the engine's shortest-arc Quaternion constructor, not the subtly different
  pinned godot-cpp inline implementation near antipodes.
- `runtime/player/combat_forearm_clearance_snapshot.gd` plus native
  `combat_forearm_clearance_kernel.*`: root-traced capsule/box snapshot, native
  prepared constraint queries. Never save the runtime snapshot into motion nodes.
- `combat_weapon_motion_rig_adapter.gd`: clearance rows, collision-only numerical
  allowances, immutable metadata reuse, real stored-bone readback. The independent
  arm adapter forwards the same original snapshot for readback.
- `combat_weapon_motion_allocator.gd`: recoverable non-deepening overlap, and a
  contact-triggered slide fallback that holds orientation before finding reachable
  translation. Real contact, original anatomy and storage checks remain mandatory.
- Presenter change is an explanatory comment only. No grip, Save/F, authored
  duration, anatomical profile, drag-speed setting or input behavior changed.

Native rebuild uses the existing CMake build directory
`C:/WORKSPACE/helper applications/cpp-build/grip-contact`, target `grip_contact`.
The rebuilt project DLL is current. Git remains uncommitted/unpushed for this pass.
Game runs are closed; the editor was left open.

If continuing performance work, begin with the active constraint/search traces
above and a representative queued mouse-drag fixture. Do not repeat full Save/F
tests, silently widen anatomy/contact tolerances, restore a must-already-be-legal
gate, or claim raw/native parity proves smooth real-time control.
