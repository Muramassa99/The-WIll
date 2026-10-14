extends SceneTree

## Cache/ownership proof only. Real geometry, save and playback are exercised
## separately by verify_surface_grip_save_playback.gd.
const UI = preload("res://runtime/combat/combat_animation_station_ui.gd")
const Draft = preload("res://core/models/combat_animation_draft.gd")
const Motion = preload("res://core/models/combat_animation_motion_node.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const Wip = preload("res://core/models/crafted_item_wip.gd")
const Station = preload("res://core/models/combat_animation_station_state.gd")
const Equipped = preload("res://runtime/player/player_equipped_skill_slot_presenter.gd")
const Fingers = preload("res://runtime/player/player_rig_finger_grip_presenter.gd")
const Solver = preload("res://runtime/player/grip/surface_driven_grip_solver.gd")

class FixtureUI extends UI:
	var station := Station.new()
	# Geometry is exercised by the real saved-weapon proof. This fixture controls
	# that dependency to verify cache ownership and rejection of invalid end bounds.
	var handle_end_bounds_valid := true
	func _get_active_station_state() -> Resource: return station
	func _get_active_weapon_total_length() -> float: return 0.2
	func _resolve_preview_trajectory_volume_config() -> Dictionary: return {}
	func _runtime_clip_respects_handle_ends(_clip: Resource) -> bool: return handle_end_bounds_valid

class UnavailableBake extends RefCounted:
	func bake_runtime_clip_upper_body_pose_track(_a, _b, _c, _d, _e, _f) -> Dictionary:
		return {"baked": false, "reason": "grip_acquisition_pending"}

var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _clip() -> Resource:
	var clip := Clip.new()
	clip.baked_frame_times = PackedFloat32Array([0.0])
	clip.solved_replay_track_source = Clip.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK
	clip.solved_replay_reference_bone_name = &"fixture"
	clip.baked_solved_upper_body_bone_names.assign([&"fixture"])
	clip.baked_solved_replay_frame_available.assign([true])
	clip.baked_solved_upper_body_pose_positions.assign([PackedVector3Array([Vector3.ZERO])])
	clip.baked_solved_upper_body_pose_rotations.assign([PackedVector4Array([Vector4(0, 0, 0, 1)])])
	clip.baked_solved_upper_body_pose_scales.assign([PackedVector3Array([Vector3.ONE])])
	clip.baked_solved_weapon_positions_reference_local = PackedVector3Array([Vector3.ZERO])
	clip.baked_solved_weapon_rotations_reference_local = PackedVector4Array([Vector4(0, 0, 0, 1)])
	clip.baked_solved_weapon_scales_reference_local = PackedVector3Array([Vector3.ONE])
	clip.baked_solved_anchor_positions_weapon_local.assign([PackedVector3Array()])
	clip.baked_solved_anchor_rotations_weapon_local.assign([PackedVector4Array()])
	clip.baked_solved_anchor_scales_weapon_local.assign([PackedVector3Array()])
	return clip

func _run() -> void:
	var ui := FixtureUI.new()
	ui.active_wip = Wip.new()
	ui.active_wip.wip_id = &"cache_fixture"
	ui.preview_presenter = UnavailableBake.new()
	var skill := Draft.new()
	skill.draft_kind = Draft.DRAFT_KIND_SKILL
	skill.motion_node_chain.assign([Motion.new()])
	skill.baked_runtime_clip = _clip()
	skill.runtime_cache_signature = ui._build_runtime_clip_cache_signature(skill)
	_check(skill.runtime_cache_signature.split("|")[1] == String(Solver.REVISION), "cache signature binds the current solver revision")
	var idle := Draft.new()
	idle.draft_kind = Draft.DRAFT_KIND_IDLE
	idle.context_id = Draft.IDLE_CONTEXT_COMBAT
	idle.motion_node_chain.assign([Motion.new()])
	ui.station.idle_drafts.assign([idle])
	_check(ui._get_existing_combat_idle_draft() == idle, "existing authored idle is reused without replacing its pose")
	_check(ui._active_draft_requires_manual_save(skill), "a ready skill with an uncached combat idle still requires Save")
	idle.baked_runtime_clip = _clip()
	idle.runtime_cache_signature = ui._build_runtime_clip_cache_signature(idle)
	_check(not ui._active_draft_requires_manual_save(skill), "current skill and idle together permit cached playback")
	ui.handle_end_bounds_valid = false
	_check(ui._active_draft_requires_manual_save(skill), "current cache still requires Save when Handle end bounds reject it")
	ui.handle_end_bounds_valid = true
	skill.runtime_cache_signature = "obsolete"
	var failed: Dictionary = ui._refresh_runtime_clip_cache_for_draft(skill)
	_check(not failed.cached and failed.reason == "grip_acquisition_pending", "pending acquisition reports an unavailable bake")
	_check(skill.baked_runtime_clip == null and skill.runtime_cache_signature.is_empty(), "failed refresh clears stale derived pose and signature")
	var equipped := Equipped.new()
	ui.active_wip.stage2_item_state = Resource.new()
	for suffix: String in ["", "_older", "_future"]:
		skill.runtime_cache_signature = "runtime_cache_v9_grip_transition_motion|%s%s|fixture" % [Solver.REVISION, suffix]
		var result := {"success": true, "baked_runtime_clip": _clip()}
		equipped._validate_prepared_grip_replay(result, ui.active_wip, skill)
		_check(bool(result.success) == suffix.is_empty(), "runtime revision comparison is exact: " + suffix)
		_check(result.get("grip_replay_ready", false) == suffix.is_empty(), "runtime readiness reports revision mismatch: " + suffix)
		if not suffix.is_empty(): _check(result.baked_runtime_clip == null, "obsolete clip is not exposed to playback")
	skill.runtime_cache_signature = "runtime_cache_v8_committed_surface_grip|%s|fixture" % Solver.REVISION
	var old_schema := {"success": true, "baked_runtime_clip": _clip()}
	equipped._validate_prepared_grip_replay(old_schema, ui.active_wip, skill)
	_check(not old_schema.success and old_schema.baked_runtime_clip == null, "old bake schema is rejected even with the current solver revision")
	var fingers := Fingers.new()
	var weapon := Node3D.new()
	var guide := Node3D.new()
	weapon.add_child(guide)
	_check(not fingers._uses_prepared_weapon(guide), "legacy weapons retain their existing owner")
	weapon.set_meta("saved_wrapper_grip_source", {"valid": false})
	_check(fingers._uses_prepared_weapon(guide), "invalid prepared input cannot fall back to the obsolete solver")
	weapon.set_meta("saved_wrapper_grip_source", {"valid": true})
	_check(fingers._uses_prepared_weapon(guide), "valid prepared weapons use the same closure owner outside the editor")
	weapon.free()
	ui.free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
