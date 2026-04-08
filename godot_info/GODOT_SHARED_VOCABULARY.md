# Godot Shared Vocabulary

This file is the translation layer between informal feature requests and Godot-native implementation choices.

## When you say "scene"

Default meaning:

- a saved node tree, usually a reusable gameplay unit or world chunk

## When you say "node"

Default meaning:

- a runtime object in the scene tree with callbacks, signals, and optional transform

## When you say "resource"

Default meaning:

- serialized data asset, often reusable and inspector-editable

Examples:

- materials
- meshes
- packed scenes
- custom data defs

## When you say "controller"

Default meaning:

- a script that owns player, actor, camera, or subsystem behavior

Examples:

- player controller: usually `CharacterBody3D` or `CharacterBody2D` logic
- UI controller: usually a `Control` root script
- system controller: usually a scene-root node or service object

## When you say "manager"

Default meaning:

- a coordinating object, not necessarily a special Godot type

My first interpretation order:

1. normal scene-root script
2. autoload singleton if global lifetime is required
3. plain helper/service object if no scene presence is needed

## When you say "singleton"

Default meaning:

- Godot autoload

Use only when one globally available instance is actually justified.

## When you say "interactable"

Default meaning:

- an object that can be targeted by player input, usually through raycast, area overlap, or collision-triggered logic

Typical Godot forms:

- `Area3D` or `Area2D`
- collider plus interface-like script method such as `interact()`
- signal-driven interaction response

## When you say "camera rig"

Default meaning:

- a node hierarchy that separates look pivot, offsets, collision handling, and final camera transform

Typical third-person 3D form:

- actor root
- yaw root or visual root
- pitch pivot
- `SpringArm3D`
- `Camera3D`

## When you say "OTS camera"

Default meaning:

- over-the-shoulder third-person camera
- usually offset laterally from the actor centerline
- commonly implemented with pivot plus `SpringArm3D`

## When you say "player body"

Default meaning:

- the actual physics/movement node, usually `CharacterBody3D` in a 3D action prototype

## When you say "physics object"

Default meaning:

- `Area`, `StaticBody`, `RigidBody`, or `CharacterBody`, with 2D or 3D chosen by project space

## When you say "data definition"

Default meaning:

- custom `Resource`

This is the correct Godot-native home for authored item defs, stat defs, materials, recipes, and similar project data.

## When you say "instance"

Default meaning:

- a runtime copy created from a `PackedScene` or resource-backed setup

## When you say "signal"

Default meaning:

- event emitted by a node or object, connected to a callback or callable elsewhere

Use case:

- low-coupling notification instead of direct hard references

## When you say "input"

Default meaning:

- action-driven input through Input Map first, raw device event handling second

## When you say "state"

Possible interpretations:

- node-local runtime state
- resource-authored data state
- global/autoload session state
- animation state machine state

I should resolve which one you mean from the gameplay context.

## When you say "saveable data"

Default meaning:

- data should be separated from scene hierarchy and serialized intentionally

Usual candidates:

- custom resources for authored content
- dictionaries or structured save payloads for runtime persistence

## When you say "Godot way"

My default interpretation is:

- prefer scenes and nodes for hierarchy
- prefer resources for authored data
- prefer signals for decoupled reactions
- prefer Input Map actions over raw keys
- prefer editor-friendly workflows when they do not fight the project architecture