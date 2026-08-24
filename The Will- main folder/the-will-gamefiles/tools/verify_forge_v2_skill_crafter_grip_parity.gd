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
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload(
	"res://core/models/player_forge_wip_library_state.gd"
)
const CombatAnimationStationUIScene = preload(
	"res://scenes/ui/combat_animation_station_ui.tscn"
)
const LayerAtomScript = preload("res://core/atoms/layer_atom.gd")
const CellAtomScript = preload("res://core/atoms/cell_atom.gd")
const PlayerRigFingerGripPresenterScript = preload(
	"res://runtime/player/player_rig_finger_grip_presenter.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_skill_crafter_grip_parity_2026-08-23.txt"
)
const TEMP_LIBRARY_PATH := (
	"user://verification/verify_forge_v2_skill_crafter_grip_parity_library.tres"
)
const CELL_SIZE_METERS := 0.0125
const HANDLE_HALF_LENGTH_METERS := 0.1625
const POSITION_EPSILON_METERS := 0.00025
const LEGACY_AXIAL_QUANTIZATION_EPSILON_METERS := CELL_SIZE_METERS * 0.11
# Legacy GripContactArea cells are identity-basis cubes. A square profile cell
# rotated 45 degrees therefore differs from its visible boundary by at most
# half_cell * (sqrt(2) - 1); retain that V1 proxy quantization in this adapter
# parity test while still requiring every expected boundary probe to hit.
const RAY_HIT_EPSILON_METERS := (
	CELL_SIZE_METERS * 0.5 * (sqrt(2.0) - 1.0) + 0.0001
)
const BASIS_EPSILON_DEGREES := 1.0
const THUMB_EPSILON_DEGREES := 2.0
const WOOD_MATERIAL_ID := &"mat_wood_gray"

# The centered 2x3 authored profile becomes a 3x2 physical slice after the
# established CSG mirror_x mapping and the authored Handle frame are applied.
const BASELINE_AUTHORED_ROWS: Array[String] = [
	"11",
	"11",
	"11",
]

# A grid-aligned, simple asymmetric profile. The missing upper-right cell is
# intentionally mirrored to the upper-left by the established final CSG path.
const ASYMMETRIC_AUTHORED_ROWS: Array[String] = [
	"1110",
	"1111",
	"1111",
]
const ASYMMETRIC_REQUESTED_ANCHOR := Vector2(0.00625, 0.0)

const RIGHT_FINGER_BONES: Array[String] = [
	"CC_Base_R_Thumb1",
	"CC_Base_R_Thumb2",
	"CC_Base_R_Thumb3",
	"CC_Base_R_Index1",
	"CC_Base_R_Index2",
	"CC_Base_R_Index3",
	"CC_Base_R_Mid1",
	"CC_Base_R_Mid2",
	"CC_Base_R_Mid3",
	"CC_Base_R_Ring1",
	"CC_Base_R_Ring2",
	"CC_Base_R_Ring3",
	"CC_Base_R_Pinky1",
	"CC_Base_R_Pinky2",
	"CC_Base_R_Pinky3",
]
const FINGER_IDS: Array[String] = ["thumb", "index", "middle", "ring", "pinky"]
const RIGHT_FINGER_END_BONES := {
	"thumb": "CC_Base_R_Thumb3",
	"index": "CC_Base_R_Index3",
	"middle": "CC_Base_R_Mid3",
	"ring": "CC_Base_R_Ring3",
	"pinky": "CC_Base_R_Pinky3",
}
const RIGHT_FINGER_TARGET_LABELS := {
	"thumb": "Thumb",
	"index": "Index",
	"middle": "Middle",
	"ring": "Ring",
	"pinky": "Pinky",
}


class FakePlayer:
	extends Node

	var ui_mode_enabled := false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled


var result_lines: PackedStringArray = []
var failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	_cleanup_temp_library()
	result_lines.append("scope=adapter_side_v1_v2_skill_crafter_grip_parity")
	result_lines.append("skill_crafter_and_grip_solver_modified=false")
	result_lines.append(
		"expected_final_profile_mapping=mirror_x_then_arithmetic_mean_center"
	)

	var baseline_v2: Dictionary = _build_v2_fixture(
		BASELINE_AUTHORED_ROWS,
		Vector2.ZERO,
		&"verify_v2_skill_crafter_grip_baseline",
		"Forge V2 Skill Crafter Grip Baseline"
	)
	if not _fixture_is_valid(baseline_v2, "baseline V2"):
		_finish()
		return
	var asymmetric_v2: Dictionary = _build_v2_fixture(
		ASYMMETRIC_AUTHORED_ROWS,
		ASYMMETRIC_REQUESTED_ANCHOR,
		&"verify_v2_skill_crafter_grip_asymmetric",
		"Forge V2 Skill Crafter Grip Asymmetric"
	)
	if not _fixture_is_valid(asymmetric_v2, "asymmetric V2"):
		_finish()
		return
	var baseline_v1: CraftedItemWIP = _build_v1_visible_oracle_wip(
		BASELINE_AUTHORED_ROWS,
		&"verify_v1_skill_crafter_grip_oracle"
	)
	if baseline_v1 == null:
		_record_failure("could not build the V1 visible/collision oracle")
		_finish()
		return

	var library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library.save_file_path = TEMP_LIBRARY_PATH
	library.saved_wips.clear()
	library.selected_wip_id = StringName()
	var saved_v1: CraftedItemWIP = library.save_wip(baseline_v1)
	var saved_v2: CraftedItemWIP = library.save_wip(
		baseline_v2.get("wip") as CraftedItemWIP
	)
	var saved_asymmetric: CraftedItemWIP = library.save_wip(
		asymmetric_v2.get("wip") as CraftedItemWIP
	)
	if saved_v1 == null or saved_v2 == null or saved_asymmetric == null:
		_record_failure("temporary WIP library rejected a parity fixture")
		_finish()
		return

	var v1_snapshot: Dictionary = await _capture_skill_crafter_snapshot(
		library,
		saved_v1.wip_id,
		"v1_oracle",
		{}
	)
	var v2_snapshot: Dictionary = await _capture_skill_crafter_snapshot(
		library,
		saved_v2.wip_id,
		"v2_baseline",
		baseline_v2
	)
	var asymmetric_snapshot: Dictionary = await _capture_skill_crafter_snapshot(
		library,
		saved_asymmetric.wip_id,
		"v2_asymmetric",
		asymmetric_v2
	)

	_append_snapshot_summary("v1", v1_snapshot)
	_append_snapshot_summary("v2", v2_snapshot)
	_append_snapshot_summary("asymmetric", asymmetric_snapshot)
	_evaluate_baseline_parity(v1_snapshot, v2_snapshot)
	_evaluate_asymmetric_surface_alignment(asymmetric_v2, asymmetric_snapshot)
	_finish()


func _fixture_is_valid(fixture: Dictionary, label: String) -> bool:
	if bool(fixture.get("valid", false)):
		return true
	_record_failure("%s fixture invalid: %s" % [
		label,
		String(fixture.get("error", "unknown fixture error")),
	])
	return false


func _build_v2_fixture(
	authored_rows: Array[String],
	requested_anchor: Vector2,
	wip_id: StringName,
	project_name: String
) -> Dictionary:
	var profile_entries: Array[Dictionary] = (
		ForgeV2ProfileShapeLibraryScript.build_handle_profile_entries()
	)
	if profile_entries.is_empty():
		return {"valid": false, "error": "no Handle builder profile exists"}
	var profile_id := StringName(profile_entries[0].get("id", StringName()))
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", project_name)
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	state.call("set_active_profile_id", profile_id)
	state.call("set_active_handle_rounding_enabled", false)
	for point: Vector3 in _build_handle_points():
		if int(state.call("append_spline_line_point", point, Vector3.UP)) < 0:
			return {"valid": false, "error": "Handle fixture rejected a control point"}
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		return {"valid": false, "error": "Handle fixture did not generate"}
	var handle_body: Resource = state.call("get_selected_material_body") as Resource
	if handle_body == null:
		return {"valid": false, "error": "generated Handle body is missing"}

	var base_polygon := _build_mask_boundary_polygon(authored_rows)
	var runtime_data: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.build_anchor_relative_profile_runtime_data(
			base_polygon,
			requested_anchor
		)
	)
	if not bool(runtime_data.get("valid", false)):
		return {
			"valid": false,
			"error": "custom Handle runtime profile invalid: %s" % String(
				runtime_data.get("error", "unknown")
			),
		}
	var authored_polygon: PackedVector2Array = runtime_data.get(
		"deposition_polygon_2d_meters",
		PackedVector2Array()
	)
	handle_body.set("material_variant_id", WOOD_MATERIAL_ID)
	handle_body.set("profile_polygon_2d_meters", authored_polygon)
	handle_body.set(
		"profile_anchor_2d_meters",
		runtime_data.get("anchor_2d_meters", requested_anchor) as Vector2
	)
	handle_body.set(
		"profile_contact_point_relative_2d_meters",
		runtime_data.get("contact_point_relative_2d_meters", Vector2.ZERO) as Vector2
	)
	handle_body.set(
		"profile_contact_direction_2d",
		runtime_data.get(
			"contact_direction_2d",
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
		) as Vector2
	)
	handle_body.set(
		"profile_contact_distance_meters",
		float(runtime_data.get("contact_distance_meters", 0.0))
	)
	handle_body.set(
		"profile_runtime_schema_version",
		int(runtime_data.get("schema_version", 1))
	)
	handle_body.set("profile_rotation_bias_degrees", 0.0)
	handle_body.call("normalize")
	var committed_layer: Resource = state.call(
		"commit_material_body_as_layer",
		StringName(handle_body.get("body_id"))
	) as Resource
	if committed_layer == null:
		return {"valid": false, "error": "custom Handle did not commit"}

	var frame := _resolve_authored_handle_frame(handle_body)
	var final_polygon := _mirror_polygon_x(authored_polygon)
	var absolute_profile_centers := _sample_profile_cell_centers(final_polygon)
	var profile_sample_center := _average_vector2(absolute_profile_centers)
	var centered_final_polygon := _translate_vector2_array(
		final_polygon,
		-profile_sample_center
	)
	var centered_profile_centers := _translate_vector2_array(
		absolute_profile_centers,
		-profile_sample_center
	)
	var path_points: PackedVector3Array = handle_body.get("path_points")
	var expected_grip_center_local := (
		path_points[1]
		+ (frame.get("axis_x", Vector3.UP) as Vector3) * profile_sample_center.x
		+ (frame.get("axis_y", Vector3.FORWARD) as Vector3) * profile_sample_center.y
	)
	var mesh_packet := _build_profile_prism_packet(
		path_points,
		final_polygon,
		frame
	)
	if not bool(mesh_packet.get("ok", false)):
		return {
			"valid": false,
			"error": String(mesh_packet.get("error", "could not build final prism")),
		}
	var wip := _build_v2_wip_from_state(state, wip_id, project_name)
	var contract: Dictionary = ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
		wip,
		mesh_packet,
		CELL_SIZE_METERS
	)
	if not bool(contract.get("valid", false)):
		return {
			"valid": false,
			"error": "adapter rejected fixture: %s" % String(contract.get("error", "")),
		}
	wip.stage2_item_state = contract.get("stage2_item_state") as Resource
	var baked_profile: BakedProfile = contract.get("baked_profile") as BakedProfile
	wip.latest_baked_profile_snapshot = baked_profile
	return {
		"valid": true,
		"wip": wip,
		"handle_body": handle_body,
		"frame": frame,
		"authored_polygon": authored_polygon,
		# GripShellCenter follows the arithmetic mean of the sampled profile,
		# so both the visible ring and published offsets are centered here.
		"final_polygon": centered_final_polygon,
		"expected_profile_centers_2d": centered_profile_centers,
		# These remain in the authored weapon/item frame and prove that moving
		# GripShellCenter did not move either the visible mesh or collision shell.
		"absolute_final_polygon": final_polygon,
		"absolute_profile_centers_2d": absolute_profile_centers,
		"profile_sample_center_2d": profile_sample_center,
		"expected_grip_center_item_local": expected_grip_center_local,
		"contract_grip_center_item_local": (
			baked_profile.primary_grip_contact_position * CELL_SIZE_METERS
		),
		"contract_profile_offsets_minor": PackedVector2Array(
			baked_profile.primary_grip_profile_offsets_minor_meters
		),
		"requested_anchor": requested_anchor,
	}


func _build_v2_wip_from_state(
	authoring_state: Resource,
	wip_id: StringName,
	project_name: String
) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = wip_id
	wip.forge_project_name = project_name
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


func _build_v1_visible_oracle_wip(
	authored_rows: Array[String],
	wip_id: StringName
) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = wip_id
	wip.forge_project_name = "V1 Skill Crafter Grip Oracle"
	CraftedItemWIPScript.apply_builder_path_defaults(
		wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var row_count := authored_rows.size()
	var column_count := _max_row_width(authored_rows)
	var layer_map: Dictionary = {}
	for axial_index in range(26):
		for row_index in range(row_count):
			var row_text := authored_rows[row_index]
			for column_index in range(row_text.length()):
				if row_text.substr(column_index, 1) != "1":
					continue
				# This maps the authored V2 profile through the established final
				# mirror_x and into V1's (+Y, FORWARD/-Z) slice convention.
				# Authored profile X maps to V1 +Y and authored profile Y maps
				# to V1 FORWARD/-Z. Keep those two extents distinct so a
				# non-square centered profile catches a transposed oracle.
				var legacy_y := 4 + (column_count - 1 - column_index)
				var legacy_z := 4 + row_index
				_add_v1_cell(
					layer_map,
					Vector3i(axial_index, legacy_y, legacy_z),
					WOOD_MATERIAL_ID
				)
	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_key: Variant in ordered_layers:
		wip.layers.append(layer_map[layer_key])
	wip.ensure_combat_animation_station_state()
	return wip


func _add_v1_cell(
	layer_map: Dictionary,
	grid_position: Vector3i,
	material_variant_id: StringName
) -> void:
	if not layer_map.has(grid_position.z):
		var layer: LayerAtom = LayerAtomScript.new()
		layer.layer_index = grid_position.z
		layer.cells = []
		layer_map[grid_position.z] = layer
	var cell: CellAtom = CellAtomScript.new()
	cell.grid_position = grid_position
	cell.layer_index = grid_position.z
	cell.material_variant_id = material_variant_id
	var target_layer: LayerAtom = layer_map[grid_position.z]
	target_layer.cells.append(cell)


func _capture_skill_crafter_snapshot(
	library: PlayerForgeWipLibraryState,
	wip_id: StringName,
	label: String,
	fixture: Dictionary
) -> Dictionary:
	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library
	root.add_child(fake_player)
	var ui = CombatAnimationStationUIScene.instantiate()
	root.add_child(ui)
	await _wait_process_frames(3)
	ui.open_for(fake_player, "Grip Parity %s" % label)
	await _wait_process_frames(5)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(
		wip_id,
		&"hand_right",
		false,
		true
	)
	await _wait_process_frames(8)
	var slot_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await _wait_process_frames(8)
	# The initial open-mount baseline intentionally clears weapon/finger guidance.
	# Move into the actual authored in-combat pose with the same public Skill
	# Crafter action a user invokes when editing weapon orientation.
	var authored_pose_ok: bool = ui.set_selected_motion_node_weapon_orientation(
		Vector3(0.0, 0.0, 12.0),
		false,
		true,
		true,
		true,
		true
	)
	await _wait_process_frames(10)
	await _wait_physics_frames(3)
	var snapshot := _read_skill_crafter_snapshot(ui, label)
	snapshot["open_ok"] = open_ok
	snapshot["slot_ok"] = slot_ok
	snapshot["authored_pose_ok"] = authored_pose_ok
	if not fixture.is_empty() and bool(snapshot.get("valid", false)):
		var grip_center: Node3D = snapshot.get("_grip_center") as Node3D
		var grip_area: Area3D = snapshot.get("_grip_area") as Area3D
		var frame: Dictionary = fixture.get("frame", {}) as Dictionary
		var expected_centers: PackedVector2Array = fixture.get(
			"expected_profile_centers_2d",
			PackedVector2Array()
		)
		snapshot["ray_probe"] = _probe_expected_grip_surface(
			grip_center,
			grip_area,
			expected_centers,
			frame
		)
	snapshot.erase("_grip_center")
	snapshot.erase("_grip_area")
	ui.free()
	fake_player.free()
	await process_frame
	return snapshot


func _read_skill_crafter_snapshot(ui: Node, label: String) -> Dictionary:
	var snapshot := {"valid": false, "label": label}
	if ui == null or ui.get("preview_subviewport") == null:
		snapshot["error"] = "Skill Crafter preview viewport is missing"
		return snapshot
	var preview_subviewport: SubViewport = ui.get("preview_subviewport") as SubViewport
	var preview_root: Node3D = preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor: Node3D = preview_root.get_node_or_null(
		"PreviewActorPivot/PreviewActor"
	) as Node3D if preview_root != null else null
	var held_item: Node3D = preview_root.get_meta(
		"preview_held_item",
		null
	) as Node3D if preview_root != null else null
	var grip_center: Node3D = held_item.get_node_or_null(
		"PrimaryGripGuide/GripShellCenter"
	) as Node3D if held_item != null else null
	var grip_area: Area3D = grip_center.get_node_or_null(
		"GripContactArea"
	) as Area3D if grip_center != null else null
	var mesh_instance := _find_primary_visible_mesh(held_item)
	var basis_anchor: Node3D = held_item.get_node_or_null(
		"PrimaryGripAnchor/PrimaryGripBasisAnchor"
	) as Node3D if held_item != null else null
	if (
		preview_root == null
		or actor == null
		or held_item == null
		or grip_center == null
		or grip_area == null
		or mesh_instance == null
		or basis_anchor == null
	):
		snapshot["error"] = "Skill Crafter did not create the complete actor/weapon/grip graph"
		return snapshot
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var dominant_contact_rays: Array = debug_state.get(
		"dominant_finger_contact_ray_debug",
		[]
	) as Array
	var proxy_centers := PackedVector3Array()
	var proxy_centers_held_local := PackedVector3Array()
	var proxy_sizes := PackedVector3Array()
	for child_node: Node in grip_area.get_children():
		var collision_shape := child_node as CollisionShape3D
		if collision_shape == null or collision_shape.shape is not BoxShape3D:
			continue
		proxy_centers.append(collision_shape.position)
		proxy_centers_held_local.append(
			held_item.to_local(collision_shape.to_global(Vector3.ZERO))
		)
		proxy_sizes.append((collision_shape.shape as BoxShape3D).size)
	var published_profile_offsets := PackedVector2Array()
	var published_offsets_array: Array = grip_center.get_meta(
		"grip_shell_profile_offsets_minor",
		[]
	) as Array
	for offset_variant: Variant in published_offsets_array:
		published_profile_offsets.append(offset_variant as Vector2)
	var mesh_vertices_grip_local := _collect_mesh_vertices_relative_to(
		mesh_instance,
		grip_center
	)
	var mesh_vertices_held_local := _collect_mesh_vertices_relative_to(
		mesh_instance,
		held_item
	)
	var skeleton: Skeleton3D = actor.get_node_or_null(
		"JosieModel/Josie/Skeleton3D"
	) as Skeleton3D
	var bone_rotations: Dictionary = {}
	var bone_positions_grip_local: Dictionary = {}
	var finger_target_positions_grip_local: Dictionary = {}
	var finger_tip_to_target_distances_meters: Dictionary = {}
	var finger_ray_counts: Dictionary = {}
	var finger_ray_hit_counts: Dictionary = {}
	if skeleton != null:
		for bone_name: String in RIGHT_FINGER_BONES:
			var bone_index := skeleton.find_bone(bone_name)
			if bone_index < 0:
				continue
			bone_rotations[bone_name] = skeleton.get_bone_pose_rotation(bone_index)
			var bone_world := skeleton.to_global(
				skeleton.get_bone_global_pose(bone_index).origin
			)
			bone_positions_grip_local[bone_name] = grip_center.to_local(bone_world)
	for finger_id: String in FINGER_IDS:
		finger_ray_counts[finger_id] = _count_finger_rays(
			dominant_contact_rays,
			finger_id
		)
		finger_ray_hit_counts[finger_id] = _count_finger_ray_hits(
			dominant_contact_rays,
			finger_id
		)
		var target_label := String(RIGHT_FINGER_TARGET_LABELS.get(finger_id, ""))
		var target: Node3D = actor.get_node_or_null(
			"IkTargets/RightFingerGripTargets/%sGripTarget" % target_label
		) as Node3D
		if target == null:
			continue
		var target_grip_local := grip_center.to_local(target.global_position)
		finger_target_positions_grip_local[finger_id] = target_grip_local
		var end_bone_name := String(RIGHT_FINGER_END_BONES.get(finger_id, ""))
		if bone_positions_grip_local.has(end_bone_name):
			finger_tip_to_target_distances_meters[finger_id] = (
				(bone_positions_grip_local[end_bone_name] as Vector3).distance_to(
					target_grip_local
				)
			)
	var mount_transform: Transform3D = held_item.get_meta(
		"hand_mount_local_transform",
		held_item.transform
	) as Transform3D
	var grip_major_axis: Vector3 = grip_center.get_meta(
		"grip_shell_major_axis_local",
		Vector3.ZERO
	) as Vector3
	var grip_minor_axis_a: Vector3 = grip_center.get_meta(
		"grip_shell_minor_axis_a_local",
		Vector3.ZERO
	) as Vector3
	var grip_minor_axis_b: Vector3 = grip_center.get_meta(
		"grip_shell_minor_axis_b_local",
		Vector3.ZERO
	) as Vector3
	var effective_minor_axis_a_local := Vector3.ZERO
	var effective_minor_axis_b_local := Vector3.ZERO
	if (
		skeleton != null
		and grip_major_axis.length_squared() > 0.000001
		and grip_minor_axis_a.length_squared() > 0.000001
		and grip_minor_axis_b.length_squared() > 0.000001
	):
		var finger_presenter: RefCounted = PlayerRigFingerGripPresenterScript.new()
		var effective_axes: Dictionary = finger_presenter.call(
			"_resolve_roll_decoupled_contact_axes",
			skeleton,
			&"hand_right",
			(grip_center.global_basis * grip_major_axis).normalized(),
			(grip_center.global_basis * grip_minor_axis_a).normalized(),
			(grip_center.global_basis * grip_minor_axis_b).normalized()
		) as Dictionary
		effective_minor_axis_a_local = (
			grip_center.global_basis.inverse()
			* (effective_axes.get("minor_axis_a_world", Vector3.ZERO) as Vector3)
		).normalized()
		effective_minor_axis_b_local = (
			grip_center.global_basis.inverse()
			* (effective_axes.get("minor_axis_b_world", Vector3.ZERO) as Vector3)
		).normalized()
	snapshot.merge({
		"valid": true,
		"debug_state": debug_state,
		"held_basis_local": mount_transform.basis.orthonormalized(),
		"current_held_basis_preview_local": (
			preview_root.global_basis.inverse() * held_item.global_basis
		).orthonormalized(),
		"grip_basis_local": basis_anchor.transform.basis.orthonormalized(),
		"grip_major_axis_local": grip_major_axis,
		"grip_minor_axis_a_local": grip_minor_axis_a,
		"grip_minor_axis_b_local": grip_minor_axis_b,
		"effective_minor_axis_a_local": effective_minor_axis_a_local,
		"effective_minor_axis_b_local": effective_minor_axis_b_local,
		"cell_world_size": float(grip_center.get_meta(
			"grip_shell_cell_world_size",
			0.0
		)),
		"proxy_centers": proxy_centers,
		"proxy_centers_held_local": proxy_centers_held_local,
		"proxy_sizes": proxy_sizes,
		"published_profile_offsets_minor": published_profile_offsets,
		"grip_center_held_local": held_item.to_local(grip_center.global_position),
		"mesh_vertices_grip_local": mesh_vertices_grip_local,
		"mesh_vertices_held_local": mesh_vertices_held_local,
		"mesh_aabb_grip_local": _calculate_aabb(mesh_vertices_grip_local),
		"bone_rotations": bone_rotations,
		"bone_positions_grip_local": bone_positions_grip_local,
		"finger_target_positions_grip_local": finger_target_positions_grip_local,
		"finger_tip_to_target_distances_meters": finger_tip_to_target_distances_meters,
		"finger_ray_counts": finger_ray_counts,
		"finger_ray_hit_counts": finger_ray_hit_counts,
		"finger_contact_readiness": float(debug_state.get(
			"dominant_finger_contact_readiness",
			-1.0
		)),
		"finger_contact_distance_meters": float(debug_state.get(
			"dominant_finger_contact_distance_meters",
			-1.0
		)),
		"max_finger_joint_proxy_penetration_meters": _max_joint_proxy_penetration(
			bone_positions_grip_local,
			proxy_centers,
			proxy_sizes
		),
		"thumb_ray_hit_count": _count_finger_ray_hits(
			dominant_contact_rays,
			"thumb"
		),
		"_grip_center": grip_center,
		"_grip_area": grip_area,
	}, true)
	return snapshot


func _evaluate_baseline_parity(v1: Dictionary, v2: Dictionary) -> void:
	var snapshots_valid := (
		bool(v1.get("valid", false))
		and bool(v2.get("valid", false))
		and bool(v1.get("open_ok", false))
		and bool(v2.get("open_ok", false))
		and bool(v1.get("authored_pose_ok", false))
		and bool(v2.get("authored_pose_ok", false))
	)
	if not snapshots_valid:
		_check(false, "baseline_skill_crafter_snapshots_valid", "V1/V2 Skill Crafter snapshot failed")
		return
	var v1_centers: PackedVector3Array = v1.get("proxy_centers", PackedVector3Array())
	var v2_centers: PackedVector3Array = v2.get("proxy_centers", PackedVector3Array())
	var shell_centers_match := _unordered_vector3_sets_match(
		v1_centers,
		v2_centers,
		POSITION_EPSILON_METERS
	)
	var v1_aabb: AABB = v1.get("mesh_aabb_grip_local", AABB()) as AABB
	var v2_aabb: AABB = v2.get("mesh_aabb_grip_local", AABB()) as AABB
	var visual_bounds_match := (
		absf(v1_aabb.position.x - v2_aabb.position.x)
			<= LEGACY_AXIAL_QUANTIZATION_EPSILON_METERS
		and absf(v1_aabb.position.y - v2_aabb.position.y) <= POSITION_EPSILON_METERS
		and absf(v1_aabb.position.z - v2_aabb.position.z) <= POSITION_EPSILON_METERS
		and v1_aabb.size.distance_to(v2_aabb.size) <= POSITION_EPSILON_METERS
	)
	var cell_size_match := absf(
		float(v1.get("cell_world_size", 0.0))
		- float(v2.get("cell_world_size", 0.0))
	) <= 0.000001
	result_lines.append("baseline_shell_centers_match=%s" % str(shell_centers_match))
	result_lines.append("baseline_visual_bounds_match=%s" % str(visual_bounds_match))
	result_lines.append("baseline_cell_size_match=%s" % str(cell_size_match))
	result_lines.append("baseline_axial_origin_delta_meters=%.6f" % absf(
		v1_aabb.position.x - v2_aabb.position.x
	))
	_check(
		shell_centers_match and visual_bounds_match and cell_size_match,
		"baseline_v1_v2_geometry_and_collision_parity",
		"equivalent V1/V2 handles do not expose the same visible bounds and grip cells"
	)

	var all_runtime_evidence_present := true
	var max_finger_target_delta := 0.0
	var v1_targets: Dictionary = v1.get(
		"finger_target_positions_grip_local",
		{}
	) as Dictionary
	var v2_targets: Dictionary = v2.get(
		"finger_target_positions_grip_local",
		{}
	) as Dictionary
	var v1_ray_counts: Dictionary = v1.get("finger_ray_counts", {}) as Dictionary
	var v2_ray_counts: Dictionary = v2.get("finger_ray_counts", {}) as Dictionary
	var v1_hit_counts: Dictionary = v1.get("finger_ray_hit_counts", {}) as Dictionary
	var v2_hit_counts: Dictionary = v2.get("finger_ray_hit_counts", {}) as Dictionary
	for finger_id: String in FINGER_IDS:
		if (
			not v1_targets.has(finger_id)
			or not v2_targets.has(finger_id)
			or int(v1_ray_counts.get(finger_id, 0)) <= 0
			or int(v2_ray_counts.get(finger_id, 0)) <= 0
			or int(v1_hit_counts.get(finger_id, 0)) <= 0
			or int(v2_hit_counts.get(finger_id, 0)) <= 0
		):
			all_runtime_evidence_present = false
			continue
		max_finger_target_delta = maxf(
			max_finger_target_delta,
			(v1_targets[finger_id] as Vector3).distance_to(
				v2_targets[finger_id] as Vector3
			)
		)
		result_lines.append("baseline_%s_target_delta_meters=%.6f" % [
			finger_id,
			(v1_targets[finger_id] as Vector3).distance_to(
				v2_targets[finger_id] as Vector3
			),
		])
	result_lines.append("baseline_max_finger_target_delta_meters=%.6f" % max_finger_target_delta)
	_check(
		all_runtime_evidence_present,
		"all_finger_runtime_evidence_present_ok",
		"unchanged Skill Crafter did not expose a contact target and ray hit for all five fingers"
	)
	result_lines.append("baseline_all_finger_target_parity_ok=%s" % str(
		max_finger_target_delta <= POSITION_EPSILON_METERS
	))
	var baseline_ray_probe: Dictionary = v2.get("ray_probe", {}) as Dictionary
	result_lines.append("baseline_v2_ray_probe_attempt_count=%d" % int(
		baseline_ray_probe.get("attempt_count", 0)
	))
	result_lines.append("baseline_v2_ray_probe_hit_count=%d" % int(
		baseline_ray_probe.get("grip_area_hit_count", 0)
	))
	result_lines.append("baseline_v2_ray_probe_aligned_count=%d" % int(
		baseline_ray_probe.get("aligned_hit_count", 0)
	))
	result_lines.append("baseline_v2_ray_probe_max_error_meters=%s" % str(float(
		baseline_ray_probe.get("max_alignment_error_meters", INF)
	)))

	var held_basis_delta := _basis_delta_degrees(
		v1.get("held_basis_local", Basis.IDENTITY) as Basis,
		v2.get("held_basis_local", Basis.IDENTITY) as Basis
	)
	var current_held_basis_delta := _basis_delta_degrees(
		v1.get("current_held_basis_preview_local", Basis.IDENTITY) as Basis,
		v2.get("current_held_basis_preview_local", Basis.IDENTITY) as Basis
	)
	var grip_basis_delta := _basis_delta_degrees(
		v1.get("grip_basis_local", Basis.IDENTITY) as Basis,
		v2.get("grip_basis_local", Basis.IDENTITY) as Basis
	)
	var v1_major: Vector3 = v1.get("grip_major_axis_local", Vector3.ZERO) as Vector3
	var v2_major: Vector3 = v2.get("grip_major_axis_local", Vector3.ZERO) as Vector3
	var v1_minor_a: Vector3 = v1.get("grip_minor_axis_a_local", Vector3.ZERO) as Vector3
	var v2_minor_a: Vector3 = v2.get("grip_minor_axis_a_local", Vector3.ZERO) as Vector3
	var v1_minor_b: Vector3 = v1.get("grip_minor_axis_b_local", Vector3.ZERO) as Vector3
	var v2_minor_b: Vector3 = v2.get("grip_minor_axis_b_local", Vector3.ZERO) as Vector3
	var v1_effective_minor_a: Vector3 = v1.get(
		"effective_minor_axis_a_local",
		Vector3.ZERO
	) as Vector3
	var v2_effective_minor_a: Vector3 = v2.get(
		"effective_minor_axis_a_local",
		Vector3.ZERO
	) as Vector3
	var v1_effective_minor_b: Vector3 = v1.get(
		"effective_minor_axis_b_local",
		Vector3.ZERO
	) as Vector3
	var v2_effective_minor_b: Vector3 = v2.get(
		"effective_minor_axis_b_local",
		Vector3.ZERO
	) as Vector3
	var major_dot := (
		v1_major.normalized().dot(v2_major.normalized())
		if v1_major.length_squared() > 0.000001 and v2_major.length_squared() > 0.000001
		else -1.0
	)
	var minor_a_dot := (
		v1_minor_a.normalized().dot(v2_minor_a.normalized())
		if v1_minor_a.length_squared() > 0.000001 and v2_minor_a.length_squared() > 0.000001
		else -1.0
	)
	var minor_b_dot := (
		v1_minor_b.normalized().dot(v2_minor_b.normalized())
		if v1_minor_b.length_squared() > 0.000001 and v2_minor_b.length_squared() > 0.000001
		else -1.0
	)
	var effective_minor_a_dot := (
		v1_effective_minor_a.normalized().dot(v2_effective_minor_a.normalized())
		if (
			v1_effective_minor_a.length_squared() > 0.000001
			and v2_effective_minor_a.length_squared() > 0.000001
		)
		else -1.0
	)
	var effective_minor_b_dot := (
		v1_effective_minor_b.normalized().dot(v2_effective_minor_b.normalized())
		if (
			v1_effective_minor_b.length_squared() > 0.000001
			and v2_effective_minor_b.length_squared() > 0.000001
		)
		else -1.0
	)
	result_lines.append("baseline_held_basis_delta_degrees=%.4f" % held_basis_delta)
	result_lines.append("baseline_current_held_basis_delta_degrees=%.4f" % current_held_basis_delta)
	result_lines.append("baseline_grip_basis_delta_degrees=%.4f" % grip_basis_delta)
	result_lines.append("baseline_major_axis_dot=%.6f" % major_dot)
	result_lines.append("baseline_minor_axis_a_dot=%.6f" % minor_a_dot)
	result_lines.append("baseline_minor_axis_b_dot=%.6f" % minor_b_dot)
	result_lines.append("baseline_effective_minor_axis_a_dot=%.6f" % effective_minor_a_dot)
	result_lines.append("baseline_effective_minor_axis_b_dot=%.6f" % effective_minor_b_dot)
	result_lines.append("baseline_v1_grip_axes=%s|%s|%s" % [
		str(v1_major),
		str(v1_minor_a),
		str(v1_minor_b),
	])
	result_lines.append("baseline_v2_grip_axes=%s|%s|%s" % [
		str(v2_major),
		str(v2_minor_a),
		str(v2_minor_b),
	])
	result_lines.append("baseline_v1_effective_finger_axes=%s|%s" % [
		str(v1_effective_minor_a),
		str(v1_effective_minor_b),
	])
	result_lines.append("baseline_v2_effective_finger_axes=%s|%s" % [
		str(v2_effective_minor_a),
		str(v2_effective_minor_b),
	])
	_check(
		held_basis_delta <= BASIS_EPSILON_DEGREES
		and current_held_basis_delta <= BASIS_EPSILON_DEGREES
		and grip_basis_delta <= BASIS_EPSILON_DEGREES
		and major_dot >= 0.9999
		and effective_minor_a_dot >= 0.9999
		and effective_minor_b_dot >= 0.9999,
		"weapon_grip_basis_orientation_ok",
		"V2 adapter output changes the effective weapon/finger-contact frame consumed by existing IK"
	)
	var max_finger_pose_delta := 0.0
	var all_finger_poses_present := true
	var v1_rotations: Dictionary = v1.get("bone_rotations", {}) as Dictionary
	var v2_rotations: Dictionary = v2.get("bone_rotations", {}) as Dictionary
	for bone_name: String in RIGHT_FINGER_BONES:
		if not v1_rotations.has(bone_name) or not v2_rotations.has(bone_name):
			all_finger_poses_present = false
			continue
		max_finger_pose_delta = maxf(
			max_finger_pose_delta,
			_quaternion_delta_degrees(
				v1_rotations[bone_name] as Quaternion,
				v2_rotations[bone_name] as Quaternion
			)
		)
	result_lines.append("baseline_all_finger_pose_max_delta_degrees=%s" % str(
		max_finger_pose_delta
	))
	_check(
		all_finger_poses_present and max_finger_pose_delta <= THUMB_EPSILON_DEGREES,
		"all_finger_pose_matches_v1_ok",
		"the unchanged Skill Crafter direct curl pose differs between equivalent V1/V2 handles"
	)

	var max_thumb_delta := 0.0
	for bone_name in [
		"CC_Base_R_Thumb1",
		"CC_Base_R_Thumb2",
		"CC_Base_R_Thumb3",
	]:
		if not v1_rotations.has(bone_name) or not v2_rotations.has(bone_name):
			max_thumb_delta = INF
			continue
		max_thumb_delta = maxf(
			max_thumb_delta,
			_quaternion_delta_degrees(
				v1_rotations[bone_name] as Quaternion,
				v2_rotations[bone_name] as Quaternion
			)
		)
	result_lines.append("baseline_thumb_pose_max_delta_degrees=%s" % str(max_thumb_delta))
	result_lines.append("baseline_v1_thumb_ray_hit_count=%d" % int(v1.get("thumb_ray_hit_count", 0)))
	result_lines.append("baseline_v2_thumb_ray_hit_count=%d" % int(v2.get("thumb_ray_hit_count", 0)))
	_check(
		max_thumb_delta <= THUMB_EPSILON_DEGREES
		and int(v1.get("thumb_ray_hit_count", 0)) > 0
		and int(v1.get("thumb_ray_hit_count", 0)) == int(v2.get("thumb_ray_hit_count", 0)),
		"thumb_engagement_matches_v1_ok",
		"unchanged Skill Crafter produces a different thumb pose/contact result for equivalent V2 geometry"
	)


func _evaluate_asymmetric_surface_alignment(
	fixture: Dictionary,
	snapshot: Dictionary
) -> void:
	if not bool(snapshot.get("valid", false)) or not bool(snapshot.get("open_ok", false)):
		_check(false, "asymmetric_skill_crafter_snapshot_valid", "asymmetric V2 preview failed")
		return
	var frame: Dictionary = fixture.get("frame", {}) as Dictionary
	var tangent: Vector3 = frame.get("tangent", Vector3.RIGHT) as Vector3
	var axis_x: Vector3 = frame.get("axis_x", Vector3.UP) as Vector3
	var axis_y: Vector3 = frame.get("axis_y", Vector3.FORWARD) as Vector3
	var final_polygon: PackedVector2Array = fixture.get(
		"final_polygon",
		PackedVector2Array()
	)
	var expected_centers: PackedVector2Array = fixture.get(
		"expected_profile_centers_2d",
		PackedVector2Array()
	)
	var absolute_final_polygon: PackedVector2Array = fixture.get(
		"absolute_final_polygon",
		PackedVector2Array()
	)
	var absolute_expected_centers: PackedVector2Array = fixture.get(
		"absolute_profile_centers_2d",
		PackedVector2Array()
	)
	var mesh_vertices: PackedVector3Array = snapshot.get(
		"mesh_vertices_grip_local",
		PackedVector3Array()
	)
	var actual_ring := _extract_profile_ring_2d(
		mesh_vertices,
		tangent,
		axis_x,
		axis_y
	)
	var visible_vertices_match := _unordered_vector2_sets_match(
		actual_ring,
		final_polygon,
		POSITION_EPSILON_METERS
	)
	var actual_proxy_centers_2d := PackedVector2Array()
	for center: Vector3 in snapshot.get("proxy_centers", PackedVector3Array()) as PackedVector3Array:
		actual_proxy_centers_2d.append(Vector2(center.dot(axis_x), center.dot(axis_y)))
	var proxy_centers_match := _unordered_vector2_sets_match(
		actual_proxy_centers_2d,
		expected_centers,
		POSITION_EPSILON_METERS
	)
	var visible_centroid := _calculate_polygon_centroid(actual_ring)
	var expected_centroid := _calculate_polygon_centroid(final_polygon)
	var proxy_centroid := _average_vector2(actual_proxy_centers_2d)
	var expected_proxy_centroid := _average_vector2(expected_centers)
	var published_offsets: PackedVector2Array = snapshot.get(
		"published_profile_offsets_minor",
		PackedVector2Array()
	)
	var published_offset_mean := _average_vector2(published_offsets)
	var contract_offsets: PackedVector2Array = fixture.get(
		"contract_profile_offsets_minor",
		PackedVector2Array()
	)
	var contract_offset_mean := _average_vector2(contract_offsets)
	var visible_center_error := visible_centroid.distance_to(expected_centroid)
	var proxy_center_error := proxy_centroid.distance_to(expected_proxy_centroid)
	var proxy_nearest_error := _max_nearest_vector2_distance(
		actual_proxy_centers_2d,
		expected_centers
	)
	var offset_mean_centered := (
		not published_offsets.is_empty()
		and published_offsets.size() == expected_centers.size()
		and published_offset_mean.length() <= POSITION_EPSILON_METERS
		and contract_offset_mean.length() <= POSITION_EPSILON_METERS
	)

	# Reconstruct the source weapon/item frame by adding the adapter's rebased
	# contact center back to the GripShellCenter-local visible/proxy geometry.
	# This is the absolute counterpart to the centered-local checks above.
	var expected_grip_center: Vector3 = fixture.get(
		"expected_grip_center_item_local",
		Vector3.INF
	) as Vector3
	var contract_grip_center: Vector3 = fixture.get(
		"contract_grip_center_item_local",
		Vector3.INF
	) as Vector3
	var grip_center_contract_error := contract_grip_center.distance_to(
		expected_grip_center
	)
	var contract_grip_center_2d := Vector2(
		contract_grip_center.dot(axis_x),
		contract_grip_center.dot(axis_y)
	)
	var reconstructed_absolute_ring := _translate_vector2_array(
		actual_ring,
		contract_grip_center_2d
	)
	var reconstructed_absolute_proxy_centers := _translate_vector2_array(
		actual_proxy_centers_2d,
		contract_grip_center_2d
	)
	var absolute_visible_match := _unordered_vector2_sets_match(
		reconstructed_absolute_ring,
		absolute_final_polygon,
		POSITION_EPSILON_METERS
	)
	var absolute_proxy_match := _unordered_vector2_sets_match(
		reconstructed_absolute_proxy_centers,
		absolute_expected_centers,
		POSITION_EPSILON_METERS
	)
	var absolute_alignment_ok := (
		grip_center_contract_error <= POSITION_EPSILON_METERS
		and absolute_visible_match
		and absolute_proxy_match
	)
	result_lines.append("asymmetric_visible_vertices_match=%s" % str(visible_vertices_match))
	result_lines.append("asymmetric_proxy_centers_match=%s" % str(proxy_centers_match))
	result_lines.append("asymmetric_visible_profile_vertex_count=%d" % actual_ring.size())
	result_lines.append("asymmetric_expected_profile_vertex_count=%d" % final_polygon.size())
	result_lines.append("asymmetric_proxy_cell_count=%d" % actual_proxy_centers_2d.size())
	result_lines.append("asymmetric_expected_proxy_cell_count=%d" % expected_centers.size())
	result_lines.append("asymmetric_visible_centroid_2d=%s" % str(visible_centroid))
	result_lines.append("asymmetric_proxy_centroid_2d=%s" % str(proxy_centroid))
	result_lines.append("asymmetric_expected_centroid_2d=%s" % str(expected_centroid))
	result_lines.append("asymmetric_expected_proxy_centroid_2d=%s" % str(
		expected_proxy_centroid
	))
	result_lines.append("asymmetric_published_offset_mean_2d=%s" % str(
		published_offset_mean
	))
	result_lines.append("asymmetric_contract_offset_mean_2d=%s" % str(
		contract_offset_mean
	))
	result_lines.append("asymmetric_visible_center_error_meters=%.6f" % visible_center_error)
	result_lines.append("asymmetric_proxy_center_error_meters=%.6f" % proxy_center_error)
	result_lines.append("asymmetric_proxy_max_nearest_error_meters=%.6f" % proxy_nearest_error)
	result_lines.append("asymmetric_proxy_centers_2d=%s" % str(actual_proxy_centers_2d))
	result_lines.append("asymmetric_expected_centers_2d=%s" % str(expected_centers))
	result_lines.append("asymmetric_profile_sample_center_2d=%s" % str(
		fixture.get("profile_sample_center_2d", Vector2.ZERO)
	))
	result_lines.append("asymmetric_expected_grip_center_item_local=%s" % str(
		expected_grip_center
	))
	result_lines.append("asymmetric_contract_grip_center_item_local=%s" % str(
		contract_grip_center
	))
	result_lines.append("asymmetric_grip_center_contract_error_meters=%.6f" % (
		grip_center_contract_error
	))
	result_lines.append("asymmetric_absolute_visible_vertices_match=%s" % str(
		absolute_visible_match
	))
	result_lines.append("asymmetric_absolute_proxy_centers_match=%s" % str(
		absolute_proxy_match
	))
	_check(
		offset_mean_centered,
		"profile_offset_mean_centered_ok",
		"adapter/runtime Handle profile offsets are not centered on GripShellCenter"
	)
	_check(
		visible_vertices_match
		and proxy_centers_match
		and visible_center_error <= POSITION_EPSILON_METERS
		and proxy_center_error <= POSITION_EPSILON_METERS
		and offset_mean_centered
		and absolute_alignment_ok,
		"geometric_slice_center_ok",
		"V2 off-center/asymmetric slice is not centered locally and preserved in the source item frame"
	)

	var ray_probe: Dictionary = snapshot.get("ray_probe", {}) as Dictionary
	var ray_attempt_count := int(ray_probe.get("attempt_count", 0))
	var ray_hit_count := int(ray_probe.get("grip_area_hit_count", 0))
	var ray_aligned_count := int(ray_probe.get("aligned_hit_count", 0))
	var ray_max_error := float(ray_probe.get("max_alignment_error_meters", INF))
	result_lines.append("asymmetric_ray_probe_attempt_count=%d" % ray_attempt_count)
	result_lines.append("asymmetric_ray_probe_grip_area_hit_count=%d" % ray_hit_count)
	result_lines.append("asymmetric_ray_probe_aligned_hit_count=%d" % ray_aligned_count)
	result_lines.append("asymmetric_ray_probe_max_error_meters=%s" % str(ray_max_error))
	result_lines.append("legacy_identity_box_surface_tolerance_meters=%s" % str(
		RAY_HIT_EPSILON_METERS
	))
	_check(
		visible_vertices_match
		and proxy_centers_match
		and absolute_alignment_ok
		and ray_attempt_count == 14
		and ray_hit_count == 14
		and ray_aligned_count == 14
		and ray_max_error <= RAY_HIT_EPSILON_METERS,
		"grip_contact_ray_visible_surface_alignment_ok",
		"GripContactArea did not preserve absolute visible/proxy alignment and the 14/14 boundary-ray gate"
	)


func _probe_expected_grip_surface(
	grip_center: Node3D,
	grip_area: Area3D,
	expected_centers_2d: PackedVector2Array,
	frame: Dictionary
) -> Dictionary:
	var result := {
		"attempt_count": 0,
		"grip_area_hit_count": 0,
		"aligned_hit_count": 0,
		"max_alignment_error_meters": 0.0,
	}
	if grip_center == null or grip_area == null or expected_centers_2d.is_empty():
		return result
	var axis_x: Vector3 = frame.get("axis_x", Vector3.UP) as Vector3
	var axis_y: Vector3 = frame.get("axis_y", Vector3.FORWARD) as Vector3
	var collision_mask := int(grip_center.get_meta("grip_shell_collision_layer", 0))
	if collision_mask <= 0:
		return result
	var directions := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	var world_3d := grip_center.get_world_3d()
	if world_3d == null:
		return result
	for center_2d: Vector2 in expected_centers_2d:
		for direction_2d: Vector2 in directions:
			if _vector2_set_has_point(
				expected_centers_2d,
				center_2d + direction_2d * CELL_SIZE_METERS,
				POSITION_EPSILON_METERS
			):
				continue
			var center_local := axis_x * center_2d.x + axis_y * center_2d.y
			var direction_local := (
				axis_x * direction_2d.x + axis_y * direction_2d.y
			).normalized()
			var from_local := center_local + direction_local * CELL_SIZE_METERS * 0.75
			var expected_hit_local := center_local + direction_local * CELL_SIZE_METERS * 0.5
			var query := PhysicsRayQueryParameters3D.create(
				grip_center.to_global(from_local),
				grip_center.to_global(center_local),
				collision_mask
			)
			query.collide_with_areas = true
			query.collide_with_bodies = false
			query.hit_from_inside = false
			var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
			result["attempt_count"] = int(result["attempt_count"]) + 1
			if hit.is_empty() or hit.get("collider", null) != grip_area:
				continue
			result["grip_area_hit_count"] = int(result["grip_area_hit_count"]) + 1
			var hit_local := grip_center.to_local(hit.get("position", Vector3.ZERO) as Vector3)
			var alignment_error := hit_local.distance_to(expected_hit_local)
			result["max_alignment_error_meters"] = maxf(
				float(result["max_alignment_error_meters"]),
				alignment_error
			)
			if alignment_error <= RAY_HIT_EPSILON_METERS:
				result["aligned_hit_count"] = int(result["aligned_hit_count"]) + 1
	return result


func _resolve_authored_handle_frame(handle_body: Resource) -> Dictionary:
	var path_points: PackedVector3Array = handle_body.get("path_points")
	var tangent := ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
		path_points,
		1
	)
	var path_normals: PackedVector3Array = handle_body.get("path_surface_normals")
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
		return {"ok": false, "error": "profile prism polygon did not triangulate"}
	var tangent: Vector3 = frame.get("tangent", Vector3.RIGHT) as Vector3
	var axis_x: Vector3 = frame.get("axis_x", Vector3.UP) as Vector3
	var axis_y: Vector3 = frame.get("axis_y", Vector3.FORWARD) as Vector3
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
	var signed_area := _calculate_signed_polygon_area(profile_polygon)
	for point_index in range(ring_size):
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
		"watertight": true,
		"output_volume_m3": absf(signed_area) * start.distance_to(finish),
		"source_original_ids": PackedStringArray(["verify_handle"]),
		"material_variant_id": WOOD_MATERIAL_ID,
		"source_state_revision": 1,
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
	if actual_normal.dot(desired_normal) >= 0.0:
		indices.append_array(PackedInt32Array([a, b, c]))
	else:
		indices.append_array(PackedInt32Array([a, c, b]))


func _build_mask_boundary_polygon(rows: Array[String]) -> PackedVector2Array:
	var occupied: Dictionary = {}
	var row_count := rows.size()
	var max_width := _max_row_width(rows)
	for row_index in range(row_count):
		var row_text := rows[row_index]
		for column_index in range(row_text.length()):
			if row_text.substr(column_index, 1) == "1":
				occupied[Vector2i(column_index, row_index)] = true
	var edges: Dictionary = {}
	for cell_coord: Vector2i in occupied.keys():
		var x := cell_coord.x
		var y := cell_coord.y
		if not occupied.has(Vector2i(x, y + 1)):
			edges[Vector2i(x, y + 1)] = Vector2i(x + 1, y + 1)
		if not occupied.has(Vector2i(x + 1, y)):
			edges[Vector2i(x + 1, y + 1)] = Vector2i(x + 1, y)
		if not occupied.has(Vector2i(x, y - 1)):
			edges[Vector2i(x + 1, y)] = Vector2i(x, y)
		if not occupied.has(Vector2i(x - 1, y)):
			edges[Vector2i(x, y)] = Vector2i(x, y + 1)
	if edges.is_empty():
		return PackedVector2Array()
	var start: Vector2i = edges.keys()[0] as Vector2i
	for point_variant: Variant in edges.keys():
		var point := point_variant as Vector2i
		if point.y < start.y or (point.y == start.y and point.x < start.x):
			start = point
	var current := start
	var polygon := PackedVector2Array([
		_grid_corner_to_profile_point(start, max_width, row_count),
	])
	var guard := edges.size() + 4
	while guard > 0:
		guard -= 1
		if not edges.has(current):
			break
		current = edges[current] as Vector2i
		if current == start:
			break
		polygon.append(_grid_corner_to_profile_point(current, max_width, row_count))
	return polygon


func _grid_corner_to_profile_point(
	corner: Vector2i,
	width_cells: int,
	height_cells: int
) -> Vector2:
	return Vector2(
		(float(corner.x) - float(width_cells) * 0.5) * CELL_SIZE_METERS,
		(float(height_cells) * 0.5 - float(corner.y)) * CELL_SIZE_METERS
	)


func _sample_profile_cell_centers(polygon: PackedVector2Array) -> PackedVector2Array:
	var samples := PackedVector2Array()
	if polygon.size() < 3:
		return samples
	var bounds := _calculate_polygon_bounds(polygon)
	var column_count := int(floor((bounds.size.x + 0.000001) / CELL_SIZE_METERS))
	var row_count := int(floor((bounds.size.y + 0.000001) / CELL_SIZE_METERS))
	var occupied_size := Vector2(column_count, row_count) * CELL_SIZE_METERS
	var first_center := (
		bounds.position
		+ (bounds.size - occupied_size) * 0.5
		+ Vector2.ONE * CELL_SIZE_METERS * 0.5
	)
	for column_index in range(column_count):
		for row_index in range(row_count):
			var candidate := first_center + Vector2(
				column_index * CELL_SIZE_METERS,
				row_index * CELL_SIZE_METERS
			)
			if _point_is_strictly_inside_polygon(candidate, polygon):
				samples.append(candidate)
	return samples


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


func _mirror_polygon_x(polygon: PackedVector2Array) -> PackedVector2Array:
	var mirrored := PackedVector2Array()
	# Reverse while mirroring so the polygon keeps its original winding.
	for point_index in range(polygon.size() - 1, -1, -1):
		var point := polygon[point_index]
		mirrored.append(Vector2(-point.x, point.y))
	return mirrored


func _translate_vector2_array(
	values: PackedVector2Array,
	offset: Vector2
) -> PackedVector2Array:
	var translated := PackedVector2Array()
	translated.resize(values.size())
	for value_index in range(values.size()):
		translated[value_index] = values[value_index] + offset
	return translated


func _extract_profile_ring_2d(
	vertices: PackedVector3Array,
	tangent: Vector3,
	axis_x: Vector3,
	axis_y: Vector3
) -> PackedVector2Array:
	var ring := PackedVector2Array()
	if vertices.is_empty():
		return ring
	var min_axial := INF
	for vertex: Vector3 in vertices:
		min_axial = minf(min_axial, vertex.dot(tangent))
	for vertex: Vector3 in vertices:
		if absf(vertex.dot(tangent) - min_axial) > POSITION_EPSILON_METERS:
			continue
		var projected := Vector2(vertex.dot(axis_x), vertex.dot(axis_y))
		if not _vector2_set_has_point(ring, projected, POSITION_EPSILON_METERS):
			ring.append(projected)
	return ring


func _collect_mesh_vertices_relative_to(
	mesh_instance: MeshInstance3D,
	reference_node: Node3D
) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	if mesh_instance == null or mesh_instance.mesh == null or reference_node == null:
		return vertices
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		var surface_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in surface_vertices:
			vertices.append(reference_node.to_local(mesh_instance.to_global(vertex)))
	return vertices


func _find_primary_visible_mesh(parent_node: Node) -> MeshInstance3D:
	if parent_node == null:
		return null
	for child_node: Node in parent_node.get_children():
		if child_node is MeshInstance3D:
			var mesh_instance := child_node as MeshInstance3D
			if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
				return mesh_instance
	for child_node: Node in parent_node.get_children():
		var nested := _find_primary_visible_mesh(child_node)
		if nested != null:
			return nested
	return null


func _calculate_aabb(vertices: PackedVector3Array) -> AABB:
	if vertices.is_empty():
		return AABB()
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex: Vector3 in vertices:
		bounds = bounds.expand(vertex)
	return bounds


func _calculate_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_point := polygon[0]
	var max_point := polygon[0]
	for point: Vector2 in polygon:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _calculate_signed_polygon_area(polygon: PackedVector2Array) -> float:
	var twice_area := 0.0
	for point_index in range(polygon.size()):
		var current := polygon[point_index]
		var next := polygon[(point_index + 1) % polygon.size()]
		twice_area += current.x * next.y - next.x * current.y
	return twice_area * 0.5


func _calculate_polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var twice_area := 0.0
	var numerator := Vector2.ZERO
	for point_index in range(polygon.size()):
		var current := polygon[point_index]
		var next := polygon[(point_index + 1) % polygon.size()]
		var cross := current.x * next.y - next.x * current.y
		twice_area += cross
		numerator += (current + next) * cross
	if absf(twice_area) <= 0.000000000001:
		return _average_vector2(polygon)
	return numerator / (3.0 * twice_area)


func _average_vector2(values: PackedVector2Array) -> Vector2:
	if values.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for value: Vector2 in values:
		total += value
	return total / float(values.size())


func _max_joint_proxy_penetration(
	bone_positions: Dictionary,
	proxy_centers: PackedVector3Array,
	proxy_sizes: PackedVector3Array
) -> float:
	var max_penetration := 0.0
	for position_variant: Variant in bone_positions.values():
		var point := position_variant as Vector3
		for proxy_index in range(mini(proxy_centers.size(), proxy_sizes.size())):
			var half_size := proxy_sizes[proxy_index] * 0.5
			var delta := point - proxy_centers[proxy_index]
			if (
				absf(delta.x) <= half_size.x
				and absf(delta.y) <= half_size.y
				and absf(delta.z) <= half_size.z
			):
				max_penetration = maxf(
					max_penetration,
					minf(
						half_size.x - absf(delta.x),
						minf(
							half_size.y - absf(delta.y),
							half_size.z - absf(delta.z)
						)
					)
				)
	return max_penetration


func _count_finger_ray_hits(ray_entries: Array, finger_name: String) -> int:
	var count := 0
	for entry_variant: Variant in ray_entries:
		var entry := entry_variant as Dictionary
		if String(entry.get("finger_id", "")) == finger_name and bool(entry.get("hit", false)):
			count += 1
	return count


func _count_finger_rays(ray_entries: Array, finger_name: String) -> int:
	var count := 0
	for entry_variant: Variant in ray_entries:
		var entry := entry_variant as Dictionary
		if String(entry.get("finger_id", "")) == finger_name:
			count += 1
	return count


func _max_nearest_vector2_distance(
	actual: PackedVector2Array,
	expected: PackedVector2Array
) -> float:
	if actual.is_empty() or expected.is_empty():
		return INF
	var max_distance := 0.0
	for expected_point: Vector2 in expected:
		var nearest := INF
		for actual_point: Vector2 in actual:
			nearest = minf(nearest, expected_point.distance_to(actual_point))
		max_distance = maxf(max_distance, nearest)
	return max_distance


func _unordered_vector3_sets_match(
	actual: PackedVector3Array,
	expected: PackedVector3Array,
	tolerance: float
) -> bool:
	if actual.size() != expected.size():
		return false
	var used: Dictionary = {}
	for expected_point: Vector3 in expected:
		var match_index := -1
		for actual_index in range(actual.size()):
			if used.has(actual_index):
				continue
			if actual[actual_index].distance_to(expected_point) <= tolerance:
				match_index = actual_index
				break
		if match_index < 0:
			return false
		used[match_index] = true
	return true


func _unordered_vector2_sets_match(
	actual: PackedVector2Array,
	expected: PackedVector2Array,
	tolerance: float
) -> bool:
	if actual.size() != expected.size():
		return false
	var used: Dictionary = {}
	for expected_point: Vector2 in expected:
		var match_index := -1
		for actual_index in range(actual.size()):
			if used.has(actual_index):
				continue
			if actual[actual_index].distance_to(expected_point) <= tolerance:
				match_index = actual_index
				break
		if match_index < 0:
			return false
		used[match_index] = true
	return true


func _vector2_set_has_point(
	points: PackedVector2Array,
	target: Vector2,
	tolerance: float
) -> bool:
	for point: Vector2 in points:
		if point.distance_to(target) <= tolerance:
			return true
	return false


func _basis_delta_degrees(first: Basis, second: Basis) -> float:
	return maxf(
		_axis_delta_degrees(first.x, second.x),
		maxf(
			_axis_delta_degrees(first.y, second.y),
			_axis_delta_degrees(first.z, second.z)
		)
	)


func _axis_delta_degrees(first: Vector3, second: Vector3) -> float:
	if first.length_squared() <= 0.000001 or second.length_squared() <= 0.000001:
		return INF
	return rad_to_deg(acos(clampf(
		first.normalized().dot(second.normalized()),
		-1.0,
		1.0
	)))


func _quaternion_delta_degrees(first: Quaternion, second: Quaternion) -> float:
	var dot_value := clampf(absf(first.normalized().dot(second.normalized())), 0.0, 1.0)
	return rad_to_deg(2.0 * acos(dot_value))


func _max_row_width(rows: Array[String]) -> int:
	var width := 0
	for row: String in rows:
		width = maxi(width, row.length())
	return width


func _build_handle_points() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-HANDLE_HALF_LENGTH_METERS, 0.0, 0.0),
		Vector3.ZERO,
		Vector3(HANDLE_HALF_LENGTH_METERS, 0.0, 0.0),
	])


func _append_snapshot_summary(prefix: String, snapshot: Dictionary) -> void:
	result_lines.append("%s_snapshot_valid=%s" % [prefix, str(bool(snapshot.get("valid", false)))])
	result_lines.append("%s_open_ok=%s" % [prefix, str(bool(snapshot.get("open_ok", false)))])
	result_lines.append("%s_slot_ok=%s" % [prefix, str(bool(snapshot.get("slot_ok", false)))])
	result_lines.append("%s_authored_pose_ok=%s" % [
		prefix,
		str(bool(snapshot.get("authored_pose_ok", false))),
	])
	result_lines.append("%s_snapshot_error=%s" % [prefix, String(snapshot.get("error", ""))])
	result_lines.append("%s_proxy_cell_count=%d" % [
		prefix,
		(snapshot.get("proxy_centers", PackedVector3Array()) as PackedVector3Array).size(),
	])
	result_lines.append("%s_mesh_aabb_grip_local=%s" % [
		prefix,
		str(snapshot.get("mesh_aabb_grip_local", AABB())),
	])
	result_lines.append("%s_max_finger_joint_proxy_penetration_meters=%s" % [
		prefix,
		str(float(snapshot.get("max_finger_joint_proxy_penetration_meters", 0.0))),
	])
	result_lines.append("%s_finger_contact_readiness=%s" % [
		prefix,
		str(float(snapshot.get("finger_contact_readiness", -1.0))),
	])
	result_lines.append("%s_finger_contact_distance_meters=%s" % [
		prefix,
		str(float(snapshot.get("finger_contact_distance_meters", -1.0))),
	])
	var ray_counts: Dictionary = snapshot.get("finger_ray_counts", {}) as Dictionary
	var hit_counts: Dictionary = snapshot.get("finger_ray_hit_counts", {}) as Dictionary
	var target_positions: Dictionary = snapshot.get(
		"finger_target_positions_grip_local",
		{}
	) as Dictionary
	var tip_target_distances: Dictionary = snapshot.get(
		"finger_tip_to_target_distances_meters",
		{}
	) as Dictionary
	for finger_id: String in FINGER_IDS:
		result_lines.append("%s_%s_ray_count=%d" % [
			prefix,
			finger_id,
			int(ray_counts.get(finger_id, 0)),
		])
		result_lines.append("%s_%s_ray_hit_count=%d" % [
			prefix,
			finger_id,
			int(hit_counts.get(finger_id, 0)),
		])
		result_lines.append("%s_%s_target_grip_local=%s" % [
			prefix,
			finger_id,
			str(target_positions.get(finger_id, Vector3.INF)),
		])
		result_lines.append("%s_%s_tip_to_target_meters=%s" % [
			prefix,
			finger_id,
			str(float(tip_target_distances.get(finger_id, INF))),
		])


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
	_write_results()
	_cleanup_temp_library()
	if failures.is_empty():
		print("Forge V2 Skill Crafter grip parity verifier passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _write_results() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(result_lines) + "\n")
		file.close()


func _cleanup_temp_library() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEMP_LIBRARY_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _wait_process_frames(frame_count: int) -> void:
	for _frame_index in range(maxi(frame_count, 0)):
		await process_frame


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index in range(maxi(frame_count, 0)):
		await physics_frame
