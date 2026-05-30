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
var active_placement_stroke_id: StringName = StringName()

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
		created_state = true
	else:
		active_authoring_state.normalize()
	if created_state:
		_emit_state_changed()
	return active_authoring_state

func start_new_draft(project_name: String = "") -> Resource:
	active_placement_stroke_id = StringName()
	active_authoring_state = ForgeV2AuthoringStateScript.new()
	active_authoring_state.reset_new_draft(_resolve_project_name(project_name))
	_emit_state_changed()
	return active_authoring_state

func get_active_authoring_state() -> Resource:
	return ensure_authoring_state(default_project_name)

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
	var state: Resource = ensure_authoring_state(default_project_name)
	var stroke: Resource = state.append_empty_volume_stroke()
	_emit_state_changed()
	return stroke

func append_sample_volume_stroke() -> Resource:
	var state: Resource = ensure_authoring_state(default_project_name)
	var stroke: Resource = state.append_sample_volume_stroke()
	_emit_state_changed()
	return stroke

func append_active_primitive_deposit() -> Array[Resource]:
	var state: Resource = ensure_authoring_state(default_project_name)
	var strokes: Array[Resource] = state.append_active_primitive_deposit()
	_emit_state_changed()
	return strokes

func append_point_volume_stroke(local_position: Vector3) -> Resource:
	var state: Resource = ensure_authoring_state(default_project_name)
	var stroke: Resource = state.append_point_volume_stroke(local_position)
	placement_cursor_local_position = local_position
	placement_cursor_valid = true
	_emit_state_changed()
	_emit_placement_cursor_changed()
	return stroke

func begin_placement_stroke(local_position: Vector3) -> StringName:
	var stroke: Resource = append_point_volume_stroke(local_position)
	active_placement_stroke_id = StringName(stroke.get("stroke_id")) if stroke != null else StringName()
	return active_placement_stroke_id

func extend_placement_stroke(local_position: Vector3, force_endpoint: bool = false) -> bool:
	if active_placement_stroke_id == StringName():
		begin_placement_stroke(local_position)
		return true
	var state: Resource = ensure_authoring_state(default_project_name)
	var sample_spacing: float = ensure_workspace_contract().resolve_stroke_sample_spacing(_get_active_brush_radius_meters())
	var changed: bool = bool(state.call(
		"append_point_to_volume_stroke",
		active_placement_stroke_id,
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
	var changed := false
	if active_placement_stroke_id != StringName() and has_final_position:
		changed = extend_placement_stroke(local_position, true)
	active_placement_stroke_id = StringName()
	return changed

func clear_volume_strokes() -> void:
	active_placement_stroke_id = StringName()
	var state: Resource = ensure_authoring_state(default_project_name)
	state.clear_volume_strokes()
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
	return ensure_authoring_state(default_project_name).get_status_summary()

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
