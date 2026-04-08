Yes. Here is **System 2: Joint / Articulation Rules** in a clean, agent-ready form.

I’m treating this as the next physical-item truth layer after:

1. edge / blunt / handle
2. **joint / articulation**
   and still keeping it compatible with your first-slice laws: 6-neighbor connectivity, baked-profile authority, and separate material truth vs later behavior resolution.  

---

# 2. JOINT / ARTICULATION RULES

## Design purpose

This system defines **articulated physical segments**:

* chain-like sections
* hinge sections
* spin joints
* membrane-bridged joints
* future rope/flail/tether-style weapon parts

This is **not** AnchorResolver logic.
AnchorResolver remains for:

* primary grip
* handle legality
* hand-related anchors only

Joint / articulation is a separate physical-item system.

---

## A. Joint segment minimum geometry

Let a candidate articulated segment be measured in its **local frame**:

* `A` = cross-plane dimension 1
* `B` = cross-plane dimension 2
* `C` = length along chain axis

A valid articulated segment must satisfy:

```text id="9vbw2y"
A >= 2
B >= 2
C >= 4
C must be even
```

### Interpretation

Each **2 voxels** along the chain axis becomes one rigid link unit.

So:

```text id="g2vnvu"
link_unit_length = 2
link_count = C / 2
hinge_count = link_count - 1
```

Examples:

* `2x2x4` → valid minimum articulated segment
* `2x2x6` → valid
* `2x2x8` → valid

This matches your repeated `2-thick` link idea and stays consistent with the existing cell/segment model where connected cells are first clustered into segments before later profile logic reads them. 

---

## B. Joint support material rule

A joint segment must be made mostly from correct joint-support material.

Add a ratio check similar to handle logic:

Let:

* `joint_support_cells` = cells in the articulated span whose material supports joints
* `total_cells` = all cells in the articulated span

Then:

```text id="is8un0"
joint_support_material_ratio = joint_support_cells / total_cells
```

For v0.1 / v0.2:

```text id="kuxixh"
joint_support_material_ratio >= 0.80
```

That keeps the same philosophy as the grip rule:
functional structure should be mostly real support material, not decorative nonsense.

---

## C. BaseMaterialDef support flags needed

Add these material-truth hooks to the material schema, because articulation legality should come from matter + shape, just like other physical systems. Your docs already treat Material Atom as the thing that contributes physical truth and capability unlocks. 

## Hard booleans

```text id="8m76kg"
can_be_joint_support
can_be_joint_membrane
can_be_axial_spin_joint
can_be_planar_hinge_joint
```

### Meaning

* `can_be_joint_support`
  material may form rigid articulated link units
* `can_be_joint_membrane`
  material may form the flexible/continuous bridge between joint units
* `can_be_axial_spin_joint`
  material may be used in spin-capable articulated sections
* `can_be_planar_hinge_joint`
  material may be used in planar hinge sections

## Optional future bias fields

```text id="3u6i8y"
joint_stiffness_bias
joint_damping_bias
joint_recovery_bias
joint_flex_bias
joint_twist_bias
```

These do not need full formulas now, but the concept is worth preserving.

---

## D. Joint type from cross-plane symmetry

This is the square vs rectangle rule you described.

Let:

* chain axis = local `C`
* hinge plane = local `A x B`

### Case 1 — square hinge plane

If:

```text id="d4oa70"
A == B
A >= 2
```

Then the segment is **square-symmetric**.

Allowed joint modes:

```text id="aq3ctq"
axial_spin
planar_a
planar_b
```

Meaning:

* free rotation around chain axis
* or hinge motion in one plane
* or hinge motion in the other plane

For a local frame where chain axis is `Z` and hinge plane is `XY`, this means:

* spin around `Z`
* or hinge about `X`
* or hinge about `Y`

### Motion limits

For first pass:

* `axial_spin` = full spin around chain axis
* `planar_a` = `-90° to +90°`
* `planar_b` = `-90° to +90°`

---

### Case 2 — rectangular hinge plane

If:

```text id="wl7gwh"
A != B
A >= 2
B >= 2
```

Then the segment is **rectangular**.

Allowed joint mode:

```text id="dlzwfr"
planar_forced
```

Rule:

* the **longer hinge-plane dimension** determines the hinge axis
* the motion plane becomes:

  * chain axis
  * plus the shorter hinge-plane dimension

So if:

* `X = 2`
* `Y = 3`
* chain axis = `Z`

Then:

* longer side = `Y`
* hinge axis = `Y`
* motion plane = `XZ`

### Motion limits

For first pass:

```text id="shfgm4"
-90° to +90°
```

No full spin for rectangular sections.

---

## E. Joint validity formula

A segment is a valid articulated joint chain if:

```text id="wt14o0"
valid_joint_chain =
    connected_to_root
    AND A >= 2
    AND B >= 2
    AND C >= 4
    AND (C % 2) == 0
    AND joint_support_material_ratio >= 0.80
```

This keeps articulation grounded in:

* real connectivity
* real segment geometry
* real material legality

which is consistent with the project’s broader “matter + shape -> profile -> gameplay” rule. 

---

## F. Membrane / bridge rule

The membrane bridge is allowed, but it should **not** become authored rigid-body truth.

### First-pass law

A membrane is:

* a runtime connector/bridge between rigid link units
* used to preserve silhouette and continuity
* not a grip
* not an edge
* not a blunt head
* not a normal rigid authored segment

So:

```text id="gq0g99"
valid_joint_membrane =
    valid_joint_chain
    AND membrane_material.can_be_joint_membrane == true
```

This keeps the authored structure sane while still allowing the visual/tactile continuity you want.

---

## G. Self-collision rule

You explicitly wanted self-collision to matter, but not instantly break the joint.

So for first pass:

### Ignore self-collision for:

* the immediate rigid pair directly connected by one hinge
* the membrane bridge between them

### Enable self-collision for:

* non-adjacent articulated units
* all rigid sections outside the immediate joint neighborhood
* the world as normal

So:

```text id="qp0d5i"
self_collision_exempt_zone = immediate_joint_pair + membrane_bridge
self_collision_enabled_elsewhere = true
```

That is simple and good enough.

---

## H. Classification precedence

This is important so a segment does not become everything at once.

A span classified as:

* **articulated joint chain**

is **not simultaneously**:

* primary grip
* cutting edge
* blunt striking head

unless it is split into distinct adjacent sub-segments.

This keeps the physical truth readable and prevents nonsense overlap.

---

## I. JointResolver outputs

`JointResolver` / `ArticulationResolver` should output something like:

```text id="l56zj4"
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

### `joint_type` values

```text id="0t8z40"
none
axial_spin
planar_a
planar_b
planar_forced
```

That is enough for later profile/capability consumers without overcommitting to combat yet.

---

## J. Resolver boundaries

This is where each truth belongs.

### `AnchorResolver`

Handles:

* primary grip legality
* grip position / axis / offset
* handle rules only

### `ShapeClassifierResolver`

Handles:

* edge-valid
* blunt-valid
* grip-safe profiles
* decorative / guard / plate distinctions

### `JointResolver`

Handles:

* articulated chain legality
* joint type
* degrees of freedom
* membrane legality
* self-collision mode

### `ProfileResolver`

Consumes all of the above later.

That separation matches your existing architecture law that resolvers should convert one layer into another without collapsing everything into one mega-object. 

---

# Agent-ready rule block

```text id="jlwm49"
JOINT / ARTICULATION RULES FOR V0.1-V0.2

This is a separate physical-item system from AnchorResolver.

A. Purpose
These rules define articulated physical segments:
- chain-like sections
- hinge sections
- spin joints
- membrane-bridged joints

B. Minimum articulated segment geometry
Let:
- A, B = cross-plane dimensions
- C = chain-axis dimension

A valid articulated segment must satisfy:
- A >= 2
- B >= 2
- C >= 4
- C must be even

Interpretation:
- each 2 voxels along the chain axis forms one rigid link unit
- link_count = C / 2
- hinge_count = link_count - 1

Examples:
- 2x2x4 = valid minimum articulated segment
- 2x2x6 = valid
- 2x2x8 = valid

C. BaseMaterialDef support fields
Required:
- can_be_joint_support
- can_be_joint_membrane
- can_be_axial_spin_joint
- can_be_planar_hinge_joint

Optional future biases:
- joint_stiffness_bias
- joint_damping_bias
- joint_recovery_bias
- joint_flex_bias
- joint_twist_bias

D. Material support ratio
Let:
- joint_support_material_ratio = joint-support cells / total cells in articulated span

For v0.1-v0.2:
- joint_support_material_ratio >= 0.80

E. Joint type from cross-plane symmetry

1. Square cross-plane:
If A == B and A >= 2:
Allowed modes:
- axial_spin
- planar_a
- planar_b

Meaning:
- free rotation around chain axis
- or planar hinge around one cross-plane axis
- or planar hinge around the other cross-plane axis

2. Rectangular cross-plane:
If A != B and A >= 2 and B >= 2:
Allowed mode:
- planar_forced

Rule:
- hinge axis = longer cross-plane dimension
- motion plane = chain axis + shorter cross-plane dimension
- angle limits = -90 degrees to +90 degrees
- no full axial spin

F. Joint validity formula
valid_joint_chain =
    connected_to_root
    AND A >= 2
    AND B >= 2
    AND C >= 4
    AND (C % 2) == 0
    AND joint_support_material_ratio >= 0.80

G. Membrane rule
A membrane is a runtime connector/bridge between rigid link units.
It preserves silhouette/continuity but is not treated as:
- grip
- cutting edge
- blunt striking body

First implementation:
- membrane is runtime visual/behavior bridge
- not authored as independent rigid segment truth

H. Self-collision rule
Ignore self-collision for:
- the immediate joint-linked pair of rigid units
- the membrane bridge between them

Enable self-collision for:
- all other non-adjacent articulated units
- all rigid sections outside the immediate joint neighborhood
- world collision as normal

I. Outputs
JointResolver should output:
- joint_chain_valid
- joint_type
- joint_axis
- motion_plane
- link_count
- hinge_count
- angle_limit_min
- angle_limit_max
- supports_axial_spin
- supports_planar_hinge
- self_collision_mode
- validation_error

J. Classification precedence
A span classified as articulated joint chain is not simultaneously:
- primary grip
- cutting edge
- blunt striking head

Unless it is split into distinct adjacent sub-segments.

K. Local frame rule
All axis rules are local to the segment frame, not absolute world axes.
```

---

## What this touches next

When you are ready, this system will require updates to:

* `BaseMaterialDef`
* `SegmentAtom`
* `JointResolver`
* later `CapabilityResolver`
* later `BakedProfile`

But for now this is enough to make the **resolver happy** and the design coherent.

After this, we can do **System 3: bow / ranged specialization** and then move on to the rest.
