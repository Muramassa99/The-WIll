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

func is_surface_face_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_FACE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FACE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FACE_RESTORE
	)

func is_surface_edge_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_EDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_EDGE_RESTORE
	)

func is_surface_feature_edge_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE
	)

func is_surface_feature_region_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_REGION_RESTORE
	)

func is_surface_feature_band_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BAND_RESTORE
	)

func is_surface_feature_cluster_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE
	)

func is_surface_feature_bridge_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_RESTORE
	)

func is_surface_feature_contour_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_RESTORE
	)

func is_surface_feature_loop_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_FILLET
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_CHAMFER
		or tool_id == TOOL_STAGE2_SURFACE_FEATURE_LOOP_RESTORE
	)

func resolve_hover_selection_data(stage2_item_state: Resource, hit_data: Dictionary, tool_id: StringName) -> Dictionary:
	if stage2_item_state != null and stage2_item_state.has_method("resolve_hover_selection_data"):
		return stage2_item_state.call("resolve_hover_selection_data", hit_data, tool_id)
	return {}

func toggle_identifier_selection(selected_ids: PackedStringArray, target_ids: PackedStringArray) -> PackedStringArray:
	var next_selection: PackedStringArray = PackedStringArray(selected_ids)
	if target_ids.is_empty():
		return next_selection
	var should_remove: bool = true
	for target_id: String in target_ids:
		if next_selection.find(target_id) == -1:
			should_remove = false
			break
	if should_remove:
		for target_id: String in target_ids:
			var existing_index: int = next_selection.find(target_id)
			if existing_index >= 0:
				next_selection.remove_at(existing_index)
	else:
		for target_id: String in target_ids:
			if next_selection.find(target_id) == -1:
				next_selection.append(target_id)
	return next_selection

func resolve_patch_ids_for_face_ids(stage2_item_state: Resource, face_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null:
		return PackedStringArray()
	if stage2_item_state.has_method("resolve_patch_ids_for_face_ids"):
		var patch_ids = stage2_item_state.call("resolve_patch_ids_for_face_ids", face_ids)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()

func resolve_patch_ids_for_shell_edge_ids(stage2_item_state: Resource, shell_edge_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null:
		return PackedStringArray()
	if stage2_item_state.has_method("resolve_patch_ids_for_shell_edge_ids"):
		var patch_ids = stage2_item_state.call("resolve_patch_ids_for_shell_edge_ids", shell_edge_ids)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()

func resolve_patch_ids_for_shell_feature_edge_ids(stage2_item_state: Resource, shell_feature_edge_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null:
		return PackedStringArray()
	if stage2_item_state.has_method("resolve_patch_ids_for_shell_feature_edge_ids"):
		var patch_ids = stage2_item_state.call("resolve_patch_ids_for_shell_feature_edge_ids", shell_feature_edge_ids)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()

func resolve_patch_ids_for_shell_feature_region_ids(stage2_item_state: Resource, shell_feature_region_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null:
		return PackedStringArray()
	if stage2_item_state.has_method("resolve_patch_ids_for_shell_feature_region_ids"):
		var patch_ids = stage2_item_state.call("resolve_patch_ids_for_shell_feature_region_ids", shell_feature_region_ids)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()

func resolve_patch_ids_for_shell_feature_band_ids(stage2_item_state: Resource, shell_feature_band_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null or shell_feature_band_ids.is_empty():
		return PackedStringArray()
	if stage2_item_state.has_method("resolve_patch_ids_for_shell_feature_band_ids"):
		var patch_ids = stage2_item_state.call("resolve_patch_ids_for_shell_feature_band_ids", shell_feature_band_ids)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()

func resolve_patch_ids_for_shell_feature_cluster_ids(stage2_item_state: Resource, shell_feature_cluster_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null or shell_feature_cluster_ids.is_empty():
		return PackedStringArray()
	if stage2_item_state.has_method("resolve_patch_ids_for_shell_feature_cluster_ids"):
		var patch_ids = stage2_item_state.call("resolve_patch_ids_for_shell_feature_cluster_ids", shell_feature_cluster_ids)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()

func resolve_patch_ids_for_shell_feature_bridge_ids(stage2_item_state: Resource, shell_feature_bridge_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null or shell_feature_bridge_ids.is_empty():
		return PackedStringArray()
	if stage2_item_state.has_method("resolve_patch_ids_for_shell_feature_bridge_ids"):
		var patch_ids = stage2_item_state.call("resolve_patch_ids_for_shell_feature_bridge_ids", shell_feature_bridge_ids)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()

func resolve_patch_ids_for_shell_feature_contour_ids(stage2_item_state: Resource, shell_feature_contour_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null or shell_feature_contour_ids.is_empty():
		return PackedStringArray()
	if stage2_item_state.has_method("resolve_patch_ids_for_shell_feature_contour_ids"):
		var patch_ids = stage2_item_state.call("resolve_patch_ids_for_shell_feature_contour_ids", shell_feature_contour_ids)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()

func resolve_patch_ids_for_shell_feature_loop_ids(stage2_item_state: Resource, shell_feature_loop_ids: PackedStringArray) -> PackedStringArray:
	if stage2_item_state == null or shell_feature_loop_ids.is_empty():
		return PackedStringArray()
	if stage2_item_state.has_method("resolve_patch_ids_for_shell_feature_loop_ids"):
		var patch_ids = stage2_item_state.call("resolve_patch_ids_for_shell_feature_loop_ids", shell_feature_loop_ids)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()

func resolve_patch_ids_for_selection_identifiers(
	stage2_item_state: Resource,
	tool_id: StringName,
	face_ids: PackedStringArray = PackedStringArray(),
	edge_ids: PackedStringArray = PackedStringArray(),
	region_ids: PackedStringArray = PackedStringArray(),
	band_ids: PackedStringArray = PackedStringArray(),
	cluster_ids: PackedStringArray = PackedStringArray(),
	bridge_ids: PackedStringArray = PackedStringArray(),
	contour_ids: PackedStringArray = PackedStringArray(),
	loop_ids: PackedStringArray = PackedStringArray()
) -> PackedStringArray:
	if stage2_item_state != null and stage2_item_state.has_method("resolve_patch_ids_for_selection_identifiers"):
		var patch_ids = stage2_item_state.call(
			"resolve_patch_ids_for_selection_identifiers",
			tool_id,
			face_ids,
			edge_ids,
			region_ids,
			band_ids,
			cluster_ids,
			bridge_ids,
			contour_ids,
			loop_ids
		)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()

func resolve_selection_apply_state(
	stage2_item_state: Resource,
	tool_id: StringName,
	face_ids: PackedStringArray = PackedStringArray(),
	edge_ids: PackedStringArray = PackedStringArray(),
	region_ids: PackedStringArray = PackedStringArray(),
	band_ids: PackedStringArray = PackedStringArray(),
	cluster_ids: PackedStringArray = PackedStringArray(),
	bridge_ids: PackedStringArray = PackedStringArray(),
	contour_ids: PackedStringArray = PackedStringArray(),
	loop_ids: PackedStringArray = PackedStringArray()
) -> Dictionary:
	if stage2_item_state != null and stage2_item_state.has_method("resolve_selection_apply_state"):
		return stage2_item_state.call(
			"resolve_selection_apply_state",
			tool_id,
			face_ids,
			edge_ids,
			region_ids,
			band_ids,
			cluster_ids,
			bridge_ids,
			contour_ids,
			loop_ids
		)
	return {}

func resolve_selection_apply_patch_ids(
	stage2_item_state: Resource,
	selected_patch_ids: PackedStringArray,
	tool_id: StringName
) -> PackedStringArray:
	if stage2_item_state != null and stage2_item_state.has_method("resolve_selection_apply_patch_ids"):
		var patch_ids = stage2_item_state.call(
			"resolve_selection_apply_patch_ids",
			selected_patch_ids,
			tool_id
		)
		if patch_ids is PackedStringArray:
			return patch_ids
	return PackedStringArray()
