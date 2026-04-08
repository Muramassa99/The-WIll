extends RefCounted
class_name ForgeStage2SelectionPresenter

const TOOL_STAGE2_SURFACE_FACE_FILLET: StringName = &"stage2_surface_face_fillet"
const TOOL_STAGE2_SURFACE_FACE_CHAMFER: StringName = &"stage2_surface_face_chamfer"
const TOOL_STAGE2_SURFACE_FACE_RESTORE: StringName = &"stage2_surface_face_restore"
const TOOL_STAGE2_SURFACE_EDGE_FILLET: StringName = &"stage2_surface_edge_fillet"
const TOOL_STAGE2_SURFACE_EDGE_CHAMFER: StringName = &"stage2_surface_edge_chamfer"
const TOOL_STAGE2_SURFACE_EDGE_RESTORE: StringName = &"stage2_surface_edge_restore"
const TOOL_STAGE2_SURFACE_FEATURE_EDGE_FILLET: StringName = &"stage2_surface_feature_edge_fillet"
const TOOL_STAGE2_SURFACE_FEATURE_EDGE_CHAMFER: StringName = &"stage2_surface_feature_edge_chamfer"
const TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE: StringName = &"stage2_surface_feature_edge_restore"
const TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET: StringName = &"stage2_surface_feature_region_fillet"
const TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER: StringName = &"stage2_surface_feature_region_chamfer"
const TOOL_STAGE2_SURFACE_FEATURE_REGION_RESTORE: StringName = &"stage2_surface_feature_region_restore"
const TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET: StringName = &"stage2_surface_feature_band_fillet"
const TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER: StringName = &"stage2_surface_feature_band_chamfer"
const TOOL_STAGE2_SURFACE_FEATURE_BAND_RESTORE: StringName = &"stage2_surface_feature_band_restore"
const TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET: StringName = &"stage2_surface_feature_cluster_fillet"
const TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER: StringName = &"stage2_surface_feature_cluster_chamfer"
const TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE: StringName = &"stage2_surface_feature_cluster_restore"
const TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET: StringName = &"stage2_surface_feature_bridge_fillet"
const TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER: StringName = &"stage2_surface_feature_bridge_chamfer"
const TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_RESTORE: StringName = &"stage2_surface_feature_bridge_restore"
const TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET: StringName = &"stage2_surface_feature_contour_fillet"
const TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER: StringName = &"stage2_surface_feature_contour_chamfer"
const TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_RESTORE: StringName = &"stage2_surface_feature_contour_restore"
const TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET: StringName = &"stage2_surface_feature_loop_fillet"
const TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER: StringName = &"stage2_surface_feature_loop_chamfer"
const TOOL_STAGE2_SURFACE_FEATURE_LOOP_RESTORE: StringName = &"stage2_surface_feature_loop_restore"

const EDGE_U_MIN: StringName = &"edge_u_min"
const EDGE_U_MAX: StringName = &"edge_u_max"
const EDGE_V_MIN: StringName = &"edge_v_min"
const EDGE_V_MAX: StringName = &"edge_v_max"

const MODIFIER_ADD: StringName = &"add"
const MODIFIER_REMOVE: StringName = &"remove"

func is_selection_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_FACE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FACE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FACE_RESTORE
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_RESTORE
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_RESTORE
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_RESTORE
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_RESTORE
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_RESTORE
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_RESTORE
	)

func is_selection_family(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_FACE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FACE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER
	)

func resolve_selection_family(tool_id: StringName, fallback_family_id: StringName = StringName()) -> StringName:
	if is_selection_family(tool_id):
		return tool_id
	match tool_id:
		TOOL_STAGE2_SURFACE_FACE_RESTORE:
			if fallback_family_id == TOOL_STAGE2_SURFACE_FACE_CHAMFER:
				return fallback_family_id
			return TOOL_STAGE2_SURFACE_FACE_FILLET
		TOOL_STAGE2_SURFACE_EDGE_RESTORE:
			if fallback_family_id == TOOL_STAGE2_SURFACE_EDGE_CHAMFER:
				return fallback_family_id
			return TOOL_STAGE2_SURFACE_EDGE_FILLET
		TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE:
			if fallback_family_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_CHAMFER:
				return fallback_family_id
			return TOOL_STAGE2_SURFACE_FEATURE_EDGE_FILLET
		TOOL_STAGE2_SURFACE_FEATURE_REGION_RESTORE:
			if fallback_family_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER:
				return fallback_family_id
			return TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET
		TOOL_STAGE2_SURFACE_FEATURE_BAND_RESTORE:
			if fallback_family_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER:
				return fallback_family_id
			return TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET
		TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE:
			if fallback_family_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER:
				return fallback_family_id
			return TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET
		TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_RESTORE:
			if fallback_family_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER:
				return fallback_family_id
			return TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET
		TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_RESTORE:
			if fallback_family_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER:
				return fallback_family_id
			return TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET
		TOOL_STAGE2_SURFACE_FEATURE_LOOP_RESTORE:
			if fallback_family_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER:
				return fallback_family_id
			return TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET
		_:
			return fallback_family_id

func compose_selection_tool_id(family_id: StringName, modifier_id: StringName) -> StringName:
	if modifier_id != MODIFIER_REMOVE:
		return family_id
	match family_id:
		TOOL_STAGE2_SURFACE_FACE_FILLET, TOOL_STAGE2_SURFACE_FACE_CHAMFER:
			return TOOL_STAGE2_SURFACE_FACE_RESTORE
		TOOL_STAGE2_SURFACE_EDGE_FILLET, TOOL_STAGE2_SURFACE_EDGE_CHAMFER:
			return TOOL_STAGE2_SURFACE_EDGE_RESTORE
		TOOL_STAGE2_SURFACE_FEATURE_EDGE_FILLET, TOOL_STAGE2_SURFACE_FEATURE_EDGE_CHAMFER:
			return TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE
		TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET, TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER:
			return TOOL_STAGE2_SURFACE_FEATURE_REGION_RESTORE
		TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET, TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER:
			return TOOL_STAGE2_SURFACE_FEATURE_BAND_RESTORE
		TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET, TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER:
			return TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE
		TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET, TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER:
			return TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_RESTORE
		TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET, TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER:
			return TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_RESTORE
		TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET, TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER:
			return TOOL_STAGE2_SURFACE_FEATURE_LOOP_RESTORE
		_:
			return family_id

func get_selection_tool_display_name(family_id: StringName) -> String:
	match family_id:
		TOOL_STAGE2_SURFACE_FACE_FILLET:
			return "Face Fillet"
		TOOL_STAGE2_SURFACE_FACE_CHAMFER:
			return "Face Chamfer"
		TOOL_STAGE2_SURFACE_EDGE_FILLET:
			return "Edge Fillet"
		TOOL_STAGE2_SURFACE_EDGE_CHAMFER:
			return "Edge Chamfer"
		TOOL_STAGE2_SURFACE_FEATURE_EDGE_FILLET:
			return "Feature Edge Fillet"
		TOOL_STAGE2_SURFACE_FEATURE_EDGE_CHAMFER:
			return "Feature Edge Chamfer"
		TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET:
			return "Feature Region Fillet"
		TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER:
			return "Feature Region Chamfer"
		TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET:
			return "Feature Band Fillet"
		TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER:
			return "Feature Band Chamfer"
		TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET:
			return "Feature Cluster Fillet"
		TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER:
			return "Feature Cluster Chamfer"
		TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET:
			return "Feature Bridge Fillet"
		TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER:
			return "Feature Bridge Chamfer"
		TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET:
			return "Feature Contour Fillet"
		TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER:
			return "Feature Contour Chamfer"
		TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET:
			return "Feature Loop Fillet"
		TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER:
			return "Feature Loop Chamfer"
		_:
			return "Stage 2 Selection"

func resolve_hover_selection_data(stage2_item_state: Resource, hit_data: Dictionary, tool_id: StringName) -> Dictionary:
	var hovered_patch_id: StringName = _resolve_hover_patch_id(hit_data)
	if hovered_patch_id == StringName():
		return {}
	if (
		tool_id == TOOL_STAGE2_SURFACE_FACE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FACE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FACE_RESTORE
	):
		var patch_state: Resource = _find_patch_state_by_id(stage2_item_state, hovered_patch_id)
		if patch_state == null or patch_state.current_quad == null:
			return {}
		var patch_ids: PackedStringArray = _resolve_connected_face_region_patch_ids(stage2_item_state, patch_state)
		if patch_ids.is_empty():
			return {}
		return {
			"patch_ids": patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_face",
		}
	if (
		tool_id == TOOL_STAGE2_SURFACE_EDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_RESTORE
	):
		var patch_state: Resource = _find_patch_state_by_id(stage2_item_state, hovered_patch_id)
		if patch_state == null or patch_state.current_quad == null:
			return {}
		var hit_point_local: Variant = hit_data.get("hit_point_canonical_local", null)
		if not hit_point_local is Vector3:
			return {}
		var edge_id: StringName = _resolve_nearest_boundary_edge_id(stage2_item_state, patch_state, hit_point_local)
		if edge_id == StringName():
			return {}
		var patch_ids: PackedStringArray = _resolve_boundary_edge_run_patch_ids(stage2_item_state, patch_state, edge_id)
		if patch_ids.is_empty():
			return {}
		return {
			"patch_ids": patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_edge",
			"edge_id": edge_id,
		}
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE
	):
		var patch_state: Resource = _find_patch_state_by_id(stage2_item_state, hovered_patch_id)
		if patch_state == null or patch_state.current_quad == null:
			return {}
		var hit_point_local: Variant = hit_data.get("hit_point_canonical_local", null)
		if not hit_point_local is Vector3:
			return {}
		var edge_id: StringName = _resolve_nearest_internal_feature_edge_id(stage2_item_state, patch_state, hit_point_local)
		if edge_id == StringName():
			return {}
		var patch_ids: PackedStringArray = _resolve_internal_feature_edge_run_patch_ids(stage2_item_state, patch_state, edge_id)
		if patch_ids.is_empty():
			return {}
		return {
			"patch_ids": patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_feature_edge",
			"edge_id": edge_id,
		}
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_RESTORE
	):
		var patch_state: Resource = _find_patch_state_by_id(stage2_item_state, hovered_patch_id)
		if patch_state == null or patch_state.current_quad == null:
			return {}
		var patch_ids: PackedStringArray = _resolve_connected_offset_feature_region_patch_ids(stage2_item_state, patch_state)
		if patch_ids.is_empty():
			return {}
		return {
			"patch_ids": patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_feature_region",
		}
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_RESTORE
	):
		var patch_state: Resource = _find_patch_state_by_id(stage2_item_state, hovered_patch_id)
		if patch_state == null or patch_state.current_quad == null:
			return {}
		var region_patch_ids: PackedStringArray = _resolve_connected_offset_feature_region_patch_ids(stage2_item_state, patch_state)
		if region_patch_ids.is_empty():
			return {}
		var patch_ids: PackedStringArray = _resolve_feature_band_patch_ids_for_region(stage2_item_state, region_patch_ids)
		if patch_ids.is_empty():
			return {}
		return {
			"patch_ids": patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_feature_band",
		}
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE
	):
		var patch_state: Resource = _find_patch_state_by_id(stage2_item_state, hovered_patch_id)
		if patch_state == null or patch_state.current_quad == null:
			return {}
		var patch_ids: PackedStringArray = _resolve_feature_cluster_patch_ids_from_anchor(stage2_item_state, patch_state)
		if patch_ids.is_empty():
			return {}
		return {
			"patch_ids": patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_feature_cluster",
		}
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_RESTORE
	):
		var patch_state: Resource = _find_patch_state_by_id(stage2_item_state, hovered_patch_id)
		if patch_state == null or patch_state.current_quad == null:
			return {}
		var patch_ids: PackedStringArray = _resolve_feature_bridge_patch_ids_from_anchor(stage2_item_state, patch_state)
		if patch_ids.is_empty():
			return {}
		return {
			"patch_ids": patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_feature_bridge",
		}
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_RESTORE
	):
		var patch_state: Resource = _find_patch_state_by_id(stage2_item_state, hovered_patch_id)
		if patch_state == null or patch_state.current_quad == null:
			return {}
		var bridge_patch_ids: PackedStringArray = _resolve_feature_bridge_patch_ids_from_anchor(stage2_item_state, patch_state)
		if bridge_patch_ids.is_empty():
			return {}
		var patch_ids: PackedStringArray = _resolve_feature_contour_patch_ids_for_bridge(stage2_item_state, bridge_patch_ids)
		if patch_ids.is_empty():
			return {}
		return {
			"patch_ids": patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_feature_contour",
		}
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_RESTORE
	):
		var patch_state: Resource = _find_patch_state_by_id(stage2_item_state, hovered_patch_id)
		if patch_state == null or patch_state.current_quad == null:
			return {}
		var region_patch_ids: PackedStringArray = _resolve_connected_offset_feature_region_patch_ids(stage2_item_state, patch_state)
		if region_patch_ids.is_empty():
			return {}
		var patch_ids: PackedStringArray = _resolve_feature_loop_patch_ids_for_region(stage2_item_state, region_patch_ids)
		if patch_ids.is_empty():
			return {}
		return {
			"patch_ids": patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_feature_loop",
		}
	return {}

func toggle_patch_selection(selected_patch_ids: PackedStringArray, patch_ids: PackedStringArray) -> PackedStringArray:
	var next_selection: PackedStringArray = PackedStringArray(selected_patch_ids)
	if patch_ids.is_empty():
		return next_selection
	var should_remove: bool = true
	for patch_id: String in patch_ids:
		if next_selection.find(patch_id) == -1:
			should_remove = false
			break
	if should_remove:
		for patch_id: String in patch_ids:
			var existing_index: int = next_selection.find(patch_id)
			if existing_index >= 0:
				next_selection.remove_at(existing_index)
	else:
		for patch_id: String in patch_ids:
			if next_selection.find(patch_id) == -1:
				next_selection.append(patch_id)
	return next_selection

func clear_selection() -> PackedStringArray:
	return PackedStringArray()

func resolve_selection_apply_patch_ids(
	stage2_item_state: Resource,
	selected_patch_ids: PackedStringArray,
	tool_id: StringName
) -> PackedStringArray:
	if stage2_item_state == null or selected_patch_ids.is_empty():
		return PackedStringArray()
	if (
		tool_id == TOOL_STAGE2_SURFACE_FACE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FACE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FACE_RESTORE
	):
		return _resolve_boundary_loop_patch_ids_for_selection(stage2_item_state, selected_patch_ids)
	if (
		tool_id == TOOL_STAGE2_SURFACE_EDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_RESTORE
	):
		return PackedStringArray(selected_patch_ids)
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE
	):
		return PackedStringArray(selected_patch_ids)
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_RESTORE
	):
		return PackedStringArray(selected_patch_ids)
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_RESTORE
	):
		return PackedStringArray(selected_patch_ids)
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE
	):
		return PackedStringArray(selected_patch_ids)
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_RESTORE
	):
		return PackedStringArray(selected_patch_ids)
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_RESTORE
	):
		return PackedStringArray(selected_patch_ids)
	if (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_RESTORE
	):
		return PackedStringArray(selected_patch_ids)
	return PackedStringArray()

func _resolve_hover_patch_id(hit_data: Dictionary) -> StringName:
	if hit_data.is_empty():
		return StringName()
	return StringName(hit_data.get("patch_id", StringName()))

func _find_patch_state_by_id(stage2_item_state: Resource, patch_id: StringName) -> Resource:
	if stage2_item_state == null or patch_id == StringName():
		return null
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null:
			continue
		if patch_state.patch_id == patch_id:
			return patch_state
	return null

func _resolve_connected_face_region_patch_ids(stage2_item_state: Resource, anchor_patch_state: Resource) -> PackedStringArray:
	if stage2_item_state == null or anchor_patch_state == null or anchor_patch_state.current_quad == null:
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup(stage2_item_state)
	var visited_lookup: Dictionary = {}
	var pending_patch_ids: Array[StringName] = [anchor_patch_state.patch_id]
	var patch_ids: PackedStringArray = PackedStringArray()
	while not pending_patch_ids.is_empty():
		var patch_id: StringName = pending_patch_ids.pop_back()
		if patch_id == StringName() or visited_lookup.has(patch_id):
			continue
		visited_lookup[patch_id] = true
		var patch_state: Resource = patch_lookup.get(patch_id, null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		if not _shares_plane_and_normal(anchor_patch_state.current_quad, patch_state.current_quad):
			continue
		patch_ids.append(String(patch_id))
		if not patch_state.neighbor_patch_ids.is_empty():
			for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
				var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
				if not visited_lookup.has(neighbor_patch_id):
					pending_patch_ids.append(neighbor_patch_id)
			continue
		for candidate_patch_state in stage2_item_state.patch_states:
			if candidate_patch_state == null or candidate_patch_state == patch_state or candidate_patch_state.current_quad == null:
				continue
			if not _shares_plane_and_normal(anchor_patch_state.current_quad, candidate_patch_state.current_quad):
				continue
			if _patches_share_boundary_edge(patch_state, candidate_patch_state):
				pending_patch_ids.append(candidate_patch_state.patch_id)
	return patch_ids

func _resolve_connected_offset_feature_region_patch_ids(stage2_item_state: Resource, anchor_patch_state: Resource) -> PackedStringArray:
	if stage2_item_state == null or anchor_patch_state == null or anchor_patch_state.current_quad == null:
		return PackedStringArray()
	var anchor_offset_cells: float = _resolve_current_offset_cells(anchor_patch_state)
	if is_zero_approx(anchor_offset_cells):
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup(stage2_item_state)
	var visited_lookup: Dictionary = {}
	var pending_patch_ids: Array[StringName] = [anchor_patch_state.patch_id]
	var patch_ids: PackedStringArray = PackedStringArray()
	while not pending_patch_ids.is_empty():
		var patch_id: StringName = pending_patch_ids.pop_back()
		if patch_id == StringName() or visited_lookup.has(patch_id):
			continue
		visited_lookup[patch_id] = true
		var patch_state: Resource = patch_lookup.get(patch_id, null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		if not _shares_plane_and_normal(anchor_patch_state.current_quad, patch_state.current_quad):
			continue
		if patch_state.zone_mask_id != anchor_patch_state.zone_mask_id:
			continue
		if not is_equal_approx(_resolve_current_offset_cells(patch_state), anchor_offset_cells):
			continue
		patch_ids.append(String(patch_id))
		if not patch_state.neighbor_patch_ids.is_empty():
			for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
				var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
				if not visited_lookup.has(neighbor_patch_id):
					pending_patch_ids.append(neighbor_patch_id)
			continue
		for candidate_patch_state in stage2_item_state.patch_states:
			if candidate_patch_state == null or candidate_patch_state == patch_state or candidate_patch_state.current_quad == null:
				continue
			if not _patches_share_boundary_edge_by_topology(patch_state, candidate_patch_state):
				continue
			if not visited_lookup.has(candidate_patch_state.patch_id):
				pending_patch_ids.append(candidate_patch_state.patch_id)
	return patch_ids

func _resolve_boundary_loop_patch_ids_for_selection(stage2_item_state: Resource, selected_patch_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null or selected_patch_ids.is_empty():
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup(stage2_item_state)
	var selected_lookup: Dictionary = {}
	for patch_id: String in selected_patch_ids:
		selected_lookup[StringName(patch_id)] = true
	var boundary_patch_ids: PackedStringArray = PackedStringArray()
	for patch_id: String in selected_patch_ids:
		var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		if _patch_has_selection_boundary_edge(patch_lookup, patch_state, selected_lookup):
			boundary_patch_ids.append(patch_id)
	if boundary_patch_ids.is_empty():
		return PackedStringArray(selected_patch_ids)
	return boundary_patch_ids

func _resolve_feature_loop_patch_ids_for_region(stage2_item_state: Resource, region_patch_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null or region_patch_ids.is_empty():
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup(stage2_item_state)
	var region_lookup: Dictionary = {}
	for patch_id: String in region_patch_ids:
		region_lookup[StringName(patch_id)] = true
	var loop_patch_ids: PackedStringArray = PackedStringArray()
	for patch_id: String in region_patch_ids:
		var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		var adjacent_patch_ids: PackedStringArray = _resolve_boundary_neighbor_patch_ids(stage2_item_state, patch_state)
		for neighbor_patch_id_string: String in adjacent_patch_ids:
			var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
			if region_lookup.has(neighbor_patch_id):
				continue
			var neighbor_patch_state: Resource = patch_lookup.get(neighbor_patch_id, null)
			if neighbor_patch_state == null or neighbor_patch_state.current_quad == null:
				continue
			if not _shares_topology_plane_and_normal(patch_state, neighbor_patch_state):
				continue
			if is_equal_approx(_resolve_current_offset_cells(patch_state), _resolve_current_offset_cells(neighbor_patch_state)):
				continue
			_append_unique_patch_id(loop_patch_ids, patch_id)
			_append_unique_patch_id(loop_patch_ids, String(neighbor_patch_id))
	if loop_patch_ids.is_empty():
		return PackedStringArray()
	return loop_patch_ids

func _resolve_feature_band_patch_ids_for_region(stage2_item_state: Resource, region_patch_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null or region_patch_ids.is_empty():
		return PackedStringArray()
	var band_patch_ids: PackedStringArray = PackedStringArray(region_patch_ids)
	var loop_patch_ids: PackedStringArray = _resolve_feature_loop_patch_ids_for_region(stage2_item_state, region_patch_ids)
	for patch_id: String in loop_patch_ids:
		_append_unique_patch_id(band_patch_ids, patch_id)
	return band_patch_ids

func _resolve_feature_cluster_patch_ids_from_anchor(stage2_item_state: Resource, anchor_patch_state: Resource) -> PackedStringArray:
	if stage2_item_state == null or anchor_patch_state == null or anchor_patch_state.current_quad == null:
		return PackedStringArray()
	if is_zero_approx(_resolve_current_offset_cells(anchor_patch_state)):
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup(stage2_item_state)
	var cluster_patch_ids: PackedStringArray = PackedStringArray()
	var visited_region_anchor_lookup: Dictionary = {}
	var pending_region_anchor_ids: Array[StringName] = [anchor_patch_state.patch_id]
	while not pending_region_anchor_ids.is_empty():
		var region_anchor_id: StringName = pending_region_anchor_ids.pop_back()
		if region_anchor_id == StringName() or visited_region_anchor_lookup.has(region_anchor_id):
			continue
		var region_anchor_state: Resource = patch_lookup.get(region_anchor_id, null)
		if region_anchor_state == null or region_anchor_state.current_quad == null:
			continue
		if region_anchor_state.zone_mask_id != anchor_patch_state.zone_mask_id:
			continue
		if not _shares_topology_plane_and_normal(anchor_patch_state, region_anchor_state):
			continue
		if is_zero_approx(_resolve_current_offset_cells(region_anchor_state)):
			continue
		visited_region_anchor_lookup[region_anchor_id] = true
		var region_patch_ids: PackedStringArray = _resolve_connected_offset_feature_region_patch_ids(stage2_item_state, region_anchor_state)
		if region_patch_ids.is_empty():
			continue
		var band_patch_ids: PackedStringArray = _resolve_feature_band_patch_ids_for_region(stage2_item_state, region_patch_ids)
		for patch_id: String in band_patch_ids:
			_append_unique_patch_id(cluster_patch_ids, patch_id)
		for patch_id: String in band_patch_ids:
			var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
			if patch_state == null or patch_state.current_quad == null:
				continue
			if patch_state.zone_mask_id != anchor_patch_state.zone_mask_id:
				continue
			if not _shares_topology_plane_and_normal(anchor_patch_state, patch_state):
				continue
			if is_zero_approx(_resolve_current_offset_cells(patch_state)):
				continue
			if not visited_region_anchor_lookup.has(patch_state.patch_id):
				pending_region_anchor_ids.append(patch_state.patch_id)
	return cluster_patch_ids

func _resolve_feature_bridge_patch_ids_from_anchor(stage2_item_state: Resource, anchor_patch_state: Resource) -> PackedStringArray:
	if stage2_item_state == null or anchor_patch_state == null or anchor_patch_state.current_quad == null:
		return PackedStringArray()
	if is_zero_approx(_resolve_current_offset_cells(anchor_patch_state)):
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup(stage2_item_state)
	var bridge_patch_ids: PackedStringArray = PackedStringArray()
	var visited_cluster_seed_lookup: Dictionary = {}
	var pending_cluster_seed_ids: Array[StringName] = [anchor_patch_state.patch_id]
	while not pending_cluster_seed_ids.is_empty():
		var cluster_seed_id: StringName = pending_cluster_seed_ids.pop_back()
		if cluster_seed_id == StringName() or visited_cluster_seed_lookup.has(cluster_seed_id):
			continue
		var cluster_seed_state: Resource = patch_lookup.get(cluster_seed_id, null)
		if cluster_seed_state == null or cluster_seed_state.current_quad == null:
			continue
		if cluster_seed_state.zone_mask_id != anchor_patch_state.zone_mask_id:
			continue
		if is_zero_approx(_resolve_current_offset_cells(cluster_seed_state)):
			continue
		visited_cluster_seed_lookup[cluster_seed_id] = true
		var cluster_patch_ids: PackedStringArray = _resolve_feature_cluster_patch_ids_from_anchor(stage2_item_state, cluster_seed_state)
		if cluster_patch_ids.is_empty():
			continue
		for patch_id: String in cluster_patch_ids:
			_append_unique_patch_id(bridge_patch_ids, patch_id)
		for patch_id: String in cluster_patch_ids:
			var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
			if patch_state == null or patch_state.current_quad == null:
				continue
			for bridge_neighbor_patch_id_string: String in _resolve_feature_bridge_neighbor_patch_ids(stage2_item_state, patch_state):
				var bridge_neighbor_patch_id: StringName = StringName(bridge_neighbor_patch_id_string)
				if not visited_cluster_seed_lookup.has(bridge_neighbor_patch_id):
					pending_cluster_seed_ids.append(bridge_neighbor_patch_id)
	return bridge_patch_ids

func _resolve_feature_contour_patch_ids_for_bridge(stage2_item_state: Resource, bridge_patch_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null or bridge_patch_ids.is_empty():
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup(stage2_item_state)
	var bridge_lookup: Dictionary = {}
	for patch_id: String in bridge_patch_ids:
		bridge_lookup[StringName(patch_id)] = true
	var contour_patch_ids: PackedStringArray = PackedStringArray()
	for patch_id: String in bridge_patch_ids:
		var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		if _patch_has_feature_contour_transition(stage2_item_state, patch_lookup, patch_state, bridge_lookup):
			_append_unique_patch_id(contour_patch_ids, patch_id)
	if contour_patch_ids.is_empty():
		return PackedStringArray()
	return contour_patch_ids

func _resolve_feature_bridge_neighbor_patch_ids(stage2_item_state: Resource, patch_state: Resource) -> PackedStringArray:
	if stage2_item_state == null or patch_state == null or patch_state.current_quad == null:
		return PackedStringArray()
	var adjacent_patch_ids: PackedStringArray = PackedStringArray()
	for candidate_patch_state in stage2_item_state.patch_states:
		if candidate_patch_state == null or candidate_patch_state == patch_state or candidate_patch_state.current_quad == null:
			continue
		if candidate_patch_state.zone_mask_id != patch_state.zone_mask_id:
			continue
		if is_zero_approx(_resolve_current_offset_cells(candidate_patch_state)):
			continue
		if _shares_topology_plane_and_normal(patch_state, candidate_patch_state):
			continue
		if _patches_share_boundary_edge_across_topology(patch_state, candidate_patch_state):
			_append_unique_patch_id(adjacent_patch_ids, String(candidate_patch_state.patch_id))
	return adjacent_patch_ids

func _patch_has_feature_contour_transition(
	stage2_item_state: Resource,
	patch_lookup: Dictionary,
	patch_state: Resource,
	selected_lookup: Dictionary
) -> bool:
	if stage2_item_state == null or patch_state == null or patch_state.current_quad == null:
		return false
	var patch_offset_cells: float = _resolve_current_offset_cells(patch_state)
	if is_zero_approx(patch_offset_cells):
		return false
	var adjacent_patch_ids: PackedStringArray = _resolve_boundary_neighbor_patch_ids(stage2_item_state, patch_state)
	for neighbor_patch_id_string: String in adjacent_patch_ids:
		var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
		var neighbor_patch_state: Resource = patch_lookup.get(neighbor_patch_id, null)
		if neighbor_patch_state == null or neighbor_patch_state.current_quad == null:
			continue
		if not _shares_topology_plane_and_normal(patch_state, neighbor_patch_state):
			continue
		if neighbor_patch_state.zone_mask_id != patch_state.zone_mask_id:
			continue
		var neighbor_offset_cells: float = _resolve_current_offset_cells(neighbor_patch_state)
		if not selected_lookup.has(neighbor_patch_id):
			if not is_equal_approx(neighbor_offset_cells, patch_offset_cells):
				return true
			continue
		if not is_equal_approx(neighbor_offset_cells, patch_offset_cells):
			return true
	return false

func _resolve_nearest_boundary_edge_id(stage2_item_state: Resource, patch_state: Resource, hit_point_local: Vector3) -> StringName:
	if patch_state == null or patch_state.current_quad == null:
		return StringName()
	var candidate_edges: Array[Dictionary] = []
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		if not _is_boundary_edge(stage2_item_state, patch_state, edge_id):
			continue
		var edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
		var distance_to_edge: float = _distance_point_to_segment(hit_point_local, edge_segment.get("start", Vector3.ZERO), edge_segment.get("end", Vector3.ZERO))
		candidate_edges.append({
			"edge_id": edge_id,
			"distance": distance_to_edge,
		})
	if candidate_edges.is_empty():
		return StringName()
	candidate_edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)
	return StringName(candidate_edges[0].get("edge_id", StringName()))

func _resolve_nearest_internal_feature_edge_id(stage2_item_state: Resource, patch_state: Resource, hit_point_local: Vector3) -> StringName:
	if patch_state == null or patch_state.current_quad == null:
		return StringName()
	var candidate_edges: Array[Dictionary] = []
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		if not _is_internal_feature_edge(stage2_item_state, patch_state, edge_id):
			continue
		var edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
		var distance_to_edge: float = _distance_point_to_segment(
			hit_point_local,
			edge_segment.get("start", Vector3.ZERO),
			edge_segment.get("end", Vector3.ZERO)
		)
		candidate_edges.append({
			"edge_id": edge_id,
			"distance": distance_to_edge,
		})
	if candidate_edges.is_empty():
		return StringName()
	candidate_edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)
	return StringName(candidate_edges[0].get("edge_id", StringName()))

func _resolve_boundary_edge_run_patch_ids(stage2_item_state: Resource, patch_state: Resource, edge_id: StringName) -> PackedStringArray:
	if stage2_item_state == null or patch_state == null or patch_state.current_quad == null or edge_id == StringName():
		return PackedStringArray()
	var base_edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
	var direction: Vector3 = base_edge_segment.get("direction", Vector3.ZERO)
	if direction == Vector3.ZERO:
		return PackedStringArray([String(patch_state.patch_id)])
	var run_intervals: Array[Dictionary] = []
	for candidate_patch_state in stage2_item_state.patch_states:
		if candidate_patch_state == null or candidate_patch_state.current_quad == null:
			continue
		if not _shares_plane_and_normal(patch_state.current_quad, candidate_patch_state.current_quad):
			continue
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			if not _is_boundary_edge(stage2_item_state, candidate_patch_state, candidate_edge_id):
				continue
			var candidate_edge_segment: Dictionary = _build_edge_segment(candidate_patch_state.current_quad, candidate_edge_id)
			if not _edges_share_same_line(base_edge_segment, candidate_edge_segment):
				continue
			var interval: Vector2 = _resolve_edge_interval(candidate_edge_segment, base_edge_segment)
			run_intervals.append({
				"patch_id": String(candidate_patch_state.patch_id),
				"interval": interval,
			})
			break
	if run_intervals.is_empty():
		return PackedStringArray()
	run_intervals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a.get("interval", Vector2.ZERO)).x < Vector2(b.get("interval", Vector2.ZERO)).x
	)
	var selected_patch_key: String = String(patch_state.patch_id)
	var anchor_index: int = -1
	for interval_index: int in range(run_intervals.size()):
		if String(run_intervals[interval_index].get("patch_id", "")) == selected_patch_key:
			anchor_index = interval_index
			break
	if anchor_index == -1:
		return PackedStringArray()
	var selected_indices: Array[int] = [anchor_index]
	var current_min: float = Vector2(run_intervals[anchor_index].get("interval", Vector2.ZERO)).x
	var current_max: float = Vector2(run_intervals[anchor_index].get("interval", Vector2.ZERO)).y
	var scan_index: int = anchor_index - 1
	while scan_index >= 0:
		var scan_interval: Vector2 = run_intervals[scan_index].get("interval", Vector2.ZERO)
		if not _intervals_touch_or_overlap(scan_interval, Vector2(current_min, current_max)):
			break
		selected_indices.push_front(scan_index)
		current_min = minf(current_min, scan_interval.x)
		current_max = maxf(current_max, scan_interval.y)
		scan_index -= 1
	scan_index = anchor_index + 1
	while scan_index < run_intervals.size():
		var scan_interval: Vector2 = run_intervals[scan_index].get("interval", Vector2.ZERO)
		if not _intervals_touch_or_overlap(Vector2(current_min, current_max), scan_interval):
			break
		selected_indices.append(scan_index)
		current_min = minf(current_min, scan_interval.x)
		current_max = maxf(current_max, scan_interval.y)
		scan_index += 1
	var patch_ids: PackedStringArray = PackedStringArray()
	for selected_index: int in selected_indices:
		patch_ids.append(String(run_intervals[selected_index].get("patch_id", "")))
	return patch_ids

func _resolve_internal_feature_edge_run_patch_ids(stage2_item_state: Resource, patch_state: Resource, edge_id: StringName) -> PackedStringArray:
	if stage2_item_state == null or patch_state == null or patch_state.current_quad == null or edge_id == StringName():
		return PackedStringArray()
	var base_edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
	var direction: Vector3 = base_edge_segment.get("direction", Vector3.ZERO)
	if direction == Vector3.ZERO:
		return PackedStringArray([String(patch_state.patch_id)])
	var interval_records_by_key: Dictionary = {}
	for candidate_patch_state in stage2_item_state.patch_states:
		if candidate_patch_state == null or candidate_patch_state.current_quad == null:
			continue
		if not _shares_plane_and_normal(patch_state.current_quad, candidate_patch_state.current_quad):
			continue
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var adjacent_patch_ids: PackedStringArray = _resolve_internal_edge_adjacent_patch_ids(
				stage2_item_state,
				candidate_patch_state,
				candidate_edge_id
			)
			if adjacent_patch_ids.is_empty():
				continue
			var candidate_edge_segment: Dictionary = _build_edge_segment(candidate_patch_state.current_quad, candidate_edge_id)
			if not _edges_share_same_line(base_edge_segment, candidate_edge_segment):
				continue
			var segment_key: String = _build_edge_segment_key(candidate_edge_segment)
			var record: Dictionary = interval_records_by_key.get(segment_key, {
				"interval": _resolve_edge_interval(candidate_edge_segment, base_edge_segment),
				"patch_ids": PackedStringArray(),
				"segment_key": segment_key,
			})
			var record_patch_ids: PackedStringArray = PackedStringArray(record.get("patch_ids", PackedStringArray()))
			_append_unique_patch_id(record_patch_ids, String(candidate_patch_state.patch_id))
			for adjacent_patch_id_string: String in adjacent_patch_ids:
				_append_unique_patch_id(record_patch_ids, adjacent_patch_id_string)
			record["patch_ids"] = record_patch_ids
			interval_records_by_key[segment_key] = record
			break
	if interval_records_by_key.is_empty():
		return PackedStringArray()
	var run_intervals: Array[Dictionary] = []
	for record_key in interval_records_by_key.keys():
		run_intervals.append(interval_records_by_key[record_key])
	run_intervals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a.get("interval", Vector2.ZERO)).x < Vector2(b.get("interval", Vector2.ZERO)).x
	)
	var anchor_key: String = _build_edge_segment_key(base_edge_segment)
	var anchor_index: int = -1
	for interval_index: int in range(run_intervals.size()):
		if String(run_intervals[interval_index].get("segment_key", "")) == anchor_key:
			anchor_index = interval_index
			break
	if anchor_index == -1:
		return PackedStringArray()
	var selected_indices: Array[int] = [anchor_index]
	var current_min: float = Vector2(run_intervals[anchor_index].get("interval", Vector2.ZERO)).x
	var current_max: float = Vector2(run_intervals[anchor_index].get("interval", Vector2.ZERO)).y
	var scan_index: int = anchor_index - 1
	while scan_index >= 0:
		var scan_interval: Vector2 = run_intervals[scan_index].get("interval", Vector2.ZERO)
		if not _intervals_touch_or_overlap(scan_interval, Vector2(current_min, current_max)):
			break
		selected_indices.push_front(scan_index)
		current_min = minf(current_min, scan_interval.x)
		current_max = maxf(current_max, scan_interval.y)
		scan_index -= 1
	scan_index = anchor_index + 1
	while scan_index < run_intervals.size():
		var scan_interval: Vector2 = run_intervals[scan_index].get("interval", Vector2.ZERO)
		if not _intervals_touch_or_overlap(Vector2(current_min, current_max), scan_interval):
			break
		selected_indices.append(scan_index)
		current_min = minf(current_min, scan_interval.x)
		current_max = maxf(current_max, scan_interval.y)
		scan_index += 1
	var patch_ids: PackedStringArray = PackedStringArray()
	for selected_index: int in selected_indices:
		var record_patch_ids: PackedStringArray = PackedStringArray(run_intervals[selected_index].get("patch_ids", PackedStringArray()))
		for patch_id: String in record_patch_ids:
			_append_unique_patch_id(patch_ids, patch_id)
	return patch_ids

func _resolve_current_offset_cells(patch_state: Resource) -> float:
	if patch_state == null or patch_state.baseline_quad == null or patch_state.current_quad == null:
		return 0.0
	var normal: Vector3 = patch_state.current_quad.normal.normalized()
	if normal == Vector3.ZERO:
		return 0.0
	return (patch_state.baseline_quad.origin_local - patch_state.current_quad.origin_local).dot(normal)

func _shares_plane_and_normal(quad_a: Resource, quad_b: Resource) -> bool:
	if quad_a == null or quad_b == null:
		return false
	var normal_a: Vector3 = quad_a.normal.normalized()
	var normal_b: Vector3 = quad_b.normal.normalized()
	if not normal_a.is_equal_approx(normal_b):
		return false
	return is_equal_approx(normal_a.dot(quad_a.origin_local), normal_b.dot(quad_b.origin_local))

func _is_boundary_edge(stage2_item_state: Resource, patch_state: Resource, edge_id: StringName) -> bool:
	if stage2_item_state == null or patch_state == null or patch_state.current_quad == null:
		return false
	var edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
	for candidate_patch_state in stage2_item_state.patch_states:
		if candidate_patch_state == null or candidate_patch_state == patch_state or candidate_patch_state.current_quad == null:
			continue
		if not _shares_plane_and_normal(patch_state.current_quad, candidate_patch_state.current_quad):
			continue
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(candidate_patch_state.current_quad, candidate_edge_id)
			if _segments_match(edge_segment, candidate_segment):
				return false
	return true

func _is_internal_feature_edge(stage2_item_state: Resource, patch_state: Resource, edge_id: StringName) -> bool:
	return not _resolve_internal_edge_adjacent_patch_ids(stage2_item_state, patch_state, edge_id).is_empty()

func _patch_has_selection_boundary_edge(patch_lookup: Dictionary, patch_state: Resource, selected_lookup: Dictionary) -> bool:
	if patch_state == null or patch_state.current_quad == null:
		return false
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		if _is_selection_boundary_edge(patch_lookup, patch_state, edge_id, selected_lookup):
			return true
	return false

func _is_selection_boundary_edge(patch_lookup: Dictionary, patch_state: Resource, edge_id: StringName, selected_lookup: Dictionary) -> bool:
	var edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
	for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
		var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
		if not selected_lookup.has(neighbor_patch_id):
			continue
		var neighbor_patch_state: Resource = patch_lookup.get(neighbor_patch_id, null)
		if neighbor_patch_state == null or neighbor_patch_state.current_quad == null:
			continue
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(neighbor_patch_state.current_quad, candidate_edge_id)
			if _segments_match(edge_segment, candidate_segment):
				return false
	return true

func _resolve_internal_edge_adjacent_patch_ids(stage2_item_state: Resource, patch_state: Resource, edge_id: StringName) -> PackedStringArray:
	if stage2_item_state == null or patch_state == null or patch_state.current_quad == null:
		return PackedStringArray()
	var edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
	var patch_lookup: Dictionary = _build_patch_lookup(stage2_item_state)
	var adjacent_patch_ids: PackedStringArray = PackedStringArray()
	if not patch_state.neighbor_patch_ids.is_empty():
		for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
			var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
			var neighbor_patch_state: Resource = patch_lookup.get(neighbor_patch_id, null)
			if neighbor_patch_state == null or neighbor_patch_state.current_quad == null:
				continue
			if not _shares_plane_and_normal(patch_state.current_quad, neighbor_patch_state.current_quad):
				continue
			for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
				var candidate_segment: Dictionary = _build_edge_segment(neighbor_patch_state.current_quad, candidate_edge_id)
				if _segments_match(edge_segment, candidate_segment):
					_append_unique_patch_id(adjacent_patch_ids, String(neighbor_patch_id))
					break
		return adjacent_patch_ids
	for candidate_patch_state in stage2_item_state.patch_states:
		if candidate_patch_state == null or candidate_patch_state == patch_state or candidate_patch_state.current_quad == null:
			continue
		if not _shares_plane_and_normal(patch_state.current_quad, candidate_patch_state.current_quad):
			continue
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(candidate_patch_state.current_quad, candidate_edge_id)
			if _segments_match(edge_segment, candidate_segment):
				_append_unique_patch_id(adjacent_patch_ids, String(candidate_patch_state.patch_id))
				break
	return adjacent_patch_ids

func _resolve_boundary_neighbor_patch_ids(stage2_item_state: Resource, patch_state: Resource) -> PackedStringArray:
	if stage2_item_state == null or patch_state == null or patch_state.current_quad == null:
		return PackedStringArray()
	var adjacent_patch_ids: PackedStringArray = PackedStringArray()
	if not patch_state.neighbor_patch_ids.is_empty():
		for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
			_append_unique_patch_id(adjacent_patch_ids, neighbor_patch_id_string)
		return adjacent_patch_ids
	for candidate_patch_state in stage2_item_state.patch_states:
		if candidate_patch_state == null or candidate_patch_state == patch_state or candidate_patch_state.current_quad == null:
			continue
		if _patches_share_boundary_edge_by_topology(patch_state, candidate_patch_state):
			_append_unique_patch_id(adjacent_patch_ids, String(candidate_patch_state.patch_id))
	return adjacent_patch_ids

func _shares_topology_plane_and_normal(patch_state: Resource, candidate_patch_state: Resource) -> bool:
	var patch_quad: Resource = _get_topology_quad(patch_state)
	var candidate_quad: Resource = _get_topology_quad(candidate_patch_state)
	return _shares_plane_and_normal(patch_quad, candidate_quad)

func _patches_share_boundary_edge_by_topology(patch_state: Resource, candidate_patch_state: Resource) -> bool:
	var patch_quad: Resource = _get_topology_quad(patch_state)
	var candidate_quad: Resource = _get_topology_quad(candidate_patch_state)
	if patch_quad == null or candidate_quad == null:
		return false
	if not _shares_plane_and_normal(patch_quad, candidate_quad):
		return false
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		var patch_segment: Dictionary = _build_edge_segment(patch_quad, edge_id)
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(candidate_quad, candidate_edge_id)
			if _segments_match(patch_segment, candidate_segment):
				return true
	return false

func _patches_share_boundary_edge_across_topology(patch_state: Resource, candidate_patch_state: Resource) -> bool:
	var patch_quad: Resource = _get_topology_quad(patch_state)
	var candidate_quad: Resource = _get_topology_quad(candidate_patch_state)
	if patch_quad == null or candidate_quad == null:
		return false
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		var patch_segment: Dictionary = _build_edge_segment(patch_quad, edge_id)
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(candidate_quad, candidate_edge_id)
			if _segments_match(patch_segment, candidate_segment):
				return true
	return false

func _get_topology_quad(patch_state: Resource) -> Resource:
	if patch_state == null:
		return null
	if patch_state.baseline_quad != null:
		return patch_state.baseline_quad
	return patch_state.current_quad

func _patches_share_boundary_edge(patch_state: Resource, candidate_patch_state: Resource) -> bool:
	if patch_state == null or candidate_patch_state == null:
		return false
	if patch_state.current_quad == null or candidate_patch_state.current_quad == null:
		return false
	if not _shares_plane_and_normal(patch_state.current_quad, candidate_patch_state.current_quad):
		return false
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		var patch_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(candidate_patch_state.current_quad, candidate_edge_id)
			if _segments_match(patch_segment, candidate_segment):
				return true
	return false

func _build_patch_lookup(stage2_item_state: Resource) -> Dictionary:
	var patch_lookup: Dictionary = {}
	if stage2_item_state == null:
		return patch_lookup
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null:
			continue
		patch_lookup[patch_state.patch_id] = patch_state
	return patch_lookup

func _append_unique_patch_id(target_patch_ids: PackedStringArray, patch_id: String) -> void:
	if patch_id.is_empty() or target_patch_ids.find(patch_id) != -1:
		return
	target_patch_ids.append(patch_id)

func _build_edge_segment(quad_state: Resource, edge_id: StringName) -> Dictionary:
	var origin_local: Vector3 = quad_state.origin_local
	var edge_u_local: Vector3 = quad_state.edge_u_local
	var edge_v_local: Vector3 = quad_state.edge_v_local
	match edge_id:
		EDGE_U_MIN:
			return {
				"start": origin_local,
				"end": origin_local + edge_v_local,
				"direction": edge_v_local.normalized(),
			}
		EDGE_U_MAX:
			return {
				"start": origin_local + edge_u_local,
				"end": origin_local + edge_u_local + edge_v_local,
				"direction": edge_v_local.normalized(),
			}
		EDGE_V_MIN:
			return {
				"start": origin_local,
				"end": origin_local + edge_u_local,
				"direction": edge_u_local.normalized(),
			}
		EDGE_V_MAX:
			return {
				"start": origin_local + edge_v_local,
				"end": origin_local + edge_u_local + edge_v_local,
				"direction": edge_u_local.normalized(),
			}
		_:
			return {
				"start": origin_local,
				"end": origin_local,
				"direction": Vector3.ZERO,
			}

func _segments_match(segment_a: Dictionary, segment_b: Dictionary) -> bool:
	var a_start: Vector3 = segment_a.get("start", Vector3.ZERO)
	var a_end: Vector3 = segment_a.get("end", Vector3.ZERO)
	var b_start: Vector3 = segment_b.get("start", Vector3.ZERO)
	var b_end: Vector3 = segment_b.get("end", Vector3.ZERO)
	return (
		(a_start.is_equal_approx(b_start) and a_end.is_equal_approx(b_end))
		or (a_start.is_equal_approx(b_end) and a_end.is_equal_approx(b_start))
	)

func _build_edge_segment_key(segment: Dictionary) -> String:
	var start_key: String = _build_vector3_key(segment.get("start", Vector3.ZERO))
	var end_key: String = _build_vector3_key(segment.get("end", Vector3.ZERO))
	if start_key <= end_key:
		return "%s|%s" % [start_key, end_key]
	return "%s|%s" % [end_key, start_key]

func _build_vector3_key(value: Vector3) -> String:
	return "%d_%d_%d" % [
		int(round(value.x * 1000.0)),
		int(round(value.y * 1000.0)),
		int(round(value.z * 1000.0))
	]

func _edges_share_same_line(base_segment: Dictionary, candidate_segment: Dictionary) -> bool:
	var base_direction: Vector3 = Vector3(base_segment.get("direction", Vector3.ZERO)).normalized()
	var candidate_direction: Vector3 = Vector3(candidate_segment.get("direction", Vector3.ZERO)).normalized()
	if base_direction == Vector3.ZERO or candidate_direction == Vector3.ZERO:
		return false
	var direction_alignment: float = absf(base_direction.dot(candidate_direction))
	if not is_equal_approx(direction_alignment, 1.0):
		return false
	var offset_vector: Vector3 = Vector3(candidate_segment.get("start", Vector3.ZERO)) - Vector3(base_segment.get("start", Vector3.ZERO))
	return offset_vector.cross(base_direction).length() <= 0.0001

func _resolve_edge_interval(segment: Dictionary, base_segment: Dictionary) -> Vector2:
	var base_direction: Vector3 = Vector3(base_segment.get("direction", Vector3.ZERO)).normalized()
	var base_start: Vector3 = base_segment.get("start", Vector3.ZERO)
	var segment_start: Vector3 = segment.get("start", Vector3.ZERO)
	var segment_end: Vector3 = segment.get("end", Vector3.ZERO)
	var start_scalar: float = (segment_start - base_start).dot(base_direction)
	var end_scalar: float = (segment_end - base_start).dot(base_direction)
	return Vector2(minf(start_scalar, end_scalar), maxf(start_scalar, end_scalar))

func _intervals_touch_or_overlap(interval_a: Vector2, interval_b: Vector2) -> bool:
	return interval_a.y >= interval_b.x - 0.0001 and interval_b.y >= interval_a.x - 0.0001

func _distance_point_to_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
	var segment_vector: Vector3 = segment_end - segment_start
	var segment_length_squared: float = segment_vector.length_squared()
	if segment_length_squared <= 0.00001:
		return point.distance_to(segment_start)
	var ratio: float = clampf((point - segment_start).dot(segment_vector) / segment_length_squared, 0.0, 1.0)
	var closest_point: Vector3 = segment_start + (segment_vector * ratio)
	return point.distance_to(closest_point)
