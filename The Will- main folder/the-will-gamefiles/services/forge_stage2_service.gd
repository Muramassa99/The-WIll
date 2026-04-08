extends RefCounted
class_name ForgeStage2Service

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const CraftedItemCanonicalSolidResolverScript = preload("res://core/resolvers/crafted_item_canonical_solid_resolver.gd")
const CraftedItemCanonicalGeometryResolverScript = preload("res://core/resolvers/crafted_item_canonical_geometry_resolver.gd")
const CraftedItemCanonicalSurfaceQuadScript = preload("res://core/models/crafted_item_canonical_surface_quad.gd")
const Stage2ItemStateScript = preload("res://core/models/stage2_item_state.gd")
const Stage2PatchStateScript = preload("res://core/models/stage2_patch_state.gd")
const Stage2ShellQuadStateScript = preload("res://core/models/stage2_shell_quad_state.gd")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var canonical_solid_resolver = CraftedItemCanonicalSolidResolverScript.new()
var canonical_geometry_resolver = CraftedItemCanonicalGeometryResolverScript.new()

func _init(rules: ForgeRulesDef = null) -> void:
	set_forge_rules(rules)

func set_forge_rules(rules: ForgeRulesDef) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE

func ensure_stage2_item_state_for_wip(wip: CraftedItemWIP):
	if wip == null:
		return null
	var canonical_solid = canonical_solid_resolver.call("resolve_from_cells", CraftedItemWIP.collect_bake_cells(wip))
	var canonical_geometry = canonical_geometry_resolver.call("resolve_from_solid", canonical_solid)
	var stage2_item_state = build_stage2_item_state_from_stage1(
		wip,
		canonical_solid,
		canonical_geometry,
		wip.latest_baked_profile_snapshot
	)
	wip.stage2_item_state = stage2_item_state
	return stage2_item_state

func build_stage2_item_state_from_stage1(
	wip: CraftedItemWIP,
	canonical_solid,
	canonical_geometry,
	baked_profile_snapshot = null
) :
	var stage2_item_state = Stage2ItemStateScript.new()
	stage2_item_state.source_wip_id = wip.wip_id if wip != null else StringName()
	stage2_item_state.source_stage1_cell_count = (
		canonical_solid.get_cell_count()
		if canonical_solid != null and not canonical_solid.is_empty()
		else CraftedItemWIP.collect_bake_cells(wip).size()
	)
	stage2_item_state.cell_world_size_meters = forge_rules.cell_world_size_meters
	if canonical_geometry != null:
		stage2_item_state.baseline_local_aabb_position = canonical_geometry.local_aabb.position
		stage2_item_state.baseline_local_aabb_size = canonical_geometry.local_aabb.size
		stage2_item_state.current_local_aabb_position = canonical_geometry.local_aabb.position
		stage2_item_state.current_local_aabb_size = canonical_geometry.local_aabb.size
	if canonical_geometry == null or canonical_geometry.surface_quads.is_empty():
		return stage2_item_state
	var patch_states: Array[Resource] = []
	var patch_index: int = 0
	for surface_quad in canonical_geometry.surface_quads:
		if surface_quad == null:
			continue
		var surface_quad_patch_states: Array[Resource] = _build_patch_states_from_surface_quad(
			canonical_solid,
			surface_quad,
			patch_index,
			baked_profile_snapshot
		)
		for patch_state: Resource in surface_quad_patch_states:
			patch_states.append(patch_state)
			patch_index += 1
	_populate_patch_neighbor_ids(patch_states)
	stage2_item_state.patch_states = patch_states
	stage2_item_state.refinement_initialized = not patch_states.is_empty()
	stage2_item_state.dirty = false
	return stage2_item_state

func _build_patch_states_from_surface_quad(
	canonical_solid,
	surface_quad,
	patch_index_start: int,
	baked_profile_snapshot = null
) -> Array[Resource]:
	var patch_states: Array[Resource] = []
	if surface_quad == null:
		return patch_states
	var width_steps: int = maxi(surface_quad.width_voxels, 1)
	var height_steps: int = maxi(surface_quad.height_voxels, 1)
	var edge_u_step: Vector3 = surface_quad.edge_u_local / float(width_steps)
	var edge_v_step: Vector3 = surface_quad.edge_v_local / float(height_steps)
	var local_patch_index: int = patch_index_start
	for v_index: int in range(height_steps):
		for u_index: int in range(width_steps):
			var patch_surface_quad = _build_surface_quad_patch(
				surface_quad,
				edge_u_step,
				edge_v_step,
				u_index,
				v_index
			)
			patch_states.append(_build_patch_state_from_surface_quad(
				canonical_solid,
				patch_surface_quad,
				local_patch_index,
				baked_profile_snapshot
			))
			local_patch_index += 1
	return patch_states

func _build_patch_state_from_surface_quad(
	canonical_solid,
	surface_quad,
	patch_index: int,
	baked_profile_snapshot = null
):
	var patch_state = Stage2PatchStateScript.new()
	patch_state.patch_id = _build_patch_id(surface_quad, patch_index)
	patch_state.baseline_quad = _build_stage2_shell_quad_state(surface_quad)
	patch_state.current_quad = _build_stage2_shell_quad_state(surface_quad)
	patch_state.min_surface_depth_voxels = _resolve_min_surface_depth_voxels(canonical_solid, surface_quad)
	patch_state.max_inward_offset_ratio = _resolve_max_inward_offset_ratio(patch_state.min_surface_depth_voxels)
	patch_state.max_inward_offset_meters = (
		patch_state.max_inward_offset_ratio
		* float(maxi(patch_state.min_surface_depth_voxels, 1))
		* forge_rules.cell_world_size_meters
	)
	patch_state.max_fillet_offset_meters = (
		patch_state.max_inward_offset_meters
		* clampf(forge_rules.stage2_fillet_max_inward_ratio, 0.0, 1.0)
	)
	patch_state.max_chamfer_offset_meters = (
		patch_state.max_inward_offset_meters
		* clampf(forge_rules.stage2_chamfer_max_inward_ratio, 0.0, 1.0)
	)
	patch_state.zone_mask_id = _resolve_patch_zone_mask_id(patch_state, baked_profile_snapshot)
	patch_state.neighbor_patch_ids = PackedStringArray()
	return patch_state

func _populate_patch_neighbor_ids(patch_states: Array[Resource]) -> void:
	var patch_lookup: Dictionary = {}
	var edge_key_to_patch_ids: Dictionary = {}
	for patch_state: Resource in patch_states:
		if patch_state == null:
			continue
		patch_state.neighbor_patch_ids = PackedStringArray()
		if patch_state.current_quad == null:
			continue
		patch_lookup[patch_state.patch_id] = patch_state
		for edge_key: String in _build_coplanar_edge_keys(patch_state.current_quad):
			var patch_id_list: PackedStringArray = edge_key_to_patch_ids.get(edge_key, PackedStringArray())
			patch_id_list.append(String(patch_state.patch_id))
			edge_key_to_patch_ids[edge_key] = patch_id_list
	for patch_id_list: PackedStringArray in edge_key_to_patch_ids.values():
		if patch_id_list.size() < 2:
			continue
		for patch_index: int in range(patch_id_list.size()):
			var patch_state: Resource = patch_lookup.get(StringName(patch_id_list[patch_index]), null)
			if patch_state == null:
				continue
			for candidate_index: int in range(patch_index + 1, patch_id_list.size()):
				var candidate_patch_state: Resource = patch_lookup.get(StringName(patch_id_list[candidate_index]), null)
				if candidate_patch_state == null:
					continue
				_append_neighbor_patch_id(patch_state, candidate_patch_state.patch_id)
				_append_neighbor_patch_id(candidate_patch_state, patch_state.patch_id)

func _build_surface_quad_patch(
	surface_quad,
	edge_u_step: Vector3,
	edge_v_step: Vector3,
	u_index: int,
	v_index: int
):
	var patch_surface_quad = CraftedItemCanonicalSurfaceQuadScript.new()
	patch_surface_quad.origin_local = (
		surface_quad.origin_local
		+ (edge_u_step * float(u_index))
		+ (edge_v_step * float(v_index))
	)
	patch_surface_quad.edge_u_local = edge_u_step
	patch_surface_quad.edge_v_local = edge_v_step
	patch_surface_quad.normal = surface_quad.normal
	patch_surface_quad.material_variant_id = surface_quad.material_variant_id
	patch_surface_quad.width_voxels = 1
	patch_surface_quad.height_voxels = 1
	return patch_surface_quad

func _build_patch_id(surface_quad, patch_index: int) -> StringName:
	if surface_quad == null:
		return StringName("stage2_patch_%d" % patch_index)
	return StringName("stage2_patch_%d_%d_%d_%d" % [
		patch_index,
		int(round(surface_quad.origin_local.x * 1000.0)),
		int(round(surface_quad.origin_local.y * 1000.0)),
		int(round(surface_quad.origin_local.z * 1000.0))
	])

func _resolve_max_inward_offset_ratio(min_surface_depth_voxels: int) -> float:
	if min_surface_depth_voxels >= 2:
		return forge_rules.stage2_multi_cell_max_inward_ratio
	return forge_rules.stage2_single_cell_max_inward_ratio

func _resolve_patch_zone_mask_id(patch_state: Resource, baked_profile_snapshot) -> StringName:
	if patch_state == null or patch_state.baseline_quad == null:
		return Stage2PatchStateScript.ZONE_GENERAL
	if baked_profile_snapshot == null or not bool(baked_profile_snapshot.primary_grip_valid):
		return Stage2PatchStateScript.ZONE_GENERAL
	var safe_radius_voxels: float = maxf(forge_rules.stage2_primary_grip_safe_radius_voxels, 0.0)
	if safe_radius_voxels <= 0.0:
		return Stage2PatchStateScript.ZONE_GENERAL
	var patch_center_local: Vector3 = _get_quad_center_local(patch_state.baseline_quad)
	var grip_distance_voxels: float = _distance_point_to_segment(
		patch_center_local,
		baked_profile_snapshot.primary_grip_span_start,
		baked_profile_snapshot.primary_grip_span_end
	)
	if grip_distance_voxels <= safe_radius_voxels:
		return Stage2PatchStateScript.ZONE_PRIMARY_GRIP_SAFE
	return Stage2PatchStateScript.ZONE_GENERAL

func _resolve_min_surface_depth_voxels(canonical_solid, surface_quad) -> int:
	if canonical_solid == null or canonical_solid.is_empty() or surface_quad == null:
		return 0
	var normal_axis_index: int = _resolve_axis_index_from_vector(surface_quad.normal)
	if normal_axis_index == -1:
		return 0
	var tangent_axes: Array[int] = _resolve_tangent_axes_from_quad(surface_quad, normal_axis_index)
	if tangent_axes.size() != 2:
		return 0
	var covered_cells: Array[Vector3i] = _resolve_surface_quad_cells(surface_quad, normal_axis_index, tangent_axes)
	if covered_cells.is_empty():
		return 0
	var inward_step: Vector3i = Vector3i.ZERO
	match normal_axis_index:
		0:
			inward_step = Vector3i(-1 if surface_quad.normal.x > 0.0 else 1, 0, 0)
		1:
			inward_step = Vector3i(0, -1 if surface_quad.normal.y > 0.0 else 1, 0)
		2:
			inward_step = Vector3i(0, 0, -1 if surface_quad.normal.z > 0.0 else 1)
	var min_depth: int = 0
	for grid_position: Vector3i in covered_cells:
		var local_depth: int = _count_contiguous_depth(canonical_solid, grid_position, inward_step)
		if min_depth == 0 or local_depth < min_depth:
			min_depth = local_depth
	return min_depth

func _resolve_surface_quad_cells(surface_quad, normal_axis_index: int, tangent_axes: Array[int]) -> Array[Vector3i]:
	var covered_cells: Array[Vector3i] = []
	var boundary_coords: Array[int] = [
		int(round(surface_quad.origin_local.x * 2.0)),
		int(round(surface_quad.origin_local.y * 2.0)),
		int(round(surface_quad.origin_local.z * 2.0))
	]
	var edge_u_steps: Array[int] = [
		int(round(surface_quad.edge_u_local.x)),
		int(round(surface_quad.edge_u_local.y)),
		int(round(surface_quad.edge_u_local.z))
	]
	var edge_v_steps: Array[int] = [
		int(round(surface_quad.edge_v_local.x)),
		int(round(surface_quad.edge_v_local.y)),
		int(round(surface_quad.edge_v_local.z))
	]
	var grid_origin: Array[int] = [0, 0, 0]
	for axis_index: int in range(3):
		if axis_index == normal_axis_index:
			var normal_sign: int = _resolve_normal_sign(surface_quad.normal, normal_axis_index)
			grid_origin[axis_index] = int(round((float(boundary_coords[axis_index]) - float(normal_sign)) / 2.0))
			continue
		grid_origin[axis_index] = int(round((float(boundary_coords[axis_index]) + 1.0) / 2.0))
	var axis_u: int = tangent_axes[0]
	var axis_v: int = tangent_axes[1]
	var width: int = maxi(abs(edge_u_steps[axis_u]), abs(edge_v_steps[axis_u]))
	var height: int = maxi(abs(edge_u_steps[axis_v]), abs(edge_v_steps[axis_v]))
	width = maxi(width, surface_quad.width_voxels)
	height = maxi(height, surface_quad.height_voxels)
	for v_index: int in range(maxi(height, 1)):
		for u_index: int in range(maxi(width, 1)):
			var cell_coords: Array[int] = [
				grid_origin[0],
				grid_origin[1],
				grid_origin[2]
			]
			cell_coords[axis_u] += u_index
			cell_coords[axis_v] += v_index
			covered_cells.append(Vector3i(cell_coords[0], cell_coords[1], cell_coords[2]))
	return covered_cells

func _count_contiguous_depth(canonical_solid, start_position: Vector3i, inward_step: Vector3i) -> int:
	var depth: int = 0
	var current_position: Vector3i = start_position
	while canonical_solid.get_cell(current_position) != null:
		depth += 1
		current_position += inward_step
	return depth

func _resolve_axis_index_from_vector(axis_vector: Vector3) -> int:
	if not is_zero_approx(axis_vector.x):
		return 0
	if not is_zero_approx(axis_vector.y):
		return 1
	if not is_zero_approx(axis_vector.z):
		return 2
	return -1

func _resolve_tangent_axes_from_quad(surface_quad, normal_axis_index: int) -> Array[int]:
	var tangent_axes: Array[int] = []
	for axis_index: int in range(3):
		if axis_index == normal_axis_index:
			continue
		var edge_u_component: float = _get_axis_component(surface_quad.edge_u_local, axis_index)
		var edge_v_component: float = _get_axis_component(surface_quad.edge_v_local, axis_index)
		if not is_zero_approx(edge_u_component) or not is_zero_approx(edge_v_component):
			tangent_axes.append(axis_index)
	if tangent_axes.size() == 2:
		return tangent_axes
	for axis_index: int in range(3):
		if axis_index == normal_axis_index or tangent_axes.has(axis_index):
			continue
		tangent_axes.append(axis_index)
		if tangent_axes.size() == 2:
			break
	return tangent_axes

func _resolve_normal_sign(normal: Vector3, axis_index: int) -> int:
	match axis_index:
		0:
			return 1 if normal.x >= 0.0 else -1
		1:
			return 1 if normal.y >= 0.0 else -1
		_:
			return 1 if normal.z >= 0.0 else -1

func _get_quad_center_local(quad_state: Resource) -> Vector3:
	return quad_state.origin_local + (quad_state.edge_u_local * 0.5) + (quad_state.edge_v_local * 0.5)

func _distance_point_to_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
	var segment_vector: Vector3 = segment_end - segment_start
	var segment_length_squared: float = segment_vector.length_squared()
	if segment_length_squared <= 0.00001:
		return point.distance_to(segment_start)
	var ratio: float = clampf((point - segment_start).dot(segment_vector) / segment_length_squared, 0.0, 1.0)
	var closest_point: Vector3 = segment_start + (segment_vector * ratio)
	return point.distance_to(closest_point)

func _patches_share_coplanar_boundary_edge(patch_state: Resource, candidate_patch_state: Resource) -> bool:
	if patch_state == null or candidate_patch_state == null:
		return false
	if patch_state.current_quad == null or candidate_patch_state.current_quad == null:
		return false
	if not _quads_share_plane_and_normal(patch_state.current_quad, candidate_patch_state.current_quad):
		return false
	for edge_id: StringName in [&"edge_u_min", &"edge_u_max", &"edge_v_min", &"edge_v_max"]:
		var patch_edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
		for candidate_edge_id: StringName in [&"edge_u_min", &"edge_u_max", &"edge_v_min", &"edge_v_max"]:
			var candidate_edge_segment: Dictionary = _build_edge_segment(candidate_patch_state.current_quad, candidate_edge_id)
			if _segments_match(patch_edge_segment, candidate_edge_segment):
				return true
	return false

func _build_coplanar_edge_keys(quad_state: Resource) -> PackedStringArray:
	var edge_keys: PackedStringArray = PackedStringArray()
	if quad_state == null:
		return edge_keys
	var plane_key: String = _build_quad_plane_key(quad_state)
	for edge_id: StringName in [&"edge_u_min", &"edge_u_max", &"edge_v_min", &"edge_v_max"]:
		var edge_segment: Dictionary = _build_edge_segment(quad_state, edge_id)
		edge_keys.append("%s|%s" % [plane_key, _build_segment_key(edge_segment)])
	return edge_keys

func _build_quad_plane_key(quad_state: Resource) -> String:
	var normal: Vector3 = quad_state.normal.normalized()
	return "%s|%d" % [
		_format_vector_key(normal),
		int(round(normal.dot(quad_state.origin_local) * 1000.0))
	]

func _build_segment_key(segment: Dictionary) -> String:
	var start_key: String = _format_vector_key(segment.get("start", Vector3.ZERO))
	var end_key: String = _format_vector_key(segment.get("end", Vector3.ZERO))
	if start_key > end_key:
		var swap_key: String = start_key
		start_key = end_key
		end_key = swap_key
	return "%s|%s" % [start_key, end_key]

func _format_vector_key(value: Vector3) -> String:
	return "%d_%d_%d" % [
		int(round(value.x * 1000.0)),
		int(round(value.y * 1000.0)),
		int(round(value.z * 1000.0))
	]

func _append_neighbor_patch_id(patch_state: Resource, neighbor_patch_id: StringName) -> void:
	if patch_state == null or neighbor_patch_id == StringName() or patch_state.patch_id == neighbor_patch_id:
		return
	if patch_state.neighbor_patch_ids.has(String(neighbor_patch_id)):
		return
	var patch_neighbors: PackedStringArray = PackedStringArray(patch_state.neighbor_patch_ids)
	patch_neighbors.append(String(neighbor_patch_id))
	patch_state.neighbor_patch_ids = patch_neighbors

func _quads_share_plane_and_normal(quad_a: Resource, quad_b: Resource) -> bool:
	if quad_a == null or quad_b == null:
		return false
	var normal_a: Vector3 = quad_a.normal.normalized()
	var normal_b: Vector3 = quad_b.normal.normalized()
	if not normal_a.is_equal_approx(normal_b):
		return false
	return is_equal_approx(normal_a.dot(quad_a.origin_local), normal_b.dot(quad_b.origin_local))

func _build_edge_segment(quad_state: Resource, edge_id: StringName) -> Dictionary:
	var origin_local: Vector3 = quad_state.origin_local
	var edge_u_local: Vector3 = quad_state.edge_u_local
	var edge_v_local: Vector3 = quad_state.edge_v_local
	match edge_id:
		&"edge_u_min":
			return {
				"start": origin_local,
				"end": origin_local + edge_v_local,
			}
		&"edge_u_max":
			return {
				"start": origin_local + edge_u_local,
				"end": origin_local + edge_u_local + edge_v_local,
			}
		&"edge_v_min":
			return {
				"start": origin_local,
				"end": origin_local + edge_u_local,
			}
		&"edge_v_max":
			return {
				"start": origin_local + edge_v_local,
				"end": origin_local + edge_u_local + edge_v_local,
			}
		_:
			return {
				"start": origin_local,
				"end": origin_local,
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

func _get_axis_component(value: Vector3, axis_index: int) -> float:
	match axis_index:
		0:
			return value.x
		1:
			return value.y
		_:
			return value.z

func _build_stage2_shell_quad_state(surface_quad):
	var quad_state = Stage2ShellQuadStateScript.new()
	if surface_quad == null:
		return quad_state
	quad_state.origin_local = surface_quad.origin_local
	quad_state.edge_u_local = surface_quad.edge_u_local
	quad_state.edge_v_local = surface_quad.edge_v_local
	quad_state.normal = surface_quad.normal
	quad_state.material_variant_id = surface_quad.material_variant_id
	quad_state.width_voxels = surface_quad.width_voxels
	quad_state.height_voxels = surface_quad.height_voxels
	return quad_state
