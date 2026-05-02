# SKILL SYSTEM CONSOLIDATED REFERENCE 2026-04-12

Purpose:
- gather the currently existing skill-related design law, input law, skill-crafting law, CC/utility/traversal mentions, and live code-side skill hooks into one place
- preserve earlier wording so future documentation does not contradict it
- separate:
  - locked or near-locked target law
  - broader exploratory mentions
  - current code reality

Status:
- this is a consolidation/reference document
- it does not invent new design
- where sources conflict, this file calls that out instead of resolving it silently

## 1. Highest-signal source files reviewed

Chronological order by file creation time where available:

- `2026-04-08`
  - `C:\WORKSPACE\GDD-and Text Resources\UPLOADED\PLAYER_COMBAT_INPUT_AND_WEAPON_HANDLING_WORKING_SPEC_2026-03-29.md`
  - `C:\WORKSPACE\GDD-and Text Resources\UPLOADED\the GAME FEEL.txt`
- `2026-04-09`
  - `C:\WORKSPACE\GDD-and Text Resources\Runtime Weapon-Owned Melee Skill Crafter 1.md`
  - `C:\WORKSPACE\GDD-and Text Resources\Runtime Weapon-Owned Melee Skill Crafter-2.md`
  - `C:\WORKSPACE\GDD-and Text Resources\Runtime Combat Editor Visual and System Addendum.md`
  - `C:\WORKSPACE\GDD-and Text Resources\Runtime Melee Combat Editor Visual-System.md`

Additional important source files:

- `C:\WORKSPACE\GDD-and Text Resources\UPLOADED\TOWN_GATE_FLOOR_FORGE_AUTHORITY_SAVEPOINT_2026-03-23.md`
- `C:\WORKSPACE\GDD-and Text Resources\UPLOADED\thought process .txt`
- `C:\WORKSPACE\The Will- main folder\the-will-gamefiles\runtime\system\user_settings_runtime.gd`
- `C:\WORKSPACE\The Will- main folder\the-will-gamefiles\core\defs\skill_core_rules_def.gd`
- `C:\WORKSPACE\The Will- main folder\the-will-gamefiles\core\models\combat_animation_station_state.gd`
- `C:\WORKSPACE\The Will- main folder\the-will-gamefiles\services\salvage_service.gd`
- `C:\WORKSPACE\The Will- main folder\the-will-gamefiles\scenes\ui\disassembly_bench_ui.tscn`
- `C:\WORKSPACE\The Will- main folder\the-will-gamefiles\scenes\ui\combat_animation_station_ui.tscn`

## 2. Locked or near-locked skill/input law

This section reflects the strongest existing working-spec law.

Primary source:
- `PLAYER_COMBAT_INPUT_AND_WEAPON_HANDLING_WORKING_SPEC_2026-03-29.md`

### 2.1 Skill ownership and loadout

- `K` opens the skill tree / skill loadout page.
- If no weapon is equipped, the player sees the unarmed skill set.
- If one weapon is equipped, weapon skills replace the unarmed skill set.
- If two weapons are equipped, or weapon + shield, the player can choose which skills occupy the numbered skill slots.
- Skill ownership follows the weapon, not the hand side or slot side.
- Two-hand-only skills must gray out when the weapon is paired with another item and true two-hand use is no longer legal.

### 2.2 Hard combat input target law

Movement and combat:

- `1 2 3 4 5 6 7 8 9 0 - =` -> main skill slots
- `Q` -> block
- `E` -> evade / dodge
- `F` -> interact
- `SS` -> back-dodge input via double-tapping `S`

UI:

- `I` -> inventory
- `M` -> map
- `U` -> quests
- `P` -> party menu
- `L` -> friends list
- `K` -> skill tree / loadout

Communication and utility:

- `/` or `Enter` -> open chat
- `Enter` again -> send message and close chat
- `` ` `` -> ping system
- `N` -> marker radial system

### 2.2.1 Canonical main-skill slot ids

For the `12` main numbered skill slots, the canonical slot ids should be:

- `1` -> `skill_slot_1`
- `2` -> `skill_slot_2`
- `3` -> `skill_slot_3`
- `4` -> `skill_slot_4`
- `5` -> `skill_slot_5`
- `6` -> `skill_slot_6`
- `7` -> `skill_slot_7`
- `8` -> `skill_slot_8`
- `9` -> `skill_slot_9`
- `0` -> `skill_slot_10`
- `-` -> `skill_slot_11`
- `=` -> `skill_slot_12`

Current consolidation note:

- a local workspace sweep did not find an occupied pre-existing use of `skill_slot_1` through `skill_slot_12`
- these names are therefore currently safe as the canonical basic-skill-slot ids

Interpretation rule:

- these are slot ids
- they are not merely visual labels
- they should become stable data anchors for gameplay rules, skill-crafter authoring law, and runtime execution law

### 2.3 Evade law

- `E + A` or `E + D` -> lateral evade
- `E + WA`, `E + WD`, `E + SA`, `E + SD` -> diagonal evade variants
- plain `E` -> local backflip
- midair `E` -> airborne evade / hover-like extension 

Timing:

- directional `E` variants -> `0.6s`
- non-directional `E` -> `1.0s`
- airborne `E` -> `1.0s`

Resource use:

- each evade source consumes `30` stamina from stamina resource pool (default value 100 can be incresed via equipment )

### 2.4 `SS` back-dodge law

- `SS` means pressing `S` twice within `1.0s`
- cannot be performed while airborne
- always moves the character backward by `5m`
- can combine with held directionals, will always move towards camera 

Current intended orientation rule:

- `SS` during `W` or `D` combination -> counter-clockwise rotational feeling
- `SS` during `A` combination or while stationary -> clockwise rotational feeling

Timing:

- `1.0s`

Resource use:

- `30` stamina

### 2.5 Iframe law

- iframes should be implemented by disabling the player hurtbox for a fixed duration
- stamina is consumed at the same moment the hurtbox is disabled
- canceling the visible animation does not end invulnerability early
- faster movement speed or attack speed should not shrink the iframe window
- re-casting before prior end resets the timer and consumes stamina again if available
- DOT already applied to the player continues ticking normally

### 2.6 Block law

- `Q` is the block input

Shield equipped:

- blocking can be held indefinitely while the button is held
- releasing block starts a `0.5s` cooldown

No shield equipped:

- blocking still exists
- max continuous block duration is `2.5s` will auto remove block status even if the key is held down longer  then  the block duration 
- once block ends, block enters a `1.0s` cooldown

Important:

- block does not consume stamina under the current rule

### 2.7 HUD layout editor law

Requested gameplay HUD shell:

- `12` main skill slots
- `1` separate block slot
- `1` horizontal HP bar
- `1` separate vertical stamina bar
- `1` separate interraction button that will come in view if in range  of interactable components
- `1` chat box
- `1` minimap
- `1` active buff effect display list
- `1` active debuff effect display list
- `1` current-enemy-target horizontal HP bar

Layout law:

- the `12` skill slots should be arranged as `6 + 6`
- each six-slot half should behave as part of one combined horizontal bar for movement in the HUD editor
- the separate block slot stays its own element

Persistence:

- per-player HUD layout
- set-it-and-forget-it until the player changes it again

Later HUD editor:

- reposition skill bar group, block slot, HP bar, and stamina bar, interraction button,  Chat box, Minimap, active buff, active debuff, current-enemy-target HP bar 
- `Adjust UI Size` for these gameplay HUD elements

## 3. Skill crafter and combat animation creator law

Primary sources:

- `Runtime Weapon-Owned Melee Skill Crafter 1.md`
- `Runtime Weapon-Owned Melee Skill Crafter-2.md`
- `Runtime Melee Combat Editor Visual-System.md`
- `Runtime Combat Editor Visual and System Addendum.md`

### 3.1 Core ownership law

- every weapon owns its own skill profile
- every editable skill draft belongs to exactly one owning weapon
- draft state persists inside the owning weapon data
- reopening the same weapon restores that same weapon draft state
- newly created weapons must receive a simple default baseline skill package
- developer starter weapons and starter skillsets should be authored using the same system

### 3.2 Top-level workflow

- WIP Weapon List
- Skill List
- Editor

The editor should never open without:

- one selected weapon
- one selected skill

Back-navigation law:

- backing out from the editor returns to the `Skill List`
- backing out again returns to the `WIP Weapon List`
- backing out again closes the skill-crafter / combat-animation menu fully
- closing or backing out at any point must preserve the already authored work through auto-save

### 3.3 Required editor controls

Required default bindings for the skill crafter / combat editor authoring flow:

- `Q` = previous motion node
- `E` = next motion node
- `R` = add new motion node after current motion node
- `T` = delete current editable motion node
- `Space` = cycle between active sub-controls while committing the current sub-control state
- `F` = preview full chain from beginning
- `F` again during preview = cancel preview

Required action names:

- current compatibility / legacy ids in existing wording:
- `skill_crafter_prev_point`
- `skill_crafter_next_point`
- `skill_crafter_new_point`
- `skill_crafter_delete_point`
- `skill_crafter_commit_point`
- `skill_crafter_play_preview`

Recommended future naming for clarity:

- `skill_crafter_prev_motion_node`
- `skill_crafter_next_motion_node`
- `skill_crafter_new_motion_node`
- `skill_crafter_delete_motion_node`
- `skill_crafter_cycle_active_subcontrol`
- `skill_crafter_play_preview`

Naming guidance:

- user-facing terminology should move to `motion node`
- the old `*_point` action ids are now semantically weak
- especially `skill_crafter_commit_point`, because the current `Space` law is really a commit-and-cycle subcontrol action between `tip` and `pommel`
- if code migration happens later, it should be done as one clean rename pass or with temporary alias support, not as a half-renamed mixed state

Optional actions mentioned:

- `skill_crafter_drag_target`
- `skill_crafter_rotate_plane_modifier`
- `skill_crafter_rotate_weapon_modifier`
- `skill_crafter_cancel_edit`

### 3.4 Motion-node chain law

- the authored unit is an ordered chain of authored timeline units
- do not replace the point-chain model with dense keyframe editing
- earlier documents call these units `points`
- this document clarifies that those units are better understood as composite `motion nodes`
- drafts are ordered chains of those committed authored units

Editor-side authored content fields must also include at least:

- skill name field
- skill description / notes text field

These must remain editable in the authoring workflow and persist with the owning draft data.

### 3.5 Onion skin and path law

- local `5-motion-node` neighborhood when possible:
  - current motion node
  - `-1`
  - `-2`
  - `+1`
  - `+2`
- `+-1` transparency = `50%`
- `+-2` transparency = `25%`
- editor must show a spline-like trajectory through the visible/local chain
- the path must update live after navigation, add, delete, drag, and commit

### 3.6 Preview/playback law

- `F` preview always starts from motion node `0`
- pressing `F` again during playback cancels the preview
- playback is read-only relative to committed draft data
- the same chain playback logic should be reusable outside the editor for:
  - runtime skill presentation
  - inspection
  - trading / presentation contexts

### 3.7 Combat editor visual/system law

The combat editor is not a generic animation editor. It is:

- a runtime 3D combat authoring scene
- weapon-owned
- skill-slot aware
- Bezier-curve driven
- motion-node structured

Hard law:

- motion nodes are the hard gameplay structure
- Bezier handles / control vectors are the freedom layer

### 3.8 Role/slot categories already named

These role boxes are explicitly named in the combat editor specs:

- `block/parry`
- `displacement / dash`
- `crowd-control`
- `damage`
- `buff / support`
- `iframe`

Important law:

- the motion being authored is the expression of the selected slot, not a redefinition of the slot role

### 3.9 Stage 1 relationship

The combat editor must pull gameplay-relevant input from Stage 1 weapon data, including:

- material data
- effect data
- hit-count modifiers if present
- center of mass
- mass distribution
- grip-related data
- handling-related values
- weapon class output

Stage 2 is not the core combat-truth source for this editor.

### 3.9.1 Skill-slot data authority for the skill crafter

The skill crafter should not treat the selected skill slot as only a UI label.

The selected slot id should become a real data authority surface.

For the basic `12`-slot set, this means:

- `skill_slot_1`
- `skill_slot_2`
- `skill_slot_3`
- `skill_slot_4`
- `skill_slot_5`
- `skill_slot_6`
- `skill_slot_7`
- `skill_slot_8`
- `skill_slot_9`
- `skill_slot_10`
- `skill_slot_11`
- `skill_slot_12`

These slot ids should later be able to carry or resolve additional authored/combat-driving values such as:

- how many motion nodes are allowed for that slot
- how many damage instances can occur for that slot
- what body-motion range or body-motion category is legal for that slot
- what built-in slot law exists for:
  - CC
  - displacement / dash
  - damage
  - iframe
  - support / buff
  - other slot-defined behavior
- what usage conditions or legality conditions apply to that slot

Practical law:

- the skill crafter output should be influenced by:
  - selected slot data
  - Stage 1 weapon/material data
  - later runtime legality / state checks

This means the authored animation/motion layer should not be inventing those gameplay truths by itself.
It should be authoring motion inside the law box already defined by:

- the selected skill slot
- the selected weapon
- the selected material/build outputs

### 3.10 Hit and segment law

- first transition into the first motion node is startup / non-hit entry motion
- each later motion-node-to-motion-node segment is one potential strike phase
- near each motion node there is a slowdown/reset band
- after slowdown, motion re-accelerates into the next segment

### 3.11 Speed-state visualization

The trajectory path is intended to show speed-state:

- `red` = valid armed strike threshold
- `green` = below low-speed threshold / reset / non-armed phase
- gradient between them = buildup / decay / intermediate state

### 3.12 Terminology correction for authored timeline units

The word `point` is not precise enough for the skill creator context if it is read as a single location in space.

For this document, the recommended replacement term is:

- `motion node`

Reason:

- it avoids drifting into Godot’s existing `keyframe` terminology
- it acknowledges that the authored unit is a combination of multiple parameters on a timeline
- it matches the real intent better than a simple positional `point`

Practical law:

- a `motion node` is the authored timeline unit
- a `motion node` is not just one position
- a `motion node` is a composed weapon-motion state defined by multiple derived and editable parameters

Until the wider project is renamed consistently, any earlier document that says `point` in the skill-crafter / combat-editor context should be read as:

- `motion node`

and not as:

- one standalone world-space point

### 3.13 Motion node definition and control law

A `motion node` is the combination of multiple parameters on the authored timeline.

It is built around:

- the weapon’s resolved grip axis
- the weapon’s resolved total-length axis state
- the derived `tip` control point
- the derived `pommel` control point
- the `trajectory_plane`
- the parent-child control hierarchy between those elements
- player-character IK range-of-motion limitations

#### 3.13.1 Grip-axis derivation

The grip axis is not guessed from arbitrary weapon center.

It is derived from the valid grip section:

- find the valid grip segment
- resolve the grip-valid endcaps
- for each endcap, calculate the center of the grip slice using the already intended/used grip-slice-center logic
- if multiple valid grip sections or valid grip endpoints exist, use the two furthest-apart valid grip endcaps
- connect those two endcap centers with a line

That line becomes:

- the `grip axis`

This axis is the driving reference axis for the weapon.

#### 3.13.2 Weapon extremity derivation from the grip axis

Once the grip axis exists, determine the true weapon length relative to that axis.

Method:

- project the Stage 1 authored weapon occupancy against the grip axis
- locate the two furthest weapon-extremity conditions along that axis
- create one plane at each extremity
- each extremity plane must be:
  - perpendicular to the grip axis
  - tangent to the weapon extremity on that side

This gives:

- `weapon_total_length_plane_1`
- `weapon_total_length_plane_2`

The distance between those two planes along the grip axis becomes:

- `weapon_total_length_calculated`

This should be stored as a precise float-distance value in meters.

#### 3.13.3 Dominant-hand position plane and tip/pommel resolution

The system must also determine where the current dominant-hand grip position sits on the grip axis.

Method:

- resolve the current dominant-hand grip position as a plane perpendicular to the grip axis
- measure its distance along the grip axis to both weapon-total-length extremity planes

Safe current implementation assumption:

- until another authority is locked, resolve this from the active primary grip seat / dominant-hand grip anchor projected onto the grip axis

Interpretation:

- the greater distance side is the `tip`
- the shorter distance side is the `pommel`

The actual control points are then:

- `tip` = intersection of the grip axis with the extremity plane on the greater-distance side
- `pommel` = intersection of the grip axis with the extremity plane on the shorter-distance side

These two points are the main weapon manipulation points for the authoring system.

#### 3.13.4 Tip-pommel axis and grip-axis roll control

The `tip` and `pommel` form the active weapon axis used by the motion node.

The motion node must also support weapon roll around the direction axis of the resolved grip axis.

Important clarification:

- the `+-120` degree law belongs to this roll control
- this is not meant as a vague free-angle rotation in arbitrary space
- it is the weapon’s roll around its grip-axis direction reference

Current stated law:

- allowed roll range: `-120` to `+120` degrees
- angle stepping target: `1` degree increments
- manipulation method: drag gizmo in the 3D viewport

Zero-angle convention clarification:

- zero degrees is now locked to the negative-Y direction of the Stage 1 calculation-space / weapon-authoring work axis
- this direction should be carried forward from the Stage 1 calculation process, because that is where the relevant weapon data points and orientation references are resolved
- for this system, `-Y` is the correct orientation reference for zero-angle roll control

Important interpretation note:

- this is the Stage 1 calculation/work-space axis rule used for weapon authoring and motion-node orientation
- it should not be rewritten later into looser compass wording if the code is already using the Stage 1 calculation-space axis as truth

#### 3.13.5 Trajectory plane law

The `trajectory_plane` is the parent movement frame for the motion node.

Its intended anchor/reference is relative to the player body:

- vertically centered between the shoulders
- centered through the spine for lateral body centerness

The `trajectory_plane`:

- defines the primary plane of action
- can be tilted/reoriented through its gizmo control
- carries the `tip` as a child control

Important behavior:

- moving or tilting the `trajectory_plane` moves the `tip` in space
- this is like moving a tray while the item on the tray keeps its local relationship to the tray

#### 3.13.6 Tip control law

The `tip` is a child of the `trajectory_plane`.

The `tip` can be:

- repositioned along the surface of the active trajectory plane
- dragged directly as a control point

The `tip` therefore has two influences on its final position:

- upstream motion from the `trajectory_plane`
- its own direct manipulation along the plane surface

The `tip` then influences the downstream position of the `pommel`.

#### 3.13.7 Pommel control law

The `pommel` is a child of the `tip`.

The `pommel`:

- follows the `tip`
- can orbit around the `tip`
- is constrained to a spherical surface

Current spherical constraint:

- sphere radius = `weapon_total_length_calculated`

This keeps the weapon length consistent while still allowing pommel orbit and orientation change.

#### 3.13.8 Control hierarchy

Control hierarchy is strictly downstream:

- `trajectory_plane` = parent
- `tip` = child of `trajectory_plane`
- `pommel` = child of `tip`

Meaning:

- `trajectory_plane` motion affects `tip` and `pommel`
- `tip` motion affects `pommel`
- `pommel` does not push upstream into `tip`
- `tip` does not push upstream into `trajectory_plane`

Short form:

- motion can influence downstream, not upstream

#### 3.13.9 Secondary axial reposition along the grip axis

The motion node must also support a secondary axial reposition of the weapon along the resolved grip axis.

This is a separate degree of freedom from:

- trajectory-plane positioning
- tip movement on the trajectory plane
- pommel orbit around the tip

Meaning:

- the active weapon state can slide along the grip axis
- this slide must operate within authored or derived `min` / `max` bounds
- this is a bounded axial reposition, not a free infinite translation

Safe interpretation:

- this axial reposition moves the weapon state along its own grip-axis reference
- it does not redefine the grip-axis direction
- it does not change `weapon_total_length_calculated`
- it acts as an additional authored parameter of the motion node

Structural interpretation:

- `tip` and `pommel` remain the main manipulation points
- the axial reposition changes the weapon’s seat along the grip axis as one coherent state variable
- this should be preserved as part of authored motion-node data

Range law:

- the slide must be clamped by explicit `min` / `max` range values
- those limits must remain compatible with player IK/body legality and the weapon’s authored use-space

#### 3.13.10 Dominant-hand grip-seat slide law

The motion node should also support a separate hand-position control along the grip axis.

This is distinct from:

- weapon axial reposition along the grip axis
- trajectory-plane movement
- tip movement
- pommel orbit

The intended authored helper state is:

- a perpendicular hand-position plane on the grip axis
- with its center on the grip axis defining the active dominant-hand grip seat

Recommended term:

- `dominant_hand_grip_seat`

Recommended structural behavior:

- this should be implemented as a child/helper under the weapon grip-axis frame or weapon root
- it should move with the weapon
- it should be able to slide locally along the weapon’s grip axis
- it should not be a parent driving the whole weapon transform when the goal is hand reposition on a stationary weapon

Use-case law:

- this allows the hand to move along the grip while the weapon remains stationary in its current authored weapon state
- this is required for motions such as sliding the hand toward the end of the grip during extension, thrusting, or grip transitions
- this also supports transitions such as two-hand grip into single-hand extension

Range law:

- the grip-seat slide must respect explicit or derived `min` / `max` bounds on the valid grip zone
- hand slide must remain inside legal grip range
- hand slide must also remain inside player IK/body legality

Important distinction:

- weapon axial reposition moves the weapon state along the grip axis
- dominant-hand grip-seat slide moves the hand attachment target along the grip axis relative to the weapon
- these are separate control variables and should not be collapsed into one parameter

#### 3.13.11 IK and body-limitation law

All of the above is subject to player body limitations.

The motion node must respect:

- player-character IK limitations
- player-character range of motion
- body legality / restriction rules

These limitations apply to:

- trajectory-plane manipulation
- axial reposition along the grip axis
- dominant-hand grip-seat slide
- tip repositioning
- pommel orbit/repositioning

The goal is:

- authored control freedom inside legal body motion
- not disconnected weapon motion that the player body cannot realistically support

#### 3.13.12 Current authoring controls implied by this model

The current intended manipulable factors are:

- trajectory-plane orientation via drag gizmo controller
- bounded axial reposition along the grip axis
- bounded dominant-hand grip-seat slide along the grip axis
- tip manipulation along the trajectory-plane surface by dragging the tip itself
- pommel manipulation along the spherical surface defined by `weapon_total_length_calculated`

This means the authored `motion node` is already more than a point-chain model in the naive sense.

It is better understood as:

- a timeline chain of constrained weapon-motion nodes

#### 3.13.13 Motion-node editing workflow

The intended workflow for one motion node is:

1. open editor on the selected weapon-owned skill
2. adjust the `trajectory_plane`
3. apply the bounded axial reposition along the grip axis if needed
4. apply the bounded dominant-hand grip-seat slide if needed
5. position the `tip`
6. press `Space`
7. position the `pommel`
8. press `Space`
9. return to `tip` state for refinement if needed

Meaning of `Space` in this workflow:

- it commits the currently active sub-control state
- then cycles active editing focus between `tip` and `pommel`

Safe interpretation:

- the `trajectory_plane` is edited directly as part of the current motion node state
- the axial grip-axis reposition is also part of the current motion node state
- the dominant-hand grip-seat slide is also part of the current motion node state
- `Space` is primarily the `tip/pommel` sub-control cycle action
- `Space` is not the action that creates the next motion node

Meaning of `R` in this workflow:

- `R` inserts a new motion node after the current motion node
- the newly inserted motion node becomes active
- the new motion node opens in its editable authoring state so the player can:
  - adjust the `trajectory_plane`
  - adjust the bounded axial reposition if needed
  - adjust the bounded dominant-hand grip-seat slide if needed
  - position the `tip`
  - then use `Space` to move into `pommel`

Meaning of `Q` and `E` in this workflow:

- `Q` moves to the previous authored motion node
- `E` moves to the next authored motion node
- they are navigation only
- they do not create or destroy data

Meaning of `F` in this workflow:

- `F` previews the full authored chain from the beginning
- `F` again cancels that preview
- preview is for review only and must not mutate authored draft data

This yields the intended working loop:

- select weapon
- select skill
- editor opens
- position plane
- apply axial reposition if needed
- apply hand slide if needed
- position tip
- `Space`
- position pommel
- `Space` if more local refinement is needed
- `R` when ready to create the next motion node
- use `Q` / `E` to move back and forth between existing motion nodes
- use `F` to review the full chain
- continue adding or refining motion nodes
- closing or navigating back out auto-saves the work

#### 3.13.14 Naming and description authoring requirement

The skill authoring workflow should expose editable text fields for:

- skill name
- skill description

These belong in the authoring UI, not as a later external-only metadata step.

#### 3.13.15 Safe interpretation note

The earlier point-chain law is still directionally correct, but it must now be interpreted as:

- authored timeline units are discrete and ordered
- each authored unit is a composite `motion node`
- the editor is still not a dense freeform keyframe editor
- but each unit carries more internal structure than a single point in space

That preserves the original design intent while correcting the too-simple wording.

## 4. CC, utility, traversal, and gameplay-style mentions already present

This section is broader and more exploratory than the working-spec material. It matters because it shows the existing design direction and wording, but it is not as locked as Section 2.

Primary source:
- `thought process .txt`

### 4.1 Broad combat style direction

Repeated phrases and ideas:

- projectile-based combat
- CC
- utility
- environmental interaction
- visible skill expression in PvE
- mastery expressed through manipulating enemies, environment, and traversal tools

### 4.2 Broader input-density idea

Exploratory input-density wording already exists for:

- `WASD`
- `Space`
- `Ctrl`
- `12345`
- `QERFGZXCV`
- `LMB / RMB`
- `Mouse4 / Mouse5`
- `Shift + 1-5`
- `Tab`

This broader concept is repeatedly associated with:

- combat
- consumables
- skills
- ultimate
- party buffs

Important:

- this broader thought-process mapping is not the same thing as the working-spec mapping in Section 2
- it should be treated as broader exploration, not a finalized keybind law

### 4.3 Traversal and utility ideas repeatedly mentioned

- jumping
- vaulting
- grapple hooks
- mounts
- shoulder bash
- push/pull mechanics
- environmental triggers
- traps
- destructible objects
- physics-based hazards
- optional B-hopping behind achievement gates

### 4.4 CC or combat-effect-adjacent examples mentioned

Broadly mentioned or implied:

- crowd control
- push
- pull
- displacement
- optional landing effect:
  - stun
  - AoE
  - momentum

Important:

- the repo currently contains role/category language for CC much more strongly than a finalized named skill roster
- there is not yet a finalized document listing a locked set of named CC skills

## 5. Skill cores, chase skills, and skill-crafter placement in the overall loop

Primary source:
- `TOWN_GATE_FLOOR_FORGE_AUTHORITY_SAVEPOINT_2026-03-23.md`

### 5.1 Skill crafter place in overall forge loop

The current loop includes:

- optionally visit the skill crafter at any point between crafting and engraving

Important law:

- if the player does not explicitly perform skill-crafter work before engraving, the system should auto-load the best-fit default skill set based on hierarchy
- reason: do not allow a valid crafted item to be finalized into a broken finished state with no meaningful skills assigned

### 5.2 Skill cores

Current law:

- skill cores are chase materials
- they provide preset powerful abilities
- they cannot be modified in the skill crafting station
- if many skill cores are used in one item, salvage should force meaningful tradeoffs about what to recover
- skill cores should be legal for weapons but not for armor or accessories

## 6. Current live code reality

This section matters because some current code defaults conflict with the stronger design docs. Do not silently merge them.

### 6.1 Current live input-action defaults in code

Primary source:
- `runtime/system/user_settings_runtime.gd`

Current live/default code actions include:

- `move_forward` -> `W`
- `move_back` -> `S`
- `move_left` -> `A`
- `move_right` -> `D`
- `jump` -> `Space`
- `sprint` -> `Shift`
- `dodge` -> `Ctrl`
- `interact` -> `F`
- `auto_run` -> `=`
- `skill_mobility` -> `Q`
- `skill_defense` -> `E`
- `target_cycle` -> `Tab`
- `quick_use_item` -> `X`
- `ui_inventory` -> `I`
- `ui_map` -> `M`
- `ui_character` -> `C`
- `ui_social` -> `O`

Important contradiction:

- current code default `Q = skill_mobility` and `E = skill_defense`
- stronger working-spec target law says `Q = block` and `E = evade`
- current code default `Ctrl = dodge`
- stronger working-spec target law says `SS` and `E` carry the evade focus

Conclusion:

- the live code input defaults are not yet the final combat-law truth
- future documentation should not treat `user_settings_runtime.gd` as the final design authority on combat binds

### 6.2 Current live combat animation creator state

Primary source:
- `core/models/combat_animation_station_state.gd`

Current live resource layer already expects:

- `author_idle`
- `author_skill`
- `idle_combat`
- `idle_noncombat`
- default melee skill draft ids:
  - `melee_baseline_a`
  - `melee_baseline_b`
- generic fallback draft id:
  - `weapon_baseline_a`

This is implementation truth, not necessarily final gameplay naming.

### 6.3 Current live combat animation station slot placeholder

Primary source:
- `scenes/ui/combat_animation_station_ui.tscn`

Current placeholder text:

- `slot_damage / slot_block / slot_dash`

This is useful as a current implementation hint, but it is not the full or final slot taxonomy because the docs already name more slot families than these three.

### 6.4 Current live skill-core code law

Primary source:
- `core/defs/skill_core_rules_def.gd`

Live code confirms:

- `skill_cores_are_nonmodifiable_in_skill_station = true`

### 6.5 Current live salvage/disassembly state

Primary sources:

- `services/salvage_service.gd`
- `scenes/ui/disassembly_bench_ui.tscn`

Live code/UI currently says:

- `Blueprint extraction and chase-skill recovery stay disabled until finalized-item makeup data exists.`
- `No blueprint or chase-skill extraction options are available for the current selection.`
- there is a hidden placeholder button:
  - `Select Skill`

Conclusion:

- blueprint extraction and chase-skill recovery are acknowledged in current UI/service language
- they are not active yet

### 6.6 Current live skill-family/material hooks

Primary sources:

- `core/defs/base_material_def.gd`
- `core/resolvers/material_runtime_resolver.gd`
- `services/forge_service.gd`
- material `.tres` files

The codebase already expects materials to influence skill-family bias through Stage 1 bake/material resolution.

Current skill-family names seen in material definitions:

- `melee`
- `magic`
- `support`
- `ranged`
- `defense`
- `mobility`
- `single_target`
- `control`
- `burst`

Examples:

- `frost` biases toward `control`
- `healing` biases toward `support`
- `aqua` biases toward `support` and `ranged`
- `wood` biases toward `melee`, `mobility`, and `support`
- `pyro` biases toward `magic` and `burst`

This means:

- skill-family interaction is not only a design idea
- the codebase already has a Stage-1-material-to-skill-family bridge

## 7. Exact wording bank worth preserving

These are direct phrases or near-direct preserved phrases that appear important enough to reuse without rewriting loosely.

### 7.1 Reverse grip tooltip

`Reverse grip shortens the weapon's effective reach significantly and disables two-handed weapon techniques, but grants +25% attack speed.`

### 7.2 Crafter/editor identity

`Do not reinterpret the design into a generic animation editor.`

`Do not replace the point-chain model with dense keyframe editing.`

`Do not detach skill drafts from weapon ownership.`

### 7.3 Combat editor identity

`The combat editor does not invent the combat role of the skill.`

`The skill slot already defines the functional box.`

`The motion being authored is the expression of the selected slot, not a redefinition of the slot’s role.`

### 7.4 Motion-node / Bezier law

`points are the law`

`Bezier handles are the freedom`

### 7.5 Skill visibility / mastery language

`He used that room in a way I didn't think of.`

`Projectile-based, CC, utility, environment interaction`

`PvE skill visible: manipulation of enemies and environment expresses mastery`

`Skill mastery visible in PvE (or boss fight equivalents) via manipulation of enemies and environment`

### 7.6 Skill-core law

`They provide preset powerful abilities that cannot be modified in the skill crafting station.`

### 7.7 Disassembly/chase-skill current state

`Blueprint extraction and chase-skill recovery stay disabled until finalized-item makeup data exists.`

`No blueprint or chase-skill extraction options are available for the current selection.`

## 8. What is still not concretely defined yet

To avoid contradictions, these should be treated as open or partial rather than silently assumed complete.

- final named skill roster across all weapon families
- final CC skill list
- exact per-slot gameplay effect tables
- final relationship between broad exploratory input-density idea and the tighter combat-input working spec
- final active-bar packing logic beyond the current numbered-slot direction
- final combat/idle animation authoring and playback pipeline for all weapon types
- final chase-skill extraction system
- final blueprint extraction rules
- final sound/effect mapping thresholds

## 9. Practical safe summary

If you need the safest short interpretation of everything already mentioned:

- hard target law currently favors:
  - `12` main skill slots on `1 2 3 4 5 6 7 8 9 0 - =`
  - `Q = block`
  - `E = evade`
  - `F = interact`
  - `SS = back-dodge`
  - `K = skill tree/loadout`
- melee skill authoring is weapon-owned and motion-node-chain based
- the combat editor is runtime, Bezier-curve driven, and slot-aware
- named slot families already include:
  - block/parry
  - displacement/dash
  - crowd-control
  - damage
  - buff/support
  - iframe
- broader game direction repeatedly supports:
  - projectile-based combat
  - CC
  - utility
  - environmental interaction
  - traversal expression through jump/vault/grapple/push/pull
- skill cores are chase materials and are nonmodifiable in the skill station
- current live code still contains older or placeholder input/default assumptions, so design docs and code are not fully aligned yet

## 10. Recommended authoring rule going forward

When writing future skill documentation, treat authority in this order:

1. `PLAYER_COMBAT_INPUT_AND_WEAPON_HANDLING_WORKING_SPEC_2026-03-29.md`
2. `Runtime Weapon-Owned Melee Skill Crafter 1.md`
3. `Runtime Weapon-Owned Melee Skill Crafter-2.md`
4. `Runtime Melee Combat Editor Visual-System.md`
5. `Runtime Combat Editor Visual and System Addendum.md`
6. this consolidation file
7. current live code defaults only as implementation-state evidence, not as final design law
