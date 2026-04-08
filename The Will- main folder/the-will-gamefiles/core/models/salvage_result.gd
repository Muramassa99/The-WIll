extends Resource
class_name SalvageResult

@export var selected_item_snapshots: Array[Resource] = []
@export var preview_material_stacks: Array[ForgeMaterialStack] = []
@export var supported_item_ids: Array[StringName] = []
@export var unsupported_item_ids: Array[StringName] = []
@export var info_lines: PackedStringArray = []
@export var blocking_lines: PackedStringArray = []
@export var can_extract_blueprint: bool = false
@export var can_select_skill: bool = false
@export var requires_irreversible_confirmation: bool = true
@export var preview_valid: bool = false
@export var commit_applied: bool = false
@export var committed_item_ids: Array[StringName] = []
@export var failure_reason: StringName = &""

func has_preview_materials() -> bool:
	for material_stack: ForgeMaterialStack in preview_material_stacks:
		if material_stack == null:
			continue
		if material_stack.quantity > 0:
			return true
	return false

func get_total_preview_quantity() -> int:
	var total_quantity: int = 0
	for material_stack: ForgeMaterialStack in preview_material_stacks:
		if material_stack == null:
			continue
		total_quantity += maxi(material_stack.quantity, 0)
	return total_quantity
