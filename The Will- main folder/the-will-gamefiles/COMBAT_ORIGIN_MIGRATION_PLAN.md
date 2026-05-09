# Combat Origin Migration Plan

Status: planning and audit reference.

Companion law file: `COMBAT_COORDINATE_LAW.md`.

This document records the current combat coordinate reality and the staged plan for
moving the project to explicit `CombatOrigin` / `origin_id` authority. It is not a
replacement for the law file. The law defines the rules; this file maps the current
systems and the order of conversion.

No game code is changed by this document.

## Goal

Make every combat-authored local space traceable back to one machine origin:

```text
RL_BoneRoot
```

The important rule is not that every node must be parented under `RL_BoneRoot`.
The important rule is that every local zero must be named and resolvable through a
full `Transform3D` chain back to `RL_BoneRoot`.

In CNC language:

```text
RL_BoneRoot = machine coordinate system
CombatOrigin = named work offset
local values = operation-space values inside a named work offset
```

## Godot Transform Basis

Use Godot's `Transform3D` as the stored frame type for origins.

Official Godot references:

- `Transform3D`: https://docs.godotengine.org/en/4.6/classes/class_transform3d.html
- `Node3D`: https://docs.godotengine.org/en/4.6/classes/class_node3d.html
- `Skeleton3D`: https://docs.godotengine.org/en/4.6/classes/class_skeleton3d.html
- `SkeletonModifier3D`: https://docs.godotengine.org/en/4.6/classes/class_skeletonmodifier3d.html

Important Godot facts for this project:

- `Transform3D` stores basis plus origin, meaning orientation/scale plus position.
- `Node3D.transform` is parent-space; `Node3D.global_transform` is world-space.
- `Skeleton3D.get_bone_global_pose()` returns a bone transform relative to the
  `Skeleton3D`, not true world space.
- Bone world transform must be resolved as:

```gdscript
var bone_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
var bone_world: Transform3D = skeleton.global_transform * bone_pose
```

- `SkeletonModifier3D` runs after animation mixer playback, so resolve phase matters.
  Two systems reading the same bone name at different phases may be reading different
  poses.

## Current Coordinate Reality

The current code already uses `RL_BoneRoot` in the most important places:

- Skill crafter preview uses `PREVIEW_ROOT_BONE = &"RL_BoneRoot"`.
- Runtime solved replay uses `RUNTIME_SOLVED_REPLAY_REFERENCE_BONE = &"RL_BoneRoot"`.
- `CombatRuntimeClip` stores `solved_replay_reference_bone_name`, defaulting to
  `RL_BoneRoot`.
- Solved replay exports full upper body pose positions, rotations, and scales, plus
  weapon transform in reference-local space.

The current issue is that many local spaces are still only implied by naming or scene
parentage. They work by convention, not by declared authority.

Examples of current convention-based locals:

- `tip_position_local`
- `pommel_position_local`
- `origin_local`
- `baked_tip_positions_local`
- `baked_pommel_positions_local`
- `baked_contact_grip_axes_local`
- `baked_solved_weapon_positions_reference_local`
- `baked_solved_anchor_positions_weapon_local`
- `weapon_tip_local`
- `weapon_pommel_local`
- `primary_grip_contact_local`
- `support_grip_contact_local`
- `station_stow_requested_tip_position_local`
- `station_stow_requested_pommel_position_local`

These are not automatically wrong. They become wrong when the origin is anonymous.

## Current Origin Inventory

This is the current combat-relevant origin map. Names here are proposed stable
`origin_id` values for migration.

| Proposed origin_id | Current owner/data | Parent chain | Phase | Static/dynamic | Notes |
| --- | --- | --- | --- | --- | --- |
| `RL_BoneRoot` | `PREVIEW_ROOT_BONE`, `RUNTIME_SOLVED_REPLAY_REFERENCE_BONE`, `CombatRuntimeClip.SOLVED_REPLAY_REFERENCE_BONE_NAME` | machine origin | all combat phases | dynamic bone frame | The one true combat machine coordinate system. |
| `TrajectoryAuthoringOrigin` | skill crafter `TrajectoryRoot`; motion node tip/pommel locals; runtime baked tip/pommel locals | `TrajectoryAuthoringOrigin -> RL_BoneRoot` | `EDITOR_PREVIEW`, `BAKE_TIME`, runtime clip sample | dynamic per actor pose | Currently implied by `_resolve_trajectory_authoring_transform()`. Needs explicit `origin_id`. |
| `SolvedReplayReferenceOrigin` | `solved_replay_reference_bone_name` | usually identity to `RL_BoneRoot` | `BAKE_TIME`, `POST_COMBAT_MODIFIER` | dynamic bone frame | Existing reference field is good, but should become an origin record instead of just a bone name. |
| `WeaponRootOrigin` | held item root; `weapon_tip_local`, `weapon_pommel_local`; baked weapon transform reference-local | `WeaponRootOrigin -> SolvedReplayReferenceOrigin -> RL_BoneRoot` during replay | forge/runtime/editor | dynamic | Weapon-local geometry is valid, but should declare weapon root as origin. |
| `PrimaryGripAnchorOrigin` | `PrimaryGripAnchor`, `PrimaryGripGuide`, primary anchor capture arrays | `PrimaryGripAnchorOrigin -> WeaponRootOrigin -> RL_BoneRoot` | editor/runtime/replay | mostly static inside weapon | Primary hand contact target on the weapon. |
| `SupportGripAnchorOrigin` | `SupportGripAnchor`, `SecondaryGripGuide`, support anchor capture arrays | `SupportGripAnchorOrigin -> WeaponRootOrigin -> RL_BoneRoot` | editor/runtime/replay | mostly static inside weapon | Support hand contact target on the weapon. |
| `HandGripAlignmentOrigin` | hand item anchors, derived finger contact center, `resolve_hand_grip_alignment_world_position()` | hand/finger bones -> `RL_BoneRoot` | `POST_FINAL_POSE` | dynamic | This is the derived anatomical mate point, not simply the hand bone. |
| `PrimaryShoulderOrigin` | trajectory volume `origin_local`; retarget `origin_space = primary_shoulder` | shoulder/clavicle bone -> `RL_BoneRoot` | editor preview, runtime trajectory volume | dynamic | Highest-risk anonymous origin today because `origin_local` can fall back to `Vector3.ZERO`. |
| `BridgeStartOrigin` | runtime solved replay bridge snapshot; current pose and current weapon capture | `BridgeStartOrigin -> RL_BoneRoot` | `RUNTIME_BRIDGE` | dynamic snapshot | Start side of skill entry, interrupt, or recovery bridge. |
| `BridgeTargetOrigin` | target clip first solved frame or combat idle target | `BridgeTargetOrigin -> RL_BoneRoot` | `RUNTIME_BRIDGE` | dynamic target frame | Target side of bridge. Must not silently change coordinate basis. |
| `CombatIdleOrigin` | combat idle runtime clip, idle chain player solved replay data | `CombatIdleOrigin -> RL_BoneRoot` | `BAKE_TIME`, runtime idle | dynamic clip frame | Must have same solved-data standard as skills. |
| `NonCombatStowOrigin` | noncombat idle draft stow motion node | `NonCombatStowOrigin -> StowAnchorOrigin -> RL_BoneRoot` | `RUNTIME_STOW` | configured/dynamic | Allowed to keep weapon off hand. This is intentionally different from combat grip. |
| `StowAnchorOrigin` | shoulder/hip/lower-back stow anchors | stow bone attachment -> `RL_BoneRoot` | stow/reanchor | dynamic actor pose | Current stow solve uses stow anchor position and usually `RL_BoneRoot` basis. Needs explicit chain. |
| `BodyRestrictionAttachmentOrigin` | body restriction attachments synced from skeleton bone poses | restriction attachment -> source bone -> `RL_BoneRoot` | `POST_FINAL_POSE` | dynamic | Collision/debug body proxies should state which bone-origin they follow. |
| `RuntimeEndpointAuthorityRoot` | `RuntimeCombatEndpointAuthorityRoot` reparent target | scene convenience only | runtime weapon ownership | dynamic parent node | Must not be treated as coordinate authority unless registered as an origin transition. |

## Current Double-Authority Risk Map

These are the areas most likely to produce editor/runtime mismatch.

| Risk | Current behavior | Why it matters | Migration decision |
| --- | --- | --- | --- |
| Solved replay weapon vs bridge anchor lock | Runtime applies weapon from `RL_BoneRoot`, then bridge frames may translate the weapon to match the live hand target. | Contact can look correct while the authored weapon/body pose no longer matches editor replay. | Bridge correction must become a named bridge writer with origin/phase, or be disabled during pure replay comparison. |
| Solved replay full body vs legacy rotation-only body path | Full solved replay applies positions, rotations, scales. Legacy fallback applies rotations only. | Same body target can be authored through two different authority levels. | Solved replay is primary. Legacy path must be fenced as fallback only and labeled. |
| Solved replay vs runtime endpoint fallback | Fallback endpoint solve writes `held_item.global_transform`; reseat path can also write `held_item.global_transform`. | Missing solved frames can swap authority mid-playback. | All weapon writers must declare target, origin, and phase. |
| Stow solve vs reanchor/hand mount | Reanchor moves weapon under hand/stow anchors; stow solve computes world transform from stow motion node data. | Parent changes can look like authority changes. | Scene parent changes remain presentation only; stow origin chain owns the authored stow pose. |
| Trajectory volume anonymous origin | `origin_local` is stored without `origin_id`; retarget fallback can use `Vector3.ZERO`. | Retargeting can reinterpret local zero as shoulder, trajectory, or machine space. | `origin_local` must become a named origin transform, not a loose vector. |
| Runtime IK/finger modifiers | Finger grip and IK systems solve from dynamic hand/finger targets after locomotion. | Same hand anchor can mean different positions before/after modifiers. | All hand-derived origins require resolve phase. |
| Body restriction sync vs mesh/bones | Body restriction proxies sync from skeleton poses. | Debug/collision shapes only mean something if sampled at the same final pose phase. | Body restriction origins are dynamic post-final-pose origins. |

## Staged Migration Chain

### Stage 0: Documentation And Audit Only

Goal: create the map before changing behavior.

Actions:

- Keep this file and `COMBAT_COORDINATE_LAW.md` as the current source of truth.
- Do not change gameplay code in this stage.
- Keep adding newly discovered origins and double-authority risks here until the map is stable.

Exit criteria:

- Every known combat-authored local field is assigned a proposed origin.
- Every current writer to upper-body pose or weapon transform is assigned an authority phase.

### Stage 1: Passive CombatOrigin Registry

Goal: introduce the origin system without changing runtime behavior.

Future implementation:

- Add a `CombatOriginRecord` model.
- Add a registry/resolver that can register origins and resolve a chain to
  `RL_BoneRoot`.
- Add diagnostics only. Do not block old data yet.
- Register the existing `RL_BoneRoot`, trajectory, weapon root, anchors, hand grip,
  shoulder, bridge, idle, stow, and body restriction origins.

Exit criteria:

- Runtime and editor can report the active origin chain for a sampled frame.
- No gameplay positioning changes are expected.

### Stage 2: Annotate Authored Resources

Goal: make saved data declare its origin.

Future implementation:

- Add origin metadata to motion node tip/pommel data and curve handles.
- Add origin metadata to runtime clip baked tip/pommel/contact axis data.
- Add origin metadata to solved replay weapon and anchor tracks.
- Add origin metadata to retarget and trajectory volume data.
- Add origin metadata to stow motion node usage and stow anchor data.
- Backfill old resources through schema/normalize logic with explicit defaults.

Default backfill policy:

```text
motion_node.tip_position_local -> TrajectoryAuthoringOrigin
motion_node.pommel_position_local -> TrajectoryAuthoringOrigin
baked_tip_positions_local -> TrajectoryAuthoringOrigin
baked_pommel_positions_local -> TrajectoryAuthoringOrigin
baked_contact_grip_axes_local -> TrajectoryAuthoringOrigin
origin_local for trajectory volume -> PrimaryShoulderOrigin relative to TrajectoryAuthoringOrigin
solved replay weapon reference-local -> SolvedReplayReferenceOrigin
solved replay anchor weapon-local -> WeaponRootOrigin
weapon_tip_local / weapon_pommel_local -> WeaponRootOrigin
station stow locals -> NonCombatStowOrigin / StowAnchorOrigin
```

Exit criteria:

- New authored combat data carries origin identifiers.
- Old data can still load, but warnings identify backfilled origin assumptions.

### Stage 3: Convert Editor Bake And Export

Goal: make skill crafter output explicitly origin-aware.

Future implementation:

- Bake F playback solved upper-body pose and weapon transform with declared origin IDs.
- Store the reference origin as an origin record, not only a bone name.
- Store anchor captures as weapon-root-local with `WeaponRootOrigin`.
- Export combat idle with the same solved replay standard as skills.
- Export noncombat stow as a stow-origin pose, not a combat hand-grip pose.
- Ensure trajectory volume and retarget use named origins instead of anonymous
  `origin_local`.

Exit criteria:

- Skill and combat idle clips can be inspected frame-by-frame relative to
  `RL_BoneRoot`.
- Editor F playback and exported runtime clip report the same origin chain.

### Stage 4: Convert Runtime Replay And Bridge

Goal: make runtime play already-solved editor data and make bridge work explicit.

Future implementation:

- Solved replay uses `CombatOrigin` chain resolution for upper body and weapon data.
- Bridge creates named `BridgeStartOrigin` and `BridgeTargetOrigin`.
- Bridge interpolation resolves both sides through `RL_BoneRoot`.
- Bridge anchor lock is either removed for pure solved replay frames or registered as
  an explicit `RUNTIME_BRIDGE` writer with diagnostics.
- Runtime endpoint root remains a parent/ownership convenience, not coordinate truth.

Exit criteria:

- During solved replay frames, no silent post-replay weapon translation occurs.
- During bridge frames, every correction reports source origin, target origin, and
  writer phase.

### Stage 5: Retire Or Fence Legacy Solvers

Goal: remove hidden double-authoring while preserving fallback safety.

Future implementation:

- Full solved replay is primary for skills and combat idle.
- Rotation-only upper-body playback is allowed only when solved replay is unavailable
  and must be labeled as legacy fallback.
- Runtime weapon endpoint solve and reseat are allowed only in declared fallback or
  bridge phases.
- Direct authoring solver mode must not compete with solved replay frames.

Exit criteria:

- No frame has two unregistered writers for the same upper-body pose or weapon
  transform.
- Any fallback path emits a clear diagnostic with the reason solved replay was not
  used.

### Stage 6: Verification And Live Comparison

Goal: prove editor and runtime are aligned.

Verification scenarios:

- Static audit: no combat-authored `local` fields without `origin_id`.
- Unit checks: origin chains resolve to `RL_BoneRoot`.
- Unit checks: identity or zero fallback requires explicit `RL_BoneRoot`.
- Bake checks: skill clips and combat idle clips include solved upper-body pose,
  weapon transform, anchor data, and origin IDs.
- Replay checks: editor F playback and runtime skill playback sample the same upper
  body bones, weapon transform, and grip anchors relative to `RL_BoneRoot`.
- Bridge checks: skill-to-skill, skill-to-combat-idle, combat-idle-to-stow, and
  interruption bridges preserve declared origin chains.
- Visual/live check: run 30 seconds total:

```text
0s-5s: idle buffer
5s: press skill 2
10s: press skill 1
10s-30s: continue sampling until test end
```

Sample:

- mesh pose
- runtime bone debug pose
- collision/body restriction markers
- weapon root
- primary grip anchor
- support grip anchor
- anatomical hand grip alignment point
- active origin chain
- active writer phase

Exit criteria:

- Combat idle and skill runtime playback match editor-authored solved data relative to
  `RL_BoneRoot`.
- Noncombat idle keeps weapon stowed and does not require hand grip contact.
- Bridge frames explain any intentional deviation from pure solved replay.

## Future CombatOrigin Interface

Conceptual record:

```gdscript
class_name CombatOriginRecord

var origin_id: StringName
var parent_origin_id: StringName
var transform_to_parent: Transform3D
var resolved_transform_to_machine: Transform3D
var owner_system: StringName
var resolve_phase: StringName
var space_type: StringName
var is_dynamic: bool
```

Required semantics:

- `origin_id` is stable and named.
- `parent_origin_id` is empty only for `RL_BoneRoot`.
- `transform_to_parent` is full `Transform3D`, not just position.
- `resolved_transform_to_machine` is the resolved transform to `RL_BoneRoot`.
- `owner_system` names who produced the origin.
- `resolve_phase` names when the origin is valid.
- `space_type` distinguishes bone, weapon, trajectory, bridge, stow, IK, collision,
  or presentation space.
- `is_dynamic` is true when the origin must be recomputed per frame or sample.

## Field Rules

After migration:

- Any field named `local` must declare its `origin_id`.
- Any missing `origin_id` is invalid.
- `Vector3.ZERO` is valid only as a real zero inside an explicit origin.
- Anonymous `Vector3.ZERO` fallback is invalid.
- Scene parentage is allowed for convenience, but never proves authority.
- A runtime writer must declare target transform, origin chain, and phase.

## Immediate Next Coding Target After This Doc

The safest first implementation stage is passive diagnostics:

1. Add `CombatOriginRecord` and a lightweight registry.
2. Register the current known origins without changing behavior.
3. Add debug output that prints active origin chains during editor preview and runtime
   solved replay.
4. Add static audit tools that find combat-authored `local` fields without an
   adjacent or containing `origin_id`.

Do not begin by deleting solvers. First make every writer visible.

## Open Questions For Later Audit

- Which old saved runtime clips are missing solved replay tracks or have stale solved
  replay data?
- Does every combat idle clip currently bake the same solved replay fields as skills?
- Which runtime bridge frames are intentionally corrected by hand lock, and which are
  accidental drift?
- Which `Vector3.ZERO` fallbacks are true mathematical zeros, and which are missing
  data placeholders?
- Which finger/IK modifier outputs should be represented as origins versus only
  final-pose consumers?

These questions should be answered with diagnostics before behavior changes.
