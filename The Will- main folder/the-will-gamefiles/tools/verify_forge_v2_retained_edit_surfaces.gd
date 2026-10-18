extends "res://tools/verify_forge_v2_retained_edit_integration.gd"

const PROFILE_LIBRARY = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const SELECTION = preload("res://runtime/forge_v2/forge_v2_retained_surface_selection.gd")
const SURFACE_REPORT := "C:/WORKSPACE/test_artifacts/forge_retained_edit_surfaces_20261018.json"

func _run() -> void:
	controller = CONTROLLER.new()
	var prefs = PREFS.new()
	prefs.save_file_path = "user://diagnostics/retained_edit_surfaces/preferences.tres"
	controller.editor_settings = prefs
	root.add_child(controller)
	workspace = WORKSPACE.new()
	root.add_child(workspace)
	await process_frame
	workspace.call("bind_stage_controller", controller)
	await process_frame
	presenter = workspace.get("volume_preview_presenter") as Node3D
	state = controller.call("get_active_authoring_state") as Resource
	controller.call("set_active_tool_id", &"tool_spline_line")
	var polygon := PackedVector2Array([Vector2(-0.012, -0.008), Vector2(0.015, -0.008), Vector2(0.015, 0.006), Vector2(-0.012, 0.012)])
	var profile: Dictionary = PROFILE_LIBRARY.compile_basic_profile_runtime_data({
		"id": &"retained_surface_saved_profile", "profile_id": &"retained_surface_saved_profile",
		"family": PROFILE_LIBRARY.PROFILE_FAMILY_BASIC, "label": "Retained asymmetric profile",
		"base_polygon_2d_meters": polygon, "polygon_2d_meters": polygon,
		"base_anchor_2d_meters": Vector2.ZERO, "anchor_x_meters": 0.0, "anchor_y_meters": 0.0,
		"rotation_degrees": 0.0,
	})
	_check(bool(controller.call("select_active_saved_basic_profile", profile)), "select saved asymmetric profile")
	for index in range(7):
		if not await _append_spline(index):
			await _finish_surfaces()
			return
	var entries: Array = state.call("get_retained_spline_editable_entries")
	_check(entries.size() == 5, "saved profile splines retain bounded native tail")
	if entries.size() < 3:
		await _finish_surfaces()
		return
	var body_id := StringName(entries[2].body_id)
	var before_polygon: PackedVector2Array = _body(body_id).profile_polygon_2d_meters.duplicate()
	_check(StringName(_body(body_id).body_kind) == &"body_kind_profile_extrusion", "fixture uses saved-profile extrusion, not capsules")
	_check(_body(body_id).path_contact_directions.is_empty(), "saved free-space spline has no fabricated contact directions")
	await _edit_roundtrip(body_id, 2)
	print("SAVED_PROFILE_CANDIDATE_RESULT ", controller.last_retained_spline_change_result)
	_check(_body(body_id).profile_polygon_2d_meters == before_polygon, "Apply and replay preserve saved polygon")
	presenter.call("set_retained_edit_selection_enabled", true)
	for _frame in range(20):
		await process_frame
		if int(presenter.retained_edit_selection.face_count) > 0:
			break
	var painted: Dictionary = {}
	for owner: Dictionary in presenter.retained_edit_selection.owners:
		painted[StringName(owner.get("body_id", StringName()))] = true
	print("SAVED_PROFILE_SELECTION ", {"faces": presenter.retained_edit_selection.face_count, "owners": painted.keys(), "records": presenter.retained_edit_selection.owner_records.keys()})
	_check(int(presenter.retained_edit_selection.face_count) > 0, "final published profile surface has E map")
	for entry: Dictionary in entries:
		_check(painted.has(StringName(entry.body_id)), "surviving saved profile owner is tinted: %s" % entry.body_id)
	presenter.call("set_retained_edit_selection_enabled", false)
	await _real_candidate_failure(body_id, false)
	await _real_candidate_failure(body_id, true)
	await _native_save_rebind()
	await _queued_candidate_disconnect_rebind()
	_surface_ownership_cases()
	_native_coplanar_ownership_case()
	await _finish_surfaces()

func _real_candidate_failure(body_id: StringName, stale: bool) -> void:
	var provider: Callable = controller.get("_retained_spline_change_provider")
	var previous_backend: Object = presenter.native_static_manifold_backend
	var previous_node: Node3D = presenter.native_static_published_node
	var before_points: PackedVector3Array = _body(body_id).path_points.duplicate()
	var previous_faces: PackedVector3Array = presenter.native_static_active_vertices.duplicate()
	controller.call("begin_retained_spline_change", body_id)
	controller.call("set_spline_line_point", 1, before_points[1] + Vector3(0, 0.01, 0))
	controller.call("set_retained_spline_change_provider", _stale_candidate if stale else _invalid_operand)
	_check(bool(controller.call("apply_retained_spline_change")), "real candidate accepts deferred failure fixture")
	await _settle()
	_check(not bool(controller.last_retained_spline_change_result.get("ok", false)), "stale/invalid candidate rejected")
	_check(presenter.native_static_manifold_backend == previous_backend, "failure retains prior native backend")
	_check(presenter.native_static_published_node == previous_node and is_instance_valid(previous_node), "failure retains prior visible publication")
	_check(presenter.native_static_active_vertices == previous_faces and _body(body_id).path_points == before_points, "failure retains committed geometry/source")
	_check(bool(previous_node.get_meta("forge_v2_material_surface", false)), "failure retains targetable collider metadata")
	controller.call("set_retained_spline_change_provider", provider)
	controller.call("cancel_retained_spline_change")

func _invalid_operand(candidate: Dictionary, completed: Callable) -> bool:
	var bodies: Array = candidate.candidate_tail_bodies
	var body: Resource = bodies[0]
	var invalid_points: PackedVector3Array = body.path_points.duplicate()
	invalid_points[0] = Vector3(NAN, 0, 0)
	body.path_points = invalid_points
	return bool(presenter.call("_provide_retained_spline_change", candidate, completed))

func _stale_candidate(candidate: Dictionary, completed: Callable) -> bool:
	var accepted := bool(presenter.call("_provide_retained_spline_change", candidate, completed))
	candidate.baseline_transition_revision -= 1
	return accepted

func _native_save_rebind() -> void:
	_check(bool(state.call("materialize_bounded_history_checkpoint_for_persistence")), "saved profile checkpoint materializes")
	var path := "user://diagnostics/retained_edit_surfaces/edited_saved_profile.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_check(ResourceSaver.save(state, path) == OK, "saved profile edited WIP persists")
	var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	_check(reloaded != null, "saved profile WIP reloads without cache")
	if reloaded == null:
		return
	reloaded.call("normalize")
	workspace.queue_free()
	controller.queue_free()
	await process_frame
	await process_frame
	controller = CONTROLLER.new()
	var preferences = PREFS.new()
	preferences.save_file_path = "user://diagnostics/retained_edit_surfaces/preferences.tres"
	controller.editor_settings = preferences
	controller.set("active_authoring_state", reloaded)
	root.add_child(controller)
	workspace = WORKSPACE.new()
	root.add_child(workspace)
	await process_frame
	workspace.call("bind_stage_controller", controller)
	presenter = workspace.get("volume_preview_presenter") as Node3D
	state = controller.call("get_active_authoring_state") as Resource
	await _settle()
	_check(_native_ready(), "reloaded saved profiles publish through fresh native backend")
	print("SAVED_PROFILE_REBIND ", presenter.native_static_sync_diagnostics.get("last_failure_reason", ""))
	var entries: Array = state.call("get_retained_spline_editable_entries")
	_check(entries.size() == 5, "reloaded saved profile tail still editable")
	if _native_ready() and entries.size() == 5:
		await _edit_roundtrip(StringName(entries[1].body_id), 1)

func _queued_candidate_disconnect_rebind() -> void:
	var entries: Array = state.call("get_retained_spline_editable_entries")
	if entries.is_empty() or not _native_ready():
		_check(false, "queued disconnect fixture requires native editable source")
		return
	var body_id := StringName(entries[0].body_id)
	var before: PackedVector3Array = _body(body_id).path_points.duplicate()
	_check(bool(controller.call("begin_retained_spline_change", body_id)), "begin queued disconnect edit")
	controller.call("set_spline_line_point", 1, before[1] + Vector3(0, 0.006, 0))
	_check(bool(controller.call("apply_retained_spline_change")) and bool(presenter.retained_edit_candidate_pending), "Apply queues presenter candidate before disconnect")
	_check(bool(presenter.call("clear_stage_controller")), "queued candidate presenter disconnect succeeds")
	_check(not bool(presenter.retained_edit_candidate_pending) and not bool(controller.call("is_retained_spline_change_pending")), "disconnect clears presenter and controller pending flags")
	_check(_body(body_id).path_points == before, "disconnect preserves committed source")
	controller.call("cancel_retained_spline_change")
	presenter.call("bind_stage_controller", controller)
	await _settle()
	_check(_native_ready() and not bool(presenter.retained_edit_candidate_pending), "rebind publishes despite stale queued callback")
	_check(_body(body_id).path_points == before, "stale queued callback cannot publish after rebind")
	_check(bool(controller.call("begin_retained_spline_change", body_id)), "rebound source can begin another edit")
	controller.call("set_spline_line_point", 1, before[1] + Vector3(0, 0.003, 0))
	_check(bool(controller.call("apply_retained_spline_change")), "rebound presenter accepts next candidate")
	await _settle()
	_check(bool(controller.last_retained_spline_change_result.get("ok", false)) and _body(body_id).path_points != before, "next candidate publishes after queued disconnect")
	_check(not bool(presenter.retained_edit_candidate_pending) and _native_ready(), "rebound presenter finishes without pending state")

func _surface_ownership_cases() -> void:
	var selection = SELECTION.new()
	var host := Node3D.new()
	root.add_child(host)
	var left := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)])
	var right := PackedVector3Array([Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)])
	var base := left.duplicate()
	base.append_array(right)
	var hidden := PackedVector3Array([Vector3(0, 0, -1), Vector3(1, 0, -1), Vector3(0, 1, -1)])
	var source_base := _source_bvh(base)
	var source_right := _source_bvh(right)
	var source_hidden := _source_bvh(hidden)
	var sources: Array[Dictionary] = [
		{"body_id": &"freehand", "editable": false, "is_handle": false, "bvh": source_right},
		{"body_id": &"spline", "editable": true, "is_handle": false, "bvh": source_base},
		{"body_id": &"hidden", "editable": true, "is_handle": false, "bvh": source_hidden},
	]
	_check(selection.build(host, base, sources), "coplanar final-surface map builds")
	var first: Dictionary = selection.resolve(Vector3(0.2, 0.2, 2), Vector3.FORWARD)
	var second: Dictionary = selection.resolve(Vector3(0.8, 0.8, 2), Vector3.FORWARD)
	_check(first.get("body_id") == &"spline" and bool(first.get("editable", false)), "coplanar surviving spline remains selectable")
	_check(second.get("body_id") == &"freehand" and not bool(second.get("editable", true)), "newer coincident noneditable surface stays red and blocks picking")
	_check(not selection.materials.has(&"hidden"), "hidden raw operand never produces tint geometry")
	_check(selection.face_count == base.size() / 3, "overlay contains exactly final published triangles")
	selection.hover(&"spline")
	var hover_tint: Color = selection.materials[&"spline"].get_shader_parameter("tint")
	_check(hover_tint.a > 0.8, "hover highlights same selected surface owner")
	selection.clear()
	_check(host.get_child_count() == 0 and selection.final_bvh == null, "E exit removes temporary tint and picking map")
	var microscopic := PackedVector3Array([Vector3(0, 0, 0.000007), Vector3(0.00004, 0, 0.000007), Vector3(0, 0.00004, 0.000007)])
	var tiny_sources: Array[Dictionary] = [{"body_id": &"fine_spline", "editable": true, "is_handle": false, "bvh": _source_bvh(microscopic)}]
	_check(selection.build(host, microscopic, tiny_sources), "fine facet below Godot metre-space snap remains queryable")
	var fine_hit: Dictionary = selection.resolve(Vector3(0.00001, 0.00001, 1), Vector3.FORWARD)
	_check(fine_hit.get("body_id") == &"fine_spline" and bool(fine_hit.get("editable", false)), "fine facet ownership survives query-space conversion")
	_check((fine_hit.get("local_position", Vector3.INF) as Vector3).distance_to(Vector3(0.00001, 0.00001, 0.000007)) < 0.0000002, "query results return exact scene-space positions")
	selection.clear()
	var a := Vector3(0, 0, 0)
	var b := Vector3(1, 0, 0)
	var c := Vector3(0, 1, 0)
	var inner_a := Vector3(0.5, 0.1, 0)
	var inner_b := Vector3(0.6, 0.1, 0)
	var inner_c := Vector3(0.5, 0.2, 0)
	var ring := PackedVector3Array([a, b, inner_b, a, inner_b, inner_a,
		b, c, inner_c, b, inner_c, inner_b, c, a, inner_a, c, inner_a, inner_c])
	var ring_bvh := _source_bvh(ring)
	var witness_count := 0
	for witness: Vector3 in [(a + b + c) / 3.0, a * 0.8 + b * 0.1 + c * 0.1,
		b * 0.8 + a * 0.1 + c * 0.1, c * 0.8 + a * 0.1 + b * 0.1]:
		if not ring_bvh.intersect_ray((witness + Vector3(0, 0, 1)) * SELECTION.QUERY_SCALE, Vector3.FORWARD).is_empty():
			witness_count += 1
	_check(witness_count == 4, "small-hole adversary passes former four witness test")
	var hole_sources: Array[Dictionary] = [{"body_id": &"incomplete_source", "editable": true, "is_handle": false, "bvh": ring_bvh}]
	_check(selection.build(host, PackedVector3Array([a, b, c]), hole_sources), "small-hole final triangle map builds")
	var hole_hit: Dictionary = selection.resolve(Vector3(0.53, 0.13, 1), Vector3.FORWARD)
	_check(bool(hole_hit.get("valid", false)) and not bool(hole_hit.get("editable", true)) and hole_hit.get("body_id") == StringName(), "merged triangle with hidden source hole cannot claim editable ownership")
	selection.clear()
	var partial_sources: Array[Dictionary] = [
		{"body_id": &"newer_freehand_patch", "editable": false, "is_handle": false, "bvh": _source_bvh(PackedVector3Array([inner_a, inner_b, inner_c]))},
		{"body_id": &"older_full_spline", "editable": true, "is_handle": false, "bvh": _source_bvh(PackedVector3Array([a, b, c]))},
	]
	_check(selection.build(host, PackedVector3Array([a, b, c]), partial_sources), "merged coplanar newer-patch fixture builds")
	var partial_hit: Dictionary = selection.resolve(Vector3(0.53, 0.13, 1), Vector3.FORWARD)
	_check(partial_hit.get("body_id") == StringName() and not bool(partial_hit.get("editable", true)), "newer partial freehand coverage blocks older full-spline fallback")
	selection.clear()
	host.free()

func _source_bvh(faces: PackedVector3Array) -> TriangleMesh:
	return SELECTION.build_query_bvh(faces)

func _native_coplanar_ownership_case() -> void:
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as Object
	backend.call("set_history_window_enabled", true)
	var base := _box_packet(Vector3(1, 1, 0.1), Vector3(0.5, 0.5, -0.05))
	var patch := _box_packet(Vector3(0.1, 0.1, 0.1), Vector3(0.55, 0.15, -0.05))
	var third := _box_packet(Vector3(0.1, 0.1, 0.1), Vector3(0.9, 0.9, -0.12))
	var result: Dictionary = backend.call("reset_mesh", base.vertices, base.indices)
	_check(bool(result.get("ok", false)), "native coplanar base resets")
	result = backend.call("add_mesh", patch.vertices, patch.indices)
	_check(bool(result.get("ok", false)), "native contained newer patch adds")
	result = backend.call("add_mesh", third.vertices, third.indices)
	_check(bool(result.get("ok", false)), "third native append preserves earlier patch ownership test")
	var host := Node3D.new()
	root.add_child(host)
	var selection = SELECTION.new()
	var sources: Array[Dictionary] = [
		{"body_id": &"third", "editable": false, "is_handle": false, "bvh": _source_bvh(third.faces)},
		{"body_id": &"native_freehand_patch", "editable": false, "is_handle": false, "bvh": _source_bvh(patch.faces)},
		{"body_id": &"native_old_spline", "editable": true, "is_handle": false, "bvh": _source_bvh(base.faces)},
	]
	var faces := PackedVector3Array()
	var vertices: PackedVector3Array = result.get("vertices", PackedVector3Array())
	for index: int in result.get("indices", PackedInt32Array()):
		faces.append(vertices[index])
	_check(selection.build(host, faces, sources), "native final coplanar surfaces classify")
	var hit: Dictionary = selection.resolve(Vector3(0.55, 0.15, 1), Vector3.FORWARD)
	_check(bool(hit.get("valid", false)) and not bool(hit.get("editable", true)), "actual merged patch after third append cannot select older spline through newer freehand")
	_check(selection.materials.has(&"native_old_spline"), "other surviving old spline surfaces remain selectable")
	selection.clear()
	host.free()

func _box_packet(size: Vector3, center: Vector3) -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = size
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in range(vertices.size()):
		vertices[index] += center
	var faces := PackedVector3Array()
	for index: int in indices:
		faces.append(vertices[index])
	return {"vertices": vertices, "indices": indices, "faces": faces}

func _finish_surfaces() -> void:
	DirAccess.make_dir_recursive_absolute(SURFACE_REPORT.get_base_dir())
	var file := FileAccess.open(SURFACE_REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures == 0, "checks": checks, "failures": failures}, "\t"))
	print("RETAINED_EDIT_SURFACES ", checks.size() - failures, "/", checks.size())
	workspace.queue_free()
	controller.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
