extends "res://tools/verify_weapon_roll_manipulation.gd"

const CoherentSkinCapture = preload("res://tools/grip_plane_proof/capture_coherent_skin_pose.gd")
const PlacementStageCapture = preload("res://tools/grip_plane_proof/capture_grip_placement_stage.gd")
const AnatomyStore = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const ANATOMY_SIGNATURE := "0fb9e5dbe88cd71e342f4efe106676026345d283374abede7dc98853dd784bf5"
const ANATOMY_PATH := "res://tools/grip_plane_proof/prepared_characters/josie/" + ANATOMY_SIGNATURE + ".tres"

class AuditSeat:
	extends "res://runtime/player/player_hand_surface_seat_solver.gd"
	var last_input: Dictionary = {}
	var last_result: Dictionary = {}
	var actor: Node3D
	var held: Node3D
	var coherent_anatomy: Resource
	var placement_transaction: Dictionary = {}
	func solve_prepared(surface: Dictionary, anatomy: Dictionary, c0: Vector3, ci: Vector3, cp: Vector3, axis: Vector3, surface_origin: StringName, world_origin: StringName) -> Dictionary:
		last_input = anatomy.duplicate(true)
		if OS.get_environment("THE_WILL_PROBE_FULL_PROXIMAL") == "1":
			last_input["enforce_ordinary_proximal_safety"] = true
		if OS.get_environment("THE_WILL_CAPTURE_GRIP_PLACEMENT") == "1" and not placement_transaction.is_empty():
			var captured: Dictionary = PlacementStageCapture.new().capture(actor, held, coherent_anatomy,
				placement_transaction.slot, &"seat_solver_input", placement_transaction.serial,
				placement_transaction.solver_inputs.size())
			captured["seat_input"] = {"c0": c0, "ci": ci, "cp": cp, "axis": axis,
				"c0_origin_id": world_origin, "ci_origin_id": world_origin,
				"cp_origin_id": world_origin, "axis_origin_id": world_origin,
				"surface_origin_id": surface_origin, "world_origin_id": world_origin,
				"anatomy": last_input.duplicate(true)}
			if not c0.is_finite() or not ci.is_finite() or not cp.is_finite() or not axis.is_finite() or axis.is_zero_approx() or surface_origin == StringName() or world_origin != &"RL_BoneRoot":
				captured["valid"] = false
				captured["reason"] = "invalid_seat_input_coordinates_or_origins"
			placement_transaction.solver_inputs.append(captured)
		last_result = super.solve_prepared(surface, last_input, c0, ci, cp, axis, surface_origin, world_origin)
		return last_result

class AuditPresenter:
	extends "res://runtime/combat/combat_animation_station_preview_presenter.gd"
	var audit: AuditSeat
	var handoff: Dictionary = {}
	var anchor_samples: Array = []
	var coherent_anatomy: Resource
	var placement_transactions: Array = []
	var placement_capture_errors: Array = []
	var placement_serial: int = 0
	func _resolve_preview_hand_mounted_transform(actor: Node3D, held: Node3D, grip_override: Variant = null, mount_override: Variant = null) -> Transform3D:
		var result: Transform3D = super._resolve_preview_hand_mounted_transform(actor, held, grip_override, mount_override)
		var slot: StringName = _resolve_preview_dominant_slot_id()
		var anchor: Node3D = _resolve_preview_mount_anchor_for_slot(actor, slot)
		var wrist: Dictionary = actor.capture_authoring_wrist_origin(slot)
		if anchor == null or not bool(wrist.get("available", false)):
			return result
		# Diagnostic read: current Hand -> RL_BoneRoot -> world, followed by the
		# existing item-anchor offset in that Hand frame. No pose is written here.
		var current: Transform3D = wrist["machine_to_world"] * wrist["origin_record"].resolved_transform_to_machine * anchor.transform
		var cached: Transform3D = anchor.global_transform
		anchor_samples.append({"slot": slot, "position_error_meters": cached.origin.distance_to(current.origin), "basis_error_degrees": rad_to_deg(cached.basis.orthonormalized().get_rotation_quaternion().angle_to(current.basis.orthonormalized().get_rotation_quaternion()))})
		return result
	func _apply_preview_weapon_surface_seat(actor: Node3D, held: Node3D, allow_solve: bool) -> Dictionary:
		var placement_enabled := OS.get_environment("THE_WILL_CAPTURE_GRIP_PLACEMENT") == "1"
		var transaction: Dictionary = {}
		if placement_enabled:
			placement_serial += 1
			var slot: StringName = _resolve_preview_dominant_slot_id()
			transaction = {"serial": placement_serial, "slot": slot, "allow_surface_solve": allow_solve,
				"solver_inputs": [], "finger_inputs": [], "result": {},
				"before": PlacementStageCapture.new().capture(actor, held, coherent_anatomy, slot, &"before_surface_seat", placement_serial)}
			placement_transactions.append(transaction)
		if actor != null and not actor.finger_grip_presenter.hand_surface_seat_solver is AuditSeat:
			audit = AuditSeat.new()
			actor.finger_grip_presenter.hand_surface_seat_solver = audit
			actor.finger_grip_presenter.surface_grasp_solver = AuditFinger.new()
		if actor != null and actor.finger_grip_presenter.surface_grasp_solver is AuditFinger:
			actor.finger_grip_presenter.surface_grasp_solver.actor = actor
			actor.finger_grip_presenter.surface_grasp_solver.held = held
			actor.finger_grip_presenter.surface_grasp_solver.coherent_anatomy = coherent_anatomy
			actor.finger_grip_presenter.surface_grasp_solver.placement_transaction = transaction
			actor.finger_grip_presenter.surface_grasp_solver.placement_capture_errors = placement_capture_errors
		if actor != null and actor.finger_grip_presenter.hand_surface_seat_solver is AuditSeat:
			audit = actor.finger_grip_presenter.hand_surface_seat_solver
			audit.actor = actor
			audit.held = held
			audit.coherent_anatomy = coherent_anatomy
			audit.placement_transaction = transaction
		var result: Dictionary = super._apply_preview_weapon_surface_seat(actor, held, allow_solve)
		if placement_enabled:
			# The observed after state remains independent of acceptance/rejection.
			transaction["after"] = PlacementStageCapture.new().capture(actor, held, coherent_anatomy,
				transaction.slot, &"after_surface_seat", transaction.serial)
			transaction["result"] = result.duplicate(true)
		if audit != null and actor != null:
			var after: Dictionary = actor.resolve_hand_surface_seat_anatomy_state(_resolve_preview_dominant_slot_id())
			handoff = {"anatomy_before": audit.last_input, "anatomy_after_seat": after}
		return result

class AuditFinger:
	extends "res://runtime/player/player_finger_surface_grip_solver.gd"
	var sweeps: Dictionary = {}
	var sweep_slot: StringName
	var captured_inputs: Dictionary = {}
	var captured_surface: Dictionary = {}
	var captured_frame: Dictionary = {}
	var actor: Node3D
	var held: Node3D
	var character_samples: Dictionary = {}
	var captured_object: Dictionary = {}
	var coherent_anatomy: Resource
	var posed_character: Dictionary = {}
	var coherent_solve_serial: int = 0
	var placement_transaction: Dictionary = {}
	var placement_capture_errors: Array = []
	func solve_prepared(skeleton: Skeleton3D, surface: Dictionary, slot: StringName, rules: Dictionary, options: Dictionary = {}) -> Dictionary:
		var placement_enabled := OS.get_environment("THE_WILL_CAPTURE_GRIP_PLACEMENT") == "1"
		var coherent_enabled := OS.get_environment("THE_WILL_CAPTURE_COHERENT_SKIN") == "1" or placement_enabled
		sweeps = {}
		captured_inputs = {}
		captured_surface = surface
		captured_frame = {}
		posed_character = {}
		var root_index := skeleton.find_bone("RL_BoneRoot")
		if skeleton.is_inside_tree() and root_index >= 0:
			var machine_to_world: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(root_index)
			if machine_to_world.is_finite() and absf(machine_to_world.basis.determinant()) > 0.000000001:
				captured_frame = {"machine_to_world": machine_to_world, "machine_origin_id": &"RL_BoneRoot", "resolve_phase": &"editor_preview", "capture_stage": &"finger_solve_input"}
		sweep_slot = slot
		if (OS.get_environment("THE_WILL_CAPTURE_CHARACTER_CONTACT") == "1" or coherent_enabled) and actor != null and held != null and not captured_frame.is_empty():
			# Coherent capture validates against the saved reference directly. Its
			# opt-in path does not re-extract/bake anatomy through the older sampler.
			if character_samples.is_empty() and not coherent_enabled:
				var sampler = load("res://tools/grip_plane_proof/capture_model_skin_samples.gd").new()
				var names: Array[StringName] = []
				for side: String in ["R", "L"]:
					for digit: String in ["Mid", "Thumb"]:
						for index: int in range(1, 4):
							names.append(StringName("CC_Base_%s_%s%d" % [side, digit, index]))
				character_samples = sampler.capture(skeleton, actor.mesh_instance, names)
				print("CHARACTER_SKIN_CAPTURE=" + JSON.stringify({"valid": character_samples.get("valid"), "reason": character_samples.get("reason"), "bind_error": character_samples.get("max_bind_reference_component_error")}))
			captured_object = {}
			for child: Node in held.get_children():
				if child is MeshInstance3D and child.get_meta("visual_mesh_source", StringName()) == &"editable_mesh":
					var object_origin := StringName("GripProofObjectContactSurfaceOrigin")
					var object_to_machine: Transform3D = captured_frame["machine_to_world"].affine_inverse() * child.global_transform
					captured_object = {"surface": prepare_surface(child.mesh, child.global_transform, {"surface_source_origin_id": object_origin, "resolved_world_origin_id": &"RL_BoneRoot"}), "origin_record": {"origin_id": object_origin, "parent_origin_id": &"RL_BoneRoot", "transform_to_parent": object_to_machine, "owner_system": &"grip_plane_proof", "resolve_phase": &"editor_preview", "is_dynamic": true}, "visual_mesh_source": child.get_meta("visual_mesh_source")}
					break
		if coherent_enabled:
			coherent_solve_serial += 1
			var process_frame_id := Engine.get_process_frames()
			if coherent_anatomy == null or actor == null:
				posed_character = {"valid": false, "reason": "missing_validated_anatomy_or_actor"}
			else:
				posed_character = CoherentSkinCapture.new().capture(skeleton, actor.mesh_instance,
					coherent_anatomy.reference_skin, coherent_anatomy.source_signature,
					StringName("%sFingerSolveInputPoseFrame%dSolve%d" % [String(slot), process_frame_id, coherent_solve_serial]))
			posed_character["capture_stage"] = &"finger_solve_input"
			posed_character["engine_process_frame"] = process_frame_id
			posed_character["solve_serial"] = coherent_solve_serial
			posed_character["prepared_anatomy_path"] = ANATOMY_PATH
		if placement_enabled:
			if placement_transaction.is_empty() or placement_transaction.get("slot") != slot:
				placement_capture_errors.append({"reason": "finger_input_has_no_matching_seat_transaction", "slot": slot,
					"solve_serial": coherent_solve_serial, "transaction_serial": placement_transaction.get("serial", -1)})
			else:
				posed_character["transaction_serial"] = placement_transaction.serial
				posed_character["pose_id"] = StringName("%sTransaction%d" % [String(posed_character.get("pose_id", StringName())), placement_transaction.serial])
				var finger_stage: Dictionary = PlacementStageCapture.new().capture(actor, held, coherent_anatomy,
					slot, &"finger_solve_input", placement_transaction.serial,
					placement_transaction.finger_inputs.size(), posed_character)
				placement_transaction.finger_inputs.append(finger_stage)
		return super.solve_prepared(skeleton, surface, slot, rules, options)
	func _capture_digit_snapshot(skeleton: Skeleton3D, rules: Dictionary, supplied: Dictionary = {}) -> Dictionary:
		var snapshot: Dictionary = super._capture_digit_snapshot(skeleton, rules, supplied)
		snapshot["tip_offset_origin_id"] = rules.get("tip_offset_origin_id", StringName())
		return snapshot
	func _solve_digit(snapshot: Dictionary, surface: Dictionary, preferred: float, cap: float, options: Dictionary, stats: Dictionary) -> Dictionary:
		captured_inputs[snapshot.get("digit_id")] = {"snapshot": snapshot.duplicate(true), "options": options.duplicate(true), "preferred": preferred, "cap": cap}
		var result: Dictionary = super._solve_digit(snapshot, surface, preferred, cap, options, stats)
		var sweep_mode := OS.get_environment("THE_WILL_PROBE_PROXIMAL_SWEEP")
		if sweep_mode in ["1", "extended"] and not bool(snapshot.get("is_thumb", false)) and not bool(result.get("diagnostics", {}).get("overlap_limit_respected", false)):
			var angles: Array[float] = _resolve_open_angles(snapshot)
			var closed: Array[float] = _resolve_closed_angles(snapshot, angles)
			var targets: Array[float] = []
			targets.assign(snapshot.get("section_target_overlaps_meters", [preferred, preferred, preferred]))
			var rows: Array = []
			var step_count := 46 if sweep_mode == "extended" else 14
			for step: int in range(step_count):
				angles[0] = deg_to_rad(-45.0 + 5.0 * float(step)) * signf(closed[0]) if sweep_mode == "extended" else lerpf(_resolve_open_angles(snapshot)[0], closed[0], float(step) / 13.0)
				var safety: Dictionary = _query_downstream_section_safety(snapshot, surface, angles, 0, _resolve_fallback_ray_target(options), 0.18, targets, cap, {})
				var sections: Array = []
				for section: Dictionary in safety.get("section_states", []):
					sections.append({"index": section.get("section_index"), "signed_overlap": section.get("signed_overlap_meters"), "safe": section.get("within_overlap_limit")})
				rows.append({"angle": rad_to_deg(angles[0]), "safe": safety.get("safe"), "sections": sections})
			sweeps[snapshot.get("digit_id")] = rows
		return result

# Inspect actual acquisition on a copy of the saved weapon. A completed
# diagnostic is not a grip acceptance test; reported rejection remains rejection.
func _run() -> void:
	var placement_enabled := OS.get_environment("THE_WILL_CAPTURE_GRIP_PLACEMENT") == "1"
	var coherent_enabled := OS.get_environment("THE_WILL_CAPTURE_COHERENT_SKIN") == "1" or placement_enabled
	var anatomy: Resource
	if coherent_enabled:
		var isolated := _coherent_user_data_guard()
		if not bool(isolated.get("valid", false)):
			push_error("COHERENT_SKIN_CAPTURE_REFUSED=" + JSON.stringify(isolated))
			quit(1)
			return
		print("COHERENT_SKIN_CAPTURE_USER_ROOT=" + String(isolated.user_root))
		var loaded := AnatomyStore.new().load_matching(ANATOMY_PATH, ANATOMY_SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
		if not bool(loaded.get("valid", false)):
			push_error("COHERENT_SKIN_CAPTURE_REFUSED=" + JSON.stringify(loaded))
			quit(1)
			return
		anatomy = loaded.resource
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
	ui.preview_presenter = AuditPresenter.new()
	ui.preview_presenter.coherent_anatomy = anatomy
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await process_frame
	ui.open_for(player, "Grip acquisition diagnostic")
	var rows: Array = []
	for slot: StringName in [&"hand_right", &"hand_left"]:
		print("GRIP_ACQUISITION_CHECKING=" + String(slot))
		ui.preview_presenter.anchor_samples = []
		ui.preview_presenter.placement_transactions = []
		ui.preview_presenter.placement_capture_errors = []
		ui.open_saved_wip_with_hand_setup(chosen.get("wip_id"), slot, false, false)
		ui.select_skill_slot(&"skill_slot_1", true)
		await process_frame
		var context: Dictionary = ui.preview_presenter.call("_weapon_roll_context", ui.preview_subviewport)
		var actor: Node3D = context["actor"]
		var seat: Dictionary = actor.call("get_weapon_surface_seat_debug_state", slot)
		var state: Dictionary = actor.finger_grip_presenter.get_surface_grasp_debug_state(slot)
		var diagnostic: Dictionary = state.get("last_attempt_diagnostics", state.get("diagnostics", {}))
		var row := {"slot": slot, "seat": _scalars(seat), "seat_diagnostics": _scalars(seat.get("diagnostics", {})), "grip": _scalars(state), "grip_diagnostics": _scalars(diagnostic), "digits": {}}
		row["handoff"] = ui.preview_presenter.handoff.duplicate(true)
		row["anchor_samples"] = ui.preview_presenter.anchor_samples.duplicate(true)
		row["proximal_sweeps"] = actor.finger_grip_presenter.surface_grasp_solver.sweeps.duplicate(true) if actor.finger_grip_presenter.surface_grasp_solver.sweep_slot == slot else {}
		row["full_proximal_check"] = OS.get_environment("THE_WILL_PROBE_FULL_PROXIMAL") == "1"
		row["sweep_mode"] = OS.get_environment("THE_WILL_PROBE_PROXIMAL_SWEEP")
		if coherent_enabled and actor.finger_grip_presenter.surface_grasp_solver.sweep_slot != slot:
			push_error("COHERENT_SKIN_CAPTURE_FAILED=no_solve_capture_for_requested_hand")
			quit(1)
			return
		if (OS.get_environment("THE_WILL_CAPTURE_GRIP_INPUTS") == "1" or coherent_enabled) and actor.finger_grip_presenter.surface_grasp_solver.sweep_slot == slot:
			var posed_character: Dictionary = actor.finger_grip_presenter.surface_grasp_solver.posed_character
			if coherent_enabled and not bool(posed_character.get("valid", false)):
				push_error("COHERENT_SKIN_CAPTURE_FAILED=" + JSON.stringify(posed_character))
				quit(1)
				return
			var capture_path := "C:/WORKSPACE/test_artifacts/grip_solver_inputs_" + String(slot) + "_" + Time.get_datetime_string_from_system().replace(":", "-") + ".bin"
			var capture_file := FileAccess.open(capture_path, FileAccess.WRITE)
			var weapon: Node3D = context["weapon"]
			var capture_packet := {
				"slot": slot,
				"capture_frame": actor.finger_grip_presenter.surface_grasp_solver.captured_frame,
				"character_skin": actor.finger_grip_presenter.surface_grasp_solver.character_samples,
				"object_contact": actor.finger_grip_presenter.surface_grasp_solver.captured_object,
				"surface": actor.finger_grip_presenter.surface_grasp_solver.captured_surface,
				"digits": actor.finger_grip_presenter.surface_grasp_solver.captured_inputs,
				"observation_weapon_world": weapon.global_transform,
				"observation_weapon_world_origin_id": &"RL_BoneRoot",
				"weapon_tip_local": weapon.get_meta("weapon_tip_local"),
				"weapon_tip_local_origin_id": weapon.get_meta("weapon_tip_origin_id"),
				"weapon_pommel_local": weapon.get_meta("weapon_pommel_local"),
				"weapon_pommel_local_origin_id": weapon.get_meta("weapon_pommel_origin_id"),
			}
			if coherent_enabled:
				capture_packet["posed_character"] = posed_character
			capture_file.store_var(capture_packet)
			capture_file.close()
			row["solver_input_capture"] = capture_path
			print("GRIP_SOLVER_INPUT_CAPTURE=" + capture_path)
		if placement_enabled:
			var trace := {"schema": &"grip_placement_trace_v1", "slot": slot, "anatomy_signature": ANATOMY_SIGNATURE,
				"root_origin_id": &"RL_BoneRoot", "resolve_phase": &"editor_preview", "transactions": [],
				"production_pose_written_by_capture": false, "actual_3d_grip_verified": false,
				"capture_errors": ui.preview_presenter.placement_capture_errors.duplicate(true),
				"stage_reference_provenance": &"existing_derived_mount_target_not_measured_palm_center"}
			for transaction: Dictionary in ui.preview_presenter.placement_transactions:
				if transaction.slot == slot:
					trace.transactions.append(transaction)
			var checked := _validate_placement_trace(trace)
			trace["valid"] = checked.valid
			trace["validation"] = checked
			var trace_path := "C:/WORKSPACE/test_artifacts/grip_placement_trace_" + String(slot) + "_" + Time.get_datetime_string_from_system().replace(":", "-") + ".bin"
			var trace_file := FileAccess.open(trace_path, FileAccess.WRITE)
			if trace_file == null:
				push_error("GRIP_PLACEMENT_CAPTURE_FAILED=cannot_write_trace")
				quit(1)
				return
			trace_file.store_var(trace)
			trace_file.close()
			row["placement_trace_capture"] = trace_path
			print("GRIP_PLACEMENT_TRACE_CAPTURE=" + trace_path)
			print("GRIP_PLACEMENT_TRACE_COUNTS=" + JSON.stringify(checked))
			if not bool(checked.valid):
				push_error("GRIP_PLACEMENT_CAPTURE_FAILED=" + JSON.stringify(checked))
				quit(1)
				return
		row["seat_best"] = (seat.get("diagnostics", {}) as Dictionary).get("best_accepted", (seat.get("diagnostics", {}) as Dictionary).get("best_overall", {}))
		for digit: Variant in (diagnostic.get("digit_results", {}) as Dictionary):
			var result: Dictionary = diagnostic["digit_results"][digit]
			var brief: Dictionary = _scalars(result)
			for section_key: String in ["final_sections", "attempted_final_sections", "section_contacts"]:
				brief[section_key] = []
				for section: Dictionary in result.get(section_key, []):
					brief[section_key].append(_scalars(section))
			row["digits"][digit] = brief
		rows.append(row)
		print("GRIP_ACQUISITION=" + JSON.stringify({"slot": slot, "seat_status": seat.get("status"), "grip_status": diagnostic.get("status"), "unsafe_digits": diagnostic.get("unsafe_digit_count")}))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "C:/WORKSPACE/test_artifacts/grip_acquisition_" + stamp + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	print("GRIP_ACQUISITION_RESULT=" + path)
	ui.queue_free()
	player.queue_free()
	await process_frame
	quit(0)

func _validate_placement_trace(trace: Dictionary) -> Dictionary:
	var errors: Array = trace.capture_errors.duplicate(true)
	var stages := 0
	var seat_inputs := 0
	var finger_inputs := 0
	var capture_ms := 0.0
	var reused_pose_capture_ms := 0.0
	var pose_ids := {}
	for transaction: Dictionary in trace.transactions:
		var observations: Array = [transaction.get("before", {}), transaction.get("after", {})]
		observations.append_array(transaction.solver_inputs)
		observations.append_array(transaction.finger_inputs)
		seat_inputs += transaction.solver_inputs.size()
		finger_inputs += transaction.finger_inputs.size()
		for stage: Dictionary in observations:
			stages += 1
			if not bool(stage.get("valid", false)):
				errors.append({"transaction_serial": transaction.serial, "stage": stage.get("stage"), "reason": stage.get("reason", "missing_stage")})
				continue
			if stage.get("transaction_serial") != transaction.serial or stage.get("slot") != transaction.slot:
				errors.append({"transaction_serial": transaction.serial, "reason": "stage_transaction_mismatch"})
			var pose_id: StringName = stage.posed_character.pose_id
			if pose_ids.has(pose_id):
				errors.append({"transaction_serial": transaction.serial, "reason": "duplicate_stage_pose_id", "pose_id": pose_id})
			pose_ids[pose_id] = true
			capture_ms += float(stage.get("capture_ms", 0.0))
			if bool(stage.get("reused_synchronous_pose_capture", false)):
				reused_pose_capture_ms += float(stage.posed_character.get("capture_ms", 0.0))
	if trace.transactions.is_empty() or seat_inputs == 0 or finger_inputs == 0:
		errors.append({"reason": "requested_hand_has_no_complete_placement_observation"})
	return {"valid": errors.is_empty(), "errors": errors, "transaction_count": trace.transactions.size(),
		"stage_count": stages, "seat_input_count": seat_inputs, "finger_input_count": finger_inputs,
		"capture_ms": capture_ms, "reused_pose_capture_ms": reused_pose_capture_ms,
		"timing_scope": &"diagnostic_capture_only_not_solver_or_bvh_cost", "actual_3d_grip_verified": false}

func _coherent_user_data_guard() -> Dictionary:
	# Engine startup has already selected user://. The launch process must set
	# APPDATA before starting Godot; this guard refuses UI/resource reads when the
	# result is not the exact explicitly declared workspace test directory.
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	if not expected.is_absolute_path() or not expected.to_lower().begins_with("c:/workspace/"):
		return {"valid": false, "reason": "missing_explicit_workspace_user_root"}
	var actual := OS.get_user_data_dir().replace("\\", "/").simplify_path().trim_suffix("/")
	var globalized := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().trim_suffix("/")
	if actual.to_lower() != expected.to_lower() or globalized.to_lower() != expected.to_lower():
		return {"valid": false, "reason": "user_directory_does_not_match_workspace_isolation", "expected": expected, "actual": actual, "globalized": globalized}
	return {"valid": true, "user_root": actual}

func _scalars(source: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for key: Variant in source:
		var value: Variant = source[key]
		if value is Dictionary or value is Object:
			continue
		if value is Array:
			if value.size() > 15:
				continue
			var nested := false
			for item: Variant in value:
				if item is Dictionary or item is Array or item is Object:
					nested = true
			if nested:
				continue
		output[key] = value
	return output
