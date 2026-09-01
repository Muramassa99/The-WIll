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
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)
const PlayerForgeWipLibraryStateScript = preload(
	"res://core/models/player_forge_wip_library_state.gd"
)
const ForgeServiceScript = preload("res://services/forge_service.gd")
const TestPrintMeshBuilderScript = preload(
	"res://runtime/forge/test_print_mesh_builder.gd"
)
const PlayerEquippedItemPresenterScript = preload(
	"res://runtime/player/player_equipped_item_presenter.gd"
)
const DEFAULT_FORGE_RULES: ForgeRulesDef = preload(
	"res://core/defs/forge/forge_rules_default.tres"
)
const DEFAULT_FORGE_VIEW_TUNING: ForgeViewTuningDef = preload(
	"res://core/defs/forge/forge_view_tuning_default.tres"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_katana_downstream_continuity_2026-08-31.txt"
)
const TEMP_LIBRARY_PATH_PREFIX := (
	"user://verification/verify_forge_v2_katana_downstream_continuity"
)
const KATANA_PROFILE_LABEL := "katana_blade_body"
const CELL_SIZE_METERS := 0.0125
const HANDLE_START := Vector3(-0.32, 0.0, 0.0)
const HANDLE_MIDPOINT := Vector3(-0.16, 0.0, 0.0)
const HANDLE_END := Vector3(0.0, 0.0, 0.0)
const BLADE_LEFT := Vector3(-0.02, 0.0, 0.0)
const BLADE_RIGHT := Vector3(0.40, 0.0, 0.0)
const READINESS_FRAME_LIMIT := 480
const PLANE_EPSILON_METERS := 0.0003
const PROFILE_VECTOR_EPSILON_CELLS := 0.001
const HELD_VECTOR_EPSILON_METERS := 0.00002
const FINGERPRINT_BIAS_EPSILON := 0.04
const FINGERPRINT_ASPECT_EPSILON := 0.08

var _result_lines: PackedStringArray = []


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	_cleanup_all_temp_libraries()
	if not ClassDB.class_exists(&"ForgeV2ManifoldBoolean"):
		_fail("native ForgeV2ManifoldBoolean backend is unavailable")
		return
	var katana_profile := _load_katana_profile()
	if katana_profile.is_empty():
		_fail("saved katana_blade_body profile was not found")
		return
	if not ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
		katana_profile
	):
		_fail("saved katana_blade_body profile is not runtime-valid")
		return

	var cases: Array[Dictionary] = [
		{
			"id": &"forward",
			"points": PackedVector3Array([BLADE_LEFT, BLADE_RIGHT]),
		},
		{
			"id": &"reverse",
			"points": PackedVector3Array([BLADE_RIGHT, BLADE_LEFT]),
		},
	]
	for case_data: Dictionary in cases:
		var case_result := await _verify_case(
			StringName(case_data.get("id", StringName())),
			katana_profile,
			case_data.get("points", PackedVector3Array()) as PackedVector3Array
		)
		if not bool(case_result.get("ok", false)):
			_fail(String(case_result.get("error", "Katana continuity case failed")))
			return
		_result_lines.append(
			"%s.pending_fingerprint=%s"
			% [String(case_data.get("id", StringName())), str(case_result.get("fingerprint", {}))]
		)
		_result_lines.append(
			"%s.final_export_vertices=%d"
			% [String(case_data.get("id", StringName())), int(case_result.get("vertex_count", 0))]
		)

	_result_lines.append("PASS: forward and reversed Katana paths retained asymmetric orientation")
	_result_lines.append("PASS: save/reload and fresh ForgeService bake retained Tip/Pommel/slide axis")
	_result_lines.append("PASS: equipped-item mesh and metadata retained the saved Forge V2 contract")
	_result_lines.append("ok=true")
	_write_results()
	_cleanup_all_temp_libraries()
	print("Forge V2 Katana downstream continuity verifier passed")
	quit(0)


func _verify_case(
	case_id: StringName,
	katana_profile: Dictionary,
	ordered_blade_points: PackedVector3Array
) -> Dictionary:
	var controller: Node = StageControllerScript.new()
	controller.name = "KatanaContinuityController_%s" % String(case_id)
	root.add_child(controller)
	var presenter: Node3D = VolumePreviewPresenterScript.new()
	presenter.name = "KatanaContinuityPresenter_%s" % String(case_id)
	root.add_child(presenter)
	await process_frame
	presenter.call("bind_stage_controller", controller)
	await process_frame
	await physics_frame
	var state: Resource = controller.call("get_active_authoring_state") as Resource
	if state == null:
		return _case_error(case_id, "StageController did not create authoring state")

	var handle_result := await _author_committed_handle(controller, state)
	if not bool(handle_result.get("ok", false)):
		return _case_error(case_id, String(handle_result.get("error", "Handle authoring failed")))
	var handle_body: Resource = handle_result.get("body", null) as Resource
	var blade_result := _author_pending_katana(
		controller,
		state,
		katana_profile,
		ordered_blade_points
	)
	if not bool(blade_result.get("ok", false)):
		return _case_error(case_id, String(blade_result.get("error", "Katana authoring failed")))
	var blade_body: Resource = blade_result.get("body", null) as Resource
	var witness := _resolve_blade_witness(blade_body)
	if not bool(witness.get("ok", false)):
		return _case_error(case_id, String(witness.get("error", "Katana witness frame failed")))

	var pending_mesh := presenter.call(
		"_build_active_material_body_sweep_mesh",
		blade_body
	) as ArrayMesh
	var pending_fingerprint := _build_asymmetric_fingerprint(
		pending_mesh,
		witness.get("origin", Vector3.ZERO) as Vector3,
		witness.get("tangent", Vector3.RIGHT) as Vector3,
		witness.get("axis_x", Vector3.UP) as Vector3,
		witness.get("axis_y", Vector3.FORWARD) as Vector3,
		PLANE_EPSILON_METERS
	)
	if not bool(pending_fingerprint.get("valid", false)):
		return _case_error(case_id, "pending Katana cap fingerprint is unavailable")
	if absf(float(pending_fingerprint.get("x_bias", 0.0))) < 0.15:
		return _case_error(
			case_id,
			"pending Katana witness is not sufficiently asymmetric: %s"
			% str(pending_fingerprint)
		)

	var layer: Resource = controller.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	if layer == null or not _body_is_active_and_committed(blade_body):
		return _case_error(case_id, "Katana body did not commit")
	var ready := await _await_runtime_export_ready(state, presenter)
	if not bool(ready.get("ok", false)):
		return _case_error(
			case_id,
			"native final export did not become ready: %s"
			% str(ready.get("summary", {}))
		)
	var final_packet: Dictionary = ready.get("packet", {}) as Dictionary
	if not bool(final_packet.get("final_union_performed", false)):
		return _case_error(case_id, "Handle/Katana final export skipped final union")
	var final_mesh := _build_mesh_from_packet(final_packet)
	if not _expect_fingerprint(
		case_id,
		"native_final_export",
		pending_fingerprint,
		_build_asymmetric_fingerprint(
			final_mesh,
			witness.get("origin", Vector3.ZERO) as Vector3,
			witness.get("tangent", Vector3.RIGHT) as Vector3,
			witness.get("axis_x", Vector3.UP) as Vector3,
			witness.get("axis_y", Vector3.FORWARD) as Vector3,
			PLANE_EPSILON_METERS
		)
	):
		return _case_error(case_id, "native final export changed Katana orientation")

	var wip: CraftedItemWIP = controller.call(
		"build_crafted_item_wip_for_save",
		StringName("verify_katana_continuity_%s" % String(case_id)),
		"Katana Continuity %s" % String(case_id),
		final_packet
	) as CraftedItemWIP
	if not _wip_has_valid_runtime_contract(wip):
		return _case_error(case_id, "StageController save builder produced an invalid WIP contract")
	var saved_profile: BakedProfile = wip.latest_baked_profile_snapshot
	var stage2_mesh := _build_mesh_from_stage2(wip.stage2_item_state)
	if not _expect_fingerprint(
		case_id,
		"stage2_save",
		pending_fingerprint,
		_build_asymmetric_fingerprint(
			stage2_mesh,
			(witness.get("origin", Vector3.ZERO) as Vector3) / CELL_SIZE_METERS,
			witness.get("tangent", Vector3.RIGHT) as Vector3,
			witness.get("axis_x", Vector3.UP) as Vector3,
			witness.get("axis_y", Vector3.FORWARD) as Vector3,
			PLANE_EPSILON_METERS / CELL_SIZE_METERS
		)
	):
		return _case_error(case_id, "Stage2 save mesh changed Katana orientation")

	var library_path := _temp_library_path(case_id)
	_cleanup_temp_library(library_path)
	var library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library.save_file_path = library_path
	var persisted_wip: CraftedItemWIP = library.save_wip(wip)
	if persisted_wip == null or not FileAccess.file_exists(library_path):
		return _case_error(case_id, "temporary WIP library save failed")
	var reloaded_library: PlayerForgeWipLibraryState = ResourceLoader.load(
		library_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PlayerForgeWipLibraryState
	if reloaded_library == null:
		return _case_error(case_id, "temporary WIP library reload failed")
	var reloaded_wip: CraftedItemWIP = reloaded_library.get_saved_wip_clone(
		persisted_wip.wip_id,
		true
	)
	if not _wip_has_valid_runtime_contract(reloaded_wip):
		return _case_error(case_id, "WIP library roundtrip lost the runtime contract")
	if not _profiles_preserve_semantics(saved_profile, reloaded_wip.latest_baked_profile_snapshot):
		return _case_error(case_id, "WIP library roundtrip changed Tip/Pommel/slide axis")
	if not _expect_fingerprint(
		case_id,
		"library_reload",
		pending_fingerprint,
		_build_asymmetric_fingerprint(
			_build_mesh_from_stage2(reloaded_wip.stage2_item_state),
			(witness.get("origin", Vector3.ZERO) as Vector3) / CELL_SIZE_METERS,
			witness.get("tangent", Vector3.RIGHT) as Vector3,
			witness.get("axis_x", Vector3.UP) as Vector3,
			witness.get("axis_y", Vector3.FORWARD) as Vector3,
			PLANE_EPSILON_METERS / CELL_SIZE_METERS
		)
	):
		return _case_error(case_id, "library reload mesh changed Katana orientation")

	var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES)
	var fresh_profile: BakedProfile = forge_service.bake_wip(reloaded_wip, {})
	if fresh_profile == null or not fresh_profile.primary_grip_valid:
		return _case_error(case_id, "fresh ForgeService bake rejected the saved WIP")
	if not _profiles_preserve_semantics(saved_profile, fresh_profile):
		return _case_error(case_id, "fresh ForgeService bake changed Tip/Pommel/slide axis")

	var mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
	var equipped_presenter: PlayerEquippedItemPresenter = (
		PlayerEquippedItemPresenterScript.new()
	)
	var held_item: Node3D = equipped_presenter.build_equipped_item_node(
		reloaded_wip,
		&"hand_right",
		forge_service,
		{},
		mesh_builder,
		null,
		DEFAULT_FORGE_RULES,
		DEFAULT_FORGE_VIEW_TUNING,
		true
	)
	if held_item == null:
		return _case_error(case_id, "equipped-item presenter rejected the reloaded WIP")
	var mesh_instance := _find_first_mesh_instance(held_item)
	if mesh_instance == null or mesh_instance.mesh == null:
		held_item.free()
		return _case_error(case_id, "equipped-item presenter produced no mesh")
	if not _expect_fingerprint(
		case_id,
		"equipped_mesh",
		pending_fingerprint,
		_build_asymmetric_fingerprint(
			mesh_instance.mesh,
			(witness.get("origin", Vector3.ZERO) as Vector3) / CELL_SIZE_METERS,
			witness.get("tangent", Vector3.RIGHT) as Vector3,
			witness.get("axis_x", Vector3.UP) as Vector3,
			witness.get("axis_y", Vector3.FORWARD) as Vector3,
			PLANE_EPSILON_METERS / CELL_SIZE_METERS
		)
	):
		held_item.free()
		return _case_error(case_id, "equipped mesh changed Katana orientation")
	if not _held_metadata_preserves_semantics(
		held_item,
		mesh_instance,
		fresh_profile
	):
		held_item.free()
		return _case_error(case_id, "equipped metadata changed Tip/Pommel/slide axis")

	held_item.free()
	controller.queue_free()
	presenter.queue_free()
	await process_frame
	_cleanup_temp_library(library_path)
	return {
		"ok": true,
		"fingerprint": pending_fingerprint,
		"vertex_count": (final_packet.get("vertices", PackedVector3Array()) as PackedVector3Array).size(),
		"handle_body_id": StringName(handle_body.get("body_id")),
	}


func _author_committed_handle(controller: Node, state: Resource) -> Dictionary:
	var profile_entries: Array[Dictionary] = ProfileShapeLibraryScript.build_handle_profile_entries()
	if profile_entries.is_empty():
		return {"ok": false, "error": "no Handle profile is available"}
	var profile_id := StringName(profile_entries[0].get("id", StringName()))
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_HANDLES)
	controller.call("set_active_profile_id", profile_id)
	for point: Vector3 in [HANDLE_START, HANDLE_MIDPOINT, HANDLE_END]:
		if int(controller.call("append_spline_line_point", point, Vector3.UP)) < 0:
			return {"ok": false, "error": "Handle point was rejected"}
	if not bool(controller.call("generate_profile_extrusion_from_spline")):
		return {"ok": false, "error": "Handle extrusion did not generate"}
	var body: Resource = state.call("get_selected_material_body") as Resource
	if (
		body == null
		or StringName(body.get("body_kind")) != MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
	):
		return {"ok": false, "error": "generated body is not a Handle"}
	var layer: Resource = controller.call("commit_pending_material_bodies_as_layer") as Resource
	if layer == null or not _body_is_active_and_committed(body):
		return {"ok": false, "error": "Handle did not commit"}
	await process_frame
	await physics_frame
	return {"ok": true, "body": body}


func _author_pending_katana(
	controller: Node,
	state: Resource,
	katana_profile: Dictionary,
	ordered_points: PackedVector3Array
) -> Dictionary:
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_SPLINE_LINE)
	controller.call("set_active_material_variant_id", &"mat_iron_gray")
	if not bool(controller.call("select_active_saved_basic_profile", katana_profile)):
		return {"ok": false, "error": "Katana saved profile selection failed"}
	for point: Vector3 in ordered_points:
		if int(controller.call("append_spline_line_point", point, Vector3.UP)) < 0:
			return {"ok": false, "error": "Katana spline point was rejected"}
	if not bool(controller.call("generate_spline_line_csg_noodle")):
		return {"ok": false, "error": "Katana CSG noodle did not generate"}
	var body: Resource = state.call("get_selected_material_body") as Resource
	if (
		body == null
		or String(body.get("profile_display_name")) != KATANA_PROFILE_LABEL
		or StringName(body.get("shape_kind")) != MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	):
		return {"ok": false, "error": "generated body is not the Katana spline profile"}
	return {"ok": true, "body": body}


func _resolve_blade_witness(blade_body: Resource) -> Dictionary:
	var points: PackedVector3Array = blade_body.get("path_points")
	var normals: PackedVector3Array = blade_body.get("path_surface_normals")
	if points.size() < 2:
		return {"ok": false, "error": "Katana path has fewer than two points"}
	var witness_index := 0
	for point_index: int in range(1, points.size()):
		if points[point_index].x > points[witness_index].x:
			witness_index = point_index
	var tangent := (
		(points[1] - points[0]).normalized()
		if witness_index == 0
		else (points[witness_index] - points[witness_index - 1]).normalized()
	)
	var surface_normal := (
		normals[witness_index]
		if witness_index < normals.size()
		else Vector3.UP
	)
	var frame := ProfileShapeLibraryScript.resolve_profile_path_frame(
		tangent,
		surface_normal,
		blade_body.get("profile_contact_direction_2d") as Vector2,
		float(blade_body.get("profile_rotation_bias_degrees"))
	)
	var axis_x := frame.get("axis_x", Vector3.ZERO) as Vector3
	var axis_y := frame.get("axis_y", Vector3.ZERO) as Vector3
	if tangent.length_squared() < 0.9 or axis_x.length_squared() < 0.9 or axis_y.length_squared() < 0.9:
		return {"ok": false, "error": "Katana witness frame is degenerate"}
	return {
		"ok": true,
		"origin": points[witness_index],
		"tangent": tangent,
		"axis_x": axis_x,
		"axis_y": axis_y,
	}


func _await_runtime_export_ready(state: Resource, presenter: Node3D) -> Dictionary:
	var last_packet: Dictionary = {}
	var last_diagnostics: Dictionary = {}
	for _frame_index: int in range(READINESS_FRAME_LIMIT):
		await process_frame
		await physics_frame
		last_diagnostics = presenter.call("get_native_static_sync_diagnostics") as Dictionary
		last_packet = state.call("request_runtime_contract_mesh_export") as Dictionary
		var vertices: PackedVector3Array = last_packet.get("vertices", PackedVector3Array())
		var indices: PackedInt32Array = last_packet.get("indices", PackedInt32Array())
		if (
			bool(last_packet.get("ok", false))
			and not vertices.is_empty()
			and not indices.is_empty()
			and indices.size() % 3 == 0
			and not bool(last_diagnostics.get("publication_pending", true))
			and bool(last_packet.get("final_union_performed", false))
		):
			return {"ok": true, "packet": last_packet}
	return {
		"ok": false,
		"summary": {
			"packet_ok": bool(last_packet.get("ok", false)),
			"packet_error": String(last_packet.get("error_code", "")),
			"vertex_count": (last_packet.get("vertices", PackedVector3Array()) as PackedVector3Array).size(),
			"triangle_count": (last_packet.get("indices", PackedInt32Array()) as PackedInt32Array).size() / 3,
			"final_union_performed": bool(last_packet.get("final_union_performed", false)),
			"backend_method": String(last_packet.get("backend_method", "")),
			"lifecycle": String(last_diagnostics.get("lifecycle", "")),
			"publication_pending": bool(last_diagnostics.get("publication_pending", false)),
			"failure": String(last_diagnostics.get("last_failure_reason", "")),
		},
	}


func _build_mesh_from_packet(packet: Dictionary) -> ArrayMesh:
	var vertices: PackedVector3Array = packet.get("vertices", PackedVector3Array())
	var indices: PackedInt32Array = packet.get("indices", PackedInt32Array())
	var mesh := ArrayMesh.new()
	if vertices.is_empty() or indices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_mesh_from_stage2(stage2_state: Resource) -> ArrayMesh:
	if stage2_state == null:
		return ArrayMesh.new()
	var editable_state: Resource = stage2_state.get("current_editable_mesh_state") as Resource
	if editable_state == null or not editable_state.has_method("build_array_mesh"):
		return ArrayMesh.new()
	return editable_state.call("build_array_mesh") as ArrayMesh


func _build_asymmetric_fingerprint(
	mesh: Mesh,
	plane_origin: Vector3,
	plane_normal: Vector3,
	axis_x: Vector3,
	axis_y: Vector3,
	plane_epsilon: float
) -> Dictionary:
	if mesh == null:
		return {"valid": false}
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var point_count := 0
	for surface_index: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var offset := vertex - plane_origin
			if absf(offset.dot(plane_normal)) > plane_epsilon:
				continue
			var coordinate := Vector2(offset.dot(axis_x), offset.dot(axis_y))
			minimum.x = minf(minimum.x, coordinate.x)
			minimum.y = minf(minimum.y, coordinate.y)
			maximum.x = maxf(maximum.x, coordinate.x)
			maximum.y = maxf(maximum.y, coordinate.y)
			point_count += 1
	var span := maximum - minimum
	if point_count < 3 or span.x <= 0.000001 or span.y <= 0.000001:
		return {"valid": false, "point_count": point_count}
	return {
		"valid": true,
		"point_count": point_count,
		"x_bias": (maximum.x + minimum.x) / span.x,
		"y_bias": (maximum.y + minimum.y) / span.y,
		"aspect": span.x / span.y,
	}


func _expect_fingerprint(
	case_id: StringName,
	stage_name: String,
	authority: Dictionary,
	candidate: Dictionary
) -> bool:
	if not bool(candidate.get("valid", false)):
		_result_lines.append(
			"FAIL: %s %s fingerprint unavailable: %s"
			% [String(case_id), stage_name, str(candidate)]
		)
		return false
	var authority_x_bias := float(authority.get("x_bias", 0.0))
	var candidate_x_bias := float(candidate.get("x_bias", 0.0))
	var authority_y_bias := float(authority.get("y_bias", 0.0))
	var candidate_y_bias := float(candidate.get("y_bias", 0.0))
	var authority_aspect := float(authority.get("aspect", 0.0))
	var candidate_aspect := float(candidate.get("aspect", 0.0))
	var matches := (
		authority_x_bias * candidate_x_bias > 0.0
		and absf(authority_x_bias - candidate_x_bias) <= FINGERPRINT_BIAS_EPSILON
		and absf(authority_y_bias - candidate_y_bias) <= FINGERPRINT_BIAS_EPSILON
		and absf(authority_aspect - candidate_aspect)
		<= maxf(authority_aspect, 1.0) * FINGERPRINT_ASPECT_EPSILON
	)
	if not matches:
		_result_lines.append(
			"FAIL: %s %s fingerprint changed: pending=%s candidate=%s"
			% [String(case_id), stage_name, str(authority), str(candidate)]
		)
	return matches


func _profiles_preserve_semantics(authority: BakedProfile, candidate: BakedProfile) -> bool:
	return (
		authority != null
		and candidate != null
		and candidate.primary_grip_valid
		and authority.weapon_tip_point.distance_to(candidate.weapon_tip_point)
		<= PROFILE_VECTOR_EPSILON_CELLS
		and authority.weapon_pommel_point.distance_to(candidate.weapon_pommel_point)
		<= PROFILE_VECTOR_EPSILON_CELLS
		and authority.primary_grip_slide_axis.normalized().dot(
			candidate.primary_grip_slide_axis.normalized()
		) >= 0.99999
	)


func _held_metadata_preserves_semantics(
	held_item: Node3D,
	mesh_instance: MeshInstance3D,
	profile: BakedProfile
) -> bool:
	var grip_center_cells := -mesh_instance.position / CELL_SIZE_METERS
	var expected_tip := (profile.weapon_tip_point - grip_center_cells) * CELL_SIZE_METERS
	var expected_pommel := (profile.weapon_pommel_point - grip_center_cells) * CELL_SIZE_METERS
	var held_tip := held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var held_pommel := held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
	var held_axis := held_item.get_meta("primary_grip_slide_axis_local", Vector3.ZERO) as Vector3
	return (
		held_tip.distance_to(expected_tip) <= HELD_VECTOR_EPSILON_METERS
		and held_pommel.distance_to(expected_pommel) <= HELD_VECTOR_EPSILON_METERS
		and held_axis.normalized().dot(profile.primary_grip_slide_axis.normalized())
		>= 0.99999
	)


func _wip_has_valid_runtime_contract(wip: CraftedItemWIP) -> bool:
	return (
		wip != null
		and wip.stage2_item_state != null
		and wip.latest_baked_profile_snapshot != null
		and wip.latest_baked_profile_snapshot.primary_grip_valid
		and wip.latest_baked_profile_snapshot.validation_error.is_empty()
		and bool(wip.stage2_item_state.get("editable_mesh_visual_authority"))
		and bool(wip.stage2_item_state.call("has_current_editable_mesh"))
	)


func _find_first_mesh_instance(parent_node: Node) -> MeshInstance3D:
	if parent_node == null:
		return null
	for child: Node in parent_node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
		var nested := _find_first_mesh_instance(child)
		if nested != null:
			return nested
	return null


func _body_is_active_and_committed(body: Resource) -> bool:
	return (
		body != null
		and body.has_method("is_committed_to_layer")
		and bool(body.call("is_committed_to_layer"))
		and body.has_method("is_active_in_layer_stack")
		and bool(body.call("is_active_in_layer_stack"))
	)


func _load_katana_profile() -> Dictionary:
	var library: Resource = ResourceLoader.load(
		PlayerToolProfileLibraryStateScript.DEFAULT_SAVE_FILE_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	if library == null or not library.has_method("get_saved_profiles"):
		return {}
	var profiles: Array = library.call(
		"get_saved_profiles",
		ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
	) as Array
	for profile_variant: Variant in profiles:
		var profile := profile_variant as Dictionary
		if String(profile.get("label", "")).strip_edges().to_lower() == KATANA_PROFILE_LABEL:
			return profile.duplicate(true)
	return {}


func _temp_library_path(case_id: StringName) -> String:
	return "%s_%s.tres" % [TEMP_LIBRARY_PATH_PREFIX, String(case_id)]


func _cleanup_all_temp_libraries() -> void:
	for case_id: StringName in [&"forward", &"reverse"]:
		_cleanup_temp_library(_temp_library_path(case_id))


func _cleanup_temp_library(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _case_error(case_id: StringName, message: String) -> Dictionary:
	return {"ok": false, "error": "%s: %s" % [String(case_id), message]}


func _fail(message: String) -> void:
	_result_lines.append("FAIL: %s" % message)
	_result_lines.append("ok=false")
	_write_results()
	_cleanup_all_temp_libraries()
	push_error(message)
	quit(1)


func _write_results() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_result_lines) + "\n")
