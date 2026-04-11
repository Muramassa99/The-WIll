extends RefCounted
class_name PrimaryGripSliceProfileLibrary

const PRESET_GRIP_2X3: StringName = &"grip_2x3"
const PRESET_GRIP_2X4: StringName = &"grip_2x4"
const PRESET_ROUNDED_8: StringName = &"grip_rounded_8"
const PRESET_GRIP_3X3: StringName = &"grip_3x3"
const PRESET_ROUNDED_11: StringName = &"grip_rounded_11"
const PRESET_ROUNDED_12: StringName = &"grip_rounded_12"
const PRESET_DIAMOND_13: StringName = &"grip_diamond_13"
const PRESET_OFFSET_14: StringName = &"grip_offset_14"
const PRESET_ROUNDED_16: StringName = &"grip_rounded_16"
const PRESET_ROUNDED_21: StringName = &"grip_rounded_21"
const PRESET_DIAMOND_21: StringName = &"grip_diamond_21"
const PRESET_HEX_24: StringName = &"grip_hex_24"

const PRESET_DEFS: Array[Dictionary] = [
	{
		"preset_id": PRESET_GRIP_2X3,
		"label": "Grip 2x3",
		"rows": ["11", "11", "11"],
	},
	{
		"preset_id": PRESET_GRIP_2X4,
		"label": "Grip 2x4",
		"rows": ["11", "11", "11", "11"],
	},
	{
		"preset_id": PRESET_ROUNDED_8,
		"label": "Rounded 8",
		"rows": ["010", "111", "111", "010"],
	},
	{
		"preset_id": PRESET_GRIP_3X3,
		"label": "Grip 3x3",
		"rows": ["111", "111", "111"],
	},
	{
		"preset_id": PRESET_ROUNDED_11,
		"label": "Rounded 11",
		"rows": ["010", "111", "111", "111", "010"],
	},
	{
		"preset_id": PRESET_ROUNDED_12,
		"label": "Rounded 12",
		"rows": ["0110", "1111", "1111", "0110"],
	},
	{
		"preset_id": PRESET_DIAMOND_13,
		"label": "Diamond 13",
		"rows": ["00100", "01110", "11111", "01110", "00100"],
	},
	{
		"preset_id": PRESET_OFFSET_14,
		"label": "Offset 14",
		"rows": ["0110", "1111", "0110", "1111", "0110"],
	},
	{
		"preset_id": PRESET_ROUNDED_16,
		"label": "Rounded 16",
		"rows": ["01110", "11111", "11111", "01110"],
	},
	{
		"preset_id": PRESET_ROUNDED_21,
		"label": "Rounded 21",
		"rows": ["01110", "11111", "11111", "11111", "01110"],
	},
	{
		"preset_id": PRESET_DIAMOND_21,
		"label": "Diamond 21",
		"rows": ["00100", "01110", "11111", "01110", "11111", "01110", "00100"],
	},
	{
		"preset_id": PRESET_HEX_24,
		"label": "Hex 24",
		"rows": ["001100", "011110", "111111", "111111", "011110", "001100"],
	},
]

static func get_preset_defs() -> Array[Dictionary]:
	return PRESET_DEFS.duplicate(true)

static func build_valid_mask_lookup() -> Dictionary:
	var lookup: Dictionary = {}
	for preset_def: Dictionary in PRESET_DEFS:
		var preset_rows: Array[String] = []
		for row_variant: Variant in preset_def.get("rows", []):
			preset_rows.append(String(row_variant))
		var canonical_key: String = build_canonical_mask_key_from_rows(preset_rows)
		if canonical_key.is_empty():
			continue
		lookup[canonical_key] = preset_def.get("preset_id", StringName())
	return lookup

static func build_canonical_mask_key_from_rows(rows: Array[String]) -> String:
	return build_canonical_mask_key_from_positions(_rows_to_positions(rows))

static func build_canonical_mask_key_from_positions(positions: Array[Vector2i]) -> String:
	if positions.is_empty():
		return ""
	var best_key: String = ""
	for mirror in [false, true]:
		for rotation_steps in range(4):
			var transformed_positions: Array[Vector2i] = []
			for coord: Vector2i in positions:
				transformed_positions.append(_transform_coord(coord, rotation_steps, mirror))
			var candidate_key: String = _positions_to_normalized_key(transformed_positions)
			if candidate_key.is_empty():
				continue
			if best_key.is_empty() or candidate_key < best_key:
				best_key = candidate_key
	return best_key

static func _rows_to_positions(rows: Array[String]) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for row_index: int in range(rows.size()):
		var row_text: String = rows[row_index]
		for column_index: int in range(row_text.length()):
			if row_text.substr(column_index, 1) != "1":
				continue
			positions.append(Vector2i(column_index, row_index))
	return positions

static func _transform_coord(coord: Vector2i, rotation_steps: int, mirror: bool) -> Vector2i:
	var transformed_coord: Vector2i = coord
	match rotation_steps % 4:
		1:
			transformed_coord = Vector2i(-coord.y, coord.x)
		2:
			transformed_coord = Vector2i(-coord.x, -coord.y)
		3:
			transformed_coord = Vector2i(coord.y, -coord.x)
	if mirror:
		transformed_coord = Vector2i(-transformed_coord.x, transformed_coord.y)
	return transformed_coord

static func _positions_to_normalized_key(positions: Array[Vector2i]) -> String:
	if positions.is_empty():
		return ""
	var min_x: int = positions[0].x
	var min_y: int = positions[0].y
	var max_x: int = positions[0].x
	var max_y: int = positions[0].y
	for coord: Vector2i in positions:
		min_x = mini(min_x, coord.x)
		min_y = mini(min_y, coord.y)
		max_x = maxi(max_x, coord.x)
		max_y = maxi(max_y, coord.y)
	var normalized_lookup: Dictionary = {}
	for coord: Vector2i in positions:
		normalized_lookup[Vector2i(coord.x - min_x, coord.y - min_y)] = true
	var lines: PackedStringArray = PackedStringArray()
	for row_index: int in range((max_y - min_y) + 1):
		var row_text: PackedStringArray = PackedStringArray()
		for column_index: int in range((max_x - min_x) + 1):
			row_text.append("1" if normalized_lookup.has(Vector2i(column_index, row_index)) else "0")
		lines.append("".join(row_text))
	return "\n".join(lines)
