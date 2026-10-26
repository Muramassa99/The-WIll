extends SceneTree

const DraftScript = preload("res://core/models/combat_animation_draft.gd")
const MotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const StationScript = preload("res://core/models/combat_animation_station_state.gd")
const LibraryScript = preload("res://core/models/player_forge_wip_library_state.gd")
const WipScript = preload("res://core/models/crafted_item_wip.gd")
const ClipScript = preload("res://core/models/combat_runtime_clip.gd")
const CompilerScript = preload("res://core/resolvers/combat_animation_runtime_chain_compiler.gd")

const DEFAULT_OUTPUT_DIR := "C:/WORKSPACE/godot_runs/skill_transition_20261023/action_storage"
var checks: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir: String = DEFAULT_OUTPUT_DIR
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var skill = _make_skill()
	var before: Dictionary = _snapshot(skill)
	var visible_before: Array = _nodes_snapshot(skill.get_action_motion_node_chain())
	var editor_duplicate = skill.duplicate(true)
	_expect(_snapshot(editor_duplicate) == before, "ordinary_deep_duplicate_preserves_full_editor_state")
	_expect(editor_duplicate.motion_node_chain[0] != skill.motion_node_chain[0], "deep_duplicate_does_not_share_reset_resource")
	_expect(editor_duplicate.motion_node_chain[1] != skill.motion_node_chain[1], "deep_duplicate_does_not_share_visible_resource")
	var action_array: Array = skill.get_action_motion_node_chain()
	action_array.pop_back()
	_expect(skill.motion_node_chain.size() == 3, "action_array_membership_does_not_mutate_editor_array")

	# Legacy text resources still carry the old exported motion_node_chain.
	# Direct ResourceSaver callers deliberately opt into action storage below.
	var legacy_path: String = output_dir.path_join("legacy_editor_draft.tres")
	_expect(ResourceSaver.save(skill, legacy_path) == OK, "legacy_resource_save")
	var legacy = ResourceLoader.load(legacy_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(legacy != null and _snapshot(legacy) == before, "legacy_resource_load_preserves_all_nodes")
	_expect(legacy != null and _nodes_snapshot(legacy.get_action_motion_node_chain()) == visible_before, "legacy_load_exposes_visible_action_only")

	skill.begin_action_storage()
	skill.begin_action_storage()
	skill.end_action_storage()
	_expect(_has_storage(skill, &"action_motion_node_chain") and not _has_storage(skill, &"motion_node_chain"), "nested_storage_mode_remains_active")
	var action_path: String = output_dir.path_join("action_only_draft.tres")
	_expect(ResourceSaver.save(skill, action_path) == OK, "action_only_resource_save")
	skill.end_action_storage()
	_expect(_has_storage(skill, &"motion_node_chain") and not _has_storage(skill, &"action_motion_node_chain"), "storage_mode_restores_default_usage")
	_expect(_snapshot(skill) == before, "serialization_does_not_mutate_editor_state")
	var action_text: String = FileAccess.get_file_as_string(action_path)
	_expect(action_text.contains("action_motion_node_chain =") and not action_text.contains("RESET_BASELINE_MUST_NOT_BE_STORED"), "saved_action_excludes_reset_resource")
	var loaded = ResourceLoader.load(action_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(loaded != null and loaded.motion_node_chain.size() == 3, "action_load_reconstructs_editor_placeholder")
	_expect(loaded != null and _nodes_snapshot(loaded.get_action_motion_node_chain()) == visible_before, "action_save_load_preserves_every_visible_field")
	_expect(loaded != null and loaded.motion_node_chain[0].tip_position_local == Vector3.ZERO, "loaded_reset_placeholder_is_neutral")
	_expect(loaded != null and _snapshot(loaded.duplicate(true)) == _snapshot(loaded), "loaded_action_deep_copy_preserves_editor_numbering")
	var seed_draft = DraftScript.create_default_skill_baseline(&"untouched_slot", "Untouched", &"skill_slot_2")
	_expect(not seed_draft.is_publishable_skill_draft(), "untouched_legacy_seed_is_unpublished")
	seed_draft.begin_action_storage()
	var seed_path: String = output_dir.path_join("untouched_action.tres")
	_expect(ResourceSaver.save(seed_draft, seed_path) == OK, "untouched_action_save")
	seed_draft.end_action_storage()
	var loaded_seed = ResourceLoader.load(seed_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(loaded_seed != null and not loaded_seed.is_publishable_skill_draft(), "action_roundtrip_does_not_publish_untouched_slot")
	_expect(loaded_seed != null and loaded_seed.needs_weapon_geometry_seed(), "unseeded_action_still_requests_weapon_geometry")
	if loaded_seed != null:
		var copied_seed = loaded_seed.duplicate(true)
		_expect(not copied_seed.is_publishable_skill_draft(), "duplicate_preserves_unpublished_action_state")
		copied_seed.motion_node_chain[1].body_support_blend = 0.5
		_expect(copied_seed.is_publishable_skill_draft(), "editing_loaded_default_makes_action_publishable")
		copied_seed.reset_to_default_baseline()
		_expect(not copied_seed.is_publishable_skill_draft(), "reset_clears_imported_baseline_signature")
		# SC-01 capture completion is separate from changing authored controls.
		# This storage test exercises that durable marker only; the real station
		# lifecycle verifier proves a capture actually occurred before Save.
		var initialized_default = loaded_seed.duplicate(true)
		var initialized_visible_before: Array = _nodes_snapshot(initialized_default.get_action_motion_node_chain())
		initialized_default.authoring_pose_initialized = true
		_expect(initialized_default.is_publishable_skill_draft(), "initialized_unchanged_default_is_publishable")
		initialized_default.begin_action_storage()
		var initialized_path: String = output_dir.path_join("initialized_default_action.tres")
		_expect(ResourceSaver.save(initialized_default, initialized_path) == OK, "initialized_default_action_save")
		initialized_default.end_action_storage()
		var loaded_initialized = ResourceLoader.load(initialized_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_expect(loaded_initialized != null and loaded_initialized.authoring_pose_initialized, "initialized_default_marker_survives_disk_reload")
		_expect(loaded_initialized != null and loaded_initialized.is_publishable_skill_draft(), "initialized_default_remains_publishable_after_reload")
		_expect(loaded_initialized != null and _nodes_snapshot(loaded_initialized.get_action_motion_node_chain()) == initialized_visible_before, "initialized_default_preserves_unchanged_visible_controls")
		if loaded_initialized != null:
			loaded_initialized.reset_to_default_baseline()
			_expect(not loaded_initialized.authoring_pose_initialized and not loaded_initialized.is_publishable_skill_draft(), "reset_clears_initialized_default_marker")

	var idle = DraftScript.new()
	idle.draft_kind = DraftScript.DRAFT_KIND_IDLE
	idle.context_id = DraftScript.IDLE_CONTEXT_COMBAT
	idle.motion_node_chain.assign([_make_node(0, &"IDLE_POSE_MUST_REMAIN", Vector3(0.25, 0.5, 0.75))])
	var idle_before: Dictionary = _snapshot(idle)
	idle.begin_action_storage()
	var idle_path: String = output_dir.path_join("idle_draft.tres")
	_expect(ResourceSaver.save(idle, idle_path) == OK, "idle_resource_save")
	idle.end_action_storage()
	var loaded_idle = ResourceLoader.load(idle_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(loaded_idle != null and _snapshot(loaded_idle) == idle_before, "idle_first_pose_is_never_removed")

	var one_pose = DraftScript.new()
	one_pose.motion_node_chain.assign([skill.motion_node_chain[0].duplicate(true), skill.motion_node_chain[1].duplicate(true)])
	var one_pose_before: Dictionary = _snapshot(one_pose)
	var compiler = CompilerScript.new()
	var compiled: Dictionary = compiler.compile_skill_chain(one_pose.get_action_motion_node_chain(), 0.5)
	var compiled_nodes: Array = compiled.get("motion_node_chain", [])
	_expect(bool(compiled.get("compiled", false)) and compiled_nodes.size() == 1, "single_visible_pose_compiles_as_action")
	_expect(compiled_nodes.size() == 1 and compiled_nodes[0] != one_pose.motion_node_chain[1], "compiler_derives_separate_runtime_pose")
	_expect(_snapshot(one_pose) == one_pose_before, "compiler_preserves_single_pose_authoring")
	_expect(not bool(compiler.compile_skill_chain([], 0.5).get("compiled", false)), "empty_action_is_rejected")
	one_pose.begin_action_storage()
	var one_pose_path: String = output_dir.path_join("single_pose_action.tres")
	_expect(ResourceSaver.save(one_pose, one_pose_path) == OK, "authored_single_pose_action_save")
	one_pose.end_action_storage()
	var loaded_one_pose = ResourceLoader.load(one_pose_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(loaded_one_pose != null and loaded_one_pose.is_publishable_skill_draft(), "authored_single_pose_remains_publishable_after_load")

	var stale = _make_skill()
	stale.draft_id = &"stale_cache_skill"
	var stale_clip = ClipScript.new()
	stale_clip.motion_node_chain.assign([_make_node(0, &"STALE_CACHE_BASELINE_MUST_NOT_BE_STORED", Vector3.ONE)])
	stale.baked_runtime_clip = stale_clip
	stale.runtime_cache_signature = "runtime_cache_v10_explicit_terminal_frame|old_grip|old_nodes"
	var current_clip = ClipScript.new()
	current_clip.motion_node_chain.assign(skill.get_action_motion_node_chain().duplicate(true))
	skill.baked_runtime_clip = current_clip
	skill.runtime_cache_signature = ClipScript.RUNTIME_CACHE_VERSION + "|test_grip|visible_nodes"
	var station = StationScript.new()
	station.skill_drafts.assign([skill, stale, one_pose])
	station.idle_drafts.assign([idle])
	var wip = WipScript.new()
	wip.wip_id = WipScript.UNARMED_AUTHORING_WIP_ID
	wip.forge_intent = WipScript.FORGE_INTENT_UNARMED
	wip.combat_animation_station_state = station
	var library = LibraryScript.new()
	library.unarmed_authoring_wip = wip
	library.save_file_path = output_dir.path_join("library.tres")
	var library_before: Dictionary = _snapshot(library)
	_expect(library.persist(), "library_persist_uses_action_storage")
	_expect(_snapshot(library) == library_before, "library_persist_keeps_live_reset_and_old_cache_intact")
	var library_text: String = FileAccess.get_file_as_string(library.save_file_path)
	_expect(not library_text.contains("RESET_BASELINE_MUST_NOT_BE_STORED"), "library_save_excludes_all_reset_nodes")
	_expect(not library_text.contains("STALE_CACHE_BASELINE_MUST_NOT_BE_STORED"), "library_save_omits_obsolete_reset_bearing_clip")
	var loaded_library = ResourceLoader.load(library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded_library != null:
		var loaded_station = loaded_library.unarmed_authoring_wip.combat_animation_station_state
		var loaded_skill = loaded_station.skill_drafts[0]
		var loaded_stale = loaded_station.skill_drafts[1]
		_expect(_nodes_snapshot(loaded_skill.get_action_motion_node_chain()) == visible_before, "library_roundtrip_preserves_visible_skill")
		_expect(loaded_skill.baked_runtime_clip != null and loaded_skill.runtime_cache_signature == skill.runtime_cache_signature, "library_roundtrip_preserves_current_cache")
		_expect(loaded_stale.baked_runtime_clip == null and loaded_stale.runtime_cache_signature.is_empty(), "library_roundtrip_discards_stale_cache_only")
		_expect(loaded_station.idle_drafts[0].motion_node_chain.size() == 1, "library_roundtrip_preserves_idle_pose")
	else:
		_expect(false, "library_resource_load")

	# An unsupported output extension causes a genuine synchronous save failure.
	# The error is expected; storage mode must still be restored for all drafts.
	library.save_file_path = output_dir.path_join("failure.unsupported_resource_extension")
	_expect(not library.persist(), "intentional_save_failure_reported")
	_expect(_has_storage(skill, &"motion_node_chain") and not _has_storage(skill, &"action_motion_node_chain"), "failed_save_restores_editor_storage_mode")
	_expect(_snapshot(skill.duplicate(true)) == _snapshot(skill), "failed_save_does_not_damage_subsequent_deep_copy")
	_expect(stale.baked_runtime_clip == stale_clip, "failed_save_preserves_live_old_cache_reference")
	var ok: bool = true
	for passed: bool in checks.values():
		ok = ok and passed
	var result: Dictionary = {"ok": ok, "checks": checks, "check_count": checks.size(), "intentional_save_failure_expected": true}
	var output: FileAccess = FileAccess.open(output_dir.path_join("results.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(result, "\t"))
		output.close()
	print("COMBAT_ACTION_STORAGE ", JSON.stringify(result))
	quit(0 if ok else 1)

func _make_skill():
	var skill = DraftScript.new()
	skill.draft_id = &"action_storage_skill"
	skill.owning_skill_id = &"skill_slot_1"
	skill.legal_slot_id = &"skill_slot_1"
	skill.selected_motion_node_index = 2
	skill.motion_node_chain.assign([
		_make_node(0, &"RESET_BASELINE_MUST_NOT_BE_STORED", Vector3(7, 8, 9)),
		_make_node(1, &"visible_node_one", Vector3(0.25, 0.5, 0.75)),
		_make_node(2, &"visible_node_two", Vector3(-0.25, 0.25, -0.5)),
	])
	return skill

func _make_node(index: int, id: StringName, position: Vector3):
	var node = MotionNodeScript.new()
	node.node_id = id
	node.node_index = index
	node.tip_position_local = position
	node.pommel_position_local = position + Vector3(0, 0, 0.5)
	node.tip_curve_in_handle = Vector3(0.125, -0.25, 0.5)
	node.pommel_curve_out_handle = Vector3(-0.5, 0.25, -0.125)
	node.transition_duration_seconds = 0.25 * (index + 1)
	node.grip_seat_slide_offset = 0.5
	node.secondary_grip_seat_slide_offset = 0.25
	node.weapon_roll_degrees = -67.5
	node.right_upperarm_roll_degrees = 112.5
	node.left_hand_proxy_authored = true
	node.left_hand_proxy_tip_position_local = Vector3(0.25, 0.75, -0.25)
	return node

func _has_storage(resource: Resource, property_name: StringName) -> bool:
	for property: Dictionary in resource.get_property_list():
		if StringName(property.name) == property_name:
			return (int(property.usage) & PROPERTY_USAGE_STORAGE) != 0
	return false

func _snapshot(resource: Resource) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		var property_name: StringName = StringName(property.name)
		if property_name in [&"script", &"resource_path", &"resource_scene_unique_id"] or (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		result[property_name] = _snapshot_value(resource.get(property_name))
	return result

func _nodes_snapshot(nodes: Array) -> Array:
	var result: Array = []
	for node: Resource in nodes:
		result.append(_snapshot(node) if node != null else null)
	return result

func _snapshot_value(value: Variant) -> Variant:
	if value is Resource:
		return _snapshot(value as Resource)
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_snapshot_value(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _snapshot_value(value[key])
		return result
	return value

func _expect(passed: bool, label: String) -> void:
	checks[label] = passed
	if not passed:
		print("FAILED: ", label)
