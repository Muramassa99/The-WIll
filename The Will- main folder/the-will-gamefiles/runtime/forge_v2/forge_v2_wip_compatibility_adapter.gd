extends RefCounted
class_name ForgeV2WipCompatibilityAdapter

const Stage2EditableMeshStateScript = preload(
	"res://core/models/stage2_editable_mesh_state.gd"
)
const Stage2ItemStateScript = preload("res://core/models/stage2_item_state.gd")
const BakedProfileScript = preload("res://core/models/baked_profile.gd")
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2SplinePathSamplerScript = preload(
	"res://runtime/forge_v2/forge_v2_spline_path_sampler.gd"
)
const PrimaryGripSeatResolverScript = preload(
	"res://core/resolvers/primary_grip_seat_resolver.gd"
)
const PrimaryGripHandleMeshPacketScript = preload(
	"res://core/resolvers/primary_grip_handle_mesh_packet.gd"
)

const DEFAULT_MATERIAL_CATALOG: Resource = preload(
	"res://core/defs/forge/forge_material_catalog_default.tres"
)

const HANDLE_MIN_SPAN_METERS := 0.25
const HANDLE_REQUIRED_POINT_COUNT := 3
const TWO_HAND_MIN_SPAN_CELLS := 26
const CENTER_BALANCE_TOLERANCE_RATIO := 0.07
const TWO_HAND_MAX_SPAN_USAGE_RATIO := 0.80
const MAX_PROFILE_OFFSET_SAMPLES := 256
const GEOMETRY_EPSILON := 0.000001
const VOLUME_EPSILON := 0.000000000001
const GRIP_AUTHORITY_SOURCE := &"forge_v2_handle_body_kind"
const HANDLE_GRIP_CURVE_BAKE_INTERVAL_METERS := 0.001
# Handle bodies still use CSGPolygon3D's legacy path sweep. Its final profile
# mapping mirrors authored X while preserving authored Y. Keep this conversion
# at the V2 compatibility boundary so legacy grip consumers receive collision
# samples in the same space as the authoritative visible mesh.
const HANDLE_FINAL_PROFILE_AXIS_X_SIGN := -1.0


static func build_runtime_contract(
	wip: CraftedItemWIP,
	final_mesh_packet: Dictionary,
	cell_size_meters: float = 0.0125
) -> Dictionary:
	var resolved_cell_size := maxf(cell_size_meters, 0.0001)
	var profile: BakedProfile = BakedProfileScript.new()
	profile.profile_id = _build_profile_id(wip)
	if final_mesh_packet.has("ok") and not bool(final_mesh_packet.get(
		"ok",
		false
	)):
		var provider_error := String(final_mesh_packet.get(
			"error_code",
			"forge_v2_runtime_mesh_provider_failed"
		))
		var provider_reason := String(final_mesh_packet.get("reason", ""))
		return _build_invalid_result(
			profile,
			null,
			provider_error if provider_reason.is_empty() else "%s:%s" % [
				provider_error,
				provider_reason,
			]
		)

	var mesh_validation := _validate_mesh_packet(final_mesh_packet)
	if not bool(mesh_validation.get("valid", false)):
		return _build_invalid_result(
			profile,
			null,
			String(mesh_validation.get("error", "forge_v2_runtime_mesh_invalid"))
		)

	var vertices_meters: PackedVector3Array = mesh_validation.get(
		"vertices",
		PackedVector3Array()
	)
	var indices: PackedInt32Array = mesh_validation.get(
		"indices",
		PackedInt32Array()
	)
	var protected_handle_mesh_validation := (
		PrimaryGripHandleMeshPacketScript.validate(final_mesh_packet)
	)
	var protected_handle_vertices_meters := PackedVector3Array()
	var protected_handle_indices := PackedInt32Array()
	var protected_handle_mesh_source := StringName()
	var protected_handle_body_signature := ""
	var protected_handle_mesh_origin_id := StringName()
	if bool(protected_handle_mesh_validation.get("valid", false)):
		protected_handle_vertices_meters = (
			protected_handle_mesh_validation.get(
				"vertices",
				PackedVector3Array()
			) as PackedVector3Array
		)
		protected_handle_indices = protected_handle_mesh_validation.get(
			"indices",
			PackedInt32Array()
		) as PackedInt32Array
		protected_handle_mesh_source = StringName(
			protected_handle_mesh_validation.get("source", StringName())
		)
		protected_handle_body_signature = String(
			protected_handle_mesh_validation.get("body_signature", "")
		)
		protected_handle_mesh_origin_id = StringName(
			protected_handle_mesh_validation.get(
				"vertices_origin_id",
				StringName()
			)
		)
	else:
		protected_handle_vertices_meters = PackedVector3Array()
		protected_handle_indices = PackedInt32Array()
	var mesh_metrics := _calculate_mesh_metrics(vertices_meters, indices)
	var stage2_item_state: Resource = _build_stage2_item_state(
		wip,
		vertices_meters,
		indices,
		mesh_metrics,
		resolved_cell_size,
		protected_handle_vertices_meters,
		protected_handle_indices,
		protected_handle_mesh_source,
		protected_handle_body_signature,
		protected_handle_mesh_origin_id
	)
	_populate_profile_mesh_metrics(profile, mesh_metrics, resolved_cell_size)
	var mesh_component_count := _count_indexed_triangle_components(
		vertices_meters,
		indices
	)
	if mesh_component_count != 1:
		return _build_invalid_result(
			profile,
			stage2_item_state,
			"forge_v2_runtime_mesh_disconnected_component_count_%d"
			% mesh_component_count
		)

	if wip == null:
		return _build_invalid_result(
			profile,
			stage2_item_state,
			"forge_v2_runtime_wip_missing"
		)
	var authoring_state: Resource = wip.forge_v2_authoring_state
	if authoring_state == null:
		return _build_invalid_result(
			profile,
			stage2_item_state,
			"forge_v2_authoring_state_missing"
		)

	var handle_validation := _resolve_valid_handle_body(authoring_state)
	var handle_body: Resource = handle_validation.get("body", null) as Resource
	if handle_body != null:
		profile.set("primary_grip_authority_source", GRIP_AUTHORITY_SOURCE)
		profile.set(
			"primary_grip_source_body_id",
			StringName(handle_body.get("body_id"))
		)
	if not bool(handle_validation.get("valid", false)):
		_populate_profile_material_usage(
			profile,
			authoring_state,
			handle_body,
			float(mesh_metrics.get("volume_m3", 0.0)),
			resolved_cell_size
		)
		return _build_invalid_result(
			profile,
			stage2_item_state,
			String(handle_validation.get("error", "forge_v2_handle_invalid"))
		)
	if not bool(protected_handle_mesh_validation.get("valid", false)):
		return _build_invalid_result(
			profile,
			stage2_item_state,
			"forge_v2_primary_handle_exact_mesh_missing"
		)
	var expected_handle_body_signature := (
		PrimaryGripHandleMeshPacketScript.build_body_signature(handle_body)
	)
	if (
		protected_handle_body_signature.is_empty()
		or protected_handle_body_signature != expected_handle_body_signature
	):
		return _build_invalid_result(
			profile,
			stage2_item_state,
			"forge_v2_primary_handle_exact_mesh_signature_mismatch"
		)

	var handle_path: PackedVector3Array = handle_validation.get(
		"path_points",
		PackedVector3Array()
	)
	var handle_polygon: PackedVector2Array = handle_validation.get(
		"profile_polygon",
		PackedVector2Array()
	)
	var handle_axis: Vector3 = handle_validation.get("axis", Vector3.RIGHT)
	var profile_offsets := _build_profile_offset_samples(
		handle_polygon,
		resolved_cell_size
	)
	profile_offsets = _map_handle_profile_samples_to_final_csg(profile_offsets)
	var grip_geometry := _resolve_handle_grip_geometry(
		handle_body,
		handle_path,
		profile_offsets,
		mesh_metrics.get("centroid_meters", Vector3.ZERO) as Vector3,
		vertices_meters,
		protected_handle_vertices_meters,
		protected_handle_indices
	)
	var slice_axis_ratios: PackedFloat32Array = grip_geometry.get(
		"slice_axis_ratios",
		PackedFloat32Array()
	) as PackedFloat32Array
	var slice_centers_meters: PackedVector3Array = grip_geometry.get(
		"slice_centers_meters",
		PackedVector3Array()
	) as PackedVector3Array
	if not PrimaryGripSeatResolverScript.sampled_path_is_valid(
		slice_axis_ratios,
		slice_centers_meters
	):
		return _build_invalid_result(
			profile,
			stage2_item_state,
			"forge_v2_primary_handle_slice_center_path_invalid"
		)
	handle_path = grip_geometry.get(
		"profile_path",
		handle_path
	) as PackedVector3Array
	handle_axis = grip_geometry.get("major_axis", handle_axis) as Vector3
	var minor_axis_a: Vector3 = grip_geometry.get("minor_axis_a", Vector3.UP)
	var minor_axis_b: Vector3 = grip_geometry.get(
		"minor_axis_b",
		Vector3.FORWARD
	)
	profile_offsets = grip_geometry.get(
		"centered_offsets",
		profile_offsets
	) as PackedVector2Array

	_populate_profile_material_usage(
		profile,
		authoring_state,
		handle_body,
		float(mesh_metrics.get("volume_m3", 0.0)),
		resolved_cell_size
	)
	_populate_primary_grip_profile(
		profile,
		wip,
		handle_body,
		handle_path,
		handle_axis,
		minor_axis_a,
		minor_axis_b,
		profile_offsets,
		vertices_meters,
		mesh_metrics,
		resolved_cell_size,
		float(grip_geometry.get("contact_ratio", 0.5)),
		float(grip_geometry.get("span_length_meters", -1.0)),
		slice_axis_ratios,
		slice_centers_meters
	)
	return {
		"stage2_item_state": stage2_item_state,
		"baked_profile": profile,
		"valid": true,
		"error": "",
	}


static func _validate_mesh_packet(mesh_packet: Dictionary) -> Dictionary:
	var vertices_variant: Variant = mesh_packet.get("vertices", null)
	if vertices_variant is not PackedVector3Array:
		return {
			"valid": false,
			"error": "forge_v2_runtime_mesh_vertices_missing",
		}
	var vertices: PackedVector3Array = vertices_variant as PackedVector3Array
	if vertices.size() < 3:
		return {
			"valid": false,
			"error": "forge_v2_runtime_mesh_requires_three_vertices",
		}
	for vertex: Vector3 in vertices:
		if not _vector3_is_finite(vertex):
			return {
				"valid": false,
				"error": "forge_v2_runtime_mesh_vertex_not_finite",
			}

	var indices_variant: Variant = mesh_packet.get("indices", null)
	if indices_variant is not PackedInt32Array:
		return {
			"valid": false,
			"error": "forge_v2_runtime_mesh_indices_missing",
		}
	var indices: PackedInt32Array = indices_variant as PackedInt32Array
	if indices.size() < 3 or indices.size() % 3 != 0:
		return {
			"valid": false,
			"error": "forge_v2_runtime_mesh_indices_not_triangles",
		}
	var nondegenerate_triangle_count := 0
	for index_offset in range(0, indices.size(), 3):
		var index_a := indices[index_offset]
		var index_b := indices[index_offset + 1]
		var index_c := indices[index_offset + 2]
		if (
			index_a < 0
			or index_b < 0
			or index_c < 0
			or index_a >= vertices.size()
			or index_b >= vertices.size()
			or index_c >= vertices.size()
		):
			return {
				"valid": false,
				"error": "forge_v2_runtime_mesh_index_out_of_range",
			}
		var face_cross := (vertices[index_b] - vertices[index_a]).cross(
			vertices[index_c] - vertices[index_a]
		)
		if face_cross.length_squared() > GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			nondegenerate_triangle_count += 1
	if nondegenerate_triangle_count <= 0:
		return {
			"valid": false,
			"error": "forge_v2_runtime_mesh_all_triangles_degenerate",
		}
	return {
		"valid": true,
		"error": "",
		"vertices": vertices,
		"indices": indices,
	}


static func _count_indexed_triangle_components(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> int:
	var welded_indices_by_bucket: Dictionary = {}
	var welded_index_by_source_index: Dictionary = {}
	for source_vertex_index: int in indices:
		if welded_index_by_source_index.has(source_vertex_index):
			continue
		var source_vertex := vertices[source_vertex_index]
		var weld_bucket := Vector3i(
			floori(source_vertex.x / GEOMETRY_EPSILON),
			floori(source_vertex.y / GEOMETRY_EPSILON),
			floori(source_vertex.z / GEOMETRY_EPSILON)
		)
		var welded_index := _find_nearby_welded_vertex_index(
			vertices,
			welded_indices_by_bucket,
			weld_bucket,
			source_vertex
		)
		if welded_index < 0:
			welded_index = source_vertex_index
			var bucket_indices: Array = welded_indices_by_bucket.get(
				weld_bucket,
				[]
			) as Array
			bucket_indices.append(welded_index)
			welded_indices_by_bucket[weld_bucket] = bucket_indices
		welded_index_by_source_index[source_vertex_index] = welded_index
	var parent_by_vertex: Dictionary = {}
	for welded_index_variant: Variant in welded_index_by_source_index.values():
		var welded_index := int(welded_index_variant)
		parent_by_vertex[welded_index] = welded_index
	for index_offset in range(0, indices.size(), 3):
		var welded_a := int(welded_index_by_source_index[
			indices[index_offset]
		])
		var welded_b := int(welded_index_by_source_index[
			indices[index_offset + 1]
		])
		var welded_c := int(welded_index_by_source_index[
			indices[index_offset + 2]
		])
		_union_indexed_vertices(
			parent_by_vertex,
			welded_a,
			welded_b
		)
		_union_indexed_vertices(
			parent_by_vertex,
			welded_a,
			welded_c
		)
	var component_roots: Dictionary = {}
	for vertex_index_variant: Variant in parent_by_vertex.keys():
		var vertex_index := int(vertex_index_variant)
		component_roots[_find_indexed_vertex_root(
			parent_by_vertex,
			vertex_index
		)] = true
	return component_roots.size()


static func _find_nearby_welded_vertex_index(
	vertices: PackedVector3Array,
	welded_indices_by_bucket: Dictionary,
	weld_bucket: Vector3i,
	source_vertex: Vector3
) -> int:
	var weld_distance_squared := GEOMETRY_EPSILON * GEOMETRY_EPSILON
	for bucket_x_offset in range(-1, 2):
		for bucket_y_offset in range(-1, 2):
			for bucket_z_offset in range(-1, 2):
				var nearby_bucket := weld_bucket + Vector3i(
					bucket_x_offset,
					bucket_y_offset,
					bucket_z_offset
				)
				var candidate_indices: Array = welded_indices_by_bucket.get(
					nearby_bucket,
					[]
				) as Array
				for candidate_index_variant: Variant in candidate_indices:
					var candidate_index := int(candidate_index_variant)
					if source_vertex.distance_squared_to(
						vertices[candidate_index]
					) <= weld_distance_squared:
						return candidate_index
	return -1


static func _union_indexed_vertices(
	parent_by_vertex: Dictionary,
	vertex_a: int,
	vertex_b: int
) -> void:
	var root_a := _find_indexed_vertex_root(parent_by_vertex, vertex_a)
	var root_b := _find_indexed_vertex_root(parent_by_vertex, vertex_b)
	if root_a != root_b:
		parent_by_vertex[root_b] = root_a


static func _find_indexed_vertex_root(
	parent_by_vertex: Dictionary,
	vertex_index: int
) -> int:
	var root := vertex_index
	while int(parent_by_vertex.get(root, root)) != root:
		root = int(parent_by_vertex.get(root, root))
	var current := vertex_index
	while int(parent_by_vertex.get(current, current)) != root:
		var next := int(parent_by_vertex.get(current, current))
		parent_by_vertex[current] = root
		current = next
	return root


static func _resolve_valid_handle_body(authoring_state: Resource) -> Dictionary:
	var active_handles: Array[Resource] = []
	var body_variants: Array = authoring_state.get("material_bodies") as Array
	for body_variant: Variant in body_variants:
		var body: Resource = body_variant as Resource
		if body == null:
			continue
		if StringName(body.get("body_kind")) != (
			ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
		):
			continue
		var layer_active_variant: Variant = body.get("layer_active")
		if layer_active_variant is bool and not bool(layer_active_variant):
			continue
		active_handles.append(body)
	if active_handles.is_empty():
		return {
			"valid": false,
			"error": "forge_v2_primary_handle_missing",
			"body": null,
		}
	if active_handles.size() > 1:
		return {
			"valid": false,
			"error": "forge_v2_multiple_active_primary_handles",
			"body": null,
		}

	var handle_body: Resource = active_handles[0]
	if StringName(handle_body.get("committed_layer_id")) == StringName():
		return {
			"valid": false,
			"error": "forge_v2_primary_handle_not_committed",
			"body": handle_body,
		}
	var path_points: PackedVector3Array = handle_body.get("path_points")
	if path_points.size() != HANDLE_REQUIRED_POINT_COUNT:
		return {
			"valid": false,
			"error": "forge_v2_primary_handle_requires_exactly_three_points",
			"body": handle_body,
		}
	for point: Vector3 in path_points:
		if not _vector3_is_finite(point):
			return {
				"valid": false,
				"error": "forge_v2_primary_handle_point_not_finite",
				"body": handle_body,
			}
	var endpoint_span_meters := path_points[0].distance_to(path_points[2])
	if endpoint_span_meters + GEOMETRY_EPSILON < HANDLE_MIN_SPAN_METERS:
		return {
			"valid": false,
			"error": "forge_v2_primary_handle_span_below_0_25_meters",
			"body": handle_body,
		}
	var profile_polygon: PackedVector2Array = handle_body.get(
		"profile_polygon_2d_meters"
	)
	var polygon_error := _validate_profile_polygon(profile_polygon)
	if not polygon_error.is_empty():
		return {
			"valid": false,
			"error": polygon_error,
			"body": handle_body,
		}
	return {
		"valid": true,
		"error": "",
		"body": handle_body,
		"path_points": path_points,
		"profile_polygon": profile_polygon,
		"axis": (path_points[2] - path_points[0]).normalized(),
	}


static func resolve_valid_handle_body(authoring_state: Resource) -> Dictionary:
	if authoring_state == null:
		return {
			"valid": false,
			"error": "forge_v2_authoring_state_missing",
			"body": null,
		}
	return _resolve_valid_handle_body(authoring_state)


static func _validate_profile_polygon(polygon: PackedVector2Array) -> String:
	if polygon.size() < 3:
		return "forge_v2_primary_handle_profile_requires_three_points"
	for point: Vector2 in polygon:
		if not is_finite(point.x) or not is_finite(point.y):
			return "forge_v2_primary_handle_profile_point_not_finite"
	if absf(_calculate_signed_polygon_area(polygon)) <= VOLUME_EPSILON:
		return "forge_v2_primary_handle_profile_area_is_zero"
	var triangulation := Geometry2D.triangulate_polygon(polygon)
	if triangulation.size() < 3 or triangulation.size() % 3 != 0:
		return "forge_v2_primary_handle_profile_is_not_simple"
	return ""


static func _calculate_mesh_metrics(
	vertices_meters: PackedVector3Array,
	indices: PackedInt32Array
) -> Dictionary:
	var mesh_aabb := AABB(vertices_meters[0], Vector3.ZERO)
	var vertex_sum := Vector3.ZERO
	for vertex: Vector3 in vertices_meters:
		mesh_aabb = mesh_aabb.expand(vertex)
		vertex_sum += vertex
	var vertex_mean := vertex_sum / float(vertices_meters.size())

	var signed_six_volume := 0.0
	var signed_centroid_numerator := Vector3.ZERO
	for index_offset in range(0, indices.size(), 3):
		var vertex_a := vertices_meters[indices[index_offset]]
		var vertex_b := vertices_meters[indices[index_offset + 1]]
		var vertex_c := vertices_meters[indices[index_offset + 2]]
		var triangle_signed_six_volume := vertex_a.dot(vertex_b.cross(vertex_c))
		signed_six_volume += triangle_signed_six_volume
		signed_centroid_numerator += (
			vertex_a + vertex_b + vertex_c
		) * triangle_signed_six_volume

	var volume_m3 := absf(signed_six_volume) / 6.0
	var centroid_meters := vertex_mean
	if absf(signed_six_volume) > VOLUME_EPSILON:
		var tetra_centroid := signed_centroid_numerator / (
			4.0 * signed_six_volume
		)
		if (
			_vector3_is_finite(tetra_centroid)
			and _aabb_contains_with_tolerance(mesh_aabb, tetra_centroid)
		):
			centroid_meters = tetra_centroid
	if volume_m3 <= VOLUME_EPSILON:
		volume_m3 = maxf(
			mesh_aabb.size.x * mesh_aabb.size.y * mesh_aabb.size.z,
			0.0
		)
	if not _vector3_is_finite(centroid_meters):
		centroid_meters = mesh_aabb.get_center()
	return {
		"aabb_meters": mesh_aabb,
		"signed_volume_m3": signed_six_volume / 6.0,
		"volume_m3": volume_m3,
		"centroid_meters": centroid_meters,
	}


static func _build_stage2_item_state(
	wip: CraftedItemWIP,
	vertices_meters: PackedVector3Array,
	indices: PackedInt32Array,
	mesh_metrics: Dictionary,
	cell_size_meters: float,
	protected_handle_vertices_meters: PackedVector3Array = PackedVector3Array(),
	protected_handle_indices: PackedInt32Array = PackedInt32Array(),
	protected_handle_mesh_source: StringName = StringName(),
	protected_handle_body_signature: String = "",
	protected_handle_mesh_origin_id: StringName = StringName()
) -> Resource:
	var vertices_cells := PackedVector3Array()
	for vertex: Vector3 in vertices_meters:
		vertices_cells.append(vertex / cell_size_meters)
	var normals := _build_vertex_normals(vertices_cells, indices)
	var colors := PackedColorArray()
	for _vertex_index in range(vertices_cells.size()):
		colors.append(Color.WHITE)
	var surface_arrays: Array = []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	surface_arrays[Mesh.ARRAY_VERTEX] = vertices_cells
	surface_arrays[Mesh.ARRAY_NORMAL] = normals
	surface_arrays[Mesh.ARRAY_COLOR] = colors
	surface_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)

	var aabb_meters: AABB = mesh_metrics.get("aabb_meters", AABB())
	var aabb_cells := AABB(
		aabb_meters.position / cell_size_meters,
		aabb_meters.size / cell_size_meters
	)
	var baseline_editable: Resource = Stage2EditableMeshStateScript.new()
	baseline_editable.call(
		"copy_from_surface_arrays",
		surface_arrays,
		Mesh.PRIMITIVE_TRIANGLES,
		aabb_cells
	)
	baseline_editable.set("dirty", false)
	var current_editable: Resource = baseline_editable.duplicate(true) as Resource
	current_editable.set("dirty", true)

	var stage2_item_state: Resource = Stage2ItemStateScript.new()
	stage2_item_state.set(
		"source_wip_id",
		wip.wip_id if wip != null else StringName()
	)
	stage2_item_state.set("cell_world_size_meters", cell_size_meters)
	stage2_item_state.set(
		"source_stage1_cell_count",
		maxi(
			int(round(float(mesh_metrics.get("volume_m3", 0.0)) / pow(cell_size_meters, 3.0))),
			0
		)
	)
	stage2_item_state.set("baseline_local_aabb_position", aabb_cells.position)
	stage2_item_state.set("baseline_local_aabb_size", aabb_cells.size)
	stage2_item_state.set("current_local_aabb_position", aabb_cells.position)
	stage2_item_state.set("current_local_aabb_size", aabb_cells.size)
	stage2_item_state.set("baseline_editable_mesh_state", baseline_editable)
	stage2_item_state.set("current_editable_mesh_state", current_editable)
	stage2_item_state.set("editable_mesh_visual_authority", true)
	stage2_item_state.set("refinement_initialized", true)
	stage2_item_state.set("dirty", true)
	stage2_item_state.set("last_active_tool_id", &"forge_v2_finalized_mesh")
	if (
		not protected_handle_vertices_meters.is_empty()
		and not protected_handle_indices.is_empty()
		and protected_handle_indices.size() % 3 == 0
	):
		var protected_vertices_cells := PackedVector3Array()
		protected_vertices_cells.resize(
			protected_handle_vertices_meters.size()
		)
		for vertex_index: int in range(
			protected_handle_vertices_meters.size()
		):
			protected_vertices_cells[vertex_index] = (
				protected_handle_vertices_meters[vertex_index]
				/ cell_size_meters
			)
		var protected_surface_arrays: Array = []
		protected_surface_arrays.resize(Mesh.ARRAY_MAX)
		protected_surface_arrays[Mesh.ARRAY_VERTEX] = (
			protected_vertices_cells
		)
		protected_surface_arrays[Mesh.ARRAY_NORMAL] = _build_vertex_normals(
			protected_vertices_cells,
			protected_handle_indices
		)
		protected_surface_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(
			protected_handle_indices
		)
		var protected_aabb_cells := AABB()
		if not protected_vertices_cells.is_empty():
			protected_aabb_cells = AABB(
				protected_vertices_cells[0],
				Vector3.ZERO
			)
			for vertex: Vector3 in protected_vertices_cells:
				protected_aabb_cells = protected_aabb_cells.expand(vertex)
		var protected_mesh_state: Resource = (
			Stage2EditableMeshStateScript.new()
		)
		protected_mesh_state.call(
			"copy_from_surface_arrays",
			protected_surface_arrays,
			Mesh.PRIMITIVE_TRIANGLES,
			protected_aabb_cells
		)
		protected_mesh_state.set("dirty", false)
		stage2_item_state.set(
			"primary_grip_handle_mesh_state",
			protected_mesh_state
		)
		stage2_item_state.set(
			"primary_grip_handle_mesh_source",
			protected_handle_mesh_source
		)
		stage2_item_state.set(
			"primary_grip_handle_body_signature",
			protected_handle_body_signature
		)
		stage2_item_state.set(
			"primary_grip_handle_mesh_origin_id",
			protected_handle_mesh_origin_id
		)
	return stage2_item_state


static func _build_vertex_normals(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> PackedVector3Array:
	var normals := PackedVector3Array()
	for _vertex_index in range(vertices.size()):
		normals.append(Vector3.ZERO)
	for index_offset in range(0, indices.size(), 3):
		var index_a := indices[index_offset]
		var index_b := indices[index_offset + 1]
		var index_c := indices[index_offset + 2]
		var face_normal := (vertices[index_b] - vertices[index_a]).cross(
			vertices[index_c] - vertices[index_a]
		)
		if face_normal.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			continue
		normals[index_a] += face_normal
		normals[index_b] += face_normal
		normals[index_c] += face_normal
	for vertex_index in range(normals.size()):
		if normals[vertex_index].length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			normals[vertex_index] = Vector3.UP
		else:
			normals[vertex_index] = normals[vertex_index].normalized()
	return normals


static func _populate_profile_mesh_metrics(
	profile: BakedProfile,
	mesh_metrics: Dictionary,
	cell_size_meters: float
) -> void:
	var volume_m3 := maxf(float(mesh_metrics.get("volume_m3", 0.0)), 0.0)
	profile.total_volume_cell_equivalents = volume_m3 / pow(cell_size_meters, 3.0)
	profile.center_of_mass = (
		mesh_metrics.get("centroid_meters", Vector3.ZERO) as Vector3
	) / cell_size_meters


static func _populate_profile_material_usage(
	profile: BakedProfile,
	authoring_state: Resource,
	handle_body: Resource,
	mesh_volume_m3: float,
	cell_size_meters: float
) -> void:
	var usage_summary: Dictionary = {}
	if (
		authoring_state != null
		and authoring_state.has_method("get_material_usage_summary")
	):
		usage_summary = authoring_state.call(
			"get_material_usage_summary"
		) as Dictionary
	var raw_material_volumes: Dictionary = {}
	var raw_total_volume := 0.0
	var material_entries: Dictionary = usage_summary.get("materials", {}) as Dictionary
	for material_key: Variant in material_entries.keys():
		var material_id := StringName(material_key)
		var entry_variant: Variant = material_entries[material_key]
		if material_id == StringName() or entry_variant is not Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var rough_volume := maxf(
			float(entry.get("rough_volume_cell_equivalents", 0.0)),
			0.0
		)
		if rough_volume <= GEOMETRY_EPSILON:
			continue
		raw_material_volumes[material_id] = rough_volume
		raw_total_volume += rough_volume
	var exact_cell_volume := maxf(mesh_volume_m3, 0.0) / pow(cell_size_meters, 3.0)
	if raw_material_volumes.is_empty() and handle_body != null:
		var handle_material_id := StringName(handle_body.get("material_variant_id"))
		if handle_material_id != StringName() and exact_cell_volume > 0.0:
			raw_material_volumes[handle_material_id] = exact_cell_volume
			raw_total_volume = exact_cell_volume

	var material_volume_mix: Dictionary = {}
	var material_variant_mix: Dictionary = {}
	var total_mass := 0.0
	for material_key: Variant in raw_material_volumes.keys():
		var material_id := StringName(material_key)
		var raw_volume := float(raw_material_volumes[material_key])
		var scaled_volume := (
			exact_cell_volume * raw_volume / raw_total_volume
			if raw_total_volume > GEOMETRY_EPSILON
			else raw_volume
		)
		material_volume_mix[material_id] = scaled_volume
		material_variant_mix[material_id] = maxi(int(round(scaled_volume)), 1)
		total_mass += scaled_volume * _resolve_density_per_cell(material_id)
	profile.material_volume_mix = material_volume_mix
	profile.material_variant_mix = material_variant_mix
	profile.total_mass = maxf(total_mass, 0.0)


static func _resolve_handle_profile_frame(
	handle_body: Resource,
	handle_path: PackedVector3Array,
	handle_axis: Vector3,
	point_index: int = 1
) -> Dictionary:
	var resolved_point_index := clampi(
		point_index,
		0,
		maxi(handle_path.size() - 1, 0)
	)
	var tangent := ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
		handle_path,
		resolved_point_index
	)
	if tangent.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		tangent = handle_axis
	var surface_normal := _resolve_profile_frame_fallback_normal(tangent)
	var path_normals: PackedVector3Array = handle_body.get("path_surface_normals")
	if path_normals.size() > resolved_point_index:
		var candidate_normal := path_normals[resolved_point_index]
		if (
			_vector3_is_finite(candidate_normal)
			and candidate_normal.length_squared() > GEOMETRY_EPSILON * GEOMETRY_EPSILON
			and absf(candidate_normal.normalized().dot(tangent.normalized())) < 0.999
		):
			surface_normal = candidate_normal.normalized()
	var contact_direction: Vector2 = handle_body.get("profile_contact_direction_2d")
	if (
		not is_finite(contact_direction.x)
		or not is_finite(contact_direction.y)
		or contact_direction.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON
	):
		contact_direction = ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	var rotation_bias := float(handle_body.get("profile_rotation_bias_degrees"))
	if not is_finite(rotation_bias):
		rotation_bias = 0.0
	var frame: Dictionary = ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
		tangent,
		surface_normal,
		contact_direction,
		rotation_bias
	)
	var axis_x: Vector3 = frame.get("axis_x", Vector3.ZERO)
	var axis_y: Vector3 = frame.get("axis_y", Vector3.ZERO)
	if (
		_vector3_is_finite(axis_x)
		and _vector3_is_finite(axis_y)
		and axis_x.length_squared() > GEOMETRY_EPSILON * GEOMETRY_EPSILON
		and axis_y.length_squared() > GEOMETRY_EPSILON * GEOMETRY_EPSILON
	):
		return frame
	var fallback_axis_a := _resolve_profile_frame_fallback_normal(handle_axis)
	var fallback_axis_b := handle_axis.cross(fallback_axis_a).normalized()
	return {
		"tangent": handle_axis,
		"axis_x": fallback_axis_a,
		"axis_y": fallback_axis_b,
	}


static func _populate_primary_grip_profile(
	profile: BakedProfile,
	wip: CraftedItemWIP,
	handle_body: Resource,
	handle_path_meters: PackedVector3Array,
	handle_axis: Vector3,
	minor_axis_a: Vector3,
	minor_axis_b: Vector3,
	profile_offsets: PackedVector2Array,
	mesh_vertices_meters: PackedVector3Array,
	mesh_metrics: Dictionary,
	cell_size_meters: float,
	resolved_contact_ratio: float = -1.0,
	resolved_span_length_meters: float = -1.0,
	resolved_slice_axis_ratios: PackedFloat32Array = PackedFloat32Array(),
	resolved_slice_centers_meters: PackedVector3Array = PackedVector3Array()
) -> void:
	var span_start_meters := handle_path_meters[0]
	var contact_meters := handle_path_meters[1]
	var span_end_meters := handle_path_meters[2]
	var center_of_mass_meters: Vector3 = mesh_metrics.get(
		"centroid_meters",
		Vector3.ZERO
	)
	var span_start_cells := span_start_meters / cell_size_meters
	var contact_cells := contact_meters / cell_size_meters
	var span_end_cells := span_end_meters / cell_size_meters
	var center_of_mass_cells := center_of_mass_meters / cell_size_meters

	profile.primary_grip_valid = true
	profile.validation_error = ""
	profile.primary_grip_contact_position = contact_cells
	profile.primary_grip_span_start = span_start_cells
	profile.primary_grip_span_end = span_end_cells
	profile.primary_grip_slide_axis = handle_axis
	profile.primary_grip_span_length_voxels = maxi(
		int(round(
			(
				resolved_span_length_meters
				if resolved_span_length_meters > 0.0
				else span_start_meters.distance_to(span_end_meters)
			) / cell_size_meters
		)),
		1
	)
	profile.primary_grip_slice_axis_ratios_from_span_start = PackedFloat32Array(
		resolved_slice_axis_ratios
	)
	var slice_centers_cells := PackedVector3Array()
	slice_centers_cells.resize(resolved_slice_centers_meters.size())
	for sample_index: int in range(resolved_slice_centers_meters.size()):
		slice_centers_cells[sample_index] = (
			resolved_slice_centers_meters[sample_index] / cell_size_meters
		)
	profile.primary_grip_slice_centers = slice_centers_cells
	profile.primary_grip_slice_centers_origin_id = (
		PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID
	)
	profile.primary_grip_offset = center_of_mass_cells - contact_cells
	profile.set("primary_grip_minor_axis_a", minor_axis_a.normalized())
	profile.set("primary_grip_minor_axis_b", minor_axis_b.normalized())
	profile.set(
		"primary_grip_profile_offsets_minor_meters",
		PackedVector2Array(profile_offsets)
	)
	profile.set("primary_grip_authority_source", GRIP_AUTHORITY_SOURCE)
	profile.set(
		"primary_grip_source_body_id",
		StringName(handle_body.get("body_id"))
	)

	var span_vector_meters := span_end_meters - span_start_meters
	var span_length_squared := span_vector_meters.length_squared()
	var contact_ratio := (
		clampf(resolved_contact_ratio, 0.0, 1.0)
		if resolved_contact_ratio >= 0.0
		else clampf(
			(contact_meters - span_start_meters).dot(span_vector_meters)
			/ span_length_squared,
			0.0,
			1.0
		)
	)
	var center_ratio_unclamped := (
		contact_ratio
		if resolved_contact_ratio >= 0.0
		else (
			(center_of_mass_meters - span_start_meters).dot(span_vector_meters)
			/ span_length_squared
		)
	)
	var center_ratio := clampf(center_ratio_unclamped, 0.0, 1.0)
	profile.primary_grip_axis_ratio_from_span_start = contact_ratio
	var span_start_is_com_side := (
		center_of_mass_meters.distance_squared_to(span_start_meters)
		<= center_of_mass_meters.distance_squared_to(span_end_meters)
	)
	profile.primary_grip_com_side_position = (
		span_start_cells if span_start_is_com_side else span_end_cells
	)
	profile.primary_grip_far_side_position = (
		span_end_cells if span_start_is_com_side else span_start_cells
	)
	profile.primary_grip_contact_percent = (
		1.0 - contact_ratio if span_start_is_com_side else contact_ratio
	)
	profile.primary_grip_center_balance_offset_percent = absf(
		center_ratio_unclamped - 0.5
	)
	profile.primary_grip_center_balance_valid = (
		center_ratio_unclamped >= 0.0
		and center_ratio_unclamped <= 1.0
		and profile.primary_grip_center_balance_offset_percent
		<= CENTER_BALANCE_TOLERANCE_RATIO
	)
	if profile.primary_grip_center_balance_valid:
		profile.primary_grip_center_balance_origin = contact_cells

	var two_hand_branch := (
		(
			wip.forge_intent == &"intent_melee"
			and wip.equipment_context == &"ctx_weapon"
		)
		or (
			wip.forge_intent == &"intent_magic"
			and wip.equipment_context == &"ctx_focus"
		)
	)
	profile.primary_grip_two_hand_eligible = (
		two_hand_branch
		and profile.primary_grip_span_length_voxels >= TWO_HAND_MIN_SPAN_CELLS
	)
	if (
		profile.primary_grip_two_hand_eligible
		and profile.primary_grip_center_balance_valid
	):
		profile.primary_grip_two_hand_negative_limit = -minf(
			center_ratio / 0.5,
			TWO_HAND_MAX_SPAN_USAGE_RATIO
		)
		profile.primary_grip_two_hand_positive_limit = minf(
			(1.0 - center_ratio) / 0.5,
			TWO_HAND_MAX_SPAN_USAGE_RATIO
		)

	var extremities := _resolve_weapon_extremities(
		mesh_vertices_meters,
		contact_meters,
		handle_axis
	)
	profile.weapon_tip_point = (
		extremities.get("tip_meters", contact_meters) as Vector3
	) / cell_size_meters
	profile.weapon_pommel_point = (
		extremities.get("pommel_meters", contact_meters) as Vector3
	) / cell_size_meters
	profile.weapon_tip_distance_meters = float(
		extremities.get("tip_distance_meters", 0.0)
	)
	profile.weapon_pommel_distance_meters = float(
		extremities.get("pommel_distance_meters", 0.0)
	)
	profile.weapon_total_length_meters = float(
		extremities.get("total_length_meters", 0.0)
	)

	var reach_meters := 0.0
	for vertex: Vector3 in mesh_vertices_meters:
		reach_meters = maxf(reach_meters, vertex.distance_to(contact_meters))
	profile.reach = reach_meters / cell_size_meters
	var safe_reach_cells := maxf(profile.reach, GEOMETRY_EPSILON)
	profile.front_heavy_score = clampf(
		profile.primary_grip_offset.dot(handle_axis) / safe_reach_cells,
		-1.0,
		1.0
	)
	profile.balance_score = 1.0 - clampf(
		profile.primary_grip_offset.length() / safe_reach_cells,
		0.0,
		1.0
	)


static func _resolve_weapon_extremities(
	vertices_meters: PackedVector3Array,
	contact_meters: Vector3,
	handle_axis: Vector3
) -> Dictionary:
	var min_projection := INF
	var max_projection := -INF
	for vertex: Vector3 in vertices_meters:
		var projection := handle_axis.dot(vertex - contact_meters)
		min_projection = minf(min_projection, projection)
		max_projection = maxf(max_projection, projection)
	var min_point := contact_meters + handle_axis * min_projection
	var max_point := contact_meters + handle_axis * max_projection
	var min_distance := absf(min_projection)
	var max_distance := absf(max_projection)
	# An exactly centered Handle is a legitimate tie. Keep that tie on the
	# already-resolved positive Handle axis instead of letting float noise swap
	# tip and pommel when the three authored Handle points are reversed.
	var max_is_tip := max_distance + GEOMETRY_EPSILON >= min_distance
	return {
		"tip_meters": max_point if max_is_tip else min_point,
		"pommel_meters": min_point if max_is_tip else max_point,
		"tip_distance_meters": max_distance if max_is_tip else min_distance,
		"pommel_distance_meters": min_distance if max_is_tip else max_distance,
		"total_length_meters": maxf(max_projection - min_projection, 0.0),
	}


static func _build_profile_offset_samples(
	polygon: PackedVector2Array,
	cell_size_meters: float
) -> PackedVector2Array:
	var samples := PackedVector2Array()
	if polygon.size() < 3:
		return samples
	# These samples are legacy grip-collision cell centers, not a copy of the
	# authored profile. The exact polygon remains on the V2 Handle body; the
	# compatibility profile later maps and recenters these samples in the final
	# CSG contact frame consumed by the legacy grip shell.
	var bounds := _calculate_polygon_bounds(polygon)
	var cell_size := maxf(cell_size_meters, 0.001)
	var half_cell := cell_size * 0.5
	var column_count := maxi(
		int(floor((bounds.size.x + GEOMETRY_EPSILON) / cell_size)),
		0
	)
	var row_count := maxi(
		int(floor((bounds.size.y + GEOMETRY_EPSILON) / cell_size)),
		0
	)
	if column_count <= 0 or row_count <= 0:
		return samples
	var occupied_size := Vector2(
		float(column_count) * cell_size,
		float(row_count) * cell_size
	)
	var leading_margin := (bounds.size - occupied_size) * 0.5
	var first_center := bounds.position + leading_margin + Vector2.ONE * half_cell
	var stride_cells := 1
	while (
		ceili(float(column_count) / float(stride_cells))
		* ceili(float(row_count) / float(stride_cells))
		> MAX_PROFILE_OFFSET_SAMPLES
	):
		stride_cells += 1
	for column_index in range(0, column_count, stride_cells):
		for row_index in range(0, row_count, stride_cells):
			var candidate := first_center + Vector2(
				float(column_index) * cell_size,
				float(row_index) * cell_size
			)
			if not _point_is_strictly_inside_polygon(candidate, polygon):
				continue
			_append_unique_profile_sample(samples, candidate)
			if samples.size() >= MAX_PROFILE_OFFSET_SAMPLES:
				return samples
	if samples.is_empty():
		var polygon_center := _calculate_polygon_centroid(polygon)
		var inset_bounds := bounds.grow(-half_cell)
		if (
			inset_bounds.has_point(polygon_center)
			and _point_is_strictly_inside_polygon(polygon_center, polygon)
		):
			_append_unique_profile_sample(samples, polygon_center)
	return samples


static func _map_handle_profile_samples_to_final_csg(
	authored_samples: PackedVector2Array
) -> PackedVector2Array:
	var final_samples := PackedVector2Array()
	final_samples.resize(authored_samples.size())
	for sample_index: int in range(authored_samples.size()):
		var authored_sample := authored_samples[sample_index]
		final_samples[sample_index] = Vector2(
			authored_sample.x * HANDLE_FINAL_PROFILE_AXIS_X_SIGN,
			authored_sample.y
		)
	return final_samples


static func _resolve_handle_grip_geometry(
	handle_body: Resource,
	handle_path: PackedVector3Array,
	final_samples: PackedVector2Array,
	desired_contact_meters: Vector3,
	mesh_vertices_meters: PackedVector3Array,
	protected_handle_vertices_meters: PackedVector3Array,
	protected_handle_indices: PackedInt32Array
) -> Dictionary:
	if handle_path.size() < 2:
		return {}
	var sample_center := Vector2.ZERO
	for sample: Vector2 in final_samples:
		sample_center += sample
	if not final_samples.is_empty():
		sample_center /= float(final_samples.size())
	var chronological_span_start := handle_path[0]
	var chronological_span_end := handle_path[handle_path.size() - 1]
	var chronological_span := (
		chronological_span_end - chronological_span_start
	)
	if (
		chronological_span.length_squared()
		<= GEOMETRY_EPSILON * GEOMETRY_EPSILON
	):
		return {}
	var exact_slice_path := (
		PrimaryGripSeatResolverScript.build_mesh_slice_center_path(
			protected_handle_vertices_meters,
			protected_handle_indices,
			chronological_span_start,
			chronological_span_end,
			HANDLE_GRIP_CURVE_BAKE_INTERVAL_METERS
		)
	)
	if not bool(exact_slice_path.get("valid", false)):
		return {}
	var chronological_ratios: PackedFloat32Array = exact_slice_path.get(
		"ratios",
		PackedFloat32Array()
	) as PackedFloat32Array
	var slice_centers := exact_slice_path.get(
		"centers_meters",
		PackedVector3Array()
	) as PackedVector3Array
	if not PrimaryGripSeatResolverScript.sampled_path_is_valid(
		chronological_ratios,
		slice_centers
	):
		return {}
	var desired_contact_ratio := clampf(
		(desired_contact_meters - chronological_span_start).dot(
			chronological_span
		) / chronological_span.length_squared(),
		0.0,
		1.0
	)
	var chronological_contact_state := (
		PrimaryGripSeatResolverScript.resolve_sampled_seat(
			chronological_ratios,
			slice_centers,
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID,
			desired_contact_ratio
		)
	)
	if not bool(chronological_contact_state.get("valid", false)):
		return {}
	var contact_center: Vector3 = chronological_contact_state.get(
		"position",
		Vector3.ZERO
	) as Vector3

	# The exact Handle-only mesh owns the seat position. The construction curve
	# remains useful only for the already-authored transverse roll of the grip
	# shell; it is not a positional fallback.
	var curve := _build_handle_authority_curve(handle_body, handle_path)
	if curve == null or curve.point_count < 2 or curve.get_baked_length() <= 0.0:
		return {}
	var curve_length := curve.get_baked_length()
	var sample_count := maxi(
		int(ceil(curve_length / HANDLE_GRIP_CURVE_BAKE_INTERVAL_METERS)),
		1
	)
	var curve_offsets := PackedFloat32Array()
	var construction_centers := PackedVector3Array()
	for sample_index: int in range(sample_count + 1):
		var curve_offset := (
			curve_length * float(sample_index) / float(sample_count)
		)
		var frame := _resolve_handle_csg_profile_frame(curve, curve_offset)
		var curve_position: Vector3 = frame.get(
			"position",
			curve.sample_baked(curve_offset)
		)
		var axis_a: Vector3 = frame.get("axis_x", Vector3.UP)
		var axis_b: Vector3 = frame.get("axis_y", Vector3.FORWARD)
		var centerline_point := (
			curve_position
			+ axis_a * sample_center.x
			+ axis_b * sample_center.y
		)
		curve_offsets.append(curve_offset)
		construction_centers.append(centerline_point)
	if construction_centers.size() < 2:
		return {}
	var construction_ratios := (
		PrimaryGripSeatResolverScript.build_axis_ratios_from_centers(
			construction_centers,
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID,
			chronological_span_start,
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID,
			chronological_span_end,
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID
		)
	)
	if not PrimaryGripSeatResolverScript.sampled_path_is_valid(
		construction_ratios,
		construction_centers
	):
		return {}
	var construction_contact_state := (
		PrimaryGripSeatResolverScript.resolve_sampled_seat(
			construction_ratios,
			construction_centers,
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID,
			desired_contact_ratio
		)
	)
	if not bool(construction_contact_state.get("valid", false)):
		return {}
	var contact_segment_index := int(
		construction_contact_state.get("segment_index", -1)
	)
	if contact_segment_index < 0 or contact_segment_index + 1 >= curve_offsets.size():
		return {}
	var contact_offset := lerpf(
		curve_offsets[contact_segment_index],
		curve_offsets[contact_segment_index + 1],
		float(construction_contact_state.get("segment_ratio", 0.0))
	)
	contact_offset = clampf(contact_offset, 0.0, curve_length)
	var contact_frame := _resolve_handle_csg_profile_frame(curve, contact_offset)
	var chronological_axis := chronological_span.normalized()
	var physical_axis_a: Vector3 = contact_frame.get("axis_x", Vector3.UP)
	var physical_axis_b: Vector3 = contact_frame.get(
		"axis_y",
		Vector3.FORWARD
	)
	var ordering_axis := _resolve_order_independent_major_axis(
		mesh_vertices_meters,
		contact_center,
		chronological_axis
	)
	var direction_sign := (
		-1.0 if chronological_axis.dot(ordering_axis) < 0.0 else 1.0
	)
	var exported_axis_a := physical_axis_a * direction_sign
	var exported_axis_b := physical_axis_b
	var centered_offsets := PackedVector2Array()
	centered_offsets.resize(final_samples.size())
	for sample_index: int in range(final_samples.size()):
		var centered_sample := final_samples[sample_index] - sample_center
		centered_offsets[sample_index] = Vector2(
			centered_sample.x * direction_sign,
			centered_sample.y
		)

	var path_reversed := false
	var span_start := chronological_span_start
	var span_end := chronological_span_end
	if chronological_span.dot(ordering_axis) < 0.0:
		span_start = chronological_span_end
		span_end = chronological_span_start
		slice_centers = _reverse_vector3_samples(slice_centers)
		path_reversed = true
	var major_axis := (span_end - span_start).normalized()
	if major_axis.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		return {}
	var slice_axis_ratios := (
		PrimaryGripSeatResolverScript.build_axis_ratios_from_centers(
			slice_centers,
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID,
			span_start,
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID,
			span_end,
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID
		)
	)
	if not PrimaryGripSeatResolverScript.sampled_path_is_valid(
		slice_axis_ratios,
		slice_centers
	):
		return {}
	var contact_ratio := (
		1.0 - desired_contact_ratio
		if path_reversed
		else desired_contact_ratio
	)
	var contact_seat_state := PrimaryGripSeatResolverScript.resolve_sampled_seat(
		slice_axis_ratios,
		slice_centers,
		PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID,
		contact_ratio
	)
	if not bool(contact_seat_state.get("valid", false)):
		return {}
	contact_center = contact_seat_state.get("position", contact_center) as Vector3
	return {
		"profile_path": PackedVector3Array([
			span_start,
			contact_center,
			span_end,
		]),
		"major_axis": major_axis,
		"minor_axis_a": exported_axis_a,
		"minor_axis_b": exported_axis_b,
		"centered_offsets": centered_offsets,
		"sample_center": sample_center,
		"contact_ratio": contact_ratio,
		"span_length_meters": span_start.distance_to(span_end),
		"slice_axis_ratios": slice_axis_ratios,
		"slice_centers_meters": slice_centers,
	}


static func _build_handle_authority_curve(
	handle_body: Resource,
	handle_path: PackedVector3Array
) -> Curve3D:
	var curve: Curve3D
	if StringName(handle_body.get("shape_kind")) == (
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	):
		curve = ForgeV2SplinePathSamplerScript.build_auto_curve(
			handle_path,
			HANDLE_GRIP_CURVE_BAKE_INTERVAL_METERS,
			true
		)
	else:
		curve = Curve3D.new()
		curve.bake_interval = HANDLE_GRIP_CURVE_BAKE_INTERVAL_METERS
		for point: Vector3 in handle_path:
			curve.add_point(point)
	_apply_handle_curve_orientation(curve, handle_body, handle_path)
	return curve


static func _apply_handle_curve_orientation(
	curve: Curve3D,
	handle_body: Resource,
	handle_path: PackedVector3Array
) -> void:
	if curve == null or curve.point_count < 2:
		return
	var path_normals: PackedVector3Array = handle_body.get("path_surface_normals")
	var contact_direction: Vector2 = handle_body.get(
		"profile_contact_direction_2d"
	)
	var rotation_bias := float(handle_body.get("profile_rotation_bias_degrees"))
	var previous_tilt := 0.0
	var has_previous_tilt := false
	var normals_align := (
		curve.point_count == handle_path.size()
		and path_normals.size() >= handle_path.size()
	)
	for point_index: int in range(curve.point_count):
		var tangent := _resolve_curve_control_tangent(curve, point_index)
		var point_position := curve.get_point_position(point_index)
		var surface_normal := Vector3.FORWARD
		if normals_align and point_position.is_equal_approx(handle_path[point_index]):
			surface_normal = (
				ForgeV2ProfileShapeLibraryScript.interpolate_path_surface_normal(
					path_normals,
					point_index,
					0.0
				)
			)
		else:
			surface_normal = (
				ForgeV2ProfileShapeLibraryScript.resolve_path_surface_normal(
					point_position,
					handle_path,
					path_normals
				)
			)
		var frame := ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			tangent,
			surface_normal,
			contact_direction,
			rotation_bias
		)
		var tilt := float(frame.get("tilt_radians", 0.0))
		if has_previous_tilt:
			while tilt - previous_tilt > PI:
				tilt -= TAU
			while tilt - previous_tilt < -PI:
				tilt += TAU
		curve.set_point_tilt(point_index, tilt)
		previous_tilt = tilt
		has_previous_tilt = true


static func _resolve_curve_control_tangent(
	curve: Curve3D,
	point_index: int
) -> Vector3:
	if curve == null or curve.point_count < 2:
		return Vector3.RIGHT
	var current_position := curve.get_point_position(point_index)
	var tangent := Vector3.ZERO
	if point_index > 0:
		tangent += current_position - curve.get_point_position(point_index - 1)
	if point_index < curve.point_count - 1:
		tangent += curve.get_point_position(point_index + 1) - current_position
	return (
		tangent.normalized()
		if tangent.length_squared() > GEOMETRY_EPSILON * GEOMETRY_EPSILON
		else Vector3.RIGHT
	)


static func _resolve_handle_csg_profile_frame(
	curve: Curve3D,
	curve_offset: float
) -> Dictionary:
	var safe_offset := clampf(curve_offset, 0.0, curve.get_baked_length())
	var pose := curve.sample_baked_with_rotation(safe_offset, false, false)
	var tangent := (pose.basis * Vector3.FORWARD).normalized()
	if tangent.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		var delta := maxf(curve.bake_interval * 0.5, 0.0001)
		tangent = (
			curve.sample_baked(minf(safe_offset + delta, curve.get_baked_length()))
			- curve.sample_baked(maxf(safe_offset - delta, 0.0))
		).normalized()
	var up := curve.sample_baked_up_vector(safe_offset, true).normalized()
	if up.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		up = _resolve_profile_frame_fallback_normal(tangent)
	var facing := Transform3D.IDENTITY.looking_at(tangent, up)
	var axis_x := -facing.basis.x.normalized()
	var axis_y := facing.basis.y.normalized()
	if (
		axis_x.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON
		or axis_y.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON
	):
		axis_x = _resolve_profile_frame_fallback_normal(tangent)
		axis_y = tangent.cross(axis_x).normalized()
	return {
		"position": curve.sample_baked(safe_offset),
		"tangent": tangent,
		"axis_x": axis_x,
		"axis_y": axis_y,
	}


static func _resolve_closest_centerline_state(
	centerline_points: PackedVector3Array,
	curve_offsets: PackedFloat32Array,
	desired_position: Vector3
) -> Dictionary:
	var best_distance_squared := INF
	var best_offset := 0.0
	for point_index: int in range(maxi(centerline_points.size() - 1, 0)):
		var point_a := centerline_points[point_index]
		var point_b := centerline_points[point_index + 1]
		var segment := point_b - point_a
		var segment_length_squared := segment.length_squared()
		var ratio := 0.0
		if segment_length_squared > GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			ratio = clampf(
				(desired_position - point_a).dot(segment)
				/ segment_length_squared,
				0.0,
				1.0
			)
		var candidate := point_a + segment * ratio
		var distance_squared := desired_position.distance_squared_to(candidate)
		if distance_squared >= best_distance_squared:
			continue
		best_distance_squared = distance_squared
		best_offset = lerpf(
			curve_offsets[point_index],
			curve_offsets[point_index + 1],
			ratio
		)
	return {
		"curve_offset": best_offset,
		"distance_squared": best_distance_squared,
	}


static func _resolve_order_independent_major_axis(
	mesh_vertices_meters: PackedVector3Array,
	contact_meters: Vector3,
	chronological_axis: Vector3
) -> Vector3:
	var fallback_axis := _canonicalize_axis(chronological_axis)
	if mesh_vertices_meters.is_empty():
		return fallback_axis
	var extremities := _resolve_weapon_extremities(
		mesh_vertices_meters,
		contact_meters,
		fallback_axis
	)
	var tip_point: Vector3 = extremities.get(
		"tip_meters",
		contact_meters + fallback_axis
	)
	var tip_direction := tip_point - contact_meters
	return (
		tip_direction.normalized()
		if tip_direction.length_squared() > GEOMETRY_EPSILON * GEOMETRY_EPSILON
		else fallback_axis
	)


static func _canonicalize_axis(axis: Vector3) -> Vector3:
	var normalized_axis := axis.normalized()
	if normalized_axis.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		return Vector3.RIGHT
	var absolute_axis := Vector3(
		absf(normalized_axis.x),
		absf(normalized_axis.y),
		absf(normalized_axis.z)
	)
	var dominant_component := normalized_axis.x
	if absolute_axis.y > absolute_axis.x and absolute_axis.y >= absolute_axis.z:
		dominant_component = normalized_axis.y
	elif absolute_axis.z > absolute_axis.x and absolute_axis.z > absolute_axis.y:
		dominant_component = normalized_axis.z
	return -normalized_axis if dominant_component < 0.0 else normalized_axis


static func _reverse_vector3_samples(
	samples: PackedVector3Array
) -> PackedVector3Array:
	var reversed := PackedVector3Array()
	reversed.resize(samples.size())
	for sample_index: int in range(samples.size()):
		reversed[sample_index] = samples[samples.size() - 1 - sample_index]
	return reversed


static func _append_unique_profile_sample(
	samples: PackedVector2Array,
	candidate: Vector2
) -> void:
	if not is_finite(candidate.x) or not is_finite(candidate.y):
		return
	for existing: Vector2 in samples:
		if existing.distance_squared_to(candidate) <= VOLUME_EPSILON:
			return
	samples.append(candidate)


static func _point_is_inside_or_on_polygon(
	point: Vector2,
	polygon: PackedVector2Array
) -> bool:
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	for point_index in range(polygon.size()):
		var point_a := polygon[point_index]
		var point_b := polygon[(point_index + 1) % polygon.size()]
		if _distance_squared_to_segment(point, point_a, point_b) <= (
			GEOMETRY_EPSILON * GEOMETRY_EPSILON
		):
			return true
	return false


static func _point_is_strictly_inside_polygon(
	point: Vector2,
	polygon: PackedVector2Array
) -> bool:
	if not Geometry2D.is_point_in_polygon(point, polygon):
		return false
	for point_index in range(polygon.size()):
		var point_a := polygon[point_index]
		var point_b := polygon[(point_index + 1) % polygon.size()]
		if _distance_squared_to_segment(point, point_a, point_b) <= (
			GEOMETRY_EPSILON * GEOMETRY_EPSILON
		):
			return false
	return true


static func _distance_squared_to_segment(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= VOLUME_EPSILON:
		return point.distance_squared_to(segment_start)
	var ratio := clampf(
		(point - segment_start).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	return point.distance_squared_to(segment_start + segment * ratio)


static func _calculate_polygon_centroid(
	polygon: PackedVector2Array
) -> Vector2:
	var signed_area_times_two := 0.0
	var centroid_numerator := Vector2.ZERO
	for point_index in range(polygon.size()):
		var point_a := polygon[point_index]
		var point_b := polygon[(point_index + 1) % polygon.size()]
		var cross := point_a.cross(point_b)
		signed_area_times_two += cross
		centroid_numerator += (point_a + point_b) * cross
	if absf(signed_area_times_two) > VOLUME_EPSILON:
		var centroid := centroid_numerator / (3.0 * signed_area_times_two)
		if _point_is_inside_or_on_polygon(centroid, polygon):
			return centroid
	var average := Vector2.ZERO
	for point: Vector2 in polygon:
		average += point
	average /= float(polygon.size())
	if _point_is_inside_or_on_polygon(average, polygon):
		return average
	return polygon[0]


static func _calculate_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var min_point := polygon[0]
	var max_point := polygon[0]
	for point: Vector2 in polygon:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


static func _calculate_signed_polygon_area(
	polygon: PackedVector2Array
) -> float:
	var signed_area_times_two := 0.0
	for point_index in range(polygon.size()):
		var point_a := polygon[point_index]
		var point_b := polygon[(point_index + 1) % polygon.size()]
		signed_area_times_two += point_a.cross(point_b)
	return signed_area_times_two * 0.5


static func _resolve_density_per_cell(material_variant_id: StringName) -> float:
	if DEFAULT_MATERIAL_CATALOG == null:
		return 0.0
	var requested_ids: Array[StringName] = [material_variant_id]
	var material_text := String(material_variant_id)
	for tier_suffix: String in [
		"_green",
		"_blue",
		"_purple",
		"_orange",
	]:
		if material_text.ends_with(tier_suffix):
			requested_ids.append(
				StringName(material_text.trim_suffix(tier_suffix) + "_gray")
			)
			break
	var entries: Array = DEFAULT_MATERIAL_CATALOG.get("entries") as Array
	for requested_id: StringName in requested_ids:
		for entry_variant: Variant in entries:
			var entry: Resource = entry_variant as Resource
			if (
				entry == null
				or StringName(entry.get("material_id")) != requested_id
			):
				continue
			var material_def: Resource = entry.get("material_def") as Resource
			if material_def == null:
				return 0.0
			return maxf(float(material_def.get("density_per_cell")), 0.0)
	return 0.0


static func _resolve_profile_frame_fallback_normal(axis: Vector3) -> Vector3:
	var normalized_axis := axis.normalized()
	var reference := Vector3.UP
	if absf(normalized_axis.dot(reference)) > 0.95:
		reference = Vector3.RIGHT
	var projected := reference - normalized_axis * reference.dot(normalized_axis)
	if projected.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		return Vector3.FORWARD
	return projected.normalized()


static func _aabb_contains_with_tolerance(aabb: AABB, point: Vector3) -> bool:
	var tolerance := maxf(aabb.size.length() * 0.00001, GEOMETRY_EPSILON)
	var min_point := aabb.position - Vector3.ONE * tolerance
	var max_point := aabb.end + Vector3.ONE * tolerance
	return (
		point.x >= min_point.x
		and point.y >= min_point.y
		and point.z >= min_point.z
		and point.x <= max_point.x
		and point.y <= max_point.y
		and point.z <= max_point.z
	)


static func _vector3_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _build_profile_id(wip: CraftedItemWIP) -> StringName:
	if wip == null or wip.wip_id == StringName():
		return &"profile_forge_v2_runtime"
	return StringName("profile_%s" % String(wip.wip_id))


static func _build_invalid_result(
	profile: BakedProfile,
	stage2_item_state: Resource,
	error: String
) -> Dictionary:
	profile.primary_grip_valid = false
	profile.validation_error = error
	return {
		"stage2_item_state": stage2_item_state,
		"baked_profile": profile,
		"valid": false,
		"error": error,
	}
