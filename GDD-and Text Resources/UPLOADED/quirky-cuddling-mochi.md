# THE WILL - First Forge Vertical Slice Implementation Plan

Reference status:
- This is the active first-slice implementation source of truth.
- Use this file together with `DECISION_LEDGER_FIRST_SLICE.md`.

**Status**: ✅ APPROVED - READY FOR IMPLEMENTATION
**Date**: 2026-03-21
**Scope**: Forge materials → cells → profiles → test prints (sandbox only)

---

## 1. PLAN OVERVIEW

**Goal**: Implement a minimum viable vertical slice that demonstrates:
- Loading material definitions from .tres files
- Placing cells in a 3D grid with 6-neighbor connectivity validation
- Baking a profile from placed cells (12 real properties + 8 capabilities)
- Spawning a test print mesh on a static dummy

**NOT Included**: Combat, economy, multiplayer, full UI polish, permanent scenes

---

## 2. ALL CRITICAL CORRECTIONS APPLIED ✓

### Tier System
- REMOVED: F/E/D/C/B/A/S tier scheme (use minimal only for v0.1)
- TierDef fields: `tier_id`, `tier_name`, `stat_multiplier`, `value_multiplier`, `drop_quality`
- `stat_multiplier` applies to StatLine values, NOT to density
- Density is: Material truth layer (BaseMaterialDef), not tier concern

### Test Print Visualization
- REMOVED: All CSGBox3D and CSGCombiner3D
- REQUIRED: MeshInstance3D with runtime-generated ArrayMesh only
- Only exposed faces emitted (no greedy meshing in v0.1)

### Cell Material Identity
- CHOSE: `material_variant_id: String` only (ID, not Resource ref)
- MaterialVariantDef loaded by resolver, NOT stored in CellAtom

### Baking Logic Location
- NO bake() method inside CraftedItemWIP (pure data model)
- Baking lives in: ProfileResolver (calculation) + ForgeService (orchestration). ForgeGridController only requests the action.
- Optional: CraftedItemWIP may hold `latest_baked_profile_snapshot` for workflow convenience

### Center of Mass Calculation
- LOCKED: Must use material density weighting (density_per_cell)
- NOT equal weight per cell (this is removed from NEEDS_DECISION)

### TestPrintInstance Data Model
- NO Node3D references stored in resource
- Fields: `test_id`, `source_wip_id`, `baked_profile` (ref only)
- ForgeGridController owns actual spawned MeshInstance3D

### BakedProfile Properties (all real calculations)
- 12 geometry properties: total_mass, center_of_mass, reach, primary_grip_offset, front_heavy_score, balance_score, edge_score, blunt_score, pierce_score, guard_score, flex_score, launch_score
- 8 capabilities: cap_edge, cap_blunt, cap_pierce, cap_guard, cap_flex, cap_launch, cap_stability, cap_reach
- validation fields: primary_grip_valid (bool), validation_error (string)

### Raw Drop Separation
- raw_drop_def uses `base_material_id` (not variant_id) to keep raw drops separate from processed variants
- ProcessRuleDef specifies conversion: `output_count_per_input = 6` (1 raw drop → 6 forge cells)

### Material Variant Generation (v0.1 Scope)
- For v0.1, material variants are generated in memory by TierResolver from BaseMaterialDef + TierDef combinations
- Explicit MaterialVariantDef .tres files are NOT required in v0.1; variants exist as runtime objects only
- Later versions may add persistent variant .tres files for save/trade systems

---

## 2B. ID NAMING SCHEME (AUTHORITATIVE REFERENCE)

**Source**: `c:\WORKSPACE\GDD-and Text Resources\UPLOADED\stat capability ID Packs.txt`

All ID naming must follow this pack to prevent mismatches:

### Direct Stat IDs (for `base_stat_lines`)
- Offense: `atk_mod_flat`, `power_flat`, `dmg_pct_add`, `crit_chance_pct`, `crit_damage_bonus_add`
- Defense: `def_mod_flat`, `endurance_flat`, `hp_pct_add`, `dmg_reduction_pct_add`, `bubble_hp_flat`, `bubble_shield_defense_mult_add`, `stagger_resist_flat`, `guard_efficiency_pct_add`, `block_power_flat`, `parry_window_pct_add`
- Movement: `move_speed_pct_add`, `move_speed_flat_add`, `aspd_pct_add`, `stamina_max_flat`, `stamina_regen_pct_add`, `stamina_regen_delay_flat`
- Healing: `heal_power_flat`, `heal_power_pct_add`, `received_heal_pct_add`, `heal_crit_scalar_flat`, `bubble_duration_pct_add`, `buff_duration_pct_add`
- DoT/Status: `dot_duration_pct_add`, `hot_duration_pct_add`, `status_apply_chance_pct`, `status_potency_flat`, `poison_power_flat`, `burn_power_flat`, `bleed_power_flat`, `anti_heal_pct_add`, `defense_down_pct_add`, `slow_strength_pct_add`
- Ranged: `projectile_speed_pct_add`, `projectile_drop_reduction_pct`, `draw_speed_pct_add`, `reload_speed_pct_add`, `quiver_capacity_flat`, `ammo_recovery_pct`, `projectile_crit_chance_pct`, `projectile_count_flat`, `projectile_spread_pct_add`, `homing_strength_flat`
- Magic: `magic_power_flat`, `cast_speed_pct_add`, `channel_stability_flat`, `elemental_amplify_pct`, `barrier_power_flat`, `summon_power_flat`
- Threat: `threat_virtual_bonus_pct`, `threat_from_heal_coeff`, `threat_from_res_coeff`

### Capability IDs (for `capability_bias_lines`)
`cap_reach`, `cap_impact`, `cap_edge`, `cap_pierce`, `cap_blunt`, `cap_guard`, `cap_flex`, `cap_tether`, `cap_launch`, `cap_magic`, `cap_heal`, `cap_mobility`, `cap_control`, `cap_stability`, `cap_channel`, `cap_barrier`, `cap_precision`, `cap_burst`, `cap_sustain`, `cap_support`, `cap_projectile`, `cap_armor`, `cap_plate`, `cap_grip`, `cap_anchor`, `cap_aoe`, `cap_counter`, `cap_parry`

### Family IDs (for `skill_family_bias_lines`)
`fam_melee`, `fam_ranged`, `fam_magic`, `fam_defense`, `fam_mobility`, `fam_aoe`, `fam_control`, `fam_support`, `fam_single_target`, `fam_burst`, `fam_sustain`, `fam_counter`, `fam_guard`, `fam_channel`, `fam_throw`, `fam_summon`, `fam_trap`, `fam_zone`, `fam_tether`

### Element IDs (for `elemental_affinity_lines`)
`elem_terre`, `elem_life`, `elem_spirit`, `elem_fae`, `elem_order`, `elem_healing`, `elem_crystal`, `elem_frost`, `elem_caelus`, `elem_cloud`, `elem_astral`, `elem_aqua`, `elem_storm`, `elem_lightning`, `elem_malice`, `elem_undeath`, `elem_plague`, `elem_chaos`, `elem_corrupt`, `elem_death`, `elem_pyro`, `elem_lava`, `elem_explosion`, `elem_demon`, `elem_light`, `elem_holy`, `elem_soul`

### Equipment Context IDs (for `equipment_context_bias_lines`)
`ctx_weapon`, `ctx_armor`, `ctx_accessory`, `ctx_shield`, `ctx_trinket`, `ctx_ranged_support`, `ctx_focus`, `ctx_tool`

### Forge Intent IDs (NOT in BaseMaterialDef; player/UI layer only)
`intent_melee`, `intent_ranged`, `intent_magic`, `intent_defense`, `intent_support`, `intent_hybrid`

---

## 3. HARD CONSTRAINTS

✓ 4 sacred classes never collapse (ForgeMaterialStack, CraftedItemWIP, TestPrintInstance, FinalizedItemInstance)
✓ Materials are universal (context is separate workflow layer)
✓ Gameplay ONLY reads BakedProfile, never raw CellAtom arrays
✓ All unknown formulas marked TODO/NEEDS_DECISION (no silently added defaults)
✓ No convenience layers added during coding
✓ Connectivity: 6-neighbor faces-only (disconnected islands invalid)
✓ Mass: Density-weighted (material_density_per_cell × cell_count)
✓ Drop ratio: 1:6 (1 raw drop → 6 forge material cells)

---

## 4. IMPLEMENTATION ROADMAP (8 PHASES)

### PHASE 1-2: Core Definitions, Atoms & Models (26 files total)

### PHASE 3: Resolvers

### PHASE 4: Services Layer

### PHASE 5: Test Print Mesh Builder

### PHASE 6: Forge Grid Controller

### PHASE 7: Sandbox Scene

### PHASE 8: Material Data Files

---

## 5. CRITICAL IMPLEMENTATION ORDER (26 FILES)

1. ✓ `stat_line.gd` (already done)
2. ✓ `base_material_def.gd` (already done)
3. **`core/defs/tier_def.gd`** - tier definitions
4. **`core/defs/raw_drop_def.gd`** - drop definitions
5. **`core/defs/process_rule_def.gd`** - processing rules
6. **`core/defs/material_variant_def.gd`** - material variants
7. **`core/atoms/cell_atom.gd`** - cell data
8. **`core/atoms/segment_atom.gd`** - segment grouping
9. **`core/atoms/anchor_atom.gd`** - grip points
10. **`core/atoms/layer_atom.gd`** - layer structure
11. **`core/resolvers/tier_resolver.gd`** - apply tier multipliers
12. **`core/resolvers/process_resolver.gd`** - drop → stack conversion
13. **`core/resolvers/segment_resolver.gd`** - cell clustering (6-neighbor)
14. **`core/resolvers/anchor_resolver.gd`** - grip detection
15. **`core/resolvers/profile_resolver.gd`** - bake profiles (12+8 properties)
16. **`core/resolvers/capability_resolver.gd`** - derive capabilities
17. **`core/models/forge_material_stack.gd`** - processed inventory
18. **`core/models/crafted_item_wip.gd`** - work-in-progress (NO bake method)
19. **`core/models/baked_profile.gd`** - baked state (20 properties)
20. **`core/models/test_print_instance.gd`** - test output (NO mesh_instance field)
21. **`core/models/finalized_item_instance.gd`** - skeleton (not used in v0.1)
22. **`runtime/forge/test_print_mesh_builder.gd`** - ArrayMesh generator
23. **`services/forge_service.gd`** - orchestration layer
24. **`runtime/forge/forge_grid_controller.gd`** - main controller
25. **Material .tres files** - `data/defs/materials/base/wood.tres`, `iron.tres`
26. **`scenes/test/forge_sandbox.tscn`** - test scene

---

## 6. FILE SPECIFICATIONS

### Defs Layer (core/defs/)

**tier_def.gd**
- tier_id: String
- tier_name: String
- stat_multiplier: float (applies to StatLine values)
- value_multiplier: float
- drop_quality: float (optional)

**raw_drop_def.gd**
- drop_id: String
- base_material_id: String (references BaseMaterialDef.base_material_id; NOT material_variant, to keep raw drops separate)
- quantity_min: int
- quantity_max: int

**process_rule_def.gd**
- rule_id: String
- input_drop_id: String
- output_material_variant_id: String
- output_count_per_input: int (value = 6; explicit: 1 input generates 6 outputs)

**material_variant_def.gd**
- variant_id: String (unique ID for this variant)
- base_material_id: String (references BaseMaterialDef.base_material_id; the base material this is a variant of)
- tier_id: String (references TierDef.tier_id for stat/value multipliers)
- variant_stats: Array[StatLine] (runtime-populated by TierResolver in v0.1)

### Atoms Layer (core/atoms/)

**cell_atom.gd**
- grid_position: Vector3i
- layer_index: int
- material_variant_id: String (ID only, NOT Resource ref)

**segment_atom.gd**
- segment_id: String
- role: String
- member_cells: Array (of CellAtom)
- material_mix: Dictionary

**anchor_atom.gd**
- anchor_id: String
- anchor_type: String
- local_position: Vector3

**layer_atom.gd**
- layer_index: int
- cells: Array (of CellAtom)

### Models Layer (core/models/)

**forge_material_stack.gd**
- stack_id: String
- material_variant_id: String
- quantity: int
- variant_stats: Array (of StatLine)

**crafted_item_wip.gd** (Sacred Class #2)
- wip_id: String
- creator_id: String
- created_timestamp: float
- layers: Array (of LayerAtom)
- current_layer_index: int
- optional: latest_baked_profile_snapshot: BakedProfile

**baked_profile.gd**
- profile_id: String
- total_mass: float
- center_of_mass: Vector3
- reach: float
- primary_grip_offset: Vector3
- front_heavy_score: float
- balance_score: float
- edge_score, blunt_score, pierce_score, guard_score, flex_score, launch_score: float
- capability_scores: Dictionary[String → float]
- primary_grip_valid: bool
- validation_error: String

**test_print_instance.gd** (Sacred Class #3)
- test_id: String
- source_wip_id: String
- baked_profile: BakedProfile (ref only, NO mesh_instance field)

### Material .tres Files

**wood.tres** (BaseMaterialDef instance)
```
base_material_id: "mat_wood_base"
density_per_cell: 0.5
hardness: 0.4, toughness: 0.5, elasticity: 0.7

base_stat_lines:
  - StatLine(atk_mod_flat, 0.8)
  - StatLine(move_speed_pct_add, 0.05)
  - StatLine(aspd_pct_add, 0.05)
  - StatLine(heal_power_flat, 0.3)
  - StatLine(dot_duration_pct_add, 0.1)

capability_bias_lines:
  - StatLine(cap_reach, 0.7)
  - StatLine(cap_flex, 0.6)
  - StatLine(cap_mobility, 0.5)
  - StatLine(cap_grip, 0.6)
  - StatLine(cap_anchor, 0.5)

skill_family_bias_lines:
  - StatLine(fam_melee, 0.7)
  - StatLine(fam_mobility, 0.6)
  - StatLine(fam_support, 0.4)

elemental_affinity_lines:
  - StatLine(elem_life, 0.2)
  - StatLine(elem_terre, 0.3)

equipment_context_bias_lines:
  - StatLine(ctx_weapon, 0.8)
  - StatLine(ctx_armor, 0.5)
  - StatLine(ctx_ranged_support, 0.6)
```

**iron.tres** (BaseMaterialDef instance)
```
base_material_id: "mat_iron_base"
density_per_cell: 1.5
hardness: 0.8, toughness: 0.6, elasticity: 0.2

base_stat_lines:
  - StatLine(atk_mod_flat, 1.2)
  - StatLine(def_mod_flat, 1.0)
  - StatLine(power_flat, 0.5)
  - StatLine(endurance_flat, 0.4)
  - StatLine(crit_chance_pct, 0.05)
  - StatLine(crit_damage_bonus_add, 0.25)
  - StatLine(heal_power_flat, 0.2)
  - StatLine(move_speed_pct_add, -0.1)
  - StatLine(aspd_pct_add, -0.05)

capability_bias_lines:
  - StatLine(cap_edge, 0.7)
  - StatLine(cap_blunt, 0.8)
  - StatLine(cap_guard, 0.6)
  - StatLine(cap_impact, 0.7)
  - StatLine(cap_stability, 0.7)
  - StatLine(cap_plate, 0.6)

skill_family_bias_lines:
  - StatLine(fam_melee, 0.8)
  - StatLine(fam_defense, 0.7)
  - StatLine(fam_single_target, 0.6)

elemental_affinity_lines:
  (none)

equipment_context_bias_lines:
  - StatLine(ctx_weapon, 0.8)
  - StatLine(ctx_armor, 0.7)
  - StatLine(ctx_shield, 0.6)
```

---

## 7. REMAINING TECHNICAL QUESTIONS (NOT BLOCKING)

Decide during implementation:

- Reach calculation: MAX distance or average?
- Balance score formula: simple distance or complex weighting?
- Edge/Blunt/Pierce capability scores: material affinity % or shape ratios?
- Capability thresholds: what scores map to 0/1/2/3/4?
- Primary grip detection: edge-adjacent cells or threshold?
- Material vertex colors: use material tags or placeholder gray?

---

## 8. OUT OF SCOPE FOR THIS SLICE

- Full combat system
- Multiplayer / networking
- Economy / trading
- Full UI polish
- Skill crafting / behavior assignment
- Animation / rigging
- Armor/Accessory crafting (weapons only for now)
- Dismantling / blueprint extraction
- Seasons / difficulty progression
- AI dummy (static placeholder only)
- Sound / VFX

---

## 9. VALIDATION CHECKLIST

After implementation:

- [ ] All 26 files compile without errors
- [ ] All .tres material files load successfully
- [ ] No circular dependencies between resolvers
- [ ] ForgeGridController can instantiate with configurable grid
- [ ] ProfileResolver produces BakedProfile with all approved geometry fields, capability scores, and validation fields
- [ ] 6-neighbor connectivity validation works
- [ ] Primary grip detection functions correctly
- [ ] TEST: Place 20 iron cells in 4×5×1 arrangement, bake, verify mass/balance
- [ ] TEST: Place wood cells, observe different capabilities vs iron
- [ ] TEST: Spawn test print MeshInstance3D appears with correct geometry
- [ ] TEST: Save WIP, reload, continue editing
- [ ] forge_sandbox.tscn allows complete workflow: place → bake → test print

---

**PLAN STATUS**: ✅ ALL CORRECTIONS APPLIED - FULLY CLEAN & READY FOR GREENLIGHT

**NEXT STEP**: User confirms all fixes are Good, then implementation begins

---

## 10. 2026-03-25 Audit Addendum

This v1 plan was audited against the live project on 2026-03-25.

Rule used for this audit:
- When this file conflicts with the current project, the current project has priority.

### Closed Under-the-Hood Items

- 6-neighbor connectivity is now enforced at bake time. Disconnected builds now surface `validation_error = "disconnected_islands"` in the baked profile instead of only being separable into multiple segments.
- `CraftedItemWIP` now carries the optional `latest_baked_profile_snapshot` described earlier in this file. It is refreshed on bake and cleared again when the WIP is edited.
- `TierResolver` now generates deterministic runtime variant IDs using the normalized live format `mat_<material>_<tier>` such as `mat_wood_gray`.
- `ProcessResolver` now generates deterministic stack IDs instead of leaving them unset.
- Missing material-side resource reference points were added for the old v1 pipeline:
  - `core/defs/materials/tiers/tier_gray.tres`
  - `core/defs/materials/raw_drops/wood_raw_drop.tres`
  - `core/defs/materials/raw_drops/iron_raw_drop.tres`
  - `core/defs/materials/process_rules/wood_gray_process_rule.tres`
  - `core/defs/materials/process_rules/iron_gray_process_rule.tres`
- A dedicated verification pass now exists at `tools/verify_mochi_vertical_slice.gd`.

### Adapted Or Superseded v1 Items

- The old `scenes/test/forge_sandbox.tscn` target is superseded by the live forge workflow built around the crafting bench UI. Do not treat the old sandbox scene as the authoritative target anymore.
- The old `4x5x1` iron test still works as a mass and material-profile check, but under the current anchor rules it is not a valid primary grip shape. Current expected result: `validation_error = "no_primary_grip_candidate"`.
- The live forge loop now uses quality variant IDs such as `mat_wood_gray` in the active authored workflow, while base material IDs remain the internal definition anchor layer for resolver/pipeline work.

### Validation Snapshot

- [x] Core forge/material files compile in the audited path
- [x] Base material `.tres` files load successfully
- [x] Tier/raw drop/process rule reference-point `.tres` files now exist and load successfully
- [x] ForgeGridController can instantiate with a configurable grid
- [x] BakedProfile exposes the approved geometry scores, capability scores, and validation fields used by the live forge path
- [x] 6-neighbor connectivity validation now blocks disconnected builds through baked-profile validation
- [x] Primary grip detection remains active under the current rule set
- [x] TEST: 20 iron cells in `4x5x1` produce the expected current-state result (`total_mass = 30.0`, no valid primary grip under current rules)
- [x] TEST: Equivalent wood and iron builds resolve different capability outcomes
- [x] TEST: Runtime ArrayMesh test print generation produces the expected touching-voxel geometry
- [x] TEST: Save WIP, reload, continue editing
- [x] The old sandbox-scene workflow requirement is superseded by the live crafting bench flow and should be read that way going forward

### Verification Artifact

- Headless verification output is written to `C:/WORKSPACE/mochi_verify_results.txt`

### Small Stitching Added During This Audit

- Deterministic runtime ID format for tier variants and process stacks
- Doc-backed default `tier_gray` resource values (`1.0` multipliers) so the old v1 processing path has a concrete resource reference point without using the stale `basic` placeholder name
- The live first-slice raw-drop/process/material layers now also share the same explicit quality-aware naming law: `drop_<material>_raw_gray` feeds `rule_process_<material>_gray`, which outputs `mat_<material>_gray`
- `1 -> 6` wood/iron process rules matching the old v1 raw-drop conversion note
