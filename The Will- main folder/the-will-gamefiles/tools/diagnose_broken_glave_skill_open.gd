extends SceneTree

## Read-only cold opening diagnostic. Run rendered, in a fresh process.
## Synchronous opening calls cannot be interrupted by a SceneTree timer: each
## stage is flushed before entering them so an external watchdog can stop it.
## This tool does not press F, save, reset, create, or manipulate a skill.

const SOURCE_LIBRARY := "user://forge/player_wip_library_state.tres"
const TARGET_NAME := "Broken_Glave_v1"
const TARGET_ID := &"player_wip_1794179018.538_16"
const SLOT_ID := &"skill_slot_1"
const UI_SCENE := "res://scenes/ui/combat_animation_station_ui.tscn"
const DEFAULT_DIRECTORY := "C:/WORKSPACE/godot_runs/broken_glave_skill_open"
const POST_OPEN_WAIT_MSEC := 20000

class FakePlayer:

	extends Node

	var forge_wip_library_state: Resource
	var ui_mode_enabled := false

	func get_forge_wip_library_state() -> Resource:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

class TracedEquippedItemPresenter:

	extends "res://runtime/player/player_equipped_item_presenter.gd"

	var diagnostic_event: Callable

	func _append_visual_mesh_proxy_samples(samples: Array[Vector3], visual_mesh: ArrayMesh, grip_center_local: Vector3, grip_center_origin_id: StringName, cell_world_size: float, clearance_offset_meters: float) -> int:
		diagnostic_event.call("before_equipped_append_visual_mesh_proxy_samples", {"existing_sample_count": samples.size(), "surface_count": visual_mesh.get_surface_count() if visual_mesh != null else 0})
		var started := Time.get_ticks_usec()
		var result := super._append_visual_mesh_proxy_samples(samples, visual_mesh, grip_center_local, grip_center_origin_id, cell_world_size, clearance_offset_meters)
		diagnostic_event.call("after_equipped_append_visual_mesh_proxy_samples", {"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0, "added_sample_count": result, "total_sample_count": samples.size()})
		return result

class TracedPresenter:

	extends "res://runtime/combat/combat_animation_station_preview_presenter.gd"

	var diagnostic_event: Callable

	func _refresh_actor_and_weapon(state: Dictionary, active_wip: CraftedItemWIP, selected_motion_node: CombatAnimationMotionNode, active_draft: Resource = null) -> void:
		diagnostic_event.call("before_presenter_refresh_actor_and_weapon", {})
		var started := Time.get_ticks_usec()
		super._refresh_actor_and_weapon(state, active_wip, selected_motion_node, active_draft)
		diagnostic_event.call("after_presenter_refresh_actor_and_weapon", {"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0})

	func _build_weapon_preview_node(preview_root: Node3D, actor: Node3D, active_wip: CraftedItemWIP) -> Node3D:
		diagnostic_event.call("before_presenter_build_weapon_preview_node", {})
		var started := Time.get_ticks_usec()
		var result := super._build_weapon_preview_node(preview_root, actor, active_wip)
		diagnostic_event.call("after_presenter_build_weapon_preview_node", {"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0, "built": result != null})
		return result

class TracedUI:

	extends "res://runtime/combat/combat_animation_station_ui.gd"

	var diagnostic_event: Callable

	func _begin(name: String, details: Dictionary = {}) -> int:
		if diagnostic_event.is_valid():
			diagnostic_event.call("before_ui_" + name, details)
		return Time.get_ticks_usec()

	func _end(name: String, started: int) -> void:
		if diagnostic_event.is_valid():
			diagnostic_event.call("after_ui_" + name, {"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0})

	func capture_selected_prepared_pose(allow_preparation: bool = false, allow_quality_warnings: bool = false) -> Dictionary:
		var started := _begin("capture_selected_prepared_pose")
		var result := super.capture_selected_prepared_pose(allow_preparation, allow_quality_warnings)
		_end("capture_selected_prepared_pose", started)
		return result

	func _set_workflow_step(step_id: StringName, status_message: String = "") -> void:
		var started := _begin("set_workflow_step", {"step_id": step_id})
		super._set_workflow_step(step_id, status_message)
		_end("set_workflow_step", started)

	func _refresh_all(status_message: String = "", preview_grip_resolve_reason: StringName = StringName()) -> void:
		var started := _begin("refresh_all", {"status_message": status_message, "grip_reason": preview_grip_resolve_reason})
		super._refresh_all(status_message, preview_grip_resolve_reason)
		_end("refresh_all", started)

	func _refresh_preview_scene(grip_resolve_reason: StringName = StringName()) -> void:
		var started := _begin("refresh_preview_scene", {"grip_reason": grip_resolve_reason})
		super._refresh_preview_scene(grip_resolve_reason)
		_end("refresh_preview_scene", started)

	func _refresh_preview_scene_prepared(grip_resolve_reason: StringName) -> void:
		var started := _begin("refresh_preview_scene_prepared", {"grip_reason": grip_resolve_reason})
		super._refresh_preview_scene_prepared(grip_resolve_reason)
		_end("refresh_preview_scene_prepared", started)

	func _reset_active_draft_to_baseline(source: String) -> bool:
		var started := _begin("reset_active_draft_to_baseline", {"source": source})
		var result := super._reset_active_draft_to_baseline(source)
		_end("reset_active_draft_to_baseline", started)
		return result

var _log: FileAccess
var _directory := DEFAULT_DIRECTORY
var _source_path := ""
var _source_hash := ""
var _started_usec: int
var _stage := "startup"
var _last_frame_usec := 0
var _max_frame_gap_ms := 0.0
var _frame_count := 0
var _ui: CanvasLayer
var _player: Node
var _report: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_started_usec = Time.get_ticks_usec()
	var override := OS.get_environment("THE_WILL_GLAVE_OPEN_DIRECTORY")
	if not override.is_empty():
		_directory = override
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		push_error("Cannot create diagnostic output directory: " + _directory)
		quit(1)
		return
	_log = FileAccess.open(_directory.path_join("stages.jsonl"), FileAccess.WRITE)
	if _log == null:
		push_error("Cannot open diagnostic stage log")
		quit(1)
		return
	process_frame.connect(_on_process_frame)
	_source_path = ProjectSettings.globalize_path(SOURCE_LIBRARY)
	_record("before_library_hash", {"source_path": _source_path})
	_source_hash = FileAccess.get_sha256(_source_path)
	_record("after_library_hash", {"source_sha256_before": _source_hash})
	if _source_hash.is_empty():
		await _finish("source_library_missing", false)
		return
	_report = {"source_path": _source_path, "source_sha256_before": _source_hash,
		"target_name": TARGET_NAME, "target_id": TARGET_ID, "skill_slot": SLOT_ID,
		"post_open_wait_cap_ms": POST_OPEN_WAIT_MSEC, "verification_skip_persistence": true,
		"scope": "Actual opening only; no F, Save, Reset, manipulation, or isolated weapon recreation."}
	_record("before_library_load")
	var started := Time.get_ticks_usec()
	var library := ResourceLoader.load(SOURCE_LIBRARY, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_record("after_library_load", {"elapsed_ms": _elapsed_ms(started), "loaded": library != null})
	if library == null:
		await _finish("library_load_failed", false)
		return
	var selected: Resource = library.call("get_saved_wip", TARGET_ID)
	if selected == null or String(selected.get("forge_project_name")) != TARGET_NAME:
		await _finish("exact_target_not_found", false)
		return
	# open_for's legacy migration writes directly, outside the UI's test guard.
	# Refuse that branch rather than silently rewriting the actual source file.
	var station_script := load("res://core/models/combat_animation_station_state.gd") as Script
	var schema := int(station_script.get_script_constant_map().get("SKILL_BASELINE_SCHEMA_VERSION", -1))
	var legacy: Array = []
	for item: Resource in library.call("get_saved_wips"):
		if item == null:
			continue
		var station: Resource = item.get("combat_animation_station_state")
		if station == null or int(station.get("station_version")) < schema:
			legacy.append({"wip_id": item.get("wip_id"), "station_version": station.get("station_version") if station != null else -1})
	_record("persistence_preflight", {"required_schema": schema, "legacy_stations": legacy})
	if schema < 0 or not legacy.is_empty():
		await _finish("legacy_migration_would_persist_real_library", false)
		return
	_report["saved_geometry"] = _geometry_counts(selected)
	_report["saved_skill"] = _saved_skill_summary(selected)
	_record("saved_source_summary", {"geometry": _report.saved_geometry, "skill": _report.saved_skill})
	_record("before_fake_player_create")
	var player := FakePlayer.new()
	_player = player
	player.forge_wip_library_state = library
	root.add_child(player)
	_record("after_fake_player_create")
	_record("before_ui_scene_load")
	started = Time.get_ticks_usec()
	var scene := load(UI_SCENE) as PackedScene
	_record("after_ui_scene_load", {"elapsed_ms": _elapsed_ms(started), "loaded": scene != null})
	if scene == null:
		await _finish("ui_scene_load_failed", false)
		return
	_record("before_ui_instantiate")
	started = Time.get_ticks_usec()
	_ui = scene.instantiate() as CanvasLayer
	_ui.set_script(TracedUI)
	_ui.set("diagnostic_event", Callable(self, "_record"))
	var traced_presenter := TracedPresenter.new()
	traced_presenter.diagnostic_event = Callable(self, "_record")
	var traced_equipped := TracedEquippedItemPresenter.new()
	traced_equipped.diagnostic_event = Callable(self, "_record")
	traced_presenter.equipped_item_presenter = traced_equipped
	_ui.set("preview_presenter", traced_presenter)
	_ui.set_meta("verification_skip_persistence", true)
	_ui.set_meta("trace_open_latency", true)
	var presenter: RefCounted = _ui.get("preview_presenter")
	presenter.set_meta("trace_preview_latency", true)
	_record("after_ui_instantiate", {"elapsed_ms": _elapsed_ms(started)})
	_record("before_ui_add_child")
	started = Time.get_ticks_usec()
	root.add_child(_ui)
	_record("after_ui_add_child", {"elapsed_ms": _elapsed_ms(started)})
	for _frame: int in 3:
		await process_frame
	_record("before_open_for")
	started = Time.get_ticks_usec()
	_ui.call("open_for", player, "Broken Glave Skill 1 Opening Diagnostic")
	_record("after_open_for", {"elapsed_ms": _elapsed_ms(started), "traces": _latency_traces()})
	await process_frame
	_record("before_weapon_open")
	started = Time.get_ticks_usec()
	var opened := bool(_ui.call("open_saved_wip_with_hand_setup", TARGET_ID, &"hand_right", false, true))
	_report["weapon_open_ms"] = _elapsed_ms(started)
	_record("after_weapon_open", {"elapsed_ms": _report.weapon_open_ms, "opened": opened, "traces": _latency_traces()})
	if not opened:
		await _finish("weapon_open_failed", false)
		return
	await process_frame
	_record("before_slot_select")
	started = Time.get_ticks_usec()
	var selected_ok := bool(_ui.call("select_skill_slot", SLOT_ID, true))
	_report["slot_select_ms"] = _elapsed_ms(started)
	_record("after_slot_select", {"elapsed_ms": _report.slot_select_ms, "selected": selected_ok, "traces": _latency_traces()})
	if not selected_ok:
		await _finish("slot_select_failed", false)
		return
	var wait_started := Time.get_ticks_msec()
	var next_sample := wait_started
	var readiness: Dictionary = {}
	_record("post_open_observation_start")
	while Time.get_ticks_msec() - wait_started < POST_OPEN_WAIT_MSEC:
		await process_frame
		var now := Time.get_ticks_msec()
		if now < next_sample:
			continue
		readiness = _read_grip_status()
		readiness["wait_ms"] = now - wait_started
		_record("post_open_observation", readiness)
		next_sample = now + 1000
		if bool(readiness.get("live_binding_ready", false)) and now - wait_started >= 2000:
			break
	_report["final_grip_observation"] = readiness
	_report["post_open_observed_ms"] = Time.get_ticks_msec() - wait_started
	_report["post_open_wait_expired"] = not bool(readiness.get("live_binding_ready", false))
	_report["latency_traces"] = _latency_traces()
	await _finish("opening_observation_complete", true)

func _on_process_frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_usec > 0:
		var gap := float(now - _last_frame_usec) / 1000.0
		_max_frame_gap_ms = maxf(_max_frame_gap_ms, gap)
		if gap > 250.0:
			_record("frame_gap", {"gap_ms": gap, "preceding_stage": _stage}, false)
	_last_frame_usec = now
	_frame_count += 1

func _record(stage: String, details: Dictionary = {}, change_stage: bool = true) -> void:
	if change_stage:
		_stage = stage
	var entry := {"stage": stage, "timestamp": Time.get_datetime_string_from_system(),
		"since_start_ms": _elapsed_ms(_started_usec), "frame_count": _frame_count}
	entry.merge(details, true)
	_log.store_line(JSON.stringify(entry))
	_log.flush()
	print("GLAVE_OPEN ", JSON.stringify(entry))

func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0

func _latency_traces() -> Dictionary:
	if not is_instance_valid(_ui):
		return {}
	var presenter: RefCounted = _ui.get("preview_presenter")
	return {"open": _ui.get_meta("last_open_latency_trace", []),
		"sync_preview_pose": presenter.get_meta("last_sync_preview_pose_latency_trace", [])}

func _read_grip_status() -> Dictionary:
	var viewport: SubViewport = _ui.get("preview_subviewport")
	var preview_root: Node3D = viewport.get_node_or_null("CombatAnimationPreviewRoot3D")
	if preview_root == null:
		return {"live_binding_ready": false, "reason": "preview_root_missing"}
	var actor: Node3D = preview_root.get_node_or_null("PreviewActorPivot/PreviewActor")
	var weapon: Node3D = preview_root.get_meta("preview_held_item", null)
	if actor == null or weapon == null:
		return {"live_binding_ready": false, "reason": "actor_or_weapon_missing"}
	var motion: Resource = _ui.call("_get_active_motion_node")
	var dominant := StringName(_ui.get("active_preview_dominant_slot_id"))
	if motion != null and StringName(motion.get("primary_hand_slot")) in [&"hand_left", &"hand_right"]:
		dominant = StringName(motion.get("primary_hand_slot"))
	var slots: Array[StringName] = [dominant]
	if motion != null and (StringName(motion.get("two_hand_state")) == &"two_hand_two_hand" or bool((motion.get("prepared_pose") as Dictionary).get("support_enabled", false))):
		slots.append(&"hand_left" if dominant == &"hand_right" else &"hand_right")
	var slot_states := {}
	var binding_owner: RefCounted = actor.get("planar_grip_pose_binding")
	var has_binding := true
	for slot: StringName in slots:
		var pose: Dictionary = actor.call("get_planar_grip_pose_state", slot)
		var binding: Dictionary = binding_owner.call("relationship", slot, weapon)
		var good := bool(pose.get("has_grip_pose", false)) and binding.get("hand_in_weapon") is Transform3D
		has_binding = has_binding and good
		slot_states[String(slot)] = {"has_grip_pose": pose.get("has_grip_pose", false),
			"has_hand_in_weapon_transform": binding.get("hand_in_weapon") is Transform3D}
	var presenter: RefCounted = _ui.get("preview_presenter")
	var pending := bool(presenter.call("is_grip_acquisition_pending", viewport))
	var statuses: Dictionary = presenter.call("get_grip_acquisition_status", viewport)
	var footer: Label = _ui.get("footer_status_label")
	return {"live_binding_ready": has_binding and not pending, "acquisition_pending": pending,
		"readiness_meaning": "Live pose and hand/weapon binding, no queued acquisition; not a full-hand anatomical certificate.",
		"slots": slot_states, "acquisition_status": statuses,
		"footer": footer.text if footer != null else "",
		"prepared_pose_restore": preview_root.get_meta("prepared_authoring_pose_restore", {})}

func _geometry_counts(wip: Resource) -> Dictionary:
	var stage2: Resource = wip.get("stage2_item_state")
	if stage2 == null:
		return {"stage2_missing": true}
	var output := {}
	for field: String in ["baseline_editable_mesh_state", "current_editable_mesh_state", "primary_grip_handle_mesh_state"]:
		var mesh_state: Resource = stage2.get(field)
		output[field] = {"vertices": mesh_state.call("get_vertex_count"), "triangles": mesh_state.call("get_triangle_count")} if mesh_state != null else {}
	var wrapper: Resource = stage2.get("primary_grip_target_wrapper")
	var wrapper_counts := {}
	if wrapper != null:
		for prefix: String in ["source_handle", "target", "palm_target", "non_thumb_s1_target"]:
			var vertices: PackedVector3Array = wrapper.get(prefix + "_vertices_m")
			var indices: PackedInt32Array = wrapper.get(prefix + "_indices")
			wrapper_counts[prefix] = {"vertices": vertices.size(), "triangles": indices.size() / 3}
		wrapper_counts["schema_version"] = wrapper.get("schema_version")
		wrapper_counts["construction_revision"] = wrapper.get("construction_revision")
	output["grip_wrapper"] = wrapper_counts
	return output

func _saved_skill_summary(wip: Resource) -> Dictionary:
	var station: Resource = wip.get("combat_animation_station_state")
	if station == null:
		return {"station_missing": true}
	for draft: Resource in station.get("skill_drafts"):
		if draft == null or not (StringName(draft.get("legal_slot_id")) == SLOT_ID or StringName(draft.get("owning_skill_id")) == SLOT_ID):
			continue
		var nodes: Array = draft.get("motion_node_chain")
		var prepared := 0
		for motion: Resource in nodes:
			if motion != null and not (motion.get("prepared_pose") as Dictionary).is_empty():
				prepared += 1
		return {"present": true, "node_count": nodes.size(), "prepared_node_count": prepared,
			"selected_node_index": draft.get("selected_motion_node_index"),
			"authoring_pose_initialized": draft.get("authoring_pose_initialized"),
			"has_runtime_clip": draft.get("baked_runtime_clip") != null}
	return {"present": false}

func _finish(reason: String, workflow_completed: bool) -> void:
	_record("before_cleanup", {"reason": reason})
	_report["reason"] = reason
	_report["workflow_completed"] = workflow_completed
	_report["max_process_frame_gap_ms"] = _max_frame_gap_ms
	_report["process_frame_count"] = _frame_count
	_report["total_before_cleanup_ms"] = _elapsed_ms(_started_usec)
	_report["source_sha256_before_cleanup"] = FileAccess.get_sha256(_source_path)
	if is_instance_valid(_ui):
		_record("before_close_ui")
		_ui.call("close_ui")
		_record("after_close_ui")
		_ui.queue_free()
	if is_instance_valid(_player):
		_player.queue_free()
	await process_frame
	_report["source_sha256_after"] = FileAccess.get_sha256(_source_path)
	_report["library_file_unchanged"] = not _source_hash.is_empty() and _source_hash == String(_report.source_sha256_after)
	var report_file := FileAccess.open(_directory.path_join("report.json"), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(_report, "\t"))
		report_file.flush()
	_record("complete", _report)
	_log.close()
	quit(0 if workflow_completed and bool(_report.library_file_unchanged) else 1)
