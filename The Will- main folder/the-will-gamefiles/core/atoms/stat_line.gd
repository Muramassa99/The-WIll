extends Resource
class_name StatLine

enum ValueKind {
	FLAT,
	PCT_ADD,
	FLAG,
	ENUM
}

@export var stat_id: StringName = &""
@export var value: float = 0.0
@export var value_kind: ValueKind = ValueKind.FLAT
@export var enum_value: StringName = &""

func is_numeric() -> bool:
	return value_kind == ValueKind.FLAT or value_kind == ValueKind.PCT_ADD

func is_flag() -> bool:
	return value_kind == ValueKind.FLAG

func is_enum() -> bool:
	return value_kind == ValueKind.ENUM

func get_flag_value() -> bool:
	return value >= 0.5

func copy_scaled(mult: float) -> StatLine:
	var out := StatLine.new()
	out.stat_id = stat_id
	out.value_kind = value_kind
	out.enum_value = enum_value

	if is_numeric():
		out.value = value * mult
	else:
		out.value = value

	return out

func is_valid() -> bool:
	if stat_id == StringName():
		return false

	if is_enum():
		return enum_value != StringName()

	return true
