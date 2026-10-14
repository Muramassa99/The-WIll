extends RefCounted

## A physical target remains fixed while its contact may slide on connected,
## prepared palmar skin. No ray cast, joint change, global target search or
## collision permission is owned here. The caller checks reach and safety.
const ROOT := &"RL_BoneRoot"
const MAX_FACE_TRANSITIONS := 16
const DISTANCE_GUARD_SQUARED_M := 1.0e-14


static func find(prepared: Dictionary, anatomy: RefCounted, digit: StringName, section: int,
		anchor_world: Vector3, seed_triangle: int, frames: Dictionary = {}) -> Dictionary:
	if section < 0 or section > 2 or not anchor_world.is_finite() or not prepared.get("digits", {}).has(digit):
		return {"valid":false, "reason":"invalid_continuous_skin_request"}
	var patches: Dictionary = prepared.digits[digit].sections[section].get("contact_patches", {})
	if not patches.has(seed_triangle):
		return {"valid":false, "reason":"contact_seed_outside_prepared_section"}
	var cache := {}
	var current := _closest(prepared, anatomy, patches[seed_triangle], anchor_world, frames)
	if not current.get("valid", false): return current
	cache[seed_triangle] = current
	var visited := {seed_triangle:true}
	var transitions := 0
	while transitions < MAX_FACE_TRANSITIONS:
		var next: Dictionary = current
		for neighbor: int in patches[int(current.triangle_id)].neighbors:
			if visited.has(neighbor): continue
			if not cache.has(neighbor): cache[neighbor] = _closest(prepared, anatomy, patches[neighbor], anchor_world, frames)
			var candidate: Dictionary = cache[neighbor]
			if not candidate.get("valid", false): continue
			if float(candidate.distance_squared_m) < float(next.distance_squared_m) - DISTANCE_GUARD_SQUARED_M:
				next = candidate
		if next.triangle_id == current.triangle_id: break
		current = next
		visited[int(current.triangle_id)] = true
		transitions += 1
	current["face_transitions"] = transitions
	current["walk_limit_reached"] = transitions == MAX_FACE_TRANSITIONS
	return current


static func _closest(prepared: Dictionary, anatomy: RefCounted, patch: Dictionary,
		anchor: Vector3, frames: Dictionary) -> Dictionary:
	var posed: Array = anatomy.pose_samples(prepared, [patch.carrier], frames)
	if posed.size() != 1: return {"valid":false, "reason":"continuous_skin_pose_unavailable"}
	var output: Dictionary = posed[0]
	var vertices: Array = output.triangle_world
	var normal: Vector3 = output.normal_world
	var projected := anchor - normal * (anchor - (vertices[0] as Vector3)).dot(normal)
	var bary := Geometry3D.get_triangle_barycentric_coords(projected, vertices[0], vertices[1], vertices[2])
	if not bary.is_finite(): return {"valid":false, "reason":"degenerate_continuous_skin_face"}
	var polygon: Array = patch.polygon_barycentric
	var point := projected
	if not _inside(bary, polygon):
		var best := INF
		for index: int in polygon.size():
			var a: Vector3 = polygon[index]
			var b: Vector3 = polygon[(index + 1) % polygon.size()]
			var start: Vector3 = vertices[0] * a.x + vertices[1] * a.y + vertices[2] * a.z
			var end: Vector3 = vertices[0] * b.x + vertices[1] * b.y + vertices[2] * b.z
			var candidate := Geometry3D.get_closest_point_to_segment(anchor, start, end)
			var distance := candidate.distance_squared_to(anchor)
			if distance < best:
				best = distance
				point = candidate
		bary = Geometry3D.get_triangle_barycentric_coords(point, vertices[0], vertices[1], vertices[2])
	var percentage := 0.0
	var length_m := 0.0
	var coordinate_valid := true
	for corner: int in 3:
		if bary[corner] <= 0.0: continue
		var coordinate: float = patch.vertex_percent[corner]
		if coordinate < 0.0:
			coordinate_valid = false
			break
		percentage += coordinate * bary[corner]
		length_m += float(patch.vertex_section_lengths_m[corner]) * bary[corner]
	output["valid"] = true
	output["barycentric"] = bary
	output["point_world"] = point
	output["percent"] = percentage if coordinate_valid else -1.0
	output["section_length_m"] = length_m if coordinate_valid else 0.0
	output["distance_squared_m"] = point.distance_squared_to(anchor)
	output["distance_m"] = point.distance_to(anchor)
	output["vectors_origin_id"] = ROOT
	output["contact_coordinate_policy"] = &"interpolated_prepared_mesh_edge_coordinates"
	return output


static func _inside(point: Vector3, polygon: Array) -> bool:
	if polygon.size() < 3: return false
	# Barycentric triples occupy x+y+z=1. Clipping preserves source winding.
	for index: int in polygon.size():
		var a: Vector3 = polygon[index]
		var b: Vector3 = polygon[(index + 1) % polygon.size()]
		if (b - a).cross(point - a).dot(Vector3.ONE) < -0.000001: return false
	return true
