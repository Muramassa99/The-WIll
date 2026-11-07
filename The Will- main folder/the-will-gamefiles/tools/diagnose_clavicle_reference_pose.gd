extends SceneTree

const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Supplied := {
	"L": Quaternion(0.174668, -0.030927, -0.808198, 0.561561),
	"R": Quaternion(0.160754, 0.015876, 0.821109, 0.547436)}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rig: Node3D = RigScene.instantiate()
	root.add_child(rig)
	await process_frame
	await process_frame
	var skeleton: Skeleton3D = rig.get("skeleton")
	var rows: Array = []
	for phase: String in ["scene_initial", "authoring_default"]:
		if phase == "authoring_default":
			rig.call("set_authoring_preview_mode_enabled", true)
			rig.call("reset_authoring_preview_baseline_pose")
		for side: String in ["L", "R"]:
			var index := skeleton.find_bone("CC_Base_" + side + "_Clavicle")
			var rest: Transform3D = skeleton.get_bone_rest(index)
			var pose: Transform3D = skeleton.get_bone_pose(index)
			var reference: Quaternion = Supplied[side].normalized()
			rows.append({"phase": phase, "side": side, "rest": rest, "pose": pose,
				"rest_quaternion": rest.basis.get_rotation_quaternion(),
				"pose_quaternion": pose.basis.get_rotation_quaternion(),
				"supplied_vs_rest_deg": _angle(reference, rest.basis.get_rotation_quaternion()),
				"supplied_vs_pose_deg": _angle(reference, pose.basis.get_rotation_quaternion())})
	var output := "C:/WORKSPACE/godot_runs/upper_body_coordination_20261107/clavicle_reference.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	print(JSON.stringify(rows))
	quit()

func _angle(a: Quaternion, b: Quaternion) -> float:
	var relative := (a.inverse() * b).normalized()
	return rad_to_deg(2.0 * atan2(Vector3(relative.x, relative.y, relative.z).length(), absf(relative.w)))
