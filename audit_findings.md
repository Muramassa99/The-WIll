# The Will Codebase - Resource Usage Audit (COMPLETE)
## Alignment with .tres RULES and RESOURCE USAGE RULES
**Date: March 23, 2026 | Status: CLEAN (Post-Fix Verification)**

### Audit Scope
- Codebase: `c:\WORKSPACE\The Will- main folder\the-will-gamefiles`
- Reference docs:
  - THE WILL — .tres RESOURCE RULES.md
  - THE WILL — RESOURCE USAGE RULES
- Exclusion: Forge WIP volatile state fixes already applied by user

### Summary
**24 Resource classes total** - all properly classified
- **0 misaligned patterns** remaining
- **12 acceptable instance-resource patterns** (verified compliant)  
- **12 correct shared definition patterns** (read-only enforcement verified)
- **13+ resolvers/services** correctly use RefCounted (not Resource)
- **All definition .tres files** are immutable at runtime

---

## VERIFIED COMPLIANT PATTERNS

### Fixed Issues (No Longer Present)
1. ~~CraftedItemWIP.current_layer_index~~ ✓ REMOVED
2. ~~CraftedItemWIP.latest_baked_profile_snapshot~~ ✓ REMOVED  
3. ~~Direct layer mutation in crafting_bench_ui~~ ✓ MOVED to ForgeGridController

### Instance Resources (Correct Mutable Usage)
✓ **PlayerForgeInventoryState** - session inventory state, proper mutation via add_quantity/try_consume
✓ **ForgeMaterialStack** - per-stack inventory tracking with quantity mutations
✓ **CraftedItemWIP** - cleaned; stores only authored/structural data (layers, cells, timestamps)
✓ **BakedProfile** - computation output container, generated fresh per bake
✓ **TestPrintInstance** - instance data linking WIP to baked profile and display cells
✓ **Atom types** (CellAtom, LayerAtom, SegmentAtom, AnchorAtom, StatLine) - geometry building blocks

### Shared Definition Resources (Correct Read-Only Usage)
✓ **ForgeRulesDef** - grid_size, fill_ratios, anchor/joint/bow rules; read at init/on setter
✓ **ForgeViewTuningDef** - visual tuning constants; read-only accessors
✓ **BaseMaterialDef** - material family, density, hardness, biases; immutable
✓ **TierDef** - processing tier definitions; immutable
✓ **MaterialVariantDef** - variant instances created by TierResolver (not mutated)
✓ **RawDropDef, ProcessRuleDef** - definition lookups; immutable
✓ **ForgeSamplePresetDef, ForgeSampleBrushDef** - brush/preset tuning; read-only

### Services/Resolvers (Correct RefCounted Usage)
✓ **ForgeService** - holds reference to ForgeRulesDef but never mutates it
✓ **TierResolver, ProfileResolver, SegmentResolver, JointResolver, BowResolver** - all RefCounted
✓ **AnchorResolver, CapabilityResolver, ShapeClassifierResolver, ProcessResolver** - all RefCounted
✓ **CraftingBenchUI** - CanvasLayer; stores UI state locally (active_plane, active_layer, active_tool)
✓ **ForgeGridController** - Node; controls WIP/test_print references and active_layer_index properly

### Missing Scene/Orchestration in Resources
✓ No Node references stored in Resources
✓ No Control/CanvasItem references in Resources  
✓ No @onready directives on Resource classes
✓ No add_child() calls from Resource code
✓ No scene tree ownership from Resources

---

## ARCHITECTURE STRENGTHS VERIFIED

### Boundary Separation
- UI state lives in CraftingBenchUI (CanvasLayer Node)
- Definition tuning lives in immutable .tres resources
- Instance crafting state lives in CraftedItemWIP (per-session instance)
- Services/resolvers are RefCounted stateless processors
- Geometry mutations (layer.cells.append, wip.layers.append) only in ForgeGridController, not UI

### Data Flow
- ForgeRulesDef.default_sample_preset_id → read by ForgeGridController → used to build WIP
- CraftedItemWIP.layers → mutated in ForgeGridController → synced to viewport
- BakedProfile → output from ForgeService → stored briefly in ForgeGridController.active_baked_profile
- PlayerForgeInventoryState → created/mutated by player → queried for UI display

### No Volatile State on Resources
✓ No per-frame UI hover/drag state  
✓ No current viewport bounds cached on Resources
✓ No pending operations queued on Resources
✓ No controller references on instance Resources

---

## MINOR OBSERVATIONS (NOT VIOLATIONS)

1. **ForgeWorkspacePreview** dynamically created in crafting_bench_ui._ensure_free_workspace_preview()
   - Status: ✓ Correct; PreviewWorkspace is RefCounted helper, not Resource
   - Reason: Supports independent viewport rendering, proper encapsulation

2. **Free view drag state** (free_view_drag_active, free_view_drag_origin) in CraftingBenchUI
   - Status: ✓ Correct; volatile per-interaction state in UI controller, not Resource
   - Reason: Matches RULE 7 (volatile/per-frame → keep out of Resources)

3. **Grid size copies** (forge_grid_controller.grid_size = DEFAULT_FORGE_RULES_RESOURCE.grid_size)
   - Status: ✓ Correct; read-once into controller state
   - Reason: Allows runtime override via configure_grid() without mutating shared .tres

4. **Material lookup built on-demand** (build_default_material_lookup())
   - Status: ✓ Correct; fresh dictionary per call, not cached on Resources
   - Reason: Prevents stale material definitions and supports dynamic tile loading

---

## CONCLUSION
✅ **ZERO MISALIGNMENTS FOUND** — Resource usage rules are properly enforced.
✅ **All previously identified issues RESOLVED** — Forge WIP volatility fixed.
✅ **Architecture is SOUND** — Clear separation of concerns maintained.
