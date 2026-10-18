extends SceneTree

const State = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const Body = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const Resolver = preload("res://runtime/forge_v2/forge_v2_material_volume_resolver.gd")
const REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_retained_edit_state_20261018.json"

var checks: Array[Dictionary] = []
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Resource = State.new()
	state.call("reset_new_draft", "Retained edit state verification")
	var ids: Array[StringName] = []
	ids.append(_append_spline(state, 0.0))
	ids.append(_append_spline(state, 0.01))
	state.call("set_active_tool_id", State.TOOL_VOLUME_STROKE)
	var freehand: Resource = state.call("append_point_material_body", Vector3(0.07, 0.0, 0.0), 0.0125, 1.0, Vector3.UP)
	if freehand != null:
		ids.append(StringName(freehand.get("body_id")))
	_check(state.call("commit_pending_material_bodies_as_layer") != null, "Freehand consumes an ordinary retained slot")
	ids.append(_append_spline(state, 0.02))
	ids.append(_append_spline(state, 0.03, true))
	if ids.size() != 5 or ids.has(StringName()):
		_finish()
		return
	var entries: Array = state.call("get_retained_spline_editable_entries")
	_check(entries.size() == 4, "Only four spline operations are editable across five shared slots")
	_check(not bool(state.call("is_retained_spline_body_editable", ids[2])), "Freehand cannot be reopened as a spline")
	_check(StringName((entries[0] as Dictionary).get("body_id")) == ids[4], "Newest eligible spline comes first")
	_check(int((entries[3] as Dictionary).get("age_index")) == 4, "Age counts noneditable freehand slots")
	_verify_cancel(state, ids[1])
	_verify_replace(state, ids[1])
	_verify_saved_profile(state, ids[4])
	_verify_stale(state, ids[0])
	_verify_redo_and_branch(state, ids[1])
	_verify_checkpoint(state)
	_verify_saved_profile_resume()
	_finish()

func _append_spline(state: Resource, y: float, saved_profile: bool = false) -> StringName:
	state.call("set_active_tool_id", State.TOOL_SPLINE_LINE)
	state.call("set_active_primitive_id", State.DEFAULT_ACTIVE_PRIMITIVE_ID)
	state.call("set_brush_radius_meters", 0.0125)
	if saved_profile:
		_check(bool(state.call("select_active_saved_basic_profile", _profile())), "Saved profile fixture selected")
	for point: Vector3 in [Vector3(0.0, y, 0.0), Vector3(0.04, y + 0.005, 0.0), Vector3(0.08, y, 0.0)]:
		state.call("append_spline_line_point", point, Vector3.UP)
	_check(bool(state.call("generate_spline_line_csg_noodle")), "Spline fixture generates")
	var body_id := StringName(state.get("selected_material_body_id"))
	_check(state.call("commit_pending_material_bodies_as_layer") != null, "Spline fixture commits in bounded history")
	return body_id

func _profile() -> Dictionary:
	var polygon := PackedVector2Array([
		Vector2(-0.012, -0.009), Vector2(0.012, -0.009),
		Vector2(0.012, 0.009), Vector2(-0.012, 0.009),
	])
	return {
		"profile_id": &"retained_source_profile", "id": &"retained_source_profile",
		"label": "Retained source profile", "family": Profiles.PROFILE_FAMILY_BASIC,
		"control_points_2d_meters": polygon, "base_polygon_2d_meters": polygon,
		"polygon_2d_meters": polygon, "base_anchor_2d_meters": Vector2(0.002, 0.001),
		"anchor_x_meters": 0.002, "anchor_y_meters": 0.001, "rotation_degrees": 19.0,
	}

func _body(state: Resource, body_id: StringName) -> Resource:
	return state.call("_find_material_body_by_id", body_id) as Resource

func _verify_cancel(state: Resource, body_id: StringName) -> void:
	state.call("set_active_tool_id", State.TOOL_DETAILING_BRUSH)
	var before: Dictionary = state.call("capture_editor_transient_snapshot")
	var original := _body(state, body_id)
	var source_points: PackedVector3Array = original.get("path_points")
	var revision := int(state.get("bounded_history_transition_revision"))
	_check(bool((state.call("begin_retained_spline_change", body_id) as Dictionary).get("ok", false)), "Retained spline opens")
	_check(_body(state, body_id) == original, "Entering edit retains the committed original instance")
	state.call("set_spline_line_point", 1, Vector3(0.04, 0.045, 0.0))
	state.call("set_spline_line_point_roll_degrees", 1, 45.0)
	_check(original.get("path_points") == source_points, "Draft edits do not mutate committed path")
	_check(int(state.get("bounded_history_transition_revision")) == revision, "Draft edits do not advance material history")
	_check(bool(state.call("cancel_retained_spline_change")), "Cancel succeeds")
	_check(state.call("capture_editor_transient_snapshot") == before, "Cancel restores exact prior editor/profile context")
	_check(_body(state, body_id) == original, "Cancel never replaces committed body")

func _verify_replace(state: Resource, body_id: StringName) -> void:
	var original := _body(state, body_id)
	var before := original.duplicate(true)
	var layer: Resource = (state.get("forge_layers") as Array)[1]
	var layer_id := StringName(layer.get("layer_id"))
	var order := int(layer.get("order_index"))
	var created := float(layer.get("created_timestamp"))
	var lifetime := int(state.get("bounded_history_lifetime_operation_count"))
	var context: Dictionary = state.call("capture_editor_transient_snapshot")
	state.call("begin_retained_spline_change", body_id)
	state.call("set_spline_line_point", 1, Vector3(0.04, 0.06, 0.0))
	var candidate: Dictionary = state.call("build_retained_spline_change_candidate")
	_check(bool(candidate.get("ok", false)), "Detached replacement candidate builds")
	if not bool(candidate.get("ok", false)):
		state.call("cancel_retained_spline_change")
		return
	_check(_body(state, body_id) == original, "Candidate preparation retains original committed source")
	var staged: Resource = candidate["candidate_state"]
	_check(staged != state, "Candidate uses a separate state")
	_check(staged.get("material_ledger") != state.get("material_ledger"), "Candidate ledger has no live mutable alias")
	_check(staged.get("committed_volume_resolver") != state.get("committed_volume_resolver"), "Candidate occupancy resolver is separate")
	_check(bool(state.call("accept_retained_spline_change_candidate", candidate)), "Prepared candidate installs")
	var after := _body(state, body_id)
	var next_layer: Resource = (state.get("forge_layers") as Array)[1]
	_check(after.get("source_record_id") == before.get("source_record_id"), "Replacement preserves source record identity")
	_check(next_layer.get("layer_id") == layer_id and int(next_layer.get("order_index")) == order, "Replacement preserves layer identity and position")
	_check(is_equal_approx(float(next_layer.get("created_timestamp")), created), "Replacement retains original operation age")
	_check(int(state.get("bounded_history_lifetime_operation_count")) == lifetime, "Replacement does not append a lifetime operation")
	_check(state.call("capture_editor_transient_snapshot") == context, "Successful Apply restores previous editor context")
	_check(not bool(state.call("is_retained_spline_change_active")), "Successful Apply closes detached edit session")
	_check(not bool(state.call("accept_retained_spline_change_candidate", candidate)), "Duplicate completion cannot install twice")
	_verify_accounting(state, "after replacement")
	var undo: Dictionary = state.call("build_retained_spline_replacement_candidate", body_id, before, &"undo")
	_check(bool(undo.get("ok", false)) and bool(state.call("accept_retained_spline_change_candidate", undo)), "Explicit before-source Undo installs without editor session")
	_check(_body(state, body_id).get("path_points") == before.get("path_points"), "Source Undo restores exact path")
	var redo: Dictionary = state.call("build_retained_spline_replacement_candidate", body_id, after, &"redo")
	_check(bool(redo.get("ok", false)) and bool(state.call("accept_retained_spline_change_candidate", redo)), "Explicit after-source Redo installs")
	_verify_accounting(state, "after source Redo")

func _verify_saved_profile(state: Resource, body_id: StringName) -> void:
	var original := _body(state, body_id)
	_check(original.get("shape_kind") == Body.SHAPE_KIND_SPLINE_PROFILE_PATH, "Saved profile has exact supported spline shape kind")
	state.call("begin_retained_spline_change", body_id)
	_check(bool(state.call("is_saved_basic_profile_shape_active")), "Reopened source profile reconstructs valid runtime metadata")
	state.call("set_spline_line_point_roll_degrees", 1, 30.0)
	var preview: Resource = state.call("build_spline_roll_preview_body")
	_check(preview != null and preview.get("profile_polygon_2d_meters") == original.get("profile_polygon_2d_meters"), "Preview uses exact persisted source polygon")
	_check(preview != null and preview.get("profile_anchor_2d_meters") == original.get("profile_anchor_2d_meters"), "Preview uses exact persisted anchor")
	var candidate: Dictionary = state.call("build_retained_spline_change_candidate")
	_check(bool(candidate.get("ok", false)), "Saved-profile point/twist replacement builds")
	if bool(candidate.get("ok", false)):
		_check(bool(state.call("accept_retained_spline_change_candidate", candidate)), "Saved-profile replacement installs")
		_check((_body(state, body_id).get("path_contact_directions") as PackedVector3Array).is_empty(), "Free-space spline gains no artificial surface contact authority")
	else:
		state.call("cancel_retained_spline_change")

func _verify_stale(state: Resource, body_id: StringName) -> void:
	var source := _body(state, body_id).duplicate(true)
	var first: Dictionary = state.call("build_retained_spline_replacement_candidate", body_id, source, &"undo")
	var second: Dictionary = state.call("build_retained_spline_replacement_candidate", body_id, source, &"undo")
	_check(not bool(state.call("is_retained_spline_change_candidate_current", first)), "New candidate invalidates an older queued candidate")
	_check(not bool(state.call("accept_retained_spline_change_candidate", first)), "Stale candidate cannot replace committed state")
	_check(bool(state.call("accept_retained_spline_change_candidate", second)), "Latest matching candidate remains valid")
	var staged: Resource = state.call("create_retained_history_replay_state")
	_check(staged != null, "Held replay clone builds")
	if staged == null:
		return
	staged.call("undo_latest_layer")
	_check((state.get("forge_layers") as Array).size() == 5, "Staged history Undo leaves live timeline untouched")
	var install: Dictionary = state.call("build_retained_history_install_candidate", staged, &"undo_batch")
	_check(bool(install.get("ok", false)), "Held replay produces one install packet")
	_check(bool(state.call("accept_retained_spline_change_candidate", install)), "Held replay installs whole timeline atomically")
	_check((state.get("forge_layers") as Array).size() == 4 and (state.get("undone_forge_layers") as Array).size() == 1, "Installed history retains active and redo timelines")
	state.call("redo_latest_layer")

func _verify_redo_and_branch(state: Resource, body_id: StringName) -> void:
	state.call("undo_latest_layer")
	var source := _body(state, body_id).duplicate(true)
	var points: PackedVector3Array = source.get("path_points")
	points[1] += Vector3(0.0, 0.015, 0.0)
	source.set("path_points", points)
	var replay: Dictionary = state.call("build_retained_spline_replacement_candidate", body_id, source, &"redo")
	_check(bool(replay.get("ok", false)), "History replacement recomputes dormant redo accounting")
	if bool(replay.get("ok", false)):
		state.call("accept_retained_spline_change_candidate", replay)
	_check((state.get("undone_forge_layers") as Array).size() == 1, "History replacement preserves redo cursor")
	state.call("redo_latest_layer")
	_verify_accounting(state, "after dormant redo restored")
	state.call("undo_latest_layer")
	var new_apply: Dictionary = state.call("build_retained_spline_replacement_candidate", body_id, source, &"apply")
	_check(bool(new_apply.get("ok", false)), "Branched Apply candidate builds")
	_check((state.get("undone_forge_layers") as Array).size() == 1, "Preparation does not discard live redo")
	if bool(new_apply.get("ok", false)):
		state.call("accept_retained_spline_change_candidate", new_apply)
	_check((state.get("undone_forge_layers") as Array).is_empty(), "Successful Apply discards abandoned redo")

func _verify_checkpoint(state: Resource) -> void:
	# State-only fixture: advance S0 using the same occupancy journal as native
	# promotion. Native geometry/publication is covered by integration checks.
	var layers: Array[Resource] = state.get("forge_layers")
	var promoted: Resource = layers[0]
	var promoted_bodies: Array = state.call("_get_layer_material_bodies", promoted)
	var checkpoint: Resource = state.get("bounded_history_checkpoint")
	var resolver: RefCounted = state.get("committed_volume_resolver")
	var sample_size := float(resolver.call("get_incremental_sample_cell_size_meters"))
	var delta: Dictionary = resolver.call("build_checkpoint_occupancy_delta", {}, promoted_bodies, sample_size)
	var ledger: Resource = state.get("material_ledger")
	var summary: Dictionary = ledger.call("build_checkpoint_summary_after_layer", {}, promoted)
	var identity: Dictionary = checkpoint.call("build_next_identity_descriptor", 1)
	_check(bool(checkpoint.call("advance_logical_checkpoint_with_occupancy_delta", 1, identity, &"mat_iron_gray", summary, 5, sample_size, delta)), "Fixture promotes one operation into logical checkpoint")
	layers.remove_at(0)
	state.set("forge_layers", layers)
	state.call("_remove_material_bodies_for_layer", promoted)
	state.call("_rebuild_material_ledger")
	var candidate_ids: Array = state.call("get_retained_spline_editable_entries")
	_check(not candidate_ids.is_empty(), "Retained edits remain available after checkpoint promotion")
	if candidate_ids.is_empty():
		return
	var target_id := StringName((candidate_ids[0] as Dictionary)["body_id"])
	var source := _body(state, target_id).duplicate(true)
	var points: PackedVector3Array = source.get("path_points")
	points[1] += Vector3(0.0, 0.008, 0.0)
	source.set("path_points", points)
	var packet_before: Dictionary = checkpoint.call("to_native_packet")
	var candidate: Dictionary = state.call("build_retained_spline_replacement_candidate", target_id, source, &"apply")
	_check(bool(candidate.get("ok", false)), "Replacement seeds resolver from checkpoint plus bounded tail")
	_check(checkpoint.call("to_native_packet") == packet_before, "Preparing replacement does not mutate shared checkpoint")
	if bool(candidate.get("ok", false)):
		_check(bool(state.call("accept_retained_spline_change_candidate", candidate)), "Checkpoint-backed replacement installs")
		_check(int(state.call("get_bounded_history_checkpoint_operation_count")) == 1, "Replacement retains checkpoint operation count")
		var next := _append_spline(state, 0.08)
		_check(next != StringName(), "Ordinary append works after checkpoint-backed replacement")

func _verify_accounting(state: Resource, label: String) -> void:
	var resolver: RefCounted = Resolver.new()
	var active: Array = state.call("_collect_committed_active_user_material_bodies")
	var reference: Dictionary = resolver.call("build_usage_summary", active)
	var actual: Dictionary = state.call("get_material_ledger_summary")
	_check(int(actual.get("total_rough_material_centi_units", -1)) == int(reference.get("total_rough_material_centi_units", -2)), "%s matches independent occupancy total" % label)
	var layer_ids: Array = state.call("_layer_ids", state.get("forge_layers"))
	for layer: Resource in state.get("forge_layers"):
		for entry: Dictionary in (layer.get("ledger_delta") as Dictionary).values():
			for owner: Variant in entry.get("layer_ids", []):
				_check(layer_ids.has(StringName(owner)), "%s uses only stable live ledger owner IDs" % label)

func _verify_saved_profile_resume() -> void:
	var state: Resource = State.new()
	state.call("reset_new_draft", "Previously unsupported saved-profile WIP")
	var source_id := _append_spline(state, 0.0, true)
	state.call("set_active_tool_id", State.TOOL_HANDLES)
	for point: Vector3 in [Vector3(0.0, 0.0, -0.1), Vector3(0.0, 0.06, -0.1), Vector3(0.0, 0.12, -0.1)]:
		state.call("append_spline_line_point", point, Vector3.FORWARD)
	_check(bool(state.call("generate_profile_extrusion_from_spline")), "Protected Handle fixture generates")
	_check(state.call("commit_pending_material_bodies_as_layer") != null, "Protected Handle fixture commits separately")
	var protected_ids: Array = state.call("_layer_ids", state.get("protected_forge_layers"))
	state.set("bounded_history_suspended_reason", &"unsupported_committed_layer")
	var path := "user://diagnostics/retained_edit_saved_profile_resume.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	_check(ResourceSaver.save(state, path) == OK, "Previously unsupported WIP saves")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	_check(loaded != null, "Previously unsupported WIP reloads independently")
	if loaded == null:
		return
	loaded.call("normalize")
	_check(loaded.get("bounded_history_suspended_reason") == State.BOUNDED_HISTORY_SUSPENDED_NONE, "Complete supported bounded saved-profile timeline resumes on load")
	_check(bool(loaded.call("is_retained_spline_body_editable", source_id)), "Reopened saved profile is available to E")
	_check(loaded.call("_layer_ids", loaded.get("protected_forge_layers")) == protected_ids, "Resuming spline support preserves protected Handle owner IDs")
	_check((loaded.get("forge_layers") as Array).size() == 1 and int(loaded.get("bounded_history_lifetime_operation_count")) == 2, "Compatibility retains operation count and tail")
	var candidate: Dictionary = loaded.call("build_retained_spline_replacement_candidate", source_id, _body(loaded, source_id), &"apply")
	_check(bool(candidate.get("ok", false)), "Reloaded resumed WIP can prepare replacement without historical replay")
	for reason: StringName in [&"native_promotion_rejected", &"legacy_unbounded_history", &"invalid_tail_capacity"]:
		var blocked := loaded.duplicate(true)
		blocked.set("bounded_history_suspended_reason", reason)
		blocked.call("normalize")
		_check(blocked.get("bounded_history_suspended_reason") == reason, "Unrelated suspension stays blocked: %s" % reason)
	var recovery_blocked := loaded.duplicate(true)
	recovery_blocked.set("bounded_history_suspended_reason", &"unsupported_operation")
	recovery_blocked.set("bounded_history_recovery_blocked_reason", &"checkpoint_unavailable")
	recovery_blocked.call("normalize")
	_check(recovery_blocked.get("bounded_history_suspended_reason") == &"unsupported_operation", "Recovery-blocked data is not implicitly re-enabled")
	var mixed := loaded.duplicate(true)
	mixed.set("bounded_history_suspended_reason", &"unsupported_operation")
	_body(mixed, source_id).set("material_variant_id", &"mat_wood_brown")
	mixed.call("normalize")
	_check(mixed.get("bounded_history_suspended_reason") == &"unsupported_operation", "Mismatched material source does not resume")
	var missing := loaded.duplicate(true)
	missing.set("bounded_history_suspended_reason", &"unsupported_operation")
	var bodies: Array[Resource] = missing.get("material_bodies")
	bodies.erase(_body(missing, source_id))
	missing.set("material_bodies", bodies)
	missing.call("normalize")
	_check(missing.get("bounded_history_suspended_reason") == &"unsupported_operation", "Incomplete retained source does not resume")
	var over_capacity := loaded.duplicate(true)
	over_capacity.set("bounded_history_suspended_reason", &"unsupported_committed_layer")
	for index in range(5):
		_append_spline(over_capacity, 0.03 + index * 0.01)
	over_capacity.set("_bounded_history_normalized_once", false)
	over_capacity.call("normalize")
	_check((over_capacity.get("forge_layers") as Array).size() == 6, "Old unbounded fixture retains all six sources")
	_check(over_capacity.get("bounded_history_suspended_reason") == &"unsupported_committed_layer", "Over-capacity WIP is not silently truncated or resumed")

func _check(passed: bool, label: String) -> void:
	checks.append({"passed": passed, "label": label})
	if not passed:
		failures += 1
		push_error(label)

func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(REPORT.get_base_dir())
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"ok": failures == 0, "passed": checks.size() - failures, "failed": failures, "checks": checks}, "\t"))
	print("Retained edit state: %d passed, %d failed" % [checks.size() - failures, failures])
	quit(0 if failures == 0 else 1)
