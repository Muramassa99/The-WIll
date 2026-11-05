extends SceneTree

## Real Unarmed Skill Crafter, shared body solver, fresh isolated library only.
## No bone writes, solver replacement, Save, F replay, or anatomical pass claim.
## --hands=R,L --elevations=0,20 --elbow-steps=15,-25,35,-45,60,-60
## --targets-from=<previous unarmed_arm_manifest.json> reuses exact input targets.
## Environment: THE_WILL_DIAGNOSTIC_USER_ROOT must equal OS user-data directory;
## THE_WILL_SAVE_PROFILE_OUTPUT_DIR supplies a fresh workspace output directory.
const Library = preload("res://core/models/player_forge_wip_library_state.gd")
const Station = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")
const RUN_LIMIT_MS := 240000
const PHASE_LIMIT_MS := 40000
const SEGMENT_STEPS := 8
const PARTS := ["Clavicle", "Upperarm", "Forearm", "Hand", "UpperarmTwist01", "UpperarmTwist02", "ForearmTwist01", "ForearmTwist02", "ElbowShareBone"]

class FakePlayer:
	extends Node
	var forge_wip_library_state: PlayerForgeWipLibraryState
	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state
	func set_ui_mode_enabled(_enabled: bool) -> void:
		pass

var _options: Dictionary = {}
var _out := ""
var _file: FileAccess
var _ui: CombatAnimationStationUI
var _player: FakePlayer
var _actor: Node3D
var _sk: Skeleton3D
var _root3d: Node3D
var _trajectory: Node3D
var _manifest: Dictionary = {"complete": false, "cases": [], "readiness": []}
var _replay: Dictionary = {}
var _case: Dictionary = {}
var _previous: Dictionary = {}
var _serial := 0
var _started := 0
var _finished := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var split: PackedStringArray = arg.substr(2).split("=", true, 1)
			_options[split[0]] = split[1]
	_out = String(_options.get("output", OS.get_environment("THE_WILL_SAVE_PROFILE_OUTPUT_DIR"))).replace("\\", "/").trim_suffix("/")
	var isolated: String = OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").trim_suffix("/")
	if not isolated.to_lower().begins_with("c:/workspace/") or OS.get_user_data_dir().replace("\\", "/").trim_suffix("/").to_lower() != isolated.to_lower():
		push_error("An explicitly isolated workspace user-data root is required."); quit(1); return
	if not _out.to_lower().begins_with("c:/workspace/") or FileAccess.file_exists(_out.path_join("unarmed_arm_manifest.json")) or DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("A fresh workspace output directory is required."); quit(1); return
	_file = FileAccess.open(_out.path_join("unarmed_arm_samples.jsonl"), FileAccess.WRITE)
	if _file == null:
		push_error("Cannot open diagnostic output."); quit(1); return
	if _options.has("targets-from"):
		var source: String = String(_options["targets-from"])
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
		if not parsed is Dictionary:
			_finish("invalid_targets_manifest"); return
		for item: Dictionary in parsed.get("cases", []):
			_replay[String(item["id"])] = item.get("inputs", {}).duplicate(true)
		_manifest["targets_source"] = {"path": source, "sha256": FileAccess.get_sha256(source)}
	var increments: Array[float] = _numbers(String(_options.get("elbow-steps", "15,-25,35,-45,60,-60")))
	if increments.is_empty():
		_finish("empty_elbow_steps"); return
	for value: float in increments:
		if absf(value) < 15.0 or absf(value) > 60.0:
			_finish("elbow_steps_require_15_to_60_degrees"); return
	_manifest.merge({"schema": 1, "options": _options, "run_limit_ms": RUN_LIMIT_MS,
		"scope": "Unarmed inputs to the shared body solver; actual UI controls; no real saves or anatomy certification.",
		"angle_conventions": "segment_deflection=0 straight; elbow_inner=180 straight. Bone axes are imported axes, not calibrated anatomical axes. Quaternion arrays are x,y,z,w.",
		"script_sha256": FileAccess.get_sha256("res://tools/diagnose_skill_crafter_unarmed_arm_continuity.gd"),
		"rig_sha256": FileAccess.get_sha256("res://runtime/player/player_humanoid_rig.gd"),
		"ui_sha256": FileAccess.get_sha256("res://runtime/combat/combat_animation_station_ui.gd")})
	_write_manifest()
	create_timer(float(RUN_LIMIT_MS) / 1000.0).timeout.connect(_on_timeout)
	var ordinal := 0
	for elevation: float in _numbers(String(_options.get("elevations", "0,20"))):
		for side: String in String(_options.get("hands", "R,L")).split(","):
			if _finished: return
			if side not in ["R", "L"]:
				_finish("invalid_side"); return
			ordinal += 1
			_case = {"id": "%02d_%s_elevation_%.0f" % [ordinal, side, elevation], "side": side, "elevation_degrees": elevation, "complete": false, "inputs": {}, "samples": 0}
			_manifest["cases"].append(_case)
			_previous = {}
			var okay: bool = await _run_case(side, elevation, increments)
			_case["complete"] = okay
			_write_manifest()
			if is_instance_valid(_ui): _ui.queue_free()
			if is_instance_valid(_player): _player.queue_free()
			await _frames(3)
			if not okay:
				_finish(String(_case.get("failure", "case_failed"))); return
	_finish("finished")


func _run_case(side: String, elevation: float, increments: Array[float]) -> bool:
	var library: PlayerForgeWipLibraryState = Library.new()
	library.save_file_path = _out.path_join("isolated_%s_library.tres" % _case["id"])
	_player = FakePlayer.new()
	_player.forge_wip_library_state = library
	root.add_child(_player)
	_ui = Station.instantiate() as CombatAnimationStationUI
	root.add_child(_ui)
	await _frames(2)
	_ui.open_for(_player, "Unarmed arm continuity diagnostic")
	await _frames(2)
	var slot: StringName = &"hand_right" if side == "R" else &"hand_left"
	if not _ui.select_unarmed_authoring(true, {"dominant_slot_id": slot, "use_two_hand": false}):
		return _fail_case("unarmed_open_failed")
	await _frames(2)
	if not _ui.select_skill_slot(&"skill_slot_2", true): return _fail_case("slot_open_failed")
	await _frames(2)
	if not _ui.reset_active_draft_to_baseline(): return _fail_case("reset_failed")
	_ui.select_motion_node(1)
	if not await _wait_ready("baseline", true): return _fail_case("baseline_not_ready")
	_root3d = _ui.call("_get_preview_root") as Node3D
	_actor = _root3d.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D
	_trajectory = _root3d.get_node_or_null("TrajectoryRoot") as Node3D
	_sk = _actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if _actor != null else null
	if _sk == null or _trajectory == null: return _fail_case("actor_or_trajectory_missing")
	var motion: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
	if motion.primary_hand_slot != slot: return _fail_case("wrong_primary_hand")
	var plan: Dictionary = _replay.get(_case["id"], {}).duplicate(true)
	if _options.has("targets-from") and plan.is_empty(): return _fail_case("replay_case_missing")
	if plan.is_empty():
		plan = {"initial_tip_local": _v(motion.tip_position_local), "initial_pommel_local": _v(motion.pommel_position_local),
			"tip_origin": String(motion.tip_position_origin_id), "pommel_origin": String(motion.pommel_position_origin_id), "elbow_increments_degrees": increments.duplicate()}
	else:
		if String(motion.tip_position_origin_id) != plan["tip_origin"] or String(motion.pommel_position_origin_id) != plan["pommel_origin"]:
			return _fail_case("replay_origin_mismatch")
		_ui.set_selected_motion_node_hand_proxy_segment(slot, _from_v(plan["initial_tip_local"]), _from_v(plan["initial_pommel_local"]), false, false, true, true, true)
		if not await _wait_ready("replay_initial", false): return _fail_case("replay_initial_not_settled")
	_case["inputs"] = plan
	await _record("baseline", {}, true)
	var forward: Vector3 = (_actor.global_basis * Vector3(0.0, sin(deg_to_rad(elevation)), cos(deg_to_rad(elevation)))).normalized()
	if not plan.has("setup_pommel_local"):
		var proxy: Node3D = _root3d.get_meta("preview_held_item", null) as Node3D
		if proxy == null: return _fail_case("unarmed_proxy_missing")
		var contact: Vector3 = proxy.global_transform * (proxy.get_meta("primary_grip_contact_local", Vector3.ZERO) as Vector3)
		var goal: Vector3 = _bone_world("CC_Base_%s_Upperarm" % side).origin + forward * 0.30 - _actor.global_basis.y.normalized() * 0.12
		plan["setup_pommel_local"] = _v(motion.pommel_position_local + _trajectory.global_basis.inverse() * (goal - contact))
		plan["forward_world"] = _v(forward)
	var setup_changed: bool = _ui.set_selected_motion_node_pommel_position(_from_v(plan["setup_pommel_local"]), false, false, true, true, true)
	if not await _wait_ready("setup", false): return _fail_case("setup_not_settled")
	await _record("setup", {"setter_changed": setup_changed, "requested_pommel_local": plan["setup_pommel_local"]}, true)
	var active: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = _ui.call("_build_authoring_motion_node_baseline", active)
	_ui.call("_begin_preview_drag_override", display)
	_ui.motion_node_editor.begin_drag(&"pommel", Vector2.ZERO, display)
	if not plan.has("extend_targets"):
		plan["extend_targets"] = _linear_targets(display.pommel_position_local, _trajectory.global_basis.inverse() * forward)
	if not await _translate(plan["extend_targets"], "extend"): return false
	await _record("maximum_extension", {}, true)
	var accepted: CombatAnimationMotionNode = _ui.call("_get_effective_preview_motion_node")
	if not plan.has("pull_targets"):
		var shoulder: Vector3 = _bone_world("CC_Base_%s_Upperarm" % side).origin
		var wrist: Vector3 = _bone_world("CC_Base_%s_Hand" % side).origin
		var delta: Vector3 = (shoulder - wrist) * 0.45
		var lateral: float = float(_options.get("lateral-factor", "0.15"))
		delta += _actor.global_basis.x.normalized() * (-1.0 if side == "L" else 1.0) * shoulder.distance_to(wrist) * 0.45 * lateral
		plan["pull_targets"] = _linear_targets(accepted.pommel_position_local, _trajectory.global_basis.inverse() * delta)
	_write_manifest()
	if not await _translate(plan["pull_targets"], "pull"): return false
	await _record("retracted_before_release", {}, true)
	_ui.motion_node_editor.end_drag()
	_ui.call("_finalize_preview_drag")
	if not await _wait_ready("translation_release", false): return _fail_case("translation_release_pending")
	await _record("retracted_held", {}, true)
	# No extension or reset occurs between retraction and the elbow interaction.
	return await _orbit_elbow(slot, side, plan["elbow_increments_degrees"])


func _translate(targets: Array, phase: String) -> bool:
	for index: int in targets.size():
		if _finished: return false
		var node: CombatAnimationMotionNode = _ui.call("_get_effective_preview_motion_node")
		_ui.call("_queue_pommel_drag_authority_target", _from_v(targets[index]), node.pommel_position_origin_id)
		var result: Dictionary = _ui.call("_resolve_pending_pommel_drag_authority", true)
		_ui.preview_drag_refresh_pending = false
		_ui.preview_drag_first_pending_msec = 0
		_ui.call("_refresh_preview_scene")
		await _frames(2)
		await _record(phase, {"input_step": index + 1, "requested_pommel_local": targets[index], "authority": result})
	return true


func _orbit_elbow(slot: StringName, side: String, increments: Array) -> bool:
	var wanted: StringName = &"right_arm_roll" if side == "R" else &"left_arm_roll"
	for index: int in 16:
		if _ui.session_state.current_focus == wanted: break
		_ui.call("_cycle_focus")
	var states: Dictionary = _root3d.get_meta("upperarm_roll_gizmo_state", {})
	var state: Dictionary = states.get(slot, {})
	if state.is_empty(): return _fail_case("elbow_gizmo_missing")
	var center: Vector3 = state["center_global"]
	var axis: Vector3 = (state["axis_global"] as Vector3).normalized()
	var normal0: Vector3 = state["initial_normal_global"]
	var camera: Camera3D = _ui.call("_get_preview_camera")
	var original_camera: Transform3D = camera.global_transform
	var original_projection: int = camera.projection
	var original_size: float = camera.size
	_point_camera_at_ring(camera, center, axis)
	var display: CombatAnimationMotionNode = _ui.call("_build_authoring_motion_node_baseline", _ui.call("_get_active_motion_node"))
	_ui.call("_begin_preview_drag_override", display)
	var press: Vector2 = camera.unproject_position(center + normal0 * float(state["radius_meters"]) * 0.999)
	_ui.motion_node_editor.begin_upperarm_roll_drag(state["drag_target"], state, camera, press)
	var total := 0.0
	for increment: float in increments:
		if _finished: return false
		total += increment
		_point_camera_at_ring(camera, center, axis)
		var normal: Vector3 = Basis(axis, deg_to_rad(total)) * normal0
		var pointer: Vector2 = camera.unproject_position(center + normal * float(state["radius_meters"]) * 0.999)
		var resolved: Variant = _ui.motion_node_editor.resolve_upperarm_roll_drag(camera, pointer)
		_ui.call("_handle_preview_drag", pointer)
		_ui.call("_flush_pending_preview_drag_refresh")
		var started: int = Time.get_ticks_msec()
		while _ui.preview_drag_refresh_pending and Time.get_ticks_msec() - started < 5000 and not _finished:
			await process_frame
		if _ui.preview_drag_refresh_pending: return _fail_case("elbow_preview_pending")
		await _frames(2)
		await _record("elbow_pointer", {"requested_step_degrees": increment, "requested_cumulative_arc_degrees": total,
			"pointer_resolved_roll_degrees": resolved, "control_axis_world": axis, "requested_radial_world": normal,
			"held_pommel_drift_m": _motion().pommel_position_local.distance_to(display.pommel_position_local),
			"held_tip_drift_m": _motion().tip_position_local.distance_to(display.tip_position_local)})
	_ui.motion_node_editor.end_drag()
	_ui.call("_finalize_preview_drag")
	if not await _wait_ready("elbow_release", false): return _fail_case("elbow_release_pending")
	camera.global_transform = original_camera
	camera.projection = original_projection
	camera.size = original_size
	await _record("elbow_released", {"requested_cumulative_arc_degrees": total}, true)
	await _frames(12)
	await _record("held_after_release", {}, true)
	return true


func _point_camera_at_ring(camera: Camera3D, center: Vector3, axis: Vector3) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.55
	camera.global_position = center + axis * 2.0
	var up: Vector3 = _actor.global_basis.y.normalized()
	if absf(up.dot(axis)) > 0.95: up = _actor.global_basis.x.normalized()
	camera.look_at(center, up)


func _wait_ready(label: String, require_baseline: bool) -> bool:
	var started: int = Time.get_ticks_msec()
	var state: Dictionary = {}
	var stable := 0
	while Time.get_ticks_msec() - started < PHASE_LIMIT_MS and not _finished:
		var node: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
		var baseline: Dictionary = _ui.get_meta("last_baseline_preparation", {})
		var current: bool = node != null and node.prepared_pose_signature == PreparedPose.node_pose_signature(node) and bool(PreparedPose.validate(node.prepared_pose).get("valid", false))
		state = {"phase": label, "case": _case["id"], "wait_ms": Time.get_ticks_msec() - started,
			"baseline": baseline, "prepared_current": current, "recording_pending": _ui.is_motion_node_recording_pending(),
			"acquisition_pending": _ui.preview_presenter.is_grip_acquisition_pending(_ui.preview_subviewport), "preview_pending": _ui.preview_drag_refresh_pending}
		# Rejected edits may have no accepted prepared pose: idle is sufficient
		# after motion, but the initial baseline requires actual valid recording.
		var ready: bool = not state["recording_pending"] and not state["acquisition_pending"] and not state["preview_pending"]
		if require_baseline: ready = ready and current and bool(baseline.get("ready", false))
		stable = stable + 1 if ready else 0
		if stable >= 3:
			_manifest["readiness"].append(_encode(state)); _write_manifest(); return true
		await process_frame
	_manifest["readiness"].append(_encode(state)); _write_manifest()
	return false


func _record(phase: String, extra: Dictionary = {}, screenshot: bool = false) -> void:
	if _finished: return
	if DisplayServer.get_name().to_lower() != "headless": await RenderingServer.frame_post_draw
	var row: Dictionary = _snapshot()
	row.merge({"serial": _serial, "case": _case["id"], "phase": phase, "elapsed_ms": Time.get_ticks_msec() - _started})
	row.merge(extra)
	if not _previous.is_empty():
		var changes: Dictionary = {}
		for name: String in row["bones"]:
			if not _previous["bones"].has(name): continue
			var before: Transform3D = _previous["bones"][name]["world"]
			var after: Transform3D = row["bones"][name]["world"]
			changes[name] = {"world_rotation_degrees": _rotation_distance(before.basis, after.basis), "world_position_m": before.origin.distance_to(after.origin)}
		row["change_from_previous"] = {"phase": _previous["phase"], "bones": changes,
			"bend_normal_degrees": _angle_optional(_previous["bend_normal_world"], row["bend_normal_world"]),
			"elbow_radial_degrees": _angle_optional(_previous["elbow_radial_world"], row["elbow_radial_world"])}
	if screenshot and DisplayServer.get_name().to_lower() != "headless":
		var name := "%s_%03d_%s.png" % [_case["id"], int(_case["samples"]), phase]
		var image: Image = _ui.preview_subviewport.get_texture().get_image()
		if image != null and image.save_png(_out.path_join(name)) == OK: row["image"] = name
	_file.store_line(JSON.stringify(_encode(row))); _file.flush()
	_previous = row
	_case["samples"] += 1
	_serial += 1
	print("UNARMED_ARM %s %s inner=%.3f status=%s" % [_case["id"], phase, row["elbow_inner_degrees"], row["footer"]])
	_write_manifest()


func _snapshot() -> Dictionary:
	var side: String = _case["side"]
	var names: Array[String] = ["CC_Base_Waist", "CC_Base_Spine01", "CC_Base_Spine02"]
	for part: String in PARTS: names.append("CC_Base_%s_%s" % [side, part])
	var bones: Dictionary = {}
	for name: String in names:
		var index: int = _sk.find_bone(name)
		if index < 0: continue
		bones[name] = {"index": index, "parent": _sk.get_bone_parent(index), "rest_local": _sk.get_bone_rest(index),
			"pose_local": _sk.get_bone_pose(index), "local_rotation": _sk.get_bone_pose_rotation(index),
			"skeleton": _sk.get_bone_global_pose(index), "world": _sk.global_transform * _sk.get_bone_global_pose(index)}
	var shoulder: Vector3 = _bone_world("CC_Base_%s_Upperarm" % side).origin
	var elbow: Vector3 = _bone_world("CC_Base_%s_Forearm" % side).origin
	var hand: Vector3 = _bone_world("CC_Base_%s_Hand" % side).origin
	var upper: Vector3 = (elbow - shoulder).normalized()
	var fore: Vector3 = (hand - elbow).normalized()
	var reach: Vector3 = (hand - shoulder).normalized()
	var radial: Vector3 = elbow - shoulder
	radial -= reach * radial.dot(reach)
	var limits: Dictionary = {}
	for property: Dictionary in _actor.get_property_list():
		var key: String = property["name"]
		if key.begins_with("authoring_") and (key.contains("limit") or key.contains("plane_angle") or key.contains("clamp")):
			limits[key] = _actor.get(key)
	var target: Node3D = _actor.get_node_or_null("IkTargets/%sHandIkTarget" % ("Right" if side == "R" else "Left")) as Node3D
	return {"bones": bones, "actor_world": _actor.global_transform, "skeleton_world": _sk.global_transform,
		"trajectory_world": _trajectory.global_transform, "effective": _motion_fields(_motion()),
		"authored": _motion_fields(_ui.call("_get_active_motion_node")), "limits": limits,
		"twist_distribution": _actor.get("authoring_limb_twist_distribution_state"),
		"shoulder_world": shoulder, "elbow_world": elbow, "hand_world": hand,
		"ik_target_world": target.global_position if target != null else null,
		"upper_axis_world": upper, "forearm_axis_world": fore,
		"bend_normal_world": upper.cross(fore).normalized(), "elbow_radial_world": radial.normalized(),
		"segment_deflection_degrees": rad_to_deg(upper.angle_to(fore)), "elbow_inner_degrees": rad_to_deg((-upper).angle_to(fore)),
		"upper_length_m": shoulder.distance_to(elbow), "forearm_length_m": elbow.distance_to(hand),
		"footer": _ui.footer_status_label.text, "preview_pending": _ui.preview_drag_refresh_pending,
		"recording_pending": _ui.is_motion_node_recording_pending()}


func _motion_fields(node: CombatAnimationMotionNode) -> Dictionary:
	if node == null: return {}
	return {"tip_local": node.tip_position_local, "pommel_local": node.pommel_position_local,
		"tip_origin": String(node.tip_position_origin_id), "pommel_origin": String(node.pommel_position_origin_id),
		"primary_hand": String(node.primary_hand_slot), "right_upperarm_roll_degrees": node.right_upperarm_roll_degrees,
		"left_upperarm_roll_degrees": node.left_upperarm_roll_degrees, "prepared_signature": node.prepared_pose_signature}


func _motion() -> CombatAnimationMotionNode:
	return _ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode


func _bone_world(name: String) -> Transform3D:
	return _sk.global_transform * _sk.get_bone_global_pose(_sk.find_bone(name))


func _linear_targets(start: Vector3, delta: Vector3) -> Array:
	var result: Array = []
	for step: int in range(1, SEGMENT_STEPS + 1): result.append(_v(start + delta * float(step) / float(SEGMENT_STEPS)))
	return result


func _rotation_distance(a: Basis, b: Basis) -> float:
	var qa: Quaternion = a.orthonormalized().get_rotation_quaternion().normalized()
	var qb: Quaternion = b.orthonormalized().get_rotation_quaternion().normalized()
	return rad_to_deg(2.0 * acos(clampf(absf(qa.dot(qb)), 0.0, 1.0)))


func _angle_optional(a: Vector3, b: Vector3) -> Variant:
	return rad_to_deg(a.angle_to(b)) if a.length_squared() > 0.000001 and b.length_squared() > 0.000001 else null


func _numbers(text: String) -> Array[float]:
	var result: Array[float] = []
	for entry: String in text.split(",", false): result.append(float(entry))
	return result


func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _from_v(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _encode(value: Variant) -> Variant:
	if value is Vector3: return _v(value)
	if value is Vector2: return [value.x, value.y]
	if value is Quaternion: return [value.x, value.y, value.z, value.w]
	if value is Basis: return {"x": _v(value.x), "y": _v(value.y), "z": _v(value.z)}
	if value is Transform3D: return {"origin": _v(value.origin), "basis": _encode(value.basis)}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[String(key)] = _encode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_encode(item))
		return result
	if value is StringName: return String(value)
	return value


func _frames(count: int) -> void:
	for index: int in count: await process_frame


func _fail_case(reason: String) -> bool:
	_case["failure"] = reason
	return false


func _write_manifest() -> void:
	if _out.is_empty(): return
	var file := FileAccess.open(_out.path_join("unarmed_arm_manifest.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(_encode(_manifest), "\t"))


func _on_timeout() -> void:
	_finish("run_time_limit")


func _finish(reason: String) -> void:
	if _finished: return
	_finished = true
	_manifest.merge({"complete": reason == "finished", "reason": reason, "samples": _serial, "elapsed_ms": Time.get_ticks_msec() - _started})
	_write_manifest()
	if _file != null: _file.close()
	print("UNARMED_ARM_DONE " + JSON.stringify({"reason": reason, "samples": _serial, "output": _out}))
	quit(0 if reason == "finished" else 1)
