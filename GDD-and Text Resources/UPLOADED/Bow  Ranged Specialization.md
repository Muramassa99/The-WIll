Yes. Here is **System 3: Bow / Ranged Specialization** as the next resolver-ready rule pack.

Update note:
- this document still contains useful resolver-side bow rules
- but it predates the newer umbrella/component split
- for current system-level terminology and crafting foundation, also read [RANGED_PHYSICAL_WEAPON_AND_SHIELD_FOUNDATION_SPEC_2026-04-02.md](/C:/WORKSPACE/GDD-and%20Text%20Resources/UPLOADED/RANGED_PHYSICAL_WEAPON_AND_SHIELD_FOUNDATION_SPEC_2026-04-02.md)
- current naming law is:
  - `Ranged Physical Weapon` = umbrella
  - `bow` + `quiver` = separate components under that umbrella
  - `shield` mannequin-anchor overlap must be considered in parallel where the shared restriction logic applies
  - explicit bow string-anchor creator points are the preferred authored truth for string endpoints, with the visible string generated in post instead of hand-built as free voxel string geometry
  - runtime bow-string behavior should use a hand-connected four-point mapping so the string can be pulled, released, and returned consistently across long-bow, short-bow, and slingshot-like endpoint spacing

This stays compatible with the current project laws:

* first slice is still forge materials → cells → profiles → test prints 
* gameplay reads `BakedProfile`, not raw cells 
* visible classes are not the truth; capability/backend resolution is 
* ranged is a forge context / intent layer above universal material truth 

---

# 3. BOW / RANGED SPECIALIZATION RULES

## Design purpose

This system defines **ranged weapon specialization** inside the ranged crafting context.

It is **not** a replacement for:

* handle / anchor rules
* edge / blunt rules
* articulation rules

It **builds on top of them**.

So:

* a bow still needs a legal grip
* a bow body can still be blunt/edge capable
* a bow string is a special ranged-only exception
* projectile behavior comes from a dedicated ranged layer

---

## A. Context gate

Bow rules activate only if:

```text id="4y9hiv"
equipment_context == ctx_weapon
AND forge_intent == intent_ranged
```

Inside this context:

* bow-specific rules are legal
* 1x1 string exception is legal
* projectile lane rules are legal
* bow limb flex rules are legal

Outside this context:

* a 1x1 line does not become a bowstring automatically

This matches the project rule that crafting context/tabs are workflow aids above material truth, not visible combat classes.

---

## B. Bow segment classes

Within ranged context, classify these segment types:

```text id="hci9if"
grip_segment
riser_segment
upper_limb_segment
lower_limb_segment
bow_string_segment
projectile_pass_segment
decorative_segment
```

### Meaning

* `grip_segment` = valid primary hand anchor region
* `riser_segment` = rigid center body of the bow
* `upper_limb_segment` = upper flexing limb
* `lower_limb_segment` = lower flexing limb
* `bow_string_segment` = ranged-only 1x1 tension path
* `projectile_pass_segment` = launch lane / arrow pass region
* `decorative_segment` = visual only

---

## C. BaseMaterialDef support fields

Add these material-truth hooks:

```text id="g6w1h0"
can_be_bow_limb
can_be_bow_string
can_be_riser_core
can_be_projectile_support
can_be_bow_grip
```

Optional future biases:

```text id="4o0knj"
limb_flex_bias
limb_recovery_bias
string_tension_bias
string_elasticity_bias
projectile_stability_bias
draw_stability_bias
```

These are material contributions only, not final bow behavior.

---

## D. Grip rule

A bow still requires one valid primary grip using the normal grip rules already locked.

So ranged context does **not** bypass handle legality.

That means:

* valid grip length/cross-section rules still apply
* anchor-material ratio still applies
* start/end anchor-material rule still applies
* edge overlap rule still applies

The bow system sits on top of that, not instead of it.

---

## E. Bowstring special rule

This is the intentional ranged-only exception.

A `bow_string_segment` may be a **continuous 1x1 path** if:

```text id="3g3ux9"
forge_intent == intent_ranged
AND string_path_continuous == true
AND string_cross_section == 1x1
AND all string cells use material.can_be_bow_string == true
AND string connects upper_string_anchor to lower_string_anchor
```

Important:
A bow string is **not** treated as:

* general joint chain
* grip
* cutting edge
* blunt striking body

It is a specialized **tension line**.

This is the clean way to let string stay “string” in ranged context while keeping the general articulation system stricter.

---

## F. Bow limb rule

A bow limb is not allowed to be 1x1.

For v0.1 / v0.2:

```text id="aj4pnn"
valid_limb_segment =
    material.can_be_bow_limb == true
    AND limb_cross_section >= 2x2
    AND limb_length >= 4
```

So:

* limbs/body are structural
* string is the only 1x1 special-case path

---

## G. Bow reference center / projectile pass point

Ranged context defines a central reference point:

```text id="r3teqk"
bow_reference_center
projectile_pass_point
```

For v0.1:

* they may be the same point

This point acts as:

* the center for upper/lower limb determination
* the launch lane reference
* the draw/release alignment reference

This is the simplifier that makes weird bows still resolvable.

---

## H. Asymmetry rule

Asymmetric bows are allowed.

Let:

* `UL_length`
* `LL_length`
* `UL_flex_score`
* `LL_flex_score`

Then:

```text id="fp4rf0"
bow_asymmetry_score = abs(UL_flex_score - LL_flex_score)
```

Asymmetry does **not** invalidate the bow by default.
It changes:

* stability
* draw feel
* projectile consistency
* later maybe recoil / recovery feel

So:

* normal bows work
* asymmetric bows work
* exotic fantasy bows still stay inside one system

---

## I. String behavior rule

Meet-in-the-middle implementation:

The bowstring should be:

* visually elastic if desired
* mechanically treated as a **constrained tension line**

So for v0.1 / v0.2:

* string has a rest path
* string has a draw point
* draw point moves only along a defined draw axis
* visual interpolation/flex is allowed
* free floppy rope physics is **not** required

That gives you bow feel without chaos.

---

## J. Draw / release axis

Ranged context defines a local frame:

```text id="0ckjo2"
shoot_axis
draw_axis
up_axis
```

For v0.1:

* `draw_axis` is opposite `shoot_axis`
* arrow travels through `projectile_pass_point` along `shoot_axis`
* pullback occurs only along `draw_axis`

This keeps character animation and projectile logic much simpler.

---

## K. Bow validity formula

```text id="qtat7o"
valid_bow =
    valid_primary_grip
    AND valid_riser_segment
    AND valid_upper_limb_segment
    AND valid_lower_limb_segment
    AND valid_bow_string
    AND valid_projectile_pass_point
```

### `valid_bow_string`

```text id="8pk52y"
valid_bow_string =
    forge_intent == intent_ranged
    AND string_path_continuous
    AND string_cross_section == 1x1
    AND all string cells use can_be_bow_string
    AND string connects upper_string_anchor to lower_string_anchor
```

### `valid_limb_segment`

```text id="4v81ct"
valid_limb_segment =
    material.can_be_bow_limb
    AND limb_cross_section >= 2x2
    AND limb_length >= 4
```

---

## L. BowResolver outputs

`BowResolver` should output:

```text id="k9vv2k"
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

### `validation_error` examples

* `no_valid_primary_grip`
* `no_valid_riser`
* `missing_upper_limb`
* `missing_lower_limb`
* `invalid_bow_string`
* `invalid_string_material`
* `invalid_string_path`
* `missing_projectile_pass_point`

---

## M. Hybrid melee use on bows

A ranged weapon can still reuse physical item truth.

So:

* if the bow body has edge-valid spans, it can support slash/cut behavior later
* if the bow body has blunt-valid spans, it can support bash behavior later
* the string remains non-striking by default

That means:

* blade bow
* bash bow
* hybrid bow
  are all legal if the rigid body qualifies

This stays consistent with your capability-first, not class-first, philosophy. 

---

# Agent-ready rule block

```text id="8f3vjr"
RANGED / BOW RULES FOR V0.1-V0.2

A. Context gate
Bow rules activate only if:
- equipment_context == ctx_weapon
- forge_intent == intent_ranged

Outside ranged context, 1x1 string paths are not treated as bowstrings.

B. Bow segment classes
Classify these segment types in ranged builds:
- grip_segment
- riser_segment
- upper_limb_segment
- lower_limb_segment
- bow_string_segment
- projectile_pass_segment
- decorative_segment

C. Required BaseMaterialDef support fields
- can_be_bow_limb
- can_be_bow_string
- can_be_riser_core
- can_be_projectile_support
- can_be_bow_grip

Optional future biases:
- limb_flex_bias
- limb_recovery_bias
- string_tension_bias
- string_elasticity_bias
- projectile_stability_bias
- draw_stability_bias

D. Grip rule
A valid bow still requires one valid primary grip using the already-locked grip rules.
Ranged context does not bypass grip legality.

E. Bowstring rule
A bow_string_segment is legal only if:
- forge_intent == intent_ranged
- string path is continuous
- string cross-section is exactly 1x1
- all string cells use material.can_be_bow_string == true
- string path connects upper and lower string anchors

A bow string is not treated as:
- general joint chain
- grip
- cutting edge
- blunt striking body

F. Limb rule
Each limb segment must satisfy:
- material.can_be_bow_limb == true
- limb cross-section >= 2x2
- limb length >= 4

String is the only 1x1 special-case path.

G. Projectile pass point
Ranged context defines:
- bow_reference_center
- projectile_pass_point

For v0.1, they may be the same point.
This point acts as the launch lane reference and central bow alignment point.

H. Asymmetry
Upper and lower limbs may differ in size or shape.
Each limb must validate independently.
Asymmetry is allowed and produces:
- bow_asymmetry_score
- stability changes
- draw feel differences

I. String behavior
Use constrained tension-line behavior, not floppy rope physics.
For v0.1-v0.2:
- string has a rest path
- string has a draw point
- draw point moves only along draw_axis
- visual elasticity is allowed
- free rope simulation is not required

J. Draw and release axes
Ranged context defines a local frame:
- shoot_axis
- draw_axis
- up_axis

For v0.1:
- draw_axis is opposite shoot_axis
- arrow travels through projectile_pass_point along shoot_axis
- pullback occurs only along draw_axis

K. Bow validity formula
valid_bow =
    valid_primary_grip
    AND valid_riser_segment
    AND valid_upper_limb_segment
    AND valid_lower_limb_segment
    AND valid_bow_string
    AND valid_projectile_pass_point

L. Resolver outputs
BowResolver should output:
- bow_valid
- bow_reference_center
- projectile_pass_point
- shoot_axis
- draw_axis
- upper_string_anchor
- lower_string_anchor
- string_rest_path
- string_draw_path
- upper_limb_valid
- lower_limb_valid
- upper_limb_flex_score
- lower_limb_flex_score
- string_tension_score
- bow_asymmetry_score
- validation_error

M. Hybrid use
Rigid bow body may still reuse melee shape truth:
- edge-valid body spans may support cut/slash behavior
- blunt-valid body spans may support bash behavior
- bow string remains non-striking by default
```

---

## Recommended implementation order after this

1. edge / blunt / handle rules
2. joint / articulation rules
3. bow / ranged specialization
4. profile math that consumes those outputs
5. magic overlays later

That keeps the physical truth stack clean.

If you want, next I’ll turn this into the **smallest implementation checklist per file**:

* `base_material_def.gd`
* `segment_atom.gd`
* `bow_resolver.gd`
* and any new fields needed in `baked_profile.gd`.
