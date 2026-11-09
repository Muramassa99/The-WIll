extends SceneTree

## Real Unarmed station, fresh in-memory library. No Save/F or body-motion sweep.
## --out=<workspace output directory>; exits nonzero on a failed check.
const Library = preload("res://core/models/player_forge_wip_library_state.gd")
const Station = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")
const PreparedCapture = preload("res://runtime/combat/combat_prepared_pose_capture.gd")
const FingerControls = preload("res://runtime/combat/combat_empty_hand_finger_control.gd")
const FingerHinges = preload("res://runtime/player/player_digit_hinge_rules.gd")
const SLOTS: Array[StringName] = [&"hand_right", &"hand_left"]

class FakePlayer:
	extends Node
	var forge_wip_library_state: PlayerForgeWipLibraryState
	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state
	func set_ui_mode_enabled(_enabled: bool) -> void:
		pass

var _out := "C:/WORKSPACE/godot_runs/unarmed_empty_hand_fingers_20261108"
var _ui: CombatAnimationStationUI
var _player: FakePlayer
var _actor: PlayerHumanoidRig
var _skeleton: Skeleton3D
var _idle: Dictionary = {}
var _report: Dictionary = {"complete": false, "checks": [], "failures": [], "readiness": [],
	"scope": "Real Unarmed UI; both empty hands; local finger ownership, frame persistence, hand-proxy classification and endpoint recording. No Save/F or anatomical motion certification."}
var _finished := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6).replace("\\", "/").trim_suffix("/")
	if not _out.to_lower().begins_with("c:/workspace/") or DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("A writable workspace output directory is required.")
		quit(1)
		return
	create_timer(90.0).timeout.connect(func() -> void:
		if not _finished:
			_check(false, "run_timeout")
			_finish())
	var library: PlayerForgeWipLibraryState = Library.new()
	library.save_file_path = _out.path_join("fresh_unarmed_fixture.tres")
	_player = FakePlayer.new()
	_player.forge_wip_library_state = library
	root.add_child(_player)
	_ui = Station.instantiate() as CombatAnimationStationUI
	root.add_child(_ui)
	await _frames(2)
	_ui.open_for(_player, "Unarmed empty-hand fingers verification")
	await _frames(2)
	if not _require(_ui.select_unarmed_authoring(true, {"dominant_slot_id": &"hand_right", "use_two_hand": false}), "unarmed_open"):
		return
	await _frames(2)
	if not _require(_ui.select_skill_slot(&"skill_slot_2", true), "skill_slot_open"):
		return
	await _frames(2)
	if not _require(_ui.reset_active_draft_to_baseline(), "baseline_reset"):
		return
	_ui.select_motion_node(1)
	if not _require(await _wait_ready("baseline"), "baseline_ready"):
		return
	var preview_root := _ui.call("_get_preview_root") as Node3D
	_actor = preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as PlayerHumanoidRig
	if not _require(_actor != null and _actor.skeleton != null, "real_rig_available"):
		return
	_skeleton = _actor.skeleton
	var proxy := preview_root.get_meta("preview_held_item", null) as Node3D
	_check(proxy != null and bool(proxy.get_meta("unarmed_hand_proxy", false)), "unarmed_virtual_proxy_identified")
	var focus_ids: Array = _ui.call("_resolve_available_focus_ids")
	for slot: StringName in SLOTS:
		_idle[slot] = _actor.finger_grip_presenter.capture_default_open_finger_rotations(_skeleton, slot)
		if not _require(bool((_idle[slot] as Dictionary).get("valid", false)), String(slot) + "_fixed_idle_available"):
			return
		for focus: StringName in FingerControls.focus_ids(slot):
			_check(focus_ids.has(focus), "focus_available:" + String(focus))
		for index: int in FingerControls.DIGITS.size():
			await _apply_and_check(slot, FingerControls.DIGITS[index], 30.0 + float(index) * 30.0, "initial")

	# The authored non-primary hand gets a separate virtual contact source. It
	# must remain an empty hand, not become a weapon grip due to that proxy.
	var motion := _motion()
	var segment: Dictionary = _ui.preview_presenter.resolve_hand_proxy_authoring_segment_state(_ui.preview_subviewport, motion, &"hand_left")
	if _require(bool(segment.get("available", false)), "left_hand_segment_available"):
		var changed := _ui.set_selected_motion_node_hand_proxy_segment(&"hand_left", segment.tip_position_local,
			segment.pommel_position_local, false, false, false, true, false)
		_check(changed, "same_position_left_hand_proxy_authored")
		if not _require(await _wait_ready("authored_proxy"), "authored_proxy_ready"):
			return
		var slot_proxy := preview_root.get_node_or_null("HandAuthoringProxy_hand_left") as Node3D
		_check(slot_proxy != null and bool(slot_proxy.get_meta("hand_authoring_slot_proxy", false))
			and StringName(slot_proxy.get_meta("slot_id", StringName())) == &"hand_left", "authored_free_hand_proxy_metadata")
		await _apply_and_check(&"hand_left", &"index", 75.0, "after_hand_proxy")
		await _apply_and_check(&"hand_right", &"index", 45.0, "after_hand_proxy")
	else:
		return

	_ui.call("_refresh_preview_scene")
	if not _require(await _wait_ready("normal_refresh"), "normal_refresh_ready"):
		return
	for slot: StringName in SLOTS:
		for digit: StringName in FingerControls.DIGITS:
			var curls: Dictionary = FingerControls.get_curls(_motion(), slot)
			_check(curls.has(digit), "refresh_keeps_authored_value:" + String(slot) + ":" + String(digit))
			_check_finger(slot, digit, float(curls.get(digit, -1.0)), "after_refresh")

	var capture: Dictionary = {}
	for attempt: int in 8:
		capture = _ui.capture_selected_prepared_pose(false, true)
		if bool(capture.get("valid", false)) or capture.get("reason", "") != "prepared_pose_settling":
			break
		await _frames(3)
	_check(bool(capture.get("valid", false)), "endpoint_capture", capture)
	if not bool(capture.get("valid", false)):
		_record_raw_capture_failure()
	if bool(capture.get("valid", false)):
		motion = _motion()
		var names: Array = motion.prepared_pose.get("bone_names", [])
		var rotations: Array = motion.prepared_pose.get("pose_rotations", [])
		for slot: StringName in SLOTS:
			for digit: StringName in FingerControls.DIGITS:
				for rule: Dictionary in FingerHinges.get_chain_rules(slot, digit):
					var bone: StringName = rule.bone
					var at: int = names.find(bone)
					var error: float = INF
					if at >= 0 and at < rotations.size():
						var stored: Variant = rotations[at]
						var rotation: Quaternion = Quaternion(stored.x, stored.y, stored.z, stored.w) if stored is Vector4 else stored
						error = _angle(rotation, _skeleton.get_bone_pose_rotation(_skeleton.find_bone(String(bone))))
					_check(error <= 0.025, "recorded_finger_matches_visible:" + String(bone), {"error_degrees": error})
	_finish()

func _record_raw_capture_failure() -> void:
	# Preserve the producer's reason before the generic UI validator reduces
	# an invalid packet to missing_or_obsolete_prepared_pose. Read-only sampling.
	var context: Dictionary = _ui.preview_presenter.get_prepared_pose_capture_context(_ui.preview_subviewport, _motion(), false)
	var data: Dictionary = {"context_valid": context.get("valid", false), "context_reason": context.get("reason", ""),
		"wrist_measurements": {}, "wrist_calibrations": {}, "planar_grips": {}}
	for slot: StringName in SLOTS:
		data.wrist_measurements[slot] = _actor.capture_wrist_motion_start_state(slot)
		data.wrist_calibrations[slot] = _actor.capture_wrist_constraint_calibration(slot)
		data.planar_grips[slot] = _actor.get_planar_grip_pose_state(slot)
	if bool(context.get("valid", false)):
		var signature: String = String(context.get("context_signature", ""))
		data["presenter_capture"] = _ui.preview_presenter.capture_prepared_authoring_pose(context, signature)
		data["raw_capture_without_validation"] = PreparedCapture.capture(context.actor, context.weapon,
			context.dominant_slot, _ui.preview_presenter.SOLVED_REPLAY_ANCHOR_NODE_PATHS,
			context.support_enabled, signature, false)
	_report["capture_diagnostic"] = data

func _apply_and_check(slot: StringName, digit: StringName, degrees: float, phase: String) -> void:
	var before: Dictionary = _bone_poses()
	var accepted: bool = _ui.set_selected_motion_node_finger_curl(slot, digit, degrees)
	_check(accepted, "%s:%s:%s:accepted" % [phase, slot, digit])
	await _frames(3)
	_check_finger(slot, digit, degrees, phase)
	var allowed: Dictionary = {}
	for rule: Dictionary in FingerHinges.get_chain_rules(slot, digit):
		allowed[StringName(rule.bone)] = true
	var worst_angle := 0.0
	var worst_position := 0.0
	var worst_scale := 0.0
	var worst_bone := ""
	for index: int in _skeleton.get_bone_count():
		var bone := StringName(_skeleton.get_bone_name(index))
		var previous: Dictionary = before[bone]
		if not allowed.has(bone):
			var angle := _angle(previous.rotation, _skeleton.get_bone_pose_rotation(index))
			if angle > worst_angle:
				worst_angle = angle
				worst_bone = String(bone)
		worst_position = maxf(worst_position, (previous.position as Vector3).distance_to(_skeleton.get_bone_pose_position(index)))
		worst_scale = maxf(worst_scale, (previous.scale as Vector3).distance_to(_skeleton.get_bone_pose_scale(index)))
	_check(worst_angle <= 0.025 and worst_position <= 0.00005 and worst_scale <= 0.000001,
		"%s:%s:%s:all_unselected_bones_unchanged" % [phase, slot, digit],
		{"max_angle_degrees": worst_angle, "bone": worst_bone, "max_position_m": worst_position, "max_scale": worst_scale})

func _check_finger(slot: StringName, digit: StringName, degrees: float, phase: String) -> void:
	var curls: Dictionary = FingerControls.get_curls(_motion(), slot)
	_check(curls.has(digit) and absf(float(curls.get(digit, -1.0)) - degrees) <= 0.0001,
		"%s:%s:%s:authored_value" % [phase, slot, digit])
	var idle: Dictionary = _idle[slot]
	for rule: Dictionary in FingerHinges.get_chain_rules(slot, digit):
		var bone: StringName = rule.bone
		var reference: Quaternion = idle.rotations[bone]
		var joint_angle := lerpf(float(rule.open_degrees), float(rule.closed_degrees), degrees / 180.0)
		var expected := (reference * Quaternion((rule.hinge_axis_local as Vector3).normalized(), deg_to_rad(joint_angle))).normalized()
		var error := _angle(expected, _skeleton.get_bone_pose_rotation(_skeleton.find_bone(String(bone))))
		_check(error <= 0.025, "%s:visible_finger:%s" % [phase, bone], {"error_degrees": error})

func _bone_poses() -> Dictionary:
	var result: Dictionary = {}
	for index: int in _skeleton.get_bone_count():
		result[StringName(_skeleton.get_bone_name(index))] = {"rotation": _skeleton.get_bone_pose_rotation(index),
			"position": _skeleton.get_bone_pose_position(index), "scale": _skeleton.get_bone_pose_scale(index)}
	return result

func _angle(a: Quaternion, b: Quaternion) -> float:
	var q := (a.normalized().inverse() * b.normalized()).normalized()
	return rad_to_deg(2.0 * atan2(Vector3(q.x, q.y, q.z).length(), absf(q.w)))

func _motion() -> CombatAnimationMotionNode:
	return _ui.call("_get_active_motion_node") as CombatAnimationMotionNode

func _wait_ready(phase: String) -> bool:
	var started: int = Time.get_ticks_msec()
	var stable := 0
	while Time.get_ticks_msec() - started < 30000 and not _finished:
		var ready: bool = not _ui.is_motion_node_recording_pending() \
			and not _ui.preview_presenter.is_grip_acquisition_pending(_ui.preview_subviewport) \
			and not _ui.preview_drag_refresh_pending and _motion() != null
		stable = stable + 1 if ready else 0
		if stable >= 3:
			_report.readiness.append({"phase": phase, "ready": true, "wait_ms": Time.get_ticks_msec() - started})
			return true
		await process_frame
	_report.readiness.append({"phase": phase, "ready": false, "wait_ms": Time.get_ticks_msec() - started})
	return false

func _frames(count: int) -> void:
	for index: int in count:
		await process_frame

func _require(passed: bool, name: String) -> bool:
	_check(passed, name)
	if not passed:
		_finish()
	return passed

func _check(passed: bool, name: String, details: Dictionary = {}) -> void:
	_report.checks.append({"passed": passed, "name": name, "details": details})
	if not passed:
		_report.failures.append(name)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_report.complete = true
	var file := FileAccess.open(_out.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
	print("UNARMED_EMPTY_HAND_FINGERS checks=%d failures=%d report=%s" % [_report.checks.size(), _report.failures.size(), _out])
	if is_instance_valid(_ui):
		_ui.queue_free()
	if is_instance_valid(_player):
		_player.queue_free()
	quit(0 if _report.failures.is_empty() else 1)
