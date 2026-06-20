extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/unarmed_mesh_bone_alignment_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_unarmed_mesh_bone_alignment_library.tres"
const RIGHT_HAND_BONE := "CC_Base_R_Hand"
const RIGHT_INDEX1_BONE := "CC_Base_R_Index1"
const RIGHT_INDEX3_BONE := "CC_Base_R_Index3"
const RIGHT_PINKY1_BONE := "CC_Base_R_Pinky1"
const RIGHT_PINKY3_BONE := "CC_Base_R_Pinky3"
const RIGHT_THUMB1_BONE := "CC_Base_R_Thumb1"
const TARGET_BONES := [
	RIGHT_HAND_BONE,
	RIGHT_INDEX1_BONE,
	RIGHT_INDEX3_BONE,
	RIGHT_PINKY1_BONE,
	RIGHT_PINKY3_BONE,
	RIGHT_THUMB1_BONE,
]

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run_diagnosis")

func _run_diagnosis() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_SAVE_FILE_PATH
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Unarmed Mesh Bone Alignment")
	await _wait_frames(6)
	var open_ok: bool = ui.select_unarmed_authoring(true)
	await _wait_frames(6)
	var skill_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await _wait_frames(4)
	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(10)
	var select_ok: bool = ui.select_motion_node(1)
	await _wait_frames(4)

	var diagnosis: Dictionary = _capture_alignment(ui)
	var lines: PackedStringArray = []
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("skill_slot_1_ok=%s" % str(skill_ok))
	lines.append("reset_ok=%s" % str(reset_ok))
	lines.append("select_editable_ok=%s" % str(select_ok))
	lines.append("capture_complete=%s" % str(bool(diagnosis.get("capture_complete", false))))
	lines.append("mesh_loaded=%s" % str(bool(diagnosis.get("mesh_loaded", false))))
	lines.append("skin_loaded=%s" % str(bool(diagnosis.get("skin_loaded", false))))
	lines.append("mesh_skeleton_path=%s" % String(diagnosis.get("mesh_skeleton_path", NodePath())))
	lines.append("skin_bind_count=%d" % int(diagnosis.get("skin_bind_count", -1)))
	lines.append("skeleton_bone_count=%d" % int(diagnosis.get("skeleton_bone_count", -1)))
	lines.append("proxy_segment_axis=%s" % str(diagnosis.get("proxy_segment_axis", Vector3.ZERO) as Vector3))
	lines.append("bone_index_pinky_axis=%s" % str(diagnosis.get("bone_index_pinky_axis", Vector3.ZERO) as Vector3))
	lines.append("proxy_axis_dot_bone_axis=%.6f" % float(diagnosis.get("proxy_axis_dot_bone_axis", 0.0)))
	lines.append("proxy_line_distance_to_index1_m=%.6f" % float(diagnosis.get("proxy_line_distance_to_index1_m", -1.0)))
	lines.append("proxy_line_distance_to_pinky1_m=%.6f" % float(diagnosis.get("proxy_line_distance_to_pinky1_m", -1.0)))
	lines.append("proxy_contact_to_index_pinky_mid_m=%.6f" % float(diagnosis.get("proxy_contact_to_index_pinky_mid_m", -1.0)))
	lines.append("proxy_contact_to_hand_bone_m=%.6f" % float(diagnosis.get("proxy_contact_to_hand_bone_m", -1.0)))
	lines.append("proxy_contact_to_hand_anchor_m=%.6f" % float(diagnosis.get("proxy_contact_to_hand_anchor_m", -1.0)))
	lines.append("hand_anchor_to_hand_bone_m=%.6f" % float(diagnosis.get("hand_anchor_to_hand_bone_m", -1.0)))
	lines.append("primary_anchor_world=%s" % str(diagnosis.get("primary_anchor_world", Vector3.ZERO) as Vector3))
	lines.append("hand_grip_target_world=%s" % str(diagnosis.get("hand_grip_target_world", Vector3.ZERO) as Vector3))
	lines.append("hand_bone_world=%s" % str(diagnosis.get("hand_bone_world", Vector3.ZERO) as Vector3))
	lines.append("right_hand_ik_target_world=%s" % str(diagnosis.get("right_hand_ik_target_world", Vector3.ZERO) as Vector3))
	lines.append("primary_anchor_to_hand_grip_target_m=%.6f" % float(diagnosis.get("primary_anchor_to_hand_grip_target_m", -1.0)))
	lines.append("hand_bone_to_ik_target_m=%.6f" % float(diagnosis.get("hand_bone_to_ik_target_m", -1.0)))
	lines.append("manual_ccd_supported=%s" % str(bool(diagnosis.get("manual_ccd_supported", false))))
	lines.append("manual_ccd_before_m=%.6f" % float(diagnosis.get("manual_ccd_before_m", -1.0)))
	lines.append("manual_ccd_after_m=%.6f" % float(diagnosis.get("manual_ccd_after_m", -1.0)))
	lines.append("weighted_target_bone_count=%d" % int(diagnosis.get("weighted_target_bone_count", 0)))
	var bone_results: Dictionary = diagnosis.get("bone_results", {}) as Dictionary
	for bone_name: String in TARGET_BONES:
		var bone_result: Dictionary = bone_results.get(bone_name, {}) as Dictionary
		lines.append("%s_exists=%s" % [bone_name, str(bool(bone_result.get("exists", false)))])
		lines.append("%s_bind_exists=%s" % [bone_name, str(bool(bone_result.get("bind_exists", false)))])
		lines.append("%s_weighted_vertex_count=%d" % [bone_name, int(bone_result.get("weighted_vertex_count", 0))])
		lines.append("%s_rest_centroid_to_bone_m=%.6f" % [bone_name, float(bone_result.get("rest_centroid_to_bone_m", -1.0))])
		lines.append("%s_deformed_a_centroid_to_bone_m=%.6f" % [bone_name, float(bone_result.get("deformed_a_centroid_to_bone_m", -1.0))])
		lines.append("%s_deformed_b_centroid_to_bone_m=%.6f" % [bone_name, float(bone_result.get("deformed_b_centroid_to_bone_m", -1.0))])
		lines.append("%s_bone_world=%s" % [bone_name, str(bone_result.get("bone_world", Vector3.ZERO) as Vector3)])
		lines.append("%s_rest_centroid_world=%s" % [bone_name, str(bone_result.get("rest_centroid_world", Vector3.ZERO) as Vector3)])
		lines.append("%s_deformed_a_centroid_world=%s" % [bone_name, str(bone_result.get("deformed_a_centroid_world", Vector3.ZERO) as Vector3)])
		lines.append("%s_deformed_b_centroid_world=%s" % [bone_name, str(bone_result.get("deformed_b_centroid_world", Vector3.ZERO) as Vector3)])
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _capture_alignment(ui: CombatAnimationStationUI) -> Dictionary:
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D if ui.preview_subviewport != null else null
	var actor: Node3D = preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null
	var held_item: Node3D = preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	var mesh_instance: MeshInstance3D = skeleton.get_node_or_null("Mesh") as MeshInstance3D if skeleton != null else null
	var skin: Skin = mesh_instance.skin if mesh_instance != null else null
	var mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh if mesh_instance != null else null
	if actor == null or held_item == null or skeleton == null:
		return {"capture_complete": false}
	var hand_index: int = skeleton.find_bone(RIGHT_HAND_BONE)
	var index_index: int = skeleton.find_bone(RIGHT_INDEX1_BONE)
	var pinky_index: int = skeleton.find_bone(RIGHT_PINKY1_BONE)
	if hand_index < 0 or index_index < 0 or pinky_index < 0:
		return {"capture_complete": false}
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var local_pommel: Vector3 = held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
	var local_contact: Vector3 = held_item.get_meta("primary_grip_contact_local", Vector3.ZERO) as Vector3
	var tip_world: Vector3 = held_item.global_transform * local_tip
	var pommel_world: Vector3 = held_item.global_transform * local_pommel
	var contact_world: Vector3 = held_item.global_transform * local_contact
	var segment_axis: Vector3 = (tip_world - pommel_world).normalized()
	var hand_world: Vector3 = _get_bone_world_position(skeleton, RIGHT_HAND_BONE)
	var index_world: Vector3 = _get_bone_world_position(skeleton, RIGHT_INDEX1_BONE)
	var pinky_world: Vector3 = _get_bone_world_position(skeleton, RIGHT_PINKY1_BONE)
	var index_pinky_axis: Vector3 = (index_world - pinky_world).normalized()
	var midpoint_world: Vector3 = index_world.lerp(pinky_world, 0.5)
	var hand_anchor: Node3D = actor.call("get_right_hand_item_anchor") as Node3D if actor.has_method("get_right_hand_item_anchor") else null
	var primary_anchor: Node3D = held_item.get_node_or_null("PrimaryGripAnchor") as Node3D
	var hand_grip_target_world: Vector3 = actor.call("resolve_hand_grip_alignment_world_position", &"hand_right") as Vector3 if actor.has_method("resolve_hand_grip_alignment_world_position") else Vector3.ZERO
	var right_hand_ik_target: Node3D = actor.get_node_or_null("IkTargets/RightHandIkTarget") as Node3D
	var manual_ccd_before: float = hand_world.distance_to(right_hand_ik_target.global_position) if right_hand_ik_target != null else -1.0
	var manual_ccd_after: float = -1.0
	var manual_ccd_supported: bool = false
	if right_hand_ik_target != null and actor.has_method("_apply_ccd_arm_reach_pose"):
		manual_ccd_supported = true
		actor.call(
			"_apply_ccd_arm_reach_pose",
			&"CC_Base_R_Upperarm",
			&"CC_Base_R_Forearm",
			&"CC_Base_R_Hand",
			right_hand_ik_target.global_position,
			48,
			1.0,
			1.0
		)
		if skeleton.has_method("force_update_all_bone_transforms"):
			skeleton.force_update_all_bone_transforms()
		manual_ccd_after = _get_bone_world_position(skeleton, RIGHT_HAND_BONE).distance_to(right_hand_ik_target.global_position)
	var bone_results: Dictionary = _capture_weighted_bone_centroids(skeleton, mesh_instance, skin, mesh)
	var weighted_target_bone_count: int = 0
	for bone_name: String in TARGET_BONES:
		var bone_result: Dictionary = bone_results.get(bone_name, {}) as Dictionary
		if int(bone_result.get("weighted_vertex_count", 0)) > 0:
			weighted_target_bone_count += 1
	return {
		"capture_complete": true,
		"mesh_loaded": mesh != null,
		"skin_loaded": skin != null,
		"mesh_skeleton_path": mesh_instance.skeleton if mesh_instance != null else NodePath(),
		"skin_bind_count": skin.get_bind_count() if skin != null else -1,
		"skeleton_bone_count": skeleton.get_bone_count(),
		"proxy_segment_axis": segment_axis,
		"bone_index_pinky_axis": index_pinky_axis,
		"proxy_axis_dot_bone_axis": segment_axis.dot(index_pinky_axis),
		"proxy_line_distance_to_index1_m": _distance_point_to_line(index_world, contact_world, segment_axis),
		"proxy_line_distance_to_pinky1_m": _distance_point_to_line(pinky_world, contact_world, segment_axis),
		"proxy_contact_to_index_pinky_mid_m": contact_world.distance_to(midpoint_world),
		"proxy_contact_to_hand_bone_m": contact_world.distance_to(hand_world),
		"proxy_contact_to_hand_anchor_m": contact_world.distance_to(hand_anchor.global_position) if hand_anchor != null else -1.0,
		"hand_anchor_to_hand_bone_m": hand_anchor.global_position.distance_to(hand_world) if hand_anchor != null else -1.0,
		"primary_anchor_world": primary_anchor.global_position if primary_anchor != null else Vector3.ZERO,
		"hand_grip_target_world": hand_grip_target_world,
		"hand_bone_world": hand_world,
		"right_hand_ik_target_world": right_hand_ik_target.global_position if right_hand_ik_target != null else Vector3.ZERO,
		"primary_anchor_to_hand_grip_target_m": primary_anchor.global_position.distance_to(hand_grip_target_world) if primary_anchor != null and hand_grip_target_world.length_squared() > 0.000001 else -1.0,
		"hand_bone_to_ik_target_m": hand_world.distance_to(right_hand_ik_target.global_position) if right_hand_ik_target != null else -1.0,
		"manual_ccd_supported": manual_ccd_supported,
		"manual_ccd_before_m": manual_ccd_before,
		"manual_ccd_after_m": manual_ccd_after,
		"weighted_target_bone_count": weighted_target_bone_count,
		"bone_results": bone_results,
	}

func _capture_weighted_bone_centroids(
	skeleton: Skeleton3D,
	mesh_instance: MeshInstance3D,
	skin: Skin,
	mesh: ArrayMesh
) -> Dictionary:
	var results: Dictionary = {}
	for bone_name: String in TARGET_BONES:
		var bone_index: int = skeleton.find_bone(bone_name) if skeleton != null else -1
		results[bone_name] = {
			"exists": bone_index >= 0,
			"bind_exists": false,
			"weighted_vertex_count": 0,
			"bone_world": _get_bone_world_position(skeleton, bone_name),
		}
	if skeleton == null or mesh_instance == null or skin == null or mesh == null:
		return results
	var bind_names: Dictionary = {}
	var skeleton_index_by_bind: Dictionary = {}
	for bind_index: int in range(skin.get_bind_count()):
		var bind_name: String = String(skin.get_bind_name(bind_index))
		var skeleton_bone_index: int = skin.get_bind_bone(bind_index)
		if bind_name.is_empty() and skeleton_bone_index >= 0 and skeleton_bone_index < skeleton.get_bone_count():
			bind_name = skeleton.get_bone_name(skeleton_bone_index)
		if skeleton_bone_index < 0 and not bind_name.is_empty():
			skeleton_bone_index = skeleton.find_bone(bind_name)
		bind_names[bind_index] = bind_name
		skeleton_index_by_bind[bind_index] = skeleton_bone_index
		if results.has(bind_name):
			var bind_result: Dictionary = results.get(bind_name, {}) as Dictionary
			bind_result["bind_exists"] = true
			results[bind_name] = bind_result
	var mesh_to_world: Transform3D = mesh_instance.global_transform
	var world_to_mesh: Transform3D = mesh_to_world.affine_inverse()
	var skeleton_to_mesh: Transform3D = world_to_mesh * skeleton.global_transform
	var sums: Dictionary = {}
	for bone_name: String in TARGET_BONES:
		sums[bone_name] = {
			"rest": Vector3.ZERO,
			"deformed_a": Vector3.ZERO,
			"deformed_b": Vector3.ZERO,
			"count": 0,
		}
	for surface_index: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_WEIGHTS:
			continue
		var vertices_variant: Variant = arrays[Mesh.ARRAY_VERTEX]
		var bones_variant: Variant = arrays[Mesh.ARRAY_BONES]
		var weights_variant: Variant = arrays[Mesh.ARRAY_WEIGHTS]
		var vertex_count: int = _packed_array_size(vertices_variant)
		var weight_count: int = _packed_array_size(weights_variant)
		var influence_count: int = int(weight_count / vertex_count) if vertex_count > 0 else 0
		if vertex_count <= 0 or influence_count <= 0:
			continue
		for vertex_index: int in range(vertex_count):
			var vertex: Vector3 = _read_packed_vector3(vertices_variant, vertex_index)
			var influences: Array[Dictionary] = []
			var touched_target_bones: Dictionary = {}
			for influence_slot: int in range(influence_count):
				var packed_index: int = vertex_index * influence_count + influence_slot
				var weight: float = _read_packed_numeric(weights_variant, packed_index)
				if weight <= 0.0001:
					continue
				var bind_index: int = int(_read_packed_numeric(bones_variant, packed_index))
				var bind_name: String = String(bind_names.get(bind_index, ""))
				var skeleton_bone_index: int = int(skeleton_index_by_bind.get(bind_index, -1))
				influences.append({
					"bind_index": bind_index,
					"bone_index": skeleton_bone_index,
					"weight": weight,
				})
				if results.has(bind_name):
					touched_target_bones[bind_name] = true
			if touched_target_bones.is_empty():
				continue
			var deformed_a_local: Vector3 = _deform_vertex_candidate(vertex, influences, skeleton, skin, skeleton_to_mesh, true)
			var deformed_b_local: Vector3 = _deform_vertex_candidate(vertex, influences, skeleton, skin, skeleton_to_mesh, false)
			for bone_name: String in touched_target_bones.keys():
				var sum_data: Dictionary = sums.get(bone_name, {}) as Dictionary
				sum_data["rest"] = (sum_data.get("rest", Vector3.ZERO) as Vector3) + vertex
				sum_data["deformed_a"] = (sum_data.get("deformed_a", Vector3.ZERO) as Vector3) + deformed_a_local
				sum_data["deformed_b"] = (sum_data.get("deformed_b", Vector3.ZERO) as Vector3) + deformed_b_local
				sum_data["count"] = int(sum_data.get("count", 0)) + 1
				sums[bone_name] = sum_data
	for bone_name: String in TARGET_BONES:
		var result: Dictionary = results.get(bone_name, {}) as Dictionary
		var sum_data: Dictionary = sums.get(bone_name, {}) as Dictionary
		var count: int = int(sum_data.get("count", 0))
		result["weighted_vertex_count"] = count
		if count > 0:
			var rest_centroid_world: Vector3 = mesh_to_world * ((sum_data.get("rest", Vector3.ZERO) as Vector3) / float(count))
			var deformed_a_world: Vector3 = mesh_to_world * ((sum_data.get("deformed_a", Vector3.ZERO) as Vector3) / float(count))
			var deformed_b_world: Vector3 = mesh_to_world * ((sum_data.get("deformed_b", Vector3.ZERO) as Vector3) / float(count))
			var bone_world: Vector3 = result.get("bone_world", Vector3.ZERO) as Vector3
			result["rest_centroid_world"] = rest_centroid_world
			result["deformed_a_centroid_world"] = deformed_a_world
			result["deformed_b_centroid_world"] = deformed_b_world
			result["rest_centroid_to_bone_m"] = rest_centroid_world.distance_to(bone_world)
			result["deformed_a_centroid_to_bone_m"] = deformed_a_world.distance_to(bone_world)
			result["deformed_b_centroid_to_bone_m"] = deformed_b_world.distance_to(bone_world)
		results[bone_name] = result
	return results

func _deform_vertex_candidate(
	vertex: Vector3,
	influences: Array[Dictionary],
	skeleton: Skeleton3D,
	skin: Skin,
	skeleton_to_mesh: Transform3D,
	use_inverse_bind: bool
) -> Vector3:
	var resolved := Vector3.ZERO
	var weight_sum: float = 0.0
	for influence: Dictionary in influences:
		var bind_index: int = int(influence.get("bind_index", -1))
		var bone_index: int = int(influence.get("bone_index", -1))
		var weight: float = float(influence.get("weight", 0.0))
		if bind_index < 0 or bone_index < 0 or weight <= 0.0001:
			continue
		var bind_pose: Transform3D = skin.get_bind_pose(bind_index)
		var bone_pose_mesh: Transform3D = skeleton_to_mesh * skeleton.get_bone_global_pose(bone_index)
		var deformed: Vector3 = bone_pose_mesh * (bind_pose.affine_inverse() * vertex) if use_inverse_bind else bone_pose_mesh * (bind_pose * vertex)
		resolved += deformed * weight
		weight_sum += weight
	if weight_sum <= 0.0001:
		return vertex
	return resolved / weight_sum

func _get_bone_world_position(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _distance_point_to_line(point: Vector3, line_origin: Vector3, line_axis: Vector3) -> float:
	var axis: Vector3 = line_axis.normalized()
	if axis.length_squared() <= 0.000001:
		return -1.0
	var offset: Vector3 = point - line_origin
	var projected: Vector3 = line_origin + axis * offset.dot(axis)
	return point.distance_to(projected)

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

func _wait_frames(frame_count: int) -> void:
	for _frame_index in range(maxi(frame_count, 0)):
		await process_frame
