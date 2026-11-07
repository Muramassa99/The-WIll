extends SceneTree

## Pure frame mathematics plus read-only imported rest. Does not run animation,
## grip, movement allocation, scene collision, Save or F playback.
const Resolver = preload("res://core/resolvers/combat_clavicle_motion_resolver.gd")
const Model = preload("res://Josie/josie.tscn")
const Profile = preload("res://core/defs/characters/josie/shoulder_motion_profile.tres")
const EPS := 0.00001
var checks: Array[Dictionary] = []
var output_dir := "C:/WORKSPACE/godot_runs/clavicle_motion"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	var profile: Dictionary = Profile.as_dictionary()
	_check(is_equal_approx(float(profile.clavicle_swing_half_angle_degrees), 10.0), "explicit_provisional_ten_degree_profile")
	# Synthetic mirrored shafts are oblique to all imported material axes.
	for side: float in [-1.0, 1.0]:
		var rest := Transform3D(Basis.from_euler(Vector3(0.13, -0.29 * side, 0.21)), Vector3(0.07 * side, 0.12, -0.03))
		var child := Transform3D(Basis.IDENTITY, Vector3(0.12 * side, 0.035, 0.018))
		_exercise("synthetic_" + str(side), rest, child, &"SyntheticClavicle")
	var actor: Node = Model.instantiate()
	var skeletons: Array[Node] = actor.find_children("*", "Skeleton3D", true, false)
	_check(not skeletons.is_empty(), "imported_skeleton_found")
	if not skeletons.is_empty():
		var skeleton := skeletons[0] as Skeleton3D
		for side: String in ["R", "L"]:
			var name := StringName("CC_Base_" + side + "_Clavicle")
			var clavicle: int = skeleton.find_bone(String(name))
			var upperarm: int = skeleton.find_bone("CC_Base_" + side + "_Upperarm")
			_check(clavicle >= 0 and upperarm >= 0, side + "_actual_bones_found")
			if clavicle < 0 or upperarm < 0:
				continue
			_check(skeleton.get_bone_parent(upperarm) == clavicle and skeleton.get_bone_name(skeleton.get_bone_parent(clavicle)) == "CC_Base_Spine02", side + "_actual_serial_parent_chain")
			var cursor := clavicle
			var ancestry: Array[String] = []
			while cursor >= 0:
				ancestry.append(skeleton.get_bone_name(cursor))
				cursor = skeleton.get_bone_parent(cursor)
			_check(ancestry.back() == "RL_BoneRoot", side + "_actual_root_provenance", ancestry)
			_exercise(side, skeleton.get_bone_rest(clavicle), skeleton.get_bone_rest(upperarm), name)
			_exercise_fixed_idle(side, skeleton.get_bone_rest(clavicle), skeleton.get_bone_rest(upperarm), name)
	actor.free()
	_test_invalid_inputs()
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if report == null:
		push_error("Cannot write clavicle verifier report")
		quit(1)
		return
	report.store_string(JSON.stringify({"passed": passed, "checks": checks,
		"scope": "Pure fixed-reference clavicle coordinates, imported rest, and explicit immutable Idle home; not live coordination proof."}, "\t"))
	report.close()
	print("CLAVICLE_MOTION passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)

func _exercise(label: String, rest: Transform3D, child: Transform3D, bone_name: StringName) -> void:
	var calibration: Dictionary = Resolver.calibrate(rest, child, bone_name)
	_check(calibration.valid, label + "_calibration")
	if not calibration.valid:
		return
	_check(calibration.parent_origin_id == &"CC_Base_Spine02" and calibration.source_bone_name == bone_name and calibration.rest_transform == rest, label + "_fixed_named_rest_origin")
	var zero: Dictionary = Resolver.measure(rest, calibration)
	_check(zero.valid and absf(zero.swing_angle) < EPS and absf(zero.twist) < EPS, label + "_rest_zero")
	var original_calibration: Dictionary = calibration.duplicate(true)
	var source := Transform3D(rest.basis * Basis.from_scale(Vector3.ONE * 1.37), rest.origin + Vector3(0.01, -0.02, 0.03))
	var common := Transform3D(Basis.from_euler(Vector3(-0.42, 0.81, 0.26)) * Basis.from_scale(Vector3.ONE * 1.8), Vector3(2.4, -1.2, 0.7))
	var moved_calibration: Dictionary = Resolver.calibrate(common * rest, child, bone_name)
	_check(moved_calibration.valid, label + "_transformed_parent_calibration")
	for degrees: Vector2 in [Vector2.ZERO, Vector2(6.0, 0.0), Vector2(0.0, -6.0), Vector2(4.0, 4.0), Vector2(5.0, 5.0), Vector2(-18.0, 9.0)]:
		for twist_degrees: float in [0.0, 23.0, -41.0]:
			var tag := label + "_" + str(degrees) + "_twist_" + str(twist_degrees)
			var x: float = deg_to_rad(degrees.x)
			var y: float = deg_to_rad(degrees.y)
			var held: float = deg_to_rad(twist_degrees)
			var composed: Dictionary = Resolver.compose(x, y, held, calibration, source)
			_check(composed.valid, tag + "_compose")
			if not composed.valid:
				continue
			var frame: Transform3D = composed.local_transform
			var measured: Dictionary = Resolver.measure(frame, calibration, 6.0, held)
			_check(measured.valid and absf(measured.swing_x - x) < EPS and absf(measured.swing_y - y) < EPS and measured.axial_constraint < EPS, tag + "_coordinates_and_held_axial")
			_check(absf(measured.constraint - deg_to_rad(degrees.length() - 6.0)) < EPS, tag + "_circular_cone_not_axis_box")
			_check(frame.origin == source.origin and frame.basis.get_scale().distance_to(source.basis.get_scale()) < EPS, tag + "_translation_scale_preserved")
			var actual_length: float = (frame * child.origin - frame.origin).length()
			var source_length: float = (source * child.origin - source.origin).length()
			_check(absf(actual_length - source_length) < EPS, tag + "_socket_length_preserved")
			var transformed: Dictionary = Resolver.measure(common * frame, moved_calibration, 6.0, held)
			_check(transformed.valid and absf(transformed.swing_x - measured.swing_x) < EPS and absf(transformed.swing_y - measured.swing_y) < EPS and absf(transformed.twist - measured.twist) < EPS, tag + "_parent_transform_invariant")
			var moved: Dictionary = Resolver.compose(x, y, held, moved_calibration, common * source)
			_check(moved.valid and _transform_error(moved.local_transform, common * frame) < EPS, tag + "_parent_transform_composition")
	# A pre-existing out-of-cone pose remains readable without enlarging the cone.
	var outside: Dictionary = Resolver.compose(deg_to_rad(17.0), deg_to_rad(-4.0), 0.31, calibration, source)
	var previous: Transform3D = outside.local_transform
	var stable := true
	for repeat: int in 20:
		var acquired: Dictionary = Resolver.measure(previous, calibration)
		var reconstructed: Dictionary = Resolver.compose(acquired.swing_x, acquired.swing_y, acquired.twist, calibration, previous)
		stable = stable and acquired.constraint > 0.0 and _transform_error(reconstructed.local_transform, outside.local_transform) < EPS * 4.0
		previous = reconstructed.local_transform
	_check(stable and calibration == original_calibration, label + "_regrab_never_recentres_cone_or_grants_axial_travel")
	var extra_twist: Dictionary = Resolver.compose(0.0, 0.0, 0.31 + deg_to_rad(1.0), calibration, source)
	var mismatch: Dictionary = Resolver.measure(extra_twist.local_transform, calibration, 6.0, 0.31)
	_check(absf(mismatch.axial_constraint - deg_to_rad(1.0)) < EPS, label + "_held_axial_readback_detects_change")

func _test_invalid_inputs() -> void:
	var rest := Transform3D.IDENTITY
	var child := Transform3D(Basis.IDENTITY, Vector3(0.1, 0.02, 0.01))
	var calibration: Dictionary = Resolver.calibrate(rest, child)
	_check(not Resolver.calibrate(rest, Transform3D.IDENTITY).valid, "zero_length_socket_rejected")
	var distorted := Transform3D(Basis.from_scale(Vector3(1.0, 2.0, 1.0)), Vector3.ZERO)
	_check(not Resolver.calibrate(distorted, child).valid, "unsupported_nonuniform_reference_rejected")
	_check(not Resolver.compose(NAN, 0.0, 0.0, calibration, rest).valid, "nonfinite_coordinate_rejected")
	_check(not Resolver.measure(rest, calibration, -1.0).valid, "negative_limit_rejected")
	_check(not Resolver.measure(rest, calibration, 6.0, INF).valid, "nonfinite_held_angle_rejected")
	_check(not Resolver.compose(PI, 0.0, 0.0, calibration, rest).valid, "antipodal_swing_chart_rejected")
	_check(not Resolver.measure(rest, {}).valid, "missing_calibration_rejected")
	_check(not Resolver.calibrate(rest, child, &"Clavicle", Quaternion.IDENTITY).valid, "fixed_reference_wrong_type_rejected")
	_check(not Resolver.calibrate(rest, child, &"Clavicle", Basis.from_scale(Vector3.ONE * 2.0)).valid, "fixed_reference_scale_rejected")

func _exercise_fixed_idle(side: String, rest: Transform3D, child: Transform3D, bone_name: StringName) -> void:
	var profile: Dictionary = Profile.as_dictionary()
	var snapshot: PackedByteArray = var_to_bytes(profile)
	var slot := &"hand_right" if side == "R" else &"hand_left"
	var rotation: Quaternion = profile.clavicle_reference_rotations_by_slot[slot]
	var reference := Basis(rotation)
	var calibration: Dictionary = Resolver.calibrate(rest, child, bone_name, reference)
	_check(calibration.valid, side + "_fixed_idle_calibrates")
	if not calibration.valid:
		return
	var home := Transform3D(reference * Basis.from_scale(rest.basis.get_scale()), rest.origin)
	var center: Dictionary = Resolver.measure(home, calibration, 10.0)
	_check(center.valid and center.swing_angle < EPS and absf(center.twist) < EPS and center.constraint < 0.0, side + "_fixed_idle_is_cone_center")
	_check(calibration.reference_source == "fixed_idle_pose" and String(calibration.origin_id).ends_with("IdlePoseClavicleOrigin") and calibration.origin_record.transform_to_parent == home, side + "_idle_origin_metadata_matches_reference")
	_check(calibration.rest_transform == rest and calibration.upperarm_rest_transform == child and _transform_error(calibration.fixed_reference_transform, rest) > EPS, side + "_idle_reference_retains_distinct_imported_rest_provenance")
	var initial_calibration: Dictionary = calibration.duplicate(true)
	var positive: Dictionary = Resolver.compose(deg_to_rad(10.0), 0.0, 0.0, calibration, home)
	var negative: Dictionary = Resolver.compose(deg_to_rad(-10.0), 0.0, 0.0, calibration, home)
	var at_positive: Dictionary = Resolver.measure(positive.local_transform, calibration, 10.0, 0.0)
	var at_negative: Dictionary = Resolver.measure(negative.local_transform, calibration, 10.0, 0.0)
	_check(absf(at_positive.constraint) < EPS and absf(at_negative.constraint) < EPS and at_positive.axial_constraint < EPS and at_negative.axial_constraint < EPS, side + "_idle_cone_ten_degrees_each_way")
	var first_direction: Vector3 = (positive.local_transform.basis * (calibration.shaft_local as Vector3)).normalized()
	var second_direction: Vector3 = (negative.local_transform.basis * (calibration.shaft_local as Vector3)).normalized()
	_check(absf(first_direction.angle_to(second_direction) - deg_to_rad(20.0)) < EPS, side + "_idle_opposite_endpoints_twenty_degrees_apart")
	var common := Transform3D(Basis.from_euler(Vector3(0.2, -0.5, 0.1)) * Basis.from_scale(Vector3.ONE * 1.8), Vector3(2.0, -1.0, 3.0))
	var moved_calibration: Dictionary = Resolver.calibrate(common * rest, child, bone_name, common.basis.orthonormalized() * reference)
	var moved: Dictionary = Resolver.measure(common * (positive.local_transform as Transform3D), moved_calibration, 10.0, 0.0)
	_check(moved.valid and absf(moved.swing_x - at_positive.swing_x) < EPS and absf(moved.swing_y - at_positive.swing_y) < EPS and moved.axial_constraint < EPS, side + "_idle_reference_parent_transform_invariant")
	_check(calibration == initial_calibration and snapshot == var_to_bytes(Profile.as_dictionary()), side + "_edited_pose_never_redefines_idle_home")

func _transform_error(a: Transform3D, b: Transform3D) -> float:
	var result: float = a.origin.distance_to(b.origin)
	for index: int in 3:
		result = maxf(result, a.basis[index].distance_to(b.basis[index]))
	return result

func _check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed": passed, "label": label, "detail": detail})
	if not passed:
		push_error(label + ": " + str(detail))
