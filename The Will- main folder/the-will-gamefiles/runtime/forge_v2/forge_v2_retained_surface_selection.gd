extends RefCounted
## Temporary E-mode presentation. Only final, surviving triangles are drawn or
## picked; operand BVHs identify their source and never become visible geometry.

const UNAVAILABLE := Color("c64f4f")
const HANDLE := Color("a77ad9")
const GRADIENT := [Color("48bf72"), Color("a5c94a"), Color("e9d34e"), Color("eaa43a"), Color("d87928")]
const SURFACE_TOLERANCE := 0.000015
# TriangleMesh snaps vertices to 0.0001 coordinate units internally. Query in
# millimetres so its snap is 0.1 micrometres, not 0.1 millimetres in this scene.
const QUERY_SCALE := 1000.0

var root: Node3D
var final_bvh: TriangleMesh
var owners: Array[Dictionary] = []
var materials: Dictionary = {}
var owner_records: Dictionary = {}
var face_count := 0
var overlay_shader: Shader

func clear() -> void:
	if root != null and is_instance_valid(root):
		root.free()
	root = null
	final_bvh = null
	owners.clear()
	materials.clear()
	owner_records.clear()
	face_count = 0

func build(parent: Node3D, faces: PackedVector3Array, source_records: Array[Dictionary]) -> bool:
	clear()
	if faces.is_empty() or faces.size() % 3 != 0:
		return false
	final_bvh = build_query_bvh(faces)
	if final_bvh == null:
		return false
	var editable_count := 0
	for record: Dictionary in source_records:
		if bool(record.get("editable", false)) and not bool(record.get("is_handle", false)):
			editable_count += 1
	var editable_index := 0
	for record: Dictionary in source_records:
		var source_bvh := record.get("bvh") as TriangleMesh
		if source_bvh != null:
			record["query_faces"] = source_bvh.get_faces()
			_prepare_source_bounds(record)
		var color := UNAVAILABLE
		if bool(record.get("is_handle", false)):
			color = HANDLE
		elif bool(record.get("editable", false)):
			var gradient_position := 0.0 if editable_count <= 1 else float(editable_index) * 4.0 / float(editable_count - 1)
			var lower := mini(int(floor(gradient_position)), 4)
			color = GRADIENT[lower].lerp(GRADIENT[mini(lower + 1, 4)], gradient_position - lower)
			editable_index += 1
		record["color"] = color
		owner_records[StringName(record.get("body_id", StringName()))] = record
	var surfaces: Dictionary = {}
	for offset in range(0, faces.size(), 3):
		var a := faces[offset]
		var b := faces[offset + 1]
		var c := faces[offset + 2]
		var normal := (b - a).cross(c - a).normalized()
		var owner: Dictionary = {"body_id": StringName(), "editable": false, "is_handle": false, "color": UNAVAILABLE}
		for record: Dictionary in source_records:
			var bvh := record.get("bvh") as TriangleMesh
			if bvh == null:
				continue
			# A whole final triangle must lie in one source triangle. Unlike a
			# handful of witnesses, convex containment proves there is no tiny
			# missing source patch in its interior. Ambiguous merged faces stay red.
			if _triangle_is_owned(record, a, b, c, normal):
				owner = record
				break
			if _triangle_has_source_overlap(record, a, b, c, normal):
				# A newer partial face cannot silently fall through to an older
				# full-face owner. Keep the unsplit final face unavailable.
				break
		owners.append(owner)
		var owner_id := StringName(owner.get("body_id", StringName()))
		if not surfaces.has(owner_id):
			var new_surface := SurfaceTool.new()
			new_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[owner_id] = new_surface
		var surface: SurfaceTool = surfaces[owner_id]
		surface.set_normal(normal)
		surface.add_vertex(a)
		surface.add_vertex(b)
		surface.add_vertex(c)
	root = Node3D.new()
	root.name = "RetainedEditSurfaceColours"
	parent.add_child(root)
	if overlay_shader == null:
		overlay_shader = Shader.new()
		overlay_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color;
void vertex() {
    vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec4 clip_position = PROJECTION_MATRIX * view_position;
    // Godot 4.7 uses reversed depth. Four float depth steps near 1 keep an
    // equal-surface overlay visible even with an orthographic long far plane.
    // Depth testing stays enabled, so foreground surfaces still occlude it.
    clip_position.z = min(clip_position.z + 0.00000024 * clip_position.w, clip_position.w);
    POSITION = clip_position;
}
void fragment() { ALBEDO = tint.rgb; ALPHA = tint.a; }
"""
	for owner_id: StringName in surfaces:
		var surface: SurfaceTool = surfaces[owner_id]
		var instance := MeshInstance3D.new()
		instance.name = "RetainedSurface_%s" % String(owner_id)
		instance.mesh = surface.commit()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = overlay_shader
		var tint: Color = (owner_records.get(owner_id, {}) as Dictionary).get("color", UNAVAILABLE)
		tint.a = 0.72
		material.set_shader_parameter("tint", tint)
		instance.material_override = material
		materials[owner_id] = material
		root.add_child(instance)
	face_count = owners.size()
	return true

func _triangle_is_owned(record: Dictionary, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> bool:
	var bvh: TriangleMesh = record["bvh"]
	var point := (a + b + c) / 3.0
	var query_point := point * QUERY_SCALE
	var offset := normal * SURFACE_TOLERANCE * QUERY_SCALE
	# A microscopic segment makes the triangle determinant fall below Godot's
	# epsilon for millimetre-sized facets. A unit ray plus a distance guard keeps
	# the same surface tolerance without that scale-dependent false negative.
	var hit := bvh.intersect_ray(query_point - offset, normal)
	if hit.is_empty():
		hit = bvh.intersect_ray(query_point + offset, -normal)
	if (hit.is_empty()
		or query_point.distance_to(hit.get("position", Vector3.INF)) > SURFACE_TOLERANCE * QUERY_SCALE
		or absf(normal.dot(hit.get("normal", Vector3.ZERO))) < 0.999):
		return false
	var source_faces: PackedVector3Array = record["query_faces"]
	var index := int(hit.get("face_index", -1)) * 3
	if index < 0 or index + 2 >= source_faces.size():
		return false
	var source_a := source_faces[index]
	var source_b := source_faces[index + 1]
	var source_c := source_faces[index + 2]
	var source_normal := (source_b - source_a).cross(source_c - source_a).normalized()
	for vertex: Vector3 in [a, b, c]:
		var query_vertex := vertex * QUERY_SCALE
		if absf(source_normal.dot(query_vertex - source_a)) > SURFACE_TOLERANCE * QUERY_SCALE:
			return false
		# A triangle is convex: its three inward edge half-planes plus its
		# surface plane exactly characterize containment, within roundoff.
		for edge: Array in [[source_a, source_b], [source_b, source_c], [source_c, source_a]]:
			var edge_direction: Vector3 = edge[1] - edge[0]
			var signed_edge_distance := edge_direction.cross(query_vertex - edge[0]).dot(source_normal)
			if signed_edge_distance < -SURFACE_TOLERANCE * QUERY_SCALE * edge_direction.length():
				return false
	return true

func resolve(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	if final_bvh == null:
		return {"valid": false, "editable": false}
	var hit := final_bvh.intersect_ray(ray_origin * QUERY_SCALE, ray_direction)
	if hit.is_empty():
		return {"valid": false, "editable": false}
	var index := int(hit.get("face_index", -1))
	if index < 0 or index >= owners.size():
		return {"valid": false, "editable": false}
	var owner: Dictionary = owners[index]
	return {"valid": true, "editable": bool(owner.get("editable", false)), "body_id": owner.get("body_id", StringName()), "is_handle": bool(owner.get("is_handle", false)), "local_position": hit.get("position", Vector3.ZERO) / QUERY_SCALE, "face_index": index}

static func build_query_bvh(faces: PackedVector3Array) -> TriangleMesh:
	if faces.is_empty():
		return null
	var scaled := faces.duplicate()
	for index in range(scaled.size()):
		scaled[index] *= QUERY_SCALE
	var bvh := TriangleMesh.new()
	return bvh if bvh.create_from_faces(scaled) else null

func _prepare_source_bounds(record: Dictionary) -> void:
	var faces: PackedVector3Array = record["query_faces"]
	var bounds: Array[AABB] = []
	var normals := PackedVector3Array()
	var total := AABB(faces[0], Vector3.ZERO)
	for index in range(0, faces.size(), 3):
		var triangle := AABB(faces[index], Vector3.ZERO).expand(faces[index + 1]).expand(faces[index + 2])
		bounds.append(triangle.grow(SURFACE_TOLERANCE * QUERY_SCALE))
		normals.append((faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index]).normalized())
		total = total.merge(triangle)
	record["query_bounds"] = total.grow(SURFACE_TOLERANCE * QUERY_SCALE)
	record["triangle_bounds"] = bounds
	record["triangle_normals"] = normals

func _triangle_has_source_overlap(record: Dictionary, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> bool:
	var qa := a * QUERY_SCALE
	var qb := b * QUERY_SCALE
	var qc := c * QUERY_SCALE
	var bounds := AABB(qa, Vector3.ZERO).expand(qb).expand(qc).grow(SURFACE_TOLERANCE * QUERY_SCALE)
	if not bounds.intersects(record["query_bounds"] as AABB):
		return false
	var faces: PackedVector3Array = record["query_faces"]
	var triangle_bounds: Array[AABB] = record["triangle_bounds"]
	var triangle_normals: PackedVector3Array = record["triangle_normals"]
	var axis := normal.abs().max_axis_index()
	var final_polygon := PackedVector2Array([_project_plane(qa, axis), _project_plane(qb, axis), _project_plane(qc, axis)])
	var minimum_area := maxf(absf((final_polygon[1] - final_polygon[0]).cross(final_polygon[2] - final_polygon[0])) * 0.00000001, 0.0000000001)
	for triangle_index in range(triangle_bounds.size()):
		if not bounds.intersects(triangle_bounds[triangle_index]) or absf(normal.dot(triangle_normals[triangle_index])) < 0.999:
			continue
		var index := triangle_index * 3
		if absf(normal.dot(faces[index] - qa)) > SURFACE_TOLERANCE * QUERY_SCALE:
			continue
		var source_polygon := PackedVector2Array([_project_plane(faces[index], axis), _project_plane(faces[index + 1], axis), _project_plane(faces[index + 2], axis)])
		for intersection: PackedVector2Array in Geometry2D.intersect_polygons(final_polygon, source_polygon):
			var twice_area := 0.0
			for vertex_index in range(intersection.size()):
				twice_area += intersection[vertex_index].cross(intersection[(vertex_index + 1) % intersection.size()])
			if absf(twice_area) > minimum_area:
				return true
	return false

func _project_plane(point: Vector3, dropped_axis: int) -> Vector2:
	if dropped_axis == 0:
		return Vector2(point.y, point.z)
	if dropped_axis == 1:
		return Vector2(point.x, point.z)
	return Vector2(point.x, point.y)

func hover(body_id: StringName) -> void:
	for owner_id: StringName in materials:
		var material: ShaderMaterial = materials[owner_id]
		var color: Color = (owner_records.get(owner_id, {}) as Dictionary).get("color", UNAVAILABLE)
		if owner_id != StringName() and owner_id == body_id:
			color = color.lightened(0.3)
		color.a = 0.82 if owner_id == body_id and body_id != StringName() else 0.72
		material.set_shader_parameter("tint", color)
