extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
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
const CombatOriginRecordScript = preload(
	"res://core/models/combat_origin_record.gd"
)
const CombatOriginRegistryScript = preload(
	"res://core/resolvers/combat_origin_registry.gd"
)
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const TestPrintMeshBuilderScript = preload(
	"res://runtime/forge/test_print_mesh_builder.gd"
)
const PlayerEquippedItemPresenterScript = preload(
	"res://runtime/player/player_equipped_item_presenter.gd"
)
const PlayerRigFingerGripPresenterScript = preload(
	"res://runtime/player/player_rig_finger_grip_presenter.gd"
)
const JosieRigScene: PackedScene = preload("res://Josie/josie.tscn")
const DEFAULT_FORGE_RULES: ForgeRulesDef = preload(
	"res://core/defs/forge/forge_rules_default.tres"
)
const DEFAULT_FORGE_VIEW_TUNING: ForgeViewTuningDef = preload(
	"res://core/defs/forge/forge_view_tuning_default.tres"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_exact_handle_grip_surface_2026-08-26.txt"
)
const CELL_SIZE_METERS := 0.0125
const HANDLE_START := Vector3(-0.19, 0.0, 0.0)
const HANDLE_MIDDLE := Vector3.ZERO
const HANDLE_END := Vector3(0.19, 0.0, 0.0)
const WOOD_MATERIAL_ID := &"mat_wood_gray"
const GRIP_CONTACT_COLLISION_LAYER := 1 << 24
const SOURCE_VERTEX_EPSILON_METERS := 0.0000005
const TRANSFORM_EPSILON_METERS := 0.000001
const RAY_HIT_EPSILON_METERS := 0.00008
const RAY_OUTSIDE_DISTANCE_METERS := 0.020
const RAY_INSIDE_DISTANCE_METERS := 0.004

# This oblique six-sided profile deliberately cannot be represented exactly by
# the legacy cell-box contact shell. Passing therefore proves that the runtime
# surface came from the protected Handle triangle packet, not its cell samples.
var authored_profile := PackedVector2Array([
	Vector2(-0.030, -0.014),
	Vector2(-0.008, -0.032),
	Vector2(0.025, -0.024),
	Vector2(0.034, 0.005),
	Vector2(0.012, 0.031),
	Vector2(-0.026, 0.022),
])

var result_lines := PackedStringArray()
var failures := PackedStringArray()


class FakeTwoHandHumanoidRig:
	extends Node3D

	func resolve_grip_hold_layout(
		baked_profile: BakedProfile,
		_dominant_slot_id: StringName,
		_cell_world_size_meters: float
	) -> Dictionary:
		var dominant_position := baked_profile.primary_grip_contact_position
		var support_position := baked_profile.primary_grip_span_start
		if support_position.distance_to(dominant_position) <= 0.0001:
			support_position = baked_profile.primary_grip_span_end
		return {
			"valid": true,
			"dominant_hand_local_position": dominant_position,
			"dominant_hand_position_origin_id": &"WeaponRootOrigin",
			"support_hand_local_position": support_position,
			"support_hand_position_origin_id": &"WeaponRootOrigin",
			"two_hand_character_eligible": true,
		}

	func resolve_hand_grip_alignment_offset_state(_slot_id: StringName) -> Dictionary:
		return {
			"hand_alignment_offset_local": Vector3.ZERO,
			"hand_alignment_offset_origin_id": &"HandGripAlignmentOrigin",
		}

	func get_right_hand_item_anchor() -> Node3D:
		return null

	func get_left_hand_item_anchor() -> Node3D:
		return null


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	result_lines.append("scope=forge_v2_equipped_exact_protected_handle_contact_surface")
	result_lines.append("ray_hit_tolerance_meters=%.8f" % RAY_HIT_EPSILON_METERS)
	result_lines.append("expected_surface_source=%s" % String(
		PrimaryGripHandleMeshPacketScript.SOURCE
	))

	var fixture := _build_fixture()
	if not bool(fixture.get("valid", false)):
		_record_failure("fixture invalid: %s" % String(fixture.get(
			"error",
			"unknown fixture failure"
		)))
		_finish()
		return
	var wip := fixture.get("wip", null) as CraftedItemWIP
	var profile := fixture.get("profile", null) as BakedProfile
	var expected_signature := String(fixture.get("body_signature", ""))
	var protected_vertices := fixture.get(
		"protected_vertices",
		PackedVector3Array()
	) as PackedVector3Array
	var protected_indices := fixture.get(
		"protected_indices",
		PackedInt32Array()
	) as PackedInt32Array
	var full_vertices := fixture.get(
		"full_vertices",
		PackedVector3Array()
	) as PackedVector3Array
	var decoy_face := fixture.get(
		"decoy_face",
		PackedVector3Array()
	) as PackedVector3Array

	var forge_service = ForgeServiceScript.new()
	var mesh_builder = TestPrintMeshBuilderScript.new()
	var equipped_presenter = PlayerEquippedItemPresenterScript.new()
	var fake_humanoid_rig := FakeTwoHandHumanoidRig.new()
	_verify_cached_stage2_signature_mismatch_rejected(
		wip,
		forge_service,
		mesh_builder,
		equipped_presenter,
		fake_humanoid_rig
	)
	var held_item: Node3D = equipped_presenter.build_equipped_item_node(
		wip,
		&"hand_right",
		forge_service,
		{},
		mesh_builder,
		fake_humanoid_rig,
		DEFAULT_FORGE_RULES,
		DEFAULT_FORGE_VIEW_TUNING,
		true
	)
	_check(
		held_item != null,
		"equipped_v2_wip_built",
		"real equipped-item presenter rejected the authorized V2 fixture"
	)
	if held_item == null:
		fake_humanoid_rig.free()
		_finish()
		return
	root.add_child(held_item)
	await process_frame
	await physics_frame
	await physics_frame

	var grip_center := held_item.get_node_or_null(
		"PrimaryGripGuide/GripShellCenter"
	) as Node3D
	var grip_area := grip_center.get_node_or_null(
		"GripContactArea"
	) as Area3D if grip_center != null else null
	_check(
		grip_center != null and grip_area != null,
		"equipped_grip_contact_graph_exists",
		"equipped V2 item has no PrimaryGripGuide/GripShellCenter/GripContactArea"
	)
	if grip_center == null or grip_area == null:
		held_item.free()
		fake_humanoid_rig.free()
		_finish()
		return

	_verify_handle_only_metadata(
		wip.stage2_item_state,
		grip_center,
		grip_area,
		expected_signature,
		CombatOriginRecordScript.ORIGIN_PRIMARY_GRIP_CONTACT_SURFACE,
		"primary"
	)
	var support_grip_center := held_item.get_node_or_null(
		"SecondaryGripGuide/GripShellCenter"
	) as Node3D
	var support_grip_area := support_grip_center.get_node_or_null(
		"GripContactArea"
	) as Area3D if support_grip_center != null else null
	_check(
		support_grip_center != null and support_grip_area != null,
		"equipped_support_grip_contact_graph_exists",
		"two-hand fixture has no SecondaryGripGuide exact contact graph"
	)
	if support_grip_center != null and support_grip_area != null:
		_verify_handle_only_metadata(
			wip.stage2_item_state,
			support_grip_center,
			support_grip_area,
			expected_signature,
			CombatOriginRecordScript.ORIGIN_SUPPORT_GRIP_CONTACT_SURFACE,
			"support"
		)
	_verify_origin_chains()

	var shape_nodes: Array[CollisionShape3D] = []
	var box_shape_count := 0
	var concave_shape_count := 0
	for child_node: Node in grip_area.get_children():
		var shape_node := child_node as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			continue
		shape_nodes.append(shape_node)
		if shape_node.shape is BoxShape3D:
			box_shape_count += 1
		if shape_node.shape is ConcavePolygonShape3D:
			concave_shape_count += 1
	result_lines.append("collision_shape_count=%d" % shape_nodes.size())
	result_lines.append("box_shape_count=%d" % box_shape_count)
	result_lines.append("concave_shape_count=%d" % concave_shape_count)
	_check(
		box_shape_count == 0,
		"legacy_cell_boxes_absent",
		"GripContactArea still publishes legacy BoxShape3D cells"
	)
	_check(
		shape_nodes.size() == 1 and concave_shape_count == 1,
		"single_exact_triangle_shape_published",
		"GripContactArea is not exactly one protected Handle triangle shape"
	)
	if shape_nodes.size() != 1 or not shape_nodes[0].shape is ConcavePolygonShape3D:
		held_item.free()
		fake_humanoid_rig.free()
		_finish()
		return

	var shape_node := shape_nodes[0]
	var concave_shape := shape_node.shape as ConcavePolygonShape3D
	var actual_faces := concave_shape.get_faces()
	var grip_center_meters := profile.primary_grip_contact_position * CELL_SIZE_METERS
	var expected_faces := _build_rebased_faces(
		protected_vertices,
		protected_indices,
		grip_center_meters
	)
	result_lines.append("protected_vertex_count=%d" % protected_vertices.size())
	result_lines.append("protected_triangle_count=%d" % int(protected_indices.size() / 3))
	result_lines.append("full_mesh_vertex_count=%d" % full_vertices.size())
	result_lines.append("contact_triangle_count=%d" % int(actual_faces.size() / 3))
	_check(
		actual_faces.size() == expected_faces.size(),
		"contact_triangle_count_matches_protected_handle_only",
		"contact face count differs from the protected Handle packet"
	)
	var max_source_vertex_error := _maximum_ordered_vertex_error(
		actual_faces,
		expected_faces
	)
	result_lines.append("max_source_vertex_error_meters=%.9f" % max_source_vertex_error)
	_check(
		max_source_vertex_error <= SOURCE_VERTEX_EPSILON_METERS,
		"contact_vertices_exactly_match_protected_handle_packet",
		"contact triangles differ from protected Handle source vertices"
	)

	var shape_local_identity := (
		shape_node.position.length() <= TRANSFORM_EPSILON_METERS
		and _basis_max_axis_error(shape_node.basis, Basis.IDENTITY) <= 0.000001
		and shape_node.scale.distance_to(Vector3.ONE) <= 0.000001
	)
	_check(
		shape_local_identity,
		"exact_shape_has_no_hidden_local_transform",
		"exact contact shape carries a second offset, rotation, or scale"
	)
	var max_global_alignment_error := _maximum_global_alignment_error(
		shape_node,
		held_item,
		actual_faces,
		expected_faces
	)
	result_lines.append("max_global_alignment_error_meters=%.9f" % (
		max_global_alignment_error
	))
	_check(
		max_global_alignment_error <= TRANSFORM_EPSILON_METERS,
		"exact_contact_surface_aligned_with_equipped_weapon",
		"contact triangles are not aligned with the equipped protected Handle mesh"
	)

	var ray_result := _probe_exact_triangle_faces(
		grip_area,
		shape_node,
		actual_faces,
		support_grip_area
	)
	result_lines.append("ray_probe_count=%d" % int(ray_result.get("probe_count", 0)))
	result_lines.append("ray_hit_count=%d" % int(ray_result.get("hit_count", 0)))
	result_lines.append("ray_collider_match_count=%d" % int(ray_result.get(
		"collider_match_count",
		0
	)))
	result_lines.append("ray_max_surface_error_meters=%.9f" % float(ray_result.get(
		"max_error_meters",
		INF
	)))
	_check(
		int(ray_result.get("hit_count", 0)) == int(ray_result.get("probe_count", 0))
		and int(ray_result.get("collider_match_count", 0)) == int(ray_result.get(
			"probe_count",
			0
		))
		and float(ray_result.get("max_error_meters", INF)) <= RAY_HIT_EPSILON_METERS,
		"physics_rays_match_exact_triangle_surfaces_within_0_08mm",
		"one or more contact rays missed or landed outside the 0.08 mm surface tolerance"
	)

	if support_grip_center != null and support_grip_area != null:
		_verify_support_exact_shape(
			held_item,
			grip_area,
			support_grip_center,
			support_grip_area,
			protected_vertices,
			protected_indices,
			grip_center_meters
		)

	var decoy_result := _probe_non_handle_decoy_face(
		[grip_area, support_grip_area],
		held_item,
		decoy_face
	)
	result_lines.append("non_handle_decoy_hit=%s" % str(bool(decoy_result.get(
		"hit",
		false
	))))
	_check(
		not bool(decoy_result.get("hit", true)),
		"surrounding_non_handle_mesh_excluded_from_grip_surface",
		"GripContactArea accepted a ray on the full-mesh decoy outside protected Handle geometry"
	)

	var primary_grip_guide := grip_center.get_parent() as Node3D
	_verify_exact_surface_invalidation_and_retry(
		equipped_presenter,
		primary_grip_guide,
		grip_center,
		grip_area,
		wip.stage2_item_state,
		profile.primary_grip_contact_position,
		expected_signature
	)
	await _verify_invalid_shell_keeps_fingers_open(
		equipped_presenter,
		primary_grip_guide,
		grip_center
	)

	held_item.free()
	fake_humanoid_rig.free()
	_finish()


func _verify_cached_stage2_signature_mismatch_rejected(
	source_wip: CraftedItemWIP,
	forge_service: ForgeService,
	mesh_builder: TestPrintMeshBuilder,
	equipped_presenter: RefCounted,
	fake_humanoid_rig: Node3D
) -> void:
	var stale_wip := source_wip.duplicate(true) as CraftedItemWIP
	var handle_validation := (
		ForgeV2WipCompatibilityAdapterScript.resolve_valid_handle_body(
			stale_wip.forge_v2_authoring_state
		)
	)
	var handle_body := handle_validation.get("body", null) as Resource
	_check(
		bool(handle_validation.get("valid", false)) and handle_body != null,
		"cached_signature_mismatch_fixture_handle_resolved",
		"cached-signature fixture could not resolve its current protected Handle"
	)
	if handle_body == null:
		return
	var cached_signature := String(stale_wip.stage2_item_state.get(
		"primary_grip_handle_body_signature"
	))
	handle_body.set(
		"profile_rotation_bias_degrees",
		float(handle_body.get("profile_rotation_bias_degrees")) + 7.0
	)
	if handle_body.has_method("normalize"):
		handle_body.call("normalize")
	var current_signature := PrimaryGripHandleMeshPacketScript.build_body_signature(
		handle_body
	)
	result_lines.append("cached_stage2_signature=%s" % cached_signature)
	result_lines.append("mutated_current_handle_signature=%s" % current_signature)
	_check(
		not cached_signature.is_empty() and current_signature != cached_signature,
		"cached_signature_mismatch_fixture_is_stale",
		"mutating the current Handle did not make cached Stage2 authority stale"
	)
	var stale_held_item := equipped_presenter.call(
		"build_equipped_item_node",
		stale_wip,
		&"hand_right",
		forge_service,
		{},
		mesh_builder,
		fake_humanoid_rig,
		DEFAULT_FORGE_RULES,
		DEFAULT_FORGE_VIEW_TUNING,
		true
	) as Node3D
	_check(
		stale_held_item == null,
		"cached_stage2_signature_mismatch_rejected",
		"cached equip published a protected Handle mesh whose signature does not match the current Handle body"
	)
	if stale_held_item != null:
		stale_held_item.free()


func _verify_exact_surface_invalidation_and_retry(
	equipped_presenter: RefCounted,
	grip_guide: Node3D,
	grip_center: Node3D,
	grip_area: Area3D,
	stage2_item_state: Resource,
	grip_center_cells: Vector3,
	expected_signature: String
) -> void:
	equipped_presenter.call("_invalidate_grip_contact_surface", grip_guide)
	var invalid_center_metadata_clear := (
		not bool(grip_center.get_meta("grip_shell_exact_surface", true))
		and not grip_center.has_meta("grip_shell_surface_authority")
		and not grip_center.has_meta("grip_shell_handle_body_signature")
		and not grip_center.has_meta("grip_shell_surface_local_origin_id")
	)
	var invalid_area_metadata_clear := true
	for meta_key: StringName in [
		&"grip_contact_surface_authority",
		&"grip_contact_handle_body_signature",
		&"grip_contact_handle_only",
		&"grip_contact_source_vertices_origin_id",
		&"grip_contact_grip_center_origin_id",
		&"grip_contact_faces_local_origin_id",
		&"grip_contact_base_guide_position_local",
		&"grip_contact_base_guide_position_origin_id",
	]:
		if grip_area.has_meta(meta_key):
			invalid_area_metadata_clear = false
			break
	_check(
		grip_area.collision_layer == 0 and grip_area.get_child_count() == 0,
		"exact_surface_invalidation_clears_collision",
		"invalidated exact surface retained its collision layer or collision shape"
	)
	_check(
		invalid_center_metadata_clear and invalid_area_metadata_clear,
		"exact_surface_invalidation_clears_metadata",
		"invalidated exact surface retained exact Handle authority metadata"
	)
	_check(
		not bool(grip_center.get_meta("grip_shell_valid", true)),
		"exact_surface_invalidation_marks_shell_invalid",
		"invalidated exact surface left grip_shell_valid enabled"
	)

	var retry_configured := bool(equipped_presenter.call(
		"_configure_exact_grip_contact_surface",
		grip_guide,
		stage2_item_state,
		{
			"grip_center_cells_local": grip_center_cells,
			"grip_center_cells_origin_id": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		},
		CELL_SIZE_METERS,
		CombatOriginRecordScript.ORIGIN_PRIMARY_GRIP_CONTACT_SURFACE
	))
	var retry_shape := (
		grip_area.get_child(0) as CollisionShape3D
		if grip_area.get_child_count() == 1
		else null
	)
	var retry_metadata_restored := (
		StringName(grip_area.get_meta(
			"grip_contact_surface_authority",
			StringName()
		)) == PrimaryGripHandleMeshPacketScript.SOURCE
		and String(grip_area.get_meta(
			"grip_contact_handle_body_signature",
			""
		)) == expected_signature
		and bool(grip_area.get_meta("grip_contact_handle_only", false))
		and bool(grip_center.get_meta("grip_shell_exact_surface", false))
		and StringName(grip_center.get_meta(
			"grip_shell_surface_authority",
			StringName()
		)) == PrimaryGripHandleMeshPacketScript.SOURCE
	)
	_check(
		retry_configured
		and grip_area.collision_layer == GRIP_CONTACT_COLLISION_LAYER
		and retry_shape != null
		and retry_shape.shape is ConcavePolygonShape3D,
		"exact_surface_direct_retry_restores_collision",
		"direct exact-surface retry did not restore the collision layer and exact triangle shape"
	)
	_check(
		retry_metadata_restored,
		"exact_surface_direct_retry_restores_metadata",
		"direct exact-surface retry did not restore protected Handle authority metadata"
	)
	_check(
		bool(grip_center.get_meta("grip_shell_valid", false)),
		"exact_surface_direct_retry_marks_shell_valid",
		"successful exact-surface retry left the grip shell invalid"
	)


func _verify_invalid_shell_keeps_fingers_open(
	equipped_presenter: RefCounted,
	grip_guide: Node3D,
	grip_center: Node3D
) -> void:
	equipped_presenter.call("_invalidate_grip_contact_surface", grip_guide)
	var josie_root := JosieRigScene.instantiate() as Node3D
	root.add_child(josie_root)
	await process_frame
	var skeleton := josie_root.get_node_or_null("Josie/Skeleton3D") as Skeleton3D
	var index_bone_index := (
		skeleton.find_bone("CC_Base_R_Index1") if skeleton != null else -1
	)
	_check(
		skeleton != null and index_bone_index >= 0,
		"invalid_shell_open_pose_fixture_has_finger_bone",
		"invalid-shell finger regression could not resolve Josie's right index bone"
	)
	if skeleton == null or index_bone_index < 0:
		josie_root.free()
		return
	var finger_presenter: RefCounted = PlayerRigFingerGripPresenterScript.new()
	finger_presenter.call("_ensure_animation_grip_baseline_cache")
	finger_presenter.call(
		"_apply_animation_contact_open_pose",
		skeleton,
		&"hand_right"
	)
	skeleton.force_update_all_bone_transforms()
	var expected_open_rotation := skeleton.get_bone_pose_rotation(
		index_bone_index
	).normalized()
	skeleton.set_bone_pose_rotation(
		index_bone_index,
		(
			expected_open_rotation
			* Quaternion(Vector3.RIGHT, deg_to_rad(32.0))
		).normalized()
	)
	skeleton.force_update_all_bone_transforms()
	var hand_bone_index := skeleton.find_bone("CC_Base_R_Hand")
	if hand_bone_index >= 0:
		grip_guide.global_position = skeleton.to_global(
			skeleton.get_bone_global_pose(hand_bone_index).origin
		)
	var index_target := Node3D.new()
	index_target.name = "InvalidShellIndexTarget"
	root.add_child(index_target)
	var get_bone_world_position := func(bone_index: int) -> Vector3:
		return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)
	finger_presenter.call(
		"update_finger_grip_targets",
		skeleton,
		{&"hand_right": grip_guide},
		{&"hand_right": {&"index": index_target}},
		get_bone_world_position,
		1000.0,
		1.0
	)
	var resolved_rotation := skeleton.get_bone_pose_rotation(
		index_bone_index
	).normalized()
	var open_rotation_error := maxf(
		1.0 - absf(expected_open_rotation.dot(resolved_rotation)),
		0.0
	)
	result_lines.append(
		"invalid_shell_open_pose_quaternion_error=%.9f" % open_rotation_error
	)
	_check(
		open_rotation_error <= 0.000001,
		"invalid_grip_shell_keeps_finger_in_open_pose",
		"invalid grip shell applied contact curl instead of leaving the finger in its open pose"
	)
	index_target.free()
	josie_root.free()


func _build_fixture() -> Dictionary:
	var profile_entries: Array[Dictionary] = (
		ForgeV2ProfileShapeLibraryScript.build_handle_profile_entries()
	)
	if profile_entries.is_empty():
		return {"valid": false, "error": "no Handle profile is available"}
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Exact Handle Grip Surface Fixture")
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	state.call("set_active_profile_id", StringName(profile_entries[0].get(
		"id",
		StringName()
	)))
	state.call("set_active_handle_rounding_enabled", false)
	for point: Vector3 in PackedVector3Array([
		HANDLE_START,
		HANDLE_MIDDLE,
		HANDLE_END,
	]):
		if int(state.call("append_spline_line_point", point, Vector3.UP)) < 0:
			return {"valid": false, "error": "Handle rejected a path point"}
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		return {"valid": false, "error": "Handle extrusion did not generate"}
	var handle_body := state.call("get_selected_material_body") as Resource
	if handle_body == null:
		return {"valid": false, "error": "generated Handle body is missing"}

	var runtime_data := (
		ForgeV2ProfileShapeLibraryScript.build_anchor_relative_profile_runtime_data(
			authored_profile,
			Vector2.ZERO
		)
	)
	if not bool(runtime_data.get("valid", false)):
		return {"valid": false, "error": "asymmetric Handle profile is invalid"}
	var authored_polygon := runtime_data.get(
		"deposition_polygon_2d_meters",
		PackedVector2Array()
	) as PackedVector2Array
	handle_body.set("material_variant_id", WOOD_MATERIAL_ID)
	handle_body.set("profile_polygon_2d_meters", authored_polygon)
	handle_body.set("profile_anchor_2d_meters", runtime_data.get(
		"anchor_2d_meters",
		Vector2.ZERO
	))
	handle_body.set("profile_contact_point_relative_2d_meters", runtime_data.get(
		"contact_point_relative_2d_meters",
		Vector2.ZERO
	))
	handle_body.set("profile_contact_direction_2d", runtime_data.get(
		"contact_direction_2d",
		Vector2.DOWN
	))
	handle_body.set("profile_contact_distance_meters", float(runtime_data.get(
		"contact_distance_meters",
		0.0
	)))
	handle_body.set("profile_runtime_schema_version", int(runtime_data.get(
		"schema_version",
		1
	)))
	handle_body.set("profile_rotation_bias_degrees", 0.0)
	handle_body.call("normalize")
	var committed_layer := state.call(
		"commit_material_body_as_layer",
		StringName(handle_body.get("body_id"))
	) as Resource
	if committed_layer == null:
		return {"valid": false, "error": "Handle did not commit"}

	var frame := _resolve_authored_handle_frame(handle_body)
	var final_polygon := _mirror_polygon_x(authored_polygon)
	var handle_packet := _build_profile_prism_packet(
		handle_body.get("path_points") as PackedVector3Array,
		final_polygon,
		frame
	)
	if not bool(handle_packet.get("ok", false)):
		return {"valid": false, "error": String(handle_packet.get(
			"error",
			"Handle packet build failed"
		))}
	var protected_vertices := handle_packet.get(
		"vertices",
		PackedVector3Array()
	) as PackedVector3Array
	var protected_indices := handle_packet.get(
		"indices",
		PackedInt32Array()
	) as PackedInt32Array
	var full_mesh := _append_non_handle_decoy_tetrahedron(
		protected_vertices,
		protected_indices,
		frame
	)
	var full_vertices := full_mesh.get("vertices", PackedVector3Array()) as PackedVector3Array
	var full_indices := full_mesh.get("indices", PackedInt32Array()) as PackedInt32Array
	var body_signature := PrimaryGripHandleMeshPacketScript.build_body_signature(
		handle_body
	)
	var mesh_packet := {
		"ok": true,
		"vertices": full_vertices,
		"indices": full_indices,
		"primary_grip_handle_vertices": protected_vertices,
		"primary_grip_handle_indices": protected_indices,
		"primary_grip_handle_vertices_origin_id": (
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID
		),
		"primary_grip_handle_mesh_source": PrimaryGripHandleMeshPacketScript.SOURCE,
		"primary_grip_handle_body_signature": body_signature,
		"watertight": true,
		"output_volume_m3": float(handle_packet.get("output_volume_m3", 0.0)),
		"source_original_ids": PackedStringArray(["verify_handle", "verify_non_handle_decoy"]),
		"material_variant_id": WOOD_MATERIAL_ID,
		"source_state_revision": 1,
	}
	var wip := _build_wip_from_state(state)
	var contract := ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
		wip,
		mesh_packet,
		CELL_SIZE_METERS
	)
	if not bool(contract.get("valid", false)):
		return {"valid": false, "error": "adapter rejected fixture: %s" % String(
			contract.get("error", "unknown")
		)}
	wip.stage2_item_state = contract.get("stage2_item_state") as Resource
	wip.latest_baked_profile_snapshot = contract.get("baked_profile") as BakedProfile
	return {
		"valid": true,
		"wip": wip,
		"profile": wip.latest_baked_profile_snapshot,
		"body_signature": body_signature,
		"protected_vertices": protected_vertices,
		"protected_indices": protected_indices,
		"full_vertices": full_vertices,
		"decoy_face": full_mesh.get("decoy_face", PackedVector3Array()),
	}


func _build_wip_from_state(authoring_state: Resource) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = &"verify_forge_v2_exact_handle_grip_surface"
	wip.forge_project_name = "Exact Handle Grip Surface Fixture"
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_builder_path_id = CraftedItemWIPScript.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.layers = []
	wip.forge_v2_authoring_state = authoring_state.duplicate(true) as Resource
	wip.ensure_combat_animation_station_state()
	return wip


func _resolve_authored_handle_frame(handle_body: Resource) -> Dictionary:
	var path_points := handle_body.get("path_points") as PackedVector3Array
	var tangent := ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
		path_points,
		1
	)
	var path_normals := handle_body.get("path_surface_normals") as PackedVector3Array
	var surface_normal := path_normals[1] if path_normals.size() > 1 else Vector3.UP
	return ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
		tangent,
		surface_normal,
		handle_body.get("profile_contact_direction_2d") as Vector2,
		float(handle_body.get("profile_rotation_bias_degrees"))
	)


func _build_profile_prism_packet(
	path_points: PackedVector3Array,
	profile_polygon: PackedVector2Array,
	frame: Dictionary
) -> Dictionary:
	if path_points.size() != 3 or profile_polygon.size() < 3:
		return {"ok": false, "error": "profile prism input is incomplete"}
	var triangulation := Geometry2D.triangulate_polygon(profile_polygon)
	if triangulation.size() < 3:
		return {"ok": false, "error": "profile polygon did not triangulate"}
	var tangent := (frame.get("tangent", Vector3.RIGHT) as Vector3).normalized()
	var axis_x := (frame.get("axis_x", Vector3.UP) as Vector3).normalized()
	var axis_y := (frame.get("axis_y", Vector3.FORWARD) as Vector3).normalized()
	var start := path_points[0]
	var finish := path_points[2]
	var ring_size := profile_polygon.size()
	var vertices := PackedVector3Array()
	for point: Vector2 in profile_polygon:
		vertices.append(start + axis_x * point.x + axis_y * point.y)
	for point: Vector2 in profile_polygon:
		vertices.append(finish + axis_x * point.x + axis_y * point.y)
	var indices := PackedInt32Array()
	for triangle_offset in range(0, triangulation.size(), 3):
		var a := triangulation[triangle_offset]
		var b := triangulation[triangle_offset + 1]
		var c := triangulation[triangle_offset + 2]
		_append_oriented_triangle(indices, vertices, a, b, c, -tangent)
		_append_oriented_triangle(
			indices,
			vertices,
			a + ring_size,
			b + ring_size,
			c + ring_size,
			tangent
		)
	var signed_area := _signed_polygon_area(profile_polygon)
	for point_index: int in range(ring_size):
		var next_index := (point_index + 1) % ring_size
		var edge := profile_polygon[next_index] - profile_polygon[point_index]
		var outward_2d := (
			Vector2(edge.y, -edge.x)
			if signed_area >= 0.0
			else Vector2(-edge.y, edge.x)
		).normalized()
		var outward_3d := (axis_x * outward_2d.x + axis_y * outward_2d.y).normalized()
		_append_oriented_triangle(
			indices,
			vertices,
			point_index,
			next_index,
			next_index + ring_size,
			outward_3d
		)
		_append_oriented_triangle(
			indices,
			vertices,
			point_index,
			next_index + ring_size,
			point_index + ring_size,
			outward_3d
		)
	return {
		"ok": true,
		"vertices": vertices,
		"indices": indices,
		"output_volume_m3": absf(signed_area) * start.distance_to(finish),
	}


func _append_non_handle_decoy_tetrahedron(
	protected_vertices: PackedVector3Array,
	protected_indices: PackedInt32Array,
	frame: Dictionary
) -> Dictionary:
	var vertices := PackedVector3Array(protected_vertices)
	var indices := PackedInt32Array(protected_indices)
	var tangent := (frame.get("tangent", Vector3.RIGHT) as Vector3).normalized()
	var axis_x := (frame.get("axis_x", Vector3.UP) as Vector3).normalized()
	var axis_y := (frame.get("axis_y", Vector3.FORWARD) as Vector3).normalized()
	# The first vertex is deliberately duplicated at a protected end-ring point.
	# Adapter component welding therefore treats this as one final item, while
	# the protected Handle packet remains the smaller source above.
	var shared := protected_vertices[int(protected_vertices.size() / 2)]
	var base_index := vertices.size()
	vertices.append(shared)
	vertices.append(shared + tangent * 0.16 + axis_x * 0.09)
	vertices.append(shared + tangent * 0.18 - axis_x * 0.08 + axis_y * 0.07)
	vertices.append(shared + tangent * 0.20 - axis_y * 0.09)
	var tetra_faces := PackedInt32Array([
		base_index, base_index + 2, base_index + 1,
		base_index, base_index + 1, base_index + 3,
		base_index, base_index + 3, base_index + 2,
		base_index + 1, base_index + 2, base_index + 3,
	])
	indices.append_array(tetra_faces)
	return {
		"vertices": vertices,
		"indices": indices,
		"decoy_face": PackedVector3Array([
			vertices[base_index + 1],
			vertices[base_index + 2],
			vertices[base_index + 3],
		]),
	}


func _append_oriented_triangle(
	indices: PackedInt32Array,
	vertices: PackedVector3Array,
	a: int,
	b: int,
	c: int,
	desired_normal: Vector3
) -> void:
	var actual_normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
	indices.append_array(
		PackedInt32Array([a, b, c])
		if actual_normal.dot(desired_normal) >= 0.0
		else PackedInt32Array([a, c, b])
	)


func _mirror_polygon_x(polygon: PackedVector2Array) -> PackedVector2Array:
	var mirrored := PackedVector2Array()
	for point_index: int in range(polygon.size() - 1, -1, -1):
		var point := polygon[point_index]
		mirrored.append(Vector2(-point.x, point.y))
	return mirrored


func _signed_polygon_area(polygon: PackedVector2Array) -> float:
	var twice_area := 0.0
	for point_index: int in range(polygon.size()):
		twice_area += polygon[point_index].cross(
			polygon[(point_index + 1) % polygon.size()]
		)
	return twice_area * 0.5


func _verify_handle_only_metadata(
	stage2_item_state: Resource,
	grip_center: Node3D,
	grip_area: Area3D,
	expected_signature: String,
	expected_faces_origin_id: StringName,
	label: String
) -> void:
	var source := PrimaryGripHandleMeshPacketScript.SOURCE
	var stage2_source := StringName(stage2_item_state.get(
		"primary_grip_handle_mesh_source"
	)) if stage2_item_state != null else StringName()
	var stage2_signature := String(stage2_item_state.get(
		"primary_grip_handle_body_signature"
	)) if stage2_item_state != null else ""
	var area_source := StringName(grip_area.get_meta(
		"grip_contact_surface_authority",
		StringName()
	))
	var area_signature := String(grip_area.get_meta(
		"grip_contact_handle_body_signature",
		""
	))
	var center_source := StringName(grip_center.get_meta(
		"grip_shell_surface_authority",
		StringName()
	))
	var center_signature := String(grip_center.get_meta(
		"grip_shell_handle_body_signature",
		""
	))
	var source_vertices_origin_id := StringName(grip_area.get_meta(
		"grip_contact_source_vertices_origin_id",
		StringName()
	))
	var grip_center_origin_id := StringName(grip_area.get_meta(
		"grip_contact_grip_center_origin_id",
		StringName()
	))
	var faces_origin_id := StringName(grip_area.get_meta(
		"grip_contact_faces_local_origin_id",
		StringName()
	))
	result_lines.append("%s_stage2_source=%s" % [label, String(stage2_source)])
	result_lines.append("%s_area_source=%s" % [label, String(area_source)])
	result_lines.append("%s_center_source=%s" % [label, String(center_source)])
	result_lines.append("%s_source_vertices_origin_id=%s" % [
		label,
		String(source_vertices_origin_id),
	])
	result_lines.append("%s_grip_center_origin_id=%s" % [
		label,
		String(grip_center_origin_id),
	])
	result_lines.append("%s_faces_local_origin_id=%s" % [
		label,
		String(faces_origin_id),
	])
	result_lines.append("%s_stage2_signature_match=%s" % [label, str(
		stage2_signature == expected_signature
	)])
	result_lines.append("%s_area_signature_match=%s" % [label, str(
		area_signature == expected_signature
	)])
	result_lines.append("%s_center_signature_match=%s" % [label, str(
		center_signature == expected_signature
	)])
	_check(
		stage2_source == source
		and area_source == source
		and center_source == source
		and bool(grip_center.get_meta("grip_shell_exact_surface", false))
		and bool(grip_area.get_meta("grip_contact_handle_only", false)),
		"%s_exact_handle_source_metadata_reaches_grip_contact_area" % label,
		"equipped surface does not identify the protected V2 Handle source end to end"
	)
	_check(
		not expected_signature.is_empty()
		and stage2_signature == expected_signature
		and area_signature == expected_signature
		and center_signature == expected_signature,
		"%s_exact_handle_body_signature_reaches_grip_contact_area" % label,
		"equipped surface signature does not match the protected Handle body"
	)
	_check(
		source_vertices_origin_id == CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		and grip_center_origin_id == CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		and faces_origin_id == expected_faces_origin_id
		and StringName(grip_center.get_meta(
			"grip_shell_surface_local_origin_id",
			StringName()
		)) == expected_faces_origin_id,
		"%s_exact_surface_origin_contract" % label,
		"source vertices, subtraction center, or local faces have the wrong declared origin"
	)
	for child_node: Node in grip_area.get_children():
		var shape_node := child_node as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			continue
		_check(
			StringName(shape_node.get_meta(
				"grip_contact_surface_authority",
				StringName()
			)) == source
			and String(shape_node.get_meta(
				"grip_contact_handle_body_signature",
				""
			)) == expected_signature
			and StringName(shape_node.get_meta(
				"grip_contact_source_vertices_origin_id",
				StringName()
			)) == CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			and StringName(shape_node.get_meta(
				"grip_contact_grip_center_origin_id",
				StringName()
			)) == CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			and StringName(shape_node.get_meta(
				"grip_contact_faces_local_origin_id",
				StringName()
			)) == expected_faces_origin_id,
			"%s_exact_collision_shape_metadata" % label,
			"exact CollisionShape3D did not retain the area surface contract"
		)


func _verify_origin_chains() -> void:
	var registry = CombatOriginRegistryScript.new()
	registry.register_default_combat_origins(&"verify_exact_handle_grip_surface")
	var primary_chain: Array = registry.resolve_chain(
		CombatOriginRecordScript.ORIGIN_PRIMARY_GRIP_CONTACT_SURFACE
	)
	var support_chain: Array = registry.resolve_chain(
		CombatOriginRecordScript.ORIGIN_SUPPORT_GRIP_CONTACT_SURFACE
	)
	var expected_primary := PackedStringArray([
		String(CombatOriginRecordScript.ORIGIN_PRIMARY_GRIP_CONTACT_SURFACE),
		String(CombatOriginRecordScript.ORIGIN_WEAPON_ROOT),
		String(CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE),
		String(CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT),
	])
	var expected_support := PackedStringArray([
		String(CombatOriginRecordScript.ORIGIN_SUPPORT_GRIP_CONTACT_SURFACE),
		String(CombatOriginRecordScript.ORIGIN_WEAPON_ROOT),
		String(CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE),
		String(CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT),
	])
	var primary_labels := _origin_chain_labels(primary_chain)
	var support_labels := _origin_chain_labels(support_chain)
	result_lines.append("primary_surface_origin_chain=%s" % " -> ".join(
		primary_labels
	))
	result_lines.append("support_surface_origin_chain=%s" % " -> ".join(
		support_labels
	))
	_check(
		primary_labels == expected_primary,
		"primary_surface_chains_to_rl_bone_root",
		"PrimaryGripAnchorOrigin does not chain through WeaponRoot and SolvedReplayReference"
	)
	_check(
		support_labels == expected_support,
		"support_surface_chains_to_rl_bone_root",
		"SupportGripAnchorOrigin does not chain through WeaponRoot and SolvedReplayReference"
	)


func _origin_chain_labels(chain: Array) -> PackedStringArray:
	var labels := PackedStringArray()
	for record_variant: Variant in chain:
		var record := record_variant as Resource
		if record != null:
			labels.append(String(record.get("origin_id")))
	return labels


func _build_rebased_faces(
	vertices_meters: PackedVector3Array,
	indices: PackedInt32Array,
	grip_center_meters: Vector3
) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for source_index: int in indices:
		faces.append(vertices_meters[source_index] - grip_center_meters)
	return faces


func _maximum_ordered_vertex_error(
	actual: PackedVector3Array,
	expected: PackedVector3Array
) -> float:
	if actual.size() != expected.size():
		return INF
	var maximum_error := 0.0
	for vertex_index: int in range(actual.size()):
		maximum_error = maxf(
			maximum_error,
			actual[vertex_index].distance_to(expected[vertex_index])
		)
	return maximum_error


func _maximum_global_alignment_error(
	shape_node: CollisionShape3D,
	held_item: Node3D,
	actual_faces: PackedVector3Array,
	expected_faces: PackedVector3Array
) -> float:
	if actual_faces.size() != expected_faces.size():
		return INF
	var maximum_error := 0.0
	for vertex_index: int in range(actual_faces.size()):
		maximum_error = maxf(
			maximum_error,
			shape_node.to_global(actual_faces[vertex_index]).distance_to(
				held_item.to_global(expected_faces[vertex_index])
			)
		)
	return maximum_error


func _verify_support_exact_shape(
	held_item: Node3D,
	primary_grip_area: Area3D,
	support_grip_center: Node3D,
	support_grip_area: Area3D,
	protected_vertices: PackedVector3Array,
	protected_indices: PackedInt32Array,
	primary_grip_center_meters: Vector3
) -> void:
	var support_shape_nodes: Array[CollisionShape3D] = []
	var support_box_count := 0
	for child_node: Node in support_grip_area.get_children():
		var shape_node := child_node as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			continue
		support_shape_nodes.append(shape_node)
		if shape_node.shape is BoxShape3D:
			support_box_count += 1
	_check(
		support_box_count == 0
		and support_shape_nodes.size() == 1
		and support_shape_nodes[0].shape is ConcavePolygonShape3D,
		"support_guide_uses_single_exact_triangle_shape",
		"support GripContactArea retained boxes or lacks exact protected Handle triangles"
	)
	if (
		support_shape_nodes.size() != 1
		or not support_shape_nodes[0].shape is ConcavePolygonShape3D
	):
		return
	var support_shape_node := support_shape_nodes[0]
	var support_faces := (
		support_shape_node.shape as ConcavePolygonShape3D
	).get_faces()
	var secondary_guide := support_grip_center.get_parent() as Node3D
	var support_center_meters := primary_grip_center_meters
	if secondary_guide != null:
		support_center_meters += secondary_guide.position
	var expected_support_faces := _build_rebased_faces(
		protected_vertices,
		protected_indices,
		support_center_meters
	)
	var support_source_error := _maximum_ordered_vertex_error(
		support_faces,
		expected_support_faces
	)
	result_lines.append("support_max_source_vertex_error_meters=%.9f" % (
		support_source_error
	))
	_check(
		support_source_error <= SOURCE_VERTEX_EPSILON_METERS,
		"support_contact_vertices_match_protected_handle_packet",
		"support exact contact surface was not rebased around its own Handle seat"
	)
	var support_global_error := _maximum_global_alignment_error(
		support_shape_node,
		held_item,
		support_faces,
		_build_rebased_faces(
			protected_vertices,
			protected_indices,
			primary_grip_center_meters
		)
	)
	result_lines.append("support_max_global_alignment_error_meters=%.9f" % (
		support_global_error
	))
	_check(
		support_global_error <= TRANSFORM_EPSILON_METERS,
		"support_contact_surface_aligned_with_equipped_weapon",
		"support exact surface does not return to protected Handle weapon space"
	)
	var support_ray_result := _probe_exact_triangle_faces(
		support_grip_area,
		support_shape_node,
		support_faces,
		primary_grip_area
	)
	result_lines.append("support_ray_probe_count=%d" % int(support_ray_result.get(
		"probe_count",
		0
	)))
	result_lines.append("support_ray_hit_count=%d" % int(support_ray_result.get(
		"hit_count",
		0
	)))
	result_lines.append("support_ray_max_surface_error_meters=%.9f" % float(
		support_ray_result.get("max_error_meters", INF)
	))
	_check(
		int(support_ray_result.get("hit_count", 0)) == int(support_ray_result.get(
			"probe_count",
			0
		))
		and int(support_ray_result.get("collider_match_count", 0)) == int(
			support_ray_result.get("probe_count", 0)
		)
		and float(support_ray_result.get(
			"max_error_meters",
			INF
		)) <= RAY_HIT_EPSILON_METERS,
		"support_physics_rays_match_exact_surfaces_within_0_08mm",
		"support guide rays missed or landed outside the 0.08 mm surface tolerance"
	)


func _basis_max_axis_error(actual: Basis, expected: Basis) -> float:
	return maxf(
		actual.x.distance_to(expected.x),
		maxf(
			actual.y.distance_to(expected.y),
			actual.z.distance_to(expected.z)
		)
	)


func _probe_exact_triangle_faces(
	grip_area: Area3D,
	shape_node: CollisionShape3D,
	faces: PackedVector3Array,
	excluded_overlap_area: Area3D = null
) -> Dictionary:
	var result := {
		"probe_count": int(faces.size() / 3),
		"hit_count": 0,
		"collider_match_count": 0,
		"max_error_meters": 0.0,
	}
	var space_state := root.get_world_3d().direct_space_state
	for face_offset: int in range(0, faces.size(), 3):
		var point_a := faces[face_offset]
		var point_b := faces[face_offset + 1]
		var point_c := faces[face_offset + 2]
		var face_normal := (point_b - point_a).cross(point_c - point_a).normalized()
		if face_normal.length_squared() <= 0.5:
			continue
		var centroid := (point_a + point_b + point_c) / 3.0
		var ray_from := shape_node.to_global(
			centroid + face_normal * RAY_OUTSIDE_DISTANCE_METERS
		)
		var ray_to := shape_node.to_global(
			centroid - face_normal * RAY_INSIDE_DISTANCE_METERS
		)
		var query := PhysicsRayQueryParameters3D.create(
			ray_from,
			ray_to,
			GRIP_CONTACT_COLLISION_LAYER
		)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.hit_from_inside = false
		if excluded_overlap_area != null:
			query.exclude = [excluded_overlap_area.get_rid()]
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		result["hit_count"] = int(result["hit_count"]) + 1
		if hit.get("collider", null) == grip_area:
			result["collider_match_count"] = int(result["collider_match_count"]) + 1
		result["max_error_meters"] = maxf(
			float(result["max_error_meters"]),
			(hit.get("position", Vector3.INF) as Vector3).distance_to(
				shape_node.to_global(centroid)
			)
		)
	return result


func _probe_non_handle_decoy_face(
	grip_areas: Array,
	held_item: Node3D,
	decoy_face_item_meters: PackedVector3Array
) -> Dictionary:
	if decoy_face_item_meters.size() != 3:
		return {"hit": true, "reason": "decoy face missing"}
	var a := decoy_face_item_meters[0]
	var b := decoy_face_item_meters[1]
	var c := decoy_face_item_meters[2]
	var normal := (b - a).cross(c - a).normalized()
	var centroid := (a + b + c) / 3.0
	var mesh_instance := _find_primary_mesh_instance(held_item)
	if mesh_instance == null:
		return {"hit": true, "reason": "visible mesh missing"}
	var item_center_cells := -mesh_instance.position / CELL_SIZE_METERS
	var decoy_centroid_held := centroid - item_center_cells * CELL_SIZE_METERS
	var ray_from := held_item.to_global(
		decoy_centroid_held + normal * RAY_OUTSIDE_DISTANCE_METERS
	)
	var ray_to := held_item.to_global(
		decoy_centroid_held - normal * RAY_INSIDE_DISTANCE_METERS
	)
	var query := PhysicsRayQueryParameters3D.create(
		ray_from,
		ray_to,
		GRIP_CONTACT_COLLISION_LAYER
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.hit_from_inside = false
	var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
	var hit_grip_area := false
	for grip_area_variant: Variant in grip_areas:
		var grip_area := grip_area_variant as Area3D
		if grip_area != null and hit.get("collider", null) == grip_area:
			hit_grip_area = true
			break
	return {
		"hit": not hit.is_empty() and hit_grip_area,
		"raw_hit": hit,
	}


func _find_primary_mesh_instance(parent_node: Node) -> MeshInstance3D:
	if parent_node == null:
		return null
	for child_node: Node in parent_node.get_children():
		if child_node is MeshInstance3D:
			return child_node as MeshInstance3D
		var nested := _find_primary_mesh_instance(child_node)
		if nested != null:
			return nested
	return null


func _check(condition: bool, assertion_id: String, failure_message: String) -> void:
	result_lines.append("%s=%s" % [assertion_id, str(condition)])
	if not condition:
		_record_failure("%s: %s" % [assertion_id, failure_message])


func _record_failure(message: String) -> void:
	failures.append(message)
	result_lines.append("FAIL: %s" % message)


func _finish() -> void:
	result_lines.append("failure_count=%d" % failures.size())
	result_lines.append("ok=%s" % str(failures.is_empty()))
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(result_lines) + "\n")
		file.close()
	if failures.is_empty():
		print("Forge V2 exact Handle grip surface verifier passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
