extends Resource
class_name ForgeV2HistoryCheckpoint

const SCHEMA_VERSION := 2

@export var schema_version: int = SCHEMA_VERSION
@export var checkpoint_id: StringName = StringName()
@export var revision: int = 0
@export var materialization_revision: int = 0
@export var accumulated_operation_count: int = 0
@export var materialized_mesh_operation_count: int = 0
@export var mesh_dirty: bool = false
@export var lifetime_operation_count_at_checkpoint: int = 0
@export var material_variant_id: StringName = StringName()
@export var vertices: PackedVector3Array = PackedVector3Array()
@export var indices: PackedInt32Array = PackedInt32Array()
@export var source_original_ids: PackedInt32Array = PackedInt32Array()
@export var source_face_ids: PackedInt32Array = PackedInt32Array()
@export var vertex_count: int = 0
@export var triangle_count: int = 0
@export var volume_m3: float = 0.0
@export var resolver_sample_cell_size_meters: float = 0.0
@export var checkpoint_cell_materials: Dictionary = {}
@export var checkpoint_protected_handle_cells: Dictionary = {}
@export var checkpoint_material_cell_counts: Dictionary = {}
@export var material_ledger_summary: Dictionary = {}
@export var created_timestamp: float = 0.0
@export var updated_timestamp: float = 0.0


func reset() -> void:
	schema_version = SCHEMA_VERSION
	checkpoint_id = StringName()
	revision = 0
	materialization_revision = 0
	accumulated_operation_count = 0
	materialized_mesh_operation_count = 0
	mesh_dirty = false
	lifetime_operation_count_at_checkpoint = 0
	material_variant_id = StringName()
	vertices = PackedVector3Array()
	indices = PackedInt32Array()
	source_original_ids = PackedInt32Array()
	source_face_ids = PackedInt32Array()
	vertex_count = 0
	triangle_count = 0
	volume_m3 = 0.0
	resolver_sample_cell_size_meters = 0.0
	checkpoint_cell_materials = {}
	checkpoint_protected_handle_cells = {}
	checkpoint_material_cell_counts = {}
	material_ledger_summary = {}
	created_timestamp = 0.0
	updated_timestamp = 0.0


func normalize() -> void:
	schema_version = SCHEMA_VERSION
	revision = maxi(revision, 0)
	materialization_revision = maxi(materialization_revision, 0)
	accumulated_operation_count = maxi(accumulated_operation_count, 0)
	materialized_mesh_operation_count = clampi(
		materialized_mesh_operation_count,
		0,
		accumulated_operation_count
	)
	lifetime_operation_count_at_checkpoint = maxi(
		lifetime_operation_count_at_checkpoint,
		accumulated_operation_count
	)
	vertex_count = vertices.size()
	triangle_count = indices.size() / 3 if indices.size() % 3 == 0 else 0
	volume_m3 = maxf(volume_m3, 0.0)
	resolver_sample_cell_size_meters = maxf(
		resolver_sample_cell_size_meters,
		0.0
	)
	if not is_initialized():
		reset()
		return
	if checkpoint_id == StringName():
		checkpoint_id = _create_checkpoint_id()
	if created_timestamp <= 0.0:
		created_timestamp = Time.get_unix_time_from_system()
	if updated_timestamp <= 0.0:
		updated_timestamp = created_timestamp
	material_ledger_summary = material_ledger_summary.duplicate(true)
	mesh_dirty = (
		materialized_mesh_operation_count != accumulated_operation_count
		or not has_materialized_mesh()
	)


func is_initialized() -> bool:
	return accumulated_operation_count > 0


func has_materialized_mesh() -> bool:
	return (
		materialized_mesh_operation_count == accumulated_operation_count
		and accumulated_operation_count > 0
		and not vertices.is_empty()
		and not indices.is_empty()
		and indices.size() % 3 == 0
	)


func is_restore_ready() -> bool:
	return is_initialized() and not mesh_dirty and has_materialized_mesh()


func get_identity_descriptor() -> Dictionary:
	return {
		"checkpoint_id": checkpoint_id,
		"checkpoint_revision": revision,
		"checkpoint_materialization_revision": materialization_revision,
		"checkpoint_operation_count": accumulated_operation_count,
		"materialized_mesh_operation_count": (
			materialized_mesh_operation_count
		),
		"checkpoint_mesh_dirty": mesh_dirty,
	}


func build_next_identity_descriptor(
	expected_operation_count: int
) -> Dictionary:
	if expected_operation_count != accumulated_operation_count + 1:
		return {}
	return {
		"checkpoint_id": (
			checkpoint_id
			if checkpoint_id != StringName()
			else _create_checkpoint_id()
		),
		"checkpoint_revision": revision + 1,
		"checkpoint_materialization_revision": materialization_revision,
		"checkpoint_operation_count": expected_operation_count,
		"materialized_mesh_operation_count": (
			materialized_mesh_operation_count
		),
		"checkpoint_mesh_dirty": true,
	}


func can_advance_logical_checkpoint_with_occupancy_delta(
	expected_operation_count: int,
	next_checkpoint_identity: Dictionary,
	next_material_variant_id: StringName,
	next_resolver_sample_cell_size_meters: float,
	occupancy_delta: Dictionary
) -> bool:
	if (
		expected_operation_count != accumulated_operation_count + 1
		or next_material_variant_id == StringName()
		or next_resolver_sample_cell_size_meters <= 0.0
		or not bool(occupancy_delta.get("ok", false))
		or int(occupancy_delta.get(
			"base_checkpoint_operation_count",
			-1
		)) != accumulated_operation_count
		or int(occupancy_delta.get(
			"base_checkpoint_revision",
			-1
		)) != revision
		or StringName(occupancy_delta.get(
			"base_checkpoint_id",
			StringName()
		)) != checkpoint_id
		or int(occupancy_delta.get("base_checkpoint_cell_count", -1))
		!= checkpoint_cell_materials.size()
		or int(occupancy_delta.get(
			"base_checkpoint_protected_cell_count",
			-1
		)) != checkpoint_protected_handle_cells.size()
		or StringName(next_checkpoint_identity.get(
			"checkpoint_id",
			StringName()
		)) == StringName()
		or int(next_checkpoint_identity.get(
			"checkpoint_revision",
			-1
		)) != revision + 1
		or int(next_checkpoint_identity.get(
			"checkpoint_operation_count",
			-1
		)) != expected_operation_count
	):
		return false
	if (
		checkpoint_id != StringName()
		and StringName(next_checkpoint_identity.get("checkpoint_id"))
		!= checkpoint_id
	):
		return false
	var cell_updates_variant: Variant = occupancy_delta.get("cell_updates", {})
	var protected_updates_variant: Variant = occupancy_delta.get(
		"protected_cell_updates",
		{}
	)
	var next_counts_variant: Variant = occupancy_delta.get(
		"next_material_cell_counts",
		{}
	)
	if (
		not cell_updates_variant is Dictionary
		or not protected_updates_variant is Dictionary
		or not next_counts_variant is Dictionary
	):
		return false
	var cell_updates := cell_updates_variant as Dictionary
	var computed_next_cell_count := checkpoint_cell_materials.size()
	var computed_next_material_counts := checkpoint_material_cell_counts.duplicate()
	for cell_key: Variant in cell_updates.keys():
		if not cell_key is Vector3i:
			return false
		var next_material_id := StringName(cell_updates[cell_key])
		var previous_material_id := StringName(checkpoint_cell_materials.get(
			cell_key,
			StringName()
		))
		if (
			next_material_id == StringName()
			and not checkpoint_cell_materials.has(cell_key)
		):
			return false
		if previous_material_id == next_material_id:
			continue
		_decrement_material_count(
			computed_next_material_counts,
			previous_material_id
		)
		_increment_material_count(
			computed_next_material_counts,
			next_material_id
		)
		if previous_material_id == StringName():
			computed_next_cell_count += 1
		elif next_material_id == StringName():
			computed_next_cell_count -= 1
	var protected_updates := protected_updates_variant as Dictionary
	for cell_key: Variant in protected_updates.keys():
		if not cell_key is Vector3i:
			return false
	var next_counts := next_counts_variant as Dictionary
	var next_total_cell_count := 0
	for material_key: Variant in next_counts.keys():
		if StringName(material_key) == StringName():
			return false
		var cell_count := int(next_counts[material_key])
		if cell_count <= 0:
			return false
		next_total_cell_count += cell_count
	if (
		next_total_cell_count != int(occupancy_delta.get(
			"next_checkpoint_cell_count",
			-1
		))
		or computed_next_cell_count != next_total_cell_count
		or computed_next_material_counts.size() != next_counts.size()
	):
		return false
	for material_key: Variant in next_counts.keys():
		if int(computed_next_material_counts.get(material_key, -1)) != int(
			next_counts[material_key]
		):
			return false
	return true


func advance_logical_checkpoint_with_occupancy_delta(
	expected_operation_count: int,
	next_checkpoint_identity: Dictionary,
	next_material_variant_id: StringName,
	next_material_ledger_summary: Dictionary,
	next_lifetime_operation_count: int,
	next_resolver_sample_cell_size_meters: float,
	occupancy_delta: Dictionary
) -> bool:
	if not can_advance_logical_checkpoint_with_occupancy_delta(
		expected_operation_count,
		next_checkpoint_identity,
		next_material_variant_id,
		next_resolver_sample_cell_size_meters,
		occupancy_delta
	):
		return false
	# Every possible rejection is above this boundary. Applying the journal is
	# an in-place touched-cell update, never a copy of the growing checkpoint.
	var cell_updates := occupancy_delta.get("cell_updates", {}) as Dictionary
	for cell_key: Vector3i in cell_updates.keys():
		var next_material_id := StringName(cell_updates[cell_key])
		if next_material_id == StringName():
			checkpoint_cell_materials.erase(cell_key)
		else:
			checkpoint_cell_materials[cell_key] = next_material_id
	var protected_updates := occupancy_delta.get(
		"protected_cell_updates",
		{}
	) as Dictionary
	for cell_key: Vector3i in protected_updates.keys():
		if bool(protected_updates[cell_key]):
			checkpoint_protected_handle_cells[cell_key] = true
		else:
			checkpoint_protected_handle_cells.erase(cell_key)
	checkpoint_material_cell_counts = occupancy_delta.get(
		"next_material_cell_counts",
		{}
	) as Dictionary
	checkpoint_id = StringName(next_checkpoint_identity.get("checkpoint_id"))
	if created_timestamp <= 0.0:
		created_timestamp = Time.get_unix_time_from_system()
	revision = int(next_checkpoint_identity.get("checkpoint_revision"))
	accumulated_operation_count = expected_operation_count
	lifetime_operation_count_at_checkpoint = maxi(
		next_lifetime_operation_count,
		expected_operation_count
	)
	material_variant_id = next_material_variant_id
	resolver_sample_cell_size_meters = next_resolver_sample_cell_size_meters
	material_ledger_summary = next_material_ledger_summary.duplicate(true)
	mesh_dirty = true
	updated_timestamp = Time.get_unix_time_from_system()
	schema_version = SCHEMA_VERSION
	return true


func advance_logical_checkpoint(
	expected_operation_count: int,
	next_material_variant_id: StringName,
	next_material_ledger_summary: Dictionary,
	next_lifetime_operation_count: int,
	next_resolver_sample_cell_size_meters: float,
	next_checkpoint_cell_materials: Dictionary,
	next_checkpoint_protected_handle_cells: Dictionary,
	next_checkpoint_material_cell_counts: Dictionary
) -> bool:
	if (
		expected_operation_count != accumulated_operation_count + 1
		or next_material_variant_id == StringName()
		or next_resolver_sample_cell_size_meters <= 0.0
	):
		return false
	if checkpoint_id == StringName():
		checkpoint_id = _create_checkpoint_id()
	if created_timestamp <= 0.0:
		created_timestamp = Time.get_unix_time_from_system()
	revision += 1
	accumulated_operation_count = expected_operation_count
	lifetime_operation_count_at_checkpoint = maxi(
		next_lifetime_operation_count,
		expected_operation_count
	)
	material_variant_id = next_material_variant_id
	resolver_sample_cell_size_meters = next_resolver_sample_cell_size_meters
	checkpoint_cell_materials = next_checkpoint_cell_materials
	checkpoint_protected_handle_cells = (
		next_checkpoint_protected_handle_cells
	)
	checkpoint_material_cell_counts = next_checkpoint_material_cell_counts
	material_ledger_summary = next_material_ledger_summary.duplicate(true)
	mesh_dirty = true
	updated_timestamp = Time.get_unix_time_from_system()
	schema_version = SCHEMA_VERSION
	return true


func _create_checkpoint_id() -> StringName:
	return StringName(
		"forge_v2_checkpoint_%s_%s" % [
			str(get_instance_id()),
			str(Time.get_ticks_usec()),
		]
	)


func _increment_material_count(
	material_counts: Dictionary,
	material_variant_id: StringName
) -> void:
	if material_variant_id == StringName():
		return
	material_counts[material_variant_id] = int(material_counts.get(
		material_variant_id,
		0
	)) + 1


func _decrement_material_count(
	material_counts: Dictionary,
	material_variant_id: StringName
) -> void:
	if material_variant_id == StringName():
		return
	var next_count := int(material_counts.get(material_variant_id, 0)) - 1
	if next_count <= 0:
		material_counts.erase(material_variant_id)
	else:
		material_counts[material_variant_id] = next_count


func replace_from_native_packet(
	packet: Dictionary,
	expected_operation_count: int,
	next_material_variant_id: StringName,
	next_material_ledger_summary: Dictionary,
	next_lifetime_operation_count: int,
	next_resolver_sample_cell_size_meters: float = 0.0,
	next_checkpoint_cell_materials: Dictionary = {},
	next_checkpoint_protected_handle_cells: Dictionary = {},
	next_checkpoint_material_cell_counts: Dictionary = {}
) -> bool:
	if not _is_valid_native_materialization_packet(
		packet,
		expected_operation_count
	):
		return false
	if accumulated_operation_count == 0:
		# Compatibility for callers materializing the first logical checkpoint
		# in one step. The live hot path uses advance_logical_checkpoint first.
		if not advance_logical_checkpoint(
			expected_operation_count,
			next_material_variant_id,
			next_material_ledger_summary,
			next_lifetime_operation_count,
			next_resolver_sample_cell_size_meters,
			next_checkpoint_cell_materials,
			next_checkpoint_protected_handle_cells,
			next_checkpoint_material_cell_counts
		):
			return false
	elif expected_operation_count != accumulated_operation_count:
		return false
	return materialize_from_native_packet(packet, expected_operation_count)


func materialize_from_native_packet(
	packet: Dictionary,
	expected_operation_count: int
) -> bool:
	if not _is_valid_native_materialization_packet(
		packet,
		expected_operation_count
	):
		return false
	var packet_vertices: PackedVector3Array = packet.get(
		"vertices",
		PackedVector3Array()
	)
	var packet_indices: PackedInt32Array = packet.get(
		"indices",
		PackedInt32Array()
	)
	materialization_revision += 1
	materialized_mesh_operation_count = expected_operation_count
	vertices = packet_vertices
	indices = packet_indices
	source_original_ids = packet.get(
		"source_original_ids",
		PackedInt32Array()
	) as PackedInt32Array
	source_face_ids = packet.get(
		"source_face_ids",
		PackedInt32Array()
	) as PackedInt32Array
	vertex_count = int(packet.get(
		"checkpoint_vertex_count",
		packet_vertices.size()
	))
	triangle_count = int(packet.get(
		"checkpoint_triangle_count",
		packet_indices.size() / 3
	))
	volume_m3 = maxf(float(packet.get("checkpoint_volume_m3", 0.0)), 0.0)
	mesh_dirty = false
	updated_timestamp = Time.get_unix_time_from_system()
	schema_version = SCHEMA_VERSION
	return true


func _is_valid_native_materialization_packet(
	packet: Dictionary,
	expected_operation_count: int
) -> bool:
	var packet_vertices_variant: Variant = packet.get(
		"vertices",
		PackedVector3Array()
	)
	var packet_indices_variant: Variant = packet.get(
		"indices",
		PackedInt32Array()
	)
	var source_original_ids_variant: Variant = packet.get(
		"source_original_ids",
		PackedInt32Array()
	)
	var source_face_ids_variant: Variant = packet.get(
		"source_face_ids",
		PackedInt32Array()
	)
	if (
		not packet_vertices_variant is PackedVector3Array
		or not packet_indices_variant is PackedInt32Array
		or not source_original_ids_variant is PackedInt32Array
		or not source_face_ids_variant is PackedInt32Array
	):
		return false
	var packet_vertices := packet_vertices_variant as PackedVector3Array
	var packet_indices := packet_indices_variant as PackedInt32Array
	return (
		expected_operation_count > 0
		and int(packet.get("checkpoint_operation_count", -1))
		== expected_operation_count
		and bool(packet.get("ok", false))
		and bool(packet.get("checkpoint_initialized", false))
		and not packet_vertices.is_empty()
		and not packet_indices.is_empty()
		and packet_indices.size() % 3 == 0
		and int(packet.get(
			"checkpoint_vertex_count",
			packet_vertices.size()
		)) == packet_vertices.size()
		and int(packet.get(
			"checkpoint_triangle_count",
			packet_indices.size() / 3
		)) == packet_indices.size() / 3
		and is_finite(float(packet.get("checkpoint_volume_m3", 0.0)))
	)


func to_native_packet() -> Dictionary:
	return {
		"schema_version": schema_version,
		"checkpoint_id": checkpoint_id,
		"checkpoint_initialized": is_initialized(),
		"checkpoint_restore_ready": is_restore_ready(),
		"checkpoint_mesh_dirty": mesh_dirty,
		"checkpoint_revision": revision,
		"checkpoint_materialization_revision": materialization_revision,
		"checkpoint_operation_count": accumulated_operation_count,
		"materialized_mesh_operation_count": materialized_mesh_operation_count,
		"material_variant_id": material_variant_id,
		"vertices": vertices,
		"indices": indices,
		"source_original_ids": source_original_ids,
		"source_face_ids": source_face_ids,
		"checkpoint_vertex_count": vertex_count,
		"checkpoint_triangle_count": triangle_count,
		"checkpoint_volume_m3": volume_m3,
		"resolver_sample_cell_size_meters": (
			resolver_sample_cell_size_meters
		),
		"checkpoint_cell_materials": checkpoint_cell_materials,
		"checkpoint_protected_handle_cells": (
			checkpoint_protected_handle_cells
		),
		"checkpoint_material_cell_counts": checkpoint_material_cell_counts,
	}


func get_material_ledger_summary() -> Dictionary:
	return material_ledger_summary.duplicate(true)
