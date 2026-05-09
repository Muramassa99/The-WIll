# The Will Combat Coordinate Law

This file is the authority reference for combat-authored coordinate systems in The Will.

## Core Law

RL_BoneRoot is the Machine Coordinate System for all combat-authored motion.

Subsystems may define their own local zeros, equivalent to CNC work offsets.

Every local zero must be registered as a named CombatOrigin and must resolve through a transform chain back to RL_BoneRoot.

No authored combat transform may be saved as anonymous local data.

Any field named `local` must also declare its `origin_id`.

Any missing `origin_id` is invalid.

Any fallback to `Vector3.ZERO` is invalid unless the `origin_id` is explicitly `RL_BoneRoot`.

Scene parentage is allowed for convenience, but scene parentage is not authority.

Authority comes from the registered origin chain.

## Coordinate Model

Use this model:

```text
RL_BoneRoot = Machine Coordinate System
Combat/editor/IK/grip/trajectory origins = Work Coordinate Systems
Subsystem local spaces = local operation spaces owned by named origins
```

The goal is not to remove local origins. The goal is to remove anonymous local origins.

Valid:

```text
tip_position_local
origin_id = TrajectoryAuthoringOrigin

TrajectoryAuthoringOrigin
parent_origin_id = RL_BoneRoot
transform_to_parent = full Transform3D
```

Invalid:

```text
tip_position_local = Vector3(...)
```

because nobody knows which zero the value belongs to.

## Required CombatOrigin Record

Every combat work origin should be represented conceptually as:

```gdscript
class_name CombatOriginRecord

var origin_id: StringName
var parent_origin_id: StringName
var transform_to_parent: Transform3D
var resolved_transform_to_machine: Transform3D
var owner_system: StringName
var is_dynamic: bool
var resolve_phase: StringName
```

The transform must include position and basis. Position alone is not enough.

## Origin Chain Rule

Every authored combat point or transform must be traceable:

```text
local point or transform
-> named CombatOrigin
-> parent CombatOrigin(s)
-> RL_BoneRoot
-> Skeleton3D
-> rig/world presentation
```

Scene parentage can help place nodes, but it does not prove authority.

## Common Origins

The exact names may change, but this is the intended shape:

```text
RL_BoneRoot
    TrajectoryAuthoringOrigin
        motion node tip/pommel locals

    PrimaryShoulderOrigin
        trajectory volume origin

    RightHandGripOrigin
        right hand IK/contact targets

    LeftHandGripOrigin
        support hand IK/contact targets

    WeaponRuntimeRootOrigin
        solved weapon transform
        PrimaryGripAnchorOrigin
        SupportGripAnchorOrigin

    CombatIdleOrigin
        combat idle solved pose

    BridgeOrigin
        transition and interrupt frames

    StowAnchorOrigin
        noncombat stowed weapon placement
```

## Static And Dynamic Origins

Static origins are authored or configured once:

```text
TrajectoryAuthoringOrigin
WeaponPrimaryGripAnchorOrigin
WeaponSupportGripAnchorOrigin
CombatIdleOrigin
StowAnchorOrigin
```

Dynamic origins are recomputed from the current pose:

```text
RightHandGripOrigin
LeftHandGripOrigin
PrimaryShoulderOrigin
TorsoFrameOrigin
PalmGripOrigin
IKTargetOrigin
BodyRestrictionOrigin
BridgeStartOrigin
```

Dynamic origins are valid only if every frame can still express their transform relative to `RL_BoneRoot`.

## Resolve Phases

Origins must declare when they are resolved. Same name at different timing can be a different authority.

Allowed phase labels:

```text
BAKE_TIME
EDITOR_PREVIEW
PRE_ANIMATION
POST_LOCOMOTION
POST_COMBAT_MODIFIER
POST_FINAL_POSE
RUNTIME_BRIDGE
RUNTIME_STOW
```

Examples:

```text
TrajectoryAuthoringOrigin -> EDITOR_PREVIEW / BAKE_TIME
RightHandGripOrigin -> POST_FINAL_POSE
SolvedReplayWeaponOrigin -> POST_LOCOMOTION / POST_COMBAT_MODIFIER
BodyRestrictionOrigin -> POST_FINAL_POSE
BridgeStartOrigin -> RUNTIME_BRIDGE
```

## Double Authoring Rule

A conflict exists when two systems can write the same spatial result while using different authority chains or overlapping resolve phases.

Conflict test:

```text
same target transform
different origin_id or different origin chain
same or overlapping resolve phase
both systems allowed to write
```

If all four are true, the system has double authoring and must be redesigned or explicitly ordered.

## Current Audit Targets

These are known areas to audit against this law:

```text
motion_node.tip_position_local / pommel_position_local
runtime clip baked tip/pommel locals
trajectory volume origin_local
retarget origin_local and origin_space
solved replay weapon reference-local data
solved replay upper-body pose-channel data
weapon grip anchor weapon-local data
bridge source and target frames
runtime endpoint authority root
combat idle vs skill solved replay parity
noncombat stow anchor and contact-local segment
IK target and hand grip derived origins
body restriction collision proxy origins
```

Noncombat idle is allowed to keep the weapon stowed and detached from hand grip. Combat idle and skills must follow the combat-authored origin chain.

