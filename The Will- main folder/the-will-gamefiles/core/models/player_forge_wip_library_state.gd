extends Resource
class_name PlayerForgeWipLibraryState

const DEFAULT_SAVE_FILE_PATH := "user://forge/player_wip_library_state.tres"
const PersistentResourceStateIOScript = preload("res://core/models/persistent_resource_state_io.gd")

@export var saved_wips: Array[CraftedItemWIP] = []
@export var unarmed_authoring_wip: CraftedItemWIP
@export var selected_wip_id: StringName = &""
@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH
@export var wip_id_generation_sequence: int = 0

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH):
	return PersistentResourceStateIOScript.load_or_create(save_path, "res://core/models/player_forge_wip_library_state.gd")

func has_saved_wips() -> bool:
	return not saved_wips.is_empty()

func get_saved_wips() -> Array[CraftedItemWIP]:
	return saved_wips

func get_saved_wip(saved_wip_id: StringName) -> CraftedItemWIP:
	for saved_wip: CraftedItemWIP in saved_wips:
		if saved_wip == null:
			continue
		if saved_wip.wip_id == saved_wip_id:
			return saved_wip
	return null

func get_saved_wip_clone(saved_wip_id: StringName, include_runtime_caches: bool = true) -> CraftedItemWIP:
	var saved_wip: CraftedItemWIP = get_saved_wip(saved_wip_id)
	if saved_wip == null:
		return null
	var saved_clone: CraftedItemWIP = _duplicate_wip_for_reader(saved_wip, include_runtime_caches)
	if saved_clone != null and saved_clone.has_method("ensure_combat_animation_station_state"):
		saved_clone.call("ensure_combat_animation_station_state")
	return saved_clone

func build_new_wip_id() -> StringName:
	return _build_generated_wip_id()

func get_unarmed_authoring_wip() -> CraftedItemWIP:
	if unarmed_authoring_wip != null:
		return unarmed_authoring_wip
	return get_saved_wip(CraftedItemWIP.UNARMED_AUTHORING_WIP_ID)

func get_unarmed_authoring_wip_clone(include_runtime_caches: bool = true) -> CraftedItemWIP:
	var source_wip: CraftedItemWIP = get_unarmed_authoring_wip()
	if source_wip == null:
		return null
	var saved_clone: CraftedItemWIP = _duplicate_wip_for_reader(source_wip, include_runtime_caches)
	if saved_clone != null and saved_clone.has_method("ensure_combat_animation_station_state"):
		saved_clone.call("ensure_combat_animation_station_state")
	return saved_clone

func get_saved_draft_runtime_clip_cache(
	saved_wip_id: StringName,
	draft_identifier: StringName,
	use_idle_identifier: bool = false
) -> Dictionary:
	var result := {
		"found": false,
		"runtime_clip": null,
		"runtime_cache_signature": "",
		"frame_count": 0,
	}
	var source_wip: CraftedItemWIP = get_saved_wip(saved_wip_id)
	if source_wip == null and saved_wip_id == CraftedItemWIP.UNARMED_AUTHORING_WIP_ID:
		source_wip = get_unarmed_authoring_wip()
	if source_wip == null or draft_identifier == StringName():
		return result
	var station_state: Resource = source_wip.combat_animation_station_state as Resource
	if station_state == null:
		return result
	var property_name: StringName = &"idle_drafts" if use_idle_identifier else &"skill_drafts"
	var drafts: Array = station_state.get(property_name) as Array
	for draft_variant: Variant in drafts:
		var draft: Resource = draft_variant as Resource
		if draft == null:
			continue
		var candidate_identifier: StringName = StringName(draft.get("context_id")) if use_idle_identifier else StringName(draft.get("owning_skill_id"))
		if candidate_identifier != draft_identifier:
			continue
		var runtime_clip = draft.get("baked_runtime_clip")
		if runtime_clip == null:
			return result
		var runtime_clip_copy = runtime_clip.call("duplicate_clip") if runtime_clip.has_method("duplicate_clip") else runtime_clip.duplicate(true)
		if runtime_clip_copy == null:
			return result
		result["found"] = true
		result["runtime_clip"] = runtime_clip_copy
		result["runtime_cache_signature"] = String(draft.get("runtime_cache_signature")) if _resource_has_property(draft, "runtime_cache_signature") else ""
		if runtime_clip_copy.has_method("get_frame_count"):
			result["frame_count"] = int(runtime_clip_copy.call("get_frame_count"))
		return result
	return result

func save_wip(source_wip: CraftedItemWIP) -> CraftedItemWIP:
	if source_wip == null:
		return null
	if CraftedItemWIP.is_unarmed_authoring_wip(source_wip):
		return save_unarmed_authoring_wip(source_wip)
	var saved_clone: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	var resolved_wip_id: StringName = _resolve_saved_wip_id(saved_clone)
	saved_clone.wip_id = resolved_wip_id
	saved_clone.forge_project_name = _resolve_forge_project_name(saved_clone)
	saved_clone.forge_project_notes = _resolve_forge_project_notes(saved_clone)
	saved_clone.stow_position_mode = CraftedItemWIP.normalize_stow_position_mode(saved_clone.stow_position_mode)
	saved_clone.grip_style_mode = CraftedItemWIP.resolve_supported_grip_style(
		saved_clone.grip_style_mode,
		saved_clone.forge_intent,
		saved_clone.equipment_context
	)
	if saved_clone.has_method("ensure_combat_animation_station_state"):
		saved_clone.call("ensure_combat_animation_station_state")
	var existing_index: int = _find_saved_wip_index(resolved_wip_id)
	var previous_saved_wip: CraftedItemWIP = (
		saved_wips[existing_index]
		if existing_index >= 0
		else null
	)
	var previous_selected_wip_id := selected_wip_id
	if existing_index >= 0:
		saved_wips[existing_index] = saved_clone
	else:
		saved_wips.append(saved_clone)
	selected_wip_id = resolved_wip_id
	if not persist():
		selected_wip_id = previous_selected_wip_id
		if existing_index >= 0:
			saved_wips[existing_index] = previous_saved_wip
		else:
			saved_wips.remove_at(saved_wips.size() - 1)
		return null
	return saved_clone.duplicate(true) as CraftedItemWIP

func save_unarmed_authoring_wip(source_wip: CraftedItemWIP) -> CraftedItemWIP:
	if source_wip == null:
		return null
	var saved_clone: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	saved_clone.wip_id = CraftedItemWIP.UNARMED_AUTHORING_WIP_ID
	saved_clone.forge_project_name = "- Unarmed"
	saved_clone.forge_intent = CraftedItemWIP.FORGE_INTENT_UNARMED
	saved_clone.equipment_context = CraftedItemWIP.EQUIPMENT_CONTEXT_UNARMED
	saved_clone.forge_builder_path_id = CraftedItemWIP.BUILDER_PATH_MELEE
	saved_clone.forge_builder_component_id = CraftedItemWIP.BUILDER_COMPONENT_PRIMARY
	saved_clone.grip_style_mode = CraftedItemWIP.GRIP_NORMAL
	saved_clone.latest_baked_profile_snapshot = null
	saved_clone.layers.clear()
	if saved_clone.has_method("ensure_combat_animation_station_state"):
		saved_clone.call("ensure_combat_animation_station_state")
	var previous_unarmed_wip := unarmed_authoring_wip
	var previous_selected_wip_id := selected_wip_id
	unarmed_authoring_wip = saved_clone
	selected_wip_id = CraftedItemWIP.UNARMED_AUTHORING_WIP_ID
	if not persist():
		unarmed_authoring_wip = previous_unarmed_wip
		selected_wip_id = previous_selected_wip_id
		return null
	return saved_clone.duplicate(true) as CraftedItemWIP

func duplicate_saved_wip(saved_wip_id: StringName) -> CraftedItemWIP:
	var source_wip: CraftedItemWIP = get_saved_wip(saved_wip_id)
	if source_wip == null:
		return null
	var duplicate_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	duplicate_wip.wip_id = _build_generated_wip_id()
	duplicate_wip.forge_project_name = _build_duplicate_project_name(duplicate_wip.forge_project_name)
	duplicate_wip.forge_project_notes = _resolve_forge_project_notes(duplicate_wip)
	duplicate_wip.stow_position_mode = CraftedItemWIP.normalize_stow_position_mode(duplicate_wip.stow_position_mode)
	duplicate_wip.grip_style_mode = CraftedItemWIP.resolve_supported_grip_style(
		duplicate_wip.grip_style_mode,
		duplicate_wip.forge_intent,
		duplicate_wip.equipment_context
	)
	if duplicate_wip.has_method("ensure_combat_animation_station_state"):
		duplicate_wip.call("ensure_combat_animation_station_state")
	var previous_selected_wip_id := selected_wip_id
	saved_wips.append(duplicate_wip)
	selected_wip_id = duplicate_wip.wip_id
	if not persist():
		saved_wips.remove_at(saved_wips.size() - 1)
		selected_wip_id = previous_selected_wip_id
		return null
	return duplicate_wip.duplicate(true) as CraftedItemWIP

func rename_saved_wip(
	saved_wip_id: StringName,
	requested_name: String
) -> CraftedItemWIP:
	var saved_index: int = _find_saved_wip_index(saved_wip_id)
	var cleaned_name := requested_name.strip_edges()
	if saved_index < 0 or cleaned_name.is_empty():
		return null
	var source_wip: CraftedItemWIP = saved_wips[saved_index]
	if source_wip == null or CraftedItemWIP.is_unarmed_authoring_wip(source_wip):
		return null
	var renamed_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	if renamed_wip == null:
		return null
	renamed_wip.forge_project_name = cleaned_name
	if renamed_wip.forge_v2_authoring_state != null:
		renamed_wip.forge_v2_authoring_state.set("project_name", cleaned_name)
		if renamed_wip.forge_v2_authoring_state.has_method("normalize"):
			renamed_wip.forge_v2_authoring_state.call("normalize")
	saved_wips[saved_index] = renamed_wip
	if not persist():
		saved_wips[saved_index] = source_wip
		return null
	return renamed_wip.duplicate(true) as CraftedItemWIP

func delete_saved_wip(
	saved_wip_id: StringName,
	select_fallback: bool = true
) -> bool:
	var saved_index: int = _find_saved_wip_index(saved_wip_id)
	if saved_index < 0:
		return false
	var deleted_wip: CraftedItemWIP = saved_wips[saved_index]
	var previous_selected_wip_id := selected_wip_id
	saved_wips.remove_at(saved_index)
	if selected_wip_id == saved_wip_id:
		selected_wip_id = (
			saved_wips[0].wip_id
			if (
				select_fallback
				and not saved_wips.is_empty()
				and saved_wips[0] != null
			)
			else StringName()
		)
	if not persist():
		saved_wips.insert(saved_index, deleted_wip)
		selected_wip_id = previous_selected_wip_id
		return false
	return true

func set_selected_wip_id(saved_wip_id: StringName, persist_selection: bool = true) -> void:
	if selected_wip_id == saved_wip_id:
		return
	selected_wip_id = saved_wip_id
	if persist_selection:
		persist()

func persist() -> bool:
	return PersistentResourceStateIOScript.persist_resource(self, save_file_path)

func _duplicate_wip_for_reader(source_wip: CraftedItemWIP, include_runtime_caches: bool) -> CraftedItemWIP:
	if source_wip == null:
		return null
	if include_runtime_caches:
		return source_wip.duplicate(true) as CraftedItemWIP
	var authoring_clone: CraftedItemWIP = source_wip.duplicate(false) as CraftedItemWIP
	if authoring_clone == null:
		return null
	var station_state: Resource = source_wip.combat_animation_station_state as Resource
	if station_state != null:
		var station_clone: Resource = station_state.duplicate(true) as Resource
		_clear_station_runtime_clip_caches(station_clone)
		authoring_clone.combat_animation_station_state = station_clone
	return authoring_clone

func _clear_station_runtime_clip_caches(station_state: Resource) -> void:
	if station_state == null:
		return
	for property_name in [&"skill_drafts", &"idle_drafts"]:
		var drafts: Array = station_state.get(property_name) as Array
		for draft_variant: Variant in drafts:
			var draft: Resource = draft_variant as Resource
			if draft == null:
				continue
			draft.set("baked_runtime_clip", null)
			if _resource_has_property(draft, "runtime_cache_signature"):
				draft.set("runtime_cache_signature", "")

func _resource_has_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false
	for property_info: Dictionary in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false

func _find_saved_wip_index(saved_wip_id: StringName) -> int:
	for index: int in range(saved_wips.size()):
		var saved_wip: CraftedItemWIP = saved_wips[index]
		if saved_wip == null:
			continue
		if saved_wip.wip_id == saved_wip_id:
			return index
	return -1

func _resolve_saved_wip_id(saved_wip: CraftedItemWIP) -> StringName:
	if saved_wip == null:
		return StringName()
	var current_wip_id_text: String = String(saved_wip.wip_id)
	if current_wip_id_text.is_empty() or current_wip_id_text.begins_with("debug_") or current_wip_id_text.begins_with("draft_"):
		return _build_generated_wip_id()
	return saved_wip.wip_id

func _resolve_forge_project_name(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return _build_generated_project_name()
	var cleaned_name: String = saved_wip.forge_project_name.strip_edges()
	if cleaned_name.is_empty():
		return _build_generated_project_name()
	return cleaned_name

func _resolve_forge_project_notes(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return ""
	return saved_wip.forge_project_notes.strip_edges()

func _build_generated_wip_id() -> StringName:
	wip_id_generation_sequence += 1
	var base_id := "player_wip_%s_%d" % [
		str(Time.get_unix_time_from_system()),
		wip_id_generation_sequence,
	]
	var candidate := StringName(base_id)
	while _find_saved_wip_index(candidate) >= 0:
		wip_id_generation_sequence += 1
		candidate = StringName("%s_%d" % [
			base_id,
			wip_id_generation_sequence,
		])
	return candidate

func _build_generated_project_name() -> String:
	return "Forge Project %03d" % (saved_wips.size() + 1)

func _build_duplicate_project_name(project_name: String) -> String:
	var cleaned_name: String = project_name.strip_edges()
	if cleaned_name.is_empty():
		cleaned_name = _build_generated_project_name()
	return "%s Copy" % cleaned_name
