extends SceneTree

func _init() -> void:
	var mesh := load("C:/WORKSPACE/godot_runs/forge_profile_transform_fluted/zero_fixed_boundary_mesh.res") as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var exact: Dictionary = {}
	var rounded: Dictionary = {}
	var zero := 0
	var smallest := INF
	for i in range(0, indices.size(), 3):
		var triangle := [vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]]
		var area: float = (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).length_squared()
		zero += int(area == 0.0)
		smallest = minf(smallest, area)
		for e in range(3):
			var a: Vector3 = triangle[e]
			var b: Vector3 = triangle[(e + 1) % 3]
			_edge(exact, var_to_bytes(a).hex_encode(), var_to_bytes(b).hex_encode())
			_edge(rounded, _rounded(a), _rounded(b))
	var report := {"triangles": indices.size() / 3, "zero_area": zero, "minimum_cross_squared": smallest,
		"exact_bad_edges": _bad(exact), "rounded_0_1_micrometer_bad_edges": _bad(rounded)}
	print(JSON.stringify(report))
	var file := FileAccess.open("C:/WORKSPACE/godot_runs/forge_v2_taper_tip_topology.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	quit()

func _rounded(p: Vector3) -> String:
	return "%d,%d,%d" % [roundi(p.x * 10000000), roundi(p.y * 10000000), roundi(p.z * 10000000)]

func _edge(counts: Dictionary, a: String, b: String) -> void:
	var key := a + "/" + b if a < b else b + "/" + a
	counts[key] = int(counts.get(key, 0)) + 1

func _bad(counts: Dictionary) -> int:
	var bad := 0
	for count: int in counts.values():
		bad += int(count != 2)
	return bad
