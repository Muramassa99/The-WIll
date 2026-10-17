extends SceneTree

# Isolated authoring + real baked Handle + public runtime export. No player saves.
# The asymmetric chamfer survives recentering, so an X reflection is observable.
const Authoring = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const Body = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const Presenter = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")
const Adapter = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const Packet = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Roll = preload("res://runtime/forge_v2/forge_v2_path_roll.gd")
const Wip = preload("res://core/models/crafted_item_wip.gd")
const OUTPUT := "C:/WORKSPACE/test_artifacts/forge_v2_twist_export_frames_20261018.json"
const CELL_M := 0.005
const SURFACE_TOLERANCE_M := 0.00005
var checks := 0
var failures := PackedStringArray()
var evidence: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	var presenter := Presenter.new()
	root.add_child(presenter)
	for degrees: float in [0.0, 90.0]:
		await _verify_export(presenter, degrees)
	_verify_explicit_surface(presenter)
	presenter.free()
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"evidence": evidence, "duration_ms": float(Time.get_ticks_usec() - started) / 1000.0}
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	var output := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("Forge V2 twist export frames: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-0.030, -0.020), Vector2(0.035, -0.020),
		Vector2(0.035, -0.010), Vector2(0.010, 0.030), Vector2(-0.030, 0.030)])


func _fixture(degrees: float) -> Dictionary:
	var state := Authoring.new()
	state.reset_new_draft("Asymmetric twist export verification")
	state.set_active_tool_id(Authoring.TOOL_HANDLES)
	state.set_active_profile_id(Profiles.PROFILE_HANDLE_BUILDER)
	state.set_active_handle_path_mode_id(Authoring.HANDLE_PATH_MODE_THREE_POINT_SPLINE)
	for point: Vector3 in [Vector3(-0.15, 0, 0), Vector3.ZERO, Vector3(0.15, 0, 0)]:
		if state.append_spline_line_point(point, Vector3.UP) < 0:
			return {}
	state.set_spline_line_point_roll_degrees(1, degrees)
	if not state.generate_profile_extrusion_from_spline():
		return {}
	var body := state.get_selected_material_body() as Resource
	if body == null:
		return {}
	body.set("profile_polygon_2d_meters", _polygon())
	body.set("profile_contact_direction_2d", Vector2(0.0, -1.0))
	body.set("profile_rotation_bias_degrees", 0.0)
	# Later placement-plane changes must not impose additional roll constraints.
	body.set("path_surface_normals", PackedVector3Array([Vector3.UP, Vector3.BACK, Vector3.DOWN]))
	body.call("normalize")
	if state.commit_material_body_as_layer(body.get("body_id")) == null:
		return {}
	var wip := Wip.new()
	wip.wip_id = StringName("verify_twist_export_%d" % int(degrees))
	wip.forge_builder_path_id = Wip.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = Wip.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.forge_v2_authoring_state = state
	return {"body": body, "wip": wip}


func _packet(presenter: Node3D, body: Resource) -> Dictionary:
	var packet: Dictionary = {}
	for _frame in range(120):
		packet = presenter.call("_resolve_authoritative_protected_handle_packet", body)
		if not bool(packet.get("pending", false)):
			return packet
		await process_frame
	return packet


func _verify_export(presenter: Node3D, degrees: float) -> void:
	var label := "middle_%d" % int(degrees)
	var fixture := _fixture(degrees)
	if not _check(not fixture.is_empty(), label + " creates a committed authored Handle"):
		return
	var body: Resource = fixture.body
	var packet := await _packet(presenter, body)
	if not _check(bool(packet.get("ok", false)), label + " actual Handle bake: " + str(packet.get("reason", ""))):
		return
	var signature := Packet.build_body_signature(body)
	var old_signature := _schema_two_signature(body)
	_check(signature.begins_with("handle_exact_v3:"), label + " uses new geometry signature schema")
	_check(signature != old_signature, label + " old geometry signature cannot reuse new sweep")
	var stale := packet.duplicate(true)
	stale["primary_grip_handle_body_signature"] = old_signature
	var rejected: Dictionary = Adapter.build_runtime_contract(fixture.wip, stale, CELL_M)
	_check(not bool(rejected.get("valid", false)) and String(rejected.get("error", "")) ==
		"forge_v2_primary_handle_exact_mesh_signature_mismatch", label + " public export rejects stale v2 Handle packet")
	var result: Dictionary = Adapter.build_runtime_contract(fixture.wip, packet, CELL_M)
	if not _check(bool(result.get("valid", false)), label + " public runtime export: " + str(result.get("error", ""))):
		return
	var profile: BakedProfile = result.baked_profile
	var contact := profile.primary_grip_contact_position * CELL_M
	# Independent straight-path oracle: initial surface UP makes native Handle
	# profile +X point BACK and +Y point UP. The symmetric 0/peak/0 smooth roll
	# is peak * (1 - (x / half_length)^2), with no placement-normal roll added.
	var expected_degrees := degrees * (1.0 - pow(contact.x / 0.15, 2.0))
	var axis_x := Vector3.BACK.rotated(Vector3.RIGHT, -deg_to_rad(expected_degrees))
	var axis_y := Vector3.UP.rotated(Vector3.RIGHT, -deg_to_rad(expected_degrees))
	var authored_samples := _independent_profile_samples(_polygon())
	var sample_mean := Vector2.ZERO
	for sample: Vector2 in authored_samples:
		sample_mean += sample / float(authored_samples.size())
	var expected := PackedVector3Array()
	for sample: Vector2 in authored_samples:
		var centered := sample - sample_mean
		expected.append(contact + axis_x * centered.x + axis_y * centered.y)
	var actual := PackedVector3Array()
	for offset: Vector2 in profile.primary_grip_profile_offsets_minor_meters:
		actual.append(contact + profile.primary_grip_minor_axis_a.normalized() * offset.x
			+ profile.primary_grip_minor_axis_b.normalized() * offset.y)
	_check(actual.size() == expected.size() and actual.size() > 20, label + " exported shell retains asymmetric sample set")
	var shell_error := maxf(_point_set_error(actual, expected), _point_set_error(expected, actual))
	_check(shell_error <= SURFACE_TOLERANCE_M, label + " public shell matches independent physical frame; error_m=" + str(shell_error))
	# Deliberately mirror the expected shell to prove this fixture can detect
	# precisely the missing/doubled X reflection being guarded against.
	var mirrored := PackedVector3Array()
	for sample: Vector2 in authored_samples:
		var centered := sample - sample_mean
		mirrored.append(contact - axis_x * centered.x + axis_y * centered.y)
	_check(_point_set_error(mirrored, expected) > 0.003, label + " asymmetric oracle distinguishes an erroneous reflection")
	var section := _section(packet.primary_grip_handle_vertices, packet.primary_grip_handle_indices, contact.x, axis_x, axis_y)
	if _check(section.size() >= 3, label + " actual baked Handle has a closed transverse section"):
		var boundary_error := maxf(_boundary_error(section, _polygon()), _boundary_error(_polygon(), section))
		_check(boundary_error <= SURFACE_TOLERANCE_M, label + " baked material matches independent source profile; error_m=" + str(boundary_error))
		var outside := 0
		for point: Vector3 in actual:
			var lateral := point - Vector3(contact.x, 0, 0)
			if not Geometry2D.is_point_in_polygon(Vector2(lateral.dot(axis_x), lateral.dot(axis_y)), section):
				outside += 1
		_check(outside == 0, label + " every exported shell sample lies within the actual baked Handle")
		evidence[label] = {"shell_error_m": shell_error, "material_boundary_error_m": boundary_error,
			"shell_samples": actual.size(), "outside_samples": outside, "contact_m": str(contact),
			"signature": signature, "rejected_old_signature": old_signature}


func _independent_profile_samples(polygon: PackedVector2Array) -> PackedVector2Array:
	var samples := PackedVector2Array()
	# Exact authored bounds are 65 x 50 mm; 13 x 10 samples need no decimation.
	for column in range(13):
		for row in range(10):
			var point := Vector2(-0.030 + (column + 0.5) * CELL_M, -0.020 + (row + 0.5) * CELL_M)
			if Geometry2D.is_point_in_polygon(point, polygon) and _edge_distance(point, polygon) > 0.000001:
				samples.append(point)
	return samples


func _section(vertices: PackedVector3Array, indices: PackedInt32Array, x: float, axis_x: Vector3, axis_y: Vector3) -> PackedVector2Array:
	var hits := PackedVector2Array()
	for triangle in range(0, indices.size(), 3):
		for edge in range(3):
			var a := vertices[indices[triangle + edge]]
			var b := vertices[indices[triangle + (edge + 1) % 3]]
			if absf(a.x - x) < 0.0000001:
				hits.append(Vector2(a.dot(axis_x), a.dot(axis_y)))
			if (a.x - x) * (b.x - x) < 0.0:
				var hit := a.lerp(b, (x - a.x) / (b.x - a.x))
				hits.append(Vector2(hit.dot(axis_x), hit.dot(axis_y)))
	return Geometry2D.convex_hull(hits) if hits.size() >= 3 else PackedVector2Array()


func _boundary_error(points: PackedVector2Array, polygon: PackedVector2Array) -> float:
	var maximum := 0.0
	for point: Vector2 in points:
		maximum = maxf(maximum, _edge_distance(point, polygon))
	return maximum


func _edge_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	var nearest := INF
	for i in range(polygon.size()):
		nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(
			point, polygon[i], polygon[(i + 1) % polygon.size()])))
	return nearest


func _point_set_error(source: PackedVector3Array, target: PackedVector3Array) -> float:
	if source.is_empty() or target.is_empty():
		return INF
	var maximum := 0.0
	for point: Vector3 in source:
		var nearest := INF
		for other: Vector3 in target:
			nearest = minf(nearest, point.distance_to(other))
		maximum = maxf(maximum, nearest)
	return maximum


func _schema_two_signature(body: Resource) -> String:
	# Frozen pre-fix schema. This must not call the current signature builder.
	var geometry := ["handle_exact_signature_schema_2", String(body.get("body_kind")),
		String(body.get("shape_kind")), String(body.get("profile_id")),
		_quantized(body.get("path_points"), 0.0000001),
		_quantized(body.get("path_surface_normals"), 0.0000001),
		_quantized(body.get("path_contact_directions"), 0.0000001),
		_quantized(body.get("profile_polygon_2d_meters"), 0.0000001),
		_quantized(body.get("profile_anchor_2d_meters"), 0.0000001),
		_quantized(body.get("profile_contact_direction_2d"), 0.0000001),
		_quantized(body.get("profile_contact_point_relative_2d_meters"), 0.0000001),
		int(round(float(body.get("profile_contact_distance_meters")) / 0.0000001)),
		int(round(float(body.get("radius_meters")) / 0.0000001)),
		int(body.get("profile_runtime_schema_version")),
		int(round(float(body.get("profile_rotation_bias_degrees")) / 0.000001)),
		int(round(float(body.get("profile_twist_degrees_per_meter")) / 0.000001))]
	var rolls: PackedFloat64Array = body.get("path_roll_degrees")
	var quantized := PackedInt64Array()
	var any_roll := false
	for value: float in rolls:
		var integer := int(round(value / 0.000001))
		quantized.append(integer)
		any_roll = any_roll or integer != 0
	if any_roll:
		geometry.append("unwrapped_path_roll_v1")
		geometry.append(quantized)
	return "handle_exact_v2:%s" % var_to_bytes(geometry).hex_encode().sha256_text()


func _quantized(value: Variant, step: float) -> PackedInt64Array:
	var result := PackedInt64Array()
	var values: Array = [value] if value is Vector2 or value is Vector3 else Array(value)
	for vector: Variant in values:
		result.append(int(round(float(vector.x) / step)))
		result.append(int(round(float(vector.y) / step)))
		if vector is Vector3:
			result.append(int(round(float(vector.z) / step)))
	return result


func _verify_explicit_surface(presenter: Node3D) -> void:
	for kind: StringName in [Body.BODY_KIND_VOLUME_STROKE, Body.BODY_KIND_DETAILING_BRUSH]:
		var body := Body.new()
		body.body_kind = kind
		body.shape_kind = Body.SHAPE_KIND_PROFILE_PATH
		body.path_points = PackedVector3Array([Vector3.ZERO, Vector3(0.08, 0, 0), Vector3(0.16, 0, 0)])
		body.path_surface_normals = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
		body.path_contact_directions = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])
		body.profile_polygon_2d_meters = PackedVector2Array([Vector2(-0.02, -0.01),
			Vector2(0, -0.02), Vector2(0.03, -0.01), Vector2(0.02, 0.02), Vector2(-0.02, 0.02)])
		body.profile_contact_point_relative_2d_meters = Vector2(0, -0.02)
		body.profile_contact_direction_2d = Vector2.DOWN
		body.profile_contact_distance_meters = 0.02
		body.profile_runtime_schema_version = 1
		body.normalize()
		_check(not Roll.uses_shared_sweep(body), String(kind) + " remains outside free spline frame authority")
		_check(body.uses_explicit_surface_contact_authority(), String(kind) + " retains explicit surface contact authority")
		var mesh := presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
		if not _check(mesh != null and mesh.get_surface_count() > 0, String(kind) + " generates a live explicit-surface mesh"):
			continue
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var max_error := 0.0
		for point: Vector3 in body.path_points:
			var desired := point + Vector3.FORWARD * 0.02
			var nearest := INF
			for vertex: Vector3 in vertices:
				nearest = minf(nearest, desired.distance_to(vertex))
			max_error = maxf(max_error, nearest)
		_check(max_error <= 0.000001, String(kind) + " authored contact vertex remains on explicit surface ray")


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
	return condition
