# Skill Crafter Unified Implementation TODO 2026-04-30

## Purpose

This file consolidates the current Skill Crafter / combat motion direction after the 2026-04-30 discussion.

It supersedes older TODO wording where there is conflict. Older TODO files still matter as reference, but this file is the working implementation order for the next passes.

Compared sources:

- `GDD-and Text Resources/ToDo stuff/Skill Crafter TODO 2026-04-21.md`
- `GDD-and Text Resources/ToDo stuff/Skill Crafter Implementation Stages 2026-04-24.md`
- `GDD-and Text Resources/ToDo stuff/the thing i figured out.md`
- `GDD-and Text Resources/Combat System Canonical Truth 2026-04-21.md`
- `GDD-and Text Resources/Runtime Weapon-Owned Melee Skill Crafter 1.md`
- `GDD-and Text Resources/Runtime Weapon-Owned Melee Skill Crafter-2.md`
- `GDD-and Text Resources/Runtime Melee Combat Editor Visual-System.md`
- `GDD-and Text Resources/Runtime Combat Editor Visual and System Addendum.md`
- `GDD-and Text Resources/ToDo stuff/Combat Editor Original Intent Digest 2026-04-30.md`
- Current chat decisions from 2026-04-29 to 2026-04-30

## Current Implemented Foundation

These pieces are already present enough to build on:

- Motion nodes store weapon endpoint positions, weapon orientation, roll, grip slide, axial offset, body support, grip style, two-hand state, and primary hand slot.
- The chain player keeps tip/pommel segment length rigid during playback.
- Grip-swap bridges exist and can freeze the source grip/hand orientation until the target grip state is reached.
- Runtime hidden entry and recovery bridges exist:
  - skill entry bridge: current truth -> first editable skill node, currently `0.3s`
  - recovery bridge: final skill state -> combat idle, currently `1.2s`
- A max reach / trajectory volume resolver exists.
- The current inner "no shortcut / no body crush" minimum volume is intentionally not final because full body/weapon clearance proxies do not exist yet.

## Implemented Slice - 2026-04-30

First authority-cleanup slice is implemented in code:

- Stage 1 forge grip/stow controls are hidden, disabled, and inert.
- Stage 1 project metadata save paths preserve existing legacy `grip_style_mode` / `stow_position_mode` instead of accepting obsolete UI selections as new authority.
- Saved project catalog descriptions no longer present grip/stow as Stage 1 gameplay truth.
- Combat idle drafts are normalized to one motion node at model level.
- Combat idle add/duplicate actions reset the single idle pose instead of adding structure.
- Combat idle delete is rejected.
- Combat idle primary hand is locked from equipment/open-hand context and cannot be edited from the primary-hand field.
- Skill nodes still keep editable `primary_hand_slot` for future authored hand swaps.

Verification:

- `tools/verify_crafting_bench_stow_ui.gd`
- `tools/verify_combat_idle_single_node_authority.gd`
- `tools/verify_combat_animation_station_baseline_reset.gd`

Second authority-cleanup slice is implemented in code:

- `idle_noncombat` is now a station-owned idle context created beside `idle_combat`.
- Noncombat idle stores its stow anchor mode on the idle draft as station truth.
- Legacy WIP `stow_position_mode` seeds the noncombat idle stow anchor when the station context is first created, then becomes fallback only.
- Runtime stowed weapon anchoring resolves from the station noncombat idle draft before falling back to the legacy WIP field.
- Runtime noncombat idle results now include the source noncombat idle draft, station stow mode, and its single motion-node data, while still keeping hands detached from the weapon.
- Both combat and noncombat idle drafts share the single-node UI guard: add/duplicate reset, delete is rejected, and primary hand remains locked from equipment/open-hand context.

Verification:

- `tools/verify_combat_animation_station_foundation.gd`
- `tools/verify_player_runtime_idle_pose.gd`
- `tools/verify_weapon_stow_positions.gd`
- `tools/verify_combat_idle_single_node_authority.gd`
- `tools/verify_combat_animation_station_baseline_reset.gd`

Third implementation slice is implemented in code:

- Runtime hidden bridge state now tracks skill entry, skill interrupt entry, skill recovery, draw-to-combat-idle, and stow-to-noncombat-idle bridge kinds.
- Runtime skill activation from stowed/noncombat state starts a draw bridge before combat playback.
- Runtime skill completion captures recovery truth and starts a recovery bridge back into combat idle.
- Combat idle expiry is implemented with a tunable default of `15.0s`, plus short-test override support.
- Expiry requests stowing the weapon and records the stow bridge state instead of mutating authored station data.
- Speed-state sampling now classifies reset, buildup, and armed samples along the trajectory.
- Temporary acceleration/deceleration percentage controls are exposed in the station UI.
- Preview trajectory coloring now uses sampled speed-state data, with degenerate zero-length curves safely ignored.

Verification:

- `tools/verify_player_runtime_skill_entry_recovery.gd`
- `tools/verify_player_runtime_idle_pose.gd`
- `tools/verify_combat_speed_state_feedback.gd`
- `tools/verify_combat_animation_station_foundation.gd`

Fourth implementation slice is implemented in code:

- Body clearance proxy generation now derives from the loaded character mesh bounds plus the stable CC_Base bone naming contract.
- The current placeholder character produces mesh-derived body clearance descriptors for torso, pelvis, shoulders, upper arms, forearms, thighs/calves, and head.
- Body clearance proxy regions are inflated by the default `0.005m` clearance value and keep source/debug metadata.
- The older hand-authored box/capsule body proxy remains only as a fallback when no mesh can be read.
- Weapon body restriction proxies now derive from Stage 2 display-cell geometry instead of only the grip slice.
- Weapon proxies include full-geometry bounds/corner/face/endpoint/cell samples and use the default `0.005m` clearance metadata.
- Preview/debug paths now see the larger geometry-derived proxy families.

Verification:

- `tools/verify_player_weapon_guidance.gd`
- `tools/verify_combat_animation_station_preview.gd`

Fifth implementation slice is implemented in code:

- Noncombat idle now has an explicit station-owned stow anchor selector in the Skill Crafter UI.
- The stow selector is hidden for combat idle and skill drafts, and active only for `idle_noncombat`.
- Runtime stowed weapon presentation now resolves the station noncombat idle motion node when present.
- Authored stow tip/pommel placement is solved relative to the selected stow anchor frame.
- Stow placement preserves rigid weapon length by resolving the legal endpoint instead of stretching the weapon to an invalid authored pair.
- Legacy WIP `stow_position_mode` remains a seed/fallback only.

Verification:

- `tools/verify_combat_idle_single_node_authority.gd`
- `tools/verify_weapon_stow_positions.gd`

Sixth implementation slice is implemented in code:

- Body clearance point queries now return structured legality data instead of only true/false.
- Returned data includes body region, attachment name, shape kind, estimated clearance/penetration, and suggested correction vector.
- A collision legality resolver now evaluates weapon proxy samples against body proxy regions for a single pose.
- The same resolver evaluates sampled path transforms for trajectory-level legality.
- Preview debug state exposes pose legality, path legality, illegal sample counts, first illegal path index, collision region, and clearance.
- The Skill Crafter summary reports pose/path collision status when trajectory samples exist.
- Existing deterministic correction paths still use the same weapon/body proxy collision check, now through the structured resolver.

Verification:

- `tools/verify_combat_animation_station_preview.gd`
- `tools/verify_player_weapon_guidance.gd`

Seventh implementation slice is implemented in code:

- The preview segment legalization path now uses the structured weapon/body collision correction vector instead of only a generic forward push.
- After inner collision correction, the segment is reprojected through the outer reach shell so max reach and body clearance are considered together.
- Authored tip/pommel edits now pass through contact tethering and then through the preview actor legality clamp before being committed.
- This gives manual endpoint edits the current combined legality pass: rigid weapon length, contact tether, max reach, and body clearance correction.
- Path-level Bezier collision is currently diagnostic-first: illegal sampled path segments are detected and reported, but full Bezier handle clamping/rejection remains a later pass.

Verification:

- `tools/verify_combat_animation_station_preview.gd`

Eighth implementation slice is implemented in code:

- Added `CombatAnimationRetargetNode` as an optional normalized motion-intent resource.
- `CombatAnimationMotionNode` can now carry an optional `retarget_node` while preserving the current absolute legacy tip/pommel endpoint fields.
- Added `CombatAnimationRetargetResolver` to convert a legacy absolute node into normalized grip/contact-pivot data.
- The retarget node stores pivot direction, legal-range percentage, pivot ratio, weapon axis, orientation, roll, grip slide, axial offset, stance state, primary-hand state, and normalized curve handles.
- Weapon orientation remains authored separately from the pivot location ray.
- Resolving a retarget node against a current weapon length derives new tip/pommel endpoints while keeping the authored pivot stable.
- Applying a retarget node updates the legacy endpoint fields for current systems and keeps the normalized intent attached for later shape-change work.

Verification:

- `tools/verify_combat_retarget_resolver.gd`

Ninth implementation slice is implemented in code:

- `CombatAnimationRetargetResolver` can now seed missing retarget nodes across a motion chain.
- The resolver can retarget a chain or draft against a current weapon length, preserving the authored grip/contact pivot and deriving new tip/pommel endpoints.
- The resolver can refresh retarget authoring snapshots from the current legacy endpoint fields before save.
- The Skill Crafter applies a non-persistent open-time retarget pass so old authored drafts preview against current weapon geometry.
- The Skill Crafter refreshes normalized retarget snapshots before saving, so intentional edits carry forward the current geometry truth.
- Missing retarget data is seeded from legacy absolute motion nodes, allowing old drafts to participate in the new shape-change path.
- Pivot ratio is derived from the current weapon geometry grip/contact position instead of assuming midpoint when station geometry is available.
- The preview retarget config falls back to geometry-only data when the preview actor/held item is not ready yet.

Verification:

- `tools/verify_combat_retarget_resolver.gd`
- `tools/verify_combat_idle_single_node_authority.gd`
- `tools/verify_combat_animation_station_preview.gd`
- `tools/verify_weapon_stow_positions.gd`
- `tools/verify_combat_speed_state_feedback.gd`

Tenth implementation slice is implemented in code:

- `CombatAnimationRetargetNode` now carries transition timing so normalized recipes preserve motion rhythm.
- Added `CombatAnimationPresetRecipe` as a normalized preset data resource.
- Added `CombatAnimationPresetResolver` as the preset-to-draft resolver.
- Added a deterministic built-in `Forward Cut` preset recipe stored as normalized retarget nodes, not fixed endpoint coordinates.
- Preset resolution creates a regular `CombatAnimationDraft` with legacy tip/pommel endpoints plus attached retarget nodes.
- Resolving the same preset onto different weapon lengths keeps grip/contact pivots stable while scaling the weapon segment.
- Preset resolution runs the draft validator and reports validation error counts instead of silently accepting invalid recipes.

Verification:

- `tools/verify_combat_preset_resolver.gd`
- `tools/verify_combat_retarget_resolver.gd`

Eleventh implementation slice is implemented in code:

- Added `CombatAnimationRuntimeChainCompiler` for runtime-effective motion-chain compilation.
- Runtime compilation duplicates authored motion nodes and does not mutate saved authoring data.
- Runtime compilation retargets the duplicate chain against the currently equipped weapon length.
- Runtime compilation seeds missing retarget nodes on the duplicate chain so legacy authored skills can still adapt at runtime.
- Runtime compilation degrades impossible explicit two-hand nodes to one-hand when the support hand is unavailable.
- Auto two-hand nodes resolve to one-hand when current equipment cannot support two-hand behavior.
- Compile diagnostics report deterministic reasons such as `two_hand_degraded_to_one_hand`.
- `PlayerRuntimeSkillPlaybackPresenter` now compiles the effective chain before building runtime entry bridges.
- Runtime playback debug state exposes compile diagnostics, degraded-node count, and retargeted-node count.

Verification:

- `tools/verify_combat_runtime_chain_compiler.gd`
- `tools/verify_player_runtime_skill_entry_recovery.gd`
- `tools/verify_player_runtime_skill_playback.gd`

Twelfth implementation slice is implemented in code:

- Runtime compilation now detects explicit authored `primary_hand_slot` changes between consecutive effective nodes.
- The compiler inserts generated `primary_hand_swap` bridge nodes into the runtime-effective chain.
- Generated hand-swap bridges hold weapon endpoints stable for a short bridge duration and switch primary-hand state intentionally.
- If two-hand support is available, the generated hand-swap bridge can pass through a two-hand state; otherwise it resolves to one-hand.
- Hand-swap bridge diagnostics are emitted as `primary_hand_swap_bridge_inserted`.
- Authored chains remain unchanged; only the duplicated runtime-effective chain receives generated hand-swap bridges.
- Runtime playback debug state exposes hand-swap bridge counts and entry/recovery hand-swap bridge flags separately from grip-swap flags.
- Combat idle primary-hand locking remains station-owned and separate from skill-node hand-swap behavior.

Verification:

- `tools/verify_combat_runtime_chain_compiler.gd`
- `tools/verify_player_runtime_skill_playback.gd`
- `tools/verify_player_runtime_skill_entry_recovery.gd`

Thirteenth implementation slice is implemented in code:

- The player rig now detects the available upperarm and forearm twist bones from the loaded skeleton.
- Authoring contact wrist solving measures the requested contact-frame twist before the wrist no-roll clamp is applied.
- The measured twist is distributed across the forearm and upperarm twist helper bones, rather than leaving the wrist mesh section to absorb the whole visual rotation.
- The existing contact hand-basis law remains intact: the hand still solves to the weapon/contact axis, and the no-roll wrist clamp remains the hand-joint safety layer.
- Twist distribution is cached from the active authoring preview baseline so repeated preview frames do not accumulate twist.
- Grip contact debug state now reports twist bone counts, requested twist, distributed forearm/upperarm twist, and applied helper-bone count.
- Normal/reverse grip bridge diagnostics still report the correct hand-Z relationship to the weapon tip.

Verification:

- `tools/verify_player_wrist_twist_distribution.gd`
- `tools/diagnose_grip_swap_hand_orientation.gd`
- `tools/verify_player_runtime_skill_playback.gd`

Fourteenth implementation slice is implemented in code:

- The Skill Crafter now builds a consolidated editor guardrail state from existing draft validation, preview collision legality, contact reach tethering, stance support, retarget distortion, and debug-view availability.
- Guardrail entries use stable severity/code/message data, so UI and verification can read the same warning truth.
- Collision guardrails report selected-pose and sampled-path body clearance problems.
- Reach guardrails report when contact reach exceeded the legal arm volume and was clamped.
- Stance guardrails report unsupported combinations such as reverse grip with requested two-hand support, or two-hand stance without a visible support contact guide.
- Retarget guardrails report seamless retarget info and warn when the current/source weapon length ratio is severe enough that the authored motion should be reviewed.
- Debug-view state now reports whether the editor has visible/available views for body clearance proxy, weapon clearance proxy, max reach boundary data, min clearance/path legality, normalized pivot path data, and speed-state coloring.
- The editor summary now shows guardrail status and compact debug-view availability without creating another authority path.

Verification:

- `tools/verify_combat_animation_station_preview.gd`

## New Authority Law

### Stage 1 / Forge

Stage 1 is geometry only.

It owns:

- weapon shape
- grip valid zone
- baked profile
- center of mass
- weapon length
- usable contact data
- upstream geometry truth for later systems

Stage 1 must not be final gameplay stance authority.

Existing WIP fields such as `grip_style_mode` and `stow_position_mode` are legacy/default seed fields until migrated. They should not remain the final truth for combat idle, skill stance, or noncombat stow once station data exists.

### Equipment Slot

Equipment slot decides dominant hand baseline.

- equipped right hand -> right dominant baseline
- equipped left hand -> left dominant baseline

This should feed the Skill Crafter open/setup path and runtime baseline truth.

### Combat Idle Editor

Combat idle is the drawn-weapon baseline.

It should be a single motion-node style pose.

It owns:

- normal vs reverse grip for drawn idle
- one-hand vs two-hand drawn idle stance
- drawn weapon pose

It does not own primary hand selection as an editable choice. Primary hand is derived from the equipped slot.

`T` should not delete the combat idle node. `R` should reset that single idle pose, not add structure.

### Skill Nodes

Skill motion nodes own per-node combat stance intent.

They should support:

- normal vs reverse grip
- one-hand vs two-hand
- primary hand slot when explicit hand-swap skills are supported

Do not remove `primary_hand_slot` from the motion node model. It is required for future hand swaps and large weapon platforms.

For now, combat idle primary hand should be locked from equipment slot even though skill nodes keep the field.

### Noncombat Idle / Stow Editor

Noncombat idle is separate from combat idle.

It should use a single-node motion-node style pose, plus stow selection and stow offset/orientation data.

It owns:

- stow anchor family
- stowed weapon position/orientation offset
- noncombat held/stowed presentation

Current code has 3 stow modes and left/right anchors, producing 6 actual anchor placements:

- shoulder hanging left/right
- side hip left/right
- lower back left/right

### Runtime Hidden Bridge Layer

The hidden bridge layer is the shadow middleman.

It handles:

- noncombat idle -> draw weapon -> combat idle
- combat idle -> skill entry
- mid-skill interrupt -> new skill entry
- skill finish -> combat idle recovery
- combat idle expiry -> stow weapon -> noncombat idle

Combat idle expiry is time-based.

Current GDD direction from `GDD-and Text Resources/UPLOADED/systems demo-1.txt`:

- after recovery enters combat idle, a timer starts
- default expiry to out-of-combat animation is `15.0s`
- value is a tunable float for testing
- new actions tagged `in_combat_when_used` refresh the combat action state

Return Scroll eligibility uses related but stricter calm gates and should not be confused with the animation expiry rule:

- not current #1 target of any enemy
- no hostile damage for `40.0s`
- no combat action for `15.0s`

The bridge layer may reuse the same runtime chain/player logic where possible, but it must not mutate saved authored data.

## Important Correction To Older TODOs

Older files correctly say that tip and pommel are authoring handles for the rigid weapon body.

Today refines that:

- In the current legacy implementation, motion nodes store tip/pommel as absolute local endpoint positions.
- In the future retargetable implementation, the grip/contact pivot should become the authored motion owner.
- Tip and pommel should become derived outputs from:
  - current weapon geometry
  - grip/contact pivot
  - weapon axis
  - roll
  - stance state
  - normalized legal motion volume position

This is required so later Stage 1 / Stage 2 weapon shape changes do not destroy authored skill work.

## Implementation Order

### 1. Authority Cleanup Before More Solver Work

Goal:
Remove stale or duplicated authority before chasing symptoms.

Tasks:

- Demote Stage 1 WIP `grip_style_mode` and `stow_position_mode` to legacy/default seed roles.
- Stop treating Stage 1 grip/stow choices as final runtime truth when station idle/stow data exists.
- Disable or hide obsolete Stage 1 stance/stow controls so they cannot write residual state or interfere with station truth.
- Do not keep intentionally obsolete controls as usable "nope" panels.
- Make combat idle primary hand derive from equipped slot.
- Disable or hide primary-hand editing for combat idle.
- Preserve primary-hand editing for future skill hand-swap nodes.
- Verify idle reset no longer receives mixed authority from Stage 1 defaults and station node state.

Done when:

- Opening the Skill Crafter makes it clear which layer owns stance.
- Combat idle stance is owned by combat idle data.
- Equipped slot owns dominant hand.
- Stage 1 owns geometry only.
- Obsolete UI cannot push stale stance/stow data.

### 2. Combat Idle Single-Node Lock

Goal:
Make combat idle a stable drawn baseline.

Tasks:

- Enforce combat idle as a single motion node.
- Prevent `T` from deleting the combat idle node.
- Make `R` reset the combat idle pose instead of adding node structure.
- Keep editable controls for:
  - grip style
  - one-hand vs two-hand
  - weapon position/orientation
  - relevant roll/slide/axial/body support values
- Lock primary hand from equipped slot.
- Verify reset stability using the earlier vibration reproduction path.

Done when:

- Combat idle is stable, repeatable, and has no accidental timeline structure.
- Reset produces a legal drawn rest pose without shaking.

### 3. Noncombat Idle / Stow Authoring Mode

Goal:
Move stow truth out of Stage 1 and into the station.

Tasks:

- Add noncombat idle/stow as a station idle context.
- Author it as single-node style data.
- Support the 3 stow mode families with left/right anchor resolution.
- Add position/orientation offset authoring relative to the selected anchor.
- Keep old WIP `stow_position_mode` as migration/default seed only.
- Runtime should use station noncombat stow data when present.

Done when:

- A player can author where the weapon sits when not drawn.
- Stage 1 no longer looks like the place where final stow presentation is decided.

### 4. Runtime Draw/Stow Bridge Reuse

Goal:
Use the hidden bridge system for state changes around combat readiness.

Tasks:

- Extend runtime hidden bridge usage to:
  - noncombat idle -> combat idle draw
  - combat idle -> noncombat idle stow
- Add time-based combat idle expiry:
  - default `15.0s`
  - starts after recovery has entered combat idle
  - refreshed by new `in_combat_when_used` actions
  - uses the stow bridge to return to noncombat idle
- Preserve existing skill entry and recovery bridge behavior.
- Keep authored idle/skill data untouched.

Done when:

- Draw, skill entry, skill recovery, and stow all feel like connected motion instead of snaps.

### 5. Slowdown/Reset And Speed-State Feedback

Goal:
Preserve the original melee law and expose readable editor feedback before hitbox logic depends on it.

Tasks:

- Keep slowdown/reset band behavior as hard law around motion-node destinations, except startup/entry.
- Expose temporary editor adjusters for acceleration/deceleration as percentage values.
- Treat those percentage values as tuning knobs until good constants are found.
- Once values are proven, hardcode/hide them as combat constants.
- Add speed-state trajectory coloring as editor feedback:
  - green: low-speed / reset / non-armed
  - red: armed strike threshold or higher
  - gradient: buildup / decay
- Base coloring on sampled Bezier/trajectory motion, not only node endpoints.
- Preserve this sampled speed-state data path as the later basis for hitbox/armed-state logic.

Done when:

- The editor shows where motion is startup, reset, buildup, and armed.
- Tuning acceleration/deceleration percentages changes the displayed speed-state path.
- The data path can later feed hitbox activation instead of being a throwaway visual.

### 6. Mesh-Inspired Clearance Proxy Foundation

Goal:
Create adaptable clearance shapes for body and weapon before implementing minimum motion volume.

Tasks:

- Build a body clearance proxy generator from the loaded character model.
- Use stable bone names as the attachment/measurement contract so later player models can vary.
- Derive the first real proxy shapes from the loaded mesh/body geometry, not hand-authored placeholder capsules.
- Attach or associate generated proxy regions through the stable bone-name contract so future player models can regenerate equivalent clearance.
- Allow simplified convex-ish regions where needed for performance, but the source of truth should remain mesh-derived and adaptable.
- Generate or configure proxies for:
  - torso
  - head
  - upper arms
  - forearms
  - hands
  - thighs/legs if needed for weapon/body legality
- Inflate body proxy outward by a clearance amount, target default `0.005m`.
- Build a weapon clearance proxy from Stage 2 baked/editable weapon geometry.
- Inflate weapon proxy outward by a clearance amount, target default `0.005m`.
- Add debug visualization toggles for both proxy families.

Done when:

- The current placeholder character produces usable body clearance proxies.
- The system can regenerate proxies for a future character model with the same bone naming contract.
- The currently baked weapon can produce a weapon proxy from geometry truth.

### 7. Collision Legality Solver

Goal:
Use body and weapon proxies to detect and prevent body crush / weapon clipping.

Tasks:

- Implement pose-level weapon proxy vs body proxy legality checks.
- Implement path-level sampled checks along Bezier/trajectory playback.
- Return stable legality data:
  - legal
  - colliding body region
  - penetration/clearance estimate where practical
  - suggested correction direction where practical
- Clamp invalid poses to the nearest stable legal position when deterministic correction is available.
- Reject invalid poses when a stable clamp cannot be determined.
- Keep diagnostics visible so the player understands why motion was constrained or rejected.
- Prefer deterministic behavior over visually clever behavior in first pass.

Done when:

- The editor can identify that a weapon pose/path enters the body clearance zone.
- The solver exposes enough information to build minimum range volume behavior.
- Illegal motion is clamped or rejected instead of silently accepted.

### 8. Minimum Motion Volume / No Shortcut / No Body Crush

Goal:
Complete the legal motion volume by adding inner constraints.

Tasks:

- Integrate collision legality with the existing trajectory volume resolver.
- Current max reach volume remains the outer boundary.
- New collision/body clearance forms the inner invalid region.
- Treat legal space as the area between:
  - outer max reach
  - inner body/weapon clearance limits
- Clamp or project proposed grip/contact pivot paths into legal space.
- Ensure Bezier handles and generated bridges respect legal space.
- Reject authored path edits that cannot be clamped into legal space cleanly.

Done when:

- The system prevents illegal shortcuts through the body.
- The trajectory path remains inside legal motion space.
- Max reach and minimum clearance are solved together.

### 9. Parametric Retarget Data Model

Goal:
Make skill motion survive later weapon geometry changes.

Tasks:

- Add a retargetable motion-node representation while preserving current absolute legacy nodes.
- Store grip/contact pivot as the main authored control point.
- Store pivot position as normalized legal-space data:
  - direction/ray from the primary-side clavicle/shoulder origin
  - measured in a stable torso/root frame
  - percent along legal range, `0.0` to `1.0`
- Do not derive weapon orientation from the location ray.
- Store weapon axis/orientation intent separately from endpoint coordinates and separately from normalized location.
- Store orientation relative to a stable body frame, then apply grip state, normal/reverse state, axial offset, grip slide, and authored roll.
- Store roll, stance, timing, grip slide, axial offset, body support, and relevant curve data.
- Store curve handles as normalized offsets relative to legal motion volume, not fixed meters.
- Build converter:
  - legacy absolute node -> normalized retarget node
- Build resolver:
  - normalized retarget node + current weapon geometry + current character volume -> actual tip/pommel endpoints

Done when:

- A saved skill can be represented as motion intent rather than fixed old endpoint coordinates.

### 10. Retarget Existing Skills After Shape Change

Goal:
Protect player-authored work when Stage 1 / Stage 2 shape changes later.

Tasks:

- Detect when current weapon geometry differs meaningfully from the geometry used to author the draft.
- Re-resolve normalized motion nodes against the new weapon geometry.
- Preserve:
  - grip/contact pivot intent
  - path shape intent
  - roll
  - stance
  - timing
- Derive new tip/pommel from current weapon length, grip ratio, and axis.
- Retarget automatically on open/save/load/update paths where weapon geometry has changed.
- Keep retargeting seamless for normal cases so the player does not need to manage valid-position maintenance manually.
- Keep diagnostics for severe changes, but do not require manual confirmation for normal beneficial retargeting.

Done when:

- Making the weapon much longer or shorter does not automatically destroy skill authoring.
- The editor adapts old motion to the new weapon automatically and keeps resulting positions valid.

### 11. Retarget-Aware Preset Skills

Goal:
Allow useful prebuilt skills after the motion system becomes shape-independent.

Tasks:

- Store presets as normalized motion recipes, not fixed sword coordinates.
- Preset data should include:
  - grip/contact pivot path
  - stance changes
  - axis/orientation intent
  - roll
  - timing
  - legal-space percentages
- Resolve presets onto the current weapon and character.
- Add validation so presets cannot create illegal body/weapon paths silently.

Done when:

- A dagger, sword, spear, or unusual player-made weapon can use the same preset recipe and get a legal adapted path.

### 12. Runtime Equipment Legality Compilation

Goal:
Compile a playable chain from authored truth without rewriting saved authoring data.

Tasks:

- On equipment change, compile a runtime-effective chain.
- Skip, bridge, or degrade illegal nodes instead of mutating the saved draft.
- Preserve legal parts of a skill where possible.
- If two-hand nodes are impossible because another weapon occupies the support hand, bridge or skip only those nodes.
- Keep deterministic diagnostics for why a node was filtered.

Done when:

- Runtime equipment changes do not corrupt skill authoring.
- A skill can degrade predictably if the current equipment setup cannot support every node.

### 13. Hand Swap Skills And Large Weapon Platforms

Goal:
Support explicit primary-hand swaps without breaking combat idle baseline rules.

Tasks:

- Keep `primary_hand_slot` active for skill nodes.
- Treat primary hand swaps as authored stance changes.
- Prefer passing through a brief two-hand bridge where visually required.
- Build generated hand-swap bridge logic similar in spirit to grip-swap bridges.
- Ensure large weapons can intentionally swap dominant hand or support hand roles.

Done when:

- Hand swaps are authored deliberately in skills.
- Combat idle still derives primary hand from equipment slot.

### 14. Wrist Twist / Twist Bone Distribution Pass

Goal:
Remove plastic-bag wrist/forearm twist artifacts.

Tasks:

- Audit current wrist, forearm, hand, and weapon-contact basis agreement.
- Use twist bones where available:
  - upperarm twist
  - forearm twist
- Distribute roll/twist along the limb instead of dumping it into the wrist mesh section.
- Respect the joint range notes in `the thing i figured out.md`.
- Verify both normal and reverse grip.

Done when:

- Wrist/forearm deformation remains visually plausible while weapon contact stays correct.

### 15. Editor Validation And User Guardrails

Goal:
Make the deep system usable instead of punishing.

Tasks:

- Add clear validation for illegal motion.
- Show warnings for:
  - collision with body proxy
  - overreach
  - severe retarget distortion
  - unsupported stance/equipment state
- Keep legal-but-bad authoring possible where safe, but make risk visible.
- Provide debug views for:
  - body clearance proxy
  - weapon clearance proxy
  - max reach boundary
  - min clearance boundary
  - normalized pivot path

Done when:

- Players can author creatively while the editor explains legality problems.

## Original Combat Editor Intent Recovered

The older four combat-editor files were reread on 2026-04-30 and compacted into:

- `GDD-and Text Resources/ToDo stuff/Combat Editor Original Intent Digest 2026-04-30.md`

Recovered rules that remain valid:

- The editor is runtime, weapon-owned, and skill-slot aware.
- The authored data must save back into the owning weapon and restore later.
- Motion nodes are the hard authored combat structure.
- Bezier handles / control vectors are the between-node freedom layer.
- Bezier data is gameplay-relevant sampled motion data, not decoration.
- Preview playback must not mutate saved draft data.
- The playback layer must remain reusable for editor preview, runtime execution, and later looped skill presentation / inspection / trading views.
- The first transition into the first motion node is startup/entry positioning and should not count as a hit.
- Later node-to-node segments are potential strike phases.
- Destination nodes should support slowdown/reset band metadata.
- Trajectory visualization should include speed-state coloring as editor feedback:
  - green: low-speed / reset / non-armed
  - red: armed strike threshold or higher
  - gradient: buildup / decay
- Stage 1 still feeds weapon build truth such as geometry, material, center of mass, mass distribution, grip data, class/profile, and handling values.
- Stage 1 does not own combat idle stance, skill stance, or final stow authoring truth.

Implementation additions from this reread:

- Keep Bezier handle data and slowdown/reset metadata visible in the model while authority cleanup happens.
- Validate sampled Bezier path positions against legal volume, not only motion node endpoints.
- Track speed-state coloring as a required editor feedback layer now, using the same sampled data path that later feeds armed-state/hitbox logic.
- Track reusable looped skill presentation as a playback architecture requirement, even if the UI is later.
- Keep slot-law hit economy compatibility in the data model, even before final damage logic exists.

## Older TODO Reconciliation

### Still Valid From Older TODOs

- Stabilize editor authority before adding feature layers.
- Preserve authored truth; runtime compiles effective chains.
- Do not let runtime legality silently rewrite saved drafts.
- Motion nodes are the authored unit.
- Weapon-owned skill drafts remain the current ownership model.
- Preview and runtime should share the same general playback architecture.
- Two-hand tethering, grip swaps, and hand swaps need explicit bridge behavior.
- Body collision and weapon/body legality are required.

### Superseded Or Refined

- Older phrase: Stage 1 is geometry/combat truth.
  - Current wording: Stage 1 is geometry truth only. Combat stance/stow truth moves to the Skill Crafter station and equipment state.
- Older phrase: tip and pommel are authoring handles for the rigid weapon body.
  - Current wording: tip/pommel remain legacy/display handles, but retargetable authoring should be grip/contact-pivot owned.
- Older weapon-open grip/stow choices were useful while the Skill Crafter did not exist.
  - Current wording: those fields become defaults/migration seeds, not final stance or stow authority.

## Locked Decisions From 2026-04-30

1. Obsolete UI must not remain usable. If a control is intentionally obsolete, disable or hide it so it cannot write residual state.
2. Clearance proxies should be mesh-derived from loaded character/weapon geometry, with stable bone names used as the adaptation contract for future player models.
3. Collision legality should clamp when the correction is stable and deterministic, and reject when it is not.
4. Slowdown/reset bands remain hard melee law near motion-node destinations, except startup/entry.
5. Acceleration/deceleration should be exposed temporarily as percentage tuning values in the editor, then hardcoded/hidden after good constants are found.
6. Speed-state coloring is editor feedback now and later becomes a basis for armed-state/hitbox logic.
7. Retargeting after weapon shape changes should be automatic and seamless in normal cases.
8. Normalized motion location should use the primary-side clavicle/shoulder as the anatomical origin, measured in a stable torso/root frame.
9. Weapon orientation should not be projected from the location ray. Orientation is authored/stored separately relative to a stable body frame and then resolved through grip state, axial offset, slide, and roll.
10. Combat idle expiry to noncombat idle is time-based, default `15.0s`, refreshed by combat-tagged actions, and uses the stow bridge.

## Remaining Non-Blocking Questions

Future refinements still open:

1. Whether active plane editing remains a direct movement tool in the normalized-volume future, or becomes a helper/gizmo around normalized placement.
2. Whether looped skill presentation/trading view gets its own UI pass or is folded into the playback architecture pass.
3. Whether slot-law hit economy should be stored as placeholder draft metadata before final damage logic exists.

## Immediate Recommended Next Slice

The 2026-04-30 unified TODO is implemented through item 15.

Recommended next work should be chosen from fresh testing feedback rather than this TODO file. Likely candidates are:

1. Player-facing polish on the Skill Crafter guardrail UI if the compact summary is not readable enough in live use.
2. Fine tuning twist distribution ratios after visual inspection in normal, reverse, and hand-swap-heavy poses.
3. Moving from diagnostic-first Bezier path legality to full handle clamp/reject behavior where the current guardrails identify bad paths.
