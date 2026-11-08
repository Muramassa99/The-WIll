extends "res://tools/verify_motion_native_performance.gd"

## Focused real-body clearance exercise, separate from the backend parity run.
## The deterministic setup samples the actual arm's bounded FK coordinates;
## it is not claimed to be a pose acquired through the editor or finger solver.
const Clearance = preload("res://runtime/player/combat_forearm_clearance_snapshot.gd")
var setup_records: Array[Dictionary] = []
var comparison_report: Dictionary = {}

func _initialize() -> void:
	output_dir = "C:/WORKSPACE/godot_runs/motion_body_clearance_20261108"
	super._initialize()
	clearance_enabled = true
	commit_enabled = true

func _run() -> void:
	if ResourceLoader.exists(BACKEND_PATH):
		backend = load(BACKEND_PATH) as Script
		backend.call("configure_native", native_enabled)
		backend.call("configure_profiling", true)
	Clearance.configure_native_kernel(native_enabled)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose()
	rig.set_process(false)
	rig.set_physics_process(false)
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	skeleton = rig.skeleton
	_check(skeleton != null, "actual_josie_skeleton_present")
	if skeleton == null:
		_finish()
		return
	fixture = _capture_fixture()
	if not comparison_path.is_empty():
		comparison_report = _read_binary(comparison_path)
		_check(not comparison_report.is_empty(), "clearance_comparison_report_present")
	for side: String in ["R", "L"]:
		_run_clearance_side(side)
	fixture["clearance_setup"] = setup_records
	if not comparison_report.is_empty():
		_check(comparison_report.get("fixture_sha256", "") == _digest(fixture), "clearance_comparison_identical_fixture_and_calibration")
	_finish()

func _request_for(slot: StringName, prop: Node3D, binding: Transform3D, target: Transform3D) -> Dictionary:
	return {"mode": "pommel", "weapon": prop, "primary_slot": slot, "support_slot": StringName(),
		"previous_weapon": prop.global_transform, "target_weapon": target, "contact_local": Vector3.ZERO,
		"hand_in_weapon_by_slot": {slot: binding}, "commit": true,
		"policy": {"forearm_clearance_enabled": true, "trace_evaluation_phases": true,
			"cached_storage_readback": cached_storage}}

func _run_clearance_side(side: String) -> void:
	_restore_fixture()
	var slot := &"hand_right" if side == "R" else &"hand_left"
	var hand := _bone_world("CC_Base_" + side + "_Hand")
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = hand * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var binding := prop.global_transform.affine_inverse() * hand
	var setup := Adapter.new()
	var initialized: Dictionary = setup._initialize(rig, _request_for(slot, prop, binding, prop.global_transform))
	_check(bool(initialized.get("valid", false)), side + "_clearance_setup_initializes", initialized)
	if not initialized.get("valid", false):
		prop.free()
		return
	var selected := _find_chest_fixture(setup, slot)
	_check(not selected.is_empty(), side + "_legal_near_chest_fixture_found", {"candidate_count": 1029})
	if selected.is_empty():
		prop.free()
		return
	var opposite := _opposite_arm_world_poses(slot)
	setup._commit((selected.evaluation.payload as Dictionary).duplicate(true), selected.evaluation.weapon_frame)
	_check_committed_contact(side + "_setup", slot, prop, binding, opposite)
	setup_records.append({"side": side, "source": "actual_Idle_fixed_reference_FK_grid", "q": selected.q,
		"clearance_meters": selected.contact.clearance_meters, "contact": selected.contact,
		"profile": setup.arms[0].shoulder_profile, "calibration": setup.arms[0].shoulder_calibration})
	# Each request begins at the preceding committed result, with the same
	# acquired Hand/prop binding. Recovery never captures a new contact offset.
	for phase: String in ["approach", "tangent", "outward"]:
		var snapshot: Dictionary = Clearance.capture(rig)
		var contact := _chest_contact(snapshot, _actual_globals(), slot)
		_check(not contact.is_empty(), side + "_" + phase + "_chest_pair_present")
		if contact.is_empty():
			break
		var normal: Vector3 = contact.normal_world
		var direction := -normal
		var distance := 0.04
		if phase == "outward":
			direction = normal
			distance = 0.02
		elif phase == "tangent":
			var chest_up := _bone_world("CC_Base_Spine02").basis.y.normalized()
			direction = chest_up - normal * chest_up.dot(normal)
			if direction.length_squared() < 0.0001:
				direction = normal.cross(_bone_world("CC_Base_Spine02").basis.x.normalized())
			direction = direction.normalized()
			distance = 0.02
		_run_clearance_request(side + "_" + phase, phase, slot, prop, binding, direction * distance, contact)
	prop.free()

func _find_chest_fixture(adapter: RefCounted, slot: StringName) -> Dictionary:
	var arm: Dictionary = adapter.arms[0]
	var best: Dictionary = {}
	var best_clearance := INF
	# Three actual material-frame shoulder coordinates and the elbow hinge.
	# No rest transforms, bone lengths, limits or fixed zeros are modified.
	for swing_x: float in [-90.0, -60.0, -30.0, 0.0, 30.0, 60.0, 90.0]:
		for swing_z: float in [-90.0, -60.0, -30.0, 0.0, 30.0, 60.0, 90.0]:
			for roll: float in [-45.0, 0.0, 45.0]:
				for flexion: float in [30.0, 45.0, 60.0, 75.0, 90.0, 105.0, 120.0]:
					var values: PackedFloat64Array = adapter.q.duplicate()
					values[arm.shoulder_q] = deg_to_rad(swing_x)
					values[arm.shoulder_q + 1] = deg_to_rad(swing_z)
					values[arm.shoulder_q + 2] = deg_to_rad(roll)
					values[arm.elbow_q] = deg_to_rad(flexion)
					var evaluation: Dictionary = adapter._evaluate_kinematics(values)
					var effective: Dictionary = Allocator.apply_start_allowance(evaluation, adapter.start_allowance)
					if not Allocator._legal(values, effective, adapter.start_allowance.lower, adapter.start_allowance.upper):
						continue
					var contact := _chest_contact(adapter.forearm_clearance_snapshot, evaluation.payload.globals, slot)
					if contact.is_empty():
						continue
					var clearance: float = contact.clearance_meters
					if clearance >= 0.0 and clearance < best_clearance and clearance < 0.025:
						best_clearance = clearance
						best = {"q": values, "evaluation": evaluation, "contact": contact}
	return best

func _run_clearance_request(id: String, phase: String, slot: StringName, prop: Node3D, binding: Transform3D, displacement: Vector3, contact_before: Dictionary) -> void:
	var previous := prop.global_transform
	var target := previous
	target.origin += displacement
	var opposite := _opposite_arm_world_poses(slot)
	var adapter := Adapter.new()
	var request := _request_for(slot, prop, binding, target)
	var started := Time.get_ticks_usec()
	var result: Dictionary = adapter.allocate(rig, request)
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	var actual_delta := prop.global_position - previous.origin
	var contact_after := _chest_contact(Clearance.capture(rig), _actual_globals(), slot)
	var valid: bool = bool(result.get("valid", false)) and String(result.get("status", "")) in ["ACCEPTED", "SCALED"]
	_check(valid, id + "_allocator_accepts", {"status": result.get("status"), "reason": result.get("reason"), "task_scale": result.get("task_scale")})
	_check_committed_contact(id, slot, prop, binding, opposite)
	var evaluation: Dictionary = adapter._evaluate_kinematics(PackedFloat64Array(result.get("accepted_q", adapter.q)))
	var effective := Allocator.apply_start_allowance(evaluation, adapter.start_allowance)
	_check(Allocator._legal(PackedFloat64Array(result.get("accepted_q", adapter.q)), effective, adapter.start_allowance.lower, adapter.start_allowance.upper), id + "_original_limits_and_clearance_allowance_preserved")
	var progress := actual_delta.dot(displacement.normalized())
	if phase in ["tangent", "outward"]:
		_check(progress > 0.0002, id + "_meaningful_directional_progress", {"progress_m": progress, "actual_delta": actual_delta})
	if not contact_after.is_empty():
		_check(float(contact_after.clearance_meters) >= minf(float(contact_before.clearance_meters), 0.0) - 0.00005, id + "_chest_overlap_not_worsened", {"before_m": contact_before.clearance_meters, "after_m": contact_after.clearance_meters})
		if phase == "outward":
			_check(float(contact_after.clearance_meters) > float(contact_before.clearance_meters) + 0.0001, id + "_outward_increases_chest_clearance")
	var compact := result.duplicate()
	for key: String in ["motion_adapter", "accepted_payload", "accepted_pose"]:
		compact.erase(key)
	var record := {"id": id, "elapsed_ms": elapsed, "result": compact, "actual_delta": actual_delta,
		"requested_displacement": displacement, "directional_progress_m": progress,
		"before": contact_before, "after": contact_after, "timings": adapter._timing_result(),
		"accepted_evaluation": _evaluation_snapshot(evaluation)}
	if not comparison_report.is_empty():
		var reference := _find_record(comparison_report, id)
		_check(not reference.is_empty(), id + "_clearance_comparison_reference_present")
		if not reference.is_empty():
			var q_error := _array_error(reference.result.accepted_q, result.accepted_q)
			var position_error: float = (reference.actual_delta as Vector3).distance_to(actual_delta)
			var clearance_error := absf(float(reference.after.get("clearance_meters", INF)) - float(contact_after.get("clearance_meters", -INF)))
			var same_outcome: bool = reference.result.get("status") == result.get("status") and reference.result.get("reason") == result.get("reason")
			var scale_error := absf(float(reference.result.get("task_scale", 0.0)) - float(result.get("task_scale", 0.0)))
			var constraints_error := 0.0
			if reference.has("accepted_evaluation"):
				constraints_error = _array_error(reference.accepted_evaluation.constraints, evaluation.constraints)
			var equivalent: bool = same_outcome and reference.requested_displacement == displacement and scale_error <= 0.000001 \
				and q_error <= COMPARE_Q_RADIANS and position_error <= COMPARE_POSITION_M \
				and clearance_error <= COMPARE_POSITION_M and constraints_error <= COMPARE_CONSTRAINT
			record["comparison"] = {"equivalent": equivalent, "q_max_error_radians": q_error, "position_error_m": position_error,
				"clearance_error_m": clearance_error, "constraints_error": constraints_error,
				"baseline_elapsed_ms": reference.elapsed_ms, "current_elapsed_ms": elapsed}
			_check(equivalent, id + "_numeric_comparison_preserves_clearance_outcome", record.comparison)
	records.append(record)
	print("BODY_CLEARANCE %s status=%s progress_mm=%.3f elapsed_ms=%.3f" % [id, result.get("status"), progress * 1000.0, elapsed])

func _chest_contact(snapshot: Dictionary, globals: Array, slot: StringName) -> Dictionary:
	var evaluated: Dictionary = Clearance.evaluate(snapshot, globals)
	if not evaluated.get("valid", false):
		return {}
	var region := "right_forearm" if slot == &"hand_right" else "left_forearm"
	for contact: Dictionary in evaluated.get("contacts", []):
		if contact.get("forearm_region") == region and contact.get("body_region") == "torso_chest":
			return contact
	return {}

func _actual_globals() -> Array[Transform3D]:
	skeleton.force_update_all_bone_transforms()
	var result: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count():
		result.append(skeleton.get_bone_global_pose(index))
	return result
