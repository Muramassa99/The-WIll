# Forge V2 Directive — CSG-First Closed-Volume Material Authoring

## Project Context

This is for **The Will**, built in **Godot 4.6.x**.

Forge V2 is not a refactor of Forge V1.

Forge V1 Stage 1 and Stage 2 are existing working systems and reference material, but Forge V2 should be treated as a **new parallel Forge implementation** with different core assumptions.

Think of it as:

    V1 and V2 share the same pond.
    They are not the same organism.

Existing V1 systems may be duplicated, studied, mined, or adapted where useful, but Forge V2 should not be constrained by V1’s GridMap/cube-based workflow or old stage separation.

Forge V2 is intended to become the near-final Forge architecture. A future V3 is not expected unless it is only an aesthetic/UI makeover.

The goal is to build the finished version now: a unified 3D Forge that bridges creation, material accounting, visual shell generation, collision, and usable in-game crafted entities.

---

# Core Intent

Forge V2 should use a **CSG-first commit/bake architecture**.

The core abstraction is:

    Every player tool action places a closed 3D volume into space.

That placed volume can be:

    real material → adds matter
    VOID         → removes matter / creates empty space

So creation and removal use the same system.

Examples:

    place iron volume  → add iron
    place wood volume  → add wood
    place VOID volume  → subtract/remove material
    replace material   → place VOID, then place new material

This gives Forge V2 one universal grammar:

    closed volume operation
        → resolved geometry
        → material ledger update
        → baked mesh/collision result
        → next operation continues from baked result

The player should feel like they are doing 3D material placement / 3D painting with real volume, not placing cubes and not painting a surface texture.

---

# High-Level Pipeline

The intended Forge V2 flow is:

    seed / existing body
        → player raycasts onto existing matter
        → player places/draws a closed volume
        → volume becomes CSG operation
        → CSG resolves operation
        → result is baked to mesh/collision
        → operation is stored as a chronological ForgeLayer
        → material ledger is updated
        → baked result becomes the target for the next operation
        → final named item exports as normal runtime mesh/collision/stat data

The final exported crafted item should not depend on a live CSG editing scene.

The final item should be a performant in-game asset generated from Forge V2 data.

---

# CSG-First Decision

Use CSG as the primary Forge V2 authoring backend.

This is intentional.

Godot’s CSG system supports boolean operations such as union, intersection, and subtraction, which directly match this Forge’s add/remove/replace needs. Godot also supports baking CSG root results into static mesh and collision resources through `bake_static_mesh()` and `bake_collision_shape()`. :contentReference[oaicite:0]{index=0}

The usual “CSG is for prototyping” framing is acceptable here because the Forge station is itself a player-facing prototyping/modeling environment.

Use CSG as the Forge editing language.

Use baked mesh/collision as the committed result.

Use layer history and material ledger as the truth.

---

# Important Boundary

Do not make the final exported combat/gameplay item a permanent live CSG tree.

Correct:

    CSG for Forge authoring
    CSG for committed add/cut/replace operations
    CSG for layer-by-layer construction
    bake after accepted operations
    final asset becomes mesh/collision/material/stat resource

Incorrect:

    hundreds of live CSG nodes as the permanent exported weapon
    final item depends on active editing scene state
    material truth only exists inside visual mesh
    save data only stores final geometry with no layer/ledger history

---

# Source of Truth

The source of truth should be:

    ForgeAssetData
    ForgeLayerData
    MaterialLedger
    operation history
    checkpoints / baked committed results

The source of truth should not be:

    temporary CSG node tree alone
    visual mesh alone
    collision shape alone
    editor scene state alone

The mesh is an output.

The CSG tree is an authoring/commit tool.

The layer history and material ledger are the actual Forge data.

---

# Material and VOID Rules

## Real Materials

Each real material represents owned matter.

Examples:

    iron
    copper
    wood
    bone
    crystal

Each real material operation should affect the material ledger.

Ledger values should eventually include:

    volume
    mass if density exists
    material ID
    layer references
    possible stat contribution
    possible provenance data

## VOID

VOID is a special operation material.

VOID means absence/removal.

VOID should be placeable by the same tool system as real materials.

VOID should not be counted as inventory material or physical mass.

VOID should be stored in layer history because it affects geometry and may produce removal/refund/scrap data.

Example:

    Layer 012:
      operation_material = VOID
      operation_type = SUBTRACT
      removed:
        iron: 0.002 m³
        copper: 0.0004 m³

VOID lets removal be handled by the same system as creation.

---

# Player Tool Model

The player uses a virtual 3D placement/deposition tool.

The tool/nozzle itself does not need to physically collide with geometry.

Existing matter is used for:

    raycast targeting
    starting point
    anchoring
    surface selection
    later construction target

The material does not need to simulate fluid.

Do not add gravity spreading, sagging, dripping, or real liquid behavior.

The player path/tool placement defines the volume.

The operation creates a closed solid volume.

---

# Seed Body

Forge V2 needs an initial hittable body.

This can be:

    a primitive seed solid
    an existing base object
    an existing crafted base
    a temporary construction anchor

The first operation needs something for raycast targeting.

After new layers are committed and baked, the new result should become raycastable for future operations.

Godot’s `RayCast3D` is appropriate for targeting because it represents a ray from origin to target position and reports the closest intersected object. :contentReference[oaicite:1]{index=1}

---

# Layer-Based Workflow

Every accepted player operation should become a chronological `ForgeLayer`.

A layer is one committed unit of authoring.

Example:

    Layer 001:
      add iron volume
      resolve through CSG
      bake result
      store ledger delta

    Layer 002:
      add VOID volume
      resolve through CSG subtraction
      bake result
      store removed material delta

    Layer 003:
      add copper volume
      resolve through CSG
      bake result
      store ledger delta

Initial undo/redo should be chronological.

Start with:

    undo latest layer
    redo latest undone layer

Non-linear editing can be added later using checkpoints/rebuilds.

---

# Checkpoints

Use checkpoints to avoid expensive full replay if needed.

Possible structure:

    seed
    checkpoint_010
    checkpoint_025
    checkpoint_050
    current

A checkpoint stores a known committed/baked state.

If a rebuild is needed, rebuild from the nearest previous checkpoint instead of replaying from the start.

This is not required for the first proof but should be considered in the architecture.

---

# Core Operation Types

Forge V2 should be designed around these operation types even if only some are implemented at first.

## ADD_MATERIAL

Places a real material volume.

    iron volume + current body = body with added iron

CSG operation is usually union/add.

## SUBTRACT_VOID

Places a VOID volume.

    VOID volume - current body = removed material / empty space

CSG operation is subtraction.

## REPLACE_MATERIAL

Removes existing material in a region and adds a new material.

Implementation can be:

    step 1: apply VOID subtraction
    step 2: apply new material addition

## INTERSECT / TRIM

Optional future operation.

Useful for keeping only a region or creating special constraints.

CSG supports intersection-style operations. :contentReference[oaicite:2]{index=2}

## PINCH / PULL / DEFORM

Optional future operation.

This may not be a natural CSG operation.

If implemented later, it may require procedural mesh manipulation, control cages, or a custom deformation step before committing/baking.

Do not block this future path, but do not make it part of the first required proof.

---

# Custom Stroke Volumes

Even though the system is CSG-first, procedural generation is still allowed.

Procedural generation should primarily be used to create valid custom input solids for CSG.

Example:

    player draws path
        → generate closed swept tube/capsule mesh
        → feed it as CSGMesh3D input
        → apply CSG operation
        → bake result

So procedural mesh generation is not the primary backend.

It is a helper for making custom CSG-compatible stroke shapes.

Godot supports procedural geometry through systems such as `ArrayMesh`, `SurfaceTool`, `MeshDataTool`, and `ImmediateMesh`. :contentReference[oaicite:3]{index=3}

`SurfaceTool` is useful for constructing meshes from script and provides helper functions such as `index()` and `generate_normals()`. :contentReference[oaicite:4]{index=4}

`MeshDataTool` gives access to faces and edges that are not directly available from ArrayMesh arrays, but it is slower than directly altering arrays, so use it only when topology information is needed. :contentReference[oaicite:5]{index=5}

---

# CSG Input Requirements

Custom CSG meshes must be valid solids.

For CSGMesh3D, Godot requires custom meshes to be manifold: closed, volumetric, and with each edge connected to only two faces. Godot also recommends avoiding negative volume, self-intersection, and interior faces. :contentReference[oaicite:6]{index=6}

This is not a reason to avoid CSG.

It is the input contract.

Every custom stroke/volume generator should aim to produce CSG-safe closed solids.

Required validation mindset:

    closed shape
    has volume
    no open ends
    no zero-thickness surfaces
    no self-intersection where avoidable
    correct winding/normals where relevant
    no internal duplicate faces where avoidable

---

# Baked Result

After a layer is accepted, bake the result.

The baked result should provide:

    visual mesh
    collision shape / raycast target
    updated material ledger
    layer record
    optional checkpoint

The next operation should work against the committed/baked result.

This keeps the working set manageable and avoids treating the entire object as one forever-growing live CSG tree.

---

# Material Ledger

The material ledger tracks material truth.

It should not depend on visually inspecting the final mesh.

Each layer should produce a ledger delta.

Example:

    Layer 001:
      +0.0042 m³ iron

    Layer 002:
      -0.0008 m³ iron due to VOID cut

    Layer 003:
      +0.0011 m³ copper

The ledger should support later stat extraction.

Possible future uses:

    mass
    center of mass
    material ratios
    damage modifiers
    durability
    magic affinities
    provenance
    salvage/refund loss

---

# Volume Precision

Material usage should be based on closed volume.

The game-facing result can be rounded.

Possible precision examples:

    0.001 m³
    0.0001 m³
    0.00001 m³

Exact precision will be tuned during implementation.

The important rule is:

    volume is not counted by grid cells
    volume is derived from the committed closed operation/body/layer result

---

# Data Model Direction

Suggested class/resource direction:

    ForgeV2Root
      ForgeV2InputController
      ForgeV2RaycastService
      ForgeV2ToolController
      ForgeV2PreviewService
      ForgeV2CsgCommitBackend
      ForgeV2BakeService
      ForgeV2LayerManager
      ForgeV2MaterialLedger
      ForgeV2CheckpointService
      ForgeV2SaveLoadService

Suggested data resources:

    ForgeAssetData
      asset_id
      seed_reference
      layers
      checkpoints
      current_baked_mesh
      current_collision
      material_ledger
      provenance
      stat_summary

    ForgeLayerData
      layer_id
      order_index
      operation_type
      operation_material
      csg_operation
      input_shape_type
      input_shape_data
      generated_mesh_reference
      baked_result_reference
      collision_reference
      volume_delta
      ledger_delta
      timestamp_or_sequence
      undoable

    ForgeMaterialLedger
      material_id -> total_volume_m3
      material_id -> total_mass
      material_id -> layer_references
      removed_material_records

    ForgeToolOperation
      operation_type
      material_id_or_VOID
      path_points
      radius/profile
      transform
      target_reference
      preview_data

---

# First Prototype Target

Build the smallest useful proof of the current intended architecture.

## Required First Proof

1. Create or reuse a seed body.
2. Raycast from camera/mouse to the seed body.
3. Place one closed CSG primitive volume on the target.
4. Commit it as a material layer.
5. Bake the result to static mesh/collision.
6. Store a `ForgeLayerData` record.
7. Update `MaterialLedger`.
8. Make the baked result raycastable.
9. Place a second volume on the new result.
10. Place a VOID volume and subtract it.
11. Confirm chronological undo can remove latest layer or rebuild latest committed state.

## Success Condition

The first proof succeeds when:

    The player can add material volume,
    subtract VOID volume,
    commit/bake each pass,
    keep layer history,
    update material totals,
    and continue building from the baked result.

---

# What Not To Build First

Do not start with perfect final UI.

Do not start with complex organic stroke drawing unless simple primitives already commit/bake correctly.

Do not start with full non-linear layer editing.

Do not start with final UV/material polish.

Do not start with live combat/export integration before the Forge layer/ledger/bake loop works.

Do not try to convert Forge V1 in place.

Forge V2 should be built as a new parallel system.

---

# Future Expansion

After the basic CSG add/subtract/bake loop works, expand into:

    path-drawn stroke volumes
    custom swept CSGMesh3D strokes
    material replacement operation
    checkpoint system
    better undo/redo
    material bond/contact records
    collision simplification
    final shell optimization
    save/load format
    finalize/naming/export into gameplay item
    stat extraction
    UI polish
    visual material display

---

# Current Priority

The current priority is not to debate whether CSG is allowed.

CSG is allowed.

CSG is the primary Forge V2 path.

The important task is to design the CSG path cleanly:

    stable layer records
    stable material ledger
    stable bake step
    stable raycast target update
    stable final asset export

---

# Core Law To Preserve

Forge V2 is not cube placement.

Forge V2 is not surface texture painting.

Forge V2 is not fluid simulation.

Forge V2 is not a direct V1 refactor.

Forge V2 is a new CSG-first closed-volume authoring system.

Every tool action places a closed volume.

Real material volumes add matter.

VOID volumes remove matter.

Every accepted operation becomes a chronological layer.

Each layer is committed, baked, and recorded.

The final crafted item is generated from Forge V2 data as a normal in-game mesh/collision/stat entity.

The truth is:

    layer history
    material ledger
    baked committed state

not temporary scene nodes alone.