extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationWeaponGeometryResolverScript = preload("res://core/resolvers/combat_animation_weapon_geometry_resolver.gd")
const BakedProfileScript = preload("res://core/models/baked_profile.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_station_baseline_reset_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_animation_station_baseline_reset_library.tres"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_SAVE_FILE_PATH
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()

	var source_wip: CraftedItemWIP = CraftedItemWIPScript.new()
	source_wip.forge_project_name = "Baseline Reset Verifier"
	CraftedItemWIPScript.apply_builder_path_defaults(
		source_wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)
	var persisted_wip: CraftedItemWIP = library_state.get_saved_wip(saved_wip.wip_id if saved_wip != null else StringName())
	var persisted_station_state: CombatAnimationStationState = null
	if persisted_wip != null:
		persisted_station_state = persisted_wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if persisted_station_state != null:
		var dirty_draft: CombatAnimationDraft = persisted_station_state.get_or_create_skill_draft(
			&"skill_slot_1",
			"Legacy Slot 1",
			persisted_wip.grip_style_mode if persisted_wip != null else &"grip_normal",
			&"skill_slot_1"
		) as CombatAnimationDraft
		if dirty_draft != null:
			dirty_draft.skill_name = "Legacy Dirty Skill"
			dirty_draft.draft_notes = "legacy dirty notes"
			dirty_draft.ensure_minimum_baseline_nodes()
			var dirty_nodes: Array = dirty_draft.motion_node_chain
			if dirty_nodes.size() > 1:
				var dirty_second_node: CombatAnimationMotionNode = dirty_nodes[1] as CombatAnimationMotionNode
				if dirty_second_node != null:
					dirty_second_node.tip_position_local = Vector3(0.11, 0.03, -0.19)
					dirty_second_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_AUTO
		persisted_station_state.skill_drafts.clear()
		if dirty_draft != null:
			persisted_station_state.skill_drafts.append(dirty_draft)
		persisted_station_state.selected_skill_id = &"skill_slot_1"
		persisted_station_state.default_skill_package_initialized = true
		persisted_station_state.station_version = CombatAnimationStationStateScript.SKILL_BASELINE_SCHEMA_VERSION - 1
	if persisted_wip != null:
		persisted_wip.latest_baked_profile_snapshot = _build_test_baked_profile()
	library_state.persist()

	var geometry_resolver = CombatAnimationWeaponGeometryResolverScript.new()
	var expected_profile: BakedProfile = persisted_wip.latest_baked_profile_snapshot if persisted_wip != null else null
	var expected_seed: Dictionary = geometry_resolver.resolve_motion_seed_data(expected_profile)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	get_root().add_child(fake_player)

	var ui = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Verifier")
	await process_frame

	var migrated_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create(TEMP_SAVE_FILE_PATH)
	var migrated_wip: CraftedItemWIP = migrated_library.get_saved_wip(saved_wip.wip_id if saved_wip != null else StringName())
	var migrated_station_state: CombatAnimationStationState = null
	if migrated_wip != null:
		migrated_station_state = migrated_wip.combat_animation_station_state as CombatAnimationStationState
	var migrated_skill_drafts: Array = migrated_station_state.skill_drafts if migrated_station_state != null else []
	var migrated_skill_draft: CombatAnimationDraft = _find_skill_draft(migrated_skill_drafts, &"skill_slot_1")
	var migrated_first_node: CombatAnimationMotionNode = _get_motion_node(migrated_skill_draft, 0)

	var custom_open_ok: bool = ui.open_saved_wip_with_hand_setup(saved_wip.wip_id if saved_wip != null else StringName(), &"hand_left", true, false)
	await process_frame
	var select_slot_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await process_frame
	var live_profile_before_reset: BakedProfile = ui.active_wip.latest_baked_profile_snapshot if ui.active_wip != null else null
	var seed_before_reset: Dictionary = ui.call("_resolve_active_weapon_authored_baseline_seed") as Dictionary
	var active_draft_before_reset: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var before_reset_first_node: CombatAnimationMotionNode = _get_motion_node(active_draft_before_reset, 0)
	var before_reset_two_hand_state: StringName = before_reset_first_node.two_hand_state if before_reset_first_node != null else StringName()
	var expected_reset_tip: Vector3 = seed_before_reset.get("tip_position_local", Vector3.ZERO) as Vector3
	var expected_reset_pommel: Vector3 = seed_before_reset.get("pommel_position_local", Vector3.ZERO) as Vector3
	var expected_reset_weapon_orientation: Vector3 = seed_before_reset.get("weapon_orientation_degrees", Vector3.ZERO) as Vector3

	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await process_frame
	var active_draft_after_reset: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var after_reset_first_node: CombatAnimationMotionNode = _get_motion_node(active_draft_after_reset, 0)
	var after_reset_second_node: CombatAnimationMotionNode = _get_motion_node(active_draft_after_reset, 1)
	var active_station_state_after_reset: CombatAnimationStationState = null
	if ui.active_wip != null:
		active_station_state_after_reset = ui.active_wip.combat_animation_station_state as CombatAnimationStationState
	var active_station_draft_after_reset: CombatAnimationDraft = _find_skill_draft(
		active_station_state_after_reset.skill_drafts if active_station_state_after_reset != null else [],
		&"skill_slot_1"
	)
	var active_station_first_node_after_reset: CombatAnimationMotionNode = _get_motion_node(active_station_draft_after_reset, 0)
	var saved_library_wip_after_reset: CraftedItemWIP = ui.active_wip_library.get_saved_wip(
		saved_wip.wip_id if saved_wip != null else StringName()
	) if ui.active_wip_library != null else null
	var saved_library_station_after_reset: CombatAnimationStationState = null
	if saved_library_wip_after_reset != null:
		saved_library_station_after_reset = saved_library_wip_after_reset.combat_animation_station_state as CombatAnimationStationState
	var saved_library_draft_after_reset: CombatAnimationDraft = _find_skill_draft(
		saved_library_station_after_reset.skill_drafts if saved_library_station_after_reset != null else [],
		&"skill_slot_1"
	)
	var saved_library_first_node_after_reset: CombatAnimationMotionNode = _get_motion_node(saved_library_draft_after_reset, 0)
	var after_reset_debug: Dictionary = ui.get_preview_debug_state()
	var first_reset_signature: Dictionary = _build_reset_signature(after_reset_first_node, after_reset_second_node)
	var seed_after_first_reset: Dictionary = ui.call("_resolve_active_weapon_authored_baseline_seed") as Dictionary
	var second_reset_ok: bool = ui.reset_active_draft_to_baseline()
	await process_frame
	var active_draft_after_second_reset: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var after_second_reset_first_node: CombatAnimationMotionNode = _get_motion_node(active_draft_after_second_reset, 0)
	var after_second_reset_second_node: CombatAnimationMotionNode = _get_motion_node(active_draft_after_second_reset, 1)
	var second_reset_signature: Dictionary = _build_reset_signature(after_second_reset_first_node, after_second_reset_second_node)
	var seed_after_second_reset: Dictionary = ui.call("_resolve_active_weapon_authored_baseline_seed") as Dictionary
	var persisted_file_text: String = FileAccess.get_file_as_string(TEMP_SAVE_FILE_PATH) if FileAccess.file_exists(TEMP_SAVE_FILE_PATH) else ""
	var persisted_slot_1_anchor: String = "draft_id = &\"skill_slot_1_draft\""
	var persisted_slot_1_anchor_index: int = persisted_file_text.find(persisted_slot_1_anchor)

	var expected_tip: Vector3 = expected_seed.get("tip_position_local", Vector3.ZERO) as Vector3
	var expected_pommel: Vector3 = expected_seed.get("pommel_position_local", Vector3.ZERO) as Vector3
	var expected_skill_draft_count: int = CombatAnimationStationStateScript.get_authoring_skill_slot_ids().size()

	var lines: PackedStringArray = []
	lines.append("migration_station_version=%d" % int(migrated_station_state.station_version if migrated_station_state != null else -1))
	lines.append("migration_skill_draft_count=%d" % migrated_skill_drafts.size())
	lines.append("migration_expected_skill_draft_count=%d" % expected_skill_draft_count)
	lines.append("migration_default_skill_package_initialized=%s" % str(bool(migrated_station_state.default_skill_package_initialized if migrated_station_state != null else false)))
	lines.append("migration_rebuilt_full_skill_package=%s" % str(migrated_skill_drafts.size() == expected_skill_draft_count))
	lines.append("migration_cleared_legacy_notes=%s" % str(migrated_skill_draft != null and String(migrated_skill_draft.draft_notes).is_empty()))
	lines.append("migration_rebuilt_slot_1=%s" % str(migrated_skill_draft != null))
	lines.append("migration_reseeded_slot_1_tip=%s" % str(
		migrated_first_node != null and migrated_first_node.tip_position_local.is_equal_approx(expected_tip)
	))
	lines.append("custom_open_ok=%s" % str(custom_open_ok))
	lines.append("select_slot_ok=%s" % str(select_slot_ok))
	lines.append("live_profile_before_reset_exists=%s" % str(live_profile_before_reset != null))
	lines.append("live_profile_before_reset_primary_grip_valid=%s" % str(
		live_profile_before_reset.primary_grip_valid if live_profile_before_reset != null else false
	))
	lines.append("live_profile_before_reset_tip=%s" % str(
		live_profile_before_reset.weapon_tip_point if live_profile_before_reset != null else Vector3.ZERO
	))
	lines.append("live_profile_before_reset_pommel=%s" % str(
		live_profile_before_reset.weapon_pommel_point if live_profile_before_reset != null else Vector3.ZERO
	))
	lines.append("seed_before_reset_two_hand_state=%s" % String(seed_before_reset.get("two_hand_state", StringName())))
	lines.append("before_reset_two_hand_state=%s" % String(before_reset_two_hand_state))
	lines.append("before_reset_preview_slot=%s" % String(ui.get_active_open_dominant_slot_id()))
	lines.append("before_reset_preview_two_hand=%s" % str(ui.is_active_open_two_hand()))
	lines.append("reset_ok=%s" % str(reset_ok))
	lines.append("after_reset_active_draft_identifier=%s" % String(ui.get_active_draft_identifier()))
	lines.append("after_reset_active_slot=%s" % String(ui.get_active_open_dominant_slot_id()))
	lines.append("after_reset_active_two_hand=%s" % str(ui.is_active_open_two_hand()))
	lines.append("after_reset_preview_slot=%s" % String(after_reset_debug.get("dominant_slot_id", StringName())))
	lines.append("after_reset_preview_two_hand=%s" % str(bool(after_reset_debug.get("default_two_hand", false))))
	lines.append("after_reset_first_node_two_hand_state=%s" % String(after_reset_first_node.two_hand_state if after_reset_first_node != null else StringName()))
	lines.append("after_reset_second_node_two_hand_state=%s" % String(after_reset_second_node.two_hand_state if after_reset_second_node != null else StringName()))
	lines.append("after_reset_station_first_node_two_hand_state=%s" % String(
		active_station_first_node_after_reset.two_hand_state if active_station_first_node_after_reset != null else StringName()
	))
	lines.append("saved_library_first_node_two_hand_state=%s" % String(
		saved_library_first_node_after_reset.two_hand_state if saved_library_first_node_after_reset != null else StringName()
	))
	lines.append("after_reset_first_node_tip_matches_expected=%s" % str(
		after_reset_first_node != null and after_reset_first_node.tip_position_local.is_equal_approx(expected_reset_tip)
	))
	lines.append("after_reset_station_tip_matches_expected=%s" % str(
		active_station_first_node_after_reset != null and active_station_first_node_after_reset.tip_position_local.is_equal_approx(expected_reset_tip)
	))
	lines.append("after_reset_first_node_pommel_matches_expected=%s" % str(
		after_reset_first_node != null and after_reset_first_node.pommel_position_local.is_equal_approx(expected_reset_pommel)
	))
	lines.append("after_reset_first_node_weapon_orientation_matches_expected=%s" % str(
		after_reset_first_node != null and after_reset_first_node.weapon_orientation_degrees.is_equal_approx(expected_reset_weapon_orientation)
	))
	lines.append("second_reset_ok=%s" % str(second_reset_ok))
	lines.append("repeated_reset_first_second_same=%s" % str(_reset_signatures_match(first_reset_signature, second_reset_signature)))
	lines.append("repeated_reset_seed_tip_stable=%s" % str(
		(seed_after_first_reset.get("tip_position_local", Vector3.ZERO) as Vector3).is_equal_approx(
			seed_after_second_reset.get("tip_position_local", Vector3.INF) as Vector3
		)
	))
	lines.append("repeated_reset_seed_pommel_stable=%s" % str(
		(seed_after_first_reset.get("pommel_position_local", Vector3.ZERO) as Vector3).is_equal_approx(
			seed_after_second_reset.get("pommel_position_local", Vector3.INF) as Vector3
		)
	))
	lines.append("repeated_reset_seed_orientation_stable=%s" % str(
		(seed_after_first_reset.get("weapon_orientation_degrees", Vector3.ZERO) as Vector3).is_equal_approx(
			seed_after_second_reset.get("weapon_orientation_degrees", Vector3.INF) as Vector3
		)
	))
	lines.append("persisted_file_slot_1_found=%s" % str(persisted_slot_1_anchor_index >= 0))
	lines.append("persisted_file_slot_1_two_hand=%s" % str(
		persisted_file_text.contains("two_hand_state = &\"two_hand_two_hand\"")
	))
	lines.append("persisted_file_slot_1_two_hand_only=%s" % str(
		persisted_file_text.contains("authored_for_two_hand_only = true")
	))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _build_test_baked_profile() -> BakedProfile:
	var profile: BakedProfile = BakedProfileScript.new()
	profile.primary_grip_valid = true
	profile.primary_grip_contact_position = Vector3.ZERO
	profile.primary_grip_span_start = Vector3(0.0, 0.0, 2.0)
	profile.primary_grip_span_end = Vector3(0.0, 0.0, -2.0)
	profile.primary_grip_axis_ratio_from_span_start = 0.5
	profile.primary_grip_slide_axis = Vector3(0.0, 0.0, -1.0)
	profile.primary_grip_two_hand_eligible = true
	profile.weapon_tip_point = Vector3(0.0, 0.0, -8.0)
	profile.weapon_pommel_point = Vector3(0.0, 0.0, 2.0)
	profile.weapon_total_length_meters = 0.125
	return profile

func _build_reset_signature(first_node: CombatAnimationMotionNode, second_node: CombatAnimationMotionNode) -> Dictionary:
	return {
		"first_tip": first_node.tip_position_local if first_node != null else Vector3.INF,
		"first_pommel": first_node.pommel_position_local if first_node != null else Vector3.INF,
		"first_orientation": first_node.weapon_orientation_degrees if first_node != null else Vector3.INF,
		"first_roll": first_node.weapon_roll_degrees if first_node != null else INF,
		"first_two_hand_state": first_node.two_hand_state if first_node != null else StringName(),
		"first_primary_hand": first_node.primary_hand_slot if first_node != null else StringName(),
		"second_tip": second_node.tip_position_local if second_node != null else Vector3.INF,
		"second_pommel": second_node.pommel_position_local if second_node != null else Vector3.INF,
		"second_orientation": second_node.weapon_orientation_degrees if second_node != null else Vector3.INF,
		"second_roll": second_node.weapon_roll_degrees if second_node != null else INF,
		"second_two_hand_state": second_node.two_hand_state if second_node != null else StringName(),
		"second_primary_hand": second_node.primary_hand_slot if second_node != null else StringName(),
	}

func _reset_signatures_match(first: Dictionary, second: Dictionary) -> bool:
	return (
		(first.get("first_tip", Vector3.INF) as Vector3).is_equal_approx(second.get("first_tip", Vector3.ZERO) as Vector3)
		and (first.get("first_pommel", Vector3.INF) as Vector3).is_equal_approx(second.get("first_pommel", Vector3.ZERO) as Vector3)
		and (first.get("first_orientation", Vector3.INF) as Vector3).is_equal_approx(second.get("first_orientation", Vector3.ZERO) as Vector3)
		and is_equal_approx(float(first.get("first_roll", INF)), float(second.get("first_roll", -INF)))
		and StringName(first.get("first_two_hand_state", StringName())) == StringName(second.get("first_two_hand_state", StringName()))
		and StringName(first.get("first_primary_hand", StringName())) == StringName(second.get("first_primary_hand", StringName()))
		and (first.get("second_tip", Vector3.INF) as Vector3).is_equal_approx(second.get("second_tip", Vector3.ZERO) as Vector3)
		and (first.get("second_pommel", Vector3.INF) as Vector3).is_equal_approx(second.get("second_pommel", Vector3.ZERO) as Vector3)
		and (first.get("second_orientation", Vector3.INF) as Vector3).is_equal_approx(second.get("second_orientation", Vector3.ZERO) as Vector3)
		and is_equal_approx(float(first.get("second_roll", INF)), float(second.get("second_roll", -INF)))
		and StringName(first.get("second_two_hand_state", StringName())) == StringName(second.get("second_two_hand_state", StringName()))
		and StringName(first.get("second_primary_hand", StringName())) == StringName(second.get("second_primary_hand", StringName()))
	)

func _find_skill_draft(skill_drafts: Array, skill_id: StringName) -> CombatAnimationDraft:
	for draft_variant: Variant in skill_drafts:
		var draft: CombatAnimationDraft = draft_variant as CombatAnimationDraft
		if draft != null and StringName(draft.owning_skill_id) == skill_id:
			return draft
	return null

func _get_motion_node(draft: CombatAnimationDraft, index: int) -> CombatAnimationMotionNode:
	if draft == null or index < 0 or index >= draft.motion_node_chain.size():
		return null
	return draft.motion_node_chain[index] as CombatAnimationMotionNode
