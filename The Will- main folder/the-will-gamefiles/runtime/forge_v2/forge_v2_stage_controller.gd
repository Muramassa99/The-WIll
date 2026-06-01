extends Node
class_name ForgeV2StageController

signal authoring_state_changed(state)
signal placement_cursor_changed(local_position: Vector3, is_valid: bool, radius_meters: float)

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const ForgeV2AuthoringStateScript = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const ForgeV2WorkspaceContractScript = preload("res://runtime/forge_v2/forge_v2_workspace_contract.gd")

@export var default_project_name: String = "Stage 1 V2 Draft"

var active_authoring_state: Resource = null
var workspace_contract = null
var placement_cursor_local_position: Vector3 = Vector3.ZERO
var placement_cursor_valid: bool = false
var active_placement_body_id: StringName = StringName()
var active_saved_wip_id: StringName = StringName()

func _ready() -> void:
	ensure_workspace_contract()
	ensure_authoring_state(default_project_name)

func ensure_workspace_contract():
	if workspace_contract == null:
		workspace_contract = ForgeV2WorkspaceContractScript.new()
	workspace_contract.normalize()
	return workspace_contract

func get_workspace_contract():
	return ensure_workspace_contract()

func get_workspace_contract_summary() -> Dictionary:
	return ensure_workspace_contract().build_summary()

func get_freehand_smoothing_steps() -> int:
	return int(ensure_workspace_contract().get("freehand_smoothing_steps"))

func set_freehand_smoothing_steps(step_count: int) -> void:
	var contract = ensure_workspace_contract()
	contract.call("set_freehand_smoothing_steps", step_count)
	_emit_state_changed()

func ensure_authoring_state(project_name: String = "") -> Resource:
	var created_state := false
	if active_authoring_state == null:
		active_authoring_state = ForgeV2AuthoringStateScript.new()
		active_authoring_state.reset_new_draft(_resolve_project_name(project_name))
		active_saved_wip_id = StringName(active_authoring_state.get("source_wip_id"))
		created_state = true
	else:
		active_authoring_state.normalize()
	if created_state:
		_emit_state_changed()
	return active_authoring_state

func start_new_draft(project_name: String = "") -> Resource:
	active_placement_body_id = StringName()
	active_saved_wip_id = StringName()
	active_authoring_state = ForgeV2AuthoringStateScript.new()
	active_authoring_state.reset_new_draft(_resolve_project_name(project_name))
	_emit_state_changed()
	return active_authoring_state

func get_active_authoring_state() -> Resource:
	return ensure_authoring_state(default_project_name)

func get_active_saved_wip_id() -> StringName:
	return active_saved_wip_id

func build_crafted_item_wip_for_save() -> CraftedItemWIP:
	var state: Resource = ensure_authoring_state(default_project_name)
	if state == null:
		return null
	if state.has_method("normalize"):
		state.call("normalize")
	var saved_wip_id: StringName = active_saved_wip_id
	if saved_wip_id == StringName():
		saved_wip_id = StringName(state.get("source_wip_id"))
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = saved_wip_id if saved_wip_id != StringName() else StringName("draft_%s" % str(Time.get_unix_time_from_system()))
	wip.forge_project_name = _resolve_project_name(String(state.get("project_name")))
	wip.forge_project_notes = String(state.get("project_notes")).strip_edges()
	wip.creator_id = StringName(state.get("creator_id"))
	wip.created_timestamp = float(state.get("created_timestamp"))
	wip.forge_builder_path_id = CraftedItemWIPScript.normalize_builder_path_id(StringName(state.get("builder_path_id")))
	wip.forge_builder_component_id = CraftedItemWIPScript.normalize_builder_component_id(
		wip.forge_builder_path_id,
		StringName(state.get("builder_component_id"))
	)
	wip.forge_intent = StringName(state.get("forge_intent"))
	wip.equipment_context = StringName(state.get("equipment_context"))
	wip.forge_v2_authoring_state = state.duplicate(true) as Resource
	if wip.forge_v2_authoring_state != null:
		wip.forge_v2_authoring_state.set("source_wip_id", saved_wip_id)
		if wip.forge_v2_authoring_state.has_method("normalize"):
			wip.forge_v2_authoring_state.call("normalize")
	wip.layers = []
	wip.latest_baked_profile_snapshot = null
	if wip.has_method("ensure_combat_animation_station_state"):
		wip.call("ensure_combat_animation_station_state")
	return wip

func save_current_wip(wip_library) -> CraftedItemWIP:
	if wip_library == null or not wip_library.has_method("save_wip"):
		return null
	var wip: CraftedItemWIP = build_crafted_item_wip_for_save()
	if wip == null:
		return null
	var saved_wip: CraftedItemWIP = wip_library.call("save_wip", wip) as CraftedItemWIP
	if saved_wip == null:
		return null
	_stamp_saved_wip_id_into_v2_state(wip_library, saved_wip)
	load_saved_wip(saved_wip)
	return saved_wip

func load_saved_wip(saved_wip: CraftedItemWIP) -> bool:
	if saved_wip == null or saved_wip.forge_v2_authoring_state == null:
		return false
	var loaded_state: Resource = saved_wip.forge_v2_authoring_state.duplicate(true) as Resource
	if loaded_state == null:
		return false
	loaded_state.set("source_wip_id", saved_wip.wip_id)
	loaded_state.set("project_name", saved_wip.forge_project_name)
	loaded_state.set("project_notes", saved_wip.forge_project_notes)
	loaded_state.set("builder_path_id", saved_wip.forge_builder_path_id)
	loaded_state.set("builder_component_id", saved_wip.forge_builder_component_id)
	loaded_state.set("forge_intent", saved_wip.forge_intent)
	loaded_state.set("equipment_context", saved_wip.equipment_context)
	if loaded_state.has_method("normalize"):
		loaded_state.call("normalize")
	active_placement_body_id = StringName()
	active_saved_wip_id = saved_wip.wip_id
	active_authoring_state = loaded_state
	_emit_state_changed()
	return true

func set_builder_path_id(builder_path_id: StringName) -> void:
	var state: Resource = ensure_authoring_state(default_project_name)
	state.set_builder_path(builder_path_id)
	_emit_state_changed()

func set_builder_component_id(builder_component_id: StringName) -> void:
	var state: Resource = ensure_authoring_state(default_project_name)
	state.set_builder_component(builder_component_id)
	_emit_state_changed()

func set_active_operation_mode(operation_mode: StringName) -> void:
	var state: Resource = ensure_authoring_state(default_project_name)
	state.set_active_operation_mode(operation_mode)
	_emit_state_changed()

func set_placement_policy(placement_policy: StringName) -> void:
	var state: Resource = ensure_authoring_state(default_project_name)
	state.set_placement_policy(placement_policy)
	_emit_state_changed()

func set_active_primitive_id(primitive_id: StringName) -> void:
	var state: Resource = ensure_authoring_state(default_project_name)
	state.set_active_primitive_id(primitive_id)
	_emit_state_changed()

func set_active_tool_id(tool_id: StringName) -> void:
	active_placement_body_id = StringName()
	var state: Resource = ensure_authoring_state(default_project_name)
	state.set_active_tool_id(tool_id)
	_emit_state_changed()

func set_active_material_variant_id(material_variant_id: StringName) -> void:
	var state: Resource = ensure_authoring_state(default_project_name)
	state.set_active_material_variant_id(material_variant_id)
	_emit_state_changed()

func adjust_brush_radius_steps(step_count: int) -> void:
	var state: Resource = ensure_authoring_state(default_project_name)
	state.adjust_brush_radius_steps(step_count)
	_emit_state_changed()
	_emit_placement_cursor_changed()

func adjust_amount_ratio_steps(step_count: int) -> void:
	var state: Resource = ensure_authoring_state(default_project_name)
	state.adjust_amount_ratio_steps(step_count)
	_emit_state_changed()

func append_empty_volume_stroke() -> Resource:
	return append_empty_material_body()

func append_empty_material_body() -> Resource:
	var state: Resource = ensure_authoring_state(default_project_name)
	var body: Resource = state.append_empty_material_body()
	_emit_state_changed()
	return body

func append_sample_volume_stroke() -> Resource:
	return append_sample_material_body()

func append_sample_material_body() -> Resource:
	var state: Resource = ensure_authoring_state(default_project_name)
	var body: Resource = state.append_sample_material_body()
	_emit_state_changed()
	return body

func append_active_primitive_deposit() -> Array[Resource]:
	var state: Resource = ensure_authoring_state(default_project_name)
	var bodies: Array[Resource] = state.append_active_primitive_deposit()
	_emit_state_changed()
	return bodies

func append_point_volume_stroke(local_position: Vector3) -> Resource:
	return append_point_material_body(local_position)

func append_point_material_body(local_position: Vector3) -> Resource:
	var state: Resource = ensure_authoring_state(default_project_name)
	var body: Resource = state.append_point_material_body(local_position)
	placement_cursor_local_position = local_position
	placement_cursor_valid = true
	_emit_state_changed()
	_emit_placement_cursor_changed()
	return body

func begin_placement_stroke(local_position: Vector3) -> StringName:
	return begin_material_body_path(local_position)

func begin_material_body_path(local_position: Vector3) -> StringName:
	var state: Resource = ensure_authoring_state(default_project_name)
	var body: Resource = state.append_point_material_body(local_position)
	active_placement_body_id = StringName(body.get("body_id")) if body != null else StringName()
	placement_cursor_local_position = local_position
	placement_cursor_valid = true
	_emit_state_changed()
	_emit_placement_cursor_changed()
	return active_placement_body_id

func extend_placement_stroke(local_position: Vector3, force_endpoint: bool = false) -> bool:
	return extend_material_body_path(local_position, force_endpoint)

func extend_material_body_path(local_position: Vector3, force_endpoint: bool = false) -> bool:
	if active_placement_body_id == StringName():
		begin_material_body_path(local_position)
		return true
	var state: Resource = ensure_authoring_state(default_project_name)
	var sample_spacing: float = ensure_workspace_contract().resolve_stroke_sample_spacing(_get_active_brush_radius_meters())
	var changed: bool = bool(state.call(
		"append_point_to_material_body",
		active_placement_body_id,
		local_position,
		sample_spacing,
		force_endpoint
	))
	placement_cursor_local_position = local_position
	placement_cursor_valid = true
	if changed:
		_emit_state_changed()
	_emit_placement_cursor_changed()
	return changed

func finish_placement_stroke(local_position: Vector3 = Vector3.ZERO, has_final_position: bool = false) -> bool:
	return finish_material_body_path(local_position, has_final_position)

func finish_material_body_path(local_position: Vector3 = Vector3.ZERO, has_final_position: bool = false) -> bool:
	var had_active_body := active_placement_body_id != StringName()
	var changed := false
	if had_active_body and has_final_position:
		var state: Resource = ensure_authoring_state(default_project_name)
		var sample_spacing: float = ensure_workspace_contract().resolve_stroke_sample_spacing(_get_active_brush_radius_meters())
		changed = bool(state.call(
			"append_point_to_material_body",
			active_placement_body_id,
			local_position,
			sample_spacing,
			true
		))
		placement_cursor_local_position = local_position
		placement_cursor_valid = true
	active_placement_body_id = StringName()
	if changed or had_active_body:
		_emit_state_changed()
	_emit_placement_cursor_changed()
	return changed or had_active_body

func get_active_placement_body_id() -> StringName:
	return active_placement_body_id

func is_material_body_path_active() -> bool:
	return active_placement_body_id != StringName()

func append_spline_line_point(local_position: Vector3) -> int:
	active_placement_body_id = StringName()
	var state: Resource = ensure_authoring_state(default_project_name)
	var point_index: int = int(state.call("append_spline_line_point", local_position))
	placement_cursor_local_position = local_position
	placement_cursor_valid = true
	if point_index >= 0:
		_emit_state_changed()
	_emit_placement_cursor_changed()
	return point_index

func set_spline_line_point(point_index: int, local_position: Vector3) -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.call("set_spline_line_point", point_index, local_position))
	placement_cursor_local_position = local_position
	placement_cursor_valid = true
	if changed:
		_emit_state_changed()
	_emit_placement_cursor_changed()
	return changed

func select_spline_line_point(point_index: int) -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.call("select_spline_line_point", point_index))
	if changed:
		_emit_state_changed()
	return changed

func find_nearest_spline_line_point(local_position: Vector3, max_distance_meters: float = -1.0) -> int:
	var state: Resource = ensure_authoring_state(default_project_name)
	var selection_radius := max_distance_meters if max_distance_meters > 0.0 else _get_spline_selection_radius_meters()
	return int(state.call("find_nearest_spline_line_point", local_position, selection_radius))

func get_spline_point_selection_radius_meters() -> float:
	return _get_spline_selection_radius_meters()

func finish_spline_line() -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.call("finish_spline_line"))
	if changed:
		_emit_state_changed()
	return changed

func cancel_spline_line() -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.call("cancel_spline_line"))
	if changed:
		_emit_state_changed()
	return changed

func generate_spline_line_csg_noodle() -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.call("generate_spline_line_csg_noodle"))
	if changed:
		_emit_state_changed()
	return changed

func clear_spline_line_csg_noodle() -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.call("clear_spline_line_csg_noodle"))
	if changed:
		_emit_state_changed()
	return changed

func clear_volume_strokes() -> void:
	clear_pending_material_bodies()

func clear_pending_material_bodies() -> void:
	active_placement_body_id = StringName()
	var state: Resource = ensure_authoring_state(default_project_name)
	state.clear_pending_material_bodies()
	_emit_state_changed()

func commit_pending_material_bodies_as_layer() -> Resource:
	var state: Resource = ensure_authoring_state(default_project_name)
	var layer: Resource = state.commit_pending_material_bodies_as_layer()
	if layer != null:
		_emit_state_changed()
	return layer

func undo_latest_layer() -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.undo_latest_layer())
	if changed:
		_emit_state_changed()
	return changed

func redo_latest_layer() -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.redo_latest_layer())
	if changed:
		_emit_state_changed()
	return changed

func select_material_body_id(body_id: StringName) -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.select_material_body(body_id))
	if changed:
		_emit_state_changed()
	return changed

func select_next_material_body(step_count: int = 1) -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.select_next_material_body(step_count))
	if changed:
		_emit_state_changed()
	return changed

func remove_selected_material_body() -> bool:
	var state: Resource = ensure_authoring_state(default_project_name)
	var changed: bool = bool(state.remove_selected_material_body())
	if changed:
		_emit_state_changed()
	return changed

func set_placement_cursor_local_position(local_position: Vector3, is_valid: bool = true) -> void:
	placement_cursor_local_position = local_position
	placement_cursor_valid = is_valid
	_emit_placement_cursor_changed()

func clear_placement_cursor() -> void:
	placement_cursor_valid = false
	_emit_placement_cursor_changed()

func get_placement_cursor_state() -> Dictionary:
	return {
		"local_position": placement_cursor_local_position,
		"is_valid": placement_cursor_valid,
		"radius_meters": _get_active_brush_radius_meters(),
	}

func get_status_summary() -> Dictionary:
	var include_material_usage := active_placement_body_id == StringName()
	return ensure_authoring_state(default_project_name).get_status_summary(include_material_usage)

func get_builder_path_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for builder_path_id: StringName in CraftedItemWIPScript.get_builder_path_ids():
		options.append({
			"id": builder_path_id,
			"label": CraftedItemWIPScript.get_builder_path_label(builder_path_id),
		})
	return options

func get_builder_component_options() -> Array[Dictionary]:
	var state: Resource = ensure_authoring_state(default_project_name)
	var builder_path_id: StringName = StringName(state.get("builder_path_id"))
	var options: Array[Dictionary] = []
	for builder_component_id: StringName in CraftedItemWIPScript.get_builder_component_ids(builder_path_id):
		options.append({
			"id": builder_component_id,
			"label": CraftedItemWIPScript.get_builder_component_label(builder_path_id, builder_component_id),
		})
	return options

func get_primitive_options() -> Array[Dictionary]:
	var state: Resource = ensure_authoring_state(default_project_name)
	return state.get_primitive_options()

func get_tool_options() -> Array[Dictionary]:
	var state: Resource = ensure_authoring_state(default_project_name)
	return state.get_tool_options()

func get_material_palette_options() -> Array[Dictionary]:
	var state: Resource = ensure_authoring_state(default_project_name)
	return state.get_material_palette_options()

func get_material_tier_policy_summary() -> Dictionary:
	var state: Resource = ensure_authoring_state(default_project_name)
	return state.get_material_tier_policy_summary()

func get_operation_options() -> Array[Dictionary]:
	return [
		{
			"id": ForgeV2AuthoringStateScript.OPERATION_ADD_MATERIAL,
			"label": "Add Material",
		},
		{
			"id": ForgeV2AuthoringStateScript.OPERATION_REMOVE_MATERIAL,
			"label": "Remove Material",
		},
	]

func get_placement_policy_options() -> Array[Dictionary]:
	return [
		{
			"id": ForgeV2AuthoringStateScript.PLACEMENT_REPLACE_EXISTING,
			"label": "Replace Existing",
		},
		{
			"id": ForgeV2AuthoringStateScript.PLACEMENT_EMPTY_ONLY,
			"label": "Empty Space Only",
		},
	]

func get_material_body_stack_options() -> Array[Dictionary]:
	var state: Resource = ensure_authoring_state(default_project_name)
	return state.get_material_body_stack_entries()

func build_authoring_export_snapshot() -> Dictionary:
	return ensure_authoring_state(default_project_name).build_authoring_export_snapshot()

func _resolve_project_name(project_name: String) -> String:
	var stripped_project_name := project_name.strip_edges()
	return stripped_project_name if not stripped_project_name.is_empty() else default_project_name

func _stamp_saved_wip_id_into_v2_state(wip_library, saved_wip: CraftedItemWIP) -> void:
	if wip_library == null or saved_wip == null or saved_wip.wip_id == StringName():
		return
	var changed := false
	if saved_wip.forge_v2_authoring_state != null and StringName(saved_wip.forge_v2_authoring_state.get("source_wip_id")) != saved_wip.wip_id:
		saved_wip.forge_v2_authoring_state.set("source_wip_id", saved_wip.wip_id)
		changed = true
	if wip_library.has_method("get_saved_wip"):
		var stored_wip: CraftedItemWIP = wip_library.call("get_saved_wip", saved_wip.wip_id) as CraftedItemWIP
		if stored_wip != null and stored_wip.forge_v2_authoring_state != null and StringName(stored_wip.forge_v2_authoring_state.get("source_wip_id")) != saved_wip.wip_id:
			stored_wip.forge_v2_authoring_state.set("source_wip_id", saved_wip.wip_id)
			changed = true
	if changed and wip_library.has_method("persist"):
		wip_library.call("persist")

func _emit_state_changed() -> void:
	authoring_state_changed.emit(active_authoring_state)

func _emit_placement_cursor_changed() -> void:
	placement_cursor_changed.emit(
		placement_cursor_local_position,
		placement_cursor_valid,
		_get_active_brush_radius_meters()
	)

func _get_active_brush_radius_meters() -> float:
	var state: Resource = ensure_authoring_state(default_project_name)
	return float(state.get("active_brush_radius_meters"))

func _get_spline_selection_radius_meters() -> float:
	return clampf(_get_active_brush_radius_meters() * 1.35, 0.035, 0.16)
