extends RefCounted
class_name Stage2ShellApplyResolver

const Stage2PatchStateScript = preload("res://core/models/stage2_patch_state.gd")
const Stage2EditableMeshBuilderScript = preload("res://core/resolvers/stage2_editable_mesh_builder.gd")

const TOOL_STAGE2_CARVE: StringName = &"stage2_carve"
const TOOL_STAGE2_RESTORE: StringName = &"stage2_restore"
const TOOL_STAGE2_FILLET: StringName = &"stage2_fillet"
const TOOL_STAGE2_CHAMFER: StringName = &"stage2_chamfer"

var editable_mesh_builder = Stage2EditableMeshBuilderScript.new()

func apply_selection_patch_ids(
	stage2_item_state: Resource,
	target_patch_ids: PackedStringArray,
	effective_tool_id: StringName,
	source_tool_id: StringName = StringName(),
	amount_ratio: float = 1.0,
	selected_vertex_indices_override: PackedInt32Array = PackedInt32Array()
) -> bool:
	if stage2_item_state == null or not stage2_item_state.has_current_shell() or target_patch_ids.is_empty():
		return false
	var filtered_target_patch_ids: PackedStringArray = PackedStringArray()
	for patch_id: String in target_patch_ids:
		var target_patch_state: Resource = null
		for patch_state in stage2_item_state.patch_states:
			if patch_state == null or patch_state.patch_id != StringName(patch_id):
				continue
			target_patch_state = patch_state
			break
		if target_patch_state == null or is_patch_tool_blocked(target_patch_state, effective_tool_id):
			continue
		filtered_target_patch_ids.append(patch_id)
	if filtered_target_patch_ids.is_empty():
		return false
	var editable_mesh_changed: bool = false
	var resolved_selection_vertex_indices: PackedInt32Array = PackedInt32Array(selected_vertex_indices_override)
	var editable_mesh_has_target_vertices: bool = (
		not resolved_selection_vertex_indices.is_empty()
		or (
			stage2_item_state.has_method("resolve_editable_mesh_vertex_indices_for_patch_ids")
			and PackedInt32Array(stage2_item_state.call("resolve_editable_mesh_vertex_indices_for_patch_ids", filtered_target_patch_ids)).size() > 0
		)
	)
	var editable_mesh_has_target_delta: bool = (
		stage2_item_state.has_method("has_editable_mesh_delta_for_patch_ids")
		and bool(stage2_item_state.call("has_editable_mesh_delta_for_patch_ids", filtered_target_patch_ids))
	)
	var editable_mesh_owns_selection_edit: bool = (
		(effective_tool_id == TOOL_STAGE2_FILLET or effective_tool_id == TOOL_STAGE2_CHAMFER)
		and stage2_item_state.has_method("has_current_editable_mesh")
		and bool(stage2_item_state.call("has_current_editable_mesh"))
		and editable_mesh_has_target_vertices
	)
	var can_use_editable_mesh_restore: bool = (
		effective_tool_id == TOOL_STAGE2_RESTORE
		and stage2_item_state.has_method("has_current_editable_mesh")
		and bool(stage2_item_state.call("has_current_editable_mesh"))
		and bool(stage2_item_state.get("editable_mesh_visual_authority"))
		and stage2_item_state.get("current_editable_mesh_state") != null
		and bool(stage2_item_state.get("current_editable_mesh_state").get("dirty"))
		and editable_mesh_has_target_vertices
		and editable_mesh_has_target_delta
	)
	if editable_mesh_owns_selection_edit or can_use_editable_mesh_restore:
		editable_mesh_changed = _apply_selection_editable_mesh(
			stage2_item_state,
			filtered_target_patch_ids,
			effective_tool_id,
			amount_ratio,
			resolved_selection_vertex_indices
		)
	if editable_mesh_changed:
		stage2_item_state.editable_mesh_visual_authority = true
		stage2_item_state.dirty = true
		stage2_item_state.last_active_tool_id = source_tool_id if source_tool_id != StringName() else effective_tool_id
		stage2_item_state.refresh_current_local_aabb_from_patches()
		return true
	if editable_mesh_owns_selection_edit:
		return false
	var changed: bool = false
	var selected_lookup: Dictionary = {}
	for patch_id: String in filtered_target_patch_ids:
		selected_lookup[StringName(patch_id)] = true
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or not patch_state.has_current_quad() or not selected_lookup.has(patch_state.patch_id):
			continue
		if _apply_selection_patch_delta(
			stage2_item_state,
			patch_state,
			effective_tool_id,
			maxf(float(stage2_item_state.cell_world_size_meters), 0.0001),
			amount_ratio
		):
			changed = true
	if not changed:
		return false
	stage2_item_state.editable_mesh_visual_authority = false
	stage2_item_state.dirty = true
	stage2_item_state.last_active_tool_id = source_tool_id if source_tool_id != StringName() else effective_tool_id
	stage2_item_state.refresh_current_local_aabb_from_patches()
	return true

func apply_pointer_brush(
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
	var cell_world_size_meters: float = maxf(float(stage2_item_state.cell_world_size_meters), 0.0001)
	var radius_cells: float = radius_meters / cell_world_size_meters
	var clamped_amount_ratio: float = clampf(amount_ratio, 0.0, 1.0)
	var step_cells: float = (step_meters / cell_world_size_meters) * maxf(clamped_amount_ratio, 0.01)
	if radius_cells <= 0.0 or step_cells <= 0.0:
		return false
	var candidate_patch_records: Array[Dictionary] = _resolve_pointer_candidate_patch_records(
		stage2_item_state,
		hit_point_local,
		radius_meters,
		hit_face_id
	)
	if candidate_patch_records.is_empty():
		return false
	var resolved_tool_axis_local: Vector3 = tool_axis_local
	if resolved_tool_axis_local == Vector3.ZERO and (tool_id == TOOL_STAGE2_CARVE or tool_id == TOOL_STAGE2_RESTORE):
		resolved_tool_axis_local = _resolve_fallback_pointer_axis_local(candidate_patch_records)
	var editable_mesh_changed: bool = false
	if tool_id == TOOL_STAGE2_CARVE or tool_id == TOOL_STAGE2_RESTORE:
		editable_mesh_changed = _apply_pointer_brush_editable_mesh(
			stage2_item_state,
			tool_id,
			hit_point_local,
			resolved_tool_axis_local,
			radius_cells,
			step_cells,
			cell_world_size_meters,
			candidate_patch_records
		)
		if editable_mesh_changed:
			stage2_item_state.editable_mesh_visual_authority = true
	var changed: bool = false
	var use_legacy_pointer_brush_path: bool = not editable_mesh_changed
	if (
		use_legacy_pointer_brush_path
		and (tool_id == TOOL_STAGE2_CARVE or tool_id == TOOL_STAGE2_RESTORE)
		and stage2_item_state.has_method("apply_shell_vertex_brush_delta_for_candidate_records")
	):
		var shell_local_candidate_records: Array[Dictionary] = []
		for candidate_patch_record: Dictionary in candidate_patch_records:
			var patch_state: Resource = candidate_patch_record.get("patch_state", null)
			if patch_state == null or not patch_state.has_current_quad() or patch_state.baseline_quad == null:
				continue
			var distance_to_hit: float = float(candidate_patch_record.get("distance_cells", INF))
			var falloff: float = _resolve_brush_falloff(tool_id, distance_to_hit, radius_cells)
			falloff *= _resolve_pointer_axis_falloff(
				tool_id,
				hit_point_local,
				resolved_tool_axis_local,
				candidate_patch_record,
				radius_cells
			)
			if falloff <= 0.0:
				continue
			if is_patch_tool_blocked(patch_state, tool_id):
				continue
			var shell_local_candidate_record: Dictionary = candidate_patch_record.duplicate()
			shell_local_candidate_record["effective_delta_cells"] = step_cells * falloff
			shell_local_candidate_records.append(shell_local_candidate_record)
		if shell_local_candidate_records.is_empty():
			if not editable_mesh_changed:
				return false
		elif stage2_item_state.apply_shell_vertex_brush_delta_for_candidate_records(
			shell_local_candidate_records,
			tool_id,
			hit_point_local,
			resolved_tool_axis_local,
			radius_cells,
			cell_world_size_meters
		):
			changed = true
	if use_legacy_pointer_brush_path:
		for candidate_patch_record: Dictionary in candidate_patch_records:
			var patch_state: Resource = candidate_patch_record.get("patch_state", null)
			if patch_state == null or not patch_state.has_current_quad() or patch_state.baseline_quad == null:
				continue
			var distance_to_hit: float = float(candidate_patch_record.get("distance_cells", INF))
			var falloff: float = _resolve_brush_falloff(tool_id, distance_to_hit, radius_cells)
			falloff *= _resolve_pointer_axis_falloff(
				tool_id,
				hit_point_local,
				resolved_tool_axis_local,
				candidate_patch_record,
				radius_cells
			)
			if falloff <= 0.0:
				continue
			if is_patch_tool_blocked(patch_state, tool_id):
				continue
			if _apply_patch_delta(
				stage2_item_state,
				patch_state,
				tool_id,
				hit_point_local,
				resolved_tool_axis_local,
				radius_cells,
				step_cells * falloff,
				cell_world_size_meters,
				clamped_amount_ratio
			):
				changed = true
	if not changed and not editable_mesh_changed:
		return false
	if not editable_mesh_changed:
		stage2_item_state.editable_mesh_visual_authority = false
	stage2_item_state.dirty = true
	stage2_item_state.last_active_tool_id = tool_id
	if editable_mesh_changed and stage2_item_state.current_editable_mesh_state != null:
		var editable_mesh_aabb: Variant = stage2_item_state.current_editable_mesh_state.get("local_aabb_position")
		if editable_mesh_aabb is Vector3:
			stage2_item_state.current_local_aabb_position = editable_mesh_aabb
		var editable_mesh_aabb_size: Variant = stage2_item_state.current_editable_mesh_state.get("local_aabb_size")
		if editable_mesh_aabb_size is Vector3:
			stage2_item_state.current_local_aabb_size = editable_mesh_aabb_size
	stage2_item_state.refresh_current_local_aabb_from_patches()
	return true

func _apply_pointer_brush_editable_mesh(
	stage2_item_state: Resource,
	tool_id: StringName,
	hit_point_local: Vector3,
	tool_axis_local: Vector3,
	radius_cells: float,
	step_cells: float,
	cell_world_size_meters: float,
	candidate_patch_records: Array[Dictionary]
) -> bool:
	if stage2_item_state == null or radius_cells <= 0.0 or step_cells <= 0.0:
		return false
	if not stage2_item_state.has_method("has_current_editable_mesh") or not bool(stage2_item_state.call("has_current_editable_mesh")):
		return false
	var editable_mesh_state: Resource = stage2_item_state.get("current_editable_mesh_state") as Resource
	var baseline_editable_mesh_state: Resource = stage2_item_state.get("baseline_editable_mesh_state") as Resource
	if editable_mesh_state == null or baseline_editable_mesh_state == null:
		return false
	var mesh_data_tool: MeshDataTool = editable_mesh_builder.build_mesh_data_tool_from_state(editable_mesh_state)
	if mesh_data_tool == null:
		return false
	var baseline_surface_arrays: Array = baseline_editable_mesh_state.get("surface_arrays") as Array
	if baseline_surface_arrays.size() <= Mesh.ARRAY_VERTEX or baseline_surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
		return false
	var baseline_vertices: PackedVector3Array = baseline_surface_arrays[Mesh.ARRAY_VERTEX]
	if baseline_vertices.size() != mesh_data_tool.get_vertex_count():
		return false
	var baseline_normals: PackedVector3Array = PackedVector3Array()
	if baseline_surface_arrays.size() > Mesh.ARRAY_NORMAL and baseline_surface_arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		baseline_normals = baseline_surface_arrays[Mesh.ARRAY_NORMAL]
	var unblocked_patch_records: Array[Dictionary] = []
	var max_offset_cells: float = INF
	for candidate_patch_record: Dictionary in candidate_patch_records:
		var patch_state: Resource = candidate_patch_record.get("patch_state", null)
		if patch_state == null or is_patch_tool_blocked(patch_state, tool_id):
			continue
		unblocked_patch_records.append(candidate_patch_record)
		var patch_max_offset_cells: float = _resolve_patch_tool_max_offset_cells(
			patch_state,
			tool_id,
			cell_world_size_meters
		)
		if patch_max_offset_cells > 0.0:
			max_offset_cells = minf(max_offset_cells, patch_max_offset_cells)
	if unblocked_patch_records.is_empty():
		return false
	if max_offset_cells == INF:
		max_offset_cells = step_cells
	var normalized_axis: Vector3 = tool_axis_local.normalized()
	if normalized_axis == Vector3.ZERO and tool_id == TOOL_STAGE2_CARVE:
		return false
	if normalized_axis == Vector3.ZERO:
		normalized_axis = _resolve_fallback_pointer_axis_local(unblocked_patch_records)
	if normalized_axis == Vector3.ZERO:
		normalized_axis = Vector3.FORWARD
	var candidate_vertex_indices: PackedInt32Array = PackedInt32Array()
	if stage2_item_state.has_method("resolve_editable_mesh_vertex_indices_for_patch_ids"):
		var candidate_patch_ids: PackedStringArray = PackedStringArray()
		var candidate_patch_lookup: Dictionary = {}
		for candidate_patch_record: Dictionary in unblocked_patch_records:
			var candidate_patch_id: String = String(candidate_patch_record.get("patch_id", ""))
			if candidate_patch_id.is_empty() or candidate_patch_lookup.has(candidate_patch_id):
				continue
			candidate_patch_lookup[candidate_patch_id] = true
			candidate_patch_ids.append(candidate_patch_id)
		candidate_vertex_indices = PackedInt32Array(stage2_item_state.call("resolve_editable_mesh_vertex_indices_for_patch_ids", candidate_patch_ids))
	var original_vertices: PackedVector3Array = PackedVector3Array()
	original_vertices.resize(mesh_data_tool.get_vertex_count())
	var influenced_vertex_weights: Dictionary = {}
	var influenced_vertex_normals: Dictionary = {}
	var candidate_depth_limits: Dictionary = _resolve_pointer_depth_limits_cells(radius_cells, max_offset_cells)
	var pointer_vertex_indices: PackedInt32Array = candidate_vertex_indices
	if pointer_vertex_indices.is_empty():
		pointer_vertex_indices.resize(mesh_data_tool.get_vertex_count())
		for vertex_index_fill: int in range(mesh_data_tool.get_vertex_count()):
			pointer_vertex_indices[vertex_index_fill] = vertex_index_fill
	for vertex_index: int in pointer_vertex_indices:
		if vertex_index < 0 or vertex_index >= mesh_data_tool.get_vertex_count():
			continue
		var current_vertex_local: Vector3 = mesh_data_tool.get_vertex(vertex_index)
		original_vertices[vertex_index] = current_vertex_local
		if _is_editable_mesh_vertex_blocked(current_vertex_local, unblocked_patch_records, candidate_patch_records, tool_id):
			continue
		var baseline_vertex_normal: Vector3 = Vector3.ZERO
		if vertex_index >= 0 and vertex_index < baseline_normals.size():
			baseline_vertex_normal = baseline_normals[vertex_index]
		elif vertex_index >= 0 and vertex_index < mesh_data_tool.get_vertex_count():
			baseline_vertex_normal = mesh_data_tool.get_vertex_normal(vertex_index)
		var vertex_weight: float = _resolve_editable_mesh_pointer_vertex_weight(
			current_vertex_local,
			baseline_vertex_normal,
			hit_point_local,
			normalized_axis,
			radius_cells,
			float(candidate_depth_limits.get("forward_limit_cells", radius_cells)),
			float(candidate_depth_limits.get("backward_limit_cells", maxf(radius_cells * 0.15, 0.2)))
		)
		if vertex_weight <= 0.0:
			continue
		influenced_vertex_weights[vertex_index] = vertex_weight
		influenced_vertex_normals[vertex_index] = baseline_vertex_normal
	if influenced_vertex_weights.is_empty():
		return false
	var changed: bool = false
	match tool_id:
		TOOL_STAGE2_CARVE, TOOL_STAGE2_RESTORE:
			for vertex_index_value in influenced_vertex_weights.keys():
				var vertex_index: int = int(vertex_index_value)
				var current_vertex_local: Vector3 = original_vertices[vertex_index]
				var baseline_vertex_local: Vector3 = baseline_vertices[vertex_index]
				var baseline_vertex_normal: Vector3 = Vector3(influenced_vertex_normals.get(vertex_index_value, Vector3.ZERO))
				var vertex_weight: float = float(influenced_vertex_weights.get(vertex_index_value, 0.0))
				var next_vertex_local: Vector3 = current_vertex_local
				var effective_delta_cells: float = step_cells * vertex_weight
				match tool_id:
					TOOL_STAGE2_CARVE:
						next_vertex_local = current_vertex_local + (normalized_axis * effective_delta_cells)
						next_vertex_local = _clamp_editable_mesh_vertex_to_inward_baseline_limit(
							next_vertex_local,
							baseline_vertex_local,
							baseline_vertex_normal,
							max_offset_cells
						)
					TOOL_STAGE2_RESTORE:
						var to_baseline: Vector3 = baseline_vertex_local - current_vertex_local
						if to_baseline.length() <= effective_delta_cells:
							next_vertex_local = baseline_vertex_local
						elif to_baseline.length() > 0.00001:
							next_vertex_local = current_vertex_local + (to_baseline.normalized() * effective_delta_cells)
				if current_vertex_local.is_equal_approx(next_vertex_local):
					continue
				mesh_data_tool.set_vertex(vertex_index, next_vertex_local)
				changed = true
		TOOL_STAGE2_CHAMFER:
			var chamfer_plane_origin: Vector3 = _resolve_editable_mesh_chamfer_plane_origin(
				original_vertices,
				influenced_vertex_weights,
				normalized_axis,
				step_cells,
				max_offset_cells
			)
			for vertex_index_value in influenced_vertex_weights.keys():
				var vertex_index: int = int(vertex_index_value)
				var current_vertex_local: Vector3 = original_vertices[vertex_index]
				var baseline_vertex_local: Vector3 = baseline_vertices[vertex_index]
				var vertex_weight: float = float(influenced_vertex_weights.get(vertex_index_value, 0.0))
				var projected_vertex_local: Vector3 = current_vertex_local - (
					normalized_axis * (current_vertex_local - chamfer_plane_origin).dot(normalized_axis)
				)
				var next_vertex_local: Vector3 = current_vertex_local.lerp(projected_vertex_local, vertex_weight)
				next_vertex_local = _clamp_editable_mesh_vertex_to_baseline_limit(
					next_vertex_local,
					baseline_vertex_local,
					max_offset_cells
				)
				if current_vertex_local.is_equal_approx(next_vertex_local):
					continue
				mesh_data_tool.set_vertex(vertex_index, next_vertex_local)
				changed = true
		TOOL_STAGE2_FILLET:
			var neighbor_lookup: Dictionary = _build_editable_mesh_vertex_neighbor_lookup(mesh_data_tool)
			for vertex_index_value in influenced_vertex_weights.keys():
				var vertex_index: int = int(vertex_index_value)
				var current_vertex_local: Vector3 = original_vertices[vertex_index]
				var baseline_vertex_local: Vector3 = baseline_vertices[vertex_index]
				var vertex_weight: float = float(influenced_vertex_weights.get(vertex_index_value, 0.0))
				var smoothed_target_local: Vector3 = _resolve_editable_mesh_fillet_target_local(
					vertex_index,
					original_vertices,
					neighbor_lookup,
					current_vertex_local,
					normalized_axis,
					step_cells * vertex_weight
				)
				var fillet_blend: float = clampf(vertex_weight * 0.85, 0.0, 1.0)
				var next_vertex_local: Vector3 = current_vertex_local.lerp(smoothed_target_local, fillet_blend)
				next_vertex_local = _clamp_editable_mesh_vertex_to_baseline_limit(
					next_vertex_local,
					baseline_vertex_local,
					max_offset_cells
				)
				if current_vertex_local.is_equal_approx(next_vertex_local):
					continue
				mesh_data_tool.set_vertex(vertex_index, next_vertex_local)
				changed = true
		_:
			return false
	if not changed:
		return false
	if not editable_mesh_builder.commit_mesh_data_tool_to_state(editable_mesh_state, mesh_data_tool):
		return false
	if stage2_item_state.has_method("sync_patch_states_from_current_editable_mesh"):
		stage2_item_state.sync_patch_states_from_current_editable_mesh()
	editable_mesh_state.dirty = true
	return true

func _apply_selection_editable_mesh(
	stage2_item_state: Resource,
	target_patch_ids: PackedStringArray,
	effective_tool_id: StringName,
	amount_ratio: float,
	selected_vertex_indices_override: PackedInt32Array = PackedInt32Array()
) -> bool:
	if (
		stage2_item_state == null
		or target_patch_ids.is_empty()
		or not stage2_item_state.has_method("has_current_editable_mesh")
		or not bool(stage2_item_state.call("has_current_editable_mesh"))
	):
		return false
	var editable_mesh_state: Resource = stage2_item_state.get("current_editable_mesh_state") as Resource
	var baseline_editable_mesh_state: Resource = stage2_item_state.get("baseline_editable_mesh_state") as Resource
	if editable_mesh_state == null or baseline_editable_mesh_state == null:
		return false
	var mesh_data_tool: MeshDataTool = editable_mesh_builder.build_mesh_data_tool_from_state(editable_mesh_state)
	if mesh_data_tool == null:
		return false
	var baseline_surface_arrays: Array = baseline_editable_mesh_state.get("surface_arrays") as Array
	if baseline_surface_arrays.size() <= Mesh.ARRAY_VERTEX or baseline_surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
		return false
	var baseline_vertices: PackedVector3Array = baseline_surface_arrays[Mesh.ARRAY_VERTEX]
	if baseline_vertices.size() != mesh_data_tool.get_vertex_count():
		return false
	if not stage2_item_state.has_method("resolve_editable_mesh_vertex_indices_for_patch_ids"):
		return false
	var selected_vertex_indices: PackedInt32Array = PackedInt32Array(selected_vertex_indices_override)
	if selected_vertex_indices.is_empty():
		selected_vertex_indices = stage2_item_state.resolve_editable_mesh_vertex_indices_for_patch_ids(target_patch_ids)
	if selected_vertex_indices.is_empty():
		return false
	var cell_world_size_meters: float = maxf(float(stage2_item_state.cell_world_size_meters), 0.0001)
	var clamped_amount_ratio: float = clampf(amount_ratio, 0.0, 1.0)
	var max_offset_cells: float = INF
	for patch_id: String in target_patch_ids:
		for patch_state in stage2_item_state.patch_states:
			if patch_state == null or patch_state.patch_id != StringName(patch_id):
				continue
			var patch_max_offset_cells: float = _resolve_patch_tool_max_offset_cells(
				patch_state,
				effective_tool_id,
				cell_world_size_meters
			) * maxf(clamped_amount_ratio, 0.01)
			if patch_max_offset_cells > 0.0:
				max_offset_cells = minf(max_offset_cells, patch_max_offset_cells)
			break
	if max_offset_cells == INF:
		return false
	var original_vertices: PackedVector3Array = PackedVector3Array()
	original_vertices.resize(mesh_data_tool.get_vertex_count())
	for vertex_index: int in range(mesh_data_tool.get_vertex_count()):
		original_vertices[vertex_index] = mesh_data_tool.get_vertex(vertex_index)
	var selection_axis_local: Vector3 = _resolve_editable_mesh_selection_axis_local(mesh_data_tool, selected_vertex_indices)
	if selection_axis_local == Vector3.ZERO:
		selection_axis_local = _resolve_selection_axis_local_from_patch_ids(stage2_item_state, target_patch_ids)
	if selection_axis_local == Vector3.ZERO:
		selection_axis_local = Vector3.FORWARD
	var influenced_vertex_weights: Dictionary = {}
	for vertex_index: int in selected_vertex_indices:
		influenced_vertex_weights[vertex_index] = 1.0
	var changed: bool = false
	match effective_tool_id:
		TOOL_STAGE2_RESTORE:
			for vertex_index: int in selected_vertex_indices:
				var current_vertex_local: Vector3 = original_vertices[vertex_index]
				var baseline_vertex_local: Vector3 = baseline_vertices[vertex_index]
				var next_vertex_local: Vector3 = current_vertex_local.lerp(baseline_vertex_local, clamped_amount_ratio)
				if current_vertex_local.is_equal_approx(next_vertex_local):
					continue
				mesh_data_tool.set_vertex(vertex_index, next_vertex_local)
				changed = true
		TOOL_STAGE2_CHAMFER:
			var chamfer_plane_origin: Vector3 = _resolve_editable_mesh_chamfer_plane_origin(
				original_vertices,
				influenced_vertex_weights,
				selection_axis_local,
				max_offset_cells,
				max_offset_cells
			)
			for vertex_index: int in selected_vertex_indices:
				var current_vertex_local: Vector3 = original_vertices[vertex_index]
				var baseline_vertex_local: Vector3 = baseline_vertices[vertex_index]
				var projected_vertex_local: Vector3 = current_vertex_local - (
					selection_axis_local * (current_vertex_local - chamfer_plane_origin).dot(selection_axis_local)
				)
				var next_vertex_local: Vector3 = current_vertex_local.lerp(projected_vertex_local, clamped_amount_ratio)
				next_vertex_local = _clamp_editable_mesh_vertex_to_baseline_limit(
					next_vertex_local,
					baseline_vertex_local,
					max_offset_cells
				)
				if current_vertex_local.is_equal_approx(next_vertex_local):
					continue
				mesh_data_tool.set_vertex(vertex_index, next_vertex_local)
				changed = true
		TOOL_STAGE2_FILLET:
			var neighbor_lookup: Dictionary = _build_editable_mesh_vertex_neighbor_lookup(mesh_data_tool)
			for vertex_index: int in selected_vertex_indices:
				var current_vertex_local: Vector3 = original_vertices[vertex_index]
				var baseline_vertex_local: Vector3 = baseline_vertices[vertex_index]
				var smoothed_target_local: Vector3 = _resolve_editable_mesh_fillet_target_local(
					vertex_index,
					original_vertices,
					neighbor_lookup,
					current_vertex_local,
					selection_axis_local,
					max_offset_cells
				)
				var next_vertex_local: Vector3 = current_vertex_local.lerp(smoothed_target_local, clampf(clamped_amount_ratio * 0.85, 0.0, 1.0))
				next_vertex_local = _clamp_editable_mesh_vertex_to_baseline_limit(
					next_vertex_local,
					baseline_vertex_local,
					max_offset_cells
				)
				if current_vertex_local.is_equal_approx(next_vertex_local):
					continue
				mesh_data_tool.set_vertex(vertex_index, next_vertex_local)
				changed = true
		_:
			return false
	if not changed and (effective_tool_id == TOOL_STAGE2_CHAMFER or effective_tool_id == TOOL_STAGE2_FILLET):
		changed = _apply_selection_editable_mesh_inset_fallback(
			mesh_data_tool,
			original_vertices,
			baseline_vertices,
			selected_vertex_indices,
			selection_axis_local,
			max_offset_cells,
			clamped_amount_ratio,
			effective_tool_id
		)
	if not changed:
		return false
	if not editable_mesh_builder.commit_mesh_data_tool_to_state(editable_mesh_state, mesh_data_tool):
		return false
	if stage2_item_state.has_method("sync_patch_states_from_current_editable_mesh"):
		stage2_item_state.sync_patch_states_from_current_editable_mesh()
	editable_mesh_state.dirty = true
	return true

func _resolve_patch_tool_max_offset_cells(
	patch_state: Resource,
	tool_id: StringName,
	cell_world_size_meters: float
) -> float:
	if patch_state == null:
		return 0.0
	match tool_id:
		TOOL_STAGE2_FILLET:
			return float(patch_state.max_fillet_offset_meters) / maxf(cell_world_size_meters, 0.0001)
		TOOL_STAGE2_CHAMFER:
			return float(patch_state.max_chamfer_offset_meters) / maxf(cell_world_size_meters, 0.0001)
		_:
			return float(patch_state.max_inward_offset_meters) / maxf(cell_world_size_meters, 0.0001)

func _resolve_fallback_pointer_axis_local(candidate_patch_records: Array[Dictionary]) -> Vector3:
	var accumulated_normal: Vector3 = Vector3.ZERO
	for candidate_patch_record: Dictionary in candidate_patch_records:
		var surface_normal: Vector3 = candidate_patch_record.get("surface_normal", Vector3.ZERO)
		if surface_normal == Vector3.ZERO:
			continue
		accumulated_normal += surface_normal.normalized()
	if accumulated_normal == Vector3.ZERO:
		return Vector3.ZERO
	return -accumulated_normal.normalized()

func _resolve_editable_mesh_selection_axis_local(
	mesh_data_tool: MeshDataTool,
	selected_vertex_indices: PackedInt32Array
) -> Vector3:
	if mesh_data_tool == null or selected_vertex_indices.is_empty():
		return Vector3.ZERO
	var accumulated_normal: Vector3 = Vector3.ZERO
	for vertex_index: int in selected_vertex_indices:
		if vertex_index < 0 or vertex_index >= mesh_data_tool.get_vertex_count():
			continue
		accumulated_normal += mesh_data_tool.get_vertex_normal(vertex_index)
	if accumulated_normal == Vector3.ZERO:
		return Vector3.ZERO
	return -accumulated_normal.normalized()

func _resolve_selection_axis_local_from_patch_ids(
	stage2_item_state: Resource,
	target_patch_ids: PackedStringArray
) -> Vector3:
	if stage2_item_state == null or target_patch_ids.is_empty():
		return Vector3.ZERO
	var selected_patch_lookup: Dictionary = {}
	for patch_id: String in target_patch_ids:
		selected_patch_lookup[StringName(patch_id)] = true
	var accumulated_normal: Vector3 = Vector3.ZERO
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or not selected_patch_lookup.has(patch_state.patch_id):
			continue
		var reference_quad: Resource = patch_state.current_quad if patch_state.current_quad != null else patch_state.baseline_quad
		if reference_quad == null:
			continue
		var patch_normal: Vector3 = reference_quad.normal.normalized()
		if patch_normal == Vector3.ZERO:
			continue
		accumulated_normal += patch_normal
	if accumulated_normal == Vector3.ZERO:
		return Vector3.ZERO
	return -accumulated_normal.normalized()

func _resolve_editable_mesh_vertex_weight(
	vertex_local: Vector3,
	hit_point_local: Vector3,
	tool_axis_local: Vector3,
	radius_cells: float
) -> float:
	if radius_cells <= 0.0:
		return 0.0
	var effective_radius_cells: float = maxf(radius_cells, 0.75)
	var relative_vertex: Vector3 = vertex_local - hit_point_local
	var lateral_delta: Vector3 = relative_vertex - (tool_axis_local * relative_vertex.dot(tool_axis_local))
	var lateral_distance_cells: float = lateral_delta.length()
	if lateral_distance_cells > effective_radius_cells:
		return 0.0
	return 1.0 - clampf(lateral_distance_cells / effective_radius_cells, 0.0, 1.0)

func _resolve_editable_mesh_pointer_vertex_weight(
	vertex_local: Vector3,
	baseline_vertex_normal: Vector3,
	hit_point_local: Vector3,
	tool_axis_local: Vector3,
	radius_cells: float,
	forward_limit_cells: float,
	backward_limit_cells: float
) -> float:
	var normalized_axis: Vector3 = tool_axis_local.normalized()
	if normalized_axis == Vector3.ZERO:
		return 0.0
	var lateral_weight: float = _resolve_editable_mesh_vertex_weight(
		vertex_local,
		hit_point_local,
		normalized_axis,
		radius_cells
	)
	if lateral_weight <= 0.0:
		return 0.0
	var relative_vertex: Vector3 = vertex_local - hit_point_local
	var axial_distance_cells: float = relative_vertex.dot(normalized_axis)
	var effective_forward_limit: float = maxf(forward_limit_cells, 0.35)
	var effective_backward_limit: float = maxf(backward_limit_cells, 0.15)
	if axial_distance_cells > effective_forward_limit or axial_distance_cells < -effective_backward_limit:
		return 0.0
	var depth_weight: float = 1.0
	if axial_distance_cells >= 0.0:
		depth_weight = 1.0 - clampf(axial_distance_cells / effective_forward_limit, 0.0, 1.0)
	else:
		depth_weight = 1.0 - clampf(absf(axial_distance_cells) / effective_backward_limit, 0.0, 1.0)
	var facing_weight: float = 1.0
	if baseline_vertex_normal != Vector3.ZERO:
		facing_weight = clampf(-baseline_vertex_normal.normalized().dot(normalized_axis), 0.0, 1.0)
	if facing_weight <= 0.0001:
		return 0.0
	return _smooth_brush_weight(lateral_weight) * _smooth_brush_weight(depth_weight) * facing_weight

func _resolve_pointer_depth_limits_cells(radius_cells: float, max_offset_cells: float) -> Dictionary:
	var effective_radius_cells: float = maxf(radius_cells, 0.5)
	var effective_max_offset_cells: float = maxf(max_offset_cells, 0.5)
	return {
		"forward_limit_cells": maxf(0.75, minf(effective_radius_cells * 0.55, effective_max_offset_cells * 1.5)),
		"backward_limit_cells": maxf(0.2, minf(effective_radius_cells * 0.18, 0.5)),
	}

func _smooth_brush_weight(weight: float) -> float:
	var clamped_weight: float = clampf(weight, 0.0, 1.0)
	return clamped_weight * clamped_weight * (3.0 - (2.0 * clamped_weight))

func _build_editable_mesh_vertex_neighbor_lookup(mesh_data_tool: MeshDataTool) -> Dictionary:
	var neighbor_lookup: Dictionary = {}
	if mesh_data_tool == null:
		return neighbor_lookup
	for vertex_index: int in range(mesh_data_tool.get_vertex_count()):
		var neighbor_map: Dictionary = {}
		var face_indices: PackedInt32Array = mesh_data_tool.get_vertex_faces(vertex_index)
		for face_index: int in face_indices:
			for face_vertex_slot: int in range(3):
				var face_vertex_index: int = mesh_data_tool.get_face_vertex(face_index, face_vertex_slot)
				if face_vertex_index == vertex_index:
					continue
				neighbor_map[face_vertex_index] = true
		neighbor_lookup[vertex_index] = neighbor_map.keys()
	return neighbor_lookup

func _resolve_editable_mesh_chamfer_plane_origin(
	original_vertices: PackedVector3Array,
	influenced_vertex_weights: Dictionary,
	plane_normal: Vector3,
	step_cells: float,
	max_offset_cells: float
) -> Vector3:
	var weighted_center: Vector3 = Vector3.ZERO
	var total_weight: float = 0.0
	for vertex_index_value in influenced_vertex_weights.keys():
		var vertex_index: int = int(vertex_index_value)
		var weight: float = float(influenced_vertex_weights.get(vertex_index_value, 0.0))
		weighted_center += original_vertices[vertex_index] * weight
		total_weight += weight
	if total_weight <= 0.00001:
		return Vector3.ZERO
	weighted_center /= total_weight
	return weighted_center + (plane_normal * minf(step_cells, max_offset_cells))

func _resolve_editable_mesh_fillet_target_local(
	vertex_index: int,
	original_vertices: PackedVector3Array,
	neighbor_lookup: Dictionary,
	fallback_vertex_local: Vector3,
	tool_axis_local: Vector3,
	inward_delta_cells: float
) -> Vector3:
	var neighbor_indices: Array = neighbor_lookup.get(vertex_index, [])
	if neighbor_indices.is_empty():
		return fallback_vertex_local + (tool_axis_local * (inward_delta_cells * 0.2))
	var neighbor_average: Vector3 = Vector3.ZERO
	var neighbor_count: int = 0
	for neighbor_index_value in neighbor_indices:
		var neighbor_index: int = int(neighbor_index_value)
		if neighbor_index < 0 or neighbor_index >= original_vertices.size():
			continue
		neighbor_average += original_vertices[neighbor_index]
		neighbor_count += 1
	if neighbor_count <= 0:
		return fallback_vertex_local + (tool_axis_local * (inward_delta_cells * 0.2))
	neighbor_average /= float(neighbor_count)
	return neighbor_average + (tool_axis_local * (inward_delta_cells * 0.2))

func _apply_selection_editable_mesh_inset_fallback(
	mesh_data_tool: MeshDataTool,
	original_vertices: PackedVector3Array,
	baseline_vertices: PackedVector3Array,
	selected_vertex_indices: PackedInt32Array,
	selection_axis_local: Vector3,
	max_offset_cells: float,
	amount_ratio: float,
	effective_tool_id: StringName
) -> bool:
	if (
		mesh_data_tool == null
		or selected_vertex_indices.is_empty()
		or original_vertices.size() != baseline_vertices.size()
	):
		return false
	var normalized_axis: Vector3 = selection_axis_local.normalized()
	if normalized_axis == Vector3.ZERO:
		return false
	var changed: bool = false
	var fallback_step_cells: float = maxf(max_offset_cells * maxf(amount_ratio, 0.01), 0.0001)
	var fallback_fillet_step_cells: float = fallback_step_cells * 0.35
	var neighbor_lookup: Dictionary = {}
	if effective_tool_id == TOOL_STAGE2_FILLET:
		neighbor_lookup = _build_editable_mesh_vertex_neighbor_lookup(mesh_data_tool)
	for vertex_index: int in selected_vertex_indices:
		if vertex_index < 0 or vertex_index >= original_vertices.size():
			continue
		var current_vertex_local: Vector3 = original_vertices[vertex_index]
		var baseline_vertex_local: Vector3 = baseline_vertices[vertex_index]
		var next_vertex_local: Vector3 = current_vertex_local
		match effective_tool_id:
			TOOL_STAGE2_CHAMFER:
				next_vertex_local = current_vertex_local + (normalized_axis * fallback_step_cells)
			TOOL_STAGE2_FILLET:
				var smoothed_target_local: Vector3 = _resolve_editable_mesh_fillet_target_local(
					vertex_index,
					original_vertices,
					neighbor_lookup,
					current_vertex_local,
					normalized_axis,
					fallback_fillet_step_cells
				)
				next_vertex_local = current_vertex_local.lerp(smoothed_target_local, clampf(amount_ratio * 0.65, 0.0, 1.0))
			_:
				return false
		next_vertex_local = _clamp_editable_mesh_vertex_to_baseline_limit(
			next_vertex_local,
			baseline_vertex_local,
			max_offset_cells
		)
		if current_vertex_local.is_equal_approx(next_vertex_local):
			continue
		mesh_data_tool.set_vertex(vertex_index, next_vertex_local)
		changed = true
	return changed

func _clamp_editable_mesh_vertex_to_baseline_limit(
	candidate_vertex_local: Vector3,
	baseline_vertex_local: Vector3,
	max_offset_cells: float
) -> Vector3:
	if max_offset_cells <= 0.0:
		return baseline_vertex_local
	var baseline_delta: Vector3 = candidate_vertex_local - baseline_vertex_local
	if baseline_delta.length() <= max_offset_cells or baseline_delta.length() <= 0.00001:
		return candidate_vertex_local
	return baseline_vertex_local + (baseline_delta.normalized() * max_offset_cells)

func _clamp_editable_mesh_vertex_to_inward_baseline_limit(
	candidate_vertex_local: Vector3,
	baseline_vertex_local: Vector3,
	baseline_vertex_normal: Vector3,
	max_offset_cells: float
) -> Vector3:
	var clamped_vertex_local: Vector3 = _clamp_editable_mesh_vertex_to_baseline_limit(
		candidate_vertex_local,
		baseline_vertex_local,
		max_offset_cells
	)
	if baseline_vertex_normal == Vector3.ZERO:
		return clamped_vertex_local
	var normalized_baseline_normal: Vector3 = baseline_vertex_normal.normalized()
	var baseline_delta: Vector3 = clamped_vertex_local - baseline_vertex_local
	var outward_component: float = baseline_delta.dot(normalized_baseline_normal)
	if outward_component <= 0.0:
		return clamped_vertex_local
	return clamped_vertex_local - (normalized_baseline_normal * outward_component)

func _is_editable_mesh_vertex_blocked(
	vertex_local: Vector3,
	unblocked_patch_records: Array[Dictionary],
	candidate_patch_records: Array[Dictionary],
	tool_id: StringName
) -> bool:
	var nearest_patch_state: Resource = null
	var best_distance: float = INF
	for candidate_patch_record: Dictionary in candidate_patch_records:
		var patch_state: Resource = candidate_patch_record.get("patch_state", null)
		if patch_state == null:
			continue
		var surface_center_local: Vector3 = candidate_patch_record.get("surface_center_local", Vector3.ZERO)
		var distance_to_vertex: float = surface_center_local.distance_to(vertex_local)
		if distance_to_vertex >= best_distance:
			continue
		best_distance = distance_to_vertex
		nearest_patch_state = patch_state
	if nearest_patch_state == null:
		return false
	if not is_patch_tool_blocked(nearest_patch_state, tool_id):
		return false
	for unblocked_patch_record: Dictionary in unblocked_patch_records:
		var unblocked_patch_state: Resource = unblocked_patch_record.get("patch_state", null)
		if unblocked_patch_state == null:
			continue
		if unblocked_patch_state.patch_id == nearest_patch_state.patch_id:
			return false
	return true

func _resolve_pointer_axis_falloff(
	tool_id: StringName,
	hit_point_local: Vector3,
	tool_axis_local: Vector3,
	candidate_patch_record: Dictionary,
	radius_cells: float
) -> float:
	if tool_id != TOOL_STAGE2_CARVE:
		return 1.0
	var normalized_axis: Vector3 = tool_axis_local.normalized()
	if normalized_axis == Vector3.ZERO:
		return 1.0
	var surface_center_local: Vector3 = candidate_patch_record.get("surface_center_local", hit_point_local)
	var surface_normal: Vector3 = candidate_patch_record.get("surface_normal", Vector3.ZERO)
	var center_delta: Vector3 = surface_center_local - hit_point_local
	var lateral_delta: Vector3 = center_delta - (normalized_axis * center_delta.dot(normalized_axis))
	var lateral_distance_cells: float = lateral_delta.length()
	if lateral_distance_cells > radius_cells:
		return 0.0
	var lateral_falloff: float = 1.0 - clampf(lateral_distance_cells / radius_cells, 0.0, 1.0)
	var facing_alignment: float = 1.0
	if surface_normal != Vector3.ZERO:
		facing_alignment = clampf(absf(surface_normal.normalized().dot(normalized_axis)), 0.15, 1.0)
	if facing_alignment <= 0.0001:
		return 0.0
	return lateral_falloff * facing_alignment

func _resolve_pointer_candidate_patch_records(
	stage2_item_state: Resource,
	hit_point_local: Vector3,
	radius_meters: float,
	hit_face_id: StringName
) -> Array[Dictionary]:
	var candidate_patch_records: Array[Dictionary] = []
	if stage2_item_state == null:
		return candidate_patch_records
	if not stage2_item_state.has_method("resolve_shell_brush_candidate_records_for_sphere"):
		return candidate_patch_records
	return stage2_item_state.resolve_shell_brush_candidate_records_for_sphere(
		hit_point_local,
		radius_meters,
		hit_face_id
	)

func selection_target_set_has_blocked_patch(
	stage2_item_state: Resource,
	target_patch_ids: PackedStringArray,
	effective_tool_id: StringName
) -> bool:
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

func _apply_patch_delta(
	stage2_item_state: Resource,
	patch_state: Resource,
	tool_id: StringName,
	hit_point_local: Vector3,
	tool_axis_local: Vector3,
	radius_cells: float,
	step_cells: float,
	cell_world_size_meters: float,
	amount_ratio: float
) -> bool:
	var current_quad: Resource = patch_state.current_quad
	var normal: Vector3 = current_quad.normal.normalized()
	if normal == Vector3.ZERO:
		return false
	var clamped_amount_ratio: float = clampf(amount_ratio, 0.0, 1.0)
	if (
		(tool_id == TOOL_STAGE2_CARVE or tool_id == TOOL_STAGE2_RESTORE)
		and stage2_item_state.has_method("apply_shell_vertex_brush_delta_for_patch")
	):
		return stage2_item_state.apply_shell_vertex_brush_delta_for_patch(
			patch_state,
			tool_id,
			hit_point_local,
			tool_axis_local,
			maxf(radius_cells, 0.0001),
			step_cells,
			cell_world_size_meters
		)
	var max_offset_cells: float = (float(patch_state.max_inward_offset_meters) / cell_world_size_meters) * clamped_amount_ratio
	var max_fillet_offset_cells: float = (float(patch_state.max_fillet_offset_meters) / cell_world_size_meters) * clamped_amount_ratio
	var max_chamfer_offset_cells: float = (float(patch_state.max_chamfer_offset_meters) / cell_world_size_meters) * clamped_amount_ratio
	var current_offset_cells: float = stage2_item_state.resolve_current_offset_cells(patch_state)
	var next_offset_cells: float = current_offset_cells
	match tool_id:
		TOOL_STAGE2_CARVE:
			next_offset_cells = minf(max_offset_cells, current_offset_cells + step_cells)
		TOOL_STAGE2_RESTORE:
			next_offset_cells = maxf(0.0, current_offset_cells - step_cells)
		TOOL_STAGE2_FILLET:
			next_offset_cells = minf(maxf(0.0, max_fillet_offset_cells), current_offset_cells + step_cells)
		TOOL_STAGE2_CHAMFER:
			next_offset_cells = minf(maxf(0.0, max_chamfer_offset_cells), current_offset_cells + step_cells)
		_:
			return false
	if is_equal_approx(next_offset_cells, current_offset_cells):
		return false
	return stage2_item_state.set_shell_patch_offset_cells_for_patch(patch_state, next_offset_cells)

func _apply_selection_patch_delta(
	stage2_item_state: Resource,
	patch_state: Resource,
	tool_id: StringName,
	cell_world_size_meters: float,
	amount_ratio: float
) -> bool:
	var current_quad: Resource = patch_state.current_quad
	var normal: Vector3 = current_quad.normal.normalized()
	if normal == Vector3.ZERO:
		return false
	var clamped_amount_ratio: float = clampf(amount_ratio, 0.0, 1.0)
	var current_offset_cells: float = stage2_item_state.resolve_current_offset_cells(patch_state)
	var target_offset_cells: float = 0.0
	match tool_id:
		TOOL_STAGE2_FILLET:
			target_offset_cells = (float(patch_state.max_fillet_offset_meters) / cell_world_size_meters) * clamped_amount_ratio
		TOOL_STAGE2_CHAMFER:
			target_offset_cells = (float(patch_state.max_chamfer_offset_meters) / cell_world_size_meters) * clamped_amount_ratio
		TOOL_STAGE2_RESTORE:
			target_offset_cells = maxf(current_offset_cells * (1.0 - clamped_amount_ratio), 0.0)
		_:
			return false
	if is_equal_approx(target_offset_cells, current_offset_cells):
		return false
	return stage2_item_state.set_shell_patch_offset_cells_for_patch(patch_state, maxf(target_offset_cells, 0.0))

func _resolve_brush_falloff(tool_id: StringName, distance_to_hit: float, radius_cells: float) -> float:
	match tool_id:
		TOOL_STAGE2_CHAMFER:
			return 1.0
		_:
			return 1.0 - clampf(distance_to_hit / radius_cells, 0.0, 1.0)
