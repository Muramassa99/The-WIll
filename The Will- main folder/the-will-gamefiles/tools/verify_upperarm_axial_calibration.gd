extends SceneTree

## Mechanical calibration experiment, not anatomical limits or a new control.
## Uses the actual posed segment translations, including imported animation
## offsets. Nothing is replaced with rest translations to obtain a passing pose.
## Reference: chest-relative upper arm forward, forearm up, elbow 90 degrees.
## Skeleton-relative frames follow the imported ancestry through RL_BoneRoot;
## the parent transform below tests world presentation only. No player save IO.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Calibration = preload("res://runtime/player/combat_shoulder_rig_calibration.gd")
const POSITION_EPSILON := 0.00005
const ANGLE_EPSILON := deg_to_rad(0.025)
var output_dir := "C:/WORKSPACE/godot_runs/upperarm_axial_calibration"
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var rig: PlayerHumanoidRig
var skeleton: Skeleton3D
var actor_parent: Node3D

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	actor_parent = Node3D.new()
	root.add_child(actor_parent)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	actor_parent.add_child(rig)
	await process_frame
	await process_frame
	# All trials below are synchronous after pausing writers. No solver or
	# animation callback can overwrite one trial before its observations.
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in rig.find_children("*", "AnimationTree", true, false):
		(node as AnimationTree).active = false
	for node: Node in rig.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).stop(true)
	for node: Node in rig.find_children("*", "SkeletonModifier3D", true, false):
		(node as SkeletonModifier3D).active = false
	skeleton = rig.skeleton
	_check(skeleton != null, "actual_imported_skeleton_available")
	if skeleton != null:
		for side: String in ["R", "L"]:
			_exercise(side)
	_finish()

func _exercise(side: String) -> void:
	actor_parent.transform = Transform3D.IDENTITY
	var slot := &"hand_right" if side == "R" else &"hand_left"
	var calibration: Dictionary = Calibration.build(skeleton, slot)
	_check(calibration.get("valid", false), side + "_calibration", calibration.get("reason", ""))
	if not calibration.get("valid", false): return
	_check(calibration.bone_origin_records.has(&"RL_BoneRoot"), side + "_declared_root_ancestry")
	var upper_id := skeleton.find_bone("CC_Base_" + side + "_Upperarm")
	var elbow_id := skeleton.find_bone("CC_Base_" + side + "_Forearm")
	var hand_id := skeleton.find_bone("CC_Base_" + side + "_Hand")
	var clavicle_id := skeleton.find_bone("CC_Base_" + side + "_Clavicle")
	var chest_id := skeleton.find_bone(String(calibration.chest_bone_name))
	var originals := {upper_id: skeleton.get_bone_pose(upper_id), elbow_id: skeleton.get_bone_pose(elbow_id)}
	var chest := skeleton.get_bone_global_pose(chest_id)
	var clavicle := skeleton.get_bone_global_pose(clavicle_id)
	var chest_frame: Basis = chest.basis.orthonormalized() * calibration.chest_anatomical_in_bone
	_point_segment(upper_id, elbow_id, -chest_frame.z)
	_point_segment(elbow_id, hand_id, chest_frame.y)
	var reference := _positions(upper_id, elbow_id, hand_id)
	_check(absf(_bend(reference) - PI * 0.5) < ANGLE_EPSILON, side + "_fixture_bend_90")
	_check((reference.elbow - reference.shoulder).normalized().dot(-chest_frame.z) > 0.99999, side + "_fixture_upper_forward")
	_check((reference.wrist - reference.elbow).normalized().dot(chest_frame.y) > 0.99999, side + "_fixture_forearm_up")
	_check(skeleton.get_bone_global_pose(chest_id).is_equal_approx(chest)
		and skeleton.get_bone_global_pose(clavicle_id).is_equal_approx(clavicle), side + "_fixture_chest_clavicle_stationary")
	# Exactly the user's capture-once operation; current geometry determines the
	# material shaft, independent of assumed imported X/Y/Z bone alignment.
	var q_reference := skeleton.get_bone_pose_rotation(upper_id).normalized()
	var upper_reference := skeleton.get_bone_global_pose(upper_id)
	_check(upper_reference.basis.is_conformal() and upper_reference.basis.determinant() > 0.0, side + "_supported_rigid_or_uniform_scale")
	var shaft_axis: Vector3 = (upper_reference.basis.inverse() * (reference.elbow - reference.shoulder)).normalized()
	_check(shaft_axis.is_finite() and shaft_axis.length_squared() > 0.99999, side + "_finite_unit_shaft")
	var translations: Array[Vector3] = [skeleton.get_bone_pose_position(elbow_id), skeleton.get_bone_pose_position(hand_id)]
	for transformed: bool in [false, true]:
		actor_parent.transform = Transform3D(Basis.from_euler(Vector3(0.23, -0.61, 0.17)).scaled(Vector3.ONE * 1.7), Vector3(5.0, -2.0, 7.0)) if transformed else Transform3D.IDENTITY
		for degrees: float in [30.0, 0.0, -30.0]:
			var label := side + ("_transformed_" if transformed else "_identity_") + str(degrees)
			var roll_offset := Quaternion(shaft_axis, deg_to_rad(degrees))
			skeleton.set_bone_pose_rotation(upper_id, (q_reference * roll_offset).normalized())
			skeleton.force_update_all_bone_transforms()
			var actual := _positions(upper_id, elbow_id, hand_id)
			var shaft: Vector3 = (reference.elbow - reference.shoulder).normalized()
			var expected_wrist: Vector3 = reference.shoulder + Basis(shaft, deg_to_rad(degrees)) * (reference.wrist - reference.shoulder)
			var world: Transform3D = skeleton.global_transform
			var wrist_error: float = (world * actual.wrist).distance_to(world * expected_wrist)
			_check((world * actual.shoulder).distance_to(world * reference.shoulder) <= POSITION_EPSILON, label + "_shoulder_fixed")
			_check((world * actual.elbow).distance_to(world * reference.elbow) <= POSITION_EPSILON, label + "_elbow_fixed")
			_check(wrist_error <= POSITION_EPSILON, label + "_wrist_matches_shaft_arc", wrist_error)
			_check(absf(_bend(actual) - _bend(reference)) < ANGLE_EPSILON, label + "_bend_preserved")
			_check(actual.wrist.distance_to(reference.wrist) > 0.01 if degrees != 0.0 else actual.wrist.distance_to(reference.wrist) <= POSITION_EPSILON, label + "_wrist_moves_or_returns")
			_check(skeleton.get_bone_global_pose(chest_id).is_equal_approx(chest)
				and skeleton.get_bone_global_pose(clavicle_id).is_equal_approx(clavicle), label + "_proximal_bones_fixed")
			_check(translations == [skeleton.get_bone_pose_position(elbow_id), skeleton.get_bone_pose_position(hand_id)], label + "_child_offsets_not_rewritten")
			samples.append({"case": label, "reference_space": "Skeleton3D through RL_BoneRoot", "shaft_in_upperarm": shaft_axis,
				"origin_id": StringName("CC_Base_" + side + "_Upperarm"), "pose": actual, "world_wrist_arc_error_m": wrist_error})
	# Existing control measures a shoulder-to-HAND axis: demonstrate that this
	# is a distinct swivel coordinate without changing its authored semantics.
	skeleton.set_bone_pose_rotation(upper_id, q_reference)
	skeleton.force_update_all_bone_transforms()
	var swivel: Dictionary = rig.get_authoring_upperarm_roll_control_state(slot)
	var swivel_transform: Transform3D = skeleton.global_transform
	var shaft_world: Vector3 = (swivel_transform * reference.elbow - swivel_transform * reference.shoulder).normalized()
	var swivel_world: Vector3 = (swivel_transform * reference.wrist - swivel_transform * reference.shoulder).normalized()
	_check(not swivel.is_empty() and (swivel.get("axis_global", Vector3.ZERO) as Vector3).dot(swivel_world) > 0.99999, side + "_existing_control_is_shoulder_to_hand")
	_check(absf(swivel_world.dot(shaft_world)) < 0.99, side + "_swivel_is_not_axial_roll")
	for bone_id: int in originals:
		skeleton.set_bone_pose(bone_id, originals[bone_id])
	skeleton.force_update_all_bone_transforms()

func _point_segment(parent_id: int, child_id: int, direction: Vector3) -> void:
	var parent := skeleton.get_bone_global_pose(parent_id)
	var child := skeleton.get_bone_global_pose(child_id)
	var swing := Basis(Quaternion((child.origin - parent.origin).normalized(), direction.normalized()))
	var grandparent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(parent_id))
	var rotation := grandparent.basis.orthonormalized().transposed() * swing * parent.basis.orthonormalized()
	skeleton.set_bone_pose_rotation(parent_id, rotation.get_rotation_quaternion().normalized())
	skeleton.force_update_all_bone_transforms()

func _positions(upper_id: int, elbow_id: int, hand_id: int) -> Dictionary:
	return {"shoulder": skeleton.get_bone_global_pose(upper_id).origin,
		"elbow": skeleton.get_bone_global_pose(elbow_id).origin, "wrist": skeleton.get_bone_global_pose(hand_id).origin}

func _bend(pose: Dictionary) -> float:
	return (pose.elbow - pose.shoulder).angle_to(pose.wrist - pose.elbow)

func _check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed": passed, "check": label, "detail": detail})
	if not passed: push_error("UPPERARM_AXIAL " + label + " " + str(detail))

func _finish() -> void:
	var passed := true
	for item: Dictionary in checks: passed = passed and bool(item.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples,
		"scope": "Capture-once +/-30 degree imported-bone axial-roll mechanics, actual posed segment offsets, R/L and presentation transform. Not anatomical range, allocator, grip or skin validation."}, "\t"))
	file.close()
	print("UPPERARM_AXIAL passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)
