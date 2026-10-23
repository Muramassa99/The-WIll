extends SceneTree

const DraftScript = preload("res://core/models/combat_animation_draft.gd")
const NodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const StationUIScript = preload("res://runtime/combat/combat_animation_station_ui.gd")
const BakerScript = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const ClipScript = preload("res://core/models/combat_runtime_clip.gd")
const RuntimePresenterScript = preload("res://runtime/player/player_runtime_skill_playback_presenter.gd")

var checks: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := "C:/WORKSPACE/godot_runs/skill_transition_20261023/action_boundary"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var ui = StationUIScript.new()
	var draft = DraftScript.new()
	var baseline = _node(0, 0.2, 9.0)
	var first = _node(1, 0.5, 0.2)
	var second = _node(2, 0.5, 0.7)
	draft.motion_node_chain.assign([baseline, first, second])
	var original_signature: String = ui._build_runtime_clip_cache_signature(draft)
	baseline.tip_position_local = Vector3(50, 60, 70)
	baseline.grip_seat_slide_offset = 0.9
	baseline.transition_duration_seconds = 4.0
	_expect(ui._build_runtime_clip_cache_signature(draft) == original_signature, "reset_coordinates_grip_and_duration_do_not_invalidate_action_cache")
	first.tip_position_local += Vector3(0.1, 0, 0)
	_expect(ui._build_runtime_clip_cache_signature(draft) != original_signature, "visible_destination_edit_invalidates_action_cache")
	draft.selected_motion_node_index = 2
	var selection_signature: String = ui._build_runtime_clip_cache_signature(draft)
	draft.selected_motion_node_index = 1
	_expect(ui._build_runtime_clip_cache_signature(draft) == selection_signature, "editor_selection_does_not_invalidate_action_cache")
	var compiled: Dictionary = ui._build_preview_runtime_motion_chain(draft.get_action_motion_node_chain(), {}, false)
	var body: Array = compiled.get("motion_node_chain", [])
	_expect(bool(compiled.get("compiled", false)) and body.size() == 2, "preview_compiles_visible_action_body")
	_expect(body.size() == 2 and body[0].node_id == first.node_id, "body_starts_at_first_visible_destination")
	var baker = BakerScript.new()
	var clip = baker.bake_from_motion_node_chain(body, {"sample_rate_hz": 60.0})
	_expect(clip != null and is_equal_approx(clip.total_duration_seconds, 0.7), "body_duration_excludes_reset_to_first_destination")
	_expect(clip != null and clip.get_frame_count() == 43, "body_uses_sixty_hertz_plus_terminal_frame")
	draft.motion_node_chain.assign([baseline, first])
	var single: Dictionary = ui._build_preview_runtime_motion_chain(draft.get_action_motion_node_chain(), {}, false)
	var single_body: Array = single.get("motion_node_chain", [])
	_expect(bool(single.get("compiled", false)) and single_body.size() == 1, "preview_accepts_one_visible_destination")
	var single_clip = baker.bake_from_motion_node_chain(single_body, {"sample_rate_hz": 60.0})
	_expect(single_clip != null and single_clip.get_frame_count() == 1, "one_destination_retains_exactly_one_body_pose")
	var idle = DraftScript.new()
	idle.draft_kind = DraftScript.DRAFT_KIND_IDLE
	idle.motion_node_chain.assign([_node(0, 0.5, 0.7)])
	var idle_signature: String = ui._build_runtime_clip_cache_signature(idle)
	idle.motion_node_chain[0].tip_position_local += Vector3(0.1, 0, 0)
	_expect(ui._build_runtime_clip_cache_signature(idle) != idle_signature, "idle_first_pose_remains_part_of_cache_identity")
	# A valid lightweight cached pose track isolates provenance validation from
	# full-hand certification. Runtime start still requires its solved replay.
	clip.baked_upper_body_bone_names.assign([&"test_bone"])
	clip.upper_body_pose_track_source = ClipScript.UPPER_BODY_POSE_TRACK_SOURCE_SKILL_CRAFTER_AUTHORED_POSE
	clip.solved_replay_track_source = ClipScript.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK
	for index: int in clip.get_frame_count():
		clip.baked_upper_body_bone_pose_rotations.append(PackedVector4Array([Vector4(0, 0, 0, 1)]))
	var runtime = RuntimePresenterScript.new()
	draft.runtime_cache_signature = ClipScript.RUNTIME_CACHE_VERSION + "|test_revision|action"
	_expect(runtime._resolve_cached_runtime_clip({"source_skill_draft": draft, "baked_runtime_clip": clip}) != null, "current_skill_cache_provenance_is_accepted")
	idle.runtime_cache_signature = ClipScript.RUNTIME_CACHE_VERSION + "|test_revision|idle"
	_expect(runtime._resolve_cached_runtime_clip({"source_idle_draft": idle, "baked_runtime_clip": clip}) != null, "current_idle_cache_provenance_is_accepted")
	draft.runtime_cache_signature = "runtime_cache_v10_explicit_terminal_frame|test_revision|action"
	_expect(runtime._resolve_cached_runtime_clip({"source_skill_draft": draft, "baked_runtime_clip": clip}) == null, "old_reset_prefixed_cache_is_rejected_even_with_current_source_label")
	_expect(runtime._resolve_cached_runtime_clip({"baked_runtime_clip": clip}) == null, "cache_without_owning_draft_is_rejected")
	ui.free()
	var ok: bool = true
	for passed: bool in checks.values():
		ok = ok and passed
	var report := {"ok": ok, "checks": checks, "check_count": checks.size()}
	var output := FileAccess.open(output_dir.path_join("results.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	print("COMBAT_ACTION_BOUNDARY ", JSON.stringify(report))
	quit(0 if ok else 1)

func _node(index: int, seat: float, duration: float):
	var node = NodeScript.new()
	node.node_id = StringName("action_boundary_%d" % index)
	node.node_index = index
	node.tip_position_local = Vector3(0, 0, 0.5)
	node.pommel_position_local = Vector3.ZERO
	node.grip_seat_slide_offset = seat
	node.transition_duration_seconds = duration
	return node

func _expect(passed: bool, label: String) -> void:
	checks[label] = passed
	if not passed:
		print("FAILED: ", label)
