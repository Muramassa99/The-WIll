extends RefCounted

const SkinCapture = preload("res://runtime/player/grip/capture_coherent_skin_pose.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const SavedSource = preload("res://runtime/player/grip/saved_wrapper_grip_source.gd")
const OWNER := &"grip_placement_capture"
const OBJECT_ORIGIN := &"GripPlacementObjectMeshOrigin"
const GEOMETRY_POLICY := &"unaltered_surface_vertex_index_arrays_no_triangle_mesh"

## Scene read only. Geometry is copied without BVH preparation,
## remeshing, anatomy baking, pose application, or advancing a scene frame.
## supplied_pose is used only by the synchronous finger-input hook which has
## just captured that same pose; it is not a fallback for an earlier stage.
## A support acquisition supplies its explicit weapon-root-local pivot; choosing
## a hand slot alone does not imply that it is the primary or support grip.
func capture(actor: Node3D, held: Node3D, anatomy: Resource, slot: StringName, stage: StringName, serial: int, ordinal: int = 0, supplied_pose: Dictionary = {}, grip_pivot_override: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	var frame_id := Engine.get_process_frames()
	var header := {"valid": false, "stage": stage, "slot": slot,
		"transaction_serial": serial, "stage_ordinal": ordinal,
		"engine_process_frame": frame_id, "root_origin_id": Origins.ORIGIN_RL_BONE_ROOT,
		"resolve_phase": Origins.PHASE_EDITOR_PREVIEW,
		"production_pose_written": false, "actual_3d_grip_verified": false}
	if actor == null or held == null or anatomy == null or not actor.is_inside_tree() or not held.is_inside_tree():
		return _fail(header, "missing_live_placement_inputs")
	if slot not in [&"hand_right", &"hand_left"] or serial <= 0:
		return _fail(header, "invalid_placement_slot_or_transaction")
	var skeleton := actor.get("skeleton") as Skeleton3D
	var character_mesh := actor.get("mesh_instance") as MeshInstance3D
	var posed := supplied_pose.duplicate(true)
	if posed.is_empty():
		posed = SkinCapture.new().capture(skeleton, character_mesh,
			anatomy.get("reference_skin"), anatomy.get("source_signature"),
			StringName("%sPlacement%d%s%dFrame%d" % [String(slot), serial, String(stage), ordinal, frame_id]))
		posed["capture_stage"] = stage
		posed["engine_process_frame"] = frame_id
	if not bool(posed.get("valid", false)):
		return _fail(header, "coherent_pose_capture_failed", posed)
	if int(posed.get("engine_process_frame", -1)) != frame_id or StringName(posed.get("capture_stage")) != stage:
		return _fail(header, "supplied_pose_does_not_match_current_stage")
	if posed.get("anatomy_signature") != anatomy.get("source_signature") or posed.get("root_origin_id") != Origins.ORIGIN_RL_BONE_ROOT:
		return _fail(header, "pose_reference_or_root_mismatch")
	posed["transaction_serial"] = serial
	header["posed_character"] = posed
	var machine: Transform3D = posed.machine_to_world
	if not _valid_frame(machine):
		return _fail(header, "invalid_machine_frame")
	var world_to_machine := machine.affine_inverse()
	var object_mesh: MeshInstance3D
	for child: Node in held.get_children():
		if child is MeshInstance3D and child.get_meta("visual_mesh_source", StringName()) == &"editable_mesh":
			if object_mesh != null:
				return _fail(header, "multiple_editable_object_meshes_not_supported")
			object_mesh = child as MeshInstance3D
	if object_mesh == null or object_mesh.mesh == null:
		return _fail(header, "missing_current_object_mesh")
	var weapon_to_world := held.global_transform
	var mesh_to_world := object_mesh.global_transform
	if not _valid_frame(weapon_to_world) or not _valid_frame(mesh_to_world):
		return _fail(header, "invalid_current_object_frame")
	var extracted: Dictionary = extract_object_triangle_faces(object_mesh.mesh)
	if not bool(extracted.get("valid", false)):
		return _fail(header, "object_triangle_copy_failed", extracted)
	var local_faces: PackedVector3Array = extracted.local_faces
	var object := {"local_faces": local_faces,
		"local_faces_origin_id": OBJECT_ORIGIN,
		"local_face_sources": extracted.local_face_sources,
		"source_surface_count": extracted.source_surface_count,
		"origin_record": _record(OBJECT_ORIGIN, world_to_machine * mesh_to_world, Origins.SPACE_TYPE_PRESENTATION),
		"mesh_to_world": mesh_to_world, "mesh_to_world_origin_id": Origins.ORIGIN_RL_BONE_ROOT,
		"weapon_to_world": weapon_to_world, "weapon_to_world_origin_id": Origins.ORIGIN_RL_BONE_ROOT,
		"weapon_origin_record": _record(Origins.ORIGIN_WEAPON_ROOT, world_to_machine * weapon_to_world, Origins.SPACE_TYPE_WEAPON),
		"mesh_instance_id": object_mesh.get_instance_id(), "mesh_resource_id": object_mesh.mesh.get_instance_id(),
		"weapon_instance_id": held.get_instance_id(), "visual_mesh_source": &"editable_mesh",
		"geometry_policy": GEOMETRY_POLICY, "missing_metadata": []}
	var pivot_meta := "preview_primary_grip_seat_local"
	var pivot_origin_meta := "preview_primary_grip_seat_origin_id"
	if not held.has_meta(pivot_meta):
		pivot_meta = "primary_grip_contact_local"
		pivot_origin_meta = "primary_grip_contact_origin_id"
	if grip_pivot_override.is_empty():
		_copy_named_point(held, object, pivot_meta, pivot_origin_meta, "grip_pivot_local", "grip_pivot_local_origin_id")
		if object.has("grip_pivot_local"):
			object["grip_pivot_source_meta"] = pivot_meta
	else:
		var point: Variant = grip_pivot_override.get("point_local")
		var origin := StringName(grip_pivot_override.get("origin_id", StringName()))
		var source := String(grip_pivot_override.get("source", ""))
		if not point is Vector3 or not point.is_finite() or origin != Origins.ORIGIN_WEAPON_ROOT or source.is_empty():
			return _fail(header, "invalid_explicit_grip_pivot")
		object["grip_pivot_local"] = point
		object["grip_pivot_local_origin_id"] = origin
		object["grip_pivot_source_meta"] = source
		object["grip_pivot_explicit_override"] = true
	for end: String in ["start", "end"]:
		var field := "primary_grip_span_" + end + "_local"
		_copy_named_point(held, object, field, "primary_grip_span_" + end + "_origin_id", field, "primary_grip_span_" + end + "_origin_id")
	header["object"] = object
	# Already detached at equipped-item creation; numerical consumers read only.
	# Keep absent/invalid wrapper explicit rather than rebuilding during a grip.
	header["saved_grip_source"] = (held.get_meta(SavedSource.META, {}) as Dictionary).duplicate(true)
	if not actor.has_method("resolve_hand_grip_alignment_world_position"):
		return _fail(header, "missing_anatomical_reference_reader")
	# This existing reader lazily prepares animation baselines when cold. A
	# diagnostic may read an already established target, never trigger that work.
	var presenter: Object = actor.get("finger_grip_presenter") as Object
	if presenter == null or not bool(presenter.get("animation_grip_baseline_initialized")):
		return _fail(header, "anatomical_reference_baseline_not_initialized")
	var cache: Variant = presenter.get("animation_grip_baseline_cache")
	if not cache is Dictionary or not (cache as Dictionary).get(slot) is Dictionary:
		return _fail(header, "anatomical_reference_slot_cache_unavailable")
	var slot_cache: Dictionary = cache[slot]
	if slot_cache.is_empty() or StringName(slot_cache.get("joint_offset_origin_id", StringName())) != Origins.ORIGIN_HAND_GRIP_ALIGNMENT or not slot_cache.get("joint_offsets") is Dictionary:
		return _fail(header, "anatomical_reference_slot_cache_incomplete")
	for digit: StringName in [&"thumb", &"index"]:
		var offsets: Variant = slot_cache.joint_offsets.get(digit)
		if not offsets is Dictionary:
			return _fail(header, "anatomical_reference_joint_cache_unavailable")
		for joint: StringName in [&"root", &"mid", &"end"]:
			var offset: Variant = offsets.get(joint)
			if not offset is Vector3 or not (offset as Vector3).is_finite():
				return _fail(header, "anatomical_reference_joint_cache_incomplete")
	var anchor_method := "get_right_hand_item_anchor" if slot == &"hand_right" else "get_left_hand_item_anchor"
	if not actor.has_method(anchor_method) or actor.call(anchor_method) == null:
		return _fail(header, "missing_current_hand_anchor")
	var reference: Variant = actor.call("resolve_hand_grip_alignment_world_position", slot)
	if not reference is Vector3 or not (reference as Vector3).is_finite():
		return _fail(header, "invalid_anatomical_reference")
	header["anatomical_reference_world"] = reference
	header["anatomical_reference_origin_id"] = Origins.ORIGIN_RL_BONE_ROOT
	header["stage_reference_provenance"] = &"existing_derived_mount_target_not_measured_palm_center"
	header["valid"] = true
	header["object_triangle_count"] = local_faces.size() / 3
	header["capture_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	header["capture_timing_scope"] = &"diagnostic_scene_read_and_local_geometry_copy_excludes_reused_pose_capture" if not supplied_pose.is_empty() else &"diagnostic_scene_read_reference_validation_and_local_geometry_copy"
	header["reused_synchronous_pose_capture"] = not supplied_pose.is_empty()
	return header


## Read the rendered ArrayMesh triangle arrays directly. Mesh.get_faces()
## passes through TriangleMesh, whose 4.7 construction snaps vertex positions.
## https://docs.godotengine.org/en/4.7/classes/class_arraymesh.html
## https://github.com/godotengine/godot/blob/4.7/core/math/triangle_mesh.cpp
## No transform, welding, quantization, primitive conversion or fallback occurs.
func extract_object_triangle_faces(mesh: Mesh) -> Dictionary:
	if not mesh is ArrayMesh:
		return {"valid": false, "reason": "unsupported_object_mesh_type"}
	var array_mesh: ArrayMesh = mesh as ArrayMesh
	if array_mesh.get_surface_count() <= 0:
		return {"valid": false, "reason": "missing_object_triangle_surfaces"}
	var faces := PackedVector3Array()
	var sources: Array = []
	for surface: int in range(array_mesh.get_surface_count()):
		var copied: Dictionary = copy_triangle_surface_arrays(
			array_mesh.surface_get_arrays(surface),
			array_mesh.surface_get_primitive_type(surface), surface)
		if not bool(copied.get("valid", false)):
			return copied
		faces.append_array(copied.local_faces)
		sources.append_array(copied.local_face_sources)
	return {"valid": true, "local_faces": faces,
		"local_faces_origin_id": OBJECT_ORIGIN, "local_face_sources": sources,
		"source_surface_count": array_mesh.get_surface_count(),
		"geometry_policy": GEOMETRY_POLICY}


## Separate validation permits malformed-input tests without asking the render
## server to construct invalid mesh resources. Coordinates remain OBJECT_ORIGIN.
func copy_triangle_surface_arrays(arrays: Array, primitive: int, surface: int) -> Dictionary:
	var failure := {"valid": false, "surface_index": surface}
	if surface < 0 or primitive != Mesh.PRIMITIVE_TRIANGLES:
		return _fail(failure, "unsupported_object_surface_primitive_or_index")
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		return _fail(failure, "invalid_object_vertex_array")
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return _fail(failure, "missing_object_surface_vertices")
	for point: Vector3 in vertices:
		if not point.is_finite():
			return _fail(failure, "nonfinite_object_surface_vertex")
	var raw_indices: Variant = arrays[Mesh.ARRAY_INDEX]
	if raw_indices != null and not raw_indices is PackedInt32Array:
		return _fail(failure, "invalid_object_index_array")
	var indices: PackedInt32Array = raw_indices if raw_indices is PackedInt32Array else PackedInt32Array()
	var indexed: bool = not indices.is_empty()
	var count: int = indices.size() if indexed else vertices.size()
	if count % 3 != 0:
		return _fail(failure, "incomplete_object_triangle")
	var faces := PackedVector3Array()
	var sources: Array = []
	for start: int in range(0, count, 3):
		var vertex_indices := PackedInt32Array()
		for corner: int in range(3):
			var vertex: int = indices[start + corner] if indexed else start + corner
			if vertex < 0 or vertex >= vertices.size():
				return _fail(failure, "object_triangle_index_out_of_bounds")
			vertex_indices.append(vertex)
		var a: Vector3 = vertices[vertex_indices[0]]
		var b: Vector3 = vertices[vertex_indices[1]]
		var c: Vector3 = vertices[vertex_indices[2]]
		var cross: Vector3 = (b - a).cross(c - a)
		if not cross.is_finite() or cross == Vector3.ZERO:
			return _fail(failure, "degenerate_or_nonfinite_object_triangle")
		faces.append(a); faces.append(b); faces.append(c)
		sources.append({"surface_index": surface, "triangle_index": start / 3,
			"vertex_indices": vertex_indices, "indexed": indexed})
	return {"valid": true, "local_faces": faces, "local_faces_origin_id": OBJECT_ORIGIN,
		"local_face_sources": sources, "geometry_policy": GEOMETRY_POLICY}


func _copy_named_point(held: Node3D, object: Dictionary, meta: String, origin_meta: String, field: String, origin_field: String) -> void:
	if not held.has_meta(meta) or not held.has_meta(origin_meta):
		object.missing_metadata.append(field)
		return
	var point: Variant = held.get_meta(meta)
	var origin := StringName(held.get_meta(origin_meta))
	if not point is Vector3 or not (point as Vector3).is_finite() or origin == StringName():
		object.missing_metadata.append(field)
		return
	object[field] = point
	object[origin_field] = origin


func _record(id: StringName, to_machine: Transform3D, space: StringName) -> Dictionary:
	return {"origin_id": id, "parent_origin_id": Origins.ORIGIN_RL_BONE_ROOT,
		"transform_to_parent": to_machine, "owner_system": OWNER,
		"resolve_phase": Origins.PHASE_EDITOR_PREVIEW, "space_type": space, "is_dynamic": true}


func _valid_frame(frame: Transform3D) -> bool:
	return frame.is_finite() and is_finite(frame.basis.determinant()) and absf(frame.basis.determinant()) > 1.0e-12


func _fail(header: Dictionary, reason: String, details: Dictionary = {}) -> Dictionary:
	header["valid"] = false
	header["reason"] = reason
	header["details"] = details
	return header
