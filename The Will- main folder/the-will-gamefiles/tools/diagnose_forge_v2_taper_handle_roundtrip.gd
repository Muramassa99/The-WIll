extends SceneTree

## Read-only for player data: builds an identical Handle in fresh authoring
## state, compares the saved fixture artifact, and writes only diagnostic files.
const STATE = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const PROFILES = preload("res://core/models/player_tool_profile_library_state.gd")
const ADAPTER = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const PRESENTER = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")
const ARTIFACT_DIR := "C:/WORKSPACE/godot_runs/forge_v2_taper_test"
const REPORT_PATH := ARTIFACT_DIR + "/handle_roundtrip_report.json"
const ROUNDTRIP_PATH := ARTIFACT_DIR + "/diagnostic_fresh_handle_roundtrip.tres"

var report: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var profiles := ResourceLoader.load(PROFILES.DEFAULT_SAVE_FILE_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	var saved := ResourceLoader.load(ARTIFACT_DIR + "/handle_body.tres", "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if profiles == null or saved == null:
		_finish(false, "source_profile_or_saved_artifact_missing")
		return
	var profile: Dictionary = {}
	for candidate: Dictionary in profiles.get("saved_profiles"):
		if String(candidate.get("label", "")).nocasecmp_to("Medoum rounded") == 0:
			profile = candidate.duplicate(true)
			break
	if profile.is_empty():
		_finish(false, "medium_round_profile_missing")
		return
	var state: Resource = STATE.new()
	state.call("reset_new_draft", "Taper_test")
	state.call("set_active_tool_id", &"tool_handles")
	state.call("set_active_handle_path_mode_id", &"handle_path_2_point_linear")
	if not bool(state.call("apply_tool_profile_preset", profile)):
		_finish(false, "profile_rejected")
		return
	state.call("append_spline_line_point", Vector3(0.02 - 0.15, 0, 0), Vector3.UP)
	state.call("append_spline_line_point", Vector3(0.02, 0, 0), Vector3.UP)
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		_finish(false, "fresh_handle_generation_failed")
		return
	state.call("commit_pending_material_bodies_as_layer")
	var fresh_result: Dictionary = ADAPTER.resolve_valid_handle_body(state)
	var fresh := fresh_result.get("body") as Resource
	if fresh == null or not bool(fresh_result.get("valid", false)):
		_finish(false, "fresh_handle_invalid")
		return
	if ResourceSaver.save(fresh.duplicate(true), ROUNDTRIP_PATH) != OK:
		_finish(false, "diagnostic_roundtrip_save_failed")
		return
	var roundtrip := ResourceLoader.load(ROUNDTRIP_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if roundtrip == null:
		_finish(false, "diagnostic_roundtrip_reload_failed")
		return
	var scalars: Array[Dictionary] = []
	var roundtrip_matches_saved := true
	for property: Dictionary in fresh.get_property_list():
		var key := String(property.name)
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or typeof(fresh.get(key)) != TYPE_FLOAT:
			continue
		var a := float(fresh.get(key))
		var b := float(saved.get(key))
		var c := float(roundtrip.get(key))
		var entry := {"field": key,
			"fresh_decimal": "%.18f" % a, "saved_decimal": "%.18f" % b,
			"roundtrip_decimal": "%.18f" % c,
			"fresh_f64_hex": PackedFloat64Array([a]).to_byte_array().hex_encode(),
			"saved_f64_hex": PackedFloat64Array([b]).to_byte_array().hex_encode(),
			"roundtrip_f64_hex": PackedFloat64Array([c]).to_byte_array().hex_encode(),
			"fresh_saved_delta": absf(a - b), "roundtrip_saved_delta": absf(c - b)}
		scalars.append(entry)
		if key not in ["created_timestamp", "updated_timestamp"]:
			roundtrip_matches_saved = c == b and roundtrip_matches_saved
		print("HANDLE_SCALAR ", JSON.stringify(entry))
	var fields: Dictionary = {}
	var geometric_fields_equal := true
	for key: String in ["shape_kind", "body_kind", "profile_id", "profile_display_name",
		"path_points", "path_surface_normals", "path_roll_degrees",
		"path_profile_scales", "path_profile_transform_ranges",
		"profile_polygon_2d_meters", "profile_anchor_2d_meters",
		"profile_contact_point_relative_2d_meters", "profile_contact_direction_2d"]:
		var identical: bool = fresh.get(key) == saved.get(key)
		fields[key] = identical
		geometric_fields_equal = identical and geometric_fields_equal
	var presenter := PRESENTER.new()
	root.add_child(presenter)
	var fresh_mesh := presenter.call("_build_active_material_body_sweep_mesh", fresh) as ArrayMesh
	var saved_mesh := presenter.call("_build_active_material_body_sweep_mesh", saved) as ArrayMesh
	var roundtrip_mesh := presenter.call("_build_active_material_body_sweep_mesh", roundtrip) as ArrayMesh
	var mesh_comparison := _compare_meshes(fresh_mesh, saved_mesh)
	var serialized_comparison := _compare_meshes(roundtrip_mesh, saved_mesh)
	presenter.free()
	report = {"scalars": scalars, "geometric_fields": fields,
		"geometric_fields_identical": geometric_fields_equal,
		"all_saved_float_scalars_equal_fresh_tres_roundtrip": roundtrip_matches_saved,
		"fresh_vs_saved_sweep": mesh_comparison,
		"fresh_roundtrip_vs_saved_sweep": serialized_comparison,
		"player_library_opened_or_written": false}
	_finish(geometric_fields_equal and roundtrip_matches_saved
		and bool(mesh_comparison.get("identical", false))
		and bool(serialized_comparison.get("identical", false)), "comparison_complete")

func _compare_meshes(a: ArrayMesh, b: ArrayMesh) -> Dictionary:
	if a == null or b == null or a.get_surface_count() != 1 or b.get_surface_count() != 1:
		return {"identical": false, "reason": "mesh_missing_or_surface_count"}
	var aa := a.surface_get_arrays(0)
	var ba := b.surface_get_arrays(0)
	var av: PackedVector3Array = aa[Mesh.ARRAY_VERTEX]
	var bv: PackedVector3Array = ba[Mesh.ARRAY_VERTEX]
	if av.size() != bv.size():
		return {"identical": false, "fresh_vertices": av.size(), "saved_vertices": bv.size()}
	var max_vertex_delta := 0.0
	for index in range(av.size()):
		max_vertex_delta = maxf(max_vertex_delta, av[index].distance_to(bv[index]))
	var indices_equal: bool = aa[Mesh.ARRAY_INDEX] == ba[Mesh.ARRAY_INDEX]
	return {"identical": max_vertex_delta == 0.0 and indices_equal,
		"vertices": av.size(), "max_vertex_delta_m": max_vertex_delta,
		"indices_identical": indices_equal,
		"normals_identical": aa[Mesh.ARRAY_NORMAL] == ba[Mesh.ARRAY_NORMAL]}

func _finish(ok: bool, reason: String) -> void:
	report["ok"] = ok
	report["reason"] = reason
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
	print("TAPER_HANDLE_ROUNDTRIP ", JSON.stringify(report))
	quit(0 if ok else 1)
