extends SceneTree

const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const Owner = preload("res://runtime/player/grip/preview_grip_acquisition.gd")
const RigCapture = preload("res://runtime/player/grip/capture_grip_placement_stage.gd")
const Data = preload("res://runtime/player/grip/character_grip_data.gd")

class TestPlayer extends Node:
	var library: Resource
	func get_forge_wip_library_state() -> Resource: return library
	func set_ui_mode_enabled(_enabled: bool) -> void: pass

var _checks := 0
var _failures: Array[String] = []
var _measurements: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures.append(label)
		push_error(label)

func _run() -> void:
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not expected.begins_with("c:/workspace/") or expected != OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower():
		push_error("Requires isolated workspace user data"); quit(1); return
	Engine.max_fps = 60
	var source: Resource = load("user://forge/player_wip_library_state.tres")
	if source == null:
		push_error("Missing isolated saved weapon library"); quit(1); return
	var player := TestPlayer.new()
	player.library = source.duplicate(true)
	player.library.set("save_file_path", "C:/WORKSPACE/test_artifacts/live_grip_unused_save.tres")
	var chosen: Resource
	for wip: Resource in player.library.get("saved_wips"):
		if wip.get("forge_project_name") == "Star_Handle_Testing": chosen = wip
	if chosen == null:
		push_error("Missing Star_Handle_Testing"); quit(1); return
	root.add_child(player)
	var ui: Node = UIScene.instantiate()
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await process_frame
	ui.open_for(player, "Live prepared grip verification")
	_check(ui.open_saved_wip_with_hand_setup(chosen.get("wip_id"), &"hand_right", false, false), "open saved weapon")
	_check(ui.select_skill_slot(&"skill_slot_1", true), "select skill")
	var context: Dictionary = ui.preview_presenter._weapon_roll_context(ui.preview_subviewport)
	if context.is_empty():
		_check(false, "live preview context"); _finish(); return
	var owner: Node = context.actor.get_node_or_null(Owner.NODE_NAME)
	if owner == null:
		_check(false, "runtime owner attached"); _finish(); return
	_check(owner.owns(&"hand_right"), "new owner claims dominant hand")
	if not owner.owns(&"hand_right"):
		_measurements["data_error"] = owner.get("_data")
		ui.queue_free(); player.queue_free()
		await process_frame
		_finish(); return
	_check(not owner.owns(&"hand_left"), "unarmed hand stays separate")
	var initial: Dictionary = owner.status()
	_measurements["initial"] = initial
	await process_frame
	await process_frame
	if OS.get_environment("THE_WILL_GRIP_TRIGGER_PROBE_ONLY") == "1":
		await _probe_triggers(ui, owner, context)
		ui.close_ui()
		for frame: int in 5: await process_frame
		ui.queue_free(); player.queue_free()
		await process_frame
		_finish(); return
	if OS.get_environment("THE_WILL_GRIP_LIFECYCLE_ONLY") == "1":
		await _exercise_lifecycle(ui, owner, context)
		ui.close_ui()
		_check(not owner.owns(&"hand_right") and not owner.owns(&"hand_left"), "close releases both hands")
		ui.queue_free(); player.queue_free()
		await process_frame
		_finish(); return
	# Reacquisition comes through the real UI and cancels any first-position job.
	var motion: Resource = ui._get_active_motion_node()
	var previous_ratio: float = motion.get("grip_seat_slide_offset")
	var next_ratio: float = 0.55 if absf(previous_ratio - 0.55) > 0.001 else 0.45
	_check(ui.set_selected_motion_node_grip_seat_slide(next_ratio, false), "real handle-position edit")
	var changed: Dictionary = owner.status()
	_check(int(changed.get(&"hand_right", {}).get("serial", -1)) > int(initial.get(&"hand_right", {}).get("serial", -1)), "position change requests fresh seat")
	var current_serial: int = changed.get(&"hand_right", {}).get("serial", -1)
	_measurements["position_change"] = changed
	var deadline: int = Time.get_ticks_msec() + 1800000
	var next_print: int = 0
	var last_tick: int = Time.get_ticks_usec()
	var maximum_frame_ms := 0.0
	var frames := 0
	var state: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var now: int = Time.get_ticks_usec()
		maximum_frame_ms = maxf(maximum_frame_ms, float(now-last_tick)/1000.0)
		last_tick = now
		frames += 1
		state = owner.status().get(&"hand_right", {})
		if Time.get_ticks_msec() >= next_print:
			print("LIVE_GRIP_PROGRESS=" + JSON.stringify(state))
			next_print = Time.get_ticks_msec() + 15000
		if str(state.get("status", "")) in ["preview_applied", "unresolved", "unavailable"]: break
	_measurements["result"] = state
	_measurements["frames_while_solving"] = frames
	_measurements["maximum_frame_ms"] = maximum_frame_ms
	_check(state.get("serial", -2) == current_serial, "old position result never applied")
	_check(state.get("status") == "preview_applied", "new solver reaches live pose application")
	if state.get("status") == "preview_applied":
		var rig: Node3D = context.actor
		var skeleton: Skeleton3D = rig.get("skeleton")
		var bones: Array[Transform3D] = []
		for index: int in skeleton.get_bone_count(): bones.append(skeleton.get_bone_pose(index))
		var hand_name: StringName = &"CC_Base_R_Hand"
		var hand_index: int = skeleton.find_bone(hand_name)
		if hand_index < 0:
			for index: int in skeleton.get_bone_count():
				if str(skeleton.get_bone_name(index)).ends_with("R_Hand"): hand_index = index
		_check(hand_index >= 0, "right hand found")
		var capture: Dictionary = RigCapture.new().capture(rig, context.weapon, Data.load_for_actor(rig).anatomy, &"hand_right", &"live_applied", current_serial)
		_check(capture.get("valid", false), "actual rig capture after application")
		if capture.get("valid", false):
			var capture_path := "C:/WORKSPACE/test_artifacts/live_grip_applied_" + Time.get_datetime_string_from_system().replace(":", "-") + ".bin"
			var captured_file := FileAccess.open(capture_path, FileAccess.WRITE)
			captured_file.store_var(capture, false); captured_file.close()
			_measurements["actual_capture"] = capture_path
		var before_weapon: Transform3D = context.weapon.global_transform
		var hand_before: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index) if hand_index >= 0 else Transform3D.IDENTITY
		_check(ui.set_selected_motion_node_weapon_roll(float(motion.get("weapon_roll_degrees")) + 20.0, false), "Roll after new grip")
		await process_frame
		var hand_after: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index) if hand_index >= 0 else Transform3D.IDENTITY
		_check((before_weapon.affine_inverse()*hand_before).is_equal_approx(context.weapon.global_transform.affine_inverse()*hand_after), "Roll retains new hand-weapon relationship")
		for index: int in skeleton.get_bone_count():
			if index != hand_index: _check(skeleton.get_bone_pose(index).is_equal_approx(bones[index]), "Roll preserves other bone " + str(index))
		_check(owner.status().get(&"hand_right", {}).get("serial", -1) == current_serial, "Roll does not reacquire")
	ui.close_ui()
	_check(not owner.owns(&"hand_right"), "close releases grip owner")
	ui.queue_free(); player.queue_free()
	await process_frame
	_finish()

## Bounded investigation of the actual UI handoff, not a completed-grip test.
## No mocked worker result, saved candidate injection or live solver override.
func _probe_triggers(ui: Node, owner: Node, context: Dictionary) -> void:
	_measurements["scope"] = "trigger probe only; acquisition deliberately cancelled before completion"
	await _record_trigger_window("opening", ui, owner, context)
	_check(ui.reset_active_draft_to_baseline(), "Reset UI action")
	await _record_trigger_window("reset", ui, owner, context)
	var motion: Resource = ui._get_active_motion_node()
	var previous: float = motion.get("grip_seat_slide_offset")
	_check(ui.set_selected_motion_node_grip_seat_slide(0.55 if absf(previous - 0.55) > 0.001 else 0.45, false), "handle slider UI action")
	await _record_trigger_window("handle_position", ui, owner, context)
	_check(ui.set_selected_motion_node_weapon_roll(float(motion.get("weapon_roll_degrees")) + 20.0, false), "Roll UI action")
	await _record_trigger_window("roll", ui, owner, context)
	_check(ui.reset_active_draft_to_baseline(), "Reset after cancelled acquisition")
	await _record_trigger_window("reset_after_roll", ui, owner, context)
	motion = ui._get_active_motion_node()
	_check(ui.set_selected_motion_node_weapon_roll(float(motion.get("weapon_roll_degrees")) + 20.0, false), "Roll at baseline handle station")
	_check(ui.reset_active_draft_to_baseline(), "Reset cancelled acquisition without changing handle station")
	await _record_trigger_window("reset_after_roll_same_station", ui, owner, context)
	ui.grip_reacquire_button.pressed.emit()
	await _record_trigger_window("reacquire", ui, owner, context)

func _record_trigger_window(label: String, ui: Node, owner: Node, context: Dictionary) -> void:
	var skeleton: Skeleton3D = context.actor.get("skeleton")
	var digit_indices: Array[int] = []
	var before: Array[Quaternion] = []
	for name: StringName in preload("res://runtime/player/player_digit_hinge_rules.gd").get_finger_bone_names(&"hand_right"):
		var index := skeleton.find_bone(name)
		digit_indices.append(index)
		before.append(skeleton.get_bone_pose_rotation(index))
	var entry := {"immediate": owner.status(), "can_process": owner.can_process(),
		"is_processing": owner.is_processing(), "settle_ready": owner.get("_settle_ready"),
		"tree_paused": paused}
	var deadline := Time.get_ticks_msec() + 3000
	var largest_change := 0.0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for joint: int in digit_indices.size():
			largest_change = maxf(largest_change, before[joint].angle_to(skeleton.get_bone_pose_rotation(digit_indices[joint])))
	entry["after_three_seconds"] = owner.status()
	entry["maximum_digit_change_degrees"] = rad_to_deg(largest_change)
	entry["binding"] = context.actor.get_planar_grip_pose_state(&"hand_right")
	(entry["binding"] as Dictionary).erase("relationship_key")
	entry["ui_status_text"] = ui.grip_acquisition_label.text
	entry["ui_status_visible"] = ui.grip_acquisition_label.is_visible_in_tree()
	_measurements[label] = entry
	print("GRIP_TRIGGER_PROBE=" + label + " " + JSON.stringify(entry))

func _exercise_lifecycle(ui: Node, owner: Node, context: Dictionary) -> void:
	var initial: Dictionary = owner.status()
	var motion: Resource = ui._get_active_motion_node()
	_check(ui.set_selected_motion_node_weapon_roll(float(motion.get("weapon_roll_degrees")) + 20.0, false), "Roll works while solve pending")
	_check(owner.status().get(&"hand_right", {}).get("status") == "cancelled", "pending Roll cancels acquisition")
	var skeleton: Skeleton3D = context.actor.get("skeleton")
	var poses: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count(): poses.append(skeleton.get_bone_pose(index))
	var weapon_pose: Transform3D = context.weapon.global_transform
	for frame: int in 15: await process_frame
	_check(context.weapon.global_transform.is_equal_approx(weapon_pose), "cancelled completion preserves rolled weapon")
	for index: int in skeleton.get_bone_count():
		_check(skeleton.get_bone_pose(index).is_equal_approx(poses[index]), "cancelled completion preserves bone " + str(index))
	ui.grip_reacquire_button.pressed.emit()
	var restarted: Dictionary = owner.status()
	_check(restarted.get(&"hand_right", {}).get("serial", -1) > initial.get(&"hand_right", {}).get("serial", -1), "Reacquire action starts new transaction")
	_check(restarted.get(&"hand_right", {}).get("status") == "queued", "Reacquire queued")
	var primary_serial: int = restarted.get(&"hand_right", {}).get("serial", -1)
	_check(ui.set_selected_motion_node_two_hand_state(&"two_hand_two_hand", false), "support hand engagement")
	_check(not owner.owns(&"hand_left"), "support remains on existing route during primary-only cutover")
	_check(owner.status().get(&"hand_right", {}).get("serial", -1) == primary_serial, "support engagement retains primary request")
	_check(ui.set_selected_motion_node_secondary_grip_seat_slide(0.7, false), "support position edit")
	_check(not owner.owns(&"hand_left"), "support position does not start the deferred new support solver")
	_check(owner.status().get(&"hand_right", {}).get("serial", -1) == primary_serial, "support position leaves primary request intact")
	_check(ui.set_selected_motion_node_two_hand_state(&"two_hand_one_hand", false), "support release")
	_check(not owner.owns(&"hand_left"), "support release restores free hand route")
	var request: Dictionary = owner.get("_requests")[&"hand_right"].duplicate()
	var pivot := {"point_local": context.weapon.get_meta("preview_primary_grip_seat_local"), "origin_id": &"WeaponRootOrigin", "source": "preview_primary_grip_seat"}
	var capture: Dictionary = await owner._capture_realized(&"hand_right", request, pivot)
	_check(capture.get("valid", false), "final skeleton signal capture hook")
	var stamp: PackedByteArray = owner._realization_stamp()
	_check(not stamp.is_empty(), "actual pose assessment identity available")
	var hand_index: int = skeleton.find_bone("CC_Base_R_Hand")
	var previous_rotation: Quaternion = skeleton.get_bone_pose_rotation(hand_index)
	skeleton.set_bone_pose_rotation(hand_index, (previous_rotation * Quaternion(Vector3.RIGHT, 0.01)).normalized())
	_check(owner._realization_stamp() != stamp, "bone change without editor notification invalidates assessment identity")
	skeleton.set_bone_pose_rotation(hand_index, previous_rotation)
	_check(owner._realization_stamp() == stamp, "restored exact pose restores assessment identity")
	_measurements["lifecycle"] = owner.status()

func _finish() -> void:
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "measurements": _measurements}
	var path := "C:/WORKSPACE/test_artifacts/verify_live_prepared_grip_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("LIVE_GRIP_RESULT=" + path + " ok=" + str(report.ok))
	quit(0 if _failures.is_empty() else 1)
