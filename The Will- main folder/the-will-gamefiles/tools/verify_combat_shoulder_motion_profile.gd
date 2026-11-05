extends SceneTree

## Narrow value/calibration verifier, not motion-allocator or anatomical proof.
## Real imported rest; explicitly constructed sample poses and common transforms.
const Model = preload("res://Josie/josie.tscn")
const Calibration = preload("res://runtime/player/combat_shoulder_rig_calibration.gd")
const Resolver = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const Profile = preload("res://core/defs/characters/josie/shoulder_motion_profile.tres")
var checks: Array[Dictionary] = []
var out_dir := "C:/WORKSPACE/godot_runs/shoulder_motion_profile"

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			out_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	var actor: Node = Model.instantiate()
	root.add_child(actor)
	var candidates: Array[Node] = actor.find_children("*", "Skeleton3D", true, false)
	_check(not candidates.is_empty(), "imported_skeleton_exists")
	if not candidates.is_empty():
		var skeleton := candidates[0] as Skeleton3D
		for slot: StringName in [&"hand_right", &"hand_left"]:
			_exercise(skeleton, slot)
	var invalid: Dictionary = Profile.as_dictionary()
	invalid.maximum_samples_radians = PackedFloat64Array([1.0])
	_check(not Resolver.validate_profile(invalid).valid, "incomplete_profile_rejected")
	var passed := true
	for item: Dictionary in checks:
		passed = passed and bool(item.passed)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write shoulder profile report")
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks,
		"scope": "Imported rest and pure semantic math only; no skill/allocator behavior claim"}, "\t"))
	file.close()
	print("SHOULDER_MOTION_PROFILE passed=%s checks=%d" % [passed, checks.size()])
	quit(0 if passed else 1)

func _exercise(skeleton: Skeleton3D, slot: StringName) -> void:
	var calibration: Dictionary = Calibration.build(skeleton, slot)
	var label := String(slot)
	_check(calibration.get("valid", false), label + "_immutable_rest_calibration", calibration.get("reason", ""))
	if not calibration.get("valid", false):
		return
	var profile: Dictionary = Profile.as_dictionary()
	var chest_index: int = skeleton.find_bone(String(calibration.chest_bone_name))
	var upper_index: int = skeleton.find_bone(String(calibration.upperarm_bone_name))
	var chest: Transform3D = skeleton.get_bone_global_rest(chest_index)
	var upper: Transform3D = skeleton.get_bone_global_rest(upper_index)
	var anatomical: Basis = chest.basis.orthonormalized() * (calibration.chest_anatomical_in_bone as Basis)
	var side: float = calibration.side_sign
	_check(calibration.bone_origin_records.has(&"RL_BoneRoot") and calibration.parent_origin_id == &"CC_Base_Spine02", label + "_declared_machine_origin_chain")
	_check(float(calibration.internal_sign) == -side, label + "_internal_turn_reference_exercise")
	var planes := [0.0, 32.5, 90.0]
	var minimums := [-107.0, -103.0, -113.0]
	var maximums := [73.0, 65.0, 41.0]
	for index: int in planes.size():
		var phi: float = deg_to_rad(planes[index])
		var direction := Vector3(side * cos(phi), 0.0, -sin(phi))
		var forearm := Transform3D(Basis.IDENTITY, upper.origin + anatomical * direction * 0.3)
		var posed: Dictionary = Resolver.compose(chest, upper, forearm, calibration, deg_to_rad(-35.0))
		_check(posed.get("valid", false), label + "_sample_compose_" + str(index))
		if not posed.get("valid", false):
			continue
		upper.basis = posed.upperarm_basis
		var measured: Dictionary = Resolver.measure(chest, upper, forearm, calibration, profile)
		_check(measured.valid and measured.covered and absf(rad_to_deg(float(measured.state.h)) + 35.0) < 0.001, label + "_sample_roundtrip_" + str(index))
		_check(absf(rad_to_deg(measured.minimum_radians) - minimums[index]) < 0.001 and absf(rad_to_deg(measured.maximum_radians) - maximums[index]) < 0.001, label + "_sample_bounds_" + str(index))
		var common := Transform3D(Basis.from_euler(Vector3(0.23, -0.61, 0.17)).scaled(Vector3.ONE * 1.7), Vector3(5.0, -2.0, 7.0))
		var moved: Dictionary = Resolver.measure(common * chest, common * upper, common * forearm, calibration, profile)
		_check(moved.valid and absf(float(moved.state.h) - float(measured.state.h)) < 0.00001, label + "_common_transform_invariant_" + str(index))
		for turns: float in [179.0, 181.0, 359.0, 500.0]:
			var composed: Dictionary = Resolver.compose(chest, upper, forearm, calibration, deg_to_rad(turns))
			var unwrapped: Dictionary = Resolver.measure(chest, Transform3D(composed.upperarm_basis, upper.origin), forearm, calibration, profile, {"h": deg_to_rad(turns)})
			_check(unwrapped.valid and absf(rad_to_deg(float(unwrapped.state.h)) - turns) < 0.001 and not unwrapped.legal, label + "_total_angle_cannot_wrap_" + str(index) + "_" + str(turns))
	for direction: Vector3 in [Vector3.DOWN, Vector3.UP, Vector3(0.0, 0.0, 1.0), Vector3(-side, 0.0, 0.0)]:
		var forearm := Transform3D(Basis.IDENTITY, upper.origin + anatomical * direction * 0.3)
		var composed: Dictionary = Resolver.compose(chest, upper, forearm, calibration, deg_to_rad(23.0))
		_check(composed.get("valid", false), label + "_uncovered_pose_still_readable_" + str(direction))
		if not composed.get("valid", false):
			continue
		var measured: Dictionary = Resolver.measure(chest, Transform3D(composed.upperarm_basis, upper.origin), forearm, calibration, profile)
		_check(measured.valid and not measured.covered and absf(rad_to_deg(float(measured.state.h)) - 23.0) < 0.001, label + "_uncovered_roundtrip_" + str(direction))
	# Pose changes cannot change immutable imported-rest calibration.
	var before: Dictionary = calibration.duplicate(true)
	skeleton.set_bone_pose_rotation(upper_index, Quaternion(Vector3.UP, 0.4))
	_check(Calibration.build(skeleton, slot) == before, label + "_posed_arm_does_not_redefine_zero")
	skeleton.reset_bone_pose(upper_index)

func _check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed": passed, "label": label, "detail": detail})
	if not passed:
		push_error(label + ": " + str(detail))
