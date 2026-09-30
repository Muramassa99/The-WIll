extends RefCounted

## Circle-only proof source. Index immutable world triangles once for a fixed
## metric plane orientation; every translated plane still gets its real section.
## Existing Slicer owns intersection, welding and closed-loop extraction. This
## helper certifies one complete simple planar loop, not a closed 3D solid/grip.
const Slicer = preload("res://runtime/player/grip/slice_reachable_surface.gd")
const Contact = preload("res://runtime/player/grip/skin_plane_contact_query.gd")
const Centroid = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const REVISION := &"prepared_weapon_plane_section_v1"
const MAX_INDEX_BINS: int = 64
const FLOAT32_EPSILON: float = 0.00000011920928955078125
var _slicer := Slicer.new()
var _contact := Contact.new()


func prepare(surface: Dictionary, plane_to_world: Transform3D, plane_origin_id: StringName) -> Dictionary:
	var started := Time.get_ticks_usec()
	if plane_origin_id == StringName() or not _slicer._valid_plane(plane_to_world):
		return _fail("invalid_named_metric_plane")
	if not surface.get("valid", false) or not surface.get("triangles_world") is PackedVector3Array:
		return _fail("invalid_world_triangle_surface")
	var source_id := StringName(surface.get("surface_source_origin_id", &""))
	var world_origin_id := StringName(surface.get("resolved_world_origin_id", &""))
	if source_id == StringName() or world_origin_id == StringName():
		return _fail("missing_surface_origin_chain")
	var triangles: PackedVector3Array = surface.triangles_world.duplicate()
	if triangles.is_empty() or triangles.size() % 3 != 0:
		return _fail("empty_or_nontriangle_surface")
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var heights := PackedFloat64Array()
	var scale_m: float = 0.0
	for vertex: Vector3 in triangles:
		if not vertex.is_finite(): return _fail("nonfinite_source_vertex")
		low = low.min(vertex); high = high.max(vertex)
		scale_m = maxf(scale_m, _maximum_component(vertex))
		heights.append(_dot_scalar(vertex, plane_to_world.basis.z))
	var minimums := PackedFloat64Array()
	var maximums := PackedFloat64Array()
	var height_min: float = INF
	var height_max: float = -INF
	for offset: int in range(0, triangles.size(), 3):
		var first: float = minf(heights[offset], minf(heights[offset + 1], heights[offset + 2]))
		var last: float = maxf(heights[offset], maxf(heights[offset + 1], heights[offset + 2]))
		minimums.append(first); maximums.append(last)
		height_min = minf(height_min, first); height_max = maxf(height_max, last)
	var bin_count: int = mini(MAX_INDEX_BINS, minimums.size()) if height_max > height_min else 1
	var bins: Array[PackedInt32Array] = []
	for _index: int in bin_count: bins.append(PackedInt32Array())
	for triangle_index: int in minimums.size():
		var first: int = _bin(minimums[triangle_index], height_min, height_max, bin_count)
		var last: int = _bin(maximums[triangle_index], height_min, height_max, bin_count)
		for index: int in range(first, last + 1):
			var bucket: PackedInt32Array = bins[index]
			bucket.append(triangle_index)
			bins[index] = bucket
	var bounds_center: Vector3 = (low + high) * 0.5
	var bounds_radius: float = (high - low).length() * 0.5
	if not bounds_center.is_finite() or not is_finite(bounds_radius):
		return _fail("nonfinite_source_bounds")
	return {"valid": true, "revision": REVISION, "triangles_world": triangles,
		"source_id": source_id, "surface_source_origin_id": source_id,
		"resolved_world_origin_id": world_origin_id, "origin_id": plane_origin_id,
		"initial_plane_to_world": plane_to_world, "fixed_basis": plane_to_world.basis,
		"triangle_height_min": minimums, "triangle_height_max": maximums,
		"height_min": height_min, "height_max": height_max, "bins": bins,
		"source_bounds_center_world": bounds_center,
		"source_bounds_radius_m": bounds_radius,
		"source_coordinate_scale_m": scale_m, "metric_units": &"meters",
		"preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"source_solid_topology_certified": false}


func slice(prepared: Dictionary, current_plane_to_world: Transform3D) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not prepared.get("valid", false) or prepared.get("revision") != REVISION:
		return _fail("invalid_prepared_section_source")
	if StringName(prepared.get("origin_id", &"")) == StringName() or StringName(prepared.get("source_id", &"")) == StringName() or StringName(prepared.get("resolved_world_origin_id", &"")) == StringName():
		return _fail("missing_prepared_origin_chain")
	if not _slicer._valid_plane(current_plane_to_world) or current_plane_to_world.basis != prepared.fixed_basis:
		return _fail("plane_orientation_changed_or_nonmetric")
	var height: float = _dot_scalar(current_plane_to_world.origin, current_plane_to_world.basis.z)
	# Conservative broad phase only. Mature Slicer retains its original 1 um
	# plane predicate. This guard covers float-vector subtraction/dot roundoff;
	# it never changes the section geometry or its acceptance tolerances.
	var scale: float = float(prepared.source_coordinate_scale_m) + _maximum_component(current_plane_to_world.origin) + 1.0
	var guard: float = Slicer.DISTANCE_EPSILON + 32.0 * FLOAT32_EPSILON * scale
	var first_height: float = height - guard
	var last_height: float = height + guard
	if last_height < float(prepared.height_min) or first_height > float(prepared.height_max):
		return _fail("plane_does_not_intersect_source")
	var bins: Array = prepared.bins
	var first: int = _bin(first_height, prepared.height_min, prepared.height_max, bins.size())
	var last: int = _bin(last_height, prepared.height_min, prepared.height_max, bins.size())
	var selected: Dictionary = {}
	var minimums: PackedFloat64Array = prepared.triangle_height_min
	var maximums: PackedFloat64Array = prepared.triangle_height_max
	for index: int in range(first, last + 1):
		for triangle_index: int in bins[index]:
			if minimums[triangle_index] <= last_height and maximums[triangle_index] >= first_height:
				selected[triangle_index] = true
	var indices: Array = selected.keys()
	indices.sort() # Preserve the original mesh traversal and welding order.
	if indices.is_empty(): return _fail("plane_does_not_intersect_source")
	var original: PackedVector3Array = prepared.triangles_world
	var triangles := PackedVector3Array()
	triangles.resize(indices.size() * 3)
	for index: int in indices.size():
		var source_offset: int = int(indices[index]) * 3
		for corner: int in 3: triangles[index * 3 + corner] = original[source_offset + corner]
	var indexed_surface := {"valid": true, "triangles_world": triangles,
		"surface_source_origin_id": prepared.source_id,
		"resolved_world_origin_id": prepared.resolved_world_origin_id}
	# Encloses ALL original vertices, not only the retained candidates. No disk
	# clipping/reach pruning may be used to manufacture a complete section.
	var reach: float = current_plane_to_world.origin.distance_to(prepared.source_bounds_center_world) + float(prepared.source_bounds_radius_m) + 0.0001
	var recording: bool = Chronology.enabled()
	var slice_span: int = Chronology.begin("section.triangle_slice", {
		"plane_id": prepared.origin_id, "source_id": prepared.source_id,
		"resolved_world_origin_id": prepared.resolved_world_origin_id,
		"source_triangles": original.size() / 3, "indexed_triangles": indices.size(),
		"index_bins_visited": last - first + 1, "plane_height_m": height,
		"reach_m": reach}) if recording else 0
	var sliced: Dictionary = _slicer.slice(indexed_surface, current_plane_to_world, prepared.origin_id, reach, 0.0)
	if recording:
		Chronology.finish(slice_span, {"valid": sliced.get("valid", false),
			"reason": sliced.get("status", ""), "counts": sliced.get("counts", {})})
	if not sliced.get("valid", false): return _fail("indexed_slice_failed", sliced)
	var counts: Dictionary = sliced.counts
	if sliced.contours.size() != 1 or counts.segments_clipped != 0 or counts.segments_outside_disk != 0 or counts.triangles_reach_pruned != 0 or counts.open_or_branched_vertices != 0 or counts.coplanar_triangles != 0:
		return _fail("requires_one_complete_noncoplanar_section", counts)
	var polygon: PackedVector2Array = sliced.contours[0].duplicate()
	if polygon[0] == polygon[-1]: polygon.remove_at(polygon.size() - 1)
	# The mature contour extractor omits cycles with invalid area/centroid. One
	# surviving loop must account for every emitted edge, including any omitted
	# disconnected component; otherwise it is not the complete current section.
	if int(counts.segments_emitted) != polygon.size():
		return _fail("section_contains_unrepresented_segments", counts)
	var edges: Array = []
	for index: int in polygon.size(): edges.append([polygon[index], polygon[(index + 1) % polygon.size()]])
	var topology_span: int = Chronology.begin("section.topology_prepare", {
		"plane_id": prepared.origin_id, "source_id": prepared.source_id,
		"segments": edges.size()}) if recording else 0
	var topology: Dictionary = _contact.prepare_target(edges, prepared.origin_id)
	if recording:
		var topology_counts: Dictionary = topology.get("topology", {})
		Chronology.finish(topology_span, {"valid": topology.get("valid", false),
			"topology_complete": topology.get("topology_complete", false),
			"reason": topology.get("reason", "" if topology.get("topology_complete", false) else "section_is_not_a_complete_simple_polygon"),
			"open_or_branched_vertices": topology_counts.get("open_or_branched_vertices", 0),
			"duplicate_edges": topology_counts.get("duplicate_edges", 0),
			"self_intersections": topology_counts.get("self_intersections", 0),
			"coplanar_edges": topology_counts.get("coplanar_edges", 0),
			"sub_epsilon_edges": topology_counts.get("sub_epsilon_edges", 0),
			"noncoincident_endpoint_welds": topology_counts.get("noncoincident_endpoint_welds", 0)})
	if not topology.get("valid", false) or not topology.get("topology_complete", false):
		return _fail("section_is_not_a_complete_simple_polygon", topology.get("topology", {}))
	var centroid_span: int = Chronology.begin("section.centroid", {
		"plane_id": prepared.origin_id, "source_id": prepared.source_id,
		"vertices": polygon.size()}) if recording else 0
	var center: Dictionary = Centroid._calculate_polygon_centroid_state(polygon)
	if recording:
		Chronology.finish(centroid_span, {"valid": center.get("valid", false),
			"reason": "" if center.get("valid", false) else "invalid_current_section_centroid"})
	if not center.get("valid", false): return _fail("invalid_current_section_centroid")
	var radius: float = 0.0
	for point: Vector2 in polygon: radius = maxf(radius, point.distance_to(center.centroid))
	return {"valid": true, "revision": REVISION, "polygon": polygon, "center": center.centroid,
		"required_enclosing_radius_m": radius, "origin_id": prepared.origin_id,
		"source_id": prepared.source_id, "surface_source_origin_id": prepared.source_id,
		"resolved_world_origin_id": prepared.resolved_world_origin_id,
		"plane": current_plane_to_world, "plane_to_world": current_plane_to_world,
		"complete": true, "planar_topology_complete": true, "metric_units": &"meters",
		"source_solid_topology_certified": false, "actual_3d_grip_verified": false,
		"counts": {"source_triangles": original.size() / 3, "indexed_triangles": indices.size(),
			"index_bins_visited": last - first + 1, "slice": counts},
		"slice_preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0}


func _bin(value: float, minimum: float, maximum: float, count: int) -> int:
	if count <= 1 or maximum <= minimum: return 0
	return clampi(int(floor((value - minimum) / (maximum - minimum) * count)), 0, count - 1)


func _dot_scalar(first: Vector3, second: Vector3) -> float:
	return float(first.x) * float(second.x) + float(first.y) * float(second.y) + float(first.z) * float(second.z)


func _maximum_component(point: Vector3) -> float:
	return maxf(absf(point.x), maxf(absf(point.y), absf(point.z)))


func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "detail": detail}
