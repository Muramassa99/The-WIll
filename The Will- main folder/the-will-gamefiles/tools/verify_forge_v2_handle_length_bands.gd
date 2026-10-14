extends SceneTree

# Exercises the same authoring gates, preview meshes and export adapter used by
# Forge, with tiny in-memory fixtures. Does not run a character or grip solver.
const Authoring = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const Body = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const Preview = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")
const Adapter = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const HandlePacket = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Wip = preload("res://core/models/crafted_item_wip.gd")
const Policy = preload("res://core/resolvers/handle_length_policy.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const RESULT_PATH := "C:/WORKSPACE/godot_runs/verify_forge_v2_handle_length_bands_2026-10-14.json"
const SAVE_PATH := "user://verification/forge_v2_handle_length_bands.tres"
const BOUNDARIES_MM := [99.99, 100.0, 199.99, 200.0, 249.99, 250.0, 600.0]
const PATH_MODES := [
	Authoring.HANDLE_PATH_MODE_THREE_POINT_SPLINE,
	Authoring.HANDLE_PATH_MODE_THREE_POINT_LINEAR,
	Authoring.HANDLE_PATH_MODE_TWO_POINT_LINEAR,
]

var _checks := 0
var _failures := PackedStringArray()
var _cases: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	_verify_policy()
	var presenter: Node3D = Preview.new()
	root.add_child(presenter)
	for length_mm: float in BOUNDARIES_MM:
		for mode: StringName in PATH_MODES:
			_verify_authoring_and_color(presenter, length_mm, mode)
		if length_mm >= 100.0:
			_verify_export(length_mm)
	_verify_ordinary_spline(presenter)
	_verify_saved_short_handle_rejection()
	presenter.free()
	var report := {
		"ok": _failures.is_empty(), "checks": _checks,
		"failures": _failures, "cases": _cases,
		"duration_ms": float(Time.get_ticks_usec() - started) / 1000.0,
	}
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var output := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t") + "\n")
	for failure: String in _failures:
		push_error(failure)
	print("Forge V2 Handle length bands: %d checks, %d failures" % [
		_checks, _failures.size(),
	])
	quit(0 if _failures.is_empty() else 1)


func _verify_policy() -> void:
	var bands := [Policy.BAND_INVALID, Policy.BAND_SINGLE_HAND, Policy.BAND_SINGLE_HAND,
		Policy.BAND_TWO_HAND, Policy.BAND_TWO_HAND, Policy.BAND_LONG_HANDLE, Policy.BAND_LONG_HANDLE]
	for index: int in range(BOUNDARIES_MM.size()):
		var length_mm := float(BOUNDARIES_MM[index])
		_expect(Policy.classify_length(length_mm * 0.001) == bands[index],
			"%.2f mm shared policy band" % length_mm)
	for invalid: float in [-1.0, 0.0, INF, NAN]:
		_expect(not Policy.meets_minimum(invalid) and not Policy.allows_two_hands(invalid),
			"invalid metric input is not usable: %s" % str(invalid))


func _verify_authoring_and_color(
	presenter: Node3D, length_mm: float, mode: StringName
) -> void:
	var label := "%.2f mm / %s" % [length_mm, mode]
	var state := _state(length_mm, mode)
	var valid := length_mm >= 100.0
	_expect(bool(state.call("can_generate_profile_extrusion_from_spline")) == valid,
		label + " generation gate")
	var status := String(state.call("get_profile_extrusion_status_label"))
	_expect(status.contains("mm axial span"), label + " status uses millimetres")
	for finished: bool in [false, true]:
		if finished:
			_expect(bool(state.call("finish_spline_line")), label + " finishes path")
		presenter.call("_sync_spline_preview_mesh", state)
		var mesh_name := "SplineLinePreviewMesh" if valid else "SplineLineInvalidPreviewMesh"
		_expect(_preview_has_color(presenter, mesh_name, _expected_color(length_mm)),
			"%s %s guide color" % [label, "finished" if finished else "draft"])
	if not valid:
		_expect(not bool(state.call("generate_profile_extrusion_from_spline")),
			label + " does not generate invalid Handle")
		return
	_expect(bool(state.call("generate_profile_extrusion_from_spline")), label + " generates")
	var body := state.call("get_selected_material_body") as Resource
	if not _expect(body != null, label + " has generated body"):
		return
	var body_id := StringName(body.get("body_id"))
	_expect(bool(state.call("is_material_body_commit_ready", body_id)), label + " commit gate")
	_expect(state.call("commit_material_body_as_layer", body_id) != null, label + " commits")
	var saved_gate: Dictionary = Adapter.resolve_valid_handle_body(state)
	_expect(bool(saved_gate.get("valid", false)), label + " saved Handle validator accepts")


func _verify_export(length_mm: float) -> void:
	var state := _state(length_mm, Authoring.HANDLE_PATH_MODE_THREE_POINT_LINEAR)
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		_expect(false, "%.2f mm export fixture generates" % length_mm)
		return
	var body := state.call("get_selected_material_body") as Resource
	if body == null or state.call("commit_material_body_as_layer", body.get("body_id")) == null:
		_expect(false, "%.2f mm export fixture commits" % length_mm)
		return
	var wip: CraftedItemWIP = Wip.new()
	wip.wip_id = &"verify_handle_length_bands"
	wip.forge_builder_path_id = Wip.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = Wip.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.forge_v2_authoring_state = state
	var packet := _box_packet(body, length_mm * 0.001)
	# 199.99 mm and 200 mm round to the same cell count at either encoding.
	# Their eligibility must nevertheless differ at the metric boundary.
	for cell_size: float in [0.0125, 0.025]:
		var label := "%.2f mm / %.4f m encoding" % [length_mm, cell_size]
		var contract: Dictionary = Adapter.build_runtime_contract(wip, packet, cell_size)
		if not _expect(bool(contract.get("valid", false)), label + " exports: " + String(contract.get("error", ""))):
			continue
		var profile := contract.get("baked_profile") as BakedProfile
		if not _expect(profile != null, label + " has BakedProfile"):
			continue
		_expect(profile.primary_grip_valid, label + " valid primary grip")
		_expect(profile.primary_grip_two_hand_eligible == (length_mm >= 200.0),
			label + " two-hand eligibility follows exact metric length")
		var restored_mm := profile.primary_grip_span_start.distance_to(profile.primary_grip_span_end) * cell_size * 1000.0
		_expect(absf(restored_mm - length_mm) < 0.001, label + " preserves full metric span")
		_cases.append({
			"length_mm": length_mm, "cell_size_m": cell_size,
			"legacy_span_cells": profile.primary_grip_span_length_voxels,
			"restored_span_mm": restored_mm,
			"two_hand_eligible": profile.primary_grip_two_hand_eligible,
		})
		wip.latest_baked_profile_snapshot = profile
		wip.stage2_item_state = contract.get("stage2_item_state") as Resource
		if length_mm == 199.99 or length_mm == 200.0:
			_verify_cache_refresh(wip, length_mm >= 200.0)
		if length_mm == 100.0 and cell_size == 0.0125:
			_verify_obsolete_minimum_refresh(wip)
		if length_mm == 200.0 and cell_size == 0.0125:
			wip.latest_baked_profile_snapshot = profile
			_verify_save_reload(wip)
	# Preserve the existing equipment-context restriction: a long shield Handle
	# is not turned into the melee/focus two-hand branch by its color alone.
	if length_mm == 250.0:
		wip.forge_intent = &"intent_shield"
		wip.equipment_context = &"ctx_shield"
		var shield_contract: Dictionary = Adapter.build_runtime_contract(wip, packet)
		_expect(bool(shield_contract.get("valid", false)), "shield Handle still exports")
		var shield_profile := shield_contract.get("baked_profile") as BakedProfile
		_expect(shield_profile != null and not shield_profile.primary_grip_two_hand_eligible,
			"length gate preserves existing shield context restriction")


func _verify_cache_refresh(wip: CraftedItemWIP, expected_two_hand: bool) -> void:
	var original := wip.latest_baked_profile_snapshot
	var stale := original.duplicate(true) as BakedProfile
	stale.primary_grip_two_hand_eligible = not expected_two_hand
	stale.primary_grip_two_hand_negative_limit = 0.0
	stale.primary_grip_two_hand_positive_limit = 0.0
	wip.latest_baked_profile_snapshot = stale
	var service: ForgeService = ForgeServiceScript.new()
	var refreshed := service.get_cached_profile_for_runtime(wip)
	_expect(refreshed != null and refreshed != stale, "runtime refresh returns independent cached profile")
	if refreshed != null:
		_expect(refreshed.primary_grip_two_hand_eligible == expected_two_hand,
			"old saved capacity refreshed using exact span and saved unit scale")
		if expected_two_hand:
			_expect(refreshed.primary_grip_two_hand_positive_limit > 0.0
				and refreshed.primary_grip_two_hand_negative_limit < 0.0,
				"old saved balanced two-hand limits restored with newly eligible capacity")
	_expect(stale.primary_grip_two_hand_eligible == (not expected_two_hand),
		"runtime capacity refresh leaves saved snapshot unchanged")
	wip.latest_baked_profile_snapshot = original


func _verify_obsolete_minimum_refresh(wip: CraftedItemWIP) -> void:
	var original := wip.latest_baked_profile_snapshot
	var stale := original.duplicate(true) as BakedProfile
	stale.primary_grip_valid = false
	stale.validation_error = "forge_v2_primary_handle_span_below_0_25_meters"
	wip.latest_baked_profile_snapshot = stale
	var service: ForgeService = ForgeServiceScript.new()
	var refreshed := service.get_cached_profile_for_runtime(wip)
	_expect(refreshed != null and refreshed.primary_grip_valid,
		"100 mm saved Handle rejected by old minimum rebuilds from saved mesh")
	_expect(not stale.primary_grip_valid
		and stale.validation_error == "forge_v2_primary_handle_span_below_0_25_meters",
		"obsolete-minimum refresh preserves original snapshot resource")
	var unrelated := original.duplicate(true) as BakedProfile
	unrelated.primary_grip_valid = false
	unrelated.validation_error = "forge_v2_primary_handle_exact_mesh_signature_mismatch"
	wip.latest_baked_profile_snapshot = unrelated
	var still_invalid := service.get_cached_profile_for_runtime(wip)
	_expect(still_invalid != null and not still_invalid.primary_grip_valid
		and still_invalid.validation_error == unrelated.validation_error,
		"unrelated saved validation failure is not silently bypassed")
	wip.latest_baked_profile_snapshot = original


func _verify_save_reload(wip: CraftedItemWIP) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_PATH.get_base_dir()))
	if not _expect(ResourceSaver.save(wip, SAVE_PATH) == OK, "200 mm exported WIP saves"):
		return
	var reloaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as CraftedItemWIP
	if _expect(reloaded != null, "200 mm exported WIP reloads uncached"):
		var saved_profile := reloaded.latest_baked_profile_snapshot
		_expect(saved_profile != null and saved_profile.primary_grip_two_hand_eligible,
			"saved/reloaded WIP retains metric two-hand eligibility")
		_expect(bool(Adapter.resolve_valid_handle_body(reloaded.forge_v2_authoring_state).get("valid", false)),
			"saved/reloaded 200 mm Handle remains valid")
	_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH)) == OK,
		"temporary verifier WIP removed")


func _verify_saved_short_handle_rejection() -> void:
	var state := _state(100.0, Authoring.HANDLE_PATH_MODE_THREE_POINT_LINEAR)
	state.call("generate_profile_extrusion_from_spline")
	var body := state.call("get_selected_material_body") as Resource
	if not _expect(body != null, "short saved fixture initially generates"):
		return
	state.call("commit_material_body_as_layer", body.get("body_id"))
	body.set("path_points", PackedVector3Array([
		Vector3.ZERO, Vector3(0.049995, 0.0, 0.0), Vector3(0.09999, 0.0, 0.0),
	]))
	var validation: Dictionary = Adapter.resolve_valid_handle_body(state)
	_expect(not bool(validation.get("valid", false)), "saved 99.99 mm Handle rejected by export validator")


func _verify_ordinary_spline(presenter: Node3D) -> void:
	var state: Resource = Authoring.new()
	state.call("reset_new_draft", "Ordinary mint control")
	state.call("set_active_tool_id", Authoring.TOOL_SPLINE_LINE)
	state.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	state.call("append_spline_line_point", Vector3(0.05, 0.0, 0.0), Vector3.UP)
	for finished: bool in [false, true]:
		if finished:
			state.call("finish_spline_line")
		presenter.call("_sync_spline_preview_mesh", state)
		_expect(_preview_has_color(presenter, "SplineLinePreviewMesh", Preview.SPLINE_LINE_COLOR),
			"ordinary %s spline stays mint below Handle minimum" % ("finished" if finished else "draft"))
	_expect(bool(state.call("can_generate_spline_line_csg_noodle")), "ordinary short spline remains usable")


func _state(length_mm: float, mode: StringName) -> Resource:
	var state: Resource = Authoring.new()
	state.call("reset_new_draft", "Handle length boundary")
	state.call("set_active_tool_id", Authoring.TOOL_HANDLES)
	state.call("set_active_profile_id", Profiles.PROFILE_HANDLE_BUILDER)
	state.call("set_active_handle_path_mode_id", mode)
	state.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	if mode != Authoring.HANDLE_PATH_MODE_TWO_POINT_LINEAR:
		state.call("append_spline_line_point", Vector3(length_mm * 0.0005, 0.0, 0.0), Vector3.UP)
	state.call("append_spline_line_point", Vector3(length_mm * 0.001, 0.0, 0.0), Vector3.UP)
	return state


func _box_packet(body: Resource, length_m: float) -> Dictionary:
	var vertices := PackedVector3Array([
		Vector3(0.0, -0.025, -0.025), Vector3(length_m, -0.025, -0.025),
		Vector3(length_m, 0.025, -0.025), Vector3(0.0, 0.025, -0.025),
		Vector3(0.0, -0.025, 0.025), Vector3(length_m, -0.025, 0.025),
		Vector3(length_m, 0.025, 0.025), Vector3(0.0, 0.025, 0.025),
	])
	var indices := PackedInt32Array([
		0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
		0, 4, 7, 0, 7, 3, 1, 2, 6, 1, 6, 5,
		0, 1, 5, 0, 5, 4, 3, 7, 6, 3, 6, 2,
	])
	return {
		"ok": true, "vertices": vertices, "indices": indices,
		"primary_grip_handle_vertices": vertices,
		"primary_grip_handle_indices": indices,
		"primary_grip_handle_vertices_origin_id": HandlePacket.VERTICES_ORIGIN_ID,
		"primary_grip_handle_mesh_source": HandlePacket.SOURCE,
		"primary_grip_handle_body_signature": HandlePacket.build_body_signature(body),
		"watertight": true, "output_volume_m3": length_m * 0.05 * 0.05,
		"source_original_ids": PackedStringArray(["verify_handle_length"]),
		"material_variant_id": &"mat_iron_gray", "source_state_revision": 1,
	}


func _expected_color(length_mm: float) -> Color:
	if length_mm < 100.0:
		return Preview.DETAILING_INVALID_LINE_COLOR
	if length_mm < 200.0:
		return Preview.HANDLE_SINGLE_HAND_LINE_COLOR
	if length_mm < 250.0:
		return Preview.HANDLE_TWO_HAND_LINE_COLOR
	return Preview.HANDLE_LONG_LINE_COLOR


func _preview_has_color(presenter: Node3D, node_name: String, expected: Color) -> bool:
	var instance := presenter.get_node_or_null(node_name) as MeshInstance3D
	if instance == null or not instance.visible or instance.mesh == null:
		return false
	for surface: int in range(instance.mesh.get_surface_count()):
		var arrays := instance.mesh.surface_get_arrays(surface)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for color: Color in colors:
			if (absf(color.r - expected.r) < 0.01 and absf(color.g - expected.g) < 0.01
				and absf(color.b - expected.b) < 0.01 and absf(color.a - expected.a) < 0.01):
				return true
	return false


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
