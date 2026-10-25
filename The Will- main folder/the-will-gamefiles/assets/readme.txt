THE WILL - BLENDER ASSET AND WORLD-CREATION RESEARCH
Recorded: 2026-10-25, Europe/Bucharest

PURPOSE AND STATUS

Keep the Codex + Blender investigation beside the project's assets for a later
integration session. This is research and a proposed workflow, not a claim that
the integration or an asset-production pipeline has been tested here.

Local inspection found Blender 5.1 at:
C:\Program Files\Blender Foundation\Blender 5.1\blender.exe

No Blender connection was installed or tested during this investigation.
No Blender scene, generated asset or game content was created. The project has
this assets directory and its existing ui_v2 child; no dedicated world-assets
subdirectory was established by this work. This readme records Blender research
only, not the separate future UI/font work.

RECOMMENDED STARTING APPROACH

Use Codex-assisted Blender work to build a small reusable environment kit, then
assemble and test playable spaces in Godot. The user supplies references, desired
dimensions, atmosphere and visual feedback; Codex can handle scripted construction,
repeatable adjustments, scene inspection and export preparation.

Good initial candidates include walls, corners, doorways, floors, stairs, pillars,
fences, crates and workbenches. Keep a consistent visual style and inspect results
from useful angles. Bespoke creatures, characters and elaborate sculptures may
need substantial artistic work or suitable existing assets; a prompt is not a
guarantee of finished production art.

BLENDER CONTROL OPTIONS

1. Python scripts: the dependable starting mechanism.
   Blender supports its Python API and command-line background execution.
   Codex can write scripts that construct or modify a scene, save editable .blend
   sources, render previews and export assets. A bridge is not required for batch
   work. Preserve useful scripts and parameters so later variants are repeatable.

   Documented command shape, for reference only:
   blender --background --python build_asset.py

2. Live MCP connection: an optional interactive workflow.
   Codex supports local MCP servers. The community project "MCP for Blender"
   (formerly blender-mcp) documents Codex setup, scene inspection, viewport images,
   Python execution and optional asset-library/generation integrations.

   Candidate repository: https://github.com/ahujasid/mcp-for-blender
   Code license reported by the project: MIT.
   This is a third-party integration, not an official Blender Foundation tool.
   Optional external asset/generation services have separate terms and may cost
   money; the MIT bridge does not make all connected content/services free.

   Its compatibility and behavior on this installed Blender/Codex combination
   still need a small local test. Confirm current installation instructions in
   the integration session rather than treating this note as an install script.

REUSABLE ASSETS AND GENERATORS

Parameterize structured assets where it helps: doorway width/height, frame
thickness, stair count, pillar dimensions or controlled surface variation.
Python and Geometry Nodes can support this authoring workflow. Blender's asset
libraries can organize reusable objects, collections, materials and node groups.

Retain editable source and a repeatable generation recipe where practical.
Keep manual artistic edits separate from operations that would regenerate them.

Geometry Nodes are Blender authoring machinery: Godot does not execute the
Blender node graph. Export evaluated geometry. Blender 5.1's glTF documentation
labels Geometry Nodes instance export experimental, so verify that path if used.

Arbitrary Blender shader graphs also do not automatically translate into Godot
materials. Start with glTF-compatible Principled materials and image textures;
bake unsupported procedural appearance when needed, or deliberately recreate it
in Godot. Inspect the actual imported result, not only Blender's render.

EXISTING ASSET SOURCES

Kenney's asset pages and Poly Haven's models/textures/HDRIs report CC0 licensing,
including commercial use. These can reduce work on textures, props and scenery.
Choose compatible art direction; mixing unrelated packs does not automatically
produce a coherent environment. Retain source/license provenance with imported
content. Website/API access conditions are separate from an asset's license.

Sources:
https://kenney.nl/support
https://polyhaven.com/license

GODOT HANDOFF

Preferred initial workflow:
Editable .blend source -> deliberate .glb export -> reusable Godot scene -> map.

Godot 4.7 recommends glTF 2.0 and supports both .gltf and .glb. It can also import
.blend directly by calling an installed Blender to convert it through glTF.
Direct .blend import is a valid alternative; explicit exports were recommended
here to make the delivered asset easy to inspect and control.

Use Godot-owned scenes around imported visuals for interactions, scripts,
collision and other gameplay behavior. Keep imported visuals reimportable.
Godot inherited scenes are another documented option, with their own editing
restrictions. A Blender-authored room or architectural section can be useful;
avoid making the whole world an indivisible asset. One scene may contain many
separate meshes and does not inherently mean one merged mesh.

Check dimensions, units, pivots, transforms, normals, UVs and material appearance.
Use deliberate simplified collision geometry where appropriate. Godot supports
collision import hints and generated mesh LODs; these do not replace checking
real movement, frame time, material cost and scene organization in the game.

PROPOSED FIRST INTEGRATION EXERCISE - NOT YET STARTED

Choose one visual reference and build a small Forge room using approximately
six reusable parts: floor, wall, corner, doorway, pillar and workbench.
Inspect the Blender results, export/import them, and walk through the room in
Godot. Check scale against the actual character, seams, materials, collisions
and performance on the user's current PC before expanding to a larger map.

The exact style, dimensions, kit contents, folder organization and choice of live
MCP versus scripts are still to be selected. Start with a small reversible proof;
do not launch a full world-generation or custom-editor project by implication.

REFERENCES REVIEWED FOR THIS INVESTIGATION

OpenAI - Codex/local MCP configuration:
https://learn.chatgpt.com/docs/extend/mcp?surface=cli
Original official route (redirects to the documentation above):
https://developers.openai.com/codex/mcp/

MCP for Blender - upstream README, capabilities, Codex setup and MIT license:
https://github.com/ahujasid/mcp-for-blender

Blender 5.1 - command-line arguments / Python and background execution:
https://docs.blender.org/manual/de/5.1/advanced/command_line/arguments.html

Blender 5.1 - asset libraries:
https://docs.blender.org/manual/nb/5.1/files/asset_libraries/introduction.html

Blender 5.1 - Geometry Nodes overview:
https://docs.blender.org/manual/id/5.1/modeling/geometry_nodes/introduction.html

Blender 5.1 - glTF exporter, materials and Geometry Nodes export limitations:
https://docs.blender.org/manual/en/5.1/addons/import_export/scene_gltf2.html

Godot 4.7 - supported 3D formats, glTF and direct .blend import:
https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html

Godot 4.7 - import configuration, inherited scenes and mesh LODs:
https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html

Godot 4.7 - imported node customization and collision hints:
https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html

Research limitation: some English Blender 5.1 manual pages could not be fetched.
Official indexed localized 5.1 pages containing the relevant English text were
used where linked above. This was documentation research, not a local Blender
compatibility or visual-quality test. Recheck version-sensitive behavior when
integration begins.
