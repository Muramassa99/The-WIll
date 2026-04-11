extends RefCounted
class_name ForgeStage2BrushPresenter

const Stage2ShellApplyResolverScript = preload("res://core/resolvers/stage2_shell_apply_resolver.gd")
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

var shell_apply_resolver = Stage2ShellApplyResolverScript.new()

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
	apply_patch_ids: PackedStringArray = PackedStringArray(),
	amount_ratio: float = 1.0,
	editable_mesh_vertex_indices: PackedInt32Array = PackedInt32Array()
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
	return shell_apply_resolver.apply_selection_patch_ids(
		stage2_item_state,
		target_patch_ids,
		effective_tool_id,
		tool_id,
		amount_ratio,
		editable_mesh_vertex_indices
	)

func apply_brush(
	stage2_item_state: Resource,
	tool_id: StringName,
	hit_point_local: Vector3,
	radius_meters: float,
	step_meters: float,
	amount_ratio: float = 1.0,
	hit_face_id: StringName = StringName(),
	tool_axis_local: Vector3 = Vector3.ZERO
) -> bool:
	if stage2_item_state == null or not stage2_item_state.has_current_shell():
		return false
	return shell_apply_resolver.apply_pointer_brush(
		stage2_item_state,
		tool_id,
		hit_point_local,
		radius_meters,
		step_meters,
		amount_ratio,
		hit_face_id,
		tool_axis_local
	)

func is_patch_tool_blocked(patch_state: Resource, tool_id: StringName) -> bool:
	return shell_apply_resolver.is_patch_tool_blocked(patch_state, tool_id)

func is_zone_mask_blocked(zone_mask_id: StringName, tool_id: StringName) -> bool:
	return shell_apply_resolver.is_zone_mask_blocked(zone_mask_id, tool_id)

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
	return shell_apply_resolver.selection_target_set_has_blocked_patch(
		stage2_item_state,
		target_patch_ids,
		effective_tool_id
	)
