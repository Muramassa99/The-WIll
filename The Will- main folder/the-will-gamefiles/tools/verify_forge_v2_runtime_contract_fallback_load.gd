extends SceneTree

const CraftingBenchV2Scene = preload(
	"res://scenes/world/crafting_bench_v2.tscn"
)
const CraftedItemWIPScript = preload(
	"res://core/models/crafted_item_wip.gd"
)
const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2WipCompatibilityAdapterScript = preload(
	"res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd"
)
const PrimaryGripHandleMeshPacketScript = preload(
	"res://core/resolvers/primary_grip_handle_mesh_packet.gd"
)
const ForgeV2KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_runtime_contract_fallback_load.json"
)
const READINESS_FRAME_LIMIT := 180
var handle_points := PackedVector3Array([
	Vector3(-0.24, 0.0, 0.0),
	Vector3.ZERO,
	Vector3(0.24, 0.0, 0.0),
])

var _checks: Dictionary = {}
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var fixture := _build_loaded_wip_fixture()
	if not bool(fixture.get("ok", false)):
		_finish_setup_failure(String(fixture.get("error", "fixture failed")))
		return

	var bench := CraftingBenchV2Scene.instantiate() as Node3D
	if bench == null:
		_finish_setup_failure("production CraftingBenchV2 scene did not instantiate")
		return
	var ui := bench.get_node_or_null("CraftingBenchUIV2") as CanvasLayer
	if ui == null:
		bench.queue_free()
		_finish_setup_failure("production CraftingBenchV2 UI is missing")
		return
	_configure_isolated_ui_state(ui)
	root.add_child(bench)
	await _settle_frame_pairs(2)
	bench.call("interact", null)
	await _settle_frame_pairs(3)

	var controller := bench.get_node_or_null("Stage1V2Controller") as Node
	var workspace := ui.get("workspace_preview") as Node3D
	var presenter := (
		workspace.get("volume_preview_presenter") as Node3D
		if workspace != null
		else null
	)
	if controller == null or presenter == null:
		bench.queue_free()
		_finish_setup_failure("production controller/presenter ownership is incomplete")
		return

	var source_wip := fixture.get("wip", null) as CraftedItemWIP
	var loaded := bool(controller.call("load_saved_wip", source_wip))
	var fallback := await _await_disabled_fallback(presenter)
	var state := controller.call("get_active_authoring_state") as Resource
	_record_check("production_wip_loaded_into_disabled_fallback", (
		loaded
		and state != null
		and bool(fallback.get("ready", false))
	), {
		"loaded": loaded,
		"native": fallback.get("native", {}),
		"csg": fallback.get("csg", {}),
	})

	var provider := (
		state.get("_runtime_contract_mesh_export_provider") as Callable
		if state != null
		else Callable()
	)
	var provider_owner := provider.get_object() if provider.is_valid() else null
	_record_check("production_presenter_owns_runtime_export_provider", (
		provider.is_valid() and provider_owner == presenter
	), {
		"provider_valid": provider.is_valid(),
		"provider_owner_is_production_presenter": provider_owner == presenter,
	})

	var packet := (
		state.call("request_runtime_contract_mesh_export") as Dictionary
		if state != null
		else {}
	)
	var packet_summary := _packet_summary(packet)
	var packet_handle_signature := String(packet.get(
		"primary_grip_handle_body_signature",
		""
	))
	var packet_has_contract_meshes := (
		bool(packet.get("ok", false))
		and _packet_array_is_indexed_mesh(packet, "vertices", "indices")
		and _packet_array_is_indexed_mesh(
			packet,
			"primary_grip_handle_vertices",
			"primary_grip_handle_indices"
		)
		and StringName(packet.get("primary_grip_handle_mesh_source"))
		== PrimaryGripHandleMeshPacketScript.SOURCE
		and not packet_handle_signature.is_empty()
		and _final_mesh_includes_ordinary_extension(packet)
	)
	_record_check("fallback_export_has_final_and_exact_handle_meshes", (
		packet_has_contract_meshes
	), packet_summary)

	var contract_wip := _build_wip_from_state(
		state,
		&"verify_forge_v2_fallback_contract"
	)
	var contract := ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
		contract_wip,
		packet
	)
	var profile := contract.get("baked_profile", null) as BakedProfile
	var stage2 := contract.get("stage2_item_state", null) as Resource
	var contract_valid := (
		bool(contract.get("valid", false))
		and profile != null
		and profile.primary_grip_valid
		and profile.validation_error.is_empty()
		and _stage2_has_final_and_handle_meshes(
			stage2,
			packet_handle_signature
		)
	)
	var stage2_contract_summary := _stage2_handle_contract_summary(
		stage2,
		packet_handle_signature
	)
	_record_check("fallback_packet_builds_valid_runtime_contract", contract_valid, {
		"contract_valid": bool(contract.get("valid", false)),
		"contract_error": String(contract.get("error", "")),
		"profile_valid": profile.primary_grip_valid if profile != null else false,
		"profile_error": profile.validation_error if profile != null else "missing",
		"stage2_handle_contract": stage2_contract_summary,
	})

	var production_wip := controller.call(
		"build_crafted_item_wip_for_save"
	) as CraftedItemWIP
	var production_profile := (
		production_wip.latest_baked_profile_snapshot
		if production_wip != null
		else null
	)
	var production_contract_valid := (
		production_wip != null
		and production_profile != null
		and production_profile.primary_grip_valid
		and production_profile.validation_error.is_empty()
		and _stage2_has_final_and_handle_meshes(
			production_wip.stage2_item_state,
			packet_handle_signature
		)
	)
	_record_check("production_save_builder_retains_valid_contract", (
		production_contract_valid
	), {
		"wip_created": production_wip != null,
		"profile_created": production_profile != null,
		"profile_valid": (
			production_profile.primary_grip_valid
			if production_profile != null
			else false
		),
		"profile_error": (
			production_profile.validation_error
			if production_profile != null
			else "missing"
		),
		"stage2_handle_contract": (
			_stage2_handle_contract_summary(
				production_wip.stage2_item_state,
				packet_handle_signature
			)
			if production_wip != null
			else {}
		),
	})

	var report := {
		"schema": "forge_v2_runtime_contract_fallback_load",
		"schema_version": 1,
		"ok": _failures.is_empty(),
		"fixture": {
			"production_bench_scene": true,
			"loaded_body_count": int(fixture.get("body_count", 0)),
			"loaded_materials": fixture.get("materials", []),
			"fallback_trigger": "valid mixed-material committed tail",
		},
		"checks": _checks,
		"provider_packet": packet_summary,
		"failures": _failures,
	}
	_write_report(report)
	bench.queue_free()
	await process_frame
	if not _failures.is_empty():
		push_error(
			"Forge V2 fallback-load runtime contract failed: %s"
			% "; ".join(_failures)
		)
	quit(0 if _failures.is_empty() else 1)


func _build_loaded_wip_fixture() -> Dictionary:
	var profile_entries: Array[Dictionary] = (
		ForgeV2ProfileShapeLibraryScript.build_handle_profile_entries()
	)
	if profile_entries.is_empty():
		return {"ok": false, "error": "no Handle profile is available"}
	var profile_id := StringName(profile_entries[0].get("id", StringName()))
	if profile_id == StringName():
		return {"ok": false, "error": "default Handle profile id is empty"}

	var state := ForgeV2AuthoringStateScript.new() as Resource
	state.call("reset_new_draft", "Fallback Runtime Contract Fixture")
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	state.call("set_active_profile_id", profile_id)
	for point: Vector3 in handle_points:
		if int(state.call("append_spline_line_point", point, Vector3.UP)) < 0:
			return {"ok": false, "error": "Handle control point was rejected"}
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		return {"ok": false, "error": "Handle extrusion was not generated"}
	var handle := state.call("get_selected_material_body") as Resource
	if (
		handle == null
		or StringName(handle.get("body_kind"))
		!= ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
	):
		return {"ok": false, "error": "generated Handle lost semantic authority"}
	if state.call(
		"commit_material_body_as_layer",
		StringName(handle.get("body_id"))
	) == null:
		return {"ok": false, "error": "Handle did not commit"}

	var ordinary_a := _append_committed_ordinary_body(
		state,
		&"mat_iron_gray",
		Vector3(0.0, -0.07, 0.0),
		Vector3(0.0, 0.07, 0.0)
	)
	if ordinary_a == null:
		return {"ok": false, "error": "iron ordinary body did not commit"}
	# Model a persisted draft that already left the bounded single-material lane.
	# Mixed-material authoring remains valid through the production full-CSG lane.
	state.set("bounded_history_suspended_reason", &"mixed_material_fallback")
	var ordinary_b := _append_committed_ordinary_body(
		state,
		&"mat_copper_gray",
		Vector3(0.0, 0.0, -0.07),
		Vector3(0.0, 0.0, 0.07)
	)
	if ordinary_b == null:
		return {"ok": false, "error": "copper ordinary body did not commit"}
	state.call("normalize")
	var body_count := int(state.call("get_material_body_count"))
	if body_count != 3:
		return {
			"ok": false,
			"error": "fixture requires exactly three committed bodies",
		}
	var wip := _build_wip_from_state(
		state,
		&"verify_forge_v2_fallback_loaded_wip"
	)
	return {
		"ok": true,
		"wip": wip,
		"body_count": body_count,
		"materials": ["mat_iron_gray", "mat_copper_gray"],
	}


func _append_committed_ordinary_body(
	state: Resource,
	material_id: StringName,
	start: Vector3,
	endpoint: Vector3
) -> Resource:
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_VOLUME_STROKE)
	state.call("set_active_material_variant_id", material_id)
	var body := state.call(
		"append_point_material_body",
		start,
		0.04,
		1.0,
		Vector3.UP,
		Vector3.ZERO
	) as Resource
	if body == null:
		return null
	var body_id := StringName(body.get("body_id"))
	if not bool(state.call(
		"append_point_to_material_body",
		body_id,
		endpoint,
		0.0,
		true,
		Vector3.UP,
		Vector3.ZERO
	)):
		return null
	if state.call("commit_material_body_as_layer", body_id) == null:
		return null
	return body


func _build_wip_from_state(
	state: Resource,
	wip_id: StringName
) -> CraftedItemWIP:
	var wip := CraftedItemWIPScript.new() as CraftedItemWIP
	wip.wip_id = wip_id
	wip.forge_project_name = "Forge V2 Fallback Runtime Contract Verification"
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_builder_path_id = CraftedItemWIPScript.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.layers = []
	wip.forge_v2_authoring_state = (
		state.duplicate(true) as Resource if state != null else null
	)
	wip.ensure_combat_animation_station_state()
	return wip


func _await_disabled_fallback(presenter: Node3D) -> Dictionary:
	var native: Dictionary = {}
	var csg: Dictionary = {}
	for _frame_index in range(READINESS_FRAME_LIMIT):
		await process_frame
		await physics_frame
		native = presenter.call(
			"get_native_static_sync_diagnostics"
		) as Dictionary
		csg = presenter.call("get_csg_static_sync_diagnostics") as Dictionary
		if (
			String(native.get("lifecycle", "")) == "disabled_until_empty"
			and not bool(native.get("authoritative", true))
			and int(csg.get("full_rebuild_count", 0)) > 0
		):
			return {
				"ready": true,
				"native": _native_summary(native),
				"csg": _csg_summary(csg),
			}
	return {
		"ready": false,
		"native": _native_summary(native),
		"csg": _csg_summary(csg),
	}


func _packet_array_is_indexed_mesh(
	packet: Dictionary,
	vertices_key: String,
	indices_key: String
) -> bool:
	var vertices_variant: Variant = packet.get(vertices_key, null)
	var indices_variant: Variant = packet.get(indices_key, null)
	if (
		vertices_variant is not PackedVector3Array
		or indices_variant is not PackedInt32Array
	):
		return false
	var vertices := vertices_variant as PackedVector3Array
	var indices := indices_variant as PackedInt32Array
	return (
		not vertices.is_empty()
		and not indices.is_empty()
		and indices.size() % 3 == 0
	)


func _final_mesh_includes_ordinary_extension(packet: Dictionary) -> bool:
	var final_vertices: PackedVector3Array = packet.get(
		"vertices",
		PackedVector3Array()
	)
	var handle_vertices: PackedVector3Array = packet.get(
		"primary_grip_handle_vertices",
		PackedVector3Array()
	)
	if final_vertices.is_empty() or handle_vertices.is_empty():
		return false
	var final_bounds := AABB(final_vertices[0], Vector3.ZERO)
	for vertex_index in range(1, final_vertices.size()):
		final_bounds = final_bounds.expand(final_vertices[vertex_index])
	var handle_bounds := AABB(handle_vertices[0], Vector3.ZERO)
	for vertex_index in range(1, handle_vertices.size()):
		handle_bounds = handle_bounds.expand(handle_vertices[vertex_index])
	return (
		final_bounds.size.y > handle_bounds.size.y + 0.025
		or final_bounds.size.z > handle_bounds.size.z + 0.025
	)


func _stage2_has_final_and_handle_meshes(
	stage2: Resource,
	expected_signature: String
) -> bool:
	if (
		stage2 == null
		or not stage2.has_method("has_current_editable_mesh")
		or not bool(stage2.call("has_current_editable_mesh"))
	):
		return false
	var handle_mesh := stage2.get("primary_grip_handle_mesh_state") as Resource
	var handle_source := StringName(stage2.get(
		"primary_grip_handle_mesh_source"
	))
	var handle_signature := String(stage2.get(
		"primary_grip_handle_body_signature"
	))
	return (
		handle_mesh != null
		and handle_mesh.has_method("has_surface_arrays")
		and bool(handle_mesh.call("has_surface_arrays"))
		and handle_source == PrimaryGripHandleMeshPacketScript.SOURCE
		and not handle_signature.is_empty()
		and (
			expected_signature.is_empty()
			or handle_signature == expected_signature
		)
	)


func _stage2_handle_contract_summary(
	stage2: Resource,
	expected_signature: String
) -> Dictionary:
	if stage2 == null:
		return {
			"valid": false,
			"reason": "stage2_missing",
		}
	var handle_mesh := stage2.get("primary_grip_handle_mesh_state") as Resource
	var handle_source := StringName(stage2.get(
		"primary_grip_handle_mesh_source"
	))
	var handle_signature := String(stage2.get(
		"primary_grip_handle_body_signature"
	))
	return {
		"valid": _stage2_has_final_and_handle_meshes(
			stage2,
			expected_signature
		),
		"has_final_mesh": (
			stage2.has_method("has_current_editable_mesh")
			and bool(stage2.call("has_current_editable_mesh"))
		),
		"has_handle_mesh": (
			handle_mesh != null
			and handle_mesh.has_method("has_surface_arrays")
			and bool(handle_mesh.call("has_surface_arrays"))
		),
		"handle_mesh_source": String(handle_source),
		"handle_source_matches_contract": (
			handle_source == PrimaryGripHandleMeshPacketScript.SOURCE
		),
		"handle_signature": handle_signature,
		"handle_signature_nonempty": not handle_signature.is_empty(),
		"handle_signature_matches_packet": (
			not expected_signature.is_empty()
			and handle_signature == expected_signature
		),
	}


func _packet_summary(packet: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = packet.get(
		"vertices",
		PackedVector3Array()
	)
	var indices: PackedInt32Array = packet.get(
		"indices",
		PackedInt32Array()
	)
	var handle_vertices: PackedVector3Array = packet.get(
		"primary_grip_handle_vertices",
		PackedVector3Array()
	)
	var handle_indices: PackedInt32Array = packet.get(
		"primary_grip_handle_indices",
		PackedInt32Array()
	)
	var bounds := _mesh_bounds_diagnostics(vertices, handle_vertices)
	return {
		"ok": bool(packet.get("ok", false)),
		"error_code": String(packet.get("error_code", "")),
		"reason": String(packet.get("reason", "")),
		"final_vertex_count": vertices.size(),
		"final_triangle_count": indices.size() / 3,
		"handle_vertex_count": handle_vertices.size(),
		"handle_triangle_count": handle_indices.size() / 3,
		"handle_mesh_source": String(packet.get(
			"primary_grip_handle_mesh_source",
			StringName()
		)),
		"handle_body_signature": String(packet.get(
			"primary_grip_handle_body_signature",
			""
		)),
		"handle_signature_nonempty": not String(packet.get(
			"primary_grip_handle_body_signature",
			""
		)).is_empty(),
		"runtime_mesh_source": String(packet.get(
			"runtime_mesh_source",
			StringName()
		)),
		"runtime_mesh_used_native_arrays": (
			StringName(packet.get("runtime_mesh_source"))
			== &"forge_v2_native_ordinary_mesh_v1"
		),
		"runtime_mesh_used_baked_csg": (
			StringName(packet.get("runtime_mesh_source"))
			== &"forge_v2_published_csg_mesh_v1"
		),
		"bounds": bounds,
		"final_mesh_includes_ordinary_extension": (
			_final_mesh_includes_ordinary_extension(packet)
		),
		"final_union_performed": bool(packet.get(
			"final_union_performed",
			false
		)),
	}


func _mesh_bounds_diagnostics(
	final_vertices: PackedVector3Array,
	handle_vertices: PackedVector3Array
) -> Dictionary:
	var final_bounds := _bounds_for_vertices(final_vertices)
	var handle_bounds := _bounds_for_vertices(handle_vertices)
	var size_delta := final_bounds.size - handle_bounds.size
	return {
		"final_position_m": _vector3_to_array(final_bounds.position),
		"final_size_m": _vector3_to_array(final_bounds.size),
		"handle_position_m": _vector3_to_array(handle_bounds.position),
		"handle_size_m": _vector3_to_array(handle_bounds.size),
		"final_minus_handle_size_m": _vector3_to_array(size_delta),
		"expected_ordinary_yz_extension_min_m": 0.025,
		"ordinary_extension_observed": (
			size_delta.y > 0.025 or size_delta.z > 0.025
		),
	}


func _bounds_for_vertices(vertices: PackedVector3Array) -> AABB:
	if vertices.is_empty():
		return AABB()
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex_index in range(1, vertices.size()):
		bounds = bounds.expand(vertices[vertex_index])
	return bounds


func _vector3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _native_summary(diagnostics: Dictionary) -> Dictionary:
	return {
		"lifecycle": String(diagnostics.get("lifecycle", "")),
		"last_mode": String(diagnostics.get("last_mode", "")),
		"authoritative": bool(diagnostics.get("authoritative", false)),
		"publication_pending": bool(diagnostics.get("publication_pending", false)),
		"last_failure_reason": String(diagnostics.get("last_failure_reason", "")),
		"protected_handle_cache_ready": bool(diagnostics.get(
			"protected_handle_cache_ready",
			false
		)),
	}


func _csg_summary(diagnostics: Dictionary) -> Dictionary:
	return {
		"last_mode": String(diagnostics.get("last_mode", "")),
		"full_rebuild_count": int(diagnostics.get("full_rebuild_count", 0)),
		"last_fallback_reason": String(diagnostics.get(
			"last_fallback_reason",
			""
		)),
	}


func _configure_isolated_ui_state(ui: CanvasLayer) -> void:
	var profile_library := PlayerToolProfileLibraryStateScript.new() as Resource
	profile_library.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/fallback_contract_profiles.tres"
	)
	ui.set("tool_profile_library_state", profile_library)
	var keybindings := ForgeV2KeybindingStateScript.new() as Resource
	keybindings.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/fallback_contract_keybindings.json"
	)
	ui.set("keybinding_state", keybindings)


func _settle_frame_pairs(pair_count: int) -> void:
	for _pair_index in range(pair_count):
		await process_frame
		await physics_frame


func _record_check(name: String, ok: bool, evidence: Dictionary) -> void:
	var row := evidence.duplicate(true)
	row["ok"] = ok
	_checks[name] = row
	if not ok:
		_failures.append(name)


func _finish_setup_failure(message: String) -> void:
	_failures.append(message)
	_write_report({
		"schema": "forge_v2_runtime_contract_fallback_load",
		"schema_version": 1,
		"ok": false,
		"checks": _checks,
		"failures": _failures,
	})
	push_error(message)
	quit(1)


func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % RESULT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
