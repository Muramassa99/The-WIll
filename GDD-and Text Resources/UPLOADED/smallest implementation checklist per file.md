Perfect. Here is the **smallest implementation checklist per file** for:

* `base_material_def.gd`
* `segment_atom.gd`
* `anchor_resolver.gd`
* `joint_resolver.gd`
* `bow_resolver.gd`
* `baked_profile.gd`

This is shaped to fit the current approved first-slice architecture:

* materials are universal matter truth,
* gameplay reads `BakedProfile`,
* raw cells are not gameplay truth,
* and resolvers stay separate from controllers/services.  

---

# 1) `core/defs/base_material_def.gd`

## Purpose

Defines **material truth** only.

It should know:

* what matter can do
* what matter can become
* what matter is allowed to support

It should **not** know:

* final weapon class
* final bow validity
* final joint validity
* final profile math

## Add these fields

### Existing physical truth

Keep:

* `base_material_id`
* `display_name`
* `density_per_cell`
* `hardness`
* `toughness`
* `elasticity`

### Existing atom arrays

Keep:

* `base_stat_lines`
* `capability_bias_lines`
* `skill_family_bias_lines`
* `elemental_affinity_lines`
* `equipment_context_bias_lines`

### Add hard support flags

```text id="zpl8dd"
can_be_anchor_material
can_be_beveled_edge
can_be_blunt_surface
can_be_grip_profile
can_be_guard_surface
can_be_plate_surface

can_be_joint_support
can_be_joint_membrane
can_be_axial_spin_joint
can_be_planar_hinge_joint

can_be_bow_limb
can_be_bow_string
can_be_riser_core
can_be_projectile_support
can_be_bow_grip
```

### Optional future bias fields

These can be real floats now or postponed, but the schema should allow them.

```text id="pqj0it"
edge_bias
pierce_bias
blunt_bias
grip_bias
guard_bias
flex_bias
launch_bias
stability_bias

joint_stiffness_bias
joint_damping_bias
joint_recovery_bias
joint_flex_bias
joint_twist_bias

limb_flex_bias
limb_recovery_bias
string_tension_bias
string_elasticity_bias
projectile_stability_bias
draw_stability_bias
```

## Add tiny helper methods only

* `has_tag(tag: StringName) -> bool`
* `supports_anchor() -> bool`
* `supports_bow_string() -> bool`
* `supports_joint() -> bool`

No formulas.

---

# 2) `core/atoms/segment_atom.gd`

## Purpose

Represents a **grouped physical region** after clustering.

It should know:

* which cells belong together
* what kind of region this might be
* enough derived metadata for later resolvers

It should **not** know:

* final profile scores
* final combat meaning
* runtime nodes
* controller state

## Keep existing

* `segment_id`
* `role`
* `member_cells`
* `material_mix`

## Add these fields

### Basic geometric metadata

```text id="73l9rs"
major_axis
minor_axis_a
minor_axis_b
length_voxels
cross_width_voxels
cross_thickness_voxels
```

### Material composition metadata

```text id="85lx4p"
anchor_material_ratio
joint_support_material_ratio
bow_string_material_ratio
```

### Edge / grip / joint metadata

```text id="jlwmf0"
start_slice_anchor_valid
end_slice_anchor_valid
profile_state
has_opposing_bevel_pair
edge_span_overlap
```

### Joint metadata

```text id="uzs6ly"
joint_type_hint
link_count
hinge_count
```

### Bow metadata

```text id="r6pb0g"
is_riser_candidate
is_upper_limb_candidate
is_lower_limb_candidate
is_bow_string_candidate
projectile_pass_candidate
```

## Allowed `profile_state` values

Use a small enum or string set:

```text id="kngmp3"
square
chamfered_hex
beveled_blade
rounded
irregular
```

## Tiny helper methods

* `get_cell_count() -> int`
* `is_empty() -> bool`
* `has_material(material_variant_id: StringName) -> bool`

Still no profile math.

---

# 3) `core/resolvers/anchor_resolver.gd`

## Purpose

Resolve **primary grip legality only** for now.

It should know:

* grip candidate dimensions
* anchor-material ratio
* start/end slice rules
* profile-safe states
* edge overlap exclusion

It should **not** know:

* full combat
* final behavior families
* bow logic
* joint logic except excluding articulated spans if already marked

## Minimal methods to add

### Public

```text id="36iu3t"
detect_primary_grip_candidates(segments: Array[SegmentAtom], material_lookup: Dictionary) -> Array[AnchorAtom]
validate_primary_grip(segment: SegmentAtom, material_lookup: Dictionary) -> bool
build_primary_grip_anchor(segment: SegmentAtom) -> AnchorAtom
calculate_primary_grip_offset(center_of_mass: Vector3, grip_position: Vector3) -> Vector3
```

### Private helpers

```text id="g98b2c"
_is_valid_grip_envelope(segment: SegmentAtom) -> bool
_has_valid_anchor_ratio(segment: SegmentAtom) -> bool
_has_valid_grip_endcaps(segment: SegmentAtom) -> bool
_is_grip_safe_profile(segment: SegmentAtom) -> bool
_overlaps_edge_span(segment: SegmentAtom) -> bool
```

## Locked rules this resolver must use

Grip valid only if:

* `length_voxels >= 10`
* `2 <= cross_thickness_voxels <= 4`
* `3 <= cross_width_voxels <= 4`
* `anchor_material_ratio >= 0.80`
* `start_slice_anchor_valid == true`
* `end_slice_anchor_valid == true`
* `profile_state in {square, chamfered_hex, rounded}`
* `edge_span_overlap == false`

These rules are now part of the physical-item law stack you are building on top of the approved first-slice pipeline.  

## Output expectations

The resolver should be able to produce:

* `primary_grip_valid`
* `primary_grip_position`
* `primary_grip_axis`
* `primary_grip_length`
* `primary_grip_offset`
* `validation_error`

---

# 4) `core/resolvers/joint_resolver.gd`

## Purpose

Resolve **articulated chain / hinge / spin legality**.

This should be a **new file**.

It should know:

* joint span geometry
* support-material ratio
* square vs rectangular hinge plane
* local motion mode
* self-collision mode

It should **not** know:

* bow logic
* final combat
* controller/runtime nodes
* full profile scoring

## Create file

`core/resolvers/joint_resolver.gd`

## Public methods

```text id="gxaqk1"
classify_joint_segments(segments: Array[SegmentAtom], material_lookup: Dictionary) -> Array[SegmentAtom]
validate_joint_chain(segment: SegmentAtom, material_lookup: Dictionary) -> bool
resolve_joint_properties(segment: SegmentAtom) -> Dictionary
```

## Private helpers

```text id="drp74m"
_is_valid_joint_envelope(segment: SegmentAtom) -> bool
_has_valid_joint_material_ratio(segment: SegmentAtom) -> bool
_is_square_cross_plane(segment: SegmentAtom) -> bool
_is_rectangular_cross_plane(segment: SegmentAtom) -> bool
_calculate_link_count(segment: SegmentAtom) -> int
_calculate_hinge_count(segment: SegmentAtom) -> int
_determine_joint_type(segment: SegmentAtom) -> StringName
_determine_motion_plane(segment: SegmentAtom) -> StringName
_determine_self_collision_mode(segment: SegmentAtom) -> StringName
```

## Locked rules

Joint-valid only if:

* `A >= 2`
* `B >= 2`
* `C >= 4`
* `C % 2 == 0`
* `joint_support_material_ratio >= 0.80`

Square cross-plane:

* may allow `axial_spin`, `planar_a`, `planar_b`

Rectangular cross-plane:

* only `planar_forced`
* hinge axis = longer hinge-plane dimension
* angle range = `-90° to +90°`

## Output fields / dictionary keys

```text id="gh821m"
joint_chain_valid
joint_type
joint_axis
motion_plane
link_count
hinge_count
angle_limit_min
angle_limit_max
supports_axial_spin
supports_planar_hinge
self_collision_mode
validation_error
```

---

# 5) `core/resolvers/bow_resolver.gd`

## Purpose

Resolve **ranged/bow specialization** inside ranged context only.

This should also be a **new file**.

It should know:

* ranged context gate
* bow-specific segment classes
* 1x1 bow-string exception
* limb validity
* projectile pass point
* draw/release axis

It should **not** know:

* generic melee family resolution
* full projectile combat
* animation playback
* runtime rope simulation

## Create file

`core/resolvers/bow_resolver.gd`

## Public methods

```text id="yx1cjd"
validate_bow_structure(segments: Array[SegmentAtom], material_lookup: Dictionary, forge_intent: StringName, equipment_context: StringName) -> Dictionary
resolve_bow_reference_points(segments: Array[SegmentAtom]) -> Dictionary
resolve_bow_axes(reference_center: Vector3) -> Dictionary
```

## Private helpers

```text id="rqpv3f"
_is_ranged_context(forge_intent: StringName, equipment_context: StringName) -> bool
_find_riser_segment(segments: Array[SegmentAtom]) -> SegmentAtom
_find_upper_limb_segment(segments: Array[SegmentAtom]) -> SegmentAtom
_find_lower_limb_segment(segments: Array[SegmentAtom]) -> SegmentAtom
_find_bow_string_segment(segments: Array[SegmentAtom]) -> SegmentAtom
_is_valid_bow_string(segment: SegmentAtom, material_lookup: Dictionary) -> bool
_is_valid_limb_segment(segment: SegmentAtom, material_lookup: Dictionary) -> bool
_calculate_bow_asymmetry_score(upper_flex: float, lower_flex: float) -> float
```

## Locked rules

Bow rules activate only if:

* `equipment_context == ctx_weapon`
* `forge_intent == intent_ranged`

Bow requires:

* one valid primary grip
* one valid riser
* one valid upper limb
* one valid lower limb
* one valid bow string
* one valid projectile pass point

Bow string rule:

* continuous `1x1` path
* all string cells use `can_be_bow_string == true`
* connects upper and lower string anchors

Limb rule:

* `material.can_be_bow_limb == true`
* cross-section `>= 2x2`
* limb length `>= 4`

## Output keys

```text id="810hye"
bow_valid
bow_reference_center
projectile_pass_point
shoot_axis
draw_axis
upper_string_anchor
lower_string_anchor
string_rest_path
string_draw_path
upper_limb_valid
lower_limb_valid
upper_limb_flex_score
lower_limb_flex_score
string_tension_score
bow_asymmetry_score
validation_error
```

---

# 6) `core/models/baked_profile.gd`

## Purpose

This is still the **gameplay-facing truth** layer.

It should receive outputs from:

* `AnchorResolver`
* `ShapeClassifierResolver`
* `JointResolver`
* `BowResolver`
* later `CapabilityResolver`

It should **not** compute them itself.

## Keep current first-slice fields

Keep the approved first-slice geometry and capability fields:

* `total_mass`
* `center_of_mass`
* `reach`
* `primary_grip_offset`
* `front_heavy_score`
* `balance_score`
* `edge_score`
* `blunt_score`
* `pierce_score`
* `guard_score`
* `flex_score`
* `launch_score`
* `capability_scores`
* `primary_grip_valid`
* `validation_error` 

## Add future-facing fields now or reserve them mentally

### Joint/articulation outputs

```text id="t6n4o2"
joint_chain_valid
joint_type
joint_axis
motion_plane
link_count
hinge_count
supports_axial_spin
supports_planar_hinge
self_collision_mode
```

### Bow outputs

```text id="2g7se4"
bow_valid
bow_reference_center
projectile_pass_point
shoot_axis
draw_axis
upper_string_anchor
lower_string_anchor
upper_limb_valid
lower_limb_valid
bow_asymmetry_score
string_tension_score
```

You do **not** need to fully consume these yet, but having room for them now prevents future naming drift.

---

# Minimal implementation order from here

## First

Update:

* `base_material_def.gd`
* `segment_atom.gd`

## Then

Create:

* `joint_resolver.gd`
* `bow_resolver.gd`

## Then

Expand:

* `anchor_resolver.gd`
* `baked_profile.gd`

## Still do **not** do yet

* full profile formulas
* full capability thresholds
* full combat behavior
* actual rope physics
* full projectile system

---

# Short version

## Files to touch now

* `base_material_def.gd`
* `segment_atom.gd`
* `anchor_resolver.gd`
* `joint_resolver.gd` *(new)*
* `bow_resolver.gd` *(new)*
* `baked_profile.gd`

## What each does

* `BaseMaterialDef` = support flags
* `SegmentAtom` = derived metadata container
* `AnchorResolver` = primary grip only
* `JointResolver` = articulation legality
* `BowResolver` = ranged specialization legality
* `BakedProfile` = receives results, does not invent them

