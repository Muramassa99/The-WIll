extends RefCounted
class_name ForgeV2PrimitiveCatalog

const PRIMITIVE_BLOB := &"primitive_blob"
const PRIMITIVE_ROD := &"primitive_rod"
const PRIMITIVE_PLATE := &"primitive_plate"
const PRIMITIVE_LOOP := &"primitive_loop"
const PRIMITIVE_SPINE := &"primitive_spine"

static func get_primitive_ids() -> Array[StringName]:
	return [
		PRIMITIVE_BLOB,
		PRIMITIVE_ROD,
		PRIMITIVE_PLATE,
		PRIMITIVE_LOOP,
		PRIMITIVE_SPINE,
	]

static func normalize_primitive_id(primitive_id: StringName) -> StringName:
	if get_primitive_ids().has(primitive_id):
		return primitive_id
	return PRIMITIVE_BLOB

static func get_primitive_label(primitive_id: StringName) -> String:
	match normalize_primitive_id(primitive_id):
		PRIMITIVE_ROD:
			return "Rod"
		PRIMITIVE_PLATE:
			return "Plate"
		PRIMITIVE_LOOP:
			return "Loop"
		PRIMITIVE_SPINE:
			return "Spine Curve"
		_:
			return "Blob"

static func get_primitive_summary(primitive_id: StringName) -> String:
	match normalize_primitive_id(primitive_id):
		PRIMITIVE_ROD:
			return "Single capsule path, useful for handles, edges, and long forms."
		PRIMITIVE_PLATE:
			return "Parallel capsule paths approximating a flat surface."
		PRIMITIVE_LOOP:
			return "Closed capsule path for guards, rims, rings, and channels."
		PRIMITIVE_SPINE:
			return "Curved capsule path for organic sweeps and future spline work."
		_:
			return "Single sphere of material at the authoring origin."

static func build_option_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for primitive_id: StringName in get_primitive_ids():
		entries.append({
			"id": primitive_id,
			"label": get_primitive_label(primitive_id),
			"summary": get_primitive_summary(primitive_id),
		})
	return entries

static func build_stroke_specs(
	primitive_id: StringName,
	radius_meters: float,
	_amount_ratio: float
) -> Array[Dictionary]:
	var radius: float = maxf(radius_meters, 0.001)
	var amount: float = 1.0
	match normalize_primitive_id(primitive_id):
		PRIMITIVE_ROD:
			return [_build_spec(
				PackedVector3Array([
					Vector3(-radius * 6.0, 0.0, 0.0),
					Vector3(radius * 6.0, 0.0, 0.0),
				]),
				radius,
				amount
			)]
		PRIMITIVE_PLATE:
			return _build_plate_specs(radius, amount)
		PRIMITIVE_LOOP:
			return [_build_spec(_build_loop_points(radius * 4.0, 16), radius * 0.55, amount)]
		PRIMITIVE_SPINE:
			return [_build_spec(
				PackedVector3Array([
					Vector3(-radius * 6.0, -radius * 0.8, 0.0),
					Vector3(-radius * 3.0, radius * 1.1, radius * 0.6),
					Vector3(0.0, -radius * 0.6, -radius * 0.3),
					Vector3(radius * 3.0, radius * 1.0, radius * 0.5),
					Vector3(radius * 6.0, -radius * 0.4, 0.0),
				]),
				radius,
				amount
			)]
		_:
			return [_build_spec(PackedVector3Array([Vector3.ZERO]), radius, amount)]

static func _build_plate_specs(radius: float, amount: float) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var plate_radius: float = radius * 0.72
	for y_offset in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		specs.append(_build_spec(
			PackedVector3Array([
				Vector3(-radius * 5.5, radius * y_offset * 0.82, 0.0),
				Vector3(radius * 5.5, radius * y_offset * 0.82, 0.0),
			]),
			plate_radius,
			amount
		))
	return specs

static func _build_loop_points(loop_radius: float, side_count: int) -> PackedVector3Array:
	var point_count: int = maxi(side_count, 6)
	var points := PackedVector3Array()
	for point_index in range(point_count):
		var angle: float = TAU * float(point_index) / float(point_count)
		points.append(Vector3(cos(angle) * loop_radius, sin(angle) * loop_radius, 0.0))
	points.append(points[0])
	return points

static func _build_spec(
	path_points: PackedVector3Array,
	radius_meters: float,
	amount_ratio: float
) -> Dictionary:
	return {
		"path_points": path_points,
		"radius_meters": radius_meters,
		"amount_ratio": amount_ratio,
	}
