Yes. Here is the **clean rule pack** for the next resolver layer.

I am grounding it on the laws you already locked:

* first slice is **forge materials → cells → profiles → test prints** only 
* connectivity is **6-neighbor only** 
* mass and center of mass are **density-weighted**
* a handheld test print requires **one valid primary grip** in v0.1
* gameplay must read **BakedProfile**, not raw cells, and capability unlocks come from **matter + structure**, not visible classes

Everything below is designed to make:

* `AnchorResolver`
* `ShapeClassifierResolver`
* `BaseMaterialDef`
  happy without overbuilding the whole game.

---

# 1) NEW `BaseMaterialDef` FLAGS / FIELDS

These are **material-truth hooks**, not final gameplay outcomes.

Add these to `BaseMaterialDef` as first-pass exported fields or equivalent tag-based truth.

## A. Hard boolean flags

Use these when something should be **allowed or not allowed** at all.

```text
can_be_anchor_material
can_be_beveled_edge
can_be_blunt_surface
can_be_grip_profile
can_be_guard_surface
can_be_plate_surface
can_be_flex_material
can_be_tether_material
can_be_projectile_support
```

### Meaning

* `can_be_anchor_material`
  material may count toward grip/anchor ratio
* `can_be_beveled_edge`
  material may become a cutting edge if geometry passes
* `can_be_blunt_surface`
  material may count as a blunt striking body
* `can_be_grip_profile`
  material may be part of a handle/grip-safe segment
* `can_be_guard_surface`
  material may support shield/guard surfaces
* `can_be_plate_surface`
  useful for armor/shield plate classification
* `can_be_flex_material`
  useful for string/rope/whip logic later
* `can_be_tether_material`
  tether/chain-like support
* `can_be_projectile_support`
  helps ranged/bow/quiver systems later

## B. Optional shape-support biases

These can stay as direct floats or live in `capability_bias_lines`, but the meaning should exist.

```text
edge_bias
pierce_bias
blunt_bias
grip_bias
guard_bias
flex_bias
launch_bias
stability_bias
```

These are **not** final scores.
They are material-side contribution hints.

This is consistent with your current split:
`BaseMaterialDef` defines matter contribution; profile/capability resolution happens later. 

---

# 2) NEW DERIVED SHAPE STATES

These do **not** belong in `BaseMaterialDef`.
They are derived from cells/segments during resolution.

## A. Segment derived metadata

Either store temporarily on `SegmentAtom` or compute inside resolvers.

```text
major_axis
minor_axis_a
minor_axis_b
length_voxels
cross_width_voxels
cross_thickness_voxels
anchor_material_ratio
non_anchor_material_ratio
start_slice_anchor_valid
end_slice_anchor_valid
profile_state
has_opposing_bevel_pair
edge_span_overlap
```

## B. `profile_state` values

Use a tiny enum/string set for v0.1:

```text
square
chamfered_hex
beveled_blade
rounded
irregular
```

My recommendation:

* do **not** require true `rounded` logic yet
* `chamfered_hex` is enough for “grip-safe softened shape”
* `beveled_blade` is enough for edge logic

---

# 3) ANCHOR RESOLVER — v0.1 RULES

This is the real rule block.

## A. Scope

For v0.1, `AnchorResolver` only cares about:

* **primary grip**
* not secondary grip
* not offhand
* not projectile origin
* not guard center

That matches the first-slice law already locked.

## B. Primary grip candidate requirements

A segment is a **primary grip candidate** only if all are true:

### 1. Connectivity

* segment belongs to the connected root body
* no floating island logic bypass

### 2. Minimum dimensions

Let:

* `L = length_voxels`
* `T = cross_thickness_voxels`
* `W = cross_width_voxels`

Then valid primary grip candidate if:

```text
L >= 10
2 <= T <= 4
3 <= W <= 4
```

Allowed first-pass grip cross-sections:

* `2x3`
* `3x3`
* `3x4`
* `4x4`

This is the exact handle envelope you settled on.

### 3. Material ratio

Let:

* `anchor_material_cells = cells in candidate span with can_be_anchor_material = true`
* `total_cells = total cells in candidate span`

Then:

```text
anchor_material_ratio = anchor_material_cells / total_cells
```

For v0.1:

```text
anchor_material_ratio >= 0.80
```

Use 80%, not 70%, because you explicitly preferred the stricter threshold.

### 4. End-cap rule

The first slice and last slice of the candidate span must contain anchor-capable material.

```text
start_slice_anchor_valid == true
end_slice_anchor_valid == true
```

### 5. Profile safety

The candidate profile must be:

```text
square
or chamfered_hex
or rounded
```

For v0.1, `rounded` may simply behave the same as `chamfered_hex` if true rounding is not implemented.

### 6. No edge overlap

A grip candidate cannot overlap an active cutting-edge span.

```text
edge_span_overlap == false
```

## C. Primary grip validity formula

```text
valid_primary_grip =
    connected_to_root
    AND L >= 10
    AND 2 <= T <= 4
    AND 3 <= W <= 4
    AND anchor_material_ratio >= 0.80
    AND start_slice_anchor_valid
    AND end_slice_anchor_valid
    AND profile_state in {square, chamfered_hex, rounded}
    AND edge_span_overlap == false
```

## D. AnchorResolver outputs

For v0.1, it should return or fill:

```text
primary_grip_valid
primary_grip_position
primary_grip_axis
primary_grip_length
primary_grip_offset
validation_error
```

Where `validation_error` can be one of:

* `no_primary_grip_candidate`
* `grip_too_short`
* `grip_cross_section_invalid`
* `insufficient_anchor_material_ratio`
* `grip_endcaps_invalid`
* `grip_overlaps_edge_span`

---

# 4) SHAPE CLASSIFIER — v0.1 RULES

This can be its own resolver or merged later, but the logic should exist as a separate concept.

## A. Edge-capable rule

A segment/slice can count as **cutting edge** only if:

### Material rule

```text
material.can_be_beveled_edge == true
```

### Geometry rule

For a candidate blade slice:

* `T >= 2`
* `W >= 3`

### Bevel rule

There must be an **opposing bevel pair**.

So the minimum conceptual blade profile is:

```text
<|>
```

Meaning:

* left beveled flank
* center core
* right beveled flank

## Edge-valid formula

```text
valid_edge_slice =
    can_be_beveled_edge
    AND T >= 2
    AND W >= 3
    AND has_opposing_bevel_pair == true
```

## B. Important anti-bug rule

**Bevel does not automatically mean edge.**

A thick chamfered handle or mace head should not become cutting just because corners are softened.

So:

* `chamfered_hex` alone ≠ edge
* only `beveled_blade` with valid thin blade geometry = edge

## C. Blunt-capable rule

A segment is blunt-capable if:

```text
material.can_be_blunt_surface == true
AND valid_edge_slice == false
AND max(W, T) >= 3
```

This keeps blunt simple and stable.

## D. Grip-safe rule

A segment is grip-safe if:

* profile is `square`, `chamfered_hex`, or `rounded`
* material allows grip/anchor participation
* and it is not classified as an active edge span

---

# 5) BEVELING VS ROUNDING — LOCKED CALL

My call for v0.1:

## **45° bevel is enough**

You do **not** need true rounding yet.

Use:

* square
* chamfered
* beveled-blade

That is enough to distinguish:

* grip-safe handle
* cutting edge
* thick blunt/chamfered forms

So:

### For v0.1

* beveling required for cutting edge
* chamfer acceptable for grip-safe softened profile
* rounding optional/later
* no true curved profile math required now

---

# 6) DECORATION ON HANDLES — RULE

You wanted decoration allowed, but not too much.

For v0.1:

## Decorative allowance

Maximum decorative / non-anchor cells inside grip span:

```text
max_non_anchor_cells = floor(0.20 * L)
min_anchor_cells = ceil(0.80 * L)
```

Examples:

* `L = 10` → min anchor cells `8`, max decoration `2`
* `L = 15` → min anchor cells `12`, max decoration `3`
* `L = 20` → min anchor cells `16`, max decoration `4`

And still:

* start slice must be anchor-valid
* end slice must be anchor-valid

So decorative interruption in the middle is okay within allowance,
but decorative start/end is **not** okay.

---

# 7) WHAT COUNTS AS “WHAT”

## Handle / anchor candidate

* correct envelope
* enough anchor material
* grip-safe profile
* no edge overlap

## Cutting edge

* edge-capable material
* thin blade geometry
* opposing bevel pair

## Blunt

* strike-capable material
* not edge-valid
* thick enough body

## Decorative only

* does not satisfy grip
* does not satisfy edge
* does not satisfy blunt
* may still exist visually

That gives you the clean distinction you wanted.

---

# 8) WORKING SCALE RECOMMENDATION

This was not locked in docs, so this is my recommended working assumption, not a project law yet:

## Use:

```text
1 voxel = 2.5 cm
```

Then:

* `2x3x10` grip = `5.0 cm x 7.5 cm x 25 cm`

That is actually very believable for fantasy one-hand grips and keeps your TERA-inspired proportions sane inside a 2m-tall character world.

Treat this as:

* **working build scale**
* not final sacred law yet

---

# 9) AGENT-READY RULE BLOCK

Here is the direct copy block.

```text
ANCHOR / SHAPE RULES FOR V0.1

These rules are for runtime gameplay-side forge validation, not editor tooling.

Locked first-slice laws already in effect:
- connectivity is 6-neighbor only
- mass and center of mass are density-weighted
- handheld test print requires one valid primary grip
- gameplay reads BakedProfile, not raw cells
- layers are workflow/edit structure, not direct physics multipliers

A. BaseMaterialDef support fields
Add or support these material-truth hooks:
- can_be_anchor_material
- can_be_beveled_edge
- can_be_blunt_surface
- can_be_grip_profile
- can_be_guard_surface
- can_be_plate_surface
- can_be_flex_material
- can_be_tether_material
- can_be_projectile_support

Optional material-side float biases:
- edge_bias
- pierce_bias
- blunt_bias
- grip_bias
- guard_bias
- flex_bias
- launch_bias
- stability_bias

B. Derived segment metadata
Shape/segment resolution may derive:
- major_axis
- minor_axis_a
- minor_axis_b
- length_voxels
- cross_width_voxels
- cross_thickness_voxels
- anchor_material_ratio
- non_anchor_material_ratio
- start_slice_anchor_valid
- end_slice_anchor_valid
- profile_state
- has_opposing_bevel_pair
- edge_span_overlap

Allowed profile_state values for v0.1:
- square
- chamfered_hex
- beveled_blade
- rounded
- irregular

C. Primary grip candidate rules
A segment is a valid primary grip candidate only if:
- it belongs to the connected root body
- length_voxels >= 10
- 2 <= cross_thickness_voxels <= 4
- 3 <= cross_width_voxels <= 4
- anchor_material_ratio >= 0.80
- start_slice_anchor_valid == true
- end_slice_anchor_valid == true
- profile_state is one of: square, chamfered_hex, rounded
- edge_span_overlap == false

Allowed first-pass grip cross-sections:
- 2x3
- 3x3
- 3x4
- 4x4

Decoration rule:
- max_non_anchor_cells = floor(0.20 * length_voxels)
- min_anchor_cells = ceil(0.80 * length_voxels)

D. Edge classification rules
A segment/slice is edge-capable only if:
- material.can_be_beveled_edge == true
- cross_thickness_voxels >= 2
- cross_width_voxels >= 3
- has_opposing_bevel_pair == true

Important:
- beveling alone does not make something an edge
- thick chamfered shapes remain grip-safe or blunt unless they satisfy thin blade conditions

E. Blunt classification rules
A segment is blunt-capable if:
- material.can_be_blunt_surface == true
- edge-valid == false
- max(cross_width_voxels, cross_thickness_voxels) >= 3

F. Resolver boundaries
AnchorResolver v0.1 should output:
- primary_grip_valid
- primary_grip_position
- primary_grip_axis
- primary_grip_length
- primary_grip_offset
- validation_error

Validation errors may include:
- no_primary_grip_candidate
- grip_too_short
- grip_cross_section_invalid
- insufficient_anchor_material_ratio
- grip_endcaps_invalid
- grip_overlaps_edge_span

Shape classification should remain separate from profile math.
Do not implement secondary grip, offhand anchors, projectile origin anchors, or full mannequin fit validation in v0.1.

G. Bevel vs rounding
For v0.1:
- 45-degree bevel is sufficient
- true curved rounding is not required
- rounded may behave the same as chamfered_hex if true rounding is not implemented yet
```

---

# 10) Short recommendation

The next clean implementation order after this rule pack is:

1. add the `BaseMaterialDef` support flags
2. add/derive the segment metadata needed
3. implement `AnchorResolver` with **primary grip only**
4. implement a tiny `ShapeClassifierResolver` or equivalent helper for:

   * edge-valid
   * blunt-valid
   * grip-safe profile state

That will make the rest of the profile math much easier later.

If you want, next I’ll turn this into a **smaller implementation checklist per file**:

* what changes go in `base_material_def.gd`
* what changes go in `segment_atom.gd`
* what methods/signatures go in `anchor_resolver.gd`
* what helper resolver file to create for shape classification.
