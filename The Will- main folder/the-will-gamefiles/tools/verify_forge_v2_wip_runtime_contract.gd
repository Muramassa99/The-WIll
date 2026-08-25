extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2WipCompatibilityAdapterScript = preload(
	"res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd"
)
const PrimaryGripHandleMeshPacketScript = preload(
	"res://core/resolvers/primary_grip_handle_mesh_packet.gd"
)
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
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
const CombatAnimationStationPreviewPresenterScript = preload(
	"res://runtime/combat/combat_animation_station_preview_presenter.gd"
)
const DEFAULT_FORGE_RULES: ForgeRulesDef = preload(
	"res://core/defs/forge/forge_rules_default.tres"
)
const DEFAULT_FORGE_VIEW_TUNING: ForgeViewTuningDef = preload(
	"res://core/defs/forge/forge_view_tuning_default.tres"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/verify_forge_v2_wip_runtime_contract_2026-08-22.txt"
)
const TEMP_LIBRARY_PATH := (
	"user://verification/verify_forge_v2_wip_runtime_contract_library.tres"
)
const CELL_SIZE_METERS := 0.0125
const HANDLE_START := Vector3(0.0, 0.0, 0.0)
const HANDLE_MIDPOINT := Vector3(0.16, 0.0, 0.0)
const HANDLE_END := Vector3(0.32, 0.0, 0.0)
const DIAGONAL_HANDLE_START := Vector3(-0.15, -0.10, -0.05)
const DIAGONAL_HANDLE_MIDPOINT := Vector3.ZERO
const DIAGONAL_HANDLE_END := Vector3(0.15, 0.10, 0.05)

var result_lines: PackedStringArray = []


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	_cleanup_temp_library()

	var handle_fixture: Dictionary = _build_committed_handle_fixture()
	if not _expect(bool(handle_fixture.get("valid", false)), String(
		handle_fixture.get("error", "could not build committed Handle fixture")
	)):
		return
	var authoring_state: Resource = handle_fixture.get("state") as Resource
	var handle_body: Resource = handle_fixture.get("handle_body") as Resource
	if not _expect(authoring_state != null, "Handle fixture has no authoring state"):
		return
	if not _expect(handle_body != null, "Handle fixture has no Handle body"):
		return
	if not _expect(
		StringName(handle_body.get("body_kind"))
		== ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE,
		"fixture body is not semantically authorized as a Handle"
	):
		return
	if not _expect(
		bool(handle_body.call("is_committed_to_layer"))
		and bool(handle_body.call("is_active_in_layer_stack")),
		"Handle body is not active and committed"
	):
		return
	if not _expect(
		int(authoring_state.call("get_material_body_count")) == 1
		and int(authoring_state.call("get_pending_material_body_count")) == 0,
		"Handle fixture is not exactly one active body with no pending bodies"
	):
		return

	var wip: CraftedItemWIP = _build_wip_from_state(
		authoring_state,
		&"verify_forge_v2_runtime_contract"
	)
	var final_mesh_packet := _authorize_primary_grip_handle_packet(
		_build_watertight_box_packet(),
		handle_body
	)
	var contract: Dictionary = ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
		wip,
		final_mesh_packet,
		CELL_SIZE_METERS
	)
	if not _expect(
		bool(contract.get("valid", false)),
		"valid V2 Handle contract was rejected: %s" % String(contract.get("error", ""))
	):
		return
	wip.stage2_item_state = contract.get("stage2_item_state") as Resource
	wip.latest_baked_profile_snapshot = contract.get("baked_profile") as BakedProfile
	if not _expect(
		wip.stage2_item_state != null
		and wip.stage2_item_state.has_method("has_current_editable_mesh")
		and bool(wip.stage2_item_state.call("has_current_editable_mesh"))
		and bool(wip.stage2_item_state.get("editable_mesh_visual_authority")),
		"adapter did not produce an authoritative Stage2 editable mesh"
	):
		return
	if not _expect(
		wip.latest_baked_profile_snapshot != null
		and wip.latest_baked_profile_snapshot.primary_grip_valid,
		"adapter did not produce a valid cached BakedProfile"
	):
		return
	if not _verify_v2_grip_profile_contract(
		wip.latest_baked_profile_snapshot,
		StringName(handle_body.get("body_id")),
		HANDLE_MIDPOINT
	):
		return
	if not _verify_authored_grip_metadata(wip, wip.latest_baked_profile_snapshot, handle_body):
		return
	if not _verify_interior_profile_cell_centers(
		wip.latest_baked_profile_snapshot,
		handle_body
	):
		return
	result_lines.append(
		"PASS: authored profile persisted and final-CSG grip frame/collision slice exported correctly"
	)
	result_lines.append(
		"PASS: adapter finalized one active committed 3-point Handle"
	)
	if not _verify_skill_crafter_cached_profile_refresh(wip):
		return
	result_lines.append(
		"PASS: Skill Crafter refreshed V2 material data once and preserved V1 cache behavior"
	)

	var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES)
	var freshly_baked_profile: BakedProfile = forge_service.bake_wip(wip, {})
	if not _expect(
		freshly_baked_profile != null
		and freshly_baked_profile.primary_grip_valid
		and not freshly_baked_profile.material_runtime_data_resolved,
		"fresh empty-lookup bake lost the V2 profile or falsely marked material data resolved"
	):
		return
	if not _verify_v2_grip_profile_contract(
		freshly_baked_profile,
		StringName(handle_body.get("body_id")),
		HANDLE_MIDPOINT
	):
		return
	result_lines.append(
		"PASS: fresh ForgeService bake retained the V2 grip contract"
	)

	var test_print: TestPrintInstance = forge_service.build_test_print_from_wip(wip, {})
	if not _expect(test_print != null, "ForgeService did not build a V2 TestPrintInstance"):
		return
	if not _expect(
		test_print.visual_mesh_source == &"editable_mesh"
		and test_print.stage2_item_state != null
		and bool(test_print.stage2_item_state.get("editable_mesh_visual_authority"))
		and bool(test_print.stage2_item_state.call("has_current_editable_mesh")),
		"TestPrintInstance does not retain authoritative editable-mesh visuals"
	):
		return
	if not _expect(
		test_print.canonical_geometry != null
		and test_print.canonical_geometry.has_method("is_empty")
		and not bool(test_print.canonical_geometry.call("is_empty")),
		"TestPrintInstance canonical geometry is empty"
	):
		return

	var mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
	var runtime_mesh: ArrayMesh = mesh_builder.build_mesh_from_test_print(test_print, {})
	if not _expect(
		runtime_mesh != null and runtime_mesh.get_surface_count() > 0,
		"existing TestPrint mesh channel did not build the V2 mesh"
	):
		return
	if not _verify_mesh_meter_scale(runtime_mesh):
		return
	if not _verify_existing_equipped_presenter_channel(
		wip,
		forge_service,
		mesh_builder
	):
		return
	result_lines.append(
		"PASS: TestPrint and equipped-item channels retained mesh, scale, and grip basis"
	)
	if not _verify_diagonal_handle_runtime_contract():
		return
	result_lines.append(
		"PASS: diagonal Handle retained exact orthogonal authored basis and valid equip/grip"
	)
	if not _verify_face_duplicated_single_unit_acceptance(wip, handle_body):
		return
	result_lines.append(
		"PASS: coincident face-duplicated vertices weld into one valid final unit"
	)
	if not _verify_disconnected_final_mesh_rejection(wip, handle_body):
		return
	result_lines.append(
		"PASS: disconnected two-box final mesh was rejected while retaining diagnostic Stage2 mesh"
	)

	var empty_state: Resource = ForgeV2AuthoringStateScript.new()
	empty_state.call("reset_new_draft", "V2 Empty Invalid Fixture")
	var empty_wip: CraftedItemWIP = _build_wip_from_state(
		empty_state,
		&"verify_forge_v2_empty_invalid"
	)
	var empty_contract: Dictionary = (
		ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
			empty_wip,
			final_mesh_packet,
			CELL_SIZE_METERS
		)
	)
	if not _expect(
		not bool(empty_contract.get("valid", false))
		and not String(empty_contract.get("error", "")).is_empty(),
		"no-Handle V2 authoring state incorrectly produced a runtime contract"
	):
		return

	var noodle_fixture: Dictionary = _build_committed_noodle_fixture()
	if not _expect(
		bool(noodle_fixture.get("valid", false)),
		String(noodle_fixture.get("error", "could not build noodle-only fixture"))
	):
		return
	var noodle_wip: CraftedItemWIP = _build_wip_from_state(
		noodle_fixture.get("state") as Resource,
		&"verify_forge_v2_noodle_invalid"
	)
	var noodle_contract: Dictionary = (
		ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
			noodle_wip,
			final_mesh_packet,
			CELL_SIZE_METERS
		)
	)
	if not _expect(
		not bool(noodle_contract.get("valid", false))
		and not String(noodle_contract.get("error", "")).is_empty(),
		"committed noodle without a Handle incorrectly produced a runtime contract"
	):
		return
	result_lines.append(
		"PASS: empty and noodle-only V2 states remain runtime-invalid"
	)

	if not _verify_temp_save_reload(wip):
		return
	result_lines.append(
		"PASS: temporary WIP library round-trip retained the complete runtime contract"
	)

	result_lines.append("ok=true")
	_write_results()
	_cleanup_temp_library()
	print("Forge V2 WIP runtime contract verifier passed")
	quit(0)


func _build_committed_handle_fixture() -> Dictionary:
	return _build_committed_handle_fixture_for_points(
		PackedVector3Array([
			HANDLE_START,
			HANDLE_MIDPOINT,
			HANDLE_END,
		]),
		"V2 WIP Runtime Contract Fixture"
	)


func _build_committed_handle_fixture_for_points(
	handle_points: PackedVector3Array,
	project_name: String
) -> Dictionary:
	if handle_points.size() != 3:
		return {"valid": false, "error": "Handle fixture requires exactly 3 points"}
	var profile_entries: Array[Dictionary] = (
		ForgeV2ProfileShapeLibraryScript.build_handle_profile_entries()
	)
	if profile_entries.is_empty():
		return {"valid": false, "error": "no Handle profile entries are available"}
	var profile_id: StringName = StringName(
		profile_entries[0].get("id", StringName())
	)
	if profile_id == StringName():
		return {"valid": false, "error": "default Handle profile id is empty"}
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", project_name)
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	state.call("set_active_profile_id", profile_id)
	for point: Vector3 in handle_points:
		if int(state.call("append_spline_line_point", point, Vector3.UP)) < 0:
			return {"valid": false, "error": "Handle fixture rejected a control point"}
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		return {"valid": false, "error": "Handle profile extrusion did not generate"}
	var handle_body: Resource = state.call("get_selected_material_body") as Resource
	if handle_body == null:
		return {"valid": false, "error": "generated Handle body is missing"}
	var path_points: PackedVector3Array = handle_body.get("path_points")
	var profile_polygon: PackedVector2Array = handle_body.get(
		"profile_polygon_2d_meters"
	)
	if path_points.size() != 3 or profile_polygon.size() < 3:
		return {
			"valid": false,
			"error": "generated Handle lacks its 3-point path or profile polygon",
		}
	var committed_layer: Resource = state.call(
		"commit_material_body_as_layer",
		StringName(handle_body.get("body_id"))
	) as Resource
	if committed_layer == null:
		return {"valid": false, "error": "generated Handle did not commit"}
	return {
		"valid": true,
		"state": state,
		"handle_body": handle_body,
	}


func _build_committed_noodle_fixture() -> Dictionary:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "V2 Noodle-Only Invalid Fixture")
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_VOLUME_STROKE)
	state.call("append_spline_line_point", HANDLE_START, Vector3.UP)
	state.call("append_spline_line_point", HANDLE_END, Vector3.UP)
	if not bool(state.call("generate_spline_line_csg_noodle")):
		return {"valid": false, "error": "ordinary noodle did not generate"}
	var noodle_body: Resource = state.call("get_selected_material_body") as Resource
	if noodle_body == null:
		return {"valid": false, "error": "generated noodle body is missing"}
	if StringName(noodle_body.get("body_kind")) == ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE:
		return {"valid": false, "error": "ordinary noodle unexpectedly became a Handle"}
	var committed_layer: Resource = state.call(
		"commit_material_body_as_layer",
		StringName(noodle_body.get("body_id"))
	) as Resource
	if committed_layer == null:
		return {"valid": false, "error": "ordinary noodle did not commit"}
	return {"valid": true, "state": state}


func _build_wip_from_state(
	authoring_state: Resource,
	wip_id: StringName
) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = wip_id
	wip.forge_project_name = "Forge V2 Runtime Contract Verification"
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_builder_path_id = CraftedItemWIPScript.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.layers = []
	wip.forge_v2_authoring_state = (
		authoring_state.duplicate(true) as Resource
		if authoring_state != null
		else null
	)
	wip.ensure_combat_animation_station_state()
	return wip


func _build_watertight_box_packet() -> Dictionary:
	var vertices := PackedVector3Array([
		Vector3(0.0, -0.025, -0.02),
		Vector3(0.32, -0.025, -0.02),
		Vector3(0.32, 0.025, -0.02),
		Vector3(0.0, 0.025, -0.02),
		Vector3(0.0, -0.025, 0.02),
		Vector3(0.32, -0.025, 0.02),
		Vector3(0.32, 0.025, 0.02),
		Vector3(0.0, 0.025, 0.02),
	])
	var indices := PackedInt32Array([
		0, 2, 1, 0, 3, 2,
		4, 5, 6, 4, 6, 7,
		0, 4, 7, 0, 7, 3,
		1, 2, 6, 1, 6, 5,
		0, 1, 5, 0, 5, 4,
		3, 7, 6, 3, 6, 2,
	])
	return {
		"ok": true,
		"vertices": vertices,
		"indices": indices,
		"primary_grip_handle_vertices": PackedVector3Array(vertices),
		"primary_grip_handle_indices": PackedInt32Array(indices),
		"primary_grip_handle_mesh_source": (
			PrimaryGripHandleMeshPacketScript.SOURCE
		),
		"watertight": true,
		"output_volume_m3": 0.32 * 0.05 * 0.04,
		"source_original_ids": PackedStringArray(["verify_handle"]),
		"material_variant_id": &"mat_iron_gray",
		"source_state_revision": 1,
	}


func _build_oriented_handle_box_packet(handle_body: Resource) -> Dictionary:
	var path_points: PackedVector3Array = handle_body.get("path_points")
	var profile_polygon: PackedVector2Array = handle_body.get(
		"profile_polygon_2d_meters"
	)
	var frame := _resolve_authored_handle_frame(handle_body)
	var minor_axis_a: Vector3 = frame.get("axis_x", Vector3.UP)
	var minor_axis_b: Vector3 = frame.get("axis_y", Vector3.FORWARD)
	var bounds := ForgeV2ProfileShapeLibraryScript.calculate_polygon_bounds(
		profile_polygon
	)
	var start := path_points[0]
	var end := path_points[2]
	var min_a := bounds.position.x
	var max_a := bounds.end.x
	var min_b := bounds.position.y
	var max_b := bounds.end.y
	var vertices := PackedVector3Array([
		start + minor_axis_a * min_a + minor_axis_b * min_b,
		end + minor_axis_a * min_a + minor_axis_b * min_b,
		end + minor_axis_a * max_a + minor_axis_b * min_b,
		start + minor_axis_a * max_a + minor_axis_b * min_b,
		start + minor_axis_a * min_a + minor_axis_b * max_b,
		end + minor_axis_a * min_a + minor_axis_b * max_b,
		end + minor_axis_a * max_a + minor_axis_b * max_b,
		start + minor_axis_a * max_a + minor_axis_b * max_b,
	])
	return {
		"ok": true,
		"vertices": vertices,
		"indices": _build_box_triangle_indices(),
		"primary_grip_handle_vertices": PackedVector3Array(vertices),
		"primary_grip_handle_indices": _build_box_triangle_indices(),
		"primary_grip_handle_mesh_source": (
			PrimaryGripHandleMeshPacketScript.SOURCE
		),
		"primary_grip_handle_body_signature": (
			PrimaryGripHandleMeshPacketScript.build_body_signature(handle_body)
		),
		"watertight": true,
		"output_volume_m3": (
			start.distance_to(end) * bounds.size.x * bounds.size.y
		),
		"source_original_ids": PackedStringArray(["verify_diagonal_handle"]),
		"material_variant_id": &"mat_iron_gray",
		"source_state_revision": 2,
	}


func _build_disconnected_two_box_packet() -> Dictionary:
	var first_box := _build_watertight_box_packet()
	var first_vertices: PackedVector3Array = first_box.get(
		"vertices",
		PackedVector3Array()
	)
	var first_indices: PackedInt32Array = first_box.get(
		"indices",
		PackedInt32Array()
	)
	var vertices := PackedVector3Array(first_vertices)
	for vertex: Vector3 in first_vertices:
		vertices.append(vertex + Vector3(0.0, 0.20, 0.0))
	var indices := PackedInt32Array(first_indices)
	for vertex_index: int in first_indices:
		indices.append(vertex_index + first_vertices.size())
	return {
		"ok": true,
		"vertices": vertices,
		"indices": indices,
		"primary_grip_handle_vertices": PackedVector3Array(first_box.get(
			"primary_grip_handle_vertices",
			PackedVector3Array()
		)),
		"primary_grip_handle_indices": PackedInt32Array(first_box.get(
			"primary_grip_handle_indices",
			PackedInt32Array()
		)),
		"primary_grip_handle_mesh_source": (
			PrimaryGripHandleMeshPacketScript.SOURCE
		),
		"watertight": true,
		"output_volume_m3": 2.0 * 0.32 * 0.05 * 0.04,
		"source_original_ids": PackedStringArray([
			"verify_disconnected_box_a",
			"verify_disconnected_box_b",
		]),
		"material_variant_id": &"mat_iron_gray",
		"source_state_revision": 3,
	}


func _build_face_duplicated_single_box_packet() -> Dictionary:
	var indexed_box := _build_watertight_box_packet()
	var source_vertices: PackedVector3Array = indexed_box.get(
		"vertices",
		PackedVector3Array()
	)
	var source_indices: PackedInt32Array = indexed_box.get(
		"indices",
		PackedInt32Array()
	)
	var duplicated_vertices := PackedVector3Array()
	var duplicated_indices := PackedInt32Array()
	for source_vertex_index: int in source_indices:
		var occurrence_index := duplicated_vertices.size()
		var weld_tolerance_perturbation := Vector3(
			float((occurrence_index % 3) - 1),
			float((int(occurrence_index / 3) % 3) - 1),
			float((int(occurrence_index / 9) % 3) - 1)
		) * 0.0000001
		duplicated_vertices.append(
			source_vertices[source_vertex_index]
			+ weld_tolerance_perturbation
		)
		duplicated_indices.append(duplicated_indices.size())
	return {
		"ok": true,
		"vertices": duplicated_vertices,
		"indices": duplicated_indices,
		"primary_grip_handle_vertices": PackedVector3Array(source_vertices),
		"primary_grip_handle_indices": PackedInt32Array(source_indices),
		"primary_grip_handle_mesh_source": (
			PrimaryGripHandleMeshPacketScript.SOURCE
		),
		"watertight": true,
		"output_volume_m3": 0.32 * 0.05 * 0.04,
		"source_original_ids": PackedStringArray([
			"verify_face_duplicated_single_box",
		]),
		"material_variant_id": &"mat_iron_gray",
		"source_state_revision": 4,
	}


func _build_box_triangle_indices() -> PackedInt32Array:
	return PackedInt32Array([
		0, 2, 1, 0, 3, 2,
		4, 5, 6, 4, 6, 7,
		0, 4, 7, 0, 7, 3,
		1, 2, 6, 1, 6, 5,
		0, 1, 5, 0, 5, 4,
		3, 7, 6, 3, 6, 2,
	])


func _authorize_primary_grip_handle_packet(
	mesh_packet: Dictionary,
	handle_body: Resource
) -> Dictionary:
	var result := mesh_packet.duplicate(true)
	result["primary_grip_handle_mesh_source"] = (
		PrimaryGripHandleMeshPacketScript.SOURCE
	)
	result["primary_grip_handle_body_signature"] = (
		PrimaryGripHandleMeshPacketScript.build_body_signature(handle_body)
	)
	return result


func _verify_v2_grip_profile_contract(
	profile: BakedProfile,
	expected_handle_body_id: StringName,
	expected_contact_meters: Vector3
) -> bool:
	if not _expect(profile != null and profile.primary_grip_valid, "V2 grip profile is invalid"):
		return false
	if not _expect(
		profile.primary_grip_source_body_id == expected_handle_body_id,
		"V2 grip profile lost its semantic Handle body authority"
	):
		return false
	if not _expect(
		profile.primary_grip_authority_source != StringName(),
		"V2 grip profile does not name its authority source"
	):
		return false
	if not _expect(
		profile.primary_grip_minor_axis_a.length_squared() > 0.9
		and profile.primary_grip_minor_axis_b.length_squared() > 0.9
		and absf(profile.primary_grip_minor_axis_a.dot(
			profile.primary_grip_minor_axis_b
		)) < 0.001,
		"V2 grip profile does not provide a usable orthogonal minor-axis frame"
	):
		return false
	if not _expect(
		not profile.primary_grip_profile_offsets_minor_meters.is_empty(),
		"V2 grip profile has no mesh-native cross-section contact offsets"
	):
		return false
	if not _expect(
		profile.primary_grip_span_length_voxels >= 20
		and profile.primary_grip_slide_axis.length_squared() > 0.9,
		"V2 grip profile has no usable Handle span or slide axis"
	):
		return false
	if not _expect(
		profile.total_volume_cell_equivalents > 0.0
		and profile.total_mass > 0.0
		and profile.reach > 0.0
		and not profile.material_volume_mix.is_empty(),
		"V2 profile lost sword-style volume, mass, reach, or material data"
	):
		return false
	if not _expect(
		profile.weapon_tip_point.distance_to(profile.weapon_pommel_point) > 0.001
		and profile.weapon_total_length_meters > 0.001,
		"V2 profile lost non-degenerate tip, pommel, or weapon-length data"
	):
		return false
	var contact_meters: Vector3 = (
		profile.primary_grip_contact_position * CELL_SIZE_METERS
	)
	if not _expect(
		contact_meters.distance_to(expected_contact_meters) <= 0.0001,
		"V2 fixture grip contact was not converted to legacy cell units exactly once"
	):
		return false
	return true


func _resolve_authored_handle_frame(handle_body: Resource) -> Dictionary:
	var path_points: PackedVector3Array = handle_body.get("path_points")
	var tangent := ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
		path_points,
		1
	)
	var path_normals: PackedVector3Array = handle_body.get("path_surface_normals")
	var surface_normal := (
		path_normals[1]
		if path_normals.size() > 1
		else Vector3.UP
	)
	var contact_direction: Vector2 = handle_body.get(
		"profile_contact_direction_2d"
	)
	return ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
		tangent,
		surface_normal,
		contact_direction,
		float(handle_body.get("profile_rotation_bias_degrees"))
	)


func _find_material_body_by_id(
	authoring_state: Resource,
	body_id: StringName
) -> Resource:
	if authoring_state == null or body_id == StringName():
		return null
	var material_bodies: Array = authoring_state.get("material_bodies") as Array
	for body_variant: Variant in material_bodies:
		var body: Resource = body_variant as Resource
		if body != null and StringName(body.get("body_id")) == body_id:
			return body
	return null


func _point_is_strictly_inside_polygon(
	point: Vector2,
	polygon: PackedVector2Array
) -> bool:
	if not Geometry2D.is_point_in_polygon(point, polygon):
		return false
	for point_index in range(polygon.size()):
		if _distance_squared_to_segment_2d(
			point,
			polygon[point_index],
			polygon[(point_index + 1) % polygon.size()]
		) <= 0.000001 * 0.000001:
			return false
	return true


func _distance_squared_to_segment_2d(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.000000000001:
		return point.distance_squared_to(segment_start)
	var ratio := clampf(
		(point - segment_start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	return point.distance_squared_to(segment_start + segment * ratio)


func _verify_authored_grip_metadata(
	wip: CraftedItemWIP,
	profile: BakedProfile,
	source_handle_body: Resource
) -> bool:
	if not _expect(
		wip != null and profile != null and source_handle_body != null,
		"authored grip metadata verifier received an incomplete fixture"
	):
		return false
	var source_body_id := StringName(source_handle_body.get("body_id"))
	var persisted_handle_body := _find_material_body_by_id(
		wip.forge_v2_authoring_state,
		source_body_id
	)
	if not _expect(
		persisted_handle_body != null,
		"V2 WIP did not retain its authored Handle body"
	):
		return false
	var source_polygon: PackedVector2Array = source_handle_body.get(
		"profile_polygon_2d_meters"
	)
	var persisted_polygon: PackedVector2Array = persisted_handle_body.get(
		"profile_polygon_2d_meters"
	)
	if not _expect(
		persisted_polygon == source_polygon,
		"runtime finalization changed the exact authored Handle profile polygon"
	):
		return false
	var expected_frame := _resolve_authored_handle_frame(source_handle_body)
	var expected_tangent: Vector3 = expected_frame.get("tangent", Vector3.ZERO)
	var major_axis := profile.primary_grip_slide_axis.normalized()
	var minor_axis_a := profile.primary_grip_minor_axis_a.normalized()
	var minor_axis_b := profile.primary_grip_minor_axis_b.normalized()
	if not _expect(
		absf(major_axis.dot(expected_tangent)) >= 0.9999,
		"BakedProfile major axis no longer follows the authored Handle span"
	):
		return false
	if not _expect(
		absf(major_axis.dot(minor_axis_a)) <= 0.00001
		and absf(major_axis.dot(minor_axis_b)) <= 0.00001
		and absf(minor_axis_a.dot(minor_axis_b)) <= 0.00001
		and major_axis.cross(minor_axis_a).dot(minor_axis_b) >= 0.9999,
		"exported Handle frame is not an orthogonal right-handed basis"
	):
		return false
	var contact_cells := profile.primary_grip_contact_position
	var tip_direction := (profile.weapon_tip_point - contact_cells).normalized()
	if not _expect(
		tip_direction.dot(major_axis) >= 0.9999,
		"exported Handle major axis does not point from grip contact toward the weapon tip"
	):
		return false
	return true


func _verify_interior_profile_cell_centers(
	profile: BakedProfile,
	source_handle_body: Resource
) -> bool:
	var authored_polygon: PackedVector2Array = (
		source_handle_body.get("profile_polygon_2d_meters") as PackedVector2Array
		if source_handle_body != null
		else PackedVector2Array()
	)
	if not _expect(
		profile != null
		and source_handle_body != null
		and authored_polygon.size() >= 3,
		"profile-cell verifier received no authored polygon"
	):
		return false
	var offsets := profile.primary_grip_profile_offsets_minor_meters
	var bounds := ForgeV2ProfileShapeLibraryScript.calculate_polygon_bounds(
		authored_polygon
	)
	var half_cell := CELL_SIZE_METERS * 0.5
	var column_count := int(floor(
		(bounds.size.x + 0.000001) / CELL_SIZE_METERS
	))
	var row_count := int(floor(
		(bounds.size.y + 0.000001) / CELL_SIZE_METERS
	))
	var occupied_size := Vector2(
		float(column_count) * CELL_SIZE_METERS,
		float(row_count) * CELL_SIZE_METERS
	)
	var first_center := (
		bounds.position
		+ (bounds.size - occupied_size) * 0.5
		+ Vector2.ONE * half_cell
	)
	var expected_final_centers := PackedVector2Array()
	for column_index in range(column_count):
		for row_index in range(row_count):
			var expected_center := first_center + Vector2(
				float(column_index) * CELL_SIZE_METERS,
				float(row_index) * CELL_SIZE_METERS
			)
			if _point_is_strictly_inside_polygon(
					expected_center,
					authored_polygon
			):
				expected_final_centers.append(Vector2(
					-expected_center.x,
					expected_center.y
				))
	if not _expect(
		offsets.size() == expected_final_centers.size()
		and not expected_final_centers.is_empty(),
		"grip occupancy offsets are not the authored profile's interior cell centers"
	):
		return false
	var expected_center_mean := Vector2.ZERO
	for expected_center: Vector2 in expected_final_centers:
		expected_center_mean += expected_center
	expected_center_mean /= float(expected_final_centers.size())
	var authored_frame := _resolve_authored_handle_frame(source_handle_body)
	var authored_tangent: Vector3 = authored_frame.get("tangent", Vector3.RIGHT)
	var direction_sign := (
		-1.0
		if authored_tangent.dot(profile.primary_grip_slide_axis) < 0.0
		else 1.0
	)
	var offset_mean := Vector2.ZERO
	for offset_index: int in range(offsets.size()):
		var offset := offsets[offset_index]
		var expected_centered := expected_final_centers[offset_index] - expected_center_mean
		expected_centered.x *= direction_sign
		offset_mean += offset
		if not _expect(
			offset.distance_to(expected_centered) <= 0.000001,
			"grip contact offset does not match the final CSG-mapped interior cell"
		):
			return false
	offset_mean /= float(offsets.size())
	if not _expect(
		offset_mean.length() <= 0.000001,
		"grip contact offsets are not centered on their geometric slice mean"
	):
		return false
	return true


func _verify_diagonal_handle_runtime_contract() -> bool:
	var diagonal_points := PackedVector3Array([
		DIAGONAL_HANDLE_START,
		DIAGONAL_HANDLE_MIDPOINT,
		DIAGONAL_HANDLE_END,
	])
	var fixture := _build_committed_handle_fixture_for_points(
		diagonal_points,
		"V2 Diagonal Handle Runtime Contract Fixture"
	)
	if not _expect(
		bool(fixture.get("valid", false)),
		String(fixture.get("error", "could not build diagonal Handle fixture"))
	):
		return false
	var state: Resource = fixture.get("state") as Resource
	var handle_body: Resource = fixture.get("handle_body") as Resource
	var wip := _build_wip_from_state(
		state,
		&"verify_forge_v2_diagonal_handle_runtime_contract"
	)
	var contract := ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
		wip,
		_build_oriented_handle_box_packet(handle_body),
		CELL_SIZE_METERS
	)
	if not _expect(
		bool(contract.get("valid", false)),
		"diagonal V2 Handle contract was rejected: %s"
		% String(contract.get("error", ""))
	):
		return false
	wip.stage2_item_state = contract.get("stage2_item_state") as Resource
	wip.latest_baked_profile_snapshot = contract.get("baked_profile") as BakedProfile
	if not _verify_v2_grip_profile_contract(
		wip.latest_baked_profile_snapshot,
		StringName(handle_body.get("body_id")),
		DIAGONAL_HANDLE_MIDPOINT
	):
		return false
	if not _expect(
		absf(wip.latest_baked_profile_snapshot.primary_grip_slide_axis.x) > 0.1
		and absf(wip.latest_baked_profile_snapshot.primary_grip_slide_axis.y) > 0.1
		and absf(wip.latest_baked_profile_snapshot.primary_grip_slide_axis.z) > 0.1,
		"diagonal fixture did not exercise a genuinely non-cardinal Handle axis"
	):
		return false
	if not _verify_authored_grip_metadata(
		wip,
		wip.latest_baked_profile_snapshot,
		handle_body
	):
		return false
	if not _verify_interior_profile_cell_centers(
		wip.latest_baked_profile_snapshot,
		handle_body
	):
		return false
	var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES)
	var freshly_baked_profile := forge_service.bake_wip(wip, {})
	if not _verify_v2_grip_profile_contract(
		freshly_baked_profile,
		StringName(handle_body.get("body_id")),
		DIAGONAL_HANDLE_MIDPOINT
	):
		return false
	var mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
	return _verify_existing_equipped_presenter_channel(
		wip,
		forge_service,
		mesh_builder
	)


func _verify_disconnected_final_mesh_rejection(
	valid_handle_wip: CraftedItemWIP,
	handle_body: Resource
) -> bool:
	var disconnected_contract := (
		ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
			valid_handle_wip,
			_authorize_primary_grip_handle_packet(
				_build_disconnected_two_box_packet(),
				handle_body
			),
			CELL_SIZE_METERS
		)
	)
	var error := String(disconnected_contract.get("error", ""))
	var invalid_profile := disconnected_contract.get("baked_profile") as BakedProfile
	var diagnostic_stage2 := disconnected_contract.get(
		"stage2_item_state"
	) as Resource
	if not _expect(
		not bool(disconnected_contract.get("valid", false))
		and error.begins_with(
			"forge_v2_runtime_mesh_disconnected_component_count_"
		),
		"disconnected final mesh did not return a clear component-count error"
	):
		return false
	if not _expect(
		invalid_profile != null
		and not invalid_profile.primary_grip_valid
		and invalid_profile.validation_error == error,
		"disconnected final mesh did not invalidate its BakedProfile"
	):
		return false
	if not _expect(
		diagnostic_stage2 != null
		and bool(diagnostic_stage2.get("editable_mesh_visual_authority"))
		and bool(diagnostic_stage2.call("has_current_editable_mesh")),
		"disconnected final mesh did not retain diagnostic Stage2 geometry"
	):
		return false
	return true


func _verify_face_duplicated_single_unit_acceptance(
	valid_handle_wip: CraftedItemWIP,
	handle_body: Resource
) -> bool:
	var contract := ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
		valid_handle_wip,
		_authorize_primary_grip_handle_packet(
			_build_face_duplicated_single_box_packet(),
			handle_body
		),
		CELL_SIZE_METERS
	)
	return _expect(
		bool(contract.get("valid", false))
		and contract.get("stage2_item_state") != null
		and contract.get("baked_profile") != null
		and bool((contract.get("baked_profile") as BakedProfile).primary_grip_valid),
		"coincident face-duplicated vertices were falsely classified as disconnected"
	)


func _verify_skill_crafter_cached_profile_refresh(
	wip: CraftedItemWIP
) -> bool:
	if not _expect(
		wip != null
		and wip.latest_baked_profile_snapshot != null
		and not wip.latest_baked_profile_snapshot.material_runtime_data_resolved,
		"fixture did not begin with the adapter-only V2 cached profile"
	):
		return false
	var station_presenter = CombatAnimationStationPreviewPresenterScript.new()
	var refreshed_profile: BakedProfile = station_presenter.ensure_baked_profile_snapshot(
		wip
	)
	if not _expect(
		refreshed_profile != null
		and refreshed_profile.primary_grip_valid
		and refreshed_profile.material_runtime_data_resolved
		and not refreshed_profile.capability_scores.is_empty()
		and not refreshed_profile.resolved_material_stat_lines.is_empty()
		and not refreshed_profile.resolved_capability_bias_lines.is_empty()
		and not refreshed_profile.resolved_skill_family_bias_lines.is_empty()
		and not refreshed_profile.resolved_equipment_context_bias_lines.is_empty(),
		"Skill Crafter did not route the adapter-only V2 cache through ForgeService material resolution"
	):
		return false
	var enriched_snapshot: BakedProfile = wip.latest_baked_profile_snapshot
	if not _expect(
		enriched_snapshot != null
		and enriched_snapshot.material_runtime_data_resolved
		and not enriched_snapshot.capability_scores.is_empty()
		and not enriched_snapshot.resolved_material_stat_lines.is_empty(),
		"ForgeService refresh did not persist the enriched V2 snapshot on the active WIP"
	):
		return false
	var enriched_snapshot_instance_id := enriched_snapshot.get_instance_id()
	var cached_profile: BakedProfile = station_presenter.ensure_baked_profile_snapshot(wip)
	if not _expect(
		cached_profile == enriched_snapshot
		and wip.latest_baked_profile_snapshot.get_instance_id()
		== enriched_snapshot_instance_id,
		"Skill Crafter rebaked an already enriched V2 cached profile"
	):
		return false

	var legacy_wip: CraftedItemWIP = CraftedItemWIPScript.new()
	legacy_wip.wip_id = &"verify_skill_crafter_v1_cache"
	legacy_wip.forge_intent = &"intent_melee"
	legacy_wip.equipment_context = &"ctx_weapon"
	var legacy_cached_profile := BakedProfile.new()
	legacy_cached_profile.validation_error = "v1_cached_profile_sentinel"
	legacy_wip.latest_baked_profile_snapshot = legacy_cached_profile
	var resolved_legacy_profile: BakedProfile = (
		station_presenter.ensure_baked_profile_snapshot(legacy_wip)
	)
	if not _expect(
		resolved_legacy_profile == legacy_cached_profile
		and legacy_wip.latest_baked_profile_snapshot == legacy_cached_profile
		and legacy_cached_profile.validation_error == "v1_cached_profile_sentinel",
		"Skill Crafter changed the existing V1 cached-profile fast path"
	):
		return false
	return true


func _verify_mesh_meter_scale(mesh: ArrayMesh) -> bool:
	var cell_space_aabb: AABB = mesh.get_aabb()
	var meter_size: Vector3 = cell_space_aabb.size * CELL_SIZE_METERS
	return _expect(
		meter_size.distance_to(Vector3(0.32, 0.05, 0.04)) <= 0.0001,
		"V2 final mesh was not converted from meters to legacy cell units exactly once: %s"
		% str(meter_size)
	)


func _verify_existing_equipped_presenter_channel(
	wip: CraftedItemWIP,
	forge_service: ForgeService,
	mesh_builder: TestPrintMeshBuilder
) -> bool:
	var presenter: PlayerEquippedItemPresenter = (
		PlayerEquippedItemPresenterScript.new()
	)
	var held_item: Node3D = presenter.build_equipped_item_node(
		wip,
		&"hand_right",
		forge_service,
		{},
		mesh_builder,
		null,
		DEFAULT_FORGE_RULES,
		DEFAULT_FORGE_VIEW_TUNING,
		true
	)
	if not _expect(
		held_item != null,
		"existing equipped-item presenter rejected the finalized V2 WIP"
	):
		return false
	var mesh_instance: MeshInstance3D = _find_first_mesh_instance(held_item)
	if not _expect(
		mesh_instance != null
		and mesh_instance.mesh != null
		and mesh_instance.mesh.get_surface_count() > 0,
		"equipped-item presenter produced no visible V2 mesh"
	):
		held_item.free()
		return false
	if not _expect(
		StringName(mesh_instance.get_meta("visual_mesh_source", StringName()))
		== &"editable_mesh",
		"cached-profile equip path suppressed authoritative V2 editable-mesh visuals"
	):
		held_item.free()
		return false
	var primary_basis_anchor: Node3D = held_item.get_node_or_null(
		"PrimaryGripAnchor/PrimaryGripBasisAnchor"
	) as Node3D
	if not _expect(
		primary_basis_anchor != null
		and bool(primary_basis_anchor.get_meta("grip_basis_valid", false)),
		"existing grip-anchor channel did not consume V2 profile frame authority"
	):
		held_item.free()
		return false
	var expected_profile := wip.latest_baked_profile_snapshot
	var held_major_axis: Vector3 = primary_basis_anchor.get_meta(
		"grip_basis_major_axis_local",
		Vector3.ZERO
	)
	var held_minor_axis_a: Vector3 = primary_basis_anchor.get_meta(
		"grip_basis_minor_axis_a_local",
		Vector3.ZERO
	)
	var held_minor_axis_b: Vector3 = primary_basis_anchor.get_meta(
		"grip_basis_minor_axis_b_local",
		Vector3.ZERO
	)
	if not _expect(
		expected_profile != null
		and held_major_axis.distance_to(
			expected_profile.primary_grip_slide_axis
		) <= 0.00001
		and held_minor_axis_a.distance_to(
			expected_profile.primary_grip_minor_axis_a
		) <= 0.00001
		and held_minor_axis_b.distance_to(
			expected_profile.primary_grip_minor_axis_b
		) <= 0.00001,
		"equipped grip basis did not preserve the authored V2 Handle frame"
	):
		held_item.free()
		return false
	held_item.free()
	return true


func _verify_temp_save_reload(wip: CraftedItemWIP) -> bool:
	var library: PlayerForgeWipLibraryState = (
		PlayerForgeWipLibraryStateScript.new()
	)
	library.save_file_path = TEMP_LIBRARY_PATH
	var saved_wip: CraftedItemWIP = library.save_wip(wip)
	if not _expect(saved_wip != null, "temporary WIP library did not save V2 contract"):
		return false
	if not _expect(
		FileAccess.file_exists(TEMP_LIBRARY_PATH),
		"temporary WIP library file was not written"
	):
		return false
	var reloaded_library: PlayerForgeWipLibraryState = ResourceLoader.load(
		TEMP_LIBRARY_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PlayerForgeWipLibraryState
	if not _expect(reloaded_library != null, "temporary WIP library did not reload"):
		return false
	var reloaded_wip: CraftedItemWIP = reloaded_library.get_saved_wip_clone(
		saved_wip.wip_id,
		true
	)
	if not _expect(
		reloaded_wip != null
		and reloaded_wip.forge_v2_authoring_state != null
		and reloaded_wip.stage2_item_state != null
		and reloaded_wip.latest_baked_profile_snapshot != null,
		"save/reload lost V2 authoring state, Stage2 mesh, or cached profile"
	):
		return false
	if not _expect(
		bool(reloaded_wip.stage2_item_state.call("has_current_editable_mesh"))
		and bool(reloaded_wip.stage2_item_state.get("editable_mesh_visual_authority"))
		and reloaded_wip.latest_baked_profile_snapshot.primary_grip_valid,
		"save/reload corrupted the V2 runtime contract"
	):
		return false
	var fresh_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES)
	var persisted_handle_signature := String(
		reloaded_wip.stage2_item_state.get(
			"primary_grip_handle_body_signature"
		)
	)
	var reloaded_handle_signature := ""
	for body_variant: Variant in (
		reloaded_wip.forge_v2_authoring_state.get("material_bodies") as Array
	):
		var body := body_variant as Resource
		if (
			body != null
			and StringName(body.get("body_kind"))
			== ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
		):
			reloaded_handle_signature = (
				PrimaryGripHandleMeshPacketScript.build_body_signature(body)
			)
			break
	var reloaded_profile: BakedProfile = fresh_service.bake_wip(reloaded_wip, {})
	var reloaded_print: TestPrintInstance = fresh_service.build_test_print_from_wip(
		reloaded_wip,
		{}
	)
	result_lines.append(
		"reload.persisted_handle_signature=%s" % persisted_handle_signature
	)
	result_lines.append(
		"reload.recomputed_handle_signature=%s" % reloaded_handle_signature
	)
	result_lines.append(
		"reload.profile_validation_error=%s" % String(
			reloaded_profile.validation_error if reloaded_profile != null else "profile_null"
		)
	)
	if not _expect(
		reloaded_profile != null
		and reloaded_profile.primary_grip_valid
		and reloaded_print != null
		and reloaded_print.visual_mesh_source == &"editable_mesh"
		and reloaded_print.canonical_geometry != null
		and not bool(reloaded_print.canonical_geometry.call("is_empty")),
		"fresh services could not consume the reloaded V2 WIP contract"
	):
		return false
	return true


func _find_first_mesh_instance(parent_node: Node) -> MeshInstance3D:
	if parent_node == null:
		return null
	for child_node: Node in parent_node.get_children():
		if child_node is MeshInstance3D:
			return child_node as MeshInstance3D
		var nested_mesh: MeshInstance3D = _find_first_mesh_instance(child_node)
		if nested_mesh != null:
			return nested_mesh
	return null


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	result_lines.append("FAIL: %s" % message)
	result_lines.append("ok=false")
	_write_results()
	_cleanup_temp_library()
	push_error(message)
	quit(1)


func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(result_lines) + "\n")
	file.close()


func _cleanup_temp_library() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEMP_LIBRARY_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
