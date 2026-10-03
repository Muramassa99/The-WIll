extends SceneTree

## Natural Skill Crafter activation and realized-pose observation. No historical
## candidate, pose injection, owner suppression, save, or alternate solve path.
## Run through the supported launcher, in an isolated workspace user directory.
## THE_WILL_DIAGNOSTIC_USER_ROOT must equal the workspace OS user directory.
## Optional THE_WILL_GRIP_LIVE_LIBRARY is a workspace file, otherwise user://.
## THE_WILL_GRIP_LIVE_WEAPON_NAME selects the exact saved name (default Star_Handle_Testing).
## THE_WILL_GRIP_LIVE_TIMEOUT_SECONDS defaults to 300; no launcher quit cutoff.
## THE_WILL_GRIP_LIVE_SKIP_MOTION=1 records acquisition only. Omit -Headless for PNGs.
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const StationState = preload("res://core/models/combat_animation_station_state.gd")
const Data = preload("res://runtime/player/grip/character_grip_data.gd")
const ActualView = preload("res://runtime/player/grip/observed_hand_pose_view.gd")
const Capture = preload("res://runtime/player/grip/capture_grip_placement_stage.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const OWNER_NAME := "PreparedGripAcquisition"
const ROOT := &"RL_BoneRoot"
const DIGITS := [&"middle", &"thumb", &"index", &"ring", &"pinky"]
const POSITION_GUARD_M := 0.00001
const ROTATION_GUARD_RAD := 0.0001

class LibraryPlayer extends Node:
	var library: Resource
	func get_forge_wip_library_state() -> Resource: return library
	func set_ui_mode_enabled(_enabled: bool) -> void: pass

var _ui: Node
var _player: LibraryPlayer
var _owner: Node
var _context: Dictionary = {}
var _checks := 0
var _failures: Array[String] = []
var _report: Dictionary = {}
var _observations: Array = []
var _motion: Array = []
var _library_path := "user://forge/player_wip_library_state.tres"
var _library_hash := ""
var _prefix := ""
var _started := 0
var _slot := &"hand_right"
var _terminal := "setup_incomplete"
var _timeout_seconds := 300.0
var _maximum_frame_ms := 0.0

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(label)
		push_error(label)
	return value

func _run() -> void:
	_started = Time.get_ticks_usec()
	_prefix = "C:/WORKSPACE/test_artifacts/live_saved_wrapper_grip_" + Time.get_datetime_string_from_system().replace(":", "-")
	_report = {"scope":"natural_skill_crafter_ui_activation_and_actual_skeleton_observation",
		"historical_pose_injected":false,"solver_suppressed":false,"source_save_written":false,
		"actual_3d_grip_verified":false,"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name()}
	var expected := _normalized(OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT"))
	if not _check(expected.begins_with("c:/workspace/") and expected == _normalized(OS.get_user_data_dir()), "isolated workspace user directory"):
		await _finish(); return
	var override_path := OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").strip_edges()
	if not override_path.is_empty():
		if not _check(_normalized(override_path).begins_with("c:/workspace/"), "library override remains inside workspace"):
			await _finish(); return
		_library_path = override_path.replace("\\", "/").simplify_path()
	var requested_timeout := OS.get_environment("THE_WILL_GRIP_LIVE_TIMEOUT_SECONDS").strip_edges()
	if not requested_timeout.is_empty():
		if not _check(requested_timeout.is_valid_float() and is_finite(float(requested_timeout)) and float(requested_timeout) > 0.0, "positive observation timeout"):
			await _finish(); return
		_timeout_seconds = float(requested_timeout)
	var name := OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME").strip_edges()
	if name.is_empty(): name = "Star_Handle_Testing"
	_report.merge({"source_library":_library_path,"weapon_name":name,"timeout_seconds":_timeout_seconds,
		"timeout_scope":"observed between frames; cancellation safely joins the worker"})
	if not _check(FileAccess.file_exists(_library_path), "saved library exists"):
		await _finish(); return
	_library_hash = FileAccess.get_sha256(_library_path)
	_report["source_library_sha256"] = _library_hash
	var library: Resource = ResourceLoader.load(_library_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(library != null, "saved library loads"):
		await _finish(); return
	var chosen: Resource
	for saved: Resource in library.get("saved_wips"):
		if saved == null: continue
		var station: Resource = saved.get("combat_animation_station_state")
		if not _check(station != null and int(station.get("station_version")) >= StationState.SKILL_BASELINE_SCHEMA_VERSION, "library does not require persisting schema migration"):
			await _finish(); return
		if str(saved.get("forge_project_name")) == name:
			if not _check(chosen == null, "weapon name is unique"):
				await _finish(); return
			chosen = saved
	if not _check(chosen != null, "requested weapon exists"):
		await _finish(); return
	var stage2: Resource = chosen.get("stage2_item_state")
	_report["input_has_saved_wrapper"] = stage2 != null and stage2.get("primary_grip_target_wrapper") != null
	_report["input_body_signature"] = stage2.get("primary_grip_handle_body_signature") if stage2 != null else ""
	_player = LibraryPlayer.new()
	_player.library = library.duplicate(true)
	_player.library.set("save_file_path", _prefix + "_unused_save.tres")
	root.add_child(_player)
	_ui = UIScene.instantiate()
	_ui.set_meta("verification_skip_persistence", true)
	root.add_child(_ui)
	await process_frame
	var span := Chronology.begin("live_verify.open_skill_crafter", {})
	_ui.open_for(_player, "Live saved-wrapper grip verification")
	Chronology.finish(span, {})
	var list: ItemList = _ui.project_list
	var selected := -1
	for index: int in list.item_count:
		if list.get_item_metadata(index) == chosen.get("wip_id"):
			selected = index; break
	if not _check(selected >= 0, "weapon is present in real project list"):
		await _finish(); return
	span = Chronology.begin("live_verify.weapon_item_activated", {"index":selected})
	list.select(selected)
	list.item_activated.emit(selected)
	Chronology.finish(span, {})
	if not _check(_ui.workflow_step == &"workflow_skill_select" and _ui.active_saved_wip_id == chosen.get("wip_id"), "real weapon double-click handler enters skill selection"):
		await _finish(); return
	var skill_button := _find_skill_button(&"skill_slot_1")
	if not _check(skill_button != null and not skill_button.disabled, "actual Skill 1 selector exists"):
		await _finish(); return
	span = Chronology.begin("live_verify.skill_1_pressed", {})
	skill_button.pressed.emit()
	Chronology.finish(span, {})
	if not _check(_ui.workflow_step == &"workflow_editor" and _ui._get_active_skill_slot_id() == &"skill_slot_1", "real Skill 1 handler enters editor"):
		await _finish(); return
	_context = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	if not _check(not _context.is_empty() and is_instance_valid(_context.get("actor")), "live preview context exists"):
		await _finish(); return
	_owner = _context.actor.get_node_or_null(OWNER_NAME)
	if not _check(_owner != null, "production acquisition owner exists"):
		await _finish(); return
	var requests: Dictionary = _owner.get("_requests")
	for key: Variant in requests:
		if requests[key].get("dominant") == key:
			_slot = StringName(key); break
	_report["slot"] = _slot
	_report["initial_pose"] = _sample_motion()
	await _observe()
	_report["terminal_status"] = _owner.status()
	_report["final_pose_before_controls"] = _sample_motion()
	var source_pose: Dictionary = _report.get("acquisition_source_pose", {})
	var final_pose: Dictionary = _report.final_pose_before_controls
	if not source_pose.is_empty() and not final_pose.is_empty():
		var unchanged: bool = var_to_bytes(source_pose.non_digit_local_poses) == var_to_bytes(final_pose.non_digit_local_poses)
		_report["upstream_local_poses_unchanged_during_acquisition"] = unchanged
		_check(unchanged, "acquisition preserves all non-digit local bone poses after macro positioning")
	await _capture_actual()
	await _screenshot("outcome")
	await _closeup_screenshots()
	var state: Dictionary = _owner.status().get(_slot, {})
	_verify_native_route(state)
	var contacts: Array = state.get("actual_material_contacts", [])
	var unique: Array = []
	for id: Variant in contacts:
		if not unique.has(id): unique.append(id)
	var applied: bool = state.get("status") == "preview_applied"
	var safe: bool = state.get("actual_material_query_valid", false) and state.get("actual_material_safe", false)
	var current: bool = state.get("actual_assessment_current", false)
	var articulation: bool = state.get("actual_articulation_valid", false)
	var completion: Dictionary = _full_hand_completion(state, unique)
	var planar_condition: bool = applied and safe and current and articulation and unique.size() >= 3
	_report["full_hand_completion"] = completion
	_report["acceptance"] = {"naturally_applied":applied,"actual_material_query_valid":state.get("actual_material_query_valid",false),
		"actual_material_safe":safe,"actual_assessment_current":current,"actual_articulation_valid":articulation,
		"distinct_actual_contact_sections":unique,"distinct_actual_contact_count":unique.size(),"required_contact_count":3,
		"planar_grip_condition_met":planar_condition,
		"full_hand_followers_complete":completion.complete,
		"intended_full_hand_solve_complete":planar_condition and completion.complete,
		"completion_state":"complete_pending_visual_review" if planar_condition and completion.complete else "unfinished",
		"whole_hand_3d_contact_certified":false,"rendered_image_requires_visual_review":true}
	_check(applied, "natural acquisition applies a pose")
	_check(safe and current and articulation and unique.size() >= 3, "actual current pose satisfies safety, articulation and three-section contact condition")
	_check(completion.complete, "intended full-hand solve has no unresolved follower response or missing realized follower contact")
	if applied and safe and current and OS.get_environment("THE_WILL_GRIP_LIVE_SKIP_MOTION") != "1":
		await _exercise_motion()
	else:
		_report["motion_checks_skipped"] = "requires naturally applied, current material-safe pose; or explicitly disabled"
	await _finish()

## Three contacts can all belong to one digit plus the palm. That satisfies the
## planar minimum but cannot establish that the remaining intended digits solved.
## Keep completion separate from collision safety and retain every follower's
## rejection instead of letting a safe open finger count as a successful grip.
func _full_hand_completion(state: Dictionary, actual_contacts: Array) -> Dictionary:
	var source: Array = state.get("follower_results", [])
	var followers: Dictionary = {}
	var duplicate_followers: Array = []
	for raw: Variant in source:
		if not raw is Dictionary: continue
		var digit: StringName = StringName(raw.get("digit", ""))
		if followers.has(digit): duplicate_followers.append(digit)
		followers[digit] = raw
	var unresolved: Array = []
	var digits: Dictionary = {}
	for digit: StringName in DIGITS:
		var contacts: Array = []
		for contact: Variant in actual_contacts:
			if str(contact).begins_with(str(digit) + "/"):
				contacts.append(contact)
		var observed: Dictionary = _report.get("actual_five_digits", {}).get(digit, {})
		var entry: Dictionary = {"digit":digit,"role":"placement_owner" if digit == &"middle" else "follower",
			"actual_contact_sections":contacts,"actual_contact_count":contacts.size(),
			"actual_measured_angles_rad":observed.get("angles_rad", []),
			"actual_articulation":observed.get("articulation", [])}
		if digit != &"middle":
			var response: Dictionary = followers.get(digit, {})
			var accepted: bool = response.get("valid", false) and response.get("accepted_contact_response", false)
			var completed: bool = accepted and not contacts.is_empty() and not duplicate_followers.has(digit)
			var reason: String = str(response.get("reason", "missing_follower_response"))
			if accepted and contacts.is_empty(): reason = "accepted_follower_has_no_realized_digit_contact"
			if duplicate_followers.has(digit): reason = "duplicate_follower_response"
			entry.merge({"response_present":not response.is_empty(),"response_valid":response.get("valid",false),
				"accepted_contact_response":accepted,"complete":completed,"reason":reason,
				"response_material_contacts":response.get("material_contacts", []),
				"response_material_safe":response.get("material_safe", false),
				"response_max_contact_error_m":response.get("max_contact_error_m"),
				"guide_fully_attached":response.get("attached", false)})
			if not completed: unresolved.append({"digit":digit,"reason":reason})
		digits[digit] = entry
	return {"complete":unresolved.is_empty(),"state":"complete" if unresolved.is_empty() else "unfinished",
		"unresolved_followers":unresolved,"per_digit":digits,"all_follower_responses":source.duplicate(true),
		"identified_palm_in_contact":actual_contacts.has("palm"),"palm_counts_as_digit_contact":false,
		"completion_does_not_replace_material_safety_or_articulation_checks":true}

func _find_skill_button(slot: StringName) -> Button:
	var grid: GridContainer = _ui.skill_slot_grid
	if grid == null: return null
	for node: Node in grid.get_children():
		if not node is Button: continue
		for connection: Dictionary in node.pressed.get_connections():
			var callback: Callable = connection.get("callable", Callable())
			if callback.get_method() == &"_on_skill_slot_selector_pressed" and slot in callback.get_bound_arguments(): return node
	return null

func _observe() -> void:
	var started := Time.get_ticks_usec()
	var previous := started
	var next_record := started
	var terminal_since := 0
	var last_serial := -1
	var last_status := ""
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		_maximum_frame_ms = maxf(_maximum_frame_ms, float(now - previous) / 1000.0)
		previous = now
		var statuses: Dictionary = _owner.status()
		var state: Dictionary = statuses.get(_slot, {})
		var serial := int(state.get("serial", -1))
		var status := str(state.get("status", ""))
		if status == "solving" and not _report.has("acquisition_source_pose"):
			# Capture after normal editor macro positioning and before the worker
			# returns; opening Skill 1 itself may still position the arm.
			_report["acquisition_source_pose"] = _sample_motion()
		var job: RefCounted = _owner.get("_job")
		var quiescent: bool = not _owner.get("_busy") and job == null and (_owner.get("_queue") as Array).is_empty()
		if now >= next_record or status != last_status or serial != last_serial:
			var row := {"elapsed_ms":float(now-_started)/1000.0,"statuses":statuses,
				"owner_busy":_owner.get("_busy"),"owner_processing":_owner.is_processing(),
				"queue":(_owner.get("_queue") as Array).duplicate(),"job_present":job != null,
				"job_script":job.get_script().resource_path if job != null else "",
				"progress":job.progress() if job != null and job.has_method("progress") else {}}
			_observations.append(row)
			Chronology.event("live_verify.observation", row)
			# Complete packets remain in the JSON report and chronology file. Keep
			# console progress bounded; terminal status contains large pose/skin data.
			var progress: Dictionary = row.progress
			print("LIVE_SAVED_GRIP_PROGRESS=" + JSON.stringify({"status":status,
				"reason":state.get("reason",state.get("actual_assessment_reason","")),
				"elapsed_ms":row.elapsed_ms,"stage":progress.get("stage",""),
				"digit":progress.get("digit",progress.get("current_digit",""))}))
			next_record = now + 1000000
		if serial != last_serial or status != last_status: terminal_since = 0
		last_serial = serial; last_status = status
		if quiescent and status in ["preview_applied", "unresolved", "unavailable", "cancelled"]:
			if terminal_since == 0: terminal_since = now
			if now-terminal_since >= 2000000:
				_terminal = status; break
		else: terminal_since = 0
		if float(now-started)/1000000.0 >= _timeout_seconds:
			_terminal = "timeout"
			_check(false, "natural acquisition completes within observation budget")
			break
	_report["natural_observation_ms"] = float(Time.get_ticks_usec()-started)/1000.0

func _capture_actual() -> void:
	var requests: Dictionary = _owner.get("_requests")
	var request: Dictionary = requests.get(_slot, {}).duplicate()
	if request.is_empty():
		_report["actual_capture_error"] = "no current request"; return
	var pivot := {"point_local":_context.weapon.get_meta("preview_primary_grip_seat_local"),
		"origin_id":_context.weapon.get_meta("preview_primary_grip_seat_origin_id"),"source":"preview_primary_grip_seat"}
	var data := Data.load_for_actor(_context.actor)
	if not data.get("valid",false):
		_report["actual_observation_error"] = data; return
	var capture: Dictionary = await _read_settled_capture(data.anatomy, request, pivot)
	_report["actual_capture_valid"] = capture.get("valid", false)
	if not _check(capture.get("valid", false), "actual naturally settled pose captured without forcing an update"):
		_report["actual_capture_error"] = capture; return
	var dimensions: Dictionary = request.get("digit_dimension_reference", {})
	if not _check(not dimensions.is_empty(), "actual observation uses the current request's frozen digit dimensions"):
		_report["actual_observation_error"] = "current_request_missing_digit_dimension_reference"; return
	capture.posed_character["digit_dimension_reference"] = dimensions.duplicate(true)
	var file := FileAccess.open(_prefix + "_actual.bin", FileAccess.WRITE)
	if not _check(file != null, "actual captured pose artifact opens"): return
	file.store_var(capture, false); file.close()
	_report["actual_capture_path"] = _prefix + "_actual.bin"
	var observed := ActualView.new().observe(data.anatomy, capture.posed_character, _slot, DIGITS)
	_report["actual_observation_valid"] = observed.get("valid", false)
	if not _check(observed.get("valid", false), "actual five-digit observation succeeds without posing geometry"):
		_report["actual_observation_error"] = observed; return
	_report["actual_articulation"] = observed.articulation
	var digits := {}
	for digit: StringName in DIGITS:
		var state: Dictionary = observed.view.digit_states[digit]
		digits[digit] = {"angles_rad":state.angles_rad,"angles_are_measured_not_reposed":true,
			"articulation":state.articulation_measurements,"plane_origin_id":state.plane_origin_id,
			"plane_to_world":state.plane_to_world,"joint_origins_world":state.joint_origins_world}
	_report["actual_five_digits"] = digits
	_report["actual_capture_source_unchanged"] = observed.source_capture_unchanged

## A stable skeleton need not emit another update. Observe a natural final-pose
## signal if one occurs. Otherwise read the settled current pose only after
## unchanged completed frames, and only when no pose-producing modifier can
## hide a deferred pose. A non-simulating physics modifier is recorded separately.
## No advance(), force update, or bone write creates the evidence.
## https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html#signals
func _read_settled_capture(anatomy: Resource, request: Dictionary, pivot: Dictionary) -> Dictionary:
	var skeleton: Skeleton3D = _context.actor.get("skeleton")
	var captured := {}
	var receive := func() -> void:
		if captured.is_empty() and _owner._is_current(_slot, request):
			captured.merge(Capture.new().capture(_context.actor, _context.weapon, anatomy, _slot,
				&"live_verifier_natural_skeleton_signal", request.serial, 0, {}, pivot))
			captured["verification_capture_policy"] = "natural_skeleton_updated_signal"
			captured["verification_signal_observed"] = true
	skeleton.skeleton_updated.connect(receive)
	var stamp: PackedByteArray = _owner._realization_stamp()
	var stable_frames := 0
	for frame: int in 4:
		await process_frame
		if not captured.is_empty(): break
		var next_stamp: PackedByteArray = _owner._realization_stamp()
		stable_frames = stable_frames + 1 if next_stamp == stamp else 0
		stamp = next_stamp
	if skeleton.skeleton_updated.is_connected(receive): skeleton.skeleton_updated.disconnect(receive)
	if not _owner._is_current(_slot, request): return {"valid":false,"reason":"request_replaced_during_passive_capture"}
	if captured.is_empty():
		var modifiers: Array = []
		var idle_simulators: Array = []
		for child: Node in skeleton.find_children("*", "SkeletonModifier3D", true, false):
			if child is SkeletonModifier3D and child.active and child.influence > 0.0:
				# Active is inherited from SkeletonModifier3D; it does not prove
				# that this simulator is currently producing any physics poses.
				# https://docs.godotengine.org/en/4.7/classes/class_physicalbonesimulator3d.html#class-physicalbonesimulator3d-method-is-simulating-physics
				if child is PhysicalBoneSimulator3D and not child.is_simulating_physics():
					idle_simulators.append(str(child.get_path()))
					continue
				modifiers.append(str(child.get_path()))
		if not modifiers.is_empty():
			return {"valid":false,"reason":"no_natural_final_signal_with_active_modifiers","active_modifiers":modifiers}
		if stable_frames < 2 or stamp.is_empty():
			return {"valid":false,"reason":"pose_did_not_remain_stable_for_read_only_capture","stable_frames":stable_frames}
		captured = Capture.new().capture(_context.actor, _context.weapon, anatomy, _slot,
			&"live_verifier_settled_unmodified_pose", request.serial, 0, {}, pivot)
		captured["verification_capture_policy"] = "stable_completed_frames_without_pose_producing_modifiers"
		captured["verification_signal_observed"] = false
		captured["verification_stable_frames"] = stable_frames
		captured["verification_non_simulating_physical_modifiers"] = idle_simulators
		captured["verification_pose_unchanged_during_capture"] = stamp == _owner._realization_stamp()
		if not captured.verification_pose_unchanged_during_capture:
			return {"valid":false,"reason":"pose_changed_during_read_only_capture"}
	_report["actual_capture_policy"] = captured.get("verification_capture_policy", "")
	_report["actual_capture_signal_observed"] = captured.get("verification_signal_observed", false)
	return captured

func _verify_native_route(state: Dictionary) -> void:
	var totals: Dictionary = state.get("solver_totals", {})
	var contact: Dictionary = totals.get("saved_contact_cache_statistics", {})
	var kernel: Dictionary = contact.get("native_kernel", {})
	var sections: Dictionary = totals.get("section_backend_statistics", {})
	_report["native_route"] = {"acquisition_method":state.get("acquisition_method",""),
		"contact_backend":state.get("contact_backend",""),"native_contact_batch_enabled":state.get("native_contact_batch_enabled",false),
		"contact_statistics":contact,"section_statistics":sections}
	_check(state.get("acquisition_method") == "saved_wrapper_contact_cpp", "natural owner selects saved-wrapper C++ acquisition")
	_check(state.get("contact_backend") == "cpp_saved_contact_batch" and state.get("native_contact_batch_enabled",false), "complete C++ contact batch is selected")
	_check(contact.get("contact_backend") == "cpp" and contact.get("native_batch_enabled",false)
		and int(contact.get("batch_calls",0)) > 0 and int(kernel.get("segment_calls",0)) > 0, "native batch and numerical segment work actually ran")
	_check(int(contact.get("backend_selection_fallbacks",-1)) == 0 and int(contact.get("fallback_calls",-1)) == 0
		and int(kernel.get("fallback_calls",-1)) == 0, "contact route has no fallback")
	_check(sections.get("section_backend") == "cpp" and int(sections.get("native_slice_calls",0)) > 0
		and int(sections.get("native_topology_calls",0)) > 0 and int(sections.get("fallback_calls",-1)) == 0
		and int(sections.get("reference_slice_calls",-1)) == 0 and int(sections.get("reference_topology_calls",-1)) == 0,
		"saved sections use native slicing and topology with no fallback")

func _sample_motion() -> Dictionary:
	var actor: Node3D = _context.actor
	var weapon: Node3D = _context.weapon
	var skeleton: Skeleton3D = actor.get("skeleton")
	var hand_name := "CC_Base_R_Hand" if _slot == &"hand_right" else "CC_Base_L_Hand"
	var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(hand_name))
	var rotations := {}
	var non_digits := {}
	var names: Array[StringName] = Rules.get_finger_bone_names(_slot)
	for index: int in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(index)
		if name in names: rotations[name] = skeleton.get_bone_pose_rotation(index)
		else: non_digits[name] = skeleton.get_bone_pose(index)
	var request: Dictionary = (_owner.get("_requests") as Dictionary).get(_slot, {})
	return {"hand_world":hand,"weapon_world":weapon.global_transform,"world_reference_origin_id":ROOT,
		"hand_in_weapon":weapon.global_transform.affine_inverse()*hand,"hand_in_weapon_origin_id":&"WeaponRootOrigin",
		"digit_rotations":rotations,"non_digit_local_poses":non_digits,
		"tip_world":weapon.to_global(weapon.get_meta("weapon_tip_local")),
		"pommel_world":weapon.to_global(weapon.get_meta("weapon_pommel_local")),
		"serial":request.get("serial",-1),"relationship_key_sha256":str(request.get("key","")).sha256_text(),
		"owner_busy":_owner.get("_busy"),"job_present":_owner.get("_job") != null,
		"queued_requests":(_owner.get("_queue") as Array).size(),"binding":actor.get_planar_grip_pose_state(_slot)}

func _exercise_motion() -> void:
	var baseline := _sample_motion()
	for action: Dictionary in [{"kind":"refresh"},{"kind":"tip","offset":Vector3(-0.003,0.004,0.002)},
		{"kind":"pommel","offset":Vector3(0.006,0.002,-0.003)},{"kind":"roll","degrees":20.0},
		{"kind":"roll","degrees":-20.0},{"kind":"pommel","offset":Vector3(4.0,4.0,0.0),"expect_limit":true}]:
		var before := _sample_motion()
		var active: Resource = _ui._get_active_motion_node()
		var display: Resource = _ui._build_authoring_motion_node_baseline(active)
		var requested := action.duplicate(true)
		var changed := false
		var start := Time.get_ticks_usec()
		if action.kind == "tip" or action.kind == "pommel":
			requested["target_local"] = display.get(action.kind + "_position_local") + action.offset
			requested["target_origin_id"] = display.get(action.kind + "_position_origin_id")
			requested["target_world"] = _context.trajectory.to_global(requested.target_local)
			if action.kind == "tip": changed = _ui.set_selected_motion_node_tip_position(requested.target_local, false, false, false, true, false)
			else: changed = _ui.set_selected_motion_node_pommel_position(requested.target_local, false, false, false, true, false)
		elif action.kind == "roll":
			requested["target_degrees"] = float(active.get("weapon_roll_degrees")) + action.degrees
			changed = _ui.set_selected_motion_node_weapon_roll(requested.target_degrees, false, false, false, true, false)
		else:
			_ui._refresh_preview_scene(); changed = true
		var synchronous_ms := float(Time.get_ticks_usec()-start)/1000.0
		for frame: int in 2: await process_frame
		var after := _sample_motion()
		var old_relation: Transform3D = baseline.hand_in_weapon
		var new_relation: Transform3D = after.hand_in_weapon
		var position_error: float = ((after.weapon_world as Transform3D).basis * (new_relation.origin-old_relation.origin)).length()
		var rotation_error := _angle_error(old_relation.basis.orthonormalized().get_rotation_quaternion(),new_relation.basis.orthonormalized().get_rotation_quaternion())
		var digit_error := 0.0
		for bone: Variant in baseline.digit_rotations:
			digit_error = maxf(digit_error,_angle_error(baseline.digit_rotations[bone],after.digit_rotations[bone]))
		var moved: bool = (before.tip_world as Vector3).distance_to(after.tip_world) > 0.0001 or (before.pommel_world as Vector3).distance_to(after.pommel_world) > 0.0001 or _angle_error((before.weapon_world as Transform3D).basis.get_rotation_quaternion(),(after.weapon_world as Transform3D).basis.get_rotation_quaternion()) > 0.0001
		_check(position_error <= POSITION_GUARD_M and rotation_error <= ROTATION_GUARD_RAD, str(action.kind)+" retains solved hand-in-weapon relationship")
		_check(digit_error <= ROTATION_GUARD_RAD, str(action.kind)+" retains all fifteen digit rotations")
		_check(after.serial == baseline.serial and after.relationship_key_sha256 == baseline.relationship_key_sha256 and not after.owner_busy and not after.job_present and after.queued_requests == 0, str(action.kind)+" needs no reacquisition")
		if action.kind == "roll":
			_check((before.hand_world as Transform3D).origin.distance_to((after.hand_world as Transform3D).origin) <= POSITION_GUARD_M and (before.tip_world as Vector3).distance_to(after.tip_world) <= POSITION_GUARD_M, "Roll fixes wrist point and weapon Tip")
		if changed and action.kind != "refresh" and not action.get("expect_limit",false):
			_check(moved, str(action.kind)+" accepted control really moves weapon")
		if action.get("expect_limit",false):
			_check((after.pommel_world as Vector3).distance_to(requested.target_world) > 0.05,"unreachable Pommel request stops before target")
		_motion.append({"requested":requested,"changed":changed,"weapon_moved":moved,"synchronous_ms":synchronous_ms,
			"position_error_m":position_error,"rotation_error_rad":rotation_error,"digit_rotation_error_rad":digit_error,"after":after})
		if not (after.serial == baseline.serial and not after.owner_busy and not after.job_present):
			_report["motion_stopped_reason"] = "unexpected reacquisition; remaining controls not attempted"; break
	await _screenshot("after_controls")

## Framing only: use the actual wrist and current digit joints in the same
## named ROOT/world presentation as _sample_motion. Nothing poses the actor or
## weapon. Opposing views expose both sides of the hand/handle contact region.
func _closeup_screenshots() -> void:
	if DisplayServer.get_name() == "headless": return
	var viewport: SubViewport = _ui.preview_subviewport
	var camera: Camera3D = viewport.get_camera_3d()
	if not _check(camera != null, "actual preview camera exists for hand close-ups"): return
	var before := _sample_motion()
	if not _check(before.get("world_reference_origin_id") == ROOT, "hand close-up framing resolves to RL_BoneRoot"): return
	var hand: Transform3D = before.hand_world
	var skeleton: Skeleton3D = _context.actor.get("skeleton")
	var points: Array[Vector3] = [hand.origin]
	var bone_points := {}
	var focus_world: Vector3 = hand.origin
	for name: StringName in Rules.get_finger_bone_names(_slot):
		var bone: int = skeleton.find_bone(name)
		if not _check(bone >= 0, "close-up framing digit bone exists: " + str(name)): return
		var point_world: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin
		bone_points[name] = point_world
		points.append(point_world)
		focus_world += point_world
	focus_world /= float(points.size())
	var prefix := "CC_Base_R_" if _slot == &"hand_right" else "CC_Base_L_"
	var along_world: Vector3 = (bone_points[StringName(prefix + "Mid1")] as Vector3) - hand.origin
	var across_world: Vector3 = (bone_points[StringName(prefix + "Index1")] as Vector3) - (bone_points[StringName(prefix + "Pinky1")] as Vector3)
	var normal_world: Vector3 = along_world.cross(across_world)
	if not _check(normal_world.length_squared() > 0.000000000001, "actual palm joints define close-up viewing directions"): return
	along_world = along_world.normalized()
	normal_world = normal_world.normalized()
	var radius_m := 0.0
	for point_world: Vector3 in points:
		radius_m = maxf(radius_m, focus_world.distance_to(point_world))
	# Display margin includes distal skin beyond the last joint; it is not a
	# grip tolerance, authored point, or added collision geometry.
	radius_m += 0.025
	var restored_transform: Transform3D = camera.global_transform
	var restored_projection := camera.projection
	var restored_size: float = camera.size
	var restored_near: float = camera.near
	var restored_keep_aspect := camera.keep_aspect
	var before_stamp: PackedByteArray = _owner._realization_stamp()
	var aspect: float = float(viewport.size.x) / maxf(float(viewport.size.y), 1.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 2.4 * radius_m / minf(aspect, 1.0)
	camera.near = minf(restored_near, 0.005)
	var views: Array = []
	for side: int in [-1, 1]:
		var direction_world: Vector3 = (normal_world * float(side) + along_world * 0.25).normalized()
		camera.look_at_from_position(focus_world + direction_world * radius_m * 3.0, focus_world, along_world)
		var label := "hand_closeup_a" if side < 0 else "hand_closeup_b"
		views.append({"label":label,"camera_to_world":camera.global_transform,"world_reference_origin_id":ROOT})
		await _screenshot(label)
	camera.global_transform = restored_transform
	camera.projection = restored_projection
	camera.size = restored_size
	camera.near = restored_near
	camera.keep_aspect = restored_keep_aspect
	var pose_unchanged: bool = before_stamp == _owner._realization_stamp()
	_report["hand_closeup_framing"] = {"hand_to_world":hand,"focus_world":focus_world,
		"world_reference_origin_id":ROOT,"source":"actual_wrist_and_current_digit_joint_origins",
		"framing_radius_m":radius_m,"views":views,"camera_restored":camera.global_transform == restored_transform,
		"pose_unchanged":pose_unchanged,"pose_writes":false,"solver_suppressed":false}
	_check(pose_unchanged, "camera close-ups leave realized actor and weapon pose unchanged")

func _screenshot(label: String) -> void:
	if not is_instance_valid(_ui): return
	if DisplayServer.get_name() == "headless":
		_report["screenshot_skipped"] = "headless display has no rendered viewport"; return
	var viewport: SubViewport = _ui.preview_subviewport
	if not is_instance_valid(viewport): return
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var path := _prefix + "_" + label + ".png"
	var saved: bool = image != null and not image.is_empty() and image.save_png(path) == OK
	_check(saved,"rendered "+label+" screenshot saved")
	if not _report.has("screenshots"): _report["screenshots"] = []
	_report.screenshots.append({"label":label,"path":path,"saved":saved,"viewport_size":viewport.size})

func _finish() -> void:
	if is_instance_valid(_ui) and not _report.has("screenshots"):
		await _screenshot("outcome")
	if is_instance_valid(_owner):
		var job: RefCounted = _owner.get("_job")
		_owner.clear()
		var deadline := Time.get_ticks_usec() + 10000000
		while job != null and bool(job.get("_running")) and Time.get_ticks_usec() < deadline: await process_frame
		if job != null and bool(job.get("_running")) and job.has_method("shutdown"): job.shutdown()
	if is_instance_valid(_ui):
		_ui.close_ui(); _ui.queue_free()
	if is_instance_valid(_player): _player.queue_free()
	await process_frame
	if not _library_hash.is_empty(): _check(FileAccess.get_sha256(_library_path)==_library_hash,"source saved library remains byte-identical")
	_report.merge({"ok":_failures.is_empty(),"checks":_checks,"failures":_failures,"terminal":_terminal,
		"observations":_observations,"motion_checks":_motion,"maximum_frame_ms":_maximum_frame_ms,
		"elapsed_ms":float(Time.get_ticks_usec()-_started)/1000.0})
	var file := FileAccess.open(_prefix + ".json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_json(_report),"\t")); file.close()
	Chronology.event("live_verify.complete", {"ok":_failures.is_empty(),"terminal":true,"terminal_state":_terminal,"report":_prefix+".json"})
	Chronology.close()
	print("LIVE_SAVED_WRAPPER_GRIP_RESULT="+_prefix+".json ok="+str(_failures.is_empty()))
	quit(0 if _failures.is_empty() else 1)

func _normalized(path: String) -> String:
	return path.replace("\\","/").simplify_path().trim_suffix("/").to_lower()

func _angle_error(before: Quaternion, after: Quaternion) -> float:
	var difference := before.inverse()*after
	return 2.0*atan2(Vector3(difference.x,difference.y,difference.z).length(),absf(difference.w))

func _json(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value: out[str(key)] = _json(value[key])
		return out
	if value is Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedStringArray or value is PackedVector2Array or value is PackedVector3Array or value is PackedByteArray:
		var out: Array = []
		for entry: Variant in value: out.append(_json(entry))
		return out
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Quaternion: return [value.x,value.y,value.z,value.w]
	if value is Basis: return {"x":_json(value.x),"y":_json(value.y),"z":_json(value.z)}
	if value is Transform3D: return {"basis":_json(value.basis),"origin":_json(value.origin)}
	if value is Object: return {"object_class":value.get_class(),"script":value.get_script().resource_path if value.get_script()!=null else ""} if is_instance_valid(value) else null
	return value
