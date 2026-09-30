extends SceneTree

## Bounded geometry-only W3 test using the persisted W1 straight/curved assets.
## Synthetic named perpendicular/oblique planes test the adapter, not a hand pose.
## No Forge rebuild, user save, IK process, or envelope generation is performed.
const Saved = preload("res://runtime/player/grip/prepared_saved_grip_sections.gd")
const Section = preload("res://runtime/player/grip/prepared_weapon_plane_section.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const HandlePacket = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Adapter = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const CONFIG: Resource = preload("res://core/defs/characters/josie/grip_contact_config.tres")
const ROOT := &"RL_BoneRoot"
const WEAPON := &"WeaponRootOrigin"
const PHASE := &"editor_preview"
const PREFIX := "C:/WORKSPACE/test_artifacts/forge_v2_grip_target_wrapper_2026-09-28T03-59-21_"
const FIXTURES := {
	"straight": "8d6920bbf783e983499aee5c42ae59b23867475dcfacc243d691f626bae7dfa6",
	"curved": "d29b7da4df2493eec17476281f26c877e5b492b4b713304aa40a4d285134fc60",
}
const ERROR_M := 0.000005
var _checks := 0
var _failures: Array[String] = []
var _cases: Array = []
var _started: int
var _helper := Saved.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_started = Time.get_ticks_usec()
	for name: String in FIXTURES: _fixture(name)
	var report := {"schema": "prepared_saved_grip_sections_verify_v1", "checks": _checks,
		"failures": _failures, "cases": _cases, "all_passed": _failures.is_empty(),
		"duration_ms": float(Time.get_ticks_usec() - _started) / 1000.0,
		"scope": "saved_geometry_slice_adapter_not_character_or_grip_acceptance"}
	var path := "C:/WORKSPACE/test_artifacts/prepared_saved_grip_sections_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t")); output.close()
	else:
		_check(false, "write verification report")
	print("PREPARED_SAVED_GRIP_SECTIONS_VERIFY: %s (%d checks) %s" % ["PASS" if _failures.is_empty() else "FAIL", _checks, path])
	quit(0 if _failures.is_empty() else 1)


func _fixture(name: String) -> void:
	var path := PREFIX + name + "_library.tres"
	if not _check(FileAccess.get_sha256(path) == FIXTURES[name], name + ": frozen library hash"): return
	var library: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(library != null and library.get("saved_wips").size() == 1, name + ": saved W1 library loads"): return
	var wip: Resource = library.get("saved_wips")[0]
	var stage: Resource = wip.get("stage2_item_state")
	var wrapper: Resource = stage.get("primary_grip_target_wrapper")
	var packet := _packet(stage)
	if not _check(HandlePacket.validate(packet).get("valid", false), name + ": independent physical Stage2 packet"): return
	var body_result: Dictionary = Adapter.resolve_valid_handle_body(wip.get("forge_v2_authoring_state"))
	if not _check(body_result.get("valid", false), name + ": persisted authoring path available"): return
	var body: Resource = body_result.body
	var machine := Transform3D(Basis(Vector3.UP, 0.31), Vector3(0.2, 0.3, -0.1))
	var weapon := machine * Transform3D(Basis(Vector3.FORWARD, 0.42), Vector3(0.03, -0.02, 0.04))
	var context := _planes(body, weapon, machine)
	var config: Dictionary = CONFIG.get("contact_config").duplicate(true)
	var prepared := _helper.prepare(wrapper, packet, weapon, machine, context, config)
	if not _check(prepared.get("valid", false), name + ": named saved geometry preparation: " + str(prepared.get("reason", ""))): return
	var prepared_before := var_to_bytes(prepared)
	var source_before := _source_bytes(wrapper, packet, context)
	var stale: Dictionary = packet.duplicate(true)
	stale.primary_grip_handle_body_signature += ":stale"
	_check(not _helper.prepare(wrapper, stale, weapon, machine, context, config).get("valid", false), name + ": changed physical signature rejected")
	stale = packet.duplicate(true)
	stale.primary_grip_handle_vertices[0] += Vector3(0, 0.001, 0)
	_check(not _helper.prepare(wrapper, stale, weapon, machine, context, config).get("valid", false), name + ": changed physical geometry rejected")
	stale = packet.duplicate(true)
	stale.erase("primary_grip_handle_vertices_origin_id")
	_check(not _helper.prepare(wrapper, stale, weapon, machine, context, config).get("valid", false), name + ": absent source origin rejected")
	var changed := config.duplicate(true)
	changed.anatomy_signature += ":stale"
	_check(not _helper.prepare(wrapper, packet, weapon, machine, context, changed).get("valid", false), name + ": current anatomy mismatch rejected")
	changed = config.duplicate(true)
	changed.guide_inward_target_offset_m += 0.001
	_check(not _helper.prepare(wrapper, packet, weapon, machine, context, changed).get("valid", false), name + ": changed target depth rejected")
	_check(not _helper.prepare(null, packet, weapon, machine, context, config).get("valid", false), name + ": missing saved wrapper rejected")
	var broken: Dictionary = context.duplicate(true)
	broken.origin_records.pop_front()
	_check(not _helper.prepare(wrapper, packet, weapon, machine, broken, config).get("valid", false), name + ": missing root rejected")
	broken = context.duplicate(true)
	broken.digit_planes[&"thumb"].plane_to_world.origin += Vector3(0, 0.001, 0)
	_check(not _helper.prepare(wrapper, packet, weapon, machine, broken, config).get("valid", false), name + ": stale plane frame rejected")
	_check(not _helper.slice(prepared, context.station_axis_world * 0.001, ROOT).get("valid", false), name + ": axial weapon change rejected")
	_check(not _helper.slice(prepared, Vector3.ZERO, &"Anonymous").get("valid", false), name + ": anonymous translation rejected")
	_check(not _helper.slice(prepared, Vector3(INF, 0, 0), ROOT).get("valid", false), name + ": nonfinite translation rejected")
	for selection: Array in [[&""], [12], [&"unknown"], [&"middle", &"middle"], ["middle", &"middle"]]:
		var rejected := _helper.slice(prepared, Vector3.ZERO, ROOT, selection)
		_check(not rejected.get("valid", false) and rejected.get("reason", "") in [
			"invalid_selected_digit_id", "unknown_selected_digit_id", "duplicate_selected_digit_id"],
			name + ": invalid or repeated digit selection rejected: " + str(selection))
	for offset: Vector2 in [Vector2.ZERO, Vector2(0.002, -0.001), Vector2(-0.001, 0.003)]:
		# The path's overall handle station axis is local X in these saved assets.
		var shift: Vector3 = weapon.basis.y * offset.x + weapon.basis.z * offset.y
		var sampled := _helper.slice(prepared, shift, ROOT)
		var label := name + "/" + str(offset)
		if not _check(sampled.get("valid", false), label + ": translated three-surface sections: " + str(sampled.get("reason", ""))): continue
		_verify_selected_digits(prepared, shift, sampled, label)
		var moved := weapon.translated(shift)
		var origins := HandSkin.new()._registry(sampled.origin_records, PHASE)
		_check(origins.get("valid", false), label + ": every output origin resolves")
		if origins.get("valid", false):
			_check(_frame_error(machine * origins.registry.resolve_transform_to_machine(WEAPON), moved) < ERROR_M, label + ": one shared weapon frame")
		var report := {"fixture": name, "translation_m": [offset.x, offset.y], "slice_ms": sampled.slice_ms, "digits": {}}
		for digit: StringName in [&"middle", &"thumb"]:
			var result: Dictionary = sampled.digits[digit]
			var plane: Transform3D = context.digit_planes[digit].plane_to_world
			_check(result.plane_to_world == plane, label + "/" + str(digit) + ": hand plane stays fixed")
			_check(result.center == result.handle.center and result.center_policy == &"physical_handle_slice_area_centroid", label + "/" + str(digit) + ": common center is material center")
			var radius := 0.0
			var maximum_error := 0.0
			for kind: StringName in Saved.KINDS:
				var surface := _surface(wrapper, packet, kind, moved)
				var reference_helper := Section.new()
				var reference := reference_helper.slice(reference_helper.prepare(surface, plane, result.origin_id), plane)
				if not _check(reference.get("valid", false), label + "/" + str(digit) + "/" + str(kind) + ": direct translated mesh oracle"): continue
				var section: Dictionary = result[kind]
				var error := _boundary_error(section.polygon, reference.polygon)
				maximum_error = maxf(maximum_error, error)
				_check(error <= ERROR_M and section.center.distance_to(reference.center) <= ERROR_M, label + "/" + str(digit) + "/" + str(kind) + ": matches direct slicing")
				_check(section.origin_id == result.origin_id and section.source_id == WEAPON and section.resolved_world_origin_id == ROOT, label + "/" + str(digit) + "/" + str(kind) + ": explicit coordinate chain")
				_check(section.is_physical_material == (kind == &"handle"), label + "/" + str(digit) + "/" + str(kind) + ": material and targets distinct")
				for point: Vector2 in section.polygon: radius = maxf(radius, point.distance_to(result.center))
			_check(absf(radius - result.required_enclosing_radius_m) < 1.0e-10, label + "/" + str(digit) + ": radius covers all three about canonical center")
			report.digits[digit] = {"maximum_boundary_error_m": maximum_error, "radius_m": radius,
				"digit_target_centroid_offset_m": result.center.distance_to(result.digit_target.center),
				"palm_target_centroid_offset_m": result.center.distance_to(result.palm_target.center)}
		_cases.append(report)
	# A later digit can be unavailable without preventing Middle's own query.
	# Corrupt only an isolated test copy, not the frozen source or prepared input.
	var unavailable := prepared.duplicate(true)
	unavailable.digits[&"thumb"].indexed[&"handle"]["valid"] = false
	_check(_helper.slice(unavailable, Vector3.ZERO, ROOT, [&"middle"]).get("valid", false),
		name + ": Middle query never touches an unselected unavailable digit")
	_check(not _helper.slice(unavailable, Vector3.ZERO, ROOT).get("valid", false),
		name + ": all-digit query still reports the unavailable digit")
	_check(var_to_bytes(prepared) == prepared_before, name + ": queries leave frozen index unchanged")
	_check(_source_bytes(wrapper, packet, context) == source_before, name + ": sources and hand provenance unchanged")
	_check(FileAccess.get_sha256(path) == FIXTURES[name], name + ": source save untouched")


func _verify_selected_digits(prepared: Dictionary, shift: Vector3, full: Dictionary, label: String) -> void:
	var selections: Array = [[&"middle"], ["thumb"]]
	if shift == Vector3.ZERO:
		selections.append([&"thumb", &"middle"])
		selections.append([])
	for selection: Array in selections:
		var subset := _helper.slice(prepared, shift, ROOT, selection)
		var tag := label + "/selected" + str(selection)
		if not _check(subset.get("valid", false), tag + ": selected query available"): continue
		var expected: Array = prepared.digits.keys() if selection.is_empty() else []
		for value: Variant in selection: expected.append(StringName(value))
		_check(subset.digits.keys() == expected, tag + ": only requested digits in requested order")
		_check(subset.weapon_to_world == full.weapon_to_world and subset.weapon_translation_world == shift
			and subset.source_fingerprint == full.source_fingerprint, tag + ": same shared source and weapon placement")
		var registered := HandSkin.new()._registry(subset.origin_records, PHASE)
		_check(registered.get("valid", false), tag + ": selected origin chain resolves")
		_check(subset.origin_records.size() == prepared.origin_records.size() + expected.size(),
			tag + ": creates only selected numerical query origins")
		for digit: Variant in prepared.digits:
			if registered.get("valid", false):
				_check(registered.registry.has_origin(prepared.digits[digit].query_origin_id) == (digit in expected),
					tag + "/" + str(digit) + ": query origin exists only when selected")
			if digit not in expected: continue
			var partial: Dictionary = subset.digits[digit].duplicate(true)
			var complete: Dictionary = full.digits[digit].duplicate(true)
			for kind: StringName in Saved.KINDS:
				partial[kind].erase("slice_preparation_ms")
				complete[kind].erase("slice_preparation_ms")
			_check(var_to_bytes(partial) == var_to_bytes(complete),
				tag + "/" + str(digit) + ": exact full-query geometry, centroids, counts and provenance")


func _packet(stage: Resource) -> Dictionary:
	var mesh: Resource = stage.get("primary_grip_handle_mesh_state")
	var arrays: Array = mesh.get("surface_arrays")
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	for index: int in vertices.size(): vertices[index] *= float(stage.get("cell_world_size_meters"))
	var packet := HandlePacket.build(vertices, arrays[Mesh.ARRAY_INDEX], stage.get("primary_grip_handle_body_signature"))
	packet.primary_grip_handle_mesh_source = stage.get("primary_grip_handle_mesh_source")
	packet.primary_grip_handle_vertices_origin_id = stage.get("primary_grip_handle_mesh_origin_id")
	return packet


func _planes(body: Resource, weapon: Transform3D, machine: Transform3D) -> Dictionary:
	var hand := machine * Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0.01, 0.06, -0.04))
	var records: Array = [_record(ROOT, &"", Transform3D.IDENTITY, Origins.SPACE_TYPE_MACHINE),
		_record(WEAPON, ROOT, machine.affine_inverse() * weapon, Origins.SPACE_TYPE_WEAPON),
		_record(&"SavedSectionsFixtureHandOrigin", ROOT, machine.affine_inverse() * hand, Origins.SPACE_TYPE_BONE_FRAME)]
	var planes: Dictionary = {}
	var points: PackedVector3Array = body.get("path_points")
	for index: int in 2:
		var digit: StringName = &"middle" if index == 0 else &"thumb"
		var frame: Dictionary = Profiles.resolve_profile_path_frame((points[index + 1] - points[index]).normalized(), Vector3.UP,
			body.get("profile_contact_direction_2d"), float(body.get("profile_rotation_bias_degrees")))
		var basis := Basis(frame.axis_x, frame.axis_y, frame.tangent)
		if digit == &"thumb": basis *= Basis(Vector3.UP, deg_to_rad(35.0))
		var plane := weapon * Transform3D(basis, points[index].lerp(points[index + 1], 0.47))
		var id := StringName("SavedSectionsFixture_" + str(digit) + "PlaneOrigin")
		records.append(_record(id, &"SavedSectionsFixtureHandOrigin", hand.affine_inverse() * plane, Origins.SPACE_TYPE_BONE_FRAME))
		planes[digit] = {"plane_to_world": plane, "plane_origin_id": id}
	return {"origin_records": records, "resolve_phase": PHASE, "digit_planes": planes,
		"station_axis_world": weapon.basis.x.normalized(), "vectors_origin_id": ROOT}


func _record(id: StringName, parent: StringName, frame: Transform3D, space: StringName) -> Dictionary:
	return {"origin_id": id, "parent_origin_id": parent, "transform_to_parent": frame,
		"owner_system": &"prepared_saved_grip_sections_verifier", "resolve_phase": PHASE,
		"space_type": space, "is_dynamic": true}


func _surface(wrapper: Resource, packet: Dictionary, kind: StringName, weapon: Transform3D) -> Dictionary:
	var vertices: PackedVector3Array = packet.primary_grip_handle_vertices
	var indices: PackedInt32Array = packet.primary_grip_handle_indices
	if kind != &"handle":
		var prefix := "" if kind == &"digit_target" else "palm_"
		vertices = wrapper.get(prefix + "target_vertices_m")
		indices = wrapper.get(prefix + "target_indices")
	var faces := PackedVector3Array()
	for index: int in indices: faces.append(weapon * vertices[index])
	return {"valid": true, "triangles_world": faces, "surface_source_origin_id": WEAPON, "resolved_world_origin_id": ROOT}


func _source_bytes(wrapper: Resource, packet: Dictionary, context: Dictionary) -> PackedByteArray:
	return var_to_bytes([packet, context, wrapper.get("source_handle_vertices_m"), wrapper.get("source_handle_indices"),
		wrapper.get("target_vertices_m"), wrapper.get("target_indices"), wrapper.get("palm_target_vertices_m"), wrapper.get("palm_target_indices")])


func _frame_error(first: Transform3D, second: Transform3D) -> float:
	var error := first.origin.distance_to(second.origin)
	for index: int in 3: error = maxf(error, first.basis[index].distance_to(second.basis[index]))
	return error


func _boundary_error(first: PackedVector2Array, second: PackedVector2Array) -> float:
	var error := 0.0
	for pair: Array in [[first, second], [second, first]]:
		for point: Vector2 in pair[0]:
			var distance := INF
			var polygon: PackedVector2Array = pair[1]
			for index: int in polygon.size():
				distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])))
			error = maxf(error, distance)
	return error


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)
	return condition
