extends SceneTree

const RigScene: PackedScene = preload(
	"res://scenes/player/player_humanoid_rig.tscn"
)
const TEST_BONES: Array[StringName] = [
	&"CC_Base_L_Clavicle",
	&"CC_Base_L_Upperarm",
	&"CC_Base_L_Forearm",
	&"CC_Base_L_Hand",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor: Node3D = RigScene.instantiate() as Node3D
	root.add_child(actor)
	await process_frame
	await process_frame
	var skeleton: Skeleton3D = actor.get_node_or_null(
		"JosieModel/Josie/Skeleton3D"
	) as Skeleton3D
	if skeleton == null:
		print("POSE_COMPOSITION skeleton_missing")
		quit(1)
		return
	for bone_name: StringName in TEST_BONES:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		if bone_index < 0 or parent_index < 0:
			print("POSE_COMPOSITION bone_missing ", bone_name)
			quit(1)
			return
		var actual: Transform3D = skeleton.get_bone_global_pose(bone_index)
		var parent: Transform3D = skeleton.get_bone_global_pose(parent_index)
		var pose: Transform3D = skeleton.get_bone_pose(bone_index)
		var rest: Transform3D = skeleton.get_bone_rest(bone_index)
		_print_candidate(bone_name, "parent_pose", actual, parent * pose)
		_print_candidate(
			bone_name,
			"parent_rest_pose",
			actual,
			parent * rest * pose
		)
		_print_candidate(
			bone_name,
			"parent_pose_rest",
			actual,
			parent * pose * rest
		)
	quit(0)


func _print_candidate(
	bone_name: StringName,
	formula: String,
	actual: Transform3D,
	candidate: Transform3D
) -> void:
	var basis_error_degrees: float = rad_to_deg(
		actual.basis.orthonormalized().get_rotation_quaternion().angle_to(
			candidate.basis.orthonormalized().get_rotation_quaternion()
		)
	)
	print(
		"POSE_COMPOSITION bone=", bone_name,
		" formula=", formula,
		" origin_error=", actual.origin.distance_to(candidate.origin),
		" basis_error_degrees=", basis_error_degrees
	)
