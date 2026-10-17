# Forge V2 guided placement planes and view radial - 2026-10-17

## Scope and authority

User authorized preparation and implementation after clarifying independent new
placement and point adjustment. This activates the camera task parked in the
Point Twist And CAD View Work Scope note. Savepoint pushed before this work:
349a9091, `Forge v2 - point twist and indicator controls`.

## Agreed behavior

- 3D placement is the goal; planes are temporary guidance, never constraints
  binding the whole spline or moving neighboring points.
- First point in free view keeps existing initial placement (material hit or XY
  fallback). In an explicitly selected axial view it uses that plane through the
  existing workspace placement origin, so side/top views can start a path too.
  Subsequent Spline Line / Handle points use a view-oriented plane through the
  predecessor.
- Adjusting an existing point uses a plane through that point's current position,
  fixed for the drag. Changing views permits editing all three dimensions.
- View changes and point selection alone never relocate authored points.
- Six perpendicular orthographic views: front/back, left/right, top/bottom.
  Travel from current orientation at a constant angular speed using native Tween;
  distance and framing stay stable. Initial tuning: 180 degrees per second.
- Double RMB chooses the nearest signed axis from the current viewing direction,
  NOT the workspace face hit by a centre ray. Explicit radial choice selects that
  face even when another is nearer.
- RMB orbit remains available; C+RMB and middle-button pan remain available.
  Free orbit supplies an oblique camera-facing placement plane through the same
  appropriate point reference. Pan changes framing, not the plane's depth.
- Hold V for view radial, move toward a face and release V to choose. Release in
  centre cancels. Escape / lost focus cancels. This is independent from the parked
  Alt+RMB creation-actions radial in forge_v2_design_notes.md.
- Future RMB-tap task popups must distinguish taps from this double-RMB view
  alignment and existing drag-to-orbit; that older popup remains unimplemented.
- Reference image: cyan outer circle, orange wedge separators, yellow centre,
  dark background and pale icons. Camera radial has six outer face choices.
- Camera state is transient preview state, excluded from authored undo/redo and
  WIP data. View changes must not create empty transactions or dirty the WIP.
- A transition blocks point placement until arrival; it may be interrupted by
  orbit or another view choice. Existing points remain editable after arrival.
- Surface/Detailing tools retain their material-target rules; rotation rods retain
  their tangent-plane drag. Do not redirect every brush through the path plane.
- Out-of-box path intersections are rejected rather than clamped off an oblique
  guide plane. Work-plane grid must depict the actual guide within the box.

## Owners and files

- runtime/forge_v2/forge_v2_workspace_preview.gd: camera, Tween, projection,
  path-plane projection and preview-only guide state.
- core/defs/forge_view_tuning_def.gd: immutable camera-transition speed setting.
- runtime/forge_v2/crafting_bench_ui_v2.gd: menu/input/radial routing and feedback.
- runtime/forge_v2/forge_v2_keybinding_state.gd: rebindable view-radial action.
- New runtime/forge_v2/forge_v2_radial_menu.gd: reusable visual radial selector.
- New tools/verify_forge_v2_cad_planes.gd: isolated plane/camera/UI regression.
- This note, original scope pointer, and final SPS preserve evidence and gaps.

No grip, material geometry, target-wrapper, saved point schema or future action
radial implementation is part of this task. No automatic flatten-to-predecessor
command is required; user resolved that ambiguity with self-origin adjustment.

## Verification plan

One substantial Godot run at a time, using isolated diagnostic user data. Check
all six view directions and nearest-axis choice, noninstant transition and its
interruptibility, orthographic pan/zoom, new-point coplanarity, existing-point
depth preservation, free oblique placement and bounds, selection immobility,
RMB/radial input, unchanged history during view changes and retained point undo.
Rerun focused twist UI tests because view controls share their input paths.
Inspect a rendered capture. Record fresh evidence separately from prior tests.

## References

Official Godot 4.7 Camera3D, Tween, Control and InputEventMouseButton documentation.
Use native projection/ray helpers, linear-time quaternion interpolation and drawn
Control UI. The view is orthographic, not a spherical deformation of the model.

## Results

Implemented locally. Point selection preserves geometry; actual point drags
preserve their initial screen pick offset and make one undo entry. View commands
finish an existing edit before changing the camera. The visible work grid follows
the applicable reference and is clipped to the real workspace bounds.

Radial clockwise from top: Top, Right, Back, Bottom, Left, Front. Every opposite
face pair is opposite in the ring. It opens only over the workspace; text entry
and popup editing retain their keys. Holding the radial consumes other authoring
inputs until release/cancel. No old task radial actions were added.

Fresh Godot 4.7 results on October 17:

- Final rendered CAD/UI verifier: **160 passed, zero failed**, actual Forward+
  D3D12 renderer. Report `test_artifacts/forge_v2_cad_planes_20261017.json`;
  stdout/stderr `godot_runs/cad_planes_rendered_20261017_*`. No runtime errors.
- Earlier focused headless CAD/UI pass: **148 passed, zero failed**. Preserved
  report `test_artifacts/forge_v2_cad_planes_headless_20261017.json`. This predates
  additional explicit hover assertions and the final radial ordering.
- Existing twist UI regression: **44 passed, zero failed**;
  `test_artifacts/forge_v2_twist_ui_after_cad_20261017.json` and
  `godot_runs/cad_twist_regression_20261017_stdout.log`.
- Preview and actual UI scripts parse successfully. Scoped diff check passes.
- Rendered captures visually inspected:
  `test_artifacts/forge_v2_cad_views_20261017_radial.png` and `_plane.png`.

The synthetic radial test initially failed because Viewport.push_input did not
update actual pointer state. Headless uses Input.parse_input_event; rendered
Windows hover additionally requires positioning the real cursor inside the test
window. The focused verifier preserves/restores its initial screen coordinates
and checks restoration. Production hover rules were not weakened for the test.

Editor import registered new script UIDs but emitted native-extension shadow-DLL
copy warnings while another editor held those libraries. Separate script parses
and the real rendered verification loaded/run cleanly; do not call that editor
import warning-free. No native libraries or manifests were changed.

User manual authoring feel remains to be confirmed. No full-game grip, material
pipeline, or extreme fine-grid performance certification is claimed. At the
default 125 mm guide spacing the grid is modest; its redraw cost at unusually
fine spacing was not benchmarked. New camera work is uncommitted; only the
completed pre-camera twist savepoint 349a9091 was pushed.

## Workspace orientation gizmo - follow-up

User confirmed that the V radial works visually and requested the old bottom-right
workspace compass in Forge V2. Reuse the surviving
`scenes/ui/assets/transform_gizmo.glb`; the old display controller is recoverable
from pre-retirement commit d1701224. No Forge V1 services are restored.

The new `runtime/forge_v2/forge_v2_workspace_axis_indicator.gd` is a passive
86 x 86 pixel overlay, inset 12 pixels from the actual viewport's bottom-right
corner, with the original 6 pixel inner padding. `crafting_bench_ui_v2.gd` binds
it to the existing preview and camera. It displays workspace X/Y/Z orientation,
not numerical position or clickable view controls. Mouse input passes through.

The camera-relative workspace basis is sampled at RenderingServer.frame_pre_draw
so the indicator follows both free orbit and each Tween step without the extra
frame delay of node processing. A TextureRect displays the isolated transparent
SubViewport; UPDATE_ONCE is requested only for changed orientation, size or
visibility. Pan/zoom do not change compass size or orientation. Nothing is added
to authoring history or saved weapon data.

Official 4.7 API references checked before implementation:
- https://docs.godotengine.org/en/4.7/classes/class_subviewport.html
- https://docs.godotengine.org/en/4.7/classes/class_viewport.html
- https://docs.godotengine.org/en/4.7/classes/class_basis.html
- https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#signals

Fresh verification: UI parse is clean. The rendered Godot 4.7 check in
`tools/verify_forge_v2_axis_indicator.gd` passed **52/52** checks on Forward+
D3D12, covering all six face views, intermediate Tween alignment, orbit,
idle/hidden rendering, reopen, resizing, input passivity and unchanged authored
history. JSON: `test_artifacts/forge_v2_axis_indicator_20261017.json`; log:
`godot_runs/axis_indicator_rendered_verified_20261017.log`, no runtime errors.
The oblique capture `test_artifacts/forge_v2_axis_indicator_20261017.png` shows
the recovered asset inside the lower-right viewport corner; visually inspected.

The initial diagnostic had four false idle failures: SubViewport's node property
retains the last requested UPDATE_ONCE value even after the rendering server
automatically disables it. The corrected diagnostic queries the renderer RID;
fresh evidence records requested mode 1 versus actual renderer mode 0. No
production workaround was necessary. The renderer query is confined to tests.

This follow-up does not rerun the material/grip pipeline. User visual testing of
the new compass is next. All additions remain local and uncommitted.
