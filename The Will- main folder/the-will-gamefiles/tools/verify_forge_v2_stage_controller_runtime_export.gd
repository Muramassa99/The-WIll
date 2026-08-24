extends SceneTree

const StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeServiceScript = preload("res://services/forge_service.gd")
const DEFAULT_FORGE_RULES: ForgeRulesDef = preload(
	"res://core/defs/forge/forge_rules_default.tres"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_stage_controller_runtime_export_2026-08-22.txt"
)
const CELL_SIZE_METERS := 0.0125
const HANDLE_START := Vector3(-0.20, 0.0, 0.0)
const HANDLE_MIDPOINT := Vector3.ZERO
const HANDLE_END := Vector3(0.20, 0.0, 0.0)
const ORDINARY_START := Vector3(0.0, -0.06, 0.0)
const ORDINARY_END := Vector3(0.0, 0.06, 0.0)
const READINESS_FRAME_LIMIT := 360

var _controller: Node
var _presenter: Node3D
var _state: Resource
var _result_lines: PackedStringArray = []


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	if not ClassDB.class_exists(&"ForgeV2ManifoldBoolean"):
		_fail("native ForgeV2ManifoldBoolean backend is unavailable")
		return

	_controller = StageControllerScript.new() as Node
	_controller.name = "RuntimeExportStageController"
	root.add_child(_controller)
	_presenter = VolumePreviewPresenterScript.new() as Node3D
	_presenter.name = "RuntimeExportVolumePreviewPresenter"
	root.add_child(_presenter)
	await process_frame
	_presenter.call("bind_stage_controller", _controller)
	await process_frame
	await physics_frame
	_state = _controller.call("get_active_authoring_state") as Resource
	if not _expect(_state != null, "production StageController did not create authoring state"):
		return
	if not _expect(
		_state.has_method("request_runtime_contract_mesh_export"),
		"authoring state has no runtime mesh-provider request channel"
	):
		return

	var handle_result := await _author_and_commit_handle()
	if not _expect(
		bool(handle_result.get("ok", false)),
		String(handle_result.get("error", "Handle authoring failed"))
	):
		return
	var handle_body: Resource = handle_result.get("body", null) as Resource
	var handle_body_id := StringName(handle_body.get("body_id"))
	_result_lines.append(
		"PASS: actual StageController generated and committed one semantic Handle"
	)

	var ordinary_result := await _author_and_commit_overlapping_ordinary_body()
	if not _expect(
		bool(ordinary_result.get("ok", false)),
		String(ordinary_result.get("error", "ordinary body authoring failed"))
	):
		return
	var ordinary_body: Resource = ordinary_result.get("body", null) as Resource
	if not _expect(
		_fixture_paths_overlap(handle_body, ordinary_body),
		"ordinary fixture body does not overlap the Handle fixture"
	):
		return
	if not _expect(
		_count_active_committed_handles() == 1,
		"fixture does not contain exactly one active committed Handle"
	):
		return
	_result_lines.append(
		"PASS: overlapping ordinary body committed beside protected Handle authority"
	)

	var ready := await _await_runtime_export_ready()
	if not _expect(
		bool(ready.get("ok", false)),
		"native presenter/provider did not become export-ready: %s"
		% str(ready.get("failure_summary", {}))
	):
		return
	var final_packet: Dictionary = ready.get("packet", {}) as Dictionary
	var final_vertices: PackedVector3Array = final_packet.get(
		"vertices",
		PackedVector3Array()
	)
	var final_indices: PackedInt32Array = final_packet.get(
		"indices",
		PackedInt32Array()
	)
	if not _expect(
		not final_vertices.is_empty()
		and not final_indices.is_empty()
		and final_indices.size() % 3 == 0,
		"presenter runtime-export provider returned empty or malformed final mesh"
	):
		return
	if not _expect(
		bool(final_packet.get("final_union_performed", false)),
		"observable ordinary/Handle export skipped its required final union"
	):
		return
	if not _expect(
		not String(final_packet.get("backend_method", "")).is_empty(),
		"final-union packet did not identify the native composition method"
	):
		return
	_result_lines.append(
		"PASS: native provider exported a nonempty ordinary/Handle final union"
	)

	var saved_wip: CraftedItemWIP = _controller.call(
		"build_crafted_item_wip_for_save"
	) as CraftedItemWIP
	if not _expect(saved_wip != null, "StageController save builder returned null"):
		return
	if not _expect(
		saved_wip.forge_v2_authoring_state != null,
		"saved WIP lost its Forge V2 authoring state"
	):
		return
	if not _expect(
		_saved_wip_has_authoritative_mesh(saved_wip),
		"saved WIP has no authoritative nonempty Stage2 editable mesh"
	):
		return
	var cached_profile: BakedProfile = saved_wip.latest_baked_profile_snapshot
	if not _expect(
		cached_profile != null
		and cached_profile.primary_grip_valid
		and cached_profile.primary_grip_source_body_id == handle_body_id,
		"saved WIP has no valid cached profile authorized by the committed Handle"
	):
		return
	if not _expect(
		cached_profile.primary_grip_contact_position.distance_to(
			HANDLE_MIDPOINT / CELL_SIZE_METERS
		) <= 0.0001,
		"saved profile did not retain Handle midpoint contact in legacy cell units"
	):
		return
	_result_lines.append(
		"PASS: StageController save produced V2 state, Stage2 mesh, and Handle profile"
	)

	var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES)
	var fresh_profile: BakedProfile = forge_service.bake_wip(saved_wip, {})
	if not _expect(
		fresh_profile != null
		and fresh_profile.primary_grip_valid
		and fresh_profile.validation_error.is_empty()
		and fresh_profile.primary_grip_source_body_id == handle_body_id,
		"fresh ForgeService bake rejected or changed the saved V2 Handle contract"
	):
		return
	if not _expect(
		_saved_wip_has_authoritative_mesh(saved_wip),
		"fresh ForgeService bake discarded the authoritative V2 mesh"
	):
		return
	_result_lines.append(
		"PASS: fresh ForgeService bake retained valid mesh and Handle authority"
	)

	var diagnostics := _presenter.call(
		"get_native_static_sync_diagnostics"
	) as Dictionary
	_result_lines.append("native_mode=%s" % String(diagnostics.get("last_mode", "")))
	_result_lines.append(
		"native_publication_vertices=%d" % int(diagnostics.get("output_vertices", 0))
	)
	_result_lines.append("final_export_vertices=%d" % final_vertices.size())
	_result_lines.append("final_export_triangles=%d" % (final_indices.size() / 3))
	_pass()


func _author_and_commit_handle() -> Dictionary:
	var profile_entries: Array[Dictionary] = (
		ProfileShapeLibraryScript.build_handle_profile_entries()
	)
	if profile_entries.is_empty():
		return {"ok": false, "error": "no Handle profile entries are available"}
	var profile_id := StringName(profile_entries[0].get("id", StringName()))
	if profile_id == StringName():
		return {"ok": false, "error": "default Handle profile id is empty"}
	_controller.call("set_active_tool_id", AuthoringStateScript.TOOL_HANDLES)
	_controller.call("set_active_profile_id", profile_id)
	for point: Vector3 in [HANDLE_START, HANDLE_MIDPOINT, HANDLE_END]:
		var point_index := int(_controller.call(
			"append_spline_line_point",
			point,
			Vector3.UP
		))
		if point_index < 0:
			return {"ok": false, "error": "StageController rejected Handle control point"}
	if not bool(_controller.call("generate_profile_extrusion_from_spline")):
		return {"ok": false, "error": "StageController did not generate Handle extrusion"}
	var handle_body: Resource = _state.call("get_selected_material_body") as Resource
	if handle_body == null:
		return {"ok": false, "error": "generated Handle body is missing"}
	if (
		StringName(handle_body.get("body_kind"))
		!= MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
	):
		return {"ok": false, "error": "generated body lacks Handle semantic authority"}
	var path_points: PackedVector3Array = handle_body.get("path_points")
	var polygon: PackedVector2Array = handle_body.get("profile_polygon_2d_meters")
	if path_points.size() != 3 or polygon.size() < 3:
		return {"ok": false, "error": "Handle lost its 3-point path or profile polygon"}
	var layer: Resource = _controller.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	if layer == null or not _body_is_active_and_committed(handle_body):
		return {"ok": false, "error": "StageController did not commit Handle layer"}
	await process_frame
	await physics_frame
	return {"ok": true, "body": handle_body}


func _author_and_commit_overlapping_ordinary_body() -> Dictionary:
	_controller.call("set_active_tool_id", AuthoringStateScript.TOOL_VOLUME_STROKE)
	_controller.call("set_active_material_variant_id", &"mat_iron_gray")
	_controller.call("set_active_primitive_id", &"primitive_blob")
	var body_id := StringName(_controller.call(
		"begin_material_body_path",
		ORDINARY_START,
		Vector3.FORWARD,
		Vector3.ZERO
	))
	if body_id == StringName():
		return {"ok": false, "error": "StageController rejected ordinary body start"}
	if not bool(_controller.call(
		"extend_material_body_path",
		ORDINARY_END,
		true,
		Vector3.FORWARD,
		Vector3.ZERO
	)):
		return {"ok": false, "error": "StageController rejected ordinary body endpoint"}
	var ordinary_body := _find_body(body_id)
	if ordinary_body == null:
		return {"ok": false, "error": "ordinary material body disappeared before finish"}
	if not bool(_controller.call("finish_material_body_path")):
		return {"ok": false, "error": "StageController did not finish ordinary body"}
	var commit_ready := await _await_body_commit(body_id)
	if not commit_ready:
		return {
			"ok": false,
			"error": "ordinary body did not reach committed active state: %s"
			% str(_controller.call("get_last_material_body_finish_result")),
		}
	return {"ok": true, "body": ordinary_body}


func _await_body_commit(body_id: StringName) -> bool:
	for _frame_index in range(READINESS_FRAME_LIMIT):
		var body := _find_body(body_id)
		if _body_is_active_and_committed(body):
			return true
		await process_frame
	return false


func _await_runtime_export_ready() -> Dictionary:
	var last_packet: Dictionary = {}
	var last_diagnostics: Dictionary = {}
	for frame_index in range(READINESS_FRAME_LIMIT):
		await process_frame
		await physics_frame
		last_diagnostics = _presenter.call(
			"get_native_static_sync_diagnostics"
		) as Dictionary
		last_packet = _state.call(
			"request_runtime_contract_mesh_export"
		) as Dictionary
		var vertices: PackedVector3Array = last_packet.get(
			"vertices",
			PackedVector3Array()
		)
		var indices: PackedInt32Array = last_packet.get(
			"indices",
			PackedInt32Array()
		)
		if (
			bool(last_packet.get("ok", false))
			and not vertices.is_empty()
			and not indices.is_empty()
			and indices.size() % 3 == 0
			and String(last_diagnostics.get("lifecycle", "")) == "active"
			and bool(last_diagnostics.get("authoritative", false))
			and not bool(last_diagnostics.get("publication_pending", true))
		):
			return {
				"ok": true,
				"packet": last_packet,
				"diagnostics": last_diagnostics,
				"waited_frame_pairs": frame_index + 1,
			}
	return {
		"ok": false,
		"failure_summary": {
			"packet": _packet_summary(last_packet),
			"diagnostics": _diagnostics_summary(last_diagnostics),
		},
	}


func _saved_wip_has_authoritative_mesh(wip: CraftedItemWIP) -> bool:
	if wip == null or wip.stage2_item_state == null:
		return false
	var state: Resource = wip.stage2_item_state
	if (
		not bool(state.get("editable_mesh_visual_authority"))
		or not state.has_method("has_current_editable_mesh")
		or not bool(state.call("has_current_editable_mesh"))
	):
		return false
	var editable := state.get("current_editable_mesh_state") as Resource
	if editable == null:
		return false
	var arrays: Array = editable.get("surface_arrays") as Array
	if (
		arrays.size() <= Mesh.ARRAY_INDEX
		or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array
		or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array
	):
		return false
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	return not vertices.is_empty() and not indices.is_empty() and indices.size() % 3 == 0


func _find_body(body_id: StringName) -> Resource:
	if _state == null or body_id == StringName():
		return null
	var bodies: Array = _state.get("material_bodies") as Array
	for body_variant: Variant in bodies:
		var body := body_variant as Resource
		if body != null and StringName(body.get("body_id")) == body_id:
			return body
	return null


func _body_is_active_and_committed(body: Resource) -> bool:
	return (
		body != null
		and body.has_method("is_committed_to_layer")
		and bool(body.call("is_committed_to_layer"))
		and body.has_method("is_active_in_layer_stack")
		and bool(body.call("is_active_in_layer_stack"))
	)


func _count_active_committed_handles() -> int:
	var count := 0
	var bodies: Array = _state.get("material_bodies") as Array
	for body_variant: Variant in bodies:
		var body := body_variant as Resource
		if (
			body != null
			and StringName(body.get("body_kind"))
			== MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
			and _body_is_active_and_committed(body)
		):
			count += 1
	return count


func _fixture_paths_overlap(handle_body: Resource, ordinary_body: Resource) -> bool:
	if handle_body == null or ordinary_body == null:
		return false
	var handle_path: PackedVector3Array = handle_body.get("path_points")
	var ordinary_path: PackedVector3Array = ordinary_body.get("path_points")
	if handle_path.size() != 3 or ordinary_path.size() < 2:
		return false
	var ordinary_segment := ordinary_path[ordinary_path.size() - 1] - ordinary_path[0]
	var segment_length_squared := ordinary_segment.length_squared()
	if segment_length_squared <= 0.000000000001:
		return false
	var ratio := clampf(
		(handle_path[1] - ordinary_path[0]).dot(ordinary_segment)
		/ segment_length_squared,
		0.0,
		1.0
	)
	var nearest := ordinary_path[0] + ordinary_segment * ratio
	var combined_radius := (
		float(handle_body.get("radius_meters"))
		+ float(ordinary_body.get("radius_meters"))
	)
	return nearest.distance_to(handle_path[1]) < combined_radius


func _packet_summary(packet: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = packet.get("vertices", PackedVector3Array())
	var indices: PackedInt32Array = packet.get("indices", PackedInt32Array())
	return {
		"ok": bool(packet.get("ok", false)),
		"error_code": String(packet.get("error_code", "")),
		"reason": String(packet.get("reason", "")),
		"vertex_count": vertices.size(),
		"triangle_count": indices.size() / 3,
		"final_union_performed": bool(packet.get("final_union_performed", false)),
		"backend_method": String(packet.get("backend_method", "")),
	}


func _diagnostics_summary(diagnostics: Dictionary) -> Dictionary:
	return {
		"last_mode": String(diagnostics.get("last_mode", "")),
		"lifecycle": String(diagnostics.get("lifecycle", "")),
		"authoritative": bool(diagnostics.get("authoritative", false)),
		"publication_pending": bool(diagnostics.get("publication_pending", false)),
		"last_failure_reason": String(diagnostics.get("last_failure_reason", "")),
		"output_vertices": int(diagnostics.get("output_vertices", 0)),
		"output_triangles": int(diagnostics.get("output_triangles", 0)),
		"protected_composition_mode": String(diagnostics.get(
			"protected_composition_mode",
			""
		)),
	}


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _pass() -> void:
	_result_lines.append("ok=true")
	_write_results()
	print("Forge V2 StageController runtime export verifier passed")
	quit(0)


func _fail(message: String) -> void:
	_result_lines.append("FAIL: %s" % message)
	_result_lines.append("ok=false")
	_write_results()
	push_error(message)
	quit(1)


func _write_results() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_result_lines) + "\n")
