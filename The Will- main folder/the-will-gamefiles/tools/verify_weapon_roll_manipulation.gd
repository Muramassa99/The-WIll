extends SceneTree

const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const Origin = preload("res://core/models/combat_origin_record.gd")
const DATA_PATH = "user://forge/player_wip_library_state.tres"
const TEST_SAVE_PATH = "C:/WORKSPACE/test_artifacts/weapon_roll_manipulation_2026-09-15_library.tres"

class TestPlayer:
	extends Node
	var library: Resource
	func get_forge_wip_library_state() -> Resource:
		return library
	func set_ui_mode_enabled(_enabled: bool) -> void:
		pass

var failures: PackedStringArray = []
var checks: int = 0
var measurements: Array = []

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _run() -> void:
	var source: Resource = load(DATA_PATH)
	if source == null:
		print("ROLL_MANIPULATION_RESULT=missing_saved_library")
		quit(1)
		return
	var library: Resource = source.duplicate(true)
	library.set("save_file_path", TEST_SAVE_PATH)
	var chosen: Resource = null
	for wip: Resource in library.get("saved_wips"):
		if String(wip.get("forge_project_name")) == "Star_Handle_Testing":
			chosen = wip
	if chosen == null:
		print("ROLL_MANIPULATION_RESULT=missing_Star_Handle_Testing")
		quit(1)
		return
	var player := TestPlayer.new()
	player.library = library
	root.add_child(player)
	var ui = UIScene.instantiate()
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await process_frame
	ui.open_for(player, "Roll manipulation verifier")
	for slot: StringName in [&"hand_right", &"hand_left"]:
		print("ROLL_MANIPULATION_CHECKING=" + String(slot))
		_check(ui.open_saved_wip_with_hand_setup(chosen.get("wip_id"), slot, false, false), "%s open" % slot)
		_check(ui.select_skill_slot(&"skill_slot_1", true), "%s select slot" % slot)
		await process_frame
		await process_frame
		ui.session_state.current_focus = &"weapon"
		ui.call("_refresh_preview_scene")
		var context: Dictionary = ui.preview_presenter.call("_weapon_roll_context", ui.preview_subviewport)
		if context.is_empty():
			_check(false, "%s missing preview context" % slot)
			continue
		var motion: Resource = ui.call("_get_active_motion_node")
		var baseline: Dictionary = _sample(context, slot)
		var initial_roll: float = motion.get("weapon_roll_degrees")
		for delta_degrees: float in [30.0, -30.0, 90.0, 0.0, 30.0, 0.0]:
			var requested: float = initial_roll + delta_degrees
			var changed: bool = ui.set_selected_motion_node_weapon_roll(requested, false)
			_check(changed, "%s request %s accepted: %s" % [slot, requested, ui.footer_status_label.text])
			_check_lookup_scope_released(ui, "%s accepted numeric Roll" % slot)
			await process_frame
			var sample: Dictionary = _sample(context, slot)
			var wrist_error: float = baseline["hand"].origin.distance_to(sample["hand"].origin)
			var tip_error: float = baseline["tip"].distance_to(sample["tip"])
			var grip_before: Transform3D = baseline["weapon"].affine_inverse() * baseline["hand"]
			var grip_after: Transform3D = sample["weapon"].affine_inverse() * sample["hand"]
			var fixed_bones: bool = true
			for bone_index: int in range(sample["bones"].size()):
				if bone_index != sample["hand_index"] and not sample["bones"][bone_index].is_equal_approx(baseline["bones"][bone_index]):
					fixed_bones = false
			_check(wrist_error < 0.00001, "%s wrist fixed at %s" % [slot, requested])
			_check(tip_error < 0.00001, "%s Tip fixed at %s" % [slot, requested])
			_check(grip_after.is_equal_approx(grip_before), "%s rigid grip at %s" % [slot, requested])
			_check(fixed_bones, "%s all other bone poses unchanged at %s" % [slot, requested])
			_check(ui.preview_presenter.weapon_roll_manipulator.matches(context["actor"], context["weapon"], context["trajectory"], motion, slot), "%s retained pose after refresh" % slot)
			if is_zero_approx(delta_degrees):
				_check(sample["weapon"].is_equal_approx(baseline["weapon"]), "%s return to initial weapon frame" % slot)
			else:
				_check(sample["pommel"].distance_to(baseline["pommel"]) > 0.0001, "%s Pommel orbits" % slot)
			measurements.append({"slot": slot, "roll": requested, "wrist_error_m": wrist_error, "tip_error_m": tip_error, "other_bones_fixed": fixed_bones, "grip_fixed": grip_after.is_equal_approx(grip_before)})
			if DisplayServer.get_name() != "headless" and slot == &"hand_right" and (is_zero_approx(delta_degrees) or is_equal_approx(delta_degrees, 90.0)):
				await RenderingServer.frame_post_draw
				var capture: Image = ui.preview_subviewport.get_texture().get_image()
				_check(capture.save_png("C:/WORKSPACE/test_artifacts/weapon_roll_2026-09-15_%d.png" % int(delta_degrees)) == OK, "rendered Roll capture")
		_check(not ui.set_selected_motion_node_weapon_roll(initial_roll, false), "%s unchanged Roll is a no-op" % slot)
		_check_lookup_scope_released(ui, "%s unchanged numeric Roll" % slot)
		# Re-entering an unrelated refresh must not reopen the arm solve.
		ui.call("_refresh_preview_scene")
		_check(_sample(context, slot)["weapon"].is_equal_approx(baseline["weapon"]), "%s idle refresh retains pose" % slot)
		await _exercise_mouse(ui, context, motion, slot)
		_exercise_draft_switch(ui, slot)
	ui.queue_free()
	player.queue_free()
	await process_frame
	print("ROLL_MANIPULATION_RESULT=" + JSON.stringify({"checks": checks, "failures": failures, "measurements": measurements, "ok": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _exercise_mouse(ui: Node, context: Dictionary, motion: Resource, slot: StringName) -> void:
	ui.session_state.current_focus = &"weapon"
	var baseline: Dictionary = _sample(context, slot)
	var camera: Camera3D = ui.call("_get_preview_camera")
	var display: Resource = ui.call("_build_display_motion_node_for_viewport_pick", motion)
	var handle: Vector3 = ui.motion_node_editor.get_weapon_rotation_handle_local(display)
	var pointer: Vector2 = camera.unproject_position(context["trajectory"].to_global(handle))
	var initial_degrees: float = motion.get("weapon_roll_degrees")
	_mouse_button(ui, pointer, true)
	_check(ui.preview_weapon_roll_dragging, "%s green handle starts Roll" % slot)
	_check(_sample(context, slot)["weapon"].is_equal_approx(baseline["weapon"]), "%s press does not jump" % slot)
	var move := InputEventMouseMotion.new()
	move.position = pointer + Vector2(60.0, 0.0)
	move.relative = Vector2(60.0, 0.0)
	ui.call("_on_preview_gui_input", move)
	_check_lookup_scope_released(ui, "%s accepted mouse Roll" % slot)
	await process_frame
	_check(is_equal_approx(motion.get("weapon_roll_degrees"), initial_degrees + 30.0), "%s horizontal drag reaches +30 degrees" % slot)
	var dragged: Dictionary = _sample(context, slot)
	_check(dragged["hand"].origin.distance_to(baseline["hand"].origin) < 0.00001 and dragged["tip"].distance_to(baseline["tip"]) < 0.00001, "%s drag fixes wrist and Tip" % slot)
	_check(not bool(context["root"].get_meta("collision_pose_deferred", true)), "%s Roll collision diagnostics refreshed" % slot)
	_mouse_button(ui, move.position, false)
	_check_lookup_scope_released(ui, "%s accepted mouse release" % slot)
	await process_frame
	_check(not ui.preview_weapon_roll_dragging and not ui.motion_node_editor.is_dragging(), "%s release ends Roll" % slot)
	_check(_sample(context, slot)["weapon"].is_equal_approx(dragged["weapon"]), "%s release does not re-solve" % slot)
	# Invalid origin must fail without a pose write, and release must retain that failure.
	display = ui.call("_build_display_motion_node_for_viewport_pick", motion)
	pointer = camera.unproject_position(context["trajectory"].to_global(ui.motion_node_editor.get_weapon_rotation_handle_local(display)))
	_mouse_button(ui, pointer, true)
	context["weapon"].set_meta("weapon_tip_origin_id", &"InvalidVerifierOrigin")
	move.position = pointer + Vector2(20.0, 0.0)
	ui.call("_on_preview_gui_input", move)
	_check_lookup_scope_released(ui, "%s rejected mouse Roll" % slot)
	var rejection: String = ui.footer_status_label.text
	_check(rejection.begins_with("Weapon roll could not be applied:"), "%s invalid origin rejected" % slot)
	context["weapon"].set_meta("weapon_tip_origin_id", Origin.ORIGIN_WEAPON_ROOT)
	_mouse_button(ui, move.position, false)
	_check_lookup_scope_released(ui, "%s rejected mouse release" % slot)
	_check(ui.footer_status_label.text == rejection, "%s release preserves failure feedback" % slot)
	_check(_sample(context, slot)["weapon"].is_equal_approx(dragged["weapon"]), "%s rejected drag leaves pose unchanged" % slot)
	# Reset while a drag has no release must clear its special input mode.
	_mouse_button(ui, pointer, true)
	_check(ui.reset_active_draft_to_baseline(), "%s reset succeeds on test copy" % slot)
	_check(not ui.preview_weapon_roll_dragging and not ui.motion_node_editor.is_dragging(), "%s Reset clears Roll drag" % slot)

func _check_lookup_scope_released(ui: Node, label: String) -> void:
	_check(int(ui.get("preview_authoring_lookup_scope_depth")) == 0, label + " releases lookup depth")
	_check(ui.get("preview_authoring_lookup_station") == null, label + " releases station reference")
	_check((ui.get("preview_authoring_lookup_inputs") as Array).is_empty(), label + " releases lookup inputs")

func _exercise_draft_switch(ui: Node, slot: StringName) -> void:
	var previous_draft: Resource = ui.call("_get_active_draft")
	var selected: bool = ui.select_skill_slot(&"skill_slot_2", true)
	_check(selected, "%s select second draft" % slot)
	if not selected:
		return
	var next_draft: Resource = ui.call("_get_active_draft")
	var next_motion: Resource = ui.call("_get_active_motion_node")
	_check(next_draft != null and next_draft != previous_draft and next_motion != null, "%s lookup follows second draft" % slot)
	if previous_draft == null or next_draft == null or next_draft == previous_draft or next_motion == null:
		return
	var previous_chain: Array = previous_draft.get("motion_node_chain")
	var previous_states: Array[Dictionary] = []
	for previous_motion: Resource in previous_chain:
		previous_states.append(_motion_node_storage(previous_motion))
	var initial_roll: float = next_motion.get("weapon_roll_degrees")
	var requested_roll: float = initial_roll + (5.0 if initial_roll <= 115.0 else -5.0)
	_check(ui.set_selected_motion_node_weapon_roll(requested_roll, false), "%s second draft Roll accepted" % slot)
	_check_lookup_scope_released(ui, "%s second draft Roll" % slot)
	_check(is_equal_approx(float(next_motion.get("weapon_roll_degrees")), requested_roll), "%s Roll edits selected second node" % slot)
	_check(ui.call("_get_active_draft") == next_draft, "%s Roll retains second draft selection" % slot)
	var unchanged_previous_chain: Array = previous_draft.get("motion_node_chain")
	_check(unchanged_previous_chain.size() == previous_states.size(), "%s Roll preserves first draft node count" % slot)
	for index: int in range(mini(unchanged_previous_chain.size(), previous_states.size())):
		_check(_motion_node_storage(unchanged_previous_chain[index]) == previous_states[index], "%s Roll preserves first draft node %d" % [slot, index])

func _motion_node_storage(motion: Resource) -> Dictionary:
	var state: Dictionary = {}
	if motion == null:
		return state
	for property_info: Dictionary in motion.get_property_list():
		if (int(property_info.get("usage", 0)) & PROPERTY_USAGE_STORAGE) != 0:
			var property_name: StringName = StringName(property_info.get("name", ""))
			state[property_name] = motion.get(property_name)
	return state.duplicate(true)

func _mouse_button(ui: Node, pointer: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pointer
	event.pressed = pressed
	ui.call("_on_preview_gui_input", event)

func _sample(context: Dictionary, slot: StringName) -> Dictionary:
	var skeleton: Skeleton3D = context["actor"].get("skeleton") as Skeleton3D
	var weapon: Node3D = context["weapon"]
	var hand_index: int = skeleton.find_bone("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand")
	var bones: Array[Transform3D] = []
	for index: int in range(skeleton.get_bone_count()):
		bones.append(skeleton.get_bone_pose(index))
	return {"hand": skeleton.global_transform * skeleton.get_bone_global_pose(hand_index), "hand_index": hand_index, "bones": bones, "weapon": weapon.global_transform, "tip": weapon.to_global(weapon.get_meta("weapon_tip_local")), "pommel": weapon.to_global(weapon.get_meta("weapon_pommel_local"))}
