extends SceneTree

const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)
const CraftingBenchUIV2Scene = preload(
	"res://scenes/ui_v2/crafting_bench_ui_v2.tscn"
)
const PlacementTargetResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_placement_target_resolver.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_generic_volume_surface_layering.json"
)
const PROFILE_LIBRARY_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_generic_volume_surface_layering_profiles.tres"
)
const KEYBINDING_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_generic_volume_surface_layering_keybindings.json"
)
const MATERIAL_SURFACE_KIND := (
	PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE
)
const PLACEMENT_PLANE_KIND := (
	PlacementTargetResolverScript.TARGET_KIND_PLACEMENT_PLANE
)
const PUBLICATION_WAIT_PAIR_LIMIT := 180
const HIT_POSITION_STABILITY_METERS := 0.0002
const HIT_NORMAL_STABILITY_DOT_MIN := 0.999
const BODY_POINT_TOLERANCE_METERS := 0.001
const MIN_OUTWARD_SHIFT_METERS := 0.005

var _errors: Array[String] = []
var _report := {
	"schema": "forge_v2_generic_volume_surface_layering",
	"schema_version": 1,
	"ok": false,
	"production_files_touched": false,
	"scope": (
		"real CraftingBenchUIV2 generic Volume Stroke input onto a published "
		+ "native material surface"
	),
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	root.size = Vector2i(1280, 720)

	var controller: Node = ForgeV2StageControllerScript.new()
	controller.name = "GenericVolumeSurfaceLayeringController"
	root.add_child(controller)
	controller.call("start_new_draft", "Generic Volume Surface Layering Verify")
	controller.call("set_active_tool_id", &"tool_volume_stroke")
	controller.call("set_freehand_smoothing_steps", 0)
	controller.call("set_active_material_variant_id", &"mat_iron_gray")
	controller.call("set_active_operation_mode", &"operation_add_material")
	controller.call("set_placement_policy", &"placement_replace_existing")

	var ui: CanvasLayer = CraftingBenchUIV2Scene.instantiate() as CanvasLayer
	if not _expect(ui != null, "CraftingBenchUIV2 could not be instantiated"):
		_finish(null, null)
		return
	var profile_state: Resource = PlayerToolProfileLibraryStateScript.new()
	profile_state.set("save_file_path", PROFILE_LIBRARY_PATH)
	var keybinding_state: Resource = ForgeV2KeybindingStateScript.new()
	keybinding_state.set("save_file_path", KEYBINDING_PATH)
	keybinding_state.call("normalize")
	ui.set("tool_profile_library_state", profile_state)
	ui.set("keybinding_state", keybinding_state)
	root.add_child(ui)
	await process_frame
	ui.call(
		"open_for",
		null,
		controller,
		"Generic Volume Surface Layering Verify",
		null
	)
	await process_frame
	await process_frame

	var workspace: Node3D = ui.get("workspace_preview") as Node3D
	if not _expect(workspace != null, "full UI did not create a workspace preview"):
		_finish(ui, controller)
		return
	var contract: Resource = controller.call("get_workspace_contract") as Resource
	if not _expect(contract != null, "controller workspace contract is missing"):
		_finish(ui, controller)
		return
	var placement_z := float(contract.get("placement_plane_z"))
	var pass_local_points := PackedVector3Array([
		Vector3(-0.30, 0.0, placement_z),
		Vector3(0.0, 0.0, placement_z),
		Vector3(0.30, 0.0, placement_z),
	])
	var pass_screen_points := _project_points(workspace, pass_local_points)
	if not _expect(
		pass_screen_points.size() == pass_local_points.size(),
		"first-pass points could not be projected through the real workspace camera"
	):
		_finish(ui, controller)
		return

	var state: Resource = controller.call("get_active_authoring_state") as Resource
	var first_body_count_before := _body_count(state)
	ui.call("_begin_workspace_brush_stroke", pass_screen_points[0])
	var first_body_id := StringName(controller.call("get_active_placement_body_id"))
	ui.call("_extend_workspace_brush_stroke", pass_screen_points[1], false)
	ui.call("_extend_workspace_brush_stroke", pass_screen_points[2], true)
	ui.call("_finish_workspace_brush_stroke", pass_screen_points[2], true)
	var first_finish := controller.call(
		"get_last_material_body_finish_result"
	) as Dictionary
	if not _expect(
		first_body_id != StringName(),
		"generic UI did not begin first Volume Stroke"
	):
		_finish(ui, controller)
		return
	if not _expect(
		_body_count(state) == first_body_count_before + 1,
		"first generic UI pass was not retained"
	):
		_finish(ui, controller)
		return

	var first_hits: Array[Dictionary] = []
	for screen_position: Vector2 in pass_screen_points:
		var hit := await _await_stable_material_hit(
			workspace,
			screen_position,
			StringName()
		)
		if not _expect(
			bool(hit.get("ok", false)),
			"first pass did not publish a stable native material collider"
		):
			_finish(ui, controller)
			return
		first_hits.append(hit)
	var first_target_id := StringName(first_hits[1].get(
		"surface_target_id",
		StringName()
	))
	var initial_hybrid_target := workspace.call(
		"resolve_placement_target",
		pass_screen_points[0]
	) as Dictionary
	if not _expect(
		bool(initial_hybrid_target.get("valid", false))
		and StringName(initial_hybrid_target.get("target_kind", StringName()))
		== MATERIAL_SURFACE_KIND,
		"second pass initial UI target was not the first pass material surface"
	):
		_finish(ui, controller)
		return

	var plane_only_local := Vector3(0.0, 0.22, placement_z)
	var plane_only_projection := workspace.call(
		"project_workspace_local_to_screen",
		plane_only_local
	) as Dictionary
	if not _expect(
		bool(plane_only_projection.get("valid", false)),
		"plane-only witness could not be projected"
	):
		_finish(ui, controller)
		return
	var plane_only_screen := plane_only_projection.get(
		"screen_position",
		Vector2.ZERO
	) as Vector2
	var strict_material_miss := workspace.call(
		"resolve_material_surface_target",
		plane_only_screen
	) as Dictionary
	var hybrid_plane_hit := workspace.call(
		"resolve_placement_target",
		plane_only_screen
	) as Dictionary
	if not _expect(
		not bool(strict_material_miss.get("valid", false))
		and bool(hybrid_plane_hit.get("valid", false))
		and StringName(hybrid_plane_hit.get("target_kind", StringName()))
		== PLACEMENT_PLANE_KIND,
		"fallback witness was not an unambiguous plane-only UI target"
	):
		_finish(ui, controller)
		return

	var second_body_count_before := _body_count(state)
	ui.call("_begin_workspace_brush_stroke", pass_screen_points[0])
	var second_body_id := StringName(controller.call("get_active_placement_body_id"))
	var second_body := _find_body(state, second_body_id)
	if not _expect(
		second_body != null,
		"generic UI did not begin second Volume Stroke on material"
	):
		_finish(ui, controller)
		return
	var second_start_points: PackedVector3Array = second_body.get("path_points")
	var expected_second_start := first_hits[0].get(
		"local_position",
		Vector3.ZERO
	) as Vector3
	var second_start_on_material := (
		second_start_points.size() == 1
		and second_start_points[0].distance_to(expected_second_start)
		<= BODY_POINT_TOLERANCE_METERS
	)
	_expect(
		second_start_on_material,
		"second Volume Stroke did not retain the material-surface hit as point zero"
	)

	ui.call("_extend_workspace_brush_stroke", pass_screen_points[1], false)
	var points_before_plane_miss: PackedVector3Array = (
		second_body.get("path_points") as PackedVector3Array
	).duplicate()
	ui.call("_extend_workspace_brush_stroke", plane_only_screen, false)
	var points_after_plane_miss: PackedVector3Array = (
		second_body.get("path_points") as PackedVector3Array
	).duplicate()
	var plane_fallback_rejected := (
		points_after_plane_miss.size() == points_before_plane_miss.size()
		and _packed_points_equal(
			points_after_plane_miss,
			points_before_plane_miss,
			BODY_POINT_TOLERANCE_METERS
		)
	)
	_expect(
		plane_fallback_rejected,
		"active material-surface stroke accepted a placement-plane fallback sample"
	)
	var active_surface_after_miss := workspace.call(
		"resolve_material_surface_target",
		pass_screen_points[1]
	) as Dictionary
	_expect(
		bool(active_surface_after_miss.get("valid", false))
		and StringName(active_surface_after_miss.get(
			"surface_target_id",
			StringName()
		)) == first_target_id,
		"first pass collider stopped being targetable during active pass B"
	)

	ui.call("_extend_workspace_brush_stroke", pass_screen_points[2], true)
	var points_after_material_return: PackedVector3Array = (
		second_body.get("path_points") as PackedVector3Array
	).duplicate()
	var returned_to_material := (
		points_after_material_return.size() > points_after_plane_miss.size()
		and points_after_material_return[
			points_after_material_return.size() - 1
		].distance_to(
			first_hits[2].get("local_position", Vector3.ZERO) as Vector3
		) <= BODY_POINT_TOLERANCE_METERS
	)
	_expect(
		returned_to_material,
		"generic UI did not resume material-surface sampling after a rejected miss"
	)
	ui.call("_finish_workspace_brush_stroke", pass_screen_points[2], true)
	var second_finish := controller.call(
		"get_last_material_body_finish_result"
	) as Dictionary
	_expect(
		_body_count(state) == second_body_count_before + 1,
		"second generic UI pass was not retained"
	)

	var second_center_hit := await _await_stable_material_hit(
		workspace,
		pass_screen_points[1],
		first_target_id
	)
	var outward_shift := -INF
	if bool(second_center_hit.get("ok", false)):
		var first_position := first_hits[1].get(
			"local_position",
			Vector3.ZERO
		) as Vector3
		var first_normal := (
			first_hits[1].get("local_normal", Vector3.ZERO) as Vector3
		).normalized()
		var second_position := second_center_hit.get(
			"local_position",
			Vector3.ZERO
		) as Vector3
		outward_shift = (second_position - first_position).dot(first_normal)
	_expect(
		bool(second_center_hit.get("ok", false)),
		"second pass did not publish a replacement native material collider"
	)
	_expect(
		outward_shift >= MIN_OUTWARD_SHIFT_METERS,
		"second deposited pass did not move the physical surface outward"
	)

	var first_hit_summaries: Array[Dictionary] = []
	for first_hit: Dictionary in first_hits:
		first_hit_summaries.append(_hit_summary(first_hit))
	_report["first_pass"] = {
		"body_id": String(first_body_id),
		"finish": _json_safe(first_finish),
		"surface_target_id": String(first_target_id),
		"stable_hits": first_hit_summaries,
	}
	_report["second_pass"] = {
		"body_id": String(second_body_id),
		"finish": _json_safe(second_finish),
		"initial_target_kind": String(initial_hybrid_target.get(
			"target_kind",
			StringName()
		)),
		"initial_point_on_material": second_start_on_material,
		"point_count_before_plane_miss": points_before_plane_miss.size(),
		"point_count_after_plane_miss": points_after_plane_miss.size(),
		"plane_fallback_rejected": plane_fallback_rejected,
		"returned_to_material": returned_to_material,
		"replacement_surface_target_id": String(second_center_hit.get(
			"surface_target_id",
			StringName()
		)),
		"outward_shift_meters": outward_shift,
		"minimum_outward_shift_meters": MIN_OUTWARD_SHIFT_METERS,
	}
	_report["plane_only_witness"] = {
		"local_position": plane_only_local,
		"material_query_valid": bool(strict_material_miss.get("valid", false)),
		"hybrid_query_valid": bool(hybrid_plane_hit.get("valid", false)),
		"hybrid_target_kind": String(hybrid_plane_hit.get(
			"target_kind",
			StringName()
		)),
	}
	_finish(ui, controller)


func _project_points(
	workspace: Node3D,
	local_points: PackedVector3Array
) -> PackedVector2Array:
	var projected := PackedVector2Array()
	for local_point: Vector3 in local_points:
		var projection := workspace.call(
			"project_workspace_local_to_screen",
			local_point
		) as Dictionary
		if not bool(projection.get("valid", false)):
			return PackedVector2Array()
		projected.append(projection.get("screen_position", Vector2.ZERO) as Vector2)
	return projected


func _await_stable_material_hit(
	workspace: Node3D,
	screen_position: Vector2,
	forbidden_target_id: StringName
) -> Dictionary:
	var previous_hit: Dictionary = {}
	for pair_index in range(PUBLICATION_WAIT_PAIR_LIMIT):
		await process_frame
		await physics_frame
		var hit := workspace.call(
			"resolve_material_surface_target",
			screen_position
		) as Dictionary
		var target_id := StringName(hit.get(
			"surface_target_id",
			StringName()
		))
		if (
			not bool(hit.get("valid", false))
			or StringName(hit.get("target_kind", StringName()))
			!= MATERIAL_SURFACE_KIND
			or target_id == StringName()
			or target_id == forbidden_target_id
		):
			previous_hit = {}
			continue
		if not previous_hit.is_empty() and _hits_are_stable(previous_hit, hit):
			var result := hit.duplicate(false)
			result["ok"] = true
			result["waited_process_physics_pairs"] = pair_index + 1
			return result
		previous_hit = hit
	return {
		"ok": false,
		"surface_target_id": StringName(),
		"waited_process_physics_pairs": PUBLICATION_WAIT_PAIR_LIMIT,
	}


func _hits_are_stable(first: Dictionary, second: Dictionary) -> bool:
	return (
		StringName(first.get("surface_target_id", StringName()))
		== StringName(second.get("surface_target_id", StringName()))
		and (first.get("local_position", Vector3.ZERO) as Vector3).distance_to(
			second.get("local_position", Vector3.ZERO) as Vector3
		) <= HIT_POSITION_STABILITY_METERS
		and (first.get("local_normal", Vector3.ZERO) as Vector3).normalized().dot(
			(second.get("local_normal", Vector3.ZERO) as Vector3).normalized()
		) >= HIT_NORMAL_STABILITY_DOT_MIN
	)


func _packed_points_equal(
	first: PackedVector3Array,
	second: PackedVector3Array,
	tolerance: float
) -> bool:
	if first.size() != second.size():
		return false
	for point_index in range(first.size()):
		if first[point_index].distance_to(second[point_index]) > tolerance:
			return false
	return true


func _find_body(state: Resource, body_id: StringName) -> Resource:
	if state == null or body_id == StringName():
		return null
	var bodies: Array = state.get("material_bodies") as Array
	for body_variant: Variant in bodies:
		if not body_variant is Resource:
			continue
		var body := body_variant as Resource
		if StringName(body.get("body_id")) == body_id:
			return body
	return null


func _body_count(state: Resource) -> int:
	return (state.get("material_bodies") as Array).size() if state != null else 0


func _hit_summary(hit: Dictionary) -> Dictionary:
	return {
		"ok": bool(hit.get("ok", false)),
		"target_kind": String(hit.get("target_kind", StringName())),
		"surface_target_id": String(hit.get(
			"surface_target_id",
			StringName()
		)),
		"local_position": hit.get("local_position", Vector3.ZERO),
		"local_normal": hit.get("local_normal", Vector3.ZERO),
		"waited_process_physics_pairs": int(hit.get(
			"waited_process_physics_pairs",
			0
		)),
	}


func _json_safe(value: Variant) -> Variant:
	if value is StringName:
		return String(value)
	if value is Vector2 or value is Vector3:
		return str(value)
	if value is Dictionary:
		var safe_dictionary := {}
		for key: Variant in (value as Dictionary).keys():
			safe_dictionary[String(key)] = _json_safe((value as Dictionary)[key])
		return safe_dictionary
	if value is Array:
		var safe_array: Array = []
		for entry: Variant in value as Array:
			safe_array.append(_json_safe(entry))
		return safe_array
	return value


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_errors.append(message)
	return false


func _finish(ui: CanvasLayer, controller: Node) -> void:
	_report["errors"] = _errors.duplicate()
	_report["ok"] = _errors.is_empty()
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_json_safe(_report), "\t", true, true) + "\n")
		file.close()
	if ui != null and is_instance_valid(ui):
		ui.queue_free()
	if controller != null and is_instance_valid(controller):
		controller.queue_free()
	if _errors.is_empty():
		print("FORGE_V2_GENERIC_VOLUME_SURFACE_LAYERING_VERIFY: PASS")
	else:
		for error: String in _errors:
			push_error(error)
	quit(0 if _errors.is_empty() else 1)
