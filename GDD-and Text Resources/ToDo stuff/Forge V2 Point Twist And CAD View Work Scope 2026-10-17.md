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

## Camera task (activated in a separate follow-up)

October 17 follow-up: see `Forge V2 Guided Planes And View Radial 2026-10-17.md`
for the approved predecessor-on-placement / self-on-adjustment rule, nearest-axis
RMB double-click, continuous camera travel, and V-held view radial. That note
supersedes the earlier rotation-lock proposal below: RMB orbit remains available.

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

## Smoothness audit after user authoring feedback - October 17

User reports sharp transitions at spline dots in the new traces, including an
apparently untwisted path, and wants the guides to depict the smooth material
shape. A dot must be a smooth pass-through, not an apparent exit/re-entry seam.
The earlier implementation assumption permitting abrupt angular-rate changes at
dots does not meet this intent. Analysis only in this follow-up: no production
geometry code changed and no replacement interpolation is yet implemented.

Compared live source to pre-twist commit ec978c57. Ordinary all-zero CSG still
uses the prior native spline route; the centerline sampler is unchanged. Ruby
rails always use ForgeV2PathRoll.build_body_curve, whereas generated profile
geometry uses that custom sweep when any roll is nonzero. Roll is currently
linear separately along each span, so the twist rate may abruptly reverse or
change at an interior dot even though the orientation itself stays continuous.

Fresh isolated Godot 4.7 audit loaded the old presenter source in memory alongside
the current presenter, without checkout or live-file replacement. Three ordinary
profile spline zero-roll fixtures produced exactly matching vertex/index arrays
(284, 96 and 196 vertices). A straight 0/90/0-degree fixture then produced a
21.38-degree turn in an outer guide trace at the middle point. This confirms a
twist-rate continuity defect, not an end cap inserted at every authored dot.

The unchanged sampler also drops auto Bezier handles shorter than 25 mm. The
compact (0,0), (50,50), (100,0) mm fixture loses all smoothing handles and forms
a polyline even at zero roll, identically before and after twist. This is a
pre-existing compact-curve limitation; do not mislabel it as a new regression.
The earlier curved verifier uses larger handles and compares current zero versus
uniform360 surfaces/end sections, not internal tangent continuity or old source.

Evidence: test_artifacts/forge_v2_twist_continuity_audit_20261017.json and
godot_runs/twist_continuity_audit_20261017.log. Diagnostic and archived-source text
are confined to test_artifacts. User's exact zero-roll example is not reproduced;
clarification remains pending on whether the generated solid is affected or only
the ruby guides. Static audit also found a smaller orientation-threshold change
in exported Handle framing; do not conflate that with proven spline results.

Recommended next correction: preserve the smooth centerline, make the unwrapped
roll field smooth through interior dots, and sample the same surface definition
for guides and generated material. Retain the 5 mm/turn density cap over the
whole interpolation, not merely endpoint differences, since easing can increase
the peak twist rate. Diagnose compact-curve smoothing separately. A live CSG
preview alone would not repair the underlying continuity; its need remains a
user choice after the shared geometry is correct.

## Actual TWIST TEST save audit - October 18

Follow-up supersedes the pending reproduction/clarification status above. User
provided matched-camera undo/redo screenshots and named saved draft TWIST TEST.
Treat preview disagreement and pass-through smoothness as separate defects.
This remains diagnosis only; no production geometry changes made.

Read the actual user library directly with ResourceLoader and duplicated the
authoring state in memory. TWIST TEST contains a pending 15-point spline, all
authored rolls zero, with the saved asymmetric eight-point "2 edge" profile,
25 by 118.75 mm. Placement normals are +Z for points 1-5, +X for 6-9, then +Z
for 10-15. Its nonzero smoothing handles are 56.63-145.93 mm. Therefore the old
25 mm handle cutoff does NOT explain this example. The saved file has no
committed material bodies; Generate was reproduced on the in-memory clone.
Source SHA256 remained unchanged throughout the successful diagnostic.

The immediate white pending-body preview and ruby guides have different frame
owners. At zero roll, _resolve_active_material_body_sweep_path plus
_build_profile_sweep_ring recompute profile frames from sampled placement
normals. Ruby guides always use ForgeV2PathRoll's transported Curve3D frames
and control-point tilts, corresponding to the native CSG path. These disagree
on the saved multi-plane path. A corresponding profile vertex can differ by
125 mm between frame constructions at the same center; this is a vertex
correspondence metric, NOT nearest-surface distance or claimed visible gap.
Any nonzero authored roll also selects a different pending-preview branch.

Fresh old-source/current-source comparison on this exact body, using the same
current workspace sampling contract, produced identical zero-roll pending mesh
vertices, indices AND normals. Native CSG vertices/indices likewise matched.
Thus this save does not demonstrate a regression in the untwisted generated
geometry between ec978c57 and current code. It does demonstrate a new guide
that disagrees with the pending preview and exposes pre-existing native-frame
problems. Earlier simple fixtures missed this combination and preview route.

Smoothness is independently confirmed. The analytic Bezier in/out tangents
match at every interior authored dot. Nevertheless automatic base tilts change
substantially: approximately 28.07, 170.54, 350.54 degrees at dots 5, 6, 7,
despite zero user roll. Base tilt comes from placement orientation and uses
per-span interpolation with no matching angular derivative through dots. The
tilt calculation also references a fresh world-up/right basis while Curve3D
uses transported up vectors. The outer guide at dot 7 turns about 56.11 degrees;
reducing sampling interval from 6.781 mm to 0.5 mm still gives 56.09 degrees,
while the fine centerline turn there is only 0.18 degrees. This is not merely
coarse tessellation, and no per-dot end caps are being inserted.

Official versioned source reference for tilt interpolation:
https://github.com/godotengine/godot/blob/4.7/scene/resources/curve.cpp#L1542-L1563

Next proposed correction: preserve the smooth centerline, consolidate guide,
pending preview and generated sweep onto one profile-frame definition, and
ensure orientation/twist rate stays smooth through interior dots. Include
automatic base orientation as well as authored roll, retaining the 5 mm/turn
density limit. A renderer-only replacement cannot fix the orientation rule.
No fix has been implemented or visually accepted in this audit.

Evidence: test_artifacts/diagnose_twist_test_saved_draft.gd,
test_artifacts/twist_test_saved_draft_audit_20261018.json,
godot_runs/twist_test_saved_draft_audit_20261018_verified.log. Focused headless
Godot 4.7 diagnostic completed with exit 0, no engine errors. An initial
diagnostic-only bool/Dictionary return-type mistake was corrected before this
successful run. No user saves, production geometry or Git index were changed.

## Smooth shared sweep implemented - October 18

User authorized fixing the diagnosed mismatch and knot smoothness. The shared
sweep now anchors the profile's initial facing once, then transports that frame
around the original smooth centreline. Later placement/view-plane normals guide
point placement without imposing hidden twist. Handle profile handedness is
retained separately. Authored unwrapped roll uses shape-preserving cubic Hermite
interpolation (PCHIP) with matching angular rate at interior dots; full turns and
the clockwise convention remain intact.

Guide traces, pending mesh, generated CSGMesh3D, material occupancy and Handle
authority curves use that shared sweep for both zero and nonzero roll. Surface
contact frames for Volume Stroke/Detailing Brush remain on their explicit path.
The rotation knob uses the same transported baseline. The Handle compatibility
shell cancels its existing legacy X reflection when consuming physical shared
frames, verified with an asymmetric profile rather than a symmetric rectangle.

The 5 mm/turn limit is checked against the maximum local cubic derivative,
including interior extrema. Input bounds are tightened against the complete
profile before whole-degree acceptance. A uniform two-point 100 mm twist still
allows 20 turns. A 0/peak/0 reversal on two 100 mm spans now permits a 10-turn
peak with the endpoint slopes of this interpolation; the previous 20-turn peak
would violate the local density limit when smoothed. This is intentional, not
loss of unwrapped turns. Sampling accounts for peak rate and profile radius.
Zero-length stations and nonfinite intermediate rates fail validation. All
consumers share the same centre-curve distance scale; arbitrary frame samples
interpolate rotations so the axes stay perpendicular.

Geometry signatures now invalidate old calculated results during regeneration:
exact Handle signature v3, shared sweep revision 2 in native-body and volume
cache tokens. Packet and wrapper format schemas are unchanged. Already baked
history checkpoints remain authoritative materialized geometry and are preserved.
Existing saved final mesh/target pairs are not rewritten by this change.

Production owners changed: forge_v2_path_roll.gd,
forge_v2_volume_preview_presenter.gd, forge_v2_material_volume_resolver.gd,
forge_v2_wip_compatibility_adapter.gd, and
core/resolvers/primary_grip_handle_mesh_packet.gd. Tests and this task note are
the remaining changes for this fix. No camera, gizmo styling or player-save
changes were needed.

Official Godot 4.7 workflows consulted before implementation:
- https://docs.godotengine.org/en/4.7/classes/class_curve3d.html
- https://docs.godotengine.org/en/4.7/classes/class_quaternion.html
- https://docs.godotengine.org/en/4.7/classes/class_csgmesh3d.html

Fresh verification (serialized Godot runs, editor allowed to remain open):
- Point twist/material/three wrapper targets/save-load and smooth-rate checks:
  57 passed. Existing quarter-span expectations were updated from linear45 to
  cubic67.5 degrees; source vertices, wrapper vertices and bias direction agree.
- Authoring lifecycle/mode conversion/undo-redo: 45 passed. Its dense monotone
  mode-conversion fixture is now seeded as a valid complete profile, avoiding an
  unrelated transient saturated reversal while creating that test fixture.
- Curved ordinary/Handle uniform360 and unchanged end sections: 12 passed.
- Asymmetric physical public export, stale v2 rejection and explicit surface
  contact preservation: 32 passed. An initial test-only Vector2.DOWN/Y-up seed
  error was corrected; tolerances/assertions were retained.
- Rendered point-twist UI controls/drag/Space cycling: 44 passed.
- Actual TWIST TEST saved draft, generated guide parity, smoothness, no hidden
  placement-normal twist and Generate/Undo/Redo: 10 passed, also rendered.

Total: 200 passed, zero remaining failures. Current focused logs are
godot_runs/twist_fix_geometry_20261018.log,
twist_lifecycle_fix_20261018.log, twist_curved_fix_20261018.log,
twist_export_fix_20261018.log, twist_ui_fix_20261018.log and
twist_saved_fix_rendered_20261018.log. Older verifier report filenames remain
fixed by those tools; the listed logs establish this fresh run date.

Actual-save evidence: test_artifacts/forge_v2_twist_saved_smoothness_20261018.json
and .png. The rendered generated solid plus actual ruby guide edges was visually
inspected. Guide-to-CSG corresponding-vertex error is 0.0002384 mm. The former
56.09-degree fine-sampled outer corner at dot 7 is now 0.248 degrees under the
same test. The largest checked fine-sampled outer-dot turn is 3.78 degrees;
rendered geometry remains discretized rather than mathematically infinite.
Asymmetric export: forge_v2_twist_export_frames_20261018.json; maximum checked
physical cross-section error 0.01482 mm, within the existing 0.05 mm tolerance.

TWIST TEST was loaded read-only and duplicated for Generate/Undo/Redo. Its
library SHA256 remains dc68f27c00d8385c483b8b84ceb58906f6150417849c24288ea15f8026a991a1.
No Git staging/commit/push performed. User's live in-game aesthetic acceptance
is pending; no claim that this authoring fix prevents arbitrary self-intersection
where a wide profile is swept around a very tight user-authored bend.

## User acceptance and pre-editing savepoint - October 18

After live examination the user confirmed the spline result: "smooth nice . good."
This supersedes the pending visual-acceptance status above. The user subsequently
requested a Git savepoint named along the lines of "Forge v2 additions" before
work on reopening retained spline geometry. Selection tints, ordinary-spline
reopening and a unified Handle editing entry remain proposed work; access modes
and keybindings are to be discussed after the savepoint. No such editing feature
is included in this savepoint.
