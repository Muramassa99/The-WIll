extends SceneTree

const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)
const ForgeV2WorkpieceBenchmarkMeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)

const FIXTURE_SCHEMA := "forge_v2_exact_regional_fixture"
const FIXTURE_SCHEMA_VERSION := 1
const FIXTURE_ID := "forge_v2_exact_regional_fixture_v1"
const PACKET_SCHEMA_VERSION := 1
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/forge_v2_exact_regional_fixture_v1.json"
)
const CHUNK_SIZE_METERS := 0.064
const PROCESSING_HALO_CHUNK_RINGS := 2
const CANONICAL_FLOAT_FORMAT := "%.9f"
const FIXED_TIMESTAMP := 1786752000.0
const MATERIAL_ID := &"mat_iron_gray"

const STROKE_A_PROFILE_POINT_COUNT := 29
const STROKE_A_PATH_POINT_COUNT := 25
const STROKE_A_ROTATION_BIAS_DEGREES := 17.0
const STROKE_A_ANCHOR_CLEARANCE_METERS := 0.00075

const STROKE_B_PROFILE_POINT_COUNT := 19
const STROKE_B_PATH_POINT_COUNT := 9
const STROKE_B_ROTATION_BIAS_DEGREES := -11.0
const STROKE_B_ANCHOR_CLEARANCE_METERS := 0.001
const STROKE_B_OUTWARD_OFFSET_METERS := 0.010
const STROKE_B_A_SAMPLE_FROM := 2.5
const STROKE_B_A_SAMPLE_TO := 7.0

const MATURE_EXTENSION_LENGTH_METERS := 2.304
const MATURE_EXTENSION_SAMPLE_COUNT := 145
const MATURE_EXTENSION_A_OVERLAP_SAMPLE_FROM := 22
const REQUIRED_REMOTE_X_CHUNK_COUNT := 32

var exporter_errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()

	var stroke_a_profile := _build_profile_spec(
		"stroke_a_asymmetric_fourier_29",
		_build_stroke_a_base_profile(),
		STROKE_A_ANCHOR_CLEARANCE_METERS,
		STROKE_A_ROTATION_BIAS_DEGREES
	)
	var stroke_a_path := _build_stroke_a_path()
	var stroke_a_body := _build_body(
		&"exact_regional_stroke_a",
		stroke_a_profile,
		stroke_a_path,
		1
	)
	var stroke_a_packet := _build_packet(
		"stroke_a",
		"young_primary_exact_sweep",
		stroke_a_body,
		stroke_a_profile,
		presenter
	)

	var stroke_b_profile := _build_profile_spec(
		"stroke_b_asymmetric_analytic_19",
		_build_stroke_b_base_profile(),
		STROKE_B_ANCHOR_CLEARANCE_METERS,
		STROKE_B_ROTATION_BIAS_DEGREES
	)
	var stroke_b_path := _build_stroke_b_path()
	var stroke_b_body := _build_body(
		&"exact_regional_stroke_b",
		stroke_b_profile,
		stroke_b_path,
		2
	)
	var stroke_b_packet := _build_packet(
		"stroke_b",
		"localized_overlapping_analytic_edit",
		stroke_b_body,
		stroke_b_profile,
		presenter
	)

	var mature_extension_path := _build_mature_extension_path(stroke_a_path)
	var mature_extension_body := _build_body(
		&"exact_regional_mature_extension",
		stroke_a_profile,
		mature_extension_path,
		3
	)
	var mature_extension_packet := _build_packet(
		"mature_extension",
		"positive_endpoint_connected_remote_extension",
		mature_extension_body,
		stroke_a_profile,
		presenter
	)

	_validate_locality_layout(
		stroke_a_packet,
		stroke_b_packet,
		mature_extension_packet
	)
	if not exporter_errors.is_empty():
		_finish_failure()
		return

	var packet_hash_inputs := PackedStringArray([
		"stroke_a=%s" % String(stroke_a_packet.get(
			"canonical_sha256",
			""
		)),
		"stroke_b=%s" % String(stroke_b_packet.get(
			"canonical_sha256",
			""
		)),
		"mature_extension=%s" % String(mature_extension_packet.get(
			"canonical_sha256",
			""
		)),
	])
	var fixture_hash := "\n".join(packet_hash_inputs).sha256_text()
	var payload := {
		"schema": FIXTURE_SCHEMA,
		"schema_version": FIXTURE_SCHEMA_VERSION,
		"fixture_id": FIXTURE_ID,
		"coordinate_units": "meters",
		"chunk_size_meters": CHUNK_SIZE_METERS,
		"processing_halo_chunk_rings": PROCESSING_HALO_CHUNK_RINGS,
		"canonicalization": {
			"algorithm": "sha256",
			"encoding": "utf-8",
			"line_separator": "\\n",
			"float_format": CANONICAL_FLOAT_FORMAT,
			"triangle_winding": (
				"forge_array_mesh_emitted_index_order"
			),
		},
		"fixture_design": {
			"stroke_b_is_on_negative_x_side": true,
			"mature_extension_attaches_at_positive_x_endpoint": true,
			"required_remote_x_chunk_count": (
				REQUIRED_REMOTE_X_CHUNK_COUNT
			),
			"locality_separation_rule": (
				"max_stroke_b_x_chunk_plus_halo_less_than_"
				+ "min_mature_extension_x_chunk"
			),
		},
		"packets": {
			"stroke_a": stroke_a_packet,
			"stroke_b": stroke_b_packet,
			"mature_extension": mature_extension_packet,
		},
		"canonical_sha256_inputs": Array(packet_hash_inputs),
		"canonical_sha256": fixture_hash,
	}
	var serialized := JSON.stringify(payload, "\t", true, true) + "\n"
	var result_file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if result_file == null:
		_record_error("could not open fixture output: %s" % RESULT_PATH)
		_finish_failure()
		return
	result_file.store_string(serialized)
	result_file.close()
	if not FileAccess.file_exists(RESULT_PATH):
		_record_error("fixture output was not created")
		_finish_failure()
		return
	print(
		"Forge V2 exact regional fixture exported: %s hash=%s"
		% [RESULT_PATH, fixture_hash]
	)
	for packet_name: String in ["stroke_a", "stroke_b", "mature_extension"]:
		var packet := payload["packets"][packet_name] as Dictionary
		print(
			"%s vertices=%d triangles=%d surfaces=%d x_chunks=%d"
			% [
				packet_name,
				(packet.get("vertices", []) as Array).size(),
				(packet.get("triangles", []) as Array).size(),
				(packet.get("surfaces", []) as Array).size(),
				(packet.get("covered_x_chunk_indices", []) as Array).size(),
			]
		)
	stroke_a_body = null
	stroke_b_body = null
	mature_extension_body = null
	presenter.free()
	presenter = null
	quit(0)


func _build_stroke_a_base_profile() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point_index in range(STROKE_A_PROFILE_POINT_COUNT):
		var theta := (
			TAU * float(point_index) / float(STROKE_A_PROFILE_POINT_COUNT)
		)
		var radial_bias := (
			1.0
			+ 0.11 * sin(theta)
			+ 0.07 * cos(2.0 * theta)
			+ 0.035 * sin(5.0 * theta)
		)
		polygon.append(Vector2(
			0.018 * radial_bias * cos(theta) + 0.0015 * sin(3.0 * theta),
			(
				0.013
				* (1.0 + 0.08 * cos(theta) - 0.04 * sin(4.0 * theta))
				* sin(theta)
			)
		))
	return _ensure_counter_clockwise(polygon)


func _build_stroke_b_base_profile() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point_index in range(STROKE_B_PROFILE_POINT_COUNT):
		var theta := (
			TAU * float(point_index) / float(STROKE_B_PROFILE_POINT_COUNT)
		)
		var radial_bias := (
			1.0
			+ 0.08 * sin(theta)
			+ 0.045 * cos(3.0 * theta)
			+ 0.025 * sin(5.0 * theta)
		)
		polygon.append(Vector2(
			0.008 * radial_bias * cos(theta) + 0.0005 * sin(2.0 * theta),
			(
				0.014
				* (1.0 + 0.05 * cos(theta) - 0.035 * sin(3.0 * theta))
				* sin(theta)
			)
		))
	return _ensure_counter_clockwise(polygon)


func _build_profile_spec(
	profile_id: String,
	base_polygon: PackedVector2Array,
	anchor_clearance_meters: float,
	rotation_bias_degrees: float
) -> Dictionary:
	if base_polygon.size() < 3:
		_record_error("%s profile has fewer than three points" % profile_id)
		return {}
	var clearance_result := (
		ForgeV2ProfileShapeLibraryScript.
			constrain_point_inside_polygon_with_clearance(
				Vector2(0.0, -1.0),
				base_polygon,
				anchor_clearance_meters
			)
	)
	if not bool(clearance_result.get("valid", false)):
		_record_error("%s anchor clearance could not be resolved" % profile_id)
		return {}
	var anchor := clearance_result.get("point", Vector2.ZERO) as Vector2
	var contact_result := (
		ForgeV2ProfileShapeLibraryScript.resolve_profile_anchor_contact(
			base_polygon,
			anchor
		)
	)
	if not bool(contact_result.get("valid", false)):
		_record_error("%s anchor contact could not be resolved" % profile_id)
		return {}
	var contact_point := contact_result.get("point", anchor) as Vector2
	var contact_relative := contact_point - anchor
	var contact_distance := float(contact_result.get("distance_meters", 0.0))
	if contact_distance + 0.0000001 < anchor_clearance_meters:
		_record_error("%s resolved anchor violates requested clearance" % profile_id)
	var deposition_polygon := PackedVector2Array()
	for profile_point: Vector2 in base_polygon:
		deposition_polygon.append(profile_point - anchor)
	return {
		"profile_id": profile_id,
		"base_polygon": base_polygon,
		"deposition_polygon": deposition_polygon,
		"anchor": anchor,
		"anchor_clearance_meters": anchor_clearance_meters,
		"contact_point": contact_point,
		"contact_point_relative": contact_relative,
		"contact_direction": contact_result.get(
			"direction",
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
		) as Vector2,
		"contact_distance_meters": contact_distance,
		"rotation_bias_degrees": rotation_bias_degrees,
	}


func _build_stroke_a_path() -> Dictionary:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for point_index in range(STROKE_A_PATH_POINT_COUNT):
		var ratio := float(point_index) / float(STROKE_A_PATH_POINT_COUNT - 1)
		var sample := _sample_stroke_a(ratio)
		points.append(sample.get("point", Vector3.ZERO) as Vector3)
		normals.append(sample.get("normal", Vector3.UP) as Vector3)
		contacts.append(sample.get("contact", Vector3.DOWN) as Vector3)
	return {
		"points": points,
		"normals": normals,
		"contacts": contacts,
		"analytic_definition": (
			"u=i/24;t=2u-1;P=(-0.176+0.352u,"
			+ "0.018sin(1.35PI*t)+0.006sin(3.1PI*t),"
			+ "0.012cos(0.9PI*t)+0.007sin(2.2PI*t));"
			+ "N=normalize((0.38+0.10sin(1.3PI*t),"
			+ "0.46+0.10cos(1.7PI*t),"
			+ "0.68+0.08sin(0.9PI*t)));BC=-N"
		),
	}


func _sample_stroke_a(ratio: float) -> Dictionary:
	var resolved_ratio := clampf(ratio, 0.0, 1.0)
	var t := 2.0 * resolved_ratio - 1.0
	var point := Vector3(
		-0.176 + 0.352 * resolved_ratio,
		0.018 * sin(1.35 * PI * t) + 0.006 * sin(3.1 * PI * t),
		0.012 * cos(0.9 * PI * t) + 0.007 * sin(2.2 * PI * t)
	)
	var normal := Vector3(
		0.38 + 0.10 * sin(1.3 * PI * t),
		0.46 + 0.10 * cos(1.7 * PI * t),
		0.68 + 0.08 * sin(0.9 * PI * t)
	).normalized()
	return {
		"point": point,
		"normal": normal,
		"contact": -normal,
	}


func _build_stroke_b_path() -> Dictionary:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for point_index in range(STROKE_B_PATH_POINT_COUNT):
		var sample_position := lerpf(
			STROKE_B_A_SAMPLE_FROM,
			STROKE_B_A_SAMPLE_TO,
			float(point_index) / float(STROKE_B_PATH_POINT_COUNT - 1)
		)
		var sample := _sample_stroke_a(
			sample_position / float(STROKE_A_PATH_POINT_COUNT - 1)
		)
		var normal := sample.get("normal", Vector3.UP) as Vector3
		points.append(
			(sample.get("point", Vector3.ZERO) as Vector3)
			+ normal * STROKE_B_OUTWARD_OFFSET_METERS
		)
		normals.append(normal)
		contacts.append(-normal)
	return {
		"points": points,
		"normals": normals,
		"contacts": contacts,
		"analytic_definition": (
			"nine analytic samples of stroke_a from sample 2.5 through 7.0;"
			+ "P_b=P_a+N_a*0.010;N_b=N_a;BC_b=-N_a"
		),
	}


func _build_mature_extension_path(stroke_a_path: Dictionary) -> Dictionary:
	var stroke_a_points: PackedVector3Array = stroke_a_path.get(
		"points",
		PackedVector3Array()
	)
	var stroke_a_normals: PackedVector3Array = stroke_a_path.get(
		"normals",
		PackedVector3Array()
	)
	var stroke_a_contacts: PackedVector3Array = stroke_a_path.get(
		"contacts",
		PackedVector3Array()
	)
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for source_index in range(
		MATURE_EXTENSION_A_OVERLAP_SAMPLE_FROM,
		stroke_a_points.size()
	):
		points.append(stroke_a_points[source_index])
		normals.append(stroke_a_normals[source_index])
		contacts.append(stroke_a_contacts[source_index])
	var endpoint := stroke_a_points[stroke_a_points.size() - 1]
	var endpoint_normal := stroke_a_normals[stroke_a_normals.size() - 1]
	for extension_index in range(1, MATURE_EXTENSION_SAMPLE_COUNT):
		var ratio := (
			float(extension_index)
			/ float(MATURE_EXTENSION_SAMPLE_COUNT - 1)
		)
		var point := Vector3(
			endpoint.x + MATURE_EXTENSION_LENGTH_METERS * ratio,
			endpoint.y + 0.010 * sin(TAU * 2.0 * ratio),
			endpoint.z + 0.008 * sin(TAU * 3.0 * ratio)
		)
		var normal := Vector3(
			endpoint_normal.x + 0.035 * sin(TAU * ratio),
			endpoint_normal.y + 0.030 * sin(TAU * 1.5 * ratio),
			endpoint_normal.z + 0.025 * (cos(TAU * ratio) - 1.0)
		).normalized()
		points.append(point)
		normals.append(normal)
		contacts.append(-normal)
	return {
		"points": points,
		"normals": normals,
		"contacts": contacts,
		"analytic_definition": (
			"stroke_a samples 22..24 followed by 144 positive-X samples "
			+ "over 2.304m with bounded Y/Z curvature;BC=-N"
		),
	}


func _build_body(
	body_id: StringName,
	profile: Dictionary,
	path: Dictionary,
	serial_index: int
) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_id", body_id)
	body.set("source_record_id", StringName("%s_source" % String(body_id)))
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE)
	body.set("material_variant_id", MATERIAL_ID)
	body.set(
		"operation_mode",
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
	)
	body.set(
		"placement_policy",
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	body.set("shape_kind", ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
	body.set("path_points", path.get("points", PackedVector3Array()))
	body.set(
		"path_surface_normals",
		path.get("normals", PackedVector3Array())
	)
	body.set(
		"path_contact_directions",
		path.get("contacts", PackedVector3Array())
	)
	body.set("profile_id", StringName(String(profile.get("profile_id", ""))))
	body.set("profile_display_name", String(profile.get("profile_id", "")))
	body.set(
		"profile_polygon_2d_meters",
		profile.get("deposition_polygon", PackedVector2Array())
	)
	body.set("profile_anchor_2d_meters", profile.get("anchor", Vector2.ZERO))
	body.set(
		"profile_contact_point_relative_2d_meters",
		profile.get("contact_point_relative", Vector2.ZERO)
	)
	body.set(
		"profile_contact_direction_2d",
		profile.get(
			"contact_direction",
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
		)
	)
	body.set(
		"profile_contact_distance_meters",
		float(profile.get("contact_distance_meters", 0.0))
	)
	body.set("profile_runtime_schema_version", 1)
	body.set(
		"profile_rotation_bias_degrees",
		float(profile.get("rotation_bias_degrees", 0.0))
	)
	body.set("profile_twist_degrees_per_meter", 0.0)
	body.set("created_timestamp", FIXED_TIMESTAMP + float(serial_index))
	body.set("updated_timestamp", FIXED_TIMESTAMP + float(serial_index))
	body.call("normalize")
	body.set("body_id", body_id)
	body.set("source_record_id", StringName("%s_source" % String(body_id)))
	body.set("created_timestamp", FIXED_TIMESTAMP + float(serial_index))
	body.set("updated_timestamp", FIXED_TIMESTAMP + float(serial_index))
	return body


func _build_packet(
	packet_name: String,
	role: String,
	body: Resource,
	profile: Dictionary,
	presenter: Node3D
) -> Dictionary:
	if body == null or presenter == null:
		_record_error("%s body or presenter was unavailable" % packet_name)
		return {}
	var mesh := presenter.call(
		"_build_active_material_body_sweep_mesh",
		body
	) as ArrayMesh
	if mesh == null:
		_record_error("%s exact Forge sweep returned null" % packet_name)
		return {}
	var analysis: Dictionary = (
		ForgeV2WorkpieceBenchmarkMeshAnalyzerScript.analyze_mesh(mesh)
	)
	if int(analysis.get("surface_count", 0)) <= 0:
		_record_error("%s mesh analyzer found no surfaces" % packet_name)
	if int(analysis.get("triangle_count", 0)) <= 0:
		_record_error("%s mesh analyzer found no triangles" % packet_name)
	if int(analysis.get("emitted_vertex_count", 0)) <= 0:
		_record_error("%s mesh analyzer found no vertices" % packet_name)
	if int(analysis.get("nonfinite_vertex_count", 0)) != 0:
		_record_error("%s mesh analyzer found non-finite vertices" % packet_name)

	var extracted := _extract_indexed_triangle_packet(mesh, packet_name)
	var vertices := extracted.get("vertices", []) as Array
	var triangles := extracted.get("triangles", []) as Array
	var surfaces := extracted.get("surfaces", []) as Array
	if vertices.is_empty() or triangles.is_empty():
		_record_error("%s indexed packet was empty" % packet_name)
	var bounds := _calculate_bounds(vertices)
	var covered_chunks := _enumerate_bounds_chunks(bounds)
	var covered_x_chunks := _collect_sorted_x_chunk_indices(covered_chunks)
	var profile_metadata := _build_profile_metadata(profile)
	var path_metadata := _build_path_metadata(body)
	var body_metadata := _build_body_metadata(body)
	var packet := {
		"packet_schema_version": PACKET_SCHEMA_VERSION,
		"packet_name": packet_name,
		"role": role,
		"coordinate_units": "meters",
		"indexed": true,
		"triangle_winding": "forge_array_mesh_emitted_index_order",
		"body": body_metadata,
		"profile": profile_metadata,
		"path": path_metadata,
		"vertices": vertices,
		"triangles": triangles,
		"surfaces": surfaces,
		"bounds": bounds,
		"covered_chunk_coordinates": covered_chunks,
		"covered_x_chunk_indices": covered_x_chunks,
		"analysis": _sanitize_analysis(analysis),
	}
	var canonical_inputs := _build_packet_canonical_inputs(packet)
	packet["canonical_sha256_inputs"] = Array(canonical_inputs)
	packet["canonical_sha256"] = "\n".join(canonical_inputs).sha256_text()
	return packet


func _extract_indexed_triangle_packet(
	mesh: ArrayMesh,
	packet_name: String
) -> Dictionary:
	var packet_vertices: Array = []
	var packet_triangles: Array = []
	var packet_surfaces: Array = []
	for surface_index in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			_record_error(
				"%s surface %d is not triangles" % [packet_name, surface_index]
			)
			continue
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			_record_error(
				"%s surface %d has no vertex slot" % [packet_name, surface_index]
			)
			continue
		var local_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var local_indices := PackedInt32Array()
		if (
			arrays.size() > Mesh.ARRAY_INDEX
			and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array
		):
			local_indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var vertex_offset := packet_vertices.size()
		for vertex: Vector3 in local_vertices:
			if not vertex.is_finite():
				_record_error(
					"%s surface %d contains non-finite vertex"
					% [packet_name, surface_index]
				)
			packet_vertices.append(_vector3_array(vertex))
		var source_count := (
			local_indices.size()
			if not local_indices.is_empty()
			else local_vertices.size()
		)
		if source_count % 3 != 0:
			_record_error(
				"%s surface %d index count is not divisible by three"
				% [packet_name, surface_index]
			)
		for source_index in range(0, source_count - 2, 3):
			var index_a := (
				local_indices[source_index]
				if not local_indices.is_empty()
				else source_index
			)
			var index_b := (
				local_indices[source_index + 1]
				if not local_indices.is_empty()
				else source_index + 1
			)
			var index_c := (
				local_indices[source_index + 2]
				if not local_indices.is_empty()
				else source_index + 2
			)
			if (
				index_a < 0
				or index_b < 0
				or index_c < 0
				or index_a >= local_vertices.size()
				or index_b >= local_vertices.size()
				or index_c >= local_vertices.size()
			):
				_record_error(
					"%s surface %d contains an invalid triangle index"
					% [packet_name, surface_index]
				)
				continue
			packet_triangles.append({
				"indices": [
					vertex_offset + index_a,
					vertex_offset + index_b,
					vertex_offset + index_c,
				],
				"surface_index": surface_index,
				"material_index": 0,
			})
		packet_surfaces.append({
			"surface_index": surface_index,
			"material_index": 0,
			"material_id": String(MATERIAL_ID),
			"source_vertex_count": local_vertices.size(),
			"source_index_count": source_count,
		})
	return {
		"vertices": packet_vertices,
		"triangles": packet_triangles,
		"surfaces": packet_surfaces,
	}


func _build_body_metadata(body: Resource) -> Dictionary:
	return {
		"body_id": String(body.get("body_id")),
		"body_kind": String(body.get("body_kind")),
		"source_record_id": String(body.get("source_record_id")),
		"material_variant_id": String(body.get("material_variant_id")),
		"operation_mode": String(body.get("operation_mode")),
		"placement_policy": String(body.get("placement_policy")),
		"shape_kind": String(body.get("shape_kind")),
		"profile_runtime_schema_version": int(body.get(
			"profile_runtime_schema_version"
		)),
		"profile_rotation_bias_degrees": float(body.get(
			"profile_rotation_bias_degrees"
		)),
		"profile_twist_degrees_per_meter": float(body.get(
			"profile_twist_degrees_per_meter"
		)),
		"radius_meters": float(body.get("radius_meters")),
	}


func _build_profile_metadata(profile: Dictionary) -> Dictionary:
	return {
		"profile_id": String(profile.get("profile_id", "")),
		"base_polygon_2d_meters": _vector2_array_list(
			profile.get("base_polygon", PackedVector2Array())
		),
		"deposition_polygon_2d_meters": _vector2_array_list(
			profile.get("deposition_polygon", PackedVector2Array())
		),
		"anchor_2d_meters": _vector2_array(
			profile.get("anchor", Vector2.ZERO) as Vector2
		),
		"anchor_clearance_meters": float(profile.get(
			"anchor_clearance_meters",
			0.0
		)),
		"contact_point_2d_meters": _vector2_array(
			profile.get("contact_point", Vector2.ZERO) as Vector2
		),
		"contact_point_relative_2d_meters": _vector2_array(
			profile.get("contact_point_relative", Vector2.ZERO) as Vector2
		),
		"contact_direction_2d": _vector2_array(
			profile.get(
				"contact_direction",
				ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
			) as Vector2
		),
		"contact_distance_meters": float(profile.get(
			"contact_distance_meters",
			0.0
		)),
		"rotation_bias_degrees": float(profile.get(
			"rotation_bias_degrees",
			0.0
		)),
	}


func _build_path_metadata(body: Resource) -> Dictionary:
	var points: PackedVector3Array = body.get("path_points")
	var normals: PackedVector3Array = body.get("path_surface_normals")
	var contacts: PackedVector3Array = body.get("path_contact_directions")
	return {
		"sample_count": points.size(),
		"points": _vector3_array_list(points),
		"surface_normals": _vector3_array_list(normals),
		"contact_directions_bc": _vector3_array_list(contacts),
		"bc_rule": "contact_direction_bc_equals_negative_surface_normal",
	}


func _sanitize_analysis(analysis: Dictionary) -> Dictionary:
	var sanitized := {}
	for key: String in [
		"mesh_count",
		"surface_count",
		"emitted_vertex_count",
		"welded_vertex_count",
		"index_count",
		"triangle_count",
		"degenerate_triangle_count",
		"nonfinite_vertex_count",
		"signed_volume_cubic_meters",
		"absolute_volume_cubic_meters",
		"signed_volume_sign",
		"aabb_position_x",
		"aabb_position_y",
		"aabb_position_z",
		"aabb_size_x",
		"aabb_size_y",
		"aabb_size_z",
		"geometry_signature_unoriented",
		"geometry_signature_oriented",
		"watertight",
		"component_count",
		"boundary_edge_count",
		"nonmanifold_edge_count",
		"directed_edge_mismatch_count",
		"edge_count",
		"euler_characteristic",
		"genus",
		"strict_topology_weld_tolerance_meters",
		"strict_welded_vertex_count",
		"strict_triangle_count",
		"strict_degenerate_triangle_collapse_count",
		"strict_watertight",
		"strict_component_count",
		"strict_boundary_edge_count",
		"strict_nonmanifold_edge_count",
		"strict_directed_edge_mismatch_count",
		"strict_edge_count",
		"strict_euler_characteristic",
		"strict_genus",
	]:
		if analysis.has(key):
			sanitized[key] = analysis[key]
	return sanitized


func _calculate_bounds(vertices: Array) -> Dictionary:
	if vertices.is_empty():
		return {
			"min": [0.0, 0.0, 0.0],
			"max": [0.0, 0.0, 0.0],
			"position": [0.0, 0.0, 0.0],
			"size": [0.0, 0.0, 0.0],
		}
	var first := vertices[0] as Array
	var minimum := Vector3(float(first[0]), float(first[1]), float(first[2]))
	var maximum := minimum
	for vertex_variant: Variant in vertices:
		var vertex_array := vertex_variant as Array
		var vertex := Vector3(
			float(vertex_array[0]),
			float(vertex_array[1]),
			float(vertex_array[2])
		)
		minimum.x = minf(minimum.x, vertex.x)
		minimum.y = minf(minimum.y, vertex.y)
		minimum.z = minf(minimum.z, vertex.z)
		maximum.x = maxf(maximum.x, vertex.x)
		maximum.y = maxf(maximum.y, vertex.y)
		maximum.z = maxf(maximum.z, vertex.z)
	return {
		"min": _vector3_array(minimum),
		"max": _vector3_array(maximum),
		"position": _vector3_array(minimum),
		"size": _vector3_array(maximum - minimum),
	}


func _enumerate_bounds_chunks(bounds: Dictionary) -> Array:
	var minimum_values := bounds.get("min", [0.0, 0.0, 0.0]) as Array
	var maximum_values := bounds.get("max", [0.0, 0.0, 0.0]) as Array
	var minimum := Vector3(
		float(minimum_values[0]),
		float(minimum_values[1]),
		float(minimum_values[2])
	)
	var maximum := Vector3(
		float(maximum_values[0]),
		float(maximum_values[1]),
		float(maximum_values[2])
	)
	var minimum_chunk := Vector3i(
		floori(minimum.x / CHUNK_SIZE_METERS),
		floori(minimum.y / CHUNK_SIZE_METERS),
		floori(minimum.z / CHUNK_SIZE_METERS)
	)
	var maximum_chunk := Vector3i(
		floori(maximum.x / CHUNK_SIZE_METERS),
		floori(maximum.y / CHUNK_SIZE_METERS),
		floori(maximum.z / CHUNK_SIZE_METERS)
	)
	var chunks: Array = []
	for chunk_x in range(minimum_chunk.x, maximum_chunk.x + 1):
		for chunk_y in range(minimum_chunk.y, maximum_chunk.y + 1):
			for chunk_z in range(minimum_chunk.z, maximum_chunk.z + 1):
				chunks.append([chunk_x, chunk_y, chunk_z])
	return chunks


func _collect_sorted_x_chunk_indices(chunks: Array) -> Array:
	var unique_x := {}
	for chunk_variant: Variant in chunks:
		var chunk := chunk_variant as Array
		unique_x[int(chunk[0])] = true
	var indices := unique_x.keys()
	indices.sort()
	return indices


func _validate_locality_layout(
	stroke_a: Dictionary,
	stroke_b: Dictionary,
	mature_extension: Dictionary
) -> void:
	var stroke_a_x := stroke_a.get("covered_x_chunk_indices", []) as Array
	var stroke_b_x := stroke_b.get("covered_x_chunk_indices", []) as Array
	var extension_x := mature_extension.get(
		"covered_x_chunk_indices",
		[]
	) as Array
	if stroke_a_x.is_empty() or stroke_b_x.is_empty() or extension_x.is_empty():
		_record_error("locality layout did not produce X chunk coverage")
		return
	var stroke_b_max_x_chunk := int(stroke_b_x[stroke_b_x.size() - 1])
	var extension_min_x_chunk := int(extension_x[0])
	if (
		stroke_b_max_x_chunk + PROCESSING_HALO_CHUNK_RINGS
		>= extension_min_x_chunk
	):
		_record_error(
			"stroke_b two-ring locality overlaps mature extension: %d + %d >= %d"
			% [
				stroke_b_max_x_chunk,
				PROCESSING_HALO_CHUNK_RINGS,
				extension_min_x_chunk,
			]
		)
	var stroke_a_x_lookup := {}
	for chunk_index: Variant in stroke_a_x:
		stroke_a_x_lookup[int(chunk_index)] = true
	var remote_x_chunks: Array = []
	for chunk_index: Variant in extension_x:
		if not stroke_a_x_lookup.has(int(chunk_index)):
			remote_x_chunks.append(int(chunk_index))
	mature_extension["remote_x_chunk_indices_relative_to_stroke_a"] = (
		remote_x_chunks
	)
	mature_extension["remote_x_chunk_count_relative_to_stroke_a"] = (
		remote_x_chunks.size()
	)
	mature_extension["locality_separation"] = {
		"stroke_b_max_x_chunk": stroke_b_max_x_chunk,
		"processing_halo_chunk_rings": PROCESSING_HALO_CHUNK_RINGS,
		"mature_extension_min_x_chunk": extension_min_x_chunk,
		"separated": (
			stroke_b_max_x_chunk + PROCESSING_HALO_CHUNK_RINGS
			< extension_min_x_chunk
		),
	}
	if remote_x_chunks.size() < REQUIRED_REMOTE_X_CHUNK_COUNT:
		_record_error(
			"mature extension reached only %d remote X chunks; required %d"
			% [remote_x_chunks.size(), REQUIRED_REMOTE_X_CHUNK_COUNT]
		)
	var stroke_a_bounds := stroke_a.get("bounds", {}) as Dictionary
	var extension_bounds := mature_extension.get("bounds", {}) as Dictionary
	var stroke_a_max_values := stroke_a_bounds.get("max", []) as Array
	var extension_min_values := extension_bounds.get("min", []) as Array
	if stroke_a_max_values.is_empty() or extension_min_values.is_empty():
		_record_error("stroke A or extension bounds were unavailable")
	elif float(extension_min_values[0]) > float(stroke_a_max_values[0]) + 0.000001:
		_record_error("mature extension does not overlap stroke A positive endpoint")


func _build_packet_canonical_inputs(packet: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray([
		"packet_schema_version=%d" % PACKET_SCHEMA_VERSION,
		"packet_name=%s" % String(packet.get("packet_name", "")),
		"role=%s" % String(packet.get("role", "")),
		"coordinate_units=meters",
		"chunk_size_meters=%s" % _canonical_float(CHUNK_SIZE_METERS),
	])
	var body := packet.get("body", {}) as Dictionary
	for key: String in [
		"body_id",
		"body_kind",
		"source_record_id",
		"material_variant_id",
		"operation_mode",
		"placement_policy",
		"shape_kind",
		"profile_runtime_schema_version",
		"profile_rotation_bias_degrees",
		"profile_twist_degrees_per_meter",
		"radius_meters",
	]:
		lines.append("body.%s=%s" % [key, _canonical_variant(body.get(key))])
	var profile := packet.get("profile", {}) as Dictionary
	for key: String in [
		"profile_id",
		"anchor_clearance_meters",
		"contact_distance_meters",
		"rotation_bias_degrees",
	]:
		lines.append(
			"profile.%s=%s" % [key, _canonical_variant(profile.get(key))]
		)
	for key: String in [
		"anchor_2d_meters",
		"contact_point_2d_meters",
		"contact_point_relative_2d_meters",
		"contact_direction_2d",
	]:
		lines.append(
			"profile.%s=%s" % [key, _canonical_number_array(
				profile.get(key, []) as Array
			)]
		)
	for key: String in [
		"base_polygon_2d_meters",
		"deposition_polygon_2d_meters",
	]:
		var polygon := profile.get(key, []) as Array
		for point_index in range(polygon.size()):
			lines.append(
				"profile.%s[%d]=%s"
				% [
					key,
					point_index,
					_canonical_number_array(polygon[point_index] as Array),
				]
			)
	var path := packet.get("path", {}) as Dictionary
	for key: String in ["points", "surface_normals", "contact_directions_bc"]:
		var samples := path.get(key, []) as Array
		for sample_index in range(samples.size()):
			lines.append(
				"path.%s[%d]=%s"
				% [
					key,
					sample_index,
					_canonical_number_array(samples[sample_index] as Array),
				]
			)
	var vertices := packet.get("vertices", []) as Array
	for vertex_index in range(vertices.size()):
		lines.append(
			"vertex[%d]=%s"
			% [
				vertex_index,
				_canonical_number_array(vertices[vertex_index] as Array),
			]
		)
	var triangles := packet.get("triangles", []) as Array
	for triangle_index in range(triangles.size()):
		var triangle := triangles[triangle_index] as Dictionary
		var indices := triangle.get("indices", []) as Array
		lines.append(
			"triangle[%d]=%d,%d,%d;s=%d;m=%d"
			% [
				triangle_index,
				int(indices[0]),
				int(indices[1]),
				int(indices[2]),
				int(triangle.get("surface_index", -1)),
				int(triangle.get("material_index", -1)),
			]
		)
	var bounds := packet.get("bounds", {}) as Dictionary
	for key: String in ["min", "max", "position", "size"]:
		lines.append(
			"bounds.%s=%s" % [key, _canonical_number_array(
				bounds.get(key, []) as Array
			)]
		)
	return lines


func _canonical_variant(value: Variant) -> String:
	if value is float:
		return _canonical_float(float(value))
	return str(value)


func _canonical_number_array(values: Array) -> String:
	var parts := PackedStringArray()
	for value: Variant in values:
		parts.append(_canonical_float(float(value)))
	return ",".join(parts)


func _canonical_float(value: float) -> String:
	return CANONICAL_FLOAT_FORMAT % value


func _vector2_array(value: Vector2) -> Array:
	return [value.x, value.y]


func _vector3_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _vector2_array_list(values: PackedVector2Array) -> Array:
	var output: Array = []
	for value: Vector2 in values:
		output.append(_vector2_array(value))
	return output


func _vector3_array_list(values: PackedVector3Array) -> Array:
	var output: Array = []
	for value: Vector3 in values:
		output.append(_vector3_array(value))
	return output


func _ensure_counter_clockwise(polygon: PackedVector2Array) -> PackedVector2Array:
	var signed_area_twice := 0.0
	for point_index in range(polygon.size()):
		signed_area_twice += polygon[point_index].cross(
			polygon[(point_index + 1) % polygon.size()]
		)
	if signed_area_twice >= 0.0:
		return polygon
	var reversed_polygon := PackedVector2Array()
	for point_index in range(polygon.size() - 1, -1, -1):
		reversed_polygon.append(polygon[point_index])
	return reversed_polygon


func _record_error(message: String) -> void:
	exporter_errors.append(message)
	push_error(message)


func _finish_failure() -> void:
	for message: String in exporter_errors:
		printerr("fixture_export_error=%s" % message)
	quit(1)
