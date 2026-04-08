extends RefCounted
class_name ForgeStage2BrushPresenter

const Stage2PatchStateScript = preload("res://core/models/stage2_patch_state.gd")
const ForgeStage2SelectionPresenterScript = preload("res://runtime/forge/forge_stage2_selection_presenter.gd")

const TOOL_STAGE2_CARVE: StringName = &"stage2_carve"
const TOOL_STAGE2_RESTORE: StringName = &"stage2_restore"
const TOOL_STAGE2_FILLET: StringName = &"stage2_fillet"
const TOOL_STAGE2_CHAMFER: StringName = &"stage2_chamfer"

const FAMILY_STAGE2_CARVE: StringName = TOOL_STAGE2_CARVE
const FAMILY_STAGE2_FILLET: StringName = TOOL_STAGE2_FILLET
const FAMILY_STAGE2_CHAMFER: StringName = TOOL_STAGE2_CHAMFER

const MODIFIER_ADD: StringName = &"add"
const MODIFIER_REMOVE: StringName = &"remove"

func is_pointer_radius_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_CARVE
		or tool_id == TOOL_STAGE2_RESTORE
		or tool_id == TOOL_STAGE2_FILLET
		or tool_id == TOOL_STAGE2_CHAMFER
	)

func is_pointer_radius_family(family_id: StringName) -> bool:
	return (
		family_id == FAMILY_STAGE2_CARVE
		or family_id == FAMILY_STAGE2_FILLET
		or family_id == FAMILY_STAGE2_CHAMFER
	)

func resolve_pointer_tool_family(tool_id: StringName, fallback_family_id: StringName = StringName()) -> StringName:
	if tool_id == TOOL_STAGE2_FILLET:
		return FAMILY_STAGE2_FILLET
	if tool_id == TOOL_STAGE2_CHAMFER:
		return FAMILY_STAGE2_CHAMFER
	if tool_id == TOOL_STAGE2_RESTORE and is_pointer_radius_family(fallback_family_id):
		return fallback_family_id
	return FAMILY_STAGE2_CARVE

func compose_pointer_tool_id(family_id: StringName, modifier_id: StringName) -> StringName:
	if modifier_id == MODIFIER_REMOVE:
		return TOOL_STAGE2_RESTORE
	match family_id:
		FAMILY_STAGE2_FILLET:
			return TOOL_STAGE2_FILLET
		FAMILY_STAGE2_CHAMFER:
			return TOOL_STAGE2_CHAMFER
		_:
			return TOOL_STAGE2_CARVE

func get_pointer_tool_display_name(family_id: StringName) -> String:
	match family_id:
		FAMILY_STAGE2_FILLET:
			return "Fillet"
		FAMILY_STAGE2_CHAMFER:
			return "Chamfer"
		_:
			return "Carve"

func apply_selection_tool(
	stage2_item_state: Resource,
	selected_patch_ids: PackedStringArray,
	tool_id: StringName,
	apply_patch_ids: PackedStringArray = PackedStringArray()
) -> bool:
	var target_patch_ids: PackedStringArray = (
		apply_patch_ids
		if not apply_patch_ids.is_empty()
		else selected_patch_ids
	)
	if stage2_item_state == null or not stage2_item_state.has_current_shell() or target_patch_ids.is_empty():
		return false
	var effective_tool_id: StringName = _resolve_effective_selection_tool_id(tool_id)
	if effective_tool_id == StringName():
		return false
	if _should_block_entire_selection(tool_id, stage2_item_state, target_patch_ids, effective_tool_id):
		return false
	var selected_lookup: Dictionary = {}
	for patch_id: String in target_patch_ids:
		selected_lookup[StringName(patch_id)] = true
	var changed: bool = false
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or not patch_state.has_current_quad() or not selected_lookup.has(patch_state.patch_id):
			continue
		if is_patch_tool_blocked(patch_state, effective_tool_id):
			continue
		if _apply_selection_patch_delta(patch_state, effective_tool_id, maxf(float(stage2_item_state.cell_world_size_meters), 0.0001)):
			changed = true
	if not changed:
		return false
	stage2_item_state.dirty = true
	stage2_item_state.last_active_tool_id = tool_id
	stage2_item_state.refresh_current_local_aabb_from_patches()
	return true

func apply_brush(
	stage2_item_state: Resource,
	tool_id: StringName,
	hit_point_local: Vector3,
	radius_meters: float,
	step_meters: float
) -> bool:
	if stage2_item_state == null or not stage2_item_state.has_current_shell():
		return false
	var cell_world_size_meters: float = maxf(float(stage2_item_state.cell_world_size_meters), 0.0001)
	var radius_cells: float = radius_meters / cell_world_size_meters
	var step_cells: float = step_meters / cell_world_size_meters
	if radius_cells <= 0.0 or step_cells <= 0.0:
		return false
	var changed: bool = false
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or not patch_state.has_current_quad() or patch_state.baseline_quad == null:
			continue
		var patch_center: Vector3 = _get_quad_center_local(patch_state.current_quad)
		var distance_to_hit: float = patch_center.distance_to(hit_point_local)
		if distance_to_hit > radius_cells:
			continue
		var falloff: float = _resolve_brush_falloff(tool_id, distance_to_hit, radius_cells)
		if falloff <= 0.0:
			continue
		if is_patch_tool_blocked(patch_state, tool_id):
			continue
		if _apply_patch_delta(patch_state, tool_id, step_cells * falloff, cell_world_size_meters):
			changed = true
	if not changed:
		return false
	stage2_item_state.dirty = true
	stage2_item_state.last_active_tool_id = tool_id
	stage2_item_state.refresh_current_local_aabb_from_patches()
	return true

func _apply_patch_delta(
	patch_state: Resource,
	tool_id: StringName,
	step_cells: float,
	cell_world_size_meters: float
) -> bool:
	var baseline_quad: Resource = patch_state.baseline_quad
	var current_quad: Resource = patch_state.current_quad
	var normal: Vector3 = current_quad.normal.normalized()
	if normal == Vector3.ZERO:
		return false
	var max_offset_cells: float = float(patch_state.max_inward_offset_meters) / cell_world_size_meters
	var max_fillet_offset_cells: float = float(patch_state.max_fillet_offset_meters) / cell_world_size_meters
	var max_chamfer_offset_cells: float = float(patch_state.max_chamfer_offset_meters) / cell_world_size_meters
	var current_offset_cells: float = (baseline_quad.origin_local - current_quad.origin_local).dot(normal)
	var next_offset_cells: float = current_offset_cells
	match tool_id:
		TOOL_STAGE2_CARVE:
			next_offset_cells = minf(max_offset_cells, current_offset_cells + step_cells)
		TOOL_STAGE2_RESTORE:
			next_offset_cells = maxf(0.0, current_offset_cells - step_cells)
		TOOL_STAGE2_FILLET:
			var target_offset_cells: float = maxf(0.0, max_fillet_offset_cells)
			next_offset_cells = minf(target_offset_cells, current_offset_cells + step_cells)
		TOOL_STAGE2_CHAMFER:
			var chamfer_target_offset_cells: float = maxf(0.0, max_chamfer_offset_cells)
			next_offset_cells = minf(chamfer_target_offset_cells, current_offset_cells + step_cells)
		_:
			return false
	if is_equal_approx(next_offset_cells, current_offset_cells):
		return false
	current_quad.origin_local = baseline_quad.origin_local - (normal * next_offset_cells)
	patch_state.dirty = true
	return true

func _apply_selection_patch_delta(
	patch_state: Resource,
	tool_id: StringName,
	cell_world_size_meters: float
) -> bool:
	var baseline_quad: Resource = patch_state.baseline_quad
	var current_quad: Resource = patch_state.current_quad
	var normal: Vector3 = current_quad.normal.normalized()
	if normal == Vector3.ZERO:
		return false
	var target_offset_cells: float = 0.0
	match tool_id:
		TOOL_STAGE2_FILLET:
			target_offset_cells = float(patch_state.max_fillet_offset_meters) / cell_world_size_meters
		TOOL_STAGE2_CHAMFER:
			target_offset_cells = float(patch_state.max_chamfer_offset_meters) / cell_world_size_meters
		TOOL_STAGE2_RESTORE:
			target_offset_cells = 0.0
		_:
			return false
	var current_offset_cells: float = (baseline_quad.origin_local - current_quad.origin_local).dot(normal)
	if is_equal_approx(target_offset_cells, current_offset_cells):
		return false
	current_quad.origin_local = baseline_quad.origin_local - (normal * maxf(target_offset_cells, 0.0))
	patch_state.dirty = true
	return true

func is_patch_tool_blocked(patch_state: Resource, tool_id: StringName) -> bool:
	if patch_state == null:
		return false
	return is_zone_mask_blocked(patch_state.zone_mask_id, tool_id)

func is_zone_mask_blocked(zone_mask_id: StringName, tool_id: StringName) -> bool:
	match tool_id:
		TOOL_STAGE2_CARVE:
			return zone_mask_id == Stage2PatchStateScript.ZONE_PRIMARY_GRIP_SAFE
		TOOL_STAGE2_CHAMFER:
			return zone_mask_id == Stage2PatchStateScript.ZONE_PRIMARY_GRIP_SAFE
		_:
			return false

func _resolve_brush_falloff(tool_id: StringName, distance_to_hit: float, radius_cells: float) -> float:
	match tool_id:
		TOOL_STAGE2_CHAMFER:
			return 1.0
		_:
			return 1.0 - clampf(distance_to_hit / radius_cells, 0.0, 1.0)

func _resolve_effective_selection_tool_id(tool_id: StringName) -> StringName:
	match tool_id:
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FACE_FILLET:
			return TOOL_STAGE2_FILLET
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FACE_CHAMFER:
			return TOOL_STAGE2_CHAMFER
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FACE_RESTORE:
			return TOOL_STAGE2_RESTORE
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_EDGE_FILLET:
			return TOOL_STAGE2_FILLET
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_EDGE_CHAMFER:
			return TOOL_STAGE2_CHAMFER
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_EDGE_RESTORE:
			return TOOL_STAGE2_RESTORE
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_EDGE_FILLET:
			return TOOL_STAGE2_FILLET
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_EDGE_CHAMFER:
			return TOOL_STAGE2_CHAMFER
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE:
			return TOOL_STAGE2_RESTORE
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET:
			return TOOL_STAGE2_FILLET
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER:
			return TOOL_STAGE2_CHAMFER
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_RESTORE:
			return TOOL_STAGE2_RESTORE
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET:
			return TOOL_STAGE2_FILLET
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER:
			return TOOL_STAGE2_CHAMFER
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BAND_RESTORE:
			return TOOL_STAGE2_RESTORE
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET:
			return TOOL_STAGE2_FILLET
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER:
			return TOOL_STAGE2_CHAMFER
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE:
			return TOOL_STAGE2_RESTORE
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET:
			return TOOL_STAGE2_FILLET
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER:
			return TOOL_STAGE2_CHAMFER
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_RESTORE:
			return TOOL_STAGE2_RESTORE
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET:
			return TOOL_STAGE2_FILLET
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER:
			return TOOL_STAGE2_CHAMFER
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_RESTORE:
			return TOOL_STAGE2_RESTORE
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET:
			return TOOL_STAGE2_FILLET
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER:
			return TOOL_STAGE2_CHAMFER
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_LOOP_RESTORE:
			return TOOL_STAGE2_RESTORE
		_:
			return StringName()

func _should_block_entire_selection(
	tool_id: StringName,
	stage2_item_state: Resource,
	target_patch_ids: PackedStringArray,
	effective_tool_id: StringName
) -> bool:
	if (
		tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET
		and tool_id != ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER
	):
		return false
	if stage2_item_state == null or target_patch_ids.is_empty():
		return false
	var patch_lookup: Dictionary = {}
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null:
			continue
		patch_lookup[patch_state.patch_id] = patch_state
	for patch_id: String in target_patch_ids:
		var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
		if patch_state == null:
			continue
		if is_patch_tool_blocked(patch_state, effective_tool_id):
			return true
	return false

func _get_quad_center_local(quad_state: Resource) -> Vector3:
	return quad_state.origin_local + (quad_state.edge_u_local * 0.5) + (quad_state.edge_v_local * 0.5)
