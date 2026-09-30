extends "res://tools/grip_plane_proof/run_contact_driven_preparation.gd"

## Diagnostic only: same immutable saved triangles, actual prepared digit planes,
## world-vs-WeaponRoot arithmetic. No IK, no tolerance or contour changes.
const PlaneSection = preload("res://runtime/player/grip/prepared_weapon_plane_section.gd")
const Slicer = preload("res://runtime/player/grip/slice_reachable_surface.gd")
const Contact = preload("res://runtime/player/grip/skin_plane_contact_query.gd")
const OriginQuery = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")


func _case(path: String, wip: Resource, packet: Dictionary) -> void:
	if not _check(FileAccess.get_sha256(path) == TRACES[path], "capture hash"): return
	var file := FileAccess.open(path, FileAccess.READ)
	var raw: Dictionary = file.get_var(false)
	file.close()
	var selected: Dictionary = {}
	for transaction: Dictionary in raw.transactions:
		if transaction.slot == raw.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty():
			selected = transaction.finger_inputs[-1]
	if not _check(not selected.is_empty(), "captured hand input"): return
	var stage: Dictionary = _uncentered_fixture(selected, wip, packet)
	var job := Acquisition.new()
	if not _check(job.configure(Config.anatomy, stage, Config.contact_config, root).get("valid", false), "configured"): return
	var context := _prepare_hand_context(job, stage)
	if not _check(context.get("valid", false), "prepared anatomy"): return
	var candidate: Dictionary = job._builder.evaluate(context.adapter, job._angles(context.open_parameters), Vector3.ZERO, ROOT)
	if not _check(candidate.get("valid", false), "prepared open hand"): return
	var weapon: Transform3D = stage.object.weapon_to_world
	var world_to_weapon := weapon.affine_inverse()
	var wrapper: Resource = wip.stage2_item_state.primary_grip_target_wrapper
	var entry := {"slot": stage.slot, "surfaces": {}, "weapon_to_world": weapon,
		"fixture_placement": "original_span_midpoint_preserving_preexisting_cap_case",
		"source_span_start": selected.object.primary_grip_span_start_local,
		"source_span_end": selected.object.primary_grip_span_end_local,
		"source_grip_pivot": selected.object.get("grip_pivot_local"),
		"source_grip_pivot_origin_id": selected.object.get("grip_pivot_local_origin_id"),
		"source_span_origin_id": selected.object.primary_grip_span_start_origin_id,
		"fixture_span_start": stage.object.primary_grip_span_start_local,
		"fixture_span_end": stage.object.primary_grip_span_end_local}
	for kind: StringName in [&"handle", &"digit_target", &"palm_target"]:
		var vertices: PackedVector3Array = packet.primary_grip_handle_vertices
		var indices: PackedInt32Array = packet.primary_grip_handle_indices
		if kind != &"handle":
			var prefix := "" if kind == &"digit_target" else "palm_"
			vertices = wrapper.get(prefix + "target_vertices_m")
			indices = wrapper.get(prefix + "target_indices")
		var faces := PackedVector3Array()
		for index: int in indices: faces.append(vertices[index])
		var results := {}
		for digit: StringName in context.digit_order:
			var plane: Transform3D = candidate.digit_states[digit].plane_to_world
			var local_plane := world_to_weapon * plane
			results[digit] = {
				"world": _one(faces, weapon, plane, ROOT, candidate.pose_packet.machine_to_world, weapon),
				"weapon": _one(faces, Transform3D.IDENTITY, local_plane, Packet.VERTICES_ORIGIN_ID, candidate.pose_packet.machine_to_world, weapon),
				"plane_to_world": plane,
				"plane_to_weapon": local_plane,
				"plane_to_weapon_origin_id": Packet.VERTICES_ORIGIN_ID,
			}
		entry.surfaces[kind] = results
	var polygon: PackedVector2Array = wrapper.source_profile_m
	var edges: Array = []
	for index: int in polygon.size(): edges.append([polygon[index], polygon[(index + 1) % polygon.size()]])
	entry["profile_topology"] = Contact.new().prepare_target(edges, &"ForgeV2HandleProfileOrigin")
	entry.profile_topology.erase("edges")
	_cases.append(entry)
	for kind: StringName in entry.surfaces:
		for digit: StringName in entry.surfaces[kind]:
			var measured: Dictionary = entry.surfaces[kind][digit]
			print("SAVED_SECTION_COORDINATES ", stage.slot, "/", digit, "/", kind,
				" world=", measured.world.get("valid", false), " weapon=", measured.weapon.get("valid", false))


func _one(faces: PackedVector3Array, source_to_frame: Transform3D, plane: Transform3D,
		frame_origin: StringName, machine_to_world: Transform3D, weapon_to_world: Transform3D) -> Dictionary:
	var weapon_frame := frame_origin == Packet.VERTICES_ORIGIN_ID
	var plane_id := &"SavedSectionDiagnosticWeaponPlaneOrigin" if weapon_frame else &"SavedSectionDiagnosticWorldPlaneOrigin"
	var plane_to_parent: Transform3D = plane if weapon_frame else machine_to_world.affine_inverse() * plane
	var records: Array = [
		_origin_record(ROOT, &"", Transform3D.IDENTITY, &"machine"),
		_origin_record(Packet.VERTICES_ORIGIN_ID, ROOT, machine_to_world.affine_inverse() * weapon_to_world, &"weapon"),
		_origin_record(plane_id, frame_origin, plane_to_parent, &"presentation"),
	]
	var registered: Dictionary = OriginQuery.new()._registry(records, &"editor_preview")
	_check(registered.get("valid", false), "diagnostic named query chain")
	var provenance := {"query_origin_id": plane_id, "origin_records": records,
		"resolve_phase": &"editor_preview", "machine_to_world": machine_to_world,
		"weapon_to_world": weapon_to_world, "weapon_to_world_origin_id": ROOT,
		"input_triangle_origin_id": Packet.VERTICES_ORIGIN_ID,
		"arithmetic_coordinates": "WeaponRoot meters" if weapon_frame else "world presentation meters",
		"arithmetic_source_transform": source_to_frame, "arithmetic_frame_origin_id": frame_origin,
		"plane_input_transform": plane, "plane_input_frame_origin_id": frame_origin,
		"origin_chain": registered.registry.validate_origin_chain(plane_id) if registered.get("valid", false) else registered}
	var surface := {"valid": true, "triangles_world": source_to_frame * faces,
		"surface_source_origin_id": Packet.VERTICES_ORIGIN_ID, "resolved_world_origin_id": frame_origin}
	var helper := PlaneSection.new()
	var prepared := helper.prepare(surface, plane, plane_id)
	if not prepared.get("valid", false): return prepared
	var section := helper.slice(prepared, plane)
	var raw := Slicer.new().slice(surface, plane, plane_id, 1.0, 0.0)
	section["coordinate_provenance"] = provenance
	section["raw_counts"] = raw.get("counts")
	section["raw_contours"] = raw.get("contours")
	section["polygon"] = section.get("polygon", PackedVector2Array())
	if not section.get("valid", false):
		section["source_triangle_evidence"] = _source_evidence(surface, plane, section.get("detail", {}))
		if weapon_frame:
			section["cap_source_overlap_evidence"] = _cap_overlaps(section.source_triangle_evidence)
	return section


func _uncentered_fixture(source: Dictionary, wip: Resource, packet: Dictionary) -> Dictionary:
	# Freeze the original cap-triggering fixture placement here. The main W3
	# preparation proof may independently place its fixture at an interior station.
	var stage: Dictionary = source.duplicate(true)
	var old: Dictionary = source.object
	var source_axis: Vector3 = (old.primary_grip_span_end_local - old.primary_grip_span_start_local).normalized()
	var frame: Transform3D = old.weapon_to_world * Transform3D(Basis(Quaternion(Vector3.RIGHT, source_axis)),
		(old.primary_grip_span_start_local + old.primary_grip_span_end_local) * 0.5)
	var record := {"origin_id": Packet.VERTICES_ORIGIN_ID, "parent_origin_id": ROOT,
		"transform_to_parent": (source.posed_character.machine_to_world as Transform3D).affine_inverse() * frame,
		"owner_system": &"w3_saved_handle_fixture", "resolve_phase": source.posed_character.resolve_phase,
		"space_type": &"weapon", "is_dynamic": true}
	var mesh_id := &"W3SavedPhysicalHandleMeshOrigin"
	var mesh_record := {"origin_id": mesh_id, "parent_origin_id": Packet.VERTICES_ORIGIN_ID,
		"transform_to_parent": Transform3D.IDENTITY, "owner_system": &"w3_saved_handle_fixture",
		"resolve_phase": source.posed_character.resolve_phase, "space_type": &"presentation", "is_dynamic": false}
	var faces := PackedVector3Array()
	for index: int in packet.primary_grip_handle_indices: faces.append(packet.primary_grip_handle_vertices[index])
	var profile: Resource = wip.latest_baked_profile_snapshot
	var cell: float = wip.stage2_item_state.cell_world_size_meters
	stage.object = {"local_faces": faces, "local_faces_origin_id": mesh_id, "origin_record": mesh_record,
		"weapon_origin_record": record, "mesh_to_world": frame, "weapon_to_world": frame,
		"primary_grip_span_start_local": profile.primary_grip_span_start * cell,
		"primary_grip_span_end_local": profile.primary_grip_span_end * cell,
		"primary_grip_span_start_origin_id": Packet.VERTICES_ORIGIN_ID,
		"primary_grip_span_end_origin_id": Packet.VERTICES_ORIGIN_ID}
	return stage


func _source_evidence(surface: Dictionary, plane: Transform3D, detail: Dictionary) -> Array:
	var wanted: Array = []
	for pair: Dictionary in detail.get("self_intersection_pairs", []):
		wanted.append([pair.a, pair.b]); wanted.append([pair.c, pair.d])
	if wanted.is_empty(): return []
	var output: Array = []
	var triangles: PackedVector3Array = surface.triangles_world
	for offset: int in range(0, triangles.size(), 3):
		var vertices := PackedVector3Array([triangles[offset], triangles[offset + 1], triangles[offset + 2]])
		var distances: Array = []
		for vertex: Vector3 in vertices: distances.append((vertex - plane.origin).dot(plane.basis.z))
		var hits: Array = []
		var on_plane: Array = []
		for index: int in 3:
			if absf(distances[index]) <= Slicer.DISTANCE_EPSILON:
				hits.append(_xy(vertices[index], plane)); on_plane.append(index)
			var following := (index + 1) % 3
			if (distances[index] > Slicer.DISTANCE_EPSILON and distances[following] < -Slicer.DISTANCE_EPSILON) or (distances[index] < -Slicer.DISTANCE_EPSILON and distances[following] > Slicer.DISTANCE_EPSILON):
				var crossing: Vector3 = vertices[index].lerp(vertices[following], distances[index] / (distances[index] - distances[following]))
				hits.append(_xy(crossing, plane))
		if hits.size() < 2: continue
		var best: Array = []
		var length := -1.0
		for first: int in hits.size():
			for second: int in range(first + 1, hits.size()):
				var squared: float = hits[first].distance_squared_to(hits[second])
				if squared > length:
					length = squared; best = [hits[first], hits[second]]
		if best.is_empty(): continue
		var matched := false
		for edge: Array in wanted:
			var direct: float = maxf(best[0].distance_to(edge[0]), best[1].distance_to(edge[1]))
			var reverse: float = maxf(best[0].distance_to(edge[1]), best[1].distance_to(edge[0]))
			matched = matched or minf(direct, reverse) <= 0.000005
		if matched:
			output.append({"triangle": offset / 3, "vertices": vertices, "distances_m": distances,
				"on_plane_vertices": on_plane, "segment": best, "all_hits": hits})
	return output


func _xy(vertex: Vector3, plane: Transform3D) -> Vector2:
	var relative := vertex - plane.origin
	return Vector2(relative.dot(plane.basis.x), relative.dot(plane.basis.y))


func _origin_record(id: StringName, parent: StringName, frame: Transform3D, space: StringName) -> Dictionary:
	return {"origin_id": id, "parent_origin_id": parent, "transform_to_parent": frame,
		"owner_system": &"saved_grip_section_coordinate_diagnostic", "resolve_phase": &"editor_preview",
		"space_type": space, "is_dynamic": false}


func _cap_overlaps(evidence: Array) -> Array:
	# This fixture's cap lies in a constant WeaponRoot X plane. Test the raw
	# saved triangle YZ values with scalar doubles, independently of slice/clip.
	# Do not weld, offset, delete triangles or use an inclusion epsilon.
	var result: Array = []
	for first: Dictionary in evidence:
		var a: PackedVector3Array = first.vertices
		if a[0].x != a[1].x or a[0].x != a[2].x: continue
		var first_yz: Array = []
		for vertex: Vector3 in a: first_yz.append([float(vertex.y), float(vertex.z)])
		var first_signed := _cross(first_yz[0], first_yz[1], first_yz[2]) * 0.5
		if first_signed == 0.0: continue
		for second: Dictionary in evidence:
			if first.triangle == second.triangle: continue
			var b: PackedVector3Array = second.vertices
			if a[0].x != b[0].x or b[0].x != b[1].x or b[0].x != b[2].x: continue
			var second_yz: Array = []
			for vertex: Vector3 in b: second_yz.append([float(vertex.y), float(vertex.z)])
			var second_signed := _cross(second_yz[0], second_yz[1], second_yz[2]) * 0.5
			if second_signed == 0.0: continue
			var barycentric: Array = []
			var all_inside := true
			for point: Array in first_yz:
				var weights := _barycentric(point, second_yz)
				barycentric.append(weights)
				for weight: float in weights: all_inside = all_inside and weight >= 0.0 and weight <= 1.0
			var center: Array = [
				(float(first_yz[0][0]) + float(first_yz[1][0]) + float(first_yz[2][0])) / 3.0,
				(float(first_yz[0][1]) + float(first_yz[1][1]) + float(first_yz[2][1])) / 3.0,
			]
			var center_weights := _barycentric(center, second_yz)
			var center_strictly_inside := true
			for weight: float in center_weights: center_strictly_inside = center_strictly_inside and weight > 0.0 and weight < 1.0
			result.append({"contained_triangle": first.triangle, "containing_triangle": second.triangle,
				"vertices_origin_id": Packet.VERTICES_ORIGIN_ID, "constant_cap_x_m": float(a[0].x),
				"contained_triangle_vertices": a, "containing_triangle_vertices": b,
				"first_signed_yz_area_m2": first_signed, "second_signed_yz_area_m2": second_signed,
				"opposite_winding": first_signed * second_signed < 0.0,
				"first_vertex_barycentrics_in_second": barycentric, "all_first_vertices_inside_second": all_inside,
				"first_centroid_yz_m": center, "centroid_barycentrics_in_second": center_weights,
				"centroid_strictly_inside_second": center_strictly_inside,
				"first_on_plane_vertices": first.on_plane_vertices, "second_on_plane_vertices": second.on_plane_vertices,
				"inclusion_epsilon_m": 0.0, "geometry_changed": false})
	return result


func _cross(a: Array, b: Array, c: Array) -> float:
	return (float(b[0]) - float(a[0])) * (float(c[1]) - float(a[1])) - (float(b[1]) - float(a[1])) * (float(c[0]) - float(a[0]))


func _barycentric(point: Array, triangle: Array) -> Array:
	var doubled_area := _cross(triangle[0], triangle[1], triangle[2])
	return [_cross(point, triangle[1], triangle[2]) / doubled_area,
		_cross(triangle[0], point, triangle[2]) / doubled_area,
		_cross(triangle[0], triangle[1], point) / doubled_area]


func _finish() -> void:
	var path := "C:/WORKSPACE/test_artifacts/saved_grip_section_coordinates_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify(_json({"cases": _cases, "failures": _failures,
		"duration_ms": float(Time.get_ticks_usec() - _started) / 1000.0}), "\t"))
	output.close()
	print("SAVED_SECTION_COORDINATES_REPORT=", path)
	quit(0 if _failures.is_empty() else 1)
