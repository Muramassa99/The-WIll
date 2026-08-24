extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2LayerDataScript = preload(
	"res://runtime/forge_v2/forge_v2_layer_data.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2MaterialVolumeResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_material_volume_resolver.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_explicit_surface_profile_integration_2026-08-12.txt"
)
const BODY_ROUNDTRIP_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_explicit_surface_profile_body_roundtrip.tres"
)
const EPSILON := 0.00001


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	root.add_child(presenter)

	var volume_body := _build_surface_profile_body(
		ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
	)
	await _assert_explicit_surface_body(
		presenter,
		volume_body,
		"Volume Stroke"
	)
	var detail_body := _build_surface_profile_body(
		ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH
	)
	detail_body.surface_target_kind = &"material_surface"
	detail_body.surface_target_id = &"surface_zone_verify"
	detail_body.normalize()
	await _assert_explicit_surface_body(
		presenter,
		detail_body,
		"Detailing Brush"
	)

	_assert_body_and_layer_contact_persistence(volume_body)
	_assert_material_volume_parity(volume_body)
	var bent_occupancy := _assert_bent_ruled_endpoint_occupancy()
	_assert_schema_4_surface_contact_migration()
	_assert_legacy_free_path_unchanged(
		presenter,
		ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
		"Spline Line"
	)
	_assert_legacy_free_path_unchanged(
		presenter,
		ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE,
		"Handle"
	)

	_write_result([
		"ok=true",
		"volume_stroke_explicit_surface_frame=true",
		"detailing_brush_explicit_surface_frame=true",
		"live_and_committed_mesh_identical=true",
		"committed_csg_mesh_bakes_closed_nonempty=true",
		"committed_csg_mesh_outward_winding_matches_oracle=true",
		"asymmetric_profile_authored_handedness_preserved=true",
		"flat_path_contact_side_has_no_zig_zag=true",
		"path_contact_directions_body_layer_disk_persisted=true",
		"material_volume_and_spatial_occupancy_match_explicit_frame=true",
		"bent_ruled_endpoint_occupancy_matches_resolver=true",
		"bent_old_midpoint_frame_occupancy_rejected=true",
		"bent_resolver_cell_count=%d" % int(bent_occupancy.get(
			"resolver_cell_count",
			0
		)),
		"bent_old_midpoint_difference_count=%d" % int(
			bent_occupancy.get("old_midpoint_difference_count", 0)
		),
		"schema_4_surface_contact_migration=true",
		"schema_4_zero_normal_does_not_fabricate_contacts=true",
		"free_spline_path_unrestricted=true",
		"handle_path_unrestricted=true",
		"legacy_spline_handle_csg_polygon_unchanged=true",
	])
	quit(0)


func _build_surface_profile_body(body_kind: StringName) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_kind", body_kind)
	body.set(
		"shape_kind",
		ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
	)
	body.set("material_variant_id", &"mat_iron_gray")
	body.set("path_points", PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.05, 0.0, 0.0),
		Vector3(0.10, 0.0, 0.0),
		Vector3(0.15, 0.0, 0.0),
	]))
	body.set("path_surface_normals", PackedVector3Array([
		Vector3.BACK,
		Vector3.BACK,
		Vector3.BACK,
		Vector3.BACK,
	]))
	body.set("path_contact_directions", PackedVector3Array([
		Vector3.FORWARD,
		Vector3.FORWARD,
		Vector3.FORWARD,
		Vector3.FORWARD,
	]))
	body.set("profile_polygon_2d_meters", PackedVector2Array([
		Vector2(-0.015, -0.028),
		Vector2(0.0, -0.032),
		Vector2(0.050, -0.015),
		Vector2(0.055, 0.010),
		Vector2(0.025, 0.035),
		Vector2(-0.015, 0.030),
	]))
	body.set("profile_contact_point_relative_2d_meters", Vector2(0.0, -0.032))
	body.set(
		"profile_contact_direction_2d",
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	body.set("profile_contact_distance_meters", 0.032)
	body.set("profile_runtime_schema_version", 1)
	body.set("profile_rotation_bias_degrees", 0.0)
	body.call("normalize")
	return body


func _assert_explicit_surface_body(
	presenter: Node3D,
	body: Resource,
	label: String
) -> void:
	_require(
		bool(body.call("uses_explicit_surface_contact_authority")),
		"%s body rejected its explicit B-C authority" % label
	)
	_require(
		bool(presenter.call("_uses_explicit_surface_profile_frame", body)),
		"%s presenter rejected its explicit surface frame" % label
	)
	var live_mesh: ArrayMesh = presenter.call(
		"_build_active_material_body_sweep_mesh",
		body
	) as ArrayMesh
	_require(
		live_mesh != null and live_mesh.get_surface_count() > 0,
		"%s live surface sweep was not generated" % label
	)

	var path_points: PackedVector3Array = body.get("path_points")
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	var contact_point: Vector2 = body.get(
		"profile_contact_point_relative_2d_meters"
	) as Vector2
	for point_index in range(path_points.size()):
		var tangent := _resolve_linear_tangent(path_points, point_index)
		var ring: PackedVector3Array = presenter.call(
			"_build_profile_sweep_ring",
			body,
			polygon,
			point_index,
			tangent
		) as PackedVector3Array
		_require(
			ring.size() == polygon.size(),
			"%s ring %d was incomplete" % [label, point_index]
		)
		var expected_contact := (
			path_points[point_index]
			+ Vector3.FORWARD * contact_point.length()
		)
		_require(
			_ring_contains_point(ring, expected_contact),
			"%s ring %d did not place authored C on explicit B-C"
			% [label, point_index]
		)

	var committed_root := Node3D.new()
	committed_root.name = "%sCommittedRoot" % label.replace(" ", "")
	root.add_child(committed_root)
	_require(
		bool(presenter.call(
			"_append_csg_body_shape",
			committed_root,
			body,
			&"mat_iron_gray",
			false,
			0
		)),
		"%s committed CSG shape was not generated" % label
	)
	var committed_mesh_node := _find_csg_mesh(committed_root)
	_require(
		committed_mesh_node != null
		and bool(committed_mesh_node.get_meta(
			"forge_v2_explicit_surface_frame",
			false
		)),
		"%s did not commit through the explicit CSGMesh path" % label
	)
	_require(
		_mesh_arrays_match(live_mesh, committed_mesh_node.mesh),
		"%s live and committed profile geometry differed" % label
	)
	await process_frame
	await process_frame
	var baked_mesh: ArrayMesh = committed_mesh_node.bake_static_mesh()
	_require(
		baked_mesh != null
		and baked_mesh.get_surface_count() > 0
		and _mesh_triangle_count(baked_mesh) > 0
		and _mesh_has_three_dimensional_extent(baked_mesh)
		and _mesh_is_closed_after_positional_weld(baked_mesh),
		"%s explicit CSGMesh did not bake as closed nonempty volume" % label
	)
	var legacy_oracle_body: Resource = body.duplicate(true) as Resource
	legacy_oracle_body.set(
		"path_contact_directions",
		PackedVector3Array()
	)
	legacy_oracle_body.call("normalize")
	var legacy_oracle_root := Node3D.new()
	legacy_oracle_root.name = "%sWindingOracleRoot" % label.replace(" ", "")
	root.add_child(legacy_oracle_root)
	_require(
		bool(presenter.call(
			"_append_csg_body_shape",
			legacy_oracle_root,
			legacy_oracle_body,
			&"mat_iron_gray",
			false,
			1
		)),
		"%s legacy winding oracle was not generated" % label
	)
	await process_frame
	await process_frame
	var legacy_oracle_polygon := _find_csg_polygon(legacy_oracle_root)
	_require(
		legacy_oracle_polygon != null,
		"%s legacy winding oracle CSGPolygon was missing" % label
	)
	var legacy_oracle_mesh := legacy_oracle_polygon.bake_static_mesh()
	var explicit_signed_volume := _mesh_signed_volume(baked_mesh)
	var oracle_signed_volume := _mesh_signed_volume(legacy_oracle_mesh)
	_require(
		absf(explicit_signed_volume) > 0.000000001
		and absf(oracle_signed_volume) > 0.000000001
		and explicit_signed_volume * oracle_signed_volume > 0.0,
		(
			"%s explicit capped sweep winding was inside-out against CSG oracle "
			+ "(explicit=%0.12f oracle=%0.12f)"
		) % [label, explicit_signed_volume, oracle_signed_volume]
	)
	legacy_oracle_root.queue_free()
	committed_root.queue_free()


func _assert_body_and_layer_contact_persistence(body: Resource) -> void:
	var expected: PackedVector3Array = body.get("path_contact_directions")
	var duplicated: Resource = body.duplicate(true) as Resource
	_require(
		duplicated != null
		and _packed_vector3_arrays_match(
			duplicated.get("path_contact_directions") as PackedVector3Array,
			expected
		),
		"body deep copy lost explicit B-C samples"
	)
	var bodies: Array[Resource] = [duplicated]
	var layer: Resource = ForgeV2LayerDataScript.new()
	layer.call("configure_from_material_bodies", 1, bodies)
	var records: Array = layer.get("input_shape_records") as Array
	_require(not records.is_empty(), "layer did not record explicit surface body")
	var record := records[0] as Dictionary
	_require(
		_packed_vector3_arrays_match(
			record.get(
				"path_contact_directions",
				PackedVector3Array()
			) as PackedVector3Array,
			expected
		),
		"layer record lost explicit B-C samples"
	)
	_require(
		ResourceSaver.save(duplicated, BODY_ROUNDTRIP_PATH) == OK,
		"explicit surface body disk save failed"
	)
	var loaded: Resource = ResourceLoader.load(
		BODY_ROUNDTRIP_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	_require(
		loaded != null
		and _packed_vector3_arrays_match(
			loaded.get("path_contact_directions") as PackedVector3Array,
			expected
		),
		"explicit surface body disk reload lost B-C samples"
	)
	DirAccess.remove_absolute(BODY_ROUNDTRIP_PATH)


func _assert_material_volume_parity(body: Resource) -> void:
	var resolver = ForgeV2MaterialVolumeResolverScript.new()
	var explicit_bodies: Array = [body.duplicate(true)]
	var explicit_summary: Dictionary = resolver.call(
		"build_usage_summary",
		explicit_bodies
	) as Dictionary
	var legacy_mirrored_body: Resource = body.duplicate(true) as Resource
	legacy_mirrored_body.set(
		"path_contact_directions",
		PackedVector3Array()
	)
	legacy_mirrored_body.call("normalize")
	var legacy_bodies: Array = [legacy_mirrored_body]
	var legacy_summary: Dictionary = resolver.call(
		"build_usage_summary",
		legacy_bodies
	) as Dictionary
	var explicit_volume := float(explicit_summary.get(
		"total_rough_volume_cell_equivalents",
		0.0
	))
	var legacy_volume := float(legacy_summary.get(
		"total_rough_volume_cell_equivalents",
		0.0
	))
	var sample_cell_size := float(resolver.call(
		"_resolve_group_sample_cell_size",
		explicit_bodies
	))
	var explicit_cells: Dictionary = resolver.call(
		"_collect_body_occupied_cells",
		body,
		sample_cell_size
	) as Dictionary
	var legacy_cells: Dictionary = resolver.call(
		"_collect_body_occupied_cells",
		legacy_mirrored_body,
		sample_cell_size
	) as Dictionary
	var explicit_frame: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.
		resolve_explicit_surface_profile_path_frame(
			Vector3.RIGHT,
			Vector3.BACK,
			body.get("profile_contact_direction_2d") as Vector2,
			body.get(
				"profile_contact_point_relative_2d_meters"
			) as Vector2,
			Vector3.FORWARD,
			0.0
		)
	)
	var visible_axis_x := explicit_frame.get(
		"axis_x",
		Vector3.ZERO
	) as Vector3
	var explicit_centroid := _occupied_cell_centroid(
		explicit_cells,
		sample_cell_size
	)
	var legacy_centroid := _occupied_cell_centroid(
		legacy_cells,
		sample_cell_size
	)
	_require(
		explicit_volume > 0.0
		and is_equal_approx(explicit_volume, legacy_volume)
		and int(explicit_summary.get(
			"total_rough_material_centi_units",
			0
		)) == int(legacy_summary.get(
			"total_rough_material_centi_units",
			-1
		))
		and not _dictionary_key_sets_match(explicit_cells, legacy_cells)
		and explicit_centroid.dot(visible_axis_x) > 0.002
		and legacy_centroid.dot(visible_axis_x) < -0.002,
		"material occupancy did not follow the visible explicit frame spatially"
	)


func _assert_bent_ruled_endpoint_occupancy() -> Dictionary:
	var body := _build_surface_profile_body(
		ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
	)
	body.set("path_points", PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.075, 0.0, 0.0),
		Vector3(0.075, 0.075, 0.0),
	]))
	body.set("path_surface_normals", PackedVector3Array([
		Vector3.BACK,
		Vector3.BACK,
		Vector3.BACK,
	]))
	body.set("path_contact_directions", PackedVector3Array([
		Vector3.FORWARD,
		Vector3.FORWARD,
		Vector3.FORWARD,
	]))
	body.call("normalize")
	var resolver = ForgeV2MaterialVolumeResolverScript.new()
	var sample_cell_size := 0.005
	var resolver_cells: Dictionary = resolver.call(
		"_collect_body_occupied_cells",
		body,
		sample_cell_size
	) as Dictionary
	var ruled_endpoint_cells := _collect_reference_profile_occupancy(
		body,
		sample_cell_size,
		true
	)
	var old_midpoint_cells := _collect_reference_profile_occupancy(
		body,
		sample_cell_size,
		false
	)
	var old_midpoint_difference_count := _dictionary_symmetric_difference_count(
		resolver_cells,
		old_midpoint_cells
	)
	_require(
		not resolver_cells.is_empty()
		and _dictionary_key_sets_match(
			resolver_cells,
			ruled_endpoint_cells
		),
		(
			"bent explicit occupancy did not follow the independently sampled "
			+ "ruled endpoint rings"
		)
	)
	_require(
		old_midpoint_difference_count > 0
		and not _dictionary_key_sets_match(
			resolver_cells,
			old_midpoint_cells
		),
		"bent asymmetric case did not distinguish old midpoint-frame occupancy"
	)
	return {
		"resolver_cell_count": resolver_cells.size(),
		"old_midpoint_difference_count": old_midpoint_difference_count,
	}


func _collect_reference_profile_occupancy(
	body: Resource,
	sample_cell_size: float,
	use_ruled_endpoint_frames: bool
) -> Dictionary:
	var occupied_cells: Dictionary = {}
	var path_points: PackedVector3Array = body.get("path_points")
	var path_surface_normals: PackedVector3Array = body.get(
		"path_surface_normals"
	)
	var path_contact_directions: PackedVector3Array = body.get(
		"path_contact_directions"
	)
	var profile_polygon: PackedVector2Array = body.get(
		"profile_polygon_2d_meters"
	)
	var contact_direction: Vector2 = body.get(
		"profile_contact_direction_2d"
	) as Vector2
	var contact_point: Vector2 = body.get(
		"profile_contact_point_relative_2d_meters"
	) as Vector2
	var rotation_bias := float(body.get("profile_rotation_bias_degrees"))
	for segment_index in range(path_points.size() - 1):
		var from_frame: Dictionary
		var to_frame: Dictionary
		if use_ruled_endpoint_frames:
			from_frame = (
				ForgeV2ProfileShapeLibraryScript.
				resolve_explicit_surface_profile_path_frame(
					ForgeV2ProfileShapeLibraryScript.
					resolve_linear_path_point_tangent(
						path_points,
						segment_index
					),
					path_surface_normals[segment_index],
					contact_direction,
					contact_point,
					path_contact_directions[segment_index],
					rotation_bias
				)
			)
			to_frame = (
				ForgeV2ProfileShapeLibraryScript.
				resolve_explicit_surface_profile_path_frame(
					ForgeV2ProfileShapeLibraryScript.
					resolve_linear_path_point_tangent(
						path_points,
						segment_index + 1
					),
					path_surface_normals[segment_index + 1],
					contact_direction,
					contact_point,
					path_contact_directions[segment_index + 1],
					rotation_bias
				)
			)
		else:
			var segment_tangent := (
				path_points[segment_index + 1]
				- path_points[segment_index]
			).normalized()
			var midpoint_normal := path_surface_normals[
				segment_index
			].lerp(
				path_surface_normals[segment_index + 1],
				0.5
			).normalized()
			var midpoint_contact := path_contact_directions[
				segment_index
			].lerp(
				path_contact_directions[segment_index + 1],
				0.5
			).normalized()
			from_frame = (
				ForgeV2ProfileShapeLibraryScript.
				resolve_explicit_surface_profile_path_frame(
					segment_tangent,
					midpoint_normal,
					contact_direction,
					contact_point,
					midpoint_contact,
					rotation_bias
				)
			)
			to_frame = from_frame
		_mark_reference_ruled_segment_cells(
			occupied_cells,
			path_points[segment_index],
			path_points[segment_index + 1],
			profile_polygon,
			sample_cell_size,
			from_frame.get("axis_x", Vector3.ZERO) as Vector3,
			from_frame.get("axis_y", Vector3.ZERO) as Vector3,
			to_frame.get("axis_x", Vector3.ZERO) as Vector3,
			to_frame.get("axis_y", Vector3.ZERO) as Vector3
		)
	return occupied_cells


func _mark_reference_ruled_segment_cells(
	occupied_cells: Dictionary,
	from_point: Vector3,
	to_point: Vector3,
	profile_polygon: PackedVector2Array,
	sample_cell_size: float,
	from_axis_x: Vector3,
	from_axis_y: Vector3,
	to_axis_x: Vector3,
	to_axis_y: Vector3
) -> void:
	var segment := to_point - from_point
	var segment_length := segment.length()
	if segment_length <= 0.000001:
		return
	var tangent := segment / segment_length
	var min_point := Vector3(INF, INF, INF)
	var max_point := Vector3(-INF, -INF, -INF)
	for profile_point: Vector2 in profile_polygon:
		for ring_point: Vector3 in [
			(
				from_point
				+ from_axis_x * profile_point.x
				+ from_axis_y * profile_point.y
			),
			(
				to_point
				+ to_axis_x * profile_point.x
				+ to_axis_y * profile_point.y
			),
		]:
			min_point.x = minf(min_point.x, ring_point.x)
			min_point.y = minf(min_point.y, ring_point.y)
			min_point.z = minf(min_point.z, ring_point.z)
			max_point.x = maxf(max_point.x, ring_point.x)
			max_point.y = maxf(max_point.y, ring_point.y)
			max_point.z = maxf(max_point.z, ring_point.z)
	var min_index := _sample_index_floor(min_point, sample_cell_size)
	var max_index := _sample_index_floor(max_point, sample_cell_size)
	for x_index in range(min_index.x, max_index.x + 1):
		for y_index in range(min_index.y, max_index.y + 1):
			for z_index in range(min_index.z, max_index.z + 1):
				var sample_position := _sample_center_from_index(
					x_index,
					y_index,
					z_index,
					sample_cell_size
				)
				var distance_along_path := (
					sample_position - from_point
				).dot(tangent)
				if (
					distance_along_path < 0.0
					or distance_along_path > segment_length
				):
					continue
				var segment_ratio := clampf(
					distance_along_path / segment_length,
					0.0,
					1.0
				)
				var axis_x := from_axis_x.lerp(to_axis_x, segment_ratio)
				var axis_y := from_axis_y.lerp(to_axis_y, segment_ratio)
				var axis_x_squared := axis_x.dot(axis_x)
				var axis_x_axis_y := axis_x.dot(axis_y)
				var axis_y_squared := axis_y.dot(axis_y)
				var gram_determinant := (
					axis_x_squared * axis_y_squared
					- axis_x_axis_y * axis_x_axis_y
				)
				if gram_determinant <= 0.000000000001:
					continue
				var profile_center := (
					from_point + tangent * distance_along_path
				)
				var lateral_position := sample_position - profile_center
				var lateral_axis_x := lateral_position.dot(axis_x)
				var lateral_axis_y := lateral_position.dot(axis_y)
				var profile_point := Vector2(
					(
						lateral_axis_x * axis_y_squared
						- lateral_axis_y * axis_x_axis_y
					) / gram_determinant,
					(
						lateral_axis_y * axis_x_squared
						- lateral_axis_x * axis_x_axis_y
					) / gram_determinant
				)
				if not _profile_polygon_contains_point(
					profile_polygon,
					profile_point
				):
					continue
				occupied_cells[Vector3i(
					x_index,
					y_index,
					z_index
				)] = true


func _profile_polygon_contains_point(
	polygon: PackedVector2Array,
	point: Vector2
) -> bool:
	var inside := false
	var previous_index := polygon.size() - 1
	for point_index in range(polygon.size()):
		var current_point: Vector2 = polygon[point_index]
		var previous_point: Vector2 = polygon[previous_index]
		if (
			_distance_squared_to_2d_segment(
				point,
				current_point,
				previous_point
			)
			<= 0.00000001
		):
			return true
		var crosses_y := (
			current_point.y > point.y
		) != (
			previous_point.y > point.y
		)
		if crosses_y:
			var denominator := previous_point.y - current_point.y
			if absf(denominator) > 0.000001:
				var intersect_x := (
					(previous_point.x - current_point.x)
					* (point.y - current_point.y)
					/ denominator
					+ current_point.x
				)
				if point.x < intersect_x:
					inside = not inside
		previous_index = point_index
	return inside


func _distance_squared_to_2d_segment(
	point: Vector2,
	from_point: Vector2,
	to_point: Vector2
) -> float:
	var segment := to_point - from_point
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.000001:
		return point.distance_squared_to(from_point)
	var segment_ratio := clampf(
		(point - from_point).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	return point.distance_squared_to(
		from_point + segment * segment_ratio
	)


func _sample_index_floor(
	point: Vector3,
	sample_cell_size: float
) -> Vector3i:
	return Vector3i(
		int(floor(point.x / sample_cell_size)),
		int(floor(point.y / sample_cell_size)),
		int(floor(point.z / sample_cell_size))
	)


func _sample_center_from_index(
	x_index: int,
	y_index: int,
	z_index: int,
	sample_cell_size: float
) -> Vector3:
	return Vector3(
		(float(x_index) + 0.5) * sample_cell_size,
		(float(y_index) + 0.5) * sample_cell_size,
		(float(z_index) + 0.5) * sample_cell_size
	)


func _dictionary_symmetric_difference_count(
	first: Dictionary,
	second: Dictionary
) -> int:
	var difference_count := 0
	for key: Variant in first.keys():
		if not second.has(key):
			difference_count += 1
	for key: Variant in second.keys():
		if not first.has(key):
			difference_count += 1
	return difference_count


func _assert_schema_4_surface_contact_migration() -> void:
	var legacy_normals := PackedVector3Array([
		Vector3.BACK,
		Vector3(0.0, 0.2, 1.0).normalized(),
		Vector3.BACK,
	])
	var expected_contacts := PackedVector3Array()
	for legacy_normal: Vector3 in legacy_normals:
		expected_contacts.append(-legacy_normal.normalized())
	var valid_body_id := &"verify_schema_4_surface_profile"
	var valid_body := _build_schema_4_profile_body(
		valid_body_id,
		legacy_normals
	)
	var active_layer := _build_schema_4_layer(
		&"verify_schema_4_active_layer",
		valid_body
	)
	var undone_layer := _build_schema_4_layer(
		&"verify_schema_4_undone_layer",
		valid_body
	)
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.set("schema_version", 4)
	var valid_bodies: Array[Resource] = [valid_body]
	var active_layers: Array[Resource] = [active_layer]
	var undone_layers: Array[Resource] = [undone_layer]
	state.set("material_bodies", valid_bodies)
	state.set("forge_layers", active_layers)
	state.set("undone_forge_layers", undone_layers)
	state.call("normalize")
	var migrated_body := _find_body_by_id(
		state.get("material_bodies") as Array[Resource],
		valid_body_id
	)
	_require(
		migrated_body != null
		and StringName(migrated_body.get("body_kind"))
		== ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
		and _packed_vector3_arrays_match(
			migrated_body.get(
				"path_contact_directions"
			) as PackedVector3Array,
			expected_contacts
		),
		"schema-4 compiled ProfileExtrusion body did not migrate to VolumeStroke B-C"
	)
	for layer_group: Array in [
		state.get("forge_layers") as Array,
		state.get("undone_forge_layers") as Array,
	]:
		_require(
			not layer_group.is_empty(),
			"schema-4 migration discarded an active or undone layer"
		)
		var migrated_record := _find_layer_record_by_body_id(
			layer_group[0] as Resource,
			valid_body_id
		)
		_require(
			not migrated_record.is_empty()
			and StringName(migrated_record.get(
				"body_kind",
				StringName()
			)) == ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
			and _packed_vector3_arrays_match(
				migrated_record.get(
					"path_contact_directions",
					PackedVector3Array()
				) as PackedVector3Array,
				expected_contacts
			),
			"schema-4 active or undone layer record lost migrated body kind/B-C"
		)

	var zero_body_id := &"verify_schema_4_zero_normal_profile"
	var zero_body := _build_schema_4_profile_body(
		zero_body_id,
		PackedVector3Array([
			Vector3.ZERO,
			Vector3.ZERO,
			Vector3.ZERO,
		])
	)
	var zero_active_layer := _build_schema_4_layer(
		&"verify_schema_4_zero_active_layer",
		zero_body
	)
	var zero_undone_layer := _build_schema_4_layer(
		&"verify_schema_4_zero_undone_layer",
		zero_body
	)
	var zero_state: Resource = ForgeV2AuthoringStateScript.new()
	zero_state.set("schema_version", 4)
	var zero_bodies: Array[Resource] = [zero_body]
	var zero_active_layers: Array[Resource] = [zero_active_layer]
	var zero_undone_layers: Array[Resource] = [zero_undone_layer]
	zero_state.set("material_bodies", zero_bodies)
	zero_state.set("forge_layers", zero_active_layers)
	zero_state.set("undone_forge_layers", zero_undone_layers)
	zero_state.call("normalize")
	var migrated_zero_body := _find_body_by_id(
		zero_state.get("material_bodies") as Array[Resource],
		zero_body_id
	)
	_require(
		migrated_zero_body != null
		and (
			migrated_zero_body.get(
				"path_contact_directions"
			) as PackedVector3Array
		).is_empty(),
		"schema-4 zero normals fabricated body B-C samples"
	)
	for layer_group: Array in [
		zero_state.get("forge_layers") as Array,
		zero_state.get("undone_forge_layers") as Array,
	]:
		var zero_record := _find_layer_record_by_body_id(
			layer_group[0] as Resource,
			zero_body_id
		)
		_require(
			not zero_record.is_empty()
			and (
				zero_record.get(
					"path_contact_directions",
					PackedVector3Array()
				) as PackedVector3Array
			).is_empty(),
			"schema-4 zero normals fabricated active or undone record B-C"
		)


func _build_schema_4_profile_body(
	body_id: StringName,
	legacy_normals: PackedVector3Array
) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_id", body_id)
	body.set(
		"body_kind",
		ForgeV2MaterialBodyScript.BODY_KIND_PROFILE_EXTRUSION
	)
	body.set(
		"shape_kind",
		ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
	)
	body.set("material_variant_id", &"mat_iron_gray")
	body.set("path_points", PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.04, 0.0, 0.0),
		Vector3(0.08, 0.0, 0.0),
	]))
	body.set("path_surface_normals", legacy_normals)
	body.set("path_contact_directions", PackedVector3Array())
	body.set("profile_polygon_2d_meters", PackedVector2Array([
		Vector2(-0.01, -0.018),
		Vector2(0.022, -0.009),
		Vector2(0.012, 0.024),
		Vector2(-0.014, 0.015),
	]))
	body.set(
		"profile_contact_point_relative_2d_meters",
		Vector2(0.0, -0.018)
	)
	body.set(
		"profile_contact_direction_2d",
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	body.set("profile_contact_distance_meters", 0.018)
	body.set("profile_runtime_schema_version", 1)
	return body


func _build_schema_4_layer(
	layer_id: StringName,
	body: Resource
) -> Resource:
	var layer: Resource = ForgeV2LayerDataScript.new()
	layer.set("layer_id", layer_id)
	layer.set("order_index", 1)
	var body_id := StringName(body.get("body_id"))
	var body_ids: Array[StringName] = [body_id]
	layer.set("body_ids", body_ids)
	var records: Array[Dictionary] = [{
		"body_id": body_id,
		"body_kind": ForgeV2MaterialBodyScript.BODY_KIND_PROFILE_EXTRUSION,
		"material_variant_id": StringName(body.get("material_variant_id")),
		"operation_mode": StringName(body.get("operation_mode")),
		"placement_policy": StringName(body.get("placement_policy")),
		"shape_kind": StringName(body.get("shape_kind")),
		"path_points": body.get("path_points"),
		"path_surface_normals": body.get("path_surface_normals"),
		"path_contact_directions": PackedVector3Array(),
		"profile_polygon_2d_meters": body.get(
			"profile_polygon_2d_meters"
		),
		"profile_contact_point_relative_2d_meters": body.get(
			"profile_contact_point_relative_2d_meters"
		),
		"profile_contact_direction_2d": body.get(
			"profile_contact_direction_2d"
		),
		"profile_runtime_schema_version": 1,
		"amount_ratio": 1.0,
	}]
	layer.set("input_shape_records", records)
	return layer


func _find_body_by_id(
	bodies: Array[Resource],
	body_id: StringName
) -> Resource:
	for body: Resource in bodies:
		if body != null and StringName(body.get("body_id")) == body_id:
			return body
	return null


func _find_layer_record_by_body_id(
	layer: Resource,
	body_id: StringName
) -> Dictionary:
	if layer == null:
		return {}
	var records: Array = layer.get("input_shape_records") as Array
	for record_variant: Variant in records:
		if (
			record_variant is Dictionary
			and StringName((record_variant as Dictionary).get(
				"body_id",
				StringName()
			)) == body_id
		):
			return record_variant as Dictionary
	return {}


func _occupied_cell_centroid(
	occupied_cells: Dictionary,
	sample_cell_size: float
) -> Vector3:
	if occupied_cells.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for key_variant: Variant in occupied_cells.keys():
		var key := key_variant as Vector3i
		sum += Vector3(
			(float(key.x) + 0.5) * sample_cell_size,
			(float(key.y) + 0.5) * sample_cell_size,
			(float(key.z) + 0.5) * sample_cell_size
		)
	return sum / float(occupied_cells.size())


func _dictionary_key_sets_match(first: Dictionary, second: Dictionary) -> bool:
	if first.size() != second.size():
		return false
	for key: Variant in first.keys():
		if not second.has(key):
			return false
	return true


func _assert_legacy_free_path_unchanged(
	presenter: Node3D,
	body_kind: StringName,
	label: String
) -> void:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_kind", body_kind)
	body.set(
		"shape_kind",
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	)
	var raw_path := PackedVector3Array([
		Vector3(-0.08, 0.04, -0.06),
		Vector3(0.01, 0.13, 0.07),
		Vector3(0.12, -0.05, 0.11),
	])
	body.set("path_points", raw_path)
	body.set("path_surface_normals", PackedVector3Array([
		Vector3.UP,
		Vector3.BACK,
		Vector3.LEFT,
	]))
	body.set("profile_polygon_2d_meters", PackedVector2Array([
		Vector2(-0.02, -0.018),
		Vector2(0.025, -0.014),
		Vector2(0.018, 0.023),
		Vector2(-0.017, 0.026),
	]))
	body.set("profile_contact_point_relative_2d_meters", Vector2(0.0, -0.018))
	body.set(
		"profile_contact_direction_2d",
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	body.set("profile_contact_distance_meters", 0.018)
	body.set("profile_runtime_schema_version", 1)
	body.call("normalize")
	_require(
		not bool(body.call("uses_explicit_surface_contact_authority"))
		and not bool(presenter.call(
			"_uses_explicit_surface_profile_frame",
			body
		)),
		"%s was accidentally routed into surface-constrained B-C" % label
	)
	_require(
		_packed_vector3_arrays_match(
			body.get("path_points") as PackedVector3Array,
			raw_path
		),
		"%s path was projected or otherwise rewritten" % label
	)
	var committed_root := Node3D.new()
	committed_root.name = "%sLegacyRoot" % label.replace(" ", "")
	root.add_child(committed_root)
	_require(
		bool(presenter.call(
			"_append_csg_body_shape",
			committed_root,
			body,
			&"mat_iron_gray",
			false,
			0
		)),
		"%s legacy CSG shape was not generated" % label
	)
	_require(
		_find_csg_polygon(committed_root) != null
		and _find_csg_mesh(committed_root) == null,
		"%s no longer uses the unchanged free-path CSGPolygon route" % label
	)
	var path_node := _find_path(committed_root)
	_require(
		path_node != null
		and path_node.curve != null
		and path_node.curve.point_count == raw_path.size(),
		"%s committed curve did not retain its authored controls" % label
	)
	for point_index in range(raw_path.size()):
		_require(
			path_node.curve.get_point_position(point_index).is_equal_approx(
				raw_path[point_index]
			),
			"%s control %d moved onto a surface" % [label, point_index]
		)
	committed_root.queue_free()


func _resolve_linear_tangent(
	points: PackedVector3Array,
	point_index: int
) -> Vector3:
	var current: Vector3 = points[point_index]
	var tangent := Vector3.ZERO
	if point_index > 0:
		tangent += current - points[point_index - 1]
	if point_index < points.size() - 1:
		tangent += points[point_index + 1] - current
	return tangent.normalized() if tangent.length_squared() > 0.000001 else Vector3.RIGHT


func _ring_contains_point(ring: PackedVector3Array, expected: Vector3) -> bool:
	for point: Vector3 in ring:
		if point.distance_to(expected) <= EPSILON:
			return true
	return false


func _mesh_arrays_match(first: Mesh, second: Mesh) -> bool:
	if first == null or second == null:
		return false
	if first.get_surface_count() != second.get_surface_count():
		return false
	for surface_index in range(first.get_surface_count()):
		var first_arrays: Array = first.surface_get_arrays(surface_index)
		var second_arrays: Array = second.surface_get_arrays(surface_index)
		var first_vertices: PackedVector3Array = first_arrays[Mesh.ARRAY_VERTEX]
		var second_vertices: PackedVector3Array = second_arrays[Mesh.ARRAY_VERTEX]
		if not _packed_vector3_arrays_match(first_vertices, second_vertices):
			return false
		var first_indices: PackedInt32Array = first_arrays[Mesh.ARRAY_INDEX]
		var second_indices: PackedInt32Array = second_arrays[Mesh.ARRAY_INDEX]
		if first_indices != second_indices:
			return false
	return true


func _mesh_triangle_count(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var triangle_count := 0
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		triangle_count += int(
			indices.size() / 3.0
			if not indices.is_empty()
			else vertices.size() / 3.0
		)
	return triangle_count


func _mesh_has_three_dimensional_extent(mesh: Mesh) -> bool:
	var bounds := mesh.get_aabb()
	return (
		bounds.size.x > EPSILON
		and bounds.size.y > EPSILON
		and bounds.size.z > EPSILON
	)


func _mesh_signed_volume(mesh: Mesh) -> float:
	if mesh == null:
		return 0.0
	var signed_volume := 0.0
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var triangle_vertex_count := (
			indices.size() if not indices.is_empty() else vertices.size()
		)
		for triangle_offset in range(0, triangle_vertex_count, 3):
			if triangle_offset + 2 >= triangle_vertex_count:
				return 0.0
			var triangle := PackedVector3Array()
			for corner_offset in range(3):
				var source_index := (
					int(indices[triangle_offset + corner_offset])
					if not indices.is_empty()
					else triangle_offset + corner_offset
				)
				if source_index < 0 or source_index >= vertices.size():
					return 0.0
				triangle.append(vertices[source_index])
			signed_volume += triangle[0].dot(
				triangle[1].cross(triangle[2])
			) / 6.0
	return signed_volume


func _mesh_is_closed_after_positional_weld(mesh: Mesh) -> bool:
	if mesh == null:
		return false
	var edge_counts: Dictionary = {}
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var triangle_vertex_count := (
			indices.size() if not indices.is_empty() else vertices.size()
		)
		for triangle_offset in range(0, triangle_vertex_count, 3):
			if triangle_offset + 2 >= triangle_vertex_count:
				return false
			var triangle_keys: Array[String] = []
			for corner_offset in range(3):
				var source_index := (
					int(indices[triangle_offset + corner_offset])
					if not indices.is_empty()
					else triangle_offset + corner_offset
				)
				if source_index < 0 or source_index >= vertices.size():
					return false
				triangle_keys.append(_welded_vertex_key(vertices[source_index]))
			_add_welded_edge(edge_counts, triangle_keys[0], triangle_keys[1])
			_add_welded_edge(edge_counts, triangle_keys[1], triangle_keys[2])
			_add_welded_edge(edge_counts, triangle_keys[2], triangle_keys[0])
	if edge_counts.is_empty():
		return false
	for count_variant: Variant in edge_counts.values():
		if int(count_variant) != 2:
			return false
	return true


func _welded_vertex_key(vertex: Vector3) -> String:
	var weld_step := EPSILON * 2.0
	return "%d:%d:%d" % [
		int(round(vertex.x / weld_step)),
		int(round(vertex.y / weld_step)),
		int(round(vertex.z / weld_step)),
	]


func _add_welded_edge(
	edge_counts: Dictionary,
	first_key: String,
	second_key: String
) -> void:
	if first_key == second_key:
		return
	var edge_key := (
		"%s|%s" % [first_key, second_key]
		if first_key < second_key
		else "%s|%s" % [second_key, first_key]
	)
	edge_counts[edge_key] = int(edge_counts.get(edge_key, 0)) + 1


func _packed_vector3_arrays_match(
	first: PackedVector3Array,
	second: PackedVector3Array
) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if first[index].distance_to(second[index]) > EPSILON:
			return false
	return true


func _find_csg_mesh(node: Node) -> CSGMesh3D:
	if node is CSGMesh3D:
		return node as CSGMesh3D
	for child: Node in node.get_children():
		var found := _find_csg_mesh(child)
		if found != null:
			return found
	return null


func _find_csg_polygon(node: Node) -> CSGPolygon3D:
	if node is CSGPolygon3D:
		return node as CSGPolygon3D
	for child: Node in node.get_children():
		var found := _find_csg_polygon(child)
		if found != null:
			return found
	return null


func _find_path(node: Node) -> Path3D:
	if node is Path3D:
		return node as Path3D
	for child: Node in node.get_children():
		var found := _find_path(child)
		if found != null:
			return found
	return null


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_write_result(["ok=false", "error=%s" % message])
	push_error(message)
	quit(1)


func _write_result(lines: Array[String]) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
