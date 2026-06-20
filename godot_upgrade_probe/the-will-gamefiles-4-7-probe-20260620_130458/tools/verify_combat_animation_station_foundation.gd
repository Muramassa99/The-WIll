extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const BaseMaterialDefScript = preload("res://core/defs/base_material_def.gd")
const MaterialAnimationEffectStubScript = preload("res://core/defs/material_animation_effect_stub.gd")
const TierDefScript = preload("res://core/defs/tier_def.gd")
const TierResolverScript = preload("res://core/resolvers/tier_resolver.gd")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_station_foundation_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_animation_station_wip_library.tres"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.forge_project_name = "Combat Animation Foundation Test"
	CraftedItemWIPScript.apply_builder_path_defaults(
		wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var station_state: Resource = wip.ensure_combat_animation_station_state()
	var combat_idle_draft: Resource = station_state.call(
		"get_or_create_idle_draft",
		CombatAnimationDraftScript.IDLE_CONTEXT_COMBAT,
		"Combat Idle"
	)
	var noncombat_idle_draft_result: Resource = station_state.call(
		"get_or_create_idle_draft",
		CombatAnimationDraftScript.IDLE_CONTEXT_NONCOMBAT,
		"Noncombat Idle"
	)

	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = TEMP_SAVE_FILE_PATH
	var saved_clone: CraftedItemWIP = wip_library.save_wip(wip)
	var saved_station_state: Resource = saved_clone.combat_animation_station_state if saved_clone != null else null

	var base_material: BaseMaterialDef = BaseMaterialDefScript.new()
	base_material.base_material_id = &"mat_test_base"
	var effect_stub: Resource = MaterialAnimationEffectStubScript.new()
	effect_stub.set("effect_stub_id", &"fx_swing_trail")
	effect_stub.set("trigger_kind", MaterialAnimationEffectStubScript.TRIGGER_MOTION_THRESHOLD)
	effect_stub.set("effect_kind", MaterialAnimationEffectStubScript.EFFECT_KIND_PARTICLE)
	effect_stub.set("animation_speed_threshold_ratio", 0.65)
	base_material.animation_effect_stubs = [effect_stub]
	var tier: TierDef = TierDefScript.new()
	tier.tier_id = &"t1"
	var tier_resolver = TierResolverScript.new()
	var variant: MaterialVariantDef = tier_resolver.build_variant(base_material, tier)
	var material_lookup := {
		base_material.base_material_id: base_material,
		variant.variant_id: variant,
	}
	var cell := CellAtom.new()
	cell.material_variant_id = variant.variant_id
	var material_runtime_resolver = MaterialRuntimeResolverScript.new()
	var resolved_effect_stubs: Array[Resource] = material_runtime_resolver.resolve_animation_effect_stubs_for_cell(cell, material_lookup)

	var lines: PackedStringArray = []
	lines.append("combat_animation_station_exists=%s" % str(station_state != null))
	lines.append("combat_animation_station_schema_id=%s" % str(_resource_get(station_state, &"station_schema_id", StringName())))
	lines.append("idle_draft_count=%d" % int((_resource_get(station_state, &"idle_drafts", []) as Array).size() if station_state != null else 0))
	lines.append("authoring_idle_context_count=%d" % int(CombatAnimationStationStateScript.get_authoring_idle_context_ids().size()))
	lines.append("skill_draft_count=%d" % int((_resource_get(station_state, &"skill_drafts", []) as Array).size() if station_state != null else 0))
	lines.append("default_skill_package_initialized=%s" % str(bool(_resource_get(station_state, &"default_skill_package_initialized", false)) if station_state != null else false))
	lines.append("combat_idle_motion_node_count=%d" % int((combat_idle_draft.get("motion_node_chain") as Array).size() if combat_idle_draft != null else 0))
	lines.append("noncombat_idle_authoring_available=%s" % str(noncombat_idle_draft_result != null))
	lines.append("noncombat_idle_motion_node_count=%d" % int((noncombat_idle_draft_result.get("motion_node_chain") as Array).size() if noncombat_idle_draft_result != null else 0))
	lines.append("noncombat_idle_stow_anchor_mode=%s" % String(_resource_get(noncombat_idle_draft_result, &"stow_anchor_mode", StringName())))
	lines.append("saved_clone_exists=%s" % str(saved_clone != null))
	lines.append("saved_station_exists=%s" % str(saved_station_state != null))
	lines.append("saved_skill_draft_count=%d" % int((_resource_get(saved_station_state, &"skill_drafts", []) as Array).size() if saved_station_state != null else 0))
	lines.append("material_effect_stub_base_count=%d" % int(base_material.animation_effect_stubs.size()))
	lines.append("material_effect_stub_variant_count=%d" % int((variant.resolved_animation_effect_stubs as Array).size() if variant != null else 0))
	lines.append("material_effect_stub_runtime_count=%d" % int(resolved_effect_stubs.size()))
	lines.append("material_effect_stub_runtime_threshold=%s" % str(snapped(float(_resource_get(resolved_effect_stubs[0], &"animation_speed_threshold_ratio", -1.0)) if not resolved_effect_stubs.is_empty() else -1.0, 0.0001)))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _resource_get(resource: Resource, property_name: StringName, default_value: Variant) -> Variant:
	if resource == null:
		return default_value
	var value: Variant = resource.get(property_name)
	return default_value if value == null else value
