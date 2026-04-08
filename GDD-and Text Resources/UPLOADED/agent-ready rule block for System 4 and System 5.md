Yes. Here is the **agent-ready rule block for System 4 and System 5**:

* **System 4 = Profile Math**
* **System 5 = Capability Resolution**

This stays aligned with the active first-slice law set:

* first slice is still **forge materials → cells → profiles → test prints** 
* **mass and center of mass are density-weighted**
* **baking lives in `ProfileResolver + ForgeService`** and gameplay reads `BakedProfile`, not raw cells
* the first slice uses the approved **8 core capabilities**: `cap_edge`, `cap_blunt`, `cap_pierce`, `cap_guard`, `cap_flex`, `cap_launch`, `cap_stability`, `cap_reach` 

---

```text
PROFILE MATH / CAPABILITY RESOLUTION RULES FOR V0.1-V0.2

SYSTEM 4 — PROFILE MATH

A. Purpose
ProfileResolver converts authored forge data into gameplay-facing physical truth.
It consumes:
- CellAtom[]
- SegmentAtom[]
- AnchorAtom[]
- material lookup data
- optional shape/joint/bow outputs

It produces:
- one BakedProfile

B. Locked first-slice laws it must obey
- gameplay reads BakedProfile, not raw cells
- mass is density-weighted
- center of mass is density-weighted
- layers are workflow/edit structure, not direct physics multipliers
- primary grip validity comes from AnchorResolver
- shape/joint/bow classification is input, not invented here

C. Public entry point
bake_profile(
    cells,
    segments,
    anchors,
    material_lookup,
    shape_data = {},
    joint_data = {},
    bow_data = {}
) -> BakedProfile

D. Required geometry outputs in BakedProfile
ProfileResolver must fill these first-pass real fields:
- total_mass
- center_of_mass
- reach
- primary_grip_offset
- front_heavy_score
- balance_score
- edge_score
- blunt_score
- pierce_score
- guard_score
- flex_score
- launch_score
- primary_grip_valid
- validation_error

E. Locked formulas / first-pass math

1. Cell mass
cell_mass = material.density_per_cell

2. Total mass
total_mass = Σ(cell_mass)

3. Center of mass
center_of_mass = Σ(cell_position * cell_mass) / total_mass

4. Reach
For v0.1:
reach = max distance from primary_grip_position to any occupied cell center

5. Primary grip offset
primary_grip_offset = center_of_mass - primary_grip_position

6. Front-heavy score
front_heavy_score =
    clamp(dot(primary_grip_offset, forward_axis) / max(reach, epsilon), -1.0, 1.0)

7. Balance score
balance_score =
    1.0 - clamp(length(primary_grip_offset) / max(reach, epsilon), 0.0, 1.0)

F. Shape-flavor score sources
These are first-pass normalized floats (0.0 to 1.0), not final combat formulas.

1. edge_score
Use:
- edge-valid spans from shape classification
- edge-capable material support
- thin beveled blade presence

2. blunt_score
Use:
- blunt-valid spans
- blunt-capable material support
- thick non-edge striking mass

3. pierce_score
Use:
- narrow/pointed forward geometry hints
- pierce-capable material support
- reach contribution if useful

4. guard_score
Use:
- plate/guard-capable spans
- guard-support material support

5. flex_score
Use:
- articulated segments
- bow limb/string outputs
- flex-capable material support

6. launch_score
Use:
- bow validity
- projectile lane support
- launch-capable material support

G. ProfileResolver is allowed to know
- baked physical inputs
- material truth lookups
- anchor results
- shape/joint/bow outputs

H. ProfileResolver must NOT know
- UI
- scenes
- save format
- animation playback
- skill templates
- combat execution
- controller logic

I. TODO / NEEDS_DECISION still allowed here
These may stay unresolved for now:
- exact reach normalization beyond first-pass max-distance
- exact shape weighting for edge/blunt/pierce
- exact guard/flex/launch blend weights
- final forward_axis definition if grip/orientation rules evolve


SYSTEM 5 — CAPABILITY RESOLUTION

A. Purpose
CapabilityResolver translates BakedProfile into gameplay-facing capability scores.
It does not create skills.
It does not create classes.
It only answers: what is this crafted thing actually good at?

B. Approved first-slice capability outputs
Populate exactly these first:
- cap_edge
- cap_blunt
- cap_pierce
- cap_guard
- cap_flex
- cap_launch
- cap_stability
- cap_reach

C. Public entry point
derive_capability_scores(
    profile: BakedProfile,
    material_bias_lines = [],
    context_bias_lines = []
) -> Dictionary

D. First-pass formula style
Use normalized, debug-friendly floats in the range 0.0 to 1.0.
Do not invent full family/skill unlock thresholds yet.

E. Recommended first-pass capability formulas

1. cap_edge
cap_edge = clamp(edge_score + edge_bias_total, 0.0, 1.0)

2. cap_blunt
cap_blunt = clamp(blunt_score + blunt_bias_total, 0.0, 1.0)

3. cap_pierce
cap_pierce = clamp(pierce_score + pierce_bias_total + optional_reach_bonus, 0.0, 1.0)

4. cap_guard
cap_guard = clamp(guard_score + guard_bias_total, 0.0, 1.0)

5. cap_flex
cap_flex = clamp(flex_score + flex_bias_total, 0.0, 1.0)

6. cap_launch
cap_launch = clamp(launch_score + launch_bias_total, 0.0, 1.0)

7. cap_stability
cap_stability = clamp(balance_score + stability_bias_total, 0.0, 1.0)

8. cap_reach
cap_reach = clamp(normalized_reach_value, 0.0, 1.0)

F. Bias source rules
CapabilityResolver may consume:
- material-side capability biases
- later equipment/context biases if explicitly passed in

It must NOT consume:
- raw cells
- scenes
- animation
- save logic
- combat state

G. CapabilityResolver is allowed to know
- BakedProfile
- aggregated material bias totals
- optional context bias totals

H. CapabilityResolver must NOT know
- CellAtom arrays
- forge controller state
- skill templates
- UI presentation
- combat execution
- networking

I. Output contract
Return a dictionary keyed by the approved capability IDs:
- cap_edge
- cap_blunt
- cap_pierce
- cap_guard
- cap_flex
- cap_launch
- cap_stability
- cap_reach

J. TODO / NEEDS_DECISION still allowed here
These may remain open for now:
- exact threshold mapping from 0.0-1.0 to 0/1/2/3/4 display tiers
- exact weighting for optional_reach_bonus on cap_pierce
- exact stability penalty from articulation chaos
- later expansion to cap_magic / cap_heal / cap_projectile / cap_anchor etc.

K. Implementation discipline
- keep ProfileResolver and CapabilityResolver pure
- keep formulas traceable and easy to print/debug
- do not broaden into skill-family resolution yet
- do not invent combat behavior
- do not move logic into controllers/services beyond orchestration
```

---

## Smallest file checklist

### `core/resolvers/profile_resolver.gd`

Add/keep:

* `bake_profile(...) -> BakedProfile`
* private helpers for:

  * total mass
  * center of mass
  * reach
  * primary grip offset
  * front-heavy score
  * balance score
  * edge/blunt/pierce/guard/flex/launch scores

### `core/models/baked_profile.gd`

Make sure it has at least:

* 12 geometry fields:

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
* 8 capability fields or one capability dictionary:

  * `cap_edge`
  * `cap_blunt`
  * `cap_pierce`
  * `cap_guard`
  * `cap_flex`
  * `cap_launch`
  * `cap_stability`
  * `cap_reach`
* validation fields:

  * `primary_grip_valid`
  * `validation_error` 

### `core/resolvers/capability_resolver.gd`

Add/keep:

* `derive_capability_scores(profile, material_bias_lines, context_bias_lines) -> Dictionary`
* private helpers for the 8 approved first-pass capabilities only

---

## Recommended implementation order

1. finish `AnchorResolver` primary-grip legality
2. make sure shape outputs for edge/blunt/grip-safe exist
3. implement `ProfileResolver` with the locked density-weighted math
4. implement `CapabilityResolver` for the approved 8 capabilities only
5. leave skill families / templates / combat behavior for later 

