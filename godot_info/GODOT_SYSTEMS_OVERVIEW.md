# Godot Systems Overview

## Scene and project structure

- `project.godot` stores project settings and main scene selection.
- `res://` is the project root path.
- scenes are the main unit of composition
- resources are the main unit of reusable data

## Scripting

Primary languages in Godot 4.6:

- GDScript
- C#
- C++ via GDExtension

For this workspace, GDScript is the practical default.

Key GDScript points:

- supports static typing
- integrates tightly with the editor
- supports `class_name`, custom resources, and signals
- warnings and typed inference matter in real projects

## Input

Preferred pattern:

1. define actions in Input Map
2. use action queries or event callbacks
3. keep gameplay input separate from UI input

Important callbacks:

- `_input(event)`
- `_shortcut_input(event)`
- `_unhandled_key_input(event)`
- `_unhandled_input(event)`

Default interpretation:

- gameplay controls usually belong in `_unhandled_input()` or in `_physics_process()` action polling
- UI-specific event handling belongs in `Control._gui_input()`

## Physics

Core practical rules:

- do physics work in `_physics_process()`
- do not scale collision shapes via node scale
- use layers and masks intentionally
- choose body type based on who owns motion

3D equivalents mirror 2D concepts closely:

- `Area3D`
- `StaticBody3D`
- `RigidBody3D`
- `CharacterBody3D`
- `CollisionShape3D`

Character movement rule:

- for `CharacterBody3D`, drive `velocity` in code and call `move_and_slide()` in `_physics_process()`

## Rendering and cameras

Major building blocks:

- `Camera2D`, `Camera3D`
- `MeshInstance3D`
- `StandardMaterial3D`, `ORMMaterial3D`
- `DirectionalLight3D`, `OmniLight3D`, `SpotLight3D`
- `WorldEnvironment`
- `Viewport` and `SubViewport`

Useful 3D patterns:

- `SpringArm3D` for third-person camera rigs with collision
- `WorldEnvironment` for sky, tonemapping, ambient, fog, and post-processing
- `Decal` for local projected detail

## 3D workflow

Typical 3D gameplay stack:

- `Node3D` or `CharacterBody3D` root
- collision via `CollisionShape3D`
- visible geometry via `MeshInstance3D` or imported scene
- camera via `Camera3D`, often with a pivot and `SpringArm3D`
- interaction via `RayCast3D`, `Area3D`, or direct queries

## UI

UI uses the `Control` family, not `Node2D`.

Key implications:

- anchors, size flags, and containers matter
- input goes through GUI handling before unhandled gameplay input
- container-based layout is the normal approach for scalable UI

Common classes:

- `Control`
- `Label`
- `Button`
- `PanelContainer`
- `HBoxContainer`, `VBoxContainer`, `GridContainer`
- `TextureRect`
- `RichTextLabel`

## Animation

Main systems:

- `AnimationPlayer`
- `AnimationTree`
- `Skeleton3D`
- blend spaces and state machines in animation resources

Practical reading:

- `AnimationPlayer` is direct authored timeline playback
- `AnimationTree` is runtime composition and state logic

## Audio

Core runtime nodes:

- `AudioStreamPlayer`
- `AudioStreamPlayer2D`
- `AudioStreamPlayer3D`

Core engine objects:

- `AudioServer`
- buses and audio effects

Use 3D players when position and attenuation matter.

## Navigation

Realtime 3D navigation usually means:

- `NavigationRegion3D`
- `NavigationMesh`
- `NavigationAgent3D`

Practical gotcha:

- the navigation server needs a frame to synchronize before the first path query is reliable

## Data-driven design

Godot supports data-driven architecture well through custom resources.

Use custom `Resource` scripts when you need:

- authored definitions
- serializable gameplay data
- inspector editing
- version-control-friendly text assets

This is especially important for projects with defs, profiles, items, materials, recipes, stats, or authored behavior tables.

## Autoloads and global systems

Use autoloads when the system:

- should exist once
- is globally reachable
- owns isolated, project-wide state or orchestration

Do not make everything an autoload. Many systems should stay as normal scene-local nodes or plain objects.

## Performance and optimization

Major topics in Godot 4.6:

- renderer choice and settings
- visibility ranges and occlusion
- `MultiMeshInstance3D` for many repeated meshes
- avoiding unnecessary per-frame allocations
- keeping physics, rendering, and script responsibilities separated cleanly

## Tooling and extension

Godot supports editor extension through:

- `tool` scripts
- `EditorPlugin`
- import plugins
- inspector plugins
- scene post-import plugins
- GDExtension for native extensions

## Export and deployment

Projects export through presets configured in the editor.

Typical concerns:

- platform templates
- window/display config
- input and controller support
- rendering compatibility
- imported assets and compression settings

## Best-practice defaults I should prefer

- scenes operate independently where possible
- children should not hard-depend on distant tree paths unless there is a strong reason
- signals are preferred for event reactions
- input should use named actions
- gameplay data should use resources when that makes authoring cleaner
- 3D controllers should use `CharacterBody3D` unless physical simulation is the point
- camera rigs should use pivots and helper nodes instead of burying logic in one transform