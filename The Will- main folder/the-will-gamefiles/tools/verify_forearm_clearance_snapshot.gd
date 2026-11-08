extends SceneTree

const Snapshot = preload("res://runtime/player/combat_forearm_clearance_snapshot.gd")
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
var checks: Array[Dictionary] = []
var timings: Dictionary = {}
var out_dir := "C:/WORKSPACE/godot_runs/forearm_clearance_snapshot"

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			out_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	_geometry()
	_native_geometry_parity()
	await _real_rig()
	var failures: Array[Dictionary] = []
	for check: Dictionary in checks:
		if not check.passed:
			failures.append(check)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks": checks.size(), "failures": failures, "results": checks,
			"timings": timings, "backend": Snapshot.backend_stats()}, "\t"))
	print("Forearm clearance snapshot: %d checks, %d failures" % [checks.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)

func _geometry() -> void:
	var vertical := _capsule(Vector3(0, -2, 0), Vector3(0, 2, 0), 0.1)
	var crossing := _capsule(Vector3(-2, 0, 0), Vector3(2, 0, 0), 0.2)
	var contact: Dictionary = Snapshot.capsule_pair(vertical, crossing)
	_near(contact.clearance_meters, -0.3, "capsule_interior_crossing_detected")
	_check(contact.normal_world.is_finite() and absf(contact.normal_world.length() - 1.0) < 0.00001, "coincident_axes_have_finite_unit_normal")
	var parallel := _capsule(Vector3(0.5, -1, 0), Vector3(0.5, 1, 0), 0.2)
	contact = Snapshot.capsule_pair(vertical, parallel)
	_near(contact.clearance_meters, 0.2, "parallel_capsules_separation")
	_check(contact.normal_world.distance_to(Vector3.LEFT) < 0.00001, "normal_points_body_to_forearm")
	var point := _capsule(Vector3(0.5, 0, 0), Vector3(0.5, 0, 0), 0.2)
	_near(Snapshot.capsule_pair(vertical, point).clearance_meters, 0.2, "degenerate_capsule_sphere_distance")
	var half := Vector3.ONE
	var through := Snapshot.segment_box(Vector3(-3, 0, 0), Vector3(3, 0, 0), half)
	_near(through.signed_distance, -1.0, "whole_segment_crosses_box_despite_clear_endpoints")
	var near_edge := Snapshot.segment_box(Vector3(-3, 2, 0), Vector3(3, 2, 0), half)
	_near(near_edge.signed_distance, 1.0, "segment_box_parallel_edge_gap")
	var corner := Snapshot.segment_box(Vector3(2, 2, 0), Vector3(2, 2, 0), half)
	_near(corner.signed_distance, sqrt(2.0), "segment_box_corner_gap")
	var boundary := Snapshot.segment_box(Vector3(-3, 1, 0), Vector3(3, 1, 0), half)
	_near(boundary.signed_distance, 0.0, "segment_box_tangent_boundary")
	var box := {"frame": Transform3D.IDENTITY, "half_size": half}
	_near(Snapshot.capsule_box(crossing, box).clearance_meters, -1.2, "capsule_box_radius_applied_to_full_segment")
	var shifted := _capsule(Vector3(-3, 1.3, 0), Vector3(3, 1.3, 0), 0.2)
	_near(Snapshot.capsule_box(shifted, box).clearance_meters, 0.1, "capsule_box_finite_radius_separation")
	var rotation := Basis(Vector3(1, 2, 3).normalized(), 0.71)
	var transform := Transform3D(rotation, Vector3(3, -2, 5))
	var rotated_capsule := _capsule(transform * shifted.start, transform * shifted.end, shifted.radius)
	_near(Snapshot.capsule_box(rotated_capsule, {"frame": transform, "half_size": half}).clearance_meters, 0.1, "oriented_box_matches_local_distance")
	# Fixed small randomized oracle: dense sampling must never find penetration
	# missed by the analytical whole-segment minimum. This is not a runtime sweep.
	var random := RandomNumberGenerator.new()
	random.seed = 90381
	for index: int in 24:
		var start := Vector3(random.randf_range(-3, 3), random.randf_range(-3, 3), random.randf_range(-3, 3))
		var end := Vector3(random.randf_range(-3, 3), random.randf_range(-3, 3), random.randf_range(-3, 3))
		var exact: Dictionary = Snapshot.segment_box(start, end, half)
		var sampled := INF
		for step: int in 1001:
			var position := start.lerp(end, float(step) / 1000.0)
			var d := position.abs() - half
			var outside := d.max(Vector3.ZERO).length()
			sampled = minf(sampled, outside + minf(maxf(d.x, maxf(d.y, d.z)), 0.0))
		_check(float(exact.signed_distance) <= sampled + 0.00001 and sampled - float(exact.signed_distance) <= start.distance_to(end) / 1000.0 + 0.00001,
			"segment_box_dense_oracle_%d" % index, {"exact": exact.signed_distance, "sampled": sampled})
	var forearm := {"region": "left_forearm", "bone_name": "CC_Base_L_Forearm", "end_bone_name": "CC_Base_L_Hand"}
	var chest := {"region": "torso_chest", "bone_name": "CC_Base_Spine02", "end_bone_name": ""}
	var upper := {"region": "left_upperarm", "bone_name": "CC_Base_L_Upperarm", "end_bone_name": "CC_Base_L_Forearm"}
	var opposite := {"region": "right_forearm", "bone_name": "CC_Base_R_Forearm", "end_bone_name": "CC_Base_R_Hand"}
	_check(not Snapshot._exempt(forearm, chest), "torso_has_no_legacy_40mm_slack")
	_check(Snapshot._exempt(forearm, upper), "connected_upperarm_exempt")
	_check(Snapshot._exempt(forearm, opposite), "opposite_forearm_exemption_preserved")

func _native_geometry_parity() -> void:
	_check(ClassDB.class_exists(&"CombatForearmClearanceKernel"), "native_forearm_kernel_registered")
	if not ClassDB.class_exists(&"CombatForearmClearanceKernel"):
		return
	Snapshot.configure_native_kernel(true)
	var random := RandomNumberGenerator.new()
	random.seed = 7613
	for index: int in 24:
		var body: Dictionary = {"bone_index": 1, "region": "torso_chest", "kind": "box",
			"bone_local_shape": Transform3D.IDENTITY, "half_size": Vector3(0.5, 0.7, 0.4)}
		if index % 2 == 0:
			body = {"bone_index": 1, "region": "torso_chest", "kind": "capsule",
				"bone_local_shape": Transform3D.IDENTITY, "radius": 0.4, "half_mid": 0.5}
		var snapshot := {"valid": true, "skeleton_world": Transform3D.IDENTITY, "normalization_meters": 0.01,
			"shapes": [{"bone_index": 0, "region": "left_forearm", "kind": "capsule", "bone_local_shape": Transform3D.IDENTITY,
				"radius": 0.1, "half_mid": 1.5}, body],
			"pairs": [{"forearm": 0, "body": 1, "reason": "FOREARM_CLEARANCE:left:chest"}]}
		var transform := Transform3D(Basis(Vector3(1, 2, 3).normalized(), random.randf_range(-PI, PI)),
			Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1), random.randf_range(-1, 1)))
		_assert_backend_parity(snapshot, [Transform3D.IDENTITY, transform], "synthetic_native_reference_%d" % index)
	# Interior crossing has legal endpoints but must remain penetrating natively.
	var box_snapshot := {"valid": true, "skeleton_world": Transform3D.IDENTITY, "normalization_meters": 0.01,
		"shapes": [{"bone_index": 0, "region": "left_forearm", "kind": "capsule", "bone_local_shape": Transform3D.IDENTITY,
			"radius": 0.1, "half_mid": 3.0}, {"bone_index": 1, "region": "torso_chest", "kind": "box",
			"bone_local_shape": Transform3D.IDENTITY, "half_size": Vector3.ONE}],
		"pairs": [{"forearm": 0, "body": 1, "reason": "FOREARM_CLEARANCE:left:chest"}]}
	_assert_backend_parity(box_snapshot, [Transform3D.IDENTITY, Transform3D.IDENTITY], "native_full_segment_box_crossing")

func _assert_backend_parity(snapshot: Dictionary, globals: Array, label: String) -> void:
	var reference: Dictionary = Snapshot.evaluate_reference(snapshot, globals)
	var native: Dictionary = Snapshot.evaluate(snapshot, globals)
	var prepared: Dictionary = Snapshot.prepare(snapshot)
	var fast: Dictionary = Snapshot.evaluate_constraints(prepared, globals)
	var fast_same: bool = bool(reference.get("valid", false)) and bool(fast.get("valid", false))
	if fast_same:
		fast_same = reference.constraint_reasons == fast.constraint_reasons and reference.constraints.size() == fast.constraints.size()
		if fast_same:
			for index: int in reference.constraints.size():
				fast_same = fast_same and absf(float(reference.constraints[index]) - float(fast.constraints[index])) < 0.0001
	_check(fast_same, label + "_prepared_constraint_only_parity", fast.get("reason", ""))
	var same := bool(reference.get("valid", false)) and bool(native.get("valid", false))
	var worst := 0.0
	if same:
		same = reference.constraint_reasons == native.constraint_reasons and reference.contacts.size() == native.contacts.size()
		if same:
			for index: int in reference.contacts.size():
				var a: Dictionary = reference.contacts[index]
				var b: Dictionary = native.contacts[index]
				worst = maxf(worst, absf(float(a.clearance_meters) - float(b.clearance_meters)))
				same = same and absf(float(reference.constraints[index]) - float(native.constraints[index])) < 0.0001
				for field: String in ["normal_world", "forearm_axis_point_world", "body_axis_point_world", "forearm_surface_world", "body_surface_world"]:
					same = same and (a[field] as Vector3).distance_to(b[field] as Vector3) < 0.00001
	_check(same and worst < 0.000001, label, {"worst_clearance_error_m": worst, "reference_reason": reference.get("reason", ""), "native_reason": native.get("reason", "")})

func _real_rig() -> void:
	var rig := RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose(&"Idle")
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in rig.find_children("*", "AnimationTree", true, false):
		(node as AnimationTree).active = false
	for node: Node in rig.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).stop(true)
	var skeleton: Skeleton3D = rig.skeleton
	var globals: Array[Transform3D] = []
	var locals: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count():
		globals.append(skeleton.get_bone_global_pose(index))
		locals.append(skeleton.get_bone_pose(index))
	var snapshot: Dictionary = Snapshot.capture(rig)
	_check(snapshot.get("valid", false), "real_named_proxy_capture", snapshot.get("reason", ""))
	if not snapshot.get("valid", false):
		rig.free()
		return
	var snapshot_bytes := _value_bytes(snapshot)
	var measured: Dictionary = Snapshot.evaluate(snapshot, globals)
	_check(measured.get("valid", false), "real_idle_evaluation_never_requires_collision_free_start", measured.get("reason", ""))
	if not measured.get("valid", false):
		rig.free()
		return
	var sides: Dictionary = {}
	for contact: Dictionary in measured.contacts:
		sides[contact.forearm_region] = true
	_check(sides.has("left_forearm") and sides.has("right_forearm"), "both_sides_have_constraint_rows")
	_check(measured.constraints.size() == snapshot.pairs.size() and measured.contacts.size() == snapshot.pairs.size(), "stable_pair_count_all_clearances_retained")
	var left_only: Dictionary = Snapshot.capture(rig, 0.01, [&"hand_left"])
	var only_left: Dictionary = Snapshot.evaluate(left_only, globals)
	var filtered: bool = bool(only_left.get("valid", false)) and (only_left.get("contacts", []) as Array).size() > 0
	for contact: Dictionary in only_left.get("contacts", []):
		filtered = filtered and contact.forearm_region == "left_forearm"
	_check(filtered, "active_slot_filter_keeps_only_requested_forearm_rows")
	_assert_backend_parity(snapshot, globals, "real_idle_native_reference_parity")
	for index: int in measured.constraints.size():
		_near(float(measured.constraints[index]), -float(measured.contacts[index].clearance_meters) / float(snapshot.normalization_meters), "normalized_constraint_%d" % index)
	var rotation := Basis(Vector3(2, -1, 3).normalized(), 0.83)
	for scale_value: float in [0.75, 1.0, 1.5]:
		var moved := snapshot.duplicate(true)
		var root_change := Transform3D(rotation.scaled(Vector3.ONE * scale_value), Vector3(-3, 5, 2))
		moved.skeleton_world = root_change * (snapshot.skeleton_world as Transform3D)
		var other: Dictionary = Snapshot.evaluate(moved, globals)
		_check(other.get("valid", false), "root_covariance_evaluates_%s" % scale_value)
		if not other.get("valid", false):
			continue
		var covariant := true
		var worst := 0.0
		for index: int in measured.contacts.size():
			var before: Dictionary = measured.contacts[index]
			var after: Dictionary = other.contacts[index]
			var error := absf(float(after.clearance_meters) - float(before.clearance_meters) * scale_value)
			worst = maxf(worst, error)
			covariant = covariant and error < 0.00005
			covariant = covariant and (after.forearm_axis_point_world as Vector3).distance_to(root_change * (before.forearm_axis_point_world as Vector3)) < 0.00005
		_check(covariant, "root_translation_rotation_scale_covariance_%s" % scale_value, {"worst_clearance_error_m": worst})
		_assert_backend_parity(moved, globals, "real_transformed_native_reference_%s" % scale_value)
	_check(snapshot_bytes == _value_bytes(snapshot), "evaluation_keeps_snapshot_values_immutable")
	var unchanged := true
	for index: int in skeleton.get_bone_count():
		unchanged = unchanged and locals[index].is_equal_approx(skeleton.get_bone_pose(index))
	_check(unchanged, "capture_and_evaluate_never_write_bones")
	var started := Time.get_ticks_usec()
	for _repeat: int in 100:
		Snapshot.evaluate_reference(snapshot, globals)
	timings["reference_100_batches_usec"] = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for _repeat: int in 100:
		Snapshot.evaluate(snapshot, globals)
	timings["selected_backend_100_batches_usec"] = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for _repeat: int in 100:
		Snapshot.evaluate_constraints(snapshot, globals)
	timings["prepared_constraints_100_batches_usec"] = Time.get_ticks_usec() - started
	timings["shape_count"] = snapshot.shapes.size()
	timings["pair_count"] = snapshot.pairs.size()
	rig.free()

func _value_bytes(snapshot: Dictionary) -> PackedByteArray:
	var values := snapshot.duplicate()
	values.erase("_prepared_native")
	return var_to_bytes(values)

func _capsule(start: Vector3, end: Vector3, radius: float) -> Dictionary:
	return {"kind": "capsule", "start": start, "end": end, "radius": radius, "fallback_axis": Vector3.RIGHT, "fallback_up": Vector3.FORWARD}

func _near(actual: float, expected: float, name: String) -> void:
	_check(absf(actual - expected) < 0.00001, name, {"actual": actual, "expected": expected})

func _check(passed: bool, name: String, detail: Variant = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
