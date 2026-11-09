# Forge V2 Point Profile Transform

Status: taper implementation complete and focused checks passed; real Taper_test saved and ready for manual use. On 2026-11-09 the user explicitly parked mesh simplification until the taper task is finished/reviewed. Current user instructions override older proposals.

## Contract

- Spline Line and Detailing Brush only. Handles must remain unchanged.
- Right-click placed control points to assign transform-selection roles; temporary menu offers Expand X and Expand Y only for transform Point 2.
- Axes are the original Profile Builder local axes, carried by the existing path frame/twist, not screen axes.
- Signed percentage change: 0% = original, +100% = twice original. Interior points stop at -95%; first/last points permit -100%.
- X and Y are independent above zero. Latest user clarification: full collapse is always biaxial, producing a true point, never a zero-thickness flattened edge. Setting either endpoint field to -100% collapses both. Raising either field from that point first reopens both to that positive size, after which they are independent again. Generate a closed mesh without zero-area caps.
- Scale relative to the original profile, never the previous edit. No cumulative baseline change.
- Rounded lead-in by path distance across the selected boundaries, including intervening spline points. Final 2026-11-09 clarification supersedes the intermediate full-span smoothstep: begin a circular bend immediately at the fixed boundary, entirely INSIDE the selected extent, then continue tangentially on a straight taper to the requested target size. Radius = 5% of that boundary-to-target path distance, rounded half-up to 0.01 mm (3.21245 mm becomes 3.21 mm). No straight run before the bend. Each leg of a three-point selection uses its own length. The profile's outermost anchor-relative X/Y extents set the physical contour reference; other features follow the same axis scaling proportionally. It never restarts at intervening points, overshoots requested sizes, or moves fixed boundaries. Existing centreline/twist remain unchanged. Deliberate two-point hard steps stay hard.
- Detail uses its already-resolved surface path and contact frame. Preserve its sampling/attachment authority; do not smooth it a second time.
- Same scale samples drive guides, generated mesh and occupancy. Preserve Undo/Redo, E editing and disk persistence. No changes to grip logic, Handle wrappers, SC, or Git history.
- When a collapsed endpoint becomes an interior point by appending a point, its minimum becomes 5%; Undo restores the original endpoint.

## Owners

`runtime/forge_v2/forge_v2_path_scale.gd` shared dimension/interpolation math; `forge_v2_path_roll.gd` sweep frames; `forge_v2_material_body.gd`, `forge_v2_authoring_state.gd`, `forge_v2_stage_controller.gd` data/history; `forge_v2_volume_preview_presenter.gd` guides/mesh; `forge_v2_material_volume_resolver.gd` occupancy; `forge_v2_layer_data.gd`, `forge_v2_workpiece_solid_engine.gd` geometry records/backend eligibility; `crafting_bench_ui_v2.gd` context UI.

## Verification scope (completed; evidence below)

Unit-scale compatibility, asymmetric positive X/Y, paired endpoint collapse, adjacent-span isolation, twist combined with scale, Detail surface-frame parity, Undo/Redo (including append after collapse), E edit, disk round trip, and Handles remaining unchanged.

## Confirmed selectable taper extent

The user clarified a role-based selection workflow (role numbers are NOT spline point numbers):

1. Transform Point 1 is a fixed boundary.
2. Transform Point 2 receives Expand X/Y. Two-point selection is sufficient.
3. Optional Transform Point 3 is another fixed boundary, on the opposite side of Point 2 from Point 1. Point 2 must lie between the boundaries in a three-point selection.

Any number of spline control points can lie between these roles; they follow the complete taper. A two-point selection spanning actual spline points 2→5 keeps actual point 2 fixed and changes actual point 5. A three-point selection creates a diamond-like expansion/contraction around role 2.

Final clarification supersedes the earlier continuous-neighbour proposal: use explicit transform ranges over authored spans. In A B C D E F, selecting B as Point 1 and D as Point 2 changes B-to-D only. D-to-E-to-F stays unchanged, producing an intentional hard shoulder / T-shaped transition at D. A boundary may therefore have different incoming and outgoing cross-sections. Intervening points follow the taper by path distance when repositioned. Independent X/Y can produce crossing profiles at a step; independently capped continuous sweep sections are united through the existing private native Manifold backend. Do not fabricate overlapping geometry or connect crossing rings with invalid annular quads.

Menu role selection is temporary UI state; authored base scales plus transform range records persist through Undo/Redo, retained E editing and save/reload. Ctrl+Z/Ctrl+Y must include taper changes and affected extents. Handles remain excluded.

The 5% minimum is for direct edits of interior transform Point 2. Derived samples near a collapsed endpoint may be below 5%; promoting an unchanged derived sample to a fixed boundary must preserve its size.

## Player test weapon

User explicitly requested a real saved melee weapon named `Taper_test`, using the existing Fluted Blade profile and straight spline points spaced 0.15 m apart. Latest drawing replaces the initial nine-point proposal: five blade points forming a diamond followed by two tapered steps. Interior narrow joins remain at 5%, final endpoint collapses to zero; an unchanged medium-round Handle overlaps the first narrow end. Preserve all other library entries. Save/cold-reload evidence follows; no Git action authorized.

Completed real Save As: `Taper_test`, melee, WIP ID `player_wip_1794174939.044_15`. Actual player library now has one new fixture; all three prior weapon records and their authored data were checked unchanged. Five blade points at X=0/.15/.30/.45/.60 m; 15 cm Handle spans -0.13 to +0.02 m. Final export: 8,255 vertices / 16,506 triangles. Save portion measured 1.516 s on this fixture (not a general guarantee).

`godot_runs/forge_v2_taper_test/report.json` records successful Save, cold geometry/range reload, valid grip wrapper and preservation of prior weapons. Its strict Handle-field comparison initially failed on ordinary text serialization: 0.012500000186264515 became 0.0125 for profile_contact_distance_meters. `handle_roundtrip_report.json` separately proves all geometric source fields, sweep vertices, indices and normals identical (maximum vertex delta 0), and a fresh `.tres` round trip produces exactly the saved scalar. No production Handle/grip change was made. The fixture tool now compares a serialized expected Handle for future runs; the real library was not resaved for that verifier correction. Rendered saved parts inspected in `godot_runs/forge_v2_taper_test/overview.png` and match the user's five-point diamond/steps drawing.

## Fresh evidence so far

Final range implementation verification (fresh, after hard-boundary integration):

- `godot_runs/forge_v2_point_transform.json`: 208 checks, zero failures. Includes two-sided boundary rings, concave Fluted Blade diamond/T/cross-axis/point fixtures at 15 cm spacing, native closed-mesh acceptance, Detail range/contact-frame preservation, Undo/Redo, retained E editing, cold resource reload, paired-zero collapse, and collapsed fixed-boundary promotion on append.
- `test_artifacts/forge_v2_point_transform_ui_20261108.json`: rendered UI, 97 checks, zero failures. Includes Point 1/2/3 role selection, independent percentages, limits, popup history grouping, pending text and Ctrl+Z/Ctrl+Y inside/outside popup, paired collapse and reopening. Screenshot inspected at `godot_runs/forge_v2_point_transform_ui.png`.
- Existing twist lifecycle rerun: 45 checks, zero failures. Existing Detailing Brush state verifier rerun: exit 0.
- Production presenter/dependencies parsed successfully in Godot 4.7.

Earlier intermediate evidence (retained for traceability; superseded by final-range checks above):

- `godot_runs/forge_v2_point_transform.json`: initial 75 geometry/lifecycle checks passed.
- Existing twist lifecycle: 45 checks passed; existing Detailing state verifier passed.
- `godot_runs/forge_v2_point_transform_save.json`: real Forge Generate/commit/Save and cold Resource reload passed with the real fluted blade profile tapered to an apex, 0.24m unchanged Handle, 0.25m blade. Exact saved mesh and taper data preserved; Handle wrapper remained valid. This small fixture is not a general performance claim.
- Initial rendered context-menu test: 33 pass, 3 history checks failed. Cause: unconditional SpinBox.apply reread stale display text before a redraw. Fixed by applying only actually typed pending text; rerun passed39 checks. This result predates selectable boundary UI; rerun required for the final workflow.
- Geometry/lifecycle verifier later passed89 checks including zero-volume safeguards and dormant scale preservation. Range/anchor cases are being added; final result pending.

## Follow-up requested

### Active refinement 2026-11-09

User requests a gradual surface transition into inward/outward taper and correct S Apply/Cancel routing while transforming. Owners: `forge_v2_path_scale.gd` (physical circular lead-in, explicit arc samples and matching volume quadrature), `forge_v2_path_roll.gd` (sweep revision/sampling), `forge_v2_authoring_state.gd` (physical profile dimensions for labels, boundary snapshots and volume checks), `crafting_bench_ui_v2.gd` (forward Transform shortcut into existing global contextual confirmation), and the existing geometry/UI verifiers. Implemented and focused checks passed. S finalizes pending numeric input/grouped history and uses the existing new-shape or retained-edit context; it does not just dismiss the popup or invent another save pipeline. Handle geometry and grip behavior stay unchanged.

Fresh S check after final circular-lead implementation: rendered `verify_forge_v2_point_transform_ui.gd`, 150 passed / 0 failed. Includes pending text, root/native-popup input routes, generation/commit, complete-task cancellation, retained E Apply/Cancel, and remapped shortcuts. Log: `godot_runs/forge_v2_point_transform_s_check.log`.

Final circular-lead geometry check: `verify_forge_v2_point_transform.gd`, 243 checks / 0 failures. Verifies physical circle radius, decimal half-up rounding, tangent continuity into a straight remainder, exact sizes, no restart at intermediate controls, range isolation, reversed selection, retained hard steps, volume consistency, and source/contact-frame preservation for Detail. Real Fluted Blade fixtures include the original five-point diamond/two-step pattern with a zero-size fixed boundary; native acceptance and closed/nondegenerate topology pass. Reports/log: `godot_runs/forge_v2_point_transform.json`, `forge_v2_point_transform_easing.log`. Rendered four-case gallery inspected at `godot_runs/forge_profile_transform_fluted/overview.png`.

Verifier correction, not a production geometry repair: its old 0.1-micrometre vertex-key rounding merged distinct tiny triangles at a rounded zero-size fixed endpoint and reported 40 false edge mismatches. `tools/diagnose_forge_v2_taper_tip_boundary.gd` / `godot_runs/forge_v2_taper_tip_topology.json` proved exact emitted coordinates have zero unmatched edges and zero zero-area faces; native Manifold also accepted the mesh. Edge checking now uses exact coordinate bits (only signed zero is canonicalized), so it no longer tests a quantized replacement mesh. No geometric tolerance was loosened.

No player library entry was overwritten by this refinement; generated inspection fixtures are isolated artifacts. Simplification stays parked. No Git action performed.

Parked by user on 2026-11-09: finish/review taper before resuming mesh simplification. No simplification is active in Save/export or the saved Taper_test.

Confirmed future scope: retain the detailed editable Forge construction, but produce a simpler runtime mesh for all Forge output, including twisted geometry. Approved maximum surface deviation is 0.1 mm. Remove redundant planar triangles (a plain cube face needs only two); retain real flutes, shoulders, twist and apex geometry. Measure triangle counts and downstream costs rather than assuming Skill Crafter opening/equip time is all mesh loading; grip/setup costs remain separate.

Preparatory work only: a stateless native `simplify_export_mesh` API was drafted in the Manifold C++ source/header, but has not been compiled or connected to runtime. Incomplete metadata wiring is preserved in `Forge V2 Runtime Simplification Parked Metadata 2026-11-09.patch` and removed from active model/service code; those two files have no content diff from this work. The unrun verifier is parked outside the Godot project at `Forge V2 Mesh Simplification Parked/verify_forge_v2_export_simplification.gd.txt`. These are unfinished, unverified simplification work, not part of taper's passed checks. No native rebuild or simplification test is required for the current taper review.

The intended future integration seam is the runtime compatibility adapter, not modification of the editable sweep. Preserve detailed mass/balance authority and existing exact Handle/grip-target data; do not change grip algorithms. Any metadata must identify its source geometry and coordinate scale so saved exports cannot be repeatedly simplified or reuse stale metrics. Root runtime helper and adapter integration have not been implemented.

### Research checked 2026-11-09

- First candidate for this generated geometry: remove redundant straight sweep rings only when the replacement preserves each side patch's plane. Keep taper slope changes, steps, caps, apex, actual curvature and twist. Longitudinal vertex collinearity alone is insufficient for independent X/Y taper: side quads may be nonplanar. This is a code-based recommendation, not a measured reduction yet.
- The pinned C++ Manifold dependency (`798d83c8d7fabcddd23c1617097b95ba40f2597c`) exposes `Simplify`, `SetTolerance` and `AsOriginal`. Our packer assigns a unique faceID to every triangle. Manifold preserves boundaries between different faceIDs, so adding Simplify alone is unlikely to eliminate most redundant triangulation. Do not globally erase provenance: body/material association depends on it. [Manifold mesh properties](https://manifoldcad.org/docs/html/structmanifold_1_1_mesh_g_l_p.html), [Manifold simplification](https://manifoldcad.org/docs/html/classmanifold_1_1_manifold.html).
- General mesh reduction is also available through meshoptimizer, with error limits and attribute/edge preservation. If used later, choose a measured geometric-error budget and protect flutes, apex, shoulders, material boundaries and grip surfaces; do not chase a triangle-count percentage regardless of deviation. [meshoptimizer simplification](https://github.com/zeux/meshoptimizer#simplification).
- Godot 4.7 uses meshoptimizer for import-time LOD. LOD selects cheaper display meshes; it does not by itself reduce this Forge runtime Save/CSG input. [Godot 4.7 mesh LOD](https://docs.godotengine.org/en/4.7/tutorials/3d/mesh_lod.html).
- Earlier candidate owner was profile sweep mesh assembly. The user's later export-only requirement supersedes that proposal: use a detached runtime export copy, preserving authored profile/path/ranges and guide sampling. Validate native manifold acceptance, topology, volume, bounded surface deviation, cuts, retained E editing and Save reload; compare timings with the saved Taper_test baseline.

## Done confirmation and pure-navigation follow-up (2026-11-09)

User reported Done followed by S/Apply leaving a blank shape, plus lag while only moving the camera or unpressed mouse. This is navigation, not control-point manipulation. Forge fixes come first; only then investigate the new saved `Broken_Glave_v1` Skill Slot 1 opening stall. Mesh simplification remains parked.

- Done now finishes pending percentage input/history, clears temporary transform roles, and returns keyboard focus to the workspace. Direct S in Transform also clears these roles before using the existing task confirmation. Outside dismissal/role selection keeps its separate behavior. No authored taper or spline point is removed.
- Fresh rendered UI check: 170 passed / 0 failed, including actual Done button -> root S -> Apply for a new shape and retained E edit, triangle publication, changed retained mesh and visible-pixel comparison. `godot_runs/forge_v2_point_transform_done_check.log`; `test_artifacts/forge_v2_point_transform_ui_20261108.json`; `_done_apply_new.png` and `_done_apply_retained.png` beside that report. Initial verifier falsely required immediate native publication; it now waits for and checks the authoritative visible publication (native or existing CSG fallback), rather than relying on body count alone.
- Navigation root cause: `_get_spline_points` and `_get_active_v2_tool_id` requested the whole status summary on each orbit/hover. That summary repeatedly validates profile, twist and taper generation. Camera events also refreshed numerical roll limits despite no authored change. UI input now reads the authoritative active-state fields directly; view changes update only roll-control editability. Actual authoring changes still refresh validation and limits.
- Before: unchanged tapered Fluted fixture hover mean 205.571 ms/event; orbit 102.430 ms/event. Initial UI fix: hover 7.731 ms/event; orbit 0.480 ms/event. Pan remained about 0.016 ms/event. All measured phases retained identical authoring data/geometry and emitted no authoring edits. Reports: `godot_runs/forge_v2_taper_idle_before.json`, `forge_v2_taper_idle_after.json`. Initial after report includes one verifier mismatch because it compared the new six-field Detail input snapshot to the entire old status dictionary; each required field is now checked individually. The final rerun below passed.
- Remaining hover cost was unchanged-profile envelope validation for the placement cursor. Added a narrow authoring-state cache with exact deep profile-data matching, including in-place edits under the same profile ID; changed/invalid data still takes the normal validation path. Primitive/Handle and invalid-profile fallbacks keep their current brush radius. Cache is transient, not serialized.
- Final rendered navigation run passed (`godot_runs/forge_v2_taper_idle_final.json`, matching `.log`). Tapered hover mean **0.088 ms/event**, orbit **0.462 ms/event**, pan **0.012 ms/event**; idle/hover/orbit frame means all approximately **4.16 ms** on this machine. Untapered results were similar. All authoring snapshots and mesh resource IDs remained unchanged; zero authoring edits. Outside measured phases, checks passed for camera-tween disable/restore, direct Spline/Handle/Detail input parity, changed same-ID profile geometry, valid/invalid transitions, brush/tool/profile switches and nonserialized cache state. These are one-event-per-frame navigation measurements, not guarantees for arbitrary authoring geometry edits.

## References

- User diagrams and clarifications in this session: orange expands, green contracts; Profile Builder X/Y; Handles excluded; Detail included; endpoint full collapse authorized.
- `GDD-and Text Resources/How To Do Menu Work.md` (read fully): temporary popup lifetime, keep workspace context, close smallest layer.
- [Godot 4.7 PopupMenu](https://docs.godotengine.org/en/4.7/classes/class_popupmenu.html)
- [Godot 4.7 SpinBox](https://docs.godotengine.org/en/4.7/classes/class_spinbox.html)
- [Godot 4.7 Curve3D](https://docs.godotengine.org/en/4.7/classes/class_curve3d.html)
