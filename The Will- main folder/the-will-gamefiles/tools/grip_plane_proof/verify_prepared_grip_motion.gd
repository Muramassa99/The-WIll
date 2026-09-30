extends "res://tools/grip_plane_proof/verify_primary_grip_weapon_seating.gd"

## Replay a completed, hash-pinned acquisition through the actual Skill Crafter
## controls. The fixture restores its captured pose explicitly; no grip search
## runs, no player save is written, and differing weapon geometry is rejected.
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const Origins = preload("res://core/models/combat_origin_record.gd")
const Capture = preload("res://runtime/player/grip/capture_grip_placement_stage.gd")
const SOLVED_REPORT := "C:/WORKSPACE/test_artifacts/inward_guide_grip_comparison_2026-09-27T20-06-32.json"
const SOLVED_SHA := "e85190a6f4620564c74c9bcf174cf1a961e56a113d915bc856f8a54b37e047c9"
const POSITION_GUARD_M := 0.00001
const ROTATION_GUARD_RAD := 0.0001
const MESH_GUARD_M := 0.000001
const MIN_MOVEMENT_M := 0.0001
const MIN_MOVEMENT_RAD := 0.000174532925199433

class TestPlayer extends Node:
	var library: Resource
	func get_forge_wip_library_state() -> Resource: return library
	func set_ui_mode_enabled(_enabled: bool) -> void: pass

var _ui: Node
var _player
var _context: Dictionary = {}
var _owner: Node
var _baseline: Dictionary = {}
var _actions: Array = []
var _fixture: Dictionary = {}
var _started_usec := 0
var _movement_counts := {"tip": 0, "pommel": 0, "roll": 0}
var _action_outcomes: Array = []
var _lifecycle: Dictionary = {}


func _run() -> void:
	_started_usec = Time.get_ticks_usec()
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not _check(expected.begins_with("c:/workspace/") and expected == OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower(), "isolated workspace user data"):
		_finish(); return
	if not _check(FileAccess.get_sha256(SOLVED_REPORT) == SOLVED_SHA, "exact completed acquisition report"):
		_finish(); return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOLVED_REPORT))
	var source: Dictionary = {}
	for entry: Dictionary in report.get("cases", []):
		if entry.get("slot") == "hand_right": source = entry
	if not _check(report.get("ok", false) and source.get("valid", false), "completed right-hand source"):
		_finish(); return
	var trace_path: String = source.source_trace
	if not _check(trace_path.begins_with("C:/WORKSPACE/test_artifacts/") and FileAccess.get_sha256(trace_path) == source.source_trace_sha256, "exact adapted placement trace"):
		_finish(); return
	var file := FileAccess.open(trace_path, FileAccess.READ)
	var trace: Dictionary = file.get_var(false); file.close()
	var stage: Dictionary = {}
	for transaction: Dictionary in trace.transactions:
		if transaction.serial == source.source_transaction:
			stage = transaction.finger_inputs[-1]
	if not _check(not stage.is_empty() and stage.transaction_serial == source.source_transaction, "matching captured placement transaction"):
		_finish(); return
	_fixture = {"source_trace": trace_path, "source_trace_sha256": source.source_trace_sha256,
		"source_transaction": source.source_transaction, "capture_is_historical": true,
		"captured_skeleton_and_weapon_restored": false, "search_performed": false}
	var library: Resource = load("user://forge/player_wip_library_state.tres")
	if not _check(library != null, "isolated saved weapon library exists"):
		_finish(); return
	_player = TestPlayer.new()
	_player.library = library.duplicate(true)
	_player.library.set("save_file_path", "C:/WORKSPACE/test_artifacts/prepared_grip_motion_unused_save.tres")
	var chosen: Resource
	for wip: Resource in _player.library.get("saved_wips"):
		if wip.get("forge_project_name") == "Star_Handle_Testing": chosen = wip
	if not _check(chosen != null, "isolated Star_Handle_Testing fixture exists"):
		_finish(); return
	root.add_child(_player)
	_ui = UIScene.instantiate()
	_ui.set_meta("verification_skip_persistence", true)
	root.add_child(_ui)
	await process_frame
	_ui.open_for(_player, "Prepared grip motion verification")
	_check(_ui.open_saved_wip_with_hand_setup(chosen.get("wip_id"), &"hand_right", false, false), "open saved weapon through UI")
	_check(_ui.select_skill_slot(&"skill_slot_1", true), "select Skill 1 through UI")
	_context = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	if not _check(not _context.is_empty(), "real UI preview context exists"):
		_finish(); return
	_owner = _context.actor.get_node_or_null(Owner.NODE_NAME)
	if not _check(_owner != null, "production acquisition owner exists"):
		_finish(); return
	# No await between skill selection and this stop: queued numerical work has
	# no opportunity to start. Keep the normal actor/control processing enabled.
	_owner.set_process(false)
	if not _check(not _owner.get("_busy") and _owner.get("_job") == null, "acquisition search never started"):
		_finish(); return
	# Derive the station from the captured named span, rather than guessing the
	# slider used by the historical capture. A sampled center lies in its axial
	# section even for an off-axis/curved handle.
	var span: Vector3 = stage.object.primary_grip_span_end_local - stage.object.primary_grip_span_start_local
	var axis_ratio: float = (stage.object.grip_pivot_local - stage.object.primary_grip_span_start_local).dot(span) / span.length_squared()
	var tip_ratio: float = _context.weapon.get_meta("primary_grip_handle_tip_side_axis_ratio_from_span_start", 1.0)
	var coordinate: float = (axis_ratio - (1.0 - tip_ratio)) / (2.0 * tip_ratio - 1.0)
	_fixture["derived_handle_coordinate"] = coordinate
	_fixture["captured_station_weapon_local"] = stage.object.grip_pivot_local
	_fixture["station_origin_id"] = Origins.ORIGIN_WEAPON_ROOT
	if not _check(is_finite(coordinate) and coordinate >= 0.0 and coordinate <= 1.0, "captured station has a valid semantic Handle coordinate"):
		_finish(); return
	_ui.set_selected_motion_node_axial_reposition(0.0, false, false, false, true, false)
	_ui.set_selected_motion_node_grip_seat_slide(coordinate, false, false, false, true, false)
	_ui._refresh_preview_scene()
	var current_station: Variant = _context.weapon.get_meta("preview_primary_grip_seat_local", null)
	_fixture["resolved_ui_station_weapon_local"] = current_station
	if not _check(current_station is Vector3 and (current_station as Vector3).distance_to(stage.object.grip_pivot_local) <= MESH_GUARD_M, "derived UI station matches frozen capture"):
		_finish(); return
	if not _install_fixture(source, trace, stage):
		_finish(); return
	_baseline = _sample_motion()
	_record("installed_fixture", {}, true, 0.0)
	_ui.session_state.current_focus = &"weapon"
	for action: Dictionary in [
		{"kind": "refresh"},
		{"kind": "tip", "offset": Vector3(-0.003, 0.004, 0.002)},
		{"kind": "pommel", "offset": Vector3(0.006, 0.002, -0.003)},
		{"kind": "tip", "offset": Vector3(0.005, -0.003, 0.001)},
		{"kind": "roll", "delta_degrees": 20.0},
		{"kind": "pommel", "offset": Vector3(-0.004, 0.001, 0.002)},
		{"kind": "roll", "delta_degrees": -20.0},
		{"kind": "refresh"},
	]:
		await _exercise(action)
	for kind: String in _movement_counts:
		_check(_movement_counts[kind] > 0, kind + " has at least one accepted control that actually moves")
	await _exercise({"kind": "pommel", "offset": Vector3(4.0, 4.0, 0.0), "expect_limit": true})
	await _exercise({"kind": "refresh"})
	await _exercise_station_and_release()
	_finish()


func _install_fixture(source: Dictionary, trace: Dictionary, stage: Dictionary) -> bool:
	var rig: Node3D = _context.actor
	var weapon: Node3D = _context.weapon
	var skeleton: Skeleton3D = rig.get("skeleton")
	var data: Dictionary = Data.load_for_actor(rig)
	if not _check(data.get("valid", false) and trace.anatomy_signature == data.anatomy.source_signature, "live character matches frozen anatomy"):
		return false
	if not _verify_mesh(weapon, stage.object): return false
	var job := Job.new()
	if not _check(job.configure(data.anatomy, stage, data.config, rig).get("valid", false), "frozen candidate configuration"):
		return false
	var prepared: Dictionary = job._prepare(data.anatomy, stage)
	if not _check(prepared.get("valid", false), "frozen geometry prepared without search"):
		return false
	var parameters: Array = job._clamped(prepared, source.selected.parameters)
	for index: int in parameters.size():
		if not _check(absf(parameters[index] - source.selected.parameters[index]) < 1.0e-12, "saved parameter within current bounds " + str(index)):
			return false
	var translation: Vector3 = prepared.translation_u_world * parameters[-2] + prepared.translation_v_world * parameters[-1]
	if not _check(translation.distance_to(_v(source.selected.translation_world)) < 1.0e-8, "same saved transverse displacement"):
		return false
	var candidate: Dictionary = job._rigid_candidate(prepared, parameters, translation)
	if not _check(candidate.get("valid", false), "saved candidate reconstructed"):
		return false
	job._set_phase("circle", 0.0)
	var selected: Dictionary = job._circle_sample(prepared, parameters, 0.0, true)
	if not _check(selected.get("valid", false) and selected.get("material_safe", false), "current selected-pose material check"):
		return false
	if not _check(selected.get("material_contacts", []) == source.selected.material_contacts, "same saved actual-handle contacts"):
		return false
	_fixture["ui_weapon_before_restore_world"] = weapon.global_transform
	_fixture["ui_station_before_restore_weapon_local"] = weapon.get_meta("preview_primary_grip_seat_local", Vector3.ZERO)
	_fixture["station_origin_id"] = Origins.ORIGIN_WEAPON_ROOT
	if not _restore(skeleton, stage.posed_character): return false
	_context.trajectory.global_transform = _ui.preview_presenter._resolve_trajectory_authoring_transform(rig)
	weapon.global_transform = stage.object.weapon_to_world
	# Retain the UI-produced station metadata and its exact key; geometry and
	# station were compared with the capture above, not substituted into live UI.
	var slots: Array[StringName] = [&"hand_right"]
	_owner.synchronize(slots, &"hand_right")
	var request: Dictionary = _owner.get("_requests").get(&"hand_right", {}).duplicate()
	if not _check(not request.is_empty(), "fixture relationship claimed by production owner"):
		return false
	var hand_index := skeleton.find_bone("CC_Base_R_Hand")
	var hand_before: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	var bones_before: Array[Transform3D] = _poses(skeleton)
	var result := {"valid": true, "selected": selected, "candidate": candidate,
		"weapon_to_world": weapon.global_transform, "vectors_origin_id": ROOT}
	var applied: Dictionary = _owner.apply_primary_result(&"hand_right", request, result, _owner._realization_stamp())
	if not _check(applied.get("valid", false), "saved grip installed through production application: " + str(applied.get("reason", ""))):
		return false
	if not _check((skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)).is_equal_approx(hand_before), "fixture acquisition leaves Hand fixed"):
		return false
	var digit_names: Array[StringName] = Job.Rules.get_finger_bone_names(&"hand_right")
	for index: int in skeleton.get_bone_count():
		if skeleton.get_bone_name(index) not in digit_names:
			if not _check(skeleton.get_bone_pose(index).is_equal_approx(bones_before[index]), "fixture application leaves non-digit bone fixed " + str(index)):
				return false
	var expected_relationship: Transform3D = (stage.object.weapon_to_world as Transform3D).affine_inverse() * candidate.hand_to_world
	var actual_relationship: Transform3D = weapon.global_transform.affine_inverse() * hand_before
	if not _check(actual_relationship.is_equal_approx(expected_relationship), "fixture retains saved complete Hand-in-WeaponRoot relationship"):
		return false
	_fixture["captured_skeleton_and_weapon_restored"] = true
	_fixture["saved_material_contacts"] = selected.material_contacts
	_fixture["hand_in_weapon"] = actual_relationship
	_fixture["hand_in_weapon_origin_id"] = Origins.ORIGIN_WEAPON_ROOT
	_fixture["machine_to_world"] = stage.posed_character.machine_to_world
	_fixture["machine_origin_id"] = ROOT
	_fixture["origin_records"] = stage.posed_character.origin_records
	# The application is deliberately replayed without the owner's asynchronous
	# queue. Leaving processing disabled proves movement needs no reacquisition.
	var empty_queue: Array[StringName] = []
	_owner.set("_queue", empty_queue)
	return true


func _verify_mesh(weapon: Node3D, object: Dictionary) -> bool:
	var meshes: Array[MeshInstance3D] = []
	for child: Node in weapon.get_children():
		if child is MeshInstance3D and child.mesh != null and child.get_meta("visual_mesh_source", StringName()) == &"editable_mesh":
			meshes.append(child)
	if not _check(meshes.size() == 1, "exactly one editable weapon mesh"):
		return false
	var extracted: Dictionary = Capture.new().extract_object_triangle_faces(meshes[0].mesh)
	if not _check(extracted.get("valid", false), "extract live mesh using capture's exact triangle source"):
		return false
	var faces: PackedVector3Array = extracted.local_faces
	var captured: PackedVector3Array = object.local_faces
	if not _check(faces.size() == captured.size(), "live and captured mesh triangle counts match"):
		return false
	var actual_frame: Transform3D = weapon.global_transform.affine_inverse() * meshes[0].global_transform
	var saved_frame: Transform3D = (object.weapon_to_world as Transform3D).affine_inverse() * object.mesh_to_world
	var largest_error := 0.0
	for index: int in faces.size():
		largest_error = maxf(largest_error, (actual_frame * faces[index]).distance_to(saved_frame * captured[index]))
	_fixture["mesh_vertex_count"] = faces.size()
	_fixture["maximum_mesh_vertex_error_m"] = largest_error
	_fixture["mesh_comparison_origin_id"] = Origins.ORIGIN_WEAPON_ROOT
	return _check(largest_error <= MESH_GUARD_M, "live weapon mesh matches exact frozen geometry in WeaponRoot")


func _exercise(action: Dictionary) -> void:
	var motion: Resource = _ui._get_active_motion_node()
	var visible_motion: Resource = _ui._build_authoring_motion_node_baseline(motion)
	var kind: String = action.kind
	var at_limit: bool = action.get("expect_limit", false)
	var requested: Dictionary = {"kind": kind, "expect_limit": at_limit}
	var before := _sample_motion()
	if kind in ["tip", "pommel"]:
		var shown: Vector3 = visible_motion.get(kind + "_position_local")
		_check(shown.distance_to(before["actual_" + kind + "_trajectory_local"]) <= POSITION_GUARD_M, kind + " displayed control starts at actual held endpoint")
		var displayed_frame: Transform3D = _ui.preview_presenter._solve_weapon_segment_transform(_context.weapon, _context.trajectory, visible_motion,
			_context.weapon.get_meta("weapon_tip_local"), _context.weapon.get_meta("weapon_pommel_local"),
			_context.trajectory.to_global(visible_motion.tip_position_local), _context.trajectory.to_global(visible_motion.pommel_position_local), visible_motion.weapon_orientation_degrees)
		_check(displayed_frame.is_equal_approx(before.weapon_world), kind + " displayed full frame reconstructs actual held orientation and position")
	var started := Time.get_ticks_usec()
	var changed := false
	if kind == "tip":
		requested["position_local"] = visible_motion.get("tip_position_local") + action.offset
		requested["position_origin_id"] = visible_motion.get("tip_position_origin_id")
		requested["position_world"] = _context.trajectory.to_global(requested.position_local)
		requested["world_reference_origin_id"] = ROOT
		changed = _ui.set_selected_motion_node_tip_position(requested.position_local, false, false, false, true, false)
	elif kind == "pommel":
		requested["position_local"] = visible_motion.get("pommel_position_local") + action.offset
		requested["position_origin_id"] = visible_motion.get("pommel_position_origin_id")
		requested["position_world"] = _context.trajectory.to_global(requested.position_local)
		requested["world_reference_origin_id"] = ROOT
		if at_limit:
			if not _check(requested.position_origin_id == Origins.ORIGIN_TRAJECTORY_AUTHORING, "limit request uses named trajectory coordinates"):
				return
			requested["position_world"] = _context.trajectory.to_global(requested.position_local)
			requested["world_reference_origin_id"] = ROOT
		changed = _ui.set_selected_motion_node_pommel_position(requested.position_local, false, false, false, true, false)
	elif kind == "roll":
		requested["degrees"] = float(motion.get("weapon_roll_degrees")) + float(action.delta_degrees)
		changed = _ui.set_selected_motion_node_weapon_roll(requested.degrees, false, false, false, true, false)
	else:
		_ui._refresh_preview_scene()
		changed = true
	var duration_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var label := kind + ("_beyond_reach" if at_limit else "")
	_record(label + "_synchronous", requested, changed, duration_ms, before)
	for frame: int in 2: await process_frame
	_record(label + "_settled", requested, changed, duration_ms, before)
	var after := _sample_motion()
	var origin_travel: float = (before.weapon_world as Transform3D).origin.distance_to((after.weapon_world as Transform3D).origin)
	var tip_travel: float = (before.tip_world as Vector3).distance_to(after.tip_world)
	var pommel_travel: float = (before.pommel_world as Vector3).distance_to(after.pommel_world)
	var rotation_travel := _quaternion_error((before.weapon_world as Transform3D).basis.orthonormalized().get_rotation_quaternion(), (after.weapon_world as Transform3D).basis.orthonormalized().get_rotation_quaternion())
	var pose_moved: bool = maxf(origin_travel, maxf(tip_travel, pommel_travel)) >= MIN_MOVEMENT_M or rotation_travel >= MIN_MOVEMENT_RAD
	var outcome := {"kind": kind, "expect_limit": at_limit, "accepted": changed,
		"actual_weapon_moved": pose_moved, "classification": "refresh" if kind == "refresh" else ("moved" if pose_moved else "no_op"),
		"weapon_origin_travel_m": origin_travel, "tip_travel_m": tip_travel,
		"pommel_travel_m": pommel_travel, "weapon_rotation_rad": rotation_travel,
		"before_to_after": _relative_error(before, after)}
	if kind in ["tip", "pommel"]:
		var before_endpoint: Vector3 = before[kind + "_world"]
		var after_endpoint: Vector3 = after[kind + "_world"]
		outcome["requested_travel_m"] = before_endpoint.distance_to(requested.position_world)
		outcome["actual_travel_m"] = before_endpoint.distance_to(after_endpoint)
		outcome["unreached_target_distance_m"] = after_endpoint.distance_to(requested.position_world)
	if kind != "refresh" and not at_limit:
		if changed:
			_check(pose_moved, kind + " accepted bounded control actually changes weapon pose")
		elif not pose_moved:
			outcome["classification"] = "rejected_or_unchanged_control"
		else:
			_check(false, kind + " reported no change but moved the weapon")
		if changed and pose_moved: _movement_counts[kind] += 1
	if at_limit:
		var requested_world: Vector3 = requested.position_world
		var actual_world: Vector3 = after.pommel_world
		var request_distance: float = (before.pommel_world as Vector3).distance_to(requested_world)
		var travelled_distance: float = (before.pommel_world as Vector3).distance_to(actual_world)
		var target_gap: float = actual_world.distance_to(requested_world)
		outcome.merge({"requested_travel_m": request_distance, "actual_travel_m": travelled_distance,
			"unreached_target_distance_m": target_gap, "classification": "limited_move" if pose_moved else "limited_no_op",
			"joint_range_state": _context.actor.get_authoring_joint_range_debug_state()}, true)
		_check(request_distance > 1.0, "limit request is beyond ordinary arm reach")
		_check(target_gap > 0.05 and travelled_distance < request_distance - 0.05, "actual weapon stops before unreachable requested endpoint")
		_check(var_to_bytes(before.range_configuration) == var_to_bytes(after.range_configuration), "unreachable request preserves arm and wrist limit configuration")
	_action_outcomes.append(outcome)
	if kind == "roll":
		_check((before.hand_world as Transform3D).origin.distance_to((after.hand_world as Transform3D).origin) <= POSITION_GUARD_M, "Roll keeps wrist point fixed")
		_check((before.tip_world as Vector3).distance_to(after.tip_world) <= POSITION_GUARD_M, "Roll keeps Tip fixed")


func _sample_motion() -> Dictionary:
	var actor: Node3D = _context.actor
	var weapon: Node3D = _context.weapon
	var skeleton: Skeleton3D = actor.get("skeleton")
	var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_R_Hand"))
	var rotations: Dictionary = {}
	for name: StringName in Job.Rules.get_finger_bone_names(&"hand_right"):
		rotations[name] = skeleton.get_bone_pose_rotation(skeleton.find_bone(name))
	var motion: Resource = _ui._get_active_motion_node()
	var tip: Vector3 = weapon.to_global(weapon.get_meta("weapon_tip_local"))
	var pommel: Vector3 = weapon.to_global(weapon.get_meta("weapon_pommel_local"))
	var request: Dictionary = _owner.get("_requests").get(&"hand_right", {})
	return {"hand_world": hand, "weapon_world": weapon.global_transform,
		"world_reference_origin_id": ROOT, "hand_in_weapon": weapon.global_transform.affine_inverse() * hand,
		"hand_in_weapon_origin_id": Origins.ORIGIN_WEAPON_ROOT, "digit_rotations": rotations,
		"tip_world": tip, "pommel_world": pommel,
		"actual_tip_trajectory_local": _context.trajectory.to_local(tip),
		"actual_pommel_trajectory_local": _context.trajectory.to_local(pommel),
		"actual_endpoint_origin_id": Origins.ORIGIN_TRAJECTORY_AUTHORING,
		"authored_tip_local": motion.get("tip_position_local"), "authored_tip_origin_id": motion.get("tip_position_origin_id"),
		"authored_pommel_local": motion.get("pommel_position_local"), "authored_pommel_origin_id": motion.get("pommel_position_origin_id"),
		"authored_roll_degrees": motion.get("weapon_roll_degrees"),
		"authored_handle_coordinate": motion.get("grip_seat_slide_offset"),
		"authored_axial_offset": motion.get("axial_reposition_offset"),
		"station_weapon_local": weapon.get_meta("preview_primary_grip_seat_local"),
		"station_origin_id": weapon.get_meta("preview_primary_grip_seat_origin_id"),
		"request_serial": request.get("serial", -1), "request_key": request.get("key", ""),
		"owner_busy": _owner.get("_busy"), "owner_processing": _owner.is_processing(),
		"queued_requests": (_owner.get("_queue") as Array).size(),
		"range_configuration": _range_configuration(actor),
		"binding": actor.get_planar_grip_pose_state(&"hand_right")}


func _record(label: String, requested: Dictionary, changed: bool, duration_ms: float, before_action: Dictionary = {}) -> void:
	var sample := _sample_motion()
	var previous: Transform3D = _baseline.hand_in_weapon
	var current: Transform3D = sample.hand_in_weapon
	var position_error: float = ((sample.weapon_world as Transform3D).basis * (current.origin - previous.origin)).length()
	var basis_error := maxf(current.basis.x.distance_to(previous.basis.x), maxf(current.basis.y.distance_to(previous.basis.y), current.basis.z.distance_to(previous.basis.z)))
	var rotation_error := _quaternion_error(previous.basis.orthonormalized().get_rotation_quaternion(), current.basis.orthonormalized().get_rotation_quaternion())
	var largest_digit_error := 0.0
	for name: StringName in _baseline.digit_rotations:
		largest_digit_error = maxf(largest_digit_error, _quaternion_error(_baseline.digit_rotations[name], sample.digit_rotations[name]))
	var row := {"label": label, "requested": requested, "action_changed": changed,
		"action_duration_ms": duration_ms, "elapsed_ms": float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		"relative_position_error_m": position_error, "relative_basis_max_component_error": basis_error,
		"relative_rotation_error_rad": rotation_error, "maximum_digit_rotation_error_rad": largest_digit_error,
		"versus_action_start": _relative_error(_baseline if before_action.is_empty() else before_action, sample),
		"sample": sample}
	_actions.append(row)
	_check(position_error <= POSITION_GUARD_M and rotation_error <= ROTATION_GUARD_RAD and basis_error <= ROTATION_GUARD_RAD, label + " retains complete solved grip frame")
	_check(largest_digit_error <= ROTATION_GUARD_RAD, label + " retains all fifteen digit rotations")
	_check(sample.request_serial == _baseline.request_serial and sample.request_key == _baseline.request_key, label + " does not reacquire grip")
	_check(not sample.owner_busy and not sample.owner_processing and sample.queued_requests == 0, label + " performs no acquisition search")
	_check(var_to_bytes(sample.range_configuration) == var_to_bytes(_baseline.range_configuration), label + " keeps joint and reach limitations unchanged")
	var display_chain: Array = _ui.preview_presenter._build_resolved_display_motion_node_chain([_ui._get_active_motion_node()], 0, _context.root.get_meta("resolved_playback_state", {}))
	var display_motion: Resource = display_chain[0]
	var display_frame: Transform3D = _ui.preview_presenter._solve_weapon_segment_transform(_context.weapon, _context.trajectory, display_motion,
		_context.weapon.get_meta("weapon_tip_local"), _context.weapon.get_meta("weapon_pommel_local"),
		_context.trajectory.to_global(display_motion.tip_position_local), _context.trajectory.to_global(display_motion.pommel_position_local), display_motion.weapon_orientation_degrees)
	_check(display_frame.is_equal_approx(sample.weapon_world), label + " displayed packet keeps orientation and Roll coherent")
	print("PREPARED_GRIP_MOTION_SAMPLE=" + JSON.stringify({"label": label, "position_error_m": position_error, "rotation_error_rad": rotation_error, "digits_error_rad": largest_digit_error, "changed": changed}))


func _quaternion_error(before: Quaternion, after: Quaternion) -> float:
	var difference := before.inverse() * after
	return 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), absf(difference.w))


func _relative_error(before: Dictionary, after: Dictionary) -> Dictionary:
	var old_frame: Transform3D = before.hand_in_weapon
	var new_frame: Transform3D = after.hand_in_weapon
	return {"position_error_m": ((after.weapon_world as Transform3D).basis * (new_frame.origin - old_frame.origin)).length(),
		"rotation_error_rad": _quaternion_error(old_frame.basis.orthonormalized().get_rotation_quaternion(), new_frame.basis.orthonormalized().get_rotation_quaternion()),
		"basis_max_component_error": maxf(new_frame.basis.x.distance_to(old_frame.basis.x), maxf(new_frame.basis.y.distance_to(old_frame.basis.y), new_frame.basis.z.distance_to(old_frame.basis.z))),
		"reference_origin_id": Origins.ORIGIN_WEAPON_ROOT}


func _range_configuration(actor: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for property: StringName in [&"usable_arm_motion_range_ratio", &"pole_grip_arm_reach_margin_percent",
		&"enable_authoring_contact_wrist_basis", &"enable_authoring_limb_twist_distribution",
		&"authoring_contact_wrist_basis_strength", &"authoring_contact_wrist_straightness_bias",
		&"authoring_contact_wrist_twist_limit_degrees", &"authoring_shoulder_min_plane_angle_degrees",
		&"authoring_shoulder_max_plane_angle_degrees", &"authoring_elbow_min_plane_angle_degrees",
		&"authoring_elbow_max_plane_angle_degrees"]:
		out[property] = actor.get(property)
	out["right_max_arm_reach_m"] = actor.get_max_arm_chain_reach_meters(&"hand_right")
	out["right_usable_arm_reach_m"] = actor.get_usable_arm_chain_reach_meters(&"hand_right")
	return out


func _exercise_station_and_release() -> void:
	var actor: Node3D = _context.actor
	var old_request: Dictionary = _owner.get("_requests")[&"hand_right"].duplicate()
	var motion: Resource = _ui._get_active_motion_node()
	var old_coordinate: float = motion.get("grip_seat_slide_offset")
	var new_coordinate := 0.4 if old_coordinate < 0.3 else 0.2
	var changed: bool = _ui.set_selected_motion_node_grip_seat_slide(new_coordinate, false, false, false, true, false)
	var current_request: Dictionary = _owner.get("_requests").get(&"hand_right", {})
	var current_binding: Dictionary = actor.get_planar_grip_pose_state(&"hand_right")
	_check(changed, "actual Handle position edit accepted")
	_check(current_request.get("serial", -1) > old_request.serial and current_request.get("key", "") != old_request.key, "Handle position edit replaces previous relationship identity")
	_check(not _owner._is_current(&"hand_right", old_request), "Handle position edit rejects old solve result")
	_check((_owner.get("_primary_seat") as Dictionary).is_empty(), "Handle position edit discards old solved weapon seat")
	_check(not current_binding.get("has_grip_pose", true), "new Handle station has no stale acquired pose")
	_check(&"hand_right" in (_owner.get("_queue") as Array), "Handle position edit queues reacquisition")
	for frame: int in 2: await process_frame
	_check(not _owner.get("_busy") and _owner.get("_job") == null and not _owner.is_processing(), "queued Handle solve remains unexecuted in bounded verifier")
	_lifecycle["station_change"] = {"old_coordinate": old_coordinate, "new_coordinate": new_coordinate,
		"old_request": old_request, "new_request": current_request, "binding": current_binding,
		"status": _owner.status(), "search_performed": false}
	# The unarmed/open presenter remains a separate existing route. Release its
	# weapon source before asking for its cached open pose so no legacy contact
	# solve is started by this ownership test.
	var left_before: Dictionary = actor.get_planar_grip_pose_state(&"hand_left")
	_owner.clear()
	actor.clear_finger_grip_target(&"hand_right")
	var presenter = actor.get("finger_grip_presenter")
	_check(not actor.get_planar_grip_pose_state(&"hand_right").get("owned", true), "release removes primary pose ownership")
	_check(not presenter.planar_grip_rotation_lookup.has(&"hand_right"), "release removes retained digit override")
	_check((_owner.get("_queue") as Array).is_empty(), "release clears queued reacquisition")
	var skeleton: Skeleton3D = actor.get("skeleton")
	presenter._apply_animation_contact_open_pose(skeleton, &"hand_right")
	var open_rotations: Dictionary = {}
	var largest_difference := 0.0
	for name: StringName in Job.Rules.get_finger_bone_names(&"hand_right"):
		var rotation := skeleton.get_bone_pose_rotation(skeleton.find_bone(name))
		open_rotations[name] = rotation
		largest_difference = maxf(largest_difference, _quaternion_error(_baseline.digit_rotations[name], rotation))
	_check(largest_difference > ROTATION_GUARD_RAD, "existing open-hand route can replace the released grip")
	_check(actor.get_planar_grip_pose_state(&"hand_left") == left_before, "primary release leaves free opposite hand ownership unchanged")
	_lifecycle["release"] = {"right_binding": actor.get_planar_grip_pose_state(&"hand_right"),
		"left_binding": actor.get_planar_grip_pose_state(&"hand_left"), "open_rotations": open_rotations,
		"largest_difference_from_solved_grip_rad": largest_difference,
		"scope": "production_release_and_existing_open_pose_route_no_unarmed_ui_transition"}


func _finish() -> void:
	if is_instance_valid(_ui): _ui.close_ui()
	if is_instance_valid(_ui): _ui.queue_free()
	if is_instance_valid(_player): _player.queue_free()
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures,
		"scope": "hash_pinned_solved_grip_on_real_ui_controls_without_acquisition_search",
		"source_report": SOLVED_REPORT, "source_sha256": SOLVED_SHA, "fixture": _fixture,
		"search_performed": false, "source_grip_reconstructed": not _baseline.is_empty(),
		"support_integration_tested": false, "fresh_acquisition_tested": false,
		"whole_hand_skin_rigidity_tested": false, "movement_sequence": "sequential_with_idle_refresh_first",
		"first_failure": "" if _failures.is_empty() else _failures[0],
		"position_guard_m": POSITION_GUARD_M, "rotation_guard_rad": ROTATION_GUARD_RAD,
		"min_movement_m": MIN_MOVEMENT_M, "min_movement_rad": MIN_MOVEMENT_RAD,
		"actions": _actions, "action_outcomes": _action_outcomes, "real_movement_counts": _movement_counts,
		"lifecycle": _lifecycle, "elapsed_ms": float(Time.get_ticks_usec() - _started_usec) / 1000.0}
	var path := "C:/WORKSPACE/test_artifacts/verify_prepared_grip_motion_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_json_value(report), "\t")); file.close()
	print("PREPARED_GRIP_MOTION_RESULT=" + path + " checks=" + str(_checks) + " failures=" + str(_failures))
	quit(0 if _failures.is_empty() else 1)


func _json_value(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value: out[str(key)] = _json_value(value[key])
		return out
	if value is Array:
		var out: Array = []
		for entry: Variant in value: out.append(_json_value(entry))
		return out
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Quaternion: return [value.x, value.y, value.z, value.w]
	if value is Basis: return {"x": _json_value(value.x), "y": _json_value(value.y), "z": _json_value(value.z)}
	if value is Transform3D: return {"basis": _json_value(value.basis), "origin": _json_value(value.origin)}
	return value
