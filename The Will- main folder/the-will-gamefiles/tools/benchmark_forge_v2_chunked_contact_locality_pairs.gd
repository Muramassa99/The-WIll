extends SceneTree

const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)
const ChunkedBackendScript = preload(
	"res://tools/forge_v2_chunked_labelled_solid_backend.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)

const BENCHMARK_ID := &"forge_v2_chunked_contact_locality_pairs_v1"
const BENCHMARK_SCHEMA_VERSION := 1
const RESULT_PREFIX := (
	"C:/WORKSPACE/godot_runs/forge_v2_chunked_contact_locality_pairs"
)
const MATERIAL_ID := &"mat_iron_gray"
const CELL_SIZE_METERS := 0.004
const CHUNK_CELL_COUNT := 16
const CHUNK_SIZE_METERS := CELL_SIZE_METERS * float(CHUNK_CELL_COUNT)
const PROCESSING_HALO_CHUNK_RINGS := 2
const DEFAULT_PROBE_COUNT := 8
const MAX_PROBE_COUNT := 64
const DEFAULT_MATURE_EXTENSION_COUNT := 32
const MAX_MATURE_EXTENSION_COUNT := 256
const STATION_SPACING_CHUNKS := 8
const LOCAL_RAIL_BUFFER_CHUNKS := 4
const MATURE_EXTENSION_LENGTH_CHUNKS := 8
const PROFILE_HALF_SIZE_METERS := 0.008
const RAIL_Y_METERS := 0.032
const RAIL_Z_METERS := 0.032
const FIRST_STATION_X_METERS := 0.032
const PROBE_LENGTH_METERS := 0.048
const FIXED_TIMESTAMP := 1700000000.0
const DEBUG_COORDINATE_FIELDS := [
	"candidate_chunk_coords",
	"contact_chunk_coords",
	"processing_context_chunk_coords",
	"resident_context_chunk_coords",
	"changed_chunk_coords",
	"remeshed_chunk_coords",
]
const LOCAL_COUNTER_FIELDS := [
	"world_aabb_cell_count",
	"examined_cell_count",
	"centerline_chunk_count",
	"broadphase_chunk_count",
	"intersecting_chunk_count",
	"candidate_cell_count",
	"candidate_chunk_count",
	"candidate_component_count",
	"attached_component_count",
	"overlap_cell_count",
	"face_attachment_count",
	"contact_cell_count",
	"contact_chunk_count",
	"new_only_chunk_count",
	"processing_context_chunk_count",
	"resident_context_chunk_count",
	"changed_cell_count",
	"changed_chunk_count",
	"remeshed_chunk_count",
	"remesh_scanned_cell_count",
	"remeshed_occupied_cell_count",
	"remeshed_occupied_cell_min",
	"remeshed_occupied_cell_max",
	"rebuilt_quad_count",
	"rebuilt_vertex_count",
	"rebuilt_index_count",
]
const TIMING_FIELDS := [
	"total_ms",
	"backend_entry_to_exit_ms",
	"apply_wall_ms",
	"validation_ms",
	"raster_ms",
	"attachment_ms",
	"context_build_ms",
	"update_ms",
	"remesh_ms",
]

var errors: Array[String] = []
var raw_rows: Array[Dictionary] = []
var probe_count := DEFAULT_PROBE_COUNT
var mature_extension_count := DEFAULT_MATURE_EXTENSION_COUNT
var run_mesh_analysis := true
var run_id := ""
var result_base_path := ""
var maturity_construction_elapsed_ms := 0.0
var station_chunk_offsets := PackedInt32Array()
var young_total_times_ms: Array[float] = []
var mature_total_times_ms: Array[float] = []
var paired_total_deltas_ms: Array[float] = []
var paired_total_ratios: Array[float] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PREFIX.get_base_dir())
	probe_count = _read_environment_int(
		"FORGE_V2_PAIRED_LOCALITY_PROBE_COUNT",
		DEFAULT_PROBE_COUNT,
		1,
		MAX_PROBE_COUNT
	)
	mature_extension_count = _read_environment_int(
		"FORGE_V2_PAIRED_LOCALITY_MATURE_EXTENSION_COUNT",
		DEFAULT_MATURE_EXTENSION_COUNT,
		1,
		MAX_MATURE_EXTENSION_COUNT
	)
	run_mesh_analysis = _read_environment_bool(
		"FORGE_V2_PAIRED_LOCALITY_ANALYZE_MESH",
		true
	)
	station_chunk_offsets = _build_station_chunk_offsets(probe_count)
	if station_chunk_offsets.size() != probe_count:
		_append_error("could_not_resolve_equal_grid_phase_probe_stations")
	run_id = "%s_%d_pid%d_%dprobes_%dmature" % [
		Time.get_datetime_string_from_system().replace(":", "").replace("-", ""),
		Time.get_ticks_usec(),
		OS.get_process_id(),
		probe_count,
		mature_extension_count,
	]
	result_base_path = RESULT_PREFIX + "_" + run_id
	print(
		"PAIRED LOCALITY probes=%d mature_extensions=%d mesh_analysis=%s"
		% [probe_count, mature_extension_count, str(run_mesh_analysis)]
	)
	if not errors.is_empty():
		_finish(null, null, {}, {}, {}, {}, Time.get_ticks_usec())
		return

	var young = ChunkedBackendScript.new()
	var mature = ChunkedBackendScript.new()
	var setup_started_usec := Time.get_ticks_usec()
	if not _initialize_backend(young, "young"):
		_finish(young, mature, {}, {}, {}, {}, setup_started_usec)
		return
	if not _initialize_backend(mature, "mature"):
		_finish(young, mature, {}, {}, {}, {}, setup_started_usec)
		return

	var rail_start_x := _rail_start_x()
	var rail_end_x := _rail_end_x()
	var young_seed := _build_body(
		&"paired_young_seed",
		Vector3(rail_start_x, RAIL_Y_METERS, RAIL_Z_METERS),
		Vector3(rail_end_x, RAIL_Y_METERS, RAIL_Z_METERS),
		Vector3.BACK,
		Vector3.FORWARD,
		0
	)
	var mature_seed := _build_body(
		&"paired_mature_seed",
		Vector3(rail_start_x, RAIL_Y_METERS, RAIL_Z_METERS),
		Vector3(rail_end_x, RAIL_Y_METERS, RAIL_Z_METERS),
		Vector3.BACK,
		Vector3.FORWARD,
		0
	)
	var young_seed_result: Dictionary = young.initialize_seed(young_seed)
	var mature_seed_result: Dictionary = mature.initialize_seed(mature_seed)
	if not bool(young_seed_result.get("ok", false)):
		_append_error(
			"young_seed_failed_%s"
			% String(young_seed_result.get("error", "unknown"))
		)
	if not bool(mature_seed_result.get("ok", false)):
		_append_error(
			"mature_seed_failed_%s"
			% String(mature_seed_result.get("error", "unknown"))
		)
	young_seed = null
	mature_seed = null
	if not errors.is_empty():
		_finish(young, mature, {}, {}, {}, {}, setup_started_usec)
		return

	var mature_cursor_x := rail_end_x
	var maturity_started_usec := Time.get_ticks_usec()
	for extension_index in range(mature_extension_count):
		var extension_start_x := mature_cursor_x - CELL_SIZE_METERS
		var extension_end_x := (
			mature_cursor_x
			+ float(MATURE_EXTENSION_LENGTH_CHUNKS) * CHUNK_SIZE_METERS
		)
		var extension_body := _build_body(
			StringName("paired_mature_extension_%03d" % extension_index),
			Vector3(extension_start_x, RAIL_Y_METERS, RAIL_Z_METERS),
			Vector3(extension_end_x, RAIL_Y_METERS, RAIL_Z_METERS),
			Vector3.BACK,
			Vector3.FORWARD,
			extension_index + 1
		)
		var extension_result: Dictionary = mature.apply_add_body(extension_body)
		extension_body = null
		if not bool(extension_result.get("ok", false)):
			_append_error(
				"mature_extension_%d_failed_%s"
				% [
					extension_index,
					String(extension_result.get("error", "unknown")),
				]
			)
			break
		if int(extension_result.get("changed_cell_count", 0)) <= 0:
			_append_error("mature_extension_%d_was_noop" % extension_index)
			break
		mature_cursor_x = extension_end_x
	maturity_construction_elapsed_ms = _elapsed_milliseconds(
		maturity_started_usec
	)
	if not errors.is_empty():
		_finish(young, mature, {}, {}, {}, {}, setup_started_usec)
		return

	var setup_elapsed_ms := _elapsed_milliseconds(setup_started_usec)
	var young_pre_summary: Dictionary = young.get_summary().duplicate(true)
	var mature_pre_summary: Dictionary = mature.get_summary().duplicate(true)
	var young_pre_debug: Dictionary = young.get_last_locality_debug_snapshot()
	var mature_pre_debug: Dictionary = mature.get_last_locality_debug_snapshot()
	var young_pre_cells := int(young_pre_summary.get("occupied_cell_count", -1))
	var mature_pre_cells := int(mature_pre_summary.get("occupied_cell_count", -1))
	var initial_occupancy_gap := mature_pre_cells - young_pre_cells
	var mature_only_chunks := _coordinate_difference(
		mature_pre_debug.get("all_resident_chunk_coords", []) as Array,
		young_pre_debug.get("all_resident_chunk_coords", []) as Array
	)
	if mature_pre_cells <= young_pre_cells or initial_occupancy_gap <= 0:
		_append_error("mature_workpiece_not_larger_than_young")
	if mature_only_chunks.is_empty():
		_append_error("mature_workpiece_has_no_remote_only_chunks")
	if int(young_pre_summary.get("live_csg_node_count", -1)) != 0:
		_append_error("young_summary_reports_csg_nodes_before_probes")
	if int(mature_pre_summary.get("live_csg_node_count", -1)) != 0:
		_append_error("mature_summary_reports_csg_nodes_before_probes")
	if _count_csg_nodes(root) != 0:
		_append_error("scene_tree_contains_csg_nodes_before_probes")

	var reference_local_signature := ""
	for probe_index in range(probe_count):
		var station_x := _station_x(probe_index)
		var probe_start := Vector3(station_x, RAIL_Y_METERS, RAIL_Z_METERS)
		var probe_end := probe_start + Vector3.UP * PROBE_LENGTH_METERS
		var young_probe := _build_body(
			StringName("paired_probe_%03d" % probe_index),
			probe_start,
			probe_end,
			Vector3.BACK,
			Vector3.FORWARD,
			1000 + probe_index
		)
		var mature_probe := _build_body(
			StringName("paired_probe_%03d" % probe_index),
			probe_start,
			probe_end,
			Vector3.BACK,
			Vector3.FORWARD,
			1000 + probe_index
		)
		var young_before: Dictionary = young.get_summary()
		var mature_before: Dictionary = mature.get_summary()
		var young_measurement: Dictionary
		var mature_measurement: Dictionary
		var execution_order := "young_then_mature"
		if probe_index % 2 == 0:
			young_measurement = _measure_apply(young, young_probe)
			mature_measurement = _measure_apply(mature, mature_probe)
		else:
			execution_order = "mature_then_young"
			mature_measurement = _measure_apply(mature, mature_probe)
			young_measurement = _measure_apply(young, young_probe)
		young_probe = null
		mature_probe = null
		var young_result: Dictionary = young_measurement.get("result", {})
		var mature_result: Dictionary = mature_measurement.get("result", {})
		var young_after: Dictionary = young.get_summary()
		var mature_after: Dictionary = mature.get_summary()
		var young_debug: Dictionary = young.get_last_locality_debug_snapshot()
		var mature_debug: Dictionary = mature.get_last_locality_debug_snapshot()

		if not bool(young_result.get("ok", false)):
			_append_error(
				"probe_%d_young_failed_%s"
				% [probe_index, String(young_result.get("error", "unknown"))]
			)
			break
		if not bool(mature_result.get("ok", false)):
			_append_error(
				"probe_%d_mature_failed_%s"
				% [probe_index, String(mature_result.get("error", "unknown"))]
			)
			break

		var young_delta := (
			int(young_after.get("occupied_cell_count", -1))
			- int(young_before.get("occupied_cell_count", -1))
		)
		var mature_delta := (
			int(mature_after.get("occupied_cell_count", -1))
			- int(mature_before.get("occupied_cell_count", -1))
		)
		if young_delta <= 0 or mature_delta <= 0:
			_append_error("probe_%d_not_positive_volume" % probe_index)
		if young_delta != int(young_result.get("changed_cell_count", -2)):
			_append_error("probe_%d_young_occupancy_delta_mismatch" % probe_index)
		if mature_delta != int(mature_result.get("changed_cell_count", -2)):
			_append_error("probe_%d_mature_occupancy_delta_mismatch" % probe_index)
		if young_delta != mature_delta:
			_append_error("probe_%d_paired_occupancy_delta_mismatch" % probe_index)

		var young_local := _extract_local_counter_vector(young_result)
		var mature_local := _extract_local_counter_vector(mature_result)
		var local_signature := JSON.stringify(young_local, "", true)
		if young_local != mature_local:
			_append_error("probe_%d_local_counter_vector_mismatch" % probe_index)
		if probe_index == 0:
			reference_local_signature = local_signature
		elif local_signature != reference_local_signature:
			_append_error("probe_%d_local_signature_changed_by_station" % probe_index)
		for coordinate_field: String in DEBUG_COORDINATE_FIELDS:
			if (
				_coordinate_signature(young_debug.get(coordinate_field, []) as Array)
				!= _coordinate_signature(mature_debug.get(coordinate_field, []) as Array)
			):
				_append_error(
					"probe_%d_%s_mismatch"
					% [probe_index, coordinate_field]
				)

		var contact_chunks: Array = young_debug.get(
			"contact_chunk_coords",
			[]
		) as Array
		var remote_minimum_distance := _minimum_chebyshev_distance(
			mature_only_chunks,
			contact_chunks
		)
		if remote_minimum_distance <= PROCESSING_HALO_CHUNK_RINGS:
			_append_error("probe_%d_remote_mass_inside_contact_halo" % probe_index)
		if int(young_after.get("live_csg_node_count", -1)) != 0:
			_append_error("probe_%d_young_summary_reports_csg_nodes" % probe_index)
		if int(mature_after.get("live_csg_node_count", -1)) != 0:
			_append_error("probe_%d_mature_summary_reports_csg_nodes" % probe_index)
		if _count_csg_nodes(root) != 0:
			_append_error("probe_%d_scene_tree_contains_csg_nodes" % probe_index)

		var young_row := _build_raw_row(
			probe_index,
			"young",
			execution_order,
			young_measurement,
			young_before,
			young_after,
			young_delta,
			remote_minimum_distance,
			local_signature
		)
		var mature_row := _build_raw_row(
			probe_index,
			"mature",
			execution_order,
			mature_measurement,
			mature_before,
			mature_after,
			mature_delta,
			remote_minimum_distance,
			local_signature
		)
		raw_rows.append(young_row)
		raw_rows.append(mature_row)
		var young_total := float(young_row.get("total_ms", 0.0))
		var mature_total := float(mature_row.get("total_ms", 0.0))
		young_total_times_ms.append(young_total)
		mature_total_times_ms.append(mature_total)
		paired_total_deltas_ms.append(mature_total - young_total)
		if young_total > 0.0:
			paired_total_ratios.append(mature_total / young_total)
		print(
			"PAIR %d/%d young=%.3fms mature=%.3fms delta=%+.3fms cells=%d"
			% [
				probe_index + 1,
				probe_count,
				young_total,
				mature_total,
				mature_total - young_total,
				young_delta,
			]
		)
		if not errors.is_empty():
			break

	var young_post_summary: Dictionary = young.get_summary().duplicate(true)
	var mature_post_summary: Dictionary = mature.get_summary().duplicate(true)
	var final_occupancy_gap := (
		int(mature_post_summary.get("occupied_cell_count", -1))
		- int(young_post_summary.get("occupied_cell_count", -1))
	)
	if final_occupancy_gap != initial_occupancy_gap:
		_append_error("paired_probes_changed_remote_occupancy_gap")
	if raw_rows.size() != probe_count * 2:
		_append_error("paired_probe_cohort_incomplete")

	var topology := {
		"enabled": run_mesh_analysis,
		"young": {},
		"mature": {},
		"pass": not run_mesh_analysis,
	}
	if run_mesh_analysis and raw_rows.size() == probe_count * 2:
		topology = _analyze_topology_after_cohort(young, mature)
		if not bool(topology.get("pass", false)):
			_append_error("post_cohort_topology_gate_failed")

	_finish(
		young,
		mature,
		young_pre_summary,
		mature_pre_summary,
		young_post_summary,
		mature_post_summary,
		setup_started_usec,
		setup_elapsed_ms,
		initial_occupancy_gap,
		mature_only_chunks.size(),
		topology
	)


func _initialize_backend(backend: RefCounted, label: String) -> bool:
	var result: Dictionary = backend.initialize(
		CELL_SIZE_METERS,
		CHUNK_CELL_COUNT,
		PROCESSING_HALO_CHUNK_RINGS
	)
	if bool(result.get("ok", false)):
		return true
	_append_error(
		"%s_initialize_failed_%s"
		% [label, String(result.get("error", "unknown"))]
	)
	return false


func _build_body(
	body_id: StringName,
	path_start: Vector3,
	path_end: Vector3,
	surface_normal: Vector3,
	contact_direction: Vector3,
	serial_index: int
) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	var path_points := PackedVector3Array([path_start, path_end])
	body.set("body_id", body_id)
	body.set("source_record_id", StringName("%s_source" % String(body_id)))
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE)
	body.set("material_variant_id", MATERIAL_ID)
	body.set("operation_mode", ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL)
	body.set(
		"placement_policy",
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	body.set("shape_kind", ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
	body.set("path_points", path_points)
	body.set(
		"path_surface_normals",
		PackedVector3Array([surface_normal, surface_normal])
	)
	body.set(
		"path_contact_directions",
		PackedVector3Array([contact_direction, contact_direction])
	)
	body.set("profile_id", &"paired_locality_square_16mm_v1")
	body.set("profile_display_name", "Paired Locality Square 16mm V1")
	body.set("profile_polygon_2d_meters", _build_profile_polygon())
	body.set("profile_anchor_2d_meters", Vector2.ZERO)
	body.set(
		"profile_contact_point_relative_2d_meters",
		Vector2(0.0, -PROFILE_HALF_SIZE_METERS)
	)
	body.set(
		"profile_contact_direction_2d",
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	body.set("profile_contact_distance_meters", PROFILE_HALF_SIZE_METERS)
	body.set("profile_runtime_schema_version", 1)
	body.set("profile_rotation_bias_degrees", 0.0)
	body.set("profile_twist_degrees_per_meter", 0.0)
	body.set("created_timestamp", FIXED_TIMESTAMP + float(serial_index))
	body.set("updated_timestamp", FIXED_TIMESTAMP + float(serial_index))
	body.call("normalize")
	body.set("body_id", body_id)
	body.set("source_record_id", StringName("%s_source" % String(body_id)))
	body.set("created_timestamp", FIXED_TIMESTAMP + float(serial_index))
	body.set("updated_timestamp", FIXED_TIMESTAMP + float(serial_index))
	return body


func _build_profile_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-PROFILE_HALF_SIZE_METERS, -PROFILE_HALF_SIZE_METERS),
		Vector2(PROFILE_HALF_SIZE_METERS, -PROFILE_HALF_SIZE_METERS),
		Vector2(PROFILE_HALF_SIZE_METERS, PROFILE_HALF_SIZE_METERS),
		Vector2(-PROFILE_HALF_SIZE_METERS, PROFILE_HALF_SIZE_METERS),
	])


func _measure_apply(backend: RefCounted, body: Resource) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var result: Dictionary = backend.apply_add_body(body)
	var apply_wall_ms := _elapsed_milliseconds(started_usec)
	return {
		"result": result,
		"apply_wall_ms": apply_wall_ms,
	}


func _extract_local_counter_vector(result: Dictionary) -> Dictionary:
	var vector: Dictionary = {}
	for field: String in LOCAL_COUNTER_FIELDS:
		vector[field] = int(result.get(field, -1))
	return vector


func _build_raw_row(
	probe_index: int,
	cohort: String,
	execution_order: String,
	measurement: Dictionary,
	before_summary: Dictionary,
	after_summary: Dictionary,
	occupancy_delta: int,
	remote_minimum_distance: int,
	local_signature: String
) -> Dictionary:
	var result: Dictionary = measurement.get("result", {})
	var row := {
		"probe_index": probe_index,
		"probe_number": probe_index + 1,
		"cohort": cohort,
		"execution_order": execution_order,
		"station_x_meters": _station_x(probe_index),
		"station_chunk_translation": _station_chunk_offset(probe_index),
		"occupancy_before": int(before_summary.get("occupied_cell_count", -1)),
		"occupancy_after": int(after_summary.get("occupied_cell_count", -1)),
		"occupancy_delta": occupancy_delta,
		"resident_chunks_before": int(before_summary.get("chunk_count", -1)),
		"resident_chunks_after": int(after_summary.get("chunk_count", -1)),
		"global_revision_after": int(after_summary.get("revision", -1)),
		"global_source_count_after": int(after_summary.get("source_body_count", -1)),
		"global_triangle_count_after": int(after_summary.get("total_triangle_count", -1)),
		"remote_minimum_chebyshev_chunks": remote_minimum_distance,
		"local_counter_signature_sha256": local_signature.sha256_text(),
		"apply_wall_ms": float(measurement.get("apply_wall_ms", -1.0)),
	}
	for field: String in LOCAL_COUNTER_FIELDS:
		row[field] = int(result.get(field, -1))
	for field: String in TIMING_FIELDS:
		if field == "apply_wall_ms":
			continue
		row[field] = float(result.get(field, -1.0))
	return row


func _analyze_topology_after_cohort(
	young: RefCounted,
	mature: RefCounted
) -> Dictionary:
	var young_started := Time.get_ticks_usec()
	var young_mesh: ArrayMesh = young.get_combined_mesh()
	var young_analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(young_mesh)
	var young_elapsed_ms := _elapsed_milliseconds(young_started)
	var mature_started := Time.get_ticks_usec()
	var mature_mesh: ArrayMesh = mature.get_combined_mesh()
	var mature_analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(mature_mesh)
	var mature_elapsed_ms := _elapsed_milliseconds(mature_started)
	var young_result := _extract_topology_result(
		young_analysis,
		young_elapsed_ms,
		young_mesh
	)
	var mature_result := _extract_topology_result(
		mature_analysis,
		mature_elapsed_ms,
		mature_mesh
	)
	return {
		"enabled": true,
		"young": young_result,
		"mature": mature_result,
		"pass": (
			bool(young_result.get("pass", false))
			and bool(mature_result.get("pass", false))
		),
		"timing_scope": (
			"combined mesh construction and topology analysis occur only after "
			+ "all paired edit timings"
		),
	}


func _extract_topology_result(
	analysis: Dictionary,
	elapsed_ms: float,
	mesh: ArrayMesh
) -> Dictionary:
	var topology_pass := (
		bool(analysis.get("watertight", false))
		and int(analysis.get("component_count", -1)) == 1
		and int(analysis.get("boundary_edge_count", -1)) == 0
		and int(analysis.get("nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("directed_edge_mismatch_count", -1)) == 0
		and int(analysis.get("degenerate_triangle_count", -1)) == 0
		and int(analysis.get("nonfinite_vertex_count", -1)) == 0
	)
	return {
		"pass": topology_pass,
		"elapsed_ms": elapsed_ms,
		"surface_count": mesh.get_surface_count(),
		"triangle_count": int(analysis.get("triangle_count", -1)),
		"vertex_count": int(analysis.get("vertex_count", -1)),
		"component_count": int(analysis.get("component_count", -1)),
		"boundary_edge_count": int(analysis.get("boundary_edge_count", -1)),
		"nonmanifold_edge_count": int(analysis.get("nonmanifold_edge_count", -1)),
		"directed_edge_mismatch_count": int(analysis.get(
			"directed_edge_mismatch_count",
			-1
		)),
		"degenerate_triangle_count": int(analysis.get(
			"degenerate_triangle_count",
			-1
		)),
		"nonfinite_vertex_count": int(analysis.get(
			"nonfinite_vertex_count",
			-1
		)),
	}


func _coordinate_difference(larger: Array, smaller: Array) -> Array[Vector3i]:
	var smaller_lookup: Dictionary = {}
	for coordinate_variant: Variant in smaller:
		if coordinate_variant is Vector3i:
			smaller_lookup[coordinate_variant as Vector3i] = true
	var difference: Array[Vector3i] = []
	for coordinate_variant: Variant in larger:
		if not coordinate_variant is Vector3i:
			continue
		var coordinate := coordinate_variant as Vector3i
		if not smaller_lookup.has(coordinate):
			difference.append(coordinate)
	return difference


func _coordinate_signature(coordinates: Array) -> String:
	var parts := PackedStringArray()
	for coordinate_variant: Variant in coordinates:
		if not coordinate_variant is Vector3i:
			parts.append(str(coordinate_variant))
			continue
		var coordinate := coordinate_variant as Vector3i
		parts.append("%d,%d,%d" % [coordinate.x, coordinate.y, coordinate.z])
	return "|".join(parts)


func _minimum_chebyshev_distance(first: Array, second: Array) -> int:
	if first.is_empty() or second.is_empty():
		return -1
	var minimum_distance := 2147483647
	for first_variant: Variant in first:
		if not first_variant is Vector3i:
			continue
		var first_coordinate := first_variant as Vector3i
		for second_variant: Variant in second:
			if not second_variant is Vector3i:
				continue
			var second_coordinate := second_variant as Vector3i
			var delta := (first_coordinate - second_coordinate).abs()
			minimum_distance = mini(
				minimum_distance,
				maxi(delta.x, maxi(delta.y, delta.z))
			)
	return minimum_distance


func _rail_start_x() -> float:
	return (
		FIRST_STATION_X_METERS
		- float(LOCAL_RAIL_BUFFER_CHUNKS) * CHUNK_SIZE_METERS
	)


func _rail_end_x() -> float:
	return (
		_station_x(probe_count - 1)
		+ float(LOCAL_RAIL_BUFFER_CHUNKS) * CHUNK_SIZE_METERS
	)


func _station_x(probe_index: int) -> float:
	return (
		FIRST_STATION_X_METERS
		+ float(_station_chunk_offset(probe_index)) * CHUNK_SIZE_METERS
	)


func _station_chunk_offset(probe_index: int) -> int:
	if probe_index >= 0 and probe_index < station_chunk_offsets.size():
		return station_chunk_offsets[probe_index]
	return probe_index * STATION_SPACING_CHUNKS


func _build_station_chunk_offsets(count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var reference_span := _represented_profile_x_cell_span(0)
	var candidate_offset := 0
	var maximum_candidate_offset := maxi(count * 64, 64)
	while result.size() < count and candidate_offset <= maximum_candidate_offset:
		var spacing_valid := (
			result.is_empty()
			or candidate_offset - result[-1] >= STATION_SPACING_CHUNKS
		)
		if (
			spacing_valid
			and _represented_profile_x_cell_span(candidate_offset)
			== reference_span
		):
			result.append(candidate_offset)
		candidate_offset += 1
	return result


func _represented_profile_x_cell_span(chunk_offset: int) -> int:
	# Vector3 uses the same represented coordinates consumed by the backend.
	# Profile edges that are mathematically on 4 mm boundaries can otherwise
	# round to opposite sides at different translations and change broadphase
	# work despite an equal logical grid phase.
	var represented_center := Vector3(
		FIRST_STATION_X_METERS
		+ float(chunk_offset) * CHUNK_SIZE_METERS,
		0.0,
		0.0
	)
	var represented_minimum := (
		represented_center
		+ Vector3.LEFT * PROFILE_HALF_SIZE_METERS
	).x
	var represented_maximum := (
		represented_center
		+ Vector3.RIGHT * PROFILE_HALF_SIZE_METERS
	).x
	return (
		floori(represented_maximum / CELL_SIZE_METERS)
		- floori(represented_minimum / CELL_SIZE_METERS)
		+ 1
	)


func _count_csg_nodes(node: Node) -> int:
	var count := 1 if node is CSGShape3D else 0
	for child: Node in node.get_children():
		count += _count_csg_nodes(child)
	return count


func _build_timing_summary() -> Dictionary:
	return {
		"sample_pairs": young_total_times_ms.size(),
		"young_total_p50_ms": _percentile(young_total_times_ms, 0.50),
		"young_total_p95_ms": _percentile(young_total_times_ms, 0.95),
		"young_total_mean_ms": _mean(young_total_times_ms),
		"mature_total_p50_ms": _percentile(mature_total_times_ms, 0.50),
		"mature_total_p95_ms": _percentile(mature_total_times_ms, 0.95),
		"mature_total_mean_ms": _mean(mature_total_times_ms),
		"paired_mature_minus_young_p50_ms": _percentile(
			paired_total_deltas_ms,
			0.50
		),
		"paired_mature_minus_young_p95_ms": _percentile(
			paired_total_deltas_ms,
			0.95
		),
		"paired_mature_minus_young_mean_ms": _mean(paired_total_deltas_ms),
		"paired_mature_over_young_ratio_p50": _percentile(
			paired_total_ratios,
			0.50
		),
		"paired_mature_over_young_ratio_p95": _percentile(
			paired_total_ratios,
			0.95
		),
		"interpretation": (
			"timings are diagnostic and noisy; correctness is gated by exact "
			+ "local-work parity, not by a timing threshold"
		),
	}


func _finish(
	young: RefCounted,
	mature: RefCounted,
	young_pre_summary: Dictionary,
	mature_pre_summary: Dictionary,
	young_post_summary: Dictionary,
	mature_post_summary: Dictionary,
	run_started_usec: int,
	setup_elapsed_ms: float = 0.0,
	initial_occupancy_gap: int = 0,
	mature_only_chunk_count: int = 0,
	topology: Dictionary = {}
) -> void:
	var passed := errors.is_empty() and raw_rows.size() == probe_count * 2
	var timing_summary := _build_timing_summary()
	var result := {
		"benchmark_id": String(BENCHMARK_ID),
		"benchmark_schema": BENCHMARK_SCHEMA_VERSION,
		"run_id": run_id,
		"passed": passed,
		"errors": errors,
		"configuration": {
			"cell_size_meters": CELL_SIZE_METERS,
			"chunk_cell_count": CHUNK_CELL_COUNT,
			"chunk_size_meters": CHUNK_SIZE_METERS,
			"processing_halo_chunk_rings": PROCESSING_HALO_CHUNK_RINGS,
			"probe_count": probe_count,
			"minimum_station_spacing_chunks": STATION_SPACING_CHUNKS,
			"station_chunk_offsets": station_chunk_offsets,
			"local_rail_buffer_chunks": LOCAL_RAIL_BUFFER_CHUNKS,
			"mature_extension_count": mature_extension_count,
			"mature_extension_length_chunks": MATURE_EXTENSION_LENGTH_CHUNKS,
			"profile_half_size_meters": PROFILE_HALF_SIZE_METERS,
			"probe_length_meters": PROBE_LENGTH_METERS,
		},
		"scope": {
			"proves": (
				"identical positive-volume edits at equal 64mm grid phase do "
				+ "identical backend-local work when additional connected mass "
				+ "is outside the contact halo"
			),
			"does_not_prove": (
				"production Forge integration, organic fidelity, curves, remove, "
				+ "multi-material behavior, collision, persistence, undo, or "
				+ "constant wall time under all geometry/topology patterns"
			),
			"timed_region": (
				"apply_add_body only; combined mesh and topology analysis are "
				+ "excluded and run after the probe cohorts"
			),
		},
		"setup_elapsed_ms": setup_elapsed_ms,
		"maturity_construction_elapsed_ms": (
			maturity_construction_elapsed_ms
		),
		"run_elapsed_ms": _elapsed_milliseconds(run_started_usec),
		"initial_occupancy_gap_cells": initial_occupancy_gap,
		"mature_only_chunk_count": mature_only_chunk_count,
		"young_pre_summary": _concise_backend_summary(young_pre_summary),
		"mature_pre_summary": _concise_backend_summary(mature_pre_summary),
		"young_post_summary": _concise_backend_summary(young_post_summary),
		"mature_post_summary": _concise_backend_summary(mature_post_summary),
		"local_counter_fields": LOCAL_COUNTER_FIELDS,
		"debug_coordinate_fields": DEBUG_COORDINATE_FIELDS,
		"timing": timing_summary,
		"topology": topology,
		"raw_rows": raw_rows,
		"live_scene_csg_node_count": _count_csg_nodes(root),
	}
	var json_path := result_base_path + ".json"
	var text_path := result_base_path + ".txt"
	var csv_path := result_base_path + ".csv"
	if not _write_text(json_path, JSON.stringify(result, "\t", true) + "\n"):
		passed = false
	if not _write_text(text_path, _build_text_report(result)):
		passed = false
	if not _write_text(csv_path, _build_csv()):
		passed = false
	if young != null and young.has_method("dispose"):
		young.dispose()
	if mature != null and mature.has_method("dispose"):
		mature.dispose()
	print(
		"PAIRED LOCALITY %s pairs=%d occupancy_gap=%d delta_p50=%+.3fms ratio_p50=%.3f"
		% [
			"PASS" if passed else "FAIL",
			young_total_times_ms.size(),
			initial_occupancy_gap,
			float(timing_summary.get("paired_mature_minus_young_p50_ms", 0.0)),
			float(timing_summary.get("paired_mature_over_young_ratio_p50", 0.0)),
		]
	)
	print("JSON: " + json_path)
	print("TXT: " + text_path)
	print("CSV: " + csv_path)
	if not errors.is_empty():
		for error: String in errors:
			push_error(error)
	quit(0 if passed else 1)


func _concise_backend_summary(summary: Dictionary) -> Dictionary:
	if summary.is_empty():
		return {}
	return {
		"backend_id": String(summary.get("backend_id", "")),
		"backend_schema": int(summary.get("backend_schema", -1)),
		"revision": int(summary.get("revision", -1)),
		"source_body_count": int(summary.get("source_body_count", -1)),
		"chunk_count": int(summary.get("chunk_count", -1)),
		"occupied_cell_count": int(summary.get("occupied_cell_count", -1)),
		"total_triangle_count": int(summary.get("total_triangle_count", -1)),
		"live_csg_node_count": int(summary.get("live_csg_node_count", -1)),
	}


func _build_text_report(result: Dictionary) -> String:
	var timing: Dictionary = result.get("timing", {})
	var topology: Dictionary = result.get("topology", {})
	var lines := PackedStringArray([
		"Forge V2 paired contact-locality benchmark",
		"result: %s" % ("PASS" if bool(result.get("passed", false)) else "FAIL"),
		"probe pairs: %d" % young_total_times_ms.size(),
		"mature-only chunks: %d" % int(result.get("mature_only_chunk_count", 0)),
		"initial occupancy gap: %d cells" % int(result.get("initial_occupancy_gap_cells", 0)),
		"mature extension construction: %.3f ms (excluded from probe timings)" % float(
			result.get("maturity_construction_elapsed_ms", 0.0)
		),
		"young total p50/p95: %.3f / %.3f ms" % [
			float(timing.get("young_total_p50_ms", 0.0)),
			float(timing.get("young_total_p95_ms", 0.0)),
		],
		"mature total p50/p95: %.3f / %.3f ms" % [
			float(timing.get("mature_total_p50_ms", 0.0)),
			float(timing.get("mature_total_p95_ms", 0.0)),
		],
		"paired mature-young delta p50/p95: %+.3f / %+.3f ms" % [
			float(timing.get("paired_mature_minus_young_p50_ms", 0.0)),
			float(timing.get("paired_mature_minus_young_p95_ms", 0.0)),
		],
		"paired mature/young ratio p50/p95: %.3f / %.3f" % [
			float(timing.get("paired_mature_over_young_ratio_p50", 0.0)),
			float(timing.get("paired_mature_over_young_ratio_p95", 0.0)),
		],
		"post-cohort topology pass: %s" % str(topology.get("pass", false)),
		"proof: exact local counter and chunk-coordinate parity with remote connected maturity outside the halo",
		"non-proof: production integration, organic fidelity, all topology patterns, and universal wall-time constancy",
	])
	if not errors.is_empty():
		lines.append("errors: " + ", ".join(PackedStringArray(errors)))
	return "\n".join(lines) + "\n"


func _build_csv() -> String:
	var headers := PackedStringArray([
		"probe_index",
		"probe_number",
		"cohort",
		"execution_order",
		"station_x_meters",
		"station_chunk_translation",
		"occupancy_before",
		"occupancy_after",
		"occupancy_delta",
		"resident_chunks_before",
		"resident_chunks_after",
		"global_revision_after",
		"global_source_count_after",
		"global_triangle_count_after",
		"remote_minimum_chebyshev_chunks",
		"local_counter_signature_sha256",
	])
	for field: String in LOCAL_COUNTER_FIELDS:
		headers.append(field)
	for field: String in TIMING_FIELDS:
		headers.append(field)
	var lines := PackedStringArray([",".join(headers)])
	for row: Dictionary in raw_rows:
		var values := PackedStringArray()
		for header: String in headers:
			values.append(_csv_value(row.get(header, "")))
		lines.append(",".join(values))
	return "\n".join(lines) + "\n"


func _csv_value(value: Variant) -> String:
	var rendered: String
	if value is float:
		rendered = "%.9f" % float(value)
	else:
		rendered = str(value)
	if rendered.contains(",") or rendered.contains("\"") or rendered.contains("\n"):
		return "\"%s\"" % rendered.replace("\"", "\"\"")
	return rendered


func _write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_append_error("cannot_write_%s" % path.get_file())
		return false
	file.store_string(content)
	file.close()
	return true


func _append_error(error: String) -> void:
	if errors.size() < 64 and not errors.has(error):
		errors.append(error)


func _read_environment_int(
	variable_name: String,
	fallback: int,
	minimum: int,
	maximum: int
) -> int:
	var raw := OS.get_environment(variable_name).strip_edges()
	if raw.is_empty() or not raw.is_valid_int():
		return fallback
	return clampi(raw.to_int(), minimum, maximum)


func _read_environment_bool(variable_name: String, fallback: bool) -> bool:
	var raw := OS.get_environment(variable_name).strip_edges().to_lower()
	if raw.is_empty():
		return fallback
	if raw in ["1", "true", "yes", "on"]:
		return true
	if raw in ["0", "false", "no", "off"]:
		return false
	return fallback


func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var position := clampf(ratio, 0.0, 1.0) * float(sorted_values.size() - 1)
	var lower_index := floori(position)
	var upper_index := ceili(position)
	if lower_index == upper_index:
		return sorted_values[lower_index]
	return lerpf(
		sorted_values[lower_index],
		sorted_values[upper_index],
		position - float(lower_index)
	)


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _elapsed_milliseconds(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
