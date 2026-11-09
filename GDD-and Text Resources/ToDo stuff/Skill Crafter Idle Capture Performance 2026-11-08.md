# Skill Crafter idle capture performance - 2026-11-08

## Request and boundary

User reports lag while orbiting the Skill Crafter camera, without manipulating
body controls. Skill preparation remains sampled at 60 Hz; editor rendering and
camera motion are not capped to that rate. User requested both native C++ work
and running the background pose task only when needed, then returning to standby.

Current viewport is UPDATE_ALWAYS and orbit directly applies the camera transform.
Static inspection found repeated whole-station normalization before the existing
already-captured early return. Background capture called this path every editor
frame. This is confirmed unnecessary work; its contribution to perceived latency
needs measurement, not an assumed FPS claim.

## Implemented behavior

- Kept background endpoint recording, including the two-frame settling window.
- Wake it on authored edits, scene/selection pose refresh and acquisition
  serial/status changes. A settled success or terminal failure waits for the next
  change. Camera orbit/zoom/pan do not request capture.
- Explicit R/navigation/F/Save recording still verifies current input; the
  background scheduling flag must never suppress an explicit request.
- Share one station preparation within an actual capture request, rather than
  repeatedly normalizing through nested draft/node lookups.
- Move authored pose-signature enumeration/assembly/hash dispatch into the
  existing native extension. Preserve exact signature bytes and script fallback;
  shared property exclusions and finger normalization remain authoritative.
- No grip, motion solver, anatomical limits, playback cadence or saved schema
  changes. Native signature work is not a claim that the whole editor is C++.

Owners: combat_animation_station_ui.gd, combat_prepared_pose.gd, new native
combat_pose_capture_kernel.cpp/.h and extension registration/build source list.
Focused verifiers will check idle/camera standby, edit/selection/acquisition wake,
terminal-error retry behavior, signature parity and measured before/after costs.

The UI uses `_request_background_prepared_pose_capture` and
`_observe_prepared_pose_acquisition_key` to wake the task. The ordinary process
loop calls a cheap pending-flag gate. Capture itself shares one existing station
lookup scope; explicit requests still check current signatures regardless of the
background flag. A request serial prevents capture's baseline presentation from
clearing a newer request raised during capture. Failed finite attempts wait for
an edit/retry; settling and acquisition can finish without redoing frame-by-frame
whole-station preparation. No new timing or movement limit was introduced.

Native `CombatPoseCaptureKernel.node_pose_signature` enumerates the authored
properties, assembles the identical Variant payload and uses engine serialization
and SHA256. `combat_prepared_pose.gd` supplies the existing policy constants and
normalized sparse finger maps. The script implementation remains a fallback and
parity reference. This moves signature work, not the entire capture/validation
pipeline, into C++. Snapshot storage and UI lifecycle remain their existing owners.

## Fresh verification and measurements

Existing CMake target `grip_contact` rebuilt successfully, including the DLL.
Godot 4.7 rendered focused verifier used a fresh isolated Unarmed station; player
weapon saves were not replaced. Baseline ran before the UI change with the new
native class still absent, using the original script fingerprint fallback.

`tools/verify_skill_crafter_idle_capture.gd` calls the actual UI `_process` once
per frame with normal rig/tree processing still active. Each measurement phase
contains 30 frames. Synchronous UI callback time is separate from frame waiting
and camera-call time; these are NOT a claim about the whole game's FPS.

| Measured phase | Before mean UI time | After mean UI time | Before station preparations | After preparations |
| --- | ---: | ---: | ---: | ---: |
| Settled idle | 38.983 ms | 0.449 ms | 3,660 / 30 frames | 0 |
| Camera only | 38.913 ms | 0.430 ms | 3,660 / 30 frames | 0 |

The full trace found 122 preparations per frame, greater than the initial static
estimate of roughly 10. Nested mode/identifier helpers added more preparations.
Camera transform calls themselves averaged 0.032 ms before and 0.060 ms after.
After a finger edit settled, UI work averaged 0.491 ms and again made zero
preparations/capture attempts. The reduction in camera-phase UI housekeeping is
approximately 98.9%; whole-frame or real-weapon performance needs manual assessment.

- Focused rendered verifier: 30 checks passed. Covers standby, actual finger
  edit/recording, insertion, existing-node selection, Reset, acquisition-key wake,
  terminal error not spinning, and recovery by an explicit request. The acquisition
  check tests notification dispatch, not a new full-hand acquisition certification.
- Native signature verifier: 330 checks passed, identical native/dispatcher/script
  results, null/default/generic resources, all supported authored properties,
  excluded timing/curve fields, sparse/nonfinite finger inputs and nonmutation.
- Signature microbenchmark (300 calls): script 175.757 microseconds/call; native
  dispatcher 171.473 microseconds/call. This is a small gain in isolation. The large
  improvement above comes from removing recurring preparation, not from C++ alone.
- Both rendered baseline/final logs are clean. Scoped diff check passed apart
  from the existing CRLF notice. No Save/F/equipped sweep or body/grip rework.

Evidence:
- `godot_runs/sc_idle_capture_20261108/baseline/report.json`
- `godot_runs/sc_idle_capture_20261108/after/report.json`
- `godot_runs/sc_idle_capture_baseline_20261108.log`
- `godot_runs/sc_idle_capture_after_20261108.log`
- `godot_runs/sc_idle_capture_native_signature_20261108.log`

Verifier files: `tools/verify_skill_crafter_idle_capture.gd` and
`tools/verify_combat_pose_signature_native.gd`. Builds/runs were sequential and
closed; the pre-existing editor was left open. No Git actions. The prior pushed
baseline is still `8426443d`; fingers and this optimization remain local.

## Next narrow focus

User assessment of camera orbit/pan/zoom and ordinary editing on their actual
weapon. Other per-frame rig/status work still exists; do not claim every possible
frame stall has been removed. Profile any remaining symptom before another port.
Preserve grip/motion behavior and fixed 60 Hz skill sampling.
