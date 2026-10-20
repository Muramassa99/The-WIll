extends "res://tools/diagnose_skill_crafter_elbow_correction.gd"

# Read-only solve-writer tracing around the established actual-asset R-L-R test.
# Setup/acquisition and screenshot waits are excluded. The usual samples remain
# authoritative for the rendered outcome; these rows locate the writer between.
var _trace_actor: PlayerHumanoidRig
var _trace_sk: Skeleton3D
var _trace_file: FileAccess
var _trace_side := ""
var _trace_slot: StringName
var _trace_capturing := false
var _trace_next_phase := "setup"
var _trace_next_step := 0
var _trace_rows := 0
var _trace_transition_rows := 0
var _trace_dropped := 0
var _trace_phase_counts: Dictionary = {}
var _trace_bone_indices: Dictionary = {}

func _run_thrust(ui: CombatAnimationStationUI, side: String, elevation: float) -> Dictionary:
	_trace_actor = _get_preview_actor(ui) as PlayerHumanoidRig
	_trace_sk = _trace_actor.get_node("JosieModel/Josie/Skeleton3D") as Skeleton3D
	_trace_side = side
	_trace_slot = &"hand_left" if side == "L" else &"hand_right"
	_trace_capturing = false
	_trace_next_phase = "setup"
	_trace_next_step = 0
	_trace_rows = 0
	_trace_transition_rows = 0
	_trace_dropped = 0
	_trace_phase_counts.clear()
	_trace_bone_indices.clear()
	for suffix: String in ["Clavicle", "Upperarm", "Forearm", "Hand", "UpperarmTwist01", "UpperarmTwist02", "ForearmTwist01", "ForearmTwist02"]:
		_trace_bone_indices[suffix] = _trace_sk.find_bone("CC_Base_%s_%s" % [side, suffix])
	var trace_name: String = "arm_solver_%s_pass_%d.jsonl" % [side, hand_pass_index]
	if elevation != 0.0 or float(options.get("lateral-factor", "0")) != 0.0 or options.has("elbow-steps") or options.has("elbow-seed") or String(options.get("elevations", "0,25")).split(",").size() > 1:
		trace_name = "arm_solver_%s_pass_%d_case_%d_elevation_%.3f.jsonl" % [side, hand_pass_index, correction_case_index + 1, elevation]
	_trace_file = FileAccess.open(output_dir.path_join(trace_name), FileAccess.WRITE)
	if _trace_file == null:
		return {"complete": false, "reason": "trace_file_open_failed"}
	# The inherited timer begins at acquisition after scene and starting-pose prep.
	if not options.has("settle-seconds"):
		options["settle-seconds"] = "10"
	var previous_sink: Callable = _trace_actor.authoring_arm_solver_trace_sink
	_trace_actor.authoring_arm_solver_trace_sink = _on_arm_solver_trace
	var result: Dictionary = await super._run_thrust(ui, side, elevation)
	_trace_capturing = false
	_trace_actor.authoring_arm_solver_trace_sink = previous_sink
	_trace_file.flush()
	_trace_file.close()
	_trace_file = null
	result["arm_solver_trace"] = {"file": trace_name, "rows": _trace_rows, "dropped_rows": _trace_dropped, "transition_counts": _trace_phase_counts.duplicate(true), "row_limit_per_transition": int(options.get("trace-transition-limit", "800")), "row_limit_per_pass": int(options.get("trace-pass-limit", "30000")), "setup_and_capture_waits_excluded": true}
	return result

func _record_stage(ui: CombatAnimationStationUI, sk: Skeleton3D, side: String, phase: String, extra: Dictionary = {}) -> void:
	_trace_capturing = false
	await super._record_stage(ui, sk, side, phase, extra)
	_trace_next_step = correction_step
	_trace_transition_rows = 0
	match phase:
		"initial", "extend":
			_trace_next_phase = "extend"
		"maximum_extension", "pull":
			_trace_next_phase = "pull"
		"retracted_before_release":
			_trace_next_phase = "retracted_held"
		"retracted_held", "elbow_correction":
			_trace_next_phase = "elbow_corrected_released" if correction_step == int(correction_case.get("expected_samples", 33)) - 1 else "elbow_correction"
		_:
			_trace_next_phase = "finished"
	var warmup: bool = hand_pass_index == 1 and String(options.get("warmup-first", "false")) == "true"
	_trace_capturing = _trace_next_phase != "finished" and (not warmup or String(options.get("trace-warmup", "false")) == "true")
	if _trace_capturing:
		_on_arm_solver_trace(&"capture_baseline", {"scope": &"capture", "slot_id": _trace_slot, "previous_phase": phase, "iteration": -1})

func _on_arm_solver_trace(event: StringName, details: Dictionary) -> void:
	if not _trace_capturing or _trace_file == null:
		return
	var slot: StringName = details.get("slot_id", StringName())
	if slot != StringName() and slot != _trace_slot:
		return
	var joint: String = String(details.get("joint_bone", ""))
	if not joint.is_empty() and not joint.begins_with("CC_Base_%s_" % _trace_side):
		return
	if _trace_transition_rows >= int(options.get("trace-transition-limit", "800")) or _trace_rows >= int(options.get("trace-pass-limit", "30000")):
		_trace_dropped += 1
		return
	var bones: Dictionary = {}
	for suffix: String in _trace_bone_indices:
		var index: int = _trace_bone_indices[suffix]
		if index < 0:
			continue
		var pose: Transform3D = _trace_sk.get_bone_global_pose(index)
		bones[suffix] = {"local_q": _trace_quat(_trace_sk.get_bone_pose_rotation(index)), "world_q": _trace_quat((_trace_sk.global_basis * pose.basis).orthonormalized().get_rotation_quaternion()), "world_p": _vec(_trace_sk.global_transform * pose.origin)}
	var target: Node3D = _trace_actor.left_hand_ik_target if _trace_side == "L" else _trace_actor.right_hand_ik_target
	var row: Dictionary = {"serial": _trace_rows, "ticks_usec": Time.get_ticks_usec(), "process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(), "side": _trace_side, "pass": hand_pass_index, "next_sample_step": _trace_next_step, "next_sample_phase": _trace_next_phase, "event": event, "details": _trace_json_value(details), "bones": bones, "actor_world_q": _trace_quat(_trace_actor.global_basis.orthonormalized().get_rotation_quaternion()), "hand_target_world": _vec(target.global_position) if target != null else null, "manual_roll_degrees": _trace_actor.call("_resolve_authoring_manual_upperarm_roll_degrees", _trace_slot), "twist_state": _trace_json_value(_trace_actor.authoring_limb_twist_distribution_state.get(_trace_slot, {}))}
	_trace_file.store_line(JSON.stringify(row))
	_trace_rows += 1
	_trace_transition_rows += 1
	var phase_key: String = "%d_%s" % [_trace_next_step, _trace_next_phase]
	_trace_phase_counts[phase_key] = int(_trace_phase_counts.get(phase_key, 0)) + 1
	if _trace_rows % 128 == 0:
		_trace_file.flush()

func _trace_quat(value: Quaternion) -> Array:
	return [value.x, value.y, value.z, value.w]

func _trace_json_value(value: Variant) -> Variant:
	if value is Vector3:
		return _vec(value)
	if value is Quaternion:
		return _trace_quat(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[String(key)] = _trace_json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_trace_json_value(entry))
		return result
	return value
