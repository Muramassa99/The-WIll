extends SceneTree

const State = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const Body = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const Layer = preload("res://runtime/forge_v2/forge_v2_layer_data.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const Resolver = preload("res://runtime/forge_v2/forge_v2_material_volume_resolver.gd")
const REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_bounded_remove_state_20261018.json"

var checks: Array[Dictionary] = []
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_verify_detail(false)
	_verify_detail(true)
	_verify_add_guards()
	_verify_promotion()
	_verify_cut_only_tail()
	_verify_empty_prefix()
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"passed": checks.size() - failures, "failed": failures, "checks": checks}, "\t"))
	print("Bounded Remove state: %d passed, %d failed" % [checks.size() - failures, failures])
	quit(0 if failures == 0 else 1)

func _fresh() -> Resource:
	var state: Resource = State.new()
	state.call("reset_new_draft", "Bounded Remove logical verification")
	return state

func _add(state: Resource, y: float = 0.0) -> Resource:
	state.call("set_active_tool_id", State.TOOL_SPLINE_LINE)
	state.call("set_active_primitive_id", State.DEFAULT_ACTIVE_PRIMITIVE_ID)
	state.set("active_material_variant_id", &"mat_iron_gray")
	state.set("active_operation_mode", State.OPERATION_ADD_MATERIAL)
	state.set("placement_policy", State.PLACEMENT_REPLACE_EXISTING)
	state.call("set_brush_radius_meters", 0.0125)
	for point: Vector3 in [Vector3(-0.04, y, 0), Vector3(0, y, 0), Vector3(0.04, y, 0)]:
		state.call("append_spline_line_point", point, Vector3.UP)
	_check(bool(state.call("generate_spline_line_csg_noodle")), "Add fixture generates")
	var body: Resource = state.call("get_selected_material_body")
	_check(state.call("commit_pending_material_bodies_as_layer") != null, "Add fixture commits")
	return body

func _detail(state: Resource, saved_profile: bool = false, y: float = 0.008) -> Resource:
	state.call("set_active_tool_id", State.TOOL_DETAILING_BRUSH)
	state.call("set_active_primitive_id", State.DEFAULT_ACTIVE_PRIMITIVE_ID)
	state.set("active_material_variant_id", &"mat_cutter_hint_only")
	state.set("active_operation_mode", State.OPERATION_REMOVE_MATERIAL)
	state.set("placement_policy", State.PLACEMENT_EMPTY_ONLY)
	state.call("set_brush_radius_meters", 0.0075)
	if saved_profile:
		var polygon := PackedVector2Array([
			Vector2(-0.015, -0.015), Vector2(0.015, -0.015),
			Vector2(0.015, 0.015), Vector2(-0.015, 0.015),
		])
		_check(bool(state.call("select_active_saved_basic_profile", {
			"profile_id": &"remove_profile", "id": &"remove_profile",
			"label": "Remove profile", "family": Profiles.PROFILE_FAMILY_BASIC,
			"control_points_2d_meters": polygon, "base_polygon_2d_meters": polygon,
			"polygon_2d_meters": polygon, "base_anchor_2d_meters": Vector2.ZERO,
			"anchor_x_meters": 0.0, "anchor_y_meters": 0.0, "rotation_degrees": 0.0,
		})), "Saved cutter profile selects")
	var points := PackedVector3Array([Vector3(-0.02, y, 0), Vector3(0, y, 0), Vector3(0.02, y, 0)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var contacts := PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
	_check(bool(state.call("replace_detailing_brush_path_solution", points, normals,
		&"target_material_surface", &"remove_fixture_surface", points, normals,
		PackedInt32Array([0, 1, 2]), [true, true], [&"none", &"none"], true,
		&"none", 0, contacts, contacts)), "Detail solution installs")
	_check(bool(state.call("generate_detailing_brush")), "Remove Detail generates")
	var body: Resource = state.call("get_selected_material_body")
	_check(state.call("commit_pending_material_bodies_as_layer") != null, "Remove Detail commits after existing Add")
	return body

func _verify_detail(saved_profile: bool) -> void:
	var state := _fresh()
	var original := _add(state)
	var before := _units(state)
	# The saved profile is offset by its explicit contact anchor. Keep this
	# accounting fixture inside the base rather than at a sampled tangency.
	var cutter := _detail(state, saved_profile, 0.0 if saved_profile else 0.008)
	_check((state.get("forge_layers") as Array).size() == 2, "Cut consumes one ordinary history slot")
	_check(int(state.call("get_pending_material_body_count")) == 0, "Applied cut has no stranded pending body")
	_check(bool((state.call("get_bounded_presentation_descriptor") as Dictionary)["bounded_history_enabled"]), "Removal stays on bounded history")
	_check(_units(state) < before, "Removal decreases actual occupied material")
	_check(StringName(state.call("_get_bounded_history_material_id")) == &"mat_iron_gray", "Cutter hint never replaces solid material identity")
	_check(not bool(state.call("is_retained_spline_body_editable", cutter.get("body_id"))), "Cutter is not an E selection source")
	_check(bool(state.call("is_retained_spline_body_editable", original.get("body_id"))), "Earlier Add remains editable")
	var layer: Resource = (state.get("forge_layers") as Array).back()
	_check(bool(layer.call("is_bounded_history_eligible", &"mat_iron_gray")), "Cut layer validates signed ordinary-material accounting")
	_check(not bool(layer.call("is_bounded_add_history_eligible", &"mat_iron_gray")), "Add-only contract does not misidentify cut")
	var invalid := layer.duplicate(true)
	invalid.set("ledger_delta", {&"mat_iron_gray": {"rough_material_centi_units": 1, "rough_volume_cell_equivalents": 1.0}})
	_check(not bool(invalid.call("is_bounded_history_eligible", &"mat_iron_gray")), "A cut cannot add occupied material")
	invalid.set("ledger_delta", {&"mat_foreign": {"rough_material_centi_units": -1, "rough_volume_cell_equivalents": -1.0}})
	_check(not bool(invalid.call("is_bounded_history_eligible", &"mat_iron_gray")), "Cut cannot escape the ordinary material lane")
	var after := _units(state)
	_check(bool(state.call("undo_latest_layer")) and _units(state) == before, "Undo restores material removed by cut")
	_check(bool(state.call("redo_latest_layer")) and _units(state) == after, "Redo restores the cut delta")
	var replacement := original.duplicate(true)
	var moved: PackedVector3Array = replacement.get("path_points")
	moved[1] += Vector3(0.0, 0.003, 0.0)
	replacement.set("path_points", moved)
	var candidate: Dictionary = state.call("build_retained_spline_replacement_candidate", original.get("body_id"), replacement, &"apply")
	_check(bool(candidate.get("ok", false)), "E replacement accounts for a later cut")
	if bool(candidate.get("ok", false)):
		_check(bool(state.call("accept_retained_spline_change_candidate", candidate)), "E candidate installs without losing cut")
		var last: Resource = (state.get("forge_layers") as Array).back()
		_check(last.get("layer_id") == layer.get("layer_id") and last.get("operation_type") == Layer.OPERATION_SUBTRACT_VOID, "E replay preserves cut identity and chronology")
		_check(bool(last.call("is_bounded_history_eligible", &"mat_iron_gray")), "Recomputed cut metadata keeps stable owner IDs")
	_verify_occupancy(state, "Edited Add then cut")

func _verify_add_guards() -> void:
	for foreign_material: bool in [false, true]:
		var state := _fresh()
		_add(state)
		state.set("active_material_variant_id", &"mat_other" if foreign_material else &"mat_iron_gray")
		state.set("placement_policy", State.PLACEMENT_REPLACE_EXISTING if foreign_material else State.PLACEMENT_EMPTY_ONLY)
		state.call("append_point_material_body", Vector3(0.0, 0.03, 0.0), 0.01, 1.0, Vector3.UP)
		var layers_before: Array = (state.get("forge_layers") as Array).duplicate()
		_check(state.call("commit_pending_material_bodies_as_layer") == null, "Unsupported Add material/policy still rejects")
		_check(state.get("forge_layers") == layers_before and int(state.call("get_pending_material_body_count")) == 1, "Rejected Add preserves prior layers and pending work")

func _verify_promotion() -> void:
	var state := _fresh()
	_add(state)
	_detail(state)
	for index in range(4):
		_add(state, 0.025 + index * 0.025)
	_check(bool(state.call("has_pending_bounded_history_promotion")), "Sixth operation stages bounded promotion")
	_ack_logical_promotion(state)
	_check(StringName(state.call("_get_bounded_history_material_id")) == &"mat_iron_gray", "First promotion retains ordinary solid identity")
	_add(state, 0.14)
	_ack_logical_promotion(state)
	var checkpoint: Resource = state.get("bounded_history_checkpoint")
	_check(checkpoint.get("material_variant_id") == &"mat_iron_gray", "Promoting Remove does not turn S0 material into VOID")
	_check(int(checkpoint.get("accumulated_operation_count")) == 2, "Cut ages into S0 as one operation")
	_check((state.get("forge_layers") as Array).size() == 5, "Add/Remove retains exactly five ordinary operations")
	var summary: Dictionary = checkpoint.call("get_material_ledger_summary")
	var removed: Array = summary.get("removed_material_records", [])
	_check(removed.size() == 1 and not (removed[0] as Dictionary).has("layer_id"), "Promoted cut accounting has no expired layer identity")
	var descriptor: Dictionary = state.call("get_bounded_presentation_descriptor")
	_check(descriptor["material_variant_id"] == &"mat_iron_gray", "Presenter receives solid material independently of last operation")

func _verify_cut_only_tail() -> void:
	var state := _fresh()
	_add(state)
	for index in range(5):
		_detail(state, false, 0.15 + index * 0.02)
	var transition: Dictionary = state.call("get_bounded_history_transition")
	_check(transition["material_variant_id"] == &"mat_iron_gray", "Promotion transition retains the only Add's solid identity")
	_ack_logical_promotion(state)
	_check((state.call("get_bounded_presentation_descriptor") as Dictionary)["material_variant_id"] == &"mat_iron_gray", "An all-cut tail retains its checkpoint solid identity")

func _verify_empty_prefix() -> void:
	var state := _fresh()
	for index in range(6):
		_detail(state, false, 0.15 + index * 0.02)
	_ack_logical_promotion(state)
	var checkpoint: Resource = state.get("bounded_history_checkpoint")
	_check(checkpoint.get("material_variant_id") == StringName(), "No-op cut prefix has no invented solid material")
	var resolver: RefCounted = Resolver.new()
	var restored: Dictionary = resolver.call("restore_incremental_committed_cache_from_checkpoint", checkpoint.call("to_native_packet"), [])
	_check(bool(restored.get("ok", false)), "Explicit empty cut checkpoint restores accounting")
	_add(state)
	_ack_logical_promotion(state)
	_check(StringName(state.call("_get_bounded_history_material_id")) == &"mat_iron_gray", "First Add establishes identity after empty cut prefix")

func _ack_logical_promotion(state: Resource) -> void:
	# This fixture acknowledges the logical contract only. Root's native suite
	# proves the actual Boolean result and its publication before real ACK.
	var transition: Dictionary = state.call("get_bounded_history_transition")
	_check(bool(state.call("acknowledge_bounded_history_transition", int(transition["revision"]), {
		"ok": true, "history_window_enabled": true, "last_mode": &"promotion_append",
		"checkpoint_operation_count": int(transition["expected_checkpoint_operation_count"]),
		"promotion_boolean_delta": 0, "promotion_export_delta": 0,
	})), "Logical promotion ACK accepts bounded occupancy and accounting")

func _units(state: Resource) -> int:
	return int((state.call("get_material_ledger_summary") as Dictionary).get("total_rough_material_centi_units", -1))

func _verify_occupancy(state: Resource, label: String) -> void:
	var resolver: RefCounted = Resolver.new()
	var expected: Dictionary = resolver.call("build_usage_summary", state.call("_collect_committed_active_user_material_bodies"))
	_check(_units(state) == int(expected["total_rough_material_centi_units"]), "%s matches independent occupancy replay" % label)

func _check(passed: bool, label: String) -> void:
	checks.append({"passed": passed, "label": label})
	if not passed:
		failures += 1
		push_error(label)
