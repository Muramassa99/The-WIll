extends SceneTree

## Isolated observations of the actual rig writers; not an anatomy certificate.
## Does not load a weapon library, edit production rules, or persist game data.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
var output_path := "C:/WORKSPACE/godot_runs/diagnose_combat_elbow_hinge_orientation.json"
var report: Dictionary = {"scope": "Real rig writer isolation; no grip or anatomical certification", "sides": {}, "errors": []}
var rig: PlayerHumanoidRig
var sk: Skeleton3D

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=")
	call_deferred("_run")

func _run() -> void:
	rig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.set_process(false)
	sk = rig.get_node("JosieModel/Josie/Skeleton3D") as Skeleton3D
	if sk == null:
		report.errors.append("missing_skeleton")
		_finish()
		return
	for side: String in ["R", "L"]:
		for part: String in ["Clavicle", "Upperarm", "Forearm", "Hand"]:
			if sk.find_bone(String(_name(side, part))) < 0: report.errors.append(side + "_missing_" + part)
	if not report.errors.is_empty():
		_finish()
		return
	report["skeleton_global_transform"] = sk.global_transform
	report["conventions"] = "Normal=(elbow->shoulder) cross (elbow->hand); upperarm local uses current basis; twist is rest-relative +Y projection; positions labeled world are meters."
	var initial: Array[Transform3D] = _capture()
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	for side: String in ["R", "L"]:
		report.sides[side] = {"rest": _observe(side)}
	_restore(initial)
	rig.set_upper_body_authoring_state({
		"active": true, "blend": 1.0, "two_hand": true, "dominant_slot_id": &"hand_right",
		"primary_target_world": rig.to_global(Vector3(0.32, 1.20, -0.68)),
		"secondary_target_world": rig.to_global(Vector3(-0.22, 1.18, -0.52)),
		"tip_world": rig.to_global(Vector3(0.58, 1.42, -1.08)),
		"pommel_world": rig.to_global(Vector3(0.18, 1.02, -0.44)),
	})
	rig.apply_authoring_preview_frame_now(false)
	var baseline: Array[Transform3D] = _capture()
	var authoring_state: Dictionary = rig.get_upper_body_authoring_state().duplicate(true)
	report["elbow_limits_degrees"] = [rig.authoring_elbow_min_plane_angle_degrees, rig.authoring_elbow_max_plane_angle_degrees]
	for side: String in ["R", "L"]:
		_restore(baseline)
		report.sides[side]["baseline"] = _observe(side)
		_exercise_orbits(side, baseline, authoring_state)
		_exercise_ccd(side, baseline)
	_finish()

func _exercise_orbits(side: String, baseline: Array[Transform3D], authoring_state: Dictionary) -> void:
	_restore(baseline)
	var control: Dictionary = rig.get_authoring_upperarm_roll_control_state(_slot(side))
	if control.is_empty():
		report.errors.append(side + "_missing_roll_control")
		return
	var initial_angle := float(control.get("initial_roll_degrees", 0.0))
	var rows: Array[Dictionary] = []
	for magnitude: float in [15.0, 30.0, 60.0, 90.0, 120.0, 180.0]:
		for sign_value: float in [-1.0, 1.0]:
			_restore(baseline)
			var before := _observe(side)
			var delta := magnitude * sign_value
			var target := wrapf(initial_angle + delta, -180.0, 180.0)
			var state := authoring_state.duplicate(true)
			state["left_upperarm_roll_degrees" if side == "L" else "right_upperarm_roll_degrees"] = target
			rig.set_upper_body_authoring_state(state)
			rig.call("_apply_authoring_manual_upperarm_roll_pose", _slot(side), _name(side, "Upperarm"), _name(side, "Forearm"), _name(side, "Hand"))
			var manual := _observe(side)
			rig.call("_enforce_authoring_upperarm_swing_authority", _slot(side), _name(side, "Clavicle"), _name(side, "Upperarm"), _name(side, "Forearm"), _name(side, "Hand"))
			var enforced := _observe(side)
			rows.append({"delta_degrees": delta, "target_degrees": target, "initial_degrees": initial_angle,
				"before": before, "after_manual": manual, "after_swing_authority": enforced,
				"manual_drift": _drift(before, manual), "authority_drift": _drift(manual, enforced)})
	report.sides[side]["manual_orbit_cases"] = rows

func _exercise_ccd(side: String, baseline: Array[Transform3D]) -> void:
	_restore(baseline)
	var reference := _observe(side)
	var normal: Vector3 = reference["bend_normal_skeleton"]
	if normal.length_squared() < 0.5:
		report.errors.append(side + "_baseline_has_no_bend_plane")
		return
	var rows: Array[Dictionary] = []
	for seed_angle: float in [20.0, -20.0, 168.0, -168.0, 179.999, -179.999, 180.0]:
		_restore(baseline)
		var elbow := _point(side, "Forearm")
		var toward_shoulder := (_point(side, "Upperarm") - elbow).normalized()
		var length := elbow.distance_to(_point(side, "Hand"))
		var seed := elbow + Basis(normal, deg_to_rad(seed_angle)) * toward_shoulder * length
		# Deliberately seed each branch without the guard, then test current CCD.
		rig.call("_rotate_bone_toward_end_target", _name(side, "Forearm"), _name(side, "Hand"), seed, 1.0, false)
		var before := _observe(side)
		var target_angle := -seed_angle if absf(seed_angle) < 170.0 else (-168.0 if seed_angle > 0.0 else 168.0)
		var target := elbow + Basis(normal, deg_to_rad(target_angle)) * toward_shoulder * length
		rig.call("_apply_ccd_arm_reach_pose", _name(side, "Upperarm"), _name(side, "Forearm"), _name(side, "Hand"), sk.to_global(target), 1, 1.0, 0.0, &"", 0.0, 0.0)
		var after := _observe(side)
		rows.append({"seed_signed_angle_degrees": seed_angle, "target_signed_angle_degrees": target_angle,
			"before": before, "after_one_forearm_only_ccd_step": after,
			"bend_normal_dot_before_after": (before.bend_normal_skeleton as Vector3).dot(after.bend_normal_skeleton),
			"hand_target_error_meters": sk.to_global(_point(side, "Hand")).distance_to(sk.to_global(target)),
			"drift": _drift(before, after)})
	report.sides[side]["isolated_ccd_cases"] = rows

func _observe(side: String) -> Dictionary:
	var frames: Dictionary = {}
	for part: String in ["Clavicle", "Upperarm", "Forearm", "Hand"]:
		var index := sk.find_bone(String(_name(side, part)))
		if index < 0:
			report.errors.append(side + "_missing_" + part)
			return {}
		frames[part] = {"rest_local": sk.get_bone_rest(index), "rest_skeleton": sk.get_bone_global_rest(index),
			"pose_local": sk.get_bone_pose(index), "pose_skeleton": sk.get_bone_global_pose(index)}
	var upper: Transform3D = frames.Upperarm.pose_skeleton
	var elbow: Vector3 = frames.Forearm.pose_skeleton.origin
	var hand: Vector3 = frames.Hand.pose_skeleton.origin
	var incoming := (upper.origin - elbow).normalized()
	var outgoing := (hand - elbow).normalized()
	var normal := incoming.cross(outgoing)
	var normal_length := normal.length()
	if normal_length > 1.0e-12: normal /= normal_length
	var relative: Quaternion = (frames.Upperarm.rest_local.basis.orthonormalized().inverse() * frames.Upperarm.pose_local.basis.orthonormalized()).get_rotation_quaternion().normalized()
	var twist := Quaternion(0.0, relative.y, 0.0, relative.w)
	var twist_degrees: Variant = null
	if twist.length_squared() > 1.0e-12:
		twist = twist.normalized()
		twist_degrees = rad_to_deg(wrapf(2.0 * atan2(twist.y, twist.w), -PI, PI))
	return {"frames": frames, "elbow_angle_degrees": rad_to_deg(incoming.angle_to(outgoing)),
		"bend_normal_cross_length": normal_length, "bend_normal_skeleton": normal,
		"bend_normal_upperarm_local": upper.basis.orthonormalized().inverse() * normal,
		"upperarm_rest_relative_q": relative, "upperarm_longitudinal_twist_degrees": twist_degrees,
		"forearm_local_q": sk.get_bone_pose_rotation(sk.find_bone(String(_name(side, "Forearm")))),
		"elbow_world": sk.to_global(elbow), "hand_world": sk.to_global(hand)}

func _drift(before: Dictionary, after: Dictionary) -> Dictionary:
	return {"elbow_meters": (before.elbow_world as Vector3).distance_to(after.elbow_world),
		"hand_meters": (before.hand_world as Vector3).distance_to(after.hand_world)}

func _capture() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index: int in sk.get_bone_count(): result.append(sk.get_bone_pose(index))
	return result

func _restore(poses: Array[Transform3D]) -> void:
	for index: int in poses.size(): sk.set_bone_pose(index, poses[index])
	sk.force_update_all_bone_transforms()

func _point(side: String, part: String) -> Vector3:
	return sk.get_bone_global_pose(sk.find_bone(String(_name(side, part)))).origin

func _name(side: String, part: String) -> StringName:
	return StringName("CC_Base_%s_%s" % [side, part])

func _slot(side: String) -> StringName:
	return &"hand_left" if side == "L" else &"hand_right"

func _json(value: Variant) -> Variant:
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Quaternion: return [value.x, value.y, value.z, value.w]
	if value is Transform3D: return {"origin": _json(value.origin), "basis_columns": [_json(value.basis.x), _json(value.basis.y), _json(value.basis.z)]}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = _json(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_json(item))
		return result
	return value

func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write elbow diagnostic: " + output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(_json(report), "\t"))
	file.close()
	print("ELBOW_HINGE_DIAGNOSTIC errors=%d output=%s" % [report.errors.size(), output_path])
	quit(0 if report.errors.is_empty() else 1)
