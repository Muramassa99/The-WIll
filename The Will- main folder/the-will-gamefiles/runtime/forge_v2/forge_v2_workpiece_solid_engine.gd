extends RefCounted
class_name ForgeV2WorkpieceSolidEngine

const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const BACKEND_ID := &"chunked_labelled_solid_v1"
const BACKEND_SCHEMA_VERSION := 2
const DEFAULT_CELL_SIZE_METERS := 0.004
const DEFAULT_CHUNK_DIMENSION := 16
const DEFAULT_PROCESSING_HALO_CHUNK_RINGS := 2
const MAX_PROCESSING_HALO_CHUNK_RINGS := 8
const MATERIAL_LABEL_EMPTY := 0
const MATERIAL_LABEL_PRIMARY := 1
const GEOMETRY_EPSILON := 0.000001
const COLLINEAR_TOLERANCE_METERS := 0.00002
const FRAME_DOT_TOLERANCE := 0.9999
const FRAME_ORTHOGONAL_DOT_TOLERANCE := 0.0001

const FACE_DIRECTIONS := [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]
const FACE_NORMALS := [
	Vector3.RIGHT,
	Vector3.LEFT,
	Vector3.UP,
	Vector3.DOWN,
	Vector3.BACK,
	Vector3.FORWARD,
]

# This 4 mm block field tests locality/scaling, NOT organic/final fidelity.
# Its label and protected channels show a material/Handle-extensible shape,
# but Handle semantics remain unproven and are deliberately not implemented.
var cell_size_meters := DEFAULT_CELL_SIZE_METERS
var chunk_dimension := DEFAULT_CHUNK_DIMENSION
var cells_per_chunk := DEFAULT_CHUNK_DIMENSION * DEFAULT_CHUNK_DIMENSION * DEFAULT_CHUNK_DIMENSION
var processing_halo_chunk_rings := DEFAULT_PROCESSING_HALO_CHUNK_RINGS
var chunks: Dictionary = {}
var initialized := false
var accepted_material_variant_id := StringName()
var revision := 0
var source_body_count := 0
var occupied_cell_count := 0
var total_quad_count := 0
var total_triangle_count := 0
var last_candidate_cell_count := 0
var last_examined_cell_count := 0
var last_world_aabb_cell_count := 0
var last_centerline_chunk_count := 0
var last_broadphase_chunk_count := 0
var last_intersecting_chunk_count := 0
var last_candidate_chunk_count := 0
var last_contact_cell_count := 0
var last_contact_chunk_count := 0
var last_new_only_chunk_count := 0
var last_candidate_component_count := 0
var last_attached_component_count := 0
var last_processing_context_chunk_count := 0
var last_resident_context_chunk_count := 0
var last_changed_cell_count := 0
var last_changed_chunk_count := 0
var last_remeshed_chunk_count := 0
var last_remesh_scanned_cell_count := 0
var last_remeshed_occupied_cell_count := 0
var last_remeshed_occupied_cell_min := 0
var last_remeshed_occupied_cell_max := 0
var last_rebuilt_quad_count := 0
var last_rebuilt_vertex_count := 0
var last_rebuilt_index_count := 0
var last_candidate_chunk_coords: Array[Vector3i] = []
var last_contact_chunk_coords: Array[Vector3i] = []
var last_processing_context_chunk_coords: Array[Vector3i] = []
var last_resident_context_chunk_coords: Array[Vector3i] = []
var last_changed_chunk_coords: Array[Vector3i] = []
var last_remeshed_chunk_coords: Array[Vector3i] = []


func initialize(
	next_cell_size_meters: float = DEFAULT_CELL_SIZE_METERS,
	next_chunk_dimension: int = DEFAULT_CHUNK_DIMENSION,
	next_processing_halo_chunk_rings: int = (
		DEFAULT_PROCESSING_HALO_CHUNK_RINGS
	)
) -> Dictionary:
	if (
		not is_finite(next_cell_size_meters)
		or next_cell_size_meters <= GEOMETRY_EPSILON
	):
		return {
			"ok": false,
			"error": "chunked_field_invalid_cell_size",
		}
	if next_chunk_dimension < 2 or next_chunk_dimension > 64:
		return {
			"ok": false,
			"error": "chunked_field_invalid_chunk_dimension",
		}
	if (
		next_processing_halo_chunk_rings < 1
		or next_processing_halo_chunk_rings
		> MAX_PROCESSING_HALO_CHUNK_RINGS
	):
		return {
			"ok": false,
			"error": "chunked_field_invalid_processing_halo_rings",
		}
	cell_size_meters = next_cell_size_meters
	chunk_dimension = next_chunk_dimension
	processing_halo_chunk_rings = next_processing_halo_chunk_rings
	cells_per_chunk = (
		chunk_dimension * chunk_dimension * chunk_dimension
	)
	initialized = true
	reset()
	return {
		"ok": true,
		"backend_id": String(BACKEND_ID),
		"backend_schema": BACKEND_SCHEMA_VERSION,
		"cell_size_meters": cell_size_meters,
		"chunk_dimension": chunk_dimension,
		"cells_per_chunk": cells_per_chunk,
		"processing_halo_chunk_rings": processing_halo_chunk_rings,
	}


func reset() -> void:
	chunks = {}
	accepted_material_variant_id = StringName()
	revision = 0
	source_body_count = 0
	occupied_cell_count = 0
	total_quad_count = 0
	total_triangle_count = 0
	last_candidate_cell_count = 0
	last_examined_cell_count = 0
	last_world_aabb_cell_count = 0
	last_centerline_chunk_count = 0
	last_broadphase_chunk_count = 0
	last_intersecting_chunk_count = 0
	last_candidate_chunk_count = 0
	last_contact_cell_count = 0
	last_contact_chunk_count = 0
	last_new_only_chunk_count = 0
	last_candidate_component_count = 0
	last_attached_component_count = 0
	last_processing_context_chunk_count = 0
	last_resident_context_chunk_count = 0
	last_changed_cell_count = 0
	last_changed_chunk_count = 0
	last_remeshed_chunk_count = 0
	last_remesh_scanned_cell_count = 0
	last_remeshed_occupied_cell_count = 0
	last_remeshed_occupied_cell_min = 0
	last_remeshed_occupied_cell_max = 0
	last_rebuilt_quad_count = 0
	last_rebuilt_vertex_count = 0
	last_rebuilt_index_count = 0
	last_candidate_chunk_coords = []
	last_contact_chunk_coords = []
	last_processing_context_chunk_coords = []
	last_resident_context_chunk_coords = []
	last_changed_chunk_coords = []
	last_remeshed_chunk_coords = []


func dispose() -> void:
	reset()
	initialized = false


func apply_body(body: Resource) -> Dictionary:
	if not initialized:
		return {
			"ok": false,
			"error": "chunked_field_not_initialized",
		}
	var result: Dictionary
	var initialized_seed := source_body_count == 0 and chunks.is_empty()
	if initialized_seed:
		result = initialize_seed(body)
	else:
		result = apply_add_body(body)
	result["apply_mode"] = (
		"first_body_seed" if initialized_seed else "incremental_add"
	)
	result["initialized_seed"] = initialized_seed and bool(result.get(
		"ok",
		false
	))
	return result


func rebuild_from_bodies(ordered_bodies: Array) -> Dictionary:
	if not initialized:
		return {
			"ok": false,
			"error": "chunked_field_not_initialized",
		}
	reset()
	for body_index in range(ordered_bodies.size()):
		var body_variant: Variant = ordered_bodies[body_index]
		if not body_variant is Resource:
			return {
				"ok": false,
				"error": "chunked_field_rebuild_body_invalid",
				"failed_body_index": body_index,
				"accepted_body_count": source_body_count,
			}
		var body := body_variant as Resource
		var body_result := apply_body(body)
		if bool(body_result.get("ok", false)):
			continue
		return {
			"ok": false,
			"error": String(body_result.get(
				"error",
				"chunked_field_rebuild_body_failed"
			)),
			"failed_body_index": body_index,
			"failed_body_id": String(body.get("body_id")),
			"accepted_body_count": source_body_count,
			"body_result": body_result,
		}
	var result := get_summary()
	result["ok"] = true
	result["rebuilt_body_count"] = source_body_count
	return result


func initialize_seed(body: Resource) -> Dictionary:
	var backend_entry_started := Time.get_ticks_usec()
	if not initialized:
		return {
			"ok": false,
			"error": "chunked_field_not_initialized",
		}
	if source_body_count != 0 or not chunks.is_empty():
		return {
			"ok": false,
			"error": "chunked_field_seed_already_initialized",
		}
	var validation_started := Time.get_ticks_usec()
	var validation := _validate_supported_body(body, StringName())
	var validation_ms := _elapsed_milliseconds(validation_started)
	if not bool(validation.get("ok", false)):
		return validation
	var raster_started := Time.get_ticks_usec()
	var raster_result := _rasterize_body(body, validation)
	var raster_ms := _elapsed_milliseconds(raster_started)
	if not bool(raster_result.get("ok", false)):
		return raster_result
	var candidate_chunks: Dictionary = raster_result.get(
		"candidate_chunks",
		{}
	) as Dictionary
	var candidate_count := int(raster_result.get("candidate_cell_count", 0))
	if candidate_count <= 0:
		return {
			"ok": false,
			"error": "chunked_field_seed_raster_empty",
			"raster_ms": raster_ms,
		}
	var update_started := Time.get_ticks_usec()
	var update_result := _apply_candidate_chunks(candidate_chunks)
	var update_ms := _elapsed_milliseconds(update_started)
	var changed_chunks: Array[Vector3i] = update_result.get(
		"changed_chunks",
		[]
	) as Array[Vector3i]
	var remesh_started := Time.get_ticks_usec()
	var remesh_result := _remesh_changed_chunks_and_neighbors(
		changed_chunks,
		update_result.get("boundary_neighbor_chunks", []) as Array[Vector3i]
	)
	var remesh_ms := _elapsed_milliseconds(remesh_started)
	var empty_attachment := {
		"contact_cell_count": 0,
		"contact_chunks": {},
		"candidate_component_count": 1,
		"attached_component_count": 1,
	}
	var empty_context := {
		"processing_context_chunks": {},
		"resident_context_chunks": {},
	}
	accepted_material_variant_id = StringName(body.get("material_variant_id"))
	source_body_count = 1
	# Revision zero is the initialized-but-empty engine. The first accepted
	# body must publish a distinct epoch so presenters cannot miss the seed.
	revision = 1
	_record_last_operation_metrics(
		raster_result,
		empty_attachment,
		empty_context,
		update_result,
		remesh_result
	)
	var result := _build_operation_result(
		raster_ms,
		update_ms,
		remesh_ms,
		_elapsed_milliseconds(backend_entry_started),
		candidate_count,
		last_changed_cell_count,
		last_changed_chunk_count,
		last_remeshed_chunk_count
	)
	result["validation_ms"] = validation_ms
	result["attachment_ms"] = 0.0
	result["context_build_ms"] = 0.0
	result["backend_entry_to_exit_ms"] = _elapsed_milliseconds(
		backend_entry_started
	)
	_append_last_locality_metrics(result)
	return result


func apply_add_body(body: Resource) -> Dictionary:
	var backend_entry_started := Time.get_ticks_usec()
	if not initialized:
		return {
			"ok": false,
			"error": "chunked_field_not_initialized",
		}
	if source_body_count <= 0 or chunks.is_empty():
		return {
			"ok": false,
			"error": "chunked_field_seed_required",
		}
	var validation_started := Time.get_ticks_usec()
	var validation := _validate_supported_body(
		body,
		accepted_material_variant_id
	)
	var validation_ms := _elapsed_milliseconds(validation_started)
	if not bool(validation.get("ok", false)):
		return validation
	var raster_started := Time.get_ticks_usec()
	var raster_result := _rasterize_body(body, validation)
	var raster_ms := _elapsed_milliseconds(raster_started)
	if not bool(raster_result.get("ok", false)):
		return raster_result
	var candidate_chunks: Dictionary = raster_result.get(
		"candidate_chunks",
		{}
	) as Dictionary
	var candidate_count := int(raster_result.get("candidate_cell_count", 0))
	if candidate_count <= 0:
		return {
			"ok": false,
			"error": "chunked_field_add_raster_empty",
			"raster_ms": raster_ms,
		}
	var attachment_started := Time.get_ticks_usec()
	var attachment := _inspect_candidate_attachment(candidate_chunks)
	var attachment_ms := _elapsed_milliseconds(attachment_started)
	if not bool(attachment.get("attached", false)):
		return {
			"ok": false,
			"error": "chunked_field_add_not_attached",
			"raster_ms": raster_ms,
			"candidate_cell_count": candidate_count,
			"overlap_cell_count": int(attachment.get(
				"overlap_cell_count",
				0
			)),
			"face_attachment_count": int(attachment.get(
				"face_attachment_count",
				0
			)),
			"candidate_component_count": int(attachment.get(
				"candidate_component_count",
				0
			)),
			"unattached_component_count": int(attachment.get(
				"unattached_component_count",
				0
			)),
		}
	var context_started := Time.get_ticks_usec()
	var context_result := _build_processing_context(
		attachment.get("contact_chunks", {}) as Dictionary
	)
	var context_ms := _elapsed_milliseconds(context_started)
	var update_started := Time.get_ticks_usec()
	var update_result := _apply_candidate_chunks(candidate_chunks)
	var update_ms := _elapsed_milliseconds(update_started)
	var changed_chunks: Array[Vector3i] = update_result.get(
		"changed_chunks",
		[]
	) as Array[Vector3i]
	var remesh_started := Time.get_ticks_usec()
	var remesh_result := _remesh_changed_chunks_and_neighbors(
		changed_chunks,
		update_result.get("boundary_neighbor_chunks", []) as Array[Vector3i]
	)
	var remesh_ms := _elapsed_milliseconds(remesh_started)
	revision += 1
	source_body_count += 1
	_record_last_operation_metrics(
		raster_result,
		attachment,
		context_result,
		update_result,
		remesh_result
	)
	var result := _build_operation_result(
		raster_ms,
		update_ms,
		remesh_ms,
		_elapsed_milliseconds(backend_entry_started),
		candidate_count,
		last_changed_cell_count,
		last_changed_chunk_count,
		last_remeshed_chunk_count
	)
	result["validation_ms"] = validation_ms
	result["attachment_ms"] = attachment_ms
	result["context_build_ms"] = context_ms
	result["backend_entry_to_exit_ms"] = _elapsed_milliseconds(
		backend_entry_started
	)
	result["overlap_cell_count"] = int(attachment.get(
		"overlap_cell_count",
		0
	))
	result["face_attachment_count"] = int(attachment.get(
		"face_attachment_count",
		0
	))
	_append_last_locality_metrics(result)
	return result


func get_combined_mesh() -> ArrayMesh:
	var combined_vertices := PackedVector3Array()
	var combined_normals := PackedVector3Array()
	var combined_indices := PackedInt32Array()
	var sorted_chunk_coords := _sorted_vector3i_keys(chunks)
	for chunk_coord: Vector3i in sorted_chunk_coords:
		var record: Dictionary = chunks.get(chunk_coord, {}) as Dictionary
		var mesh_arrays: Array = record.get("mesh_arrays", []) as Array
		if mesh_arrays.size() < Mesh.ARRAY_MAX:
			continue
		var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = mesh_arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
		if vertices.is_empty() or indices.is_empty():
			continue
		var vertex_offset := combined_vertices.size()
		combined_vertices.append_array(vertices)
		combined_normals.append_array(normals)
		for index: int in indices:
			combined_indices.append(vertex_offset + index)
	var mesh := ArrayMesh.new()
	if combined_vertices.is_empty() or combined_indices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = combined_vertices
	arrays[Mesh.ARRAY_NORMAL] = combined_normals
	arrays[Mesh.ARRAY_INDEX] = combined_indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func get_render_chunk_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for chunk_coord: Vector3i in _sorted_vector3i_keys(chunks):
		var record: Dictionary = chunks.get(chunk_coord, {}) as Dictionary
		var cached_mesh := record.get("mesh") as ArrayMesh
		if cached_mesh == null:
			cached_mesh = _build_array_mesh_from_arrays(
				record.get("mesh_arrays", []) as Array
			)
			record["mesh"] = cached_mesh
			chunks[chunk_coord] = record
		result.append({
			"chunk_coord": chunk_coord,
			"mesh": cached_mesh,
			"mesh_revision": int(record.get("mesh_revision", 0)),
			"material_variant_id": accepted_material_variant_id,
			"occupied_cell_count": int(record.get(
				"occupied_cell_count",
				0
			)),
		})
	return result


func get_material_usage_summary() -> Dictionary:
	# This is intentionally O(1). The authoritative primary-label count is
	# maintained during each accepted edit; usage publication never scans the
	# resident workpiece or rebuilds geometry.
	var cell_volume_equivalents := pow(
		cell_size_meters
		/ ForgeV2MaterialBodyScript.REFERENCE_CELL_WORLD_SIZE_METERS,
		3.0
	)
	var volume_cell_equivalents := (
		float(occupied_cell_count) * cell_volume_equivalents
	)
	var material_centi_units := int(round(
		volume_cell_equivalents
		/ ForgeV2MaterialBodyScript.CELL_EQUIVALENTS_PER_MATERIAL_UNIT
		* float(ForgeV2MaterialBodyScript.MATERIAL_UNIT_SCALE)
	))
	if occupied_cell_count > 0:
		material_centi_units = maxi(material_centi_units, 1)
	var material_units := (
		float(material_centi_units)
		/ float(ForgeV2MaterialBodyScript.MATERIAL_UNIT_SCALE)
	)
	var materials: Dictionary = {}
	if (
		occupied_cell_count > 0
		and accepted_material_variant_id != StringName()
	):
		materials[accepted_material_variant_id] = {
			"material_variant_id": accepted_material_variant_id,
			"rough_volume_cell_equivalents": volume_cell_equivalents,
			"rough_material_centi_units": material_centi_units,
			"rough_material_units": material_units,
			"ratio": 1.0,
		}
	return {
		"total_rough_volume_cell_equivalents": volume_cell_equivalents,
		"total_rough_material_centi_units": material_centi_units,
		"total_rough_material_units": material_units,
		"materials": materials,
	}


func get_summary() -> Dictionary:
	return {
		"backend_id": String(BACKEND_ID),
		"backend_schema": BACKEND_SCHEMA_VERSION,
		"revision": revision,
		"accepted_revision": revision,
		"source_body_count": source_body_count,
		"accepted_source_body_count": source_body_count,
		"chunk_count": chunks.size(),
		"chunks": chunks.size(),
		"occupied_cell_count": occupied_cell_count,
		"cells": occupied_cell_count,
		"total_quad_count": total_quad_count,
		"quads": total_quad_count,
		"total_triangle_count": total_triangle_count,
		"triangles": total_triangle_count,
		"last_candidate_cell_count": last_candidate_cell_count,
		"last_examined_cell_count": last_examined_cell_count,
		"last_world_aabb_cell_count": last_world_aabb_cell_count,
		"last_centerline_chunk_count": last_centerline_chunk_count,
		"last_broadphase_chunk_count": last_broadphase_chunk_count,
		"last_intersecting_chunk_count": last_intersecting_chunk_count,
		"last_candidate_chunk_count": last_candidate_chunk_count,
		"last_contact_cell_count": last_contact_cell_count,
		"last_contact_chunk_count": last_contact_chunk_count,
		"last_new_only_chunk_count": last_new_only_chunk_count,
		"last_candidate_component_count": last_candidate_component_count,
		"last_attached_component_count": last_attached_component_count,
		"last_processing_context_chunk_count": (
			last_processing_context_chunk_count
		),
		"last_resident_context_chunk_count": (
			last_resident_context_chunk_count
		),
		"last_changed_cell_count": last_changed_cell_count,
		"last_changed_chunk_count": last_changed_chunk_count,
		"last_remeshed_chunk_count": last_remeshed_chunk_count,
		"last_remesh_scanned_cell_count": last_remesh_scanned_cell_count,
		"last_remeshed_occupied_cell_count": (
			last_remeshed_occupied_cell_count
		),
		"last_remeshed_occupied_cell_min": (
			last_remeshed_occupied_cell_min
		),
		"last_remeshed_occupied_cell_max": (
			last_remeshed_occupied_cell_max
		),
		"last_rebuilt_quad_count": last_rebuilt_quad_count,
		"last_rebuilt_vertex_count": last_rebuilt_vertex_count,
		"last_rebuilt_index_count": last_rebuilt_index_count,
		"cell_size_meters": cell_size_meters,
		"chunk_dimension": chunk_dimension,
		"cells_per_chunk": cells_per_chunk,
		"chunk_world_size_meters": (
			cell_size_meters * float(chunk_dimension)
		),
		"processing_halo_chunk_rings": processing_halo_chunk_rings,
		"material_variant_id": String(accepted_material_variant_id),
		"live_csg_node_count": 0,
	}


func get_last_locality_debug_snapshot() -> Dictionary:
	return {
		"revision": revision,
		"cell_size_meters": cell_size_meters,
		"chunk_dimension": chunk_dimension,
		"chunk_world_size_meters": (
			cell_size_meters * float(chunk_dimension)
		),
		"processing_halo_chunk_rings": processing_halo_chunk_rings,
		"candidate_chunk_coords": last_candidate_chunk_coords.duplicate(),
		"contact_chunk_coords": last_contact_chunk_coords.duplicate(),
		"processing_context_chunk_coords": (
			last_processing_context_chunk_coords.duplicate()
		),
		"resident_context_chunk_coords": (
			last_resident_context_chunk_coords.duplicate()
		),
		"changed_chunk_coords": last_changed_chunk_coords.duplicate(),
		"remeshed_chunk_coords": last_remeshed_chunk_coords.duplicate(),
		"all_resident_chunk_coords": _sorted_vector3i_keys(chunks),
	}


func _validate_supported_body(
	body: Resource,
	expected_material_variant_id: StringName
) -> Dictionary:
	if body == null:
		return {
			"ok": false,
			"error": "chunked_field_body_missing",
		}
	var body_kind := StringName(body.get("body_kind"))
	match body_kind:
		ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE, \
		ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH:
			pass
		ForgeV2MaterialBodyScript.BODY_KIND_PLATFORM_SEED:
			return {
				"ok": false,
				"error": "chunked_field_platform_seed_unsupported",
			}
		ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE:
			return {
				"ok": false,
				"error": "chunked_field_handle_profile_unsupported",
			}
		ForgeV2MaterialBodyScript.BODY_KIND_PROFILE_EXTRUSION:
			return {
				"ok": false,
				"error": "chunked_field_profile_extrusion_unsupported",
			}
		_:
			return {
				"ok": false,
				"error": "chunked_field_body_kind_unsupported",
			}
	var operation_mode := StringName(body.get("operation_mode"))
	if operation_mode == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL:
		return {
			"ok": false,
			"error": "chunked_field_remove_material_unsupported",
		}
	if operation_mode != ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL:
		return {
			"ok": false,
			"error": "chunked_field_operation_unsupported",
		}
	var placement_policy := StringName(body.get("placement_policy"))
	if placement_policy == ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY:
		return {
			"ok": false,
			"error": "chunked_field_empty_only_unsupported",
		}
	if placement_policy != ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING:
		return {
			"ok": false,
			"error": "chunked_field_placement_policy_unsupported",
		}
	var shape_kind := StringName(body.get("shape_kind"))
	match shape_kind:
		ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH:
			pass
		ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH:
			return {
				"ok": false,
				"error": "chunked_field_capsule_path_unsupported",
			}
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH:
			return {
				"ok": false,
				"error": "chunked_field_spline_profile_path_unsupported",
			}
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH:
			return {
				"ok": false,
				"error": "chunked_field_spline_capsule_path_unsupported",
			}
		_:
			return {
				"ok": false,
				"error": "chunked_field_shape_kind_unsupported",
			}
	var material_variant_id := StringName(body.get("material_variant_id"))
	if material_variant_id == StringName():
		return {
			"ok": false,
			"error": "chunked_field_material_missing",
		}
	if (
		expected_material_variant_id != StringName()
		and material_variant_id != expected_material_variant_id
	):
		return {
			"ok": false,
			"error": "chunked_field_multiple_materials_unsupported",
			"expected_material_id": String(expected_material_variant_id),
			"received_material_id": String(material_variant_id),
		}
	if StringName(body.get("profile_id")) == StringName():
		return {
			"ok": false,
			"error": "chunked_field_saved_profile_required",
		}
	if int(body.get("profile_runtime_schema_version")) <= 0:
		return {
			"ok": false,
			"error": "chunked_field_saved_profile_runtime_required",
		}
	if (
		not body.has_method("uses_explicit_surface_contact_authority")
		or not bool(body.call("uses_explicit_surface_contact_authority"))
	):
		return {
			"ok": false,
			"error": "chunked_field_explicit_bc_required",
		}
	var path_points: PackedVector3Array = body.get("path_points")
	var path_normals: PackedVector3Array = body.get("path_surface_normals")
	var path_contacts: PackedVector3Array = body.get("path_contact_directions")
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	if path_points.size() < 2:
		return {
			"ok": false,
			"error": "chunked_field_path_too_short",
		}
	if (
		path_normals.size() != path_points.size()
		or path_contacts.size() != path_points.size()
	):
		return {
			"ok": false,
			"error": "chunked_field_explicit_frame_count_mismatch",
		}
	if polygon.size() < 3:
		return {
			"ok": false,
			"error": "chunked_field_profile_polygon_invalid",
		}
	if not is_finite(float(body.get("profile_rotation_bias_degrees"))):
		return {
			"ok": false,
			"error": "chunked_field_profile_rotation_not_finite",
		}
	if (
		not is_finite(float(body.get("profile_twist_degrees_per_meter")))
		or not is_zero_approx(float(body.get(
			"profile_twist_degrees_per_meter"
		)))
	):
		return {
			"ok": false,
			"error": "chunked_field_profile_twist_unsupported",
		}
	for point: Vector3 in path_points:
		if not _is_finite_vector3(point):
			return {
				"ok": false,
				"error": "chunked_field_path_point_not_finite",
			}
	for normal: Vector3 in path_normals:
		if (
			not _is_finite_vector3(normal)
			or normal.length_squared() <= GEOMETRY_EPSILON
		):
			return {
				"ok": false,
				"error": "chunked_field_surface_normal_invalid",
			}
	for contact: Vector3 in path_contacts:
		if (
			not _is_finite_vector3(contact)
			or contact.length_squared() <= GEOMETRY_EPSILON
		):
			return {
				"ok": false,
				"error": "chunked_field_contact_direction_invalid",
			}
	for profile_point: Vector2 in polygon:
		if not is_finite(profile_point.x) or not is_finite(profile_point.y):
			return {
				"ok": false,
				"error": "chunked_field_profile_point_not_finite",
			}
	var frame_result := _resolve_piecewise_linear_explicit_frames(
		body,
		path_points
	)
	if not bool(frame_result.get("ok", false)):
		return frame_result
	var validation := {
		"ok": true,
		"uses_straight_fast_path": false,
		"point_tangents": frame_result.get(
			"point_tangents",
			PackedVector3Array()
		),
		"point_axis_x": frame_result.get(
			"point_axis_x",
			PackedVector3Array()
		),
		"point_axis_y": frame_result.get(
			"point_axis_y",
			PackedVector3Array()
		),
		"nonzero_segment_count": int(frame_result.get(
			"nonzero_segment_count",
			0
		)),
	}
	# Preserve the exact mature benchmark path and counters for the established
	# straight, constant-frame subset. Curves and changing frames take the new
	# ruled-segment path below.
	var path_result := _resolve_straight_path(path_points)
	if bool(path_result.get("ok", false)):
		var constant_frame := _resolve_constant_explicit_frame(
			body,
			path_result.get("tangent", Vector3.RIGHT) as Vector3
		)
		if bool(constant_frame.get("ok", false)):
			validation["uses_straight_fast_path"] = true
			validation["path_origin"] = path_result.get(
				"origin",
				Vector3.ZERO
			)
			validation["path_tangent"] = path_result.get(
				"tangent",
				Vector3.RIGHT
			)
			validation["path_length"] = float(path_result.get(
				"length",
				0.0
			))
			validation["axis_x"] = constant_frame.get(
				"axis_x",
				Vector3.RIGHT
			)
			validation["axis_y"] = constant_frame.get(
				"axis_y",
				Vector3.UP
			)
	return validation


func _resolve_piecewise_linear_explicit_frames(
	body: Resource,
	path_points: PackedVector3Array
) -> Dictionary:
	var nonzero_segment_count := 0
	for point_index in range(path_points.size() - 1):
		if (
			path_points[point_index].distance_squared_to(
				path_points[point_index + 1]
			)
			> GEOMETRY_EPSILON * GEOMETRY_EPSILON
		):
			nonzero_segment_count += 1
	if nonzero_segment_count <= 0:
		return {
			"ok": false,
			"error": "chunked_field_path_extent_invalid",
		}
	var path_normals: PackedVector3Array = body.get("path_surface_normals")
	var path_contacts: PackedVector3Array = body.get(
		"path_contact_directions"
	)
	var contact_direction_2d: Vector2 = body.get(
		"profile_contact_direction_2d"
	)
	var contact_relative_2d: Vector2 = body.get(
		"profile_contact_point_relative_2d_meters"
	)
	var rotation_bias := float(body.get("profile_rotation_bias_degrees"))
	var point_tangents := PackedVector3Array()
	var point_axis_x := PackedVector3Array()
	var point_axis_y := PackedVector3Array()
	for point_index in range(path_points.size()):
		var point_tangent := (
			ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
				path_points,
				point_index
			)
		)
		var frame := (
			ForgeV2ProfileShapeLibraryScript.resolve_explicit_surface_profile_path_frame(
				point_tangent,
				path_normals[point_index],
				contact_direction_2d,
				contact_relative_2d,
				path_contacts[point_index],
				rotation_bias
			)
		)
		if not bool(frame.get("valid", false)):
			return {
				"ok": false,
				"error": "chunked_field_explicit_frame_invalid",
				"point_index": point_index,
			}
		var resolved_tangent: Vector3 = frame.get(
			"tangent",
			Vector3.ZERO
		) as Vector3
		var axis_x: Vector3 = frame.get("axis_x", Vector3.ZERO) as Vector3
		var axis_y: Vector3 = frame.get("axis_y", Vector3.ZERO) as Vector3
		var gram_determinant := (
			axis_x.dot(axis_x) * axis_y.dot(axis_y)
			- pow(axis_x.dot(axis_y), 2.0)
		)
		if (
			not _is_finite_vector3(resolved_tangent)
			or not _is_finite_vector3(axis_x)
			or not _is_finite_vector3(axis_y)
			or resolved_tangent.length_squared() <= GEOMETRY_EPSILON
			or gram_determinant <= 0.000000000001
		):
			return {
				"ok": false,
				"error": "chunked_field_explicit_frame_invalid",
				"point_index": point_index,
			}
		point_tangents.append(resolved_tangent)
		point_axis_x.append(axis_x)
		point_axis_y.append(axis_y)
	return {
		"ok": true,
		"point_tangents": point_tangents,
		"point_axis_x": point_axis_x,
		"point_axis_y": point_axis_y,
		"nonzero_segment_count": nonzero_segment_count,
	}


func _resolve_straight_path(path_points: PackedVector3Array) -> Dictionary:
	var origin := path_points[0]
	var final_delta := path_points[path_points.size() - 1] - origin
	var path_length := final_delta.length()
	if path_length <= GEOMETRY_EPSILON:
		return {
			"ok": false,
			"error": "chunked_field_path_extent_invalid",
		}
	var tangent := final_delta / path_length
	var previous_projection := -GEOMETRY_EPSILON
	for point: Vector3 in path_points:
		var delta := point - origin
		var projection := delta.dot(tangent)
		var off_axis := delta - tangent * projection
		if off_axis.length() > COLLINEAR_TOLERANCE_METERS:
			return {
				"ok": false,
				"error": "chunked_field_non_straight_path_unsupported",
			}
		if (
			projection + COLLINEAR_TOLERANCE_METERS < previous_projection
			or projection < -COLLINEAR_TOLERANCE_METERS
			or projection > path_length + COLLINEAR_TOLERANCE_METERS
		):
			return {
				"ok": false,
				"error": "chunked_field_non_monotonic_path_unsupported",
			}
		previous_projection = projection
	return {
		"ok": true,
		"origin": origin,
		"tangent": tangent,
		"length": path_length,
	}


func _resolve_constant_explicit_frame(
	body: Resource,
	path_tangent: Vector3
) -> Dictionary:
	var path_normals: PackedVector3Array = body.get("path_surface_normals")
	var path_contacts: PackedVector3Array = body.get("path_contact_directions")
	var contact_direction_2d: Vector2 = body.get("profile_contact_direction_2d")
	var contact_relative_2d: Vector2 = body.get(
		"profile_contact_point_relative_2d_meters"
	)
	var rotation_bias := float(body.get("profile_rotation_bias_degrees"))
	var first_frame: Dictionary = {}
	for point_index in range(path_normals.size()):
		var frame := (
			ForgeV2ProfileShapeLibraryScript.resolve_explicit_surface_profile_path_frame(
				path_tangent,
				path_normals[point_index],
				contact_direction_2d,
				contact_relative_2d,
				path_contacts[point_index],
				rotation_bias
			)
		)
		if not bool(frame.get("valid", false)):
			return {
				"ok": false,
				"error": "chunked_field_explicit_frame_invalid",
			}
		var axis_x: Vector3 = frame.get("axis_x", Vector3.ZERO) as Vector3
		var axis_y: Vector3 = frame.get("axis_y", Vector3.ZERO) as Vector3
		if (
			not _is_finite_vector3(axis_x)
			or not _is_finite_vector3(axis_y)
			or axis_x.length_squared() <= GEOMETRY_EPSILON
			or axis_y.length_squared() <= GEOMETRY_EPSILON
		):
			return {
				"ok": false,
				"error": "chunked_field_explicit_frame_invalid",
			}
		if point_index == 0:
			first_frame = frame
			continue
		var first_axis_x: Vector3 = first_frame.get(
			"axis_x",
			Vector3.RIGHT
		) as Vector3
		var first_axis_y: Vector3 = first_frame.get(
			"axis_y",
			Vector3.UP
		) as Vector3
		if (
			axis_x.dot(first_axis_x) < FRAME_DOT_TOLERANCE
			or axis_y.dot(first_axis_y) < FRAME_DOT_TOLERANCE
		):
			return {
				"ok": false,
				"error": "chunked_field_varying_explicit_frame_unsupported",
			}
	var resolved_tangent: Vector3 = first_frame.get(
		"tangent",
		Vector3.ZERO
	) as Vector3
	var first_axis_x: Vector3 = first_frame.get(
		"axis_x",
		Vector3.ZERO
	) as Vector3
	var first_axis_y: Vector3 = first_frame.get(
		"axis_y",
		Vector3.ZERO
	) as Vector3
	if (
		resolved_tangent.length_squared() <= GEOMETRY_EPSILON
		or resolved_tangent.dot(path_tangent) < FRAME_DOT_TOLERANCE
		or absf(first_axis_x.dot(path_tangent))
		> FRAME_ORTHOGONAL_DOT_TOLERANCE
		or absf(first_axis_y.dot(path_tangent))
		> FRAME_ORTHOGONAL_DOT_TOLERANCE
		or absf(first_axis_x.dot(first_axis_y))
		> FRAME_ORTHOGONAL_DOT_TOLERANCE
	):
		return {
			"ok": false,
			"error": "chunked_field_path_frame_tangent_mismatch",
		}
	return {
		"ok": true,
		"axis_x": first_axis_x,
		"axis_y": first_axis_y,
	}


func _rasterize_body(body: Resource, validation: Dictionary) -> Dictionary:
	if bool(validation.get("uses_straight_fast_path", false)):
		return _rasterize_straight_body(body, validation)
	return _rasterize_ruled_polyline_body(body, validation)


func _rasterize_straight_body(
	body: Resource,
	validation: Dictionary
) -> Dictionary:
	var origin: Vector3 = validation.get("path_origin", Vector3.ZERO) as Vector3
	var tangent: Vector3 = validation.get(
		"path_tangent",
		Vector3.RIGHT
	) as Vector3
	var path_length := float(validation.get("path_length", 0.0))
	var axis_x: Vector3 = validation.get("axis_x", Vector3.RIGHT) as Vector3
	var axis_y: Vector3 = validation.get("axis_y", Vector3.UP) as Vector3
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	var bounds_min := Vector3(INF, INF, INF)
	var bounds_max := Vector3(-INF, -INF, -INF)
	var profile_world_support := Vector3.ZERO
	for longitudinal_offset in [0.0, path_length]:
		var ring_center := origin + tangent * float(longitudinal_offset)
		for profile_point: Vector2 in polygon:
			var profile_world_offset := (
				axis_x * profile_point.x
				+ axis_y * profile_point.y
			)
			profile_world_support = profile_world_support.max(
				profile_world_offset.abs()
			)
			var world_point := (
				ring_center
				+ profile_world_offset
			)
			bounds_min = bounds_min.min(world_point)
			bounds_max = bounds_max.max(world_point)
	if not _is_finite_vector3(bounds_min) or not _is_finite_vector3(bounds_max):
		return {
			"ok": false,
			"error": "chunked_field_raster_bounds_invalid",
		}
	var min_cell := _world_to_cell(bounds_min)
	var max_cell := _world_to_cell(bounds_max)
	var world_aabb_cell_count := (
		(max_cell.x - min_cell.x + 1)
		* (max_cell.y - min_cell.y + 1)
		* (max_cell.z - min_cell.z + 1)
	)
	var path_end := origin + tangent * path_length
	var scan_selection := _select_operation_scan_chunks(
		origin,
		path_end,
		profile_world_support,
		bounds_min,
		bounds_max
	)
	if not bool(scan_selection.get("ok", false)):
		return scan_selection
	var scan_chunk_coords: Array[Vector3i] = scan_selection.get(
		"intersecting_chunk_coords",
		[]
	) as Array[Vector3i]
	var candidate_chunks: Dictionary = {}
	var candidate_count := 0
	var examined_cell_count := 0
	for chunk_coord: Vector3i in scan_chunk_coords:
		var chunk_min_cell := chunk_coord * chunk_dimension
		var chunk_max_cell := (
			chunk_min_cell
			+ Vector3i.ONE * (chunk_dimension - 1)
		)
		var clipped_min := Vector3i(
			maxi(min_cell.x, chunk_min_cell.x),
			maxi(min_cell.y, chunk_min_cell.y),
			maxi(min_cell.z, chunk_min_cell.z)
		)
		var clipped_max := Vector3i(
			mini(max_cell.x, chunk_max_cell.x),
			mini(max_cell.y, chunk_max_cell.y),
			mini(max_cell.z, chunk_max_cell.z)
		)
		if (
			clipped_min.x > clipped_max.x
			or clipped_min.y > clipped_max.y
			or clipped_min.z > clipped_max.z
		):
			continue
		for cell_x in range(clipped_min.x, clipped_max.x + 1):
			for cell_y in range(clipped_min.y, clipped_max.y + 1):
				for cell_z in range(clipped_min.z, clipped_max.z + 1):
					examined_cell_count += 1
					var cell_coord := Vector3i(cell_x, cell_y, cell_z)
					var cell_center := _cell_center_world(cell_coord)
					var relative := cell_center - origin
					var longitudinal := relative.dot(tangent)
					if (
						longitudinal < -GEOMETRY_EPSILON
						or longitudinal > path_length + GEOMETRY_EPSILON
					):
						continue
					var profile_point := Vector2(
						relative.dot(axis_x),
						relative.dot(axis_y)
					)
					if not _point_inside_or_on_polygon(profile_point, polygon):
						continue
					var candidate_chunk_coord := _cell_to_chunk(cell_coord)
					var local_coord := _cell_to_local(
						cell_coord,
						candidate_chunk_coord
					)
					var local_index := _flatten_local(local_coord)
					var local_indices: PackedInt32Array = candidate_chunks.get(
						candidate_chunk_coord,
						PackedInt32Array()
					) as PackedInt32Array
					local_indices.append(local_index)
					candidate_chunks[candidate_chunk_coord] = local_indices
					candidate_count += 1
	return {
		"ok": true,
		"candidate_chunks": candidate_chunks,
		"candidate_cell_count": candidate_count,
		"candidate_chunk_count": candidate_chunks.size(),
		"examined_cell_count": examined_cell_count,
		"world_aabb_cell_count": world_aabb_cell_count,
		"centerline_chunk_count": int(scan_selection.get(
			"centerline_chunk_count",
			0
		)),
		"broadphase_chunk_count": int(scan_selection.get(
			"broadphase_chunk_count",
			0
		)),
		"intersecting_chunk_count": scan_chunk_coords.size(),
		"intersecting_chunk_coords": scan_chunk_coords,
	}


func _rasterize_ruled_polyline_body(
	body: Resource,
	validation: Dictionary
) -> Dictionary:
	var path_points: PackedVector3Array = body.get("path_points")
	var point_axis_x: PackedVector3Array = validation.get(
		"point_axis_x",
		PackedVector3Array()
	) as PackedVector3Array
	var point_axis_y: PackedVector3Array = validation.get(
		"point_axis_y",
		PackedVector3Array()
	) as PackedVector3Array
	if (
		point_axis_x.size() != path_points.size()
		or point_axis_y.size() != path_points.size()
	):
		return {
			"ok": false,
			"error": "chunked_field_internal_frame_count_mismatch",
		}
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	var candidate_sets: Dictionary = {}
	var centerline_chunk_set: Dictionary = {}
	var broadphase_chunk_set: Dictionary = {}
	var intersecting_chunk_set: Dictionary = {}
	var examined_cell_count := 0
	var world_aabb_cell_count := 0
	for segment_index in range(path_points.size() - 1):
		var segment_start := path_points[segment_index]
		var segment_end := path_points[segment_index + 1]
		if (
			segment_start.distance_squared_to(segment_end)
			<= GEOMETRY_EPSILON * GEOMETRY_EPSILON
		):
			continue
		var segment_result := _rasterize_ruled_segment(
			segment_start,
			segment_end,
			point_axis_x[segment_index],
			point_axis_y[segment_index],
			point_axis_x[segment_index + 1],
			point_axis_y[segment_index + 1],
			polygon
		)
		if not bool(segment_result.get("ok", false)):
			segment_result["segment_index"] = segment_index
			return segment_result
		_merge_candidate_chunk_sets(
			candidate_sets,
			segment_result.get("candidate_chunks", {}) as Dictionary
		)
		_merge_vector3i_array_into_set(
			centerline_chunk_set,
			segment_result.get("centerline_chunk_coords", []) as Array
		)
		_merge_vector3i_array_into_set(
			broadphase_chunk_set,
			segment_result.get("broadphase_chunk_coords", []) as Array
		)
		_merge_vector3i_array_into_set(
			intersecting_chunk_set,
			segment_result.get("intersecting_chunk_coords", []) as Array
		)
		examined_cell_count += int(segment_result.get(
			"examined_cell_count",
			0
		))
		world_aabb_cell_count += int(segment_result.get(
			"world_aabb_cell_count",
			0
		))
	var candidate_chunks := _candidate_sets_to_packed_chunks(candidate_sets)
	var candidate_count := 0
	for chunk_coord: Vector3i in _sorted_vector3i_keys(candidate_chunks):
		var local_indices: PackedInt32Array = candidate_chunks.get(
			chunk_coord,
			PackedInt32Array()
		) as PackedInt32Array
		candidate_count += local_indices.size()
	return {
		"ok": true,
		"candidate_chunks": candidate_chunks,
		"candidate_cell_count": candidate_count,
		"candidate_chunk_count": candidate_chunks.size(),
		"examined_cell_count": examined_cell_count,
		"world_aabb_cell_count": world_aabb_cell_count,
		"centerline_chunk_count": centerline_chunk_set.size(),
		"broadphase_chunk_count": broadphase_chunk_set.size(),
		"intersecting_chunk_count": intersecting_chunk_set.size(),
		"intersecting_chunk_coords": _sorted_vector3i_keys(
			intersecting_chunk_set
		),
	}


func _rasterize_ruled_segment(
	segment_start: Vector3,
	segment_end: Vector3,
	from_axis_x: Vector3,
	from_axis_y: Vector3,
	to_axis_x: Vector3,
	to_axis_y: Vector3,
	polygon: PackedVector2Array
) -> Dictionary:
	var segment := segment_end - segment_start
	var segment_length := segment.length()
	if segment_length <= GEOMETRY_EPSILON:
		return {
			"ok": false,
			"error": "chunked_field_path_segment_extent_invalid",
		}
	var tangent := segment / segment_length
	var bounds_min := Vector3(INF, INF, INF)
	var bounds_max := Vector3(-INF, -INF, -INF)
	var profile_world_support := Vector3.ZERO
	for profile_point: Vector2 in polygon:
		var from_offset := (
			from_axis_x * profile_point.x
			+ from_axis_y * profile_point.y
		)
		var to_offset := (
			to_axis_x * profile_point.x
			+ to_axis_y * profile_point.y
		)
		profile_world_support = profile_world_support.max(
			from_offset.abs()
		).max(to_offset.abs())
		var from_world_point := segment_start + from_offset
		var to_world_point := segment_end + to_offset
		bounds_min = bounds_min.min(from_world_point).min(to_world_point)
		bounds_max = bounds_max.max(from_world_point).max(to_world_point)
	if not _is_finite_vector3(bounds_min) or not _is_finite_vector3(bounds_max):
		return {
			"ok": false,
			"error": "chunked_field_raster_bounds_invalid",
		}
	var min_cell := _world_to_cell(bounds_min)
	var max_cell := _world_to_cell(bounds_max)
	var world_aabb_cell_count := (
		(max_cell.x - min_cell.x + 1)
		* (max_cell.y - min_cell.y + 1)
		* (max_cell.z - min_cell.z + 1)
	)
	var scan_selection := _select_operation_scan_chunks(
		segment_start,
		segment_end,
		profile_world_support,
		bounds_min,
		bounds_max
	)
	if not bool(scan_selection.get("ok", false)):
		return scan_selection
	var scan_chunk_coords: Array[Vector3i] = scan_selection.get(
		"intersecting_chunk_coords",
		[]
	) as Array[Vector3i]
	var candidate_chunks: Dictionary = {}
	var examined_cell_count := 0
	for chunk_coord: Vector3i in scan_chunk_coords:
		var chunk_min_cell := chunk_coord * chunk_dimension
		var chunk_max_cell := (
			chunk_min_cell + Vector3i.ONE * (chunk_dimension - 1)
		)
		var clipped_min := Vector3i(
			maxi(min_cell.x, chunk_min_cell.x),
			maxi(min_cell.y, chunk_min_cell.y),
			maxi(min_cell.z, chunk_min_cell.z)
		)
		var clipped_max := Vector3i(
			mini(max_cell.x, chunk_max_cell.x),
			mini(max_cell.y, chunk_max_cell.y),
			mini(max_cell.z, chunk_max_cell.z)
		)
		if (
			clipped_min.x > clipped_max.x
			or clipped_min.y > clipped_max.y
			or clipped_min.z > clipped_max.z
		):
			continue
		for cell_x in range(clipped_min.x, clipped_max.x + 1):
			for cell_y in range(clipped_min.y, clipped_max.y + 1):
				for cell_z in range(clipped_min.z, clipped_max.z + 1):
					examined_cell_count += 1
					var cell_coord := Vector3i(cell_x, cell_y, cell_z)
					if not _cell_inside_ruled_segment(
						_cell_center_world(cell_coord),
						segment_start,
						tangent,
						segment_length,
						from_axis_x,
						from_axis_y,
						to_axis_x,
						to_axis_y,
						polygon
					):
						continue
					var candidate_chunk_coord := _cell_to_chunk(cell_coord)
					var local_coord := _cell_to_local(
						cell_coord,
						candidate_chunk_coord
					)
					var local_indices: PackedInt32Array = candidate_chunks.get(
						candidate_chunk_coord,
						PackedInt32Array()
					) as PackedInt32Array
					local_indices.append(_flatten_local(local_coord))
					candidate_chunks[candidate_chunk_coord] = local_indices
	return {
		"ok": true,
		"candidate_chunks": candidate_chunks,
		"examined_cell_count": examined_cell_count,
		"world_aabb_cell_count": world_aabb_cell_count,
		"centerline_chunk_coords": scan_selection.get(
			"centerline_chunk_coords",
			[]
		),
		"broadphase_chunk_coords": scan_selection.get(
			"broadphase_chunk_coords",
			[]
		),
		"intersecting_chunk_coords": scan_chunk_coords,
	}


func _cell_inside_ruled_segment(
	cell_center: Vector3,
	segment_start: Vector3,
	tangent: Vector3,
	segment_length: float,
	from_axis_x: Vector3,
	from_axis_y: Vector3,
	to_axis_x: Vector3,
	to_axis_y: Vector3,
	polygon: PackedVector2Array
) -> bool:
	var relative := cell_center - segment_start
	var distance_along_path := relative.dot(tangent)
	if distance_along_path < 0.0 or distance_along_path > segment_length:
		return false
	var segment_ratio := clampf(
		distance_along_path / segment_length,
		0.0,
		1.0
	)
	var axis_x := from_axis_x.lerp(to_axis_x, segment_ratio)
	var axis_y := from_axis_y.lerp(to_axis_y, segment_ratio)
	var axis_x_squared := axis_x.dot(axis_x)
	var axis_x_axis_y := axis_x.dot(axis_y)
	var axis_y_squared := axis_y.dot(axis_y)
	var gram_determinant := (
		axis_x_squared * axis_y_squared
		- axis_x_axis_y * axis_x_axis_y
	)
	if gram_determinant <= 0.000000000001:
		return false
	var profile_center := (
		segment_start + tangent * distance_along_path
	)
	var lateral_position := cell_center - profile_center
	var lateral_axis_x := lateral_position.dot(axis_x)
	var lateral_axis_y := lateral_position.dot(axis_y)
	var profile_point := Vector2(
		(
			lateral_axis_x * axis_y_squared
			- lateral_axis_y * axis_x_axis_y
		) / gram_determinant,
		(
			lateral_axis_y * axis_x_squared
			- lateral_axis_x * axis_x_axis_y
		) / gram_determinant
	)
	return _point_inside_or_on_polygon(profile_point, polygon)


func _merge_candidate_chunk_sets(
	target_sets: Dictionary,
	source_chunks: Dictionary
) -> void:
	for chunk_coord: Vector3i in _sorted_vector3i_keys(source_chunks):
		var local_set: Dictionary = target_sets.get(chunk_coord, {}) as Dictionary
		var local_indices: PackedInt32Array = source_chunks.get(
			chunk_coord,
			PackedInt32Array()
		) as PackedInt32Array
		for local_index: int in local_indices:
			local_set[local_index] = true
		target_sets[chunk_coord] = local_set


func _candidate_sets_to_packed_chunks(candidate_sets: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for chunk_coord: Vector3i in _sorted_vector3i_keys(candidate_sets):
		var local_set: Dictionary = candidate_sets.get(chunk_coord, {}) as Dictionary
		var sorted_indices: Array = local_set.keys()
		sorted_indices.sort()
		var packed_indices := PackedInt32Array()
		for local_index_variant: Variant in sorted_indices:
			packed_indices.append(int(local_index_variant))
		if not packed_indices.is_empty():
			result[chunk_coord] = packed_indices
	return result


func _merge_vector3i_array_into_set(
	target_set: Dictionary,
	coords: Array
) -> void:
	for coord_variant: Variant in coords:
		if coord_variant is Vector3i:
			target_set[coord_variant as Vector3i] = true


func _select_operation_scan_chunks(
	segment_start: Vector3,
	segment_end: Vector3,
	profile_world_support: Vector3,
	bounds_min: Vector3,
	bounds_max: Vector3
) -> Dictionary:
	var centerline_chunks := _traverse_segment_chunks(
		segment_start,
		segment_end
	)
	if centerline_chunks.is_empty():
		return {
			"ok": false,
			"error": "chunked_field_centerline_chunk_traversal_empty",
		}
	var chunk_world_size := cell_size_meters * float(chunk_dimension)
	var half_cell := Vector3.ONE * cell_size_meters * 0.5
	var support := profile_world_support + half_cell
	var support_rings := Vector3i(
		ceili(support.x / chunk_world_size) + 1,
		ceili(support.y / chunk_world_size) + 1,
		ceili(support.z / chunk_world_size) + 1
	)
	var broadphase_set: Dictionary = {}
	for centerline_chunk: Vector3i in centerline_chunks:
		for offset_x in range(-support_rings.x, support_rings.x + 1):
			for offset_y in range(-support_rings.y, support_rings.y + 1):
				for offset_z in range(-support_rings.z, support_rings.z + 1):
					broadphase_set[
						centerline_chunk
						+ Vector3i(offset_x, offset_y, offset_z)
					] = true
	var exact_bounds := AABB(bounds_min, bounds_max - bounds_min)
	var intersecting_chunks: Array[Vector3i] = []
	for chunk_coord: Vector3i in _sorted_vector3i_keys(broadphase_set):
		var chunk_bounds := _chunk_world_aabb(chunk_coord)
		if not chunk_bounds.intersects(exact_bounds):
			continue
		var grown_chunk_bounds := AABB(
			chunk_bounds.position - support,
			chunk_bounds.size + support * 2.0
		)
		if not _segment_intersects_aabb(
			segment_start,
			segment_end,
			grown_chunk_bounds
		):
			continue
		intersecting_chunks.append(chunk_coord)
	return {
		"ok": true,
		"centerline_chunk_count": centerline_chunks.size(),
		"broadphase_chunk_count": broadphase_set.size(),
		"centerline_chunk_coords": centerline_chunks,
		"broadphase_chunk_coords": _sorted_vector3i_keys(broadphase_set),
		"intersecting_chunk_coords": intersecting_chunks,
		"profile_support_chunk_rings": support_rings,
	}


func _traverse_segment_chunks(
	segment_start: Vector3,
	segment_end: Vector3
) -> Array[Vector3i]:
	var chunk_world_size := cell_size_meters * float(chunk_dimension)
	var current := _world_to_chunk_position(segment_start)
	var final_chunk := _world_to_chunk_position(segment_end)
	var result: Array[Vector3i] = [current]
	if current == final_chunk:
		return result
	var delta := segment_end - segment_start
	var step := Vector3i(
		1 if delta.x > 0.0 else (-1 if delta.x < 0.0 else 0),
		1 if delta.y > 0.0 else (-1 if delta.y < 0.0 else 0),
		1 if delta.z > 0.0 else (-1 if delta.z < 0.0 else 0)
	)
	var t_delta := Vector3(INF, INF, INF)
	var t_max := Vector3(INF, INF, INF)
	if step.x != 0:
		var next_x := float(current.x + (1 if step.x > 0 else 0)) * chunk_world_size
		t_max.x = (next_x - segment_start.x) / delta.x
		t_delta.x = chunk_world_size / absf(delta.x)
	if step.y != 0:
		var next_y := float(current.y + (1 if step.y > 0 else 0)) * chunk_world_size
		t_max.y = (next_y - segment_start.y) / delta.y
		t_delta.y = chunk_world_size / absf(delta.y)
	if step.z != 0:
		var next_z := float(current.z + (1 if step.z > 0 else 0)) * chunk_world_size
		t_max.z = (next_z - segment_start.z) / delta.z
		t_delta.z = chunk_world_size / absf(delta.z)
	var guard := 0
	while current != final_chunk and guard < 1000000:
		guard += 1
		if t_max.x <= t_max.y and t_max.x <= t_max.z:
			current.x += step.x
			t_max.x += t_delta.x
		elif t_max.y <= t_max.z:
			current.y += step.y
			t_max.y += t_delta.y
		else:
			current.z += step.z
			t_max.z += t_delta.z
		if result[-1] != current:
			result.append(current)
	return result


func _world_to_chunk_position(world_position: Vector3) -> Vector3i:
	var chunk_world_size := cell_size_meters * float(chunk_dimension)
	return Vector3i(
		floori(world_position.x / chunk_world_size),
		floori(world_position.y / chunk_world_size),
		floori(world_position.z / chunk_world_size)
	)


func _chunk_world_aabb(chunk_coord: Vector3i) -> AABB:
	var chunk_world_size := cell_size_meters * float(chunk_dimension)
	return AABB(
		Vector3(chunk_coord) * chunk_world_size,
		Vector3.ONE * chunk_world_size
	)


func _segment_intersects_aabb(
	segment_start: Vector3,
	segment_end: Vector3,
	bounds: AABB
) -> bool:
	var delta := segment_end - segment_start
	var bounds_end := bounds.end
	var start_values := [segment_start.x, segment_start.y, segment_start.z]
	var delta_values := [delta.x, delta.y, delta.z]
	var minimum_values := [bounds.position.x, bounds.position.y, bounds.position.z]
	var maximum_values := [bounds_end.x, bounds_end.y, bounds_end.z]
	var minimum_ratio := 0.0
	var maximum_ratio := 1.0
	for axis_index in range(3):
		var axis_start: float = start_values[axis_index]
		var axis_delta: float = delta_values[axis_index]
		var axis_minimum: float = minimum_values[axis_index]
		var axis_maximum: float = maximum_values[axis_index]
		if absf(axis_delta) <= GEOMETRY_EPSILON:
			if (
				axis_start < axis_minimum - GEOMETRY_EPSILON
				or axis_start > axis_maximum + GEOMETRY_EPSILON
			):
				return false
			continue
		var first_ratio := (axis_minimum - axis_start) / axis_delta
		var second_ratio := (axis_maximum - axis_start) / axis_delta
		if first_ratio > second_ratio:
			var temporary := first_ratio
			first_ratio = second_ratio
			second_ratio = temporary
		minimum_ratio = maxf(minimum_ratio, first_ratio)
		maximum_ratio = minf(maximum_ratio, second_ratio)
		if minimum_ratio > maximum_ratio + GEOMETRY_EPSILON:
			return false
	return true


func _inspect_candidate_attachment(candidate_chunks: Dictionary) -> Dictionary:
	# Component fields describe only candidate cells that would become newly
	# occupied.  Existing-overlap cells are already accepted occupancy: they
	# remain contact/overlap evidence but cannot create a new detached island.
	var overlap_count := 0
	var face_attachment_count := 0
	var contact_cell_count := 0
	var contact_chunks: Dictionary = {}
	var candidate_component_count := 0
	var attached_component_count := 0
	var new_candidate_cell_count := 0
	var candidate_chunk_coords := _sorted_vector3i_keys(candidate_chunks)
	var candidate_chunk_ids: Dictionary = {}
	var new_indices_by_chunk: Array = []
	var new_candidate_masks: Array = []
	var visited_masks: Array = []
	var existing_labels_by_chunk: Array = []
	for chunk_index in range(candidate_chunk_coords.size()):
		var chunk_coord := candidate_chunk_coords[chunk_index]
		candidate_chunk_ids[chunk_coord] = chunk_index
		var local_indices: PackedInt32Array = candidate_chunks.get(
			chunk_coord,
			PackedInt32Array()
		) as PackedInt32Array
		var existing_labels := PackedByteArray()
		if chunks.has(chunk_coord):
			var record: Dictionary = chunks.get(chunk_coord, {}) as Dictionary
			existing_labels = record.get(
				"labels",
				PackedByteArray()
			) as PackedByteArray
		existing_labels_by_chunk.append(existing_labels)
		var classified_mask := PackedByteArray()
		classified_mask.resize(cells_per_chunk)
		var new_candidate_mask := PackedByteArray()
		new_candidate_mask.resize(cells_per_chunk)
		var new_indices := PackedInt32Array()
		for local_index: int in local_indices:
			if (
				local_index < 0
				or local_index >= cells_per_chunk
				or classified_mask[local_index] != 0
			):
				continue
			classified_mask[local_index] = 1
			if (
				existing_labels.size() == cells_per_chunk
				and existing_labels[local_index] != MATERIAL_LABEL_EMPTY
			):
				overlap_count += 1
				contact_cell_count += 1
				contact_chunks[chunk_coord] = true
				continue
			new_candidate_mask[local_index] = 1
			new_indices.append(local_index)
			new_candidate_cell_count += 1
		new_indices_by_chunk.append(new_indices)
		new_candidate_masks.append(new_candidate_mask)
		var visited_mask: Array = []
		if not new_indices.is_empty():
			visited_mask.resize(cells_per_chunk)
			visited_mask.fill(false)
		visited_masks.append(visited_mask)

	var external_existing_labels: Dictionary = {}
	var queue := PackedInt64Array()
	var plane_size := chunk_dimension * chunk_dimension
	for start_chunk_id in range(candidate_chunk_coords.size()):
		var start_indices: PackedInt32Array = new_indices_by_chunk[
			start_chunk_id
		] as PackedInt32Array
		for start_local_index: int in start_indices:
			var start_visited: Array = visited_masks[
				start_chunk_id
			] as Array
			if (
				start_local_index < 0
				or start_local_index >= cells_per_chunk
				or bool(start_visited[start_local_index])
			):
				continue
			candidate_component_count += 1
			queue.clear()
			queue.append(
				start_chunk_id * cells_per_chunk + start_local_index
			)
			start_visited[start_local_index] = true
			var queue_index := 0
			var component_attached := false
			while queue_index < queue.size():
				var packed_cell := int(queue[queue_index])
				queue_index += 1
				var chunk_id := int(packed_cell / cells_per_chunk)
				var local_index := packed_cell - chunk_id * cells_per_chunk
				var chunk_coord: Vector3i = candidate_chunk_coords[chunk_id]
				var local_z := int(local_index / plane_size)
				var remainder := local_index - local_z * plane_size
				var local_y := int(remainder / chunk_dimension)
				var local_x := remainder - local_y * chunk_dimension
				var cell_contacts := false
				for face_index in range(FACE_DIRECTIONS.size()):
					var direction: Vector3i = FACE_DIRECTIONS[face_index]
					var neighbor_chunk_coord := chunk_coord
					var neighbor_x := local_x + direction.x
					var neighbor_y := local_y + direction.y
					var neighbor_z := local_z + direction.z
					if neighbor_x < 0:
						neighbor_x = chunk_dimension - 1
						neighbor_chunk_coord.x -= 1
					elif neighbor_x >= chunk_dimension:
						neighbor_x = 0
						neighbor_chunk_coord.x += 1
					if neighbor_y < 0:
						neighbor_y = chunk_dimension - 1
						neighbor_chunk_coord.y -= 1
					elif neighbor_y >= chunk_dimension:
						neighbor_y = 0
						neighbor_chunk_coord.y += 1
					if neighbor_z < 0:
						neighbor_z = chunk_dimension - 1
						neighbor_chunk_coord.z -= 1
					elif neighbor_z >= chunk_dimension:
						neighbor_z = 0
						neighbor_chunk_coord.z += 1
					var neighbor_local_index := (
						neighbor_x
						+ neighbor_y * chunk_dimension
						+ neighbor_z * plane_size
					)
					var neighbor_chunk_id := int(candidate_chunk_ids.get(
						neighbor_chunk_coord,
						-1
					))
					if neighbor_chunk_id >= 0:
						var neighbor_candidate_mask: PackedByteArray = (
							new_candidate_masks[neighbor_chunk_id]
							as PackedByteArray
						)
						var neighbor_visited_mask: Array = (
							visited_masks[neighbor_chunk_id] as Array
						)
						if (
							neighbor_candidate_mask.size() == cells_per_chunk
							and neighbor_candidate_mask[neighbor_local_index] != 0
							and not bool(neighbor_visited_mask[
								neighbor_local_index
							])
						):
							neighbor_visited_mask[neighbor_local_index] = true
							queue.append(
								neighbor_chunk_id * cells_per_chunk
								+ neighbor_local_index
							)
					var neighbor_existing_labels := PackedByteArray()
					if neighbor_chunk_id >= 0:
						neighbor_existing_labels = (
							existing_labels_by_chunk[neighbor_chunk_id]
							as PackedByteArray
						)
					else:
						if not external_existing_labels.has(
							neighbor_chunk_coord
						):
							var external_labels := PackedByteArray()
							if chunks.has(neighbor_chunk_coord):
								var neighbor_record: Dictionary = chunks.get(
									neighbor_chunk_coord,
									{}
								) as Dictionary
								external_labels = neighbor_record.get(
									"labels",
									PackedByteArray()
								) as PackedByteArray
							external_existing_labels[
								neighbor_chunk_coord
							] = external_labels
						neighbor_existing_labels = external_existing_labels.get(
							neighbor_chunk_coord,
							PackedByteArray()
						) as PackedByteArray
					if (
						neighbor_existing_labels.size() != cells_per_chunk
						or neighbor_existing_labels[neighbor_local_index]
						== MATERIAL_LABEL_EMPTY
					):
						continue
					face_attachment_count += 1
					component_attached = true
					cell_contacts = true
					contact_chunks[chunk_coord] = true
					contact_chunks[neighbor_chunk_coord] = true
				if cell_contacts:
					contact_cell_count += 1
			if component_attached:
				attached_component_count += 1
	var unattached_component_count := (
		candidate_component_count - attached_component_count
	)
	return {
		"attached": unattached_component_count == 0,
		"new_candidate_cell_count": new_candidate_cell_count,
		"overlap_cell_count": overlap_count,
		"face_attachment_count": face_attachment_count,
		"contact_cell_count": contact_cell_count,
		"contact_chunks": contact_chunks,
		"candidate_component_count": candidate_component_count,
		"attached_component_count": attached_component_count,
		"unattached_component_count": unattached_component_count,
	}


func _build_candidate_cell_set(candidate_chunks: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for chunk_coord: Vector3i in _sorted_vector3i_keys(candidate_chunks):
		var local_indices: PackedInt32Array = candidate_chunks.get(
			chunk_coord,
			PackedInt32Array()
		) as PackedInt32Array
		for local_index: int in local_indices:
			result[_chunk_local_to_cell(
				chunk_coord,
				_unflatten_local(local_index)
			)] = true
	return result


func _build_processing_context(contact_chunks: Dictionary) -> Dictionary:
	var processing_context: Dictionary = {}
	for contact_chunk: Vector3i in _sorted_vector3i_keys(contact_chunks):
		for offset_x in range(
			-processing_halo_chunk_rings,
			processing_halo_chunk_rings + 1
		):
			for offset_y in range(
				-processing_halo_chunk_rings,
				processing_halo_chunk_rings + 1
			):
				for offset_z in range(
					-processing_halo_chunk_rings,
					processing_halo_chunk_rings + 1
				):
					processing_context[
						contact_chunk
						+ Vector3i(offset_x, offset_y, offset_z)
					] = true
	var resident_context: Dictionary = {}
	for context_chunk: Vector3i in _sorted_vector3i_keys(processing_context):
		if chunks.has(context_chunk):
			resident_context[context_chunk] = true
	return {
		"processing_context_chunks": processing_context,
		"resident_context_chunks": resident_context,
	}


func _apply_candidate_chunks(candidate_chunks: Dictionary) -> Dictionary:
	var changed_chunks: Array[Vector3i] = []
	var changed_cell_count := 0
	var boundary_neighbor_set: Dictionary = {}
	for chunk_coord: Vector3i in _sorted_vector3i_keys(candidate_chunks):
		var record := _get_or_create_chunk_record(chunk_coord)
		var labels: PackedByteArray = record.get(
			"labels",
			PackedByteArray()
		) as PackedByteArray
		var occupied_count := int(record.get("occupied_cell_count", 0))
		var chunk_changed := false
		var local_indices: PackedInt32Array = candidate_chunks.get(
			chunk_coord,
			PackedInt32Array()
		) as PackedInt32Array
		for local_index: int in local_indices:
			if labels[local_index] != MATERIAL_LABEL_EMPTY:
				continue
			labels[local_index] = MATERIAL_LABEL_PRIMARY
			occupied_count += 1
			occupied_cell_count += 1
			changed_cell_count += 1
			chunk_changed = true
			var local_coord := _unflatten_local(local_index)
			if local_coord.x == 0:
				boundary_neighbor_set[chunk_coord + Vector3i.LEFT] = true
			if local_coord.x == chunk_dimension - 1:
				boundary_neighbor_set[chunk_coord + Vector3i.RIGHT] = true
			if local_coord.y == 0:
				boundary_neighbor_set[chunk_coord + Vector3i.DOWN] = true
			if local_coord.y == chunk_dimension - 1:
				boundary_neighbor_set[chunk_coord + Vector3i.UP] = true
			if local_coord.z == 0:
				boundary_neighbor_set[chunk_coord + Vector3i(0, 0, -1)] = true
			if local_coord.z == chunk_dimension - 1:
				boundary_neighbor_set[chunk_coord + Vector3i(0, 0, 1)] = true
		if not chunk_changed:
			continue
		record["labels"] = labels
		record["occupied_cell_count"] = occupied_count
		chunks[chunk_coord] = record
		changed_chunks.append(chunk_coord)
	return {
		"changed_chunks": changed_chunks,
		"changed_cell_count": changed_cell_count,
		"boundary_neighbor_chunks": _sorted_vector3i_keys(
			boundary_neighbor_set
		),
	}


func _remesh_changed_chunks_and_neighbors(
	changed_chunks: Array[Vector3i],
	boundary_neighbor_chunks: Array[Vector3i]
) -> Dictionary:
	if changed_chunks.is_empty():
		return {
			"remeshed_chunk_coords": [],
			"remeshed_chunk_count": 0,
			"remesh_scanned_cell_count": 0,
			"remeshed_occupied_cell_count": 0,
			"remeshed_occupied_cell_min": 0,
			"remeshed_occupied_cell_max": 0,
			"rebuilt_quad_count": 0,
			"rebuilt_vertex_count": 0,
			"rebuilt_index_count": 0,
		}
	var affected_set: Dictionary = {}
	for changed_chunk: Vector3i in changed_chunks:
		affected_set[changed_chunk] = true
	for boundary_neighbor: Vector3i in boundary_neighbor_chunks:
		affected_set[boundary_neighbor] = true
	var remeshed_coords: Array[Vector3i] = []
	var rebuilt_quad_count := 0
	var rebuilt_vertex_count := 0
	var rebuilt_index_count := 0
	var remeshed_occupied_cell_count := 0
	var remeshed_occupied_cell_min := cells_per_chunk
	var remeshed_occupied_cell_max := 0
	for chunk_coord: Vector3i in _sorted_vector3i_keys(affected_set):
		if not chunks.has(chunk_coord):
			continue
		_remesh_chunk(chunk_coord)
		remeshed_coords.append(chunk_coord)
		var record: Dictionary = chunks.get(chunk_coord, {}) as Dictionary
		var remeshed_chunk_occupied_count := int(record.get(
			"occupied_cell_count",
			0
		))
		remeshed_occupied_cell_count += remeshed_chunk_occupied_count
		remeshed_occupied_cell_min = mini(
			remeshed_occupied_cell_min,
			remeshed_chunk_occupied_count
		)
		remeshed_occupied_cell_max = maxi(
			remeshed_occupied_cell_max,
			remeshed_chunk_occupied_count
		)
		rebuilt_quad_count += int(record.get("quad_count", 0))
		var mesh_arrays: Array = record.get("mesh_arrays", []) as Array
		if mesh_arrays.size() >= Mesh.ARRAY_MAX:
			var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
			rebuilt_vertex_count += vertices.size()
			rebuilt_index_count += indices.size()
	return {
		"remeshed_chunk_coords": remeshed_coords,
		"remeshed_chunk_count": remeshed_coords.size(),
		"remesh_scanned_cell_count": (
			remeshed_coords.size() * cells_per_chunk
		),
		"remeshed_occupied_cell_count": remeshed_occupied_cell_count,
		"remeshed_occupied_cell_min": (
			remeshed_occupied_cell_min if not remeshed_coords.is_empty() else 0
		),
		"remeshed_occupied_cell_max": remeshed_occupied_cell_max,
		"rebuilt_quad_count": rebuilt_quad_count,
		"rebuilt_vertex_count": rebuilt_vertex_count,
		"rebuilt_index_count": rebuilt_index_count,
	}


func _remesh_chunk(chunk_coord: Vector3i) -> void:
	var record: Dictionary = chunks.get(chunk_coord, {}) as Dictionary
	total_quad_count -= int(record.get("quad_count", 0))
	total_triangle_count -= int(record.get("triangle_count", 0))
	var labels: PackedByteArray = record.get(
		"labels",
		PackedByteArray()
	) as PackedByteArray
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var quad_count := 0
	var neighbor_labels_by_face: Array = []
	for direction: Vector3i in FACE_DIRECTIONS:
		var neighbor_labels := PackedByteArray()
		var neighbor_chunk_coord := chunk_coord + direction
		if chunks.has(neighbor_chunk_coord):
			var neighbor_record: Dictionary = chunks.get(
				neighbor_chunk_coord,
				{}
			) as Dictionary
			neighbor_labels = neighbor_record.get(
				"labels",
				PackedByteArray()
			) as PackedByteArray
		neighbor_labels_by_face.append(neighbor_labels)
	var plane_size := chunk_dimension * chunk_dimension
	var chunk_origin_cell := chunk_coord * chunk_dimension
	for local_index in range(labels.size()):
		if labels[local_index] == MATERIAL_LABEL_EMPTY:
			continue
		var local_z := int(local_index / plane_size)
		var remainder := local_index - local_z * plane_size
		var local_y := int(remainder / chunk_dimension)
		var local_x := remainder - local_y * chunk_dimension
		var cell_coord := (
			chunk_origin_cell + Vector3i(local_x, local_y, local_z)
		)
		for face_index in range(FACE_DIRECTIONS.size()):
			var neighbor_local_index := local_index
			var neighbor_is_local := true
			match face_index:
				0:
					neighbor_local_index += 1
					neighbor_is_local = local_x < chunk_dimension - 1
					if not neighbor_is_local:
						neighbor_local_index -= chunk_dimension
				1:
					neighbor_local_index -= 1
					neighbor_is_local = local_x > 0
					if not neighbor_is_local:
						neighbor_local_index += chunk_dimension
				2:
					neighbor_local_index += chunk_dimension
					neighbor_is_local = local_y < chunk_dimension - 1
					if not neighbor_is_local:
						neighbor_local_index -= plane_size
				3:
					neighbor_local_index -= chunk_dimension
					neighbor_is_local = local_y > 0
					if not neighbor_is_local:
						neighbor_local_index += plane_size
				4:
					neighbor_local_index += plane_size
					neighbor_is_local = local_z < chunk_dimension - 1
					if not neighbor_is_local:
						neighbor_local_index -= cells_per_chunk
				_:
					neighbor_local_index -= plane_size
					neighbor_is_local = local_z > 0
					if not neighbor_is_local:
						neighbor_local_index += cells_per_chunk
			var neighbor_is_occupied := false
			if neighbor_is_local:
				neighbor_is_occupied = (
					labels[neighbor_local_index] != MATERIAL_LABEL_EMPTY
				)
			else:
				var neighbor_labels: PackedByteArray = (
					neighbor_labels_by_face[face_index] as PackedByteArray
				)
				neighbor_is_occupied = (
					neighbor_labels.size() == cells_per_chunk
					and neighbor_labels[neighbor_local_index]
					!= MATERIAL_LABEL_EMPTY
				)
			if neighbor_is_occupied:
				continue
			_append_cell_face(
				vertices,
				normals,
				indices,
				cell_coord,
				face_index
			)
			quad_count += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var triangle_count := quad_count * 2
	var cached_mesh := _build_array_mesh_from_arrays(arrays)
	record["mesh_arrays"] = arrays
	record["mesh"] = cached_mesh
	record["mesh_revision"] = int(record.get("mesh_revision", 0)) + 1
	record["quad_count"] = quad_count
	record["triangle_count"] = triangle_count
	chunks[chunk_coord] = record
	total_quad_count += quad_count
	total_triangle_count += triangle_count


func _build_array_mesh_from_arrays(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if arrays.size() < Mesh.ARRAY_MAX:
		return mesh
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty() or indices.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _append_cell_face(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	cell_coord: Vector3i,
	face_index: int
) -> void:
	var minimum := Vector3(cell_coord) * cell_size_meters
	var maximum := minimum + Vector3.ONE * cell_size_meters
	match face_index:
		0:
			vertices.append(Vector3(maximum.x, minimum.y, minimum.z))
			vertices.append(Vector3(maximum.x, maximum.y, minimum.z))
			vertices.append(Vector3(maximum.x, maximum.y, maximum.z))
			vertices.append(Vector3(maximum.x, minimum.y, maximum.z))
		1:
			vertices.append(Vector3(minimum.x, minimum.y, minimum.z))
			vertices.append(Vector3(minimum.x, minimum.y, maximum.z))
			vertices.append(Vector3(minimum.x, maximum.y, maximum.z))
			vertices.append(Vector3(minimum.x, maximum.y, minimum.z))
		2:
			vertices.append(Vector3(minimum.x, maximum.y, minimum.z))
			vertices.append(Vector3(minimum.x, maximum.y, maximum.z))
			vertices.append(Vector3(maximum.x, maximum.y, maximum.z))
			vertices.append(Vector3(maximum.x, maximum.y, minimum.z))
		3:
			vertices.append(Vector3(minimum.x, minimum.y, minimum.z))
			vertices.append(Vector3(maximum.x, minimum.y, minimum.z))
			vertices.append(Vector3(maximum.x, minimum.y, maximum.z))
			vertices.append(Vector3(minimum.x, minimum.y, maximum.z))
		4:
			vertices.append(Vector3(minimum.x, minimum.y, maximum.z))
			vertices.append(Vector3(maximum.x, minimum.y, maximum.z))
			vertices.append(Vector3(maximum.x, maximum.y, maximum.z))
			vertices.append(Vector3(minimum.x, maximum.y, maximum.z))
		_:
			vertices.append(Vector3(minimum.x, minimum.y, minimum.z))
			vertices.append(Vector3(minimum.x, maximum.y, minimum.z))
			vertices.append(Vector3(maximum.x, maximum.y, minimum.z))
			vertices.append(Vector3(maximum.x, minimum.y, minimum.z))
	var vertex_offset := vertices.size()
	vertex_offset -= 4
	var normal: Vector3 = FACE_NORMALS[face_index]
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	indices.append(vertex_offset)
	indices.append(vertex_offset + 1)
	indices.append(vertex_offset + 2)
	indices.append(vertex_offset)
	indices.append(vertex_offset + 2)
	indices.append(vertex_offset + 3)


func _get_or_create_chunk_record(chunk_coord: Vector3i) -> Dictionary:
	if chunks.has(chunk_coord):
		return chunks.get(chunk_coord, {}) as Dictionary
	var labels := PackedByteArray()
	labels.resize(cells_per_chunk)
	labels.fill(MATERIAL_LABEL_EMPTY)
	var protected_mask := PackedByteArray()
	protected_mask.resize(cells_per_chunk)
	protected_mask.fill(0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	var record := {
		"labels": labels,
		"protected_mask": protected_mask,
		"occupied_cell_count": 0,
		"mesh_arrays": arrays,
		"mesh": ArrayMesh.new(),
		"mesh_revision": 0,
		"quad_count": 0,
		"triangle_count": 0,
	}
	chunks[chunk_coord] = record
	return record


func _get_cell_label(cell_coord: Vector3i) -> int:
	var chunk_coord := _cell_to_chunk(cell_coord)
	if not chunks.has(chunk_coord):
		return MATERIAL_LABEL_EMPTY
	var record: Dictionary = chunks.get(chunk_coord, {}) as Dictionary
	var labels: PackedByteArray = record.get(
		"labels",
		PackedByteArray()
	) as PackedByteArray
	if labels.size() != cells_per_chunk:
		return MATERIAL_LABEL_EMPTY
	var local_coord := _cell_to_local(cell_coord, chunk_coord)
	return int(labels[_flatten_local(local_coord)])


func _world_to_cell(world_position: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_position.x / cell_size_meters),
		floori(world_position.y / cell_size_meters),
		floori(world_position.z / cell_size_meters)
	)


func _cell_center_world(cell_coord: Vector3i) -> Vector3:
	return (
		(Vector3(cell_coord) + Vector3.ONE * 0.5)
		* cell_size_meters
	)


func _cell_to_chunk(cell_coord: Vector3i) -> Vector3i:
	return Vector3i(
		_floor_divide(cell_coord.x, chunk_dimension),
		_floor_divide(cell_coord.y, chunk_dimension),
		_floor_divide(cell_coord.z, chunk_dimension)
	)


func _cell_to_local(
	cell_coord: Vector3i,
	chunk_coord: Vector3i
) -> Vector3i:
	return cell_coord - chunk_coord * chunk_dimension


func _chunk_local_to_cell(
	chunk_coord: Vector3i,
	local_coord: Vector3i
) -> Vector3i:
	return chunk_coord * chunk_dimension + local_coord


func _flatten_local(local_coord: Vector3i) -> int:
	return (
		local_coord.x
		+ local_coord.y * chunk_dimension
		+ local_coord.z * chunk_dimension * chunk_dimension
	)


func _unflatten_local(local_index: int) -> Vector3i:
	var plane_size := chunk_dimension * chunk_dimension
	var local_z := int(local_index / plane_size)
	var remainder := local_index - local_z * plane_size
	var local_y := int(remainder / chunk_dimension)
	var local_x := remainder - local_y * chunk_dimension
	return Vector3i(local_x, local_y, local_z)


func _floor_divide(value: int, divisor: int) -> int:
	return floori(float(value) / float(divisor))


func _point_inside_or_on_polygon(
	point: Vector2,
	polygon: PackedVector2Array
) -> bool:
	var inside := false
	for index in range(polygon.size()):
		var start := polygon[index]
		var end := polygon[(index + 1) % polygon.size()]
		if _point_on_segment_2d(point, start, end):
			return true
		var crosses := (
			(start.y > point.y) != (end.y > point.y)
			and point.x
			< (
				(end.x - start.x) * (point.y - start.y)
				/ (end.y - start.y)
				+ start.x
			)
		)
		if crosses:
			inside = not inside
	return inside


func _point_on_segment_2d(
	point: Vector2,
	start: Vector2,
	end: Vector2
) -> bool:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		return point.distance_squared_to(start) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON
	var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	var nearest := start + segment * ratio
	return point.distance_squared_to(nearest) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON


func _sorted_vector3i_keys(dictionary: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for key: Variant in dictionary.keys():
		if key is Vector3i:
			result.append(key as Vector3i)
	result.sort_custom(_vector3i_less)
	return result


func _vector3i_less(first: Vector3i, second: Vector3i) -> bool:
	if first.x != second.x:
		return first.x < second.x
	if first.y != second.y:
		return first.y < second.y
	return first.z < second.z


func _record_last_operation_metrics(
	raster_result: Dictionary,
	attachment: Dictionary,
	context_result: Dictionary,
	update_result: Dictionary,
	remesh_result: Dictionary
) -> void:
	var candidate_chunks: Dictionary = raster_result.get(
		"candidate_chunks",
		{}
	) as Dictionary
	var contact_chunks: Dictionary = attachment.get(
		"contact_chunks",
		{}
	) as Dictionary
	var context_chunks: Dictionary = context_result.get(
		"processing_context_chunks",
		{}
	) as Dictionary
	var resident_context_chunks: Dictionary = context_result.get(
		"resident_context_chunks",
		{}
	) as Dictionary
	last_candidate_chunk_coords = _sorted_vector3i_keys(candidate_chunks)
	last_contact_chunk_coords = _sorted_vector3i_keys(contact_chunks)
	last_processing_context_chunk_coords = _sorted_vector3i_keys(context_chunks)
	last_resident_context_chunk_coords = _sorted_vector3i_keys(
		resident_context_chunks
	)
	# Dictionary fallbacks are untyped Arrays.  Copy element-by-element so a
	# valid no-op Add (zero changed/remeshed chunks) remains a first-class
	# transaction instead of tripping typed-array assignment in diagnostics.
	last_changed_chunk_coords.clear()
	var changed_coords_variant: Variant = update_result.get(
		"changed_chunks",
		[]
	)
	if changed_coords_variant is Array:
		for coord_variant: Variant in changed_coords_variant as Array:
			if coord_variant is Vector3i:
				last_changed_chunk_coords.append(coord_variant as Vector3i)
	last_remeshed_chunk_coords.clear()
	var remeshed_coords_variant: Variant = remesh_result.get(
		"remeshed_chunk_coords",
		[]
	)
	if remeshed_coords_variant is Array:
		for coord_variant: Variant in remeshed_coords_variant as Array:
			if coord_variant is Vector3i:
				last_remeshed_chunk_coords.append(coord_variant as Vector3i)
	var new_only_chunk_count := 0
	for candidate_chunk: Vector3i in last_candidate_chunk_coords:
		if not contact_chunks.has(candidate_chunk):
			new_only_chunk_count += 1
	last_candidate_cell_count = int(raster_result.get(
		"candidate_cell_count",
		0
	))
	last_examined_cell_count = int(raster_result.get(
		"examined_cell_count",
		0
	))
	last_world_aabb_cell_count = int(raster_result.get(
		"world_aabb_cell_count",
		0
	))
	last_centerline_chunk_count = int(raster_result.get(
		"centerline_chunk_count",
		0
	))
	last_broadphase_chunk_count = int(raster_result.get(
		"broadphase_chunk_count",
		0
	))
	last_intersecting_chunk_count = int(raster_result.get(
		"intersecting_chunk_count",
		0
	))
	last_candidate_chunk_count = last_candidate_chunk_coords.size()
	last_contact_cell_count = int(attachment.get("contact_cell_count", 0))
	last_contact_chunk_count = last_contact_chunk_coords.size()
	last_new_only_chunk_count = new_only_chunk_count
	last_candidate_component_count = int(attachment.get(
		"candidate_component_count",
		0
	))
	last_attached_component_count = int(attachment.get(
		"attached_component_count",
		0
	))
	last_processing_context_chunk_count = (
		last_processing_context_chunk_coords.size()
	)
	last_resident_context_chunk_count = (
		last_resident_context_chunk_coords.size()
	)
	last_changed_cell_count = int(update_result.get("changed_cell_count", 0))
	last_changed_chunk_count = last_changed_chunk_coords.size()
	last_remeshed_chunk_count = last_remeshed_chunk_coords.size()
	last_remesh_scanned_cell_count = int(remesh_result.get(
		"remesh_scanned_cell_count",
		0
	))
	last_remeshed_occupied_cell_count = int(remesh_result.get(
		"remeshed_occupied_cell_count",
		0
	))
	last_remeshed_occupied_cell_min = int(remesh_result.get(
		"remeshed_occupied_cell_min",
		0
	))
	last_remeshed_occupied_cell_max = int(remesh_result.get(
		"remeshed_occupied_cell_max",
		0
	))
	last_rebuilt_quad_count = int(remesh_result.get("rebuilt_quad_count", 0))
	last_rebuilt_vertex_count = int(remesh_result.get(
		"rebuilt_vertex_count",
		0
	))
	last_rebuilt_index_count = int(remesh_result.get("rebuilt_index_count", 0))


func _append_last_locality_metrics(result: Dictionary) -> void:
	result["examined_cell_count"] = last_examined_cell_count
	result["world_aabb_cell_count"] = last_world_aabb_cell_count
	result["centerline_chunk_count"] = last_centerline_chunk_count
	result["broadphase_chunk_count"] = last_broadphase_chunk_count
	result["intersecting_chunk_count"] = last_intersecting_chunk_count
	result["candidate_chunk_count"] = last_candidate_chunk_count
	result["contact_cell_count"] = last_contact_cell_count
	result["contact_chunk_count"] = last_contact_chunk_count
	result["new_only_chunk_count"] = last_new_only_chunk_count
	result["candidate_component_count"] = last_candidate_component_count
	result["attached_component_count"] = last_attached_component_count
	result["processing_context_chunk_count"] = (
		last_processing_context_chunk_count
	)
	result["resident_context_chunk_count"] = (
		last_resident_context_chunk_count
	)
	result["remesh_scanned_cell_count"] = last_remesh_scanned_cell_count
	result["remeshed_occupied_cell_count"] = (
		last_remeshed_occupied_cell_count
	)
	result["remeshed_occupied_cell_min"] = last_remeshed_occupied_cell_min
	result["remeshed_occupied_cell_max"] = last_remeshed_occupied_cell_max
	result["rebuilt_quad_count"] = last_rebuilt_quad_count
	result["rebuilt_vertex_count"] = last_rebuilt_vertex_count
	result["rebuilt_index_count"] = last_rebuilt_index_count


func _build_operation_result(
	raster_ms: float,
	update_ms: float,
	remesh_ms: float,
	total_ms: float,
	candidate_count: int,
	changed_count: int,
	changed_chunk_count: int,
	remeshed_chunk_count: int
) -> Dictionary:
	var result := get_summary()
	result["ok"] = true
	result["raster_ms"] = raster_ms
	result["update_ms"] = update_ms
	result["remesh_ms"] = remesh_ms
	result["total_ms"] = total_ms
	result["operation_compile_total_ms"] = total_ms
	result["candidate_cell_count"] = candidate_count
	result["changed_cell_count"] = changed_count
	result["changed_chunk_count"] = changed_chunk_count
	result["remeshed_chunk_count"] = remeshed_chunk_count
	return result


func _is_finite_vector3(value: Vector3) -> bool:
	return (
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
	)


func _elapsed_milliseconds(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
