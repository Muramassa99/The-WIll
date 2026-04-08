# Godot Class Taxonomy

This is not the complete class reference. The complete reference is in `official_docs/html/classes/index.html`.

This file groups the class landscape into practical engineering buckets.

## Base object model

- `Object`
- `RefCounted`
- `Resource`
- `Node`

These are the foundation of most project code.

## Variant and math types

Core non-node value types:

- `Vector2`, `Vector3`, `Vector4`
- `Basis`, `Quaternion`, `Transform2D`, `Transform3D`
- `Color`, `AABB`, `Plane`, `Rect2`
- `Array`, `Dictionary`, packed arrays
- `StringName`, `NodePath`, `Callable`, `Signal`, `RID`

## Scene tree and lifecycle

- `Node`
- `SceneTree`
- `PackedScene`
- `Viewport`
- `Window`

## 2D node family

- `Node2D`
- `Sprite2D`
- `AnimatedSprite2D`
- `Camera2D`
- `TileMap`, `TileMapLayer`
- `Line2D`, `Polygon2D`
- `Marker2D`

## 3D node family

- `Node3D`
- `MeshInstance3D`
- `Camera3D`
- `Marker3D`
- `SpringArm3D`
- `Decal`
- `GridMap`
- `WorldEnvironment`

## UI node family

- `Control`
- `Label`
- `Button`
- `Panel`, `PanelContainer`
- `LineEdit`, `TextEdit`, `RichTextLabel`
- `TextureRect`
- container nodes such as `HBoxContainer`, `VBoxContainer`, `GridContainer`

## Physics and collision

2D:

- `Area2D`
- `StaticBody2D`
- `RigidBody2D`
- `CharacterBody2D`
- `CollisionShape2D`
- `RayCast2D`, `ShapeCast2D`

3D:

- `Area3D`
- `StaticBody3D`
- `RigidBody3D`
- `CharacterBody3D`
- `CollisionShape3D`
- `RayCast3D`, `ShapeCast3D`

## Rendering and visual assets

- `Mesh`, `ArrayMesh`, `ImmediateMesh`
- primitive meshes such as `BoxMesh`, `PlaneMesh`, `CapsuleMesh`
- `Material`, `BaseMaterial3D`, `StandardMaterial3D`, `ShaderMaterial`
- `Texture2D`, `ImageTexture`, `ViewportTexture`
- `Environment`, `Sky`

## Lighting

- `Light2D`
- `DirectionalLight3D`
- `OmniLight3D`
- `SpotLight3D`
- `LightmapGI`, `VoxelGI`

## Animation

- `AnimationPlayer`
- `AnimationTree`
- `AnimationMixer`
- animation resources and animation nodes
- `Skeleton2D`, `Skeleton3D`

## Audio

- `AudioStreamPlayer`
- `AudioStreamPlayer2D`
- `AudioStreamPlayer3D`
- `AudioServer`
- `AudioStream`
- audio effect resources

## Navigation

- `AStar2D`, `AStar3D`, `AStarGrid2D`
- `NavigationRegion2D`, `NavigationRegion3D`
- `NavigationAgent2D`, `NavigationAgent3D`
- `NavigationLink2D`, `NavigationLink3D`
- `NavigationObstacle2D`, `NavigationObstacle3D`
- `NavigationMesh`
- `NavigationServer2D`, `NavigationServer3D`

## Input and device handling

- `Input`
- `InputMap`
- `InputEvent` and specialized subclasses

## File, serialization, and data I/O

- `FileAccess`
- `DirAccess`
- `ConfigFile`
- `JSON`
- `ResourceLoader`
- `ResourceSaver`

## Networking and multiplayer

- `MultiplayerAPI`
- `ENetMultiplayerPeer`
- `WebSocketPeer`
- `HTTPClient`, `HTTPRequest`
- packet and stream peer classes

## Editor extension classes

- `EditorPlugin`
- `EditorInspectorPlugin`
- `EditorImportPlugin`
- `EditorScenePostImportPlugin`
- `EditorExportPlugin`

## Common project-level interpretation

If a feature is asking for:

- world presence: use a node
- reusable world unit: use a scene
- authored data: use a resource
- event reaction: use a signal
- global process: consider autoload
- pure algorithm/service: plain object or resource-backed service, not necessarily a node