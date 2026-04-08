extends RefCounted
class_name ItemInstanceContainerSupport

static func get_item(container_items: Array[Resource], item_instance_id: StringName):
	for container_item: Resource in container_items:
		if container_item == null:
			continue
		if container_item.item_instance_id == item_instance_id:
			return container_item
	return null

static func add_item(
	container_items: Array[Resource],
	source_item: Resource,
	generated_item_prefix: String,
	persist_container: Callable
):
	if source_item == null:
		return null
	var stored_item: Resource = source_item.duplicate(true)
	stored_item.item_instance_id = _resolve_item_instance_id(container_items, stored_item, generated_item_prefix)
	var stack_target: Resource = _find_stack_target(container_items, stored_item)
	if stack_target != null:
		stack_target.stack_count += maxi(stored_item.stack_count, 1)
		_persist_if_available(persist_container)
		return stack_target.duplicate(true)
	container_items.append(stored_item)
	_persist_if_available(persist_container)
	return stored_item.duplicate(true)

static func take_item(
	container_items: Array[Resource],
	item_instance_id: StringName,
	amount: int,
	persist_container: Callable
):
	var item_index: int = _find_item_index(container_items, item_instance_id)
	if item_index < 0:
		return null
	var stored_item: Resource = container_items[item_index]
	if stored_item == null:
		return null
	var resolved_amount: int = stored_item.stack_count if amount <= 0 else mini(amount, stored_item.stack_count)
	var taken_item: Resource = stored_item.duplicate(true)
	taken_item.stack_count = resolved_amount
	if resolved_amount >= stored_item.stack_count:
		container_items.remove_at(item_index)
	else:
		stored_item.stack_count -= resolved_amount
	_persist_if_available(persist_container)
	return taken_item

static func _find_item_index(container_items: Array[Resource], item_instance_id: StringName) -> int:
	for index: int in range(container_items.size()):
		var container_item: Resource = container_items[index]
		if container_item == null:
			continue
		if container_item.item_instance_id == item_instance_id:
			return index
	return -1

static func _find_stack_target(container_items: Array[Resource], source_item: Resource):
	for container_item: Resource in container_items:
		if container_item == null:
			continue
		if container_item.is_stack_equivalent_to(source_item):
			return container_item
	return null

static func _resolve_item_instance_id(
	container_items: Array[Resource],
	source_item: Resource,
	generated_item_prefix: String
) -> StringName:
	if source_item == null:
		return StringName()
	if source_item.item_instance_id == StringName():
		return _build_generated_item_instance_id(container_items, generated_item_prefix)
	if get_item(container_items, source_item.item_instance_id) != null:
		return _build_generated_item_instance_id(container_items, generated_item_prefix)
	return source_item.item_instance_id

static func _build_generated_item_instance_id(
	container_items: Array[Resource],
	generated_item_prefix: String
) -> StringName:
	return StringName("%s_%s_%d" % [generated_item_prefix, str(Time.get_unix_time_from_system()), container_items.size() + 1])

static func _persist_if_available(persist_container: Callable) -> void:
	if persist_container.is_valid():
		persist_container.call()
