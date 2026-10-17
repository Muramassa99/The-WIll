# Forge V2 point twist and CAD views - 2026-10-17

## Authority and current slice

User authorized pre-work documentation followed by implementation on October 17.
This note supersedes the undecided twist controls in the August 29 Handle
transform note. It does not activate that note's longitudinal size shaping.
Recovery commit: ec978c57, hand overhault v6.2 - Forge V1 retirement and metric
handles. Existing local settings and generated test-library changes are unrelated.
No new Git operation is requested.

Implement point twist for Spline Line and Handles first. Camera modes are a
separate later task. Do not resume grip solving or support-hand baking here.

## User-facing contract

- Space selects the next authored dot; Shift+Space selects the previous dot.
  Both wrap around in placement order. These commands belong to active 3D path
  editing, not text entry or the 2D profile editor (whose Space recenters view).
- The selected dot exposes a perpendicular offset rod with a draggable endpoint.
  Its plane is normal to the actual forward spline tangent at that dot.
- First-to-last placement order defines forward. At the last dot use continued
  incoming direction. Positive rotation is clockwise when looking from the
  downstream side toward the upstream side; negative is counterclockwise.
- Degrees and Twist are synchronized views of one unwrapped total rotation.
  1 Twist = 360 degrees; 0.25 Twist = 90 degrees; 10 Twist = 3600 degrees.
  They are not additive fields. Mouse dragging across the angular seam preserves
  accumulated turns. Neither persistence nor geometry may reduce totals modulo 360.
- Rotating a dot leaves other dots' authored rolls and path positions unchanged.
  Roll changes linearly with travelled arc distance between adjacent dots. Thus
  0 / 3600 / 0 gives ten turns followed by ten turns back. This preserves the
  density bound without interpolation overshoot. Direction reversal is continuous
  in orientation but need not have a smooth angular-rate derivative at the dot.
- The centerline stays fixed. A circular profile does not gain a thread merely
  from rotation; noncircular profile features create the visible spiral.
- While editing, show two opposing traces from actual profile boundary locations.
  Asymmetric profiles must not be represented by a fictitious symmetric radius.
  The traces and rod provide lightweight feedback; do not rebuild committed CSG
  on every mouse event.

## Twist density and geometry limits

- User confirmed initial minimum pitch: **5 mm per full turn**, equivalent to
  20 turns per 100 mm. Keep one named shared constant so it can be adjusted later.
- Limit differences between neighboring dots using their actual spline span arc
  length, not distance from origin, total path length, or overall Handle length.
- Root implementation assumption: edit to whole degrees; round allowable bounds
  inward to whole degrees. Fractional Twist values remain available. A 100 mm span
  can differ by 7200 degrees. A common roll on both dots rotates the profile without
  consuming twist density. Do not force whole-turn-only authoring.
- Clamp the selected dot within the intersection of both neighboring constraints,
  show its actual accepted value and bounds, and preserve neighboring rolls.
- If moving a dot makes existing roll differences invalid, reject that move with
  feedback. Never silently remove authored turns. Revalidate before generation
  and when consuming persisted data.
- Refine samples for angular change as well as path curvature/distance. Start
  with at most 5 degrees of authored roll between successive sweep samples,
  further refined when needed to keep radial chord error within 0.05 mm.
- This is a pitch cap, not a mathematical guarantee of minimum material thickness
  for arbitrary profiles or self-crossing paths. Existing geometry validity and
  closed-solid checks remain authoritative; never export a fabricated fallback.

## Shared geometry and persistence contract

- Add per-point PackedFloat64Array roll data aligned with authored path points:
  transient spline_line_roll_degrees and saved body/layer path_roll_degrees.
- Existing files with missing roll arrays behave as all-zero authored roll.
- Preserve roll through adding/removing points, path-mode conversion, undo/redo,
  generate, Change Handle, WIP Save/Save As/reload and export.
- Existing profile rotation remains the baseline. Apply authored roll after
  resolving the stable baseline frame; shortest-angle frame continuity must not
  erase whole turns.
- One shared roll/frame sampler must feed generated CSG, cheap preview traces,
  material/occupancy evaluation, exported Handle triangles and grip wrapper.
- The invisible saved handle target must be generated from the correctly twisted
  Handle. Preserve target depths/overlap rules and invalidate changed geometry's
  derived caches through the existing geometry/save contract.
- Zero-roll paths retain their established geometry behavior. Do not introduce
  a second Handle identity, live grip solver, or alternate material pipeline.

## Planned files and ownership

All source paths below are under The Will- main folder/the-will-gamefiles/.

- New runtime/forge_v2/forge_v2_path_roll.gd: shared pitch, bounds, roll and frame
  sampling (plus generated UID).
- runtime/forge_v2/forge_v2_authoring_state.gd: point-roll lifecycle and validation.
- runtime/forge_v2/forge_v2_material_body.gd and forge_v2_layer_data.gd: saved data.
- runtime/forge_v2/forge_v2_stage_controller.gd: existing command/history routing
  and packed-double sequence deltas. The action-history owner needs no changes.
- core/resolvers/primary_grip_handle_mesh_packet.gd: include authored complete
  turns in exact-Handle signatures while retaining existing zero-roll signatures.
- runtime/forge_v2/crafting_bench_ui_v2.gd and forge_v2_keybinding_state.gd:
  Space cycling, synchronized fields, drag input and feedback.
- runtime/forge_v2/forge_v2_volume_preview_presenter.gd: shared sweep, rod and rails.
- runtime/forge_v2/forge_v2_workspace_preview.gd: forward the presenter's rod frame
  to the UI using the existing workspace-preview boundary.
- runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd and
  forge_v2_material_volume_resolver.gd: transformed export/evaluation consistency.
- runtime/forge_v2/forge_v2_workpiece_solid_engine.gd: reject unsupported rolled
  detailing inputs rather than silently dropping authored roll. Existing spline
  path sampling helpers remain unchanged.
- New tools/verify_forge_v2_point_twist.gd, _lifecycle.gd, _ui.gd and _curved.gd:
  focused integration proof. Modernize the existing single-handle-change test's
  outdated tetrahedron Save fixture using the real handle exporter and baker.
  Record actual results below and in a new SPS when handing off. Do not update
  sunset trackers.
- This note and a pointer in forge_v2_design_notes.md.

## Verification plan

1. Parse/import and shared-helper proof: signed direction, full turns, density
   bounds, uneven/curved spans, unchanged neighbors and zero-roll compatibility.
2. State/controller/UI: Space wrap both directions, text/profile focus isolation,
   synchronized values, seam-crossing drag, undo/redo and invalid-move feedback.
3. Generate asymmetric Spline Line and semantic Handle: compare preview frames
   with actual twisted sections, bounded sample spacing and closed geometry.
4. Save/reload/Change Handle; verify final triangles and saved wrapper come from
   transformed Handle, not its untwisted proxy. Check old zero-roll Handle gates.
5. One substantial Godot run at a time, isolated test data. Distinguish automated
   geometric proof from manual visual confirmation. Do not claim the latter from
   a parser or metadata-only test.

## Later camera task (recorded only)

Orthographic projection with front/back/left/right/top/bottom face views,
rotation lock/unlock and pan/zoom while locked. Orthographic free orbit is also
possible; evaluate it as the default Forge view later. This is parallel-ray
projection, not spherical distortion. Keep familiar input meanings consistent.

## Evidence and progress

Pre-work: reread all four Agent law documents and current SPS; inspected current
state/UI/sweep/export owners. Official Godot 4.7 Curve3D, CSGPolygon3D and Camera3D
documentation reviewed in the preceding design turn. Existing twist-per-meter
field is not a complete active per-dot feature; both generation paths currently
pass zero and orientation handling can discard full turns.

Implemented in the files above. `ForgeV2PathRoll.MIN_TWIST_PITCH_METERS = 0.005`
is the single policy value to adjust after user testing. Degrees are unwrapped
through history and persistence; zero-roll saved Handle signatures remain stable.
Twist-field arrows advance one degree (1/360 turn); text accepts fractional turns.
The first point can accept rotation before its neighboring spacing is defined.

The baseline frame now reuses the existing native Curve3D orientation/tilt
calculation. Roll is applied on top of that frame, with distinct existing profile
handedness preserved for Handles and ordinary Spline Lines. Shared orientation
logic was consolidated from the presenter and adapter rather than copied into a
second implementation. Ordered cumulative span stations avoid nearest-point
ambiguity when a path returns near an earlier point.

Fresh isolated Godot 4.7 verification on October 17:

| Check | Result | Evidence |
| --- | --- | --- |
| Point twist, actual asymmetric Handle triangles, three saved target meshes, WIP save/reload | 50 passed, 0 failed | `test_artifacts/forge_v2_point_twist_20261017.json` |
| Curved Handle and ordinary Spline actual meshes | 12 passed, 0 failed | `test_artifacts/forge_v2_point_twist_curved_20261017.json` |
| Append/history, path conversion, Change Handle, persisted invalid-data rejection | 45 passed, 0 failed | `test_artifacts/forge_v2_point_twist_lifecycle_20261017.json` |
| Actual UI/controller input, number fields, multi-turn rod drag, undo and focus isolation | 44 passed, 0 failed headless; 45 passed rendered including capture | `test_artifacts/forge_v2_point_twist_ui_20261017.json`, `forge_v2_point_twist_ui_rendered_20261017.json` |
| Existing Handle length bands | 298 passed, 0 failed | `godot_runs/verify_forge_v2_handle_length_bands_final_20261017_stdout.log` |
| Existing single Handle / Change Handle / automatic Save commit | PASS with real export/baker fixture | `godot_runs/verify_forge_v2_single_handle_change_20261017.txt` |
| Existing action history | PASS | `godot_runs/verify_forge_v2_action_history_twist_20261017_stdout.log` |

Final editor import exited 0 with no script errors:
`godot_runs/forge_v2_twist_final_import_20261017_stdout.log`. Scoped diff checks
passed. Resume snapshot: `GDD-and Text Resources/SPS/SPS_2026_10_17_20-10.md`.

Initial tests caught and corrected profile reflection, clockwise sign, and curved
baseline-frame discrepancies. Measured uniform-360-degree curved surface errors
are 0.0214 mm for Handle and 0.0221 mm for ordinary Spline, below 0.05 mm.
Untouched endpoint sections under a middle-point 90-degree twist remain within
0.00001 mm of the original. The stale single-Handle verifier's tetrahedron lacked
today's exact Handle signature and wrapper provider; only its fixture was updated,
with assertions retained and no production save gate weakened.

Rendered capture: `test_artifacts/forge_v2_point_twist_ui_20261017.png`. The capture
uses a circular profile, so the gold traces illustrate twist while a generated
circular solid retains its silhouette. This is automated UI/geometric evidence;
manual authoring feel and the user's actual weapon profiles still await testing.
No new full-game grip, support-hand bake, performance, or camera certification is
claimed. The prior two-hand bake-retention issue remains parked.

## Indicator styling follow-up - October 17

User requested line thickness divided by five, ball diameter divided by 1.5,
with resulting diameters rounded down to whole millimetres. Updated dimensions:

| Indicator | Previous diameter | New diameter |
| --- | --- | --- |
| Two opposing shape traces | 16.8 mm | 3 mm |
| Spline centerline and rotation rod | 28 mm | 5 mm |
| Rotation knob | 39.2 mm | 26 mm |
| Ordinary point | 56 mm | 37 mm |
| Selected point | 76 mm | 50 mm |

Rod length and actual profile/path positions remain unchanged. Its previous
95 mm minimum reach is now independent of selected-marker size. Existing pixel
pick tolerances remain unchanged. Shared detailing path indicators inherit the
same reduced line/point sizes; generated material and grip geometry do not.

Rod brown #8b5a2b; traces ruby red #b5123b; knob green #35984a, becoming lighter
#7bc66d during active selection/drag. Highlight is transient preview feedback,
cleared through the existing drag-end/focus-loss/close path, without authored
state or history changes. The UI forwards this feedback to the presenter through
the workspace preview. Optional rendered UI verification also captures the
selected knob in a sibling `_selected.png` file.

Official Godot 4.7 [Color](https://docs.godotengine.org/en/4.7/classes/class_color.html)
and [StandardMaterial3D](https://docs.godotengine.org/en/4.7/classes/class_standardmaterial3d.html)
documentation was checked before the styling change.

Fresh rendered UI verification: 45 passed, zero failed, including rod picking,
multi-turn dragging, undo/redo and point cycling. Report:
`test_artifacts/forge_v2_point_twist_ui_styling_20261017.json`. Rendered captures
`forge_v2_point_twist_ui_styling_20261017.png` and its `_selected.png` sibling were
visually inspected for the thinner traces, resized markers and lighter active
green knob. Scoped diff check passes. No full geometry/grip rerun was needed for
this display-only change; earlier geometric evidence remains historical.
