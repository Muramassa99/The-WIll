extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const TARGET_PROJECT_NAME := "Test sword for animations"
const RESULT_FILE_PATH := "C:/WORKSPACE/skill_slot_1_reset_arm_mesh_sections_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_skill_slot_1_reset_arm_mesh_sections_library.tres"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const DOMINANT_SLOT_ID: StringName = &"hand_right"
const PHASE_COUNT := 3
const OBSERVE_SECONDS_PER_PHASE := 3.0
const MESH_CAPTURE_STEP_SECONDS := 1.0

const ARM_MESH_GROUPS := {
	"right_upperarm": {
		"bones": [
			"CC_Base_R_Upperarm",
			"CC_Base_R_UpperarmTwist01",
			"CC_Base_R_UpperarmTwist02",
		],
		"segment_start": "CC_Base_R_Upperarm",
		"segment_end": "CC_Base_R_Forearm",
	},
	"right_forearm": {
		"bones": [
			"CC_Base_R_Forearm",
			"CC_Base_R_ForearmTwist01",
			"CC_Base_R_ForearmTwist02",
		],
		"segment_start": "CC_Base_R_Forearm",
		"segment_end": "CC_Base_R_Hand",
	},
	"left_upperarm": {
		"bones": [
			"CC_Base_L_Upperarm",
			"CC_Base_L_UpperarmTwist01",
			"CC_Base_L_UpperarmTwist02",
		],
		"segment_start": "CC_Base_L_Upperarm",
		"segment_end": "CC_Base_L_Forearm",
	},
	"left_forearm": {
		"bones": [
			"CC_Base_L_Forearm",
			"CC_Base_L_ForearmTwist01",
			"CC_Base_L_ForearmTwist02",
		],
		"segment_start": "CC_Base_L_Forearm",
		"segment_end": "CC_Base_L_Hand",
	},
}

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

var lines: PackedStringArray = []
var capture_count: int = 0

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	lines.append("target_slot=skill_slot_1")
	lines.append("phase_count=%d" % PHASE_COUNT)
	lines.append("observe_seconds_per_phase=%.4f" % OBSERVE_SECONDS_PER_PHASE)
	lines.append("mesh_capture_step_seconds=%.4f" % MESH_CAPTURE_STEP_SECONDS)
	lines.append("mesh_capture_method=MeshInstance3D.bake_mesh_from_current_skeleton_pose")

	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	lines.append("source_library_loaded=%s" % str(source_library != null))
	lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_results()
		quit()
		return

	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = TEMP_SAVE_FILE_PATH
	temp_library.saved_wips.clear()
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	diagnostic_wip.wip_id = StringName("%s_reset_arm_mesh_sections" % String(source_wip.wip_id))
	diagnostic_wip.forge_project_name = "%s Reset Arm Mesh Sections Diagnostic" % source_wip.forge_project_name
	diagnostic_wip.ensure_combat_animation_station_state()
	temp_library.saved_wips.append(diagnostic_wip)
	temp_library.selected_wip_id = diagnostic_wip.wip_id
	temp_library.persist()

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = temp_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Skill Slot 1 Reset Arm Mesh Sections Diagnostic")
	await _wait_frames(8)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(diagnostic_wip.wip_id, DOMINANT_SLOT_ID, false, false)
	await _wait_frames(8)
	var select_slot_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	await _wait_frames(8)
	_select_first_visible_skill_node(ui)
	await _wait_frames(4)

	lines.append("diagnostic_save_path=%s" % TEMP_SAVE_FILE_PATH)
	lines.append("source_wip_id=%s" % String(source_wip.wip_id))
	lines.append("diagnostic_wip_id=%s" % String(diagnostic_wip.wip_id))
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_skill_slot_1_ok=%s" % str(select_slot_ok))
	lines.append("active_draft_identifier=%s" % String(ui.get_active_draft_identifier()))
	lines.append("active_open_slot=%s" % String(ui.get_active_open_dominant_slot_id()))
	lines.append("active_open_two_hand=%s" % str(ui.is_active_open_two_hand()))
	_append_capture(ui, "initial")

	for phase_index: int in range(PHASE_COUNT):
		var reset_ok: bool = ui.reset_active_draft_to_baseline()
		await _wait_frames(4)
		_select_first_visible_skill_node(ui)
		await _wait_frames(4)
		lines.append("")
		lines.append("[phase_%d]" % (phase_index + 1))
		lines.append("phase_%d_reset_ok=%s" % [phase_index + 1, str(reset_ok)])
		_append_capture(ui, "phase_%d_t0" % (phase_index + 1))
		var elapsed := 0.0
		while elapsed < OBSERVE_SECONDS_PER_PHASE:
			await create_timer(MESH_CAPTURE_STEP_SECONDS).timeout
			elapsed += MESH_CAPTURE_STEP_SECONDS
			_append_capture(ui, "phase_%d_t%.0f" % [phase_index + 1, elapsed])

	lines.append("")
	lines.append("capture_count=%d" % capture_count)
	_write_results()
	quit()

func _select_first_visible_skill_node(ui: CombatAnimationStationUI) -> void:
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	if draft == null:
		return
	if draft.motion_node_chain.size() <= 0:
		return
	ui.select_motion_node(1 if draft.motion_node_chain.size() > 1 else 0)

func _append_capture(ui: CombatAnimationStationUI, prefix: String) -> void:
	capture_count += 1
	var actor: Node3D = _get_preview_actor(ui)
	var held_item: Node3D = _get_preview_held_item(ui)
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	var mesh_instance: MeshInstance3D = skeleton.get_node_or_null("Mesh") as MeshInstance3D if skeleton != null else null
	var mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh if mesh_instance != null else null
	var skin: Skin = mesh_instance.skin if mesh_instance != null else null
	var baked_mesh: ArrayMesh = mesh_instance.bake_mesh_from_current_skeleton_pose() if mesh_instance != null and mesh_instance.has_method("bake_mesh_from_current_skeleton_pose") else null
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	lines.append("")
	lines.append("[%s]" % prefix)
	lines.append("%s_capture_index=%d" % [prefix, capture_count])
	lines.append("%s_actor_exists=%s" % [prefix, str(actor != null)])
	lines.append("%s_skeleton_exists=%s" % [prefix, str(skeleton != null)])
	lines.append("%s_mesh_instance_exists=%s" % [prefix, str(mesh_instance != null)])
	lines.append("%s_mesh_exists=%s" % [prefix, str(mesh != null)])
	lines.append("%s_skin_exists=%s" % [prefix, str(skin != null)])
	lines.append("%s_baked_mesh_exists=%s" % [prefix, str(baked_mesh != null)])
	lines.append("%s_mesh_skeleton_path=%s" % [prefix, String(mesh_instance.skeleton if mesh_instance != null else NodePath())])
	lines.append("%s_skin_bind_count=%d" % [prefix, skin.get_bind_count() if skin != null else -1])
	lines.append("%s_skeleton_bone_count=%d" % [prefix, skeleton.get_bone_count() if skeleton != null else -1])
	lines.append("%s_mesh_surface_count=%d" % [prefix, mesh.get_surface_count() if mesh != null else -1])
	lines.append("%s_baked_surface_count=%d" % [prefix, baked_mesh.get_surface_count() if baked_mesh != null else -1])
	if motion_node != null:
		lines.append("%s_node_tip_local=%s" % [prefix, str(motion_node.tip_position_local)])
		lines.append("%s_node_pommel_local=%s" % [prefix, str(motion_node.pommel_position_local)])
		lines.append("%s_node_grip=%s" % [prefix, String(motion_node.preferred_grip_style_mode)])
	lines.append("%s_weapon_world=%s" % [prefix, str(held_item.global_position if held_item != null else Vector3.ZERO)])
	lines.append("%s_dominant_grip_error_m=%.6f" % [prefix, float(debug_state.get("dominant_grip_alignment_error_meters", -1.0))])
	lines.append("%s_collision_pose_legal=%s" % [prefix, str(bool(debug_state.get("collision_pose_legal", true)))])
	lines.append("%s_collision_pose_region=%s" % [prefix, String(debug_state.get("collision_pose_region", ""))])
	lines.append("%s_collision_pose_clearance_m=%.6f" % [prefix, float(debug_state.get("collision_pose_clearance_meters", -1.0))])
	lines.append("%s_body_self_legal=%s" % [prefix, str(bool(debug_state.get("body_self_collision_legal", true)))])
	lines.append("%s_body_self_illegal_count=%d" % [prefix, int(debug_state.get("body_self_collision_illegal_pair_count", 0))])
	lines.append("%s_body_self_first_illegal_pair=%s" % [prefix, str(debug_state.get("body_self_collision_first_illegal_pair", {}))])
	lines.append("%s_joint_range_debug=%s" % [prefix, str(debug_state.get("joint_range_debug_state", {}))])
	lines.append_array(_capture_bone_lines(skeleton, prefix))
	lines.append_array(_capture_baked_mesh_group_lines(skeleton, mesh_instance, mesh, skin, baked_mesh, prefix))

func _capture_bone_lines(skeleton: Skeleton3D, prefix: String) -> PackedStringArray:
	var result: PackedStringArray = []
	if skeleton == null:
		return result
	for group_name: String in ARM_MESH_GROUPS.keys():
		var group: Dictionary = ARM_MESH_GROUPS.get(group_name, {}) as Dictionary
		var start_name: String = String(group.get("segment_start", ""))
		var end_name: String = String(group.get("segment_end", ""))
		var start_world: Vector3 = _get_bone_world_position(skeleton, start_name)
		var end_world: Vector3 = _get_bone_world_position(skeleton, end_name)
		result.append("%s_%s_segment_start=%s" % [prefix, group_name, str(start_world)])
		result.append("%s_%s_segment_end=%s" % [prefix, group_name, str(end_world)])
		result.append("%s_%s_segment_length_m=%.6f" % [prefix, group_name, start_world.distance_to(end_world)])
	var right_elbow: float = _joint_angle_degrees(skeleton, "CC_Base_R_Upperarm", "CC_Base_R_Forearm", "CC_Base_R_Hand")
	var left_elbow: float = _joint_angle_degrees(skeleton, "CC_Base_L_Upperarm", "CC_Base_L_Forearm", "CC_Base_L_Hand")
	result.append("%s_right_elbow_direct_angle_deg=%.6f" % [prefix, right_elbow])
	result.append("%s_left_elbow_direct_angle_deg=%.6f" % [prefix, left_elbow])
	return result

func _capture_baked_mesh_group_lines(
	skeleton: Skeleton3D,
	mesh_instance: MeshInstance3D,
	mesh: ArrayMesh,
	skin: Skin,
	baked_mesh: ArrayMesh,
	prefix: String
) -> PackedStringArray:
	var result: PackedStringArray = []
	var group_stats: Dictionary = {}
	for group_name: String in ARM_MESH_GROUPS.keys():
		group_stats[group_name] = _new_group_stat()
	if skeleton == null or mesh_instance == null or mesh == null or skin == null or baked_mesh == null:
		for group_name: String in ARM_MESH_GROUPS.keys():
			result.append("%s_%s_mesh_capture_available=false" % [prefix, group_name])
		return result
	var bind_to_bone_name: Dictionary = _build_bind_to_bone_name_lookup(skeleton, skin)
	var mesh_to_world: Transform3D = mesh_instance.global_transform
	var surface_count: int = mini(mesh.get_surface_count(), baked_mesh.get_surface_count())
	for surface_index: int in range(surface_count):
		var original_arrays: Array = mesh.surface_get_arrays(surface_index)
		var baked_arrays: Array = baked_mesh.surface_get_arrays(surface_index)
		if original_arrays.size() <= Mesh.ARRAY_WEIGHTS or baked_arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var baked_vertices_variant: Variant = baked_arrays[Mesh.ARRAY_VERTEX]
		var bones_variant: Variant = original_arrays[Mesh.ARRAY_BONES]
		var weights_variant: Variant = original_arrays[Mesh.ARRAY_WEIGHTS]
		var vertex_count: int = _packed_array_size(baked_vertices_variant)
		var weight_count: int = _packed_array_size(weights_variant)
		var influence_count: int = int(weight_count / vertex_count) if vertex_count > 0 else 0
		if vertex_count <= 0 or influence_count <= 0:
			continue
		for vertex_index: int in range(vertex_count):
			var vertex_world: Vector3 = mesh_to_world * _read_packed_vector3(baked_vertices_variant, vertex_index)
			var group_weights: Dictionary = {}
			for influence_slot: int in range(influence_count):
				var packed_index: int = vertex_index * influence_count + influence_slot
				var weight: float = _read_packed_numeric(weights_variant, packed_index)
				if weight <= 0.0001:
					continue
				var bind_index: int = int(_read_packed_numeric(bones_variant, packed_index))
				var bone_name: String = String(bind_to_bone_name.get(bind_index, ""))
				var group_name: String = _resolve_group_for_bone(bone_name)
				if group_name.is_empty():
					continue
				group_weights[group_name] = float(group_weights.get(group_name, 0.0)) + weight
			for group_name: String in group_weights.keys():
				var group_weight: float = float(group_weights.get(group_name, 0.0))
				if group_weight <= 0.0001:
					continue
				var stat: Dictionary = group_stats.get(group_name, _new_group_stat()) as Dictionary
				_accumulate_group_stat(stat, vertex_world, group_weight)
				group_stats[group_name] = stat
	for group_name: String in ARM_MESH_GROUPS.keys():
		var group: Dictionary = ARM_MESH_GROUPS.get(group_name, {}) as Dictionary
		var start_world: Vector3 = _get_bone_world_position(skeleton, String(group.get("segment_start", "")))
		var end_world: Vector3 = _get_bone_world_position(skeleton, String(group.get("segment_end", "")))
		var stat: Dictionary = group_stats.get(group_name, _new_group_stat()) as Dictionary
		result.append_array(_build_group_result_lines(prefix, group_name, stat, start_world, end_world))
	return result

func _new_group_stat() -> Dictionary:
	return {
		"weight_sum": 0.0,
		"vertex_hits": 0,
		"centroid_sum": Vector3.ZERO,
		"min": Vector3(INF, INF, INF),
		"max": Vector3(-INF, -INF, -INF),
		"points": [],
	}

func _accumulate_group_stat(stat: Dictionary, point_world: Vector3, weight: float) -> void:
	stat["weight_sum"] = float(stat.get("weight_sum", 0.0)) + weight
	stat["vertex_hits"] = int(stat.get("vertex_hits", 0)) + 1
	stat["centroid_sum"] = (stat.get("centroid_sum", Vector3.ZERO) as Vector3) + point_world * weight
	stat["min"] = _min_vec(stat.get("min", point_world) as Vector3, point_world)
	stat["max"] = _max_vec(stat.get("max", point_world) as Vector3, point_world)
	var points: Array = stat.get("points", []) as Array
	points.append({"point": point_world, "weight": weight})
	stat["points"] = points

func _build_group_result_lines(
	prefix: String,
	group_name: String,
	stat: Dictionary,
	segment_start: Vector3,
	segment_end: Vector3
) -> PackedStringArray:
	var result: PackedStringArray = []
	var weight_sum: float = float(stat.get("weight_sum", 0.0))
	var vertex_hits: int = int(stat.get("vertex_hits", 0))
	result.append("%s_%s_mesh_capture_available=%s" % [prefix, group_name, str(weight_sum > 0.0001)])
	result.append("%s_%s_weighted_vertex_hits=%d" % [prefix, group_name, vertex_hits])
	result.append("%s_%s_weight_sum=%.6f" % [prefix, group_name, weight_sum])
	if weight_sum <= 0.0001:
		return result
	var centroid: Vector3 = (stat.get("centroid_sum", Vector3.ZERO) as Vector3) / weight_sum
	var min_value: Vector3 = stat.get("min", centroid) as Vector3
	var max_value: Vector3 = stat.get("max", centroid) as Vector3
	var points: Array = stat.get("points", []) as Array
	var distance_sum := 0.0
	var distance_weight_sum := 0.0
	var max_distance := 0.0
	var min_projection := INF
	var max_projection := -INF
	var axis: Vector3 = segment_end - segment_start
	var axis_length: float = axis.length()
	var axis_dir: Vector3 = axis / axis_length if axis_length > 0.000001 else Vector3.ZERO
	for entry_variant: Variant in points:
		var entry: Dictionary = entry_variant as Dictionary
		var point_world: Vector3 = entry.get("point", Vector3.ZERO) as Vector3
		var weight: float = float(entry.get("weight", 0.0))
		var distance: float = _distance_point_to_segment(point_world, segment_start, segment_end)
		distance_sum += distance * weight
		distance_weight_sum += weight
		max_distance = maxf(max_distance, distance)
		if axis_dir.length_squared() > 0.000001:
			var projection: float = (point_world - segment_start).dot(axis_dir)
			min_projection = minf(min_projection, projection)
			max_projection = maxf(max_projection, projection)
	result.append("%s_%s_centroid_world=%s" % [prefix, group_name, str(centroid)])
	result.append("%s_%s_aabb_min_world=%s" % [prefix, group_name, str(min_value)])
	result.append("%s_%s_aabb_max_world=%s" % [prefix, group_name, str(max_value)])
	result.append("%s_%s_aabb_size_m=%s" % [prefix, group_name, str(max_value - min_value)])
	result.append("%s_%s_centroid_to_segment_m=%.6f" % [prefix, group_name, _distance_point_to_segment(centroid, segment_start, segment_end)])
	result.append("%s_%s_avg_vertex_to_segment_m=%.6f" % [prefix, group_name, distance_sum / maxf(distance_weight_sum, 0.0001)])
	result.append("%s_%s_max_vertex_to_segment_m=%.6f" % [prefix, group_name, max_distance])
	result.append("%s_%s_segment_projection_min_m=%.6f" % [prefix, group_name, min_projection if min_projection < INF else 0.0])
	result.append("%s_%s_segment_projection_max_m=%.6f" % [prefix, group_name, max_projection if max_projection > -INF else 0.0])
	result.append("%s_%s_segment_projection_span_m=%.6f" % [prefix, group_name, max_projection - min_projection if min_projection < INF and max_projection > -INF else 0.0])
	return result

func _build_bind_to_bone_name_lookup(skeleton: Skeleton3D, skin: Skin) -> Dictionary:
	var lookup: Dictionary = {}
	if skeleton == null or skin == null:
		return lookup
	for bind_index: int in range(skin.get_bind_count()):
		var bone_name: String = String(skin.get_bind_name(bind_index))
		var skeleton_bone_index: int = skin.get_bind_bone(bind_index)
		if bone_name.is_empty() and skeleton_bone_index >= 0 and skeleton_bone_index < skeleton.get_bone_count():
			bone_name = skeleton.get_bone_name(skeleton_bone_index)
		if bone_name.is_empty() and skeleton_bone_index < 0:
			continue
		lookup[bind_index] = bone_name
	return lookup

func _resolve_group_for_bone(bone_name: String) -> String:
	for group_name: String in ARM_MESH_GROUPS.keys():
		var group: Dictionary = ARM_MESH_GROUPS.get(group_name, {}) as Dictionary
		var bones: Array = group.get("bones", []) as Array
		if bones.has(bone_name):
			return group_name
	return ""

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip != null and saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _get_preview_root(ui: CombatAnimationStationUI) -> Node3D:
	if ui == null or ui.preview_subviewport == null:
		return null
	return ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D

func _get_preview_actor(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null

func _get_preview_held_item(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null

func _get_bone_world_position(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _joint_angle_degrees(skeleton: Skeleton3D, parent_bone: String, joint_bone: String, child_bone: String) -> float:
	var parent_world: Vector3 = _get_bone_world_position(skeleton, parent_bone)
	var joint_world: Vector3 = _get_bone_world_position(skeleton, joint_bone)
	var child_world: Vector3 = _get_bone_world_position(skeleton, child_bone)
	var a: Vector3 = parent_world - joint_world
	var b: Vector3 = child_world - joint_world
	if a.length_squared() <= 0.000001 or b.length_squared() <= 0.000001:
		return -1.0
	return rad_to_deg(acos(clampf(a.normalized().dot(b.normalized()), -1.0, 1.0)))

func _distance_point_to_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
	var segment: Vector3 = segment_end - segment_start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_to(segment_start)
	var t: float = clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_start + segment * t)

func _packed_array_size(packed_variant: Variant) -> int:
	if packed_variant is PackedVector3Array:
		return packed_variant.size()
	if packed_variant is PackedFloat32Array:
		return packed_variant.size()
	if packed_variant is PackedInt32Array:
		return packed_variant.size()
	if packed_variant is PackedByteArray:
		return packed_variant.size()
	return 0

func _read_packed_vector3(packed_variant: Variant, index: int) -> Vector3:
	if packed_variant is PackedVector3Array:
		return packed_variant[index]
	return Vector3.ZERO

func _read_packed_numeric(packed_variant: Variant, index: int) -> float:
	if packed_variant is PackedFloat32Array:
		return packed_variant[index]
	if packed_variant is PackedInt32Array:
		return float(packed_variant[index])
	if packed_variant is PackedByteArray:
		return float(packed_variant[index])
	return 0.0

func _min_vec(first: Vector3, second: Vector3) -> Vector3:
	return Vector3(minf(first.x, second.x), minf(first.y, second.y), minf(first.z, second.z))

func _max_vec(first: Vector3, second: Vector3) -> Vector3:
	return Vector3(maxf(first.x, second.x), maxf(first.y, second.y), maxf(first.z, second.z))

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
