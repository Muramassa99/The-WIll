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
- [ ] Export the required full-hand measurements, joint mappings, motion planes,
  skin/contact representation and movement rules. Derive dimensions from the
  finalized character; preserve explicitly authored movement rules as such.
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

## Starting points

- [Character hand preparation tool and current limitations](<../../The Will- main folder/the-will-gamefiles/tools/grip_plane_proof/CHARACTER_HAND_PREPARATION.md>)
- [Middle and Thumb proof, findings and remaining contact work](<Two Digit Grip Plane Proof 2026-09-15.md>)

The existing standalone exporter currently prepares Middle and Thumb on both
hands and persists reusable character-linked measurements. Full-hand coverage,
validated contact envelopes, character creation/save integration and live grip
consumption remain future work. This TODO records that work for later selection.
