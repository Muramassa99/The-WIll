extends RefCounted
class_name PrimaryGripHandleMeshPacket

const CombatOriginRecordScript = preload(
	"res://core/models/combat_origin_record.gd"
)
const SOURCE := &"forge_v2_protected_handle_exact_csg_v1"
const VERTICES_ORIGIN_ID: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
const METER_SIGNATURE_STEP := 0.0000001
const UNIT_SIGNATURE_STEP := 0.0000001
const DEGREE_SIGNATURE_STEP := 0.000001


static func build_body_signature(body: Resource) -> String:
	if body == null:
		return ""
	var exact_geometry := [
		"handle_exact_signature_schema_2",
		String(StringName(body.get("body_kind"))),
		String(StringName(body.get("shape_kind"))),
		String(StringName(body.get("profile_id"))),
		_quantize_vector3_array(
			body.get("path_points") as PackedVector3Array,
			METER_SIGNATURE_STEP
		),
		_quantize_vector3_array(
			body.get("path_surface_normals") as PackedVector3Array,
			UNIT_SIGNATURE_STEP
		),
		_quantize_vector3_array(
			body.get("path_contact_directions") as PackedVector3Array,
			UNIT_SIGNATURE_STEP
		),
		_quantize_vector2_array(
			body.get("profile_polygon_2d_meters") as PackedVector2Array,
			METER_SIGNATURE_STEP
		),
		_quantize_vector2(
			body.get("profile_anchor_2d_meters") as Vector2,
			METER_SIGNATURE_STEP
		),
		_quantize_vector2(
			body.get("profile_contact_direction_2d") as Vector2,
			UNIT_SIGNATURE_STEP
		),
		_quantize_vector2(
			body.get("profile_contact_point_relative_2d_meters") as Vector2,
			METER_SIGNATURE_STEP
		),
		_quantize_scalar(
			float(body.get("profile_contact_distance_meters")),
			METER_SIGNATURE_STEP
		),
		_quantize_scalar(
			float(body.get("radius_meters")),
			METER_SIGNATURE_STEP
		),
		int(body.get("profile_runtime_schema_version")),
		_quantize_scalar(
			float(body.get("profile_rotation_bias_degrees")),
			DEGREE_SIGNATURE_STEP
		),
		_quantize_scalar(
			float(body.get("profile_twist_degrees_per_meter")),
			DEGREE_SIGNATURE_STEP
		),
	]
	return "handle_exact_v2:%s" % (
		var_to_bytes(exact_geometry).hex_encode().sha256_text()
	)


static func _quantize_vector3_array(
	values: PackedVector3Array,
	step: float
) -> PackedInt64Array:
	var quantized := PackedInt64Array()
	quantized.resize(values.size() * 3)
	for value_index: int in range(values.size()):
		var value := values[value_index]
		var component_offset := value_index * 3
		quantized[component_offset] = _quantize_scalar(value.x, step)
		quantized[component_offset + 1] = _quantize_scalar(value.y, step)
		quantized[component_offset + 2] = _quantize_scalar(value.z, step)
	return quantized


static func _quantize_vector2_array(
	values: PackedVector2Array,
	step: float
) -> PackedInt64Array:
	var quantized := PackedInt64Array()
	quantized.resize(values.size() * 2)
	for value_index: int in range(values.size()):
		var value := values[value_index]
		var component_offset := value_index * 2
		quantized[component_offset] = _quantize_scalar(value.x, step)
		quantized[component_offset + 1] = _quantize_scalar(value.y, step)
	return quantized


static func _quantize_vector2(value: Vector2, step: float) -> PackedInt64Array:
	return PackedInt64Array([
		_quantize_scalar(value.x, step),
		_quantize_scalar(value.y, step),
	])


static func _quantize_scalar(value: float, step: float) -> int:
	if not is_finite(value):
		return 9223372036854775807
	return roundi(value / step)


static func build(
	vertices_meters: PackedVector3Array,
	indices: PackedInt32Array,
	body_signature: String
) -> Dictionary:
	return {
		"ok": true,
		"vertices": PackedVector3Array(vertices_meters),
		"indices": PackedInt32Array(indices),
		"primary_grip_handle_vertices": PackedVector3Array(vertices_meters),
		"primary_grip_handle_indices": PackedInt32Array(indices),
		"primary_grip_handle_mesh_source": SOURCE,
		"primary_grip_handle_body_signature": body_signature,
		"primary_grip_handle_vertices_origin_id": VERTICES_ORIGIN_ID,
	}


static func validate(packet: Dictionary) -> Dictionary:
	if StringName(packet.get(
		"primary_grip_handle_mesh_source",
		StringName()
	)) != SOURCE:
		return {"valid": false, "error": "handle_mesh_source_invalid"}
	var body_signature := String(packet.get(
		"primary_grip_handle_body_signature",
		""
	))
	if body_signature.is_empty():
		return {"valid": false, "error": "handle_mesh_signature_missing"}
	var vertices_origin_id := StringName(packet.get(
		"primary_grip_handle_vertices_origin_id",
		StringName()
	))
	var vertices_origin_migrated := false
	if vertices_origin_id == StringName():
		# SOURCE v1 has always authored these vertices in WeaponRootOrigin. Older
		# saved packets predate the explicit field, so migrate from the versioned
		# source contract instead of treating the vectors as anonymous.
		vertices_origin_id = VERTICES_ORIGIN_ID
		vertices_origin_migrated = true
	if vertices_origin_id != VERTICES_ORIGIN_ID:
		return {"valid": false, "error": "handle_mesh_vertices_origin_invalid"}
	var vertices_variant: Variant = packet.get(
		"primary_grip_handle_vertices",
		null
	)
	var indices_variant: Variant = packet.get(
		"primary_grip_handle_indices",
		null
	)
	if not vertices_variant is PackedVector3Array:
		return {"valid": false, "error": "handle_mesh_vertices_missing"}
	if not indices_variant is PackedInt32Array:
		return {"valid": false, "error": "handle_mesh_indices_missing"}
	var vertices := vertices_variant as PackedVector3Array
	var indices := indices_variant as PackedInt32Array
	if vertices.size() < 3 or indices.size() < 3 or indices.size() % 3 != 0:
		return {"valid": false, "error": "handle_mesh_topology_invalid"}
	for vertex: Vector3 in vertices:
		if not vertex.is_finite():
			return {"valid": false, "error": "handle_mesh_vertex_nonfinite"}
	for index_value: int in indices:
		if index_value < 0 or index_value >= vertices.size():
			return {"valid": false, "error": "handle_mesh_index_invalid"}
	return {
		"valid": true,
		"vertices": vertices,
		"indices": indices,
		"source": SOURCE,
		"body_signature": body_signature,
		"vertices_origin_id": vertices_origin_id,
		"vertices_origin_migrated": vertices_origin_migrated,
	}
