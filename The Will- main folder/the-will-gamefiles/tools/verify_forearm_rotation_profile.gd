extends SceneTree

## Focused numerical checks on the real imported L/R rest frames. No weapon,
## saved library, grip acquisition or authored skill mutation.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Wrist = preload("res://core/resolvers/combat_wrist_motion_resolver.gd")
const Calibration = preload("res://runtime/player/combat_wrist_rig_calibration.gd")
const ForearmSkin = preload("res://core/resolvers/combat_forearm_hand_index_resolver.gd")
const MotionAdapter = preload("res://runtime/player/combat_weapon_motion_rig_adapter.gd")
var checks: Array[Dictionary] = []
var calibration_summary := {}
var output_path := "C:/WORKSPACE/godot_runs/forearm_rotation_profile/report.json"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): output_path = argument.trim_prefix("--out=")
	call_deferred("_run")

func _run() -> void:
	var rig: PlayerHumanoidRig = RigScene.instantiate()
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_process(false)
	rig.set_physics_process(false)
	var sk: Skeleton3D = rig.skeleton
	var profile: Dictionary = rig.wrist_motion_profile.as_dictionary()
	for spec: Array in [[&"hand_right", "CC_Base_R_"], [&"hand_left", "CC_Base_L_"]]:
		var slot: StringName = spec[0]
		var prefix: String = spec[1]
		var calibration: Dictionary = Calibration.build(sk, slot)
		_check(calibration.get("valid", false), String(slot) + "_calibration")
		if not calibration.get("valid", false): continue
		calibration_summary[slot] = {"thumb_up_rho_degrees": rad_to_deg(calibration.forearm_thumb_up_rho_radians),
			"pronation_sign": calibration.forearm_pronation_sign,
			"origin_id": calibration.forearm_reference_origin_id,
			"parent_origin_id": calibration.forearm_reference_parent_origin_id}
		var f: int = sk.find_bone(prefix + "Forearm")
		var h: int = sk.find_bone(prefix + "Hand")
		var forearm: Transform3D = sk.get_bone_global_rest(f)
		var hand: Transform3D = sk.get_bone_global_rest(h)
		var zero: float = calibration.forearm_thumb_up_rho_radians
		var direction: float = calibration.forearm_pronation_sign
		var shaft: Vector3 = calibration.forearm_shaft_local
		var thumb: Vector3 = -calibration.neutral_anatomical_in_forearm.x * calibration.radial_sign
		thumb -= shaft * thumb.dot(shaft)
		thumb = (Basis(shaft, zero) * thumb.normalized()).normalized()
		_check(thumb.dot(calibration.forearm_thumb_up_local) > 0.9999, String(slot) + "_thumb_up_zero")
		for row: Array in [[0.0, 39.0, 109.0], [45.0, 73.0, 96.0], [90.0, 85.0, 80.0], [160.0, 95.0, 54.0], [125.0, 90.0, 67.0]]:
			var interval: Dictionary = Wrist.forearm_interval(calibration, profile, deg_to_rad(row[0]))
			_check(interval.valid and interval.conditioned and absf(rad_to_deg(interval.supination_limit) - row[1]) < 0.00001 and absf(rad_to_deg(interval.pronation_limit) - row[2]) < 0.00001,
				String(slot) + "_table_" + str(row[0]))
			for p: float in [-deg_to_rad(row[1]), deg_to_rad(row[2])]:
				var state := {"rho": zero + direction * p, "beta": 0.0, "gamma": 0.0}
				var sampled: Dictionary = Wrist.sample_kinematics(forearm, hand, calibration, profile, state, deg_to_rad(row[0]))
				var actual := hand
				actual.basis = sampled.hand_basis
				var accepted: Dictionary = Wrist.compose(forearm, actual, calibration, profile, state, deg_to_rad(row[0]))
				_check(accepted.get("valid", false), String(slot) + "_endpoint_" + str(row[0]) + "_" + str(p))
		var state := {"rho": zero + direction * deg_to_rad(75.0), "beta": 0.0, "gamma": 0.0}
		var sampled: Dictionary = Wrist.sample_kinematics(forearm, hand, calibration, profile, state, deg_to_rad(90.0))
		var actual := hand
		actual.basis = sampled.hand_basis
		_check(Wrist.compose(forearm, actual, calibration, profile, state, deg_to_rad(90.0)).valid, String(slot) + "_75_pronation_at90")
		_check(not Wrist.compose(forearm, actual, calibration, profile, state, deg_to_rad(160.0)).valid, String(slot) + "_75_pronation_rejected_at160")
		var measured: Dictionary = Wrist.measure_state(forearm, actual, calibration, profile, state, deg_to_rad(160.0))
		_check(measured.valid and not measured.within_limits and absf(float(measured.state.rho) - float(state.rho)) < 0.00001, String(slot) + "_outside_pose_remains_measurable")
		var moved := Transform3D(Basis(Vector3(1.0, 2.0, -3.0).normalized(), 0.7), Vector3(80.0, -6.0, 23.0))
		var transformed: Dictionary = Wrist.measure_state(moved * forearm, moved * actual, calibration, profile, state, deg_to_rad(90.0))
		_check(transformed.valid and absf(float(transformed.state.rho) - float(state.rho)) < 0.00001, String(slot) + "_shared_reference_motion_preserves_rho")
		var maximum: Dictionary = Wrist.forearm_interval(calibration, profile)
		_check(maximum.valid and not maximum.conditioned, String(slot) + "_missing_bend_explicit_global_envelope")
		for rho: float in [maximum.rho_min, maximum.rho_max]:
			var skin: Dictionary = ForearmSkin.distribute(forearm, actual,
				sk.get_bone_rest(sk.find_bone(prefix + "ForearmTwist01")).basis,
				sk.get_bone_rest(sk.find_bone(prefix + "ForearmTwist02")).basis,
				sk.get_bone_rest(h).basis, Wrist.forearm_geometry_limit(calibration, profile), deg_to_rad(0.05), rho)
			_check(skin.get("valid", false), String(slot) + "_skin_profile_extreme_" + str(rho))
		_check_adapter_coupling(rig, slot, zero, direction)
	if calibration_summary.size() == 2:
		_check(calibration_summary[&"hand_left"].pronation_sign == -calibration_summary[&"hand_right"].pronation_sign, "mirrored_signs_derived_independently")
	var legacy := profile.duplicate(true)
	legacy.erase("forearm_interval_revision")
	var legacy_bounds: Dictionary = Wrist.forearm_interval({}, legacy, 0.0)
	_check(legacy_bounds.valid and legacy_bounds.legacy and absf(legacy_bounds.rho_max - deg_to_rad(90.0)) < 0.00001, "legacy_packet_preserves_old_scalar")
	_check(not Wrist.forearm_interval({}, profile, 0.0).valid, "new_profile_requires_calibration")
	var passed := true
	for check: Dictionary in checks: passed = passed and check.passed
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"passed": passed, "checks": checks, "calibration": calibration_summary}, "\t"))
		file.close()
	print("FOREARM_ROTATION_PROFILE passed=%s checks=%d output=%s" % [passed, checks.size(), output_path])
	quit(0 if passed else 1)

func _check(passed: bool, name: String) -> void:
	checks.append({"name": name, "passed": passed})
	if not passed: push_error(name)

## Exercise production candidate constraints, not just the interval helper.
## Pure FK evaluations never install these counterfactual poses in the rig.
func _check_adapter_coupling(rig: PlayerHumanoidRig, slot: StringName, zero: float, direction: float) -> void:
	var prop := Node3D.new()
	root.add_child(prop)
	var adapter = MotionAdapter.new()
	var initialized: Dictionary = adapter._initialize(rig, {"weapon": prop,
		"previous_weapon": prop.global_transform, "target_weapon": prop.global_transform,
		"contact_local": Vector3.ZERO, "primary_slot": slot, "mode": "tip", "commit": false})
	_check(initialized.get("valid", false), String(slot) + "_adapter_coupling_initialized")
	if initialized.get("valid", false):
		var arm: Dictionary = adapter.arms[0]
		for row: Array in [[90.0, 75.0, true], [160.0, 75.0, false], [160.0, 54.0, true]]:
			var values: PackedFloat64Array = adapter.q.duplicate()
			values[arm.elbow_q] = deg_to_rad(row[0])
			values[arm.wrist_q] = zero + direction * deg_to_rad(row[1])
			values[arm.wrist_q + 1] = 0.0
			values[arm.wrist_q + 2] = 0.0
			var evaluated: Dictionary = adapter._evaluate_kinematics(values)
			var found := 0
			var satisfied := true
			if evaluated.get("valid", false):
				var reasons: PackedStringArray = evaluated.constraint_reasons
				var constraints: PackedFloat64Array = evaluated.constraints
				for index: int in reasons.size():
					if reasons[index].begins_with("JOINT_RANGE:forearm_"):
						found += 1
						satisfied = satisfied and constraints[index] <= 0.000001
			_check(found == 2 and satisfied == bool(row[2]),
				String(slot) + "_adapter_elbow_" + str(row[0]) + "_pronation_" + str(row[1]))
	prop.free()
