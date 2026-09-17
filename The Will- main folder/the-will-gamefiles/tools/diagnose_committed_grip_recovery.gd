extends "res://tools/verify_weapon_roll_manipulation.gd"

func _run() -> void:
	var player := TestPlayer.new()
	player.library = load(DATA_PATH).duplicate(true)
	player.library.set("save_file_path", TEST_SAVE_PATH)
	var chosen: Resource
	for wip: Resource in player.library.get("saved_wips"):
		if wip.get("forge_project_name") == "Star_Handle_Testing":
			chosen = wip
	if chosen == null:
		quit(1)
		return
	root.add_child(player)
	var ui = UIScene.instantiate()
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await process_frame
	ui.open_for(player, "Committed grip recovery diagnostic")
	ui.open_saved_wip_with_hand_setup(chosen.get("wip_id"), &"hand_right", false, false)
	ui.select_skill_slot(&"skill_slot_1", true)
	await process_frame
	ui.set_process(false)
	var context: Dictionary = ui.preview_presenter.call("_weapon_roll_context", ui.preview_subviewport)
	var baseline: Dictionary = _sample(context, &"hand_right")
	var actor: Node3D = context["actor"]
	var weapon: Node3D = context["weapon"]
	var motion: Resource = ui.call("_get_active_motion_node")
	var hand_in_weapon: Transform3D = baseline["weapon"].affine_inverse() * baseline["hand"]
	var seat: Dictionary = actor.call("get_weapon_surface_seat_debug_state", &"hand_right")
	print("GRIP_DIGITS_BEFORE=" + JSON.stringify(_digit_summary(actor)))
	print("GRIP_BASELINE=" + JSON.stringify({"seat_valid": seat.get("valid"), "seat_status": seat.get("status"), "hand_in_weapon": var_to_str(hand_in_weapon)}))
	for index: int in range(3):
		var target: Transform3D = baseline["weapon"]
		if index == 0:
			target.origin += Vector3(0.02, 0.0, 0.0)
		else:
			var rotation := Basis(Vector3.UP, deg_to_rad(5.0 if index == 1 else -5.0))
			target = Transform3D(rotation * target.basis, baseline["hand"].origin + rotation * (target.origin - baseline["hand"].origin))
		weapon.global_transform = target
		var presenter = ui.preview_presenter
		presenter.call("_apply_preview_resolved_grip_state", weapon, actor)
		presenter.call("_apply_two_hand_preview_state", actor, weapon, motion)
		presenter.call("_apply_preview_upper_body_authoring_state", actor, weapon, motion, {})
		presenter.call("_apply_preview_actor_upper_body_pose_now", actor, true, false)
		print("GRIP_DIGITS_AFTER_MACRO=" + JSON.stringify(_digit_summary(actor)))
		var restored: bool = actor.call("restore_authoring_committed_surface_grip_now", &"hand_right")
		var sample: Dictionary = _sample(context, &"hand_right")
		var relation: Transform3D = sample["weapon"].affine_inverse() * sample["hand"]
		print("GRIP_REUSE_PROBE=" + JSON.stringify({"sample": index, "digits_restored": restored, "grip_position_delta_m": relation.origin.distance_to(hand_in_weapon.origin), "grip_basis_delta": relation.basis.x.distance_to(hand_in_weapon.basis.x) + relation.basis.y.distance_to(hand_in_weapon.basis.y) + relation.basis.z.distance_to(hand_in_weapon.basis.z), "hand_in_weapon": var_to_str(relation)}))
	ui.queue_free()
	player.queue_free()
	await process_frame
	quit(0)

func _digit_summary(actor: Node3D) -> Dictionary:
	var state: Dictionary = actor.finger_grip_presenter.get_surface_grasp_debug_state(&"hand_right")
	return {"valid": state.get("valid", false), "status": state.get("status", ""), "rotation_count": (state.get("rotations", {}) as Dictionary).size(), "solve_count": state.get("solve_count", 0), "last_rejected_status": state.get("last_rejected_status", "")}
