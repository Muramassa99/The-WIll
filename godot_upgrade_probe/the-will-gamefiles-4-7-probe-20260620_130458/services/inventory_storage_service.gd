extends RefCounted
class_name InventoryStorageService

func transfer_item(from_state: Resource, to_state: Resource, item_instance_id: StringName, amount: int = 0):
	if from_state == null or to_state == null:
		return null
	if not from_state.has_method("take_item") or not to_state.has_method("add_item"):
		return null
	var taken_item = from_state.call("take_item", item_instance_id, amount)
	if taken_item == null:
		return null
	var stored_item = to_state.call("add_item", taken_item)
	if stored_item != null:
		return stored_item
	if from_state.has_method("add_item"):
		from_state.call("add_item", taken_item)
	return null

func route_material_stack_to_forge_inventory(material_inventory_state: PlayerForgeInventoryState, material_stack: ForgeMaterialStack) -> bool:
	if material_inventory_state == null or material_stack == null:
		return false
	if material_stack.material_variant_id == StringName() or material_stack.quantity <= 0:
		return false
	material_inventory_state.add_quantity(material_stack.material_variant_id, material_stack.quantity)
	return true

func route_material_stacks_to_forge_inventory(
		material_inventory_state: PlayerForgeInventoryState,
		material_stacks: Array[ForgeMaterialStack]
	) -> bool:
	if material_inventory_state == null:
		return false
	var routed_stacks: Array[ForgeMaterialStack] = []
	for material_stack: ForgeMaterialStack in material_stacks:
		if not route_material_stack_to_forge_inventory(material_inventory_state, material_stack):
			for routed_stack: ForgeMaterialStack in routed_stacks:
				if routed_stack == null:
					continue
				material_inventory_state.add_quantity(routed_stack.material_variant_id, -routed_stack.quantity)
			return false
		routed_stacks.append(material_stack)
	return true
