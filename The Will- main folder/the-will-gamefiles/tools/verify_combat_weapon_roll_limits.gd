extends SceneTree

## Focused range-policy verifier. Synthetic registered frames only; no scenes,
## player saves, gameplay settings, or pose writer are changed. Save/load checks
## use a fresh user://verification subdirectory printed in the result.
const Resolver = preload("res://core/resolvers/combat_weapon_roll_resolver.gd")
const Origin = preload("res://core/models/combat_origin_record.gd")
const Registry = preload("res://core/resolvers/combat_origin_registry.gd")
const Motion = preload("res://core/models/combat_animation_motion_node.gd")
const Retarget = preload("res://core/models/combat_animation_retarget_node.gd")
const FrameSolver = preload("res://runtime/combat/combat_animation_weapon_frame_solver.gd")
const ANGLE_TOLERANCE: float = 0.002
const POSITION_TOLERANCE: float = 0.00005

var checks: int = 0
var failures: PackedStringArray = []
var measurements: Array[Dictionary] = []
var artifact_directory: String = ""

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _run() -> void:
	_exercise_centers_and_recapture()
	_exercise_rejections()
	_exercise_model_normalization()
	_exercise_saved_frames()
	print("COMBAT_WEAPON_ROLL_LIMITS_RESULT=" + JSON.stringify({
		"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"measurements": measurements, "artifact_directory": artifact_directory,
	}))
	quit(0 if failures.is_empty() else 1)

func _exercise_centers_and_recapture() -> void:
	for wrist_id: StringName in [Origin.ORIGIN_RIGHT_WRIST, Origin.ORIGIN_LEFT_WRIST]:
		var mirror: float = 1.0 if wrist_id == Origin.ORIGIN_RIGHT_WRIST else -1.0
		for baseline: float in [0.0, 720.0, -720.0]:
			for offset: float in [0.0, 47.0, 156.0, -179.0]:
				var expected_offset: float = mirror * offset
				var fixture: Dictionary = _fixture(wrist_id, expected_offset, 0.0)
				var label: String = "%s baseline=%s offset=%s" % [wrist_id, baseline, expected_offset]
				var capture: Dictionary = fixture.capture
				var source_record = capture.origin_record
				var source_transform: Transform3D = source_record.transform_to_parent
				var neutral_before: Basis = capture.roll_neutral_world_basis
				var result: Dictionary = _limits(fixture, baseline)
				var expected_center: float = baseline + expected_offset
				_check_limits(result, expected_center, label)
				_check(source_record.transform_to_parent == source_transform, label + " immutable wrist frame")
				_check(capture.roll_neutral_world_basis == neutral_before, label + " immutable neutral reference")
				_check(capture.registry.get_origin_count() == 2, label + " immutable registry")
				if not bool(result.get("available", false)):
					continue
				# Alternate both boundaries repeatedly. Every new capture contains
				# the realized Hand and scalar, never the original baseline angle.
				# A range centered on each current scalar would ratchet immediately.
				var current_fixture: Dictionary = fixture
				var current_scalar: float = baseline
				for boundary_offset: float in [-120.0, 120.0, -120.0, 120.0, 0.0]:
					var requested: float = expected_center + boundary_offset
					var rolled: Dictionary = Resolver.resolve(
						current_fixture.capture, current_fixture.weapon, current_fixture.tip,
						Origin.ORIGIN_WEAPON_ROOT, current_scalar, requested
					)
					_check(bool(rolled.get("available", false)), label + " existing transform resolve " + str(requested))
					if not bool(rolled.get("available", false)):
						break
					var next_capture: Dictionary = _capture_fixture(wrist_id, rolled.hand_transform_world)
					next_capture.roll_neutral_world_basis = neutral_before
					current_fixture = {
						"capture": next_capture, "weapon": rolled.weapon_transform_world,
						"tip": fixture.tip,
					}
					current_scalar = requested
					_check_limits(_limits(current_fixture, current_scalar), expected_center,
						label + " recapture at " + str(requested))
				measurements.append({"case": label, "expected_center": expected_center,
					"actual_center": result.center_degrees,
					"minimum": result.minimum_degrees, "maximum": result.maximum_degrees})
		# Off-axis neutral swing means the exact neutral is unattainable.
		# Rx(swing) * Rz(offset) still has independently known nearest Z-orbit
		# rotation=offset, since its quaternion w/z share cos(swing/2).
		var projected_fixture: Dictionary = _fixture(wrist_id, mirror * 63.0, 37.0)
		_check_limits(_limits(projected_fixture, 25.0), 25.0 + mirror * 63.0,
			str(wrist_id) + " off-axis reference projection")
		projected_fixture.capture.roll_neutral_world_basis = (projected_fixture.capture.roll_neutral_world_basis as Basis) * Basis.from_scale(Vector3(0.7, 1.1, 1.3))
		_check_limits(_limits(projected_fixture, 25.0), 25.0 + mirror * 63.0,
			str(wrist_id) + " reference scale does not change center")
	# Side names alone must not reverse the interval. Actual reflected geometry
	# above determines the sign, rather than a hand_right/hand_left multiplier.
	var same_geometry: Dictionary = _fixture(Origin.ORIGIN_RIGHT_WRIST, 41.0, 23.0)
	var left_capture: Dictionary = _capture_fixture(Origin.ORIGIN_LEFT_WRIST, same_geometry.hand)
	left_capture.roll_neutral_world_basis = same_geometry.capture.roll_neutral_world_basis
	same_geometry.capture = left_capture
	_check_limits(_limits(same_geometry, 17.0), 58.0, "slot name does not invent a sign reversal")

func _check_limits(result: Dictionary, expected_center: float, label: String) -> void:
	_check(bool(result.get("available", false)), label + " available: " + str(result.get("reason")))
	if not bool(result.get("available", false)):
		return
	for field: String in ["minimum_degrees", "maximum_degrees", "center_degrees"]:
		_check(result.has(field) and is_finite(float(result.get(field, NAN))), label + " finite " + field)
	if not result.has_all(["minimum_degrees", "maximum_degrees", "center_degrees"]):
		return
	_check(absf(float(result.center_degrees) - expected_center) <= ANGLE_TOLERANCE, label + " correct unwrapped center")
	_check(absf(float(result.minimum_degrees) - (expected_center - 120.0)) <= ANGLE_TOLERANCE, label + " lower endpoint")
	_check(absf(float(result.maximum_degrees) - (expected_center + 120.0)) <= ANGLE_TOLERANCE, label + " upper endpoint")
	_check(absf(float(result.maximum_degrees) - float(result.minimum_degrees) - 240.0) <= ANGLE_TOLERANCE, label + " exactly 240-degree span")

func _exercise_rejections() -> void:
	for kind: String in ["missing_neutral", "wrong_neutral_type", "nan_neutral", "infinite_neutral", "singular_neutral", "reflected_neutral", "ambiguous_neutral", "degenerate_axis", "nan_tip", "missing_registry", "wrong_phase", "stale_wrist", "wrong_tip_origin", "nan_baseline", "infinite_baseline"]:
		var fixture: Dictionary = _fixture(Origin.ORIGIN_RIGHT_WRIST, 45.0, 0.0)
		var baseline: float = 0.0
		var origin_id: StringName = Origin.ORIGIN_WEAPON_ROOT
		match kind:
			"missing_neutral": fixture.capture.erase("roll_neutral_world_basis")
			"wrong_neutral_type": fixture.capture.roll_neutral_world_basis = Vector3.UP
			"nan_neutral": fixture.capture.roll_neutral_world_basis = Basis(Vector3(NAN, 0.0, 0.0), Vector3.UP, Vector3.BACK)
			"infinite_neutral": fixture.capture.roll_neutral_world_basis = Basis(Vector3(INF, 0.0, 0.0), Vector3.UP, Vector3.BACK)
			"singular_neutral": fixture.capture.roll_neutral_world_basis = Basis.from_scale(Vector3(0.0, 1.0, 1.0))
			"reflected_neutral": fixture.capture.roll_neutral_world_basis = Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
			"ambiguous_neutral": fixture = _fixture(Origin.ORIGIN_RIGHT_WRIST, 0.0, 180.0)
			"degenerate_axis": fixture.tip = (fixture.weapon as Transform3D).affine_inverse() * (fixture.hand as Transform3D).origin
			"nan_tip": fixture.tip = Vector3(NAN, 0.0, 0.0)
			"missing_registry": fixture.capture.erase("registry")
			"wrong_phase": fixture.capture.origin_record.resolve_phase = Origin.PHASE_EDITOR_PREVIEW
			"stale_wrist": fixture.capture.origin_record.transform_to_parent.origin.x += 1.0
			"wrong_tip_origin": origin_id = Origin.ORIGIN_TRAJECTORY_AUTHORING
			"nan_baseline": baseline = NAN
			"infinite_baseline": baseline = INF
		var result: Dictionary = Resolver.resolve_limits(fixture.capture, fixture.weapon, fixture.tip, origin_id, baseline)
		_check(not bool(result.get("available", false)), kind + " rejected")
		_check(result.has("reason"), kind + " explicit reason")
		_check(not result.has("weapon_transform_world") and not result.has("hand_transform_world"), kind + " no fallback pose")

func _exercise_model_normalization() -> void:
	for value: float in [-1080.25, -720.0, -276.75, 156.5, 720.0, 1080.25]:
		var motion = Motion.new()
		var retarget = Retarget.new()
		motion.weapon_roll_degrees = value
		retarget.weapon_roll_degrees = value
		motion.retarget_node = retarget
		motion.normalize()
		retarget.normalize()
		_check(is_equal_approx(motion.weapon_roll_degrees, value), "Motion preserves finite unwrapped " + str(value))
		_check(is_equal_approx(retarget.weapon_roll_degrees, value), "Retarget preserves finite unwrapped " + str(value))
	for value: float in [NAN, INF, -INF]:
		var motion = Motion.new()
		var retarget = Retarget.new()
		motion.weapon_roll_degrees = value
		retarget.weapon_roll_degrees = value
		motion.retarget_node = retarget
		motion.normalize()
		retarget.normalize()
		_check(is_finite(motion.weapon_roll_degrees) and motion.weapon_roll_degrees == 0.0, "Motion sanitizes non-finite " + str(value))
		_check(is_finite(retarget.weapon_roll_degrees) and retarget.weapon_roll_degrees == 0.0, "Retarget sanitizes non-finite " + str(value))

func _exercise_saved_frames() -> void:
	artifact_directory = "user://verification/weapon_roll_limits_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(artifact_directory))
	_check(directory_error == OK, "create unique isolated save/load directory")
	if directory_error != OK:
		return
	var solver = FrameSolver.new()
	var local_tip := Vector3(0.07, 0.015, 0.8)
	var local_pommel := Vector3(-0.025, -0.01, -0.2)
	var trajectory := Transform3D(Basis.from_euler(Vector3(0.17, -0.4, 0.32)), Vector3(2.0, -0.7, 1.3))
	var target := Transform3D(Basis.from_euler(Vector3(-0.45, 0.63, -0.27)), Vector3(-0.3, 1.1, 0.4))
	for value: float in [-915.25, -276.75, 276.75, 735.25]:
		var label: String = "saved frame " + str(value)
		var encoded: Dictionary = solver.encode_transform_for_authoring(target, local_tip, local_pommel, Vector3.UP, trajectory, value, Origin.ORIGIN_WEAPON_ROOT)
		_check(bool(encoded.get("available", false)), label + " encoded")
		if not bool(encoded.get("available", false)):
			continue
		var motion = Motion.new()
		for property_name: StringName in [&"tip_position_local", &"tip_position_origin_id", &"pommel_position_local", &"pommel_position_origin_id", &"weapon_orientation_degrees", &"weapon_orientation_authored", &"weapon_roll_degrees"]:
			motion.set(property_name, encoded[property_name])
		var retarget = Retarget.new()
		retarget.weapon_roll_degrees = value
		motion.retarget_node = retarget
		motion.normalize()
		var suffix: String = str(value).replace("-", "minus_").replace(".", "_")
		var motion_path: String = artifact_directory.path_join("motion_" + suffix + ".tres")
		var retarget_path: String = artifact_directory.path_join("retarget_" + suffix + ".tres")
		var motion_error: Error = ResourceSaver.save(motion, motion_path)
		var retarget_error: Error = ResourceSaver.save(retarget, retarget_path)
		_check(motion_error == OK and retarget_error == OK, label + " resources saved")
		if motion_error != OK or retarget_error != OK:
			continue
		var loaded_motion = ResourceLoader.load(motion_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var loaded_retarget = ResourceLoader.load(retarget_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_check(loaded_motion != null and loaded_retarget != null, label + " resources loaded")
		if loaded_motion == null or loaded_retarget == null:
			continue
		loaded_motion.normalize()
		loaded_retarget.normalize()
		_check(is_equal_approx(loaded_motion.weapon_roll_degrees, value), label + " Motion scalar retained")
		_check(is_equal_approx(loaded_retarget.weapon_roll_degrees, value), label + " Retarget scalar retained")
		_check(loaded_motion.retarget_node != null and is_equal_approx(loaded_motion.retarget_node.weapon_roll_degrees, value), label + " embedded Retarget scalar retained")
		var reconstructed: Transform3D = solver.solve_transform_from_segment(
			local_tip, local_pommel, trajectory * loaded_motion.tip_position_local,
			trajectory * loaded_motion.pommel_position_local, Vector3.UP, trajectory.basis,
			loaded_motion.weapon_orientation_degrees, loaded_motion.weapon_roll_degrees,
			Origin.ORIGIN_WEAPON_ROOT, Origin.ORIGIN_WEAPON_ROOT, Origin.ORIGIN_WEAPON_ROOT
		)
		_check(_transform_close(reconstructed, target), label + " exact reconstructed full frame")
		_check((reconstructed * local_tip).distance_to(target * local_tip) < POSITION_TOLERANCE, label + " Tip retained")
		_check((reconstructed * local_pommel).distance_to(target * local_pommel) < POSITION_TOLERANCE, label + " Pommel retained")

func _limits(fixture: Dictionary, baseline: float) -> Dictionary:
	return Resolver.resolve_limits(fixture.capture, fixture.weapon, fixture.tip, Origin.ORIGIN_WEAPON_ROOT, baseline)

func _fixture(wrist_id: StringName, offset: float, off_axis_swing: float) -> Dictionary:
	# A common world rotation changes neither the known center nor handedness.
	# Positive local scales preserve the independent authored rotation bases.
	var common := Basis.from_euler(Vector3(0.37, -0.61, 0.29))
	var hand_rotation := Basis.from_euler(Vector3(-0.23, 0.18, 0.46))
	var reflection: Basis = Basis.IDENTITY if wrist_id == Origin.ORIGIN_RIGHT_WRIST else Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
	hand_rotation = reflection * hand_rotation * reflection
	var weapon_rotation: Basis = reflection * Basis.from_euler(Vector3(0.21, -0.38, 0.19)) * reflection
	var wrist: Vector3 = reflection * Vector3(2.3, -1.7, 4.1)
	var hand := Transform3D(common * hand_rotation * Basis.from_scale(Vector3(0.71, 0.89, 1.12)), wrist)
	var weapon := Transform3D(common * weapon_rotation * Basis.from_scale(Vector3(0.64, 0.81, 1.2)), wrist + common * reflection * Vector3(0.24, 0.13, -0.18))
	var tip_world: Vector3 = wrist + common * Vector3(0.0, 0.0, 2.0)
	var capture: Dictionary = _capture_fixture(wrist_id, hand)
	capture.roll_neutral_world_basis = common * Basis(Vector3.RIGHT, deg_to_rad(off_axis_swing)) * Basis(Vector3.BACK, deg_to_rad(offset)) * hand_rotation
	return {"capture": capture, "weapon": weapon, "tip": weapon.affine_inverse() * tip_world, "hand": hand}

func _capture_fixture(wrist_id: StringName, hand_world: Transform3D) -> Dictionary:
	# Same minimal registered frame contract as verify_combat_weapon_roll_resolver.
	var machine_to_world := Transform3D(Basis.from_euler(Vector3(-0.27, 0.61, 0.17)) * Basis.from_scale(Vector3(0.764, 0.91, 1.08)), Vector3(4.0, -2.0, 7.0))
	var registry = Registry.new()
	var record = Origin.new()
	record.origin_id = wrist_id
	record.parent_origin_id = Origin.ORIGIN_RL_BONE_ROOT
	record.transform_to_parent = machine_to_world.affine_inverse() * hand_world
	record.resolve_phase = Origin.PHASE_POST_FINAL_POSE
	record.owner_system = &"player_humanoid_rig"
	record.space_type = Origin.SPACE_TYPE_BONE_FRAME
	record.is_dynamic = true
	registry.register_origin(record)
	var registered = registry.get_origin(wrist_id)
	registered.resolved_transform_to_machine = registry.resolve_transform_to_machine(wrist_id)
	return {"available": true, "reason": &"ok", "wrist_origin_id": wrist_id,
		"hand_bone_name": &"CC_Base_R_Hand" if wrist_id == Origin.ORIGIN_RIGHT_WRIST else &"CC_Base_L_Hand",
		"origin_record": registered, "origin_chain": registry.resolve_chain(wrist_id),
		"origin_chain_ids": registry.validate_origin_chain(wrist_id)["chain_ids"],
		"registry": registry, "machine_to_world": machine_to_world}

func _transform_close(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < POSITION_TOLERANCE and a.basis.x.distance_to(b.basis.x) < POSITION_TOLERANCE and a.basis.y.distance_to(b.basis.y) < POSITION_TOLERANCE and a.basis.z.distance_to(b.basis.z) < POSITION_TOLERANCE
