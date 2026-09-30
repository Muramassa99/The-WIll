# Character creation/save: prepare reusable full-hand anatomy

Date: 2026-09-15
Status: TODO - future integration requested by the user; not implemented.

## Intended outcome

Make character hand preparation a process step during character creation/save,
after the character's final model, skeleton, proportions, scale and morphs are
established. Run the expensive measurement/preparation once for that character
configuration, export the results, and persist their association with the saved
character. Grip consumers then use the already prepared data.

Expand the current Middle-and-Thumb proof to **both complete hands: all ten
digits plus palm contact data**, including shared tissue at digit/palm junctions.
Keep the preparation modular so different character models and hand shapes
provide their own measured dimensions instead of inheriting Josie-sized values.

## Work to complete

- [ ] Validate the current Middle/Thumb contact representation against actual
  skinned geometry before extending it to all digits and palms.
- [ ] Once the current envelope/hand match produces a satisfactory result,
  upgrade Index, Ring and Pinky on both hands to the same prepared anatomy,
  posed skin observation, motion-rule and solver level as Middle/Thumb
  (September 27 user direction). Plan the production cutover separately:
  replace superseded contact-solving responsibilities, retain what the new
  system does not cover, and remove competing pose writers. Preserve open/
  unarmed hand behavior and authored placement/Roll/IK ownership. The first
  envelope hand-match attempt is incomplete and does not meet that condition.
- [ ] Export the required full-hand measurements, joint mappings, motion planes,
  skin/contact representation and movement rules. Derive dimensions from the
  finalized character; preserve explicitly authored movement rules as such.
- [ ] Measure all ten fingertip contact curves and retain each digit's result,
  fit quality and source geometry. Derive minimum, maximum and an average radius
  for the character-owned contact-wrapper target (September 26 user direction).
  Define the cap-selection and averaging policy explicitly before production
  baking; do not confuse the mean of digit radii with the midpoint of extremes.
  Missing digits or poor fits must remain visible rather than silently producing
  a supposedly complete character average.
- [ ] Save that chosen radius with the prepared hand data and its model/metric/
  preparation revision. Consumers reuse it; repeat measurement only when those
  inputs change. A larger radius permits less inward curvature, so the field
  represents a minimum inward radius, equivalently a maximum curvature.
- [ ] Integrate preparation and its exported resource reference into character
  creation/save. The saved character must identify the matching prepared data.
- [ ] Reuse valid output when saving an unchanged character. Invalidate and
  regenerate it when relevant model, skeleton, proportion, scale, morph or
  preparation-rule changes make it stale; never silently use mismatched anatomy.
- [ ] Load/validate the matching resource during character setup and retain it
  for grip consumers, avoiding repeated character measurements during grip use.
- [ ] Preserve the project's named coordinate chains back to `RL_BoneRoot` for
  every exported position, plane and transform.
- [ ] Verify save/reload association, full-hand geometry/contact accuracy and
  changed-character invalidation. Measure preparation/setup costs separately
  from weapon-specific grip solving and complete grip-acquisition duration.

The exported anatomy does not pre-solve arbitrary weapons. Weapon geometry,
selected grip placement and contact still require their own solve using that
prepared character data. Existing full-grip correctness and performance goals
remain part of the integration.

September 26 follow-on direction: Forge V2 should export a prepared handle
contact wrapper so Skill Crafter can consume it without rebuilding during
manipulation. Its identity must include the geometry and the character-derived
radius used to construct it. Baking a complete 3D wrapper versus caching
orientation-specific 2D sections remains an explicit integration decision:
closing a perpendicular profile and then slicing it obliquely is not generally
the same operation as closing that oblique slice. This does not authorize
substituting a generic collision hull or changing the visible weapon geometry.

The September 26 envelope proof uses an approximate Right Middle radius from
the saved prepared-zero pose. It is not the ten-digit average or a new completed
character resource. See [the active consolidation guide](<Grip Overhaul Consolidation 2026-09-18.md>).

Later September 26 measurement correction: use the broad rounded S3 side shown
in the user's annotation, not the small terminal end cap. The Right Middle proof
now uses a 22.099337 mm side-arc fit. Define that contact-region extraction for
each digit explicitly before aggregating the full character measurements; the
current diagnostic's positive-side contour selection is not a universal palm
or dorsal label.

September 27 tuning: the user selected **2.3 times** that measured side radius
for the working contact envelope: 22.099336934 mm measured, 50.828474948 mm
effective minimum inward radius. Persist the measurement and multiplier as
separate values with their revisions; do not bake the multiplier into the skin
dimensions or call the effective radius a new anatomical measurement. This is
still the current diagnostic tuning, not a completed ten-digit character bake.

## Starting points

- [Character hand preparation tool and current limitations](<../../The Will- main folder/the-will-gamefiles/tools/grip_plane_proof/CHARACTER_HAND_PREPARATION.md>)
- [Middle and Thumb proof, findings and remaining contact work](<Two Digit Grip Plane Proof 2026-09-15.md>)

The existing standalone exporter currently prepares Middle and Thumb on both
hands and persists reusable character-linked measurements. Full-hand coverage,
validated contact envelopes, character creation/save integration and live grip
consumption remain future work. This TODO records that work for later selection.
