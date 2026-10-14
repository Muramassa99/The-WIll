extends SceneTree

## End-to-end proof using a READ-ONLY workspace copy of an actual saved weapon.
## All writes (library, slots, equipment, report) use a new workspace prefix.
## Requires isolated THE_WILL_DIAGNOSTIC_USER_ROOT and
## THE_WILL_GRIP_LIVE_LIBRARY. Optional THE_WILL_GRIP_LIVE_WEAPON_NAME.
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const Equipment = preload("res://core/models/player_equipment_state.gd")
const Slots = preload("res://core/models/player_skill_slot_state.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const ChainPlayer = preload("res://runtime/combat/combat_animation_chain_player.gd")
const HAND := &"hand_right"
const SKILL := &"skill_slot_1"
const MotionData = preload("res://core/models/combat_animation_motion_node.gd")

class LibraryPlayer extends Node:
	var library: Resource
	func get_forge_wip_library_state() -> Resource: return library
	func set_ui_mode_enabled(_enabled: bool) -> void: pass

var _ui: Node
var _library_player: LibraryPlayer
var _game_player: Node3D
var _source := ""
var _source_hash := ""
var _prefix := ""
var _failures: Array[String] = []
var _checks := 0
var _last_pose_metrics: Dictionary = {}
var _verified_hands: Array[StringName] = [HAND]
var _report: Dictionary = {"scope": "actual_saved_weapon_skill_bake_serialize_reload_equipped_playback", "visual_grip_certified": false}

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures.append(label)
		push_error(label)
	return ok

func _workspace(path: String) -> bool:
	return path.replace("\\", "/").simplify_path().to_lower().begins_with("c:/workspace/")

func _run() -> void:
	_prefix = "C:/WORKSPACE/test_artifacts/grip_save_playback_" + Time.get_datetime_string_from_system().replace(":", "-")
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").strip_edges()
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not _check(_workspace(expected) and expected == OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower(), "all incidental user writes are isolated inside workspace"):
		_finish(); return
	if not _check(_workspace(_source) and FileAccess.file_exists(_source), "actual input library is a workspace copy"):
		_finish(); return
	_source_hash = FileAccess.get_sha256(_source)
	_report.merge({"source_library": _source, "source_library_sha256": _source_hash, "output_prefix": _prefix})
	var input: Resource = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(input != null, "source library loads"):
		_finish(); return
	var requested := OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME").strip_edges()
	if requested.is_empty(): requested = "Star_Handle_Testing"
	var chosen: Resource
	for wip: Resource in input.saved_wips:
		if wip.forge_project_name == requested: chosen = wip
	if not _check(chosen != null, "named actual weapon exists"):
		_finish(); return
	_report["weapon_name"] = requested
	_library_player = LibraryPlayer.new()
	_library_player.library = input.duplicate(true)
	_library_player.library.save_file_path = _prefix + "_library.tres"
	root.add_child(_library_player)
	_ui = UIScene.instantiate()
	root.add_child(_ui)
	await process_frame
	_ui.open_for(_library_player, "Isolated grip save/playback verification")
	if not _check(_ui.select_saved_wip(chosen.wip_id), "Skill Crafter selects actual weapon"):
		_finish(); return
	_ui._on_skill_slot_selector_pressed(SKILL)
	var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	if not _check(not context.is_empty(), "real Skill Crafter preview exists"):
		_finish(); return
	var started := Time.get_ticks_usec()
	var status: Dictionary = {}
	while float(Time.get_ticks_usec() - started) / 1000000.0 < 120.0:
		await process_frame
		status = _ui.preview_presenter.get_grip_acquisition_status(_ui.preview_subviewport).get(HAND, {})
		if status.get("status", "") in ["preview_applied", "unresolved", "unavailable"]: break
	_report["initial_grip_status"] = status
	if not _check(status.get("status", "") == "preview_applied", "natural acquisition applies before save"):
		_finish(); return
	if OS.get_environment("THE_WILL_GRIP_SAVE_TWO_HAND") == "1":
		_verified_hands.append(&"hand_left")
		_report["two_hand_save"] = true
		if not _check(_ui.set_selected_motion_node_two_hand_state(MotionData.TWO_HAND_STATE_TWO_HAND, false), "actual UI enables support before two-hand Save"):
			_finish(); return
		var support_started := Time.get_ticks_usec()
		var support_status: Dictionary = {}
		while float(Time.get_ticks_usec() - support_started) / 1000000.0 < 120.0:
			await process_frame
			support_status = _ui.preview_presenter.get_grip_acquisition_status(_ui.preview_subviewport).get(&"hand_left", {})
			if support_status.get("status", "") in ["preview_applied", "unresolved", "unavailable"]: break
		_report["support_before_save"] = support_status
		if not _check(support_status.get("status", "") == "preview_applied", "support committed before two-hand Save"):
			_finish(); return
	_report["editor_legacy_solve_count"] = _legacy_solve_count(context.actor)
	_check(_legacy_solve_count(context.actor) == 0, "prepared editor acquisition does not run legacy serial/seat solve")
	# Only the copied skill changes: a small macro translation and axis turn
	# exercise transport of one committed grip through the ordinary body solver.
	var draft: Resource = _ui._get_active_draft()
	var source_motion: Resource = draft.motion_node_chain[clampi(draft.selected_motion_node_index, 0, draft.motion_node_chain.size() - 1)]
	var first: Resource = source_motion.duplicate_node()
	var second: Resource = source_motion.duplicate_node()
	first.node_id = &"grip_save_probe_0"
	second.node_id = &"grip_save_probe_1"
	first.node_index = 0
	second.node_index = 1
	first.transition_duration_seconds = 0.3
	second.transition_duration_seconds = 0.3
	var midpoint: Vector3 = (first.tip_position_local + first.pommel_position_local) * 0.5
	var turn := Basis(Vector3.UP, deg_to_rad(5.0))
	var shift := Vector3(0.015, 0.0, 0.0)
	var requested_reference_shift := Vector3.ZERO
	if _verified_hands.size() == 2:
		# The focused support proof establishes this direction as reachable.
		# Isolate translation so a separate wrist turn cannot mask a frozen grip.
		turn = Basis.IDENTITY
		shift = Vector3(-0.01, 0.0, 0.0)
		_report["requested_two_hand_translation_local"] = shift
		_report["support_station_slide_offset"] = source_motion.secondary_grip_seat_slide_offset
		var reference: Transform3D = context.actor._resolve_runtime_solved_replay_reference_transform(&"RL_BoneRoot")
		requested_reference_shift = reference.basis.inverse() * context.trajectory.global_basis * shift
		_report["requested_two_hand_translation_reference_m"] = requested_reference_shift
	second.tip_position_local = midpoint + turn * (first.tip_position_local - midpoint) + shift
	second.pommel_position_local = midpoint + turn * (first.pommel_position_local - midpoint) + shift
	_report["authored_motion_endpoints"] = {"first_tip": first.tip_position_local, "first_pommel": first.pommel_position_local,
		"last_tip": second.tip_position_local, "last_pommel": second.pommel_position_local,
		"first_roll_degrees": first.weapon_roll_degrees, "last_roll_degrees": second.weapon_roll_degrees}
	draft.motion_node_chain.assign([first, second])
	draft.selected_motion_node_index = 1
	draft.preview_loop_enabled = false
	var authored_idle: Resource = _ui._get_existing_combat_idle_draft()
	_check(authored_idle != null, "existing station factory provides Combat Idle")
	_ui._mark_draft_runtime_clip_cache_dirty(authored_idle)
	_ui._mark_active_draft_runtime_clip_cache_dirty()
	_ui.editor_state_dirty = true
	var grip_owner: Node = context.actor.get_node("PreparedGripAcquisition")
	var before_save_hands: Dictionary = {}
	for slot: StringName in _verified_hands:
		before_save_hands[slot] = _hand_in_weapon(context.actor, context.weapon, slot)
	_report["before_save_hand_relationships"] = before_save_hands.duplicate()
	_report["before_save_skeleton_world"] = context.actor.skeleton.global_transform
	var before_save_weapon_reference := _weapon_in_replay_reference(context.actor, context.weapon)
	_report["before_save_weapon_reference_frame"] = before_save_weapon_reference
	var clamp_count_before: int = grip_owner._support_motion_clamp_count
	started = Time.get_ticks_usec()
	await _ui._manual_save_active_editor_state()
	_report["save_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	_report["save_message"] = _ui.footer_status_label.text
	_report["after_save_grip_status"] = _ui.preview_presenter.get_grip_acquisition_status(_ui.preview_subviewport)
	_report["motion_retention"] = grip_owner._last_support_motion_clamp.duplicate(true)
	_report["save_motion_clamp_count"] = grip_owner._support_motion_clamp_count - clamp_count_before
	_check(_ui.footer_status_label.text.contains("Preview ready"), "Save restores the selected valid preview after temporary Idle bake")
	var retained_hand_error := 0.0
	for slot: StringName in _verified_hands:
		var before: Transform3D = before_save_hands[slot]
		var after := _hand_in_weapon(context.actor, context.weapon, slot)
		retained_hand_error = maxf(retained_hand_error, maxf(before.origin.distance_to(after.origin), _rotation_error(before.basis.get_rotation_quaternion(), after.basis.get_rotation_quaternion())))
		var key: String = grip_owner._requests[slot].key
		var cached: Dictionary = grip_owner._replay_pose_cache.get(key, {})
		var bound: Dictionary = context.actor.planar_grip_pose_binding.relationship(slot, context.weapon)
		_check(not cached.is_empty() and cached.packet.hand_in_weapon == bound.get("hand_in_weapon"), "restored cache matches committed " + str(slot) + " relationship for next Save")
	_report["after_save_hand_relationship_error_m_or_rad"] = retained_hand_error
	if _verified_hands.size() == 2:
		_check(retained_hand_error <= 0.00005, "Save restores both established Hand-to-weapon relationships")
	_check(_ui._get_active_draft() == draft and draft.selected_motion_node_index == 1, "Skill Save preserves active authored selection")
	_check(authored_idle != null and authored_idle.baked_runtime_clip != null and authored_idle.baked_runtime_clip.has_solved_replay_track(), "Skill Save also prepares the existing Combat Idle grip")
	var clip: Resource = draft.baked_runtime_clip
	if not _check(clip != null and clip.has_solved_replay_track(), "manual Save produces solved bone/weapon/anchor track"):
		_finish(); return
	_report["baked_frame_count"] = clip.get_frame_count()
	_report["bake_legacy_solve_count"] = _legacy_solve_count(context.actor)
	_check(_legacy_solve_count(context.actor) == 0, "offline prepared bake does not run legacy serial/seat solve")
	var macro_shift: float = clip.baked_solved_weapon_positions_reference_local[0].distance_to(clip.baked_solved_weapon_positions_reference_local[-1])
	var macro_turn: float = clip.baked_solved_weapon_rotations_reference_local[0].distance_to(clip.baked_solved_weapon_rotations_reference_local[-1])
	_report["baked_macro_translation_m"] = macro_shift
	_report["baked_macro_quaternion_delta"] = macro_turn
	if _verified_hands.size() == 2:
		_report["macro_motion_outcome"] = "motion_realized" if macro_shift > 0.0001 else "motion_not_realized"
		_check(macro_shift > 0.0001, "two-hand baked clip realizes more than 0.1 mm of weapon translation")
		var fidelity := _two_hand_motion_fidelity(clip, requested_reference_shift)
		var first_rotation: Vector4 = clip.baked_solved_weapon_rotations_reference_local[0]
		fidelity["initial_position_error_m"] = before_save_weapon_reference.origin.distance_to(clip.baked_solved_weapon_positions_reference_local[0])
		fidelity["initial_rotation_error_rad"] = _rotation_error(before_save_weapon_reference.basis.orthonormalized().get_rotation_quaternion(),
			Quaternion(first_rotation.x, first_rotation.y, first_rotation.z, first_rotation.w))
		_report["two_hand_baked_motion_fidelity"] = fidelity
		_check(fidelity.finite, "two-hand motion samples are finite")
		# These expose macro projection/settling differences. The 0.05 mm contact
		# tolerance is not a rule that every authored body target is reachable.
		fidelity["interpretation"] = "Requested-path metrics; no invented macro movement tolerance. Compare against ordinary UI realization."
	else:
		_report["macro_motion_outcome"] = "motion_realized"
		_check(macro_shift > 0.001 or macro_turn > 0.001, "baked clip realizes macro body/weapon motion")
	var persisted: Resource = ResourceLoader.load(_prefix + "_library.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(persisted != null, "workspace saved library reloads from disk"):
		_finish(); return
	persisted.save_file_path = _prefix + "_library.tres"
	var reloaded_wip: Resource = persisted.get_saved_wip_clone(chosen.wip_id)
	var reloaded_draft: Resource
	for item: Resource in reloaded_wip.combat_animation_station_state.skill_drafts:
		if item.draft_id == draft.draft_id: reloaded_draft = item
	if not _check(reloaded_draft != null and reloaded_draft.baked_runtime_clip != null, "saved skill contains reloaded clip"):
		_finish(); return
	var reloaded: Resource = reloaded_draft.baked_runtime_clip
	var reloaded_idle: Resource
	for item: Resource in reloaded_wip.combat_animation_station_state.idle_drafts:
		if item.context_id == &"idle_combat": reloaded_idle = item
	_check(reloaded_idle != null and reloaded_idle.baked_runtime_clip != null and reloaded_idle.baked_runtime_clip.has_solved_replay_track(), "same Save persists both skill and Combat Idle clips")
	_check(reloaded.has_solved_replay_track() and reloaded.get_frame_count() == clip.get_frame_count(), "serialized replay retains frame availability")
	_check(_track_error(clip, reloaded) <= 0.00005, "serialization preserves finger and weapon tracks within 0.05 mm/rad")
	# Apply the reloaded track through the actual Skill Crafter replay presenter.
	var chain := ChainPlayer.new()
	chain.prepare_runtime_clip(reloaded)
	chain.start()
	var preview_state: Dictionary = _clip_frame_state(chain)
	_ui.preview_presenter.sync_playback_pose(_ui.preview_view_container, _ui.preview_subviewport,
		reloaded_wip, reloaded_draft, 1, preview_state)
	var replayed: Dictionary = context.root.get_meta("resolved_playback_state", {})
	_check(replayed.get("solved_replay_applied", false), "reloaded Skill Crafter playback consumes solved track")
	_check(_pose_error(context.actor, context.weapon, preview_state) <= 0.00005, "reloaded preview applies fingers and weapon together")
	_report["preview_pose_metrics"] = _last_pose_metrics.duplicate(true)
	if _verified_hands.size() == 2:
		var replay_start: Vector3 = context.weapon.global_position
		var endpoint_errors := {"first": _saved_relationship_error(context.actor, context.weapon, before_save_hands)}
		chain._apply_runtime_clip_sample(reloaded.baked_frame_times[-1])
		var last_state: Dictionary = _clip_frame_state(chain)
		_ui.preview_presenter.sync_playback_pose(_ui.preview_view_container, _ui.preview_subviewport,
			reloaded_wip, reloaded_draft, 1, last_state)
		_check(_pose_error(context.actor, context.weapon, last_state) <= 0.00005, "two-hand final preview frame applies the recorded pose")
		endpoint_errors["last"] = _saved_relationship_error(context.actor, context.weapon, before_save_hands)
		var replay_motion: float = replay_start.distance_to(context.weapon.global_position)
		_report["two_hand_preview_endpoint_relationship_errors"] = endpoint_errors
		_report["two_hand_preview_realized_translation_m"] = replay_motion
		_check(float(endpoint_errors.first) <= 0.00005 and float(endpoint_errors.last) <= 0.00005,
			"both recorded preview endpoints retain both established grips")
		_check(replay_motion > 0.0001, "two-hand reloaded preview actually moves the weapon more than 0.1 mm")
	_ui.preview_presenter.cancel_grip_acquisition(_ui.preview_subviewport)
	_ui.queue_free()
	_ui = null
	await process_frame
	var equipment := Equipment.new()
	equipment.save_file_path = _prefix + "_equipment.tres"
	equipment.equip_forge_test_wip(HAND, reloaded_wip)
	var slots := Slots.new()
	slots.save_file_path = _prefix + "_slots.tres"
	_game_player = PlayerScene.instantiate()
	_game_player.equipment_state = equipment
	_game_player.forge_wip_library_state = persisted
	_game_player.player_skill_slot_state = slots
	_game_player.weapons_drawn = true
	root.add_child(_game_player)
	for _i: int in 4: await process_frame
	_game_player._sync_equipped_test_meshes()
	_game_player._sync_equipped_skill_slots()
	var idle_observed := false
	for _i: int in 120:
		await physics_frame
		await process_frame
		var idle_state: Dictionary = _game_player.runtime_skill_playback_presenter.last_runtime_idle_pose_state
		if not idle_state.get("solved_replay_applied", false) or idle_state.get("solved_replay_bridge_frame", false): continue
		var idle_weapon: Node3D = _game_player.held_item_nodes.get(HAND)
		var idle_error := _pose_error(_game_player.humanoid_rig, idle_weapon, idle_state)
		_report["equipped_idle_pose_metrics"] = _last_pose_metrics.duplicate(true)
		_check(idle_error <= 0.00005, "equipped Combat Idle preserves saved finger/weapon relationship")
		idle_observed = true
		break
	_check(idle_observed, "equipped Combat Idle consumes the clip prepared by Skill Save")
	var runtime_legacy_before := _legacy_solve_count(_game_player.humanoid_rig)
	_report["runtime_legacy_count_before_activation"] = runtime_legacy_before
	_game_player._activate_skill_slot(SKILL)
	var activation: Dictionary = _game_player.get_last_skill_activation_result()
	_report["activation"] = activation
	if not _check(activation.get("runtime_playback_started", false), "equipped saved skill starts runtime playback"):
		_finish(); return
	var observed := false
	var equipped_first_position := Vector3.ZERO
	var equipped_position_recorded := false
	var equipped_motion := 0.0
	var equipped_relationship_error := 0.0
	var equipped_samples: Array = []
	var equipped_nonbridge_count := 0
	var equipped_last_body_time := 0.0
	var observation_trace: Array = []
	var runtime_presenter = _game_player.runtime_skill_playback_presenter
	var active_clip: Resource = runtime_presenter.active_runtime_clip
	_report["equipped_active_clip_contract"] = {"duration_seconds": active_clip.total_duration_seconds,
		"frame_times": active_clip.baked_frame_times, "bridge_flags": active_clip.get_meta("baked_solved_replay_bridge_frame", []),
		"two_hand_states": active_clip.baked_two_hand_states, "entry_bridge_seconds": runtime_presenter.last_entry_bridge_duration_seconds}
	for _i: int in 180:
		await physics_frame
		await process_frame
		var state: Dictionary = runtime_presenter.last_runtime_pose_state
		if _i < 10 or _i % 15 == 0 or (state.get("solved_replay_applied", false) and not state.get("solved_replay_bridge_frame", false)):
			observation_trace.append({"iteration": _i, "active": runtime_presenter.runtime_playback_active,
				"elapsed_seconds": runtime_presenter.chain_player._clip_elapsed, "total_seconds": runtime_presenter.chain_player._clip_total_duration,
				"playing": runtime_presenter.chain_player.is_playing(), "applied": state.get("solved_replay_applied", false),
				"bridge": state.get("solved_replay_bridge_frame", false), "two_hand_state": state.get("two_hand_state")})
		if observed and _verified_hands.size() == 2 and not runtime_presenter.runtime_playback_active: break
		if not state.get("solved_replay_applied", false) or state.get("solved_replay_bridge_frame", false): continue
		var weapon: Node3D = _game_player.held_item_nodes.get(HAND)
		var error := _pose_error(_game_player.humanoid_rig, weapon, state)
		_report["equipped_pose_metrics"] = _last_pose_metrics.duplicate(true)
		_report["equipped_replay_error_m_or_rad"] = error
		_check(error <= 0.00005, "equipped runtime preserves replayed finger/weapon relationship")
		_report["runtime_legacy_count_during_replay"] = _legacy_solve_count(_game_player.humanoid_rig)
		_check(_legacy_solve_count(_game_player.humanoid_rig) == runtime_legacy_before, "saved skill replay performs no legacy serial/seat solve")
		observed = true
		if _verified_hands.size() == 2:
			equipped_nonbridge_count += 1
			equipped_last_body_time = runtime_presenter.chain_player._clip_elapsed
			var metric_frame := _weapon_in_replay_reference(_game_player.humanoid_rig, weapon)
			if not equipped_position_recorded:
				equipped_first_position = metric_frame.origin
				equipped_position_recorded = true
			equipped_motion = maxf(equipped_motion, equipped_first_position.distance_to(metric_frame.origin))
			equipped_relationship_error = maxf(equipped_relationship_error,
				_saved_relationship_error(_game_player.humanoid_rig, weapon, before_save_hands))
			var diagnostics := _equipped_relationship_diagnostics(_game_player.humanoid_rig, weapon, state, before_save_hands)
			if equipped_samples.size() < 8: equipped_samples.append(diagnostics)
			if equipped_relationship_error > 0.00005 and not _report.has("first_equipped_binding_mismatch"):
				_report["first_equipped_binding_mismatch"] = diagnostics
			# Observe the entire active body, including later constrained frames.
			# The ordinary controller can apply recovery/Idle in the same tick as
			# completion, so the inactive pose must not be mistaken for skill grip.
			continue
		break
	_report["equipped_observation_trace"] = observation_trace
	_check(observed, "observed equipped non-bridge solved replay frame")
	if _verified_hands.size() == 2:
		_report["equipped_two_hand_realized_translation_m"] = equipped_motion
		_report["equipped_two_hand_relationship_error_m_or_rad"] = equipped_relationship_error
		_report["equipped_motion_measurement_origin"] = "RL_BoneRoot metric frame; excludes actor world translation"
		_report["equipped_binding_samples"] = equipped_samples
		_report["equipped_nonbridge_observed_count"] = equipped_nonbridge_count
		_report["equipped_last_active_body_time_seconds"] = equipped_last_body_time
		_report["equipped_clip_completed"] = not runtime_presenter.chain_player.is_playing() and runtime_presenter.chain_player._clip_elapsed >= runtime_presenter.chain_player._clip_total_duration
		_report["equipped_terminal_track_bridge_flag"] = runtime_presenter.last_runtime_pose_state.get("solved_replay_bridge_frame", false)
		_check(_report.equipped_clip_completed and not _report.equipped_terminal_track_bridge_flag,
			"equipped replay reaches the completed non-bridge terminal track")
		_check(equipped_motion > 0.0001, "equipped two-hand playback realizes more than 0.1 mm of weapon motion")
		_check(equipped_relationship_error <= 0.00005, "equipped motion preserves both established Hand-to-weapon relationships")
	_finish()

func _clip_frame_state(chain) -> Dictionary:
	return {"active": true, "runtime_clip_playback": true,
		"solved_replay_available": chain.current_solved_replay_available,
		"solved_replay_reference_bone_name": chain.current_solved_replay_reference_bone_name,
		"solved_upper_body_bone_names": chain.current_solved_upper_body_bone_names,
		"solved_upper_body_pose_positions": chain.current_solved_upper_body_pose_positions,
		"solved_upper_body_pose_rotations": chain.current_solved_upper_body_pose_rotations,
		"solved_upper_body_pose_scales": chain.current_solved_upper_body_pose_scales,
		"solved_weapon_position_reference_local": chain.current_solved_weapon_position_reference_local,
		"solved_weapon_rotation_reference_local": chain.current_solved_weapon_rotation_reference_local,
		"solved_weapon_scale_reference_local": chain.current_solved_weapon_scale_reference_local,
		"solved_anchor_node_paths": chain.current_solved_anchor_node_paths,
		"solved_anchor_positions_weapon_local": chain.current_solved_anchor_positions_weapon_local,
		"solved_anchor_rotations_weapon_local": chain.current_solved_anchor_rotations_weapon_local,
		"solved_anchor_scales_weapon_local": chain.current_solved_anchor_scales_weapon_local}

func _track_error(a: Resource, b: Resource) -> float:
	if a.baked_solved_upper_body_bone_names != b.baked_solved_upper_body_bone_names: return INF
	var error := 0.0
	for frame: int in a.get_frame_count():
		error = maxf(error, a.baked_solved_weapon_positions_reference_local[frame].distance_to(b.baked_solved_weapon_positions_reference_local[frame]))
		error = maxf(error, a.baked_solved_weapon_rotations_reference_local[frame].distance_to(b.baked_solved_weapon_rotations_reference_local[frame]))
		for bone: int in a.baked_solved_upper_body_bone_names.size():
			error = maxf(error, a.baked_solved_upper_body_pose_positions[frame][bone].distance_to(b.baked_solved_upper_body_pose_positions[frame][bone]))
			error = maxf(error, a.baked_solved_upper_body_pose_rotations[frame][bone].distance_to(b.baked_solved_upper_body_pose_rotations[frame][bone]))
	return error

func _pose_error(actor: Node3D, weapon: Node3D, state: Dictionary) -> float:
	if actor == null or weapon == null: return INF
	var skeleton: Skeleton3D = actor.skeleton
	var names: Array = state.get("solved_upper_body_bone_names", [])
	var rotations: Array = state.get("solved_upper_body_pose_rotations", [])
	if names.is_empty() or names.size() != rotations.size(): return INF
	var error := 0.0
	var worst_bone := StringName()
	for slot: StringName in _verified_hands:
		for name: StringName in Rules.get_finger_bone_names(slot):
			var track_index := names.find(name)
			var bone_index := skeleton.find_bone(name)
			if track_index < 0 or bone_index < 0: return INF
			var bone_error := _rotation_error(skeleton.get_bone_pose_rotation(bone_index), rotations[track_index])
			if bone_error > error: worst_bone = name
			error = maxf(error, bone_error)
	var reference := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RL_BoneRoot"))
	# Replay's named RL_BoneRoot reference is a metric frame: both production
	# capture and playback remove imported skeleton scale from this basis.
	reference.basis = reference.basis.orthonormalized()
	var actual := reference.affine_inverse() * weapon.global_transform
	var position_error := actual.origin.distance_to(state.solved_weapon_position_reference_local)
	var rotation_error := _rotation_error(actual.basis.orthonormalized().get_rotation_quaternion(), state.solved_weapon_rotation_reference_local)
	_last_pose_metrics = {"finger_rotation_max_rad": error, "worst_finger_bone": worst_bone,
		"verified_hands": _verified_hands.duplicate(),
		"weapon_position_error_m": position_error, "weapon_rotation_error_rad": rotation_error}
	error = maxf(error, maxf(position_error, rotation_error))
	return error

func _hand_in_weapon(actor: Node3D, weapon: Node3D, slot: StringName) -> Transform3D:
	var skeleton: Skeleton3D = actor.skeleton
	return weapon.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand"))

func _saved_relationship_error(actor: Node3D, weapon: Node3D, expected: Dictionary) -> float:
	var error := 0.0
	for slot: StringName in _verified_hands:
		var before: Transform3D = expected[slot]
		var actual := _hand_in_weapon(actor, weapon, slot)
		error = maxf(error, maxf(before.origin.distance_to(actual.origin),
			_rotation_error(before.basis.orthonormalized().get_rotation_quaternion(), actual.basis.orthonormalized().get_rotation_quaternion())))
	return error

func _weapon_in_replay_reference(actor: Node3D, weapon: Node3D) -> Transform3D:
	var skeleton: Skeleton3D = actor.skeleton
	var reference := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RL_BoneRoot"))
	reference.basis = reference.basis.orthonormalized()
	return reference.affine_inverse() * weapon.global_transform

func _two_hand_motion_fidelity(clip: Resource, requested_shift: Vector3) -> Dictionary:
	var positions: PackedVector3Array = clip.baked_solved_weapon_positions_reference_local
	var rotations: PackedVector4Array = clip.baked_solved_weapon_rotations_reference_local
	var result := {"finite": true, "maximum_rotation_rad": 0.0, "maximum_off_path_m": 0.0,
		"minimum_progress_m": 0.0, "maximum_progress_m": 0.0, "maximum_backward_step_m": 0.0,
		"requested_shift_reference_m": requested_shift, "frames": []}
	if positions.is_empty() or rotations.size() != positions.size() or requested_shift.length_squared() <= 0.0:
		result.finite = false
		return result
	var first_q := Quaternion(rotations[0].x, rotations[0].y, rotations[0].z, rotations[0].w)
	var direction := requested_shift.normalized()
	var prior_progress := 0.0
	for index: int in positions.size():
		var delta := positions[index] - positions[0]
		var q := Quaternion(rotations[index].x, rotations[index].y, rotations[index].z, rotations[index].w)
		var progress := delta.dot(direction)
		var off_path := (delta - direction * progress).length()
		var rotation := _rotation_error(first_q, q)
		result.finite = result.finite and positions[index].is_finite() and q.is_finite()
		result.maximum_rotation_rad = maxf(result.maximum_rotation_rad, rotation)
		result.maximum_off_path_m = maxf(result.maximum_off_path_m, off_path)
		result.minimum_progress_m = minf(result.minimum_progress_m, progress)
		result.maximum_progress_m = maxf(result.maximum_progress_m, progress)
		result.maximum_backward_step_m = maxf(result.maximum_backward_step_m, prior_progress - progress)
		result.frames.append({"frame": index, "time_seconds": clip.baked_frame_times[index],
			"authored_tip": clip.baked_tip_positions_local[index], "authored_pommel": clip.baked_pommel_positions_local[index],
			"actual_delta_reference_m": delta, "progress_m": progress, "off_path_m": off_path, "rotation_rad": rotation})
		prior_progress = progress
	return result

func _equipped_relationship_diagnostics(actor: Node3D, weapon: Node3D, state: Dictionary, expected: Dictionary) -> Dictionary:
	var skeleton: Skeleton3D = actor.skeleton
	var hands: Dictionary = {}
	for slot: StringName in _verified_hands:
		var before: Transform3D = expected[slot]
		var actual := _hand_in_weapon(actor, weapon, slot)
		var relative := (before.basis.orthonormalized().get_rotation_quaternion().inverse()
			* actual.basis.orthonormalized().get_rotation_quaternion()).normalized()
		hands[slot] = {"position_error_m": (weapon.global_basis * (actual.origin - before.origin)).length(),
			"orientation_error_rad": 2.0 * atan2(Vector3(relative.x, relative.y, relative.z).length(), absf(relative.w)),
			"expected_hand_in_weapon": before, "actual_hand_in_weapon": actual}
	var names: Array = state.get("solved_upper_body_bone_names", [])
	var rotations: Array = state.get("solved_upper_body_pose_rotations", [])
	var positions: Array = state.get("solved_upper_body_pose_positions", [])
	var scales: Array = state.get("solved_upper_body_pose_scales", [])
	var mismatches: Array = []
	for index: int in names.size():
		var bone: int = skeleton.find_bone(names[index])
		if bone < 0 or index >= rotations.size() or index >= positions.size() or index >= scales.size():
			mismatches.append({"bone": names[index], "missing_bone_or_track": true})
			continue
		var rotation_error := _rotation_error(skeleton.get_bone_pose_rotation(bone), rotations[index])
		var position_error := skeleton.get_bone_pose_position(bone).distance_to(positions[index])
		var scale_error := skeleton.get_bone_pose_scale(bone).distance_to(scales[index])
		if rotation_error > 0.00005 or position_error > 0.00005 or scale_error > 0.000005:
			mismatches.append({"bone": names[index], "rotation_error_rad": rotation_error,
				"local_position_error": position_error, "local_scale_error": scale_error,
				"actual_pose": skeleton.get_bone_pose(bone), "recorded_position": positions[index],
				"recorded_rotation": rotations[index], "recorded_scale": scales[index]})
	return {"hands": hands, "recorded_upper_body_pose_mismatches": mismatches,
		"skeleton_world": skeleton.global_transform, "weapon_world": weapon.global_transform,
		"actual_weapon_reference_frame": _weapon_in_replay_reference(actor, weapon),
		"recorded_weapon_reference_position": state.get("solved_weapon_position_reference_local"),
		"two_hand_state": state.get("two_hand_state"), "grip_style": state.get("preferred_grip_style_mode"),
		"bridge_frame": state.get("solved_replay_bridge_frame", false)}


func _rotation_error(a: Quaternion, b: Quaternion) -> float:
	# Component distance remains stable below the float32 acos resolution.
	return 2.0 * (a.normalized() - (b.normalized() if a.dot(b) >= 0.0 else -b.normalized())).length()

func _legacy_solve_count(actor: Node3D) -> int:
	var count := 0
	for states: Dictionary in [actor.finger_grip_presenter.surface_grasp_state_lookup, actor.finger_grip_presenter.weapon_surface_seat_state_lookup]:
		for state: Dictionary in states.values():
			count += int(state.get("solve_count", 0))
	return count

func _finish() -> void:
	if not _source_hash.is_empty(): _check(FileAccess.get_sha256(_source) == _source_hash, "input library remains byte-for-byte unchanged")
	_report.merge({"checks": _checks, "failures": _failures, "passed": _failures.is_empty()})
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	var output := FileAccess.open(_prefix + "_report.json", FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify(_report, "\t"))
	if is_instance_valid(_ui):
		_ui.preview_presenter.cancel_grip_acquisition(_ui.preview_subviewport)
		_ui.queue_free()
	if is_instance_valid(_game_player): _game_player.queue_free()
	if is_instance_valid(_library_player): _library_player.queue_free()
	print(JSON.stringify({"report": _prefix + "_report.json", "checks": _checks, "failures": _failures}))
	quit(0 if _failures.is_empty() else 1)
