extends RefCounted
class_name PlayerRuntimeStatePresenter

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const StoredItemInstanceScript = preload("res://core/models/stored_item_instance.gd")

func get_body_inventory_state(current_state):
	if current_state == null:
		return PlayerBodyInventoryStateScript.load_or_create()
	return current_state

func get_personal_storage_state(current_state):
	if current_state == null:
		return PlayerPersonalStorageStateScript.load_or_create()
	return current_state

func get_equipment_state(current_state):
	if current_state == null:
		return PlayerEquipmentStateScript.load_or_create()
	return current_state

func get_forge_inventory_state(current_state: PlayerForgeInventoryState) -> PlayerForgeInventoryState:
	if current_state == null:
		return PlayerForgeInventoryState.new()
	return current_state

func get_forge_wip_library_state(current_state: PlayerForgeWipLibraryState) -> PlayerForgeWipLibraryState:
	if current_state == null:
		return PlayerForgeWipLibraryStateScript.load_or_create()
	return current_state

func get_material_lookup(material_pipeline_service, cached_material_lookup: Dictionary) -> Dictionary:
	if not cached_material_lookup.is_empty():
		return cached_material_lookup
	if material_pipeline_service == null:
		return {}
	return material_pipeline_service.build_base_material_lookup()

func ensure_body_inventory_seeded(body_state, seed_def: Resource = null) -> void:
	if body_state == null or seed_def == null or seed_def.is_empty():
		return
	if not body_state.get_owned_items().is_empty():
		return
	for seed_entry in seed_def.entries:
		if seed_entry == null or seed_entry.stack_count <= 0:
			continue
		if seed_entry.item_kind == &"raw_drop" and seed_entry.raw_drop_id == StringName():
			continue
		var stored_item = StoredItemInstanceScript.new()
		stored_item.item_kind = seed_entry.item_kind
		stored_item.display_name = seed_entry.display_name.strip_edges()
		stored_item.stack_count = seed_entry.stack_count
		stored_item.raw_drop_id = seed_entry.raw_drop_id
		stored_item.is_disassemblable = seed_entry.is_disassemblable
		body_state.add_item(stored_item)

func ensure_forge_inventory_seeded(
	inventory_state: PlayerForgeInventoryState,
	material_lookup: Dictionary,
	inventory_seed_def: Resource = null,
	fallback_quantity: int = 0,
	debug_bonus_quantity: int = 0
) -> void:
	if inventory_state == null or material_lookup.is_empty():
		return
	if inventory_seed_def != null and not inventory_seed_def.is_empty():
		var applied_seed_floor: bool = false
		for seed_entry in inventory_seed_def.entries:
			if seed_entry == null or seed_entry.material_id == StringName() or seed_entry.quantity <= 0:
				continue
			if not material_lookup.has(seed_entry.material_id):
				continue
			var target_quantity: int = seed_entry.quantity + maxi(debug_bonus_quantity, 0)
			if inventory_state.get_quantity(seed_entry.material_id) < target_quantity:
				inventory_state.set_quantity(seed_entry.material_id, target_quantity)
			applied_seed_floor = true
		if applied_seed_floor:
			return
	if fallback_quantity <= 0:
		return
	var resolved_fallback_quantity: int = fallback_quantity + maxi(debug_bonus_quantity, 0)
	for material_id_value in material_lookup.keys():
		var material_id: StringName = material_id_value
		if inventory_state.get_quantity(material_id) < resolved_fallback_quantity:
			inventory_state.set_quantity(material_id, resolved_fallback_quantity)

func set_selected_forge_wip_id(wip_library: PlayerForgeWipLibraryState, saved_wip_id: StringName) -> void:
	if wip_library != null:
		wip_library.set_selected_wip_id(saved_wip_id)
