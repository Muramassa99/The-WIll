extends SceneTree

## --source=C:/.../profile_library.tres --out=C:/.../equipped_playback.json
## Reads the actual saved 20-visible-node slot 1. Only the report is written.
## Deterministic presenter stepping with real rig modifier frames; not a visual,
## continuous-playback, collision, or full-hand grip certificate.
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const ChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")
const SeatResolverScript = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const WEAPON_NAME := "Broken_Balde_v1"
const SLOT := &"skill_slot_1"
const HAND := &"hand_right"
const POSITION_EPSILON := 0.0001
const ROTATION_EPSILON := 0.001

class MemoryEquipment extends PlayerEquipmentState:
	var suppressed_writes := 0
	func persist() -> bool:
		suppressed_writes += 1
		return true

class MemorySlots extends PlayerSkillSlotState:
	var suppressed_writes := 0
	func persist() -> bool:
		suppressed_writes += 1
		return true

class MemoryLibrary extends PlayerForgeWipLibraryState:
	var suppressed_writes := 0
	func persist() -> bool:
		suppressed_writes += 1
		return true

var _source := ""
var _output := ""
var _source_hash := ""
var _player: PlayerController3D
var _weapon: Node3D
var _weapon_id := StringName()
var _observed_skeleton: Skeleton3D
var _observation_chain: CombatAnimationChainPlayer
var _pose_observation_sequence: int = 0
var _pose_request_sequence_before: int = 0
var _pose_request_id: int = 0
var _pose_snapshot: Dictionary = {}
var _equipment := MemoryEquipment.new()
var _slots := MemorySlots.new()
var _library := MemoryLibrary.new()
var _report: Dictionary = {
	"complete": false, "ok": false, "samples": [],
	"scope": "saved slot resolution, equipped presenter and real rig application at selected times",
	"limits": "No continuous playback, recovery, visual quality, collision or full-hand grip certification.",
	"position_tolerance_m": POSITION_EPSILON, "rotation_tolerance_rad": ROTATION_EPSILON,
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() != 2:
			continue
		if pair[0] == "source": _source = pair[1]
		if pair[0] == "out": _output = pair[1]
	if not _source.is_absolute_path() or not _output.is_absolute_path():
		_finish(false, "absolute_source_and_out_required"); return
	if _source.replace("\\", "/").to_lower() == _output.replace("\\", "/").to_lower():
		_output = ""
		_finish(false, "report_cannot_overwrite_source"); return
	if FileAccess.file_exists(_output):
		_output = ""
		_finish(false, "fresh_report_path_required"); return
	if not FileAccess.file_exists(_source):
		_finish(false, "source_library_missing"); return
	_source_hash = FileAccess.get_sha256(_source)
	var loaded := ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	if loaded == null:
		_finish(false, "source_library_load_failed"); return
	var saved_weapon: CraftedItemWIP
	for candidate: CraftedItemWIP in loaded.saved_wips:
		if candidate != null and candidate.forge_project_name == WEAPON_NAME:
			if saved_weapon != null:
				_finish(false, "ambiguous_weapon_name"); return
			saved_weapon = candidate
	if saved_weapon == null:
		_finish(false, "saved_weapon_missing"); return
	_weapon_id = saved_weapon.wip_id
	var station := saved_weapon.combat_animation_station_state as CombatAnimationStationState
	var saved_draft: CombatAnimationDraft
	if station != null:
		for candidate: CombatAnimationDraft in station.skill_drafts:
			if candidate != null and candidate.legal_slot_id == SLOT:
				if saved_draft != null:
					_finish(false, "ambiguous_saved_slot"); return
				saved_draft = candidate
	if saved_draft == null:
		_finish(false, "saved_slot_missing"); return
	var saved_clip := saved_draft.baked_runtime_clip as CombatRuntimeClip
	var saved_tracks := _complete_saved_tracks(saved_clip)
	_report.merge({
		"source": _source, "source_sha256": _source_hash, "weapon": WEAPON_NAME,
		"weapon_id": String(_weapon_id), "slot": String(SLOT), "draft_id": String(saved_draft.draft_id),
		"raw_node_count": saved_draft.motion_node_chain.size(),
		"visible_node_count": saved_draft.motion_node_chain.size() - 1,
		"saved_tracks": saved_tracks,
	})
	if saved_draft.draft_kind != CombatAnimationDraft.DRAFT_KIND_SKILL or saved_draft.motion_node_chain.size() != 21:
		_finish(false, "expected_20_visible_nodes_plus_hidden_entry"); return
	if saved_draft.preview_loop_enabled or not bool(saved_tracks.get("ok", false)):
		_finish(false, "nonlooping_complete_saved_replay_required"); return

	# These are the freshly loaded saved resources. Production readers clone them;
	# no Save, normalization, fixture rebuild or publication happens in this tool.
	_library.saved_wips = loaded.saved_wips
	_library.selected_wip_id = _weapon_id
	if _equipment.equip_forge_test_wip(HAND, saved_weapon) == null:
		_finish(false, "equip_failed"); return
	_player = PlayerScene.instantiate() as PlayerController3D
	if _player == null:
		_finish(false, "player_scene_instantiation_failed"); return
	_player.equipment_state = _equipment
	_player.forge_wip_library_state = _library
	_player.player_skill_slot_state = _slots
	_player.weapons_drawn = true
	root.add_child(_player)
	# Keep the real rig/modifier processing. The normal controller idle update is
	# stepped below before activation; automatic locomotion/playback stay frozen
	# so neither free fall nor automatic advances affect the exact samples.
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	for _index: int in 3:
		await physics_frame
		await process_frame
	_weapon = _player.held_item_nodes.get(HAND) as Node3D
	if _weapon == null or StringName(_weapon.get_meta("source_wip_id", StringName())) != _weapon_id:
		_finish(false, "actual_equipped_weapon_missing"); return
	_observed_skeleton = _player.humanoid_rig.get("skeleton") as Skeleton3D
	if _observed_skeleton == null:
		_finish(false, "actual_equipped_skeleton_missing"); return
	# A direct signal callback observes the final skin pose while modifier output
	# is still applied. Reading after process_frame can see restored input poses.
	_observed_skeleton.skeleton_updated.connect(_capture_final_skeleton_pose)
	_report["pre_idle_weapon"] = _weapon_transform_diagnostic()
	var idle_ready: bool = await _prepare_combat_idle()
	if not idle_ready:
		_finish(false, "production_combat_idle_not_ready"); return
	_report["pre_activation_weapon"] = _weapon_transform_diagnostic()
	_player.call("_sync_equipped_skill_slots")
	_player.call("_activate_skill_slot", SLOT)
	var activation: Dictionary = _player.get_last_skill_activation_result()
	_report["activation"] = {
		"success": activation.get("success", false),
		"runtime_playback_started": activation.get("runtime_playback_started", false),
		"grip_replay_ready": activation.get("grip_replay_ready", false),
		"message": activation.get("message", ""),
		"runtime_message": activation.get("runtime_playback_message", ""),
		"source_weapon_wip_id": String(activation.get("source_weapon_wip_id", "")),
		"source_skill_draft_id": String(activation.get("source_skill_draft_id", "")),
		"source_equipment_slot_id": String(activation.get("source_equipment_slot_id", "")),
	}
	if (
		not bool(activation.get("success", false))
		or not bool(activation.get("runtime_playback_started", false))
		or not bool(activation.get("grip_replay_ready", false))
		or StringName(activation.get("source_weapon_wip_id", StringName())) != _weapon_id
		or StringName(activation.get("source_skill_draft_id", StringName())) != saved_draft.draft_id
		or StringName(activation.get("source_equipment_slot_id", StringName())) != HAND
	):
		_finish(false, "saved_slot_activation_failed"); return
	var presenter: PlayerRuntimeSkillPlaybackPresenter = _player.runtime_skill_playback_presenter
	var runtime_clip: CombatRuntimeClip = presenter.active_runtime_clip
	if runtime_clip == null or not runtime_clip.has_solved_replay_track():
		_finish(false, "equipped_solved_track_missing"); return
	var offset: float = presenter.last_entry_bridge_duration_seconds
	_report["runtime"] = {
		"duration_seconds": runtime_clip.total_duration_seconds,
		"frame_count": runtime_clip.get_frame_count(),
		"saved_duration_seconds": saved_clip.total_duration_seconds,
		"entry_bridge_seconds": offset,
		"cached_track_copied": presenter.active_runtime_skill_result.get("cached_runtime_clip_upper_body_pose_track", false),
		"compile_diagnostics": presenter.active_runtime_skill_result.get("runtime_compile_diagnostics", []),
	}
	if not bool(_report.runtime.cached_track_copied):
		_finish(false, "saved_track_not_consumed"); return
	await _settle_rig(presenter.chain_player)
	var entry := _sample("activation_start", 0.0, presenter.last_runtime_pose_state, false)
	entry["comparison"] = "Current-pose entry bridge; not equality with the first saved pose." if offset > 0.0001 else "Initial saved pose."
	_report.samples.append(entry)
	var all_ok := bool(entry.ok)
	var first_authored_time := -1.0
	var bridge_flags: Array = runtime_clip.get_meta("baked_solved_replay_bridge_frame", [])
	for index: int in runtime_clip.get_frame_count():
		if runtime_clip.baked_frame_times[index] >= offset and (bridge_flags.is_empty() or not bool(bridge_flags[index])):
			first_authored_time = runtime_clip.baked_frame_times[index]
			break
	if first_authored_time < 0.0:
		_finish(false, "authored_runtime_frame_missing"); return
	var times: Array[float] = [
		first_authored_time,
		maxf(first_authored_time, offset + saved_clip.total_duration_seconds * 0.5),
		runtime_clip.total_duration_seconds,
	]
	var labels := ["authored_start", "authored_middle", "terminal"]
	var elapsed := 0.0
	var terminal_state: Dictionary = {}
	for index: int in times.size():
		var target_time: float = times[index]
		var delta := maxf(target_time - elapsed, 0.0) / presenter.chain_player.speed_scale
		# Cross the declared duration explicitly, exercising the actual terminal
		# sample and completion signal instead of a near-end interpolated pose.
		if index == times.size() - 1: delta += 0.00001
		var state := presenter.advance_playback(delta, _player.humanoid_rig, _player.held_item_nodes)
		elapsed = target_time
		await _settle_rig(presenter.chain_player)
		var sample := _sample(labels[index], target_time, state, true)
		_report.samples.append(sample)
		all_ok = all_ok and bool(sample.ok)
		if index == times.size() - 1: terminal_state = state
	var source_player = ChainPlayerScript.new()
	source_player.prepare_runtime_clip(saved_clip, 1.0, false)
	source_player.start()
	source_player.advance(saved_clip.total_duration_seconds + 0.00001)
	var saved_terminal := _compare_terminal_source(presenter.chain_player, source_player)
	_report["terminal_matches_saved"] = saved_terminal
	_report["terminal_finished"] = bool(terminal_state.get("finished", false)) and not presenter.chain_player.is_playing()
	all_ok = all_ok and bool(saved_terminal.ok) and bool(_report.terminal_finished)
	_finish(all_ok, "" if all_ok else "equipped_sample_or_terminal_check_failed")

func _settle_rig(chain: CombatAnimationChainPlayer) -> void:
	_pose_request_id += 1
	_pose_request_sequence_before = _pose_observation_sequence
	_pose_snapshot = {}
	_observation_chain = chain
	await physics_frame
	await process_frame
	await process_frame
	_observation_chain = null

func _capture_final_skeleton_pose() -> void:
	if _observation_chain == null or not is_instance_valid(_observed_skeleton):
		return
	_pose_observation_sequence += 1
	var skeleton_world: Transform3D = _observed_skeleton.global_transform
	var bones: Dictionary = {}
	for name: StringName in _observation_chain.current_solved_upper_body_bone_names:
		var bone_index: int = _observed_skeleton.find_bone(String(name))
		if bone_index < 0:
			continue
		var global_pose: Transform3D = _observed_skeleton.get_bone_global_pose(bone_index)
		bones[String(name)] = {
			"local_pose": _observed_skeleton.get_bone_pose(bone_index),
			"skeleton_global_pose": global_pose,
			"world_pose": skeleton_world * global_pose,
		}
	var snapshot: Dictionary = {
		"signal": "Skeleton3D.skeleton_updated",
		"request_id": _pose_request_id, "sequence": _pose_observation_sequence,
		"sequence_before_request": _pose_request_sequence_before,
		"process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(),
		"skeleton_world_transform": skeleton_world, "bones": bones,
		"reference_bone_name": String(_observation_chain.current_solved_replay_reference_bone_name),
		"anchors": {}, "same_equipped_weapon": false,
	}
	var reference_index: int = _observed_skeleton.find_bone(String(_observation_chain.current_solved_replay_reference_bone_name))
	if reference_index >= 0:
		var reference_world: Transform3D = skeleton_world * _observed_skeleton.get_bone_global_pose(reference_index)
		snapshot["reference_bone_world_transform"] = reference_world
		reference_world.basis = reference_world.basis.orthonormalized()
		snapshot["replay_reference_world_transform"] = reference_world
	if is_instance_valid(_weapon):
		var weapon_world: Transform3D = _weapon.global_transform
		snapshot["weapon_world_transform"] = weapon_world
		snapshot["weapon_instance_id"] = _weapon.get_instance_id()
		snapshot["same_equipped_weapon"] = (
			_player.held_item_nodes.get(HAND) == _weapon
			and StringName(_weapon.get_meta("source_wip_id", StringName())) == _weapon_id
		)
		if snapshot.has("replay_reference_world_transform"):
			var captured_reference: Transform3D = snapshot.replay_reference_world_transform
			snapshot["weapon_reference_local_transform"] = captured_reference.affine_inverse() * weapon_world
		for path: StringName in _observation_chain.current_solved_anchor_node_paths:
			var anchor: Node3D = _weapon.get_node_or_null(NodePath(String(path))) as Node3D
			if anchor == null:
				continue
			var anchor_world: Transform3D = anchor.global_transform
			snapshot.anchors[String(path)] = {
				"world_transform": anchor_world,
				"weapon_local_transform": weapon_world.affine_inverse() * anchor_world,
			}
	_pose_snapshot = snapshot

func _prepare_combat_idle() -> bool:
	var presenter: PlayerRuntimeSkillPlaybackPresenter = _player.runtime_skill_playback_presenter
	var preparation: Dictionary = {
		"mode": "Controlled production PlayerController._advance_runtime_skill_playback ticks before slot activation.",
		"tick_delta_seconds": 1.0 / 60.0, "samples": [], "ok": false,
		"scope": "Already drawn combat-idle lifecycle; cold activation and draw-from-stow are not covered.",
	}
	_report["combat_idle_preparation"] = preparation
	for tick: int in 2:
		_player.call("_advance_runtime_skill_playback", 1.0 / 60.0)
		await _settle_rig(presenter.idle_chain_player)
		var resolved: Dictionary = _player.last_runtime_idle_pose_result
		var sample: Dictionary = _sample(
			"combat_idle_tick_%d" % (tick + 1),
			float(tick + 1) / 60.0,
			presenter.last_runtime_idle_pose_state,
			true,
			presenter.idle_chain_player
		)
		sample.merge({
			"resolved_success": bool(resolved.get("success", false)),
			"grip_replay_ready": bool(resolved.get("grip_replay_ready", false)),
			"runtime_idle_active": presenter.runtime_idle_active,
			"reported_idle_applied": bool(resolved.get("runtime_idle_applied", false)),
			"cached_track_copied": bool(presenter.active_runtime_idle_result.get("cached_runtime_clip_upper_body_pose_track", false)),
			"source_weapon_wip_id": String(resolved.get("source_weapon_wip_id", "")),
			"source_equipment_slot_id": String(resolved.get("source_equipment_slot_id", "")),
			"draft_id": String(resolved.get("draft_id", "")),
			"idle_context_id": String(resolved.get("idle_context_id", "")),
			"message": String(resolved.get("runtime_idle_message", resolved.get("message", ""))),
		})
		sample["ok"] = (
			bool(sample.ok) and bool(sample.resolved_success) and bool(sample.grip_replay_ready)
			and bool(sample.runtime_idle_active) and bool(sample.cached_track_copied)
			and StringName(sample.source_weapon_wip_id) == _weapon_id
			and StringName(sample.source_equipment_slot_id) == HAND
			and StringName(sample.idle_context_id) == CombatAnimationStationState.IDLE_CONTEXT_COMBAT
		)
		preparation.samples.append(sample)
		preparation["post_idle_weapon"] = _weapon_transform_diagnostic()
		if not bool(sample.ok):
			return false
	preparation["ok"] = true
	return true

func _weapon_transform_diagnostic() -> Dictionary:
	if not is_instance_valid(_weapon):
		return {"reason": "missing_weapon"}
	var mount_parent := _weapon.get_parent() as Node3D
	return {
		"weapon_local_scale": _weapon.basis.get_scale(),
		"weapon_world_scale": _weapon.global_basis.get_scale(),
		"parent_path": str(_weapon.get_parent().get_path()),
		"parent_world_scale": mount_parent.global_basis.get_scale() if mount_parent != null else Vector3.ZERO,
		"hand_spans_metadata_m": _weapon.get_meta("hand_grip_spans_meters", {}),
	}

func _complete_saved_tracks(clip: CombatRuntimeClip) -> Dictionary:
	if clip == null or not clip.has_solved_replay_track():
		return {"ok": false, "reason": "missing_solved_track"}
	if clip.get_frame_count() < 2 or not is_finite(clip.total_duration_seconds) or clip.total_duration_seconds <= 0.0:
		return {"ok": false, "reason": "invalid_saved_duration"}
	var bones := clip.baked_solved_upper_body_bone_names.size()
	var anchors := clip.baked_solved_anchor_node_paths.size()
	for index: int in clip.get_frame_count():
		if index > 0 and clip.baked_frame_times[index] < clip.baked_frame_times[index - 1]:
			return {"ok": false, "reason": "nonmonotonic_saved_times", "frame": index}
		if not bool(clip.baked_solved_replay_frame_available[index]):
			return {"ok": false, "reason": "unavailable_saved_frame", "frame": index}
		for field: String in ["baked_solved_upper_body_pose_positions", "baked_solved_upper_body_pose_rotations", "baked_solved_upper_body_pose_scales", "baked_solved_anchor_positions_weapon_local", "baked_solved_anchor_rotations_weapon_local", "baked_solved_anchor_scales_weapon_local"]:
			var values: Variant = clip.get(field)[index]
			var expected := anchors if field.contains("anchor") else bones
			if values.size() != expected:
				return {"ok": false, "reason": "incomplete_saved_frame", "field": field, "frame": index}
			for value: Variant in values:
				if not value.is_finite():
					return {"ok": false, "reason": "nonfinite_saved_frame", "field": field, "frame": index}
		if (
			not is_finite(clip.baked_frame_times[index])
			or not clip.baked_solved_weapon_positions_reference_local[index].is_finite()
			or not clip.baked_solved_weapon_rotations_reference_local[index].is_finite()
			or not clip.baked_solved_weapon_scales_reference_local[index].is_finite()
		):
			return {"ok": false, "reason": "nonfinite_saved_weapon_or_time", "frame": index}
	return {"ok": anchors > 0, "frame_count": clip.get_frame_count(), "bone_count": bones, "anchor_count": anchors}

func _sample(
	label: String,
	time_seconds: float,
	state: Dictionary,
	compare_pose: bool,
	sample_chain: CombatAnimationChainPlayer = null
) -> Dictionary:
	var same_weapon: bool = is_instance_valid(_weapon) and _player.held_item_nodes.get(HAND) == _weapon
	same_weapon = same_weapon and StringName(_weapon.get_meta("source_wip_id", StringName())) == _weapon_id
	var row := {
		"label": label, "time_seconds": time_seconds,
		"solved_replay_applied": state.get("solved_replay_applied", false),
		"solved_replay_available": state.get("solved_replay_available", false),
		"entry_bridge_frame": state.get("solved_replay_bridge_frame", false),
		"grip_endcap_replay_invalid": state.get("grip_endcap_replay_invalid", false),
		"grip_endcap_replay_reason": String(state.get("grip_endcap_replay_reason", "")),
		"same_equipped_weapon": same_weapon, "status": String(state.get("status", "")),
	}
	row["end_bounds_diagnostic"] = _end_bounds_diagnostic(state)
	var chain: CombatAnimationChainPlayer = sample_chain if sample_chain != null else _player.runtime_skill_playback_presenter.chain_player
	var fresh_snapshot: bool = (
		not _pose_snapshot.is_empty()
		and int(_pose_snapshot.get("request_id", -1)) == _pose_request_id
		and int(_pose_snapshot.get("sequence", -1)) > _pose_request_sequence_before
	)
	row["fresh_final_pose_snapshot"] = fresh_snapshot
	row["rendered_pose_observation"] = _pose_snapshot.duplicate(true)
	if not fresh_snapshot:
		row.merge({"ok": false, "finite_pose": false, "reason": "fresh_skeleton_updated_snapshot_missing"})
		return row
	var finite_pose: bool = same_weapon and bool(_pose_snapshot.get("same_equipped_weapon", false))
	var errors: Dictionary = {
		"max_position_error_m": 0.0, "max_rotation_error_rad": 0.0, "max_scale_error": 0.0,
		"worst_position": {}, "worst_rotation": {}, "worst_scale": {},
	}
	var missing: Array[String] = []
	var bones: Dictionary = _pose_snapshot.get("bones", {})
	for index: int in chain.current_solved_upper_body_bone_names.size():
		var name: String = String(chain.current_solved_upper_body_bone_names[index])
		if not bones.has(name):
			missing.append("bone:" + name)
			continue
		var observed: Dictionary = bones[name]
		var local_pose: Transform3D = observed.local_pose
		var world_pose: Transform3D = observed.world_pose
		var global_pose: Transform3D = observed.skeleton_global_pose
		finite_pose = finite_pose and local_pose.is_finite() and world_pose.is_finite() and global_pose.is_finite()
		_accumulate_pose_error(errors, "bone:" + name, local_pose,
			chain.current_solved_upper_body_pose_positions[index],
			chain.current_solved_upper_body_pose_rotations[index],
			chain.current_solved_upper_body_pose_scales[index])
	if _pose_snapshot.has("weapon_reference_local_transform"):
		var weapon_local: Transform3D = _pose_snapshot.weapon_reference_local_transform
		var weapon_world: Transform3D = _pose_snapshot.weapon_world_transform
		var reference_world: Transform3D = _pose_snapshot.replay_reference_world_transform
		finite_pose = finite_pose and weapon_local.is_finite() and weapon_world.is_finite() and reference_world.is_finite()
		_accumulate_pose_error(errors, "weapon:reference_local", weapon_local,
			chain.current_solved_weapon_position_reference_local,
			chain.current_solved_weapon_rotation_reference_local,
			chain.current_solved_weapon_scale_reference_local)
	else:
		missing.append("weapon:reference_local")
	var anchors: Dictionary = _pose_snapshot.get("anchors", {})
	for index: int in chain.current_solved_anchor_node_paths.size():
		var path: String = String(chain.current_solved_anchor_node_paths[index])
		if not anchors.has(path):
			missing.append("anchor:" + path)
			continue
		var observed: Dictionary = anchors[path]
		var local_pose: Transform3D = observed.weapon_local_transform
		var world_pose: Transform3D = observed.world_transform
		finite_pose = finite_pose and local_pose.is_finite() and world_pose.is_finite()
		_accumulate_pose_error(errors, "anchor:" + path, local_pose,
			chain.current_solved_anchor_positions_weapon_local[index],
			chain.current_solved_anchor_rotations_weapon_local[index],
			chain.current_solved_anchor_scales_weapon_local[index])
	finite_pose = finite_pose and missing.is_empty()
	var pose_matches: bool = (
		float(errors.max_position_error_m) <= POSITION_EPSILON
		and float(errors.max_rotation_error_rad) <= ROTATION_EPSILON
		and float(errors.max_scale_error) <= POSITION_EPSILON
		and missing.is_empty()
	)
	row.merge(errors)
	row.merge({
		"finite_pose": finite_pose, "pose_equality_checked": compare_pose,
		"missing_transform_labels": missing,
		"bone_count": chain.current_solved_upper_body_bone_names.size(),
		"anchor_count": chain.current_solved_anchor_node_paths.size(),
		"pose_matches_runtime_sample": pose_matches,
		"ok": bool(row.solved_replay_applied) and bool(row.solved_replay_available)
			and not bool(row.grip_endcap_replay_invalid) and finite_pose and same_weapon
			and chain.current_solved_upper_body_bone_names.size() > 0
			and chain.current_solved_anchor_node_paths.size() > 0
			and (not compare_pose or (pose_matches and not bool(row.entry_bridge_frame))),
	})
	return row

func _accumulate_pose_error(
	errors: Dictionary,
	label: String,
	actual: Transform3D,
	expected_position: Vector3,
	expected_rotation: Quaternion,
	expected_scale: Vector3
) -> void:
	var actual_rotation: Quaternion = actual.basis.get_rotation_quaternion()
	var actual_scale: Vector3 = actual.basis.get_scale()
	var position_error: float = actual.origin.distance_to(expected_position)
	var rotation_error: float = actual_rotation.angle_to(expected_rotation)
	var scale_error: float = actual_scale.distance_to(expected_scale)
	if position_error > float(errors.max_position_error_m):
		errors["max_position_error_m"] = position_error
		errors["worst_position"] = {"label": label, "actual": actual.origin, "expected": expected_position}
	if rotation_error > float(errors.max_rotation_error_rad):
		errors["max_rotation_error_rad"] = rotation_error
		errors["worst_rotation"] = {"label": label, "actual": actual_rotation, "expected": expected_rotation}
	if scale_error > float(errors.max_scale_error):
		errors["max_scale_error"] = scale_error
		errors["worst_scale"] = {"label": label, "actual": actual_scale, "expected": expected_scale}

func _end_bounds_diagnostic(state: Dictionary) -> Dictionary:
	if not is_instance_valid(_weapon):
		return {"reason": "missing_weapon"}
	var presenter: PlayerRuntimeSkillPlaybackPresenter = _player.runtime_skill_playback_presenter
	var start: Vector3 = _weapon.get_meta("primary_grip_span_start_local", Vector3.ZERO)
	var end: Vector3 = _weapon.get_meta("primary_grip_span_end_local", Vector3.ZERO)
	var span: Vector3 = end - start
	var hand_spans: Dictionary = _weapon.get_meta("hand_grip_spans_meters", {})
	var saved_scale: Vector3 = state.get("solved_weapon_scale_reference_local", Vector3.ONE)
	var saved_rotation: Quaternion = state.get("solved_weapon_rotation_reference_local", Quaternion.IDENTITY)
	var saved_basis := Basis(saved_rotation.normalized()).scaled(saved_scale)
	var saved_length: float = (saved_basis * span).length()
	var current_length: float = (_weapon.global_basis * span).length()
	var skeleton: Skeleton3D = _player.humanoid_rig.get("skeleton") as Skeleton3D
	var parent_3d := _weapon.get_parent() as Node3D
	var result: Dictionary = {
		"validation": presenter.live_pose_presenter.validate_solved_replay_hand_end_bounds(_weapon, state),
		"span_start_local": start, "span_end_local": end,
		"span_start_origin_id": String(_weapon.get_meta("primary_grip_span_start_origin_id", "")),
		"span_end_origin_id": String(_weapon.get_meta("primary_grip_span_end_origin_id", "")),
		"span_length_local": span.length(),
		"current_handle_length_world_m": current_length,
		"saved_basis_handle_length_world_m": saved_length,
		"weapon_local_scale": _weapon.basis.get_scale(),
		"weapon_world_scale": _weapon.global_basis.get_scale(),
		"weapon_world_basis": _weapon.global_basis,
		"weapon_parent_path": str(_weapon.get_parent().get_path()),
		"weapon_parent_world_scale": parent_3d.global_basis.get_scale() if parent_3d != null else Vector3.ZERO,
		"rig_world_scale": _player.humanoid_rig.global_basis.get_scale(),
		"skeleton_world_scale": skeleton.global_basis.get_scale() if skeleton != null else Vector3.ZERO,
		"saved_weapon_reference_scale": saved_scale,
		"saved_weapon_reference_basis": saved_basis,
		"saved_weapon_reference_origin_id": String(state.get("solved_weapon_reference_origin_id", "")),
		"hand_spans_metadata_m": hand_spans,
		"hand_spans_current_rig_m": _player.humanoid_rig.call("get_hand_grip_spans_meters"),
		"measurement_cache": _weapon.get_meta("preview_handle_span_measurement", {}),
		"anchors": [],
		"prospective_bounds_note": "Pure calculation using saved weapon basis and current hand span. No transform was applied; this is diagnostic, not a playback pass.",
	}
	var paths: Array = state.get("solved_anchor_node_paths", [])
	var positions: Array = state.get("solved_anchor_positions_weapon_local", [])
	var dominant: StringName = StringName(state.get("primary_hand_slot", HAND))
	if dominant != &"hand_left": dominant = HAND
	var slots: Array[StringName] = [dominant, &"hand_left" if dominant == HAND else HAND]
	var names: Array[StringName] = [&"PrimaryGripAnchor", &"SupportGripAnchor"]
	var two_hand: StringName = StringName(state.get("two_hand_state", ""))
	for anchor_index: int in names.size():
		var path_index: int = paths.find(names[anchor_index])
		if path_index < 0: path_index = paths.find(String(names[anchor_index]))
		var current_bounds: Dictionary = presenter.live_pose_presenter.get_held_item_hand_end_bounds(_weapon, slots[anchor_index])
		var prospective_bounds: Dictionary = SeatResolverScript.resolve_hand_end_bounds(saved_length, float(hand_spans.get(slots[anchor_index], 0.0)))
		var row: Dictionary = {
			"path": String(names[anchor_index]), "slot": String(slots[anchor_index]),
			"required": anchor_index == 0 or two_hand == CombatAnimationMotionNode.TWO_HAND_STATE_TWO_HAND
				or (two_hand == CombatAnimationMotionNode.TWO_HAND_STATE_AUTO and presenter.active_default_two_hand),
			"current_bounds": current_bounds, "prospective_saved_basis_bounds": prospective_bounds,
			"anchor_found": path_index >= 0 and path_index < positions.size(),
		}
		if path_index >= 0 and path_index < positions.size() and positions[path_index] is Vector3 and span.length_squared() > 0.000000000001:
			var position: Vector3 = positions[path_index]
			var ratio: float = (position - start).dot(span) / span.length_squared()
			row["saved_anchor_weapon_local"] = position
			row["saved_anchor_axis_ratio"] = ratio
			row["inside_current_bounds"] = bool(current_bounds.get("valid", false)) and ratio >= float(current_bounds.get("min_ratio", 0.0)) - 0.000001 and ratio <= float(current_bounds.get("max_ratio", 1.0)) + 0.000001
			row["inside_prospective_saved_basis_bounds"] = bool(prospective_bounds.get("valid", false)) and ratio >= float(prospective_bounds.get("min_ratio", 0.0)) - 0.000001 and ratio <= float(prospective_bounds.get("max_ratio", 1.0)) + 0.000001
		result.anchors.append(row)
	return result

func _compare_terminal_source(actual: CombatAnimationChainPlayer, expected: CombatAnimationChainPlayer) -> Dictionary:
	var matches := actual.current_solved_upper_body_bone_names == expected.current_solved_upper_body_bone_names
	matches = matches and actual.current_solved_anchor_node_paths == expected.current_solved_anchor_node_paths
	var max_error := 0.0
	for field: String in ["current_solved_upper_body_pose_positions", "current_solved_upper_body_pose_scales", "current_solved_anchor_positions_weapon_local", "current_solved_anchor_scales_weapon_local"]:
		var left: Array = actual.get(field)
		var right: Array = expected.get(field)
		if left.size() != right.size():
			matches = false
			continue
		for index: int in left.size(): max_error = maxf(max_error, left[index].distance_to(right[index]))
	var max_rotation := actual.current_solved_weapon_rotation_reference_local.angle_to(expected.current_solved_weapon_rotation_reference_local)
	for field: String in ["current_solved_upper_body_pose_rotations", "current_solved_anchor_rotations_weapon_local"]:
		var left: Array = actual.get(field)
		var right: Array = expected.get(field)
		if left.size() != right.size():
			matches = false
			continue
		for index: int in left.size(): max_rotation = maxf(max_rotation, left[index].angle_to(right[index]))
	max_error = maxf(max_error, actual.current_solved_weapon_position_reference_local.distance_to(expected.current_solved_weapon_position_reference_local))
	max_error = maxf(max_error, actual.current_solved_weapon_scale_reference_local.distance_to(expected.current_solved_weapon_scale_reference_local))
	return {"ok": matches and max_error <= POSITION_EPSILON and max_rotation <= ROTATION_EPSILON,
		"max_position_or_scale_error": max_error, "max_rotation_error_rad": max_rotation}

func _finish(success: bool, reason: String) -> void:
	var unchanged := not _source_hash.is_empty() and FileAccess.get_sha256(_source) == _source_hash
	_report.merge({
		"complete": true, "ok": success and unchanged, "reason": reason,
		"source_unchanged": unchanged, "persistence": "In-memory state overrides; report only.",
		"suppressed_state_writes": {"equipment": _equipment.suppressed_writes, "slots": _slots.suppressed_writes, "library": _library.suppressed_writes},
	}, true)
	if not _output.is_empty() and _output.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(_output.get_base_dir())
		var file := FileAccess.open(_output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_report, "\t"))
			file.close()
		else:
			_report["ok"] = false
			push_error("Could not write equipped playback report: " + _output)
	print("PROFILED_EQUIPPED_PLAYBACK ok=%s reason=%s report=%s" % [_report.ok, reason, _output])
	quit(0 if bool(_report.ok) else 1)
