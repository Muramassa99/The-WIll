extends RefCounted
class_name ForgeV2ProfileSweepJoin

# Join independently capped sweep sections at discontinuous profile-size
# boundaries. This backend instance is private to the operand construction;
# it must never be the presenter's live material/history backend.
static func join_sections(meshes: Array[ArrayMesh]) -> Dictionary:
	var sections: Array[Dictionary] = []
	for mesh: ArrayMesh in meshes:
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		for surface_index in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface_index)
			if arrays.size() < Mesh.ARRAY_MAX:
				return _failure("profile_section_arrays_incomplete")
			var surface_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var surface_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if surface_vertices.is_empty() or surface_indices.is_empty():
				continue
			if surface_indices.size() % 3 != 0:
				return _failure("profile_section_triangle_indices_unaligned")
			var vertex_offset := vertices.size()
			for index: int in surface_indices:
				if index < 0 or index >= surface_vertices.size():
					return _failure("profile_section_triangle_index_invalid")
				indices.append(vertex_offset + index)
			vertices.append_array(surface_vertices)
		if not indices.is_empty():
			sections.append({"vertices": vertices, "indices": indices})
	if sections.is_empty():
		return {"ok": true, "empty": true, "vertices": PackedVector3Array(),
			"indices": PackedInt32Array(), "error": ""}
	if not ClassDB.class_exists(&"ForgeV2ManifoldBoolean"):
		return _failure("profile_section_join_native_backend_unavailable")
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as RefCounted
	if backend == null or not backend.has_method("reset_mesh") or not backend.has_method("add_mesh"):
		return _failure("profile_section_join_native_api_unavailable")
	var result: Dictionary = {}
	for section_index in range(sections.size()):
		var section := sections[section_index]
		# These existing native entry points import with the same vertex-merge
		# tolerance as Godot's CSG. They return Godot-facing triangle winding.
		result = backend.call("reset_mesh" if section_index == 0 else "add_mesh",
			section.vertices, section.indices) as Dictionary
		if not bool(result.get("ok", false)):
			return _failure("profile_section_join_%d:%s:%s" % [section_index,
				String(result.get("error_code", "native_failure")),
				String(result.get("error_message", "section join failed"))])
	var vertices: PackedVector3Array = result.get("vertices", PackedVector3Array())
	var indices: PackedInt32Array = result.get("indices", PackedInt32Array())
	return {"ok": true, "empty": vertices.is_empty() or indices.is_empty(),
		"vertices": vertices, "indices": indices, "error": ""}


static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "empty": true, "vertices": PackedVector3Array(),
		"indices": PackedInt32Array(), "error": reason}
