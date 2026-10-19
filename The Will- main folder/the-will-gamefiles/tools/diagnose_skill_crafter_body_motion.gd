extends "res://tools/diagnose_skill_slot_1_arm_extension_authority.gd"

# Reusable diagnostic, not a game controller. Uses real station drag authority,
# a cloned saved item, normal single-hand grip and actual rendered/bone output.
# See Skill Crafter Body Mobility Preparation 2026-10-19.md for usage and limits.
var options: Dictionary = {}
var output_dir := ""
var samples_file: FileAccess
var manifest: Dictionary = {"complete": false, "cases": []}
var sample_serial := 0
var hand_pass_index := 0
var hand_open_started_msec := 0

func _run_diagnostic() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	output_dir = String(options.get("out", "C:/WORKSPACE/godot_runs/body_motion_%d" % int(Time.get_unix_time_from_system())))
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Could not create diagnostic output directory")
		quit(1)
		return
	if FileAccess.file_exists(output_dir.path_join("manifest.json")):
		push_error("Use a fresh --out directory; previous evidence exists")
		quit(1)
		return
	samples_file = FileAccess.open(output_dir.path_join("samples.jsonl"), FileAccess.WRITE)
	if samples_file == null:
		push_error("Could not open diagnostic sample output")
		quit(1)
		return
	var source_path: String = ProjectSettings.globalize_path(PlayerForgeWipLibraryStateScript.DEFAULT_SAVE_FILE_PATH)
	var source: PlayerForgeWipLibraryState = ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayerForgeWipLibraryState
	if source == null:
		_fail("source_library_missing_or_unreadable")
		return
	var chosen: CraftedItemWIP = null
	for item: CraftedItemWIP in source.get_saved_wips():
		if item == null or item.latest_baked_profile_snapshot == null or not CraftedItemWIP.is_forge_v2_authoring_wip(item):
			continue
		if options.has("weapon"):
			if item.forge_project_name == String(options["weapon"]) or String(item.wip_id) == String(options["weapon"]):
				chosen = item
				break
		elif chosen == null or item.created_timestamp > chosen.created_timestamp:
			chosen = item
	if chosen == null:
		_fail("no_matching_baked_forge_v2_weapon")
		return
	manifest.merge({"weapon": chosen.forge_project_name, "source_wip_id": String(chosen.wip_id), "created_timestamp": chosen.created_timestamp, "selection": "explicit weapon" if options.has("weapon") else "latest created baked Forge V2 item", "source_path": source_path, "options": options, "scope": "normal single-hand, real station pommel drag, diagnostic evidence not a pass certificate"})
	print("BODY_MOTION weapon=%s out=%s" % [chosen.forge_project_name, output_dir])
	_write_manifest()
	var hands: PackedStringArray = String(options.get("hands", "R,L")).split(",")
	var elevations: PackedStringArray = String(options.get("elevations", "0,25")).split(",")
	var reuse_station: bool = String(options.get("reuse-station", "false")) == "true"
	manifest["reuse_station"] = reuse_station
	manifest["hand_order"] = hands
	var player: FakePlayer = null
	var ui: CombatAnimationStationUI = null
	var fixture: CraftedItemWIP = null
	for side: String in hands:
		hand_pass_index += 1
		if side != "R" and side != "L":
			_fail("hands_must_be_R_or_L")
			return
		if ui == null:
			var isolated := PlayerForgeWipLibraryStateScript.new()
			isolated.save_file_path = output_dir.path_join("isolated_%s_library.tres" % side)
			fixture = chosen.duplicate(true) as CraftedItemWIP
			fixture.grip_style_mode = CraftedItemWIP.GRIP_NORMAL
			fixture.ensure_combat_animation_station_state()
			isolated.saved_wips.append(fixture)
			isolated.selected_wip_id = fixture.wip_id
			player = FakePlayer.new()
			player.forge_wip_library_state = isolated
			root.add_child(player)
			ui = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
			ui.set_meta("verification_skip_persistence", true)
			root.add_child(ui)
			await _wait_frames(3)
			ui.open_for(player, "Body motion diagnostic: normal %s / skill slot 2" % side)
			await _wait_frames(4)
		hand_open_started_msec = Time.get_ticks_msec()
		var hand_slot: StringName = &"hand_right" if side == "R" else &"hand_left"
		var opened: bool = ui.open_saved_wip_with_hand_setup(fixture.wip_id, hand_slot, false, true)
		var slot_name: StringName = StringName(String(options.get("slot", "skill_slot_2")))
		var selected: bool = ui.select_skill_slot(slot_name, true)
		await _wait_frames(4)
		if not opened or not selected:
			_fail("station_or_slot_open_failed_%s" % side)
			return
		for elevation_text: String in elevations:
			var case_result: Dictionary = await _run_thrust(ui, side, elevation_text.to_float())
			case_result["hand_pass"] = hand_pass_index
			case_result["station_instance_id"] = ui.get_instance_id()
			case_result["actor_instance_id"] = _get_preview_actor(ui).get_instance_id()
			case_result["weapon_instance_id"] = _get_preview_held_item(ui).get_instance_id()
			manifest["cases"].append(case_result)
			_write_manifest()
			if not bool(case_result.get("complete", false)):
				if bool(case_result.get("warmup_only", false)):
					continue
				_fail("case_setup_or_motion_incomplete")
				return
		if not reuse_station:
			ui.queue_free()
			player.queue_free()
			await _wait_frames(4)
			ui = null
			player = null
	if is_instance_valid(ui):
		ui.queue_free()
		player.queue_free()
		await _wait_frames(4)
	manifest["complete"] = true
	manifest["sample_count"] = sample_serial
	_write_manifest()
	samples_file.close()
	print("BODY_MOTION complete samples=%d" % sample_serial)
	quit(0)

func _run_thrust(ui: CombatAnimationStationUI, side: String, elevation: float) -> Dictionary:
	var case_id := "%s_elevation_%.1f" % [side, elevation]
	print("BODY_MOTION begin " + case_id)
	if not ui.reset_active_draft_to_baseline():
		return {"case": case_id, "complete": false, "reason": "reset_failed"}
	await _wait_frames(4)
	_select_first_visible_skill_node(ui)
	await _wait_frames(3)
	var motion: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var actor: Node3D = _get_preview_actor(ui)
	var trajectory: Node3D = _get_trajectory_root(ui)
	var anchor: Node3D = _get_primary_grip_anchor(ui)
	if motion == null or actor == null or trajectory == null or anchor == null or motion.locked_for_authoring:
		return {"case": case_id, "complete": false, "reason": "missing_or_locked_context"}
	if motion.preferred_grip_style_mode != CraftedItemWIP.GRIP_NORMAL or ui.is_active_open_two_hand():
		return {"case": case_id, "complete": false, "reason": "not_normal_single_hand"}
	var initial_grip: Dictionary = await _await_applied_grip(ui, side)
	if not initial_grip.get("ready", false):
		return {"case": case_id, "complete": false, "reason": "initial_grip_not_ready", "grip": initial_grip}
	var sk: Skeleton3D = actor.get_node("JosieModel/Josie/Skeleton3D") as Skeleton3D
	# Character front is +Z by project convention, not Godot camera -Z.
	var direction_world: Vector3 = (actor.global_basis * Vector3(0.0, sin(deg_to_rad(elevation)), cos(deg_to_rad(elevation)))).normalized()
	var direction_local: Vector3 = (trajectory.global_basis.inverse() * direction_world).normalized()
	var length: float = motion.tip_position_local.distance_to(motion.pommel_position_local)
	ui.set_selected_motion_node_tip_position(motion.pommel_position_local + direction_local * length, false, false, false, true, false)
	await _wait_frames(3)
	# Move the gripping point in front of this shoulder before beginning the sweep.
	var shoulder: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Upperarm" % side)
	var desired_grip: Vector3 = shoulder + direction_world * 0.30 - actor.global_basis.y.normalized() * 0.12
	_attempt_grip_translation_with_ui(ui, desired_grip)
	await _wait_frames(3)
	var setup_grip: Dictionary = await _await_applied_grip(ui, side)
	if not setup_grip.get("ready", false):
		return {"case": case_id, "complete": false, "reason": "setup_grip_not_ready", "grip": setup_grip}
	motion = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", motion) as CombatAnimationMotionNode
	if display == null:
		return {"case": case_id, "complete": false, "reason": "missing_display_baseline"}
	# The actual accepted weapon axis is authoritative even if setup was constrained.
	direction_local = (display.tip_position_local - display.pommel_position_local).normalized()
	ui.call("_begin_preview_drag_override", display)
	ui.motion_node_editor.begin_drag(&"pommel", Vector2.ZERO, display)
	var base_pommel: Vector3 = display.pommel_position_local
	var baseline: Dictionary = _capture_bones(sk, side, {})
	var steps: int = clampi(int(options.get("steps", "20")), 2, 200)
	var travel: float = clampf(float(options.get("travel", "1.0")), 0.05, 3.0)
	var previous: Dictionary = {}
	var accepted_axis_world: Vector3 = (trajectory.global_basis * direction_local).normalized()
	var case_result: Dictionary = {"case": case_id, "complete": false, "steps_each_way": steps, "travel_m": travel, "accepted_axis_local": _vec(direction_local), "accepted_axis_world": _vec(accepted_axis_world), "requested_axis_world": _vec(direction_world), "setup_axis_error_degrees": rad_to_deg(acos(clampf(accepted_axis_world.dot(direction_world), -1.0, 1.0))), "requested_elevation_degrees": elevation, "initial_status": ui.footer_status_label.text, "wrist_cap_unchanged": actor.get("authoring_contact_wrist_twist_limit_degrees"), "snapshots": [], "samples": 0}
	case_result["initial_applied_grip"] = initial_grip
	case_result["setup_applied_grip"] = setup_grip
	for step: int in range(steps * 2 + 1):
		var distance: float = travel * float(step if step <= steps else steps * 2 - step) / float(steps)
		var requested: Vector3 = base_pommel + direction_local * distance
		var started: int = Time.get_ticks_usec()
		var before_authority: Dictionary = _capture_bones(sk, side, baseline)
		ui.call("_queue_pommel_drag_authority_target", requested, display.pommel_position_origin_id)
		var authority: Dictionary = ui.call("_resolve_pending_pommel_drag_authority", true)
		var after_authority: Dictionary = _capture_bones(sk, side, baseline)
		ui.preview_drag_refresh_pending = false
		ui.preview_drag_first_pending_msec = 0
		ui.call("_refresh_preview_scene")
		await _wait_frames(2)
		var row: Dictionary = _capture_motion(ui, sk, side, baseline)
		row["bones_before_authority"] = before_authority
		row["bones_after_authority"] = after_authority
		row["authority_local_rotation_change_degrees"] = _largest_bone_step(before_authority, after_authority)
		row["refresh_local_rotation_change_degrees"] = _largest_bone_step(after_authority, row["bones"])
		row.merge({"case": case_id, "step": step, "distance_m": distance, "phase": "out" if step <= steps else "back", "requested_pommel_local": _vec(requested), "authority": authority, "sample_serial": sample_serial, "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0})
		var jump: float = _largest_bone_step(previous, row["bones"])
		row["largest_local_rotation_step_degrees"] = jump
		previous = row["bones"]
		if step % 5 == 0 or jump > 25.0 or step == steps * 2:
			var image_name: String = "%s_%03d.png" % [case_id, step]
			var captured: bool = await _capture_frame(ui, actor, side, output_dir.path_join(image_name))
			if captured:
				row["image"] = image_name
				case_result["snapshots"].append(image_name)
		samples_file.store_line(JSON.stringify(row))
		samples_file.flush()
		sample_serial += 1
		case_result["samples"] += 1
		if step % 5 == 0:
			print("BODY_MOTION %s step=%d distance=%.2f jump=%.2f legal=%s" % [case_id, step, distance, jump, str(authority.get("legal", true))])
	ui.motion_node_editor.end_drag()
	ui.call("_clear_preview_drag_override")
	case_result["complete"] = true
	return case_result

func _capture_motion(ui: CombatAnimationStationUI, sk: Skeleton3D, side: String, baseline: Dictionary) -> Dictionary:
	var state: Dictionary = ui.get_preview_debug_state()
	var actor: Node3D = _get_preview_actor(ui)
	var shoulder: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Upperarm" % side)
	var elbow: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Forearm" % side)
	var hand: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Hand" % side)
	var upper: Vector3 = elbow - shoulder
	var lower: Vector3 = hand - elbow
	var normal: Vector3 = upper.cross(lower)
	var result: Dictionary = {"bones": _capture_bones(sk, side, baseline), "elbow_inner_angle_degrees": rad_to_deg(acos(clampf((-upper.normalized()).dot(lower.normalized()), -1.0, 1.0))), "elbow_plane_cross_length": normal.length(), "elbow_plane_character_space": _vec(actor.global_basis.inverse() * normal.normalized()), "shoulder_to_hand_m": shoulder.distance_to(hand), "arm_length_m": upper.length() + lower.length(), "status": ui.footer_status_label.text}
	var effective: CombatAnimationMotionNode = ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode
	result["accepted_pommel_local"] = _vec(effective.pommel_position_local)
	result["accepted_tip_local"] = _vec(effective.tip_position_local)
	result["drag_validation"] = ui.preview_drag_pommel_last_validation_result
	result["prepared_grip_readiness"] = _grip_readiness(ui, side)
	for key: String in ["dominant_grip_alignment_error_meters", "dominant_grip_target_world", "dominant_grip_anchor_world", "display_selected_pommel_position_local", "resolved_pommel_position_local", "authoring_contact_tether_metrics", "authoring_endpoint_legality_result", "collision_pose_legal", "body_self_collision_legal", "joint_range_debug_state", "grip_contact_debug_state"]:
		result[key] = state.get(key, null)
	return result

func _grip_readiness(ui: CombatAnimationStationUI, side: String) -> Dictionary:
	var actor: Node3D = _get_preview_actor(ui)
	var weapon: Node3D = _get_preview_held_item(ui)
	var owner: Node = actor.get_node_or_null("PreparedGripAcquisition") if actor != null else null
	if actor == null or weapon == null or owner == null:
		return {"ready": false, "status": "owner_missing"}
	var slot: StringName = &"hand_right" if side == "R" else &"hand_left"
	var statuses: Dictionary = owner.call("status")
	var status: Dictionary = statuses.get(slot, {})
	var binding: Dictionary = actor.call("get_planar_grip_pose_state", slot)
	var seat: Dictionary = weapon.get_meta("weapon_surface_seat_state", {})
	var requests: Dictionary = owner.get("_requests")
	var request: Dictionary = requests.get(slot, {})
	var request_fields: Array = bytes_to_var(String(request.get("key", "")).hex_decode()) if not String(request.get("key", "")).is_empty() else []
	var identity: Dictionary = {"request_key": request.get("key", ""), "primary_seat_local": str(weapon.get_meta("preview_primary_grip_seat_local", null))}
	var motion: CombatAnimationMotionNode = ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode
	var span_start: Vector3 = weapon.get_meta("primary_grip_span_start_local", Vector3.ZERO)
	var span_end: Vector3 = weapon.get_meta("primary_grip_span_end_local", Vector3.ZERO)
	identity["span_length_local_m"] = span_start.distance_to(span_end)
	identity["span_length_world_m"] = (weapon.global_basis * (span_end - span_start)).length()
	identity["weapon_world_scale"] = _vec(weapon.global_basis.get_scale())
	identity["hand_spans_m"] = weapon.get_meta("hand_grip_spans_meters", {})
	identity["end_bounds_now"] = ui.preview_presenter.get_held_item_hand_end_bounds(weapon, slot)
	identity["requested_slide"] = motion.grip_seat_slide_offset
	identity["requested_axial"] = motion.axial_reposition_offset
	var seat_now: Dictionary = ui.preview_presenter.call("_resolve_primary_grip_seat_state_from_offsets", weapon, motion.grip_seat_slide_offset, motion.axial_reposition_offset)
	identity["resolved_station_now"] = _vec(seat_now.get("position", Vector3.ZERO) as Vector3)
	identity["resolved_ratio_now"] = seat_now.get("ratio")
	if request_fields.size() >= 9:
		identity["station_local"] = _vec(request_fields[5] as Vector3)
		identity["style"] = request_fields[7]
		identity["geometry"] = str(request_fields[8])
	return {"ready": bool(owner.call("_primary_ready_for_support")) and bool(binding.get("has_grip_pose", false)), "status": status.get("status", "pending"), "reason": status.get("reason", ""), "seat_status": String(seat.get("status", "")), "binding": binding, "status_details": status, "identity": identity}

func _await_applied_grip(ui: CombatAnimationStationUI, side: String) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var last_print: int = started - 5000
	var state: Dictionary = {}
	var retried_stale_setup := false
	while Time.get_ticks_msec() - started < 90000:
		state = _grip_readiness(ui, side)
		if state.get("ready", false):
			state["wait_ms"] = Time.get_ticks_msec() - started
			state["retried_stale_setup"] = retried_stale_setup
			return state
		if String(state.get("status", "")) in ["unresolved", "unavailable", "cancelled"]:
			# Opening/selecting/resetting can obsolete the asynchronously captured
			# setup pose. Retry that specific case once after all setup has stopped.
			if not retried_stale_setup and state.get("reason", "") == "source_pose_changed_during_acquisition":
				retried_stale_setup = true
				print("BODY_MOTION reacquire_stable_setup side=" + side)
				ui.preview_presenter.reacquire_grip(ui.preview_subviewport)
				await _wait_frames(3)
				continue
			state["retried_stale_setup"] = retried_stale_setup
			return state
		if Time.get_ticks_msec() - last_print >= 5000:
			print("BODY_MOTION waiting_grip side=%s status=%s" % [side, state.get("status", "")])
			last_print = Time.get_ticks_msec()
		await _wait_frames(3)
	state["wait_timeout"] = true
	return state

func _capture_bones(sk: Skeleton3D, side: String, baseline: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var rig: PlayerHumanoidRig = sk.get_parent().get_parent().get_parent() as PlayerHumanoidRig
	var helper_neutrals: Dictionary = rig.authoring_limb_twist_neutral_rotation_lookup if rig != null else {}
	var names: Array[String] = ["CC_Base_Waist", "CC_Base_Spine01", "CC_Base_Spine02"]
	for suffix: String in ["Clavicle", "Upperarm", "Forearm", "Hand", "UpperarmTwist01", "UpperarmTwist02", "ForearmTwist01", "ForearmTwist02"]:
		names.append("CC_Base_%s_%s" % [side, suffix])
	for bone: String in names:
		var index: int = sk.find_bone(bone)
		if index < 0:
			continue
		var local: Quaternion = sk.get_bone_pose_rotation(index).normalized()
		var world: Transform3D = sk.global_transform * sk.get_bone_global_pose(index)
		var delta: Quaternion = local
		if baseline.has(bone):
			delta = (_quat(baseline[bone]["local_quaternion"]).inverse() * local).normalized()
		var vector := Vector3(delta.x, delta.y, delta.z)
		var signed_twist: float = wrapf(2.0 * atan2(vector.dot(Vector3.UP), delta.w), -PI, PI)
		var rest_delta: Quaternion = (sk.get_bone_rest(index).basis.orthonormalized().get_rotation_quaternion().inverse() * local).normalized()
		var rest_twist: float = wrapf(2.0 * atan2(rest_delta.y, rest_delta.w), -PI, PI)
		result[bone] = {"local_quaternion": [local.x, local.y, local.z, local.w], "world_position": _vec(world.origin), "world_quaternion": [world.basis.get_rotation_quaternion().x, world.basis.get_rotation_quaternion().y, world.basis.get_rotation_quaternion().z, world.basis.get_rotation_quaternion().w], "baseline_relative_local_y_twist_degrees": rad_to_deg(signed_twist), "rest_relative_local_y_twist_degrees": rad_to_deg(rest_twist)}
		if helper_neutrals.has(StringName(bone)):
			var helper_neutral: Quaternion = helper_neutrals[StringName(bone)]
			var helper_delta: Quaternion = (helper_neutral.inverse() * local).normalized()
			result[bone]["cached_neutral_relative_y_twist_degrees"] = rad_to_deg(wrapf(2.0 * atan2(helper_delta.y, helper_delta.w), -PI, PI))
	return result

func _largest_bone_step(previous: Dictionary, current: Dictionary) -> float:
	var largest := 0.0
	for bone: String in previous:
		if current.has(bone):
			largest = maxf(largest, rad_to_deg(_quat(previous[bone]["local_quaternion"]).angle_to(_quat(current[bone]["local_quaternion"]))))
	return largest

func _capture_frame(ui: CombatAnimationStationUI, actor: Node3D, side: String, path: String) -> bool:
	if DisplayServer.get_name().to_lower() == "headless":
		return false
	var camera: Camera3D = ui.call("_get_preview_camera") as Camera3D
	if camera == null:
		return false
	var sign_side: float = 1.0 if side == "R" else -1.0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.55
	camera.global_position = actor.to_global(Vector3(sign_side * 2.1, 1.65, 2.2))
	camera.look_at(actor.to_global(Vector3(sign_side * 0.12, 1.35, 0.30)), actor.global_basis.y.normalized())
	ui.preview_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	var shot: Image = ui.preview_subviewport.get_texture().get_image()
	return shot != null and not shot.is_empty() and shot.save_png(path) == OK

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _quat(value: Array) -> Quaternion:
	return Quaternion(float(value[0]), float(value[1]), float(value[2]), float(value[3])).normalized()

func _write_manifest() -> void:
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()

func _fail(reason: String) -> void:
	manifest["failure"] = reason
	_write_manifest()
	push_error("BODY_MOTION " + reason)
	quit(1)
