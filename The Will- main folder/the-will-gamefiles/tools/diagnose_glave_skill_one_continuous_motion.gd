extends "res://tools/diagnose_glave_skill_one_offhand.gd"

## Consecutive real UI edits on the saved two-hand Node 2. No checkpoint restore
## between edits: separates runtime retention from diagnostic restoration effects.
var _continuous_rows: Array[Dictionary] = []

func _probe_movements(index: int) -> void:
	if index != 2:
		return
	var edits: Array[Dictionary] = [
		{"control": "pommel", "delta": Vector3(0.03, 0, 0)},
		{"control": "pommel", "delta": Vector3(0.03, 0, 0)},
		{"control": "pommel", "delta": Vector3(0, 0.03, 0)},
		{"control": "tip", "delta": Vector3(0.10, 0, 0)},
	]
	_continuous_observe("before_first_edit")
	for i: int in edits.size():
		var edit: Dictionary = edits[i]
		var motion: Resource = _ui.call("_get_active_motion_node")
		var target: Vector3 = motion.get(edit.control + "_position_local")
		var started := Time.get_ticks_usec()
		var accepted: bool = _ui.call("set_selected_motion_node_" + edit.control + "_position", target + edit.delta, false, false, false, true, false)
		_continuous_observe("edit_%d_immediate" % i, {"control": edit.control, "requested_delta": edit.delta,
			"accepted": accepted, "elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0,
			"stored_displacement": (motion.get(edit.control + "_position_local") as Vector3) - target})
		for frame: int in range(1, 13):
			await process_frame
			if frame in [1, 4, 12]:
				_continuous_observe("edit_%d_after_%d_frames" % [i, frame])
	await _snapshot("node_02_after_consecutive_edits")
	_report["continuous_probe_scope"] = "Node 2: Pommel +X, +X, +Y then Tip +X through production UI setters, no checkpoint or node restoration between requests; no Save or F."

func _continuous_observe(stage: String, extra: Dictionary = {}) -> void:
	var viewport: SubViewport = _ui.get("preview_subviewport")
	var presenter: RefCounted = _ui.get("preview_presenter")
	var context: Dictionary = presenter.call("_weapon_roll_context", viewport)
	var owner: Node = context.actor.get_node_or_null("PreparedGripAcquisition")
	var motion: Resource = _ui.call("_get_active_motion_node")
	var grip := _read_grip_status()
	var row := {"stage": stage, "tick_ms": Time.get_ticks_msec(),
		"binding_check": presenter.call("_validate_weapon_motion_bindings", context, &"hand_right", &"hand_left"),
		"tip": motion.get("tip_position_local"), "pommel": motion.get("pommel_position_local"),
		"weapon_world": context.weapon.global_transform, "live_binding_ready": grip.get("live_binding_ready"),
		"acquisition_pending": grip.get("acquisition_pending"), "footer": grip.get("footer"),
		"support_clamp_count": owner.get("_support_motion_clamp_count") if owner != null else -1,
		"last_support_clamp": owner.get("_last_support_motion_clamp") if owner != null else {},
		"wrist_failures": context.actor.get("_wrist_motion_failures")}
	var allocation: Dictionary = context.root.get_meta("weapon_motion_allocation_result", {})
	row["allocation_summary"] = {}
	for field: String in ["valid", "status", "reason", "task_scale", "iterations", "blocking_constraints", "commit_readback_valid", "pose_warning"]:
		if allocation.has(field):
			row.allocation_summary[field] = allocation[field]
	row.merge(extra, true)
	_continuous_rows.append(row)
	_write_audit("continuous_movements.json", _continuous_rows)
