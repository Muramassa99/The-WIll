extends RefCounted
class_name ForgeV2MaterialCompositionPolicy

const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)


static func is_protected_handle_entry(body: Variant) -> bool:
	# body_kind is the sole persisted semantic authority for Handle protection.
	return _read_body_string_name(body, "body_kind") == (
		ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
	)


static func resolve_effective_operation_mode(body: Variant) -> StringName:
	if is_protected_handle_entry(body):
		return ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
	if (
		_read_body_string_name(body, "operation_mode")
		== ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
	):
		return ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
	return ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL


static func resolve_effective_placement_policy(body: Variant) -> StringName:
	if is_protected_handle_entry(body):
		return ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	if (
		_read_body_string_name(body, "placement_policy")
		== ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
	):
		return ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
	return ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING


static func can_mutate_protected_handle_cells(body: Variant) -> bool:
	return is_protected_handle_entry(body)


static func _read_body_string_name(
	body: Variant,
	field_name: String,
	default_value: StringName = StringName()
) -> StringName:
	if body is Resource:
		var value: Variant = (body as Resource).get(field_name)
		return default_value if value == null else StringName(value)
	if body is Dictionary:
		return StringName((body as Dictionary).get(field_name, default_value))
	return default_value
