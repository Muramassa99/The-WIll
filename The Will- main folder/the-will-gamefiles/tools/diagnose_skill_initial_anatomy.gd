extends "res://tools/diagnose_skill_crafter_weapon_motion_allocation.gd"

## Read-only anatomy audit of real Idle and the existing UI Reset/acquisition.
## --raw-idle-only=true --out=<fresh C:/WORKSPACE/godot_runs directory>
## Otherwise: --weapon=Broken_Balde_v1 --slot=skill_slot_3 --hands=R
## --elevations=0 --out=<fresh directory>. No Save/F. Optional --probe-motion=true
## adds two small live Pommel requests after the repeated Reset check.
const InitialRig = preload("res://scenes/player/player_humanoid_rig.tscn")
const InitialAdapter = preload("res://runtime/player/combat_independent_arm_motion_adapter.gd")
const InitialAllocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")

func _run_diagnostic() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	if String(options.get("raw-idle-only", "false")) != "true":
		await super._run_diagnostic()
		return
	output_dir = String(options.get("out", "")).replace("\\", "/").simplify_path()
	if not output_dir.to_lower().begins_with("c:/workspace/godot_runs/") or FileAccess.file_exists(output_dir.path_join("initial_anatomy.json")):
		push_error("Require fresh --out inside C:/WORKSPACE/godot_runs")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		quit(1)
		return
	var evidence: Dictionary = await _actual_idle_samples()
	_write_initial_report(evidence)
	quit(0 if evidence.get("available", false) else 1)

func _run_thrust(ui: CombatAnimationStationUI, side: String, _elevation: float) -> Dictionary:
	var source := ProjectSettings.globalize_path(PlayerForgeWipLibraryStateScript.DEFAULT_SAVE_FILE_PATH)
	var source_before := FileAccess.get_sha256(source)
	var evidence := {"complete": false, "scope": "Actual Idle, two real UI Resets, acquired snapshots; no fabricated neutral joints, Save, F, or source writes. Movement probes opt-in only.", "side": side}
	ui.set_meta("verification_skip_persistence", true)
	evidence["idle_source"] = await _actual_idle_samples()
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	if actor == null:
		return evidence.merged({"reason": "preview_actor_missing"})
	evidence["before_reset"] = _capture_initial_anatomy(actor)
	evidence["reset_called"] = ui.reset_active_draft_to_baseline()
	evidence["reset_frame"] = ui.get_meta("last_reset_baseline_frame", {})
	evidence["immediate_reset_return"] = _capture_initial_anatomy(actor)
	evidence["immediate_reset_scope"] = "Synchronous UI Reset return; refresh/acquisition may already have applied macro positioning. Independent Idle source is captured separately."
	evidence["readiness"] = await _await_recorded_reset_baseline(ui)
	evidence["after_acquisition"] = _capture_initial_anatomy(actor)
	var idle: Dictionary = evidence.idle_source.get("idle_frame_0", {})
	evidence["body_vs_idle"] = _compare_initial_body(idle, evidence.after_acquisition)
	evidence["status"] = ui.footer_status_label.text
	evidence["grip_readiness"] = _grip_readiness(ui, side)
	evidence["nodes_after_reset"] = _initial_node_snapshots(ui, idle, evidence.after_acquisition)
	# Reset again through the real UI. Do not restore a fixture skeleton or
	# manufacture a prepared pose: this is specifically a lifecycle comparison.
	var repeat := {"reset_called": ui.reset_active_draft_to_baseline()}
	repeat["immediate_return"] = _capture_initial_anatomy(actor)
	repeat["readiness"] = await _await_recorded_reset_baseline(ui)
	repeat["after_acquisition"] = _capture_initial_anatomy(actor)
	repeat["body_vs_idle"] = _compare_initial_body(idle, repeat.after_acquisition)
	repeat["body_vs_first_reset"] = _compare_initial_body(evidence.after_acquisition, repeat.after_acquisition)
	repeat["nodes"] = _initial_node_snapshots(ui, idle, repeat.after_acquisition)
	repeat["status"] = ui.footer_status_label.text
	evidence["repeat_reset"] = repeat
	if String(options.get("probe-motion", "false")) in ["true", "reach"] and repeat.readiness.get("ready", false):
		evidence["motion_probes"] = await _probe_initial_body_motion(ui, actor)
	evidence["source_sha256_before"] = source_before
	evidence["source_sha256_after"] = FileAccess.get_sha256(source)
	evidence["source_unchanged"] = evidence.source_sha256_before == evidence.source_sha256_after
	evidence["isolated_library_exists"] = FileAccess.file_exists(ui.active_wip_library.save_file_path)
	evidence["complete"] = evidence.source_unchanged and bool(evidence.readiness.get("ready", false)) and bool(repeat.readiness.get("ready", false))
	_write_initial_report(evidence)
	return evidence

func _initial_node_snapshots(ui: CombatAnimationStationUI, idle: Dictionary, current: Dictionary) -> Array:
	var draft: Resource = ui.call("_get_active_draft")
	var chain: Array = draft.get("motion_node_chain") if draft != null else []
	var result: Array = []
	for node: CombatAnimationMotionNode in chain:
		var pose: Dictionary = node.prepared_pose
		var names: Array = pose.get("bone_names", [])
		var bodies: Array = []
		var complete_arrays: bool = names.size() > 0
		for key: String in ["pose_positions", "pose_rotations", "pose_scales"]:
			complete_arrays = complete_arrays and pose.has(key) and pose[key].size() == names.size()
		if complete_arrays:
			for i: int in names.size():
				var rotation: Vector4 = pose.pose_rotations[i]
				var basis := Basis(Quaternion(rotation.x, rotation.y, rotation.z, rotation.w)).scaled(pose.pose_scales[i])
				bodies.append({"name": names[i], "local": Transform3D(basis, pose.pose_positions[i])})
		var capture := {"bones": bodies}
		result.append({"node_id": node.node_id, "locked_for_authoring": node.locked_for_authoring,
			"tip": node.tip_position_local, "pommel": node.pommel_position_local,
			"prepared_pose_keys": pose.keys(), "prepared_pose_signature": node.prepared_pose_signature,
			"snapshot_bone_count": names.size(), "snapshot_arrays_complete": complete_arrays,
			"body_vs_idle": _compare_initial_body(idle, capture),
			"body_vs_current": _compare_initial_body(current, capture)})
	return result

func _compare_initial_body(reference: Dictionary, actual: Dictionary) -> Dictionary:
	var expected: Dictionary = {}
	for entry: Dictionary in reference.get("bones", []):
		expected[String(entry.name)] = entry.local
	var rows: Array = []
	var missing: Array = []
	var max_position := 0.0
	var max_angle := 0.0
	var max_scale := 0.0
	var mismatch_count := 0
	for entry: Dictionary in actual.get("bones", []):
		var name := String(entry.name)
		if _initial_digit_bone(name):
			continue
		if not expected.has(name):
			missing.append(name)
			continue
		var baseline: Transform3D = expected[name]
		var measured: Transform3D = entry.local
		var position_error := baseline.origin.distance_to(measured.origin)
		var angle_error := rad_to_deg(_allocation_basis_error(baseline.basis, measured.basis))
		var scale_error := baseline.basis.get_scale().distance_to(measured.basis.get_scale())
		var within_tolerance := position_error <= 0.00005 and angle_error <= 0.025 and scale_error <= 0.000001
		if not within_tolerance:
			mismatch_count += 1
		max_position = maxf(max_position, position_error)
		max_angle = maxf(max_angle, angle_error)
		max_scale = maxf(max_scale, scale_error)
		rows.append({"bone_name": name, "position_error_m": position_error, "rotation_error_degrees": angle_error,
			"scale_error": scale_error, "within_existing_tolerance": within_tolerance})
	return {"all_match": not rows.is_empty() and missing.is_empty() and mismatch_count == 0,
		"compared_non_digit_bone_count": rows.size(), "mismatch_count": mismatch_count, "missing_reference_names": missing,
		"maximum_position_error_m": max_position, "maximum_rotation_error_degrees": max_angle,
		"maximum_scale_error": max_scale, "rows": rows,
		"space": "Named bone parent-local pose; finger phalanges excluded, hand and twist bones included."}

func _initial_digit_bone(name: String) -> bool:
	for part: String in ["_Thumb", "_Index", "_Mid", "_Ring", "_Pinky"]:
		if part in name:
			return true
	return false

func _probe_initial_body_motion(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig) -> Array:
	var result: Array = []
	# Normal UI requests. No solver settings or budgets are changed.
	# The reverse request uses the currently displayed position, as user input does.
	var steps: Array[Vector3] = [Vector3(0.02, 0, 0), Vector3(-0.02, 0, 0)]
	if String(options.get("probe-motion", "false")) == "reach":
		steps.clear()
		for direction: Vector3 in [Vector3.UP, Vector3.FORWARD, Vector3.BACK, Vector3.DOWN]:
			for _i: int in 10:
				steps.append(direction * 0.03)
	for delta: Vector3 in steps:
		var before := _capture_initial_anatomy(actor)
		var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
		var displayed: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", node)
		var target := displayed.pommel_position_local + delta
		var started := Time.get_ticks_usec()
		var changed := ui.set_selected_motion_node_pommel_position(target, false)
		var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
		var immediate := _capture_initial_anatomy(actor)
		await _wait_frames(3)
		var after := _capture_initial_anatomy(actor)
		result.append({"control": "pommel", "delta_local": delta, "changed": changed,
			"setter_ms": elapsed, "body_change": _compare_initial_body(before, immediate),
			"body_retained_after_three_frames": _compare_initial_body(immediate, after),
			"allocation": _live_allocation_details(ui, actor), "after": after})
		if elapsed > 3000.0:
			result.append({"stopped": "First synchronous request exceeded 3 seconds; skip remaining probe. No policy was modified."})
			break
	return result

func _actual_idle_samples() -> Dictionary:
	var actor := InitialRig.instantiate() as PlayerHumanoidRig
	root.add_child(actor)
	await _wait_frames(2)
	actor.set_authoring_preview_mode_enabled(true)
	actor.set_process(false)
	actor.set_physics_process(false)
	for tree: Node in actor.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	var evidence := {"available": actor.skeleton != null, "source": "PlayerHumanoidRig.reset_authoring_preview_baseline_pose(Idle), existing production owner; no neutral reseed."}
	if actor.skeleton != null:
		actor.reset_authoring_preview_baseline_pose(&"Idle")
		evidence["idle_frame_0"] = _capture_initial_anatomy(actor)
		var animation: Animation = actor.animation_player.get_animation("Idle")
		if animation != null:
			actor.animation_player.play("Idle", 0.0)
			actor.animation_player.seek(animation.length * 0.5, true)
			actor.animation_player.stop(true)
			actor.skeleton.force_update_all_bone_transforms()
			evidence["idle_half_clip"] = _capture_initial_anatomy(actor)
			evidence["idle_clip_length"] = animation.length
	actor.queue_free()
	await _wait_frames(2)
	return evidence

func _capture_initial_anatomy(actor: PlayerHumanoidRig) -> Dictionary:
	var skeleton: Skeleton3D = actor.skeleton
	skeleton.force_update_all_bone_transforms()
	var bones: Array = []
	for index: int in skeleton.get_bone_count():
		bones.append({"name": skeleton.get_bone_name(index), "parent": skeleton.get_bone_parent(index),
			"local": skeleton.get_bone_pose(index), "rest": skeleton.get_bone_rest(index), "global": skeleton.get_bone_global_pose(index)})
	var result := {"skeleton_world": skeleton.global_transform, "bones": bones, "arms": {},
		"method": "Measure actual transforms; common independent-hand adapter initializes/evaluates only. No allocation, commit, or grip derivation."}
	for side: String in ["R", "L"]:
		var slot: StringName = &"hand_right" if side == "R" else &"hand_left"
		var index := skeleton.find_bone("CC_Base_" + side + "_Hand")
		if index < 0:
			continue
		var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(index)
		var adapter = InitialAdapter.new()
		var initialized: Dictionary = adapter._initialize(actor, {"mode": "pose", "primary_slot": slot,
			"previous_weapon": hand, "target_weapon": hand, "contact_local": Vector3.ZERO,
			"hand_in_weapon_by_slot": {slot: Transform3D.IDENTITY}, "commit": false})
		var arm := {"initialized": initialized, "shoulder": actor.capture_shoulder_motion_start_state(slot),
			"wrist": actor.capture_wrist_motion_start_state(slot), "actual_elbow_bend_degrees": rad_to_deg(actor.capture_elbow_bend_radians(slot))}
		if initialized.get("valid", false):
			var evaluated: Dictionary = adapter._evaluate_kinematics(adapter.q)
			arm["q"] = adapter.q
			arm["lower"] = adapter.lower
			arm["upper"] = adapter.upper
			arm["joint_groups"] = adapter.groups
			arm["raw_diagnostics"] = InitialAllocator._initial_diagnostics(adapter.q, evaluated, adapter.lower, adapter.upper, PackedStringArray(adapter.groups))
			arm["raw_pose_legal"] = InitialAllocator._evaluation_valid(evaluated) and InitialAllocator._legal(adapter.q, evaluated, adapter.lower, adapter.upper)
			arm["start_allowance"] = adapter.start_allowance
			arm["constraints"] = evaluated.get("constraints", [])
			arm["constraint_names"] = evaluated.get("constraint_reasons", [])
			arm["evaluation_valid"] = evaluated.get("valid", false)
			arm["evaluation_reason"] = evaluated.get("reason", "")
			if evaluated.get("weapon_frame") is Transform3D:
				var evaluated_hand: Transform3D = evaluated.weapon_frame
				arm["measured_reconstruction_position_error_m"] = hand.origin.distance_to(evaluated_hand.origin)
				arm["measured_reconstruction_angle_error_degrees"] = rad_to_deg(_allocation_basis_error(hand.basis, evaluated_hand.basis))
		result.arms[side] = arm
	return result

func _write_initial_report(evidence: Dictionary) -> void:
	var file := FileAccess.open(output_dir.path_join("initial_anatomy.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_initial_json(evidence), "\t"))
		file.close()
	print("INITIAL_ANATOMY report=" + output_dir.path_join("initial_anatomy.json"))

func _initial_json(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Quaternion:
		return [value.x, value.y, value.z, value.w]
	if value is Basis:
		return [_initial_json(value.x), _initial_json(value.y), _initial_json(value.z)]
	if value is Transform3D:
		return {"basis": _initial_json(value.basis), "origin": _initial_json(value.origin)}
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[String(key)] = _initial_json(value[key])
		return result
	if value is Array or value is PackedFloat64Array or value is PackedFloat32Array or value is PackedInt32Array or value is PackedStringArray:
		var result := []
		for entry: Variant in value:
			result.append(_initial_json(entry))
		return result
	if value is float and not is_finite(value):
		return str(value)
	if value is Object:
		return str(value)
	return value
