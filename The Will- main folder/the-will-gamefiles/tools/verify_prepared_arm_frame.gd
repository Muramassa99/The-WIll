extends SceneTree

## Isolated data proof: the original 46-frame UI02 clip/trace supplies motion;
## the library supplies immutable layout only. A fresh real rig supplies actual
## initialized anatomical limits/neutrals. No weapon, acquisition or save runs.
const Resolver = preload("res://core/resolvers/combat_prepared_arm_frame_resolver.gd")
const Capture = preload("res://runtime/combat/combat_prepared_pose_capture.gd")
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
var checks: Dictionary = {}
var report: Dictionary = {}
var output := "C:/WORKSPACE/godot_runs/skill_transition_20261024/prepared_arm_frame_01.json"
var source_dir := "C:/WORKSPACE/godot_runs/skill_transition_20261024/stored_pose_action_02/results"
var source_hashes: Dictionary = {}
var rig: Node3D

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--source-dir="): source_dir = arg.trim_prefix("--source-dir=")
	if FileAccess.file_exists(output):
		push_error("Fresh --out path required")
		quit(2)
		return
	for name: String in ["profile_library.tres", "replica_solved_clip.json", "bones.jsonl"]:
		var path: String = source_dir.path_join(name)
		if not FileAccess.file_exists(path):
			_finish("missing_input_" + name)
			return
		source_hashes[path] = FileAccess.get_sha256(path)
	var library: Resource = ResourceLoader.load(source_dir.path_join("profile_library.tres"), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var layout: Dictionary = _find_layout(library)
	if layout.is_empty():
		_finish("missing_prepared_layout")
		return
	var clip: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_dir.path_join("replica_solved_clip.json")))
	var traces: Dictionary = _load_traces(source_dir.path_join("bones.jsonl"))
	if traces.size() < 5:
		_finish("missing_original_endpoint_traces")
		return
	var first_pose: Dictionary = _frame_pose(layout, clip, 0)
	var first_fk: Dictionary = Resolver.forward_kinematics(first_pose)
	if not first_fk.valid:
		_finish("invalid_input_fk")
		return
	var hand_index: int = first_pose.bone_names.find(&"CC_Base_R_Hand")
	var first_hand: Transform3D = _trace_hand_reference(traces[1], &"CC_Base_R_Hand")
	var mate: Transform3D = _weapon_frame(clip, 0).affine_inverse() * first_hand
	_expect(first_fk.transforms[hand_index].origin.distance_to(first_hand.origin) <= 0.000005, "stored_fk_matches_independent_original_hand_trace")
	# Initialize the same baseline as single-hand Skill Crafter. This creates
	# ordinary rig helpers but never provides an item or finger-grip target.
	rig = RigScene.instantiate() as Node3D
	root.add_child(rig)
	rig.set_process(false)
	rig.set_physics_process(false)
	var baseline := StringName(rig.get("default_animation_name"))
	rig.call("set_authoring_preview_mode_enabled", true, baseline)
	rig.call("reset_authoring_preview_baseline_pose", baseline)
	var skeleton: Skeleton3D = rig.get("skeleton") as Skeleton3D
	var reference: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RL_BoneRoot"))
	reference.basis = reference.basis.orthonormalized()
	var by_slot: Dictionary = Capture.capture_arm_constraints(rig, reference)
	var constraints: Dictionary = by_slot.get(&"hand_right", {})
	if not bool(constraints.get("valid", false)):
		report["constraints"] = _plain(constraints)
		_finish("actual_rig_constraints_unavailable")
		return
	report["constraints"] = _plain(constraints)
	report["constraint_source"] = "Fresh real rig, single-hand default animation at t=0; actual cached helper neutrals. Original trace lacked constraint cache."
	var endpoint_times: Array[float] = [0.0]
	for index: int in range(1, clip.motion_node_chain.size()):
		endpoint_times.append(endpoint_times[-1] + float(clip.motion_node_chain[index].transition_duration_seconds))
	var rows: Array[Dictionary] = []
	var all_valid := true
	var all_other_channels := true
	var all_endpoints := true
	var all_lengths := true
	var all_idempotent := true
	var previous_bend := Vector3.ZERO
	var max_bend_step := 0.0
	var max_error := 0.0
	var max_angle := 0.0
	var max_twist := 0.0
	var endpoint_count := 0
	var resolve_usec := 0
	var started: int = Time.get_ticks_usec()
	for frame: int in clip.baked_frame_times.size():
		var pose: Dictionary = _frame_pose(layout, clip, frame)
		var before: PackedByteArray = var_to_bytes(pose)
		var target: Transform3D = _weapon_frame(clip, frame) * mate
		var resolve_started: int = Time.get_ticks_usec()
		var result: Dictionary = Resolver.resolve(pose, target, constraints)
		resolve_usec += Time.get_ticks_usec() - resolve_started
		var row: Dictionary = {"frame": frame, "time": clip.baked_frame_times[frame], "result": _plain(result), "target_hand_reference": _plain(target)}
		all_other_channels = all_other_channels and var_to_bytes(pose) == before
		all_valid = all_valid and bool(result.get("valid", false))
		if bool(result.get("valid", false)):
			var corrected: Dictionary = pose.duplicate(true)
			corrected.pose_rotations = result.pose_rotations
			var globals: Array[Transform3D] = Resolver.forward_kinematics(corrected).transforms
			var original: Array[Transform3D] = Resolver.forward_kinematics(pose).transforms
			var allowed: Array[int] = []
			var frames: Dictionary = {}
			for name: StringName in [constraints.clavicle_bone, constraints.upperarm_bone, constraints.forearm_bone, constraints.hand_bone]:
				var index: int = pose.bone_names.find(name)
				allowed.append(index)
				frames[name] = globals[index]
			for index: int in pose.bone_names.size():
				if not allowed.has(index):
					all_other_channels = all_other_channels and corrected.pose_rotations[index] == pose.pose_rotations[index]
			for index: int in range(1, allowed.size()):
				var a: int = allowed[index - 1]
				var b: int = allowed[index]
				all_lengths = all_lengths and absf(globals[a].origin.distance_to(globals[b].origin) - original[a].origin.distance_to(original[b].origin)) <= 0.000005
			var repeat: Dictionary = Resolver.resolve(corrected, target, constraints)
			all_idempotent = all_idempotent and bool(repeat.get("valid", false)) and repeat.get("pose_rotations") == corrected.pose_rotations
			var bend: Vector3 = result.bend_normal_reference
			var bend_step: float = rad_to_deg(previous_bend.angle_to(bend)) if previous_bend.length_squared() > 0.0 else 0.0
			max_bend_step = maxf(max_bend_step, bend_step)
			previous_bend = bend
			row["bend_step_degrees"] = bend_step
			row["corrected_pose_rotations"] = _plain(corrected.pose_rotations)
			row["arm_global_frames_reference"] = _plain(frames)
			max_error = maxf(max_error, result.position_error_m)
			max_angle = maxf(max_angle, result.orientation_error_rad)
			max_twist = maxf(max_twist, result.wrist_twist_change_rad)
			for endpoint: int in endpoint_times.size():
				if absf(float(clip.baked_frame_times[frame]) - endpoint_times[endpoint]) <= 0.000001:
					endpoint_count += 1
					all_endpoints = all_endpoints and corrected.pose_rotations == pose.pose_rotations
					var independent_hand: Transform3D = _trace_hand_reference(traces[endpoint + 1], constraints.hand_bone)
					row["original_endpoint_trace_error_m"] = globals[hand_index].origin.distance_to(independent_hand.origin)
					all_endpoints = all_endpoints and float(row.original_endpoint_trace_error_m) <= 0.000005
		rows.append(row)
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	_expect(all_valid, "all_original_samples_realize_complete_hand_frame")
	_expect(all_other_channels, "inputs_and_all_nonarm_rotations_unchanged_including_fingers")
	_expect(all_lengths, "all_arm_segment_lengths_preserved")
	_expect(all_idempotent, "realized_frames_are_idempotent")
	_expect(all_endpoints and endpoint_count == endpoint_times.size(), "all_five_original_endpoints_retained_exactly")
	# This is a diagnostic threshold for a one-sample inversion, not an added
	# anatomical rule or a claim about visually acceptable animation speed.
	_expect(max_bend_step < 90.0, "no_adjacent_bend_normal_hemisphere_jump_in_this_fixture")
	var impossible: Transform3D = _weapon_frame(clip, 0) * mate
	impossible.origin += Vector3(100, 100, 100)
	_expect(not Resolver.resolve(first_pose, impossible, constraints).get("valid", true), "unreachable_request_is_rejected_without_target_clamping")
	var malformed: Dictionary = first_pose.duplicate(true)
	malformed.parent_indices[0] = 0
	_expect(not Resolver.resolve(malformed, first_hand, constraints).get("valid", true), "cyclic_layout_is_rejected")
	_test_invalid_inputs(first_pose, first_hand, constraints)
	_test_reference_and_target_variations(layout, clip, mate, constraints, endpoint_times)
	report.merge({"frames": rows, "frame_count": rows.size(), "endpoint_count": endpoint_count, "elapsed_ms_including_checks": elapsed_ms, "primary_resolve_calls": rows.size(), "primary_resolve_elapsed_ms": float(resolve_usec) / 1000.0, "max_position_error_m": max_error, "max_orientation_error_rad": max_angle, "max_wrist_twist_change_rad": max_twist, "max_adjacent_bend_step_degrees": max_bend_step, "source_dir": source_dir, "scope": "Same-grip right-hand original stored frames only. No acquisition/collision/CCD. Not a full roll-range, slide, reverse, support or entry certification."})
	_finish()

func _test_reference_and_target_variations(layout: Dictionary, clip: Dictionary, mate: Transform3D, constraints: Dictionary, endpoint_times: Array[float]) -> void:
	var transformation := Transform3D(Basis(Vector3(0.3, 0.7, 0.2).normalized(), deg_to_rad(37.0)), Vector3(0.37, -0.19, 0.43))
	var summaries: Dictionary = {}
	for mode: String in ["rigid_reference", "up_15mm_envelope", "right_10mm_envelope"]:
		var rows: Array[Dictionary] = []
		var all_valid := true
		var equivariant := true
		var max_rotation_error := 0.0
		var max_bend_step := 0.0
		var previous_bend := Vector3.ZERO
		var endpoint_unchanged := true
		for frame: int in clip.baked_frame_times.size():
			var time: float = float(clip.baked_frame_times[frame])
			var pose: Dictionary = _frame_pose(layout, clip, frame)
			var target: Transform3D = _weapon_frame(clip, frame) * mate
			var settings: Dictionary = constraints.duplicate(true)
			var baseline: Dictionary = {}
			var segment := 0
			while segment + 1 < endpoint_times.size() - 1 and time >= endpoint_times[segment + 1] - 0.000001:
				segment += 1
			var ratio: float = clampf((time - endpoint_times[segment]) / (endpoint_times[segment + 1] - endpoint_times[segment]), 0.0, 1.0)
			var is_endpoint: bool = ratio <= 0.000001 or ratio >= 0.999999
			if mode == "rigid_reference":
				baseline = Resolver.resolve(pose, target, constraints)
				for index: int in pose.parent_reference_transforms.size():
					pose.parent_reference_transforms[index] = transformation * pose.parent_reference_transforms[index]
				target = transformation * target
				settings.reference_up = transformation.basis * settings.reference_up
			else:
				var envelope: float = 0.0 if is_endpoint else sin(ratio * PI)
				target.origin += (Vector3.UP * 0.015 if mode == "up_15mm_envelope" else Vector3.RIGHT * 0.010) * envelope
			var result: Dictionary = Resolver.resolve(pose, target, settings)
			all_valid = all_valid and bool(result.get("valid", false))
			var row: Dictionary = {"frame": frame, "time": time, "result": _plain(result)}
			if bool(result.get("valid", false)):
				if is_endpoint:
					endpoint_unchanged = endpoint_unchanged and result.pose_rotations == pose.pose_rotations
				if mode == "rigid_reference":
					equivariant = equivariant and bool(baseline.get("valid", false))
					if bool(baseline.get("valid", false)):
						for index: int in result.pose_rotations.size():
							var a: Vector4 = baseline.pose_rotations[index]
							var b: Vector4 = result.pose_rotations[index]
							var delta: Quaternion = (Quaternion(a.x, a.y, a.z, a.w).inverse() * Quaternion(b.x, b.y, b.z, b.w)).normalized()
							var error: float = 2.0 * atan2(Vector3(delta.x, delta.y, delta.z).length(), absf(delta.w))
							max_rotation_error = maxf(max_rotation_error, error)
							equivariant = equivariant and error <= 0.00005
				var bend: Vector3 = result.bend_normal_reference
				var step: float = rad_to_deg(previous_bend.angle_to(bend)) if previous_bend.length_squared() > 0.0 else 0.0
				max_bend_step = maxf(max_bend_step, step)
				previous_bend = bend
				row["bend_step_degrees"] = step
			rows.append(row)
		_expect(all_valid, mode + "_all_frames_valid")
		_expect(endpoint_unchanged, mode + "_authored_endpoints_unchanged")
		_expect(max_bend_step < 90.0, mode + "_no_adjacent_bend_hemisphere_jump")
		if mode == "rigid_reference":
			_expect(equivariant, "rigid_reference_local_rotations_are_equivariant")
		summaries[mode] = {"frames": rows, "all_valid": all_valid, "max_local_rotation_error_rad": max_rotation_error, "max_adjacent_bend_step_degrees": max_bend_step}
	report["bounded_variations"] = summaries

func _test_invalid_inputs(pose: Dictionary, target: Transform3D, constraints: Dictionary) -> void:
	for mode: String in ["reflected", "nonuniform", "singular", "different_scale"]:
		var bad_target: Transform3D = target
		match mode:
			"reflected": bad_target.basis.x = -bad_target.basis.x
			"nonuniform": bad_target.basis.x *= 1.2
			"singular": bad_target.basis.x = Vector3.ZERO
			"different_scale": bad_target.basis = bad_target.basis.scaled(Vector3.ONE * 2.0)
		_expect(not Resolver.resolve(pose, bad_target, constraints).get("valid", true), mode + "_target_is_rejected")
	for mode: String in ["zero_quaternion", "nonfinite_position", "reflected_scale", "nonuniform_scale"]:
		var bad_pose: Dictionary = pose.duplicate(true)
		match mode:
			"zero_quaternion": bad_pose.pose_rotations[0] = Vector4.ZERO
			"nonfinite_position": bad_pose.pose_positions[0] = Vector3(INF, 0, 0)
			"reflected_scale": bad_pose.pose_scales[0] = Vector3(-1, 1, 1)
			"nonuniform_scale": bad_pose.pose_scales[0] = Vector3(1, 2, 1)
		_expect(not Resolver.resolve(bad_pose, target, constraints).get("valid", true), mode + "_pose_is_rejected")
	for mode: String in ["missing_reach", "nonfinite_limit", "reversed_range", "zero_twist_axis", "missing_helper_neutral"]:
		var bad_constraints: Dictionary = constraints.duplicate(true)
		match mode:
			"missing_reach": bad_constraints.erase("usable_reach_m")
			"nonfinite_limit": bad_constraints.shoulder_max_degrees = NAN
			"reversed_range": bad_constraints.elbow_min_degrees = bad_constraints.elbow_max_degrees + 1.0
			"zero_twist_axis": bad_constraints.limb_twist_axis = Vector3.ZERO
			"missing_helper_neutral": bad_constraints.twist_neutral_rotations.clear()
		_expect(not Resolver.resolve(pose, target, bad_constraints).get("valid", true), mode + "_constraint_is_rejected")
	var helper_pose: Dictionary = pose.duplicate(true)
	var helper_name: StringName = constraints.twist_chains[0][0]
	var index: int = pose.bone_names.find(helper_name)
	var rotation: Quaternion = constraints.twist_neutral_rotations[helper_name] * Quaternion(constraints.limb_twist_axis, PI)
	helper_pose.pose_rotations[index] = Vector4(rotation.x, rotation.y, rotation.z, rotation.w)
	_expect(not Resolver.resolve(helper_pose, target, constraints).get("valid", true), "helper_twist_over_existing_limit_is_rejected")

func _find_layout(library: Resource) -> Dictionary:
	if library == null: return {}
	for wip: Resource in library.get("saved_wips"):
		var station: Resource = wip.get("combat_animation_station_state")
		if station == null: continue
		for draft: Resource in station.get("skill_drafts"):
			if StringName(draft.get("draft_id")) != &"skill_slot_1_draft": continue
			for node: Resource in draft.get_action_motion_node_chain():
				var packet: Dictionary = node.get("prepared_pose")
				if not packet.is_empty(): return packet.duplicate(true)
	return {}

func _frame_pose(layout: Dictionary, clip: Dictionary, frame: int) -> Dictionary:
	var pose: Dictionary = layout.duplicate(true)
	pose.pose_positions = _vectors3(clip.baked_solved_upper_body_pose_positions[frame])
	pose.pose_rotations = _vectors4(clip.baked_solved_upper_body_pose_rotations[frame])
	pose.pose_scales = _vectors3(clip.baked_solved_upper_body_pose_scales[frame])
	return pose

func _weapon_frame(clip: Dictionary, frame: int) -> Transform3D:
	var q: Array = clip.baked_solved_weapon_rotations_reference_local[frame]
	return Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3]).normalized()).scaled(_v3(clip.baked_solved_weapon_scales_reference_local[frame])), _v3(clip.baked_solved_weapon_positions_reference_local[frame]))

func _load_traces(path: String) -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.strip_edges().is_empty(): continue
		var row: Variant = JSON.parse_string(line)
		if not row is Dictionary: continue
		var label: String = row.get("label", "")
		if label.begins_with("prepared_node_"):
			result[int(label.trim_prefix("prepared_node_"))] = row
	return result

func _trace_hand_reference(row: Dictionary, name: StringName) -> Transform3D:
	var reference := Transform3D.IDENTITY
	var hand := Transform3D.IDENTITY
	for bone: Dictionary in row.skeletons[0].bones:
		if bone.name == "RL_BoneRoot": reference = _trace_transform(bone.world_pose)
		if bone.name == String(name): hand = _trace_transform(bone.world_pose)
	reference.basis = reference.basis.orthonormalized()
	return reference.affine_inverse() * hand

func _trace_transform(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0], values[1], values[2]), Vector3(values[3], values[4], values[5]), Vector3(values[6], values[7], values[8])), Vector3(values[9], values[10], values[11]))

func _vectors3(values: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for value: Array in values: result.append(_v3(value))
	return result

func _vectors4(values: Array) -> PackedVector4Array:
	var result := PackedVector4Array()
	for value: Array in values: result.append(Vector4(value[0], value[1], value[2], value[3]))
	return result

func _v3(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _plain(value: Variant) -> Variant:
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Vector4 or value is Quaternion: return [value.x, value.y, value.z, value.w]
	if value is Transform3D: return [_plain(value.basis.x), _plain(value.basis.y), _plain(value.basis.z), _plain(value.origin)]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[String(key)] = _plain(value[key])
		return result
	if value is Array or value is PackedVector3Array or value is PackedVector4Array:
		var result: Array = []
		for item: Variant in value: result.append(_plain(item))
		return result
	return value

func _expect(passed: bool, name: String) -> void:
	checks[name] = passed

func _finish(reason: String = "") -> void:
	var ok: bool = reason.is_empty()
	for path: String in source_hashes:
		_expect(FileAccess.get_sha256(path) == source_hashes[path], "source_unchanged_" + path.get_file())
	for passed: bool in checks.values(): ok = ok and passed
	report.merge({"ok": ok, "reason": reason, "checks": checks, "source_hashes": source_hashes})
	if is_instance_valid(rig): rig.free()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify({"ok": ok, "reason": reason, "checks": checks, "out": output, "max_position_error_m": report.get("max_position_error_m"), "max_adjacent_bend_step_degrees": report.get("max_adjacent_bend_step_degrees")}))
	quit(0 if ok else 1)
