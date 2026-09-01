# Forge V2 Design Notes

## Workspace Contract V1

Current code foundation:
- The canonical V2 workspace contract lives in `runtime/forge_v2/forge_v2_workspace_contract.gd`.
- The V2 stage controller owns one workspace contract and exposes it through `get_workspace_contract()`.
- The V2 viewport preview reads the contract instead of owning hardcoded workspace dimensions.
- The contract currently owns local bounds, placement-plane mode, placement-plane depth, grid step, fit size, visual offsets, visible bounds-box intent, and the future world-prop anchor id.

Why this matters:
- Future placement tools, raycasts, transparent-box visuals, save/export, world-prop binding, and optimization passes should all aim at the same contract.
- The authoring space should stay local and stable even when its presentation later becomes a physical forge prop in the world.
- The viewport and the diegetic forge box should present the same authored object, not become two separate sources of truth.
- This gives us one place to reason about workspace scale, legal authoring volume, and later performance rules.

Open followups:
- Bind the contract to an actual in-world transparent box/forge furniture transform.
- Move placement from the current plane-only target toward contract-driven surface or volume targets.
- Decide whether the workspace contract is saved per project, per station, or kept as a shared V2 station default.
- Route future continuous paint, stroke sampling, selection, and deletion through the contract instead of ad hoc viewport rules.
- Add a small editor-visible status/debug readout only if it helps development, and do not treat that as shippable UI.

## Brush Stroke Placement Foundation

Current code foundation:
- Left mouse placement is intended to act as a brush stroke, not only as isolated single-click sphere deposits.
- The UI begins a placement stroke on left press, samples additional local 3D positions while dragging, and finishes the stroke on release.
- The stage controller owns the active placement stroke id so the UI does not need to know how strokes and material bodies are paired.
- The authoring state updates the existing stroke/body pair as sampled points are added, keeping one drag action as one material body.
- The workspace contract owns the stroke sample spacing rule, currently based on active brush radius.

Why this matters:
- Continuous placement should not be married to the temporary plane target.
- Later the targeting layer can swap from "ray hits the plane" to "ray hits a surface, box face, volume cursor, or existing material" while the stroke sampler still receives local 3D points.
- Sampling through the contract gives us one future optimization target for density, mesh cost, drag smoothness, and material accounting.
- Treating a drag as one stroke/body keeps deletion, selection, undo layering, and material ledger work cleaner than spawning hundreds of unrelated dots.

Open followups:
- Replace the temporary placement plane with a real 3D target system.
- Add stroke preview quality controls if mesh rebuild cost becomes visible.
- Decide how brush stamping, capsule paths, primitive insertion, and future spline/noodle placement share the same stroke/body pipeline.
- Add true paint-over-surface behavior once material bodies have selectable/raycastable collision or proxy surfaces.

## Deferred Remove-Material Cut-Surface Aesthetic Pass

This is parked visual/material-publication work. It must not fork Remove into a
second path or Boolean solver: Add and Remove continue consuming the same
authored geometry, with Remove differing only by depositing VOID.

- When subtraction exposes a new face, resolve the material volume directly
  adjacent to each part of that cut and apply its associated `.tres` surface
  material/texture to the newly exposed face.
- A cut through multiple materials must preserve those spatial boundaries. For
  example, cutting through red, green, and blue volumes should expose red,
  green, and blue cut regions respectively rather than one generic cut color.
- The translucent red Remove representation remains an authoring preview only.
  It must not become the committed, saved, reloaded, exported, or downstream
  Skill Crafter surface material.
- Preserve current curved-path parity, Boolean geometry, Undo/Redo, commit,
  Save/Save As, collision, and reload behavior while adding this aesthetic
  publication step.
- Acceptance requires the visible cut-surface material assignment to remain
  identical before and after commit, save/reload, and final WIP export.
- This feature is forward-only. It does not need to migrate, rebake, repair, or
  retroactively alter existing saved WIP projects. Testing and acceptance will
  use newly authored WIPs created after the feature becomes live.

## Freehand Smoothing Setting V1

Current code foundation:
- The V2 settings popup is player-facing UI opened from the top action bar.
- The first setting is `Freehand Smoothing`, stored on the workspace contract as a whole-number value from 0 to 10.
- The setting is intentionally not applied to stroke geometry yet. It is reserved for the next sampler/spline pass.
- The current drag stroke still samples from mouse-motion GUI events and then applies the workspace contract's distance gate.
- Current sample spacing is `max(active_brush_radius_meters * stroke_sample_spacing_radius_ratio, stroke_sample_spacing_min_meters)`.
- Current defaults are a 0.55 radius ratio and a 0.00625 m minimum spacing.

Why this matters:
- Freehand smoothing needs to behave like a brush stabilizer, not like random post-hoc mesh cleanup.
- The player-facing 0-10 control should survive the replacement of the temporary plane and the later move to true 3D targeting.
- The smoothing setting belongs beside stroke sampling policy because it changes how the authored centerline is produced.

Open followups:
- Add a deterministic stroke sampler instead of relying directly on mouse-motion event frequency.
- Decide the fixed sampling cadence before spline smoothing is applied.
- Use the 0-10 value to blend between raw cursor points and a smoothed centerline.
- Keep raw input available long enough to debug the difference between player motion, sampled centerline, and final noodle mesh.
- Use the smoothed centerline as the foundation for true closed noodle volume: wall surface, flat/rounded end caps, material add/replace policy, and later same-material merge behavior.

Freehand stabilizer implementation added and integrated 2026-08-10:
- `runtime/forge_v2/forge_v2_freehand_input_stabilizer.gd` now provides a reusable screen-space input stabilizer with no scene, camera, surface, or material ownership.
- Smoothness `0` is direct input. Values `1-10` use deterministic 60 Hz timestamp resampling plus a delayed centered triangular-weighted window whose lookahead is the selected step count.
- Release stops raw input, pads and drains the delayed window, and ends at the exact final valid screen sample without retaining stroke history.
- Internal smoothing history is bounded to at most 21 uniform samples. Catch-up output is also bounded per call so a long frame stall cannot create an unbounded raycast burst.
- Focused verifier: `tools/verify_forge_v2_freehand_input_stabilizer.gd`.
- `crafting_bench_ui_v2.gd` now owns stabilizer lifetime during a Volume Stroke, raycasts stabilized screen samples in order, applies them through the batched stroke API, drains the tail on release, and restores accumulated-input ownership on every finish/focus-loss path.
- Live drawing uses a collisionless swept `ArrayMesh` instead of rebuilding active CSG for each accepted sample. The final committed CSG/collision result remains authoritative and can still have a measurable release-time cost.
- Honest boundary: stabilizing the cursor path does not by itself guarantee exact wrapping over rapidly changing 3D surfaces. Target sampling and final committed CSG orientation remain separate responsibilities that require interactive evidence.

## Deferred QoL: User-Defined Profile Catalogs

This is parked Profile Creator and saved-profile library work, not part of the
current Forge V2 implementation pass.

- Add a folder-equivalent organization feature so users can catalogue their
  own saved brush profiles instead of navigating one flat list that may grow
  beyond 200 profiles.
- The user must be able to define the organizational groups. The final UI,
  naming, nesting behavior, and storage representation remain deliberately
  undecided until this feature is designed.
- Catalog organization is presentation and bookkeeping metadata. It must not
  alter profile geometry, material behavior, profile identity, saved-WIP
  references, or downstream resolver results.
- Existing profiles must remain valid when the catalog feature is introduced.

## Deferred QoL: RMB Apply Popup And Alt+RMB Deposition Radial

This is parked Forge V2 workflow work. It must reuse the existing tool commands,
authoring state, profile selection, and local keybinding system rather than
creating parallel deposition or generation paths.

### RMB tap: local Apply popup

- While actively authoring any point/path-derived Forge V2 operation -- Handle,
  Spline Line, or Detailing Brush -- tapping `RMB` opens a compact two-option
  popup at the current mouse position.
- The top option is `Apply`. It is presented as a green rectangular button with
  bold `Apply` text.
- `Apply` routes to the active mode's existing generation/commit command: the
  same semantic action currently exposed as that mode's equivalent of
  `Generate CSG Noodle`. Do not duplicate the geometry-generation logic inside
  the popup.
- A Handle mode must therefore call its existing Handle apply/generate path;
  Spline Line and Detailing Brush must call their own existing equivalents.
- The popup must preserve the currently selected mode, operation, material,
  profile, and authored points. It is a quick command surface, not a second tool
  state.
- The second popup option has not been named or assigned yet. Do not invent its
  behavior during implementation; confirm it first.
- Current `RMB` drag camera orbit remains valid. Tap-versus-drag gesture
  disambiguation must prevent an orbit gesture from opening the popup and must
  prevent a popup tap from moving the camera.

### Later Alt+RMB hold: six-button deposition quick tray

- Later, holding `Alt+RMB` opens a simple six-button radial selector at the
  pointer: four outer deposition-mode buttons plus the two center operation
  buttons.
- Selection is directional from the radial origin: upward movement selects the
  12-o'clock group, rightward movement selects the 3-o'clock group, with the
  remaining two modes occupying the corresponding 6- and 9-o'clock groups.
  Exact mode-to-direction assignment remains to be confirmed.
- The center is divided into two operation targets: left is `Add`, right is
  `Remove`.
- Each of the four outer mode slots is prepared in advance through the normal
  Forge menus. Its configured quick-slot state pulls the selected mode's chosen
  profile and the other settings that are deliberately assigned to that slot.
- The radial consumes those prepared settings; it is not where profiles or
  detailed tool parameters are searched, edited, or browsed.
- This creates a limited working set analogous to laying several chosen pens on
  the table. The player can swap among them immediately at the pointer. Choosing
  a different profile, thicker marker, or other non-prepared variant requires
  opening the extended menu and replacing/configuring one of the quick slots.
- Quick-slot activation must use the same authoritative profile, material,
  operation, and tool-setting data used by the full menus. Do not maintain a
  second reduced copy of geometry or deposition rules inside the radial.
- The last selected deposition mode is sticky and remains the active default
  until the user changes it through either the radial selector or the normal
  menu. Opening or applying a multi-step Handle operation must not silently
  reset that selection.
- The radial is a fast front end over the same four existing deposition modes;
  it must not introduce alternate authoring implementations.
- Implement the gesture through the existing Forge V2 local keybinding/input
  infrastructure so it does not become an untracked hardcoded input exception.

The supplied radial image is a directional interaction reference only. The
only committed visual requirements at this stage are the four directional mode
groups and the center-left Add / center-right Remove split.

### Future surface-coloring reuse

- Reuse the same quick-tray principle for the later surface-coloring workflow.
- The color palette coexists with the deposition-tool palette. It does not
  replace, remap, or temporarily convert the tool radial into a color radial.
- Give the tool palette and color palette separate input chords so either can be
  summoned directly during the same authoring workflow. The exact keybind
  combinations remain deliberately undecided until the later rested design
  pass.
- The full coloring menu prepares a limited color palette in advance; the
  radial exposes those selected colors at the pointer for immediate switching.
- The radial remains a fast selector over that prepared palette. Searching the
  full color library, changing palette membership, and advanced color setup stay
  in the extended menu.
- The intended workflow is continuous authoring with the selected pens/colors
  already at hand, avoiding repeated menu traversal during active work.

## Forge V2 Local Keybindings V1

Current code foundation:
- Forge V2 now owns local editor bindings through `runtime/forge_v2/forge_v2_keybinding_state.gd`.
- These bindings are intentionally separate from the global settings/InputMap system for now.
- The Forge V2 binding state supports keyboard keys, mouse buttons, key-plus-key chords such as `C + F`, and key-plus-mouse chords such as `C + RMB`.
- Forge V2 key capture allows the broad normal keyboard range: Ctrl, Shift, Tab, CapsLock, letters, top-row numbers, symbols, navigation keys, arrow keys, and numpad numbers as distinct from top-row numbers.
- Forge V2 key capture currently blocks Enter, keypad Enter, Backspace, NumLock, and function keys F1-F12. The normal letter `F` remains valid.
- Bindings persist to `user://settings/forge_v2_keybindings.json`.
- The Forge V2 Settings popup opens a dedicated keybindings popup with action names on the left and editable binding boxes on the right.
- Clicking a binding box enters capture mode and shows
  `Press key / mouse button`.
- A key press can become a key-only binding on release, can be combined with a second real key, or can be held while clicking a mouse button to form a chord.
- Forge V2 bindings are unique inside Forge V2. If a user gives action B the same binding as action A, action B steals that binding and action A becomes explicitly `Unbound`.
- Explicit unbound overrides persist, so stealing a default binding does not silently restore the old default after reload.
- The keybindings popup has a reset button that restores Forge V2 defaults.

Current default examples:
- `LMB` places/paints material.
- `RMB` orbits the view.
- `MMB` pans the view.
- `C + RMB` pans the view as an alternate binding.
- `Ctrl+Z` performs action-level Undo.
- `Ctrl+Y` performs action-level Redo.
- `L` selects the Spline Line tool.
- `B` selects the Volume Stroke tool.
- Mouse 4 and Mouse 5 are valid configurable inputs for any Forge V2 action,
  including Undo and Redo.

Why this matters:
- Forge V2 needs editor-grade controls before tool complexity grows.
- The global settings system currently handles simple keyboard bindings well, but Forge V2 needs mouse chords and local authoring commands.
- Forge V2 can prove the better binding model first; later the global settings system can adopt the useful parts.
- Keep the binding model broad now; later, individual commands can restrict themselves to mouse-only, key-only, key-plus-key, or key-plus-mouse where that makes sense.
- Godot `InputMap` remains the right native reference for simple global actions, but Forge V2 keeps a local custom layer because it needs scoped editor commands and arbitrary two-key chords beyond modifier-only combinations.

Open followups:
- Add categories or grouping once the keybinding list grows.
- Add visible binding hints in tooltips/status only after the command surface stabilizes.
- Consider promoting this chord-capable binding model to global settings later.

Action-level history is unbounded by user-action count inside the active native
material window. It is pruned by acknowledged CSG checkpoint promotion while
the native `checkpoint + five ordinary tail CSGs + protected Handle` structure
remains unchanged. The authoritative behavior and lifecycle contract is documented in
`Forge V2 Action Undo Redo Work Scope 2026-08-30.md`.

## Spline Line Tool V1

Current code foundation:
- Forge V2 now has a selectable `Spline Line` tool id in the authoring state.
- The Shape menu exposes a Tool submenu with `Volume Stroke` and `Spline Line`.
- The local keybinding defaults bind `B` to Volume Stroke and `L` to Spline Line.
- The current geometry path is still the existing stroke/path preview pipeline; the dedicated spline/CSG noodle system is not implemented yet.

Why this matters:
- Tool selection now exists before the spline implementation arrives.
- Future spline placement can reuse the same settings/keybinding shell instead of arriving as another hardcoded special case.
- The current data already records path points and radius, which is close to the future centerline-plus-volume model.

Open followups:
- Implement point-based spline authoring behavior for `Spline Line`.
- Convert spline authoring output into a `Curve3D`/`Path3D` style centerline.
- Test `CSGPolygon3D` path extrusion as the professional noodle operand.
- Decide how spline endpoints become flat caps, rounded caps, or separate cap primitives.

## Benched Spline Line And Handle Select Solid Orientation Reference

Deferred design intent:
- Add an optional `Select Solid` magnetic orientation reference for future
  Spline Line and Handle authoring.
- Spline Line and Handle centerlines remain unrestricted 3D paths. Selecting a
  connected solid does not pull the path onto its surface and does not inherit
  the surface-conforming path law used by CSG Material Stroke and Detailing
  Brush.
- The selected connected solid supplies only the roll/B-C orientation bias
  toward the reference while the path position and tangent remain authored in
  free 3D space.
- At each path sample, project the direction toward the selected-solid
  reference into the plane perpendicular to path tangent `T`. Use that
  projected direction as the magnetic orientation reference rather than
  changing `T` or the centerline.
- If the reference direction is parallel or near-parallel to `T`, or otherwise
  degenerates, preserve the last valid projected direction when available and
  use a deterministic least-parallel canonical-axis fallback when it is not.
  The fallback must not introduce nondeterministic roll flips.
- Preview geometry, generated/final geometry, saved authoring data, and WIP
  reload must resolve the same reference, frame, and fallback result.
- While placing or moving Spline Line control dots, show a live shadow/profile
  sweep preview of the prospective authored profile geometry and its resolved
  orientation. This should provide the same kind of immediate decision feedback
  as the Skill Crafter blade/pose preview, so the user can choose point position
  and orientation visually instead of guessing and pressing Generate to inspect
  the result.

Prerequisite and boundary:
- This feature requires a stable connected-solid identity that survives the
  relevant authoring and persistence lifecycle; transient body ids or mutable
  render-zone membership are not sufficient authority.
- This feature is explicitly benched. It is outside the current CSG Material
  Stroke/Detailing Brush surface-frame and connected-surface work and must not
  broaden that implementation pass into Spline Line or Handle path changes.
  The shadow/profile sweep preview is deferred with the same future Spline Line
  and Handle orientation infrastructure.

## Deferred QoL: Reopen And Edit A Committed Handle

Requested behavior:
- Add an explicit `Edit Handle` action for the distinct semantic Handle
  component. This is deferred QoL work and is not part of the current Handle
  minimum-span feedback pass.
- Reopen the selected committed Handle in its original three-dot/connection-line
  authoring form, including its authored profile, point positions, surface-frame
  data, and other settings required to reproduce the same component.
- Allow the three points, length, curve, and profile settings to be adjusted with
  the same controls and validity feedback used while creating a new Handle.
- Regenerating the edited Handle must replace the old Handle component rather
  than adding a second Handle authority. The replacement should be atomic: keep
  the old committed Handle recoverable until the edited replacement is valid and
  committed, and make Cancel leave the original unchanged.
- The under-minimum start-to-end span must use the same red-guide feedback and
  generation gate as new Handle creation. Point 2 remains excluded from the
  minimum endpoint-span calculation.
- Preserve editability through WIP save/reload so a Handle can be adjusted after
  testing the WIP in Inventory, equip, or the Skill Crafter.

Acceptance boundary for the later implementation:
- At most one active committed semantic Handle exists before and after editing.
- A successful edit removes/retires the old Handle body and installs the new one
  without leaving duplicate geometry, material-ledger entries, history entries,
  collision, or runtime grip authority.
- Undo/redo, bounded history, final save-time composition, and the existing V2
  runtime compatibility adapter must observe the replacement as one coherent
  operation.
- Do not reconstruct the editable path from the final fused mesh when the saved
  semantic Handle authoring data is available.

## Placement Target Resolver V1

Current code foundation:
- The canonical V2 mouse-hit resolver lives in `runtime/forge_v2/forge_v2_placement_target_resolver.gd`.
- The workspace preview calls the resolver through `resolve_placement_target(screen_position)`.
- The old `screen_to_workspace_local(screen_position)` entry point remains as a compatibility wrapper for UI code that only needs a local position.
- The current target kind is still `target_placement_plane`, but it is now only one resolver mode, not the core placement architecture.

Why this matters:
- The temporary plane can be removed later without rewriting brush strokes, material bodies, or UI drag logic.
- The resolver result now has room for future 3D targets: target kind, local/world hit position, local/world normal, hit distance, raw vs clamped position, and source body/source record ids.
- Future placement can decide whether the ray hit a workspace box face, existing material surface, free-depth cursor, selected body proxy, or another authored target.
- This keeps the Workspace Contract responsible for legal authoring space while the resolver is responsible for "what did the player aim at?"

Open followups:
- Add `target_workspace_box_face` so the transparent authoring box can be a real target.
- Add `target_material_surface` once material bodies have collision/proxy surfaces.
- Decide whether snapping, depth stepping, and surface offset belong in the resolver or a later placement operation layer.
- Route hover UI/status through the target kind so the editor can communicate what the player is actually aiming at.

## Diegetic World-Space Authoring Box

V2 authoring should lean into the current useful behavior where the crafted structure exists in the same world space as the forge area.

Current observation:
- V2 currently deposits preview material in a world-space authoring area rather than in a fully isolated abstract editor space.
- This was not originally treated as a finished design feature, but it has useful player-facing value.
- Seeing the ongoing model in the same world as the forge station gives immediate scale reference.
- It also makes the WIP feel like a real object being worked on, not just data hidden behind an editor panel.

Design intent:
- Use the "same world space" behavior as an intentional forge prop instead of hiding it.
- Make the authoring workspace feel like physical crafting furniture inside the game world.
- The player should be able to walk up to the forge area and see the unfinished project waiting there.
- This supports the fantasy that the player is shaping matter directly in-world.
- This also supports later social/showcase value: other players or the player themselves can visually inspect an in-progress build.

Future direction:
- Represent the active weapon/project inside a transparent physical box near the forge station.
- Treat that box as actual in-world furniture/prop, not only an invisible editor surface.
- Bind the V2 authoring workspace to that physical structure so it can later be moved, manipulated, or showcased.
- Let the player see the ongoing project waiting in-world between sessions, giving scale and presence without needing to equip it.
- Keep the editor viewport and world-space representation coherent: the model in the workspace box should feel like the same object being authored.

Authoring box behavior direction:
- The transparent box is the visible boundary of the legal creation volume.
- Deposited material should appear inside that box.
- The box can become the physical anchor/origin for the authoring workspace.
- Later, moving or rotating the furniture could move or rotate the presentation of the WIP without changing the authored local geometry.
- The box should help communicate scale, bounds, and where material can be placed.
- The box should eventually replace the feeling of "placing material on a random plane" with "placing material inside a forge containment volume."

Implementation direction, later:
- Keep authored geometry in a stable local authoring space.
- Bind that local authoring space to a world-space forge prop transform.
- The UI viewport can look into that same authoring space, while the in-world prop can display the same WIP.
- Avoid making the viewport and the physical prop become two different sources of truth.
- The world-space display should be a presentation/anchor for the authored model, not a separate duplicate editing system.

Not the current target:
- Do not build the lazy-susan animation yet.
- Do not solve moving forge furniture yet.
- Do not solve multiplayer showcase/spectator rules yet.
- Do not treat this note as a requirement to replace the current click-to-place proof loop immediately.
- The near-term goal remains making V2 material placement and editing better.

Later polish idea:
- Add a lazy-susan style presentation mode where the project slowly rotates and gently oscillates up/down as if floating.
- This is not a current implementation target; the important foundation is the transparent authoring box and world-space binding.

## Parked Handle Sweep Transforms: Three-Shape Family And Twist

This is a future Forge V2 Handle-authoring feature. It is recorded now, but it
must not be mixed into the current mass/center-of-mass or Skill Crafter grip
passes.

Intended longitudinal shape family:
- `0` preserves the original/cylindrical authored profile size along the Handle.
- One signed-slider direction produces a symmetric concave Handle: narrower at
  the longitudinal middle and wider toward both endcaps.
- The opposite direction produces a symmetric Jian-style convex Handle: wider
  at the longitudinal middle and narrower toward both endcaps.
- The slider sign mapping and safe maximum/minimum scale or endcap-area limits
  remain deliberately undecided until implementation.
- Scale each perpendicular sweep slice about its own geometric center. Preserve
  the authored three-dot path rather than moving it to create the silhouette.

Reference boundary:
- From `Straight-Handles.jpg`, only Cylinder, the symmetric Neotech Concave, and
  the symmetric Jian-style form are intended.
- Finger grooves, asymmetric waists, compound decorative shapes, bevelled cut
  ends, and the other reference silhouettes are explicitly outside scope.

Separate axial-twist transform:
- Rotate the authored profile deterministically around the local Handle-path
  tangent as the sweep advances.
- Final controls may use total twist or twist per path distance; the unit and
  range remain undecided until the user elaborates the thread/spiral behavior.
- Preview, committed geometry, collision, save/reload, Change Handle, runtime
  surface targeting, and the final exported mesh must agree.
- Keep endcaps closed, retain one semantic Handle, and persist the transform
  parameters with the existing Handle authoring snapshot.

The detailed active/continuation boundary lives in
`Forge V2 Physical Truth And Handle Transform Work Scope 2026-08-29.md`.

## Weapon Intrinsic COM And Runtime Grip Boundary

- Forge V2 calculates one density-weighted weapon-intrinsic COM from spatial
  material truth. Grip changes do not move that COM.
- Existing serialized `BakedProfile.center_of_mass` remains compatibility
  storage in WeaponRoot cell units; fresh code reaches it through the explicit
  `weapon_intrinsic_center_of_mass_*` API.
- Baked Tip/Pommel, Handle coordinate mode, and Handle zero read intrinsic mass
  properties only. Future `active_grip_*` relationships feed future
  `handling_*` outputs one way and never write back.
- `WeaponRootOrigin` currently covers both forge/geometry-local data and the
  grip-rebased held-item root. Preserve that working contract now. When V1 is
  removed, the clean V2-only origin model should distinguish immutable
  `WeaponGeometryOrigin` from runtime `WeaponEquipRootOrigin` or
  `PrimaryGripMountOrigin`. COM is not either root; an optional physics-COM
  pivot would be a derived child frame.
