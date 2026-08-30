# Forge V2 Physical Truth And Handle Transform Work Scope — 2026-08-29

## Why This Note Exists

This note preserves the authorized work order and the boundaries agreed in the
active conversation. It is a continuation aid, not a second source of runtime
authority. Current code, focused verifiers, the project authority map, and the
newest SPS remain the evidence chain.

## Authorized Work Order

1. Correct the Forge V2 physical-truth output used by equip and Skill Crafter:
   spatial density-weighted material mass, true center of mass, unclamped
   Handle projection, deterministic Handle-zero mode/point, and COM-side
   Tip/Pommel selection.
2. Return to the existing grasping implementation, inspect the calculation and
   authority order with complete WIP data, then finish reliable surface contact.
   Initial completion is a direct solved pose; visual grasp tweens remain later.
3. Return to Forge V2 Handle authoring and design the parked sweep transforms:
   symmetric longitudinal size shaping and axial twist.

Only item 1 is authorized for implementation in the current slice. Item 2 is
the next implementation slice. Item 3 is recorded now so it survives context
loss, but its controls are not yet sufficiently specified for implementation.

## Current Slice: Required Outcome

### Spatial mass and center of mass

- Preserve material identity **and spatial material position** from Forge V2's
  existing winning-cell occupancy through the save/bake boundary.
- Resolve each material id through its authoritative material `.tres` density.
- Compute density-weighted mass contributions from spatial occupancy.
- Compute center of mass from `sum(sample_position * sample_mass) / total_mass`.
- Compute the result in Forge V2's authored-local meter space, then convert it
  through the compatibility API into `BakedProfile`'s legacy WeaponRoot cell
  units. `BakedProfile.center_of_mass` remains the serialized backing name;
  it is not a meter-valued field.
- Preserve the exact final-mesh volume as the total-volume authority. The coarse
  occupancy may determine material shares and spatial mass distribution; it
  must not replace exact final volume with a coarse voxel volume.
- Run the additional spatial aggregation at the save/bake compatibility seam,
  not once per frame, per brush input, or inside Skill Crafter playback.
- An empty or unresolved spatial sample set must fail visibly or use an already
  documented truthful source. It must not silently present the uniform mesh
  centroid as a density-weighted COM.

### COM authority and coordinate-frame boundary

- There is one physical weapon center of mass. Grip placement does not move it;
  grip placement changes the support point, lever arm, and later handling state.
- Fresh code names the immutable baked fact
  `weapon_intrinsic_center_of_mass_*`. It changes only when weapon geometry or
  spatial material distribution is rebaked.
- The exported `BakedProfile.center_of_mass` property is retained solely as the
  compatibility storage name used by existing V1 profiles and saved WIPs. Use
  the explicit intrinsic-COM getter/setter rather than creating a second
  exported COM authority.
- Handle coordinate mode, Handle zero, and Tip/Pommel semantics may read only
  weapon-intrinsic mass properties. Active hand placement must never write back
  to those baked facts or cause the Handle mode to switch.
- Future grip-relative values use `active_grip_*`; future derived motion limits
  use `handling_*`. Do not call either value a mobile or second COM.
- Current code uses `WeaponRootOrigin` for both persisted forge/geometry values
  and the grip-rebased runtime held-item frame. Existing math compensates for
  that rebase, so this slice does not rename or move the live origin.
- At the later V2-only cleanup boundary, formalize the distinction as an
  immutable `WeaponGeometryOrigin` followed by a runtime
  `WeaponEquipRootOrigin`/`PrimaryGripMountOrigin`. If a physics-COM pivot is
  useful, it is a derived child frame at the intrinsic COM, never the canonical
  weapon origin.
- V1 remains a compatibility branch while old profiles/saves are supported. Do
  not add new V1-only behavior; the existing ForgeService V1/V2 bake split is
  the intended deletion seam when V2 supersedes it.

### Handle projection, Handle zero, Tip, and Pommel

- Project true COM onto the complete Handle endcap axis without clamping it to
  the Handle span. Retain that unclamped ratio for physical interpretation.
- Keep the existing Handle contact/slider position as a separate value. A
  clamped contact ratio must never substitute for the COM projection.
- Determine the Handle positioning mode from true COM relative to the valid
  Handle section:
  - balanced Handle case: `-1..+1`, with zero at the Handle midpoint;
  - directional Handle case: `0..1`, with zero at the Pommel-side Handle
    endcap and one at the Tip-side Handle endcap.
- The geometric side containing true COM is the Tip/business side. The opposite
  extremity is Pommel. This holds whether COM is outside the Handle or within
  the Handle but biased to one side.
- If true COM is exactly on the Handle midpoint within the deterministic balance
  tolerance, use the canonical positive Forge V2 Handle-axis direction as Tip.
- Tip and Pommel positions remain actual extrema of the final WIP geometry along
  the resolved weapon axis; COM chooses their semantic labels rather than
  replacing their positions.
- Preserve normal/reverse-grip interpretation and the existing macro IK chain.
  This slice supplies correct upstream facts; it does not redesign grip pose.

## Performance Boundary

- Do not replay thousands of stroke bodies solely to recover position when the
  bounded-history checkpoint plus active-tail occupancy already owns the final
  spatial winning-material map.
- Do not add continuous physics, gravity simulation, or per-frame COM queries.
- Do not move the Forge placement hot path or bounded Boolean/history behavior.
- Focused bake/save work may be more expensive than an aggregate count, but its
  cost must be bounded by current retained occupancy rather than stroke count.

## Expected Code Seams (Confirm Before Editing)

- `runtime/forge_v2/forge_v2_material_volume_resolver.gd`
- `runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd`
- `core/models/baked_profile.gd` only if the existing fields cannot truthfully
  express the Handle-zero contract
- existing Forge V2 compatibility/material-volume verifier scripts

Avoid editing dirty authoring, stage-controller, UI, Handle-change, or Player
grip files unless inspection proves that the clean owner seam cannot supply the
required data. Any overlap must preserve the user's current local work.

## Focused Verification Contract

- Same geometry and same material layout produce deterministic mass and COM.
- Equal density reproduces the geometric centroid within occupancy tolerance.
- Two separated materials with unequal densities move COM toward the denser
  material while exact total final volume remains unchanged.
- Reversing which side owns the dense material reverses the COM and Tip side.
- COM outside the Handle produces an unclamped projection (`< 0` or `> 1`) and
  is not collapsed to an endcap ratio.
- Balanced Handle mode exposes midpoint zero and `-1..+1` bounds.
- Directional Handle mode exposes Pommel-end zero and `0..1` bounds.
- Existing Forge V2 WIPs can be rebaked without being recreated.
- Existing grip, menu, Handle-change, bounded-history, and deposition verifiers
  remain untouched except for focused compatibility assertions where needed.

## Next Slice: Grip (Parked Until Physical Truth Passes)

- Re-establish the exact chronological authority order from WIP load through
  Handle seat/orientation and the three-section digit solve.
- Grip solve is event-driven: initial equip and actual grip-arrangement changes,
  not every weapon/control-point movement and not debug-visibility toggles.
- First make the direct solved pose reliable. Animation/tween presentation is a
  later layer and must not own contact truth.
- Preserve the macro chain: the primary hand governs the weapon; in a two-hand
  state the secondary hand conforms to the already governed weapon/primary-hand
  pair.

## Future Forge V2 Handle Sweep Transforms (Recorded, Not Implemented)

### Intended longitudinal shape family

Only these three simple, symmetric outcomes from the supplied Handle reference
sheet are intended:

1. **Original/cylindrical (`0`)** — the authored profile keeps its original size
   for the whole Handle path.
2. **Symmetric concave** — the Handle is narrower around its longitudinal middle
   and expands toward both endcaps.
3. **Symmetric Jian-style convex** — the Handle is wider around its longitudinal
   middle and contracts toward both endcaps.

The other shapes shown on the reference sheet—finger grooves, asymmetric
waists, offset tapers, decorative cut ends, and named proprietary silhouettes—
are not targets.

The eventual UI is one signed slider centered at `0`. The sign mapping and safe
maximum/minimum scale or endcap-area percentages are intentionally
`NEEDS_DECISION` when implementation begins. The envelope must be symmetric
about the Handle's longitudinal center and must scale around each slice's
geometric center without translating the three-dot path.

### Intended axial twist

- Rotate the authored Handle profile around the local Handle-path tangent as it
  advances along the sweep.
- Use one deterministic authored twist rule (for example total turns or angle
  per path distance); its final unit and UI range are `NEEDS_DECISION` later.
- Do not translate the path or silently deform the source profile.
- Preview, committed CSG/sweep geometry, collision, save/reload, Change Handle,
  final mesh, and grip-target surface must all resolve the same transform.
- Endcaps must remain closed and Handle validity must use the transformed final
  Handle rather than an untransformed proxy.

### Reference images

- `C:/Users/ixro1/Downloads/maxresdefault.jpg` — axial twist concept only.
- `C:/Users/ixro1/Downloads/concave-convex-example_7abbbb2796.jpg` — simple
  concave/convex longitudinal distinction only.
- `C:/Users/ixro1/Downloads/Straight-Handles.jpg` — only the original Cylinder,
  symmetric Neotech Concave, and symmetric Jian-style forms identified by the
  user; all other examples are excluded.

## Explicitly Not Loaded Into The Current Slice

- Grip animation/tween presentation
- Two-hand authority implementation
- Mass/leverage velocity governor
- Momentum persistence, damage, critical-strike, or DPS implementation
- Handle twist or longitudinal scale implementation
- Ranged-weapon Handle rules
- Remove-material/void-authoring work

## Current Progress Ledger

- [x] Scope and authority restated.
- [x] Future Handle transform family bounded to the three intended shapes.
- [x] Spatial material occupancy exposed at the bake seam.
- [x] Density-weighted true COM saved into `BakedProfile`.
- [x] Unclamped COM projection and Handle zero corrected.
- [x] COM-side Tip/Pommel corrected.
- [x] Intrinsic COM, active-grip, and future handling vocabulary separated.
- [x] Legacy serialized COM storage retained without a second authority.
- [x] Focused verifiers pass.
- [x] Exact implementation files and evidence recorded below.

## Completed Implementation Evidence

### Reused authorities

- Forge V2 keeps its existing ordered winning-material occupancy, protected
  Handle behavior, incremental cache, and checkpoint-plus-tail restoration.
- V2 occupancy is analogous to V1 `CellAtom` data, but it is not converted into
  literal `CellAtom` resources. A conversion would lose V2 sample-volume and
  origin semantics and could allocate up to one resource per cached cell.
- Density-to-mass conversion reuses
  `MaterialMassResolver.resolve_mass_for_cell_equivalent_volume(..., 0.0)`, the
  same core material-mass authority used by V1. Only V2-specific origin checks,
  exact-volume rescaling, centroid correction, and first-moment accumulation
  remain at the V2 compatibility seam.
- Handle slice seating reuses `PrimaryGripSeatResolver`; canonical Handle-axis
  resolution and the existing final-mesh metric calculation remain authoritative.

### Changed implementation files

- `runtime/forge_v2/forge_v2_material_volume_resolver.gd`
  - publishes per-material spatial sample counts, cell-equivalent volumes,
    centroids, origin, and source from either active-body reconstruction or the
    existing checkpoint-plus-tail occupancy cache;
  - rejects pending cache promotion and malformed/stale checkpoint occupancy.
- `runtime/forge_v2/forge_v2_authoring_state.gd`
  - exposes the saved-state spatial summary through the existing bounded-history
    checkpoint and retained-tail authority, with one-time reconstruction only
    for states that have no checkpoint.
- `runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd`
  - combines exact final-mesh volume with occupancy material shares;
  - resolves spatial density-weighted mass and true COM;
  - publishes unclamped COM projection, Handle-zero mode/point, and COM-side
    Tip/Pommel semantics;
  - skips the spatial scan when Handle validation has already failed.
- `core/models/baked_profile.gd`
  - retains legacy `center_of_mass` serialized storage behind an explicit
    weapon-intrinsic COM API;
  - persists intrinsic COM authority/origin, unclamped projection, Tip-side
    direction, Handle-coordinate-mode facts, and the origin companion for
    center-balance position.
- `services/forge_service.gd`
  - passes the existing runtime material lookup into the V2 adapter and does not
    overwrite authoritative spatial mass during later material enrichment.
- `runtime/combat/combat_animation_station_preview_presenter.gd`
  - rebakes legacy cached V2 profiles that predate the spatial physical-truth
    contract.

### Focused verification results

- `verify_forge_v2_weighted_mass_orientation_contract.gd`: PASS
  - legacy `center_of_mass` storage saves/reloads through the intrinsic-COM API
    with exactly one serialized COM backing property;
  - equal-density COM ratio `0.500000000`;
  - mirrored wood/gold COM `+/-0.160621 m`, mirror error `0.000000030 m`;
  - checkpoint + protected Handle + tail equals full-history occupancy at
    `2304` occupied samples;
  - reversed authored Handle path leaves COM, canonical axis, and zero unchanged;
  - one-sided dense fixture retains unclamped ratio `1.251540990` while surface
    contact remains clamped to `1.0` and directional zero remains Pommel-side;
  - malformed initialized checkpoint without prefix occupancy fails visibly.
- `verify_forge_v2_wip_runtime_contract.gd`: PASS.
- `verify_forge_v2_grip_order_balance_contract.gd`: PASS.
- `verify_forge_v2_exact_handle_grip_surface.gd`: PASS.
- `verify_forge_v2_runtime_contract_fallback_load.gd`: PASS.
- `verify_mochi_vertical_slice.gd`: PASS (V1 compatibility bake).
- `verify_combat_origin_registry.gd`: PASS; all `17` registered chains are
  valid and `WeaponRootOrigin` remains a dynamic child of
  `SolvedReplayReferenceOrigin`.
- `verify_combat_origin_annotations.gd`: PASS; strict source pairs and
  forbidden-pattern checks remain clean.

The new spatial pass runs only at save/bake compatibility time. It walks the
already bounded occupancy map once and does not alter brush deposition, Boolean,
checkpoint-promotion, per-frame Skill Crafter, or playback hot paths.
