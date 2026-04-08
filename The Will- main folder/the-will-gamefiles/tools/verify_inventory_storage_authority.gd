extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerForgeInventoryStateScript = preload("res://core/models/player_forge_inventory_state.gd")
const StoredItemInstanceScript = preload("res://core/models/stored_item_instance.gd")
const FinalizedItemInstanceScript = preload("res://core/models/finalized_item_instance.gd")
const InventoryStorageServiceScript = preload("res://services/inventory_storage_service.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")

const WoodMaterialResource = preload("res://core/defs/materials/base/wood.tres")
const ForgeStorageRulesResource = preload("res://core/defs/forge/forge_storage_rules_default.tres")

const TEMP_BODY_SAVE_PATH := "user://inventory/verify_player_body_inventory_state.tres"
const TEMP_STORAGE_SAVE_PATH := "user://storage/verify_player_personal_storage_state.tres"
const OUTPUT_PATH := "c:/WORKSPACE/inventory_storage_results.txt"

func _init() -> void:
	_cleanup_temp_file(TEMP_BODY_SAVE_PATH)
	_cleanup_temp_file(TEMP_STORAGE_SAVE_PATH)

	var body_state = PlayerBodyInventoryStateScript.load_or_create(TEMP_BODY_SAVE_PATH)
	body_state.owned_items.clear()
	body_state.persist()

	var personal_storage_state = PlayerPersonalStorageStateScript.load_or_create(TEMP_STORAGE_SAVE_PATH)
	personal_storage_state.stored_items.clear()
	personal_storage_state.persist()

	var raw_drop_item = _build_raw_drop_item()
	var finalized_item = _build_finalized_item()
	body_state.add_item(raw_drop_item)
	body_state.add_item(finalized_item)

	var inventory_storage_service = InventoryStorageServiceScript.new()
	var moved_raw_drop = inventory_storage_service.call(
		"transfer_item",
		body_state,
		personal_storage_state,
		&"drop_stack_wood_1",
		2
	)
	var moved_finalized_item = inventory_storage_service.call(
		"transfer_item",
		body_state,
		personal_storage_state,
		&"practice_sword_finalized_1"
	)

	var material_pipeline_service = MaterialPipelineServiceScript.new()
	var resolved_pipeline: Dictionary = material_pipeline_service.resolve_pipeline_for_material(WoodMaterialResource)
	var routed_material_stack = resolved_pipeline.get("material_stack")
	var forge_inventory_state = PlayerForgeInventoryStateScript.new()
	var route_success: bool = inventory_storage_service.call(
		"route_material_stack_to_forge_inventory",
		forge_inventory_state,
		routed_material_stack
	)

	var body_raw_drop = body_state.get_item(&"drop_stack_wood_1")
	var storage_raw_drop = personal_storage_state.get_item(&"drop_stack_wood_1")
	var storage_finalized = personal_storage_state.get_item(&"practice_sword_finalized_1")

	var lines: PackedStringArray = []
	lines.append("body_state_save_exists=%s" % str(FileAccess.file_exists(TEMP_BODY_SAVE_PATH)))
	lines.append("personal_storage_save_exists=%s" % str(FileAccess.file_exists(TEMP_STORAGE_SAVE_PATH)))
	lines.append("body_owned_item_count=%d" % body_state.get_owned_items().size())
	lines.append("body_disassemblable_count=%d" % body_state.get_disassemblable_items().size())
	lines.append("storage_item_count=%d" % personal_storage_state.get_stored_items().size())
	lines.append("raw_drop_partial_transfer_success=%s" % str(moved_raw_drop != null and moved_raw_drop.stack_count == 2))
	lines.append("finalized_item_transfer_success=%s" % str(moved_finalized_item != null and moved_finalized_item.finalized_item != null))
	lines.append("body_raw_drop_remaining=%d" % (body_raw_drop.stack_count if body_raw_drop != null else 0))
	lines.append("storage_raw_drop_quantity=%d" % (storage_raw_drop.stack_count if storage_raw_drop != null else 0))
	lines.append("storage_finalized_present=%s" % str(storage_finalized != null and storage_finalized.finalized_item != null))
	lines.append("route_material_stack_success=%s" % str(route_success))
	lines.append("routed_material_variant_id=%s" % String(routed_material_stack.material_variant_id if routed_material_stack != null else StringName()))
	lines.append("routed_material_quantity=%d" % (routed_material_stack.quantity if routed_material_stack != null else 0))
	lines.append("forge_inventory_routed_quantity=%d" % forge_inventory_state.get_quantity(
		routed_material_stack.material_variant_id if routed_material_stack != null else StringName()
	))
	lines.append("forge_storage_weapon_wip_slots=%d" % (
		ForgeStorageRulesResource.weapon_wip_slot_capacity if ForgeStorageRulesResource != null else 0
	))
	lines.append("forge_storage_blueprint_slots=%d" % (
		ForgeStorageRulesResource.blueprint_slot_capacity if ForgeStorageRulesResource != null else 0
	))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	_cleanup_temp_file(TEMP_BODY_SAVE_PATH)
	_cleanup_temp_file(TEMP_STORAGE_SAVE_PATH)
	quit()

func _build_raw_drop_item():
	var stored_item = StoredItemInstanceScript.new()
	stored_item.item_instance_id = &"drop_stack_wood_1"
	stored_item.item_kind = &"raw_drop"
	stored_item.display_name = "Wood Raw (Gray)"
	stored_item.stack_count = 3
	stored_item.raw_drop_id = &"drop_wood_raw_gray"
	stored_item.is_disassemblable = true
	return stored_item

func _build_finalized_item():
	var finalized_item = FinalizedItemInstanceScript.new()
	finalized_item.finalized_item_id = &"finalized_practice_sword"
	finalized_item.final_item_name = "Practice Sword"
	finalized_item.source_wip_id = &"wip_practice_sword"
	finalized_item.finalized_timestamp = Time.get_unix_time_from_system()

	var stored_item = StoredItemInstanceScript.new()
	stored_item.item_instance_id = &"practice_sword_finalized_1"
	stored_item.item_kind = &"finalized_item"
	stored_item.stack_count = 1
	stored_item.finalized_item = finalized_item
	stored_item.is_disassemblable = true
	return stored_item

func _cleanup_temp_file(save_path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_path)
