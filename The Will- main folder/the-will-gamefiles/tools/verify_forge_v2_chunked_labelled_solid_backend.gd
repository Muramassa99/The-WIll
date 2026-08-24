extends SceneTree

const BackendScript = preload(
	"res://tools/forge_v2_chunked_labelled_solid_backend.gd"
)
const RuntimeEngineScript = preload(
	"res://runtime/forge_v2/forge_v2_workpiece_solid_engine.gd"
)
const FixtureScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_fixture.gd"
)
const StressFixtureScript = preload(
	"res://tools/forge_v2_workpiece_stress_fixture.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const GuideOverlayScript = preload(
	"res://tools/forge_v2_chunk_locality_guide_overlay.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_chunked_labelled_solid_backend.txt"
)
const RESULT_JSON_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_chunked_labelled_solid_backend.json"
)
const VALID_ADD_COUNT := 10
const CELL_SIZE_METERS := 0.004
const CHUNK_CELL_COUNT := 16
const PROTOTYPE_SCOPE := (
	"4mm labelled voxel/block geometry is a locality-and-scaling proof only; "
	+ "it is not organic-fidelity geometry, an SDF implementation, or the "
	+ "final Forge V2 workpiece backend"
)
const LATTICE_SNAP_TOLERANCE_METERS := CELL_SIZE_METERS * 0.000025

var checks: Array[String] = []
var errors: Array[String] = []
var rejection_results: Array[Dictionary] = []
var occupancy_volume_diagnostics: Dictionary = {}
var diagonal_locality_diagnostics: Dictionary = {}
var guide_diagnostics: Dictionary = {}
var production_api_diagnostics: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var backend = BackendScript.new()
	var initialize_result: Dictionary = backend.initialize()
	_check(
		"initializes at 4 mm and 16 cubed cells",
		bool(initialize_result.get("ok", false))
		and is_equal_approx(float(initialize_result.get(
			"cell_size_meters",
			0.0
		)), 0.004)
		and int(initialize_result.get("chunk_dimension", 0)) == 16
		and int(initialize_result.get(
			"processing_halo_chunk_rings",
			-1
		)) == 2
	)
	_check(
		"negative grid coordinates use floor chunks",
		backend.call("_cell_to_chunk", Vector3i(-1, -16, -17))
		== Vector3i(-1, -1, -2)
		and backend.call(
			"_cell_to_local",
			Vector3i(-1, -16, -17),
			Vector3i(-1, -1, -2)
		) == Vector3i(15, 0, 15)
	)

	var bodies: Array[Resource] = FixtureScript.build_body_sequence(1)
	var seed_result: Dictionary = backend.initialize_seed(bodies[0])
	var seed_summary: Dictionary = backend.get_summary()
	_check(
		"seed publishes revision zero labelled chunks",
		bool(seed_result.get("ok", false))
		and int(seed_summary.get("revision", -1)) == 0
		and int(seed_summary.get("source_body_count", 0)) == 1
		and int(seed_summary.get("occupied_cell_count", 0)) > 0
		and int(seed_summary.get("chunk_count", 0)) > 0
		and int(seed_summary.get("total_triangle_count", 0)) > 0
	)
	_check(
		"seed result exposes required timings",
		seed_result.has("raster_ms")
		and seed_result.has("update_ms")
		and seed_result.has("remesh_ms")
		and seed_result.has("total_ms")
		and seed_result.has("validation_ms")
		and seed_result.has("examined_cell_count")
		and seed_result.has("world_aabb_cell_count")
	)

	var add_result: Dictionary = backend.apply_add_body(bodies[1])
	var add_summary: Dictionary = backend.get_summary()
	_check(
		"attached same-material Add advances one logical state",
		bool(add_result.get("ok", false))
		and int(add_summary.get("revision", -1)) == 1
		and int(add_summary.get("source_body_count", 0)) == 2
		and (
			int(add_result.get("overlap_cell_count", 0)) > 0
			or int(add_result.get("face_attachment_count", 0)) > 0
		)
		and int(add_result.get("remeshed_chunk_count", 0))
		<= int(add_result.get("changed_chunk_count", 0)) * 7
		and int(add_result.get("candidate_component_count", 0)) > 0
		and int(add_result.get("attached_component_count", -1))
		== int(add_result.get("candidate_component_count", 0))
		and int(add_result.get("contact_chunk_count", 0)) > 0
		and int(add_result.get("processing_context_chunk_count", 0)) > 0
		and int(add_result.get("examined_cell_count", 0))
		<= int(add_result.get("world_aabb_cell_count", -1))
	)
	_check(
		"remesh occupancy density metrics exactly match rebuilt chunks",
		_remeshed_occupancy_metrics_match(backend, add_result, add_summary)
	)

	var no_op_body := bodies[1].duplicate(true) as Resource
	no_op_body.set("body_id", &"chunked_no_op_repeat")
	no_op_body.set("source_record_id", &"chunked_no_op_repeat")
	var no_op_result: Dictionary = backend.apply_add_body(no_op_body)
	var no_op_summary: Dictionary = backend.get_summary()
	var no_op_debug: Dictionary = backend.get_last_locality_debug_snapshot()
	_check(
		"fully overlapping Add records a clean zero-change local transaction",
		bool(no_op_result.get("ok", false))
		and int(no_op_result.get("changed_cell_count", -1)) == 0
		and int(no_op_result.get("changed_chunk_count", -1)) == 0
		and int(no_op_result.get("remeshed_chunk_count", -1)) == 0
		and int(no_op_result.get("candidate_component_count", -1)) == 0
		and int(no_op_result.get("attached_component_count", -1)) == 0
		and int(no_op_result.get("overlap_cell_count", -1))
		== int(no_op_result.get("candidate_cell_count", -2))
		and int(no_op_result.get("face_attachment_count", -1)) == 0
		and int(no_op_result.get("remeshed_occupied_cell_count", -1)) == 0
		and int(no_op_result.get("remeshed_occupied_cell_min", -1)) == 0
		and int(no_op_result.get("remeshed_occupied_cell_max", -1)) == 0
		and int(no_op_summary.get("revision", -1)) == 2
		and (
			no_op_debug.get("changed_chunk_coords", []) as Array
		).is_empty()
		and (
			no_op_debug.get("remeshed_chunk_coords", []) as Array
		).is_empty()
	)

	var combined_mesh: ArrayMesh = backend.get_combined_mesh()
	var winding_ok := _mesh_has_outward_winding(combined_mesh)
	var mesh_triangle_count := _count_mesh_triangles(combined_mesh)
	_check(
		"combined cache mesh matches summary with outward winding",
		combined_mesh != null
		and combined_mesh.get_surface_count() == 1
		and mesh_triangle_count
		== int(add_summary.get("total_triangle_count", -1))
		and winding_ok
	)
	_check(
		"combined mesh is strict and authoring watertight with one component",
		_mesh_topology_pass(combined_mesh)
	)

	var before_reject := _capture_transaction_state(backend)
	var second_material := bodies[1].duplicate(true) as Resource
	second_material.set("material_variant_id", &"mat_test_second")
	var rejected: Dictionary = backend.apply_add_body(second_material)
	var second_material_unchanged := before_reject == _capture_transaction_state(
		backend
	)
	_check(
		"unsupported second material rejects atomically",
		not bool(rejected.get("ok", false))
		and String(rejected.get("error", ""))
		== "chunked_field_multiple_materials_unsupported"
		and second_material_unchanged
	)
	rejection_results.append({
		"label": "second material",
		"result": rejected,
		"state_unchanged": second_material_unchanged,
	})

	var stress_body := StressFixtureScript.build_operation_body(1)
	var void_body := stress_body.duplicate(true) as Resource
	void_body.set(
		"operation_mode",
		ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
	)
	_verify_transactional_rejection(
		backend,
		void_body,
		"unsupported VOID rejects atomically",
		"chunked_field_remove_material_unsupported"
	)

	production_api_diagnostics = _verify_production_api_contract()

	var diagonal_body := _build_diagonal_body()
	var diagonal_validation: Dictionary = backend.call(
		"_validate_supported_body",
		diagonal_body,
		StringName()
	)
	var diagonal_raster: Dictionary = {}
	if bool(diagonal_validation.get("ok", false)):
		diagonal_raster = backend.call(
			"_rasterize_body",
			diagonal_body,
			diagonal_validation
		)
	var optimized_diagonal_cells := _candidate_chunks_to_cell_set(
		backend,
		diagonal_raster.get("candidate_chunks", {}) as Dictionary
	)
	var brute_diagonal_cells := _brute_force_candidate_cell_set(
		backend,
		diagonal_body,
		diagonal_validation
	)
	diagonal_locality_diagnostics = {
		"validation": diagonal_validation,
		"world_aabb_cell_count": int(diagonal_raster.get(
			"world_aabb_cell_count",
			0
		)),
		"examined_cell_count": int(diagonal_raster.get(
			"examined_cell_count",
			0
		)),
		"candidate_cell_count": int(diagonal_raster.get(
			"candidate_cell_count",
			0
		)),
		"centerline_chunk_count": int(diagonal_raster.get(
			"centerline_chunk_count",
			0
		)),
		"broadphase_chunk_count": int(diagonal_raster.get(
			"broadphase_chunk_count",
			0
		)),
		"intersecting_chunk_count": int(diagonal_raster.get(
			"intersecting_chunk_count",
			0
		)),
		"optimized_candidate_count": optimized_diagonal_cells.size(),
		"brute_candidate_count": brute_diagonal_cells.size(),
	}
	_check(
		"diagonal chunk traversal exactly matches brute-force occupancy",
		bool(diagonal_validation.get("ok", false))
		and bool(diagonal_raster.get("ok", false))
		and optimized_diagonal_cells == brute_diagonal_cells
	)
	_check(
		"diagonal traversal examines a local band instead of its full world AABB",
		int(diagonal_raster.get("examined_cell_count", 0)) > 0
		and int(diagonal_raster.get("examined_cell_count", 0))
		< int(diagonal_raster.get("world_aabb_cell_count", 0))
		and int(diagonal_raster.get("centerline_chunk_count", 0)) > 1
	)

	backend.reset()
	var stress_seed_result: Dictionary = backend.initialize_seed(
		StressFixtureScript.build_seed_body()
	)
	var stress_adds_ok := bool(stress_seed_result.get("ok", false))
	for operation_index in range(VALID_ADD_COUNT):
		if not stress_adds_ok:
			break
		var stress_result: Dictionary = backend.apply_add_body(
			StressFixtureScript.build_operation_body(operation_index)
		)
		stress_adds_ok = (
			bool(stress_result.get("ok", false))
			and int(stress_result.get("revision", -1)) == operation_index + 1
			and int(stress_result.get("source_body_count", -1))
			== operation_index + 2
			and stress_result.has("candidate_cell_count")
			and stress_result.has("changed_cell_count")
		)
	var stress_state := _capture_transaction_state(backend)
	var stress_summary: Dictionary = backend.get_summary()
	var stress_mesh: ArrayMesh = backend.get_combined_mesh()
	_check(
		"ten deterministic stress Adds advance revision/source counts",
		stress_adds_ok
		and int(stress_summary.get("revision", -1)) == VALID_ADD_COUNT
		and int(stress_summary.get("source_body_count", -1))
		== VALID_ADD_COUNT + 1
	)
	_check(
		"ten-Add combined mesh is strict and authoring watertight with one component",
		_mesh_topology_pass(stress_mesh)
	)
	_check(
		"combined mesh volume equals occupied 4mm voxel-union volume",
		_occupancy_volume_pass(stress_mesh, stress_summary)
	)
	_check(
		"backend reports and retains zero built-in CSG nodes",
		int(stress_summary.get("live_csg_node_count", -1)) == 0
		and _count_csg_nodes(root) == 0
	)

	var synthetic_attachment := _build_mixed_attachment_probe(backend)
	_check(
		"every new candidate component must attach before an Add can mutate state",
		not bool(synthetic_attachment.get("attached", true))
		and int(synthetic_attachment.get("candidate_component_count", 0)) == 2
		and int(synthetic_attachment.get("attached_component_count", 0)) == 1
		and int(synthetic_attachment.get("unattached_component_count", 0)) == 1
	)

	var chunks_before_guide := int(stress_summary.get("chunk_count", -1))
	var guide = GuideOverlayScript.new()
	root.add_child(guide)
	guide.configure(0.064, AABB(Vector3.ZERO, Vector3.ONE * 0.128))
	guide.update_from_snapshot(backend.get_last_locality_debug_snapshot())
	guide.set_guide_mode(GuideOverlayScript.MODE_ACTIVE_WITH_HALO)
	var active_guide_summary: Dictionary = guide.get_debug_summary()
	guide.set_guide_mode(GuideOverlayScript.MODE_FULL_WORKSPACE)
	var full_guide_summary: Dictionary = guide.get_debug_summary()
	guide.set_guide_mode(GuideOverlayScript.MODE_OFF)
	var off_guide_summary: Dictionary = guide.get_debug_summary()
	guide_diagnostics = {
		"active_with_halo": active_guide_summary,
		"full_workspace": full_guide_summary,
		"off": off_guide_summary,
	}
	_check(
		"guide overlay is toggleable, non-colliding, and does not allocate chunks",
		bool(active_guide_summary.get("visible", false))
		and int(active_guide_summary.get("rendered_chunk_count", 0)) > 0
		and not bool(active_guide_summary.get("has_collision_node", true))
		and int(full_guide_summary.get("rendered_chunk_count", 0)) == 8
		and not bool(off_guide_summary.get("visible", true))
		and int(backend.get_summary().get("chunk_count", -2))
		== chunks_before_guide
	)
	guide.queue_free()

	var replay_backend = BackendScript.new()
	var replay_initialize: Dictionary = replay_backend.initialize(
		CELL_SIZE_METERS,
		CHUNK_CELL_COUNT
	)
	var replay_ok := bool(replay_initialize.get("ok", false))
	if replay_ok:
		replay_ok = bool(replay_backend.initialize_seed(
			StressFixtureScript.build_seed_body()
		).get("ok", false))
	for operation_index in range(VALID_ADD_COUNT):
		if not replay_ok:
			break
		replay_ok = bool(replay_backend.apply_add_body(
			StressFixtureScript.build_operation_body(operation_index)
		).get("ok", false))
	var replay_state := _capture_transaction_state(replay_backend)
	_check(
		"ten-Add replay produces the same summary and combined mesh",
		replay_ok and stress_state == replay_state
	)

	var ok := errors.is_empty()
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("Forge V2 chunked labelled solid verifier\n")
		file.store_string("Result: %s\n" % ("PASS" if ok else "FAIL"))
		for check: String in checks:
			file.store_string("%s\n" % check)
		file.store_string("Scope: %s\n" % PROTOTYPE_SCOPE)
		file.close()
	_write_json(RESULT_JSON_PATH, {
		"ok": ok,
		"backend_id": String(BackendScript.BACKEND_ID),
		"backend_schema": BackendScript.BACKEND_SCHEMA_VERSION,
		"prototype_scope": PROTOTYPE_SCOPE,
		"valid_add_count": VALID_ADD_COUNT,
		"checks": checks,
		"rejection_results": rejection_results,
		"occupancy_volume_diagnostics": occupancy_volume_diagnostics,
		"diagonal_locality_diagnostics": diagonal_locality_diagnostics,
		"guide_diagnostics": guide_diagnostics,
		"production_api_diagnostics": production_api_diagnostics,
		"errors": errors,
	})
	_dispose_backend(backend)
	_dispose_backend(replay_backend)
	print(
		"Forge V2 chunked labelled solid verifier: %s (%s)"
		% ["PASS" if ok else "FAIL", RESULT_PATH]
	)
	quit(0 if ok else 1)


func _verify_production_api_contract() -> Dictionary:
	var engine = RuntimeEngineScript.new()
	var initialize_result: Dictionary = engine.initialize()
	_check(
		"production engine exposes the locked backend identity",
		bool(initialize_result.get("ok", false))
		and String(initialize_result.get("backend_id", ""))
		== "chunked_labelled_solid_v1"
		and String(RuntimeEngineScript.BACKEND_ID)
		== "chunked_labelled_solid_v1"
	)
	var curved_seed := _build_curved_varying_frame_body()
	var validation: Dictionary = engine.call(
		"_validate_supported_body",
		curved_seed,
		StringName()
	)
	var raster: Dictionary = {}
	if bool(validation.get("ok", false)):
		raster = engine.call("_rasterize_body", curved_seed, validation)
	var optimized_cells := _candidate_chunks_to_cell_set(
		engine,
		raster.get("candidate_chunks", {}) as Dictionary
	)
	var reference_cells := _brute_force_ruled_candidate_cell_set(
		engine,
		curved_seed,
		validation
	)
	var point_axis_x: PackedVector3Array = validation.get(
		"point_axis_x",
		PackedVector3Array()
	) as PackedVector3Array
	var frame_changes := false
	if point_axis_x.size() >= 2:
		for point_index in range(1, point_axis_x.size()):
			if point_axis_x[0].dot(point_axis_x[point_index]) < 0.9999:
				frame_changes = true
				break
	_check(
		"curved varying-frame PROFILE_PATH matches the ruled occupancy oracle",
		bool(validation.get("ok", false))
		and not bool(validation.get("uses_straight_fast_path", true))
		and frame_changes
		and bool(raster.get("ok", false))
		and not optimized_cells.is_empty()
		and optimized_cells == reference_cells
		and optimized_cells.size()
		== int(raster.get("candidate_cell_count", -1))
	)
	var seed_result: Dictionary = engine.apply_body(curved_seed)
	var seed_summary: Dictionary = engine.get_summary()
	_check(
		"first production apply auto-seeds and publishes revision one",
		bool(seed_result.get("ok", false))
		and bool(seed_result.get("initialized_seed", false))
		and String(seed_result.get("apply_mode", "")) == "first_body_seed"
		and int(seed_summary.get("revision", -1)) == 1
		and int(seed_summary.get("source_body_count", -1)) == 1
	)
	var render_before: Array = engine.get_render_chunk_records()
	var render_before_map := _render_record_map(render_before)
	var detail_body := _build_attached_curved_detail_body(curved_seed)
	var detail_result: Dictionary = engine.apply_body(detail_body)
	var detail_summary: Dictionary = engine.get_summary()
	var detail_snapshot: Dictionary = engine.get_last_locality_debug_snapshot()
	var render_after: Array = engine.get_render_chunk_records()
	var render_after_map := _render_record_map(render_after)
	_check(
		"attached Detail PROFILE_PATH uses the same local Add authority",
		bool(detail_result.get("ok", false))
		and String(detail_result.get("apply_mode", ""))
		== "incremental_add"
		and int(detail_summary.get("revision", -1)) == 2
		and int(detail_summary.get("source_body_count", -1)) == 2
		and int(detail_result.get("changed_cell_count", 0)) > 0
		and int(detail_result.get("candidate_cell_count", 0)) > 0
	)
	var cache_probe := _analyze_render_cache_coherence(
		render_before_map,
		render_after_map,
		detail_snapshot.get("remeshed_chunk_coords", []) as Array
	)
	_check(
		"render records replace touched meshes and retain remote cached meshes",
		bool(cache_probe.get("pass", false))
	)
	var render_contract_ok := not render_after.is_empty()
	for record_variant: Variant in render_after:
		if not record_variant is Dictionary:
			render_contract_ok = false
			break
		var record := record_variant as Dictionary
		if (
			not record.get("chunk_coord") is Vector3i
			or not record.get("mesh") is ArrayMesh
			or int(record.get("mesh_revision", 0)) <= 0
			or StringName(record.get("material_variant_id"))
			!= StringName(detail_summary.get("material_variant_id", ""))
		):
			render_contract_ok = false
			break
	_check(
		"render publication is cached per chunk with no combined edit mesh",
		render_contract_ok
		and render_after.size() == int(detail_summary.get("chunk_count", -1))
		and int(detail_summary.get("live_csg_node_count", -1)) == 0
	)
	var usage: Dictionary = engine.get_material_usage_summary()
	var expected_volume_equivalents := (
		float(detail_summary.get("occupied_cell_count", 0))
		* pow(
			CELL_SIZE_METERS
			/ ForgeV2MaterialBodyScript.REFERENCE_CELL_WORLD_SIZE_METERS,
			3.0
		)
	)
	var expected_centi_units := int(round(
		expected_volume_equivalents
		/ ForgeV2MaterialBodyScript.CELL_EQUIVALENTS_PER_MATERIAL_UNIT
		* float(ForgeV2MaterialBodyScript.MATERIAL_UNIT_SCALE)
	))
	if expected_volume_equivalents > 0.0:
		expected_centi_units = maxi(expected_centi_units, 1)
	var usage_materials: Dictionary = usage.get("materials", {}) as Dictionary
	var material_id := StringName(detail_summary.get("material_variant_id", ""))
	var usage_entry: Dictionary = usage_materials.get(material_id, {}) as Dictionary
	_check(
		"4 mm maintained label count maps to the Forge material summary schema",
		is_equal_approx(float(usage.get(
			"total_rough_volume_cell_equivalents",
			-1.0
		)), expected_volume_equivalents)
		and int(usage.get("total_rough_material_centi_units", -1))
		== expected_centi_units
		and is_equal_approx(float(usage.get(
			"total_rough_material_units",
			-1.0
		)), float(expected_centi_units) / 100.0)
		and usage_materials.size() == 1
		and StringName(usage_entry.get("material_variant_id")) == material_id
		and is_equal_approx(float(usage_entry.get("ratio", -1.0)), 1.0)
	)
	var replay_engine = RuntimeEngineScript.new()
	var replay_initialize: Dictionary = replay_engine.initialize()
	var replay_bodies: Array[Resource] = [curved_seed, detail_body]
	var replay_result: Dictionary = replay_engine.rebuild_from_bodies(
		replay_bodies
	)
	var replay_summary: Dictionary = replay_engine.get_summary()
	var replay_usage: Dictionary = replay_engine.get_material_usage_summary()
	_check(
		"ordered-body rebuild deterministically restores geometry and usage",
		bool(replay_initialize.get("ok", false))
		and bool(replay_result.get("ok", false))
		and int(replay_result.get("rebuilt_body_count", -1)) == 2
		and int(replay_summary.get("revision", -1)) == 2
		and _production_summary_signature(replay_summary)
		== _production_summary_signature(detail_summary)
		and replay_usage == usage
	)
	_verify_production_rejections(engine, detail_body)
	var diagnostics := {
		"initialize_result": initialize_result,
		"validation_ok": bool(validation.get("ok", false)),
		"uses_straight_fast_path": bool(validation.get(
			"uses_straight_fast_path",
			true
		)),
		"frame_changes": frame_changes,
		"optimized_candidate_count": optimized_cells.size(),
		"reference_candidate_count": reference_cells.size(),
		"seed_revision": int(seed_summary.get("revision", -1)),
		"detail_revision": int(detail_summary.get("revision", -1)),
		"detail_changed_cell_count": int(detail_result.get(
			"changed_cell_count",
			0
		)),
		"render_chunk_count": render_after.size(),
		"cache_probe": cache_probe,
		"usage": usage,
		"replay_result": replay_result,
	}
	_dispose_backend(engine)
	_dispose_backend(replay_engine)
	return diagnostics


func _build_curved_varying_frame_body() -> Resource:
	var body := StressFixtureScript.build_seed_body().duplicate(true) as Resource
	var path_points := PackedVector3Array([
		Vector3(-0.24, -0.040, 0.0),
		Vector3(-0.12, -0.040, 0.0),
		Vector3(-0.04, -0.012, 0.0),
		Vector3(0.08, 0.040, 0.0),
		Vector3(0.24, 0.040, 0.0),
	])
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for _point: Vector3 in path_points:
		normals.append(Vector3.BACK)
		contacts.append(Vector3.FORWARD)
	body.set("body_id", &"chunked_curved_seed")
	body.set("source_record_id", &"chunked_curved_seed_command")
	body.set("path_points", path_points)
	body.set("path_surface_normals", normals)
	body.set("path_contact_directions", contacts)
	body.call("normalize")
	body.set("body_id", &"chunked_curved_seed")
	body.set("source_record_id", &"chunked_curved_seed_command")
	return body


func _build_attached_curved_detail_body(curved_seed: Resource) -> Resource:
	var body := curved_seed.duplicate(true) as Resource
	var seed_points: PackedVector3Array = curved_seed.get("path_points")
	var seed_normals: PackedVector3Array = curved_seed.get(
		"path_surface_normals"
	)
	var seed_contacts: PackedVector3Array = curved_seed.get(
		"path_contact_directions"
	)
	var path_points := PackedVector3Array()
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for point_index in range(3):
		path_points.append(seed_points[point_index] + Vector3(0.0, 0.0, 0.008))
		normals.append(seed_normals[point_index])
		contacts.append(seed_contacts[point_index])
	body.set("body_id", &"chunked_curved_detail")
	body.set("source_record_id", &"chunked_curved_detail_command")
	body.set(
		"body_kind",
		ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH
	)
	body.set("path_points", path_points)
	body.set("path_surface_normals", normals)
	body.set("path_contact_directions", contacts)
	body.call("normalize")
	body.set("body_id", &"chunked_curved_detail")
	body.set("source_record_id", &"chunked_curved_detail_command")
	return body


func _brute_force_ruled_candidate_cell_set(
	engine: RefCounted,
	body: Resource,
	validation: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	if not bool(validation.get("ok", false)):
		return result
	var path_points: PackedVector3Array = body.get("path_points")
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	var point_axis_x: PackedVector3Array = validation.get(
		"point_axis_x",
		PackedVector3Array()
	) as PackedVector3Array
	var point_axis_y: PackedVector3Array = validation.get(
		"point_axis_y",
		PackedVector3Array()
	) as PackedVector3Array
	if (
		point_axis_x.size() != path_points.size()
		or point_axis_y.size() != path_points.size()
	):
		return result
	var bounds_min := Vector3(INF, INF, INF)
	var bounds_max := Vector3(-INF, -INF, -INF)
	for point_index in range(path_points.size()):
		for profile_point: Vector2 in polygon:
			var world_point := (
				path_points[point_index]
				+ point_axis_x[point_index] * profile_point.x
				+ point_axis_y[point_index] * profile_point.y
			)
			bounds_min = bounds_min.min(world_point)
			bounds_max = bounds_max.max(world_point)
	var minimum_cell: Vector3i = engine.call("_world_to_cell", bounds_min)
	var maximum_cell: Vector3i = engine.call("_world_to_cell", bounds_max)
	for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
		for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
			for cell_z in range(minimum_cell.z, maximum_cell.z + 1):
				var cell_coord := Vector3i(cell_x, cell_y, cell_z)
				var cell_center: Vector3 = engine.call(
					"_cell_center_world",
					cell_coord
				)
				for segment_index in range(path_points.size() - 1):
					if _reference_cell_inside_ruled_segment(
						cell_center,
						path_points[segment_index],
						path_points[segment_index + 1],
						point_axis_x[segment_index],
						point_axis_y[segment_index],
						point_axis_x[segment_index + 1],
						point_axis_y[segment_index + 1],
						polygon
					):
						result[cell_coord] = true
						break
	return result


func _reference_cell_inside_ruled_segment(
	cell_center: Vector3,
	segment_start: Vector3,
	segment_end: Vector3,
	from_axis_x: Vector3,
	from_axis_y: Vector3,
	to_axis_x: Vector3,
	to_axis_y: Vector3,
	polygon: PackedVector2Array
) -> bool:
	var segment := segment_end - segment_start
	var segment_length := segment.length()
	if segment_length <= 0.000001:
		return false
	var tangent := segment / segment_length
	var distance_along_path := (cell_center - segment_start).dot(tangent)
	if distance_along_path < 0.0 or distance_along_path > segment_length:
		return false
	var ratio := clampf(distance_along_path / segment_length, 0.0, 1.0)
	var axis_x := from_axis_x.lerp(to_axis_x, ratio)
	var axis_y := from_axis_y.lerp(to_axis_y, ratio)
	var axis_x_squared := axis_x.dot(axis_x)
	var axis_x_axis_y := axis_x.dot(axis_y)
	var axis_y_squared := axis_y.dot(axis_y)
	var determinant := (
		axis_x_squared * axis_y_squared
		- axis_x_axis_y * axis_x_axis_y
	)
	if determinant <= 0.000000000001:
		return false
	var centerline_point := segment_start + tangent * distance_along_path
	var lateral := cell_center - centerline_point
	var lateral_x := lateral.dot(axis_x)
	var lateral_y := lateral.dot(axis_y)
	var profile_point := Vector2(
		(lateral_x * axis_y_squared - lateral_y * axis_x_axis_y)
		/ determinant,
		(lateral_y * axis_x_squared - lateral_x * axis_x_axis_y)
		/ determinant
	)
	return bool(_point_inside_or_on_polygon_reference(profile_point, polygon))


func _point_inside_or_on_polygon_reference(
	point: Vector2,
	polygon: PackedVector2Array
) -> bool:
	var inside := false
	var previous_index := polygon.size() - 1
	for point_index in range(polygon.size()):
		var current := polygon[point_index]
		var previous := polygon[previous_index]
		if Geometry2D.get_closest_point_to_segment(point, current, previous).distance_squared_to(point) <= 0.000000000001:
			return true
		if (current.y > point.y) != (previous.y > point.y):
			var denominator := previous.y - current.y
			if absf(denominator) > 0.000001:
				var intersection_x := (
					(previous.x - current.x)
					* (point.y - current.y)
					/ denominator
					+ current.x
				)
				if point.x < intersection_x:
					inside = not inside
		previous_index = point_index
	return inside


func _render_record_map(records: Array) -> Dictionary:
	var result: Dictionary = {}
	for record_variant: Variant in records:
		if not record_variant is Dictionary:
			continue
		var record := record_variant as Dictionary
		var coord_variant: Variant = record.get("chunk_coord")
		if coord_variant is Vector3i:
			result[coord_variant as Vector3i] = record
	return result


func _analyze_render_cache_coherence(
	before_records: Dictionary,
	after_records: Dictionary,
	remeshed_coords: Array
) -> Dictionary:
	var remeshed_set: Dictionary = {}
	for coord_variant: Variant in remeshed_coords:
		if coord_variant is Vector3i:
			remeshed_set[coord_variant as Vector3i] = true
	var touched_seen := false
	var untouched_seen := false
	var touched_changed := true
	var untouched_retained := true
	for coord_variant: Variant in before_records.keys():
		if not coord_variant is Vector3i or not after_records.has(coord_variant):
			continue
		var coord := coord_variant as Vector3i
		var before: Dictionary = before_records.get(coord, {}) as Dictionary
		var after: Dictionary = after_records.get(coord, {}) as Dictionary
		var before_mesh := before.get("mesh") as ArrayMesh
		var after_mesh := after.get("mesh") as ArrayMesh
		if remeshed_set.has(coord):
			touched_seen = true
			touched_changed = (
				touched_changed
				and before_mesh != null
				and after_mesh != null
				and before_mesh != after_mesh
				and before_mesh.get_rid() != after_mesh.get_rid()
				and int(after.get("mesh_revision", 0))
				> int(before.get("mesh_revision", -1))
			)
		else:
			untouched_seen = true
			untouched_retained = (
				untouched_retained
				and before_mesh != null
				and before_mesh == after_mesh
				and before_mesh.get_rid() == after_mesh.get_rid()
				and int(after.get("mesh_revision", -1))
				== int(before.get("mesh_revision", -2))
			)
	return {
		"pass": (
			touched_seen
			and untouched_seen
			and touched_changed
			and untouched_retained
		),
		"touched_seen": touched_seen,
		"untouched_seen": untouched_seen,
		"touched_changed": touched_changed,
		"untouched_retained": untouched_retained,
		"remeshed_chunk_count": remeshed_set.size(),
	}


func _production_summary_signature(summary: Dictionary) -> Dictionary:
	return {
		"backend_id": String(summary.get("backend_id", "")),
		"revision": int(summary.get("revision", -1)),
		"source_body_count": int(summary.get("source_body_count", -1)),
		"chunk_count": int(summary.get("chunk_count", -1)),
		"occupied_cell_count": int(summary.get("occupied_cell_count", -1)),
		"total_quad_count": int(summary.get("total_quad_count", -1)),
		"total_triangle_count": int(summary.get("total_triangle_count", -1)),
		"material_variant_id": String(summary.get("material_variant_id", "")),
		"live_csg_node_count": int(summary.get("live_csg_node_count", -1)),
	}


func _verify_production_rejections(
	engine: RefCounted,
	accepted_template: Resource
) -> void:
	var remove_body := accepted_template.duplicate(true) as Resource
	remove_body.set(
		"operation_mode",
		ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
	)
	_verify_transactional_rejection(
		engine,
		remove_body,
		"production Remove rejects atomically with an exact code",
		"chunked_field_remove_material_unsupported"
	)
	var empty_only_body := accepted_template.duplicate(true) as Resource
	empty_only_body.set(
		"placement_policy",
		ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
	)
	_verify_transactional_rejection(
		engine,
		empty_only_body,
		"production EmptyOnly rejects atomically with an exact code",
		"chunked_field_empty_only_unsupported"
	)
	var second_material := accepted_template.duplicate(true) as Resource
	second_material.set("material_variant_id", &"mat_test_second")
	_verify_transactional_rejection(
		engine,
		second_material,
		"production multimaterial rejects atomically with an exact code",
		"chunked_field_multiple_materials_unsupported"
	)
	var handle_body := accepted_template.duplicate(true) as Resource
	handle_body.set(
		"body_kind",
		ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
	)
	_verify_transactional_rejection(
		engine,
		handle_body,
		"production Handle rejects atomically with an exact code",
		"chunked_field_handle_profile_unsupported"
	)
	var spline_body := accepted_template.duplicate(true) as Resource
	spline_body.set(
		"shape_kind",
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	)
	_verify_transactional_rejection(
		engine,
		spline_body,
		"production Spline rejects atomically with an exact code",
		"chunked_field_spline_profile_path_unsupported"
	)
	var capsule_body := accepted_template.duplicate(true) as Resource
	capsule_body.set(
		"shape_kind",
		ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH
	)
	_verify_transactional_rejection(
		engine,
		capsule_body,
		"production capsule rejects atomically with an exact visible code",
		"chunked_field_capsule_path_unsupported"
	)
	var platform_body := accepted_template.duplicate(true) as Resource
	platform_body.set(
		"body_kind",
		ForgeV2MaterialBodyScript.BODY_KIND_PLATFORM_SEED
	)
	_verify_transactional_rejection(
		engine,
		platform_body,
		"production platform seed rejects atomically with an exact code",
		"chunked_field_platform_seed_unsupported"
	)


func _build_diagonal_body() -> Resource:
	var body := StressFixtureScript.build_seed_body().duplicate(true) as Resource
	var direction := Vector3(1.0, 1.0, 0.0).normalized()
	var path_length := 0.56
	var path_points := PackedVector3Array()
	var path_normals := PackedVector3Array()
	var path_contacts := PackedVector3Array()
	for point_index in range(5):
		var ratio := float(point_index) / 4.0
		path_points.append(
			direction * lerpf(-path_length * 0.5, path_length * 0.5, ratio)
		)
		path_normals.append(Vector3.BACK)
		path_contacts.append(Vector3.FORWARD)
	body.set("body_id", &"chunked_diagonal_oracle_body")
	body.set("source_record_id", &"chunked_diagonal_oracle_command")
	body.set("path_points", path_points)
	body.set("path_surface_normals", path_normals)
	body.set("path_contact_directions", path_contacts)
	body.call("normalize")
	return body


func _candidate_chunks_to_cell_set(
	backend: RefCounted,
	candidate_chunks: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	for chunk_variant: Variant in candidate_chunks.keys():
		if not chunk_variant is Vector3i:
			continue
		var chunk_coord := chunk_variant as Vector3i
		var local_indices: PackedInt32Array = candidate_chunks.get(
			chunk_coord,
			PackedInt32Array()
		) as PackedInt32Array
		for local_index: int in local_indices:
			var local_coord: Vector3i = backend.call(
				"_unflatten_local",
				local_index
			)
			var cell_coord: Vector3i = backend.call(
				"_chunk_local_to_cell",
				chunk_coord,
				local_coord
			)
			result[cell_coord] = true
	return result


func _brute_force_candidate_cell_set(
	backend: RefCounted,
	body: Resource,
	validation: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	if not bool(validation.get("ok", false)):
		return result
	var origin: Vector3 = validation.get("path_origin", Vector3.ZERO)
	var tangent: Vector3 = validation.get("path_tangent", Vector3.RIGHT)
	var path_length := float(validation.get("path_length", 0.0))
	var axis_x: Vector3 = validation.get("axis_x", Vector3.RIGHT)
	var axis_y: Vector3 = validation.get("axis_y", Vector3.UP)
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	var bounds_min := Vector3(INF, INF, INF)
	var bounds_max := Vector3(-INF, -INF, -INF)
	for longitudinal_offset in [0.0, path_length]:
		var ring_center := origin + tangent * float(longitudinal_offset)
		for profile_vertex: Vector2 in polygon:
			var world_point := (
				ring_center
				+ axis_x * profile_vertex.x
				+ axis_y * profile_vertex.y
			)
			bounds_min = bounds_min.min(world_point)
			bounds_max = bounds_max.max(world_point)
	var minimum_cell: Vector3i = backend.call("_world_to_cell", bounds_min)
	var maximum_cell: Vector3i = backend.call("_world_to_cell", bounds_max)
	for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
		for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
			for cell_z in range(minimum_cell.z, maximum_cell.z + 1):
				var cell_coord := Vector3i(cell_x, cell_y, cell_z)
				var cell_center: Vector3 = backend.call(
					"_cell_center_world",
					cell_coord
				)
				var relative := cell_center - origin
				var longitudinal := relative.dot(tangent)
				if longitudinal < -0.000001 or longitudinal > path_length + 0.000001:
					continue
				var profile_point := Vector2(
					relative.dot(axis_x),
					relative.dot(axis_y)
				)
				if bool(backend.call(
					"_point_inside_or_on_polygon",
					profile_point,
					polygon
				)):
					result[cell_coord] = true
	return result


func _remeshed_occupancy_metrics_match(
	backend: RefCounted,
	operation_result: Dictionary,
	summary: Dictionary
) -> bool:
	var snapshot: Dictionary = backend.get_last_locality_debug_snapshot()
	var coords_variant: Variant = snapshot.get("remeshed_chunk_coords", [])
	if not coords_variant is Array:
		return false
	var remeshed_coords: Array = coords_variant as Array
	if remeshed_coords.is_empty():
		return false
	var chunk_records_variant: Variant = backend.get("chunks")
	if not chunk_records_variant is Dictionary:
		return false
	var chunk_records := chunk_records_variant as Dictionary
	var occupied_sum := 0
	var occupied_min := (
		CHUNK_CELL_COUNT * CHUNK_CELL_COUNT * CHUNK_CELL_COUNT
	)
	var occupied_max := 0
	for coord_variant: Variant in remeshed_coords:
		if not coord_variant is Vector3i:
			return false
		var coord := coord_variant as Vector3i
		if not chunk_records.has(coord):
			return false
		var record: Dictionary = chunk_records.get(coord, {}) as Dictionary
		var chunk_occupied := int(record.get("occupied_cell_count", -1))
		if chunk_occupied < 0:
			return false
		occupied_sum += chunk_occupied
		occupied_min = mini(occupied_min, chunk_occupied)
		occupied_max = maxi(occupied_max, chunk_occupied)
	return (
		int(operation_result.get("remeshed_occupied_cell_count", -1))
		== occupied_sum
		and int(operation_result.get("remeshed_occupied_cell_min", -1))
		== occupied_min
		and int(operation_result.get("remeshed_occupied_cell_max", -1))
		== occupied_max
		and int(summary.get("last_remeshed_occupied_cell_count", -1))
		== occupied_sum
		and int(summary.get("last_remeshed_occupied_cell_min", -1))
		== occupied_min
		and int(summary.get("last_remeshed_occupied_cell_max", -1))
		== occupied_max
	)


func _build_mixed_attachment_probe(backend: RefCounted) -> Dictionary:
	var seed_body := StressFixtureScript.build_seed_body()
	var validation: Dictionary = backend.call(
		"_validate_supported_body",
		seed_body,
		StringName(backend.get_summary().get("material_variant_id", ""))
	)
	if not bool(validation.get("ok", false)):
		return {}
	var raster: Dictionary = backend.call("_rasterize_body", seed_body, validation)
	var seed_cells := _candidate_chunks_to_cell_set(
		backend,
		raster.get("candidate_chunks", {}) as Dictionary
	)
	if seed_cells.is_empty():
		return {}
	var attached_cell := Vector3i.ZERO
	var attached_cell_found := false
	for seed_cell_variant: Variant in seed_cells.keys():
		var seed_cell := seed_cell_variant as Vector3i
		for direction: Vector3i in [
			Vector3i.RIGHT,
			Vector3i.LEFT,
			Vector3i.UP,
			Vector3i.DOWN,
			Vector3i(0, 0, 1),
			Vector3i(0, 0, -1),
		]:
			var neighbor := seed_cell + direction
			if int(backend.call("_get_cell_label", neighbor)) != 0:
				continue
			attached_cell = neighbor
			attached_cell_found = true
			break
		if attached_cell_found:
			break
	if not attached_cell_found:
		return {}
	var detached_cell := attached_cell + Vector3i(1000, 1000, 1000)
	var candidate_chunks: Dictionary = {}
	for cell_coord: Vector3i in [attached_cell, detached_cell]:
		var chunk_coord: Vector3i = backend.call("_cell_to_chunk", cell_coord)
		var local_coord: Vector3i = backend.call(
			"_cell_to_local",
			cell_coord,
			chunk_coord
		)
		var local_index: int = backend.call("_flatten_local", local_coord)
		var indices: PackedInt32Array = candidate_chunks.get(
			chunk_coord,
			PackedInt32Array()
		) as PackedInt32Array
		indices.append(local_index)
		candidate_chunks[chunk_coord] = indices
	return backend.call("_inspect_candidate_attachment", candidate_chunks)


func _check(label: String, passed: bool) -> void:
	var line := "- %s: %s" % ["PASS" if passed else "FAIL", label]
	checks.append(line)
	if passed:
		print(line)
	else:
		errors.append(label)
		push_error(line)


func _verify_transactional_rejection(
	backend: RefCounted,
	body: Resource,
	label: String,
	expected_error: String
) -> void:
	var before := _capture_transaction_state(backend)
	var result: Dictionary = (
		backend.apply_body(body)
		if backend.has_method("apply_body")
		else backend.apply_add_body(body)
	)
	var after := _capture_transaction_state(backend)
	var unchanged := before == after
	var passed := (
		not bool(result.get("ok", false))
		and String(result.get("error", "")) == expected_error
		and unchanged
	)
	rejection_results.append({
		"label": label,
		"expected_error": expected_error,
		"result": result,
		"state_unchanged": unchanged,
	})
	_check(label, passed)


func _capture_transaction_state(backend: RefCounted) -> Dictionary:
	var summary: Dictionary = backend.get_summary()
	var analysis := MeshAnalyzerScript.strip_transient_arrays(
		MeshAnalyzerScript.analyze_mesh(backend.get_combined_mesh())
	)
	return {
		"summary": summary.duplicate(true),
		"triangle_count": int(analysis.get("triangle_count", 0)),
		"absolute_volume_cubic_meters": float(analysis.get(
			"absolute_volume_cubic_meters",
			0.0
		)),
		"geometry_signature_oriented": String(analysis.get(
			"geometry_signature_oriented",
			""
		)),
		"geometry_signature_unoriented": String(analysis.get(
			"geometry_signature_unoriented",
			""
		)),
	}


func _mesh_topology_pass(mesh: ArrayMesh) -> bool:
	var analysis := MeshAnalyzerScript.analyze_mesh(mesh)
	return (
		bool(analysis.get("strict_watertight", false))
		and bool(analysis.get("watertight", false))
		and int(analysis.get("strict_component_count", 0)) == 1
		and int(analysis.get("component_count", 0)) == 1
		and int(analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(analysis.get("boundary_edge_count", -1)) == 0
		and int(analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("nonfinite_vertex_count", -1)) == 0
	)


func _occupancy_volume_pass(mesh: ArrayMesh, summary: Dictionary) -> bool:
	var analysis := MeshAnalyzerScript.analyze_mesh(mesh)
	var analyzer_volume := float(analysis.get(
		"absolute_volume_cubic_meters",
		0.0
	))
	var local_origin_volume := _calculate_local_origin_mesh_volume(mesh)
	var expected_volume := (
		float(summary.get("occupied_cell_count", 0))
		* float(CELL_SIZE_METERS * CELL_SIZE_METERS * CELL_SIZE_METERS)
	)
	var packed_float_mesh_volume_tolerance := maxf(
		0.000000000001,
		expected_volume * 0.000005
	)
	var occupied_cell_count := int(summary.get("occupied_cell_count", 0))
	var lattice_oracle := _analyze_integer_lattice_volume(
		mesh,
		occupied_cell_count
	)
	occupancy_volume_diagnostics = {
		"analyzer_absolute_volume_cubic_meters": analyzer_volume,
		"local_origin_absolute_volume_cubic_meters": local_origin_volume,
		"expected_occupied_volume_cubic_meters": expected_volume,
		"local_origin_error_cubic_meters": absf(
			local_origin_volume - expected_volume
		),
		"local_origin_relative_error": (
			absf(local_origin_volume - expected_volume) / expected_volume
			if expected_volume > 0.0
			else INF
		),
		"packed_float_diagnostic_tolerance_cubic_meters": (
			packed_float_mesh_volume_tolerance
		),
		"integer_lattice_oracle": lattice_oracle,
	}
	print(
		"OCCUPANCY VOLUME analyzer=%.12f local_origin=%.12f expected=%.12f local_error=%.12f tolerance=%.12f cells=%d lattice_six=%d expected_six=%d snap=%.12f"
		% [
			analyzer_volume,
			local_origin_volume,
			expected_volume,
			absf(local_origin_volume - expected_volume),
			packed_float_mesh_volume_tolerance,
			occupied_cell_count,
			int(lattice_oracle.get("absolute_six_lattice_volume", 0)),
			int(lattice_oracle.get("expected_six_lattice_volume", 0)),
			float(lattice_oracle.get("maximum_lattice_snap_error_meters", INF)),
		]
	)
	return (
		expected_volume > 0.0
		and is_finite(analyzer_volume)
		and is_finite(local_origin_volume)
		and bool(lattice_oracle.get("pass", false))
	)


func _analyze_integer_lattice_volume(
	mesh: ArrayMesh,
	expected_occupied_cell_count: int
) -> Dictionary:
	var signed_six_lattice_volume := 0
	var maximum_snap_error_meters := 0.0
	var triangle_count := 0
	var nonfinite_vertex_count := 0
	if mesh == null:
		return {"pass": false, "error": "mesh_missing"}
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var lattice_vertices: Array[Vector3i] = []
		lattice_vertices.resize(vertices.size())
		for vertex_index in range(vertices.size()):
			var vertex := vertices[vertex_index]
			if not vertex.is_finite():
				nonfinite_vertex_count += 1
				continue
			var lattice_vertex := Vector3i(
				roundi(vertex.x / CELL_SIZE_METERS),
				roundi(vertex.y / CELL_SIZE_METERS),
				roundi(vertex.z / CELL_SIZE_METERS)
			)
			lattice_vertices[vertex_index] = lattice_vertex
			var snapped := Vector3(lattice_vertex) * CELL_SIZE_METERS
			var vertex_snap_error := maxf(
				absf(vertex.x - snapped.x),
				maxf(
					absf(vertex.y - snapped.y),
					absf(vertex.z - snapped.z)
				)
			)
			maximum_snap_error_meters = maxf(
				maximum_snap_error_meters,
				vertex_snap_error
			)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for offset in range(0, indices.size(), 3):
			var first := lattice_vertices[indices[offset]]
			var second := lattice_vertices[indices[offset + 1]]
			var third := lattice_vertices[indices[offset + 2]]
			signed_six_lattice_volume += _integer_scalar_triple(
				first,
				second,
				third
			)
			triangle_count += 1
	var absolute_six_lattice_volume := absi(signed_six_lattice_volume)
	var expected_six_lattice_volume := expected_occupied_cell_count * 6
	return {
		"pass": (
			expected_occupied_cell_count > 0
			and nonfinite_vertex_count == 0
			and maximum_snap_error_meters <= LATTICE_SNAP_TOLERANCE_METERS
			and absolute_six_lattice_volume == expected_six_lattice_volume
			and absolute_six_lattice_volume % 6 == 0
		),
		"triangle_count": triangle_count,
		"nonfinite_vertex_count": nonfinite_vertex_count,
		"signed_six_lattice_volume": signed_six_lattice_volume,
		"absolute_six_lattice_volume": absolute_six_lattice_volume,
		"expected_six_lattice_volume": expected_six_lattice_volume,
		"exact_lattice_volume_cells": float(absolute_six_lattice_volume) / 6.0,
		"expected_occupied_cell_count": expected_occupied_cell_count,
		"maximum_lattice_snap_error_meters": maximum_snap_error_meters,
		"lattice_snap_tolerance_meters": LATTICE_SNAP_TOLERANCE_METERS,
	}


func _integer_scalar_triple(
	first: Vector3i,
	second: Vector3i,
	third: Vector3i
) -> int:
	return (
		first.x * (second.y * third.z - second.z * third.y)
		+ first.y * (second.z * third.x - second.x * third.z)
		+ first.z * (second.x * third.y - second.y * third.x)
	)


func _calculate_local_origin_mesh_volume(mesh: ArrayMesh) -> float:
	if mesh == null or mesh.get_surface_count() <= 0:
		return 0.0
	var bounds := mesh.get_aabb()
	var origin := bounds.get_center()
	var signed_volume := 0.0
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for offset in range(0, indices.size(), 3):
			var first := vertices[indices[offset]] - origin
			var second := vertices[indices[offset + 1]] - origin
			var third := vertices[indices[offset + 2]] - origin
			signed_volume += first.dot(second.cross(third)) / 6.0
	return absf(signed_volume)


func _count_csg_nodes(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is CSGShape3D else 0
	for child: Node in node.get_children():
		count += _count_csg_nodes(child)
	return count


func _dispose_backend(backend: Variant) -> void:
	if backend == null:
		return
	if backend.has_method("dispose"):
		backend.call("dispose")
	elif backend.has_method("reset"):
		backend.call("reset")


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write verifier JSON: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()


func _count_mesh_triangles(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() <= 0:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return int(indices.size() / 3.0)


func _mesh_has_outward_winding(mesh: ArrayMesh) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for offset in range(0, indices.size(), 3):
		var index_a := int(indices[offset])
		var index_b := int(indices[offset + 1])
		var index_c := int(indices[offset + 2])
		var geometric_normal := (
			(vertices[index_b] - vertices[index_a]).cross(
				vertices[index_c] - vertices[index_a]
			).normalized()
		)
		if geometric_normal.dot(normals[index_a]) < 0.999:
			return false
	return not indices.is_empty()
