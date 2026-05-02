# Skill Crafter TODO 2026-04-21

## Purpose

This file preserves the current skill crafter / combat animation station design scope so the idea is not lost while the editor is still unstable.

The immediate priority is not feature creep.
The immediate priority is to get the editor to a stable, correct, responsive baseline first.

This document exists so later implementation can be slotted in cleanly without forgetting the intended direction.

Primary companion reference:

- `GDD-and Text Resources/Combat System Canonical Truth 2026-04-21.md`
- `GDD-and Text Resources/ToDo stuff/Skill Crafter Implementation Stages 2026-04-24.md`

If wording here and the canonical truth document conflict, treat the canonical truth document as the newer wording anchor.

## Current Truth In Code

- The skill crafter currently opens in a weapon-selection workflow.
- Opening a weapon currently applies a baseline hand setup:
  dominant slot plus default one-handed or two-handed preview mode.
- That weapon-open hand setup is currently also used to seed fresh drafts from weapon geometry.
- Skill selection happens after weapon selection.
- The main editable unit is the motion node.
- A motion node already stores:
  trajectory plane orientation,
  trajectory plane vertical offset,
  weapon orientation,
  tip position,
  pommel position,
  weapon roll,
  axial reposition offset,
  grip-seat slide offset,
  body-support blend,
  grip style,
  two-hand state.
- The preview already supports per-motion-node `two_hand_state`.
- Current `two_hand_state` is only a foothold, not the full future stance/grip system.

## Core Design Law Going Forward

- The weapon-open configuration is an authoring baseline only.
- The weapon-open configuration must not become the final stance law for the skill.
- The real authored stance/grip logic must live at the motion-node level.
- Runtime legality filtering must be separate from editor authoring.
- The saved authored chain must remain truth.
- Runtime may build an effective playable chain from authored truth, but it must not silently rewrite the authoring data.

## Immediate Stabilization Work Before Adding More Scope

- Correct the skill crafter editor so it behaves as a stable functional tool before more systems are attached to it.
- Make sure tip and pommel are resolved from weapon geometry truth and not left in a bad default-zero or wrong-anchor state.
- Ensure the body plane, tip, pommel, weapon rotation, grip-seat slide, and axial reposition each control only their intended responsibility.
- Remove conflicting control hierarchies where multiple systems fight the same transform result.
- Make drag/edit interaction smooth and responsive.
- Avoid heavy recomputation and disk writes during active drag.
- Save on deliberate commit points such as:
  `R`,
  `T`,
  exit,
  or other explicit node-structure changes.
- Keep live motion editing in-memory while authoring a node.
- Ensure preview updates visually during drag without forcing unnecessary persistence work.
- Ensure the authored skill editor can meaningfully influence the body pose and is not blocked by rigid outside animation state.
- Reach a stable editor baseline before adding stance transitions, dual wield combo pages, or other large new layers.

## Motion Node Stance / Grip Scope To Add Later

- Add stance/grip state as a deliberate motion-node concept, not only as a weapon-open default.
- Expand beyond current `two_hand_state` once the editor is stable.
- Support per-motion-node stance intent such as:
  one-handed,
  two-handed,
  reverse grip,
  and other stance families when needed.
- Allow the authoring workflow to change stance within a skill chain.
- Allow later motion nodes to differ from earlier ones inside the same authored skill.
- Treat stance changes as a real authored artistic factor, not as an external hard-coded override.

## Transition Layer For Stance Changes

- When stance changes between motion nodes, do not snap if a blended transition is more correct.
- Use tweened or blended transitions for:
  one-hand to two-hand,
  two-hand to one-hand,
  normal grip to reverse grip,
  and similar state swaps.
- These transitions should be usable as part of authored combat expression, not only as hidden runtime correction.
- Do not implement this before the editor baseline is stable enough to trust the authored data.

## Runtime Equipment-State Filtering

- Runtime must later evaluate equipment legality without destroying the authored chain.
- The legality check should happen on equipment-state change, not every frame.
- Example trigger:
  equip,
  unequip,
  slot state changed,
  or equivalent equipment refresh events.
- If the runtime setup cannot support a motion node, that motion node should be skipped or bridged chronologically instead of mutating the saved draft.
- The runtime-effective chain should be compiled from the authored chain.
- A skill should not be thrown away just because one node becomes illegal for the current equipment state.
- If only part of a skill is illegal, only that part should be filtered out or bridged.

## Two-Hand Node Filtering Rule

- If more than one weapon is equipped, two-handed-only motion nodes should become unavailable for runtime use.
- That should not necessarily mute the entire skill.
- The runtime should attempt to preserve the legal parts of the authored chain.
- The authoring data should remain untouched.
- This will allow a skill to still function in a degraded but deterministic way when used in a different equipment setup than the one it was authored for.

## Equipment Matrix Direction For Later

- If needed, formalize legality through a matrix or rule grid.
- One axis can be weapon class:
  melee,
  shield,
  magic,
  ranged physical.
- One axis can be equipment condition:
  single weapon available,
  more than one weapon equipped,
  or similar runtime state.
- The output of the matrix should decide what node states or authored motion conditions are legal.
- Keep this as a later structured extension once the baseline behavior is correct.

## Dual Wield Future Scope

- Later add dual-wield combined authoring pages.
- A dual-wield page should allow selecting a main-hand and off-hand weapon combination as a pair.
- Those paired pages should author skills intended for both weapons together.
- This should be additive to the existing single-weapon skill pages, not a replacement.
- A single weapon should still keep its own independent skill page.
- If a paired weapon is missing, the single weapon should still be usable by itself.

## Weapon Selection / Open Workflow Direction

- Keep current open-with workflow as a useful baseline loader.
- Double click can continue to load the default intended hand setup for the weapon class.
- Context open-with can continue to expose explicit hand setup choices.
- This baseline load is still useful because it reduces manual setup effort at node zero.
- However, this baseline load must remain separate from the later per-motion-node stance system.

## Current Default Open Baseline Intent

- Melee default:
  right-hand primary,
  one-handed baseline.
- Shield default:
  left-hand primary.
- Ranged physical default:
  left-hand primary.
- Magic default:
  right-hand primary,
  two-handed baseline.

These are baseline loading rules, not final authored-skill restrictions.

## Unarmed And Ranged Special Cases

- Unarmed combat may later use similar legality/filtering principles, but it is out of scope for the current implementation phase.
- Ranged physical will likely need special handling because of the bow/quiver or similar multi-part logic.
- Do not let these special cases distort the current stabilization work.
- Leave extension points where sensible, but do not branch implementation around them yet.

## Stable Baseline Needed Before Feature Growth

Before adding the future systems above, the skill crafter must first reach a baseline where:

- the editor is readable,
- the controls are understandable,
- the transforms do not fight each other,
- the weapon points are derived correctly,
- the preview behaves deterministically,
- the editor is responsive during interaction,
- the save behavior is deliberate and not noisy,
- the existing motion-node workflow can be trusted.

## Recommended Implementation Order

1. Stabilize the current editor behavior and control hierarchy.
2. Correct weapon-derived point truth for tip, pommel, and related authored controls.
3. Cleanly separate baseline open config from per-motion-node authored state.
4. Expand motion-node stance/grip state beyond the current foothold when the editor is stable.
5. Add runtime equipment-state legality filtering that compiles an effective playable chain from authored truth.
6. Add tweened stance/grip transitions.
7. Add dual-wield combined authoring pages later as an additive layer.

## Guardrails

- Do not patch more features on top of an unstable editor foundation.
- Do not let runtime legality logic silently overwrite authored data.
- Do not mix baseline weapon-open setup with final authored stance law.
- Do not let future weapon-class special cases derail the current stabilization pass.
- Build with extension points in mind so later stance systems can slot in without rewriting everything again.

## Working Principle

The editor must first become stable, trustworthy, and responsive.
After that, the future stance-aware and equipment-aware systems can be added as clean layers on top instead of as emergency corrections.
