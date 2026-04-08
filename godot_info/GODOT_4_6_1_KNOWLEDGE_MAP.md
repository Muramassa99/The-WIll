# Godot 4.6.1 Knowledge Map

## Core mental model

Godot is primarily a scene-and-node engine.

- A game is a tree of scenes.
- A scene is a tree of nodes.
- Nodes provide behavior and runtime presence.
- Resources provide reusable data.
- Scripts extend engine types with project-specific behavior.

This is the base model I should assume unless the project clearly uses a different layer on top.

## The object stack

At a high level, many Godot types sit in this conceptual ladder:

- `Object`
  - base engine object model
- `RefCounted`
  - reference-counted non-node objects
- `Resource`
  - serializable data assets such as materials, meshes, scenes, and custom data defs
- `Node`
  - scene tree object with lifecycle callbacks, signals, and child hierarchy
- Specialized node families
  - `Node2D`, `Node3D`, `Control`, `PhysicsBody2D`, `PhysicsBody3D`, `Camera3D`, `AnimationPlayer`, and so on

## Scenes

Scenes are reusable node trees.

- Every scene has one root node.
- Saved scenes become reusable assets.
- Instancing a scene creates a configured runtime node tree.
- The project has one main scene as the default entry point.

Practical meaning:

- if something is a reusable gameplay unit, scene is the default packaging choice
- if something is pure data, resource is the default packaging choice

## Nodes

Nodes are the functional building blocks.

Common expectations:

- they live in a parent-child tree
- they receive lifecycle callbacks
- they can emit and receive signals
- they can be enabled, disabled, added, removed, reparented, and freed

Important node families:

- `Node`: general logic and scene-tree participation
- `Node2D`: 2D transform hierarchy
- `Node3D`: 3D transform hierarchy
- `Control`: UI layout and input handling

## Resources

Resources are data containers.

Use them when the main problem is authored data, not runtime hierarchy.

Typical examples:

- textures
- meshes
- audio streams
- materials
- animations
- packed scenes
- custom gameplay data definitions

Important practical rules:

- resources are shared when loaded multiple times
- scenes on disk are `PackedScene` resources
- custom resources are a first-class way to model gameplay data
- `.tres` text resources are good for version control and data-driven design

## Scripts

Scripts extend engine classes.

Typical script roles:

- add gameplay behavior to a node
- define custom resource data structures
- encapsulate algorithms and services in `RefCounted` or `Object` types
- create tool scripts for editor-side behavior

In Godot 4, GDScript is a strong default for gameplay iteration, editor integration, and typed project code.

## Signals

Signals are Godot's event/delegation mechanism.

- nodes emit events when something happens
- other objects connect to those signals and respond
- this is the preferred low-coupling pattern for many cross-object reactions

Good default use:

- child reports event upward
- UI reacts to state change
- interactable notifies controller
- timers and areas drive gameplay transitions

## Input model

Default mental model:

- define actions in `InputMap`
- query actions with `Input.is_action_pressed()` or handle them in event callbacks
- use `_unhandled_input()` for gameplay input when UI should get first chance
- use `_input()` only when you intentionally need earliest access

## Processing model

Godot separates variable-rate frame work from fixed-rate physics work.

- `_process(delta)`
  - per rendered frame, variable rate
- `_physics_process(delta)`
  - fixed physics tick, default 60 Hz

Use the right callback for the right domain:

- visuals, camera polish, and non-physics updates in `_process()`
- movement, collision, body updates, and physics-facing logic in `_physics_process()`

## Physics model

Choose the body type by ownership of motion.

- `StaticBody2D/3D`
  - world geometry, obstacles, moving platforms by configured velocity
- `RigidBody2D/3D`
  - simulation owns motion; apply forces, do not drive transform directly
- `CharacterBody2D/3D`
  - your code owns motion; use `move_and_slide()` or `move_and_collide()`
- `Area2D/3D`
  - overlap detection and local physics influence

## Rendering model

Rendering is split by 2D and 3D but uses the same scene approach.

- cameras define view
- lights influence visible scene data
- materials define surface response
- meshes define 3D geometry
- viewports define render targets and can host sub-scenes or offscreen rendering

## Navigation model

There are two main navigation styles:

- graph-based with `AStar2D` or `AStar3D`
- mesh-based with `NavigationServer`, `NavigationRegion`, `NavigationMesh`, and `NavigationAgent`

For realtime 3D spaces, navigation mesh workflows are usually the default choice.

## Editor model

Godot is strongly editor-integrated.

- scene editing, resource editing, signals, imported assets, and inspector-driven workflows are core, not optional extras
- many systems are easiest to maintain when authored through scenes and resources rather than raw code-only patterns

## What this means for project design

When mapping a feature into Godot, the first question is usually:

- is this hierarchy and runtime presence
  - use nodes/scenes
- is this authored data
  - use resources
- is this engine event flow
  - use signals
- is this reusable service logic without scene presence
  - use `RefCounted`, `Object`, or static helpers

That is the baseline interpretation I will use unless the project architecture explicitly dictates otherwise.