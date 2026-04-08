# Godot 4.6.1 Workspace Reference

This folder is the local Godot reference base for this workspace.

It has two layers:

1. Official offline documentation mirror
2. Curated notes for fast engineering decisions and shared vocabulary

## What is here

- `official_docs/html/index.html`
  - Full official offline Godot documentation, downloaded from the stable docs build.
- `GODOT_4_6_1_KNOWLEDGE_MAP.md`
  - The engine mental model: what the major parts are and how they fit together.
- `GODOT_SYSTEMS_OVERVIEW.md`
  - Fast reference for gameplay, rendering, input, physics, UI, navigation, audio, export, and tooling.
- `GODOT_SHARED_VOCABULARY.md`
  - Shared meaning map for common requests like controller, interactable, manager, singleton, scene, resource, rig, and signal.
- `GODOT_CLASS_TAXONOMY.md`
  - The class landscape in practical groups instead of one giant class list.
- `GODOT_OFFICIAL_SOURCES.md`
  - Attribution, download source, and the official entry points I will treat as canonical.

## How I will use this

When you ask for Godot work in this workspace, I will treat this folder as the local reference anchor.

That means:

- shared terms will map to Godot-native concepts first
- implementation choices should prefer Godot 4.6 stable patterns
- scene, node, resource, signal, and input architecture should stay aligned with official guidance

## Best local starting points

- Offline docs home: `official_docs/html/index.html`
- Full class reference: `official_docs/html/classes/index.html`
- GDScript docs: `official_docs/html/tutorials/scripting/gdscript/index.html`
- 3D docs: `official_docs/html/tutorials/3d/index.html`
- Rendering docs: `official_docs/html/tutorials/rendering/index.html`
- Physics docs: `official_docs/html/tutorials/physics/index.html`
- Input docs: `official_docs/html/tutorials/inputs/index.html`
- Navigation docs: `official_docs/html/tutorials/navigation/index.html`

## Important constraint

This folder gives me a strong local reference base, but it does not turn me into a permanently updated external service. When a task depends on exact engine behavior, I will still verify against the local offline docs and, when needed, current official sources.