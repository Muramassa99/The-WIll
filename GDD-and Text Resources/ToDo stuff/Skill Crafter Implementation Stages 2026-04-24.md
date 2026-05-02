# Skill Crafter Implementation Stages 2026-04-24

## Purpose

This document turns the recent skill crafter / combat rig clarification into a staged implementation path.

The goal is to stop mixing old body-plane assumptions, preview patchwork, and runtime constraints into one messy pass.
We build this in slices.
Each slice should leave the editor more truthful, more stable, and easier to extend.

Primary companion references:

- `GDD-and Text Resources/ToDo stuff/Skill Crafter TODO 2026-04-21.md`
- `GDD-and Text Resources/Combat System Canonical Truth 2026-04-21.md`

If older rough notes conflict with this file on rig authority, control hierarchy, or editor authoring behavior, use this file as the current implementation truth.

## Locked Terms

- `Contact Group`
  The hand-contact package.
  This means the hand bone set, finger bone set, hand surface contact patch, and weapon grip contact patch acting together as the weapon-contact section.
- `Occupied-Hand Authority Set`
  The control set used when a weapon is present in the hand.
  Weapon-derived controls have priority.
- `Empty-Hand Authority Set`
  The control set used when a weapon is not present in the hand.
  Hand-derived surrogate controls have priority.
- `Silent Inactive Control Set`
  A stored control set that remains saved but is not currently driving the motion node.
  It loses authority without being deleted.
- `Stance Baseline`
  The local baseline pose for a chosen hand/setup state such as right-hand one-hand, left-hand one-hand, or two-hand.
- `Baseline-Local Motion Node`
  A motion node saved relative to the stance baseline under the model root frame, not in world space.

## Reference Frame Law

- `LR_BoneRoot` is the stable model reference frame.
- The skill crafter saves authored motion node targets relative to a chosen local stance baseline under `LR_BoneRoot`.
- The editor must author in code-space, not on top of live locomotion sway.
- Gameplay runtime may later blend:
  locomotion keyframes,
  grip/contact logic,
  and the authored combat layer.
- The editor itself should not use gameplay idle/run/jump motion as the authoring driver.

## Core Authority Chain

For an occupied hand:

1. Motion node controls define weapon frame intent.
2. Weapon frame drives the rigid weapon body.
3. Rigid weapon body drives the `Contact Group`.
4. `Contact Group` drives wrist solve.
5. Wrist solve drives:
   forearm,
   elbow,
   upper arm,
   clavicle,
   and limited spine support.

For an empty hand:

1. Motion node controls define the empty-hand surrogate frame.
2. Empty-hand surrogate frame drives the empty-hand `Contact Group` equivalent.
3. That drives wrist solve.
4. Wrist solve drives the same upstream arm chain.

For a two-hand state:

1. Both arms solve against the same rigid weapon state.
2. The system is tethered.
3. Both hands are solving hand-to-weapon on separate lanes, not hand-to-hand.
4. If the secondary/support hand reaches motion max, the primary hand is allowed to move the weapon state so the secondary hand can still try to restore legal hand-to-weapon contact.
5. If that re-accommodation still cannot restore legality, movement is constrained instead of silently cheating.

## Occupied-Hand Truth

- When a weapon is present, the occupied-hand `Contact Group` is weapon-attached.
- In first implementation, wrist is solver output, not a separate authored control.
- Tip and pommel are authoring handles for the rigid weapon body.
- Weapon orientation data plus the tip-pommel relation define the occupied-hand frame.
- Old body-plane authority must be retired from the main occupied-hand solve path.

## Empty-Hand Surrogate Truth

The empty hand uses the same general system family as the occupied hand, but without weapon grip seating.

### Left Hand Local Solve Inputs

- `F = CC_Base_L_Forearm`
- `H = CC_Base_L_Hand`
- `I = CC_Base_L_Index1`
- `P = CC_Base_L_Pinky1`

Derived meaning:

- `H / I / P` define the local hand plane.
- `I-P` defines hand width.
- The altitude from `H` to the `I-P` line gives the palm-center / contact-center direction.
- `F-H` gives the wrist-back / forearm approach direction.
- `H` plus the forearm-hand joint acts as local zero for this subsystem.
- The derived altitude point becomes the axial center of the empty hand.

### Right Hand Local Solve Inputs

- `F = CC_Base_R_Forearm`
- `H = CC_Base_R_Hand`
- `I = CC_Base_R_Index1`
- `P = CC_Base_R_Pinky1`

The same solve law applies mirrored to the right side.

### Empty-Hand Authoring Handles

- Do not expose only the tiny literal hand distances.
- Extend the empty-hand control axis outward into virtual authoring handles.
- This keeps the controls visible, easier to grab, and more precise to author.
- When a weapon is present in that hand, the empty-hand controls remain stored but inactive.

## Seat Acquisition / Coupling Law

- The system is a coupling system.
- Each hand has an assigned legal target seat on the weapon when that hand is meant to be coupled.
- If a hand is already seated on its assigned target, the coupling system does nothing.
- If a hand is not seated, that hand tries to reach its assigned weapon seat through a legal path.
- This solve is hand-to-weapon, not hand-to-hand.
- The coupling solve is bidirectional:
  the hand may move toward the weapon seat,
  and the weapon may move toward the hand so the seat can come into legal range.
- In a single-hand state, the occupied hand stays latched to its assigned primary grip seat.
- In a two-hand state, both hands try to make their own assigned hand-to-weapon relationship true at the same time.
- If a currently coupled hand is already seated, that hand continues following the weapon as the shared weapon state moves.
- If dominance changes, the weapon may reorient so the newly dominant hand becomes the primary seat authority.
- Left/right hand swaps should therefore read as both hands swapping weapon seats, not as one hand teleporting to the other hand.
- For long handles such as pole or spear-like weapons, this same rule applies over more distant grip seats.
- The same coupling/seat-acquisition family can later be reused for non-grip targets such as bow-string acquisition.

## Constraint Law

- One-hand motion should prefer a valid workaround instead of a dumb dead stop.
- Two-hand motion is tethered.
- In a two-hand state, the system should first try to preserve both hand-to-weapon relationships before giving up.
- If the secondary/support hand hits its motion limit, the primary hand may yield by moving the shared weapon state to help re-establish valid support-hand contact.
- The fallback is a hard constraint only after that shared re-accommodation fails.
- Pommel has pathing priority over tip for the newer movement logic.
- The old idea of pommel orbiting around tip is not the forward model anymore.
- Body-to-body and weapon-to-body clipping prevention remain required.
- Joint limits should be encoded as:
  `swing`,
  `twist`,
  `hinge`.
- Those encoded limits must match the intended degree ranges already defined in design notes.

## State Authority Rules

- Occupied-hand controls and empty-hand controls may both exist in a motion node.
- Only one authority set drives a given side at a time.
- Inactive sets persist silently and keep their authored values.
- They lose authority without being deleted.
- Hand swaps should later be bridged visually, not snap when a transition is intended.
- A pure left-hand to pure right-hand swap should pass through a brief two-hand state.
- Reverse-grip and later stance families should fit this same authority system instead of replacing it.

## Spine / Head Scope

- Spine support is part of the solve scope.
- Neck and head stay untouched in first pass.
- Only escalate neck/head involvement if the torso chain fails catastrophically without it.

## Save / Commit Law

- Save motion-node data in stance-local space under `LR_BoneRoot`.
- Do not save world-space authored positions.
- Keep live drag edits in memory while editing.
- Save on deliberate structure or exit events such as:
  `R`,
  `T`,
  exit,
  or equivalent explicit commit actions.
- Preview should visually update during drag without noisy persistence work.

## Build Stages

## Stage 1 - Frame Cleanup And Authority Freeze

Goal:
Lock the correct reference model before adding more solver behavior.

Deliverables:

- `LR_BoneRoot` is the editor reference root.
- Motion-node data is treated as baseline-local authored data.
- The editor pose path is clearly separated from gameplay locomotion/keyframe sway.
- Silent inactive control sets are recognized as a real data concept.
- Old body-plane authority is marked deprecated for occupied-hand driving.

Done when:

- Opening the crafter no longer depends on live gameplay sway for visual motion.
- Reset/open behavior is stable relative to a stance baseline, not drifting pseudo-world state.
- Control ownership is readable in code.

## Stage 2 - Occupied-Hand Rigid Package

Goal:
Make the weapon plus `Contact Group` behave like one rigid authored package for the occupied hand.

Deliverables:

- Tip, pommel, and weapon orientation define the occupied-hand frame.
- Weapon rigid body drives `Contact Group`.
- Wrist becomes the first articulation point upstream from the rigid contact package.
- Forearm and upper chain solve behind that package instead of fighting it.

Done when:

- The weapon no longer visually leaves the occupied hand during normal authoring.
- Dragging occupied-hand controls produces meaningful weapon motion instead of instant rubberbanding to a fake default.

## Stage 3 - Empty-Hand Surrogate System

Goal:
Give the empty hand an equivalent authoring frame so one-hand skills still control the free arm coherently.

Deliverables:

- Left and right empty-hand frames are derived from:
  forearm,
  hand,
  index root,
  pinky root.
- Empty-hand virtual handles are extended outward for usability.
- Empty-hand authority activates only when no weapon is present in that hand.

Done when:

- One-hand editing can place and shape the free arm deliberately instead of leaving it as dead weight.
- Switching between occupied-hand and empty-hand authority on a side does not destroy stored authored values.

## Stage 4 - Upstream Arm Solve Pass

Goal:
Make the arm chain obey the authored contact package instead of acting visually rigid.

Deliverables:

- First-pass joint limits are encoded for:
  clavicle,
  shoulder,
  elbow,
  wrist,
  limited spine support.
- Elbow is treated as a constrained hinge in first pass.
- Wrist remains solver output, not first-pass authored control.
- Neck/head remain untouched.

Done when:

- The body visibly answers weapon or empty-hand motion.
- The system stops behaving like a frozen torso with tiny micro-adjustments only.

## Stage 5 - Two-Hand Tether And State Switching

Goal:
Make one-hand, two-hand, reverse-grip, and side swaps live under one authority system.

Deliverables:

- Two-hand solve first tries shared seat re-accommodation before hard-constraining.
- Dominant/support hand changes behave as seat swaps on the weapon, not hand-to-hand chasing.
- One-hand mode keeps empty-hand surrogate data available.
- Left/right hand swaps preserve silent inactive data.
- Swaps are prepared to bridge through a brief two-hand state.
- The shared weapon state is allowed to move to help a hand re-seat when legal coupling is still possible.
- Normal-grip to reverse-grip changes are generated as locked transition motion nodes, not direct edits to the current authored pose.
- A generated grip-swap node is deletable but not manually editable; if the author wants a different swap, they delete and recreate the bridge from the corrected source pose.
- The grip-swap bridge flips the weapon endpoint segment around the primary grip/contact seat so the hand/contact group stays the turn authority instead of the weapon teleporting through a vague world-space pivot.

Done when:

- Authors can switch ownership or stance without deleting prior authored setups.
- The editor naturally communicates "swap hands or change stance" when two-hand tethering limits motion.
- Long-handle seat swaps read coherently instead of looking like the weapon and hands disagree about who owns the grip.

## Stage 6 - Constraint And Preview Truth Pass

Goal:
Make preview truth and legality behavior match the intended authored rules.

Deliverables:

- Body clipping prevention is applied coherently.
- Weapon/body legality is applied coherently.
- One-hand workaround behavior is preferred where intended.
- Two-hand hard constraints are visible and deterministic.
- Preview truth is aligned closely enough with runtime truth that authoring is trustworthy.

Done when:

- The user can trust what they see while dragging and previewing.
- The editor no longer lies about poses that runtime cannot hold.

## Stage 7 - Phase 2 Expansion

Goal:
Add the extra articulation and polish only after the main chain is trustworthy.

Future additions:

- explicit elbow author controls,
- support-hand tween/path routing around the body,
- general hand seat-acquisition routing for swaps and bow-string grabs,
- reverse-grip refinement,
- more spine posture tools,
- later leg/knee/posture authoring,
- neck/head support only if genuinely needed.

## First Recommended Implementation Slice

The next practical slice should be:

1. Stage 1 frame cleanup and authority freeze.
2. Stage 2 occupied-hand rigid package.
3. The minimum Stage 4 arm response needed to make the body visibly answer the occupied-hand package.

Reason:

- This is the shortest path to removing the current fake motion / rubberband feel.
- It prepares the system correctly before empty-hand surrogate work and state-swap expansion.
- It gives us a truthful occupied-hand baseline, which the rest of the editor depends on.

## Guardrails

- Do not rebuild the old body-plane model under a new name.
- Do not let preview authority silently fight runtime authority.
- Do not delete inactive control sets when they should only lose authority.
- Do not attach more features on top of a chain that still rubberbands back to a false baseline.
- Do not solve editor authoring by leaning harder on gameplay keyframes.

## Working Principle

The skill crafter should author a code-driven combat pose layer.
Gameplay can later blend that authored layer with locomotion and other runtime systems.
The editor itself must first become a truthful place to author the rigid contact package and the arm chain behind it.
