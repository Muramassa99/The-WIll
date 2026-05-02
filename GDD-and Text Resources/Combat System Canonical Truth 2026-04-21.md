# Combat System Canonical Truth 2026-04-21

## Purpose

This document is the current implementation-prep truth for the combat system branch.

It exists because the earlier combat-system files captured the correct intent, but they were written while the terminology and hierarchy were still rough.

This file is the cleaner anchor to use before implementation work continues.

When wording in older concept files conflicts with this document, this document should be treated as the newer truth.

Relevant earlier concept files:

- `Runtime Weapon-Owned Melee Skill Crafter 1.md`
- `Runtime Weapon-Owned Melee Skill Crafter-2.md`
- `Runtime Melee Combat Editor Visual-System.md`
- `Runtime Combat Editor Visual and System Addendum.md`

This file does not erase those earlier documents.
It consolidates what we understand better now.

## Reading Law

This document separates three kinds of statements:

- `Current fact in code`
- `Settled target law`
- `Deferred / later scope`

That separation matters.
We do not want to confuse "already implemented" with "clearly intended but not finished yet."

## Core Idea

The combat system is not a generic animation editor.

It is a runtime, weapon-owned, slot-constrained motion authoring and playback pipeline.

In plain terms:

- the weapon owns the authored combat package
- the selected skill slot defines the legal/use-role box
- the editor authors the motion expression inside that box
- the body later plays that authored motion through a reusable playback layer

The body is the playback machine.
The skill is the motion program.
The weapon is the geometry and handling truth source that feeds the program.

## What The System Is

Settled target law:

- The skill crafter is a runtime combat authoring station.
- It is not a dense offline clip editor.
- It is not a freeform "move random bones until it looks good" tool.
- It is not the final source of combat truth by itself.

The skill crafter exists to author reusable motion data that can later be:

- previewed inside the editor
- shown in inspection / presentation views
- played by runtime combat

## Ownership Hierarchy

Settled target law:

1. Materials and weapon parts feed Stage 1 weapon truth.
2. Stage 1 produces the weapon's combat-driving geometry and handling data.
3. A weapon owns its skill drafts.
4. A selected skill slot chooses which skill draft is being edited or played.
5. A skill draft contains an ordered chain of authored motion nodes.
6. Runtime builds an effective playable chain from the authored truth when legality filters are needed.
7. The body playback layer reads that runtime-effective chain and performs it.

This means:

- the weapon is upstream of the skill
- the skill is upstream of playback
- playback is downstream of both weapon truth and authored node truth

## Stage 1 Truth Source

Settled target law:

Stage 1 is the main combat-driving truth source for the combat system.

That includes values such as:

- weapon class
- materials
- effects
- grip-valid span
- grip endcaps
- grip center calculations
- center of mass
- mass distribution
- handling identity
- derived overall weapon axis truth
- later proper tip and pommel derivation

Stage 2 refinement is not the main combat-driving truth source.

The combat system should not invent geometry truth locally if Stage 1 already knows it.

## Terminology Lock

Settled target law:

The older word `point` is too weak and too vague for the intended system.

Use `motion node` as the preferred term.

A motion node is not just a position.
It is a bundle of authored parameters that live at one authored step on the skill timeline.

Current fact in code:

The current implementation already moved in this direction and stores more than a bare point.

Settled target law:

Going forward, the system should be described in terms of:

- `motion node`
- `skill draft`
- `authoring baseline`
- `runtime-effective chain`
- `body playback layer`
- `Stage 1 truth`

## Motion Node Meaning

Settled target law:

A motion node is the authored unit of the skill crafter.

It is the container for the values that define one authored step of combat motion.

Current fact in code:

The current motion-node-shaped data already includes or is attempting to include values such as:

- trajectory plane orientation
- trajectory plane vertical offset
- weapon orientation
- tip position
- pommel position
- weapon roll
- axial reposition offset
- grip-seat slide offset
- body-support blend
- grip style
- two-hand state

Settled target law:

That is much closer to the intended system than the old idea of a bare point.

## Editor Workflow

Settled target law:

The runtime workflow is:

1. weapon selection
2. skill slot selection / skill selection
3. editor

The editor does not open without:

- a selected weapon
- a selected skill slot / skill

Current fact in code:

The skill crafter already follows a weapon-selection-first workflow and then moves into skill selection.

## Weapon-Open Baseline

Settled target law:

Opening a weapon in the skill crafter should load a useful authoring baseline.

This baseline is a convenience loader.
It is not the final stance law for the whole skill.

Current baseline intent:

- melee default: right-hand primary, one-handed baseline
- shield default: left-hand primary
- ranged physical default: left-hand primary
- magic default: right-hand primary, two-handed baseline

Settled target law:

Those are baseline open rules only.

The final authored stance and grip logic must live at the motion-node level, not be permanently inherited from the initial load state.

## Double Click And Open-With Workflow

Settled target law:

The skill crafter should support:

- double click to open a weapon with the default intended baseline for its class
- right click open-with style selection for explicit hand/grip baseline choices

The purpose is to reduce setup friction at node zero.

This baseline loader is useful, but it must remain separate from authored node truth.

## Motion Node Authoring Model

Settled target law:

The skill editor is based on authored motion nodes, not dense frame-by-frame bone authoring.

The motion node chain is the authored truth.
Interpolation, preview motion, and runtime playback are downstream of that authored truth.

This means:

- navigation moves between motion nodes
- add/delete operates on motion nodes
- save/restore preserves motion node data
- preview plays the authored chain

## Curve Layer Law

Settled target law:

Destination structure is the hard authored law.
Curve shaping is the freedom layer between those authored units.

In other words:

- motion nodes are the hard authored structure
- the path between them is the shaping layer

The visible trajectory is not cosmetic only.
It is a readable and eventually sampleable motion path.

That path should support:

- preview readability
- timing readability
- speed-state evaluation
- later VFX and SFX timing
- later hitbox timing support

## Body As Playback Machine

Settled target law:

The body should not be treated as a fixed keyframed wall that the editor fights directly forever.

The correct long-term model is:

- the body is the playback machine
- the skill is the authored motion program
- runtime feeds the body the proper playable motion package

This is the "body as cartridge reader / CNC machine / playback shell" idea expressed more cleanly.

The editor is not supposed to solve the entire final combat playback problem by brute force inside the editor scene.

## Playback Layer Law

Settled target law:

Preview, inspection, and combat should ride the same general playback highway.

That means the authored motion should be reusable in:

- the editor preview
- a presentation / inspection / trade viewer
- real combat runtime

Those can have different wrappers, but they should not be three unrelated playback systems.

## Layered Body Override Direction

Settled target law:

The correct direction is not "replace the entire existing animation system with total procedural chaos."

The correct direction is to introduce a proper layered playback / override path where authored combat motion can drive the relevant body regions without destroying the whole character rig.

Current understanding:

- upper body and combat-relevant chains need to be overridable
- fingers do not necessarily need to be driven by the same layer if the grip/finger system already provides the correct local contact behavior

Practical intent:

- keep what is already good
- override what must become combat-authorable
- avoid breaking the whole model just to move the weapon and arms

## Finger Scope

Settled target law:

Finger contact logic and upper-body playback logic are related, but they are not the same job.

The upper-body combat layer should not casually destroy working finger behavior.

If fingers already have a valid grip/contact logic path, it is acceptable for the broader combat authoring layer to leave that narrower responsibility to the dedicated grip/finger system.

## Weapon Geometry-Derived Controls

Settled target law:

Tip and pommel are not arbitrary local placeholders.

They must be derived from weapon geometry truth.

That derivation should be based on the Stage 1-established weapon truth, including:

- grip-valid span
- grip endcaps
- grip slice center calculations
- the resulting grip axis
- overall weapon extremity derivation relative to that axis

The skill crafter should consume those derived truths, not fake them from editor-local zero positions.

## Plane Separation Law

Settled target law:

The editor needs more than one plane-like control context.

At minimum:

- the body-linked trajectory plane must be distinct from
- the weapon-linked rotation / roll control plane

These responsibilities should not be collapsed into one control if doing so makes the hierarchy fight itself.

## Authoring Hierarchy

Settled target law:

For authoring intent, the motion relationship is:

1. body-linked plane provides the local motion-authoring context
2. tip moves in that plane context
3. pommel remains in a constant-distance relationship to the tip based on weapon length truth
4. grip-seat / hand position remains constrained by the legal grip span
5. body solve follows through the IK/playback system

This expresses the user's intended creative direction.

## Restriction Hierarchy

Settled target law:

For legality and restriction, the flow is read in the opposite direction:

1. body collision and body range-of-motion constraints
2. IK reach and legal attachment continuity
3. legal grip span / grip-seat sliding limits
4. fixed weapon-length relationship between pommel and tip
5. tangent / plane constraints on authored tip motion

The point is:

- authoring intent flows one way
- legality pushes back the other way

This is a two-way system, not a single-direction one.

## Grip Continuity Law

Settled target law:

The hand does not need to stay locked to one infinitesimal pin point.

It needs to stay in legal grip continuity across the valid grip span.

That means grip behavior should be modeled as:

- continuity across the legal grip area
- with sliding allowed inside that legal grip span
- with hard stops at grip endcaps

This is more correct than pretending the hand is always nailed to one impossible zero-width seat.

## Runtime Legality Filtering

Settled target law:

Runtime legality filtering must not silently rewrite the authored draft.

Instead:

- the authored chain remains truth
- runtime may compile an effective playable chain from that truth
- illegal nodes may be skipped or bridged when the current equipment state cannot support them

This is especially important for:

- two-handed nodes
- future dual wielding
- future stance filtering

## Equipment-State Filtering

Settled target law:

Equipment legality checks should happen on equipment-state change, not every frame.

Typical triggers:

- equip
- unequip
- hand-slot state changed
- similar loadout refresh events

The runtime-effective chain should be built from authored truth after those checks.

## Two-Hand Node Filtering

Settled target law:

If the runtime equipment state cannot support two-handed nodes, the system should attempt to preserve the legal parts of the skill instead of destroying the entire skill.

That means:

- authored data remains untouched
- runtime filters or bridges the illegal parts
- the result may be a degraded but deterministic valid chain

## Dual Wield And Pair Authorship

Deferred / later scope:

- later add dual-wield pair pages
- let a main-hand and off-hand weapon pair share authored skills intended for both together
- preserve single-weapon pages as their own independent authoring spaces

This is future scope.
It should not derail the current stabilization and core playback work.

## Unarmed And Ranged Special Cases

Deferred / later scope:

- unarmed will likely reuse similar legality/filtering ideas
- ranged physical will likely need separate handling because of its multi-part nature

These should remain extension points, not current distortion points.

## Skill Slot Law

Settled target law:

The selected skill slot already provides the legal role box.

The skill crafter authors the motion expression inside that slot law.

The editor is not deciding the whole gameplay role from scratch.

This is why the authored package needs to remain compatible with:

- slot identity
- runtime slot bindings
- later effects and usage conditions

## Skill Slot Naming Direction

Settled target law:

For the main combat bar, the slot naming direction should use:

- `skill_slot_1`
- `skill_slot_2`
- ...
- `skill_slot_12`

These slot identities should remain stable data anchors.

The visible button prompts may vary with user keybindings, but the slot identifiers themselves should remain clear and consistent in data.

## Save Law

Settled target law:

Editing should feel responsive.

Do not do noisy persistence work during live drag unless truly necessary.

Preferred save moments are deliberate structural or exit actions such as:

- add node
- delete node
- exit editor
- other explicit structural commit moments

Live editing should remain mostly in-memory until a deliberate commit/update point is reached.

## Stable Editor Baseline Requirement

Settled target law:

Before large scope growth, the editor must become:

- readable
- responsive
- deterministic
- transform-clean
- based on correct weapon-derived data

The current foundation should be stabilized before more feature weight is stacked onto it.

## Current Known Gaps

Current fact in code / current known problem area:

- the editor baseline exists but is still rough
- some transform responsibilities are still fighting each other
- body influence is not yet fully aligned with authored intent
- weapon orientation / basis alignment is not yet fully reliable
- proper derived tip/pommel truth still needs stronger implementation linkage
- the playback/body override path is not yet in its final intended layered shape

## Immediate Implementation Direction

Settled target law:

The next serious implementation work should follow this order:

1. stabilize the current editor behavior and control hierarchy
2. correct weapon-derived point truth for tip, pommel, axis, and related authored controls
3. cleanly separate baseline-open state from per-motion-node authored state
4. strengthen the reusable body playback / upper-body override path
5. make preview, inspection, and runtime share the same general playback architecture
6. only after the above, expand stance transitions, equipment filtering depth, and pair-authoring systems

## Working Principle

Settled target law:

The system should be built as a modular production line:

- components feed materials
- materials feed weapons
- weapons feed geometry and handling truth
- geometry and handling truth feed skill authoring
- skill authoring feeds playback
- playback feeds combat, hitboxes, VFX, SFX, and presentation

That is the intended assembly line.
The goal is not to hard-code one trick for one weapon.
The goal is to let the same shell read different authored packages and behave correctly.

## Final Summary

The earlier documents captured the right concept, but in rough form.

The cleaner truth now is:

- use `motion node` instead of vague `point`
- treat Stage 1 as the upstream geometry/combat truth source
- keep weapon ownership of skill drafts
- keep slot law as the legal role box
- build the editor as a runtime authoring station
- build the body as the reusable playback machine
- keep preview, inspection, and combat on the same general playback highway
- preserve authored truth and let runtime compile legality-aware playable chains from it

That is the working truth to implement from.
