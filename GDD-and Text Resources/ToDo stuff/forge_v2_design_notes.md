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

## Forge V2 Local Keybindings V1

Current code foundation:
- Forge V2 now owns local editor bindings through `runtime/forge_v2/forge_v2_keybinding_state.gd`.
- These bindings are intentionally separate from the global settings/InputMap system for now.
- The Forge V2 binding state supports keyboard keys, mouse buttons, key-plus-key chords such as `C + F`, and key-plus-mouse chords such as `C + RMB`.
- Forge V2 key capture allows the broad normal keyboard range: Ctrl, Shift, Tab, CapsLock, letters, top-row numbers, symbols, navigation keys, arrow keys, and numpad numbers as distinct from top-row numbers.
- Forge V2 key capture currently blocks Enter, keypad Enter, Backspace, NumLock, and function keys F1-F12. The normal letter `F` remains valid.
- Bindings persist to `user://settings/forge_v2_keybindings.json`.
- The Forge V2 Settings popup opens a dedicated keybindings popup with action names on the left and editable binding boxes on the right.
- Clicking a binding box enters capture mode and shows `Press keys to bind`.
- A key press can become a key-only binding on release, can be combined with a second real key, or can be held while clicking a mouse button to form a chord.
- Forge V2 bindings are unique inside Forge V2. If a user gives action B the same binding as action A, action B steals that binding and action A becomes explicitly `Unbound`.
- Explicit unbound overrides persist, so stealing a default binding does not silently restore the old default after reload.
- The keybindings popup has a reset button that restores Forge V2 defaults.

Current default examples:
- `LMB` places/paints material.
- `RMB` orbits the view.
- `MMB` pans the view.
- `C + RMB` pans the view as an alternate binding.
- `L` selects the Spline Line tool.
- `B` selects the Volume Stroke tool.

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
