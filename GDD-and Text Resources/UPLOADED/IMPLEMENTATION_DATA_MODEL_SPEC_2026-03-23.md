# Implementation Data Model Spec

Date: 2026-03-23
Status: Implementation-facing design spec derived from the authority savepoint
Purpose: Convert the agreed Town, Gate, Floor, and Forge design into a modular Godot-facing data model that avoids hardcoded gameplay values where practical and keeps tunable data in Resources, preferably `.tres` files.

## 1. Core Implementation Law

The implementation should follow this chain:

raw world drop -> processed forge material -> WIP forge project -> baked profile -> forge-internal test use or finalized external item

And this systemic law:

the player crafts matter -> the Forge resolves matter into a profile -> the game uses the baked profile

That means:
- raw cells are authoring data
- gameplay should not read edit-cloud data after bake when a baked gameplay representation exists
- tunable rules should live in data assets rather than scattered controller constants whenever practical

## 2. Anti-Hardcode Rule

### 2.1 Principle

Avoid hardcoding tunable values in controller code if they represent:
- capacities
- thresholds
- routing priorities
- timeouts
- entry permissions
- salvage percentages
- station rules
- expiry windows
- UI display thresholds
- floor occupancy behavior
- town population behavior

The preferred default is:
- external reference first
- hardcoded value only when there is a strong technical reason

In practice that means most gameplay/system values should be referenced from external data assets, registries, or save-backed data rather than embedded directly in scripts.

### 2.2 Acceptable Hardcoded Values

Some values may still be hardcoded temporarily when they are:
- pure implementation scaffolding with no design weight
- editor-only convenience defaults
- fallback values used only when data assets are missing
- engine/API glue values that are not meaningful game design knobs
- low-level implementation details that would gain nothing from externalization

When that happens, the code should clearly treat them as temporary fallback defaults rather than the true design source.

If a value meaningfully affects game rules, tuning, progression, economy, social flow, storage limits, routing, permissions, timing, salvage, or finalization behavior, it should be assumed to belong outside the script unless there is a compelling reason otherwise.

### 2.3 Preferred Storage Rule

Prefer `.tres` assets for static and tunable design data.

Prefer external references whenever possible:
- `.tres` Resources for static and tunable design rules
- registries for stable indexed lookups
- save-backed models/state for mutable player-owned data
- service lookup against defs/registries instead of embedding rule values locally

Do not force everything into `.tres` if it is actually:
- per-player mutable save state
- runtime instance state
- transient UI session state

Static rules go in defs.
Player-owned mutable data goes in models/state and is saved using save systems.

### 2.4 Strong Preference Rule

The implementation should assume that an external reference is preferred most of the time.

Hardcoding should be the exception, not the convenience default.

Before leaving a meaningful value in code, ask:
- is this a real gameplay/system rule
- could this need tuning later
- could this need expansion later
- could lowering or raising it become a live patch need

If the answer is yes to any of those, prefer moving it out of code.

## 3. Naming and Layering Standard

Use the existing naming law:

- `*Def` = static design/tuning data, usually Resource-backed and stored as `.tres`
- `*State` = mutable runtime state
- `*Instance` = concrete owned runtime/inventory object
- `*Profile` = baked gameplay-facing derived result
- `*Resolver` = pure transformation rules
- `*Service` = orchestration/application layer
- `*Controller` = scene/node behavior
- `*Registry` = indexed lookup service/data

## 4. Data Ownership Split

The implementation must preserve these ownership layers:

### 4.1 Shared Static Data

Shared static game rules live in defs/registries.
Examples:
- town routing thresholds
- floor capacity rules
- forge storage caps
- salvage percentages
- gate presentation rules

### 4.2 Player-Owned Persistent Data

Persistent player-owned data lives in player/account models and save state.
Examples:
- forge material inventory
- WIP projects
- blueprint records
- finalized items
- last active forge workspace state
- social lists if mirrored locally

### 4.3 Runtime Instance State

Mutable per-instance state lives separately from the player-owned persistent layer.
Examples:
- current town layer occupancy snapshot
- floor instance active occupants
- forge instance current visitors
- boss alive/dead/in-combat status for a running instance

## 5. High-Level File/Type Plan

Recommended top-level additions or targets:

### 5.1 Core Defs

Suggested defs under `core/defs/`:

- `town_layer_rules_def.gd`
- `town_routing_rules_def.gd`
- `gate_destination_def.gd`
- `gate_ui_rules_def.gd`
- `named_floor_def.gd`
- `season_floor_assignment_def.gd`
- `floor_instance_rules_def.gd`
- `forge_rules_def.gd`
- `forge_storage_rules_def.gd`
- `forge_test_rules_def.gd`
- `forge_finalization_rules_def.gd`
- `salvage_rules_def.gd`
- `skill_core_rules_def.gd`
- `social_presence_rules_def.gd`

These are design-rule containers and should ideally be instantiated as `.tres` files.

### 5.2 Core Models / States / Instances

Suggested models under `core/models/`:

- `town_layer_state.gd`
- `town_routing_snapshot.gd`
- `gate_instance_summary.gd`
- `floor_instance_state.gd`
- `floor_presence_record.gd`
- `forge_workspace_state.gd`
- `forge_project_record.gd`
- `forge_blueprint_record.gd`
- `forge_test_loadout_state.gd`
- `finalized_item_instance.gd`
- `join_request_record.gd`
- `salvage_result.gd`

### 5.3 Services

Suggested services:

- `town_layer_routing_service.gd`
- `gate_directory_service.gd`
- `floor_instance_service.gd`
- `floor_presence_service.gd`
- `forge_workspace_service.gd`
- `forge_project_service.gd`
- `forge_test_service.gd`
- `forge_finalization_service.gd`
- `salvage_service.gd`
- `social_affinity_service.gd`

### 5.4 Registries

Suggested registries:

- `gate_destination_registry.gd`
- `named_floor_registry.gd`
- `season_assignment_registry.gd`
- `rule_profile_registry.gd`

The registry layer can resolve shared defs and keep controllers from directly loading arbitrary `.tres` paths.

## 6. Tunable Rule Profiles That Should Be `.tres`

### 6.1 Town Layer Rules

Create `TownLayerRulesDef` as a Resource.

Suggested fields:
- `rule_id: StringName`
- `max_population_hard_cap: int`
- `soft_full_ratio: float`
- `auto_route_avoid_ratio: float`
- `preferred_target_ratio: float`
- `allow_manual_join_above_soft_full: bool`
- `create_new_layer_when_all_above_ratio: float`
- `empty_layer_cleanup_delay_seconds: float`

Example `.tres` role:
- `data/defs/world/town/default_town_layer_rules.tres`

### 6.2 Town Routing Rules

Create `TownRoutingRulesDef` as a Resource.

Suggested fields:
- `rule_id: StringName`
- `priority_active_party: int`
- `priority_guild_presence: int`
- `priority_ingame_friend_presence: int`
- `priority_steam_friend_presence: int`
- `priority_population_fit: int`
- `allow_same_previous_layer_bias: bool`
- `require_social_target_below_hard_cap: bool`

This keeps routing priority data-driven instead of branching logic locked to fixed priority assumptions.

### 6.3 Floor Instance Rules

Create `FloorInstanceRulesDef` as a Resource.

Suggested fields:
- `rule_id: StringName`
- `empty_instance_expiry_seconds: float`
- `open_entry_soft_cap: int`
- `invite_entry_hard_cap: int`
- `allow_rejoin_after_death: bool`
- `allow_request_to_join_private_instances: bool`
- `teleport_prompt_timeout_seconds: float`

### 6.4 Forge Rules

Create `ForgeRulesDef` as a Resource.

Suggested fields:
- `rule_id: StringName`
- `max_visitors_total: int`
- `instance_cleanup_when_empty_seconds: float`
- `allow_shared_station_usage: bool`
- `allow_cross_forge_project_continuation: bool`
- `allow_visitors_hit_dummies: bool`
- `allow_visitors_use_owner_unnamed_items: bool`

### 6.5 Forge Storage Rules

Create `ForgeStorageRulesDef` as a Resource.

Suggested fields:
- `rule_id: StringName`
- `weapon_wip_capacity: int`
- `armor_wip_capacity: int`
- `accessory_wip_capacity: int`
- `blueprint_capacity: int`
- `allow_future_capacity_expansion: bool`

### 6.6 Forge Test Rules

Create `ForgeTestRulesDef` as a Resource.

Suggested fields:
- `rule_id: StringName`
- `require_valid_anchor_for_forge_test_equip: bool`
- `allow_unnamed_forge_internal_equip: bool`
- `allow_unnamed_external_use: bool`
- `allow_visitor_test_use_of_owner_unnamed_item: bool`
- `dummy_test_requires_storeable_wip: bool`

This separates the very important distinction:
- forge-internal use allowed
- external use forbidden before naming

### 6.7 Finalization Rules

Create `ForgeFinalizationRulesDef` as a Resource.

Suggested fields:
- `rule_id: StringName`
- `naming_locks_design: bool`
- `naming_locks_skill_allocation: bool`
- `naming_locks_effect_parameters: bool`
- `finalized_items_tradeable: bool`
- `enforce_name_uniqueness_per_player_per_category: bool`

### 6.8 Salvage Rules

Create `SalvageRulesDef` as a Resource.

Suggested fields:
- `rule_id: StringName`
- `material_return_ratio_with_blueprint: float`
- `material_return_ratio_without_blueprint: float`
- `higher_tier_priority_weight: float`
- `skill_core_priority_weight: float`
- `allow_manual_salvage_selection: bool`

### 6.9 Skill Core Rules

Create `SkillCoreRulesDef` as a Resource.

Suggested fields:
- `rule_id: StringName`
- `skill_cores_are_nonmodifiable_in_skill_station: bool`
- `salvage_priority_bonus: float`
- `count_toward_special_recovery_logic: bool`

## 7. Destination and Floor Identity Data

### 7.1 Gate Destination Def

Create `GateDestinationDef` for every gate destination.

Suggested fields:
- `destination_id: StringName`
- `display_name: String`
- `destination_kind: StringName`
- `named_floor_id: StringName`
- `gate_visual_theme_id: StringName`
- `banner_texture: Texture2D`
- `lore_summary: String`

Use this to keep gate naming stable even when floor numbers reshuffle.

### 7.2 Named Floor Def

Create `NamedFloorDef` as the stable identity layer.

Suggested fields:
- `named_floor_id: StringName`
- `display_name: String`
- `lore_name: String`
- `map_scene_path: String`
- `flora_theme_id: StringName`
- `fauna_theme_id: StringName`
- `enemy_pool_ids: PackedStringArray`
- `landmark_ids: PackedStringArray`
- `supports_boss_status_board: bool`

### 7.3 Season Assignment Def

Create `SeasonFloorAssignmentDef` as data, not code.

Suggested fields:
- `season_id: StringName`
- `named_floor_id: StringName`
- `floor_number: int`
- `difficulty_profile_id: StringName`
- `drop_profile_id: StringName`
- `active_from_utc: String`
- `active_to_utc: String`

This avoids baking season-number logic into the floor asset itself.

## 8. Runtime and Persistent State Models

### 8.1 TownLayerState

Mutable runtime state.

Suggested fields:
- `layer_id: StringName`
- `layer_index: int`
- `occupant_count: int`
- `capacity_hard_cap: int`
- `soft_full_ratio: float`
- `is_accepting_auto_routes: bool`
- `is_accepting_manual_entry: bool`
- `occupant_player_ids: PackedStringArray`

This may be runtime-managed and does not need to be a `.tres`.

### 8.2 FloorInstanceState

Suggested fields:
- `instance_id: StringName`
- `named_floor_id: StringName`
- `season_assignment_id: StringName`
- `privacy_mode_id: StringName`
- `owner_player_id: StringName`
- `active_player_ids: PackedStringArray`
- `open_entry_cap: int`
- `hard_cap: int`
- `last_nonempty_timestamp_utc: String`
- `boss_status_records: Array`
- `rejoin_group_id: StringName`

### 8.3 ForgeWorkspaceState

Per-player persistent mutable state.

Suggested fields:
- `owner_player_id: StringName`
- `last_active_project_id: StringName`
- `last_station_id: StringName`
- `last_tool_id: StringName`
- `last_plane_id: StringName`
- `last_layer_index: int`
- `last_camera_state_blob: Dictionary`
- `last_opened_at_utc: String`

This is not a static `.tres`. It is player save state.

### 8.4 ForgeProjectRecord

Per-player persistent WIP record.

Suggested fields:
- `project_id: StringName`
- `owner_player_id: StringName`
- `project_category_id: StringName`
- `display_label: String`
- `is_named_finalized: bool`
- `is_valid_for_forge_test_equip: bool`
- `crafted_item_wip: CraftedItemWIP`
- `latest_baked_profile_snapshot: BakedProfile`
- `last_modified_utc: String`

### 8.5 ForgeBlueprintRecord

Suggested fields:
- `blueprint_id: StringName`
- `owner_player_id: StringName`
- `source_item_name: String`
- `source_creator_player_id: StringName`
- `category_id: StringName`
- `material_recipe_snapshot: Array`
- `skill_layout_snapshot: Array`
- `shape_snapshot_ref: Resource`
- `created_at_utc: String`

### 8.6 ForgeTestLoadoutState

This should exist as a forge-only equipment/testing bridge.

Suggested fields:
- `owner_player_id: StringName`
- `equipped_forge_project_id: StringName`
- `category_id: StringName`
- `baked_profile_snapshot: BakedProfile`
- `is_forge_internal_only: bool`
- `is_tradeable: bool`
- `is_external_world_usable: bool`

This prevents leaking unnamed test items into world-valid equipment logic.

## 9. Service Responsibilities

### 9.1 TownLayerRoutingService

Should read:
- `TownLayerRulesDef`
- `TownRoutingRulesDef`
- social affinity data
- live occupancy snapshots

Should output:
- target town layer choice
- reason code for selection

### 9.2 GateDirectoryService

Should aggregate:
- `GateDestinationDef`
- `NamedFloorDef`
- `SeasonFloorAssignmentDef`
- live `FloorInstanceState`
- friend/guild/Steam presence summaries

Should output destination board view models.

### 9.3 ForgeWorkspaceService

Should own:
- loading/saving `ForgeWorkspaceState`
- loading per-player WIP and blueprint collections
- restoring last-active project/session state

### 9.4 ForgeTestService

Should determine:
- whether a WIP is forge-test-equip valid
- how to produce `ForgeTestLoadoutState`
- how to unequip or swap forge-only test items

### 9.5 ForgeFinalizationService

Should enforce:
- naming rules
- uniqueness constraints
- post-name transition to finalized item
- lock of previously mutable data

### 9.6 SalvageService

Should read:
- `SalvageRulesDef`
- `SkillCoreRulesDef`
- finalized item makeup

Should output:
- salvage preview
- salvage selection options
- resulting material return and optional blueprint

## 10. Controllers Should Stay Thin

Controllers and UI code should not become the authority for:
- caps
- percentages
- timings
- privacy rules
- routing priorities
- naming rules
- salvage math

Controllers should ask services.
Services should read defs and models.
Resolvers should transform cleanly.

This same rule applies beyond controllers:
- services should avoid embedding design tunables when defs can provide them
- models should avoid pretending runtime snapshots are static rules
- UI widgets should not invent gameplay defaults locally

## 11. Suggested `.tres` Folder Layout

Recommended layout:

```text
res://data/defs/world/town/
    default_town_layer_rules.tres
    default_town_routing_rules.tres

res://data/defs/world/gates/
    forge_gate_destination.tres
    graces_garden_gate_destination.tres

res://data/defs/world/floors/
    graces_garden_named_floor.tres
    floor_instance_rules_default.tres

res://data/defs/world/seasons/
    season_2026_q2_graces_garden_assignment.tres

res://data/defs/forge/
    forge_rules_default.tres
    forge_storage_rules_default.tres
    forge_test_rules_default.tres
    forge_finalization_rules_default.tres
    salvage_rules_default.tres
    skill_core_rules_default.tres
```

## 12. What Should Not Be `.tres`

Do not force these into static `.tres` definitions:

- active player-owned WIP collections
- runtime occupancy counts
- active join requests
- active forge visitors
- current boss instance status
- current test-equip selection
- last opened project per player

Those should be save-backed state/models, database-backed later, or runtime state.

## 13. Minimal First Implementation Order

To keep momentum without overbuilding, the first implementation-facing order should be:

1. add rule defs for town, floor, forge, storage, finalization, salvage
2. add stable destination and named-floor defs
3. add player-owned forge workspace and project records
4. add forge-only test-loadout state model
5. add services that read defs rather than hardcoded constants
6. only then expand UI/controller surfaces against those services

## 14. Final Guidance

The system should be:
- data-driven where values are meant to change
- model-driven where state is player-owned or runtime-owned
- modular enough that caps and rules can shrink or expand later
- explicit about the difference between static game rules and mutable player progress

If a future implementation choice would bury a tunable gameplay value in a controller script, prefer moving that value into a `.tres` rule profile unless there is a strong reason not to.