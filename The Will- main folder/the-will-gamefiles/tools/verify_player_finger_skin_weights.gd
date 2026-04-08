extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_finger_skin_results.txt"
const FINGER_BONE_NAMES := [
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
	"CC_Base_R_Thumb1",
	"CC_Base_R_Thumb2",
	"CC_Base_R_Thumb3",
	"CC_Base_L_Index1",
	"CC_Base_L_Index2",
	"CC_Base_L_Index3",
	"CC_Base_L_Mid1",
	"CC_Base_L_Mid2",
	"CC_Base_L_Mid3",
	"CC_Base_L_Ring1",
	"CC_Base_L_Ring2",
	"CC_Base_L_Ring3",
	"CC_Base_L_Pinky1",
	"CC_Base_L_Pinky2",
	"CC_Base_L_Pinky3",
	"CC_Base_L_Thumb1",
	"CC_Base_L_Thumb2",
	"CC_Base_L_Thumb3"
]

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player = player_root as PlayerController3D
	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null
	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if rig != null else null
	var mesh_instance: MeshInstance3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D/Mesh") as MeshInstance3D if rig != null else null
	var skin: Skin = mesh_instance.skin if mesh_instance != null else null
	var mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh if mesh_instance != null else null

	var bind_name_by_index: Dictionary = {}
	if skin != null and skeleton != null:
		for bind_index: int in range(skin.get_bind_count()):
			var bind_name: String = String(skin.get_bind_name(bind_index))
			if bind_name.is_empty():
				var skeleton_bone_index: int = skin.get_bind_bone(bind_index)
				if skeleton_bone_index >= 0 and skeleton_bone_index < skeleton.get_bone_count():
					bind_name = skeleton.get_bone_name(skeleton_bone_index)
			bind_name_by_index[bind_index] = bind_name

	var finger_slot_hits: Dictionary = {}
	var finger_vertex_hits: Dictionary = {}
	for finger_bone_name: String in FINGER_BONE_NAMES:
		finger_slot_hits[finger_bone_name] = 0
		finger_vertex_hits[finger_bone_name] = 0

	var surface_count: int = mesh.get_surface_count() if mesh != null else 0
	for surface_index: int in range(surface_count):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var vertices_variant = arrays[Mesh.ARRAY_VERTEX]
		var bones_variant = arrays[Mesh.ARRAY_BONES]
		var weights_variant = arrays[Mesh.ARRAY_WEIGHTS]
		var vertex_count: int = _packed_array_size(vertices_variant)
		var weight_count: int = _packed_array_size(weights_variant)
		var influence_count: int = int(weight_count / vertex_count) if vertex_count > 0 else 0
		if vertex_count <= 0 or influence_count <= 0:
			continue

		for vertex_index: int in range(vertex_count):
			var touched_bones: Dictionary = {}
			for influence_slot: int in range(influence_count):
				var packed_index: int = vertex_index * influence_count + influence_slot
				var influence_weight: float = _read_packed_numeric(weights_variant, packed_index)
				if influence_weight <= 0.0001:
					continue
				var bind_index: int = int(_read_packed_numeric(bones_variant, packed_index))
				var bind_name: String = String(bind_name_by_index.get(bind_index, ""))
				if not finger_slot_hits.has(bind_name):
					continue
				finger_slot_hits[bind_name] = int(finger_slot_hits[bind_name]) + 1
				touched_bones[bind_name] = true
			for bind_name: String in touched_bones.keys():
				finger_vertex_hits[bind_name] = int(finger_vertex_hits[bind_name]) + 1

	var weighted_finger_bone_count: int = 0
	for finger_bone_name: String in FINGER_BONE_NAMES:
		if int(finger_vertex_hits[finger_bone_name]) > 0:
			weighted_finger_bone_count += 1

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("rig_loaded=%s" % str(rig != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("mesh_loaded=%s" % str(mesh != null))
	lines.append("skin_loaded=%s" % str(skin != null))
	lines.append("surface_count=%d" % surface_count)
	lines.append("skin_bind_count=%d" % (skin.get_bind_count() if skin != null else -1))
	lines.append("weighted_finger_bone_count=%d" % weighted_finger_bone_count)
	for finger_bone_name: String in FINGER_BONE_NAMES:
		lines.append(
			"%s_slot_hits=%d vertex_hits=%d" % [
				finger_bone_name,
				int(finger_slot_hits[finger_bone_name]),
				int(finger_vertex_hits[finger_bone_name])
			]
		)

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

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

func _read_packed_numeric(packed_variant: Variant, index: int) -> float:
	if packed_variant is PackedFloat32Array:
		return packed_variant[index]
	if packed_variant is PackedInt32Array:
		return float(packed_variant[index])
	if packed_variant is PackedByteArray:
		return float(packed_variant[index])
	return 0.0
