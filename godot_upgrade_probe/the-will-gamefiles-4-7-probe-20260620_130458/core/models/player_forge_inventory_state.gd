extends Resource
class_name PlayerForgeInventoryState

@export var material_stacks: Array[ForgeMaterialStack] = []

func has_any_material_stacks() -> bool:
	for stack: ForgeMaterialStack in material_stacks:
		if stack != null and stack.quantity > 0:
			return true
	return false

func get_quantity(material_variant_id: StringName) -> int:
	var stack: ForgeMaterialStack = _find_stack(material_variant_id)
	if stack == null:
		return 0
	return stack.quantity

func set_quantity(material_variant_id: StringName, quantity: int) -> void:
	var stack: ForgeMaterialStack = _ensure_stack(material_variant_id)
	stack.quantity = maxi(quantity, 0)

func add_quantity(material_variant_id: StringName, amount: int) -> void:
	if amount == 0:
		return
	var stack: ForgeMaterialStack = _ensure_stack(material_variant_id)
	stack.quantity = maxi(stack.quantity + amount, 0)

func try_consume(material_variant_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var stack: ForgeMaterialStack = _find_stack(material_variant_id)
	if stack == null or stack.quantity < amount:
		return false
	stack.quantity -= amount
	return true

func _ensure_stack(material_variant_id: StringName) -> ForgeMaterialStack:
	var existing_stack: ForgeMaterialStack = _find_stack(material_variant_id)
	if existing_stack != null:
		return existing_stack
	var new_stack: ForgeMaterialStack = ForgeMaterialStack.new()
	new_stack.material_variant_id = material_variant_id
	material_stacks.append(new_stack)
	return new_stack

func _find_stack(material_variant_id: StringName) -> ForgeMaterialStack:
	for stack: ForgeMaterialStack in material_stacks:
		if stack == null:
			continue
		if stack.material_variant_id == material_variant_id:
			return stack
	return null